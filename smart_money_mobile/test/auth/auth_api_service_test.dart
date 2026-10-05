import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_money_mobile/features/auth/data/models/forgot_password_request.dart';
import 'package:smart_money_mobile/features/auth/data/models/login_request.dart';
import 'package:smart_money_mobile/features/auth/data/models/reset_password_request.dart';
import 'package:smart_money_mobile/features/auth/data/services/auth_api_service.dart';

const String _base = 'http://test.local';

void main() {
  group('AuthApiService.login', () {
    // Regression test: the login screen used to show a hardcoded generic
    // error no matter what the backend actually said, which hid a real
    // "verify your email first" rejection behind "invalid password".
    test('surfaces the real backend message, not a generic one', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'message': 'Please verify your email address before logging in.',
          }),
          401,
        );
      });
      final service = AuthApiService(client: client, baseUrl: _base);

      expect(
        () => service.login(
          const LoginRequest(email: 'user@test.local', password: 'whatever'),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Please verify your email address before logging in.'),
          ),
        ),
      );
    });
  });

  group('AuthApiService.forgotPassword', () {
    test('posts the trimmed email and parses the message', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'message': 'If an account exists, a code was sent.'}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final service = AuthApiService(client: client, baseUrl: _base);

      final response = await service.forgotPassword(
        const ForgotPasswordRequest(email: '  user@test.local  '),
      );

      expect(captured!.url.toString(), '$_base/api/identity/forgot-password');
      expect(captured!.method, 'POST');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['email'], 'user@test.local');
      expect(response.message, 'If an account exists, a code was sent.');
    });

    test('surfaces the backend message on a 400', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Email format is invalid.'}),
          400,
        );
      });
      final service = AuthApiService(client: client, baseUrl: _base);

      expect(
        () => service.forgotPassword(const ForgotPasswordRequest(email: 'bad')),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Email format is invalid.'),
          ),
        ),
      );
    });
  });

  group('AuthApiService.resetPassword', () {
    test('posts email/otp/newPassword and parses the response', () async {
      http.Request? captured;
      final client = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'email': 'user@test.local',
            'message': 'Password has been reset.',
          }),
          200,
        );
      });
      final service = AuthApiService(client: client, baseUrl: _base);

      final response = await service.resetPassword(
        const ResetPasswordRequest(
          email: 'user@test.local',
          otp: '123456',
          newPassword: 'NewPassw0rd!',
        ),
      );

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['email'], 'user@test.local');
      expect(body['otp'], '123456');
      expect(body['newPassword'], 'NewPassw0rd!');
      expect(response.email, 'user@test.local');
      expect(response.message, 'Password has been reset.');
    });

    test('surfaces the backend message on an invalid OTP', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'Invalid email or OTP.'}),
          400,
        );
      });
      final service = AuthApiService(client: client, baseUrl: _base);

      expect(
        () => service.resetPassword(
          const ResetPasswordRequest(
            email: 'user@test.local',
            otp: '000000',
            newPassword: 'NewPassw0rd!',
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Invalid email or OTP.'),
          ),
        ),
      );
    });

    test(
      'falls back to a generic message when the body has no message field',
      () async {
        final client = MockClient((request) async {
          return http.Response('not json', 500);
        });
        final service = AuthApiService(client: client, baseUrl: _base);

        expect(
          () => service.resetPassword(
            const ResetPasswordRequest(
              email: 'user@test.local',
              otp: '123456',
              newPassword: 'NewPassw0rd!',
            ),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Unable to reset password.'),
            ),
          ),
        );
      },
    );
  });
}
