import 'package:flutter/foundation.dart';
import '../network/http_api_client.dart';

/// Base class for controllers that expose a single async operation's state
/// (loading + error) to the UI.
///
/// Subclasses should call [runGuarded] to wrap async actions — it toggles
/// [isLoading], captures errors into [errorMessage], and notifies listeners.
/// Use [clearError] when the UI wants to dismiss an error banner.
abstract class BaseAsyncController extends ChangeNotifier {
  bool _isLoading = false;
  String? _errorMessage;
  bool _isDisposed = false;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasError => _errorMessage != null;

  @protected
  void setLoading(bool value) {
    if (_isLoading == value) return;
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  /// Runs [action] while managing [isLoading] and capturing errors into
  /// [errorMessage]. Returns the action's result, or `null` if it threw.
  @protected
  Future<T?> runGuarded<T>(Future<T> Function() action) async {
    _errorMessage = null;
    setLoading(true);
    try {
      return await action();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      return null;
    } finally {
      setLoading(false);
    }
  }

  @override
  void notifyListeners() {
    if (_isDisposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
