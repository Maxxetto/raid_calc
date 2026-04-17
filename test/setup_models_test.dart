import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';
import 'package:raid_calc/data/setup_models.dart';

void main() {
  group('pet skill display names', () {
    test('keep normal and infinite Special Regeneration distinct', () {
      expect(
        petSkillDisplayNameRaw('Special Regeneration'),
        'Special Regeneration',
      );
      expect(
        petSkillDisplayNameRaw('Special Regeneration (inf)'),
        'Special Regeneration \u221E',
      );
      expect(
        petSkillDisplayNameRaw('Special Regeneration \u221E'),
        'Special Regeneration \u221E',
      );
    });

    test('pickImportedPetSkillSelection preserves custom selection and overrides', () {
      const current = SetupPetSkillSnapshot(
        slotId: 'skill11',
        name: 'Death Blow',
        canonicalEffectId: 'death_blow',
        values: <String, num>{'bonusFlatDamage': 12450},
        overrideValues: <String, num>{'bonusFlatDamage': 14000},
      );

      final options = <SetupPetSkillSnapshot>[
        const SetupPetSkillSnapshot(
          slotId: 'skill11',
          name: 'Revenge Strike',
          canonicalEffectId: 'revenge_strike',
          values: <String, num>{'petAttackCap': 12912},
        ),
        const SetupPetSkillSnapshot(
          slotId: 'skill12',
          name: 'Ready to Crit',
          canonicalEffectId: 'ready_to_crit',
          values: <String, num>{'critChancePercent': 50, 'turns': 5},
        ),
      ];

      final picked = pickImportedPetSkillSelection(
        options: options,
        current: current,
      );

      expect(picked.name, 'Death Blow');
      expect(
        picked.overrideValues,
        const <String, num>{'bonusFlatDamage': 14000},
      );
    });

    test('pickImportedPetSkillSelection merges overrides into refreshed catalog option', () {
      const current = SetupPetSkillSnapshot(
        slotId: 'skill2',
        name: 'Shatter Shield',
        canonicalEffectId: 'shatter_shield',
        values: <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
        overrideValues: <String, num>{'bonusShieldHp': 61},
      );

      final options = <SetupPetSkillSnapshot>[
        const SetupPetSkillSnapshot(
          slotId: 'skill2',
          name: 'Shatter Shield',
          canonicalEffectId: 'shatter_shield',
          values: <String, num>{'baseShieldHp': 200, 'bonusShieldHp': 50},
        ),
      ];

      final picked = pickImportedPetSkillSelection(
        options: options,
        current: current,
      );

      expect(picked.values['baseShieldHp'], 200);
      expect(picked.values['bonusShieldHp'], 50);
      expect(picked.overrideValues, const <String, num>{'bonusShieldHp': 61});
      expect(picked.effectiveValues['bonusShieldHp'], 61);
    });
  });

  group('SetupSnapshot', () {
    test('roundtrip serialization preserves core fields', () {
      final snapshot = SetupSnapshot(
        bossMode: 'blitz',
        bossLevel: 5,
        bossElements: const <ElementType>[ElementType.air, ElementType.water],
        fightMode: FightMode.durableRockShield,
        knights: const <SetupKnightSnapshot>[
          SetupKnightSnapshot(
            atk: 59814,
            def: 74314,
            hp: 1876,
            stun: 25,
            elements: <ElementType>[ElementType.fire, ElementType.earth],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 66408,
            def: 79852,
            hp: 2049,
            stun: 0,
            elements: <ElementType>[ElementType.water, ElementType.water],
            active: false,
          ),
          SetupKnightSnapshot(
            atk: 76247,
            def: 62871,
            hp: 1796,
            stun: 12.5,
            elements: <ElementType>[ElementType.air, ElementType.starmetal],
            active: true,
          ),
        ],
        pet: const SetupPetSnapshot(
          atk: 6583,
          elementalAtk: 1393,
          elementalDef: 1174,
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
              effectSpec: <String, Object?>{
                'attackOverrideModel': 'scaled_to_cap_by_knight_hp_lost_ratio',
              },
            ),
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
              effectSpec: <String, Object?>{
                'target': 'active_knight',
                'stacking': 'adds_hp_to_existing_shield',
              },
            ),
          ],
        ),
        modeEffects: const SetupModeEffectsSnapshot(
          cycloneUseGemsForSpecials: false,
          cycloneBoostPercent: 71.0,
          shatterBaseHp: 150,
          shatterBonusHp: 33,
          drsDefenseBoost: 0.42,
          ewWeaknessEffect: 0.71,
        ),
      );

      final decoded = SetupSnapshot.fromJson(snapshot.toJson());

      expect(decoded.bossMode, 'blitz');
      expect(decoded.bossLevel, 5);
      expect(decoded.bossElements,
          <ElementType>[ElementType.air, ElementType.water]);
      expect(decoded.fightMode, FightMode.durableRockShield);

      expect(decoded.knights, hasLength(3));
      expect(decoded.knights[0].atk, 59814);
      expect(decoded.knights[0].def, 74314);
      expect(decoded.knights[0].hp, 1876);
      expect(decoded.knights[0].stun, 25);
      expect(decoded.knights[0].elements,
          <ElementType>[ElementType.fire, ElementType.earth]);
      expect(decoded.knights[1].active, isFalse);
      expect(decoded.knights[2].elements,
          <ElementType>[ElementType.starmetal, ElementType.starmetal]);

      expect(decoded.pet.atk, 6583);
      expect(decoded.pet.elementalAtk, 1393);
      expect(decoded.pet.elementalDef, 1174);
      expect(decoded.pet.element1, ElementType.water);
      expect(decoded.pet.element2, ElementType.fire);
      expect(decoded.pet.skillUsage, PetSkillUsageMode.cycleSpecial1Then2);
      expect(decoded.pet.importedCompendium?.familyId, 's101sf_ignitide');
      expect(decoded.pet.importedCompendium?.familyTag, 'S101SF');
      expect(decoded.pet.importedCompendium?.selectedSkill1.name,
          'Revenge Strike');
      expect(decoded.pet.importedCompendium?.selectedSkill2.name,
          'Shatter Shield');
      expect(
        decoded.pet.importedCompendium?.selectedSkill2.values['bonusShieldHp'],
        48,
      );
      expect(decoded.pet.resolvedEffects, hasLength(2));
      expect(decoded.pet.resolvedEffects.first.canonicalEffectId,
          'revenge_strike');
      expect(decoded.pet.resolvedEffects.first.sourceSkillName,
          'Revenge Strike');
      expect(
        decoded.petSimulationProfile.archetype,
        PetSimulationArchetype.shatterShield,
      );
      expect(
        decoded.petSimulationProfile.legacyEquivalentMode,
        FightMode.shatterShield,
      );
      expect(decoded.petSimulationResolution.slot1Effect?.canonicalEffectId,
          'revenge_strike');
      expect(decoded.petSimulationResolution.slot2Effect?.canonicalEffectId,
          'shatter_shield');
      expect(
        decoded.petSimulationResolution.modeDrivingEffects
            .map((e) => e.canonicalEffectId)
            .toList(),
        <String>['shatter_shield'],
      );
      expect(decoded.compactSummary(), contains('SS'));

      expect(decoded.modeEffects.shatterBaseHp, 150);
      expect(decoded.modeEffects.shatterBonusHp, 33);
      expect(decoded.modeEffects.drsDefenseBoost, closeTo(0.42, 1e-9));
      expect(decoded.modeEffects.ewWeaknessEffect, closeTo(0.71, 1e-9));
    });

    test('fromJson uses safe defaults with missing optional keys', () {
      final decoded = SetupSnapshot.fromJson(<String, Object?>{
        'bossMode': 'epic', // unsupported for setups -> fallback
        'bossLevel': 99, // clamped by mode
        'bossElements': <Object?>['starmetal'],
        'fightMode': 'not_a_mode',
        'knights': <Object?>[
          <String, Object?>{'atk': 1234.0},
        ],
        'knightElements': <Object?>[
          <Object?>['water'],
        ],
        'activeKnights': <Object?>[false],
        'pet': <String, Object?>{
          'atk': 77,
          'elements': <Object?>['starmetal', ''],
          'skillUsage': 'not_a_valid_mode',
        },
        // legacy flat fields accepted as percent/string
        'drsDefenseBoost': 50,
        'ewWeaknessEffect': '65,5',
      });

      expect(decoded.bossMode, 'raid');
      expect(decoded.bossLevel, 7); // raid clamp
      expect(decoded.bossElements,
          <ElementType>[ElementType.fire, ElementType.fire]);
      expect(decoded.fightMode, FightMode.normal);

      expect(decoded.knights, hasLength(3));
      expect(decoded.knights[0].atk, 1234);
      expect(decoded.knights[0].def, 1000);
      expect(decoded.knights[0].hp, 1000);
      expect(decoded.knights[0].elements,
          <ElementType>[ElementType.water, ElementType.fire]);
      expect(decoded.knights[0].active, isFalse);
      expect(decoded.knights[1].atk, 1000);
      expect(decoded.knights[2].active, isTrue);

      expect(decoded.pet.atk, 77);
      expect(decoded.pet.elementalAtk, 0);
      expect(decoded.pet.elementalDef, 0);
      expect(decoded.pet.element1, ElementType.fire); // starmetal sanitized
      expect(decoded.pet.element2, isNull);
      expect(decoded.pet.skillUsage, PetSkillUsageMode.special1Only);
      expect(decoded.pet.importedCompendium, isNull);
      expect(decoded.pet.resolvedEffects, isEmpty);

      expect(decoded.modeEffects.cycloneUseGemsForSpecials, isTrue);
      expect(decoded.modeEffects.shatterBaseHp, 100);
      expect(decoded.modeEffects.shatterBonusHp, 20);
      expect(decoded.modeEffects.drsDefenseBoost, closeTo(0.5, 1e-9));
      expect(decoded.modeEffects.ewWeaknessEffect, closeTo(0.655, 1e-9));
    });

    test(
        'fromJson migrates legacy imported pet data into canonical skill ids and resolved effects',
        () {
      final decoded = SetupSnapshot.fromJson(<String, Object?>{
        'v': 1,
        'bossMode': 'raid',
        'bossLevel': 4,
        'bossElements': <Object?>['air', 'water'],
        'fightMode': FightMode.normal.name,
        'knights': <Object?>[
          <String, Object?>{'atk': 1000, 'def': 1000, 'hp': 1000, 'stun': 0},
          <String, Object?>{'atk': 1000, 'def': 1000, 'hp': 1000, 'stun': 0},
          <String, Object?>{'atk': 1000, 'def': 1000, 'hp': 1000, 'stun': 0},
        ],
        'knightElements': <Object?>[
          <Object?>['fire', 'fire'],
          <Object?>['fire', 'fire'],
          <Object?>['fire', 'fire'],
        ],
        'activeKnights': <Object?>[true, true, true],
        'pet': <String, Object?>{
          'atk': 6583,
          'elementalAtk': 1393,
          'elementalDef': 1174,
          'elements': <Object?>['water', 'fire'],
          'skillUsage': PetSkillUsageMode.special2Only.name,
          'importedCompendium': <String, Object?>{
            'familyId': 's101sf_ignitide',
            'familyTag': 'S101SF',
            'rarity': 'Shadowforged',
            'tierId': 'V',
            'tierName': '[S101SF] Ignitide',
            'profileId': 'max',
            'profileLabel': 'Max 99',
            'useAltSkillSet': false,
            'selectedSkill1': <String, Object?>{
              'slotId': 'skill11',
              'name': 'Revenge Strike',
              'values': <String, Object?>{'petAttackCap': 12912},
            },
            'selectedSkill2': <String, Object?>{
              'slotId': 'skill2',
              'name': 'Shatter Shield',
              'values': <String, Object?>{
                'baseShieldHp': 178,
                'bonusShieldHp': 48,
              },
            },
          },
        },
      });

      expect(decoded.v, 1);
      expect(
        decoded.pet.importedCompendium?.selectedSkill1.canonicalEffectId,
        'revenge_strike',
      );
      expect(
        decoded.pet.importedCompendium?.selectedSkill2.canonicalEffectId,
        'shatter_shield',
      );
      expect(decoded.pet.resolvedEffects, hasLength(2));
      expect(
        decoded.pet.resolvedEffects.map((e) => e.canonicalEffectId).toList(),
        containsAll(<String>['revenge_strike', 'shatter_shield']),
      );
      expect(
        decoded.petSimulationProfile.archetype,
        PetSimulationArchetype.shatterShield,
      );
      expect(
        decoded.petSimulationProfile.legacyEquivalentMode,
        FightMode.shatterShield,
      );
    });

    test('pet simulation profile derives canonical mode from imported skills', () {
      final snapshot = SetupSnapshot(
        bossMode: 'raid',
        bossLevel: 4,
        bossElements: const <ElementType>[ElementType.air, ElementType.water],
        fightMode: FightMode.normal,
        knights: List<SetupKnightSnapshot>.generate(
          3,
          (_) => SetupKnightSnapshot.defaults(),
          growable: false,
        ),
        pet: const SetupPetSnapshot(
          atk: 3892,
          elementalAtk: 955,
          elementalDef: 845,
          element1: ElementType.spirit,
          element2: null,
          skillUsage: PetSkillUsageMode.special2ThenSpecial1,
          importedCompendium: SetupPetCompendiumImportSnapshot(
            familyId: 's47_night_lalsaumo',
            familyTag: 'S47',
            rarity: '5 stars',
            tierId: 'V',
            tierName: '[S47] Night Lalsaumo',
            profileId: 'max90',
            profileLabel: 'Max 90',
            useAltSkillSet: false,
            selectedSkill1: SetupPetSkillSnapshot(
              slotId: 'skill11',
              name: 'Elemental Weakness',
              values: <String, num>{
                'enemyAttackReductionPercent': 30.8,
                'turns': 2,
              },
            ),
            selectedSkill2: SetupPetSkillSnapshot(
              slotId: 'skill2',
              name: 'Soul Burn',
              values: <String, num>{
                'flatDamage': 2334,
                'damageOverTime': 4598,
                'turns': 3,
              },
            ),
          ),
          resolvedEffects: <PetResolvedEffect>[
            PetResolvedEffect(
              sourceSlotId: 'skill11',
              sourceSkillName: 'Elemental Weakness',
              values: <String, num>{
                'enemyAttackReductionPercent': 30.8,
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
              sourceSkillName: 'Soul Burn',
              values: <String, num>{
                'flatDamage': 2334,
                'damageOverTime': 4598,
                'turns': 3,
              },
              canonicalEffectId: 'soul_burn',
              canonicalName: 'Soul Burn',
              effectCategory: 'damage_over_time',
              dataSupport: 'structured_values',
              runtimeSupport: 'none',
              simulatorModes: <String>[],
              effectSpec: <String, Object?>{},
            ),
          ],
        ),
        modeEffects: const SetupModeEffectsSnapshot(
          cycloneUseGemsForSpecials: false,
          cycloneBoostPercent: 71.0,
          shatterBaseHp: 100,
          shatterBonusHp: 20,
          drsDefenseBoost: 0.5,
          ewWeaknessEffect: 0.65,
        ),
      );

      expect(snapshot.petSimulationProfile.archetype,
          PetSimulationArchetype.normal);
      expect(snapshot.compactSummary(), contains('Normal'));
    });

    test('compactSummary prefers canonical profile derived from imported skills',
        () {
      final snapshot = SetupSnapshot(
        bossMode: 'raid',
        bossLevel: 3,
        bossElements: const <ElementType>[ElementType.fire, ElementType.water],
        fightMode: FightMode.normal,
        knights: List<SetupKnightSnapshot>.generate(
          3,
          (_) => SetupKnightSnapshot.defaults(),
          growable: false,
        ),
        pet: const SetupPetSnapshot(
          atk: 3892,
          elementalAtk: 955,
          elementalDef: 845,
          element1: ElementType.spirit,
          element2: null,
          skillUsage: PetSkillUsageMode.special2ThenSpecial1,
          importedCompendium: SetupPetCompendiumImportSnapshot(
            familyId: 's47_sr_ew_pet',
            familyTag: 'S47',
            rarity: '5 stars',
            tierId: 'V',
            tierName: '[S47] Hybrid Tester',
            profileId: 'max90',
            profileLabel: 'Max 90',
            useAltSkillSet: false,
            selectedSkill1: SetupPetSkillSnapshot(
              slotId: 'skill11',
              name: 'Special Regeneration (inf)',
              values: <String, num>{'chargeRatePercent': 70},
            ),
            selectedSkill2: SetupPetSkillSnapshot(
              slotId: 'skill2',
              name: 'Elemental Weakness',
              values: <String, num>{
                'enemyAttackReductionPercent': 30.8,
                'turns': 2,
              },
            ),
          ),
          resolvedEffects: <PetResolvedEffect>[
            PetResolvedEffect(
              sourceSlotId: 'skill11',
              sourceSkillName: 'Special Regeneration (inf)',
              values: <String, num>{'chargeRatePercent': 70},
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
                'enemyAttackReductionPercent': 30.8,
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
        ),
        modeEffects: SetupModeEffectsSnapshot.defaults(),
      );

      expect(
        snapshot.petSimulationProfile.archetype,
        PetSimulationArchetype.specialRegenPlusElementalWeakness,
      );
      expect(
        snapshot.petSimulationResolution.runtimeActiveEffects
            .map((e) => e.canonicalEffectId)
            .toList(),
        <String>['special_regeneration_infinite', 'elemental_weakness'],
      );
      expect(snapshot.compactSummary(), contains('SR+EW'));
    });
  });

  group('SetupSlotRecord', () {
    test('serializes slot wrapper and exposes compact summary', () {
      final slot = SetupSlotRecord(
        slot: 2,
        savedAt: DateTime.utc(2026, 2, 22, 12, 0, 0),
        setup: SetupSnapshot.defaults(),
        customName: 'Raid L4 SS',
      );

      final decoded = SetupSlotRecord.fromJson(slot.toJson());

      expect(decoded.slot, 2);
      expect(decoded.customName, 'Raid L4 SS');
      expect(decoded.savedAtIso, startsWith('2026-02-22T12:00:00.000Z'));
      expect(decoded.compactSummary(), contains('Raid L1'));
      expect(decoded.compactSummary(), contains('K:3/3'));
    });

    test('fromJson falls back on malformed slot metadata', () {
      final decoded = SetupSlotRecord.fromJson(<String, Object?>{
        'slot': 99,
        'savedAtIso': 'not-a-date',
        'setup': <String, Object?>{},
      });

      expect(decoded.slot, 5);
      expect(DateTime.tryParse(decoded.savedAtIso), isNotNull);
      expect(decoded.setup.bossMode, 'raid');
    });
  });
}
