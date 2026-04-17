import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/boss_tables_loader.dart';
import 'package:raid_calc/data/elixirs_loader.dart';
import 'package:raid_calc/data/knight_bar_rules_loader.dart';
import 'package:raid_calc/data/ocr_defaults_loader.dart';
import 'package:raid_calc/data/pet_bar_rules_loader.dart';
import 'package:raid_calc/data/sim_rules_loader.dart';
import 'package:raid_calc/data/war_points_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('SimRulesLoader loads core simulation values', () async {
    SimRulesLoader.clearCache();
    final rules = await SimRulesLoader.loadRaw();

    expect(rules['raidFreeEnergies'], 30);
    expect(rules['thresholdEpicBoss'], 80);

    final timing = rules['timing'];
    expect(timing, isA<Map>());
    expect((timing as Map)['bossSpecialDuration'], 0.5);
  });

  test('PetBarRulesLoader resolves scoped rules by boss type and fight mode',
      () {
    final resolved = PetBarRulesLoader.resolveScoped(
      raw: <String, Object?>{
        'enabled': true,
        'ticksPerState': 165,
        'startTicks': 165,
        'bossNormal': <String, Object?>{
          '2': 0.7,
        },
        'scopedRules': <String, Object?>{
          'blitz': <String, Object?>{
            'specialRegenPlusEw': <String, Object?>{
              'startTicks': 220,
              'bossNormal': <String, Object?>{
                '4': 1.0,
              },
            },
          },
        },
      },
      bossTypeKey: 'blitz',
      fightModeKey: 'specialRegenPlusEw',
    );

    expect(resolved['enabled'], isTrue);
    expect(resolved['startTicks'], 220);
    expect(resolved['bossNormal'], <String, Object?>{'4': 1.0});
    expect(resolved.containsKey('scopedRules'), isFalse);
  });

  test('PetBarRulesLoader loads active pet bar config', () async {
    PetBarRulesLoader.clearCache();
    final raw = await PetBarRulesLoader.loadRaw();
    final cfg = await PetBarRulesLoader.loadConfig();

    expect(raw.containsKey('bossNormalORGINAL'), isFalse);
    expect(raw.containsKey('scopedRules'), isTrue);
    expect(cfg.enabled, isTrue);
    expect(cfg.ticksPerState, 165);
    expect(cfg.startTicks, 165);
    expect(raw['petCritPlusOneProb'], 0.1);
    expect(raw['bossNormal'], <String, Object?>{'2': 1.0});
    expect(raw['bossSpecial'], <String, Object?>{'4': 1.0});
    expect(raw['stun'], <String, Object?>{'1': 1.0});
    expect(raw['petKnightBase'], <String, Object?>{'12': 1.0});
    expect(cfg.petCritPlusOneProb, 0.1);
    expect(cfg.bossNormal.map((e) => e.ticks).toList(), <int>[2]);
    expect(cfg.bossNormal.map((e) => e.weight).toList(), <double>[1.0]);
    expect(cfg.bossSpecial.single.ticks, 4);
    expect(cfg.stun.single.ticks, 1);
    expect(cfg.petKnightBase.map((e) => e.ticks).toList(), <int>[12]);
    expect(cfg.petKnightBase.map((e) => e.weight).toList(), <double>[1.0]);
    expect(cfg.useInShatterShield, isTrue);
  });

  test('KnightBarRulesLoader loads knight special bar config', () async {
    KnightBarRulesLoader.clearCache();
    final raw = await KnightBarRulesLoader.loadRaw();
    final cfg = await KnightBarRulesLoader.loadConfig();

    expect(raw.containsKey('scopedRules'), isTrue);
    expect(cfg.enabled, isTrue);
    expect(cfg.startFill, 0.0);
    expect(cfg.knightTurnFill, 0.2);
    expect(cfg.bossTurnFill, 0.042);
    expect(cfg.thresholdFill, 1.0);
    expect(cfg.maxFill, 1.0);
  });

  test('BossTablesLoader loads raid, blitz and epic tables', () async {
    BossTablesLoader.clearCache();
    final raid = await BossTablesLoader.loadBossTable(raidMode: true);
    final blitz = await BossTablesLoader.loadBossTable(raidMode: false);
    final epic = await BossTablesLoader.loadEpicTable();

    expect(raid, hasLength(7));
    expect(blitz, hasLength(6));
    expect(epic.length, 83);
    expect(raid.first.level, 1);
    expect(blitz.first.level, 1);
    expect(epic[1]!.level, 1);
  });

  test('ElixirsLoader loads and sorts elixirs', () async {
    ElixirsLoader.clearCache();
    final list = await ElixirsLoader.load();
    final war = await ElixirsLoader.load(gamemode: 'War');

    expect(list, isNotEmpty);
    expect(list.first.name, 'Common');
    expect(list.last.name, 'Wraith');
    expect(war, isNotEmpty);
    expect(war.every((e) => e.gamemode == 'War'), isTrue);
  });

  test('WarPointsLoader loads EU and Global point sets', () async {
    WarPointsLoader.clearCache();
    final cfg = await WarPointsLoader.load();

    expect(cfg.eu.normal.base, 780);
    expect(cfg.eu.strip.powerAttack, 1885);
    expect(cfg.global.normal.frenzyPowerAttack, 2736);
  });

  test('OcrDefaultsLoader loads crop defaults as fractions', () async {
    OcrDefaultsLoader.clearCache();
    final crop = await OcrDefaultsLoader.load();

    expect(crop.left, closeTo(0.20, 1e-9));
    expect(crop.right, closeTo(0.15, 1e-9));
    expect(crop.top, closeTo(0.05, 1e-9));
    expect(crop.bottom, closeTo(0.55, 1e-9));
  });
}
