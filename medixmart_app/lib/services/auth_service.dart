import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';

class AuthService {
  final String baseUrl;

  const AuthService({this.baseUrl = 'http://127.0.0.1:3000/api'});

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

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && body['success'] == true) {
      return AuthResponse.fromJson(body['data'] as Map<String, dynamic>);
    } else {
      final error = (body['error'] as Map<String, dynamic>?) ?? {};
      final message = error['message'] as String? ?? 'Authentication failed.';
      final code = error['code'] as String? ?? 'UNKNOWN_ERROR';
      throw ApiException(
        code: code,
        message: message,
        statusCode: response.statusCode,
      );
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

    final Map<String, dynamic> body =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'] as Map<String, dynamic>;
      return UserModel.fromJson(data['user'] as Map<String, dynamic>);
    } else {
      final error = (body['error'] as Map<String, dynamic>?) ?? {};
      final message = error['message'] as String? ?? 'Session expired.';
      final code = error['code'] as String? ?? 'AUTH_EXPIRED_TOKEN';
      throw ApiException(
        code: code,
        message: message,
        statusCode: response.statusCode,
      );
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
