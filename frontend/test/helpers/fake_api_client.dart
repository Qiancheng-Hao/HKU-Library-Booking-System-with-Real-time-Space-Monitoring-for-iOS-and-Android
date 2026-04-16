import 'package:frontend/core/network/http_api_client.dart';

class ApiCall {
  final String method;
  final String path;
  final Object? body;
  final bool authenticated;
  final Set<int> successCodes;

  const ApiCall({
    required this.method,
    required this.path,
    this.body,
    required this.authenticated,
    required this.successCodes,
  });
}

class FakeApiClient implements ApiClient {
  final Map<String, Object?> getResponses = {};
  final Map<String, Object?> postResponses = {};
  final Map<String, Object?> deleteResponses = {};
  final List<ApiCall> calls = [];

  Object? error;

  ApiCall get lastCall => calls.last;

  @override
  Future<dynamic> getJson(
    String path, {
    bool authenticated = true,
    Set<int> successCodes = const {200},
  }) async {
    final currentError = error;
    if (currentError != null) throw currentError;
    calls.add(
      ApiCall(
        method: 'GET',
        path: path,
        authenticated: authenticated,
        successCodes: successCodes,
      ),
    );
    return getResponses[path];
  }

  @override
  Future<dynamic> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
    Set<int> successCodes = const {200},
  }) async {
    final currentError = error;
    if (currentError != null) throw currentError;
    calls.add(
      ApiCall(
        method: 'POST',
        path: path,
        body: body,
        authenticated: authenticated,
        successCodes: successCodes,
      ),
    );
    return postResponses[path];
  }

  @override
  Future<void> delete(
    String path, {
    bool authenticated = true,
    Set<int> successCodes = const {200, 204},
  }) async {
    final currentError = error;
    if (currentError != null) throw currentError;
    calls.add(
      ApiCall(
        method: 'DELETE',
        path: path,
        authenticated: authenticated,
        successCodes: successCodes,
      ),
    );
    deleteResponses[path];
  }
}
