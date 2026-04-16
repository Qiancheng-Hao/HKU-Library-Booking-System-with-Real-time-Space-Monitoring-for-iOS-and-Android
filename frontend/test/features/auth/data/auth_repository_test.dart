import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';

import '../../../helpers/fake_api_client.dart';
import '../../../helpers/memory_session_store.dart';

void main() {
  group('AuthRepository', () {
    test('login posts credentials and persists session', () async {
      final sessionStore = MemorySessionStore();
      final client = FakeApiClient()
        ..postResponses['/api/v1/auth/login'] = {'access_token': 'token-1'};
      final repository = AuthRepository(client, sessionStore: sessionStore);

      await repository.login('user@example.com', 'secret');

      expect(client.lastCall.path, '/api/v1/auth/login');
      expect(client.lastCall.authenticated, isFalse);
      expect(client.lastCall.body, {
        'email': 'user@example.com',
        'password': 'secret',
      });
      expect(await sessionStore.getToken(), 'token-1');
      expect(await sessionStore.getUserEmail(), 'user@example.com');
    });

    test('register posts profile payload unauthenticated', () async {
      final client = FakeApiClient();
      final repository = AuthRepository(client);

      await repository.register(
        email: 'user@example.com',
        password: 'secret',
        fullName: 'Test User',
      );

      expect(client.lastCall.path, '/api/v1/auth/register');
      expect(client.lastCall.authenticated, isFalse);
      expect(client.lastCall.successCodes, {200, 201});
      expect(client.lastCall.body, {
        'email': 'user@example.com',
        'password': 'secret',
        'full_name': 'Test User',
      });
    });

    test('getUserProfile parses profile response', () async {
      final client = FakeApiClient()
        ..getResponses['/api/v1/auth/me'] = {
          'full_name': 'Test User',
          'email': 'user@example.com',
        };
      final repository = AuthRepository(client);

      final profile = await repository.getUserProfile();

      expect(profile.fullName, 'Test User');
      expect(profile.email, 'user@example.com');
      expect(client.lastCall.path, '/api/v1/auth/me');
    });
  });
}
