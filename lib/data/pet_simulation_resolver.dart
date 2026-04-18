import '../core/engine/skill_catalog.dart';
import '../core/sim_types.dart';
import 'pet_effect_models.dart';
import 'pet_loadout_models.dart';

class PetSimulationResolution {
  final PetLoadoutSnapshot loadout;
  final PetSimulationProfile profile;
  final PetResolvedEffect? slot1Effect;
  final PetResolvedEffect? slot2Effect;
  final List<PetResolvedEffect> orderedEffects;
  final List<PetResolvedEffect> modeDrivingEffects;
  final List<PetResolvedEffect> runtimeActiveEffects;

  const PetSimulationResolution({
    required this.loadout,
    required this.profile,
    required this.slot1Effect,
    required this.slot2Effect,
    required this.orderedEffects,
    required this.modeDrivingEffects,
    required this.runtimeActiveEffects,
  });
}

class PetSimulationResolver {
  static const Set<String> _modeDrivingEffectIds = <String>{
    BattleSkillCatalog.specialRegenId,
    BattleSkillCatalog.specialRegenInfiniteId,
    BattleSkillCatalog.elementalWeaknessId,
    BattleSkillCatalog.shatterShieldId,
    BattleSkillCatalog.durableRockShieldId,
    BattleSkillCatalog.cycloneId,
  };

  static PetSimulationResolution resolve(PetLoadoutSnapshot loadout) {
    final profile = PetSimulationDeriver.deriveFromLoadout(loadout);
    final slot1Effect =
        _matchSelectedEffect(loadout.slot1, loadout.resolvedEffects);
    final slot2Effect =
        _matchSelectedEffect(loadout.slot2, loadout.resolvedEffects);
    final orderedEffects = <PetResolvedEffect>[
      if (slot1Effect != null) slot1Effect,
      if (slot2Effect != null) slot2Effect,
    ];
    final activeSlots = _activeSlotIdsForUsage(loadout.usageMode);
    final modeDrivingEffects = orderedEffects
        .where((effect) =>
            activeSlots.contains(effect.sourceSlotId) &&
            _modeDrivingEffectIds.contains(
              BattleSkillCatalog.normalizeCanonicalEffectId(
                effect.canonicalEffectId,
                fallbackSkillName: effect.sourceSkillName,
              ),
            ))
        .toList(growable: false);
    final runtimeActiveEffects = orderedEffects
        .where((effect) =>
            activeSlots.contains(effect.sourceSlotId) &&
            effect.runtimeSupport.trim().toLowerCase() != 'none')
        .toList(growable: false);

    return PetSimulationResolution(
      loadout: loadout,
      profile: profile,
      slot1Effect: slot1Effect,
      slot2Effect: slot2Effect,
      orderedEffects: List<PetResolvedEffect>.unmodifiable(orderedEffects),
      modeDrivingEffects:
          List<PetResolvedEffect>.unmodifiable(modeDrivingEffects),
      runtimeActiveEffects:
          List<PetResolvedEffect>.unmodifiable(runtimeActiveEffects),
    );
  }

  static PetSimulationProfile deriveProfileFromResolvedEffects({
    required List<PetResolvedEffect> resolvedEffects,
    required PetSkillUsageMode usageMode,
  }) {
    final activeSlots = _activeSlotIdsForUsage(usageMode);
    final activeEffects = resolvedEffects
        .where((effect) => activeSlots.contains(effect.sourceSlotId))
        .toList(growable: false);
    final slot1 = activeEffects
        .where((effect) =>
            effect.sourceSlotId == 'skill11' ||
            effect.sourceSlotId == 'skill12')
        .cast<PetResolvedEffect?>()
        .firstWhere((_) => true, orElse: () => null);
    final slot2 = activeEffects
        .where((effect) => effect.sourceSlotId == 'skill2')
        .cast<PetResolvedEffect?>()
        .firstWhere((_) => true, orElse: () => null);
    final loadout = PetLoadoutSnapshot(
      slot1: slot1 == null
          ? null
          : PetLoadoutSlotSelection(
              slotId: slot1.sourceSlotId,
              skillName: slot1.sourceSkillName,
              canonicalEffectId: slot1.canonicalEffectId,
              values: slot1.values,
            ),
      slot2: slot2 == null
          ? null
          : PetLoadoutSlotSelection(
              slotId: slot2.sourceSlotId,
              skillName: slot2.sourceSkillName,
              canonicalEffectId: slot2.canonicalEffectId,
              values: slot2.values,
            ),
      usageMode: usageMode,
      resolvedEffects: activeEffects,
    );
    return PetSimulationDeriver.deriveFromLoadout(loadout);
  }

  static Set<String> _activeSlotIdsForUsage(PetSkillUsageMode usageMode) =>
      switch (usageMode) {
        PetSkillUsageMode.special1Only => const <String>{'skill11', 'skill12'},
        PetSkillUsageMode.special2Only => const <String>{'skill2'},
        PetSkillUsageMode.cycleSpecial1Then2 ||
        PetSkillUsageMode.special2ThenSpecial1 ||
        PetSkillUsageMode.doubleSpecial2ThenSpecial1 =>
          const <String>{'skill11', 'skill12', 'skill2'},
      };

  static PetResolvedEffect? _matchSelectedEffect(
    PetLoadoutSlotSelection? slot,
    List<PetResolvedEffect> resolvedEffects,
  ) {
    if (slot == null) return null;
    if (slot.isEffectDisabled) return null;
    for (final effect in resolvedEffects) {
      if (effect.sourceSlotId != slot.slotId) continue;
      if (effect.sourceSkillName != slot.skillName) continue;
      if (slot.canonicalEffectId != null &&
          slot.canonicalEffectId!.trim().isNotEmpty &&
          BattleSkillCatalog.normalizeCanonicalEffectId(
                effect.canonicalEffectId,
                fallbackSkillName: effect.sourceSkillName,
              ) !=
              BattleSkillCatalog.normalizeCanonicalEffectId(
                slot.canonicalEffectId,
                fallbackSkillName: slot.skillName,
              )) {
        continue;
      }
      return effect;
    }
    return null;
  }
}
