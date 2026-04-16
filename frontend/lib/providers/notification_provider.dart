import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/notification_service.dart';

/// UI-facing entry point for booking reminder settings.
///
/// Owns the persisted reminder state (enabled / lead time) and delegates
/// actual notification scheduling to [NotificationService]. UI code must
/// never read or write these settings through [NotificationService] directly,
/// to keep a single source of truth for reactivity.
class NotificationProvider with ChangeNotifier {
  static const _storage = FlutterSecureStorage();

  bool _enabled = true;
  int _reminderMinutes = 30;

  bool get enabled => _enabled;
  int get reminderMinutes => _reminderMinutes;

  static const List<int> reminderOptions = [15, 30, 60];

  NotificationProvider() {
    _load();
  }

  Future<void> _load() async {
    final enabled = await _storage.read(key: NotificationService.keyEnabled);
    final minutes = await _storage.read(
      key: NotificationService.keyReminderMinutes,
    );
    _enabled = enabled != 'false';
    _reminderMinutes = int.tryParse(minutes ?? '') ?? 30;
    notifyListeners();
  }

  Future<bool> setEnabled(bool value) async {
    if (_enabled == value) return true;
    if (value) {
      final granted = await NotificationService.ensurePermissions();
      if (!granted) {
        return false;
      }
    }

    _enabled = value;
    notifyListeners();
    await _storage.write(
      key: NotificationService.keyEnabled,
      value: value ? 'true' : 'false',
    );

    if (value) {
      await NotificationService.syncUpcomingReminders();
    } else {
      await NotificationService.cancelAllBookingReminders();
    }
    return true;
  }

  Future<void> setReminderMinutes(int minutes) async {
    if (_reminderMinutes == minutes) return;
    _reminderMinutes = minutes;
    notifyListeners();
    await _storage.write(
      key: NotificationService.keyReminderMinutes,
      value: minutes.toString(),
    );
    if (_enabled) {
      await NotificationService.syncUpcomingReminders();
    }
  }
}
