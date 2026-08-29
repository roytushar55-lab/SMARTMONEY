import 'package:flutter/material.dart';

import '../../../../app/routes/route_names.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/widgets/empty_view.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/login_demo_widgets.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../core/widgets/view_state.dart';
import '../../data/models/store_list_item.dart';
import '../../data/services/browsing_api_service.dart';
import '../widgets/store_card.dart';

/// Lists all stores from `GET /api/stores`. Tapping a store opens store details.
class StoresScreen extends StatefulWidget {
  const StoresScreen({super.key});

  @override
  State<StoresScreen> createState() => _StoresScreenState();
}

class _StoresScreenState extends State<StoresScreen> {
  final BrowsingApiService _service = BrowsingApiService();

  ViewState _state = ViewState.initial;
  List<StoreListItem> _stores = const [];
  String _error = '';
  bool _isLoading = false;

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
    if (_isLoading) return;
    _isLoading = true;

    setState(() => _state = ViewState.loading);

    try {
      final stores = await _service.getStores();
      if (!mounted) return;
      setState(() {
        _stores = stores;
        _state = stores.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _state = ViewState.error;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong. Please try again.';
        _state = ViewState.error;
      });
    } finally {
      _isLoading = false;
    }
  }

  void _openStore(StoreListItem store) {
    Navigator.pushNamed(
      context,
      RouteNames.storeDetails,
      arguments: store.slug,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stores')),
      body: LoginDemoBackground(
        child: SafeArea(top: false, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading stores...');
      case ViewState.error:
        return ErrorView(message: _error, onRetry: _load);
      case ViewState.empty:
        return EmptyView(
          title: 'No stores yet',
          message: 'Stores will appear here once they are available.',
          icon: Icons.storefront_outlined,
          onRetry: _load,
        );
      case ViewState.success:
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            itemCount: _stores.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final store = _stores[index];
              return StoreCard(store: store, onTap: () => _openStore(store));
            },
          ),
        );
    }
  }
}
