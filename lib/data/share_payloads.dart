import 'dart:convert';

import '../core/battle_outcome.dart';
import '../core/sim_types.dart';
import 'config_models.dart';
import 'setup_models.dart';

class SharePayloadException implements Exception {
  final String message;

  const SharePayloadException(this.message);

  @override
  String toString() => 'SharePayloadException($message)';
}

Map<String, Object?> decodeShareJsonMap(String raw) {
  final normalized = _stripCodeFence(raw).trim();
  if (normalized.isEmpty) {
    throw const SharePayloadException('empty_payload');
  }
  final decoded = jsonDecode(normalized);
  if (decoded is! Map) {
    throw const SharePayloadException('invalid_payload_root');
  }
  return decoded.cast<String, Object?>();
}

String encodePrettyJson(Map<String, Object?> payload) =>
    const JsonEncoder.withIndent('  ').convert(payload);

String _stripCodeFence(String raw) {
  final text = raw.trim();
  if (!text.startsWith('```')) return text;
  final lines = text.split('\n');
  if (lines.length < 2) return text;
  final first = lines.first.trim();
  final last = lines.last.trim();
  if (!first.startsWith('```') || last != '```') return text;
  return lines.sublist(1, lines.length - 1).join('\n');
}

class SetupSharePayload {
  static const String kind = 'raid_calc.setup';
  static const int schemaVersion = 2;

  final SetupSnapshot setup;
  final String? name;
  final String exportedAtIso;

  const SetupSharePayload({
    required this.setup,
    this.name,
    required this.exportedAtIso,
  });

  factory SetupSharePayload.fromRecord(SetupSlotRecord record) =>
      SetupSharePayload(
        setup: record.setup,
        name: record.customName,
        exportedAtIso: DateTime.now().toIso8601String(),
      );

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'v': schemaVersion,
        'exportedAtIso': exportedAtIso,
        if (name != null && name!.trim().isNotEmpty) 'name': name!.trim(),
        'setup': setup.toJson(),
      };

  factory SetupSharePayload.fromJson(Map<String, Object?> j) {
    final rawKind = (j['kind'] as String?)?.trim();
    if (rawKind != kind) {
      throw const SharePayloadException('invalid_setup_payload_kind');
    }
    final rawSetup = (j['setup'] as Map?)?.cast<String, Object?>();
    if (rawSetup == null) {
      throw const SharePayloadException('missing_setup_payload_setup');
    }
    return SetupSharePayload(
      setup: SetupSnapshot.fromJson(rawSetup),
      name: (j['name'] as String?)?.trim(),
      exportedAtIso: (j['exportedAtIso'] as String?)?.trim().isNotEmpty == true
          ? (j['exportedAtIso'] as String).trim()
          : DateTime.now().toIso8601String(),
    );
  }

  factory SetupSharePayload.fromText(String raw) =>
      SetupSharePayload.fromJson(decodeShareJsonMap(raw));
}

class ResultsSharePayload {
  static const String kind = 'raid_calc.results';
  static const int schemaVersion = 4;

  final bool cycloneUseGemsForSpecials;
  final bool isPremium;
  final bool debugEnabled;
  final int milestoneTargetPoints;
  final int startEnergies;
  final int freeRaidEnergies;
  final List<String> knightIds;
  final ShatterShieldConfig? shatter;
  final Precomputed pre;
  final SimStats stats;
  final List<ElixirInventoryItem> elixirs;
  final String petElement1Id;
  final String? petElement2Id;
  final List<List<String>> knightElementPairs;
  final String exportedAtIso;
  final String? appVersion;
  final String? appBuildNumber;

  const ResultsSharePayload({
    this.cycloneUseGemsForSpecials = true,
    required this.isPremium,
    required this.debugEnabled,
    required this.milestoneTargetPoints,
    required this.startEnergies,
    required this.freeRaidEnergies,
    required this.knightIds,
    required this.shatter,
    required this.pre,
    required this.stats,
    required this.elixirs,
    required this.petElement1Id,
    required this.petElement2Id,
    required this.knightElementPairs,
    required this.exportedAtIso,
    this.appVersion,
    this.appBuildNumber,
  });

  Map<String, Object?> toJson() => <String, Object?>{
        'kind': kind,
        'v': schemaVersion,
        'exportedAtIso': exportedAtIso,
        if (appVersion != null && appVersion!.trim().isNotEmpty)
          'appVersion': appVersion!.trim(),
        if (appBuildNumber != null && appBuildNumber!.trim().isNotEmpty)
          'appBuildNumber': appBuildNumber!.trim(),
        'cycloneUseGemsForSpecials': cycloneUseGemsForSpecials,
        'isPremium': isPremium,
        'debugEnabled': debugEnabled,
        'milestoneTargetPoints': milestoneTargetPoints,
        'startEnergies': startEnergies,
        'freeRaidEnergies': freeRaidEnergies,
        'knightIds': knightIds,
        'shatter': shatter?.toJson(),
        'pre': pre.toJson(),
        'stats': stats.toJson(),
        'elixirs': elixirs.map((e) => e.toJson()).toList(growable: false),
        'petElement1Id': petElement1Id,
        'petElement2Id': petElement2Id,
        'knightElementPairs': knightElementPairs,
      };

  factory ResultsSharePayload.fromJson(Map<String, Object?> j) {
    final hasLegacyShape = j.containsKey('pre') && j.containsKey('stats');
    final rawKind = (j['kind'] as String?)?.trim();
    if (!hasLegacyShape && rawKind != kind) {
      throw const SharePayloadException('invalid_results_payload_kind');
    }

    final preMap = (j['pre'] as Map?)?.cast<String, Object?>();
    final statsMap = (j['stats'] as Map?)?.cast<String, Object?>();
    if (preMap == null || statsMap == null) {
      throw const SharePayloadException('missing_results_payload_data');
    }

    final elixirsRaw = (j['elixirs'] as List?)?.cast<Object?>() ?? const [];
    final elixirs = elixirsRaw
        .whereType<Map>()
        .map((e) => ElixirInventoryItem.fromJson(e.cast<String, Object?>()))
        .where((e) => e.name.isNotEmpty)
        .toList(growable: false);

    final shRaw = (j['shatter'] as Map?)?.cast<String, Object?>();

    final knightIdsRaw = (j['knightIds'] as List?)?.cast<Object?>() ?? const [];
    final knightIds = knightIdsRaw
        .map((e) => (e?.toString() ?? '').trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final knightElementsRaw =
        (j['knightElementPairs'] as List?)?.cast<Object?>() ?? const [];
    final knightElementPairs = knightElementsRaw
        .whereType<List>()
        .map((pair) => pair
            .cast<Object?>()
            .map((e) => (e?.toString() ?? '').trim())
            .where((e) => e.isNotEmpty)
            .take(2)
            .toList(growable: false))
        .toList(growable: false);

    int readInt(Object? raw, int fallback) {
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw.trim()) ?? fallback;
      return fallback;
    }

    return ResultsSharePayload(
      cycloneUseGemsForSpecials: j['cycloneUseGemsForSpecials'] == null
          ? true
          : j['cycloneUseGemsForSpecials'] == true,
      isPremium: j['isPremium'] == true,
      debugEnabled: j['debugEnabled'] == true,
      milestoneTargetPoints: readInt(j['milestoneTargetPoints'], 1000000000),
      startEnergies: readInt(j['startEnergies'], 0),
      freeRaidEnergies: readInt(j['freeRaidEnergies'], 30),
      knightIds: knightIds,
      shatter: shRaw == null ? null : ShatterShieldConfig.fromJson(shRaw),
      pre: Precomputed.fromJson(preMap),
      stats: SimStats.fromJson(statsMap),
      elixirs: elixirs,
      petElement1Id: ((j['petElement1Id'] as String?) ?? 'fire').trim().isEmpty
          ? 'fire'
          : ((j['petElement1Id'] as String?) ?? 'fire').trim(),
      petElement2Id: ((j['petElement2Id'] as String?) ?? '').trim().isEmpty
          ? null
          : ((j['petElement2Id'] as String?) ?? '').trim(),
      knightElementPairs: knightElementPairs,
      exportedAtIso: (j['exportedAtIso'] as String?)?.trim().isNotEmpty == true
          ? (j['exportedAtIso'] as String).trim()
          : DateTime.now().toIso8601String(),
      appVersion: (j['appVersion'] as String?)?.trim(),
      appBuildNumber: (j['appBuildNumber'] as String?)?.trim(),
    );
  }

  factory ResultsSharePayload.fromText(String raw) =>
      ResultsSharePayload.fromJson(decodeShareJsonMap(raw));
}
