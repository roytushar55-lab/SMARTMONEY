import 'package:flutter/material.dart';

import '../../../core/auth/admin_session.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/admin_page_header.dart';
import '../../../core/widgets/admin_page_scaffold.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/status_badge.dart';
import '../models/admin_user_lookup.dart';
import '../services/admin_user_api_service.dart';

/// SuperAdmin-only screen: find a user by exact email, then promote/demote
/// between Customer and Admin. The backend enforces that SuperAdmin can't be
/// granted here and that nobody can change their own role.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _service = AdminUserApiService();
  final _emailController = TextEditingController();

  bool _searching = false;
  bool _changingRole = false;
  String? _errorMessage;
  AdminUserLookup? _result;
  bool _searched = false;

  @override
  void dispose() {
    _service.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() {
      _searching = true;
      _errorMessage = null;
      _result = null;
      _searched = true;
    });

    try {
      final result = await _service.findByEmail(email);
      setState(() => _result = result);
    } on ApiException catch (error) {
      setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _changeRole(String newRole) async {
    final user = _result;
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
      setState(() => _result = user.copyWith(role: newRole));
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
    return AdminPageScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Users',
            description:
                'Look up a user by email to grant or revoke admin access.',
          ),
          const SizedBox(height: AdminSpacing.lg),
          _buildSearchBar(),
          const SizedBox(height: AdminSpacing.xxl),
          if (_searching)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: AdminColors.danger),
            )
          else if (_result != null)
            _buildResult(_result!)
          else if (_searched)
            const Text(
              'No user with that email.',
              style: TextStyle(color: AdminColors.textMuted),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return SizedBox(
      width: 420,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'User email',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
          ),
          const SizedBox(width: AdminSpacing.sm),
          FilledButton(onPressed: _search, child: const Text('Search')),
        ],
      ),
    );
  }

  Widget _buildResult(AdminUserLookup user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AdminSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.fullName.isEmpty ? user.email : user.fullName,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              user.email,
              style: const TextStyle(color: AdminColors.textMuted),
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
            const SizedBox(height: AdminSpacing.lg),
            if (_changingRole)
              const CircularProgressIndicator()
            else if (user.role == 'SuperAdmin')
              const Text(
                'SuperAdmin is config-seeded only and cannot be changed here.',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
              )
            else
              Row(
                children: [
                  if (user.role != 'Admin')
                    FilledButton(
                      onPressed: () => _changeRole('Admin'),
                      child: const Text('Grant admin'),
                    )
                  else
                    OutlinedButton(
                      onPressed: () => _changeRole('Customer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AdminColors.danger,
                      ),
                      child: const Text('Revoke admin'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
