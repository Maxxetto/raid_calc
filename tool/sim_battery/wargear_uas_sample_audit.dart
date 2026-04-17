import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/data/wargear_universal_scoring.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

import 'boss_sim_battery_config.dart';
import 'boss_sim_battery_models.dart';
import 'boss_sim_battery_runner.dart';

class WargearUasSampleAuditSummary {
  final Directory outputDir;
  final int runsPerScenario;
  final int sampleScenarioCount;
  final int sensitivityScenarioCount;
  final List<String> generatedFiles;

  const WargearUasSampleAuditSummary({
    required this.outputDir,
    required this.runsPerScenario,
    required this.sampleScenarioCount,
    required this.sensitivityScenarioCount,
    required this.generatedFiles,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'outputDir': outputDir.path,
        'runsPerScenario': runsPerScenario,
        'sampleScenarioCount': sampleScenarioCount,
        'sensitivityScenarioCount': sensitivityScenarioCount,
        'generatedFiles': generatedFiles,
      };
}

class WargearUasSampleAuditRunner {
  final WargearUniversalScoringEngine _engine;
  final BossSimulationRunner _batteryRunner;

  WargearUasSampleAuditRunner({
    WargearUniversalScoringEngine? engine,
    BossSimulationRunner? batteryRunner,
  })  : _engine = engine ?? const WargearUniversalScoringEngine(),
        _batteryRunner = batteryRunner ?? BossSimulationRunner();

  double computeSetupUas({
    required BossSimulationScenario scenario,
    required List<double> knightStunChances,
  }) {
    final strategy = BossSimulationConfig.defaultBattery()
        .petUsageStrategies
        .firstWhere((value) => value.id == scenario.petStrategyId);
    var total = 0.0;
    for (final slot in scenario.slotProfiles) {
      total += _engine
          .score(
            stats: slot.effectiveStatsBeforeRandomization,
            armorElements: const <ElementType>[
              ElementType.fire,
              ElementType.fire,
            ],
            context: WargearUniversalScoreContext(
              bossMode: scenario.modeKey,
              bossLevel: scenario.bossLevel,
              bossElements: const <ElementType>[
                ElementType.fire,
                ElementType.fire,
              ],
              petElements: const <ElementType>[],
              petElementalAttack: 0,
              petElementalDefense: 0,
              stunPercent: slot.slotIndex < knightStunChances.length
                  ? knightStunChances[slot.slotIndex]
                  : 0.0,
              petSkillUsageMode: strategy.usageMode,
              petPrimarySkillName: scenario.petPrimarySkill,
              petSecondarySkillName: scenario.petSecondarySkill,
              knightAdvantageOverride:
                  scenario.knightAdvantageVector[slot.slotIndex],
              bossAdvantageOverride:
                  scenario.bossAdvantageVector[slot.slotIndex],
            ),
            variant: WargearUniversalScoreVariant.petAware,
          )
          .score;
    }
    return total;
  }

  Future<WargearUasSampleAuditSummary> run({
    required Directory outputDir,
    int runsPerScenario = 100,
  }) async {
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final plan = await _buildPlan(runsPerScenario);
    final results = await _runCases(plan);
    final audit = _buildAuditJson();
    final byModeLevel = _correlations(
      results.sampleRows,
      (row) => row.modeLevel,
    );
    final byModeLevelSkillUsage = _correlations(
      results.sampleRows,
      (row) => '${row.modeLevel}|${row.primarySkill}|${row.strategyId}',
    );
    final topK = <_TopKRow>[
      ..._topKRows(
        results.sampleRows,
        'mode_level',
        (row) => row.modeLevel,
      ),
      ..._topKRows(
        results.sampleRows,
        'mode_level_skill_usage',
        (row) => '${row.modeLevel}|${row.primarySkill}|${row.strategyId}',
      ),
    ];
    final mismatches = <_Mismatch>[
      ..._mismatchRows(
        results.sampleRows,
        'mode_level',
        (row) => row.modeLevel,
      ),
      ..._mismatchRows(
        results.sampleRows,
        'mode_level_skill_usage',
        (row) => '${row.modeLevel}|${row.primarySkill}|${row.strategyId}',
      ),
    ];
    final breakEven = _breakEvenRows(results.sensitivityRows);

    final generatedFiles = <String>[];
    generatedFiles.add(
      await _writeJson(File('${outputDir.path}/uas_audit.json'), audit),
    );
    generatedFiles.add(
      await _writeSampleCsv(
        File('${outputDir.path}/uas_sample_scenarios.csv'),
        results.sampleRows,
      ),
    );
    generatedFiles.add(
      await _writeCorrelationCsv(
        File('${outputDir.path}/uas_correlation_by_mode_level.csv'),
        byModeLevel,
      ),
    );
    generatedFiles.add(
      await _writeCorrelationCsv(
        File('${outputDir.path}/uas_correlation_by_mode_level_skill_usage.csv'),
        byModeLevelSkillUsage,
      ),
    );
    generatedFiles.add(
      await _writeTopKCsv(
        File('${outputDir.path}/uas_topk_agreement.csv'),
        topK,
      ),
    );
    generatedFiles.add(
      await _writeMismatchCsv(
        File('${outputDir.path}/uas_topk_mismatches.csv'),
        mismatches,
      ),
    );
    generatedFiles.add(
      await _writeSensitivityCsv(
        File('${outputDir.path}/uas_sensitivity_marginals.csv'),
        results.sensitivityRows,
      ),
    );
    generatedFiles.add(
      await _writeBreakEvenCsv(
        File('${outputDir.path}/uas_sensitivity_break_even.csv'),
        breakEven,
      ),
    );
    generatedFiles.add(
      await _writeMarkdown(
        File('${outputDir.path}/uas_calibration_report.md'),
        audit: audit,
        sampleRows: results.sampleRows,
        byModeLevel: byModeLevel,
        byModeLevelSkillUsage: byModeLevelSkillUsage,
        topKRows: topK,
        breakEvenRows: breakEven,
        generatedFiles: generatedFiles,
      ),
    );

    final summary = WargearUasSampleAuditSummary(
      outputDir: outputDir,
      runsPerScenario: runsPerScenario,
      sampleScenarioCount: results.sampleRows.length,
      sensitivityScenarioCount: results.sensitivityRows.length,
      generatedFiles: List<String>.unmodifiable(generatedFiles),
    );
    generatedFiles.add(
      await _writeJson(
        File('${outputDir.path}/uas_calibration_summary.json'),
        summary.toJson(),
      ),
    );
    return WargearUasSampleAuditSummary(
      outputDir: outputDir,
      runsPerScenario: runsPerScenario,
      sampleScenarioCount: results.sampleRows.length,
      sensitivityScenarioCount: results.sensitivityRows.length,
      generatedFiles: List<String>.unmodifiable(generatedFiles),
    );
  }

  Future<_Plan> _buildPlan(int runsPerScenario) async {
    final catalog = await WargearWardrobeLoader.load();
    final base = _baseConfig(runsPerScenario);
    final sample = <_Case>[];
    for (final target in base.targets) {
      for (final skill in base.petPrimarySkills) {
        for (final strategy in base.petUsageStrategies) {
          sample.addAll(<_Case>[
            await _makeCase(
              catalog: catalog,
              base: base,
              target: target,
              skill: skill,
              strategy: strategy,
              variantId: 'scenario_a',
              layoutToken: 'pss',
              knightAdv: const <double>[1, 1, 1],
              bossAdv: const <double>[1, 1, 1],
              baseTierId: 'tier_1',
              stats: _tier(base, 'tier_1'),
              swapped: false,
              stunPercent: 0,
              kind: 'sample',
            ),
            await _makeCase(
              catalog: catalog,
              base: base,
              target: target,
              skill: skill,
              strategy: strategy,
              variantId: 'scenario_b',
              layoutToken: 'sps',
              knightAdv: const <double>[1.5, 1, 2],
              bossAdv: const <double>[1, 1.5, 2],
              baseTierId: 'tier_4',
              stats: _tier(base, 'tier_4'),
              swapped: true,
              stunPercent: 0,
              kind: 'sample',
            ),
            await _makeCase(
              catalog: catalog,
              base: base,
              target: target,
              skill: skill,
              strategy: strategy,
              variantId: 'scenario_c',
              layoutToken: 'ssp',
              knightAdv: const <double>[2, 1.5, 1],
              bossAdv: const <double>[2, 1.5, 1],
              baseTierId: 'tier_7',
              stats: _tier(base, 'tier_7'),
              swapped: false,
              stunPercent: 0,
              kind: 'sample',
            ),
          ]);
        }
      }
    }

    final sensitivity = <_Case>[];
    for (final target in base.targets) {
      final modeLevel = '${target.modeKey}_L${target.bossLevel}';
      final anchors = <_Anchor>[
        _Anchor(
          id: '${modeLevel}_fragile',
          variant: 'fragile',
          tierId: 'tier_2',
          stats: _tier(base, 'tier_2'),
          skill: 'Soul Burn',
          strategyId: 'double_s2_then_s1',
          layoutToken: 'pss',
          knightAdv: const <double>[1, 1, 1],
          bossAdv: const <double>[1.5, 1.5, 1.5],
        ),
        _Anchor(
          id: '${modeLevel}_balanced',
          variant: 'balanced',
          tierId: 'tier_4',
          stats: _tier(base, 'tier_4'),
          skill: 'Vampiric Attack',
          strategyId: 's2_then_s1',
          layoutToken: 'sps',
          knightAdv: const <double>[1.5, 1, 2],
          bossAdv: const <double>[1, 1.5, 2],
        ),
        _Anchor(
          id: '${modeLevel}_strong',
          variant: 'strong',
          tierId: 'tier_6',
          stats: _tier(base, 'tier_6'),
          skill: 'Elemental Weakness',
          strategyId: 's2_then_s1',
          layoutToken: 'ssp',
          knightAdv: const <double>[2, 1.5, 1],
          bossAdv: const <double>[1, 1, 1],
        ),
      ];
      for (final anchor in anchors) {
        final strategy = base.petUsageStrategies
            .firstWhere((value) => value.id == anchor.strategyId);
        sensitivity.add(
          await _makeCase(
            catalog: catalog,
            base: base,
            target: target,
            skill: anchor.skill,
            strategy: strategy,
            variantId: '${anchor.variant}_baseline',
            layoutToken: anchor.layoutToken,
            knightAdv: anchor.knightAdv,
            bossAdv: anchor.bossAdv,
            baseTierId: anchor.tierId,
            stats: anchor.stats,
            swapped: false,
            stunPercent: 0,
            kind: 'sensitivity',
            anchorId: anchor.id,
            anchorVariant: anchor.variant,
            factorType: 'baseline',
            factorDelta: 0,
            factorLabel: 'baseline',
          ),
        );
        for (final delta in const <int>[1000, 3000, 5000]) {
          sensitivity.add(
            await _makeCase(
              catalog: catalog,
              base: base,
              target: target,
              skill: anchor.skill,
              strategy: strategy,
              variantId: '${anchor.variant}_atk_p$delta',
              layoutToken: anchor.layoutToken,
              knightAdv: anchor.knightAdv,
              bossAdv: anchor.bossAdv,
              baseTierId: anchor.tierId,
              tierIdOverride: '${anchor.tierId}_atk_p$delta',
              stats: WargearStats(
                attack: anchor.stats.attack + delta,
                defense: anchor.stats.defense,
                health: anchor.stats.health,
              ),
              swapped: false,
              stunPercent: 0,
              kind: 'sensitivity',
              anchorId: anchor.id,
              anchorVariant: anchor.variant,
              factorType: 'attack',
              factorDelta: delta.toDouble(),
              factorLabel: '+$delta atk',
            ),
          );
          sensitivity.add(
            await _makeCase(
              catalog: catalog,
              base: base,
              target: target,
              skill: anchor.skill,
              strategy: strategy,
              variantId: '${anchor.variant}_def_p$delta',
              layoutToken: anchor.layoutToken,
              knightAdv: anchor.knightAdv,
              bossAdv: anchor.bossAdv,
              baseTierId: anchor.tierId,
              tierIdOverride: '${anchor.tierId}_def_p$delta',
              stats: WargearStats(
                attack: anchor.stats.attack,
                defense: anchor.stats.defense + delta,
                health: anchor.stats.health,
              ),
              swapped: false,
              stunPercent: 0,
              kind: 'sensitivity',
              anchorId: anchor.id,
              anchorVariant: anchor.variant,
              factorType: 'defense',
              factorDelta: delta.toDouble(),
              factorLabel: '+$delta def',
            ),
          );
        }
        for (final delta in const <int>[100, 300, 500, 800, 1000]) {
          sensitivity.add(
            await _makeCase(
              catalog: catalog,
              base: base,
              target: target,
              skill: anchor.skill,
              strategy: strategy,
              variantId: '${anchor.variant}_hp_p$delta',
              layoutToken: anchor.layoutToken,
              knightAdv: anchor.knightAdv,
              bossAdv: anchor.bossAdv,
              baseTierId: anchor.tierId,
              tierIdOverride: '${anchor.tierId}_hp_p$delta',
              stats: WargearStats(
                attack: anchor.stats.attack,
                defense: anchor.stats.defense,
                health: anchor.stats.health + delta,
              ),
              swapped: false,
              stunPercent: 0,
              kind: 'sensitivity',
              anchorId: anchor.id,
              anchorVariant: anchor.variant,
              factorType: 'health',
              factorDelta: delta.toDouble(),
              factorLabel: '+$delta hp',
            ),
          );
        }
        for (final delta in const <double>[1, 3, 5, 10]) {
          sensitivity.add(
            await _makeCase(
              catalog: catalog,
              base: base,
              target: target,
              skill: anchor.skill,
              strategy: strategy,
              variantId: '${anchor.variant}_stun_p${delta.toInt()}',
              layoutToken: anchor.layoutToken,
              knightAdv: anchor.knightAdv,
              bossAdv: anchor.bossAdv,
              baseTierId: anchor.tierId,
              stats: anchor.stats,
              swapped: false,
              stunPercent: delta,
              kind: 'sensitivity',
              anchorId: anchor.id,
              anchorVariant: anchor.variant,
              factorType: 'stun',
              factorDelta: delta,
              factorLabel: '+${delta.toStringAsFixed(0)}% stun',
            ),
          );
        }
      }
    }
    return _Plan(base: base, sample: sample, sensitivity: sensitivity);
  }

  Future<_Case> _makeCase({
    required WargearWardrobeCatalog catalog,
    required BossSimulationConfig base,
    required BossSimulationModeLevel target,
    required String skill,
    required BossSimulationPetStrategy strategy,
    required String variantId,
    required String layoutToken,
    required List<double> knightAdv,
    required List<double> bossAdv,
    required String baseTierId,
    String? tierIdOverride,
    required WargearStats stats,
    required bool swapped,
    required double stunPercent,
    required String kind,
    String? anchorId,
    String? anchorVariant,
    String? factorType,
    double? factorDelta,
    String? factorLabel,
  }) async {
    final scenario = _buildScenario(
      catalog: catalog,
      base: base,
      target: target,
      skill: skill,
      strategy: strategy,
      layoutToken: layoutToken,
      knightAdv: knightAdv,
      bossAdv: bossAdv,
      tierId: tierIdOverride ?? baseTierId,
      stats: stats,
      swapped: swapped,
    );
    return _Case(
      kind: kind,
      modeLevel: '${target.modeKey}_L${target.bossLevel}',
      skill: skill,
      strategyId: strategy.id,
      variantId: variantId,
      layoutToken: layoutToken,
      knightAdv: knightAdv,
      bossAdv: bossAdv,
      stunPercent: stunPercent,
      anchorId: anchorId,
      anchorVariant: anchorVariant,
      factorType: factorType,
      factorDelta: factorDelta ?? 0,
      factorLabel: factorLabel,
      scenario: scenario,
    );
  }

  BossSimulationScenario _buildScenario({
    required WargearWardrobeCatalog catalog,
    required BossSimulationConfig base,
    required BossSimulationModeLevel target,
    required String skill,
    required BossSimulationPetStrategy strategy,
    required String layoutToken,
    required List<double> knightAdv,
    required List<double> bossAdv,
    required String tierId,
    required WargearStats stats,
    required bool swapped,
  }) {
    final config = BossSimulationConfig(
      targets: <BossSimulationModeLevel>[target],
      fightMode: base.fightMode,
      runsPerScenario: base.runsPerScenario,
      layoutPermutations: <List<WargearRole>>[_layout(layoutToken)],
      knightAdvantageVectors: <List<double>>[List<double>.from(knightAdv)],
      bossAdvantageVectors: <List<double>>[List<double>.from(bossAdv)],
      petUsageStrategies: <BossSimulationPetStrategy>[strategy],
      petPrimarySkills: <String>[skill],
      petSecondarySkill: base.petSecondarySkill,
      statTiers: <BossSimulationStatTier>[
        BossSimulationStatTier(id: tierId, bonusStats: stats),
      ],
      includeSwappedAttackDefenseVariant: swapped,
      randomization: base.randomization,
      petMatchByKnightSlot: base.petMatchByKnightSlot,
      petStrongVsBossByKnightSlot: base.petStrongVsBossByKnightSlot,
      petAttackResolutionPolicy: base.petAttackResolutionPolicy,
      petAdvantageMultiplier: base.petAdvantageMultiplier,
      knightStunChances: const <double>[0, 0, 0],
      captureTiming: false,
      exportAggregates: false,
      exportScores: false,
      retainAggregatesInMemory: true,
      retainScoresInMemory: true,
      exportShardSize: base.exportShardSize,
      checkpointEveryScenarios: base.checkpointEveryScenarios,
      pauseEveryScenarios: 0,
      pauseDurationMs: 0,
      maxScenarios: null,
      raidScoreProfile: base.raidScoreProfile,
      blitzScoreProfile: base.blitzScoreProfile,
    );
    return BossSimulationScenarioGenerator(config: config, catalog: catalog)
        .generate()
        .firstWhere((value) => value.attackDefenseSwapped == swapped);
  }

  Future<_Results> _runCases(_Plan plan) async {
    final grouped = <double, List<_Case>>{};
    for (final item in <_Case>[...plan.sample, ...plan.sensitivity]) {
      grouped.putIfAbsent(item.stunPercent, () => <_Case>[]).add(item);
    }

    final sampleRows = <_SampleRow>[];
    final sensitivityRows = <_SensitivityRow>[];
    final groupKeys = grouped.keys.toList(growable: false)..sort();
    for (final stunPercent in groupKeys) {
      final cases = grouped[stunPercent]!;
      final batch = await _batteryRunner.runSelectedScenarios(
        config: _withStun(plan.base, stunPercent),
        scenarios: cases.map((value) => value.scenario).toList(growable: false),
      );
      final aggregates = <String, BossSimulationAggregate>{
        for (final value in batch.aggregates) value.scenarioId: value,
      };
      final scores = <String, BossSimulationScore>{
        for (final value in batch.scores) value.scenarioId: value,
      };
      for (final item in cases) {
        final aggregate = aggregates[item.scenario.scenarioId]!;
        final score = scores[item.scenario.scenarioId]!;
        final row = _SampleRow(
          scenarioId: item.scenario.scenarioId,
          modeLevel: item.modeLevel,
          primarySkill: item.skill,
          strategyId: item.strategyId,
          variantId: item.variantId,
          layoutToken: item.layoutToken,
          statTierId: item.scenario.statTierId,
          swapped: item.scenario.attackDefenseSwapped,
          knightAdv: item.knightAdv,
          bossAdv: item.bossAdv,
          setupUas: computeSetupUas(
            scenario: item.scenario,
            knightStunChances: List<double>.filled(3, item.stunPercent),
          ),
          meanDamage: aggregate.meanTotalDamage,
          batteryScore: score.finalScore,
          survivalRate: aggregate.survivalRate,
          meanTurnsSurvived: aggregate.meanTurnsSurvived,
        );
        if (item.kind == 'sample') {
          sampleRows.add(row);
        } else {
          sensitivityRows.add(
            _SensitivityRow.fromCase(
              row: row,
              anchorId: item.anchorId!,
              anchorVariant: item.anchorVariant!,
              factorType: item.factorType!,
              factorDelta: item.factorDelta,
              factorLabel: item.factorLabel ?? '',
            ),
          );
        }
      }
    }

    final baselines = <String, _SensitivityRow>{
      for (final row in sensitivityRows)
        if (row.factorType == 'baseline') row.anchorId: row,
    };
    final finalizedSensitivity = sensitivityRows
        .map((row) => row.withBaseline(baselines[row.anchorId]))
        .toList(growable: false)
      ..sort((a, b) {
        final anchorCompare = a.anchorId.compareTo(b.anchorId);
        if (anchorCompare != 0) return anchorCompare;
        final typeCompare = a.factorType.compareTo(b.factorType);
        if (typeCompare != 0) return typeCompare;
        return a.factorDelta.compareTo(b.factorDelta);
      });
    sampleRows.sort((a, b) => a.scenarioId.compareTo(b.scenarioId));
    return _Results(
      sampleRows: List<_SampleRow>.unmodifiable(sampleRows),
      sensitivityRows: List<_SensitivityRow>.unmodifiable(finalizedSensitivity),
    );
  }

  Map<String, Object?> _buildAuditJson() => <String, Object?>{
        ..._engine.auditSnapshot(),
        'usageSites': const <Map<String, String>>[
          <String, String>{
            'label': 'UI label on imported/current armor',
            'path': 'lib/ui/home_page.dart',
          },
          <String, String>{
            'label': 'Favorite ranking in the Wardrobe',
            'path': 'lib/data/wargear_wardrobe_candidates.dart',
          },
          <String, String>{
            'label': 'Candidate preselection for Wardrobe Simulate',
            'path': 'lib/data/wargear_wardrobe_simulator.dart',
          },
        ],
        'blindSpots': const <String>[
          'No automatic empirical calibration against simulation outputs in runtime.',
          'No direct runtime modeling of real run tempo inside the UAS heuristic.',
          'No automatic ranking validation against battery outputs unless this audit is run.',
        ],
        'setupUasDefinition': 'setup UAS = sum of the 3 slot UAS values',
      };

  List<_CorrelationRow> _correlations(
    List<_SampleRow> rows,
    String Function(_SampleRow row) groupOf,
  ) {
    final damage = <String, _Corr>{};
    final score = <String, _Corr>{};
    final counts = <String, int>{};
    for (final row in rows) {
      final key = groupOf(row);
      damage.putIfAbsent(key, _Corr.new).add(row.setupUas, row.meanDamage);
      score.putIfAbsent(key, _Corr.new).add(row.setupUas, row.batteryScore);
      counts.update(key, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts.keys.map((key) {
      return _CorrelationRow(
        key: key,
        count: counts[key] ?? 0,
        uasVsMeanDamage: damage[key]!.value,
        uasVsBatteryScore: score[key]!.value,
      );
    }).toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
  }

  List<_TopKRow> _topKRows(
    List<_SampleRow> rows,
    String groupType,
    String Function(_SampleRow row) groupOf,
  ) {
    final groups = <String, List<_SampleRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(groupOf(row), () => <_SampleRow>[]).add(row);
    }
    final out = <_TopKRow>[];
    final keys = groups.keys.toList(growable: false)..sort();
    for (final key in keys) {
      final tracker = _Tracker(groups[key]!);
      for (final requestedK in const <int>[5, 10]) {
        out.add(
          _TopKRow(
            groupType: groupType,
            groupKey: key,
            requestedK: requestedK,
            effectiveK: math.min(requestedK, groups[key]!.length),
            groupSize: groups[key]!.length,
            overlap: tracker.overlap(requestedK),
          ),
        );
      }
    }
    return out;
  }

  List<_Mismatch> _mismatchRows(
    List<_SampleRow> rows,
    String groupType,
    String Function(_SampleRow row) groupOf,
  ) {
    final groups = <String, List<_SampleRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(groupOf(row), () => <_SampleRow>[]).add(row);
    }
    final out = <_Mismatch>[];
    final keys = groups.keys.toList(growable: false)..sort();
    for (final key in keys) {
      final tracker = _Tracker(groups[key]!);
      out.addAll(
        tracker.uasOnly(10).map(
              (row) => _Mismatch(
                groupType: groupType,
                groupKey: key,
                source: 'uas_only',
                row: row,
              ),
            ),
      );
      out.addAll(
        tracker.damageOnly(10).map(
              (row) => _Mismatch(
                groupType: groupType,
                groupKey: key,
                source: 'mean_damage_only',
                row: row,
              ),
            ),
      );
    }
    return out;
  }

  List<_BreakEven> _breakEvenRows(List<_SensitivityRow> rows) {
    final groups = <String, List<_SensitivityRow>>{};
    for (final row in rows) {
      groups.putIfAbsent(row.anchorId, () => <_SensitivityRow>[]).add(row);
    }
    final out = <_BreakEven>[];
    final keys = groups.keys.toList(growable: false)..sort();
    for (final key in keys) {
      final anchorRows = groups[key]!;
      final stun1 = _find(anchorRows, 'stun', 1);
      final def1k = _find(anchorRows, 'defense', 1000);
      if (stun1 != null) {
        out.add(
          _BreakEven(
            anchorId: key,
            modeLevel: anchorRows.first.modeLevel,
            comparison: '1% stun ~= X HP',
            targetLabel: stun1.factorLabel,
            targetDelta: stun1.deltaMeanDamage,
            equivalent: _equivalent(
              stun1.deltaMeanDamage,
              _curve(anchorRows, 'health'),
            ),
            unit: 'hp',
          ),
        );
        out.add(
          _BreakEven(
            anchorId: key,
            modeLevel: anchorRows.first.modeLevel,
            comparison: '1% stun ~= Y DEF',
            targetLabel: stun1.factorLabel,
            targetDelta: stun1.deltaMeanDamage,
            equivalent: _equivalent(
              stun1.deltaMeanDamage,
              _curve(anchorRows, 'defense'),
            ),
            unit: 'def',
          ),
        );
      }
      if (def1k != null) {
        out.add(
          _BreakEven(
            anchorId: key,
            modeLevel: anchorRows.first.modeLevel,
            comparison: '1000 DEF ~= Z ATK',
            targetLabel: def1k.factorLabel,
            targetDelta: def1k.deltaMeanDamage,
            equivalent: _equivalent(
              def1k.deltaMeanDamage,
              _curve(anchorRows, 'attack'),
            ),
            unit: 'atk',
          ),
        );
      }
    }
    return out;
  }

  _SensitivityRow? _find(
      List<_SensitivityRow> rows, String type, double delta) {
    for (final row in rows) {
      if (row.factorType == type && (row.factorDelta - delta).abs() < 1e-9) {
        return row;
      }
    }
    return null;
  }

  List<_Point> _curve(List<_SensitivityRow> rows, String type) {
    return rows
        .where((row) => row.factorType == type && row.factorDelta > 0)
        .map((row) => _Point(row.factorDelta, row.deltaMeanDamage))
        .toList(growable: false)
      ..sort((a, b) => a.x.compareTo(b.x));
  }

  double? _equivalent(double target, List<_Point> curve) {
    if (target <= 0 || curve.isEmpty) return null;
    final positive =
        curve.where((point) => point.y > 0).toList(growable: false);
    if (positive.isEmpty) return null;
    if (positive.length == 1) {
      return positive.first.x * (target / positive.first.y);
    }
    if (target <= positive.first.y) {
      return positive.first.x * (target / positive.first.y);
    }
    for (var i = 1; i < positive.length; i++) {
      final left = positive[i - 1];
      final right = positive[i];
      if (target <= right.y) {
        final range = right.y - left.y;
        if (range.abs() < 1e-9) return right.x;
        final t = (target - left.y) / range;
        return left.x + ((right.x - left.x) * t);
      }
    }
    final left = positive[positive.length - 2];
    final right = positive.last;
    final range = right.y - left.y;
    if (range.abs() < 1e-9) return right.x;
    final t = (target - left.y) / range;
    return left.x + ((right.x - left.x) * t);
  }

  BossSimulationConfig _baseConfig(int runsPerScenario) {
    final base = BossSimulationConfig.defaultBattery(
      runsPerScenario: runsPerScenario,
    );
    return BossSimulationConfig(
      targets: base.targets,
      fightMode: base.fightMode,
      runsPerScenario: base.runsPerScenario,
      layoutPermutations: base.layoutPermutations,
      knightAdvantageVectors: base.knightAdvantageVectors,
      bossAdvantageVectors: base.bossAdvantageVectors,
      petUsageStrategies: base.petUsageStrategies,
      petPrimarySkills: base.petPrimarySkills,
      petSecondarySkill: base.petSecondarySkill,
      statTiers: base.statTiers,
      includeSwappedAttackDefenseVariant:
          base.includeSwappedAttackDefenseVariant,
      randomization: base.randomization,
      petMatchByKnightSlot: base.petMatchByKnightSlot,
      petStrongVsBossByKnightSlot: base.petStrongVsBossByKnightSlot,
      petAttackResolutionPolicy: base.petAttackResolutionPolicy,
      petAdvantageMultiplier: base.petAdvantageMultiplier,
      knightStunChances: const <double>[0, 0, 0],
      captureTiming: false,
      exportAggregates: false,
      exportScores: false,
      retainAggregatesInMemory: true,
      retainScoresInMemory: true,
      exportShardSize: base.exportShardSize,
      checkpointEveryScenarios: base.checkpointEveryScenarios,
      pauseEveryScenarios: 0,
      pauseDurationMs: 0,
      maxScenarios: null,
      raidScoreProfile: base.raidScoreProfile,
      blitzScoreProfile: base.blitzScoreProfile,
    );
  }

  BossSimulationConfig _withStun(
      BossSimulationConfig base, double stunPercent) {
    return BossSimulationConfig(
      targets: base.targets,
      fightMode: base.fightMode,
      runsPerScenario: base.runsPerScenario,
      layoutPermutations: base.layoutPermutations,
      knightAdvantageVectors: base.knightAdvantageVectors,
      bossAdvantageVectors: base.bossAdvantageVectors,
      petUsageStrategies: base.petUsageStrategies,
      petPrimarySkills: base.petPrimarySkills,
      petSecondarySkill: base.petSecondarySkill,
      statTiers: base.statTiers,
      includeSwappedAttackDefenseVariant:
          base.includeSwappedAttackDefenseVariant,
      randomization: base.randomization,
      petMatchByKnightSlot: base.petMatchByKnightSlot,
      petStrongVsBossByKnightSlot: base.petStrongVsBossByKnightSlot,
      petAttackResolutionPolicy: base.petAttackResolutionPolicy,
      petAdvantageMultiplier: base.petAdvantageMultiplier,
      knightStunChances: <double>[stunPercent, stunPercent, stunPercent],
      captureTiming: false,
      exportAggregates: false,
      exportScores: false,
      retainAggregatesInMemory: true,
      retainScoresInMemory: true,
      exportShardSize: base.exportShardSize,
      checkpointEveryScenarios: base.checkpointEveryScenarios,
      pauseEveryScenarios: 0,
      pauseDurationMs: 0,
      maxScenarios: null,
      raidScoreProfile: base.raidScoreProfile,
      blitzScoreProfile: base.blitzScoreProfile,
    );
  }

  WargearStats _tier(BossSimulationConfig base, String id) =>
      base.statTiers.firstWhere((value) => value.id == id).bonusStats;

  List<WargearRole> _layout(String token) => token
      .split('')
      .map((char) => char == 'p' ? WargearRole.primary : WargearRole.secondary)
      .toList(growable: false);

  Future<String> _writeJson(File file, Map<String, Object?> data) async {
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  Future<String> _writeSampleCsv(File file, List<_SampleRow> rows) async {
    final buffer = StringBuffer()
      ..writeln(
        'scenario_id,mode_level,primary_skill,pet_strategy_id,variant_id,layout_token,stat_tier_id,swapped,setup_uas,mean_total_damage,battery_final_score,survival_rate,mean_turns_survived',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.scenarioId},${row.modeLevel},${_csv(row.primarySkill)},${row.strategyId},${row.variantId},${row.layoutToken},${row.statTierId},${row.swapped},${row.setupUas},${row.meanDamage},${row.batteryScore},${row.survivalRate},${row.meanTurnsSurvived}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeCorrelationCsv(
    File file,
    List<_CorrelationRow> rows,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        'group_key,scenario_count,pearson_uas_vs_mean_damage,pearson_uas_vs_battery_score',
      );
    for (final row in rows) {
      buffer.writeln(
        '${_csv(row.key)},${row.count},${row.uasVsMeanDamage},${row.uasVsBatteryScore}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeTopKCsv(File file, List<_TopKRow> rows) async {
    final buffer = StringBuffer()
      ..writeln(
        'group_type,group_key,requested_k,effective_k,group_size,overlap_uas_vs_mean_damage',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.groupType},${_csv(row.groupKey)},${row.requestedK},${row.effectiveK},${row.groupSize},${row.overlap}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeMismatchCsv(File file, List<_Mismatch> rows) async {
    final buffer = StringBuffer()
      ..writeln(
        'group_type,group_key,source,scenario_id,setup_uas,mean_total_damage,battery_final_score',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.groupType},${_csv(row.groupKey)},${row.source},${row.row.scenarioId},${row.row.setupUas},${row.row.meanDamage},${row.row.batteryScore}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeSensitivityCsv(
    File file,
    List<_SensitivityRow> rows,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        'scenario_id,anchor_id,mode_level,anchor_variant,factor_type,factor_label,factor_delta,setup_uas,delta_setup_uas,mean_total_damage,delta_mean_total_damage,survival_rate,delta_survival_rate,mean_turns_survived,delta_mean_turns_survived,battery_final_score,delta_battery_final_score',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.scenarioId},${row.anchorId},${row.modeLevel},${row.anchorVariant},${row.factorType},${_csv(row.factorLabel)},${row.factorDelta},${row.setupUas},${row.deltaSetupUas},${row.meanDamage},${row.deltaMeanDamage},${row.survivalRate},${row.deltaSurvivalRate},${row.meanTurnsSurvived},${row.deltaMeanTurns},${row.batteryScore},${row.deltaBatteryScore}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeBreakEvenCsv(File file, List<_BreakEven> rows) async {
    final buffer = StringBuffer()
      ..writeln(
        'anchor_id,mode_level,comparison,target_label,target_delta_mean_damage,equivalent_value,unit',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.anchorId},${row.modeLevel},${_csv(row.comparison)},${_csv(row.targetLabel)},${row.targetDelta},${row.equivalent ?? ''},${row.unit}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeMarkdown(
    File file, {
    required Map<String, Object?> audit,
    required List<_SampleRow> sampleRows,
    required List<_CorrelationRow> byModeLevel,
    required List<_CorrelationRow> byModeLevelSkillUsage,
    required List<_TopKRow> topKRows,
    required List<_BreakEven> breakEvenRows,
    required List<String> generatedFiles,
  }) async {
    final profiles = (audit['profiles'] as Map<String, Object?>?) ?? const {};
    final buffer = StringBuffer()
      ..writeln('# Universal Armor Score audit')
      ..writeln()
      ..writeln(
        'L’app continua a mostrare solo il numero finale dell’UAS; questo report è interno.',
      )
      ..writeln()
      ..writeln('## Coefficienti attuali')
      ..writeln()
      ..writeln(
        '| Profilo | Atk | Def | HP | Mode scale | Knight slope | Boss slope |',
      )
      ..writeln('| --- | ---: | ---: | ---: | ---: | ---: | ---: |');
    final profileKeys = profiles.keys.toList(growable: false)..sort();
    for (final key in profileKeys) {
      final value = profiles[key] as Map<String, Object?>;
      buffer.writeln(
        '| $key | ${value['attackWeight']} | ${value['defenseWeight']} | ${value['healthWeight']} | ${value['modeScale']} | ${value['knightAdvantageSlope']} | ${value['bossAdvantageSlope']} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Correlazione su campione sintetico')
      ..writeln()
      ..writeln('Setup sintetici: ${sampleRows.length}.')
      ..writeln()
      ..writeln(
          '| Group | Scenari | UAS vs mean damage | UAS vs battery score |')
      ..writeln('| --- | ---: | ---: | ---: |');
    for (final row in byModeLevel) {
      buffer.writeln(
        '| ${row.key} | ${row.count} | ${row.uasVsMeanDamage.toStringAsFixed(4)} | ${row.uasVsBatteryScore.toStringAsFixed(4)} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Correlazione per mode level + skill + usage')
      ..writeln()
      ..writeln(
          '| Group | Scenari | UAS vs mean damage | UAS vs battery score |')
      ..writeln('| --- | ---: | ---: | ---: |');
    for (final row in byModeLevelSkillUsage.take(12)) {
      buffer.writeln(
        '| ${row.key} | ${row.count} | ${row.uasVsMeanDamage.toStringAsFixed(4)} | ${row.uasVsBatteryScore.toStringAsFixed(4)} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Top-k agreement UAS vs mean damage')
      ..writeln()
      ..writeln('| Group | k richiesto | k effettivo | Overlap |')
      ..writeln('| --- | ---: | ---: | ---: |');
    for (final row
        in topKRows.where((value) => value.groupType == 'mode_level')) {
      buffer.writeln(
        '| ${row.groupKey} | ${row.requestedK} | ${row.effectiveK} | ${row.overlap.toStringAsFixed(3)} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Break-even locali')
      ..writeln()
      ..writeln('| Anchor | Mode level | Comparison | Equivalent |')
      ..writeln('| --- | --- | --- | --- |');
    for (final row in breakEvenRows.take(12)) {
      final eq = row.equivalent == null
          ? 'n/a'
          : '${row.equivalent!.toStringAsFixed(2)} ${row.unit}';
      buffer.writeln(
        '| ${row.anchorId} | ${row.modeLevel} | ${row.comparison} | $eq |',
      );
    }
    buffer
      ..writeln()
      ..writeln('Generated files:')
      ..writeln();
    for (final path in generatedFiles) {
      buffer.writeln('- `${path.split(Platform.pathSeparator).last}`');
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  String _csv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

class _Plan {
  final BossSimulationConfig base;
  final List<_Case> sample;
  final List<_Case> sensitivity;

  const _Plan({
    required this.base,
    required this.sample,
    required this.sensitivity,
  });
}

class _Case {
  final String kind;
  final String modeLevel;
  final String skill;
  final String strategyId;
  final String variantId;
  final String layoutToken;
  final List<double> knightAdv;
  final List<double> bossAdv;
  final double stunPercent;
  final String? anchorId;
  final String? anchorVariant;
  final String? factorType;
  final double factorDelta;
  final String? factorLabel;
  final BossSimulationScenario scenario;

  const _Case({
    required this.kind,
    required this.modeLevel,
    required this.skill,
    required this.strategyId,
    required this.variantId,
    required this.layoutToken,
    required this.knightAdv,
    required this.bossAdv,
    required this.stunPercent,
    required this.anchorId,
    required this.anchorVariant,
    required this.factorType,
    required this.factorDelta,
    required this.factorLabel,
    required this.scenario,
  });
}

class _Anchor {
  final String id;
  final String variant;
  final String tierId;
  final WargearStats stats;
  final String skill;
  final String strategyId;
  final String layoutToken;
  final List<double> knightAdv;
  final List<double> bossAdv;

  const _Anchor({
    required this.id,
    required this.variant,
    required this.tierId,
    required this.stats,
    required this.skill,
    required this.strategyId,
    required this.layoutToken,
    required this.knightAdv,
    required this.bossAdv,
  });
}

class _Results {
  final List<_SampleRow> sampleRows;
  final List<_SensitivityRow> sensitivityRows;

  const _Results({
    required this.sampleRows,
    required this.sensitivityRows,
  });
}

class _SampleRow {
  final String scenarioId;
  final String modeLevel;
  final String primarySkill;
  final String strategyId;
  final String variantId;
  final String layoutToken;
  final String statTierId;
  final bool swapped;
  final List<double> knightAdv;
  final List<double> bossAdv;
  final double setupUas;
  final double meanDamage;
  final double batteryScore;
  final double survivalRate;
  final double meanTurnsSurvived;

  const _SampleRow({
    required this.scenarioId,
    required this.modeLevel,
    required this.primarySkill,
    required this.strategyId,
    required this.variantId,
    required this.layoutToken,
    required this.statTierId,
    required this.swapped,
    required this.knightAdv,
    required this.bossAdv,
    required this.setupUas,
    required this.meanDamage,
    required this.batteryScore,
    required this.survivalRate,
    required this.meanTurnsSurvived,
  });
}

class _SensitivityRow extends _SampleRow {
  final String anchorId;
  final String anchorVariant;
  final String factorType;
  final double factorDelta;
  final String factorLabel;
  final double deltaSetupUas;
  final double deltaMeanDamage;
  final double deltaSurvivalRate;
  final double deltaMeanTurns;
  final double deltaBatteryScore;

  const _SensitivityRow({
    required super.scenarioId,
    required super.modeLevel,
    required super.primarySkill,
    required super.strategyId,
    required super.variantId,
    required super.layoutToken,
    required super.statTierId,
    required super.swapped,
    required super.knightAdv,
    required super.bossAdv,
    required super.setupUas,
    required super.meanDamage,
    required super.batteryScore,
    required super.survivalRate,
    required super.meanTurnsSurvived,
    required this.anchorId,
    required this.anchorVariant,
    required this.factorType,
    required this.factorDelta,
    required this.factorLabel,
    required this.deltaSetupUas,
    required this.deltaMeanDamage,
    required this.deltaSurvivalRate,
    required this.deltaMeanTurns,
    required this.deltaBatteryScore,
  });

  factory _SensitivityRow.fromCase({
    required _SampleRow row,
    required String anchorId,
    required String anchorVariant,
    required String factorType,
    required double factorDelta,
    required String factorLabel,
  }) {
    return _SensitivityRow(
      scenarioId: row.scenarioId,
      modeLevel: row.modeLevel,
      primarySkill: row.primarySkill,
      strategyId: row.strategyId,
      variantId: row.variantId,
      layoutToken: row.layoutToken,
      statTierId: row.statTierId,
      swapped: row.swapped,
      knightAdv: row.knightAdv,
      bossAdv: row.bossAdv,
      setupUas: row.setupUas,
      meanDamage: row.meanDamage,
      batteryScore: row.batteryScore,
      survivalRate: row.survivalRate,
      meanTurnsSurvived: row.meanTurnsSurvived,
      anchorId: anchorId,
      anchorVariant: anchorVariant,
      factorType: factorType,
      factorDelta: factorDelta,
      factorLabel: factorLabel,
      deltaSetupUas: 0,
      deltaMeanDamage: 0,
      deltaSurvivalRate: 0,
      deltaMeanTurns: 0,
      deltaBatteryScore: 0,
    );
  }

  _SensitivityRow withBaseline(_SensitivityRow? baseline) {
    if (baseline == null || factorType == 'baseline') return this;
    return _SensitivityRow(
      scenarioId: scenarioId,
      modeLevel: modeLevel,
      primarySkill: primarySkill,
      strategyId: strategyId,
      variantId: variantId,
      layoutToken: layoutToken,
      statTierId: statTierId,
      swapped: swapped,
      knightAdv: knightAdv,
      bossAdv: bossAdv,
      setupUas: setupUas,
      meanDamage: meanDamage,
      batteryScore: batteryScore,
      survivalRate: survivalRate,
      meanTurnsSurvived: meanTurnsSurvived,
      anchorId: anchorId,
      anchorVariant: anchorVariant,
      factorType: factorType,
      factorDelta: factorDelta,
      factorLabel: factorLabel,
      deltaSetupUas: setupUas - baseline.setupUas,
      deltaMeanDamage: meanDamage - baseline.meanDamage,
      deltaSurvivalRate: survivalRate - baseline.survivalRate,
      deltaMeanTurns: meanTurnsSurvived - baseline.meanTurnsSurvived,
      deltaBatteryScore: batteryScore - baseline.batteryScore,
    );
  }
}

class _CorrelationRow {
  final String key;
  final int count;
  final double uasVsMeanDamage;
  final double uasVsBatteryScore;

  const _CorrelationRow({
    required this.key,
    required this.count,
    required this.uasVsMeanDamage,
    required this.uasVsBatteryScore,
  });
}

class _TopKRow {
  final String groupType;
  final String groupKey;
  final int requestedK;
  final int effectiveK;
  final int groupSize;
  final double overlap;

  const _TopKRow({
    required this.groupType,
    required this.groupKey,
    required this.requestedK,
    required this.effectiveK,
    required this.groupSize,
    required this.overlap,
  });
}

class _Mismatch {
  final String groupType;
  final String groupKey;
  final String source;
  final _SampleRow row;

  const _Mismatch({
    required this.groupType,
    required this.groupKey,
    required this.source,
    required this.row,
  });
}

class _BreakEven {
  final String anchorId;
  final String modeLevel;
  final String comparison;
  final String targetLabel;
  final double targetDelta;
  final double? equivalent;
  final String unit;

  const _BreakEven({
    required this.anchorId,
    required this.modeLevel,
    required this.comparison,
    required this.targetLabel,
    required this.targetDelta,
    required this.equivalent,
    required this.unit,
  });
}

class _Point {
  final double x;
  final double y;

  const _Point(this.x, this.y);
}

class _Corr {
  int n = 0;
  double sx = 0;
  double sy = 0;
  double sx2 = 0;
  double sy2 = 0;
  double sxy = 0;

  void add(double x, double y) {
    n += 1;
    sx += x;
    sy += y;
    sx2 += x * x;
    sy2 += y * y;
    sxy += x * y;
  }

  double get value {
    if (n <= 1) return 0;
    final numerator = (n * sxy) - (sx * sy);
    final left = (n * sx2) - (sx * sx);
    final right = (n * sy2) - (sy * sy);
    final denominator = math.sqrt(math.max(0, left) * math.max(0, right));
    if (denominator <= 0) return 0;
    return numerator / denominator;
  }
}

class _Tracker {
  final List<_SampleRow> _byUas;
  final List<_SampleRow> _byDamage;

  _Tracker(List<_SampleRow> rows)
      : _byUas = List<_SampleRow>.from(rows)
          ..sort((a, b) => b.setupUas.compareTo(a.setupUas)),
        _byDamage = List<_SampleRow>.from(rows)
          ..sort((a, b) => b.meanDamage.compareTo(a.meanDamage));

  double overlap(int requestedK) {
    final left = _slice(_byUas, requestedK);
    final right = _slice(_byDamage, requestedK);
    if (left.isEmpty || right.isEmpty) return 0;
    final leftIds = left.map((value) => value.scenarioId).toSet();
    final rightIds = right.map((value) => value.scenarioId).toSet();
    return leftIds.intersection(rightIds).length /
        math.min(leftIds.length, rightIds.length);
  }

  List<_SampleRow> uasOnly(int requestedK) {
    final rightIds =
        _slice(_byDamage, requestedK).map((value) => value.scenarioId).toSet();
    return _slice(_byUas, requestedK)
        .where((value) => !rightIds.contains(value.scenarioId))
        .toList(growable: false);
  }

  List<_SampleRow> damageOnly(int requestedK) {
    final rightIds =
        _slice(_byUas, requestedK).map((value) => value.scenarioId).toSet();
    return _slice(_byDamage, requestedK)
        .where((value) => !rightIds.contains(value.scenarioId))
        .toList(growable: false);
  }

  List<_SampleRow> _slice(List<_SampleRow> rows, int requestedK) =>
      rows.take(math.min(rows.length, requestedK)).toList(growable: false);
}
