import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_sticky_table.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state.dart';
import '../../stores/models/admin_store.dart';
import '../../stores/services/admin_store_api_service.dart';
import '../models/admin_offer.dart';
import '../services/admin_offer_api_service.dart';
import 'offer_form_dialog.dart';

class OffersScreen extends StatefulWidget {
  const OffersScreen({super.key});

  @override
  State<OffersScreen> createState() => _OffersScreenState();
}

class _OffersScreenState extends State<OffersScreen> {
  final _offerService = AdminOfferApiService();
  final _storeService = AdminStoreApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  List<AdminOffer> _offers = [];
  List<AdminStore> _stores = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _offerService.dispose();
    _storeService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);
    try {
      final results = await Future.wait([
        _offerService.list(),
        _storeService.list(),
      ]);
      setState(() {
        _offers = results[0] as List<AdminOffer>;
        _stores = results[1] as List<AdminStore>;
        _state = _offers.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  Future<void> _create() async {
    if (_stores.isEmpty) {
      showErrorSnackBar(context, 'Create a store first.');
      return;
    }

    final body = await showOfferFormDialog(context, stores: _stores);
    if (body == null || !mounted) return;

    try {
      await _offerService.create(body);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Offer created.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _edit(AdminOffer offer) async {
    final body = await showOfferFormDialog(
      context,
      stores: _stores,
      existing: offer,
    );
    if (body == null || !mounted) return;

    try {
      await _offerService.update(offer.id, body);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Offer updated.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Offers',
            description: 'Cashback, coupon, and deal offers across all stores.',
            action: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New offer'),
            ),
          ),
          const SizedBox(height: AdminSpacing.lg),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView();
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _load);
      case ViewState.empty:
        return const EmptyView(message: 'No offers yet.');
      case ViewState.success:
        return AdminStickyTable(
          columns: const ['Title', 'Store', 'Type', 'Cashback', 'Status', ''],
          columnWidths: const [200, 140, 100, 140, 100, 70],
          columnAlignments: const [
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerLeft,
          ],
          itemCount: _offers.length,
          cellsBuilder: (context, index) {
            final offer = _offers[index];

            return [
              Text(offer.title),
              Text(offer.storeName),
              Text(offer.offerType),
              Text(offer.cashbackText ?? offer.cashbackType),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: StatusBadge.active(offer.isActive),
              ),
              TextButton(
                onPressed: () => _edit(offer),
                child: const Text('Edit'),
              ),
            ];
          },
        );
    }
  }
}
