import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';

void main() {
  test('advantage multiplier follows element rules', () {
    expect(
      advantageMultiplier(
        [ElementType.fire, ElementType.fire],
        [ElementType.earth, ElementType.spirit],
      ),
      2.0,
    );

    expect(
      advantageMultiplier(
        [ElementType.fire, ElementType.water],
        [ElementType.fire, ElementType.air],
      ),
      1.5,
    );

    expect(
      advantageMultiplier(
        [ElementType.fire, ElementType.spirit],
        [ElementType.earth, ElementType.spirit],
      ),
      2.0,
    );

    expect(
      advantageMultiplier(
        [ElementType.starmetal, ElementType.starmetal],
        [ElementType.water, ElementType.air],
      ),
      2.0,
    );
  });
}
