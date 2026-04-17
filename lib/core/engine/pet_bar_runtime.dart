import 'package:flutter/foundation.dart';

import '../../data/config_models.dart';
import '../debug/debug_hooks.dart';
import '../sim_types.dart';
import 'pet_usage_policy.dart';

@immutable
class QueuedPetCast {
  final PetSpecialCastKind cast;
  final int queuedAtTicks;
  final int requiredTicks;
  final int castIndex;

  const QueuedPetCast({
    required this.cast,
    required this.queuedAtTicks,
    required this.requiredTicks,
    required this.castIndex,
  });
}

class PetBarRuntimeState {
  PetBarRuntimeState({
    required this.config,
    required this.policy,
    this.requiredSpecial2BeforeSpecial1 = 0,
    this.knightActionChargeMultiplier = 1.0,
    DebugPetBarHook? debug,
  })  : _debug = debug,
        ticks = config.startTicks.clamp(0, config.ticksPerState * 2) {
    if (!config.enabled) return;
    _debug?.onPetBarInit(
      ticks: ticks,
      ticksPerState: config.ticksPerState,
    );
    _maybeQueueCast();
  }

  final PetTicksBarConfig config;
  final PetUsagePolicy policy;
  final int requiredSpecial2BeforeSpecial1;
  final double knightActionChargeMultiplier;
  final DebugPetBarHook? _debug;

  int ticks;
  int totalCasts = 0;
  int special2Casts = 0;
  QueuedPetCast? _pendingCast;

  bool get enabled => config.enabled;
  int get ticksPerState => config.ticksPerState;
  int get maxTicks => config.ticksPerState * 2;
  QueuedPetCast? get pendingCast => _pendingCast;

  PetSpecialCastKind get _desiredCast {
    if (special2Casts < requiredSpecial2BeforeSpecial1) {
      return PetSpecialCastKind.special2;
    }
    return policy.nextCastForIndex(totalCasts);
  }

  QueuedPetCast? consumeQueuedCast() {
    if (!enabled || _pendingCast == null) return null;
    final cast = _pendingCast!;
    if (cast.cast == PetSpecialCastKind.special2) {
      special2Casts += 1;
    }
    totalCasts += 1;
    _pendingCast = null;
    final before = ticks;
    ticks = 0;
    _debug?.onPetBarCast(
      cast: cast.cast,
      before: before,
      after: ticks,
    );
    return cast;
  }

  void onKnightPetResolved({
    required bool knightMiss,
    required bool petMiss,
    required bool petCrit,
    required FastRng rng,
  }) {
    if (!enabled) return;

    final base = _scaleKnightTicks(_sample(config.petKnightBase, rng));
    int add = 0;
    if (knightMiss && petMiss) {
      add = 0;
    } else if (knightMiss && !petMiss) {
      add = _scaleKnightTicks(1);
    } else if (!knightMiss && petMiss) {
      add = base - _scaleKnightTicks(1);
      if (add < 0) add = 0;
    } else {
      add = base;
      if (petCrit && config.petCritPlusOneProb > 0) {
        final target =
            (config.petCritPlusOneProb * 1000).round().clamp(0, 1000);
        if (rng.nextPermil() < target) {
          add += _scaleKnightTicks(1);
        }
      }
    }

    _addTicks(add, source: 'p+k');
  }

  void onBossNormal(FastRng rng) {
    if (!enabled) return;
    _addTicks(_sample(config.bossNormal, rng), source: 'boss_normal');
  }

  void onBossSpecial(FastRng rng) {
    if (!enabled) return;
    _addTicks(_sample(config.bossSpecial, rng), source: 'boss_special');
  }

  void onBossMiss(FastRng rng) {
    if (!enabled) return;
    _addTicks(_sample(config.bossMiss, rng), source: 'boss_miss');
  }

  void onBossStun(FastRng rng) {
    if (!enabled) return;
    _addTicks(_sample(config.stun, rng), source: 'stun');
  }

  int requiredTicksForCast(PetSpecialCastKind cast) =>
      cast == PetSpecialCastKind.special2 ? maxTicks : config.ticksPerState;

  int _scaleKnightTicks(int baseTicks) {
    if (baseTicks <= 0) return 0;
    final scaled = (baseTicks * knightActionChargeMultiplier).round();
    return scaled < 0 ? 0 : scaled;
  }

  void _addTicks(
    int add, {
    required String source,
  }) {
    if (add < 0) add = 0;
    final before = ticks;
    ticks = (ticks + add).clamp(0, maxTicks);
    _debug?.onPetBarFill(
      source: source,
      add: add,
      before: before,
      after: ticks,
      max: maxTicks,
    );
    _maybeQueueCast();
  }

  void _maybeQueueCast() {
    if (!enabled || _pendingCast != null) return;
    final cast = _desiredCast;
    final threshold = requiredTicksForCast(cast);
    if (ticks < threshold) return;
    _pendingCast = QueuedPetCast(
      cast: cast,
      queuedAtTicks: ticks,
      requiredTicks: threshold,
      castIndex: totalCasts,
    );
    _debug?.onPetBarQueued(
      cast: cast,
      ticks: ticks,
    );
  }

  static int _sample(List<WeightedTick> dist, FastRng rng) {
    if (dist.isEmpty) return 0;
    double sum = 0.0;
    for (final entry in dist) {
      if (entry.weight > 0 && entry.weight.isFinite) {
        sum += entry.weight;
      }
    }
    if (sum <= 0) return dist.last.ticks;

    final roll = rng.nextPermil();
    final target = (roll / 1000.0) * sum;
    double acc = 0.0;
    for (final entry in dist) {
      final weight =
          (entry.weight > 0 && entry.weight.isFinite) ? entry.weight : 0.0;
      acc += weight;
      if (target <= acc) return entry.ticks;
    }
    return dist.last.ticks;
  }
}
