import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/sim_battery/wargear_uas_pet_skill_audit.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pet skill audit generates the expected scenario grid and report files',
      () async {
    final dir = await Directory.systemTemp.createTemp('uas_pet_skill_audit_test');
    addTearDown(() async {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    });

    final summary = await WargearUasPetSkillAuditRunner().run(
      outputDir: dir,
      runsPerScenario: 1,
    );

    expect(summary.scenarioCount, 180);
    expect(
      summary.generatedFiles.any((path) => path.endsWith('uas_pet_skill_rows.csv')),
      isTrue,
    );
    expect(
      summary.generatedFiles.any((path) => path.endsWith('uas_pet_skill_report.md')),
      isTrue,
    );

    final report = File('${dir.path}/uas_pet_skill_report.md');
    expect(await report.exists(), isTrue);
    final markdown = await report.readAsString();
    expect(markdown, contains('EW + SR∞ | 2,1'));
    expect(markdown, contains('DRS + EW | 1'));
    expect(markdown, contains('EW + Shatter | 2'));
    expect(markdown, contains('EW + Cyclone | 2'));
  });
}
