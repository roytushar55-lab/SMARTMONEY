import 'package:flutter/material.dart';

import '../theme/sm_colors.dart';
import '../theme/sm_motion.dart';

class SmBottomNavItem {
  const SmBottomNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// The app's primary mobile navigation — replaces the old side drawer.
/// Active item gets a subtle lift + tinted pill, per the app's motion rules
/// (transform/opacity only).
class SmBottomNavBar extends StatelessWidget {
  const SmBottomNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<SmBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _NavButton(
                    item: items[i],
                    isActive: i == currentIndex,
                    colors: colors,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.isActive,
    required this.colors,
    required this.onTap,
  });

  final SmBottomNavItem item;
  final bool isActive;
  final SmColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? colors.primary : colors.textMuted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: SmMotion.fast,
          curve: SmMotion.standard,
          transform: Matrix4.translationValues(0, isActive ? -2 : 0, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isActive ? item.activeIcon : item.icon,
                color: color,
                size: 24,
              ),
              const SizedBox(height: 3),
              Text(
                item.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
