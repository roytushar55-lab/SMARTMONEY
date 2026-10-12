import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// A queue tab: a pill with the queue's name and, once known, how many are in
/// it. Selected, it fills with the queue's colour. Put them in
/// [AdminQueueTabBar] so a long row scrolls sideways instead of overflowing.
class AdminQueueTab extends StatelessWidget {
  const AdminQueueTab({
    super.key,
    required this.label,
    required this.color,
    required this.count,
    required this.selected,
    required this.onTap,
    this.countKey,
  });

  final String label;
  final Color color;

  /// Null until the numbers have loaded.
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  /// Lets a test read the number shown in the badge.
  final Key? countKey;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminRadius.chip),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.14) : AdminColors.surface,
          borderRadius: BorderRadius.circular(AdminRadius.chip),
          border: Border.all(
            color: selected ? color.withValues(alpha: 0.5) : AdminColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? color : AdminColors.textSecondary,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? color
                      : AdminColors.textMuted.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AdminRadius.chip),
                ),
                child: Text(
                  '$count',
                  key: countKey,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : AdminColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A horizontally scrolling row of [AdminQueueTab]s.
class AdminQueueTabBar extends StatelessWidget {
  const AdminQueueTabBar({super.key, required this.tabs});

  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final tab in tabs) ...[
            tab,
            const SizedBox(width: AdminSpacing.sm),
          ],
        ],
      ),
    );
  }
}
