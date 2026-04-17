import 'dart:convert';

import 'package:flutter/services.dart';

class PetSkillDefinition {
  final String name;
  final String descriptionKey;
  final List<String> valueOrder;
  final Map<String, String> valueLabels;

  const PetSkillDefinition({
    required this.name,
    required this.descriptionKey,
    required this.valueOrder,
    required this.valueLabels,
  });

  factory PetSkillDefinition.fromJson(Map<String, Object?> json) {
    String read(String key) => (json[key] ?? '').toString().trim();
    final rawOrder =
        (json['valueOrder'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final rawLabels = (json['valueLabels'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};

    return PetSkillDefinition(
      name: read('name'),
      descriptionKey: read('descriptionKey'),
      valueOrder: rawOrder
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false),
      valueLabels: rawLabels.map(
        (key, value) => MapEntry(key, value?.toString().trim() ?? ''),
      )..removeWhere((key, value) => value.isEmpty),
    );
  }

  bool get isValid => name.isNotEmpty;
}

class PetSkillDefinitionsCatalog {
  final int schemaVersion;
  final Map<String, PetSkillDefinition> definitionsByName;

  const PetSkillDefinitionsCatalog({
    required this.schemaVersion,
    required this.definitionsByName,
  });

  factory PetSkillDefinitionsCatalog.fromJson(Map<String, Object?> json) {
    final rawDefinitions =
        (json['definitions'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final definitions = rawDefinitions
        .whereType<Map>()
        .map(
          (e) => PetSkillDefinition.fromJson(
            e.cast<String, Object?>(),
          ),
        )
        .where((e) => e.isValid)
        .toList(growable: false);

    final schemaVersion =
        int.tryParse((json['schemaVersion'] ?? '1').toString()) ?? 1;
    return PetSkillDefinitionsCatalog(
      schemaVersion: schemaVersion,
      definitionsByName: {
        for (final definition in definitions) definition.name: definition,
      },
    );
  }

  PetSkillDefinition? operator [](String name) => definitionsByName[name];
}

class PetSkillDefinitionsLoader {
  static const String _asset = 'assets/pet_skill_definitions.json';
  static PetSkillDefinitionsCatalog? _cache;

  static Future<PetSkillDefinitionsCatalog> load() async {
    final cached = _cache;
    if (cached != null) return cached;

    final raw = await rootBundle.loadString(_asset);
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      const empty = PetSkillDefinitionsCatalog(
        schemaVersion: 1,
        definitionsByName: <String, PetSkillDefinition>{},
      );
      _cache = empty;
      return empty;
    }

    final catalog = PetSkillDefinitionsCatalog.fromJson(
      decoded.cast<String, Object?>(),
    );
    _cache = catalog;
    return catalog;
  }

  static void clearCache() {
    _cache = null;
  }
}
