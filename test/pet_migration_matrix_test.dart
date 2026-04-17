import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';
import 'package:raid_calc/data/setup_models.dart';

Map<String, Object?> _setupJson(List<PetResolvedEffect> effects) =>
    <String, Object?>{
      'v': 2,
      'bossMode': 'raid',
      'bossLevel': 4,
      'bossElements': <String>['fire', 'water'],
      'fightMode': 'cycloneBoost',
      'knights': List<Object?>.generate(
        3,
        (_) => <String, Object?>{
          'atk': 1000,
          'def': 1000,
          'hp': 1000,
          'stun': 0,
          'elements': <String>['fire', 'fire'],
          'active': true,
        },
      ),
      'pet': <String, Object?>{
        'atk': 0,
        'elements': <String>['fire', 'water'],
        'skillUsage': 'special2Only',
        'resolvedEffects': effects.map((e) => e.toJson()).toList(),
      },
      'modeEffects': <String, Object?>{
        'cycloneUseGemsForSpecials': true,
      },
    };

PetResolvedEffect _effect(String id) => PetResolvedEffect(
      sourceSlotId: 'skill2',
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
  test('legacy fightMode payload key is ignored while pet skills drive profile',
      () {
    final setup = SetupSnapshot.fromJson(
      _setupJson(<PetResolvedEffect>[_effect('cyclone_boost')]),
    );

    expect(setup.bossElements.first, ElementType.fire);
    expect(setup.pet.resolvedEffects.single.canonicalEffectId, 'cyclone_boost');
    expect(setup.petSimulationProfile.archetype,
        PetSimulationArchetype.cycloneBoost);
  });
}
