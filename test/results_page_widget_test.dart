import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/battle_outcome.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:raid_calc/data/setup_models.dart';
import 'package:raid_calc/ui/results_page.dart';

Precomputed _buildPrecomputed() {
  final meta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const [1.0, 1.0, 1.0],
    evasionChance: 0.1,
    criticalChance: 0.05,
    criticalMultiplier: 1.5,
    raidSpecialMultiplier: 3.25,
    hitsToFirstShatter: 7,
    hitsToNextShatter: 13,
    knightToSpecial: 5,
    bossToSpecial: 7,
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
    timing: const TimingConfig(
      normalDuration: 0.4,
      specialDuration: 0.6,
      stunDuration: 0.2,
      missDuration: 0.3,
      bossDuration: 0.4,
      bossSpecialDuration: 0.7,
    ),
  );

  final stats = const BossStats(attack: 1000, defense: 2000, hp: 3000);

  return Precomputed(
    meta: meta,
    stats: stats,
    kAtk: const [1000, 1100, 1200],
    kDef: const [500, 600, 700],
    kHp: const [1000, 1000, 1000],
    kAdv: const [1.0, 1.0, 1.0],
    kStun: const [0.1, 0.1, 0.1],
    kNormalDmg: const [100, 110, 120],
    kCritDmg: const [150, 165, 180],
    kSpecialDmg: const [300, 330, 360],
    bNormalDmg: const [80, 90, 100],
    bCritDmg: const [120, 135, 150],
  );
}

Precomputed _buildShatterPetBarPrecomputed() {
  final meta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const [1.0, 1.0, 1.0],
    evasionChance: 0.1,
    criticalChance: 0.05,
    criticalMultiplier: 1.5,
    raidSpecialMultiplier: 3.25,
    hitsToFirstShatter: 7,
    hitsToNextShatter: 13,
    knightToSpecial: 5,
    bossToSpecial: 7,
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
    timing: const TimingConfig(
      normalDuration: 0.4,
      specialDuration: 0.6,
      stunDuration: 0.2,
      missDuration: 0.3,
      bossDuration: 0.4,
      bossSpecialDuration: 0.7,
    ),
    petTicksBar: const PetTicksBarConfig(
      enabled: true,
      useInShatterShield: true,
    ),
  );

  return Precomputed(
    meta: meta,
    stats: const BossStats(attack: 1000, defense: 2000, hp: 3000),
    kAtk: const [1000, 1100, 1200],
    kDef: const [500, 600, 700],
    kHp: const [1000, 1000, 1000],
    kAdv: const [1.0, 1.0, 1.0],
    kStun: const [0.1, 0.1, 0.1],
    kNormalDmg: const [100, 110, 120],
    kCritDmg: const [150, 165, 180],
    kSpecialDmg: const [300, 330, 360],
    bNormalDmg: const [80, 90, 100],
    bCritDmg: const [120, 135, 150],
  );
}

Precomputed _buildSrEwPetBarPrecomputed() {
  final meta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const [1.0, 1.0, 1.0],
    evasionChance: 0.1,
    criticalChance: 0.05,
    criticalMultiplier: 1.5,
    raidSpecialMultiplier: 3.25,
    hitsToFirstShatter: 7,
    hitsToNextShatter: 13,
    knightToSpecial: 5,
    bossToSpecial: 7,
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
    timing: const TimingConfig(
      normalDuration: 0.4,
      specialDuration: 0.6,
      stunDuration: 0.2,
      missDuration: 0.3,
      bossDuration: 0.4,
      bossSpecialDuration: 0.7,
    ),
    petTicksBar: const PetTicksBarConfig(
      enabled: true,
      useInSpecialRegenPlusEw: true,
    ),
  );

  return Precomputed(
    meta: meta,
    stats: const BossStats(attack: 1000, defense: 2000, hp: 3000),
    kAtk: const [1000, 1100, 1200],
    kDef: const [500, 600, 700],
    kHp: const [1000, 1000, 1000],
    kAdv: const [1.0, 1.0, 1.0],
    kStun: const [0.1, 0.1, 0.1],
    kNormalDmg: const [100, 110, 120],
    kCritDmg: const [150, 165, 180],
    kSpecialDmg: const [300, 330, 360],
    bNormalDmg: const [80, 90, 100],
    bCritDmg: const [120, 135, 150],
  );
}

Precomputed _buildDrsPetBarPrecomputed() {
  final meta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const [1.0, 1.0, 1.0],
    evasionChance: 0.1,
    criticalChance: 0.05,
    criticalMultiplier: 1.5,
    raidSpecialMultiplier: 3.25,
    hitsToFirstShatter: 7,
    hitsToNextShatter: 13,
    knightToSpecial: 5,
    bossToSpecial: 7,
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
    timing: const TimingConfig(
      normalDuration: 0.4,
      specialDuration: 0.6,
      stunDuration: 0.2,
      missDuration: 0.3,
      bossDuration: 0.4,
      bossSpecialDuration: 0.7,
    ),
    petTicksBar: const PetTicksBarConfig(
      enabled: true,
      useInDurableRockShield: true,
    ),
  );

  return Precomputed(
    meta: meta,
    stats: const BossStats(attack: 1000, defense: 2000, hp: 3000),
    kAtk: const [1000, 1100, 1200],
    kDef: const [500, 600, 700],
    kHp: const [1000, 1000, 1000],
    kAdv: const [1.0, 1.0, 1.0],
    kStun: const [0.1, 0.1, 0.1],
    petSkillUsage: PetSkillUsageMode.cycleSpecial1Then2,
    kNormalDmg: const [100, 110, 120],
    kCritDmg: const [150, 165, 180],
    kSpecialDmg: const [300, 330, 360],
    bNormalDmg: const [80, 90, 100],
    bCritDmg: const [120, 135, 150],
  );
}

Finder _verticalScrollable() => find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up),
      description: 'vertical Scrollable',
    );

Future<void> _expandTileByKey(
  WidgetTester tester,
  ValueKey<String> tileKey,
) async {
  await tester.binding.setSurfaceSize(const Size(1200, 5000));
  await tester.pumpAndSettle();
  final containerFinder = find.byKey(tileKey);
  if (containerFinder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      containerFinder,
      180,
      scrollable: _verticalScrollable().first,
    );
  }
  final container = containerFinder.first;
  await tester.ensureVisible(container);
  await tester.pumpAndSettle();
  final target =
      find.descendant(of: container, matching: find.byType(ListTile)).first;
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _expandPetDetails(WidgetTester tester) => _expandTileByKey(
      tester,
      const ValueKey('results.advanced.tile.pet_details'),
    );

Future<void> _expandFightDurationDetails(WidgetTester tester) =>
    _expandTileByKey(
      tester,
      const ValueKey('results.advanced.tile.duration'),
    );

void main() {
  testWidgets('Results page toggles graph view without replacing tables',
      (tester) async {
    final pre = _buildPrecomputed();
    const stats = SimStats(
      mean: 100,
      median: 98,
      min: 90,
      max: 110,
      series: SimulationSeries(
        checkpointEvery: 500,
        totalRuns: 1000,
        checkpoints: <SimulationCheckpoint>[
          SimulationCheckpoint(
            runIndex: 500,
            cumulativeMean: 96,
            cumulativeMin: 90,
            cumulativeMax: 108,
          ),
          SimulationCheckpoint(
            runIndex: 1000,
            cumulativeMean: 100,
            cumulativeMin: 90,
            cumulativeMax: 110,
          ),
        ],
        histogram: SimulationHistogram(
          bins: <SimulationHistogramBin>[
            SimulationHistogramBin(
              lowerBound: 90,
              upperBound: 94,
              count: 180,
            ),
            SimulationHistogramBin(
              lowerBound: 95,
              upperBound: 99,
              count: 320,
            ),
            SimulationHistogramBin(
              lowerBound: 100,
              upperBound: 104,
              count: 340,
            ),
            SimulationHistogramBin(
              lowerBound: 105,
              upperBound: 110,
              count: 160,
            ),
          ],
        ),
      ),
      timing: TimingStats(
        meanRunSeconds: 10,
        meanBossSeconds: 3,
        meanKnightSeconds: [1, 1, 1],
        meanSurvivalSeconds: [1, 1, 1],
        kNormalCount: [1.2, 1.0, 0.8],
        kNormalSeconds: [1.2, 1.0, 0.9],
        kSpecialCount: [0.4, 0.3, 0.2],
        kSpecialSeconds: [0.8, 0.7, 0.6],
        kStunCount: [0, 0, 0],
        kStunSeconds: [0.1, 0.0, 0.2],
        kMissCount: [0, 0, 0],
        kMissSeconds: [0.1, 0.1, 0.1],
        bNormalCount: [0, 0, 0],
        bNormalSeconds: [0, 0, 0],
        bSpecialCount: [0, 0, 0],
        bSpecialSeconds: [0, 0, 0],
        bMissCount: [0, 0, 0],
        bMissSeconds: [0, 0, 0],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: true,
          debugEnabled: false,
          fightMode: FightMode.normal,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('results.chart.score_summary')),
        findsNothing);
    expect(
        find.byKey(const ValueKey('results.chart.run_pacing')), findsNothing);
    expect(find.text('Stats'), findsOneWidget);

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('results.chart.score_summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.convergence')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.histogram')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.exceedance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.exceedance.targets')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.exceedance.percentiles')),
      findsOneWidget,
    );
    expect(find.textContaining('P50'), findsOneWidget);

    await _expandPetDetails(tester);
    expect(
      find.byKey(const ValueKey('results.chart.pet_impact')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('results.chart.knight_outgoing')),
      180,
      scrollable: _verticalScrollable().first,
    );

    expect(
      find.byKey(const ValueKey('results.chart.knight_outgoing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_contribution')),
      findsOneWidget,
    );

    await _expandFightDurationDetails(tester);

    expect(
      find.byKey(const ValueKey('results.chart.timing_breakdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.run_pacing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.survival_pressure')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_time_share')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_efficiency')),
      findsOneWidget,
    );
  });

  testWidgets(
      'Non-premium graph view keeps score charts and hides timing charts',
      (tester) async {
    final pre = _buildPrecomputed();
    const stats = SimStats(
      mean: 100,
      median: 98,
      min: 90,
      max: 110,
      series: SimulationSeries(
        checkpointEvery: 500,
        totalRuns: 1000,
        checkpoints: <SimulationCheckpoint>[
          SimulationCheckpoint(
            runIndex: 500,
            cumulativeMean: 96,
            cumulativeMin: 90,
            cumulativeMax: 108,
          ),
          SimulationCheckpoint(
            runIndex: 1000,
            cumulativeMean: 100,
            cumulativeMin: 90,
            cumulativeMax: 110,
          ),
        ],
        histogram: SimulationHistogram(
          bins: <SimulationHistogramBin>[
            SimulationHistogramBin(
              lowerBound: 90,
              upperBound: 94,
              count: 180,
            ),
            SimulationHistogramBin(
              lowerBound: 95,
              upperBound: 99,
              count: 320,
            ),
            SimulationHistogramBin(
              lowerBound: 100,
              upperBound: 104,
              count: 340,
            ),
            SimulationHistogramBin(
              lowerBound: 105,
              upperBound: 110,
              count: 160,
            ),
          ],
        ),
      ),
      timing: TimingStats(
        meanRunSeconds: 10,
        meanBossSeconds: 3,
        meanKnightSeconds: [1, 1, 1],
        meanSurvivalSeconds: [1, 1, 1],
        kNormalCount: [1.2, 1.0, 0.8],
        kNormalSeconds: [1.2, 1.0, 0.9],
        kSpecialCount: [0.4, 0.3, 0.2],
        kSpecialSeconds: [0.8, 0.7, 0.6],
        kStunCount: [0, 0, 0],
        kStunSeconds: [0.1, 0.0, 0.2],
        kMissCount: [0, 0, 0],
        kMissSeconds: [0.1, 0.1, 0.1],
        bNormalCount: [0, 0, 0],
        bNormalSeconds: [0, 0, 0],
        bSpecialCount: [0, 0, 0],
        bSpecialSeconds: [0, 0, 0],
        bMissCount: [0, 0, 0],
        bMissSeconds: [0, 0, 0],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.normal,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('results.chart.score_summary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.convergence')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.histogram')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.exceedance')),
      findsOneWidget,
    );

    await _expandPetDetails(tester);
    expect(
      find.byKey(const ValueKey('results.chart.pet_impact')),
      findsNothing,
    );

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('results.chart.knight_outgoing')),
      180,
      scrollable: _verticalScrollable().first,
    );

    expect(
      find.byKey(const ValueKey('results.chart.knight_outgoing')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_incoming')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_contribution')),
      findsNothing,
    );

    await _expandFightDurationDetails(tester);

    expect(
      find.byKey(const ValueKey('results.chart.run_pacing')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.chart.survival_pressure')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_time_share')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_efficiency')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.chart.timing_breakdown')),
      findsNothing,
    );
    expect(
      find.textContaining('available with Premium only'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Timing data is unavailable for this result set.'),
      findsNothing,
    );
  });

  testWidgets(
      'Premium graph view shows neutral timing state when timing is missing',
      (tester) async {
    final pre = _buildPrecomputed();
    const stats = SimStats(
      mean: 100,
      median: 98,
      min: 90,
      max: 110,
      timing: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: true,
          debugEnabled: false,
          fightMode: FightMode.normal,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    await _expandFightDurationDetails(tester);

    expect(
      find.byKey(const ValueKey('results.chart.run_pacing')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.chart.survival_pressure')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_time_share')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_efficiency')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('results.chart.timing_breakdown')),
      findsNothing,
    );
    expect(
      find.textContaining('Timing data is unavailable for this result set.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('available with Premium only'),
      findsNothing,
    );
  });

  testWidgets('Knight charts switch between bars and histogram views',
      (tester) async {
    final pre = _buildPrecomputed();
    const stats = SimStats(
      mean: 100,
      median: 98,
      min: 90,
      max: 110,
      timing: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.normal,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('results.chart.knight_outgoing')),
      180,
      scrollable: _verticalScrollable().first,
    );

    expect(
      find.byKey(const ValueKey('results.chart.knight_outgoing.bars')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('results.chart.knight_incoming.bars')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(
          const ValueKey('results.chart.knight_outgoing.toggle.histogram')),
      80,
      scrollable: _verticalScrollable().first,
    );
    tester
        .widget<ChoiceChip>(
          find.byKey(
              const ValueKey('results.chart.knight_outgoing.toggle.histogram')),
        )
        .onSelected!(true);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('results.chart.knight_outgoing.histogram')),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.byKey(
          const ValueKey('results.chart.knight_incoming.toggle.histogram')),
      80,
      scrollable: _verticalScrollable().first,
    );
    tester
        .widget<ChoiceChip>(
          find.byKey(
              const ValueKey('results.chart.knight_incoming.toggle.histogram')),
        )
        .onSelected!(true);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('results.chart.knight_incoming.histogram')),
      findsOneWidget,
    );
  });

  testWidgets('Results chart help opens explanatory dialog', (tester) async {
    final pre = _buildPrecomputed();
    const stats = SimStats(
      mean: 100,
      median: 98,
      min: 90,
      max: 110,
      series: SimulationSeries(
        checkpointEvery: 500,
        totalRuns: 1000,
        checkpoints: <SimulationCheckpoint>[
          SimulationCheckpoint(
            runIndex: 500,
            cumulativeMean: 96,
            cumulativeMin: 90,
            cumulativeMax: 108,
          ),
          SimulationCheckpoint(
            runIndex: 1000,
            cumulativeMean: 100,
            cumulativeMin: 90,
            cumulativeMax: 110,
          ),
        ],
      ),
      timing: null,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: true,
          debugEnabled: false,
          fightMode: FightMode.normal,
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final helpButton = find.descendant(
      of: find.byKey(const ValueKey('results.chart.score_summary')),
      matching: find.byIcon(Icons.help_outline),
    );
    expect(helpButton, findsOneWidget);

    await tester.ensureVisible(helpButton);
    await tester.pumpAndSettle();
    await tester.tap(helpButton, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Shows the spread of outcomes'),
      findsOneWidget,
    );
  });

  testWidgets('Results page shows summary line with skills and flags',
      (tester) async {
    final pre = _buildPrecomputed();
    const stats =
        SimStats(mean: 100, median: 100, min: 90, max: 110, timing: null);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: true,
          debugEnabled: true,
          fightMode: FightMode.shatterShield,
          cycloneUseGemsForSpecials: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Simulation Report'), findsWidgets);
    expect(find.text('Performance Summary'), findsOneWidget);
    expect(find.textContaining('Raid Boss'), findsWidgets);
    expect(find.textContaining('Premium'), findsWidgets);
    expect(find.textContaining('Debug'), findsWidgets);
    expect(find.textContaining('No pet skills selected'), findsWidgets);
    expect(find.text('Boss Context'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Advanced Details'),
      240,
      scrollable: _verticalScrollable().first,
    );
    expect(find.text('Advanced Details'), findsOneWidget);
    await _expandPetDetails(tester);
    expect(find.text('Pet & Skills'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('results.knight.card.0')),
      160,
      scrollable: _verticalScrollable().first,
    );
    expect(find.byKey(const ValueKey('results.knight.card.0')), findsOneWidget);
    expect(find.byKey(const ValueKey('results.knight.card.1')), findsOneWidget);
    expect(find.byKey(const ValueKey('results.knight.card.2')), findsOneWidget);
    expect(find.text('Loadout'), findsWidgets);
    expect(find.text('Damage to boss'), findsWidgets);
    expect(find.text('Damage from boss'), findsWidgets);
    expect(find.text('Pet ATK'), findsWidgets);
    expect(find.text('Normal damage'), findsWidgets);
    expect(find.text('Crit damage'), findsWidgets);
  });

  testWidgets('Boss Context shows boss pressure values per knight',
      (tester) async {
    final pre = _buildPrecomputed();
    const stats =
        SimStats(mean: 100, median: 100, min: 90, max: 110, timing: null);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.normal,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Boss Context').first,
      80,
      scrollable: _verticalScrollable().first,
    );

    expect(find.text('Boss Context'), findsOneWidget);
    expect(find.text('Boss -> K (normal)'), findsWidgets);
    expect(find.text('Boss -> K (crit)'), findsWidgets);
    expect(find.text('Advantage'), findsWidgets);
  });

  testWidgets('Results page shows pet-bar shatter recap when enabled',
      (tester) async {
    final pre = _buildShatterPetBarPrecomputed();
    const stats =
        SimStats(mean: 100, median: 100, min: 90, max: 110, timing: null);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.shatterShield,
          cycloneUseGemsForSpecials: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Skill mechanics'), findsNothing);
    await _expandPetDetails(tester);

    expect(find.text('Starting bar'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Pet Special 2 (2/2)'), findsWidgets);
  });

  testWidgets('Results page shows pet-bar copy in SR + EW mode overview',
      (tester) async {
    final pre = _buildSrEwPetBarPrecomputed();
    const stats =
        SimStats(mean: 100, median: 100, min: 90, max: 110, timing: null);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.specialRegenPlusEw,
          cycloneUseGemsForSpecials: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _expandPetDetails(tester);
    expect(find.text('EW interval'), findsOneWidget);
    expect(find.text('pet Special 1 trigger'), findsOneWidget);
    expect(find.textContaining('Infinite special requirement'), findsWidgets);
  });

  testWidgets('Results page shows pet-bar copy for DRS when enabled',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 1800));
    final pre = _buildDrsPetBarPrecomputed();
    const stats =
        SimStats(mean: 100, median: 100, min: 90, max: 110, timing: null);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.durableRockShield,
          cycloneUseGemsForSpecials: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _expandPetDetails(tester);
    expect(find.textContaining('Pet bar cast sequence'), findsOneWidget);
    expect(find.textContaining('Activation interval'), findsNothing);

    addTearDown(() => tester.binding.setSurfaceSize(null));
  });

  testWidgets('Results page shows imported pet skills and values',
      (tester) async {
    final pre = _buildPrecomputed();
    const stats =
        SimStats(mean: 100, median: 100, min: 90, max: 110, timing: null);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.shatterShield,
          cycloneUseGemsForSpecials: false,
          importedPet: const SetupPetCompendiumImportSnapshot(
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
          petEffects: const <PetResolvedEffect>[
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
      ),
    );

    await tester.pumpAndSettle();

    await _expandPetDetails(tester);

    expect(find.text('Skill Slot 1'), findsWidgets);
    expect(find.text('Skill Slot 2'), findsWidgets);
    expect(find.textContaining('Revenge Strike'), findsWidgets);
    expect(find.textContaining('ATK cap 12.912'), findsWidgets);
    expect(find.textContaining('Shatter Shield'), findsWidgets);
    expect(find.textContaining('Base shield 178'), findsWidgets);
    expect(find.textContaining('Bonus shield 48'), findsWidgets);
    expect(find.text('Pet bar'), findsWidgets);
  });

  testWidgets('Results page shows manual pet skill overrides in the recap',
      (tester) async {
    final pre = _buildPrecomputed();
    const stats =
        SimStats(mean: 100, median: 100, min: 90, max: 110, timing: null);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.normal,
          selectedSkill1: const SetupPetSkillSnapshot(
            slotId: 'skill11',
            name: 'Elemental Weakness',
            values: <String, num>{
              'enemyAttackReductionPercent': 65,
              'turns': 2,
            },
            overrideValues: <String, num>{'turns': 3},
          ),
          selectedSkill2: const SetupPetSkillSnapshot(
            slotId: 'skill2',
            name: 'Ready to Crit',
            values: <String, num>{
              'critChancePercent': 100,
              'turns': 2,
            },
            overrideValues: <String, num>{'critChancePercent': 75},
          ),
          petEffects: const <PetResolvedEffect>[
            PetResolvedEffect(
              sourceSlotId: 'skill11',
              sourceSkillName: 'Elemental Weakness',
              values: <String, num>{
                'enemyAttackReductionPercent': 65,
                'turns': 3,
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
              sourceSkillName: 'Ready to Crit',
              values: <String, num>{
                'critChancePercent': 75,
                'turns': 2,
              },
              canonicalEffectId: 'ready_to_crit',
              canonicalName: 'Ready to Crit',
              effectCategory: 'crit_chance_buff',
              dataSupport: 'structured_values',
              runtimeSupport: 'normal_only',
              simulatorModes: <String>['normal'],
              effectSpec: <String, Object?>{},
            ),
          ],
        ),
      ),
    );

    await tester.pumpAndSettle();

    await _expandPetDetails(tester);

    expect(find.textContaining('Elemental Weakness'), findsWidgets);
    expect(find.textContaining('Boss ATK - 65'), findsWidgets);
    expect(find.textContaining('Turns 3'), findsWidgets);
    expect(find.textContaining('Ready to Crit'), findsWidgets);
    expect(find.textContaining('Crit + 75'), findsWidgets);
    expect(
      find.text('Uses the selected pet skills and pet bar sequence.'),
      findsWidgets,
    );
  });

  testWidgets('Cyclone timing values stay premium-only', (tester) async {
    final pre = _buildPrecomputed();
    const timingStats = SimStats(
      mean: 100,
      median: 100,
      min: 90,
      max: 110,
      timing: TimingStats(
        meanRunSeconds: 10,
        meanBossSeconds: 3,
        meanKnightSeconds: [1, 1, 1],
        meanSurvivalSeconds: [1, 1, 1],
        kNormalCount: [0, 0, 0],
        kNormalSeconds: [0, 0, 0],
        kSpecialCount: [1.5, 2.0, 0.5],
        kSpecialSeconds: [1, 1, 1],
        kStunCount: [0, 0, 0],
        kStunSeconds: [0, 0, 0],
        kMissCount: [0, 0, 0],
        kMissSeconds: [0, 0, 0],
        bNormalCount: [1, 1, 1],
        bNormalSeconds: [1, 1, 1],
        bSpecialCount: [0, 0, 0],
        bSpecialSeconds: [0, 0, 0],
        bMissCount: [0, 0, 0],
        bMissSeconds: [0, 0, 0],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: timingStats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.cycloneBoost,
          cycloneUseGemsForSpecials: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Average gems spent'), findsNothing);
    expect(find.text('Requires Premium timing'), findsNothing);
    expect(find.textContaining('expected on average'), findsNothing);
  });

  testWidgets('Milestone elixir timing boost is premium-only', (tester) async {
    final pre = _buildPrecomputed();
    const timingStats = SimStats(
      mean: 100,
      median: 100,
      min: 100,
      max: 100,
      timing: TimingStats(
        meanRunSeconds: 10,
        meanBossSeconds: 3,
        meanKnightSeconds: [1, 1, 1],
        meanSurvivalSeconds: [1, 1, 1],
        kNormalCount: [0, 0, 0],
        kNormalSeconds: [0, 0, 0],
        kSpecialCount: [0, 0, 0],
        kSpecialSeconds: [0, 0, 0],
        kStunCount: [0, 0, 0],
        kStunSeconds: [0, 0, 0],
        kMissCount: [0, 0, 0],
        kMissSeconds: [0, 0, 0],
        bNormalCount: [0, 0, 0],
        bNormalSeconds: [0, 0, 0],
        bSpecialCount: [0, 0, 0],
        bSpecialSeconds: [0, 0, 0],
        bMissCount: [0, 0, 0],
        bMissSeconds: [0, 0, 0],
      ),
    );
    const elixirs = <ElixirInventoryItem>[
      ElixirInventoryItem(
        name: 'Test',
        gamemode: 'Raid',
        scoreMultiplier: 0.5,
        durationMinutes: 10,
        quantity: 1,
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: timingStats,
          labels: const {},
          isPremium: false,
          debugEnabled: false,
          fightMode: FightMode.normal,
          milestoneTargetPoints: 1000,
          startEnergies: 0,
          freeRaidEnergies: 0,
          elixirs: elixirs,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('10/1'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: timingStats,
          labels: const {},
          isPremium: true,
          debugEnabled: false,
          fightMode: FightMode.normal,
          milestoneTargetPoints: 1000,
          startEnergies: 0,
          freeRaidEnergies: 0,
          elixirs: elixirs,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('7/1'), findsOneWidget);
  });

  testWidgets('Results page shows Cyclone average gems spent', (tester) async {
    final pre = _buildPrecomputed();
    const stats = SimStats(
      mean: 100,
      median: 100,
      min: 90,
      max: 110,
      timing: TimingStats(
        meanRunSeconds: 10,
        meanBossSeconds: 3,
        meanKnightSeconds: [1, 1, 1],
        meanSurvivalSeconds: [1, 1, 1],
        kNormalCount: [0, 0, 0],
        kNormalSeconds: [0, 0, 0],
        kSpecialCount: [1.5, 2.0, 0.5],
        kSpecialSeconds: [1, 1, 1],
        kStunCount: [0, 0, 0],
        kStunSeconds: [0, 0, 0],
        kMissCount: [0, 0, 0],
        kMissSeconds: [0, 0, 0],
        bNormalCount: [1, 1, 1],
        bNormalSeconds: [1, 1, 1],
        bSpecialCount: [0, 0, 0],
        bSpecialSeconds: [0, 0, 0],
        bMissCount: [0, 0, 0],
        bMissSeconds: [0, 0, 0],
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ResultsPage(
          pre: pre,
          knightIds: const ['K1', 'K2', 'K3'],
          stats: stats,
          labels: const {},
          isPremium: true,
          debugEnabled: false,
          fightMode: FightMode.cycloneBoost,
          cycloneUseGemsForSpecials: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Average gems spent'), findsWidgets);
    expect(find.text('16'), findsOneWidget);
    await _expandPetDetails(tester);
    await tester.scrollUntilVisible(
      find.text('Always gemmed: 4 gems per knight turn.'),
      140,
      scrollable: _verticalScrollable().first,
    );
    expect(find.text('Always gemmed: 4 gems per knight turn.'), findsWidgets);
  });
}
