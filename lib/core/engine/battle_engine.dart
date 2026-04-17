import '../../data/config_models.dart';
import '../../data/pet_loadout_models.dart';
import '../debug/debug_hooks.dart';
import '../sim_types.dart';
import '../timing_acc.dart';
import 'battle_state.dart';
import 'battle_run_result.dart';
import 'battle_runtime_effects.dart';
import 'engine_common.dart';
import 'skill_catalog.dart';
import 'skill_handlers.dart';

class BattleEngineSeed {
  final Precomputed pre;
  final Map<String, Map<String, num>> overrideValuesBySkillKey;
  final BattleRuntimeKnobs runtimeKnobs;
  late final List<BattleSkillDefinition> resolvedSkillDefinitions =
      BattleSkillCatalog.buildDefinitions(
    pre.petEffects,
    overrideValuesBySkillKey: overrideValuesBySkillKey,
  );

  BattleEngineSeed({
    required this.pre,
    this.overrideValuesBySkillKey = const <String, Map<String, num>>{},
    this.runtimeKnobs = const BattleRuntimeKnobs(),
  });

  factory BattleEngineSeed.fromLoadoutSnapshot({
    required Precomputed pre,
    required PetLoadoutSnapshot loadout,
    BattleRuntimeKnobs runtimeKnobs = const BattleRuntimeKnobs(),
  }) {
    return BattleEngineSeed(
      pre: pre,
      overrideValuesBySkillKey: loadout.overrideValuesBySkillKey,
      runtimeKnobs: runtimeKnobs,
    );
  }
}

class RaidBlitzBattleEngine {
  const RaidBlitzBattleEngine();

  List<BattleSkillDefinition> resolveSkills(BattleEngineSeed seed) =>
      seed.resolvedSkillDefinitions;

  BattleState createInitialState(
    BattleEngineSeed seed, {
    DebugPetBarHook? petBarDebug,
    bool trackEffectTimeline = false,
  }) {
    final skills = resolveSkills(seed);
    return BattleState.initial(
      pre: seed.pre,
      skillDefinitions: skills,
      runtimeKnobs: seed.runtimeKnobs,
      petBarDebug: petBarDebug,
      trackEffectTimeline: trackEffectTimeline,
    );
  }

  BattleSkillDispatchPlan buildDispatchPlan(
    BattleEngineSeed seed,
    PetSpecialCastKind cast,
  ) {
    return BattleSkillHandlerRegistry.buildDispatchPlan(
      resolveSkills(seed),
      cast,
    );
  }

  int runPoints(
    BattleEngineSeed seed, {
    bool withTiming = false,
    TimingAcc? timing,
  }) {
    return run(seed, withTiming: withTiming, timing: timing).points;
  }

  BattleRunResult run(
    BattleEngineSeed seed, {
    bool withTiming = false,
    TimingAcc? timing,
    DebugHook? debug,
    DebugPetBarHook? petBarDebug,
  }) {
    final state = createInitialState(
      seed,
      petBarDebug: petBarDebug,
      trackEffectTimeline: debug != null,
    );
    final tracker = (withTiming && timing != null)
        ? EngineTimingTracker(timing, seed.pre.meta.timing)
        : null;
    final rng = FastRng(DateTime.now().microsecondsSinceEpoch & 0x7fffffff);
    return _runState(
      state,
      rng,
      withTiming: withTiming,
      tracker: tracker,
      timing: timing,
      debug: debug,
    );
  }

  BattleRunResult runWithRng(
    BattleEngineSeed seed,
    FastRng rng, {
    bool withTiming = false,
    TimingAcc? timing,
    DebugHook? debug,
    DebugPetBarHook? petBarDebug,
  }) {
    final state = createInitialState(
      seed,
      petBarDebug: petBarDebug,
      trackEffectTimeline: debug != null,
    );
    final tracker = (withTiming && timing != null)
        ? EngineTimingTracker(timing, seed.pre.meta.timing)
        : null;
    return _runState(
      state,
      rng,
      withTiming: withTiming,
      tracker: tracker,
      timing: timing,
      debug: debug,
    );
  }

  BattleRunResult _runState(
    BattleState state,
    FastRng rng, {
    required bool withTiming,
    required EngineTimingTracker? tracker,
    required TimingAcc? timing,
    DebugHook? debug,
  }) {
    final metrics = _BattleMetrics();
    final runtimeSkills = BattleRuntimeSkillState(
      knightCount: state.knights.length,
    );
    int queuedBossStuns = 0;

    while (!state.battleEnded) {
      final activeKnight = state.activeKnight;
      if (activeKnight == null) break;

      final PetSpecialCastKind? petCast = state.cycloneAlwaysGemActive
          ? _forcedCycloneCast(state)
          : state.petBar.consumeQueuedCast()?.cast;
      final bool petCastThisTurn = petCast != null;
      if (petCast != null) {
        metrics.registerPetCast(petCast);
        if (state.cycloneAlwaysGemActive) {
          metrics.registerCycloneAlwaysGemTurn();
        }
      }

      state.advanceKnightTurn();
      final bool doSpecial;
      if (state.cycloneAlwaysGemActive) {
        doSpecial = true;
      } else if (runtimeSkills.shouldForceKnightSpecial(
        state,
        activeKnightIndex: activeKnight.index,
      )) {
        doSpecial = true;
      } else if (state.knightSpecialBar.enabled &&
          !runtimeSkills.hasTimedSpecialRegenCadenceOverride) {
        doSpecial = state.knightSpecialBar.consumeQueuedSpecial();
      } else {
        doSpecial = _isScheduledKnightSpecial(
          state,
          runtimeSkills,
        );
      }
      final _KnightActionResult knightAction = _resolveKnightAction(
        runtimeSkills,
        state.pre,
        rng,
        battleState: state,
        knightIndex: activeKnight.index,
        doSpecial: doSpecial,
      );

      final int knightDamage =
          runtimeSkills.boostKnightDamage(knightAction.damage);
      if (knightDamage > 0) {
        state.points += knightDamage;
        state.boss.currentHp = (state.boss.currentHp - knightDamage).clamp(
          0,
          state.boss.maxHp,
        );
      }
      metrics.registerKnightAction(knightAction.action);
      debug?.onKnightAction(
        knightTurn: state.knightTurn,
        kIdx: activeKnight.index,
        action: knightAction.action,
        dmg: knightDamage,
        points: state.points,
        cycloneStep: knightAction.action == DebugAction.special &&
                runtimeSkills.cycloneStackCount > 0
            ? runtimeSkills.cycloneStackCount
            : null,
        cycloneMult: knightAction.action == DebugAction.special &&
                runtimeSkills.cycloneStackCount > 0
            ? knightDamage /
                (knightAction.damage <= 0
                    ? 1.0
                    : knightAction.damage.toDouble())
            : null,
      );

      switch (knightAction.action) {
        case DebugAction.special:
          tracker?.knightSpecial(activeKnight.index);
        case DebugAction.miss:
          tracker?.knightMiss(activeKnight.index);
        case DebugAction.normal || DebugAction.crit:
          tracker?.knightNormal(activeKnight.index);
      }

      if (state.boss.currentHp <= 0) {
        runtimeSkills.onBattleFinished(state);
        return _buildResult(
          state,
          metrics,
          runtimeSkills,
          timing,
          queuedBossStuns,
        );
      }

      if (!knightAction.missed) {
        final int stunTarget = stunPermil(state.pre, activeKnight.index);
        final int stunRoll = stunTarget > 0 ? rng.nextPermil() : 1000;
        final bool stunSuccess = stunTarget > 0 && stunRoll < stunTarget;
        if (stunTarget > 0 || debug != null) {
          debug?.onKnightStun(
            knightTurn: state.knightTurn,
            kIdx: activeKnight.index,
            success: stunSuccess,
            roll: stunRoll,
            target: stunTarget,
          );
        }
        if (stunSuccess) {
          queuedBossStuns += 1;
          tracker?.knightStun(activeKnight.index);
        }
      }

      runtimeSkills.onKnightActionResolved(state);

      if (petCastThisTurn) {
        final dispatchPlan = state.dispatchPlanForCast(petCast);
        runtimeSkills.onPetCast(
          battleState: state,
          dispatchPlan: dispatchPlan,
          activeKnightIndex: activeKnight.index,
          debug: debug,
        );
        if (dispatchPlan.immediatePetHit) {
          final petAttackResult = runtimeSkills.resolvePetAttack(
            state.pre,
            rng,
            activeKnightIndex: activeKnight.index,
            currentKnightHp: activeKnight.currentHp,
          );
          _applyPetAttackResult(
            state,
            activeKnight,
            petAttackResult,
          );
          metrics.registerPetBasic();
          tracker?.petAttack(
            missed: petAttackResult.missed,
            crit: petAttackResult.crit,
          );
          if (state.boss.currentHp <= 0) {
            runtimeSkills.onBattleFinished(state);
            return _buildResult(
              state,
              metrics,
              runtimeSkills,
              timing,
              queuedBossStuns,
            );
          }
        }
        state.petBar.onKnightPetResolved(
          knightMiss: knightAction.missed,
          petMiss: false,
          petCrit: false,
          rng: rng,
        );
      } else {
        final petAttackResult = runtimeSkills.resolvePetAttack(
          state.pre,
          rng,
          activeKnightIndex: activeKnight.index,
          currentKnightHp: activeKnight.currentHp,
        );
        _applyPetAttackResult(
          state,
          activeKnight,
          petAttackResult,
        );
        metrics.registerPetBasic();
        tracker?.petAttack(
          missed: petAttackResult.missed,
          crit: petAttackResult.crit,
        );
        state.petBar.onKnightPetResolved(
          knightMiss: knightAction.missed,
          petMiss: petAttackResult.missed,
          petCrit: petAttackResult.crit,
          rng: rng,
        );
        if (state.boss.currentHp <= 0) {
          runtimeSkills.onBattleFinished(state);
          return _buildResult(
            state,
            metrics,
            runtimeSkills,
            timing,
            queuedBossStuns,
          );
        }
      }

      state.knightSpecialBar.onKnightTurnResolved();

      if (queuedBossStuns > 0) {
        queuedBossStuns -= 1;
        metrics.bossStunSkips += 1;
        state.petBar.onBossStun(rng);
        state.knightSpecialBar.onBossTurnResolved();
        runtimeSkills.onBossStunResolved(
          state,
          debug: debug,
        );
        debug?.onBossSkip(queuedNow: queuedBossStuns);
        continue;
      }

      state.advanceBossTurn();
      final bool bossSpecial = state.pre.meta.bossToSpecial > 0 &&
          state.bossTurn % state.pre.meta.bossToSpecial == 0;
      final _BossActionResult bossAction = _resolveBossAction(
        state.pre,
        rng,
        knightIndex: activeKnight.index,
        bossSpecial: bossSpecial,
        defMultiplier:
            runtimeSkills.bossDefenseMultiplierForKnight(activeKnight.index),
        damageMultiplier: runtimeSkills.bossOutgoingDamageMultiplier(),
      );
      final int baseBossDamage = bossDamage(
        state.pre,
        activeKnight.index,
        crit: bossAction.action == DebugAction.special ||
            bossAction.action == DebugAction.crit,
        defMultiplier:
            runtimeSkills.bossDefenseMultiplierForKnight(activeKnight.index),
      );

      metrics.registerBossAction(bossAction.action);
      switch (bossAction.action) {
        case DebugAction.special:
          tracker?.bossSpecial(activeKnight.index);
          state.petBar.onBossSpecial(rng);
        case DebugAction.miss:
          tracker?.bossMiss(activeKnight.index);
          state.petBar.onBossMiss(rng);
        case DebugAction.normal || DebugAction.crit:
          tracker?.bossNormal(activeKnight.index);
          state.petBar.onBossNormal(rng);
      }

      final int debugHpAfter = _debugKnightHpAfterBossDamage(
        activeKnight,
        bossAction.damage,
      );
      if (bossAction.damage > 0) {
        _applyBossDamageToKnight(
          activeKnight,
          bossAction.damage,
        );
      }
      debug?.onBossAction(
        bossTurn: state.bossTurn,
        kIdx: activeKnight.index,
        action: bossAction.action,
        dmg: bossAction.damage,
        hpAfter: debugHpAfter,
        baseDmg: runtimeSkills.elementalWeaknessStackCount > 0
            ? baseBossDamage
            : null,
        ewStacks: runtimeSkills.elementalWeaknessStackCount > 0
            ? runtimeSkills.elementalWeaknessStackCount
            : null,
      );

      final soulBurnDamage = runtimeSkills.onBossActionResolved(
        state,
        activeKnightIndex: activeKnight.index,
        consumesElementalWeakness: bossAction.action != DebugAction.miss,
        consumesDurableRockShield: true,
        debug: debug,
      );
      if (soulBurnDamage > 0) {
        state.points += soulBurnDamage;
        state.boss.currentHp =
            (state.boss.currentHp - soulBurnDamage).clamp(0, state.boss.maxHp);
        if (state.boss.currentHp <= 0) {
          runtimeSkills.onBattleFinished(state);
          return _buildResult(
            state,
            metrics,
            runtimeSkills,
            timing,
            queuedBossStuns,
          );
        }
      }

      state.knightSpecialBar.onBossTurnResolved();

      if (activeKnight.currentHp <= 0) {
        runtimeSkills.onKnightDeath(activeKnight.index);
        state.registerKnightDeath(activeKnight.index);
        debug?.onKnightDied(kIdx: activeKnight.index);
        final nextKnight = state.activeKnight;
        if (nextKnight != null) {
          debug?.onTargetSwitch(
            kIdx: nextKnight.index,
            hp: nextKnight.currentHp,
          );
        }
        continue;
      }
    }

    runtimeSkills.onBattleFinished(state);
    return _buildResult(
      state,
      metrics,
      runtimeSkills,
      timing,
      queuedBossStuns,
    );
  }

  PetSpecialCastKind? _forcedCycloneCast(BattleState state) {
    for (final skill in state.skillDefinitions) {
      if (!skill.isCycloneBoost || skill.isDisabledByOverride) continue;
      return skill.matchesCast(PetSpecialCastKind.special2)
          ? PetSpecialCastKind.special2
          : PetSpecialCastKind.special1;
    }
    return null;
  }

  BattleRunResult _buildResult(
    BattleState state,
    _BattleMetrics metrics,
    BattleRuntimeSkillState runtimeSkills,
    TimingAcc? timing,
    int queuedBossStuns,
  ) {
    final finalKnight = state.activeKnight;
    return BattleRunResult(
      points: state.points,
      bossHpRemaining: state.boss.currentHp,
      bossDefeated: state.boss.currentHp <= 0,
      knightsDefeated: !state.hasLivingKnights,
      knightTurns: state.knightTurn,
      bossTurns: state.bossTurn,
      finalKnightIndex: state.activeKnightIndex,
      finalKnightHp: finalKnight?.currentHp,
      petBasicAttacks: metrics.petBasicAttacks,
      petCastCount: metrics.petCastCount,
      petSpecial1Casts: metrics.petSpecial1Casts,
      petSpecial2Casts: metrics.petSpecial2Casts,
      petCastSequence:
          List<PetSpecialCastKind>.unmodifiable(metrics.petCastSequence),
      knightNormalActions: metrics.knightNormalActions,
      knightCritActions: metrics.knightCritActions,
      knightSpecialActions: metrics.knightSpecialActions,
      knightMissActions: metrics.knightMissActions,
      bossNormalActions: metrics.bossNormalActions,
      bossCritActions: metrics.bossCritActions,
      bossSpecialActions: metrics.bossSpecialActions,
      bossMissActions: metrics.bossMissActions,
      bossStunSkips: metrics.bossStunSkips + queuedBossStuns,
      cycloneAlwaysGemApplied: state.cycloneAlwaysGemActive,
      gemsSpent: metrics.gemsSpent,
      goldDropEnabled: runtimeSkills.goldDropEnabled,
      goldDropped: runtimeSkills.goldDropTriggered,
      timing: timing == null ? null : timing.toStats(1),
    );
  }
}

class _BattleMetrics {
  int petBasicAttacks = 0;
  int petCastCount = 0;
  int petSpecial1Casts = 0;
  int petSpecial2Casts = 0;
  final List<PetSpecialCastKind> petCastSequence = <PetSpecialCastKind>[];
  int knightNormalActions = 0;
  int knightCritActions = 0;
  int knightSpecialActions = 0;
  int knightMissActions = 0;
  int bossNormalActions = 0;
  int bossCritActions = 0;
  int bossSpecialActions = 0;
  int bossMissActions = 0;
  int bossStunSkips = 0;
  int gemsSpent = 0;

  void registerPetBasic() {
    petBasicAttacks += 1;
  }

  void registerPetCast(PetSpecialCastKind cast) {
    petCastCount += 1;
    petCastSequence.add(cast);
    if (cast == PetSpecialCastKind.special1) {
      petSpecial1Casts += 1;
    } else {
      petSpecial2Casts += 1;
    }
  }

  void registerCycloneAlwaysGemTurn() {
    gemsSpent += 4;
  }

  void registerKnightAction(DebugAction action) {
    switch (action) {
      case DebugAction.normal:
        knightNormalActions += 1;
      case DebugAction.crit:
        knightCritActions += 1;
      case DebugAction.special:
        knightSpecialActions += 1;
      case DebugAction.miss:
        knightMissActions += 1;
    }
  }

  void registerBossAction(DebugAction action) {
    switch (action) {
      case DebugAction.normal:
        bossNormalActions += 1;
      case DebugAction.crit:
        bossCritActions += 1;
      case DebugAction.special:
        bossSpecialActions += 1;
      case DebugAction.miss:
        bossMissActions += 1;
    }
  }
}

class _KnightActionResult {
  final int damage;
  final DebugAction action;
  final bool missed;

  const _KnightActionResult({
    required this.damage,
    required this.action,
    required this.missed,
  });
}

class _BossActionResult {
  final int damage;
  final DebugAction action;

  const _BossActionResult({
    required this.damage,
    required this.action,
  });
}

_KnightActionResult _resolveKnightAction(
  BattleRuntimeSkillState runtimeSkills,
  Precomputed pre,
  FastRng rng, {
  required BattleState battleState,
  required int knightIndex,
  required bool doSpecial,
}) {
  final result = runtimeSkills.resolveKnightAttack(
    pre,
    rng,
    battleState: battleState,
    knightIndex: knightIndex,
    doSpecial: doSpecial,
  );
  return _KnightActionResult(
    damage: result.damage,
    action: result.action,
    missed: result.missed,
  );
}

_BossActionResult _resolveBossAction(
  Precomputed pre,
  FastRng rng, {
  required int knightIndex,
  required bool bossSpecial,
  required double defMultiplier,
  required double damageMultiplier,
}) {
  if (bossSpecial) {
    return _BossActionResult(
      damage: _scaleBossDamage(
        bossDamage(
          pre,
          knightIndex,
          crit: true,
          defMultiplier: defMultiplier,
        ),
        damageMultiplier,
      ),
      action: DebugAction.special,
    );
  }

  if (rng.nextPermil() < evadePermil(pre)) {
    return const _BossActionResult(
      damage: 0,
      action: DebugAction.miss,
    );
  }

  final bool crit = rng.nextPermil() < critPermil(pre);
  return _BossActionResult(
    damage: _scaleBossDamage(
      bossDamage(
        pre,
        knightIndex,
        crit: crit,
        defMultiplier: defMultiplier,
      ),
      damageMultiplier,
    ),
    action: crit ? DebugAction.crit : DebugAction.normal,
  );
}

bool _isScheduledKnightSpecial(
  BattleState state,
  BattleRuntimeSkillState runtimeSkills,
) {
  final specialEveryTurns = runtimeSkills.resolveKnightSpecialEveryTurns(state);
  return specialEveryTurns > 0 && state.knightTurn % specialEveryTurns == 0;
}

int _scaleBossDamage(int baseDamage, double damageMultiplier) {
  if (baseDamage <= 0) return 0;
  if (damageMultiplier >= 1.0) return baseDamage;
  if (damageMultiplier <= 0) return 1;
  final scaled = (baseDamage * damageMultiplier).floor();
  return scaled < 1 ? 1 : scaled;
}

void _applyBossDamageToKnight(
  KnightBattleState knight,
  int damage,
) {
  if (damage <= 0) return;
  int remainingDamage = damage;
  if (knight.shatterShieldHp > 0) {
    final absorbed = remainingDamage.clamp(0, knight.shatterShieldHp);
    knight.shatterShieldHp -= absorbed;
    remainingDamage -= absorbed;
  }
  if (remainingDamage <= 0) return;
  knight.currentHp =
      (knight.currentHp - remainingDamage).clamp(0, knight.maxHp);
}

void _applyPetAttackResult(
  BattleState state,
  KnightBattleState activeKnight,
  RuntimePetAttackResult petAttackResult,
) {
  if (petAttackResult.damage <= 0) return;
  final actualDamage = petAttackResult.damage.clamp(0, state.boss.currentHp);
  state.points += petAttackResult.damage;
  state.boss.currentHp = (state.boss.currentHp - petAttackResult.damage)
      .clamp(0, state.boss.maxHp);
  if (petAttackResult.healPercentOfActualDamage <= 0 || actualDamage <= 0) {
    return;
  }
  final heal =
      ((actualDamage * petAttackResult.healPercentOfActualDamage) / 100.0)
          .floor();
  if (heal <= 0) return;
  activeKnight.currentHp = (activeKnight.currentHp + heal).clamp(
    0,
    activeKnight.maxHp,
  );
}

int _debugKnightHpAfterBossDamage(
  KnightBattleState knight,
  int damage,
) {
  if (damage <= 0) return knight.currentHp;
  int remainingDamage = damage;
  if (knight.shatterShieldHp > 0) {
    final absorbed = remainingDamage.clamp(0, knight.shatterShieldHp);
    remainingDamage -= absorbed;
  }
  return knight.currentHp - remainingDamage;
}
