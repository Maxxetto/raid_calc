import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/engine/engine.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';

Precomputed _buildPrecomputed({
  int bossHp = 200,
  double bossAttack = 0,
  double bossDefense = 1000,
  int knightHp = 200,
  double knightAttack = 1000,
  double knightDefense = 1000,
  double petAtk = 100,
  PetSkillUsageMode usageMode = PetSkillUsageMode.special1Only,
  List<PetResolvedEffect> petEffects = const <PetResolvedEffect>[],
}) {
  final bossMeta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const <double>[1.0],
    evasionChance: 0.0,
    criticalChance: 0.0,
    criticalMultiplier: 1.5,
    raidSpecialMultiplier: 3.25,
    hitsToFirstShatter: 7,
    hitsToNextShatter: 13,
    knightToSpecial: 4,
    bossToSpecial: 99,
    bossToSpecialFakeEW: 99,
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
    petTicksBar: const PetTicksBarConfig(
      enabled: true,
      ticksPerState: 10,
      startTicks: 9,
      petKnightBase: <WeightedTick>[WeightedTick(ticks: 1, weight: 1.0)],
      bossNormal: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      bossSpecial: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      bossMiss: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      stun: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      useInNormal: true,
    ),
  );

  return DamageModel().precompute(
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
    kStun: const <double>[0.0],
    petAtk: petAtk,
    petAdv: 1.0,
    petSkillUsage: usageMode,
    petEffects: petEffects,
  );
}

Precomputed _copyWithPetConfig(
  Precomputed pre, {
  required PetSkillUsageMode petSkillUsage,
  required List<PetResolvedEffect> petEffects,
}) {
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
    petSkillUsage: petSkillUsage,
    petEffects: petEffects,
    kNormalDmg: pre.kNormalDmg,
    kCritDmg: pre.kCritDmg,
    kSpecialDmg: pre.kSpecialDmg,
    petNormalDmg: pre.petNormalDmg,
    petCritDmg: pre.petCritDmg,
    bNormalDmg: pre.bNormalDmg,
    bCritDmg: pre.bCritDmg,
  );
}

void main() {
  group('Phase 7 damage model integration', () {
    const shatter = ShatterShieldConfig(
      baseHp: 25,
      bonusHp: 5,
      elementMatch: <bool>[true],
      strongElementEw: <bool>[false],
    );

    test('legacy Special Regeneration mode is bridged into the new engine', () async {
      final pre = _buildPrecomputed();
      final synthetic = LegacyModeAdapter.synthesize(
        mode: FightMode.specialRegen,
        requestedUsageMode: pre.petSkillUsage,
        cycloneUseGemsForSpecials: false,
        cycloneBoostPercent: pre.meta.cyclone,
        shatterBaseHp: shatter.baseHp,
        shatterBonusHp: shatter.bonusHp,
        drsDefenseBoost: pre.meta.defaultDurableRockShield,
        ewWeaknessEffect: pre.meta.defaultElementalWeakness,
      );
      final bridgedPre = _copyWithPetConfig(
        pre,
        petSkillUsage: synthetic.usageMode,
        petEffects: synthetic.resolvedEffects,
      );
      final expected = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(
          pre: bridgedPre,
          runtimeKnobs: const BattleRuntimeKnobs(
            knightPetElementMatches: <bool>[true],
            petStrongVsBossByKnight: <bool>[false],
          ),
        ),
        FastRng(123),
      );

      final stats = await DamageModel().simulate(
        pre,
        runs: 1,
        mode: FightMode.specialRegen,
        shatter: shatter,
        withTiming: false,
        cycloneUseGemsForSpecials: false,
      );

      expect(stats.mean, expected.points);
      expect(stats.median, expected.points);
    });

    test('old simulator keeps using the legacy runner', () async {
      final pre = _buildPrecomputed(
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
        ],
      );
      final expected = runLegacyOldSimulator(
        pre,
        FastRng(123),
        withTiming: false,
        timing: null,
      );

      final stats = await DamageModel().simulate(
        pre,
        runs: 1,
        mode: FightMode.specialRegenEw,
        shatter: shatter,
        withTiming: false,
      );

      expect(stats.mean, expected);
      expect(stats.median, expected);
    });
  });
}
