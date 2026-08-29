import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/login_demo_widgets.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/view_state.dart';
import '../../data/models/offer_list_item.dart';
import '../../data/services/browsing_api_service.dart';
import '../widgets/offer_card.dart';

/// Lists all offers from `GET /api/offers`. Tapping an offer opens its details.
class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final BrowsingApiService _service = BrowsingApiService();

  ViewState _state = ViewState.initial;
  List<OfferListItem> _offers = const [];
  String _error = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    _isLoading = true;

    setState(() => _state = ViewState.loading);

    try {
      final offers = await _service.getOffers();
      if (!mounted) return;
      setState(() {
        _offers = offers;
        _state = offers.isEmpty ? ViewState.empty : ViewState.success;
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

  void _openOffer(OfferListItem offer) {
    Navigator.pushNamed(
      context,
      RouteNames.offerDetails,
      arguments: offer.slug,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Offers')),
      body: LoginDemoBackground(
        child: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading offers...');
      case ViewState.error:
        return ErrorView(message: _error, onRetry: _load);
      case ViewState.empty:
        return EmptyView(
          title: 'No offers yet',
          message: 'Offers will appear here once they are available.',
          icon: Icons.local_offer_outlined,
          onRetry: _load,
        );
      case ViewState.success:
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            itemCount: _offers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final offer = _offers[index];
              return OfferCard(offer: offer, onTap: () => _openOffer(offer));
            },
          ),
        );
    }
  }
}
