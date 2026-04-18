import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/config_models.dart';
import '../debug/debug_hooks.dart';
import '../sim_types.dart';
import 'battle_effect_instance.dart';
import 'battle_state.dart';
import 'engine_common.dart';
import 'skill_catalog.dart';
import 'skill_handlers.dart';

@immutable
class RuntimeKnightAttackResult {
  final int damage;
  final DebugAction action;
  final bool missed;
  final bool crit;
  final bool deathBlowConsumed;
  final int deathBlowBonus;

  const RuntimeKnightAttackResult({
    required this.damage,
    required this.action,
    required this.missed,
    required this.crit,
    required this.deathBlowConsumed,
    required this.deathBlowBonus,
  });
}

@immutable
class RuntimePetAttackResult {
  final int damage;
  final bool missed;
  final bool crit;
  final int healPercentOfActualDamage;

  const RuntimePetAttackResult({
    required this.damage,
    required this.missed,
    required this.crit,
    required this.healPercentOfActualDamage,
  });
}

class BattleRuntimeSkillState {
  BattleRuntimeSkillState({
    required int knightCount,
  })  : _pendingDeathBlowBonusesByKnight =
            List<List<int>>.generate(knightCount, (_) => <int>[]),
        _readyToCritByKnight = List<List<_TimedCritChanceBonus>>.generate(
          knightCount,
          (_) => <_TimedCritChanceBonus>[],
        ),
        _durableRockShieldByKnight =
            List<List<_DurableRockShieldStack>>.generate(
          knightCount,
          (_) => <_DurableRockShieldStack>[],
        );

  final List<List<int>> _pendingDeathBlowBonusesByKnight;
  final List<List<_TimedCritChanceBonus>> _readyToCritByKnight;
  final List<List<_DurableRockShieldStack>> _durableRockShieldByKnight;
  final List<_TimedTurnEffect> _specialRegenStacks = <_TimedTurnEffect>[];
  final List<_ElementalWeaknessStack> _elementalWeaknessStacks =
      <_ElementalWeaknessStack>[];
  final List<_TimedCycloneStack> _cycloneStacks = <_TimedCycloneStack>[];

  _PendingPetAttackOverride? _pendingPetAttackOverride;
  _SoulBurnDot? _soulBurnDot;
  int _specialRegenInfiniteStacks = 0;

  bool goldDropEnabled = false;
  int goldDropAmount = 0;
  int goldDropTriggered = 0;

  int get specialRegenTimedStackCount => _specialRegenStacks.length;
  int get specialRegenInfiniteStacks => _specialRegenInfiniteStacks;
  int get cycloneStackCount => _cycloneStacks.length;
  int get elementalWeaknessStackCount => _elementalWeaknessStacks.length;
  bool get hasTimedSpecialRegenCadenceOverride =>
      _specialRegenStacks.isNotEmpty;

  double bossOutgoingDamageMultiplier() {
    double out = 1.0;
    for (final stack in _elementalWeaknessStacks) {
      out *= stack.damageMultiplier;
    }
    if (!out.isFinite || out < 0) return 0.0;
    if (out > 1.0) return 1.0;
    return out;
  }

  double bossDefenseMultiplierForKnight(int knightIndex) {
    if (knightIndex < 0 || knightIndex >= _durableRockShieldByKnight.length) {
      return 1.0;
    }
    double out = 1.0;
    for (final stack in _durableRockShieldByKnight[knightIndex]) {
      out *= stack.defenseMultiplier;
    }
    if (!out.isFinite || out <= 0) return 1.0;
    return out;
  }

  bool shouldForceKnightSpecial(
    BattleState battleState, {
    required int activeKnightIndex,
  }) {
    if (_specialRegenInfiniteStacks <= 0) return false;
    final neededStacks =
        battleState.knightMatchesPet(activeKnightIndex) ? 2 : 4;
    return _specialRegenInfiniteStacks >= neededStacks;
  }

  int resolveKnightSpecialEveryTurns(BattleState battleState) {
    int everyTurns = battleState.pre.meta.knightToSpecial;
    if (everyTurns <= 0) return everyTurns;
    if (_specialRegenInfiniteStacks > 0) return everyTurns;
    for (int i = 0; i < _specialRegenStacks.length; i++) {
      everyTurns = (everyTurns ~/ 2).clamp(1, 1 << 30);
    }
    return everyTurns;
  }

  int boostKnightDamage(int baseDamage) {
    if (baseDamage <= 0 || _cycloneStacks.isEmpty) return baseDamage;
    double multiplier = 1.0;
    for (final stack in _cycloneStacks) {
      multiplier *= 1.0 + (stack.boostPercent / 100.0);
    }
    return clampInt((baseDamage * multiplier).ceil());
  }

  void onPetCast({
    required BattleState battleState,
    required BattleSkillDispatchPlan dispatchPlan,
    required int activeKnightIndex,
    DebugHook? debug,
  }) {
    for (final skill in dispatchPlan.matchedSkills) {
      switch (skill.canonicalEffectId) {
        case BattleSkillCatalog.specialRegenId:
          _applySpecialRegen(
            battleState,
            skill,
            debug: debug,
          );
          break;
        case BattleSkillCatalog.specialRegenInfiniteId:
          _applySpecialRegenInfinite(
            battleState,
            skill,
            activeKnightIndex: activeKnightIndex,
            debug: debug,
          );
          break;
        case BattleSkillCatalog.elementalWeaknessId:
          _applyElementalWeakness(
            battleState,
            skill,
            activeKnightIndex: activeKnightIndex,
            debug: debug,
          );
          break;
        case BattleSkillCatalog.shatterShieldId:
          _applyShatterShield(
            battleState,
            skill,
            activeKnightIndex: activeKnightIndex,
            debug: debug,
          );
          break;
        case BattleSkillCatalog.durableRockShieldId:
          _applyDurableRockShield(
            battleState,
            skill,
            activeKnightIndex: activeKnightIndex,
            debug: debug,
          );
          break;
        case BattleSkillCatalog.cycloneId:
          _applyCycloneBoost(
            battleState,
            skill,
            debug: debug,
          );
          break;
        case BattleSkillCatalog.deathBlowId:
          _applyDeathBlow(
            skill,
            activeKnightIndex: activeKnightIndex,
          );
          break;
        case BattleSkillCatalog.readyToCritId:
          _applyReadyToCrit(
            battleState,
            skill,
            activeKnightIndex: activeKnightIndex,
          );
          break;
        case BattleSkillCatalog.shadowSlashId:
          final fixedAttack = skill.values.intValue('petAttack');
          if (fixedAttack > 0) {
            _pendingPetAttackOverride = _PendingPetAttackOverride.shadowSlash(
              fixedAttack: fixedAttack,
            );
          }
          break;
        case BattleSkillCatalog.revengeStrikeId:
          final attackCap = skill.values.intValue('petAttackCap');
          if (attackCap > 0) {
            _pendingPetAttackOverride = _PendingPetAttackOverride.revengeStrike(
              attackCap: attackCap,
            );
          }
          break;
        case BattleSkillCatalog.soulBurnId:
          _applySoulBurn(battleState, skill);
          break;
        case BattleSkillCatalog.vampiricAttackId:
          final attack = skill.values.intValue('flatDamage');
          final stealPercent = _wholePercent(skill.values['stealPercent']);
          if (attack > 0) {
            _pendingPetAttackOverride =
                _PendingPetAttackOverride.vampiricAttack(
              fixedAttack: attack,
              stealPercent: stealPercent,
            );
          }
          break;
        case BattleSkillCatalog.fortunesCallId:
          goldDropEnabled = true;
          goldDropAmount = skill.values.intValue(
            'goldDrop',
            fallback: skill.values.intValue(
              'goldAmount',
              fallback: skill.values.intValue('gold'),
            ),
          );
          _replaceUniqueEffect(
            battleState,
            BattleEffectInstance(
              instanceId: _newEffectInstanceId(
                skill.canonicalEffectId,
                battleState,
              ),
              canonicalEffectId: skill.canonicalEffectId,
              displayName: skill.displayName,
              sourceSlotId: skill.sourceSlotId,
              owner: const BattleEffectOwner.battle(),
              durationUnit: BattleEffectDurationUnit.battle,
              stackingMode: BattleEffectStackingMode.uniquePersistent,
              values: skill.values,
              remainingTurns: null,
              createdAtKnightTurn: battleState.knightTurn,
              createdAtBossTurn: battleState.bossTurn,
            ),
          );
          break;
        default:
          break;
      }
    }
  }

  RuntimeKnightAttackResult resolveKnightAttack(
    Precomputed pre,
    FastRng rng, {
    required BattleState battleState,
    required int knightIndex,
    required bool doSpecial,
  }) {
    final pendingDeathBlows = knightIndex >= 0 &&
            knightIndex < _pendingDeathBlowBonusesByKnight.length
        ? _pendingDeathBlowBonusesByKnight[knightIndex]
        : const <int>[];
    final hasDeathBlow = pendingDeathBlows.isNotEmpty;
    final deathBlowBonus = hasDeathBlow ? pendingDeathBlows.first : 0;

    if (doSpecial) {
      if (hasDeathBlow) {
        pendingDeathBlows.removeAt(0);
      }
      return _afterKnightAction(
        battleState,
        knightIndex,
        RuntimeKnightAttackResult(
          damage: pre.kSpecialDmg[knightIndex],
          action: DebugAction.special,
          missed: false,
          crit: false,
          deathBlowConsumed: hasDeathBlow,
          deathBlowBonus: 0,
        ),
      );
    }

    if (rng.nextPermil() < evadePermil(pre)) {
      if (hasDeathBlow) {
        pendingDeathBlows.removeAt(0);
      }
      return _afterKnightAction(
        battleState,
        knightIndex,
        RuntimeKnightAttackResult(
          damage: 0,
          action: DebugAction.miss,
          missed: true,
          crit: false,
          deathBlowConsumed: hasDeathBlow,
          deathBlowBonus: 0,
        ),
      );
    }

    if (hasDeathBlow) {
      pendingDeathBlows.removeAt(0);
      return _afterKnightAction(
        battleState,
        knightIndex,
        RuntimeKnightAttackResult(
          damage: pre.kCritDmg[knightIndex] + deathBlowBonus,
          action: DebugAction.crit,
          missed: false,
          crit: true,
          deathBlowConsumed: true,
          deathBlowBonus: deathBlowBonus,
        ),
      );
    }

    final critChance =
        (critPermil(pre) + _readyToCritBonusPermil(knightIndex)).clamp(0, 1000);
    final isCrit = rng.nextPermil() < critChance;
    return _afterKnightAction(
      battleState,
      knightIndex,
      RuntimeKnightAttackResult(
        damage:
            isCrit ? pre.kCritDmg[knightIndex] : pre.kNormalDmg[knightIndex],
        action: isCrit ? DebugAction.crit : DebugAction.normal,
        missed: false,
        crit: isCrit,
        deathBlowConsumed: false,
        deathBlowBonus: 0,
      ),
    );
  }

  RuntimePetAttackResult resolvePetAttack(
    Precomputed pre,
    FastRng rng, {
    required int activeKnightIndex,
    required int currentKnightHp,
  }) {
    final override = _pendingPetAttackOverride;
    if (override == null) {
      final result = petAttack(pre, rng);
      return RuntimePetAttackResult(
        damage: result.damage,
        missed: result.missed,
        crit: result.crit,
        healPercentOfActualDamage: 0,
      );
    }
    _pendingPetAttackOverride = null;

    final attackOverride = switch (override.kind) {
      _PendingPetAttackOverrideKind.shadowSlash =>
        override.fixedAttack.toDouble(),
      _PendingPetAttackOverrideKind.revengeStrike => _revengeStrikeAttack(
          pre,
          activeKnightIndex: activeKnightIndex,
          currentKnightHp: currentKnightHp,
          attackCap: override.attackCap,
        ),
      _PendingPetAttackOverrideKind.vampiricAttack =>
        override.fixedAttack.toDouble(),
    };

    final result = petAttack(
      pre,
      rng,
      attackOverride: attackOverride,
    );
    return RuntimePetAttackResult(
      damage: result.damage,
      missed: result.missed,
      crit: result.crit,
      healPercentOfActualDamage: override.stealPercent,
    );
  }

  void onKnightActionResolved(BattleState battleState) {
    _decrementTimedTurnStacks(
      battleState,
      _specialRegenStacks,
    );
    _decrementTimedTurnStacks(
      battleState,
      _cycloneStacks,
    );
    _expireSpecialRegenInfiniteStacksIfInactive(
      battleState,
      activeKnightIndex: battleState.activeKnightIndex,
    );
  }

  int onBossActionResolved(
    BattleState battleState, {
    required int activeKnightIndex,
    required bool consumesElementalWeakness,
    required bool consumesDurableRockShield,
    DebugHook? debug,
  }) {
    if (consumesElementalWeakness) {
      _decrementElementalWeaknessStacks(
        battleState,
        debug: debug,
        reason: 'boss_turn',
      );
    }
    if (consumesDurableRockShield) {
      _decrementDurableRockShieldStacks(
        battleState,
        knightIndex: activeKnightIndex,
        debug: debug,
      );
    }

    final dot = _soulBurnDot;
    if (dot == null) return 0;
    final damage = dot.damagePerBossAction;
    dot.remainingBossActions -= 1;
    if (dot.remainingBossActions <= 0) {
      if (battleState.trackEffectTimeline) {
        battleState.activeEffects
            .removeWhere((effect) => effect.instanceId == dot.instanceId);
      }
      _soulBurnDot = null;
      return damage;
    }

    _updateEffectRemainingTurns(
      battleState,
      dot.instanceId,
      dot.remainingBossActions,
    );
    return damage;
  }

  void onBossStunResolved(BattleState battleState, {DebugHook? debug}) {
    _decrementElementalWeaknessStacks(
      battleState,
      debug: debug,
      reason: 'stun',
    );
  }

  void onKnightDeath(int knightIndex) {
    if (knightIndex < 0 ||
        knightIndex >= _pendingDeathBlowBonusesByKnight.length) {
      return;
    }
    _pendingDeathBlowBonusesByKnight[knightIndex].clear();
    _readyToCritByKnight[knightIndex].clear();
    _durableRockShieldByKnight[knightIndex].clear();
  }

  void onBattleFinished(BattleState battleState) {
    if (goldDropEnabled && battleState.boss.currentHp <= 0) {
      goldDropTriggered = goldDropAmount;
    }
  }

  RuntimeKnightAttackResult _afterKnightAction(
    BattleState battleState,
    int knightIndex,
    RuntimeKnightAttackResult result,
  ) {
    if (knightIndex < 0 || knightIndex >= _readyToCritByKnight.length) {
      return result;
    }
    final stacks = _readyToCritByKnight[knightIndex];
    for (final stack in stacks) {
      stack.remainingTurns -= 1;
    }
    if (!battleState.trackEffectTimeline) {
      stacks.removeWhere((stack) => stack.remainingTurns <= 0);
      return result;
    }
    for (int i = battleState.activeEffects.length - 1; i >= 0; i--) {
      final effect = battleState.activeEffects[i];
      if (effect.canonicalEffectId != BattleSkillCatalog.readyToCritId) {
        continue;
      }
      final owner = effect.owner;
      if (owner.kind != BattleEffectOwnerKind.knight ||
          owner.index != knightIndex) {
        continue;
      }
      final matchingStack = stacks.cast<_TimedCritChanceBonus?>().firstWhere(
            (stack) => stack?.instanceId == effect.instanceId,
            orElse: () => null,
          );
      if (matchingStack == null || matchingStack.remainingTurns <= 0) {
        battleState.activeEffects.removeAt(i);
      } else {
        battleState.activeEffects[i] = effect.copyWith(
          remainingTurns: matchingStack.remainingTurns,
        );
      }
    }
    stacks.removeWhere((stack) => stack.remainingTurns <= 0);
    return result;
  }

  void _applySpecialRegen(
    BattleState battleState,
    BattleSkillDefinition skill, {
    DebugHook? debug,
  }) {
    final turns = skill.values.intValue('turns', fallback: 5);
    if (turns <= 0) return;
    final instanceId =
        _newEffectInstanceId(skill.canonicalEffectId, battleState);
    _specialRegenStacks.add(
      _TimedTurnEffect(
        instanceId: instanceId,
        remainingTurns: turns,
      ),
    );
    battleState.addEffect(
      BattleEffectInstance(
        instanceId: instanceId,
        canonicalEffectId: skill.canonicalEffectId,
        displayName: skill.displayName,
        sourceSlotId: skill.sourceSlotId,
        owner: const BattleEffectOwner.battle(),
        durationUnit: BattleEffectDurationUnit.knightTurn,
        stackingMode: BattleEffectStackingMode.additive,
        values: skill.values,
        remainingTurns: turns,
        createdAtKnightTurn: battleState.knightTurn,
        createdAtBossTurn: battleState.bossTurn,
      ),
    );
  }

  void _applySpecialRegenInfinite(
    BattleState battleState,
    BattleSkillDefinition skill, {
    required int activeKnightIndex,
    DebugHook? debug,
  }) {
    final wasActive = shouldForceKnightSpecial(
      battleState,
      activeKnightIndex: activeKnightIndex,
    );
    final addedStacks = battleState.knightMatchesPet(activeKnightIndex) ? 2 : 1;
    final room = 4 - _specialRegenInfiniteStacks;
    final applied = addedStacks.clamp(0, room);
    if (applied <= 0) return;
    for (int i = 0; i < applied; i++) {
      battleState.addEffect(
        BattleEffectInstance(
          instanceId: _newEffectInstanceId(
            skill.canonicalEffectId,
            battleState,
            suffix: ':$i',
          ),
          canonicalEffectId: skill.canonicalEffectId,
          displayName: skill.displayName,
          sourceSlotId: skill.sourceSlotId,
          owner: const BattleEffectOwner.battle(),
          durationUnit: BattleEffectDurationUnit.battle,
          stackingMode: BattleEffectStackingMode.additive,
          values: skill.values,
          remainingTurns: null,
          createdAtKnightTurn: battleState.knightTurn,
          createdAtBossTurn: battleState.bossTurn,
        ),
      );
    }
    _specialRegenInfiniteStacks += applied;
    battleState.srInfiniteStacks = _specialRegenInfiniteStacks;
    final isActive = shouldForceKnightSpecial(
      battleState,
      activeKnightIndex: activeKnightIndex,
    );
    if (!wasActive && isActive) {
      debug?.onSrActive(knightTurn: battleState.knightTurn);
    }
  }

  void _expireSpecialRegenInfiniteStacksIfInactive(
    BattleState battleState, {
    required int activeKnightIndex,
  }) {
    if (_specialRegenInfiniteStacks <= 0) return;
    if (activeKnightIndex >= 0 &&
        shouldForceKnightSpecial(
          battleState,
          activeKnightIndex: activeKnightIndex,
        )) {
      return;
    }
    _specialRegenInfiniteStacks = 0;
    battleState.srInfiniteStacks = 0;
    if (battleState.trackEffectTimeline) {
      battleState.activeEffects.removeWhere(
        (effect) =>
            effect.canonicalEffectId ==
            BattleSkillCatalog.specialRegenInfiniteId,
      );
    }
  }

  void _applyElementalWeakness(
    BattleState battleState,
    BattleSkillDefinition skill, {
    required int activeKnightIndex,
    DebugHook? debug,
  }) {
    final turns = skill.values.intValue(
      'turns',
      fallback: battleState.pre.meta.durationElementalWeakness,
    );
    final reduction = skill.values.fractionValue(
      'enemyAttackReductionPercent',
      fallback: battleState.pre.meta.defaultElementalWeakness,
    );
    if (turns <= 0 || reduction <= 0) return;
    final petStrong = battleState.petStrongVsBossForKnight(activeKnightIndex);
    final exponent = elementalWeaknessExponent(
      petStrongVsBoss: petStrong,
      baseReduction: reduction,
      strongElementEw: battleState.pre.meta.strongElementEW,
    );
    final damageMultiplier =
        math.pow(1.0 - reduction.clamp(0.0, 0.999999), exponent).toDouble();
    final instanceId =
        _newEffectInstanceId(skill.canonicalEffectId, battleState);
    _elementalWeaknessStacks.add(
      _ElementalWeaknessStack(
        instanceId: instanceId,
        damageMultiplier: damageMultiplier,
        remainingBossActions: turns,
      ),
    );
    battleState.addEffect(
      BattleEffectInstance(
        instanceId: instanceId,
        canonicalEffectId: skill.canonicalEffectId,
        displayName: skill.displayName,
        sourceSlotId: skill.sourceSlotId,
        owner: const BattleEffectOwner.boss(),
        durationUnit: BattleEffectDurationUnit.bossTurn,
        stackingMode: BattleEffectStackingMode.independent,
        values: skill.values,
        remainingTurns: turns,
        createdAtKnightTurn: battleState.knightTurn,
        createdAtBossTurn: battleState.bossTurn,
      ),
    );
    debug?.onEwApplied(
      stacks: _elementalWeaknessStacks.length,
      reduction: (1.0 - damageMultiplier).clamp(0.0, 1.0),
      duration: turns,
    );
  }

  void _applyShatterShield(
    BattleState battleState,
    BattleSkillDefinition skill, {
    required int activeKnightIndex,
    DebugHook? debug,
  }) {
    if (activeKnightIndex < 0 ||
        activeKnightIndex >= battleState.knights.length) {
      return;
    }
    final knight = battleState.knights[activeKnightIndex];
    final maxHp = knight.maxHp.clamp(0, 1 << 30);
    final baseShieldFlat = _firstIntValue(
      skill.values,
      const <String>['baseShieldHp', 'flatHp', 'baseHp'],
    );
    final bonusShieldFlat = _firstIntValue(
      skill.values,
      const <String>['bonusShieldHp', 'bonusHp'],
    );
    final baseShieldPercent = _percentShieldValue(
      maxHp,
      skill.values,
      const <String>['baseShieldPercent'],
    );
    final bonusShieldPercent = _percentShieldValue(
      maxHp,
      skill.values,
      const <String>['bonusShieldPercent'],
    );
    final baseShield = baseShieldFlat + baseShieldPercent;
    final bonusShield = bonusShieldFlat + bonusShieldPercent;
    final totalShield = baseShield +
        (battleState.knightMatchesPet(activeKnightIndex) ? bonusShield : 0);
    if (totalShield <= 0) return;
    knight.shatterShieldHp += totalShield;
    debug?.onShatterApply(
      knightTurn: battleState.knightTurn,
      add: totalShield,
      baseHp: baseShield,
      bonusHp:
          battleState.knightMatchesPet(activeKnightIndex) ? bonusShield : 0,
      hpAfter: knight.currentHp + knight.shatterShieldHp,
    );
  }

  void _applyDurableRockShield(
    BattleState battleState,
    BattleSkillDefinition skill, {
    required int activeKnightIndex,
    DebugHook? debug,
  }) {
    if (activeKnightIndex < 0 ||
        activeKnightIndex >= _durableRockShieldByKnight.length) {
      return;
    }
    final turns = skill.values.intValue(
      'turns',
      fallback: battleState.pre.meta.durationDRS,
    );
    final defenseBoost = skill.values.fractionValue(
      'defenseBoostPercent',
      fallback: battleState.pre.meta.defaultDurableRockShield,
    );
    if (turns <= 0 || defenseBoost <= 0) return;
    final defenseMultiplier = drsDefenseMultiplier(
      baseBoostFraction: defenseBoost,
      elementMatch: battleState.knightMatchesPet(activeKnightIndex),
      sameElementMultiplier: battleState.pre.meta.sameElementDRS,
    );
    final instanceId =
        _newEffectInstanceId(skill.canonicalEffectId, battleState);
    _durableRockShieldByKnight[activeKnightIndex].add(
      _DurableRockShieldStack(
        instanceId: instanceId,
        defenseMultiplier: defenseMultiplier,
        remainingBossActions: turns,
      ),
    );
    battleState.addEffect(
      BattleEffectInstance(
        instanceId: instanceId,
        canonicalEffectId: skill.canonicalEffectId,
        displayName: skill.displayName,
        sourceSlotId: skill.sourceSlotId,
        owner: BattleEffectOwner.knight(activeKnightIndex),
        durationUnit: BattleEffectDurationUnit.bossTurn,
        stackingMode: BattleEffectStackingMode.multiplicative,
        values: skill.values,
        remainingTurns: turns,
        createdAtKnightTurn: battleState.knightTurn,
        createdAtBossTurn: battleState.bossTurn,
      ),
    );
    debug?.onDrsActive(
      pct: defenseBoost,
      turns: turns,
    );
  }

  void _applyCycloneBoost(
    BattleState battleState,
    BattleSkillDefinition skill, {
    DebugHook? debug,
  }) {
    final turns = skill.values.intValue(
      'turns',
      fallback: battleState.maxCycloneStacks,
    );
    final boostPercent = _percentValue(
      skill.values['attackBoostPercent'],
      fallback: battleState.pre.meta.cyclone,
    );
    if (turns <= 0 || boostPercent <= 0) return;
    while (_cycloneStacks.length >= battleState.maxCycloneStacks &&
        _cycloneStacks.isNotEmpty) {
      final removed = _cycloneStacks.removeAt(0);
      if (battleState.trackEffectTimeline) {
        battleState.activeEffects
            .removeWhere((effect) => effect.instanceId == removed.instanceId);
      }
    }
    final instanceId =
        _newEffectInstanceId(skill.canonicalEffectId, battleState);
    _cycloneStacks.add(
      _TimedCycloneStack(
        instanceId: instanceId,
        boostPercent: boostPercent,
        remainingTurns: turns,
      ),
    );
    battleState.addEffect(
      BattleEffectInstance(
        instanceId: instanceId,
        canonicalEffectId: skill.canonicalEffectId,
        displayName: skill.displayName,
        sourceSlotId: skill.sourceSlotId,
        owner: const BattleEffectOwner.battle(),
        durationUnit: BattleEffectDurationUnit.knightTurn,
        stackingMode: BattleEffectStackingMode.additive,
        values: skill.values,
        remainingTurns: turns,
        createdAtKnightTurn: battleState.knightTurn,
        createdAtBossTurn: battleState.bossTurn,
      ),
    );
  }

  void _applyDeathBlow(
    BattleSkillDefinition skill, {
    required int activeKnightIndex,
  }) {
    final bonus = skill.values.intValue(
      'bonusFlatDamage',
      fallback: (skill.effectSpec['bonusFlatDamage'] as num?)?.toInt() ?? 0,
    );
    if (bonus <= 0 ||
        activeKnightIndex < 0 ||
        activeKnightIndex >= _pendingDeathBlowBonusesByKnight.length) {
      return;
    }
    _pendingDeathBlowBonusesByKnight[activeKnightIndex].add(bonus);
  }

  void _applyReadyToCrit(
    BattleState battleState,
    BattleSkillDefinition skill, {
    required int activeKnightIndex,
  }) {
    final turns = skill.values.intValue('turns');
    final critChancePermil = _permilFromPercent(
      skill.values['critChancePercent'],
    );
    if (turns <= 0 ||
        critChancePermil <= 0 ||
        activeKnightIndex < 0 ||
        activeKnightIndex >= _readyToCritByKnight.length) {
      return;
    }
    final instanceId =
        _newEffectInstanceId(skill.canonicalEffectId, battleState);
    _readyToCritByKnight[activeKnightIndex].add(
      _TimedCritChanceBonus(
        instanceId: instanceId,
        bonusPermil: critChancePermil,
        remainingTurns: turns,
      ),
    );
    battleState.addEffect(
      BattleEffectInstance(
        instanceId: instanceId,
        canonicalEffectId: skill.canonicalEffectId,
        displayName: skill.displayName,
        sourceSlotId: skill.sourceSlotId,
        owner: BattleEffectOwner.knight(activeKnightIndex),
        durationUnit: BattleEffectDurationUnit.knightTurn,
        stackingMode: BattleEffectStackingMode.additive,
        values: skill.values,
        remainingTurns: turns,
        createdAtKnightTurn: battleState.knightTurn,
        createdAtBossTurn: battleState.bossTurn,
      ),
    );
  }

  void _applySoulBurn(
    BattleState battleState,
    BattleSkillDefinition skill,
  ) {
    final directDamage = skill.values.intValue('flatDamage');
    final dotDamage = skill.values.intValue('damageOverTime');
    final turns = skill.values.intValue('turns');
    if (directDamage > 0) {
      battleState.points += directDamage;
      battleState.boss.currentHp =
          (battleState.boss.currentHp - directDamage).clamp(
        0,
        battleState.boss.maxHp,
      );
    }
    if (dotDamage <= 0 || turns <= 0) return;
    final instanceId =
        _newEffectInstanceId(skill.canonicalEffectId, battleState);
    _soulBurnDot = _SoulBurnDot(
      instanceId: instanceId,
      damagePerBossAction: dotDamage,
      remainingBossActions: turns,
    );
    _replaceUniqueEffect(
      battleState,
      BattleEffectInstance(
        instanceId: instanceId,
        canonicalEffectId: skill.canonicalEffectId,
        displayName: skill.displayName,
        sourceSlotId: skill.sourceSlotId,
        owner: const BattleEffectOwner.boss(),
        durationUnit: BattleEffectDurationUnit.bossTurn,
        stackingMode: BattleEffectStackingMode.replace,
        values: skill.values,
        remainingTurns: turns,
        createdAtKnightTurn: battleState.knightTurn,
        createdAtBossTurn: battleState.bossTurn,
      ),
    );
  }

  void _decrementTimedTurnStacks<T extends _TimedTurnBackedEffect>(
    BattleState battleState,
    List<T> stacks,
  ) {
    for (int i = stacks.length - 1; i >= 0; i--) {
      final stack = stacks[i];
      stack.remainingTurns -= 1;
      if (stack.remainingTurns <= 0) {
        stacks.removeAt(i);
        if (battleState.trackEffectTimeline) {
          battleState.activeEffects
              .removeWhere((effect) => effect.instanceId == stack.instanceId);
        }
        continue;
      }
      _updateEffectRemainingTurns(
        battleState,
        stack.instanceId,
        stack.remainingTurns,
      );
    }
  }

  void _decrementElementalWeaknessStacks(
    BattleState battleState, {
    DebugHook? debug,
    required String reason,
  }) {
    final hadStacks = _elementalWeaknessStacks.isNotEmpty;
    for (int i = _elementalWeaknessStacks.length - 1; i >= 0; i--) {
      final stack = _elementalWeaknessStacks[i];
      stack.remainingBossActions -= 1;
      if (stack.remainingBossActions <= 0) {
        _elementalWeaknessStacks.removeAt(i);
        if (battleState.trackEffectTimeline) {
          battleState.activeEffects
              .removeWhere((effect) => effect.instanceId == stack.instanceId);
        }
        continue;
      }
      _updateEffectRemainingTurns(
        battleState,
        stack.instanceId,
        stack.remainingBossActions,
      );
    }
    if (hadStacks) {
      debug?.onEwTick(
        reason: reason,
        stacks: _elementalWeaknessStacks.length,
      );
    }
  }

  void _decrementDurableRockShieldStacks(
    BattleState battleState, {
    required int knightIndex,
    DebugHook? debug,
  }) {
    if (knightIndex < 0 || knightIndex >= _durableRockShieldByKnight.length) {
      return;
    }
    final stacks = _durableRockShieldByKnight[knightIndex];
    final hadStacks = stacks.isNotEmpty;
    for (int i = stacks.length - 1; i >= 0; i--) {
      final stack = stacks[i];
      stack.remainingBossActions -= 1;
      if (stack.remainingBossActions <= 0) {
        stacks.removeAt(i);
        if (battleState.trackEffectTimeline) {
          battleState.activeEffects
              .removeWhere((effect) => effect.instanceId == stack.instanceId);
        }
        continue;
      }
      _updateEffectRemainingTurns(
        battleState,
        stack.instanceId,
        stack.remainingBossActions,
      );
    }
    if (hadStacks && stacks.isEmpty) {
      debug?.onDrsEnded();
    }
  }

  void _updateEffectRemainingTurns(
    BattleState battleState,
    String instanceId,
    int remainingTurns,
  ) {
    if (!battleState.trackEffectTimeline) return;
    for (int i = 0; i < battleState.activeEffects.length; i++) {
      final effect = battleState.activeEffects[i];
      if (effect.instanceId != instanceId) continue;
      battleState.activeEffects[i] = effect.copyWith(
        remainingTurns: remainingTurns,
      );
      return;
    }
  }

  int _readyToCritBonusPermil(int knightIndex) {
    if (knightIndex < 0 || knightIndex >= _readyToCritByKnight.length) {
      return 0;
    }
    return _readyToCritByKnight[knightIndex].fold<int>(
      0,
      (sum, stack) => sum + stack.bonusPermil,
    );
  }

  double _revengeStrikeAttack(
    Precomputed pre, {
    required int activeKnightIndex,
    required int currentKnightHp,
    required int attackCap,
  }) {
    final baseAttack = pre.petAtk <= 0 ? 0.0 : pre.petAtk;
    if (baseAttack <= 0 || attackCap <= 0) return baseAttack;
    if (activeKnightIndex < 0 || activeKnightIndex >= pre.kHp.length) {
      return baseAttack;
    }
    final maxHp = pre.kHp[activeKnightIndex];
    if (maxHp <= 0) return baseAttack;
    final hpLost = (maxHp - currentKnightHp).clamp(0, maxHp);
    final hpLostRatio = hpLost / maxHp;
    final extra = (attackCap - baseAttack).clamp(0, 1 << 30);
    return baseAttack + (extra * hpLostRatio);
  }

  void _replaceUniqueEffect(
    BattleState battleState,
    BattleEffectInstance next,
  ) {
    if (battleState.trackEffectTimeline) {
      battleState.activeEffects.removeWhere(
        (effect) => effect.canonicalEffectId == next.canonicalEffectId,
      );
    }
    battleState.addEffect(next);
  }

  String _newEffectInstanceId(
    String effectId,
    BattleState battleState, {
    String suffix = '',
  }) =>
      '$effectId:${battleState.knightTurn}:${battleState.bossTurn}:'
      '${battleState.actionIndex}:${battleState.allocateEffectSerial()}$suffix';

  int _permilFromPercent(num? raw) {
    if (raw == null) return 0;
    final value = raw.toDouble();
    if (!value.isFinite || value <= 0) return 0;
    final fraction = value <= 1.0 ? value : value / 100.0;
    return (fraction * 1000).round().clamp(0, 1000);
  }

  int _wholePercent(num? raw) {
    if (raw == null) return 0;
    final value = raw.toDouble();
    if (!value.isFinite || value <= 0) return 0;
    return value <= 1.0 ? (value * 100).round() : value.round();
  }

  double _percentValue(num? raw, {double fallback = 0.0}) {
    if (raw == null) return fallback;
    final value = raw.toDouble();
    if (!value.isFinite || value <= 0) return fallback;
    return value <= 1.0 ? value * 100.0 : value;
  }

  int _firstIntValue(
    EffectiveSkillValues values,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      if (!values.containsKey(key)) continue;
      return values.intValue(key, fallback: fallback);
    }
    return fallback;
  }

  int _percentShieldValue(
    int maxHp,
    EffectiveSkillValues values,
    List<String> keys,
  ) {
    if (maxHp <= 0) return 0;
    for (final key in keys) {
      final raw = values[key];
      if (raw == null) continue;
      final percent = raw.toDouble();
      if (!percent.isFinite || percent <= 0) continue;
      return ((maxHp * percent) / 100.0).round().clamp(0, 1 << 30);
    }
    return 0;
  }
}

abstract class _TimedTurnBackedEffect {
  String get instanceId;
  int get remainingTurns;
  set remainingTurns(int value);
}

class _TimedTurnEffect implements _TimedTurnBackedEffect {
  @override
  final String instanceId;

  @override
  int remainingTurns;

  _TimedTurnEffect({
    required this.instanceId,
    required this.remainingTurns,
  });
}

class _TimedCycloneStack implements _TimedTurnBackedEffect {
  @override
  final String instanceId;
  final double boostPercent;

  @override
  int remainingTurns;

  _TimedCycloneStack({
    required this.instanceId,
    required this.boostPercent,
    required this.remainingTurns,
  });
}

class _ElementalWeaknessStack {
  final String instanceId;
  final double damageMultiplier;
  int remainingBossActions;

  _ElementalWeaknessStack({
    required this.instanceId,
    required this.damageMultiplier,
    required this.remainingBossActions,
  });
}

class _DurableRockShieldStack {
  final String instanceId;
  final double defenseMultiplier;
  int remainingBossActions;

  _DurableRockShieldStack({
    required this.instanceId,
    required this.defenseMultiplier,
    required this.remainingBossActions,
  });
}

class _TimedCritChanceBonus {
  final String instanceId;
  final int bonusPermil;
  int remainingTurns;

  _TimedCritChanceBonus({
    required this.instanceId,
    required this.bonusPermil,
    required this.remainingTurns,
  });
}

enum _PendingPetAttackOverrideKind {
  shadowSlash,
  revengeStrike,
  vampiricAttack,
}

class _PendingPetAttackOverride {
  final _PendingPetAttackOverrideKind kind;
  final int fixedAttack;
  final int attackCap;
  final int stealPercent;

  const _PendingPetAttackOverride._({
    required this.kind,
    this.fixedAttack = 0,
    this.attackCap = 0,
    this.stealPercent = 0,
  });

  factory _PendingPetAttackOverride.shadowSlash({
    required int fixedAttack,
  }) =>
      _PendingPetAttackOverride._(
        kind: _PendingPetAttackOverrideKind.shadowSlash,
        fixedAttack: fixedAttack,
      );

  factory _PendingPetAttackOverride.revengeStrike({
    required int attackCap,
  }) =>
      _PendingPetAttackOverride._(
        kind: _PendingPetAttackOverrideKind.revengeStrike,
        attackCap: attackCap,
      );

  factory _PendingPetAttackOverride.vampiricAttack({
    required int fixedAttack,
    required int stealPercent,
  }) =>
      _PendingPetAttackOverride._(
        kind: _PendingPetAttackOverrideKind.vampiricAttack,
        fixedAttack: fixedAttack,
        stealPercent: stealPercent,
      );
}

class _SoulBurnDot {
  final String instanceId;
  final int damagePerBossAction;
  int remainingBossActions;

  _SoulBurnDot({
    required this.instanceId,
    required this.damagePerBossAction,
    required this.remainingBossActions,
  });
}
