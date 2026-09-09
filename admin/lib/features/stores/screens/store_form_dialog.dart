import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/image_upload_field.dart';
import '../../../core/widgets/spaced_column.dart';
import '../../categories/models/admin_category.dart';
import '../models/admin_store.dart';

class StoreFormResult {
  const StoreFormResult({
    required this.name,
    required this.slug,
    required this.shortDescription,
    required this.description,
    required this.logoUrl,
    required this.bannerUrl,
    required this.websiteUrl,
    required this.defaultCashbackText,
    required this.isFeatured,
    required this.displayOrder,
    required this.isActive,
    required this.categoryIds,
  });

  final String name;
  final String? slug;
  final String? shortDescription;
  final String? description;
  final String? logoUrl;
  final String? bannerUrl;
  final String websiteUrl;
  final String? defaultCashbackText;
  final bool isFeatured;
  final int displayOrder;
  final bool isActive;
  final List<String> categoryIds;
}

Future<StoreFormResult?> showStoreFormDialog(
  BuildContext context, {
  required List<AdminCategory> categories,
  AdminStore? existing,
}) {
  return showDialog<StoreFormResult>(
    context: context,
    builder: (_) =>
        _StoreFormDialog(categories: categories, existing: existing),
  );
}

class _StoreFormDialog extends StatefulWidget {
  const _StoreFormDialog({required this.categories, this.existing});

  final List<AdminCategory> categories;
  final AdminStore? existing;

  @override
  State<_StoreFormDialog> createState() => _StoreFormDialogState();
}

class _StoreFormDialogState extends State<_StoreFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name,
  );
  late final _slugController = TextEditingController(
    text: widget.existing?.slug,
  );
  late final _shortDescController = TextEditingController(
    text: widget.existing?.shortDescription,
  );
  late final _descController = TextEditingController(
    text: widget.existing?.description,
  );
  late final _logoUrlController = TextEditingController(
    text: widget.existing?.logoUrl,
  );
  late final _bannerUrlController = TextEditingController(
    text: widget.existing?.bannerUrl,
  );
  late final _websiteUrlController = TextEditingController(
    text: widget.existing?.websiteUrl,
  );
  late final _cashbackTextController = TextEditingController(
    text: widget.existing?.defaultCashbackText,
  );
  late final _displayOrderController = TextEditingController(
    text: '${widget.existing?.displayOrder ?? 0}',
  );
  late bool _isFeatured = widget.existing?.isFeatured ?? false;
  late bool _isActive = widget.existing?.isActive ?? true;
  late final Set<String> _selectedCategoryIds = {
    ...(widget.existing?.categoryIds ?? const []),
  };

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _shortDescController.dispose();
    _descController.dispose();
    _logoUrlController.dispose();
    _bannerUrlController.dispose();
    _websiteUrlController.dispose();
    _cashbackTextController.dispose();
    _displayOrderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      StoreFormResult(
        name: _nameController.text.trim(),
        slug: _slugController.text.trim().isEmpty
            ? null
            : _slugController.text.trim(),
        shortDescription: _shortDescController.text.trim().isEmpty
            ? null
            : _shortDescController.text.trim(),
        description: _descController.text.trim().isEmpty
            ? null
            : _descController.text.trim(),
        logoUrl: _logoUrlController.text.trim().isEmpty
            ? null
            : _logoUrlController.text.trim(),
        bannerUrl: _bannerUrlController.text.trim().isEmpty
            ? null
            : _bannerUrlController.text.trim(),
        websiteUrl: _websiteUrlController.text.trim(),
        defaultCashbackText: _cashbackTextController.text.trim().isEmpty
            ? null
            : _cashbackTextController.text.trim(),
        isFeatured: _isFeatured,
        displayOrder: int.tryParse(_displayOrderController.text.trim()) ?? 0,
        isActive: _isActive,
        categoryIds: _selectedCategoryIds.toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit store' : 'New store'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
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
                  controller: _slugController,
                  decoration: InputDecoration(
                    labelText: 'Slug',
                    hintText: _isEdit ? null : 'Leave blank to auto-generate',
                  ),
                  validator: (v) => _isEdit && (v == null || v.trim().isEmpty)
                      ? 'Required'
                      : null,
                ),
                TextFormField(
                  controller: _websiteUrlController,
                  decoration: const InputDecoration(labelText: 'Website URL'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _shortDescController,
                  decoration: const InputDecoration(
                    labelText: 'Short description',
                  ),
                ),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                TextFormField(
                  controller: _cashbackTextController,
                  decoration: const InputDecoration(
                    labelText: 'Default cashback text',
                  ),
                ),
                ImageUploadField(
                  controller: _logoUrlController,
                  label: 'Logo URL',
                  folder: 'stores',
                ),
                ImageUploadField(
                  controller: _bannerUrlController,
                  label: 'Banner URL',
                  folder: 'stores',
                ),
                TextFormField(
                  controller: _displayOrderController,
                  decoration: const InputDecoration(labelText: 'Display order'),
                  keyboardType: TextInputType.number,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Featured'),
                  value: _isFeatured,
                  onChanged: (v) => setState(() => _isFeatured = v),
                ),
                if (_isEdit)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Categories',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Wrap(
                  spacing: AdminSpacing.xs,
                  children: widget.categories
                      .map(
                        (category) => FilterChip(
                          label: Text(category.name),
                          selected: _selectedCategoryIds.contains(category.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _selectedCategoryIds.add(category.id);
                            } else {
                              _selectedCategoryIds.remove(category.id);
                            }
                          }),
                        ),
                      )
                      .toList(),
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
