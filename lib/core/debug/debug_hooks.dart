// lib/core/debug/debug_hooks.dart
//
// Debug hook interface for mode simulations.

enum DebugAction {
  normal,
  crit,
  special,
  miss,
}

enum PetSpecialCastKind {
  special1,
  special2,
}

abstract class DebugHook {
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
  });

  void onKnightStun({
    required int knightTurn,
    required int kIdx,
    required bool success,
    required int roll,
    required int target,
  });

  void onBossSkip({
    required int queuedNow,
  });

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
  });

  void onKnightDied({
    required int kIdx,
  });

  void onTargetSwitch({
    required int kIdx,
    required int hp,
  });

  void onSrIntro({
    required int srFrom,
  });

  void onSrActive({
    required int knightTurn,
  });

  void onSrEwIntro({
    required int srFrom,
    required int ewEvery,
  });

  void onEwTrigger({
    required int knightTurn,
  });

  void onEwApplied({
    required int stacks,
    required double reduction,
    required int duration,
  });

  void onEwTick({
    required String reason,
    required int stacks,
  });

  void onOldSimIntro({
    required int fakeDiv,
  });

  void onOldSimBossSpecialDisabled({
    required int bossTurn,
  });

  void onShatterInfo({
    required int first,
    required int step,
  });

  void onShatterApply({
    required int knightTurn,
    required int add,
    required int baseHp,
    required int bonusHp,
    required int hpAfter,
  });

  void onCycloneIntro({
    required double boostPct,
  });

  void onDrsActive({
    required double pct,
    required int turns,
  });

  void onDrsEnded();
}

abstract class DebugPetBarHook {
  void onPetBarInit({
    required int ticks,
    required int ticksPerState,
  });

  void onPetBarFill({
    required String source,
    required int add,
    required int before,
    required int after,
    required int max,
  });

  void onPetBarQueued({
    required PetSpecialCastKind cast,
    required int ticks,
  });

  void onPetBarCast({
    required PetSpecialCastKind cast,
    required int before,
    required int after,
  });
}
