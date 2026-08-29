import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/sm_colors.dart';
import '../../../../core/widgets/brand_logo_mark.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/login_demo_widgets.dart';
import '../../../../core/widgets/network_image_with_fallback.dart';
import '../../../../core/widgets/profile_avatar.dart';
import '../../../../core/widgets/view_state.dart';
import '../../../browsing/data/models/category.dart';
import '../../../browsing/data/models/offer_list_item.dart';
import '../../../browsing/data/models/search_result.dart';
import '../../../browsing/data/models/store_list_item.dart';
import '../../../browsing/data/services/browsing_api_service.dart';
import '../../../browsing/presentation/widgets/category_circle_tile.dart';
import '../../../browsing/presentation/widgets/offer_card.dart';
import '../../../browsing/presentation/widgets/promo_carousel.dart';
import '../../../browsing/presentation/widgets/search_group_header.dart';
import '../../../browsing/presentation/widgets/store_card.dart';
import '../../../profile/data/profile_summary_store.dart';
import '../../../shell/presentation/screens/main_shell.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onSelectTab});

  /// Provided by [MainShell] so "see all" actions switch bottom-nav tabs
  /// instead of pushing a duplicate screen on top of the shell.
  final void Function(ShellTab tab)? onSelectTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final BrowsingApiService _browsingApiService = BrowsingApiService();

  /// Profile lives in a shared store so both the dashboard topbar and the
  /// profile screen stay in sync without a state-management package.
  final ProfileSummaryStore _profileStore = ProfileSummaryStore.instance;

  // Browsing data (real backend data — no hardcoded brands).
  ViewState _categoriesState = ViewState.initial;
  List<Category> _categories = const [];
  String _categoriesError = '';
  bool _isLoadingCategories = false;

  ViewState _offersState = ViewState.initial;
  List<OfferListItem> _offers = const [];
  String _offersError = '';
  bool _isLoadingOffers = false;

  ViewState _storesState = ViewState.initial;
  List<StoreListItem> _stores = const [];
  String _storesError = '';
  bool _isLoadingStores = false;

  static const int _dashboardItemLimit = 10;

  // Inline search. Typing in the header's search bar swaps the scrolling
  // sections below it for results; clearing the query brings them back. No
  // navigation is involved, so the header never moves.
  static const Duration _searchDebounce = Duration(milliseconds: 400);

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  Timer? _searchDebounceTimer;
  ViewState _searchState = ViewState.initial;
  SearchResult? _searchResult;
  String _searchError = '';

  /// Trimmed query text. Whitespace-only input is not a search, so it leaves
  /// the dashboard in place — but the clear button keys off the raw text, so
  /// the user can still wipe it.
  String _searchQuery = '';

  bool get _isSearching => _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _profileStore.ensureLoaded();
    _loadCategories();
    _loadOffers();
    _loadStores();
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchTextChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _browsingApiService.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    if (_isLoadingCategories) return;
    _isLoadingCategories = true;
    setState(() => _categoriesState = ViewState.loading);

    try {
      final categories = await _browsingApiService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoriesState =
            categories.isEmpty ? ViewState.empty : ViewState.success;
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
        _categoriesError = 'Could not load categories.';
        _categoriesState = ViewState.error;
      });
    } finally {
      _isLoadingCategories = false;
    }
  }

  Future<void> _loadOffers() async {
    if (_isLoadingOffers) return;
    _isLoadingOffers = true;
    setState(() => _offersState = ViewState.loading);

    try {
      final offers = await _browsingApiService.getOffers();
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
        _offersError = 'Could not load offers.';
        _offersState = ViewState.error;
      });
    } finally {
      _isLoadingOffers = false;
    }
  }

  Future<void> _loadStores() async {
    if (_isLoadingStores) return;
    _isLoadingStores = true;
    setState(() => _storesState = ViewState.loading);

    try {
      final stores = await _browsingApiService.getStores();
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
        _storesError = 'Could not load stores.';
        _storesState = ViewState.error;
      });
    } finally {
      _isLoadingStores = false;
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _profileStore.refresh(),
      _loadCategories(),
      _loadOffers(),
      _loadStores(),
    ]);
  }

  /// Categories for the dashboard strip: only those with artwork.
  ///
  /// A category with no icon falls back to a tinted initial, which reads as a
  /// hole in a row of illustrated tiles. Filtering on the icon rather than on a
  /// hardcoded slug list means a category joins the strip as soon as its art is
  /// uploaded, and drops out again if the art is ever removed. The complete
  /// list, fallbacks included, is still one tap away on the categories screen.
  List<Category> get _topCategories {
    final illustrated = _categories.where(
      (c) => (c.iconUrl?.trim().isNotEmpty) ?? false,
    );
    return illustrated.take(_dashboardItemLimit).toList();
  }

  /// Offers to feature: prioritize `isFeatured`, then fall back to the rest.
  List<OfferListItem> get _featuredOffers {
    final featured = _offers.where((o) => o.isFeatured).toList();
    final ordered = [
      ...featured,
      ..._offers.where((o) => !o.isFeatured),
    ];
    return ordered.take(_dashboardItemLimit).toList();
  }

  /// Stores to surface: prioritize `isFeatured`, then fall back to the rest.
  List<StoreListItem> get _popularStores {
    final featured = _stores.where((s) => s.isFeatured).toList();
    final ordered = [
      ...featured,
      ..._stores.where((s) => !s.isFeatured),
    ];
    return ordered.take(_dashboardItemLimit).toList();
  }

  void _openCategories() {
    Navigator.pushNamed(context, RouteNames.categories);
  }

  void _openStores() {
    Navigator.pushNamed(context, RouteNames.stores);
  }

  void _openOffers() {
    Navigator.pushNamed(context, RouteNames.offers);
  }

  /// Keeps [_searchQuery] in step with the field and repaints the clear button.
  ///
  /// Without a listener the clear button would read stale text and only appear
  /// on the next unrelated rebuild.
  void _onSearchTextChanged() {
    final trimmed = _searchController.text.trim();
    if (trimmed == _searchQuery) {
      // Raw text moved (a trailing space, a caret change) but the effective
      // query did not. Still repaint so the clear button tracks the raw text.
      setState(() {});
      return;
    }
    setState(() => _searchQuery = trimmed);
  }

  void _onSearchQueryChanged(String value) {
    _searchDebounceTimer?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _searchResult = null;
        _searchState = ViewState.initial;
      });
      return;
    }

    // Show the spinner for the debounce window too, otherwise the swap from
    // dashboard to results opens on a blank frame.
    setState(() => _searchState = ViewState.loading);
    _searchDebounceTimer = Timer(_searchDebounce, () => _performSearch(trimmed));
  }

  Future<void> _performSearch(String query) async {
    setState(() => _searchState = ViewState.loading);

    try {
      final result = await _browsingApiService.search(query);
      if (!mounted) return;
      // Ignore stale responses if the query changed while awaiting.
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

  /// Returns to the dashboard: drops the query, the results and the keyboard.
  void _clearSearch() {
    _searchDebounceTimer?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchResult = null;
      _searchState = ViewState.initial;
      _searchError = '';
    });
  }

  void _openCategory(Category category) {
    Navigator.pushNamed(
      context,
      RouteNames.categoryStores,
      arguments: category,
    );
  }

  void _openStore(StoreListItem store) {
    Navigator.pushNamed(context, RouteNames.storeDetails, arguments: store.slug);
  }

  void _openOffer(OfferListItem offer) {
    Navigator.pushNamed(context, RouteNames.offerDetails, arguments: offer.slug);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // The drawer handles its own back dismissal now that the framework hosts
      // it, so only search needs intercepting here.
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSearching) {
          _clearSearch();
        }
      },
      child: Scaffold(
        body: LoginDemoBackground(
          child: SafeArea(
            // The topbar and search bar sit outside the scroll view so they
            // stay frozen at the top while the sections below scroll under
            // them. A pinned SliverPersistentHeader would need a fixed
            // extent, which the LayoutBuilder-driven compact/wide topbar
            // does not have. Keeping them outside also means search results
            // can replace the body without the search field moving.
            child: Column(
              children: [
                _buildPinnedHeader(),
                Expanded(
                  child: _isSearching
                      ? _buildSearchResultsPane()
                      : _buildDashboardContent(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent() {
    return RefreshIndicator(
      onRefresh: _refreshAll,
      child: CustomScrollView(
        // Swapping this subtree out for search results disposes its scroll
        // position; the key restores the offset when the dashboard comes back.
        key: const PageStorageKey<String>('dashboard-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeroSection(),
                const SizedBox(height: 18),
                _buildCategoryStrip(),
                const SizedBox(height: 16),
                _buildFeaturedOffersSection(),
                const SizedBox(height: 16),
                _buildPopularStoresSection(),
                const SizedBox(height: 16),
                _buildHowItWorks(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsPane() {
    switch (_searchState) {
      // `initial` is unreachable while searching (an empty query shows the
      // dashboard), but the switch stays exhaustive.
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Searching...');
      case ViewState.error:
        return ErrorView(
          message: _searchError,
          onRetry: () {
            final trimmed = _searchController.text.trim();
            if (trimmed.isNotEmpty) _performSearch(trimmed);
          },
        );
      case ViewState.empty:
        return const EmptyView(
          title: 'No results found',
          message: 'Try a different store, brand or keyword.',
          icon: Icons.search_off_rounded,
        );
      case ViewState.success:
        return _buildSearchResults(_searchResult!);
    }
  }

  Widget _buildSearchResults(SearchResult result) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        if (result.stores.isNotEmpty) ...[
          SearchGroupHeader(
            icon: Icons.storefront_outlined,
            label: 'Stores',
            count: result.stores.length,
          ),
          const SizedBox(height: 12),
          for (final store in result.stores) ...[
            StoreCard(store: store, onTap: () => _openStore(store)),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],
        if (result.offers.isNotEmpty) ...[
          SearchGroupHeader(
            icon: Icons.local_offer_outlined,
            label: 'Offers',
            count: result.offers.length,
          ),
          const SizedBox(height: 12),
          for (final offer in result.offers) ...[
            OfferCard(offer: offer, onTap: () => _openOffer(offer)),
            const SizedBox(height: 14),
          ],
        ],
      ],
    );
  }

  /// Frozen block at the top of the dashboard: menu button, logo, profile and
  /// the search bar. Painted over the scrolling content, with a soft shadow so
  /// sections passing underneath read as being behind it.
  Widget _buildPinnedHeader() {
    final colors = SmColors.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        // Opaque on purpose. The header is painted over the scroll view, so a
        // translucent fill would let the sections show through as they pass
        // underneath. Matches the background gradient's starting colour so
        // the seam with the scrolling area is invisible.
        color: colors.bgSecondary,
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildTopbar(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: _buildSearchBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopbar() {
    final colors = SmColors.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 20, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 390;

          return Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.10),
                      blurRadius: 32,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Transform.scale(
                  scale: 1.16,
                  child: Image.asset(
                    'assets/images/smartmoney_mark.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isCompact ? 154 : 190,
                    ),
                    child: Image.asset(
                      'assets/images/smartmoney_wordmark.png',
                      height: isCompact ? 24 : 27,
                      fit: BoxFit.contain,
                      alignment: Alignment.centerLeft,
                    ),
                  ),
                ),
              ),
              if (!isCompact) ...[
                const SizedBox(width: 10),
              ],
              _buildProfileSection(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProfileSection() {
    final colors = SmColors.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        final selectTab = widget.onSelectTab;
        if (selectTab != null) {
          selectTab(ShellTab.profile);
          return;
        }
        Navigator.pushNamed(context, RouteNames.profile).then((_) {
          _profileStore.refresh();
        });
      },
      child: Container(
        height: 46,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
        decoration: BoxDecoration(
          color: colors.surface.withValues(alpha: 0.76),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ValueListenableBuilder<ProfileSummary>(
              valueListenable: _profileStore.summary,
              builder: (context, profile, _) => ProfileAvatar(
                initials: profile.initials,
                imageUrl: profile.imageUrl,
                size: 34,
                fontSize: 12,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: colors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    switch (_offersState) {
      case ViewState.initial:
      case ViewState.loading:
        return const SizedBox(height: 172, child: _SectionLoading());
      case ViewState.error:
        return SizedBox(
          height: 172,
          child: _SectionInlineError(
            message: _offersError,
            onRetry: _loadOffers,
          ),
        );
      case ViewState.empty:
        return _buildWelcomeBanner();
      case ViewState.success:
        return PromoCarousel(
          offers: _featuredOffers,
          onOfferTap: _openOffer,
        );
    }
  }

  /// Shown instead of the carousel when the catalogue has no offers yet.
  Widget _buildWelcomeBanner() {
    final colors = SmColors.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, colors.primaryHover],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to SmartMoney',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Browse stores and start earning cashback on every purchase.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _openStores,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: colors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.storefront_outlined, size: 18),
            label: const Text(
              'Browse Stores',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  /// The header's search field.
  ///
  /// Hand-rolled rather than a themed [InputDecoration] so the pill keeps the
  /// exact resting look it had as a fake bar; the [TextField] is borderless and
  /// only supplies the editing behaviour. The trailing slot shows the (purely
  /// decorative) tune icon at rest and the clear button once there is text, so
  /// the pill never changes width.
  Widget _buildSearchBar() {
    final colors = SmColors.of(context);
    final hasText = _searchController.text.isNotEmpty;

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surfaceHover.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, color: colors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              textAlignVertical: TextAlignVertical.center,
              onChanged: _onSearchQueryChanged,
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isNotEmpty) {
                  _searchDebounceTimer?.cancel();
                  _performSearch(trimmed);
                }
              },
              cursorColor: colors.primary,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: 'Search stores, brands, offers',
                hintStyle: TextStyle(
                  color: colors.textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (hasText)
            IconButton(
              onPressed: _clearSearch,
              icon: const Icon(Icons.close_rounded),
              color: colors.textMuted,
              iconSize: 20,
              // Default IconButton sizing would fight the pill's padding.
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              splashRadius: 18,
              tooltip: 'Clear search',
            )
          else
            Icon(Icons.tune_rounded, color: colors.primary, size: 20),
        ],
      ),
    );
  }

  Widget _buildCategoryStrip() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Top Categories',
          subtitle: 'Browse by what you love',
          onTap: _openCategories,
        ),
        const SizedBox(height: 14),
        SizedBox(height: 108, child: _buildCategoryStripBody()),
      ],
    );
  }

  Widget _buildCategoryStripBody() {
    switch (_categoriesState) {
      case ViewState.initial:
      case ViewState.loading:
        return const _SectionLoading();
      case ViewState.error:
        return _SectionInlineError(
          message: _categoriesError,
          onRetry: _loadCategories,
        );
      case ViewState.empty:
        return const _SectionInlineEmpty(message: 'No categories yet');
      case ViewState.success:
        final categories = _topCategories;
        if (categories.isEmpty) {
          return const _SectionInlineEmpty(message: 'No categories yet');
        }
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final category = categories[index];
            return CategoryCircleTile(
              category: category,
              onTap: () => _openCategory(category),
            );
          },
        );
    }
  }

  Widget _buildFeaturedOffersSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: 'Featured Offers',
          subtitle: 'High-value deals to start earning',
          onTap: _openOffers,
        ),
        const SizedBox(height: 12),
        SizedBox(height: 218, child: _buildFeaturedOffersBody()),
      ],
    );
  }

  Widget _buildFeaturedOffersBody() {
    switch (_offersState) {
      case ViewState.initial:
      case ViewState.loading:
        return const _SectionLoading();
      case ViewState.error:
        return _SectionInlineError(
          message: _offersError,
          onRetry: _loadOffers,
        );
      case ViewState.empty:
        return const _SectionInlineEmpty(message: 'No offers yet');
      case ViewState.success:
        final offers = _featuredOffers;
        return ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: offers.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final offer = offers[index];
            return _DashboardOfferCard(
              offer: offer,
              onTap: () => _openOffer(offer),
            );
          },
        );
    }
  }

  Widget _buildPopularStoresSection() {
    return LoginDemoGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      // Blur disabled: this card lives inside the scroll view.
      enableBlur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'Popular Stores',
            subtitle: 'Browse brands with active cashback',
            showArrow: false,
          ),
          const SizedBox(height: 16),
          _buildPopularStoresBody(),
        ],
      ),
    );
  }

  Widget _buildPopularStoresBody() {
    switch (_storesState) {
      case ViewState.initial:
      case ViewState.loading:
        return const SizedBox(height: 90, child: _SectionLoading());
      case ViewState.error:
        return SizedBox(
          height: 90,
          child: _SectionInlineError(
            message: _storesError,
            onRetry: _loadStores,
          ),
        );
      case ViewState.empty:
        return const SizedBox(
          height: 90,
          child: _SectionInlineEmpty(message: 'No stores yet'),
        );
      case ViewState.success:
        final stores = _popularStores;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 560;
            final itemWidth = isWide
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;

            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: stores.map((store) {
                return SizedBox(
                  width: itemWidth,
                  child: StoreCard(
                    store: store,
                    onTap: () => _openStore(store),
                  ),
                );
              }).toList(),
            );
          },
        );
    }
  }

  Widget _buildHowItWorks() {
    return LoginDemoGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 20,
      // Blur disabled: this card lives inside the scroll view.
      enableBlur: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            title: 'How Cashback Works',
            subtitle: 'Three simple steps before every purchase',
            showArrow: false,
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Expanded(
                child: _StepTile(
                  number: '1',
                  title: 'Choose',
                  icon: Icons.storefront_outlined,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _StepTile(
                  number: '2',
                  title: 'Shop',
                  icon: Icons.shopping_cart_outlined,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _StepTile(
                  number: '3',
                  title: 'Earn',
                  icon: Icons.savings_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    bool showArrow = true,
    VoidCallback? onTap,
  }) {
    final colors = SmColors.of(context);

    return InkWell(
      onTap: showArrow ? onTap : null,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (showArrow)
            Icon(Icons.arrow_forward_rounded, color: colors.primary),
        ],
      ),
    );
  }
}

class _DashboardOfferCard extends StatelessWidget {
  const _DashboardOfferCard({required this.offer, required this.onTap});

  final OfferListItem offer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);
    final storeName = offer.storeName.trim();
    final cashback = offer.cashbackText?.trim() ?? '';
    final hasCashback = cashback.isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(14),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Offer artwork as the card's banner, with the store's brand mark
            // overlaid so the deal reads as "this brand, this offer".
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 76,
                    child: NetworkImageWithFallback(
                      url: offer.imageUrl,
                      fallbackIcon: Icons.local_offer_outlined,
                      backgroundColor: colors.primary.withValues(alpha: 0.10),
                      iconColor: colors.primary,
                      iconSize: 26,
                    ),
                  ),
                  Positioned(
                    left: 8,
                    bottom: 8,
                    child: BrandLogoMark(
                      name: storeName,
                      slug: offer.storeSlug,
                      logoUrl: offer.storeLogoUrl,
                      size: 30,
                      radius: 9,
                    ),
                  ),
                  if (offer.isFeatured)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.warning,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Featured',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            if (storeName.isNotEmpty)
              Text(
                storeName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                offer.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    hasCashback ? cashback : 'View offer',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasCashback ? colors.success : colors.primary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Shop',
                    style: TextStyle(
                      color: Colors.white,
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
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: SmColors.of(context).primary,
        ),
      ),
    );
  }
}

class _SectionInlineError extends StatelessWidget {
  const _SectionInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_rounded, color: colors.textMuted, size: 18),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SectionInlineEmpty extends StatelessWidget {
  const _SectionInlineEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: TextStyle(
          color: SmColors.of(context).textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.title,
    required this.icon,
  });

  final String number;
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = SmColors.of(context);

    return Container(
      height: 96,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.primary.withValues(alpha: 0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(icon, color: colors.primary, size: 25),
              Positioned(
                right: -10,
                top: -10,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: colors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
