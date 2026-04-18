import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const double pythonMultiplierConst = 164.0;

class MultiplierDatasetRow {
  final double knightDefense;
  final double damageReceived;
  final double bossAdvantage;
  final int bossLevel;
  final bool isBlitz;

  const MultiplierDatasetRow({
    required this.knightDefense,
    required this.damageReceived,
    required this.bossAdvantage,
    required this.bossLevel,
    required this.isBlitz,
  });

  factory MultiplierDatasetRow.fromSequence(List<Object?> row, {required int rowIndex}) {
    if (row.length != 5) {
      throw FormatException(
        'Row $rowIndex must have 5 items: '
        '[KnightDef, DMGRecv, BossAdv, BossLVL, IsBlitz].',
      );
    }
    return MultiplierDatasetRow(
      knightDefense: _readDouble(row[0], 'row $rowIndex knightDefense'),
      damageReceived: _readDouble(row[1], 'row $rowIndex damageReceived'),
      bossAdvantage: _readDouble(row[2], 'row $rowIndex bossAdvantage'),
      bossLevel: _readInt(row[3], 'row $rowIndex bossLevel'),
      isBlitz: _readBool(row[4]),
    );
  }

  static double _readDouble(Object? raw, String label) {
    if (raw is num) return raw.toDouble();
    final parsed = double.tryParse('$raw');
    if (parsed != null) return parsed;
    throw FormatException('Invalid numeric value for $label: $raw');
  }

  static int _readInt(Object? raw, String label) {
    if (raw is num) return raw.toInt();
    final parsed = int.tryParse('$raw');
    if (parsed != null) return parsed;
    throw FormatException('Invalid integer value for $label: $raw');
  }

  static bool _readBool(Object? raw) {
    if (raw is bool) return raw;
    if (raw is num) return raw.toInt() != 0;
    final normalized = '$raw'.trim().toLowerCase();
    return normalized == 'true' ||
        normalized == '1' ||
        normalized == 'yes' ||
        normalized == 'y';
  }
}

class MultiplierSample {
  final MultiplierDatasetRow row;
  final double bossAttack;
  final double factor1;
  final double factor2;
  final double multiplier;

  const MultiplierSample({
    required this.row,
    required this.bossAttack,
    required this.factor1,
    required this.factor2,
    required this.multiplier,
  });
}

class MultiplierEstimate {
  final double multiplier;
  final double ciLow;
  final double ciHigh;
  final int totalSamples;
  final int usedSamples;
  final int removedSamples;
  final String estimator;
  final String trimMethod;
  final double trimK;
  final List<MultiplierSample> samples;
  final double median;
  final double mean;
  final double harmonicMean;
  final double weightedMean;
  final double heterogeneityQ;
  final int heterogeneityDf;
  final double heterogeneityI2Percent;

  const MultiplierEstimate({
    required this.multiplier,
    required this.ciLow,
    required this.ciHigh,
    required this.totalSamples,
    required this.usedSamples,
    required this.removedSamples,
    required this.estimator,
    required this.trimMethod,
    required this.trimK,
    required this.samples,
    required this.median,
    required this.mean,
    required this.harmonicMean,
    required this.weightedMean,
    required this.heterogeneityQ,
    required this.heterogeneityDf,
    required this.heterogeneityI2Percent,
  });
}

class CycleMultiplierEstimator {
  final Map<bool, Map<int, double>> _bossAttackByModeAndLevel;

  const CycleMultiplierEstimator._(this._bossAttackByModeAndLevel);

  static Future<CycleMultiplierEstimator> fromBossTablesJson(
    String path,
  ) async {
    final raw = await File(path).readAsString();
    final normalized = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
    final decoded = jsonDecode(normalized);
    if (decoded is! Map) {
      throw const FormatException('Boss tables root must be an object.');
    }

    Map<int, double> readTable(String key) {
      final rows = (decoded[key] as List?) ?? const <Object?>[];
      final out = <int, double>{};
      for (final row in rows.whereType<Map>()) {
        final level = (row['level'] as num?)?.toInt();
        final attack = (row['attack'] as num?)?.toDouble();
        if (level == null || attack == null) continue;
        out[level] = attack;
      }
      return out;
    }

    return CycleMultiplierEstimator._(
      <bool, Map<int, double>>{
        true: readTable('Blitz'),
        false: readTable('Raid'),
      },
    );
  }

  static Future<List<MultiplierDatasetRow>> loadDatasetRows(String path) async {
    final raw = await File(path).readAsString();
    final normalized = raw.startsWith('\uFEFF') ? raw.substring(1) : raw;
    final decoded = jsonDecode(normalized);
    if (decoded is! List) {
      throw const FormatException(
        'Multiplier dataset must be a list of rows.',
      );
    }
    final rows = <MultiplierDatasetRow>[];
    for (int i = 0; i < decoded.length; i++) {
      final entry = decoded[i];
      if (entry is! List) {
        throw FormatException('Row ${i + 1} must be a list.');
      }
      rows.add(
        MultiplierDatasetRow.fromSequence(
          entry.cast<Object?>(),
          rowIndex: i + 1,
        ),
      );
    }
    return rows;
  }

  MultiplierEstimate estimate(
    List<MultiplierDatasetRow> rows, {
    String estimator = 'weighted_harmonic_mean',
    String trimMethod = 'mad',
    double trimK = 3.5,
    int bootstrapIterations = 2000,
  }) {
    if (rows.isEmpty) {
      throw const FormatException('Multiplier dataset is empty.');
    }

    final samples = <MultiplierSample>[];
    for (final row in rows) {
      final bossAttack = _bossAttackByModeAndLevel[row.isBlitz]?[row.bossLevel];
      if (bossAttack == null) {
        throw FormatException(
          'Boss attack not found for '
          '${row.isBlitz ? 'Blitz' : 'Raid'} L${row.bossLevel}.',
        );
      }
      final factor1 = bossAttack * row.bossAdvantage * pythonMultiplierConst;
      final factor2 = row.knightDefense * math.max(row.damageReceived, 1e-12);
      final mi = factor1 / factor2;
      samples.add(
        MultiplierSample(
          row: row,
          bossAttack: bossAttack,
          factor1: factor1,
          factor2: factor2,
          multiplier: mi,
        ),
      );
    }

    final kept = _trimSamples(samples, method: trimMethod, k: trimK);
    final multipliers = kept.map((e) => e.multiplier).toList(growable: false);
    final weights = kept.map((e) => e.factor2).toList(growable: false);
    final estimateValue = _aggregate(
      multipliers,
      weights,
      estimator: estimator,
    );
    final ci = _bootstrapCi(
      multipliers,
      weights,
      estimator: estimator,
      iterations: bootstrapIterations,
    );
    final hetero = _heterogeneity(multipliers, weights);

    return MultiplierEstimate(
      multiplier: estimateValue,
      ciLow: ci.$1,
      ciHigh: ci.$2,
      totalSamples: samples.length,
      usedSamples: kept.length,
      removedSamples: samples.length - kept.length,
      estimator: estimator,
      trimMethod: trimMethod,
      trimK: trimK,
      samples: kept,
      median: _median(multipliers),
      mean: multipliers.reduce((a, b) => a + b) / multipliers.length,
      harmonicMean: _harmonicMean(multipliers),
      weightedMean: _weightedMean(multipliers, weights),
      heterogeneityQ: hetero.$1,
      heterogeneityDf: hetero.$2,
      heterogeneityI2Percent: hetero.$3,
    );
  }

  List<MultiplierSample> _trimSamples(
    List<MultiplierSample> samples, {
    required String method,
    required double k,
  }) {
    if (method.toLowerCase() != 'mad' || samples.length < 3) {
      return List<MultiplierSample>.from(samples, growable: false);
    }
    final values = samples.map((e) => e.multiplier).toList(growable: false)
      ..sort();
    final med = _median(values);
    final deviations = values
        .map((value) => (value - med).abs())
        .toList(growable: false)
      ..sort();
    final mad = _median(deviations);
    if (mad <= 0) {
      return List<MultiplierSample>.from(samples, growable: false);
    }
    final scale = 1.4826 * mad;
    return samples
        .where((sample) => ((sample.multiplier - med).abs() / scale) <= k)
        .toList(growable: false);
  }

  static double _aggregate(
    List<double> multipliers,
    List<double> weights, {
    required String estimator,
  }) {
    return switch (estimator.toLowerCase()) {
      'median' => _median(List<double>.from(multipliers)..sort()),
      'mean' =>
        multipliers.reduce((a, b) => a + b) / math.max(1, multipliers.length),
      'hmean' || 'harmonic_mean' => _harmonicMean(multipliers),
      'weighted' || 'weighted_mean' => _weightedMean(multipliers, weights),
      _ => _weightedHarmonicMean(multipliers, weights),
    };
  }

  static (double, double) _bootstrapCi(
    List<double> multipliers,
    List<double> weights, {
    required String estimator,
    required int iterations,
  }) {
    if (multipliers.length < 2) {
      final only = multipliers.first;
      return (only, only);
    }
    final rng = math.Random(12345);
    final boots = <double>[];
    for (int i = 0; i < iterations; i++) {
      final sampledM = <double>[];
      final sampledW = <double>[];
      for (int j = 0; j < multipliers.length; j++) {
        final idx = rng.nextInt(multipliers.length);
        sampledM.add(multipliers[idx]);
        sampledW.add(weights[idx]);
      }
      boots.add(_aggregate(sampledM, sampledW, estimator: estimator));
    }
    boots.sort();
    return (_percentile(boots, 0.025), _percentile(boots, 0.975));
  }

  static (double, int, double) _heterogeneity(
    List<double> multipliers,
    List<double> weights,
  ) {
    if (multipliers.length < 2) {
      return (0.0, 1, 0.0);
    }
    final wm = _weightedMean(multipliers, weights);
    double q = 0.0;
    for (int i = 0; i < multipliers.length; i++) {
      q += weights[i] * math.pow(multipliers[i] - wm, 2).toDouble();
    }
    final df = math.max(1, multipliers.length - 1);
    final i2 = q > 0 ? (math.max(0.0, (q - df) / q) * 100.0) : 0.0;
    return (q, df, i2);
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static double _percentile(List<double> values, double p) {
    if (values.isEmpty) return 0.0;
    final index = (values.length - 1) * p.clamp(0.0, 1.0);
    final lower = index.floor();
    final upper = index.ceil();
    if (lower == upper) return values[lower];
    final t = index - lower;
    return values[lower] * (1.0 - t) + values[upper] * t;
  }

  static double _harmonicMean(List<double> values) {
    final denom = values.fold<double>(
      0.0,
      (sum, value) => sum + (1.0 / math.max(value, 1e-12)),
    );
    return values.length / math.max(denom, 1e-12);
  }

  static double _weightedMean(List<double> values, List<double> weights) {
    double weighted = 0.0;
    double total = 0.0;
    for (int i = 0; i < values.length; i++) {
      weighted += values[i] * weights[i];
      total += weights[i];
    }
    return weighted / math.max(total, 1e-12);
  }

  static double _weightedHarmonicMean(
    List<double> values,
    List<double> weights,
  ) {
    double totalWeight = 0.0;
    double denom = 0.0;
    for (int i = 0; i < values.length; i++) {
      final weight = math.max(weights[i], 1e-12);
      final value = math.max(values[i], 1e-12);
      totalWeight += weight;
      denom += weight / value;
    }
    return totalWeight / math.max(denom, 1e-12);
  }
}
