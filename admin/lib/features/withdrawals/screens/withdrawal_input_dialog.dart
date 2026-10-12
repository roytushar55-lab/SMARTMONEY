import 'package:flutter/material.dart';

import '../../../core/theme/admin_colors.dart';

/// Asks the admin for one piece of text before a withdrawal action: a reason
/// the user will see, or a bank transaction reference. Returns the trimmed
/// text, or null if cancelled. Empty (or whitespace-only) text is refused.
Future<String?> showWithdrawalInputDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String label,
  required String confirmLabel,
  String? hint,
  String emptyError = 'This is required.',
  int maxLength = 500,
  bool multiline = false,
  bool danger = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _WithdrawalInputDialog(
      title: title,
      message: message,
      label: label,
      confirmLabel: confirmLabel,
      hint: hint,
      emptyError: emptyError,
      maxLength: maxLength,
      multiline: multiline,
      danger: danger,
    ),
  );
}

class _WithdrawalInputDialog extends StatefulWidget {
  const _WithdrawalInputDialog({
    required this.title,
    required this.message,
    required this.label,
    required this.confirmLabel,
    required this.hint,
    required this.emptyError,
    required this.maxLength,
    required this.multiline,
    required this.danger,
  });

  final String title;
  final String message;
  final String label;
  final String confirmLabel;
  final String? hint;
  final String emptyError;
  final int maxLength;
  final bool multiline;
  final bool danger;

  @override
  State<_WithdrawalInputDialog> createState() => _WithdrawalInputDialogState();
}

class _WithdrawalInputDialogState extends State<_WithdrawalInputDialog> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.message),
                const SizedBox(height: AdminSpacing.lg),
                TextFormField(
                  controller: _controller,
                  autofocus: true,
                  maxLength: widget.maxLength,
                  maxLines: widget.multiline ? 3 : 1,
                  minLines: widget.multiline ? 2 : 1,
                  textInputAction: widget.multiline
                      ? TextInputAction.newline
                      : TextInputAction.done,
                  onFieldSubmitted: widget.multiline ? null : (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: widget.label,
                    hintText: widget.hint,
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? widget.emptyError
                      : null,
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
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: widget.danger
                ? AdminColors.danger
                : AdminColors.primary,
          ),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}
