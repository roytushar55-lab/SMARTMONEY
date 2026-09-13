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
import '../../categories/models/admin_category.dart';
import '../../categories/services/admin_category_api_service.dart';
import '../models/admin_store.dart';
import '../services/admin_store_api_service.dart';
import 'store_form_dialog.dart';

class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final _storeService = AdminStoreApiService();
  final _categoryService = AdminCategoryApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  List<AdminStore> _stores = [];
  List<AdminCategory> _categories = [];

  final _searchController = TextEditingController();
  String _search = '';

  /// null = no status toggle applied, true = "Active" chip selected, false =
  /// "Inactive" chip selected.
  bool? _statusFilter;

  /// null = no featured toggle applied, true = "Featured" chip selected,
  /// false = "Not featured" chip selected. All three filters are applied
  /// client-side since the full store list is already loaded.
  bool? _featuredFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _storeService.dispose();
    _categoryService.dispose();
    super.dispose();
  }

  List<AdminStore> get _filteredStores {
    Iterable<AdminStore> result = _stores;

    if (_statusFilter != null) {
      result = result.where((store) => store.isActive == _statusFilter);
    }

    if (_featuredFilter != null) {
      result = result.where((store) => store.isFeatured == _featuredFilter);
    }

    if (_search.isNotEmpty) {
      final term = _search.toLowerCase();
      result = result.where(
        (store) =>
            store.name.toLowerCase().contains(term) ||
            store.slug.toLowerCase().contains(term) ||
            _categoryNames(store).toLowerCase().contains(term),
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

    if (_search.isEmpty) return 'No ${statusWord}stores found.';
    return 'No ${statusWord}stores match "$_search".';
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);
    try {
      final results = await Future.wait([
        _storeService.list(),
        _categoryService.list(),
      ]);
      setState(() {
        _stores = results[0] as List<AdminStore>;
        _categories = results[1] as List<AdminCategory>;
        _state = _stores.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  String _categoryNames(AdminStore store) {
    if (store.categoryIds.isEmpty) return '—';
    final names = _categories
        .where((category) => store.categoryIds.contains(category.id))
        .map((category) => category.name);
    return names.isEmpty ? '—' : names.join(', ');
  }

  Future<void> _create() async {
    final result = await showStoreFormDialog(context, categories: _categories);
    if (result == null || !mounted) return;

    try {
      await _storeService.create(
        name: result.name,
        slug: result.slug,
        shortDescription: result.shortDescription,
        description: result.description,
        logoUrl: result.logoUrl,
        bannerUrl: result.bannerUrl,
        websiteUrl: result.websiteUrl,
        defaultCashbackText: result.defaultCashbackText,
        isFeatured: result.isFeatured,
        displayOrder: result.displayOrder,
        categoryIds: result.categoryIds,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Store created.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _edit(AdminStore store) async {
    final result = await showStoreFormDialog(
      context,
      categories: _categories,
      existing: store,
    );
    if (result == null || !mounted) return;

    try {
      await _storeService.update(
        store.id,
        name: result.name,
        slug: result.slug ?? store.slug,
        shortDescription: result.shortDescription,
        description: result.description,
        logoUrl: result.logoUrl,
        bannerUrl: result.bannerUrl,
        websiteUrl: result.websiteUrl,
        defaultCashbackText: result.defaultCashbackText,
        isFeatured: result.isFeatured,
        displayOrder: result.displayOrder,
        isActive: result.isActive,
        categoryIds: result.categoryIds,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Store updated.');
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
            title: 'Stores',
            description: 'Manage the merchants users can earn cashback with.',
            action: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New store'),
            ),
          ),
          const SizedBox(height: AdminSpacing.lg),
          AdminSearchStatusBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
            statusFilter: _statusFilter,
            onStatusToggle: _toggleStatusFilter,
            hintText: 'Search name, slug, category…',
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
        return const EmptyView(message: 'No stores yet.');
      case ViewState.success:
        final filtered = _filteredStores;

        if (filtered.isEmpty) {
          return EmptyView(
            icon: _search.isEmpty ? Icons.inbox_outlined : Icons.search_off_rounded,
            message: _emptyMessage(),
          );
        }

        return AdminStickyTable(
          columns: const [
            'Name',
            'Slug',
            'Categories',
            'Featured',
            'Status',
            '',
          ],
          columnWidths: const [160, 160, 200, 90, 100, 70],
          columnAlignments: const [
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.centerLeft,
            Alignment.center,
            Alignment.centerLeft,
          ],
          itemCount: filtered.length,
          cellsBuilder: (context, index) {
            final store = filtered[index];

            return [
              Text(store.name),
              Text(store.slug),
              Text(_categoryNames(store)),
              Icon(
                store.isFeatured ? Icons.star : Icons.star_border,
                size: 18,
                color: store.isFeatured
                    ? AdminColors.warning
                    : AdminColors.textMuted,
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: StatusBadge.active(store.isActive),
              ),
              TextButton(
                onPressed: () => _edit(store),
                child: const Text('Edit'),
              ),
            ];
          },
        );
    }
  }
}
