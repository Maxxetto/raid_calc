import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/debug/debug_hooks.dart';
import 'package:raid_calc/core/engine/engine.dart';
import 'package:raid_calc/data/config_models.dart';

class _BossActionEvent {
  final int bossTurn;
  final DebugAction action;

  const _BossActionEvent({
    required this.bossTurn,
    required this.action,
  });
}

class _RecordingHook implements DebugHook {
  final List<_BossActionEvent> bossActions = <_BossActionEvent>[];
  int bossSkips = 0;

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
    bossActions.add(_BossActionEvent(bossTurn: bossTurn, action: action));
  }

  @override
  void onBossSkip({required int queuedNow}) {
    bossSkips += 1;
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
  }) {}

  @override
  void onKnightStun({
    required int knightTurn,
    required int kIdx,
    required bool success,
    required int roll,
    required int target,
  }) {}

  @override
  void onKnightDied({required int kIdx}) {}

  @override
  void onTargetSwitch({required int kIdx, required int hp}) {}

  @override
  void onSrIntro({required int srFrom}) {}

  @override
  void onSrActive({required int knightTurn}) {}

  @override
  void onSrEwIntro({required int srFrom, required int ewEvery}) {}

  @override
  void onEwTrigger({required int knightTurn}) {}

  @override
  void onEwApplied({
    required int stacks,
    required double reduction,
    required int duration,
  }) {}

  @override
  void onEwTick({required String reason, required int stacks}) {}

  @override
  void onOldSimIntro({required int fakeDiv}) {}

  @override
  void onOldSimBossSpecialDisabled({required int bossTurn}) {}

  @override
  void onShatterInfo({required int first, required int step}) {}

  @override
  void onShatterApply({
    required int knightTurn,
    required int add,
    required int baseHp,
    required int bonusHp,
    required int hpAfter,
  }) {}

  @override
  void onCycloneIntro({required double boostPct}) {}

  @override
  void onDrsActive({required double pct, required int turns}) {}

  @override
  void onDrsEnded() {}
}

Precomputed _buildPrecomputed({
  required int bossToSpecial,
  required double stunChance,
}) {
  final meta = BossMeta.fromJson({
    'raidMode': true,
    'level': 1,
    'advVsKnights': [1.0],
    'evasionChance': 0.0,
    'criticalChance': 0.0,
    'criticalMultiplier': 1.5,
    'raidSpecialMultiplier': 3.25,
    'knightToSpecial': 999,
    'bossToSpecial': bossToSpecial,
    'bossToSpecialFakeEW': 1000,
    'knightToSpecialSR': 7,
    'knightToRecastSpecialSR': 13,
    'knightToSpecialSREW': 7,
    'knightToRecastSpecialSREW': 13,
    'hitsToElementalWeakness': 7,
    'defaultElementalWeakness': 0.65,
    'durationElementalWeakness': 2,
  });

  final cfg = BossConfig(
    meta: meta,
    stats: const BossStats(
      attack: 1,
      defense: 10000,
      hp: 5000,
    ),
  );

  return DamageModel().precompute(
    boss: cfg,
    kAtk: const [1000],
    kDef: const [1000000000],
    kHp: const [1000000],
    kAdv: const [1.0],
    kStun: [stunChance],
  );
}

void main() {
  test('boss special follows bossToSpecial cadence with no stuns', () {
    final pre = _buildPrecomputed(
      bossToSpecial: 3,
      stunChance: 0.0,
    );
    final hook = _RecordingHook();

    const RaidBlitzBattleEngine().runWithRng(
      BattleEngineSeed(pre: pre),
      FastRng(123),
      withTiming: false,
      debug: hook,
    );

    expect(hook.bossActions.length, greaterThanOrEqualTo(6));
    final firstSix =
        hook.bossActions.take(6).map((e) => e.action).toList(growable: false);
    expect(
      firstSix,
      <DebugAction>[
        DebugAction.normal,
        DebugAction.normal,
        DebugAction.special,
        DebugAction.normal,
        DebugAction.normal,
        DebugAction.special,
      ],
    );

    for (int i = 0; i < 6; i++) {
      expect(hook.bossActions[i].bossTurn, i + 1);
    }
  });

  test('stun does not advance boss special counter', () {
    final pre = _buildPrecomputed(
      bossToSpecial: 3,
      stunChance: 0.40,
    );

    _RecordingHook? selected;
    for (int seed = 1; seed <= 400; seed++) {
      final hook = _RecordingHook();
      const RaidBlitzBattleEngine().runWithRng(
        BattleEngineSeed(pre: pre),
        FastRng(seed),
        withTiming: false,
        debug: hook,
      );
      final hasSpecial =
          hook.bossActions.any((e) => e.action == DebugAction.special);
      if (hook.bossSkips > 0 && hasSpecial && hook.bossActions.length >= 6) {
        selected = hook;
        break;
      }
    }

    expect(
      selected,
      isNotNull,
      reason: 'No deterministic run found with both stun skips and specials.',
    );

    final hook = selected!;
    int actionIndex = 0;
    for (final e in hook.bossActions) {
      actionIndex += 1;
      expect(
        e.bossTurn,
        actionIndex,
        reason: 'Boss turn must increase only on real boss actions.',
      );
      if (e.action == DebugAction.special) {
        expect(
          actionIndex % pre.meta.bossToSpecial,
          0,
          reason: 'Boss special must respect bossToSpecial cadence.',
        );
      }
    }

    expect(hook.bossSkips, greaterThan(0));
  });
}
