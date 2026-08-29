import 'package:flutter/animation.dart';

/// Centralized animation timing so motion feels consistent across the app.
/// Only [Curves]/[Duration] — no widget here animates layout properties
/// (width/height/top/left), only transform/opacity per the app's motion
/// guidelines.
class SmMotion {
  SmMotion._();

  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 250);
  static const slow = Duration(milliseconds: 400);

  static const standard = Curves.easeOutCubic;
  static const emphasized = Curves.easeOutQuint;
  static const entrance = Curves.easeOutCubic;
}
