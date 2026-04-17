import 'package:flutter_test/flutter_test.dart';

import '../tool/run_boss_sim_battery.dart' as battery_cli;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const enabled = bool.fromEnvironment('BOSS_SIM_ENABLE');

  test(
    'run configured boss simulation battery',
    () async {
      final args = <String>[];
      const runsPerScenario =
          String.fromEnvironment('BOSS_SIM_RUNS_PER_SCENARIO', defaultValue: '70');
      const outputDir =
          String.fromEnvironment('BOSS_SIM_OUTPUT', defaultValue: 'tool/sim_battery/out/full_run');
      const shardSize =
          String.fromEnvironment('BOSS_SIM_SHARD_SIZE', defaultValue: '10000');
      const checkpointEvery =
          String.fromEnvironment('BOSS_SIM_CHECKPOINT_EVERY', defaultValue: '100');
      const pauseEvery =
          String.fromEnvironment('BOSS_SIM_PAUSE_EVERY', defaultValue: '250');
      const pauseMs =
          String.fromEnvironment('BOSS_SIM_PAUSE_MS', defaultValue: '2000');
      const progressEvery =
          String.fromEnvironment('BOSS_SIM_PROGRESS_EVERY', defaultValue: '100');
      const maxScenarios =
          String.fromEnvironment('BOSS_SIM_MAX_SCENARIOS', defaultValue: '');

      if (const bool.fromEnvironment('BOSS_SIM_DRY_RUN')) {
        args.add('--dry-run');
      }
      if (const bool.fromEnvironment('BOSS_SIM_RESUME')) {
        args.add('--resume');
      }
      if (const bool.fromEnvironment('BOSS_SIM_CLEAN')) {
        args.add('--clean');
      }

      args
        ..add('--runs-per-scenario')
        ..add(runsPerScenario)
        ..add('--output')
        ..add(outputDir)
        ..add('--shard-size')
        ..add(shardSize)
        ..add('--checkpoint-every')
        ..add(checkpointEvery)
        ..add('--pause-every')
        ..add(pauseEvery)
        ..add('--pause-ms')
        ..add(pauseMs)
        ..add('--progress-every')
        ..add(progressEvery);

      if (maxScenarios.isNotEmpty) {
        args
          ..add('--max-scenarios')
          ..add(maxScenarios);
      }

      await battery_cli.main(args);
    },
    skip: !enabled,
    timeout: Timeout.none,
  );
}
