import 'dart:async';
import 'dart:isolate';

import '../data/config_models.dart';
import '../util/war_calc.dart';

typedef WarIsolateProgress = void Function(int done, int total);

Future<WarPlan> computeWarPlanInIsolate({
  required int milestonePoints,
  required int pointsPerAttackValue,
  required int pointsPerPowerAttackValue,
  required int availableEnergy,
  required List<ElixirInventoryItem> elixirs,
  required WarAttackStrategy strategy,
  required int forcedPowerAttacks,
  required WarIsolateProgress onProgress,
}) async {
  final rp = ReceivePort();
  final err = ReceivePort();
  final exit = ReceivePort();
  final completer = Completer<WarPlan>();
  Isolate? isolate;

  void cleanup() {
    rp.close();
    err.close();
    exit.close();
    isolate?.kill(priority: Isolate.immediate);
  }

  rp.listen((msg) {
    if (msg is! Map) return;
    final type = msg['type'];
    if (type == 'progress') {
      final done = (msg['done'] as num?)?.toInt() ?? 0;
      final total = (msg['total'] as num?)?.toInt() ?? 1;
      onProgress(done, total);
      return;
    }
    if (type == 'done' && !completer.isCompleted) {
      final json = (msg['plan'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{};
      completer.complete(WarPlan.fromJson(json));
      return;
    }
    if (type == 'error' && !completer.isCompleted) {
      completer.completeError(msg['error'] ?? 'War isolate error');
    }
  });

  err.listen((e) {
    if (!completer.isCompleted) {
      completer.completeError(e);
    }
  });

  exit.listen((_) {
    if (!completer.isCompleted) {
      completer.completeError('War isolate exited unexpectedly.');
    }
  });

  isolate = await Isolate.spawn(
    _warEntry,
    <String, Object?>{
      'sendPort': rp.sendPort,
      'milestonePoints': milestonePoints,
      'pointsPerAttackValue': pointsPerAttackValue,
      'pointsPerPowerAttackValue': pointsPerPowerAttackValue,
      'availableEnergy': availableEnergy,
      'elixirs': elixirs.map((e) => e.toJson()).toList(growable: false),
      'strategy': strategy.name,
      'forcedPowerAttacks': forcedPowerAttacks,
    },
    onError: err.sendPort,
    onExit: exit.sendPort,
  );

  return completer.future.whenComplete(cleanup);
}

void _warEntry(Map<String, Object?> m) {
  final send = m['sendPort'] as SendPort;
  try {
    final milestonePoints = (m['milestonePoints'] as num?)?.toInt() ?? 0;
    final pointsPerAttackValue =
        (m['pointsPerAttackValue'] as num?)?.toInt() ?? 0;
    final pointsPerPowerAttackValue =
        (m['pointsPerPowerAttackValue'] as num?)?.toInt() ?? 0;
    final availableEnergy = (m['availableEnergy'] as num?)?.toInt() ?? 0;
    final forcedPowerAttacks = (m['forcedPowerAttacks'] as num?)?.toInt() ?? 0;
    final strategy = WarAttackStrategy.values.firstWhere(
      (value) => value.name == (m['strategy'] as String?)?.trim(),
      orElse: () => WarAttackStrategy.optimizedMix,
    );
    final elixirs = ((m['elixirs'] as List?) ?? const <Object?>[])
        .whereType<Map>()
        .map((e) => ElixirInventoryItem.fromJson(e.cast<String, Object?>()))
        .toList(growable: false);

    final plan = computeWarPlan(
      milestonePoints: milestonePoints,
      pointsPerAttackValue: pointsPerAttackValue,
      pointsPerPowerAttackValue: pointsPerPowerAttackValue,
      availableEnergy: availableEnergy,
      elixirs: elixirs,
      strategy: strategy,
      forcedPowerAttacks: forcedPowerAttacks,
      onProgress: (done, total) {
        send.send({
          'type': 'progress',
          'done': done,
          'total': total,
        });
      },
    );

    send.send({
      'type': 'done',
      'plan': plan.toJson(),
    });
  } catch (e, st) {
    send.send({
      'type': 'error',
      'error': '$e',
      'stack': '$st',
    });
  }
}
