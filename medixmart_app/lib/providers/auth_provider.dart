import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

/// Minimal persistence contract for JWT token storage, enabling in-memory
/// fakes in widget/unit tests while using [FlutterSecureStorage] in production.
abstract class TokenStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureTokenStorage implements TokenStorage {
  final FlutterSecureStorage _storage;

  const SecureTokenStorage([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) : _storage = storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final TokenStorage _storage;

  static const String tokenStorageKey = 'medixmart_jwt_token';

  AuthStatus _status;
  bool _isRestoringSession = false;
  bool _isChangingPassword = false;
  UserModel? _user;
  String? _token;
  String? _errorMessage;
  DateTime? _lastPasswordChangedAt;

  AuthProvider({
    AuthService? authService,
    TokenStorage? tokenStorage,
    AuthStatus initialStatus = AuthStatus.uninitialized,
    UserModel? initialUser,
    String? initialToken,
  })  : _authService = authService ?? const AuthService(),
        _storage = tokenStorage ?? const SecureTokenStorage(),
        _status = initialStatus,
        _user = initialUser,
        _token = initialToken;

  TokenStorage get tokenStorage => _storage;
  AuthStatus get status => _status;
  bool get isRestoringSession => _isRestoringSession;
  bool get isSubmitting => _status == AuthStatus.loading && !_isRestoringSession;
  bool get isChangingPassword => _isChangingPassword;
  UserModel? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  DateTime? get lastPasswordChangedAt => _lastPasswordChangedAt;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  void clearError() {
    if (_errorMessage == null) return;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> tryAutoLogin() async {
    if (_isRestoringSession) return;
    _isRestoringSession = true;
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final storedToken = await _storage.read(tokenStorageKey);
      if (storedToken == null || storedToken.isEmpty) {
        _status = AuthStatus.unauthenticated;
        return;
      }

      final verifiedUser = await _authService.getProfile(storedToken);
      _token = storedToken;
      _user = verifiedUser;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (_) {
      try {
        await _storage.delete(tokenStorageKey);
      } catch (_) {
        // Ignore storage cleanup failure during recovery.
      }
      _token = null;
      _user = null;
      _status = AuthStatus.unauthenticated;
    } finally {
      _isRestoringSession = false;
      notifyListeners();
    }
  }

  Future<bool> login(String username, String password) async {
    _isRestoringSession = false;
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse = await _authService.login(username, password);
      _token = authResponse.token;
      _user = authResponse.user;
      _status = AuthStatus.authenticated;

      await _storage.write(tokenStorageKey, _token!);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (_) {
      _errorMessage =
          'Unable to connect to pharmacy server. Check network connection.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Rotates the authenticated user's password via `PUT /api/auth/change-password`.
  ///
  /// Persists the newly minted JWT token so this device remains signed in while
  /// all prior sessions on other devices are invalidated server-side.
  Future<String> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    if (_isChangingPassword) {
      throw const ApiException(
        code: 'REQUEST_IN_PROGRESS',
        message: 'Password update is already in progress.',
        statusCode: 0,
      );
    }

    final activeToken = _token ?? await _storage.read(tokenStorageKey);
    if (activeToken == null || activeToken.isEmpty) {
      await handleSessionRevoked(
        'Your session has expired. Please sign in again.',
      );
      throw const ApiException(
        code: 'AUTH_MISSING_TOKEN',
        message: 'Authentication token is missing.',
        statusCode: 401,
      );
    }

    _isChangingPassword = true;
    notifyListeners();

    try {
      final result = await _authService.changePassword(
        activeToken,
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      _token = result.token;
      _user = UserModel(
        id: result.user.id,
        username: result.user.username,
        role: result.user.role,
        fullName: result.user.fullName ?? _user?.fullName,
      );
      _lastPasswordChangedAt = DateTime.now();
      await _storage.write(tokenStorageKey, result.token);
      return result.message;
    } on ApiException catch (e) {
      if (e.isSessionRevoked) {
        await handleSessionRevoked(e.message);
      }
      rethrow;
    } finally {
      _isChangingPassword = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final activeToken = _token;
    if (activeToken != null) {
      await _authService.logout(activeToken);
    }
    try {
      await _storage.delete(tokenStorageKey);
    } catch (_) {
      // Proceed with local sign-out even if secure storage throws.
    }
    _token = null;
    _user = null;
    _lastPasswordChangedAt = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clears stored credentials and transitions back to [AuthStatus.unauthenticated]
  /// when a protected API response indicates the session is no longer valid.
  Future<void> handleSessionRevoked([String? reason]) async {
    try {
      await _storage.delete(tokenStorageKey);
    } catch (_) {
      // Proceed with local sign-out even if secure storage throws.
    }
    _isRestoringSession = false;
    _isChangingPassword = false;
    _token = null;
    _user = null;
    _lastPasswordChangedAt = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = (reason != null && reason.trim().isNotEmpty)
        ? reason
        : 'Your session has expired. Please sign in again.';
    notifyListeners();
  }
}
