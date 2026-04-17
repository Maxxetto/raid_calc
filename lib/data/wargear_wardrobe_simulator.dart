import '../core/battle_outcome.dart';
import '../core/damage_model.dart';
import '../core/element_types.dart';
import '../core/sim_types.dart';
import 'config_loader.dart';
import 'config_models.dart';
import 'pet_effect_models.dart';
import 'setup_models.dart';
import 'wargear_universal_scoring.dart';
import 'wargear_wardrobe_candidates.dart';
import 'wargear_wardrobe_loader.dart';

class WardrobeSimulateArmorAssignment {
  final int slotIndex;
  final WargearWardrobeEntry entry;
  final WargearRole role;
  final WargearStats resolvedStats;
  final WargearStats finalStats;
  final WargearUniversalScoreResult universalArmorScore;
  final WargearUniversalScoreResult petAwareUniversalArmorScore;
  final double stunPercent;

  const WardrobeSimulateArmorAssignment({
    required this.slotIndex,
    required this.entry,
    required this.role,
    required this.resolvedStats,
    required this.finalStats,
    required this.universalArmorScore,
    required this.petAwareUniversalArmorScore,
    required this.stunPercent,
  });
}

class WardrobeSimulateScenarioResult {
  final String scenarioId;
  final List<WardrobeSimulateArmorAssignment> assignments;
  final SetupSnapshot setup;
  final Precomputed precomputed;
  final SimStats stats;

  const WardrobeSimulateScenarioResult({
    required this.scenarioId,
    required this.assignments,
    required this.setup,
    required this.precomputed,
    required this.stats,
  });
}

class WardrobeSimulateBatchResult {
  final SetupSnapshot baseSetup;
  final WargearFavoriteCandidateBatch candidateBatch;
  final int runsPerScenario;
  final int totalScenarios;
  final List<WardrobeSimulateScenarioResult> results;
  final List<SetupPetSnapshot> testedPets;
  final int favoritePetCount;
  final List<PetSkillUsageMode> testedSkillUsages;

  const WardrobeSimulateBatchResult({
    required this.baseSetup,
    required this.candidateBatch,
    required this.runsPerScenario,
    required this.totalScenarios,
    required this.results,
    this.testedPets = const <SetupPetSnapshot>[],
    this.favoritePetCount = 1,
    this.testedSkillUsages = const <PetSkillUsageMode>[],
  });

  List<WardrobeSimulateScenarioResult> topResults({int limit = 5}) {
    final sorted = List<WardrobeSimulateScenarioResult>.from(results)
      ..sort((a, b) {
        final byMean = b.stats.mean.compareTo(a.stats.mean);
        if (byMean != 0) return byMean;
        final byMedian = b.stats.median.compareTo(a.stats.median);
        if (byMedian != 0) return byMedian;
        return b.stats.max.compareTo(a.stats.max);
      });
    return sorted.take(limit).toList(growable: false);
  }
}

class WargearWardrobeSimulator {
  final DamageModel _model;

  WargearWardrobeSimulator({DamageModel? model})
      : _model = model ?? DamageModel();

  Future<WardrobeSimulateBatchResult> simulateTopCandidates({
    required SetupSnapshot baseSetup,
    required WargearFavoriteCandidateBatch candidateBatch,
    required Map<ElementType, int> guildElementBonuses,
    required int runsPerScenario,
    bool withTiming = true,
    void Function(int done, int total)? onProgress,
    SimulationCancellationToken? cancellationToken,
  }) async {
    if (!baseSetup.isRaidOrBlitz) {
      throw ArgumentError('Wardrobe Simulate supports only Raid / Blitz setups.');
    }
    final candidates = candidateBatch.topCandidates;
    if (candidates.length < 3) {
      return WardrobeSimulateBatchResult(
        baseSetup: baseSetup,
        candidateBatch: candidateBatch,
        runsPerScenario: runsPerScenario,
        totalScenarios: 0,
        results: const <WardrobeSimulateScenarioResult>[],
        testedPets: <SetupPetSnapshot>[baseSetup.pet],
        favoritePetCount: 1,
        testedSkillUsages: <PetSkillUsageMode>[baseSetup.pet.skillUsage],
      );
    }

    final scenarios = await _buildScenarioInputs(
      baseSetup: baseSetup,
      candidateBatch: candidateBatch,
      guildElementBonuses: guildElementBonuses,
    );
    final totalRunCount = scenarios.length * runsPerScenario;

    final results = <WardrobeSimulateScenarioResult>[];
    var completedRuns = 0;
    for (var i = 0; i < scenarios.length; i++) {
      if (cancellationToken?.isCancelled ?? false) {
        throw const SimulationCancelledException();
      }
      final scenario = scenarios[i];
      final stats = await _model.simulate(
        scenario.precomputed,
        runs: runsPerScenario,
        mode: scenario.fightMode,
        shatter: scenario.shatter,
        withTiming: withTiming,
        cycloneUseGemsForSpecials: scenario.setup.modeEffects.cycloneUseGemsForSpecials,
        cancellationToken: cancellationToken,
        onProgress: onProgress == null
            ? null
            : (done, total) {
                onProgress(completedRuns + done, totalRunCount);
              },
      );
      results.add(
        WardrobeSimulateScenarioResult(
          scenarioId: scenario.id,
          assignments: scenario.assignments,
          setup: scenario.setup,
          precomputed: scenario.precomputed,
          stats: stats,
        ),
      );
      completedRuns += runsPerScenario;
      onProgress?.call(completedRuns, totalRunCount);
    }

    return WardrobeSimulateBatchResult(
      baseSetup: baseSetup,
      candidateBatch: candidateBatch,
      runsPerScenario: runsPerScenario,
      totalScenarios: scenarios.length,
      results: List<WardrobeSimulateScenarioResult>.unmodifiable(results),
      testedPets: <SetupPetSnapshot>[baseSetup.pet],
      favoritePetCount: 1,
      testedSkillUsages: <PetSkillUsageMode>[baseSetup.pet.skillUsage],
    );
  }

  Future<List<_WardrobeScenarioInput>> _buildScenarioInputs({
    required SetupSnapshot baseSetup,
    required WargearFavoriteCandidateBatch candidateBatch,
    required Map<ElementType, int> guildElementBonuses,
  }) async {
    final candidates = candidateBatch.topCandidates;
    final out = <_WardrobeScenarioInput>[];
    WargearBossPressureProfile? bossPressureProfile;
    if (baseSetup.isRaidOrBlitz) {
      final boss = await ConfigLoader.loadBoss(
        raidMode: baseSetup.bossMode == 'raid',
        bossLevel: baseSetup.bossLevel,
        adv: const <double>[1.0, 1.0, 1.0],
        fightModeKey: 'normal',
      );
      bossPressureProfile = WargearBossPressureProfile.fromBossStats(
        modeKey: baseSetup.bossMode,
        bossAttack: boss.stats.attack,
        bossDefense: boss.stats.defense,
        bossHealth: boss.stats.hp,
      );
    }
    final contexts = List<WargearFavoriteCandidateContext>.generate(
      3,
      (index) => WargearFavoriteCandidateContext(
        id: 'k${index + 1}',
        label: 'K#${index + 1}',
        scoreContext: WargearUniversalScoreContext(
          bossMode: baseSetup.bossMode,
          bossLevel: baseSetup.bossLevel,
          bossElements: baseSetup.bossElements,
          petElements: <ElementType>[
            baseSetup.pet.element1,
            if (baseSetup.pet.element2 != null) baseSetup.pet.element2!,
          ],
          petElementalAttack: baseSetup.pet.elementalAtk,
          petElementalDefense: baseSetup.pet.elementalDef,
          stunPercent: 0.0,
          petSkillUsageMode: baseSetup.pet.skillUsage,
          petPrimarySkillName: baseSetup.manualOrImportedSkill1Name,
          petSecondarySkillName: baseSetup.manualOrImportedSkill2Name,
          bossPressureProfile: bossPressureProfile,
        ),
        scoreVariant: WargearUniversalScoreVariant.armorOnly,
      ),
      growable: false,
    );
    final scoring = const WargearUniversalScoringEngine();
    final normalizedGuildBonuses =
        normalizeWargearGuildElementBonuses(guildElementBonuses);

    for (var a = 0; a < candidates.length - 2; a++) {
      for (var b = a + 1; b < candidates.length - 1; b++) {
        for (var c = b + 1; c < candidates.length; c++) {
          final trio = <WargearFavoriteCandidate>[
            candidates[a],
            candidates[b],
            candidates[c],
          ];
          for (var primaryIndex = 0; primaryIndex < 3; primaryIndex++) {
            for (final permutation in _permutations3) {
              final assignments = <WardrobeSimulateArmorAssignment>[];
              final knightSnapshots = <SetupKnightSnapshot>[];

              for (var slot = 0; slot < 3; slot++) {
                final candidate = trio[permutation[slot]];
                final role = permutation[slot] == primaryIndex
                    ? WargearRole.primary
                    : WargearRole.secondary;
                final resolvedStats = candidate.entry.resolveStats(
                  role: role,
                  rank: candidateBatch.filters.rank,
                  plus: candidateBatch.filters.plus,
                  guildElementBonuses: normalizedGuildBonuses,
                );
                final finalStats = _finalStatsFor(
                  resolvedStats: resolvedStats,
                  armorElements: candidate.entry.elements,
                  pet: baseSetup.pet,
                );
                final stunPercent = baseSetup.knights[slot].stun.clamp(0.0, 100.0);
                final baseContext = contexts[slot].scoreContext;
                final scoreContext = WargearUniversalScoreContext(
                  bossMode: baseContext.bossMode,
                  bossLevel: baseContext.bossLevel,
                  bossElements: baseContext.bossElements,
                  petElements: baseContext.petElements,
                  petElementalAttack: baseContext.petElementalAttack,
                  petElementalDefense: baseContext.petElementalDefense,
                  stunPercent: stunPercent,
                  petSkillUsageMode: baseContext.petSkillUsageMode,
                  petPrimarySkillName: baseContext.petPrimarySkillName,
                  petSecondarySkillName: baseContext.petSecondarySkillName,
                  bossPressureProfile: baseContext.bossPressureProfile,
                );
                final armorOnlyScore = scoring.score(
                  stats: finalStats,
                  armorElements: candidate.entry.elements,
                  context: scoreContext,
                  variant: WargearUniversalScoreVariant.armorOnly,
                );
                final petAwareScore = scoring.score(
                  stats: finalStats,
                  armorElements: candidate.entry.elements,
                  context: scoreContext,
                  variant: WargearUniversalScoreVariant.petAware,
                );
                assignments.add(
                  WardrobeSimulateArmorAssignment(
                    slotIndex: slot,
                    entry: candidate.entry,
                    role: role,
                    resolvedStats: resolvedStats,
                    finalStats: finalStats,
                    universalArmorScore: armorOnlyScore,
                    petAwareUniversalArmorScore: petAwareScore,
                    stunPercent: stunPercent,
                  ),
                );
                knightSnapshots.add(
                  SetupKnightSnapshot(
                    atk: finalStats.attack,
                    def: finalStats.defense,
                    hp: finalStats.health,
                    stun: stunPercent,
                    elements: candidate.entry.elements,
                    active: true,
                  ),
                );
              }

              final scenarioSetup = SetupSnapshot(
                bossMode: baseSetup.bossMode,
                bossLevel: baseSetup.bossLevel,
                bossElements: baseSetup.bossElements,
                knights: knightSnapshots,
                fightMode: baseSetup.fightMode,
                pet: baseSetup.pet,
                modeEffects: baseSetup.modeEffects,
              );
              out.add(await _buildScenarioInput(
                id: '${_petScenarioPrefix(baseSetup.pet)}|${_scenarioId(assignments)}',
                setup: scenarioSetup,
                assignments: assignments,
              ));
            }
          }
        }
      }
    }
    return out;
  }

  String _scenarioId(List<WardrobeSimulateArmorAssignment> assignments) {
    return assignments
        .map(
          (assignment) =>
              's${assignment.slotIndex + 1}:${assignment.entry.id}:${assignment.role.name}',
        )
        .join('|');
  }

  String _petScenarioPrefix(SetupPetSnapshot pet) {
    final imported = pet.importedCompendium;
    if (imported != null && imported.familyId.trim().isNotEmpty) {
      return 'pet:${imported.familyId.trim()}';
    }
    if (imported != null && imported.tierName.trim().isNotEmpty) {
      return 'pet:${imported.tierName.trim().toLowerCase().replaceAll(' ', '_')}';
    }
    final second = pet.element2;
    return second == null
        ? 'pet:${pet.element1.id}'
        : 'pet:${pet.element1.id}_${second.id}';
  }
}

class _WardrobeScenarioInput {
  final String id;
  final SetupSnapshot setup;
  final List<WardrobeSimulateArmorAssignment> assignments;
  final FightMode fightMode;
  final ShatterShieldConfig shatter;
  final Precomputed precomputed;

  const _WardrobeScenarioInput({
    required this.id,
    required this.setup,
    required this.assignments,
    required this.fightMode,
    required this.shatter,
    required this.precomputed,
  });

}

Future<_WardrobeScenarioInput> _buildScenarioInput({
  required String id,
  required SetupSnapshot setup,
  required List<WardrobeSimulateArmorAssignment> assignments,
}) async {
  final fightMode = _effectiveFightMode(setup);
  final bossAdv = setup.knights
      .map((knight) => advantageMultiplier(setup.bossElements, knight.elements))
      .toList(growable: false);
  final rawBoss = await ConfigLoader.loadBoss(
    raidMode: setup.bossMode == 'raid',
    bossLevel: setup.bossLevel,
    adv: bossAdv,
    fightModeKey: fightMode.name,
  );
  final boss = BossConfig(
    meta: rawBoss.meta.copyWith(
      defaultDurableRockShield: setup.modeEffects.drsDefenseBoost,
      defaultElementalWeakness: setup.modeEffects.ewWeaknessEffect,
    ),
    stats: rawBoss.stats,
  );

  final kAdv = setup.knights
      .map((knight) => advantageMultiplier(knight.elements, setup.bossElements))
      .toList(growable: false);
  final kAtk = setup.knights
      .map((knight) => knight.atk.toDouble().clamp(0.0, 1e18))
      .toList(growable: false);
  final kDef = setup.knights
      .map((knight) => (knight.def <= 0 ? 1.0 : knight.def.toDouble()))
      .toList(growable: false);
  final kHp = setup.knights
      .map((knight) => knight.hp.clamp(1, 2000000000))
      .toList(growable: false);
  final kStun = setup.knights
      .map((knight) => (knight.stun / 100.0).clamp(0.0, 1.0))
      .toList(growable: false);

  final petElements = <ElementType>[
    setup.pet.element1,
    if (setup.pet.element2 != null) setup.pet.element2!,
  ];
  final petAdv = advantageMultiplier(petElements, setup.bossElements);
  final petStrong = petElements.any(
    (petElement) =>
        setup.bossElements.any((bossEl) => elementBeats(petElement, bossEl)),
  );

  final shatter = ShatterShieldConfig(
    baseHp: setup.modeEffects.shatterBaseHp.clamp(0, 999),
    bonusHp: setup.modeEffects.shatterBonusHp.clamp(0, 999),
    elementMatch: setup.knights
        .map((knight) => _petMatchesElements(petElements, knight.elements))
        .toList(growable: false),
    strongElementEw:
        List<bool>.filled(setup.knights.length, petStrong, growable: false),
  );

  final precomputed = DamageModel().precompute(
    boss: boss,
    kAtk: kAtk,
    kDef: kDef,
    kHp: kHp,
    kAdv: kAdv,
    kStun: kStun,
    petAtk: setup.pet.atk.toDouble().clamp(0.0, 1e18),
    petAdv: petAdv,
    petSkillUsage: setup.pet.skillUsage,
    petEffects:
        List<PetResolvedEffect>.from(setup.pet.resolvedEffects, growable: false),
  );

  return _WardrobeScenarioInput(
    id: id,
    setup: setup,
    assignments: assignments,
    fightMode: fightMode,
    shatter: shatter,
    precomputed: precomputed,
  );
}

FightMode _effectiveFightMode(SetupSnapshot setup) {
  return setup.pet.resolvedEffects.isNotEmpty ? FightMode.normal : setup.fightMode;
}

bool _petMatchesElements(List<ElementType> petElements, List<ElementType> armorElements) {
  for (final petEl in petElements) {
    for (final armorEl in armorElements) {
      if (petEl == armorEl) return true;
    }
  }
  return false;
}

WargearStats _finalStatsFor({
  required WargearStats resolvedStats,
  required List<ElementType> armorElements,
  required SetupPetSnapshot pet,
}) {
  final petElements = <ElementType>[
    pet.element1,
    if (pet.element2 != null) pet.element2!,
  ];
  final matchCount = _petArmorBonusMatchCount(
    armorElements: armorElements,
    petElements: petElements,
  );
  return WargearStats(
    attack: resolvedStats.attack + (pet.elementalAtk * matchCount),
    defense: resolvedStats.defense + (pet.elementalDef * matchCount),
    health: resolvedStats.health,
  );
}

int _petArmorBonusMatchCount({
  required List<ElementType> armorElements,
  required List<ElementType> petElements,
}) {
  if (petElements.isEmpty) return 0;
  final petFirst = petElements[0];
  final petSecond = petElements.length > 1 ? petElements[1] : null;

  if (petSecond == null) {
    return armorElements.contains(petFirst) ? 1 : 0;
  }
  if (petSecond == petFirst) {
    final armorFirst = armorElements[0];
    final armorSecond = armorElements[1];
    if (armorFirst == petFirst && armorSecond == petFirst) return 2;
    if (armorSecond == petFirst) return 2;
    if (armorFirst == petFirst) return 1;
    return 0;
  }
  if (armorElements[0] == petFirst && armorElements[1] == petSecond) {
    return 2;
  }
  return armorElements.contains(petFirst) ? 1 : 0;
}

const List<List<int>> _permutations3 = <List<int>>[
  <int>[0, 1, 2],
  <int>[0, 2, 1],
  <int>[1, 0, 2],
  <int>[1, 2, 0],
  <int>[2, 0, 1],
  <int>[2, 1, 0],
];

extension on SetupSnapshot {
  String? get manualOrImportedSkill1Name {
    if (pet.importedCompendium != null) {
      return pet.importedCompendium!.selectedSkill1.name;
    }
    return pet.manualSkill1?.name;
  }

  String? get manualOrImportedSkill2Name {
    if (pet.importedCompendium != null) {
      return pet.importedCompendium!.selectedSkill2.name;
    }
    return pet.manualSkill2?.name;
  }
}
