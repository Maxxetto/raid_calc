import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class UaScoreMilestoneRule {
  final int minPoints;
  final int pieces;
  final bool excludeOnFirstBlitzOfMonth;

  const UaScoreMilestoneRule({
    required this.minPoints,
    required this.pieces,
    required this.excludeOnFirstBlitzOfMonth,
  });

  factory UaScoreMilestoneRule.fromJson(Map<String, Object?> j) {
    return UaScoreMilestoneRule(
      minPoints: _readInt(j['minPoints'], fallback: 0, min: 0, max: 2000000000),
      pieces: _readInt(j['pieces'], fallback: 0, min: 0, max: 999),
      excludeOnFirstBlitzOfMonth:
          (j['excludeOnFirstBlitzOfMonth'] as bool?) ?? false,
    );
  }

  bool get isValid => minPoints > 0 && pieces > 0;
}

@immutable
class UaPlacementTierRule {
  final int rankFrom;
  final int rankTo;
  final int pieces;
  final bool excludeOnFirstBlitzOfMonth;

  const UaPlacementTierRule({
    required this.rankFrom,
    required this.rankTo,
    required this.pieces,
    required this.excludeOnFirstBlitzOfMonth,
  });

  factory UaPlacementTierRule.fromJson(Map<String, Object?> j) {
    final rankFrom = _readInt(j['rankFrom'], fallback: 0, min: 0, max: 99999);
    final rankTo = _readInt(j['rankTo'], fallback: 0, min: 0, max: 99999);
    return UaPlacementTierRule(
      rankFrom: rankFrom,
      rankTo: rankTo,
      pieces: _readInt(j['pieces'], fallback: 0, min: 0, max: 999),
      excludeOnFirstBlitzOfMonth:
          (j['excludeOnFirstBlitzOfMonth'] as bool?) ?? false,
    );
  }

  bool get isValid => rankFrom > 0 && rankTo >= rankFrom && pieces > 0;

  bool matchesRank(int rank) => rank >= rankFrom && rank <= rankTo;
}

@immutable
class UaEventRule {
  final bool enabled;
  final List<UaScoreMilestoneRule> scoreMilestones;
  final List<UaPlacementTierRule> guildPlacementTiers;
  final List<UaPlacementTierRule> individualPlacementTiers;
  final bool allSourcesCumulative;
  final int piecesPerCompletedHeroic;

  const UaEventRule({
    required this.enabled,
    required this.scoreMilestones,
    required this.guildPlacementTiers,
    required this.individualPlacementTiers,
    required this.allSourcesCumulative,
    required this.piecesPerCompletedHeroic,
  });

  factory UaEventRule.fromJson(Map<String, Object?> j) {
    final scoreRaw =
        (j['scoreMilestones'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final guildRaw = (j['guildPlacementTiers'] as List?)?.cast<Object?>() ??
        const <Object?>[];
    final individualRaw =
        (j['individualPlacementTiers'] as List?)?.cast<Object?>() ??
            const <Object?>[];

    final score = scoreRaw
        .whereType<Map>()
        .map((e) => UaScoreMilestoneRule.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);

    final guild = guildRaw
        .whereType<Map>()
        .map((e) => UaPlacementTierRule.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);

    final individual = individualRaw
        .whereType<Map>()
        .map((e) => UaPlacementTierRule.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);

    return UaEventRule(
      enabled: (j['enabled'] as bool?) ?? true,
      scoreMilestones: score,
      guildPlacementTiers: guild,
      individualPlacementTiers: individual,
      allSourcesCumulative: (j['allSourcesCumulative'] as bool?) ?? true,
      piecesPerCompletedHeroic: _readInt(
        j['piecesPerCompletedHeroic'],
        fallback: 1,
        min: 0,
        max: 99,
      ),
    );
  }

  int scorePieces(int points, {required bool isFirstBlitzOfMonth}) {
    if (!enabled || points <= 0) return 0;
    var out = 0;
    for (final tier in scoreMilestones) {
      if (isFirstBlitzOfMonth && tier.excludeOnFirstBlitzOfMonth) continue;
      if (points >= tier.minPoints) out += tier.pieces;
    }
    return out;
  }

  int guildPlacementPieces(int rank, {required bool isFirstBlitzOfMonth}) {
    if (!enabled || rank <= 0) return 0;
    for (final tier in guildPlacementTiers) {
      if (isFirstBlitzOfMonth && tier.excludeOnFirstBlitzOfMonth) continue;
      if (tier.matchesRank(rank)) return tier.pieces;
    }
    return 0;
  }

  int individualPlacementPieces(
    int rank, {
    required bool isFirstBlitzOfMonth,
  }) {
    if (!enabled || rank <= 0) return 0;
    for (final tier in individualPlacementTiers) {
      if (isFirstBlitzOfMonth && tier.excludeOnFirstBlitzOfMonth) continue;
      if (tier.matchesRank(rank)) return tier.pieces;
    }
    return 0;
  }
}

@immutable
class UaBonusEntryRule {
  final String id;
  final String label;
  final int pieces;
  final String? dependsOn;

  const UaBonusEntryRule({
    required this.id,
    required this.label,
    required this.pieces,
    required this.dependsOn,
  });

  factory UaBonusEntryRule.fromJson(Map<String, Object?> j) {
    final dependsRaw = (j['dependsOn'] ?? '').toString().trim();
    return UaBonusEntryRule(
      id: (j['id'] ?? '').toString().trim(),
      label: (j['label'] ?? '').toString().trim(),
      pieces: _readInt(j['pieces'], fallback: 0, min: 0, max: 99),
      dependsOn: dependsRaw.isEmpty ? null : dependsRaw,
    );
  }

  bool get isValid => id.isNotEmpty && label.isNotEmpty && pieces > 0;
}

@immutable
class UaRuleset {
  final String id;
  final String label;
  final String source;
  final bool active;
  final bool appUpdateRequiredOnChange;
  final Map<String, UaEventRule> eventRules;
  final Map<String, List<UaBonusEntryRule>> bonusRules;

  const UaRuleset({
    required this.id,
    required this.label,
    required this.source,
    required this.active,
    required this.appUpdateRequiredOnChange,
    required this.eventRules,
    required this.bonusRules,
  });

  factory UaRuleset.fromJson(Map<String, Object?> j) {
    final eventMap =
        (j['eventRules'] as Map?)?.cast<String, Object?>() ?? const {};
    final parsedEvents = <String, UaEventRule>{};
    for (final entry in eventMap.entries) {
      final value = entry.value;
      if (value is! Map) continue;
      parsedEvents[entry.key] = UaEventRule.fromJson(
        value.cast<String, Object?>(),
      );
    }

    final bonusMap =
        (j['bonusRules'] as Map?)?.cast<String, Object?>() ?? const {};
    final parsedBonus = <String, List<UaBonusEntryRule>>{};
    for (final entry in bonusMap.entries) {
      final list = (entry.value as List?)?.cast<Object?>() ?? const <Object?>[];
      parsedBonus[entry.key] = list
          .whereType<Map>()
          .map((e) => UaBonusEntryRule.fromJson(e.cast<String, Object?>()))
          .where((e) => e.isValid)
          .toList(growable: false);
    }

    return UaRuleset(
      id: (j['id'] ?? '').toString().trim(),
      label: (j['label'] ?? '').toString().trim(),
      source: (j['source'] ?? '').toString().trim(),
      active: (j['active'] as bool?) ?? false,
      appUpdateRequiredOnChange:
          (j['appUpdateRequiredOnChange'] as bool?) ?? true,
      eventRules: Map.unmodifiable(parsedEvents),
      bonusRules: Map.unmodifiable(parsedBonus),
    );
  }

  bool get isValid =>
      id.isNotEmpty && label.isNotEmpty && eventRules.isNotEmpty;
}

class UaPlannerRulesCatalog {
  final int schemaVersion;
  final List<UaRuleset> rulesets;

  const UaPlannerRulesCatalog({
    required this.schemaVersion,
    required this.rulesets,
  });

  factory UaPlannerRulesCatalog.fromJson(Map<String, Object?> j) {
    final raw = (j['rulesets'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final rulesets = raw
        .whereType<Map>()
        .map((e) => UaRuleset.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);
    return UaPlannerRulesCatalog(
      schemaVersion:
          _readInt(j['schemaVersion'], fallback: 1, min: 1, max: 9999),
      rulesets: rulesets,
    );
  }

  UaRuleset? get activeRuleset {
    for (final r in rulesets) {
      if (r.active) return r;
    }
    return rulesets.isNotEmpty ? rulesets.first : null;
  }
}

class UaPlannerRulesLoader {
  static UaPlannerRulesCatalog? _cache;

  static Future<UaPlannerRulesCatalog> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/ua_planner_rules.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _cache = const UaPlannerRulesCatalog(schemaVersion: 1, rulesets: []);
      return _cache!;
    }
    _cache = UaPlannerRulesCatalog.fromJson(decoded.cast<String, Object?>());
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
  }
}

int _readInt(
  Object? raw, {
  required int fallback,
  required int min,
  required int max,
}) {
  int? v;
  if (raw is int) {
    v = raw;
  } else if (raw is num) {
    v = raw.toInt();
  } else if (raw is String) {
    v = int.tryParse(raw.trim());
  }
  if (v == null) return fallback;
  return v.clamp(min, max);
}
