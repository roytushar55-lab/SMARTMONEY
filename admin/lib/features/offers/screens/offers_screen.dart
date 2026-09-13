import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_search_status_bar.dart';
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

  final _searchController = TextEditingController();
  String _search = '';

  /// null = no status toggle applied, true = "Active" chip selected, false =
  /// "Inactive" chip selected. Both filters are applied client-side since
  /// the full offer list is already loaded.
  bool? _statusFilter;

  /// null = no featured toggle applied, true = "Featured" chip selected,
  /// false = "Not featured" chip selected.
  bool? _featuredFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _offerService.dispose();
    _storeService.dispose();
    super.dispose();
  }

  List<AdminOffer> get _filteredOffers {
    Iterable<AdminOffer> result = _offers;

    if (_statusFilter != null) {
      result = result.where((offer) => offer.isActive == _statusFilter);
    }

    if (_featuredFilter != null) {
      result = result.where((offer) => offer.isFeatured == _featuredFilter);
    }

    if (_search.isNotEmpty) {
      final term = _search.toLowerCase();
      result = result.where(
        (offer) =>
            offer.title.toLowerCase().contains(term) ||
            offer.storeName.toLowerCase().contains(term) ||
            offer.offerType.toLowerCase().contains(term),
      );
    }

    return result.toList();
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value.trim());
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _search = '');
  }

  /// Tapping a selected chip clears the filter back to "all"; tapping the
  /// other chip switches straight over.
  void _toggleStatusFilter(bool value) {
    setState(() => _statusFilter = _statusFilter == value ? null : value);
  }

  void _toggleFeaturedFilter(bool value) {
    setState(() => _featuredFilter = _featuredFilter == value ? null : value);
  }

  String _emptyMessage() {
    final words = [
      if (_statusFilter == true) 'active',
      if (_statusFilter == false) 'inactive',
      if (_featuredFilter == true) 'featured',
      if (_featuredFilter == false) 'non-featured',
    ];
    final statusWord = words.isEmpty ? '' : '${words.join(' ')} ';

    if (_search.isEmpty) return 'No ${statusWord}offers found.';
    return 'No ${statusWord}offers match "$_search".';
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

  /// Flips [offer]'s featured flag directly from the table's star toggle,
  /// without opening the edit dialog. The backend's update endpoint takes a
  /// full replacement body (no PATCH), so this resends every field exactly
  /// as [offer_form_dialog.dart]'s save button would, with only isFeatured
  /// flipped.
  Future<void> _toggleFeatured(AdminOffer offer) async {
    final body = <String, dynamic>{
      'title': offer.title,
      'slug': offer.slug,
      'offerType': offer.offerType,
      'shortDescription': offer.shortDescription,
      'description': offer.description,
      'termsAndConditions': offer.termsAndConditions,
      'imageUrl': offer.imageUrl,
      'cashbackType': offer.cashbackType,
      'cashbackValue': offer.cashbackValue,
      'cashbackText': offer.cashbackText,
      'couponCode': offer.couponCode,
      'destinationUrl': offer.destinationUrl,
      'startAt': offer.startAt?.toIso8601String(),
      'endAt': offer.endAt?.toIso8601String(),
      'isFeatured': !offer.isFeatured,
      'priority': offer.priority,
      'isActive': offer.isActive,
    };

    try {
      await _offerService.update(offer.id, body);
      if (!mounted) return;
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
          AdminSearchStatusBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
            statusFilter: _statusFilter,
            onStatusToggle: _toggleStatusFilter,
            hintText: 'Search title, store, type…',
            extraChips: [
              AdminFilterChip(
                selected: _featuredFilter == true,
                label: 'Featured',
                activeColor: AdminColors.warning,
                onTap: () => _toggleFeaturedFilter(true),
              ),
              AdminFilterChip(
                selected: _featuredFilter == false,
                label: 'Not featured',
                activeColor: AdminColors.textSecondary,
                onTap: () => _toggleFeaturedFilter(false),
              ),
            ],
          ),
          const SizedBox(height: AdminSpacing.md),
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
        final filtered = _filteredOffers;

        if (filtered.isEmpty) {
          return EmptyView(
            icon: _search.isEmpty ? Icons.inbox_outlined : Icons.search_off_rounded,
            message: _emptyMessage(),
          );
        }

        return AdminStickyTable(
          columns: const [
            'Title',
            'Store',
            'Type',
            'Cashback',
            'Featured',
            'Status',
            '',
          ],
          columnWidths: const [200, 140, 100, 140, 90, 100, 70],
          columnAlignments: const [
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.center,
            Alignment.center,
            Alignment.centerLeft,
          ],
          itemCount: filtered.length,
          cellsBuilder: (context, index) {
            final offer = filtered[index];

            return [
              Text(offer.title),
              Text(offer.storeName),
              Text(offer.offerType),
              Text(offer.cashbackText ?? offer.cashbackType),
              Tooltip(
                message: offer.isFeatured
                    ? 'Featured — tap to unfeature'
                    : 'Not featured — tap to feature',
                child: InkWell(
                  onTap: () => _toggleFeatured(offer),
                  borderRadius: BorderRadius.circular(AdminRadius.chip),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      offer.isFeatured ? Icons.star : Icons.star_border,
                      size: 18,
                      color: offer.isFeatured
                          ? AdminColors.warning
                          : AdminColors.textMuted,
                    ),
                  ),
                ),
              ),
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
