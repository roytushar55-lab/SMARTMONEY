import 'package:flutter/material.dart';

import '../theme/sm_colors.dart';
import '../theme/sm_motion.dart';
import '../theme/sm_radius.dart';

/// "Continue with Google" button supporting normal / hover / pressed /
/// loading / disabled states. Tapping it calls [onPressed]; this widget owns
/// no auth logic itself.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Google',
    this.loadingLabel = 'Signing in with Google...',
  });

  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;
  final String loadingLabel;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final isEnabled = widget.onPressed != null && !widget.isLoading;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: AnimatedContainer(
        duration: SmMotion.fast,
        curve: SmMotion.standard,
        decoration: BoxDecoration(
          color: isEnabled && _hovering
              ? colors.surfaceHover
              : colors.surface,
          borderRadius: BorderRadius.circular(SmRadius.button),
          border: Border.all(
            color: isEnabled ? colors.border : colors.border.withValues(alpha: 0.6),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(SmRadius.button),
            onTap: isEnabled ? widget.onPressed : null,
            child: SizedBox(
              height: 56,
              child: Center(
                child: widget.isLoading
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            widget.loadingLabel,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _GoogleGlyph(size: 20),
                          const SizedBox(width: 10),
                          Text(
                            widget.label,
                            style: TextStyle(
                              color: isEnabled
                                  ? colors.textPrimary
                                  : colors.textMuted,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Google's official "G" mark, traced from the standard 18x18 logo geometry
/// (the same shape used in Google's own Sign-In button spec) rather than a
/// stylized approximation — the four colored strokes need to actually read
/// as the recognizable G, not just Google's brand colors in a circle.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GoogleGlyphPainter()),
    );
  }
}

class _GoogleGlyphPainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _green = Color(0xFF34A853);
  static const _yellow = Color(0xFFFBBC05);
  static const _red = Color(0xFFEA4335);

  // All paths below are in the logo's native 18x18 coordinate space.
  static const double _viewBoxSize = 18;

  static Path get _bluePath => Path()
    ..moveTo(17.64, 9.2)
    ..cubicTo(17.64, 8.563, 17.583, 7.949, 17.476, 7.36)
    ..lineTo(9, 7.36)
    ..lineTo(9, 10.841)
    ..lineTo(13.844, 10.841)
    ..cubicTo(13.635, 11.966, 13.001, 12.919, 12.048, 13.558)
    ..lineTo(12.048, 15.816)
    ..lineTo(14.956, 15.816)
    ..cubicTo(16.658, 14.249, 17.64, 11.942, 17.64, 9.201)
    ..close();

  static Path get _greenPath => Path()
    ..moveTo(9, 18)
    ..cubicTo(11.43, 18, 13.467, 17.194, 14.956, 15.82)
    ..lineTo(12.048, 13.561)
    ..cubicTo(11.242, 14.101, 10.211, 14.421, 9, 14.421)
    ..cubicTo(6.656, 14.421, 4.672, 12.837, 3.964, 10.71)
    ..lineTo(0.957, 10.71)
    ..lineTo(0.957, 13.042)
    ..cubicTo(2.438, 15.983, 5.482, 18, 9, 18)
    ..close();

  static Path get _yellowPath => Path()
    ..moveTo(3.964, 10.71)
    ..cubicTo(3.784, 10.17, 3.682, 9.593, 3.682, 9)
    ..cubicTo(3.682, 8.407, 3.784, 7.83, 3.964, 7.29)
    ..lineTo(3.964, 4.958)
    ..lineTo(0.957, 4.958)
    ..cubicTo(0.348, 6.173, 0, 7.548, 0, 9)
    ..cubicTo(0, 10.452, 0.348, 11.827, 0.957, 13.042)
    ..lineTo(3.964, 10.71)
    ..close();

  static Path get _redPath => Path()
    ..moveTo(9, 3.58)
    ..cubicTo(10.321, 3.58, 11.508, 4.034, 12.44, 4.925)
    ..lineTo(15.022, 2.345)
    ..cubicTo(13.463, 0.891, 11.426, 0, 9, 0)
    ..cubicTo(5.482, 0, 2.438, 2.017, 0.957, 4.958)
    ..lineTo(3.964, 7.29)
    ..cubicTo(4.672, 5.163, 6.656, 3.58, 9, 3.58)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBoxSize, size.height / _viewBoxSize);

    final paint = Paint()..style = PaintingStyle.fill;

    canvas.drawPath(_bluePath, paint..color = _blue);
    canvas.drawPath(_greenPath, paint..color = _green);
    canvas.drawPath(_yellowPath, paint..color = _yellow);
    canvas.drawPath(_redPath, paint..color = _red);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
