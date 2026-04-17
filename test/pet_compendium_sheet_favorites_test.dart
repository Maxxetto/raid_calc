import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/data/favorites_limits.dart';
import 'package:raid_calc/data/pet_compendium_loader.dart';
import 'package:raid_calc/data/pet_favorites_storage.dart';
import 'package:raid_calc/ui/home/pet_compendium_sheet.dart';
import 'package:raid_calc/ui/home/pet_favorites_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('pet compendium can favorite a pet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: true,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-compendium-favorite-vulpitier')),
    );

    final favoriteButton = find.byKey(
      const ValueKey('pet-compendium-favorite-vulpitier'),
    );
    expect(favoriteButton, findsOneWidget);

    await tester.tap(favoriteButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final favorites = await PetFavoritesStorage.load();
    expect(favorites, contains('vulpitier'));
  });

  testWidgets('favorite pets sheet shows favorited pets', (tester) async {
    await PetFavoritesStorage.save(<String>{'vulpitier'});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetFavoritesSheet(
            t: _translate,
          ),
        ),
      ),
    );

    await _pumpUntilFound(tester, find.text('Vulpitier'));

    expect(find.text('Vulpitier'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('pet-favorites-apply-vulpitier')),
      findsOneWidget,
    );
  });

  testWidgets('pet compendium can filter to favorite pets only',
      (tester) async {
    await PetFavoritesStorage.save(<String>{'vulpitier'});

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: true,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );

    await tester.tap(
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey('pet-compendium-favorites-only-filter'),
      ),
    );
    await _pumpUntilFound(tester, find.text('1 pets found'));

    expect(find.text('1 pets found'), findsOneWidget);
    expect(find.textContaining('Vulpitier'), findsWidgets);
    expect(
      find.byKey(const ValueKey('pet-compendium-favorite-vulpitier')),
      findsOneWidget,
    );
  });

  testWidgets('pet compendium can combine season and element filters',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: true,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );

    await tester.tap(
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );
    await tester.pumpAndSettle();

    final seasonFilter = tester.widget<DropdownButtonFormField<String?>>(
      find.byKey(const ValueKey('pet-compendium-season-filter')),
    );
    seasonFilter.onChanged?.call('S47');
    await tester.pumpAndSettle();

    final elementFilter = tester.widget<DropdownButtonFormField<ElementType?>>(
      find.byKey(const ValueKey('pet-compendium-element-filter')),
    );
    elementFilter.onChanged?.call(ElementType.spirit);
    await tester.pumpAndSettle();

    expect(find.textContaining('Vulpitier'), findsWidgets);
    expect(find.text('3 pets found'), findsOneWidget);
  });

  testWidgets('non-premium pet favorites are capped at six', (tester) async {
    await PetFavoritesStorage.save(
      <String>{
        'fav-1',
        'fav-2',
        'fav-3',
        'fav-4',
        'fav-5',
        'fav-6',
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: false,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-favorites-limit-banner')),
    );

    expect(
      find.text(
        'Favorite pets: $freeFavoritePetsLimit/$freeFavoritePetsLimit. Premium unlocks up to $premiumFavoritePetsLimit favorite pets.',
      ),
      findsOneWidget,
    );

    final blockedButton = find.byKey(
      const ValueKey('pet-compendium-favorite-vulpitier'),
    );
    await tester.ensureVisible(blockedButton);
    await tester.tap(blockedButton);
    await tester.pump();

    expect(
      find.text(
        'You can save up to $freeFavoritePetsLimit favorite pets. You are at $freeFavoritePetsLimit/$freeFavoritePetsLimit.',
      ),
      findsOneWidget,
    );

    final favorites = await PetFavoritesStorage.load();
    expect(favorites.length, freeFavoritePetsLimit);
    expect(favorites, isNot(contains('vulpitier')));
  });

  testWidgets('premium pet users can save up to eight favorites',
      (tester) async {
    await PetFavoritesStorage.save(
      <String>{
        'fav-1',
        'fav-2',
        'fav-3',
        'fav-4',
        'fav-5',
        'fav-6',
        'fav-7',
      },
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: true,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-compendium-favorite-vulpitier')),
    );

    final favoriteButton = find.byKey(
      const ValueKey('pet-compendium-favorite-vulpitier'),
    );
    await tester.ensureVisible(favoriteButton);
    await tester.tap(favoriteButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('pet-favorites-limit-banner')),
        findsOneWidget);

    final favorites = await PetFavoritesStorage.load();
    expect(favorites.length, premiumFavoritePetsLimit);
    expect(favorites, contains('vulpitier'));
  });

  testWidgets('pet compendium filters can be collapsed to free space',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: true,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );

    expect(
      find.byKey(const ValueKey('pet-compendium-search-field')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pet-compendium-search-field')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pet-compendium-search-field')),
      findsNothing,
    );
    expect(find.text('Search and filters'), findsOneWidget);
    expect(find.textContaining('pets found'), findsOneWidget);
  });

  testWidgets('pet compendium exposes two skill filters for combos',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: true,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );

    await tester.tap(
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pet-compendium-skill-filter-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('pet-compendium-skill-filter-2')),
      findsOneWidget,
    );
    expect(
      find.text('Pick one or two skills to match pet combos more easily.'),
      findsOneWidget,
    );
  });

  testWidgets(
      'pet compendium skill filter keeps Special Regeneration and SR inf distinct',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final catalog = await PetCompendiumLoader.load();
    final expectedInfCount = catalog.pets
        .where(
          (family) => family.allSkills.any(
            (skill) => skill == 'Special Regeneration (inf)',
          ),
        )
        .length;
    final normalizedSrCount = catalog.pets
        .where(
          (family) => family.allSkills.any(
            (skill) => skill.startsWith('Special Regeneration'),
          ),
        )
        .length;
    expect(expectedInfCount, lessThan(normalizedSrCount));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: true,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );

    await tester.tap(
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );
    await tester.pumpAndSettle();

    final skillFilter = tester.widget<DropdownButtonFormField<String?>>(
      find.byKey(const ValueKey('pet-compendium-skill-filter-1')),
    );
    skillFilter.onChanged?.call('Special Regeneration (inf)');
    await tester.pumpAndSettle();

    expect(find.text('$expectedInfCount pets found'), findsOneWidget);
  });

  testWidgets('pet compendium mobile filters do not overflow when expanded',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PetCompendiumSheet(
            t: _translate,
            isPremium: false,
          ),
        ),
      ),
    );

    await _pumpUntilFound(
      tester,
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );

    await tester.tap(
      find.byKey(const ValueKey('pet-compendium-toggle-filters')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('pet-compendium-skill-filter-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
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
