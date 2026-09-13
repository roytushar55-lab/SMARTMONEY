import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'admin_colors.dart';

/// Central ThemeData for the admin app. Style direction: Minimalism & Swiss
/// Style (the design-intelligence skill's own recommendation for "Enterprise
/// apps, dashboards, admin panels, SaaS platforms") — Inter type, restrained
/// shadows, a clear grid, and SmartMoney's existing brand colors (Purple
/// #6334D8, Cashback Green #16A765) rather than a generic palette swap, so
/// the admin panel reads as the same product as the mobile app.
ThemeData buildAdminTheme() {
  final textTheme = GoogleFonts.interTextTheme().copyWith(
    // Page titles (was a repeated ad-hoc TextStyle literal on every screen).
    headlineSmall: GoogleFonts.inter(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AdminColors.textPrimary,
      letterSpacing: -0.3,
    ),
    titleMedium: GoogleFonts.inter(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: AdminColors.textPrimary,
    ),
    bodyMedium: GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AdminColors.textSecondary,
      height: 1.5,
    ),
    bodySmall: GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AdminColors.textMuted,
    ),
    labelLarge: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
  );

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AdminColors.primary,
    brightness: Brightness.light,
    primary: AdminColors.primary,
    onPrimary: AdminColors.onPrimary,
    secondary: AdminColors.success,
    error: AdminColors.danger,
    surface: AdminColors.surface,
    onSurface: AdminColors.textPrimary,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: AdminColors.bgPrimary,
    splashFactory: InkSparkle.splashFactory,

    appBarTheme: const AppBarTheme(
      backgroundColor: AdminColors.surface,
      foregroundColor: AdminColors.textPrimary,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),

    cardTheme: CardThemeData(
      color: AdminColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.card),
        side: const BorderSide(color: AdminColors.border),
      ),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.bgPrimary,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.input),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.input),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.input),
        borderSide: const BorderSide(color: AdminColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AdminRadius.input),
        borderSide: const BorderSide(color: AdminColors.danger),
      ),
      labelStyle: const TextStyle(
        color: AdminColors.textSecondary,
        fontSize: 13,
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AdminColors.primary,
        foregroundColor: AdminColors.onPrimary,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.lg,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.button),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.textPrimary,
        side: const BorderSide(color: AdminColors.border),
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.lg,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadius.button),
        ),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AdminColors.primary,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: AdminColors.bgPrimary,
      selectedColor: AdminColors.primary.withValues(alpha: 0.12),
      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      side: const BorderSide(color: AdminColors.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.chip),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),

    dataTableTheme: DataTableThemeData(
      headingRowColor: WidgetStateProperty.all(AdminColors.bgPrimary),
      headingTextStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AdminColors.textSecondary,
        letterSpacing: 0.2,
      ),
      dataTextStyle: const TextStyle(
        fontSize: 13,
        color: AdminColors.textPrimary,
      ),
      dividerThickness: 1,
      dataRowMinHeight: 52,
      dataRowMaxHeight: 56,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AdminColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.card),
      ),
      titleTextStyle: textTheme.titleMedium?.copyWith(fontSize: 17),
    ),

    tabBarTheme: const TabBarThemeData(
      labelColor: AdminColors.primary,
      unselectedLabelColor: AdminColors.textMuted,
      labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      indicatorColor: AdminColors.primary,
      indicatorSize: TabBarIndicatorSize.label,
    ),

    dividerTheme: const DividerThemeData(
      color: AdminColors.border,
      thickness: 1,
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadius.button),
      ),
    ),
  );
}
