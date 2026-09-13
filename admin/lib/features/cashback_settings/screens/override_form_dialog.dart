import 'package:flutter/material.dart';

import '../../../core/widgets/spaced_column.dart';
import '../../categories/models/admin_category.dart';
import '../../stores/models/admin_store.dart';
import '../models/admin_cashback_rate_override.dart';

class OverrideFormResult {
  const OverrideFormResult({
    required this.storeId,
    required this.categoryId,
    required this.userSharePercent,
    required this.confirmationWindowDays,
  });

  final String storeId;
  final String? categoryId;
  final double userSharePercent;
  final int confirmationWindowDays;
}

/// Add/edit a store (and optional category) override of a network's global
/// cashback policy. Store and category are immutable once created, so they're
/// disabled (not just pre-filled) when editing an existing override.
Future<OverrideFormResult?> showOverrideFormDialog(
  BuildContext context, {
  required List<AdminStore> stores,
  required List<AdminCategory> categories,
  AdminCashbackRateOverride? existing,
}) {
  return showDialog<OverrideFormResult>(
    context: context,
    builder: (_) => _OverrideFormDialog(
      stores: stores,
      categories: categories,
      existing: existing,
    ),
  );
}

class _OverrideFormDialog extends StatefulWidget {
  const _OverrideFormDialog({
    required this.stores,
    required this.categories,
    this.existing,
  });

  final List<AdminStore> stores;
  final List<AdminCategory> categories;
  final AdminCashbackRateOverride? existing;

  @override
  State<_OverrideFormDialog> createState() => _OverrideFormDialogState();
}

class _OverrideFormDialogState extends State<_OverrideFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _shareController = TextEditingController(
    text: widget.existing?.userSharePercent.toString(),
  );
  late final _windowController = TextEditingController(
    text: widget.existing?.confirmationWindowDays.toString(),
  );
  String? _storeId;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _storeId = widget.existing?.storeId;
    _categoryId = widget.existing?.categoryId;
  }

  @override
  void dispose() {
    _shareController.dispose();
    _windowController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_storeId == null) return;

    Navigator.of(context).pop(
      OverrideFormResult(
        storeId: _storeId!,
        categoryId: _categoryId,
        userSharePercent: double.parse(_shareController.text.trim()),
        confirmationWindowDays: int.parse(_windowController.text.trim()),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit override' : 'New override'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: withGaps([
                DropdownButtonFormField<String>(
                  initialValue: _storeId,
                  decoration: const InputDecoration(labelText: 'Store'),
                  items: widget.stores
                      .map(
                        (store) => DropdownMenuItem(
                          value: store.id,
                          child: Text(store.name),
                        ),
                      )
                      .toList(),
                  onChanged: isEdit
                      ? null
                      : (value) => setState(() => _storeId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                DropdownButtonFormField<String?>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    helperText: 'Leave blank to apply to all categories',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All categories'),
                    ),
                    ...widget.categories.map(
                      (category) => DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    ),
                  ],
                  onChanged: isEdit
                      ? null
                      : (value) => setState(() => _categoryId = value),
                ),
                TextFormField(
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
                ),
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
