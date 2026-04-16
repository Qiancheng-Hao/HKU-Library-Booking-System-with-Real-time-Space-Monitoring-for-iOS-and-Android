import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/models/auth_models.dart';
import 'package:frontend/core/network/http_api_client.dart';
import 'package:frontend/features/auth/data/auth_repository.dart';
import 'package:frontend/providers/auth_provider.dart';

void main() {
  group('AuthProvider', () {
    test(
      'initial check signs in stored sessions and syncs reminders',
      () async {
        var syncCount = 0;
        final provider = AuthProvider(
          authRepository: _FakeAuthRepository(
            hasSession: true,
            profile: const UserProfile(
              fullName: 'Test User',
              email: 'user@example.com',
            ),
          ),
          syncUpcomingReminders: () async {
            syncCount += 1;
          },
        );

        await pumpEventQueue();

        expect(provider.isLoading, isFalse);
        expect(provider.isLoggedIn, isTrue);
        expect(provider.userName, 'Test User');
        expect(provider.userEmail, 'user@example.com');
        expect(syncCount, 1);
      },
    );

    test('initial check signs out when no stored session exists', () async {
      final provider = AuthProvider(
        authRepository: _FakeAuthRepository(hasSession: false),
        syncUpcomingReminders: () async {},
      );

      await pumpEventQueue();

      expect(provider.isLoading, isFalse);
      expect(provider.isLoggedIn, isFalse);
    });

    test('login persists logged-in state and syncs reminders', () async {
      var syncCount = 0;
      final repository = _FakeAuthRepository(
        hasSession: false,
        profile: const UserProfile(
          fullName: 'Logged User',
          email: 'logged@example.com',
        ),
      );
      final provider = AuthProvider(
        authRepository: repository,
        syncUpcomingReminders: () async {
          syncCount += 1;
        },
      );
      await pumpEventQueue();

      await provider.login('logged@example.com', 'secret');

      expect(repository.loginEmail, 'logged@example.com');
      expect(provider.isLoggedIn, isTrue);
      expect(provider.userName, 'Logged User');
      expect(provider.userEmail, 'logged@example.com');
      expect(syncCount, 1);
    });

    test('profile failure falls back to stored email', () async {
      final repository = _FakeAuthRepository(
        hasSession: true,
        profileError: StateError('profile down'),
        storedEmail: 'stored@example.com',
      );
      final provider = AuthProvider(
        authRepository: repository,
        syncUpcomingReminders: () async {},
      );

      await pumpEventQueue();

      expect(provider.isLoggedIn, isTrue);
      expect(provider.userEmail, 'stored@example.com');
      expect(provider.userName, isNull);
    });

    test('logout clears auth state and cancels reminders', () async {
      var cancelCount = 0;
      final provider = AuthProvider(
        authRepository: _FakeAuthRepository(
          hasSession: true,
          profile: const UserProfile(fullName: 'Test User'),
        ),
        syncUpcomingReminders: () async {},
        cancelAllBookingReminders: () async {
          cancelCount += 1;
        },
      );
      await pumpEventQueue();

      await provider.logout();

      expect(provider.isLoggedIn, isFalse);
      expect(provider.userName, isNull);
      expect(provider.userEmail, isNull);
      expect(cancelCount, 1);
    });
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository({
    required this.hasSession,
    this.profile,
    this.profileError,
    this.storedEmail,
  }) : super(HttpApiClient());

  bool hasSession;
  UserProfile? profile;
  Object? profileError;
  String? storedEmail;
  String? loginEmail;

  @override
  Future<void> login(String email, String password) async {
    loginEmail = email;
    hasSession = true;
  }

  @override
  Future<void> logout() async {
    hasSession = false;
  }

  @override
  Future<bool> hasStoredSession() async => hasSession;

  @override
  Future<String?> getStoredUserEmail() async => storedEmail;

  @override
  Future<UserProfile> getUserProfile() async {
    final currentError = profileError;
    if (currentError != null) throw currentError;
    return profile ?? const UserProfile();
  }
}
