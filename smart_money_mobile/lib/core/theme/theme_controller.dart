import 'package:flutter/foundation.dart';

import 'app_theme_mode.dart';

/// Holds the app's current [AppThemeMode] and notifies listeners on change.
///
/// A single instance ([instance]) is read by [SmartMoneyApp] to pick between
/// light/dark [ThemeData] explicitly — the same pattern the app already uses
/// for cross-screen shared state (see `ProfileSummaryStore`). This is also
/// the seam a future user-facing theme switch would call into.
class ThemeController extends ChangeNotifier {
  ThemeController._() : _mode = AppThemeConfig.initial;

  static final ThemeController instance = ThemeController._();

  AppThemeMode _mode;
  AppThemeMode get mode => _mode;

  void setMode(AppThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }

  void toggle() =>
      setMode(_mode == AppThemeMode.light ? AppThemeMode.dark : AppThemeMode.light);
}
