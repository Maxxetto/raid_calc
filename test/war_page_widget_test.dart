import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/ui/war_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('War page renders sections using split-backed ConfigLoader',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WarPage(),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('War calculator'), findsOneWidget);
    expect(find.byKey(const Key('war-calculator-tip-button')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('war-elixirs-tip-button')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('war-elixirs-tip-button')), findsOneWidget);
    expect(find.byKey(const Key('war-results-tip-button')), findsOneWidget);
  });

  testWidgets('War page shows PA strategy controls when PA is enabled',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WarPage(),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byType(Switch).last);
    await tester.pumpAndSettle();

    expect(find.text('PA strategy'), findsOneWidget);
    expect(find.text('Optimized mix'), findsWidgets);
  });

  testWidgets('War page can switch to raid guild planner mode',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WarPage(isPremium: true),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const ValueKey('app-shortcuts-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('war-mode-toggle-menu-item')));
    await tester.pumpAndSettle();

    expect(find.text('Raid guild planner'), findsOneWidget);
    expect(find.text('Simple estimate'), findsOneWidget);
    expect(find.text('Fastest path'), findsOneWidget);
    expect(find.byKey(const Key('raid-guild-tip-button')), findsOneWidget);
  });

  testWidgets('Free users do not see raid guild planner in quick actions',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WarPage(),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const ValueKey('app-shortcuts-menu')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('war-mode-toggle-menu-item')), findsNothing);
    expect(find.text('Open Raid planner'), findsNothing);
  });

  testWidgets('Raid guild planner can copy an export payload',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WarPage(isPremium: true),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.tap(find.byKey(const ValueKey('app-shortcuts-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('war-mode-toggle-menu-item')));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.copy_all_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Raid planner export copied'), findsOneWidget);
  });
}
