import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
import '../../data/models/offer_details.dart';
import '../../data/services/browsing_api_service.dart';

/// Offer details from `GET /api/offers/{slug}`.
///
/// The CTA creates a tracked affiliate click (`POST /api/affiliate/clicks`)
/// and opens the backend `/r/{token}` redirect so the journey is recorded,
/// falling back to [OfferDetails.destinationUrl] when tracking is unavailable.
class OfferDetailsScreen extends StatefulWidget {
  const OfferDetailsScreen({super.key, required this.offerSlug});

  final String offerSlug;

  @override
  State<OfferDetailsScreen> createState() => _OfferDetailsScreenState();
}

class _OfferDetailsScreenState extends State<OfferDetailsScreen> {
  final BrowsingApiService _service = BrowsingApiService();
  final AffiliateApiService _affiliateService = AffiliateApiService();

  ViewState _state = ViewState.initial;
  OfferDetails? _offer;
  String _error = '';
  bool _isLoading = false;
  bool _isCreatingClick = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    _affiliateService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;

    setState(() => _state = ViewState.loading);

    try {
      final offer = await _service.getOfferDetails(widget.offerSlug);
      if (!mounted) return;
      setState(() {
        _offer = offer;
        _state = ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _state = ViewState.error;
      });
    } finally {
      _isLoading = false;
    }
  }

  void _openStore(String storeSlug) {
    if (storeSlug.isEmpty) return;
    Navigator.pushNamed(
      context,
      RouteNames.storeDetails,
      arguments: storeSlug,
    );
  }

  Future<void> _copyCoupon(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Coupon "$code" copied')),
    );
  }

  /// Creates a tracked affiliate click for this offer, then opens the backend
  /// redirect link (`baseUrl + /r/{token}`) so the journey is recorded before
  /// the browser reaches the merchant. Falls back to the untracked
  /// [OfferDetails.destinationUrl] when tracking is unavailable.
  Future<void> _onShopPressed() async {
    final offer = _offer;
    if (offer == null || _isCreatingClick) return;

    // Reserved synchronously, before the click-creation `await` below —
    // otherwise the eventual window.open() falls outside the browser's user-
    // gesture window and gets silently popup-blocked on Flutter web.
    final reservedTab = ExternalLink.reserve();

    setState(() => _isCreatingClick = true);

    try {
      String url;
      try {
        final click = await _affiliateService.createClick(
          storeId: offer.storeId,
          offerId: offer.id,
        );
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
          'Cashback tracking is not available for this offer yet. '
          'Opening the offer link.',
        );
        url = offer.destinationUrl;
      }

      final opened = await ExternalLink.openReserved(reservedTab, url);
      if (!mounted || opened) return;

      _showSnack('Could not open the offer link.');
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
      appBar: AppBar(title: Text(_offer?.storeName ?? 'Offer')),
      body: LoginDemoBackground(
        child: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading offer...');
      case ViewState.error:
        return ErrorView(message: _error, onRetry: _load);
      case ViewState.empty:
      case ViewState.success:
        final offer = _offer;
        if (offer == null) {
          return ErrorView(message: 'Offer not found.', onRetry: _load);
        }
        return _buildContent(offer);
    }
  }

  Widget _buildContent(OfferDetails offer) {
    final colors = SmColors.of(context);
    final shortDescription = offer.shortDescription?.trim() ?? '';
    final description = offer.description?.trim() ?? '';
    final terms = offer.termsAndConditions?.trim() ?? '';
    final cashback = offer.cashbackText?.trim() ?? '';
    final coupon = offer.couponCode?.trim() ?? '';
    final storeName = offer.storeName.trim();
    final validity = _formatValidity(offer.startAt, offer.endAt);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: NetworkImageWithFallback(
              url: offer.imageUrl,
              fallbackIcon: Icons.local_offer_outlined,
              backgroundColor: colors.primary.withValues(alpha: 0.10),
              iconColor: colors.primary,
              iconSize: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (storeName.isNotEmpty)
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _openStore(offer.storeSlug),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    storeName.toUpperCase(),
                    style: TextStyle(
                      color: colors.primary,
                      fontSize: 12,
                      letterSpacing: 0.4,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 6),
        Text(
          offer.title,
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (shortDescription.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            shortDescription,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (cashback.isNotEmpty || offer.isFeatured) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (cashback.isNotEmpty)
                _Pill(
                  icon: Icons.savings_outlined,
                  label: cashback,
                  color: colors.success,
                ),
              if (offer.isFeatured)
                _Pill(
                  icon: Icons.star_rounded,
                  label: 'Featured',
                  color: colors.warning,
                ),
            ],
          ),
        ],
        if (coupon.isNotEmpty) ...[
          const SizedBox(height: 16),
          _CouponBox(code: coupon, onCopy: () => _copyCoupon(coupon)),
        ],
        if (validity != null) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.schedule_rounded,
                color: colors.textMuted,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  validity,
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
        if (description.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Details'),
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
        if (terms.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Terms & Conditions'),
          const SizedBox(height: 8),
          Text(
            terms,
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              height: 1.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        if (ExternalLink.parse(offer.destinationUrl) != null) ...[
          const SizedBox(height: 24),
          LoginDemoGradientButton(
            label: 'Shop & Earn Cashback',
            icon: Icons.open_in_new_rounded,
            isLoading: _isCreatingClick,
            onPressed: _onShopPressed,
          ),
        ],
      ],
    );
  }

  String? _formatValidity(DateTime? startAt, DateTime? endAt) {
    if (startAt == null && endAt == null) return null;
    if (startAt != null && endAt != null) {
      return 'Valid ${_formatDate(startAt)} - ${_formatDate(endAt)}';
    }
    if (endAt != null) {
      return 'Valid until ${_formatDate(endAt)}';
    }
    return 'Valid from ${_formatDate(startAt!)}';
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = date.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }
}

class _CouponBox extends StatelessWidget {
  const _CouponBox({required this.code, required this.onCopy});

  final String code;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.primary.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.confirmation_number_outlined,
            color: colors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Coupon code',
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  code,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16,
                    letterSpacing: 0.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onCopy,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text(
              'Copy',
              style: TextStyle(fontWeight: FontWeight.w800),
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
