import 'package:flutter/material.dart';

import '../../data/auth_repository.dart';

class RegisterController extends ChangeNotifier {
  final AuthRepository _authRepository;

  RegisterController({required AuthRepository authRepository})
    : _authRepository = authRepository;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  Future<void> register({
    required String email,
    required String password,
    required String fullName,
  }) async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _authRepository.register(
        email: email,
        password: password,
        fullName: fullName,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
