import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/ui/ua_planner_page.dart';
import 'package:raid_calc/util/i18n.dart';

Finder _monthCard(String monthKey) {
  return find.byKey(ValueKey<String>('ua_month_card_$monthKey'));
}

Finder _monthFinder(String monthKey, Finder inner) {
  return find.descendant(of: _monthCard(monthKey), matching: inner);
}

Finder _monthFieldChip(String monthKey, String fieldId) {
  return find.byKey(ValueKey<String>('ua_field_${monthKey}_$fieldId'));
}

Finder _monthBonusCheckbox(String monthKey, String bonusId) {
  return find.byKey(ValueKey<String>('ua_bonus_${monthKey}_$bonusId'));
}

Finder _monthClearButton(String monthKey) {
  return find.byKey(ValueKey<String>('ua_month_clear_$monthKey'));
}

Finder _monthCraftCheckbox(String monthKey, String craftId) {
  return find.byKey(ValueKey<String>('ua_craft_${monthKey}_$craftId'));
}

Future<void> _pumpUaPlanner(WidgetTester tester) async {
  await _pumpUaPlannerWithSize(tester, const Size(1080, 2400));
}

Future<void> _pumpUaPlannerWithSize(
  WidgetTester tester,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: UaPlannerPage(
        i18n: const I18n('en', <String, String>{}),
      ),
    ),
  );
}

Future<void> _scrollIntoView(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _openUaActions(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('app-shortcuts-menu')));
  await tester.pumpAndSettle();
}

void main() {
  const monthKey = '2025-11';

  testWidgets('UA planner tracks progress per month', (tester) async {
    await _pumpUaPlanner(tester);

    expect(find.text('UA Planner'), findsOneWidget);
    expect(find.textContaining('month by month'), findsOneWidget);
    expect(_monthCard(monthKey), findsOneWidget);

    await tester.tap(_monthFieldChip(monthKey, 'war'));
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Elite: Missing 10')),
      findsOneWidget,
    );
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 0')),
      findsOneWidget,
    );
  });

  testWidgets('UA planner shows extended range and cycle headers',
      (tester) async {
    await _pumpUaPlanner(tester);

    expect(find.text('UA Calendar'), findsOneWidget);
    expect(find.text('November 2025 - December 2028'), findsWidgets);
    expect(find.text('UA Cycle 15'), findsOneWidget);
    expect(find.text('November 2025 - March 2026'), findsOneWidget);
    expect(find.text('Cycle elements'), findsAtLeastNWidgets(1));
    expect(find.text('November 2025'), findsAtLeastNWidgets(1));
  });

  testWidgets('UA planner actions open calendar view', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String clipboardText = '';
    messenger.setMockMethodCallHandler(SystemChannels.platform,
        (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        final args = methodCall.arguments;
        if (args is Map && args['text'] is String) {
          clipboardText = args['text'] as String;
        }
        return null;
      }
      if (methodCall.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpUaPlanner(tester);

    await _openUaActions(tester);
    await tester.tap(find.byKey(const ValueKey('ua_planner_calendar_view')));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('ua_calendar_view_sheet')), findsOneWidget);
    expect(find.text('Calendar View'), findsOneWidget);
    expect(find.text('November 2025 - December 2028'), findsWidgets);
    expect(find.text('War Blitz'), findsWidgets);
    expect(find.text('Raid Blitz'), findsWidgets);
    expect(find.text('Blitz Arena'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('ua_calendar_year_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2028').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ua_calendar_month_filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('December').last);
    await tester.pumpAndSettle();

    final calendarSheet = find.byKey(const ValueKey('ua_calendar_view_sheet'));
    expect(
      find.descendant(of: calendarSheet, matching: find.text('December 2028')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: calendarSheet, matching: find.text('November 2025')),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await _openUaActions(tester);
    await tester.tap(find.byKey(const ValueKey('ua_planner_export_state')));
    await tester.pumpAndSettle();

    expect(clipboardText.contains('"calendarFilterYear":2028'), isTrue);
    expect(clipboardText.contains('"calendarFilterMonth":12'), isTrue);
  });

  testWidgets('Headstart and EB bonuses apply dependency rules',
      (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'headstart'));
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 0')),
      findsOneWidget,
    );
    expect(
      _monthFinder(monthKey, find.text('Crafted Elite+ of previous month')),
      findsOneWidget,
    );
    expect(
      _monthFinder(
          monthKey, find.text('Crafted Elite+ of previous two months')),
      findsOneWidget,
    );

    final secondHeadstartBonus =
        _monthBonusCheckbox(monthKey, 'headstart_prev_two_months');
    await _scrollIntoView(tester, secondHeadstartBonus);
    await tester.tap(secondHeadstartBonus);
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 0')),
      findsOneWidget,
    );

    final firstHeadstartBonus =
        _monthBonusCheckbox(monthKey, 'headstart_prev_month');
    await _scrollIntoView(tester, firstHeadstartBonus);
    await tester.tap(firstHeadstartBonus);
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );

    await _scrollIntoView(tester, secondHeadstartBonus);
    await tester.tap(secondHeadstartBonus);
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 2')),
      findsOneWidget,
    );

    final ebCollectionChip = _monthFieldChip(monthKey, 'eb_collection');
    await _scrollIntoView(tester, ebCollectionChip);
    await tester.tap(ebCollectionChip);
    await tester.pumpAndSettle();
    expect(
      _monthFinder(
          monthKey, find.text('Obtained T20 armor of the current month')),
      findsOneWidget,
    );
    expect(
      _monthFinder(
          monthKey, find.text('Obtained T20 armor of current and past month')),
      findsOneWidget,
    );

    final ebCurrentBonus = _monthBonusCheckbox(monthKey, 'eb_current_month');
    await _scrollIntoView(tester, ebCurrentBonus);
    await tester.tap(ebCurrentBonus);
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 3')),
      findsOneWidget,
    );

    final ebCurrentAndPast =
        _monthBonusCheckbox(monthKey, 'eb_current_and_past');
    await _scrollIntoView(tester, ebCurrentAndPast);
    await tester.tap(ebCurrentAndPast);
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 4')),
      findsOneWidget,
    );
  });

  testWidgets('Heroic uses per-date rows and piece count from selected dates',
      (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'heroic'));
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Heroic runs this month')),
      findsOneWidget,
    );
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 0')),
      findsOneWidget,
    );

    final firstHeroicCheckbox = _monthFinder(monthKey, find.byType(Checkbox));
    await tester.tap(firstHeroicCheckbox.first);
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );
  });

  testWidgets('Heroic April 14 survives partial restored state',
      (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String clipboardText = '';
    messenger.setMockMethodCallHandler(SystemChannels.platform,
        (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        final args = methodCall.arguments;
        if (args is Map && args['text'] is String) {
          clipboardText = args['text'] as String;
        }
        return null;
      }
      if (methodCall.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    const aprilKey = '2026-04';
    const heroicDateKey = '2026-04-14';
    final heroicCheckbox = _monthFinder(
      aprilKey,
      find.byKey(const ValueKey('ua_heroic_${aprilKey}_$heroicDateKey')),
    );

    await _pumpUaPlannerWithSize(tester, const Size(1080, 4200));
    await tester.pumpAndSettle();

    clipboardText =
        '{"kind":"ua_planner.state","v":1,"state":{"settings":{},"months":[{"monthKey":"$aprilKey","flags":{"heroic":false},"heroicFlags":{"$heroicDateKey":true}}]}}';
    await _openUaActions(tester);
    await tester.tap(find.byKey(const ValueKey('ua_planner_import_state')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const ValueKey('ua_planner_import_apply')));
    await tester.pumpAndSettle();

    await _scrollIntoView(tester, heroicCheckbox);
    expect(tester.widget<Checkbox>(heroicCheckbox).value, isTrue);
  });

  testWidgets('Raid rows compute pieces from score and placements',
      (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'raid'));
    await tester.pumpAndSettle();

    expect(_monthFinder(monthKey, find.text('Raid')), findsAtLeastNWidgets(1));
    expect(_monthFinder(monthKey, find.text('Score')), findsAtLeastNWidgets(1));
    expect(
      _monthFinder(monthKey, find.text('Total: +0')),
      findsAtLeastNWidgets(1),
    );

    final monthTextFields = _monthFinder(monthKey, find.byType(TextField));
    await tester.enterText(monthTextFields.at(0), '500');
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 2')),
      findsOneWidget,
    );
    expect(
      _monthFinder(monthKey, find.text('Total: +2')),
      findsAtLeastNWidgets(1),
    );

    await tester.enterText(monthTextFields.at(1), '1');
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 6')),
      findsOneWidget,
    );

    await tester.enterText(monthTextFields.at(2), '1');
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 10')),
      findsOneWidget,
    );
  });

  testWidgets('Raid Blitz applies score and individual placement rules',
      (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'raid_blitz'));
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.byType(DropdownButtonFormField<String>)),
      findsAtLeastNWidgets(1),
    );

    final monthTextFields = _monthFinder(monthKey, find.byType(TextField));
    await tester.enterText(monthTextFields.at(0), '8200000');
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );

    await tester.enterText(monthTextFields.at(1), '1');
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );

    await tester.enterText(monthTextFields.at(2), '1');
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 3')),
      findsOneWidget,
    );
  });

  testWidgets('War Blitz first blitz exception is applied', (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'war_blitz'));
    await tester.pumpAndSettle();

    final monthTextFields = _monthFinder(monthKey, find.byType(TextField));
    await tester.enterText(monthTextFields.at(0), '475');
    await tester.pumpAndSettle();
    await tester.enterText(monthTextFields.at(1), '1');
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 2')),
      findsOneWidget,
    );
  });

  testWidgets('Closing a field keeps its pieces counted and shows chip summary',
      (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    final raidChip = _monthFieldChip(monthKey, 'raid');
    await tester.tap(raidChip);
    await tester.pumpAndSettle();

    final monthTextFields = _monthFinder(monthKey, find.byType(TextField));
    await tester.enterText(monthTextFields.at(0), '500');
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 2')),
      findsOneWidget,
    );
    expect(_monthFinder(monthKey, find.text('Raid (+2)')), findsOneWidget);

    await tester.tap(raidChip);
    await tester.pumpAndSettle();

    expect(_monthFinder(monthKey, find.text('Raid (+2)')), findsOneWidget);
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 2')),
      findsOneWidget,
    );
    expect(_monthFinder(monthKey, find.text('Score')), findsNothing);
  });

  testWidgets('Clear month resets all toggles and rows', (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await tester.ensureVisible(clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'headstart'));
    await tester.pumpAndSettle();

    final firstHeadstartBonus =
        _monthBonusCheckbox(monthKey, 'headstart_prev_month');
    await _scrollIntoView(tester, firstHeadstartBonus);
    await tester.tap(firstHeadstartBonus);
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );

    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 0')),
      findsOneWidget,
    );
    expect(
      _monthFinder(monthKey, find.text('Crafted Elite+ of previous month')),
      findsNothing,
    );
  });

  testWidgets('Hidden month can be toggled and restored', (tester) async {
    await _pumpUaPlanner(tester);

    final hideButton = find.byKey(const ValueKey('ua_month_hidden_2025-11'));
    await _scrollIntoView(tester, hideButton);
    await tester.tap(hideButton);
    await tester.pumpAndSettle();

    expect(_monthCard(monthKey), findsNothing);

    final showHiddenSwitch =
        find.byKey(const ValueKey('ua_show_hidden_months'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2400));
    await tester.pumpAndSettle();
    expect(showHiddenSwitch, findsOneWidget);
    await tester.tap(showHiddenSwitch);
    await tester.pumpAndSettle();

    expect(_monthCard(monthKey), findsOneWidget);
    expect(_monthFinder(monthKey, find.text('Hidden')), findsOneWidget);

    await tester.tap(hideButton);
    await tester.pumpAndSettle();

    expect(_monthFinder(monthKey, find.text('Hidden')), findsNothing);
    expect(_monthFieldChip(monthKey, 'headstart'), findsOneWidget);
  });

  testWidgets('Hidden month remains counted in totals', (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'headstart'));
    await tester.pumpAndSettle();
    final firstHeadstartBonus =
        _monthBonusCheckbox(monthKey, 'headstart_prev_month');
    await _scrollIntoView(tester, firstHeadstartBonus);
    await tester.tap(firstHeadstartBonus);
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );

    final hideButton = find.byKey(const ValueKey('ua_month_hidden_2025-11'));
    await _scrollIntoView(tester, hideButton);
    await tester.tap(hideButton);
    await tester.pumpAndSettle();

    final showHiddenSwitch =
        find.byKey(const ValueKey('ua_show_hidden_months'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2400));
    await tester.pumpAndSettle();
    await tester.tap(showHiddenSwitch);
    await tester.pumpAndSettle();

    await _scrollIntoView(tester, _monthCard(monthKey));
    expect(
      _monthFinder(
        monthKey,
        find.text('Hidden month. Still counted in totals.'),
      ),
      findsOneWidget,
    );
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );
  });

  testWidgets('Hidden month card does not overflow on narrow screens',
      (tester) async {
    await _pumpUaPlannerWithSize(tester, const Size(351, 820));

    final hideButton = find.byKey(const ValueKey('ua_month_hidden_2025-11'));
    await _scrollIntoView(tester, hideButton);
    await tester.tap(hideButton);
    await tester.pumpAndSettle();

    final showHiddenSwitch =
        find.byKey(const ValueKey('ua_show_hidden_months'));
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 2400));
    await tester.pumpAndSettle();
    await tester.tap(showHiddenSwitch);
    await tester.pumpAndSettle();

    await _scrollIntoView(tester, _monthCard(monthKey));
    expect(_monthFinder(monthKey, find.text('November 2025')), findsOneWidget);
    expect(
      _monthFinder(
          monthKey, find.text('Hidden month. Still counted in totals.')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Planner lock prevents editing until unlocked', (tester) async {
    await _pumpUaPlanner(tester);

    await _openUaActions(tester);
    await tester.tap(find.byKey(const ValueKey('ua_planner_lock')));
    await tester.pumpAndSettle();

    expect(
      find.text('Planner is locked. Unlock to edit values.'),
      findsOneWidget,
    );

    await tester.tap(_monthFieldChip(monthKey, 'headstart'));
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Crafted Elite+ of previous month')),
      findsNothing,
    );

    await _openUaActions(tester);
    await tester.tap(find.byKey(const ValueKey('ua_planner_lock')));
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'headstart'));
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Crafted Elite+ of previous month')),
      findsOneWidget,
    );
  });

  testWidgets('Monthly craft recap unlocks and updates UA cycle progress',
      (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'raid'));
    await tester.pumpAndSettle();

    final monthTextFields = _monthFinder(monthKey, find.byType(TextField));
    await tester.enterText(monthTextFields.at(0), '500');
    await tester.pumpAndSettle();
    await tester.enterText(monthTextFields.at(1), '1');
    await tester.pumpAndSettle();
    await tester.enterText(monthTextFields.at(2), '1');
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 10')),
      findsOneWidget,
    );
    expect(
      _monthFinder(monthKey, find.text('Fire Elite crafted')),
      findsOneWidget,
    );

    final eliteCraft = _monthCraftCheckbox(monthKey, 'elite');
    await _scrollIntoView(tester, eliteCraft);
    await tester.tap(eliteCraft);
    await tester.pumpAndSettle();

    expect(find.text('UA progress: 1 / 5'), findsOneWidget);
    expect(find.text('UA 1/5'), findsOneWidget);
    expect(find.text('Missing 4'), findsAtLeastNWidgets(1));
  });

  testWidgets('First Blitz War special rewards appear at 350k and 475k',
      (tester) async {
    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'war_blitz'));
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('First Blitz War rewards')),
      findsAtLeastNWidgets(1),
    );

    final monthTextFields = _monthFinder(monthKey, find.byType(TextField));
    await tester.enterText(monthTextFields.at(0), '350');
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Elite ring')),
      findsAtLeastNWidgets(1),
    );
    expect(
      _monthFinder(monthKey, find.text('UA Eggs x5')),
      findsAtLeastNWidgets(1),
    );

    await tester.enterText(monthTextFields.at(0), '475');
    await tester.pumpAndSettle();

    expect(
      _monthFinder(monthKey, find.text('Elite amulet')),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('Planner tools can export and import state', (tester) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String clipboardText = '';
    messenger.setMockMethodCallHandler(SystemChannels.platform,
        (MethodCall methodCall) async {
      if (methodCall.method == 'Clipboard.setData') {
        final args = methodCall.arguments;
        if (args is Map && args['text'] is String) {
          clipboardText = args['text'] as String;
        }
        return null;
      }
      if (methodCall.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardText};
      }
      return null;
    });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await _pumpUaPlanner(tester);

    final clearButton = _monthClearButton(monthKey);
    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();

    await tester.tap(_monthFieldChip(monthKey, 'headstart'));
    await tester.pumpAndSettle();
    final firstHeadstartBonus =
        _monthBonusCheckbox(monthKey, 'headstart_prev_month');
    await _scrollIntoView(tester, firstHeadstartBonus);
    await tester.tap(firstHeadstartBonus);
    await tester.pumpAndSettle();
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );

    await _openUaActions(tester);
    await tester.tap(find.byKey(const ValueKey('ua_planner_export_state')));
    await tester.pumpAndSettle();

    final exported = await Clipboard.getData(Clipboard.kTextPlain);
    final exportedText = exported?.text ?? '';
    expect(exportedText.contains('"kind":"ua_planner.state"'), isTrue);

    await _scrollIntoView(tester, clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await _scrollIntoView(tester, _monthCard(monthKey));
    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 0')),
      findsOneWidget,
    );

    await Clipboard.setData(ClipboardData(text: exportedText));

    await _openUaActions(tester);
    await tester.tap(find.byKey(const ValueKey('ua_planner_import_state')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(
        find.byKey(const ValueKey('ua_planner_import_text')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ua_planner_import_apply')));
    await tester.pumpAndSettle();
    await _scrollIntoView(tester, _monthCard(monthKey));

    expect(
      _monthFinder(monthKey, find.text('Pieces this month: 1')),
      findsOneWidget,
    );
  });
}
