import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/run_boss_sim_battery.dart' as battery_cli;
import '../tool/sim_battery/boss_sim_battery_config.dart';
import '../tool/sim_battery/boss_sim_battery_runner.dart';
import 'run_boss_sim_battery_entry_test.dart' as battery_entry;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('boss simulation battery dry run enumerates full scenario space', () async {
    final config = BossSimulationConfig.defaultBattery();
    final runner = BossSimulationRunner();
    final result = await runner.run(
      config: config,
      outputDir: Directory('tool/sim_battery/out/dry_run'),
      dryRun: true,
    );

    stdout.writeln('Boss simulation battery dry run');
    stdout.writeln('Scenarios: ${result.summary.totalScenarios}');
    stdout.writeln('Runs expected: ${result.summary.totalRunsExpected}');
    stdout.writeln('By mode: ${result.summary.scenariosByMode}');
    stdout.writeln('By boss level: ${result.summary.scenariosByBossLevel}');
    stdout.writeln('By stat tier: ${result.summary.scenariosByStatTier}');
    stdout.writeln(
      'By pet primary skill: ${result.summary.scenariosByPetPrimarySkill}',
    );
    stdout.writeln('Sample scenario: ${result.summary.sampleScenario}');

    expect(result.summary.totalScenarios, 1102248);
    expect(result.summary.totalRunsExpected, 110224800);
    expect(result.summary.scenariosByMode['raid'], 551124);
    expect(result.summary.scenariosByMode['blitz'], 551124);
    expect(result.summary.scenariosByBossLevel['raid_L4'], 183708);
    expect(result.summary.scenariosByBossLevel['raid_L6'], 183708);
    expect(result.summary.scenariosByBossLevel['raid_L7'], 183708);
    expect(result.summary.scenariosByBossLevel['blitz_L4'], 183708);
    expect(result.summary.scenariosByBossLevel['blitz_L5'], 183708);
    expect(result.summary.scenariosByBossLevel['blitz_L6'], 183708);
    expect(result.summary.scenariosByStatTier['tier_1'], 157464);
    expect(result.summary.scenariosByStatTier['tier_7'], 157464);
    expect(
      result.summary.scenariosByPetPrimarySkill['Soul Burn'],
      367416,
    );
    expect(
      result.summary.scenariosByPetPrimarySkill['Vampiric Attack'],
      367416,
    );
    expect(
      result.summary.scenariosByPetPrimarySkill['Elemental Weakness'],
      367416,
    );
  });

  test('boss simulation battery executes and exports a limited real batch', () async {
    final outputDir = Directory('tool/sim_battery/out/smoke_test');
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }

    final config = BossSimulationConfig.defaultBattery(
      maxScenarios: 1,
    ).copyWith(
      retainAggregatesInMemory: true,
      retainScoresInMemory: true,
      exportShardSize: 1000,
      checkpointEveryScenarios: 1,
    );
    final runner = BossSimulationRunner();
    final result = await runner.run(
      config: config,
      outputDir: outputDir,
      dryRun: false,
    );

    stdout.writeln('Boss simulation battery smoke run');
    stdout.writeln('Executed scenarios: ${result.executedScenarioCount}');
    stdout.writeln('Executed runs: ${result.executedRunCount}');
    stdout.writeln('First aggregate: ${result.aggregates.first.toJson()}');
    stdout.writeln('First score: ${result.scores.first.toJson()}');

    expect(result.executedScenarioCount, 1);
    expect(result.executedRunCount, config.runsPerScenario);
    expect(result.aggregates, hasLength(1));
    expect(result.scores, hasLength(1));
    expect(File('${outputDir.path}/summary.json').existsSync(), isTrue);
    expect(File('${outputDir.path}/config.json').existsSync(), isTrue);
    expect(File('${outputDir.path}/manifest.json').existsSync(), isTrue);
    expect(
      File('${outputDir.path}/aggregates_0001.ndjson').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDir.path}/aggregates_0001.csv').existsSync(),
      isTrue,
    );
    expect(File('${outputDir.path}/scores_0001.ndjson').existsSync(), isTrue);
    expect(File('${outputDir.path}/scores_0001.csv').existsSync(), isTrue);
  });

  test('boss simulation battery can resume from manifest', () async {
    final outputDir = Directory('tool/sim_battery/out/resume_test');
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }

    final runner = BossSimulationRunner();
    final firstConfig = BossSimulationConfig.defaultBattery(
      maxScenarios: 1,
    ).copyWith(
      retainAggregatesInMemory: true,
      retainScoresInMemory: true,
      exportShardSize: 1000,
      checkpointEveryScenarios: 1,
    );
    final firstResult = await runner.run(
      config: firstConfig,
      outputDir: outputDir,
      dryRun: false,
    );

    expect(firstResult.executedScenarioCount, 1);
    expect(firstResult.executedRunCount, firstConfig.runsPerScenario);

    final resumedConfig = BossSimulationConfig.defaultBattery(
      maxScenarios: 2,
    ).copyWith(
      retainAggregatesInMemory: true,
      retainScoresInMemory: true,
      exportShardSize: 1000,
      checkpointEveryScenarios: 1,
    );
    final resumedResult = await runner.run(
      config: resumedConfig,
      outputDir: outputDir,
      dryRun: false,
      resume: true,
    );

    expect(resumedResult.executedScenarioCount, 2);
    expect(resumedResult.executedRunCount, resumedConfig.runsPerScenario * 2);

    final manifestText =
        await File('${outputDir.path}/manifest.json').readAsString();
    expect(manifestText.contains('"executedScenarios":2'), isTrue);

    final aggregateLines = await File('${outputDir.path}/aggregates_0001.ndjson')
        .readAsLines();
    expect(aggregateLines, hasLength(2));
  });

  test('boss simulation battery cli supports custom runs per scenario', () async {
    final outputDir = Directory('tool/sim_battery/out/cli_runs_test');
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }

    await battery_cli.main(<String>[
      '--clean',
      '--runs-per-scenario',
      '70',
      '--max-scenarios',
      '1',
      '--output',
      outputDir.path,
    ]);

    final configText = await File('${outputDir.path}/config.json').readAsString();
    final manifestText = await File('${outputDir.path}/manifest.json').readAsString();
    expect(configText.contains('"runsPerScenario":70'), isTrue);
    expect(manifestText.contains('"executedRuns":70'), isTrue);
  });

  test('boss simulation battery flutter test entrypoint is loadable', () {
    expect(battery_entry.main, isNotNull);
  });
}
