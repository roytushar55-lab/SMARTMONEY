import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_stat_card.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/view_state.dart';
import '../../cashbacks/cashback_status_copy.dart';
import '../../cashbacks/services/admin_cashback_api_service.dart';

/// Landing screen: a count per cashback status. There's no dedicated
/// summary endpoint — each card asks the existing list endpoint for
/// `pageSize=1` and reads `totalCount`, which is cheap and avoids a new
/// backend route just for this.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenReviewQueue});

  /// Lets a card jump straight to the review queue pre-filtered to its status.
  final void Function(String status) onOpenReviewQueue;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _service = AdminCashbackApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  final Map<String, int> _counts = {};

  static const Map<String, IconData> _statusIcons = {
    'AwaitingAdminReview': Icons.hourglass_top_rounded,
    'Pending': Icons.schedule_rounded,
    'Confirmed': Icons.check_circle_outline_rounded,
    'Rejected': Icons.cancel_outlined,
    'Reversed': Icons.undo_rounded,
    'PaidOut': Icons.account_balance_wallet_outlined,
  };

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
      final pages = await Future.wait(
        kCashbackStatusFilters.map(
          (status) => _service.list(status: status, page: 1, pageSize: 1),
        ),
      );

      final counts = <String, int>{};
      for (var i = 0; i < kCashbackStatusFilters.length; i++) {
        counts[kCashbackStatusFilters[i]] = pages[i].totalCount;
      }

      setState(() {
        _counts
          ..clear()
          ..addAll(counts);
        _state = ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Dashboard',
            description:
                'Cashback pipeline at a glance — tap a card to review.',
          ),
          const SizedBox(height: AdminSpacing.xxl),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading counts...');
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _load);
      case ViewState.empty:
      case ViewState.success:
        return Wrap(
          spacing: AdminSpacing.lg,
          runSpacing: AdminSpacing.lg,
          children: kCashbackStatusFilters
              .map((status) => _buildCard(status, _counts[status] ?? 0))
              .toList(),
        );
    }
  }

  Widget _buildCard(String status, int count) {
    final copy = CashbackStatusCopy.forStatus(status);

    return AdminStatCard(
      icon: _statusIcons[status] ?? Icons.circle_outlined,
      value: '$count',
      label: copy.label,
      color: copy.color,
      onTap: () => widget.onOpenReviewQueue(status),
    );
  }
}
