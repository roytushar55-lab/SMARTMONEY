import 'package:flutter/material.dart';

import '../../../core/auth/admin_session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/admin_stat_card.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../core/widgets/view_state.dart';
import '../models/admin_user_lookup.dart';
import '../services/admin_user_api_service.dart';

/// SuperAdmin-only screen: one user's profile, lifetime cashback summary, and
/// the admin actions available on them (activate/deactivate, change role).
class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.userId});

  final String userId;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _service = AdminUserApiService();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  AdminUserDetail? _detail;
  bool _updatingStatus = false;
  bool _changingRole = false;

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
      final detail = await _service.getUserDetail(widget.userId);
      setState(() {
        _detail = detail;
        _state = ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  Future<void> _toggleActive() async {
    final user = _detail;
    if (user == null) return;

    final ownId = AdminSession.instance.claims.value?.userId;
    if (ownId == user.userId && user.isActive) {
      showErrorSnackBar(context, 'You cannot deactivate your own account.');
      return;
    }

    final activating = !user.isActive;
    final confirmed = await showConfirmDialog(
      context,
      title: activating ? 'Activate user' : 'Deactivate user',
      message:
          '${activating ? 'Activate' : 'Deactivate'} ${user.email}? '
          '${activating ? 'They will be able to sign in again.' : 'They will no longer be able to sign in.'}',
      confirmLabel: activating ? 'Activate' : 'Deactivate',
      danger: !activating,
    );
    if (!confirmed || !mounted) return;

    setState(() => _updatingStatus = true);

    try {
      final isActive = await _service.setActive(user.userId, activating);
      if (!mounted) return;
      setState(() => _detail = user.copyWith(isActive: isActive));
      showSuccessSnackBar(
        context,
        isActive ? 'User activated.' : 'User deactivated.',
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } finally {
      if (mounted) setState(() => _updatingStatus = false);
    }
  }

  Future<void> _changeRole(String newRole) async {
    final user = _detail;
    if (user == null) return;

    final ownId = AdminSession.instance.claims.value?.userId;
    if (ownId == user.userId) {
      showErrorSnackBar(context, 'You cannot change your own role.');
      return;
    }

    final confirmed = await showConfirmDialog(
      context,
      title: newRole == 'Admin' ? 'Grant admin access' : 'Revoke admin access',
      message:
          '${newRole == 'Admin' ? 'Grant' : 'Revoke'} admin access for '
          '${user.email}?',
      confirmLabel: newRole == 'Admin' ? 'Grant' : 'Revoke',
      danger: newRole != 'Admin',
    );
    if (!confirmed || !mounted) return;

    setState(() => _changingRole = true);

    try {
      await _service.changeRole(user.userId, newRole);
      if (!mounted) return;
      setState(() => _detail = user.copyWith(role: newRole));
      showSuccessSnackBar(context, 'Role updated to $newRole.');
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } finally {
      if (mounted) setState(() => _changingRole = false);
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
                tooltip: 'Back to users',
              ),
              const SizedBox(width: AdminSpacing.sm),
              const Expanded(
                child: AdminPageHeader(
                  title: 'User details',
                  description: 'Profile, cashback summary, and admin actions.',
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
        return const LoadingView(message: 'Loading user...');
      case ViewState.error:
        return ErrorView(message: _errorMessage, onRetry: _load);
      case ViewState.empty:
      case ViewState.success:
        return SingleChildScrollView(child: _buildContent(_detail!));
    }
  }

  Widget _buildContent(AdminUserDetail user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildProfileCard(user),
        const SizedBox(height: AdminSpacing.xl),
        Text(
          'Lifetime cashback',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: AdminSpacing.md),
        _buildStatGrid(user),
        const SizedBox(height: AdminSpacing.md),
        Text(
          'Lifetime withdrawn: ${_formatAmount(user.lifetimeWithdrawn)}',
          style: const TextStyle(
            color: AdminColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AdminSpacing.xl),
        Text('Admin actions', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AdminSpacing.md),
        _buildActions(user),
      ],
    );
  }

  Widget _buildProfileCard(AdminUserDetail user) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminRadius.card),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            user.fullName.isEmpty ? user.email : user.fullName,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(user.email, style: const TextStyle(color: AdminColors.textMuted)),
          const SizedBox(height: AdminSpacing.sm),
          Text(
            'Member since ${_formatDate(user.createdAt)}',
            style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AdminSpacing.md),
          Row(
            children: [
              StatusBadge(
                label: user.role,
                color: user.role == 'SuperAdmin'
                    ? AdminColors.primary
                    : user.role == 'Admin'
                    ? AdminColors.success
                    : AdminColors.textMuted,
              ),
              const SizedBox(width: AdminSpacing.sm),
              StatusBadge.active(user.isActive),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatGrid(AdminUserDetail user) {
    final summary = user.cashbackSummary;

    final tiles = [
      (
        icon: Icons.schedule_rounded,
        label: 'Pending',
        color: AdminColors.warning,
        stat: summary.pending,
      ),
      (
        icon: Icons.check_circle_outline_rounded,
        label: 'Approved',
        color: AdminColors.success,
        stat: summary.approved,
      ),
      (
        icon: Icons.cancel_outlined,
        label: 'Rejected',
        color: AdminColors.danger,
        stat: summary.rejected,
      ),
      (
        icon: Icons.undo_rounded,
        label: 'Reversed',
        color: AdminColors.textMuted,
        stat: summary.reversed,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < AdminBreakpoints.mobile;
        final crossAxisCount = isMobile ? 2 : 4;
        final tileWidth =
            (constraints.maxWidth - AdminSpacing.lg * (crossAxisCount - 1)) /
            crossAxisCount;

        // Wrap sizes each tile to its own content height instead of forcing
        // a fixed aspect ratio, so a card never overflows regardless of how
        // tall its label/value combination ends up being.
        return Wrap(
          spacing: AdminSpacing.lg,
          runSpacing: AdminSpacing.lg,
          children: [
            for (final tile in tiles)
              SizedBox(
                width: tileWidth,
                child: AdminStatCard(
                  icon: tile.icon,
                  value: _formatAmount(tile.stat.amount),
                  label: '${tile.label} · ${tile.stat.count}',
                  color: tile.color,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildActions(AdminUserDetail user) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminRadius.card),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account status',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: AdminSpacing.sm),
          if (_updatingStatus)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _toggleActive,
              icon: Icon(
                user.isActive ? Icons.block_outlined : Icons.check_circle_outline,
              ),
              label: Text(user.isActive ? 'Deactivate user' : 'Activate user'),
              style: OutlinedButton.styleFrom(
                foregroundColor: user.isActive
                    ? AdminColors.danger
                    : AdminColors.success,
              ),
            ),
          const SizedBox(height: AdminSpacing.xl),
          Text(
            'Role',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: AdminSpacing.sm),
          if (_changingRole)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (user.role == 'SuperAdmin')
            const Text(
              'SuperAdmin is config-seeded only and cannot be changed here.',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
            )
          else if (user.role != 'Admin')
            FilledButton(
              onPressed: () => _changeRole('Admin'),
              child: const Text('Grant admin'),
            )
          else
            OutlinedButton(
              onPressed: () => _changeRole('Customer'),
              style: OutlinedButton.styleFrom(foregroundColor: AdminColors.danger),
              child: const Text('Revoke admin'),
            ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) => '₹${amount.toStringAsFixed(2)}';

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
