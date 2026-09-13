import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// Title + optional description on the left, one primary action on the
/// right — the same header shape repeated (inconsistently, as ad-hoc
/// TextStyle literals) across every screen. One primary CTA per screen,
/// per the skill's `primary-action` rule.
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    this.description,
    this.action,
  });

  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: textTheme.headlineSmall),
        if (description != null) ...[
          const SizedBox(height: 4),
          Text(
            description!,
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 13),
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AdminBreakpoints.mobile;

        if (isMobile && action != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleColumn,
              const SizedBox(height: AdminSpacing.md),
              action!,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: titleColumn),
            ?action,
          ],
        );
      },
    );
  }
}
