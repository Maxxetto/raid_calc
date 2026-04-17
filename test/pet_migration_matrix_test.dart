import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/setup_models.dart';
import 'package:raid_calc/data/share_payloads.dart';

Map<String, Object?> _legacySetupJson({
  required String skill1Name,
  required Map<String, Object?> skill1Values,
  required String skill2Name,
  required Map<String, Object?> skill2Values,
  required PetSkillUsageMode usageMode,
}) {
  return <String, Object?>{
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
      'skillUsage': usageMode.name,
      'importedCompendium': <String, Object?>{
        'familyId': 'migration_test_pet',
        'familyTag': 'SXX',
        'rarity': 'Shadowforged',
        'tierId': 'V',
        'tierName': '[SXX] Migration Test',
        'profileId': 'max',
        'profileLabel': 'Max 99',
        'useAltSkillSet': false,
        'selectedSkill1': <String, Object?>{
          'slotId': 'skill11',
          'name': skill1Name,
          'values': skill1Values,
        },
        'selectedSkill2': <String, Object?>{
          'slotId': 'skill2',
          'name': skill2Name,
          'values': skill2Values,
        },
      },
    },
  };
}

void main() {
  group('Pet migration matrix', () {
    final cases = <({
      String label,
      Map<String, Object?> setupJson,
      FightMode? expectedLegacyEquivalentMode,
      List<String> expectedCanonicalEffectIds,
    })>[
      (
        label: 'Shatter',
        setupJson: _legacySetupJson(
          skill1Name: 'Revenge Strike',
          skill1Values: <String, Object?>{'petAttackCap': 12912},
          skill2Name: 'Shatter Shield',
          skill2Values: <String, Object?>{
            'baseShieldHp': 178,
            'bonusShieldHp': 48,
          },
          usageMode: PetSkillUsageMode.special2Only,
        ),
        expectedLegacyEquivalentMode: FightMode.shatterShield,
        expectedCanonicalEffectIds: <String>[
          'revenge_strike',
          'shatter_shield',
        ],
      ),
      (
        label: 'SR+EW',
        setupJson: _legacySetupJson(
          skill1Name: 'Special Regeneration (inf)',
          skill1Values: <String, Object?>{'chargeRatePercent': 104.72},
          skill2Name: 'Elemental Weakness',
          skill2Values: <String, Object?>{
            'enemyAttackReductionPercent': 65.2,
            'turns': 2,
          },
          usageMode: PetSkillUsageMode.special2ThenSpecial1,
        ),
        expectedLegacyEquivalentMode: FightMode.specialRegenPlusEw,
        expectedCanonicalEffectIds: <String>[
          'special_regeneration_infinite',
          'elemental_weakness',
        ],
      ),
      (
        label: 'Cyclone',
        setupJson: _legacySetupJson(
          skill1Name: 'Vampiric Attack',
          skill1Values: <String, Object?>{
            'flatDamage': 5710,
            'stealPercent': 10,
          },
          skill2Name: 'Cyclone Earth Boost',
          skill2Values: <String, Object?>{
            'attackBoostPercent': 11,
            'turns': 5,
          },
          usageMode: PetSkillUsageMode.special1Only,
        ),
        expectedLegacyEquivalentMode: FightMode.normal,
        expectedCanonicalEffectIds: <String>[
          'vampiric_attack',
          'cyclone_boost_earth',
        ],
      ),
      (
        label: 'Normal offensive pair',
        setupJson: _legacySetupJson(
          skill1Name: 'Death Blow',
          skill1Values: <String, Object?>{},
          skill2Name: 'Shadow Slash',
          skill2Values: <String, Object?>{'petAttack': 8750},
          usageMode: PetSkillUsageMode.cycleSpecial1Then2,
        ),
        expectedLegacyEquivalentMode: FightMode.normal,
        expectedCanonicalEffectIds: <String>['death_blow', 'shadow_slash'],
      ),
    ];

    for (final testCase in cases) {
      test('SetupSnapshot migrates ${testCase.label} into canonical metadata',
          () {
        final parsed = SetupSnapshot.fromJson(testCase.setupJson);

        expect(
          parsed.pet.importedCompendium?.selectedSkill1.canonicalEffectId,
          testCase.expectedCanonicalEffectIds.first,
        );
        expect(
          parsed.pet.importedCompendium?.selectedSkill2.canonicalEffectId,
          testCase.expectedCanonicalEffectIds.last,
        );
        expect(
          parsed.pet.resolvedEffects.map((e) => e.canonicalEffectId).toList(),
          containsAll(testCase.expectedCanonicalEffectIds),
        );
        expect(
          parsed.petSimulationProfile.legacyEquivalentMode,
          testCase.expectedLegacyEquivalentMode,
        );
      });

      test('SetupSharePayload migrates ${testCase.label} into canonical metadata',
          () {
        final payload = <String, Object?>{
          'kind': SetupSharePayload.kind,
          'v': 1,
          'exportedAtIso': DateTime(2026, 3, 21).toIso8601String(),
          'setup': testCase.setupJson,
        };

        final parsed = SetupSharePayload.fromJson(payload);

        expect(
          parsed.setup.pet.resolvedEffects
              .map((e) => e.canonicalEffectId)
              .toList(),
          containsAll(testCase.expectedCanonicalEffectIds),
        );
        expect(
          parsed.setup.petSimulationProfile.legacyEquivalentMode,
          testCase.expectedLegacyEquivalentMode,
        );
      });
    }
  });
}
