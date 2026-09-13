import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_search_status_bar.dart';
import '../../../core/widgets/admin_sticky_table.dart';
import '../../../core/widgets/empty_view.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state.dart';
import '../models/admin_user_lookup.dart';
import '../services/admin_user_api_service.dart';
import 'user_detail_screen.dart';

/// SuperAdmin-only screen: a paginated list of every registered user. Tap a
/// row to drill into their profile, cashback summary, and admin actions.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _service = AdminUserApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  AdminUserPage? _page;
  int _pageNumber = 1;

  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _search = '';

  /// null = no status toggle applied, true = "Active" chip selected, false =
  /// "Inactive" chip selected. ANDed with [_search] server-side, so toggling
  /// a status narrows whatever the search box already matches.
  bool? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _service.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);

    try {
      final page = await _service.listUsers(
        page: _pageNumber,
        search: _search.isEmpty ? null : _search,
        isActive: _statusFilter,
      );
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

  void _changePage(int delta) {
    setState(() => _pageNumber += delta);
    _load();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      final trimmed = value.trim();
      if (trimmed == _search) return;
      setState(() {
        _search = trimmed;
        _pageNumber = 1;
      });
      _load();
    });
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    if (_search.isEmpty) return;
    setState(() {
      _search = '';
      _pageNumber = 1;
    });
    _load();
  }

  /// Tapping a selected chip clears the filter back to "all"; tapping the
  /// other chip switches straight over.
  void _toggleStatusFilter(bool value) {
    setState(() {
      _statusFilter = _statusFilter == value ? null : value;
      _pageNumber = 1;
    });
    _load();
  }

  Future<void> _openDetail(AdminUserListItem user) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserDetailScreen(userId: user.userId)),
    );
    // The detail screen may have changed role/active status — refresh.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return AdminPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Users',
            description: 'All registered users.',
          ),
          const SizedBox(height: AdminSpacing.lg),
          AdminSearchStatusBar(
            controller: _searchController,
            onChanged: _onSearchChanged,
            onClear: _clearSearch,
            statusFilter: _statusFilter,
            onStatusToggle: _toggleStatusFilter,
          ),
          const SizedBox(height: AdminSpacing.md),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case ViewState.initial:
      case ViewState.loading:
        return const LoadingView(message: 'Loading users...');
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _load);
      case ViewState.empty:
        return EmptyView(
          icon: _search.isEmpty ? Icons.inbox_outlined : Icons.search_off_rounded,
          message: _emptyMessage(),
        );
      case ViewState.success:
        return _buildTable();
    }
  }

  String _emptyMessage() {
    final statusWord = switch (_statusFilter) {
      true => 'active ',
      false => 'inactive ',
      null => '',
    };

    if (_search.isEmpty) return 'No ${statusWord}users found.';
    return 'No ${statusWord}users match "$_search".';
  }

  Widget _buildTable() {
    final page = _page!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AdminStickyTable(
            columns: const ['Username', 'Email', 'Member since', 'Status'],
            columnWidths: const [160, 240, 130, 110],
            columnAlignments: const [
              Alignment.centerLeft,
              Alignment.centerLeft,
              Alignment.centerLeft,
              Alignment.center,
            ],
            itemCount: page.items.length,
            onRowTap: (index) => _openDetail(page.items[index]),
            cellsBuilder: (context, index) {
              final user = page.items[index];

              return [
                Text(
                  user.fullName.isEmpty ? user.email : user.fullName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(user.email),
                Text(_formatDate(user.createdAt)),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StatusBadge.active(user.isActive),
                ),
              ];
            },
          ),
        ),
        const SizedBox(height: AdminSpacing.md),
        _buildPager(page),
      ],
    );
  }

  Widget _buildPager(AdminUserPage page) {
    final totalPages = (page.totalCount / page.pageSize).ceil().clamp(
      1,
      999999,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '${page.totalCount} total · page ${page.page} of $totalPages',
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
        ),
        const SizedBox(width: AdminSpacing.sm),
        _pagerButton(
          icon: Icons.chevron_left,
          onPressed: page.page > 1 ? () => _changePage(-1) : null,
        ),
        const SizedBox(width: 4),
        _pagerButton(
          icon: Icons.chevron_right,
          onPressed: page.hasNextPage ? () => _changePage(1) : null,
        ),
      ],
    );
  }

  Widget _pagerButton({required IconData icon, required VoidCallback? onPressed}) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      splashRadius: 18,
    );
  }

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatDate(DateTime date) {
    return '${date.day} ${_months[date.month - 1]} ${date.year}';
  }
}
