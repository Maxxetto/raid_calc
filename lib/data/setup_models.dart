import 'package:flutter/foundation.dart';

import '../core/engine/skill_catalog.dart';
import '../core/element_types.dart';
import '../core/sim_types.dart';
import '../util/text_encoding_guard.dart';
import 'pet_effect_models.dart';
import 'pet_loadout_models.dart';
import 'pet_simulation_resolver.dart';

@immutable
class SetupKnightSnapshot {
  final int atk;
  final int def;
  final int hp;
  final double stun;
  final List<ElementType> elements;
  final bool active;

  const SetupKnightSnapshot({
    required this.atk,
    required this.def,
    required this.hp,
    required this.stun,
    required List<ElementType> elements,
    required this.active,
  }) : elements = elements;

  factory SetupKnightSnapshot.defaults() => const SetupKnightSnapshot(
        atk: 1000,
        def: 1000,
        hp: 1000,
        stun: 0.0,
        elements: <ElementType>[ElementType.fire, ElementType.fire],
        active: true,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'atk': atk,
        'def': def,
        'hp': hp,
        'stun': stun,
        'elements': elements.map((e) => e.id).toList(growable: false),
        'active': active,
      };

  factory SetupKnightSnapshot.fromJson(Map<String, Object?> j) {
    return SetupKnightSnapshot(
      atk: _readInt(j['atk'], fallback: 1000, min: 0, max: 2000000000),
      def: _readInt(j['def'], fallback: 1000, min: 0, max: 2000000000),
      hp: _readInt(j['hp'], fallback: 1000, min: 0, max: 2000000000),
      stun: _readDouble(j['stun'], fallback: 0.0, min: 0.0, max: 100.0),
      elements: _readElementPair(j['elements'], allowStarmetal: true),
      active: j['active'] == null ? true : j['active'] == true,
    );
  }
}

@immutable
class SetupPetSkillSnapshot {
  final String slotId;
  final String name;
  final String? canonicalEffectId;
  final Map<String, num> values;
  final Map<String, num> overrideValues;

  const SetupPetSkillSnapshot({
    required this.slotId,
    required this.name,
    this.canonicalEffectId,
    required Map<String, num> values,
    Map<String, num> overrideValues = const <String, num>{},
  })  : values = values,
        overrideValues = overrideValues;

  SetupPetSkillSnapshot copyWith({
    String? slotId,
    String? name,
    String? canonicalEffectId,
    Map<String, num>? values,
    Map<String, num>? overrideValues,
  }) {
    return SetupPetSkillSnapshot(
      slotId: slotId ?? this.slotId,
      name: name ?? this.name,
      canonicalEffectId: canonicalEffectId ?? this.canonicalEffectId,
      values: values ?? this.values,
      overrideValues: overrideValues ?? this.overrideValues,
    );
  }

  Map<String, num> get effectiveValues => Map<String, num>.unmodifiable(
        <String, num>{
          ...values,
          ...overrideValues,
        },
      );

  bool get isEffectDisabledByOverride =>
      overrideValues.values.any((value) => value.toDouble() == 0.0);

  Map<String, Object?> toJson() => <String, Object?>{
        'slotId': slotId,
        'name': name,
        if (canonicalEffectId != null && canonicalEffectId!.trim().isNotEmpty)
          'canonicalEffectId': canonicalEffectId,
        'values': values,
        if (overrideValues.isNotEmpty) 'overrideValues': overrideValues,
      };

  factory SetupPetSkillSnapshot.fromJson(Map<String, Object?> j) {
    final values = _readSkillNumericMap(j['values']);
    final overrideValues = _readSkillNumericMap(j['overrideValues']);
    return SetupPetSkillSnapshot(
      slotId: (j['slotId'] ?? '').toString().trim(),
      name: (j['name'] ?? '').toString().trim(),
      canonicalEffectId: _inferCanonicalEffectIdFromSkillName(
        (j['canonicalEffectId'] as String?)?.trim(),
        fallbackSkillName: (j['name'] ?? '').toString().trim(),
      ),
      values: Map<String, num>.unmodifiable(values),
      overrideValues: Map<String, num>.unmodifiable(overrideValues),
    );
  }
}

String petSkillDisplayNameRaw(String rawName) {
  final normalized = _normalizePetSkillNameForMatching(rawName);
  return switch (normalized) {
    'cyclone air boost' ||
    'cyclone earth boost' ||
    'cyclone boost' =>
      'Cyclone Boost',
    'special regen' || 'special regeneration' => 'Special Regeneration',
    'special regeneration (inf)' ||
    'special regeneration \u221e' =>
      'Special Regeneration \u221E',
    _ => rawName.trim(),
  };
}

String petSkillDisplayName(SetupPetSkillSnapshot skill) =>
    petSkillDisplayNameRaw(skill.name);

SetupPetSkillSnapshot pickImportedPetSkillSelection({
  required List<SetupPetSkillSnapshot> options,
  required SetupPetSkillSnapshot current,
}) {
  for (final option in options) {
    final sameCanonical =
        (option.canonicalEffectId?.trim().isNotEmpty ?? false) &&
            option.canonicalEffectId == current.canonicalEffectId;
    final sameRawName =
        option.name.trim().toLowerCase() == current.name.trim().toLowerCase();
    if (sameCanonical || sameRawName) {
      return option.copyWith(
        overrideValues: Map<String, num>.unmodifiable(current.overrideValues),
      );
    }
  }
  return current;
}

String _normalizePetSkillNameForMatching(String rawName) =>
    TextEncodingGuard.repairLikelyMojibake(rawName).trim().toLowerCase();

@immutable
class SetupPetCompendiumImportSnapshot {
  final String familyId;
  final String familyTag;
  final String rarity;
  final String tierId;
  final String tierName;
  final String profileId;
  final String profileLabel;
  final bool useAltSkillSet;
  final List<SetupPetSkillSnapshot> availableSkill1Options;
  final List<SetupPetSkillSnapshot> availableSkill2Options;
  final SetupPetSkillSnapshot selectedSkill1;
  final SetupPetSkillSnapshot selectedSkill2;

  const SetupPetCompendiumImportSnapshot({
    required this.familyId,
    required this.familyTag,
    required this.rarity,
    required this.tierId,
    required this.tierName,
    required this.profileId,
    required this.profileLabel,
    required this.useAltSkillSet,
    List<SetupPetSkillSnapshot> availableSkill1Options =
        const <SetupPetSkillSnapshot>[],
    List<SetupPetSkillSnapshot> availableSkill2Options =
        const <SetupPetSkillSnapshot>[],
    required this.selectedSkill1,
    required this.selectedSkill2,
  })  : availableSkill1Options = availableSkill1Options,
        availableSkill2Options = availableSkill2Options;

  static List<SetupPetSkillSnapshot> _dedupeSkillOptions(
    List<SetupPetSkillSnapshot> skills,
  ) {
    final seen = <String>{};
    final out = <SetupPetSkillSnapshot>[];
    for (final skill in skills) {
      final key = '${skill.slotId}|${petSkillDisplayName(skill)}|'
          '${skill.overrideValues.entries.map((e) => '${e.key}:${e.value}').join(',')}';
      if (!seen.add(key)) continue;
      out.add(skill);
    }
    return List<SetupPetSkillSnapshot>.unmodifiable(out);
  }

  SetupPetCompendiumImportSnapshot copyWith({
    bool? useAltSkillSet,
    List<SetupPetSkillSnapshot>? availableSkill1Options,
    List<SetupPetSkillSnapshot>? availableSkill2Options,
    SetupPetSkillSnapshot? selectedSkill1,
    SetupPetSkillSnapshot? selectedSkill2,
  }) {
    return SetupPetCompendiumImportSnapshot(
      familyId: familyId,
      familyTag: familyTag,
      rarity: rarity,
      tierId: tierId,
      tierName: tierName,
      profileId: profileId,
      profileLabel: profileLabel,
      useAltSkillSet: useAltSkillSet ?? this.useAltSkillSet,
      availableSkill1Options:
          availableSkill1Options ?? this.availableSkill1Options,
      availableSkill2Options:
          availableSkill2Options ?? this.availableSkill2Options,
      selectedSkill1: selectedSkill1 ?? this.selectedSkill1,
      selectedSkill2: selectedSkill2 ?? this.selectedSkill2,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'familyId': familyId,
        'familyTag': familyTag,
        'rarity': rarity,
        'tierId': tierId,
        'tierName': tierName,
        'profileId': profileId,
        'profileLabel': profileLabel,
        'useAltSkillSet': useAltSkillSet,
        'availableSkill1Options': availableSkill1Options
            .map((e) => e.toJson())
            .toList(growable: false),
        'availableSkill2Options': availableSkill2Options
            .map((e) => e.toJson())
            .toList(growable: false),
        'selectedSkill1': selectedSkill1.toJson(),
        'selectedSkill2': selectedSkill2.toJson(),
      };

  factory SetupPetCompendiumImportSnapshot.fromJson(Map<String, Object?> j) {
    final skill1Raw =
        (j['selectedSkill1'] as Map?)?.cast<String, Object?>() ?? const {};
    final skill2Raw =
        (j['selectedSkill2'] as Map?)?.cast<String, Object?>() ?? const {};
    final selectedSkill1 = SetupPetSkillSnapshot.fromJson(skill1Raw);
    final selectedSkill2 = SetupPetSkillSnapshot.fromJson(skill2Raw);
    final rawSlot1Options =
        ((j['availableSkill1Options'] as List?) ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => SetupPetSkillSnapshot.fromJson(
                  e.cast<String, Object?>(),
                ))
            .toList(growable: false);
    final rawSlot2Options =
        ((j['availableSkill2Options'] as List?) ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => SetupPetSkillSnapshot.fromJson(
                  e.cast<String, Object?>(),
                ))
            .toList(growable: false);
    return SetupPetCompendiumImportSnapshot(
      familyId: (j['familyId'] ?? '').toString().trim(),
      familyTag: (j['familyTag'] ?? '').toString().trim(),
      rarity: (j['rarity'] ?? '').toString().trim(),
      tierId: (j['tierId'] ?? '').toString().trim(),
      tierName: (j['tierName'] ?? '').toString().trim(),
      profileId: (j['profileId'] ?? '').toString().trim(),
      profileLabel: (j['profileLabel'] ?? '').toString().trim(),
      useAltSkillSet: j['useAltSkillSet'] == true,
      availableSkill1Options: _dedupeSkillOptions(
        rawSlot1Options.isEmpty
            ? <SetupPetSkillSnapshot>[selectedSkill1]
            : rawSlot1Options,
      ),
      availableSkill2Options: _dedupeSkillOptions(
        rawSlot2Options.isEmpty
            ? <SetupPetSkillSnapshot>[selectedSkill2]
            : rawSlot2Options,
      ),
      selectedSkill1: selectedSkill1,
      selectedSkill2: selectedSkill2,
    );
  }
}

@immutable
class SetupPetSnapshot {
  final int atk;
  final int elementalAtk;
  final int elementalDef;
  final ElementType element1;
  final ElementType? element2;
  final PetSkillUsageMode skillUsage;
  final SetupPetSkillSnapshot? manualSkill1;
  final SetupPetSkillSnapshot? manualSkill2;
  final SetupPetCompendiumImportSnapshot? importedCompendium;
  final List<PetResolvedEffect> resolvedEffects;

  const SetupPetSnapshot({
    required this.atk,
    this.elementalAtk = 0,
    this.elementalDef = 0,
    required this.element1,
    required this.element2,
    this.skillUsage = PetSkillUsageMode.special1Only,
    this.manualSkill1,
    this.manualSkill2,
    this.importedCompendium,
    this.resolvedEffects = const <PetResolvedEffect>[],
  });

  Map<String, Map<String, num>> get overrideValuesBySkillKey =>
      PetLoadoutSnapshot.fromSetupPet(this).overrideValuesBySkillKey;

  factory SetupPetSnapshot.defaults() => const SetupPetSnapshot(
        atk: 0,
        elementalAtk: 0,
        elementalDef: 0,
        element1: ElementType.fire,
        element2: null,
        skillUsage: PetSkillUsageMode.special1Only,
        resolvedEffects: <PetResolvedEffect>[],
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'atk': atk,
        'elementalAtk': elementalAtk,
        'elementalDef': elementalDef,
        'elements': <Object?>[element1.id, element2?.id],
        'skillUsage': skillUsage.name,
        if (manualSkill1 != null) 'manualSkill1': manualSkill1!.toJson(),
        if (manualSkill2 != null) 'manualSkill2': manualSkill2!.toJson(),
        if (importedCompendium != null)
          'importedCompendium': importedCompendium!.toJson(),
        if (resolvedEffects.isNotEmpty)
          'resolvedEffects':
              resolvedEffects.map((e) => e.toJson()).toList(growable: false),
      };

  factory SetupPetSnapshot.fromJson(Map<String, Object?> j) {
    final raw = (j['elements'] as List?)?.cast<Object?>() ?? const <Object?>[];

    ElementType parseFirst() {
      final e = ElementTypeCycle.fromId(
        raw.isNotEmpty ? raw.first?.toString() : null,
        fallback: ElementType.fire,
      );
      return e == ElementType.starmetal ? ElementType.fire : e;
    }

    ElementType? parseSecond() {
      if (raw.length < 2) return null;
      final id = raw[1]?.toString();
      if (id == null || id.trim().isEmpty) return null;
      final e = ElementTypeCycle.fromId(id, fallback: ElementType.fire);
      return e == ElementType.starmetal ? null : e;
    }

    final importedCompendium = (j['importedCompendium'] is Map)
        ? SetupPetCompendiumImportSnapshot.fromJson(
            (j['importedCompendium'] as Map).cast<String, Object?>(),
          )
        : null;
    final manualSkill1 = (j['manualSkill1'] is Map)
        ? SetupPetSkillSnapshot.fromJson(
            (j['manualSkill1'] as Map).cast<String, Object?>(),
          )
        : null;
    final manualSkill2 = (j['manualSkill2'] is Map)
        ? SetupPetSkillSnapshot.fromJson(
            (j['manualSkill2'] as Map).cast<String, Object?>(),
          )
        : null;
    final rawResolvedEffects =
        ((j['resolvedEffects'] as List?) ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => PetResolvedEffect.fromJson(e.cast<String, Object?>()))
            .toList(growable: false);
    final resolvedEffects = importedCompendium == null
        ? rawResolvedEffects
        : _materializeResolvedEffectsFromImported(
            importedCompendium,
            rawResolvedEffects,
          );

    return SetupPetSnapshot(
      atk: _readInt(j['atk'], fallback: 0, min: 0, max: 2000000000),
      elementalAtk:
          _readInt(j['elementalAtk'], fallback: 0, min: 0, max: 2000000000),
      elementalDef:
          _readInt(j['elementalDef'], fallback: 0, min: 0, max: 2000000000),
      element1: parseFirst(),
      element2: parseSecond(),
      skillUsage: PetSkillUsageMode.values.firstWhere(
        (mode) => mode.name == (j['skillUsage'] as String?)?.trim(),
        orElse: () => PetSkillUsageMode.special1Only,
      ),
      manualSkill1: manualSkill1,
      manualSkill2: manualSkill2,
      importedCompendium: importedCompendium,
      resolvedEffects: resolvedEffects,
    );
  }
}

@immutable
class SetupModeEffectsSnapshot {
  final bool cycloneUseGemsForSpecials;

  const SetupModeEffectsSnapshot({
    this.cycloneUseGemsForSpecials = true,
  });

  factory SetupModeEffectsSnapshot.defaults() => const SetupModeEffectsSnapshot(
        cycloneUseGemsForSpecials: true,
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'cycloneUseGemsForSpecials': cycloneUseGemsForSpecials,
      };

  factory SetupModeEffectsSnapshot.fromJson(Map<String, Object?> j) {
    return SetupModeEffectsSnapshot(
      cycloneUseGemsForSpecials: j['cycloneUseGemsForSpecials'] == null
          ? true
          : j['cycloneUseGemsForSpecials'] == true,
    );
  }
}

@immutable
class SetupSnapshot {
  static const int schemaVersion = 2;

  final int v;
  final String bossMode;
  final int bossLevel;
  final List<ElementType> bossElements;
  final List<SetupKnightSnapshot> knights;
  final SetupPetSnapshot pet;
  final SetupModeEffectsSnapshot modeEffects;

  const SetupSnapshot({
    this.v = schemaVersion,
    required this.bossMode,
    required this.bossLevel,
    required List<ElementType> bossElements,
    required List<SetupKnightSnapshot> knights,
    required this.pet,
    required this.modeEffects,
  })  : bossElements = bossElements,
        knights = knights;

  factory SetupSnapshot.defaults() => SetupSnapshot(
        bossMode: 'raid',
        bossLevel: 1,
        bossElements: const <ElementType>[ElementType.fire, ElementType.fire],
        knights: List<SetupKnightSnapshot>.generate(
          3,
          (_) => SetupKnightSnapshot.defaults(),
          growable: false,
        ),
        pet: SetupPetSnapshot.defaults(),
        modeEffects: SetupModeEffectsSnapshot.defaults(),
      );

  bool get isRaidOrBlitz => bossMode == 'raid' || bossMode == 'blitz';

  int get activeKnightsCount => knights.where((k) => k.active).length;

  PetLoadoutSnapshot get petLoadout => PetLoadoutSnapshot.fromSetupPet(pet);

  bool get hasExplicitPetSkillData =>
      pet.importedCompendium != null ||
      pet.resolvedEffects.isNotEmpty ||
      pet.manualSkill1 != null ||
      pet.manualSkill2 != null;

  PetLoadoutSnapshot get effectivePetLoadout => petLoadout;

  Map<String, Map<String, num>> get petSkillOverrideValuesByKey =>
      effectivePetLoadout.overrideValuesBySkillKey;

  PetSimulationResolution get petSimulationResolution =>
      PetSimulationResolver.resolve(effectivePetLoadout);

  PetSimulationProfile get petSimulationProfile {
    return petSimulationResolution.profile;
  }

  String compactSummary() {
    final modeLabel = switch (bossMode) {
      'raid' => 'Raid',
      'blitz' => 'Blitz',
      _ => bossMode,
    };
    final bossEls = '${bossElements[0].id}/${bossElements[1].id}';
    final petEls = pet.element2 == null
        ? pet.element1.id
        : '${pet.element1.id}/${pet.element2!.id}';
    final fm = petSimulationProfile.shortLabel();
    return '$modeLabel L$bossLevel | $fm | K:$activeKnightsCount/3 | '
        'Boss:$bossEls | Pet:$petEls';
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'v': v,
      'bossMode': bossMode,
      'bossLevel': bossLevel,
      'bossElements': bossElements.map((e) => e.id).toList(growable: false),
      'knights': knights
          .map((k) => <String, Object?>{
                'atk': k.atk,
                'def': k.def,
                'hp': k.hp,
                'stun': k.stun,
              })
          .toList(growable: false),
      'knightElements': knights
          .map((k) => k.elements.map((e) => e.id).toList(growable: false))
          .toList(growable: false),
      'activeKnights': knights.map((k) => k.active).toList(growable: false),
      'pet': pet.toJson(),
      'cycloneUseGemsForSpecials': modeEffects.cycloneUseGemsForSpecials,
    };
  }

  factory SetupSnapshot.fromJson(Map<String, Object?> j) {
    final bossMode = _normalizeBossMode(j['bossMode']);
    final bossLevel = _readInt(
      j['bossLevel'],
      fallback: 1,
      min: 1,
      max: bossMode == 'raid' ? 7 : 6,
    );
    final bossElements =
        _readElementPair(j['bossElements'], allowStarmetal: false);

    final statsList = (j['knights'] as List?)?.cast<Object?>() ?? const [];
    final elementList =
        (j['knightElements'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final activeList =
        (j['activeKnights'] as List?)?.map((e) => e == true).toList() ??
            const <bool>[];

    final knights = List<SetupKnightSnapshot>.generate(3, (i) {
      final stats = (i < statsList.length && statsList[i] is Map)
          ? (statsList[i] as Map).cast<String, Object?>()
          : const <String, Object?>{};
      final elements =
          (i < elementList.length) ? elementList[i] : const <Object?>[];
      return SetupKnightSnapshot.fromJson(<String, Object?>{
        'atk': stats['atk'],
        'def': stats['def'],
        'hp': stats['hp'],
        'stun': stats['stun'],
        'elements': elements,
        'active': (i < activeList.length) ? activeList[i] : true,
      });
    }, growable: false);

    final pet = (j['pet'] as Map?)?.cast<String, Object?>() ?? const {};
    final petSnapshot = SetupPetSnapshot.fromJson(pet);

    return SetupSnapshot(
      v: _readInt(j['v'], fallback: schemaVersion, min: 1, max: 9999),
      bossMode: bossMode,
      bossLevel: bossLevel,
      bossElements: bossElements,
      knights: knights,
      pet: petSnapshot,
      modeEffects: SetupModeEffectsSnapshot.fromJson(j),
    );
  }
}

String? _inferCanonicalEffectIdFromSkillName(
  String? rawCanonicalId, {
  required String fallbackSkillName,
}) {
  final normalizedForEngine = BattleSkillCatalog.normalizeCanonicalEffectId(
    rawCanonicalId,
    fallbackSkillName: fallbackSkillName,
  );
  if (normalizedForEngine == BattleSkillCatalog.cycloneId) {
    final normalizedName = _normalizePetSkillNameForMatching(fallbackSkillName);
    return switch (normalizedName) {
      'cyclone earth boost' => 'cyclone_boost_earth',
      _ => 'cyclone_boost_air',
    };
  }
  if (normalizedForEngine == BattleSkillCatalog.vampiricAttackId) {
    final normalizedName = _normalizePetSkillNameForMatching(fallbackSkillName);
    return normalizedName == 'leech strike'
        ? 'leech_strike'
        : BattleSkillCatalog.vampiricAttackId;
  }
  if (normalizedForEngine.isNotEmpty &&
      normalizedForEngine != BattleSkillCatalog.fortunesCallId) {
    return normalizedForEngine;
  }
  if (normalizedForEngine == BattleSkillCatalog.fortunesCallId) {
    return 'fortunes_call';
  }

  final canonicalId = (rawCanonicalId ?? '').trim().toLowerCase();
  if (canonicalId.isNotEmpty) return canonicalId;
  final skillName = _normalizePetSkillNameForMatching(fallbackSkillName);
  return switch (skillName) {
    'cyclone air boost' => 'cyclone_boost_air',
    'cyclone earth boost' => 'cyclone_boost_earth',
    'death blow' => 'death_blow',
    'durable rock shield' => 'durable_rock_shield',
    'element weakness' || 'elemental weakness' => 'elemental_weakness',
    "fortune's call" => 'fortunes_call',
    'ready to crit' => 'ready_to_crit',
    'revenge strike' => 'revenge_strike',
    'shadow slash' => 'shadow_slash',
    'shatter shield' => 'shatter_shield',
    'soul burn' => 'soul_burn',
    'special regen' || 'special regeneration' => 'special_regeneration',
    'special regeneration (inf)' ||
    'special regeneration \u221e' =>
      'special_regeneration_infinite',
    'vampiric attack' => 'vampiric_attack',
    'leech strike' => 'leech_strike',
    _ => null,
  };
}

List<PetResolvedEffect> _materializeResolvedEffectsFromImported(
  SetupPetCompendiumImportSnapshot imported,
  List<PetResolvedEffect> existing,
) {
  if (existing.isNotEmpty) {
    return List<PetResolvedEffect>.unmodifiable(existing);
  }

  final generated = <PetResolvedEffect>[];
  final seen = <String>{};
  final skills = <SetupPetSkillSnapshot>[
    ...imported.availableSkill1Options,
    ...imported.availableSkill2Options,
    imported.selectedSkill1,
    imported.selectedSkill2,
  ];

  for (final skill in skills) {
    final canonicalEffectId = skill.canonicalEffectId?.trim() ?? '';
    if (canonicalEffectId.isEmpty) continue;
    final key = '${skill.slotId}|${skill.name}|$canonicalEffectId';
    if (!seen.add(key)) continue;
    generated.add(
      PetResolvedEffect(
        sourceSlotId: skill.slotId,
        sourceSkillName: skill.name,
        values: Map<String, num>.unmodifiable(skill.values),
        canonicalEffectId: canonicalEffectId,
        canonicalName:
            _canonicalSkillDisplayName(canonicalEffectId, skill.name),
        effectCategory: _effectCategoryForCanonicalId(canonicalEffectId),
        dataSupport: _dataSupportForCanonicalId(canonicalEffectId),
        runtimeSupport: _runtimeSupportForCanonicalId(canonicalEffectId),
        simulatorModes: _simulatorModesForCanonicalId(canonicalEffectId),
        effectSpec: const <String, Object?>{},
      ),
    );
  }

  return List<PetResolvedEffect>.unmodifiable(generated);
}

String _canonicalSkillDisplayName(String canonicalEffectId, String fallback) {
  return switch (canonicalEffectId) {
    'cyclone_boost_air' => 'Cyclone Boost',
    'cyclone_boost_earth' => 'Cyclone Boost',
    'death_blow' => 'Death Blow',
    'durable_rock_shield' => 'Durable Rock Shield',
    'elemental_weakness' => 'Elemental Weakness',
    'fortunes_call' => "Fortune's Call",
    'ready_to_crit' => 'Ready to Crit',
    'revenge_strike' => 'Revenge Strike',
    'shadow_slash' => 'Shadow Slash',
    'shatter_shield' => 'Shatter Shield',
    'soul_burn' => 'Soul Burn',
    'special_regeneration' => 'Special Regeneration',
    'special_regeneration_infinite' => 'Special Regeneration \u221E',
    'vampiric_attack' => 'Vampiric Attack',
    'leech_strike' => 'Leech Strike',
    _ => petSkillDisplayNameRaw(fallback),
  };
}

String _effectCategoryForCanonicalId(String canonicalEffectId) {
  return switch (canonicalEffectId) {
    'cyclone_boost_air' || 'cyclone_boost_earth' => 'knight_attack_buff',
    'death_blow' => 'pet_attack_modifier',
    'durable_rock_shield' => 'knight_defense_buff',
    'elemental_weakness' => 'boss_attack_debuff',
    'fortunes_call' => 'unknown_support',
    'ready_to_crit' => 'crit_chance_buff',
    'revenge_strike' => 'pet_attack_scaling',
    'shadow_slash' => 'pet_attack_fixed',
    'shatter_shield' => 'damage_absorb_shield',
    'soul_burn' => 'damage_over_time',
    'special_regeneration' ||
    'special_regeneration_infinite' =>
      'special_meter_acceleration',
    'vampiric_attack' => 'lifesteal_attack',
    'leech_strike' => 'life_steal_attack',
    _ => 'unknown',
  };
}

String _dataSupportForCanonicalId(String canonicalEffectId) {
  return switch (canonicalEffectId) {
    'death_blow' || 'fortunes_call' => 'description_only',
    _ => 'structured_values',
  };
}

String _runtimeSupportForCanonicalId(String canonicalEffectId) {
  return switch (canonicalEffectId) {
    'death_blow' ||
    'shadow_slash' ||
    'revenge_strike' ||
    'ready_to_crit' ||
    'soul_burn' ||
    'vampiric_attack' =>
      'normal_only',
    'special_regeneration' => 'mode_specific',
    'special_regeneration_infinite' => 'mode_specific',
    'elemental_weakness' => 'mode_specific',
    'shatter_shield' => 'mode_specific',
    'durable_rock_shield' => 'mode_specific',
    'cyclone_boost_air' || 'cyclone_boost_earth' => 'mode_specific',
    _ => 'none',
  };
}

List<String> _simulatorModesForCanonicalId(String canonicalEffectId) {
  return switch (canonicalEffectId) {
    'cyclone_boost_air' || 'cyclone_boost_earth' => const <String>[
        'cycloneBoost'
      ],
    'durable_rock_shield' => const <String>['durableRockShield'],
    'elemental_weakness' => const <String>[
        'specialRegenPlusEw',
        'specialRegenEw'
      ],
    'shatter_shield' => const <String>['shatterShield'],
    'special_regeneration' => const <String>[
        'specialRegen',
        'specialRegenPlusEw'
      ],
    'special_regeneration_infinite' => const <String>[
        'specialRegen',
        'specialRegenPlusEw'
      ],
    'death_blow' ||
    'shadow_slash' ||
    'revenge_strike' ||
    'ready_to_crit' ||
    'soul_burn' ||
    'vampiric_attack' =>
      const <String>['normal'],
    _ => const <String>[],
  };
}

@immutable
class SetupSlotRecord {
  final int slot; // 1..5
  final SetupSnapshot setup;
  final String savedAtIso;
  final String? customName;

  SetupSlotRecord({
    required int slot,
    required this.setup,
    DateTime? savedAt,
    String? customName,
  })  : slot = slot.clamp(1, 5),
        savedAtIso = (savedAt ?? DateTime.now()).toIso8601String(),
        customName = _normalizeOptionalName(customName);

  Map<String, Object?> toJson() => <String, Object?>{
        'slot': slot,
        'savedAtIso': savedAtIso,
        if (customName != null) 'name': customName,
        'setup': setup.toJson(),
      };

  factory SetupSlotRecord.fromJson(Map<String, Object?> j) {
    final rawSetup = (j['setup'] as Map?)?.cast<String, Object?>() ?? const {};
    final parsedAt = DateTime.tryParse((j['savedAtIso'] as String?) ?? '');
    return SetupSlotRecord(
      slot: _readInt(j['slot'], fallback: 1, min: 1, max: 5),
      setup: SetupSnapshot.fromJson(rawSetup),
      savedAt: parsedAt,
      customName: (j['name'] ?? j['customName'])?.toString(),
    );
  }

  String compactSummary() => setup.compactSummary();
}

String? _normalizeOptionalName(String? raw) {
  final v = raw?.trim() ?? '';
  if (v.isEmpty) return null;
  return v.length <= 40 ? v : v.substring(0, 40).trimRight();
}

String _normalizeBossMode(Object? raw) {
  final s = (raw as String?)?.trim();
  return switch (s) {
    'raid' => 'raid',
    'blitz' => 'blitz',
    _ => 'raid',
  };
}

int _readInt(
  Object? raw, {
  required int fallback,
  required int min,
  required int max,
}) {
  int? v;
  if (raw is int) {
    v = raw;
  } else if (raw is num) {
    v = raw.round();
  } else if (raw is String) {
    v = int.tryParse(raw.trim().replaceAll(',', ''));
  }
  if (v == null) return fallback;
  return v.clamp(min, max);
}

Map<String, num> _readSkillNumericMap(Object? raw) {
  final rawValues =
      (raw as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
  final values = <String, num>{};
  for (final entry in rawValues.entries) {
    final current = entry.value;
    if (current is num) {
      values[entry.key] = current;
      continue;
    }
    final parsed = num.tryParse((current ?? '').toString().trim());
    if (parsed != null) values[entry.key] = parsed;
  }
  return values;
}

double _readDouble(
  Object? raw, {
  required double fallback,
  required double min,
  required double max,
}) {
  double? v;
  if (raw is num) {
    v = raw.toDouble();
  } else if (raw is String) {
    v = double.tryParse(raw.trim().replaceAll(',', '.'));
  }
  if (v == null || !v.isFinite) return fallback;
  return v.clamp(min, max);
}

List<ElementType> _readElementPair(
  Object? raw, {
  required bool allowStarmetal,
}) {
  final list = (raw as List?)?.cast<Object?>() ?? const <Object?>[];

  ElementType readAt(int i) {
    if (i >= list.length) return ElementType.fire;
    final id = list[i]?.toString();
    final e = ElementTypeCycle.fromId(id, fallback: ElementType.fire);
    if (!allowStarmetal && e == ElementType.starmetal) return ElementType.fire;
    return e;
  }

  var first = readAt(0);
  var second = readAt(1);
  if (allowStarmetal &&
      (first == ElementType.starmetal || second == ElementType.starmetal)) {
    first = ElementType.starmetal;
    second = ElementType.starmetal;
  }
  return <ElementType>[first, second];
}
