import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/auth/admin_session.dart';
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
import '../../withdrawals/screens/withdrawal_input_dialog.dart';
import '../cashback_queues.dart';
import '../cashback_status_copy.dart';
import '../models/admin_cashback.dart';
import '../services/admin_cashback_api_service.dart';
import '../widgets/cashback_card.dart';
import 'cashback_detail_dialog.dart';

class CashbackReviewScreen extends StatefulWidget {
  const CashbackReviewScreen({
    super.key,
    this.initialStatus,
    this.service,
    this.isSuperAdmin,
  });

  /// Set when navigated here from a dashboard card. A decided status opens
  /// History on that status; Pending and Awaiting review show every cashback
  /// with that raw status, across the queues.
  final String? initialStatus;

  /// For tests. When null the screen creates, and later disposes, its own.
  final AdminCashbackApiService? service;

  /// For tests. When null it is read from the signed-in admin's role.
  final bool? isSuperAdmin;

  @override
  State<CashbackReviewScreen> createState() => _CashbackReviewScreenState();
}

class _CashbackReviewScreenState extends State<CashbackReviewScreen> {
  static const _searchDelay = Duration(milliseconds: 350);

  late final AdminCashbackApiService _service =
      widget.service ?? AdminCashbackApiService();

  /// Only a SuperAdmin may approve against the network's status.
  bool get _isSuperAdmin =>
      widget.isSuperAdmin ??
      AdminSession.instance.claims.value?.isSuperAdmin ??
      false;

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  AdminCashbackPage? _page;
  AdminCashbackSummary? _summary;
  int _pageNumber = 1;

  /// The queue tab. Null while a raw status from the dashboard is showing.
  CashbackQueue? _queue = CashbackQueue.readyToApprove;

  /// A raw status shown across the queues (dashboard deep link).
  String? _rawStatus;

  /// The status chip inside History. Null is "All".
  String? _historyStatus;
  late final List<String> _historyChips;

  bool _overdueOnly = false;
  String _search = '';
  DateTimeRange? _range;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;

  /// Ids currently mid-action, so their card shows a spinner instead of the
  /// whole screen reloading.
  final Set<String> _busyIds = {};

  @override
  void initState() {
    super.initState();
    _historyChips = [...kHistoryStatuses];

    final initial = widget.initialStatus;
    if (initial == 'Pending' || initial == 'AwaitingAdminReview') {
      _queue = null;
      _rawStatus = initial;
    } else if (initial != null && initial.isNotEmpty) {
      _queue = CashbackQueue.history;
      _historyStatus = initial;
      if (!_historyChips.contains(initial)) _historyChips.add(initial);
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

  String? get _effectiveStatus =>
      _rawStatus ?? (_queue == CashbackQueue.history ? _historyStatus : null);

  bool get _hasFilters =>
      _overdueOnly ||
      _search.isNotEmpty ||
      _range != null ||
      _rawStatus != null;

  Future<void> _load() async {
    final token = ++_loadToken;
    setState(() => _state = ViewState.loading);

    try {
      final range = _range;
      final page = await _service.list(
        status: _effectiveStatus,
        queue: _queue?.apiName,
        overdue: _overdueOnly,
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
    }
  }

  /// The numbers above the list. If they fail the page still works, the
  /// tiles just read "—".
  Future<void> _loadSummary() async {
    try {
      final summary = await _service.summary();
      if (!mounted) return;
      setState(() => _summary = summary);
    } on ApiException {
      // Leave the last numbers (or the dashes) in place.
    }
  }

  void _reloadAll() {
    _load();
    _loadSummary();
  }

  void _filtersChanged() {
    setState(() => _pageNumber = 1);
    _load();
  }

  void _selectQueue(CashbackQueue queue) {
    setState(() {
      _queue = queue;
      _rawStatus = null;
      _historyStatus = null;
    });
    _filtersChanged();
  }

  void _selectHistoryStatus(String? status) {
    setState(() => _historyStatus = status);
    _filtersChanged();
  }

  void _clearRawStatus() {
    setState(() {
      _rawStatus = null;
      _queue = CashbackQueue.readyToApprove;
    });
    _filtersChanged();
  }

  void _toggleOverdue() {
    setState(() => _overdueOnly = !_overdueOnly);
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
      helpText: 'Cashbacks created between',
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
      _overdueOnly = false;
      if (_rawStatus != null) {
        _rawStatus = null;
        _queue = CashbackQueue.readyToApprove;
      }
    });
    _filtersChanged();
  }

  void _changePage(int delta) {
    setState(() => _pageNumber = (_pageNumber + delta).clamp(1, 1 << 30));
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

  /// SuperAdmin only: approve although the network has not validated the
  /// sale. Asks for a reason, which is recorded in the audit trail.
  Future<void> _approveAnyway(AdminCashback cashback) => _decideWithReason(
    cashback,
    title: 'Approve anyway',
    confirmLabel: 'Approve anyway',
    message:
        'The network says this sale is "${cashback.networkStatus}", not '
        'validated. Approving moves ₹${cashback.cashbackAmount.toStringAsFixed(2)} '
        'to ${cashback.userEmail}\'s available balance, and it may have to '
        'be taken back. Say why you are overriding.',
    emptyError: 'A reason is required to approve against the network.',
    action: (reason) =>
        _service.approve(cashback.id, reason: reason, override: true),
    successMessage: 'Cashback approved with an override.',
  );

  Future<void> _reject(AdminCashback cashback) => _decideWithReason(
    cashback,
    title: 'Reject cashback',
    confirmLabel: 'Reject',
    message:
        'Reject ₹${cashback.cashbackAmount.toStringAsFixed(2)} for '
        '${cashback.userEmail}? This removes it from their pending balance. '
        'Say why; the reason is kept with your name.',
    hint: 'For example: the order was returned',
    emptyError: 'A reason is required to reject a cashback.',
    action: (reason) => _service.reject(cashback.id, reason),
    successMessage: 'Cashback rejected.',
  );

  Future<void> _reverse(AdminCashback cashback) => _decideWithReason(
    cashback,
    title: 'Reverse cashback',
    confirmLabel: 'Reverse',
    message:
        'Reverse ₹${cashback.cashbackAmount.toStringAsFixed(2)} already '
        'confirmed for ${cashback.userEmail}? This debits their available '
        'balance and fails if they already withdrew it. Say why; the reason '
        'is kept with your name.',
    hint: 'For example: the network reversed the sale',
    emptyError: 'A reason is required to reverse a cashback.',
    action: (reason) => _service.reverse(cashback.id, reason),
    successMessage: 'Cashback reversed.',
  );

  /// A decision that needs a written reason: asks for it in a dialog, sends
  /// it, and reloads. The confirm button reads [confirmLabel].
  Future<void> _decideWithReason(
    AdminCashback cashback, {
    required String title,
    required String message,
    required String confirmLabel,
    required String emptyError,
    required Future<CashbackDecision> Function(String reason) action,
    required String successMessage,
    String? hint,
  }) async {
    // Mark busy synchronously, before any await, so a second click (or a
    // second dialog) for the same row can never start another decision.
    if (!_busyIds.add(cashback.id)) return;
    setState(() {});

    try {
      final reason = await showWithdrawalInputDialog(
        context,
        title: title,
        message: message,
        label: 'Reason',
        hint: hint,
        confirmLabel: confirmLabel,
        emptyError: emptyError,
        multiline: true,
        danger: true,
      );
      if (reason == null || !mounted) return;

      await action(reason);
      if (!mounted) return;
      showSuccessSnackBar(context, successMessage);
      _reloadAll();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } finally {
      if (mounted) setState(() => _busyIds.remove(cashback.id));
    }
  }

  Future<void> _decide(
    AdminCashback cashback, {
    required Future<CashbackDecision> Function(String) action,
    required String confirmTitle,
    required String confirmMessage,
    required String successMessage,
    bool danger = false,
  }) async {
    // Mark busy synchronously, before any await, so a second click (or a
    // second dialog) for the same row can never start another decision.
    if (!_busyIds.add(cashback.id)) return;
    setState(() {});

    try {
      final confirmed = await showConfirmDialog(
        context,
        title: confirmTitle,
        message: confirmMessage,
        confirmLabel: confirmTitle.split(' ').first,
        danger: danger,
      );
      if (!confirmed || !mounted) return;

      await action(cashback.id);
      if (!mounted) return;
      showSuccessSnackBar(context, successMessage);
      _reloadAll();
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } finally {
      if (mounted) setState(() => _busyIds.remove(cashback.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AdminPageHeader(
                  title: 'Cashback review',
                  description:
                      'Decide on cashback, sorted by what the network has said.',
                ),
                const SizedBox(height: AdminSpacing.lg),
                _buildSummary(),
                const SizedBox(height: AdminSpacing.lg),
                _buildTabs(),
                if (_queue == CashbackQueue.history) ...[
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

  // ---- summary strip -------------------------------------------------------

  Widget _buildSummary() {
    final summary = _summary;
    String count(int Function(AdminCashbackSummary) pick) =>
        summary == null ? '—' : '${pick(summary)}';

    return AdminSummaryStrip(
      tiles: [
        AdminSummaryTile(
          key: const ValueKey('summary-needs-decision'),
          label: 'Needs a decision',
          value: count((s) => s.needsDecision),
          hint: 'Ready to approve, reversals and network rejected',
          color: AdminColors.warning,
        ),
        AdminSummaryTile(
          key: const ValueKey('summary-waiting'),
          label: 'Waiting on network',
          value: count((s) => s.waitingOnNetwork),
          hint: 'Nothing to do until the network answers',
          color: AdminColors.statusBlue,
        ),
        AdminSummaryTile(
          key: const ValueKey('summary-overdue'),
          label: 'Overdue',
          value: count((s) => s.overdue),
          hint: 'Past the expected confirmation date and still undecided',
          color: AdminColors.danger,
        ),
        AdminSummaryTile(
          key: const ValueKey('summary-exposure'),
          label: 'Confirmed, not paid by network',
          value: summary == null
              ? '—'
              : formatRupeesGrouped(summary.exposureAmount),
          hint: 'Money users can withdraw that the network has not paid us yet',
          color: AdminColors.primary,
        ),
      ],
    );
  }

  // ---- queue tabs ----------------------------------------------------------

  Widget _buildTabs() {
    return AdminQueueTabBar(
      tabs: [
        for (final queue in CashbackQueue.values)
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
          label: 'All decided',
          activeColor: AdminColors.primary,
          onTap: () => _selectHistoryStatus(null),
        ),
        for (final status in _historyChips)
          AdminFilterChip(
            key: ValueKey('history-chip-$status'),
            selected: _historyStatus == status,
            label: CashbackStatusCopy.forStatus(status).label,
            activeColor: CashbackStatusCopy.forStatus(status).color,
            onTap: () => _selectHistoryStatus(status),
          ),
      ],
    );
  }

  // ---- search, dates, overdue ---------------------------------------------

  Widget _buildFilterBar() {
    final overdueCount = _summary?.overdue;

    return Wrap(
      spacing: AdminSpacing.sm,
      runSpacing: AdminSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxWidth: 340),
          child: _buildSearchField(),
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
          key: const ValueKey('overdue-chip'),
          selected: _overdueOnly,
          label: overdueCount == null ? 'Overdue' : 'Overdue ($overdueCount)',
          activeColor: AdminColors.danger,
          onTap: _toggleOverdue,
        ),
        if (_rawStatus != null)
          AdminFilterChip(
            key: const ValueKey('raw-status-chip'),
            selected: true,
            label: '${CashbackStatusCopy.forStatus(_rawStatus!).label}  ×',
            activeColor: CashbackStatusCopy.forStatus(_rawStatus!).color,
            onTap: _clearRawStatus,
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

  Widget _buildSearchField() {
    return AdminSearchField(
      fieldKey: const ValueKey('cashback-search'),
      clearKey: const ValueKey('clear-search'),
      controller: _searchController,
      hintText: 'Search user, email, store or amount',
      onChanged: _onSearchChanged,
      onSubmitted: _applySearch,
      onClear: _clearSearch,
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
              child: LoadingView(message: 'Loading cashbacks...'),
            ),
          ),
        ];
      case ViewState.error:
        return [
          SliverToBoxAdapter(
            child: SizedBox(
              height: 240,
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
              final cashback = page.items[index];
              return CashbackCard(
                key: ValueKey(cashback.id),
                cashback: cashback,
                busy: _busyIds.contains(cashback.id),
                isSuperAdmin: _isSuperAdmin,
                showQueue: _queue == null,
                onApprove: () => _approve(cashback),
                onApproveAnyway: () => _approveAnyway(cashback),
                onReject: () => _reject(cashback),
                onReverse: () => _reverse(cashback),
                onOpen: () => showCashbackDetailDialog(
                  context,
                  cashback: cashback,
                  service: _service,
                ),
              );
            },
          ),
          SliverToBoxAdapter(child: _buildPager(page)),
        ];
    }
  }

  String _emptyMessage() {
    if (_hasFilters) return 'No cashbacks match these filters.';
    return _queue?.emptyMessage ?? 'No cashbacks with this status.';
  }

  Widget _buildPager(AdminCashbackPage page) {
    final totalPages = (page.totalCount / page.pageSize).ceil().clamp(
      1,
      999999,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              '${page.totalCount} total · page ${page.page} of $totalPages',
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
          ),
          IconButton(
            onPressed: page.hasNextPage ? () => _changePage(1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
