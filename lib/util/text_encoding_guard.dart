import 'dart:convert';

/// Centralized guard against mojibake caused by UTF-8 text decoded with a
/// latin1/cp1252 path one or more times.
class TextEncodingGuard {
  static final RegExp _controlChars = RegExp(r'[\u0080-\u009F]');
  static const Map<int, int> _cp1252Extras = <int, int>{
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  static const List<String> _suspiciousFragments = <String>[
    '\uFFFD',
    'Ã',
    'Â',
    'â€',
    'â†’',
    'â€™',
    'â€œ',
    'â€�',
    'â€“',
    'â€”',
    'â€¦',
    'âˆž',
    'ðŸ',
  ];

  static bool containsLikelyMojibake(String input) {
    if (input.isEmpty) return false;
    if (_controlChars.hasMatch(input)) return true;
    return _suspiciousFragments.any(input.contains);
  }

  static int suspicionScore(String input) {
    if (input.isEmpty) return 0;
    var score = _controlChars.allMatches(input).length * 2;
    for (final fragment in _suspiciousFragments) {
      score += _countOccurrences(input, fragment);
    }
    return score;
  }

  static String repairLikelyMojibake(String input, {int maxRounds = 3}) {
    if (input.isEmpty || !containsLikelyMojibake(input)) return input;

    var best = input;
    var bestScore = suspicionScore(input);
    var current = input;

    for (var i = 0; i < maxRounds; i++) {
      final repaired = _bestSingleRoundRepair(current);
      if (repaired == null || repaired == current) break;
      current = repaired;
      final score = suspicionScore(current);
      if (score < bestScore) {
        best = current;
        bestScore = score;
      }
      if (score == 0) return current;
    }

    return best;
  }

  static String? _bestSingleRoundRepair(String input) {
    final latin1Candidate = _decodeUtf8FromByteEncoding(
      input,
      latin1.encode,
    );
    final cp1252Candidate = _decodeUtf8FromByteEncoding(
      input,
      _encodeCp1252,
    );

    final candidates = <String>[
      if (latin1Candidate != null) latin1Candidate,
      if (cp1252Candidate != null && cp1252Candidate != latin1Candidate)
        cp1252Candidate,
    ];
    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final scoreDiff = suspicionScore(a).compareTo(suspicionScore(b));
      if (scoreDiff != 0) return scoreDiff;
      return a.length.compareTo(b.length);
    });
    return candidates.first;
  }

  static String? _decodeUtf8FromByteEncoding(
    String input,
    List<int> Function(String value) encoder,
  ) {
    try {
      return utf8.decode(encoder(input), allowMalformed: false);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }

  static List<int> _encodeCp1252(String input) {
    final bytes = <int>[];
    for (final rune in input.runes) {
      if (rune <= 0xFF) {
        bytes.add(rune);
        continue;
      }
      final mapped = _cp1252Extras[rune];
      if (mapped == null) {
        throw const FormatException('Cannot encode rune in cp1252');
      }
      bytes.add(mapped);
    }
    return bytes;
  }

  static int _countOccurrences(String input, String fragment) {
    if (fragment.isEmpty) return 0;
    var count = 0;
    var index = 0;
    while (true) {
      index = input.indexOf(fragment, index);
      if (index == -1) return count;
      count++;
      index += fragment.length;
    }
  }
}
