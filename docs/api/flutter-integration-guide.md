# Medixmart Plus — Flutter Client API Integration Guide

**Target Audience:** Member 2 (Frontend & UI/UX Lead) and Flutter Client Contributors  
**Author:** Member 1 (System Architect & Backend Lead)  
**Version:** 2.0.0  
**Effective Date:** 2026-11-19  

---

## 1. System Architecture & Topology

Medixmart Plus employs an on-premises local architecture where the Express.js REST API and PostgreSQL 17 database run directly on the primary Windows pharmacy host computer. All client applications—Windows cashier terminals, Android inventory tablets, and mobile devices—connect to this single host machine over the pharmacy's local area network (LAN / Wi-Fi).

```
                      +------------------------------------------+
                      |   Pharmacy Host Machine (Windows PC)     |
                      |   - PostgreSQL 17 (127.0.0.1:5432)       |
                      |   - Express.js API (0.0.0.0:3000)        |
                      +------------------------------------------+
                                     ^          ^
                                     |          |
              (Local Loopback: 127.0.0.1)       (Wi-Fi LAN: 192.168.x.x / 172.x.x.x)
                                     |          |
                                     v          v
                  +--------------------+     +---------------------------+
                  | Windows Desktop    |     | Android Tablet / Mobile   |
                  | Cashier Terminal   |     | Stock & Pharmacist App    |
                  +--------------------+     +---------------------------+
```

---

## 2. Environment & Multi-Host URL Configuration

Because the client app runs on different platforms during development and production, the base URL must be resolved dynamically based on the platform and runtime network environment:

| Platform / Runtime Environment | Base URL | Description |
| :--- | :--- | :--- |
| **Windows Desktop App** | `http://127.0.0.1:3000/api` | Direct local loopback on the host PC |
| **Android Studio Emulator** | `http://10.0.2.2:3000/api` | Android emulator loopback alias mapping to host `127.0.0.1` |
| **Physical Android Device (Wi-Fi)** | `http://<HOST_LAN_IP>:3000/api` | Wi-Fi LAN IP printed on backend startup (e.g. `192.168.1.100` or `172.20.10.2`) |
| **Flutter Web (Back-office)** | `http://localhost:3000/api` | Web browser origin (CORS permitted automatically in dev) |

### 2.1 Dynamic Environment Resolver in Dart

Place this in `lib/config/api_config.dart` to allow automatic fallback and runtime server IP switching:

```dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConfig {
  static const int defaultPort = 3000;
  static String customHostIp = '';

  static String get baseUrl {
    if (customHostIp.isNotEmpty) {
      return 'http://$customHostIp:$defaultPort/api';
    }

    if (kIsWeb) {
      return 'http://localhost:$defaultPort/api';
    }

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://127.0.0.1:$defaultPort/api';
    }

    if (Platform.isAndroid) {
      // In Android emulator, 10.0.2.2 maps to host PC 127.0.0.1
      // For physical devices, set customHostIp via app settings or QR scan
      return 'http://10.0.2.2:$defaultPort/api';
    }

    return 'http://127.0.0.1:$defaultPort/api';
  }

  static const Duration connectTimeout = Duration(seconds: 5);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
```

---

## 3. Standard Request & Response Protocol

### 3.1 Standard Request Headers

Every request to the Medixmart Plus API must include standard headers:

```http
Content-Type: application/json
Accept: application/json
Authorization: Bearer <jwt_token>
```
*(Note: Omit `Authorization` for public endpoints such as `POST /api/auth/login` and `GET /api/health`).*

### 3.2 Standardized JSON Envelopes

All backend responses strictly adhere to uniform JSON envelopes.

#### 1. Single Entity / Action Success Envelope (`200 OK`, `201 Created`)
```json
{
  "success": true,
  "data": {
    "id": 1,
    "name": "Antibiotics"
  },
  "meta": {
    "timestamp": "2026-11-19T08:00:00.000Z"
  }
}
```

#### 2. Paginated Collection Success Envelope (`200 OK`)
```json
{
  "success": true,
  "data": [
    {
      "id": 10,
      "brand_name": "Panadol",
      "generic_name": "Paracetamol",
      "strength": "500mg",
      "category_id": 1,
      "category_name": "Analgesics",
      "is_active": true
    }
  ],
  "meta": {
    "timestamp": "2026-11-19T08:00:00.000Z",
    "pagination": {
      "page": 1,
      "limit": 20,
      "total": 142,
      "totalPages": 8,
      "hasNext": true,
      "hasPrev": false
    }
  }
}
```

#### 3. Standard Error Envelope (`4xx`, `5xx`)
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Validation failed.",
    "details": [
      { "field": "brand_name", "message": "Brand name is required." }
    ]
  },
  "meta": {
    "timestamp": "2026-11-19T08:00:00.000Z"
  }
}
```

### 3.3 HTTP Status Codes & Error Taxonomy

| HTTP Code | Error Code (`error.code`) | Meaning / Client Action |
| :--- | :--- | :--- |
| `200` | — | Success. |
| `201` | — | Resource created successfully. |
| `400` | `VALIDATION_ERROR` | Request failed validation. Check `error.details` for field-specific errors. |
| `400` | `MALFORMED_JSON` | Body is not valid JSON. |
| `401` | `AUTH_MISSING_TOKEN` | Bearer token is missing. Redirect to Login. |
| `401` | `AUTH_INVALID_TOKEN` | Token is invalid, malformed, or tampered. Clear storage and redirect to Login. |
| `401` | `AUTH_EXPIRED_TOKEN` | 8-hour JWT has expired. Prompt user to log in again. |
| `401` | `AUTH_SESSION_REVOKED` | User changed password or credentials rotated. Clear storage and redirect to Login. |
| `401` | `AUTH_INVALID_CREDENTIALS` | Incorrect username or password. |
| `403` | `AUTH_ACCOUNT_DISABLED` | Account has been deactivated by an admin. Show notification. |
| `403` | `AUTH_FORBIDDEN_ROLE` | Pharmacist attempted an Admin-only action. Show "Access Denied" toast. |
| `403` | `AUTH_LAST_ADMIN_PROTECTED` | Cannot disable or demote the last remaining active Administrator. |
| `404` | `RESOURCE_NOT_FOUND` | Medicine, Category, or User ID does not exist. |
| `409` | `DUPLICATE_ENTRY` | Unique constraint violated (e.g., category name or medicine brand+strength exists). |
| `500` | `INTERNAL_SERVER_ERROR` | Server failure. Show "Something went wrong" message. |
| `503` | `DATABASE_ERROR` | Database connection lost or degraded. |

---

## 4. Production-Ready Dart Network Layer (`package:http`)

The following lightweight, robust HTTP service handles automatic token injection, timeout management, and standardized error parsing without external heavy dependencies.

### 4.1 ApiException Model (`lib/models/api_exception.dart`)

```dart
class ApiErrorDetail {
  final String field;
  final String message;

  ApiErrorDetail({required this.field, required this.message});

  factory ApiErrorDetail.fromJson(Map<String, dynamic> json) {
    return ApiErrorDetail(
      field: json['field'] as String? ?? '',
      message: json['message'] as String? ?? '',
    );
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;
  final List<ApiErrorDetail> details;

  ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
    this.details = const [],
  });

  factory ApiException.fromJson(Map<String, dynamic> json, int statusCode) {
    final error = (json['error'] as Map<String, dynamic>?) ?? {};
    final rawDetails = error['details'] as List<dynamic>? ?? [];

    return ApiException(
      code: error['code'] as String? ?? 'UNKNOWN_ERROR',
      message: error['message'] as String? ?? 'An unexpected error occurred.',
      statusCode: statusCode,
      details: rawDetails
          .map((d) => ApiErrorDetail.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isSessionRevoked =>
      code == 'AUTH_SESSION_REVOKED' || code == 'AUTH_EXPIRED_TOKEN';

  bool get isForbidden => statusCode == 403;

  @override
  String toString() => 'ApiException [$code] ($statusCode): $message';
}
```

### 4.2 Generic ApiClient (`lib/services/api_client.dart`)

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import '../models/api_exception.dart';

class ApiClient {
  final http.Client _httpClient;
  final FlutterSecureStorage _storage;
  void Function()? onSessionRevoked;

  ApiClient({
    http.Client? httpClient,
    FlutterSecureStorage? storage,
    this.onSessionRevoked,
  })  : _httpClient = httpClient ?? http.Client(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Map<String, String>> _buildHeaders({bool requiresAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storage.read(key: 'auth_token');
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint')
        .replace(queryParameters: queryParameters?.map((k, v) => MapEntry(k, v.toString())));

    try {
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await _httpClient
          .get(uri, headers: headers)
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach backend server. Please verify Wi-Fi / LAN connection.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiException(
        code: 'TIMEOUT_ERROR',
        message: 'Server request timed out. Please try again.',
        statusCode: 408,
      );
    }
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    return _sendWithBody('POST', endpoint, body, requiresAuth);
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    return _sendWithBody('PUT', endpoint, body, requiresAuth);
  }

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    bool requiresAuth = true,
  }) async {
    return _sendWithBody('PATCH', endpoint, body, requiresAuth);
  }

  Future<dynamic> delete(
    String endpoint, {
    bool requiresAuth = true,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
    try {
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final response = await _httpClient
          .delete(uri, headers: headers)
          .timeout(ApiConfig.receiveTimeout);

      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach backend server.',
        statusCode: 0,
      );
    }
  }

  Future<dynamic> _sendWithBody(
    String method,
    String endpoint,
    dynamic body,
    bool requiresAuth,
  ) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    try {
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      final encodedBody = body != null ? jsonEncode(body) : null;

      http.Response response;
      if (method == 'POST') {
        response = await _httpClient.post(uri, headers: headers, body: encodedBody);
      } else if (method == 'PUT') {
        response = await _httpClient.put(uri, headers: headers, body: encodedBody);
      } else if (method == 'PATCH') {
        response = await _httpClient.patch(uri, headers: headers, body: encodedBody);
      } else {
        throw ArgumentError('Unsupported HTTP method: $method');
      }

      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to reach backend server.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw ApiException(
        code: 'TIMEOUT_ERROR',
        message: 'Request timed out.',
        statusCode: 408,
      );
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw ApiException(
        code: 'MALFORMED_RESPONSE',
        message: 'Invalid response from server (${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final exception = ApiException.fromJson(decoded as Map<String, dynamic>, response.statusCode);

    // Trigger session invalidation callback on 401
    if (exception.isSessionRevoked) {
      _storage.delete(key: 'auth_token');
      onSessionRevoked?.call();
    }

    throw exception;
  }
}
```

---

## 5. Feature Endpoint Reference & Payload Specifications

### 5.1 Authentication & Security Lifecycle

#### 1. User Login
- **Method & Route:** `POST /api/auth/login` (Public)
- **Request Body:**
  ```json
  {
    "username": "admin",
    "password": "Admin@Medix123"
  }
  ```
- **Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "token": "eyJhbGciOiJIUzI1NiIsInR5cCI...",
      "user": {
        "id": 1,
        "username": "admin",
        "role": "admin"
      },
      "expiresIn": "8h"
    }
  }
  ```

#### 2. Verify Session & Profile
- **Method & Route:** `GET /api/auth/me` (Protected)
- **Headers:** `Authorization: Bearer <token>`
- **Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "user": {
        "id": 1,
        "username": "admin",
        "role": "admin",
        "token_version": 1
      }
    }
  }
  ```

#### 3. Change Password (Credential Rotation)
- **Method & Route:** `PUT /api/auth/change-password` (Protected)
- **Request Body:**
  ```json
  {
    "current_password": "Admin@Medix123",
    "new_password": "NewSecurePassword123!",
    "confirm_password": "NewSecurePassword123!"
  }
  ```
- **Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "message": "Password changed successfully. Prior sessions have been invalidated.",
      "token": "eyJhbGciOiJIUzI1Ni...",
      "user": {
        "id": 1,
        "username": "admin",
        "role": "admin"
      },
      "expiresIn": "8h"
    }
  }
  ```
- **Error Codes:**
  - `400 VALIDATION_ERROR`: Password < 8 characters, or confirmation does not match, or new password identical to current.
  - `401 AUTH_INVALID_CREDENTIALS`: Current password is wrong.
  - `401 AUTH_SESSION_REVOKED`: Previous tokens are instantly revoked upon password change.

---

### 5.2 Categories Subsystem

#### 1. List Categories
- **Method & Route:** `GET /api/categories` (Protected: Admin & Pharmacist)
- **Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": 1,
        "name": "Antibiotics",
        "description": "Prescription antibiotics",
        "created_at": "2026-11-19T06:00:00.000Z"
      }
    ],
    "meta": {
      "total": 1
    }
  }
  ```

#### 2. Create Category
- **Method & Route:** `POST /api/categories` (Protected: Admin Only)
- **Request Body:**
  ```json
  {
    "name": "Vitamins & Supplements",
    "description": "Over the counter dietary supplements"
  }
  ```
- **Error Responses:**
  - `409 DUPLICATE_ENTRY`: Category name already exists.
  - `403 AUTH_FORBIDDEN_ROLE`: Pharmacist attempting to create category.

---

### 5.3 Medicines & Inventory Subsystem

#### 1. Search & Filter Medicines (Paginated)
- **Method & Route:** `GET /api/medicines` (Protected: Admin & Pharmacist)
- **Query Parameters:**
  - `search` (optional): Filter by brand or generic name (e.g. `?search=para`).
  - `category_id` (optional): Filter by numeric category ID.
  - `page` (optional, default `1`): Page number.
  - `limit` (optional, default `20`, max `100`): Items per page.
  - `sort_by` (optional, default `brand_name`): Whitelisted: `id`, `brand_name`, `generic_name`, `strength`, `created_at`.
  - `order` (optional, default `asc`): `asc` or `desc`.
- **Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": [
      {
        "id": 5,
        "brand_name": "Panadol ActiFast",
        "generic_name": "Paracetamol",
        "strength": "500mg",
        "category_id": 1,
        "category_name": "Analgesics",
        "description": "Rapid release paracetamol tablets",
        "is_active": true,
        "created_at": "2026-11-19T06:00:00.000Z"
      }
    ],
    "meta": {
      "pagination": {
        "page": 1,
        "limit": 20,
        "total": 1,
        "totalPages": 1,
        "hasNext": false,
        "hasPrev": false
      }
    }
  }
  ```

#### 2. Create Medicine
- **Method & Route:** `POST /api/medicines` (Protected: Admin Only)
- **Request Body:**
  ```json
  {
    "brand_name": "Amoxil",
    "generic_name": "Amoxicillin",
    "strength": "250mg",
    "category_id": 1,
    "description": "Broad-spectrum oral antibiotic"
  }
  ```
- **Error Codes:**
  - `400 VALIDATION_ERROR`: Missing required fields or category does not exist.
  - `409 DUPLICATE_ENTRY`: Medicine with identical `brand_name` and `strength` already exists.

#### 3. Update Medicine Details
- **Method & Route:** `PUT /api/medicines/:id` (Protected: Admin Only)
- **Request Body:**
  ```json
  {
    "brand_name": "Amoxil Forte",
    "generic_name": "Amoxicillin",
    "strength": "500mg",
    "category_id": 1,
    "description": "Updated strength"
  }
  ```

#### 4. Safe Soft-Deactivation
- **Method & Route:** `PATCH /api/medicines/:id/deactivate` (Protected: Admin Only)
- **Description:** Sets `is_active = FALSE`. The medicine is hidden from regular POS autocomplete while completely preserving historical sales foreign key integrity.
- **Response (`200 OK`):**
  ```json
  {
    "success": true,
    "data": {
      "message": "Medicine successfully deactivated.",
      "medicine": {
        "id": 5,
        "brand_name": "Panadol",
        "is_active": false
      }
    }
  }
  ```

---

### 5.4 Administrative User Management

#### 1. List Users
- **Method & Route:** `GET /api/users` (Protected: Admin Only)
- **Response (`200 OK`):** Lists all staff users with their roles, active status, and timestamps.

#### 2. Update User Active Status (Self-Lockout Protected)
- **Method & Route:** `PATCH /api/users/:id/status` (Protected: Admin Only)
- **Request Body:**
  ```json
  {
    "is_active": false
  }
  ```
- **Self-Lockout Safeguard:** If attempting to deactivate the only remaining active Administrator, the server rejects the request with `403 Forbidden` (`AUTH_LAST_ADMIN_PROTECTED`).

#### 3. Update User Role
- **Method & Route:** `PATCH /api/users/:id/role` (Protected: Admin Only)
- **Request Body:**
  ```json
  {
    "role": "pharmacist"
  }
  ```
- **Self-Lockout Safeguard:** Demoting the last active Administrator account is strictly forbidden (`403 AUTH_LAST_ADMIN_PROTECTED`).

---

### 5.5 System Health & Readiness

- **Method & Route:** `GET /api/health` (Public)
- **Use Case:** Ping upon app launch to verify Wi-Fi connectivity to the host PC and database status before presenting the login screen.
- **Response (`200 OK`):**
  ```json
  {
    "success": true,
    "status": "healthy",
    "uptimeSeconds": 1420,
    "timestamp": "2026-11-19T08:00:00.000Z",
    "environment": "development",
    "database": {
      "connected": true,
      "database": "postgres",
      "user": "postgres",
      "serverTime": "2026-11-19T08:00:00.000Z"
    }
  }
  ```

---

## 6. Common Pitfalls & Troubleshooting Checklist

### 1. Android Cleartext Traffic (HTTP LAN Access)
Android 9 (API 28) and newer blocks unencrypted HTTP traffic by default. Because the local pharmacy backend operates over HTTP on the local Wi-Fi subnet:
- Ensure `medixmart_app/android/app/src/main/AndroidManifest.xml` contains:
  ```xml
  <application
      android:label="Medixmart Plus"
      android:name="${applicationName}"
      android:icon="@mipmap/ic_launcher"
      android:usesCleartextTraffic="true">
  ```

### 2. Windows Firewall Port Inbound Rule
If physical Android tablets cannot connect to `http://<HOST_IP>:3000/api`:
- On the Windows host PC, open PowerShell as Administrator and ensure port 3000 is open for the local subnet:
  ```powershell
  New-NetFirewallRule -DisplayName "Medixmart Backend Port 3000" -Direction Inbound -LocalPort 3000 -Protocol TCP -Action Allow
  ```

### 3. Session Revocation & Password Changes
- Whenever a user updates their password via `PUT /api/auth/change-password`, all previous tokens minted under earlier `token_version` values are revoked immediately.
- The client must replace its stored token with the newly minted token returned in `change-password` response `data.token`.
- If an existing screen receives `401 AUTH_SESSION_REVOKED`, immediately clear stored tokens and redirect to the Login screen.

### 4. FEFO Expiry Standard
- Sri Lankan regulatory policy and pharmacy operations enforce a **7-month expiry window** (`EXPIRY_WINDOW_MONTHS=7`).
- Medicines reaching expiration within 7 months must display a warning status badge (`status_dot_warning.svg`).
- Dispensing must always allocate from the earliest expiring batch first (FEFO).

