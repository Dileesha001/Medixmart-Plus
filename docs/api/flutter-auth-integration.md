# Flutter Client — Authentication & API Integration Guide

**Target Audience:** Member 2 (Frontend & UI/UX Lead)  
**Author:** Member 1 (System Architect & Backend Lead)  
**Version:** 1.0.0  
**Effective Date:** 2026-11-05  

This guide provides the exact contracts, Dart models, and service architectures required to integrate the Flutter Windows and Android client with the Express backend authentication subsystem.

---

## 1. Network Configuration & Base URLs

Because the backend runs locally on the pharmacy host computer, client base URLs differ based on the target execution environment:

| Platform / Environment | Recommended Base URL | Notes |
| :--- | :--- | :--- |
| **Windows Desktop App** | `http://127.0.0.1:3000/api` | Direct local loopback |
| **Android Emulator** | `http://10.0.2.2:3000/api` | Android emulator loopback alias |
| **Android Physical Device (Wi-Fi)** | `http://192.168.1.100:3000/api` | Static LAN IP of the pharmacy host PC |

### 1.1 Android Cleartext Traffic Configuration
Because the backend operates over plain HTTP on the local Wi-Fi network, Android requires explicit permission to communicate with local IP addresses.

Ensure `medixmart_app/android/app/src/main/AndroidManifest.xml` includes:
```xml
<application
    android:label="Medixmart Plus"
    android:name="${applicationName}"
    android:icon="@mipmap/ic_launcher"
    android:usesCleartextTraffic="true">
    ...
</application>
```

---

## 2. API Contracts & Payload Specifications

### 2.1 User Login
- **Endpoint:** `POST /api/auth/login`
- **Headers:** `Content-Type: application/json`
- **Request Body:**
  ```json
  {
    "username": "admin",
    "password": "Admin@Medix123"
  }
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      "user": {
        "id": 1,
        "username": "admin",
        "role": "admin"
      },
      "expiresIn": "8h"
    },
    "meta": {
      "timestamp": "2026-11-05T08:00:00.000Z"
    }
  }
  ```
- **Error Responses:**
  - `400 Bad Request` (`VALIDATION_ERROR`): Missing `username` or `password`.
  - `401 Unauthorized` (`AUTH_INVALID_CREDENTIALS`): Incorrect username or password.
  - `403 Forbidden` (`AUTH_ACCOUNT_DISABLED`): User account deactivated.

---

### 2.2 Verify Session & Fetch Current User Profile
- **Endpoint:** `GET /api/auth/me`
- **Headers:**
  ```http
  Authorization: Bearer <token>
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "user": {
        "id": 1,
        "username": "admin",
        "role": "admin"
      }
    },
    "meta": {
      "timestamp": "2026-11-05T08:00:00.000Z"
    }
  }
  ```
- **Error Responses:**
  - `401 Unauthorized` (`AUTH_MISSING_TOKEN`): Missing `Authorization` header.
  - `401 Unauthorized` (`AUTH_EXPIRED_TOKEN`): Token expired (older than 8 hours).
  - `401 Unauthorized` (`AUTH_INVALID_TOKEN`): Tampered or invalid JWT.
  - `403 Forbidden` (`AUTH_ACCOUNT_DISABLED`): Account deactivated while token was active.

---

### 2.3 User Logout
- **Endpoint:** `POST /api/auth/logout`
- **Headers:**
  ```http
  Authorization: Bearer <token>
  ```
- **Success Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "message": "Successfully logged out."
    },
    "meta": {
      "timestamp": "2026-11-05T08:00:00.000Z"
    }
  }
  ```
- **Client Side Behavior:** Regardless of HTTP response, the client must immediately delete the cached JWT from `flutter_secure_storage` and navigate the user back to the Login screen.

---

## 3. Flutter Implementation Blueprint

### 3.1 Recommended Packages (`pubspec.yaml`)
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.2
  http: ^1.2.2
  flutter_secure_storage: ^9.2.2
```

---

### 3.2 User & Auth Data Models (`lib/models/user_model.dart`)

```dart
class UserModel {
  final int id;
  final String username;
  final String role; // 'admin' or 'pharmacist'

  UserModel({
    required this.id,
    required this.username,
    required this.role,
  });

  bool get isAdmin => role.toLowerCase() == 'admin';
  bool get isPharmacist => role.toLowerCase() == 'pharmacist';

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'role': role,
  };
}

class AuthResponse {
  final String token;
  final UserModel user;
  final String expiresIn;

  AuthResponse({
    required this.token,
    required this.user,
    required this.expiresIn,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      token: json['token'] as String,
      user: UserModel.fromJson(json['user'] as Map<String, dynamic>),
      expiresIn: json['expiresIn'] as String,
    );
  }
}
```

---

### 3.3 Centralized Auth Service (`lib/services/auth_service.dart`)

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AuthService {
  final String baseUrl;

  AuthService({required this.baseUrl});

  Future<AuthResponse> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim(),
        'password': password,
      }),
    );

    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return AuthResponse.fromJson(body['data']);
    } else {
      final error = body['error'] ?? {};
      final message = error['message'] ?? 'Authentication failed.';
      final code = error['code'] ?? 'UNKNOWN_ERROR';
      throw ApiException(code: code, message: message, statusCode: response.statusCode);
    }
  }

  Future<UserModel> getProfile(String token) async {
    final url = Uri.parse('$baseUrl/auth/me');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final Map<String, dynamic> body = jsonDecode(response.body);

    if (response.statusCode == 200 && body['success'] == true) {
      return UserModel.fromJson(body['data']['user']);
    } else {
      final error = body['error'] ?? {};
      final message = error['message'] ?? 'Session expired.';
      final code = error['code'] ?? 'AUTH_EXPIRED_TOKEN';
      throw ApiException(code: code, message: message, statusCode: response.statusCode);
    }
  }

  Future<void> logout(String token) async {
    final url = Uri.parse('$baseUrl/auth/logout');
    try {
      await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    } catch (_) {
      // Ignored: client must wipe local storage regardless of backend state
    }
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => message;
}
```

---

### 3.4 Auth Provider & Session Lifecycle (`lib/providers/auth_provider.dart`)

```dart
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

  AuthProvider({required AuthService authService}) : _authService = authService;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get token => _token;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Check stored token on app boot
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

      // Verify token with backend
      final verifiedUser = await _authService.getProfile(storedToken);
      _token = storedToken;
      _user = verifiedUser;
      _status = AuthStatus.authenticated;
      _errorMessage = null;
    } catch (e) {
      // Token invalid or expired: clear storage
      await _storage.delete(key: _tokenKey);
      _token = null;
      _user = null;
      _status = AuthStatus.unauthenticated;
    }

    notifyListeners();
  }

  /// User login action
  Future<bool> login(String username, String password) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final authResponse = await _authService.login(username, password);
      _token = authResponse.token;
      _user = authResponse.user;
      _status = AuthStatus.authenticated;

      // Save token securely
      await _storage.write(key: _tokenKey, value: _token);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Unable to connect to pharmacy server. Check network connection.';
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// User logout action
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
```

---

## 4. Key Security & Operational Takeaways

1. **Token Lifetime:** JWTs expire after **8 hours**. Client apps should prompt the user to re-authenticate when `AUTH_EXPIRED_TOKEN` is received.
2. **Global 401 Interceptor:** If any feature endpoint (Medicines, POS, Credit, Reports) responds with $401$, client HTTP interceptors should immediately invoke `authProvider.logout()` to return to the Login screen.
3. **Role Guards:** UI screens can inspect `user.isAdmin` to display or hide sensitive administrative controls (e.g. User Management, System Settings). Note that the backend strictly enforces RBAC regardless of UI state.

