import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/accent_palette.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/widgets/network_image_with_fallback.dart';
import '../../data/models/offer_list_item.dart';

/// Swipeable promotional banner carousel driven by real offers.
///
/// Auto-advances every few seconds, pauses nothing else, and exposes dot
/// indicators. Every banner is built from API data only — when an offer has no
/// image the banner falls back to a branded gradient panel rather than a
/// broken image.
class PromoCarousel extends StatefulWidget {
  const PromoCarousel({
    super.key,
    required this.offers,
    required this.onOfferTap,
    this.height = 172,
  });

  final List<OfferListItem> offers;
  final void Function(OfferListItem offer) onOfferTap;
  final double height;

  @override
  State<PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<PromoCarousel> {
  static const Duration _interval = Duration(seconds: 5);

  final PageController _controller = PageController(viewportFraction: 0.92);
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void didUpdateWidget(covariant PromoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.offers.length != widget.offers.length) {
      _index = 0;
      _restartTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _restartTimer() {
    _timer?.cancel();
    if (widget.offers.length < 2) return;

    _timer = Timer.periodic(_interval, (_) {
      if (!mounted || !_controller.hasClients) return;
      final next = (_index + 1) % widget.offers.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.offers.isEmpty) return const SizedBox.shrink();

    final primary = SmColors.of(context).primary;

    return Column(
      children: [
        // Isolates the auto-advancing PageView so its animation frames do not
        // repaint the rest of the dashboard.
        RepaintBoundary(
          child: SizedBox(
            height: widget.height,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.offers.length,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final offer = widget.offers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _PromoBanner(
                    offer: offer,
                    onTap: () => widget.onOfferTap(offer),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.offers.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.offers.length, (dot) {
              final isActive = dot == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: isActive ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isActive ? primary : primary.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.offer, required this.onTap});

  final OfferListItem offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AccentPalette.forKey(
      offer.storeSlug.isNotEmpty ? offer.storeSlug : offer.slug,
    );
    final hasImage = (offer.imageUrl?.trim().isNotEmpty) ?? false;
    final hasLogo = (offer.storeLogoUrl?.trim().isNotEmpty) ?? false;
    final cashback = offer.cashbackText?.trim() ?? '';
    final storeName = offer.storeName.trim();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent, Color.lerp(accent, Colors.black, 0.28)!],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.32),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage) ...[
              NetworkImageWithFallback(
                url: offer.imageUrl,
                fit: BoxFit.cover,
                fallbackIcon: Icons.local_offer_outlined,
                backgroundColor: Colors.transparent,
                iconColor: Colors.white,
              ),
              // Scrim rather than a low image opacity: the artwork stays
              // readable on the right while the text column on the left keeps
              // enough contrast against it.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color.lerp(accent, Colors.black, 0.35)!.withValues(
                        alpha: 0.92,
                      ),
                      Color.lerp(accent, Colors.black, 0.35)!.withValues(
                        alpha: 0.30,
                      ),
                    ],
                    stops: const [0.05, 1.0],
                  ),
                ),
              ),
            ],
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (storeName.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasLogo) ...[
                                ClipOval(
                                  child: NetworkImageWithFallback(
                                    url: offer.storeLogoUrl,
                                    width: 18,
                                    height: 18,
                                    fit: BoxFit.cover,
                                    fallbackIcon: Icons.storefront_outlined,
                                    backgroundColor: Colors.white,
                                    iconColor: accent,
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                storeName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Spacer(),
                      if (offer.isFeatured)
                        const Icon(
                          Icons.star_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    offer.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      height: 1.2,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (cashback.isNotEmpty)
                        Expanded(
                          child: Text(
                            cashback,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Grab Deal',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
