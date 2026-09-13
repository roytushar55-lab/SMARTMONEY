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
      final page = await _service.listUsers(page: _pageNumber);
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
        return const EmptyView(message: 'No users found.');
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
          child: AdminTableCard(
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Username')),
                DataColumn(label: Text('Email')),
                DataColumn(label: Text('Member since')),
                DataColumn(label: Text('Status')),
              ],
              rows: page.items.map(_buildRow).toList(),
            ),
          ),
        ),
        const SizedBox(height: AdminSpacing.md),
        _buildPager(page),
      ],
    );
  }

  DataRow _buildRow(AdminUserListItem user) {
    return DataRow(
      onSelectChanged: (_) => _openDetail(user),
      cells: [
        DataCell(
          Text(
            user.fullName.isEmpty ? user.email : user.fullName,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(user.email)),
        DataCell(Text(_formatDate(user.createdAt))),
        DataCell(StatusBadge.active(user.isActive)),
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
