import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// Small colored pill for a status string (cashback status, active/inactive,
/// etc). [color] drives both text and the tinted background.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  factory StatusBadge.active(bool isActive) {
    return StatusBadge(
      label: isActive ? 'Active' : 'Inactive',
      color: isActive ? AdminColors.success : AdminColors.textMuted,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminRadius.chip),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
