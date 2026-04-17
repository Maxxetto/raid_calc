import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/engine/battle_engine.dart';
import 'package:raid_calc/core/engine/battle_state.dart';
import 'package:raid_calc/core/engine/skill_catalog.dart';
import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/debug/debug_hooks.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/core/timing_acc.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';

Precomputed _buildPrecomputed({
  int bossHp = 100,
  double bossAttack = 0,
  double bossDefense = 1000,
  int knightHp = 100,
  double knightAttack = 1000,
  double knightDefense = 1000,
  double petAtk = 0,
  PetSkillUsageMode usageMode = PetSkillUsageMode.special1Only,
  List<PetResolvedEffect> petEffects = const <PetResolvedEffect>[],
  PetTicksBarConfig petBar = const PetTicksBarConfig(),
  int knightToSpecial = 5,
  int bossToSpecial = 6,
  double evasionChance = 0.0,
  double critChance = 0.0,
  double stunChance = 0.0,
  TimingConfig timing = const TimingConfig(
    normalDuration: 0.4,
    specialDuration: 0.6,
    stunDuration: 0.2,
    missDuration: 0.3,
    bossDuration: 0.4,
    bossSpecialDuration: 0.7,
  ),
}) {
  final bossMeta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const <double>[1.0],
    evasionChance: evasionChance,
    criticalChance: critChance,
    criticalMultiplier: 1.5,
    raidSpecialMultiplier: 3.25,
    hitsToFirstShatter: 7,
    hitsToNextShatter: 13,
    knightToSpecial: knightToSpecial,
    bossToSpecial: bossToSpecial,
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
    timing: timing,
    petTicksBar: petBar,
  );
  final bossStats = BossStats(
    attack: bossAttack,
    defense: bossDefense,
    hp: bossHp,
  );

  final damageModel = DamageModel();
  return damageModel.precompute(
    boss: BossConfig(meta: bossMeta, stats: bossStats),
    kAtk: <double>[knightAttack],
    kDef: <double>[knightDefense],
    kHp: <int>[knightHp],
    kAdv: const <double>[1.0],
    kStun: <double>[stunChance],
    petAtk: petAtk,
    petAdv: 1.0,
    petSkillUsage: usageMode,
    petEffects: petEffects,
  );
}

void main() {
  group('Phase 3 raid/blitz engine loop', () {
    test('uses the canonical normal loop without pet effects', () {
      final pre = _buildPrecomputed(
        bossHp: 150,
        bossAttack: 200,
        bossDefense: 1000,
        knightHp: 120,
        knightAttack: 1000,
        knightDefense: 1000,
        petAtk: 0,
        evasionChance: 0.0,
        critChance: 0.0,
        bossToSpecial: 3,
        knightToSpecial: 2,
      );

      final seed = BattleEngineSeed(pre: pre);
      final newRng = FastRng(12345);
      final result = const RaidBlitzBattleEngine().runWithRng(
        seed,
        newRng,
        withTiming: false,
      );

      expect(result.points, 164);
    });

    test('pet bar queues special1 on next knight turn and suppresses pet basic',
        () {
      final pre = _buildPrecomputed(
        bossHp: 35,
        bossAttack: 0,
        bossDefense: 1640,
        knightHp: 200,
        knightAttack: 100,
        knightDefense: 1000,
        petAtk: 0,
        knightToSpecial: 99,
        bossToSpecial: 99,
        petBar: const PetTicksBarConfig(
          enabled: true,
          ticksPerState: 10,
          startTicks: 9,
          petKnightBase: <WeightedTick>[WeightedTick(ticks: 1, weight: 1.0)],
          useInNormal: true,
        ),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(1),
      );

      expect(result.petCastCount, 1);
      expect(result.petSpecial1Casts, 1);
      expect(result.petCastSequence, <PetSpecialCastKind>[
        PetSpecialCastKind.special1,
      ]);
      expect(result.petBasicAttacks, 2);
      expect(result.knightTurns, 4);
    });

    test('cyclone always-gem overrides usage and forces specials every turn',
        () {
      final pre = _buildPrecomputed(
        bossHp: 45,
        bossAttack: 0,
        bossDefense: 1640,
        knightHp: 200,
        knightAttack: 100,
        knightDefense: 1000,
        petAtk: 0,
        knightToSpecial: 99,
        bossToSpecial: 99,
        usageMode: PetSkillUsageMode.special1Only,
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Elemental Weakness',
            values: <String, num>{
              'enemyAttackReductionPercent': 65,
              'turns': 2,
            },
            canonicalEffectId: 'elemental_weakness',
            canonicalName: 'Elemental Weakness',
            effectCategory: 'boss_attack_debuff',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegenPlusEw'],
            effectSpec: <String, Object?>{},
          ),
          PetResolvedEffect(
            sourceSlotId: 'skill2',
            sourceSkillName: 'Cyclone Earth Boost',
            values: <String, num>{
              'attackBoostPercent': 71,
              'turns': 5,
            },
            canonicalEffectId: 'cyclone_boost_earth',
            canonicalName: 'Cyclone Boost',
            effectCategory: 'knight_attack_buff',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['cycloneBoost'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final loadout = PetLoadoutSnapshot(
        slot1: const PetLoadoutSlotSelection(
          slotId: 'skill11',
          skillName: 'Elemental Weakness',
          canonicalEffectId: 'elemental_weakness',
          values: <String, num>{
            'enemyAttackReductionPercent': 65,
            'turns': 2,
          },
        ),
        slot2: const PetLoadoutSlotSelection(
          slotId: 'skill2',
          skillName: 'Cyclone Earth Boost',
          canonicalEffectId: 'cyclone_boost_earth',
          values: <String, num>{
            'attackBoostPercent': 71,
            'turns': 5,
          },
        ),
        usageMode: PetSkillUsageMode.special1Only,
        resolvedEffects: pre.petEffects,
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed.fromLoadoutSnapshot(
          pre: pre,
          loadout: loadout,
          runtimeKnobs: const BattleRuntimeKnobs(
            cycloneAlwaysGemEnabled: true,
          ),
        ),
        FastRng(7),
      );

      expect(result.cycloneAlwaysGemApplied, isTrue);
      expect(result.knightSpecialActions, result.knightTurns);
      expect(result.petBasicAttacks, 0);
      expect(
        result.petCastSequence.every(
          (cast) => cast == PetSpecialCastKind.special2,
        ),
        isTrue,
      );
      expect(
        BattleSkillCatalog.normalizeCanonicalEffectId('cyclone_boost_earth'),
        BattleSkillCatalog.cycloneId,
      );
    });

    test('dead knight is removed from battle and cannot keep acting forever',
        () {
      final pre = _buildPrecomputed(
        bossHp: 100000,
        bossAttack: 100000,
        bossDefense: 1000,
        knightHp: 100,
        knightAttack: 100,
        knightDefense: 1000,
        petAtk: 0,
        evasionChance: 0.0,
        critChance: 0.0,
        bossToSpecial: 99,
        knightToSpecial: 99,
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(123),
      );

      expect(result.knightsDefeated, isTrue);
      expect(result.finalKnightIndex, -1);
      expect(result.finalKnightHp, isNull);
      expect(result.knightTurns, lessThanOrEqualTo(2));
      expect(result.points, lessThan(pre.stats.hp));
    });

    test('boss miss timing uses bossDuration instead of missDuration', () {
      final pre = _buildPrecomputed(
        bossHp: 400,
        bossAttack: 0,
        bossDefense: 1000,
        knightHp: 300,
        knightAttack: 1000,
        knightDefense: 1000,
        petAtk: 0,
        evasionChance: 1.0, // boss always misses
        critChance: 0.0,
        bossToSpecial: 99,
        knightToSpecial: 99,
        timing: const TimingConfig(
          normalDuration: 0.3,
          specialDuration: 0.5,
          stunDuration: 0.4,
          missDuration: 0.9,
          bossDuration: 0.2,
          bossSpecialDuration: 0.5,
        ),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(1234),
        withTiming: true,
        timing: TimingAcc(),
      );

      final timing = result.timing!;
      expect(timing.bMissCount[0], greaterThan(0));
      expect(
        timing.bMissSeconds[0],
        closeTo(timing.bMissCount[0] * 0.2, 1e-9),
      );
    });

    test('successful stun contributes stun timing duration', () {
      final pre = _buildPrecomputed(
        bossHp: 400,
        bossAttack: 0,
        bossDefense: 1000,
        knightHp: 300,
        knightAttack: 1000,
        knightDefense: 1000,
        petAtk: 0,
        evasionChance: 0.0,
        critChance: 0.0,
        stunChance: 1.0, // every eligible turn stuns
        bossToSpecial: 99,
        knightToSpecial: 99,
        timing: const TimingConfig(
          normalDuration: 0.3,
          specialDuration: 0.5,
          stunDuration: 0.4,
          missDuration: 0.3,
          bossDuration: 0.2,
          bossSpecialDuration: 0.5,
        ),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(4321),
        withTiming: true,
        timing: TimingAcc(),
      );

      final timing = result.timing!;
      expect(timing.kStunCount[0], greaterThan(0));
      expect(
        timing.kStunSeconds[0],
        closeTo(timing.kStunCount[0] * 0.4, 1e-9),
      );
    });
  });
}
