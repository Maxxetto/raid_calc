import 'dart:io';

import 'calibration/boss_numbers.dart';
import 'calibration/calibration_runner.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  try {
    final sources = await _loadSources(options);
    final results = <BossNumbersSearchResult>[];
    for (var i = 0; i < sources.length; i++) {
      final result = await const BossNumbersCalibrator().evaluate(
        source: sources[i],
        runs: options.runs,
        top: options.top,
      );
      if (i > 0) stdout.writeln('');
      _printReport(result);
      results.add(result);
    }
    if (options.writeAfter) {
      final written = await const BossNumbersAfterWriter().write(
        results: results,
        afterDir: options.afterDir,
      );
      stdout.writeln('');
      stdout.writeln('Wrote Boss Numbers after artifacts:');
      for (final file in written) {
        stdout.writeln('- ${file.path}');
      }
    }
  } on Object catch (error, stackTrace) {
    stderr.writeln('Failed to calibrate boss numbers: $error');
    stderr.writeln(stackTrace);
    exitCode = 1;
  }
}

Future<List<BossNumberFile>> _loadSources(_CliOptions options) async {
  if (options.all) {
    final dir = Directory('assets/boss numbers');
    if (!dir.existsSync()) {
      throw StateError('assets/boss numbers does not exist.');
    }
    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    if (files.isEmpty) {
      throw StateError('No .json files found in assets/boss numbers.');
    }
    final sources = <BossNumberFile>[];
    for (final file in files) {
      sources.add(await BossNumberFile.load(file.path));
    }
    return sources;
  }
  return <BossNumberFile>[await BossNumberFile.load(options.filePath!)];
}

void _printReport(BossNumbersSearchResult result) {
  final source = result.source;
  final observed = result.observedStats;
  final observedSummary = observed.summary;

  stdout.writeln('Boss Numbers calibration');
  stdout.writeln('File: ${source.path}');
  stdout.writeln(
    'Context: ${source.mode.toUpperCase()} L${source.level} '
    '${source.bossElements.join('/')}',
  );
  stdout.writeln('Label: ${source.label}');
  stdout.writeln('Skill usage: ${source.setup.pet.skillUsage}');
  final appliedPetAtkBonus = result.preview.knights
      .fold<int>(0, (sum, knight) => sum + knight.petAtkBonus);
  final appliedPetDefBonus = result.preview.knights
      .fold<int>(0, (sum, knight) => sum + knight.petDefBonus);
  stdout.writeln(
    'Pet elemental bonus available: '
    'EA ${source.setup.pet.elementalAtk} / ED ${source.setup.pet.elementalDef}',
  );
  stdout.writeln(
    'Pet elemental bonus applied to setup: '
    'ATK +$appliedPetAtkBonus / DEF +$appliedPetDefBonus',
  );
  stdout.writeln('Observed samples: ${observedSummary.count}');
  stdout.writeln('Simulation runs per candidate: ${result.runs}');
  stdout.writeln('Candidate combinations: ${result.combinationsEvaluated}');
  stdout.writeln('');

  stdout.writeln('Observed score distribution');
  stdout.writeln(
    'min=${_fmtInt(observedSummary.min)} '
    'p10=${_fmtDouble(observedSummary.p10)} '
    'median=${_fmtDouble(observedSummary.median)} '
    'mean=${_fmtDouble(observedSummary.mean)} '
    'p90=${_fmtDouble(observedSummary.p90)} '
    'max=${_fmtInt(observedSummary.max)}',
  );
  stdout.writeln(
    'stdev=${_fmtDouble(observed.standardDeviation)} '
    'cv=${observed.coefficientOfVariationPercent.toStringAsFixed(2)}%',
  );
  stdout.writeln('');

  stdout.writeln('Top ${result.topResults.length} pet bar candidates');
  for (var i = 0; i < result.topResults.length; i++) {
    final item = result.topResults[i];
    final sim = item.simulated;
    stdout.writeln(
      '#${i + 1} '
      'accuracy=${item.accuracy.toStringAsFixed(2)}% '
      'loss=${item.loss.toStringAsFixed(6)} '
      'bias=${item.meanBiasPercent.toStringAsFixed(2)}%',
    );
    stdout.writeln('   ${_formatKnobs(item.knobs)}');
    stdout.writeln(
      '   sim p10=${_fmtDouble(sim.p10)} '
      'median=${_fmtDouble(sim.median)} '
      'mean=${_fmtDouble(sim.mean)} '
      'p90=${_fmtDouble(sim.p90)}',
    );
  }
  stdout.writeln('');
  stdout.writeln(
    'Note: accuracy is distribution-based and should be read against the '
    'observed natural variance (CV ${observed.coefficientOfVariationPercent.toStringAsFixed(2)}%).',
  );
  stdout.writeln(
    'This tool only reports candidate values; it does not modify pet_bar_rules.json.',
  );
}

String _formatKnobs(CalibrationKnobs knobs) {
  return 'ticksPerState=${knobs.ticksPerState} '
      'startTicks=${knobs.startTicks} '
      'petKnightBase=${knobs.petKnightFill} '
      'bossNormal=${knobs.bossNormalFill} '
      'bossSpecial=${knobs.bossSpecialFill} '
      'bossMiss=${knobs.bossMissFill} '
      'stun=${knobs.stunFill} '
      'petCrit+1=${knobs.petCritPlusOneProb}';
}

String _fmtInt(int value) => value.toString();

String _fmtDouble(double value) => value.toStringAsFixed(1);

void _printUsage() {
  stdout.writeln('Usage:');
  stdout.writeln(
    '  dart run tool/calibrate_boss_numbers.dart '
    '--file "assets/boss numbers/2026-04-17_raid_l4.json"',
  );
  stdout.writeln('');
  stdout.writeln('Options:');
  stdout.writeln('  --file <path>  Boss number JSON file to analyze.');
  stdout.writeln(
      '  --all          Analyze all JSON files in assets/boss numbers.');
  stdout
      .writeln('  --top <n>      Number of candidates to print. Default: 10.');
  stdout.writeln(
      '  --runs <n>     Simulation runs per candidate. Default: observed count.');
  stdout
      .writeln('  --write-after  Write per-file and aggregate JSON artifacts.');
  stdout.writeln(
    '  --after-dir <path>  Output directory. Default: assets/boss numbers after.',
  );
}

class _CliOptions {
  final String? filePath;
  final bool all;
  final int top;
  final int? runs;
  final bool writeAfter;
  final String afterDir;

  const _CliOptions({
    required this.filePath,
    required this.all,
    required this.top,
    required this.runs,
    required this.writeAfter,
    required this.afterDir,
  });

  static _CliOptions? parse(List<String> args) {
    String? filePath;
    var all = false;
    var top = 10;
    int? runs;
    var writeAfter = false;
    var afterDir = 'assets/boss numbers after';

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') {
        return null;
      }
      if (arg == '--file' && i + 1 < args.length) {
        filePath = args[++i];
        continue;
      }
      if (arg.startsWith('--file=')) {
        filePath = arg.substring('--file='.length);
        continue;
      }
      if (arg == '--all') {
        all = true;
        continue;
      }
      if (arg == '--top' && i + 1 < args.length) {
        top = int.tryParse(args[++i]) ?? top;
        continue;
      }
      if (arg.startsWith('--top=')) {
        top = int.tryParse(arg.substring('--top='.length)) ?? top;
        continue;
      }
      if (arg == '--runs' && i + 1 < args.length) {
        runs = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--runs=')) {
        runs = int.tryParse(arg.substring('--runs='.length));
        continue;
      }
      if (arg == '--write-after') {
        writeAfter = true;
        continue;
      }
      if (arg == '--after-dir' && i + 1 < args.length) {
        afterDir = args[++i];
        continue;
      }
      if (arg.startsWith('--after-dir=')) {
        afterDir = arg.substring('--after-dir='.length);
        continue;
      }
    }

    final normalizedFilePath = filePath?.trim();
    final hasFile = normalizedFilePath != null && normalizedFilePath.isNotEmpty;
    if (all == hasFile || top <= 0 || afterDir.trim().isEmpty) {
      return null;
    }
    if (runs != null && runs <= 0) {
      return null;
    }

    return _CliOptions(
      filePath: normalizedFilePath,
      all: all,
      top: top,
      runs: runs,
      writeAfter: writeAfter,
      afterDir: afterDir,
    );
  }
}
