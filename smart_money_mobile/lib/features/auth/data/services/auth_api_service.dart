import 'dart:convert';
import '../../../../core/network/api_config.dart';
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

class AuthApiService {
  AuthApiService({http.Client? client, this.baseUrl = ApiConfig.baseUrl})
    : _client = client ?? http.Client();

  final http.Client _client;
  final String baseUrl;

  Future<RegisterResponse> register(RegisterRequest request) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Registration failed with status ${response.statusCode}: '
        '${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid registration response.');
    }

    return RegisterResponse.fromJson(decodedBody);
  }

  void dispose() {
    _client.close();
  }

  Future<void> verifyEmailOtp(VerifyEmailOtpRequest request) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/verify-email-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'OTP verification failed with status ${response.statusCode}: '
        '${response.body}',
      );
    }
  }

  Future<void> resendEmailOtp(ResendEmailOtpRequest request) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/resend-email-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Resend OTP failed with status ${response.statusCode}: '
        '${response.body}',
      );
    }
  }

  Future<LoginResponse> login(LoginRequest request) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(_extractErrorMessage(response, 'Invalid email or password.'));
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid login response.');
    }

    return LoginResponse.fromJson(decodedBody);
  }

  /// Exchanges a verified Google ID token for a SmartMoney session. Returns
  /// the same [LoginResponse] shape a normal login does, so callers save
  /// tokens and navigate exactly the same way regardless of sign-in method.
  Future<LoginResponse> loginWithGoogle(String idToken) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/google-login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'idToken': idToken}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(
          response,
          "Google sign-in couldn't be completed. Please try again.",
        ),
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid Google login response.');
    }

    return LoginResponse.fromJson(decodedBody);
  }

  Future<RefreshTokenResponse> refreshToken(RefreshTokenRequest request) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/identity/refresh-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request.toJson()),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Token refresh failed with status ${response.statusCode}: '
        '${response.body}',
      );
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid refresh-token response.');
    }

    return RefreshTokenResponse.fromJson(decodedBody);
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
      throw Exception(_extractErrorMessage(response, 'Unable to send reset code.'));
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid forgot-password response.');
    }

    return ForgotPasswordResponse.fromJson(decodedBody);
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
      throw Exception(_extractErrorMessage(response, 'Unable to reset password.'));
    }

    final decodedBody = jsonDecode(response.body);

    if (decodedBody is! Map<String, dynamic>) {
      throw const FormatException('Invalid reset-password response.');
    }

    return ResetPasswordResponse.fromJson(decodedBody);
  }

  /// Backend error responses are `{"message": "..."}`; falls back to
  /// [fallback] when the body isn't in that shape.
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
}
