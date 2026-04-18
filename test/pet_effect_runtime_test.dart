import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/debug/debug_hooks.dart';
import 'package:raid_calc/core/engine/engine_common.dart';
import 'package:raid_calc/core/pet_effect_runtime.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';

void main() {
  group('PetEffectRuntimeState', () {
    Precomputed buildPrecomputed({
      List<PetResolvedEffect> effects = const <PetResolvedEffect>[],
      int normal = 100,
      int crit = 200,
      int special = 300,
      double criticalChance = 0.0,
      double evasionChance = 0.0,
    }) {
      return Precomputed(
        meta: BossMeta(
          raidMode: true,
          level: 1,
          advVsKnights: const <double>[1.0, 1.0, 1.0],
          evasionChance: evasionChance,
          criticalChance: criticalChance,
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
        ),
        stats: const BossStats(attack: 1000, defense: 1000, hp: 1000),
        kAtk: const <double>[1000, 1000, 1000],
        kDef: const <double>[1000, 1000, 1000],
        kHp: const <int>[1000, 1000, 1000],
        kAdv: const <double>[1, 1, 1],
        kStun: const <double>[0, 0, 0],
        kNormalDmg: <int>[normal, normal, normal],
        kCritDmg: <int>[crit, crit, crit],
        kSpecialDmg: <int>[special, special, special],
        bNormalDmg: const <int>[1, 1, 1],
        bCritDmg: const <int>[2, 2, 2],
        petEffects: effects,
      );
    }

    test('applies Death Blow on the next normal hit after matching pet cast', () {
      const effect = PetResolvedEffect(
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
      );
      final pre = buildPrecomputed(effects: const <PetResolvedEffect>[effect]);
      final state = PetEffectRuntimeState.fromPrecomputed(
        pre,
        knightCount: 3,
      );
      final rng = FastRng(123456);

      state.onPetCast(
        cast: PetSpecialCastKind.special1,
        activeKnightIndex: 0,
      );
      final result = state.resolveKnightAttack(
        pre,
        rng,
        kIdx: 0,
        doSpecial: false,
        evadePermil: (pre) => 0,
        critPermil: (pre) => 0,
      );

      expect(result.action, DebugAction.crit);
      expect(result.damage, 950);
      expect(result.deathBlowApplied, isTrue);
      expect(result.deathBlowConsumed, isTrue);
    });

    test('consumes Death Blow on miss without preserving it', () {
      const effect = PetResolvedEffect(
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
      );
      final pre = buildPrecomputed(effects: const <PetResolvedEffect>[effect]);
      final state = PetEffectRuntimeState.fromPrecomputed(
        pre,
        knightCount: 3,
      );
      final rng = FastRng(123456);

      state.onPetCast(
        cast: PetSpecialCastKind.special1,
        activeKnightIndex: 0,
      );
      final missed = state.resolveKnightAttack(
        pre,
        rng,
        kIdx: 0,
        doSpecial: false,
        evadePermil: (pre) => 1000,
        critPermil: (pre) => 0,
      );
      final next = state.resolveKnightAttack(
        pre,
        rng,
        kIdx: 0,
        doSpecial: false,
        evadePermil: (pre) => 0,
        critPermil: (pre) => 0,
      );

      expect(missed.action, DebugAction.miss);
      expect(missed.deathBlowConsumed, isTrue);
      expect(next.action, DebugAction.normal);
      expect(next.damage, 100);
      expect(next.deathBlowApplied, isFalse);
    });

    test('consumes Death Blow on special without applying crit bonus', () {
      const effect = PetResolvedEffect(
        sourceSlotId: 'skill2',
        sourceSkillName: 'Death Blow',
        values: <String, num>{},
        canonicalEffectId: 'death_blow',
        canonicalName: 'Death Blow',
        effectCategory: 'pet_attack_modifier',
        dataSupport: 'description_only',
        runtimeSupport: 'none',
        simulatorModes: <String>[],
        effectSpec: <String, Object?>{'bonusFlatDamage': 750},
      );
      final pre = buildPrecomputed(effects: const <PetResolvedEffect>[effect]);
      final state = PetEffectRuntimeState.fromPrecomputed(
        pre,
        knightCount: 3,
      );
      final rng = FastRng(123456);

      state.onPetCast(
        cast: PetSpecialCastKind.special2,
        activeKnightIndex: 1,
      );
      final special = state.resolveKnightAttack(
        pre,
        rng,
        kIdx: 1,
        doSpecial: true,
        evadePermil: (pre) => 0,
        critPermil: (pre) => 0,
      );
      final next = state.resolveKnightAttack(
        pre,
        rng,
        kIdx: 1,
        doSpecial: false,
        evadePermil: (pre) => 0,
        critPermil: (pre) => 0,
      );

      expect(special.action, DebugAction.special);
      expect(special.damage, 300);
      expect(special.deathBlowConsumed, isTrue);
      expect(next.action, DebugAction.normal);
      expect(next.damage, 100);
    });

    test('Shadow Slash overrides the next pet attack to the fixed ATK value', () {
      const effect = PetResolvedEffect(
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
      );
      final pre = buildPrecomputed(
        effects: const <PetResolvedEffect>[effect],
      );
      final state = PetEffectRuntimeState.fromPrecomputed(
        pre.copyWithPetAttack(1000),
        knightCount: 3,
      );
      final rng = FastRng(123456);

      state.onPetCast(
        cast: PetSpecialCastKind.special1,
        activeKnightIndex: 0,
      );
      final pet = state.resolvePetAttack(
        pre.copyWithPetAttack(1000),
        rng,
        activeKnightIndex: 0,
        currentKnightHp: 1000,
      );

      expect(pet.missed, isFalse);
      expect(pet.damage, 492);

      final next = state.resolvePetAttack(
        pre.copyWithPetAttack(1000),
        rng,
        activeKnightIndex: 0,
        currentKnightHp: 1000,
      );
      expect(next.damage, 164);
    });

    test('Revenge Strike scales next pet attack by current knight HP lost', () {
      const effect = PetResolvedEffect(
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
      );
      final pre = buildPrecomputed(
        effects: const <PetResolvedEffect>[effect],
      ).copyWithPetAttack(4000);
      final state = PetEffectRuntimeState.fromPrecomputed(
        pre,
        knightCount: 3,
      );
      final rng = FastRng(123456);

      state.onPetCast(
        cast: PetSpecialCastKind.special2,
        activeKnightIndex: 0,
      );
      final pet = state.resolvePetAttack(
        pre,
        rng,
        activeKnightIndex: 0,
        currentKnightHp: 400,
      );

      expect(pet.missed, isFalse);
      expect(pet.damage, 853);
    });

    test('Ready to Crit boosts crit chance for the configured knight turns', () {
      const effect = PetResolvedEffect(
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
      );
      final pre = buildPrecomputed(effects: const <PetResolvedEffect>[effect]);
      final state = PetEffectRuntimeState.fromPrecomputed(
        pre,
        knightCount: 3,
      );
      final rng = FastRng(123456);

      state.onPetCast(
        cast: PetSpecialCastKind.special1,
        activeKnightIndex: 0,
      );
      final first = state.resolveKnightAttack(
        pre,
        rng,
        kIdx: 0,
        doSpecial: false,
        evadePermil: (pre) => 0,
        critPermil: (pre) => 0,
      );
      final second = state.resolveKnightAttack(
        pre,
        rng,
        kIdx: 0,
        doSpecial: false,
        evadePermil: (pre) => 0,
        critPermil: (pre) => 0,
      );
      final third = state.resolveKnightAttack(
        pre,
        rng,
        kIdx: 0,
        doSpecial: false,
        evadePermil: (pre) => 0,
        critPermil: (pre) => 0,
      );

      expect(first.action, DebugAction.crit);
      expect(first.damage, 200);
      expect(first.critTarget, 1000);
      expect(second.action, DebugAction.crit);
      expect(second.damage, 200);
      expect(second.critTarget, 1000);
      expect(third.action, DebugAction.normal);
      expect(third.damage, 100);
      expect(third.critTarget, 0);
    });

    test('Soul Burn applies direct damage and then three boss-action DOT ticks', () {
      const effect = PetResolvedEffect(
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
      );
      final pre = buildPrecomputed(effects: const <PetResolvedEffect>[effect]);
      final state = PetEffectRuntimeState.fromPrecomputed(
        pre,
        knightCount: 3,
      );

      final resolution = state.onPetCast(
        cast: PetSpecialCastKind.special1,
        activeKnightIndex: 0,
      );
      final tick1 = state.onBossActionResolved();
      final tick2 = state.onBossActionResolved();
      final tick3 = state.onBossActionResolved();
      final tick4 = state.onBossActionResolved();

      expect(resolution.immediateBossDamage, 500);
      expect(resolution.knightHealPercentOfActualDamage, 0);
      expect(tick1, 200);
      expect(tick2, 200);
      expect(tick3, 200);
      expect(tick4, 0);
    });

    test('Vampiric Attack exposes direct damage and heal percent on cast', () {
      const effect = PetResolvedEffect(
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
      );
      final pre = buildPrecomputed(effects: const <PetResolvedEffect>[effect]);
      final state = PetEffectRuntimeState.fromPrecomputed(
        pre,
        knightCount: 3,
      );

      final resolution = state.onPetCast(
        cast: PetSpecialCastKind.special2,
        activeKnightIndex: 1,
      );

      expect(resolution.immediateBossDamage, 900);
      expect(resolution.knightHealPercentOfActualDamage, 10);
    });
  });
}

extension on Precomputed {
  Precomputed copyWithPetAttack(double petAttack) {
    return Precomputed(
      meta: meta,
      stats: stats,
      kAtk: kAtk,
      kDef: kDef,
      kHp: kHp,
      kAdv: kAdv,
      kStun: kStun,
      petAtk: petAttack,
      petAdv: petAdv,
      petSkillUsage: petSkillUsage,
      petEffects: petEffects,
      kNormalDmg: kNormalDmg,
      kCritDmg: kCritDmg,
      kSpecialDmg: kSpecialDmg,
      petNormalDmg: petNormalDamageForAttack(this, attack: petAttack),
      petCritDmg: petCritDamageForAttack(this, attack: petAttack),
      bNormalDmg: bNormalDmg,
      bCritDmg: bCritDmg,
    );
  }
}
