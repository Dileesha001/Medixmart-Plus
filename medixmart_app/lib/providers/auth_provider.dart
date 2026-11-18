import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';

enum AuthStatus { uninitialized, authenticated, unauthenticated, loading }

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _tokenKey = 'medixmart_jwt_token';

  AuthStatus _status = AuthStatus.uninitialized;
  UserModel? _user;
  String? _token;
  String? _errorMessage;

  AuthProvider({AuthService? authService})
      : _authService = authService ?? const AuthService();

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  Future<void> tryAutoLogin() async {
    _status = AuthStatus.loading;
    notifyListeners();

    try {
      final storedToken = await _storage.read(key: _tokenKey);
      if (storedToken == null || storedToken.isEmpty) {
        _status = AuthStatus.unauthenticated;
        notifyListeners();
        return;
      }

      final verifiedUser = await _authService.getProfile(storedToken);
      _token = storedToken;
      _user = verifiedUser;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (_) {
      await _storage.delete(key: _tokenKey);
      _token = null;
      _user = null;
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse = await _authService.login(username, password);
      _token = authResponse.token;
      _user = authResponse.user;
      _status = AuthStatus.authenticated;

      await _storage.write(key: _tokenKey, value: _token);
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

  Future<void> logout() async {
    if (_token != null) {
      await _authService.logout(_token!);
    }
    await _storage.delete(key: _tokenKey);
    _token = null;
    _user = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }
}
