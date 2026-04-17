import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('compact pet compendium assets are internally consistent', () async {
    final library =
        await _loadJson('assets/pet_compendium_compact_library.json');
    final stats = _readList(library, 'statsProfiles');
    final payloads = _readList(library, 'skillPayloads');
    final skillSets = _readList(library, 'skillSets');

    final statIds = <String>{};
    final payloadIds = <String>{};
    final skillSetIds = <String>{};

    for (final stat in stats) {
      expect(statIds.add(_read(stat, 'id')), isTrue);
    }
    for (final payload in payloads) {
      expect(payloadIds.add(_read(payload, 'id')), isTrue);
    }
    for (final skillSet in skillSets) {
      expect(skillSetIds.add(_read(skillSet, 'id')), isTrue);
      for (final slotId in const <String>['skill11', 'skill12', 'skill2']) {
        final payloadId = _read(skillSet, slotId);
        if (payloadId.isEmpty) continue;
        expect(payloadIds.contains(payloadId), isTrue,
            reason:
                'Missing payload $payloadId for $slotId in ${_read(skillSet, 'id')}');
      }
    }

    for (final asset in const <String>[
      'assets/pet_compendium_compact_index_five_star.json',
      'assets/pet_compendium_compact_index_four_star.json',
      'assets/pet_compendium_compact_index_three_star.json',
      'assets/pet_compendium_compact_index_primal.json',
      'assets/pet_compendium_compact_index_shadowforged.json',
    ]) {
      final index = await _loadJson(asset);
      final familyIds = <String>{};
      final families = _readList(index, 'families');
      expect(families, isNotEmpty, reason: '$asset has no families');

      for (final family in families) {
        expect(familyIds.add(_read(family, 'id')), isTrue,
            reason: 'Duplicate family id ${_read(family, 'id')} in $asset');

        final tierIds = <String>{};
        final tiers = _readList(family, 'tiers');
        expect(tiers, isNotEmpty,
            reason: 'Family ${_read(family, 'id')} in $asset has no tiers');

        for (final tier in tiers) {
          expect(tierIds.add(_read(tier, 'id')), isTrue,
              reason:
                  'Duplicate tier id ${_read(tier, 'id')} in family ${_read(family, 'id')}');

          final profiles = _readList(tier, 'profiles');
          expect(profiles, isNotEmpty,
              reason:
                  'Tier ${_read(tier, 'id')} in family ${_read(family, 'id')} has no profiles');
          expect(profiles.length, 1,
              reason:
                  'Tier ${_read(tier, 'id')} in family ${_read(family, 'id')} should keep only the highest-level profile');

          for (final profile in profiles) {
            final statsRef = _read(profile, 'statsRef');
            expect(statIds.contains(statsRef), isTrue,
                reason: 'Missing statsRef $statsRef in $asset');

            final skillSetRef = _read(profile, 'skillSetRef');
            if (skillSetRef.isEmpty) continue;
            expect(skillSetIds.contains(skillSetRef), isTrue,
                reason: 'Missing skillSetRef $skillSetRef in $asset');

            final skillSet = skillSets.firstWhere(
              (entry) => _read(entry, 'id') == skillSetRef,
            );
            for (final slotId in const <String>[
              'skill11',
              'skill12',
              'skill2'
            ]) {
              final payloadId = _read(skillSet, slotId);
              if (payloadId.isEmpty) continue;
              final payload = payloads.firstWhere(
                (entry) => _read(entry, 'id') == payloadId,
              );
              expect(_read(payload, 'name'), _read(tier, slotId),
                  reason:
                      'Name mismatch for ${_read(family, 'id')} / ${_read(tier, 'id')} / ${_read(profile, 'id')} / $slotId');
            }
          }
        }
      }
    }
  });
}

Future<Map<String, Object?>> _loadJson(String asset) async {
  final raw = await rootBundle.loadString(asset);
  final decoded = jsonDecode(raw);
  if (decoded is! Map) {
    throw StateError('Expected a JSON object in $asset');
  }
  return decoded.cast<String, Object?>();
}

List<Map<String, Object?>> _readList(Map<String, Object?> json, String key) {
  final raw = (json[key] as List?)?.cast<Object?>() ?? const <Object?>[];
  return raw
      .whereType<Map>()
      .map((entry) => entry.cast<String, Object?>())
      .toList();
}

String _read(Map<String, Object?> json, String key) =>
    (json[key] ?? '').toString().trim();
