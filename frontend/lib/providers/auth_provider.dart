import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _userName;
  String? _userEmail;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get userName => _userName;
  String? get userEmail => _userEmail;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    try {
      final token = await ApiService.getToken();
      if (token != null) {
        _isLoggedIn = true;
        await _fetchUserProfile();
        await NotificationService.syncUpcomingReminders();
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
    await ApiService.login(email, password);
    _isLoggedIn = true;
    await _fetchUserProfile();
    await NotificationService.syncUpcomingReminders();
    notifyListeners();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final profile = await ApiService.getUserProfile();
      _userName = profile['full_name'];
      _userEmail =
          profile['email'] as String? ?? await ApiService.getUserEmail();
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      _userEmail = await ApiService.getUserEmail();
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    await NotificationService.cancelAllBookingReminders();
    _isLoggedIn = false;
    _userName = null;
    _userEmail = null;
    notifyListeners();
  }
}
