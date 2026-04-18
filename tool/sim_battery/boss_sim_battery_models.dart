import 'package:raid_calc/core/debug/debug_hooks.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

class BossSimulationScenarioSlotProfile {
  final int slotIndex;
  final WargearRole role;
  final WargearStats baseKnightStats;
  final WargearStats statPackage;
  final WargearStats effectiveStatsBeforeRandomization;

  const BossSimulationScenarioSlotProfile({
    required this.slotIndex,
    required this.role,
    required this.baseKnightStats,
    required this.statPackage,
    required this.effectiveStatsBeforeRandomization,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'slotIndex': slotIndex,
        'role': role.name,
        'baseKnightStats': baseKnightStats.toJson(),
        'statPackage': statPackage.toJson(),
        'effectiveStatsBeforeRandomization':
            effectiveStatsBeforeRandomization.toJson(),
      };
}

class BossSimulationScenario {
  final String scenarioId;
  final String modeKey;
  final bool raidMode;
  final int bossLevel;
  final String fightModeKey;
  final List<WargearRole> layout;
  final List<double> knightAdvantageVector;
  final List<double> bossAdvantageVector;
  final String petStrategyId;
  final String petStrategyLabel;
  final String petPrimarySkill;
  final String petSecondarySkill;
  final String statTierId;
  final bool attackDefenseSwapped;
  final WargearStats statPackage;
  final List<BossSimulationScenarioSlotProfile> slotProfiles;

  const BossSimulationScenario({
    required this.scenarioId,
    required this.modeKey,
    required this.raidMode,
    required this.bossLevel,
    required this.fightModeKey,
    required this.layout,
    required this.knightAdvantageVector,
    required this.bossAdvantageVector,
    required this.petStrategyId,
    required this.petStrategyLabel,
    required this.petPrimarySkill,
    required this.petSecondarySkill,
    required this.statTierId,
    required this.attackDefenseSwapped,
    required this.statPackage,
    required this.slotProfiles,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'scenarioId': scenarioId,
        'modeKey': modeKey,
        'raidMode': raidMode,
        'bossLevel': bossLevel,
        'fightModeKey': fightModeKey,
        'layout': layout.map((value) => value.name).toList(growable: false),
        'knightAdvantageVector': knightAdvantageVector,
        'bossAdvantageVector': bossAdvantageVector,
        'petStrategyId': petStrategyId,
        'petStrategyLabel': petStrategyLabel,
        'petPrimarySkill': petPrimarySkill,
        'petSecondarySkill': petSecondarySkill,
        'statTierId': statTierId,
        'attackDefenseSwapped': attackDefenseSwapped,
        'statPackage': statPackage.toJson(),
        'slotProfiles': slotProfiles.map((value) => value.toJson()).toList(),
      };
}

class BossSimulationRunResult {
  final String scenarioId;
  final int runIndex;
  final int rngSeed;
  final String modeKey;
  final int bossLevel;
  final List<String> layout;
  final List<double> knightAdvantageVector;
  final List<double> bossAdvantageVector;
  final String petStrategyId;
  final String petPrimarySkill;
  final String petSecondarySkill;
  final String statTierId;
  final bool attackDefenseSwapped;
  final int randomAttackDelta;
  final int randomDefenseDelta;
  final int randomHealthDelta;
  final List<Map<String, Object?>> slotProfiles;
  final int totalDamage;
  final List<int> damageByKnight;
  final String outcome;
  final bool survived;
  final bool bossDefeated;
  final bool knightsDefeated;
  final int turnsSurvived;
  final int totalSpecialsUsed;
  final List<int> specialUsageCountByKnight;
  final int petCastCount;
  final int petSpecial1Casts;
  final int petSpecial2Casts;
  final List<String> petCastSequence;
  final int knightNormalActions;
  final int knightCritActions;
  final int knightSpecialActions;
  final int knightMissActions;
  final int bossNormalActions;
  final int bossCritActions;
  final int bossSpecialActions;
  final int bossMissActions;
  final int bossStunSkips;
  final int? finalKnightIndex;
  final int? finalKnightHp;
  final double? runDurationSeconds;
  final double? bossDurationSeconds;
  final double? healingRecovered;
  final Map<String, Object?> rawEngineResult;

  const BossSimulationRunResult({
    required this.scenarioId,
    required this.runIndex,
    required this.rngSeed,
    required this.modeKey,
    required this.bossLevel,
    required this.layout,
    required this.knightAdvantageVector,
    required this.bossAdvantageVector,
    required this.petStrategyId,
    required this.petPrimarySkill,
    required this.petSecondarySkill,
    required this.statTierId,
    required this.attackDefenseSwapped,
    required this.randomAttackDelta,
    required this.randomDefenseDelta,
    required this.randomHealthDelta,
    required this.slotProfiles,
    required this.totalDamage,
    required this.damageByKnight,
    required this.outcome,
    required this.survived,
    required this.bossDefeated,
    required this.knightsDefeated,
    required this.turnsSurvived,
    required this.totalSpecialsUsed,
    required this.specialUsageCountByKnight,
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
    required this.finalKnightIndex,
    required this.finalKnightHp,
    required this.runDurationSeconds,
    required this.bossDurationSeconds,
    required this.healingRecovered,
    required this.rawEngineResult,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'scenarioId': scenarioId,
        'runIndex': runIndex,
        'rngSeed': rngSeed,
        'modeKey': modeKey,
        'bossLevel': bossLevel,
        'layout': layout,
        'knightAdvantageVector': knightAdvantageVector,
        'bossAdvantageVector': bossAdvantageVector,
        'petStrategyId': petStrategyId,
        'petPrimarySkill': petPrimarySkill,
        'petSecondarySkill': petSecondarySkill,
        'statTierId': statTierId,
        'attackDefenseSwapped': attackDefenseSwapped,
        'randomAttackDelta': randomAttackDelta,
        'randomDefenseDelta': randomDefenseDelta,
        'randomHealthDelta': randomHealthDelta,
        'slotProfiles': slotProfiles,
        'totalDamage': totalDamage,
        'damageByKnight': damageByKnight,
        'outcome': outcome,
        'survived': survived,
        'bossDefeated': bossDefeated,
        'knightsDefeated': knightsDefeated,
        'turnsSurvived': turnsSurvived,
        'totalSpecialsUsed': totalSpecialsUsed,
        'specialUsageCountByKnight': specialUsageCountByKnight,
        'petCastCount': petCastCount,
        'petSpecial1Casts': petSpecial1Casts,
        'petSpecial2Casts': petSpecial2Casts,
        'petCastSequence': petCastSequence,
        'knightNormalActions': knightNormalActions,
        'knightCritActions': knightCritActions,
        'knightSpecialActions': knightSpecialActions,
        'knightMissActions': knightMissActions,
        'bossNormalActions': bossNormalActions,
        'bossCritActions': bossCritActions,
        'bossSpecialActions': bossSpecialActions,
        'bossMissActions': bossMissActions,
        'bossStunSkips': bossStunSkips,
        'finalKnightIndex': finalKnightIndex,
        'finalKnightHp': finalKnightHp,
        'runDurationSeconds': runDurationSeconds,
        'bossDurationSeconds': bossDurationSeconds,
        'healingRecovered': healingRecovered,
        'rawEngineResult': rawEngineResult,
      };
}

class BossSimulationAggregate {
  final String scenarioId;
  final String modeKey;
  final int bossLevel;
  final String petPrimarySkill;
  final String statTierId;
  final bool attackDefenseSwapped;
  final int runsCount;
  final double meanTotalDamage;
  final double medianTotalDamage;
  final int minTotalDamage;
  final int maxTotalDamage;
  final double stdDevTotalDamage;
  final double p10TotalDamage;
  final double p25TotalDamage;
  final double p75TotalDamage;
  final double p90TotalDamage;
  final double completionRate;
  final double survivalRate;
  final List<double> meanDamageByKnight;
  final List<double> meanSpecialUsageByKnight;
  final double meanTurnsSurvived;
  final double meanPetCastCount;
  final double meanPetSpecial1Casts;
  final double meanPetSpecial2Casts;
  final double meanKnightSpecialActions;
  final double meanBossTurns;
  final double meanRunDurationSeconds;

  const BossSimulationAggregate({
    required this.scenarioId,
    required this.modeKey,
    required this.bossLevel,
    required this.petPrimarySkill,
    required this.statTierId,
    required this.attackDefenseSwapped,
    required this.runsCount,
    required this.meanTotalDamage,
    required this.medianTotalDamage,
    required this.minTotalDamage,
    required this.maxTotalDamage,
    required this.stdDevTotalDamage,
    required this.p10TotalDamage,
    required this.p25TotalDamage,
    required this.p75TotalDamage,
    required this.p90TotalDamage,
    required this.completionRate,
    required this.survivalRate,
    required this.meanDamageByKnight,
    required this.meanSpecialUsageByKnight,
    required this.meanTurnsSurvived,
    required this.meanPetCastCount,
    required this.meanPetSpecial1Casts,
    required this.meanPetSpecial2Casts,
    required this.meanKnightSpecialActions,
    required this.meanBossTurns,
    required this.meanRunDurationSeconds,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'scenarioId': scenarioId,
        'modeKey': modeKey,
        'bossLevel': bossLevel,
        'petPrimarySkill': petPrimarySkill,
        'statTierId': statTierId,
        'attackDefenseSwapped': attackDefenseSwapped,
        'runsCount': runsCount,
        'meanTotalDamage': meanTotalDamage,
        'medianTotalDamage': medianTotalDamage,
        'minTotalDamage': minTotalDamage,
        'maxTotalDamage': maxTotalDamage,
        'stdDevTotalDamage': stdDevTotalDamage,
        'p10TotalDamage': p10TotalDamage,
        'p25TotalDamage': p25TotalDamage,
        'p75TotalDamage': p75TotalDamage,
        'p90TotalDamage': p90TotalDamage,
        'completionRate': completionRate,
        'survivalRate': survivalRate,
        'meanDamageByKnight': meanDamageByKnight,
        'meanSpecialUsageByKnight': meanSpecialUsageByKnight,
        'meanTurnsSurvived': meanTurnsSurvived,
        'meanPetCastCount': meanPetCastCount,
        'meanPetSpecial1Casts': meanPetSpecial1Casts,
        'meanPetSpecial2Casts': meanPetSpecial2Casts,
        'meanKnightSpecialActions': meanKnightSpecialActions,
        'meanBossTurns': meanBossTurns,
        'meanRunDurationSeconds': meanRunDurationSeconds,
      };
}

class BossSimulationScore {
  final String scenarioId;
  final String profileId;
  final double finalScore;
  final Map<String, double> scoreComponents;

  const BossSimulationScore({
    required this.scenarioId,
    required this.profileId,
    required this.finalScore,
    required this.scoreComponents,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'scenarioId': scenarioId,
        'profileId': profileId,
        'finalScore': finalScore,
        'scoreComponents': scoreComponents,
      };
}

class BossSimulationSummary {
  final int totalScenarios;
  final int totalRunsExpected;
  final Map<String, int> scenariosByMode;
  final Map<String, int> scenariosByBossLevel;
  final Map<String, int> scenariosByStatTier;
  final Map<String, int> scenariosByPetPrimarySkill;
  final Map<String, Object?> sampleScenario;

  const BossSimulationSummary({
    required this.totalScenarios,
    required this.totalRunsExpected,
    required this.scenariosByMode,
    required this.scenariosByBossLevel,
    required this.scenariosByStatTier,
    required this.scenariosByPetPrimarySkill,
    required this.sampleScenario,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'totalScenarios': totalScenarios,
        'totalRunsExpected': totalRunsExpected,
        'scenariosByMode': scenariosByMode,
        'scenariosByBossLevel': scenariosByBossLevel,
        'scenariosByStatTier': scenariosByStatTier,
        'scenariosByPetPrimarySkill': scenariosByPetPrimarySkill,
        'sampleScenario': sampleScenario,
      };
}

class BossSimulationBatchResult {
  final BossSimulationSummary summary;
  final int executedScenarioCount;
  final int executedRunCount;
  final List<BossSimulationAggregate> aggregates;
  final List<BossSimulationScore> scores;

  const BossSimulationBatchResult({
    required this.summary,
    required this.executedScenarioCount,
    required this.executedRunCount,
    required this.aggregates,
    required this.scores,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'summary': summary.toJson(),
        'executedScenarioCount': executedScenarioCount,
        'executedRunCount': executedRunCount,
        'aggregates': aggregates.map((value) => value.toJson()).toList(),
        'scores': scores.map((value) => value.toJson()).toList(),
      };
}

class BossSimulationProgress {
  final int completedScenarios;
  final int totalScenarios;
  final int completedRuns;
  final int totalRunsExpected;
  final String? currentScenarioId;
  final Duration elapsed;
  final int currentShardIndex;

  const BossSimulationProgress({
    required this.completedScenarios,
    required this.totalScenarios,
    required this.completedRuns,
    required this.totalRunsExpected,
    required this.currentScenarioId,
    required this.elapsed,
    required this.currentShardIndex,
  });

  double get scenarioProgressFraction =>
      totalScenarios <= 0 ? 0.0 : completedScenarios / totalScenarios;

  double get runProgressFraction =>
      totalRunsExpected <= 0 ? 0.0 : completedRuns / totalRunsExpected;

  Duration? get eta {
    if (completedScenarios <= 0 || totalScenarios <= 0) return null;
    final elapsedMs = elapsed.inMilliseconds;
    if (elapsedMs <= 0) return null;
    final msPerScenario = elapsedMs / completedScenarios;
    final remainingScenarios = totalScenarios - completedScenarios;
    if (remainingScenarios <= 0) return Duration.zero;
    return Duration(milliseconds: (msPerScenario * remainingScenarios).round());
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'completedScenarios': completedScenarios,
        'totalScenarios': totalScenarios,
        'completedRuns': completedRuns,
        'totalRunsExpected': totalRunsExpected,
        'currentScenarioId': currentScenarioId,
        'elapsedMs': elapsed.inMilliseconds,
        'currentShardIndex': currentShardIndex,
        'scenarioProgressFraction': scenarioProgressFraction,
        'runProgressFraction': runProgressFraction,
        'etaMs': eta?.inMilliseconds,
      };
}

class BossSimulationDebugCapture implements DebugHook {
  final List<int> damageByKnight = <int>[0, 0, 0];
  final List<int> specialUsageCountByKnight = <int>[0, 0, 0];

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
    if (kIdx >= 0 && kIdx < damageByKnight.length) {
      damageByKnight[kIdx] += dmg;
    }
    if (action == DebugAction.special &&
        kIdx >= 0 &&
        kIdx < specialUsageCountByKnight.length) {
      specialUsageCountByKnight[kIdx] += 1;
    }
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
