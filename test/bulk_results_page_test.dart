import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/battle_outcome.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/bulk_results_models.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/setup_models.dart';
import 'package:raid_calc/ui/bulk_results_page.dart';

void main() {
  TimingConfig _timingCfg() => const TimingConfig(
        normalDuration: 0.4,
        specialDuration: 0.6,
        stunDuration: 0.2,
        missDuration: 0.3,
        bossDuration: 0.4,
        bossSpecialDuration: 0.7,
      );

  BossMeta _bossMeta({required bool raid, required int level}) => BossMeta(
        raidMode: raid,
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
        timing: _timingCfg(),
      );

  Precomputed _pre({required bool raid, required int level}) => Precomputed(
        meta: _bossMeta(raid: raid, level: level),
        stats: const BossStats(attack: 1000, defense: 1000, hp: 100000),
        kAtk: const <double>[1000, 2000],
        kDef: const <double>[900, 1800],
        kHp: const <int>[1500, 1600],
        kAdv: const <double>[1.0, 1.5],
        kStun: const <double>[0.1, 0.2],
        petAtk: 500,
        petAdv: 1.0,
        kNormalDmg: const <int>[100, 200],
        kCritDmg: const <int>[150, 300],
        kSpecialDmg: const <int>[180, 360],
        petNormalDmg: 50,
        petCritDmg: 75,
        bNormalDmg: const <int>[20, 30],
        bCritDmg: const <int>[30, 45],
      );

  SimStats _stats({required int mean, double? runSeconds}) => SimStats(
        mean: mean,
        median: mean,
        min: mean - 100,
        max: mean + 100,
        series: SimulationSeries(
          checkpointEvery: 500,
          totalRuns: 1000,
          checkpoints: <SimulationCheckpoint>[
            SimulationCheckpoint(
              runIndex: 500,
              cumulativeMean: mean - 20,
              cumulativeMin: mean - 100,
              cumulativeMax: mean + 80,
            ),
            SimulationCheckpoint(
              runIndex: 1000,
              cumulativeMean: mean,
              cumulativeMin: mean - 100,
              cumulativeMax: mean + 100,
            ),
          ],
          histogram: SimulationHistogram(
            bins: <SimulationHistogramBin>[
              SimulationHistogramBin(
                lowerBound: mean - 100,
                upperBound: mean - 50,
                count: 180,
              ),
              SimulationHistogramBin(
                lowerBound: mean - 49,
                upperBound: mean,
                count: 420,
              ),
              SimulationHistogramBin(
                lowerBound: mean + 1,
                upperBound: mean + 50,
                count: 280,
              ),
              SimulationHistogramBin(
                lowerBound: mean + 51,
                upperBound: mean + 100,
                count: 120,
              ),
            ],
          ),
        ),
        timing: runSeconds == null
            ? null
            : TimingStats(
                meanRunSeconds: runSeconds,
                meanBossSeconds: 5,
                meanKnightSeconds: const <double>[1, 1],
                meanSurvivalSeconds: const <double>[1, 1],
                kNormalCount: const <double>[1, 1],
                kNormalSeconds: const <double>[1, 1],
                kSpecialCount: const <double>[1, 1],
                kSpecialSeconds: const <double>[1, 1],
                kStunCount: const <double>[1, 1],
                kStunSeconds: const <double>[1, 1],
                kMissCount: const <double>[1, 1],
                kMissSeconds: const <double>[1, 1],
                bNormalCount: const <double>[1, 1],
                bNormalSeconds: const <double>[1, 1],
                bSpecialCount: const <double>[1, 1],
                bSpecialSeconds: const <double>[1, 1],
                bMissCount: const <double>[1, 1],
                bMissSeconds: const <double>[1, 1],
              ),
      );

  SetupSnapshot _setup({
    required String bossMode,
    required int level,
    required FightMode mode,
  }) =>
      SetupSnapshot(
        bossMode: bossMode,
        bossLevel: level,
        bossElements: const <ElementType>[ElementType.fire, ElementType.water],
        fightMode: mode,
        knights: const <SetupKnightSnapshot>[
          SetupKnightSnapshot(
            atk: 1000,
            def: 2000,
            hp: 1500,
            stun: 10,
            elements: <ElementType>[ElementType.fire, ElementType.air],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 1100,
            def: 2100,
            hp: 1600,
            stun: 20,
            elements: <ElementType>[ElementType.water, ElementType.water],
            active: true,
          ),
          SetupKnightSnapshot(
            atk: 1200,
            def: 2200,
            hp: 1700,
            stun: 0,
            elements: <ElementType>[ElementType.earth, ElementType.earth],
            active: false,
          ),
        ],
        pet: const SetupPetSnapshot(
          atk: 500,
          element1: ElementType.fire,
          element2: ElementType.water,
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

  BulkSimulationRunResult _run(
    int slot, {
    required bool raid,
    bool includeTiming = true,
    double? runSeconds,
  }) =>
      BulkSimulationRunResult(
        slot: slot,
        setup: _setup(
          bossMode: raid ? 'raid' : 'blitz',
          level: raid ? 4 : 3,
          mode: raid ? FightMode.normal : FightMode.durableRockShield,
        ),
        pre: _pre(raid: raid, level: raid ? 4 : 3),
        stats: _stats(
          mean: 1000 + (slot * 100),
          runSeconds:
              includeTiming ? (runSeconds ?? (20 + slot.toDouble())) : null,
        ),
        shatter: null,
        completedAt: DateTime.utc(2026, 2, 22, 12, slot),
      );

  testWidgets('BulkResultsPage supports swipe to compare page', (tester) async {
    final batch = BulkSimulationBatchResult(runs: <BulkSimulationRunResult>[
      _run(1, raid: true),
      _run(2, raid: false),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: BulkResultsPage(
          batch: batch,
          labels: const {},
          isPremium: false,
          milestoneTargetPoints: 1000000000,
          startEnergies: 0,
          freeRaidEnergies: 30,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('(1/3)'), findsOneWidget);

    for (int i = 0; i < 4; i++) {
      if (find.textContaining('(3/3)').evaluate().isNotEmpty) break;
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
      await tester.pumpAndSettle();
    }

    expect(find.textContaining('(3/3)'), findsOneWidget);
    expect(find.text('Bulk Results Comparison'), findsOneWidget);
    expect(find.text('Points/second'), findsNothing);
    expect(find.text('Run time mean (s)'), findsNothing);
  });

  testWidgets('BulkResultsPage shows n+1 pages for 3 setups', (tester) async {
    final batch = BulkSimulationBatchResult(runs: <BulkSimulationRunResult>[
      _run(1, raid: true),
      _run(2, raid: false),
      _run(3, raid: true),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: BulkResultsPage(
          batch: batch,
          labels: const {},
          isPremium: true,
          milestoneTargetPoints: 1000000000,
          startEnergies: 0,
          freeRaidEnergies: 30,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('(1/4)'), findsOneWidget);
  });

  testWidgets('BulkResultsPage shows Bulk Frontier chart for premium compare',
      (tester) async {
    final batch = BulkSimulationBatchResult(runs: <BulkSimulationRunResult>[
      _run(1, raid: true),
      _run(2, raid: false),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: BulkResultsPage(
          batch: batch,
          labels: const {},
          isPremium: true,
          milestoneTargetPoints: 1000000000,
          startEnergies: 0,
          freeRaidEnergies: 30,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (int i = 0; i < 5; i++) {
      if (find
          .byKey(const ValueKey('results.bulk.chart.frontier'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
      await tester.pumpAndSettle();
    }

    expect(
      find.byKey(const ValueKey('results.bulk.chart.frontier')),
      findsOneWidget,
    );
    expect(find.text('Bulk Frontier'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('results.bulk.chart.timing')),
      findsOneWidget,
    );
    expect(find.text('Bulk Timing Snapshot'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('results.bulk.chart.time_efficiency')),
      findsOneWidget,
    );
    expect(find.text('Bulk Time Efficiency'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('results.bulk.chart.range')),
      findsOneWidget,
    );
    expect(find.text('Bulk Score Range'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('results.bulk.chart.percentiles')),
      findsOneWidget,
    );
    expect(find.text('Bulk Percentile Comparison'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('results.bulk.chart.target_chance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.bulk.chart.thresholds')),
      findsOneWidget,
    );
    expect(find.text('Bulk Threshold Chips'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('results.bulk.chart.distribution')),
      findsOneWidget,
    );
    expect(find.text('Bulk Distribution'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('results.bulk.chart.head_to_head')),
      findsOneWidget,
    );
    expect(find.text('Head-to-Head Delta'), findsOneWidget);
  });

  testWidgets(
      'Bulk premium compare hides timing charts when any setup lacks timing',
      (tester) async {
    final batch = BulkSimulationBatchResult(runs: <BulkSimulationRunResult>[
      _run(1, raid: true),
      _run(2, raid: false, includeTiming: false),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: BulkResultsPage(
          batch: batch,
          labels: const {},
          isPremium: true,
          milestoneTargetPoints: 1000000000,
          startEnergies: 0,
          freeRaidEnergies: 30,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (int i = 0; i < 5; i++) {
      if (find
          .byKey(const ValueKey('results.bulk.chart.range'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
      await tester.pumpAndSettle();
    }

    expect(
      find.byKey(const ValueKey('results.bulk.chart.frontier')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.bulk.chart.timing')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.bulk.chart.time_efficiency')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.bulk.chart.range')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.bulk.chart.percentiles')),
      findsOneWidget,
    );
    expect(find.text('Run time mean (s)'), findsWidgets);
    expect(find.text('Points/second'), findsWidgets);
  });

  testWidgets('Bulk compare shows head-to-head selectors for 3 setups',
      (tester) async {
    final batch = BulkSimulationBatchResult(runs: <BulkSimulationRunResult>[
      _run(1, raid: true),
      _run(2, raid: false),
      _run(3, raid: true),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: BulkResultsPage(
          batch: batch,
          labels: const {},
          isPremium: true,
          milestoneTargetPoints: 1000000000,
          startEnergies: 0,
          freeRaidEnergies: 30,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (int i = 0; i < 5; i++) {
      if (find
          .byKey(const ValueKey('results.bulk.compare.left_selector'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.fling(find.byType(PageView), const Offset(-600, 0), 1200);
      await tester.pumpAndSettle();
    }

    expect(
      find.byKey(const ValueKey('results.bulk.compare.left_selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.bulk.compare.right_selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.bulk.chart.head_to_head')),
      findsOneWidget,
    );
  });
}
