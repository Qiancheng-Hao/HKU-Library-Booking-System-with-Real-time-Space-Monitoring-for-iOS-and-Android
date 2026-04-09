import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'api_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _enabledKey = 'notif_enabled';
  static const String _minutesKey = 'notif_reminder_minutes';
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

  static Future<bool> isReminderEnabled() async {
    final enabled = await _storage.read(key: _enabledKey);
    return enabled != 'false';
  }

  static Future<int> getReminderMinutes() async {
    final minutes = await _storage.read(key: _minutesKey);
    return int.tryParse(minutes ?? '') ?? 30;
  }

  static Future<void> setReminderEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
    if (!enabled) {
      await cancelAllBookingReminders();
      return;
    }
    await syncUpcomingReminders();
  }

  static Future<void> setReminderMinutes(int minutes) async {
    await _storage.write(key: _minutesKey, value: minutes.toString());
    if (await isReminderEnabled()) {
      await syncUpcomingReminders();
    }
  }

  static Future<void> syncUpcomingReminders() async {
    await initialize();

    if (!await isReminderEnabled()) {
      await cancelAllBookingReminders();
      return;
    }

    final hasPermission = await ensurePermissions();
    if (!hasPermission) return;

    final reservations = await ApiService.getUserReservations();
    await cancelAllBookingReminders();

    for (final reservation in reservations) {
      await scheduleReservationReminder(reservation);
    }
  }

  static Future<void> scheduleReservationReminder(
    Map<String, dynamic> reservation,
  ) async {
    await initialize();

    if (!await isReminderEnabled()) return;

    final status = reservation['status']?.toString().toLowerCase();
    if (status != 'confirmed' && status != 'pending') return;

    final reminderMinutes = await getReminderMinutes();
    final scheduledAt = _reservationStart(
      reservation,
    ).subtract(Duration(minutes: reminderMinutes));
    final now = DateTime.now();

    if (!scheduledAt.isAfter(now)) return;

    final facility = (reservation['facility'] as Map<String, dynamic>? ?? {});
    final facilityName = facility['name']?.toString() ?? 'Reserved facility';
    final libraryName = facility['library_name']?.toString() ?? 'HKU Library';
    final notificationId = _notificationIdFor(reservation['id'].toString());
    final startTime = reservation['start_time']?.toString().substring(0, 5);

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Booking reminder',
      body: '$facilityName starts at $startTime in $libraryName.',
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: reservation['id']?.toString(),
    );
  }

  static Future<void> cancelReservationReminder(String reservationId) async {
    await initialize();
    await _plugin.cancel(id: _notificationIdFor(reservationId));
  }

  static Future<void> cancelAllBookingReminders() async {
    await initialize();
    await _plugin.cancelAll();
  }

  static int _notificationIdFor(String reservationId) {
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

  static DateTime _reservationStart(Map<String, dynamic> reservation) {
    final date = reservation['reservation_date']?.toString() ?? '';
    final startTime = reservation['start_time']?.toString() ?? '00:00:00';
    return DateTime.parse('${date}T$startTime');
  }

  static String _ianaTimeZoneName() {
    if (Platform.isIOS || Platform.isMacOS) {
      return 'Asia/Hong_Kong';
    }
    return 'Asia/Hong_Kong';
  }
}
