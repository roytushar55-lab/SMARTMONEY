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
import '../models/admin_affiliate_network.dart';
import '../services/admin_affiliate_api_service.dart';
import 'mapping_form_dialog.dart';
import 'network_form_dialog.dart';

/// SuperAdmin-only: affiliate networks and store↔network mappings. This is
/// what finally lets an admin onboard a new store's commission attribution
/// without a manual SQL insert.
class AffiliateScreen extends StatefulWidget {
  const AffiliateScreen({super.key});

  @override
  State<AffiliateScreen> createState() => _AffiliateScreenState();
}

class _AffiliateScreenState extends State<AffiliateScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);

  final _affiliateService = AdminAffiliateApiService();
  final _storeService = AdminStoreApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  List<AdminAffiliateNetwork> _networks = [];
  List<AdminStoreAffiliateMapping> _mappings = [];
  List<AdminStore> _stores = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _affiliateService.dispose();
    _storeService.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);
    try {
      final results = await Future.wait([
        _affiliateService.listNetworks(),
        _affiliateService.listMappings(),
        _storeService.list(),
      ]);
      setState(() {
        _networks = results[0] as List<AdminAffiliateNetwork>;
        _mappings = results[1] as List<AdminStoreAffiliateMapping>;
        _stores = results[2] as List<AdminStore>;
        _state = ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  Future<void> _createNetwork() async {
    final result = await showNetworkFormDialog(context);
    if (result == null || !mounted) return;
    try {
      await _affiliateService.createNetwork(result.name, result.code);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Network created.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _editNetwork(AdminAffiliateNetwork network) async {
    final result = await showNetworkFormDialog(context, existing: network);
    if (result == null || !mounted) return;
    try {
      await _affiliateService.updateNetwork(
        network.id,
        name: result.name,
        code: result.code,
        isActive: result.isActive,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Network updated.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _createMapping() async {
    if (_stores.isEmpty || _networks.isEmpty) {
      showErrorSnackBar(context, 'Create a store and a network first.');
      return;
    }
    final result = await showMappingFormDialog(
      context,
      stores: _stores,
      networks: _networks,
    );
    if (result == null || !mounted) return;
    try {
      await _affiliateService.createMapping(
        storeId: result.storeId!,
        affiliateNetworkId: result.affiliateNetworkId!,
        externalMerchantId: result.externalMerchantId,
        externalMerchantName: result.externalMerchantName,
        merchantUrl: result.merchantUrl,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Mapping created.');
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    }
  }

  Future<void> _editMapping(AdminStoreAffiliateMapping mapping) async {
    final result = await showMappingFormDialog(
      context,
      stores: _stores,
      networks: _networks,
      existing: mapping,
    );
    if (result == null || !mounted) return;
    try {
      await _affiliateService.updateMapping(
        mapping.id,
        externalMerchantId: result.externalMerchantId,
        externalMerchantName: result.externalMerchantName,
        merchantUrl: result.merchantUrl,
        isActive: result.isActive,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Mapping updated.');
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
          const AdminPageHeader(
            title: 'Affiliate networks',
            description:
                'Providers and which merchant id maps each store to them.',
          ),
          const SizedBox(height: AdminSpacing.md),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            labelColor: AdminColors.primary,
            tabs: const [
              Tab(text: 'Networks'),
              Tab(text: 'Store mappings'),
            ],
          ),
          const SizedBox(height: AdminSpacing.lg),
          Expanded(
            child: switch (_state) {
              ViewState.initial || ViewState.loading => const LoadingView(),
              ViewState.error => ErrorView(
                message: _errorMessage,
                onRetry: _load,
              ),
              _ => TabBarView(
                controller: _tabController,
                children: [_buildNetworksTab(), _buildMappingsTab()],
              ),
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNetworksTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _createNetwork,
            icon: const Icon(Icons.add),
            label: const Text('New network'),
          ),
        ),
        const SizedBox(height: AdminSpacing.md),
        if (_networks.isEmpty)
          const EmptyView(message: 'No affiliate networks yet.')
        else
          Expanded(
            child: AdminStickyTable(
              columns: const ['Name', 'Code', 'Status', ''],
              columnWidths: const [160, 120, 100, 70],
              columnAlignments: const [
                Alignment.centerLeft,
                Alignment.centerLeft,
                Alignment.center,
                Alignment.centerLeft,
              ],
              itemCount: _networks.length,
              cellsBuilder: (context, index) {
                final network = _networks[index];

                return [
                  Text(network.name),
                  Text(network.code),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: StatusBadge.active(network.isActive),
                  ),
                  TextButton(
                    onPressed: () => _editNetwork(network),
                    child: const Text('Edit'),
                  ),
                ];
              },
            ),
          ),
      ],
    );
  }

  Widget _buildMappingsTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _createMapping,
            icon: const Icon(Icons.add),
            label: const Text('New mapping'),
          ),
        ),
        const SizedBox(height: AdminSpacing.md),
        if (_mappings.isEmpty)
          const EmptyView(message: 'No store mappings yet.')
        else
          Expanded(
            child: AdminStickyTable(
              columns: const [
                'Store',
                'Network',
                'External merchant id',
                'Status',
                '',
              ],
              columnWidths: const [160, 140, 200, 100, 70],
              columnAlignments: const [
                Alignment.centerLeft,
                Alignment.centerLeft,
                Alignment.centerLeft,
                Alignment.center,
                Alignment.centerLeft,
              ],
              itemCount: _mappings.length,
              cellsBuilder: (context, index) {
                final mapping = _mappings[index];

                return [
                  Text(mapping.storeName),
                  Text(mapping.affiliateNetworkName),
                  Text(mapping.externalMerchantId),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: StatusBadge.active(mapping.isActive),
                  ),
                  TextButton(
                    onPressed: () => _editMapping(mapping),
                    child: const Text('Edit'),
                  ),
                ];
              },
            ),
          ),
      ],
    );
  }
}
