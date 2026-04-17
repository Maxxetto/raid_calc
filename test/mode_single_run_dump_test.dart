import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/debug/debug_run.dart';
import 'package:raid_calc/data/config_loader.dart';

Future<void> _writeJson(String name, Map<String, Object?> payload) async {
  final dir = Directory('lib/test/results');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  final file = File('${dir.path}/$name.json');
  final json = const JsonEncoder.withIndent('  ').convert(payload);
  await file.writeAsString(json);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('dump single run per mode to lib/test/results', () async {
    final boss = await ConfigLoader.loadBoss(
      raidMode: true,
      bossLevel: 4,
      adv: <double>[1.0, 1.0, 1.0],
      fightModeKey: 'normal',
    );
    final pre = DamageModel().precompute(
      boss: boss,
      kAtk: <double>[62375, 66508, 59814],
      kDef: <double>[71787, 79372, 74314],
      kHp: <int>[1976, 2149, 1876],
      kAdv: <double>[1.0, 1.0, 1.0],
      kStun: <double>[0.25, 0.25, 0.25],
    );

    final shatter = ShatterShieldConfig(
      baseHp: 100,
      bonusHp: 20,
      elementMatch: const <bool>[true, true, true],
    );

    int seed = 123456;
    for (final mode in FightMode.values) {
      final debug = DebugSimulator.run(
        pre,
        mode: mode,
        labels: const <String, String>{},
        shatter: shatter,
        cycloneUseGemsForSpecials: false,
        seed: seed++,
      );

      await _writeJson(mode.name, <String, Object?>{
        'mode': mode.name,
        'seed': seed - 1,
        'points': debug.points,
        'pre': pre.toJson(),
        'shatter': shatter.toJson(),
        'lines': debug.lines,
      });
    }
  });
}
