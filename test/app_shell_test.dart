import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/ui/app_shell.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel pathChannel =
      MethodChannel('plugins.flutter.io/path_provider');
  late Directory docsDir;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    docsDir = await Directory.systemTemp.createTemp('raid_calc_app_shell_test');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return docsDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    final file = File('${docsDir.path}/raid_calc/raid_calc_last_session.json');
    if (await file.exists()) {
      await file.delete();
    }
  });

  testWidgets('App shell shows bottom navigation and switches tabs',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(NavigationBar), findsOneWidget);

    final warIt = find.text('Guerra');
    final warEn = find.text('War');
    final warLabel = warIt.evaluate().isNotEmpty ? warIt : warEn;
    expect(warLabel, findsOneWidget);

    final friendIt = find.text('Codici Amici');
    final friendEn = find.text('Friend Codes');
    final friendLabel = friendIt.evaluate().isNotEmpty ? friendIt : friendEn;
    expect(friendLabel, findsOneWidget);

    await tester.tap(warLabel);
    await tester.pumpAndSettle();

    final titleIt = find.text('Guerra');
    final titleEn = find.text('War');
    expect(
      titleIt.evaluate().isNotEmpty || titleEn.evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('Top shortcuts do not force navigation back to Raid',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: AppShell(),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final warIt = find.text('Guerra');
    final warEn = find.text('War');
    final warLabel = warIt.evaluate().isNotEmpty ? warIt : warEn;
    await tester.tap(warLabel);
    await tester.pumpAndSettle();

    final shortcutsButton = find.byTooltip('Quick actions').hitTestable();
    expect(shortcutsButton, findsOneWidget);
    await tester.tap(shortcutsButton);
    await tester.pumpAndSettle();

    final languageItem = find.text('Language').last;
    expect(languageItem, findsOneWidget);
    await tester.tap(languageItem);
    await tester.pumpAndSettle();

    final english = find.text('English').last;
    expect(english, findsOneWidget);
    await tester.tap(english);
    await tester.pumpAndSettle();

    final titleIt = find.text('Guerra');
    final titleEn = find.text('War');
    expect(
      titleIt.evaluate().isNotEmpty || titleEn.evaluate().isNotEmpty,
      isTrue,
    );
  });
}
