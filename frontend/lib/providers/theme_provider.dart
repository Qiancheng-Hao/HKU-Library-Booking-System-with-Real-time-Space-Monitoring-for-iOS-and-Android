import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ThemeProvider with ChangeNotifier {
  static const _key = 'theme_mode';
  static const _storage = FlutterSecureStorage();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final value = await _storage.read(key: _key);
    _themeMode = switch (value) {
      'light'  => ThemeMode.light,
      'system' => ThemeMode.system,
      _        => ThemeMode.dark,
    };
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _storage.write(
      key: _key,
      value: switch (mode) {
        ThemeMode.light  => 'light',
        ThemeMode.system => 'system',
        _                => 'dark',
      },
    );
  }
}
