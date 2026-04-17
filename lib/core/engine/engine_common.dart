import 'dart:math' as math;

import '../../data/config_models.dart';
import '../../data/pet_effect_models.dart';
import '../debug/debug_hooks.dart';
import '../sim_types.dart';
import '../timing_acc.dart';
import 'skill_catalog.dart';

const double bossBaseConst = 120.0;
const double _pythonBossBaseConst = 164.0;
const double _ewStrongPotencyScale = 0.8;
const double _ewStrongExponentCap = 2.8;

double bossBaseConstForMeta(BossMeta meta) {
  final cycle = meta.cycleMultiplier;
  // Keep backward compatibility for synthetic/test metas that leave the
  // multiplier at 1.0 while still enabling calibrated hidden multipliers.
  if (!cycle.isFinite || cycle <= 1.0) return bossBaseConst;
  final resolved = _pythonBossBaseConst / cycle;
  if (!resolved.isFinite || resolved <= 0) return bossBaseConst;
  return resolved;
}

double elementalWeaknessExponent({
  required bool petStrongVsBoss,
  required double baseReduction,
  required double strongElementEw,
}) {
  if (!petStrongVsBoss) return 1.0;

  final reduction = baseReduction.clamp(0.0, 0.999999);
  if (reduction <= 0.0) return 1.0;

  final strongWeight = strongElementEw.isFinite ? strongElementEw : 1.0;
  if (strongWeight <= 0) return 1.0;

  final potency = reduction / (1.0 - reduction);
  final exponent = 1.0 + (strongWeight * potency * _ewStrongPotencyScale);
  if (!exponent.isFinite || exponent <= 0) return 1.0;
  return exponent.clamp(1.0, _ewStrongExponentCap);
}

int evadePermil(Precomputed pre) =>
    (pre.meta.evasionChance * 1000).round().clamp(0, 1000);

int critPermil(Precomputed pre) =>
    (pre.meta.criticalChance * 1000).round().clamp(0, 1000);

int stunPermil(Precomputed pre, int kIdx) =>
    (pre.kStun[kIdx] * 1000).round().clamp(0, 1000);

double advMul(double adv) {
  if ((adv - 1.5).abs() < 1e-9) return 1.5;
  if ((adv - 2.0).abs() < 1e-9) return 2.0;
  return 1.0;
}

int clampInt(num value) {
  final out = value.toInt();
  if (out < 0) return 0;
  if (out > (1 << 30)) return (1 << 30);
  return out;
}

double powN(double base, int exponent) {
  if (exponent <= 0) return 1.0;
  double out = 1.0;
  for (int i = 0; i < exponent; i++) {
    out *= base;
  }
  return out;
}

double drsDefenseMultiplier({
  required double baseBoostFraction,
  required bool elementMatch,
  required double sameElementMultiplier,
}) {
  final baseBoost = baseBoostFraction.clamp(0.0, 10.0);
  final sameMult = sameElementMultiplier <= 0 ? 1.0 : sameElementMultiplier;
  final effectiveBoost = baseBoost * (elementMatch ? sameMult : 1.0);
  final nonlinearDef = math.pow(1.0 + effectiveBoost, 2.0).toDouble();
  final matchAmplifier = elementMatch ? sameMult : 1.0;
  final out = nonlinearDef * matchAmplifier;
  if (!out.isFinite || out <= 0) return 1.0;
  return out;
}

int bossDamage(
  Precomputed pre,
  int kIdx, {
  required bool crit,
  required double defMultiplier,
}) {
  final effectiveDefense = pre.kDef[kIdx] * defMultiplier;
  final defense = effectiveDefense <= 0 ? 1.0 : effectiveDefense;
  final advantage = advMul(pre.meta.advVsKnights[kIdx]);
  final raw = ((pre.stats.attack / defense) * bossBaseConstForMeta(pre.meta)) *
      advantage;
  if (!crit) return clampInt(raw.floor());
  return clampInt((raw.floor() * pre.meta.criticalMultiplier).round());
}

class PetAttackResult {
  final int damage;
  final bool missed;
  final bool crit;

  const PetAttackResult({
    required this.damage,
    required this.missed,
    required this.crit,
  });
}

double petRawDamage(
  Precomputed pre, {
  required double attack,
}) {
  final defense = pre.stats.defense <= 0 ? 1.0 : pre.stats.defense;
  return ((attack / defense) * 164.0) * advMul(pre.petAdv);
}

int petNormalDamageForAttack(
  Precomputed pre, {
  required double attack,
}) {
  if (attack <= 0) return 0;
  return clampInt(petRawDamage(pre, attack: attack).round());
}

int petCritDamageForAttack(
  Precomputed pre, {
  required double attack,
}) {
  if (attack <= 0) return 0;
  final critMultiplier =
      pre.meta.criticalMultiplier <= 0 ? 1.5 : pre.meta.criticalMultiplier;
  return clampInt((petRawDamage(pre, attack: attack) * critMultiplier).ceil());
}

PetAttackResult petAttack(
  Precomputed pre,
  FastRng rng, {
  double? attackOverride,
}) {
  final effectiveAttack = attackOverride ?? pre.petAtk;
  final normalDamage = attackOverride == null
      ? pre.petNormalDmg
      : petNormalDamageForAttack(pre, attack: effectiveAttack);
  final critDamage = attackOverride == null
      ? pre.petCritDmg
      : petCritDamageForAttack(pre, attack: effectiveAttack);

  if (effectiveAttack <= 0 || (normalDamage <= 0 && critDamage <= 0)) {
    return const PetAttackResult(damage: 0, missed: true, crit: false);
  }
  if (rng.nextPermil() < evadePermil(pre)) {
    return const PetAttackResult(damage: 0, missed: true, crit: false);
  }
  final isCrit = rng.nextPermil() < critPermil(pre);
  return PetAttackResult(
    damage: isCrit ? critDamage : normalDamage,
    missed: false,
    crit: isCrit,
  );
}

int petDamage(Precomputed pre, FastRng rng) => petAttack(pre, rng).damage;

bool castUsesSlot(String slotId, PetSpecialCastKind cast) => switch (cast) {
      PetSpecialCastKind.special1 => slotId == 'skill11' || slotId == 'skill12',
      PetSpecialCastKind.special2 => slotId == 'skill2',
    };

PetResolvedEffect? resolvedEffectForCast(
  Iterable<PetResolvedEffect> petEffects,
  String canonicalEffectId,
  PetSpecialCastKind cast,
) {
  final target =
      BattleSkillCatalog.normalizeCanonicalEffectId(canonicalEffectId);
  for (final effect in petEffects) {
    final effectId = BattleSkillCatalog.normalizeCanonicalEffectId(
      effect.canonicalEffectId,
      fallbackSkillName: effect.sourceSkillName,
    );
    if (effectId != target) continue;
    if (castUsesSlot(effect.sourceSlotId.trim().toLowerCase(), cast)) {
      return effect;
    }
  }
  return null;
}

PetResolvedEffect? resolvedEffectById(
  Iterable<PetResolvedEffect> petEffects,
  String canonicalEffectId,
) {
  final target =
      BattleSkillCatalog.normalizeCanonicalEffectId(canonicalEffectId);
  for (final effect in petEffects) {
    final effectId = BattleSkillCatalog.normalizeCanonicalEffectId(
      effect.canonicalEffectId,
      fallbackSkillName: effect.sourceSkillName,
    );
    if (effectId == target) return effect;
  }
  return null;
}

double resolvedElementalWeaknessFraction(
  Iterable<PetResolvedEffect> petEffects, {
  required double fallback,
}) {
  final effect = resolvedEffectById(
    petEffects,
    BattleSkillCatalog.elementalWeaknessId,
  );
  final raw = effect?.values['enemyAttackReductionPercent'];
  if (raw == null) return fallback;
  final value = raw.toDouble();
  if (!value.isFinite || value < 0) return fallback;
  return value <= 1.0 ? value : (value / 100.0);
}

int resolvedElementalWeaknessTurns(
  Iterable<PetResolvedEffect> petEffects, {
  required int fallback,
}) {
  final effect = resolvedEffectById(
    petEffects,
    BattleSkillCatalog.elementalWeaknessId,
  );
  final value = effect?.values['turns']?.toInt();
  if (value == null || value <= 0) return fallback;
  return value;
}

double resolvedDurableRockShieldFraction(
  Iterable<PetResolvedEffect> petEffects, {
  required double fallback,
}) {
  final effect = resolvedEffectById(
    petEffects,
    BattleSkillCatalog.durableRockShieldId,
  );
  final raw = effect?.values['defenseBoostPercent'];
  if (raw == null) return fallback;
  final value = raw.toDouble();
  if (!value.isFinite || value < 0) return fallback;
  return value <= 1.0 ? value : (value / 100.0);
}

int resolvedDurableRockShieldTurns(
  Iterable<PetResolvedEffect> petEffects, {
  required int fallback,
}) {
  final effect = resolvedEffectById(
    petEffects,
    BattleSkillCatalog.durableRockShieldId,
  );
  final value = effect?.values['turns']?.toInt();
  if (value == null || value <= 0) return fallback;
  return value;
}

double resolvedCycloneBoostPct(
  Iterable<PetResolvedEffect> petEffects, {
  required double fallback,
}) {
  final effect = resolvedEffectById(petEffects, BattleSkillCatalog.cycloneId);
  final raw = effect?.values['attackBoostPercent'];
  if (raw == null) return fallback;
  final pct = raw.toDouble();
  if (!pct.isFinite || pct < 0) return fallback;
  return pct;
}

int resolvedCycloneBoostTurns(
  Iterable<PetResolvedEffect> petEffects, {
  required int fallback,
}) {
  final effect = resolvedEffectById(petEffects, BattleSkillCatalog.cycloneId);
  final turns = effect?.values['turns']?.toInt();
  if (turns == null || turns <= 0) return fallback;
  return turns;
}

bool cycloneSelectedForCast(
  Iterable<PetResolvedEffect> petEffects,
  PetSpecialCastKind cast,
) {
  return resolvedEffectForCast(
        petEffects,
        BattleSkillCatalog.cycloneId,
        cast,
      ) !=
      null;
}

int nextCycloneStacks({
  required int currentStacks,
  required bool triggeredByPetCast,
  required int maxStacks,
}) {
  if (!triggeredByPetCast) return currentStacks.clamp(0, maxStacks);
  return (currentStacks + 1).clamp(0, maxStacks);
}

int boostedKnightDamage(
  int baseDamage, {
  required double boostPct,
  required int cycloneStacks,
}) {
  if (baseDamage <= 0) return 0;
  if (cycloneStacks <= 0 || boostPct <= 0) return baseDamage;
  final multiplier = powN(1.0 + (boostPct / 100.0), cycloneStacks);
  return clampInt((baseDamage * multiplier).ceil());
}

class EngineTimingTracker {
  EngineTimingTracker(this.timing, this.config);

  final TimingAcc timing;
  final TimingConfig config;

  void _addRun(double seconds) => timing.runSeconds += seconds;

  void knightNormal(int knightIndex) {
    final seconds = config.normalDuration;
    timing.kNormalCount[knightIndex] += 1;
    timing.kNormalSeconds[knightIndex] += seconds;
    timing.kOwnSeconds[knightIndex] += seconds;
    timing.survivalSeconds[knightIndex] += seconds;
    _addRun(seconds);
  }

  void knightSpecial(int knightIndex) {
    final seconds = config.specialDuration;
    timing.kSpecialCount[knightIndex] += 1;
    timing.kSpecialSeconds[knightIndex] += seconds;
    timing.kOwnSeconds[knightIndex] += seconds;
    timing.survivalSeconds[knightIndex] += seconds;
    _addRun(seconds);
  }

  void knightStun(int knightIndex) {
    final seconds = config.stunDuration;
    timing.kStunCount[knightIndex] += 1;
    timing.kStunSeconds[knightIndex] += seconds;
    timing.kOwnSeconds[knightIndex] += seconds;
    timing.survivalSeconds[knightIndex] += seconds;
    _addRun(seconds);
  }

  void knightMiss(int knightIndex) {
    final seconds = config.missDuration;
    timing.kMissCount[knightIndex] += 1;
    timing.kMissSeconds[knightIndex] += seconds;
    timing.kOwnSeconds[knightIndex] += seconds;
    timing.survivalSeconds[knightIndex] += seconds;
    _addRun(seconds);
  }

  void bossMiss(int knightIndex) {
    // Boss miss consumes the boss turn timing slot.
    final seconds = config.bossDuration;
    timing.bMissCount[knightIndex] += 1;
    timing.bMissSeconds[knightIndex] += seconds;
    timing.bossSeconds += seconds;
    timing.survivalSeconds[knightIndex] += seconds;
    _addRun(seconds);
  }

  void bossNormal(int knightIndex) {
    final seconds = config.bossDuration;
    timing.bNormalCount[knightIndex] += 1;
    timing.bNormalSeconds[knightIndex] += seconds;
    timing.bossSeconds += seconds;
    timing.survivalSeconds[knightIndex] += seconds;
    _addRun(seconds);
  }

  void bossSpecial(int knightIndex) {
    final seconds = config.bossSpecialDuration;
    timing.bSpecialCount[knightIndex] += 1;
    timing.bSpecialSeconds[knightIndex] += seconds;
    timing.bossSeconds += seconds;
    timing.survivalSeconds[knightIndex] += seconds;
    _addRun(seconds);
  }

  void petAttack({
    required bool missed,
    required bool crit,
  }) {
    timing.petAttacks += 1;
    if (missed) {
      timing.petMissAttacks += 1;
      return;
    }
    if (crit) {
      timing.petCritAttacks += 1;
    }
  }
}
