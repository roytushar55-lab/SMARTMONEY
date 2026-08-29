import 'package:flutter/material.dart';

import '../core/theme/app_theme_mode.dart';
import '../core/theme/theme_controller.dart';
import 'routes/app_routes.dart';
import 'routes/route_names.dart';
import 'theme/app_theme.dart';

class SmartMoneyApp extends StatelessWidget {
  const SmartMoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Smart Money',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          // Explicit app-level flag — never follows the OS/browser theme.
          themeMode: ThemeController.instance.mode == AppThemeMode.dark
              ? ThemeMode.dark
              : ThemeMode.light,
          initialRoute: RouteNames.splash,
          onGenerateRoute: AppRoutes.generateRoute,
        );
      },
    );
  }
}
