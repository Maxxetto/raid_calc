import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';
import 'package:raid_calc/data/pet_simulation_resolver.dart';
import 'package:raid_calc/data/setup_models.dart';

PetResolvedEffect _effect({
  required String slotId,
  required String skillName,
  required String canonicalEffectId,
  required String canonicalName,
  required String effectCategory,
  required String runtimeSupport,
  required List<String> simulatorModes,
  Map<String, num> values = const <String, num>{},
}) {
  return PetResolvedEffect(
    sourceSlotId: slotId,
    sourceSkillName: skillName,
    values: values,
    canonicalEffectId: canonicalEffectId,
    canonicalName: canonicalName,
    effectCategory: effectCategory,
    dataSupport: values.isEmpty ? 'description_only' : 'structured_values',
    runtimeSupport: runtimeSupport,
    simulatorModes: simulatorModes,
    effectSpec: const <String, Object?>{},
  );
}

PetLoadoutSnapshot _loadout({
  PetLoadoutSlotSelection? slot1,
  PetLoadoutSlotSelection? slot2,
  required PetSkillUsageMode usageMode,
  required List<PetResolvedEffect> resolvedEffects,
}) {
  return PetLoadoutSnapshot(
    slot1: slot1,
    slot2: slot2,
    usageMode: usageMode,
    resolvedEffects: resolvedEffects,
  );
}

SetupSnapshot _setupForBossMode(
  String bossMode, {
  required FightMode legacyMode,
  required SetupPetSnapshot pet,
}) {
  return SetupSnapshot(
    bossMode: bossMode,
    bossLevel: 4,
    bossElements: const <ElementType>[ElementType.fire, ElementType.water],
    fightMode: legacyMode,
    knights: List<SetupKnightSnapshot>.generate(
      bossMode == 'epic' ? 2 : 3,
      (_) => SetupKnightSnapshot.defaults(),
      growable: false,
    ),
    pet: pet,
    modeEffects: SetupModeEffectsSnapshot.defaults(),
  );
}

void main() {
  group('Pet system matrix - generic runtime skills', () {
    final genericCases = <({
      String canonicalId,
      String skillName,
      String category,
      Map<String, num> values,
    })>[
      (
        canonicalId: 'death_blow',
        skillName: 'Death Blow',
        category: 'pet_attack_modifier',
        values: const <String, num>{},
      ),
      (
        canonicalId: 'shadow_slash',
        skillName: 'Shadow Slash',
        category: 'pet_attack_fixed',
        values: const <String, num>{'petAttack': 8750},
      ),
      (
        canonicalId: 'revenge_strike',
        skillName: 'Revenge Strike',
        category: 'pet_attack_scaling',
        values: const <String, num>{'petAttackCap': 12912},
      ),
      (
        canonicalId: 'ready_to_crit',
        skillName: 'Ready to Crit',
        category: 'crit_chance_buff',
        values: const <String, num>{'critChancePercent': 40, 'turns': 3},
      ),
      (
        canonicalId: 'soul_burn',
        skillName: 'Soul Burn',
        category: 'damage_over_time',
        values: const <String, num>{
          'flatDamage': 2334,
          'damageOverTime': 4598,
          'turns': 3,
        },
      ),
      (
        canonicalId: 'vampiric_attack',
        skillName: 'Vampiric Attack',
        category: 'lifesteal_attack',
        values: const <String, num>{'flatDamage': 5710, 'stealPercent': 10},
      ),
    ];

    for (final testCase in genericCases) {
      test('${testCase.skillName} stays in normal profile and is runtime-active',
          () {
        final effect = _effect(
          slotId: 'skill11',
          skillName: testCase.skillName,
          canonicalEffectId: testCase.canonicalId,
          canonicalName: testCase.skillName,
          effectCategory: testCase.category,
          runtimeSupport: 'normal_only',
          simulatorModes: const <String>['normal'],
          values: testCase.values,
        );
        final loadout = _loadout(
          slot1: PetLoadoutSlotSelection(
            slotId: 'skill11',
            skillName: testCase.skillName,
            canonicalEffectId: testCase.canonicalId,
            values: testCase.values,
          ),
          slot2: null,
          usageMode: PetSkillUsageMode.special1Only,
          resolvedEffects: <PetResolvedEffect>[effect],
        );

        final resolution = PetSimulationResolver.resolve(loadout);

        expect(resolution.profile.archetype, PetSimulationArchetype.normal);
        expect(resolution.profile.legacyEquivalentMode, FightMode.normal);
        expect(resolution.modeDrivingEffects, isEmpty);
        expect(resolution.runtimeActiveEffects, hasLength(1));
        expect(
          resolution.runtimeActiveEffects.single.canonicalEffectId,
          testCase.canonicalId,
        );
      });
    }
  });

  group('Pet system matrix - mode-driving skills across pet bar policies', () {
    final modeCases = <({
      String description,
      List<PetResolvedEffect> effects,
      List<PetLoadoutSlotSelection?> slots,
      PetSimulationArchetype expectedArchetype,
      FightMode? expectedLegacyMode,
      bool usesPetBar,
      bool alwaysGemmed,
      List<String> expectedModeDrivers,
    })>[
      (
        description: 'SR',
        effects: <PetResolvedEffect>[
          _effect(
            slotId: 'skill11',
            skillName: 'Special Regeneration (inf)',
            canonicalEffectId: 'special_regeneration_infinite',
            canonicalName: 'Special Regeneration',
            effectCategory: 'special_meter_buff',
            runtimeSupport: 'mode_specific',
            simulatorModes: const <String>[
              'specialRegen',
              'specialRegenPlusEw',
            ],
            values: const <String, num>{'chargeRatePercent': 104.72},
          ),
        ],
        slots: <PetLoadoutSlotSelection?>[
          const PetLoadoutSlotSelection(
            slotId: 'skill11',
            skillName: 'Special Regeneration (inf)',
            canonicalEffectId: 'special_regeneration_infinite',
            values: <String, num>{'chargeRatePercent': 104.72},
          ),
          null,
        ],
        expectedArchetype: PetSimulationArchetype.specialRegen,
        expectedLegacyMode: FightMode.specialRegen,
        usesPetBar: true,
        alwaysGemmed: false,
        expectedModeDrivers: <String>['special_regeneration_infinite'],
      ),
      (
        description: 'SR+EW',
        effects: <PetResolvedEffect>[
          _effect(
            slotId: 'skill11',
            skillName: 'Special Regeneration (inf)',
            canonicalEffectId: 'special_regeneration_infinite',
            canonicalName: 'Special Regeneration',
            effectCategory: 'special_meter_buff',
            runtimeSupport: 'mode_specific',
            simulatorModes: const <String>[
              'specialRegen',
              'specialRegenPlusEw',
            ],
            values: const <String, num>{'chargeRatePercent': 104.72},
          ),
          _effect(
            slotId: 'skill2',
            skillName: 'Elemental Weakness',
            canonicalEffectId: 'elemental_weakness',
            canonicalName: 'Elemental Weakness',
            effectCategory: 'boss_attack_debuff',
            runtimeSupport: 'mode_specific',
            simulatorModes: const <String>['specialRegenPlusEw'],
            values: const <String, num>{
              'enemyAttackReductionPercent': 65.2,
              'turns': 2,
            },
          ),
        ],
        slots: <PetLoadoutSlotSelection?>[
          const PetLoadoutSlotSelection(
            slotId: 'skill11',
            skillName: 'Special Regeneration (inf)',
            canonicalEffectId: 'special_regeneration_infinite',
            values: <String, num>{'chargeRatePercent': 104.72},
          ),
          const PetLoadoutSlotSelection(
            slotId: 'skill2',
            skillName: 'Elemental Weakness',
            canonicalEffectId: 'elemental_weakness',
            values: <String, num>{
              'enemyAttackReductionPercent': 65.2,
              'turns': 2,
            },
          ),
        ],
        expectedArchetype:
            PetSimulationArchetype.specialRegenPlusElementalWeakness,
        expectedLegacyMode: FightMode.specialRegenPlusEw,
        usesPetBar: true,
        alwaysGemmed: false,
        expectedModeDrivers: <String>[
          'special_regeneration_infinite',
          'elemental_weakness',
        ],
      ),
      (
        description: 'Shatter',
        effects: <PetResolvedEffect>[
          _effect(
            slotId: 'skill2',
            skillName: 'Shatter Shield',
            canonicalEffectId: 'shatter_shield',
            canonicalName: 'Shatter Shield',
            effectCategory: 'shield',
            runtimeSupport: 'mode_specific',
            simulatorModes: const <String>['shatterShield'],
            values: const <String, num>{
              'baseShieldHp': 178,
              'bonusShieldHp': 48,
            },
          ),
        ],
        slots: <PetLoadoutSlotSelection?>[
          null,
          const PetLoadoutSlotSelection(
            slotId: 'skill2',
            skillName: 'Shatter Shield',
            canonicalEffectId: 'shatter_shield',
            values: <String, num>{
              'baseShieldHp': 178,
              'bonusShieldHp': 48,
            },
          ),
        ],
        expectedArchetype: PetSimulationArchetype.shatterShield,
        expectedLegacyMode: FightMode.shatterShield,
        usesPetBar: true,
        alwaysGemmed: false,
        expectedModeDrivers: <String>['shatter_shield'],
      ),
      (
        description: 'DRS',
        effects: <PetResolvedEffect>[
          _effect(
            slotId: 'skill2',
            skillName: 'Durable Rock Shield',
            canonicalEffectId: 'durable_rock_shield',
            canonicalName: 'Durable Rock Shield',
            effectCategory: 'defense_buff',
            runtimeSupport: 'mode_specific',
            simulatorModes: const <String>['durableRockShield'],
            values: const <String, num>{
              'defenseBoostPercent': 51.8,
              'turns': 3,
            },
          ),
        ],
        slots: <PetLoadoutSlotSelection?>[
          null,
          const PetLoadoutSlotSelection(
            slotId: 'skill2',
            skillName: 'Durable Rock Shield',
            canonicalEffectId: 'durable_rock_shield',
            values: <String, num>{
              'defenseBoostPercent': 51.8,
              'turns': 3,
            },
          ),
        ],
        expectedArchetype: PetSimulationArchetype.durableRockShield,
        expectedLegacyMode: FightMode.durableRockShield,
        usesPetBar: true,
        alwaysGemmed: false,
        expectedModeDrivers: <String>['durable_rock_shield'],
      ),
      (
        description: 'Cyclone',
        effects: <PetResolvedEffect>[
          _effect(
            slotId: 'skill2',
            skillName: 'Cyclone Earth Boost',
            canonicalEffectId: 'cyclone_boost_earth',
            canonicalName: 'Cyclone Earth Boost',
            effectCategory: 'attack_buff',
            runtimeSupport: 'mode_specific',
            simulatorModes: const <String>['cycloneBoost'],
            values: const <String, num>{
              'attackBoostPercent': 11,
              'turns': 5,
            },
          ),
        ],
        slots: <PetLoadoutSlotSelection?>[
          null,
          const PetLoadoutSlotSelection(
            slotId: 'skill2',
            skillName: 'Cyclone Earth Boost',
            canonicalEffectId: 'cyclone_boost_earth',
            values: <String, num>{'attackBoostPercent': 11, 'turns': 5},
          ),
        ],
        expectedArchetype: PetSimulationArchetype.cycloneBoost,
        expectedLegacyMode: FightMode.cycloneBoost,
        usesPetBar: false,
        alwaysGemmed: true,
        expectedModeDrivers: <String>['cyclone_boost_earth'],
      ),
    ];

    final allPolicies = PetSkillUsageMode.values;

    Set<String> activeSlotsForUsage(PetSkillUsageMode usageMode) =>
        switch (usageMode) {
          PetSkillUsageMode.special1Only => const <String>{'skill11', 'skill12'},
          PetSkillUsageMode.special2Only => const <String>{'skill2'},
          PetSkillUsageMode.cycleSpecial1Then2 ||
          PetSkillUsageMode.special2ThenSpecial1 ||
          PetSkillUsageMode.doubleSpecial2ThenSpecial1 =>
            const <String>{'skill11', 'skill12', 'skill2'},
        };

    for (final testCase in modeCases) {
      for (final usageMode in allPolicies) {
        test('${testCase.description} keeps canonical profile for $usageMode',
            () {
          final loadout = _loadout(
            slot1: testCase.slots[0],
            slot2: testCase.slots[1],
            usageMode: usageMode,
            resolvedEffects: testCase.effects,
          );

          final resolution = PetSimulationResolver.resolve(loadout);
          final reachableDrivers = testCase.effects
              .where((effect) => activeSlotsForUsage(usageMode).contains(effect.sourceSlotId))
              .map((effect) => effect.canonicalEffectId)
              .toList(growable: false);

          final expectedArchetype = switch (testCase.description) {
            'SR' => reachableDrivers.contains('special_regeneration')
                || reachableDrivers.contains('special_regeneration_infinite')
                ? PetSimulationArchetype.specialRegen
                : PetSimulationArchetype.normal,
            'SR+EW' => (reachableDrivers.contains('special_regeneration_infinite')) &&
                    reachableDrivers.contains('elemental_weakness')
                ? PetSimulationArchetype.specialRegenPlusElementalWeakness
                : (reachableDrivers.contains('special_regeneration_infinite'))
                    ? PetSimulationArchetype.specialRegen
                    : PetSimulationArchetype.normal,
            'Shatter' => reachableDrivers.contains('shatter_shield')
                ? PetSimulationArchetype.shatterShield
                : PetSimulationArchetype.normal,
            'DRS' => reachableDrivers.contains('durable_rock_shield')
                ? PetSimulationArchetype.durableRockShield
                : PetSimulationArchetype.normal,
            'Cyclone' => reachableDrivers.contains('cyclone_boost_earth')
                ? PetSimulationArchetype.cycloneBoost
                : PetSimulationArchetype.normal,
            _ => testCase.expectedArchetype,
          };

          final expectedLegacyMode = switch (expectedArchetype) {
            PetSimulationArchetype.normal => FightMode.normal,
            PetSimulationArchetype.specialRegen => FightMode.specialRegen,
            PetSimulationArchetype.specialRegenPlusElementalWeakness =>
              FightMode.specialRegenPlusEw,
            PetSimulationArchetype.shatterShield => FightMode.shatterShield,
            PetSimulationArchetype.cycloneBoost => FightMode.cycloneBoost,
            PetSimulationArchetype.durableRockShield =>
              FightMode.durableRockShield,
            _ => testCase.expectedLegacyMode,
          };

          expect(resolution.profile.archetype, expectedArchetype);
          expect(
            resolution.profile.legacyEquivalentMode,
            expectedLegacyMode,
          );
          expect(resolution.profile.usageMode, usageMode);
          expect(
            resolution.profile.alwaysGemmed,
            expectedArchetype == PetSimulationArchetype.cycloneBoost,
          );
          expect(
            resolution.modeDrivingEffects.map((e) => e.canonicalEffectId),
            reachableDrivers,
          );
        });
      }
    }

    test('EW alone does not claim a dedicated simulation archetype', () {
      final effect = _effect(
        slotId: 'skill11',
        skillName: 'Elemental Weakness',
        canonicalEffectId: 'elemental_weakness',
        canonicalName: 'Elemental Weakness',
        effectCategory: 'boss_attack_debuff',
        runtimeSupport: 'mode_specific',
        simulatorModes: const <String>['specialRegenPlusEw'],
        values: const <String, num>{
          'enemyAttackReductionPercent': 30.8,
          'turns': 2,
        },
      );
      final loadout = _loadout(
        slot1: const PetLoadoutSlotSelection(
          slotId: 'skill11',
          skillName: 'Elemental Weakness',
          canonicalEffectId: 'elemental_weakness',
          values: <String, num>{
            'enemyAttackReductionPercent': 30.8,
            'turns': 2,
          },
        ),
        slot2: null,
        usageMode: PetSkillUsageMode.special1Only,
        resolvedEffects: <PetResolvedEffect>[effect],
      );

      final resolution = PetSimulationResolver.resolve(loadout);

      expect(resolution.profile.archetype, PetSimulationArchetype.normal);
      expect(
        resolution.modeDrivingEffects.single.canonicalEffectId,
        'elemental_weakness',
      );
    });

    test('multiple mode-driving families are rejected as unsupported hybrid',
        () {
      final shatter = _effect(
        slotId: 'skill11',
        skillName: 'Shatter Shield',
        canonicalEffectId: 'shatter_shield',
        canonicalName: 'Shatter Shield',
        effectCategory: 'shield',
        runtimeSupport: 'mode_specific',
        simulatorModes: const <String>['shatterShield'],
        values: const <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
      );
      final drs = _effect(
        slotId: 'skill2',
        skillName: 'Durable Rock Shield',
        canonicalEffectId: 'durable_rock_shield',
        canonicalName: 'Durable Rock Shield',
        effectCategory: 'defense_buff',
        runtimeSupport: 'mode_specific',
        simulatorModes: const <String>['durableRockShield'],
        values: const <String, num>{'defenseBoostPercent': 51.8, 'turns': 3},
      );
      final loadout = _loadout(
        slot1: const PetLoadoutSlotSelection(
          slotId: 'skill11',
          skillName: 'Shatter Shield',
          canonicalEffectId: 'shatter_shield',
          values: <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
        ),
        slot2: const PetLoadoutSlotSelection(
          slotId: 'skill2',
          skillName: 'Durable Rock Shield',
          canonicalEffectId: 'durable_rock_shield',
          values: <String, num>{'defenseBoostPercent': 51.8, 'turns': 3},
        ),
        usageMode: PetSkillUsageMode.cycleSpecial1Then2,
        resolvedEffects: <PetResolvedEffect>[shatter, drs],
      );

      final resolution = PetSimulationResolver.resolve(loadout);

      expect(
        resolution.profile.archetype,
        PetSimulationArchetype.unsupportedHybrid,
      );
      expect(resolution.profile.legacyEquivalentMode, isNull);
    });
  });

  group('Pet system matrix - setup parity across raid/blitz/epic', () {
    final importedPet = SetupPetSnapshot(
      atk: 6583,
      elementalAtk: 1393,
      elementalDef: 1174,
      element1: ElementType.water,
      element2: ElementType.fire,
      skillUsage: PetSkillUsageMode.special2ThenSpecial1,
      importedCompendium: const SetupPetCompendiumImportSnapshot(
        familyId: 's101sf_sr_ew',
        familyTag: 'S101SF',
        rarity: 'Shadowforged',
        tierId: 'V',
        tierName: '[S101SF] Test SR+EW',
        profileId: 'max',
        profileLabel: 'Max 99',
        useAltSkillSet: false,
        selectedSkill1: SetupPetSkillSnapshot(
          slotId: 'skill11',
          name: 'Special Regeneration (inf)',
          canonicalEffectId: 'special_regeneration_infinite',
          values: <String, num>{'chargeRatePercent': 104.72},
        ),
        selectedSkill2: SetupPetSkillSnapshot(
          slotId: 'skill2',
          name: 'Elemental Weakness',
          canonicalEffectId: 'elemental_weakness',
          values: <String, num>{
            'enemyAttackReductionPercent': 65.2,
            'turns': 2,
          },
        ),
      ),
      resolvedEffects: <PetResolvedEffect>[
        PetResolvedEffect(
          sourceSlotId: 'skill11',
          sourceSkillName: 'Special Regeneration (inf)',
          values: <String, num>{'chargeRatePercent': 104.72},
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

    for (final bossMode in <String>['raid', 'blitz', 'epic']) {
      test('$bossMode setup keeps canonical SR+EW profile', () {
        final setup = _setupForBossMode(
          bossMode,
          legacyMode: FightMode.normal,
          pet: importedPet,
        );

        expect(
          setup.petSimulationProfile.archetype,
          PetSimulationArchetype.specialRegenPlusElementalWeakness,
        );
        expect(
          setup.petSimulationProfile.legacyEquivalentMode,
          FightMode.specialRegenPlusEw,
        );
        expect(
          setup.petSimulationResolution.modeDrivingEffects
              .map((e) => e.canonicalEffectId)
              .toList(),
          <String>['special_regeneration_infinite', 'elemental_weakness'],
        );
      });
    }
  });

  group('Pet system matrix - legacy adapter coverage', () {
    final expected = <FightMode, ({
      PetSimulationArchetype archetype,
      PetSkillUsageMode usageMode,
      bool usesPetBar,
      bool alwaysGemmed,
    })>{
      FightMode.normal: (
        archetype: PetSimulationArchetype.normal,
        usageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
        usesPetBar: false,
        alwaysGemmed: false,
      ),
      FightMode.specialRegen: (
        archetype: PetSimulationArchetype.specialRegen,
        usageMode: PetSkillUsageMode.special1Only,
        usesPetBar: true,
        alwaysGemmed: false,
      ),
      FightMode.specialRegenPlusEw: (
        archetype: PetSimulationArchetype.specialRegenPlusElementalWeakness,
        usageMode: PetSkillUsageMode.special2ThenSpecial1,
        usesPetBar: true,
        alwaysGemmed: false,
      ),
      FightMode.specialRegenEw: (
        archetype: PetSimulationArchetype.oldSimulatorLegacy,
        usageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
        usesPetBar: false,
        alwaysGemmed: false,
      ),
      FightMode.shatterShield: (
        archetype: PetSimulationArchetype.shatterShield,
        usageMode: PetSkillUsageMode.special2Only,
        usesPetBar: true,
        alwaysGemmed: false,
      ),
      FightMode.cycloneBoost: (
        archetype: PetSimulationArchetype.cycloneBoost,
        usageMode: PetSkillUsageMode.special1Only,
        usesPetBar: false,
        alwaysGemmed: true,
      ),
      FightMode.durableRockShield: (
        archetype: PetSimulationArchetype.durableRockShield,
        usageMode: PetSkillUsageMode.special1Only,
        usesPetBar: true,
        alwaysGemmed: false,
      ),
    };

    for (final entry in expected.entries) {
      test('legacy ${entry.key} maps to canonical profile flags', () {
        final profile = PetLegacyModeAdapter.fromLegacyMode(
          entry.key,
          usageMode: PetSkillUsageMode.doubleSpecial2ThenSpecial1,
        );

        expect(profile.archetype, entry.value.archetype);
        expect(profile.usesPetBar, entry.value.usesPetBar);
        expect(profile.alwaysGemmed, entry.value.alwaysGemmed);
        expect(profile.usageMode, entry.value.usageMode);
        expect(profile.derivedFromLegacyMode, isTrue);
        expect(profile.legacyMode, entry.key);
      });
    }
  });
}
