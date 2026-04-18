import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/epic_simulator.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';

void main() {
  TimingConfig timing() => const TimingConfig(
        normalDuration: 0.4,
        specialDuration: 0.6,
        stunDuration: 0.2,
        missDuration: 0.3,
        bossDuration: 0.4,
        bossSpecialDuration: 0.7,
      );

  BossMeta meta() => BossMeta(
        raidMode: true,
        level: 1,
        advVsKnights: const [1.0, 1.0],
        evasionChance: 0.0,
        criticalChance: 0.0,
        criticalMultiplier: 1.5,
        raidSpecialMultiplier: 1.0,
        hitsToFirstShatter: 7,
        hitsToNextShatter: 13,
        knightToSpecial: 99,
        bossToSpecial: 1,
        bossToSpecialFakeEW: 1000,
        knightToSpecialSR: 7,
        knightToRecastSpecialSR: 13,
        knightToSpecialSREW: 7,
        knightToRecastSpecialSREW: 13,
        hitsToElementalWeakness: 7,
        durationElementalWeakness: 2,
        defaultElementalWeakness: 0.65,
        cyclone: 71.0,
        defaultDurableRockShield: 0.5,
        sameElementDRS: 1.6,
        strongElementEW: 1.6,
        hitsToDRS: 7,
        durationDRS: 3,
        cycleMultiplier: 1.0,
        epicBossDamageBonus: 0.25,
        timing: timing(),
      );

  test('Epic threshold simulation increments knights and handles missing',
      () async {
    final table = <int, EpicBossRow>{
      1: const EpicBossRow(
        level: 1,
        attack: 1000000000,
        defense: 1,
        hp: 1000,
      ),
      2: const EpicBossRow(
        level: 2,
        attack: 1000000000,
        defense: 1,
        hp: 1000000000,
      ),
    };

    final knights = <EpicKnight>[
      const EpicKnight(
        atk: 1000,
        def: 1,
        hp: 1,
        adv: 1.0,
        stun: 0.0,
        elementMatch: false,
      ),
      const EpicKnight(
        atk: 1000,
        def: 1,
        hp: 1,
        adv: 1.0,
        stun: 0.0,
        elementMatch: false,
      ),
    ];

    final res = await EpicSimulator.runThresholdSimulation(
      table: table,
      meta: meta(),
      knights: knights,
      threshold: 80,
      runsPerLevel: 5,
      shatter: const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: [false, false],
      ),
      cycloneUseGemsForSpecials: false,
    );

    final l1 = res.levels.firstWhere((e) => e.level == 1);
    final l2 = res.levels.firstWhere((e) => e.level == 2);
    final l3 = res.levels.firstWhere((e) => e.level == 3);

    expect(l1.missing, isFalse);
    expect(l1.winRates[0], 1.0);
    expect(l1.knightsUsed, 1);

    expect(l2.missing, isFalse);
    expect(l2.winRates[0], 0.0);
    expect(l2.winRates[1], isNotNull);
    expect(l2.knightsUsed, 2);

    expect(l3.missing, isTrue);
    expect(l3.winRates[0], isNull);
  });

  test('Epic SR uses pet-match stacks for infinite special', () async {
    final srMeta = BossMeta(
      raidMode: true,
      level: 1,
      advVsKnights: const [1.0, 1.0],
      evasionChance: 0.0,
      criticalChance: 0.0,
      criticalMultiplier: 1.5,
      raidSpecialMultiplier: 3.25,
      hitsToFirstShatter: 7,
      hitsToNextShatter: 13,
      knightToSpecial: 99,
      bossToSpecial: 999,
      bossToSpecialFakeEW: 999,
      knightToSpecialSR: 1,
      knightToRecastSpecialSR: 13,
      knightToSpecialSREW: 1,
      knightToRecastSpecialSREW: 13,
      hitsToElementalWeakness: 7,
      durationElementalWeakness: 2,
      defaultElementalWeakness: 0.65,
      cyclone: 71.0,
      defaultDurableRockShield: 0.5,
      sameElementDRS: 1.6,
      strongElementEW: 1.6,
      hitsToDRS: 7,
      durationDRS: 3,
      cycleMultiplier: 1.0,
      epicBossDamageBonus: 0.0,
      timing: timing(),
      petTicksBar: const PetTicksBarConfig(
        enabled: true,
        ticksPerState: 1,
        startTicks: 1,
        petCritPlusOneProb: 0.0,
        petKnightBase: <WeightedTick>[WeightedTick(ticks: 1, weight: 1.0)],
        bossNormal: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        bossSpecial: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        bossMiss: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        stun: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        useInSpecialRegen: true,
        useInEpic: true,
      ),
    );

    const boss = EpicBossRow(
      level: 1,
      attack: 1,
      defense: 1,
      hp: 400,
    );

    const knights = <EpicKnight>[
      EpicKnight(
        atk: 1,
        def: 1,
        hp: 150,
        adv: 1.0,
        stun: 0.0,
        elementMatch: true,
      ),
    ];

    final pre = EpicSimulator.precompute(
      boss: boss,
      meta: srMeta,
      knights: knights,
      petSkillUsage: PetSkillUsageMode.special1Only,
      petEffects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Special Regeneration',
          values: <String, num>{'meterChargePercent': 100},
          canonicalEffectId: 'special_regeneration_infinite',
          canonicalName: 'Special Regeneration',
          effectCategory: 'special_meter_acceleration',
          dataSupport: 'test',
          runtimeSupport: 'test',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{},
        ),
      ],
    );

    final winWithMatch = await EpicSimulator.simulateLevel(
      pre: pre,
      shatter: const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: [true],
      ),
      cycloneUseGemsForSpecials: false,
      runs: 1,
      seed: 1,
    );

    final loseWithoutMatch = await EpicSimulator.simulateLevel(
      pre: pre,
      shatter: const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: [false],
      ),
      cycloneUseGemsForSpecials: false,
      runs: 1,
      seed: 1,
    );

    expect(winWithMatch.winRate, 1.0);
    expect(loseWithoutMatch.winRate, 0.0);
  });

  test('Epic DRS pet bar respects pet skill usage policy', () async {
    final drsMeta = BossMeta(
      raidMode: true,
      level: 1,
      advVsKnights: const [1.0],
      evasionChance: 0.0,
      criticalChance: 0.0,
      criticalMultiplier: 1.5,
      raidSpecialMultiplier: 1.0,
      hitsToFirstShatter: 7,
      hitsToNextShatter: 13,
      knightToSpecial: 999,
      bossToSpecial: 999,
      bossToSpecialFakeEW: 999,
      knightToSpecialSR: 7,
      knightToRecastSpecialSR: 13,
      knightToSpecialSREW: 7,
      knightToRecastSpecialSREW: 13,
      hitsToElementalWeakness: 7,
      durationElementalWeakness: 2,
      defaultElementalWeakness: 0.65,
      cyclone: 71.0,
      defaultDurableRockShield: 0.5,
      sameElementDRS: 1.6,
      strongElementEW: 1.6,
      hitsToDRS: 99,
      durationDRS: 3,
      cycleMultiplier: 1.0,
      epicBossDamageBonus: 0.0,
      timing: timing(),
      petTicksBar: const PetTicksBarConfig(
        enabled: true,
        ticksPerState: 2,
        startTicks: 2,
        petCritPlusOneProb: 0.0,
        petKnightBase: <WeightedTick>[
          WeightedTick(ticks: 2, weight: 1.0),
        ],
        bossNormal: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        bossSpecial: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        bossMiss: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        stun: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        useInDurableRockShield: true,
        useInEpic: true,
      ),
    );

    const boss = EpicBossRow(
      level: 1,
      attack: 1500,
      defense: 1000,
      hp: 30,
    );

    const knights = <EpicKnight>[
      EpicKnight(
        atk: 100,
        def: 1000,
        hp: 50,
        adv: 1.0,
        stun: 0.0,
        elementMatch: true,
      ),
    ];

    final preSpecial1 = EpicSimulator.precompute(
      boss: boss,
      meta: drsMeta,
      knights: knights,
      petSkillUsage: PetSkillUsageMode.special1Only,
      petEffects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Durable Rock Shield',
          values: <String, num>{
            'defenseBoostPercent': 50,
            'turns': 3,
          },
          canonicalEffectId: 'durable_rock_shield',
          canonicalName: 'Durable Rock Shield',
          effectCategory: 'knight_defense_buff',
          dataSupport: 'test',
          runtimeSupport: 'test',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{},
        ),
      ],
    );
    final preSpecial2 = EpicSimulator.precompute(
      boss: boss,
      meta: drsMeta,
      knights: knights,
      petSkillUsage: PetSkillUsageMode.special2Only,
      petEffects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Durable Rock Shield',
          values: <String, num>{
            'defenseBoostPercent': 50,
            'turns': 3,
          },
          canonicalEffectId: 'durable_rock_shield',
          canonicalName: 'Durable Rock Shield',
          effectCategory: 'knight_defense_buff',
          dataSupport: 'test',
          runtimeSupport: 'test',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{},
        ),
      ],
    );

    const shatter = ShatterShieldConfig(
      baseHp: 0,
      bonusHp: 0,
      elementMatch: [true],
    );

    final winWithSpecial1 = await EpicSimulator.simulateLevel(
      pre: preSpecial1,
      shatter: shatter,
      cycloneUseGemsForSpecials: false,
      runs: 1,
      seed: 1,
    );

    final loseWithSpecial2 = await EpicSimulator.simulateLevel(
      pre: preSpecial2,
      shatter: shatter,
      cycloneUseGemsForSpecials: false,
      runs: 1,
      seed: 1,
    );

    expect(winWithSpecial1.winRate, 1.0);
    expect(loseWithSpecial2.winRate, 0.0);
  });

  test(
      'Epic explicit pet skills use the unified skill-driven engine',
      () async {
    final drsMeta = BossMeta(
      raidMode: true,
      level: 1,
      advVsKnights: const [1.0],
      evasionChance: 0.0,
      criticalChance: 0.0,
      criticalMultiplier: 1.5,
      raidSpecialMultiplier: 1.0,
      hitsToFirstShatter: 7,
      hitsToNextShatter: 13,
      knightToSpecial: 999,
      bossToSpecial: 999,
      bossToSpecialFakeEW: 999,
      knightToSpecialSR: 7,
      knightToRecastSpecialSR: 13,
      knightToSpecialSREW: 7,
      knightToRecastSpecialSREW: 13,
      hitsToElementalWeakness: 7,
      durationElementalWeakness: 2,
      defaultElementalWeakness: 0.65,
      cyclone: 71.0,
      defaultDurableRockShield: 0.5,
      sameElementDRS: 1.6,
      strongElementEW: 1.6,
      hitsToDRS: 99,
      durationDRS: 3,
      cycleMultiplier: 1.0,
      epicBossDamageBonus: 0.0,
      timing: timing(),
      petTicksBar: const PetTicksBarConfig(
        enabled: true,
        ticksPerState: 2,
        startTicks: 2,
        petCritPlusOneProb: 0.0,
        petKnightBase: <WeightedTick>[
          WeightedTick(ticks: 2, weight: 1.0),
        ],
        bossNormal: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        bossSpecial: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        bossMiss: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        stun: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
        useInDurableRockShield: true,
        useInEpic: true,
      ),
    );

    const boss = EpicBossRow(
      level: 1,
      attack: 1500,
      defense: 1000,
      hp: 30,
    );

    const knights = <EpicKnight>[
      EpicKnight(
        atk: 100,
        def: 1000,
        hp: 50,
        adv: 1.0,
        stun: 0.0,
        elementMatch: true,
      ),
    ];

    const drsEffect = PetResolvedEffect(
      sourceSlotId: 'skill11',
      sourceSkillName: 'Durable Rock Shield',
      values: <String, num>{
        'defenseBoostPercent': 50,
        'turns': 3,
      },
      canonicalEffectId: 'durable_rock_shield',
      canonicalName: 'Durable Rock Shield',
      effectCategory: 'knight_defense_buff',
      dataSupport: 'structured_values',
      runtimeSupport: 'mode_specific',
      simulatorModes: <String>['durableRockShield'],
      effectSpec: <String, Object?>{},
    );

    final preSpecial1 = EpicSimulator.precompute(
      boss: boss,
      meta: drsMeta,
      knights: knights,
      petSkillUsage: PetSkillUsageMode.special1Only,
      petEffects: const <PetResolvedEffect>[drsEffect],
    );
    final preSpecial2 = EpicSimulator.precompute(
      boss: boss,
      meta: drsMeta,
      knights: knights,
      petSkillUsage: PetSkillUsageMode.special2Only,
      petEffects: const <PetResolvedEffect>[drsEffect],
    );

    const shatter = ShatterShieldConfig(
      baseHp: 0,
      bonusHp: 0,
      elementMatch: [true],
    );

    final winWithSkills = await EpicSimulator.simulateLevel(
      pre: preSpecial1,
      shatter: shatter,
      cycloneUseGemsForSpecials: false,
      runs: 1,
      seed: 1,
    );

    final loseWithWrongUsage = await EpicSimulator.simulateLevel(
      pre: preSpecial2,
      shatter: shatter,
      cycloneUseGemsForSpecials: false,
      runs: 1,
      seed: 1,
    );

    expect(winWithSkills.winRate, 1.0);
    expect(loseWithWrongUsage.winRate, 0.0);
  });
}
