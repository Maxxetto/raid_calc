import 'package:flutter/foundation.dart';

import '../core/battle_outcome.dart';
import '../core/sim_types.dart';
import 'config_models.dart';
import 'setup_models.dart';

@immutable
class BulkExpectedRange {
  final int lower;
  final int upper;

  const BulkExpectedRange({
    required this.lower,
    required this.upper,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'lower': lower,
        'upper': upper,
      };
}

@immutable
class BulkSimulationRunResult {
  static const double expectedMeanPct = 0.08; // Same as ResultsPage.
  static const int maxScorePoints = 200000000000;

  final int slot;
  final String? slotName;
  final SetupSnapshot setup;
  final Precomputed pre;
  final SimStats stats;
  final ShatterShieldConfig? shatter;
  final String completedAtIso;

  BulkSimulationRunResult({
    required int slot,
    this.slotName,
    required this.setup,
    required this.pre,
    required this.stats,
    required this.shatter,
    DateTime? completedAt,
  })  : slot = slot.clamp(1, 5),
        completedAtIso = (completedAt ?? DateTime.now()).toIso8601String();

  BulkExpectedRange get expectedRange {
    final half = stats.mean * expectedMeanPct;
    final lower = (stats.mean - half).round().clamp(0, maxScorePoints);
    final upper = (stats.mean + half).round().clamp(0, maxScorePoints);
    return BulkExpectedRange(lower: lower, upper: upper);
  }

  double? get meanRunSeconds {
    final v = stats.timing?.meanRunSeconds;
    if (v == null || !v.isFinite || v <= 0) return null;
    return v;
  }

  double? get pointsPerSecond {
    final sec = meanRunSeconds;
    if (sec == null || sec <= 0) return null;
    return stats.mean / sec;
  }
}

@immutable
class BulkComparisonRow {
  final int slot;
  final String? slotName;
  final String bossMode; // raid | blitz
  final int bossLevel;
  final bool cycloneUseGemsForSpecials;
  final List<SetupKnightSnapshot> knights;
  final SetupPetSnapshot pet;
  final int petNormalDamage;
  final int petCritDamage;

  final int minPoints;
  final int meanPoints;
  final int medianPoints;
  final int maxPoints;
  final BulkExpectedRange expectedRange;
  final double? meanRunSeconds;
  final double? pointsPerSecond;
  final double? lowestKnightSurvivalSeconds;
  final SimulationSeries? series;

  const BulkComparisonRow({
    required this.slot,
    required this.slotName,
    required this.bossMode,
    required this.bossLevel,
    this.cycloneUseGemsForSpecials = true,
    required this.knights,
    required this.pet,
    required this.petNormalDamage,
    required this.petCritDamage,
    required this.minPoints,
    required this.meanPoints,
    required this.medianPoints,
    required this.maxPoints,
    required this.expectedRange,
    required this.meanRunSeconds,
    required this.pointsPerSecond,
    required this.lowestKnightSurvivalSeconds,
    required this.series,
  });

  factory BulkComparisonRow.fromRun(BulkSimulationRunResult run) {
    return BulkComparisonRow(
      slot: run.slot,
      slotName: run.slotName,
      bossMode: run.setup.bossMode,
      bossLevel: run.setup.bossLevel,
      cycloneUseGemsForSpecials:
          run.setup.modeEffects.cycloneUseGemsForSpecials,
      knights: List<SetupKnightSnapshot>.unmodifiable(run.setup.knights),
      pet: run.setup.pet,
      petNormalDamage: run.pre.petNormalDmg,
      petCritDamage: run.pre.petCritDmg,
      minPoints: run.stats.min,
      meanPoints: run.stats.mean,
      medianPoints: run.stats.median,
      maxPoints: run.stats.max,
      expectedRange: run.expectedRange,
      meanRunSeconds: run.meanRunSeconds,
      pointsPerSecond: run.pointsPerSecond,
      lowestKnightSurvivalSeconds: () {
        final values =
            run.stats.timing?.meanSurvivalSeconds ?? const <double>[];
        if (values.isEmpty) return null;
        final valid = values.where((value) => value.isFinite && value >= 0);
        if (valid.isEmpty) return null;
        return valid.reduce((a, b) => a < b ? a : b);
      }(),
      series: run.stats.series,
    );
  }
}

@immutable
class BulkSimulationBatchResult {
  final List<BulkSimulationRunResult> runs;

  BulkSimulationBatchResult({
    required List<BulkSimulationRunResult> runs,
  }) : runs = List<BulkSimulationRunResult>.unmodifiable(runs);

  List<BulkSimulationRunResult> get runsBySlot {
    final out = List<BulkSimulationRunResult>.from(runs);
    out.sort((a, b) => a.slot.compareTo(b.slot));
    return out;
  }

  List<BulkComparisonRow> get comparisonRows =>
      runsBySlot.map(BulkComparisonRow.fromRun).toList(growable: false);
}
