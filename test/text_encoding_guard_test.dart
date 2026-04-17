import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/util/text_encoding_guard.dart';

void main() {
  test('TextEncodingGuard detects and repairs common mojibake', () {
    expect(
      TextEncodingGuard.repairLikelyMojibake('Questa app Ã¨ stata pensata'),
      'Questa app è stata pensata',
    );
    expect(
      TextEncodingGuard.repairLikelyMojibake('ModalitÃ  Boss'),
      'Modalità Boss',
    );
    expect(
      TextEncodingGuard.repairLikelyMojibake('Cyclone Boost â€” Damage per turn'),
      'Cyclone Boost — Damage per turn',
    );
    expect(
      TextEncodingGuard.repairLikelyMojibake('Special Regeneration âˆž'),
      'Special Regeneration ∞',
    );
  });

  test('TextEncodingGuard leaves clean UTF-8 text unchanged', () {
    expect(
      TextEncodingGuard.repairLikelyMojibake('Questa app è stata pensata'),
      'Questa app è stata pensata',
    );
    expect(
      TextEncodingGuard.containsLikelyMojibake('Questa app è stata pensata'),
      isFalse,
    );
  });
}
