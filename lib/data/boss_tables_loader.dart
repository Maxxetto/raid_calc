import 'dart:convert';

import 'package:flutter/services.dart';

import 'config_models.dart';

class BossTablesLoader {
  static Map<String, Object?>? _cache;

  static Future<Map<String, Object?>> loadRaw() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/boss_tables.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _cache = const <String, Object?>{};
      return _cache!;
    }

    _cache = decoded.cast<String, Object?>();
    return _cache!;
  }

  static Future<List<BossLevelRow>> loadBossTable({
    required bool raidMode,
  }) async {
    final root = await loadRaw();
    final key = raidMode ? 'Raid' : 'Blitz';
    final raw = (root[key] as List?) ?? const <Object?>[];

    return raw
        .whereType<Map>()
        .map((e) => BossLevelRow.fromJson(e.cast<String, Object?>()))
        .toList(growable: false);
  }

  static Future<Map<int, EpicBossRow>> loadEpicTable() async {
    final root = await loadRaw();
    final raw = (root['Epic'] as List?) ?? const <Object?>[];

    final out = <int, EpicBossRow>{};
    for (final entry in raw) {
      if (entry is! Map) continue;
      final row = entry.cast<String, Object?>();
      if (row['level'] is! num ||
          row['attack'] is! num ||
          row['defense'] is! num ||
          row['hp'] is! num) {
        continue;
      }
      final parsed = EpicBossRow.fromJson(row);
      if (parsed.level <= 0) continue;
      out[parsed.level] = parsed;
    }

    return out;
  }

  static void clearCache() {
    _cache = null;
  }
}
