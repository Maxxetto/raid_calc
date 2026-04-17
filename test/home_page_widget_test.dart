import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/data/last_session_storage.dart';
import 'package:raid_calc/data/pet_favorites_storage.dart';
import 'package:raid_calc/data/wargear_favorites_storage.dart';
import 'package:raid_calc/data/wargear_wardrobe_loader.dart';
import 'package:raid_calc/premium/premium_service.dart';
import 'package:raid_calc/ui/home_page.dart';
import 'package:raid_calc/ui/home/boss_section.dart';

late Directory _homePageWidgetDocsDir;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel pathChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() async {
    _homePageWidgetDocsDir =
        await Directory.systemTemp.createTemp('raid_calc_test');
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return _homePageWidgetDocsDir.path;
        }
        return null;
      },
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LastSessionStorage.clear();
  });

  testWidgets('Home page renders core sections', (tester) async {
    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byType(BossSection), findsOneWidget);
    expect(find.byKey(const ValueKey('app-shortcuts-menu')), findsOneWidget);

    final utilKey = find.byKey(const ValueKey('utility-elements'));
    await tester.scrollUntilVisible(
      utilKey,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    final utilIt = find.text('Utility');
    final utilEn = find.text('Utilities');
    expect(
        utilIt.evaluate().isNotEmpty || utilEn.evaluate().isNotEmpty, isTrue);

    final elementsIt = find.text('Tabella elementi');
    final elementsEn = find.text('Elements table');
    expect(
      elementsIt.evaluate().isNotEmpty || elementsEn.evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('Raid home can hide pet skill values and knight cards',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    var petToggle = find.byKey(const ValueKey('pet-skill-slot1-toggle-hidden'));
    if (petToggle.evaluate().isEmpty) {
      final skillDropdown = find.byKey(const ValueKey('pet-skill-slot1'));
      await tester.ensureVisible(skillDropdown);
      await tester.tap(skillDropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Shadow Slash').last);
      await tester.pumpAndSettle();
      petToggle = find.byKey(const ValueKey('pet-skill-slot1-toggle-hidden'));
    }

    await tester.ensureVisible(petToggle);
    await tester.tap(petToggle);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pet-skill-slot1-hidden-summary')),
      findsOneWidget,
    );

    final knightToggle = find.byKey(const ValueKey('knight-toggle-hidden-0'));
    await tester.ensureVisible(knightToggle);
    await tester.tap(knightToggle);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('knight-hidden-stats-0')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('knight-hidden-elements-0')),
      findsOneWidget,
    );
  });

  testWidgets('Utilities sheet opens elements table', (tester) async {
    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));
    await tester.drag(find.byType(ListView), const Offset(0, -1200));
    await tester.pumpAndSettle();

    final target = find.byKey(const ValueKey('utility-elements'));
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    final it = find.text('Tabella elementi');
    final en = find.text('Elements table');
    expect(it.evaluate().isNotEmpty || en.evaluate().isNotEmpty, isTrue);
  });

  testWidgets('Utilities boss stats sheet also shows Epic boss values',
      (tester) async {
    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final target = find.byKey(const ValueKey('utility-boss-stats'));
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('Boss stats'), findsWidgets);

    final epicMode = find.byKey(const ValueKey('boss-stats-mode-epic'));
    await tester.ensureVisible(epicMode);
    await tester.pumpAndSettle();
    await tester.tap(epicMode);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('711'), findsOneWidget);
    expect(find.text('1.815'), findsOneWidget);
  });

  testWidgets('Utilities can open app features help cards', (tester) async {
    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final target = find.byKey(const ValueKey('utility-app-features'));
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.text('App Features'), findsOneWidget);
    expect(find.text('Raid / Blitz Simulator'), findsOneWidget);
  });

  testWidgets('Utilities can open pet compendium', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final target = find.byKey(const ValueKey('utility-pet-compendium'));
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await _pumpUntilFound(tester, find.text('Pet Compendium'));

    expect(find.text('Pet Compendium'), findsOneWidget);
    expect(find.text('Vulpitier'), findsOneWidget);

    final applyPet = find.byKey(
      const ValueKey('pet-compendium-apply-vulpitier'),
    );
    await tester.scrollUntilVisible(
      applyPet,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(applyPet);
    await tester.pumpAndSettle();
    expect(applyPet, findsOneWidget);
  });

  testWidgets('Utilities can open wargear wardrobe and import armor into K1',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final target = find.byKey(const ValueKey('utility-wargear-wardrobe'));
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'storm',
    );
    await tester.pumpAndSettle();

    expect(find.text('Wargear Wardrobe'), findsWidgets);
    expect(find.text('Stormsea Hauberk'), findsOneWidget);
    expect(find.textContaining('Universal Armor Score'), findsNothing);

    final applyArmor =
        find.byKey(const ValueKey('wargear-apply-stormsea_hauberk'));
    await tester.ensureVisible(applyArmor);
    await tester.pumpAndSettle();
    await tester.tap(applyArmor);
    await _pumpUntilFound(
      tester,
      find.textContaining('Stormsea Hauberk imported into K#1.'),
    );

    expect(find.textContaining('Stormsea Hauberk imported into K#1.'),
        findsOneWidget);
    expect(find.textContaining('Universal Armor Score:'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    expect(find.text('71,232'), findsOneWidget);
    expect(find.text('59,506'), findsOneWidget);
    expect(find.text('1,994'), findsOneWidget);
  });

  testWidgets(
      'imported armor badges on knights can cycle role rank and version',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final target = find.byKey(const ValueKey('utility-wargear-wardrobe'));
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'stormsea hauberk',
    );
    await tester.pumpAndSettle();

    final applyArmor =
        find.byKey(const ValueKey('wargear-apply-stormsea_hauberk'));
    await tester.ensureVisible(applyArmor);
    await tester.tap(applyArmor);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('knight-armor-role-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('knight-armor-rank-0')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('knight-armor-version-0')), findsOneWidget);

    expect(find.text('71,232'), findsOneWidget);
    expect(find.text('59,506'), findsOneWidget);
    expect(find.text('1,994'), findsOneWidget);

    expect(find.text('Primary'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('knight-armor-role-0')));
    await tester.pumpAndSettle();
    expect(find.text('Secondary'), findsOneWidget);

    expect(find.text('Comm'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('knight-armor-rank-0')));
    await tester.pumpAndSettle();
    expect(find.text('HC'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('knight-armor-version-0')));
    await tester.pumpAndSettle();
    expect(find.text('Version: +'), findsOneWidget);
    expect(find.textContaining('Stormsea Hauberk +'), findsWidgets);
  });

  testWidgets(
      'premium users with 5 matching favorite armors can open Wardrobe Simulate confirm',
      (tester) async {
    final premium = DevPremiumService();
    await premium.setDevPremium(
      untilUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
    );
    final catalog = await WargearWardrobeLoader.load();
    await WargearFavoritesStorage.save(
      _idsForNames(catalog, <String>[
        'Stormsea Hauberk',
        'Glacierrun Panoply',
        'Riverborn Shell',
        'Aeroforge Sentinel',
        'TerraPulse Blaster',
      ]),
    );
    await PetFavoritesStorage.save(<String>{'vulpitier', 's101sf_ignitide'});

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final button = find.byKey(const ValueKey('wardrobe-simulate-button'));
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(button, findsOneWidget);
    await tester.tap(button);
    await tester.pumpAndSettle(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('wardrobe-simulate-confirm-button')),
        findsOneWidget);
    expect(find.text('Wardrobe Simulate'), findsWidgets);
    expect(find.textContaining('Runs per setup: 200'), findsOneWidget);
    expect(find.textContaining('Scenarios: 1.800'), findsOneWidget);
    expect(find.textContaining('Pet skill usage: 5'), findsOneWidget);
    expect(find.text('Breakdown by pet'), findsOneWidget);
    expect(find.textContaining('Top candidates'), findsWidgets);
  });

  testWidgets('free users do not see Wardrobe Simulate button', (tester) async {
    final premium = DevPremiumService();
    final catalog = await WargearWardrobeLoader.load();
    await WargearFavoritesStorage.save(
      _idsForNames(catalog, <String>[
        'Stormsea Hauberk',
        'Glacierrun Panoply',
        'Riverborn Shell',
        'Aeroforge Sentinel',
        'TerraPulse Blaster',
      ]),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(
        find.byKey(const ValueKey('wardrobe-simulate-button')), findsNothing);
  });

  testWidgets(
      'premium users do not see Wardrobe Simulate button without favorites requirements',
      (tester) async {
    final premium = DevPremiumService();
    await premium.setDevPremium(
      untilUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('wardrobe-simulate-button')), findsNothing);
  });

  testWidgets(
      'premium users see Wardrobe Simulate button with 5 armor favorites and 1 pet favorite',
      (tester) async {
    final premium = DevPremiumService();
    await premium.setDevPremium(
      untilUtc: DateTime.now().toUtc().add(const Duration(days: 3)),
    );
    final catalog = await WargearWardrobeLoader.load();
    await WargearFavoritesStorage.save(
      _idsForNames(catalog, <String>[
        'Stormsea Hauberk',
        'Glacierrun Panoply',
        'Riverborn Shell',
        'Aeroforge Sentinel',
        'TerraPulse Blaster',
      ]),
    );
    await PetFavoritesStorage.save(<String>{'vulpitier'});

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final button = find.byKey(const ValueKey('wardrobe-simulate-button'));
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(button, findsOneWidget);
  });

  testWidgets(
      'Armor import adds pet elemental bonus and shows imported base summary',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final petCompendium = find.byKey(const ValueKey('utility-pet-compendium'));
    await tester.scrollUntilVisible(
      petCompendium,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(petCompendium);
    await _pumpUntilFound(tester, find.text('Pet Compendium'));

    final petFiltersToggle =
        find.byKey(const ValueKey('pet-compendium-toggle-filters'));
    await tester.ensureVisible(petFiltersToggle);
    await tester.pumpAndSettle();
    await tester.tap(petFiltersToggle);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pet-compendium-search-field')),
      'ignitide',
    );
    await tester.pumpAndSettle();

    final applyPet =
        find.byKey(const ValueKey('pet-compendium-apply-s101sf_ignitide'));
    await _pumpUntilFound(tester, applyPet);
    await tester.ensureVisible(applyPet);
    await tester.pumpAndSettle();
    await tester.tap(applyPet);
    await tester.pumpAndSettle();

    final wardrobeButton =
        find.byKey(const ValueKey('utility-wargear-wardrobe'));
    await tester.scrollUntilVisible(
      wardrobeButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(wardrobeButton);
    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'storm',
    );
    await tester.pumpAndSettle();

    final applyArmor =
        find.byKey(const ValueKey('wargear-apply-stormsea_hauberk'));
    await tester.ensureVisible(applyArmor);
    await tester.pumpAndSettle();
    await tester.tap(applyArmor);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    expect(find.text('72,625'), findsOneWidget);
    expect(find.text('60,680'), findsOneWidget);
    expect(
      find.textContaining('Imported base armor as Stormsea Hauberk'),
      findsOneWidget,
    );
  });

  testWidgets('Recalculate armor reapplies current pet bonus to imported gear',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final petCompendium = find.byKey(const ValueKey('utility-pet-compendium'));
    await tester.scrollUntilVisible(
      petCompendium,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(petCompendium);
    await _pumpUntilFound(tester, find.text('Pet Compendium'));

    final petFiltersToggle =
        find.byKey(const ValueKey('pet-compendium-toggle-filters'));
    await tester.ensureVisible(petFiltersToggle);
    await tester.pumpAndSettle();
    await tester.tap(petFiltersToggle);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pet-compendium-search-field')),
      'ignitide',
    );
    await tester.pumpAndSettle();

    final applyPet =
        find.byKey(const ValueKey('pet-compendium-apply-s101sf_ignitide'));
    await _pumpUntilFound(tester, applyPet);
    await tester.ensureVisible(applyPet);
    await tester.pumpAndSettle();
    await tester.tap(applyPet);
    await tester.pumpAndSettle();

    final wardrobeButton =
        find.byKey(const ValueKey('utility-wargear-wardrobe'));
    await tester.scrollUntilVisible(
      wardrobeButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(wardrobeButton);
    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'storm',
    );
    await tester.pumpAndSettle();

    final applyArmor =
        find.byKey(const ValueKey('wargear-apply-stormsea_hauberk'));
    await tester.ensureVisible(applyArmor);
    await tester.pumpAndSettle();
    await tester.tap(applyArmor);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 2200));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('pet-elemental-atk-field')),
      '2000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('pet-elemental-def-field')),
      '3000',
    );
    await tester.pumpAndSettle();

    final recalcButton =
        find.byKey(const ValueKey('knight-recalculate-armor-0'));
    await tester.ensureVisible(recalcButton);
    await tester.pumpAndSettle();
    await tester.tap(recalcButton);
    await tester.pumpAndSettle();

    expect(find.text('73,232'), findsOneWidget);
    expect(find.text('62,506'), findsOneWidget);
  });

  testWidgets('Recalculate armor also uses the current guild element bonuses',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final wardrobeButton =
        find.byKey(const ValueKey('utility-wargear-wardrobe'));
    await tester.scrollUntilVisible(
      wardrobeButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(wardrobeButton);
    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'storm',
    );
    await tester.pumpAndSettle();

    final applyArmor =
        find.byKey(const ValueKey('wargear-apply-stormsea_hauberk'));
    await tester.ensureVisible(applyArmor);
    await tester.pumpAndSettle();
    await tester.tap(applyArmor);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    expect(find.text('71,232'), findsOneWidget);
    expect(find.text('59,506'), findsOneWidget);

    await tester.scrollUntilVisible(
      wardrobeButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(wardrobeButton);
    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));

    final waterGuildBonus =
        find.byKey(const ValueKey('wargear-guild-bonus-water'));
    await tester.ensureVisible(waterGuildBonus);
    await tester.pumpAndSettle();
    await tester.tap(waterGuildBonus);
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(24, 24));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 2200));
    await tester.pumpAndSettle();

    final recalcButton =
        find.byKey(const ValueKey('knight-recalculate-armor-0'));
    await tester.ensureVisible(recalcButton);
    await tester.pumpAndSettle();
    await tester.tap(recalcButton);
    await tester.pumpAndSettle();

    expect(find.text('59,360'), findsOneWidget);
    expect(find.text('49,589'), findsOneWidget);
  });

  testWidgets('Knight favorite armor shortcut can import a starred armor',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final wardrobeButton =
        find.byKey(const ValueKey('utility-wargear-wardrobe'));
    await tester.scrollUntilVisible(
      wardrobeButton,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(wardrobeButton);
    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));
    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'storm',
    );
    await tester.pumpAndSettle();
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('wargear-favorite-stormsea_hauberk')),
    );

    final favoriteArmor =
        find.byKey(const ValueKey('wargear-favorite-stormsea_hauberk'));
    await tester.ensureVisible(favoriteArmor);
    await tester.pumpAndSettle();
    await tester.tap(favoriteArmor);
    await tester.pumpAndSettle();

    final applyArmor =
        find.byKey(const ValueKey('wargear-apply-stormsea_hauberk'));
    await tester.ensureVisible(applyArmor);
    await tester.pumpAndSettle();
    await tester.tap(applyArmor);
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('knight-favorite-armor-0')));
    await _pumpUntilFound(tester, find.text('Favorite armors'));
    expect(
        find.textContaining(
            'Scores use the current boss, pet and guild context.'),
        findsOneWidget);
    expect(_findLocalizedUasChip().evaluate().isNotEmpty, isTrue);

    final useArmor =
        find.byKey(const ValueKey('wargear-apply-stormsea_hauberk'));
    await tester.ensureVisible(useArmor);
    await tester.pumpAndSettle();
    await tester.tap(useArmor);
    await _pumpUntilFound(
      tester,
      find.textContaining('Stormsea Hauberk imported into K#1.'),
    );

    expect(
      find.textContaining('Stormsea Hauberk imported into K#1.'),
      findsOneWidget,
    );
    expect(find.textContaining('Universal Armor Score:'), findsOneWidget);
  });

  testWidgets('Utilities can save setup and asks overwrite on occupied slot',
      (tester) async {
    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    final saveBtn = find.byKey(const ValueKey('utility-save-setup'));
    await tester.scrollUntilVisible(
      saveBtn,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    final saveTitleIt = find.text('Salva setup');
    final saveTitleEn = find.text('Save setup');
    expect(
        saveTitleIt.evaluate().isNotEmpty || saveTitleEn.evaluate().isNotEmpty,
        isTrue);

    await tester.tap(find.byKey(const ValueKey('setups-slot-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setups-name-confirm-1')));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    await tester.tap(saveBtn);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('setups-slot-1')));
    await tester.pumpAndSettle();

    final overwriteIt = find.text('Sovrascrivere setup?');
    final overwriteEn = find.text('Overwrite setup?');
    expect(
      overwriteIt.evaluate().isNotEmpty || overwriteEn.evaluate().isNotEmpty,
      isTrue,
    );
  });

  testWidgets('Top Setups sheet can load a saved setup', (tester) async {
    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Save slot 1 with boss level L4.
    final bossLevelDropdown = find.byKey(const ValueKey('boss-level-dropdown'));

    await tester.tap(bossLevelDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('L4').last);
    await tester.pumpAndSettle();

    final saveBtn = find.byKey(const ValueKey('utility-save-setup'));
    await tester.scrollUntilVisible(
      saveBtn,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setups-slot-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setups-name-confirm-1')));
    await tester.pumpAndSettle();

    // Change level to L2, then load slot 1 from top shortcut.
    await tester.drag(find.byType(ListView).first, const Offset(0, 700));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, 700));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 1200));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('boss-level-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('L2').last);
    await tester.pumpAndSettle();
    expect(find.text('L2'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('app-shortcuts-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-shortcut-setups')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setups-load-slot-1')));
    await tester.pumpAndSettle();

    expect(find.text('L4'), findsWidgets);
  });

  testWidgets('Bulk Simulate button appears only when at least 2 setups exist',
      (tester) async {
    final premium = DevPremiumService();
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(premiumService: premium),
      ),
    );

    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.byKey(const ValueKey('bulk-simulate-button')), findsNothing);

    final saveBtn = find.byKey(const ValueKey('utility-save-setup'));
    await tester.scrollUntilVisible(
      saveBtn,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setups-slot-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setups-name-confirm-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('bulk-simulate-button')), findsNothing);

    await tester.tap(saveBtn);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setups-slot-2')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('setups-name-confirm-2')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 300));

    final bulkButton = find.byKey(const ValueKey('bulk-simulate-button'));
    await tester.drag(find.byType(ListView).first, const Offset(0, 500));
    await tester.pumpAndSettle();

    expect(bulkButton, findsOneWidget);
  });
}

Set<String> _idsForNames(
  WargearWardrobeCatalog catalog,
  List<String> names,
) {
  final ids = <String>{};
  for (final name in names) {
    final match = catalog.armors.where((entry) => entry.name == name).first;
    ids.add(match.id);
  }
  return ids;
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxTicks = 50,
  Duration step = const Duration(milliseconds: 200),
}) async {
  for (var i = 0; i < maxTicks; i++) {
    await tester.pump(step);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Finder not found after waiting: $finder');
}

Finder _findLocalizedUasChip() {
  return find.byWidgetPredicate((widget) {
    if (widget is! Text) return false;
    final data = widget.data ?? '';
    return data.contains('UAS:') ||
        data.contains('PAU:') ||
        data.contains('UPS:') ||
        data.contains('URS:') ||
        data.contains('SAU:') ||
        data.contains('EZP:');
  });
}
