import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/util/knight_stats_ocr.dart';

void main() {
  test('KnightStatsParser extracts atk/def/hp for three columns', () {
    final tokens = <OcrLineToken>[
      const OcrLineToken(text: '59,814', x: 70, y: 120),
      const OcrLineToken(text: '74,314', x: 72, y: 170),
      const OcrLineToken(text: '1,870/1,870', x: 70, y: 225),
      const OcrLineToken(text: '66,408', x: 320, y: 118),
      const OcrLineToken(text: '79,852', x: 322, y: 170),
      const OcrLineToken(text: '2,049/2,049', x: 320, y: 226),
      const OcrLineToken(text: '76,247', x: 570, y: 118),
      const OcrLineToken(text: '62,871', x: 568, y: 171),
      const OcrLineToken(text: '1,790/1,790', x: 570, y: 227),
      const OcrLineToken(text: 'Choose Your Party', x: 320, y: 20),
    ];

    final parsed = KnightStatsParser.parseFromTokens(
      tokens: tokens,
      width: 900,
      height: 500,
    );

    expect(parsed, isNotNull);
    expect(parsed![0]!.atk, 59814);
    expect(parsed[0]!.def, 74314);
    expect(parsed[0]!.hp, 1870);
    expect(parsed[1]!.atk, 66408);
    expect(parsed[1]!.def, 79852);
    expect(parsed[1]!.hp, 2049);
    expect(parsed[2]!.atk, 76247);
    expect(parsed[2]!.def, 62871);
    expect(parsed[2]!.hp, 1790);
  });

  test('KnightStatsParser returns partial list when only one column is parsed',
      () {
    final tokens = <OcrLineToken>[
      const OcrLineToken(text: '59,814', x: 70, y: 120),
      const OcrLineToken(text: '74,314', x: 72, y: 170),
      const OcrLineToken(text: '1,870/1,870', x: 70, y: 225),
    ];

    final parsed = KnightStatsParser.parseFromTokens(
      tokens: tokens,
      width: 900,
      height: 500,
    );

    expect(parsed, isNotNull);
    expect(parsed![0], isNotNull);
    expect(parsed[1], isNull);
    expect(parsed[2], isNull);
  });
}
