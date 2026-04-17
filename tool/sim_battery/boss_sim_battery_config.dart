import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';

class BossSimulationModeLevel {
  final String modeKey;
  final bool raidMode;
  final int bossLevel;

  const BossSimulationModeLevel({
    required this.modeKey,
    required this.raidMode,
    required this.bossLevel,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'modeKey': modeKey,
        'raidMode': raidMode,
        'bossLevel': bossLevel,
      };
}

class BossSimulationPetStrategy {
  final String id;
  final String label;
  final PetSkillUsageMode usageMode;

  const BossSimulationPetStrategy({
    required this.id,
    required this.label,
    required this.usageMode,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'label': label,
        'usageMode': usageMode.name,
      };
}

class BossSimulationRandomizationRange {
  final int attackDeltaMin;
  final int attackDeltaMax;
  final int defenseDeltaMin;
  final int defenseDeltaMax;
  final int healthDeltaMin;
  final int healthDeltaMax;

  const BossSimulationRandomizationRange({
    required this.attackDeltaMin,
    required this.attackDeltaMax,
    required this.defenseDeltaMin,
    required this.defenseDeltaMax,
    required this.healthDeltaMin,
    required this.healthDeltaMax,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'attackDeltaMin': attackDeltaMin,
        'attackDeltaMax': attackDeltaMax,
        'defenseDeltaMin': defenseDeltaMin,
        'defenseDeltaMax': defenseDeltaMax,
        'healthDeltaMin': healthDeltaMin,
        'healthDeltaMax': healthDeltaMax,
      };
}

class BossSimulationStatTier {
  final String id;
  final WargearStats bonusStats;

  const BossSimulationStatTier({
    required this.id,
    required this.bonusStats,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'bonusStats': bonusStats.toJson(),
      };
}

class BossSimulationScoreProfile {
  final String id;
  final double damageWeight;
  final double survivabilityWeight;
  final double consistencyPenaltyWeight;
  final double efficiencyWeight;
  final double specialEconomyWeight;
  final double tempoWeight;
  final double advantageFactorWeight;
  final double bossPenaltyWeight;

  const BossSimulationScoreProfile({
    required this.id,
    required this.damageWeight,
    required this.survivabilityWeight,
    required this.consistencyPenaltyWeight,
    required this.efficiencyWeight,
    required this.specialEconomyWeight,
    required this.tempoWeight,
    required this.advantageFactorWeight,
    required this.bossPenaltyWeight,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'damageWeight': damageWeight,
        'survivabilityWeight': survivabilityWeight,
        'consistencyPenaltyWeight': consistencyPenaltyWeight,
        'efficiencyWeight': efficiencyWeight,
        'specialEconomyWeight': specialEconomyWeight,
        'tempoWeight': tempoWeight,
        'advantageFactorWeight': advantageFactorWeight,
        'bossPenaltyWeight': bossPenaltyWeight,
      };
}

enum BossSimulationPetAttackResolutionPolicy {
  maxSelectedPresetAttack,
  primaryPresetAttack,
}

class BossSimulationConfig {
  final List<BossSimulationModeLevel> targets;
  final FightMode fightMode;
  final int runsPerScenario;
  final List<List<WargearRole>> layoutPermutations;
  final List<List<double>> knightAdvantageVectors;
  final List<List<double>> bossAdvantageVectors;
  final List<BossSimulationPetStrategy> petUsageStrategies;
  final List<String> petPrimarySkills;
  final String petSecondarySkill;
  final List<BossSimulationStatTier> statTiers;
  final bool includeSwappedAttackDefenseVariant;
  final BossSimulationRandomizationRange randomization;
  final List<bool> petMatchByKnightSlot;
  final List<bool> petStrongVsBossByKnightSlot;
  final BossSimulationPetAttackResolutionPolicy petAttackResolutionPolicy;
  final double petAdvantageMultiplier;
  final List<double> knightStunChances;
  final bool captureTiming;
  final bool exportAggregates;
  final bool exportScores;
  final bool retainAggregatesInMemory;
  final bool retainScoresInMemory;
  final int exportShardSize;
  final int checkpointEveryScenarios;
  final int pauseEveryScenarios;
  final int pauseDurationMs;
  final int? maxScenarios;
  final BossSimulationScoreProfile raidScoreProfile;
  final BossSimulationScoreProfile blitzScoreProfile;

  const BossSimulationConfig({
    required this.targets,
    required this.fightMode,
    required this.runsPerScenario,
    required this.layoutPermutations,
    required this.knightAdvantageVectors,
    required this.bossAdvantageVectors,
    required this.petUsageStrategies,
    required this.petPrimarySkills,
    required this.petSecondarySkill,
    required this.statTiers,
    required this.includeSwappedAttackDefenseVariant,
    required this.randomization,
    required this.petMatchByKnightSlot,
    required this.petStrongVsBossByKnightSlot,
    required this.petAttackResolutionPolicy,
    required this.petAdvantageMultiplier,
    required this.knightStunChances,
    required this.captureTiming,
    required this.exportAggregates,
    required this.exportScores,
    required this.retainAggregatesInMemory,
    required this.retainScoresInMemory,
    required this.exportShardSize,
    required this.checkpointEveryScenarios,
    required this.pauseEveryScenarios,
    required this.pauseDurationMs,
    required this.maxScenarios,
    required this.raidScoreProfile,
    required this.blitzScoreProfile,
  });

  factory BossSimulationConfig.defaultBattery({
    int runsPerScenario = 100,
    int? maxScenarios,
  }) {
    return BossSimulationConfig(
      targets: const <BossSimulationModeLevel>[
        BossSimulationModeLevel(modeKey: 'raid', raidMode: true, bossLevel: 4),
        BossSimulationModeLevel(modeKey: 'raid', raidMode: true, bossLevel: 6),
        BossSimulationModeLevel(modeKey: 'raid', raidMode: true, bossLevel: 7),
        BossSimulationModeLevel(
            modeKey: 'blitz', raidMode: false, bossLevel: 4),
        BossSimulationModeLevel(
            modeKey: 'blitz', raidMode: false, bossLevel: 5),
        BossSimulationModeLevel(
            modeKey: 'blitz', raidMode: false, bossLevel: 6),
      ],
      fightMode: FightMode.normal,
      runsPerScenario: runsPerScenario,
      layoutPermutations: const <List<WargearRole>>[
        <WargearRole>[
          WargearRole.primary,
          WargearRole.secondary,
          WargearRole.secondary,
        ],
        <WargearRole>[
          WargearRole.secondary,
          WargearRole.primary,
          WargearRole.secondary,
        ],
        <WargearRole>[
          WargearRole.secondary,
          WargearRole.secondary,
          WargearRole.primary,
        ],
      ],
      knightAdvantageVectors:
          _buildMultiplierVectors(const <double>[1.0, 1.5, 2.0]),
      bossAdvantageVectors:
          _buildMultiplierVectors(const <double>[1.0, 1.5, 2.0]),
      petUsageStrategies: const <BossSimulationPetStrategy>[
        BossSimulationPetStrategy(
          id: 'double_s2_then_s1',
          label: '2, 2, then always 1',
          usageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
        ),
        BossSimulationPetStrategy(
          id: 's2_then_s1',
          label: '2, then always 1',
          usageMode: PetSkillUsageMode.special2ThenSpecial1,
        ),
      ],
      petPrimarySkills: const <String>[
        'Soul Burn',
        'Vampiric Attack',
        'Elemental Weakness',
      ],
      petSecondarySkill: 'Special Regeneration (inf)',
      statTiers: const <BossSimulationStatTier>[
        BossSimulationStatTier(
          id: 'tier_1',
          bonusStats: WargearStats(attack: 30000, defense: 20000, health: 500),
        ),
        BossSimulationStatTier(
          id: 'tier_2',
          bonusStats: WargearStats(attack: 35000, defense: 25000, health: 650),
        ),
        BossSimulationStatTier(
          id: 'tier_3',
          bonusStats: WargearStats(attack: 45000, defense: 35000, health: 800),
        ),
        BossSimulationStatTier(
          id: 'tier_4',
          bonusStats: WargearStats(attack: 50000, defense: 38000, health: 850),
        ),
        BossSimulationStatTier(
          id: 'tier_5',
          bonusStats: WargearStats(attack: 60000, defense: 45000, health: 1000),
        ),
        BossSimulationStatTier(
          id: 'tier_6',
          bonusStats: WargearStats(attack: 70000, defense: 60000, health: 1200),
        ),
        BossSimulationStatTier(
          id: 'tier_7',
          bonusStats: WargearStats(attack: 75000, defense: 65000, health: 1350),
        ),
      ],
      includeSwappedAttackDefenseVariant: true,
      randomization: const BossSimulationRandomizationRange(
        attackDeltaMin: -3000,
        attackDeltaMax: 3000,
        defenseDeltaMin: -3000,
        defenseDeltaMax: 3000,
        healthDeltaMin: -300,
        healthDeltaMax: 300,
      ),
      petMatchByKnightSlot: const <bool>[true, true, true],
      petStrongVsBossByKnightSlot: const <bool>[false, false, false],
      petAttackResolutionPolicy:
          BossSimulationPetAttackResolutionPolicy.maxSelectedPresetAttack,
      petAdvantageMultiplier: 1.0,
      knightStunChances: const <double>[0.0, 0.0, 0.0],
      captureTiming: false,
      exportAggregates: true,
      exportScores: true,
      retainAggregatesInMemory: false,
      retainScoresInMemory: false,
      exportShardSize: 10000,
      checkpointEveryScenarios: 100,
      pauseEveryScenarios: 0,
      pauseDurationMs: 0,
      maxScenarios: maxScenarios,
      raidScoreProfile: const BossSimulationScoreProfile(
        id: 'raid',
        damageWeight: 1.0,
        survivabilityWeight: 0.25,
        consistencyPenaltyWeight: 0.10,
        efficiencyWeight: 0.05,
        specialEconomyWeight: 0.02,
        tempoWeight: 0.0,
        advantageFactorWeight: 0.0,
        bossPenaltyWeight: 0.0,
      ),
      blitzScoreProfile: const BossSimulationScoreProfile(
        id: 'blitz',
        damageWeight: 1.0,
        survivabilityWeight: 0.25,
        consistencyPenaltyWeight: 0.10,
        efficiencyWeight: 0.05,
        specialEconomyWeight: 0.02,
        tempoWeight: 0.0,
        advantageFactorWeight: 0.0,
        bossPenaltyWeight: 0.0,
      ),
    );
  }

  BossSimulationConfig copyWith({
    int? runsPerScenario,
    int? maxScenarios,
    bool? captureTiming,
    bool? exportAggregates,
    bool? exportScores,
    bool? retainAggregatesInMemory,
    bool? retainScoresInMemory,
    int? exportShardSize,
    int? checkpointEveryScenarios,
    int? pauseEveryScenarios,
    int? pauseDurationMs,
  }) {
    return BossSimulationConfig(
      targets: targets,
      fightMode: fightMode,
      runsPerScenario: runsPerScenario ?? this.runsPerScenario,
      layoutPermutations: layoutPermutations,
      knightAdvantageVectors: knightAdvantageVectors,
      bossAdvantageVectors: bossAdvantageVectors,
      petUsageStrategies: petUsageStrategies,
      petPrimarySkills: petPrimarySkills,
      petSecondarySkill: petSecondarySkill,
      statTiers: statTiers,
      includeSwappedAttackDefenseVariant: includeSwappedAttackDefenseVariant,
      randomization: randomization,
      petMatchByKnightSlot: petMatchByKnightSlot,
      petStrongVsBossByKnightSlot: petStrongVsBossByKnightSlot,
      petAttackResolutionPolicy: petAttackResolutionPolicy,
      petAdvantageMultiplier: petAdvantageMultiplier,
      knightStunChances: knightStunChances,
      captureTiming: captureTiming ?? this.captureTiming,
      exportAggregates: exportAggregates ?? this.exportAggregates,
      exportScores: exportScores ?? this.exportScores,
      retainAggregatesInMemory:
          retainAggregatesInMemory ?? this.retainAggregatesInMemory,
      retainScoresInMemory:
          retainScoresInMemory ?? this.retainScoresInMemory,
      exportShardSize: exportShardSize ?? this.exportShardSize,
      checkpointEveryScenarios:
          checkpointEveryScenarios ?? this.checkpointEveryScenarios,
      pauseEveryScenarios: pauseEveryScenarios ?? this.pauseEveryScenarios,
      pauseDurationMs: pauseDurationMs ?? this.pauseDurationMs,
      maxScenarios: maxScenarios ?? this.maxScenarios,
      raidScoreProfile: raidScoreProfile,
      blitzScoreProfile: blitzScoreProfile,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'targets': targets.map((value) => value.toJson()).toList(),
        'fightMode': fightMode.name,
        'runsPerScenario': runsPerScenario,
        'layoutPermutations': layoutPermutations
            .map((layout) => layout.map((value) => value.name).toList())
            .toList(),
        'knightAdvantageVectors': knightAdvantageVectors,
        'bossAdvantageVectors': bossAdvantageVectors,
        'petUsageStrategies':
            petUsageStrategies.map((value) => value.toJson()).toList(),
        'petPrimarySkills': petPrimarySkills,
        'petSecondarySkill': petSecondarySkill,
        'statTiers': statTiers.map((value) => value.toJson()).toList(),
        'includeSwappedAttackDefenseVariant':
            includeSwappedAttackDefenseVariant,
        'randomization': randomization.toJson(),
        'petMatchByKnightSlot': petMatchByKnightSlot,
        'petStrongVsBossByKnightSlot': petStrongVsBossByKnightSlot,
        'petAttackResolutionPolicy': petAttackResolutionPolicy.name,
        'petAdvantageMultiplier': petAdvantageMultiplier,
        'knightStunChances': knightStunChances,
        'captureTiming': captureTiming,
        'exportAggregates': exportAggregates,
        'exportScores': exportScores,
        'retainAggregatesInMemory': retainAggregatesInMemory,
        'retainScoresInMemory': retainScoresInMemory,
        'exportShardSize': exportShardSize,
        'checkpointEveryScenarios': checkpointEveryScenarios,
        'pauseEveryScenarios': pauseEveryScenarios,
        'pauseDurationMs': pauseDurationMs,
        'maxScenarios': maxScenarios,
        'raidScoreProfile': raidScoreProfile.toJson(),
        'blitzScoreProfile': blitzScoreProfile.toJson(),
      };
}

List<List<double>> _buildMultiplierVectors(List<double> values) {
  final out = <List<double>>[];
  for (final a in values) {
    for (final b in values) {
      for (final c in values) {
        out.add(<double>[a, b, c]);
      }
    }
  }
  return List<List<double>>.unmodifiable(out);
}
