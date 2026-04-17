// lib/core/epic_isolate.dart
//
// Runs Epic Boss simulation inside an isolate to keep UI responsive.

import 'dart:async';
import 'dart:isolate';

import '../data/config_models.dart';
import '../data/pet_effect_models.dart';
import 'epic_simulator.dart';
import 'sim_types.dart';

Future<List<Map<String, Object?>>> runEpicSimulationInIsolate({
  required Map<int, EpicBossRow> table,
  required BossMeta meta,
  required List<EpicKnight> knights,
  required double petAtk,
  required double petAdv,
  required PetSkillUsageMode petSkillUsage,
  required List<PetResolvedEffect> petEffects,
  required int threshold,
  required int runsPerLevel,
  required FightMode mode,
  required ShatterShieldConfig shatter,
  bool cycloneUseGemsForSpecials = true,
  required void Function(double done, int total) onProgress,
}) async {
  final receive = ReceivePort();
  final errorPort = ReceivePort();
  final exitPort = ReceivePort();

  Isolate? isolate;
  final completer = Completer<List<Map<String, Object?>>>();

  void cleanup() {
    receive.close();
    errorPort.close();
    exitPort.close();
    isolate?.kill(priority: Isolate.immediate);
  }

  receive.listen((message) {
    if (message is! Map) return;
    final type = message['type'];
    if (type == 'progress') {
      final done = (message['done'] as num?)?.toDouble() ?? 0.0;
      final total = (message['total'] as num?)?.toInt() ?? 100;
      onProgress(done, total);
      return;
    }
    if (type == 'result') {
      final raw = (message['levels'] as List?)?.cast<Map>() ?? const [];
      final levels =
          raw.map((e) => e.cast<String, Object?>()).toList(growable: false);
      completer.complete(levels);
      cleanup();
      return;
    }
    if (type == 'error') {
      completer.completeError(message['error'] ?? 'Epic isolate error');
      cleanup();
    }
  });

  errorPort.listen((message) {
    if (!completer.isCompleted) {
      completer.completeError(message);
    }
    cleanup();
  });

  exitPort.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError('Epic isolate exited unexpectedly.');
    }
    cleanup();
  });

  final request = <String, Object?>{
    'table': table.values.map((e) => e.toJson()).toList(growable: false),
    'meta': meta.toJson(),
    'knights': knights
        .map(
          (k) => <String, Object?>{
            'atk': k.atk,
            'def': k.def,
            'hp': k.hp,
            'adv': k.adv,
            'stun': k.stun,
            'elementMatch': k.elementMatch,
          },
        )
        .toList(growable: false),
    'pet': <String, Object?>{
      'atk': petAtk,
      'adv': petAdv,
      'skillUsage': petSkillUsage.name,
      'effects': petEffects.map((e) => e.toJson()).toList(growable: false),
    },
    'threshold': threshold,
    'runsPerLevel': runsPerLevel,
    'mode': mode.name,
    'cycloneUseGemsForSpecials': cycloneUseGemsForSpecials,
    'shatter': <String, Object?>{
      'baseHp': shatter.baseHp,
      'bonusHp': shatter.bonusHp,
      'elementMatch': shatter.elementMatch,
      'strongElementEw': shatter.strongElementEw,
    },
  };

  isolate = await Isolate.spawn(
    _epicIsolateEntry,
    <String, Object?>{
      'sendPort': receive.sendPort,
      'request': request,
    },
    onError: errorPort.sendPort,
    onExit: exitPort.sendPort,
  );

  return completer.future;
}

Future<void> _epicIsolateEntry(Map<String, Object?> payload) async {
  final sendPort = payload['sendPort'] as SendPort?;
  final req = (payload['request'] as Map?)?.cast<String, Object?>() ?? const {};
  if (sendPort == null) return;

  try {
    final meta =
        BossMeta.fromJson((req['meta'] as Map).cast<String, Object?>());
    final tableRaw = (req['table'] as List?)?.cast<Object?>() ?? const [];
    final table = <int, EpicBossRow>{};
    for (final row in tableRaw.whereType<Map>()) {
      final e = EpicBossRow.fromJson(row.cast<String, Object?>());
      table[e.level] = e;
    }

    final knightsRaw = (req['knights'] as List?)?.cast<Object?>() ?? const [];
    final knights = <EpicKnight>[];
    for (final row in knightsRaw.whereType<Map>()) {
      final m = row.cast<String, Object?>();
      knights.add(
        EpicKnight(
          atk: (m['atk'] as num?)?.toDouble() ?? 0.0,
          def: (m['def'] as num?)?.toDouble() ?? 1.0,
          hp: (m['hp'] as num?)?.toInt() ?? 1,
          adv: (m['adv'] as num?)?.toDouble() ?? 1.0,
          stun: (m['stun'] as num?)?.toDouble() ?? 0.0,
          elementMatch: (m['elementMatch'] as bool?) ?? false,
        ),
      );
    }

    final shMap = (req['shatter'] as Map?)?.cast<String, Object?>() ?? const {};
    final petMap = (req['pet'] as Map?)?.cast<String, Object?>() ?? const {};
    final shatter = ShatterShieldConfig(
      baseHp: (shMap['baseHp'] as num?)?.toInt() ?? 0,
      bonusHp: (shMap['bonusHp'] as num?)?.toInt() ?? 0,
      elementMatch: (shMap['elementMatch'] as List?)?.whereType<bool>().toList(
                growable: false,
              ) ??
          const <bool>[],
      strongElementEw:
          (shMap['strongElementEw'] as List?)?.whereType<bool>().toList(
                    growable: false,
                  ) ??
              const <bool>[],
    );

    final modeName = (req['mode'] as String?) ?? FightMode.normal.name;
    final mode = FightMode.values.firstWhere(
      (e) => e.name == modeName,
      orElse: () => FightMode.normal,
    );

    final threshold = (req['threshold'] as num?)?.toInt() ?? 80;
    final runsPerLevel = (req['runsPerLevel'] as num?)?.toInt() ?? 1000;
    final cycloneUseGemsForSpecials =
        (req['cycloneUseGemsForSpecials'] as bool?) ?? true;
    final petAtk = (petMap['atk'] as num?)?.toDouble() ?? 0.0;
    final petAdv = (petMap['adv'] as num?)?.toDouble() ?? 1.0;
    final petSkillUsage = PetSkillUsageMode.values.firstWhere(
      (mode) => mode.name == (petMap['skillUsage'] as String?)?.trim(),
      orElse: () => PetSkillUsageMode.special1Only,
    );
    final petEffects = ((petMap['effects'] as List?) ?? const <Object?>[])
        .whereType<Map>()
        .map((e) => PetResolvedEffect.fromJson(e.cast<String, Object?>()))
        .toList(growable: false);

    final results = await EpicSimulator.runThresholdSimulation(
      table: table,
      meta: meta,
      knights: knights,
      petAtk: petAtk,
      petAdv: petAdv,
      petSkillUsage: petSkillUsage,
      petEffects: petEffects,
      threshold: threshold,
      runsPerLevel: runsPerLevel,
      mode: mode,
      shatter: shatter,
      cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
      onProgress: (done, total) {
        sendPort.send(<String, Object?>{
          'type': 'progress',
          'done': done,
          'total': total,
        });
      },
      yieldToUi: false,
    );

    final levels = results.levels
        .map(
          (e) => <String, Object?>{
            'level': e.level,
            'missing': e.missing,
            'knightsUsed': e.knightsUsed,
            'winRates': e.winRates,
          },
        )
        .toList(growable: false);

    sendPort.send(<String, Object?>{
      'type': 'result',
      'levels': levels,
    });
  } catch (e) {
    sendPort.send(<String, Object?>{
      'type': 'error',
      'error': e.toString(),
    });
  }
}
