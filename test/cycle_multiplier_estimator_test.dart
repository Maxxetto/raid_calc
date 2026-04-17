import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../tool/calibration/cycle_multiplier_estimator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cycle multiplier estimator reproduces python-style dataset flow',
      () async {
    final bossTablesPath = const String.fromEnvironment(
      'CYCLE_MULTIPLIER_BOSS_TABLES',
      defaultValue: 'assets/boss_tables.json',
    );
    final datasetPath = const String.fromEnvironment(
      'CYCLE_MULTIPLIER_DATASET',
      defaultValue: 'tool/calibration/data/multiplier_dataset.sample.json',
    );

    final estimator = await CycleMultiplierEstimator.fromBossTablesJson(
      bossTablesPath,
    );
    final rows = await CycleMultiplierEstimator.loadDatasetRows(datasetPath);
    final estimate = estimator.estimate(
      rows,
      estimator: 'weighted_harmonic_mean',
      trimMethod: 'mad',
      trimK: 3.5,
      bootstrapIterations: 500,
    );

    debugPrint('Cycle multiplier estimator');
    debugPrint('Dataset: $datasetPath');
    debugPrint(
      'Samples: total=${estimate.totalSamples} used=${estimate.usedSamples}',
    );
    debugPrint(
      'Multiplier=${estimate.multiplier.toStringAsFixed(6)} '
      'CI95=[${estimate.ciLow.toStringAsFixed(6)}, '
      '${estimate.ciHigh.toStringAsFixed(6)}]',
    );
    debugPrint(
      'Summary median=${estimate.median.toStringAsFixed(6)} '
      'mean=${estimate.mean.toStringAsFixed(6)} '
      'hmean=${estimate.harmonicMean.toStringAsFixed(6)} '
      'weightedMean=${estimate.weightedMean.toStringAsFixed(6)}',
    );
    debugPrint(
      'Heterogeneity Q=${estimate.heterogeneityQ.toStringAsFixed(6)} '
      'df=${estimate.heterogeneityDf} '
      'I2=${estimate.heterogeneityI2Percent.toStringAsFixed(2)}%',
    );
    for (final sample in estimate.samples.take(10)) {
      debugPrint(
        '- ${sample.row.isBlitz ? 'Blitz' : 'Raid'} L${sample.row.bossLevel} '
        'def=${sample.row.knightDefense.toStringAsFixed(0)} '
        'dmg=${sample.row.damageReceived.toStringAsFixed(3)} '
        'bossAdv=${sample.row.bossAdvantage.toStringAsFixed(3)} '
        'Mi=${sample.multiplier.toStringAsFixed(6)}',
      );
    }

    expect(estimate.totalSamples, rows.length);
    expect(estimate.usedSamples, greaterThan(0));
    expect(estimate.multiplier, greaterThan(0));
    expect(estimate.ciHigh, greaterThanOrEqualTo(estimate.ciLow));
    if (datasetPath.endsWith('assets/multiplier_dataset_regression.json')) {
      expect(estimate.usedSamples, 12);
      expect(estimate.multiplier, closeTo(1.3678581290530216, 1e-12));
    }
  });
}
