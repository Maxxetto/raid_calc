import 'package:flutter/foundation.dart';

import '../battle_outcome.dart';
import '../debug/debug_hooks.dart';

@immutable
class BattleRunResult {
  final int points;
  final int bossHpRemaining;
  final bool bossDefeated;
  final bool knightsDefeated;
  final int knightTurns;
  final int bossTurns;
  final int finalKnightIndex;
  final int? finalKnightHp;
  final int petBasicAttacks;
  final int petCastCount;
  final int petSpecial1Casts;
  final int petSpecial2Casts;
  final List<PetSpecialCastKind> petCastSequence;
  final int knightNormalActions;
  final int knightCritActions;
  final int knightSpecialActions;
  final int knightMissActions;
  final int bossNormalActions;
  final int bossCritActions;
  final int bossSpecialActions;
  final int bossMissActions;
  final int bossStunSkips;
  final bool cycloneAlwaysGemApplied;
  final bool goldDropEnabled;
  final int goldDropped;
  final TimingStats? timing;

  const BattleRunResult({
    required this.points,
    required this.bossHpRemaining,
    required this.bossDefeated,
    required this.knightsDefeated,
    required this.knightTurns,
    required this.bossTurns,
    required this.finalKnightIndex,
    required this.finalKnightHp,
    required this.petBasicAttacks,
    required this.petCastCount,
    required this.petSpecial1Casts,
    required this.petSpecial2Casts,
    required this.petCastSequence,
    required this.knightNormalActions,
    required this.knightCritActions,
    required this.knightSpecialActions,
    required this.knightMissActions,
    required this.bossNormalActions,
    required this.bossCritActions,
    required this.bossSpecialActions,
    required this.bossMissActions,
    required this.bossStunSkips,
    required this.cycloneAlwaysGemApplied,
    required this.goldDropEnabled,
    required this.goldDropped,
    required this.timing,
  });
}
