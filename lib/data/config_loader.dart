// lib/data/config_loader.dart
import 'boss_tables_loader.dart';
import 'config_models.dart';
import 'elixirs_loader.dart';
import 'knight_bar_rules_loader.dart';
import 'ocr_defaults_loader.dart';
import 'pet_bar_rules_loader.dart';
import 'sim_rules_loader.dart';
import 'war_points_loader.dart';

class ConfigLoader {
  static Future<BossConfig> loadBoss({
    required bool raidMode,
    required int bossLevel,
    required List<double> adv,
    String? fightModeKey,
  }) async {
    final rows = await BossTablesLoader.loadBossTable(raidMode: raidMode);

    final row = rows.firstWhere(
      (r) => r.level == bossLevel,
      orElse: () => rows.first,
    );

    final simRules = await SimRulesLoader.loadRaw();
    final petBarRaw = await PetBarRulesLoader.loadRaw();
    final knightBarRaw = await KnightBarRulesLoader.loadRaw();
    final petBar = PetBarRulesLoader.resolveScoped(
      raw: petBarRaw,
      bossTypeKey: raidMode ? 'raid' : 'blitz',
      fightModeKey: fightModeKey ?? 'normal',
    );
    final knightBar = KnightBarRulesLoader.resolveScoped(
      raw: knightBarRaw,
      bossTypeKey: raidMode ? 'raid' : 'blitz',
      fightModeKey: fightModeKey ?? 'normal',
    );
    final meta = BossMeta.fromSources(
      simRules: simRules,
      petTicksBar: petBar,
      knightSpecialBar: knightBar,
      overrides: <String, Object?>{
        'raidMode': raidMode,
        'level': bossLevel,
        'advVsKnights': Advantage.normalizeList(adv),
      },
    );

    final stats = BossStats(
      attack: row.attack,
      defense: row.defense,
      hp: row.hp,
    );

    return BossConfig(meta: meta, stats: stats);
  }

  static Future<BossMeta> loadEpicMeta({
    required bool raidMode,
    required List<double> adv,
    String? fightModeKey,
  }) async {
    final simRules = await SimRulesLoader.loadRaw();
    final petBarRaw = await PetBarRulesLoader.loadRaw();
    final knightBarRaw = await KnightBarRulesLoader.loadRaw();
    final petBar = PetBarRulesLoader.resolveScoped(
      raw: petBarRaw,
      bossTypeKey: 'epic',
      fightModeKey: fightModeKey ?? 'normal',
    );
    final knightBar = KnightBarRulesLoader.resolveScoped(
      raw: knightBarRaw,
      bossTypeKey: 'epic',
      fightModeKey: fightModeKey ?? 'normal',
    );
    final advNorm = adv.isEmpty
        ? <double>[1.0]
        : adv.map(Advantage.normalize).toList(growable: false);

    return BossMeta.fromSources(
      simRules: simRules,
      petTicksBar: petBar,
      knightSpecialBar: knightBar,
      overrides: <String, Object?>{
        'raidMode': raidMode,
        'level': 1,
        'advVsKnights': advNorm,
      },
    );
  }

  static Future<int> loadEpicThreshold() async {
    final root = await SimRulesLoader.loadRaw();
    final raw = root['thresholdEpicBoss'];
    final v = (raw is num) ? raw.toInt() : 80;
    if (v < 0) return 0;
    if (v > 100) return 100;
    return v;
  }

  static Future<int> loadRaidFreeEnergies() async {
    final root = await SimRulesLoader.loadRaw();
    final raw = root['raidFreeEnergies'];
    final v = (raw is num) ? raw.toInt() : 30;
    if (v < 0) return 0;
    if (v > 2000000000) return 2000000000;
    return v;
  }

  static Future<double> loadDefaultDurableRockShield({
    String bossTypeKey = 'raid',
    String fightModeKey = 'normal',
  }) async {
    final simRules = await SimRulesLoader.loadRaw();
    final petBarRaw = await PetBarRulesLoader.loadRaw();
    final knightBarRaw = await KnightBarRulesLoader.loadRaw();
    final petBar = PetBarRulesLoader.resolveScoped(
      raw: petBarRaw,
      bossTypeKey: bossTypeKey,
      fightModeKey: fightModeKey,
    );
    final knightBar = KnightBarRulesLoader.resolveScoped(
      raw: knightBarRaw,
      bossTypeKey: bossTypeKey,
      fightModeKey: fightModeKey,
    );
    final meta = BossMeta.fromSources(
      simRules: simRules,
      petTicksBar: petBar,
      knightSpecialBar: knightBar,
      overrides: const <String, Object?>{},
    );
    return meta.defaultDurableRockShield;
  }

  static Future<double> loadDefaultElementalWeakness({
    String bossTypeKey = 'raid',
    String fightModeKey = 'normal',
  }) async {
    final simRules = await SimRulesLoader.loadRaw();
    final petBarRaw = await PetBarRulesLoader.loadRaw();
    final knightBarRaw = await KnightBarRulesLoader.loadRaw();
    final petBar = PetBarRulesLoader.resolveScoped(
      raw: petBarRaw,
      bossTypeKey: bossTypeKey,
      fightModeKey: fightModeKey,
    );
    final knightBar = KnightBarRulesLoader.resolveScoped(
      raw: knightBarRaw,
      bossTypeKey: bossTypeKey,
      fightModeKey: fightModeKey,
    );
    final meta = BossMeta.fromSources(
      simRules: simRules,
      petTicksBar: petBar,
      knightSpecialBar: knightBar,
      overrides: const <String, Object?>{},
    );
    return meta.defaultElementalWeakness;
  }

  static Future<({double left, double right, double top, double bottom})>
      loadDefaultKnightImportCrop() async {
    return OcrDefaultsLoader.load();
  }

  static Future<Map<int, EpicBossRow>> loadEpicTable() async {
    return BossTablesLoader.loadEpicTable();
  }

  static Future<List<ElixirConfig>> loadElixirs({String? gamemode}) async {
    return ElixirsLoader.load(gamemode: gamemode);
  }

  static Future<List<BossLevelRow>> loadBossTable({
    required bool raidMode,
  }) async {
    return BossTablesLoader.loadBossTable(raidMode: raidMode);
  }

  static Future<WarPointsConfig> loadWarPoints() async {
    return WarPointsLoader.load();
  }
}
