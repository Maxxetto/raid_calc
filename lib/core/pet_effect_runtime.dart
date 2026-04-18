import '../data/config_models.dart';
import 'debug/debug_hooks.dart';
import 'engine/engine_common.dart';
import 'sim_types.dart';

class KnightAttackResult {
  final int damage;
  final DebugAction action;
  final bool missed;
  final bool crit;
  final bool deathBlowApplied;
  final bool deathBlowConsumed;
  final int deathBlowBonus;
  final int? missRoll;
  final int? missTarget;
  final int? critRoll;
  final int? critTarget;

  const KnightAttackResult({
    required this.damage,
    required this.action,
    required this.missed,
    required this.crit,
    required this.deathBlowApplied,
    required this.deathBlowConsumed,
    required this.deathBlowBonus,
    this.missRoll,
    this.missTarget,
    this.critRoll,
    this.critTarget,
  });
}

class PetCastResolution {
  final int immediateBossDamage;
  final int knightHealPercentOfActualDamage;

  const PetCastResolution({
    required this.immediateBossDamage,
    required this.knightHealPercentOfActualDamage,
  });

  static const none = PetCastResolution(
    immediateBossDamage: 0,
    knightHealPercentOfActualDamage: 0,
  );
}

class PetEffectRuntimeState {
  PetEffectRuntimeState._({
    required this.deathBlowSpecial1Bonus,
    required this.deathBlowSpecial2Bonus,
    required this.readyToCritSpecial1BonusPermil,
    required this.readyToCritSpecial1Turns,
    required this.readyToCritSpecial2BonusPermil,
    required this.readyToCritSpecial2Turns,
    required this.shadowSlashSpecial1Attack,
    required this.shadowSlashSpecial2Attack,
    required this.revengeStrikeSpecial1Cap,
    required this.revengeStrikeSpecial2Cap,
    required this.soulBurnSpecial1DirectDamage,
    required this.soulBurnSpecial1DotDamage,
    required this.soulBurnSpecial1Turns,
    required this.soulBurnSpecial2DirectDamage,
    required this.soulBurnSpecial2DotDamage,
    required this.soulBurnSpecial2Turns,
    required this.vampiricAttackSpecial1Damage,
    required this.vampiricAttackSpecial1StealPercent,
    required this.vampiricAttackSpecial2Damage,
    required this.vampiricAttackSpecial2StealPercent,
    required int knightCount,
  })  : _pendingDeathBlowBonusByKnight =
            List<int>.filled(knightCount, 0, growable: false),
        _readyToCritStacksByKnight = List<List<_TimedCritChanceBonus>>.generate(
          knightCount,
          (_) => <_TimedCritChanceBonus>[],
          growable: false,
        ),
        _soulBurnDots = <_SoulBurnDot>[];

  final int deathBlowSpecial1Bonus;
  final int deathBlowSpecial2Bonus;
  final int readyToCritSpecial1BonusPermil;
  final int readyToCritSpecial1Turns;
  final int readyToCritSpecial2BonusPermil;
  final int readyToCritSpecial2Turns;
  final int shadowSlashSpecial1Attack;
  final int shadowSlashSpecial2Attack;
  final int revengeStrikeSpecial1Cap;
  final int revengeStrikeSpecial2Cap;
  final int soulBurnSpecial1DirectDamage;
  final int soulBurnSpecial1DotDamage;
  final int soulBurnSpecial1Turns;
  final int soulBurnSpecial2DirectDamage;
  final int soulBurnSpecial2DotDamage;
  final int soulBurnSpecial2Turns;
  final int vampiricAttackSpecial1Damage;
  final int vampiricAttackSpecial1StealPercent;
  final int vampiricAttackSpecial2Damage;
  final int vampiricAttackSpecial2StealPercent;
  final List<int> _pendingDeathBlowBonusByKnight;
  final List<List<_TimedCritChanceBonus>> _readyToCritStacksByKnight;
  final List<_SoulBurnDot> _soulBurnDots;
  _PendingPetAttackOverride? _pendingPetAttackOverride;

  factory PetEffectRuntimeState.fromPrecomputed(
    Precomputed pre, {
    required int knightCount,
  }) {
    int special1Bonus = 0;
    int special2Bonus = 0;
    int special1ShadowSlash = 0;
    int special2ShadowSlash = 0;
    int special1RevengeStrike = 0;
    int special2RevengeStrike = 0;
    int special1ReadyToCritBonusPermil = 0;
    int special1ReadyToCritTurns = 0;
    int special2ReadyToCritBonusPermil = 0;
    int special2ReadyToCritTurns = 0;
    int special1SoulBurnDirectDamage = 0;
    int special1SoulBurnDotDamage = 0;
    int special1SoulBurnTurns = 0;
    int special2SoulBurnDirectDamage = 0;
    int special2SoulBurnDotDamage = 0;
    int special2SoulBurnTurns = 0;
    int special1VampiricAttackDamage = 0;
    int special1VampiricAttackStealPercent = 0;
    int special2VampiricAttackDamage = 0;
    int special2VampiricAttackStealPercent = 0;
    for (final effect in pre.petEffects) {
      switch (effect.canonicalEffectId) {
        case 'death_blow':
          final bonus =
              (effect.effectSpec['bonusFlatDamage'] as num?)?.toInt() ?? 0;
          if (_isSpecial1Slot(effect.sourceSlotId)) {
            special1Bonus = bonus;
          } else if (effect.sourceSlotId == 'skill2') {
            special2Bonus = bonus;
          }
        case 'shadow_slash':
          final attack = effect.values['petAttack']?.toInt() ?? 0;
          if (_isSpecial1Slot(effect.sourceSlotId)) {
            special1ShadowSlash = attack;
          } else if (effect.sourceSlotId == 'skill2') {
            special2ShadowSlash = attack;
          }
        case 'revenge_strike':
          final cap = effect.values['petAttackCap']?.toInt() ?? 0;
          if (_isSpecial1Slot(effect.sourceSlotId)) {
            special1RevengeStrike = cap;
          } else if (effect.sourceSlotId == 'skill2') {
            special2RevengeStrike = cap;
          }
        case 'ready_to_crit':
          final bonusPercent =
              effect.values['critChancePercent']?.toDouble() ?? 0.0;
          final turns = effect.values['turns']?.toInt() ?? 0;
          final bonusPermil = (bonusPercent * 10).round().clamp(0, 1000);
          if (_isSpecial1Slot(effect.sourceSlotId)) {
            special1ReadyToCritBonusPermil = bonusPermil;
            special1ReadyToCritTurns = turns;
          } else if (effect.sourceSlotId == 'skill2') {
            special2ReadyToCritBonusPermil = bonusPermil;
            special2ReadyToCritTurns = turns;
          }
        case 'soul_burn':
          final directDamage = effect.values['flatDamage']?.toInt() ?? 0;
          final dotDamage = effect.values['damageOverTime']?.toInt() ?? 0;
          final turns = effect.values['turns']?.toInt() ?? 0;
          if (_isSpecial1Slot(effect.sourceSlotId)) {
            special1SoulBurnDirectDamage = directDamage;
            special1SoulBurnDotDamage = dotDamage;
            special1SoulBurnTurns = turns;
          } else if (effect.sourceSlotId == 'skill2') {
            special2SoulBurnDirectDamage = directDamage;
            special2SoulBurnDotDamage = dotDamage;
            special2SoulBurnTurns = turns;
          }
        case 'vampiric_attack':
          final directDamage = effect.values['flatDamage']?.toInt() ?? 0;
          final stealPercent = effect.values['stealPercent']?.toInt() ?? 0;
          if (_isSpecial1Slot(effect.sourceSlotId)) {
            special1VampiricAttackDamage = directDamage;
            special1VampiricAttackStealPercent = stealPercent;
          } else if (effect.sourceSlotId == 'skill2') {
            special2VampiricAttackDamage = directDamage;
            special2VampiricAttackStealPercent = stealPercent;
          }
        default:
          break;
      }
    }
    return PetEffectRuntimeState._(
      deathBlowSpecial1Bonus: special1Bonus,
      deathBlowSpecial2Bonus: special2Bonus,
      readyToCritSpecial1BonusPermil: special1ReadyToCritBonusPermil,
      readyToCritSpecial1Turns: special1ReadyToCritTurns,
      readyToCritSpecial2BonusPermil: special2ReadyToCritBonusPermil,
      readyToCritSpecial2Turns: special2ReadyToCritTurns,
      shadowSlashSpecial1Attack: special1ShadowSlash,
      shadowSlashSpecial2Attack: special2ShadowSlash,
      revengeStrikeSpecial1Cap: special1RevengeStrike,
      revengeStrikeSpecial2Cap: special2RevengeStrike,
      soulBurnSpecial1DirectDamage: special1SoulBurnDirectDamage,
      soulBurnSpecial1DotDamage: special1SoulBurnDotDamage,
      soulBurnSpecial1Turns: special1SoulBurnTurns,
      soulBurnSpecial2DirectDamage: special2SoulBurnDirectDamage,
      soulBurnSpecial2DotDamage: special2SoulBurnDotDamage,
      soulBurnSpecial2Turns: special2SoulBurnTurns,
      vampiricAttackSpecial1Damage: special1VampiricAttackDamage,
      vampiricAttackSpecial1StealPercent: special1VampiricAttackStealPercent,
      vampiricAttackSpecial2Damage: special2VampiricAttackDamage,
      vampiricAttackSpecial2StealPercent: special2VampiricAttackStealPercent,
      knightCount: knightCount,
    );
  }

  bool get hasEffects =>
      deathBlowSpecial1Bonus > 0 ||
      deathBlowSpecial2Bonus > 0 ||
      readyToCritSpecial1BonusPermil > 0 ||
      readyToCritSpecial2BonusPermil > 0 ||
      shadowSlashSpecial1Attack > 0 ||
      shadowSlashSpecial2Attack > 0 ||
      revengeStrikeSpecial1Cap > 0 ||
      revengeStrikeSpecial2Cap > 0 ||
      soulBurnSpecial1DirectDamage > 0 ||
      soulBurnSpecial2DirectDamage > 0 ||
      vampiricAttackSpecial1Damage > 0 ||
      vampiricAttackSpecial2Damage > 0;

  PetCastResolution onPetCast({
    required PetSpecialCastKind cast,
    required int activeKnightIndex,
  }) {
    if (activeKnightIndex < 0 ||
        activeKnightIndex >= _pendingDeathBlowBonusByKnight.length) {
      return PetCastResolution.none;
    }
    final bonus = switch (cast) {
      PetSpecialCastKind.special1 => deathBlowSpecial1Bonus,
      PetSpecialCastKind.special2 => deathBlowSpecial2Bonus,
    };
    if (bonus > 0) {
      _pendingDeathBlowBonusByKnight[activeKnightIndex] = bonus;
    }
    final readyToCrit = switch (cast) {
      PetSpecialCastKind.special1 => _readyToCritForSpecial1(),
      PetSpecialCastKind.special2 => _readyToCritForSpecial2(),
    };
    if (readyToCrit != null) {
      _readyToCritStacksByKnight[activeKnightIndex].add(readyToCrit);
    }

    final petAttackOverride = switch (cast) {
      PetSpecialCastKind.special1 => _petOverrideForSpecial1(),
      PetSpecialCastKind.special2 => _petOverrideForSpecial2(),
    };
    if (petAttackOverride != null) {
      _pendingPetAttackOverride = petAttackOverride;
    }
    return _buildPetCastResolution(cast);
  }

  KnightAttackResult resolveKnightAttack(
    Precomputed pre,
    FastRng rng, {
    required int kIdx,
    required bool doSpecial,
    required int Function(Precomputed pre) evadePermil,
    required int Function(Precomputed pre) critPermil,
  }) {
    final pendingBonus = _pendingDeathBlowBonusByKnight[kIdx];

    if (doSpecial) {
      if (pendingBonus > 0) {
        _pendingDeathBlowBonusByKnight[kIdx] = 0;
      }
      return _afterKnightAction(
        kIdx,
        KnightAttackResult(
          damage: pre.kSpecialDmg[kIdx],
          action: DebugAction.special,
          missed: false,
          crit: false,
          deathBlowApplied: false,
          deathBlowConsumed: pendingBonus > 0,
          deathBlowBonus: 0,
        ),
      );
    }

    final missTarget = evadePermil(pre);
    final missRoll = rng.nextPermil();
    if (missRoll < missTarget) {
      if (pendingBonus > 0) {
        _pendingDeathBlowBonusByKnight[kIdx] = 0;
      }
      return _afterKnightAction(
        kIdx,
        KnightAttackResult(
          damage: 0,
          action: DebugAction.miss,
          missed: true,
          crit: false,
          deathBlowApplied: false,
          deathBlowConsumed: pendingBonus > 0,
          deathBlowBonus: 0,
          missRoll: missRoll,
          missTarget: missTarget,
        ),
      );
    }

    if (pendingBonus > 0) {
      _pendingDeathBlowBonusByKnight[kIdx] = 0;
      return _afterKnightAction(
        kIdx,
        KnightAttackResult(
          damage: pre.kCritDmg[kIdx] + pendingBonus,
          action: DebugAction.crit,
          missed: false,
          crit: true,
          deathBlowApplied: true,
          deathBlowConsumed: true,
          deathBlowBonus: pendingBonus,
          missRoll: missRoll,
          missTarget: missTarget,
        ),
      );
    }

    final critTarget =
        (critPermil(pre) + _readyToCritBonusPermil(kIdx)).clamp(0, 1000);
    final critRoll = rng.nextPermil();
    final isCrit = critRoll < critTarget;
    return _afterKnightAction(
      kIdx,
      KnightAttackResult(
        damage: isCrit ? pre.kCritDmg[kIdx] : pre.kNormalDmg[kIdx],
        action: isCrit ? DebugAction.crit : DebugAction.normal,
        missed: false,
        crit: isCrit,
        deathBlowApplied: false,
        deathBlowConsumed: false,
        deathBlowBonus: 0,
        missRoll: missRoll,
        missTarget: missTarget,
        critRoll: critRoll,
        critTarget: critTarget,
      ),
    );
  }

  PetAttackResult resolvePetAttack(
    Precomputed pre,
    FastRng rng, {
    required int activeKnightIndex,
    required int currentKnightHp,
  }) {
    final override = _pendingPetAttackOverride;
    if (override == null) {
      return petAttack(pre, rng);
    }
    _pendingPetAttackOverride = null;

    final overrideAttack = switch (override.kind) {
      _PendingPetAttackOverrideKind.shadowSlash =>
        override.fixedAttack.toDouble(),
      _PendingPetAttackOverrideKind.revengeStrike => _revengeStrikeAttack(
          pre,
          activeKnightIndex: activeKnightIndex,
          currentKnightHp: currentKnightHp,
          attackCap: override.attackCap,
        ),
    };

    return petAttack(
      pre,
      rng,
      attackOverride: overrideAttack,
    );
  }

  int onBossActionResolved() {
    if (_soulBurnDots.isEmpty) return 0;
    var damage = 0;
    for (final dot in _soulBurnDots) {
      damage += dot.damagePerBossAction;
      dot.remainingBossActions -= 1;
    }
    _soulBurnDots.removeWhere((dot) => dot.remainingBossActions <= 0);
    return damage;
  }

  static bool _isSpecial1Slot(String slotId) =>
      slotId == 'skill11' || slotId == 'skill12';

  _PendingPetAttackOverride? _petOverrideForSpecial1() {
    if (shadowSlashSpecial1Attack > 0) {
      return _PendingPetAttackOverride.shadowSlash(
        fixedAttack: shadowSlashSpecial1Attack,
      );
    }
    if (revengeStrikeSpecial1Cap > 0) {
      return _PendingPetAttackOverride.revengeStrike(
        attackCap: revengeStrikeSpecial1Cap,
      );
    }
    return null;
  }

  _PendingPetAttackOverride? _petOverrideForSpecial2() {
    if (shadowSlashSpecial2Attack > 0) {
      return _PendingPetAttackOverride.shadowSlash(
        fixedAttack: shadowSlashSpecial2Attack,
      );
    }
    if (revengeStrikeSpecial2Cap > 0) {
      return _PendingPetAttackOverride.revengeStrike(
        attackCap: revengeStrikeSpecial2Cap,
      );
    }
    return null;
  }

  _TimedCritChanceBonus? _readyToCritForSpecial1() {
    if (readyToCritSpecial1BonusPermil <= 0 || readyToCritSpecial1Turns <= 0) {
      return null;
    }
    return _TimedCritChanceBonus(
      bonusPermil: readyToCritSpecial1BonusPermil,
      remainingTurns: readyToCritSpecial1Turns,
    );
  }

  _TimedCritChanceBonus? _readyToCritForSpecial2() {
    if (readyToCritSpecial2BonusPermil <= 0 || readyToCritSpecial2Turns <= 0) {
      return null;
    }
    return _TimedCritChanceBonus(
      bonusPermil: readyToCritSpecial2BonusPermil,
      remainingTurns: readyToCritSpecial2Turns,
    );
  }

  PetCastResolution _buildPetCastResolution(PetSpecialCastKind cast) {
    final (soulBurnDirectDamage, soulBurnDotDamage, soulBurnTurns) =
        switch (cast) {
      PetSpecialCastKind.special1 => (
          soulBurnSpecial1DirectDamage,
          soulBurnSpecial1DotDamage,
          soulBurnSpecial1Turns,
        ),
      PetSpecialCastKind.special2 => (
          soulBurnSpecial2DirectDamage,
          soulBurnSpecial2DotDamage,
          soulBurnSpecial2Turns,
        ),
    };
    if (soulBurnDotDamage > 0 && soulBurnTurns > 0) {
      _soulBurnDots.add(
        _SoulBurnDot(
          damagePerBossAction: soulBurnDotDamage,
          remainingBossActions: soulBurnTurns,
        ),
      );
    }
    final (vampiricDamage, vampiricStealPercent) = switch (cast) {
      PetSpecialCastKind.special1 => (
          vampiricAttackSpecial1Damage,
          vampiricAttackSpecial1StealPercent,
        ),
      PetSpecialCastKind.special2 => (
          vampiricAttackSpecial2Damage,
          vampiricAttackSpecial2StealPercent,
        ),
    };

    return PetCastResolution(
      immediateBossDamage: soulBurnDirectDamage + vampiricDamage,
      knightHealPercentOfActualDamage: vampiricStealPercent,
    );
  }

  int _readyToCritBonusPermil(int kIdx) {
    if (kIdx < 0 || kIdx >= _readyToCritStacksByKnight.length) return 0;
    return _readyToCritStacksByKnight[kIdx].fold<int>(
      0,
      (sum, stack) => sum + stack.bonusPermil,
    );
  }

  KnightAttackResult _afterKnightAction(int kIdx, KnightAttackResult result) {
    if (kIdx < 0 || kIdx >= _readyToCritStacksByKnight.length) return result;
    final stacks = _readyToCritStacksByKnight[kIdx];
    if (stacks.isEmpty) return result;
    for (final stack in stacks) {
      stack.remainingTurns -= 1;
    }
    stacks.removeWhere((stack) => stack.remainingTurns <= 0);
    return result;
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
}

enum _PendingPetAttackOverrideKind {
  shadowSlash,
  revengeStrike,
}

class _PendingPetAttackOverride {
  final _PendingPetAttackOverrideKind kind;
  final int fixedAttack;
  final int attackCap;

  const _PendingPetAttackOverride._({
    required this.kind,
    this.fixedAttack = 0,
    this.attackCap = 0,
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
}

class _TimedCritChanceBonus {
  final int bonusPermil;
  int remainingTurns;

  _TimedCritChanceBonus({
    required this.bonusPermil,
    required this.remainingTurns,
  });
}

class _SoulBurnDot {
  final int damagePerBossAction;
  int remainingBossActions;

  _SoulBurnDot({
    required this.damagePerBossAction,
    required this.remainingBossActions,
  });
}
