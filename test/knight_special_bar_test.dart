import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/debug/debug_hooks.dart';
import 'package:raid_calc/core/engine/battle_engine.dart';
import 'package:raid_calc/core/engine/knight_special_bar_runtime.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';

class _KnightActionEvent {
  final int knightTurn;
  final DebugAction action;

  const _KnightActionEvent({
    required this.knightTurn,
    required this.action,
  });
}

class _RecordingHook implements DebugHook {
  final List<_KnightActionEvent> knightActions = <_KnightActionEvent>[];

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
    knightActions.add(
      _KnightActionEvent(
        knightTurn: knightTurn,
        action: action,
      ),
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
  }) {}

  @override
  void onBossSkip({required int queuedNow}) {}

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
  required KnightSpecialBarConfig knightSpecialBar,
  int bossHp = 100,
  double bossAttack = 0.0,
  double bossDefense = 1640.0,
  int knightHp = 200,
  double knightAttack = 100.0,
  double knightDefense = 1000.0,
  int knightToSpecial = 99,
  int bossToSpecial = 99,
  double stunChance = 0.0,
}) {
  final meta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const <double>[1.0],
    evasionChance: 0.0,
    criticalChance: 0.0,
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
    knightSpecialBar: knightSpecialBar,
  );

  return DamageModel().precompute(
    boss: BossConfig(
      meta: meta,
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
    kStun: <double>[stunChance],
  );
}

void main() {
  test('knight special bar queues after 5 boss turns and 4 knight turns', () {
    final bar = KnightSpecialBarRuntimeState(
      config: const KnightSpecialBarConfig(
        enabled: true,
        startFill: 0.0,
        knightTurnFill: 0.2,
        bossTurnFill: 0.042,
        thresholdFill: 1.0,
        maxFill: 1.0,
      ),
    );

    for (int i = 0; i < 4; i++) {
      bar.onKnightTurnResolved();
    }
    for (int i = 0; i < 4; i++) {
      bar.onBossTurnResolved();
    }

    expect(bar.hasQueuedSpecial, isFalse);
    expect(bar.fill, closeTo(0.968, 1e-9));

    bar.onBossTurnResolved();

    expect(bar.hasQueuedSpecial, isTrue);
    expect(bar.fill, closeTo(1.0, 1e-9));
    expect(bar.consumeQueuedSpecial(), isTrue);
    expect(bar.fill, closeTo(0.0, 1e-9));
  });

  test('engine schedules knight special after boss turn fill', () {
    final pre = _buildPrecomputed(
      knightSpecialBar: const KnightSpecialBarConfig(
        enabled: true,
        startFill: 0.0,
        knightTurnFill: 0.5,
        bossTurnFill: 0.5,
        thresholdFill: 1.0,
        maxFill: 1.0,
      ),
      bossHp: 40,
      bossAttack: 0.0,
    );
    final hook = _RecordingHook();

    const RaidBlitzBattleEngine().runWithRng(
      BattleEngineSeed(pre: pre),
      FastRng(3),
      debug: hook,
    );

    expect(hook.knightActions.length, greaterThanOrEqualTo(2));
    expect(hook.knightActions[0].knightTurn, 1);
    expect(hook.knightActions[0].action, DebugAction.normal);
    expect(hook.knightActions[1].knightTurn, 2);
    expect(hook.knightActions[1].action, DebugAction.special);
  });

  test('boss stun skip still fills the knight special bar', () {
    final pre = _buildPrecomputed(
      knightSpecialBar: const KnightSpecialBarConfig(
        enabled: true,
        startFill: 0.0,
        knightTurnFill: 0.0,
        bossTurnFill: 1.0,
        thresholdFill: 1.0,
        maxFill: 1.0,
      ),
      bossHp: 40,
      bossAttack: 0.0,
      stunChance: 1.0,
    );
    final hook = _RecordingHook();

    const RaidBlitzBattleEngine().runWithRng(
      BattleEngineSeed(pre: pre),
      FastRng(11),
      debug: hook,
    );

    expect(hook.knightActions.length, greaterThanOrEqualTo(2));
    expect(hook.knightActions[0].action, DebugAction.normal);
    expect(hook.knightActions[1].action, DebugAction.special);
  });
}
