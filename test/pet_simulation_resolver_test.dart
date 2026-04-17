import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';
import 'package:raid_calc/data/pet_simulation_resolver.dart';

void main() {
  group('PetSimulationResolver', () {
    test('resolves slot effects in stable slot order', () {
      const loadout = PetLoadoutSnapshot(
        slot1: PetLoadoutSlotSelection(
          slotId: 'skill11',
          skillName: 'Revenge Strike',
          canonicalEffectId: 'revenge_strike',
          values: <String, num>{'petAttackCap': 12912},
        ),
        slot2: PetLoadoutSlotSelection(
          slotId: 'skill2',
          skillName: 'Shatter Shield',
          canonicalEffectId: 'shatter_shield',
          values: <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
        ),
        usageMode: PetSkillUsageMode.cycleSpecial1Then2,
        resolvedEffects: <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill2',
            sourceSkillName: 'Shatter Shield',
            values: <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
            canonicalEffectId: 'shatter_shield',
            canonicalName: 'Shatter Shield',
            effectCategory: 'shield',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['shatterShield'],
            effectSpec: <String, Object?>{},
          ),
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Revenge Strike',
            values: <String, num>{'petAttackCap': 12912},
            canonicalEffectId: 'revenge_strike',
            canonicalName: 'Revenge Strike',
            effectCategory: 'pet_attack_scaling',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final resolution = PetSimulationResolver.resolve(
        loadout,
      );

      expect(resolution.slot1Effect?.canonicalEffectId, 'revenge_strike');
      expect(resolution.slot2Effect?.canonicalEffectId, 'shatter_shield');
      expect(
        resolution.orderedEffects.map((e) => e.canonicalEffectId).toList(),
        <String>['revenge_strike', 'shatter_shield'],
      );
    });

    test('tracks mode-driving and runtime-active effects separately', () {
      const loadout = PetLoadoutSnapshot(
        slot1: PetLoadoutSlotSelection(
          slotId: 'skill11',
          skillName: 'Special Regeneration (inf)',
          canonicalEffectId: 'special_regeneration_infinite',
          values: <String, num>{'meterChargePercent': 104.72},
        ),
        slot2: PetLoadoutSlotSelection(
          slotId: 'skill2',
          skillName: 'Elemental Weakness',
          canonicalEffectId: 'elemental_weakness',
          values: <String, num>{
            'enemyAttackReductionPercent': 65.2,
            'turns': 2,
          },
        ),
        usageMode: PetSkillUsageMode.special2ThenSpecial1,
        resolvedEffects: <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Special Regeneration (inf)',
            values: <String, num>{'meterChargePercent': 104.72},
            canonicalEffectId: 'special_regeneration_infinite',
            canonicalName: 'Special Regeneration',
            effectCategory: 'special_meter_buff',
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

      final resolution = PetSimulationResolver.resolve(loadout);

      expect(
        resolution.profile.archetype,
        PetSimulationArchetype.specialRegenPlusElementalWeakness,
      );
      expect(
        resolution.modeDrivingEffects.map((e) => e.canonicalEffectId).toList(),
        <String>['special_regeneration_infinite', 'elemental_weakness'],
      );
      expect(
        resolution.runtimeActiveEffects
            .map((e) => e.canonicalEffectId)
            .toList(),
        <String>['special_regeneration_infinite', 'elemental_weakness'],
      );
    });

    test('usage mode limits active mode-driving effects to reachable slot', () {
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

      final resolution = PetSimulationResolver.resolve(loadout);

      expect(resolution.profile.archetype, PetSimulationArchetype.cycloneBoost);
      expect(
        resolution.modeDrivingEffects.map((e) => e.canonicalEffectId).toList(),
        <String>['cyclone_boost_earth'],
      );
      expect(
        resolution.runtimeActiveEffects
            .map((e) => e.canonicalEffectId)
            .toList(),
        <String>['cyclone_boost_earth'],
      );
    });
  });
}
