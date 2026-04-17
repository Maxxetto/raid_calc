import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/ui/epic_results_page.dart';

void main() {
  testWidgets('Epic results page summary shows the effective fight mode',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EpicResultsPage(
          knights: const <EpicKnightRow>[
            EpicKnightRow(
              id: 'K1',
              atk: 1000,
              def: 1000,
              hp: 1000,
              adv: 1.0,
              stun: 0.0,
            ),
          ],
          levels: const <EpicLevelRow>[
            EpicLevelRow(level: 1, missing: false, winRates: <double?>[1.0]),
          ],
          labels: const <String, String>{},
          threshold: 80,
          epicBonusPerExtraPct: 25.0,
          epicEffectiveBonusPct: 25.0,
          isPremium: true,
          debugEnabled: false,
          fightMode: FightMode.shatterShield,
          cycloneUseGemsForSpecials: false,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Shatter Shield'), findsWidgets);
  });
}
