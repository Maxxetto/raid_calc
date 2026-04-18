import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/boss_tables_loader.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/util/raid_guild_calc.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('effective raid attack score applies elixir percent', () {
    expect(
      effectiveRaidAttackScore(rawAttackScore: 480000, elixirPercent: 10),
      528000,
    );
  });

  test('provisional kill bonus uses temporary raid and blitz rules', () {
    expect(
      provisionalRaidKillBonus(mode: RaidGuildBossMode.raid, level: 7),
      70,
    );
    expect(
      provisionalRaidKillBonus(mode: RaidGuildBossMode.blitz, level: 6),
      600,
    );
  });

  test('simple planner counts overkill and kill bonus', () {
    final plan = computeRaidGuildSimplePlan(
      boss: const RaidGuildBossSpec(
        mode: RaidGuildBossMode.raid,
        level: 7,
        hp: 25,
        killBonus: 70,
      ),
      targetPoints: 100,
      rawAverageAttackScore: 10,
      elixirPercent: 0,
      activePlayers: 5,
      freeEnergyPerPlayer: 30,
    );

    expect(plan.effectiveAttackScore, 10);
    expect(plan.attacksUsed, 3);
    expect(plan.bossesKilled, 1);
    expect(plan.totalPlayerPoints, 30);
    expect(plan.totalKillBonusPoints, 70);
    expect(plan.totalGuildPoints, 100);
  });

  test('fastest planner proposes a board and reaches target points', () {
    final plan = computeRaidGuildFastestPlan(
      mode: RaidGuildBossMode.raid,
      targetPoints: 150,
      boardSize: 1,
      rawPlayerAttackScores: const [80, 80],
      elixirPercent: 0,
      freeEnergyPerPlayer: 30,
      bossRowsByLevel: const <int, BossLevelRow>{
        1: BossLevelRow(level: 1, attack: 0, defense: 0, hp: 100),
        2: BossLevelRow(level: 2, attack: 0, defense: 0, hp: 150),
      },
    );

    expect(plan.rounds, 1);
    expect(plan.totalAttacks, 2);
    expect(plan.totalGuildPoints, greaterThanOrEqualTo(150));
    expect(plan.recommendedBoard, hasLength(1));
    expect(plan.recommendedBoard.first.level, 2);
    expect(plan.energy.minAttacksPerPlayer, 1);
    expect(plan.energy.maxAttacksPerPlayer, 1);
  });

  test('fastest planner respects forced levels in the recommended board', () {
    final plan = computeRaidGuildFastestPlan(
      mode: RaidGuildBossMode.raid,
      targetPoints: 260,
      boardSize: 2,
      rawPlayerAttackScores: const [80, 80],
      elixirPercent: 0,
      freeEnergyPerPlayer: 30,
      forcedLevels: const [1],
      bossRowsByLevel: const <int, BossLevelRow>{
        1: BossLevelRow(level: 1, attack: 0, defense: 0, hp: 100),
        2: BossLevelRow(level: 2, attack: 0, defense: 0, hp: 150),
      },
    );

    final levels = plan.recommendedBoard.map((boss) => boss.level).toList();
    expect(levels, contains(1));
  });

  test('BossLevelRow reads killPoints from boss tables rows', () async {
    BossTablesLoader.clearCache();
    final rows = await BossTablesLoader.loadBossTable(raidMode: true);
    final row = rows.firstWhere((entry) => entry.level == 6);

    expect(row.killPoints, 60);
  });

  test('fastest planner prefers killPoints from asset rows over provisional fallback', () {
    final plan = computeRaidGuildFastestPlan(
      mode: RaidGuildBossMode.raid,
      targetPoints: 260,
      boardSize: 1,
      rawPlayerAttackScores: const [100, 100],
      elixirPercent: 0,
      freeEnergyPerPlayer: 30,
      bossRowsByLevel: const <int, BossLevelRow>{
        1: BossLevelRow(
          level: 1,
          attack: 0,
          defense: 0,
          hp: 100,
          killPoints: 500,
        ),
      },
    );

    expect(plan.recommendedBoard, hasLength(1));
    expect(plan.recommendedBoard.first.killBonus, 500);
    expect(plan.totalGuildPoints, 700);
    expect(plan.totalKillBonusPoints, 500);
  });

  test('fastest planner can keep roster entries on preferred boss levels', () {
    final plan = computeRaidGuildFastestPlan(
      mode: RaidGuildBossMode.raid,
      targetPoints: 500,
      boardSize: 2,
      rawPlayerAttackScores: const [],
      rosterEntries: const <RaidGuildRosterEntry>[
        RaidGuildRosterEntry(
          name: 'Alice',
          rawAttackScore: 150,
          preferredLevels: <int>{6},
        ),
        RaidGuildRosterEntry(
          name: 'Bob',
          rawAttackScore: 150,
          preferredLevels: <int>{6},
        ),
        RaidGuildRosterEntry(
          name: 'Cora',
          rawAttackScore: 210,
          preferredLevels: <int>{7},
        ),
      ],
      allowedLevels: const <int>[6, 7],
      elixirPercent: 0,
      freeEnergyPerPlayer: 30,
      bossRowsByLevel: const <int, BossLevelRow>{
        6: BossLevelRow(level: 6, attack: 0, defense: 0, hp: 300, killPoints: 60),
        7: BossLevelRow(level: 7, attack: 0, defense: 0, hp: 210, killPoints: 70),
      },
    );

    expect(plan.recommendedBoard.map((boss) => boss.level), everyElement(anyOf(6, 7)));
    expect(plan.firstRoundAssignments, isNotEmpty);
    final level6Assignment = plan.firstRoundAssignments.firstWhere(
      (assignment) => assignment.level == 6,
      orElse: () => const RaidGuildBoardAssignment(
        slotIndex: 0,
        level: 0,
        playerNames: <String>[],
        totalScore: 0,
      ),
    );
    final level7Assignment = plan.firstRoundAssignments.firstWhere(
      (assignment) => assignment.level == 7,
      orElse: () => const RaidGuildBoardAssignment(
        slotIndex: 0,
        level: 0,
        playerNames: <String>[],
        totalScore: 0,
      ),
    );
    expect(level6Assignment.playerNames, containsAll(<String>['Alice', 'Bob']));
    expect(level7Assignment.playerNames, contains('Cora'));
  });
}
