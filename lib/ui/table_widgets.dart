import 'package:flutter/material.dart';

import 'theme_helpers.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final TextStyle? titleStyle;
  final Widget? headerTrailing;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.titleStyle,
    this.headerTrailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: isDark ? 0.38 : 0.14,
          ),
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: isDark
                ? Colors.black.withValues(alpha: 0.38)
                : const Color(0x0A000000),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: titleStyle ??
                      theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (headerTrailing != null) ...[
                const SizedBox(width: 8),
                headerTrailing!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class TableHeaderCell extends StatelessWidget {
  final String text;
  final double? width;
  final TextAlign align;
  final int maxLines;
  final TextOverflow overflow;
  final TextStyle? style;

  const TableHeaderCell({
    super.key,
    required this.text,
    this.width,
    this.align = TextAlign.center,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelColor = themedLabelColor(theme);
    final baseStyle = style ??
        theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: labelColor,
        );
    final child = Text(
      text,
      style: baseStyle,
      textAlign: align,
      maxLines: maxLines,
      overflow: overflow,
    );
    if (width == null) return child;
    return SizedBox(width: width, child: child);
  }
}

class TableValueCell extends StatelessWidget {
  final String text;
  final double? width;
  final TextAlign align;
  final int maxLines;
  final TextOverflow overflow;
  final TextStyle? style;

  const TableValueCell({
    super.key,
    required this.text,
    this.width,
    this.align = TextAlign.center,
    this.maxLines = 2,
    this.overflow = TextOverflow.ellipsis,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final child = Text(
      text,
      style: style ?? theme.textTheme.bodySmall,
      textAlign: align,
      maxLines: maxLines,
      overflow: overflow,
    );
    if (width == null) return child;
    return SizedBox(width: width, child: child);
  }
}

class ThemedDataTable extends StatelessWidget {
  final List<Widget> columns;
  final List<List<Widget>> rows;
  final double? minWidth;
  final double columnSpacing;
  final double headingRowHeight;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final double horizontalMargin;

  const ThemedDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.minWidth,
    this.columnSpacing = 16,
    this.headingRowHeight = 40,
    this.dataRowMinHeight = 36,
    this.dataRowMaxHeight = 44,
    this.horizontalMargin = 6,
  });

  @override
  Widget build(BuildContext context) {
    Widget table = DataTable(
      columnSpacing: columnSpacing,
      horizontalMargin: horizontalMargin,
      headingRowHeight: headingRowHeight,
      dataRowMinHeight: dataRowMinHeight,
      dataRowMaxHeight: dataRowMaxHeight,
      columns: [
        for (final c in columns) DataColumn(label: c),
      ],
      rows: [
        for (final r in rows)
          DataRow(
            cells: [for (final v in r) DataCell(v)],
          ),
      ],
    );

    if (minWidth != null) {
      table = ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth!),
        child: table,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: table,
    );
  }
}

class ThemedStringTable extends StatelessWidget {
  final List<String> columns;
  final List<List<String>> rows;
  final double minWidth;
  final double columnSpacing;
  final double headingRowHeight;
  final double dataRowMinHeight;
  final double dataRowMaxHeight;
  final double horizontalMargin;

  const ThemedStringTable({
    super.key,
    required this.columns,
    required this.rows,
    required this.minWidth,
    this.columnSpacing = 16,
    this.headingRowHeight = 40,
    this.dataRowMinHeight = 36,
    this.dataRowMaxHeight = 44,
    this.horizontalMargin = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ThemedDataTable(
      minWidth: minWidth,
      columnSpacing: columnSpacing,
      headingRowHeight: headingRowHeight,
      dataRowMinHeight: dataRowMinHeight,
      dataRowMaxHeight: dataRowMaxHeight,
      horizontalMargin: horizontalMargin,
      columns: [
        for (final c in columns)
          TableHeaderCell(text: c, align: TextAlign.left),
      ],
      rows: [
        for (final r in rows)
          [for (final v in r) TableValueCell(text: v, align: TextAlign.left)],
      ],
    );
  }
}
