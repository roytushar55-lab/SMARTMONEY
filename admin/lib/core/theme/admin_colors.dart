import 'package:flutter/material.dart';

/// Mirrors the mobile app's SmColors light palette (SmartMoney brand tokens)
/// so the admin panel reads as the same product. Kept as its own small copy
/// rather than a shared package — one extra app doesn't justify a monorepo
/// split yet. Light-only: this is an internal tool, not a consumer surface.
class AdminColors {
  AdminColors._();

  static const bgPrimary = Color(0xFFF8F7FF);
  static const bgSecondary = Color(0xFFF1EAFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceHover = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF172033);
  static const textSecondary = Color(0xFF475569);
  static const textMuted = Color(0xFF687086);
  static const border = Color(0xFFE8E4F2);

  /// SmartMoney Purple.
  static const primary = Color(0xFF6334D8);
  static const primaryHover = Color(0xFF5429B8);
  static const onPrimary = Color(0xFFFFFFFF);

  /// Cashback Green — earnings, confirmations, positive states.
  static const success = Color(0xFF16A765);
  static const successHover = Color(0xFF0C9F56);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
}

class AdminSpacing {
  AdminSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
}

class AdminRadius {
  AdminRadius._();

  static const chip = 999.0;
  static const button = 12.0;
  static const input = 10.0;
  static const card = 16.0;
}

class AdminBreakpoints {
  AdminBreakpoints._();

  static const mobile = 720.0;
}
