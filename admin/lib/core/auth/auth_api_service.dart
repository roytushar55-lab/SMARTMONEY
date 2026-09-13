import 'dart:convert';

import 'package:http/http.dart' as http;

import '../network/api_config.dart';
import 'forgot_password_request.dart';
import 'forgot_password_response.dart';
import 'login_response.dart';
import 'refresh_token_response.dart';
import 'reset_password_request.dart';
import 'reset_password_response.dart';

/// Login + refresh + password reset — the admin app never registers
/// accounts; every admin is promoted from an existing customer account by a
/// SuperAdmin. Forgot/reset password reuse the same generic identity
/// endpoints the mobile app uses, since an admin's `User` row is no
/// different from a customer's for that purpose.
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

  Future<ForgotPasswordResponse> forgotPassword(
    ForgotPasswordRequest request,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(response, 'Unable to send reset code.'),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid forgot-password response.');
    }

    return ForgotPasswordResponse.fromJson(decoded);
  }

  Future<ResetPasswordResponse> resetPassword(
    ResetPasswordRequest request,
  ) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(response, 'Unable to reset password.'),
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid reset-password response.');
    }

    return ResetPasswordResponse.fromJson(decoded);
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
