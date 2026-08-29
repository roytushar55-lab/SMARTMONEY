import 'package:flutter/material.dart';

import '../theme/sm_colors.dart';

/// Circular profile picture that degrades to gradient-backed initials.
///
/// Shared across the dashboard topbar and the profile screen.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.initials,
    required this.imageUrl,
    required this.size,
    required this.fontSize,
  });

  final String initials;
  final String imageUrl;
  final double size;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final hasImage = imageUrl.trim().isNotEmpty;
    final colors = SmColors.of(context);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryHover],
        ),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? Image.network(
              imageUrl,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _InitialsLabel(initials: initials, fontSize: fontSize);
              },
            )
          : _InitialsLabel(initials: initials, fontSize: fontSize),
    );
  }
}

class _InitialsLabel extends StatelessWidget {
  const _InitialsLabel({required this.initials, required this.fontSize});

  final String initials;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Text(
      initials,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
