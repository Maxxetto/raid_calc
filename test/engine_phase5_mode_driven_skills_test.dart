import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/debug/debug_hooks.dart';
import 'package:raid_calc/core/engine/battle_engine.dart';
import 'package:raid_calc/core/engine/battle_runtime_effects.dart';
import 'package:raid_calc/core/engine/battle_state.dart';
import 'package:raid_calc/core/engine/engine_common.dart';
import 'package:raid_calc/core/engine/skill_handlers.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';

Precomputed _buildPrecomputed({
  int bossHp = 100,
  double bossAttack = 0,
  double bossDefense = 1000,
  List<int> knightHp = const <int>[100],
  List<double> knightAttack = const <double>[100],
  List<double> knightDefense = const <double>[1000],
  List<double> knightStun = const <double>[0],
  double petAtk = 0,
  PetSkillUsageMode usageMode = PetSkillUsageMode.special1Only,
  List<PetResolvedEffect> petEffects = const <PetResolvedEffect>[],
  PetTicksBarConfig petBar = const PetTicksBarConfig(),
  int knightToSpecial = 4,
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

  final normalizedKnightAttack = normalized<double>(knightAttack);
  final normalizedKnightDefense = normalized<double>(knightDefense);
  final normalizedKnightStun = normalized<double>(knightStun);
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
    kAtk: normalizedKnightAttack,
    kDef: normalizedKnightDefense,
    kHp: knightHp,
    kAdv: List<double>.filled(count, 1.0, growable: false),
    kStun: normalizedKnightStun,
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

void _castSkill1(
  BattleState state,
  BattleRuntimeSkillState runtime,
) {
  final dispatchPlan = BattleSkillHandlerRegistry.buildDispatchPlan(
    state.skillDefinitions,
    PetSpecialCastKind.special1,
  );
  runtime.onPetCast(
    battleState: state,
    dispatchPlan: dispatchPlan,
    activeKnightIndex: state.activeKnightIndex,
  );
}

void _castSkill2(
  BattleState state,
  BattleRuntimeSkillState runtime,
) {
  final dispatchPlan = BattleSkillHandlerRegistry.buildDispatchPlan(
    state.skillDefinitions,
    PetSpecialCastKind.special2,
  );
  runtime.onPetCast(
    battleState: state,
    dispatchPlan: dispatchPlan,
    activeKnightIndex: state.activeKnightIndex,
  );
}

void main() {
  group('Phase 5 ex-mode-driven skills', () {
    test('Special Regeneration halves knight special cadence while active', () {
      final pre = _buildPrecomputed(
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Special Regeneration',
            values: <String, num>{'turns': 5},
            canonicalEffectId: 'special_regeneration',
            canonicalName: 'Special Regeneration',
            effectCategory: 'knight_special_charge',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegen'],
            effectSpec: <String, Object?>{},
          ),
        ],
        knightToSpecial: 4,
      );

      final state = const RaidBlitzBattleEngine()
          .createInitialState(BattleEngineSeed(pre: pre));
      final runtime =
          BattleRuntimeSkillState(knightCount: state.knights.length);
      _castSkill1(state, runtime);

      expect(runtime.specialRegenTimedStackCount, 1);
      expect(runtime.resolveKnightSpecialEveryTurns(state), 2);

      for (int i = 0; i < 5; i++) {
        runtime.onKnightActionResolved(state);
      }

      expect(runtime.specialRegenTimedStackCount, 0);
      expect(runtime.resolveKnightSpecialEveryTurns(state), 4);
    });

    test(
        'Special Regeneration infinite respects match and non-match thresholds',
        () {
      const effect = PetResolvedEffect(
        sourceSlotId: 'skill11',
        sourceSkillName: 'Special Regeneration (inf)',
        values: <String, num>{},
        canonicalEffectId: 'special_regeneration_infinite',
        canonicalName: 'Special Regeneration (inf)',
        effectCategory: 'knight_special_charge',
        dataSupport: 'structured_values',
        runtimeSupport: 'mode_specific',
        simulatorModes: <String>['specialRegen'],
        effectSpec: <String, Object?>{},
      );

      final matchState = const RaidBlitzBattleEngine().createInitialState(
        BattleEngineSeed(
          pre: _buildPrecomputed(petEffects: const <PetResolvedEffect>[effect]),
          runtimeKnobs: const BattleRuntimeKnobs(
            knightPetElementMatches: <bool>[true],
          ),
        ),
      );
      final matchRuntime =
          BattleRuntimeSkillState(knightCount: matchState.knights.length);
      _castSkill1(matchState, matchRuntime);
      expect(matchRuntime.specialRegenInfiniteStacks, 2);
      expect(
        matchRuntime.shouldForceKnightSpecial(
          matchState,
          activeKnightIndex: 0,
        ),
        isTrue,
      );

      final noMatchState = const RaidBlitzBattleEngine().createInitialState(
        BattleEngineSeed(
          pre: _buildPrecomputed(petEffects: const <PetResolvedEffect>[effect]),
          runtimeKnobs: const BattleRuntimeKnobs(
            knightPetElementMatches: <bool>[false],
          ),
        ),
      );
      final noMatchRuntime =
          BattleRuntimeSkillState(knightCount: noMatchState.knights.length);
      _castSkill1(noMatchState, noMatchRuntime);
      expect(noMatchRuntime.specialRegenInfiniteStacks, 1);
      expect(
        noMatchRuntime.shouldForceKnightSpecial(
          noMatchState,
          activeKnightIndex: 0,
        ),
        isFalse,
      );
      for (int i = 0; i < 3; i++) {
        _castSkill1(noMatchState, noMatchRuntime);
      }
      expect(noMatchRuntime.specialRegenInfiniteStacks, 4);
      expect(
        noMatchRuntime.shouldForceKnightSpecial(
          noMatchState,
          activeKnightIndex: 0,
        ),
        isTrue,
      );
    });

    test('Special Regeneration infinite decays after a turn below threshold',
        () {
      const effect = PetResolvedEffect(
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
      );

      final state = const RaidBlitzBattleEngine().createInitialState(
        BattleEngineSeed(
          pre: _buildPrecomputed(petEffects: const <PetResolvedEffect>[effect]),
          runtimeKnobs: const BattleRuntimeKnobs(
            knightPetElementMatches: <bool>[true, false],
          ),
        ),
      );
      final runtime =
          BattleRuntimeSkillState(knightCount: state.knights.length);

      _castSkill2(state, runtime);
      expect(runtime.specialRegenInfiniteStacks, 2);
      expect(
        runtime.shouldForceKnightSpecial(
          state,
          activeKnightIndex: 0,
        ),
        isTrue,
      );

      state.activeKnightIndex = 1;
      expect(
        runtime.shouldForceKnightSpecial(
          state,
          activeKnightIndex: 1,
        ),
        isFalse,
      );

      runtime.onKnightActionResolved(state);

      expect(runtime.specialRegenInfiniteStacks, 0);
      expect(state.srInfiniteStacks, 0);
    });

    test(
        'Elemental Weakness ignores boss miss but ticks on stun and boss action',
        () {
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
        ],
      );

      final state = const RaidBlitzBattleEngine()
          .createInitialState(BattleEngineSeed(pre: pre));
      final runtime =
          BattleRuntimeSkillState(knightCount: state.knights.length);
      _castSkill1(state, runtime);

      expect(runtime.bossOutgoingDamageMultiplier(), 0.5);

      runtime.onBossActionResolved(
        state,
        activeKnightIndex: 0,
        consumesElementalWeakness: false,
        consumesDurableRockShield: true,
      );
      expect(runtime.bossOutgoingDamageMultiplier(), 0.5);

      runtime.onBossStunResolved(state);
      expect(runtime.bossOutgoingDamageMultiplier(), 0.5);

      runtime.onBossActionResolved(
        state,
        activeKnightIndex: 0,
        consumesElementalWeakness: true,
        consumesDurableRockShield: true,
      );
      expect(runtime.bossOutgoingDamageMultiplier(), 1.0);
    });

    test(
        'Durable Rock Shield stacks multiplicatively and stun does not consume it',
        () {
      final pre = _buildPrecomputed(
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
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['durableRockShield'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final state = const RaidBlitzBattleEngine()
          .createInitialState(BattleEngineSeed(pre: pre));
      final runtime =
          BattleRuntimeSkillState(knightCount: state.knights.length);
      _castSkill1(state, runtime);
      _castSkill1(state, runtime);

      final single = drsDefenseMultiplier(
        baseBoostFraction: 0.5,
        elementMatch: false,
        sameElementMultiplier: pre.meta.sameElementDRS,
      );
      expect(runtime.bossDefenseMultiplierForKnight(0),
          closeTo(single * single, 1e-9));

      runtime.onBossStunResolved(state);
      expect(runtime.bossDefenseMultiplierForKnight(0),
          closeTo(single * single, 1e-9));

      for (int i = 0; i < 3; i++) {
        runtime.onBossActionResolved(
          state,
          activeKnightIndex: 0,
          consumesElementalWeakness: false,
          consumesDurableRockShield: true,
        );
      }
      expect(runtime.bossDefenseMultiplierForKnight(0), 1.0);
    });

    test(
        'Shatter Shield absorbs boss damage and extends survival in the real loop',
        () {
      final bossAttack = 1000.0;
      final withoutShield = _buildPrecomputed(
        bossHp: 9999,
        bossAttack: bossAttack,
        knightHp: const <int>[100],
        knightAttack: const <double>[0],
        petEffects: const <PetResolvedEffect>[],
        petBar: _instantSpecial1Bar(),
      );
      final withShield = _buildPrecomputed(
        bossHp: 9999,
        bossAttack: bossAttack,
        knightHp: const <int>[100],
        knightAttack: const <double>[0],
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Shatter Shield',
            values: <String, num>{
              'baseShieldHp': 150,
              'bonusShieldHp': 0,
            },
            canonicalEffectId: 'shatter_shield',
            canonicalName: 'Shatter Shield',
            effectCategory: 'damage_absorb_shield',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['shatterShield'],
            effectSpec: <String, Object?>{},
          ),
        ],
        petBar: _instantSpecial1Bar(),
      );

      final engine = const RaidBlitzBattleEngine();
      final withoutResult = engine.runWithRng(
        BattleEngineSeed(pre: withoutShield),
        FastRng(31),
      );
      final withResult = engine.runWithRng(
        BattleEngineSeed(pre: withShield),
        FastRng(31),
      );

      expect(withResult.bossTurns, greaterThan(withoutResult.bossTurns));
    });

    test('Shatter Shield percent uses max HP instead of current HP', () {
      const effect = PetResolvedEffect(
        sourceSlotId: 'skill2',
        sourceSkillName: 'Shatter Shield',
        values: <String, num>{
          'baseShieldPercent': 10,
          'bonusShieldPercent': 2,
        },
        canonicalEffectId: 'shatter_shield',
        canonicalName: 'Shatter Shield',
        effectCategory: 'damage_absorb_shield',
        dataSupport: 'structured_values',
        runtimeSupport: 'mode_specific',
        simulatorModes: <String>['shatterShield'],
        effectSpec: <String, Object?>{},
      );

      final state = const RaidBlitzBattleEngine().createInitialState(
        BattleEngineSeed(
          pre: _buildPrecomputed(
            knightHp: const <int>[1500],
            petEffects: const <PetResolvedEffect>[effect],
          ),
          runtimeKnobs: const BattleRuntimeKnobs(
            knightPetElementMatches: <bool>[true],
          ),
        ),
      );
      final runtime =
          BattleRuntimeSkillState(knightCount: state.knights.length);
      state.knights[0].currentHp = 1000;

      _castSkill2(state, runtime);

      expect(state.knights[0].shatterShieldHp, 180);
    });

    test('Cyclone Boost carries to the next knight after FIFO death', () {
      final basePre = _buildPrecomputed(
        bossHp: 9999,
        bossAttack: 1000,
        knightHp: const <int>[50, 100],
        knightAttack: const <double>[100, 100],
        knightStun: const <double>[0, 0],
        petEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Cyclone Boost',
            values: <String, num>{
              'attackBoostPercent': 100,
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
        petBar: _instantSpecial1Bar(),
        knightToSpecial: 99,
      );
      final bossHp = (basePre.kNormalDmg[0] * 3);
      final pre = _buildPrecomputed(
        bossHp: bossHp,
        bossAttack: 1000,
        knightHp: const <int>[50, 100],
        knightAttack: const <double>[100, 100],
        knightStun: const <double>[0, 0],
        petEffects: basePre.petEffects,
        petBar: _instantSpecial1Bar(),
        knightToSpecial: 99,
      );

      final result = const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(41),
      );

      expect(result.bossDefeated, isTrue);
      expect(result.knightTurns, 2);
      expect(result.finalKnightIndex, 1);
    });
  });
}
