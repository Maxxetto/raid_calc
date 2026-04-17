import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/engine/legacy_mode_adapter.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';
import 'package:raid_calc/data/setup_models.dart';

void main() {
  group('Phase 6 legacy mode adapter', () {
    test('synthesizes SR + EW into a skill-based pet configuration', () {
      final synthetic = LegacyModeAdapter.synthesize(
        mode: FightMode.specialRegenPlusEw,
        requestedUsageMode: PetSkillUsageMode.special1Only,
        cycloneUseGemsForSpecials: true,
        cycloneBoostPercent: 71.0,
        shatterBaseHp: 100,
        shatterBonusHp: 20,
        drsDefenseBoost: 0.5,
        ewWeaknessEffect: 0.65,
      );

      expect(synthetic.usageMode, PetSkillUsageMode.special2ThenSpecial1);
      expect(
        synthetic.resolvedEffects.map((e) => e.canonicalEffectId).toList(),
        <String>['elemental_weakness', 'special_regeneration_infinite'],
      );
      expect(synthetic.resolvedEffects[0].sourceSlotId, 'skill11');
      expect(synthetic.resolvedEffects[1].sourceSlotId, 'skill2');
    });

    test('legacy setup without explicit pet data resolves to synthetic shatter loadout', () {
      final setup = SetupSnapshot(
        bossMode: 'raid',
        bossLevel: 2,
        bossElements: const <ElementType>[ElementType.fire, ElementType.water],
        fightMode: FightMode.shatterShield,
        knights: List<SetupKnightSnapshot>.generate(
          3,
          (_) => SetupKnightSnapshot.defaults(),
          growable: false,
        ),
        pet: SetupPetSnapshot.defaults(),
        modeEffects: const SetupModeEffectsSnapshot(
          shatterBaseHp: 180,
          shatterBonusHp: 45,
          cycloneBoostPercent: 71.0,
          drsDefenseBoost: 0.5,
          ewWeaknessEffect: 0.65,
        ),
      );

      expect(setup.hasExplicitPetSkillData, isFalse);
      expect(setup.effectivePetLoadout.slot2?.canonicalEffectId, 'shatter_shield');
      expect(setup.effectivePetLoadout.usageMode, PetSkillUsageMode.special2Only);
      expect(
        setup.petSimulationResolution.modeDrivingEffects
            .map((e) => e.canonicalEffectId)
            .toList(),
        <String>['shatter_shield'],
      );
      expect(setup.petSimulationProfile.legacyEquivalentMode, FightMode.shatterShield);
    });

    test('legacy setup without pet data resolves cyclone as synthetic always-gem profile', () {
      final setup = SetupSnapshot(
        bossMode: 'raid',
        bossLevel: 3,
        bossElements: const <ElementType>[ElementType.air, ElementType.water],
        fightMode: FightMode.cycloneBoost,
        knights: List<SetupKnightSnapshot>.generate(
          3,
          (_) => SetupKnightSnapshot.defaults(),
          growable: false,
        ),
        pet: SetupPetSnapshot.defaults(),
        modeEffects: const SetupModeEffectsSnapshot(
          cycloneUseGemsForSpecials: false,
          cycloneBoostPercent: 88.0,
          shatterBaseHp: 100,
          shatterBonusHp: 20,
          drsDefenseBoost: 0.5,
          ewWeaknessEffect: 0.65,
        ),
      );

      expect(setup.effectivePetLoadout.slot1?.canonicalEffectId, 'cyclone_boost_earth');
      expect(
        setup.effectivePetLoadout.slot1?.values['attackBoostPercent'],
        88.0,
      );
      expect(setup.petSimulationProfile.archetype, PetSimulationArchetype.cycloneBoost);
      expect(setup.petSimulationProfile.alwaysGemmed, isFalse);
    });

    test('old simulator legacy mode stays profile-only and does not synthesize effects', () {
      final setup = SetupSnapshot(
        bossMode: 'raid',
        bossLevel: 1,
        bossElements: const <ElementType>[ElementType.fire, ElementType.fire],
        fightMode: FightMode.specialRegenEw,
        knights: List<SetupKnightSnapshot>.generate(
          3,
          (_) => SetupKnightSnapshot.defaults(),
          growable: false,
        ),
        pet: SetupPetSnapshot.defaults(),
        modeEffects: SetupModeEffectsSnapshot.defaults(),
      );

      expect(setup.effectivePetLoadout.resolvedEffects, isEmpty);
      expect(setup.petSimulationProfile.archetype, PetSimulationArchetype.oldSimulatorLegacy);
    });
  });
}
