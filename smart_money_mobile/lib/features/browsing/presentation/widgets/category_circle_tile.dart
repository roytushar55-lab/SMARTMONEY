import 'package:flutter/material.dart';

import '../../../../core/constants/accent_palette.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/widgets/network_image_with_fallback.dart';
import '../../data/models/category.dart';

/// Circular category tile (icon bubble + label underneath).
///
/// Falls back to a tinted initial-letter bubble when [Category.iconUrl] is
/// null, so no broken image is ever shown. The tint is derived from the slug
/// so a category keeps the same colour everywhere.
class CategoryCircleTile extends StatelessWidget {
  const CategoryCircleTile({
    super.key,
    required this.category,
    required this.onTap,
    this.diameter = 62,
    this.labelWidth = 76,
  });

  final Category category;
  final VoidCallback onTap;
  final double diameter;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final accent = AccentPalette.forKey(
      category.slug.isNotEmpty ? category.slug : category.name,
    );
    final hasIcon = (category.iconUrl?.trim().isNotEmpty) ?? false;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: SizedBox(
        width: labelWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: diameter,
              height: diameter,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: accent.withValues(alpha: 0.22)),
              ),
              clipBehavior: Clip.antiAlias,
              child: hasIcon
                  // Contained and inset, not cover: these are illustrations on
                  // a transparent background, so cropping them to fill the
                  // circle would cut the artwork off at the edges. The inset is
                  // small because the assets are already cropped to their
                  // artwork, with no baked-in margin of their own.
                  ? Padding(
                      padding: EdgeInsets.all(diameter * 0.10),
                      child: NetworkImageWithFallback(
                        url: category.iconUrl,
                        fit: BoxFit.contain,
                        fallbackIcon: Icons.category_outlined,
                        backgroundColor: Colors.transparent,
                        iconColor: accent,
                        iconSize: diameter * 0.38,
                      ),
                    )
                  : Center(
                      child: Text(
                        _initial(category.name),
                        style: TextStyle(
                          color: accent,
                          fontSize: diameter * 0.36,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '#' : trimmed[0].toUpperCase();
  }
}
