import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// One number above a list: a coloured bar, the value, what it is, and an
/// optional second line (for example the rupees behind a count). Hovering shows
/// [hint]. Used by the cashback and withdrawals pages.
class AdminSummaryTile extends StatelessWidget {
  const AdminSummaryTile({
    super.key,
    required this.label,
    required this.value,
    required this.hint,
    required this.color,
    this.detail,
  });

  final String label;
  final String value;
  final String hint;
  final Color color;

  /// A smaller line under the label, such as "₹1,500.50 to pay out".
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: hint,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminSpacing.lg,
          vertical: AdminSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AdminColors.surface,
          borderRadius: BorderRadius.circular(AdminRadius.card),
          border: Border.all(color: AdminColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: detail == null ? 36 : 52,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AdminSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AdminColors.textPrimary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AdminColors.textMuted,
                    ),
                  ),
                  if (detail != null)
                    Text(
                      detail!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AdminColors.textSecondary,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
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

/// Lays summary tiles out in a row of four on a wide screen and two by two on
/// a narrow one.
class AdminSummaryStrip extends StatelessWidget {
  const AdminSummaryStrip({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? tiles.length : 2;
        const gap = AdminSpacing.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}
