// lib/core/debug/debug_run.dart
//
// Debug (Premium):
// - 1 run
// - Turn-by-turn deterministic log based on seed
// - Uses the unified battle engine + debug hooks

import 'package:flutter/foundation.dart';

import '../../data/config_models.dart';
import '../../data/pet_simulation_resolver.dart';
import '../engine/battle_engine.dart';
import '../engine/battle_state.dart';
import '../engine/legacy_mode_adapter.dart';
import '../engine/legacy_old_simulator.dart';
import '../sim_types.dart';
import 'debug_hooks.dart';

@immutable
class DebugRunResult {
  final int seed;
  final FightMode mode;
  final int points;
  final List<String> lines;

  const DebugRunResult({
    required this.seed,
    required this.mode,
    required this.points,
    required this.lines,
  });
}

class DebugSimulator {
  static DebugRunResult run(
    Precomputed pre, {
    required FightMode mode,
    required Map<String, String> labels,
    ShatterShieldConfig? shatter,
    bool cycloneUseGemsForSpecials = true,
    int? seed,
    bool includeRolls = false,
  }) {
    final s = (seed ?? (DateTime.now().microsecondsSinceEpoch & 0x7fffffff));
    final rng = FastRng(s);

    final prepared = _prepareDebugSeed(
      pre: pre,
      requestedMode: mode,
      shatter: shatter,
      cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
    );
    final effectiveMode = prepared.effectiveMode;

    final logger = _DebugLogger(
      mode: effectiveMode,
      includeRolls: includeRolls,
      labels: labels,
    );

    late final int points;

    switch (effectiveMode) {
      case FightMode.specialRegenEw:
        points = runLegacyOldSimulator(
          prepared.pre,
          rng,
          withTiming: false,
          timing: null,
          debug: logger,
        );
      case FightMode.normal:
      case FightMode.specialRegen:
      case FightMode.specialRegenPlusEw:
      case FightMode.shatterShield:
      case FightMode.cycloneBoost:
      case FightMode.durableRockShield:
        if (effectiveMode == FightMode.cycloneBoost) {
          logger.onCycloneIntro(
            boostPct: prepared.pre.meta.cyclone,
          );
        }
        final result = const RaidBlitzBattleEngine().runWithRng(
          prepared.seed,
          rng,
          debug: logger,
          petBarDebug: logger,
        );
        points = result.points;
    }

    return DebugRunResult(
      seed: s,
      mode: effectiveMode,
      points: points,
      lines: logger.lines,
    );
  }
}

class _PreparedDebugSeed {
  final Precomputed pre;
  final BattleEngineSeed seed;
  final FightMode effectiveMode;

  const _PreparedDebugSeed({
    required this.pre,
    required this.seed,
    required this.effectiveMode,
  });
}

_PreparedDebugSeed _prepareDebugSeed({
  required Precomputed pre,
  required FightMode requestedMode,
  required ShatterShieldConfig? shatter,
  required bool cycloneUseGemsForSpecials,
}) {
  final shatterCfg = shatter ??
      const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: <bool>[true, true, true],
      );
  final synthetic =
      (pre.petEffects.isEmpty && requestedMode != FightMode.specialRegenEw)
          ? LegacyModeAdapter.synthesize(
              mode: requestedMode,
              requestedUsageMode: pre.petSkillUsage,
              cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
              cycloneBoostPercent: pre.meta.cyclone,
              shatterBaseHp: shatterCfg.baseHp,
              shatterBonusHp: shatterCfg.bonusHp,
              drsDefenseBoost: pre.meta.defaultDurableRockShield,
              ewWeaknessEffect: pre.meta.defaultElementalWeakness,
            )
          : null;
  final effectivePre = synthetic == null
      ? pre
      : Precomputed(
          meta: pre.meta,
          stats: pre.stats,
          kAtk: pre.kAtk,
          kDef: pre.kDef,
          kHp: pre.kHp,
          kAdv: pre.kAdv,
          kStun: pre.kStun,
          petAtk: pre.petAtk,
          petAdv: pre.petAdv,
          petSkillUsage: synthetic.usageMode,
          petEffects: synthetic.resolvedEffects,
          kNormalDmg: pre.kNormalDmg,
          kCritDmg: pre.kCritDmg,
          kSpecialDmg: pre.kSpecialDmg,
          petNormalDmg: pre.petNormalDmg,
          petCritDmg: pre.petCritDmg,
          bNormalDmg: pre.bNormalDmg,
          bCritDmg: pre.bCritDmg,
        );
  final derivedProfile = PetSimulationResolver.deriveProfileFromResolvedEffects(
    resolvedEffects: effectivePre.petEffects,
    usageMode: effectivePre.petSkillUsage,
    legacyFallbackMode: requestedMode,
  );
  final effectiveMode =
      synthetic?.mode ?? derivedProfile.legacyEquivalentMode ?? requestedMode;
  final seed = BattleEngineSeed(
    pre: effectivePre,
    runtimeKnobs: BattleRuntimeKnobs(
      cycloneAlwaysGemEnabled: cycloneUseGemsForSpecials,
      knightPetElementMatches: List<bool>.unmodifiable(shatterCfg.elementMatch),
      petStrongVsBossByKnight:
          List<bool>.unmodifiable(shatterCfg.strongElementEw),
    ),
  );
  return _PreparedDebugSeed(
    pre: effectivePre,
    seed: seed,
    effectiveMode: effectiveMode,
  );
}

class _DebugLogger implements DebugHook, DebugPetBarHook {
  _DebugLogger({
    required this.mode,
    required this.includeRolls,
    required this.labels,
  });

  final FightMode mode;
  final bool includeRolls;
  final Map<String, String> labels;

  final List<String> lines = <String>[];

  bool get _cycloneMode => mode == FightMode.cycloneBoost;

  void _log(String s) => lines.add(s);

  String _kLabel(int kIdx) => 'K#${kIdx + 1}';

  String _t(String key, String fallbackEn) {
    final v = labels[key];
    if (v == null) return fallbackEn;
    final s = v.trim();
    return s.isEmpty ? fallbackEn : s;
  }

  String _fmt(String tpl, Map<String, String> vars) {
    var out = tpl;
    vars.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }

  @override
  void onKnightAction({
    required int knightTurn,
    required int kIdx,
    required DebugAction action,
    required int dmg,
    required int points,
    int? roll,
    int? rollTarget,
    int? critRoll,
    int? critTarget,
    int? cycloneStep,
    double? cycloneMult,
  }) {
    final act = _t(
      switch (action) {
        DebugAction.normal => 'debug.log.act.normal',
        DebugAction.crit => 'debug.log.act.crit',
        DebugAction.special => 'debug.log.act.special',
        DebugAction.miss => 'debug.log.act.miss',
      },
      switch (action) {
        DebugAction.normal => 'NORMAL',
        DebugAction.crit => 'CRIT',
        DebugAction.special => 'SPECIAL',
        DebugAction.miss => 'MISS',
      },
    );
    final pointsLabel = _t('debug.log.label.points', 'points');

    if (_cycloneMode &&
        action == DebugAction.special &&
        cycloneStep != null &&
        cycloneMult != null) {
      final tpl = _t(
        'debug.log.line.cyclone_special',
        'KT#{kt} K#{k} {act} (Cyclone {step}/5, mult={mult}) ? '
            '+{dmg} ({pointsLabel}={points})',
      );
      _log(
        _fmt(tpl, {
          'kt': knightTurn.toString(),
          'k': (kIdx + 1).toString(),
          'act': act,
          'step': cycloneStep.toString(),
          'mult': cycloneMult.toStringAsFixed(4),
          'dmg': dmg.toString(),
          'pointsLabel': pointsLabel,
          'points': points.toString(),
        }),
      );
      return;
    }

    switch (action) {
      case DebugAction.special:
        final tpl = _t(
          'debug.log.line.knight_special',
          'KT#{kt} K#{k} {act} ? +{dmg} ({pointsLabel}={points})',
        );
        _log(
          _fmt(tpl, {
            'kt': knightTurn.toString(),
            'k': (kIdx + 1).toString(),
            'act': act,
            'dmg': dmg.toString(),
            'pointsLabel': pointsLabel,
            'points': points.toString(),
          }),
        );
      case DebugAction.normal:
      case DebugAction.crit:
        if (includeRolls && critRoll != null && critTarget != null) {
          final tpl = _t(
            'debug.log.line.knight_action_roll',
            'KT#{kt} K#{k} {act} ? +{dmg} ({pointsLabel}={points}, '
                'critRoll={critRoll} < {critTarget})',
          );
          _log(
            _fmt(tpl, {
              'kt': knightTurn.toString(),
              'k': (kIdx + 1).toString(),
              'act': act,
              'dmg': dmg.toString(),
              'pointsLabel': pointsLabel,
              'points': points.toString(),
              'critRoll': critRoll.toString(),
              'critTarget': critTarget.toString(),
            }),
          );
        } else {
          final tpl = _t(
            'debug.log.line.knight_action',
            'KT#{kt} K#{k} {act} ? +{dmg} ({pointsLabel}={points})',
          );
          _log(
            _fmt(tpl, {
              'kt': knightTurn.toString(),
              'k': (kIdx + 1).toString(),
              'act': act,
              'dmg': dmg.toString(),
              'pointsLabel': pointsLabel,
              'points': points.toString(),
            }),
          );
        }
      case DebugAction.miss:
        if (includeRolls && roll != null && rollTarget != null) {
          final tpl = _t(
            'debug.log.line.knight_miss_roll',
            'KT#{kt} K#{k} MISS (roll={roll} < {target})',
          );
          _log(
            _fmt(tpl, {
              'kt': knightTurn.toString(),
              'k': (kIdx + 1).toString(),
              'roll': roll.toString(),
              'target': rollTarget.toString(),
            }),
          );
        } else {
          final tpl = _t(
            'debug.log.line.knight_miss',
            'KT#{kt} K#{k} MISS',
          );
          _log(
            _fmt(tpl, {
              'kt': knightTurn.toString(),
              'k': (kIdx + 1).toString(),
            }),
          );
        }
    }
  }

  @override
  void onKnightStun({
    required int knightTurn,
    required int kIdx,
    required bool success,
    required int roll,
    required int target,
  }) {
    if (success) {
      if (includeRolls) {
        final tpl = _t(
          'debug.log.line.knight_stun_success_roll',
          'KT#{kt} K#{k} STUN (roll={roll} < {target}) ? Boss stunned',
        );
        _log(
          _fmt(tpl, {
            'kt': knightTurn.toString(),
            'k': (kIdx + 1).toString(),
            'roll': roll.toString(),
            'target': target.toString(),
          }),
        );
      } else {
        final tpl = _t(
          'debug.log.line.knight_stun_success',
          'KT#{kt} K#{k} esegue stun ? Boss stunned',
        );
        _log(
          _fmt(tpl, {
            'kt': knightTurn.toString(),
            'k': (kIdx + 1).toString(),
          }),
        );
      }
      return;
    }

    if (includeRolls) {
      final tpl = _t(
        'debug.log.line.knight_stun_fail_roll',
        'KT#{kt} K#{k} stun fail (roll={roll} >= {target})',
      );
      _log(
        _fmt(tpl, {
          'kt': knightTurn.toString(),
          'k': (kIdx + 1).toString(),
          'roll': roll.toString(),
          'target': target.toString(),
        }),
      );
    }
  }

  @override
  void onBossSkip({
    required int queuedNow,
  }) {
    final tpl = _t(
      'debug.log.line.boss_skip',
      'Boss stunned ? skips turn (queuedNow={queued})',
    );
    _log(
      _fmt(tpl, {
        'queued': queuedNow.toString(),
      }),
    );
  }

  @override
  void onBossAction({
    required int bossTurn,
    required int kIdx,
    required DebugAction action,
    required int dmg,
    required int hpAfter,
    int? roll,
    int? rollTarget,
    int? critRoll,
    int? critTarget,
    int? baseDmg,
    int? ewStacks,
  }) {
    final target = _kLabel(kIdx);
    final act = _t(
      switch (action) {
        DebugAction.normal => 'debug.log.act.normal',
        DebugAction.crit => 'debug.log.act.crit',
        DebugAction.special => 'debug.log.act.special',
        DebugAction.miss => 'debug.log.act.miss',
      },
      switch (action) {
        DebugAction.normal => 'NORMAL',
        DebugAction.crit => 'CRIT',
        DebugAction.special => 'SPECIAL',
        DebugAction.miss => 'MISS',
      },
    );
    final hpLabel = _t('debug.log.label.hp', 'hp');
    final targetLabel = _t('debug.log.label.target', 'target');

    if (action == DebugAction.special) {
      if (baseDmg != null && ewStacks != null) {
        final tpl = _t(
          'debug.log.line.boss_special_ew',
          'BT#{bt} Boss {act} ? K#{k} -{dmg} '
              '(base={base}, EWstacks={stacks}, {hpLabel}={hp})',
        );
        _log(
          _fmt(tpl, {
            'bt': bossTurn.toString(),
            'act': act,
            'k': (kIdx + 1).toString(),
            'dmg': dmg.toString(),
            'base': baseDmg.toString(),
            'stacks': ewStacks.toString(),
            'hpLabel': hpLabel,
            'hp': hpAfter.toString(),
          }),
        );
      } else {
        final tpl = _t(
          'debug.log.line.boss_special',
          'BT#{bt} Boss {act} ? K#{k} -{dmg} ({hpLabel}={hp})',
        );
        _log(
          _fmt(tpl, {
            'bt': bossTurn.toString(),
            'act': act,
            'k': (kIdx + 1).toString(),
            'dmg': dmg.toString(),
            'hpLabel': hpLabel,
            'hp': hpAfter.toString(),
          }),
        );
      }
      return;
    }

    if (action == DebugAction.miss) {
      if (includeRolls && roll != null && rollTarget != null) {
        final tpl = _t(
          'debug.log.line.boss_miss_roll',
          'BT#{bt} Boss MISS (roll={roll} < {targetRoll}, {targetLabel}={target})',
        );
        _log(
          _fmt(tpl, {
            'bt': bossTurn.toString(),
            'roll': roll.toString(),
            'targetRoll': rollTarget.toString(),
            'targetLabel': targetLabel,
            'target': target,
          }),
        );
      } else {
        final tpl = _t(
          'debug.log.line.boss_miss',
          'BT#{bt} Boss MISS ({targetLabel}={target})',
        );
        _log(
          _fmt(tpl, {
            'bt': bossTurn.toString(),
            'targetLabel': targetLabel,
            'target': target,
          }),
        );
      }
      return;
    }

    if (baseDmg != null && ewStacks != null) {
      if (includeRolls && critRoll != null && critTarget != null) {
        final tpl = _t(
          'debug.log.line.boss_action_ew_roll',
          'BT#{bt} Boss {act} ? K#{k} -{dmg} (base={base}, '
              'EWstacks={stacks}, critRoll={critRoll} < {critTarget}, '
              '{hpLabel}={hp})',
        );
        _log(
          _fmt(tpl, {
            'bt': bossTurn.toString(),
            'act': act,
            'k': (kIdx + 1).toString(),
            'dmg': dmg.toString(),
            'base': baseDmg.toString(),
            'stacks': ewStacks.toString(),
            'critRoll': critRoll.toString(),
            'critTarget': critTarget.toString(),
            'hpLabel': hpLabel,
            'hp': hpAfter.toString(),
          }),
        );
      } else {
        final tpl = _t(
          'debug.log.line.boss_action_ew',
          'BT#{bt} Boss {act} ? K#{k} -{dmg} (base={base}, '
              'EWstacks={stacks}, {hpLabel}={hp})',
        );
        _log(
          _fmt(tpl, {
            'bt': bossTurn.toString(),
            'act': act,
            'k': (kIdx + 1).toString(),
            'dmg': dmg.toString(),
            'base': baseDmg.toString(),
            'stacks': ewStacks.toString(),
            'hpLabel': hpLabel,
            'hp': hpAfter.toString(),
          }),
        );
      }
      return;
    }

    if (includeRolls && critRoll != null && critTarget != null) {
      final tpl = _t(
        'debug.log.line.boss_action_roll',
        'BT#{bt} Boss {act} ? K#{k} -{dmg} ({hpLabel}={hp}, '
            'critRoll={critRoll} < {critTarget})',
      );
      _log(
        _fmt(tpl, {
          'bt': bossTurn.toString(),
          'act': act,
          'k': (kIdx + 1).toString(),
          'dmg': dmg.toString(),
          'hpLabel': hpLabel,
          'hp': hpAfter.toString(),
          'critRoll': critRoll.toString(),
          'critTarget': critTarget.toString(),
        }),
      );
    } else {
      final tpl = _t(
        'debug.log.line.boss_action',
        'BT#{bt} Boss {act} ? K#{k} -{dmg} ({hpLabel}={hp})',
      );
      _log(
        _fmt(tpl, {
          'bt': bossTurn.toString(),
          'act': act,
          'k': (kIdx + 1).toString(),
          'dmg': dmg.toString(),
          'hpLabel': hpLabel,
          'hp': hpAfter.toString(),
        }),
      );
    }
  }

  @override
  void onPetBarInit({
    required int ticks,
    required int ticksPerState,
  }) {
    final tpl = _t(
      'debug.log.line.pet_bar_init',
      'PET BAR init: {ticks}/{max}',
    );
    _log(_fmt(tpl,
        {'ticks': ticks.toString(), 'max': (ticksPerState * 2).toString()}));
  }

  @override
  void onPetBarFill({
    required String source,
    required int add,
    required int before,
    required int after,
    required int max,
  }) {
    final tpl = _t(
      'debug.log.line.pet_bar_fill',
      'PET BAR +{add} ({source}) : {before}->{after}/{max}',
    );
    _log(
      _fmt(tpl, {
        'add': add.toString(),
        'source': source,
        'before': before.toString(),
        'after': after.toString(),
        'max': max.toString(),
      }),
    );
  }

  @override
  void onPetBarQueued({
    required PetSpecialCastKind cast,
    required int ticks,
  }) {
    final tpl = _t(
      'debug.log.line.pet_bar_queued',
      'PET BAR queued {cast} at {ticks}',
    );
    _log(
      _fmt(tpl, {
        'cast': cast.name,
        'ticks': ticks.toString(),
      }),
    );
  }

  @override
  void onPetBarCast({
    required PetSpecialCastKind cast,
    required int before,
    required int after,
  }) {
    final tpl = _t(
      'debug.log.line.pet_bar_cast',
      'PET BAR cast {cast}: {before}->{after}',
    );
    _log(
      _fmt(tpl, {
        'cast': cast.name,
        'before': before.toString(),
        'after': after.toString(),
      }),
    );
  }

  @override
  void onKnightDied({
    required int kIdx,
  }) {
    final tpl = _t(
      'debug.log.line.knight_died',
      'K#{k} died ? FIFO switch',
    );
    _log(
      _fmt(tpl, {
        'k': (kIdx + 1).toString(),
      }),
    );
  }

  @override
  void onTargetSwitch({
    required int kIdx,
    required int hp,
  }) {
    final tpl = _t(
      'debug.log.line.target_switch',
      'Now target is K#{k} ({hpLabel}={hp})',
    );
    _log(
      _fmt(tpl, {
        'k': (kIdx + 1).toString(),
        'hpLabel': _t('debug.log.label.hp', 'hp'),
        'hp': hp.toString(),
      }),
    );
  }

  @override
  void onSrIntro({
    required int srFrom,
  }) {
    final tpl = _t(
      'debug.log.phrase.sr_intro',
      'SR: special every turn from KT#{turn} onward',
    );
    _log(_fmt(tpl, {'turn': srFrom.toString()}));
  }

  @override
  void onSrActive({
    required int knightTurn,
  }) {
    final tpl = _t(
      'debug.log.line.sr_active',
      'KT#{turn} SR active -> special ALWAYS from now',
    );
    _log(_fmt(tpl, {'turn': knightTurn.toString()}));
  }

  @override
  void onSrEwIntro({
    required int srFrom,
    required int ewEvery,
  }) {
    final tpl = _t(
      'debug.log.phrase.sr_ew_intro',
      'SR+EW: SR active from KT#{sr}; EW every {ew} turns after KT#{sr} (stacking EW)',
    );
    _log(
      _fmt(tpl, {
        'sr': srFrom.toString(),
        'ew': ewEvery.toString(),
      }),
    );
  }

  @override
  void onEwTrigger({
    required int knightTurn,
  }) {
    final tpl = _t(
      'debug.log.phrase.ew_trigger',
      'KT#{turn} triggers EW application',
    );
    _log(_fmt(tpl, {'turn': knightTurn.toString()}));
  }

  @override
  void onEwApplied({
    required int stacks,
    required double reduction,
    required int duration,
  }) {
    final pct = (reduction * 100).round();
    final tpl = _t(
      'debug.log.line.ew_applied',
      'EW applied: stacks={stacks} (effectiveReduction={reduction}%, '
          'dur={dur} bossTurns; miss does NOT tick)',
    );
    _log(
      _fmt(tpl, {
        'stacks': stacks.toString(),
        'reduction': pct.toString(),
        'dur': duration.toString(),
      }),
    );
  }

  @override
  void onEwTick({
    required String reason,
    required int stacks,
  }) {
    final tpl = _t(
      'debug.log.line.ew_ticks',
      'EW ticks ({reason}) ? stacks={stacks}',
    );
    _log(
      _fmt(tpl, {
        'reason': reason,
        'stacks': stacks.toString(),
      }),
    );
  }

  @override
  void onOldSimIntro({
    required int fakeDiv,
  }) {
    final tpl = _t(
      'debug.log.phrase.old_sim_intro',
      'Old Simulator: knight SPECIAL always from KT#1; boss SPECIAL disabled (fakeEW={fake})',
    );
    _log(_fmt(tpl, {'fake': fakeDiv.toString()}));
  }

  @override
  void onOldSimBossSpecialDisabled({
    required int bossTurn,
  }) {
    final tpl = _t(
      'debug.log.phrase.old_sim_boss_special_disabled',
      'BT#{turn} Boss SPECIAL disabled (fakeEW tick)',
    );
    _log(_fmt(tpl, {'turn': bossTurn.toString()}));
  }

  @override
  void onShatterInfo({
    required int first,
    required int step,
  }) {
    final tpl = _t(
      'debug.log.phrase.shatter_info_full',
      'Shatter: first=KT#{first}, step={step}',
    );
    _log(
      _fmt(tpl, {
        'first': first.toString(),
        'step': step.toString(),
      }),
    );
  }

  @override
  void onShatterApply({
    required int knightTurn,
    required int add,
    required int baseHp,
    required int bonusHp,
    required int hpAfter,
  }) {
    final tpl = _t(
      'debug.log.line.shatter_apply',
      'KT#{kt} Shatter Shield ? +{add} HP (base={base}, bonus={bonus}) '
          '({hpLabel}={hp})',
    );
    _log(
      _fmt(tpl, {
        'kt': knightTurn.toString(),
        'add': add.toString(),
        'base': baseHp.toString(),
        'bonus': bonusHp.toString(),
        'hpLabel': _t('debug.log.label.hp', 'hp'),
        'hp': hpAfter.toString(),
      }),
    );
  }

  @override
  void onCycloneIntro({
    required double boostPct,
  }) {
    final tpl = _t(
      'debug.log.phrase.cyclone_intro',
      'Cyclone: +{pct}% per turn (cap 5)',
    );
    _log(
      _fmt(tpl, {
        'pct': boostPct.toString(),
      }),
    );
  }

  @override
  void onDrsActive({
    required double pct,
    required int turns,
  }) {
    final asPercent = (pct <= 1.0) ? (pct * 100.0) : pct;
    final tpl = _t(
      'debug.log.phrase.drs_active_full',
      'DRS active: +{pct}% DEF for {turns} turns',
    );
    _log(
      _fmt(tpl, {
        'pct': asPercent.toStringAsFixed(1),
        'turns': turns.toString(),
      }),
    );
  }

  @override
  void onDrsEnded() {
    final tpl = _t(
      'debug.log.phrase.drs_ended',
      'DRS ended',
    );
    _log(tpl);
  }
}
