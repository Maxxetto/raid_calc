import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/element_types.dart';

class PetCompendiumSkillDetails {
  final String slotId;
  final String name;
  final Map<String, num> values;

  const PetCompendiumSkillDetails({
    required this.slotId,
    required this.name,
    required this.values,
  });

  factory PetCompendiumSkillDetails.fromJson(
    String slotId,
    Map<String, Object?> json,
  ) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final rawValues = (json['values'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final values = <String, num>{};
    for (final entry in rawValues.entries) {
      final raw = entry.value;
      if (raw is num) {
        values[entry.key] = raw;
        continue;
      }
      final parsed = num.tryParse(raw?.toString().trim() ?? '');
      if (parsed != null) {
        values[entry.key] = parsed;
      }
    }

    return PetCompendiumSkillDetails(
      slotId: slotId,
      name: read('name'),
      values: Map<String, num>.unmodifiable(values),
    );
  }

  bool get isValid => slotId.isNotEmpty && name.isNotEmpty;
}

class PetCompendiumStatsProfile {
  final String id;
  final String label;
  final String valueSource;
  final int level;
  final int petAttack;
  final int petAttackStat;
  final int petDefenseStat;
  final Map<String, PetCompendiumSkillDetails> skills;

  const PetCompendiumStatsProfile({
    required this.id,
    required this.label,
    required this.valueSource,
    required this.level,
    required this.petAttack,
    required this.petAttackStat,
    required this.petDefenseStat,
    required this.skills,
  });

  factory PetCompendiumStatsProfile.fromJson(Map<String, Object?> json) {
    String read(String key) => (json[key] ?? '').toString().trim();
    int readInt(String key) => int.tryParse(read(key)) ?? 0;
    final rawSkills =
        (json['skills'] as Map?)?.cast<String, Object?>() ?? const {};
    final skills = <String, PetCompendiumSkillDetails>{};
    for (final entry in rawSkills.entries) {
      final raw = entry.value;
      if (raw is! Map) continue;
      final parsed = PetCompendiumSkillDetails.fromJson(
        entry.key,
        raw.cast<String, Object?>(),
      );
      if (!parsed.isValid) continue;
      skills[entry.key] = parsed;
    }

    return PetCompendiumStatsProfile(
      id: read('id'),
      label: read('label'),
      valueSource: read('valueSource'),
      level: readInt('level'),
      petAttack: readInt('petAttack'),
      petAttackStat: readInt('petAttackStat'),
      petDefenseStat: readInt('petDefenseStat'),
      skills: Map<String, PetCompendiumSkillDetails>.unmodifiable(skills),
    );
  }

  bool get isValid =>
      id.isNotEmpty && label.isNotEmpty && valueSource.isNotEmpty && level >= 0;

  PetCompendiumSkillDetails skillOrFallback(
      String slotId, String fallbackName) {
    final resolved = skills[slotId];
    if (resolved != null) return resolved;
    return PetCompendiumSkillDetails(
      slotId: slotId,
      name: fallbackName,
      values: const <String, num>{},
    );
  }
}

class PetCompendiumTierVariant {
  final String id;
  final String name;
  final ElementType element;
  final ElementType? secondElement;
  final String tier;
  final List<PetCompendiumStatsProfile> profiles;
  final String skill11;
  final String skill12;
  final String skill2;

  const PetCompendiumTierVariant({
    required this.id,
    required this.name,
    required this.element,
    this.secondElement,
    required this.tier,
    required this.profiles,
    required this.skill11,
    required this.skill12,
    required this.skill2,
  });

  factory PetCompendiumTierVariant.fromJson(Map<String, Object?> json) {
    String read(String key) => (json[key] ?? '').toString().trim();
    int readInt(String key) => int.tryParse(read(key)) ?? 0;

    final rawProfiles =
        (json['profiles'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final profiles = rawProfiles
        .whereType<Map>()
        .map(
          (e) => PetCompendiumStatsProfile.fromJson(
            e.cast<String, Object?>(),
          ),
        )
        .where((e) => e.isValid)
        .toList(growable: false);

    final fallbackValueSource = read('valueSource');
    final fallbackProfile = profiles.isNotEmpty
        ? null
        : PetCompendiumStatsProfile(
            id: fallbackValueSource
                    .toLowerCase()
                    .trim()
                    .replaceAll(' ', '_')
                    .isEmpty
                ? 'default'
                : fallbackValueSource.toLowerCase().trim().replaceAll(' ', '_'),
            label:
                fallbackValueSource.isEmpty ? 'Default' : fallbackValueSource,
            valueSource:
                fallbackValueSource.isEmpty ? 'default' : fallbackValueSource,
            level: readInt('level'),
            petAttack: readInt('petAttack'),
            petAttackStat: readInt('petAttackStat'),
            petDefenseStat: readInt('petDefenseStat'),
            skills: const <String, PetCompendiumSkillDetails>{},
          );

    return PetCompendiumTierVariant(
      id: read('id').isEmpty ? read('tier') : read('id'),
      name: read('name'),
      element: ElementTypeCycle.fromId(read('element')),
      secondElement: read('secondElement').isEmpty
          ? null
          : ElementTypeCycle.fromId(read('secondElement')),
      tier: read('tier'),
      profiles: profiles.isNotEmpty
          ? profiles
          : <PetCompendiumStatsProfile>[fallbackProfile!],
      skill11: read('skill11'),
      skill12: read('skill12'),
      skill2: read('skill2'),
    );
  }

  bool get isValid =>
      id.isNotEmpty &&
      name.isNotEmpty &&
      tier.isNotEmpty &&
      profiles.isNotEmpty &&
      skill11.isNotEmpty &&
      skill12.isNotEmpty &&
      skill2.isNotEmpty;

  List<String> get allSkills => <String>[skill11, skill12, skill2]
      .where((skill) => !_isPlaceholderSkillName(skill))
      .toList(growable: false);
  List<ElementType> get allElements => <ElementType>[
        element,
        if (secondElement != null) secondElement!,
      ];

  PetCompendiumStatsProfile get defaultProfile {
    for (final profile in profiles) {
      if (profile.id == 'max') return profile;
    }
    return profiles.first;
  }

  PetCompendiumStatsProfile? profileById(String id) {
    for (final profile in profiles) {
      if (profile.id == id) return profile;
    }
    return null;
  }

  static int tierRank(String tier) {
    return switch (tier.trim().toUpperCase()) {
      'I' => 1,
      'II' => 2,
      'III' => 3,
      'IV' => 4,
      'V' => 5,
      _ => 0,
    };
  }
}

class PetCompendiumEntry {
  final String id;
  final String rarity;
  final String familyTag;
  final List<PetCompendiumTierVariant> tiers;

  const PetCompendiumEntry({
    required this.id,
    required this.rarity,
    required this.familyTag,
    required this.tiers,
  });

  factory PetCompendiumEntry.fromJson(Map<String, Object?> json) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final rawTiers =
        (json['tiers'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final parsedTiers = rawTiers
        .whereType<Map>()
        .map(
          (e) => PetCompendiumTierVariant.fromJson(
            e.cast<String, Object?>(),
          ),
        )
        .where((e) => e.isValid)
        .toList(growable: false);

    // Backward compatibility with the previous flat schema.
    final fallbackTier =
        parsedTiers.isNotEmpty ? null : PetCompendiumTierVariant.fromJson(json);

    String deriveFamilyTag() {
      final explicit = read('familyTag');
      if (explicit.isNotEmpty) return explicit;
      final source = parsedTiers.isNotEmpty
          ? parsedTiers.first.name
          : (fallbackTier?.name ?? '');
      final match = RegExp(r'^\[([^\]]+)\]').firstMatch(source);
      return match == null ? '' : match.group(1) ?? '';
    }

    return PetCompendiumEntry(
      id: read('id'),
      rarity: read('rarity'),
      familyTag: deriveFamilyTag(),
      tiers: parsedTiers.isNotEmpty
          ? parsedTiers
          : ((fallbackTier != null && fallbackTier.isValid)
              ? <PetCompendiumTierVariant>[fallbackTier]
              : <PetCompendiumTierVariant>[]),
    );
  }

  bool get isValid => id.isNotEmpty && rarity.isNotEmpty && tiers.isNotEmpty;

  List<String> get allSkills => tiers
      .expand((tier) => tier.allSkills)
      .where((skill) => !_isPlaceholderSkillName(skill))
      .toSet()
      .toList(growable: false);
  List<ElementType> get allElements =>
      tiers.expand((tier) => tier.allElements).toSet().toList(growable: false);
  List<String> get allNames =>
      tiers.map((tier) => tier.name).toSet().toList(growable: false);
  List<String> get availableTiers {
    final tiersSorted = tiers.toList(growable: false)
      ..sort((a, b) => PetCompendiumTierVariant.tierRank(b.tier).compareTo(
            PetCompendiumTierVariant.tierRank(a.tier),
          ));
    return tiersSorted.map((tier) => tier.tier).toList(growable: false);
  }

  bool containsTier(String tier) =>
      tiers.any((variant) => variant.tier == tier);

  PetCompendiumTierVariant get highestTier {
    final sorted = tiers.toList(growable: false)
      ..sort((a, b) => PetCompendiumTierVariant.tierRank(b.tier).compareTo(
            PetCompendiumTierVariant.tierRank(a.tier),
          ));
    return sorted.first;
  }

  PetCompendiumTierVariant? tierById(String tierId) {
    for (final tier in tiers) {
      if (tier.id == tierId || tier.tier == tierId) return tier;
    }
    return null;
  }
}

class PetCompendiumCatalog {
  final int schemaVersion;
  final List<PetCompendiumEntry> pets;

  const PetCompendiumCatalog({
    required this.schemaVersion,
    required this.pets,
  });

  factory PetCompendiumCatalog.fromJson(Map<String, Object?> json) {
    final rawFamilies =
        (json['families'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final rawPets =
        (json['pets'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final rawEntries = rawFamilies.isNotEmpty ? rawFamilies : rawPets;

    final pets = rawEntries
        .whereType<Map>()
        .map((e) => PetCompendiumEntry.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);

    final schemaVersion =
        int.tryParse((json['schemaVersion'] ?? '1').toString()) ?? 1;
    return PetCompendiumCatalog(schemaVersion: schemaVersion, pets: pets);
  }
}

class PetCompendiumLoader {
  static const String _libraryAsset =
      'assets/pet_compendium_compact_library.json';
  static const Map<String, String> _assetByRarity = <String, String>{
    '5 stars': 'assets/pet_compendium_compact_index_five_star.json',
    '4 stars': 'assets/pet_compendium_compact_index_four_star.json',
    '3 stars': 'assets/pet_compendium_compact_index_three_star.json',
    'Primal': 'assets/pet_compendium_compact_index_primal.json',
    'Shadowforged': 'assets/pet_compendium_compact_index_shadowforged.json',
  };

  static _CompactLibrary? _libraryCache;
  static final Map<String, PetCompendiumCatalog> _rarityCache =
      <String, PetCompendiumCatalog>{};
  static PetCompendiumCatalog? _allCache;

  static List<String> get supportedRarities =>
      _assetByRarity.keys.toList(growable: false);

  static Future<PetCompendiumCatalog> load({String? rarity}) async {
    if (rarity != null && _assetByRarity.containsKey(rarity)) {
      return _loadSingle(rarity);
    }
    if (_allCache != null) return _allCache!;

    final catalogs = await Future.wait(_assetByRarity.keys.map(_loadSingle));
    final schemaVersion = catalogs.fold<int>(
      1,
      (value, catalog) =>
          catalog.schemaVersion > value ? catalog.schemaVersion : value,
    );
    _allCache = PetCompendiumCatalog(
      schemaVersion: schemaVersion,
      pets: catalogs.expand((catalog) => catalog.pets).toList(growable: false),
    );
    return _allCache!;
  }

  static Future<PetCompendiumCatalog> _loadSingle(String rarity) async {
    final cached = _rarityCache[rarity];
    if (cached != null) return cached;

    final asset = _assetByRarity[rarity];
    if (asset == null) {
      const empty =
          PetCompendiumCatalog(schemaVersion: 1, pets: <PetCompendiumEntry>[]);
      return empty;
    }

    final library = await _loadLibrary();
    final raw = await rootBundle.loadString(asset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      const empty =
          PetCompendiumCatalog(schemaVersion: 1, pets: <PetCompendiumEntry>[]);
      _rarityCache[rarity] = empty;
      return empty;
    }
    final json = decoded.cast<String, Object?>();
    final schemaVersion =
        int.tryParse((json['schemaVersion'] ?? '1').toString()) ?? 1;
    final rawFamilies =
        (json['families'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final pets = rawFamilies
        .whereType<Map>()
        .map(
          (entry) => _buildEntry(
            entry.cast<String, Object?>(),
            rarity: rarity,
            library: library,
          ),
        )
        .where((entry) => entry.isValid)
        .toList(growable: false);

    final catalog = PetCompendiumCatalog(
      schemaVersion: schemaVersion,
      pets: pets,
    );
    _rarityCache[rarity] = catalog;
    return catalog;
  }

  static void clearCache() {
    _allCache = null;
    _libraryCache = null;
    _rarityCache.clear();
  }

  static Future<_CompactLibrary> _loadLibrary() async {
    final cached = _libraryCache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_libraryAsset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('Invalid compact pet compendium library asset.');
    }
    _libraryCache = _CompactLibrary.fromJson(decoded.cast<String, Object?>());
    return _libraryCache!;
  }

  static PetCompendiumEntry _buildEntry(
    Map<String, Object?> json, {
    required String rarity,
    required _CompactLibrary library,
  }) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final rawTiers =
        (json['tiers'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final tiers = rawTiers
        .whereType<Map>()
        .map(
          (tier) => _buildTier(
            tier.cast<String, Object?>(),
            library: library,
          ),
        )
        .where((tier) => tier.isValid)
        .toList(growable: false);

    return PetCompendiumEntry(
      id: read('id'),
      rarity: read('rarity').isEmpty ? rarity : read('rarity'),
      familyTag: read('familyTag'),
      tiers: tiers,
    );
  }

  static PetCompendiumTierVariant _buildTier(
    Map<String, Object?> json, {
    required _CompactLibrary library,
  }) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final rawProfiles =
        (json['profiles'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final profiles = rawProfiles
        .whereType<Map>()
        .map(
          (profile) => _buildProfile(
            profile.cast<String, Object?>(),
            library: library,
          ),
        )
        .where((profile) => profile.isValid)
        .toList(growable: false);

    return PetCompendiumTierVariant(
      id: read('id').isEmpty ? read('tier') : read('id'),
      name: read('name'),
      element: ElementTypeCycle.fromId(read('element')),
      secondElement: read('secondElement').isEmpty
          ? null
          : ElementTypeCycle.fromId(read('secondElement')),
      tier: read('tier'),
      profiles: profiles,
      skill11: read('skill11'),
      skill12: read('skill12'),
      skill2: read('skill2'),
    );
  }

  static PetCompendiumStatsProfile _buildProfile(
    Map<String, Object?> json, {
    required _CompactLibrary library,
  }) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final stats = library.statsById[read('statsRef')];
    final skillSet = library.skillSetsById[read('skillSetRef')];
    final skills = <String, PetCompendiumSkillDetails>{};
    if (skillSet != null) {
      for (final slotId in const <String>['skill11', 'skill12', 'skill2']) {
        final payloadId = skillSet.payloadBySlot[slotId];
        if (payloadId == null) continue;
        final payload = library.skillPayloadsById[payloadId];
        if (payload == null) continue;
        skills[slotId] = PetCompendiumSkillDetails(
          slotId: slotId,
          name: payload.name,
          values: payload.values,
        );
      }
    }

    return PetCompendiumStatsProfile(
      id: read('id'),
      label: read('label'),
      valueSource: read('valueSource'),
      level: stats?.level ?? 0,
      petAttack: stats?.petAttack ?? 0,
      petAttackStat: stats?.petAttackStat ?? 0,
      petDefenseStat: stats?.petDefenseStat ?? 0,
      skills: Map<String, PetCompendiumSkillDetails>.unmodifiable(skills),
    );
  }
}

bool _isPlaceholderSkillName(String name) {
  final normalized = name.trim().toLowerCase();
  return normalized.isEmpty || normalized == 'none';
}

class _CompactLibrary {
  final Map<String, _CompactStatsProfile> statsById;
  final Map<String, _CompactSkillPayload> skillPayloadsById;
  final Map<String, _CompactSkillSet> skillSetsById;

  const _CompactLibrary({
    required this.statsById,
    required this.skillPayloadsById,
    required this.skillSetsById,
  });

  factory _CompactLibrary.fromJson(Map<String, Object?> json) {
    final rawStats =
        (json['statsProfiles'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final rawPayloads =
        (json['skillPayloads'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final rawSets =
        (json['skillSets'] as List?)?.cast<Object?>() ?? const <Object?>[];

    final statsById = <String, _CompactStatsProfile>{};
    for (final raw in rawStats.whereType<Map>()) {
      final profile =
          _CompactStatsProfile.fromJson(raw.cast<String, Object?>());
      statsById[profile.id] = profile;
    }

    final payloadsById = <String, _CompactSkillPayload>{};
    for (final raw in rawPayloads.whereType<Map>()) {
      final payload =
          _CompactSkillPayload.fromJson(raw.cast<String, Object?>());
      payloadsById[payload.id] = payload;
    }

    final skillSetsById = <String, _CompactSkillSet>{};
    for (final raw in rawSets.whereType<Map>()) {
      final skillSet = _CompactSkillSet.fromJson(raw.cast<String, Object?>());
      skillSetsById[skillSet.id] = skillSet;
    }

    return _CompactLibrary(
      statsById: Map<String, _CompactStatsProfile>.unmodifiable(statsById),
      skillPayloadsById:
          Map<String, _CompactSkillPayload>.unmodifiable(payloadsById),
      skillSetsById: Map<String, _CompactSkillSet>.unmodifiable(skillSetsById),
    );
  }
}

class _CompactStatsProfile {
  final String id;
  final int level;
  final int petAttack;
  final int petAttackStat;
  final int petDefenseStat;

  const _CompactStatsProfile({
    required this.id,
    required this.level,
    required this.petAttack,
    required this.petAttackStat,
    required this.petDefenseStat,
  });

  factory _CompactStatsProfile.fromJson(Map<String, Object?> json) {
    int readInt(String key) => int.tryParse((json[key] ?? '0').toString()) ?? 0;
    String read(String key) => (json[key] ?? '').toString().trim();

    return _CompactStatsProfile(
      id: read('id'),
      level: readInt('level'),
      petAttack: readInt('petAttack'),
      petAttackStat: readInt('petAttackStat'),
      petDefenseStat: readInt('petDefenseStat'),
    );
  }
}

class _CompactSkillPayload {
  final String id;
  final String name;
  final Map<String, num> values;

  const _CompactSkillPayload({
    required this.id,
    required this.name,
    required this.values,
  });

  factory _CompactSkillPayload.fromJson(Map<String, Object?> json) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final rawValues = (json['values'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final values = <String, num>{};
    for (final entry in rawValues.entries) {
      final raw = entry.value;
      if (raw is num) {
        values[entry.key] = raw;
        continue;
      }
      final parsed = num.tryParse((raw ?? '').toString().trim());
      if (parsed != null) {
        values[entry.key] = parsed;
      }
    }

    return _CompactSkillPayload(
      id: read('id'),
      name: read('name'),
      values: Map<String, num>.unmodifiable(values),
    );
  }
}

class _CompactSkillSet {
  final String id;
  final Map<String, String> payloadBySlot;

  const _CompactSkillSet({
    required this.id,
    required this.payloadBySlot,
  });

  factory _CompactSkillSet.fromJson(Map<String, Object?> json) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final payloadBySlot = <String, String>{};
    for (final slotId in const <String>['skill11', 'skill12', 'skill2']) {
      final payloadId = read(slotId);
      if (payloadId.isEmpty) continue;
      payloadBySlot[slotId] = payloadId;
    }
    return _CompactSkillSet(
      id: read('id'),
      payloadBySlot: Map<String, String>.unmodifiable(payloadBySlot),
    );
  }
}
