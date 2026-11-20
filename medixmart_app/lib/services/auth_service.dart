import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/user_model.dart';

class AuthService {
  final String? _baseUrlOverride;
  final http.Client? _client;

  const AuthService({
    String? baseUrl,
    http.Client? client,
  })  : _baseUrlOverride = baseUrl,
        _client = client;

  String get baseUrl => _baseUrlOverride ?? ApiConfig.baseUrl;

  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> _post(
    Uri url, {
    required Map<String, String> headers,
    Object? body,
  }) {
    final future = _client != null
        ? _client.post(url, headers: headers, body: body)
        : http.post(url, headers: headers, body: body);
    return future.timeout(ApiConfig.receiveTimeout);
  }

  Future<http.Response> _get(
    Uri url, {
    required Map<String, String> headers,
  }) {
    final future = _client != null
        ? _client.get(url, headers: headers)
        : http.get(url, headers: headers);
    return future.timeout(ApiConfig.receiveTimeout);
  }

  Map<String, dynamic> _decodeJson(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw const FormatException('Response body is not a JSON object.');
    } on FormatException {
      throw ApiException(
        code: 'INVALID_RESPONSE',
        message: response.statusCode >= 500
            ? 'Pharmacy server error (${response.statusCode}). Please check server status.'
            : 'Unexpected response from pharmacy server.',
        statusCode: response.statusCode,
      );
    }
  }

  Future<AuthResponse> login(String username, String password) async {
    final url = Uri.parse('$baseUrl/auth/login');
    final http.Response response;
    try {
      response = await _post(
        url,
        headers: _headers(),
        body: jsonEncode({
          'username': username.trim(),
          'password': password,
        }),
      );
    } on TimeoutException {
      throw const ApiException(
        code: 'REQUEST_TIMEOUT',
        message:
            'Connection timed out. Verify the pharmacy server is running and reachable.',
        statusCode: 0,
      );
    }

    final body = _decodeJson(response);

    if (response.statusCode == 200 && body['success'] == true) {
      return AuthResponse.fromJson(body['data'] as Map<String, dynamic>);
    }

    final error = (body['error'] as Map<String, dynamic>?) ?? {};
    final message = error['message'] as String? ?? 'Authentication failed.';
    final code = error['code'] as String? ?? 'UNKNOWN_ERROR';
    throw ApiException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  Future<UserModel> getProfile(String token) async {
    final url = Uri.parse('$baseUrl/auth/me');
    final http.Response response;
    try {
      response = await _get(
        url,
        headers: _headers(token: token),
      );
    } on TimeoutException {
      throw const ApiException(
        code: 'REQUEST_TIMEOUT',
        message: 'Session verification timed out.',
        statusCode: 0,
      );
    }

    final body = _decodeJson(response);

    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    }

    final error = (body['error'] as Map<String, dynamic>?) ?? {};
    final message = error['message'] as String? ?? 'Session expired.';
    final code = error['code'] as String? ?? 'AUTH_EXPIRED_TOKEN';
    throw ApiException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  Future<void> logout(String token) async {
    final url = Uri.parse('$baseUrl/auth/logout');
    try {
      await _post(
        url,
        headers: _headers(token: token),
      );
    } catch (_) {
      // Client must wipe local storage regardless of backend state.
    }
  }
}

class ApiException implements Exception {
  final String code;
  final String message;
  final int statusCode;

  const ApiException({
    required this.code,
    required this.message,
    required this.statusCode,
  });

  @override
  String toString() => message;
}
