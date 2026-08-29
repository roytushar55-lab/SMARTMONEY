import 'package:flutter/material.dart';

import '../../../../core/theme/sm_colors.dart';

/// Section heading above a group of search results ("Stores (3)").
///
/// Shared rather than private to the dashboard so it stays beside the
/// [StoreCard] / [OfferCard] rows it labels.
class SearchGroupHeader extends StatelessWidget {
  const SearchGroupHeader({
    super.key,
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Row(
      children: [
        Icon(icon, color: colors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '($count)',
          style: TextStyle(
            color: colors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
