import 'dart:convert';

import 'package:flutter/services.dart';

class SimRulesLoader {
  static Map<String, Object?>? _cache;

  static Future<Map<String, Object?>> loadRaw() async {
    if (_cache != null) return _cache!;

    final raw = await rootBundle.loadString('assets/sim_rules.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _cache = const <String, Object?>{};
      return _cache!;
    }

    _cache = decoded.cast<String, Object?>();
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
  }
}
