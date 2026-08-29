import 'package:flutter/material.dart';

import '../../../../core/constants/accent_palette.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/widgets/network_image_with_fallback.dart';
import '../../data/models/store_list_item.dart';

/// Card for a single store in a list/grid. Handles null logo, short description
/// and cashback text, and shows a "Featured" marker when applicable.
class StoreCard extends StatelessWidget {
  const StoreCard({super.key, required this.store, required this.onTap});

  final StoreListItem store;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final shortDescription = store.shortDescription?.trim() ?? '';
    final hasDescription = shortDescription.isNotEmpty;
    final cashback = store.defaultCashbackText?.trim() ?? '';
    final hasCashback = cashback.isNotEmpty;
    final accent = AccentPalette.forKey(
      store.slug.isNotEmpty ? store.slug : store.name,
    );

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StoreLogo(store: store, accent: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          store.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      if (store.isFeatured) ...[
                        const SizedBox(width: 6),
                        _FeaturedBadge(colors: colors),
                      ],
                    ],
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 4),
                    Text(
                      shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (hasCashback) ...[
                    const SizedBox(height: 9),
                    _CashbackBadge(text: cashback, colors: colors),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeaturedBadge extends StatelessWidget {
  const _FeaturedBadge({required this.colors});

  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: colors.warning, size: 12),
          const SizedBox(width: 3),
          Text(
            'Featured',
            style: TextStyle(
              color: colors.warning,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Store logo with an accent-tinted initial fallback (never a broken image).
class _StoreLogo extends StatelessWidget {
  const _StoreLogo({required this.store, required this.accent});

  final StoreListItem store;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final hasLogo = (store.logoUrl?.trim().isNotEmpty) ?? false;
    final initial = store.name.trim().isEmpty
        ? '#'
        : store.name.trim()[0].toUpperCase();

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        // Brand logo tiles stay white regardless of theme — most store logos
        // are authored on a light/transparent background.
        color: hasLogo ? Colors.white : accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Padding(
              padding: const EdgeInsets.all(5),
              child: NetworkImageWithFallback(
                url: store.logoUrl,
                fit: BoxFit.contain,
                fallbackIcon: Icons.storefront_outlined,
                backgroundColor: Colors.white,
                iconColor: accent,
                iconSize: 22,
              ),
            )
          : Center(
              child: Text(
                initial,
                style: TextStyle(
                  color: accent,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
    );
  }
}

/// Bold, solid cashback badge (CashKaro-style emphasis on the rate).
class _CashbackBadge extends StatelessWidget {
  const _CashbackBadge({required this.text, required this.colors});

  final String text;
  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: colors.success,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}
