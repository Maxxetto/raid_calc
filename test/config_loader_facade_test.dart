import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/boss_tables_loader.dart';
import 'package:raid_calc/data/config_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ConfigLoader loadBoss composes meta and stats from split sources',
      () async {
    BossTablesLoader.clearCache();
    final boss = await ConfigLoader.loadBoss(
      raidMode: false,
      bossLevel: 4,
      adv: const [1.0, 1.5, 2.0],
      fightModeKey: 'normal',
    );
    final blitzRows = await BossTablesLoader.loadBossTable(raidMode: false);
    final expectedRow = blitzRows.firstWhere((row) => row.level == 4);

    expect(boss.meta.raidMode, isFalse);
    expect(boss.meta.level, 4);
    expect(boss.meta.advVsKnights, const [1.0, 1.5, 2.0]);
    expect(boss.meta.petTicksBar.enabled, isTrue);
    expect(boss.stats.attack, expectedRow.attack);
    expect(boss.stats.defense, expectedRow.defense);
    expect(boss.stats.hp, expectedRow.hp);
  });

  test('ConfigLoader loadEpicMeta composes split rules with overrides',
      () async {
    final meta = await ConfigLoader.loadEpicMeta(
      raidMode: true,
      adv: const [2.0, 1.5],
      fightModeKey: 'cycloneBoost',
    );

    expect(meta.raidMode, isTrue);
    expect(meta.level, 1);
    expect(meta.advVsKnights, const [2.0, 1.5, 1.0]);
    expect(meta.criticalChance, 0.05);
    expect(meta.petTicksBar.enabled, isTrue);
  });

  test('ConfigLoader delegates war points to split loader', () async {
    final war = await ConfigLoader.loadWarPoints();

    expect(war.eu.normal.base, 780);
    expect(war.global.strip.frenzyPowerAttack, 2712);
  });

  test('ConfigLoader exposes threshold and default combat values', () async {
    final threshold = await ConfigLoader.loadEpicThreshold();
    final drs = await ConfigLoader.loadDefaultDurableRockShield(
      bossTypeKey: 'raid',
      fightModeKey: 'durableRockShield',
    );
    final ew = await ConfigLoader.loadDefaultElementalWeakness(
      bossTypeKey: 'raid',
      fightModeKey: 'specialRegenPlusEw',
    );
    final bossTable = await ConfigLoader.loadBossTable(raidMode: true);
    final epicTable = await ConfigLoader.loadEpicTable();

    expect(threshold, 80);
    expect(drs, 0.5);
    expect(ew, 0.65);
    expect(bossTable, isNotEmpty);
    expect(bossTable.first.level, 1);
    expect(epicTable[1]!.level, 1);
  });
}
