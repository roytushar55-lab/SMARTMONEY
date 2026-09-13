import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_table_card.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state.dart';
import '../../affiliate/models/admin_affiliate_network.dart';
import '../services/cashback_settings_api_service.dart';
import 'network_cashback_detail_screen.dart';

/// Entry point for the hierarchical cashback settings flow: pick a network,
/// then drill into its global policy and store/category overrides.
class CashbackNetworksScreen extends StatefulWidget {
  const CashbackNetworksScreen({super.key});

  @override
  State<CashbackNetworksScreen> createState() =>
      _CashbackNetworksScreenState();
}

class _CashbackNetworksScreenState extends State<CashbackNetworksScreen> {
  final _service = CashbackSettingsApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  List<AdminAffiliateNetwork> _networks = [];

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
      final networks = await _service.listNetworks();
      setState(() {
        _networks = networks;
        _state = networks.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  Future<void> _openNetwork(AdminAffiliateNetwork network) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NetworkCashbackDetailScreen(
          networkId: network.id,
          networkName: network.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Cashback settings',
            description:
                'Pick an affiliate network to manage its global policy and '
                'store/category overrides.',
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
        return const EmptyView(message: 'No affiliate networks yet.');
      case ViewState.success:
        return _buildTable();
    }
  }

  Widget _buildTable() {
    return AdminTableCard(
      child: DataTable(
        columns: const [
          DataColumn(label: Text('Name')),
          DataColumn(label: Text('Code')),
          DataColumn(label: Text('Status')),
          DataColumn(label: Text('')),
        ],
        rows: _networks
            .map(
              (network) => DataRow(
                onSelectChanged: (_) => _openNetwork(network),
                cells: [
                  DataCell(Text(network.name)),
                  DataCell(Text(network.code)),
                  DataCell(StatusBadge.active(network.isActive)),
                  DataCell(
                    TextButton(
                      onPressed: () => _openNetwork(network),
                      child: const Text('Manage'),
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
