import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

class PetSkillSemanticsEntry {
  final String name;
  final String canonicalName;
  final String canonicalEffectId;
  final String effectCategory;
  final String dataSupport;
  final String runtimeSupport;
  final List<String> simulatorModes;
  final List<String> requiredValueKeys;
  final String gameplaySummary;
  final String projectSummary;
  final Map<String, Object?> effectSpec;

  const PetSkillSemanticsEntry({
    required this.name,
    required this.canonicalName,
    required this.canonicalEffectId,
    required this.effectCategory,
    required this.dataSupport,
    required this.runtimeSupport,
    required this.simulatorModes,
    required this.requiredValueKeys,
    required this.gameplaySummary,
    required this.projectSummary,
    required this.effectSpec,
  });

  factory PetSkillSemanticsEntry.fromJson(Map<String, Object?> json) {
    List<String> readList(String key) =>
        ((json[key] as List?) ?? const <Object?>[])
            .map((e) => e?.toString().trim() ?? '')
            .where((e) => e.isNotEmpty)
            .toList(growable: false);

    String read(String key) => (json[key] as String?)?.trim() ?? '';

    return PetSkillSemanticsEntry(
      name: read('name'),
      canonicalName: read('canonicalName'),
      canonicalEffectId: read('canonicalEffectId'),
      effectCategory: read('effectCategory'),
      dataSupport: read('dataSupport'),
      runtimeSupport: read('runtimeSupport'),
      simulatorModes: readList('simulatorModes'),
      requiredValueKeys: readList('requiredValueKeys'),
      gameplaySummary: read('gameplaySummary'),
      projectSummary: read('projectSummary'),
      effectSpec: (json['effectSpec'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
  }
}

class PetSkillSemanticsCatalog {
  final int schemaVersion;
  final Map<String, PetSkillSemanticsEntry> entriesByName;

  const PetSkillSemanticsCatalog({
    required this.schemaVersion,
    required this.entriesByName,
  });

  factory PetSkillSemanticsCatalog.fromJson(Map<String, Object?> json) {
    final rawEntries =
        (json['skills'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final entries = rawEntries
        .whereType<Map>()
        .map((e) => PetSkillSemanticsEntry.fromJson(
              e.cast<String, Object?>(),
            ))
        .where((e) => e.name.isNotEmpty)
        .toList(growable: false);

    return PetSkillSemanticsCatalog(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
      entriesByName: {for (final entry in entries) entry.name: entry},
    );
  }

  PetSkillSemanticsEntry? operator [](String name) => entriesByName[name];
}

class PetSkillSemanticsLoader {
  static const String _asset = 'assets/pet_skill_semantics.json';
  static PetSkillSemanticsCatalog? _cache;

  static Future<PetSkillSemanticsCatalog> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_asset);
    final catalog = PetSkillSemanticsCatalog.fromJson(
      jsonDecode(raw) as Map<String, Object?>,
    );
    _cache = catalog;
    return catalog;
  }
}
