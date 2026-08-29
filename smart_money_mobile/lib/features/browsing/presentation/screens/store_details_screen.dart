import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/utils/external_link.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/login_demo_widgets.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/network_image_with_fallback.dart';
import '../../../../core/widgets/view_state.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../affiliate/data/services/affiliate_api_service.dart';
import '../../data/models/offer_list_item.dart';
import '../../data/models/store_details.dart';
import '../../data/services/browsing_api_service.dart';
import '../widgets/offer_card.dart';

/// Store details from `GET /api/stores/{slug}` plus that store's offers from
/// `GET /api/stores/{slug}/offers`. Tapping an offer opens its details.
class StoreDetailsScreen extends StatefulWidget {
  const StoreDetailsScreen({super.key, required this.storeSlug});

  final String storeSlug;

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  final BrowsingApiService _service = BrowsingApiService();
  final AffiliateApiService _affiliateService = AffiliateApiService();

  bool _isCreatingClick = false;

  ViewState _detailsState = ViewState.initial;
  StoreDetails? _details;
  String _detailsError = '';
  bool _isLoadingDetails = false;

  ViewState _offersState = ViewState.initial;
  List<OfferListItem> _offers = const [];
  String _offersError = '';
  bool _isLoadingOffers = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  @override
  void dispose() {
    _service.dispose();
    _affiliateService.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await _loadDetails();
    if (!mounted) return;
    if (_detailsState == ViewState.success) {
      await _loadOffers();
    }
  }

  Future<void> _loadDetails() async {
    if (_isLoadingDetails) return;
    _isLoadingDetails = true;

    setState(() => _detailsState = ViewState.loading);

    try {
      final details = await _service.getStoreDetails(widget.storeSlug);
      if (!mounted) return;
      setState(() {
        _details = details;
        _detailsState = ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _detailsError = e.message;
        _detailsState = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _detailsError = 'Something went wrong. Please try again.';
        _detailsState = ViewState.error;
      });
    } finally {
      _isLoadingDetails = false;
    }
  }

  Future<void> _loadOffers() async {
    if (_isLoadingOffers) return;
    _isLoadingOffers = true;

    setState(() => _offersState = ViewState.loading);

    try {
      final offers = await _service.getStoreOffers(widget.storeSlug);
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _offersState = offers.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _offersError = e.message;
        _offersState = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _offersError = 'Could not load offers. Please try again.';
        _offersState = ViewState.error;
      });
    } finally {
      _isLoadingOffers = false;
    }
  }

  void _openOffer(OfferListItem offer) {
    Navigator.pushNamed(
      context,
      RouteNames.offerDetails,
      arguments: offer.slug,
    );
  }

  /// Creates a tracked affiliate click, then opens the backend redirect link
  /// (`baseUrl + /r/{token}`) so the journey is recorded before the browser
  /// reaches the merchant. Falls back to the untracked website URL when the
  /// store has no active affiliate mapping.
  Future<void> _onEarnCashbackPressed() async {
    final details = _details;
    if (details == null || _isCreatingClick) return;

    // Reserved synchronously, before the click-creation `await` below —
    // otherwise the eventual window.open() falls outside the browser's user-
    // gesture window and gets silently popup-blocked on Flutter web.
    final reservedTab = ExternalLink.reserve();

    setState(() => _isCreatingClick = true);

    try {
      String url;
      try {
        final click = await _affiliateService.createClick(storeId: details.id);
        url = '${_affiliateService.baseUrl}${click.redirectPath}';
      } on ApiException catch (e) {
        if (e.isUnauthorized || !e.isNotFound) {
          ExternalLink.cancelReserved(reservedTab);
        }
        if (!mounted) return;
        if (e.isUnauthorized) {
          _promptSignIn(e.message);
          return;
        }
        if (!e.isNotFound) {
          _showSnack(e.message);
          return;
        }
        _showSnack(
          'Cashback tracking is not available for this store yet. '
          'Opening the store website.',
        );
        url = details.websiteUrl;
      }

      final opened = await ExternalLink.openReserved(reservedTab, url);
      if (!mounted || opened) return;

      _showSnack('Could not open the store website.');
    } catch (_) {
      ExternalLink.cancelReserved(reservedTab);
      if (!mounted) return;
      _showSnack('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isCreatingClick = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _promptSignIn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Sign in',
          onPressed: () => Navigator.pushNamed(context, RouteNames.login),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_details?.name ?? 'Store')),
      body: LoginDemoBackground(
        child: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_detailsState) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading store...');
      case ViewState.error:
        return ErrorView(message: _detailsError, onRetry: _loadAll);
      case ViewState.empty:
      case ViewState.success:
        final details = _details;
        if (details == null) {
          return ErrorView(message: 'Store not found.', onRetry: _loadAll);
        }
        return RefreshIndicator(
          onRefresh: _loadAll,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            children: [
              _StoreHeader(
                details: details,
                onEarnCashback: _onEarnCashbackPressed,
                isEarnCashbackLoading: _isCreatingClick,
              ),
              const SizedBox(height: 20),
              const _SectionTitle(title: 'Offers'),
              const SizedBox(height: 12),
              _buildOffersSection(),
            ],
          ),
        );
    }
  }

  Widget _buildOffersSection() {
    final colors = SmColors.of(context);

    switch (_offersState) {
      case ViewState.initial:
      case ViewState.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: LoadingView(message: 'Loading offers...'),
        );
      case ViewState.error:
        return _InlineNotice(
          icon: Icons.cloud_off_rounded,
          iconColor: colors.danger,
          title: 'Could not load offers',
          message: _offersError,
          actionLabel: 'Try again',
          onAction: _loadOffers,
        );
      case ViewState.empty:
        return _InlineNotice(
          icon: Icons.local_offer_outlined,
          iconColor: colors.primary,
          title: 'No active offers',
          message: 'This store has no active offers right now.',
        );
      case ViewState.success:
        return Column(
          children: [
            for (final offer in _offers) ...[
              OfferCard(offer: offer, onTap: () => _openOffer(offer)),
              const SizedBox(height: 14),
            ],
          ],
        );
    }
  }
}

class _StoreHeader extends StatelessWidget {
  const _StoreHeader({
    required this.details,
    required this.onEarnCashback,
    required this.isEarnCashbackLoading,
  });

  final StoreDetails details;
  final VoidCallback onEarnCashback;
  final bool isEarnCashbackLoading;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final shortDescription = details.shortDescription?.trim() ?? '';
    final description = details.description?.trim() ?? '';
    final cashback = details.defaultCashbackText?.trim() ?? '';
    final website = details.websiteUrl.trim();

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
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
          AspectRatio(
            aspectRatio: 16 / 7,
            child: NetworkImageWithFallback(
              url: details.bannerUrl,
              fallbackIcon: Icons.image_outlined,
              backgroundColor: colors.primary.withValues(alpha: 0.10),
              iconColor: colors.primary,
              iconSize: 34,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: NetworkImageWithFallback(
                        url: details.logoUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.contain,
                        fallbackIcon: Icons.storefront_outlined,
                        backgroundColor: Colors.white,
                        iconColor: colors.primary,
                        iconSize: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            details.name,
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (shortDescription.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              shortDescription,
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                if (cashback.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: colors.success.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: colors.success.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.savings_rounded,
                          color: colors.success,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cashback rate',
                                style: TextStyle(
                                  color: colors.textMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                cashback,
                                style: TextStyle(
                                  color: colors.success,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (details.isFeatured) ...[
                  const SizedBox(height: 12),
                  _Pill(
                    icon: Icons.star_rounded,
                    label: 'Featured store',
                    color: colors.warning,
                  ),
                ],
                // Only offered when the store actually has a launchable site.
                if (ExternalLink.parse(details.websiteUrl) != null) ...[
                  const SizedBox(height: 16),
                  LoginDemoGradientButton(
                    label: 'Earn Cashback',
                    icon: Icons.open_in_new_rounded,
                    isLoading: isEarnCashbackLoading,
                    onPressed: onEarnCashback,
                  ),
                ],
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const _SectionTitle(title: 'About'),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (website.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.language_rounded,
                        color: colors.textMuted,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          website,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: SmColors.of(context).textPrimary,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
