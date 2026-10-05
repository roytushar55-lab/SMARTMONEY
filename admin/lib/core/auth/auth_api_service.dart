import 'dart:convert';

import 'package:http/http.dart' as http;

import '../network/api_config.dart';
import '../network/api_exception.dart';
import '../network/network_errors.dart';
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
///
/// Every failure surfaces as an [ApiException] with a user-safe message;
/// transport errors and timeouts carry no status code.
class AuthApiService {
  AuthApiService({http.Client? client, this.baseUrl = ApiConfig.baseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<http.Response> _post(String path, Object body) {
    return guardNetwork(
      () => _client.post(
        Uri.parse('$baseUrl$path'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ),
    );
  }

  Future<LoginResponse> login(String email, String password) async {
    final response = await _post('/api/identity/login', {
      'email': email.trim(),
      'password': password,
    });

    _ensureSuccess(response, 'Invalid email or password.');

    return LoginResponse.fromJson(_decodeMap(response));
  }

  /// Revokes the refresh token on the server so a copy of it stops working.
  /// Best-effort: signing out must never fail because the network is down.
  Future<void> logout(String refreshToken) async {
    try {
      await _post('/api/identity/logout', {'refreshToken': refreshToken});
    } catch (_) {
      // Local sign-out proceeds regardless.
    }
  }

  Future<RefreshTokenResponse> refreshToken(String refreshToken) async {
    final response = await _post('/api/identity/refresh-token', {
      'refreshToken': refreshToken,
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Token refresh failed.',
        statusCode: response.statusCode,
      );
    }

    return RefreshTokenResponse.fromJson(_decodeMap(response));
  }

  Future<ForgotPasswordResponse> forgotPassword(
    ForgotPasswordRequest request,
  ) async {
    final response = await _post(
      '/api/identity/forgot-password',
      request.toJson(),
    );

    _ensureSuccess(response, 'Unable to send reset code.');

    return ForgotPasswordResponse.fromJson(_decodeMap(response));
  }

  Future<ResetPasswordResponse> resetPassword(
    ResetPasswordRequest request,
  ) async {
    final response = await _post(
      '/api/identity/reset-password',
      request.toJson(),
    );

    _ensureSuccess(response, 'Unable to reset password.');

    return ResetPasswordResponse.fromJson(_decodeMap(response));
  }

  void _ensureSuccess(http.Response response, String fallback) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response, fallback),
        statusCode: response.statusCode,
      );
    }
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Falls through to the generic message below.
    }
    throw const ApiException(badResponseMessage);
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
