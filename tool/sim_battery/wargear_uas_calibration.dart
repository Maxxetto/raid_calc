import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/wargear_universal_scoring.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

import 'boss_sim_battery_config.dart';

class WargearUasCalibrationCorrelation {
  final String modeLevel;
  final int scenarioCount;
  final double uasVsMeanDamage;
  final double uasVsBatteryScore;

  const WargearUasCalibrationCorrelation({
    required this.modeLevel,
    required this.scenarioCount,
    required this.uasVsMeanDamage,
    required this.uasVsBatteryScore,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'modeLevel': modeLevel,
        'scenarioCount': scenarioCount,
        'uasVsMeanDamage': uasVsMeanDamage,
        'uasVsBatteryScore': uasVsBatteryScore,
      };
}

class WargearUasStatsWeightProposal {
  final String modeLevel;
  final int scenarioCount;
  final double attackScorePer1000;
  final double defenseScorePer1000;
  final double healthScorePer1000;
  final double defenseWeightRelative;
  final double healthWeightRelative;

  const WargearUasStatsWeightProposal({
    required this.modeLevel,
    required this.scenarioCount,
    required this.attackScorePer1000,
    required this.defenseScorePer1000,
    required this.healthScorePer1000,
    required this.defenseWeightRelative,
    required this.healthWeightRelative,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'modeLevel': modeLevel,
        'scenarioCount': scenarioCount,
        'attackScorePer1000': attackScorePer1000,
        'defenseScorePer1000': defenseScorePer1000,
        'healthScorePer1000': healthScorePer1000,
        'defenseWeightRelative': defenseWeightRelative,
        'healthWeightRelative': healthWeightRelative,
      };
}

class WargearUasCalibrationSummary {
  final Directory outputDir;
  final int scenarioCount;
  final List<String> sourceFiles;
  final List<WargearUasCalibrationCorrelation> correlations;
  final List<WargearUasStatsWeightProposal> statsWeightProposals;
  final List<String> generatedFiles;

  const WargearUasCalibrationSummary({
    required this.outputDir,
    required this.scenarioCount,
    required this.sourceFiles,
    required this.correlations,
    required this.statsWeightProposals,
    required this.generatedFiles,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'outputDir': outputDir.path,
        'scenarioCount': scenarioCount,
        'sourceFiles': sourceFiles,
        'correlations': correlations.map((value) => value.toJson()).toList(),
        'statsWeightProposals':
            statsWeightProposals.map((value) => value.toJson()).toList(),
        'generatedFiles': generatedFiles,
      };
}

class WargearUasCalibrationRunner {
  final WargearUniversalScoringEngine _engine;

  WargearUasCalibrationRunner({
    WargearUniversalScoringEngine? engine,
  }) : _engine = engine ?? const WargearUniversalScoringEngine();

  Future<WargearUasCalibrationSummary> run({
    required Directory inputDir,
    Directory? outputDir,
  }) async {
    final resolvedOutputDir = outputDir == null
        ? Directory('${inputDir.path}/uas_calibration')
        : outputDir;
    if (!await resolvedOutputDir.exists()) {
      await resolvedOutputDir.create(recursive: true);
    }

    final sources = await _discoverSources(inputDir);
    final catalog = await WargearWardrobeLoader.load();
    final statTierMap = <String, WargearStats>{
      for (final tier in BossSimulationConfig.defaultBattery().statTiers)
        tier.id: tier.bonusStats,
    };
    final strategyMap = <String, PetSkillUsageMode>{
      for (final strategy
          in BossSimulationConfig.defaultBattery().petUsageStrategies)
        strategy.id: strategy.usageMode,
    };

    final damageCorrelationByModeLevel = <String, _CorrelationAccumulator>{};
    final batteryCorrelationByModeLevel = <String, _CorrelationAccumulator>{};
    final statsRegressionByModeLevel = <String, _LinearRegressionAccumulator>{};
    final modeLevelScenarioCounts = <String, int>{};
    final factorStats = <String, Map<String, _MetricAccumulator>>{};
    final topTrackers = <String, _TopKTracker>{};

    var scenarioCount = 0;
    for (final source in sources) {
      final aggregateLines = await source.aggregateCsv.readAsLines();
      final scoreLines = await source.scoreCsv.readAsLines();
      if (aggregateLines.isEmpty || scoreLines.isEmpty) continue;

      final aggregateRows = _parseCsvRows(aggregateLines);
      final scoreRows = _parseCsvRows(scoreLines);
      if (aggregateRows.length != scoreRows.length) {
        throw StateError(
          'Aggregate/score row count mismatch for ${source.aggregateCsv.path} and ${source.scoreCsv.path}.',
        );
      }

      for (var index = 0; index < aggregateRows.length; index++) {
        final aggregate = aggregateRows[index];
        final score = scoreRows[index];
        final scenarioId = (aggregate['scenario_id'] ?? '').trim();
        if (scenarioId.isEmpty ||
            scenarioId != (score['scenario_id'] ?? '').trim()) {
          throw StateError(
            'Scenario id mismatch between aggregate and score rows: '
            '$scenarioId != ${(score['scenario_id'] ?? '').trim()}',
          );
        }

        final meta = _ScenarioMeta.parse(
          scenarioId: scenarioId,
          modeKey: (aggregate['mode'] ?? '').trim(),
          bossLevel: int.tryParse((aggregate['boss_level'] ?? '').trim()) ?? 0,
          petPrimarySkill: (aggregate['pet_primary_skill'] ?? '').trim(),
          statTierId: (aggregate['stat_tier_id'] ?? '').trim(),
          attackDefenseSwapped:
              (aggregate['atk_def_swapped'] ?? '').trim().toLowerCase() ==
                  'true',
        );
        final statPackage = statTierMap[meta.statTierId];
        if (statPackage == null) {
          throw StateError('Unknown stat tier id in scenario $scenarioId.');
        }
        final usageMode = strategyMap[meta.petStrategyId];
        if (usageMode == null) {
          throw StateError('Unknown pet strategy id in scenario $scenarioId.');
        }

        final scenarioStats = _ScenarioStatSnapshot.fromMeta(
          meta: meta,
          statPackage: statPackage,
          primaryBaseStats:
              catalog.rules.knightBaseStats[WargearRole.primary] ??
                  const WargearKnightBaseStats(
                    attack: 0,
                    defense: 0,
                    health: 0,
                  ),
          secondaryBaseStats:
              catalog.rules.knightBaseStats[WargearRole.secondary] ??
                  const WargearKnightBaseStats(
                    attack: 0,
                    defense: 0,
                    health: 0,
                  ),
          usageMode: usageMode,
          engine: _engine,
        );

        final meanDamage =
            double.tryParse((aggregate['mean_total_damage'] ?? '').trim()) ??
                0.0;
        final batteryFinalScore =
            double.tryParse((score['final_score'] ?? '').trim()) ?? 0.0;
        final modeLevel = meta.modeLevel;
        scenarioCount += 1;
        modeLevelScenarioCounts.update(
          modeLevel,
          (value) => value + 1,
          ifAbsent: () => 1,
        );

        damageCorrelationByModeLevel
            .putIfAbsent(modeLevel, _CorrelationAccumulator.new)
            .add(scenarioStats.uasTotalScore, meanDamage);
        batteryCorrelationByModeLevel
            .putIfAbsent(modeLevel, _CorrelationAccumulator.new)
            .add(scenarioStats.uasTotalScore, batteryFinalScore);
        statsRegressionByModeLevel
            .putIfAbsent(modeLevel, _LinearRegressionAccumulator.new)
            .add(
          <double>[
            1.0,
            scenarioStats.totalAttack / 1000.0,
            scenarioStats.totalDefense / 1000.0,
            scenarioStats.totalHealth / 100.0,
          ],
          batteryFinalScore,
        );

        _addFactorMetric(
          factorStats,
          factorType: 'pet_primary_skill',
          factorValue: meta.petPrimarySkill,
          uasValue: scenarioStats.uasTotalScore,
          meanDamage: meanDamage,
          batteryFinalScore: batteryFinalScore,
        );
        _addFactorMetric(
          factorStats,
          factorType: 'pet_strategy',
          factorValue: meta.petStrategyId,
          uasValue: scenarioStats.uasTotalScore,
          meanDamage: meanDamage,
          batteryFinalScore: batteryFinalScore,
        );
        _addFactorMetric(
          factorStats,
          factorType: 'attack_def_variant',
          factorValue: meta.attackDefenseSwapped ? 'swapped' : 'normal',
          uasValue: scenarioStats.uasTotalScore,
          meanDamage: meanDamage,
          batteryFinalScore: batteryFinalScore,
        );
        _addFactorMetric(
          factorStats,
          factorType: 'knight_adv_mean',
          factorValue: meta.knightAdvMean.toStringAsFixed(3),
          uasValue: scenarioStats.uasTotalScore,
          meanDamage: meanDamage,
          batteryFinalScore: batteryFinalScore,
        );
        _addFactorMetric(
          factorStats,
          factorType: 'boss_adv_mean',
          factorValue: meta.bossAdvMean.toStringAsFixed(3),
          uasValue: scenarioStats.uasTotalScore,
          meanDamage: meanDamage,
          batteryFinalScore: batteryFinalScore,
        );

        for (final group in <String>[
          'mode_level:${meta.modeLevel}',
          'mode_level_tier_skill:${meta.modeLevel}|${meta.statTierId}|${meta.petPrimarySkill}',
        ]) {
          topTrackers.putIfAbsent(group, _TopKTracker.new).add(
                scenarioId: scenarioId,
                uasValue: scenarioStats.uasTotalScore,
                meanDamage: meanDamage,
                batteryFinalScore: batteryFinalScore,
              );
        }
      }
    }

    final correlations = damageCorrelationByModeLevel.keys.map((modeLevel) {
      return WargearUasCalibrationCorrelation(
        modeLevel: modeLevel,
        scenarioCount: modeLevelScenarioCounts[modeLevel] ?? 0,
        uasVsMeanDamage:
            damageCorrelationByModeLevel[modeLevel]!.pearsonCorrelation,
        uasVsBatteryScore:
            batteryCorrelationByModeLevel[modeLevel]!.pearsonCorrelation,
      );
    }).toList(growable: false)
      ..sort((left, right) => left.modeLevel.compareTo(right.modeLevel));

    final statsWeightProposals =
        statsRegressionByModeLevel.entries.map((entry) {
      final coefficients = entry.value.solve();
      final attackScorePer1000 =
          coefficients.length > 1 ? coefficients[1] : 0.0;
      final defenseScorePer1000 =
          coefficients.length > 2 ? coefficients[2] : 0.0;
      final healthScorePer1000 =
          coefficients.length > 3 ? coefficients[3] * 10.0 : 0.0;
      final safeAttack =
          attackScorePer1000.abs() < 1e-9 ? 1.0 : attackScorePer1000;
      return WargearUasStatsWeightProposal(
        modeLevel: entry.key,
        scenarioCount: modeLevelScenarioCounts[entry.key] ?? 0,
        attackScorePer1000: attackScorePer1000,
        defenseScorePer1000: defenseScorePer1000,
        healthScorePer1000: healthScorePer1000,
        defenseWeightRelative: defenseScorePer1000 / safeAttack,
        healthWeightRelative: healthScorePer1000 / safeAttack,
      );
    }).toList(growable: false)
          ..sort((left, right) => left.modeLevel.compareTo(right.modeLevel));

    final generatedFiles = <String>[];
    generatedFiles.add(
      await _writeJson(
        File('${resolvedOutputDir.path}/uas_audit.json'),
        _engine.auditSnapshot(),
      ),
    );
    generatedFiles.add(
      await _writeCorrelationCsv(
        File('${resolvedOutputDir.path}/uas_correlation_by_mode_level.csv'),
        correlations,
      ),
    );
    generatedFiles.add(
      await _writeStatsWeightCsv(
        File('${resolvedOutputDir.path}/uas_stats_weight_proposals.csv'),
        statsWeightProposals,
      ),
    );
    generatedFiles.add(
      await _writeFactorSummaryCsv(
        File('${resolvedOutputDir.path}/uas_factor_summary.csv'),
        factorStats,
      ),
    );
    generatedFiles.add(
      await _writeTopKAgreementCsv(
        File('${resolvedOutputDir.path}/uas_topk_agreement.csv'),
        topTrackers,
      ),
    );
    generatedFiles.add(
      await _writeTopKMismatchCsv(
        File('${resolvedOutputDir.path}/uas_topk_mismatches.csv'),
        topTrackers,
      ),
    );

    final summary = WargearUasCalibrationSummary(
      outputDir: resolvedOutputDir,
      scenarioCount: scenarioCount,
      sourceFiles: sources
          .expand((source) => <String>[
                source.aggregateCsv.path,
                source.scoreCsv.path,
              ])
          .toList(growable: false),
      correlations: correlations,
      statsWeightProposals: statsWeightProposals,
      generatedFiles: const <String>[],
    );
    generatedFiles.add(
      await _writeMarkdownReport(
        File('${resolvedOutputDir.path}/uas_calibration_report.md'),
        summary: WargearUasCalibrationSummary(
          outputDir: summary.outputDir,
          scenarioCount: summary.scenarioCount,
          sourceFiles: summary.sourceFiles,
          correlations: summary.correlations,
          statsWeightProposals: summary.statsWeightProposals,
          generatedFiles: generatedFiles,
        ),
        factorStats: factorStats,
        topTrackers: topTrackers,
      ),
    );

    final finalizedSummary = WargearUasCalibrationSummary(
      outputDir: summary.outputDir,
      scenarioCount: summary.scenarioCount,
      sourceFiles: summary.sourceFiles,
      correlations: summary.correlations,
      statsWeightProposals: summary.statsWeightProposals,
      generatedFiles: List<String>.unmodifiable(generatedFiles),
    );
    generatedFiles.add(
      await _writeJson(
        File('${resolvedOutputDir.path}/uas_calibration_summary.json'),
        finalizedSummary.toJson(),
      ),
    );

    return WargearUasCalibrationSummary(
      outputDir: finalizedSummary.outputDir,
      scenarioCount: finalizedSummary.scenarioCount,
      sourceFiles: finalizedSummary.sourceFiles,
      correlations: finalizedSummary.correlations,
      statsWeightProposals: finalizedSummary.statsWeightProposals,
      generatedFiles: List<String>.unmodifiable(generatedFiles),
    );
  }

  Future<List<_CsvSourcePair>> _discoverSources(Directory inputDir) async {
    final mergedAggregate = File('${inputDir.path}/aggregates_all.csv');
    final mergedScore = File('${inputDir.path}/scores_all.csv');
    if (await mergedAggregate.exists() && await mergedScore.exists()) {
      return <_CsvSourcePair>[
        _CsvSourcePair(aggregateCsv: mergedAggregate, scoreCsv: mergedScore),
      ];
    }

    final aggregateFiles = inputDir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((file) => RegExp(r'aggregates_\d{4}\.csv$').hasMatch(file.path))
        .toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));
    final scoreFiles = inputDir
        .listSync(followLinks: false)
        .whereType<File>()
        .where((file) => RegExp(r'scores_\d{4}\.csv$').hasMatch(file.path))
        .toList(growable: false)
      ..sort((left, right) => left.path.compareTo(right.path));

    if (aggregateFiles.isEmpty || scoreFiles.isEmpty) {
      throw StateError(
        'No compatible battery CSV exports were found in ${inputDir.path}.',
      );
    }
    if (aggregateFiles.length != scoreFiles.length) {
      throw StateError(
        'Aggregate/score shard count mismatch in ${inputDir.path}.',
      );
    }

    final pairs = <_CsvSourcePair>[];
    for (var index = 0; index < aggregateFiles.length; index++) {
      final aggregate = aggregateFiles[index];
      final score = scoreFiles[index];
      final aggregateToken =
          RegExp(r'(\d{4})\.csv$').firstMatch(aggregate.path)?.group(1);
      final scoreToken =
          RegExp(r'(\d{4})\.csv$').firstMatch(score.path)?.group(1);
      if (aggregateToken != scoreToken) {
        throw StateError(
          'Aggregate/score shard token mismatch: ${aggregate.path} vs ${score.path}.',
        );
      }
      pairs.add(_CsvSourcePair(aggregateCsv: aggregate, scoreCsv: score));
    }
    return pairs;
  }

  List<Map<String, String>> _parseCsvRows(List<String> lines) {
    if (lines.length <= 1) return const <Map<String, String>>[];
    final header = _parseCsvLine(lines.first);
    final rows = <Map<String, String>>[];
    for (final line in lines.skip(1)) {
      if (line.trim().isEmpty) continue;
      final values = _parseCsvLine(line);
      final row = <String, String>{};
      for (var index = 0; index < header.length; index++) {
        row[header[index]] = index < values.length ? values[index] : '';
      }
      rows.add(row);
    }
    return rows;
  }

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final current = StringBuffer();
    var insideQuotes = false;
    for (var index = 0; index < line.length; index++) {
      final char = line[index];
      if (char == '"') {
        final nextIsQuote = index + 1 < line.length && line[index + 1] == '"';
        if (insideQuotes && nextIsQuote) {
          current.write('"');
          index += 1;
          continue;
        }
        insideQuotes = !insideQuotes;
        continue;
      }
      if (char == ',' && !insideQuotes) {
        values.add(current.toString());
        current.clear();
        continue;
      }
      current.write(char);
    }
    values.add(current.toString());
    return values;
  }

  void _addFactorMetric(
    Map<String, Map<String, _MetricAccumulator>> stats, {
    required String factorType,
    required String factorValue,
    required double uasValue,
    required double meanDamage,
    required double batteryFinalScore,
  }) {
    stats
        .putIfAbsent(factorType, () => <String, _MetricAccumulator>{})
        .putIfAbsent(factorValue, _MetricAccumulator.new)
        .add(
          uasValue: uasValue,
          meanDamage: meanDamage,
          batteryFinalScore: batteryFinalScore,
        );
  }

  Future<String> _writeJson(File file, Map<String, Object?> data) async {
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data),
      flush: true,
    );
    return file.path;
  }

  Future<String> _writeCorrelationCsv(
    File file,
    List<WargearUasCalibrationCorrelation> rows,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        'mode_level,scenario_count,pearson_uas_vs_mean_damage,pearson_uas_vs_battery_score',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.modeLevel},${row.scenarioCount},${row.uasVsMeanDamage},${row.uasVsBatteryScore}',
      );
    }
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  Future<String> _writeStatsWeightCsv(
    File file,
    List<WargearUasStatsWeightProposal> rows,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        'mode_level,scenario_count,attack_score_per_1000,defense_score_per_1000,health_score_per_1000,defense_weight_relative,health_weight_relative',
      );
    for (final row in rows) {
      buffer.writeln(
        '${row.modeLevel},${row.scenarioCount},${row.attackScorePer1000},${row.defenseScorePer1000},${row.healthScorePer1000},${row.defenseWeightRelative},${row.healthWeightRelative}',
      );
    }
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  Future<String> _writeFactorSummaryCsv(
    File file,
    Map<String, Map<String, _MetricAccumulator>> stats,
  ) async {
    final baselineByType = <String, String>{
      'pet_primary_skill': 'Soul Burn',
      'pet_strategy': 'double_s2_then_s1',
      'attack_def_variant': 'normal',
    };
    final buffer = StringBuffer()
      ..writeln(
        'factor_type,factor_value,scenario_count,mean_uas,mean_total_damage,mean_battery_score,relative_uas_to_baseline,relative_damage_to_baseline,relative_battery_to_baseline',
      );
    final factorTypes = stats.keys.toList(growable: false)..sort();
    for (final factorType in factorTypes) {
      final values = stats[factorType]!;
      final sortedValues = values.keys.toList(growable: false)
        ..sort((left, right) {
          final leftNum = double.tryParse(left);
          final rightNum = double.tryParse(right);
          if (leftNum != null && rightNum != null) {
            return leftNum.compareTo(rightNum);
          }
          return left.compareTo(right);
        });
      final baselineKey = baselineByType[factorType] ??
          sortedValues.firstWhere(
            (value) => double.tryParse(value) != null,
            orElse: () => sortedValues.first,
          );
      final baseline = values[baselineKey] ?? values[sortedValues.first]!;
      final baselineUas = baseline.meanUas == 0 ? 1.0 : baseline.meanUas;
      final baselineDamage =
          baseline.meanDamage == 0 ? 1.0 : baseline.meanDamage;
      final baselineBattery =
          baseline.meanBatteryScore == 0 ? 1.0 : baseline.meanBatteryScore;
      for (final factorValue in sortedValues) {
        final item = values[factorValue]!;
        buffer.writeln(
          '$factorType,$factorValue,${item.count},${item.meanUas},${item.meanDamage},${item.meanBatteryScore},${item.meanUas / baselineUas},${item.meanDamage / baselineDamage},${item.meanBatteryScore / baselineBattery}',
        );
      }
    }
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  Future<String> _writeTopKAgreementCsv(
    File file,
    Map<String, _TopKTracker> trackers,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        'group_type,group_key,k,overlap_vs_mean_damage,overlap_vs_battery_score,group_size',
      );
    final keys = trackers.keys.toList(growable: false)..sort();
    for (final key in keys) {
      final tracker = trackers[key]!;
      final parts = key.split(':');
      final groupType = parts.first;
      final groupKey = parts.sublist(1).join(':');
      for (final k in const <int>[5, 10]) {
        buffer.writeln(
          '$groupType,$groupKey,$k,${tracker.overlapFractionAgainstMeanDamage(k)},${tracker.overlapFractionAgainstBattery(k)},${tracker.groupSize}',
        );
      }
    }
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  Future<String> _writeTopKMismatchCsv(
    File file,
    Map<String, _TopKTracker> trackers,
  ) async {
    final buffer = StringBuffer()
      ..writeln(
        'group_type,group_key,source,scenario_id,uas_total,mean_total_damage,battery_final_score',
      );
    final keys = trackers.keys
        .where((key) => key.startsWith('mode_level:'))
        .toList(growable: false)
      ..sort();
    for (final key in keys) {
      final tracker = trackers[key]!;
      final parts = key.split(':');
      final groupType = parts.first;
      final groupKey = parts.sublist(1).join(':');
      for (final item in tracker.topKOnlyByUas(k: 10)) {
        buffer.writeln(
          '$groupType,$groupKey,uas_only,${item.scenarioId},${item.uasValue},${item.meanDamage},${item.batteryFinalScore}',
        );
      }
      for (final item in tracker.topKOnlyByBattery(k: 10)) {
        buffer.writeln(
          '$groupType,$groupKey,battery_only,${item.scenarioId},${item.uasValue},${item.meanDamage},${item.batteryFinalScore}',
        );
      }
    }
    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }

  Future<String> _writeMarkdownReport(
    File file, {
    required WargearUasCalibrationSummary summary,
    required Map<String, Map<String, _MetricAccumulator>> factorStats,
    required Map<String, _TopKTracker> topTrackers,
  }) async {
    final buffer = StringBuffer()
      ..writeln('# Universal Armor Score calibration audit')
      ..writeln()
      ..writeln('## Current UAS audit')
      ..writeln()
      ..writeln(
        'The current Universal Armor Score remains a fast local heuristic. '
        'This report compares it against the offline battery outputs without changing runtime behavior.',
      )
      ..writeln()
      ..writeln('Current usage sites:')
      ..writeln(
        '- UI label on imported/current armor in `lib/ui/home_page.dart`.',
      )
      ..writeln(
        '- Favorite ranking in `lib/data/wargear_wardrobe_candidates.dart`.',
      )
      ..writeln(
        '- Candidate preselection for Wardrobe Simulate in `lib/data/wargear_wardrobe_simulator.dart`.',
      )
      ..writeln()
      ..writeln('Known blind spots:')
      ..writeln(
          '- No direct calibration against simulation outputs before this audit.')
      ..writeln(
          '- No real-time run tempo unless fed by an offline calibration loop.')
      ..writeln(
        '- This calibration uses battery scenario multipliers via explicit overrides, not real armor element pairs.',
      )
      ..writeln()
      ..writeln('## Correlation by mode/level')
      ..writeln()
      ..writeln(
          '| Mode/Level | Scenarios | UAS vs mean damage | UAS vs battery score |')
      ..writeln('| --- | ---: | ---: | ---: |');
    for (final row in summary.correlations) {
      buffer.writeln(
        '| ${row.modeLevel} | ${row.scenarioCount} | ${row.uasVsMeanDamage.toStringAsFixed(4)} | ${row.uasVsBatteryScore.toStringAsFixed(4)} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## Proposed stat weights from battery score regression')
      ..writeln()
      ..writeln(
        '| Mode/Level | Attack per 1000 | Defense per 1000 | Health per 1000 | Defense rel | Health rel |',
      )
      ..writeln('| --- | ---: | ---: | ---: | ---: | ---: |');
    for (final row in summary.statsWeightProposals) {
      buffer.writeln(
        '| ${row.modeLevel} | ${row.attackScorePer1000.toStringAsFixed(3)} | ${row.defenseScorePer1000.toStringAsFixed(3)} | ${row.healthScorePer1000.toStringAsFixed(3)} | ${row.defenseWeightRelative.toStringAsFixed(3)} | ${row.healthWeightRelative.toStringAsFixed(3)} |',
      );
    }

    buffer
      ..writeln()
      ..writeln('## top-k ranking agreement')
      ..writeln()
      ..writeln('| Group | k | UAS vs mean damage | UAS vs battery score |')
      ..writeln('| --- | ---: | ---: | ---: |');
    final topKeys = topTrackers.keys.toList(growable: false)..sort();
    for (final key in topKeys) {
      final tracker = topTrackers[key]!;
      for (final k in const <int>[5, 10]) {
        buffer.writeln(
          '| $key | $k | ${tracker.overlapFractionAgainstMeanDamage(k).toStringAsFixed(3)} | ${tracker.overlapFractionAgainstBattery(k).toStringAsFixed(3)} |',
        );
      }
    }

    final primarySkillStats = factorStats['pet_primary_skill'] ?? const {};
    if (primarySkillStats.isNotEmpty) {
      final baseline =
          primarySkillStats['Soul Burn'] ?? primarySkillStats.values.first;
      final baselineBattery =
          baseline.meanBatteryScore == 0 ? 1.0 : baseline.meanBatteryScore;
      buffer
        ..writeln()
        ..writeln('## Pet primary skill uplift vs Soul Burn')
        ..writeln()
        ..writeln('| Skill | Mean battery score | Relative to Soul Burn |')
        ..writeln('| --- | ---: | ---: |');
      final keys = primarySkillStats.keys.toList(growable: false)..sort();
      for (final key in keys) {
        final item = primarySkillStats[key]!;
        buffer.writeln(
          '| $key | ${item.meanBatteryScore.toStringAsFixed(3)} | ${(item.meanBatteryScore / baselineBattery).toStringAsFixed(3)} |',
        );
      }
    }

    buffer
      ..writeln()
      ..writeln('Generated files:')
      ..writeln();
    for (final path in summary.generatedFiles) {
      buffer.writeln('- `${path.split(Platform.pathSeparator).last}`');
    }

    await file.writeAsString(buffer.toString(), flush: true);
    return file.path;
  }
}

class _CsvSourcePair {
  final File aggregateCsv;
  final File scoreCsv;

  const _CsvSourcePair({
    required this.aggregateCsv,
    required this.scoreCsv,
  });
}

class _ScenarioMeta {
  static final RegExp _scenarioIdPattern = RegExp(
    r'^(?<mode>[a-z]+)-l(?<bossLevel>\d+)'
    r'-layout_(?<layout>[ps]+)'
    r'-kadv_(?<kadv>[0-9_]+-[0-9_]+-[0-9_]+)'
    r'-badv_(?<badv>[0-9_]+-[0-9_]+-[0-9_]+)'
    r'-pet_(?<pet>.+)'
    r'-skill_(?<skill>.+)'
    r'-tier_(?<tier>tier_\d+)'
    r'-(?<variant>normal|swapped)$',
  );

  final String scenarioId;
  final String modeKey;
  final int bossLevel;
  final String layoutToken;
  final List<double> knightAdvantageVector;
  final List<double> bossAdvantageVector;
  final String petStrategyId;
  final String petPrimarySkill;
  final String statTierId;
  final bool attackDefenseSwapped;

  const _ScenarioMeta({
    required this.scenarioId,
    required this.modeKey,
    required this.bossLevel,
    required this.layoutToken,
    required this.knightAdvantageVector,
    required this.bossAdvantageVector,
    required this.petStrategyId,
    required this.petPrimarySkill,
    required this.statTierId,
    required this.attackDefenseSwapped,
  });

  String get modeLevel => '${modeKey}_L$bossLevel';

  double get knightAdvMean =>
      knightAdvantageVector.reduce((left, right) => left + right) /
      knightAdvantageVector.length;

  double get bossAdvMean =>
      bossAdvantageVector.reduce((left, right) => left + right) /
      bossAdvantageVector.length;

  static _ScenarioMeta parse({
    required String scenarioId,
    required String modeKey,
    required int bossLevel,
    required String petPrimarySkill,
    required String statTierId,
    required bool attackDefenseSwapped,
  }) {
    final match = _scenarioIdPattern.firstMatch(scenarioId);
    if (match == null) {
      throw StateError('Unable to parse scenario id: $scenarioId');
    }
    return _ScenarioMeta(
      scenarioId: scenarioId,
      modeKey: modeKey,
      bossLevel: bossLevel,
      layoutToken: match.namedGroup('layout') ?? '',
      knightAdvantageVector: _parseVector(match.namedGroup('kadv') ?? ''),
      bossAdvantageVector: _parseVector(match.namedGroup('badv') ?? ''),
      petStrategyId: match.namedGroup('pet') ?? '',
      petPrimarySkill: petPrimarySkill,
      statTierId: statTierId,
      attackDefenseSwapped: attackDefenseSwapped,
    );
  }

  static List<double> _parseVector(String raw) {
    return raw
        .split('-')
        .where((value) => value.trim().isNotEmpty)
        .map((value) => double.tryParse(value.replaceAll('_', '.')) ?? 0.0)
        .toList(growable: false);
  }
}

class _ScenarioStatSnapshot {
  final double uasTotalScore;
  final int totalAttack;
  final int totalDefense;
  final int totalHealth;

  const _ScenarioStatSnapshot({
    required this.uasTotalScore,
    required this.totalAttack,
    required this.totalDefense,
    required this.totalHealth,
  });

  static _ScenarioStatSnapshot fromMeta({
    required _ScenarioMeta meta,
    required WargearStats statPackage,
    required WargearKnightBaseStats primaryBaseStats,
    required WargearKnightBaseStats secondaryBaseStats,
    required PetSkillUsageMode usageMode,
    required WargearUniversalScoringEngine engine,
  }) {
    var uasTotalScore = 0.0;
    var totalAttack = 0;
    var totalDefense = 0;
    var totalHealth = 0;
    for (var index = 0; index < meta.layoutToken.length; index++) {
      final role = meta.layoutToken[index] == 'p'
          ? WargearRole.primary
          : WargearRole.secondary;
      final base =
          role == WargearRole.primary ? primaryBaseStats : secondaryBaseStats;
      final effectiveStats = WargearStats(
        attack: base.attack + statPackage.attack,
        defense: base.defense + statPackage.defense,
        health: base.health + statPackage.health,
      );
      totalAttack += effectiveStats.attack;
      totalDefense += effectiveStats.defense;
      totalHealth += effectiveStats.health;
      final score = engine.score(
        stats: effectiveStats,
        armorElements: const <ElementType>[
          ElementType.fire,
          ElementType.fire,
        ],
        context: WargearUniversalScoreContext(
          bossMode: meta.modeKey,
          bossLevel: meta.bossLevel,
          bossElements: const <ElementType>[
            ElementType.fire,
            ElementType.fire,
          ],
          petElements: const <ElementType>[],
          petElementalAttack: 0,
          petElementalDefense: 0,
          petSkillUsageMode: usageMode,
          petPrimarySkillName: meta.petPrimarySkill,
          petSecondarySkillName:
              BossSimulationConfig.defaultBattery().petSecondarySkill,
          knightAdvantageOverride: index < meta.knightAdvantageVector.length
              ? meta.knightAdvantageVector[index]
              : null,
          bossAdvantageOverride: index < meta.bossAdvantageVector.length
              ? meta.bossAdvantageVector[index]
              : null,
        ),
        variant: WargearUniversalScoreVariant.petAware,
      );
      uasTotalScore += score.score;
    }
    return _ScenarioStatSnapshot(
      uasTotalScore: uasTotalScore,
      totalAttack: totalAttack,
      totalDefense: totalDefense,
      totalHealth: totalHealth,
    );
  }
}

class _MetricAccumulator {
  int count = 0;
  double _sumUas = 0.0;
  double _sumDamage = 0.0;
  double _sumBatteryScore = 0.0;

  void add({
    required double uasValue,
    required double meanDamage,
    required double batteryFinalScore,
  }) {
    count += 1;
    _sumUas += uasValue;
    _sumDamage += meanDamage;
    _sumBatteryScore += batteryFinalScore;
  }

  double get meanUas => count == 0 ? 0.0 : _sumUas / count;
  double get meanDamage => count == 0 ? 0.0 : _sumDamage / count;
  double get meanBatteryScore => count == 0 ? 0.0 : _sumBatteryScore / count;
}

class _CorrelationAccumulator {
  int count = 0;
  double _sumX = 0.0;
  double _sumY = 0.0;
  double _sumX2 = 0.0;
  double _sumY2 = 0.0;
  double _sumXY = 0.0;

  void add(double x, double y) {
    count += 1;
    _sumX += x;
    _sumY += y;
    _sumX2 += x * x;
    _sumY2 += y * y;
    _sumXY += x * y;
  }

  double get pearsonCorrelation {
    if (count <= 1) return 0.0;
    final numerator = (count * _sumXY) - (_sumX * _sumY);
    final left = (count * _sumX2) - (_sumX * _sumX);
    final right = (count * _sumY2) - (_sumY * _sumY);
    final denominator = math.sqrt(math.max(0.0, left) * math.max(0.0, right));
    if (denominator <= 0) return 0.0;
    return numerator / denominator;
  }
}

class _LinearRegressionAccumulator {
  final List<List<double>> _xtx = List<List<double>>.generate(
    4,
    (_) => List<double>.filled(4, 0.0),
  );
  final List<double> _xty = List<double>.filled(4, 0.0);

  void add(List<double> features, double target) {
    for (var row = 0; row < _xtx.length; row++) {
      for (var column = 0; column < _xtx[row].length; column++) {
        _xtx[row][column] += features[row] * features[column];
      }
      _xty[row] += features[row] * target;
    }
  }

  List<double> solve() {
    final size = _xtx.length;
    final matrix = List<List<double>>.generate(
      size,
      (row) => <double>[..._xtx[row], _xty[row]],
    );

    for (var pivot = 0; pivot < size; pivot++) {
      var bestRow = pivot;
      for (var row = pivot + 1; row < size; row++) {
        if (matrix[row][pivot].abs() > matrix[bestRow][pivot].abs()) {
          bestRow = row;
        }
      }
      if (matrix[bestRow][pivot].abs() < 1e-9) {
        return List<double>.filled(size, 0.0);
      }
      if (bestRow != pivot) {
        final temp = matrix[pivot];
        matrix[pivot] = matrix[bestRow];
        matrix[bestRow] = temp;
      }

      final pivotValue = matrix[pivot][pivot];
      for (var column = pivot; column <= size; column++) {
        matrix[pivot][column] /= pivotValue;
      }

      for (var row = 0; row < size; row++) {
        if (row == pivot) continue;
        final factor = matrix[row][pivot];
        if (factor.abs() < 1e-12) continue;
        for (var column = pivot; column <= size; column++) {
          matrix[row][column] -= factor * matrix[pivot][column];
        }
      }
    }

    return List<double>.generate(size, (index) => matrix[index][size]);
  }
}

class _TopKEntry {
  final String scenarioId;
  final double uasValue;
  final double meanDamage;
  final double batteryFinalScore;

  const _TopKEntry({
    required this.scenarioId,
    required this.uasValue,
    required this.meanDamage,
    required this.batteryFinalScore,
  });
}

class _TopKTracker {
  static const int _maxK = 10;

  final List<_TopKEntry> _byUas = <_TopKEntry>[];
  final List<_TopKEntry> _byMeanDamage = <_TopKEntry>[];
  final List<_TopKEntry> _byBattery = <_TopKEntry>[];
  int groupSize = 0;

  void add({
    required String scenarioId,
    required double uasValue,
    required double meanDamage,
    required double batteryFinalScore,
  }) {
    groupSize += 1;
    final entry = _TopKEntry(
      scenarioId: scenarioId,
      uasValue: uasValue,
      meanDamage: meanDamage,
      batteryFinalScore: batteryFinalScore,
    );
    _insert(_byUas, entry, (value) => value.uasValue);
    _insert(_byMeanDamage, entry, (value) => value.meanDamage);
    _insert(_byBattery, entry, (value) => value.batteryFinalScore);
  }

  double overlapFractionAgainstMeanDamage(int k) {
    return _overlapFraction(_byUas, _byMeanDamage, k);
  }

  double overlapFractionAgainstBattery(int k) {
    return _overlapFraction(_byUas, _byBattery, k);
  }

  List<_TopKEntry> topKOnlyByUas({required int k}) {
    final primary = _slice(_byUas, k);
    final secondaryIds =
        _slice(_byBattery, k).map((item) => item.scenarioId).toSet();
    return primary
        .where((item) => !secondaryIds.contains(item.scenarioId))
        .toList(growable: false);
  }

  List<_TopKEntry> topKOnlyByBattery({required int k}) {
    final primary = _slice(_byBattery, k);
    final secondaryIds =
        _slice(_byUas, k).map((item) => item.scenarioId).toSet();
    return primary
        .where((item) => !secondaryIds.contains(item.scenarioId))
        .toList(growable: false);
  }

  void _insert(
    List<_TopKEntry> list,
    _TopKEntry entry,
    double Function(_TopKEntry value) keyOf,
  ) {
    list.add(entry);
    list.sort((left, right) => keyOf(right).compareTo(keyOf(left)));
    if (list.length > _maxK) {
      list.removeRange(_maxK, list.length);
    }
  }

  List<_TopKEntry> _slice(List<_TopKEntry> list, int k) {
    return list.take(math.min(k, list.length)).toList(growable: false);
  }

  double _overlapFraction(
    List<_TopKEntry> left,
    List<_TopKEntry> right,
    int k,
  ) {
    final leftSlice = _slice(left, k);
    final rightSlice = _slice(right, k);
    if (leftSlice.isEmpty || rightSlice.isEmpty) return 0.0;
    final leftIds = leftSlice.map((item) => item.scenarioId).toSet();
    final rightIds = rightSlice.map((item) => item.scenarioId).toSet();
    final overlap = leftIds.intersection(rightIds).length;
    return overlap / math.min(leftIds.length, rightIds.length);
  }
}
