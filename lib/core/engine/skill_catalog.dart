import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/pet_effect_models.dart';
import '../../util/text_encoding_guard.dart';
import '../debug/debug_hooks.dart';

String _normalizeSkillName(String rawName) =>
    TextEncodingGuard.repairLikelyMojibake(rawName).trim().toLowerCase();

@immutable
class EffectiveSkillValues {
  final Map<String, num> baseValues;
  final Map<String, num> overrideValues;
  final Map<String, num> effectiveValues;

  const EffectiveSkillValues._({
    required this.baseValues,
    required this.overrideValues,
    required this.effectiveValues,
  });

  factory EffectiveSkillValues({
    Map<String, num> baseValues = const <String, num>{},
    Map<String, num> overrideValues = const <String, num>{},
  }) {
    final merged = <String, num>{
      ...baseValues,
      ...overrideValues,
    };
    return EffectiveSkillValues._(
      baseValues: Map<String, num>.unmodifiable(baseValues),
      overrideValues: Map<String, num>.unmodifiable(overrideValues),
      effectiveValues: Map<String, num>.unmodifiable(merged),
    );
  }

  num? operator [](String key) => effectiveValues[key];

  bool containsKey(String key) => effectiveValues.containsKey(key);

  int intValue(String key, {int fallback = 0}) =>
      effectiveValues[key]?.toInt() ?? fallback;

  double doubleValue(String key, {double fallback = 0.0}) =>
      effectiveValues[key]?.toDouble() ?? fallback;

  double fractionValue(String key, {double fallback = 0.0}) {
    final raw = effectiveValues[key];
    if (raw == null) return fallback;
    final value = raw.toDouble();
    if (!value.isFinite || value < 0) return fallback;
    return value <= 1.0 ? value : value / 100.0;
  }

  bool keyDisablesEffect(String key) =>
      effectiveValues[key] != null && effectiveValues[key]!.toDouble() == 0.0;
}

@immutable
class BattleSkillDefinition {
  final String sourceSlotId;
  final String sourceSkillName;
  final String originalCanonicalEffectId;
  final String canonicalEffectId;
  final String displayName;
  final String effectCategory;
  final String dataSupport;
  final String runtimeSupport;
  final List<String> simulatorModes;
  final Map<String, Object?> effectSpec;
  final EffectiveSkillValues values;

  const BattleSkillDefinition({
    required this.sourceSlotId,
    required this.sourceSkillName,
    required this.originalCanonicalEffectId,
    required this.canonicalEffectId,
    required this.displayName,
    required this.effectCategory,
    required this.dataSupport,
    required this.runtimeSupport,
    required this.simulatorModes,
    required this.effectSpec,
    required this.values,
  });

  bool matchesCast(PetSpecialCastKind cast) => switch (cast) {
        PetSpecialCastKind.special1 =>
          sourceSlotId == 'skill11' || sourceSlotId == 'skill12',
        PetSpecialCastKind.special2 => sourceSlotId == 'skill2',
      };

  bool get isCycloneBoost => canonicalEffectId == BattleSkillCatalog.cycloneId;
  bool get isSpecialRegen =>
      canonicalEffectId == BattleSkillCatalog.specialRegenId;
  bool get isSpecialRegenInfinite =>
      canonicalEffectId == BattleSkillCatalog.specialRegenInfiniteId;
  bool get isDisabledByOverride =>
      values.overrideValues.values.any((value) => value.toDouble() == 0.0);

  Map<String, Object?> toJson() => <String, Object?>{
        'sourceSlotId': sourceSlotId,
        'sourceSkillName': sourceSkillName,
        'originalCanonicalEffectId': originalCanonicalEffectId,
        'canonicalEffectId': canonicalEffectId,
        'displayName': displayName,
        'effectCategory': effectCategory,
        'dataSupport': dataSupport,
        'runtimeSupport': runtimeSupport,
        'simulatorModes': simulatorModes,
        'effectSpec': effectSpec,
        'baseValues': values.baseValues,
        'overrideValues': values.overrideValues,
        'effectiveValues': values.effectiveValues,
      };
}

class BattleSkillCatalog {
  static const String cycloneId = 'cyclone_boost';
  static const String deathBlowId = 'death_blow';
  static const String durableRockShieldId = 'durable_rock_shield';
  static const String elementalWeaknessId = 'elemental_weakness';
  static const String fortunesCallId = 'fortunes_call';
  static const String readyToCritId = 'ready_to_crit';
  static const String revengeStrikeId = 'revenge_strike';
  static const String shadowSlashId = 'shadow_slash';
  static const String shatterShieldId = 'shatter_shield';
  static const String soulBurnId = 'soul_burn';
  static const String specialRegenId = 'special_regeneration';
  static const String specialRegenInfiniteId = 'special_regeneration_infinite';
  static const String vampiricAttackId = 'vampiric_attack';

  static const Set<String> knownEffectIds = <String>{
    cycloneId,
    deathBlowId,
    durableRockShieldId,
    elementalWeaknessId,
    fortunesCallId,
    readyToCritId,
    revengeStrikeId,
    shadowSlashId,
    shatterShieldId,
    soulBurnId,
    specialRegenId,
    specialRegenInfiniteId,
    vampiricAttackId,
  };

  static String normalizeCanonicalEffectId(
    String? rawId, {
    String fallbackSkillName = '',
  }) {
    final trimmed = (rawId ?? '').trim().toLowerCase();
    if (trimmed.isNotEmpty) {
      return switch (trimmed) {
        'cyclone_boost_air' || 'cyclone_boost_earth' => cycloneId,
        'leech_strike' => vampiricAttackId,
        'fortunes_call' => fortunesCallId,
        _ => trimmed,
      };
    }

    final normalizedName = _normalizeSkillName(fallbackSkillName);
    return switch (normalizedName) {
      'cyclone air boost' ||
      'cyclone earth boost' ||
      'cyclone boost' =>
        cycloneId,
      'death blow' => deathBlowId,
      'durable rock shield' => durableRockShieldId,
      'element weakness' || 'elemental weakness' => elementalWeaknessId,
      "fortune's call" => fortunesCallId,
      'ready to crit' => readyToCritId,
      'revenge strike' => revengeStrikeId,
      'shadow slash' => shadowSlashId,
      'shatter shield' => shatterShieldId,
      'soul burn' => soulBurnId,
      'special regen' || 'special regeneration' => specialRegenId,
      'special regeneration (inf)' ||
      'special regeneration ∞' =>
        specialRegenInfiniteId,
      'vampiric attack' || 'leech strike' => vampiricAttackId,
      _ => '',
    };
  }

  static String displayNameForId(
    String canonicalEffectId, {
    String fallback = '',
  }) {
    return switch (normalizeCanonicalEffectId(canonicalEffectId)) {
      cycloneId => 'Cyclone Boost',
      deathBlowId => 'Death Blow',
      durableRockShieldId => 'Durable Rock Shield',
      elementalWeaknessId => 'Elemental Weakness',
      fortunesCallId => "Fortune's Call",
      readyToCritId => 'Ready to Crit',
      revengeStrikeId => 'Revenge Strike',
      shadowSlashId => 'Shadow Slash',
      shatterShieldId => 'Shatter Shield',
      soulBurnId => 'Soul Burn',
      specialRegenId => 'Special Regeneration',
      specialRegenInfiniteId => 'Special Regeneration ∞',
      vampiricAttackId when _normalizeSkillName(fallback) == 'leech strike' =>
        'Leech Strike',
      vampiricAttackId => 'Vampiric Attack',
      _ => fallback.trim(),
    };
  }

  static String skillKeyForSlot({
    required String sourceSlotId,
    required String canonicalEffectId,
  }) {
    return '${sourceSlotId.trim().toLowerCase()}|'
        '${normalizeCanonicalEffectId(canonicalEffectId)}';
  }

  static BattleSkillDefinition fromResolvedEffect(
    PetResolvedEffect effect, {
    Map<String, num> overrideValues = const <String, num>{},
  }) {
    final normalizedId = normalizeCanonicalEffectId(
      effect.canonicalEffectId,
      fallbackSkillName: effect.sourceSkillName,
    );
    final fallbackName = effect.canonicalName.trim().isEmpty
        ? effect.sourceSkillName
        : effect.canonicalName;
    return BattleSkillDefinition(
      sourceSlotId: effect.sourceSlotId.trim(),
      sourceSkillName: effect.sourceSkillName.trim(),
      originalCanonicalEffectId: effect.canonicalEffectId.trim(),
      canonicalEffectId: normalizedId,
      displayName: displayNameForId(
        normalizedId,
        fallback: fallbackName,
      ),
      effectCategory: effect.effectCategory.trim(),
      dataSupport: effect.dataSupport.trim(),
      runtimeSupport: effect.runtimeSupport.trim(),
      simulatorModes: List<String>.unmodifiable(effect.simulatorModes),
      effectSpec: Map<String, Object?>.unmodifiable(effect.effectSpec),
      values: EffectiveSkillValues(
        baseValues: Map<String, num>.from(effect.values),
        overrideValues: overrideValues,
      ),
    );
  }

  static List<BattleSkillDefinition> buildDefinitions(
    Iterable<PetResolvedEffect> effects, {
    Map<String, Map<String, num>> overrideValuesBySkillKey =
        const <String, Map<String, num>>{},
  }) {
    return List<BattleSkillDefinition>.unmodifiable(
      effects.map((effect) {
        final normalizedId = normalizeCanonicalEffectId(
          effect.canonicalEffectId,
          fallbackSkillName: effect.sourceSkillName,
        );
        final key = skillKeyForSlot(
          sourceSlotId: effect.sourceSlotId,
          canonicalEffectId: normalizedId,
        );
        return fromResolvedEffect(
          effect,
          overrideValues: overrideValuesBySkillKey[key] ?? const {},
        );
      }),
    );
  }

  static BattleSkillDefinition? firstForCast(
    Iterable<BattleSkillDefinition> definitions,
    PetSpecialCastKind cast,
  ) {
    for (final definition in definitions) {
      if (definition.matchesCast(cast)) return definition;
    }
    return null;
  }

  static bool hasCycloneBoost(Iterable<BattleSkillDefinition> definitions) =>
      definitions.any((definition) => definition.isCycloneBoost);

  static bool hasActiveCycloneBoost(
    Iterable<BattleSkillDefinition> definitions,
  ) =>
      definitions.any(
        (definition) =>
            definition.isCycloneBoost && !definition.isDisabledByOverride,
      );

  static int maxCycloneStacks(
    Iterable<BattleSkillDefinition> definitions, {
    int fallback = 5,
  }) {
    int? resolved;
    for (final definition in definitions) {
      if (!definition.isCycloneBoost) continue;
      final turns = definition.values.intValue('turns', fallback: fallback);
      final candidate = turns <= 0 ? fallback : turns;
      resolved = resolved == null ? candidate : math.max(resolved, candidate);
    }
    return resolved ?? fallback;
  }
}
