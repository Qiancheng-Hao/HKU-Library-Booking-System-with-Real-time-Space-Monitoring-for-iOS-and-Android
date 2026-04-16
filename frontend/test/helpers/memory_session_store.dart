import 'package:frontend/core/auth/auth_session.dart';

class MemorySessionStore implements SessionStore {
  String? token;
  String? email;
  var clearCount = 0;

  MemorySessionStore({this.token, this.email});

  @override
  Future<void> persistSession({
    required String token,
    required String email,
  }) async {
    this.token = token;
    this.email = email;
  }

  @override
  Future<void> clear() async {
    clearCount += 1;
    token = null;
    email = null;
  }

  @override
  Future<String?> getToken() async => token;

  @override
  Future<String?> getUserEmail() async => email;

  @override
  Future<bool> hasToken() async => token != null;
}
