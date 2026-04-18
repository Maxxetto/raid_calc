import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/engine/engine_common.dart';

int _scaledDamage({
  required int baseDamage,
  required double reduction,
  required bool petStrongVsBoss,
  double strongElementEw = 1.6,
}) {
  final exponent = elementalWeaknessExponent(
    petStrongVsBoss: petStrongVsBoss,
    baseReduction: reduction,
    strongElementEw: strongElementEw,
  );
  final multiplier = math.pow(1.0 - reduction, exponent).toDouble();
  return (baseDamage * multiplier).floor();
}

void main() {
  test('EW 65.2% strong reproduces observed low-damage profile', () {
    const reduction = 0.652;
    expect(
      <int>[
        _scaledDamage(
          baseDamage: 43,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
        _scaledDamage(
          baseDamage: 41,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
        _scaledDamage(
          baseDamage: 38,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
      ],
      <int>[2, 2, 1],
    );
    expect(
      <int>[
        _scaledDamage(
          baseDamage: 65,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
        _scaledDamage(
          baseDamage: 82,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
        _scaledDamage(
          baseDamage: 88,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
      ],
      <int>[3, 4, 4],
    );
  });

  test('EW 34.65% strong reproduces medium-reduction profile', () {
    const reduction = 0.3465;
    expect(
      <int>[
        _scaledDamage(
          baseDamage: 43,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
        _scaledDamage(
          baseDamage: 42,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
        _scaledDamage(
          baseDamage: 38,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
      ],
      <int>[21, 20, 18],
    );
    expect(
      <int>[
        _scaledDamage(
          baseDamage: 65,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
        _scaledDamage(
          baseDamage: 63,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
        _scaledDamage(
          baseDamage: 58,
          reduction: reduction,
          petStrongVsBoss: true,
        ),
      ],
      <int>[31, 30, 28],
    );
  });

  test('EW 65.2% non-strong keeps base one-stack profile', () {
    const reduction = 0.652;
    expect(
      <int>[
        _scaledDamage(
          baseDamage: 40,
          reduction: reduction,
          petStrongVsBoss: false,
        ),
        _scaledDamage(
          baseDamage: 54,
          reduction: reduction,
          petStrongVsBoss: false,
        ),
        _scaledDamage(
          baseDamage: 56,
          reduction: reduction,
          petStrongVsBoss: false,
        ),
        _scaledDamage(
          baseDamage: 44,
          reduction: reduction,
          petStrongVsBoss: false,
        ),
      ],
      <int>[13, 18, 19, 15],
    );
  });
}
