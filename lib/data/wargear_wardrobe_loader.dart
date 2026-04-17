import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/element_types.dart';

const List<ElementType> wargearGuildBonusElements = <ElementType>[
  ElementType.fire,
  ElementType.spirit,
  ElementType.earth,
  ElementType.air,
  ElementType.water,
];

const Map<ElementType, int> _defaultGuildElementBonusPercents =
    <ElementType, int>{
  ElementType.fire: 10,
  ElementType.spirit: 10,
  ElementType.earth: 10,
  ElementType.air: 10,
  ElementType.water: 10,
};

Map<ElementType, int> defaultWargearGuildElementBonuses() =>
    Map<ElementType, int>.from(_defaultGuildElementBonusPercents);

Map<ElementType, int> normalizeWargearGuildElementBonuses(
  Map<ElementType, int>? raw,
) {
  final normalized = defaultWargearGuildElementBonuses();
  if (raw == null) return normalized;
  for (final element in wargearGuildBonusElements) {
    normalized[element] =
        (raw[element] ?? normalized[element] ?? 10).clamp(0, 10);
  }
  return normalized;
}

Map<String, Object?> wargearGuildElementBonusesToJson(
  Map<ElementType, int>? bonuses,
) {
  final normalized = normalizeWargearGuildElementBonuses(bonuses);
  return <String, Object?>{
    for (final element in wargearGuildBonusElements)
      element.id: normalized[element] ?? 10,
  };
}

Map<ElementType, int> wargearGuildElementBonusesFromJson(Object? raw) {
  final map = (raw as Map?)?.cast<String, Object?>() ?? const {};
  return normalizeWargearGuildElementBonuses(
    <ElementType, int>{
      for (final element in wargearGuildBonusElements)
        element: int.tryParse((map[element.id] ?? '10').toString()) ?? 10,
    },
  );
}

enum WargearRole {
  primary,
  secondary,
}

enum WargearGuildRank {
  commander,
  highCommander,
  gcGs,
  guildMaster,
}

class WargearImportSnapshot {
  final String entryId;
  final String displayName;
  final List<ElementType> elements;
  final WargearRole role;
  final WargearGuildRank rank;
  final bool plus;
  final WargearStats stats;

  const WargearImportSnapshot({
    required this.entryId,
    required this.displayName,
    required List<ElementType> elements,
    required this.role,
    required this.rank,
    required this.plus,
    required this.stats,
  }) : elements = elements;

  factory WargearImportSnapshot.fromSelection(
    WargearWardrobeSelectionLike selection,
  ) {
    return WargearImportSnapshot(
      entryId: selection.entryId,
      displayName: selection.displayName,
      elements: selection.elements,
      role: selection.role,
      rank: selection.rank,
      plus: selection.plus,
      stats: selection.stats,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'entryId': entryId,
        'displayName': displayName,
        'elements': elements.map((e) => e.id).toList(growable: false),
        'role': role.name,
        'rank': rank.name,
        'plus': plus,
        'stats': stats.toJson(),
      };

  factory WargearImportSnapshot.fromJson(Map<String, Object?> json) {
    final rawElements =
        (json['elements'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final elements = rawElements
        .map((value) => ElementTypeCycle.fromId(value?.toString()))
        .take(2)
        .toList(growable: false);
    final rawStats = (json['stats'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    return WargearImportSnapshot(
      entryId: (json['entryId'] ?? '').toString().trim(),
      displayName: (json['displayName'] ?? '').toString().trim(),
      elements: elements.length == 2
          ? List<ElementType>.unmodifiable(elements)
          : const <ElementType>[ElementType.fire, ElementType.fire],
      role: WargearRole.values.firstWhere(
        (value) => value.name == (json['role'] as String?)?.trim(),
        orElse: () => WargearRole.primary,
      ),
      rank: WargearGuildRank.values.firstWhere(
        (value) => value.name == (json['rank'] as String?)?.trim(),
        orElse: () => WargearGuildRank.commander,
      ),
      plus: json['plus'] == true,
      stats: WargearStats.fromJson(rawStats),
    );
  }
}

abstract interface class WargearWardrobeSelectionLike {
  String get entryId;
  String get displayName;
  List<ElementType> get elements;
  WargearRole get role;
  WargearGuildRank get rank;
  bool get plus;
  WargearStats get stats;
}

class WargearStats {
  final int attack;
  final int defense;
  final int health;

  const WargearStats({
    required this.attack,
    required this.defense,
    required this.health,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'attack': attack,
        'defense': defense,
        'health': health,
      };

  factory WargearStats.fromJson(Map<String, Object?> json) {
    return WargearStats(
      attack: int.tryParse((json['attack'] ?? '0').toString()) ?? 0,
      defense: int.tryParse((json['defense'] ?? '0').toString()) ?? 0,
      health: int.tryParse((json['health'] ?? '0').toString()) ?? 0,
    );
  }
}

class WargearAccessoryBonus {
  final int attack;
  final int health;

  const WargearAccessoryBonus({
    required this.attack,
    required this.health,
  });

  factory WargearAccessoryBonus.fromJson(Map<String, Object?> json) {
    return WargearAccessoryBonus(
      attack: int.tryParse((json['attack'] ?? '0').toString()) ?? 0,
      health: int.tryParse((json['health'] ?? '0').toString()) ?? 0,
    );
  }
}

class WargearKnightBaseStats {
  final int attack;
  final int defense;
  final int health;

  const WargearKnightBaseStats({
    required this.attack,
    required this.defense,
    required this.health,
  });

  factory WargearKnightBaseStats.fromJson(Map<String, Object?> json) {
    return WargearKnightBaseStats(
      attack: int.tryParse((json['attack'] ?? '0').toString()) ?? 0,
      defense: int.tryParse((json['defense'] ?? '0').toString()) ?? 0,
      health: int.tryParse((json['health'] ?? '0').toString()) ?? 0,
    );
  }
}

class WargearArmorCoreStats {
  final int attack;
  final int defense;

  const WargearArmorCoreStats({
    required this.attack,
    required this.defense,
  });

  factory WargearArmorCoreStats.fromJson(Map<String, Object?> json) {
    return WargearArmorCoreStats(
      attack: int.tryParse((json['attack'] ?? '0').toString()) ?? 0,
      defense: int.tryParse((json['defense'] ?? '0').toString()) ?? 0,
    );
  }
}

class WargearSetBonusStats {
  final int attack;
  final int defense;
  final int health;

  const WargearSetBonusStats({
    required this.attack,
    required this.defense,
    required this.health,
  });

  factory WargearSetBonusStats.fromJson(Map<String, Object?> json) {
    return WargearSetBonusStats(
      attack: int.tryParse((json['attack'] ?? '0').toString()) ?? 0,
      defense: int.tryParse((json['defense'] ?? '0').toString()) ?? 0,
      health: int.tryParse((json['health'] ?? '0').toString()) ?? 0,
    );
  }
}

class WargearVariantStats {
  final WargearArmorCoreStats? armorBaseStats;
  final WargearArmorCoreStats? coreStats;
  final WargearSetBonusStats? setBonusStats;
  final int? setBonusHealth;
  final WargearAccessoryBonus? ringBonus;
  final WargearAccessoryBonus? amuletBonus;

  const WargearVariantStats({
    this.armorBaseStats,
    this.coreStats,
    this.setBonusStats,
    this.setBonusHealth,
    this.ringBonus,
    this.amuletBonus,
  });

  factory WargearVariantStats.fromJson(Map<String, Object?> json) {
    final coreJson =
        (json['coreStats'] as Map?)?.cast<String, Object?>() ?? const {};
    final armorBaseJson =
        (json['armorBaseStats'] as Map?)?.cast<String, Object?>() ?? const {};
    final setBonusJson =
        (json['setBonusStats'] as Map?)?.cast<String, Object?>() ?? const {};
    final ringJson =
        (json['ringBonus'] as Map?)?.cast<String, Object?>() ?? const {};
    final amuletJson =
        (json['amuletBonus'] as Map?)?.cast<String, Object?>() ?? const {};
    return WargearVariantStats(
      armorBaseStats: armorBaseJson.isEmpty
          ? null
          : WargearArmorCoreStats.fromJson(armorBaseJson),
      coreStats:
          coreJson.isEmpty ? null : WargearArmorCoreStats.fromJson(coreJson),
      setBonusStats: setBonusJson.isEmpty
          ? null
          : WargearSetBonusStats.fromJson(setBonusJson),
      setBonusHealth: json.containsKey('setBonusHealth')
          ? int.tryParse((json['setBonusHealth'] ?? '0').toString()) ?? 0
          : null,
      ringBonus:
          ringJson.isEmpty ? null : WargearAccessoryBonus.fromJson(ringJson),
      amuletBonus: amuletJson.isEmpty
          ? null
          : WargearAccessoryBonus.fromJson(amuletJson),
    );
  }

  factory WargearVariantStats.fromCompactVector(
    List<int> values, {
    WargearAccessoryBonus? ringBonus,
    WargearAccessoryBonus? amuletBonus,
  }) {
    final padded = List<int>.from(values);
    while (padded.length < 5) {
      padded.add(0);
    }
    return WargearVariantStats(
      armorBaseStats: WargearArmorCoreStats(
        attack: padded[0],
        defense: padded[1],
      ),
      setBonusStats: WargearSetBonusStats(
        attack: padded[2],
        defense: padded[3],
        health: padded[4],
      ),
      ringBonus: ringBonus,
      amuletBonus: amuletBonus,
    );
  }
}

class WargearWardrobeRules {
  final Map<ElementType, WargearAccessoryBonus> ringBonuses;
  final Map<ElementType, WargearAccessoryBonus> amuletBonuses;
  final Map<WargearRole, WargearKnightBaseStats> knightBaseStats;
  final Map<WargearGuildRank, int> rankBonuses;
  final Map<ElementType, int> defaultGuildElementBonuses;

  const WargearWardrobeRules({
    required this.ringBonuses,
    required this.amuletBonuses,
    required this.knightBaseStats,
    required this.rankBonuses,
    required this.defaultGuildElementBonuses,
  });

  factory WargearWardrobeRules.fromJson(Map<String, Object?> json) {
    Map<ElementType, WargearAccessoryBonus> parseAccessoryMap(String key) {
      final raw = (json[key] as Map?)?.cast<String, Object?>() ?? const {};
      return Map<ElementType, WargearAccessoryBonus>.unmodifiable(
        <ElementType, WargearAccessoryBonus>{
          for (final element in wargearGuildBonusElements)
            element: WargearAccessoryBonus.fromJson(
              (raw[element.id] as Map?)?.cast<String, Object?>() ?? const {},
            ),
        },
      );
    }

    final rawKnightBaseStats =
        (json['knightBaseStats'] as Map?)?.cast<String, Object?>() ?? const {};
    final rawRankBonuses =
        (json['rankBonuses'] as Map?)?.cast<String, Object?>() ?? const {};

    return WargearWardrobeRules(
      ringBonuses: parseAccessoryMap('ringBonuses'),
      amuletBonuses: parseAccessoryMap('amuletBonuses'),
      knightBaseStats: Map<WargearRole, WargearKnightBaseStats>.unmodifiable(
        <WargearRole, WargearKnightBaseStats>{
          for (final role in WargearRole.values)
            role: WargearKnightBaseStats.fromJson(
              (rawKnightBaseStats[role.name] as Map?)
                      ?.cast<String, Object?>() ??
                  const {},
            ),
        },
      ),
      rankBonuses: Map<WargearGuildRank, int>.unmodifiable(
        <WargearGuildRank, int>{
          for (final rank in WargearGuildRank.values)
            rank: int.tryParse((rawRankBonuses[rank.name] ?? '0').toString()) ??
                0,
        },
      ),
      defaultGuildElementBonuses: Map<ElementType, int>.unmodifiable(
        wargearGuildElementBonusesFromJson(
          json['defaultGuildElementBonuses'],
        ),
      ),
    );
  }
}

class WargearWardrobeEntry {
  final String id;
  final String name;
  final String seasonTag;
  final List<ElementType> elements;
  final WargearVariantStats baseStats;
  final WargearVariantStats? plusStats;
  final WargearWardrobeRules rules;

  const WargearWardrobeEntry({
    required this.id,
    required this.name,
    required this.seasonTag,
    required this.elements,
    required this.baseStats,
    required this.plusStats,
    required this.rules,
  });

  factory WargearWardrobeEntry.fromJson(
    Map<String, Object?> json, {
    required WargearWardrobeRules rules,
  }) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final rawElements =
        (json['elements'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final elements = rawElements
        .map((value) => ElementTypeCycle.fromId(value?.toString()))
        .take(2)
        .toList(growable: false);
    final baseStats =
        (json['baseStats'] as Map?)?.cast<String, Object?>() ?? const {};
    final plusStats =
        (json['plusStats'] as Map?)?.cast<String, Object?>() ?? const {};
    final statsVector = ((json['stats'] as List?) ?? const <Object?>[])
        .map((value) => int.tryParse(value.toString()) ?? 0)
        .toList(growable: false);
    final jewelryVector = ((json['jewelry'] as List?) ?? const <Object?>[])
        .map((value) => int.tryParse(value.toString()) ?? 0)
        .toList(growable: false);

    WargearAccessoryBonus? accessoryFromVector(int offset) {
      if (jewelryVector.length < offset + 2) return null;
      return WargearAccessoryBonus(
        attack: jewelryVector[offset],
        health: jewelryVector[offset + 1],
      );
    }

    return WargearWardrobeEntry(
      id: read('id'),
      name: read('name'),
      seasonTag: read('seasonTag'),
      elements: List<ElementType>.unmodifiable(elements),
      baseStats: statsVector.isNotEmpty
          ? WargearVariantStats.fromCompactVector(
              statsVector.take(5).toList(growable: false),
              ringBonus: accessoryFromVector(0),
              amuletBonus: accessoryFromVector(2),
            )
          : WargearVariantStats.fromJson(baseStats),
      plusStats: statsVector.length >= 10
          ? WargearVariantStats.fromCompactVector(
              statsVector.skip(5).take(5).toList(growable: false),
              ringBonus: accessoryFromVector(4),
              amuletBonus: accessoryFromVector(6),
            )
          : (plusStats.isEmpty
              ? null
              : WargearVariantStats.fromJson(plusStats)),
      rules: rules,
    );
  }

  bool get isValid =>
      id.isNotEmpty &&
      name.isNotEmpty &&
      elements.length == 2 &&
      (rules.ringBonuses.containsKey(elements.first) ||
          baseStats.ringBonus != null ||
          plusStats?.ringBonus != null) &&
      (rules.amuletBonuses.containsKey(elements[1]) ||
          baseStats.amuletBonus != null ||
          plusStats?.amuletBonus != null);

  bool get supportsPlus => plusStats != null;

  WargearStats resolveStats({
    required WargearRole role,
    required WargearGuildRank rank,
    required bool plus,
    Map<ElementType, int>? guildElementBonuses,
  }) {
    final variant = plusStats != null && plus ? plusStats! : baseStats;
    final ring = variant.ringBonus ??
        rules.ringBonuses[elements.first] ??
        const WargearAccessoryBonus(attack: 0, health: 0);
    final amulet = variant.amuletBonus ??
        rules.amuletBonuses[elements[1]] ??
        const WargearAccessoryBonus(attack: 0, health: 0);
    final knight = rules.knightBaseStats[role] ??
        const WargearKnightBaseStats(attack: 0, defense: 0, health: 0);
    final normalizedGuildBonuses = normalizeWargearGuildElementBonuses(
      guildElementBonuses ?? rules.defaultGuildElementBonuses,
    );

    final guildBonusPercent = elements.fold<int>(
      0,
      (sum, element) => sum + (normalizedGuildBonuses[element] ?? 0),
    );
    final guildMultiplier = 1.0 + (guildBonusPercent / 100.0);
    final rankMultiplier =
        1.0 + ((rules.rankBonuses[rank] ?? 0).clamp(0, 100) / 100.0);

    final armorBase = variant.armorBaseStats;
    final setBonus = variant.setBonusStats;
    final attackCore = variant.coreStats?.attack ??
        ((armorBase?.attack ?? 0) + (setBonus?.attack ?? 0));
    final defenseCore = variant.coreStats?.defense ??
        ((armorBase?.defense ?? 0) + (setBonus?.defense ?? 0));
    final setHealth =
        variant.setBonusStats?.health ?? variant.setBonusHealth ?? 0;

    final attackRaw = attackCore + ring.attack + amulet.attack + knight.attack;
    final defenseRaw = defenseCore + knight.defense;

    return WargearStats(
      attack: (attackRaw * guildMultiplier * rankMultiplier).floor(),
      defense: (defenseRaw * guildMultiplier * rankMultiplier).floor(),
      health: setHealth + ring.health + amulet.health + knight.health,
    );
  }

  String displayName({required bool plus}) =>
      plus && supportsPlus ? '$name +' : name;
}

class WargearWardrobeCatalog {
  final int schemaVersion;
  final WargearWardrobeRules rules;
  final List<WargearWardrobeEntry> armors;

  const WargearWardrobeCatalog({
    required this.schemaVersion,
    required this.rules,
    required this.armors,
  });

  factory WargearWardrobeCatalog.fromJson(Map<String, Object?> json) {
    final rules = WargearWardrobeRules.fromJson(json);
    final rawEntries =
        (json['armors'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final armors = rawEntries
        .whereType<Map>()
        .map(
          (entry) => WargearWardrobeEntry.fromJson(
            entry.cast<String, Object?>(),
            rules: rules,
          ),
        )
        .where((entry) => entry.isValid)
        .toList(growable: false);
    final schemaVersion =
        int.tryParse((json['schemaVersion'] ?? '3').toString()) ?? 3;
    return WargearWardrobeCatalog(
      schemaVersion: schemaVersion,
      rules: rules,
      armors: armors,
    );
  }

  WargearWardrobeEntry? findById(String id) {
    for (final entry in armors) {
      if (entry.id == id) return entry;
    }
    return null;
  }
}

class WargearWardrobeLoader {
  static const String _asset = 'assets/wargear_wardrobe.json';
  static WargearWardrobeCatalog? _cache;

  static Future<WargearWardrobeCatalog> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw StateError('Invalid wargear wardrobe asset.');
    }
    _cache = WargearWardrobeCatalog.fromJson(decoded.cast<String, Object?>());
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
  }
}
