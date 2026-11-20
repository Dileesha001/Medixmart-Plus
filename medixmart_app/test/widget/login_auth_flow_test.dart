import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medixmart_app/config/api_config.dart';
import 'package:medixmart_app/main.dart';
import 'package:medixmart_app/models/user_model.dart';
import 'package:medixmart_app/providers/auth_provider.dart';
import 'package:medixmart_app/services/auth_service.dart';

class _InMemoryTokenStorage implements TokenStorage {
  final Map<String, String> _store = {};

  _InMemoryTokenStorage([Map<String, String>? initial]) {
    if (initial != null) {
      _store.addAll(initial);
    }
  }

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

class _FakeAuthService extends AuthService {
  final Future<AuthResponse> Function(String username, String password)?
      onLogin;
  final Future<UserModel> Function(String token)? onGetProfile;
  int loginCalls = 0;
  int logoutCalls = 0;

  _FakeAuthService({
    this.onLogin,
    this.onGetProfile,
  });

  @override
  Future<AuthResponse> login(String username, String password) async {
    loginCalls++;
    if (onLogin != null) {
      return onLogin!(username, password);
    }
    return const AuthResponse(
      token: 'fake-jwt-token',
      user: UserModel(
        id: 1,
        username: 'admin',
        role: 'admin',
        fullName: 'Nimal Perera',
      ),
      expiresIn: '8h',
    );
  }

  @override
  Future<UserModel> getProfile(String token) async {
    if (onGetProfile != null) {
      return onGetProfile!(token);
    }
    return const UserModel(
      id: 1,
      username: 'admin',
      role: 'admin',
      fullName: 'Nimal Perera',
    );
  }

  @override
  Future<void> logout(String token) async {
    logoutCalls++;
  }
}

void main() {
  tearDown(() {
    ApiConfig.customHost = '';
  });

  testWidgets('LoginScreen validates empty fields and toggles password visibility',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeService = _FakeAuthService();
    final authProvider = AuthProvider(
      authService: fakeService,
      tokenStorage: _InMemoryTokenStorage(),
    );

    await tester.pumpWidget(MedixmartApp(authProvider: authProvider));
    await tester.pumpAndSettle();

    expect(find.text('Staff Sign In'), findsOneWidget);

    // Submitting empty form triggers validators without calling API.
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pump();

    expect(find.text('Username is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
    expect(fakeService.loginCalls, 0);

    // Password visibility toggle reveals and re-obscures text.
    final passwordFieldFinder = find.descendant(
      of: find.byKey(const Key('login_password_field')),
      matching: find.byType(EditableText),
    );
    expect(tester.widget<EditableText>(passwordFieldFinder).obscureText, isTrue);

    await tester.tap(find.byKey(const Key('login_password_visibility_toggle')));
    await tester.pump();
    expect(
      tester.widget<EditableText>(passwordFieldFinder).obscureText,
      isFalse,
    );
  });

  testWidgets('LoginScreen displays API error banner on invalid credentials',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeService = _FakeAuthService(
      onLogin: (_, __) async => throw const ApiException(
        code: 'AUTH_INVALID_CREDENTIALS',
        message: 'Invalid username or password.',
        statusCode: 401,
      ),
    );
    final authProvider = AuthProvider(
      authService: fakeService,
      tokenStorage: _InMemoryTokenStorage(),
    );

    await tester.pumpWidget(MedixmartApp(authProvider: authProvider));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_username_field')),
      'admin',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'wrongpass',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login_error_banner')), findsOneWidget);
    expect(find.text('Invalid username or password.'), findsOneWidget);
    // Username input remains intact after failed submit.
    expect(find.text('admin'), findsOneWidget);
  });

  testWidgets(
      'Successful login navigates to dashboard with user info and logout returns to login',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _InMemoryTokenStorage();
    final fakeService = _FakeAuthService(
      onLogin: (username, _) async => AuthResponse(
        token: 'jwt-pharmacist-123',
        user: UserModel(
          id: 2,
          username: username,
          role: 'pharmacist',
          fullName: 'Kasun Silva',
        ),
        expiresIn: '8h',
      ),
    );
    final authProvider = AuthProvider(
      authService: fakeService,
      tokenStorage: storage,
    );

    await tester.pumpWidget(MedixmartApp(authProvider: authProvider));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_username_field')),
      'pharmacist1',
    );
    await tester.enterText(
      find.byKey(const Key('login_password_field')),
      'Pharm@Medix123',
    );
    await tester.tap(find.byKey(const Key('login_submit_button')));
    await tester.pumpAndSettle();

    // Authenticated dashboard shows signed-in user and role badge.
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Kasun Silva'), findsOneWidget);
    expect(find.text('Pharmacist'), findsOneWidget);
    expect(find.text('PHARMACIST'), findsOneWidget);
    expect(await storage.read('medixmart_jwt_token'), 'jwt-pharmacist-123');

    // Logging out returns to LoginScreen and clears stored token.
    await tester.tap(find.byKey(const Key('sidebar_logout_button')));
    await tester.pumpAndSettle();

    expect(find.text('Staff Sign In'), findsOneWidget);
    expect(fakeService.logoutCalls, 1);
    expect(await storage.read('medixmart_jwt_token'), isNull);
  });

  testWidgets('AuthGate auto-logs in when a valid token is persisted',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final storage = _InMemoryTokenStorage({
      'medixmart_jwt_token': 'persisted-valid-jwt',
    });
    final fakeService = _FakeAuthService(
      onGetProfile: (_) async => const UserModel(
        id: 1,
        username: 'admin',
        role: 'admin',
        fullName: 'Nimal Perera',
      ),
    );
    final authProvider = AuthProvider(
      authService: fakeService,
      tokenStorage: storage,
    );

    await tester.pumpWidget(MedixmartApp(authProvider: authProvider));
    await tester.pumpAndSettle();

    expect(find.text('Nimal Perera'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Staff Sign In'), findsNothing);
  });

  testWidgets('LoginScreen allows overriding the backend LAN server host',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final authProvider = AuthProvider(
      authService: _FakeAuthService(),
      tokenStorage: _InMemoryTokenStorage(),
    );

    await tester.pumpWidget(MedixmartApp(authProvider: authProvider));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('login_server_toggle_button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('login_server_host_field')),
      '192.168.1.50',
    );
    await tester.tap(find.byKey(const Key('login_server_save_button')));
    await tester.pumpAndSettle();

    expect(ApiConfig.baseUrl, 'http://192.168.1.50:3000/api');
    expect(find.text('http://192.168.1.50:3000/api'), findsOneWidget);
  });
}
