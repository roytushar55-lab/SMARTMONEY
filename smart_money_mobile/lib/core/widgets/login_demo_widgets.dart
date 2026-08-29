import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/sm_colors.dart';

class LoginDemoBackground extends StatelessWidget {
  const LoginDemoBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: SmColors.of(context).backgroundGradient),
      child: child,
    );
  }
}

class LoginDemoGlassCard extends StatelessWidget {
  const LoginDemoGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(30),
    this.borderRadius = 25,
    this.width,
    this.enableBlur = true,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double? width;

  /// Set to false inside scrolling content.
  ///
  /// [BackdropFilter] re-blurs everything painted behind the card on *every
  /// frame*, which is the single most expensive thing you can put inside a
  /// scroll view. The card keeps its translucent fill either way, so the look
  /// is nearly identical over the app's gradient background.
  final bool enableBlur;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final card = Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: enableBlur ? 0.80 : 0.86),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: colors.border.withValues(alpha: 0.60)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.10),
            blurRadius: 32,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );

    if (!enableBlur) return card;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: card,
      ),
    );
  }
}

class LoginDemoGradientButton extends StatelessWidget {
  const LoginDemoGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.height = 52,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final enabled = onPressed != null && !isLoading;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? [colors.primary, colors.primaryHover]
              : [
                  colors.primary.withValues(alpha: 0.45),
                  colors.primaryHover.withValues(alpha: 0.45),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : const [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            height: height,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
