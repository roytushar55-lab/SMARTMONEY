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
import '../../../core/widgets/view_state.dart';
import '../../categories/models/admin_category.dart';
import '../../categories/services/admin_category_api_service.dart';
import '../../stores/models/admin_store.dart';
import '../../stores/services/admin_store_api_service.dart';
import '../models/admin_cashback_rate_override.dart';
import '../models/admin_network_cashback_settings.dart';
import '../services/cashback_settings_api_service.dart';
import 'network_global_settings_card.dart';
import 'override_form_dialog.dart';

/// One affiliate network's cashback policy: its "Global" defaults plus any
/// store/category overrides layered on top.
class NetworkCashbackDetailScreen extends StatefulWidget {
  const NetworkCashbackDetailScreen({
    super.key,
    required this.networkId,
    required this.networkName,
  });

  final String networkId;
  final String networkName;

  @override
  State<NetworkCashbackDetailScreen> createState() =>
      _NetworkCashbackDetailScreenState();
}

class _NetworkCashbackDetailScreenState
    extends State<NetworkCashbackDetailScreen> {
  final _service = CashbackSettingsApiService();
  final _storeService = AdminStoreApiService();
  final _categoryService = AdminCategoryApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  AdminNetworkCashbackDetail? _detail;
  List<AdminStore> _stores = [];
  List<AdminCategory> _categories = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    _storeService.dispose();
    _categoryService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);
    try {
      final results = await Future.wait([
        _service.getNetworkSettings(widget.networkId),
        _storeService.list(),
        _categoryService.list(),
      ]);
      setState(() {
        _detail = results[0] as AdminNetworkCashbackDetail;
        _stores = results[1] as List<AdminStore>;
        _categories = results[2] as List<AdminCategory>;
        _state = ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  Future<void> _saveGlobal(
    double userSharePercent,
    int confirmationWindowDays,
  ) async {
    try {
      final updated = await _service.updateNetworkGlobal(
        widget.networkId,
        userSharePercent: userSharePercent,
        confirmationWindowDays: confirmationWindowDays,
      );
      if (!mounted) return;
      setState(() => _detail = _detail?.let((d) => AdminNetworkCashbackDetail(
            networkId: d.networkId,
            networkName: d.networkName,
            global: updated,
            overrides: d.overrides,
          )));
      showSuccessSnackBar(context, 'Global cashback settings updated.');
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _addOverride() async {
    if (_stores.isEmpty) {
      showErrorSnackBar(context, 'Create a store first.');
      return;
    }
    final result = await showOverrideFormDialog(
      context,
      stores: _stores,
      categories: _categories,
    );
    if (result == null || !mounted) return;

    try {
      await _service.createOverride(
        widget.networkId,
        storeId: result.storeId,
        categoryId: result.categoryId,
        userSharePercent: result.userSharePercent,
        confirmationWindowDays: result.confirmationWindowDays,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Override created.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _editOverride(AdminCashbackRateOverride override) async {
    final result = await showOverrideFormDialog(
      context,
      stores: _stores,
      categories: _categories,
      existing: override,
    );
    if (result == null || !mounted) return;

    try {
      await _service.updateOverride(
        widget.networkId,
        override.id,
        userSharePercent: result.userSharePercent,
        confirmationWindowDays: result.confirmationWindowDays,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Override updated.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _deleteOverride(AdminCashbackRateOverride override) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete override',
      message:
          'Remove the ${override.userSharePercent}% override for '
          '${override.storeName}'
          '${override.categoryName != null ? ' · ${override.categoryName}' : ''}? '
          'The network global policy will apply instead.',
      confirmLabel: 'Delete',
      danger: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await _service.deleteOverride(widget.networkId, override.id);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Override deleted.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.bgPrimary,
      body: AdminPageScaffold(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back),
                  tooltip: 'Back to networks',
                ),
                const SizedBox(width: AdminSpacing.sm),
                Expanded(
                  child: AdminPageHeader(
                    title: widget.networkName,
                    description:
                        'Global cashback policy and store/category overrides.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdminSpacing.lg),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading network settings...');
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _load);
      case ViewState.empty:
      case ViewState.success:
        return SingleChildScrollView(child: _buildContent(_detail!));
    }
  }

  Widget _buildContent(AdminNetworkCashbackDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NetworkGlobalSettingsCard(global: detail.global, onSave: _saveGlobal),
        const SizedBox(height: AdminSpacing.xl),
        _buildOverridesHeader(),
        const SizedBox(height: AdminSpacing.md),
        if (detail.overrides.isEmpty)
          const EmptyView(message: 'No overrides yet for this network.')
        else
          _buildOverridesTable(detail.overrides),
      ],
    );
  }

  Widget _buildOverridesHeader() {
    const title = Text(
      'Store & category overrides',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    );
    final button = FilledButton.icon(
      onPressed: _addOverride,
      icon: const Icon(Icons.add),
      label: const Text('Add override'),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AdminBreakpoints.mobile;

        if (isMobile) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              title,
              const SizedBox(height: AdminSpacing.md),
              button,
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [title, button],
        );
      },
    );
  }

  Widget _buildOverridesTable(List<AdminCashbackRateOverride> overrides) {
    return AdminStickyTable(
      shrinkWrap: true,
      columns: const ['Store', 'Category', 'User share', 'Window', ''],
      columnWidths: const [150, 150, 100, 90, 90],
      itemCount: overrides.length,
      cellsBuilder: (context, index) {
        final override = overrides[index];

        return [
          Text(override.storeName),
          Text(override.categoryName ?? 'All categories'),
          Text('${override.userSharePercent}%'),
          Text('${override.confirmationWindowDays} days'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _compactIconButton(
                onPressed: () => _editOverride(override),
                icon: Icons.edit_outlined,
                tooltip: 'Edit',
              ),
              _compactIconButton(
                onPressed: () => _deleteOverride(override),
                icon: Icons.delete_outline,
                tooltip: 'Delete',
                color: AdminColors.danger,
              ),
            ],
          ),
        ];
      },
    );
  }

  Widget _compactIconButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String tooltip,
    Color? color,
  }) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      color: color,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 18,
    );
  }
}

extension _Let<T> on T {
  R let<R>(R Function(T) block) => block(this);
}
