import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_table_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state.dart';
import '../models/admin_category.dart';
import '../services/admin_category_api_service.dart';
import 'category_form_dialog.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final _service = AdminCategoryApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  List<AdminCategory> _categories = [];

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
    setState(() => _state = ViewState.loading);
    try {
      final categories = await _service.list();
      setState(() {
        _categories = categories;
        _state = categories.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  Future<void> _create() async {
    final result = await showCategoryFormDialog(context);
    if (result == null || !mounted) return;

    try {
      await _service.create(
        name: result.name,
        slug: result.slug,
        description: result.description,
        iconUrl: result.iconUrl,
        displayOrder: result.displayOrder,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Category created.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _edit(AdminCategory category) async {
    final result = await showCategoryFormDialog(context, existing: category);
    if (result == null || !mounted) return;

    try {
      await _service.update(
        category.id,
        name: result.name,
        slug: result.slug ?? category.slug,
        description: result.description,
        iconUrl: result.iconUrl,
        displayOrder: result.displayOrder,
        isActive: result.isActive,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Category updated.');
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
            title: 'Categories',
            description:
                'Browse categories shown to users, and how stores are grouped.',
            action: FilledButton.icon(
              onPressed: _create,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New category'),
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
        return const EmptyView(message: 'No categories yet.');
      case ViewState.success:
        return AdminTableCard(
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Slug')),
              DataColumn(label: Text('Order')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('')),
            ],
            rows: _categories
                .map(
                  (category) => DataRow(
                    cells: [
                      DataCell(Text(category.name)),
                      DataCell(Text(category.slug)),
                      DataCell(Text('${category.displayOrder}')),
                      DataCell(StatusBadge.active(category.isActive)),
                      DataCell(
                        TextButton(
                          onPressed: () => _edit(category),
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
