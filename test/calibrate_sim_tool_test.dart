import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/calibration/calibration_dataset.dart';
import '../tool/calibration/calibration_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('calibration tool evaluates dataset and prints summary', () async {
    final datasetPath = const String.fromEnvironment(
      'CALIBRATION_DATASET',
      defaultValue: 'tool/calibration/data/calibration_dataset.sample.json',
    );
    final caseLimit = int.tryParse(
          const String.fromEnvironment(
            'CALIBRATION_CASE_LIMIT',
            defaultValue: '10',
          ),
        ) ??
        10;

    final knobs = CalibrationKnobs(
      ticksPerState: _readIntDefine('CALIBRATION_TICKS_PER_STATE'),
      startTicks: _readIntDefine('CALIBRATION_START_TICKS'),
      petCritPlusOneProb:
          _readDoubleDefine('CALIBRATION_PET_CRIT_PLUS_ONE_PROB'),
      bossNormalFill: _readIntDefine('CALIBRATION_BOSS_NORMAL_FILL'),
      bossSpecialFill: _readIntDefine('CALIBRATION_BOSS_SPECIAL_FILL'),
      bossMissFill: _readIntDefine('CALIBRATION_BOSS_MISS_FILL'),
      stunFill: _readIntDefine('CALIBRATION_STUN_FILL'),
      petKnightFill: _readIntDefine('CALIBRATION_PET_KNIGHT_FILL'),
      cycleMultiplier: _readDoubleDefine('CALIBRATION_CYCLE_MULTIPLIER'),
    );

    final dataset = await CalibrationDataset.loadFromFile(datasetPath);
    final cases = dataset.flattenCases();
    final evaluation =
        await CalibrationRunner(dataset: dataset, knobs: knobs)
            .evaluateCurrentConfig();

    stdout.writeln('Simulation calibrator');
    stdout.writeln('Dataset: $datasetPath');
    stdout.writeln('Cases: ${cases.length}');
    stdout.writeln('Global loss: ${evaluation.globalLoss.toStringAsFixed(6)}');
    for (final item in evaluation.cases.take(caseLimit)) {
      stdout.writeln(
        '- ${item.calibrationCase.data.setupId} '
        '[${item.calibrationCase.modeKey.toUpperCase()} '
        'L${item.calibrationCase.level}] '
        'obsMean=${item.observed.mean.toStringAsFixed(1)} '
        'simMean=${item.simulated.mean.toStringAsFixed(1)} '
        'obsMedian=${item.observed.median.toStringAsFixed(1)} '
        'simMedian=${item.simulated.median.toStringAsFixed(1)} '
        'loss=${item.loss.toStringAsFixed(6)}',
      );
    }

    expect(dataset.version, greaterThanOrEqualTo(1));
    expect(evaluation.cases.length, cases.length);
  });
}

int? _readIntDefine(String name) {
  final raw = String.fromEnvironment(name, defaultValue: '');
  if (raw.trim().isEmpty) return null;
  return int.tryParse(raw.trim());
}

double? _readDoubleDefine(String name) {
  final raw = String.fromEnvironment(name, defaultValue: '');
  if (raw.trim().isEmpty) return null;
  return double.tryParse(raw.trim());
}
