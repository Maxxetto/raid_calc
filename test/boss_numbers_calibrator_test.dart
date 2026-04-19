import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/calibration/boss_numbers.dart';
import '../tool/calibration/calibration_runner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('boss number loader converts raid fixture for calibration', () async {
    final source = await BossNumberFile.load(
      'assets/boss numbers/2026-04-17_raid_l4.json',
    );

    expect(source.mode, 'raid');
    expect(source.level, 4);
    expect(source.bossElements, <String>['fire', 'water']);
    expect(source.setup.knights, hasLength(3));
    expect(source.setup.knights.first.elements, <String>['water', 'water']);
    expect(source.setup.pet.elementalAtk, 1341);
    expect(source.setup.pet.elementalDef, 1132);
    expect(source.setup.pet.skillUsage, 'special2ThenSpecial1');
    expect(source.setup.pet.effects.map((e) => e.canonicalEffectId), <String>[
      'elemental_weakness',
      'special_regeneration_infinite',
    ]);
    expect(source.candidateRanges.combinationCount, greaterThan(0));
    expect(source.observedScores.length, greaterThan(100));

    final dataset = source.toCalibrationDataset();
    final cases = dataset.flattenCases();
    expect(cases, hasLength(1));
    expect(cases.single.modeKey, 'raid');
    expect(cases.single.level, 4);
    expect(cases.single.data.setup.pet.skillUsage, 'special2ThenSpecial1');
    expect(cases.single.data.setup.pet.elementalAtk, 1341);
    expect(cases.single.data.setup.pet.elementalDef, 1132);
  });

  test('boss number calibrator evaluates a candidate with finite accuracy',
      () async {
    final source = await BossNumberFile.load(
      'assets/boss numbers/2026-04-17_raid_l4.json',
    );
    final narrowSource = _narrowSource(source);

    final result = await const BossNumbersCalibrator().evaluate(
      source: narrowSource,
      runs: 5,
      top: 1,
    );

    expect(result.combinationsEvaluated, 1);
    expect(result.runs, 5);
    expect(result.topResults, hasLength(1));
    expect(result.topResults.single.loss.isFinite, isTrue);
    expect(result.topResults.single.accuracy.isFinite, isTrue);
  });

  test('boss number loader preserves blitz pet setup from app export',
      () async {
    final source = await BossNumberFile.load(
      'assets/boss numbers/2026-04-13_blitz_l6.json',
    );

    expect(source.mode, 'blitz');
    expect(source.level, 6);
    expect(source.setup.pet.skillUsage, 'special2ThenSpecial1');
    final srInf = source.setup.pet.effects.singleWhere(
      (effect) => effect.canonicalEffectId == 'special_regeneration_infinite',
    );
    expect(srInf.values['meterChargePercent'], 104.72);

    final preview = (await CalibrationRunner(
      dataset: source.toCalibrationDataset(),
    ).previewCases())
        .single;
    expect(
      preview.knights.map((knight) => knight.petMatchCount),
      <int>[0, 0, 0],
    );
  });

  test('boss number after writer emits per-file and aggregate JSON', () async {
    final raidSource = _narrowSource(await BossNumberFile.load(
      'assets/boss numbers/2026-04-17_raid_l4.json',
    ));
    final blitzSource = _narrowSource(await BossNumberFile.load(
      'assets/boss numbers/2026-04-13_blitz_l6.json',
    ));
    final raidResult = await const BossNumbersCalibrator().evaluate(
      source: raidSource,
      runs: 3,
      top: 1,
    );
    final blitzResult = await const BossNumbersCalibrator().evaluate(
      source: blitzSource,
      runs: 3,
      top: 1,
    );
    final tempDir = Directory.systemTemp.createTempSync('boss_numbers_after_');
    addTearDown(() {
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    final written = await const BossNumbersAfterWriter().write(
      results: <BossNumbersSearchResult>[raidResult, blitzResult],
      afterDir: tempDir.path,
    );

    expect(written, hasLength(3));
    final afterFile = File('${tempDir.path}/2026-04-17_raid_l4_after.json');
    expect(afterFile.existsSync(), isTrue);
    final afterJson = (jsonDecode(afterFile.readAsStringSync()) as Map)
        .cast<String, Object?>();
    final resolvedSetup =
        (afterJson['resolvedSetup'] as Map).cast<String, Object?>();
    final pet = (resolvedSetup['pet'] as Map).cast<String, Object?>();
    expect(pet['elementalBonusRule'], contains('Wargear Wardrobe'));
    expect(
      (pet['totalElementalBonusApplied'] as Map).cast<String, Object?>()['atk'],
      greaterThan(0),
    );
    final knights = (resolvedSetup['knights'] as List).cast<Object?>();
    final firstKnight = (knights.first as Map).cast<String, Object?>();
    expect(firstKnight['petArmorBonusMatchCount'], 1);
    expect(
      (firstKnight['baseStats'] as Map).cast<String, Object?>()['atk'],
      76933,
    );
    expect(
      (firstKnight['petBonus'] as Map).cast<String, Object?>()['atk'],
      1341,
    );
    expect(
      (firstKnight['finalStats'] as Map).cast<String, Object?>()['atk'],
      78274,
    );
    final damagePreview =
        (afterJson['damagePreview'] as Map).cast<String, Object?>();
    expect(damagePreview['knights'], isA<List>());
    expect(damagePreview['pet'], isA<Map>());

    final summaryFile =
        File('${tempDir.path}/pet_bar_calibration_summary.json');
    expect(summaryFile.existsSync(), isTrue);
    final summaryJson = (jsonDecode(summaryFile.readAsStringSync()) as Map)
        .cast<String, Object?>();
    expect(summaryJson['sourceCount'], 2);
    expect(summaryJson['recommendation'], isA<Map>());
  });
}

BossNumberFile _narrowSource(BossNumberFile source) {
  return BossNumberFile(
    path: source.path,
    schemaVersion: source.schemaVersion,
    eventDate: source.eventDate,
    label: source.label,
    mode: source.mode,
    level: source.level,
    bossElements: source.bossElements,
    scoreKind: source.scoreKind,
    setup: source.setup,
    candidateRanges: const BossNumberCandidateRanges(
      ticksPerState: <int>[165],
      startTicks: <int>[165],
      petKnightBaseTicks: <int>[12],
      bossNormalTicks: <int>[2],
      bossSpecialTicks: <int>[4],
      bossMissTicks: <int>[0],
      stunTicks: <int>[0],
      petCritPlusOneProb: <double>[0.0],
    ),
    observedScores: source.observedScores,
    notes: source.notes,
  );
}
