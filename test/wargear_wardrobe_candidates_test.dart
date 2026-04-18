import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/wargear_favorites_storage.dart';
import 'package:raid_calc/data/wargear_universal_scoring.dart';
import 'package:raid_calc/data/wargear_wardrobe_candidates.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';
import 'package:raid_calc/data/wargear_wardrobe_sheet_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('selector ranks top 5 favorite armors and ignores saved role filter',
      () async {
    final catalog = await WargearWardrobeLoader.load();
    final ids = _idsForNames(catalog, <String>[
      'Stormsea Hauberk',
      'Glacierrun Panoply',
      'Riverborn Shell',
      'Aeroforge Sentinel',
      'TerraPulse Blaster',
      'Ultimate Quatuordecimus',
    ]);

    final batch = const WargearFavoriteCandidateSelector().rankFavorites(
      catalog: catalog,
      favoriteIds: ids,
      filters: const WargearWardrobeSavedFilters(
        seasonFilter: null,
        firstElement: null,
        secondElement: null,
        role: WargearRole.secondary,
        rank: WargearGuildRank.highCommander,
        plus: true,
        sortModeName: 'season',
      ),
      contexts: const <WargearFavoriteCandidateContext>[
        WargearFavoriteCandidateContext(
          id: 'k1',
          label: 'K#1',
          scoreContext: WargearUniversalScoreContext(
            bossMode: 'raid',
            bossLevel: 6,
            bossElements: <ElementType>[ElementType.fire, ElementType.spirit],
            petElements: <ElementType>[ElementType.fire, ElementType.fire],
            petElementalAttack: 0,
            petElementalDefense: 0,
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

    expect(batch.favoriteCount, ids.length);
    expect(batch.matchingFavoriteCount, ids.length);
    expect(batch.topCandidates.length, 5);
    for (final candidate in batch.topCandidates) {
      expect(candidate.scores.length, 2);
      expect(candidate.bestScore.role, WargearRole.primary);
    }
    for (var i = 0; i < batch.topCandidates.length - 1; i++) {
      expect(
        batch.topCandidates[i].bestScore.score.score,
        greaterThanOrEqualTo(batch.topCandidates[i + 1].bestScore.score.score),
      );
    }
  });

  test('selector loads persisted filters and respects season/plus favorites',
      () async {
    final catalog = await WargearWardrobeLoader.load();
    final ids = _idsForNames(catalog, <String>[
      'Glacierrun Panoply',
      'Riverborn Shell',
      'Stormsea Hauberk',
      'Aeroforge Sentinel',
      'Blazewreath Paladin T12',
    ]);
    await WargearFavoritesStorage.save(ids);
    await WargearWardrobeSheetStorage.save(<String, Object?>{
      'seasonFilter': 'S116',
      'firstElement': null,
      'secondElement': null,
      'role': WargearRole.secondary.name,
      'rank': WargearGuildRank.guildMaster.name,
      'plus': true,
      'sortMode': 'score',
    });

    final batch =
        await const WargearFavoriteCandidateSelector().loadTopFavoriteCandidates(
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
    );

    expect(batch.filters.seasonFilter, 'S116');
    expect(batch.filters.plus, isTrue);
    expect(batch.matchingFavoriteCount, 3);
    expect(
      batch.topCandidates.map((candidate) => candidate.entry.name),
      containsAll(<String>[
        'Glacierrun Panoply',
        'Riverborn Shell',
        'Stormsea Hauberk',
      ]),
    );
    expect(
      batch.topCandidates.map((candidate) => candidate.entry.name),
      isNot(contains('Aeroforge Sentinel')),
    );
  });

  test('candidate scoring defaults to armor-only even when pet skill context changes',
      () async {
    final catalog = await WargearWardrobeLoader.load();
    final ids = _idsForNames(catalog, <String>[
      'Stormsea Hauberk',
      'Glacierrun Panoply',
      'Riverborn Shell',
    ]);

    final batch = const WargearFavoriteCandidateSelector().rankFavorites(
      catalog: catalog,
      favoriteIds: ids,
      filters: const WargearWardrobeSavedFilters(
        seasonFilter: null,
        firstElement: null,
        secondElement: null,
        role: WargearRole.primary,
        rank: WargearGuildRank.commander,
        plus: false,
        sortModeName: 'score',
      ),
      contexts: const <WargearFavoriteCandidateContext>[
        WargearFavoriteCandidateContext(
          id: 'armor',
          label: 'Armor-only',
          scoreContext: WargearUniversalScoreContext(
            bossMode: 'raid',
            bossLevel: 6,
            bossElements: <ElementType>[ElementType.fire, ElementType.spirit],
            petElements: <ElementType>[ElementType.fire, ElementType.fire],
            petElementalAttack: 0,
            petElementalDefense: 0,
            petSkillUsageMode: PetSkillUsageMode.special1Only,
            petPrimarySkillName: 'Soul Burn',
            petSecondarySkillName: 'Special Regeneration',
          ),
        ),
        WargearFavoriteCandidateContext(
          id: 'still_armor',
          label: 'Still armor-only',
          scoreContext: WargearUniversalScoreContext(
            bossMode: 'raid',
            bossLevel: 6,
            bossElements: <ElementType>[ElementType.fire, ElementType.spirit],
            petElements: <ElementType>[ElementType.fire, ElementType.fire],
            petElementalAttack: 0,
            petElementalDefense: 0,
            petSkillUsageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
            petPrimarySkillName: 'Elemental Weakness',
            petSecondarySkillName: 'Special Regeneration Infinite',
          ),
        ),
      ],
      guildElementBonuses: const <ElementType, int>{},
      maxCandidates: 3,
    );

    expect(batch.topCandidates, isNotEmpty);
    final sample = batch.topCandidates.first.scores;
    expect(sample.length, 4);
    expect(
      sample[0].score.score,
      closeTo(sample[1].score.score, 1e-9),
    );
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
