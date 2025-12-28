import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AuthProvider with ChangeNotifier {
  bool _isLoggedIn = false;
  bool get isLoggedIn => _isLoggedIn;

  AuthProvider() {
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    final token = await ApiService.getToken();
    _isLoggedIn = token != null;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await ApiService.login(email, password);
    _isLoggedIn = true;
    notifyListeners();
  }

  Future<void> logout() async {
    await ApiService.logout();
    _isLoggedIn = false;
    notifyListeners();
  }
}
