import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResultsChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final List<Widget> legend;
  final String? helpTooltip;

  const ResultsChartCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.legend = const <Widget>[],
    this.helpTooltip,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 10 : 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.24),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (helpTooltip != null) ...[
                const SizedBox(width: 8),
                _ResultsChartHelpButton(
                  title: title,
                  message: helpTooltip!,
                ),
              ],
            ],
          ),
          if (subtitle != null) ...[
            SizedBox(height: compact ? 3 : 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
          if (legend.isNotEmpty) ...[
            SizedBox(height: compact ? 8 : 10),
            Wrap(
              spacing: compact ? 6 : 8,
              runSpacing: compact ? 6 : 8,
              children: legend,
            ),
          ],
          SizedBox(height: compact ? 10 : 12),
          child,
        ],
      ),
    );
  }
}

class _ResultsChartHelpButton extends StatelessWidget {
  final String title;
  final String message;

  const _ResultsChartHelpButton({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      waitDuration: const Duration(milliseconds: 250),
      child: IconButton(
        iconSize: 18,
        splashRadius: 18,
        visualDensity: VisualDensity.compact,
        tooltip: message,
        icon: const Icon(Icons.help_outline),
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(MaterialLocalizations.of(context).okButtonLabel),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ResultsChartLegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final String? value;

  const ResultsChartLegendChip({
    super.key,
    required this.color,
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final text = value == null ? label : '$label: $value';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.32 : 0.12,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          SizedBox(width: compact ? 6 : 8),
          Text(
            text,
            style: (compact
                    ? theme.textTheme.labelSmall
                    : theme.textTheme.labelMedium)
                ?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartRangeSummary extends StatelessWidget {
  final String leading;
  final String trailing;

  const _ChartRangeSummary({
    required this.leading,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontWeight: FontWeight.w700,
    );

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(leading, style: textStyle),
          const SizedBox(height: 4),
          Text(trailing, style: textStyle),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Text(
            leading,
            style: textStyle,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          trailing,
          style: textStyle,
        ),
      ],
    );
  }
}

class ScoreSummaryChart extends StatelessWidget {
  final int min;
  final int median;
  final int mean;
  final int max;
  final String minLabel;
  final String medianLabel;
  final String meanLabel;
  final String maxLabel;
  final String Function(num value) formatValue;

  const ScoreSummaryChart({
    super.key,
    required this.min,
    required this.median,
    required this.mean,
    required this.max,
    required this.minLabel,
    required this.medianLabel,
    required this.meanLabel,
    required this.maxLabel,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 420;
    final values = <int>[min, median, mean, max];
    final lower = values.reduce(math.min);
    final upper = values.reduce(math.max);
    final span = math.max(1, upper - lower).toDouble();
    final theme = Theme.of(context);
    const minColor = Color(0xFF3B82F6);
    const medianColor = Color(0xFFF59E0B);
    const meanColor = Color(0xFF10B981);
    const maxColor = Color(0xFFEF4444);

    double normalized(int value) {
      if (upper == lower) return 0.5;
      return ((value - lower) / span).clamp(0.0, 1.0);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? 68 : 78,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: compact ? 30 : 34,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  _marker(
                    context,
                    left: width * normalized(min),
                    color: minColor,
                    label: minLabel,
                  ),
                  _marker(
                    context,
                    left: width * normalized(median),
                    color: medianColor,
                    label: medianLabel,
                  ),
                  _marker(
                    context,
                    left: width * normalized(mean),
                    color: meanColor,
                    label: meanLabel,
                  ),
                  _marker(
                    context,
                    left: width * normalized(max),
                    color: maxColor,
                    label: maxLabel,
                  ),
                ],
              );
            },
          ),
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                formatValue(lower),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              formatValue(upper),
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _marker(
    BuildContext context, {
    required double left,
    required Color color,
    required String label,
  }) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    return Positioned(
      left: math.max(0, left - (compact ? 16 : 18)),
      top: 0,
      child: SizedBox(
        width: compact ? 32 : 36,
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            SizedBox(height: compact ? 4 : 6),
            Container(
              width: 3,
              height: compact ? 36 : 44,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BarChartSeries {
  final String label;
  final Color color;
  final List<double> values;

  const BarChartSeries({
    required this.label,
    required this.color,
    required this.values,
  });
}

enum GroupedBarScaleMode {
  global,
  perSeriesZoom,
}

class GroupedHorizontalBarChart extends StatelessWidget {
  final List<String> categories;
  final List<BarChartSeries> series;
  final String Function(num value) formatValue;
  final GroupedBarScaleMode scaleMode;
  final double minVisibleFraction;

  const GroupedHorizontalBarChart({
    super.key,
    required this.categories,
    required this.series,
    required this.formatValue,
    this.scaleMode = GroupedBarScaleMode.global,
    this.minVisibleFraction = 0.16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final globalMaxValue =
        series.expand((entry) => entry.values).fold<double>(0, math.max);

    return Column(
      children: [
        for (int categoryIndex = 0;
            categoryIndex < categories.length;
            categoryIndex++) ...[
          if (categoryIndex > 0)
            Divider(
              height: 18,
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              categories[categoryIndex],
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          for (int seriesIndex = 0;
              seriesIndex < series.length;
              seriesIndex++) ...[
            () {
              final entry = series[seriesIndex];
              final value = categoryIndex < entry.values.length
                  ? entry.values[categoryIndex]
                  : 0.0;
              return _GroupedBarRow(
                label: entry.label,
                color: entry.color,
                value: value,
                fraction: _groupedBarFraction(
                  value: value,
                  allSeries: series,
                  seriesIndex: seriesIndex,
                  globalMaxValue: globalMaxValue,
                  scaleMode: scaleMode,
                  minVisibleFraction: minVisibleFraction,
                ),
                formatValue: formatValue,
              );
            }(),
            SizedBox(height: compact ? 6 : 8),
          ],
        ],
      ],
    );
  }
}

class _GroupedBarRow extends StatelessWidget {
  final String label;
  final Color color;
  final double value;
  final double fraction;
  final String Function(num value) formatValue;

  const _GroupedBarRow({
    required this.label,
    required this.color,
    required this.value,
    required this.fraction,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final trackColor =
        theme.colorScheme.surface.withValues(alpha: compact ? 0.88 : 0.82);
    final trackBorderColor = theme.colorScheme.outline.withValues(
      alpha: theme.brightness == Brightness.dark ? 0.18 : 0.08,
    );

    return Row(
      children: [
        SizedBox(
          width: compact ? 62 : 74,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackWidth = constraints.maxWidth;
                final barWidth = fraction <= 0
                    ? 0.0
                    : math.max(trackWidth * fraction, compact ? 6.0 : 8.0);
                return SizedBox(
                  height: compact ? 10 : 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: trackColor,
                      border: Border.all(color: trackBorderColor),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Stack(
                      children: [
                        if (barWidth > 0)
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            width: math.min(barWidth, trackWidth),
                            child: ColoredBox(color: color),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        SizedBox(width: compact ? 8 : 10),
        SizedBox(
          width: compact ? 58 : 72,
          child: Text(
            formatValue(value),
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class GroupedVerticalBarChart extends StatelessWidget {
  final List<String> categories;
  final List<BarChartSeries> series;
  final String xAxisLabel;
  final String yAxisLabel;
  final String emptyLabel;
  final String Function(num value) formatValue;
  final GroupedBarScaleMode scaleMode;
  final double minVisibleFraction;

  const GroupedVerticalBarChart({
    super.key,
    required this.categories,
    required this.series,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.emptyLabel,
    required this.formatValue,
    this.scaleMode = GroupedBarScaleMode.global,
    this.minVisibleFraction = 0.16,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    if (categories.isEmpty || series.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall,
      );
    }

    final globalMaxValue =
        series.expand((entry) => entry.values).fold<double>(0, math.max);
    final allValues =
        series.expand((entry) => entry.values).toList(growable: false);
    final minValue = allValues.isEmpty ? 0.0 : allValues.reduce(math.min);
    final maxValue = allValues.isEmpty ? 0.0 : allValues.reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? 210 : 236,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int categoryIndex = 0;
                  categoryIndex < categories.length;
                  categoryIndex++) ...[
                if (categoryIndex > 0) SizedBox(width: compact ? 10 : 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (int seriesIndex = 0;
                                  seriesIndex < series.length;
                                  seriesIndex++) ...[
                                if (seriesIndex > 0)
                                  SizedBox(width: compact ? 4 : 6),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Expanded(
                                        child: Align(
                                          alignment: Alignment.bottomCenter,
                                          child: FractionallySizedBox(
                                            heightFactor: _groupedBarFraction(
                                              value: categoryIndex <
                                                      series[seriesIndex]
                                                          .values
                                                          .length
                                                  ? series[seriesIndex]
                                                      .values[categoryIndex]
                                                  : 0.0,
                                              allSeries: series,
                                              seriesIndex: seriesIndex,
                                              globalMaxValue: globalMaxValue,
                                              scaleMode: scaleMode,
                                              minVisibleFraction:
                                                  minVisibleFraction,
                                            ),
                                            widthFactor: 1,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                color:
                                                    series[seriesIndex].color,
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                  top: Radius.circular(8),
                                                ),
                                              ),
                                              child: const SizedBox.expand(),
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: compact ? 6 : 8),
                                      Text(
                                        formatValue(
                                          categoryIndex <
                                                  series[seriesIndex]
                                                      .values
                                                      .length
                                              ? series[seriesIndex]
                                                  .values[categoryIndex]
                                              : 0.0,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 10),
                      Text(
                        categories[categoryIndex],
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ChartRangeSummary(
          leading: '$xAxisLabel: ${categories.join(' · ')}',
          trailing:
              '$yAxisLabel: ${formatValue(minValue)} -> ${formatValue(maxValue)}',
        ),
      ],
    );
  }
}

double _groupedBarFraction({
  required double value,
  required List<BarChartSeries> allSeries,
  required int seriesIndex,
  required double globalMaxValue,
  required GroupedBarScaleMode scaleMode,
  required double minVisibleFraction,
}) {
  const perSeriesZoomExponent = 2.6;
  if (value <= 0) return 0.0;
  switch (scaleMode) {
    case GroupedBarScaleMode.global:
      if (globalMaxValue <= 0) return 0.0;
      return (value / globalMaxValue).clamp(0.0, 1.0);
    case GroupedBarScaleMode.perSeriesZoom:
      final seriesValues = allSeries[seriesIndex].values;
      if (seriesValues.isEmpty) return 0.0;
      final seriesMax = seriesValues.fold<double>(0, math.max);
      if (seriesMax <= 0) return 0.0;
      if (seriesMax <= 1e-9) {
        return 1.0;
      }
      final ratio = (value / seriesMax).clamp(0.0, 1.0);
      if ((ratio - 1.0).abs() < 1e-9) {
        return 1.0;
      }
      final emphasized = math.pow(ratio, perSeriesZoomExponent).toDouble();
      return math.max(minVisibleFraction, emphasized).clamp(0.0, 1.0);
  }
}

class StackedBarSegment {
  final String label;
  final Color color;
  final List<double> values;

  const StackedBarSegment({
    required this.label,
    required this.color,
    required this.values,
  });
}

class StackedHorizontalBarChart extends StatelessWidget {
  final List<String> categories;
  final List<StackedBarSegment> segments;
  final String Function(num value) formatValue;

  const StackedHorizontalBarChart({
    super.key,
    required this.categories,
    required this.segments,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final totals = List<double>.generate(
      categories.length,
      (categoryIndex) => segments.fold<double>(
        0,
        (sum, segment) =>
            sum +
            (categoryIndex < segment.values.length
                ? segment.values[categoryIndex]
                : 0),
      ),
      growable: false,
    );
    final maxTotal = totals.fold<double>(0, math.max);
    final denominator = maxTotal <= 0 ? 1.0 : maxTotal;
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;

    return Column(
      children: [
        for (int categoryIndex = 0;
            categoryIndex < categories.length;
            categoryIndex++) ...[
          if (categoryIndex > 0)
            Divider(
              height: 18,
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          Row(
            children: [
              SizedBox(
                width: compact ? 32 : 40,
                child: Text(
                  categories[categoryIndex],
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final total = totals[categoryIndex];
                    final totalWidth =
                        constraints.maxWidth * (total / denominator);
                    var offset = 0.0;
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: compact ? 12 : 14,
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: ColoredBox(
                                color: theme.colorScheme.surfaceContainerLow,
                              ),
                            ),
                            for (final segment in segments)
                              () {
                                final value =
                                    categoryIndex < segment.values.length
                                        ? segment.values[categoryIndex]
                                        : 0;
                                final width = total <= 0
                                    ? 0.0
                                    : totalWidth * (value / total);
                                final currentLeft = offset;
                                offset += width;
                                return Positioned(
                                  left: currentLeft,
                                  top: 0,
                                  bottom: 0,
                                  width: width,
                                  child: ColoredBox(color: segment.color),
                                );
                              }(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(width: compact ? 8 : 10),
              SizedBox(
                width: compact ? 48 : 56,
                child: Text(
                  formatValue(totals[categoryIndex]),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class HeadToHeadMetricDatum {
  final String label;
  final double leftValue;
  final double rightValue;
  final String leftText;
  final String rightText;
  final bool higherIsBetter;

  const HeadToHeadMetricDatum({
    required this.label,
    required this.leftValue,
    required this.rightValue,
    required this.leftText,
    required this.rightText,
    this.higherIsBetter = true,
  });
}

class HeadToHeadDeltaChart extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final Color leftColor;
  final Color rightColor;
  final List<HeadToHeadMetricDatum> metrics;

  const HeadToHeadDeltaChart({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.leftColor,
    required this.rightColor,
    required this.metrics,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (metrics.isEmpty) {
      return Text(
        'No chart data available.',
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ResultsChartLegendChip(
              color: leftColor,
              label: leftLabel,
            ),
            ResultsChartLegendChip(
              color: rightColor,
              label: rightLabel,
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < metrics.length; i++) ...[
          if (i > 0)
            Divider(
              height: 18,
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          _HeadToHeadDeltaRow(
            datum: metrics[i],
            leftColor: leftColor,
            rightColor: rightColor,
          ),
        ],
      ],
    );
  }
}

class _HeadToHeadDeltaRow extends StatelessWidget {
  final HeadToHeadMetricDatum datum;
  final Color leftColor;
  final Color rightColor;

  const _HeadToHeadDeltaRow({
    required this.datum,
    required this.leftColor,
    required this.rightColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final leftScore = datum.higherIsBetter ? datum.leftValue : -datum.leftValue;
    final rightScore =
        datum.higherIsBetter ? datum.rightValue : -datum.rightValue;
    final diff = rightScore - leftScore;
    final denominator = math.max(
      1.0,
      math.max(leftScore.abs(), rightScore.abs()),
    );
    final normalized = (diff.abs() / denominator).clamp(0.0, 1.0);
    final emphasis = diff == 0
        ? 0.0
        : math.max(compact ? 0.08 : 0.1, math.pow(normalized, 0.8).toDouble());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          datum.label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        Row(
          children: [
            SizedBox(
              width: compact ? 60 : 78,
              child: Text(
                datum.leftText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: leftColor,
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final center = width / 2;
                    final barWidth = center * emphasis;
                    final trackColor = theme.colorScheme.surfaceContainerLow;
                    final centerColor =
                        theme.colorScheme.outline.withValues(alpha: 0.3);

                    return SizedBox(
                      height: compact ? 14 : 16,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: trackColor,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          Positioned(
                            left: center - 1,
                            top: 0,
                            bottom: 0,
                            width: 2,
                            child: ColoredBox(color: centerColor),
                          ),
                          if (diff < 0 && barWidth > 0)
                            Positioned(
                              left: center - barWidth,
                              top: 0,
                              bottom: 0,
                              width: barWidth,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: leftColor,
                                  borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                          if (diff > 0 && barWidth > 0)
                            Positioned(
                              left: center,
                              top: 0,
                              bottom: 0,
                              width: barWidth,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: rightColor,
                                  borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(999),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            SizedBox(
              width: compact ? 60 : 78,
              child: Text(
                datum.rightText,
                textAlign: TextAlign.right,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: rightColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ScatterPointDatum {
  final String label;
  final double x;
  final double y;
  final Color color;

  const ScatterPointDatum({
    required this.label,
    required this.x,
    required this.y,
    required this.color,
  });
}

class ScatterPlotChart extends StatelessWidget {
  final List<ScatterPointDatum> points;
  final String xAxisLabel;
  final String yAxisLabel;
  final String Function(num value) formatX;
  final String Function(num value) formatY;
  final String emptyLabel;

  const ScatterPlotChart({
    super.key,
    required this.points,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.formatX,
    required this.formatY,
    required this.emptyLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    if (points.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall,
      );
    }

    final minX = points.map((point) => point.x).reduce(math.min);
    final maxX = points.map((point) => point.x).reduce(math.max);
    final minY = points.map((point) => point.y).reduce(math.min);
    final maxY = points.map((point) => point.y).reduce(math.max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? 188 : 220,
          child: CustomPaint(
            painter: _ScatterPlotPainter(
              points: points,
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              axisColor: theme.colorScheme.outline.withValues(alpha: 0.55),
              gridColor: theme.colorScheme.outline.withValues(alpha: 0.12),
              textColor: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              showLabels: !compact,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        _ChartRangeSummary(
          leading: '$xAxisLabel: ${formatX(minX)} -> ${formatX(maxX)}',
          trailing: '$yAxisLabel: ${formatY(minY)} -> ${formatY(maxY)}',
        ),
      ],
    );
  }
}

class _ScatterPlotPainter extends CustomPainter {
  final List<ScatterPointDatum> points;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Color axisColor;
  final Color gridColor;
  final Color textColor;
  final bool showLabels;

  const _ScatterPlotPainter({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.axisColor,
    required this.gridColor,
    required this.textColor,
    required this.showLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 18.0;
    const rightPad = 14.0;
    const topPad = 12.0;
    const bottomPad = 22.0;
    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      math.max(0, size.width - leftPad - rightPad),
      math.max(0, size.height - topPad - bottomPad),
    );

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (int i = 0; i < 4; i++) {
      final dx = chartRect.left + (chartRect.width * (i / 3));
      final dy = chartRect.bottom - (chartRect.height * (i / 3));
      canvas.drawLine(
        Offset(dx, chartRect.top),
        Offset(dx, chartRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(chartRect.left, dy),
        Offset(chartRect.right, dy),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );

    for (final point in points) {
      final px = _scale(point.x, minX, maxX, chartRect.left, chartRect.right);
      final py = _scale(point.y, minY, maxY, chartRect.bottom, chartRect.top);
      final dotPaint = Paint()..color = point.color;
      canvas.drawCircle(Offset(px, py), 5, dotPaint);
      canvas.drawCircle(
        Offset(px, py),
        5,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      if (showLabels) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: point.label,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: 48);
        textPainter.paint(canvas, Offset(px + 6, py - 8));
      }
    }
  }

  static double _scale(
    double value,
    double min,
    double max,
    double start,
    double end,
  ) {
    if ((max - min).abs() < 1e-9) return (start + end) / 2;
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return start + ((end - start) * fraction);
  }

  @override
  bool shouldRepaint(covariant _ScatterPlotPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.textColor != textColor ||
        oldDelegate.showLabels != showLabels;
  }
}

class HistogramBinDatum {
  final int lowerBound;
  final int upperBound;
  final int count;
  final Color color;

  const HistogramBinDatum({
    required this.lowerBound,
    required this.upperBound,
    required this.count,
    required this.color,
  });
}

class HistogramBarChart extends StatelessWidget {
  final List<HistogramBinDatum> bins;
  final String xAxisLabel;
  final String yAxisLabel;
  final String emptyLabel;
  final String Function(num value) formatX;
  final String Function(num value) formatY;
  const HistogramBarChart({
    super.key,
    required this.bins,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.emptyLabel,
    required this.formatX,
    required this.formatY,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    if (bins.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall,
      );
    }

    final maxCount = bins.map((bin) => bin.count).fold<int>(0, math.max);
    final denominator = math.max(1, maxCount).toDouble();
    final labelStep = bins.length <= 6
        ? 1
        : math.max(1, (bins.length / (compact ? 3 : 4)).ceil());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? 188 : 220,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int index = 0; index < bins.length; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: FractionallySizedBox(
                            heightFactor: bins[index].count / denominator,
                            widthFactor: 1,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: bins[index].color,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8),
                                ),
                              ),
                              child: const SizedBox.expand(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        index % labelStep == 0 || index == bins.length - 1
                            ? formatX(bins[index].lowerBound)
                            : '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        _ChartRangeSummary(
          leading:
              '$xAxisLabel: ${formatX(bins.first.lowerBound)} -> ${formatX(bins.last.upperBound)}',
          trailing: '$yAxisLabel: ${formatY(0)} -> ${formatY(maxCount)}',
        ),
      ],
    );
  }
}

class SmallMultipleHistogramDatum {
  final String label;
  final String? summary;
  final List<HistogramBinDatum> bins;
  final Color accentColor;

  const SmallMultipleHistogramDatum({
    required this.label,
    required this.bins,
    required this.accentColor,
    this.summary,
  });
}

class SmallMultipleHistogramList extends StatelessWidget {
  final List<SmallMultipleHistogramDatum> items;
  final String emptyLabel;
  final String Function(num value) formatX;

  const SmallMultipleHistogramList({
    super.key,
    required this.items,
    required this.emptyLabel,
    required this.formatX,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (items.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          if (i > 0)
            Divider(
              height: 18,
              color: theme.colorScheme.outline.withValues(alpha: 0.12),
            ),
          _SmallMultipleHistogramRow(
            item: items[i],
            formatX: formatX,
          ),
        ],
      ],
    );
  }
}

class _SmallMultipleHistogramRow extends StatelessWidget {
  final SmallMultipleHistogramDatum item;
  final String Function(num value) formatX;

  const _SmallMultipleHistogramRow({
    required this.item,
    required this.formatX,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    if (item.bins.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          item.label,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    final maxCount = item.bins.map((bin) => bin.count).fold<int>(0, math.max);
    final denominator = math.max(1, maxCount).toDouble();
    final start = item.bins.first.lowerBound;
    final end = item.bins.last.upperBound;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                item.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            if (item.summary != null && item.summary!.trim().isNotEmpty)
              Text(
                item.summary!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        SizedBox(height: compact ? 8 : 10),
        SizedBox(
          height: compact ? 68 : 82,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (int index = 0; index < item.bins.length; index++) ...[
                if (index > 0) const SizedBox(width: 2),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      heightFactor: item.bins[index].count / denominator,
                      widthFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: item.accentColor.withValues(
                            alpha: 0.45 + (0.45 * (index / item.bins.length)),
                          ),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: compact ? 6 : 8),
        _ChartRangeSummary(
          leading: formatX(start),
          trailing: formatX(end),
        ),
      ],
    );
  }
}

class PieSliceDatum {
  final String label;
  final Color color;
  final double value;

  const PieSliceDatum({
    required this.label,
    required this.color,
    required this.value,
  });
}

class PieDonutChart extends StatelessWidget {
  final List<PieSliceDatum> slices;
  final String centerLabel;
  final String emptyLabel;
  final String Function(num value) formatValue;

  const PieDonutChart({
    super.key,
    required this.slices,
    required this.centerLabel,
    required this.emptyLabel,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final positiveSlices = slices
        .where((slice) => slice.value.isFinite && slice.value > 0)
        .toList(growable: false);
    final total = positiveSlices.fold<double>(
      0.0,
      (sum, slice) => sum + slice.value,
    );
    if (positiveSlices.isEmpty || total <= 0) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: SizedBox(
            width: compact ? 180 : 210,
            height: compact ? 180 : 210,
            child: CustomPaint(
              painter: _PieDonutPainter(
                slices: positiveSlices,
                total: total,
                holeFactor: 0.56,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerLabel,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatValue(total),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final slice in positiveSlices)
              ResultsChartLegendChip(
                color: slice.color,
                label: slice.label,
                value:
                    '${((slice.value / total) * 100).toStringAsFixed(1)}% | ${formatValue(slice.value)}',
              ),
          ],
        ),
      ],
    );
  }
}

class _PieDonutPainter extends CustomPainter {
  final List<PieSliceDatum> slices;
  final double total;
  final double holeFactor;

  const _PieDonutPainter({
    required this.slices,
    required this.total,
    required this.holeFactor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * (1.0 - holeFactor).clamp(0.08, 0.7);
    final ringRect = Rect.fromCircle(
      center: rect.center,
      radius: radius - (strokeWidth / 2),
    );
    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = (slice.value / total) * (2 * math.pi);
      final paint = Paint()
        ..color = slice.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
      canvas.drawArc(
        ringRect,
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PieDonutPainter oldDelegate) {
    return oldDelegate.slices != slices ||
        oldDelegate.total != total ||
        oldDelegate.holeFactor != holeFactor;
  }
}

class ProbabilityPointDatum {
  final int x;
  final double y;

  const ProbabilityPointDatum({
    required this.x,
    required this.y,
  });
}

class ProbabilityLineChart extends StatelessWidget {
  final List<ProbabilityPointDatum> points;
  final String xAxisLabel;
  final String yAxisLabel;
  final String emptyLabel;
  final String Function(num value) formatX;
  final String Function(num value) formatY;
  final int? targetX;
  final Color? targetColor;
  final Color lineColor;
  final Color fillColor;

  const ProbabilityLineChart({
    super.key,
    required this.points,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.emptyLabel,
    required this.formatX,
    required this.formatY,
    this.targetX,
    this.targetColor,
    required this.lineColor,
    required this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    if (points.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall,
      );
    }

    final minX = points.map((point) => point.x).reduce(math.min).toDouble();
    final maxX = points.map((point) => point.x).reduce(math.max).toDouble();
    final maxY = math.max(
      100.0,
      points.map((point) => point.y).reduce(math.max),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? 188 : 220,
          child: CustomPaint(
            painter: _ProbabilityLinePainter(
              points: points,
              minX: minX,
              maxX: maxX,
              maxY: maxY,
              axisColor: theme.colorScheme.outline.withValues(alpha: 0.55),
              gridColor: theme.colorScheme.outline.withValues(alpha: 0.12),
              lineColor: lineColor,
              fillColor: fillColor,
              targetX: targetX?.toDouble(),
              targetColor: targetColor ?? theme.colorScheme.tertiary,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        _ChartRangeSummary(
          leading: '$xAxisLabel: ${formatX(minX)} -> ${formatX(maxX)}',
          trailing: '$yAxisLabel: ${formatY(0)} -> ${formatY(maxY)}',
        ),
      ],
    );
  }
}

class LineChartDatum {
  final int x;
  final int y;
  final int? lower;
  final int? upper;

  const LineChartDatum({
    required this.x,
    required this.y,
    this.lower,
    this.upper,
  });
}

class ConvergenceLineChart extends StatelessWidget {
  final List<LineChartDatum> points;
  final String xAxisLabel;
  final String yAxisLabel;
  final String emptyLabel;
  final String Function(num value) formatX;
  final String Function(num value) formatY;
  final int meanValue;
  final int medianValue;
  final Color scorePointColor;
  final Color meanColor;
  final Color medianColor;
  final Color minColor;
  final Color maxColor;
  final Color bandColor;

  const ConvergenceLineChart({
    super.key,
    required this.points,
    required this.xAxisLabel,
    required this.yAxisLabel,
    required this.emptyLabel,
    required this.formatX,
    required this.formatY,
    required this.meanValue,
    required this.medianValue,
    required this.scorePointColor,
    required this.meanColor,
    required this.medianColor,
    required this.minColor,
    required this.maxColor,
    required this.bandColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 420;
    if (points.isEmpty) {
      return Text(
        emptyLabel,
        style: theme.textTheme.bodySmall,
      );
    }

    final minX = points.map((point) => point.x).reduce(math.min).toDouble();
    final maxX = points.map((point) => point.x).reduce(math.max).toDouble();
    final minY = points
        .map((point) => point.lower ?? point.y)
        .followedBy(<int>[meanValue, medianValue])
        .reduce(math.min)
        .toDouble();
    final maxY = points
        .map((point) => point.upper ?? point.y)
        .followedBy(<int>[meanValue, medianValue])
        .reduce(math.max)
        .toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: compact ? 188 : 220,
          child: CustomPaint(
            painter: _ConvergenceLinePainter(
              points: points,
              meanValue: meanValue.toDouble(),
              medianValue: medianValue.toDouble(),
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              axisColor: theme.colorScheme.outline.withValues(alpha: 0.55),
              gridColor: theme.colorScheme.outline.withValues(alpha: 0.12),
              scorePointColor: scorePointColor,
              meanColor: meanColor,
              medianColor: medianColor,
              minColor: minColor,
              maxColor: maxColor,
              bandColor: bandColor,
            ),
            child: const SizedBox.expand(),
          ),
        ),
        const SizedBox(height: 8),
        _ChartRangeSummary(
          leading: '$xAxisLabel: ${formatX(minX)} -> ${formatX(maxX)}',
          trailing: '$yAxisLabel: ${formatY(minY)} -> ${formatY(maxY)}',
        ),
      ],
    );
  }
}

class _ProbabilityLinePainter extends CustomPainter {
  final List<ProbabilityPointDatum> points;
  final double minX;
  final double maxX;
  final double maxY;
  final Color axisColor;
  final Color gridColor;
  final Color lineColor;
  final Color fillColor;
  final double? targetX;
  final Color targetColor;

  const _ProbabilityLinePainter({
    required this.points,
    required this.minX,
    required this.maxX,
    required this.maxY,
    required this.axisColor,
    required this.gridColor,
    required this.lineColor,
    required this.fillColor,
    required this.targetX,
    required this.targetColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 18.0;
    const rightPad = 12.0;
    const topPad = 12.0;
    const bottomPad = 22.0;
    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      math.max(0, size.width - leftPad - rightPad),
      math.max(0, size.height - topPad - bottomPad),
    );

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (int i = 0; i < 4; i++) {
      final dx = chartRect.left + (chartRect.width * (i / 3));
      final dy = chartRect.bottom - (chartRect.height * (i / 3));
      canvas.drawLine(
        Offset(dx, chartRect.top),
        Offset(dx, chartRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(chartRect.left, dy),
        Offset(chartRect.right, dy),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );

    if (targetX != null &&
        targetX! >= minX &&
        targetX! <= maxX &&
        (maxX - minX).abs() > 1e-9) {
      final dx = _scale(targetX!, minX, maxX, chartRect.left, chartRect.right);
      canvas.drawLine(
        Offset(dx, chartRect.top),
        Offset(dx, chartRect.bottom),
        Paint()
          ..color = targetColor
          ..strokeWidth = 1.6,
      );
    }

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final dx = _scale(
        point.x.toDouble(),
        minX,
        maxX,
        chartRect.left,
        chartRect.right,
      );
      final dy = _scale(
        point.y,
        0,
        maxY,
        chartRect.bottom,
        chartRect.top,
      );
      if (i == 0) {
        path.moveTo(dx, dy);
        fillPath.moveTo(dx, chartRect.bottom);
        fillPath.lineTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
        fillPath.lineTo(dx, dy);
      }
      canvas.drawCircle(
        Offset(dx, dy),
        3.5,
        Paint()..color = lineColor,
      );
    }

    final lastDx = _scale(
      points.last.x.toDouble(),
      minX,
      maxX,
      chartRect.left,
      chartRect.right,
    );
    fillPath
      ..lineTo(lastDx, chartRect.bottom)
      ..close();

    canvas.drawPath(fillPath, Paint()..color = fillColor);
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  static double _scale(
    double value,
    double min,
    double max,
    double start,
    double end,
  ) {
    if ((max - min).abs() < 1e-9) return (start + end) / 2;
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return start + ((end - start) * fraction);
  }

  @override
  bool shouldRepaint(covariant _ProbabilityLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.maxY != maxY ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.targetX != targetX ||
        oldDelegate.targetColor != targetColor;
  }
}

class _ConvergenceLinePainter extends CustomPainter {
  final List<LineChartDatum> points;
  final double meanValue;
  final double medianValue;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final Color axisColor;
  final Color gridColor;
  final Color scorePointColor;
  final Color meanColor;
  final Color medianColor;
  final Color minColor;
  final Color maxColor;
  final Color bandColor;

  const _ConvergenceLinePainter({
    required this.points,
    required this.meanValue,
    required this.medianValue,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.axisColor,
    required this.gridColor,
    required this.scorePointColor,
    required this.meanColor,
    required this.medianColor,
    required this.minColor,
    required this.maxColor,
    required this.bandColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 18.0;
    const rightPad = 12.0;
    const topPad = 12.0;
    const bottomPad = 22.0;
    final chartRect = Rect.fromLTWH(
      leftPad,
      topPad,
      math.max(0, size.width - leftPad - rightPad),
      math.max(0, size.height - topPad - bottomPad),
    );

    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.2;
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;
    final bandPoints = points
        .where((point) => point.lower != null && point.upper != null)
        .toList(growable: false);

    for (int i = 0; i < 4; i++) {
      final dx = chartRect.left + (chartRect.width * (i / 3));
      final dy = chartRect.bottom - (chartRect.height * (i / 3));
      canvas.drawLine(
        Offset(dx, chartRect.top),
        Offset(dx, chartRect.bottom),
        gridPaint,
      );
      canvas.drawLine(
        Offset(chartRect.left, dy),
        Offset(chartRect.right, dy),
        gridPaint,
      );
    }

    canvas.drawLine(
      Offset(chartRect.left, chartRect.bottom),
      Offset(chartRect.right, chartRect.bottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartRect.left, chartRect.top),
      Offset(chartRect.left, chartRect.bottom),
      axisPaint,
    );

    if (bandPoints.length >= 2) {
      final bandPath = Path();
      final minPath = Path();
      final maxPath = Path();
      for (int i = 0; i < bandPoints.length; i++) {
        final point = bandPoints[i];
        final dx = _scale(
          point.x.toDouble(),
          minX,
          maxX,
          chartRect.left,
          chartRect.right,
        );
        final dyUpper = _scale(
          point.upper!.toDouble(),
          minY,
          maxY,
          chartRect.bottom,
          chartRect.top,
        );
        if (i == 0) {
          bandPath.moveTo(dx, dyUpper);
          maxPath.moveTo(dx, dyUpper);
        } else {
          bandPath.lineTo(dx, dyUpper);
          maxPath.lineTo(dx, dyUpper);
        }
      }
      for (int i = bandPoints.length - 1; i >= 0; i--) {
        final point = bandPoints[i];
        final dx = _scale(
          point.x.toDouble(),
          minX,
          maxX,
          chartRect.left,
          chartRect.right,
        );
        final dyLower = _scale(
          point.lower!.toDouble(),
          minY,
          maxY,
          chartRect.bottom,
          chartRect.top,
        );
        bandPath.lineTo(dx, dyLower);
        if (i == bandPoints.length - 1) {
          minPath.moveTo(dx, dyLower);
        } else {
          minPath.lineTo(dx, dyLower);
        }
      }
      bandPath.close();
      canvas.drawPath(
        bandPath,
        Paint()..color = bandColor,
      );
      canvas.drawPath(
        maxPath,
        Paint()
          ..color = maxColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.drawPath(
        minPath,
        Paint()
          ..color = minColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
    }

    final meanDy = _scale(
      meanValue,
      minY,
      maxY,
      chartRect.bottom,
      chartRect.top,
    );
    final medianDy = _scale(
      medianValue,
      minY,
      maxY,
      chartRect.bottom,
      chartRect.top,
    );
    _drawDashedHorizontalLine(
      canvas,
      startX: chartRect.left,
      endX: chartRect.right,
      y: meanDy,
      color: meanColor,
    );
    _drawDashedHorizontalLine(
      canvas,
      startX: chartRect.left,
      endX: chartRect.right,
      y: medianDy,
      color: medianColor,
    );

    for (int i = 0; i < points.length; i++) {
      final point = points[i];
      final dx = _scale(
        point.x.toDouble(),
        minX,
        maxX,
        chartRect.left,
        chartRect.right,
      );
      final dy = _scale(
        point.y.toDouble(),
        minY,
        maxY,
        chartRect.bottom,
        chartRect.top,
      );
      canvas.drawCircle(
        Offset(dx, dy),
        3.8,
        Paint()..color = scorePointColor,
      );
      canvas.drawCircle(
        Offset(dx, dy),
        7.0,
        Paint()..color = scorePointColor.withValues(alpha: 0.12),
      );
    }
  }

  void _drawDashedHorizontalLine(
    Canvas canvas, {
    required double startX,
    required double endX,
    required double y,
    required Color color,
  }) {
    const dashWidth = 8.0;
    const gapWidth = 5.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    double x = startX;
    while (x < endX) {
      final next = math.min(x + dashWidth, endX);
      canvas.drawLine(Offset(x, y), Offset(next, y), paint);
      x = next + gapWidth;
    }
  }

  static double _scale(
    double value,
    double min,
    double max,
    double start,
    double end,
  ) {
    if ((max - min).abs() < 1e-9) return (start + end) / 2;
    final fraction = ((value - min) / (max - min)).clamp(0.0, 1.0);
    return start + ((end - start) * fraction);
  }

  @override
  bool shouldRepaint(covariant _ConvergenceLinePainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.meanValue != meanValue ||
        oldDelegate.medianValue != medianValue ||
        oldDelegate.minX != minX ||
        oldDelegate.maxX != maxX ||
        oldDelegate.minY != minY ||
        oldDelegate.maxY != maxY ||
        oldDelegate.axisColor != axisColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.scorePointColor != scorePointColor ||
        oldDelegate.meanColor != meanColor ||
        oldDelegate.medianColor != medianColor ||
        oldDelegate.minColor != minColor ||
        oldDelegate.maxColor != maxColor ||
        oldDelegate.bandColor != bandColor;
  }
}
