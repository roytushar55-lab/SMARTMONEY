import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// A pill-shaped search box with a clear button that appears once there is
/// text. The page decides when to search (typing pause, Enter) through
/// [onChanged] and [onSubmitted].
class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    this.fieldKey,
    this.clearKey,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  /// For tests: the text field and its clear button.
  final Key? fieldKey;
  final Key? clearKey;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadius.chip),
          borderSide: BorderSide(color: color, width: width),
        );

    return SizedBox(
      height: 42,
      child: TextField(
        key: fieldKey,
        controller: controller,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 13.5, color: AdminColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AdminColors.surface,
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: AdminColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 19,
            color: AdminColors.textMuted,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, child) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    key: clearKey,
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: border(AdminColors.border),
          enabledBorder: border(AdminColors.border),
          focusedBorder: border(AdminColors.primary, 1.5),
        ),
      ),
    );
  }
}
