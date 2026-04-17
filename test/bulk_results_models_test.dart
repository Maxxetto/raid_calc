import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/battle_outcome.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/bulk_results_models.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/setup_models.dart';

void main() {
  TimingConfig timingConfig() => const TimingConfig(
        normalDuration: 0.4,
        specialDuration: 0.6,
        stunDuration: 0.2,
        missDuration: 0.3,
        bossDuration: 0.4,
        bossSpecialDuration: 0.7,
      );

  BossMeta bossMeta({required bool raidMode, required int level}) => BossMeta(
        raidMode: raidMode,
        level: level,
        advVsKnights: const <double>[1.0, 1.0, 1.0],
        evasionChance: 0.1,
        criticalChance: 0.1,
        criticalMultiplier: 1.5,
        raidSpecialMultiplier: 2.0,
        hitsToFirstShatter: 3,
        hitsToNextShatter: 3,
        knightToSpecial: 3,
        bossToSpecial: 4,
        bossToSpecialFakeEW: 4,
        knightToSpecialSR: 1,
        knightToRecastSpecialSR: 2,
        knightToSpecialSREW: 1,
        knightToRecastSpecialSREW: 2,
        hitsToElementalWeakness: 3,
        durationElementalWeakness: 2,
        defaultElementalWeakness: 0.65,
        cyclone: 0.2,
        defaultDurableRockShield: 0.5,
        sameElementDRS: 1.6,
        strongElementEW: 1.6,
        hitsToDRS: 3,
        durationDRS: 2,
        cycleMultiplier: 1.0,
        epicBossDamageBonus: 0.25,
        timing: timingConfig(),
      );

  Precomputed precomputed({
    required bool raidMode,
    required int level,
  }) =>
      Precomputed(
        meta: bossMeta(raidMode: raidMode, level: level),
        stats: const BossStats(attack: 1000, defense: 1000, hp: 100000),
        kAtk: const <double>[1000, 2000, 3000],
        kDef: const <double>[1100, 2100, 3100],
        kHp: const <int>[1200, 2200, 3200],
        kAdv: const <double>[1.0, 1.5, 2.0],
        kStun: const <double>[0.1, 0.2, 0.3],
        petAtk: 1500,
        petAdv: 1.5,
        kNormalDmg: const <int>[100, 200, 300],
        kCritDmg: const <int>[150, 300, 450],
        kSpecialDmg: const <int>[180, 360, 540],
        petNormalDmg: 90,
        petCritDmg: 135,
        bNormalDmg: const <int>[40, 50, 60],
        bCritDmg: const <int>[60, 75, 90],
      );

  SetupSnapshot setup({
    required String bossMode,
    required int bossLevel,
    required FightMode fightMode,
    required bool cycloneUseGemsForSpecials,
  }) {
    return SetupSnapshot(
      bossMode: bossMode,
      bossLevel: bossLevel,
      bossElements: const <ElementType>[ElementType.fire, ElementType.water],
      fightMode: fightMode,
      knights: const <SetupKnightSnapshot>[
        SetupKnightSnapshot(
          atk: 59814,
          def: 74314,
          hp: 1876,
          stun: 25.0,
          elements: <ElementType>[ElementType.fire, ElementType.earth],
          active: true,
        ),
        SetupKnightSnapshot(
          atk: 66408,
          def: 79852,
          hp: 2049,
          stun: 0.0,
          elements: <ElementType>[ElementType.water, ElementType.water],
          active: true,
        ),
        SetupKnightSnapshot(
          atk: 76247,
          def: 62871,
          hp: 1796,
          stun: 12.0,
          elements: <ElementType>[ElementType.air, ElementType.air],
          active: false,
        ),
      ],
      pet: const SetupPetSnapshot(
        atk: 6583,
        element1: ElementType.water,
        element2: ElementType.fire,
      ),
      modeEffects: SetupModeEffectsSnapshot(
        cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
        cycloneBoostPercent: 71.0,
        shatterBaseHp: 100,
        shatterBonusHp: 20,
        drsDefenseBoost: 0.5,
        ewWeaknessEffect: 0.65,
      ),
    );
  }

  SimStats statsWithTiming({
    required int mean,
    required double runSeconds,
  }) {
    return SimStats(
      mean: mean,
      median: mean,
      min: (mean * 0.8).round(),
      max: (mean * 1.2).round(),
      timing: TimingStats(
        meanRunSeconds: runSeconds,
        meanBossSeconds: 5,
        meanKnightSeconds: const <double>[1, 1, 1],
        meanSurvivalSeconds: const <double>[1, 1, 1],
        kNormalCount: const <double>[1, 1, 1],
        kNormalSeconds: const <double>[1, 1, 1],
        kSpecialCount: const <double>[1, 1, 1],
        kSpecialSeconds: const <double>[1, 1, 1],
        kStunCount: const <double>[1, 1, 1],
        kStunSeconds: const <double>[1, 1, 1],
        kMissCount: const <double>[1, 1, 1],
        kMissSeconds: const <double>[1, 1, 1],
        bNormalCount: const <double>[1, 1, 1],
        bNormalSeconds: const <double>[1, 1, 1],
        bSpecialCount: const <double>[1, 1, 1],
        bSpecialSeconds: const <double>[1, 1, 1],
        bMissCount: const <double>[1, 1, 1],
        bMissSeconds: const <double>[1, 1, 1],
      ),
    );
  }

  group('BulkSimulationRunResult metrics', () {
    test('expected range uses +/-8% of mean and rounds', () {
      final run = BulkSimulationRunResult(
        slot: 1,
        setup: setup(
          bossMode: 'raid',
          bossLevel: 4,
          fightMode: FightMode.normal,
          cycloneUseGemsForSpecials: false,
        ),
        pre: precomputed(raidMode: true, level: 4),
        stats: statsWithTiming(mean: 1000, runSeconds: 20),
        shatter: null,
        completedAt: DateTime.utc(2026, 2, 22),
      );

      expect(run.expectedRange.lower, 920);
      expect(run.expectedRange.upper, 1080);
    });

    test('points per second uses mean / meanRunSeconds when timing exists', () {
      final run = BulkSimulationRunResult(
        slot: 1,
        setup: setup(
          bossMode: 'raid',
          bossLevel: 4,
          fightMode: FightMode.normal,
          cycloneUseGemsForSpecials: false,
        ),
        pre: precomputed(raidMode: true, level: 4),
        stats: statsWithTiming(mean: 1200, runSeconds: 24),
        shatter: null,
      );

      expect(run.meanRunSeconds, 24.0);
      expect(run.pointsPerSecond, closeTo(50.0, 1e-9));
    });

    test('points per second is null when timing missing or invalid', () {
      final noTiming = BulkSimulationRunResult(
        slot: 1,
        setup: setup(
          bossMode: 'raid',
          bossLevel: 4,
          fightMode: FightMode.normal,
          cycloneUseGemsForSpecials: false,
        ),
        pre: precomputed(raidMode: true, level: 4),
        stats: const SimStats(
          mean: 1000,
          median: 1000,
          min: 900,
          max: 1100,
          timing: null,
        ),
        shatter: null,
      );
      expect(noTiming.meanRunSeconds, isNull);
      expect(noTiming.pointsPerSecond, isNull);

      final zeroTiming = BulkSimulationRunResult(
        slot: 1,
        setup: setup(
          bossMode: 'raid',
          bossLevel: 4,
          fightMode: FightMode.normal,
          cycloneUseGemsForSpecials: false,
        ),
        pre: precomputed(raidMode: true, level: 4),
        stats: statsWithTiming(mean: 1000, runSeconds: 0),
        shatter: null,
      );
      expect(zeroTiming.meanRunSeconds, isNull);
      expect(zeroTiming.pointsPerSecond, isNull);
    });
  });

  group('BulkSimulationBatchResult comparison', () {
    test('comparisonRows preserve setup details and sort by slot', () {
      final run2 = BulkSimulationRunResult(
        slot: 2,
        setup: setup(
          bossMode: 'blitz',
          bossLevel: 3,
          fightMode: FightMode.durableRockShield,
          cycloneUseGemsForSpecials: false,
        ),
        pre: precomputed(raidMode: false, level: 3),
        stats: statsWithTiming(mean: 1500, runSeconds: 30),
        shatter: null,
      );
      final run1 = BulkSimulationRunResult(
        slot: 1,
        setup: setup(
          bossMode: 'raid',
          bossLevel: 5,
          fightMode: FightMode.cycloneBoost,
          cycloneUseGemsForSpecials: true,
        ),
        pre: precomputed(raidMode: true, level: 5),
        stats: statsWithTiming(mean: 2000, runSeconds: 40),
        shatter: null,
      );

      final batch = BulkSimulationBatchResult(runs: <BulkSimulationRunResult>[
        run2,
        run1,
      ]);

      final rows = batch.comparisonRows;
      expect(rows, hasLength(2));
      expect(rows.map((e) => e.slot), orderedEquals(<int>[1, 2]));

      final row1 = rows[0];
      expect(row1.bossMode, 'raid');
      expect(row1.bossLevel, 5);
      expect(row1.fightMode, FightMode.cycloneBoost);
      expect(row1.cycloneUseGemsForSpecials, isTrue);
      expect(row1.knights[0].atk, 59814);
      expect(row1.knights[0].def, 74314);
      expect(row1.knights[0].hp, 1876);
      expect(row1.knights[0].stun, 25.0);
      expect(row1.knights[0].elements,
          <ElementType>[ElementType.fire, ElementType.earth]);
      expect(row1.pet.atk, 6583);
      expect(row1.pet.element1, ElementType.water);
      expect(row1.pet.element2, ElementType.fire);
      expect(row1.petNormalDamage, 90);
      expect(row1.petCritDamage, 135);
      expect(row1.meanPoints, 2000);
      expect(row1.meanRunSeconds, 40.0);
      expect(row1.pointsPerSecond, closeTo(50.0, 1e-9));
      expect(row1.lowestKnightSurvivalSeconds, 1.0);

      final row2 = rows[1];
      expect(row2.bossMode, 'blitz');
      expect(row2.fightMode, FightMode.durableRockShield);
      expect(row2.cycloneUseGemsForSpecials, isFalse);
    });

    test('raid rows respect only reachable imported pet skills', () {
      final importedRaidSetup = SetupSnapshot(
        bossMode: 'raid',
        bossLevel: 5,
        bossElements: const <ElementType>[ElementType.fire, ElementType.water],
        fightMode: FightMode.normal,
        knights: const <SetupKnightSnapshot>[
          SetupKnightSnapshot(
            atk: 59814,
            def: 74314,
            hp: 1876,
            stun: 25.0,
            elements: <ElementType>[ElementType.fire, ElementType.earth],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 66408,
            def: 79852,
            hp: 2049,
            stun: 0.0,
            elements: <ElementType>[ElementType.water, ElementType.water],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 76247,
            def: 62871,
            hp: 1796,
            stun: 12.0,
            elements: <ElementType>[ElementType.air, ElementType.air],
            active: false,
          ),
        ],
        pet: const SetupPetSnapshot(
          atk: 6583,
          element1: ElementType.water,
          element2: ElementType.fire,
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
              runtimeSupport: 'normal_only',
              simulatorModes: <String>['normal'],
              effectSpec: <String, Object?>{},
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
      final run = BulkSimulationRunResult(
        slot: 1,
        setup: importedRaidSetup,
        pre: precomputed(raidMode: true, level: 5),
        stats: statsWithTiming(mean: 2000, runSeconds: 40),
        shatter: null,
      );

      final row = BulkComparisonRow.fromRun(run);

      expect(row.fightMode, FightMode.normal);
    });

    test('blitz rows also respect only reachable imported pet skills', () {
      final importedBlitzSetup = SetupSnapshot(
        bossMode: 'blitz',
        bossLevel: 5,
        bossElements: const <ElementType>[ElementType.fire, ElementType.water],
        fightMode: FightMode.normal,
        knights: const <SetupKnightSnapshot>[
          SetupKnightSnapshot(
            atk: 59814,
            def: 74314,
            hp: 1876,
            stun: 25.0,
            elements: <ElementType>[ElementType.fire, ElementType.earth],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 66408,
            def: 79852,
            hp: 2049,
            stun: 0.0,
            elements: <ElementType>[ElementType.water, ElementType.water],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 76247,
            def: 62871,
            hp: 1796,
            stun: 12.0,
            elements: <ElementType>[ElementType.air, ElementType.air],
            active: false,
          ),
        ],
        pet: const SetupPetSnapshot(
          atk: 6583,
          element1: ElementType.water,
          element2: ElementType.fire,
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
              runtimeSupport: 'normal_only',
              simulatorModes: <String>['normal'],
              effectSpec: <String, Object?>{},
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
      final run = BulkSimulationRunResult(
        slot: 1,
        setup: importedBlitzSetup,
        pre: precomputed(raidMode: false, level: 5),
        stats: statsWithTiming(mean: 2000, runSeconds: 40),
        shatter: null,
      );

      final row = BulkComparisonRow.fromRun(run);

      expect(row.fightMode, FightMode.normal);
    });
  });
}
