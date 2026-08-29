import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/theme/sm_radius.dart';
import '../../../../core/theme/sm_spacing.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/view_state.dart';
import '../../data/models/category.dart';
import '../../data/models/offer_list_item.dart';
import '../../data/models/search_result.dart';
import '../../data/models/store_list_item.dart';
import '../../data/services/browsing_api_service.dart';
import '../widgets/category_circle_tile.dart';
import '../widgets/offer_card.dart';
import '../widgets/store_card.dart';

const _sectionLimit = 6;
const _searchDebounce = Duration(milliseconds: 400);

/// Shopping discovery tab: search, categories, offers and stores in one
/// screen, all backed by the existing public browsing endpoints.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final BrowsingApiService _service = BrowsingApiService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  ViewState _categoriesState = ViewState.initial;
  List<Category> _categories = const [];
  String _categoriesError = '';

  ViewState _offersState = ViewState.initial;
  List<OfferListItem> _offers = const [];
  String _offersError = '';

  ViewState _storesState = ViewState.initial;
  List<StoreListItem> _stores = const [];
  String _storesError = '';

  String _searchQuery = '';
  ViewState _searchState = ViewState.initial;
  SearchResult? _searchResult;
  String _searchError = '';
  Timer? _searchDebounceTimer;

  bool get _isSearching => _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _loadCategories();
    _loadOffers();
    _loadStores();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    setState(() => _categoriesState = ViewState.loading);
    try {
      final categories = await _service.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoriesState = categories.isEmpty
            ? ViewState.empty
            : ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _categoriesError = e.message;
        _categoriesState = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categoriesError = 'Something went wrong. Please try again.';
        _categoriesState = ViewState.error;
      });
    }
  }

  Future<void> _loadOffers() async {
    setState(() => _offersState = ViewState.loading);
    try {
      final offers = await _service.getOffers();
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
        _offersError = 'Something went wrong. Please try again.';
        _offersState = ViewState.error;
      });
    }
  }

  Future<void> _loadStores() async {
    setState(() => _storesState = ViewState.loading);
    try {
      final stores = await _service.getStores();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _storesState = stores.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _storesError = e.message;
        _storesState = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _storesError = 'Something went wrong. Please try again.';
        _storesState = ViewState.error;
      });
    }
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadCategories(), _loadOffers(), _loadStores()]);
  }

  void _onSearchTextChanged() {
    final trimmed = _searchController.text.trim();
    if (trimmed == _searchQuery) {
      setState(() {});
      return;
    }

    _searchDebounceTimer?.cancel();
    setState(() => _searchQuery = trimmed);

    if (trimmed.isEmpty) {
      setState(() {
        _searchResult = null;
        _searchState = ViewState.initial;
      });
      return;
    }

    setState(() => _searchState = ViewState.loading);
    _searchDebounceTimer = Timer(
      _searchDebounce,
      () => _performSearch(trimmed),
    );
  }

  Future<void> _performSearch(String query) async {
    try {
      final result = await _service.search(query);
      if (!mounted) return;
      if (query != _searchController.text.trim()) return;
      setState(() {
        _searchResult = result;
        _searchState = result.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (query != _searchController.text.trim()) return;
      setState(() {
        _searchError = e.message;
        _searchState = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      if (query != _searchController.text.trim()) return;
      setState(() {
        _searchError = 'Something went wrong. Please try again.';
        _searchState = ViewState.error;
      });
    }
  }

  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _searchResult = null;
      _searchState = ViewState.initial;
    });
  }

  void _openCategory(Category category) {
    Navigator.pushNamed(context, RouteNames.categoryStores, arguments: category);
  }

  void _openStore(StoreListItem store) {
    Navigator.pushNamed(context, RouteNames.storeDetails, arguments: store.slug);
  }

  void _openOffer(OfferListItem offer) {
    Navigator.pushNamed(context, RouteNames.offerDetails, arguments: offer.slug);
  }

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Scaffold(
      backgroundColor: colors.bgPrimary,
      appBar: AppBar(title: const Text('Explore')),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SmSpacing.lg,
                SmSpacing.md,
                SmSpacing.lg,
                SmSpacing.sm,
              ),
              child: _buildSearchBar(colors),
            ),
            Expanded(
              child: _isSearching
                  ? _buildSearchResults(colors)
                  : _buildDiscovery(colors),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(SmColors colors) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(SmRadius.button),
        border: Border.all(color: colors.border),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: colors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search stores and offers',
          hintStyle: TextStyle(color: colors.textMuted),
          prefixIcon: Icon(Icons.search_rounded, color: colors.textMuted),
          suffixIcon: _isSearching
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: colors.textMuted),
                  onPressed: _clearSearch,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }

  Widget _buildSearchResults(SmColors colors) {
    switch (_searchState) {
      case ViewState.initial:
        return const SizedBox.shrink();
      case ViewState.loading:
        return const LoadingView(message: 'Searching...');
      case ViewState.error:
        return ErrorView(
          message: _searchError,
          onRetry: () => _performSearch(_searchQuery),
        );
      case ViewState.empty:
        return const EmptyView(
          title: 'No results',
          message: 'Try a different store or offer name.',
          icon: Icons.search_off_rounded,
        );
      case ViewState.success:
        final result = _searchResult!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            SmSpacing.lg,
            SmSpacing.sm,
            SmSpacing.lg,
            SmSpacing.xxl,
          ),
          children: [
            if (result.stores.isNotEmpty) ...[
              _SectionHeader(title: 'Stores', colors: colors),
              const SizedBox(height: SmSpacing.sm),
              for (final store in result.stores) ...[
                StoreCard(store: store, onTap: () => _openStore(store)),
                const SizedBox(height: SmSpacing.sm),
              ],
              const SizedBox(height: SmSpacing.md),
            ],
            if (result.offers.isNotEmpty) ...[
              _SectionHeader(title: 'Offers', colors: colors),
              const SizedBox(height: SmSpacing.sm),
              for (final offer in result.offers) ...[
                OfferCard(offer: offer, onTap: () => _openOffer(offer)),
                const SizedBox(height: SmSpacing.sm),
              ],
            ],
          ],
        );
    }
  }

  Widget _buildDiscovery(SmColors colors) {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          SmSpacing.lg,
          SmSpacing.sm,
          SmSpacing.lg,
          SmSpacing.xxl,
        ),
        children: [
          _SectionHeader(
            title: 'Categories',
            colors: colors,
            onSeeAll: () => Navigator.pushNamed(context, RouteNames.categories),
          ),
          const SizedBox(height: SmSpacing.md),
          SizedBox(height: 104, child: _buildCategoriesRow(colors)),
          const SizedBox(height: SmSpacing.xl),
          _SectionHeader(
            title: 'Best Cashback Offers',
            colors: colors,
            onSeeAll: () => Navigator.pushNamed(context, RouteNames.offers),
          ),
          const SizedBox(height: SmSpacing.md),
          _buildOffersSection(colors),
          const SizedBox(height: SmSpacing.xl),
          _SectionHeader(
            title: 'Popular Stores',
            colors: colors,
            onSeeAll: () => Navigator.pushNamed(context, RouteNames.stores),
          ),
          const SizedBox(height: SmSpacing.md),
          _buildStoresSection(colors),
        ],
      ),
    );
  }

  Widget _buildCategoriesRow(SmColors colors) {
    switch (_categoriesState) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView();
      case ViewState.error:
        return ErrorView(message: _categoriesError, onRetry: _loadCategories);
      case ViewState.empty:
        return Center(
          child: Text(
            'No categories yet.',
            style: TextStyle(color: colors.textMuted),
          ),
        );
      case ViewState.success:
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: SmSpacing.md),
          itemBuilder: (context, index) {
            final category = _categories[index];
            return CategoryCircleTile(
              category: category,
              onTap: () => _openCategory(category),
            );
          },
        );
    }
  }

  Widget _buildOffersSection(SmColors colors) {
    switch (_offersState) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView();
      case ViewState.error:
        return ErrorView(message: _offersError, onRetry: _loadOffers);
      case ViewState.empty:
        return EmptyView(
          title: 'No offers yet',
          message: 'Offers will appear here once they are available.',
          icon: Icons.local_offer_outlined,
        );
      case ViewState.success:
        final items = _offers.take(_sectionLimit).toList();
        return Column(
          children: [
            for (final offer in items) ...[
              OfferCard(offer: offer, onTap: () => _openOffer(offer)),
              const SizedBox(height: SmSpacing.md),
            ],
          ],
        );
    }
  }

  Widget _buildStoresSection(SmColors colors) {
    switch (_storesState) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView();
      case ViewState.error:
        return ErrorView(message: _storesError, onRetry: _loadStores);
      case ViewState.empty:
        return EmptyView(
          title: 'No stores yet',
          message: 'Stores will appear here once they are available.',
          icon: Icons.storefront_outlined,
        );
      case ViewState.success:
        final items = _stores.take(_sectionLimit).toList();
        return Column(
          children: [
            for (final store in items) ...[
              StoreCard(store: store, onTap: () => _openStore(store)),
              const SizedBox(height: SmSpacing.sm),
            ],
          ],
        );
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.colors,
    this.onSeeAll,
  });

  final String title;
  final SmColors colors;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              'See all',
              style: TextStyle(color: colors.primary, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
