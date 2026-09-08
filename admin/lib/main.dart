import 'package:flutter/material.dart';

import 'core/auth/admin_session.dart';
import 'core/auth/jwt_claims.dart';
import 'core/theme/admin_colors.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/shell/admin_shell.dart';

void main() {
  runApp(const SmartMoneyAdminApp());
}

class SmartMoneyAdminApp extends StatelessWidget {
  const SmartMoneyAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartMoney Admin',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AdminColors.primary,
          primary: AdminColors.primary,
        ),
        scaffoldBackgroundColor: AdminColors.bgPrimary,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const _SessionGate(),
    );
  }
}

/// Restores a session from stored tokens once, then switches between the
/// login screen and the admin shell as `AdminSession.instance.claims` changes.
class _SessionGate extends StatefulWidget {
  const _SessionGate();

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late final Future<void> _restoreFuture = AdminSession.instance.restore();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _restoreFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AdminColors.bgPrimary,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return ValueListenableBuilder<JwtClaims?>(
          valueListenable: AdminSession.instance.claims,
          builder: (context, claims, _) {
            return claims == null ? const LoginScreen() : const AdminShell();
          },
        );
      },
    );
  }
}
