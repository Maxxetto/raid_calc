import 'package:flutter/foundation.dart';

@immutable
class PetResolvedEffect {
  final String sourceSlotId;
  final String sourceSkillName;
  final Map<String, num> values;
  final String canonicalEffectId;
  final String canonicalName;
  final String effectCategory;
  final String dataSupport;
  final String runtimeSupport;
  final List<String> simulatorModes;
  final Map<String, Object?> effectSpec;

  const PetResolvedEffect({
    required this.sourceSlotId,
    required this.sourceSkillName,
    required Map<String, num> values,
    required this.canonicalEffectId,
    required this.canonicalName,
    required this.effectCategory,
    required this.dataSupport,
    required this.runtimeSupport,
    required List<String> simulatorModes,
    required Map<String, Object?> effectSpec,
  })  : values = values,
        simulatorModes = simulatorModes,
        effectSpec = effectSpec;

  Map<String, Object?> toJson() => <String, Object?>{
        'sourceSlotId': sourceSlotId,
        'sourceSkillName': sourceSkillName,
        'values': values,
        'canonicalEffectId': canonicalEffectId,
        'canonicalName': canonicalName,
        'effectCategory': effectCategory,
        'dataSupport': dataSupport,
        'runtimeSupport': runtimeSupport,
        'simulatorModes': simulatorModes,
        'effectSpec': effectSpec,
      };

  factory PetResolvedEffect.fromJson(Map<String, Object?> json) {
    final rawValues = (json['values'] as Map?)?.cast<String, Object?>() ??
        const <String, Object?>{};
    final values = <String, num>{};
    for (final entry in rawValues.entries) {
      final raw = entry.value;
      if (raw is num) {
        values[entry.key] = raw;
        continue;
      }
      final parsed = num.tryParse((raw ?? '').toString().trim());
      if (parsed != null) values[entry.key] = parsed;
    }

    final rawModes =
        (json['simulatorModes'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final simulatorModes = rawModes
        .map((e) => e?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    return PetResolvedEffect(
      sourceSlotId: (json['sourceSlotId'] ?? '').toString().trim(),
      sourceSkillName: (json['sourceSkillName'] ?? '').toString().trim(),
      values: Map<String, num>.unmodifiable(values),
      canonicalEffectId: (json['canonicalEffectId'] ?? '').toString().trim(),
      canonicalName: (json['canonicalName'] ?? '').toString().trim(),
      effectCategory: (json['effectCategory'] ?? '').toString().trim(),
      dataSupport: (json['dataSupport'] ?? '').toString().trim(),
      runtimeSupport: (json['runtimeSupport'] ?? '').toString().trim(),
      simulatorModes: simulatorModes,
      effectSpec: (json['effectSpec'] as Map?)?.cast<String, Object?>() ??
          const <String, Object?>{},
    );
  }
}
