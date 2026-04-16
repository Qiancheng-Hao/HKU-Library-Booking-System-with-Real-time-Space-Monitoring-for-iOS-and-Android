import 'package:flutter/material.dart';

import '../../../../providers/auth_provider.dart';

/// Controller for the login form.
///
/// Intentionally depends on [AuthProvider] rather than [AuthRepository]:
/// a successful login needs to flip the global auth state (and trigger the
/// downstream notification sync inside [AuthProvider.login]), which is
/// [AuthProvider]'s responsibility. Going through the repository directly
/// would leave the app-wide session state stale.
class LoginController extends ChangeNotifier {
  final AuthProvider _authProvider;

  LoginController({required AuthProvider authProvider})
    : _authProvider = authProvider;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> login({required String email, required String password}) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _authProvider.login(email, password);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
