// lib/ui/results_page.dart
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../core/battle_outcome.dart';
import '../core/engine/engine_common.dart';
import '../core/engine/skill_catalog.dart';
import '../core/sim_types.dart';
import '../data/config_models.dart';
import '../data/pet_effect_models.dart';
import '../data/share_payloads.dart';
import '../data/setup_models.dart';
import '../util/elixir_calc.dart';
import 'results_charts.dart';
import 'table_widgets.dart';
import 'theme_helpers.dart';

class ResultsPage extends StatelessWidget {
  final Precomputed pre;
  final List<String> knightIds;
  final SimStats stats;
  final Map<String, String> labels;
  final bool isPremium;
  final bool debugEnabled;
  final List<ElixirInventoryItem> elixirs;
  final ShatterShieldConfig? shatter;

  // Helper for Cyclone table + info
  final bool cycloneUseGemsForSpecials;

  // Helper for milestone target (Home input)
  final int milestoneTargetPoints;

  // Helper for starting available energy (Home input)
  final int startEnergies;
  final int freeRaidEnergies;
  final String petElement1Id;
  final String? petElement2Id;
  final List<List<String>> knightElementPairs;
  final SetupPetCompendiumImportSnapshot? importedPet;
  final List<PetResolvedEffect> petEffects;
  final SetupPetSkillSnapshot? selectedSkill1;
  final SetupPetSkillSnapshot? selectedSkill2;
  final bool embedded;

  const ResultsPage({
    super.key,
    required this.pre,
    required this.knightIds,
    required this.stats,
    required this.labels,
    required this.isPremium,
    this.cycloneUseGemsForSpecials = true,
    this.debugEnabled = false,
    this.elixirs = const <ElixirInventoryItem>[],
    this.shatter,
    this.milestoneTargetPoints = _defaultTargetPoints,
    this.startEnergies = 0,
    this.freeRaidEnergies = _defaultFreeRaidEnergies,
    this.petElement1Id = 'fire',
    this.petElement2Id,
    this.knightElementPairs = const <List<String>>[],
    this.importedPet,
    this.petEffects = const <PetResolvedEffect>[],
    this.selectedSkill1,
    this.selectedSkill2,
    this.embedded = false,
  });

  String t(String k, String fb) => labels[k] ?? fb;

  int get _knightCount => pre.kHp.length;
  bool get _drsUsesPetBar =>
      pre.meta.petTicksBar.enabled &&
      pre.meta.petTicksBar.useInDurableRockShield;
  bool get _hasTimingData => stats.timing != null;
  bool get _hasPremiumTimingData => isPremium && _hasTimingData;
  bool get _hasCyclone => _hasPetEffect(BattleSkillCatalog.cycloneId);
  bool get _hasShatter => _hasPetEffect(BattleSkillCatalog.shatterShieldId);
  bool get _hasDrs => _hasPetEffect(BattleSkillCatalog.durableRockShieldId);
  bool get _hasSr =>
      _hasPetEffect(BattleSkillCatalog.specialRegenId) ||
      _hasPetEffect(BattleSkillCatalog.specialRegenInfiniteId);
  bool get _hasEw => _hasPetEffect(BattleSkillCatalog.elementalWeaknessId);
  List<PetResolvedEffect> get _effectivePetEffects =>
      petEffects.isNotEmpty ? petEffects : pre.petEffects;

  bool _hasPetEffect(String id) {
    final target = BattleSkillCatalog.normalizeCanonicalEffectId(id);
    return _effectivePetEffects.any(
      (effect) =>
          BattleSkillCatalog.normalizeCanonicalEffectId(
            effect.canonicalEffectId,
            fallbackSkillName: effect.sourceSkillName,
          ) ==
          target,
    );
  }

  double? get _averageCycloneGemsSpent {
    if (!_hasCyclone || !cycloneUseGemsForSpecials) return null;
    return stats.meanGemsSpent;
  }

  List<double>? get _estimatedKnightContributionTotals {
    final tstats = stats.timing;
    if (!_hasPremiumTimingData || tstats == null) return null;
    final critChance = pre.meta.criticalChance.clamp(0.0, 1.0);
    return List<double>.generate(_knightCount, (idx) {
      final normalDamage =
          idx < pre.kNormalDmg.length ? pre.kNormalDmg[idx] : 0;
      final critDamage = idx < pre.kCritDmg.length ? pre.kCritDmg[idx] : 0;
      final specialDamage =
          idx < pre.kSpecialDmg.length ? pre.kSpecialDmg[idx] : 0;
      final normalCount =
          idx < tstats.kNormalCount.length ? tstats.kNormalCount[idx] : 0.0;
      final specialCount =
          idx < tstats.kSpecialCount.length ? tstats.kSpecialCount[idx] : 0.0;
      final expectedNormalDamage =
          (normalDamage * (1.0 - critChance)) + (critDamage * critChance);
      return (normalCount * expectedNormalDamage) +
          (specialCount * specialDamage);
    });
  }

  List<double>? get _survivalGapSeconds {
    final tstats = stats.timing;
    if (!_hasPremiumTimingData || tstats == null) return null;
    final runSeconds = tstats.meanRunSeconds <= 0 ? 0.0 : tstats.meanRunSeconds;
    return List<double>.generate(_knightCount, (idx) {
      final survival = idx < tstats.meanSurvivalSeconds.length
          ? tstats.meanSurvivalSeconds[idx]
          : 0.0;
      return math.max(0.0, runSeconds - survival);
    });
  }

  double? get _estimatedPetDirectDamage {
    final tstats = stats.timing;
    if (!_hasPremiumTimingData || tstats == null) return null;
    final totalAttacks = tstats.meanPetAttacks;
    if (totalAttacks <= 0) return 0.0;
    final misses = tstats.meanPetMissAttacks.clamp(0.0, totalAttacks);
    final crits = tstats.meanPetCritAttacks
        .clamp(0.0, math.max(0.0, totalAttacks - misses));
    final normalHits = math.max(0.0, totalAttacks - misses - crits);
    return (normalHits * pre.petNormalDmg) + (crits * pre.petCritDmg);
  }

  double? get _estimatedPetDamageSharePercent {
    final petDamage = _estimatedPetDirectDamage;
    if (petDamage == null || stats.mean <= 0) return null;
    return ((petDamage / stats.mean) * 100.0).clamp(0.0, 100.0);
  }

  String get _petSkillUsageLabel => pre.petSkillUsage.shortLabel();

  PetResolvedEffect? _effectByCanonicalId(String id) {
    final needle = BattleSkillCatalog.normalizeCanonicalEffectId(id);
    for (final effect in _effectivePetEffects) {
      if (BattleSkillCatalog.normalizeCanonicalEffectId(
            effect.canonicalEffectId,
            fallbackSkillName: effect.sourceSkillName,
          ) ==
          needle) {
        return effect;
      }
    }
    return null;
  }

  num? _effectValue(String canonicalId, String key) {
    return _effectByCanonicalId(canonicalId)?.values[key];
  }

  String _valueKeyLabel(String key) {
    return switch (key) {
      'attackBoostPercent' => 'Knight ATK +',
      'bonusFlatDamage' => 'Bonus damage',
      'petAttack' => 'ATK',
      'petAttackCap' => 'ATK cap',
      'critChancePercent' => 'Crit +',
      'flatDamage' => 'Damage',
      'damageOverTime' => 'DoT',
      'goldDrop' => 'Gold drop',
      'stealPercent' => 'Steal',
      'baseShieldHp' => 'Base shield',
      'baseShieldPercent' => 'Base shield % max HP',
      'bonusShieldHp' => 'Bonus shield',
      'bonusShieldPercent' => 'Bonus shield % max HP',
      'defenseBoostPercent' => 'DEF +',
      'enemyAttackReductionPercent' => 'Boss ATK -',
      'meterChargePercent' => 'Charge +',
      'turns' => 'Turns',
      _ => key,
    };
  }

  String _formatSkillValue(num value) {
    if (value is int) return _fmtInt(value);
    if (value == value.roundToDouble()) return _fmtInt(value.round());
    return value.toString();
  }

  String _skillValuesSummary(SetupPetSkillSnapshot skill) {
    final values = skill.effectiveValues;
    if (values.isEmpty) {
      return t('results.pet.skills.no_values', 'no imported values');
    }
    if (skill.isEffectDisabledByOverride) {
      return t(
        'results.pet.skills.disabled',
        'disabled by override (0)',
      );
    }
    final parts = <String>[];
    for (final entry in values.entries) {
      parts.add(
        '${_valueKeyLabel(entry.key)} ${_formatSkillValue(entry.value)}',
      );
    }
    return parts.join(' | ');
  }

  List<SetupPetSkillSnapshot> _selectedSkillsForDisplay() {
    final explicit = <SetupPetSkillSnapshot>[
      if (selectedSkill1 != null) selectedSkill1!,
      if (selectedSkill2 != null) selectedSkill2!,
    ]
        .where((skill) => petSkillDisplayName(skill) != 'None')
        .toList(growable: false);
    if (explicit.isNotEmpty) {
      return explicit;
    }
    if (importedPet != null) {
      return <SetupPetSkillSnapshot>[
        importedPet!.selectedSkill1,
        importedPet!.selectedSkill2,
      ]
          .where((skill) => petSkillDisplayName(skill) != 'None')
          .toList(growable: false);
    }
    final ordered = <SetupPetSkillSnapshot>[];
    for (final slotId in const <String>['skill11', 'skill12', 'skill2']) {
      for (final effect in petEffects) {
        if (effect.sourceSlotId != slotId) continue;
        ordered.add(
          SetupPetSkillSnapshot(
            slotId: effect.sourceSlotId,
            name: effect.sourceSkillName,
            canonicalEffectId: effect.canonicalEffectId,
            values: effect.values,
          ),
        );
        break;
      }
    }
    return ordered;
  }

  String _knightLabel(int idx) {
    if (idx >= 0 && idx < knightIds.length) return knightIds[idx];
    return 'K${idx + 1}';
  }

  static const int _defaultTargetPoints = 1000000000; // 1B
  static const int _maxTargetPoints = 200000000000; // 200B

  // Milestone energies model
  static const int _defaultFreeRaidEnergies = 30;
  static const int _packSize = 40;
  static const int _packCost = 90;

  // Expected range: band centered around the mean (+/-8% of mean).
  static const double _expectedMeanPct = 0.08;

  String _summaryLine() {
    final parts = <String>[];
    if (pre.meta.raidMode) {
      parts.add('${t('raid', 'Raid')} ${t('boss', 'Boss')}');
    } else {
      parts.add('${t('blitz', 'Blitz')} ${t('raid', 'Raid')}');
    }
    if (isPremium) parts.add(t('premium.title', 'Premium'));
    if (debugEnabled) parts.add(t('debug.title', 'Debug'));
    parts.add(_skillSetupSummary());
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('report_title', 'Simulation Report')),
        actions: [
          IconButton(
            tooltip: t('results.share_tip.title', 'Share tip'),
            icon: Icon(
              Icons.info_outline,
              semanticLabel: t('results.share_tip.title', 'Share tip'),
            ),
            onPressed: () => _showResultsShareTip(context),
          ),
          IconButton(
            tooltip: t('results.export', 'Copy export'),
            icon: Icon(
              Icons.copy,
              semanticLabel: t('results.export', 'Copy export'),
            ),
            onPressed: () => _copyExport(context),
          ),
        ],
      ),
      body: _ResultsBody(page: this),
    );
  }

  Widget _reportHeader(BuildContext context) {
    final theme = Theme.of(context);
    final chips = <String>[
      pre.meta.raidMode
          ? '${t('raid', 'Raid')} ${t('boss', 'Boss')}'
          : '${t('blitz', 'Blitz')} ${t('raid', 'Raid')}',
      _skillSetupSummary(),
      if (isPremium) t('premium.title', 'Premium'),
      if (debugEnabled) t('debug.title', 'Debug'),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.38 : 0.14,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('report_title', 'Simulation Report'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _summaryLine(),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final chip in chips) _reportTagChip(context, chip),
            ],
          ),
        ],
      ),
    );
  }

  Widget _performanceSummarySection(
    BuildContext context,
    int perRun,
    _EnergyPlan plan, {
    bool graphViewEnabled = false,
    required int selectedProbabilityTargetPoints,
    required ValueChanged<int> onSelectProbabilityTarget,
  }) {
    const convergenceScoreColor = Color(0xFF10B981);
    const convergenceMeanColor = Color(0xFF7C3AED);
    const convergenceMedianColor = Color(0xFFD946EF);
    const convergenceMinColor = Color(0xFF2563EB);
    const convergenceMaxColor = Color(0xFFEF4444);
    const convergenceBandColor = Color(0xFFF59E0B);
    const histogramLowBandColor = Color(0xFF2563EB);
    const histogramCoreBandColor = Color(0xFF10B981);
    const histogramHighBandColor = Color(0xFFEF4444);
    const probabilityLineColor = Color(0xFF7C3AED);
    const probabilityTargetColor = Color(0xFFEF4444);
    final compact = MediaQuery.sizeOf(context).width < 420;
    final probabilityFillColor = probabilityLineColor.withValues(alpha: 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricCard(
              context,
              label: t('mean', 'Mean score'),
              value: _fmtInt(stats.mean),
            ),
            _metricCard(
              context,
              label: t('expected_range', 'Expected range (+/-8%)'),
              value: _expectedRange(stats.mean),
            ),
            _metricCard(
              context,
              label:
                  t('milestone.row.runs_packs', 'Runs needed / Packs to buy'),
              value: '${_fmtInt(plan.runs)} / ${_fmtInt(plan.packs)}',
            ),
            _metricCard(
              context,
              label:
                  t('milestone.row.gems_leftover', 'Gems needed / Energy left'),
              value: '${_fmtInt(plan.gems)} / ${_fmtInt(plan.leftover)}',
            ),
            if (_hasCyclone &&
                cycloneUseGemsForSpecials &&
                _averageCycloneGemsSpent != null)
              _metricCard(
                context,
                label: t('results.cyclone.gems_spent', 'Gems spent'),
                value: t(
                  'results.cyclone.gems_spent_value',
                  '{value} gems',
                ).replaceAll(
                  '{value}',
                  _fmtCompact(_averageCycloneGemsSpent!),
                ),
              ),
          ],
        ),
        if (graphViewEnabled) ...[
          const SizedBox(height: 14),
          if (stats.series != null && stats.series!.checkpoints.isNotEmpty) ...[
            ResultsChartCard(
              key: const ValueKey('results.chart.convergence'),
              title: t(
                'results.charts.convergence.title',
                'Convergence',
              ),
              subtitle: t(
                'results.charts.convergence.subtitle',
                'Sampled checkpoint score points with overall mean, median, min and max guides.',
              ),
              helpTooltip: t(
                'results.charts.convergence.help',
                'Plots one sampled score point per checkpoint across the run count. The dashed purple line is the final mean, the dashed fuchsia line is the final median, the blue line is the final min, the red line is the final max, and the shaded band spans the same min/max range.',
              ),
              legend: [
                ResultsChartLegendChip(
                  color: convergenceScoreColor,
                  label: t('score', 'Score'),
                ),
                ResultsChartLegendChip(
                  color: convergenceMeanColor,
                  label: t('mean', 'Mean'),
                ),
                ResultsChartLegendChip(
                  color: convergenceMedianColor,
                  label: t('median', 'Median'),
                ),
                ResultsChartLegendChip(
                  color: convergenceMinColor,
                  label: t('min', 'Min'),
                ),
                ResultsChartLegendChip(
                  color: convergenceMaxColor,
                  label: t('max', 'Max'),
                ),
                ResultsChartLegendChip(
                  color: convergenceBandColor,
                  label: t(
                    'results.charts.convergence.band',
                    'Min/max band',
                  ),
                ),
                ResultsChartLegendChip(
                  color: const Color(0xFF10B981),
                  label: t(
                    'results.charts.convergence.total_runs',
                    'Total runs',
                  ),
                  value: _fmtInt(stats.series!.totalRuns),
                ),
              ],
              child: ConvergenceLineChart(
                points: stats.series!.checkpoints
                    .map(
                      (checkpoint) => LineChartDatum(
                        x: checkpoint.runIndex,
                        y: checkpoint.sampledScore,
                        lower: stats.min,
                        upper: stats.max,
                      ),
                    )
                    .toList(growable: false),
                xAxisLabel: t('runs', 'Runs'),
                yAxisLabel: t('score', 'Score'),
                emptyLabel: t(
                  'results.charts.empty',
                  'No chart data available.',
                ),
                formatX: _fmtInt,
                formatY: _fmtInt,
                meanValue: stats.mean,
                medianValue: stats.median,
                scorePointColor: convergenceScoreColor,
                meanColor: convergenceMeanColor,
                medianColor: convergenceMedianColor,
                minColor: convergenceMinColor,
                maxColor: convergenceMaxColor,
                bandColor: convergenceBandColor.withValues(alpha: 0.18),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (stats.series?.histogram != null &&
              stats.series!.histogram!.bins.isNotEmpty) ...[
            ResultsChartCard(
              key: const ValueKey('results.chart.histogram'),
              title: t(
                'results.charts.histogram.title',
                'Score Distribution',
              ),
              subtitle: t(
                'results.charts.histogram.subtitle',
                'How often each score range appears across all runs.',
              ),
              helpTooltip: t(
                'results.charts.histogram.help',
                'Each bar is a score bucket. Colors show three percentile zones: below 40%, from 40% to 60%, and above 60%.',
              ),
              legend: [
                ResultsChartLegendChip(
                  color: histogramLowBandColor,
                  label: t(
                    'results.charts.histogram.band.low',
                    '< 40%',
                  ),
                ),
                ResultsChartLegendChip(
                  color: histogramCoreBandColor,
                  label: t(
                    'results.charts.histogram.band.core',
                    '40% - 60%',
                  ),
                ),
                ResultsChartLegendChip(
                  color: histogramHighBandColor,
                  label: t(
                    'results.charts.histogram.band.high',
                    '> 60%',
                  ),
                ),
              ],
              child: HistogramBarChart(
                bins: _buildHistogramBinsWithBands(
                  stats.series!.histogram!,
                  stats.series!.totalRuns,
                  lowBandColor: histogramLowBandColor,
                  coreBandColor: histogramCoreBandColor,
                  highBandColor: histogramHighBandColor,
                ),
                xAxisLabel: t(
                  'results.charts.histogram.score_axis',
                  'Score',
                ),
                yAxisLabel: t(
                  'results.charts.histogram.runs_per_bin',
                  'Runs/bin',
                ),
                emptyLabel: t(
                  'results.charts.empty',
                  'No chart data available.',
                ),
                formatX: _fmtInt,
                formatY: _fmtInt,
              ),
            ),
            const SizedBox(height: 12),
            ResultsChartCard(
              key: const ValueKey('results.chart.exceedance'),
              title: t(
                'results.charts.exceedance.title',
                'Target Probability',
              ),
              subtitle: t(
                'results.charts.exceedance.subtitle',
                'Approximate chance to finish at or above each score threshold.',
              ),
              helpTooltip: t(
                'results.charts.exceedance.help',
                'This graph is derived from histogram buckets, so it is an approximation. Higher values mean a higher chance to end a run at or above the selected score threshold. The percentile chips below show approximate score cutoffs.',
              ),
              legend: [
                ResultsChartLegendChip(
                  color: probabilityLineColor,
                  label: t(
                    'results.charts.exceedance.axis_label',
                    'Chance >= threshold',
                  ),
                ),
                ResultsChartLegendChip(
                  color: probabilityTargetColor,
                  label: t(
                    'results.charts.exceedance.target',
                    'Target',
                  ),
                  value: _fmtInt(selectedProbabilityTargetPoints),
                ),
                ResultsChartLegendChip(
                  color: probabilityTargetColor,
                  label: t(
                    'results.charts.exceedance.target_chance',
                    'At target',
                  ),
                  value: _fmtPercent(_approxHistogramExceedancePercent(
                    stats.series!.histogram!,
                    selectedProbabilityTargetPoints,
                    stats.series!.totalRuns,
                  )),
                ),
              ],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(
                      'results.charts.exceedance.quick_targets',
                      'Quick targets',
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    key: const ValueKey('results.chart.exceedance.targets'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final option in _probabilityTargetOptions(
                        stats.series!.histogram!,
                        stats.series!.totalRuns,
                      ))
                        ChoiceChip(
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          label: Text(
                            compact
                                ? '${option.label} ${_fmtShortInt(option.value)}'
                                : '${option.label} ${_fmtInt(option.value)}',
                          ),
                          selected:
                              option.value == selectedProbabilityTargetPoints,
                          onSelected: (_) =>
                              onSelectProbabilityTarget(option.value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ProbabilityLineChart(
                    points: _buildExceedancePoints(
                      stats.series!.histogram!,
                      stats.series!.totalRuns,
                    ),
                    xAxisLabel: t(
                      'results.charts.histogram.score_axis',
                      'Score',
                    ),
                    yAxisLabel: t(
                      'results.charts.exceedance.axis_label',
                      'Chance >= threshold',
                    ),
                    emptyLabel: t(
                      'results.charts.empty',
                      'No chart data available.',
                    ),
                    formatX: _fmtInt,
                    formatY: _fmtPercent,
                    targetX: selectedProbabilityTargetPoints,
                    lineColor: probabilityLineColor,
                    fillColor: probabilityFillColor,
                    targetColor: probabilityTargetColor,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t(
                      'results.charts.exceedance.percentiles',
                      'Approx. percentiles',
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    key: const ValueKey('results.chart.exceedance.percentiles'),
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final percentile in const <int>[10, 25, 50, 75, 90])
                        ResultsChartLegendChip(
                          color: probabilityLineColor,
                          label: _percentileLabel(percentile),
                          value: _fmtInt(
                            _approxHistogramPercentileScore(
                              stats.series!.histogram!,
                              stats.series!.totalRuns,
                              percentile.toDouble(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          ResultsChartCard(
            key: const ValueKey('results.chart.score_summary'),
            title: t('results.charts.score_range.title', 'Score Range'),
            subtitle: t(
              'results.charts.score_range.subtitle',
              'Min, median, mean and max for this simulation set.',
            ),
            helpTooltip: t(
              'results.charts.score_range.help',
              'Shows the spread of outcomes from the worst run to the best run. Read it from left to right as min, median, mean and max.',
            ),
            legend: [
              ResultsChartLegendChip(
                color: const Color(0xFF3B82F6),
                label: t('min', 'Min'),
                value: _fmtInt(stats.min),
              ),
              ResultsChartLegendChip(
                color: const Color(0xFFF59E0B),
                label: t('median', 'Median'),
                value: _fmtInt(stats.median),
              ),
              ResultsChartLegendChip(
                color: const Color(0xFF10B981),
                label: t('mean', 'Mean'),
                value: _fmtInt(stats.mean),
              ),
              ResultsChartLegendChip(
                color: const Color(0xFFEF4444),
                label: t('max', 'Max'),
                value: _fmtInt(stats.max),
              ),
            ],
            child: ScoreSummaryChart(
              min: stats.min,
              median: stats.median,
              mean: stats.mean,
              max: stats.max,
              minLabel: t('min', 'Min'),
              medianLabel: t('median', 'Median'),
              meanLabel: t('mean', 'Mean'),
              maxLabel: t('max', 'Max'),
              formatValue: _fmtInt,
            ),
          ),
        ],
        const SizedBox(height: 14),
        _subsectionLabel(
          context,
          t('stats', 'Stats'),
        ),
        const SizedBox(height: 8),
        _statsTable(context, includeElixirs: false),
        const SizedBox(height: 14),
        _subsectionLabel(
          context,
          "${t('milestone_title', 'Milestone - Gem cost')} (${_fmtInt(milestoneTargetPoints)} ${t('points_short', 'pts')})",
        ),
        const SizedBox(height: 8),
        _milestoneTable2x4(context, perRun, plan),
      ],
    );
  }

  Widget _battleContextSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricCard(
              context,
              label: t('boss.level', 'Boss Level'),
              value: pre.meta.level.toString(),
            ),
            _metricCard(
              context,
              label: t('results.battle_type', 'Battle'),
              value:
                  pre.meta.raidMode ? t('raid', 'Raid') : t('blitz', 'Blitz'),
            ),
            _metricCard(
              context,
              label: t('atk', 'ATK'),
              value: _fmtInt(pre.stats.attack),
            ),
            _metricCard(
              context,
              label: t('def', 'DEF'),
              value: _fmtInt(pre.stats.defense),
            ),
            _metricCard(
              context,
              label: t('hp', 'HP'),
              value: _fmtInt(pre.stats.hp),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _bossTable(context),
        const SizedBox(height: 10),
        _bossIncomingPressureTable(context),
      ],
    );
  }

  Widget _petAndModeSection(
    BuildContext context, {
    bool graphViewEnabled = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _metricCard(
              context,
              label: t('pet.atk', 'Pet ATK'),
              value: _fmtInt(pre.petAtk),
            ),
            _metricCard(
              context,
              label: t('results.pet.normal_damage', 'Normal damage'),
              value: _fmtInt(pre.petNormalDmg),
            ),
            _metricCard(
              context,
              label: t('results.pet.crit_damage', 'Crit damage'),
              value: _fmtInt(pre.petCritDmg),
            ),
            _metricCard(
              context,
              label: t('results.pet.elements', 'Elements'),
              value:
                  '${_elementLabelFromId(petElement1Id)} / ${_elementLabelFromId(petElement2Id)}',
            ),
          ],
        ),
        if (graphViewEnabled && _hasPremiumTimingData) ...[
          const SizedBox(height: 14),
          ResultsChartCard(
            key: const ValueKey('results.chart.pet_impact'),
            title: t(
              'results.charts.pet_impact.title',
              'Pet Impact Summary',
            ),
            subtitle: t(
              'results.charts.pet_impact.subtitle',
              'Quick view of pet direct damage, average casts and estimated share of the total run score.',
            ),
            helpTooltip: t(
              'results.charts.pet_impact.help',
              'This summary uses the tracked average pet attacks, crits and misses from timing data. It estimates direct pet damage only, so it does not try to price in secondary skill effects like buffs or shields.',
            ),
            legend: [
              ResultsChartLegendChip(
                color: const Color(0xFF3B82F6),
                label: t(
                  'results.charts.pet_impact.direct_damage',
                  'Direct damage',
                ),
                value: _fmtInt((_estimatedPetDirectDamage ?? 0).round()),
              ),
              ResultsChartLegendChip(
                color: const Color(0xFF10B981),
                label: t(
                  'results.charts.pet_impact.avg_casts',
                  'Avg casts',
                ),
                value: _dash(stats.timing!.meanPetAttacks),
              ),
              ResultsChartLegendChip(
                color: const Color(0xFFF59E0B),
                label: t(
                  'results.charts.pet_impact.share',
                  'Share of total',
                ),
                value: _estimatedPetDamageSharePercent == null
                    ? '-'
                    : _fmtPercent(_estimatedPetDamageSharePercent!),
              ),
            ],
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metricCard(
                  context,
                  label: t(
                    'results.charts.pet_impact.direct_damage',
                    'Direct damage',
                  ),
                  value: _fmtInt((_estimatedPetDirectDamage ?? 0).round()),
                ),
                _metricCard(
                  context,
                  label: t(
                    'results.charts.pet_impact.avg_casts',
                    'Avg casts',
                  ),
                  value: _dash(stats.timing!.meanPetAttacks),
                ),
                _metricCard(
                  context,
                  label: t(
                    'results.charts.pet_impact.avg_crits',
                    'Avg crits',
                  ),
                  value: _dash(stats.timing!.meanPetCritAttacks),
                ),
                _metricCard(
                  context,
                  label: t(
                    'results.charts.pet_impact.avg_misses',
                    'Avg misses',
                  ),
                  value: _dash(stats.timing!.meanPetMissAttacks),
                ),
                _metricCard(
                  context,
                  label: t(
                    'results.charts.pet_impact.share',
                    'Share of total',
                  ),
                  value: _estimatedPetDamageSharePercent == null
                      ? '-'
                      : _fmtPercent(_estimatedPetDamageSharePercent!),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _subsectionLabel(
          context,
          t('results.pet_mode.overview', 'Skill overview'),
        ),
        const SizedBox(height: 8),
        _petSummary(context),
      ],
    );
  }

  Widget _advancedDetailsSection(
    BuildContext context, {
    bool graphViewEnabled = false,
    required _TimingShareVisualMode timingShareVisualMode,
    required ValueChanged<_TimingShareVisualMode>
        onTimingShareVisualModeChanged,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t(
              'results.advanced.hint',
              'Open only the panels you need for a deeper breakdown.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.72),
                ),
          ),
          const SizedBox(height: 8),
          _advancedTile(
            context,
            tileKey: const ValueKey('results.advanced.tile.pet_details'),
            title: t('results.advanced.pet_details', 'Pet details'),
            subtitle: t(
              'results.advanced.pet_details_hint',
              'Quick snapshot of pet damage profile and active loadout.',
            ),
            icon: Icons.pets_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _subsectionLabel(
                  context,
                  t('results.pet_mode.title', 'Pet & Skills'),
                ),
                const SizedBox(height: 8),
                _petAndModeSection(
                  context,
                  graphViewEnabled: graphViewEnabled,
                ),
                const SizedBox(height: 8),
                _petAbilityRecap(context),
                if (_hasShatter && shatter != null) ...[
                  const SizedBox(height: 8),
                  _shatterSummary(context),
                ],
              ],
            ),
          ),
          if (elixirs.isNotEmpty) ...[
            const SizedBox(height: 4),
            _advancedTile(
              context,
              tileKey: const ValueKey('results.advanced.tile.elixirs'),
              title: t('results.advanced.elixirs', 'Elixir impact'),
              subtitle: t(
                'results.advanced.elixirs_hint',
                'Estimated score gain per selected elixir.',
              ),
              icon: Icons.local_drink_outlined,
              child: _elixirImpact(context),
            ),
          ],
          const SizedBox(height: 4),
          _advancedTile(
            context,
            tileKey: const ValueKey('results.advanced.tile.duration'),
            title: t('durations', 'Fight duration data (Premium)'),
            subtitle: t(
              'results.advanced.timing_hint',
              'Run pacing, survival pressure and per-action timing.',
            ),
            icon: Icons.timer_outlined,
            child: _durationsSection(
              context,
              graphViewEnabled: graphViewEnabled,
              timingShareVisualMode: timingShareVisualMode,
              onTimingShareVisualModeChanged: onTimingShareVisualModeChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportTagChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onPrimaryContainer,
        ),
      ),
    );
  }

  Widget _metricCard(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.32 : 0.14,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _subsectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }

  Widget _compactInfoList(
    BuildContext context,
    List<MapEntry<String, String>> items,
  ) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 16,
                color: theme.colorScheme.outline.withValues(alpha: 0.14),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    items[i].key,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 7,
                  child: Text(
                    items[i].value,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _skillSetupSummary() {
    final selectedSkills = _selectedSkillsForDisplay();
    if (selectedSkills.isEmpty) {
      return t(
        'results.pet.skills.none_selected',
        'No pet skills selected',
      );
    }
    return selectedSkills.map(petSkillDisplayName).join(' + ');
  }

  Widget _advancedTile(
    BuildContext context, {
    Key? tileKey,
    required String title,
    required Widget child,
    IconData? icon,
    String? subtitle,
  }) {
    final theme = Theme.of(context);
    final tileColor = theme.colorScheme.surfaceContainerHighest
        .withValues(alpha: theme.brightness == Brightness.dark ? 0.2 : 0.18);
    return Container(
      key: tileKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: tileColor,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.3 : 0.12,
          ),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        iconColor: theme.colorScheme.primary,
        collapsedIconColor: theme.colorScheme.primary,
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Container(
                width: 28,
                height: 28,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle != null && subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: theme.colorScheme.surface.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.24 : 0.6,
              ),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.25 : 0.08,
                ),
              ),
            ),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _elixirImpact(BuildContext context) {
    final rows = <MapEntry<String, String>>[];
    for (final e in elixirs) {
      rows.add(
        MapEntry(
          e.name,
          '+${_fmtInt((stats.mean * e.scoreMultiplier).round())} | '
          '+${(e.scoreMultiplier * 100).toStringAsFixed(0)}% | '
          '${e.durationMinutes}m',
        ),
      );
    }
    return _compactInfoList(context, rows);
  }

  Widget _shatterSummary(BuildContext context) {
    final match = shatter?.elementMatch ?? const <bool>[false, false, false];
    final yes = t('results.yes', 'Yes');
    final no = t('results.no', 'No');
    final matchSummary = List<String>.generate(
      _knightCount,
      (i) => '${_knightLabel(i)}: ${i < match.length && match[i] ? yes : no}',
      growable: false,
    ).join(' | ');

    return _compactInfoList(
      context,
      <MapEntry<String, String>>[
        MapEntry(t('results.shatter.pet_match', 'Pet match'), matchSummary),
        MapEntry(
          t('results.shatter.base', 'Shatter base HP'),
          _fmtInt(shatter?.baseHp ?? 0),
        ),
        MapEntry(
          t('results.shatter.bonus', 'Shatter bonus HP'),
          _fmtInt(shatter?.bonusHp ?? 0),
        ),
      ],
    );
  }

  Widget _petSummary(BuildContext context) {
    final selectedSkills = _selectedSkillsForDisplay();
    final rows = <MapEntry<String, String>>[
      MapEntry(t('pet.atk', 'Pet ATK'), _fmtInt(pre.petAtk)),
      MapEntry(
        t('results.pet.normal_damage', 'Normal damage'),
        _fmtInt(pre.petNormalDmg),
      ),
      MapEntry(
        t('results.pet.crit_damage', 'Crit damage'),
        _fmtInt(pre.petCritDmg),
      ),
      MapEntry(
        t('results.pet.elements', 'Elements'),
        '${_elementLabelFromId(petElement1Id)} / ${_elementLabelFromId(petElement2Id)}',
      ),
      MapEntry(t('results.pet.skills.bar', 'Pet bar'), _petSkillUsageLabel),
      MapEntry(
        t('results.pet.skills.bar_flow', 'Pet bar flow'),
        _petBarFlowDescription(),
      ),
      MapEntry(
        t('results.pet.skills.bar_cycle', 'Pet bar cycle example'),
        _petBarCyclePreview(),
      ),
    ];
    for (int i = 0; i < selectedSkills.length; i++) {
      final skill = selectedSkills[i];
      final slotNumber = i + 1;
      final slotLabel = t(
        i == 0 ? 'results.pet.skills.slot1' : 'results.pet.skills.slot2',
        i == 0 ? 'Skill Slot 1' : 'Skill Slot 2',
      );
      rows.add(
        MapEntry(
          slotLabel,
          petSkillDisplayName(skill),
        ),
      );
      rows.add(
        MapEntry(
          '$slotLabel ${t('results.pet.skills.behavior', 'behavior')}',
          _skillBehaviorDescription(skill),
        ),
      );
      rows.add(
        MapEntry(
          '$slotLabel ${t('results.pet.skills.cadence', 'cadence')}',
          _skillCadenceDescription(slotNumber),
        ),
      );
      rows.add(
        MapEntry(
          '$slotLabel ${t('results.pet.skills.values', 'values')}',
          _skillValuesSummary(skill),
        ),
      );
    }
    return _compactInfoList(context, rows);
  }

  String _petBarFlowDescription() => switch (pre.petSkillUsage) {
        PetSkillUsageMode.special1Only => t(
            'pet.skill_usage.special1_only.description',
            'Always fills once and uses Skill 1.',
          ),
        PetSkillUsageMode.special2Only => t(
            'pet.skill_usage.special2_only.description',
            'Always fills to Skill 2 and uses it.',
          ),
        PetSkillUsageMode.cycleSpecial1Then2 => t(
            'pet.skill_usage.cycle_special1_then2.description',
            'Alternates Skill 1 and Skill 2 continuously.',
          ),
        PetSkillUsageMode.special2ThenSpecial1 => t(
            'pet.skill_usage.special2_then_special1.description',
            'Starts with Skill 2 once, then continues with Skill 1.',
          ),
        PetSkillUsageMode.doubleSpecial2ThenSpecial1 => t(
            'pet.skill_usage.double_special2_then_special1.description',
            'Starts with Skill 2 twice, then continues with Skill 1.',
          ),
      };

  String _petBarCyclePreview() => switch (pre.petSkillUsage) {
        PetSkillUsageMode.special1Only => '1, 1, 1, ...',
        PetSkillUsageMode.special2Only => '2, 2, 2, ...',
        PetSkillUsageMode.cycleSpecial1Then2 => '1, 2, 1, 2, ...',
        PetSkillUsageMode.special2ThenSpecial1 => '2, 1, 1, 1, ...',
        PetSkillUsageMode.doubleSpecial2ThenSpecial1 => '2, 2, 1, 1, 1, ...',
      };

  String _skillCadenceDescription(int slotNumber) {
    final slot1 = slotNumber == 1;
    return switch (pre.petSkillUsage) {
      PetSkillUsageMode.special1Only => slot1
          ? t(
              'results.pet.skills.cadence.s1_always',
              'Used on every pet cast.',
            )
          : t(
              'results.pet.skills.cadence.s2_never',
              'Not used in this pet bar setup.',
            ),
      PetSkillUsageMode.special2Only => slot1
          ? t(
              'results.pet.skills.cadence.s1_never',
              'Not used in this pet bar setup.',
            )
          : t(
              'results.pet.skills.cadence.s2_always',
              'Used on every pet cast.',
            ),
      PetSkillUsageMode.cycleSpecial1Then2 => slot1
          ? t(
              'results.pet.skills.cadence.s1_alt',
              'Used on alternating casts (1st, 3rd, 5th...).',
            )
          : t(
              'results.pet.skills.cadence.s2_alt',
              'Used on alternating casts (2nd, 4th, 6th...).',
            ),
      PetSkillUsageMode.special2ThenSpecial1 => slot1
          ? t(
              'results.pet.skills.cadence.s1_after_open',
              'Used from the 2nd cast onward.',
            )
          : t(
              'results.pet.skills.cadence.s2_open_once',
              'Used only on the 1st cast.',
            ),
      PetSkillUsageMode.doubleSpecial2ThenSpecial1 => slot1
          ? t(
              'results.pet.skills.cadence.s1_after_double_open',
              'Used from the 3rd cast onward.',
            )
          : t(
              'results.pet.skills.cadence.s2_open_twice',
              'Used on the 1st and 2nd casts.',
            ),
    };
  }

  PetResolvedEffect? _resolvedEffectForSkill(SetupPetSkillSnapshot skill) {
    final canonical = (skill.canonicalEffectId ?? '').trim().toLowerCase();
    if (canonical.isNotEmpty) {
      for (final effect in petEffects) {
        if (effect.canonicalEffectId.trim().toLowerCase() == canonical) {
          return effect;
        }
      }
    }
    final slotId = skill.slotId.trim().toLowerCase();
    if (slotId.isEmpty) return null;
    for (final effect in petEffects) {
      if (effect.sourceSlotId.trim().toLowerCase() == slotId) {
        return effect;
      }
    }
    return null;
  }

  String _skillBehaviorDescription(SetupPetSkillSnapshot skill) {
    final canonical = (skill.canonicalEffectId ?? '').trim().toLowerCase();
    final category =
        (_resolvedEffectForSkill(skill)?.effectCategory ?? '').toLowerCase();
    return switch (canonical) {
      'elemental_weakness' => t(
          'results.pet.skills.behavior.elemental_weakness',
          'Reduces boss ATK for the configured number of boss turns.',
        ),
      'special_regeneration' || 'special_regeneration_infinite' => t(
          'results.pet.skills.behavior.special_regeneration',
          'Builds or boosts knight special meter to accelerate SPECIAL turns.',
        ),
      'durable_rock_shield' => t(
          'results.pet.skills.behavior.drs',
          'Boosts knight DEF while the shield buff is active.',
        ),
      'shatter_shield' => t(
          'results.pet.skills.behavior.shatter',
          'Adds shatter shield HP (base + bonus) when triggered.',
        ),
      'cyclone_boost_air' || 'cyclone_boost_earth' => t(
          'results.pet.skills.behavior.cyclone',
          'Applies cyclone damage boost during the cyclone phase.',
        ),
      _ => switch (category) {
          'boss_attack_debuff' => t(
              'results.pet.skills.behavior.category_boss_debuff',
              'Applies a boss ATK debuff while active.',
            ),
          'special_meter_acceleration' => t(
              'results.pet.skills.behavior.category_meter',
              'Accelerates knight special meter gain.',
            ),
          'knight_defense_buff' => t(
              'results.pet.skills.behavior.category_def_buff',
              'Temporarily boosts knight DEF.',
            ),
          'damage_absorb_shield' => t(
              'results.pet.skills.behavior.category_shield',
              'Creates a shield that absorbs incoming damage.',
            ),
          _ => t(
              'results.pet.skills.behavior.fallback',
              'Uses the imported effect values shown in this row.',
            ),
        },
    };
  }

  Widget _petAbilityRecap(BuildContext context) {
    final sections = <Widget>[];
    if (_effectivePetEffects.isEmpty) {
      return _dataTable(
        minWidth: 520,
        columns: [t('param', 'Param'), t('value', 'Value')],
        rows: [
          [
            t('results.pet_ability.none', 'No pet skills selected.'),
            '-',
          ],
        ],
      );
    }

    sections.add(
      _dataTable(
        minWidth: 520,
        columns: [t('param', 'Param'), t('value', 'Value')],
        rows: [
          [
            t(
              'results.pet_ability.skill_driven',
              'Uses the selected pet skills and pet bar sequence.',
            ),
            _petSkillUsageLabel,
          ],
        ],
      ),
    );

    if (_hasSr) {
      sections.add(const SizedBox(height: 8));
      sections.add(_srRecapTable(withEw: _hasEw));
    }
    if (_hasEw) {
      sections.add(const SizedBox(height: 8));
      sections.add(_ewRecapTable(context));
    }
    if (_hasShatter) {
      final shatterFromPetBar = pre.meta.petTicksBar.enabled &&
          pre.meta.petTicksBar.useInShatterShield;
      sections.add(const SizedBox(height: 8));
      sections.add(
        _dataTable(
          minWidth: 560,
          columns: [t('param', 'Param'), t('value', 'Value')],
          rows: [
            if (shatterFromPetBar) ...[
              [t('results.pet_ability.start_fill', 'Starting bar'), '1 / 2'],
              [
                t('results.pet_ability.shatter.trigger', 'Trigger'),
                t(
                  'results.pet_ability.shatter.trigger_special2',
                  'Pet Special 2 (2/2)',
                ),
              ],
            ] else ...[
              [
                t('results.pet_ability.shatter.first', 'First trigger'),
                '${t('results.pet_ability.turn', 'every')} ${pre.meta.hitsToFirstShatter}',
              ],
              [
                t('results.pet_ability.shatter.next', 'Next trigger'),
                '${t('results.pet_ability.turn', 'every')} ${pre.meta.hitsToNextShatter}',
              ],
            ],
            [
              t('results.shatter.base', 'Shatter base HP'),
              _fmtInt(shatter?.baseHp ?? 0),
            ],
            [
              t('results.shatter.bonus', 'Shatter bonus HP'),
              _fmtInt(shatter?.bonusHp ?? 0),
            ],
          ],
        ),
      );
    }
    if (_hasCyclone) {
      final boostPct = resolvedCycloneBoostPct(
        pre.petEffects,
        fallback: pre.meta.cyclone,
      );
      sections.add(const SizedBox(height: 8));
      sections.add(
        _dataTable(
          minWidth: 560,
          columns: [t('param', 'Param'), t('value', 'Value')],
          rows: [
            [
              t('results.pet_ability.cyclone.boost', 'Boost'),
              '${boostPct.toStringAsFixed(3)}%',
            ],
            [
              t('results.pet_ability.cyclone.turn_cap', 'Turn cap'),
              t('turn_5_plus', 'Turn 5+'),
            ],
            [
              cycloneUseGemsForSpecials
                  ? t(
                      'results.cyclone.gem_rule',
                      'Always gemmed: 4 gems per knight turn.',
                    )
                  : t(
                      'results.cyclone.pet_bar_rule',
                      'Uses the normal pet bar flow and selected pet skill usage.',
                    ),
              cycloneUseGemsForSpecials
                  ? (_averageCycloneGemsSpent == null
                      ? '-'
                      : t(
                          'results.cyclone.gems_spent_value',
                          '{value} gems',
                        ).replaceAll(
                          '{value}',
                          _fmtCompact(_averageCycloneGemsSpent!),
                        ))
                  : t(
                      'results.cyclone.avg_gems_off',
                      'No forced gem usage.',
                    ),
            ],
          ],
        ),
      );
      sections.add(const SizedBox(height: 8));
      sections.add(_cycloneDamageTable(context));
    }
    if (_hasDrs) {
      sections.add(const SizedBox(height: 8));
      sections.add(_drsRecapTable(context));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _srRecapTable({required bool withEw}) {
    final first =
        withEw ? pre.meta.knightToSpecialSREW : pre.meta.knightToSpecialSR;
    final second = first +
        (withEw
            ? pre.meta.knightToRecastSpecialSREW
            : pre.meta.knightToRecastSpecialSR);

    final rows = <List<String>>[];
    for (int i = 0; i < _knightCount; i++) {
      final petMatch = _petMatchForKnightIdx(i);
      final petMatchLabel = petMatch == null
          ? '-'
          : (petMatch ? t('results.yes', 'Yes') : t('results.no', 'No'));
      final requirement = switch (petMatch) {
        true => t('results.pet_ability.sr.requirement_match', '1 activation'),
        false =>
          t('results.pet_ability.sr.requirement_no_match', '2 activations'),
        null => t(
            'results.pet_ability.sr.requirement',
            '1 activation (pet match) / 2 activations (no match)',
          ),
      };
      rows.add([
        _knightLabel(i),
        petMatchLabel,
        requirement,
        'KT#$first',
        'KT#$second',
      ]);
    }
    return _dataTable(
      minWidth: 760,
      columns: [
        t('knight', 'Knight'),
        t('results.pet_ability.sr.pet_match', 'Pet match'),
        t('results.pet_ability.sr.infinite', 'Infinite special requirement'),
        t('results.pet_ability.sr.trigger_1', 'Trigger #1'),
        t('results.pet_ability.sr.trigger_2', 'Trigger #2'),
      ],
      rows: rows,
    );
  }

  Widget _ewRecapTable(BuildContext context) {
    final importedReductionRaw = _effectValue(
      'elemental_weakness',
      'enemyAttackReductionPercent',
    );
    final baseReduction =
        ((importedReductionRaw ?? pre.meta.defaultElementalWeakness) <= 1.0
                ? (importedReductionRaw ?? pre.meta.defaultElementalWeakness)
                    .toDouble()
                : (importedReductionRaw ?? pre.meta.defaultElementalWeakness)
                        .toDouble() /
                    100.0)
            .clamp(0.0, 1.0);
    final durationTurns = (_effectValue('elemental_weakness', 'turns') ??
            pre.meta.durationElementalWeakness)
        .round();
    final strongStacks = pre.meta.strongElementEW.round().clamp(1, 10);
    final strongReduction =
        (1.0 - _pow(1.0 - baseReduction, strongStacks)).clamp(0.0, 1.0);
    final ewFromPetBar = pre.meta.petTicksBar.enabled &&
        pre.meta.petTicksBar.useInSpecialRegenPlusEw;
    final ewIntervalText = ewFromPetBar
        ? t(
            'results.pet_ability.ew.interval_pet_bar',
            'pet Special 1 trigger',
          )
        : '${t('results.pet_ability.turn', 'every')} ${pre.meta.hitsToElementalWeakness}';

    final summaryRows = <List<String>>[
      [
        t('results.pet_ability.ew.reduction_stack', 'EW reduction per stack'),
        _fmtPct(baseReduction),
      ],
      [
        t('results.pet_ability.ew.interval', 'EW interval'),
        ewIntervalText,
      ],
      [
        t('results.pet_ability.ew.duration', 'EW duration'),
        '$durationTurns ${t('results.pet_ability.turns', 'turns')}',
      ],
      [
        t('results.pet_ability.ew.strong_multiplier',
            'Strong-element EW multiplier'),
        'x${pre.meta.strongElementEW.toStringAsFixed(2)}',
      ],
      [
        t('results.pet_ability.ew.strong_stacks',
            'Strong EW stacks per trigger'),
        strongStacks.toString(),
      ],
    ];

    final columns = <String>[
      t('knight', 'Knight'),
      t('results.pet_ability.ew.boss_n_no', 'Boss N (no EW)'),
      t('results.pet_ability.ew.boss_c_no', 'Boss C (no EW)'),
      t('results.pet_ability.ew.boss_n', 'Boss N (EW 1 stack)'),
      t('results.pet_ability.ew.boss_c', 'Boss C (EW 1 stack)'),
    ];
    final includeStrong = (strongReduction - baseReduction).abs() > 1e-9;
    if (includeStrong) {
      columns.addAll([
        t('results.pet_ability.ew.boss_n_strong', 'Boss N (EW strong)'),
        t('results.pet_ability.ew.boss_c_strong', 'Boss C (EW strong)'),
      ]);
    }

    final incomingRows = <List<String>>[];
    for (int i = 0; i < _knightCount; i++) {
      final noN = _bossIncomingNormal(i, reduction: 0.0);
      final noC = _bossIncomingCrit(i, reduction: 0.0);
      final ewN = _bossIncomingNormal(i, reduction: baseReduction);
      final ewC = _bossIncomingCrit(i, reduction: baseReduction);
      final row = <String>[
        _knightLabel(i),
        _fmtInt(noN),
        _fmtInt(noC),
        _fmtInt(ewN),
        _fmtInt(ewC),
      ];
      if (includeStrong) {
        row.add(_fmtInt(_bossIncomingNormal(i, reduction: strongReduction)));
        row.add(_fmtInt(_bossIncomingCrit(i, reduction: strongReduction)));
      }
      incomingRows.add(row);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dataTable(
          minWidth: 320,
          columnSpacing: 8,
          horizontalMargin: 2,
          columns: [t('param', 'Param'), t('value', 'Value')],
          rows: summaryRows,
        ),
        const SizedBox(height: 8),
        _dataTable(
          minWidth: includeStrong ? 1040 : 860,
          columns: columns,
          rows: incomingRows,
        ),
      ],
    );
  }

  Widget _drsRecapTable(BuildContext context) {
    final importedBoostRaw = _effectValue(
      'durable_rock_shield',
      'defenseBoostPercent',
    );
    final baseBoostRaw =
        (importedBoostRaw ?? pre.meta.defaultDurableRockShield).toDouble();
    final baseBoostFraction =
        (baseBoostRaw <= 1.0 ? baseBoostRaw : baseBoostRaw / 100.0)
            .clamp(0.0, 10.0);
    final baseBoostDisplay = (baseBoostFraction * 100.0).clamp(0.0, 1000.0);
    final durationTurns =
        (_effectValue('durable_rock_shield', 'turns') ?? pre.meta.durationDRS)
            .round();
    final sameElementMult =
        pre.meta.sameElementDRS <= 0 ? 1.0 : pre.meta.sameElementDRS;

    final perKnightColumns = <String>[
      t('param', 'Param'),
      for (int i = 0; i < _knightCount; i++) _knightLabel(i),
    ];
    final perKnightRows = <List<String>>[];
    final effectiveBoostByKnight = <double>[];
    final defMultiplierByKnight = <double>[];
    final petMatchLabelByKnight = <String>[];
    for (int i = 0; i < _knightCount; i++) {
      final petMatch = _petMatchForKnightIdx(i);
      final hasMatch = petMatch ?? false;
      final boost = baseBoostFraction * (hasMatch ? sameElementMult : 1.0);
      effectiveBoostByKnight.add(boost);
      defMultiplierByKnight.add(
        _drsDefenseMultiplierForKnight(
          baseBoostFraction: baseBoostFraction,
          hasMatch: hasMatch,
          sameElementMultiplier: sameElementMult,
        ),
      );
      petMatchLabelByKnight.add(
        petMatch == null
            ? '-'
            : (petMatch ? t('results.yes', 'Yes') : t('results.no', 'No')),
      );
    }
    perKnightRows.add([
      t('results.pet_ability.drs.pet_match', 'Pet match'),
      ...petMatchLabelByKnight,
    ]);
    perKnightRows.add([
      t('results.pet_ability.drs.boost_effective', 'Effective DRS boost'),
      for (final v in effectiveBoostByKnight) _fmtPct(v),
    ]);
    perKnightRows.add([
      t('results.pet_ability.drs.def_multiplier', 'Defense multiplier'),
      for (final v in defMultiplierByKnight) 'x${v.toStringAsFixed(2)}',
    ]);

    final summaryRows = <List<String>>[
      [
        t('results.pet_ability.drs.boost', 'Defense boost'),
        '${_formatSkillValue(baseBoostDisplay)}%',
      ],
      [
        t(
          _drsUsesPetBar
              ? 'results.pet_ability.shatter.trigger'
              : 'results.pet_ability.drs.interval',
          _drsUsesPetBar ? 'Trigger' : 'Activation interval',
        ),
        _drsUsesPetBar
            ? t(
                'results.pet_ability.drs.pet_bar_trigger',
                'Pet bar cast sequence ({usage})',
              ).replaceAll('{usage}', _petSkillUsageLabel)
            : '${t('results.pet_ability.turn', 'every')} ${pre.meta.hitsToDRS}',
      ],
      [
        t('results.pet_ability.drs.duration', 'Duration'),
        '$durationTurns ${t('results.pet_ability.turns', 'turns')}',
      ],
      if (_drsUsesPetBar)
        [
          t('results.pet_ability.drs.refresh', 'Recast'),
          t(
            'results.pet_ability.drs.refresh_value',
            'Refreshing the cast renews the active duration.',
          ),
        ],
      [
        t('results.pet_ability.drs.same_element', 'Same-element multiplier'),
        'x${sameElementMult.toStringAsFixed(2)}',
      ],
    ];

    final columns = <String>[
      t('knight', 'Knight'),
      t('results.pet_ability.drs.pet_match', 'Pet match'),
      t('results.pet_ability.drs.boost_effective', 'Effective DRS boost'),
      t('results.pet_ability.drs.boss_n_no', 'Boss N (no DRS)'),
      t('results.pet_ability.drs.boss_c_no', 'Boss C (no DRS)'),
      t('results.pet_ability.drs.boss_n', 'Boss N (DRS)'),
      t('results.pet_ability.drs.boss_c', 'Boss C (DRS)'),
      t('results.pet_ability.drs.boss_n_reduction', 'N reduction'),
      t('results.pet_ability.drs.boss_c_reduction', 'C reduction'),
    ];

    final rows = <List<String>>[];
    for (int i = 0; i < _knightCount; i++) {
      final boost = effectiveBoostByKnight[i];
      final defMult = defMultiplierByKnight[i];
      final noN =
          _bossIncomingWithDefMultiplier(i, defMultiplier: 1.0, crit: false);
      final noC =
          _bossIncomingWithDefMultiplier(i, defMultiplier: 1.0, crit: true);
      final withN = _bossIncomingWithDefMultiplier(
        i,
        defMultiplier: defMult,
        crit: false,
      );
      final withC = _bossIncomingWithDefMultiplier(
        i,
        defMultiplier: defMult,
        crit: true,
      );
      final redN = (noN <= 0) ? 0.0 : (1.0 - (withN / noN)).clamp(0.0, 1.0);
      final redC = (noC <= 0) ? 0.0 : (1.0 - (withC / noC)).clamp(0.0, 1.0);

      rows.add([
        _knightLabel(i),
        petMatchLabelByKnight[i],
        _fmtPct(boost),
        _fmtInt(noN),
        _fmtInt(noC),
        _fmtInt(withN),
        _fmtInt(withC),
        _fmtPct(redN),
        _fmtPct(redC),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _dataTable(
          minWidth: 220.0 + (120.0 * _knightCount),
          columns: perKnightColumns,
          rows: perKnightRows,
        ),
        const SizedBox(height: 8),
        _dataTable(
          minWidth: 560,
          columns: [t('param', 'Param'), t('value', 'Value')],
          rows: summaryRows,
        ),
        const SizedBox(height: 8),
        _dataTable(
          minWidth: 1180,
          columns: columns,
          rows: rows,
        ),
      ],
    );
  }

  int _bossIncomingNormal(int idx, {required double reduction}) {
    final base =
        (idx >= 0 && idx < pre.bNormalDmg.length) ? pre.bNormalDmg[idx] : 0;
    return _bossIncomingWithEw(base, reduction: reduction);
  }

  int _bossIncomingCrit(int idx, {required double reduction}) {
    final base =
        (idx >= 0 && idx < pre.bCritDmg.length) ? pre.bCritDmg[idx] : 0;
    return _bossIncomingWithEw(base, reduction: reduction);
  }

  int _bossIncomingWithEw(int base, {required double reduction}) {
    if (base <= 0) return 0;
    final red = reduction.clamp(0.0, 1.0);
    if (red <= 0) return base;
    final mult = 1.0 - red;
    if (mult <= 0) return 1;
    return math.max(1, (base * mult).floor());
  }

  int _bossIncomingWithDefMultiplier(
    int idx, {
    required double defMultiplier,
    required bool crit,
  }) {
    if (idx < 0 || idx >= pre.kDef.length) return 0;
    final defBase = pre.kDef[idx] <= 0 ? 1.0 : pre.kDef[idx];
    final defMult = defMultiplier <= 0 ? 1.0 : defMultiplier;
    final def = defBase * defMult;
    final adv = (idx >= 0 && idx < pre.meta.advVsKnights.length)
        ? pre.meta.advVsKnights[idx]
        : 1.0;
    final raw = ((pre.stats.attack / def) * 120.0) * _advMul(adv);
    final normal = raw.floor();
    if (crit) {
      final critMult =
          pre.meta.criticalMultiplier <= 0 ? 1.5 : pre.meta.criticalMultiplier;
      return math.max(0, (normal * critMult).round());
    }
    return math.max(0, normal);
  }

  double _drsDefenseMultiplierForKnight({
    required double baseBoostFraction,
    required bool hasMatch,
    required double sameElementMultiplier,
  }) {
    final baseBoost = baseBoostFraction.clamp(0.0, 10.0);
    final sameMult = sameElementMultiplier <= 0 ? 1.0 : sameElementMultiplier;
    final effectiveBoost = baseBoost * (hasMatch ? sameMult : 1.0);
    final nonlinearDef = math.pow(1.0 + effectiveBoost, 2.0).toDouble();
    final matchAmplifier = hasMatch ? sameMult : 1.0;
    final out = nonlinearDef * matchAmplifier;
    if (!out.isFinite || out <= 0) return 1.0;
    return out;
  }

  double _advMul(double adv) {
    if ((adv - 1.5).abs() < 1e-9) return 1.5;
    if ((adv - 2.0).abs() < 1e-9) return 2.0;
    return 1.0;
  }

  bool? _petMatchForKnightIdx(int idx) {
    if (idx < 0 || idx >= knightElementPairs.length) return null;
    final pair = knightElementPairs[idx];
    if (pair.isEmpty) return null;

    final pet = <String>{
      petElement1Id.trim(),
      (petElement2Id ?? '').trim(),
    }.where((e) => e.isNotEmpty && e != 'empty' && e != 'none').toSet();
    if (pet.isEmpty) return null;

    final knight = <String>{
      if (pair.isNotEmpty) pair[0].trim(),
      if (pair.length > 1) pair[1].trim(),
    }.where((e) => e.isNotEmpty && e != 'empty' && e != 'none').toSet();
    if (knight.isEmpty) return null;

    return pet.any(knight.contains);
  }

  Future<void> _showTablesScrollTip(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          t('results.tables_scroll_tip_title', 'Table scroll tip'),
        ),
        content: Text(
          t(
            'results.tables_scroll_tip_body',
            'You can scroll or swipe horizontally on the tables to view all data.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('cancel', 'Close')),
          ),
        ],
      ),
    );
  }

  Widget _tableScrollTipButton(BuildContext context) {
    final title = t('results.tables_scroll_tip_title', 'Table scroll tip');
    return IconButton(
      tooltip: title,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 24, height: 24),
      icon: Icon(
        Icons.info_outline,
        size: 18,
        semanticLabel: title,
      ),
      onPressed: () => _showTablesScrollTip(context),
    );
  }

  String _elementLabelFromId(String? id) {
    final raw = id?.trim() ?? '';
    if (raw.isEmpty || raw == 'empty' || raw == 'none' || raw == 'null') {
      return t('pet.element.empty', 'Empty');
    }
    switch (raw) {
      case 'fire':
        return t('element.fire', 'Fire');
      case 'spirit':
        return t('element.spirit', 'Spirit');
      case 'earth':
        return t('element.earth', 'Earth');
      case 'air':
        return t('element.air', 'Air');
      case 'water':
        return t('element.water', 'Water');
      case 'starmetal':
        return t('element.starmetal', 'Starmetal');
      default:
        return raw;
    }
  }

  Future<void> _copyExport(BuildContext context) async {
    final packageInfo = await _loadPackageInfo();
    final payload = _exportPayload(
      appVersion: packageInfo?.version,
      appBuildNumber: packageInfo?.buildNumber,
    );
    final text = encodePrettyJson(payload);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t('results.export_copied', 'Export copied')),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<PackageInfo?> _loadPackageInfo() async {
    try {
      return await PackageInfo.fromPlatform();
    } catch (_) {
      return null;
    }
  }

  Map<String, Object?> _exportPayload({
    String? appVersion,
    String? appBuildNumber,
  }) =>
      ResultsSharePayload(
        cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
        isPremium: isPremium,
        debugEnabled: debugEnabled,
        milestoneTargetPoints: milestoneTargetPoints,
        startEnergies: startEnergies,
        freeRaidEnergies: freeRaidEnergies,
        knightIds: knightIds,
        shatter: shatter,
        pre: pre,
        stats: stats,
        elixirs: elixirs,
        petElement1Id: petElement1Id,
        petElement2Id: petElement2Id,
        knightElementPairs: knightElementPairs,
        exportedAtIso: DateTime.now().toIso8601String(),
        appVersion: appVersion,
        appBuildNumber: appBuildNumber,
      ).toJson();

  Future<void> _showResultsShareTip(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('results.share_tip.title', 'Share tip')),
        content: Text(
          t(
            'results.share_tip.body',
            'Use the copy button to export this report as JSON. Another user can import it from Home > Utilities > Import results to review the same report locally.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('cancel', 'Close')),
          ),
        ],
      ),
    );
  }

  Widget _bossTable(BuildContext context) {
    final isRaid = pre.meta.raidMode;

    final columns = <String>[
      t('boss.level', 'Boss Level'),
      t('atk', 'ATK'),
      t('def', 'DEF'),
      t('hp', 'HP'),
      t('results.battle_type', 'Battle'),
    ];
    final row = <String>[
      pre.meta.level.toString(),
      _fmtInt(pre.stats.attack),
      _fmtInt(pre.stats.defense),
      _fmtInt(pre.stats.hp),
      isRaid ? t('raid', 'Raid') : t('blitz', 'Blitz'),
    ];

    return _dataTable(
      minWidth: 540,
      columns: columns,
      rows: [row],
    );
  }

  Widget _bossIncomingPressureTable(BuildContext context) {
    final rows = <List<String>>[];
    for (int i = 0; i < _knightCount; i++) {
      final adv =
          i < pre.meta.advVsKnights.length ? pre.meta.advVsKnights[i] : 1;
      final normal = i < pre.bNormalDmg.length ? pre.bNormalDmg[i] : 0;
      final crit = i < pre.bCritDmg.length ? pre.bCritDmg[i] : 0;
      rows.add([
        _knightLabel(i),
        _fmtAdv(adv.toDouble()),
        _fmtInt(normal),
        _fmtInt(crit),
      ]);
    }
    return _dataTable(
      minWidth: 660,
      columns: [
        t('knight', 'Knight'),
        t('advantage', 'Advantage'),
        t('dmg_from_boss_normal', 'Boss -> K (normal)'),
        t('dmg_from_boss_crit', 'Boss -> K (crit)'),
      ],
      rows: rows,
    );
  }

  Widget _knightsTable(
    BuildContext context, {
    bool graphViewEnabled = false,
    required _KnightChartVisualMode outgoingChartMode,
    required ValueChanged<_KnightChartVisualMode> onOutgoingChartModeChanged,
    required _KnightChartVisualMode incomingChartMode,
    required ValueChanged<_KnightChartVisualMode> onIncomingChartModeChanged,
  }) {
    final outgoingCategories = List<String>.generate(
      _knightCount,
      _knightLabel,
      growable: false,
    );
    final outgoingSeries = <BarChartSeries>[
      BarChartSeries(
        label: t('results.charts.series.normal', 'Normal'),
        color: const Color(0xFF3B82F6),
        values: pre.kNormalDmg.map((value) => value.toDouble()).toList(
              growable: false,
            ),
      ),
      BarChartSeries(
        label: t('results.charts.series.crit', 'Crit'),
        color: const Color(0xFFF59E0B),
        values: pre.kCritDmg.map((value) => value.toDouble()).toList(
              growable: false,
            ),
      ),
      BarChartSeries(
        label: t('results.charts.series.special', 'Special'),
        color: const Color(0xFF10B981),
        values: pre.kSpecialDmg.map((value) => value.toDouble()).toList(
              growable: false,
            ),
      ),
    ];
    final incomingCategories = List<String>.generate(
      _knightCount,
      _knightLabel,
      growable: false,
    );
    final incomingSeries = <BarChartSeries>[
      BarChartSeries(
        label: t('results.charts.series.boss_n', 'Boss N'),
        color: const Color(0xFF8B5CF6),
        values: pre.bNormalDmg.map((value) => value.toDouble()).toList(
              growable: false,
            ),
      ),
      BarChartSeries(
        label: t('results.charts.series.boss_c', 'Boss C'),
        color: const Color(0xFFEF4444),
        values: pre.bCritDmg.map((value) => value.toDouble()).toList(
              growable: false,
            ),
      ),
    ];
    final contributionTotals = _estimatedKnightContributionTotals;
    final contributionTotal = contributionTotals == null
        ? 0.0
        : contributionTotals.fold<double>(0.0, (sum, value) => sum + value);
    const contributionColors = <Color>[
      Color(0xFF2563EB),
      Color(0xFF10B981),
      Color(0xFFF59E0B),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (graphViewEnabled) ...[
          ResultsChartCard(
            key: const ValueKey('results.chart.knight_outgoing'),
            title: t('results.charts.knight_outgoing.title', 'Outgoing Damage'),
            subtitle: t(
              'results.charts.knight_outgoing.subtitle',
              'Compare each knight normal, crit and special output.',
            ),
            helpTooltip: t(
              'results.charts.knight_outgoing.help',
              'Compares each knight normal, crit and special damage against the boss. Longer bars mean higher outgoing damage.',
            ),
            legend: [
              ResultsChartLegendChip(
                color: Color(0xFF3B82F6),
                label: t('results.charts.series.normal', 'Normal'),
              ),
              ResultsChartLegendChip(
                color: Color(0xFFF59E0B),
                label: t('results.charts.series.crit', 'Crit'),
              ),
              ResultsChartLegendChip(
                color: Color(0xFF10B981),
                label: t('results.charts.series.special', 'Special'),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chartModeToggle(
                  context,
                  keyPrefix: 'results.chart.knight_outgoing',
                  mode: outgoingChartMode,
                  onChanged: onOutgoingChartModeChanged,
                ),
                const SizedBox(height: 10),
                if (outgoingChartMode == _KnightChartVisualMode.bars)
                  KeyedSubtree(
                    key: const ValueKey('results.chart.knight_outgoing.bars'),
                    child: GroupedHorizontalBarChart(
                      categories: outgoingCategories,
                      series: outgoingSeries,
                      formatValue: _fmtInt,
                      scaleMode: GroupedBarScaleMode.perSeriesZoom,
                    ),
                  )
                else
                  KeyedSubtree(
                    key: const ValueKey(
                      'results.chart.knight_outgoing.histogram',
                    ),
                    child: GroupedVerticalBarChart(
                      categories: outgoingCategories,
                      series: outgoingSeries,
                      xAxisLabel: t('results.knights.title', 'Knights'),
                      yAxisLabel: t('results.charts.knight_outgoing.title',
                          'Outgoing Damage'),
                      emptyLabel: t(
                        'results.charts.empty',
                        'No chart data available.',
                      ),
                      formatValue: _fmtInt,
                      scaleMode: GroupedBarScaleMode.perSeriesZoom,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ResultsChartCard(
            key: const ValueKey('results.chart.knight_incoming'),
            title:
                t('results.charts.knight_incoming.title', 'Incoming Pressure'),
            subtitle: t(
              'results.charts.knight_incoming.subtitle',
              'Shows how much boss damage each knight absorbs.',
            ),
            helpTooltip: t(
              'results.charts.knight_incoming.help',
              'Shows incoming boss damage per knight. Longer bars mean that knight is under more pressure and needs more survivability.',
            ),
            legend: [
              ResultsChartLegendChip(
                color: Color(0xFF8B5CF6),
                label: t(
                  'results.charts.series.boss_normal',
                  'Boss normal',
                ),
              ),
              ResultsChartLegendChip(
                color: Color(0xFFEF4444),
                label: t('results.charts.series.boss_crit', 'Boss crit'),
              ),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _chartModeToggle(
                  context,
                  keyPrefix: 'results.chart.knight_incoming',
                  mode: incomingChartMode,
                  onChanged: onIncomingChartModeChanged,
                ),
                const SizedBox(height: 10),
                if (incomingChartMode == _KnightChartVisualMode.bars)
                  KeyedSubtree(
                    key: const ValueKey('results.chart.knight_incoming.bars'),
                    child: GroupedHorizontalBarChart(
                      categories: incomingCategories,
                      series: incomingSeries,
                      formatValue: _fmtInt,
                      scaleMode: GroupedBarScaleMode.perSeriesZoom,
                    ),
                  )
                else
                  KeyedSubtree(
                    key: const ValueKey(
                      'results.chart.knight_incoming.histogram',
                    ),
                    child: GroupedVerticalBarChart(
                      categories: incomingCategories,
                      series: incomingSeries,
                      xAxisLabel: t('results.knights.title', 'Knights'),
                      yAxisLabel: t('results.charts.knight_incoming.title',
                          'Incoming Pressure'),
                      emptyLabel: t(
                        'results.charts.empty',
                        'No chart data available.',
                      ),
                      formatValue: _fmtInt,
                      scaleMode: GroupedBarScaleMode.perSeriesZoom,
                    ),
                  ),
              ],
            ),
          ),
          if (graphViewEnabled &&
              _hasPremiumTimingData &&
              contributionTotals != null &&
              contributionTotal > 0) ...[
            const SizedBox(height: 12),
            ResultsChartCard(
              key: const ValueKey('results.chart.knight_contribution'),
              title: t(
                'results.charts.knight_contribution.title',
                'Contribution Share',
              ),
              subtitle: t(
                'results.charts.knight_contribution.subtitle',
                'Estimated share of total knight damage using mean action counts and damage values.',
              ),
              helpTooltip: t(
                'results.charts.knight_contribution.help',
                'This stacked bar estimates how much of the full knight damage comes from each knight, based on mean normal and special action counts plus the current precomputed damage values.',
              ),
              legend: [
                for (int i = 0; i < _knightCount; i++)
                  ResultsChartLegendChip(
                    color: contributionColors[i % contributionColors.length],
                    label: _knightLabel(i),
                    value: contributionTotal <= 0
                        ? '0%'
                        : _fmtPercent(
                            (contributionTotals[i] / contributionTotal) * 100.0,
                          ),
                  ),
              ],
              child: StackedHorizontalBarChart(
                categories: [
                  t('results.charts.knight_contribution.team', 'Team'),
                ],
                segments: [
                  for (int i = 0; i < _knightCount; i++)
                    StackedBarSegment(
                      label: _knightLabel(i),
                      color: contributionColors[i % contributionColors.length],
                      values: [contributionTotals[i]],
                    ),
                ],
                formatValue: _fmtInt,
              ),
            ),
          ],
          const SizedBox(height: 12),
        ],
        for (int i = 0; i < _knightCount; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _knightCard(context, i),
        ],
      ],
    );
  }

  Widget _chartModeToggle(
    BuildContext context, {
    required String keyPrefix,
    required _KnightChartVisualMode mode,
    required ValueChanged<_KnightChartVisualMode> onChanged,
  }) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          key: ValueKey('$keyPrefix.toggle.bars'),
          label: Text(t('results.charts.view.bars', 'Bars')),
          selected: mode == _KnightChartVisualMode.bars,
          onSelected: (_) => onChanged(_KnightChartVisualMode.bars),
          labelStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        ChoiceChip(
          key: ValueKey('$keyPrefix.toggle.histogram'),
          label: Text(t('results.charts.view.histogram', 'Histogram')),
          selected: mode == _KnightChartVisualMode.histogram,
          onSelected: (_) => onChanged(_KnightChartVisualMode.histogram),
          labelStyle: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _knightCard(BuildContext context, int idx) {
    final theme = Theme.of(context);
    return Container(
      key: ValueKey('results.knight.card.$idx'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
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
                  _knightLabel(idx),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _reportTagChip(
                    context,
                    '${t('advantage', 'Advantage')}: ${_fmtAdv(pre.kAdv[idx])}',
                  ),
                  _reportTagChip(
                    context,
                    '${t('stun_chance', 'Stun Chance')}: ${_fmtPct(pre.kStun[idx])}',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _knightSection(
            context,
            title: t('results.knights.loadout', 'Loadout'),
            items: [
              MapEntry(t('atk', 'ATK'), _fmtInt(pre.kAtk[idx])),
              MapEntry(t('def', 'DEF'), _fmtInt(pre.kDef[idx])),
              MapEntry(t('hp', 'HP'), _fmtInt(pre.kHp[idx])),
            ],
          ),
          const SizedBox(height: 12),
          _knightSection(
            context,
            title: t('results.knights.outgoing', 'Damage to boss'),
            items: [
              MapEntry(
                t('dmg_to_boss_normal', 'Hit -> Boss (normal)'),
                _fmtInt(pre.kNormalDmg[idx]),
              ),
              MapEntry(
                t('dmg_to_boss_crit', 'Hit -> Boss (crit)'),
                _fmtInt(pre.kCritDmg[idx]),
              ),
              MapEntry(
                t('dmg_to_boss_special', 'Hit -> Boss (special)'),
                _fmtInt(pre.kSpecialDmg[idx]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _knightSection(
            context,
            title: t('results.knights.incoming', 'Damage from boss'),
            items: [
              MapEntry(
                t('dmg_from_boss_normal', 'Boss -> K (normal)'),
                _fmtInt(pre.bNormalDmg[idx]),
              ),
              MapEntry(
                t('dmg_from_boss_crit', 'Boss -> K (crit)'),
                _fmtInt(pre.bCritDmg[idx]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _knightSection(
    BuildContext context, {
    required String title,
    required List<MapEntry<String, String>> items,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: themedLabelColor(theme),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: theme.colorScheme.surfaceContainerLowest
                .withValues(alpha: 0.55),
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 14,
                    color: theme.colorScheme.outline.withValues(alpha: 0.12),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 7,
                      child: Text(
                        items[i].key,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 4,
                      child: Text(
                        items[i].value,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  String _expectedRange(int meanV) {
    final half = (meanV * _expectedMeanPct);
    final lower = (meanV - half).round();
    final upper = (meanV + half).round();
    final lo = math.max(0, math.min(lower, upper));
    final hi = math.max(0, math.max(lower, upper));
    return '${_fmtInt(lo)} - ${_fmtInt(hi)}';
  }

  Widget _statsTable(BuildContext context, {bool includeElixirs = true}) {
    final expected = _expectedRange(stats.mean);
    final labelColor = themedLabelColor(Theme.of(context));

    final table = _dataTable(
      minWidth: 720,
      columns: [
        t('mean', 'mean'),
        t('median', 'median'),
        t('min', 'min'),
        t('max', 'max'),
        t('expected_range', 'Expected range (+/-8%)'),
      ],
      rows: [
        [
          _fmtInt(stats.mean),
          _fmtInt(stats.median),
          _fmtInt(stats.min),
          _fmtInt(stats.max),
          expected,
        ],
      ],
    );

    if (!includeElixirs || elixirs.isEmpty) return table;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        table,
        const SizedBox(height: 8),
        for (final e in elixirs)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      decoration: TextDecoration.none,
                    ),
                children: [
                  TextSpan(
                    text: e.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                          decoration: TextDecoration.none,
                        ),
                  ),
                  TextSpan(
                    text:
                        ' | +${_fmtInt((stats.mean * e.scoreMultiplier).round())} | '
                        '(+${(e.scoreMultiplier * 100).toStringAsFixed(0)}%, '
                        '${e.durationMinutes}m)',
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _cycloneDamageTable(BuildContext context) {
    final boostPct = resolvedCycloneBoostPct(
      pre.petEffects,
      fallback: pre.meta.cyclone,
    );
    final stepMult = 1.0 + (boostPct / 100.0);

    int dmgAtStacks(int kIdx, int stacks) {
      final clampedStacks = stacks.clamp(0, 5).toInt();
      final mult = _pow(stepMult, clampedStacks);
      return (pre.kSpecialDmg[kIdx] * mult).ceil();
    }

    final rows = <List<String>>[];
    for (int i = 0; i < _knightCount; i++) {
      rows.add([
        _knightLabel(i),
        for (int stacks = 0; stacks <= 5; stacks++)
          _fmtInt(dmgAtStacks(i, stacks)),
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t('boost', 'Boost')}: ${boostPct.toStringAsFixed(3)}%',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 10),
        _dataTable(
          minWidth: 760,
          columns: [
            t('knight', 'Knight'),
            t('results.cyclone.stack_0', '0 stacks'),
            for (int stacks = 1; stacks <= 5; stacks++)
              t(
                'results.cyclone.stack_n',
                '{n} stack(s)',
              ).replaceAll('{n}', stacks.toString()),
          ],
          rows: rows,
        ),
      ],
    );
  }

  static double _pow(double a, int n) {
    double out = 1.0;
    for (int i = 0; i < n; i++) {
      out *= a;
    }
    return out;
  }

  /// Milestone table: 2 columns x 4 rows (linear).
  /// Rows:
  /// - Score/Objective
  /// - Available+Free
  /// - Runs/Packs
  /// - Gems/Leftover
  Widget _milestoneTable2x4(
    BuildContext context,
    int perRun,
    _EnergyPlan p,
  ) {
    return _dataTable(
      minWidth: 520,
      columns: [
        t('milestone.col.metric', 'Metric'),
        t('milestone.col.value', 'Value'),
      ],
      rows: [
        [
          t('milestone.row.score_objective', 'Score / Objective'),
          '${_fmtInt(perRun)}/${_fmtInt(milestoneTargetPoints)}',
        ],
        [
          t('milestone.row.available_free', 'Available + Free'),
          '${_fmtInt(p.extra)} + ${_fmtInt(p.free)}',
        ],
        [
          t('milestone.row.runs_packs', 'Runs needed / Packs to buy'),
          '${_fmtInt(p.runs)}/${_fmtInt(p.packs)}',
        ],
        [
          t('milestone.row.gems_leftover', 'Gems needed / Energy left'),
          '${_fmtInt(p.gems)}/${_fmtInt(p.leftover)}',
        ],
      ],
    );
  }

  Widget _durationsTable(
    BuildContext context, {
    bool showActionBreakdown = true,
  }) {
    final tstats = stats.timing;

    if (!isPremium || tstats == null) {
      final theme = Theme.of(context);
      final isPremiumLocked = !isPremium;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surfaceContainerLow,
          border: Border.all(
            color: theme.colorScheme.outline.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.38 : 0.16,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              isPremiumLocked ? Icons.lock : Icons.info_outline,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isPremiumLocked
                    ? t(
                        'durations.lock',
                        'This section is available with Premium only.\n'
                            'Enable Premium from Home (star icon).',
                      )
                    : t(
                        'durations.unavailable',
                        'Timing data is unavailable for this result set.\n'
                            'Run the simulation again to populate this section.',
                      ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.8),
                    ),
              ),
            ),
          ],
        ),
      );
    }

    final runSeconds = tstats.meanRunSeconds <= 0 ? 1.0 : tstats.meanRunSeconds;
    final petMissRate = tstats.meanPetAttacks <= 0
        ? 0.0
        : (tstats.meanPetMissAttacks / tstats.meanPetAttacks) * 100.0;
    final totalKnightOwnSeconds = tstats.meanKnightSeconds.fold<double>(
      0.0,
      (sum, value) => sum + value,
    );
    final trackedSeconds = tstats.meanBossSeconds + totalKnightOwnSeconds;
    final rawRunSeconds = tstats.meanRunSeconds;
    final timingDeltaSeconds = (rawRunSeconds - trackedSeconds).abs();
    final coveragePct = rawRunSeconds > 0
        ? ((trackedSeconds / rawRunSeconds) * 100.0).clamp(0.0, 100.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t(
            'durations.summary_hint',
            'All values are averaged per run. Read top cards first, then open each knight card.',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 700
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _timingOverviewCard(
                    context,
                    icon: Icons.timer_outlined,
                    label: t(
                        'durations.row.run_time_mean_s', 'Run time (mean) (s)'),
                    value: '${_dash(tstats.meanRunSeconds)} s',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _timingOverviewCard(
                    context,
                    icon: Icons.smart_toy_outlined,
                    label: t('durations.row.boss_time_mean_s',
                        'Boss time (mean/run) (s)'),
                    value: '${_dash(tstats.meanBossSeconds)} s',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _timingOverviewCard(
                    context,
                    icon: Icons.shield_outlined,
                    label: t('durations.row.knight_own_time_s',
                        'Knight own time (s)'),
                    value: '${_dash(totalKnightOwnSeconds)} s',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _timingOverviewCard(
                    context,
                    icon: Icons.pets_outlined,
                    label:
                        '${t('results.charts.pet_impact.avg_casts', 'Avg casts')} / '
                        '${t('results.charts.pet_impact.avg_misses', 'Avg misses')}',
                    value:
                        '${_dash(tstats.meanPetAttacks)} / ${_dash(petMissRate)}%',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _timingOverviewCard(
                    context,
                    icon: Icons.rule_folder_outlined,
                    label: t(
                      'durations.row.tracked_coverage_pct',
                      'Tracked timeline coverage',
                    ),
                    value: '${_dash(coveragePct)}%',
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _timingOverviewCard(
                    context,
                    icon: Icons.straighten_outlined,
                    label: t(
                      'durations.row.timing_delta_s',
                      'Timing delta |run - (boss + knights)| (s)',
                    ),
                    value: '${_dash(timingDeltaSeconds)} s',
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < _knightCount; i++) ...[
          _timingKnightCard(
            context,
            knightIndex: i,
            tstats: tstats,
            runSeconds: runSeconds,
            showActionBreakdown: showActionBreakdown,
          ),
          if (i != _knightCount - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _timingOverviewCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.32 : 0.12,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timingKnightCard(
    BuildContext context, {
    required int knightIndex,
    required TimingStats tstats,
    required double runSeconds,
    required bool showActionBreakdown,
  }) {
    final theme = Theme.of(context);
    final kLabel = _knightLabel(knightIndex);

    double at(List<double> values) =>
        knightIndex < values.length ? values[knightIndex] : 0.0;

    final survivalSeconds = at(tstats.meanSurvivalSeconds);
    final ownSeconds = at(tstats.meanKnightSeconds);
    final survivalPct = (survivalSeconds / runSeconds).clamp(0.0, 1.0) * 100.0;

    final bossNormalSeconds = at(tstats.bNormalSeconds);
    final bossSpecialSeconds = at(tstats.bSpecialSeconds);
    final bossMissSeconds = at(tstats.bMissSeconds);
    final bossVsKnightSeconds =
        bossNormalSeconds + bossSpecialSeconds + bossMissSeconds;
    final contributionTotals = _estimatedKnightContributionTotals;
    final estimatedPoints =
        (contributionTotals != null && knightIndex < contributionTotals.length)
            ? contributionTotals[knightIndex]
            : null;
    final pointsPerOwnSecond = (estimatedPoints != null && ownSeconds > 0)
        ? (estimatedPoints / ownSeconds)
        : null;

    return Container(
      key: ValueKey('results.timing.knight.$kLabel'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.3 : 0.12,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                kLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: theme.colorScheme.primaryContainer
                      .withValues(alpha: 0.55),
                ),
                child: Text(
                  '${_dash(survivalPct)}%',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _timingPill(
                context,
                label: t('durations.row.survival_s', 'Survival (s)'),
                value: '${_dash(survivalSeconds)} s',
              ),
              _timingPill(
                context,
                label:
                    t('durations.row.knight_own_time_s', 'Knight own time (s)'),
                value: '${_dash(ownSeconds)} s',
              ),
              _timingPill(
                context,
                label: t('durations.row.boss_time_mean_s',
                    'Boss time (mean/run) (s)'),
                value: '${_dash(bossVsKnightSeconds)} s',
              ),
              _timingPill(
                context,
                label: t(
                  'durations.row.points_per_own_second',
                  'Points / own sec (est.)',
                ),
                value: pointsPerOwnSecond == null
                    ? '-'
                    : _fmtCompact(pointsPerOwnSecond),
              ),
            ],
          ),
          if (showActionBreakdown) ...[
            const SizedBox(height: 10),
            Text(
              t('results.charts.timing_breakdown.title', 'Timing Breakdown'),
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            _timingActionRow(
              context,
              label: t('durations.row.k_special_sec', 'K special (sec)'),
              count: at(tstats.kSpecialCount),
              seconds: at(tstats.kSpecialSeconds),
              referenceSeconds: ownSeconds,
              color: const Color(0xFF10B981),
            ),
            _timingActionRow(
              context,
              label: t('durations.row.k_normal_sec', 'K normal (sec)'),
              count: at(tstats.kNormalCount),
              seconds: at(tstats.kNormalSeconds),
              referenceSeconds: ownSeconds,
              color: const Color(0xFF3B82F6),
            ),
            _timingActionRow(
              context,
              label: t('durations.row.stun_sec', 'Stun (sec)'),
              count: at(tstats.kStunCount),
              seconds: at(tstats.kStunSeconds),
              referenceSeconds: ownSeconds,
              color: const Color(0xFFF59E0B),
            ),
            _timingActionRow(
              context,
              label: t('durations.row.k_miss_sec', 'K miss (sec)'),
              count: at(tstats.kMissCount),
              seconds: at(tstats.kMissSeconds),
              referenceSeconds: ownSeconds,
              color: const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 8),
            Divider(
              height: 1,
              color: theme.colorScheme.outline.withValues(
                alpha: theme.brightness == Brightness.dark ? 0.35 : 0.15,
              ),
            ),
            const SizedBox(height: 8),
            _timingActionRow(
              context,
              label: t('durations.row.boss_special_sec', 'Boss special (sec)'),
              count: at(tstats.bSpecialCount),
              seconds: bossSpecialSeconds,
              referenceSeconds: bossVsKnightSeconds,
              color: const Color(0xFFEF4444),
            ),
            _timingActionRow(
              context,
              label: t('durations.row.boss_normal_sec', 'Boss normal (sec)'),
              count: at(tstats.bNormalCount),
              seconds: bossNormalSeconds,
              referenceSeconds: bossVsKnightSeconds,
              color: const Color(0xFF8B5CF6),
            ),
            _timingActionRow(
              context,
              label: t('durations.row.boss_miss_sec', 'Boss miss (sec)'),
              count: at(tstats.bMissCount),
              seconds: bossMissSeconds,
              referenceSeconds: bossVsKnightSeconds,
              color: const Color(0xFF6B7280),
            ),
          ],
        ],
      ),
    );
  }

  Widget _timingPill(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.28 : 0.1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _timingActionRow(
    BuildContext context, {
    required String label,
    required double count,
    required double seconds,
    required double referenceSeconds,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final safeReference = referenceSeconds <= 0 ? 1.0 : referenceSeconds;
    final progress = (seconds / safeReference).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: color.withValues(alpha: 0.18),
                ),
                child: Text(
                  'x${_dash(count)}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_dash(seconds)} s',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: progress,
              backgroundColor: color.withValues(alpha: 0.14),
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _durationsSection(
    BuildContext context, {
    required bool graphViewEnabled,
    required _TimingShareVisualMode timingShareVisualMode,
    required ValueChanged<_TimingShareVisualMode>
        onTimingShareVisualModeChanged,
  }) {
    final tstats = stats.timing;
    if (!graphViewEnabled || !_hasPremiumTimingData || tstats == null) {
      return _durationsTable(context, showActionBreakdown: graphViewEnabled);
    }

    const runPacingKnightColors = <Color>[
      Color(0xFF10B981),
      Color(0xFFF59E0B),
      Color(0xFF8B5CF6),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    final bossSeconds =
        tstats.meanBossSeconds.isFinite && tstats.meanBossSeconds > 0
            ? tstats.meanBossSeconds
            : 0.0;
    final knightSeconds = List<double>.generate(
      _knightCount,
      (index) {
        if (index >= tstats.meanKnightSeconds.length) return 0.0;
        final value = tstats.meanKnightSeconds[index];
        if (!value.isFinite || value <= 0) return 0.0;
        return value;
      },
      growable: false,
    );
    final trackedSeconds =
        bossSeconds + knightSeconds.fold(0.0, (sum, value) => sum + value);
    final untrackedSeconds = (tstats.meanRunSeconds - trackedSeconds) > 0.05
        ? (tstats.meanRunSeconds - trackedSeconds)
        : 0.0;
    final survivalSecondsByKnight = List<double>.generate(
      _knightCount,
      (index) => index < tstats.meanSurvivalSeconds.length &&
              tstats.meanSurvivalSeconds[index].isFinite &&
              tstats.meanSurvivalSeconds[index] > 0
          ? tstats.meanSurvivalSeconds[index]
          : 0.0,
      growable: false,
    );
    final lostSecondsByKnight = List<double>.generate(
      _knightCount,
      (index) => index < _survivalGapSeconds!.length &&
              _survivalGapSeconds![index].isFinite &&
              _survivalGapSeconds![index] > 0
          ? _survivalGapSeconds![index]
          : 0.0,
      growable: false,
    );
    final contributionTotals = _estimatedKnightContributionTotals;
    final pointsPerOwnSecond = contributionTotals == null
        ? null
        : List<double>.generate(
            _knightCount,
            (index) {
              final points = index < contributionTotals.length
                  ? contributionTotals[index]
                  : 0.0;
              final time =
                  index < knightSeconds.length ? knightSeconds[index] : 0.0;
              if (!points.isFinite ||
                  points <= 0 ||
                  !time.isFinite ||
                  time <= 0) {
                return 0.0;
              }
              return points / time;
            },
            growable: false,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ResultsChartCard(
          key: const ValueKey('results.chart.run_pacing'),
          title: t(
            'results.charts.run_pacing.title',
            'Run Pacing Mix',
          ),
          subtitle: t(
            'results.charts.run_pacing.subtitle',
            'Shows how average run time is distributed between boss and knight turns.',
          ),
          helpTooltip: t(
            'results.charts.run_pacing.help',
            'This stacked bar shows who owns the timeline in an average run. Large boss share means stronger incoming pressure; larger knight share usually means more offensive uptime.',
          ),
          legend: [
            ResultsChartLegendChip(
              color: const Color(0xFF3B82F6),
              label: t('results.charts.run_pacing.boss', 'Boss'),
              value: '${_dash(bossSeconds)} s',
            ),
            for (int i = 0; i < _knightCount; i++)
              ResultsChartLegendChip(
                color: runPacingKnightColors[i % runPacingKnightColors.length],
                label: _knightLabel(i),
                value: '${_dash(knightSeconds[i])} s',
              ),
            if (untrackedSeconds > 0)
              ResultsChartLegendChip(
                color: const Color(0xFF9CA3AF),
                label: t('results.charts.run_pacing.other', 'Other'),
                value: '${_dash(untrackedSeconds)} s',
              ),
          ],
          child: StackedHorizontalBarChart(
            categories: [
              t('results.charts.run_pacing.run', 'Run'),
            ],
            segments: [
              StackedBarSegment(
                label: t('results.charts.run_pacing.boss', 'Boss'),
                color: const Color(0xFF3B82F6),
                values: [bossSeconds],
              ),
              for (int i = 0; i < _knightCount; i++)
                StackedBarSegment(
                  label: _knightLabel(i),
                  color:
                      runPacingKnightColors[i % runPacingKnightColors.length],
                  values: [knightSeconds[i]],
                ),
              if (untrackedSeconds > 0)
                StackedBarSegment(
                  label: t('results.charts.run_pacing.other', 'Other'),
                  color: const Color(0xFF9CA3AF),
                  values: [untrackedSeconds],
                ),
            ],
            formatValue: (value) => _dash(value.toDouble()),
          ),
        ),
        const SizedBox(height: 12),
        ResultsChartCard(
          key: const ValueKey('results.chart.survival_pressure'),
          title: t(
            'results.charts.survival_pressure.title',
            'Survival Pressure',
          ),
          subtitle: t(
            'results.charts.survival_pressure.subtitle',
            'Shows how much of the average run each knight survives before becoming the defensive bottleneck.',
          ),
          helpTooltip: t(
            'results.charts.survival_pressure.help',
            'Each bar compares survival time against the average run time. A larger loss segment means that knight drops out earlier and is under more defensive pressure.',
          ),
          legend: [
            ResultsChartLegendChip(
              color: const Color(0xFF10B981),
              label: t(
                'results.charts.survival_pressure.survived',
                'Survived',
              ),
            ),
            ResultsChartLegendChip(
              color: const Color(0xFFEF4444),
              label: t(
                'results.charts.survival_pressure.lost',
                'Lost before end',
              ),
            ),
          ],
          child: StackedHorizontalBarChart(
            categories: List<String>.generate(
              _knightCount,
              _knightLabel,
              growable: false,
            ),
            segments: [
              StackedBarSegment(
                label: t(
                  'results.charts.survival_pressure.survived',
                  'Survived',
                ),
                color: const Color(0xFF10B981),
                values: tstats.meanSurvivalSeconds,
              ),
              StackedBarSegment(
                label: t(
                  'results.charts.survival_pressure.lost',
                  'Lost before end',
                ),
                color: const Color(0xFFEF4444),
                values: _survivalGapSeconds!,
              ),
            ],
            formatValue: (value) => _dash(value.toDouble()),
          ),
        ),
        const SizedBox(height: 12),
        ResultsChartCard(
          key: const ValueKey('results.chart.knight_time_share'),
          title: t(
            'results.charts.knight_time_share.title',
            'Knight Survival vs Time Loss',
          ),
          subtitle: t(
            'results.charts.knight_time_share.subtitle',
            'Compare survival share and lost-time share across knights.',
          ),
          helpTooltip: t(
            'results.charts.knight_time_share.help',
            'Use Histogram to compare Survival and Lost seconds side by side. Use Pie to see share distribution per knight.',
          ),
          legend: [
            ResultsChartLegendChip(
              color: const Color(0xFF10B981),
              label: t(
                'results.charts.survival_pressure.survived',
                'Survived',
              ),
            ),
            ResultsChartLegendChip(
              color: const Color(0xFFEF4444),
              label: t(
                'results.charts.survival_pressure.lost',
                'Lost before end',
              ),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    key: const ValueKey(
                        'results.chart.knight_time_share.histogram'),
                    label:
                        Text(t('results.charts.view.histogram', 'Histogram')),
                    selected: timingShareVisualMode ==
                        _TimingShareVisualMode.histogram,
                    onSelected: (_) => onTimingShareVisualModeChanged(
                      _TimingShareVisualMode.histogram,
                    ),
                  ),
                  ChoiceChip(
                    key: const ValueKey('results.chart.knight_time_share.pie'),
                    label: Text(t('results.charts.view.pie', 'Pie')),
                    selected:
                        timingShareVisualMode == _TimingShareVisualMode.pie,
                    onSelected: (_) => onTimingShareVisualModeChanged(
                      _TimingShareVisualMode.pie,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (timingShareVisualMode == _TimingShareVisualMode.histogram)
                GroupedVerticalBarChart(
                  categories: List<String>.generate(
                    _knightCount,
                    _knightLabel,
                    growable: false,
                  ),
                  series: [
                    BarChartSeries(
                      label: t(
                        'results.charts.survival_pressure.survived',
                        'Survived',
                      ),
                      color: const Color(0xFF10B981),
                      values: survivalSecondsByKnight,
                    ),
                    BarChartSeries(
                      label: t(
                        'results.charts.survival_pressure.lost',
                        'Lost before end',
                      ),
                      color: const Color(0xFFEF4444),
                      values: lostSecondsByKnight,
                    ),
                  ],
                  xAxisLabel: t('results.knights.title', 'Knights'),
                  yAxisLabel: t('seconds', 'Seconds'),
                  emptyLabel: t(
                    'results.charts.empty',
                    'No chart data available.',
                  ),
                  formatValue: (value) => _dash(value.toDouble()),
                  scaleMode: GroupedBarScaleMode.perSeriesZoom,
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width < 560 ? 220 : 250,
                      child: PieDonutChart(
                        slices: List<PieSliceDatum>.generate(
                          _knightCount,
                          (index) => PieSliceDatum(
                            label: _knightLabel(index),
                            color: runPacingKnightColors[
                                index % runPacingKnightColors.length],
                            value: survivalSecondsByKnight[index],
                          ),
                        ),
                        centerLabel: t(
                          'results.charts.survival_pressure.survived',
                          'Survived',
                        ),
                        emptyLabel: t(
                          'results.charts.empty',
                          'No chart data available.',
                        ),
                        formatValue: (value) => '${_dash(value.toDouble())} s',
                      ),
                    ),
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width < 560 ? 220 : 250,
                      child: PieDonutChart(
                        slices: List<PieSliceDatum>.generate(
                          _knightCount,
                          (index) => PieSliceDatum(
                            label: _knightLabel(index),
                            color: runPacingKnightColors[
                                index % runPacingKnightColors.length],
                            value: lostSecondsByKnight[index],
                          ),
                        ),
                        centerLabel: t(
                          'results.charts.survival_pressure.lost',
                          'Lost',
                        ),
                        emptyLabel: t(
                          'results.charts.empty',
                          'No chart data available.',
                        ),
                        formatValue: (value) => '${_dash(value.toDouble())} s',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        if (pointsPerOwnSecond != null) ...[
          const SizedBox(height: 12),
          ResultsChartCard(
            key: const ValueKey('results.chart.knight_efficiency'),
            title: t(
              'results.charts.knight_efficiency.title',
              'Knight Efficiency (Points / Own Second)',
            ),
            subtitle: t(
              'results.charts.knight_efficiency.subtitle',
              'Estimated score generated per second of knight action time.',
            ),
            helpTooltip: t(
              'results.charts.knight_efficiency.help',
              'Useful for comparing setups quickly: higher values indicate better point throughput for the same action time budget.',
            ),
            legend: [
              for (int i = 0; i < _knightCount; i++)
                ResultsChartLegendChip(
                  color:
                      runPacingKnightColors[i % runPacingKnightColors.length],
                  label: _knightLabel(i),
                  value: _fmtCompact(pointsPerOwnSecond[i]),
                ),
            ],
            child: GroupedVerticalBarChart(
              categories: List<String>.generate(
                _knightCount,
                _knightLabel,
                growable: false,
              ),
              series: [
                BarChartSeries(
                  label: t(
                    'durations.row.points_per_own_second',
                    'Points / own sec (est.)',
                  ),
                  color: const Color(0xFF2563EB),
                  values: pointsPerOwnSecond,
                ),
              ],
              xAxisLabel: t('results.knights.title', 'Knights'),
              yAxisLabel: t(
                'durations.row.points_per_own_second',
                'Points / own sec (est.)',
              ),
              emptyLabel: t(
                'results.charts.empty',
                'No chart data available.',
              ),
              formatValue: _fmtCompact,
              scaleMode: GroupedBarScaleMode.perSeriesZoom,
            ),
          ),
        ],
        const SizedBox(height: 12),
        ResultsChartCard(
          key: const ValueKey('results.chart.timing_breakdown'),
          title: t(
            'results.charts.timing_breakdown.title',
            'Timing Breakdown',
          ),
          subtitle: t(
            'results.charts.timing_breakdown.subtitle',
            'Per-knight action time split across normal, special, stun and miss.',
          ),
          helpTooltip: t(
            'results.charts.timing_breakdown.help',
            'Each row is one knight. The full bar is that knight total action time, split into normal, special, stun and miss segments.',
          ),
          legend: [
            ResultsChartLegendChip(
              color: Color(0xFF3B82F6),
              label: t('results.charts.series.normal', 'Normal'),
            ),
            ResultsChartLegendChip(
              color: Color(0xFF10B981),
              label: t('results.charts.series.special', 'Special'),
            ),
            ResultsChartLegendChip(
              color: Color(0xFFF59E0B),
              label: t('results.charts.series.stun', 'Stun'),
            ),
            ResultsChartLegendChip(
              color: Color(0xFF9CA3AF),
              label: t('results.charts.series.miss', 'Miss'),
            ),
          ],
          child: StackedHorizontalBarChart(
            categories: List<String>.generate(
              _knightCount,
              _knightLabel,
              growable: false,
            ),
            segments: [
              StackedBarSegment(
                label: t('results.charts.series.normal', 'Normal'),
                color: const Color(0xFF3B82F6),
                values: tstats.kNormalSeconds,
              ),
              StackedBarSegment(
                label: t('results.charts.series.special', 'Special'),
                color: const Color(0xFF10B981),
                values: tstats.kSpecialSeconds,
              ),
              StackedBarSegment(
                label: t('results.charts.series.stun', 'Stun'),
                color: const Color(0xFFF59E0B),
                values: tstats.kStunSeconds,
              ),
              StackedBarSegment(
                label: t('results.charts.series.miss', 'Miss'),
                color: const Color(0xFF9CA3AF),
                values: tstats.kMissSeconds,
              ),
            ],
            formatValue: (value) => _dash(value.toDouble()),
          ),
        ),
        const SizedBox(height: 12),
        _durationsTable(context, showActionBreakdown: graphViewEnabled),
      ],
    );
  }

  String _dash(double? v) => v == null ? '-' : v.toStringAsFixed(2);

  List<ProbabilityPointDatum> _buildExceedancePoints(
    SimulationHistogram histogram,
    int totalRuns,
  ) {
    final bins = List<SimulationHistogramBin>.from(histogram.bins)
      ..sort((a, b) => a.lowerBound.compareTo(b.lowerBound));
    if (bins.isEmpty || totalRuns <= 0) return const <ProbabilityPointDatum>[];

    final points = <ProbabilityPointDatum>[];
    var remaining = totalRuns.toDouble();

    for (final bin in bins) {
      points.add(
        ProbabilityPointDatum(
          x: bin.lowerBound,
          y: ((remaining / totalRuns) * 100).clamp(0.0, 100.0),
        ),
      );
      remaining -= bin.count;
    }

    if (remaining <= 0) {
      points.add(
        ProbabilityPointDatum(
          x: bins.last.upperBound,
          y: 0,
        ),
      );
    }

    return points;
  }

  List<HistogramBinDatum> _buildHistogramBinsWithBands(
    SimulationHistogram histogram,
    int totalRuns, {
    required Color lowBandColor,
    required Color coreBandColor,
    required Color highBandColor,
  }) {
    final bins = List<SimulationHistogramBin>.from(histogram.bins)
      ..sort((a, b) => a.lowerBound.compareTo(b.lowerBound));
    if (bins.isEmpty || totalRuns <= 0) {
      return bins
          .map(
            (bin) => HistogramBinDatum(
              lowerBound: bin.lowerBound,
              upperBound: bin.upperBound,
              count: bin.count,
              color: coreBandColor,
            ),
          )
          .toList(growable: false);
    }

    var cumulative = 0.0;
    final out = <HistogramBinDatum>[];
    for (final bin in bins) {
      final startPercentile = (cumulative / totalRuns) * 100.0;
      final endPercentile = ((cumulative + bin.count) / totalRuns) * 100.0;
      final midPercentile =
          ((startPercentile + endPercentile) / 2.0).clamp(0.0, 100.0);
      out.add(
        HistogramBinDatum(
          lowerBound: bin.lowerBound,
          upperBound: bin.upperBound,
          count: bin.count,
          color: _histogramBandColor(
            midPercentile,
            lowBandColor: lowBandColor,
            coreBandColor: coreBandColor,
            highBandColor: highBandColor,
          ),
        ),
      );
      cumulative += bin.count;
    }
    return out;
  }

  Color _histogramBandColor(
    double percentile, {
    required Color lowBandColor,
    required Color coreBandColor,
    required Color highBandColor,
  }) {
    if (percentile < 40.0) return lowBandColor;
    if (percentile <= 60.0) return coreBandColor;
    return highBandColor;
  }

  double _approxHistogramExceedancePercent(
    SimulationHistogram histogram,
    int threshold,
    int totalRuns,
  ) {
    if (totalRuns <= 0) return 0;
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

  List<_ProbabilityTargetOption> _probabilityTargetOptions(
    SimulationHistogram histogram,
    int totalRuns,
  ) {
    final minScore = histogram.bins.isEmpty
        ? 0
        : histogram.bins.map((bin) => bin.lowerBound).reduce(math.min);
    final maxScore = histogram.bins.isEmpty
        ? 0
        : histogram.bins.map((bin) => bin.upperBound).reduce(math.max);

    final candidates = <_ProbabilityTargetOption>[
      _ProbabilityTargetOption(
        value: stats.mean,
        label: t('results.charts.target.mean', 'Mean'),
      ),
      _ProbabilityTargetOption(
        value: stats.median,
        label: t('results.charts.target.median', 'Median'),
      ),
      _ProbabilityTargetOption(
        value: _approxHistogramPercentileScore(histogram, totalRuns, 75),
        label: t('results.charts.target.p75', 'P75'),
      ),
      _ProbabilityTargetOption(
        value: _approxHistogramPercentileScore(histogram, totalRuns, 90),
        label: t('results.charts.target.p90', 'P90'),
      ),
      if (milestoneTargetPoints >= minScore &&
          milestoneTargetPoints <= maxScore)
        _ProbabilityTargetOption(
          value: milestoneTargetPoints,
          label: t('results.charts.target.milestone', 'Milestone'),
        ),
    ];

    final seen = <int>{};
    final options = <_ProbabilityTargetOption>[];
    for (final candidate in candidates) {
      final value = candidate.value.clamp(0, _maxTargetPoints);
      if (!seen.add(value)) continue;
      options
          .add(_ProbabilityTargetOption(value: value, label: candidate.label));
    }
    return options;
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
      final nextCumulative = cumulative + bin.count;
      if (targetRank <= nextCumulative) {
        final span = math.max(1, (bin.upperBound - bin.lowerBound) + 1);
        final offsetFraction =
            ((targetRank - cumulative) / math.max(1, bin.count))
                .clamp(0.0, 1.0);
        return bin.lowerBound + ((span - 1) * offsetFraction).round();
      }
      cumulative = nextCumulative;
    }

    return bins.last.upperBound;
  }

  String _percentileLabel(int percentile) {
    switch (percentile) {
      case 10:
        return t('results.charts.percentile.p10', 'P10');
      case 25:
        return t('results.charts.percentile.p25', 'P25');
      case 50:
        return t('results.charts.percentile.p50', 'P50');
      case 75:
        return t('results.charts.percentile.p75', 'P75');
      case 90:
        return t('results.charts.percentile.p90', 'P90');
      default:
        return 'P$percentile';
    }
  }

  String _fmtPercent(num value) {
    final v = value.toDouble();
    if (v >= 99.95 || v == 0 || (v - v.roundToDouble()).abs() < 0.05) {
      return '${v.round()}%';
    }
    if (v >= 10) return '${v.toStringAsFixed(1)}%';
    return '${v.toStringAsFixed(2)}%';
  }

  _EnergyPlan _energyPlan(int perRun) {
    final extra = startEnergies.clamp(0, 2000000000).toInt();
    final free = freeRaidEnergies.clamp(0, 2000000000).toInt();

    if (perRun <= 0) {
      return _EnergyPlan(
        runs: 0,
        free: free,
        extra: extra,
        packs: 0,
        gems: 0,
        leftover: 0,
      );
    }

    final meanRunSeconds =
        isPremium ? (stats.timing?.meanRunSeconds ?? 0.0) : 0.0;
    final runs = runsNeededWithElixirs(
      basePerRun: perRun,
      targetPoints: milestoneTargetPoints,
      meanRunSeconds: meanRunSeconds,
      elixirs: elixirs,
    );

    final available = free + extra;
    final need = math.max(0, runs - available);

    final packs = (need / _packSize).ceil();
    final totalBought = packs * _packSize;

    final leftover = math.max(0, totalBought - need);

    final gems = packs * _packCost;

    return _EnergyPlan(
      runs: runs,
      free: free,
      extra: extra,
      packs: packs,
      gems: gems,
      leftover: leftover,
    );
  }

  Widget _dataTable({
    required double minWidth,
    required List<String> columns,
    required List<List<String>> rows,
    double columnSpacing = 16,
    double horizontalMargin = 6,
  }) {
    return ThemedStringTable(
      columns: columns,
      rows: rows,
      minWidth: minWidth,
      columnSpacing: columnSpacing,
      horizontalMargin: horizontalMargin,
    );
  }

  String _fmtPct(double v) => '${(v * 100).toStringAsFixed(0)}%';

  String _fmtAdv(double v) {
    if ((v - 1.0).abs() < 1e-9) return '1';
    if ((v - 1.5).abs() < 1e-9) return '1.5';
    if ((v - 2.0).abs() < 1e-9) return '2';
    return v.toStringAsFixed(1);
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
      if (isGroup) buf.write('.');
    }
    return neg ? '-${buf.toString()}' : buf.toString();
  }

  String _fmtCompact(num n) {
    if ((n - n.round()).abs() < 1e-9) return _fmtInt(n);
    return n.toStringAsFixed(1);
  }

  String _fmtShortInt(num n) {
    final absValue = n.abs().toDouble();
    if (absValue >= 1000000000) {
      return '${(n / 1000000000).toStringAsFixed(absValue >= 10000000000 ? 0 : 1)}B';
    }
    if (absValue >= 1000000) {
      return '${(n / 1000000).toStringAsFixed(absValue >= 10000000 ? 0 : 1)}M';
    }
    if (absValue >= 1000) {
      return '${(n / 1000).toStringAsFixed(absValue >= 100000 ? 0 : 1)}k';
    }
    return _fmtInt(n);
  }
}

class _EnergyPlan {
  final int runs;
  final int free;
  final int extra;
  final int packs;
  final int gems;
  final int leftover;

  const _EnergyPlan({
    required this.runs,
    required this.free,
    required this.extra,
    required this.packs,
    required this.gems,
    required this.leftover,
  });
}

class _ProbabilityTargetOption {
  final int value;
  final String label;

  const _ProbabilityTargetOption({
    required this.value,
    required this.label,
  });
}

enum _KnightChartVisualMode {
  bars,
  histogram,
}

enum _TimingShareVisualMode {
  histogram,
  pie,
}

class _ResultsBody extends StatefulWidget {
  final ResultsPage page;

  const _ResultsBody({required this.page});

  @override
  State<_ResultsBody> createState() => _ResultsBodyState();
}

class _ResultsBodyState extends State<_ResultsBody> {
  bool _graphViewEnabled = false;
  late int _selectedProbabilityTargetPoints;
  _KnightChartVisualMode _outgoingChartMode = _KnightChartVisualMode.bars;
  _KnightChartVisualMode _incomingChartMode = _KnightChartVisualMode.bars;
  _TimingShareVisualMode _timingShareVisualMode =
      _TimingShareVisualMode.histogram;

  ResultsPage get page => widget.page;

  @override
  void initState() {
    super.initState();
    final histogram = page.stats.series?.histogram;
    if (histogram != null && histogram.bins.isNotEmpty) {
      _selectedProbabilityTargetPoints = page._approxHistogramPercentileScore(
        histogram,
        page.stats.series!.totalRuns,
        75,
      );
    } else {
      _selectedProbabilityTargetPoints = page.stats.median;
    }
  }

  @override
  Widget build(BuildContext context) {
    final perRun = page.stats.mean;
    final plan = page._energyPlan(perRun);

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        page._reportHeader(context),
        const SizedBox(height: 10),
        _graphViewToggle(context),
        const SizedBox(height: 12),
        SectionCard(
          title: page.t('results.performance_summary', 'Performance Summary'),
          headerTrailing: page._tableScrollTipButton(context),
          child: page._performanceSummarySection(
            context,
            perRun,
            plan,
            graphViewEnabled: _graphViewEnabled,
            selectedProbabilityTargetPoints: _selectedProbabilityTargetPoints,
            onSelectProbabilityTarget: (value) {
              setState(() => _selectedProbabilityTargetPoints = value);
            },
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: page.t('results.boss_context', 'Boss Context'),
          child: page._battleContextSection(context),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: page.t('results.knights.title', 'Knights'),
          child: page._knightsTable(
            context,
            graphViewEnabled: _graphViewEnabled,
            outgoingChartMode: _outgoingChartMode,
            onOutgoingChartModeChanged: (value) {
              setState(() => _outgoingChartMode = value);
            },
            incomingChartMode: _incomingChartMode,
            onIncomingChartModeChanged: (value) {
              setState(() => _incomingChartMode = value);
            },
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: page.t('results.advanced.title', 'Advanced Details'),
          headerTrailing: page._tableScrollTipButton(context),
          child: page._advancedDetailsSection(
            context,
            graphViewEnabled: _graphViewEnabled,
            timingShareVisualMode: _timingShareVisualMode,
            onTimingShareVisualModeChanged: (value) {
              setState(() => _timingShareVisualMode = value);
            },
          ),
        ),
      ],
    );
  }

  Widget _graphViewToggle(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('results.graph_toggle'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.outline.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.28 : 0.12,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.show_chart,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  page.t('results.graph_view.title', 'Graph View'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _graphViewEnabled
                      ? page.t(
                          'results.graph_view.body_on',
                          'Charts are shown alongside the detailed report.',
                        )
                      : page.t(
                          'results.graph_view.body_off',
                          'Turn this on to add charts without replacing the tables.',
                        ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Switch.adaptive(
            value: _graphViewEnabled,
            onChanged: (value) {
              setState(() => _graphViewEnabled = value);
            },
          ),
        ],
      ),
    );
  }
}
