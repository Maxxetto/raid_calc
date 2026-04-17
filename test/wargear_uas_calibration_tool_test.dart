import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/wargear_universal_scoring.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

import '../tool/sim_battery/boss_sim_battery_config.dart';
import '../tool/sim_battery/boss_sim_battery_runner.dart';
import '../tool/sim_battery/wargear_uas_sample_audit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wargear UAS sample audit generates the expected sample coverage',
      () async {
    final outputDir = Directory('tool/sim_battery/out/uas_sample_audit_test');
    if (await outputDir.exists()) {
      await outputDir.delete(recursive: true);
    }

    final summary = await WargearUasSampleAuditRunner().run(
      outputDir: outputDir,
      runsPerScenario: 3,
    );

    expect(summary.sampleScenarioCount, 108);
    expect(summary.sensitivityScenarioCount, 288);
    expect(File('${outputDir.path}/uas_audit.json').existsSync(), isTrue);
    expect(
      File('${outputDir.path}/uas_correlation_by_mode_level.csv').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDir.path}/uas_correlation_by_mode_level_skill_usage.csv')
          .existsSync(),
      isTrue,
    );
    expect(
      File('${outputDir.path}/uas_sensitivity_marginals.csv').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDir.path}/uas_sensitivity_break_even.csv').existsSync(),
      isTrue,
    );
    expect(
      File('${outputDir.path}/uas_calibration_report.md').existsSync(),
      isTrue,
    );

    final audit = jsonDecode(
      await File('${outputDir.path}/uas_audit.json').readAsString(),
    ) as Map<String, dynamic>;
    final profiles = audit['profiles'] as Map<String, dynamic>;
    expect(
        (profiles['raid_L4'] as Map<String, dynamic>)['defenseWeight'], 1.16);
    expect((profiles['raid_L7'] as Map<String, dynamic>)['healthWeight'], 38.0);
    expect(
      (profiles['blitz_L6'] as Map<String, dynamic>)['bossAdvantageSlope'],
      0.22,
    );
    final primaryFactors = audit['primarySkillFactors'] as Map<String, dynamic>;
    expect(primaryFactors['elemental weakness'], 1.034);
    expect(primaryFactors['vampiric attack'], 0.997);
    expect(primaryFactors['soul burn'], 0.971);
    expect(
      audit['setupUasDefinition'],
      'setup UAS = sum of the 3 slot UAS values',
    );

    final sampleLines =
        await File('${outputDir.path}/uas_sample_scenarios.csv').readAsLines();
    expect(sampleLines.length, 109);
    final rows = sampleLines.skip(1).map((line) => line.split(',')).toList();
    final modeLevels = rows.map((row) => row[1]).toSet();
    final primarySkills = rows.map((row) => row[2]).toSet();
    final strategies = rows.map((row) => row[3]).toSet();
    final variants = rows.map((row) => row[4]).toSet();
    expect(modeLevels.length, 6);
    expect(primarySkills.length, 3);
    expect(strategies.length, 2);
    expect(variants, {'scenario_a', 'scenario_b', 'scenario_c'});

    final reportText = await File('${outputDir.path}/uas_calibration_report.md')
        .readAsString();
    expect(reportText, contains('Top-k agreement UAS vs mean damage'));
    expect(reportText, contains('Break-even locali'));

    final breakEvenText =
        await File('${outputDir.path}/uas_sensitivity_break_even.csv')
            .readAsString();
    expect(breakEvenText, contains('1% stun ~= X HP'));
    expect(breakEvenText, contains('1000 DEF ~= Z ATK'));
  });

  test('setup UAS is the sum of the three slot UAS values', () async {
    final catalog = await WargearWardrobeLoader.load();
    final base = BossSimulationConfig.defaultBattery(runsPerScenario: 1);
    final config = BossSimulationConfig(
      targets: const <BossSimulationModeLevel>[
        BossSimulationModeLevel(modeKey: 'raid', raidMode: true, bossLevel: 6),
      ],
      runsPerScenario: 1,
      layoutPermutations: const <List<WargearRole>>[
        <WargearRole>[
          WargearRole.primary,
          WargearRole.secondary,
          WargearRole.secondary,
        ],
      ],
      knightAdvantageVectors: const <List<double>>[
        <double>[1.5, 1.0, 2.0],
      ],
      bossAdvantageVectors: const <List<double>>[
        <double>[1.0, 1.5, 2.0],
      ],
      petUsageStrategies: const <BossSimulationPetStrategy>[
        BossSimulationPetStrategy(
          id: 's2_then_s1',
          label: '2, then always 1',
          usageMode: PetSkillUsageMode.special2ThenSpecial1,
        ),
      ],
      petPrimarySkills: const <String>['Elemental Weakness'],
      petSecondarySkill: base.petSecondarySkill,
      statTiers: const <BossSimulationStatTier>[
        BossSimulationStatTier(
          id: 'tier_4',
          bonusStats: WargearStats(attack: 50000, defense: 38000, health: 850),
        ),
      ],
      includeSwappedAttackDefenseVariant: false,
      randomization: base.randomization,
      petMatchByKnightSlot: base.petMatchByKnightSlot,
      petStrongVsBossByKnightSlot: base.petStrongVsBossByKnightSlot,
      petAttackResolutionPolicy: base.petAttackResolutionPolicy,
      petAdvantageMultiplier: base.petAdvantageMultiplier,
      knightStunChances: const <double>[3.0, 3.0, 3.0],
      captureTiming: false,
      exportAggregates: false,
      exportScores: false,
      retainAggregatesInMemory: true,
      retainScoresInMemory: true,
      exportShardSize: base.exportShardSize,
      checkpointEveryScenarios: base.checkpointEveryScenarios,
      pauseEveryScenarios: 0,
      pauseDurationMs: 0,
      maxScenarios: null,
      raidScoreProfile: base.raidScoreProfile,
      blitzScoreProfile: base.blitzScoreProfile,
    );

    final scenario = BossSimulationScenarioGenerator(
      config: config,
      catalog: catalog,
    ).generate().single;

    final runner = WargearUasSampleAuditRunner();
    final total = runner.computeSetupUas(
      scenario: scenario,
      knightStunChances: const <double>[3.0, 3.0, 3.0],
    );

    const engine = WargearUniversalScoringEngine();
    final strategy = config.petUsageStrategies.single;
    final manual = scenario.slotProfiles.fold<double>(0.0, (sum, slot) {
      return sum +
          engine
              .score(
                stats: slot.effectiveStatsBeforeRandomization,
                armorElements: const <ElementType>[
                  ElementType.fire,
                  ElementType.fire,
                ],
                context: WargearUniversalScoreContext(
                  bossMode: scenario.modeKey,
                  bossLevel: scenario.bossLevel,
                  bossElements: const <ElementType>[
                    ElementType.fire,
                    ElementType.fire,
                  ],
                  petElements: const <ElementType>[],
                  petElementalAttack: 0,
                  petElementalDefense: 0,
                  stunPercent: 3.0,
                  petSkillUsageMode: strategy.usageMode,
                  petPrimarySkillName: scenario.petPrimarySkill,
                  petSecondarySkillName: scenario.petSecondarySkill,
                  knightAdvantageOverride:
                      scenario.knightAdvantageVector[slot.slotIndex],
                  bossAdvantageOverride:
                      scenario.bossAdvantageVector[slot.slotIndex],
                ),
                variant: WargearUniversalScoreVariant.petAware,
              )
              .score;
    });

    expect(total, closeTo(manual, 1e-6));
  });
}
