import 'package:flutter/material.dart';

/// SmartMoney's centralized color tokens, as a [ThemeExtension] so every
/// widget reads the same values through `SmColors.of(context)` instead of
/// each screen hardcoding its own hex codes. [light] and [dark] are the only
/// two variants — which one applies is controlled by [AppThemeConfig], not
/// by the OS theme.
@immutable
class SmColors extends ThemeExtension<SmColors> {
  const SmColors({
    required this.bgPrimary,
    required this.bgSecondary,
    required this.surface,
    required this.surfaceHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.primary,
    required this.primaryHover,
    required this.onPrimary,
    required this.success,
    required this.successHover,
    required this.warning,
    required this.danger,
    required this.shadow,
    required this.backgroundGradient,
  });

  final Color bgPrimary;
  final Color bgSecondary;
  final Color surface;
  final Color surfaceHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;

  /// SmartMoney Purple.
  final Color primary;
  final Color primaryHover;
  final Color onPrimary;

  /// Cashback Green — used for earnings, confirmations, positive states.
  final Color success;
  final Color successHover;
  final Color warning;
  final Color danger;

  final Color shadow;
  final Gradient backgroundGradient;

  static SmColors of(BuildContext context) =>
      Theme.of(context).extension<SmColors>() ?? light;

  static const light = SmColors(
    bgPrimary: Color(0xFFF8F7FF),
    bgSecondary: Color(0xFFF1EAFF),
    surface: Color(0xFFFFFFFF),
    surfaceHover: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF172033),
    textSecondary: Color(0xFF475569),
    textMuted: Color(0xFF687086),
    border: Color(0xFFE8E4F2),
    primary: Color(0xFF6334D8),
    primaryHover: Color(0xFF5429B8),
    onPrimary: Color(0xFFFFFFFF),
    success: Color(0xFF16A765),
    successHover: Color(0xFF0C9F56),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    shadow: Color(0xFF6334D8),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFF1EAFF), Color(0xFFFEFCFF), Color(0xFFF0FFF7)],
      stops: [0.0, 0.52, 1.0],
    ),
  );

  static const dark = SmColors(
    bgPrimary: Color(0xFF120D1E),
    bgSecondary: Color(0xFF1A1428),
    surface: Color(0xFF1E1830),
    surfaceHover: Color(0xFF271F3B),
    textPrimary: Color(0xFFF5F3FA),
    textSecondary: Color(0xFFC7C2D6),
    textMuted: Color(0xFF8B8599),
    border: Color(0xFF332B49),
    primary: Color(0xFF9A7BF5),
    primaryHover: Color(0xFFAD91F7),
    onPrimary: Color(0xFF120D1E),
    success: Color(0xFF34D399),
    successHover: Color(0xFF22C387),
    warning: Color(0xFFFBBF24),
    danger: Color(0xFFF87171),
    shadow: Color(0xFF000000),
    backgroundGradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF140F22), Color(0xFF19132A), Color(0xFF10201B)],
      stops: [0.0, 0.55, 1.0],
    ),
  );

  @override
  SmColors copyWith({
    Color? bgPrimary,
    Color? bgSecondary,
    Color? surface,
    Color? surfaceHover,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? border,
    Color? primary,
    Color? primaryHover,
    Color? onPrimary,
    Color? success,
    Color? successHover,
    Color? warning,
    Color? danger,
    Color? shadow,
    Gradient? backgroundGradient,
  }) {
    return SmColors(
      bgPrimary: bgPrimary ?? this.bgPrimary,
      bgSecondary: bgSecondary ?? this.bgSecondary,
      surface: surface ?? this.surface,
      surfaceHover: surfaceHover ?? this.surfaceHover,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      border: border ?? this.border,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      onPrimary: onPrimary ?? this.onPrimary,
      success: success ?? this.success,
      successHover: successHover ?? this.successHover,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
      shadow: shadow ?? this.shadow,
      backgroundGradient: backgroundGradient ?? this.backgroundGradient,
    );
  }

  @override
  SmColors lerp(ThemeExtension<SmColors>? other, double t) {
    if (other is! SmColors) return this;
    return SmColors(
      bgPrimary: Color.lerp(bgPrimary, other.bgPrimary, t)!,
      bgSecondary: Color.lerp(bgSecondary, other.bgSecondary, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceHover: Color.lerp(surfaceHover, other.surfaceHover, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t)!,
      success: Color.lerp(success, other.success, t)!,
      successHover: Color.lerp(successHover, other.successHover, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      backgroundGradient:
          Gradient.lerp(backgroundGradient, other.backgroundGradient, t)!,
    );
  }
}
