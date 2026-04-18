import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/debug/debug_hooks.dart';
import 'package:raid_calc/core/engine/battle_engine.dart';
import 'package:raid_calc/core/engine/battle_runtime_effects.dart';
import 'package:raid_calc/core/engine/battle_state.dart';
import 'package:raid_calc/core/engine/pet_usage_policy.dart';
import 'package:raid_calc/core/engine/skill_handlers.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';

Precomputed _buildPrecomputed({
  int bossHp = 100,
  double bossAttack = 0,
  double bossDefense = 1000,
  List<int> knightHp = const <int>[100],
  List<double> knightAttack = const <double>[0],
  List<double> knightDefense = const <double>[1000],
  List<double> knightStun = const <double>[0],
  double petAtk = 0,
  PetSkillUsageMode usageMode = PetSkillUsageMode.special1Only,
  List<PetResolvedEffect> petEffects = const <PetResolvedEffect>[],
  PetTicksBarConfig petBar = const PetTicksBarConfig(),
  int knightToSpecial = 99,
  int bossToSpecial = 99,
  double evasionChance = 0.0,
  double critChance = 0.0,
}) {
  final count = knightHp.length;

  List<T> normalized<T>(List<T> values) {
    if (values.length == count) return values;
    if (values.isEmpty) {
      throw ArgumentError('Knight value list cannot be empty.');
    }
    return List<T>.filled(count, values.last, growable: false);
  }

  final bossMeta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: List<double>.filled(count, 1.0, growable: false),
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
    defaultElementalWeakness: 0.5,
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

  return DamageModel().precompute(
    boss: BossConfig(
      meta: bossMeta,
      stats: BossStats(
        attack: bossAttack,
        defense: bossDefense,
        hp: bossHp,
      ),
    ),
    kAtk: normalized<double>(knightAttack),
    kDef: normalized<double>(knightDefense),
    kHp: knightHp,
    kAdv: List<double>.filled(count, 1.0, growable: false),
    kStun: normalized<double>(knightStun),
    petAtk: petAtk,
    petAdv: 1.0,
    petSkillUsage: usageMode,
    petEffects: petEffects,
  );
}

void _castSkill(
  BattleState state,
  BattleRuntimeSkillState runtime,
  PetSpecialCastKind cast,
) {
  final dispatchPlan = BattleSkillHandlerRegistry.buildDispatchPlan(
    state.skillDefinitions,
    cast,
  );
  runtime.onPetCast(
    battleState: state,
    dispatchPlan: dispatchPlan,
    activeKnightIndex: state.activeKnightIndex,
  );
}

void main() {
  group('Phase 9 effect-based suite', () {
    test('pet usage policy returns the canonical cast sequences', () {
      final special1Only = PetUsagePolicy.fromSkillUsage(
        PetSkillUsageMode.special1Only,
      );
      final special2Only = PetUsagePolicy.fromSkillUsage(
        PetSkillUsageMode.special2Only,
      );
      final cycle = PetUsagePolicy.fromSkillUsage(
        PetSkillUsageMode.cycleSpecial1Then2,
      );
      final special2ThenSpecial1 = PetUsagePolicy.fromSkillUsage(
        PetSkillUsageMode.special2ThenSpecial1,
      );
      final doubleSpecial2ThenSpecial1 = PetUsagePolicy.fromSkillUsage(
        PetSkillUsageMode.doubleSpecial2ThenSpecial1,
      );

      expect(
        List<PetSpecialCastKind>.generate(
          4,
          special1Only.nextCastForIndex,
        ),
        <PetSpecialCastKind>[
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
        ],
      );
      expect(
        List<PetSpecialCastKind>.generate(
          4,
          special2Only.nextCastForIndex,
        ),
        <PetSpecialCastKind>[
          PetSpecialCastKind.special2,
          PetSpecialCastKind.special2,
          PetSpecialCastKind.special2,
          PetSpecialCastKind.special2,
        ],
      );
      expect(
        List<PetSpecialCastKind>.generate(4, cycle.nextCastForIndex),
        <PetSpecialCastKind>[
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special2,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special2,
        ],
      );
      expect(
        List<PetSpecialCastKind>.generate(
          5,
          special2ThenSpecial1.nextCastForIndex,
        ),
        <PetSpecialCastKind>[
          PetSpecialCastKind.special2,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
        ],
      );
      expect(
        List<PetSpecialCastKind>.generate(
          5,
          doubleSpecial2ThenSpecial1.nextCastForIndex,
        ),
        <PetSpecialCastKind>[
          PetSpecialCastKind.special2,
          PetSpecialCastKind.special2,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
        ],
      );
    });

    test('override value 0 disables the skill in dispatch planning', () {
      const effect = PetResolvedEffect(
        sourceSlotId: 'skill11',
        sourceSkillName: 'Elemental Weakness',
        values: <String, num>{
          'enemyAttackReductionPercent': 50,
          'turns': 2,
        },
        canonicalEffectId: 'elemental_weakness',
        canonicalName: 'Elemental Weakness',
        effectCategory: 'boss_attack_debuff',
        dataSupport: 'structured_values',
        runtimeSupport: 'mode_specific',
        simulatorModes: <String>['specialRegenPlusEw'],
        effectSpec: <String, Object?>{},
      );
      final pre = _buildPrecomputed(
        petEffects: const <PetResolvedEffect>[effect],
      );
      final loadout = PetLoadoutSnapshot(
        slot1: const PetLoadoutSlotSelection(
          slotId: 'skill11',
          skillName: 'Elemental Weakness',
          canonicalEffectId: 'elemental_weakness',
          values: <String, num>{
            'enemyAttackReductionPercent': 50,
            'turns': 2,
          },
          overrideValues: <String, num>{'turns': 0},
        ),
        slot2: null,
        usageMode: PetSkillUsageMode.special1Only,
        resolvedEffects: const <PetResolvedEffect>[effect],
      );

      final seed = BattleEngineSeed.fromLoadoutSnapshot(
        pre: pre,
        loadout: loadout,
      );
      final engine = const RaidBlitzBattleEngine();
      final skills = engine.resolveSkills(seed);
      final dispatchPlan = BattleSkillHandlerRegistry.buildDispatchPlan(
        skills,
        PetSpecialCastKind.special1,
      );

      expect(skills, hasLength(1));
      expect(skills.single.isDisabledByOverride, isTrue);
      expect(dispatchPlan.matchedSkills, isEmpty);
    });

    test('Cyclone turns override raises the effective stack cap', () {
      const effect = PetResolvedEffect(
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
      );
      final pre = _buildPrecomputed(
        petEffects: const <PetResolvedEffect>[effect],
      );
      final loadout = PetLoadoutSnapshot(
        slot1: null,
        slot2: const PetLoadoutSlotSelection(
          slotId: 'skill2',
          skillName: 'Cyclone Earth Boost',
          canonicalEffectId: 'cyclone_boost_earth',
          values: <String, num>{
            'attackBoostPercent': 71,
            'turns': 5,
          },
          overrideValues: <String, num>{'turns': 7},
        ),
        usageMode: PetSkillUsageMode.special2Only,
        resolvedEffects: const <PetResolvedEffect>[effect],
      );

      final engine = const RaidBlitzBattleEngine();
      final state = engine.createInitialState(
        BattleEngineSeed.fromLoadoutSnapshot(
          pre: pre,
          loadout: loadout,
        ),
      );
      final runtime = BattleRuntimeSkillState(knightCount: state.knights.length);
      final dispatchPlan = BattleSkillHandlerRegistry.buildDispatchPlan(
        state.skillDefinitions,
        PetSpecialCastKind.special2,
      );

      expect(state.maxCycloneStacks, 7);
      for (int i = 0; i < 10; i++) {
        state.advanceActionIndex();
        runtime.onPetCast(
          battleState: state,
          dispatchPlan: dispatchPlan,
          activeKnightIndex: state.activeKnightIndex,
        );
      }

      expect(runtime.cycloneStackCount, 7);
    });

    test('SR infinite and EW coexist in the same battle state', () {
      final pre = _buildPrecomputed(
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Elemental Weakness',
            values: <String, num>{
              'enemyAttackReductionPercent': 50,
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
            sourceSkillName: 'Special Regeneration (inf)',
            values: <String, num>{},
            canonicalEffectId: 'special_regeneration_infinite',
            canonicalName: 'Special Regeneration (inf)',
            effectCategory: 'knight_special_charge',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegen'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );
      final state = const RaidBlitzBattleEngine().createInitialState(
        BattleEngineSeed(
          pre: pre,
          runtimeKnobs: const BattleRuntimeKnobs(
            knightPetElementMatches: <bool>[true],
          ),
        ),
      );
      final runtime = BattleRuntimeSkillState(knightCount: state.knights.length);

      _castSkill(state, runtime, PetSpecialCastKind.special2);
      _castSkill(state, runtime, PetSpecialCastKind.special1);

      expect(runtime.specialRegenInfiniteStacks, 2);
      expect(runtime.bossOutgoingDamageMultiplier(), 0.5);
      expect(
        runtime.shouldForceKnightSpecial(
          state,
          activeKnightIndex: state.activeKnightIndex,
        ),
        isTrue,
      );
    });

    test('Cyclone and EW coexist when always-gem is off', () {
      final pre = _buildPrecomputed(
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Elemental Weakness',
            values: <String, num>{
              'enemyAttackReductionPercent': 50,
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
      final state =
          const RaidBlitzBattleEngine().createInitialState(BattleEngineSeed(pre: pre));
      final runtime = BattleRuntimeSkillState(knightCount: state.knights.length);

      _castSkill(state, runtime, PetSpecialCastKind.special2);
      _castSkill(state, runtime, PetSpecialCastKind.special1);

      expect(runtime.cycloneStackCount, 1);
      expect(runtime.boostKnightDamage(100), greaterThan(100));
      expect(runtime.bossOutgoingDamageMultiplier(), 0.5);
    });

    test('special2 then special1 sequence is respected by the real loop', () {
      final pre = _buildPrecomputed(
        bossHp: 999999,
        bossAttack: 500,
        bossDefense: 1000,
        knightHp: const <int>[200, 200],
        knightAttack: const <double>[0, 0],
        knightDefense: const <double>[1000, 1000],
        petAtk: 100,
        usageMode: PetSkillUsageMode.special2ThenSpecial1,
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
          PetResolvedEffect(
            sourceSlotId: 'skill2',
            sourceSkillName: 'Special Regeneration (inf)',
            values: <String, num>{},
            canonicalEffectId: 'special_regeneration_infinite',
            canonicalName: 'Special Regeneration (inf)',
            effectCategory: 'knight_special_charge',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegen'],
            effectSpec: <String, Object?>{},
          ),
        ],
        petBar: const PetTicksBarConfig(
          enabled: true,
          ticksPerState: 1,
          startTicks: 1,
          petKnightBase: <WeightedTick>[WeightedTick(ticks: 1, weight: 1.0)],
          bossNormal: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
          bossSpecial: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
          bossMiss: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
          stun: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
          useInNormal: true,
        ),
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(42),
      );

      expect(result.petCastSequence, hasLength(greaterThanOrEqualTo(3)));
      expect(
        result.petCastSequence.take(3).toList(),
        <PetSpecialCastKind>[
          PetSpecialCastKind.special2,
          PetSpecialCastKind.special1,
          PetSpecialCastKind.special1,
        ],
      );
    });
  });
}
