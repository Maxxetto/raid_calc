import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'calibration_dataset.dart';
import 'calibration_runner.dart';

const Map<int, String> bossNumberSkillUsageByCode = <int, String>{
  1: 'special1Only',
  2: 'special2Only',
  3: 'cycleSpecial1Then2',
  4: 'special2ThenSpecial1',
  5: 'doubleSpecial2ThenSpecial1',
};

class BossNumberFile {
  final String path;
  final int schemaVersion;
  final String eventDate;
  final String label;
  final String mode;
  final int level;
  final List<String> bossElements;
  final String scoreKind;
  final CalibrationSetup setup;
  final BossNumberCandidateRanges candidateRanges;
  final List<int> observedScores;
  final String? notes;

  const BossNumberFile({
    required this.path,
    required this.schemaVersion,
    required this.eventDate,
    required this.label,
    required this.mode,
    required this.level,
    required this.bossElements,
    required this.scoreKind,
    required this.setup,
    required this.candidateRanges,
    required this.observedScores,
    required this.notes,
  });

  static Future<BossNumberFile> load(String path) async {
    final raw = await File(path).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw FormatException('Boss number file root must be an object: $path');
    }
    return BossNumberFile.fromJson(path, decoded.cast<String, Object?>());
  }

  factory BossNumberFile.fromJson(String path, Map<String, Object?> json) {
    final boss = _requiredMap(json, 'boss', path);
    final setup = _requiredMap(json, 'setup', path);
    final petBarCalibration = _requiredMap(json, 'petBarCalibration', path);
    final ranges = _requiredMap(petBarCalibration, 'candidateRanges', path);
    final mode = _requiredString(boss, 'mode', path).toLowerCase();
    if (mode != 'raid' && mode != 'blitz') {
      throw FormatException('boss.mode must be raid or blitz: $path');
    }
    final level = _requiredInt(boss, 'level', path);
    if (level <= 0) {
      throw FormatException('boss.level must be positive: $path');
    }

    final observedScores = _requiredNumList(json, 'observedScores', path)
        .map((value) => value.round())
        .toList(growable: false);
    if (observedScores.isEmpty || observedScores.any((score) => score <= 0)) {
      throw FormatException(
          'observedScores must contain positive values: $path');
    }

    return BossNumberFile(
      path: path,
      schemaVersion: _requiredInt(json, 'schemaVersion', path),
      eventDate: _requiredString(json, 'eventDate', path),
      label: _requiredString(json, 'label', path),
      mode: mode,
      level: level,
      bossElements: _requiredStringList(boss, 'elements', path),
      scoreKind: _requiredString(json, 'scoreKind', path),
      setup: _parseSetup(setup, path),
      candidateRanges: BossNumberCandidateRanges.fromJson(ranges, path),
      observedScores: observedScores,
      notes: (json['notes'] as String?)?.trim(),
    );
  }

  CalibrationDataset toCalibrationDataset() {
    return CalibrationDataset(
      version: schemaVersion,
      notes: 'Imported from ${_basename(path)}',
      datasets: <String, Map<int, List<CalibrationCase>>>{
        mode: <int, List<CalibrationCase>>{
          level: <CalibrationCase>[
            CalibrationCase(
              setupId: _stem(path),
              collectedAt: eventDate,
              scoreKind: scoreKind,
              bossElements: bossElements,
              setup: setup,
              observedScores: observedScores,
            ),
          ],
        },
      },
    );
  }

  ExtendedScoreSummary get observedStats =>
      ExtendedScoreSummary.fromScores(observedScores);

  static CalibrationSetup _parseSetup(Map<String, Object?> json, String path) {
    final rawKnights = (json['knights'] as List?) ?? const <Object?>[];
    final knights = <CalibrationKnight>[];
    for (final raw in rawKnights) {
      if (raw is! Map) continue;
      final knight = raw.cast<String, Object?>();
      knights.add(
        CalibrationKnight(
          atk: _requiredInt(knight, 'atk', path),
          def: _requiredInt(knight, 'def', path),
          hp: _requiredInt(knight, 'hp', path),
          stun: _requiredDouble(knight, 'stunChance', path),
          elements: _requiredStringList(knight, 'elements', path),
        ),
      );
    }
    if (knights.length != 3) {
      throw FormatException('setup.knights must contain 3 entries: $path');
    }

    final pet = _requiredMap(json, 'pet', path);
    final skillUsageCode = _requiredInt(pet, 'skillUsageCode', path);
    final skillUsage = bossNumberSkillUsageByCode[skillUsageCode];
    if (skillUsage == null) {
      throw FormatException('pet.skillUsageCode must be 1..5: $path');
    }
    final rawSkills = (pet['skills'] as List?) ?? const <Object?>[];
    final effects = <CalibrationPetEffect>[];
    for (final raw in rawSkills) {
      if (raw is! Map) continue;
      final skill = raw.cast<String, Object?>();
      effects.add(
        CalibrationPetEffect(
          canonicalEffectId: _requiredString(skill, 'canonicalEffectId', path),
          slot: _requiredInt(skill, 'slot', path),
          values: _numMap(_requiredMap(skill, 'values', path)),
        ),
      );
    }
    if (effects.isEmpty) {
      throw FormatException('setup.pet.skills must not be empty: $path');
    }

    return CalibrationSetup(
      knights: knights,
      pet: CalibrationPet(
        atk: _requiredInt(pet, 'atk', path),
        elementalAtk: _requiredInt(pet, 'elementalAtk', path),
        elementalDef: _requiredInt(pet, 'elementalDef', path),
        elements: _requiredStringList(pet, 'elements', path),
        skillUsage: skillUsage,
        cycloneAlwaysGem: pet['cycloneAlwaysGem'] == true,
        effects: effects,
      ),
    );
  }
}

class BossNumberCandidateRanges {
  final List<int> ticksPerState;
  final List<int> startTicks;
  final List<int> petKnightBaseTicks;
  final List<int> bossNormalTicks;
  final List<int> bossSpecialTicks;
  final List<int> bossMissTicks;
  final List<int> stunTicks;
  final List<double> petCritPlusOneProb;

  const BossNumberCandidateRanges({
    required this.ticksPerState,
    required this.startTicks,
    required this.petKnightBaseTicks,
    required this.bossNormalTicks,
    required this.bossSpecialTicks,
    required this.bossMissTicks,
    required this.stunTicks,
    required this.petCritPlusOneProb,
  });

  factory BossNumberCandidateRanges.fromJson(
    Map<String, Object?> json,
    String path,
  ) {
    final ticksPerState = _requiredIntList(json, 'ticksPerState', path);
    final startTicks = _requiredIntList(json, 'startTicks', path);
    if (ticksPerState.length != 1 ||
        startTicks.length != 1 ||
        startTicks.single != ticksPerState.single) {
      throw FormatException(
        'petBarCalibration.startTicks must be locked to one full pet bar '
        'state and equal ticksPerState: $path',
      );
    }
    return BossNumberCandidateRanges(
      ticksPerState: ticksPerState,
      startTicks: startTicks,
      petKnightBaseTicks: _requiredIntList(json, 'petKnightBaseTicks', path),
      bossNormalTicks: _requiredIntList(json, 'bossNormalTicks', path),
      bossSpecialTicks: _requiredIntList(json, 'bossSpecialTicks', path),
      bossMissTicks: _requiredIntList(json, 'bossMissTicks', path),
      stunTicks: _requiredIntList(json, 'stunTicks', path),
      petCritPlusOneProb: _requiredDoubleList(json, 'petCritPlusOneProb', path),
    );
  }

  int get combinationCount =>
      ticksPerState.length *
      startTicks.length *
      petKnightBaseTicks.length *
      bossNormalTicks.length *
      bossSpecialTicks.length *
      bossMissTicks.length *
      stunTicks.length *
      petCritPlusOneProb.length;

  Iterable<CalibrationKnobs> combinations() sync* {
    for (final ticks in ticksPerState) {
      for (final start in startTicks) {
        for (final petKnight in petKnightBaseTicks) {
          for (final bossNormal in bossNormalTicks) {
            for (final bossSpecial in bossSpecialTicks) {
              for (final bossMiss in bossMissTicks) {
                for (final stun in stunTicks) {
                  for (final petCrit in petCritPlusOneProb) {
                    yield CalibrationKnobs(
                      ticksPerState: ticks,
                      startTicks: start,
                      petKnightFill: petKnight,
                      bossNormalFill: bossNormal,
                      bossSpecialFill: bossSpecial,
                      bossMissFill: bossMiss,
                      stunFill: stun,
                      petCritPlusOneProb: petCrit,
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

  Map<String, Object?> toJson() => <String, Object?>{
        'ticksPerState': ticksPerState,
        'startTicks': startTicks,
        'petKnightBaseTicks': petKnightBaseTicks,
        'bossNormalTicks': bossNormalTicks,
        'bossSpecialTicks': bossSpecialTicks,
        'bossMissTicks': bossMissTicks,
        'stunTicks': stunTicks,
        'petCritPlusOneProb': petCritPlusOneProb,
      };
}

const double bossNumbersTieTolerance = 0.000001;

class BossNumbersSearchResult {
  final BossNumberFile source;
  final int runs;
  final int combinationsEvaluated;
  final ExtendedScoreSummary observedStats;
  final CalibrationCasePreview preview;
  final List<BossNumbersCandidateResult> equivalentBestResults;
  final List<BossNumbersCandidateResult> topResults;

  const BossNumbersSearchResult({
    required this.source,
    required this.runs,
    required this.combinationsEvaluated,
    required this.observedStats,
    required this.preview,
    required this.equivalentBestResults,
    required this.topResults,
  });

  BossNumbersCandidateResult get bestResult => topResults.first;
}

class BossNumbersCandidateResult {
  final CalibrationKnobs knobs;
  final CalibrationEvaluation evaluation;

  const BossNumbersCandidateResult({
    required this.knobs,
    required this.evaluation,
  });

  CalibrationCaseEvaluation get caseEvaluation => evaluation.cases.single;
  ScoreSummary get simulated => caseEvaluation.simulated;
  double get loss => evaluation.globalLoss;
  double get accuracy => math.max(0, 100 * (1 - loss));

  double get meanBiasPercent {
    final observedMean = caseEvaluation.observed.mean;
    if (observedMean.abs() < 1) return 0;
    return ((simulated.mean - observedMean) / observedMean) * 100;
  }
}

class BossNumbersCalibrator {
  const BossNumbersCalibrator();

  Future<BossNumbersSearchResult> evaluate({
    required BossNumberFile source,
    int? runs,
    int top = 10,
  }) async {
    final resolvedRuns = runs ?? source.observedScores.length;
    if (resolvedRuns <= 0) {
      throw ArgumentError.value(runs, 'runs', 'must be positive');
    }
    if (top <= 0) {
      throw ArgumentError.value(top, 'top', 'must be positive');
    }

    final dataset = source.toCalibrationDataset();
    final simRulesRaw = await _loadJsonFile('assets/sim_rules.json');
    final petBarRaw = await _loadJsonFile('assets/pet_bar_rules.json');
    final bossTablesRaw = await _loadJsonFile('assets/boss_tables.json');
    final results = <BossNumbersCandidateResult>[];

    for (final knobs in source.candidateRanges.combinations()) {
      final evaluation = await CalibrationRunner(
        dataset: dataset,
        knobs: knobs,
        runCountOverride: resolvedRuns,
      ).evaluateCurrentConfig(
        simRulesRaw: simRulesRaw,
        petBarRaw: petBarRaw,
        bossTablesRaw: bossTablesRaw,
      );
      results.add(
        BossNumbersCandidateResult(
          knobs: knobs,
          evaluation: evaluation,
        ),
      );
    }

    results.sort((a, b) => a.loss.compareTo(b.loss));
    if (results.isEmpty) {
      throw StateError('No candidate combinations were generated.');
    }
    final bestLoss = results.first.loss;
    final equivalentBestResults = results
        .where(
            (item) => (item.loss - bestLoss).abs() <= bossNumbersTieTolerance)
        .toList(growable: false);
    final preview = (await CalibrationRunner(
      dataset: dataset,
      knobs: results.first.knobs,
      runCountOverride: resolvedRuns,
    ).previewCases(
      simRulesRaw: simRulesRaw,
      petBarRaw: petBarRaw,
      bossTablesRaw: bossTablesRaw,
    ))
        .single;

    return BossNumbersSearchResult(
      source: source,
      runs: resolvedRuns,
      combinationsEvaluated: results.length,
      observedStats: source.observedStats,
      preview: preview,
      equivalentBestResults: equivalentBestResults,
      topResults: results.take(top).toList(growable: false),
    );
  }
}

class BossNumbersAfterWriter {
  const BossNumbersAfterWriter();

  Future<List<File>> write({
    required List<BossNumbersSearchResult> results,
    required String afterDir,
  }) async {
    if (results.isEmpty) {
      throw ArgumentError.value(results, 'results', 'must not be empty');
    }

    final dir = Directory(afterDir);
    await dir.create(recursive: true);
    final encoder = const JsonEncoder.withIndent('  ');
    final written = <File>[];

    for (final result in results) {
      final file = File('${dir.path}/${_stem(result.source.path)}_after.json');
      await file.writeAsString(
        '${encoder.convert(afterJson(result))}\n',
      );
      written.add(file);
    }

    final summary = File('${dir.path}/pet_bar_calibration_summary.json');
    await summary.writeAsString(
      '${encoder.convert(summaryJson(results))}\n',
    );
    written.add(summary);
    return written;
  }

  Map<String, Object?> afterJson(BossNumbersSearchResult result) {
    final source = result.source;
    return <String, Object?>{
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceFile': source.path,
      'context': <String, Object?>{
        'eventDate': source.eventDate,
        'label': source.label,
        'mode': source.mode,
        'level': source.level,
        'bossElements': source.bossElements,
        'scoreKind': source.scoreKind,
        'observedScoreCount': source.observedScores.length,
      },
      'petBarCalibration': <String, Object?>{
        'meaning':
            'candidateRanges is the search space tested by the tool, not the calibrated result.',
        'candidateRanges': source.candidateRanges.toJson(),
      },
      'resolvedSetup': _resolvedSetupJson(result.preview),
      'damagePreview': _damagePreviewJson(result.preview),
      'observedDistribution': _extendedSummaryToJson(result.observedStats),
      'calibrationResult': <String, Object?>{
        'runs': result.runs,
        'combinationsEvaluated': result.combinationsEvaluated,
        'tieTolerance': bossNumbersTieTolerance,
        'bestCandidate': _candidateToJson(result.bestResult),
        'equivalentBestCandidates':
            result.equivalentBestResults.map(_candidateToJson).toList(
                  growable: false,
                ),
        'topCandidates': result.topResults.map(_candidateToJson).toList(
              growable: false,
            ),
      },
      if (source.notes != null && source.notes!.isNotEmpty)
        'sourceNotes': source.notes,
    };
  }

  Map<String, Object?> summaryJson(List<BossNumbersSearchResult> results) {
    final recommendation = _recommendationJson(results);
    return <String, Object?>{
      'schemaVersion': 1,
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'sourceCount': results.length,
      'status': recommendation.status,
      'sources': results
          .map(
            (result) => <String, Object?>{
              'sourceFile': result.source.path,
              'mode': result.source.mode,
              'level': result.source.level,
              'bossElements': result.source.bossElements,
              'observedScoreCount': result.source.observedScores.length,
              'bestCandidate': _knobsToJson(result.bestResult.knobs),
              'loss': result.bestResult.loss,
              'accuracy': result.bestResult.accuracy,
              'biasPercent': result.bestResult.meanBiasPercent,
            },
          )
          .toList(growable: false),
      'recommendation': recommendation.values,
      'note':
          'This summary suggests candidate pet bar values only; it does not modify pet_bar_rules.json.',
    };
  }
}

class _Recommendation {
  final String status;
  final Map<String, Object?> values;

  const _Recommendation({
    required this.status,
    required this.values,
  });
}

Map<String, Object?> _resolvedSetupJson(CalibrationCasePreview preview) {
  final pet = preview.calibrationCase.data.setup.pet;
  final totalPetAtkBonus =
      preview.knights.fold<int>(0, (sum, knight) => sum + knight.petAtkBonus);
  final totalPetDefBonus =
      preview.knights.fold<int>(0, (sum, knight) => sum + knight.petDefBonus);
  return <String, Object?>{
    'pet': <String, Object?>{
      'elements': pet.elements,
      'atk': pet.atk,
      'elementalAtk': pet.elementalAtk,
      'elementalDef': pet.elementalDef,
      'elementalBonusRule':
          'Uses the same ordered armor bonus rule as Wargear Wardrobe; skill element matching is evaluated separately by the simulator.',
      'totalElementalBonusApplied': <String, Object?>{
        'atk': totalPetAtkBonus,
        'def': totalPetDefBonus,
      },
      'skillUsage': pet.skillUsage,
      'cycloneAlwaysGem': pet.cycloneAlwaysGem,
    },
    'knights': preview.knights
        .map(
          (knight) => <String, Object?>{
            'slot': knight.slot,
            'elements': knight.elements,
            'baseStats': <String, Object?>{
              'atk': knight.baseAtk,
              'def': knight.baseDef,
              'hp': knight.hp,
              'stunChance': knight.stun,
            },
            'petArmorBonusMatchCount': knight.petMatchCount,
            'petBonus': <String, Object?>{
              'atk': knight.petAtkBonus,
              'def': knight.petDefBonus,
            },
            'finalStats': <String, Object?>{
              'atk': knight.finalAtk,
              'def': knight.finalDef,
              'hp': knight.hp,
              'stunChance': knight.stun,
            },
            'advantage': <String, Object?>{
              'knightVsBoss': knight.knightAdvantage,
              'bossVsKnight': knight.bossAdvantage,
            },
          },
        )
        .toList(growable: false),
  };
}

Map<String, Object?> _damagePreviewJson(CalibrationCasePreview preview) {
  final pre = preview.pre;
  return <String, Object?>{
    'knights': List<Map<String, Object?>>.generate(
      preview.knights.length,
      (index) => <String, Object?>{
        'slot': preview.knights[index].slot,
        'kNormalDmg': pre.kNormalDmg[index],
        'kCritDmg': pre.kCritDmg[index],
        'kSpecialDmg': pre.kSpecialDmg[index],
        'bNormalDmg': pre.bNormalDmg[index],
        'bCritDmg': pre.bCritDmg[index],
      },
      growable: false,
    ),
    'pet': <String, Object?>{
      'petNormalDmg': pre.petNormalDmg,
      'petCritDmg': pre.petCritDmg,
      'petAdv': pre.petAdv,
    },
  };
}

Map<String, Object?> _candidateToJson(BossNumbersCandidateResult result) {
  return <String, Object?>{
    'values': _knobsToJson(result.knobs),
    'loss': result.loss,
    'accuracy': result.accuracy,
    'biasPercent': result.meanBiasPercent,
    'simulatedDistribution': _summaryToJson(result.simulated),
  };
}

Map<String, Object?> _knobsToJson(CalibrationKnobs knobs) => <String, Object?>{
      'ticksPerState': knobs.ticksPerState,
      'startTicks': knobs.startTicks,
      'petKnightBase': knobs.petKnightFill,
      'bossNormal': knobs.bossNormalFill,
      'bossSpecial': knobs.bossSpecialFill,
      'bossMiss': knobs.bossMissFill,
      'stun': knobs.stunFill,
      'petCritPlusOneProb': knobs.petCritPlusOneProb,
    };

Map<String, Object?> _summaryToJson(ScoreSummary summary) => <String, Object?>{
      'count': summary.count,
      'min': summary.min,
      'p10': summary.p10,
      'median': summary.median,
      'mean': summary.mean,
      'p90': summary.p90,
      'max': summary.max,
    };

Map<String, Object?> _extendedSummaryToJson(ExtendedScoreSummary summary) {
  return <String, Object?>{
    ..._summaryToJson(summary.summary),
    'standardDeviation': summary.standardDeviation,
    'coefficientOfVariationPercent': summary.coefficientOfVariationPercent,
  };
}

_Recommendation _recommendationJson(List<BossNumbersSearchResult> results) {
  final fields = <String, List<num>>{
    'ticksPerState': <num>[],
    'startTicks': <num>[],
    'petKnightBase': <num>[],
    'bossNormal': <num>[],
    'bossSpecial': <num>[],
    'bossMiss': <num>[],
    'stun': <num>[],
    'petCritPlusOneProb': <num>[],
  };

  for (final result in results) {
    for (final equivalent in result.equivalentBestResults) {
      _appendKnobValues(fields, equivalent.knobs);
    }
  }

  final values = <String, Object?>{};
  var allStable = true;
  fields.forEach((field, rawValues) {
    final unique = _uniqueSorted(rawValues);
    if (unique.length != 1) allStable = false;
    values[field] = <String, Object?>{
      'values': unique,
      'stable': unique.length == 1,
    };
  });

  final status = results.length < 2
      ? 'insufficient_cases'
      : allStable
          ? 'candidate_consensus'
          : 'mixed_results';
  return _Recommendation(status: status, values: values);
}

void _appendKnobValues(Map<String, List<num>> fields, CalibrationKnobs knobs) {
  void add(String key, num? value) {
    if (value != null) fields[key]!.add(value);
  }

  add('ticksPerState', knobs.ticksPerState);
  add('startTicks', knobs.startTicks);
  add('petKnightBase', knobs.petKnightFill);
  add('bossNormal', knobs.bossNormalFill);
  add('bossSpecial', knobs.bossSpecialFill);
  add('bossMiss', knobs.bossMissFill);
  add('stun', knobs.stunFill);
  add('petCritPlusOneProb', knobs.petCritPlusOneProb);
}

List<num> _uniqueSorted(List<num> values) {
  final out = <num>[];
  for (final value in values) {
    if (!out.any((existing) => existing == value)) out.add(value);
  }
  out.sort((a, b) => a.compareTo(b));
  return out;
}

class ExtendedScoreSummary {
  final ScoreSummary summary;
  final double standardDeviation;
  final double coefficientOfVariationPercent;

  const ExtendedScoreSummary({
    required this.summary,
    required this.standardDeviation,
    required this.coefficientOfVariationPercent,
  });

  factory ExtendedScoreSummary.fromScores(List<int> scores) {
    final summary = ScoreSummary.fromScores(scores);
    if (scores.isEmpty || summary.mean == 0) {
      return ExtendedScoreSummary(
        summary: summary,
        standardDeviation: 0,
        coefficientOfVariationPercent: 0,
      );
    }
    final variance = scores.fold<double>(
          0,
          (sum, score) => sum + math.pow(score - summary.mean, 2),
        ) /
        scores.length;
    final standardDeviation = math.sqrt(variance);
    return ExtendedScoreSummary(
      summary: summary,
      standardDeviation: standardDeviation,
      coefficientOfVariationPercent: standardDeviation / summary.mean * 100,
    );
  }
}

Future<Map<String, Object?>> _loadJsonFile(String path) async {
  final raw = await File(path).readAsString();
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw FormatException('JSON root in $path must be an object.');
  }
  return decoded.cast<String, Object?>();
}

Map<String, Object?> _requiredMap(
  Map<String, Object?> parent,
  String key,
  String path,
) {
  final value = parent[key];
  if (value is Map) return value.cast<String, Object?>();
  throw FormatException('$key must be an object: $path');
}

String _requiredString(
  Map<String, Object?> parent,
  String key,
  String path,
) {
  final value = parent[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('$key must be a non-empty string: $path');
}

int _requiredInt(Map<String, Object?> parent, String key, String path) {
  final value = parent[key];
  if (value is num) return value.round();
  throw FormatException('$key must be a number: $path');
}

double _requiredDouble(Map<String, Object?> parent, String key, String path) {
  final value = parent[key];
  if (value is num) return value.toDouble();
  throw FormatException('$key must be a number: $path');
}

List<String> _requiredStringList(
  Map<String, Object?> parent,
  String key,
  String path,
) {
  final value = parent[key];
  if (value is! List || value.isEmpty) {
    throw FormatException('$key must be a non-empty list: $path');
  }
  return value.map((item) {
    final text = item.toString().trim();
    if (text.isEmpty) {
      throw FormatException('$key must not contain empty values: $path');
    }
    return text;
  }).toList(growable: false);
}

List<num> _requiredNumList(
  Map<String, Object?> parent,
  String key,
  String path,
) {
  final value = parent[key];
  if (value is! List || value.isEmpty) {
    throw FormatException('$key must be a non-empty list: $path');
  }
  return value.map((item) {
    if (item is num) return item;
    throw FormatException('$key must contain only numbers: $path');
  }).toList(growable: false);
}

List<int> _requiredIntList(
  Map<String, Object?> parent,
  String key,
  String path,
) {
  return _requiredNumList(parent, key, path)
      .map((value) => value.round())
      .toList(growable: false);
}

List<double> _requiredDoubleList(
  Map<String, Object?> parent,
  String key,
  String path,
) {
  return _requiredNumList(parent, key, path)
      .map((value) => value.toDouble())
      .toList(growable: false);
}

Map<String, num> _numMap(Map<String, Object?> raw) {
  final out = <String, num>{};
  raw.forEach((key, value) {
    if (value is num) out[key] = value;
  });
  return out;
}

String _basename(String path) => path.split(RegExp(r'[\\/]')).last;

String _stem(String path) {
  final basename = _basename(path);
  final dot = basename.lastIndexOf('.');
  return dot <= 0 ? basename : basename.substring(0, dot);
}
