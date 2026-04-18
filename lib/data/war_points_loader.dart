import 'dart:convert';

import 'package:flutter/services.dart';

import 'config_models.dart';

class WarPointsLoader {
  static WarPointsConfig? _cache;

  static Future<WarPointsConfig> load() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/war_points.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _cache = const WarPointsConfig(
        eu: WarPointsServer(
          normal: WarPointsSet(
            base: 0,
            frenzy: 0,
            powerAttack: 0,
            frenzyPowerAttack: 0,
          ),
          strip: WarPointsSet(
            base: 0,
            frenzy: 0,
            powerAttack: 0,
            frenzyPowerAttack: 0,
          ),
        ),
        global: WarPointsServer(
          normal: WarPointsSet(
            base: 0,
            frenzy: 0,
            powerAttack: 0,
            frenzyPowerAttack: 0,
          ),
          strip: WarPointsSet(
            base: 0,
            frenzy: 0,
            powerAttack: 0,
            frenzyPowerAttack: 0,
          ),
        ),
      );
      return _cache!;
    }

    final root = decoded.cast<String, Object?>();
    final rawWar = (root['War'] as Map?)?.cast<String, Object?>() ?? const {};
    _cache = WarPointsConfig.fromJson(rawWar);
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
  }
}
