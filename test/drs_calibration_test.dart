import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/engine/engine_common.dart';

void main() {
  group('DRS calibration', () {
    test('uses stronger non-linear defense scaling', () {
      final noMatch = drsDefenseMultiplier(
        baseBoostFraction: 0.3,
        elementMatch: false,
        sameElementMultiplier: 1.6,
      );

      expect(noMatch, closeTo(1.69, 1e-9));
      expect((71 / noMatch).floor(), 42);
      expect((80 / noMatch).floor(), 47);
    });

    test('applies additional match amplification for pet-element match', () {
      final match = drsDefenseMultiplier(
        baseBoostFraction: 0.3,
        elementMatch: true,
        sameElementMultiplier: 1.6,
      );

      expect(match, closeTo(3.50464, 1e-9));
      expect((76 / match).floor(), 21);
      expect((115 / match).floor(), 32);
    });
  });
}
