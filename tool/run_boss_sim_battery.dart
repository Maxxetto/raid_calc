import 'dart:io';

import 'sim_battery/boss_sim_battery_config.dart';
import 'sim_battery/boss_sim_battery_models.dart';
import 'sim_battery/boss_sim_battery_runner.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final outputDir = Directory(options.outputDir);
  final manifestFile = File('${outputDir.path}/manifest.json');
  if (options.cleanOutput && await outputDir.exists()) {
    await outputDir.delete(recursive: true);
  }
  if (options.resume && !await manifestFile.exists()) {
    stderr.writeln(
      'Resume requested but manifest was not found: ${manifestFile.path}',
    );
    exitCode = 66;
    return;
  }
  if (!options.resume &&
      !options.cleanOutput &&
      await outputDir.exists() &&
      await _directoryHasEntries(outputDir)) {
    stderr.writeln(
      'Output directory is not empty. Use --clean to start fresh or --resume to continue.',
    );
    exitCode = 73;
    return;
  }

  final config = BossSimulationConfig.defaultBattery(
    runsPerScenario: options.runsPerScenario,
    maxScenarios: options.maxScenarios,
  ).copyWith(
    exportAggregates: true,
    exportScores: true,
    retainAggregatesInMemory: false,
    retainScoresInMemory: false,
    exportShardSize: options.exportShardSize,
    checkpointEveryScenarios: options.checkpointEveryScenarios,
    pauseEveryScenarios: options.pauseEveryScenarios,
    pauseDurationMs: options.pauseDurationMs,
  );

  final runner = BossSimulationRunner();

  stdout.writeln('Boss simulation battery');
  stdout.writeln('Output: ${outputDir.path}');
  stdout.writeln('Dry run: ${options.dryRun}');
  stdout.writeln('Resume: ${options.resume}');
  stdout.writeln('Runs per scenario: ${config.runsPerScenario}');
  stdout.writeln('Shard size: ${config.exportShardSize}');
  stdout.writeln('Checkpoint every: ${config.checkpointEveryScenarios}');
  if (config.pauseEveryScenarios > 0 && config.pauseDurationMs > 0) {
    stdout.writeln(
      'Pause policy: every ${config.pauseEveryScenarios} scenarios for ${config.pauseDurationMs} ms',
    );
  }
  stdout.writeln('');

  final result = await runner.run(
    config: config,
    outputDir: outputDir,
    dryRun: options.dryRun,
    resume: options.resume,
    progressEveryScenarios: options.progressEveryScenarios,
    onProgress: (progress) {
      stdout.writeln(_formatProgress(progress));
    },
  );

  stdout.writeln('');
  stdout.writeln('Done');
  stdout.writeln('Executed scenarios: ${result.executedScenarioCount}');
  stdout.writeln('Executed runs: ${result.executedRunCount}');
  stdout.writeln('Summary: ${outputDir.path}\\summary.json');
  stdout.writeln('Manifest: ${outputDir.path}\\manifest.json');
}

class _CliOptions {
  final String outputDir;
  final bool dryRun;
  final bool resume;
  final bool cleanOutput;
  final int runsPerScenario;
  final int exportShardSize;
  final int checkpointEveryScenarios;
  final int pauseEveryScenarios;
  final int pauseDurationMs;
  final int progressEveryScenarios;
  final int? maxScenarios;

  const _CliOptions({
    required this.outputDir,
    required this.dryRun,
    required this.resume,
    required this.cleanOutput,
    required this.runsPerScenario,
    required this.exportShardSize,
    required this.checkpointEveryScenarios,
    required this.pauseEveryScenarios,
    required this.pauseDurationMs,
    required this.progressEveryScenarios,
    required this.maxScenarios,
  });

  static _CliOptions? parse(List<String> args) {
    var outputDir = 'tool/sim_battery/out/full_run';
    var dryRun = false;
    var resume = false;
    var cleanOutput = false;
    var runsPerScenario = 100;
    var exportShardSize = 10000;
    var checkpointEveryScenarios = 100;
    var pauseEveryScenarios = 0;
    var pauseDurationMs = 0;
    var progressEveryScenarios = 100;
    int? maxScenarios;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') return null;
      if (arg == '--dry-run') {
        dryRun = true;
        continue;
      }
      if (arg == '--resume') {
        resume = true;
        continue;
      }
      if (arg == '--clean') {
        cleanOutput = true;
        continue;
      }
      if (arg == '--runs-per-scenario' && i + 1 < args.length) {
        runsPerScenario = int.tryParse(args[++i]) ?? runsPerScenario;
        continue;
      }
      if (arg.startsWith('--runs-per-scenario=')) {
        runsPerScenario =
            int.tryParse(arg.substring('--runs-per-scenario='.length)) ??
                runsPerScenario;
        continue;
      }
      if (arg == '--output' && i + 1 < args.length) {
        outputDir = args[++i];
        continue;
      }
      if (arg.startsWith('--output=')) {
        outputDir = arg.substring('--output='.length);
        continue;
      }
      if (arg == '--shard-size' && i + 1 < args.length) {
        exportShardSize = int.tryParse(args[++i]) ?? exportShardSize;
        continue;
      }
      if (arg.startsWith('--shard-size=')) {
        exportShardSize =
            int.tryParse(arg.substring('--shard-size='.length)) ??
                exportShardSize;
        continue;
      }
      if (arg == '--checkpoint-every' && i + 1 < args.length) {
        checkpointEveryScenarios =
            int.tryParse(args[++i]) ?? checkpointEveryScenarios;
        continue;
      }
      if (arg.startsWith('--checkpoint-every=')) {
        checkpointEveryScenarios =
            int.tryParse(arg.substring('--checkpoint-every='.length)) ??
                checkpointEveryScenarios;
        continue;
      }
      if (arg == '--pause-every' && i + 1 < args.length) {
        pauseEveryScenarios =
            int.tryParse(args[++i]) ?? pauseEveryScenarios;
        continue;
      }
      if (arg.startsWith('--pause-every=')) {
        pauseEveryScenarios =
            int.tryParse(arg.substring('--pause-every='.length)) ??
                pauseEveryScenarios;
        continue;
      }
      if (arg == '--pause-ms' && i + 1 < args.length) {
        pauseDurationMs = int.tryParse(args[++i]) ?? pauseDurationMs;
        continue;
      }
      if (arg.startsWith('--pause-ms=')) {
        pauseDurationMs =
            int.tryParse(arg.substring('--pause-ms='.length)) ?? pauseDurationMs;
        continue;
      }
      if (arg == '--progress-every' && i + 1 < args.length) {
        progressEveryScenarios =
            int.tryParse(args[++i]) ?? progressEveryScenarios;
        continue;
      }
      if (arg.startsWith('--progress-every=')) {
        progressEveryScenarios =
            int.tryParse(arg.substring('--progress-every='.length)) ??
                progressEveryScenarios;
        continue;
      }
      if (arg == '--max-scenarios' && i + 1 < args.length) {
        maxScenarios = int.tryParse(args[++i]);
        continue;
      }
      if (arg.startsWith('--max-scenarios=')) {
        maxScenarios =
            int.tryParse(arg.substring('--max-scenarios='.length));
        continue;
      }
    }

    return _CliOptions(
      outputDir: outputDir,
      dryRun: dryRun,
      resume: resume,
      cleanOutput: cleanOutput,
      runsPerScenario: runsPerScenario.clamp(1, 1000000),
      exportShardSize: exportShardSize.clamp(1, 1000000),
      checkpointEveryScenarios: checkpointEveryScenarios.clamp(1, 1000000),
      pauseEveryScenarios: pauseEveryScenarios.clamp(0, 1000000),
      pauseDurationMs: pauseDurationMs.clamp(0, 600000),
      progressEveryScenarios: progressEveryScenarios.clamp(1, 1000000),
      maxScenarios: maxScenarios,
    );
  }
}

String _formatProgress(BossSimulationProgress progress) {
  final scenarioPct = (progress.scenarioProgressFraction * 100).toStringAsFixed(3);
  final runPct = (progress.runProgressFraction * 100).toStringAsFixed(3);
  final eta = progress.eta == null ? 'n/a' : _formatDuration(progress.eta!);
  return '[progress] ${_progressBar(progress.scenarioProgressFraction)} '
      'scenarios ${progress.completedScenarios}/${progress.totalScenarios} '
      '($scenarioPct%) | runs ${progress.completedRuns}/${progress.totalRunsExpected} '
      '($runPct%) | shard ${progress.currentShardIndex} '
      '| elapsed ${_formatDuration(progress.elapsed)} | eta $eta'
      '${progress.currentScenarioId == null ? '' : ' | current ${progress.currentScenarioId}'}';
}

String _progressBar(double value) {
  const width = 24;
  final clamped = value.clamp(0.0, 1.0);
  final filled = (clamped * width).round();
  final buffer = StringBuffer('[');
  for (var index = 0; index < width; index++) {
    buffer.write(index < filled ? '#' : '-');
  }
  buffer.write(']');
  return buffer.toString();
}

String _formatDuration(Duration value) {
  final hours = value.inHours;
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${hours}h${minutes}m${seconds}s';
}

void _printUsage() {
  stdout.writeln(
    'Usage: dart run tool/run_boss_sim_battery.dart '
    '[--dry-run] [--resume] [--clean] [--runs-per-scenario <n>] [--output <dir>] '
    '[--max-scenarios <n>] [--shard-size <n>] [--checkpoint-every <n>] '
    '[--pause-every <n>] [--pause-ms <n>] [--progress-every <n>]',
  );
}

Future<bool> _directoryHasEntries(Directory dir) async {
  await for (final _ in dir.list(followLinks: false)) {
    return true;
  }
  return false;
}
