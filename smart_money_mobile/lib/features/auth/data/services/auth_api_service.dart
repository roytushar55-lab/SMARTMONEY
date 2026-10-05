import 'dart:convert';
import '../../../../core/network/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/network_guard.dart';
import '../models/register_response.dart';
import 'package:http/http.dart' as http;
import '../models/register_request.dart';
import '../models/verify_email_otp_request.dart';
import '../models/resend_email_otp_request.dart';
import '../models/refresh_token_request.dart';
import '../models/refresh_token_response.dart';
import '../models/login_request.dart';
import '../models/login_response.dart';
import '../models/forgot_password_request.dart';
import '../models/forgot_password_response.dart';
import '../models/reset_password_request.dart';
import '../models/reset_password_response.dart';

/// Every failure is surfaced as an [ApiException] whose message is safe to
/// show in the UI: the server's `{message}` when present, otherwise a generic
/// fallback. Raw response bodies are never exposed.
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

  Map<String, dynamic> _decodeMap(http.Response response, String what) {
    final Object? decodedBody;
    try {
      decodedBody = jsonDecode(response.body);
    } on FormatException {
      throw ApiException('Invalid $what response.');
    }

    if (decodedBody is! Map<String, dynamic>) {
      throw ApiException('Invalid $what response.');
    }

    return decodedBody;
  }

  void _ensureSuccess(http.Response response, String fallback) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _extractErrorMessage(response, fallback),
        statusCode: response.statusCode,
      );
    }
  }

  Future<RegisterResponse> register(RegisterRequest request) async {
    final response = await _post('/api/identity/register', request.toJson());

    _ensureSuccess(response, 'Registration failed. Please try again.');

    return RegisterResponse.fromJson(_decodeMap(response, 'registration'));
  }

  void dispose() {
    _client.close();
  }

  Future<void> verifyEmailOtp(VerifyEmailOtpRequest request) async {
    final response = await _post(
      '/api/identity/verify-email-otp',
      request.toJson(),
    );

    _ensureSuccess(response, 'Verification failed. Please try again.');
  }

  Future<void> resendEmailOtp(ResendEmailOtpRequest request) async {
    final response = await _post(
      '/api/identity/resend-email-otp',
      request.toJson(),
    );

    _ensureSuccess(response, 'Unable to resend the code. Please try again.');
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _post('/api/identity/login', request.toJson());

    _ensureSuccess(response, 'Invalid email or password.');

    return LoginResponse.fromJson(_decodeMap(response, 'login'));
  }

  Future<RefreshTokenResponse> refreshToken(RefreshTokenRequest request) async {
    final response = await _post(
      '/api/identity/refresh-token',
      request.toJson(),
    );

    _ensureSuccess(response, 'Your session could not be refreshed.');

    return RefreshTokenResponse.fromJson(_decodeMap(response, 'refresh-token'));
  }

  /// Revokes the refresh token on the server so a copy of it (device backup,
  /// stolen phone) stops working. Best-effort: signing out must never fail
  /// or hang because the network is down.
  Future<void> logout(String refreshToken) async {
    try {
      await _post('/api/identity/logout', {'refreshToken': refreshToken});
    } catch (_) {
      // Local sign-out proceeds regardless.
    }
  }

  Future<ForgotPasswordResponse> forgotPassword(
    ForgotPasswordRequest request,
  ) async {
    final response = await _post(
      '/api/identity/forgot-password',
      request.toJson(),
    );

    _ensureSuccess(response, 'Unable to send reset code.');

    return ForgotPasswordResponse.fromJson(
      _decodeMap(response, 'forgot-password'),
    );
  }

  Future<ResetPasswordResponse> resetPassword(
    ResetPasswordRequest request,
  ) async {
    final response = await _post(
      '/api/identity/reset-password',
      request.toJson(),
    );

    _ensureSuccess(response, 'Unable to reset password.');

    return ResetPasswordResponse.fromJson(
      _decodeMap(response, 'reset-password'),
    );
  }

  /// Backend error responses are `{"message": "..."}`; falls back to
  /// [fallback] when the body isn't in that shape.
  String _extractErrorMessage(http.Response response, String fallback) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final message = decoded['message'];
        if (message is String && message.trim().isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      // Falls through to the generic message below.
    }
    return fallback;
  }
}
