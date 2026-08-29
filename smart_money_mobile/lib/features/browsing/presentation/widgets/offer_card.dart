import 'package:flutter/material.dart';

import '../../../../core/theme/sm_colors.dart';
import '../../../../core/widgets/brand_logo_mark.dart';
import '../../../../core/widgets/network_image_with_fallback.dart';
import '../../data/models/offer_list_item.dart';

/// Card for a single offer in a list. Handles null image, short description,
/// cashback text and coupon code, plus a "Featured" marker.
class OfferCard extends StatelessWidget {
  const OfferCard({super.key, required this.offer, required this.onTap});

  final OfferListItem offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final storeName = offer.storeName.trim();
    final shortDescription = offer.shortDescription?.trim() ?? '';
    final hasDescription = shortDescription.isNotEmpty;
    final cashback = offer.cashbackText?.trim() ?? '';
    final hasCashback = cashback.isNotEmpty;
    final coupon = offer.couponCode?.trim() ?? '';
    final hasCoupon = coupon.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.border),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.10),
              blurRadius: 32,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: NetworkImageWithFallback(
                    url: offer.imageUrl,
                    fallbackIcon: Icons.local_offer_outlined,
                    backgroundColor: colors.primary.withValues(alpha: 0.08),
                    iconColor: colors.primary,
                    iconSize: 34,
                  ),
                ),
                if (offer.isFeatured)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _FeaturedBadge(colors: colors),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (storeName.isNotEmpty)
                    Row(
                      children: [
                        BrandLogoMark(
                          name: storeName,
                          slug: offer.storeSlug,
                          logoUrl: offer.storeLogoUrl,
                          size: 24,
                          radius: 7,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            storeName.toUpperCase(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.primary,
                              fontSize: 11,
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 4),
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (hasDescription) ...[
                    const SizedBox(height: 5),
                    Text(
                      shortDescription,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textMuted,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  if (hasCashback || hasCoupon) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (hasCashback)
                          _CashbackPill(text: cashback, colors: colors),
                        if (hasCoupon)
                          _CouponChip(code: coupon, colors: colors),
                      ],
                    ),
                  ],
                ],
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.warning,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.white, size: 12),
          SizedBox(width: 3),
          Text(
            'Featured',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bold, solid cashback badge (CashKaro-style emphasis on the rate).
class _CashbackPill extends StatelessWidget {
  const _CashbackPill({required this.text, required this.colors});

  final String text;
  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.success,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.savings_rounded, color: Colors.white, size: 13),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponChip extends StatelessWidget {
  const _CouponChip({required this.code, required this.colors});

  final String code;
  final SmColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            color: colors.primary,
            size: 13,
          ),
          const SizedBox(width: 5),
          Text(
            code,
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
