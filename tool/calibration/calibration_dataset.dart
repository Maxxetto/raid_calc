import 'dart:convert';
import 'dart:io';

class CalibrationDataset {
  final int version;
  final String? notes;
  final Map<String, Map<int, List<CalibrationCase>>> datasets;

  const CalibrationDataset({
    required this.version,
    required this.notes,
    required this.datasets,
  });

  factory CalibrationDataset.fromJson(Map<String, Object?> json) {
    final rawDatasets =
        (json['datasets'] as Map?)?.cast<String, Object?>() ?? const {};
    final datasets = <String, Map<int, List<CalibrationCase>>>{};
    rawDatasets.forEach((modeKey, modeValue) {
      final modeMap = (modeValue as Map?)?.cast<String, Object?>() ?? const {};
      final levels = <int, List<CalibrationCase>>{};
      modeMap.forEach((levelKey, levelValue) {
        final level = int.tryParse(levelKey);
        if (level == null) return;
        final rawCases = (levelValue as List?) ?? const [];
        levels[level] = rawCases
            .whereType<Map>()
            .map((raw) =>
                CalibrationCase.fromJson(raw.cast<String, Object?>()))
            .toList(growable: false);
      });
      datasets[modeKey] = levels;
    });

    return CalibrationDataset(
      version: (json['version'] as num?)?.toInt() ?? 1,
      notes: (json['notes'] as String?)?.trim().isEmpty == true
          ? null
          : json['notes'] as String?,
      datasets: datasets,
    );
  }

  static Future<CalibrationDataset> loadFromFile(String path) async {
    final raw = await File(path).readAsString();
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Calibration dataset root must be an object.');
    }
    return CalibrationDataset.fromJson(decoded.cast<String, Object?>());
  }

  List<FlattenedCalibrationCase> flattenCases() {
    final out = <FlattenedCalibrationCase>[];
    datasets.forEach((modeKey, byLevel) {
      byLevel.forEach((level, cases) {
        for (final c in cases) {
          out.add(FlattenedCalibrationCase(
            modeKey: modeKey,
            level: level,
            data: c,
          ));
        }
      });
    });
    return out;
  }
}

class CalibrationCase {
  final String setupId;
  final String? collectedAt;
  final String? scoreKind;
  final List<String> bossElements;
  final CalibrationSetup setup;
  final List<int> observedScores;

  const CalibrationCase({
    required this.setupId,
    required this.collectedAt,
    required this.scoreKind,
    required this.bossElements,
    required this.setup,
    required this.observedScores,
  });

  factory CalibrationCase.fromJson(Map<String, Object?> json) {
    final rawObserved = (json['observedScores'] as List?) ?? const [];
    final rawBossElements = (json['bossElements'] as List?) ?? const [];
    return CalibrationCase(
      setupId: (json['setupId'] as String?)?.trim().isNotEmpty == true
          ? (json['setupId'] as String).trim()
          : 'case',
      collectedAt: (json['collectedAt'] as String?)?.trim(),
      scoreKind: (json['scoreKind'] as String?)?.trim(),
      bossElements:
          rawBossElements.map((e) => e.toString()).toList(growable: false),
      setup: CalibrationSetup.fromJson(
        (json['setup'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
      observedScores: rawObserved
          .whereType<num>()
          .map((e) => e.round())
          .toList(growable: false),
    );
  }
}

class FlattenedCalibrationCase {
  final String modeKey;
  final int level;
  final CalibrationCase data;

  const FlattenedCalibrationCase({
    required this.modeKey,
    required this.level,
    required this.data,
  });
}

class CalibrationSetup {
  final List<CalibrationKnight> knights;
  final CalibrationPet pet;

  const CalibrationSetup({
    required this.knights,
    required this.pet,
  });

  factory CalibrationSetup.fromJson(Map<String, Object?> json) {
    final rawKnights = (json['knights'] as List?) ?? const [];
    return CalibrationSetup(
      knights: rawKnights
          .whereType<Map>()
          .map((raw) => CalibrationKnight.fromJson(raw.cast<String, Object?>()))
          .toList(growable: false),
      pet: CalibrationPet.fromJson(
        (json['pet'] as Map?)?.cast<String, Object?>() ?? const {},
      ),
    );
  }
}

class CalibrationKnight {
  final int atk;
  final int def;
  final int hp;
  final double stun;
  final List<String> elements;

  const CalibrationKnight({
    required this.atk,
    required this.def,
    required this.hp,
    required this.stun,
    required this.elements,
  });

  factory CalibrationKnight.fromJson(Map<String, Object?> json) {
    final rawElements = (json['elements'] as List?) ?? const [];
    return CalibrationKnight(
      atk: (json['atk'] as num?)?.round() ?? 0,
      def: (json['def'] as num?)?.round() ?? 0,
      hp: (json['hp'] as num?)?.round() ?? 0,
      stun: (json['stun'] as num?)?.toDouble() ?? 0.0,
      elements: rawElements.map((e) => e.toString()).toList(growable: false),
    );
  }
}

class CalibrationPet {
  final int atk;
  final List<String> elements;
  final String skillUsage;
  final bool cycloneAlwaysGem;
  final List<CalibrationPetEffect> effects;

  const CalibrationPet({
    required this.atk,
    required this.elements,
    required this.skillUsage,
    required this.cycloneAlwaysGem,
    required this.effects,
  });

  factory CalibrationPet.fromJson(Map<String, Object?> json) {
    final rawElements = (json['elements'] as List?) ?? const [];
    final rawEffects = (json['effects'] as List?) ?? const [];
    return CalibrationPet(
      atk: (json['atk'] as num?)?.round() ?? 0,
      elements: rawElements.map((e) => e.toString()).toList(growable: false),
      skillUsage: (json['skillUsage'] as String?)?.trim().isNotEmpty == true
          ? (json['skillUsage'] as String).trim()
          : 'special1Only',
      cycloneAlwaysGem: json['cycloneAlwaysGem'] == true,
      effects: rawEffects
          .whereType<Map>()
          .map((raw) =>
              CalibrationPetEffect.fromJson(raw.cast<String, Object?>()))
          .toList(growable: false),
    );
  }
}

class CalibrationPetEffect {
  final String canonicalEffectId;
  final int slot;
  final Map<String, num> values;

  const CalibrationPetEffect({
    required this.canonicalEffectId,
    required this.slot,
    required this.values,
  });

  factory CalibrationPetEffect.fromJson(Map<String, Object?> json) {
    final rawValues = (json['values'] as Map?)?.cast<String, Object?>() ?? const {};
    final values = <String, num>{};
    rawValues.forEach((key, value) {
      if (value is num) {
        values[key] = value;
      }
    });
    return CalibrationPetEffect(
      canonicalEffectId:
          (json['canonicalEffectId'] as String?)?.trim().isNotEmpty == true
              ? (json['canonicalEffectId'] as String).trim()
              : 'unknown',
      slot: (json['slot'] as num?)?.toInt() ?? 1,
      values: values,
    );
  }
}

class ScoreSummary {
  final int count;
  final int min;
  final int max;
  final double mean;
  final double median;
  final double p10;
  final double p90;

  const ScoreSummary({
    required this.count,
    required this.min,
    required this.max,
    required this.mean,
    required this.median,
    required this.p10,
    required this.p90,
  });

  factory ScoreSummary.fromScores(List<int> scores) {
    if (scores.isEmpty) {
      return const ScoreSummary(
        count: 0,
        min: 0,
        max: 0,
        mean: 0,
        median: 0,
        p10: 0,
        p90: 0,
      );
    }
    final sorted = List<int>.from(scores)..sort();
    final total = sorted.fold<int>(0, (sum, value) => sum + value);
    return ScoreSummary(
      count: sorted.length,
      min: sorted.first,
      max: sorted.last,
      mean: total / sorted.length,
      median: _quantile(sorted, 0.50),
      p10: _quantile(sorted, 0.10),
      p90: _quantile(sorted, 0.90),
    );
  }

  static double _quantile(List<int> sorted, double q) {
    if (sorted.isEmpty) return 0;
    if (sorted.length == 1) return sorted.first.toDouble();
    final clampedQ = q.clamp(0.0, 1.0);
    final position = (sorted.length - 1) * clampedQ;
    final lower = position.floor();
    final upper = position.ceil();
    if (lower == upper) return sorted[lower].toDouble();
    final fraction = position - lower;
    return sorted[lower] + (sorted[upper] - sorted[lower]) * fraction;
  }
}
