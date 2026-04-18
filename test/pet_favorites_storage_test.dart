import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/data/pet_favorites_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('pet favorites storage saves and loads family ids', () async {
    await PetFavoritesStorage.save(<String>{'s101sf_ignitide', 'vulpitier'});

    final loaded = await PetFavoritesStorage.load();

    expect(loaded, contains('s101sf_ignitide'));
    expect(loaded, contains('vulpitier'));
  });

  test('pet favorites storage toggles family ids', () async {
    final added = await PetFavoritesStorage.toggle('vulpitier');
    expect(added, isTrue);
    expect(await PetFavoritesStorage.load(), contains('vulpitier'));

    final removed = await PetFavoritesStorage.toggle('vulpitier');
    expect(removed, isFalse);
    expect(await PetFavoritesStorage.load(), isNot(contains('vulpitier')));
  });
}
