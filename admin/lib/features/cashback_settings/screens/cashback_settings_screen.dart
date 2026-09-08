import 'package:flutter/material.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/view_state.dart';
import '../services/cashback_settings_api_service.dart';

/// The two business levers behind every cashback calculation: what share of
/// commission the user receives, and how long a Pending cashback waits
/// before it's expected to confirm. Previously only changeable via a DB edit.
class CashbackSettingsScreen extends StatefulWidget {
  const CashbackSettingsScreen({super.key});

  @override
  State<CashbackSettingsScreen> createState() => _CashbackSettingsScreenState();
}

class _CashbackSettingsScreenState extends State<CashbackSettingsScreen> {
  final _service = CashbackSettingsApiService();
  final _formKey = GlobalKey<FormState>();
  final _shareController = TextEditingController();
  final _windowController = TextEditingController();

  ViewState _state = ViewState.initial;
  String _errorMessage = '';
  DateTime? _updatedAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _service.dispose();
    _shareController.dispose();
    _windowController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _state = ViewState.loading);
    try {
      final settings = await _service.get();
      _shareController.text = settings.userSharePercent.toString();
      _windowController.text = settings.confirmationWindowDays.toString();
      setState(() {
        _updatedAt = settings.updatedAt;
        _state = ViewState.success;
      });
    } on ApiException catch (error) {
      setState(() {
        _errorMessage = error.message;
        _state = ViewState.error;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Update cashback policy',
      message:
          'This changes the share every future cashback pays out '
          '(existing cashbacks are unaffected). Continue?',
      confirmLabel: 'Update',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);

    try {
      final settings = await _service.update(
        userSharePercent: double.parse(_shareController.text.trim()),
        confirmationWindowDays: int.parse(_windowController.text.trim()),
      );
      if (!mounted) return;
      setState(() => _updatedAt = settings.updatedAt);
      showSuccessSnackBar(context, 'Cashback settings updated.');
    } on ApiException catch (error) {
      if (!mounted) return;
      showErrorSnackBar(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
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
            'Cashback settings',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AdminColors.textPrimary,
            ),
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
      case ViewState.success:
        return _buildForm();
    }
  }

  Widget _buildForm() {
    return SizedBox(
      width: 380,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _shareController,
              decoration: const InputDecoration(
                labelText: 'User share percent',
                suffixText: '%',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                final parsed = double.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed <= 0 || parsed > 100) {
                  return 'Enter a value between 0 and 100';
                }
                return null;
              },
            ),
            const SizedBox(height: AdminSpacing.md),
            TextFormField(
              controller: _windowController,
              decoration: const InputDecoration(
                labelText: 'Confirmation window',
                suffixText: 'days',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                final parsed = int.tryParse(value?.trim() ?? '');
                if (parsed == null || parsed <= 0) {
                  return 'Enter a positive number of days';
                }
                return null;
              },
            ),
            const SizedBox(height: AdminSpacing.lg),
            if (_updatedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminSpacing.md),
                child: Text(
                  'Last updated: $_updatedAt',
                  style: const TextStyle(color: AdminColors.textMuted, fontSize: 12),
                ),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
