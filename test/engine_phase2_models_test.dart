import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/engine/battle_engine.dart';
import 'package:raid_calc/core/engine/skill_catalog.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/pet_loadout_models.dart';
import 'package:raid_calc/data/setup_models.dart';

void main() {
  group('Phase 2 skill pipeline', () {
    test('SetupPetSkillSnapshot persists overrideValues and effectiveValues', () {
      final skill = SetupPetSkillSnapshot(
        slotId: 'skill11',
        name: 'Elemental Weakness',
        canonicalEffectId: 'elemental_weakness',
        values: const <String, num>{
          'enemyAttackReductionPercent': 65,
          'turns': 2,
        },
        overrideValues: const <String, num>{
          'turns': 3,
        },
      );

      final roundTrip = SetupPetSkillSnapshot.fromJson(skill.toJson());

      expect(roundTrip.overrideValues, const <String, num>{'turns': 3});
      expect(roundTrip.effectiveValues['turns'], 3);
      expect(roundTrip.effectiveValues['enemyAttackReductionPercent'], 65);
      expect(roundTrip.isEffectDisabledByOverride, isFalse);
    });

    test('loadout exposes normalized override map and disabled effects', () {
      final pet = SetupPetSnapshot(
        atk: 100,
        element1: ElementType.fire,
        element2: null,
        skillUsage: PetSkillUsageMode.special1Only,
        manualSkill1: const SetupPetSkillSnapshot(
          slotId: 'skill11',
          name: 'Cyclone Earth Boost',
          canonicalEffectId: 'cyclone_boost_earth',
          values: <String, num>{
            'attackBoostPercent': 71,
            'turns': 5,
          },
          overrideValues: <String, num>{
            'turns': 0,
          },
        ),
        resolvedEffects: const <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Cyclone Earth Boost',
            values: <String, num>{
              'attackBoostPercent': 71,
              'turns': 5,
            },
            canonicalEffectId: 'cyclone_boost_earth',
            canonicalName: 'Cyclone Boost',
            effectCategory: 'knight_attack_buff',
            dataSupport: 'structured_values',
            runtimeSupport: 'mode_specific',
            simulatorModes: <String>['cycloneBoost'],
            effectSpec: <String, Object?>{},
          ),
        ],
      );

      final loadout = PetLoadoutSnapshot.fromSetupPet(pet);

      expect(loadout.slot1, isNotNull);
      expect(loadout.slot1!.normalizedCanonicalEffectId,
          BattleSkillCatalog.cycloneId);
      expect(loadout.slot1!.isEffectDisabled, isTrue);
      expect(loadout.overrideValuesBySkillKey, <String, Map<String, num>>{
        'skill11|cyclone_boost': const <String, num>{'turns': 0},
      });
      expect(loadout.canonicalEffectIds, isEmpty);
    });

    test('engine seed resolves overrides and canonical aliases', () {
      const pre = Precomputed(
        meta: BossMeta(
          raidMode: true,
          level: 1,
          advVsKnights: <double>[1.0, 1.0, 1.0],
          evasionChance: 0.1,
          criticalChance: 0.05,
          criticalMultiplier: 1.5,
          raidSpecialMultiplier: 3.25,
          hitsToFirstShatter: 7,
          hitsToNextShatter: 13,
          knightToSpecial: 5,
          bossToSpecial: 6,
          bossToSpecialFakeEW: 1000,
          knightToSpecialSR: 7,
          knightToRecastSpecialSR: 13,
          knightToSpecialSREW: 7,
          knightToRecastSpecialSREW: 13,
          hitsToElementalWeakness: 7,
          durationElementalWeakness: 2,
          defaultElementalWeakness: 0.65,
          cyclone: 71.0,
          defaultDurableRockShield: 0.5,
          sameElementDRS: 1.6,
          strongElementEW: 1.6,
          hitsToDRS: 7,
          durationDRS: 3,
          cycleMultiplier: 1.0,
          epicBossDamageBonus: 0.25,
          timing: TimingConfig(
            normalDuration: 0.4,
            specialDuration: 0.6,
            stunDuration: 0.2,
            missDuration: 0.3,
            bossDuration: 0.4,
            bossSpecialDuration: 0.7,
          ),
        ),
        stats: BossStats(attack: 1000, defense: 1000, hp: 10000),
        kAtk: <double>[1000],
        kDef: <double>[1000],
        kHp: <int>[1000],
        kAdv: <double>[1.0],
        kStun: <double>[0.0],
        petAtk: 100,
        petAdv: 1.0,
        petSkillUsage: PetSkillUsageMode.cycleSpecial1Then2,
        petEffects: <PetResolvedEffect>[
          PetResolvedEffect(
            sourceSlotId: 'skill11',
            sourceSkillName: 'Cyclone Earth Boost',
            values: <String, num>{
              'attackBoostPercent': 71,
              'turns': 5,
            },
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
            sourceSkillName: 'Leech Strike',
            values: <String, num>{
              'flatDamage': 1200,
              'stealPercent': 20,
            },
            canonicalEffectId: 'leech_strike',
            canonicalName: 'Leech Strike',
            effectCategory: 'life_steal_attack',
            dataSupport: 'structured_values',
            runtimeSupport: 'normal_only',
            simulatorModes: <String>['normal'],
            effectSpec: <String, Object?>{},
          ),
        ],
        kNormalDmg: <int>[100],
        kCritDmg: <int>[150],
        kSpecialDmg: <int>[325],
        petNormalDmg: 16,
        petCritDmg: 24,
        bNormalDmg: <int>[100],
        bCritDmg: <int>[150],
      );

      final loadout = PetLoadoutSnapshot(
        slot1: const PetLoadoutSlotSelection(
          slotId: 'skill11',
          skillName: 'Cyclone Earth Boost',
          canonicalEffectId: 'cyclone_boost_earth',
          values: <String, num>{
            'attackBoostPercent': 71,
            'turns': 5,
          },
          overrideValues: <String, num>{
            'turns': 12,
          },
        ),
        slot2: const PetLoadoutSlotSelection(
          slotId: 'skill2',
          skillName: 'Leech Strike',
          canonicalEffectId: 'leech_strike',
          values: <String, num>{
            'flatDamage': 1200,
            'stealPercent': 20,
          },
        ),
        usageMode: PetSkillUsageMode.cycleSpecial1Then2,
        resolvedEffects: pre.petEffects,
      );

      final engine = RaidBlitzBattleEngine();
      final seed = BattleEngineSeed.fromLoadoutSnapshot(
        pre: pre,
        loadout: loadout,
      );
      final skills = engine.resolveSkills(seed);

      expect(skills.first.canonicalEffectId, BattleSkillCatalog.cycloneId);
      expect(skills.first.values.intValue('turns'), 12);
      expect(skills.last.canonicalEffectId, BattleSkillCatalog.vampiricAttackId);
      expect(skills.last.displayName, 'Leech Strike');
    });
  });
}
