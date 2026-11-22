import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/api_exception.dart';
import '../providers/auth_provider.dart';

/// Shared authenticated HTTP client for Medixmart Plus REST endpoints.
///
/// Handles dynamic [ApiConfig.baseUrl] resolution, Bearer JWT attachment via
/// [TokenStorage], timeouts, JSON envelope parsing, and global session
/// revocation notifications.
class ApiClient {
  final http.Client _httpClient;
  final TokenStorage _tokenStorage;
  final String? _baseUrlOverride;
  void Function(String? message)? onSessionRevoked;

  ApiClient({
    http.Client? httpClient,
    TokenStorage? tokenStorage,
    String? baseUrlOverride,
    this.onSessionRevoked,
  })  : _httpClient = httpClient ?? http.Client(),
        _tokenStorage = tokenStorage ?? const SecureTokenStorage(),
        _baseUrlOverride = baseUrlOverride;

  String get _baseUrl => _baseUrlOverride ?? ApiConfig.baseUrl;

  Uri _buildUri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    final normalizedEndpoint =
        endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final uri = Uri.parse('$_baseUrl$normalizedEndpoint');
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final filtered = <String, String>{};
    for (final entry in queryParameters.entries) {
      if (entry.value != null) {
        filtered[entry.key] = entry.value.toString();
      }
    }
    if (filtered.isEmpty) {
      return uri;
    }
    return uri.replace(queryParameters: filtered);
  }

  Future<Map<String, String>> _buildHeaders({required bool requiresAuth}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _tokenStorage.read(AuthProvider.tokenStorageKey);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _execute(
      requiresAuth: requiresAuth,
      requestFn: (headers) => _httpClient.get(
        _buildUri(endpoint, queryParameters),
        headers: headers,
      ),
    );
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _execute(
      requiresAuth: requiresAuth,
      requestFn: (headers) => _httpClient.post(
        _buildUri(endpoint, queryParameters),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<Map<String, dynamic>> put(
    String endpoint, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _execute(
      requiresAuth: requiresAuth,
      requestFn: (headers) => _httpClient.put(
        _buildUri(endpoint, queryParameters),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _execute(
      requiresAuth: requiresAuth,
      requestFn: (headers) => _httpClient.patch(
        _buildUri(endpoint, queryParameters),
        headers: headers,
        body: body != null ? jsonEncode(body) : null,
      ),
    );
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _execute(
      requiresAuth: requiresAuth,
      requestFn: (headers) => _httpClient.delete(
        _buildUri(endpoint, queryParameters),
        headers: headers,
      ),
    );
  }

  Future<Map<String, dynamic>> _execute({
    required bool requiresAuth,
    required Future<http.Response> Function(Map<String, String> headers)
        requestFn,
  }) async {
    final http.Response response;
    try {
      final headers = await _buildHeaders(requiresAuth: requiresAuth);
      response = await requestFn(headers).timeout(ApiConfig.receiveTimeout);
    } on SocketException {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message:
            'Unable to reach pharmacy server. Verify server status and LAN/Wi-Fi connection.',
        statusCode: 0,
      );
    } on http.ClientException {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message:
            'Unable to reach pharmacy server. Verify server status and LAN/Wi-Fi connection.',
        statusCode: 0,
      );
    } on TimeoutException {
      throw const ApiException(
        code: 'REQUEST_TIMEOUT',
        message: 'Server request timed out. Please try again.',
        statusCode: 408,
      );
    }

    return _handleResponse(response, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> _handleResponse(
    http.Response response, {
    required bool requiresAuth,
  }) async {
    final Map<String, dynamic> decoded;
    try {
      final raw = jsonDecode(response.body);
      if (raw is! Map<String, dynamic>) {
        throw const FormatException('Response body is not a JSON object.');
      }
      decoded = raw;
    } on FormatException {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: response.statusCode >= 500
            ? 'Pharmacy server error (${response.statusCode}). Please check server status.'
            : 'Unexpected response from pharmacy server.',
        statusCode: response.statusCode,
      );
    }

    if (response.statusCode >= 200 &&
        response.statusCode < 300 &&
        decoded['success'] != false) {
      return decoded;
    }

    final exception = ApiException.fromJson(decoded, response.statusCode);

    if (requiresAuth && exception.isSessionRevoked) {
      try {
        await _tokenStorage.delete(AuthProvider.tokenStorageKey);
      } catch (_) {
        // Proceed with revocation callback even if storage delete fails.
      }
      onSessionRevoked?.call(exception.message);
    }

    throw exception;
  }

  void close() {
    _httpClient.close();
  }
}
