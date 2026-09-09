import 'package:flutter/material.dart';

import '../../../core/widgets/spaced_column.dart';
import '../../stores/models/admin_store.dart';
import '../models/admin_affiliate_network.dart';

class MappingFormResult {
  const MappingFormResult({
    this.storeId,
    this.affiliateNetworkId,
    required this.externalMerchantId,
    required this.externalMerchantName,
    required this.merchantUrl,
    required this.isActive,
  });

  /// Null when editing — store/network are immutable after creation.
  final String? storeId;
  final String? affiliateNetworkId;
  final String externalMerchantId;
  final String? externalMerchantName;
  final String? merchantUrl;
  final bool isActive;
}

Future<MappingFormResult?> showMappingFormDialog(
  BuildContext context, {
  required List<AdminStore> stores,
  required List<AdminAffiliateNetwork> networks,
  AdminStoreAffiliateMapping? existing,
}) {
  return showDialog<MappingFormResult>(
    context: context,
    builder: (_) => _MappingFormDialog(
      stores: stores,
      networks: networks,
      existing: existing,
    ),
  );
}

class _MappingFormDialog extends StatefulWidget {
  const _MappingFormDialog({
    required this.stores,
    required this.networks,
    this.existing,
  });

  final List<AdminStore> stores;
  final List<AdminAffiliateNetwork> networks;
  final AdminStoreAffiliateMapping? existing;

  @override
  State<_MappingFormDialog> createState() => _MappingFormDialogState();
}

class _MappingFormDialogState extends State<_MappingFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _externalIdController = TextEditingController(
    text: widget.existing?.externalMerchantId,
  );
  late final _externalNameController = TextEditingController(
    text: widget.existing?.externalMerchantName,
  );
  late final _merchantUrlController = TextEditingController(
    text: widget.existing?.merchantUrl,
  );
  late bool _isActive = widget.existing?.isActive ?? true;

  String? _storeId;
  String? _networkId;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _externalIdController.dispose();
    _externalNameController.dispose();
    _merchantUrlController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_isEdit && (_storeId == null || _networkId == null)) return;

    Navigator.of(context).pop(
      MappingFormResult(
        storeId: _isEdit ? null : _storeId,
        affiliateNetworkId: _isEdit ? null : _networkId,
        externalMerchantId: _externalIdController.text.trim(),
        externalMerchantName: _externalNameController.text.trim().isEmpty
            ? null
            : _externalNameController.text.trim(),
        merchantUrl: _merchantUrlController.text.trim().isEmpty
            ? null
            : _merchantUrlController.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit mapping' : 'New store-affiliate mapping'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: withGaps([
              if (_isEdit) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.existing!.storeName} ↔ '
                    '${widget.existing!.affiliateNetworkName}',
                  ),
                ),
              ] else ...[
                DropdownButtonFormField<String>(
                  initialValue: _storeId,
                  decoration: const InputDecoration(labelText: 'Store'),
                  items: widget.stores
                      .map(
                        (s) =>
                            DropdownMenuItem(value: s.id, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _storeId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
                DropdownButtonFormField<String>(
                  initialValue: _networkId,
                  decoration: const InputDecoration(
                    labelText: 'Affiliate network',
                  ),
                  items: widget.networks
                      .map(
                        (n) =>
                            DropdownMenuItem(value: n.id, child: Text(n.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _networkId = value),
                  validator: (value) => value == null ? 'Required' : null,
                ),
              ],
              TextFormField(
                controller: _externalIdController,
                decoration: const InputDecoration(
                  labelText: 'External merchant id',
                  helperText: "The network's own id for this store",
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _externalNameController,
                decoration: const InputDecoration(
                  labelText: 'External merchant name',
                ),
              ),
              TextFormField(
                controller: _merchantUrlController,
                decoration: const InputDecoration(labelText: 'Merchant URL'),
              ),
              if (_isEdit)
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
