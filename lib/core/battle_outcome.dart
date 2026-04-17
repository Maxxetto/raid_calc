// lib/core/battle_outcome.dart
import 'package:flutter/foundation.dart';

@immutable
class SimulationCheckpoint {
  final int runIndex;
  final int sampledScore;
  final int cumulativeMean;
  final int cumulativeMin;
  final int cumulativeMax;

  const SimulationCheckpoint({
    required this.runIndex,
    int? sampledScore,
    required this.cumulativeMean,
    required this.cumulativeMin,
    required this.cumulativeMax,
  }) : sampledScore = sampledScore ?? cumulativeMean;

  Map<String, Object?> toJson() => {
        'runIndex': runIndex,
        'sampledScore': sampledScore,
        'cumulativeMean': cumulativeMean,
        'cumulativeMin': cumulativeMin,
        'cumulativeMax': cumulativeMax,
      };

  factory SimulationCheckpoint.fromJson(Map<String, Object?> j) =>
      SimulationCheckpoint(
        runIndex: (j['runIndex'] as num).toInt(),
        sampledScore: (j['sampledScore'] as num?)?.toInt(),
        cumulativeMean: (j['cumulativeMean'] as num).toInt(),
        cumulativeMin: (j['cumulativeMin'] as num).toInt(),
        cumulativeMax: (j['cumulativeMax'] as num).toInt(),
      );
}

@immutable
class SimulationSeries {
  final int checkpointEvery;
  final int totalRuns;
  final List<SimulationCheckpoint> checkpoints;
  final SimulationHistogram? histogram;

  const SimulationSeries({
    required this.checkpointEvery,
    required this.totalRuns,
    required this.checkpoints,
    this.histogram,
  });

  Map<String, Object?> toJson() => {
        'checkpointEvery': checkpointEvery,
        'totalRuns': totalRuns,
        'checkpoints':
            checkpoints.map((e) => e.toJson()).toList(growable: false),
        'histogram': histogram?.toJson(),
      };

  factory SimulationSeries.fromJson(Map<String, Object?> j) {
    final checkpointsRaw =
        (j['checkpoints'] as List?)?.cast<Object?>() ?? const <Object?>[];
    return SimulationSeries(
      checkpointEvery: (j['checkpointEvery'] as num).toInt(),
      totalRuns: (j['totalRuns'] as num).toInt(),
      checkpoints: checkpointsRaw
          .whereType<Map>()
          .map((e) => SimulationCheckpoint.fromJson(e.cast<String, Object?>()))
          .toList(growable: false),
      histogram: (j['histogram'] is Map)
          ? SimulationHistogram.fromJson(
              (j['histogram'] as Map).cast<String, Object?>(),
            )
          : null,
    );
  }
}

@immutable
class SimulationHistogramBin {
  final int lowerBound;
  final int upperBound;
  final int count;

  const SimulationHistogramBin({
    required this.lowerBound,
    required this.upperBound,
    required this.count,
  });

  Map<String, Object?> toJson() => {
        'lowerBound': lowerBound,
        'upperBound': upperBound,
        'count': count,
      };

  factory SimulationHistogramBin.fromJson(Map<String, Object?> j) =>
      SimulationHistogramBin(
        lowerBound: (j['lowerBound'] as num).toInt(),
        upperBound: (j['upperBound'] as num).toInt(),
        count: (j['count'] as num).toInt(),
      );
}

@immutable
class SimulationHistogram {
  final List<SimulationHistogramBin> bins;

  const SimulationHistogram({
    required this.bins,
  });

  Map<String, Object?> toJson() => {
        'bins': bins.map((e) => e.toJson()).toList(growable: false),
      };

  factory SimulationHistogram.fromJson(Map<String, Object?> j) {
    final binsRaw = (j['bins'] as List?)?.cast<Object?>() ?? const <Object?>[];
    return SimulationHistogram(
      bins: binsRaw
          .whereType<Map>()
          .map(
            (e) => SimulationHistogramBin.fromJson(
              e.cast<String, Object?>(),
            ),
          )
          .toList(growable: false),
    );
  }
}

@immutable
class TimingStats {
  final double meanRunSeconds;
  final double meanBossSeconds;
  final List<double> meanKnightSeconds;
  final List<double> meanSurvivalSeconds;
  final double meanPetAttacks;
  final double meanPetCritAttacks;
  final double meanPetMissAttacks;

  // Breakdown (mean counts + mean seconds), per knight
  final List<double> kNormalCount;
  final List<double> kNormalSeconds;

  final List<double> kSpecialCount;
  final List<double> kSpecialSeconds;

  final List<double> kStunCount;
  final List<double> kStunSeconds;

  final List<double> kMissCount;
  final List<double> kMissSeconds;

  final List<double> bNormalCount;
  final List<double> bNormalSeconds;

  final List<double> bSpecialCount;
  final List<double> bSpecialSeconds;

  final List<double> bMissCount;
  final List<double> bMissSeconds;

  const TimingStats({
    required this.meanRunSeconds,
    required this.meanBossSeconds,
    required this.meanKnightSeconds,
    required this.meanSurvivalSeconds,
    this.meanPetAttacks = 0,
    this.meanPetCritAttacks = 0,
    this.meanPetMissAttacks = 0,
    required this.kNormalCount,
    required this.kNormalSeconds,
    required this.kSpecialCount,
    required this.kSpecialSeconds,
    required this.kStunCount,
    required this.kStunSeconds,
    required this.kMissCount,
    required this.kMissSeconds,
    required this.bNormalCount,
    required this.bNormalSeconds,
    required this.bSpecialCount,
    required this.bSpecialSeconds,
    required this.bMissCount,
    required this.bMissSeconds,
  });

  Map<String, Object?> toJson() => {
        'meanRunSeconds': meanRunSeconds,
        'meanBossSeconds': meanBossSeconds,
        'meanKnightSeconds': meanKnightSeconds,
        'meanSurvivalSeconds': meanSurvivalSeconds,
        'meanPetAttacks': meanPetAttacks,
        'meanPetCritAttacks': meanPetCritAttacks,
        'meanPetMissAttacks': meanPetMissAttacks,
        'kNormalCount': kNormalCount,
        'kNormalSeconds': kNormalSeconds,
        'kSpecialCount': kSpecialCount,
        'kSpecialSeconds': kSpecialSeconds,
        'kStunCount': kStunCount,
        'kStunSeconds': kStunSeconds,
        'kMissCount': kMissCount,
        'kMissSeconds': kMissSeconds,
        'bNormalCount': bNormalCount,
        'bNormalSeconds': bNormalSeconds,
        'bSpecialCount': bSpecialCount,
        'bSpecialSeconds': bSpecialSeconds,
        'bMissCount': bMissCount,
        'bMissSeconds': bMissSeconds,
      };

  factory TimingStats.fromJson(Map<String, Object?> j) {
    List<double> _d(String k) => ((j[k] as List?) ?? const <Object?>[])
        .map((e) => (e as num).toDouble())
        .toList(growable: false);
    double _n(String k) => (j[k] as num?)?.toDouble() ?? 0.0;

    return TimingStats(
      meanRunSeconds: (j['meanRunSeconds'] as num).toDouble(),
      meanBossSeconds: (j['meanBossSeconds'] as num).toDouble(),
      meanKnightSeconds: _d('meanKnightSeconds'),
      meanSurvivalSeconds: _d('meanSurvivalSeconds'),
      meanPetAttacks: _n('meanPetAttacks'),
      meanPetCritAttacks: _n('meanPetCritAttacks'),
      meanPetMissAttacks: _n('meanPetMissAttacks'),
      kNormalCount: _d('kNormalCount'),
      kNormalSeconds: _d('kNormalSeconds'),
      kSpecialCount: _d('kSpecialCount'),
      kSpecialSeconds: _d('kSpecialSeconds'),
      kStunCount: _d('kStunCount'),
      kStunSeconds: _d('kStunSeconds'),
      kMissCount: _d('kMissCount'),
      kMissSeconds: _d('kMissSeconds'),
      bNormalCount: _d('bNormalCount'),
      bNormalSeconds: _d('bNormalSeconds'),
      bSpecialCount: _d('bSpecialCount'),
      bSpecialSeconds: _d('bSpecialSeconds'),
      bMissCount: _d('bMissCount'),
      bMissSeconds: _d('bMissSeconds'),
    );
  }
}

@immutable
class SimStats {
  final int mean;
  final int median;
  final int min;
  final int max;

  final TimingStats? timing;
  final SimulationSeries? series;
  final double? meanGemsSpent;

  const SimStats({
    required this.mean,
    required this.median,
    required this.min,
    required this.max,
    required this.timing,
    this.series,
    this.meanGemsSpent,
  });

  Map<String, Object?> toJson() => {
        'mean': mean,
        'median': median,
        'min': min,
        'max': max,
        'timing': timing?.toJson(),
        'series': series?.toJson(),
        'meanGemsSpent': meanGemsSpent,
      };

  factory SimStats.fromJson(Map<String, Object?> j) => SimStats(
        mean: (j['mean'] as num).toInt(),
        median: (j['median'] as num).toInt(),
        min: (j['min'] as num).toInt(),
        max: (j['max'] as num).toInt(),
        timing: (j['timing'] is Map)
            ? TimingStats.fromJson((j['timing'] as Map).cast<String, Object?>())
            : null,
        series: (j['series'] is Map)
            ? SimulationSeries.fromJson(
                (j['series'] as Map).cast<String, Object?>(),
              )
            : null,
        meanGemsSpent: (j['meanGemsSpent'] as num?)?.toDouble(),
      );
}
