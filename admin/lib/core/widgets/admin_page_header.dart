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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: textTheme.headlineSmall),
              if (description != null) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}
