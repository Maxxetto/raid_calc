import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/util/format.dart';

void main() {
  test('fmtInt groups thousands and keeps sign', () {
    expect(fmtInt(1234567), '1.234.567');
    expect(fmtInt(-1000), '-1.000');
  });

  test('fmtDouble trims zeros and keeps decimals', () {
    expect(fmtDouble(12.0), '12');
    expect(fmtDouble(12.5), '12.5');
  });

  test('fmtPct formats percent with default decimals', () {
    expect(fmtPct(0.123), '12.3%');
  });
}
