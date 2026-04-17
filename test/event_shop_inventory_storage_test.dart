import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/data/event_shop_inventory_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads empty inventory when nothing is stored', () async {
    final loaded = await EventShopInventoryStorage.load();
    expect(loaded, isEmpty);
  });

  test('saves and reloads shop inventory by event and currency', () async {
    await EventShopInventoryStorage.save({
      'celestial_steed': {
        'lunar_bell': 450,
        'guardian_hoof': 120,
      },
      'other_event': {
        'gems': 90,
      },
    });

    final loaded = await EventShopInventoryStorage.load();
    expect(loaded['celestial_steed']?['lunar_bell'], 450);
    expect(loaded['celestial_steed']?['guardian_hoof'], 120);
    expect(loaded['other_event']?['gems'], 90);
  });

  test('filters empty ids and non-positive values while saving', () async {
    await EventShopInventoryStorage.save({
      'celestial_steed': {
        'lunar_bell': 0,
        'guardian_hoof': -5,
        'jade_steed': 12,
      },
      '': {
        'gems': 10,
      },
    });

    final loaded = await EventShopInventoryStorage.load();
    expect(loaded.length, 1);
    expect(loaded['celestial_steed']?.containsKey('lunar_bell'), isFalse);
    expect(loaded['celestial_steed']?.containsKey('guardian_hoof'), isFalse);
    expect(loaded['celestial_steed']?['jade_steed'], 12);
  });
}
