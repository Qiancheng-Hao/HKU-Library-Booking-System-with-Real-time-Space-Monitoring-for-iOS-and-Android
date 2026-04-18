import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../core/di/app_services.dart';
import '../core/models/reservation.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String keyEnabled = 'notif_enabled';
  static const String keyReminderMinutes = 'notif_reminder_minutes';
  static const String _keyTrackedReminderIds = 'notif_booking_reminder_ids';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_ianaTimeZoneName()));

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/launcher_icon',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  static Future<bool> ensurePermissions() async {
    await initialize();

    if (kIsWeb) return false;

    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      final granted = await iosPlugin?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }

    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidPlugin?.requestNotificationsPermission();
      return granted ?? true;
    }

    return true;
  }

  static Future<bool> hasSystemPermission() async {
    if (kIsWeb) return false;
    final status = await Permission.notification.status;
    return status.isGranted || status.isLimited || status.isProvisional;
  }

  static Future<bool> openNotificationSettings() async {
    return openAppSettings();
  }

  static Future<bool> _isReminderEnabled() async {
    final enabled = await _storage.read(key: keyEnabled);
    return enabled != 'false';
  }

  static Future<int> _getReminderMinutes() async {
    final minutes = await _storage.read(key: keyReminderMinutes);
    return int.tryParse(minutes ?? '') ?? 30;
  }

  static Future<void> syncUpcomingReminders() async {
    await initialize();

    if (!await _isReminderEnabled()) {
      await cancelAllBookingReminders();
      return;
    }

    final hasPermission = await ensurePermissions();
    if (!hasPermission) return;

    final reservations = await AppServices.reservationRepository
        .getUserReservations();
    await cancelAllBookingReminders();

    for (final reservation in reservations) {
      await scheduleReservationReminder(reservation);
    }
  }

  static Future<void> scheduleReservationReminder(
    Reservation reservation,
  ) async {
    await initialize();

    if (!await _isReminderEnabled()) return;

    final reminderMinutes = await _getReminderMinutes();
    final scheduledAt = reminderScheduledAt(
      reservation,
      reminderMinutes: reminderMinutes,
      now: DateTime.now(),
    );
    if (scheduledAt == null) return;

    final notificationId = notificationIdFor(reservation.id);

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Booking reminder',
      body: reminderBody(reservation),
      scheduledDate: tz.TZDateTime.from(scheduledAt, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'booking_reminders',
          'Booking reminders',
          channelDescription: 'Reminder notifications before reservations',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: reservation.id,
    );
    await _trackReminderId(notificationId);
  }

  static Future<void> cancelReservationReminder(String reservationId) async {
    await initialize();
    final notificationId = notificationIdFor(reservationId);
    await _plugin.cancel(id: notificationId);
    await _untrackReminderId(notificationId);
  }

  static Future<void> cancelAllBookingReminders() async {
    await initialize();
    final trackedIds = await _trackedReminderIds();
    for (final notificationId in trackedIds) {
      await _plugin.cancel(id: notificationId);
    }
    await _saveTrackedReminderIds(<int>{});
  }

  @visibleForTesting
  static int notificationIdFor(String reservationId) {
    final compact = reservationId.replaceAll('-', '');
    final suffix = compact.length > 8
        ? compact.substring(compact.length - 8)
        : compact;
    final parsed = int.tryParse(suffix, radix: 16);
    if (parsed != null) {
      return parsed & 0x7fffffff;
    }
    return compact.hashCode & 0x7fffffff;
  }

  @visibleForTesting
  static DateTime? reminderScheduledAt(
    Reservation reservation, {
    required int reminderMinutes,
    required DateTime now,
  }) {
    if (!reservation.isUpcoming) return null;
    final reservationStart = reservation.maybeStartDateTime;
    if (reservationStart == null) return null;
    final scheduledAt = reservationStart.subtract(
      Duration(minutes: reminderMinutes),
    );
    if (!scheduledAt.isAfter(now)) return null;
    return scheduledAt;
  }

  @visibleForTesting
  static String reminderBody(Reservation reservation) {
    final facilityName = reservation.facility?.name ?? 'Reserved facility';
    final libraryName = reservation.facility?.libraryName ?? 'HKU Library';
    final startTime = reservation.shortStartTime;
    return '$facilityName starts at $startTime in $libraryName.';
  }

  static Future<Set<int>> _trackedReminderIds() async {
    final raw = await _storage.read(key: _keyTrackedReminderIds);
    if (raw == null || raw.isEmpty) return <int>{};
    try {
      final decoded = json.decode(raw);
      if (decoded is! List) return <int>{};
      return decoded
          .map((item) => int.tryParse(item.toString()))
          .whereType<int>()
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<void> _saveTrackedReminderIds(Set<int> ids) async {
    if (ids.isEmpty) {
      await _storage.delete(key: _keyTrackedReminderIds);
      return;
    }

    final sortedIds = ids.toList()..sort();
    await _storage.write(
      key: _keyTrackedReminderIds,
      value: json.encode(sortedIds),
    );
  }

  static Future<void> _trackReminderId(int notificationId) async {
    final trackedIds = await _trackedReminderIds();
    trackedIds.add(notificationId);
    await _saveTrackedReminderIds(trackedIds);
  }

  static Future<void> _untrackReminderId(int notificationId) async {
    final trackedIds = await _trackedReminderIds();
    trackedIds.remove(notificationId);
    await _saveTrackedReminderIds(trackedIds);
  }

  static String _ianaTimeZoneName() => 'Asia/Hong_Kong';
}
