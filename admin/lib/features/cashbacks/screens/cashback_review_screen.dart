import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state.dart';
import '../cashback_status_copy.dart';
import '../models/admin_cashback.dart';
import '../services/admin_cashback_api_service.dart';

class CashbackReviewScreen extends StatefulWidget {
  const CashbackReviewScreen({super.key, this.initialStatus});

  /// Set when navigated here from a dashboard card, to pre-select the filter.
  final String? initialStatus;

  @override
  State<CashbackReviewScreen> createState() => _CashbackReviewScreenState();
}

class _CashbackReviewScreenState extends State<CashbackReviewScreen> {
  final _service = AdminCashbackApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  AdminCashbackPage? _page;
  late String _statusFilter = widget.initialStatus ?? 'AwaitingAdminReview';
  int _pageNumber = 1;

  /// Ids currently mid-action, so their row shows a spinner instead of the
  /// whole screen reloading.
  final Set<String> _busyIds = {};

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
      final page = await _service.list(status: _statusFilter, page: _pageNumber);
      setState(() {
        _page = page;
        _state = page.items.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  void _changeFilter(String status) {
    setState(() {
      _statusFilter = status;
      _pageNumber = 1;
    });
    _load();
  }

  void _changePage(int delta) {
    setState(() => _pageNumber += delta);
    _load();
  }

  Future<void> _approve(AdminCashback cashback) => _decide(
    cashback,
    action: _service.approve,
    confirmTitle: 'Approve cashback',
    confirmMessage:
        'Approve ₹${cashback.cashbackAmount.toStringAsFixed(2)} for '
        '${cashback.userEmail}? This moves the amount to their available balance.',
    successMessage: 'Cashback approved.',
  );

  Future<void> _reject(AdminCashback cashback) => _decide(
    cashback,
    action: _service.reject,
    confirmTitle: 'Reject cashback',
    confirmMessage:
        'Reject ₹${cashback.cashbackAmount.toStringAsFixed(2)} for '
        '${cashback.userEmail}? This removes it from their pending balance.',
    successMessage: 'Cashback rejected.',
    danger: true,
  );

  Future<void> _reverse(AdminCashback cashback) => _decide(
    cashback,
    action: _service.reverse,
    confirmTitle: 'Reverse cashback',
    confirmMessage:
        'Reverse ₹${cashback.cashbackAmount.toStringAsFixed(2)} already '
        'confirmed for ${cashback.userEmail}? This debits their available '
        'balance and fails if they already withdrew it.',
    successMessage: 'Cashback reversed.',
    danger: true,
  );

  Future<void> _decide(
    AdminCashback cashback, {
    required Future<CashbackDecision> Function(String) action,
    required String confirmTitle,
    required String confirmMessage,
    required String successMessage,
    bool danger = false,
  }) async {
    final confirmed = await showConfirmDialog(
      context,
      title: confirmTitle,
      message: confirmMessage,
      confirmLabel: confirmTitle.split(' ').first,
      danger: danger,
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyIds.add(cashback.id));

    try {
      await action(cashback.id);
      if (!mounted) return;
      showSuccessSnackBar(context, successMessage);
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } finally {
      if (mounted) setState(() => _busyIds.remove(cashback.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AdminSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cashback review',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AdminColors.textPrimary,
            ),
          ),
          const SizedBox(height: AdminSpacing.lg),
          _buildFilterBar(),
          const SizedBox(height: AdminSpacing.lg),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    return Wrap(
      spacing: AdminSpacing.sm,
      children: [
        for (final status in kCashbackStatusFilters)
          ChoiceChip(
            label: Text(CashbackStatusCopy.forStatus(status).label),
            selected: _statusFilter == status,
            onSelected: (_) => _changeFilter(status),
          ),
      ],
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading cashbacks...');
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _load);
      case ViewState.empty:
        return const EmptyView(message: 'No cashbacks with this status.');
      case ViewState.success:
        return _buildTable();
    }
  }

  Widget _buildTable() {
    final page = _page!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('User')),
                  DataColumn(label: Text('Store')),
                  DataColumn(label: Text('Amount')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Network status')),
                  DataColumn(label: Text('Created')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: page.items.map(_buildRow).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(height: AdminSpacing.md),
        _buildPager(page),
      ],
    );
  }

  DataRow _buildRow(AdminCashback cashback) {
    final busy = _busyIds.contains(cashback.id);
    final statusCopy = CashbackStatusCopy.forStatus(cashback.status);

    return DataRow(
      cells: [
        DataCell(Text(cashback.userEmail)),
        DataCell(Text(cashback.storeName ?? '—')),
        DataCell(Text('₹${cashback.cashbackAmount.toStringAsFixed(2)}')),
        DataCell(StatusBadge(label: statusCopy.label, color: statusCopy.color)),
        DataCell(Text(cashback.networkStatus)),
        DataCell(Text(_formatDate(cashback.createdAt))),
        DataCell(busy ? const _RowSpinner() : _buildActions(cashback)),
      ],
    );
  }

  Widget _buildActions(AdminCashback cashback) {
    final canDecide =
        cashback.status == 'Pending' || cashback.status == 'AwaitingAdminReview';

    if (!canDecide) {
      return const Text('—', style: TextStyle(color: AdminColors.textMuted));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          onPressed: () => _approve(cashback),
          child: const Text('Approve'),
        ),
        if (cashback.wasPreviouslyConfirmed)
          TextButton(
            onPressed: () => _reverse(cashback),
            style: TextButton.styleFrom(foregroundColor: AdminColors.danger),
            child: const Text('Reverse'),
          )
        else
          TextButton(
            onPressed: () => _reject(cashback),
            style: TextButton.styleFrom(foregroundColor: AdminColors.danger),
            child: const Text('Reject'),
          ),
      ],
    );
  }

  Widget _buildPager(AdminCashbackPage page) {
    final totalPages = (page.totalCount / page.pageSize).ceil().clamp(1, 999999);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${page.totalCount} total · page ${page.page} of $totalPages',
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: AdminSpacing.md),
        IconButton(
          onPressed: page.page > 1 ? () => _changePage(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          onPressed: page.hasNextPage ? () => _changePage(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

class _RowSpinner extends StatelessWidget {
  const _RowSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
