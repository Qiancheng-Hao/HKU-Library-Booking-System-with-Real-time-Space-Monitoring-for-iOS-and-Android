import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _userName;

  bool get isLoggedIn => _isLoggedIn;
  bool get isLoading => _isLoading;
  String? get userName => _userName;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final token = await ApiService.getToken();
    if (token != null) {
      _isLoggedIn = true;
      await _fetchUserProfile();
    } else {
      _isLoggedIn = false;
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await ApiService.login(email, password);
    _isLoggedIn = true;
    await _fetchUserProfile();
    notifyListeners();
  }

  Future<void> _fetchUserProfile() async {
    try {
      final profile = await ApiService.getUserProfile();
      _userName = profile['full_name'];
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    _isLoggedIn = false;
    _userName = null;
    notifyListeners();
  }
}
