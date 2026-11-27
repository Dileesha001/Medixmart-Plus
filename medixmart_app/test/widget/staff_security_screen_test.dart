import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:medixmart_app/config/app_theme.dart';
import 'package:medixmart_app/models/staff_user_model.dart';
import 'package:medixmart_app/models/user_model.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/providers/dashboard_provider.dart';
import 'package:medixmart_app/providers/staff_user_provider.dart';
import 'package:medixmart_app/screens/administration/staff_security_screen.dart';
import 'package:medixmart_app/screens/dashboard/admin_dashboard_screen.dart';
import 'package:medixmart_app/services/api_client.dart';
import 'package:medixmart_app/services/auth_service.dart';
import 'package:medixmart_app/services/staff_user_service.dart';
import 'package:provider/provider.dart';

class _InMemoryTokenStorage implements TokenStorage {
  final Map<String, String> _store = {
    AuthProvider.tokenStorageKey: 'test-jwt',
  };

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async => _store[key] = value;

  @override
  Future<void> delete(String key) async => _store.remove(key);
}

class _FakeStaffUserService extends StaffUserService {
  _FakeStaffUserService() : super(ApiClient());

  List<StaffUserModel> users = [
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
      username: 'dileesha_admin',
      role: 'admin',
      isActive: true,
      tokenVersion: 1,
      passwordChangedAt: DateTime.utc(2026, 11, 15),
      createdAt: DateTime.utc(2026, 10, 12),
    ),
    StaffUserModel(
      id: 3,
      username: 'nimal_pharm',
      role: 'pharmacist',
      isActive: true,
      tokenVersion: 1,
      passwordChangedAt: DateTime.utc(2026, 11, 10),
      createdAt: DateTime.utc(2026, 10, 18),
    ),
    StaffUserModel(
      id: 4,
      username: 'kasun_pharm',
      role: 'pharmacist',
      isActive: false,
      tokenVersion: 2,
      passwordChangedAt: DateTime.utc(2026, 10, 28),
      createdAt: DateTime.utc(2026, 10, 20),
      updatedAt: DateTime.utc(2026, 11, 4),
    ),
  ];

  bool blockLastAdmin = false;

  @override
  Future<List<StaffUserModel>> fetchUsers() async => List.of(users);

  @override
  Future<StaffUserUpdateResult> updateUserStatus(
    int userId, {
    required bool isActive,
  }) async {
    if (blockLastAdmin) {
      throw const ApiException(
        code: 'AUTH_LAST_ADMIN_PROTECTED',
        message:
            'Cannot disable the last remaining active Administrator account. Self-lockout prevented.',
        statusCode: 403,
      );
    }
    final index = users.indexWhere((u) => u.id == userId);
    final updated = users[index].copyWith(isActive: isActive);
    users[index] = updated;
    return StaffUserUpdateResult(
      message:
          'User account has been successfully ${isActive ? 'activated' : 'deactivated'}.',
      user: updated,
    );
  }

  @override
  Future<StaffUserUpdateResult> updateUserRole(
    int userId, {
    required String role,
  }) async {
    if (blockLastAdmin) {
      throw const ApiException(
        code: 'AUTH_LAST_ADMIN_PROTECTED',
        message:
            'Cannot demote the last remaining active Administrator account. Self-lockout prevented.',
        statusCode: 403,
      );
    }
    final index = users.indexWhere((u) => u.id == userId);
    final updated = users[index].copyWith(role: role);
    users[index] = updated;
    return StaffUserUpdateResult(
      message: 'User role successfully updated to "$role".',
      user: updated,
    );
  }
}

Widget _buildScreenHarness({
  required AuthProvider authProvider,
  required StaffUserProvider staffProvider,
  bool showMenuButton = false,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      ChangeNotifierProvider<StaffUserProvider>.value(value: staffProvider),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        backgroundColor: MmColors.bgCanvas,
        body: StaffSecurityScreen(showMenuButton: showMenuButton),
      ),
    ),
  );
}

AuthProvider _makeAuthProvider({
  required String role,
  http.Client? httpClient,
}) {
  return AuthProvider(
    authService: AuthService(
      baseUrl: 'http://127.0.0.1:3000/api',
      client: httpClient,
    ),
    tokenStorage: _InMemoryTokenStorage(),
    initialStatus: AuthStatus.authenticated,
    initialUser: UserModel(
      id: role == 'admin' ? 1 : 3,
      username: role == 'admin' ? 'admin' : 'nimal_pharm',
      role: role,
      fullName: role == 'admin' ? 'Ravindu Bandara' : 'Nimal Perera',
    ),
    initialToken: 'test-jwt',
  );
}

void main() {
  testWidgets(
      'StaffSecurityScreen renders refined Desktop Admin layout at 1440x900 with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final staffProvider =
        StaffUserProvider(service: _FakeStaffUserService());
    final authProvider = _makeAuthProvider(role: 'admin');

    await tester.pumpWidget(
      _buildScreenHarness(
        authProvider: authProvider,
        staffProvider: staffProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff & Account Security'), findsOneWidget);
    expect(find.text('Admin Access'), findsOneWidget);
    expect(find.text('Total Staff'), findsOneWidget);
    expect(find.text('04 Users'), findsOneWidget);
    expect(find.text('03 Active'), findsOneWidget);
    expect(find.text('01 Disabled'), findsOneWidget);
    expect(find.text('Session verified'), findsOneWidget);

    // Refined design omits technical banners
    expect(find.textContaining('token_version'), findsNothing);
    expect(find.textContaining('Administrative Self-Lockout Protection'),
        findsNothing);

    // Both cards rendered with live staff rows
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Staff Accounts'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
    expect(find.text('dileesha_admin'), findsOneWidget);
    expect(find.text('nimal_pharm'), findsOneWidget);
    expect(find.text('kasun_pharm'), findsOneWidget);
  });

  testWidgets(
      'StaffSecurityScreen adapts cleanly at mobile 390x844 with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final staffProvider =
        StaffUserProvider(service: _FakeStaffUserService());
    final authProvider = _makeAuthProvider(role: 'admin');

    await tester.pumpWidget(
      _buildScreenHarness(
        authProvider: authProvider,
        staffProvider: staffProvider,
        showMenuButton: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard_menu_button')), findsOneWidget);
    expect(find.text('Staff & Security'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('nimal_pharm'), findsOneWidget);
  });

  testWidgets(
      'StaffSecurityScreen adapts cleanly at tablet 862x692 with zero overflow',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(862, 692);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final staffProvider =
        StaffUserProvider(service: _FakeStaffUserService());
    final authProvider = _makeAuthProvider(role: 'admin');

    await tester.pumpWidget(
      _buildScreenHarness(
        authProvider: authProvider,
        staffProvider: staffProvider,
        showMenuButton: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard_menu_button')), findsOneWidget);
    expect(find.text('Staff & Account Security'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('nimal_pharm'), findsOneWidget);
  });

  testWidgets(
      'StaffSecurityScreen hides KPI strip and Staff Accounts when signed in as Pharmacist',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final staffProvider =
        StaffUserProvider(service: _FakeStaffUserService());
    final authProvider = _makeAuthProvider(role: 'pharmacist');

    await tester.pumpWidget(
      _buildScreenHarness(
        authProvider: authProvider,
        staffProvider: staffProvider,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account Security'), findsOneWidget);
    expect(find.text('Pharmacist'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.byKey(const Key('staff_accounts_section')), findsNothing);
    expect(find.text('Total Staff'), findsNothing);
    expect(find.byKey(const Key('staff_refresh_button')), findsNothing);
  });

  testWidgets(
      'Change Password submits rotated token and handles wrong current password inline',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var shouldFailWrongPwd = true;
    final mockClient = MockClient((request) async {
      if (shouldFailWrongPwd) {
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
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'message':
                'Password changed successfully. Prior sessions have been invalidated.',
            'token': 'rotated-jwt',
            'user': {'id': 3, 'username': 'nimal_pharm', 'role': 'pharmacist'},
            'expiresIn': '8h',
          },
        }),
        200,
      );
    });

    final authProvider =
        _makeAuthProvider(role: 'pharmacist', httpClient: mockClient);
    final staffProvider =
        StaffUserProvider(service: _FakeStaffUserService());

    await tester.pumpWidget(
      _buildScreenHarness(
        authProvider: authProvider,
        staffProvider: staffProvider,
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('pwd_current_field')),
      'WrongPass123',
    );
    await tester.enterText(
      find.byKey(const Key('pwd_new_field')),
      'Medix@2026!',
    );
    await tester.enterText(
      find.byKey(const Key('pwd_confirm_field')),
      'Medix@2026!',
    );
    await tester.tap(find.byKey(const Key('pwd_submit_button')));
    await tester.pumpAndSettle();

    expect(find.text('Current password is incorrect.'), findsOneWidget);
    expect(authProvider.isAuthenticated, isTrue);

    // Fix current password and succeed
    shouldFailWrongPwd = false;
    await tester.enterText(
      find.byKey(const Key('pwd_current_field')),
      'CorrectPass123',
    );
    await tester.tap(find.byKey(const Key('pwd_submit_button')));
    await tester.pumpAndSettle();

    expect(authProvider.token, 'rotated-jwt');
    expect(find.textContaining('Password changed successfully'), findsOneWidget);
  });

  testWidgets(
      'Admin can deactivate staff, promote pharmacist, and see AUTH_LAST_ADMIN_PROTECTED banner',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeStaffUserService();
    final staffProvider = StaffUserProvider(service: service);
    final authProvider = _makeAuthProvider(role: 'admin');

    await tester.pumpWidget(
      _buildScreenHarness(
        authProvider: authProvider,
        staffProvider: staffProvider,
      ),
    );
    await tester.pumpAndSettle();

    // 1. Deactivate nimal_pharm (#3)
    await tester.tap(find.byKey(const Key('staff_status_btn_3')));
    await tester.pumpAndSettle();
    expect(find.text('Deactivate Staff Account?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('staff_dialog_confirm')));
    await tester.pumpAndSettle();
    expect(find.text('02 Disabled'), findsOneWidget);

    // 2. Promote nimal_pharm (#3)
    await tester.tap(find.byKey(const Key('staff_role_btn_3')));
    await tester.pumpAndSettle();
    expect(find.text('Change Role to Administrator?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('staff_dialog_confirm')));
    await tester.pumpAndSettle();
    expect(staffProvider.adminCount, 3);

    // 3. Trigger AUTH_LAST_ADMIN_PROTECTED inline callout
    service.blockLastAdmin = true;
    await tester.tap(find.byKey(const Key('staff_status_btn_2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('staff_dialog_confirm')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('staff_action_error_banner')), findsOneWidget);
    expect(find.text('Action Blocked — Last Active Admin'), findsOneWidget);
    expect(find.text('403 Forbidden'), findsOneWidget);
    expect(find.text('code: AUTH_LAST_ADMIN_PROTECTED'), findsOneWidget);

    await tester.tap(find.byKey(const Key('staff_action_error_dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('staff_action_error_banner')), findsNothing);
  });

  testWidgets(
      'Tapping sidebar account card in AdminDashboardScreen opens StaffSecurityScreen inside shell',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authProvider = _makeAuthProvider(role: 'admin');
    final staffProvider =
        StaffUserProvider(service: _FakeStaffUserService());

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider(create: (_) => DashboardProvider()),
          ChangeNotifierProvider<StaffUserProvider>.value(value: staffProvider),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AdminDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('sidebar_account_button')));
    await tester.pumpAndSettle();

    expect(find.text('Staff & Account Security'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('nimal_pharm'), findsOneWidget);
    // Persistent desktop sidebar remains mounted
    expect(find.text('Medixmart Plus'), findsOneWidget);
  });
}
