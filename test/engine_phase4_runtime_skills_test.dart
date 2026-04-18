import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/engine/battle_engine.dart';
import 'package:raid_calc/core/engine/engine_common.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';

Precomputed _buildPrecomputed({
  int bossHp = 100,
  double bossAttack = 0,
  double bossDefense = 1000,
  int knightHp = 100,
  double knightAttack = 0,
  double knightDefense = 1000,
  double petAtk = 0,
  PetSkillUsageMode usageMode = PetSkillUsageMode.special1Only,
  List<PetResolvedEffect> petEffects = const <PetResolvedEffect>[],
  PetTicksBarConfig petBar = const PetTicksBarConfig(),
  int knightToSpecial = 99,
  int bossToSpecial = 99,
  double evasionChance = 0.0,
  double critChance = 0.0,
  double stunChance = 0.0,
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
    timing: const TimingConfig(
      normalDuration: 0.4,
      specialDuration: 0.6,
      stunDuration: 0.2,
      missDuration: 0.3,
      bossDuration: 0.4,
      bossSpecialDuration: 0.7,
    ),
    petTicksBar: petBar,
  );

  final damageModel = DamageModel();
  return damageModel.precompute(
    boss: BossConfig(
      meta: bossMeta,
      stats: BossStats(
        attack: bossAttack,
        defense: bossDefense,
        hp: bossHp,
      ),
    ),
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

PetTicksBarConfig _instantSpecial1Bar({int ticksPerState = 1000}) =>
    PetTicksBarConfig(
      enabled: true,
      ticksPerState: ticksPerState,
      startTicks: ticksPerState,
      petKnightBase: const <WeightedTick>[WeightedTick(ticks: 1, weight: 1.0)],
      useInNormal: true,
    );

void main() {
  group('Phase 4 runtime skills', () {
    test('Death Blow stacks and is consumed on the next knight attack', () {
      final basePre = _buildPrecomputed(
        bossHp: 9999,
        knightAttack: 100,
        bossDefense: 1000,
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Death Blow',
            values: <String, num>{'bonusFlatDamage': 50},
            canonicalEffectId: 'death_blow',
            canonicalName: 'Death Blow',
            effectCategory: 'pet_attack_modifier',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{'bonusFlatDamage': 50},
          ),
        ],
        petBar: _instantSpecial1Bar(),
      );
      final expectedPoints =
          basePre.kNormalDmg[0] + basePre.kCritDmg[0] + 50;
      final pre = _buildPrecomputed(
        bossHp: expectedPoints,
        knightAttack: 100,
        bossDefense: 1000,
        petEffects: basePre.petEffects,
        petBar: _instantSpecial1Bar(),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(1),
      );

      expect(result.points, expectedPoints);
      expect(result.knightCritActions, 1);
      expect(result.petCastCount, 1);
    });

    test('Ready to Crit grants additive crit chance for multiple knight turns', () {
      final basePre = _buildPrecomputed(
        bossHp: 9999,
        knightAttack: 100,
        bossDefense: 1000,
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Ready to Crit',
            values: <String, num>{
              'critChancePercent': 100,
              'turns': 2,
            },
            canonicalEffectId: 'ready_to_crit',
            canonicalName: 'Ready to Crit',
            effectCategory: 'crit_chance_buff',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{},
          ),
        ],
        petBar: _instantSpecial1Bar(),
      );
      final expectedPoints = basePre.kNormalDmg[0] + (basePre.kCritDmg[0] * 2);
      final pre = _buildPrecomputed(
        bossHp: expectedPoints,
        knightAttack: 100,
        bossDefense: 1000,
        petEffects: basePre.petEffects,
        petBar: _instantSpecial1Bar(),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(2),
      );

      expect(result.points, expectedPoints);
      expect(result.knightCritActions, 2);
      expect(result.knightTurns, 3);
    });

    test('Shadow Slash casts and triggers an immediate pet hit', () {
      final pre = _buildPrecomputed(
        bossHp: 164,
        knightAttack: 0,
        petAtk: 0,
        bossDefense: 1000,
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Shadow Slash',
            values: <String, num>{'petAttack': 1000},
            canonicalEffectId: 'shadow_slash',
            canonicalName: 'Shadow Slash',
            effectCategory: 'pet_attack_fixed',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{},
          ),
        ],
        petBar: _instantSpecial1Bar(),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(3),
      );

      expect(result.bossDefeated, isTrue);
      expect(result.petCastCount, 1);
      expect(result.petBasicAttacks, 1);
      expect(result.points, 164);
    });

    test('Revenge Strike scales the immediate pet hit from lost knight HP', () {
      final basePre = _buildPrecomputed(
        bossHp: 9999,
        bossAttack: 500,
        knightHp: 100,
        knightAttack: 0,
        knightDefense: 1000,
        petAtk: 100,
        bossDefense: 1000,
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Revenge Strike',
            values: <String, num>{'petAttackCap': 200},
            canonicalEffectId: 'revenge_strike',
            canonicalName: 'Revenge Strike',
            effectCategory: 'pet_attack_scaling',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{},
          ),
        ],
        petBar: const PetTicksBarConfig(
          enabled: true,
          ticksPerState: 10,
          startTicks: 9,
          petKnightBase: <WeightedTick>[WeightedTick(ticks: 1, weight: 1.0)],
          useInNormal: true,
        ),
      );
      final hpAfterBossHit = 100 - bossDamage(
        basePre,
        0,
        crit: false,
        defMultiplier: 1.0,
      );
      final revengeAttack = 100 + ((200 - 100) * ((100 - hpAfterBossHit) / 100));
      final revengeDamage = petNormalDamageForAttack(
        basePre,
        attack: revengeAttack,
      );
      final expectedPoints = basePre.petNormalDmg + revengeDamage;
      final pre = _buildPrecomputed(
        bossHp: expectedPoints,
        bossAttack: 500,
        knightHp: 100,
        knightAttack: 0,
        knightDefense: 1000,
        petAtk: 100,
        bossDefense: 1000,
        petEffects: basePre.petEffects,
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
        FastRng(4),
      );

      expect(result.points, expectedPoints);
      expect(result.petCastCount, 1);
      expect(result.knightTurns, 2);
    });

    test('Soul Burn applies a non-stacking DoT after boss actions', () {
      final pre = _buildPrecomputed(
        bossHp: 15,
        bossAttack: 0,
        knightAttack: 0,
        petAtk: 0,
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Soul Burn',
            values: <String, num>{
              'damageOverTime': 5,
              'turns': 3,
            },
            canonicalEffectId: 'soul_burn',
            canonicalName: 'Soul Burn',
            effectCategory: 'damage_over_time',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{},
          ),
        ],
        petBar: _instantSpecial1Bar(),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(5),
      );

      expect(result.points, 15);
      expect(result.bossTurns, 3);
      expect(result.bossDefeated, isTrue);
    });

    test('Leech Strike heals based on actual damage dealt by the immediate hit', () {
      final pre = _buildPrecomputed(
        bossHp: 180,
        bossAttack: 500,
        knightHp: 100,
        knightAttack: 0,
        knightDefense: 1000,
        petAtk: 100,
        bossDefense: 1000,
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Leech Strike',
            values: <String, num>{
              'flatDamage': 1000,
              'stealPercent': 50,
            },
            canonicalEffectId: 'leech_strike',
            canonicalName: 'Leech Strike',
            effectCategory: 'life_steal_attack',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{},
          ),
        ],
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
        FastRng(6),
      );

      expect(result.bossDefeated, isTrue);
      expect(result.finalKnightHp, 100);
    });

    test('Fortune\'s Call grants gold when the boss dies after the cast', () {
      final pre = _buildPrecomputed(
        bossHp: 20,
        bossAttack: 0,
        knightAttack: 61,
        bossDefense: 1000,
        petAtk: 0,
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: "Fortune's Call",
            values: <String, num>{'goldDrop': 123},
            canonicalEffectId: 'fortunes_call',
            canonicalName: "Fortune's Call",
            effectCategory: 'unknown_support',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{},
          ),
        ],
        petBar: _instantSpecial1Bar(),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(7),
      );

      expect(result.bossDefeated, isTrue);
      expect(result.goldDropEnabled, isTrue);
      expect(result.goldDropped, 123);
    });
  });
}
