import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  static const _storage = FlutterSecureStorage();
  static const _keyEnabled = 'notif_enabled';
  static const _keyMinutes = 'notif_reminder_minutes';

  bool _enabled = true;
  int _reminderMinutes = 30;

  bool get enabled => _enabled;
  int get reminderMinutes => _reminderMinutes;

  static const List<int> reminderOptions = [15, 30, 60];

  NotificationProvider() {
    _load();
  }

  Future<void> _load() async {
    final enabled = await _storage.read(key: _keyEnabled);
    final minutes = await _storage.read(key: _keyMinutes);
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
    await _storage.write(key: _keyEnabled, value: value ? 'true' : 'false');
    await NotificationService.setReminderEnabled(value);
    return true;
  }

  Future<void> setReminderMinutes(int minutes) async {
    if (_reminderMinutes == minutes) return;
    _reminderMinutes = minutes;
    notifyListeners();
    await _storage.write(key: _keyMinutes, value: minutes.toString());
    await NotificationService.setReminderMinutes(minutes);
  }
}
