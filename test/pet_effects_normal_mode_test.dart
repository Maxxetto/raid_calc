import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/engine/engine.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';

void main() {
  int runEngine(Precomputed pre) => const RaidBlitzBattleEngine()
      .runWithRng(BattleEngineSeed(pre: pre), FastRng(123456))
      .points;

  Precomputed buildPrecomputed({
    required int bossHp,
    required double petAtk,
    required PetSkillUsageMode skillUsage,
    required List<PetResolvedEffect> effects,
    double bossAttack = 1000,
    int petBarStartTicks = 165,
    int bossNormalDmg = 1,
    int bossCritDmg = 2,
  }) {
    final pre = Precomputed(
      meta: BossMeta(
        raidMode: true,
        level: 1,
        advVsKnights: const <double>[1.0, 1.0, 1.0],
        evasionChance: 0.0,
        criticalChance: 0.0,
        criticalMultiplier: 1.5,
        raidSpecialMultiplier: 3.25,
        hitsToFirstShatter: 7,
        hitsToNextShatter: 13,
        knightToSpecial: 5,
        bossToSpecial: 6,
        bossToSpecialFakeEW: 1000,
        knightToSpecialSR: 7,
        knightToRecastSpecialSR: 13,
        knightToSpecialSREW: 7,
        knightToRecastSpecialSREW: 13,
        hitsToElementalWeakness: 7,
        durationElementalWeakness: 2,
        defaultElementalWeakness: 0.65,
        cyclone: 71,
        
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
        petTicksBar: PetTicksBarConfig(
          enabled: true,
          useInNormal: true,
          ticksPerState: 165,
          startTicks: petBarStartTicks,
        ),
      ),
      stats: BossStats(attack: bossAttack, defense: 1000, hp: bossHp),
      kAtk: const <double>[1000, 1000, 1000],
      kDef: const <double>[1000, 1000, 1000],
      kHp: const <int>[1000, 1000, 1000],
      kAdv: const <double>[1, 1, 1],
      kStun: const <double>[0, 0, 0],
      petAtk: petAtk,
      petAdv: 1,
      petSkillUsage: skillUsage,
      petEffects: effects,
      kNormalDmg: const <int>[100, 100, 100],
      kCritDmg: const <int>[200, 200, 200],
      kSpecialDmg: const <int>[300, 300, 300],
      petNormalDmg: 0,
      petCritDmg: 0,
      bNormalDmg: <int>[bossNormalDmg, bossNormalDmg, bossNormalDmg],
      bCritDmg: <int>[bossCritDmg, bossCritDmg, bossCritDmg],
    );
    return Precomputed(
      meta: pre.meta,
      stats: pre.stats,
      kAtk: pre.kAtk,
      kDef: pre.kDef,
      kHp: pre.kHp,
      kAdv: pre.kAdv,
      kStun: pre.kStun,
      petAtk: pre.petAtk,
      petAdv: pre.petAdv,
      petSkillUsage: pre.petSkillUsage,
      petEffects: pre.petEffects,
      kNormalDmg: pre.kNormalDmg,
      kCritDmg: pre.kCritDmg,
      kSpecialDmg: pre.kSpecialDmg,
      petNormalDmg: petAtk <= 0 ? 0 : petNormalDamageForAttack(pre, attack: petAtk),
      petCritDmg: petAtk <= 0 ? 0 : petCritDamageForAttack(pre, attack: petAtk),
      bNormalDmg: pre.bNormalDmg,
      bCritDmg: pre.bCritDmg,
    );
  }

  test('normal loop applies Death Blow on first queued special1 cast', () {
    final pre = buildPrecomputed(
      bossHp: 950,
      petAtk: 0,
      skillUsage: PetSkillUsageMode.special1Only,
      effects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Death Blow',
          values: <String, num>{},
          canonicalEffectId: 'death_blow',
          canonicalName: 'Death Blow',
          effectCategory: 'pet_attack_modifier',
          dataSupport: 'description_only',
          runtimeSupport: 'none',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{'bonusFlatDamage': 750},
        ),
      ],
    );

    final points = runEngine(pre);

    expect(points, 1050);
  });

  test('normal loop uses Shadow Slash on the next pet attack after pet cast', () {
    final pre = buildPrecomputed(
      bossHp: 692,
      petAtk: 1000,
      skillUsage: PetSkillUsageMode.special1Only,
      effects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Shadow Slash',
          values: <String, num>{'petAttack': 3000},
          canonicalEffectId: 'shadow_slash',
          canonicalName: 'Shadow Slash',
          effectCategory: 'pet_attack_fixed',
          dataSupport: 'structured_values',
          runtimeSupport: 'none',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{'attackValueKey': 'petAttack'},
        ),
      ],
    );

    final points = runEngine(pre);

    expect(points, 692);
  });

  test('normal loop uses Revenge Strike scaled pet attack after pet cast', () {
    final pre = buildPrecomputed(
      bossHp: 953,
      petAtk: 4000,
      skillUsage: PetSkillUsageMode.special2Only,
      bossAttack: 5000,
      petBarStartTicks: 330,
      bossNormalDmg: 600,
      bossCritDmg: 600,
      effects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill2',
          sourceSkillName: 'Revenge Strike',
          values: <String, num>{'petAttackCap': 6000},
          canonicalEffectId: 'revenge_strike',
          canonicalName: 'Revenge Strike',
          effectCategory: 'pet_attack_scaling',
          dataSupport: 'structured_values',
          runtimeSupport: 'none',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{'attackCapValueKey': 'petAttackCap'},
        ),
      ],
    );

    final points = runEngine(pre);

    expect(points, 1512);
  });

  test('normal loop applies Ready to Crit for the configured knight turns', () {
    final pre = buildPrecomputed(
      bossHp: 400,
      petAtk: 0,
      skillUsage: PetSkillUsageMode.special1Only,
      effects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Ready to Crit',
          values: <String, num>{'critChancePercent': 100, 'turns': 2},
          canonicalEffectId: 'ready_to_crit',
          canonicalName: 'Ready to Crit',
          effectCategory: 'crit_chance_buff',
          dataSupport: 'structured_values',
          runtimeSupport: 'none',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{
            'critChanceValueKey': 'critChancePercent',
            'turnsValueKey': 'turns',
          },
        ),
      ],
    );

    final points = runEngine(pre);

    expect(points, 500);
  });

  test('normal loop applies Special Regeneration cadence boost for 5 turns', () {
    final pre = buildPrecomputed(
      bossHp: 1100,
      petAtk: 0,
      skillUsage: PetSkillUsageMode.special1Only,
      effects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Special Regeneration',
          values: <String, num>{'meterChargePercent': 101.5},
          canonicalEffectId: 'special_regeneration',
          canonicalName: 'Special Regeneration',
          effectCategory: 'special_meter_acceleration',
          dataSupport: 'structured_values',
          runtimeSupport: 'mode_specific',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{},
        ),
      ],
      petBarStartTicks: 165,
    );

    final points = runEngine(pre);

    expect(points, 1200);
  });

  test('normal loop applies Soul Burn direct damage plus boss-action DOT', () {
    final pre = buildPrecomputed(
      bossHp: 1100,
      petAtk: 0,
      skillUsage: PetSkillUsageMode.special1Only,
      effects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Soul Burn',
          values: <String, num>{
            'flatDamage': 500,
            'damageOverTime': 200,
            'turns': 3,
          },
          canonicalEffectId: 'soul_burn',
          canonicalName: 'Soul Burn',
          effectCategory: 'damage_over_time',
          dataSupport: 'structured_values',
          runtimeSupport: 'none',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{
            'directDamageValueKey': 'flatDamage',
            'dotDamageValueKey': 'damageOverTime',
            'turnsValueKey': 'turns',
          },
        ),
      ],
    );

    final points = runEngine(pre);

    expect(points, 1100);
  });

  test('normal loop applies Vampiric Attack damage and healing', () {
    final pre = buildPrecomputed(
      bossHp: 1300,
      petAtk: 0,
      skillUsage: PetSkillUsageMode.special2Only,
      bossAttack: 5000,
      petBarStartTicks: 330,
      bossNormalDmg: 300,
      bossCritDmg: 300,
      effects: const <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill2',
          sourceSkillName: 'Vampiric Attack',
          values: <String, num>{
            'flatDamage': 900,
            'stealPercent': 10,
          },
          canonicalEffectId: 'vampiric_attack',
          canonicalName: 'Vampiric Attack',
          effectCategory: 'lifesteal_attack',
          dataSupport: 'structured_values',
          runtimeSupport: 'none',
          simulatorModes: <String>[],
          effectSpec: <String, Object?>{
            'directDamageValueKey': 'flatDamage',
            'lifestealPercentValueKey': 'stealPercent',
          },
        ),
      ],
    );

    final points = runEngine(pre);

    expect(points, 948);
  });
}
