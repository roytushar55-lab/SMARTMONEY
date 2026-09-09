import 'package:flutter/material.dart';

import '../../../core/widgets/spaced_column.dart';
import '../models/admin_category.dart';

class CategoryFormResult {
  const CategoryFormResult({
    required this.name,
    required this.slug,
    required this.description,
    required this.iconUrl,
    required this.displayOrder,
    required this.isActive,
  });

  final String name;
  final String? slug;
  final String? description;
  final String? iconUrl;
  final int displayOrder;
  final bool isActive;
}

/// Returns the submitted values, or null if cancelled. [existing] null means
/// "create"; non-null pre-fills the form for editing (slug becomes required
/// and the active toggle appears, matching what the backend accepts).
Future<CategoryFormResult?> showCategoryFormDialog(
  BuildContext context, {
  AdminCategory? existing,
}) {
  return showDialog<CategoryFormResult>(
    context: context,
    builder: (_) => _CategoryFormDialog(existing: existing),
  );
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({this.existing});

  final AdminCategory? existing;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _slugController = TextEditingController(
    text: widget.existing?.slug,
  );
  late final _descriptionController = TextEditingController(
    text: widget.existing?.description,
  );
  late final _iconUrlController = TextEditingController(
    text: widget.existing?.iconUrl,
  );
  late final _displayOrderController = TextEditingController(
    text: '${widget.existing?.displayOrder ?? 0}',
  );
  late bool _isActive = widget.existing?.isActive ?? true;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _descriptionController.dispose();
    _iconUrlController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      CategoryFormResult(
        name: _nameController.text.trim(),
        slug: _slugController.text.trim().isEmpty
            ? null
            : _slugController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        iconUrl: _iconUrlController.text.trim().isEmpty
            ? null
            : _iconUrlController.text.trim(),
        displayOrder: int.tryParse(_displayOrderController.text.trim()) ?? 0,
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit category' : 'New category'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: withGaps([
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              TextFormField(
                controller: _slugController,
                decoration: InputDecoration(
                  labelText: 'Slug',
                  hintText: _isEdit ? null : 'Leave blank to auto-generate',
                ),
                validator: (value) =>
                    _isEdit && (value == null || value.trim().isEmpty)
                    ? 'Slug is required'
                    : null,
              ),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
                maxLines: 2,
              ),
              TextFormField(
                controller: _iconUrlController,
                decoration: const InputDecoration(labelText: 'Icon URL'),
              ),
              TextFormField(
                controller: _displayOrderController,
                decoration: const InputDecoration(labelText: 'Display order'),
                keyboardType: TextInputType.number,
              ),
              if (_isEdit)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
            ]),
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
