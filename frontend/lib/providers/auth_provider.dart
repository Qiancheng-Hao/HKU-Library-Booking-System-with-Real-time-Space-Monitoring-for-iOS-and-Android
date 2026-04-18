import 'package:flutter/material.dart';

import '../features/auth/data/auth_repository.dart';
import '../services/notification_service.dart';

typedef NotificationSyncer = Future<void> Function();
typedef NotificationCanceller = Future<void> Function();

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  final NotificationSyncer _syncUpcomingReminders;
  final NotificationCanceller _cancelAllBookingReminders;

  AuthProvider({
    required AuthRepository authRepository,
    NotificationSyncer? syncUpcomingReminders,
    NotificationCanceller? cancelAllBookingReminders,
  }) : _authRepository = authRepository,
       _syncUpcomingReminders =
           syncUpcomingReminders ?? NotificationService.syncUpcomingReminders,
       _cancelAllBookingReminders =
           cancelAllBookingReminders ??
           NotificationService.cancelAllBookingReminders {
    _checkLoginStatus();
  }

  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _userName;
  String? _userEmail;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  Future<void> _checkLoginStatus() async {
    try {
      if (await _authRepository.hasStoredSession()) {
        _isLoggedIn = true;
        await _fetchUserProfile();
        await _syncUpcomingRemindersQuietly();
      } else {
        _isLoggedIn = false;
      }
    } catch (e) {
      debugPrint('Error checking login status: $e');
      _isLoggedIn = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    _userName = null;
    _userEmail = null;
    await _authRepository.login(email, password);
    _isLoggedIn = true;
    await _fetchUserProfile();
    await _syncUpcomingRemindersQuietly();
    notifyListeners();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final profile = await _authRepository.getUserProfile();
      _userName = profile.fullName;
      _userEmail = profile.email ?? await _authRepository.getStoredUserEmail();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      _userEmail = await _authRepository.getStoredUserEmail();
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    await _cancelAllBookingReminders();
    _isLoggedIn = false;
    _userName = null;
    _userEmail = null;
    notifyListeners();
  }

  Future<void> _syncUpcomingRemindersQuietly() async {
    try {
      await _syncUpcomingReminders();
    } catch (e) {
      debugPrint('Error syncing booking reminders: $e');
    }
  }
}
