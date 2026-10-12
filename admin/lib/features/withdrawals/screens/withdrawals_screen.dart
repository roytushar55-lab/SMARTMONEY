import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/formatting/money_and_dates.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_queue_tab.dart';
import '../../../core/widgets/admin_search_field.dart';
import '../../../core/widgets/admin_search_status_bar.dart';
import '../../../core/widgets/admin_summary_tile.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/view_state.dart';
import '../models/admin_withdrawal.dart';
import '../services/admin_withdrawal_api_service.dart';
import '../widgets/withdrawal_card.dart';
import '../withdrawal_formatters.dart';
import '../withdrawal_queues.dart';
import '../withdrawal_status_copy.dart';
import '../withdrawals_filter.dart';
import 'withdrawal_detail_dialog.dart';
import 'withdrawal_input_dialog.dart';

/// The withdrawals page: the numbers on top, a tab for each stage of the work
/// (to decide, to pay, in progress, history), search and dates, and a card for
/// each withdrawal. A card opens the withdrawal in full; a Requested one can be
/// approved or declined right on the card. The page reloads after any change.
class WithdrawalsScreen extends StatefulWidget {
  const WithdrawalsScreen({
    super.key,
    this.service,
    this.initialFilter = WithdrawalsFilter.requested,
    this.onChanged,
  });

  /// For tests. When null the screen creates, and later disposes, its own.
  final AdminWithdrawalApiService? service;

  /// What the page opens on; the dashboard and the sidebar link with these.
  /// A status opens its tab (a settled one opens History on that status);
  /// "needs attention" with no status shows every flagged withdrawal across
  /// the tabs.
  final WithdrawalsFilter initialFilter;

  /// Called after an action changed a withdrawal, so the shell can refresh
  /// its needs-attention badge.
  final VoidCallback? onChanged;

  @override
  State<WithdrawalsScreen> createState() => _WithdrawalsScreenState();
}

class _WithdrawalsScreenState extends State<WithdrawalsScreen> {
  static const _searchDelay = Duration(milliseconds: 350);

  late final AdminWithdrawalApiService _service =
      widget.service ?? AdminWithdrawalApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  AdminWithdrawalPage? _page;
  AdminWithdrawalSummary? _summary;
  int _pageNumber = 1;

  /// The tab. Null while every flagged withdrawal is shown across the tabs
  /// (the dashboard's "needs attention" link).
  WithdrawalQueue? _queue = WithdrawalQueue.toDecide;

  /// The status chip inside History. Null is "All settled".
  String? _historyStatus;

  bool _attentionOnly = false;
  String _search = '';
  DateTimeRange? _range;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  /// Ids currently mid-action, so their card shows a spinner instead of the
  /// whole page reloading.
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();

    final filter = widget.initialFilter;
    final status = filter.status;
    _attentionOnly = filter.needsAttentionOnly;

    if (status != null) {
      _queue = WithdrawalQueue.forStatus(status);
      if (_queue == WithdrawalQueue.history) _historyStatus = status;
    } else if (filter.needsAttentionOnly) {
      _queue = null;
    }

    _load();
    _loadSummary();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    if (widget.service == null) _service.dispose();
    super.dispose();
  }

  /// Monotonic token so a slow earlier response can't overwrite a later one.
  int _loadToken = 0;

  bool get _hasFilters =>
      _attentionOnly || _search.isNotEmpty || _range != null;

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() => _state = ViewState.loading);

    try {
      final range = _range;
      final page = await _service.list(
        queue: _queue?.apiName,
        status: _queue == WithdrawalQueue.history ? _historyStatus : null,
        needsAttentionOnly: _attentionOnly,
        search: _search,
        // The picked days are local: from the start of the first day up to
        // (not including) the start of the day after the last.
        from: range == null
            ? null
            : DateTime(range.start.year, range.start.month, range.start.day),
        to: range == null
            ? null
            : DateTime(range.end.year, range.end.month, range.end.day + 1),
        page: _pageNumber,
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _page = page;
        _state = page.items.isEmpty ? ViewState.empty : ViewState.success;
      });
    } on ApiException catch (error) {
      if (!mounted || token != _loadToken) return;
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    } catch (_) {
      // An unexpected payload must end the spinner, not leave it spinning.
      if (!mounted || token != _loadToken) return;
      setState(() {
        _errorMessage = 'Could not load withdrawals. Please try again.';
        _state = ViewState.error;
      });
    }
  }

  /// The numbers above the list. If they fail the page still works, the
  /// tiles just read "—".
  Future<void> _loadSummary() async {
    try {
      final summary = await _service.summary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } catch (_) {
      // Leave the last numbers (or the dashes) in place.
    }
  }

  void _reloadAll() {
    _load();
    _loadSummary();
  }

  /// Something changed a withdrawal: reload, and tell the shell.
  void _changed() {
    widget.onChanged?.call();
    if (mounted) _reloadAll();
  }

  void _filtersChanged() {
    setState(() => _pageNumber = 1);
    _load();
  }

  void _selectQueue(WithdrawalQueue queue) {
    setState(() {
      _queue = queue;
      _historyStatus = null;
    });
    _filtersChanged();
  }

  void _selectHistoryStatus(String? status) {
    setState(() => _historyStatus = status);
    _filtersChanged();
  }

  void _toggleAttention() {
    setState(() {
      _attentionOnly = !_attentionOnly;
      // Showing every flagged one across the tabs only makes sense while the
      // chip is on.
      if (!_attentionOnly && _queue == null) _queue = WithdrawalQueue.toDecide;
    });
    _filtersChanged();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(_searchDelay, () => _applySearch(value));
  }

  void _applySearch(String value) {
    _searchTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed == _search) return;
    setState(() => _search = trimmed);
    _filtersChanged();
  }

  void _clearSearch() {
    _searchController.clear();
    _applySearch('');
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
      helpText: 'Requested between',
    );
    if (picked == null || !mounted) return;
    setState(() => _range = picked);
    _filtersChanged();
  }

  void _clearFilters() {
    _searchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _search = '';
      _range = null;
      _attentionOnly = false;
      _queue ??= WithdrawalQueue.toDecide;
    });
    _filtersChanged();
  }

  void _changePage(int delta) {
    setState(() => _pageNumber = (_pageNumber + delta).clamp(1, 1 << 30));
    _load();
  }

  void _open(AdminWithdrawal withdrawal) {
    showWithdrawalDetailDialog(
      context,
      withdrawalId: withdrawal.id,
      service: _service,
      // An action changed it: refresh the page behind the dialog.
      onChanged: _changed,
    );
  }

  // ---- decisions on a card -------------------------------------------------

  Future<void> _approve(AdminWithdrawal withdrawal) => _decide(
    withdrawal,
    ask: () async {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Approve withdrawal',
        message:
            'Approve ${formatRupees(withdrawal.netAmount)} for '
            '${withdrawal.userEmail}? If payouts are automatic it is sent to '
            'the payment provider now. Otherwise you pay it yourself, then '
            'open it and use Mark paid.',
        confirmLabel: 'Approve',
      );
      return confirmed ? '' : null;
    },
    send: (_) async {
      final decision = await _service.approve(withdrawal.id);

      switch (decision.status) {
        case 'Completed':
          return 'Approved, and the payment provider has already paid it.';
        case 'Processing':
          return 'Approved and sent to the payment provider.';
        case 'Failed':
          return 'Approved, but the payment provider refused it. The money '
              'went back to the user.';
        default:
          return 'Approved. Pay it, then open it and use Mark paid.';
      }
    },
  );

  Future<void> _decline(AdminWithdrawal withdrawal) => _decide(
    withdrawal,
    ask: () => showWithdrawalInputDialog(
      context,
      title: 'Decline withdrawal',
      message:
          '${formatRupees(withdrawal.amount)} goes back to the user\'s '
          'available balance, and they see your reason.',
      label: 'Reason (shown to the user)',
      confirmLabel: 'Decline',
      emptyError: 'Enter a reason.',
      multiline: true,
      danger: true,
    ),
    send: (reason) async {
      await _service.reject(withdrawal.id, reason: reason);
      return 'Declined. The money went back to the user.';
    },
  );

  /// Asks, sends, and reloads. [ask] returns what to send, or null if the
  /// admin cancelled. A refusal (400, 401, 403) means nothing happened; any
  /// other error leaves us unsure, so the page looks again.
  Future<void> _decide(
    AdminWithdrawal withdrawal, {
    required Future<String?> Function() ask,
    required Future<String> Function(String input) send,
  }) async {
    // Mark busy synchronously, before any await, so a second tap (or a second
    // dialog) for the same card can never start another action.
    if (!_busyIds.add(withdrawal.id)) return;
    setState(() {});

    var changed = false;

    try {
      final input = await ask();
      if (input == null || !mounted) return;

      final message = await send(input);
      changed = true;
      if (!mounted) return;
      showSuccessSnackBar(context, message);
    } on ApiException catch (error) {
      changed =
          !(error.statusCode == 400 ||
              error.isUnauthorized ||
              error.isForbidden);
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } catch (_) {
      // An unreadable reply: the action may well have gone through.
      changed = true;
      if (!mounted) return;
      showErrorSnackBar(context, 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busyIds.remove(withdrawal.id));
      if (changed) _changed();
    }
  }

  // ---- layout --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AdminPageHeader(
                  title: 'Withdrawals',
                  description:
                      'Decide on requests, pay them, and follow up on anything '
                      'that needs attention.',
                  action: OutlinedButton.icon(
                    onPressed: _state == ViewState.loading ? null : _reloadAll,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                  ),
                ),
                const SizedBox(height: AdminSpacing.lg),
                _buildSummary(),
                const SizedBox(height: AdminSpacing.lg),
                _buildTabs(),
                if (_queue == WithdrawalQueue.history) ...[
                  const SizedBox(height: AdminSpacing.sm),
                  _buildHistoryChips(),
                ],
                const SizedBox(height: AdminSpacing.md),
                _buildFilterBar(),
                const SizedBox(height: AdminSpacing.lg),
              ],
            ),
          ),
          ..._buildBody(),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final summary = _summary;
    String count(int Function(AdminWithdrawalSummary) pick) =>
        summary == null ? '—' : '${pick(summary)}';

    return AdminSummaryStrip(
      tiles: [
        AdminSummaryTile(
          key: const ValueKey('summary-to-decide'),
          label: 'To decide',
          value: count((s) => s.toDecide),
          detail: summary == null
              ? null
              : '${formatRupeesGrouped(summary.toDecideAmount)} requested',
          hint: 'Requested: waiting for you to approve or decline',
          color: AdminColors.warning,
        ),
        AdminSummaryTile(
          key: const ValueKey('summary-to-pay'),
          label: 'To pay',
          value: count((s) => s.toPay),
          detail: summary == null
              ? null
              : '${formatRupeesGrouped(summary.toPayAmount)} owed now',
          hint: 'Approved: cleared, and waiting for the payout',
          color: AdminColors.statusBlue,
        ),
        AdminSummaryTile(
          key: const ValueKey('summary-attention'),
          label: 'Needs attention',
          value: count((s) => s.needsAttention),
          hint: 'Something does not match our records, in any status',
          color: AdminColors.danger,
        ),
        AdminSummaryTile(
          key: const ValueKey('summary-paid'),
          label: 'Paid in the last 30 days',
          value: summary == null
              ? '—'
              : formatRupeesGrouped(summary.paidLast30DaysAmount),
          detail: summary == null
              ? null
              : '${summary.paidLast30Days} '
                    '${summary.paidLast30Days == 1 ? 'withdrawal' : 'withdrawals'}',
          hint: 'What users received',
          color: AdminColors.success,
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return AdminQueueTabBar(
      tabs: [
        for (final queue in WithdrawalQueue.values)
          AdminQueueTab(
            key: ValueKey('queue-tab-${queue.apiName}'),
            countKey: ValueKey('queue-count-${queue.apiName}'),
            label: queue.label,
            color: queue.color,
            count: _summary == null ? null : queue.count(_summary!),
            selected: _queue == queue,
            onTap: () => _selectQueue(queue),
          ),
      ],
    );
  }

  Widget _buildHistoryChips() {
    return Wrap(
      spacing: AdminSpacing.sm,
      runSpacing: AdminSpacing.sm,
      children: [
        AdminFilterChip(
          key: const ValueKey('history-chip-All'),
          selected: _historyStatus == null,
          label: 'All settled',
          activeColor: AdminColors.primary,
          onTap: () => _selectHistoryStatus(null),
        ),
        for (final status in kWithdrawalHistoryStatuses)
          AdminFilterChip(
            key: ValueKey('history-chip-$status'),
            selected: _historyStatus == status,
            label: WithdrawalStatusCopy.forStatus(status).label,
            activeColor: WithdrawalStatusCopy.forStatus(status).color,
            onTap: () => _selectHistoryStatus(status),
          ),
      ],
    );
  }

  Widget _buildFilterBar() {
    final attentionCount = _summary?.needsAttention;

    return Wrap(
      spacing: AdminSpacing.sm,
      runSpacing: AdminSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
          child: AdminSearchField(
            fieldKey: const ValueKey('withdrawal-search'),
            clearKey: const ValueKey('clear-search'),
            controller: _searchController,
            hintText: 'Search name, reference, UTR, amount',
            onChanged: _onSearchChanged,
            onSubmitted: _applySearch,
            onClear: _clearSearch,
          ),
        ),
        OutlinedButton.icon(
          key: const ValueKey('date-filter'),
          onPressed: _pickRange,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(
            _range == null ? 'Any date' : formatDateRangeLabel(_range!),
          ),
          style: OutlinedButton.styleFrom(
            foregroundColor: _range == null
                ? AdminColors.textSecondary
                : AdminColors.primary,
            side: BorderSide(
              color: _range == null ? AdminColors.border : AdminColors.primary,
            ),
            minimumSize: const Size(0, 42),
            shape: const StadiumBorder(),
          ),
        ),
        AdminFilterChip(
          key: const ValueKey('attention-chip'),
          selected: _attentionOnly,
          label: attentionCount == null
              ? 'Needs attention'
              : 'Needs attention ($attentionCount)',
          activeColor: AdminColors.warning,
          onTap: _toggleAttention,
        ),
        if (_hasFilters)
          TextButton(
            key: const ValueKey('clear-filters'),
            onPressed: _clearFilters,
            child: const Text('Clear filters'),
          ),
      ],
    );
  }

  // ---- the list ------------------------------------------------------------

  List<Widget> _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: LoadingView(message: 'Loading withdrawals...'),
            ),
          ),
        ];
      case ViewState.error:
        return [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 280,
              child: ErrorView(message: _errorMessage, onRetry: _reloadAll),
            ),
          ),
        ];
      case ViewState.empty:
        return [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
              child: EmptyView(message: _emptyMessage()),
            ),
          ),
        ];
      case ViewState.success:
        final page = _page!;
        return [
          SliverList.builder(
            itemCount: page.items.length,
            itemBuilder: (context, index) {
              final withdrawal = page.items[index];
              return WithdrawalCard(
                key: ValueKey(withdrawal.id),
                withdrawal: withdrawal,
                busy: _busyIds.contains(withdrawal.id),
                showQueue: _queue == null,
                onOpen: () => _open(withdrawal),
                onApprove: () => _approve(withdrawal),
                onDecline: () => _decline(withdrawal),
              );
            },
          ),
          SliverToBoxAdapter(child: _buildPager(page)),
        ];
    }
  }

  String _emptyMessage() {
    if (_hasFilters) {
      return _attentionOnly && _search.isEmpty && _range == null
          ? 'Nothing needs attention here.'
          : 'No withdrawals match these filters.';
    }
    return _queue?.emptyMessage ?? 'No withdrawals.';
  }

  Widget _buildPager(AdminWithdrawalPage page) {
    final totalPages = (page.totalCount / page.pageSize).ceil().clamp(
      1,
      999999,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Flexible so the arrows always fit, even on a phone-width window.
          Flexible(
            child: Text(
              '${page.totalCount} total · page ${page.page} of $totalPages',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AdminColors.textMuted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: AdminSpacing.md),
          IconButton(
            onPressed: page.page > 1 ? () => _changePage(-1) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: 'Previous page',
          ),
          IconButton(
            onPressed: page.hasNextPage ? () => _changePage(1) : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}
