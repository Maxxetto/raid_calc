import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:raid_calc/data/event_shop_inventory_storage.dart';
import 'package:raid_calc/data/event_shop_planner_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loads empty planner state when nothing is stored', () async {
    final loaded = await EventShopPlannerStorage.load();
    expect(loaded, isEmpty);
  });

  test('migrates legacy inventory storage when planner state is absent',
      () async {
    await EventShopInventoryStorage.save({
      'celestial_steed_2026_02': {
        'lunar_bell': 300,
      },
    });

    final loaded = await EventShopPlannerStorage.load();
    expect(loaded['celestial_steed_2026_02']?.inventory['lunar_bell'], 300);
    expect(loaded['celestial_steed_2026_02']?.quantities, isEmpty);
  });

  test('saves and reloads inventory and quantities', () async {
    await EventShopPlannerStorage.save({
      'celestial_steed_2026_02': const EventShopPlannerStateData(
        inventory: {
          'lunar_bell': 450,
          'guardian_hoof': 120,
        },
        quantities: {
          0: 2,
          5: 1,
        },
      ),
    });

    final loaded = await EventShopPlannerStorage.load();
    expect(loaded['celestial_steed_2026_02']?.inventory['lunar_bell'], 450);
    expect(loaded['celestial_steed_2026_02']?.inventory['guardian_hoof'], 120);
    expect(loaded['celestial_steed_2026_02']?.quantities[0], 2);
    expect(loaded['celestial_steed_2026_02']?.quantities[5], 1);
  });
}
