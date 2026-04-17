import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';
import 'package:raid_calc/data/setup_models.dart';

void main() {
  group('PetLoadoutSnapshot', () {
    test('extracts slot selections and canonical effects from imported pet', () {
      const pet = SetupPetSnapshot(
        atk: 6583,
        element1: ElementType.water,
        element2: ElementType.fire,
        skillUsage: PetSkillUsageMode.cycleSpecial1Then2,
        importedCompendium: SetupPetCompendiumImportSnapshot(
          familyId: 's101sf_ignitide',
          familyTag: 'S101SF',
          rarity: 'Shadowforged',
          tierId: 'V',
          tierName: '[S101SF] Ignitide',
          profileId: 'max',
          profileLabel: 'Max 99',
          useAltSkillSet: false,
          selectedSkill1: SetupPetSkillSnapshot(
            slotId: 'skill11',
            name: 'Revenge Strike',
            values: <String, num>{'petAttackCap': 12912},
          ),
          selectedSkill2: SetupPetSkillSnapshot(
            slotId: 'skill2',
            name: 'Shatter Shield',
            values: <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
          ),
        ),
        resolvedEffects: <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Revenge Strike',
            values: <String, num>{'petAttackCap': 12912},
            canonicalEffectId: 'revenge_strike',
            canonicalName: 'Revenge Strike',
            effectCategory: 'pet_attack_scaling',
            dataSupport: 'structured_values',
            runtimeSupport: 'none',
            simulatorModes: <String>[],
            effectSpec: <String, Object?>{},
          ),
          PetResolvedEffect(
            sourceSlotId: 'skill2',
            sourceSkillName: 'Shatter Shield',
            values: <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
            canonicalEffectId: 'shatter_shield',
            canonicalName: 'Shatter Shield',
            effectCategory: 'damage_absorb_shield',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['shatterShield'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final loadout = PetLoadoutSnapshot.fromSetupPet(pet);

      expect(loadout.usageMode, PetSkillUsageMode.cycleSpecial1Then2);
      expect(loadout.slot1?.skillName, 'Revenge Strike');
      expect(loadout.slot1?.canonicalEffectId, 'revenge_strike');
      expect(loadout.slot2?.skillName, 'Shatter Shield');
      expect(loadout.slot2?.canonicalEffectId, 'shatter_shield');
      expect(loadout.canonicalEffectIds,
          containsAll(<String>['revenge_strike', 'shatter_shield']));
    });
  });

  group('PetLegacyModeAdapter', () {
    test('derives SR + EW from imported effect combination', () {
      final loadout = PetLoadoutSnapshot(
        slot1: null,
        slot2: null,
        usageMode: PetSkillUsageMode.special2ThenSpecial1,
        resolvedEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Special Regeneration (inf)',
            values: <String, num>{'meterChargePercent': 104.72},
            canonicalEffectId: 'special_regeneration_infinite',
            canonicalName: 'Special Regeneration',
            effectCategory: 'special_meter_acceleration',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegen', 'specialRegenPlusEw'],
            effectSpec: <String, Object?>{},
          ),
          PetResolvedEffect(
            sourceSlotId: 'skill2',
            sourceSkillName: 'Elemental Weakness',
            values: <String, num>{
              'enemyAttackReductionPercent': 65.2,
              'turns': 2,
            },
            canonicalEffectId: 'elemental_weakness',
            canonicalName: 'Elemental Weakness',
            effectCategory: 'boss_attack_debuff',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegenPlusEw'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final profile = PetLegacyModeAdapter.deriveFromLoadout(loadout);

      expect(profile.archetype,
          PetSimulationArchetype.specialRegenPlusElementalWeakness);
      expect(profile.usesPetBar, isTrue);
      expect(profile.alwaysGemmed, isFalse);
      expect(profile.legacyEquivalentMode, FightMode.specialRegenPlusEw);
    });

    test('keeps regular SR + EW on generic skill-driven normal path', () {
      final loadout = PetLoadoutSnapshot(
        slot1: null,
        slot2: null,
        usageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
        resolvedEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Elemental Weakness',
            values: <String, num>{
              'enemyAttackReductionPercent': 61.6,
              'turns': 2,
            },
            canonicalEffectId: 'elemental_weakness',
            canonicalName: 'Elemental Weakness',
            effectCategory: 'boss_attack_debuff',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegenPlusEw'],
            effectSpec: <String, Object?>{},
          ),
          PetResolvedEffect(
            sourceSlotId: 'skill2',
            sourceSkillName: 'Special Regeneration',
            values: <String, num>{'meterChargePercent': 101.5},
            canonicalEffectId: 'special_regeneration',
            canonicalName: 'Special Regeneration',
            effectCategory: 'special_meter_acceleration',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegen', 'specialRegenPlusEw'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final profile = PetLegacyModeAdapter.deriveFromLoadout(loadout);

      expect(profile.archetype, PetSimulationArchetype.normal);
      expect(profile.legacyEquivalentMode, FightMode.normal);
      expect(profile.usesPetBar, isTrue);
    });

    test('derives unsupported hybrid when multiple mode-driving families clash',
        () {
      final loadout = PetLoadoutSnapshot(
        slot1: null,
        slot2: null,
        usageMode: PetSkillUsageMode.cycleSpecial1Then2,
        resolvedEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Shatter Shield',
            values: <String, num>{},
            canonicalEffectId: 'shatter_shield',
            canonicalName: 'Shatter Shield',
            effectCategory: 'damage_absorb_shield',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['shatterShield'],
            effectSpec: <String, Object?>{},
          ),
          PetResolvedEffect(
            sourceSlotId: 'skill2',
            sourceSkillName: 'Durable Rock Shield',
            values: <String, num>{},
            canonicalEffectId: 'durable_rock_shield',
            canonicalName: 'Durable Rock Shield',
            effectCategory: 'knight_defense_buff',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['durableRockShield'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final profile = PetLegacyModeAdapter.deriveFromLoadout(loadout);

      expect(profile.archetype, PetSimulationArchetype.unsupportedHybrid);
      expect(profile.legacyEquivalentMode, isNull);
    });

    test('maps legacy cyclone mode into canonical profile', () {
      final profile = PetLegacyModeAdapter.fromLegacyMode(
        FightMode.cycloneBoost,
        usageMode: PetSkillUsageMode.special2Only,
        canonicalEffectIds: const <String>['cyclone_boost_air'],
      );

      expect(profile.archetype, PetSimulationArchetype.cycloneBoost);
      expect(profile.alwaysGemmed, isTrue);
      expect(profile.usesPetBar, isFalse);
      expect(profile.derivedFromLegacyMode, isTrue);
      expect(profile.legacyEquivalentMode, FightMode.cycloneBoost);
    });

    test('usage mode filters which skill family can drive the simulation', () {
      const loadout = PetLoadoutSnapshot(
        slot1: PetLoadoutSlotSelection(
          slotId: 'skill11',
          skillName: 'Cyclone Boost',
          canonicalEffectId: 'cyclone_boost_earth',
          values: <String, num>{},
        ),
        slot2: PetLoadoutSlotSelection(
          slotId: 'skill2',
          skillName: 'Special Regeneration ∞',
          canonicalEffectId: 'special_regeneration_infinite',
          values: <String, num>{'meterChargePercent': 104.72},
        ),
        usageMode: PetSkillUsageMode.special1Only,
        resolvedEffects: <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Cyclone Boost',
            values: <String, num>{},
            canonicalEffectId: 'cyclone_boost_earth',
            canonicalName: 'Cyclone Boost',
            effectCategory: 'knight_attack_buff',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['cycloneBoost'],
            effectSpec: <String, Object?>{},
          ),
          PetResolvedEffect(
            sourceSlotId: 'skill2',
            sourceSkillName: 'Special Regeneration ∞',
            values: <String, num>{'meterChargePercent': 104.72},
            canonicalEffectId: 'special_regeneration_infinite',
            canonicalName: 'Special Regeneration ∞',
            effectCategory: 'special_meter_buff',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['specialRegen', 'specialRegenPlusEw'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final profile = PetLegacyModeAdapter.deriveFromLoadout(loadout);

      expect(profile.archetype, PetSimulationArchetype.cycloneBoost);
      expect(profile.legacyEquivalentMode, FightMode.cycloneBoost);
    });
  });
}
