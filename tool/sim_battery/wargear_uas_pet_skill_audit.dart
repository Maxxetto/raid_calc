import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_loader.dart';
import 'package:raid_calc/data/wargear_universal_scoring.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

import 'boss_sim_battery_config.dart';
import 'boss_sim_battery_models.dart';
import 'boss_sim_battery_runner.dart';

class WargearUasPetSkillAuditSummary {
  final Directory outputDir;
  final int runsPerScenario;
  final int scenarioCount;
  final List<String> generatedFiles;

  const WargearUasPetSkillAuditSummary({
    required this.outputDir,
    required this.runsPerScenario,
    required this.scenarioCount,
    required this.generatedFiles,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'outputDir': outputDir.path,
        'runsPerScenario': runsPerScenario,
        'scenarioCount': scenarioCount,
        'generatedFiles': generatedFiles,
      };
}

class WargearUasPetSkillAuditRunner {
  final WargearUniversalScoringEngine _engine;
  final BossSimulationRunner _batteryRunner;
  final Map<String, WargearBossPressureProfile> _bossPressureCache =
      <String, WargearBossPressureProfile>{};

  WargearUasPetSkillAuditRunner({
    WargearUniversalScoringEngine? engine,
    BossSimulationRunner? batteryRunner,
  })  : _engine = engine ?? const WargearUniversalScoringEngine(),
        _batteryRunner = batteryRunner ?? BossSimulationRunner();

  Future<WargearUasPetSkillAuditSummary> run({
    required Directory outputDir,
    int runsPerScenario = 100,
  }) async {
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }

    final plan = await _buildPlan(runsPerScenario);
    final rows = await _runPlan(plan);
    final familySummary = _familySummaries(rows);
    final correlations = _correlations(rows);
    final mismatches = _mismatches(rows);
    final recommendations = _recommendations(familySummary);

    final generatedFiles = <String>[
      await _writeJson(
        File('${outputDir.path}/uas_pet_skill_audit_summary.json'),
        <String, Object?>{
          'runsPerScenario': runsPerScenario,
          'scenarioCount': rows.length,
          'comboCount': _comboSpecs.length,
          'anchorCount': _anchorSpecs.length,
          'targets': plan.base.targets.map((value) => value.toJson()).toList(),
        },
      ),
      await _writeRowsCsv(
        File('${outputDir.path}/uas_pet_skill_rows.csv'),
        rows,
      ),
      await _writeFamilySummaryCsv(
        File('${outputDir.path}/uas_pet_skill_family_ranking.csv'),
        familySummary,
      ),
      await _writeCorrelationCsv(
        File('${outputDir.path}/uas_pet_skill_correlations.csv'),
        correlations,
      ),
      await _writeMismatchCsv(
        File('${outputDir.path}/uas_pet_skill_mismatches.csv'),
        mismatches,
      ),
      await _writeRecommendationCsv(
        File('${outputDir.path}/uas_pet_skill_factor_recommendations.csv'),
        recommendations,
      ),
      await _writeMarkdown(
        File('${outputDir.path}/uas_pet_skill_report.md'),
        rows: rows,
        familySummary: familySummary,
        correlations: correlations,
        recommendations: recommendations,
      ),
    ];

    final summary = WargearUasPetSkillAuditSummary(
      outputDir: outputDir,
      runsPerScenario: runsPerScenario,
      scenarioCount: rows.length,
      generatedFiles: List<String>.unmodifiable(generatedFiles),
    );
    await _writeJson(
      File('${outputDir.path}/uas_pet_skill_report_index.json'),
      summary.toJson(),
    );
    return summary;
  }

  Future<_PetPlan> _buildPlan(int runsPerScenario) async {
    final catalog = await WargearWardrobeLoader.load();
    final base = _baseConfig(runsPerScenario);
    final cases = <_PetCase>[];
    for (final target in base.targets) {
      for (final anchor in _anchorSpecs) {
        for (final combo in _comboSpecs) {
          cases.add(
            _PetCase(
              combo: combo,
              anchor: anchor,
              target: target,
              scenario: _buildScenario(
                catalog: catalog,
                base: base,
                target: target,
                combo: combo,
                anchor: anchor,
              ),
            ),
          );
        }
      }
    }
    return _PetPlan(base: base, cases: cases);
  }

  BossSimulationScenario _buildScenario({
    required WargearWardrobeCatalog catalog,
    required BossSimulationConfig base,
    required BossSimulationModeLevel target,
    required _PetComboSpec combo,
    required _AnchorSpec anchor,
  }) {
    final config = BossSimulationConfig(
      targets: <BossSimulationModeLevel>[target],
      runsPerScenario: base.runsPerScenario,
      layoutPermutations: <List<WargearRole>>[_layout(anchor.layoutToken)],
      knightAdvantageVectors: <List<double>>[
        List<double>.from(anchor.knightAdvantage),
      ],
      bossAdvantageVectors: <List<double>>[
        List<double>.from(anchor.bossAdvantage),
      ],
      petUsageStrategies: <BossSimulationPetStrategy>[
        BossSimulationPetStrategy(
          id: combo.usageId,
          label: combo.usageMode.shortLabel(),
          usageMode: combo.usageMode,
        ),
      ],
      petPrimarySkills: <String>[combo.primarySkill],
      petSecondarySkill: combo.secondarySkill,
      statTiers: <BossSimulationStatTier>[
        BossSimulationStatTier(id: anchor.statTierId, bonusStats: anchor.stats),
      ],
      includeSwappedAttackDefenseVariant: false,
      randomization: base.randomization,
      petMatchByKnightSlot: base.petMatchByKnightSlot,
      petStrongVsBossByKnightSlot: base.petStrongVsBossByKnightSlot,
      petAttackResolutionPolicy: base.petAttackResolutionPolicy,
      petAdvantageMultiplier: base.petAdvantageMultiplier,
      knightStunChances: const <double>[0.0, 0.0, 0.0],
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
        .first;
  }

  Future<List<_PetAuditRow>> _runPlan(_PetPlan plan) async {
    final bySecondary = <String, List<_PetCase>>{};
    for (final item in plan.cases) {
      bySecondary
          .putIfAbsent(item.combo.secondarySkill, () => <_PetCase>[])
          .add(item);
    }

    final rows = <_PetAuditRow>[];
    for (final entry in bySecondary.entries) {
      final secondSkill = entry.key;
      final cases = entry.value;
      final config = _configForSecondaryGroup(
        plan.base,
        secondSkill: secondSkill,
        primarySkills: cases
            .map((value) => value.combo.primarySkill)
            .toSet()
            .toList(growable: false),
        strategies: cases
            .map(
              (value) => BossSimulationPetStrategy(
                id: value.combo.usageId,
                label: value.combo.usageMode.shortLabel(),
                usageMode: value.combo.usageMode,
              ),
            )
            .toSet()
            .toList(growable: false),
      );
      final batch = await _batteryRunner.runSelectedScenarios(
        config: config,
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
        rows.add(
          _PetAuditRow(
            familyId: item.combo.familyId,
            familyLabel: item.combo.label,
            modeLevel: '${item.target.modeKey}_L${item.target.bossLevel}',
            anchorId: item.anchor.id,
            usageId: item.combo.usageId,
            primarySkill: item.combo.primarySkill,
            secondarySkill: item.combo.secondarySkill,
            scenarioId: item.scenario.scenarioId,
            setupUas: await _computeSetupUas(item),
            meanDamage: aggregate.meanTotalDamage,
            batteryScore: score.finalScore,
            survivalRate: aggregate.survivalRate,
            meanTurnsSurvived: aggregate.meanTurnsSurvived,
            meanSpecial1Casts: aggregate.meanPetSpecial1Casts,
            meanSpecial2Casts: aggregate.meanPetSpecial2Casts,
          ),
        );
      }
    }
    return rows;
  }

  Future<double> _computeSetupUas(_PetCase item) async {
    final profile = await _bossPressureProfile(
      modeKey: item.target.modeKey,
      raidMode: item.target.raidMode,
      bossLevel: item.target.bossLevel,
    );
    var total = 0.0;
    for (final slot in item.scenario.slotProfiles) {
      total += _engine
          .score(
            stats: slot.effectiveStatsBeforeRandomization,
            armorElements: const <ElementType>[
              ElementType.fire,
              ElementType.fire,
            ],
            context: WargearUniversalScoreContext(
              bossMode: item.target.modeKey,
              bossLevel: item.target.bossLevel,
              bossElements: const <ElementType>[
                ElementType.fire,
                ElementType.fire,
              ],
              petElements: const <ElementType>[],
              petElementalAttack: 0,
              petElementalDefense: 0,
              petSkillUsageMode: item.combo.usageMode,
              petPrimarySkillName: item.combo.primarySkill,
              petSecondarySkillName: item.combo.secondarySkill,
              knightAdvantageOverride:
                  item.scenario.knightAdvantageVector[slot.slotIndex],
              bossAdvantageOverride:
                  item.scenario.bossAdvantageVector[slot.slotIndex],
              bossPressureProfile: profile,
            ),
            variant: WargearUniversalScoreVariant.petAware,
          )
          .score;
    }
    return total;
  }

  Future<WargearBossPressureProfile> _bossPressureProfile({
    required String modeKey,
    required bool raidMode,
    required int bossLevel,
  }) async {
    final cacheKey = '$modeKey:$bossLevel';
    final cached = _bossPressureCache[cacheKey];
    if (cached != null) return cached;
    final boss = await ConfigLoader.loadBoss(
      raidMode: raidMode,
      bossLevel: bossLevel,
      adv: const <double>[1.0, 1.0, 1.0],
      fightModeKey: 'normal',
    );
    final profile = WargearBossPressureProfile.fromBossStats(
      modeKey: modeKey,
      bossAttack: boss.stats.attack,
      bossDefense: boss.stats.defense,
      bossHealth: boss.stats.hp,
    );
    _bossPressureCache[cacheKey] = profile;
    return profile;
  }

  BossSimulationConfig _baseConfig(int runsPerScenario) {
    final base = BossSimulationConfig.defaultBattery(
      runsPerScenario: runsPerScenario,
    );
    return BossSimulationConfig(
      targets: base.targets,
      runsPerScenario: base.runsPerScenario,
      layoutPermutations: base.layoutPermutations,
      knightAdvantageVectors: base.knightAdvantageVectors,
      bossAdvantageVectors: base.bossAdvantageVectors,
      petUsageStrategies: base.petUsageStrategies,
      petPrimarySkills: base.petPrimarySkills,
      petSecondarySkill: base.petSecondarySkill,
      statTiers: base.statTiers,
      includeSwappedAttackDefenseVariant: false,
      randomization: base.randomization,
      petMatchByKnightSlot: base.petMatchByKnightSlot,
      petStrongVsBossByKnightSlot: base.petStrongVsBossByKnightSlot,
      petAttackResolutionPolicy: base.petAttackResolutionPolicy,
      petAdvantageMultiplier: base.petAdvantageMultiplier,
      knightStunChances: const <double>[0.0, 0.0, 0.0],
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

  BossSimulationConfig _configForSecondaryGroup(
    BossSimulationConfig base, {
    required String secondSkill,
    required List<String> primarySkills,
    required List<BossSimulationPetStrategy> strategies,
  }) {
    return BossSimulationConfig(
      targets: base.targets,
      runsPerScenario: base.runsPerScenario,
      layoutPermutations: base.layoutPermutations,
      knightAdvantageVectors: base.knightAdvantageVectors,
      bossAdvantageVectors: base.bossAdvantageVectors,
      petUsageStrategies: strategies,
      petPrimarySkills: primarySkills,
      petSecondarySkill: secondSkill,
      statTiers: base.statTiers,
      includeSwappedAttackDefenseVariant: false,
      randomization: base.randomization,
      petMatchByKnightSlot: base.petMatchByKnightSlot,
      petStrongVsBossByKnightSlot: base.petStrongVsBossByKnightSlot,
      petAttackResolutionPolicy: base.petAttackResolutionPolicy,
      petAdvantageMultiplier: base.petAdvantageMultiplier,
      knightStunChances: const <double>[0.0, 0.0, 0.0],
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

  List<_FamilySummaryRow> _familySummaries(List<_PetAuditRow> rows) {
    final grouped = <String, List<_PetAuditRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.familyId, () => <_PetAuditRow>[]).add(row);
    }
    final out = <_FamilySummaryRow>[];
    for (final entry in grouped.entries) {
      final group = entry.value;
      out.add(
        _FamilySummaryRow(
          familyId: entry.key,
          familyLabel: group.first.familyLabel,
          scenarioCount: group.length,
          meanSetupUas: _mean(group.map((value) => value.setupUas)),
          meanDamage: _mean(group.map((value) => value.meanDamage)),
          meanBatteryScore: _mean(group.map((value) => value.batteryScore)),
          meanSurvivalRate: _mean(group.map((value) => value.survivalRate)),
        ),
      );
    }
    out.sort((a, b) => b.meanDamage.compareTo(a.meanDamage));
    for (var i = 0; i < out.length; i++) {
      out[i] = out[i].copyWith(simRank: i + 1);
    }
    final byUas = List<_FamilySummaryRow>.from(out)
      ..sort((a, b) => b.meanSetupUas.compareTo(a.meanSetupUas));
    for (var i = 0; i < byUas.length; i++) {
      final row = byUas[i];
      final match = out.indexWhere((value) => value.familyId == row.familyId);
      out[match] = out[match].copyWith(uasRank: i + 1);
    }
    final baseline = out.firstWhere(
      (row) => row.familyId == 'ew_sr_inf_s2_then_s1',
      orElse: () => out.first,
    );
    return out
        .map(
          (row) => row.copyWith(
            damageUpliftVsBaseline:
                _uplift(row.meanDamage, baseline.meanDamage),
            batteryUpliftVsBaseline:
                _uplift(row.meanBatteryScore, baseline.meanBatteryScore),
          ),
        )
        .toList(growable: false);
  }

  List<_CorrelationRow> _correlations(List<_PetAuditRow> rows) {
    final grouped = <String, List<_PetAuditRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.familyId, () => <_PetAuditRow>[]).add(row);
    }
    final out = <_CorrelationRow>[];
    for (final entry in grouped.entries) {
      final group = entry.value;
      out.add(
        _CorrelationRow(
          familyId: entry.key,
          familyLabel: group.first.familyLabel,
          scenarioCount: group.length,
          pearsonUasVsMeanDamage: _pearson(
            group.map((value) => value.setupUas),
            group.map((value) => value.meanDamage),
          ),
          pearsonUasVsBatteryScore: _pearson(
            group.map((value) => value.setupUas),
            group.map((value) => value.batteryScore),
          ),
        ),
      );
    }
    out.sort((a, b) => a.familyId.compareTo(b.familyId));
    return out;
  }

  List<_MismatchRow> _mismatches(List<_PetAuditRow> rows) {
    final byScenarioKey = <String, List<_PetAuditRow>>{};
    for (final row in rows) {
      final key = '${row.modeLevel}|${row.anchorId}';
      byScenarioKey.putIfAbsent(key, () => <_PetAuditRow>[]).add(row);
    }
    final out = <_MismatchRow>[];
    for (final entry in byScenarioKey.entries) {
      final group = entry.value;
      final byDamage = List<_PetAuditRow>.from(group)
        ..sort((a, b) => b.meanDamage.compareTo(a.meanDamage));
      final byUas = List<_PetAuditRow>.from(group)
        ..sort((a, b) => b.setupUas.compareTo(a.setupUas));
      final simBest = byDamage.first;
      final uasBest = byUas.first;
      if (simBest.familyId != uasBest.familyId) {
        out.add(
          _MismatchRow(
            groupKey: entry.key,
            simulatedBestFamily: simBest.familyLabel,
            uasBestFamily: uasBest.familyLabel,
            simulatedBestMeanDamage: simBest.meanDamage,
            uasBestMeanDamage: uasBest.meanDamage,
            simulatedBestUas: simBest.setupUas,
            uasBestUas: uasBest.setupUas,
          ),
        );
      }
    }
    return out;
  }

  List<_RecommendationRow> _recommendations(List<_FamilySummaryRow> rows) {
    return rows.map((row) {
      final delta = row.simRank - row.uasRank;
      final action = delta <= -2
          ? 'increase'
          : delta >= 2
              ? 'reduce'
              : 'neutral';
      return _RecommendationRow(
        familyId: row.familyId,
        familyLabel: row.familyLabel,
        simRank: row.simRank,
        uasRank: row.uasRank,
        action: action,
      );
    }).toList(growable: false);
  }

  Future<String> _writeJson(File file, Map<String, Object?> data) async {
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    return file.path;
  }

  Future<String> _writeRowsCsv(File file, List<_PetAuditRow> rows) async {
    final buffer = StringBuffer()
      ..writeln(
        'family_id,family_label,mode_level,anchor_id,usage_id,primary_skill,secondary_skill,scenario_id,setup_uas,mean_damage,battery_score,survival_rate,mean_turns_survived,mean_pet_special1_casts,mean_pet_special2_casts',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.familyId},${_csv(row.familyLabel)},${row.modeLevel},${row.anchorId},${row.usageId},${_csv(row.primarySkill)},${_csv(row.secondarySkill)},${row.scenarioId},${row.setupUas},${row.meanDamage},${row.batteryScore},${row.survivalRate},${row.meanTurnsSurvived},${row.meanSpecial1Casts},${row.meanSpecial2Casts}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeFamilySummaryCsv(
    File file,
    List<_FamilySummaryRow> rows,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        'family_id,family_label,scenario_count,sim_rank,uas_rank,mean_setup_uas,mean_damage,mean_battery_score,mean_survival_rate,damage_uplift_vs_baseline,battery_uplift_vs_baseline',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.familyId},${_csv(row.familyLabel)},${row.scenarioCount},${row.simRank},${row.uasRank},${row.meanSetupUas},${row.meanDamage},${row.meanBatteryScore},${row.meanSurvivalRate},${row.damageUpliftVsBaseline},${row.batteryUpliftVsBaseline}',
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
        'family_id,family_label,scenario_count,pearson_uas_vs_mean_damage,pearson_uas_vs_battery_score',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.familyId},${_csv(row.familyLabel)},${row.scenarioCount},${row.pearsonUasVsMeanDamage},${row.pearsonUasVsBatteryScore}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeMismatchCsv(
    File file,
    List<_MismatchRow> rows,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        'group_key,simulated_best_family,uas_best_family,simulated_best_mean_damage,uas_best_mean_damage,simulated_best_uas,uas_best_uas',
      );
    for (final row in rows) {
      buffer.writeln(
        '${_csv(row.groupKey)},${_csv(row.simulatedBestFamily)},${_csv(row.uasBestFamily)},${row.simulatedBestMeanDamage},${row.uasBestMeanDamage},${row.simulatedBestUas},${row.uasBestUas}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeRecommendationCsv(
    File file,
    List<_RecommendationRow> rows,
  ) async {
    final buffer = StringBuffer()
      ..writeln('family_id,family_label,sim_rank,uas_rank,action');
    for (final row in rows) {
      buffer.writeln(
        '${row.familyId},${_csv(row.familyLabel)},${row.simRank},${row.uasRank},${row.action}',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }

  Future<String> _writeMarkdown(
    File file, {
    required List<_PetAuditRow> rows,
    required List<_FamilySummaryRow> familySummary,
    required List<_CorrelationRow> correlations,
    required List<_RecommendationRow> recommendations,
  }) async {
    final buffer = StringBuffer()
      ..writeln('# UAS Pet Skill Audit')
      ..writeln()
      ..writeln('- Scenarios: ${rows.length}')
      ..writeln('- Families: ${familySummary.length}')
      ..writeln('- Anchors: ${_anchorSpecs.length}')
      ..writeln()
      ..writeln('## Ranking')
      ..writeln()
      ..writeln(
          '| Rank | Family | Mean damage | Mean battery | Mean UAS | Delta damage vs EW+SR∞ 2,1 |')
      ..writeln('| --- | --- | ---: | ---: | ---: | ---: |');
    for (final row in familySummary) {
      buffer.writeln(
        '| ${row.simRank} | ${row.familyLabel} | ${row.meanDamage.toStringAsFixed(2)} | ${row.meanBatteryScore.toStringAsFixed(2)} | ${row.meanSetupUas.toStringAsFixed(2)} | ${(row.damageUpliftVsBaseline * 100).toStringAsFixed(2)}% |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Correlation')
      ..writeln()
      ..writeln('| Family | UAS vs mean damage | UAS vs battery score |')
      ..writeln('| --- | ---: | ---: |');
    for (final row in correlations) {
      buffer.writeln(
        '| ${row.familyLabel} | ${row.pearsonUasVsMeanDamage.toStringAsFixed(4)} | ${row.pearsonUasVsBatteryScore.toStringAsFixed(4)} |',
      );
    }
    buffer
      ..writeln()
      ..writeln('## Recommendations')
      ..writeln()
      ..writeln('| Family | Action | Sim rank | UAS rank |')
      ..writeln('| --- | --- | ---: | ---: |');
    for (final row in recommendations) {
      buffer.writeln(
        '| ${row.familyLabel} | ${row.action} | ${row.simRank} | ${row.uasRank} |',
      );
    }
    await file.writeAsString(buffer.toString());
    return file.path;
  }
}

class _PetPlan {
  final BossSimulationConfig base;
  final List<_PetCase> cases;

  const _PetPlan({
    required this.base,
    required this.cases,
  });
}

class _PetCase {
  final _PetComboSpec combo;
  final _AnchorSpec anchor;
  final BossSimulationModeLevel target;
  final BossSimulationScenario scenario;

  const _PetCase({
    required this.combo,
    required this.anchor,
    required this.target,
    required this.scenario,
  });
}

class _PetAuditRow {
  final String familyId;
  final String familyLabel;
  final String modeLevel;
  final String anchorId;
  final String usageId;
  final String primarySkill;
  final String secondarySkill;
  final String scenarioId;
  final double setupUas;
  final double meanDamage;
  final double batteryScore;
  final double survivalRate;
  final double meanTurnsSurvived;
  final double meanSpecial1Casts;
  final double meanSpecial2Casts;

  const _PetAuditRow({
    required this.familyId,
    required this.familyLabel,
    required this.modeLevel,
    required this.anchorId,
    required this.usageId,
    required this.primarySkill,
    required this.secondarySkill,
    required this.scenarioId,
    required this.setupUas,
    required this.meanDamage,
    required this.batteryScore,
    required this.survivalRate,
    required this.meanTurnsSurvived,
    required this.meanSpecial1Casts,
    required this.meanSpecial2Casts,
  });
}

class _FamilySummaryRow {
  final String familyId;
  final String familyLabel;
  final int scenarioCount;
  final double meanSetupUas;
  final double meanDamage;
  final double meanBatteryScore;
  final double meanSurvivalRate;
  final int simRank;
  final int uasRank;
  final double damageUpliftVsBaseline;
  final double batteryUpliftVsBaseline;

  const _FamilySummaryRow({
    required this.familyId,
    required this.familyLabel,
    required this.scenarioCount,
    required this.meanSetupUas,
    required this.meanDamage,
    required this.meanBatteryScore,
    required this.meanSurvivalRate,
    this.simRank = 0,
    this.uasRank = 0,
    this.damageUpliftVsBaseline = 0.0,
    this.batteryUpliftVsBaseline = 0.0,
  });

  _FamilySummaryRow copyWith({
    int? simRank,
    int? uasRank,
    double? damageUpliftVsBaseline,
    double? batteryUpliftVsBaseline,
  }) {
    return _FamilySummaryRow(
      familyId: familyId,
      familyLabel: familyLabel,
      scenarioCount: scenarioCount,
      meanSetupUas: meanSetupUas,
      meanDamage: meanDamage,
      meanBatteryScore: meanBatteryScore,
      meanSurvivalRate: meanSurvivalRate,
      simRank: simRank ?? this.simRank,
      uasRank: uasRank ?? this.uasRank,
      damageUpliftVsBaseline:
          damageUpliftVsBaseline ?? this.damageUpliftVsBaseline,
      batteryUpliftVsBaseline:
          batteryUpliftVsBaseline ?? this.batteryUpliftVsBaseline,
    );
  }
}

class _CorrelationRow {
  final String familyId;
  final String familyLabel;
  final int scenarioCount;
  final double pearsonUasVsMeanDamage;
  final double pearsonUasVsBatteryScore;

  const _CorrelationRow({
    required this.familyId,
    required this.familyLabel,
    required this.scenarioCount,
    required this.pearsonUasVsMeanDamage,
    required this.pearsonUasVsBatteryScore,
  });
}

class _MismatchRow {
  final String groupKey;
  final String simulatedBestFamily;
  final String uasBestFamily;
  final double simulatedBestMeanDamage;
  final double uasBestMeanDamage;
  final double simulatedBestUas;
  final double uasBestUas;

  const _MismatchRow({
    required this.groupKey,
    required this.simulatedBestFamily,
    required this.uasBestFamily,
    required this.simulatedBestMeanDamage,
    required this.uasBestMeanDamage,
    required this.simulatedBestUas,
    required this.uasBestUas,
  });
}

class _RecommendationRow {
  final String familyId;
  final String familyLabel;
  final int simRank;
  final int uasRank;
  final String action;

  const _RecommendationRow({
    required this.familyId,
    required this.familyLabel,
    required this.simRank,
    required this.uasRank,
    required this.action,
  });
}

class _PetComboSpec {
  final String familyId;
  final String label;
  final String primarySkill;
  final String secondarySkill;
  final String usageId;
  final PetSkillUsageMode usageMode;

  const _PetComboSpec({
    required this.familyId,
    required this.label,
    required this.primarySkill,
    required this.secondarySkill,
    required this.usageId,
    required this.usageMode,
  });
}

class _AnchorSpec {
  final String id;
  final String layoutToken;
  final List<double> knightAdvantage;
  final List<double> bossAdvantage;
  final String statTierId;
  final WargearStats stats;

  const _AnchorSpec({
    required this.id,
    required this.layoutToken,
    required this.knightAdvantage,
    required this.bossAdvantage,
    required this.statTierId,
    required this.stats,
  });
}

double _mean(Iterable<double> values) {
  final list = values.toList(growable: false);
  if (list.isEmpty) return 0.0;
  return list.reduce((a, b) => a + b) / list.length;
}

double _pearson(Iterable<double> xs, Iterable<double> ys) {
  final x = xs.toList(growable: false);
  final y = ys.toList(growable: false);
  if (x.length != y.length || x.length < 2) return 0.0;
  final mx = _mean(x);
  final my = _mean(y);
  var numerator = 0.0;
  var denomX = 0.0;
  var denomY = 0.0;
  for (var i = 0; i < x.length; i++) {
    final dx = x[i] - mx;
    final dy = y[i] - my;
    numerator += dx * dy;
    denomX += dx * dx;
    denomY += dy * dy;
  }
  if (denomX <= 0.0 || denomY <= 0.0) return 0.0;
  return numerator / math.sqrt(denomX * denomY);
}

double _uplift(double value, double baseline) {
  if (baseline.abs() <= 1e-9) return 0.0;
  return (value - baseline) / baseline;
}

String _csv(String value) {
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}

List<WargearRole> _layout(String token) => token
    .split('')
    .map((char) => char == 'p' ? WargearRole.primary : WargearRole.secondary)
    .toList(growable: false);

const List<_PetComboSpec> _comboSpecs = <_PetComboSpec>[
  _PetComboSpec(
    familyId: 'ew_sr_inf_s2_then_s1',
    label: 'EW + SR∞ | 2,1',
    primarySkill: 'Elemental Weakness',
    secondarySkill: 'Special Regeneration (inf)',
    usageId: 's2_then_s1',
    usageMode: PetSkillUsageMode.special2ThenSpecial1,
  ),
  _PetComboSpec(
    familyId: 'ew_sr_inf_double_s2_then_s1',
    label: 'EW + SR∞ | 2,2,1',
    primarySkill: 'Elemental Weakness',
    secondarySkill: 'Special Regeneration (inf)',
    usageId: 'double_s2_then_s1',
    usageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
  ),
  _PetComboSpec(
    familyId: 'vamp_sr_inf_s2_then_s1',
    label: 'Vamp + SR∞ | 2,1',
    primarySkill: 'Vampiric Attack',
    secondarySkill: 'Special Regeneration (inf)',
    usageId: 's2_then_s1',
    usageMode: PetSkillUsageMode.special2ThenSpecial1,
  ),
  _PetComboSpec(
    familyId: 'vamp_sr_inf_double_s2_then_s1',
    label: 'Vamp + SR∞ | 2,2,1',
    primarySkill: 'Vampiric Attack',
    secondarySkill: 'Special Regeneration (inf)',
    usageId: 'double_s2_then_s1',
    usageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
  ),
  _PetComboSpec(
    familyId: 'soul_sr_inf_s2_then_s1',
    label: 'Soul Burn + SR∞ | 2,1',
    primarySkill: 'Soul Burn',
    secondarySkill: 'Special Regeneration (inf)',
    usageId: 's2_then_s1',
    usageMode: PetSkillUsageMode.special2ThenSpecial1,
  ),
  _PetComboSpec(
    familyId: 'soul_sr_inf_double_s2_then_s1',
    label: 'Soul Burn + SR∞ | 2,2,1',
    primarySkill: 'Soul Burn',
    secondarySkill: 'Special Regeneration (inf)',
    usageId: 'double_s2_then_s1',
    usageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
  ),
  _PetComboSpec(
    familyId: 'drs_special1_only',
    label: 'DRS + EW | 1',
    primarySkill: 'Durable Rock Shield',
    secondarySkill: 'Elemental Weakness',
    usageId: 'special1_only',
    usageMode: PetSkillUsageMode.special1Only,
  ),
  _PetComboSpec(
    familyId: 'shatter_special2_only',
    label: 'EW + Shatter | 2',
    primarySkill: 'Elemental Weakness',
    secondarySkill: 'Shatter Shield',
    usageId: 'special2_only',
    usageMode: PetSkillUsageMode.special2Only,
  ),
  _PetComboSpec(
    familyId: 'cyclone_special2_only',
    label: 'EW + Cyclone | 2',
    primarySkill: 'Elemental Weakness',
    secondarySkill: 'Cyclone Boost',
    usageId: 'special2_only',
    usageMode: PetSkillUsageMode.special2Only,
  ),
  _PetComboSpec(
    familyId: 'cyclone_cycle_1_2',
    label: 'EW + Cyclone | 1,2',
    primarySkill: 'Elemental Weakness',
    secondarySkill: 'Cyclone Boost',
    usageId: 'cycle_1_2',
    usageMode: PetSkillUsageMode.cycleSpecial1Then2,
  ),
];

const List<_AnchorSpec> _anchorSpecs = <_AnchorSpec>[
  _AnchorSpec(
    id: 'fragile',
    layoutToken: 'pss',
    knightAdvantage: <double>[1.0, 1.0, 1.0],
    bossAdvantage: <double>[1.5, 1.5, 1.5],
    statTierId: 'tier_2',
    stats: WargearStats(attack: 35000, defense: 25000, health: 650),
  ),
  _AnchorSpec(
    id: 'balanced',
    layoutToken: 'sps',
    knightAdvantage: <double>[1.5, 1.0, 2.0],
    bossAdvantage: <double>[1.0, 1.5, 2.0],
    statTierId: 'tier_4',
    stats: WargearStats(attack: 50000, defense: 38000, health: 850),
  ),
  _AnchorSpec(
    id: 'strong',
    layoutToken: 'ssp',
    knightAdvantage: <double>[2.0, 1.5, 1.0],
    bossAdvantage: <double>[1.0, 1.0, 1.0],
    statTierId: 'tier_6',
    stats: WargearStats(attack: 70000, defense: 60000, health: 1200),
  ),
];
