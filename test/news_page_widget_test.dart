import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/data/events_loader.dart';
import 'package:raid_calc/ui/news_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    EventsLoader.clearCache();
  });

  testWidgets('manual shop inventory input does not reload the whole page',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewsPage(
          nowOverride: DateTime(2026, 3, 10),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final plannerFinder =
        find.byKey(const ValueKey('shop-planner-celestial_steed_2026_02'));
    expect(plannerFinder, findsOneWidget);

    await tester.ensureVisible(plannerFinder);
    await tester.pumpAndSettle();
    await tester.tap(plannerFinder);
    await tester.pumpAndSettle();

    final inventoryField =
        find.byKey(const ValueKey('shop-inventory-lunar_bell'));
    expect(inventoryField, findsOneWidget);

    await tester.ensureVisible(inventoryField);
    await tester.pumpAndSettle();
    await tester.tap(inventoryField);
    await tester.pump();

    await tester.enterText(inventoryField, '1');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<TextField>(inventoryField).controller?.text,
      '1',
    );

    await tester.enterText(inventoryField, '128');
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<TextField>(inventoryField).controller?.text,
      '128',
    );

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      tester.widget<TextField>(inventoryField).controller?.text,
      '128',
    );
  });
}
