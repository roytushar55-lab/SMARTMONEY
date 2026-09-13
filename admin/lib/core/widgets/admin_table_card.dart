import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// Wraps a DataTable in a bordered surface card with horizontal scroll for
/// narrow viewports — the consistent shell every list screen's table sits in.
class AdminTableCard extends StatelessWidget {
  const AdminTableCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminRadius.card),
        border: Border.all(color: AdminColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: child,
        ),
      ),
    );
  }
}
