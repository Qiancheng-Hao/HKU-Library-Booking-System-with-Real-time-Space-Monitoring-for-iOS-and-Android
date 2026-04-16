import 'dart:convert';
import 'package:http/http.dart' as http;
import '../auth/auth_session.dart';
import '../config/backend_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Object? body;

  const ApiException(this.message, {this.statusCode, this.body});

  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException([super.message = 'Not authenticated'])
    : super(statusCode: 401);
}

abstract interface class ApiClient {
  Future<dynamic> getJson(
    String path, {
    bool authenticated = true,
    Set<int> successCodes = const {200},
  });

  Future<dynamic> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
    Set<int> successCodes = const {200},
  });

  Future<void> delete(
    String path, {
    bool authenticated = true,
    Set<int> successCodes = const {200, 204},
  });
}

class HttpApiClient implements ApiClient {
  final http.Client _client;
  final SessionStore _sessionStore;
  final Future<void> Function(SessionStore store) _handleUnauthorized;

  HttpApiClient({
    http.Client? client,
    SessionStore? sessionStore,
    Future<void> Function(SessionStore store)? handleUnauthorized,
  }) : _client = client ?? http.Client(),
       _sessionStore = sessionStore ?? AuthSession.store,
       _handleUnauthorized =
           handleUnauthorized ??
           ((store) => AuthSession.handleUnauthorized(store: store));

  @override
  Future<dynamic> getJson(
    String path, {
    bool authenticated = true,
    Set<int> successCodes = const {200},
  }) async {
    final response = await _client.get(
      Uri.parse('${BackendConfig.baseUrl}$path'),
      headers: await _buildHeaders(authenticated: authenticated),
    );
    return _parseResponse(response, successCodes: successCodes);
  }

  @override
  Future<dynamic> postJson(
    String path, {
    Object? body,
    bool authenticated = true,
    Set<int> successCodes = const {200},
  }) async {
    final response = await _client.post(
      Uri.parse('${BackendConfig.baseUrl}$path'),
      headers: await _buildHeaders(authenticated: authenticated),
      body: body == null ? null : json.encode(body),
    );
    return _parseResponse(response, successCodes: successCodes);
  }

  @override
  Future<void> delete(
    String path, {
    bool authenticated = true,
    Set<int> successCodes = const {200, 204},
  }) async {
    final response = await _client.delete(
      Uri.parse('${BackendConfig.baseUrl}$path'),
      headers: await _buildHeaders(authenticated: authenticated),
    );
    await _parseResponse(response, successCodes: successCodes);
  }

  Future<Map<String, String>> _buildHeaders({
    required bool authenticated,
  }) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (!authenticated) return headers;

    final token = await _sessionStore.getToken();
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> _parseResponse(
    http.Response response, {
    required Set<int> successCodes,
  }) async {
    if (response.statusCode == 401) {
      await _handleUnauthorized(_sessionStore);
      throw const UnauthorizedException();
    }

    if (successCodes.contains(response.statusCode)) {
      if (response.body.isEmpty) return null;
      return json.decode(response.body);
    }

    final body = _tryDecodeBody(response.body);
    throw ApiException(
      _extractErrorMessage(response, decodedBody: body),
      statusCode: response.statusCode,
      body: body,
    );
  }

  Object? _tryDecodeBody(String body) {
    if (body.isEmpty) return null;
    try {
      return json.decode(body);
    } catch (_) {
      return body;
    }
  }

  String _extractErrorMessage(http.Response response, {Object? decodedBody}) {
    final body = decodedBody;
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }
    return 'Request failed (${response.statusCode})';
  }
}
