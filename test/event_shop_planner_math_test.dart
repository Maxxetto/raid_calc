import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/event_shop_planner_math.dart';

void main() {
  test('remaining is reduced by manual and tracked inventory', () {
    final totals = computeEventShopPlannerTotals(
      requiredAmount: 500,
      manualInventory: 400,
      trackedInventory: 0,
      trackedInfinite: false,
    );

    expect(totals.required, 500);
    expect(totals.available, 400);
    expect(totals.remaining, 100);
    expect(totals.inventoryIsInfinite, isFalse);
  });

  test('remaining floors at zero when inventory exceeds required amount', () {
    final totals = computeEventShopPlannerTotals(
      requiredAmount: 500,
      manualInventory: 700,
      trackedInventory: 50,
      trackedInfinite: false,
    );

    expect(totals.available, 750);
    expect(totals.remaining, 0);
  });

  test('tracked infinity makes remaining zero', () {
    final totals = computeEventShopPlannerTotals(
      requiredAmount: 500,
      manualInventory: 0,
      trackedInventory: 0,
      trackedInfinite: true,
    );

    expect(totals.available, 500);
    expect(totals.remaining, 0);
    expect(totals.inventoryIsInfinite, isTrue);
  });
}
