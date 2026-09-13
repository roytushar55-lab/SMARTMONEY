import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../models/admin_network_cashback_settings.dart';

/// The "Global" section of a network's cashback detail page: the network-wide
/// user share percent and confirmation window, editable in place. Extracted
/// from the old flat `CashbackSettingsScreen` form so both surfaces share it.
class NetworkGlobalSettingsCard extends StatefulWidget {
  const NetworkGlobalSettingsCard({
    super.key,
    required this.global,
    required this.onSave,
  });

  final AdminNetworkCashbackGlobal? global;
  final Future<void> Function(double userSharePercent, int confirmationWindowDays)
  onSave;

  @override
  State<NetworkGlobalSettingsCard> createState() =>
      _NetworkGlobalSettingsCardState();
}

class _NetworkGlobalSettingsCardState
    extends State<NetworkGlobalSettingsCard> {
  final _formKey = GlobalKey<FormState>();
  late final _shareController = TextEditingController(
    text: widget.global?.userSharePercent.toString() ?? '',
  );
  late final _windowController = TextEditingController(
    text: widget.global?.confirmationWindowDays.toString() ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _shareController.dispose();
    _windowController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmed = await showConfirmDialog(
      context,
      title: 'Update global cashback policy',
      message:
          'This changes the share every future cashback pays out for this '
          'network (existing cashbacks are unaffected). Continue?',
      confirmLabel: 'Update',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.onSave(
        double.parse(_shareController.text.trim()),
        int.parse(_windowController.text.trim()),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AdminSpacing.lg),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminRadius.card),
        border: Border.all(color: AdminColors.border),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Global',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'Default policy for this network, used when no store or '
              'category override applies.',
              style: TextStyle(color: AdminColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: AdminSpacing.lg),
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < AdminBreakpoints.mobile;
                final shareField = TextFormField(
                  controller: _shareController,
                  decoration: const InputDecoration(
                    labelText: 'User share percent',
                    suffixText: '%',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed <= 0 || parsed > 100) {
                      return 'Enter a value between 0 and 100';
                    }
                    return null;
                  },
                );
                final windowField = TextFormField(
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
                );

                if (isMobile) {
                  return Column(
                    children: [
                      shareField,
                      const SizedBox(height: AdminSpacing.md),
                      windowField,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: shareField),
                    const SizedBox(width: AdminSpacing.lg),
                    Expanded(child: windowField),
                  ],
                );
              },
            ),
            const SizedBox(height: AdminSpacing.lg),
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
