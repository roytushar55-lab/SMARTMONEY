import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// Consistent page padding plus a content max-width so tables and forms
/// don't stretch edge-to-edge on ultra-wide monitors (skill: `container-width`).
class AdminPageScaffold extends StatelessWidget {
  const AdminPageScaffold({
    super.key,
    required this.child,
    this.maxWidth = 1200,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AdminBreakpoints.mobile;
        return Padding(
          padding: EdgeInsets.all(
            isMobile ? AdminSpacing.lg : AdminSpacing.xxl,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
