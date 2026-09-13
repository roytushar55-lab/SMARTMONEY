import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartmoney_admin/features/auth/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders its title and fields', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('SmartMoney Admin'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
  });
}
