import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('boss number fixtures follow the manual calibration schema', () {
    final dir = Directory('assets/boss numbers');
    expect(dir.existsSync(), isTrue);

    final files = dir
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.json'))
        .toList(growable: false)
      ..sort((a, b) => a.path.compareTo(b.path));
    expect(files, isNotEmpty);

    final knownCanonicalEffectIds = _knownCanonicalEffectIds();
    for (final file in files) {
      final decoded = jsonDecode(file.readAsStringSync());
      expect(decoded, isA<Map>(), reason: file.path);
      _validateBossNumberFile((decoded as Map).cast<String, Object?>(),
          file.path, knownCanonicalEffectIds);
    }
  });
}

void _validateBossNumberFile(
  Map<String, Object?> root,
  String path,
  Set<String> knownCanonicalEffectIds,
) {
  expect(root['schemaVersion'], 1, reason: path);
  expect((root['eventDate'] as String?)?.trim(), isNotEmpty, reason: path);
  expect((root['label'] as String?)?.trim(), isNotEmpty, reason: path);
  expect(root['scoreKind'], 'raw_battle_points', reason: path);

  final boss = _requiredMap(root, 'boss', path);
  expect(boss['mode'], anyOf('raid', 'blitz'), reason: path);
  expect((boss['level'] as num?)?.toInt(), greaterThan(0), reason: path);
  _expectStringList(boss['elements'], length: 2, reason: '$path boss.elements');

  final setup = _requiredMap(root, 'setup', path);
  final knights = (setup['knights'] as List?) ?? const <Object?>[];
  expect(knights, hasLength(3), reason: '$path setup.knights');
  for (var i = 0; i < knights.length; i++) {
    final knight = (knights[i] as Map).cast<String, Object?>();
    expect((knight['slot'] as num?)?.toInt(), i + 1, reason: path);
    _expectStringList(knight['elements'],
        length: 2, reason: '$path knight ${i + 1} elements');
    _expectPositiveNumber(knight['atk'], '$path knight ${i + 1} atk');
    _expectPositiveNumber(knight['def'], '$path knight ${i + 1} def');
    _expectPositiveNumber(knight['hp'], '$path knight ${i + 1} hp');
    expect((knight['stunChance'] as num?)?.toDouble(), inInclusiveRange(0, 1),
        reason: '$path knight ${i + 1} stunChance');
  }

  final pet = _requiredMap(setup, 'pet', path);
  _expectStringList(pet['elements'], minLength: 1, maxLength: 2,
      reason: '$path pet.elements');
  _expectNonNegativeNumber(pet['atk'], '$path pet.atk');
  _expectNonNegativeNumber(pet['elementalAtk'], '$path pet.elementalAtk');
  _expectNonNegativeNumber(pet['elementalDef'], '$path pet.elementalDef');
  expect((pet['skillUsageCode'] as num?)?.toInt(), inInclusiveRange(1, 5),
      reason: '$path pet.skillUsageCode');

  final skills = (pet['skills'] as List?) ?? const <Object?>[];
  expect(skills, isNotEmpty, reason: '$path pet.skills');
  for (final rawSkill in skills) {
    final skill = (rawSkill as Map).cast<String, Object?>();
    expect((skill['slot'] as num?)?.toInt(), inInclusiveRange(1, 2),
        reason: path);
    expect((skill['name'] as String?)?.trim(), isNotEmpty, reason: path);
    final canonicalEffectId =
        (skill['canonicalEffectId'] as String?)?.trim() ?? '';
    expect(canonicalEffectId, isNotEmpty, reason: path);
    expect(knownCanonicalEffectIds, contains(canonicalEffectId), reason: path);
    expect(skill['values'], isA<Map>(), reason: path);
  }

  final calibration = _requiredMap(root, 'petBarCalibration', path);
  expect(calibration['enabled'], isA<bool>(), reason: path);
  final ranges = _requiredMap(calibration, 'candidateRanges', path);
  for (final key in const <String>[
    'ticksPerState',
    'startTicks',
    'petKnightBaseTicks',
    'bossNormalTicks',
    'bossSpecialTicks',
    'bossMissTicks',
    'stunTicks',
    'petCritPlusOneProb',
  ]) {
    final values = (ranges[key] as List?) ?? const <Object?>[];
    expect(values, isNotEmpty, reason: '$path petBarCalibration.$key');
    for (final value in values) {
      expect(value, isA<num>(), reason: '$path petBarCalibration.$key');
      expect((value as num).toDouble(), greaterThanOrEqualTo(0),
          reason: '$path petBarCalibration.$key');
    }
  }

  final scores = (root['observedScores'] as List?) ?? const <Object?>[];
  expect(scores, isNotEmpty, reason: '$path observedScores');
  for (final score in scores) {
    expect(score, isA<num>(), reason: '$path observedScores');
    expect((score as num).round(), greaterThan(0),
        reason: '$path observedScores');
  }
}

Set<String> _knownCanonicalEffectIds() {
  final raw = File('assets/pet_skill_semantics.json').readAsStringSync();
  final decoded = (jsonDecode(raw) as Map).cast<String, Object?>();
  final skills = (decoded['skills'] as List?) ?? const <Object?>[];
  return skills
      .whereType<Map>()
      .map((skill) => skill['canonicalEffectId']?.toString().trim() ?? '')
      .where((id) => id.isNotEmpty)
      .toSet();
}

Map<String, Object?> _requiredMap(
  Map<String, Object?> parent,
  String key,
  String path,
) {
  expect(parent[key], isA<Map>(), reason: '$path $key');
  return (parent[key] as Map).cast<String, Object?>();
}

void _expectStringList(
  Object? raw, {
  int? length,
  int? minLength,
  int? maxLength,
  required String reason,
}) {
  expect(raw, isA<List>(), reason: reason);
  final values = (raw as List).map((e) => e.toString().trim()).toList();
  if (length != null) expect(values, hasLength(length), reason: reason);
  if (minLength != null) {
    expect(values.length, greaterThanOrEqualTo(minLength), reason: reason);
  }
  if (maxLength != null) {
    expect(values.length, lessThanOrEqualTo(maxLength), reason: reason);
  }
  expect(values.every((value) => value.isNotEmpty), isTrue, reason: reason);
}

void _expectPositiveNumber(Object? raw, String reason) {
  expect(raw, isA<num>(), reason: reason);
  expect((raw as num).toDouble(), greaterThan(0), reason: reason);
}

void _expectNonNegativeNumber(Object? raw, String reason) {
  expect(raw, isA<num>(), reason: reason);
  expect((raw as num).toDouble(), greaterThanOrEqualTo(0), reason: reason);
}
