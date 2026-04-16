import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/core/auth/auth_session.dart';
import 'package:frontend/core/config/backend_config.dart';
import 'package:frontend/core/network/http_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/memory_session_store.dart';

void main() {
  group('HttpApiClient', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      AuthSession.resetStore();
    });

    tearDown(AuthSession.resetStore);

    test('getJson decodes successful JSON responses', () async {
      final client = HttpApiClient(
        client: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), '${BackendConfig.baseUrl}/ok');
          return http.Response('{"ok":true}', 200);
        }),
      );

      final data = await client.getJson('/ok', authenticated: false);

      expect(data, {'ok': true});
    });

    test('getJson returns null for successful empty responses', () async {
      final client = HttpApiClient(
        client: MockClient((request) async => http.Response('', 204)),
      );

      final data = await client.getJson(
        '/empty',
        authenticated: false,
        successCodes: const {204},
      );

      expect(data, isNull);
    });

    test('postJson sends JSON body and content-type header', () async {
      final client = HttpApiClient(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.headers['Content-Type'], 'application/json');
          expect(json.decode(request.body), {'name': 'HKU'});
          return http.Response('{"created":true}', 201);
        }),
      );

      final data = await client.postJson(
        '/create',
        authenticated: false,
        successCodes: const {201},
        body: {'name': 'HKU'},
      );

      expect(data, {'created': true});
    });

    test(
      'authenticated requests include bearer token when available',
      () async {
        final sessionStore = MemorySessionStore(token: 'token-1');
        final client = HttpApiClient(
          sessionStore: sessionStore,
          client: MockClient((request) async {
            expect(request.headers['Authorization'], 'Bearer token-1');
            return http.Response('{}', 200);
          }),
        );

        await client.getJson('/secure');
      },
    );

    test('unauthenticated requests omit bearer token', () async {
      final sessionStore = MemorySessionStore(token: 'token-1');
      final client = HttpApiClient(
        sessionStore: sessionStore,
        client: MockClient((request) async {
          expect(request.headers.containsKey('Authorization'), isFalse);
          return http.Response('{}', 200);
        }),
      );

      await client.getJson('/public', authenticated: false);
    });

    test('delete accepts configured success code', () async {
      final client = HttpApiClient(
        client: MockClient((request) async {
          expect(request.method, 'DELETE');
          expect(request.url.toString(), '${BackendConfig.baseUrl}/item/1');
          return http.Response('', 204);
        }),
      );

      await client.delete('/item/1');
    });

    test(
      '401 clears session, calls unauthorized handler, and throws',
      () async {
        final sessionStore = MemorySessionStore(
          token: 'token-1',
          email: 'user@example.com',
        );
        var unauthorizedHandled = false;
        Future<void> handleUnauthorized(SessionStore store) async {
          await store.clear();
          unauthorizedHandled = true;
        }

        final client = HttpApiClient(
          sessionStore: sessionStore,
          handleUnauthorized: handleUnauthorized,
          client: MockClient((request) async {
            return http.Response('{"detail":"expired"}', 401);
          }),
        );

        await expectLater(
          client.getJson('/secure'),
          throwsA(isA<UnauthorizedException>()),
        );

        expect(unauthorizedHandled, isTrue);
        expect(await sessionStore.getToken(), isNull);
        expect(await sessionStore.getUserEmail(), isNull);
      },
    );

    test(
      'error responses expose detail, status code, and decoded body',
      () async {
        final client = HttpApiClient(
          client: MockClient((request) async {
            return http.Response('{"detail":"Invalid input"}', 422);
          }),
        );

        await expectLater(
          client.getJson('/bad', authenticated: false),
          throwsA(
            isA<ApiException>()
                .having((e) => e.message, 'message', 'Invalid input')
                .having((e) => e.statusCode, 'statusCode', 422)
                .having((e) => e.body, 'body', {'detail': 'Invalid input'}),
          ),
        );
      },
    );

    test('non-JSON error responses fall back to status message', () async {
      final client = HttpApiClient(
        client: MockClient((request) async {
          return http.Response('server exploded', 500);
        }),
      );

      await expectLater(
        client.getJson('/bad', authenticated: false),
        throwsA(
          isA<ApiException>()
              .having((e) => e.message, 'message', 'Request failed (500)')
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.body, 'body', 'server exploded'),
        ),
      );
    });
  });

  group('ApiException', () {
    test('keeps message as string representation', () {
      const exception = ApiException(
        'Validation failed',
        statusCode: 422,
        body: {'detail': 'Validation failed'},
      );

      expect(exception.toString(), 'Validation failed');
      expect(exception.statusCode, 422);
      expect(exception.body, {'detail': 'Validation failed'});
    });

    test('UnauthorizedException carries 401 status code', () {
      const exception = UnauthorizedException();

      expect(exception.toString(), 'Not authenticated');
      expect(exception.statusCode, 401);
    });
  });
}
