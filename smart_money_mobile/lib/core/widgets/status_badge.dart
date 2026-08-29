import 'package:flutter/material.dart';

import '../theme/sm_colors.dart';
import '../theme/sm_radius.dart';

enum StatusTone { success, pending, danger, neutral }

/// Small pill used to show a status word (cashback status, transaction type,
/// verification state, ...) with a consistent look across the app.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final color = switch (tone) {
      StatusTone.success => colors.success,
      StatusTone.pending => colors.warning,
      StatusTone.danger => colors.danger,
      StatusTone.neutral => colors.textMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SmRadius.chip),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
