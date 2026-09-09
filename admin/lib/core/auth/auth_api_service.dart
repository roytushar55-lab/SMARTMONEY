import 'dart:convert';

import 'package:http/http.dart' as http;

import '../network/api_config.dart';
import 'login_response.dart';
import 'refresh_token_response.dart';

/// Only login + refresh — the admin app never registers accounts; every
/// admin is promoted from an existing customer account by a SuperAdmin.
class AuthApiService {
  AuthApiService({http.Client? client, this.baseUrl = ApiConfig.baseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<LoginResponse> login(String email, String password) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(response, 'Invalid email or password.'),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid login response.');
    }

    return LoginResponse.fromJson(decoded);
  }

  Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/refresh-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': refreshToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Token refresh failed with status ${response.statusCode}.',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid refresh-token response.');
    }

    return RefreshTokenResponse.fromJson(decoded);
  }

  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        return decoded['message'] as String;
      }
    } catch (_) {
      // Falls through to the generic message below.
    }
    return fallback;
  }

  void dispose() => _client.close();
}
