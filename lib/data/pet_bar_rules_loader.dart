import 'dart:convert';

import 'package:flutter/services.dart';

import 'config_models.dart';

class PetBarRulesLoader {
  static Map<String, Object?>? _rawCache;
  static final Map<String, PetTicksBarConfig> _configCache =
      <String, PetTicksBarConfig>{};

  static Future<Map<String, Object?>> loadRaw() async {
    if (_rawCache != null) return _rawCache!;

    final raw = await rootBundle.loadString('assets/pet_bar_rules.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _rawCache = const <String, Object?>{};
      return _rawCache!;
    }

    _rawCache = decoded.cast<String, Object?>();
    return _rawCache!;
  }

  static Map<String, Object?> resolveScoped({
    required Map<String, Object?> raw,
    required String bossTypeKey,
    required String fightModeKey,
  }) {
    final resolved = <String, Object?>{
      ...raw,
    };
    resolved.remove('scopedRules');

    final scopedRoot =
        (raw['scopedRules'] as Map?)?.cast<String, Object?>() ?? const {};
    final bossScope =
        (scopedRoot[bossTypeKey] as Map?)?.cast<String, Object?>() ?? const {};
    final modeScope =
        (bossScope[fightModeKey] as Map?)?.cast<String, Object?>() ?? const {};

    resolved.addAll(modeScope);
    return resolved;
  }

  static Future<PetTicksBarConfig> loadConfig({
    String? bossTypeKey,
    String? fightModeKey,
  }) async {
    final cacheKey = '${bossTypeKey ?? '*'}::${fightModeKey ?? '*'}';
    if (_configCache.containsKey(cacheKey)) {
      return _configCache[cacheKey]!;
    }

    final raw = await loadRaw();
    final scopedRaw = (bossTypeKey == null || fightModeKey == null)
        ? raw
        : resolveScoped(
            raw: raw,
            bossTypeKey: bossTypeKey,
            fightModeKey: fightModeKey,
          );
    final cfg = PetTicksBarConfig.fromJson(scopedRaw);
    _configCache[cacheKey] = cfg;
    return cfg;
  }

  static void clearCache() {
    _rawCache = null;
    _configCache.clear();
  }
}
