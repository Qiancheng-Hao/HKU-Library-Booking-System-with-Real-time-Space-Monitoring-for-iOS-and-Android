import '../../../core/auth/auth_session.dart';
import '../../../core/models/auth_models.dart';
import '../../../core/models/json_helpers.dart';
import '../../../core/network/http_api_client.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SessionStore _sessionStore;

  AuthRepository(this._apiClient, {SessionStore? sessionStore})
    : _sessionStore = sessionStore ?? AuthSession.store;

  Future<void> login(String email, String password) async {
    final data = LoginResponse.fromJson(
      asJsonMap(
        await _apiClient.postJson(
          '/api/v1/auth/login',
          authenticated: false,
          successCodes: const {200},
          body: {'email': email, 'password': password},
        ),
      ),
    );

    await _sessionStore.persistSession(token: data.accessToken, email: email);
  }

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) {
    return _apiClient.postJson(
      '/api/v1/auth/register',
      authenticated: false,
      successCodes: const {200, 201},
      body: {'email': email, 'password': password, 'full_name': fullName},
    );
  }

  Future<void> logout() {
    return _sessionStore.clear();
  }

  Future<bool> hasStoredSession() {
    return _sessionStore.hasToken();
  }

  Future<String?> getStoredUserEmail() {
    return _sessionStore.getUserEmail();
  }

  Future<String?> getStoredToken() {
    return _sessionStore.getToken();
  }

  Future<UserProfile> getUserProfile() async {
    return UserProfile.fromJson(
      asJsonMap(await _apiClient.getJson('/api/v1/auth/me')),
    );
  }
}
