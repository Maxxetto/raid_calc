// lib/data/config_loader.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../data/config_models.dart';

/// Carica le stats del boss da assets e restituisce un RECORD:
/// ({BossStats stats, BossMeta meta, double multiplierM})
class ConfigLoader {
  static const String _defaultAsset = 'assets/raidComplete_data.json';

  /// Esempio d'uso:
  /// final loaded = await ConfigLoader.loadBossFromAssets(
  ///   raidMode: true, bossLevel: 7,
  ///   overrideBossAdv: [1.0, 1.0, 1.0],
  /// );
  /// final boss = BossConfig(stats: loaded.stats, meta: loaded.meta, multiplierM: loaded.multiplierM);
  static Future<({BossStats stats, BossMeta meta, double multiplierM})>
      loadBossFromAssets({
    required bool raidMode,
    required int bossLevel,
    List<double>? overrideBossAdv,
    String assetPath = _defaultAsset,
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final map = json.decode(raw) as Map<String, dynamic>;

    final tables = (map['tables'] as Map<String, dynamic>);
    final tableKey = raidMode ? 'Raid' : 'Blitz';
    final list = (tables[tableKey] as List).cast<Map<String, dynamic>>();

    // Clamp del livello ai range disponibili in tabella
    final minLvl = 1;
    final maxLvl = list.fold<int>(
        1,
        (m, e) =>
            (e['level'] as num).toInt() > m ? (e['level'] as num).toInt() : m);
    final lvl = bossLevel.clamp(minLvl, maxLvl);

    // Trova la riga corrispondente al livello (fallback: ultima disponibile)
    Map<String, dynamic> row = list.firstWhere(
      (e) => (e['level'] as num).toInt() == lvl,
      orElse: () => list.last,
    );

    final stats = BossStats(
      attack: (row['attack'] as num).toDouble(),
      defense: (row['defense'] as num).toDouble(),
      hp: (row['hp'] as num).toInt(),
    );

    // Multiplier opzionale
    final multiplierM = (map['Multiplier'] is num)
        ? (map['Multiplier'] as num).toDouble()
        : 1.0;

    // Adv default dall'asset "boss.adv_vs_knights" se presente
    List<double> advDefault = const [1.0, 1.0, 1.0];
    if (map['boss'] is Map) {
      final b = (map['boss'] as Map)['adv_vs_knights'];
      if (b is List && b.length == 3) {
        advDefault = b.map((e) => (e as num).toDouble()).toList();
      }
    }

    final adv = (overrideBossAdv != null && overrideBossAdv.length == 3)
        ? overrideBossAdv
        : advDefault;

    final meta = BossMeta(
      level: lvl,
      raidMode: raidMode,
      advVsKnights: adv,
    );

    return (stats: stats, meta: meta, multiplierM: multiplierM);
  }
}
