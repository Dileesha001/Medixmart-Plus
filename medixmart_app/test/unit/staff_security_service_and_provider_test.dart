import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medixmart_app/models/staff_user_model.dart';
import 'package:medixmart_app/models/user_model.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/providers/staff_user_provider.dart';
import 'package:medixmart_app/services/api_client.dart';
import 'package:medixmart_app/services/auth_service.dart';
import 'package:medixmart_app/services/staff_user_service.dart';

class _InMemoryTokenStorage implements TokenStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }
}

class _FakeStaffUserService extends StaffUserService {
  _FakeStaffUserService() : super(ApiClient());

  Future<List<StaffUserModel>> Function()? onFetchUsers;
  Future<StaffUserUpdateResult> Function(int id, bool isActive)?
      onUpdateStatus;
  Future<StaffUserUpdateResult> Function(int id, String role)? onUpdateRole;

  @override
  Future<List<StaffUserModel>> fetchUsers() async {
    if (onFetchUsers != null) return onFetchUsers!();
    return [
      StaffUserModel(
        id: 1,
        username: 'admin',
        role: 'admin',
        isActive: true,
        tokenVersion: 3,
        passwordChangedAt: DateTime.utc(2026, 11, 19),
        createdAt: DateTime.utc(2026, 10, 1),
      ),
      StaffUserModel(
        id: 2,
        username: 'nimal_pharm',
        role: 'pharmacist',
        isActive: true,
        tokenVersion: 1,
        passwordChangedAt: DateTime.utc(2026, 11, 10),
        createdAt: DateTime.utc(2026, 10, 18),
      ),
      StaffUserModel(
        id: 3,
        username: 'kasun_pharm',
        role: 'pharmacist',
        isActive: false,
        tokenVersion: 2,
        createdAt: DateTime.utc(2026, 10, 20),
        updatedAt: DateTime.utc(2026, 11, 4),
      ),
    ];
  }

  @override
  Future<StaffUserUpdateResult> updateUserStatus(
    int userId, {
    required bool isActive,
  }) async {
    if (onUpdateStatus != null) return onUpdateStatus!(userId, isActive);
    return StaffUserUpdateResult(
      message: isActive
          ? 'User account has been successfully activated.'
          : 'User account has been successfully deactivated.',
      user: StaffUserModel(
        id: userId,
        username: 'nimal_pharm',
        role: 'pharmacist',
        isActive: isActive,
        tokenVersion: 2,
      ),
    );
  }

  @override
  Future<StaffUserUpdateResult> updateUserRole(
    int userId, {
    required String role,
  }) async {
    if (onUpdateRole != null) return onUpdateRole!(userId, role);
    return StaffUserUpdateResult(
      message: 'User role successfully updated to "$role".',
      user: StaffUserModel(
        id: userId,
        username: 'nimal_pharm',
        role: role,
        isActive: true,
        tokenVersion: 2,
      ),
    );
  }
}

void main() {
  group('StaffUserModel', () {
    test('parses backend /api/users payload and computes initials cleanly', () {
      final user = StaffUserModel.fromJson({
        'id': 3,
        'username': 'nimal_pharm',
        'role': 'pharmacist',
        'is_active': true,
        'token_version': 2,
        'password_changed_at': '2026-11-10T06:00:00.000Z',
        'created_at': '2026-10-18T06:00:00.000Z',
        'updated_at': '2026-11-10T06:00:00.000Z',
      });

      expect(user.id, 3);
      expect(user.username, 'nimal_pharm');
      expect(user.isPharmacist, isTrue);
      expect(user.isAdmin, isFalse);
      expect(user.roleLabel, 'Pharmacist');
      expect(user.initials, 'NP');
      expect(user.isActive, isTrue);
      expect(user.tokenVersion, 2);
      expect(user.passwordChangedAt, isNotNull);
    });

    test('handles null password_changed_at and single-word usernames', () {
      final user = StaffUserModel.fromJson({
        'id': 1,
        'username': 'admin',
        'role': 'admin',
        'is_active': true,
        'password_changed_at': null,
      });

      expect(user.isAdmin, isTrue);
      expect(user.roleLabel, 'Admin');
      expect(user.initials, 'AD');
      expect(user.passwordChangedAt, isNull);
    });
  });

  group('AuthService & AuthProvider.changePassword', () {
    test('rotates stored JWT token on success without logging out', () async {
      final storage = _InMemoryTokenStorage();
      await storage.write(AuthProvider.tokenStorageKey, 'old-jwt');

      late http.Request capturedRequest;
      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'message':
                  'Password changed successfully. Prior sessions have been invalidated.',
              'token': 'rotated-jwt-v2',
              'user': {
                'id': 1,
                'username': 'admin',
                'role': 'admin',
              },
              'expiresIn': '8h',
            },
          }),
          200,
        );
      });

      final provider = AuthProvider(
        authService: AuthService(
          baseUrl: 'http://127.0.0.1:3000/api',
          client: mockClient,
        ),
        tokenStorage: storage,
        initialStatus: AuthStatus.authenticated,
        initialUser: const UserModel(
          id: 1,
          username: 'admin',
          role: 'admin',
          fullName: 'Ravindu Bandara',
        ),
        initialToken: 'old-jwt',
      );

      final message = await provider.changePassword(
        currentPassword: 'OldPassword123',
        newPassword: 'NewPassword123!',
        confirmPassword: 'NewPassword123!',
      );

      expect(capturedRequest.method, 'PUT');
      expect(capturedRequest.url.path, '/api/auth/change-password');
      expect(capturedRequest.headers['Authorization'], 'Bearer old-jwt');
      expect(
        jsonDecode(capturedRequest.body),
        {
          'current_password': 'OldPassword123',
          'new_password': 'NewPassword123!',
          'confirm_password': 'NewPassword123!',
        },
      );

      expect(message, contains('Password changed successfully'));
      expect(provider.isAuthenticated, isTrue);
      expect(provider.token, 'rotated-jwt-v2');
      expect(provider.user?.fullName, 'Ravindu Bandara');
      expect(provider.lastPasswordChangedAt, isNotNull);
      expect(
        await storage.read(AuthProvider.tokenStorageKey),
        'rotated-jwt-v2',
      );
    });

    test('preserves active session on wrong current password (401)', () async {
      final storage = _InMemoryTokenStorage();
      await storage.write(AuthProvider.tokenStorageKey, 'valid-jwt');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'AUTH_INVALID_CREDENTIALS',
              'message': 'Current password is incorrect.',
            },
          }),
          401,
        );
      });

      final provider = AuthProvider(
        authService: AuthService(
          baseUrl: 'http://127.0.0.1:3000/api',
          client: mockClient,
        ),
        tokenStorage: storage,
        initialStatus: AuthStatus.authenticated,
        initialUser: const UserModel(id: 1, username: 'admin', role: 'admin'),
        initialToken: 'valid-jwt',
      );

      await expectLater(
        () => provider.changePassword(
          currentPassword: 'WrongPassword',
          newPassword: 'NewPassword123!',
          confirmPassword: 'NewPassword123!',
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'AUTH_INVALID_CREDENTIALS'),
        ),
      );

      expect(provider.isAuthenticated, isTrue);
      expect(provider.token, 'valid-jwt');
      expect(await storage.read(AuthProvider.tokenStorageKey), 'valid-jwt');
    });

    test('revokes session when server returns AUTH_SESSION_REVOKED', () async {
      final storage = _InMemoryTokenStorage();
      await storage.write(AuthProvider.tokenStorageKey, 'stale-jwt');

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'error': {
              'code': 'AUTH_SESSION_REVOKED',
              'message': 'Session has been revoked.',
            },
          }),
          401,
        );
      });

      final provider = AuthProvider(
        authService: AuthService(
          baseUrl: 'http://127.0.0.1:3000/api',
          client: mockClient,
        ),
        tokenStorage: storage,
        initialStatus: AuthStatus.authenticated,
        initialUser: const UserModel(id: 1, username: 'admin', role: 'admin'),
        initialToken: 'stale-jwt',
      );

      await expectLater(
        () => provider.changePassword(
          currentPassword: 'OldPassword123',
          newPassword: 'NewPassword123!',
          confirmPassword: 'NewPassword123!',
        ),
        throwsA(isA<ApiException>()),
      );

      expect(provider.isAuthenticated, isFalse);
      expect(await storage.read(AuthProvider.tokenStorageKey), isNull);
    });
  });

  group('StaffUserService', () {
    test('calls GET /users, PATCH /users/:id/status, and PATCH /users/:id/role',
        () async {
      final storage = _InMemoryTokenStorage();
      await storage.write(AuthProvider.tokenStorageKey, 'admin-jwt');

      final calls = <String>[];
      final mockClient = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'GET' && request.url.path == '/api/users') {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'users': [
                  {
                    'id': 1,
                    'username': 'admin',
                    'role': 'admin',
                    'is_active': true,
                  },
                ],
              },
            }),
            200,
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/api/users/2/status') {
          expect(jsonDecode(request.body), {'is_active': false});
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'message': 'User account has been successfully deactivated.',
                'user': {
                  'id': 2,
                  'username': 'nimal_pharm',
                  'role': 'pharmacist',
                  'is_active': false,
                  'token_version': 2,
                },
              },
            }),
            200,
          );
        }
        if (request.method == 'PATCH' &&
            request.url.path == '/api/users/2/role') {
          expect(jsonDecode(request.body), {'role': 'admin'});
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'message': 'User role successfully updated to "admin".',
                'user': {
                  'id': 2,
                  'username': 'nimal_pharm',
                  'role': 'admin',
                  'is_active': true,
                  'token_version': 3,
                },
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        tokenStorage: storage,
        baseUrlOverride: 'http://127.0.0.1:3000/api',
      );
      final service = StaffUserService(apiClient);

      final users = await service.fetchUsers();
      expect(users, hasLength(1));
      expect(users.first.username, 'admin');

      final statusRes = await service.updateUserStatus(2, isActive: false);
      expect(statusRes.user.isActive, isFalse);

      final roleRes = await service.updateUserRole(2, role: 'admin');
      expect(roleRes.user.isAdmin, isTrue);

      expect(
        calls,
        [
          'GET /api/users',
          'PATCH /api/users/2/status',
          'PATCH /api/users/2/role',
        ],
      );
    });
  });

  group('StaffUserProvider', () {
    test('loads users, computes counts, filters by search and status',
        () async {
      final service = _FakeStaffUserService();
      final provider = StaffUserProvider(service: service);

      await provider.ensureLoaded();

      expect(provider.totalCount, 3);
      expect(provider.adminCount, 1);
      expect(provider.pharmacistCount, 2);
      expect(provider.activeCount, 2);
      expect(provider.disabledCount, 1);

      provider.setStatusFilter(StaffStatusFilter.disabled);
      expect(provider.filteredUsers.map((u) => u.username), ['kasun_pharm']);

      provider.setStatusFilter(StaffStatusFilter.all);
      provider.setSearchQuery('nimal');
      expect(provider.filteredUsers.map((u) => u.username), ['nimal_pharm']);
    });

    test('records AUTH_LAST_ADMIN_PROTECTED in actionError and clears cleanly',
        () async {
      final service = _FakeStaffUserService()
        ..onUpdateStatus = (id, isActive) async {
          throw const ApiException(
            code: 'AUTH_LAST_ADMIN_PROTECTED',
            message:
                'Cannot disable the last remaining active Administrator account. Self-lockout prevented.',
            statusCode: 403,
          );
        };
      final provider = StaffUserProvider(service: service);
      await provider.ensureLoaded();

      await expectLater(
        () => provider.updateUserStatus(1, isActive: false),
        throwsA(isA<ApiException>()),
      );

      expect(provider.actionError?.code, 'AUTH_LAST_ADMIN_PROTECTED');
      expect(provider.isMutatingUser(1), isFalse);

      provider.clearActionError();
      expect(provider.actionError, isNull);
    });

    test('discards stale fetch response when reset() occurs mid-flight',
        () async {
      final completer = Completer<List<StaffUserModel>>();
      final service = _FakeStaffUserService()
        ..onFetchUsers = () => completer.future;

      final provider = StaffUserProvider(service: service);
      final loadFuture = provider.ensureLoaded();

      provider.reset();
      completer.complete(const [
        StaffUserModel(
          id: 99,
          username: 'stale_user',
          role: 'admin',
          isActive: true,
        ),
      ]);
      await loadFuture;

      expect(provider.users, isEmpty);
      expect(provider.hasLoadedOnce, isFalse);
    });
  });
}
