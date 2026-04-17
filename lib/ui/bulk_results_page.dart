import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/battle_outcome.dart';
import '../core/element_types.dart';
import '../core/engine/skill_catalog.dart';
import '../core/sim_types.dart';
import '../data/bulk_results_models.dart';
import 'results_charts.dart';
import 'results_page.dart';
import 'table_widgets.dart';

class BulkResultsPage extends StatefulWidget {
  final BulkSimulationBatchResult batch;
  final Map<String, String> labels;
  final bool isPremium;
  final int milestoneTargetPoints;
  final int startEnergies;
  final int freeRaidEnergies;

  const BulkResultsPage({
    super.key,
    required this.batch,
    required this.labels,
    required this.isPremium,
    required this.milestoneTargetPoints,
    required this.startEnergies,
    required this.freeRaidEnergies,
  });

  @override
  State<BulkResultsPage> createState() => _BulkResultsPageState();
}

class _BulkResultsPageState extends State<BulkResultsPage> {
  late final PageController _controller;
  int _pageIndex = 0;
  int? _compareLeftSlot;
  int? _compareRightSlot;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
    _seedCompareSelection();
  }

  @override
  void didUpdateWidget(covariant BulkResultsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.batch, widget.batch)) {
      _seedCompareSelection();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _seedCompareSelection() {
    final rows = widget.batch.comparisonRows;
    _compareLeftSlot = rows.isNotEmpty ? rows.first.slot : null;
    _compareRightSlot = rows.length > 1 ? rows[1].slot : _compareLeftSlot;
  }

  void _updateCompareLeftSlot(int slot) {
    setState(() {
      if (_compareRightSlot == slot) {
        _compareRightSlot = _compareLeftSlot;
      }
      _compareLeftSlot = slot;
      _normalizeCompareSelection();
    });
  }

  void _updateCompareRightSlot(int slot) {
    setState(() {
      if (_compareLeftSlot == slot) {
        _compareLeftSlot = _compareRightSlot;
      }
      _compareRightSlot = slot;
      _normalizeCompareSelection();
    });
  }

  void _normalizeCompareSelection() {
    final slots = widget.batch.comparisonRows.map((row) => row.slot).toList();
    if (slots.isEmpty) {
      _compareLeftSlot = null;
      _compareRightSlot = null;
      return;
    }
    _compareLeftSlot =
        slots.contains(_compareLeftSlot) ? _compareLeftSlot : slots.first;
    _compareRightSlot = slots.contains(_compareRightSlot)
        ? _compareRightSlot
        : _compareLeftSlot;
    if (_compareLeftSlot == _compareRightSlot && slots.length > 1) {
      _compareRightSlot = slots.firstWhere((slot) => slot != _compareLeftSlot,
          orElse: () => slots.first);
    }
  }

  String t(String key, String fallback) => widget.labels[key] ?? fallback;

  String _slotLabel(int slot, [String? slotName]) {
    final base = '${t('setups.slot', 'Slot')} $slot';
    var name = slotName?.trim() ?? '';
    if (name.isEmpty) return base;
    if (name.length > 18) {
      name = '${name.substring(0, 18).trimRight()}...';
    }
    return '$base · $name';
  }

  List<_BulkPageItem> _pages() {
    final runs = widget.batch.runsBySlot;
    return <_BulkPageItem>[
      for (final run in runs)
        _BulkPageItem(
          label: _slotLabel(run.slot, run.slotName),
          child: ResultsPage(
            pre: run.pre,
            knightIds: _activeKnightIds(run),
            stats: run.stats,
            labels: widget.labels,
            isPremium: widget.isPremium,
            debugEnabled: false,
            cycloneUseGemsForSpecials:
                run.setup.modeEffects.cycloneUseGemsForSpecials,
            milestoneTargetPoints: widget.milestoneTargetPoints,
            startEnergies: widget.startEnergies,
            freeRaidEnergies: widget.freeRaidEnergies,
            petElement1Id: run.setup.pet.element1.id,
            petElement2Id: run.setup.pet.element2?.id,
            knightElementPairs: _activeKnightElements(run),
            selectedSkill1: run.setup.pet.importedCompendium?.selectedSkill1 ??
                run.setup.pet.manualSkill1,
            selectedSkill2: run.setup.pet.importedCompendium?.selectedSkill2 ??
                run.setup.pet.manualSkill2,
            importedPet: run.setup.pet.importedCompendium,
            petEffects: run.setup.pet.resolvedEffects,
            elixirs: const [],
            shatter: run.shatter,
          ),
        ),
      _BulkPageItem(
        label: t('results.bulk.compare_tab', 'Compare'),
        child: _BulkCompareScaffold(
          rows: widget.batch.comparisonRows,
          labels: widget.labels,
          isPremium: widget.isPremium,
          milestoneTargetPoints: widget.milestoneTargetPoints,
          compareLeftSlot: _compareLeftSlot,
          compareRightSlot: _compareRightSlot,
          onSelectCompareLeft: _updateCompareLeftSlot,
          onSelectCompareRight: _updateCompareRightSlot,
        ),
      ),
    ];
  }

  List<String> _activeKnightIds(BulkSimulationRunResult run) {
    final ids = <String>[];
    for (int i = 0; i < run.setup.knights.length; i++) {
      if (run.setup.knights[i].active) ids.add('K${i + 1}');
    }
    if (ids.isEmpty) {
      // Defensive fallback; validation should already prevent this.
      return const <String>['K1'];
    }
    return ids;
  }

  List<List<String>> _activeKnightElements(BulkSimulationRunResult run) {
    final out = <List<String>>[];
    for (int i = 0; i < run.setup.knights.length; i++) {
      final k = run.setup.knights[i];
      if (!k.active) continue;
      out.add(<String>[k.elements[0].id, k.elements[1].id]);
    }
    if (out.isEmpty && run.setup.knights.isNotEmpty) {
      final k = run.setup.knights.first;
      out.add(<String>[k.elements[0].id, k.elements[1].id]);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final pages = _pages();
    final currentLabel = (_pageIndex >= 0 && _pageIndex < pages.length)
        ? pages[_pageIndex].label
        : '';

    return Stack(
      children: [
        PageView(
          controller: _controller,
          onPageChanged: (i) => setState(() => _pageIndex = i),
          children: [for (final p in pages) p.child],
        ),
        IgnorePointer(
          child: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: Text(
                  '${t('results.bulk.title', 'Bulk Results')}  •  $currentLabel  '
                  '(${_pageIndex + 1}/${pages.length})',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BulkPageItem {
  final String label;
  final Widget child;

  const _BulkPageItem({
    required this.label,
    required this.child,
  });
}

class _BulkThresholdChipDatum {
  final Color color;
  final String label;
  final String value;

  const _BulkThresholdChipDatum({
    required this.color,
    required this.label,
    required this.value,
  });
}

class _BulkCompareScaffold extends StatelessWidget {
  static const Color _headToHeadLeftColor = Color(0xFF2563EB);
  static const Color _headToHeadRightColor = Color(0xFF10B981);

  final List<BulkComparisonRow> rows;
  final Map<String, String> labels;
  final bool isPremium;
  final int milestoneTargetPoints;
  final int? compareLeftSlot;
  final int? compareRightSlot;
  final ValueChanged<int> onSelectCompareLeft;
  final ValueChanged<int> onSelectCompareRight;

  const _BulkCompareScaffold({
    required this.rows,
    required this.labels,
    required this.isPremium,
    required this.milestoneTargetPoints,
    required this.compareLeftSlot,
    required this.compareRightSlot,
    required this.onSelectCompareLeft,
    required this.onSelectCompareRight,
  });

  String t(String key, String fallback) => labels[key] ?? fallback;

  String _slotLabel(BulkComparisonRow row) {
    final base = '${t('setups.slot', 'Slot')} ${row.slot}';
    final name = row.slotName?.trim() ?? '';
    if (name.isEmpty) return base;
    return '$base · $name';
  }

  String _fmtInt(num n) {
    final s = n.round().toString();
    final neg = s.startsWith('-');
    final raw = neg ? s.substring(1) : s;
    final buf = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final idxFromEnd = raw.length - i;
      buf.write(raw[i]);
      final isGroup = idxFromEnd > 1 && (idxFromEnd - 1) % 3 == 0;
      if (isGroup) buf.write(',');
    }
    return neg ? '-$buf' : buf.toString();
  }

  String _fmtDouble(double? v, {int decimals = 2}) {
    if (v == null || !v.isFinite) return '-';
    return v.toStringAsFixed(decimals);
  }

  String _modeLabel(String bossMode) =>
      bossMode == 'blitz' ? t('blitz', 'Blitz') : t('raid', 'Raid');

  String _fightLabel(BulkComparisonRow row) {
    final names = row.pet.resolvedEffects
        .map(
          (effect) => BattleSkillCatalog.displayNameForId(
            effect.canonicalEffectId,
            fallback: effect.canonicalName.isEmpty
                ? effect.sourceSkillName
                : effect.canonicalName,
          ),
        )
        .where((name) => name.trim().isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (names.isEmpty) return row.pet.skillUsage.shortLabel();
    return names.join(' + ');
  }

  String _fmtPercent(num value) {
    final v = value.toDouble();
    if (v >= 99.95 || v == 0 || (v - v.roundToDouble()).abs() < 0.05) {
      return '${v.round()}%';
    }
    if (v >= 10) return '${v.toStringAsFixed(1)}%';
    return '${v.toStringAsFixed(2)}%';
  }

  double? _targetChancePercent(BulkComparisonRow row) {
    final histogram = row.series?.histogram;
    final totalRuns = row.series?.totalRuns ?? 0;
    if (histogram == null || histogram.bins.isEmpty || totalRuns <= 0) {
      return null;
    }
    double matching = 0;
    for (final bin in histogram.bins) {
      final lower = bin.lowerBound;
      final upper = bin.upperBound;
      if (milestoneTargetPoints <= lower) {
        matching += bin.count;
        continue;
      }
      if (milestoneTargetPoints > upper) continue;
      final span = (upper - lower + 1).clamp(1, 2000000000);
      final overlap = (upper - milestoneTargetPoints + 1).clamp(0, span);
      matching += bin.count * (overlap / span);
    }
    return ((matching / totalRuns) * 100).clamp(0.0, 100.0);
  }

  List<BarChartSeries> _bulkTargetChanceSeries() {
    final values = <double>[];
    for (final row in rows) {
      final chance = _targetChancePercent(row);
      values.add(chance ?? 0);
    }
    return <BarChartSeries>[
      BarChartSeries(
        label: t('results.charts.bulk_target.series', 'Target chance'),
        color: const Color(0xFF10B981),
        values: values,
      ),
    ];
  }

  double? _approxHistogramExceedancePercent(
    SimulationHistogram histogram,
    int threshold,
    int totalRuns,
  ) {
    if (totalRuns <= 0 || histogram.bins.isEmpty) return null;
    double matching = 0;
    for (final bin in histogram.bins) {
      final lower = bin.lowerBound;
      final upper = bin.upperBound;
      if (threshold <= lower) {
        matching += bin.count;
        continue;
      }
      if (threshold > upper) continue;

      final span = math.max(1, upper - lower + 1);
      final overlap = (upper - threshold + 1).clamp(0, span);
      matching += bin.count * (overlap / span);
    }
    return ((matching / totalRuns) * 100).clamp(0.0, 100.0);
  }

  bool get _hasBulkTargetChance =>
      rows.any((row) => _targetChancePercent(row) != null);

  bool get _hasBulkThresholdChips =>
      rows.any((row) => _thresholdChipsForRow(row).isNotEmpty);

  bool get _hasBulkDistributionSmallMultiples =>
      rows.length >= 2 &&
      rows.length <= 5 &&
      rows.every(
        (row) =>
            row.series?.histogram != null &&
            row.series!.histogram!.bins.isNotEmpty &&
            row.series!.totalRuns > 0,
      );

  bool get _hasBulkPercentileComparison => rows.every(
        (row) =>
            row.series?.histogram != null &&
            row.series!.histogram!.bins.isNotEmpty &&
            row.series!.totalRuns > 0,
      );

  bool _isFinitePositive(double? value) =>
      value != null && value.isFinite && value > 0;

  bool get _hasBulkRunTimeComparison =>
      isPremium && rows.every((row) => _isFinitePositive(row.meanRunSeconds));

  bool get _hasBulkLowestSurvivalComparison =>
      isPremium &&
      rows.every((row) => _isFinitePositive(row.lowestKnightSurvivalSeconds));

  bool get _hasBulkPointsPerSecondComparison =>
      isPremium && rows.every((row) => _isFinitePositive(row.pointsPerSecond));

  bool get _hasBulkFrontierComparison => _hasBulkPointsPerSecondComparison;

  List<BarChartSeries> _bulkTimingSeries() {
    final out = <BarChartSeries>[];
    if (_hasBulkRunTimeComparison) {
      out.add(
        BarChartSeries(
          label: t('results.bulk.run_time_mean', 'Run time mean (s)'),
          color: const Color(0xFF3B82F6),
          values: [
            for (final row in rows) row.meanRunSeconds!,
          ],
        ),
      );
    }
    if (_hasBulkLowestSurvivalComparison) {
      out.add(
        BarChartSeries(
          label: t(
            'results.charts.bulk_timing.lowest_survival',
            'Lowest knight survival (s)',
          ),
          color: const Color(0xFFF59E0B),
          values: [
            for (final row in rows) row.lowestKnightSurvivalSeconds!,
          ],
        ),
      );
    }
    return out;
  }

  List<BarChartSeries> _bulkPointsPerSecondSeries() {
    if (!_hasBulkPointsPerSecondComparison) return const <BarChartSeries>[];
    return <BarChartSeries>[
      BarChartSeries(
        label: t('results.bulk.points_per_second', 'Points/second'),
        color: const Color(0xFF10B981),
        values: [
          for (final row in rows) row.pointsPerSecond!,
        ],
      ),
    ];
  }

  List<BarChartSeries> _bulkRangeSeries() {
    return <BarChartSeries>[
      BarChartSeries(
        label: t('min', 'Min'),
        color: const Color(0xFF3B82F6),
        values: [for (final row in rows) row.minPoints.toDouble()],
      ),
      BarChartSeries(
        label: t('median', 'Median'),
        color: const Color(0xFFF59E0B),
        values: [for (final row in rows) row.medianPoints.toDouble()],
      ),
      BarChartSeries(
        label: t('mean', 'Mean'),
        color: const Color(0xFF10B981),
        values: [for (final row in rows) row.meanPoints.toDouble()],
      ),
      BarChartSeries(
        label: t('max', 'Max'),
        color: const Color(0xFFEF4444),
        values: [for (final row in rows) row.maxPoints.toDouble()],
      ),
    ];
  }

  int _approxHistogramPercentileScore(
    SimulationHistogram histogram,
    int totalRuns,
    double percentile,
  ) {
    if (totalRuns <= 0 || histogram.bins.isEmpty) return 0;
    final bins = List<SimulationHistogramBin>.from(histogram.bins)
      ..sort((a, b) => a.lowerBound.compareTo(b.lowerBound));
    final targetRank = ((percentile.clamp(0.0, 100.0) / 100.0) * totalRuns)
        .clamp(1.0, totalRuns.toDouble());
    var cumulative = 0.0;
    for (final bin in bins) {
      final next = cumulative + bin.count;
      if (next >= targetRank) {
        final span = math.max(1, bin.upperBound - bin.lowerBound + 1);
        final insideRank =
            (targetRank - cumulative).clamp(0.0, bin.count.toDouble());
        final fraction = bin.count == 0 ? 0.0 : insideRank / bin.count;
        return (bin.lowerBound + (span * fraction)).round();
      }
      cumulative = next;
    }
    return bins.last.upperBound;
  }

  List<BarChartSeries> _bulkPercentileSeries() {
    return <BarChartSeries>[
      BarChartSeries(
        label: t('results.charts.percentile.p10', 'P10'),
        color: const Color(0xFF2563EB),
        values: [
          for (final row in rows)
            _approxHistogramPercentileScore(
              row.series!.histogram!,
              row.series!.totalRuns,
              10,
            ).toDouble(),
        ],
      ),
      BarChartSeries(
        label: t('results.charts.percentile.p50', 'P50'),
        color: const Color(0xFF7C3AED),
        values: [
          for (final row in rows)
            _approxHistogramPercentileScore(
              row.series!.histogram!,
              row.series!.totalRuns,
              50,
            ).toDouble(),
        ],
      ),
      BarChartSeries(
        label: t('results.charts.percentile.p90', 'P90'),
        color: const Color(0xFFEF4444),
        values: [
          for (final row in rows)
            _approxHistogramPercentileScore(
              row.series!.histogram!,
              row.series!.totalRuns,
              90,
            ).toDouble(),
        ],
      ),
    ];
  }

  int? _histogramPercentileScore(BulkComparisonRow row, double percentile) {
    final histogram = row.series?.histogram;
    final totalRuns = row.series?.totalRuns ?? 0;
    if (histogram == null || histogram.bins.isEmpty || totalRuns <= 0) {
      return null;
    }
    return _approxHistogramPercentileScore(histogram, totalRuns, percentile);
  }

  List<HeadToHeadMetricDatum> _headToHeadMetrics() {
    final selectedRows = _selectedHeadToHeadRows;
    if (selectedRows.length != 2) return const <HeadToHeadMetricDatum>[];
    final left = selectedRows[0];
    final right = selectedRows[1];
    final metrics = <HeadToHeadMetricDatum>[
      HeadToHeadMetricDatum(
        label: t('mean', 'Mean'),
        leftValue: left.meanPoints.toDouble(),
        rightValue: right.meanPoints.toDouble(),
        leftText: _fmtInt(left.meanPoints),
        rightText: _fmtInt(right.meanPoints),
      ),
    ];

    final leftP90 = _histogramPercentileScore(left, 90);
    final rightP90 = _histogramPercentileScore(right, 90);
    if (leftP90 != null && rightP90 != null) {
      metrics.add(
        HeadToHeadMetricDatum(
          label: t('results.charts.bulk_head_to_head.metric.p90', 'P90'),
          leftValue: leftP90.toDouble(),
          rightValue: rightP90.toDouble(),
          leftText: _fmtInt(leftP90),
          rightText: _fmtInt(rightP90),
        ),
      );
    }

    final leftTarget = _targetChancePercent(left);
    final rightTarget = _targetChancePercent(right);
    if (leftTarget != null && rightTarget != null) {
      metrics.add(
        HeadToHeadMetricDatum(
          label: t(
            'results.charts.bulk_head_to_head.metric.target_chance',
            'Target chance',
          ),
          leftValue: leftTarget,
          rightValue: rightTarget,
          leftText: _fmtPercent(leftTarget),
          rightText: _fmtPercent(rightTarget),
        ),
      );
    }

    final leftPps = left.pointsPerSecond;
    final rightPps = right.pointsPerSecond;
    if (isPremium &&
        leftPps != null &&
        rightPps != null &&
        leftPps.isFinite &&
        rightPps.isFinite) {
      metrics.add(
        HeadToHeadMetricDatum(
          label: t(
            'results.charts.bulk_head_to_head.metric.points_per_second',
            'Points/second',
          ),
          leftValue: leftPps,
          rightValue: rightPps,
          leftText: _fmtDouble(leftPps),
          rightText: _fmtDouble(rightPps),
        ),
      );
    }

    final leftSurvival = left.lowestKnightSurvivalSeconds;
    final rightSurvival = right.lowestKnightSurvivalSeconds;
    if (isPremium &&
        leftSurvival != null &&
        rightSurvival != null &&
        leftSurvival.isFinite &&
        rightSurvival.isFinite) {
      metrics.add(
        HeadToHeadMetricDatum(
          label: t(
            'results.charts.bulk_head_to_head.metric.lowest_survival',
            'Lowest survival',
          ),
          leftValue: leftSurvival,
          rightValue: rightSurvival,
          leftText: '${_fmtDouble(leftSurvival)}s',
          rightText: '${_fmtDouble(rightSurvival)}s',
        ),
      );
    }

    return metrics;
  }

  BulkComparisonRow? _rowBySlot(int? slot) {
    if (slot == null) return null;
    for (final row in rows) {
      if (row.slot == slot) return row;
    }
    return null;
  }

  List<BulkComparisonRow> get _selectedHeadToHeadRows {
    final left = _rowBySlot(compareLeftSlot);
    final right = _rowBySlot(compareRightSlot);
    if (left == null || right == null || left.slot == right.slot) {
      return const <BulkComparisonRow>[];
    }
    return <BulkComparisonRow>[left, right];
  }

  List<_BulkThresholdChipDatum> _thresholdChipsForRow(BulkComparisonRow row) {
    final histogram = row.series?.histogram;
    final totalRuns = row.series?.totalRuns ?? 0;
    if (histogram == null || histogram.bins.isEmpty || totalRuns <= 0) {
      return const <_BulkThresholdChipDatum>[];
    }

    final p75 = _approxHistogramPercentileScore(histogram, totalRuns, 75);
    final p90 = _approxHistogramPercentileScore(histogram, totalRuns, 90);

    return <_BulkThresholdChipDatum>[
      _BulkThresholdChipDatum(
        color: const Color(0xFFEF4444),
        label: t(
          'results.charts.exceedance.target',
          'Selected score',
        ),
        value: _fmtPercent(
          _approxHistogramExceedancePercent(
                histogram,
                milestoneTargetPoints,
                totalRuns,
              ) ??
              0,
        ),
      ),
      _BulkThresholdChipDatum(
        color: const Color(0xFF10B981),
        label: t('results.charts.target.mean', 'Mean'),
        value: _fmtPercent(
          _approxHistogramExceedancePercent(
                histogram,
                row.meanPoints,
                totalRuns,
              ) ??
              0,
        ),
      ),
      _BulkThresholdChipDatum(
        color: const Color(0xFFF59E0B),
        label: t('results.charts.target.p75', 'P75'),
        value: _fmtPercent(
          _approxHistogramExceedancePercent(
                histogram,
                p75,
                totalRuns,
              ) ??
              0,
        ),
      ),
      _BulkThresholdChipDatum(
        color: const Color(0xFF7C3AED),
        label: t('results.charts.target.p90', 'P90'),
        value: _fmtPercent(
          _approxHistogramExceedancePercent(
                histogram,
                p90,
                totalRuns,
              ) ??
              0,
        ),
      ),
    ];
  }

  String _elementLabel(String id) {
    return switch (id) {
      'fire' => t('element.fire', 'Fire'),
      'spirit' => t('element.spirit', 'Spirit'),
      'earth' => t('element.earth', 'Earth'),
      'air' => t('element.air', 'Air'),
      'water' => t('element.water', 'Water'),
      'starmetal' => t('element.starmetal', 'Starmetal'),
      _ => id,
    };
  }

  String _petElement2Label(BulkComparisonRow row) {
    final e2 = row.pet.element2;
    if (e2 == null) return t('pet.element.empty', 'Empty');
    return _elementLabel(e2.id);
  }

  String _knightSummary(BulkComparisonRow row, int idx) {
    if (idx < 0 || idx >= row.knights.length) return '-';
    final k = row.knights[idx];
    return 'ATK ${_fmtInt(k.atk)} | DEF ${_fmtInt(k.def)} | HP ${_fmtInt(k.hp)} | '
        '${_elementLabel(k.elements[0].id)}/${_elementLabel(k.elements[1].id)} | '
        '${t('stun_chance', 'Stun Chance')} ${k.stun.toStringAsFixed(0)}%';
  }

  Widget _kvLine(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotSubCard(BuildContext context, {required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: child,
    );
  }

  Widget _compactSummaryCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _slotSubCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slotLabel(rows[i]),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                _kvLine(
                    context, t('mode', 'Mode'), _modeLabel(rows[i].bossMode)),
                _kvLine(context, t('boss.level', 'Boss Level'),
                    'L${rows[i].bossLevel}'),
                _kvLine(
                  context,
                  t('pet.skill_loadout', 'Pet loadout'),
                  _fightLabel(rows[i]),
                ),
                _kvLine(
                    context, t('mean', 'mean'), _fmtInt(rows[i].meanPoints)),
                _kvLine(
                  context,
                  t('results.bulk.target_chance', 'Target chance'),
                  _targetChancePercent(rows[i]) == null
                      ? '-'
                      : _fmtPercent(_targetChancePercent(rows[i])!),
                ),
                _kvLine(
                  context,
                  t('expected_range', 'Expected range (+/-8%)'),
                  '${_fmtInt(rows[i].expectedRange.lower)} - ${_fmtInt(rows[i].expectedRange.upper)}',
                ),
                if (isPremium)
                  _kvLine(
                    context,
                    t('results.bulk.run_time_mean', 'Run time mean (s)'),
                    _fmtDouble(rows[i].meanRunSeconds),
                  ),
                if (isPremium)
                  _kvLine(
                    context,
                    t('results.bulk.points_per_second', 'Points/second'),
                    _fmtDouble(rows[i].pointsPerSecond),
                  ),
              ],
            ),
          ),
          if (i != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<ScatterPointDatum> _bulkFrontierPoints() {
    if (!_hasBulkFrontierComparison) return const <ScatterPointDatum>[];
    const palette = <Color>[
      Color(0xFF3B82F6),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
    ];
    final points = <ScatterPointDatum>[];
    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final pps = row.pointsPerSecond;
      if (pps == null || !pps.isFinite || pps <= 0) continue;
      points.add(
        ScatterPointDatum(
          label: 'S${row.slot}',
          x: row.meanPoints.toDouble(),
          y: pps,
          color: palette[i % palette.length],
        ),
      );
    }
    return points;
  }

  Widget _compactPetCards(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _slotSubCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slotLabel(rows[i]),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                _kvLine(
                    context, t('pet.atk', 'Pet ATK'), _fmtInt(rows[i].pet.atk)),
                _kvLine(
                  context,
                  t('results.pet.normal_damage', 'Normal damage'),
                  _fmtInt(rows[i].petNormalDamage),
                ),
                _kvLine(
                  context,
                  t('results.pet.crit_damage', 'Crit damage'),
                  _fmtInt(rows[i].petCritDamage),
                ),
                _kvLine(
                  context,
                  t('results.pet.element_1', 'Element 1'),
                  _elementLabel(rows[i].pet.element1.id),
                ),
                _kvLine(
                  context,
                  t('results.pet.element_2', 'Element 2'),
                  _petElement2Label(rows[i]),
                ),
              ],
            ),
          ),
          if (i != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _compactKnightsCards(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int r = 0; r < rows.length; r++) ...[
          _slotSubCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slotLabel(rows[r]),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                for (int k = 0; k < rows[r].knights.length; k++) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: theme.colorScheme.surfaceContainerLow,
                      border: Border.all(
                        color:
                            theme.colorScheme.outline.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'K#${k + 1}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _kvLine(
                          context,
                          t('atk', 'ATK'),
                          _fmtInt(rows[r].knights[k].atk),
                        ),
                        _kvLine(
                          context,
                          t('def', 'DEF'),
                          _fmtInt(rows[r].knights[k].def),
                        ),
                        _kvLine(
                          context,
                          t('hp', 'HP'),
                          _fmtInt(rows[r].knights[k].hp),
                        ),
                        _kvLine(
                          context,
                          t('elements', 'Elements'),
                          '${_elementLabel(rows[r].knights[k].elements[0].id)}/${_elementLabel(rows[r].knights[k].elements[1].id)}',
                        ),
                        _kvLine(
                          context,
                          t('stun_chance', 'Stun Chance'),
                          '${rows[r].knights[k].stun.toStringAsFixed(0)}%',
                        ),
                      ],
                    ),
                  ),
                  if (k != rows[r].knights.length - 1)
                    const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          if (r != rows.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _bulkThresholdCards(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _slotSubCard(
            context,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _slotLabel(rows[i]),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final chip in _thresholdChipsForRow(rows[i]))
                      ResultsChartLegendChip(
                        color: chip.color,
                        label: chip.label,
                        value: chip.value,
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (i != rows.length - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<SmallMultipleHistogramDatum> _bulkDistributionItems() {
    const palette = <Color>[
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFFEF4444),
      Color(0xFF8B5CF6),
    ];
    return [
      for (int i = 0; i < rows.length; i++)
        SmallMultipleHistogramDatum(
          label: _slotLabel(rows[i]),
          summary:
              '${t('mean', 'Mean')} ${_fmtInt(rows[i].meanPoints)} | ${t('results.charts.target.p90', 'P90')} ${_fmtInt(_histogramPercentileScore(rows[i], 90) ?? rows[i].maxPoints)}',
          accentColor: palette[i % palette.length],
          bins: [
            for (final bin in List<SimulationHistogramBin>.from(
              rows[i].series!.histogram!.bins,
            )..sort((a, b) => a.lowerBound.compareTo(b.lowerBound)))
              HistogramBinDatum(
                lowerBound: bin.lowerBound,
                upperBound: bin.upperBound,
                count: bin.count,
                color: palette[i % palette.length],
              ),
          ],
        ),
    ];
  }

  Widget _headToHeadSelectors(BuildContext context) {
    final theme = Theme.of(context);
    return _slotSubCard(
      context,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(
              'results.charts.bulk_head_to_head.selectors',
              'Choose the two setups to compare directly.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('results.bulk.compare.left_selector'),
                  initialValue: compareLeftSlot,
                  decoration: InputDecoration(
                    labelText: t(
                      'results.charts.bulk_head_to_head.left',
                      'Setup A',
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final row in rows)
                      DropdownMenuItem<int>(
                        value: row.slot,
                        child: Text(_slotLabel(row)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSelectCompareLeft(value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<int>(
                  key: const ValueKey('results.bulk.compare.right_selector'),
                  initialValue: compareRightSlot,
                  decoration: InputDecoration(
                    labelText: t(
                      'results.charts.bulk_head_to_head.right',
                      'Setup B',
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    for (final row in rows)
                      DropdownMenuItem<int>(
                        value: row.slot,
                        child: Text(_slotLabel(row)),
                      ),
                  ],
                  onChanged: (value) {
                    if (value != null) onSelectCompareRight(value);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final compact = screenW < 640;
    final frontierPoints = _bulkFrontierPoints();
    final headToHeadMetrics = _headToHeadMetrics();
    final selectedHeadToHeadRows = _selectedHeadToHeadRows;
    return Scaffold(
      appBar: AppBar(
        title: Text(t('results.bulk.compare_title', 'Bulk Results Comparison')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          SectionCard(
            title: t('results.bulk.summary_section', 'Summary'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t(
                    'results.bulk.swipe_hint',
                    'Swipe left/right to move across setup result pages and this comparison page.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (_hasBulkFrontierComparison) ...[
                  const SizedBox(height: 12),
                  ResultsChartCard(
                    key: const ValueKey('results.bulk.chart.frontier'),
                    title: t(
                        'results.charts.bulk_frontier.title', 'Bulk Frontier'),
                    subtitle: t(
                      'results.charts.bulk_frontier.subtitle',
                      'Mean points versus points/second across saved setups.',
                    ),
                    helpTooltip: t(
                      'results.charts.bulk_frontier.help',
                      'Each point is one saved setup. Farther right means higher average score, higher up means better score efficiency over time.',
                    ),
                    legend: [
                      for (final point in frontierPoints)
                        ResultsChartLegendChip(
                          color: point.color,
                          label: point.label,
                        ),
                    ],
                    child: ScatterPlotChart(
                      points: frontierPoints,
                      xAxisLabel: t('mean', 'Mean'),
                      yAxisLabel: t(
                        'results.bulk.points_per_second',
                        'Points/second',
                      ),
                      formatX: _fmtInt,
                      formatY: (value) => _fmtDouble(value.toDouble()),
                      emptyLabel: t(
                        'results.charts.empty',
                        'No chart data available.',
                      ),
                    ),
                  ),
                ],
                if (_hasBulkRunTimeComparison ||
                    _hasBulkLowestSurvivalComparison) ...[
                  const SizedBox(height: 12),
                  ResultsChartCard(
                    key: const ValueKey('results.bulk.chart.timing'),
                    title: t(
                      'results.charts.bulk_timing.title',
                      'Bulk Timing Snapshot',
                    ),
                    subtitle: t(
                      'results.charts.bulk_timing.subtitle',
                      'Compares average run duration and defensive survivability across setups.',
                    ),
                    helpTooltip: t(
                      'results.charts.bulk_timing.help',
                      'Run time mean estimates total fight length. Lowest knight survival highlights the first defensive collapse point. Looking at both together helps identify stable and fast setups.',
                    ),
                    legend: [
                      if (_hasBulkRunTimeComparison)
                        ResultsChartLegendChip(
                          color: const Color(0xFF3B82F6),
                          label: t(
                            'results.bulk.run_time_mean',
                            'Run time mean (s)',
                          ),
                        ),
                      if (_hasBulkLowestSurvivalComparison)
                        ResultsChartLegendChip(
                          color: const Color(0xFFF59E0B),
                          label: t(
                            'results.charts.bulk_timing.lowest_survival',
                            'Lowest knight survival (s)',
                          ),
                        ),
                    ],
                    child: GroupedHorizontalBarChart(
                      categories: [
                        for (final row in rows) _slotLabel(row),
                      ],
                      series: _bulkTimingSeries(),
                      formatValue: (value) => _fmtDouble(value.toDouble()),
                    ),
                  ),
                ],
                if (_hasBulkPointsPerSecondComparison) ...[
                  const SizedBox(height: 12),
                  ResultsChartCard(
                    key: const ValueKey('results.bulk.chart.time_efficiency'),
                    title: t(
                      'results.charts.bulk_time_efficiency.title',
                      'Bulk Time Efficiency',
                    ),
                    subtitle: t(
                      'results.charts.bulk_time_efficiency.subtitle',
                      'Ranks setups by points generated per second.',
                    ),
                    helpTooltip: t(
                      'results.charts.bulk_time_efficiency.help',
                      'Higher values indicate faster score generation in practice. Use this alongside score range to balance speed and consistency.',
                    ),
                    legend: [
                      ResultsChartLegendChip(
                        color: const Color(0xFF10B981),
                        label: t(
                          'results.bulk.points_per_second',
                          'Points/second',
                        ),
                      ),
                    ],
                    child: GroupedHorizontalBarChart(
                      categories: [
                        for (final row in rows) _slotLabel(row),
                      ],
                      series: _bulkPointsPerSecondSeries(),
                      formatValue: (value) => _fmtDouble(value.toDouble()),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                ResultsChartCard(
                  key: const ValueKey('results.bulk.chart.range'),
                  title: t(
                    'results.charts.bulk_range.title',
                    'Bulk Score Range',
                  ),
                  subtitle: t(
                    'results.charts.bulk_range.subtitle',
                    'Compare min, median, mean and max across saved setups.',
                  ),
                  helpTooltip: t(
                    'results.charts.bulk_range.help',
                    'Each setup is one row. Read the four bars as worst run, median run, average run and best run to compare both ceiling and consistency.',
                  ),
                  legend: [
                    ResultsChartLegendChip(
                      color: const Color(0xFF3B82F6),
                      label: t('min', 'Min'),
                    ),
                    ResultsChartLegendChip(
                      color: const Color(0xFFF59E0B),
                      label: t('median', 'Median'),
                    ),
                    ResultsChartLegendChip(
                      color: const Color(0xFF10B981),
                      label: t('mean', 'Mean'),
                    ),
                    ResultsChartLegendChip(
                      color: const Color(0xFFEF4444),
                      label: t('max', 'Max'),
                    ),
                  ],
                  child: GroupedHorizontalBarChart(
                    categories: [
                      for (final row in rows) _slotLabel(row),
                    ],
                    series: _bulkRangeSeries(),
                    formatValue: _fmtInt,
                  ),
                ),
                if (_hasBulkPercentileComparison) ...[
                  const SizedBox(height: 12),
                  ResultsChartCard(
                    key: const ValueKey('results.bulk.chart.percentiles'),
                    title: t(
                      'results.charts.bulk_percentiles.title',
                      'Bulk Percentile Comparison',
                    ),
                    subtitle: t(
                      'results.charts.bulk_percentiles.subtitle',
                      'Compare conservative, typical and high-roll outcomes across setups.',
                    ),
                    helpTooltip: t(
                      'results.charts.bulk_percentiles.help',
                      'P10 is a conservative low-end outcome, P50 is the median run, and P90 is a strong high-end outcome. This helps distinguish stable setups from swingier ones.',
                    ),
                    legend: [
                      ResultsChartLegendChip(
                        color: const Color(0xFF2563EB),
                        label: t('results.charts.percentile.p10', 'P10'),
                      ),
                      ResultsChartLegendChip(
                        color: const Color(0xFF7C3AED),
                        label: t('results.charts.percentile.p50', 'P50'),
                      ),
                      ResultsChartLegendChip(
                        color: const Color(0xFFEF4444),
                        label: t('results.charts.percentile.p90', 'P90'),
                      ),
                    ],
                    child: GroupedHorizontalBarChart(
                      categories: [
                        for (final row in rows) _slotLabel(row),
                      ],
                      series: _bulkPercentileSeries(),
                      formatValue: _fmtInt,
                    ),
                  ),
                ],
                if (_hasBulkTargetChance) ...[
                  const SizedBox(height: 12),
                  ResultsChartCard(
                    key: const ValueKey('results.bulk.chart.target_chance'),
                    title: t(
                      'results.charts.bulk_target.title',
                      'Bulk Target Chance',
                    ),
                    subtitle: t(
                      'results.charts.bulk_target.subtitle',
                      'Approximate chance for each setup to reach the current target score.',
                    ),
                    helpTooltip: t(
                      'results.charts.bulk_target.help',
                      'Uses histogram buckets from each setup simulation to estimate how likely that setup is to hit the current milestone target.',
                    ),
                    legend: [
                      ResultsChartLegendChip(
                        color: const Color(0xFF10B981),
                        label: t(
                          'results.charts.bulk_target.series',
                          'Target chance',
                        ),
                      ),
                      ResultsChartLegendChip(
                        color: const Color(0xFFEF4444),
                        label: t(
                          'results.charts.exceedance.target',
                          'Target',
                        ),
                        value: _fmtInt(milestoneTargetPoints),
                      ),
                    ],
                    child: GroupedHorizontalBarChart(
                      categories: [
                        for (final row in rows) _slotLabel(row),
                      ],
                      series: _bulkTargetChanceSeries(),
                      formatValue: _fmtPercent,
                    ),
                  ),
                ],
                if (_hasBulkThresholdChips) ...[
                  const SizedBox(height: 12),
                  ResultsChartCard(
                    key: const ValueKey('results.bulk.chart.thresholds'),
                    title: t(
                      'results.charts.bulk_thresholds.title',
                      'Bulk Threshold Chips',
                    ),
                    subtitle: t(
                      'results.charts.bulk_thresholds.subtitle',
                      'Compact chance view for each setup at the current target, mean, P75 and P90 thresholds.',
                    ),
                    helpTooltip: t(
                      'results.charts.bulk_thresholds.help',
                      'Each setup shows approximate chances to finish at or above four practical score cutoffs: the current selected score, its own mean, P75 and P90.',
                    ),
                    child: _bulkThresholdCards(context),
                  ),
                ],
                if (_hasBulkDistributionSmallMultiples) ...[
                  const SizedBox(height: 12),
                  ResultsChartCard(
                    key: const ValueKey('results.bulk.chart.distribution'),
                    title: t(
                      'results.charts.bulk_distribution.title',
                      'Bulk Distribution',
                    ),
                    subtitle: t(
                      'results.charts.bulk_distribution.subtitle',
                      'Small multiples make the score shape of each setup easier to compare at a glance.',
                    ),
                    helpTooltip: t(
                      'results.charts.bulk_distribution.help',
                      'Each mini histogram shows how the setup scores are distributed across the simulation. Compare spread, skew and concentration without overlapping the setups into a single noisy chart.',
                    ),
                    child: SmallMultipleHistogramList(
                      items: _bulkDistributionItems(),
                      emptyLabel: t(
                        'results.charts.empty',
                        'No chart data available.',
                      ),
                      formatX: _fmtInt,
                    ),
                  ),
                ],
                if (rows.length > 2) ...[
                  const SizedBox(height: 12),
                  _headToHeadSelectors(context),
                ],
                if (headToHeadMetrics.length >= 2) ...[
                  const SizedBox(height: 12),
                  ResultsChartCard(
                    key: const ValueKey('results.bulk.chart.head_to_head'),
                    title: t(
                      'results.charts.bulk_head_to_head.title',
                      'Head-to-Head Delta',
                    ),
                    subtitle: t(
                      'results.charts.bulk_head_to_head.subtitle',
                      'Direct comparison of the two selected setups across score, consistency and efficiency signals.',
                    ),
                    helpTooltip: t(
                      'results.charts.bulk_head_to_head.help',
                      'Each row compares the same metric between the two setups. Bars point toward the setup with the stronger value, while the side labels keep the exact numbers visible.',
                    ),
                    child: HeadToHeadDeltaChart(
                      leftLabel: _slotLabel(selectedHeadToHeadRows[0]),
                      rightLabel: _slotLabel(selectedHeadToHeadRows[1]),
                      leftColor: _headToHeadLeftColor,
                      rightColor: _headToHeadRightColor,
                      metrics: headToHeadMetrics,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                if (compact)
                  _compactSummaryCards(context)
                else
                  ThemedStringTable(
                    minWidth: 1100,
                    columns: [
                      t('setups.slot', 'Slot'),
                      t('mode', 'Mode'),
                      t('boss.level', 'Boss Level'),
                      t('pet.skill_loadout', 'Pet loadout'),
                      t('mean', 'mean'),
                      t('results.bulk.target_chance', 'Target chance'),
                      t('expected_range', 'Expected range (+/-8%)'),
                      if (isPremium)
                        t('results.bulk.run_time_mean', 'Run time mean (s)'),
                      if (isPremium)
                        t('results.bulk.points_per_second', 'Points/second'),
                    ],
                    rows: [
                      for (final row in rows)
                        [
                          _slotLabel(row),
                          _modeLabel(row.bossMode),
                          'L${row.bossLevel}',
                          _fightLabel(row),
                          _fmtInt(row.meanPoints),
                          _targetChancePercent(row) == null
                              ? '-'
                              : _fmtPercent(_targetChancePercent(row)!),
                          '${_fmtInt(row.expectedRange.lower)} - ${_fmtInt(row.expectedRange.upper)}',
                          if (isPremium) _fmtDouble(row.meanRunSeconds),
                          if (isPremium) _fmtDouble(row.pointsPerSecond),
                        ],
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: t('results.bulk.pet_section', 'Pet'),
            child: compact
                ? _compactPetCards(context)
                : ThemedStringTable(
                    minWidth: 760,
                    columns: [
                      t('setups.slot', 'Slot'),
                      t('pet.atk', 'Pet ATK'),
                      t('results.pet.normal_damage', 'Normal damage'),
                      t('results.pet.crit_damage', 'Crit damage'),
                      t('results.pet.element_1', 'Element 1'),
                      t('results.pet.element_2', 'Element 2'),
                    ],
                    rows: [
                      for (final row in rows)
                        [
                          _slotLabel(row),
                          _fmtInt(row.pet.atk),
                          _fmtInt(row.petNormalDamage),
                          _fmtInt(row.petCritDamage),
                          _elementLabel(row.pet.element1.id),
                          _petElement2Label(row),
                        ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: t('results.bulk.knights_section', 'Knights'),
            child: compact
                ? _compactKnightsCards(context)
                : ThemedStringTable(
                    minWidth: 1800,
                    columns: [
                      t('setups.slot', 'Slot'),
                      'K#1',
                      'K#2',
                      'K#3',
                    ],
                    rows: [
                      for (final row in rows)
                        [
                          _slotLabel(row),
                          _knightSummary(row, 0),
                          _knightSummary(row, 1),
                          _knightSummary(row, 2),
                        ],
                    ],
                    dataRowMaxHeight: 88,
                  ),
          ),
        ],
      ),
    );
  }
}
