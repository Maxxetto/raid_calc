import 'dart:io';

import 'calibration/calibration_dataset.dart';
import 'calibration/calibration_runner.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  try {
    final dataset = await CalibrationDataset.loadFromFile(options.datasetPath);
    final cases = dataset.flattenCases();

    stdout.writeln('Simulation calibrator groundwork');
    stdout.writeln('Dataset: ${options.datasetPath}');
    stdout.writeln('Version: ${dataset.version}');
    if (dataset.notes != null && dataset.notes!.isNotEmpty) {
      stdout.writeln('Notes: ${dataset.notes}');
    }
    stdout.writeln('Cases: ${cases.length}');
    stdout.writeln('Observed score samples: '
        '${cases.fold<int>(0, (sum, c) => sum + c.data.observedScores.length)}');
    stdout.writeln('');

    if (cases.isEmpty) {
      stdout.writeln('No calibration cases found in the dataset.');
      return;
    }

    final byContext = <String, List<FlattenedCalibrationCase>>{};
    for (final c in cases) {
      final key = '${c.modeKey.toUpperCase()} L${c.level}';
      byContext.putIfAbsent(key, () => <FlattenedCalibrationCase>[]).add(c);
    }

    stdout.writeln('Context summary');
    for (final entry in byContext.entries) {
      final scoreCount = entry.value.fold<int>(
        0,
        (sum, c) => sum + c.data.observedScores.length,
      );
      stdout.writeln('- ${entry.key}: ${entry.value.length} cases, '
          '$scoreCount observed scores');
    }

    stdout.writeln('');
    stdout.writeln('Case summaries');
    final caseLimit = options.caseLimit.clamp(1, cases.length);
    for (final c in cases.take(caseLimit)) {
      final summary = ScoreSummary.fromScores(c.data.observedScores);
      stdout.writeln(
        '- ${c.data.setupId} [${c.modeKey.toUpperCase()} L${c.level}] '
        'scores=${summary.count} '
        'mean=${summary.mean.toStringAsFixed(1)} '
        'median=${summary.median.toStringAsFixed(1)} '
        'p10=${summary.p10.toStringAsFixed(1)} '
        'p90=${summary.p90.toStringAsFixed(1)} '
        'min=${summary.min} '
        'max=${summary.max}',
      );
    }

    if (cases.length > caseLimit) {
      stdout.writeln('... ${cases.length - caseLimit} more cases omitted');
    }

    stdout.writeln('');
    final evaluation = await CalibrationRunner(
      dataset: dataset,
      knobs: options.knobs,
    ).evaluateCurrentConfig();

    stdout.writeln('Calibration evaluation');
    stdout.writeln(
      'Global loss: ${evaluation.globalLoss.toStringAsFixed(6)}',
    );
    for (final item in evaluation.cases.take(caseLimit)) {
      stdout.writeln(
        '- ${item.calibrationCase.data.setupId}: '
        'obsMean=${item.observed.mean.toStringAsFixed(1)} '
        'simMean=${item.simulated.mean.toStringAsFixed(1)} '
        'obsMedian=${item.observed.median.toStringAsFixed(1)} '
        'simMedian=${item.simulated.median.toStringAsFixed(1)} '
        'loss=${item.loss.toStringAsFixed(6)}',
      );
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('Failed to load calibration dataset: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

class _CliOptions {
  final String datasetPath;
  final int caseLimit;
  final CalibrationKnobs knobs;

  const _CliOptions({
    required this.datasetPath,
    required this.caseLimit,
    required this.knobs,
  });

  static _CliOptions? parse(List<String> args) {
    String? datasetPath;
    var caseLimit = 10;
    int? ticksPerState;
    int? startTicks;
    double? petCritPlusOneProb;
    int? bossNormalFill;
    int? bossSpecialFill;
    int? bossMissFill;
    int? stunFill;
    int? petKnightFill;
    double? cycleMultiplier;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') {
        return null;
      }
      if (arg == '--dataset' && i + 1 < args.length) {
        datasetPath = args[++i];
        continue;
      }
      if (arg.startsWith('--dataset=')) {
        datasetPath = arg.substring('--dataset='.length);
        continue;
      }
      if (arg == '--case-limit' && i + 1 < args.length) {
        caseLimit = int.tryParse(args[++i]) ?? caseLimit;
        continue;
      }
      if (arg.startsWith('--case-limit=')) {
        caseLimit = int.tryParse(arg.substring('--case-limit='.length)) ??
            caseLimit;
        continue;
      }
      if (arg == '--ticks-per-state' && i + 1 < args.length) {
        ticksPerState = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--ticks-per-state=')) {
        ticksPerState = int.tryParse(arg.substring('--ticks-per-state='.length));
        continue;
      }
      if (arg == '--start-ticks' && i + 1 < args.length) {
        startTicks = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--start-ticks=')) {
        startTicks = int.tryParse(arg.substring('--start-ticks='.length));
        continue;
      }
      if (arg == '--pet-crit-plus-one-prob' && i + 1 < args.length) {
        petCritPlusOneProb = double.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--pet-crit-plus-one-prob=')) {
        petCritPlusOneProb =
            double.tryParse(arg.substring('--pet-crit-plus-one-prob='.length));
        continue;
      }
      if (arg == '--boss-normal-fill' && i + 1 < args.length) {
        bossNormalFill = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--boss-normal-fill=')) {
        bossNormalFill = int.tryParse(arg.substring('--boss-normal-fill='.length));
        continue;
      }
      if (arg == '--boss-special-fill' && i + 1 < args.length) {
        bossSpecialFill = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--boss-special-fill=')) {
        bossSpecialFill =
            int.tryParse(arg.substring('--boss-special-fill='.length));
        continue;
      }
      if (arg == '--boss-miss-fill' && i + 1 < args.length) {
        bossMissFill = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--boss-miss-fill=')) {
        bossMissFill = int.tryParse(arg.substring('--boss-miss-fill='.length));
        continue;
      }
      if (arg == '--stun-fill' && i + 1 < args.length) {
        stunFill = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--stun-fill=')) {
        stunFill = int.tryParse(arg.substring('--stun-fill='.length));
        continue;
      }
      if (arg == '--pet-knight-fill' && i + 1 < args.length) {
        petKnightFill = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--pet-knight-fill=')) {
        petKnightFill = int.tryParse(arg.substring('--pet-knight-fill='.length));
        continue;
      }
      if (arg == '--cycle-multiplier' && i + 1 < args.length) {
        cycleMultiplier = double.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--cycle-multiplier=')) {
        cycleMultiplier =
            double.tryParse(arg.substring('--cycle-multiplier='.length));
        continue;
      }
    }

    if (datasetPath == null || datasetPath.trim().isEmpty) {
      return null;
    }

    return _CliOptions(
      datasetPath: datasetPath,
      caseLimit: caseLimit,
      knobs: CalibrationKnobs(
        ticksPerState: ticksPerState,
        startTicks: startTicks,
        petCritPlusOneProb: petCritPlusOneProb,
        bossNormalFill: bossNormalFill,
        bossSpecialFill: bossSpecialFill,
        bossMissFill: bossMissFill,
        stunFill: stunFill,
        petKnightFill: petKnightFill,
        cycleMultiplier: cycleMultiplier,
      ),
    );
  }
}

void _printUsage() {
  stdout.writeln('Usage: flutter pub run tool/calibrate_sim.dart '
      '--dataset <path> [--case-limit <n>] '
      '[--ticks-per-state <n>] [--boss-normal-fill <n>] '
      '[--boss-special-fill <n>] [--boss-miss-fill <n>] '
      '[--stun-fill <n>] [--pet-knight-fill <n>] '
      '[--cycle-multiplier <v>]');
}
