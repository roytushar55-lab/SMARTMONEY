import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _storeService.dispose();
    _categoryService.dispose();
    super.dispose();
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
    return Padding(
      padding: const EdgeInsets.all(AdminSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Stores',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AdminColors.textPrimary,
                ),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New store'),
              ),
            ],
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
        return const EmptyView(message: 'No stores yet.');
      case ViewState.success:
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Slug')),
              DataColumn(label: Text('Categories')),
              DataColumn(label: Text('Featured')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('')),
            ],
            rows: _stores
                .map(
                  (store) => DataRow(
                    cells: [
                      DataCell(Text(store.name)),
                      DataCell(Text(store.slug)),
                      DataCell(Text(_categoryNames(store))),
                      DataCell(Icon(
                        store.isFeatured ? Icons.star : Icons.star_border,
                        size: 18,
                        color: store.isFeatured
                            ? AdminColors.warning
                            : AdminColors.textMuted,
                      )),
                      DataCell(StatusBadge.active(store.isActive)),
                      DataCell(
                        TextButton(
                          onPressed: () => _edit(store),
                          child: const Text('Edit'),
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        );
    }
  }
}
