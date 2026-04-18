import 'dart:math' as math;

import '../data/config_models.dart';

typedef WarProgressCallback = void Function(int done, int total);

enum WarAttackStrategy {
  normalOnly,
  optimizedMix,
  powerAttackOnly,
  fixedPowerAttacks,
}

class WarGemPlan {
  final int energyNeeded;
  final int energyBought;
  final int gems;
  final int packs4;
  final int packs20;
  final int packs40;
  final int leftover;

  const WarGemPlan({
    required this.energyNeeded,
    required this.energyBought,
    required this.gems,
    required this.packs4,
    required this.packs20,
    required this.packs40,
    required this.leftover,
  });

  Map<String, Object?> toJson() {
    return {
      'energyNeeded': energyNeeded,
      'energyBought': energyBought,
      'gems': gems,
      'packs4': packs4,
      'packs20': packs20,
      'packs40': packs40,
      'leftover': leftover,
    };
  }

  factory WarGemPlan.fromJson(Map<String, Object?> j) {
    int v(String k) => (j[k] as num?)?.toInt() ?? 0;
    return WarGemPlan(
      energyNeeded: v('energyNeeded'),
      energyBought: v('energyBought'),
      gems: v('gems'),
      packs4: v('packs4'),
      packs20: v('packs20'),
      packs40: v('packs40'),
      leftover: v('leftover'),
    );
  }
}

class WarPlan {
  final int pointsPerAttack;
  final int pointsPerPowerAttack;
  final int normalAttacks;
  final int powerAttacks;
  final WarGemPlan gems;
  final WarBoostSummary boostSummary;
  final List<WarElixirUsage> elixirUsages;

  const WarPlan({
    required this.pointsPerAttack,
    required this.pointsPerPowerAttack,
    required this.normalAttacks,
    required this.powerAttacks,
    required this.gems,
    this.boostSummary = const WarBoostSummary(),
    this.elixirUsages = const <WarElixirUsage>[],
  });

  int get attacks => normalAttacks + powerAttacks;

  int get totalEnergy => normalAttacks + (powerAttacks * 4);

  Map<String, Object?> toJson() {
    return {
      'pointsPerAttack': pointsPerAttack,
      'pointsPerPowerAttack': pointsPerPowerAttack,
      'normalAttacks': normalAttacks,
      'powerAttacks': powerAttacks,
      'gems': gems.toJson(),
      'boostSummary': boostSummary.toJson(),
      'elixirUsages':
          elixirUsages.map((e) => e.toJson()).toList(growable: false),
    };
  }

  factory WarPlan.fromJson(Map<String, Object?> j) {
    int v(String k) => (j[k] as num?)?.toInt() ?? 0;
    return WarPlan(
      pointsPerAttack: v('pointsPerAttack'),
      pointsPerPowerAttack: v('pointsPerPowerAttack'),
      normalAttacks: v('normalAttacks'),
      powerAttacks: v('powerAttacks'),
      gems: WarGemPlan.fromJson(
        ((j['gems'] as Map?)?.cast<String, Object?>()) ??
            const <String, Object?>{},
      ),
      boostSummary: WarBoostSummary.fromJson(
        ((j['boostSummary'] as Map?)?.cast<String, Object?>()) ??
            const <String, Object?>{},
      ),
      elixirUsages: ((j['elixirUsages'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((e) => WarElixirUsage.fromJson(e.cast<String, Object?>()))
          .toList(growable: false),
    );
  }
}

class WarBoostSummary {
  final int boostedNormalAttacks;
  final int boostedPowerAttacks;
  final int unboostedNormalAttacks;
  final int unboostedPowerAttacks;

  const WarBoostSummary({
    this.boostedNormalAttacks = 0,
    this.boostedPowerAttacks = 0,
    this.unboostedNormalAttacks = 0,
    this.unboostedPowerAttacks = 0,
  });

  int get boostedTotal => boostedNormalAttacks + boostedPowerAttacks;
  int get unboostedTotal => unboostedNormalAttacks + unboostedPowerAttacks;

  Map<String, Object?> toJson() {
    return {
      'boostedNormalAttacks': boostedNormalAttacks,
      'boostedPowerAttacks': boostedPowerAttacks,
      'unboostedNormalAttacks': unboostedNormalAttacks,
      'unboostedPowerAttacks': unboostedPowerAttacks,
    };
  }

  factory WarBoostSummary.fromJson(Map<String, Object?> j) {
    int v(String k) => (j[k] as num?)?.toInt() ?? 0;
    return WarBoostSummary(
      boostedNormalAttacks: v('boostedNormalAttacks'),
      boostedPowerAttacks: v('boostedPowerAttacks'),
      unboostedNormalAttacks: v('unboostedNormalAttacks'),
      unboostedPowerAttacks: v('unboostedPowerAttacks'),
    );
  }
}

class WarElixirUsage {
  final String name;
  final double scoreMultiplier;
  final int configuredAttacks;
  final int usedAttacks;
  final int boostedNormalAttacks;
  final int boostedPowerAttacks;

  const WarElixirUsage({
    required this.name,
    required this.scoreMultiplier,
    required this.configuredAttacks,
    required this.usedAttacks,
    required this.boostedNormalAttacks,
    required this.boostedPowerAttacks,
  });

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'scoreMultiplier': scoreMultiplier,
      'configuredAttacks': configuredAttacks,
      'usedAttacks': usedAttacks,
      'boostedNormalAttacks': boostedNormalAttacks,
      'boostedPowerAttacks': boostedPowerAttacks,
    };
  }

  factory WarElixirUsage.fromJson(Map<String, Object?> j) {
    int v(String k) => (j[k] as num?)?.toInt() ?? 0;
    return WarElixirUsage(
      name: (j['name'] as String?)?.trim() ?? '',
      scoreMultiplier: (j['scoreMultiplier'] as num?)?.toDouble() ?? 0.0,
      configuredAttacks: v('configuredAttacks'),
      usedAttacks: v('usedAttacks'),
      boostedNormalAttacks: v('boostedNormalAttacks'),
      boostedPowerAttacks: v('boostedPowerAttacks'),
    );
  }
}

WarPointsSet selectPoints({
  required WarPointsServer server,
  required bool stripBase,
}) {
  return stripBase ? server.strip : server.normal;
}

int pointsPerAttack({
  required WarPointsSet set,
  required bool frenzy,
  required bool powerAttack,
}) {
  if (frenzy && powerAttack) return set.frenzyPowerAttack;
  if (powerAttack) return set.powerAttack;
  if (frenzy) return set.frenzy;
  return set.base;
}

int boostedWarPoints({
  required int basePoints,
  required double scoreMultiplier,
}) {
  return (basePoints * (1.0 + scoreMultiplier)).round();
}

WarPlan computeWarPlan({
  required int milestonePoints,
  required int pointsPerAttackValue,
  required int pointsPerPowerAttackValue,
  int availableEnergy = 0,
  List<ElixirInventoryItem> elixirs = const <ElixirInventoryItem>[],
  WarAttackStrategy strategy = WarAttackStrategy.optimizedMix,
  int forcedPowerAttacks = 0,
  WarProgressCallback? onProgress,
}) {
  if (milestonePoints <= 0 ||
      (pointsPerAttackValue <= 0 && pointsPerPowerAttackValue <= 0)) {
    return WarPlan(
      pointsPerAttack: pointsPerAttackValue,
      pointsPerPowerAttack: pointsPerPowerAttackValue,
      normalAttacks: 0,
      powerAttacks: 0,
      gems: const WarGemPlan(
        energyNeeded: 0,
        energyBought: 0,
        gems: 0,
        packs4: 0,
        packs20: 0,
        packs40: 0,
        leftover: 0,
      ),
      boostSummary: const WarBoostSummary(),
      elixirUsages: const <WarElixirUsage>[],
    );
  }

  final available = availableEnergy < 0 ? 0 : availableEnergy;
  final resolvedStrategy = _resolveAttackStrategy(
    strategy: strategy,
    pointsPerAttackValue: pointsPerAttackValue,
    pointsPerPowerAttackValue: pointsPerPowerAttackValue,
  );
  final best = switch (resolvedStrategy) {
    WarAttackStrategy.normalOnly => _mixForFixedPowerAttacks(
        milestonePoints: milestonePoints,
        pointsPerAttackValue: pointsPerAttackValue,
        pointsPerPowerAttackValue: pointsPerPowerAttackValue,
        availableEnergy: available,
        forcedPowerAttacks: 0,
        elixirs: elixirs,
        onProgress: onProgress,
      ),
    WarAttackStrategy.powerAttackOnly => _mixForPowerAttackOnly(
        milestonePoints: milestonePoints,
        pointsPerPowerAttackValue: pointsPerPowerAttackValue,
        availableEnergy: available,
        elixirs: elixirs,
        onProgress: onProgress,
      ),
    WarAttackStrategy.fixedPowerAttacks => _mixForFixedPowerAttacks(
        milestonePoints: milestonePoints,
        pointsPerAttackValue: pointsPerAttackValue,
        pointsPerPowerAttackValue: pointsPerPowerAttackValue,
        availableEnergy: available,
        forcedPowerAttacks: forcedPowerAttacks,
        elixirs: elixirs,
        onProgress: onProgress,
      ),
    WarAttackStrategy.optimizedMix => _bestAttackMix(
        milestonePoints: milestonePoints,
        pointsPerAttackValue: pointsPerAttackValue,
        pointsPerPowerAttackValue: pointsPerPowerAttackValue,
        availableEnergy: available,
        elixirs: elixirs,
        onProgress: onProgress,
      ),
  };

  return WarPlan(
    pointsPerAttack: pointsPerAttackValue,
    pointsPerPowerAttack: pointsPerPowerAttackValue,
    normalAttacks: best.normalAttacks,
    powerAttacks: best.powerAttacks,
    gems: best.gems,
    boostSummary: best.boostSummary,
    elixirUsages: best.elixirUsages,
  );
}

WarAttackStrategy _resolveAttackStrategy({
  required WarAttackStrategy strategy,
  required int pointsPerAttackValue,
  required int pointsPerPowerAttackValue,
}) {
  final hasNormal = pointsPerAttackValue > 0;
  final hasPower = pointsPerPowerAttackValue > 0;
  if (!hasPower) return WarAttackStrategy.normalOnly;
  if (!hasNormal) {
    return switch (strategy) {
      WarAttackStrategy.fixedPowerAttacks ||
      WarAttackStrategy.powerAttackOnly ||
      WarAttackStrategy.optimizedMix =>
        WarAttackStrategy.powerAttackOnly,
      WarAttackStrategy.normalOnly => WarAttackStrategy.powerAttackOnly,
    };
  }
  return strategy;
}

_AttackMix _mixForPowerAttackOnly({
  required int milestonePoints,
  required int pointsPerPowerAttackValue,
  required int availableEnergy,
  required List<ElixirInventoryItem> elixirs,
  WarProgressCallback? onProgress,
}) {
  if (pointsPerPowerAttackValue <= 0) {
    onProgress?.call(1, 1);
    return _zeroAttackMix();
  }

  final elixirSegments = _buildElixirSegments(elixirs);
  int hi = milestonePoints <= 0
      ? 0
      : (milestonePoints + pointsPerPowerAttackValue - 1) ~/
          pointsPerPowerAttackValue;
  if (hi < 0) hi = 0;
  int lo = 0;
  onProgress?.call(0, 1);
  while (lo < hi) {
    final mid = lo + ((hi - lo) >> 1);
    final score = _scoreMix(
      normalAttacks: 0,
      powerAttacks: mid,
      pointsPerAttackValue: 0,
      pointsPerPowerAttackValue: pointsPerPowerAttackValue,
      elixirSegments: elixirSegments,
    );
    if (score.totalPoints >= milestonePoints) {
      hi = mid;
    } else {
      lo = mid + 1;
    }
  }
  final detailed = _scoreMix(
    normalAttacks: 0,
    powerAttacks: lo,
    pointsPerAttackValue: 0,
    pointsPerPowerAttackValue: pointsPerPowerAttackValue,
    elixirSegments: elixirSegments,
    includeDetails: true,
  );
  if (detailed.totalPoints < milestonePoints) {
    onProgress?.call(1, 1);
    return _zeroAttackMix();
  }
  onProgress?.call(1, 1);
  return _finalizeFixedMix(
    normalAttacks: 0,
    powerAttacks: lo,
    availableEnergy: availableEnergy,
    detailed: detailed,
  );
}

_AttackMix _mixForFixedPowerAttacks({
  required int milestonePoints,
  required int pointsPerAttackValue,
  required int pointsPerPowerAttackValue,
  required int availableEnergy,
  required int forcedPowerAttacks,
  required List<ElixirInventoryItem> elixirs,
  WarProgressCallback? onProgress,
}) {
  final powerAttacks = forcedPowerAttacks < 0 ? 0 : forcedPowerAttacks;
  final elixirSegments = _buildElixirSegments(elixirs);
  onProgress?.call(0, 1);

  int normalAttacks = 0;
  if (pointsPerAttackValue <= 0) {
    final detailed = _scoreMix(
      normalAttacks: 0,
      powerAttacks: powerAttacks,
      pointsPerAttackValue: pointsPerAttackValue,
      pointsPerPowerAttackValue: pointsPerPowerAttackValue,
      elixirSegments: elixirSegments,
      includeDetails: true,
    );
    if (detailed.totalPoints < milestonePoints) {
      onProgress?.call(1, 1);
      return _zeroAttackMix();
    }
    onProgress?.call(1, 1);
    return _finalizeFixedMix(
      normalAttacks: 0,
      powerAttacks: powerAttacks,
      availableEnergy: availableEnergy,
      detailed: detailed,
    );
  }

  final powerOnlyScore = _scoreMix(
    normalAttacks: 0,
    powerAttacks: powerAttacks,
    pointsPerAttackValue: pointsPerAttackValue,
    pointsPerPowerAttackValue: pointsPerPowerAttackValue,
    elixirSegments: elixirSegments,
  );
  if (powerOnlyScore.totalPoints < milestonePoints) {
    final remaining = milestonePoints - powerOnlyScore.totalPoints;
    normalAttacks =
        (remaining + pointsPerAttackValue - 1) ~/ pointsPerAttackValue;
    if (normalAttacks < 0) normalAttacks = 0;

    int lo = 0;
    int hi = normalAttacks;
    while (lo < hi) {
      final mid = lo + ((hi - lo) >> 1);
      final score = _scoreMix(
        normalAttacks: mid,
        powerAttacks: powerAttacks,
        pointsPerAttackValue: pointsPerAttackValue,
        pointsPerPowerAttackValue: pointsPerPowerAttackValue,
        elixirSegments: elixirSegments,
      );
      if (score.totalPoints >= milestonePoints) {
        hi = mid;
      } else {
        lo = mid + 1;
      }
    }
    normalAttacks = lo;
  }

  final detailed = _scoreMix(
    normalAttacks: normalAttacks,
    powerAttacks: powerAttacks,
    pointsPerAttackValue: pointsPerAttackValue,
    pointsPerPowerAttackValue: pointsPerPowerAttackValue,
    elixirSegments: elixirSegments,
    includeDetails: true,
  );
  if (detailed.totalPoints < milestonePoints) {
    onProgress?.call(1, 1);
    return _zeroAttackMix();
  }
  onProgress?.call(1, 1);
  return _finalizeFixedMix(
    normalAttacks: normalAttacks,
    powerAttacks: powerAttacks,
    availableEnergy: availableEnergy,
    detailed: detailed,
  );
}

_AttackMix _finalizeFixedMix({
  required int normalAttacks,
  required int powerAttacks,
  required int availableEnergy,
  required _MixScore detailed,
}) {
  final totalEnergy = normalAttacks + (powerAttacks * 4);
  final attacks = normalAttacks + powerAttacks;
  final energyNeeded =
      totalEnergy > availableEnergy ? (totalEnergy - availableEnergy) : 0;
  return _AttackMix(
    normalAttacks: normalAttacks,
    powerAttacks: powerAttacks,
    gems: _minGemsForEnergy(energyNeeded),
    totalEnergy: totalEnergy,
    attacks: attacks,
    boostSummary: detailed.boostSummary,
    elixirUsages: detailed.elixirUsages,
  );
}

_AttackMix _zeroAttackMix() {
  return const _AttackMix(
    normalAttacks: 0,
    powerAttacks: 0,
    gems: WarGemPlan(
      energyNeeded: 0,
      energyBought: 0,
      gems: 0,
      packs4: 0,
      packs20: 0,
      packs40: 0,
      leftover: 0,
    ),
    totalEnergy: 0,
    attacks: 0,
    boostSummary: WarBoostSummary(),
    elixirUsages: <WarElixirUsage>[],
  );
}

class _AttackMix {
  final int normalAttacks;
  final int powerAttacks;
  final WarGemPlan gems;
  final int totalEnergy;
  final int attacks;
  final WarBoostSummary boostSummary;
  final List<WarElixirUsage> elixirUsages;

  const _AttackMix({
    required this.normalAttacks,
    required this.powerAttacks,
    required this.gems,
    required this.totalEnergy,
    required this.attacks,
    required this.boostSummary,
    required this.elixirUsages,
  });
}

class _ElixirSegment {
  final String name;
  final int configuredAttacks;
  final int slots;
  final double scoreMultiplier;

  const _ElixirSegment({
    required this.name,
    required this.configuredAttacks,
    required this.slots,
    required this.scoreMultiplier,
  });
}

class _MixScore {
  final int totalPoints;
  final WarBoostSummary boostSummary;
  final List<WarElixirUsage> elixirUsages;

  const _MixScore({
    required this.totalPoints,
    required this.boostSummary,
    required this.elixirUsages,
  });
}

_AttackMix _bestAttackMix({
  required int milestonePoints,
  required int pointsPerAttackValue,
  required int pointsPerPowerAttackValue,
  required int availableEnergy,
  required List<ElixirInventoryItem> elixirs,
  WarProgressCallback? onProgress,
}) {
  final hasNormal = pointsPerAttackValue > 0;
  final hasPower = pointsPerPowerAttackValue > 0;
  final elixirSegments = _buildElixirSegments(elixirs);

  int bestNormal = 0;
  int bestPower = 0;
  int bestEnergy = 1 << 30;
  int bestAttacks = 1 << 30;
  bool bestFound = false;
  WarGemPlan bestGems = WarGemPlan(
    energyNeeded: 1 << 30,
    energyBought: 1 << 30,
    gems: 1 << 30,
    packs4: 0,
    packs20: 0,
    packs40: 0,
    leftover: 0,
  );

  int startB = 0;
  int endB = 0;
  if (hasPower && hasNormal) {
    final maxB = (milestonePoints + pointsPerPowerAttackValue - 1) ~/
        pointsPerPowerAttackValue;
    startB = 0;
    endB = maxB;
  } else if (hasPower) {
    final onlyB = (milestonePoints + pointsPerPowerAttackValue - 1) ~/
        pointsPerPowerAttackValue;
    startB = onlyB;
    endB = onlyB;
  } else {
    startB = 0;
    endB = 0;
  }

  final total = (endB - startB + 1).clamp(1, 1 << 30);
  final emitEvery = (total / 500).ceil().clamp(1, total);
  onProgress?.call(0, total);
  int done = 0;

  for (int b = startB; b <= endB; b++) {
    int normalAttacks;
    if (!hasNormal) {
      final score = _scoreMix(
        normalAttacks: 0,
        powerAttacks: b,
        pointsPerAttackValue: pointsPerAttackValue,
        pointsPerPowerAttackValue: pointsPerPowerAttackValue,
        elixirSegments: elixirSegments,
      );
      if (score.totalPoints < milestonePoints) {
        done++;
        if (done == total || (done % emitEvery) == 0) {
          onProgress?.call(done, total);
        }
        continue;
      }
      normalAttacks = 0;
    } else {
      final powerPoints = b * pointsPerPowerAttackValue;
      final remaining = milestonePoints - powerPoints;
      int hi = (remaining <= 0)
          ? 0
          : (remaining + pointsPerAttackValue - 1) ~/ pointsPerAttackValue;
      if (hi < 0) hi = 0;
      int lo = 0;
      while (lo < hi) {
        final mid = lo + ((hi - lo) >> 1);
        final score = _scoreMix(
          normalAttacks: mid,
          powerAttacks: b,
          pointsPerAttackValue: pointsPerAttackValue,
          pointsPerPowerAttackValue: pointsPerPowerAttackValue,
          elixirSegments: elixirSegments,
        );
        if (score.totalPoints >= milestonePoints) {
          hi = mid;
        } else {
          lo = mid + 1;
        }
      }
      normalAttacks = lo;
    }

    final score = _scoreMix(
      normalAttacks: normalAttacks,
      powerAttacks: b,
      pointsPerAttackValue: pointsPerAttackValue,
      pointsPerPowerAttackValue: pointsPerPowerAttackValue,
      elixirSegments: elixirSegments,
    );
    if (score.totalPoints < milestonePoints) {
      done++;
      if (done == total || (done % emitEvery) == 0) {
        onProgress?.call(done, total);
      }
      continue;
    }

    final totalEnergy = normalAttacks + (b * 4);
    final attacks = normalAttacks + b;
    final energyNeeded =
        totalEnergy > availableEnergy ? (totalEnergy - availableEnergy) : 0;
    final gems = _minGemsForEnergy(energyNeeded);

    final better = !bestFound ||
        (gems.gems < bestGems.gems) ||
        (gems.gems == bestGems.gems && totalEnergy < bestEnergy) ||
        (gems.gems == bestGems.gems &&
            totalEnergy == bestEnergy &&
            attacks < bestAttacks);

    if (better) {
      bestFound = true;
      bestGems = gems;
      bestNormal = normalAttacks;
      bestPower = b;
      bestEnergy = totalEnergy;
      bestAttacks = attacks;
    }

    done++;
    if (done == total || (done % emitEvery) == 0) {
      onProgress?.call(done, total);
    }
  }

  if (!bestFound) {
    return _zeroAttackMix();
  }

  final detailed = _scoreMix(
    normalAttacks: bestNormal,
    powerAttacks: bestPower,
    pointsPerAttackValue: pointsPerAttackValue,
    pointsPerPowerAttackValue: pointsPerPowerAttackValue,
    elixirSegments: elixirSegments,
    includeDetails: true,
  );

  return _AttackMix(
    normalAttacks: bestNormal,
    powerAttacks: bestPower,
    gems: bestGems,
    totalEnergy: bestEnergy == 1 << 30 ? 0 : bestEnergy,
    attacks: bestAttacks == 1 << 30 ? 0 : bestAttacks,
    boostSummary: detailed.boostSummary,
    elixirUsages: detailed.elixirUsages,
  );
}

List<_ElixirSegment> _buildElixirSegments(List<ElixirInventoryItem> elixirs) {
  final out = <_ElixirSegment>[];
  for (final e in elixirs) {
    if (e.quantity <= 0) continue;
    if (!e.scoreMultiplier.isFinite || e.scoreMultiplier <= 0) continue;
    if (e.durationMinutes <= 0) continue;
    final configuredSlots = e.durationMinutes * e.quantity;
    if (configuredSlots <= 0) continue;
    out.add(
      _ElixirSegment(
        name: e.name,
        configuredAttacks: configuredSlots,
        slots: configuredSlots,
        scoreMultiplier: e.scoreMultiplier,
      ),
    );
  }
  return out;
}

_MixScore _scoreMix({
  required int normalAttacks,
  required int powerAttacks,
  required int pointsPerAttackValue,
  required int pointsPerPowerAttackValue,
  required List<_ElixirSegment> elixirSegments,
  bool includeDetails = false,
}) {
  if (normalAttacks < 0 || powerAttacks < 0) {
    return const _MixScore(
      totalPoints: 0,
      boostSummary: WarBoostSummary(),
      elixirUsages: <WarElixirUsage>[],
    );
  }

  if (elixirSegments.isEmpty) {
    final points = (normalAttacks * pointsPerAttackValue) +
        (powerAttacks * pointsPerPowerAttackValue);
    return _MixScore(
      totalPoints: points,
      boostSummary: WarBoostSummary(
        boostedNormalAttacks: 0,
        boostedPowerAttacks: 0,
        unboostedNormalAttacks: normalAttacks,
        unboostedPowerAttacks: powerAttacks,
      ),
      elixirUsages: const <WarElixirUsage>[],
    );
  }

  var remainingNormal = normalAttacks;
  var remainingPower = powerAttacks;
  var points = 0;
  var boostedNormal = 0;
  var boostedPower = 0;

  final usages = includeDetails ? <WarElixirUsage>[] : null;

  for (final seg in elixirSegments) {
    var slots = seg.slots;
    if (slots <= 0) continue;

    final boostedNormalPoints = boostedWarPoints(
      basePoints: pointsPerAttackValue,
      scoreMultiplier: seg.scoreMultiplier,
    );
    final boostedPowerPoints = boostedWarPoints(
      basePoints: pointsPerPowerAttackValue,
      scoreMultiplier: seg.scoreMultiplier,
    );

    final canUseNormal = remainingNormal > 0 && pointsPerAttackValue > 0;
    final canUsePower = remainingPower > 0 && pointsPerPowerAttackValue > 0;

    var boostedNormalForSegment = 0;
    var boostedPowerForSegment = 0;

    if (canUseNormal || canUsePower) {
      bool preferPowerFirst;
      if (canUseNormal && canUsePower) {
        preferPowerFirst = boostedPowerPoints > (boostedNormalPoints * 4);
      } else {
        preferPowerFirst = canUsePower;
      }

      if (preferPowerFirst) {
        boostedPowerForSegment = math.min(remainingPower, slots);
        remainingPower -= boostedPowerForSegment;
        slots -= boostedPowerForSegment;

        if (slots > 0) {
          boostedNormalForSegment = math.min(remainingNormal, slots);
          remainingNormal -= boostedNormalForSegment;
        }
      } else {
        boostedNormalForSegment = math.min(remainingNormal, slots);
        remainingNormal -= boostedNormalForSegment;
        slots -= boostedNormalForSegment;

        if (slots > 0) {
          boostedPowerForSegment = math.min(remainingPower, slots);
          remainingPower -= boostedPowerForSegment;
        }
      }
    }

    points += (boostedNormalForSegment * boostedNormalPoints) +
        (boostedPowerForSegment * boostedPowerPoints);
    boostedNormal += boostedNormalForSegment;
    boostedPower += boostedPowerForSegment;

    if (usages != null) {
      usages.add(
        WarElixirUsage(
          name: seg.name,
          scoreMultiplier: seg.scoreMultiplier,
          configuredAttacks: seg.configuredAttacks,
          usedAttacks: boostedNormalForSegment + boostedPowerForSegment,
          boostedNormalAttacks: boostedNormalForSegment,
          boostedPowerAttacks: boostedPowerForSegment,
        ),
      );
    }
  }

  points += (remainingNormal * pointsPerAttackValue) +
      (remainingPower * pointsPerPowerAttackValue);

  return _MixScore(
    totalPoints: points,
    boostSummary: WarBoostSummary(
      boostedNormalAttacks: boostedNormal,
      boostedPowerAttacks: boostedPower,
      unboostedNormalAttacks: remainingNormal,
      unboostedPowerAttacks: remainingPower,
    ),
    elixirUsages: usages ?? const <WarElixirUsage>[],
  );
}

WarGemPlan _minGemsForEnergy(int energyNeeded) {
  if (energyNeeded <= 0) {
    return const WarGemPlan(
      energyNeeded: 0,
      energyBought: 0,
      gems: 0,
      packs4: 0,
      packs20: 0,
      packs40: 0,
      leftover: 0,
    );
  }

  // Packs: 4 energy for 10 gems, 20 energy for 47 gems, 40 energy for 90 gems.
  final int targetUnits = (energyNeeded + 3) ~/ 4;
  int bestCost = 1 << 30;
  int bestUnits = targetUnits;
  int bestP4 = 0;
  int bestP20 = 0;
  int bestP40 = 0;

  for (int units = targetUnits; units <= targetUnits + 9; units++) {
    final p40 = units ~/ 10;
    final rem = units % 10;
    final p20 = rem ~/ 5;
    final p4 = rem % 5;
    final cost = (p40 * 90) + (p20 * 47) + (p4 * 10);

    if (cost < bestCost) {
      bestCost = cost;
      bestUnits = units;
      bestP4 = p4;
      bestP20 = p20;
      bestP40 = p40;
    }
  }

  final energyBought = bestUnits * 4;
  final leftover = energyBought - energyNeeded;

  return WarGemPlan(
    energyNeeded: energyNeeded,
    energyBought: energyBought,
    gems: bestCost,
    packs4: bestP4,
    packs20: bestP20,
    packs40: bestP40,
    leftover: leftover,
  );
}
