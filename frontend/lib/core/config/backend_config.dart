import 'dart:io';

import 'package:flutter/foundation.dart';

class BackendConfig {
  BackendConfig._();

  // Override via: flutter run --dart-define-from-file=dart_defines.json
  // dart_defines.json example: { "BASE_URL": "http://192.168.x.x:8000" }
  static const _envBaseUrl = String.fromEnvironment('BASE_URL');

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) return _envBaseUrl;
    if (kIsWeb) return 'http://localhost:8000';
    if (Platform.isAndroid) return 'http://10.0.2.2:8000'; // Android emulator
    return 'http://localhost:8000'; // iOS Simulator
  }

  /// Fallback coordinates used when the device location is unavailable.
  /// Points to HKU Main Library so the backend can still return nearby results.
  static const double defaultLatitude = 22.2830;
  static const double defaultLongitude = 114.1371;
}
