import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/pet_compendium_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PetCompendiumLoader.clearCache);

  test('combined pet compendium catalog matches the merge of per-rarity loads',
      () async {
    final combined = await PetCompendiumLoader.load();
    final perRarity = <PetCompendiumCatalog>[];

    for (final rarity in PetCompendiumLoader.supportedRarities) {
      perRarity.add(await PetCompendiumLoader.load(rarity: rarity));
    }

    final merged = PetCompendiumCatalog(
      schemaVersion: perRarity.fold<int>(
        1,
        (value, catalog) =>
            catalog.schemaVersion > value ? catalog.schemaVersion : value,
      ),
      pets: perRarity.expand((catalog) => catalog.pets).toList(growable: false),
    );

    expect(_normalizeCatalog(combined), _normalizeCatalog(merged));
  });
}

Map<String, Object?> _normalizeCatalog(PetCompendiumCatalog catalog) {
  final pets = catalog.pets.map(_normalizeEntry).toList(growable: false)
    ..sort(_compareById);
  return <String, Object?>{
    'schemaVersion': catalog.schemaVersion,
    'pets': pets,
  };
}

Map<String, Object?> _normalizeEntry(PetCompendiumEntry entry) {
  final tiers = entry.tiers.map(_normalizeTier).toList(growable: false)
    ..sort(_compareById);
  return <String, Object?>{
    'id': entry.id,
    'rarity': entry.rarity,
    'familyTag': entry.familyTag,
    'tiers': tiers,
  };
}

Map<String, Object?> _normalizeTier(PetCompendiumTierVariant tier) {
  final profiles = tier.profiles.map(_normalizeProfile).toList(growable: false)
    ..sort(_compareById);
  return <String, Object?>{
    'id': tier.id,
    'name': tier.name,
    'element': tier.element.name,
    'secondElement': tier.secondElement?.name,
    'tier': tier.tier,
    'skill11': tier.skill11,
    'skill12': tier.skill12,
    'skill2': tier.skill2,
    'profiles': profiles,
  };
}

Map<String, Object?> _normalizeProfile(PetCompendiumStatsProfile profile) {
  final skills = profile.skills.values
      .map(_normalizeSkill)
      .toList(growable: false)
    ..sort(_compareById);
  return <String, Object?>{
    'id': profile.id,
    'label': profile.label,
    'valueSource': profile.valueSource,
    'level': profile.level,
    'petAttack': profile.petAttack,
    'petAttackStat': profile.petAttackStat,
    'petDefenseStat': profile.petDefenseStat,
    'skills': skills,
  };
}

Map<String, Object?> _normalizeSkill(PetCompendiumSkillDetails skill) {
  final keys = skill.values.keys.toList(growable: false)..sort();
  return <String, Object?>{
    'slotId': skill.slotId,
    'name': skill.name,
    'values': <String, num>{
      for (final key in keys) key: skill.values[key]!,
    },
  };
}

int _compareById(Map<String, Object?> a, Map<String, Object?> b) =>
    (a['id'] ?? '').toString().compareTo((b['id'] ?? '').toString());
