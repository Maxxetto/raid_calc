import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/util/text_encoding_guard.dart';

void main() {
  test('user-facing text assets and docs are free from mojibake', () {
    final targets = <String>[
      'AGENTS.md',
      'guidelines.md',
      'app_features.md',
      'wargear_scoring_parameters.md',
    ];

    final langFiles = Directory('assets/langs')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList()
      ..sort((a, b) => a.path.compareTo(b.path));

    final broken = <String>[];

    for (final path in targets) {
      final text = File(path).readAsStringSync();
      if (TextEncodingGuard.containsLikelyMojibake(text)) {
        broken.add(path);
      }
    }

    for (final file in langFiles) {
      final text = file.readAsStringSync();
      if (TextEncodingGuard.containsLikelyMojibake(text)) {
        broken.add(file.path.replaceAll('\\', '/'));
      }
    }

    expect(
      broken,
      isEmpty,
      reason: 'Mojibake detected in text assets/docs: ${broken.join(', ')}',
    );
  });
}
