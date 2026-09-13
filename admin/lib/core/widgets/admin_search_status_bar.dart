import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// A creative pill search field plus two small status chips ("Active" /
/// "Inactive"), reused wherever an admin list needs both free-text and
/// active/inactive filtering (Users, Store mappings, ...). The search field
/// glows and lifts on focus with a clear button that appears once there's
/// text; the chips fill solid green/red once selected, each hugging its
/// label rather than stretching. The search field caps at 240px on wide
/// screens but shrinks to whatever's left beside the two chips on narrow
/// ones, so all three always stay on one line.
class AdminSearchStatusBar extends StatefulWidget {
  const AdminSearchStatusBar({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.statusFilter,
    required this.onStatusToggle,
    this.hintText = 'Search name, email, status…',
    this.extraChips,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  /// null = no status toggle applied, true = "Active" chip selected, false =
  /// "Inactive" chip selected.
  final bool? statusFilter;
  final ValueChanged<bool> onStatusToggle;
  final String hintText;

  /// Extra [AdminFilterChip]s (or any widgets) appended after the
  /// Active/Inactive pair for a screen that needs another filter dimension
  /// alongside status — e.g. Stores' Featured/Not featured toggle.
  final List<Widget>? extraChips;

  @override
  State<AdminSearchStatusBar> createState() => _AdminSearchStatusBarState();
}

class _AdminSearchStatusBarState extends State<AdminSearchStatusBar> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(
      () => setState(() => _focused = _focusNode.hasFocus),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: _buildSearchField(),
          ),
        ),
        const SizedBox(width: AdminSpacing.sm),
        AdminFilterChip(
          selected: widget.statusFilter == true,
          label: 'Active',
          activeColor: AdminColors.success,
          onTap: () => widget.onStatusToggle(true),
        ),
        const SizedBox(width: AdminSpacing.sm),
        AdminFilterChip(
          selected: widget.statusFilter == false,
          label: 'Inactive',
          activeColor: AdminColors.danger,
          onTap: () => widget.onStatusToggle(false),
        ),
        for (final chip in widget.extraChips ?? <Widget>[]) ...[
          const SizedBox(width: AdminSpacing.sm),
          chip,
        ],
      ],
    );
  }

  Widget _buildSearchField() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      height: 42,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminRadius.chip),
        border: Border.all(
          color: _focused ? AdminColors.primary : AdminColors.border,
          width: _focused ? 1.5 : 1,
        ),
        boxShadow: _focused
            ? [
                BoxShadow(
                  color: AdminColors.primary.withValues(alpha: 0.16),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: AdminColors.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(
            Icons.search_rounded,
            size: 19,
            color: _focused ? AdminColors.primary : AdminColors.textMuted,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: const TextStyle(
                fontSize: 13.5,
                color: AdminColors.textPrimary,
              ),
              decoration: InputDecoration(
                isDense: true,
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.hintText,
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AdminColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, child) {
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: value.text.isNotEmpty
                    ? InkWell(
                        key: const ValueKey('clear'),
                        onTap: widget.onClear,
                        borderRadius: BorderRadius.circular(AdminRadius.chip),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AdminColors.textMuted,
                          ),
                        ),
                      )
                    : const SizedBox(key: ValueKey('empty'), width: 4),
              );
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }

}

/// A small pill filter chip — solid-filled in [activeColor] when [selected],
/// outlined and muted otherwise. Hugs its label rather than stretching.
/// Powers the Active/Inactive pair inside [AdminSearchStatusBar], and is
/// reused directly for other single-dimension toggles (e.g. Stores'
/// Featured/Not featured filter) so every admin list filters with the same
/// look.
class AdminFilterChip extends StatelessWidget {
  const AdminFilterChip({
    super.key,
    required this.selected,
    required this.label,
    required this.activeColor,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminRadius.chip),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: selected ? activeColor : AdminColors.surface,
          borderRadius: BorderRadius.circular(AdminRadius.chip),
          border: Border.all(
            color: selected ? activeColor : AdminColors.border,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
