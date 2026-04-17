import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/data/wargear_favorites_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('wargear favorites storage saves and loads armor ids', () async {
    await WargearFavoritesStorage.save(
      <String>{'stormsea_hauberk', 'glacierrun_panoply'},
    );

    final loaded = await WargearFavoritesStorage.load();

    expect(loaded, contains('stormsea_hauberk'));
    expect(loaded, contains('glacierrun_panoply'));
  });

  test('wargear favorites storage toggles armor ids', () async {
    final added = await WargearFavoritesStorage.toggle('stormsea_hauberk');
    expect(added, isTrue);
    expect(await WargearFavoritesStorage.load(), contains('stormsea_hauberk'));

    final removed = await WargearFavoritesStorage.toggle('stormsea_hauberk');
    expect(removed, isFalse);
    expect(
      await WargearFavoritesStorage.load(),
      isNot(contains('stormsea_hauberk')),
    );
  });
}
