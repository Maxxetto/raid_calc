// lib/core/damage_model.dart
import 'dart:async';
import 'dart:math' as math;
import 'dart:isolate';
import 'dart:typed_data';

import '../core/engine/engine.dart'
    show
        BattleEngineSeed,
        BattleRuntimeKnobs,
        RaidBlitzBattleEngine,
        bossBaseConstForMeta;
import '../data/config_models.dart';
import '../data/pet_effect_models.dart';
import 'battle_outcome.dart';
import 'sim_types.dart';
import 'timing_acc.dart';

// Re-export per mantenere compatibilità con UI/debug che importano damage_model.dart
export 'sim_types.dart' show ShatterShieldConfig, FastRng;

class SimulationCancellationToken {
  bool _cancelled = false;

  bool get isCancelled => _cancelled;

  void cancel() {
    _cancelled = true;
  }
}

class SimulationCancelledException implements Exception {
  const SimulationCancelledException();
}

class DamageModel {
  // Costanti:
  // - Knight -> Boss: baseConst 164 (coerente con special/crit mostrati in Python).
  // - Boss -> Knight: baseConst derivata da cycleMultiplier (164 / cycleMultiplier),
  //   con fallback legacy 120 per compatibilita'.
  static const double _knightBaseConst = 164.0;

  static const double _defaultCritMult = 1.5;
  static const double _defaultSpecialMult = 3.25;

  // Progress throttle: ~0.187%
  static const int _progressSteps = 535;

  static double _advMul(double adv) {
    if ((adv - 1.5).abs() < 1e-9) return 1.5;
    if ((adv - 2.0).abs() < 1e-9) return 2.0;
    return 1.0;
  }

  static double _rawDamage({
    required double atk,
    required double def,
    required double baseConst,
    required double adv,
  }) {
    final d = (def <= 0) ? 1.0 : def;
    return ((atk / d) * baseConst) * _advMul(adv);
  }

  static int _clampInt(num v) {
    final x = v.toInt();
    if (x < 0) return 0;
    if (x > (1 << 30)) return (1 << 30);
    return x;
  }

  // Knight -> Boss
  static int _normalDamage(double raw) => _clampInt(raw.round());
  static int _critDamage(double raw, double critMult) =>
      _clampInt((raw * critMult).ceil());
  static int _specialDamage(double raw, double specialMult) {
    final base = raw.round();
    return _clampInt((base * specialMult).round());
  }

  // Boss -> Knight (allineato in-game):
  // - normal = floor(raw)
  // - crit = round(normal * critMult)
  static int _bossNormalDamage(double raw) => _clampInt(raw.floor());
  static int _bossCritDamage(double raw, double critMult) {
    final base = raw.floor();
    return _clampInt((base * critMult).round());
  }

  Precomputed precompute({
    required BossConfig boss,
    required List<double> kAtk,
    required List<double> kDef,
    required List<int> kHp,
    required List<double> kAdv,
    required List<double> kStun,
    double petAtk = 0.0,
    double petAdv = 1.0,
    PetSkillUsageMode petSkillUsage = PetSkillUsageMode.special1Only,
    List<PetResolvedEffect> petEffects = const <PetResolvedEffect>[],
  }) {
    final kNormal = <int>[];
    final kCrit = <int>[];
    final kSpec = <int>[];

    final bNormal = <int>[];
    final bCrit = <int>[];

    final critMult = boss.meta.criticalMultiplier <= 0
        ? _defaultCritMult
        : boss.meta.criticalMultiplier;
    // Raid and Blitz use the same knight special multiplier.
    final specialMult = boss.meta.raidSpecialMultiplier <= 0
        ? _defaultSpecialMult
        : boss.meta.raidSpecialMultiplier;

    final kCount = <int>[
      kAtk.length,
      kDef.length,
      kHp.length,
      kAdv.length,
      kStun.length,
    ].reduce((a, b) => a < b ? a : b);

    for (int i = 0; i < kCount; i++) {
      final advK = kAdv[i];
      final advB =
          (i < boss.meta.advVsKnights.length) ? boss.meta.advVsKnights[i] : 1.0;

      // Knight -> Boss
      final rawK = _rawDamage(
        atk: kAtk[i],
        def: boss.stats.defense,
        baseConst: _knightBaseConst,
        adv: advK,
      );
      kNormal.add(_normalDamage(rawK));
      kCrit.add(_critDamage(rawK, critMult));
      kSpec.add(_specialDamage(rawK, specialMult));

      // Boss -> Knight (scaling dedicato)
      final rawB = _rawDamage(
        atk: boss.stats.attack,
        def: kDef[i],
        baseConst: bossBaseConstForMeta(boss.meta),
        adv: advB,
      );
      bNormal.add(_bossNormalDamage(rawB));
      bCrit.add(_bossCritDamage(rawB, critMult));
    }

    final rawPet = _rawDamage(
      atk: petAtk <= 0 ? 0.0 : petAtk,
      def: boss.stats.defense,
      baseConst: _knightBaseConst,
      adv: petAdv,
    );
    final petNormal = (petAtk <= 0) ? 0 : _normalDamage(rawPet);
    final petCrit = (petAtk <= 0) ? 0 : _critDamage(rawPet, critMult);

    return Precomputed(
      meta: boss.meta,
      stats: boss.stats,
      kAtk: kAtk,
      kDef: kDef,
      kHp: kHp,
      kAdv: kAdv,
      kStun: kStun,
      petAtk: petAtk,
      petAdv: petAdv,
      petSkillUsage: petSkillUsage,
      petEffects: petEffects,
      kNormalDmg: kNormal,
      kCritDmg: kCrit,
      kSpecialDmg: kSpec,
      petNormalDmg: petNormal,
      petCritDmg: petCrit,
      bNormalDmg: bNormal,
      bCritDmg: bCrit,
    );
  }

  static ({
    Precomputed pre,
    BattleRuntimeKnobs runtimeKnobs,
  }) _buildRaidBlitzSimulationInput({
    required Precomputed pre,
    required ShatterShieldConfig shatter,
    required bool cycloneUseGemsForSpecials,
  }) {
    final runtimeKnobs = BattleRuntimeKnobs(
      cycloneAlwaysGemEnabled: cycloneUseGemsForSpecials,
      knightPetElementMatches: List<bool>.from(
        shatter.elementMatch,
        growable: false,
      ),
      petStrongVsBossByKnight: List<bool>.from(
        shatter.strongElementEw,
        growable: false,
      ),
    );
    return (
      pre: pre,
      runtimeKnobs: runtimeKnobs,
    );
  }

  Future<SimStats> simulate(
    Precomputed pre, {
    required int runs,
    required ShatterShieldConfig shatter,
    required bool withTiming,
    bool cycloneUseGemsForSpecials = true,
    void Function(int done, int total)? onProgress,
    SimulationCancellationToken? cancellationToken,
  }) async {
    final simInput = _buildRaidBlitzSimulationInput(
      pre: pre,
      shatter: shatter,
      cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
    );
    final engineSeed = BattleEngineSeed(
      pre: simInput.pre,
      runtimeKnobs: simInput.runtimeKnobs,
    );
    const engine = RaidBlitzBattleEngine();
    // Isolate > 50k per performance
    if (runs > 50000) {
      return _simulateIsolate(
        simInput.pre,
        runs: runs,
        shatter: shatter,
        withTiming: withTiming,
        cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
      );
    }

    void throwIfCancelled() {
      if (cancellationToken?.isCancelled ?? false) {
        throw const SimulationCancelledException();
      }
    }

    throwIfCancelled();

    final rng = FastRng(DateTime.now().microsecondsSinceEpoch & 0x7fffffff);

    final values = Int32List(runs);
    int sum = 0;
    int minV = 1 << 30;
    int maxV = 0;
    int gemsSpentSum = 0;

    final timing = withTiming ? TimingAcc() : null;

    // progress throttle (~0.187%)
    final step = (runs / _progressSteps).ceil().clamp(1, runs);

    for (int i = 0; i < runs; i++) {
      throwIfCancelled();
      final result = engine.runWithRng(
        engineSeed,
        rng,
        withTiming: withTiming,
        timing: timing,
      );
      final pts = result.points;
      gemsSpentSum += result.gemsSpent;

      values[i] = pts;
      sum += pts;

      if (pts < minV) minV = pts;
      if (pts > maxV) maxV = pts;

      if (onProgress != null && (i + 1) % step == 0) {
        onProgress(i + 1, runs);
        await Future<void>.delayed(Duration.zero);
      }
    }

    throwIfCancelled();

    final mean = runs > 0 ? (sum / runs).round() : 0;
    final median = _median(values);
    final series = _buildSimulationSeries(values);

    TimingStats? tstats;
    if (withTiming && timing != null && runs > 0) {
      tstats = timing.toStats(runs);
    }

    return SimStats(
      mean: mean,
      median: median,
      min: (runs == 0) ? 0 : minV,
      max: (runs == 0) ? 0 : maxV,
      meanGemsSpent: runs > 0 ? gemsSpentSum / runs : 0.0,
      timing: tstats,
      series: series,
    );
  }

  Future<SimStats> _simulateIsolate(
    Precomputed pre, {
    required int runs,
    required ShatterShieldConfig shatter,
    required bool withTiming,
    bool cycloneUseGemsForSpecials = true,
    void Function(int done, int total)? onProgress,
    SimulationCancellationToken? cancellationToken,
  }) async {
    final rp = ReceivePort();
    final isolate = await Isolate.spawn(_isolateEntry, rp.sendPort);

    final sp = await rp.first as SendPort;

    final resp = ReceivePort();
    sp.send(<String, Object?>{
      'type': 'run',
      'replyTo': resp.sendPort,
      'pre': pre.toJson(),
      'runs': runs,
      'shatter': shatter.toJson(),
      'withTiming': withTiming,
      'cycloneUseGemsForSpecials': cycloneUseGemsForSpecials,
    });

    final values = Int32List(runs);

    int sum = 0;
    int minV = 1 << 30;
    int maxV = 0;
    int gemsSpentSum = 0;

    TimingStats? timing;
    final done = Completer<void>();
    late final StreamSubscription<Object?> sub;
    Timer? cancelPoll;

    sub = resp.listen((msg) {
      if (done.isCompleted) return;
      final m = (msg as Map).cast<String, Object?>();

      final type = m['type'] as String;
      if (type == 'progress') {
        final progressDone = (m['done'] as num).toInt();
        if (onProgress != null) onProgress(progressDone, runs);
        return;
      }

      if (type == 'result') {
        final raw = (m['values'] as Uint8List);
        values.buffer.asUint8List().setRange(0, raw.length, raw);

        sum = (m['sum'] as num).toInt();
        minV = (m['min'] as num).toInt();
        maxV = (m['max'] as num).toInt();
        gemsSpentSum = (m['gemsSpentSum'] as num?)?.toInt() ?? 0;

        final t = m['timing'];
        if (t is Map) {
          timing = TimingStats.fromJson(t.cast<String, Object?>());
        }
        done.complete();
      }
    });

    cancelPoll = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!(cancellationToken?.isCancelled ?? false)) return;
      isolate.kill(priority: Isolate.immediate);
      if (!done.isCompleted) {
        done.completeError(const SimulationCancelledException());
      }
    });

    try {
      await done.future;
    } finally {
      cancelPoll.cancel();
      await sub.cancel();
      resp.close();
      rp.close();
      isolate.kill(priority: Isolate.immediate);
    }

    final mean = runs > 0 ? (sum / runs).round() : 0;
    final median = _median(values);
    final series = _buildSimulationSeries(values);

    return SimStats(
      mean: mean,
      median: median,
      min: (runs == 0) ? 0 : minV,
      max: (runs == 0) ? 0 : maxV,
      meanGemsSpent: runs > 0 ? gemsSpentSum / runs : 0.0,
      timing: timing,
      series: series,
    );
  }

  static void _isolateEntry(SendPort main) {
    final rp = ReceivePort();
    main.send(rp.sendPort);

    rp.listen((msg) {
      final req = (msg as Map).cast<String, Object?>();

      final type = req['type'] as String;
      if (type != 'run') return;

      final reply = req['replyTo'] as SendPort;

      final pre =
          Precomputed.fromJson((req['pre'] as Map).cast<String, Object?>());
      final runs = (req['runs'] as num).toInt();

      final sh = (req['shatter'] as Map).cast<String, Object?>();
      final shatter = ShatterShieldConfig.fromJson(sh);

      final withTiming = (req['withTiming'] as bool?) ?? false;
      final cycloneUseGemsForSpecials =
          (req['cycloneUseGemsForSpecials'] as bool?) ?? true;
      final simInput = _buildRaidBlitzSimulationInput(
        pre: pre,
        shatter: shatter,
        cycloneUseGemsForSpecials: cycloneUseGemsForSpecials,
      );
      final engineSeed = BattleEngineSeed(
        pre: simInput.pre,
        runtimeKnobs: simInput.runtimeKnobs,
      );
      const engine = RaidBlitzBattleEngine();

      final rng = FastRng(DateTime.now().microsecondsSinceEpoch & 0x7fffffff);

      final values = Int32List(runs);
      int sum = 0;
      int minV = 1 << 30;
      int maxV = 0;
      int gemsSpentSum = 0;

      final timing = withTiming ? TimingAcc() : null;

      // progress throttle (~0.187%)
      final step = (runs / _progressSteps).ceil().clamp(1, runs);

      for (int i = 0; i < runs; i++) {
        final result = engine.runWithRng(
          engineSeed,
          rng,
          withTiming: withTiming,
          timing: timing,
        );
        final pts = result.points;
        gemsSpentSum += result.gemsSpent;

        values[i] = pts;
        sum += pts;

        if (pts < minV) minV = pts;
        if (pts > maxV) maxV = pts;

        if ((i + 1) % step == 0) {
          reply.send(<String, Object?>{
            'type': 'progress',
            'done': i + 1,
            'total': runs,
          });
        }
      }

      TimingStats? tstats;
      if (withTiming && timing != null && runs > 0) {
        tstats = timing.toStats(runs);
      }

      reply.send(<String, Object?>{
        'type': 'result',
        'values': values.buffer.asUint8List(),
        'sum': sum,
        'min': (runs == 0) ? 0 : minV,
        'max': (runs == 0) ? 0 : maxV,
        'gemsSpentSum': gemsSpentSum,
        'timing': tstats?.toJson(),
      });
    });
  }

  static int _median(Int32List values) {
    if (values.isEmpty) return 0;
    final copy = Int32List.fromList(values);
    copy.sort();
    return copy[copy.length ~/ 2];
  }

  static int _recommendedCheckpointEvery(int runs) {
    if (runs <= 0) return 500;
    if (runs <= 20000) return 500;
    return 1000;
  }

  static int _recommendedHistogramBinCount(int runs) {
    if (runs <= 0) return 12;
    if (runs <= 1000) return 12;
    if (runs <= 10000) return 16;
    if (runs <= 50000) return 20;
    return 24;
  }

  static SimulationHistogram? _buildSimulationHistogram(Int32List values) {
    if (values.isEmpty) return null;

    var minV = values.first;
    var maxV = values.first;
    for (int i = 1; i < values.length; i++) {
      final value = values[i];
      if (value < minV) minV = value;
      if (value > maxV) maxV = value;
    }

    if (minV == maxV) {
      return SimulationHistogram(
        bins: <SimulationHistogramBin>[
          SimulationHistogramBin(
            lowerBound: minV,
            upperBound: maxV,
            count: values.length,
          ),
        ],
      );
    }

    final preferredBinCount = _recommendedHistogramBinCount(values.length);
    final span = (maxV - minV) + 1;
    final binSize = math.max(1, (span / preferredBinCount).ceil());
    final actualBinCount = (((maxV - minV) / binSize).floor()) + 1;
    final counts = List<int>.filled(actualBinCount, 0, growable: false);

    for (final value in values) {
      final rawIndex = ((value - minV) / binSize).floor();
      final index = rawIndex.clamp(0, actualBinCount - 1);
      counts[index] += 1;
    }

    final bins = List<SimulationHistogramBin>.generate(
      actualBinCount,
      (index) {
        final lowerBound = minV + (index * binSize);
        final upperBound = index == actualBinCount - 1
            ? maxV
            : math.min(maxV, lowerBound + binSize - 1);
        return SimulationHistogramBin(
          lowerBound: lowerBound,
          upperBound: upperBound,
          count: counts[index],
        );
      },
      growable: false,
    );

    return SimulationHistogram(bins: bins);
  }

  static SimulationSeries? _buildSimulationSeries(Int32List values) {
    if (values.isEmpty) return null;
    final checkpointEvery = _recommendedCheckpointEvery(values.length);
    final checkpoints = <SimulationCheckpoint>[];
    var sum = 0;
    var minV = 1 << 30;
    var maxV = 0;

    for (int i = 0; i < values.length; i++) {
      final pts = values[i];
      sum += pts;
      if (pts < minV) minV = pts;
      if (pts > maxV) maxV = pts;

      final runIndex = i + 1;
      final isInterval = runIndex % checkpointEvery == 0;
      final isLast = runIndex == values.length;
      if (!isInterval && !isLast) continue;

      checkpoints.add(
        SimulationCheckpoint(
          runIndex: runIndex,
          sampledScore: pts,
          cumulativeMean: (sum / runIndex).round(),
          cumulativeMin: minV,
          cumulativeMax: maxV,
        ),
      );
    }

    return SimulationSeries(
      checkpointEvery: checkpointEvery,
      totalRuns: values.length,
      checkpoints: checkpoints,
      histogram: _buildSimulationHistogram(values),
    );
  }
}
