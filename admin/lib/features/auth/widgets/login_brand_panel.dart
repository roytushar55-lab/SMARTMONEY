import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';

/// The marketing side of the login screen: logo, headline, a decorative
/// stats card and trust badges. Shown next to the form on wide screens; its
/// pieces (logo lockup, trust badges) are reused standalone in the collapsed
/// mobile layout since there's no room for a separate panel there.
class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AdminColors.bgSecondary,
            AdminColors.bgPrimary,
            AdminColors.success.withValues(alpha: 0.06),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(48),
          bottomRight: Radius.circular(48),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -60,
              right: -40,
              child: _SoftBlob(color: AdminColors.success, size: 220),
            ),
            Positioned(
              bottom: -80,
              left: -60,
              child: _SoftBlob(color: AdminColors.primary, size: 260),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(48, 56, 48, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const LoginBrandLockup(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Smarter insights.\nHappier users.',
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          height: 1.18,
                          letterSpacing: -0.5,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: 340,
                        child: Text(
                          'Manage users, track performance, monitor cashback, '
                          'and keep SmartMoney running smoothly.',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.5,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const _StatsIllustrationCard(),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const LoginTrustBadges(),
                      const SizedBox(height: 14),
                      Container(
                        height: 1,
                        width: 64,
                        color: AdminColors.border,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Powering a smarter, rewarding tomorrow.',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AdminColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SmartMoney's icon mark + wordmark + tagline, used both in the wide brand
/// panel and, standalone, above the form on narrow screens.
class LoginBrandLockup extends StatelessWidget {
  const LoginBrandLockup({super.key, this.centered = false});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 40,
              width: 40,
              child: Image.asset(
                'assets/images/smartmoney_mark.png',
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 22,
              child: Image.asset(
                'assets/images/smartmoney_wordmark.png',
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Your Money, Your Rewards.',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AdminColors.textMuted,
          ),
        ),
      ],
    );
  }
}

/// "Secure / Private / Trusted" row shown under the brand illustration on
/// wide screens, and folded into the bottom of the form on narrow ones.
class LoginTrustBadges extends StatelessWidget {
  const LoginTrustBadges({super.key});

  @override
  Widget build(BuildContext context) {
    Widget item(IconData icon, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AdminColors.success),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AdminColors.textMuted,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 18,
      runSpacing: 8,
      children: [
        item(Icons.verified_user_outlined, 'Secure'),
        item(Icons.lock_outline, 'Private'),
        item(Icons.bar_chart_rounded, 'Trusted'),
      ],
    );
  }
}

class _StatsIllustrationCard extends StatelessWidget {
  const _StatsIllustrationCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminRadius.card),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: AdminColors.primary.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Users',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '12,580',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _TrendChip(label: '+12%'),
                      ],
                    ),
                  ],
                ),
              ),
              const _MiniTrendChart(),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '₹2,48,320',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _TrendChip(label: '+18%'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Total Cashback',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const _MiniDonutChart(),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AdminColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.arrow_upward_rounded,
            size: 11,
            color: AdminColors.success,
          ),
          const SizedBox(width: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AdminColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTrendChart extends StatelessWidget {
  const _MiniTrendChart();

  static const _heights = [0.32, 0.5, 0.42, 0.68, 0.9];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 44,
      child: CustomPaint(painter: _MiniTrendChartPainter(_heights)),
    );
  }
}

class _MiniTrendChartPainter extends CustomPainter {
  _MiniTrendChartPainter(this.heights);

  final List<double> heights;

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (heights.length * 1.8);
    final gap = (size.width - barWidth * heights.length) /
        (heights.length - 1);

    final barPaint = Paint()
      ..color = AdminColors.success.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    final points = <Offset>[];

    for (var i = 0; i < heights.length; i++) {
      final x = i * (barWidth + gap);
      final barHeight = size.height * heights[i];
      final rect = Rect.fromLTWH(
        x,
        size.height - barHeight,
        barWidth,
        barHeight,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        barPaint,
      );
      points.add(Offset(x + barWidth / 2, size.height - barHeight));
    }

    final linePaint = Paint()
      ..color = AdminColors.success
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = AdminColors.success;
    canvas.drawCircle(points.last, 2.6, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _MiniTrendChartPainter oldDelegate) => false;
}

class _MiniDonutChart extends StatelessWidget {
  const _MiniDonutChart();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 48,
      height: 48,
      child: CustomPaint(painter: _MiniDonutChartPainter()),
    );
  }
}

class _MiniDonutChartPainter extends CustomPainter {
  const _MiniDonutChartPainter();

  static const _segments = [0.45, 0.30, 0.25];
  static const _colors = [
    AdminColors.primary,
    AdminColors.success,
    Color(0xFFD7CCF5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(3, 3, size.width - 6, size.height - 6);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    var start = -math.pi / 2;
    const gap = 0.12;

    for (var i = 0; i < _segments.length; i++) {
      final sweep = _segments[i] * (2 * math.pi) - gap;
      paint.color = _colors[i];
      canvas.drawArc(rect, start, sweep, false, paint);
      start += _segments[i] * (2 * math.pi);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniDonutChartPainter oldDelegate) => false;
}

class _SoftBlob extends StatelessWidget {
  const _SoftBlob({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.10),
      ),
    );
  }
}
