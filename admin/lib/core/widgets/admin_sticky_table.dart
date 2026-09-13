import 'package:flutter/material.dart';

import '../theme/admin_colors.dart';

/// A table with fixed-width columns whose header row stays put while the
/// body scrolls vertically, and where the whole table (header + body)
/// scrolls horizontally together as one unit when it's wider than the
/// viewport — so no cell ever truncates and the header never drifts out of
/// sync with the body's columns.
///
/// Fixed widths (rather than `DataTable`'s intrinsic auto-sizing) are what
/// make the frozen header possible: header and body are laid out inside the
/// same horizontally-scrolled, fixed-width column, so they always line up
/// without any manual scroll-position syncing.
class AdminStickyTable extends StatelessWidget {
  const AdminStickyTable({
    super.key,
    required this.columns,
    required this.columnWidths,
    required this.itemCount,
    required this.cellsBuilder,
    this.onRowTap,
    this.shrinkWrap = false,
    this.columnAlignments,
  }) : assert(columns.length == columnWidths.length),
       assert(
         columnAlignments == null || columnAlignments.length == columns.length,
       );

  final List<String> columns;
  final List<double> columnWidths;
  final int itemCount;
  final List<Widget> Function(BuildContext context, int index) cellsBuilder;

  /// Per-column alignment for both the header label and every body cell.
  /// Defaults to [Alignment.centerLeft] for every column when omitted — pass
  /// [Alignment.center] for columns like a status badge that read better
  /// centered.
  final List<Alignment>? columnAlignments;

  /// When set, each row is wrapped in an [InkWell] that calls this with the
  /// row's index. Leave null for screens that use an explicit action cell
  /// (e.g. an "Edit" button) instead of a tappable row.
  final void Function(int index)? onRowTap;

  /// True for tables that sit directly in a page-level scroll view rather
  /// than inside a bounded-height `Expanded` — e.g. a short, non-paginated
  /// override list. Rows are laid out in a plain [Column] that grows with
  /// content instead of an internally-scrolling [ListView], since the body's
  /// `Expanded` would otherwise have no bounded height to expand into.
  final bool shrinkWrap;

  static const _gap = AdminSpacing.md;

  double get _rowContentWidth =>
      columnWidths.reduce((a, b) => a + b) + _gap * (columnWidths.length - 1);

  @override
  Widget build(BuildContext context) {
    final tableWidth = _rowContentWidth + AdminSpacing.lg * 2;

    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminRadius.card),
        border: Border.all(color: AdminColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
            children: [
              _buildHeaderRow(),
              const Divider(height: 1, color: AdminColors.border),
              if (shrinkWrap)
                for (var index = 0; index < itemCount; index++) ...[
                  if (index > 0)
                    const Divider(height: 1, color: AdminColors.border),
                  _buildDataRow(context, index),
                ]
              else
                Expanded(
                  child: itemCount == 0
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          itemCount: itemCount,
                          separatorBuilder: (context, index) => const Divider(
                            height: 1,
                            color: AdminColors.border,
                          ),
                          itemBuilder: (context, index) =>
                              _buildDataRow(context, index),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow() {
    const style = TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AdminColors.textMuted,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: AdminSpacing.md,
      ),
      child: Row(
        children: [
          for (var i = 0; i < columns.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            SizedBox(
              width: columnWidths[i],
              child: Align(
                alignment: columnAlignments?[i] ?? Alignment.centerLeft,
                child: Text(columns[i], style: style),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDataRow(BuildContext context, int index) {
    final cells = cellsBuilder(context, index);

    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminSpacing.lg,
        vertical: AdminSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: _gap),
            SizedBox(
              width: columnWidths[i],
              child: Align(
                alignment: columnAlignments?[i] ?? Alignment.centerLeft,
                child: cells[i],
              ),
            ),
          ],
        ],
      ),
    );

    if (onRowTap == null) return row;

    return InkWell(onTap: () => onRowTap!(index), child: row);
  }
}
