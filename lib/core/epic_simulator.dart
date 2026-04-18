// lib/core/epic_simulator.dart
//
// Epic Boss simulator (core). Uses the same combat rules as normal modes,
// but supports a variable number of knights (up to 5).
// ignore_for_file: unused_element

import 'dart:math' as math;

import '../data/config_models.dart';
import '../data/pet_effect_models.dart';
import 'debug/debug_hooks.dart';
import 'engine/battle_engine.dart';
import 'engine/battle_state.dart';
import 'engine/engine_common.dart';
import 'pet_ticks_bar.dart';
import 'sim_types.dart';

class EpicKnight {
  final double atk;
  final double def;
  final int hp;
  final double adv;
  final double stun; // 0..1
  final bool elementMatch;

  const EpicKnight({
    required this.atk,
    required this.def,
    required this.hp,
    required this.adv,
    required this.stun,
    required this.elementMatch,
  });
}

class EpicPrecomputed {
  final BossMeta meta;
  final EpicBossRow boss;

  final List<double> bossAdv;

  final List<double> kAtk;
  final List<double> kDef;
  final List<int> kHp;
  final List<double> kAdv;
  final List<double> kStun;
  final double petAtk;
  final double petAdv;
  final PetSkillUsageMode petSkillUsage;
  final List<PetResolvedEffect> petEffects;

  final List<int> kNormalDmg;
  final List<int> kCritDmg;
  final List<int> kSpecialDmg;
  final int petNormalDmg;
  final int petCritDmg;

  final List<int> bNormalDmg;
  final List<int> bCritDmg;

  const EpicPrecomputed({
    required this.meta,
    required this.boss,
    required this.bossAdv,
    required this.kAtk,
    required this.kDef,
    required this.kHp,
    required this.kAdv,
    required this.kStun,
    this.petAtk = 0.0,
    this.petAdv = 1.0,
    this.petSkillUsage = PetSkillUsageMode.special1Only,
    this.petEffects = const <PetResolvedEffect>[],
    required this.kNormalDmg,
    required this.kCritDmg,
    required this.kSpecialDmg,
    this.petNormalDmg = 0,
    this.petCritDmg = 0,
    required this.bNormalDmg,
    required this.bCritDmg,
  });

  int get kCount => kHp.length;
}

class EpicSimResult {
  final int wins;
  final int runs;

  const EpicSimResult({
    required this.wins,
    required this.runs,
  });

  double get winRate => (runs <= 0) ? 0.0 : (wins / runs);
}

class EpicLevelResult {
  final int level;
  final bool missing;
  final int knightsUsed;
  final EpicSimResult primary;
  final EpicSimResult? upgraded;
  final List<double?> winRates; // index 0 => 1 knight

  const EpicLevelResult({
    required this.level,
    required this.missing,
    required this.knightsUsed,
    required this.primary,
    required this.upgraded,
    required this.winRates,
  });
}

class EpicRunResults {
  final List<EpicLevelResult> levels;
  final int maxKnights;
  final int threshold;
  final int runsPerLevel;

  const EpicRunResults({
    required this.levels,
    required this.maxKnights,
    required this.threshold,
    required this.runsPerLevel,
  });
}

typedef EpicProgressCallback = void Function(double done, int total);

class EpicSimulator {
  static const double _knightBaseConst = 164.0;
  static const double _legacyBossBaseConst = 120.0;

  static const double _defaultCritMult = 1.5;
  static const double _defaultSpecialMult = 3.25;

  static double _resolvedBossBaseConst(BossMeta meta) {
    final cycle = meta.cycleMultiplier;
    if (!cycle.isFinite || cycle <= 1.0) return _legacyBossBaseConst;
    final resolved = _knightBaseConst / cycle;
    if (!resolved.isFinite || resolved <= 0) return _legacyBossBaseConst;
    return resolved;
  }

  static EpicPrecomputed precompute({
    required EpicBossRow boss,
    required BossMeta meta,
    required List<EpicKnight> knights,
    double petAtk = 0.0,
    double petAdv = 1.0,
    PetSkillUsageMode petSkillUsage = PetSkillUsageMode.special1Only,
    List<PetResolvedEffect> petEffects = const <PetResolvedEffect>[],
  }) {
    final kAtk = <double>[];
    final kDef = <double>[];
    final kHp = <int>[];
    final kAdv = <double>[];
    final kStun = <double>[];

    final double dmgBonusMult = _epicDamageBonusMultiplier(
      meta.epicBossDamageBonus,
      knights.length,
    );

    for (final k in knights) {
      kAtk.add(k.atk);
      kDef.add(k.def);
      kHp.add(k.hp);
      kAdv.add(_advMul(k.adv));
      kStun.add(k.stun.clamp(0.0, 1.0));
    }

    final bossAdv = _normalizeAdvList(meta.advVsKnights, knights.length);

    final kNormal = <int>[];
    final kCrit = <int>[];
    final kSpec = <int>[];

    final bNormal = <int>[];
    final bCrit = <int>[];

    final critMult = meta.criticalMultiplier <= 0
        ? _defaultCritMult
        : meta.criticalMultiplier;
    // Raid and Blitz use the same knight special multiplier.
    final specialMult = meta.raidSpecialMultiplier <= 0
        ? _defaultSpecialMult
        : meta.raidSpecialMultiplier;

    for (int i = 0; i < knights.length; i++) {
      final rawK = _rawDamage(
            atk: kAtk[i],
            def: boss.defense,
            baseConst: _knightBaseConst,
            adv: kAdv[i],
          ) *
          dmgBonusMult;
      kNormal.add(_normalDamage(rawK));
      kCrit.add(_critDamage(rawK, critMult));
      kSpec.add(_specialDamage(rawK, specialMult));

      final rawB = _rawDamage(
        atk: boss.attack,
        def: kDef[i],
        baseConst: _resolvedBossBaseConst(meta),
        adv: bossAdv[i],
      );
      bNormal.add(_bossNormalDamage(rawB));
      bCrit.add(_bossCritDamage(rawB, critMult));
    }

    final rawPet = _rawDamage(
          atk: petAtk <= 0 ? 0.0 : petAtk,
          def: boss.defense,
          baseConst: _knightBaseConst,
          adv: _advMul(petAdv),
        ) *
        dmgBonusMult;
    final petNormal = (petAtk <= 0) ? 0 : _normalDamage(rawPet);
    final petCrit = (petAtk <= 0) ? 0 : _critDamage(rawPet, critMult);

    return EpicPrecomputed(
      meta: meta,
      boss: boss,
      bossAdv: bossAdv,
      kAtk: kAtk,
      kDef: kDef,
      kHp: kHp,
      kAdv: kAdv,
      kStun: kStun,
      petAtk: petAtk,
      petAdv: petAdv,
      petSkillUsage: petSkillUsage,
      petEffects: petEffects,
      kNormalDmg: kNormal,
      kCritDmg: kCrit,
      kSpecialDmg: kSpec,
      petNormalDmg: petNormal,
      petCritDmg: petCrit,
      bNormalDmg: bNormal,
      bCritDmg: bCrit,
    );
  }

  static Future<EpicSimResult> simulateLevel({
    required EpicPrecomputed pre,
    required ShatterShieldConfig shatter,
    bool cycloneUseGemsForSpecials = true,
    required int runs,
    int? seed,
    int? chunkSize,
    EpicProgressCallback? onProgress,
    bool yieldToUi = false,
    double progressBase = 0.0,
    double progressSpan = 1.0,
    int progressTotal = 100,
  }) async {
    if (runs <= 0) {
      return const EpicSimResult(wins: 0, runs: 0);
    }

    final prepared = _prepareEpicBattleSeed(
      pre: pre,
      shatter: shatter,
      cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
    );

    final rng = FastRng(seed ?? DateTime.now().microsecondsSinceEpoch);
    int wins = 0;

    var step = runs;
    if (chunkSize != null && chunkSize > 0) {
      step = chunkSize;
      if (step < 1) step = 1;
      if (step > runs) step = runs;
    }

    for (int i = 0; i < runs; i++) {
      final pts =
          const RaidBlitzBattleEngine().runWithRng(prepared.seed, rng).points;

      if (pts >= pre.boss.hp) wins += 1;

      final done = i + 1;
      if (onProgress != null && (done % step == 0 || done == runs)) {
        final frac = done / runs;
        final progress = progressBase + (frac * progressSpan);
        onProgress(progress, progressTotal);
        if (yieldToUi) {
          await Future<void>.delayed(Duration.zero);
        }
      }
    }

    return EpicSimResult(wins: wins, runs: runs);
  }

  static Future<EpicRunResults> runThresholdSimulation({
    required Map<int, EpicBossRow> table,
    required BossMeta meta,
    required List<EpicKnight> knights,
    double petAtk = 0.0,
    double petAdv = 1.0,
    PetSkillUsageMode petSkillUsage = PetSkillUsageMode.special1Only,
    List<PetResolvedEffect> petEffects = const <PetResolvedEffect>[],
    required int threshold,
    required int runsPerLevel,
    required ShatterShieldConfig shatter,
    bool cycloneUseGemsForSpecials = true,
    EpicProgressCallback? onProgress,
    bool yieldToUi = false,
  }) async {
    final out = <EpicLevelResult>[];
    final maxKnights = knights.length;
    const totalLevels = 100;
    onProgress?.call(0.0, totalLevels);

    int currentKnights = 1;
    for (int level = 1; level <= totalLevels; level++) {
      final winRates = List<double?>.filled(maxKnights, null, growable: false);
      final row = table[level];
      if (row == null) {
        out.add(
          EpicLevelResult(
            level: level,
            missing: true,
            knightsUsed: currentKnights,
            primary: const EpicSimResult(wins: 0, runs: 0),
            upgraded: null,
            winRates: winRates,
          ),
        );
        onProgress?.call(level.toDouble(), totalLevels);
        if (yieldToUi) {
          await Future<void>.delayed(Duration.zero);
        }
      } else {
        if (currentKnights > 1) {
          for (int i = 0; i < currentKnights - 1; i++) {
            winRates[i] = 0.0;
          }
        }

        var chunkSize = (runsPerLevel + 39) ~/ 40;
        if (chunkSize < 1) chunkSize = 1;
        if (chunkSize > runsPerLevel) chunkSize = runsPerLevel;
        final bool canUpgrade = currentKnights < maxKnights;
        final double primarySpan = canUpgrade ? 0.5 : 1.0;

        final baseKnights =
            knights.take(currentKnights).toList(growable: false);
        final pre = precompute(
          boss: row,
          meta: meta,
          knights: baseKnights,
          petAtk: petAtk,
          petAdv: petAdv,
          petSkillUsage: petSkillUsage,
          petEffects: petEffects,
        );
        final primary = await simulateLevel(
          pre: pre,
          shatter: shatter,
          cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
          runs: runsPerLevel,
          chunkSize: chunkSize,
          onProgress: onProgress,
          yieldToUi: yieldToUi,
          progressBase: level - 1,
          progressSpan: primarySpan,
          progressTotal: totalLevels,
        );
        winRates[currentKnights - 1] = primary.winRate;

        EpicSimResult? upgraded;
        if (primary.winRate * 100 < threshold && canUpgrade) {
          final nextKnights =
              knights.take(currentKnights + 1).toList(growable: false);
          final pre2 = precompute(
            boss: row,
            meta: meta,
            knights: nextKnights,
            petAtk: petAtk,
            petAdv: petAdv,
            petSkillUsage: petSkillUsage,
            petEffects: petEffects,
          );
          upgraded = await simulateLevel(
            pre: pre2,
            shatter: shatter,
            cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
            runs: runsPerLevel,
            chunkSize: chunkSize,
            onProgress: onProgress,
            yieldToUi: yieldToUi,
            progressBase: (level - 1) + 0.5,
            progressSpan: 0.5,
            progressTotal: totalLevels,
          );
          winRates[currentKnights] = upgraded.winRate;
          currentKnights += 1;
        } else if (canUpgrade) {
          onProgress?.call(level.toDouble(), totalLevels);
        }

        out.add(
          EpicLevelResult(
            level: level,
            missing: false,
            knightsUsed: currentKnights,
            primary: primary,
            upgraded: upgraded,
            winRates: winRates,
          ),
        );
      }
    }

    return EpicRunResults(
      levels: out,
      maxKnights: maxKnights,
      threshold: threshold,
      runsPerLevel: runsPerLevel,
    );
  }
}

class _PreparedEpicBattleSeed {
  final BattleEngineSeed seed;

  const _PreparedEpicBattleSeed({
    required this.seed,
  });
}

_PreparedEpicBattleSeed _prepareEpicBattleSeed({
  required EpicPrecomputed pre,
  required ShatterShieldConfig shatter,
  required bool cycloneUseGemsForSpecials,
}) {
  final effectivePre = Precomputed(
    meta: pre.meta,
    stats: BossStats(
      attack: pre.boss.attack,
      defense: pre.boss.defense,
      hp: pre.boss.hp,
    ),
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
    petNormalDmg: pre.petNormalDmg,
    petCritDmg: pre.petCritDmg,
    bNormalDmg: pre.bNormalDmg,
    bCritDmg: pre.bCritDmg,
  );

  return _PreparedEpicBattleSeed(
    seed: BattleEngineSeed(
      pre: effectivePre,
      runtimeKnobs: BattleRuntimeKnobs(
        cycloneAlwaysGemEnabled: cycloneUseGemsForSpecials,
        knightPetElementMatches: List<bool>.unmodifiable(shatter.elementMatch),
        petStrongVsBossByKnight:
            List<bool>.unmodifiable(shatter.strongElementEw),
      ),
    ),
  );
}

// ----------------- helpers -----------------

double _advMul(double adv) {
  if ((adv - 1.5).abs() < 1e-9) return 1.5;
  if ((adv - 2.0).abs() < 1e-9) return 2.0;
  return 1.0;
}

double _epicDamageBonusMultiplier(double bonusPerKnight, int knights) {
  if (bonusPerKnight <= 0 || knights <= 1) return 1.0;
  return 1.0 + (bonusPerKnight * (knights - 1));
}

List<double> _normalizeAdvList(List<double> raw, int len) {
  final out = <double>[];
  for (final v in raw) {
    out.add(_advMul(v));
  }
  while (out.length < len) {
    out.add(1.0);
  }
  if (out.length > len) out.length = len;
  return out;
}

int _clampInt(num v) {
  final x = v.toInt();
  if (x < 0) return 0;
  if (x > (1 << 30)) return (1 << 30);
  return x;
}

double _rawDamage({
  required double atk,
  required double def,
  required double baseConst,
  required double adv,
}) {
  final d = (def <= 0) ? 1.0 : def;
  return ((atk / d) * baseConst) * adv;
}

int _normalDamage(double raw) => _clampInt(raw.round());
int _critDamage(double raw, double critMult) =>
    _clampInt((raw * critMult).ceil());
int _specialDamage(double raw, double specialMult) {
  final base = raw.round();
  return _clampInt((base * specialMult).round());
}

int _bossNormalDamage(double raw) => _clampInt(raw.floor());
int _bossCritDamage(double raw, double critMult) {
  final base = raw.floor();
  return _clampInt((base * critMult).round());
}

int _evadePermil(BossMeta meta) =>
    (meta.evasionChance * 1000).round().clamp(0, 1000);

int _critPermil(BossMeta meta) =>
    (meta.criticalChance * 1000).round().clamp(0, 1000);

int _stunPermil(EpicPrecomputed pre, int kIdx) =>
    (pre.kStun[kIdx] * 1000).round().clamp(0, 1000);

bool _matchAt(List<bool> match, int idx) =>
    idx >= 0 && idx < match.length && match[idx];

int _bossDamage(
  EpicPrecomputed pre,
  int kIdx, {
  required bool crit,
  required double defMultiplier,
}) {
  final d = pre.kDef[kIdx] * defMultiplier;
  final def = d <= 0 ? 1.0 : d;
  final adv = pre.bossAdv[kIdx];
  final raw = ((pre.boss.attack / def) *
          EpicSimulator._resolvedBossBaseConst(pre.meta)) *
      adv;
  final critMult = pre.meta.criticalMultiplier <= 0
      ? EpicSimulator._defaultCritMult
      : pre.meta.criticalMultiplier;
  if (crit) {
    final base = raw.floor();
    return _clampInt((base * critMult).round());
  }
  return _clampInt(raw.floor());
}

class _EpicPetAttackResult {
  final int damage;
  final bool missed;
  final bool crit;

  const _EpicPetAttackResult({
    required this.damage,
    required this.missed,
    required this.crit,
  });
}

_EpicPetAttackResult _petAttack(EpicPrecomputed pre, FastRng rng) {
  if (pre.petAtk <= 0 || (pre.petNormalDmg <= 0 && pre.petCritDmg <= 0)) {
    return const _EpicPetAttackResult(damage: 0, missed: true, crit: false);
  }
  final int rMiss = rng.nextPermil();
  if (rMiss < _evadePermil(pre.meta)) {
    return const _EpicPetAttackResult(damage: 0, missed: true, crit: false);
  }
  final int rCrit = rng.nextPermil();
  final bool pCrit = (rCrit < _critPermil(pre.meta));
  return _EpicPetAttackResult(
    damage: pCrit ? pre.petCritDmg : pre.petNormalDmg,
    missed: false,
    crit: pCrit,
  );
}

const String _epicModeNormal = 'normal';
const String _epicModeSpecialRegen = 'specialRegen';
const String _epicModeSpecialRegenPlusEw = 'specialRegenPlusEw';
const String _epicModeSpecialRegenEw = 'specialRegenEw';
const String _epicModeShatterShield = 'shatterShield';
const String _epicModeCycloneBoost = 'cycloneBoost';
const String _epicModeDurableRockShield = 'durableRockShield';

bool _petBarEnabledForMode(EpicPrecomputed pre, String mode) {
  final cfg = pre.meta.petTicksBar;
  if (!cfg.enabled || !cfg.useInEpic) return false;
  return switch (mode) {
    _epicModeNormal => cfg.useInNormal,
    _epicModeSpecialRegen => cfg.useInSpecialRegen,
    _epicModeSpecialRegenPlusEw => cfg.useInSpecialRegenPlusEw,
    _epicModeSpecialRegenEw => cfg.useInSpecialRegenEw,
    _epicModeShatterShield => cfg.useInShatterShield,
    _epicModeCycloneBoost => cfg.useInCycloneBoost,
    _epicModeDurableRockShield => cfg.useInDurableRockShield,
    _ => false,
  };
}

// ----------------- modes (epic) -----------------

int _runNormal(EpicPrecomputed pre, FastRng rng) {
  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;

  int kIdx = 0;
  int kHp = pre.kHp[0];
  final int kCount = pre.kCount;
  final PetTicksBarRuntime? petBar = _petBarEnabledForMode(pre, _epicModeNormal)
      ? PetTicksBarRuntime(
          config: pre.meta.petTicksBar,
          policy: PetTicksBarPolicy.special2Only,
        )
      : null;

  while (true) {
    final petSpecialCastThisTurn = petBar?.consumeQueuedCast() != null;
    knightTurn += 1;
    final bool doSpecial = (knightTurn % pre.meta.knightToSpecial == 0);
    bool knightMiss = false;

    if (doSpecial) {
      final int dmg = pre.kSpecialDmg[kIdx];
      points += dmg;
      if (points >= pre.boss.hp) return points;

      final int sp = _stunPermil(pre, kIdx);
      if (sp > 0 && rng.nextPermil() < sp) {
        bossStun += 1;
      }
    } else {
      if (rng.nextPermil() < _evadePermil(pre.meta)) {
        // miss
        knightMiss = true;
      } else {
        final bool kCrit = (rng.nextPermil() < _critPermil(pre.meta));
        final int dmg = kCrit ? pre.kCritDmg[kIdx] : pre.kNormalDmg[kIdx];
        points += dmg;
        if (points >= pre.boss.hp) return points;

        final int sp = _stunPermil(pre, kIdx);
        if (sp > 0 && rng.nextPermil() < sp) {
          bossStun += 1;
        }
      }
    }

    if (!petSpecialCastThisTurn) {
      final pet = _petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.boss.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: knightMiss,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      petBar?.onBossStun(rng);
      continue;
    }

    bossTurn += 1;
    final bool bossSpecial = (bossTurn % pre.meta.bossToSpecial == 0);

    if (bossSpecial) {
      final int bdmg = pre.bCritDmg[kIdx];
      petBar?.onBossSpecial(rng);
      kHp -= bdmg;
      if (kHp > 0) continue;

      kIdx += 1;
      if (kIdx >= kCount) break;
      kHp = pre.kHp[kIdx];
      continue;
    }

    if (rng.nextPermil() < _evadePermil(pre.meta)) {
      petBar?.onBossMiss(rng);
      continue;
    }

    final bool bCrit = (rng.nextPermil() < _critPermil(pre.meta));
    final int bdmg = bCrit ? pre.bCritDmg[kIdx] : pre.bNormalDmg[kIdx];
    petBar?.onBossNormal(rng);

    kHp -= bdmg;
    if (kHp > 0) continue;

    kIdx += 1;
    if (kIdx >= kCount) break;
    kHp = pre.kHp[kIdx];
  }

  return points;
}

int _runSpecialRegen(
    EpicPrecomputed pre, FastRng rng, List<bool> elementMatch) {
  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;

  int kIdx = 0;
  int kHp = pre.kHp[0];
  final int kCount = pre.kCount;
  final petBarEnabled = _petBarEnabledForMode(pre, _epicModeSpecialRegen);
  if (petBarEnabled &&
      pre.meta.petTicksBar.requireFirstKnightMatchForSrModes &&
      elementMatch.isNotEmpty &&
      !elementMatch.first) {
    throw ArgumentError('first_knight_pet_match_required');
  }
  final PetTicksBarRuntime? petBar = petBarEnabled
      ? PetTicksBarRuntime(
          config: pre.meta.petTicksBar,
          policy: PetTicksBarPolicy.special2Only,
        )
      : null;
  final int srFrom = pre.meta.knightToSpecialSR;
  final bool hasAnyNonMatching =
      elementMatch.any((match) => !match) && elementMatch.isNotEmpty;
  final int recastTurns = pre.meta.knightToRecastSpecialSR <= 0
      ? 13
      : pre.meta.knightToRecastSpecialSR;
  final int? secondSrAt = hasAnyNonMatching ? (srFrom + recastTurns) : null;
  int srStacks = 0;

  while (true) {
    final petCast = petBar?.consumeQueuedCast();
    final bool petSpecialCastThisTurn = petCast != null;
    if (petCast == PetSpecialCastKind.special2) {
      srStacks += 1;
    }

    knightTurn += 1;
    if (!petBarEnabled && (knightTurn == srFrom || knightTurn == secondSrAt)) {
      if (_matchAt(elementMatch, kIdx)) {
        srStacks += 1;
      }
    }
    final bool srActivatedThisTurn =
        !petBarEnabled && (knightTurn == srFrom || knightTurn == secondSrAt);
    final int neededStacks = _matchAt(elementMatch, kIdx) ? 1 : 2;
    final bool infiniteSpecial = srStacks >= neededStacks;
    final bool scheduledSpecial = (pre.meta.knightToSpecial > 0 &&
        (knightTurn % pre.meta.knightToSpecial == 0));
    bool knightMiss = false;

    if (infiniteSpecial || scheduledSpecial) {
      final int dmg = pre.kSpecialDmg[kIdx];
      points += dmg;
      if (points >= pre.boss.hp) return points;

      final int sp = _stunPermil(pre, kIdx);
      if (sp > 0 && rng.nextPermil() < sp) {
        bossStun += 1;
      }
    } else {
      if (rng.nextPermil() < _evadePermil(pre.meta)) {
        // miss
        knightMiss = true;
      } else {
        final bool kCrit = (rng.nextPermil() < _critPermil(pre.meta));
        final int dmg = kCrit ? pre.kCritDmg[kIdx] : pre.kNormalDmg[kIdx];
        points += dmg;
        if (points >= pre.boss.hp) return points;

        final int sp = _stunPermil(pre, kIdx);
        if (sp > 0 && rng.nextPermil() < sp) {
          bossStun += 1;
        }
      }
    }

    final allowPetAction =
        !petSpecialCastThisTurn && (petBarEnabled || !srActivatedThisTurn);
    if (allowPetAction) {
      final pet = _petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.boss.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: knightMiss,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      petBar?.onBossStun(rng);
      continue;
    }

    bossTurn += 1;
    final bool bossSpecial = (bossTurn % pre.meta.bossToSpecial == 0);

    if (bossSpecial) {
      final int bdmg = pre.bCritDmg[kIdx];
      petBar?.onBossSpecial(rng);
      kHp -= bdmg;
      if (kHp > 0) continue;

      kIdx += 1;
      if (kIdx >= kCount) break;
      kHp = pre.kHp[kIdx];
      continue;
    }

    if (rng.nextPermil() < _evadePermil(pre.meta)) {
      petBar?.onBossMiss(rng);
      continue;
    }

    final bool bCrit = (rng.nextPermil() < _critPermil(pre.meta));
    final int bdmg = bCrit ? pre.bCritDmg[kIdx] : pre.bNormalDmg[kIdx];
    petBar?.onBossNormal(rng);

    kHp -= bdmg;
    if (kHp > 0) continue;

    kIdx += 1;
    if (kIdx >= kCount) break;
    kHp = pre.kHp[kIdx];
  }

  return points;
}

int _runSpecialRegenPlusEw(
  EpicPrecomputed pre,
  FastRng rng,
  List<bool> elementMatch,
  List<bool> strongElementEw,
) {
  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;

  int kIdx = 0;
  int kHp = pre.kHp[0];
  final int kCount = pre.kCount;
  final petBarEnabled = _petBarEnabledForMode(pre, _epicModeSpecialRegenPlusEw);
  if (petBarEnabled &&
      pre.meta.petTicksBar.requireFirstKnightMatchForSrModes &&
      elementMatch.isNotEmpty &&
      !elementMatch.first) {
    throw ArgumentError('first_knight_pet_match_required');
  }
  final int srFrom = pre.meta.knightToSpecialSREW;
  final bool hasAnyNonMatching =
      elementMatch.any((match) => !match) && elementMatch.isNotEmpty;
  final int recastTurns = pre.meta.knightToRecastSpecialSREW <= 0
      ? 13
      : pre.meta.knightToRecastSpecialSREW;
  final int? secondSrAt = hasAnyNonMatching ? (srFrom + recastTurns) : null;
  final int ewFrom = secondSrAt ?? srFrom;
  int srStacks = 0;
  final PetTicksBarRuntime? petBar = petBarEnabled
      ? PetTicksBarRuntime(
          config: pre.meta.petTicksBar,
          policy: PetTicksBarPolicy.special2ThenSpecial1,
          requiredSpecial2BeforeSpecial1: hasAnyNonMatching ? 2 : 1,
        )
      : null;

  final int ewEvery = pre.meta.hitsToElementalWeakness;
  final int ewDur = pre.meta.durationElementalWeakness;
  final double ewBase = pre.meta.defaultElementalWeakness;
  final double ewStrongMult = pre.meta.strongElementEW;

  int nextEwAt = ewFrom + ewEvery;

  final bool ewEnabled = petBarEnabled
      ? (ewDur > 0 && ewBase > 0)
      : (ewEvery > 0 && ewDur > 0 && ewBase > 0);
  final buckets = ewEnabled
      ? List<double>.filled(ewDur, 1.0, growable: false)
      : const <double>[];
  final stackBuckets =
      ewEnabled ? List<int>.filled(ewDur, 0, growable: false) : const <int>[];
  int ewStacks = 0;
  double ewDamageMult = 1.0;

  bool isStrongAt(int idx) =>
      idx >= 0 && idx < strongElementEw.length && strongElementEw[idx];

  void ewApply(int activeKnightIndex) {
    if (!ewEnabled) return;
    final baseReduction = ewBase.clamp(0.0, 0.999999);
    final strong = isStrongAt(activeKnightIndex);
    final strongStacks = strong ? ewStrongMult.round().clamp(1, 10) : 1;
    final exponent = elementalWeaknessExponent(
      petStrongVsBoss: strong,
      baseReduction: baseReduction,
      strongElementEw: ewStrongMult,
    );
    final applyMult = math.pow(1.0 - baseReduction, exponent).toDouble();
    buckets[ewDur - 1] = buckets[ewDur - 1] * applyMult;
    stackBuckets[ewDur - 1] = stackBuckets[ewDur - 1] + strongStacks;
    ewStacks += strongStacks;
    ewDamageMult *= applyMult;
    if (!ewDamageMult.isFinite || ewDamageMult < 0) ewDamageMult = 0;
    if (ewDamageMult > 1) ewDamageMult = 1;
  }

  void ewTick() {
    if (!ewEnabled || ewStacks == 0) return;
    final expired = buckets[0];
    final expiredStacks = stackBuckets[0];
    if (expired > 0) {
      ewDamageMult /= expired;
      if (!ewDamageMult.isFinite || ewDamageMult < 0) ewDamageMult = 0;
      if (ewDamageMult > 1) ewDamageMult = 1;
    }
    if (expiredStacks > 0) ewStacks -= expiredStacks;
    for (int i = 0; i < ewDur - 1; i++) {
      buckets[i] = buckets[i + 1];
      stackBuckets[i] = stackBuckets[i + 1];
    }
    buckets[ewDur - 1] = 1;
    stackBuckets[ewDur - 1] = 0;
  }

  int bossDmg(int base) {
    if (!ewEnabled || ewStacks <= 0) return base;
    final mult = ewDamageMult;
    if (mult <= 0) return 1;
    final v = (base * mult).floor();
    return v < 1 ? 1 : v;
  }

  while (true) {
    final petCast = petBar?.consumeQueuedCast();
    final bool petSpecialCastThisTurn = petCast != null;
    if (petCast == PetSpecialCastKind.special2) {
      srStacks += 1;
    }

    knightTurn += 1;
    if (!petBarEnabled && (knightTurn == srFrom || knightTurn == secondSrAt)) {
      if (_matchAt(elementMatch, kIdx)) {
        srStacks += 1;
      }
    }
    final bool srActivatedThisTurn =
        !petBarEnabled && (knightTurn == srFrom || knightTurn == secondSrAt);

    bool ewTriggeredThisTurn = false;
    if (petBarEnabled) {
      if (petCast == PetSpecialCastKind.special1) {
        ewApply(kIdx);
        ewTriggeredThisTurn = true;
      }
    } else if (ewEnabled && knightTurn >= ewFrom && knightTurn == nextEwAt) {
      ewApply(kIdx);
      nextEwAt += ewEvery;
      ewTriggeredThisTurn = true;
    }

    final int neededStacks = _matchAt(elementMatch, kIdx) ? 1 : 2;
    final bool infiniteSpecial = srStacks >= neededStacks;
    final bool scheduledSpecial = (pre.meta.knightToSpecial > 0 &&
        (knightTurn % pre.meta.knightToSpecial == 0));
    bool knightMiss = false;

    if (infiniteSpecial || scheduledSpecial) {
      final int dmg = pre.kSpecialDmg[kIdx];
      points += dmg;
      if (points >= pre.boss.hp) return points;

      final int sp = _stunPermil(pre, kIdx);
      if (sp > 0 && rng.nextPermil() < sp) {
        bossStun += 1;
      }
    } else {
      if (rng.nextPermil() < _evadePermil(pre.meta)) {
        // miss
        knightMiss = true;
      } else {
        final bool kCrit = (rng.nextPermil() < _critPermil(pre.meta));
        final int dmg = kCrit ? pre.kCritDmg[kIdx] : pre.kNormalDmg[kIdx];
        points += dmg;
        if (points >= pre.boss.hp) return points;

        final int sp = _stunPermil(pre, kIdx);
        if (sp > 0 && rng.nextPermil() < sp) {
          bossStun += 1;
        }
      }
    }

    final allowPetAction = !petSpecialCastThisTurn &&
        (petBarEnabled || (!srActivatedThisTurn && !ewTriggeredThisTurn));
    if (allowPetAction) {
      final pet = _petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.boss.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: knightMiss,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      petBar?.onBossStun(rng);
      ewTick();
      continue;
    }

    bossTurn += 1;
    final bool bossSpecial = (bossTurn % pre.meta.bossToSpecial == 0);

    if (bossSpecial) {
      final int bdmg = bossDmg(pre.bCritDmg[kIdx]);
      petBar?.onBossSpecial(rng);
      ewTick();

      kHp -= bdmg;
      if (kHp > 0) continue;

      kIdx += 1;
      if (kIdx >= kCount) break;
      kHp = pre.kHp[kIdx];
      continue;
    }

    if (rng.nextPermil() < _evadePermil(pre.meta)) {
      petBar?.onBossMiss(rng);
      continue;
    }

    final bool bCrit = (rng.nextPermil() < _critPermil(pre.meta));
    final int base = bCrit ? pre.bCritDmg[kIdx] : pre.bNormalDmg[kIdx];
    final int bdmg = bossDmg(base);
    petBar?.onBossNormal(rng);
    ewTick();

    kHp -= bdmg;
    if (kHp > 0) continue;

    kIdx += 1;
    if (kIdx >= kCount) break;
    kHp = pre.kHp[kIdx];
  }

  return points;
}

int _runOldSimulator(EpicPrecomputed pre, FastRng rng) {
  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;

  int kIdx = 0;
  int kHp = pre.kHp[0];
  final int kCount = pre.kCount;
  final int fakeDiv = pre.meta.bossToSpecialFakeEW;
  final PetTicksBarRuntime? petBar =
      _petBarEnabledForMode(pre, _epicModeSpecialRegenEw)
          ? PetTicksBarRuntime(
              config: pre.meta.petTicksBar,
              policy: PetTicksBarPolicy.special2Only,
            )
          : null;

  while (true) {
    final petSpecialCastThisTurn = petBar?.consumeQueuedCast() != null;
    knightTurn += 1;
    final bool srActivatedThisTurn = knightTurn == 1;
    final int dmg = pre.kSpecialDmg[kIdx];
    points += dmg;
    if (points >= pre.boss.hp) return points;

    final int sp = _stunPermil(pre, kIdx);
    if (sp > 0 && rng.nextPermil() < sp) {
      bossStun += 1;
    }

    final allowPetAction =
        !petSpecialCastThisTurn && (petBar != null || !srActivatedThisTurn);
    if (allowPetAction) {
      final pet = _petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.boss.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: false,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      petBar?.onBossStun(rng);
      continue;
    }

    bossTurn += 1;
    if (fakeDiv > 0 && (bossTurn % fakeDiv == 0)) {
      // no-op
    }

    if (rng.nextPermil() < _evadePermil(pre.meta)) {
      petBar?.onBossMiss(rng);
      continue;
    }

    final bool bCrit = (rng.nextPermil() < _critPermil(pre.meta));
    final int bdmg = bCrit ? pre.bCritDmg[kIdx] : pre.bNormalDmg[kIdx];
    petBar?.onBossNormal(rng);

    kHp -= bdmg;
    if (kHp > 0) continue;

    kIdx += 1;
    if (kIdx >= kCount) break;
    kHp = pre.kHp[kIdx];
  }

  return points;
}

int _runShatterShield(
  EpicPrecomputed pre,
  FastRng rng,
  ShatterShieldConfig shatter,
) {
  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;

  int kIdx = 0;
  int kHp = pre.kHp[0];
  final int kCount = pre.kCount;
  final petBarEnabled = _petBarEnabledForMode(pre, _epicModeShatterShield);
  final PetTicksBarRuntime? petBar = petBarEnabled
      ? PetTicksBarRuntime(
          config: pre.meta.petTicksBar,
          policy: PetTicksBarPolicy.special2Only,
        )
      : null;
  int shatterCount = 0;
  int nextShatter = pre.meta.hitsToFirstShatter;
  final int step = pre.meta.hitsToNextShatter;

  while (true) {
    knightTurn += 1;
    bool didMiss = false;
    bool shatterTriggeredThisTurn = false;
    final petCast = petBar?.consumeQueuedCast();
    final bool petSpecialCastThisTurn = petCast != null;

    if (petCast == PetSpecialCastKind.special2) {
      shatterTriggeredThisTurn = true;
      final int add = shatter.baseHp +
          (_matchAt(shatter.elementMatch, kIdx) ? shatter.bonusHp : 0);
      kHp += add;
    }

    final bool doSpecial = (knightTurn % pre.meta.knightToSpecial == 0);

    if (doSpecial) {
      final int dmg = pre.kSpecialDmg[kIdx];
      points += dmg;
      if (points >= pre.boss.hp) return points;

      final int sp = _stunPermil(pre, kIdx);
      if (sp > 0 && rng.nextPermil() < sp) {
        bossStun += 1;
      }
    } else {
      if (rng.nextPermil() < _evadePermil(pre.meta)) {
        // miss
        didMiss = true;
      } else {
        final bool kCrit = (rng.nextPermil() < _critPermil(pre.meta));
        final int dmg = kCrit ? pre.kCritDmg[kIdx] : pre.kNormalDmg[kIdx];
        points += dmg;
        if (points >= pre.boss.hp) return points;

        final int sp = _stunPermil(pre, kIdx);
        if (sp > 0 && rng.nextPermil() < sp) {
          bossStun += 1;
        }
      }
    }

    final bool countShatter = !petBarEnabled && !didMiss;
    if (countShatter) {
      shatterCount += 1;
      if (shatterCount == nextShatter) {
        shatterTriggeredThisTurn = true;
        final int add = shatter.baseHp +
            (_matchAt(shatter.elementMatch, kIdx) ? shatter.bonusHp : 0);
        kHp += add;
        nextShatter += step;
      }
    }

    final allowPetAction = !petSpecialCastThisTurn &&
        (petBar != null || !shatterTriggeredThisTurn);
    if (allowPetAction) {
      final pet = _petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.boss.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: didMiss,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      petBar?.onBossStun(rng);
      continue;
    }

    bossTurn += 1;
    final bool bossSpecial = (bossTurn % pre.meta.bossToSpecial == 0);

    if (bossSpecial) {
      final int bdmg = pre.bCritDmg[kIdx];
      petBar?.onBossSpecial(rng);
      kHp -= bdmg;
      if (kHp > 0) continue;

      kIdx += 1;
      if (kIdx >= kCount) break;
      kHp = pre.kHp[kIdx];
      continue;
    }

    if (rng.nextPermil() < _evadePermil(pre.meta)) {
      petBar?.onBossMiss(rng);
      continue;
    }

    final bool bCrit = (rng.nextPermil() < _critPermil(pre.meta));
    final int bdmg = bCrit ? pre.bCritDmg[kIdx] : pre.bNormalDmg[kIdx];
    petBar?.onBossNormal(rng);

    kHp -= bdmg;
    if (kHp > 0) continue;

    kIdx += 1;
    if (kIdx >= kCount) break;
    kHp = pre.kHp[kIdx];
  }

  return points;
}

int _runCycloneBoost(
  EpicPrecomputed pre,
  FastRng rng, {
  required double boostPct,
  required bool useGemsForSpecials,
}) {
  if (useGemsForSpecials) {
    return _runCycloneBoostAlwaysGemmed(
      pre,
      rng,
      boostPct: boostPct,
    );
  }
  return _runCycloneBoostPetBarDriven(
    pre,
    rng,
    boostPct: boostPct,
  );
}

int _runCycloneBoostAlwaysGemmed(
  EpicPrecomputed pre,
  FastRng rng, {
  required double boostPct,
}) {
  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;

  int kIdx = 0;
  int kHp = pre.kHp[0];
  final int kCount = pre.kCount;
  final PetTicksBarRuntime? petBar =
      _petBarEnabledForMode(pre, _epicModeCycloneBoost)
          ? PetTicksBarRuntime(
              config: pre.meta.petTicksBar,
              policy: PetTicksBarPolicy.special2Only,
            )
          : null;

  final double stepMult = 1.0 + (boostPct / 100.0);

  while (true) {
    final petSpecialCastThisTurn = petBar?.consumeQueuedCast() != null;
    knightTurn += 1;
    final bool cycloneActivatedThisTurn = knightTurn == 1;
    final int t = (knightTurn <= 5) ? knightTurn : 5;
    final double mult = _powN(stepMult, t);
    final int dmg = (pre.kSpecialDmg[kIdx] * mult).ceil();
    points += dmg;
    if (points >= pre.boss.hp) return points;

    final int sp = _stunPermil(pre, kIdx);
    if (sp > 0 && rng.nextPermil() < sp) {
      bossStun += 1;
    }

    final allowPetAction = !petSpecialCastThisTurn &&
        (petBar != null || !cycloneActivatedThisTurn);
    if (allowPetAction) {
      final pet = _petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.boss.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: false,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      petBar?.onBossStun(rng);
      continue;
    }

    bossTurn += 1;
    final bool bossSpecial = (bossTurn % pre.meta.bossToSpecial == 0);

    if (bossSpecial) {
      final int bdmg = pre.bCritDmg[kIdx];
      petBar?.onBossSpecial(rng);
      kHp -= bdmg;
      if (kHp > 0) continue;

      kIdx += 1;
      if (kIdx >= kCount) break;
      kHp = pre.kHp[kIdx];
      continue;
    }

    if (rng.nextPermil() < _evadePermil(pre.meta)) {
      petBar?.onBossMiss(rng);
      continue;
    }

    final bool bCrit = (rng.nextPermil() < _critPermil(pre.meta));
    final int bdmg = bCrit ? pre.bCritDmg[kIdx] : pre.bNormalDmg[kIdx];
    petBar?.onBossNormal(rng);

    kHp -= bdmg;
    if (kHp > 0) continue;

    kIdx += 1;
    if (kIdx >= kCount) break;
    kHp = pre.kHp[kIdx];
  }

  return points;
}

int _runCycloneBoostPetBarDriven(
  EpicPrecomputed pre,
  FastRng rng, {
  required double boostPct,
}) {
  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;
  int cycloneStacks = 0;

  int kIdx = 0;
  int kHp = pre.kHp[0];
  final int kCount = pre.kCount;
  final PetTicksBarRuntime? petBar =
      _petBarEnabledForMode(pre, _epicModeCycloneBoost)
          ? PetTicksBarRuntime(
              config: pre.meta.petTicksBar,
              policy: PetTicksBarPolicyFromUsage.fromSkillUsage(
                pre.petSkillUsage,
              ),
            )
          : null;

  while (true) {
    final petCast = petBar?.consumeQueuedCast();
    final petSpecialCastThisTurn = petCast != null;
    if (petCast != null) {
      cycloneStacks = nextCycloneStacks(
        currentStacks: cycloneStacks,
        triggeredByPetCast: cycloneSelectedForCast(pre.petEffects, petCast),
        maxStacks: resolvedCycloneBoostTurns(
          pre.petEffects,
          fallback: 5,
        ),
      );
    }

    knightTurn += 1;
    final bool doSpecial = (knightTurn % pre.meta.knightToSpecial == 0);
    final int currentStacks = cycloneStacks.clamp(0, 5);
    bool knightMiss = false;

    if (doSpecial) {
      final int dmg = boostedKnightDamage(
        pre.kSpecialDmg[kIdx],
        boostPct: boostPct,
        cycloneStacks: currentStacks,
      );
      points += dmg;
      if (points >= pre.boss.hp) return points;

      final int sp = _stunPermil(pre, kIdx);
      if (sp > 0 && rng.nextPermil() < sp) {
        bossStun += 1;
      }
    } else {
      if (rng.nextPermil() >= _evadePermil(pre.meta)) {
        final bool kCrit = (rng.nextPermil() < _critPermil(pre.meta));
        final int dmg = boostedKnightDamage(
          kCrit ? pre.kCritDmg[kIdx] : pre.kNormalDmg[kIdx],
          boostPct: boostPct,
          cycloneStacks: currentStacks,
        );
        points += dmg;
        if (points >= pre.boss.hp) return points;

        final int sp = _stunPermil(pre, kIdx);
        if (sp > 0 && rng.nextPermil() < sp) {
          bossStun += 1;
        }
      } else {
        knightMiss = true;
      }
    }

    if (!petSpecialCastThisTurn) {
      final pet = _petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.boss.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: knightMiss,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      petBar?.onBossStun(rng);
      continue;
    }

    bossTurn += 1;
    final bool bossSpecial = (bossTurn % pre.meta.bossToSpecial == 0);

    if (bossSpecial) {
      final int bdmg = pre.bCritDmg[kIdx];
      petBar?.onBossSpecial(rng);
      kHp -= bdmg;
      if (kHp > 0) continue;

      kIdx += 1;
      if (kIdx >= kCount) break;
      kHp = pre.kHp[kIdx];
      continue;
    }

    if (rng.nextPermil() < _evadePermil(pre.meta)) {
      petBar?.onBossMiss(rng);
      continue;
    }

    final bool bCrit = (rng.nextPermil() < _critPermil(pre.meta));
    final int bdmg = bCrit ? pre.bCritDmg[kIdx] : pre.bNormalDmg[kIdx];
    petBar?.onBossNormal(rng);

    kHp -= bdmg;
    if (kHp > 0) continue;

    kIdx += 1;
    if (kIdx >= kCount) break;
    kHp = pre.kHp[kIdx];
  }

  return points;
}

int _runDurableRockShield(
  EpicPrecomputed pre,
  FastRng rng,
  List<bool> elementMatch,
) {
  int points = 0;
  int bossStun = 0;
  int bossTurn = 0;
  int knightTurn = 0;

  int kIdx = 0;
  int kHp = pre.kHp[0];
  final int kCount = pre.kCount;
  final PetTicksBarRuntime? petBar =
      _petBarEnabledForMode(pre, _epicModeDurableRockShield)
          ? PetTicksBarRuntime(
              config: pre.meta.petTicksBar,
              policy: PetTicksBarPolicyFromUsage.fromSkillUsage(
                pre.petSkillUsage,
              ),
            )
          : null;

  final int drsEvery = pre.meta.hitsToDRS;
  final int drsDuration = pre.meta.durationDRS;
  int nextDrsAt = (drsEvery > 0) ? drsEvery : 1 << 30;
  int drsTurnsLeft = 0;
  double drsBaseBoost = 0.0;
  bool drsHasMatch = false;

  void applyDrs() {
    if (drsEvery <= 0 || drsDuration <= 0) return;
    drsTurnsLeft = drsDuration;
    drsBaseBoost = pre.meta.defaultDurableRockShield;
    drsHasMatch = _matchAt(elementMatch, kIdx);
  }

  while (true) {
    final petCast = petBar?.consumeQueuedCast();
    final petSpecialCastThisTurn = petCast != null;
    knightTurn += 1;
    bool drsTriggeredThisTurn = false;
    if (petBar != null && petCast != null) {
      applyDrs();
      drsTriggeredThisTurn = true;
    } else if (petBar == null && knightTurn == nextDrsAt) {
      applyDrs();
      nextDrsAt += drsEvery;
      drsTriggeredThisTurn = true;
    }
    final bool doSpecial = (knightTurn % pre.meta.knightToSpecial == 0);
    bool knightMiss = false;

    if (doSpecial) {
      final int dmg = pre.kSpecialDmg[kIdx];
      points += dmg;
      if (points >= pre.boss.hp) return points;

      final int sp = _stunPermil(pre, kIdx);
      if (sp > 0 && rng.nextPermil() < sp) {
        bossStun += 1;
      }
    } else {
      if (rng.nextPermil() < _evadePermil(pre.meta)) {
        // miss
        knightMiss = true;
      } else {
        final bool kCrit = (rng.nextPermil() < _critPermil(pre.meta));
        final int dmg = kCrit ? pre.kCritDmg[kIdx] : pre.kNormalDmg[kIdx];
        points += dmg;
        if (points >= pre.boss.hp) return points;

        final int sp = _stunPermil(pre, kIdx);
        if (sp > 0 && rng.nextPermil() < sp) {
          bossStun += 1;
        }
      }
    }

    final allowPetAction =
        !petSpecialCastThisTurn && (petBar != null || !drsTriggeredThisTurn);
    if (allowPetAction) {
      final pet = _petAttack(pre, rng);
      if (pet.damage > 0) {
        points += pet.damage;
        if (points >= pre.boss.hp) return points;
      }
      petBar?.onKnightPetResolved(
        knightMiss: knightMiss,
        petMiss: pet.missed,
        petCrit: pet.crit,
        rng: rng,
      );
    }

    if (bossStun > 0) {
      bossStun -= 1;
      petBar?.onBossStun(rng);
      continue;
    }

    bossTurn += 1;
    final bool drsActive = (drsTurnsLeft > 0 && drsBaseBoost > 0);
    final double defMult = drsActive
        ? _drsDefenseMultiplier(
            baseBoostFraction: drsBaseBoost,
            elementMatch: drsHasMatch,
            sameElementMultiplier: pre.meta.sameElementDRS,
          )
        : 1.0;

    final bool bossSpecial = (bossTurn % pre.meta.bossToSpecial == 0);

    if (bossSpecial) {
      final int bdmg = _bossDamage(
        pre,
        kIdx,
        crit: true,
        defMultiplier: defMult,
      );
      petBar?.onBossSpecial(rng);

      if (drsTurnsLeft > 0) drsTurnsLeft -= 1;

      kHp -= bdmg;
      if (kHp > 0) continue;

      kIdx += 1;
      if (kIdx >= kCount) break;

      kHp = pre.kHp[kIdx];
      drsTurnsLeft = 0;
      drsBaseBoost = 0.0;
      drsHasMatch = false;
      continue;
    }

    if (rng.nextPermil() < _evadePermil(pre.meta)) {
      petBar?.onBossMiss(rng);
      if (drsTurnsLeft > 0) drsTurnsLeft -= 1;
      continue;
    }

    final bool bCrit = (rng.nextPermil() < _critPermil(pre.meta));
    final int bdmg = _bossDamage(
      pre,
      kIdx,
      crit: bCrit,
      defMultiplier: defMult,
    );
    petBar?.onBossNormal(rng);

    if (drsTurnsLeft > 0) drsTurnsLeft -= 1;

    kHp -= bdmg;
    if (kHp > 0) continue;

    kIdx += 1;
    if (kIdx >= kCount) break;

    kHp = pre.kHp[kIdx];
    drsTurnsLeft = 0;
    drsBaseBoost = 0.0;
    drsHasMatch = false;
  }

  return points;
}

double _drsDefenseMultiplier({
  required double baseBoostFraction,
  required bool elementMatch,
  required double sameElementMultiplier,
}) {
  final baseBoost = baseBoostFraction.clamp(0.0, 10.0);
  final sameMult = sameElementMultiplier <= 0 ? 1.0 : sameElementMultiplier;
  final effectiveBoost = baseBoost * (elementMatch ? sameMult : 1.0);
  final nonlinearDef = _powN(1.0 + effectiveBoost, 2);
  final matchAmplifier = elementMatch ? sameMult : 1.0;
  final out = nonlinearDef * matchAmplifier;
  if (!out.isFinite || out <= 0) return 1.0;
  return out;
}

double _powN(double base, int n) {
  if (n <= 0) return 1.0;
  double r = 1.0;
  for (int i = 0; i < n; i++) {
    r *= base;
  }
  return r;
}
