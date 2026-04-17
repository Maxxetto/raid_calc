import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';
import 'package:raid_calc/data/pet_simulation_resolver.dart';

PetResolvedEffect effect(String id, String slot) => PetResolvedEffect(
      sourceSlotId: slot,
      sourceSkillName: id,
      values: const <String, num>{},
      canonicalEffectId: id,
      canonicalName: id,
      effectCategory: 'test',
      dataSupport: 'test',
      runtimeSupport: 'test',
      simulatorModes: const <String>[],
      effectSpec: const <String, Object?>{},
    );

void main() {
  group('Pet system matrix - skill-driven profiles', () {
    test('derives Cyclone from selected resolved skill', () {
      final resolution = PetSimulationResolver.resolve(
        PetLoadoutSnapshot(
          slot1: null,
          slot2: null,
          usageMode: PetSkillUsageMode.special2Only,
          resolvedEffects: <PetResolvedEffect>[
            effect('cyclone_boost', 'skill2'),
          ],
        ),
      );

      expect(resolution.profile.archetype, PetSimulationArchetype.cycloneBoost);
      expect(resolution.profile.alwaysGemmed, isTrue);
    });

    test('derives SR + EW from reachable skill families', () {
      final resolution = PetSimulationResolver.resolve(
        PetLoadoutSnapshot(
          slot1: null,
          slot2: null,
          usageMode: PetSkillUsageMode.special2ThenSpecial1,
          resolvedEffects: <PetResolvedEffect>[
            effect('special_regeneration_infinite', 'skill11'),
            effect('elemental_weakness', 'skill2'),
          ],
        ),
      );

      expect(
        resolution.profile.archetype,
        PetSimulationArchetype.specialRegenPlusElementalWeakness,
      );
      expect(resolution.profile.usesPetBar, isTrue);
    });

    test('marks conflicting skill families as unsupported hybrid', () {
      final resolution = PetSimulationResolver.resolve(
        PetLoadoutSnapshot(
          slot1: null,
          slot2: null,
          usageMode: PetSkillUsageMode.cycleSpecial1Then2,
          resolvedEffects: <PetResolvedEffect>[
            effect('shatter_shield', 'skill11'),
            effect('durable_rock_shield', 'skill2'),
          ],
        ),
      );

      expect(
        resolution.profile.archetype,
        PetSimulationArchetype.unsupportedHybrid,
      );
    });
  });
}
