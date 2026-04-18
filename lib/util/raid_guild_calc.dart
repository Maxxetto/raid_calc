import 'dart:math' as math;

import '../data/config_models.dart';

enum RaidGuildBossMode {
  raid,
  blitz,
}

enum RaidGuildPlannerMode {
  simple,
  fastest,
}

class RaidGuildBossSpec {
  final RaidGuildBossMode mode;
  final int level;
  final int hp;
  final int killBonus;

  const RaidGuildBossSpec({
    required this.mode,
    required this.level,
    required this.hp,
    required this.killBonus,
  });
}

class RaidGuildEnergyPlan {
  final int totalAttacks;
  final int totalEnergy;
  final int freeEnergyPerPlayer;
  final int totalFreeEnergy;
  final int totalPaidEnergy;
  final int packs40;
  final int gems;
  final int leftoverEnergy;
  final int minAttacksPerPlayer;
  final int maxAttacksPerPlayer;

  const RaidGuildEnergyPlan({
    required this.totalAttacks,
    required this.totalEnergy,
    required this.freeEnergyPerPlayer,
    required this.totalFreeEnergy,
    required this.totalPaidEnergy,
    required this.packs40,
    required this.gems,
    required this.leftoverEnergy,
    required this.minAttacksPerPlayer,
    required this.maxAttacksPerPlayer,
  });
}

class RaidGuildSimplePlan {
  final RaidGuildBossSpec boss;
  final int targetPoints;
  final int effectiveAttackScore;
  final int attacksUsed;
  final int bossesKilled;
  final int totalPlayerPoints;
  final int totalKillBonusPoints;
  final int totalGuildPoints;
  final RaidGuildEnergyPlan energy;

  const RaidGuildSimplePlan({
    required this.boss,
    required this.targetPoints,
    required this.effectiveAttackScore,
    required this.attacksUsed,
    required this.bossesKilled,
    required this.totalPlayerPoints,
    required this.totalKillBonusPoints,
    required this.totalGuildPoints,
    required this.energy,
  });

  int get attacksPerBoss => effectiveAttackScore <= 0
      ? 0
      : ((boss.hp + effectiveAttackScore - 1) ~/ effectiveAttackScore);
}

class RaidGuildFastestPlan {
  final RaidGuildBossMode mode;
  final int boardSize;
  final int targetPoints;
  final int rounds;
  final int totalAttacks;
  final int totalPlayerPoints;
  final int totalKillBonusPoints;
  final int totalGuildPoints;
  final RaidGuildEnergyPlan energy;
  final List<RaidGuildBossSpec> recommendedBoard;
  final Map<int, int> bossesKilledByLevel;
  final List<RaidGuildBoardAssignment> firstRoundAssignments;
  final List<String> firstRoundUnassignedPlayers;

  const RaidGuildFastestPlan({
    required this.mode,
    required this.boardSize,
    required this.targetPoints,
    required this.rounds,
    required this.totalAttacks,
    required this.totalPlayerPoints,
    required this.totalKillBonusPoints,
    required this.totalGuildPoints,
    required this.energy,
    required this.recommendedBoard,
    required this.bossesKilledByLevel,
    this.firstRoundAssignments = const <RaidGuildBoardAssignment>[],
    this.firstRoundUnassignedPlayers = const <String>[],
  });
}

class RaidGuildRosterEntry {
  final String name;
  final int rawAttackScore;
  final Set<int> preferredLevels;

  const RaidGuildRosterEntry({
    required this.name,
    required this.rawAttackScore,
    this.preferredLevels = const <int>{},
  });

  bool supportsLevel(int level) =>
      preferredLevels.isEmpty || preferredLevels.contains(level);
}

class RaidGuildBoardAssignment {
  final int slotIndex;
  final int level;
  final List<String> playerNames;
  final int totalScore;

  const RaidGuildBoardAssignment({
    required this.slotIndex,
    required this.level,
    required this.playerNames,
    required this.totalScore,
  });
}

int provisionalRaidKillBonus({
  required RaidGuildBossMode mode,
  required int level,
}) {
  if (level <= 0) return 0;
  return mode == RaidGuildBossMode.blitz ? level * 100 : level * 10;
}

int effectiveRaidAttackScore({
  required int rawAttackScore,
  required int elixirPercent,
}) {
  final bonus = elixirPercent.clamp(0, 1000) / 100.0;
  return (rawAttackScore * (1.0 + bonus)).round();
}

RaidGuildSimplePlan computeRaidGuildSimplePlan({
  required RaidGuildBossSpec boss,
  required int targetPoints,
  required int rawAverageAttackScore,
  required int elixirPercent,
  required int activePlayers,
  required int freeEnergyPerPlayer,
}) {
  final effectiveAttack = effectiveRaidAttackScore(
    rawAttackScore: rawAverageAttackScore,
    elixirPercent: elixirPercent,
  );
  if (targetPoints <= 0 || effectiveAttack <= 0 || activePlayers <= 0) {
    return RaidGuildSimplePlan(
      boss: boss,
      targetPoints: targetPoints,
      effectiveAttackScore: effectiveAttack,
      attacksUsed: 0,
      bossesKilled: 0,
      totalPlayerPoints: 0,
      totalKillBonusPoints: 0,
      totalGuildPoints: 0,
      energy: computeRaidGuildEnergyPlan(
        totalAttacks: 0,
        activePlayers: math.max(activePlayers, 1),
        freeEnergyPerPlayer: freeEnergyPerPlayer,
      ),
    );
  }

  var remainingTarget = targetPoints;
  var remainingBossHp = boss.hp;
  var attacks = 0;
  var kills = 0;
  var playerPoints = 0;
  var killBonusPoints = 0;

  while (remainingTarget > 0) {
    attacks++;
    playerPoints += effectiveAttack;
    remainingTarget -= effectiveAttack;
    remainingBossHp -= effectiveAttack;
    if (remainingBossHp <= 0) {
      kills++;
      killBonusPoints += boss.killBonus;
      remainingTarget -= boss.killBonus;
      remainingBossHp = boss.hp;
    }
  }

  final totalGuildPoints = playerPoints + killBonusPoints;
  return RaidGuildSimplePlan(
    boss: boss,
    targetPoints: targetPoints,
    effectiveAttackScore: effectiveAttack,
    attacksUsed: attacks,
    bossesKilled: kills,
    totalPlayerPoints: playerPoints,
    totalKillBonusPoints: killBonusPoints,
    totalGuildPoints: totalGuildPoints,
    energy: computeRaidGuildEnergyPlan(
      totalAttacks: attacks,
      activePlayers: activePlayers,
      freeEnergyPerPlayer: freeEnergyPerPlayer,
    ),
  );
}

RaidGuildFastestPlan computeRaidGuildFastestPlan({
  required RaidGuildBossMode mode,
  required int targetPoints,
  required int boardSize,
  required List<int> rawPlayerAttackScores,
  required int elixirPercent,
  required int freeEnergyPerPlayer,
  required Map<int, BossLevelRow> bossRowsByLevel,
  List<RaidGuildRosterEntry> rosterEntries = const <RaidGuildRosterEntry>[],
  List<int> forcedLevels = const <int>[],
  List<int> allowedLevels = const <int>[],
}) {
  final cleanedRoster = <_EffectiveRosterEntry>[
    for (var i = 0; i < rosterEntries.length; i++)
      if (rosterEntries[i].rawAttackScore > 0)
        _EffectiveRosterEntry(
          id: i,
          name: rosterEntries[i].name.trim().isEmpty
              ? 'Player ${i + 1}'
              : rosterEntries[i].name.trim(),
          effectiveScore: effectiveRaidAttackScore(
            rawAttackScore: rosterEntries[i].rawAttackScore,
            elixirPercent: elixirPercent,
          ),
          preferredLevels: rosterEntries[i].preferredLevels,
        ),
  ];
  if (cleanedRoster.isEmpty) {
    for (var i = 0; i < rawPlayerAttackScores.length; i++) {
      final rawScore = rawPlayerAttackScores[i];
      if (rawScore <= 0) continue;
      cleanedRoster.add(
        _EffectiveRosterEntry(
          id: i,
          name: 'Player ${i + 1}',
          effectiveScore: effectiveRaidAttackScore(
            rawAttackScore: rawScore,
            elixirPercent: elixirPercent,
          ),
        ),
      );
    }
  }
  cleanedRoster
    ..removeWhere((entry) => entry.effectiveScore <= 0)
    ..sort((a, b) => b.effectiveScore.compareTo(a.effectiveScore));

  final effectiveBoardSize = boardSize.clamp(1, 5);
  final normalizedForcedLevels = forcedLevels
      .where((level) => bossRowsByLevel.containsKey(level))
      .toList(growable: false)
    ..sort();
  final normalizedAllowedLevels = allowedLevels
      .where((level) => bossRowsByLevel.containsKey(level))
      .toSet()
      .toList(growable: false)
    ..sort();
  if (targetPoints <= 0 || cleanedRoster.isEmpty || bossRowsByLevel.isEmpty) {
    return RaidGuildFastestPlan(
      mode: mode,
      boardSize: effectiveBoardSize,
      targetPoints: targetPoints,
      rounds: 0,
      totalAttacks: 0,
      totalPlayerPoints: 0,
      totalKillBonusPoints: 0,
      totalGuildPoints: 0,
      energy: computeRaidGuildEnergyPlan(
        totalAttacks: 0,
        activePlayers: math.max(cleanedRoster.length, 1),
        freeEnergyPerPlayer: freeEnergyPerPlayer,
      ),
      recommendedBoard: const <RaidGuildBossSpec>[],
      bossesKilledByLevel: const <int, int>{},
    );
  }

  final levelChoices = (normalizedAllowedLevels.isNotEmpty
          ? normalizedAllowedLevels
          : bossRowsByLevel.keys.toList())
      .toList()
    ..sort();
  final compositions = <List<int>>[];
  _buildLevelCompositions(
    output: compositions,
    current: <int>[],
    levels: levelChoices,
    startIndex: 0,
    slots: effectiveBoardSize,
  );

  _FastestSearchResult? best;
  for (final composition in compositions) {
    if (!_compositionIncludesForcedLevels(
      composition: composition,
      forcedLevels: normalizedForcedLevels,
    )) {
      continue;
    }
    final simulated = _simulateFixedBoardStrategy(
      mode: mode,
      targetPoints: targetPoints,
      levels: composition,
      players: cleanedRoster,
      freeEnergyPerPlayer: freeEnergyPerPlayer,
      bossRowsByLevel: bossRowsByLevel,
    );
    if (best == null || simulated.isBetterThan(best)) {
      best = simulated;
    }
  }

  if (best == null) {
    return RaidGuildFastestPlan(
      mode: mode,
      boardSize: effectiveBoardSize,
      targetPoints: targetPoints,
      rounds: 0,
      totalAttacks: 0,
      totalPlayerPoints: 0,
      totalKillBonusPoints: 0,
      totalGuildPoints: 0,
      energy: computeRaidGuildEnergyPlan(
        totalAttacks: 0,
        activePlayers: cleanedRoster.length,
        freeEnergyPerPlayer: freeEnergyPerPlayer,
      ),
      recommendedBoard: const <RaidGuildBossSpec>[],
      bossesKilledByLevel: const <int, int>{},
    );
  }

  final result = best;
  return RaidGuildFastestPlan(
    mode: mode,
    boardSize: effectiveBoardSize,
    targetPoints: targetPoints,
    rounds: result.rounds,
    totalAttacks: result.totalAttacks,
    totalPlayerPoints: result.totalPlayerPoints,
    totalKillBonusPoints: result.totalKillBonusPoints,
    totalGuildPoints: result.totalGuildPoints,
    energy: computeRaidGuildEnergyPlan(
      totalAttacks: result.totalAttacks,
      activePlayers: cleanedRoster.length,
      freeEnergyPerPlayer: freeEnergyPerPlayer,
      synchronizedRounds: result.rounds,
    ),
    recommendedBoard: result.board
        .map(
          (boss) => RaidGuildBossSpec(
            mode: mode,
            level: boss.level,
            hp: boss.maxHp,
            killBonus: boss.killBonus,
          ),
        )
        .toList(growable: false),
    bossesKilledByLevel: result.killsByLevel,
    firstRoundAssignments: result.firstRoundAssignments,
    firstRoundUnassignedPlayers: result.firstRoundUnassignedPlayers,
  );
}

RaidGuildEnergyPlan computeRaidGuildEnergyPlan({
  required int totalAttacks,
  required int activePlayers,
  required int freeEnergyPerPlayer,
  int? synchronizedRounds,
}) {
  final players = math.max(1, activePlayers);
  final freePerPlayer = math.max(0, freeEnergyPerPlayer);

  int minAttacksPerPlayer;
  int maxAttacksPerPlayer;
  if (synchronizedRounds != null) {
    minAttacksPerPlayer = synchronizedRounds;
    maxAttacksPerPlayer = synchronizedRounds;
  } else {
    minAttacksPerPlayer = totalAttacks ~/ players;
    maxAttacksPerPlayer =
        minAttacksPerPlayer + (totalAttacks % players == 0 ? 0 : 1);
  }

  var totalPaidEnergy = 0;
  var packs40 = 0;
  var leftoverEnergy = 0;
  if (synchronizedRounds != null) {
    final paidPerPlayer = math.max(0, synchronizedRounds - freePerPlayer);
    final packsPerPlayer =
        paidPerPlayer <= 0 ? 0 : ((paidPerPlayer + 39) ~/ 40);
    totalPaidEnergy = paidPerPlayer * players;
    packs40 = packsPerPlayer * players;
    leftoverEnergy =
        math.max(0, (packsPerPlayer * 40 - paidPerPlayer) * players);
  } else {
    final baseAttacks = totalAttacks ~/ players;
    final extraPlayers = totalAttacks % players;
    for (var i = 0; i < players; i++) {
      final attacksForPlayer = baseAttacks + (i < extraPlayers ? 1 : 0);
      final paid = math.max(0, attacksForPlayer - freePerPlayer);
      final packs = paid <= 0 ? 0 : ((paid + 39) ~/ 40);
      totalPaidEnergy += paid;
      packs40 += packs;
      leftoverEnergy += math.max(0, packs * 40 - paid);
    }
  }

  return RaidGuildEnergyPlan(
    totalAttacks: totalAttacks,
    totalEnergy: totalAttacks,
    freeEnergyPerPlayer: freePerPlayer,
    totalFreeEnergy: freePerPlayer * players,
    totalPaidEnergy: totalPaidEnergy,
    packs40: packs40,
    gems: packs40 * 90,
    leftoverEnergy: leftoverEnergy,
    minAttacksPerPlayer: minAttacksPerPlayer,
    maxAttacksPerPlayer: maxAttacksPerPlayer,
  );
}

class _FastestBoardBoss {
  final int slotIndex;
  final int level;
  final int maxHp;
  final int killBonus;
  int remainingHp;

  _FastestBoardBoss({
    required this.slotIndex,
    required this.level,
    required this.maxHp,
    required this.killBonus,
  }) : remainingHp = maxHp;

  void reset() {
    remainingHp = maxHp;
  }
}

class _FastestSearchResult {
  final int rounds;
  final int totalAttacks;
  final int totalPlayerPoints;
  final int totalKillBonusPoints;
  final int totalGuildPoints;
  final List<_FastestBoardBoss> board;
  final Map<int, int> killsByLevel;
  final List<RaidGuildBoardAssignment> firstRoundAssignments;
  final List<String> firstRoundUnassignedPlayers;

  const _FastestSearchResult({
    required this.rounds,
    required this.totalAttacks,
    required this.totalPlayerPoints,
    required this.totalKillBonusPoints,
    required this.totalGuildPoints,
    required this.board,
    required this.killsByLevel,
    required this.firstRoundAssignments,
    required this.firstRoundUnassignedPlayers,
  });

  bool isBetterThan(_FastestSearchResult other) {
    if (rounds != other.rounds) return rounds < other.rounds;
    if (totalAttacks != other.totalAttacks) {
      return totalAttacks < other.totalAttacks;
    }
    if (totalKillBonusPoints != other.totalKillBonusPoints) {
      return totalKillBonusPoints > other.totalKillBonusPoints;
    }
    return totalGuildPoints > other.totalGuildPoints;
  }
}

_FastestSearchResult _simulateFixedBoardStrategy({
  required RaidGuildBossMode mode,
  required int targetPoints,
  required List<int> levels,
  required List<_EffectiveRosterEntry> players,
  required int freeEnergyPerPlayer,
  required Map<int, BossLevelRow> bossRowsByLevel,
}) {
  final board = levels
      .indexed
      .map(
        (entry) => _FastestBoardBoss(
          slotIndex: entry.$1,
          level: entry.$2,
          maxHp: bossRowsByLevel[entry.$2]!.hp,
          killBonus: bossRowsByLevel[entry.$2]!.killPoints > 0
              ? bossRowsByLevel[entry.$2]!.killPoints
              : provisionalRaidKillBonus(mode: mode, level: entry.$2),
        ),
      )
      .toList(growable: false);

  final totalPerRound =
      players.fold<int>(0, (sum, value) => sum + value.effectiveScore);
  final roundsLimit = totalPerRound <= 0
      ? 0
      : ((targetPoints / totalPerRound).ceil() + 50).clamp(1, 100000);

  var totalGuildPoints = 0;
  var totalPlayerPoints = 0;
  var totalKillBonusPoints = 0;
  var rounds = 0;
  final killsByLevel = <int, int>{};
  var firstRoundAssignments = <RaidGuildBoardAssignment>[];
  var firstRoundUnassignedPlayers = <String>[];

  while (totalGuildPoints < targetPoints && rounds < roundsLimit) {
    rounds++;
    totalPlayerPoints += totalPerRound;
    totalGuildPoints += totalPerRound;

    final available = players
        .map(
          (entry) => _RoundRosterEntry(
            id: entry.id,
            name: entry.name,
            effectiveScore: entry.effectiveScore,
            preferredLevels: entry.preferredLevels,
          ),
        )
        .toList(growable: true);
    final roundAssignments = <int, _RoundAssignmentAccumulator>{};
    final roundUnassignedPlayers = <String>[];
    final order = List<int>.generate(board.length, (i) => i)
      ..sort((a, b) {
        final bossA = board[a];
        final bossB = board[b];
        final hpCmp = bossA.remainingHp.compareTo(bossB.remainingHp);
        if (hpCmp != 0) return hpCmp;
        return bossB.killBonus.compareTo(bossA.killBonus);
      });

    final killedIndexes = <int>{};
    for (final idx in order) {
      final boss = board[idx];
      final chosen = _pickPlayersToReachHp(
        availablePlayers: available,
        requiredHp: boss.remainingHp,
        level: boss.level,
      );
      if (chosen == null) continue;
      for (final player in chosen) {
        available.removeWhere((candidate) => candidate.id == player.id);
      }
      killedIndexes.add(idx);
      totalKillBonusPoints += boss.killBonus;
      totalGuildPoints += boss.killBonus;
      killsByLevel[boss.level] = (killsByLevel[boss.level] ?? 0) + 1;
      final acc = roundAssignments.putIfAbsent(
        boss.slotIndex,
        () => _RoundAssignmentAccumulator(level: boss.level),
      );
      for (final player in chosen) {
        acc.playerNames.add(player.name);
        acc.totalScore += player.effectiveScore;
      }
    }

    final survivors = <_FastestBoardBoss>[
      for (var i = 0; i < board.length; i++)
        if (!killedIndexes.contains(i)) board[i],
    ];
    if (survivors.isNotEmpty && available.isNotEmpty) {
      for (final player in available.toList()..sort((a, b) => b.effectiveScore.compareTo(a.effectiveScore))) {
        final eligibleSurvivors = survivors
            .where((boss) => player.supportsLevel(boss.level))
            .toList(growable: false);
        if (eligibleSurvivors.isEmpty) {
          roundUnassignedPlayers.add(player.name);
          continue;
        }
        eligibleSurvivors.sort((a, b) {
          final hpCmp = a.remainingHp.compareTo(b.remainingHp);
          if (hpCmp != 0) return hpCmp;
          return b.killBonus.compareTo(a.killBonus);
        });
        final focus = eligibleSurvivors.first;
        focus.remainingHp = math.max(1, focus.remainingHp - player.effectiveScore);
        final acc = roundAssignments.putIfAbsent(
          focus.slotIndex,
          () => _RoundAssignmentAccumulator(level: focus.level),
        );
        acc.playerNames.add(player.name);
        acc.totalScore += player.effectiveScore;
      }
    }

    for (final idx in killedIndexes) {
      board[idx].reset();
    }

    if (rounds == 1) {
      final sortedSlots = roundAssignments.keys.toList()..sort();
      firstRoundAssignments = [
        for (final slotIndex in sortedSlots)
          RaidGuildBoardAssignment(
            slotIndex: slotIndex + 1,
            level: roundAssignments[slotIndex]!.level,
            playerNames: List<String>.from(roundAssignments[slotIndex]!.playerNames),
            totalScore: roundAssignments[slotIndex]!.totalScore,
          ),
      ];
      firstRoundUnassignedPlayers = List<String>.from(roundUnassignedPlayers);
    }
  }

  return _FastestSearchResult(
    rounds: rounds,
    totalAttacks: rounds * players.length,
    totalPlayerPoints: totalPlayerPoints,
    totalKillBonusPoints: totalKillBonusPoints,
    totalGuildPoints: totalGuildPoints,
    board: board
        .map(
          (boss) => _FastestBoardBoss(
            slotIndex: boss.slotIndex,
            level: boss.level,
            maxHp: boss.maxHp,
            killBonus: boss.killBonus,
          ),
        )
        .toList(growable: false),
    killsByLevel: killsByLevel,
    firstRoundAssignments: firstRoundAssignments,
    firstRoundUnassignedPlayers: firstRoundUnassignedPlayers,
  );
}

List<_RoundRosterEntry>? _pickPlayersToReachHp({
  required List<_RoundRosterEntry> availablePlayers,
  required int requiredHp,
  required int level,
}) {
  if (requiredHp <= 0) return const <_RoundRosterEntry>[];
  final eligiblePlayers = availablePlayers
      .where((player) => player.supportsLevel(level))
      .toList(growable: true)
    ..sort((a, b) => a.effectiveScore.compareTo(b.effectiveScore));
  if (eligiblePlayers.isEmpty) return null;

  var remaining = requiredHp;
  final selected = <_RoundRosterEntry>[];
  final working = eligiblePlayers.toList(growable: true);

  while (remaining > 0 && working.isNotEmpty) {
    final below = _findLargestPlayerIndexAtMost(working, remaining);
    if (below >= 0) {
      final pick = working.removeAt(below);
      selected.add(pick);
      remaining -= pick.effectiveScore;
      continue;
    }
    final pick = working.removeAt(0);
    selected.add(pick);
    remaining -= pick.effectiveScore;
  }

  if (remaining > 0) return null;
  return selected;
}

int _findLargestPlayerIndexAtMost(List<_RoundRosterEntry> ascending, int value) {
  var lo = 0;
  var hi = ascending.length - 1;
  var ans = -1;
  while (lo <= hi) {
    final mid = lo + ((hi - lo) >> 1);
    if (ascending[mid].effectiveScore <= value) {
      ans = mid;
      lo = mid + 1;
    } else {
      hi = mid - 1;
    }
  }
  return ans;
}

class _EffectiveRosterEntry {
  final int id;
  final String name;
  final int effectiveScore;
  final Set<int> preferredLevels;

  const _EffectiveRosterEntry({
    required this.id,
    required this.name,
    required this.effectiveScore,
    this.preferredLevels = const <int>{},
  });
}

class _RoundRosterEntry {
  final int id;
  final String name;
  final int effectiveScore;
  final Set<int> preferredLevels;

  const _RoundRosterEntry({
    required this.id,
    required this.name,
    required this.effectiveScore,
    this.preferredLevels = const <int>{},
  });

  bool supportsLevel(int level) =>
      preferredLevels.isEmpty || preferredLevels.contains(level);
}

class _RoundAssignmentAccumulator {
  final int level;
  final List<String> playerNames = <String>[];
  int totalScore = 0;

  _RoundAssignmentAccumulator({required this.level});
}

void _buildLevelCompositions({
  required List<List<int>> output,
  required List<int> current,
  required List<int> levels,
  required int startIndex,
  required int slots,
}) {
  if (current.length == slots) {
    output.add(List<int>.from(current));
    return;
  }
  for (var i = startIndex; i < levels.length; i++) {
    current.add(levels[i]);
    _buildLevelCompositions(
      output: output,
      current: current,
      levels: levels,
      startIndex: i,
      slots: slots,
    );
    current.removeLast();
  }
}

bool _compositionIncludesForcedLevels({
  required List<int> composition,
  required List<int> forcedLevels,
}) {
  if (forcedLevels.isEmpty) return true;
  final counts = <int, int>{};
  for (final level in composition) {
    counts[level] = (counts[level] ?? 0) + 1;
  }
  for (final level in forcedLevels) {
    final current = counts[level] ?? 0;
    if (current <= 0) return false;
    counts[level] = current - 1;
  }
  return true;
}
