// lib/data/config_models.dart
import 'package:flutter/foundation.dart';

import '../core/sim_types.dart';
import 'pet_effect_models.dart';

@immutable
class TimingConfig {
  final double normalDuration;
  final double specialDuration;
  final double stunDuration;
  final double missDuration;

  final double bossDuration;
  final double bossSpecialDuration;

  const TimingConfig({
    required this.normalDuration,
    required this.specialDuration,
    required this.stunDuration,
    required this.missDuration,
    required this.bossDuration,
    required this.bossSpecialDuration,
  });

  Map<String, Object?> toJson() => {
        'normalDuration': normalDuration,
        'specialDuration': specialDuration,
        'stunDuration': stunDuration,
        'missDuration': missDuration,
        'bossDuration': bossDuration,
        'bossSpecialDuration': bossSpecialDuration,
      };

  factory TimingConfig.fromJson(Map<String, Object?> j) {
    double dd(String k, double fb) => (j[k] as num?)?.toDouble() ?? fb;

    // compat: nel json legacy esiste "bossSpecial"
    final bossSpecial = (j['bossSpecialDuration'] as num?)?.toDouble() ??
        (j['bossSpecial'] as num?)?.toDouble() ??
        0.5;

    return TimingConfig(
      normalDuration: dd('normalDuration', 0.3),
      specialDuration: dd('specialDuration', 0.5),
      stunDuration: dd('stunDuration', 0.4),
      missDuration: dd('missDuration', 0.3),
      bossDuration: dd('bossDuration', 0.2),
      bossSpecialDuration: bossSpecial,
    );
  }
}

@immutable
class WeightedTick {
  final int ticks;
  final double weight;

  const WeightedTick({
    required this.ticks,
    required this.weight,
  });

  Map<String, Object?> toJson() => {
        'ticks': ticks,
        'weight': weight,
      };
}

@immutable
class PetTicksBarConfig {
  static const int defaultTicksPerState = 165;
  static const int defaultStartTicks = 165;

  final bool enabled;
  final int ticksPerState;
  final int startTicks;
  final double petCritPlusOneProb;

  final List<WeightedTick> bossNormal;
  final List<WeightedTick> bossSpecial;
  final List<WeightedTick> bossMiss;
  final List<WeightedTick> stun;
  final List<WeightedTick> petKnightBase;

  final bool useInNormal;
  final bool useInSpecialRegen;
  final bool useInSpecialRegenPlusEw;
  final bool useInSpecialRegenEw;
  final bool useInShatterShield;
  final bool useInCycloneBoost;
  final bool useInDurableRockShield;
  final bool useInEpic;

  final bool requireFirstKnightMatchForSrModes;

  const PetTicksBarConfig({
    this.enabled = false,
    this.ticksPerState = defaultTicksPerState,
    this.startTicks = defaultStartTicks,
    this.petCritPlusOneProb = 0.10,
    this.bossNormal = const <WeightedTick>[
      WeightedTick(ticks: 2, weight: 1.00),
    ],
    this.bossSpecial = const <WeightedTick>[
      WeightedTick(ticks: 4, weight: 1.00),
    ],
    this.bossMiss = const <WeightedTick>[
      WeightedTick(ticks: 1, weight: 1.00),
    ],
    this.stun = const <WeightedTick>[
      WeightedTick(ticks: 1, weight: 1.00),
    ],
    this.petKnightBase = const <WeightedTick>[
      WeightedTick(ticks: 12, weight: 1.00),
    ],
    this.useInNormal = false,
    this.useInSpecialRegen = false,
    this.useInSpecialRegenPlusEw = false,
    this.useInSpecialRegenEw = false,
    this.useInShatterShield = false,
    this.useInCycloneBoost = false,
    this.useInDurableRockShield = false,
    this.useInEpic = false,
    this.requireFirstKnightMatchForSrModes = true,
  });

  static List<WeightedTick> _parseWeightedTicks(
    Object? raw, {
    required List<WeightedTick> fallback,
  }) {
    if (raw is! Map) return fallback;
    final out = <WeightedTick>[];
    raw.forEach((k, v) {
      final ticks = int.tryParse(k.toString());
      final weight = (v as num?)?.toDouble();
      if (ticks == null || ticks <= 0) return;
      if (weight == null || !weight.isFinite || weight <= 0) return;
      out.add(WeightedTick(ticks: ticks, weight: weight));
    });
    if (out.isEmpty) return fallback;
    out.sort((a, b) => a.ticks.compareTo(b.ticks));
    return out;
  }

  static Map<String, double> _toDistMap(List<WeightedTick> dist) {
    final out = <String, double>{};
    for (final e in dist) {
      out[e.ticks.toString()] = e.weight;
    }
    return out;
  }

  factory PetTicksBarConfig.fromJson(Map<String, Object?> bar) {
    final modeMap = (bar['modes'] as Map?)?.cast<String, Object?>() ?? const {};

    final enabled = (bar['enabled'] as bool?) ?? false;
    bool modeOn(String key) =>
        (modeMap[key] as bool?) ?? enabled; // if enabled and no map -> ON all

    final ticksPerState =
        (bar['ticksPerState'] as num?)?.toInt() ?? defaultTicksPerState;
    final startTicksRaw =
        (bar['startTicks'] as num?)?.toInt() ?? defaultStartTicks;
    final maxTicks =
        ticksPerState <= 0 ? defaultTicksPerState * 2 : ticksPerState * 2;
    final startTicks = startTicksRaw.clamp(0, maxTicks);

    final critPlusOneRaw =
        (bar['petCritPlusOneProb'] as num?)?.toDouble() ?? 0.10;
    final critPlusOne = critPlusOneRaw.clamp(0.0, 1.0);

    return PetTicksBarConfig(
      enabled: enabled,
      ticksPerState: ticksPerState <= 0 ? defaultTicksPerState : ticksPerState,
      startTicks: startTicks,
      petCritPlusOneProb: critPlusOne,
      bossNormal: _parseWeightedTicks(
        bar['bossNormal'],
        fallback: const <WeightedTick>[WeightedTick(ticks: 2, weight: 1.00)],
      ),
      bossSpecial: _parseWeightedTicks(
        bar['bossSpecial'],
        fallback: const <WeightedTick>[WeightedTick(ticks: 4, weight: 1.00)],
      ),
      bossMiss: _parseWeightedTicks(
        bar['bossMiss'],
        fallback: const <WeightedTick>[WeightedTick(ticks: 1, weight: 1.00)],
      ),
      stun: _parseWeightedTicks(
        bar['stun'],
        fallback: const <WeightedTick>[WeightedTick(ticks: 1, weight: 1.00)],
      ),
      petKnightBase: _parseWeightedTicks(
        bar['petKnightBase'],
        fallback: const <WeightedTick>[WeightedTick(ticks: 12, weight: 1.00)],
      ),
      useInNormal: modeOn('normal'),
      useInSpecialRegen: modeOn('specialRegen'),
      useInSpecialRegenPlusEw: modeOn('specialRegenPlusEw'),
      useInSpecialRegenEw: modeOn('specialRegenEw'),
      useInShatterShield: modeOn('shatterShield'),
      useInCycloneBoost: modeOn('cycloneBoost'),
      useInDurableRockShield: modeOn('durableRockShield'),
      useInEpic: modeOn('epic'),
      requireFirstKnightMatchForSrModes:
          (bar['requireFirstKnightMatchForSrModes'] as bool?) ?? true,
    );
  }

  @Deprecated('Use PetTicksBarConfig.fromJson on the petTicksBar map.')
  factory PetTicksBarConfig.fromRootJson(Map<String, Object?> root) {
    final bar =
        (root['petTicksBar'] as Map?)?.cast<String, Object?>() ?? const {};
    return PetTicksBarConfig.fromJson(bar);
  }

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'ticksPerState': ticksPerState,
        'startTicks': startTicks,
        'petCritPlusOneProb': petCritPlusOneProb,
        'bossNormal': _toDistMap(bossNormal),
        'bossSpecial': _toDistMap(bossSpecial),
        'bossMiss': _toDistMap(bossMiss),
        'stun': _toDistMap(stun),
        'petKnightBase': _toDistMap(petKnightBase),
        'modes': <String, bool>{
          'normal': useInNormal,
          'specialRegen': useInSpecialRegen,
          'specialRegenPlusEw': useInSpecialRegenPlusEw,
          'specialRegenEw': useInSpecialRegenEw,
          'shatterShield': useInShatterShield,
          'cycloneBoost': useInCycloneBoost,
          'durableRockShield': useInDurableRockShield,
          'epic': useInEpic,
        },
        'requireFirstKnightMatchForSrModes': requireFirstKnightMatchForSrModes,
      };

  PetTicksBarConfig copyWith({
    bool? enabled,
    int? ticksPerState,
    int? startTicks,
    double? petCritPlusOneProb,
    List<WeightedTick>? bossNormal,
    List<WeightedTick>? bossSpecial,
    List<WeightedTick>? bossMiss,
    List<WeightedTick>? stun,
    List<WeightedTick>? petKnightBase,
    bool? useInNormal,
    bool? useInSpecialRegen,
    bool? useInSpecialRegenPlusEw,
    bool? useInSpecialRegenEw,
    bool? useInShatterShield,
    bool? useInCycloneBoost,
    bool? useInDurableRockShield,
    bool? useInEpic,
    bool? requireFirstKnightMatchForSrModes,
  }) {
    return PetTicksBarConfig(
      enabled: enabled ?? this.enabled,
      ticksPerState: ticksPerState ?? this.ticksPerState,
      startTicks: startTicks ?? this.startTicks,
      petCritPlusOneProb: petCritPlusOneProb ?? this.petCritPlusOneProb,
      bossNormal: bossNormal ?? this.bossNormal,
      bossSpecial: bossSpecial ?? this.bossSpecial,
      bossMiss: bossMiss ?? this.bossMiss,
      stun: stun ?? this.stun,
      petKnightBase: petKnightBase ?? this.petKnightBase,
      useInNormal: useInNormal ?? this.useInNormal,
      useInSpecialRegen: useInSpecialRegen ?? this.useInSpecialRegen,
      useInSpecialRegenPlusEw:
          useInSpecialRegenPlusEw ?? this.useInSpecialRegenPlusEw,
      useInSpecialRegenEw: useInSpecialRegenEw ?? this.useInSpecialRegenEw,
      useInShatterShield: useInShatterShield ?? this.useInShatterShield,
      useInCycloneBoost: useInCycloneBoost ?? this.useInCycloneBoost,
      useInDurableRockShield:
          useInDurableRockShield ?? this.useInDurableRockShield,
      useInEpic: useInEpic ?? this.useInEpic,
      requireFirstKnightMatchForSrModes: requireFirstKnightMatchForSrModes ??
          this.requireFirstKnightMatchForSrModes,
    );
  }
}

@immutable
class KnightSpecialBarConfig {
  static const double defaultThresholdFill = 1.0;

  final bool enabled;
  final double startFill;
  final double knightTurnFill;
  final double bossTurnFill;
  final double thresholdFill;
  final double maxFill;

  const KnightSpecialBarConfig({
    this.enabled = false,
    this.startFill = 0.0,
    this.knightTurnFill = 0.20,
    this.bossTurnFill = 0.042,
    this.thresholdFill = defaultThresholdFill,
    this.maxFill = defaultThresholdFill,
  });

  static double _sanitizeNonNegative(
    Object? raw, {
    required double fallback,
  }) {
    final value = (raw as num?)?.toDouble();
    if (value == null || !value.isFinite || value < 0) {
      return fallback;
    }
    return value;
  }

  factory KnightSpecialBarConfig.fromJson(Map<String, Object?> raw) {
    final threshold = _sanitizeNonNegative(
      raw['thresholdFill'],
      fallback: defaultThresholdFill,
    );
    final parsedMax = _sanitizeNonNegative(
      raw['maxFill'],
      fallback: threshold,
    );
    final maxFill = parsedMax < threshold ? threshold : parsedMax;
    final startFill = _sanitizeNonNegative(
      raw['startFill'],
      fallback: 0.0,
    ).clamp(0.0, maxFill);

    return KnightSpecialBarConfig(
      enabled: (raw['enabled'] as bool?) ?? false,
      startFill: startFill,
      knightTurnFill: _sanitizeNonNegative(
        raw['knightTurnFill'],
        fallback: 0.20,
      ),
      bossTurnFill: _sanitizeNonNegative(
        raw['bossTurnFill'],
        fallback: 0.042,
      ),
      thresholdFill: threshold,
      maxFill: maxFill,
    );
  }

  Map<String, Object?> toJson() => {
        'enabled': enabled,
        'startFill': startFill,
        'knightTurnFill': knightTurnFill,
        'bossTurnFill': bossTurnFill,
        'thresholdFill': thresholdFill,
        'maxFill': maxFill,
      };

  KnightSpecialBarConfig copyWith({
    bool? enabled,
    double? startFill,
    double? knightTurnFill,
    double? bossTurnFill,
    double? thresholdFill,
    double? maxFill,
  }) {
    return KnightSpecialBarConfig(
      enabled: enabled ?? this.enabled,
      startFill: startFill ?? this.startFill,
      knightTurnFill: knightTurnFill ?? this.knightTurnFill,
      bossTurnFill: bossTurnFill ?? this.bossTurnFill,
      thresholdFill: thresholdFill ?? this.thresholdFill,
      maxFill: maxFill ?? this.maxFill,
    );
  }
}

class Advantage {
  static List<double> normalizeList(Iterable<num> v) {
    final out = <double>[];
    for (final x in v) {
      out.add(normalize(x.toDouble()));
    }
    while (out.length < 3) {
      out.add(1.0);
    }
    if (out.length > 3) out.length = 3;
    return out;
  }

  static double normalize(double x) {
    if ((x - 1.0).abs() < 1e-9) return 1.0;
    if ((x - 1.5).abs() < 1e-9) return 1.5;
    if ((x - 2.0).abs() < 1e-9) return 2.0;

    // clamp hard alle sole 3 opzioni supportate
    if (x < 1.25) return 1.0;
    if (x < 1.75) return 1.5;
    return 2.0;
  }
}

@immutable
class BossMeta {
  final bool raidMode;
  final int level;
  final List<double> advVsKnights;

  // Common combat params
  final double evasionChance;
  final double criticalChance;
  final double criticalMultiplier;
  final double raidSpecialMultiplier;

  final int hitsToFirstShatter;
  final int hitsToNextShatter;

  final int knightToSpecial;
  final int bossToSpecial;

  /// Clock finto usato dall'Old Simulator (ex specialRegenEw):
  /// il boss NON fa special ma vogliamo mantenere un tick deterministico.
  final int bossToSpecialFakeEW;

  /// SR: turno (knightTurn) da cui i cavalieri iniziano a fare sempre special.
  final int knightToSpecialSR;
  final int knightToRecastSpecialSR;
  final int knightToSpecialSREW;
  final int knightToRecastSpecialSREW;

  // ✅ SR + EW (Elemental Weakness)
  // Applicazione: dopo l'attivazione SR, ogni hitsToElementalWeakness turni
  // (basato su knightTurn) applica un nuovo stack di debuff.
  final int hitsToElementalWeakness;

  // Durata: numero di "boss turns" in cui il debuff resta attivo.
  // IMPORTANT: non scala sui miss del boss.
  final int durationElementalWeakness;

  // Riduzione: per stack, riduce l'attacco del boss di questa frazione (es. 0.65 = -65%).
  // Gli stack sono additivi.
  final double defaultElementalWeakness;

  // ✅ Cyclone Boost %
  final double cyclone;

  // ✅ Durable Rock Shield (percento di aumento difesa)
  final double defaultDurableRockShield;
  final double sameElementDRS;
  final double strongElementEW;

  // ✅ DRS cadence from json
  final int hitsToDRS;
  final int durationDRS;

  // Cycle multiplier base (dal json)
  final double cycleMultiplier;

  // Epic Boss: bonus damage per cavaliere extra (es. 0.25 = +25%)
  final double epicBossDamageBonus;

  // Premium timing config
  final TimingConfig timing;
  final PetTicksBarConfig petTicksBar;
  final KnightSpecialBarConfig knightSpecialBar;

  const BossMeta({
    required this.raidMode,
    required this.level,
    required this.advVsKnights,
    required this.evasionChance,
    required this.criticalChance,
    required this.criticalMultiplier,
    required this.raidSpecialMultiplier,
    required this.hitsToFirstShatter,
    required this.hitsToNextShatter,
    required this.knightToSpecial,
    required this.bossToSpecial,
    required this.bossToSpecialFakeEW,
    required this.knightToSpecialSR,
    required this.knightToRecastSpecialSR,
    required this.knightToSpecialSREW,
    required this.knightToRecastSpecialSREW,
    required this.hitsToElementalWeakness,
    required this.durationElementalWeakness,
    required this.defaultElementalWeakness,
    required this.cyclone,
    required this.defaultDurableRockShield,
    required this.sameElementDRS,
    required this.strongElementEW,
    required this.hitsToDRS,
    required this.durationDRS,
    required this.cycleMultiplier,
    required this.epicBossDamageBonus,
    required this.timing,
    this.petTicksBar = const PetTicksBarConfig(),
    this.knightSpecialBar = const KnightSpecialBarConfig(),
  });

  Map<String, Object?> toJson() => {
        'raidMode': raidMode,
        'level': level,
        'advVsKnights': advVsKnights,
        'evasionChance': evasionChance,
        'criticalChance': criticalChance,
        'criticalMultiplier': criticalMultiplier,
        'raidSpecialMultiplier': raidSpecialMultiplier,
        'hitsToFirstShatter': hitsToFirstShatter,
        'hitsToNextShatter': hitsToNextShatter,
        'knightToSpecial': knightToSpecial,
        'bossToSpecial': bossToSpecial,
        'bossToSpecialFakeEW': bossToSpecialFakeEW,
        'knightToSpecialSR': knightToSpecialSR,
        'knightToRecastSpecialSR': knightToRecastSpecialSR,
        'knightToSpecialSREW': knightToSpecialSREW,
        'knightToRecastSpecialSREW': knightToRecastSpecialSREW,
        'hitsToElementalWeakness': hitsToElementalWeakness,
        'durationElementalWeakness': durationElementalWeakness,
        'defaultElementalWeakness': defaultElementalWeakness,
        'cyclone': cyclone,
        'defaultDurableRockShield': defaultDurableRockShield,
        'sameElementDRS': sameElementDRS,
        'strongElementEW': strongElementEW,
        'hitsToDRS': hitsToDRS,
        'durationDRS': durationDRS,
        'cycleMultiplier': cycleMultiplier,
        'epicBossDamageBonus': epicBossDamageBonus,
        'timing': timing.toJson(),
        'petTicksBar': petTicksBar.toJson(),
        'knightSpecialBar': knightSpecialBar.toJson(),
      };

  static double _toFraction(double raw, double fallback) {
    if (!raw.isFinite) return fallback;
    if (raw < 0) return 0.0;
    if (raw > 1.0) return raw / 100.0;
    return raw;
  }

  static double _parseDefaultDurableRockShield(Map<String, Object?> j) {
    final rawNew = (j['defaultDurableRockShield'] as num?)?.toDouble();
    if (rawNew != null) return _toFraction(rawNew, 0.5);
    final rawOld = (j['durableRockShield'] as num?)?.toDouble();
    if (rawOld != null) return _toFraction(rawOld, 0.5);
    return 0.5;
  }

  static double _parseDefaultElementalWeakness(Map<String, Object?> j) {
    final rawNew = (j['defaultElementalWeakness'] as num?)?.toDouble();
    if (rawNew != null) return _toFraction(rawNew, 0.65);
    final rawOld = (j['reductionElementalWeakness'] as num?)?.toDouble();
    if (rawOld != null) return _toFraction(rawOld, 0.65);
    return 0.65;
  }

  static double _parseSameElementDrsMultiplier(Map<String, Object?> j) {
    final raw = (j['sameElementDRS'] as num?)?.toDouble();
    if (raw == null) return 1.6;

    // New format: flat multiplier.
    if (raw <= 10.0) {
      if (raw <= 0) return 1.0;
      return raw;
    }

    // Legacy format: absolute match boost percent (e.g. 80).
    // Convert using legacy base DRS (e.g. 80/50 = 1.6x).
    final legacyBaseRaw = (j['durableRockShield'] as num?)?.toDouble() ?? 50.0;
    final legacyBasePct =
        (legacyBaseRaw <= 1.0) ? (legacyBaseRaw * 100.0) : legacyBaseRaw;
    if (legacyBasePct <= 0) return 1.6;
    final m = raw / legacyBasePct;
    if (!m.isFinite || m <= 0) return 1.6;
    return m;
  }

  static BossMeta _fromConfigMaps(
    Map<String, Object?> source, {
    Map<String, Object?>? petTicksBarRaw,
    Map<String, Object?>? knightSpecialBarRaw,
  }) {
    final adv = (source['advVsKnights'] as List?)?.whereType<num>() ??
        const <num>[1, 1, 1];

    double dd(String k, double fb) => (source[k] as num?)?.toDouble() ?? fb;
    double d01(String k, double fb) {
      final v = dd(k, fb);
      if (v < 0) return 0.0;
      if (v > 1) return 1.0;
      return v;
    }

    final defaultDrs = _parseDefaultDurableRockShield(source);
    final defaultEw = _parseDefaultElementalWeakness(source);
    final resolvedPetTicksBar = petTicksBarRaw ??
        (source['petTicksBar'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final resolvedKnightSpecialBar = knightSpecialBarRaw ??
        (source['knightSpecialBar'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    return BossMeta(
      raidMode: (source['raidMode'] as bool?) ?? true,
      level: (source['level'] as num?)?.toInt() ?? 1,
      advVsKnights: Advantage.normalizeList(adv),
      evasionChance: d01('evasionChance', 0.10),
      criticalChance: d01('criticalChance', 0.05),
      criticalMultiplier: dd('criticalMultiplier', 1.5),
      raidSpecialMultiplier: dd('raidSpecialMultiplier', 3.25),
      hitsToFirstShatter: (source['hitsToFirstShatter'] as num?)?.toInt() ?? 7,
      hitsToNextShatter: (source['hitsToNextShatter'] as num?)?.toInt() ?? 13,
      knightToSpecial: (source['knightToSpecial'] as num?)?.toInt() ?? 5,
      bossToSpecial: (source['bossToSpecial'] as num?)?.toInt() ?? 6,
      bossToSpecialFakeEW:
          (source['bossToSpecialFakeEW'] as num?)?.toInt() ?? 1000,
      knightToSpecialSR: (source['knightToSpecialSR'] as num?)?.toInt() ?? 7,
      knightToRecastSpecialSR:
          (source['knightToRecastSpecialSR'] as num?)?.toInt() ?? 13,
      knightToSpecialSREW: (source['knightToSpecialSREW'] as num?)?.toInt() ??
          (source['knightToSpecialSR'] as num?)?.toInt() ??
          7,
      knightToRecastSpecialSREW:
          (source['knightToRecastSpecialSREW'] as num?)?.toInt() ??
              (source['knightToRecastSpecialSR'] as num?)?.toInt() ??
              13,
      hitsToElementalWeakness:
          (source['hitsToElementalWeakness'] as num?)?.toInt() ?? 7,
      durationElementalWeakness:
          (source['durationElementalWeakness'] as num?)?.toInt() ?? 2,
      defaultElementalWeakness: defaultEw,
      cyclone: dd('cyclone', 71.0),
      defaultDurableRockShield: defaultDrs,
      sameElementDRS: _parseSameElementDrsMultiplier(source),
      strongElementEW: dd('strongElementEW', 1.6),
      hitsToDRS: (source['hitsToDRS'] as num?)?.toInt() ?? 7,
      durationDRS: (source['durationDRS'] as num?)?.toInt() ?? 3,
      cycleMultiplier: (source['cycleMultiplier'] as num?)?.toDouble() ??
          (source['multiplier'] as num?)?.toDouble() ??
          (source['Multiplier'] as num?)?.toDouble() ??
          1.0,
      epicBossDamageBonus:
          (source['epicBossDamageBonus'] as num?)?.toDouble() ?? 0.25,
      timing: TimingConfig.fromJson(
        (source['timing'] as Map?)?.cast<String, Object?>() ?? source,
      ),
      petTicksBar: PetTicksBarConfig.fromJson(resolvedPetTicksBar),
      knightSpecialBar:
          KnightSpecialBarConfig.fromJson(resolvedKnightSpecialBar),
    );
  }

  factory BossMeta.fromSources({
    required Map<String, Object?> simRules,
    Map<String, Object?>? petTicksBar,
    Map<String, Object?>? knightSpecialBar,
    Map<String, Object?>? overrides,
  }) {
    final merged = <String, Object?>{
      ...simRules,
      if (overrides != null) ...overrides,
    };
    return _fromConfigMaps(
      merged,
      petTicksBarRaw: petTicksBar,
      knightSpecialBarRaw: knightSpecialBar,
    );
  }

  factory BossMeta.fromJson(Map<String, Object?> j) => _fromConfigMaps(j);

  BossMeta copyWith({
    bool? raidMode,
    int? level,
    List<double>? advVsKnights,
    double? evasionChance,
    double? criticalChance,
    double? criticalMultiplier,
    double? raidSpecialMultiplier,
    int? hitsToFirstShatter,
    int? hitsToNextShatter,
    int? knightToSpecial,
    int? bossToSpecial,
    int? bossToSpecialFakeEW,
    int? knightToSpecialSR,
    int? knightToRecastSpecialSR,
    int? knightToSpecialSREW,
    int? knightToRecastSpecialSREW,
    int? hitsToElementalWeakness,
    int? durationElementalWeakness,
    double? defaultElementalWeakness,
    double? cyclone,
    double? defaultDurableRockShield,
    double? sameElementDRS,
    double? strongElementEW,
    int? hitsToDRS,
    int? durationDRS,
    double? cycleMultiplier,
    double? epicBossDamageBonus,
    TimingConfig? timing,
    PetTicksBarConfig? petTicksBar,
    KnightSpecialBarConfig? knightSpecialBar,
  }) {
    return BossMeta(
      raidMode: raidMode ?? this.raidMode,
      level: level ?? this.level,
      advVsKnights: advVsKnights ?? this.advVsKnights,
      evasionChance: evasionChance ?? this.evasionChance,
      criticalChance: criticalChance ?? this.criticalChance,
      criticalMultiplier: criticalMultiplier ?? this.criticalMultiplier,
      raidSpecialMultiplier:
          raidSpecialMultiplier ?? this.raidSpecialMultiplier,
      hitsToFirstShatter: hitsToFirstShatter ?? this.hitsToFirstShatter,
      hitsToNextShatter: hitsToNextShatter ?? this.hitsToNextShatter,
      knightToSpecial: knightToSpecial ?? this.knightToSpecial,
      bossToSpecial: bossToSpecial ?? this.bossToSpecial,
      bossToSpecialFakeEW: bossToSpecialFakeEW ?? this.bossToSpecialFakeEW,
      knightToSpecialSR: knightToSpecialSR ?? this.knightToSpecialSR,
      knightToRecastSpecialSR:
          knightToRecastSpecialSR ?? this.knightToRecastSpecialSR,
      knightToSpecialSREW: knightToSpecialSREW ?? this.knightToSpecialSREW,
      knightToRecastSpecialSREW:
          knightToRecastSpecialSREW ?? this.knightToRecastSpecialSREW,
      hitsToElementalWeakness:
          hitsToElementalWeakness ?? this.hitsToElementalWeakness,
      durationElementalWeakness:
          durationElementalWeakness ?? this.durationElementalWeakness,
      defaultElementalWeakness:
          defaultElementalWeakness ?? this.defaultElementalWeakness,
      cyclone: cyclone ?? this.cyclone,
      defaultDurableRockShield:
          defaultDurableRockShield ?? this.defaultDurableRockShield,
      sameElementDRS: sameElementDRS ?? this.sameElementDRS,
      strongElementEW: strongElementEW ?? this.strongElementEW,
      hitsToDRS: hitsToDRS ?? this.hitsToDRS,
      durationDRS: durationDRS ?? this.durationDRS,
      cycleMultiplier: cycleMultiplier ?? this.cycleMultiplier,
      epicBossDamageBonus: epicBossDamageBonus ?? this.epicBossDamageBonus,
      timing: timing ?? this.timing,
      petTicksBar: petTicksBar ?? this.petTicksBar,
      knightSpecialBar: knightSpecialBar ?? this.knightSpecialBar,
    );
  }
}

@immutable
class BossStats {
  final double attack;
  final double defense;
  final int hp;

  const BossStats({
    required this.attack,
    required this.defense,
    required this.hp,
  });

  Map<String, Object?> toJson() => {
        'attack': attack,
        'defense': defense,
        'hp': hp,
      };

  factory BossStats.fromJson(Map<String, Object?> j) => BossStats(
        attack: (j['attack'] as num).toDouble(),
        defense: (j['defense'] as num).toDouble(),
        hp: (j['hp'] as num).toInt(),
      );
}

@immutable
class BossLevelRow {
  final int level;
  final double attack;
  final double defense;
  final int hp;
  final int killPoints;

  const BossLevelRow({
    required this.level,
    required this.attack,
    required this.defense,
    required this.hp,
    this.killPoints = 0,
  });

  Map<String, Object?> toJson() => {
        'level': level,
        'attack': attack,
        'defense': defense,
        'hp': hp,
        'killPoints': killPoints,
      };

  factory BossLevelRow.fromJson(Map<String, Object?> j) => BossLevelRow(
        level: (j['level'] as num).toInt(),
        attack: (j['attack'] as num).toDouble(),
        defense: (j['defense'] as num).toDouble(),
        hp: (j['hp'] as num).toInt(),
        killPoints: (j['killPoints'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class WarPointsSet {
  final int base;
  final int frenzy;
  final int powerAttack;
  final int frenzyPowerAttack;

  const WarPointsSet({
    required this.base,
    required this.frenzy,
    required this.powerAttack,
    required this.frenzyPowerAttack,
  });

  factory WarPointsSet.fromJson(Map<String, Object?> j) => WarPointsSet(
        base: (j['base'] as num?)?.toInt() ?? 0,
        frenzy: (j['frenzy'] as num?)?.toInt() ?? 0,
        powerAttack: (j['powerAttack'] as num?)?.toInt() ?? 0,
        frenzyPowerAttack: (j['frenzyPowerAttack'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class WarPointsServer {
  final WarPointsSet normal;
  final WarPointsSet strip;

  const WarPointsServer({
    required this.normal,
    required this.strip,
  });

  factory WarPointsServer.fromJson(Map<String, Object?> j) => WarPointsServer(
        normal: WarPointsSet.fromJson(
          (j['normal'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
        strip: WarPointsSet.fromJson(
          (j['strip'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      );
}

@immutable
class WarPointsConfig {
  final WarPointsServer eu;
  final WarPointsServer global;

  const WarPointsConfig({
    required this.eu,
    required this.global,
  });

  factory WarPointsConfig.fromJson(Map<String, Object?> j) => WarPointsConfig(
        eu: WarPointsServer.fromJson(
          (j['EU'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
        global: WarPointsServer.fromJson(
          (j['Global'] as Map?)?.cast<String, Object?>() ?? const {},
        ),
      );
}

@immutable
class EpicBossRow {
  final int level;
  final double attack;
  final double defense;
  final int hp;

  const EpicBossRow({
    required this.level,
    required this.attack,
    required this.defense,
    required this.hp,
  });

  Map<String, Object?> toJson() => {
        'level': level,
        'attack': attack,
        'defense': defense,
        'hp': hp,
      };

  factory EpicBossRow.fromJson(Map<String, Object?> j) => EpicBossRow(
        level: (j['level'] as num).toInt(),
        attack: (j['attack'] as num).toDouble(),
        defense: (j['defense'] as num).toDouble(),
        hp: (j['hp'] as num).toInt(),
      );
}

@immutable
class BossConfig {
  final BossMeta meta;
  final BossStats stats;

  const BossConfig({
    required this.meta,
    required this.stats,
  });

  Map<String, Object?> toJson() => {
        'meta': meta.toJson(),
        'stats': stats.toJson(),
      };

  factory BossConfig.fromJson(Map<String, Object?> j) => BossConfig(
        meta: BossMeta.fromJson((j['meta'] as Map).cast<String, Object?>()),
        stats: BossStats.fromJson((j['stats'] as Map).cast<String, Object?>()),
      );
}

@immutable
class Precomputed {
  final BossMeta meta;
  final BossStats stats;

  // Inputs
  final List<double> kAtk;
  final List<double> kDef;
  final List<int> kHp;
  final List<double> kAdv;
  final List<double> kStun;
  final double petAtk;
  final double petAdv;
  final PetSkillUsageMode petSkillUsage;
  final List<PetResolvedEffect> petEffects;

  // Precomputed damages (ints)
  final List<int> kNormalDmg;
  final List<int> kCritDmg;
  final List<int> kSpecialDmg;
  final int petNormalDmg;
  final int petCritDmg;

  final List<int> bNormalDmg;
  final List<int> bCritDmg;

  const Precomputed({
    required this.meta,
    required this.stats,
    required this.kAtk,
    required this.kDef,
    required this.kHp,
    required this.kAdv,
    required this.kStun,
    this.petAtk = 0.0,
    this.petAdv = 1.0,
    this.petSkillUsage = PetSkillUsageMode.special1Only,
    this.petEffects = const <PetResolvedEffect>[],
    required this.kNormalDmg,
    required this.kCritDmg,
    required this.kSpecialDmg,
    this.petNormalDmg = 0,
    this.petCritDmg = 0,
    required this.bNormalDmg,
    required this.bCritDmg,
  });

  Map<String, Object?> toJson() => {
        'meta': meta.toJson(),
        'stats': stats.toJson(),
        'kAtk': kAtk,
        'kDef': kDef,
        'kHp': kHp,
        'kAdv': kAdv,
        'kStun': kStun,
        'petAtk': petAtk,
        'petAdv': petAdv,
        'petSkillUsage': petSkillUsage.name,
        if (petEffects.isNotEmpty)
          'petEffects':
              petEffects.map((e) => e.toJson()).toList(growable: false),
        'kNormalDmg': kNormalDmg,
        'kCritDmg': kCritDmg,
        'kSpecialDmg': kSpecialDmg,
        'petNormalDmg': petNormalDmg,
        'petCritDmg': petCritDmg,
        'bNormalDmg': bNormalDmg,
        'bCritDmg': bCritDmg,
      };

  factory Precomputed.fromJson(Map<String, Object?> j) => Precomputed(
        meta: BossMeta.fromJson((j['meta'] as Map).cast<String, Object?>()),
        stats: BossStats.fromJson((j['stats'] as Map).cast<String, Object?>()),
        kAtk:
            ((j['kAtk'] as List).cast<num>()).map((e) => e.toDouble()).toList(),
        kDef:
            ((j['kDef'] as List).cast<num>()).map((e) => e.toDouble()).toList(),
        kHp: ((j['kHp'] as List).cast<num>()).map((e) => e.toInt()).toList(),
        kAdv:
            ((j['kAdv'] as List).cast<num>()).map((e) => e.toDouble()).toList(),
        kStun: ((j['kStun'] as List).cast<num>())
            .map((e) => e.toDouble())
            .toList(),
        petAtk: (j['petAtk'] as num?)?.toDouble() ?? 0.0,
        petAdv: (j['petAdv'] as num?)?.toDouble() ?? 1.0,
        petSkillUsage: PetSkillUsageMode.values.firstWhere(
          (mode) => mode.name == (j['petSkillUsage'] as String?)?.trim(),
          orElse: () => PetSkillUsageMode.special1Only,
        ),
        petEffects: ((j['petEffects'] as List?) ?? const <Object?>[])
            .whereType<Map>()
            .map((e) => PetResolvedEffect.fromJson(e.cast<String, Object?>()))
            .toList(growable: false),
        kNormalDmg: ((j['kNormalDmg'] as List).cast<num>())
            .map((e) => e.toInt())
            .toList(),
        kCritDmg: ((j['kCritDmg'] as List).cast<num>())
            .map((e) => e.toInt())
            .toList(),
        kSpecialDmg: ((j['kSpecialDmg'] as List).cast<num>())
            .map((e) => e.toInt())
            .toList(),
        petNormalDmg: (j['petNormalDmg'] as num?)?.toInt() ?? 0,
        petCritDmg: (j['petCritDmg'] as num?)?.toInt() ?? 0,
        bNormalDmg: ((j['bNormalDmg'] as List).cast<num>())
            .map((e) => e.toInt())
            .toList(),
        bCritDmg: ((j['bCritDmg'] as List).cast<num>())
            .map((e) => e.toInt())
            .toList(),
      );
}

@immutable
class ElixirConfig {
  final String name;
  final String gamemode;
  final double scoreMultiplier;
  final int durationMinutes;

  const ElixirConfig({
    required this.name,
    required this.gamemode,
    required this.scoreMultiplier,
    required this.durationMinutes,
  });

  Map<String, Object?> toJson() => {
        'name': name,
        'gamemode': gamemode,
        'score_multiplier': scoreMultiplier,
        'duration_minutes': durationMinutes,
      };

  factory ElixirConfig.fromJson(Map<String, Object?> j) => ElixirConfig(
        name: (j['name'] as String?)?.trim() ?? '',
        gamemode: (j['gamemode'] as String?)?.trim() ?? 'Raid',
        scoreMultiplier: (j['score_multiplier'] as num?)?.toDouble() ?? 0.0,
        durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
      );
}

@immutable
class ElixirInventoryItem {
  final String name;
  final String gamemode;
  final double scoreMultiplier;
  final int durationMinutes;
  final int quantity;

  const ElixirInventoryItem({
    required this.name,
    required this.gamemode,
    required this.scoreMultiplier,
    required this.durationMinutes,
    required this.quantity,
  });

  factory ElixirInventoryItem.fromConfig(ElixirConfig c, int quantity) =>
      ElixirInventoryItem(
        name: c.name,
        gamemode: c.gamemode,
        scoreMultiplier: c.scoreMultiplier,
        durationMinutes: c.durationMinutes,
        quantity: quantity,
      );

  Map<String, Object?> toJson() => {
        'name': name,
        'gamemode': gamemode,
        'score_multiplier': scoreMultiplier,
        'duration_minutes': durationMinutes,
        'qty': quantity,
      };

  factory ElixirInventoryItem.fromJson(Map<String, Object?> j) =>
      ElixirInventoryItem(
        name: (j['name'] as String?)?.trim() ?? '',
        gamemode: (j['gamemode'] as String?)?.trim() ?? 'Raid',
        scoreMultiplier: (j['score_multiplier'] as num?)?.toDouble() ?? 0.0,
        durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 0,
        quantity: (j['qty'] as num?)?.toInt() ?? 0,
      );
}
