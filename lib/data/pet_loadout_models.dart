import '../core/engine/skill_catalog.dart';
import '../core/sim_types.dart';
import 'pet_effect_models.dart';
import 'setup_models.dart';

enum PetSimulationArchetype {
  normal,
  specialRegen,
  specialRegenPlusElementalWeakness,
  shatterShield,
  cycloneBoost,
  durableRockShield,
  unsupportedHybrid,
}

class PetLoadoutSlotSelection {
  final String slotId;
  final String skillName;
  final String? canonicalEffectId;
  final Map<String, num> values;
  final Map<String, num> overrideValues;

  const PetLoadoutSlotSelection({
    required this.slotId,
    required this.skillName,
    required this.canonicalEffectId,
    required this.values,
    this.overrideValues = const <String, num>{},
  });

  Map<String, num> get effectiveValues => Map<String, num>.unmodifiable(
        <String, num>{
          ...values,
          ...overrideValues,
        },
      );

  String get normalizedCanonicalEffectId =>
      BattleSkillCatalog.normalizeCanonicalEffectId(
        canonicalEffectId,
        fallbackSkillName: skillName,
      );

  String get normalizedSkillKey => BattleSkillCatalog.skillKeyForSlot(
        sourceSlotId: slotId,
        canonicalEffectId: normalizedCanonicalEffectId,
      );

  bool get isEffectDisabled =>
      overrideValues.values.any((value) => value.toDouble() == 0.0);

  factory PetLoadoutSlotSelection.fromImportedSkill(
    SetupPetSkillSnapshot skill, {
    required List<PetResolvedEffect> resolvedEffects,
  }) {
    String? canonicalEffectId = skill.canonicalEffectId;
    for (final effect in resolvedEffects) {
      if (effect.sourceSlotId == skill.slotId &&
          effect.sourceSkillName == skill.name) {
        canonicalEffectId = effect.canonicalEffectId;
        break;
      }
    }
    return PetLoadoutSlotSelection(
      slotId: skill.slotId,
      skillName: skill.name,
      canonicalEffectId: canonicalEffectId,
      values: Map<String, num>.unmodifiable(skill.values),
      overrideValues: Map<String, num>.unmodifiable(skill.overrideValues),
    );
  }
}

class PetLoadoutSnapshot {
  final PetLoadoutSlotSelection? slot1;
  final PetLoadoutSlotSelection? slot2;
  final PetSkillUsageMode usageMode;
  final List<PetResolvedEffect> resolvedEffects;

  const PetLoadoutSnapshot({
    required this.slot1,
    required this.slot2,
    required this.usageMode,
    required this.resolvedEffects,
  });

  factory PetLoadoutSnapshot.fromSetupPet(SetupPetSnapshot pet) {
    final imported = pet.importedCompendium;
    return PetLoadoutSnapshot(
      slot1: imported != null
          ? PetLoadoutSlotSelection.fromImportedSkill(
              imported.selectedSkill1,
              resolvedEffects: pet.resolvedEffects,
            )
          : pet.manualSkill1 == null
              ? null
              : PetLoadoutSlotSelection.fromImportedSkill(
                  pet.manualSkill1!,
                  resolvedEffects: pet.resolvedEffects,
                ),
      slot2: imported != null
          ? PetLoadoutSlotSelection.fromImportedSkill(
              imported.selectedSkill2,
              resolvedEffects: pet.resolvedEffects,
            )
          : pet.manualSkill2 == null
              ? null
              : PetLoadoutSlotSelection.fromImportedSkill(
                  pet.manualSkill2!,
                  resolvedEffects: pet.resolvedEffects,
                ),
      usageMode: pet.skillUsage,
      resolvedEffects:
          List<PetResolvedEffect>.unmodifiable(pet.resolvedEffects),
    );
  }

  List<String> get canonicalEffectIds => <String>[
        for (final slot in <PetLoadoutSlotSelection?>[slot1, slot2])
          if (slot != null &&
              !slot.isEffectDisabled &&
              slot.normalizedCanonicalEffectId.isNotEmpty)
            slot.normalizedCanonicalEffectId,
      ];

  Map<String, Map<String, num>> get overrideValuesBySkillKey {
    final out = <String, Map<String, num>>{};
    for (final slot in <PetLoadoutSlotSelection?>[slot1, slot2]) {
      if (slot == null || slot.overrideValues.isEmpty) continue;
      out[slot.normalizedSkillKey] =
          Map<String, num>.unmodifiable(slot.overrideValues);
    }
    return Map<String, Map<String, num>>.unmodifiable(out);
  }
}

class PetSimulationProfile {
  final PetSimulationArchetype archetype;
  final PetSkillUsageMode usageMode;
  final List<String> canonicalEffectIds;
  final bool usesPetBar;
  final bool alwaysGemmed;
  final String summary;

  const PetSimulationProfile({
    required this.archetype,
    required this.usageMode,
    required this.canonicalEffectIds,
    required this.usesPetBar,
    required this.alwaysGemmed,
    required this.summary,
  });

  String shortLabel() => switch (archetype) {
        PetSimulationArchetype.normal => 'Normal',
        PetSimulationArchetype.specialRegen => 'SR',
        PetSimulationArchetype.specialRegenPlusElementalWeakness => 'SR+EW',
        PetSimulationArchetype.shatterShield => 'SS',
        PetSimulationArchetype.cycloneBoost => 'CB',
        PetSimulationArchetype.durableRockShield => 'DRS',
        PetSimulationArchetype.unsupportedHybrid => 'Hybrid',
      };
}

/// Derives a [PetSimulationProfile] from a loaded [PetLoadoutSnapshot].
/// Skill-based detection only; no legacy mode synthesis.
class PetSimulationDeriver {
  static const String _specialRegenId = 'special_regeneration';
  static const String _specialRegenInfiniteId = 'special_regeneration_infinite';
  static const String _elementalWeaknessId = 'elemental_weakness';
  static const String _shatterShieldId = 'shatter_shield';
  static const String _durableRockShieldId = 'durable_rock_shield';
  static const String _cycloneId = BattleSkillCatalog.cycloneId;

  static const Set<String> _modeDrivingIds = <String>{
    _specialRegenInfiniteId,
    _shatterShieldId,
    _durableRockShieldId,
    _cycloneId,
  };

  static PetSimulationProfile deriveFromLoadout(PetLoadoutSnapshot loadout) {
    final activeSlots = switch (loadout.usageMode) {
      PetSkillUsageMode.special1Only => const <String>{'skill11', 'skill12'},
      PetSkillUsageMode.special2Only => const <String>{'skill2'},
      PetSkillUsageMode.cycleSpecial1Then2 ||
      PetSkillUsageMode.special2ThenSpecial1 ||
      PetSkillUsageMode.doubleSpecial2ThenSpecial1 =>
        const <String>{'skill11', 'skill12', 'skill2'},
    };
    final ids = <String>{
      for (final slot in <PetLoadoutSlotSelection?>[
        loadout.slot1,
        loadout.slot2
      ])
        if (slot != null &&
            !slot.isEffectDisabled &&
            activeSlots.contains(slot.slotId) &&
            slot.normalizedCanonicalEffectId.isNotEmpty)
          slot.normalizedCanonicalEffectId,
      for (final effect in loadout.resolvedEffects)
        if (activeSlots.contains(effect.sourceSlotId))
          BattleSkillCatalog.normalizeCanonicalEffectId(
            effect.canonicalEffectId,
            fallbackSkillName: effect.sourceSkillName,
          ),
    };
    final modeIds = ids.intersection(_modeDrivingIds);
    final hasSrRegular = ids.contains(_specialRegenId);
    final hasSrInfinite = ids.contains(_specialRegenInfiniteId);
    final hasEw = ids.contains(_elementalWeaknessId);
    final hasShatter = ids.contains(_shatterShieldId);
    final hasDrs = ids.contains(_durableRockShieldId);
    final hasCyclone = ids.contains(_cycloneId);

    final allowedSrEw = hasSrInfinite &&
        hasEw &&
        modeIds.difference(<String>{
          _specialRegenInfiniteId,
        }).isEmpty;

    if (allowedSrEw) {
      return PetSimulationProfile(
        archetype: PetSimulationArchetype.specialRegenPlusElementalWeakness,
        usageMode: loadout.usageMode,
        canonicalEffectIds:
            List<String>.unmodifiable(loadout.canonicalEffectIds),
        usesPetBar: true,
        alwaysGemmed: false,
        summary: 'SR + EW derived from pet skills.',
      );
    }

    final singleModeFamilies = <PetSimulationArchetype>[];
    if (hasSrInfinite) {
      singleModeFamilies.add(PetSimulationArchetype.specialRegen);
    }
    if (hasShatter)
      singleModeFamilies.add(PetSimulationArchetype.shatterShield);
    if (hasDrs) {
      singleModeFamilies.add(PetSimulationArchetype.durableRockShield);
    }
    if (hasCyclone) singleModeFamilies.add(PetSimulationArchetype.cycloneBoost);

    if (singleModeFamilies.length > 1) {
      return PetSimulationProfile(
        archetype: PetSimulationArchetype.unsupportedHybrid,
        usageMode: loadout.usageMode,
        canonicalEffectIds:
            List<String>.unmodifiable(loadout.canonicalEffectIds),
        usesPetBar: hasSrInfinite || hasShatter || hasDrs || hasSrRegular,
        alwaysGemmed: hasCyclone,
        summary: 'Multiple mode-driving pet skill families are selected.',
      );
    }

    if (singleModeFamilies.length == 1) {
      final archetype = singleModeFamilies.single;
      return PetSimulationProfile(
        archetype: archetype,
        usageMode: loadout.usageMode,
        canonicalEffectIds:
            List<String>.unmodifiable(loadout.canonicalEffectIds),
        usesPetBar: archetype == PetSimulationArchetype.specialRegen ||
            archetype == PetSimulationArchetype.shatterShield ||
            archetype == PetSimulationArchetype.durableRockShield,
        alwaysGemmed: archetype == PetSimulationArchetype.cycloneBoost,
        summary: '${_labelForArchetype(archetype)} derived from pet skills.',
      );
    }

    return PetSimulationProfile(
      archetype: PetSimulationArchetype.normal,
      usageMode: loadout.usageMode,
      canonicalEffectIds: List<String>.unmodifiable(loadout.canonicalEffectIds),
      usesPetBar: hasSrRegular || hasEw || ids.isNotEmpty,
      alwaysGemmed: false,
      summary: 'Skill-driven standard simulation.',
    );
  }

  static String _labelForArchetype(PetSimulationArchetype archetype) =>
      switch (archetype) {
        PetSimulationArchetype.normal => 'Normal',
        PetSimulationArchetype.specialRegen => 'Special Regeneration',
        PetSimulationArchetype.specialRegenPlusElementalWeakness => 'SR + EW',
        PetSimulationArchetype.shatterShield => 'Shatter Shield',
        PetSimulationArchetype.cycloneBoost => 'Cyclone Boost',
        PetSimulationArchetype.durableRockShield => 'Durable Rock Shield',
        PetSimulationArchetype.unsupportedHybrid => 'Unsupported hybrid',
      };
}
