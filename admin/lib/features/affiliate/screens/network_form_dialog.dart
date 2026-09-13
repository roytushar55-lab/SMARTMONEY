import 'package:flutter/material.dart';

import '../../../core/widgets/spaced_column.dart';
import '../models/admin_affiliate_network.dart';

class NetworkFormResult {
  const NetworkFormResult({
    required this.name,
    required this.code,
    required this.isActive,
  });

  final String name;
  final String code;
  final bool isActive;
}

Future<NetworkFormResult?> showNetworkFormDialog(
  BuildContext context, {
  AdminAffiliateNetwork? existing,
}) {
  return showDialog<NetworkFormResult>(
    context: context,
    builder: (_) => _NetworkFormDialog(existing: existing),
  );
}

class _NetworkFormDialog extends StatefulWidget {
  const _NetworkFormDialog({this.existing});

  final AdminAffiliateNetwork? existing;

  @override
  State<_NetworkFormDialog> createState() => _NetworkFormDialogState();
}

class _NetworkFormDialogState extends State<_NetworkFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _codeController = TextEditingController(
    text: widget.existing?.code,
  );
  late bool _isActive = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      NetworkFormResult(
        name: _nameController.text.trim(),
        code: _codeController.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return AlertDialog(
      title: Text(isEdit ? 'Edit affiliate network' : 'New affiliate network'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: withGaps([
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    labelText: 'Code',
                    helperText:
                        'Must match what the provider sends in webhooks',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                if (isEdit)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
              ]),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
