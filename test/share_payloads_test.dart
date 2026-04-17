import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/battle_outcome.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/setup_models.dart';
import 'package:raid_calc/data/share_payloads.dart';

void main() {
  test('SetupSharePayload roundtrip and fenced text decode', () {
    final record = SetupSlotRecord(
      slot: 2,
      customName: 'Guild test',
      setup: SetupSnapshot(
        bossMode: 'raid',
        bossLevel: 4,
        bossElements: const [ElementType.air, ElementType.water],
        fightMode: FightMode.specialRegenPlusEw,
        knights: const [
          SetupKnightSnapshot(
            atk: 1000,
            def: 2000,
            hp: 3000,
            stun: 12.5,
            elements: [ElementType.air, ElementType.air],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 4000,
            def: 5000,
            hp: 6000,
            stun: 0,
            elements: [ElementType.fire, ElementType.water],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 7000,
            def: 8000,
            hp: 9000,
            stun: 25,
            elements: [ElementType.earth, ElementType.spirit],
            active: false,
          ),
        ],
        pet: const SetupPetSnapshot(
          atk: 123,
          element1: ElementType.air,
          element2: ElementType.water,
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
              sourceSlotId: 'skill2',
              sourceSkillName: 'Shatter Shield',
              values: <String, num>{'baseShieldHp': 178, 'bonusShieldHp': 48},
              canonicalEffectId: 'shatter_shield',
              canonicalName: 'Shatter Shield',
              effectCategory: 'damage_absorb_shield',
              dataSupport: 'structured_values',
              runtimeSupport: 'mode_specific',
              simulatorModes: <String>['shatterShield'],
              effectSpec: <String, Object?>{
                'target': 'active_knight',
              },
            ),
          ],
        ),
        modeEffects: const SetupModeEffectsSnapshot(
          cycloneUseGemsForSpecials: false,
          cycloneBoostPercent: 71.0,
          shatterBaseHp: 111,
          shatterBonusHp: 22,
          drsDefenseBoost: 0.5,
          ewWeaknessEffect: 0.65,
        ),
      ),
    );

    final payload = SetupSharePayload.fromRecord(record);
    final fenced = '```json\n${encodePrettyJson(payload.toJson())}\n```';
    final parsed = SetupSharePayload.fromText(fenced);

    expect(parsed.name, 'Guild test');
    expect(parsed.setup.bossLevel, 4);
    expect(parsed.setup.fightMode, FightMode.specialRegenPlusEw);
    expect(parsed.setup.pet.element1, ElementType.air);
    expect(parsed.setup.pet.importedCompendium?.familyTag, 'S101SF');
    expect(parsed.setup.pet.importedCompendium?.selectedSkill2.name,
        'Shatter Shield');
    expect(
      parsed.setup.pet.importedCompendium?.selectedSkill2.canonicalEffectId,
      'shatter_shield',
    );
    expect(parsed.setup.pet.resolvedEffects.single.canonicalEffectId,
        'shatter_shield');
    expect(parsed.setup.knights[2].active, isFalse);
  });

  test(
      'SetupSharePayload migrates legacy imported pet setup without resolved effects',
      () {
    final payload = <String, Object?>{
      'kind': SetupSharePayload.kind,
      'v': 1,
      'exportedAtIso': DateTime(2026, 3, 21).toIso8601String(),
      'setup': <String, Object?>{
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
      },
    };

    final parsed = SetupSharePayload.fromJson(payload);
    expect(parsed.setup.pet.resolvedEffects, hasLength(2));
    expect(
      parsed.setup.pet.importedCompendium?.selectedSkill1.canonicalEffectId,
      'revenge_strike',
    );
    expect(
      parsed.setup.petSimulationProfile.legacyEquivalentMode,
      FightMode.shatterShield,
    );
  });

  test('ResultsSharePayload roundtrip and legacy payload compatibility', () {
    final pre = Precomputed.fromJson(<String, Object?>{
      'meta': <String, Object?>{
        'raidMode': true,
        'level': 4,
        'advVsKnights': <double>[1.0, 1.5, 2.0],
      },
      'stats': <String, Object?>{
        'attack': 100,
        'defense': 200,
        'hp': 300,
      },
      'kAtk': <int>[1000, 2000, 3000],
      'kDef': <int>[1100, 2100, 3100],
      'kHp': <int>[1200, 2200, 3200],
      'kAdv': <double>[1.0, 1.5, 2.0],
      'kStun': <double>[0.1, 0.2, 0.3],
      'petAtk': 500,
      'petAdv': 1.5,
      'petSkillUsage': 'special2ThenSpecial1',
      'petEffects': <Object?>[
        <String, Object?>{
          'sourceSlotId': 'skill11',
          'sourceSkillName': 'Death Blow',
          'values': <String, Object?>{},
          'canonicalEffectId': 'death_blow',
          'canonicalName': 'Death Blow',
          'effectCategory': 'pet_attack_modifier',
          'dataSupport': 'description_only',
          'runtimeSupport': 'none',
          'simulatorModes': <Object?>[],
          'effectSpec': <String, Object?>{
            'bonusFlatDamage': 750,
          },
        },
      ],
      'kNormalDmg': <int>[10, 20, 30],
      'kCritDmg': <int>[15, 30, 45],
      'kSpecialDmg': <int>[25, 50, 75],
      'petNormalDmg': 40,
      'petCritDmg': 60,
      'bNormalDmg': <int>[11, 22, 33],
      'bCritDmg': <int>[16, 32, 48],
    });
    final stats = SimStats(
      mean: 100000,
      median: 99000,
      min: 80000,
      max: 120000,
      series: const SimulationSeries(
        checkpointEvery: 500,
        totalRuns: 1000,
        checkpoints: <SimulationCheckpoint>[
          SimulationCheckpoint(
            runIndex: 500,
            cumulativeMean: 98000,
            cumulativeMin: 80000,
            cumulativeMax: 115000,
          ),
          SimulationCheckpoint(
            runIndex: 1000,
            cumulativeMean: 100000,
            cumulativeMin: 80000,
            cumulativeMax: 120000,
          ),
        ],
        histogram: SimulationHistogram(
          bins: <SimulationHistogramBin>[
            SimulationHistogramBin(
              lowerBound: 80000,
              upperBound: 89999,
              count: 120,
            ),
            SimulationHistogramBin(
              lowerBound: 90000,
              upperBound: 99999,
              count: 430,
            ),
            SimulationHistogramBin(
              lowerBound: 100000,
              upperBound: 109999,
              count: 310,
            ),
            SimulationHistogramBin(
              lowerBound: 110000,
              upperBound: 120000,
              count: 140,
            ),
          ],
        ),
      ),
      timing: null,
    );
    final payload = ResultsSharePayload(
      fightMode: FightMode.durableRockShield,
      cycloneUseGemsForSpecials: false,
      isPremium: true,
      debugEnabled: false,
      milestoneTargetPoints: 1000000000,
      startEnergies: 10,
      freeRaidEnergies: 30,
      knightIds: const ['K1', 'K2', 'K3'],
      shatter: const ShatterShieldConfig(
        baseHp: 100,
        bonusHp: 20,
        elementMatch: [true, false, true],
      ),
      pre: pre,
      stats: stats,
      elixirs: const [
        ElixirInventoryItem(
          name: 'Test',
          gamemode: 'Raid',
          scoreMultiplier: 0.35,
          durationMinutes: 30,
          quantity: 2,
        ),
      ],
      petElement1Id: 'air',
      petElement2Id: 'water',
      knightElementPairs: const [
        ['fire', 'air'],
        ['earth', 'water'],
        ['spirit', 'air'],
      ],
      exportedAtIso: DateTime(2026, 2, 24).toIso8601String(),
    );

    final parsed = ResultsSharePayload.fromText(jsonEncode(payload.toJson()));
    expect(parsed.fightMode, FightMode.durableRockShield);
    expect(parsed.isPremium, isTrue);
    expect(parsed.pre.petNormalDmg, 40);
    expect(parsed.pre.petSkillUsage, PetSkillUsageMode.special2ThenSpecial1);
    expect(parsed.pre.petEffects.single.canonicalEffectId, 'death_blow');
    expect(parsed.petElement1Id, 'air');
    expect(parsed.petElement2Id, 'water');
    expect(parsed.knightElementPairs.length, 3);
    expect(parsed.knightElementPairs.first.first, 'fire');
    expect(parsed.elixirs.single.name, 'Test');
    expect(parsed.stats.series?.checkpointEvery, 500);
    expect(parsed.stats.series?.checkpoints, hasLength(2));
    expect(parsed.stats.series?.histogram?.bins, hasLength(4));
    expect(parsed.stats.series?.histogram?.bins[1].count, 430);

    final legacy = payload.toJson()
      ..remove('kind')
      ..remove('v');
    final legacyParsed = ResultsSharePayload.fromJson(legacy);
    expect(legacyParsed.stats.mean, 100000);
    expect(legacyParsed.pre.stats.hp, 300);
  });
}
