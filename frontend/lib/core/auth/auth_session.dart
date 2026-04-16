import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SessionStore {
  Future<void> persistSession({required String token, required String email});
  Future<void> clear();
  Future<String?> getToken();
  Future<String?> getUserEmail();
  Future<bool> hasToken();
}

class SecureSessionStore implements SessionStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';
  static const String _userEmailKey = 'user_email';

  const SecureSessionStore();

  @override
  Future<void> persistSession({
    required String token,
    required String email,
  }) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userEmailKey, value: email);
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userEmailKey);
  }

  @override
  Future<String?> getToken() {
    return _storage.read(key: _tokenKey);
  }

  @override
  Future<String?> getUserEmail() {
    return _storage.read(key: _userEmailKey);
  }

  @override
  Future<bool> hasToken() async {
    return (await getToken()) != null;
  }
}

class AuthSession {
  AuthSession._();

  static SessionStore _store = const SecureSessionStore();
  static VoidCallback? _onUnauthorized;

  static SessionStore get store => _store;

  @visibleForTesting
  static void configureStore(SessionStore store) {
    _store = store;
  }

  @visibleForTesting
  static void resetStore() {
    _store = const SecureSessionStore();
    _onUnauthorized = null;
  }

  static void registerUnauthorizedHandler(VoidCallback handler) {
    _onUnauthorized = handler;
  }

  static Future<void> persistSession({
    required String token,
    required String email,
  }) async {
    await _store.persistSession(token: token, email: email);
  }

  static Future<void> clear() async {
    await _store.clear();
  }

  static Future<String?> getToken() {
    return _store.getToken();
  }

  static Future<String?> getUserEmail() {
    return _store.getUserEmail();
  }

  static Future<bool> hasToken() async {
    return _store.hasToken();
  }

  static Future<void> handleUnauthorized({SessionStore? store}) async {
    await (store ?? _store).clear();
    _onUnauthorized?.call();
  }
}
