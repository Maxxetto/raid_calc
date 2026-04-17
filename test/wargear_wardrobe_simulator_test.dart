import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/setup_models.dart';
import 'package:raid_calc/data/wargear_universal_scoring.dart';
import 'package:raid_calc/data/wargear_wardrobe_candidates.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';
import 'package:raid_calc/data/wargear_wardrobe_simulator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('wardrobe simulator generates 180 scenarios from top 5 candidates',
      () async {
    final catalog = await WargearWardrobeLoader.load();
    final ids = _idsForNames(catalog, <String>[
      'Stormsea Hauberk',
      'Glacierrun Panoply',
      'Riverborn Shell',
      'Aeroforge Sentinel',
      'TerraPulse Blaster',
    ]);

    final candidateBatch =
        const WargearFavoriteCandidateSelector().rankFavorites(
      catalog: catalog,
      favoriteIds: ids,
      filters: const WargearWardrobeSavedFilters(
        seasonFilter: null,
        firstElement: null,
        secondElement: null,
        role: WargearRole.primary,
        rank: WargearGuildRank.highCommander,
        plus: true,
        sortModeName: 'score',
      ),
      contexts: const <WargearFavoriteCandidateContext>[
        WargearFavoriteCandidateContext(
          id: 'k1',
          label: 'K#1',
          scoreContext: WargearUniversalScoreContext(
            bossMode: 'raid',
            bossLevel: 6,
            bossElements: <ElementType>[ElementType.water, ElementType.air],
            petElements: <ElementType>[ElementType.water, ElementType.water],
            petElementalAttack: 1133,
            petElementalDefense: 960,
            stunPercent: 12.0,
            petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
          ),
        ),
        WargearFavoriteCandidateContext(
          id: 'k2',
          label: 'K#2',
          scoreContext: WargearUniversalScoreContext(
            bossMode: 'raid',
            bossLevel: 6,
            bossElements: <ElementType>[ElementType.water, ElementType.air],
            petElements: <ElementType>[ElementType.water, ElementType.water],
            petElementalAttack: 1133,
            petElementalDefense: 960,
            stunPercent: 5.0,
            petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
          ),
        ),
        WargearFavoriteCandidateContext(
          id: 'k3',
          label: 'K#3',
          scoreContext: WargearUniversalScoreContext(
            bossMode: 'raid',
            bossLevel: 6,
            bossElements: <ElementType>[ElementType.water, ElementType.air],
            petElements: <ElementType>[ElementType.water, ElementType.water],
            petElementalAttack: 1133,
            petElementalDefense: 960,
            stunPercent: 0.0,
            petSkillUsageMode: PetSkillUsageMode.special2ThenSpecial1,
          ),
        ),
      ],
      guildElementBonuses: const <ElementType, int>{
        ElementType.fire: 10,
        ElementType.spirit: 10,
        ElementType.earth: 10,
        ElementType.air: 10,
        ElementType.water: 10,
      },
      maxCandidates: 5,
    );

    final setup = SetupSnapshot(
      bossMode: 'raid',
      bossLevel: 6,
      bossElements: const <ElementType>[ElementType.water, ElementType.air],
      knights: const <SetupKnightSnapshot>[
        SetupKnightSnapshot(
          atk: 1000,
          def: 1000,
          hp: 1000,
          stun: 25.0,
          elements: <ElementType>[ElementType.fire, ElementType.fire],
          active: true,
        ),
        SetupKnightSnapshot(
          atk: 1000,
          def: 1000,
          hp: 1000,
          stun: 10.0,
          elements: <ElementType>[ElementType.fire, ElementType.fire],
          active: true,
        ),
        SetupKnightSnapshot(
          atk: 1000,
          def: 1000,
          hp: 1000,
          stun: 0.0,
          elements: <ElementType>[ElementType.fire, ElementType.fire],
          active: true,
        ),
      ],
      pet: const SetupPetSnapshot(
        atk: 20000,
        elementalAtk: 1133,
        elementalDef: 960,
        element1: ElementType.water,
        element2: ElementType.water,
        skillUsage: PetSkillUsageMode.special2ThenSpecial1,
      ),
      modeEffects: SetupModeEffectsSnapshot.defaults(),
    );

    final batch = await WargearWardrobeSimulator().simulateTopCandidates(
      baseSetup: setup,
      candidateBatch: candidateBatch,
      guildElementBonuses: const <ElementType, int>{
        ElementType.fire: 10,
        ElementType.spirit: 10,
        ElementType.earth: 10,
        ElementType.air: 10,
        ElementType.water: 10,
      },
      runsPerScenario: 5,
      withTiming: false,
    );

    expect(batch.totalScenarios, 180);
    expect(batch.results.length, 180);

    final sample = batch.results.first;
    expect(sample.assignments.length, 3);
    expect(
      sample.assignments
          .where((item) => item.role == WargearRole.primary)
          .length,
      1,
    );
    expect(
      sample.assignments.map((item) => item.entry.id).toSet().length,
      3,
    );
    for (final assignment in sample.assignments) {
      expect(
        assignment.petAwareUniversalArmorScore.score,
        greaterThan(assignment.universalArmorScore.score),
      );
    }

    final top5 = batch.topResults();
    expect(top5.length, 5);
    for (var i = 0; i < top5.length - 1; i++) {
      expect(top5[i].stats.mean, greaterThanOrEqualTo(top5[i + 1].stats.mean));
    }
  });
}

Set<String> _idsForNames(
  WargearWardrobeCatalog catalog,
  List<String> names,
) {
  final ids = <String>{};
  for (final name in names) {
    final match = catalog.armors.where((entry) => entry.name == name).first;
    ids.add(match.id);
  }
  return ids;
}
