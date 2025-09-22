// lib/data/config_loader.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'config_models.dart';

class ConfigLoader {
  /// Carica le stats del Boss da assets/raidComplete_data.json
  /// usando SEMPRE la tabella corretta (Raid/Blitz) + il livello selezionato.
  static Future<BossConfig> loadBossFromAssets({
    required int bossLevel,
    required bool raidMode,
    List<double>? overrideBossAdv,
    String assetPath = 'assets/raidComplete_data.json',
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final Map<String, dynamic> data = jsonDecode(raw);

    // --- Default: advantage dal blocco "boss" (se presente), MA NON il level ---
    List<double> advDefault;
    try {
      final lst =
          (data['boss']?['adv_vs_knights'] as List?) ?? const [1.0, 1.0, 1.0];
      advDefault = lst
          .map((e) => (e as num).toDouble())
          .toList(growable: false);
      if (advDefault.length != 3) {
        advDefault = const [1.0, 1.0, 1.0];
      }
    } catch (_) {
      advDefault = const [1.0, 1.0, 1.0];
    }
    final advVsKnights = overrideBossAdv ?? advDefault;

    // --- Selezione tabella per modalità ---
    final tables = (data['tables'] as Map<String, dynamic>?);
    if (tables == null) {
      throw StateError('JSON: manca la chiave "tables"');
    }
    final modeKey = raidMode ? 'Raid' : 'Blitz';
    final listDyn = tables[modeKey];
    if (listDyn == null || listDyn is! List) {
      throw StateError('JSON: manca la tabella "$modeKey"');
    }
    final List<Map<String, dynamic>> table = listDyn
        .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);

    // --- Clamp del livello e lookup by level ---
    final maxLevel = table.length; // Raid=7, Blitz=6
    var lv = bossLevel.clamp(1, maxLevel);
    Map<String, dynamic>? row = table.firstWhere(
      (e) => (e['level'] as num).toInt() == lv,
      orElse: () => <String, dynamic>{},
    );
    if (row.isEmpty) {
      // fallback per sicurezza (index-based)
      row = table[lv - 1];
    }

    final atk = (row['attack'] as num).toDouble();
    final def = (row['defense'] as num).toDouble();
    final hp = (row['hp'] as num).toInt();

    // --- Multiplier (debug) ---
    final mult = (data['Multiplier'] is num)
        ? (data['Multiplier'] as num).toDouble()
        : 1.0;

    final meta = BossMeta(
      level: lv,
      raidMode: raidMode,
      advVsKnights: advVsKnights,
    );

    return BossConfig(
      stats: BossStats(attack: atk, defense: def, hp: hp),
      meta: meta,
      multiplierM: mult,
    );
  }
}
