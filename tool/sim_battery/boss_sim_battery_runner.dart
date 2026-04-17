import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/engine/engine.dart';
import 'package:raid_calc/core/timing_acc.dart';
import 'package:raid_calc/data/config_loader.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_compendium_loader.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_skill_semantics_loader.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

import 'boss_sim_battery_config.dart';
import 'boss_sim_battery_models.dart';

class BossSimulationPetSkillPreset {
  final String skillName;
  final String sourcePetId;
  final String sourcePetName;
  final String sourceTierId;
  final String sourceProfileId;
  final int sourceProfileLevel;
  final int petAttack;
  final PetResolvedEffect effect;

  const BossSimulationPetSkillPreset({
    required this.skillName,
    required this.sourcePetId,
    required this.sourcePetName,
    required this.sourceTierId,
    required this.sourceProfileId,
    required this.sourceProfileLevel,
    required this.petAttack,
    required this.effect,
  });
}

class BossSimulationPetLoadout {
  final BossSimulationPetSkillPreset primaryPreset;
  final BossSimulationPetSkillPreset secondaryPreset;
  final double petAttack;
  final List<PetResolvedEffect> effects;

  const BossSimulationPetLoadout({
    required this.primaryPreset,
    required this.secondaryPreset,
    required this.petAttack,
    required this.effects,
  });
}

class BossSimulationScenarioGenerator {
  BossSimulationScenarioGenerator({
    required this.config,
    required this.catalog,
  });

  final BossSimulationConfig config;
  final WargearWardrobeCatalog catalog;

  Iterable<BossSimulationScenario> generate() sync* {
    for (final target in config.targets) {
      for (final knightAdvantage in config.knightAdvantageVectors) {
        for (final bossAdvantage in config.bossAdvantageVectors) {
          for (final layout in config.layoutPermutations) {
            for (final strategy in config.petUsageStrategies) {
              for (final primarySkill in config.petPrimarySkills) {
                for (final tier in config.statTiers) {
                  yield _buildScenario(
                    target: target,
                    knightAdvantage: knightAdvantage,
                    bossAdvantage: bossAdvantage,
                    layout: layout,
                    strategy: strategy,
                    primarySkill: primarySkill,
                    tier: tier,
                    swapped: false,
                  );
                  if (config.includeSwappedAttackDefenseVariant) {
                    yield _buildScenario(
                      target: target,
                      knightAdvantage: knightAdvantage,
                      bossAdvantage: bossAdvantage,
                      layout: layout,
                      strategy: strategy,
                      primarySkill: primarySkill,
                      tier: tier,
                      swapped: true,
                    );
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  BossSimulationSummary summarize() {
    var totalScenarios = 0;
    final byMode = <String, int>{};
    final byBossLevel = <String, int>{};
    final byStatTier = <String, int>{};
    final byPrimarySkill = <String, int>{};
    Map<String, Object?> sampleScenario = const <String, Object?>{};

    for (final scenario in generate()) {
      totalScenarios += 1;
      byMode.update(scenario.modeKey, (value) => value + 1, ifAbsent: () => 1);
      final bossLevelKey = '${scenario.modeKey}_L${scenario.bossLevel}';
      byBossLevel.update(
        bossLevelKey,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      byStatTier.update(
        scenario.statTierId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      byPrimarySkill.update(
        scenario.petPrimarySkill,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      if (sampleScenario.isEmpty) {
        sampleScenario = scenario.toJson();
      }
    }

    return BossSimulationSummary(
      totalScenarios: totalScenarios,
      totalRunsExpected: totalScenarios * config.runsPerScenario,
      scenariosByMode: Map<String, int>.unmodifiable(byMode),
      scenariosByBossLevel: Map<String, int>.unmodifiable(byBossLevel),
      scenariosByStatTier: Map<String, int>.unmodifiable(byStatTier),
      scenariosByPetPrimarySkill: Map<String, int>.unmodifiable(byPrimarySkill),
      sampleScenario: sampleScenario,
    );
  }

  BossSimulationScenario _buildScenario({
    required BossSimulationModeLevel target,
    required List<double> knightAdvantage,
    required List<double> bossAdvantage,
    required List<WargearRole> layout,
    required BossSimulationPetStrategy strategy,
    required String primarySkill,
    required BossSimulationStatTier tier,
    required bool swapped,
  }) {
    final statPackage = swapped
        ? WargearStats(
            attack: tier.bonusStats.defense,
            defense: tier.bonusStats.attack,
            health: tier.bonusStats.health,
          )
        : tier.bonusStats;
    final rules = catalog.rules;
    final slotProfiles = <BossSimulationScenarioSlotProfile>[];
    for (var index = 0; index < layout.length; index++) {
      final role = layout[index];
      final base = rules.knightBaseStats[role] ??
          const WargearKnightBaseStats(attack: 0, defense: 0, health: 0);
      final effective = WargearStats(
        attack: base.attack + statPackage.attack,
        defense: base.defense + statPackage.defense,
        health: base.health + statPackage.health,
      );
      slotProfiles.add(
        BossSimulationScenarioSlotProfile(
          slotIndex: index,
          role: role,
          baseKnightStats: WargearStats(
            attack: base.attack,
            defense: base.defense,
            health: base.health,
          ),
          statPackage: statPackage,
          effectiveStatsBeforeRandomization: effective,
        ),
      );
    }

    return BossSimulationScenario(
      scenarioId: _buildScenarioId(
        modeKey: target.modeKey,
        bossLevel: target.bossLevel,
        layout: layout,
        knightAdvantage: knightAdvantage,
        bossAdvantage: bossAdvantage,
        strategyId: strategy.id,
        primarySkill: primarySkill,
        tierId: tier.id,
        swapped: swapped,
      ),
      modeKey: target.modeKey,
      raidMode: target.raidMode,
      bossLevel: target.bossLevel,
      fightModeKey: config.fightModeKey,
      layout: List<WargearRole>.unmodifiable(layout),
      knightAdvantageVector: List<double>.unmodifiable(knightAdvantage),
      bossAdvantageVector: List<double>.unmodifiable(bossAdvantage),
      petStrategyId: strategy.id,
      petStrategyLabel: strategy.label,
      petPrimarySkill: primarySkill,
      petSecondarySkill: config.petSecondarySkill,
      statTierId: tier.id,
      attackDefenseSwapped: swapped,
      statPackage: statPackage,
      slotProfiles: List<BossSimulationScenarioSlotProfile>.unmodifiable(
        slotProfiles,
      ),
    );
  }

  String _buildScenarioId({
    required String modeKey,
    required int bossLevel,
    required List<WargearRole> layout,
    required List<double> knightAdvantage,
    required List<double> bossAdvantage,
    required String strategyId,
    required String primarySkill,
    required String tierId,
    required bool swapped,
  }) {
    final layoutToken = layout.map((value) => value.name[0]).join();
    final knightAdvToken = knightAdvantage.map(_multiplierToken).join('-');
    final bossAdvToken = bossAdvantage.map(_multiplierToken).join('-');
    final primarySkillToken = primarySkill
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('(', '')
        .replaceAll(')', '');
    final swappedToken = swapped ? 'swapped' : 'normal';
    return '$modeKey-l$bossLevel'
        '-layout_$layoutToken'
        '-kadv_$knightAdvToken'
        '-badv_$bossAdvToken'
        '-pet_$strategyId'
        '-skill_$primarySkillToken'
        '-tier_$tierId'
        '-$swappedToken';
  }

  String _multiplierToken(double value) {
    if ((value - 1.0).abs() < 1e-9) return '1';
    if ((value - 1.5).abs() < 1e-9) return '1_5';
    return '2';
  }
}

class BossSimulationResultCollector {
  BossSimulationResultCollector({
    required this.keepAggregates,
    required this.keepScores,
  });

  final bool keepAggregates;
  final bool keepScores;
  final List<BossSimulationAggregate> _aggregates = <BossSimulationAggregate>[];
  final List<BossSimulationScore> _scores = <BossSimulationScore>[];

  void addRun(BossSimulationRunResult result) {}

  void addAggregate(BossSimulationAggregate aggregate) {
    if (keepAggregates) {
      _aggregates.add(aggregate);
    }
  }

  void addScore(BossSimulationScore score) {
    if (keepScores) {
      _scores.add(score);
    }
  }

  List<BossSimulationAggregate> get aggregates =>
      List<BossSimulationAggregate>.unmodifiable(_aggregates);

  List<BossSimulationScore> get scores =>
      List<BossSimulationScore>.unmodifiable(_scores);
}

class BossSimulationAggregationLayer {
  const BossSimulationAggregationLayer();

  BossSimulationAggregate aggregateScenario(
    BossSimulationScenario scenario,
    List<BossSimulationRunResult> runs,
  ) {
    final damages =
        runs.map((value) => value.totalDamage).toList(growable: false);
    final completionCount =
        runs.where((value) => value.bossDefeated).length.toDouble();
    final survivalCount =
        runs.where((value) => value.survived).length.toDouble();
    final meanDamageByKnight = _meanList(
      runs.map((value) => value.damageByKnight).toList(growable: false),
    );
    final meanSpecialUsageByKnight = _meanList(
      runs
          .map((value) => value.specialUsageCountByKnight)
          .toList(growable: false),
    );
    return BossSimulationAggregate(
      scenarioId: scenario.scenarioId,
      modeKey: scenario.modeKey,
      bossLevel: scenario.bossLevel,
      petPrimarySkill: scenario.petPrimarySkill,
      statTierId: scenario.statTierId,
      attackDefenseSwapped: scenario.attackDefenseSwapped,
      runsCount: runs.length,
      meanTotalDamage: _meanInts(damages),
      medianTotalDamage: _quantileInts(damages, 0.50),
      minTotalDamage: damages.isEmpty ? 0 : damages.reduce(math.min),
      maxTotalDamage: damages.isEmpty ? 0 : damages.reduce(math.max),
      stdDevTotalDamage: _stdDevInts(damages),
      p10TotalDamage: _quantileInts(damages, 0.10),
      p25TotalDamage: _quantileInts(damages, 0.25),
      p75TotalDamage: _quantileInts(damages, 0.75),
      p90TotalDamage: _quantileInts(damages, 0.90),
      completionRate: runs.isEmpty ? 0.0 : completionCount / runs.length,
      survivalRate: runs.isEmpty ? 0.0 : survivalCount / runs.length,
      meanDamageByKnight: meanDamageByKnight,
      meanSpecialUsageByKnight: meanSpecialUsageByKnight,
      meanTurnsSurvived: _meanInts(
        runs.map((value) => value.turnsSurvived).toList(growable: false),
      ),
      meanPetCastCount: _meanInts(
        runs.map((value) => value.petCastCount).toList(growable: false),
      ),
      meanPetSpecial1Casts: _meanInts(
        runs.map((value) => value.petSpecial1Casts).toList(growable: false),
      ),
      meanPetSpecial2Casts: _meanInts(
        runs.map((value) => value.petSpecial2Casts).toList(growable: false),
      ),
      meanKnightSpecialActions: _meanInts(
        runs.map((value) => value.knightSpecialActions).toList(growable: false),
      ),
      meanBossTurns: _meanInts(
        runs
            .map((value) => value.rawEngineResult['bossTurns'] as int? ?? 0)
            .toList(growable: false),
      ),
      meanRunDurationSeconds: _meanDoubles(
        runs
            .map((value) => value.runDurationSeconds ?? 0.0)
            .toList(growable: false),
      ),
    );
  }

  List<double> _meanList(List<List<int>> samples) {
    if (samples.isEmpty) return const <double>[0.0, 0.0, 0.0];
    final maxLength = samples.fold<int>(
      0,
      (value, item) => item.length > value ? item.length : value,
    );
    final totals = List<double>.filled(maxLength, 0.0);
    for (final sample in samples) {
      for (var index = 0; index < sample.length; index++) {
        totals[index] += sample[index];
      }
    }
    return List<double>.unmodifiable(
      totals.map((value) => value / samples.length),
    );
  }

  double _meanInts(List<int> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((left, right) => left + right) / values.length;
  }

  double _meanDoubles(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((left, right) => left + right) / values.length;
  }

  double _stdDevInts(List<int> values) {
    if (values.length <= 1) return 0.0;
    final mean = _meanInts(values);
    final variance = values.fold<double>(
          0.0,
          (sum, value) => sum + math.pow(value - mean, 2),
        ) /
        values.length;
    return math.sqrt(variance);
  }

  double _quantileInts(List<int> values, double quantile) {
    if (values.isEmpty) return 0.0;
    final sorted = List<int>.from(values)..sort();
    if (sorted.length == 1) return sorted.first.toDouble();
    final clampedQ = quantile.clamp(0.0, 1.0);
    final position = (sorted.length - 1) * clampedQ;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower].toDouble();
    final fraction = position - lower;
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
  }
}

class BossSimulationArmorScoringEngine {
  const BossSimulationArmorScoringEngine();

  BossSimulationScore scoreScenario({
    required BossSimulationScenario scenario,
    required BossSimulationAggregate aggregate,
    required BossSimulationScoreProfile profile,
  }) {
    final consistencyFactor = aggregate.meanTotalDamage <= 0
        ? 0.0
        : 1.0 - (aggregate.stdDevTotalDamage / aggregate.meanTotalDamage);
    final efficiencyFactor = aggregate.meanTurnsSurvived <= 0
        ? 0.0
        : aggregate.meanTotalDamage / aggregate.meanTurnsSurvived;
    final specialEconomyFactor = aggregate.meanPetCastCount <= 0
        ? 0.0
        : aggregate.meanTotalDamage / aggregate.meanPetCastCount;
    final advantageFactor = _meanDoubleVector(scenario.knightAdvantageVector);
    final bossPenaltyFactor = _meanDoubleVector(scenario.bossAdvantageVector);
    final tempoFactor = aggregate.meanRunDurationSeconds <= 0
        ? 0.0
        : aggregate.meanTotalDamage / aggregate.meanRunDurationSeconds;

    final components = <String, double>{
      'damage': aggregate.meanTotalDamage * profile.damageWeight,
      'survivability':
          aggregate.survivalRate * 1000.0 * profile.survivabilityWeight,
      'consistencyPenalty': (1.0 - consistencyFactor.clamp(0.0, 1.0)) *
          aggregate.meanTotalDamage *
          profile.consistencyPenaltyWeight,
      'efficiency': efficiencyFactor * profile.efficiencyWeight,
      'specialEconomy': specialEconomyFactor * profile.specialEconomyWeight,
      'tempo': tempoFactor * profile.tempoWeight,
      'advantageFactor': advantageFactor * profile.advantageFactorWeight,
      'bossPenalty': bossPenaltyFactor * profile.bossPenaltyWeight,
    };

    final finalScore = components['damage']! +
        components['survivability']! +
        components['efficiency']! +
        components['specialEconomy']! +
        components['tempo']! +
        components['advantageFactor']! -
        components['consistencyPenalty']! -
        components['bossPenalty']!;

    return BossSimulationScore(
      scenarioId: scenario.scenarioId,
      profileId: profile.id,
      finalScore: finalScore,
      scoreComponents: Map<String, double>.unmodifiable(components),
    );
  }

  double _meanDoubleVector(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((left, right) => left + right) / values.length;
  }
}

class BossSimulationExportLayer {
  Future<BossSimulationExportSession> openSession({
    required Directory outputDir,
    required BossSimulationConfig config,
    required BossSimulationSummary summary,
    _BossSimulationResumeState? resumeState,
  }) async {
    if (!await outputDir.exists()) {
      await outputDir.create(recursive: true);
    }
    if (resumeState == null) {
      await File('${outputDir.path}/summary.json').writeAsString(
        jsonEncode(summary.toJson()),
        flush: true,
      );
      await File('${outputDir.path}/config.json').writeAsString(
        jsonEncode(config.toJson()),
        flush: true,
      );
    }

    final session = BossSimulationExportSession._(
      outputDir: outputDir,
      config: config,
      summary: summary,
      initialState: resumeState,
    );
    if (resumeState == null) {
      await session._openNextShard();
    } else {
      await session._resumeCurrentShard();
    }
    await session._writeManifest();
    return session;
  }

  String aggregateCsvRow(BossSimulationAggregate aggregate) => _csvRow(
        <Object?>[
          aggregate.scenarioId,
          aggregate.modeKey,
          aggregate.bossLevel,
          aggregate.petPrimarySkill,
          aggregate.statTierId,
          aggregate.attackDefenseSwapped,
          aggregate.runsCount,
          aggregate.meanTotalDamage,
          aggregate.medianTotalDamage,
          aggregate.minTotalDamage,
          aggregate.maxTotalDamage,
          aggregate.stdDevTotalDamage,
          aggregate.p10TotalDamage,
          aggregate.p25TotalDamage,
          aggregate.p75TotalDamage,
          aggregate.p90TotalDamage,
          aggregate.completionRate,
          aggregate.survivalRate,
          jsonEncode(aggregate.meanDamageByKnight),
          jsonEncode(aggregate.meanSpecialUsageByKnight),
          aggregate.meanTurnsSurvived,
          aggregate.meanPetCastCount,
          aggregate.meanRunDurationSeconds,
        ],
      );

  String scoreCsvRow(BossSimulationScore score) => _csvRow(
        <Object?>[
          score.scenarioId,
          score.profileId,
          score.finalScore,
          jsonEncode(score.scoreComponents),
        ],
      );

  String _csvRow(List<Object?> row) => row.map(_escapeCsv).join(',');

  String _escapeCsv(Object? value) {
    final text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      return '"${text.replaceAll('"', '""')}"';
    }
    return text;
  }
}

class BossSimulationExportSession {
  BossSimulationExportSession._({
    required this.outputDir,
    required this.config,
    required this.summary,
    required _BossSimulationResumeState? initialState,
  })  : _currentShardIndex = initialState?.currentShardIndex ?? 0,
        _rowsInCurrentShard = initialState?.rowsInCurrentShard ?? 0,
        _executedScenarios = initialState?.executedScenarios ?? 0,
        _executedRuns = initialState?.executedRuns ?? 0,
        _lastScenarioId = initialState?.lastScenarioId,
        _elapsedBeforeCurrentRun = initialState == null
            ? Duration.zero
            : Duration(milliseconds: initialState.elapsedMs);

  final Directory outputDir;
  final BossSimulationConfig config;
  final BossSimulationSummary summary;
  final BossSimulationExportLayer _layer = BossSimulationExportLayer();
  final Duration _elapsedBeforeCurrentRun;

  IOSink? _aggregateJsonSink;
  IOSink? _aggregateCsvSink;
  IOSink? _scoreJsonSink;
  IOSink? _scoreCsvSink;

  int _currentShardIndex = 0;
  int _rowsInCurrentShard = 0;
  int _executedScenarios = 0;
  int _executedRuns = 0;
  String? _lastScenarioId;

  Future<void> appendScenario({
    required BossSimulationScenario scenario,
    required List<BossSimulationRunResult> runs,
    required BossSimulationAggregate aggregate,
    required BossSimulationScore score,
    required int executedScenarios,
    required int executedRuns,
    required Duration elapsed,
  }) async {
    if (_rowsInCurrentShard >= config.exportShardSize) {
      await _rotateShard();
    }

    if (config.exportAggregates) {
      _aggregateJsonSink!.writeln(jsonEncode(aggregate.toJson()));
      _aggregateCsvSink!.writeln(_layer.aggregateCsvRow(aggregate));
    }
    if (config.exportScores) {
      _scoreJsonSink!.writeln(jsonEncode(score.toJson()));
      _scoreCsvSink!.writeln(_layer.scoreCsvRow(score));
    }
    _rowsInCurrentShard += 1;
    _executedScenarios = executedScenarios;
    _executedRuns = executedRuns;
    _lastScenarioId = scenario.scenarioId;

    if (config.checkpointEveryScenarios > 0 &&
        executedScenarios % config.checkpointEveryScenarios == 0) {
      await flush();
      await _writeManifest(elapsed: elapsed);
    }
  }

  Future<void> maybePause() async {
    if (config.pauseEveryScenarios <= 0 || config.pauseDurationMs <= 0) {
      return;
    }
    if (_executedScenarios <= 0) return;
    if (_executedScenarios % config.pauseEveryScenarios != 0) return;
    await flush();
    await Future<void>.delayed(Duration(milliseconds: config.pauseDurationMs));
  }

  Future<void> flush() async {
    await _aggregateJsonSink?.flush();
    await _aggregateCsvSink?.flush();
    await _scoreJsonSink?.flush();
    await _scoreCsvSink?.flush();
  }

  Future<void> close({Duration? elapsed}) async {
    await flush();
    await _writeManifest(elapsed: elapsed);
    await _aggregateJsonSink?.close();
    await _aggregateCsvSink?.close();
    await _scoreJsonSink?.close();
    await _scoreCsvSink?.close();
  }

  Future<void> _rotateShard() async {
    await _aggregateJsonSink?.close();
    await _aggregateCsvSink?.close();
    await _scoreJsonSink?.close();
    await _scoreCsvSink?.close();
    await _openNextShard();
  }

  Future<void> _resumeCurrentShard() async {
    if (_currentShardIndex <= 0) {
      await _openNextShard();
      return;
    }
    final shardToken = _currentShardIndex.toString().padLeft(4, '0');

    if (config.exportAggregates) {
      final aggregateJsonFile =
          File('${outputDir.path}/aggregates_$shardToken.ndjson');
      final aggregateCsvFile =
          File('${outputDir.path}/aggregates_$shardToken.csv');
      if (!aggregateJsonFile.existsSync() || !aggregateCsvFile.existsSync()) {
        throw StateError(
          'Missing aggregate shard files for resume: $shardToken.',
        );
      }
      _aggregateJsonSink = aggregateJsonFile.openWrite(mode: FileMode.append);
      _aggregateCsvSink = aggregateCsvFile.openWrite(mode: FileMode.append);
    }
    if (config.exportScores) {
      final scoreJsonFile = File('${outputDir.path}/scores_$shardToken.ndjson');
      final scoreCsvFile = File('${outputDir.path}/scores_$shardToken.csv');
      if (!scoreJsonFile.existsSync() || !scoreCsvFile.existsSync()) {
        throw StateError(
          'Missing score shard files for resume: $shardToken.',
        );
      }
      _scoreJsonSink = scoreJsonFile.openWrite(mode: FileMode.append);
      _scoreCsvSink = scoreCsvFile.openWrite(mode: FileMode.append);
    }
  }

  Future<void> _openNextShard() async {
    _currentShardIndex += 1;
    _rowsInCurrentShard = 0;
    final shardToken = _currentShardIndex.toString().padLeft(4, '0');

    if (config.exportAggregates) {
      _aggregateJsonSink =
          File('${outputDir.path}/aggregates_$shardToken.ndjson').openWrite();
      _aggregateCsvSink =
          File('${outputDir.path}/aggregates_$shardToken.csv').openWrite();
      _aggregateCsvSink!.writeln(
        'scenario_id,mode,boss_level,pet_primary_skill,stat_tier_id,atk_def_swapped,runs_count,mean_total_damage,median_total_damage,min_total_damage,max_total_damage,stddev_total_damage,p10_total_damage,p25_total_damage,p75_total_damage,p90_total_damage,completion_rate,survival_rate,mean_damage_by_knight,mean_special_usage_by_knight,mean_turns_survived,mean_pet_cast_count,mean_run_duration_seconds',
      );
    }
    if (config.exportScores) {
      _scoreJsonSink =
          File('${outputDir.path}/scores_$shardToken.ndjson').openWrite();
      _scoreCsvSink =
          File('${outputDir.path}/scores_$shardToken.csv').openWrite();
      _scoreCsvSink!.writeln(
        'scenario_id,profile_id,final_score,score_components',
      );
    }
  }

  Future<void> _writeManifest({Duration? elapsed}) async {
    final totalElapsed = elapsed ?? _elapsedBeforeCurrentRun;
    final manifest = <String, Object?>{
      'totalScenarios': summary.totalScenarios,
      'totalRunsExpected': summary.totalRunsExpected,
      'executedScenarios': _executedScenarios,
      'executedRuns': _executedRuns,
      'currentShardIndex': _currentShardIndex,
      'rowsInCurrentShard': _rowsInCurrentShard,
      'lastScenarioId': _lastScenarioId,
      'elapsedMs': totalElapsed.inMilliseconds,
      'exportAggregates': config.exportAggregates,
      'exportScores': config.exportScores,
      'exportShardSize': config.exportShardSize,
      'checkpointEveryScenarios': config.checkpointEveryScenarios,
      'updatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    };
    await File('${outputDir.path}/manifest.json').writeAsString(
      jsonEncode(manifest),
      flush: true,
    );
  }
}

class _BossSimulationResumeState {
  final int executedScenarios;
  final int executedRuns;
  final int currentShardIndex;
  final int rowsInCurrentShard;
  final String? lastScenarioId;
  final int elapsedMs;

  const _BossSimulationResumeState({
    required this.executedScenarios,
    required this.executedRuns,
    required this.currentShardIndex,
    required this.rowsInCurrentShard,
    required this.lastScenarioId,
    required this.elapsedMs,
  });

  static Future<_BossSimulationResumeState?> tryLoad({
    required Directory outputDir,
    required BossSimulationSummary summary,
    required BossSimulationConfig config,
  }) async {
    final manifestFile = File('${outputDir.path}/manifest.json');
    if (!await manifestFile.exists()) {
      return null;
    }
    final raw = jsonDecode(await manifestFile.readAsString());
    if (raw is! Map<String, dynamic>) {
      throw StateError('Invalid simulation manifest format.');
    }
    final totalScenarios = raw['totalScenarios'] as int? ?? 0;
    final totalRunsExpected = raw['totalRunsExpected'] as int? ?? 0;
    if (totalScenarios != summary.totalScenarios ||
        totalRunsExpected != summary.totalRunsExpected) {
      throw StateError(
        'Simulation manifest does not match the current scenario space.',
      );
    }
    if ((raw['exportAggregates'] as bool? ?? true) != config.exportAggregates ||
        (raw['exportScores'] as bool? ?? true) != config.exportScores ||
        (raw['exportShardSize'] as int? ?? 0) != config.exportShardSize) {
      throw StateError(
        'Simulation manifest export settings do not match the current config.',
      );
    }
    return _BossSimulationResumeState(
      executedScenarios: raw['executedScenarios'] as int? ?? 0,
      executedRuns: raw['executedRuns'] as int? ?? 0,
      currentShardIndex: raw['currentShardIndex'] as int? ?? 0,
      rowsInCurrentShard: raw['rowsInCurrentShard'] as int? ?? 0,
      lastScenarioId: raw['lastScenarioId'] as String?,
      elapsedMs: raw['elapsedMs'] as int? ?? 0,
    );
  }
}

class BossSimulationRunner {
  BossSimulationRunner({
    DamageModel? damageModel,
    RaidBlitzBattleEngine? engine,
    BossSimulationAggregationLayer? aggregationLayer,
    BossSimulationArmorScoringEngine? scoringEngine,
  })  : _damageModel = damageModel ?? DamageModel(),
        _engine = engine ?? const RaidBlitzBattleEngine(),
        _aggregationLayer =
            aggregationLayer ?? const BossSimulationAggregationLayer(),
        _scoringEngine =
            scoringEngine ?? const BossSimulationArmorScoringEngine();

  final DamageModel _damageModel;
  final RaidBlitzBattleEngine _engine;
  final BossSimulationAggregationLayer _aggregationLayer;
  final BossSimulationArmorScoringEngine _scoringEngine;

  final Map<String, BossConfig> _bossCache = <String, BossConfig>{};

  Future<BossSimulationBatchResult> run({
    required BossSimulationConfig config,
    required Directory outputDir,
    bool dryRun = false,
    bool resume = false,
    int progressEveryScenarios = 100,
    void Function(BossSimulationProgress progress)? onProgress,
  }) async {
    final wardrobeCatalog = await WargearWardrobeLoader.load();
    final generator = BossSimulationScenarioGenerator(
      config: config,
      catalog: wardrobeCatalog,
    );
    final summary = generator.summarize();
    if (dryRun) {
      return BossSimulationBatchResult(
        summary: summary,
        executedScenarioCount: 0,
        executedRunCount: 0,
        aggregates: const <BossSimulationAggregate>[],
        scores: const <BossSimulationScore>[],
      );
    }

    final resumeState = resume
        ? await _BossSimulationResumeState.tryLoad(
            outputDir: outputDir,
            summary: summary,
            config: config,
          )
        : null;

    final petPresetCatalog = await _buildPetPresetCatalog(
      requiredPrimarySkills: config.petPrimarySkills,
      requiredSecondarySkill: config.petSecondarySkill,
    );
    final exportSession = await BossSimulationExportLayer().openSession(
      outputDir: outputDir,
      config: config,
      summary: summary,
      resumeState: resumeState,
    );
    final random = math.Random();
    final stopwatch = Stopwatch()..start();
    final elapsedBeforeCurrentRun = resumeState == null
        ? Duration.zero
        : Duration(milliseconds: resumeState.elapsedMs);
    final collector = BossSimulationResultCollector(
      keepAggregates: config.retainAggregatesInMemory,
      keepScores: config.retainScoresInMemory,
    );
    var executedScenarios = resumeState?.executedScenarios ?? 0;
    var executedRuns = resumeState?.executedRuns ?? 0;
    final scenarioStream = resumeState == null
        ? generator.generate()
        : generator.generate().skip(resumeState.executedScenarios);

    for (final scenario in scenarioStream) {
      if (config.maxScenarios != null &&
          executedScenarios >= config.maxScenarios!) {
        break;
      }

      final loadout = _buildPetLoadout(
        config: config,
        petPresetCatalog: petPresetCatalog,
        primarySkill: scenario.petPrimarySkill,
        secondarySkill: scenario.petSecondarySkill,
      );
      final boss = await _resolveBossConfig(
        raidMode: scenario.raidMode,
        bossLevel: scenario.bossLevel,
        bossAdvantage: scenario.bossAdvantageVector,
        fightModeKey: scenario.fightModeKey,
      );

      final scenarioRuns = <BossSimulationRunResult>[];
      final strategy = config.petUsageStrategies.firstWhere(
        (value) => value.id == scenario.petStrategyId,
      );

      for (var runIndex = 0; runIndex < config.runsPerScenario; runIndex++) {
        final randomAttackDelta = _nextInclusiveInt(
          random,
          config.randomization.attackDeltaMin,
          config.randomization.attackDeltaMax,
        );
        final randomDefenseDelta = _nextInclusiveInt(
          random,
          config.randomization.defenseDeltaMin,
          config.randomization.defenseDeltaMax,
        );
        final randomHealthDelta = _nextInclusiveInt(
          random,
          config.randomization.healthDeltaMin,
          config.randomization.healthDeltaMax,
        );

        final kAtk = <double>[];
        final kDef = <double>[];
        final kHp = <int>[];
        final slotProfileJson = <Map<String, Object?>>[];
        for (final slot in scenario.slotProfiles) {
          final effective = WargearStats(
            attack: slot.effectiveStatsBeforeRandomization.attack +
                randomAttackDelta,
            defense: slot.effectiveStatsBeforeRandomization.defense +
                randomDefenseDelta,
            health: slot.effectiveStatsBeforeRandomization.health +
                randomHealthDelta,
          );
          kAtk.add(effective.attack.toDouble());
          kDef.add(effective.defense.toDouble());
          kHp.add(effective.health);
          slotProfileJson.add(<String, Object?>{
            ...slot.toJson(),
            'effectiveStatsWithRandomization': effective.toJson(),
          });
        }

        final pre = _damageModel.precompute(
          boss: boss,
          kAtk: kAtk,
          kDef: kDef,
          kHp: kHp,
          kAdv: scenario.knightAdvantageVector,
          kStun: config.knightStunChances,
          petAtk: loadout.petAttack,
          petAdv: config.petAdvantageMultiplier,
          petSkillUsage: strategy.usageMode,
          petEffects: loadout.effects,
        );

        final engineSeed = BattleEngineSeed(
          pre: pre,
          runtimeKnobs: BattleRuntimeKnobs(
            knightPetElementMatches: config.petMatchByKnightSlot,
            petStrongVsBossByKnight: config.petStrongVsBossByKnightSlot,
          ),
        );
        final rngSeed = random.nextInt(0x7fffffff);
        final debugCapture = BossSimulationDebugCapture();
        final timing = config.captureTiming ? TimingAcc() : null;
        final engineResult = _engine.runWithRng(
          engineSeed,
          FastRng(rngSeed),
          withTiming: config.captureTiming,
          timing: timing,
          debug: debugCapture,
        );

        final runResult = BossSimulationRunResult(
          scenarioId: scenario.scenarioId,
          runIndex: runIndex,
          rngSeed: rngSeed,
          modeKey: scenario.modeKey,
          bossLevel: scenario.bossLevel,
          layout: scenario.layout
              .map((value) => value.name)
              .toList(growable: false),
          knightAdvantageVector: scenario.knightAdvantageVector,
          bossAdvantageVector: scenario.bossAdvantageVector,
          petStrategyId: scenario.petStrategyId,
          petPrimarySkill: scenario.petPrimarySkill,
          petSecondarySkill: scenario.petSecondarySkill,
          statTierId: scenario.statTierId,
          attackDefenseSwapped: scenario.attackDefenseSwapped,
          randomAttackDelta: randomAttackDelta,
          randomDefenseDelta: randomDefenseDelta,
          randomHealthDelta: randomHealthDelta,
          slotProfiles: slotProfileJson,
          totalDamage: engineResult.points,
          damageByKnight: List<int>.unmodifiable(debugCapture.damageByKnight),
          outcome: engineResult.bossDefeated
              ? 'boss_defeated'
              : (engineResult.knightsDefeated ? 'knights_defeated' : 'ended'),
          survived: !engineResult.knightsDefeated,
          bossDefeated: engineResult.bossDefeated,
          knightsDefeated: engineResult.knightsDefeated,
          turnsSurvived: engineResult.knightTurns,
          totalSpecialsUsed: engineResult.knightSpecialActions,
          specialUsageCountByKnight:
              List<int>.unmodifiable(debugCapture.specialUsageCountByKnight),
          petCastCount: engineResult.petCastCount,
          petSpecial1Casts: engineResult.petSpecial1Casts,
          petSpecial2Casts: engineResult.petSpecial2Casts,
          petCastSequence: engineResult.petCastSequence
              .map((value) => value.name)
              .toList(growable: false),
          knightNormalActions: engineResult.knightNormalActions,
          knightCritActions: engineResult.knightCritActions,
          knightSpecialActions: engineResult.knightSpecialActions,
          knightMissActions: engineResult.knightMissActions,
          bossNormalActions: engineResult.bossNormalActions,
          bossCritActions: engineResult.bossCritActions,
          bossSpecialActions: engineResult.bossSpecialActions,
          bossMissActions: engineResult.bossMissActions,
          bossStunSkips: engineResult.bossStunSkips,
          finalKnightIndex: engineResult.finalKnightIndex < 0
              ? null
              : engineResult.finalKnightIndex,
          finalKnightHp: engineResult.finalKnightHp,
          runDurationSeconds: engineResult.timing?.meanRunSeconds,
          bossDurationSeconds: engineResult.timing?.meanBossSeconds,
          healingRecovered: null,
          rawEngineResult: <String, Object?>{
            'points': engineResult.points,
            'bossHpRemaining': engineResult.bossHpRemaining,
            'bossDefeated': engineResult.bossDefeated,
            'knightsDefeated': engineResult.knightsDefeated,
            'knightTurns': engineResult.knightTurns,
            'bossTurns': engineResult.bossTurns,
            'finalKnightIndex': engineResult.finalKnightIndex,
            'finalKnightHp': engineResult.finalKnightHp,
            'petBasicAttacks': engineResult.petBasicAttacks,
            'petCastCount': engineResult.petCastCount,
            'petSpecial1Casts': engineResult.petSpecial1Casts,
            'petSpecial2Casts': engineResult.petSpecial2Casts,
            'petCastSequence': engineResult.petCastSequence
                .map((value) => value.name)
                .toList(growable: false),
            'knightNormalActions': engineResult.knightNormalActions,
            'knightCritActions': engineResult.knightCritActions,
            'knightSpecialActions': engineResult.knightSpecialActions,
            'knightMissActions': engineResult.knightMissActions,
            'bossNormalActions': engineResult.bossNormalActions,
            'bossCritActions': engineResult.bossCritActions,
            'bossSpecialActions': engineResult.bossSpecialActions,
            'bossMissActions': engineResult.bossMissActions,
            'bossStunSkips': engineResult.bossStunSkips,
            'cycloneAlwaysGemApplied': engineResult.cycloneAlwaysGemApplied,
            'goldDropEnabled': engineResult.goldDropEnabled,
            'goldDropped': engineResult.goldDropped,
            'timing': engineResult.timing?.toJson(),
          },
        );

        collector.addRun(runResult);
        scenarioRuns.add(runResult);
        executedRuns += 1;
      }

      final aggregate =
          _aggregationLayer.aggregateScenario(scenario, scenarioRuns);
      collector.addAggregate(aggregate);
      final score = _scoringEngine.scoreScenario(
        scenario: scenario,
        aggregate: aggregate,
        profile: scenario.raidMode
            ? config.raidScoreProfile
            : config.blitzScoreProfile,
      );
      collector.addScore(score);
      executedScenarios += 1;
      await exportSession.appendScenario(
        scenario: scenario,
        runs: scenarioRuns,
        aggregate: aggregate,
        score: score,
        executedScenarios: executedScenarios,
        executedRuns: executedRuns,
        elapsed: elapsedBeforeCurrentRun + stopwatch.elapsed,
      );
      if (onProgress != null &&
          progressEveryScenarios > 0 &&
          (executedScenarios % progressEveryScenarios == 0 ||
              executedScenarios == summary.totalScenarios ||
              (config.maxScenarios != null &&
                  executedScenarios == config.maxScenarios))) {
        onProgress(
          BossSimulationProgress(
            completedScenarios: executedScenarios,
            totalScenarios: summary.totalScenarios,
            completedRuns: executedRuns,
            totalRunsExpected: summary.totalRunsExpected,
            currentScenarioId: scenario.scenarioId,
            elapsed: elapsedBeforeCurrentRun + stopwatch.elapsed,
            currentShardIndex: exportSession._currentShardIndex,
          ),
        );
      }
      await exportSession.maybePause();
    }

    await exportSession.close(
        elapsed: elapsedBeforeCurrentRun + stopwatch.elapsed);
    stopwatch.stop();

    final result = BossSimulationBatchResult(
      summary: summary,
      executedScenarioCount: executedScenarios,
      executedRunCount: executedRuns,
      aggregates: collector.aggregates,
      scores: collector.scores,
    );
    return result;
  }

  Future<BossSimulationBatchResult> runSelectedScenarios({
    required BossSimulationConfig config,
    required List<BossSimulationScenario> scenarios,
    int progressEveryScenarios = 100,
    void Function(BossSimulationProgress progress)? onProgress,
  }) async {
    final summary = _summaryForSelectedScenarios(
      scenarios: scenarios,
      runsPerScenario: config.runsPerScenario,
    );
    if (scenarios.isEmpty) {
      return BossSimulationBatchResult(
        summary: summary,
        executedScenarioCount: 0,
        executedRunCount: 0,
        aggregates: const <BossSimulationAggregate>[],
        scores: const <BossSimulationScore>[],
      );
    }

    final petPresetCatalog = await _buildPetPresetCatalog(
      requiredPrimarySkills: config.petPrimarySkills,
      requiredSecondarySkill: config.petSecondarySkill,
    );
    final random = math.Random();
    final stopwatch = Stopwatch()..start();
    final collector = BossSimulationResultCollector(
      keepAggregates: true,
      keepScores: true,
    );
    var executedScenarios = 0;
    var executedRuns = 0;

    for (final scenario in scenarios) {
      final loadout = _buildPetLoadout(
        config: config,
        petPresetCatalog: petPresetCatalog,
        primarySkill: scenario.petPrimarySkill,
        secondarySkill: scenario.petSecondarySkill,
      );
      final boss = await _resolveBossConfig(
        raidMode: scenario.raidMode,
        bossLevel: scenario.bossLevel,
        bossAdvantage: scenario.bossAdvantageVector,
        fightModeKey: scenario.fightModeKey,
      );

      final scenarioRuns = <BossSimulationRunResult>[];
      final strategy = config.petUsageStrategies.firstWhere(
        (value) => value.id == scenario.petStrategyId,
      );

      for (var runIndex = 0; runIndex < config.runsPerScenario; runIndex++) {
        final randomAttackDelta = _nextInclusiveInt(
          random,
          config.randomization.attackDeltaMin,
          config.randomization.attackDeltaMax,
        );
        final randomDefenseDelta = _nextInclusiveInt(
          random,
          config.randomization.defenseDeltaMin,
          config.randomization.defenseDeltaMax,
        );
        final randomHealthDelta = _nextInclusiveInt(
          random,
          config.randomization.healthDeltaMin,
          config.randomization.healthDeltaMax,
        );

        final kAtk = <double>[];
        final kDef = <double>[];
        final kHp = <int>[];
        final slotProfileJson = <Map<String, Object?>>[];
        for (final slot in scenario.slotProfiles) {
          final effective = WargearStats(
            attack: slot.effectiveStatsBeforeRandomization.attack +
                randomAttackDelta,
            defense: slot.effectiveStatsBeforeRandomization.defense +
                randomDefenseDelta,
            health: slot.effectiveStatsBeforeRandomization.health +
                randomHealthDelta,
          );
          kAtk.add(effective.attack.toDouble());
          kDef.add(effective.defense.toDouble());
          kHp.add(effective.health);
          slotProfileJson.add(<String, Object?>{
            ...slot.toJson(),
            'effectiveStatsWithRandomization': effective.toJson(),
          });
        }

        final pre = _damageModel.precompute(
          boss: boss,
          kAtk: kAtk,
          kDef: kDef,
          kHp: kHp,
          kAdv: scenario.knightAdvantageVector,
          kStun: config.knightStunChances,
          petAtk: loadout.petAttack,
          petAdv: config.petAdvantageMultiplier,
          petSkillUsage: strategy.usageMode,
          petEffects: loadout.effects,
        );

        final engineSeed = BattleEngineSeed(
          pre: pre,
          runtimeKnobs: BattleRuntimeKnobs(
            knightPetElementMatches: config.petMatchByKnightSlot,
            petStrongVsBossByKnight: config.petStrongVsBossByKnightSlot,
          ),
        );
        final rngSeed = random.nextInt(0x7fffffff);
        final debugCapture = BossSimulationDebugCapture();
        final timing = config.captureTiming ? TimingAcc() : null;
        final engineResult = _engine.runWithRng(
          engineSeed,
          FastRng(rngSeed),
          withTiming: config.captureTiming,
          timing: timing,
          debug: debugCapture,
        );

        final runResult = BossSimulationRunResult(
          scenarioId: scenario.scenarioId,
          runIndex: runIndex,
          rngSeed: rngSeed,
          modeKey: scenario.modeKey,
          bossLevel: scenario.bossLevel,
          layout: scenario.layout
              .map((value) => value.name)
              .toList(growable: false),
          knightAdvantageVector: scenario.knightAdvantageVector,
          bossAdvantageVector: scenario.bossAdvantageVector,
          petStrategyId: scenario.petStrategyId,
          petPrimarySkill: scenario.petPrimarySkill,
          petSecondarySkill: scenario.petSecondarySkill,
          statTierId: scenario.statTierId,
          attackDefenseSwapped: scenario.attackDefenseSwapped,
          randomAttackDelta: randomAttackDelta,
          randomDefenseDelta: randomDefenseDelta,
          randomHealthDelta: randomHealthDelta,
          slotProfiles: slotProfileJson,
          totalDamage: engineResult.points,
          damageByKnight: List<int>.unmodifiable(debugCapture.damageByKnight),
          outcome: engineResult.bossDefeated
              ? 'boss_defeated'
              : (engineResult.knightsDefeated ? 'knights_defeated' : 'ended'),
          survived: !engineResult.knightsDefeated,
          bossDefeated: engineResult.bossDefeated,
          knightsDefeated: engineResult.knightsDefeated,
          turnsSurvived: engineResult.knightTurns,
          totalSpecialsUsed: engineResult.knightSpecialActions,
          specialUsageCountByKnight:
              List<int>.unmodifiable(debugCapture.specialUsageCountByKnight),
          petCastCount: engineResult.petCastCount,
          petSpecial1Casts: engineResult.petSpecial1Casts,
          petSpecial2Casts: engineResult.petSpecial2Casts,
          petCastSequence: engineResult.petCastSequence
              .map((value) => value.name)
              .toList(growable: false),
          knightNormalActions: engineResult.knightNormalActions,
          knightCritActions: engineResult.knightCritActions,
          knightSpecialActions: engineResult.knightSpecialActions,
          knightMissActions: engineResult.knightMissActions,
          bossNormalActions: engineResult.bossNormalActions,
          bossCritActions: engineResult.bossCritActions,
          bossSpecialActions: engineResult.bossSpecialActions,
          bossMissActions: engineResult.bossMissActions,
          bossStunSkips: engineResult.bossStunSkips,
          finalKnightIndex: engineResult.finalKnightIndex < 0
              ? null
              : engineResult.finalKnightIndex,
          finalKnightHp: engineResult.finalKnightHp,
          runDurationSeconds: engineResult.timing?.meanRunSeconds,
          bossDurationSeconds: engineResult.timing?.meanBossSeconds,
          healingRecovered: null,
          rawEngineResult: <String, Object?>{
            'points': engineResult.points,
            'bossHpRemaining': engineResult.bossHpRemaining,
            'bossDefeated': engineResult.bossDefeated,
            'knightsDefeated': engineResult.knightsDefeated,
            'knightTurns': engineResult.knightTurns,
            'bossTurns': engineResult.bossTurns,
            'finalKnightIndex': engineResult.finalKnightIndex,
            'finalKnightHp': engineResult.finalKnightHp,
            'petBasicAttacks': engineResult.petBasicAttacks,
            'petCastCount': engineResult.petCastCount,
            'petSpecial1Casts': engineResult.petSpecial1Casts,
            'petSpecial2Casts': engineResult.petSpecial2Casts,
            'petCastSequence': engineResult.petCastSequence
                .map((value) => value.name)
                .toList(growable: false),
            'knightNormalActions': engineResult.knightNormalActions,
            'knightCritActions': engineResult.knightCritActions,
            'knightSpecialActions': engineResult.knightSpecialActions,
            'knightMissActions': engineResult.knightMissActions,
            'bossNormalActions': engineResult.bossNormalActions,
            'bossCritActions': engineResult.bossCritActions,
            'bossSpecialActions': engineResult.bossSpecialActions,
            'bossMissActions': engineResult.bossMissActions,
            'bossStunSkips': engineResult.bossStunSkips,
            'cycloneAlwaysGemApplied': engineResult.cycloneAlwaysGemApplied,
            'goldDropEnabled': engineResult.goldDropEnabled,
            'goldDropped': engineResult.goldDropped,
            'timing': engineResult.timing?.toJson(),
          },
        );

        collector.addRun(runResult);
        scenarioRuns.add(runResult);
        executedRuns += 1;
      }

      final aggregate =
          _aggregationLayer.aggregateScenario(scenario, scenarioRuns);
      collector.addAggregate(aggregate);
      final score = _scoringEngine.scoreScenario(
        scenario: scenario,
        aggregate: aggregate,
        profile: scenario.raidMode
            ? config.raidScoreProfile
            : config.blitzScoreProfile,
      );
      collector.addScore(score);
      executedScenarios += 1;

      if (onProgress != null &&
          progressEveryScenarios > 0 &&
          (executedScenarios % progressEveryScenarios == 0 ||
              executedScenarios == scenarios.length)) {
        onProgress(
          BossSimulationProgress(
            completedScenarios: executedScenarios,
            totalScenarios: scenarios.length,
            completedRuns: executedRuns,
            totalRunsExpected: scenarios.length * config.runsPerScenario,
            currentScenarioId: scenario.scenarioId,
            elapsed: stopwatch.elapsed,
            currentShardIndex: 0,
          ),
        );
      }
    }

    stopwatch.stop();
    return BossSimulationBatchResult(
      summary: summary,
      executedScenarioCount: executedScenarios,
      executedRunCount: executedRuns,
      aggregates: collector.aggregates,
      scores: collector.scores,
    );
  }

  BossSimulationSummary _summaryForSelectedScenarios({
    required List<BossSimulationScenario> scenarios,
    required int runsPerScenario,
  }) {
    final byMode = <String, int>{};
    final byBossLevel = <String, int>{};
    final byStatTier = <String, int>{};
    final byPrimarySkill = <String, int>{};
    for (final scenario in scenarios) {
      byMode.update(scenario.modeKey, (value) => value + 1, ifAbsent: () => 1);
      final bossLevelKey = '${scenario.modeKey}_L${scenario.bossLevel}';
      byBossLevel.update(
        bossLevelKey,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      byStatTier.update(
        scenario.statTierId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
      byPrimarySkill.update(
        scenario.petPrimarySkill,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return BossSimulationSummary(
      totalScenarios: scenarios.length,
      totalRunsExpected: scenarios.length * runsPerScenario,
      scenariosByMode: Map<String, int>.unmodifiable(byMode),
      scenariosByBossLevel: Map<String, int>.unmodifiable(byBossLevel),
      scenariosByStatTier: Map<String, int>.unmodifiable(byStatTier),
      scenariosByPetPrimarySkill: Map<String, int>.unmodifiable(byPrimarySkill),
      sampleScenario: scenarios.isEmpty
          ? const <String, Object?>{}
          : scenarios.first.toJson(),
    );
  }

  Future<Map<String, BossSimulationPetSkillPreset>> _buildPetPresetCatalog({
    required List<String> requiredPrimarySkills,
    required String requiredSecondarySkill,
  }) async {
    final semantics = await PetSkillSemanticsLoader.load();
    final primalCatalog = await PetCompendiumLoader.load(rarity: 'Primal');
    final fullCatalog = await PetCompendiumLoader.load();
    final requiredSkills = <String>{
      ...requiredPrimarySkills,
      requiredSecondarySkill,
    };

    final candidatesBySkill = <String, List<_PetPresetCandidate>>{
      for (final skill in requiredSkills) skill: <_PetPresetCandidate>[],
    };

    void collectFromCatalog(PetCompendiumCatalog catalog) {
      for (final pet in catalog.pets) {
        for (final tier in pet.tiers) {
          for (final profile in tier.profiles) {
            for (final entry in profile.skills.entries) {
              final skill = entry.value;
              final matchedRequiredSkill =
                  requiredSkills.cast<String?>().firstWhere(
                        (requiredSkill) => _matchesRequestedPetSkill(
                          requiredSkill!,
                          skill.name,
                        ),
                        orElse: () => null,
                      );
              if (matchedRequiredSkill == null) continue;
              final semanticsEntry = semantics[skill.name];
              if (semanticsEntry == null) continue;
              candidatesBySkill[matchedRequiredSkill]!.add(
                _PetPresetCandidate(
                  sourcePetId: pet.id,
                  sourcePetName: tier.name,
                  sourceTierId: tier.id,
                  sourceProfileId: profile.id,
                  sourceProfileLevel: profile.level,
                  petAttack: profile.petAttack,
                  hasMaxProfile: profile.id == 'max' ||
                      profile.label.toLowerCase().contains('max'),
                  tierRank: PetCompendiumTierVariant.tierRank(tier.tier),
                  effect: PetResolvedEffect(
                    sourceSlotId: skill.slotId,
                    sourceSkillName: skill.name,
                    values: skill.values,
                    canonicalEffectId: semanticsEntry.canonicalEffectId,
                    canonicalName: semanticsEntry.canonicalName,
                    effectCategory: semanticsEntry.effectCategory,
                    dataSupport: semanticsEntry.dataSupport,
                    runtimeSupport: semanticsEntry.runtimeSupport,
                    simulatorModes: semanticsEntry.simulatorModes,
                    effectSpec: semanticsEntry.effectSpec,
                  ),
                ),
              );
            }
          }
        }
      }
    }

    collectFromCatalog(primalCatalog);
    for (final skillName in requiredSkills) {
      if (candidatesBySkill[skillName]!.isEmpty) {
        collectFromCatalog(fullCatalog);
        break;
      }
    }

    final out = <String, BossSimulationPetSkillPreset>{};
    for (final skillName in requiredSkills) {
      final candidates =
          candidatesBySkill[skillName] ?? const <_PetPresetCandidate>[];
      if (candidates.isEmpty) {
        throw StateError('Missing Primal pet preset for $skillName.');
      }
      candidates.sort();
      final selected = candidates.last;
      out[skillName] = BossSimulationPetSkillPreset(
        skillName: skillName,
        sourcePetId: selected.sourcePetId,
        sourcePetName: selected.sourcePetName,
        sourceTierId: selected.sourceTierId,
        sourceProfileId: selected.sourceProfileId,
        sourceProfileLevel: selected.sourceProfileLevel,
        petAttack: selected.petAttack,
        effect: selected.effect,
      );
    }
    return Map<String, BossSimulationPetSkillPreset>.unmodifiable(out);
  }

  bool _matchesRequestedPetSkill(String requiredSkill, String actualSkill) {
    if (requiredSkill == actualSkill) return true;
    final required = requiredSkill.trim().toLowerCase();
    final actual = actualSkill.trim().toLowerCase();
    if (required == 'cyclone boost') {
      return actual.contains('cyclone') && actual.contains('boost');
    }
    return false;
  }

  BossSimulationPetLoadout _buildPetLoadout({
    required BossSimulationConfig config,
    required Map<String, BossSimulationPetSkillPreset> petPresetCatalog,
    required String primarySkill,
    required String secondarySkill,
  }) {
    final primaryPreset = petPresetCatalog[primarySkill];
    final secondaryPreset = petPresetCatalog[secondarySkill];
    if (primaryPreset == null || secondaryPreset == null) {
      throw StateError(
        'Unable to resolve pet loadout presets for $primarySkill + $secondarySkill.',
      );
    }
    final petAttack = switch (config.petAttackResolutionPolicy) {
      BossSimulationPetAttackResolutionPolicy.maxSelectedPresetAttack =>
        math.max(primaryPreset.petAttack, secondaryPreset.petAttack).toDouble(),
      BossSimulationPetAttackResolutionPolicy.primaryPresetAttack =>
        primaryPreset.petAttack.toDouble(),
    };
    return BossSimulationPetLoadout(
      primaryPreset: primaryPreset,
      secondaryPreset: secondaryPreset,
      petAttack: petAttack,
      effects: <PetResolvedEffect>[
        primaryPreset.effect,
        secondaryPreset.effect,
      ],
    );
  }

  Future<BossConfig> _resolveBossConfig({
    required bool raidMode,
    required int bossLevel,
    required List<double> bossAdvantage,
    required String fightModeKey,
  }) async {
    final cacheKey =
        '${raidMode ? 'raid' : 'blitz'}:$bossLevel:${bossAdvantage.join('/')}:$fightModeKey';
    final cached = _bossCache[cacheKey];
    if (cached != null) return cached;
    final boss = await ConfigLoader.loadBoss(
      raidMode: raidMode,
      bossLevel: bossLevel,
      adv: bossAdvantage,
      fightModeKey: fightModeKey,
    );
    _bossCache[cacheKey] = boss;
    return boss;
  }

  int _nextInclusiveInt(math.Random random, int min, int max) {
    if (max <= min) return min;
    return min + random.nextInt(max - min + 1);
  }
}

class _PetPresetCandidate implements Comparable<_PetPresetCandidate> {
  final String sourcePetId;
  final String sourcePetName;
  final String sourceTierId;
  final String sourceProfileId;
  final int sourceProfileLevel;
  final int petAttack;
  final bool hasMaxProfile;
  final int tierRank;
  final PetResolvedEffect effect;

  const _PetPresetCandidate({
    required this.sourcePetId,
    required this.sourcePetName,
    required this.sourceTierId,
    required this.sourceProfileId,
    required this.sourceProfileLevel,
    required this.petAttack,
    required this.hasMaxProfile,
    required this.tierRank,
    required this.effect,
  });

  double get potencyScore => effect.values.values.fold<double>(
        0.0,
        (sum, value) => sum + value.toDouble().abs(),
      );

  @override
  int compareTo(_PetPresetCandidate other) {
    final maxCompare =
        hasMaxProfile == other.hasMaxProfile ? 0 : (hasMaxProfile ? 1 : -1);
    if (maxCompare != 0) return maxCompare;
    final levelCompare = sourceProfileLevel.compareTo(other.sourceProfileLevel);
    if (levelCompare != 0) return levelCompare;
    final potencyCompare = potencyScore.compareTo(other.potencyScore);
    if (potencyCompare != 0) return potencyCompare;
    final tierCompare = tierRank.compareTo(other.tierRank);
    if (tierCompare != 0) return tierCompare;
    return petAttack.compareTo(other.petAttack);
  }
}
