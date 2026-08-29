/// SmartMoney's supported theme variants.
enum AppThemeMode { light, dark }

/// The application-level theme flag.
///
/// SmartMoney does NOT follow the OS/browser theme (no
/// `MediaQuery.platformBrightness`, no `ThemeMode.system`). The active theme
/// is decided here, centrally, and flows through [ThemeController] to
/// [AppTheme] to every screen. Flip this constant to change the app's
/// default theme globally.
class AppThemeConfig {
  AppThemeConfig._();

  static const AppThemeMode initial = AppThemeMode.light;
}
