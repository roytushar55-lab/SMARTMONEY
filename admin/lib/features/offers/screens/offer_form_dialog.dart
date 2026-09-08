import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';
import '../../../core/widgets/image_upload_field.dart';
import '../../stores/models/admin_store.dart';
import '../models/admin_offer.dart';

/// Returns the request body map ready to POST/PUT, or null if cancelled.
Future<Map<String, dynamic>?> showOfferFormDialog(
  BuildContext context, {
  required List<AdminStore> stores,
  AdminOffer? existing,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _OfferFormDialog(stores: stores, existing: existing),
  );
}

class _OfferFormDialog extends StatefulWidget {
  const _OfferFormDialog({required this.stores, this.existing});

  final List<AdminStore> stores;
  final AdminOffer? existing;

  @override
  State<_OfferFormDialog> createState() => _OfferFormDialogState();
}

class _OfferFormDialogState extends State<_OfferFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _titleController = TextEditingController(text: widget.existing?.title);
  late final _slugController = TextEditingController(text: widget.existing?.slug);
  late final _shortDescController =
      TextEditingController(text: widget.existing?.shortDescription);
  late final _descController = TextEditingController(text: widget.existing?.description);
  late final _termsController =
      TextEditingController(text: widget.existing?.termsAndConditions);
  late final _imageUrlController = TextEditingController(text: widget.existing?.imageUrl);
  late final _cashbackValueController = TextEditingController(
    text: widget.existing?.cashbackValue?.toString(),
  );
  late final _cashbackTextController =
      TextEditingController(text: widget.existing?.cashbackText);
  late final _couponCodeController =
      TextEditingController(text: widget.existing?.couponCode);
  late final _destinationUrlController =
      TextEditingController(text: widget.existing?.destinationUrl);
  late final _priorityController = TextEditingController(
    text: '${widget.existing?.priority ?? 0}',
  );

  late String? _storeId = widget.existing?.storeId ?? widget.stores.firstOrNull?.id;
  late String _offerType = kOfferTypes.contains(widget.existing?.offerType)
      ? widget.existing!.offerType
      : kOfferTypes.first;
  late String _cashbackType = kCashbackTypes.contains(widget.existing?.cashbackType)
      ? widget.existing!.cashbackType
      : kCashbackTypes.last;
  late bool _isFeatured = widget.existing?.isFeatured ?? false;
  late bool _isActive = widget.existing?.isActive ?? true;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _shortDescController.dispose();
    _descController.dispose();
    _termsController.dispose();
    _imageUrlController.dispose();
    _cashbackValueController.dispose();
    _cashbackTextController.dispose();
    _couponCodeController.dispose();
    _destinationUrlController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_storeId == null) return;

    final body = <String, dynamic>{
      if (!_isEdit) 'storeId': _storeId,
      'title': _titleController.text.trim(),
      if (_isEdit || _slugController.text.trim().isNotEmpty)
        'slug': _slugController.text.trim().isEmpty ? null : _slugController.text.trim(),
      'offerType': _offerType,
      'shortDescription': _emptyToNull(_shortDescController.text),
      'description': _emptyToNull(_descController.text),
      'termsAndConditions': _emptyToNull(_termsController.text),
      'imageUrl': _emptyToNull(_imageUrlController.text),
      'cashbackType': _cashbackType,
      'cashbackValue': double.tryParse(_cashbackValueController.text.trim()),
      'cashbackText': _emptyToNull(_cashbackTextController.text),
      'couponCode': _emptyToNull(_couponCodeController.text),
      'destinationUrl': _destinationUrlController.text.trim(),
      'isFeatured': _isFeatured,
      'priority': int.tryParse(_priorityController.text.trim()) ?? 0,
    };

    if (_isEdit) {
      body['isActive'] = _isActive;
    }

    Navigator.of(context).pop(body);
  }

  String? _emptyToNull(String value) => value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit offer' : 'New offer'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isEdit)
                  DropdownButtonFormField<String>(
                    initialValue: _storeId,
                    decoration: const InputDecoration(labelText: 'Store'),
                    items: widget.stores
                        .map((s) => DropdownMenuItem(value: s.id, child: Text(s.name)))
                        .toList(),
                    onChanged: (value) => setState(() => _storeId = value),
                    validator: (value) => value == null ? 'Required' : null,
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Store: ${widget.existing!.storeName}',
                      style: const TextStyle(color: AdminColors.textMuted),
                    ),
                  ),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _slugController,
                  decoration: InputDecoration(
                    labelText: 'Slug',
                    hintText: _isEdit ? null : 'Leave blank to auto-generate',
                  ),
                  validator: (v) =>
                      _isEdit && (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _offerType,
                  decoration: const InputDecoration(labelText: 'Offer type'),
                  items: kOfferTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() => _offerType = value!),
                ),
                TextFormField(
                  controller: _destinationUrlController,
                  decoration: const InputDecoration(labelText: 'Destination URL'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                TextFormField(
                  controller: _shortDescController,
                  decoration: const InputDecoration(labelText: 'Short description'),
                ),
                TextFormField(
                  controller: _descController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                TextFormField(
                  controller: _termsController,
                  decoration: const InputDecoration(labelText: 'Terms & conditions'),
                  maxLines: 2,
                ),
                const SizedBox(height: AdminSpacing.sm),
                ImageUploadField(
                  controller: _imageUrlController,
                  label: 'Image URL',
                  folder: 'offers',
                ),
                const SizedBox(height: AdminSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: _cashbackType,
                  decoration: const InputDecoration(labelText: 'Cashback type'),
                  items: kCashbackTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (value) => setState(() => _cashbackType = value!),
                ),
                TextFormField(
                  controller: _cashbackValueController,
                  decoration: const InputDecoration(labelText: 'Cashback value'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextFormField(
                  controller: _cashbackTextController,
                  decoration: const InputDecoration(labelText: 'Cashback text'),
                ),
                TextFormField(
                  controller: _couponCodeController,
                  decoration: const InputDecoration(labelText: 'Coupon code'),
                ),
                TextFormField(
                  controller: _priorityController,
                  decoration: const InputDecoration(labelText: 'Priority'),
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
              ],
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
