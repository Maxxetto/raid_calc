import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/config_models.dart';

void main() {
  test('Advantage.normalize clamps to supported values', () {
    expect(Advantage.normalize(1.0), 1.0);
    expect(Advantage.normalize(1.4), 1.5);
    expect(Advantage.normalize(1.6), 1.5);
    expect(Advantage.normalize(1.9), 2.0);
    expect(Advantage.normalize(0.9), 1.0);
  });

  test('Advantage.normalizeList enforces length 3', () {
    final v = Advantage.normalizeList([2]);
    expect(v, [2.0, 1.0, 1.0]);

    final v2 = Advantage.normalizeList([1.0, 1.5, 2.0, 2.0]);
    expect(v2, [1.0, 1.5, 2.0]);
  });
}
