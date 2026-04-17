import 'dart:io';

import 'sim_battery/wargear_uas_sample_audit.dart';

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options == null) {
    _printUsage();
    exitCode = 64;
    return;
  }

  final outputDir =
      Directory(options.outputDir ?? 'tool/sim_battery/out/uas_sample_audit');
  final summary = await WargearUasSampleAuditRunner().run(
    outputDir: outputDir,
    runsPerScenario: options.runsPerScenario,
  );

  stdout.writeln('Universal Armor Score sample audit');
  stdout.writeln('Output: ${summary.outputDir.path}');
  stdout.writeln('Runs per scenario: ${summary.runsPerScenario}');
  stdout.writeln('Sample scenarios: ${summary.sampleScenarioCount}');
  stdout.writeln('Sensitivity scenarios: ${summary.sensitivityScenarioCount}');
  for (final file in summary.generatedFiles) {
    stdout.writeln('Generated: $file');
  }
}

class _CliOptions {
  final String? outputDir;
  final int runsPerScenario;

  const _CliOptions({
    required this.outputDir,
    required this.runsPerScenario,
  });

  static _CliOptions? parse(List<String> args) {
    String? outputDir;
    var runsPerScenario = 100;

    for (var i = 0; i < args.length; i++) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') return null;
      if (arg == '--output' && i + 1 < args.length) {
        outputDir = args[++i];
        continue;
      }
      if (arg.startsWith('--output=')) {
        outputDir = arg.substring('--output='.length);
        continue;
      }
      if (arg == '--runs' && i + 1 < args.length) {
        runsPerScenario = int.tryParse(args[++i]) ?? runsPerScenario;
        continue;
      }
      if (arg.startsWith('--runs=')) {
        runsPerScenario =
            int.tryParse(arg.substring('--runs='.length)) ?? runsPerScenario;
        continue;
      }
    }

    return _CliOptions(
      outputDir: outputDir,
      runsPerScenario: runsPerScenario,
    );
  }
}

void _printUsage() {
  stdout.writeln(
    'Usage via Flutter test context: flutter test '
    'test/run_wargear_uas_calibration_entry_test.dart '
    '--dart-define=UAS_AUDIT_ENABLE=true '
    '[--dart-define=UAS_AUDIT_OUTPUT=<report-dir>] '
    '[--dart-define=UAS_AUDIT_RUNS=<runs-per-scenario>]',
  );
}
