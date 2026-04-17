import 'dart:io';

import 'sim_battery/wargear_uas_pet_skill_audit.dart';

Future<void> main(List<String> args) async {
  var outputPath = 'tool/sim_battery/out/uas_pet_skill_audit';
  var runsPerScenario = 100;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--output' && i + 1 < args.length) {
      outputPath = args[++i];
    } else if (args[i] == '--runs' && i + 1 < args.length) {
      runsPerScenario = int.tryParse(args[++i]) ?? runsPerScenario;
    }
  }

  final summary = await WargearUasPetSkillAuditRunner().run(
    outputDir: Directory(outputPath),
    runsPerScenario: runsPerScenario,
  );
  stdout.writeln(
    'Pet skill audit completed: ${summary.scenarioCount} scenarios -> ${summary.outputDir.path}',
  );
}
