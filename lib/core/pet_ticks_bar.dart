import '../data/config_models.dart';
import 'debug/debug_hooks.dart';
import 'sim_types.dart';

enum PetTicksBarPolicy {
  special1Only,
  special2Only,
  cycleSpecial1ThenSpecial2,
  special2ThenSpecial1,
  doubleSpecial2ThenSpecial1,
}

extension PetTicksBarPolicyFromUsage on PetTicksBarPolicy {
  static PetTicksBarPolicy fromSkillUsage(PetSkillUsageMode mode) =>
      switch (mode) {
        PetSkillUsageMode.special1Only => PetTicksBarPolicy.special1Only,
        PetSkillUsageMode.special2Only => PetTicksBarPolicy.special2Only,
        PetSkillUsageMode.cycleSpecial1Then2 =>
          PetTicksBarPolicy.cycleSpecial1ThenSpecial2,
        PetSkillUsageMode.special2ThenSpecial1 =>
          PetTicksBarPolicy.special2ThenSpecial1,
        PetSkillUsageMode.doubleSpecial2ThenSpecial1 =>
          PetTicksBarPolicy.doubleSpecial2ThenSpecial1,
      };

  PetSpecialCastKind nextCastForIndex(int castIndex) => switch (this) {
        PetTicksBarPolicy.special1Only => PetSpecialCastKind.special1,
        PetTicksBarPolicy.special2Only => PetSpecialCastKind.special2,
        PetTicksBarPolicy.cycleSpecial1ThenSpecial2 => castIndex.isEven
            ? PetSpecialCastKind.special1
            : PetSpecialCastKind.special2,
        PetTicksBarPolicy.special2ThenSpecial1 => castIndex == 0
            ? PetSpecialCastKind.special2
            : PetSpecialCastKind.special1,
        PetTicksBarPolicy.doubleSpecial2ThenSpecial1 => castIndex < 2
            ? PetSpecialCastKind.special2
            : PetSpecialCastKind.special1,
      };
}

class PetTicksBarRuntime {
  PetTicksBarRuntime({
    required this.config,
    required this.policy,
    this.requiredSpecial2BeforeSpecial1 = 0,
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
  final PetTicksBarPolicy policy;
  final int requiredSpecial2BeforeSpecial1;
  final DebugPetBarHook? _debug;

  int ticks;
  int totalCasts = 0;
  int special2Casts = 0;
  int _pendingCast = 0; // 0=none, 1=special1, 2=special2

  bool get enabled => config.enabled;
  int get maxTicks => config.ticksPerState * 2;

  PetSpecialCastKind get _desiredCast {
    if (special2Casts < requiredSpecial2BeforeSpecial1) {
      return PetSpecialCastKind.special2;
    }
    return policy.nextCastForIndex(totalCasts);
  }

  PetSpecialCastKind? consumeQueuedCast() {
    if (!enabled || _pendingCast == 0) return null;
    final before = ticks;
    final cast = (_pendingCast == 1)
        ? PetSpecialCastKind.special1
        : PetSpecialCastKind.special2;
    if (cast == PetSpecialCastKind.special2) {
      special2Casts += 1;
    }
    totalCasts += 1;
    _pendingCast = 0;
    ticks = 0;
    _debug?.onPetBarCast(
      cast: cast,
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

    final base = _sample(config.petKnightBase, rng);
    int add = 0;
    if (knightMiss && petMiss) {
      add = 0;
    } else if (knightMiss && !petMiss) {
      add = 1;
    } else if (!knightMiss && petMiss) {
      add = base - 1;
      if (add < 0) add = 0;
    } else {
      add = base;
      if (petCrit && config.petCritPlusOneProb > 0) {
        final target =
            (config.petCritPlusOneProb * 1000).round().clamp(0, 1000);
        if (rng.nextPermil() < target) {
          add += 1;
        }
      }
    }

    _addTicks(
      add,
      source: 'p+k',
    );
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

  void _addTicks(
    int add, {
    required String source,
  }) {
    if (add < 0) add = 0;
    final before = ticks;
    final after = (ticks + add).clamp(0, maxTicks);
    ticks = after;
    _debug?.onPetBarFill(
      source: source,
      add: add,
      before: before,
      after: after,
      max: maxTicks,
    );
    _maybeQueueCast();
  }

  void _maybeQueueCast() {
    if (!enabled || _pendingCast != 0) return;

    final cast = _desiredCast;
    final threshold =
        cast == PetSpecialCastKind.special2 ? maxTicks : config.ticksPerState;
    if (ticks >= threshold) {
      _pendingCast = cast == PetSpecialCastKind.special2 ? 2 : 1;
      _debug?.onPetBarQueued(
        cast: cast,
        ticks: ticks,
      );
    }
  }

  static int _sample(List<WeightedTick> dist, FastRng rng) {
    if (dist.isEmpty) return 0;
    double sum = 0.0;
    for (final e in dist) {
      if (e.weight > 0 && e.weight.isFinite) {
        sum += e.weight;
      }
    }
    if (sum <= 0) return dist.last.ticks;

    final roll = rng.nextPermil();
    final target = (roll / 1000.0) * sum;
    double acc = 0.0;
    for (final e in dist) {
      final w = (e.weight > 0 && e.weight.isFinite) ? e.weight : 0.0;
      acc += w;
      if (target <= acc) return e.ticks;
    }
    return dist.last.ticks;
  }
}
