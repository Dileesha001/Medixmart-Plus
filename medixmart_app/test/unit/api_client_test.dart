import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medixmart_app/models/api_exception.dart';
import 'package:medixmart_app/models/user_model.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/services/api_client.dart';

class _InMemoryTokenStorage implements TokenStorage {
  final Map<String, String> store;

  _InMemoryTokenStorage([Map<String, String>? initial])
      : store = Map<String, String>.from(initial ?? const {});

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    store.remove(key);
  }
}

void main() {
  group('ApiException', () {
    test('fromJson parses error code, message, details, and fieldError lookup',
        () {
      final ex = ApiException.fromJson(
        {
          'success': false,
          'error': {
            'code': 'VALIDATION_ERROR',
            'message': 'Invalid medicine details provided.',
            'details': [
              {'field': 'name', 'message': 'Medicine name is required.'},
              {
                'field': 'selling_price',
                'message': 'Selling price must be a non-negative number.',
              },
            ],
          },
        },
        400,
      );

      expect(ex.code, 'VALIDATION_ERROR');
      expect(ex.message, 'Invalid medicine details provided.');
      expect(ex.statusCode, 400);
      expect(ex.isValidation, isTrue);
      expect(ex.isDuplicate, isFalse);
      expect(ex.isForbidden, isFalse);
      expect(ex.isSessionRevoked, isFalse);
      expect(ex.details.length, 2);
      expect(ex.fieldError('name'), 'Medicine name is required.');
      expect(
        ex.fieldError('selling_price'),
        'Selling price must be a non-negative number.',
      );
      expect(ex.fieldError('category_id'), isNull);
    });

    test(
        'isSessionRevoked matches exact allowlist and excludes AUTH_INVALID_CREDENTIALS and AUTH_FORBIDDEN_ROLE',
        () {
      const revokingCodes = [
        'AUTH_MISSING_TOKEN',
        'AUTH_INVALID_TOKEN',
        'AUTH_EXPIRED_TOKEN',
        'AUTH_SESSION_REVOKED',
        'AUTH_ACCOUNT_DISABLED',
      ];
      for (final code in revokingCodes) {
        final ex = ApiException(
          code: code,
          message: 'Revoked',
          statusCode: code == 'AUTH_ACCOUNT_DISABLED' ? 403 : 401,
        );
        expect(ex.isSessionRevoked, isTrue, reason: '$code should revoke');
      }

      const nonRevokingCodes = [
        'AUTH_INVALID_CREDENTIALS',
        'AUTH_FORBIDDEN_ROLE',
        'VALIDATION_ERROR',
        'DUPLICATE_ENTRY',
      ];
      for (final code in nonRevokingCodes) {
        final ex = ApiException(
          code: code,
          message: 'Non-revoking',
          statusCode: code == 'AUTH_INVALID_CREDENTIALS' ? 401 : 403,
        );
        expect(
          ex.isSessionRevoked,
          isFalse,
          reason: '$code must NOT revoke session',
        );
      }
    });
  });

  group('ApiClient', () {
    test(
        'attaches Bearer token from medixmart_jwt_token, omits null query params, and omits auth when requiresAuth is false',
        () async {
      final capturedRequests = <http.Request>[];
      final mockClient = MockClient((request) async {
        capturedRequests.add(request);
        return http.Response(
          jsonEncode({'success': true, 'data': []}),
          200,
        );
      });

      final storage = _InMemoryTokenStorage({
        AuthProvider.tokenStorageKey: 'jwt-abc-123',
      });
      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: storage,
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );

      await apiClient.get(
        '/medicines',
        queryParameters: {'search': 'para', 'category_id': null, 'page': 2},
      );
      await apiClient.get('/health', requiresAuth: false);

      expect(capturedRequests.length, 2);
      expect(
        capturedRequests[0].headers['Authorization'],
        'Bearer jwt-abc-123',
      );
      expect(capturedRequests[0].url.queryParameters, {
        'search': 'para',
        'page': '2',
      });
      expect(capturedRequests[1].headers.containsKey('Authorization'), isFalse);
    });

    test('supports post, put, patch, and delete with JSON payloads', () async {
      final methodsAndBodies = <String>[];
      final mockClient = MockClient((request) async {
        methodsAndBodies.add('${request.method}:${request.url.path}:${request.body}');
        return http.Response(
          jsonEncode({'success': true, 'data': {'ok': true}}),
          request.method == 'POST' ? 201 : 200,
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: _InMemoryTokenStorage({
          AuthProvider.tokenStorageKey: 'tok',
        }),
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );

      await apiClient.post('/categories', body: {'name': 'Painkillers'});
      await apiClient.put('/medicines/1', body: {'name': 'Panadol'});
      await apiClient.patch('/medicines/1/deactivate');
      await apiClient.delete('/medicines/1');

      expect(methodsAndBodies, [
        'POST:/api/categories:{"name":"Painkillers"}',
        'PUT:/api/medicines/1:{"name":"Panadol"}',
        'PATCH:/api/medicines/1/deactivate:',
        'DELETE:/api/medicines/1:',
      ]);
    });

    test(
        'normalizes SocketException, TimeoutException, and malformed non-JSON responses into ApiException',
        () async {
      final socketClient = ApiClient(
        httpClient: MockClient((_) async {
          throw const SocketException('Connection refused');
        }),
        tokenStorage: _InMemoryTokenStorage(),
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );
      await expectLater(
        socketClient.get('/medicines'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'NETWORK_ERROR')
              .having((e) => e.statusCode, 'statusCode', 0),
        ),
      );

      final timeoutClient = ApiClient(
        httpClient: MockClient((_) async {
          throw TimeoutException('Timed out');
        }),
        tokenStorage: _InMemoryTokenStorage(),
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );
      await expectLater(
        timeoutClient.get('/medicines'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'REQUEST_TIMEOUT')
              .having((e) => e.statusCode, 'statusCode', 408),
        ),
      );

      final htmlClient = ApiClient(
        httpClient: MockClient((_) async => http.Response('<html>502</html>', 502)),
        tokenStorage: _InMemoryTokenStorage(),
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );
      await expectLater(
        htmlClient.get('/medicines'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'INVALID_RESPONSE')
              .having((e) => e.statusCode, 'statusCode', 502),
        ),
      );
    });

    test(
        'revokes session, deletes medixmart_jwt_token, and calls onSessionRevoked on 401 AUTH_SESSION_REVOKED and 403 AUTH_ACCOUNT_DISABLED',
        () async {
      for (final scenario in [
        (401, 'AUTH_SESSION_REVOKED', 'Session has been revoked.'),
        (403, 'AUTH_ACCOUNT_DISABLED', 'Your account has been disabled.'),
      ]) {
        final storage = _InMemoryTokenStorage({
          AuthProvider.tokenStorageKey: 'live-token',
        });
        String? revokedReason;
        final apiClient = ApiClient(
          httpClient: MockClient((_) async {
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': scenario.$2, 'message': scenario.$3},
              }),
              scenario.$1,
            );
          }),
          tokenStorage: storage,
          baseUrlOverride: 'http://127.0.0.1:3000/api',
          onSessionRevoked: (reason) => revokedReason = reason,
        );

        await expectLater(
          apiClient.get('/medicines'),
          throwsA(
            isA<ApiException>().having((e) => e.code, 'code', scenario.$2),
          ),
        );
        expect(storage.store.containsKey(AuthProvider.tokenStorageKey), isFalse);
        expect(revokedReason, scenario.$3);
      }
    });

    test(
        'does NOT revoke session on protected 401 AUTH_INVALID_CREDENTIALS or 403 AUTH_FORBIDDEN_ROLE',
        () async {
      for (final scenario in [
        (401, 'AUTH_INVALID_CREDENTIALS', 'Current password is incorrect.'),
        (403, 'AUTH_FORBIDDEN_ROLE', 'Admin role required.'),
      ]) {
        final storage = _InMemoryTokenStorage({
          AuthProvider.tokenStorageKey: 'still-valid-token',
        });
        var revokedCalled = false;
        final apiClient = ApiClient(
          httpClient: MockClient((_) async {
            return http.Response(
              jsonEncode({
                'success': false,
                'error': {'code': scenario.$2, 'message': scenario.$3},
              }),
              scenario.$1,
            );
          }),
          tokenStorage: storage,
          baseUrlOverride: 'http://127.0.0.1:3000/api',
          onSessionRevoked: (_) => revokedCalled = true,
        );

        await expectLater(
          apiClient.put('/auth/change-password', body: {'current_password': 'bad'}),
          throwsA(
            isA<ApiException>().having((e) => e.code, 'code', scenario.$2),
          ),
        );
        expect(revokedCalled, isFalse);
        expect(
          storage.store[AuthProvider.tokenStorageKey],
          'still-valid-token',
        );
      }
    });
  });

  group('AuthProvider.handleSessionRevoked', () {
    test('clears token, sets unauthenticated status, and surfaces reason message',
        () async {
      final storage = _InMemoryTokenStorage({
        AuthProvider.tokenStorageKey: 'old-jwt',
      });
      final provider = AuthProvider(
        tokenStorage: storage,
        initialStatus: AuthStatus.authenticated,
        initialUser: const UserModel(id: 1, username: 'admin', role: 'admin'),
        initialToken: 'old-jwt',
      );

      await provider.handleSessionRevoked('Your account has been disabled.');

      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.isAuthenticated, isFalse);
      expect(provider.user, isNull);
      expect(provider.token, isNull);
      expect(provider.errorMessage, 'Your account has been disabled.');
      expect(storage.store.containsKey(AuthProvider.tokenStorageKey), isFalse);
      expect(provider.tokenStorage, same(storage));
    });
  });
}
