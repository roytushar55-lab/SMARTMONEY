import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// Dashboard KPI tile: icon, big number, label. Replaces the plain
/// dot-and-number card with a clearer visual hierarchy (icon establishes
/// category at a glance, number carries the most weight, label anchors it).
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Darkened tints of the card's own hue, so value/label stay legible on
    // the tinted background while still reading as "part of" that color.
    final valueColor = Color.lerp(color, Colors.black, 0.45)!;
    final labelColor = Color.lerp(color, Colors.black, 0.2)!;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminRadius.card),
      child: Container(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AdminRadius.card),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AdminRadius.input),
              ),
              child: Icon(icon, size: 16, color: Colors.white),
            ),
            const SizedBox(height: AdminSpacing.md),
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: valueColor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: labelColor, fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}
