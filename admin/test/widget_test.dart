import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartmoney_admin/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders its title and fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Admin Login'), findsOneWidget);
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });

  testWidgets('Forgot password opens the reset-password dialog', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();

    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });

  testWidgets('Continue with Google shows a not-available message', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.ensureVisible(find.text('Continue with Google'));
    await tester.tap(find.text('Continue with Google'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 750));

    expect(find.textContaining('Google sign-in'), findsOneWidget);
  });
}
