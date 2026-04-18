import 'dart:convert';

import 'package:flutter/services.dart';

import 'config_models.dart';

class ElixirsLoader {
  static List<ElixirConfig>? _cache;

  static int _elixirGroup(String name) {
    final n = name.trim().toLowerCase();
    if (n.startsWith('common')) return 0;
    if (n.startsWith('uncommon')) return 1;
    if (n.startsWith('rare')) return 2;
    if (n.startsWith('legendary')) return 3;
    if (n.contains('epic')) return 4;
    if (n.startsWith('knightmare')) return 5;
    if (n.startsWith('lavatide')) return 6;
    if (n.startsWith('wraith')) return 7;
    return 99;
  }

  static int _elixirVariant(String name) {
    final n = name.trim().toLowerCase();
    if (n.contains('ii+')) return 2;
    final ii = RegExp(r'\bii\b');
    if (ii.hasMatch(n)) return 1;
    return 0;
  }

  static int _compareElixir(ElixirConfig a, ElixirConfig b) {
    final ga = _elixirGroup(a.name);
    final gb = _elixirGroup(b.name);
    if (ga != gb) return ga.compareTo(gb);
    final va = _elixirVariant(a.name);
    final vb = _elixirVariant(b.name);
    if (va != vb) return va.compareTo(vb);
    return a.name.compareTo(b.name);
  }

  static Future<List<ElixirConfig>> load({String? gamemode}) async {
    if (_cache == null) {
      final raw = await rootBundle.loadString('assets/elixirs.json');
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _cache = const <ElixirConfig>[];
      } else {
        final root = decoded.cast<String, Object?>();
        final rawList = root['elixirs'];
        if (rawList is! List) {
          _cache = const <ElixirConfig>[];
        } else {
          final out = rawList
              .whereType<Map>()
              .map((e) => ElixirConfig.fromJson(e.cast<String, Object?>()))
              .toList(growable: true);
          out.sort(_compareElixir);
          _cache = List<ElixirConfig>.unmodifiable(out);
        }
      }
    }

    final list = _cache!;
    if (gamemode == null) return list;
    return list.where((e) => e.gamemode == gamemode).toList(growable: false);
  }

  static void clearCache() {
    _cache = null;
  }
}
