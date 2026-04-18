import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/data/favorites_limits.dart';
import 'package:raid_calc/data/wargear_favorites_storage.dart';
import 'package:raid_calc/data/wargear_wardrobe_sheet_storage.dart';
import 'package:raid_calc/ui/home/wargear_wardrobe_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('wargear wardrobe sheet filters and resolves plus stats',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('wargear-search-field')),
    );

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'stormsea',
    );
    await tester.pumpAndSettle();
    expect(find.text('Stormsea Hauberk'), findsOneWidget);
    expect(find.text('ATK: 71,232'), findsOneWidget);

    final plusButton = find.byKey(const ValueKey('wargear-cycle-plus'));
    await tester.ensureVisible(plusButton);
    await tester.pumpAndSettle();
    await tester.tap(plusButton);
    await tester.pumpAndSettle();
    expect(find.text('Stormsea Hauberk +'), findsOneWidget);
    expect(find.text('ATK: 79,820'), findsOneWidget);

    final roleButton = find.byKey(const ValueKey('wargear-cycle-role'));
    await tester.ensureVisible(roleButton);
    await tester.pumpAndSettle();
    await tester.tap(roleButton);
    await tester.pumpAndSettle();
    expect(find.text('HP: 1,842'), findsOneWidget);

    expect(find.text('1 armor sets found'), findsOneWidget);

    final waterGuildBonus =
        find.byKey(const ValueKey('wargear-guild-bonus-water'));
    await tester.ensureVisible(waterGuildBonus);
    await tester.pumpAndSettle();
    await tester.tap(waterGuildBonus);
    await tester.pumpAndSettle();

    expect(find.text('ATK: 66,438'), findsOneWidget);
  });

  testWidgets(
      'wargear wardrobe can filter by season and sorts recent seasons first',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('wargear-search-field')),
    );
    await tester.tap(find.byKey(const ValueKey('wargear-clear-filters')));
    await tester.pumpAndSettle();
    expect(find.text('Season: All'), findsOneWidget);

    expect(find.text('Hellforge Plastron'), findsOneWidget);

    final seasonButton = find.byKey(const ValueKey('wargear-season-menu'));
    await tester.ensureVisible(seasonButton);
    await tester.pumpAndSettle();
    await tester.tap(seasonButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('S116').last);
    await tester.pumpAndSettle();

    expect(find.text('4 armor sets found'), findsOneWidget);
    expect(find.text('Glacierrun Panoply'), findsOneWidget);
    expect(find.text('Riverborn Shell'), findsOneWidget);
    expect(find.text('Stormsea Hauberk'), findsOneWidget);
    expect(find.text('Hellforge Plastron'), findsNothing);

    await tester.ensureVisible(seasonButton);
    await tester.pumpAndSettle();
    await tester.tap(seasonButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('S117').last);
    await tester.pumpAndSettle();

    expect(find.text('7 armor sets found'), findsOneWidget);
    expect(find.text('Hellforge Plastron'), findsOneWidget);
  });

  testWidgets(
      'wargear wardrobe searches by season tag and hides no-plus armors',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      's109',
    );
    await tester.pumpAndSettle();
    expect(find.text('TerraPulse Blaster'), findsOneWidget);
    expect(find.text('4 armor sets found'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'steed t10',
    );
    await tester.pumpAndSettle();
    expect(find.text('Skybound Steed T10'), findsOneWidget);
    expect(find.text('Shadowbound Steed T10'), findsOneWidget);
    expect(find.text('2 armor sets found'), findsOneWidget);

    final plusButton = find.byKey(const ValueKey('wargear-cycle-plus'));
    await tester.ensureVisible(plusButton);
    await tester.pumpAndSettle();
    await tester.tap(plusButton);
    await tester.pumpAndSettle();

    expect(
      find.text('No armor set matches the current filters.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'wargear wardrobe can favorite an armor and favorites mode shows it',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

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
    final favoriteButton =
        find.byKey(const ValueKey('wargear-favorite-stormsea_hauberk'));
    await tester.ensureVisible(favoriteButton);
    await tester.pumpAndSettle();
    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            favoritesOnlyMode: true,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Favorite armors'));
    expect(find.text('Stormsea Hauberk'), findsOneWidget);
    expect(find.text('1 armor sets found'), findsOneWidget);
  });

  testWidgets(
      'wargear wardrobe can filter to favorite armors only in normal mode',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await WargearFavoritesStorage.save(<String>{'stormsea_hauberk'});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            isPremium: true,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('wargear-favorites-only-filter')),
    );
    await tester.tap(
      find.byKey(const ValueKey('wargear-favorites-only-filter')),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 armor sets found'), findsOneWidget);
    expect(find.textContaining('Stormsea Hauberk'), findsWidgets);
  });

  testWidgets('wargear wardrobe can clear all filters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await WargearFavoritesStorage.save(<String>{'stormsea_hauberk'});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            isPremium: true,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));
    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'storm',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('wargear-favorites-only-filter')),
    );
    await tester.pumpAndSettle();

    final seasonButton = find.byKey(const ValueKey('wargear-season-menu'));
    await tester.ensureVisible(seasonButton);
    await tester.tap(seasonButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('S116').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('wargear-clear-filters')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('wargear-search-field')))
          .controller!
          .text,
      isEmpty,
    );
    expect(find.text('Season: All'), findsOneWidget);
    expect(find.text('Favorites only'), findsOneWidget);
  });

  testWidgets('non-premium armors favorites are capped at fifteen',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await WargearFavoritesStorage.save(
      <String>{
        for (var i = 1; i <= freeFavoriteArmorsLimit; i++) 'fav-$i',
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            isPremium: false,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('wargear-favorites-limit-banner')),
    );

    expect(
      find.text(
        'Favorite armors: $freeFavoriteArmorsLimit/$freeFavoriteArmorsLimit. Premium unlocks up to $premiumFavoriteArmorsLimit favorite armors.',
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'storm',
    );
    await tester.pumpAndSettle();

    final favoriteButton =
        find.byKey(const ValueKey('wargear-favorite-stormsea_hauberk'));
    await tester.ensureVisible(favoriteButton);
    await tester.tap(favoriteButton);
    await tester.pump();

    expect(
      find.text(
        'Free users can save up to $freeFavoriteArmorsLimit favorite armors. You are at $freeFavoriteArmorsLimit/$freeFavoriteArmorsLimit. Premium unlocks up to $premiumFavoriteArmorsLimit favorite armors.',
      ),
      findsOneWidget,
    );

    final favorites = await WargearFavoritesStorage.load();
    expect(favorites.length, freeFavoriteArmorsLimit);
    expect(favorites, isNot(contains('stormsea_hauberk')));
  });

  testWidgets(
      'premium armor users can exceed the free favorites cap up to premium cap',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final seeded = <String>{
      for (var i = 1; i <= freeFavoriteArmorsLimit; i++) 'fav-$i',
    };
    await WargearFavoritesStorage.save(seeded);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            isPremium: true,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));
    expect(find.byKey(const ValueKey('wargear-favorites-limit-banner')),
        findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('wargear-search-field')),
      'storm',
    );
    await tester.pumpAndSettle();

    final favoriteButton =
        find.byKey(const ValueKey('wargear-favorite-stormsea_hauberk'));
    await tester.ensureVisible(favoriteButton);
    await tester.tap(favoriteButton);
    await tester.pumpAndSettle();

    final favorites = await WargearFavoritesStorage.load();
    expect(favorites.length, freeFavoriteArmorsLimit + 1);
    expect(favorites, contains('stormsea_hauberk'));
  });

  testWidgets('wargear wardrobe persists selected filters to storage',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('wargear-search-field')),
    );

    final rankButton = find.byKey(const ValueKey('wargear-cycle-rank'));
    await tester.ensureVisible(rankButton);
    await tester.pumpAndSettle();
    await tester.tap(rankButton);
    await tester.pumpAndSettle();
    final plusButton = find.byKey(const ValueKey('wargear-cycle-plus'));
    await tester.ensureVisible(plusButton);
    await tester.pumpAndSettle();
    await tester.tap(plusButton);
    await tester.pumpAndSettle();

    expect(find.text('Rank: HC'), findsOneWidget);
    expect(find.text('Version: +'), findsOneWidget);
    final saved = await WargearWardrobeSheetStorage.load();
    expect(saved['rank'], 'highCommander');
    expect(saved['plus'], isTrue);
  });

  testWidgets('wargear wardrobe can hide and show filters', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WargearWardrobeSheet(
            t: _translate,
            availableTargets: <WargearImportTarget>[
              WargearImportTarget(
                kind: WargearImportTargetKind.knight,
                index: 0,
                label: 'K#1',
              ),
            ],
          ),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Wargear Wardrobe'));
    expect(find.text('Modifiers'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('wargear-toggle-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Show filters'), findsOneWidget);
    expect(find.text('Modifiers'), findsNothing);
    expect(find.byKey(const ValueKey('wargear-cycle-rank')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('wargear-toggle-filters')));
    await tester.pumpAndSettle();

    expect(find.text('Hide filters'), findsOneWidget);
    expect(find.byKey(const ValueKey('wargear-cycle-rank')), findsOneWidget);
  });
}

String _translate(String _, String fallback) => fallback;

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
