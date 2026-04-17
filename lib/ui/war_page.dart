import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/war_isolate.dart';
import '../data/config_loader.dart';
import '../data/config_models.dart';
import '../data/raid_guild_planner_storage.dart';
import '../util/format.dart';
import '../util/i18n.dart';
import '../util/raid_guild_calc.dart';
import '../util/war_calc.dart';
import 'theme_helpers.dart';
import 'widgets.dart';

enum _RaidRosterInputMode {
  automatic,
  selectedLevels,
}

class _RaidLevelRosterRow {
  final TextEditingController nameCtl;
  final TextEditingController scoreCtl;

  _RaidLevelRosterRow({
    String name = '',
    String score = '',
  })  : nameCtl = TextEditingController(text: name),
        scoreCtl = TextEditingController(text: score);

  String get name => nameCtl.text.trim();

  int get score {
    final digits = scoreCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0);
  }

  Map<String, Object?> toJson() => {
        'name': nameCtl.text.trim(),
        'score': scoreCtl.text.replaceAll(RegExp(r'[^0-9]'), ''),
      };

  void dispose() {
    nameCtl.dispose();
    scoreCtl.dispose();
  }
}

class WarPage extends StatefulWidget {
  final I18n? i18n;
  final bool isPremium;
  final VoidCallback? onOpenPremium;
  final VoidCallback? onOpenLastResults;
  final VoidCallback? onOpenTheme;
  final VoidCallback? onOpenLanguage;

  const WarPage({
    super.key,
    this.i18n,
    this.isPremium = false,
    this.onOpenPremium,
    this.onOpenLastResults,
    this.onOpenTheme,
    this.onOpenLanguage,
  });

  @override
  State<WarPage> createState() => _WarPageState();
}

class _WarPageState extends State<WarPage> {
  final TextEditingController _milestoneCtl =
      TextEditingController(text: '1,000,000');
  int _milestone = 1000000;
  final TextEditingController _energyCtl = TextEditingController(text: '0');
  int _energyAvailable = 0;
  final TextEditingController _forcedPaCtl = TextEditingController(text: '1');
  int _forcedPowerAttacks = 1;

  bool _serverEu = true;
  bool _frenzy = false;
  bool _powerAttack = false;
  bool _strip = false;
  WarAttackStrategy _attackStrategy = WarAttackStrategy.optimizedMix;

  WarPointsConfig? _points;
  List<ElixirConfig> _warElixirs = const <ElixirConfig>[];
  final List<_WarElixirItem> _warElixirInventory = <_WarElixirItem>[];
  Key _warElixirDropdownKey = UniqueKey();
  String? _warElixirWarning;
  WarPlan _plan = const WarPlan(
    pointsPerAttack: 0,
    pointsPerPowerAttack: 0,
    normalAttacks: 0,
    powerAttacks: 0,
    gems: WarGemPlan(
      energyNeeded: 0,
      energyBought: 0,
      gems: 0,
      packs4: 0,
      packs20: 0,
      packs40: 0,
      leftover: 0,
    ),
  );
  bool _optimizing = false;
  int _progressDone = 0;
  int _progressTotal = 0;
  int _requestToken = 0;
  Timer? _recomputeDebounce;

  final TextEditingController _raidTargetCtl =
      TextEditingController(text: '1,000,000,000');
  int _raidTargetPoints = 1000000000;
  final TextEditingController _raidAverageCtl =
      TextEditingController(text: '2,000,000');
  int _raidAverageAttack = 2000000;
  final TextEditingController _raidElixirCtl = TextEditingController(text: '0');
  int _raidElixirPercent = 0;
  final TextEditingController _raidPlayersCtl =
      TextEditingController(text: '40');
  int _raidPlayers = 40;
  final TextEditingController _raidRosterCtl =
      TextEditingController(text: '1100000');
  _RaidRosterInputMode _raidRosterInputMode = _RaidRosterInputMode.automatic;
  final Set<int> _raidRosterSelectedLevels = <int>{};
  final Map<int, List<_RaidLevelRosterRow>> _raidRosterByLevel =
      <int, List<_RaidLevelRosterRow>>{};
  int _raidBoardSize = 5;
  int _raidSelectedLevel = 6;
  int _raidFreeEnergies = 30;
  RaidGuildBossMode _raidBossMode = RaidGuildBossMode.raid;
  RaidGuildPlannerMode _raidPlannerMode = RaidGuildPlannerMode.simple;
  bool _warViewMode = true;
  final Set<int> _raidForcedLevels = <int>{};
  Map<int, BossLevelRow> _raidBossRows = const <int, BossLevelRow>{};
  Map<int, BossLevelRow> _blitzBossRows = const <int, BossLevelRow>{};
  RaidGuildSimplePlan? _raidSimplePlan;
  RaidGuildFastestPlan? _raidFastestPlan;
  Timer? _raidPlannerPrefsDebounce;

  String t(String key, String fallback) =>
      widget.i18n?.t(key, fallback) ?? fallback;

  Future<void> _showWarCalculatorTip(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('war.tip.title', 'War tip')),
        content: Text(
          '${t('war.tip.calculator', 'Set the target milestone and available energy, then choose server and toggles (Strip, Frenzy, PA) to simulate the correct war points table.')}\n\n'
          '${t('war.tip.optimizer', 'When PA is enabled, you can keep the optimizer or force a non-optimal strategy such as only PAs or a fixed number of PAs.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('cancel', 'Cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _showWarElixirsTip(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('war.elixirs.tip.title', 'War elixirs tip')),
        content: Text(
          '${t('war.elixirs.tip.body', 'Elixirs provide a temporary points boost and are used in the war calculation to optimize attacks and estimate the gems needed to reach the selected milestone. Elixirs are applied in the same order in which you add them.')}\n\n'
          '${widget.isPremium ? t('war.elixirs.tip.limit_premium', 'Premium users can select all available war elixirs.') : t('war.elixirs.tip.limit_free', 'Free users can add up to 5 elixirs. Premium users can select all available war elixirs.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('cancel', 'Cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _showWarResultsTip(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t('war.results.tip.title', 'War results tip')),
        content: Text(
          t(
            'war.results.tip.body',
            'Results summarize attacks, power attacks, energy and gems based on the selected server, toggles, strategy and war elixirs.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('cancel', 'Cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _showRaidGuildTip(BuildContext context) {
    return showDialog<void>(
      context: context,
        builder: (context) => AlertDialog(
          title: Text(t('raid_guild.tip.title', 'Raid guild planner tip')),
          content: Text(
            '${t('raid_guild.tip.body', 'Estimate how many bosses your guild needs to kill to reach a target score. Player score always counts in full, overkill counts, and boss kill bonus is added only when the boss dies.')}\n\n'
          '${t('raid_guild.tip.provisional', 'Boss HP and kill bonus are loaded from boss tables when available. Missing kill values currently fall back to placeholders: Raid = 10 x level, Blitz = 100 x level.')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t('cancel', 'Cancel')),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _milestoneCtl.addListener(_onMilestoneChanged);
    _energyCtl.addListener(_onEnergyChanged);
    _forcedPaCtl.addListener(_onForcedPaChanged);
    _raidTargetCtl.addListener(_onRaidTargetChanged);
    _raidAverageCtl.addListener(_onRaidAverageChanged);
    _raidElixirCtl.addListener(_onRaidElixirChanged);
    _raidPlayersCtl.addListener(_onRaidPlayersChanged);
    _raidRosterCtl.addListener(_onRaidRosterChanged);
    _loadPoints();
    _loadElixirs();
    unawaited(_restoreRaidPlannerState());
    _loadRaidPlannerData();
  }

  @override
  void didUpdateWidget(covariant WarPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPremium && !widget.isPremium && !_warViewMode) {
      setState(() => _warViewMode = true);
      _scheduleRaidPlannerSave();
    }
  }

  Future<void> _loadPoints() async {
    final p = await ConfigLoader.loadWarPoints();
    if (!mounted) return;
    setState(() => _points = p);
    _scheduleRecompute(immediate: true);
  }

  Future<void> _loadElixirs() async {
    final list = await ConfigLoader.loadElixirs(gamemode: 'War');
    if (!mounted) return;
    setState(() => _warElixirs = list);
    _scheduleRecompute(immediate: true);
  }

  Future<void> _loadRaidPlannerData() async {
    final raidRows = await ConfigLoader.loadBossTable(raidMode: true);
    final blitzRows = await ConfigLoader.loadBossTable(raidMode: false);
    final free = await ConfigLoader.loadRaidFreeEnergies();
    if (!mounted) return;
    setState(() {
      _raidBossRows = {
        for (final row in raidRows) row.level: row,
      };
      _blitzBossRows = {
        for (final row in blitzRows) row.level: row,
      };
      _raidFreeEnergies = free;
      if (!_availableRaidLevels.contains(_raidSelectedLevel)) {
        _raidSelectedLevel =
            _availableRaidLevels.isEmpty ? 1 : _availableRaidLevels.last;
      }
      _raidForcedLevels
          .removeWhere((level) => !_availableRaidLevels.contains(level));
      _raidRosterSelectedLevels
          .removeWhere((level) => !_availableRaidLevels.contains(level));
      _raidRosterByLevel.removeWhere(
        (level, _) => !_availableRaidLevels.contains(level),
      );
    });
    _recomputeRaidPlans();
  }

  Future<void> _restoreRaidPlannerState() async {
    final raw = await RaidGuildPlannerStorage.load();
    if (!mounted || raw.isEmpty) return;
    final forcedLevelsRaw =
        (raw['forcedLevels'] as List?)?.cast<Object?>() ?? const <Object?>[];
    final restoredForcedLevels = <int>{
      for (final value in forcedLevelsRaw)
        if (value is num) value.toInt(),
    };
    final rosterLevelsRaw =
        (raw['rosterSelectedLevels'] as List?)?.cast<Object?>() ??
            const <Object?>[];
    final restoredRosterLevels = <int>{
      for (final value in rosterLevelsRaw)
        if (value is num) value.toInt(),
    };
    setState(() {
      _warViewMode = widget.isPremium
          ? ((raw['warViewMode'] as bool?) ?? _warViewMode)
          : true;
      _raidPlannerMode = ((raw['plannerMode'] as String?) == 'fastest')
          ? RaidGuildPlannerMode.fastest
          : RaidGuildPlannerMode.simple;
      _raidRosterInputMode =
          ((raw['rosterInputMode'] as String?) == 'selected_levels')
              ? _RaidRosterInputMode.selectedLevels
              : _RaidRosterInputMode.automatic;
      _raidBossMode = ((raw['bossMode'] as String?) == 'blitz')
          ? RaidGuildBossMode.blitz
          : RaidGuildBossMode.raid;
      _raidTargetPoints =
          (raw['targetPoints'] as num?)?.toInt() ?? _raidTargetPoints;
      _raidAverageAttack =
          (raw['averageAttack'] as num?)?.toInt() ?? _raidAverageAttack;
      _raidElixirPercent =
          (raw['elixirPercent'] as num?)?.toInt() ?? _raidElixirPercent;
      _raidPlayers = ((raw['activePlayers'] as num?)?.toInt() ?? _raidPlayers)
          .clamp(1, 40);
      _raidBoardSize =
          ((raw['boardSize'] as num?)?.toInt() ?? _raidBoardSize).clamp(1, 5);
      _raidSelectedLevel =
          (raw['selectedLevel'] as num?)?.toInt() ?? _raidSelectedLevel;
      _raidForcedLevels
        ..clear()
        ..addAll(restoredForcedLevels.toList()..sort());
      _raidRosterSelectedLevels
        ..clear()
        ..addAll(restoredRosterLevels.toList()..sort());
      if (_raidForcedLevels.length > 5) {
        final trimmed = _raidForcedLevels.toList()..sort();
        _raidForcedLevels
          ..clear()
          ..addAll(trimmed.take(5));
      }
      if (_raidRosterSelectedLevels.length > 5) {
        final trimmed = _raidRosterSelectedLevels.toList()..sort();
        _raidRosterSelectedLevels
          ..clear()
          ..addAll(trimmed.take(5));
      }
      final roster = (raw['rosterText'] as String?)?.trim();
      if (roster != null && roster.isNotEmpty) {
        _raidRosterCtl.text = roster;
      }
      _raidTargetCtl.text = fmtInt(_raidTargetPoints);
      _raidAverageCtl.text = fmtInt(_raidAverageAttack);
      _raidElixirCtl.text = fmtInt(_raidElixirPercent);
      _raidPlayersCtl.text = fmtInt(_raidPlayers);
    });
    _restoreRaidLevelRoster(raw['rosterByLevel']);
    _recomputeRaidPlans();
  }

  void _scheduleRaidPlannerSave() {
    _raidPlannerPrefsDebounce?.cancel();
    _raidPlannerPrefsDebounce = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(
        RaidGuildPlannerStorage.save(
          <String, Object?>{
            'warViewMode': _warViewMode,
            'plannerMode': _raidPlannerMode == RaidGuildPlannerMode.fastest
                ? 'fastest'
                : 'simple',
            'rosterInputMode':
                _raidRosterInputMode == _RaidRosterInputMode.selectedLevels
                    ? 'selected_levels'
                    : 'automatic',
            'bossMode':
                _raidBossMode == RaidGuildBossMode.blitz ? 'blitz' : 'raid',
            'targetPoints': _raidTargetPoints,
            'averageAttack': _raidAverageAttack,
            'elixirPercent': _raidElixirPercent,
            'activePlayers': _raidPlayers,
            'rosterText': _raidRosterCtl.text,
            'rosterSelectedLevels': (_raidRosterSelectedLevels.toList()..sort()),
            'rosterByLevel': _serializeRaidLevelRoster(),
            'boardSize': _raidBoardSize,
            'selectedLevel': _raidSelectedLevel,
            'forcedLevels': (_raidForcedLevels.toList()..sort()),
          },
        ),
      ),
    );
  }

  Map<String, Object?> _serializeRaidLevelRoster() {
    final out = <String, Object?>{};
    final levels = _raidRosterByLevel.keys.toList()..sort();
    for (final level in levels) {
      final rows = _raidRosterByLevel[level] ?? const <_RaidLevelRosterRow>[];
      out[level.toString()] = [
        for (final row in rows)
          if (row.name.isNotEmpty || row.score > 0) row.toJson(),
      ];
    }
    return out;
  }

  void _disposeRaidLevelRoster() {
    for (final rows in _raidRosterByLevel.values) {
      for (final row in rows) {
        row.dispose();
      }
    }
    _raidRosterByLevel.clear();
  }

  void _restoreRaidLevelRoster(Object? raw) {
    _disposeRaidLevelRoster();
    if (raw is! Map) return;
    raw.forEach((key, value) {
      final level = int.tryParse(key.toString());
      if (level == null) return;
      final rowsRaw = (value as List?)?.cast<Object?>() ?? const <Object?>[];
      final rows = <_RaidLevelRosterRow>[];
      for (final rowRaw in rowsRaw) {
        if (rowRaw is! Map) continue;
        final rowMap = rowRaw.cast<Object?, Object?>();
        final row = _RaidLevelRosterRow(
          name: rowMap['name']?.toString() ?? '',
          score: rowMap['score']?.toString() ?? '',
        );
        row.nameCtl.addListener(_onRaidRosterChanged);
        row.scoreCtl.addListener(_onRaidRosterChanged);
        rows.add(row);
      }
      if (rows.isNotEmpty) {
        _raidRosterByLevel[level] = rows;
      }
    });
  }

  void _addRaidLevelRosterRow(int level, {_RaidLevelRosterRow? row}) {
    final next = row ?? _RaidLevelRosterRow();
    next.nameCtl.addListener(_onRaidRosterChanged);
    next.scoreCtl.addListener(_onRaidRosterChanged);
    final rows = _raidRosterByLevel.putIfAbsent(level, () => <_RaidLevelRosterRow>[]);
    rows.add(next);
  }

  void _removeRaidLevelRosterRow(int level, _RaidLevelRosterRow row) {
    final rows = _raidRosterByLevel[level];
    if (rows == null) return;
    rows.remove(row);
    row.dispose();
    if (rows.isEmpty) {
      _raidRosterByLevel.remove(level);
    }
  }

  int get _warElixirsLimit {
    if (widget.isPremium) return _warElixirs.length;
    return 5;
  }

  void _addWarElixir(String name) {
    ElixirConfig? config;
    for (final e in _warElixirs) {
      if (e.name == name) {
        config = e;
        break;
      }
    }
    final selectedConfig = config;
    if (selectedConfig == null) return;
    if (_warElixirInventory.any((e) => e.config.name == selectedConfig.name)) {
      return;
    }
    final controller = TextEditingController(text: '1');
    final item = _WarElixirItem(
      config: selectedConfig,
      qty: controller,
      qtyValue: 1,
    );
    controller.addListener(() => _onWarElixirQtyChanged(item));

    setState(() {
      _warElixirInventory.add(item);
      _warElixirDropdownKey = UniqueKey();
    });
    _scheduleRecompute();
  }

  void _removeWarElixirAt(int index) {
    if (index < 0 || index >= _warElixirInventory.length) return;
    final removed = _warElixirInventory.removeAt(index);
    removed.qty.dispose();
    setState(() {
      _warElixirDropdownKey = UniqueKey();
    });
    _scheduleRecompute();
  }

  void _onWarElixirQtyChanged(_WarElixirItem item) {
    var v = int.tryParse(item.qty.text.trim()) ?? item.qtyValue;
    if (v < 1) v = 1;
    if (v > 999) v = 999;
    if (v != item.qtyValue) {
      item.qtyValue = v;
    }
    _scheduleRecompute();
  }

  List<ElixirInventoryItem> _selectedWarElixirs() {
    final out = <ElixirInventoryItem>[];
    for (final e in _warElixirInventory) {
      if (e.qtyValue <= 0) continue;
      out.add(
        ElixirInventoryItem.fromConfig(e.config, e.qtyValue),
      );
    }
    return out;
  }

  void _onMilestoneChanged() {
    final digits = _milestoneCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      setState(() => _milestone = 0);
      _scheduleRecompute();
      return;
    }
    final v = int.tryParse(digits) ?? 0;
    setState(() => _milestone = v);
    _scheduleRecompute();
  }

  void _onEnergyChanged() {
    final digits = _energyCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      setState(() => _energyAvailable = 0);
      _scheduleRecompute();
      return;
    }
    var v = int.tryParse(digits) ?? 0;
    if (v < 0) v = 0;
    if (v > 9999) v = 9999;
    setState(() => _energyAvailable = v);
    _scheduleRecompute();
  }

  void _onForcedPaChanged() {
    final digits = _forcedPaCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      setState(() => _forcedPowerAttacks = 0);
      _scheduleRecompute();
      return;
    }
    var v = int.tryParse(digits) ?? 0;
    if (v < 0) v = 0;
    if (v > 999999) v = 999999;
    setState(() => _forcedPowerAttacks = v);
    _scheduleRecompute();
  }

  void _onRaidTargetChanged() {
    final digits = _raidTargetCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
    _raidTargetPoints = digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0);
    _recomputeRaidPlans();
    _scheduleRaidPlannerSave();
  }

  void _onRaidAverageChanged() {
    final digits = _raidAverageCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
    _raidAverageAttack = digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0);
    _recomputeRaidPlans();
    _scheduleRaidPlannerSave();
  }

  void _onRaidElixirChanged() {
    final digits = _raidElixirCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
    var value = digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0);
    value = value.clamp(0, 1000);
    _raidElixirPercent = value;
    _recomputeRaidPlans();
    _scheduleRaidPlannerSave();
  }

  void _onRaidPlayersChanged() {
    final digits = _raidPlayersCtl.text.replaceAll(RegExp(r'[^0-9]'), '');
    var value = digits.isEmpty ? 0 : (int.tryParse(digits) ?? 0);
    value = value.clamp(1, 40);
    _raidPlayers = value;
    _recomputeRaidPlans();
    _scheduleRaidPlannerSave();
  }

  void _onRaidRosterChanged() {
    _recomputeRaidPlans();
    _scheduleRaidPlannerSave();
  }

  List<int> get _availableRaidLevels {
    final rows = _raidBossMode == RaidGuildBossMode.raid
        ? _raidBossRows
        : _blitzBossRows;
    final levels = rows.keys.toList()..sort();
    return levels;
  }

  Map<int, BossLevelRow> get _activeRaidRows =>
      _raidBossMode == RaidGuildBossMode.raid ? _raidBossRows : _blitzBossRows;

  int _killPointsForRow(BossLevelRow row) {
    if (row.killPoints > 0) return row.killPoints;
    return provisionalRaidKillBonus(
      mode: _raidBossMode,
      level: row.level,
    );
  }

  void _recomputeRaidPlans() {
    final rows = _activeRaidRows;
    final row = rows[_raidSelectedLevel];
    final rosterEntries = _collectRaidRosterEntries();
    if (row == null) {
      if (mounted) {
        setState(() {
          _raidSimplePlan = null;
          _raidFastestPlan = null;
        });
      }
      return;
    }

    final simpleBoss = RaidGuildBossSpec(
      mode: _raidBossMode,
      level: row.level,
      hp: row.hp,
      killBonus: _killPointsForRow(row),
    );
    final roster = _parseRaidRosterScores(_raidRosterCtl.text);
    final simplePlan = computeRaidGuildSimplePlan(
      boss: simpleBoss,
      targetPoints: _raidTargetPoints,
      rawAverageAttackScore: _raidAverageAttack,
      elixirPercent: _raidElixirPercent,
      activePlayers: _raidPlayers,
      freeEnergyPerPlayer: _raidFreeEnergies,
    );
    final fastestPlan = computeRaidGuildFastestPlan(
      mode: _raidBossMode,
      targetPoints: _raidTargetPoints,
      boardSize: _raidBoardSize,
      rawPlayerAttackScores: roster,
      rosterEntries: rosterEntries,
      elixirPercent: _raidElixirPercent,
      freeEnergyPerPlayer: _raidFreeEnergies,
      bossRowsByLevel: rows,
      forcedLevels: _raidRosterInputMode == _RaidRosterInputMode.automatic
          ? _raidForcedLevels.toList()
          : const <int>[],
      allowedLevels: _raidRosterInputMode == _RaidRosterInputMode.selectedLevels
          ? _raidRosterSelectedLevels.toList()
          : const <int>[],
    );

    if (!mounted) return;
    setState(() {
      _raidSimplePlan = simplePlan;
      _raidFastestPlan = fastestPlan;
    });
  }

  List<int> _parseRaidRosterScores(String raw) {
    return _parseAutomaticRaidRosterEntries(raw)
        .map((entry) => entry.rawAttackScore)
        .take(40)
        .toList(growable: false);
  }

  List<RaidGuildRosterEntry> _collectRaidRosterEntries() {
    if (_raidRosterInputMode == _RaidRosterInputMode.selectedLevels) {
      return _buildSelectedLevelRaidRosterEntries();
    }
    return _parseAutomaticRaidRosterEntries(_raidRosterCtl.text);
  }

  List<RaidGuildRosterEntry> _parseAutomaticRaidRosterEntries(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return const <RaidGuildRosterEntry>[];
    final hasLetters = RegExp(r'[A-Za-z]').hasMatch(trimmed);
    if (!hasLetters) {
      final matches = RegExp(r'\d+').allMatches(trimmed);
      var idx = 0;
      return matches
          .map((m) => int.tryParse(m.group(0) ?? '') ?? 0)
          .where((v) => v > 0)
          .take(40)
          .map(
            (score) => RaidGuildRosterEntry(
              name: 'Player ${++idx}',
              rawAttackScore: score,
            ),
          )
          .toList(growable: false);
    }

    final lines = trimmed
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty);
    final out = <RaidGuildRosterEntry>[];
    var idx = 0;
    for (final line in lines) {
      final scoreMatch = RegExp(r'[\d][\d,._ ]*').firstMatch(line);
      if (scoreMatch == null) continue;
      final digits = scoreMatch.group(0)?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
      final score = int.tryParse(digits) ?? 0;
      if (score <= 0) continue;
      final name = line
          .replaceFirst(scoreMatch.group(0) ?? '', '')
          .replaceAll(RegExp(r'^[,;|:/\\-\\s]+|[,;|:/\\-\\s]+$'), '')
          .trim();
      out.add(
        RaidGuildRosterEntry(
          name: name.isEmpty ? 'Player ${++idx}' : name,
          rawAttackScore: score,
        ),
      );
      if (out.length >= 40) break;
    }
    return out;
  }

  List<RaidGuildRosterEntry> _buildSelectedLevelRaidRosterEntries() {
    final out = <RaidGuildRosterEntry>[];
    final levels = _raidRosterSelectedLevels.toList()..sort();
    for (final level in levels) {
      final rows = _raidRosterByLevel[level] ?? const <_RaidLevelRosterRow>[];
      for (final row in rows) {
        final score = row.score;
        if (score <= 0) continue;
        out.add(
          RaidGuildRosterEntry(
            name: row.name.isEmpty ? 'L$level Player ${out.length + 1}' : row.name,
            rawAttackScore: score,
            preferredLevels: <int>{level},
          ),
        );
        if (out.length >= 40) return out;
      }
    }
    return out;
  }

  void _scheduleRecompute({bool immediate = false}) {
    _recomputeDebounce?.cancel();
    if (immediate) {
      unawaited(_recomputePlan());
      return;
    }
    _recomputeDebounce = Timer(
      const Duration(milliseconds: 120),
      () => unawaited(_recomputePlan()),
    );
  }

  bool _shouldUseAsyncOptimization({
    required int milestonePoints,
    required int pointsPerAttackValue,
    required int pointsPerPowerAttackValue,
    required WarAttackStrategy strategy,
  }) {
    if (milestonePoints <= 0) return false;
    if (strategy != WarAttackStrategy.optimizedMix) return false;
    if (pointsPerAttackValue <= 0 || pointsPerPowerAttackValue <= 0) {
      return false;
    }
    final maxPower = (milestonePoints + pointsPerPowerAttackValue - 1) ~/
        pointsPerPowerAttackValue;
    return maxPower >= 20000;
  }

  Future<void> _recomputePlan() async {
    final points = _points;
    final selectedWarElixirs = _selectedWarElixirs();
    final invalidElixirs = selectedWarElixirs
        .where((e) => e.scoreMultiplier <= 0 || e.durationMinutes <= 0)
        .toList(growable: false);
    if (invalidElixirs.isNotEmpty) {
      if (!mounted) return;
      setState(() {
        _warElixirWarning = t(
          'warning.invalid_elixir_config',
          'Please select only elixirs with valid bonus and duration.',
        );
        _plan = const WarPlan(
          pointsPerAttack: 0,
          pointsPerPowerAttack: 0,
          normalAttacks: 0,
          powerAttacks: 0,
          gems: WarGemPlan(
            energyNeeded: 0,
            energyBought: 0,
            gems: 0,
            packs4: 0,
            packs20: 0,
            packs40: 0,
            leftover: 0,
          ),
          boostSummary: WarBoostSummary(),
          elixirUsages: <WarElixirUsage>[],
        );
        _optimizing = false;
        _progressDone = 0;
        _progressTotal = 0;
      });
      return;
    }

    if (points == null) {
      if (!mounted) return;
      setState(() {
        _warElixirWarning = null;
        _plan = const WarPlan(
          pointsPerAttack: 0,
          pointsPerPowerAttack: 0,
          normalAttacks: 0,
          powerAttacks: 0,
          gems: WarGemPlan(
            energyNeeded: 0,
            energyBought: 0,
            gems: 0,
            packs4: 0,
            packs20: 0,
            packs40: 0,
            leftover: 0,
          ),
        );
        _optimizing = false;
        _progressDone = 0;
        _progressTotal = 0;
      });
      return;
    }

    final server = _serverEu ? points.eu : points.global;
    final set = selectPoints(server: server, stripBase: _strip);
    final pointsPerAtk = _frenzy
        ? pointsPerAttack(set: set, frenzy: true, powerAttack: false)
        : pointsPerAttack(set: set, frenzy: false, powerAttack: false);
    final pointsPerPa = _powerAttack
        ? (_frenzy
            ? pointsPerAttack(set: set, frenzy: true, powerAttack: true)
            : pointsPerAttack(set: set, frenzy: false, powerAttack: true))
        : 0;
    final effectiveStrategy =
        _powerAttack ? _attackStrategy : WarAttackStrategy.normalOnly;

    final runAsync = _shouldUseAsyncOptimization(
      milestonePoints: _milestone,
      pointsPerAttackValue: pointsPerAtk,
      pointsPerPowerAttackValue: pointsPerPa,
      strategy: effectiveStrategy,
    );

    if (!runAsync) {
      final plan = computeWarPlan(
        milestonePoints: _milestone,
        pointsPerAttackValue: pointsPerAtk,
        pointsPerPowerAttackValue: pointsPerPa,
        availableEnergy: _energyAvailable,
        elixirs: selectedWarElixirs,
        strategy: effectiveStrategy,
        forcedPowerAttacks: _forcedPowerAttacks,
      );
      if (!mounted) return;
      setState(() {
        _warElixirWarning = null;
        _plan = plan;
        _optimizing = false;
        _progressDone = 0;
        _progressTotal = 0;
      });
      return;
    }

    final token = ++_requestToken;
    if (mounted) {
      setState(() {
        _optimizing = true;
        _progressDone = 0;
        _progressTotal = 0;
      });
    }

    try {
      final plan = await computeWarPlanInIsolate(
        milestonePoints: _milestone,
        pointsPerAttackValue: pointsPerAtk,
        pointsPerPowerAttackValue: pointsPerPa,
        availableEnergy: _energyAvailable,
        elixirs: selectedWarElixirs,
        strategy: effectiveStrategy,
        forcedPowerAttacks: _forcedPowerAttacks,
        onProgress: (done, total) {
          if (!mounted || token != _requestToken) return;
          setState(() {
            _progressDone = done;
            _progressTotal = total;
          });
        },
      );
      if (!mounted || token != _requestToken) return;
      setState(() {
        _warElixirWarning = null;
        _plan = plan;
        _optimizing = false;
      });
    } catch (_) {
      if (!mounted || token != _requestToken) return;
      final fallback = computeWarPlan(
        milestonePoints: _milestone,
        pointsPerAttackValue: pointsPerAtk,
        pointsPerPowerAttackValue: pointsPerPa,
        availableEnergy: _energyAvailable,
        elixirs: selectedWarElixirs,
        strategy: effectiveStrategy,
        forcedPowerAttacks: _forcedPowerAttacks,
      );
      setState(() {
        _warElixirWarning = null;
        _plan = fallback;
        _optimizing = false;
      });
    }
  }

  @override
  void dispose() {
    _recomputeDebounce?.cancel();
    _raidPlannerPrefsDebounce?.cancel();
    _requestToken++;
    _milestoneCtl.dispose();
    _energyCtl.dispose();
    _forcedPaCtl.dispose();
    _raidTargetCtl.dispose();
    _raidAverageCtl.dispose();
    _raidElixirCtl.dispose();
    _raidPlayersCtl.dispose();
    _raidRosterCtl.dispose();
    _disposeRaidLevelRoster();
    for (final e in _warElixirInventory) {
      e.qty.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final theme = Theme.of(context);
    final labelColor = themedLabelColor(theme);
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.w700,
      color: labelColor,
    );

    final server = _serverEu ? points?.eu : points?.global;
    final set =
        server == null ? null : selectPoints(server: server, stripBase: _strip);
    final basePoints = (set == null)
        ? 0
        : pointsPerAttack(set: set, frenzy: false, powerAttack: false);
    final frenzyPoints = (set == null)
        ? 0
        : pointsPerAttack(set: set, frenzy: true, powerAttack: false);
    final paPoints = (set == null)
        ? 0
        : pointsPerAttack(set: set, frenzy: false, powerAttack: true);
    final frenzyPaPoints = (set == null)
        ? 0
        : pointsPerAttack(set: set, frenzy: true, powerAttack: true);

    // WAR toggle semantics:
    // - Server / Strip / Frenzy select the point table.
    // - PA ON enables strategy selection (optimized mix / only PAs / fixed PAs).
    // - PA OFF keeps only normal attacks on the selected table.
    final plan = _plan;
    final selectedWarElixirs = _selectedWarElixirs();
    final totalEnergy = plan.totalEnergy;
    final selectedPointsSummary = _buildSelectedPointsSummary(
      basePoints: basePoints,
      frenzyPoints: frenzyPoints,
      paPoints: paPoints,
      frenzyPaPoints: frenzyPaPoints,
      strip: _strip,
      frenzy: _frenzy,
      powerAttack: _powerAttack,
    );
    final activeNormalPoints = pointsPerAttack(
      set: set ??
          const WarPointsSet(
            base: 0,
            frenzy: 0,
            powerAttack: 0,
            frenzyPowerAttack: 0,
          ),
      frenzy: _frenzy,
      powerAttack: false,
    );
    final activePowerPoints = _powerAttack
        ? pointsPerAttack(
            set: set ??
                const WarPointsSet(
                  base: 0,
                  frenzy: 0,
                  powerAttack: 0,
                  frenzyPowerAttack: 0,
                ),
            frenzy: _frenzy,
            powerAttack: true,
          )
        : null;
    final pointValueEntries = _buildPointValueEntries(
      activeNormalPoints: activeNormalPoints,
      activePowerPoints: activePowerPoints,
      elixirs: selectedWarElixirs,
    );
    final elixirScoreSummary = _buildElixirScoreSummary(
      plan: plan,
      activeNormalPoints: activeNormalPoints,
      activePowerPoints: activePowerPoints,
    );
    final bestMixBadges = _buildBestMixBadges(
      plan: plan,
      strip: _strip,
      frenzy: _frenzy,
    );
    final attackSummary = _buildAttackSummary(
      plan: plan,
      strip: _strip,
      frenzy: _frenzy,
      powerAttack: _powerAttack,
    );
    final gemSummary = _buildGemSummary(plan.gems);
    final strategyLabel = _warStrategyLabel(
      _powerAttack ? _attackStrategy : WarAttackStrategy.normalOnly,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(t('nav.war', 'War')),
        actions: [
          AppBarShortcutsMenuButton(
            buttonKey: const ValueKey('app-shortcuts-menu'),
            tooltip: t('shortcuts.menu.tooltip', 'Quick actions'),
            title: t('shortcuts.menu.title', 'Quick actions'),
            items: [
              if (widget.isPremium)
                AppShortcutSheetItem(
                  tileKey: const Key('war-mode-toggle-menu-item'),
                  icon: _warViewMode
                      ? Icons.travel_explore_outlined
                      : Icons.arrow_back_outlined,
                  label: _warViewMode
                      ? t('war.mode.menu.open_raid', 'Open Raid planner')
                      : t('war.mode.menu.back_war', 'Back to War'),
                  onTap: () {
                    if (!mounted) return;
                    setState(() => _warViewMode = !_warViewMode);
                    _scheduleRaidPlannerSave();
                  },
                ),
              AppShortcutSheetItem(
                icon: widget.isPremium ? Icons.star : Icons.star_border,
                iconColor: widget.isPremium ? theme.colorScheme.primary : null,
                label: widget.isPremium
                    ? t('premium.active', 'Premium active')
                    : t('premium.inactive', 'Premium inactive'),
                onTap: widget.onOpenPremium,
              ),
              AppShortcutSheetItem(
                icon: Icons.history,
                label: t('results.last', 'Last results'),
                onTap: widget.onOpenLastResults,
              ),
              AppShortcutSheetItem(
                icon: Icons.palette_outlined,
                label: t('theme.tooltip', 'Themes'),
                onTap: widget.onOpenTheme,
              ),
              AppShortcutSheetItem(
                icon: Icons.public,
                label: t('lang', 'Language'),
                onTap: widget.onOpenLanguage,
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_warViewMode || !widget.isPremium) ...[
            CompactCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('war.section.title', 'War calculator'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('war-calculator-tip-button'),
                        tooltip: t('war.tip.title', 'War tip'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showWarCalculatorTip(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: LabeledField(
                          label: t('war.milestone', 'Milestone richiesta'),
                          labelStyle: labelStyle,
                          child: CompactGroupedIntField(
                            controller: _milestoneCtl,
                            hint: '1,000,000',
                            enabled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: LabeledField(
                          label:
                              t('war.energy_available', 'Energie disponibili'),
                          labelStyle: labelStyle,
                          child: CompactIntField(
                            controller: _energyCtl,
                            hint: '0',
                            enabled: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('war.server', 'Server'),
                              style: labelStyle,
                            ),
                            const SizedBox(height: 4),
                            SegmentedButton<bool>(
                              segments: [
                                ButtonSegment<bool>(
                                  value: true,
                                  label: Text(t('war.server.eu', 'EU')),
                                ),
                                ButtonSegment<bool>(
                                  value: false,
                                  label: Text(t('war.server.global', 'Global')),
                                ),
                              ],
                              showSelectedIcon: false,
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                padding: WidgetStatePropertyAll(
                                  EdgeInsets.symmetric(horizontal: 8),
                                ),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              selected: {_serverEu},
                              onSelectionChanged: (s) {
                                if (s.isEmpty) return;
                                setState(() => _serverEu = s.first);
                                _scheduleRecompute();
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('war.strip', 'Strip'),
                              style: labelStyle,
                            ),
                            Switch(
                              value: _strip,
                              onChanged: (v) {
                                setState(() => _strip = v);
                                _scheduleRecompute();
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('war.frenzy', 'Frenzy'),
                              style: labelStyle,
                            ),
                            Switch(
                              value: _frenzy,
                              onChanged: (v) {
                                setState(() => _frenzy = v);
                                _scheduleRecompute();
                              },
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t('war.power_attack', 'Power attack'),
                              style: labelStyle,
                            ),
                            Switch(
                              value: _powerAttack,
                              onChanged: (v) {
                                setState(() {
                                  _powerAttack = v;
                                  if (!v) {
                                    _attackStrategy =
                                        WarAttackStrategy.optimizedMix;
                                  }
                                });
                                _scheduleRecompute();
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_powerAttack) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          flex: 2,
                          child: LabeledField(
                            label: t('war.attack_strategy', 'PA strategy'),
                            labelStyle: labelStyle,
                            child: DropdownButtonFormField<WarAttackStrategy>(
                              key: ValueKey(
                                'war-attack-strategy-${_attackStrategy.name}',
                              ),
                              initialValue: _attackStrategy,
                              decoration: const InputDecoration(
                                isDense: true,
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: WarAttackStrategy.optimizedMix,
                                  child: Text(
                                    t(
                                      'war.attack_strategy.optimized_mix',
                                      'Optimized mix',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: WarAttackStrategy.powerAttackOnly,
                                  child: Text(
                                    t(
                                      'war.attack_strategy.power_attack_only',
                                      'Only PAs',
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: WarAttackStrategy.fixedPowerAttacks,
                                  child: Text(
                                    t(
                                      'war.attack_strategy.fixed_power_attacks',
                                      'Fixed PAs',
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _attackStrategy = value);
                                _scheduleRecompute();
                              },
                            ),
                          ),
                        ),
                        if (_attackStrategy ==
                            WarAttackStrategy.fixedPowerAttacks) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: LabeledField(
                              label: t('war.fixed_power_attacks', 'Forced PAs'),
                              labelStyle: labelStyle,
                              child: CompactIntField(
                                controller: _forcedPaCtl,
                                hint: '1',
                                enabled: true,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            CompactCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('elixirs.title', 'Elixirs inventory'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('war-elixirs-tip-button'),
                        tooltip: t('war.elixirs.tip.title', 'War elixirs tip'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showWarElixirsTip(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  LabeledField(
                    label: t('elixirs.add', 'Add elixir'),
                    labelStyle: labelStyle,
                    child: Builder(
                      builder: (_) {
                        final available = _warElixirs
                            .where(
                              (e) => !_warElixirInventory
                                  .any((i) => i.config.name == e.name),
                            )
                            .toList(growable: false);

                        final canPick = available.isNotEmpty &&
                            _warElixirInventory.length < _warElixirsLimit &&
                            !_optimizing;

                        return DropdownButtonFormField<String>(
                          key: _warElixirDropdownKey,
                          items: available
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.name,
                                  child: Text(e.name),
                                ),
                              )
                              .toList(growable: false),
                          initialValue: null,
                          onChanged: canPick
                              ? (v) {
                                  if (v == null) return;
                                  _addWarElixir(v);
                                }
                              : null,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          hint: Text(
                            t('elixirs.add', 'Add elixir'),
                          ),
                        );
                      },
                    ),
                  ),
                  if (_warElixirWarning != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _warElixirWarning!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (_warElixirInventory.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    for (int i = 0; i < _warElixirInventory.length; i++) ...[
                      _WarElixirRow(
                        item: _warElixirInventory[i],
                        running: _optimizing,
                        qtyHint: t('elixirs.qty', 'Qty'),
                        deleteTooltip: t('elixirs.delete', 'Remove'),
                        attacksLabel: t('war.attacks_word', 'attacks'),
                        onRemove: () => _removeWarElixirAt(i),
                      ),
                      if (i != _warElixirInventory.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            CompactCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          t('war.results', 'Risultati'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const Key('war-results-tip-button'),
                        tooltip: t('war.results.tip.title', 'War results tip'),
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.info_outline),
                        onPressed: () => _showWarResultsTip(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _WarSummaryTile(
                        label: t('war.attacks_needed', 'Attacchi necessari'),
                        value: fmtInt(plan.attacks),
                        icon: Icons.sports_martial_arts,
                      ),
                      _WarSummaryTile(
                        label: t('war.total_energy', 'Energie totali'),
                        value: fmtInt(totalEnergy),
                        icon: Icons.bolt,
                      ),
                      _WarSummaryTile(
                        label: t('war.gems_needed', 'Gemme necessarie'),
                        value: fmtInt(plan.gems.gems),
                        icon: Icons.diamond_outlined,
                      ),
                      if (_powerAttack)
                        _WarSummaryTile(
                          label: t('war.power_attacks_used', 'PAs used'),
                          value: fmtInt(plan.powerAttacks),
                          icon: Icons.flash_on_outlined,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _resultRow(
                    t('war.strategy_active', 'Active strategy'),
                    strategyLabel,
                    labelStyle: labelStyle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t('war.attack_summary', 'Riepilogo attacchi'),
                    style: labelStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(attackSummary),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: bestMixBadges
                        .map((badge) =>
                            _WarMetaPill(text: badge, highlighted: true))
                        .toList(growable: false),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('war.gem_summary', 'Riepilogo gemme'),
                    style: labelStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(gemSummary),
                  if (plan.elixirUsages.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      t('war.elixir_coverage', 'Elixir coverage'),
                      style: labelStyle,
                    ),
                    const SizedBox(height: 4),
                    _resultRow(
                      t('war.elixir_boosted_total', 'Boosted attacks'),
                      fmtInt(plan.boostSummary.boostedTotal),
                      labelStyle: labelStyle,
                    ),
                    _resultRow(
                      t('war.elixir_unboosted_total', 'Unboosted attacks'),
                      fmtInt(plan.boostSummary.unboostedTotal),
                      labelStyle: labelStyle,
                    ),
                    _resultRow(
                      t('war.elixir_boosted_pa', 'Boosted PA'),
                      fmtInt(plan.boostSummary.boostedPowerAttacks),
                      labelStyle: labelStyle,
                    ),
                    _resultRow(
                      t('war.elixir_boosted_normal', 'Boosted Normal'),
                      fmtInt(plan.boostSummary.boostedNormalAttacks),
                      labelStyle: labelStyle,
                    ),
                    _resultRow(
                      t('war.elixir_unboosted_pa', 'Unboosted PA'),
                      fmtInt(plan.boostSummary.unboostedPowerAttacks),
                      labelStyle: labelStyle,
                    ),
                    _resultRow(
                      t('war.elixir_unboosted_normal', 'Unboosted Normal'),
                      fmtInt(plan.boostSummary.unboostedNormalAttacks),
                      labelStyle: labelStyle,
                    ),
                    _resultRow(
                      t('war.elixir_boosted_points', 'Boosted score'),
                      fmtInt(elixirScoreSummary.boostedScore),
                      labelStyle: labelStyle,
                    ),
                    _resultRow(
                      t('war.elixir_base_points',
                          'Base score on boosted attacks'),
                      fmtInt(elixirScoreSummary.baseScore),
                      labelStyle: labelStyle,
                    ),
                    _resultRow(
                      t('war.elixir_bonus_points', 'Bonus score from elixirs'),
                      fmtInt(elixirScoreSummary.bonusScore),
                      labelStyle: labelStyle,
                      highlightValue: true,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t('war.elixir_usage_breakdown', 'Elixir usage breakdown'),
                      style: labelStyle,
                    ),
                    const SizedBox(height: 4),
                    for (final usage in plan.elixirUsages)
                      if (usage.usedAttacks > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(
                            '${usage.name} (+${(usage.scoreMultiplier * 100).round()}%) '
                            '-> ${fmtInt(usage.usedAttacks)} '
                            '• ${fmtInt(_buildUsageBoostedScore(
                              usage: usage,
                              activeNormalPoints: activeNormalPoints,
                              activePowerPoints: activePowerPoints,
                            ))} '
                            '(${t('war.elixir_bonus_short', 'bonus')}: '
                            '${fmtInt(_buildUsageBonusScore(
                              usage: usage,
                              activeNormalPoints: activeNormalPoints,
                              activePowerPoints: activePowerPoints,
                            ))}) '
                            '(${t('war.elixir_pa_short', 'PA')}: ${fmtInt(usage.boostedPowerAttacks)}, '
                            '${t('war.elixir_normal_short', 'N')}: ${fmtInt(usage.boostedNormalAttacks)})',
                          ),
                        ),
                  ],
                  if (_optimizing) ...[
                    const SizedBox(height: 10),
                    Text(
                      t('war.optimizing', 'Optimizing best mix...'),
                      style: labelStyle,
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: (_progressTotal > 0)
                          ? (_progressDone / _progressTotal).clamp(0.0, 1.0)
                          : null,
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        (_progressTotal > 0)
                            ? '${fmtInt(_progressDone)}/${fmtInt(_progressTotal)} '
                                '(${((_progressDone / _progressTotal) * 100).toStringAsFixed(1)}%)'
                            : t('war.optimizing_wait', 'Please wait...'),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    t('war.points_per_attack', 'Punti selezionati'),
                    style: labelStyle,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selectedPointsSummary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (pointValueEntries.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _WarPointValuesPanel(
                      title: t('war.point_values', 'Point values with elixirs'),
                      subtitle: t(
                        'war.point_values.base',
                        'Base values and boosted values for the currently selected war mode.',
                      ),
                      entries: pointValueEntries,
                    ),
                  ],
                  const SizedBox(height: 6),
                  _resultRow(
                    t('war.attacks_needed', 'Attacchi necessari'),
                    fmtInt(plan.attacks),
                    labelStyle: labelStyle,
                  ),
                  _resultRow(
                    t('war.energy_needed', 'Energie necessarie'),
                    fmtInt(plan.gems.energyNeeded),
                    labelStyle: labelStyle,
                  ),
                  _resultRow(
                    t('war.total_energy', 'Energie totali'),
                    fmtInt(totalEnergy),
                    labelStyle: labelStyle,
                  ),
                  _resultRow(
                    t('war.gems_needed', 'Gemme necessarie'),
                    fmtInt(plan.gems.gems),
                    labelStyle: labelStyle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('war.packs', 'Pacchetti'),
                    style: labelStyle,
                  ),
                  const SizedBox(height: 6),
                  _resultRow(
                    '4',
                    'x${plan.gems.packs4}',
                    labelStyle: labelStyle,
                  ),
                  _resultRow(
                    '20',
                    'x${plan.gems.packs20}',
                    labelStyle: labelStyle,
                  ),
                  _resultRow(
                    '40',
                    'x${plan.gems.packs40}',
                    labelStyle: labelStyle,
                  ),
                  const SizedBox(height: 6),
                  _resultRow(
                    t('war.energy_bought', 'Energie comprate'),
                    fmtInt(plan.gems.energyBought),
                    labelStyle: labelStyle,
                  ),
                  _resultRow(
                    t('war.energy_leftover', 'Energie rimaste'),
                    fmtInt(plan.gems.leftover),
                    labelStyle: labelStyle,
                  ),
                ],
              ),
            ),
          ] else ...[
            _buildRaidPlannerCard(theme: theme, labelStyle: labelStyle),
            const SizedBox(height: 12),
            _buildRaidResultsCard(theme: theme, labelStyle: labelStyle),
          ],
        ],
      ),
    );
  }

  Widget _buildRaidPlannerCard({
    required ThemeData theme,
    required TextStyle? labelStyle,
  }) {
    final availableLevels = _availableRaidLevels;
    final rosterCount = _collectRaidRosterEntries().length;

    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('raid_guild.section.title', 'Raid guild planner'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const Key('raid-guild-tip-button'),
                tooltip: t('raid_guild.tip.title', 'Raid guild planner tip'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.info_outline),
                onPressed: () => _showRaidGuildTip(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LabeledField(
            label: t('raid_guild.planner_mode', 'Planner mode'),
            labelStyle: labelStyle,
            child: SegmentedButton<RaidGuildPlannerMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment<RaidGuildPlannerMode>(
                  value: RaidGuildPlannerMode.simple,
                  label: Text(
                    t('raid_guild.planner.simple', 'Simple estimate'),
                  ),
                ),
                ButtonSegment<RaidGuildPlannerMode>(
                  value: RaidGuildPlannerMode.fastest,
                  label: Text(
                    t('raid_guild.planner.fastest', 'Fastest path'),
                  ),
                ),
              ],
              selected: {_raidPlannerMode},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                setState(() => _raidPlannerMode = s.first);
                _recomputeRaidPlans();
                _scheduleRaidPlannerSave();
              },
            ),
          ),
          const SizedBox(height: 12),
          LabeledField(
            label: t('raid_guild.boss_mode', 'Boss mode'),
            labelStyle: labelStyle,
            child: SegmentedButton<RaidGuildBossMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment<RaidGuildBossMode>(
                  value: RaidGuildBossMode.raid,
                  label: Text(
                    t('raid_guild.boss_mode.raid', 'Raid'),
                  ),
                ),
                ButtonSegment<RaidGuildBossMode>(
                  value: RaidGuildBossMode.blitz,
                  label: Text(
                    t('raid_guild.boss_mode.blitz', 'Blitz'),
                  ),
                ),
              ],
              selected: {_raidBossMode},
              onSelectionChanged: (s) {
                if (s.isEmpty) return;
                final nextMode = s.first;
                setState(() {
                  _raidBossMode = nextMode;
                  final levels = _availableRaidLevels;
                  if (!levels.contains(_raidSelectedLevel)) {
                    _raidSelectedLevel = levels.isEmpty ? 1 : levels.last;
                  }
                  _raidForcedLevels.removeWhere(
                    (level) => !levels.contains(level),
                  );
                  _raidRosterSelectedLevels.removeWhere(
                    (level) => !levels.contains(level),
                  );
                  _raidRosterByLevel.removeWhere(
                    (level, _) => !levels.contains(level),
                  );
                });
                _recomputeRaidPlans();
                _scheduleRaidPlannerSave();
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: LabeledField(
                  label: t('raid_guild.target_points', 'Target guild points'),
                  labelStyle: labelStyle,
                  child: CompactGroupedIntField(
                    controller: _raidTargetCtl,
                    hint: '1,000,000,000',
                    enabled: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LabeledField(
                  label: t('raid_guild.elixir_bonus', 'Elixir bonus %'),
                  labelStyle: labelStyle,
                  child: CompactIntField(
                    controller: _raidElixirCtl,
                    hint: '0',
                    enabled: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_raidPlannerMode == RaidGuildPlannerMode.simple) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: LabeledField(
                    label: t('raid_guild.boss_level', 'Boss level'),
                    labelStyle: labelStyle,
                    child: DropdownButtonFormField<int>(
                      initialValue: availableLevels.contains(_raidSelectedLevel)
                          ? _raidSelectedLevel
                          : (availableLevels.isEmpty
                              ? null
                              : availableLevels.last),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: availableLevels
                          .map(
                            (level) => DropdownMenuItem<int>(
                              value: level,
                              child: Text('L$level'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _raidSelectedLevel = value);
                        _recomputeRaidPlans();
                        _scheduleRaidPlannerSave();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: LabeledField(
                    label: t('raid_guild.average_attack', 'Average attack'),
                    labelStyle: labelStyle,
                    child: CompactGroupedIntField(
                      controller: _raidAverageCtl,
                      hint: '2,000,000',
                      enabled: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LabeledField(
                    label: t('raid_guild.active_players', 'Active players'),
                    labelStyle: labelStyle,
                    child: CompactIntField(
                      controller: _raidPlayersCtl,
                      hint: '40',
                      enabled: true,
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            LabeledField(
              label: t('raid_guild.roster_mode', 'Roster input'),
              labelStyle: labelStyle,
              child: SegmentedButton<_RaidRosterInputMode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment<_RaidRosterInputMode>(
                    value: _RaidRosterInputMode.automatic,
                    label: Text(
                      t(
                        'raid_guild.roster_mode.automatic',
                        'Automatically optimize to best',
                      ),
                    ),
                  ),
                  ButtonSegment<_RaidRosterInputMode>(
                    value: _RaidRosterInputMode.selectedLevels,
                    label: Text(
                      t(
                        'raid_guild.roster_mode.selected_levels',
                        'Optimize on selected boss levels',
                      ),
                    ),
                  ),
                ],
                selected: {_raidRosterInputMode},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  setState(() => _raidRosterInputMode = s.first);
                  _recomputeRaidPlans();
                  _scheduleRaidPlannerSave();
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: LabeledField(
                    label: t('raid_guild.board_size', 'Active boss slots'),
                    labelStyle: labelStyle,
                    child: DropdownButtonFormField<int>(
                      initialValue: _raidBoardSize,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      items: List<int>.generate(5, (i) => i + 1)
                          .map(
                            (size) => DropdownMenuItem<int>(
                              value: size,
                              child: Text(fmtInt(size)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _raidBoardSize = value;
                          if (_raidForcedLevels.length > _raidBoardSize) {
                            final sorted = _raidForcedLevels.toList()..sort();
                            _raidForcedLevels
                              ..clear()
                              ..addAll(sorted.take(_raidBoardSize));
                          }
                        });
                        _recomputeRaidPlans();
                        _scheduleRaidPlannerSave();
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: _WarMetaPill(
                    text:
                        '${t('raid_guild.active_players', 'Active players')}: ${fmtInt(rosterCount)}',
                    highlighted: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_raidRosterInputMode == _RaidRosterInputMode.automatic) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t('raid_guild.force_levels', 'Force levels'),
                      style: labelStyle,
                    ),
                  ),
                  TextButton(
                    onPressed: _raidForcedLevels.isEmpty
                        ? null
                        : () {
                            setState(_raidForcedLevels.clear);
                            _recomputeRaidPlans();
                            _scheduleRaidPlannerSave();
                          },
                    child: Text(
                      t('raid_guild.force_levels.clear', 'Clear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableLevels
                    .map(
                      (level) => FilterChip(
                        label: Text('L$level'),
                        selected: _raidForcedLevels.contains(level),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              if (!_raidForcedLevels.contains(level) &&
                                  _raidForcedLevels.length >= 5) {
                                return;
                              }
                              _raidForcedLevels.add(level);
                              if (_raidForcedLevels.length > _raidBoardSize) {
                                _raidBoardSize =
                                    _raidForcedLevels.length.clamp(1, 5);
                              }
                            } else {
                              _raidForcedLevels.remove(level);
                            }
                          });
                          _recomputeRaidPlans();
                          _scheduleRaidPlannerSave();
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'raid_guild.force_levels.note',
                  'Selected levels must appear in the recommended board for Fastest path.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: t('raid_guild.player_scores', 'Player average scores'),
                labelStyle: labelStyle,
                child: TextField(
                  controller: _raidRosterCtl,
                  keyboardType: TextInputType.multiline,
                  minLines: 4,
                  maxLines: 7,
                  decoration: InputDecoration(
                    hintText: t(
                      'raid_guild.player_scores.hint',
                      'Use one player per line: 1200000, Maxxetto',
                    ),
                    isDense: true,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      t(
                        'raid_guild.selected_levels',
                        'Selected boss levels',
                      ),
                      style: labelStyle,
                    ),
                  ),
                  TextButton(
                    onPressed: _raidRosterSelectedLevels.isEmpty
                        ? null
                        : () {
                            setState(_raidRosterSelectedLevels.clear);
                            _recomputeRaidPlans();
                            _scheduleRaidPlannerSave();
                          },
                    child: Text(
                      t('raid_guild.force_levels.clear', 'Clear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableLevels
                    .map(
                      (level) => FilterChip(
                        label: Text('L$level'),
                        selected: _raidRosterSelectedLevels.contains(level),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _raidRosterSelectedLevels.add(level);
                              _raidRosterByLevel.putIfAbsent(
                                level,
                                () => <_RaidLevelRosterRow>[],
                              );
                            } else {
                              _raidRosterSelectedLevels.remove(level);
                            }
                          });
                          _recomputeRaidPlans();
                          _scheduleRaidPlannerSave();
                        },
                      ),
                    )
                    .toList(growable: false),
              ),
              const SizedBox(height: 8),
              Text(
                t(
                  'raid_guild.selected_levels.note',
                  'Add player nicknames and average scores per boss level. The optimizer will keep those players on their selected levels.',
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              for (final level in (_raidRosterSelectedLevels.toList()..sort()))
                _buildRaidLevelRosterSection(
                  theme: theme,
                  labelStyle: labelStyle,
                  level: level,
                ),
            ],
          ],
          const SizedBox(height: 10),
          Text(
            t(
              'raid_guild.fastest_note',
              'Fastest path distributes simultaneous attacks across up to 5 active bosses and reads HP/kill values from boss tables when available.',
            ),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildRaidResultsCard({
    required ThemeData theme,
    required TextStyle? labelStyle,
  }) {
    final simplePlan = _raidSimplePlan;
    final fastestPlan = _raidFastestPlan;
    final noData = Text(
      t('raid_guild.no_data', 'No raid data available yet.'),
      style: theme.textTheme.bodyMedium,
    );
    late final List<Widget> resultWidgets;
    String? assetValuesText;
    if (_raidPlannerMode == RaidGuildPlannerMode.simple) {
      resultWidgets = simplePlan == null
          ? <Widget>[noData]
          : _buildRaidSimpleResultWidgets(
              theme: theme,
              labelStyle: labelStyle,
              plan: simplePlan,
            );
      final selectedRow = _activeRaidRows[_raidSelectedLevel];
      if (selectedRow != null) {
        assetValuesText =
            '${t('raid_guild.asset_values', 'Using values from boss tables')}: '
            '${_raidBossMode == RaidGuildBossMode.blitz ? t('raid_guild.boss_mode.blitz', 'Blitz') : t('raid_guild.boss_mode.raid', 'Raid')} '
            'L${selectedRow.level} HP=${fmtInt(selectedRow.hp)} '
            'Kill=${fmtInt(_killPointsForRow(selectedRow))}';
      }
    } else {
      resultWidgets = fastestPlan == null
          ? <Widget>[noData]
          : _buildRaidFastestResultWidgets(
              theme: theme,
              labelStyle: labelStyle,
              plan: fastestPlan,
            );
      if (_activeRaidRows.isNotEmpty) {
        final levels = _availableRaidLevels.map((level) => 'L$level').join(', ');
        assetValuesText =
            '${t('raid_guild.asset_values', 'Using values from boss tables')}: '
            '${_raidBossMode == RaidGuildBossMode.blitz ? t('raid_guild.boss_mode.blitz', 'Blitz') : t('raid_guild.boss_mode.raid', 'Raid')} '
            '$levels';
      }
    }

    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('war.results', 'Results'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                tooltip: t('raid_guild.export', 'Copy export'),
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.copy_all_outlined),
                onPressed: _copyRaidPlannerExport,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (assetValuesText != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                assetValuesText,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ...resultWidgets,
        ],
      ),
    );
  }

  Widget _buildRaidLevelRosterSection({
    required ThemeData theme,
    required TextStyle? labelStyle,
    required int level,
  }) {
    final rows = _raidRosterByLevel[level] ?? const <_RaidLevelRosterRow>[];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${t('raid_guild.level_section', 'Level')} $level',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _addRaidLevelRosterRow(level);
                  });
                  _recomputeRaidPlans();
                  _scheduleRaidPlannerSave();
                },
                icon: const Icon(Icons.add, size: 18),
                label: Text(t('raid_guild.player.add', 'Add player')),
              ),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                t(
                  'raid_guild.player.empty',
                  'No players added for this level yet.',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: row.nameCtl,
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        labelText: t('raid_guild.player.name', 'Nickname'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: row.scoreCtl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        isDense: true,
                        border: const OutlineInputBorder(),
                        labelText:
                            t('raid_guild.player.average', 'Average score'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: t('raid_guild.player.remove', 'Remove player'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      setState(() {
                        _removeRaidLevelRosterRow(level, row);
                      });
                      _recomputeRaidPlans();
                      _scheduleRaidPlannerSave();
                    },
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildRaidSimpleResultWidgets({
    required ThemeData theme,
    required TextStyle? labelStyle,
    required RaidGuildSimplePlan plan,
  }) {
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _WarSummaryTile(
            label: t('raid_guild.total_attacks', 'Total attacks'),
            value: fmtInt(plan.attacksUsed),
            icon: Icons.sports_martial_arts,
          ),
          _WarSummaryTile(
            label: t('raid_guild.bosses_killed', 'Bosses killed'),
            value: fmtInt(plan.bossesKilled),
            icon: Icons.shield_moon_outlined,
          ),
          _WarSummaryTile(
            label: t('raid_guild.total_energy', 'Total energy'),
            value: fmtInt(plan.energy.totalEnergy),
            icon: Icons.bolt,
          ),
          _WarSummaryTile(
            label: t('raid_guild.total_gems', 'Total gems'),
            value: fmtInt(plan.energy.gems),
            icon: Icons.diamond_outlined,
          ),
        ],
      ),
      const SizedBox(height: 10),
      _resultRow(
        t('raid_guild.boss_level', 'Boss level'),
        '${_raidBossMode == RaidGuildBossMode.blitz ? t('raid_guild.boss_mode.blitz', 'Blitz') : t('raid_guild.boss_mode.raid', 'Raid')} L${plan.boss.level}',
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.effective_attack', 'Effective attack'),
        fmtInt(plan.effectiveAttackScore),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.attacks_per_boss', 'Attacks per boss'),
        fmtInt(plan.attacksPerBoss),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.player_points', 'Player points'),
        fmtInt(plan.totalPlayerPoints),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.kill_bonus_points', 'Kill bonus points'),
        fmtInt(plan.totalKillBonusPoints),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.target_points', 'Target guild points'),
        fmtInt(plan.targetPoints),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.total_points', 'Total guild points'),
        fmtInt(plan.totalGuildPoints),
        labelStyle: labelStyle,
        highlightValue: true,
      ),
      const SizedBox(height: 8),
      Text(
        t('raid_guild.energy_split', 'Energy split'),
        style: labelStyle,
      ),
      const SizedBox(height: 4),
      _resultRow(
        t('raid_guild.free_energy_total', 'Total free energy'),
        fmtInt(plan.energy.totalFreeEnergy),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.paid_energy_total', 'Total paid energy'),
        fmtInt(plan.energy.totalPaidEnergy),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.energy_packs_40', '40-energy packs'),
        fmtInt(plan.energy.packs40),
        labelStyle: labelStyle,
      ),
    ];
  }

  List<Widget> _buildRaidFastestResultWidgets({
    required ThemeData theme,
    required TextStyle? labelStyle,
    required RaidGuildFastestPlan plan,
  }) {
    final bossesKilled = plan.bossesKilledByLevel.values.fold<int>(
      0,
      (sum, value) => sum + value,
    );
    final boardLabel = plan.recommendedBoard.isEmpty
        ? t('war.none', '-')
        : _summarizeRecommendedBoard(plan.recommendedBoard);
    final killBreakdown = plan.bossesKilledByLevel.isEmpty
        ? t('war.none', '-')
        : _summarizeKillsByLevel(plan.bossesKilledByLevel);
    final firstRoundAssignments = plan.firstRoundAssignments;

    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _WarSummaryTile(
            label: t('raid_guild.rounds', 'Rounds'),
            value: fmtInt(plan.rounds),
            icon: Icons.timer_outlined,
          ),
          _WarSummaryTile(
            label: t('raid_guild.total_attacks', 'Total attacks'),
            value: fmtInt(plan.totalAttacks),
            icon: Icons.sports_martial_arts,
          ),
          _WarSummaryTile(
            label: t('raid_guild.bosses_killed', 'Bosses killed'),
            value: fmtInt(bossesKilled),
            icon: Icons.shield_moon_outlined,
          ),
          _WarSummaryTile(
            label: t('raid_guild.total_gems', 'Total gems'),
            value: fmtInt(plan.energy.gems),
            icon: Icons.diamond_outlined,
          ),
        ],
      ),
      const SizedBox(height: 10),
      _resultRow(
        t('raid_guild.recommended_board', 'Recommended board'),
        boardLabel,
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.kill_breakdown', 'Kills by level'),
        killBreakdown,
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.player_points', 'Player points'),
        fmtInt(plan.totalPlayerPoints),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.kill_bonus_points', 'Kill bonus points'),
        fmtInt(plan.totalKillBonusPoints),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.total_points', 'Total guild points'),
        fmtInt(plan.totalGuildPoints),
        labelStyle: labelStyle,
        highlightValue: true,
      ),
      if (firstRoundAssignments.isNotEmpty) ...[
        const SizedBox(height: 8),
        Text(
          t(
            'raid_guild.assignments',
            'Suggested first-round assignments',
          ),
          style: labelStyle,
        ),
        const SizedBox(height: 4),
        for (final assignment in firstRoundAssignments)
          _resultRow(
            '${t('raid_guild.slot', 'Slot')} ${assignment.slotIndex} • L${assignment.level}',
            '${assignment.playerNames.join(', ')} (${fmtInt(assignment.totalScore)})',
            labelStyle: labelStyle,
          ),
        if (plan.firstRoundUnassignedPlayers.isNotEmpty)
          _resultRow(
            t('raid_guild.unassigned', 'Unassigned players'),
            plan.firstRoundUnassignedPlayers.join(', '),
            labelStyle: labelStyle,
          ),
      ],
      const SizedBox(height: 8),
      Text(
        t(
          'raid_guild.fastest_note',
          'Fastest path distributes simultaneous attacks across up to 5 active bosses and reads HP/kill values from boss tables when available.',
        ),
        style: theme.textTheme.bodySmall,
      ),
      const SizedBox(height: 8),
      _resultRow(
        t('raid_guild.total_energy', 'Total energy'),
        fmtInt(plan.energy.totalEnergy),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.paid_energy_total', 'Total paid energy'),
        fmtInt(plan.energy.totalPaidEnergy),
        labelStyle: labelStyle,
      ),
      _resultRow(
        t('raid_guild.energy_packs_40', '40-energy packs'),
        fmtInt(plan.energy.packs40),
        labelStyle: labelStyle,
      ),
    ];
  }

  String _summarizeRecommendedBoard(List<RaidGuildBossSpec> board) {
    final counts = <int, int>{};
    for (final boss in board) {
      counts[boss.level] = (counts[boss.level] ?? 0) + 1;
    }
    final levels = counts.keys.toList()..sort((a, b) => b.compareTo(a));
    return levels.map((level) => 'L$level x${counts[level]}').join(', ');
  }

  String _summarizeKillsByLevel(Map<int, int> killsByLevel) {
    final levels = killsByLevel.keys.toList()..sort((a, b) => b.compareTo(a));
    return levels
        .map((level) => 'L$level x${fmtInt(killsByLevel[level] ?? 0)}')
        .join(', ');
  }

  void _copyRaidPlannerExport() {
    final selectedRow = _activeRaidRows[_raidSelectedLevel];
    final rosterEntries = _collectRaidRosterEntries();
    final payload = <String, Object?>{
      'type': 'raid_guild_planner_export_v1',
      'exportedAtIso': DateTime.now().toIso8601String(),
      'premiumOnly': true,
      'plannerMode': _raidPlannerMode == RaidGuildPlannerMode.fastest
          ? 'fastest'
          : 'simple',
      'rosterInputMode': _raidRosterInputMode == _RaidRosterInputMode.selectedLevels
          ? 'selected_levels'
          : 'automatic',
      'bossMode': _raidBossMode == RaidGuildBossMode.blitz ? 'blitz' : 'raid',
      'targetPoints': _raidTargetPoints,
      'elixirPercent': _raidElixirPercent,
      'activePlayers': _raidPlayers,
      'boardSize': _raidBoardSize,
      'selectedLevel': _raidSelectedLevel,
      'forcedLevels': (_raidForcedLevels.toList()..sort()),
      'selectedRosterLevels': (_raidRosterSelectedLevels.toList()..sort()),
      'rosterEntries': [
        for (final entry in rosterEntries)
          <String, Object?>{
            'name': entry.name,
            'rawAttackScore': entry.rawAttackScore,
            'preferredLevels': entry.preferredLevels.toList()..sort(),
          },
      ],
      'bossRow': selectedRow?.toJson(),
      'simplePlan': _raidSimplePlan == null
          ? null
          : <String, Object?>{
              'effectiveAttackScore': _raidSimplePlan!.effectiveAttackScore,
              'attacksUsed': _raidSimplePlan!.attacksUsed,
              'bossesKilled': _raidSimplePlan!.bossesKilled,
              'totalPlayerPoints': _raidSimplePlan!.totalPlayerPoints,
              'totalKillBonusPoints': _raidSimplePlan!.totalKillBonusPoints,
              'totalGuildPoints': _raidSimplePlan!.totalGuildPoints,
              'energy': <String, Object?>{
                'totalAttacks': _raidSimplePlan!.energy.totalAttacks,
                'totalEnergy': _raidSimplePlan!.energy.totalEnergy,
                'totalPaidEnergy': _raidSimplePlan!.energy.totalPaidEnergy,
                'packs40': _raidSimplePlan!.energy.packs40,
                'gems': _raidSimplePlan!.energy.gems,
              },
            },
      'fastestPlan': _raidFastestPlan == null
          ? null
          : <String, Object?>{
              'rounds': _raidFastestPlan!.rounds,
              'totalAttacks': _raidFastestPlan!.totalAttacks,
              'totalPlayerPoints': _raidFastestPlan!.totalPlayerPoints,
              'totalKillBonusPoints': _raidFastestPlan!.totalKillBonusPoints,
              'totalGuildPoints': _raidFastestPlan!.totalGuildPoints,
              'recommendedBoard': [
                for (final boss in _raidFastestPlan!.recommendedBoard)
                  <String, Object?>{
                    'level': boss.level,
                    'hp': boss.hp,
                    'killPoints': boss.killBonus,
                  },
              ],
              'bossesKilledByLevel': <String, int>{
                for (final entry in _raidFastestPlan!.bossesKilledByLevel.entries)
                  entry.key.toString(): entry.value,
              },
              'firstRoundAssignments': [
                for (final assignment in _raidFastestPlan!.firstRoundAssignments)
                  <String, Object?>{
                    'slotIndex': assignment.slotIndex,
                    'level': assignment.level,
                    'players': assignment.playerNames,
                    'totalScore': assignment.totalScore,
                  },
              ],
              'firstRoundUnassignedPlayers':
                  _raidFastestPlan!.firstRoundUnassignedPlayers,
              'energy': <String, Object?>{
                'totalAttacks': _raidFastestPlan!.energy.totalAttacks,
                'totalEnergy': _raidFastestPlan!.energy.totalEnergy,
                'totalPaidEnergy': _raidFastestPlan!.energy.totalPaidEnergy,
                'packs40': _raidFastestPlan!.energy.packs40,
                'gems': _raidFastestPlan!.energy.gems,
              },
            },
    };

    final text = const JsonEncoder.withIndent('  ').convert(payload);
    Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          t('raid_guild.export_copied', 'Raid planner export copied'),
        ),
      ),
    );
  }

  Widget _resultRow(
    String label,
    String value, {
    TextStyle? labelStyle,
    bool highlightValue = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: labelStyle),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: highlightValue ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  List<_WarPointValueEntry> _buildPointValueEntries({
    required int activeNormalPoints,
    required int? activePowerPoints,
    required List<ElixirInventoryItem> elixirs,
  }) {
    final entries = <_WarPointValueEntry>[
      _WarPointValueEntry(
        label: activePowerPoints == null
            ? _attackLabel(
                strip: _strip,
                frenzy: _frenzy,
                powerAttack: false,
              )
            : t('war.base.normal', 'Normal'),
        value: activeNormalPoints,
        detail: t('war.point_values.base_chip', 'Base'),
      ),
    ];

    if (activePowerPoints != null) {
      entries.add(
        _WarPointValueEntry(
          label: t('war.power_attack_short', 'PA'),
          value: activePowerPoints,
          detail: t('war.point_values.base_chip', 'Base'),
        ),
      );
    }

    for (final elixir in elixirs) {
      entries.add(
        _WarPointValueEntry(
          label: '${elixir.name} • ${t('war.elixir_normal_short', 'N')}',
          value: boostedWarPoints(
            basePoints: activeNormalPoints,
            scoreMultiplier: elixir.scoreMultiplier,
          ),
          detail: '+${(elixir.scoreMultiplier * 100).round()}%',
          isBoosted: true,
        ),
      );
      if (activePowerPoints != null) {
        entries.add(
          _WarPointValueEntry(
            label: '${elixir.name} • ${t('war.power_attack_short', 'PA')}',
            value: boostedWarPoints(
              basePoints: activePowerPoints,
              scoreMultiplier: elixir.scoreMultiplier,
            ),
            detail: '+${(elixir.scoreMultiplier * 100).round()}%',
            isBoosted: true,
          ),
        );
      }
    }

    return entries;
  }

  _WarElixirScoreSummary _buildElixirScoreSummary({
    required WarPlan plan,
    required int activeNormalPoints,
    required int? activePowerPoints,
  }) {
    var baseScore = 0;
    var boostedScore = 0;

    for (final usage in plan.elixirUsages) {
      if (usage.usedAttacks <= 0) continue;
      final boostedNormalPoints = boostedWarPoints(
        basePoints: activeNormalPoints,
        scoreMultiplier: usage.scoreMultiplier,
      );
      final boostedPaPoints = activePowerPoints == null
          ? 0
          : boostedWarPoints(
              basePoints: activePowerPoints,
              scoreMultiplier: usage.scoreMultiplier,
            );
      baseScore += (usage.boostedNormalAttacks * activeNormalPoints) +
          (usage.boostedPowerAttacks * (activePowerPoints ?? 0));
      boostedScore += (usage.boostedNormalAttacks * boostedNormalPoints) +
          (usage.boostedPowerAttacks * boostedPaPoints);
    }

    return _WarElixirScoreSummary(
      baseScore: baseScore,
      boostedScore: boostedScore,
      bonusScore: boostedScore - baseScore,
    );
  }

  List<String> _buildBestMixBadges({
    required WarPlan plan,
    required bool strip,
    required bool frenzy,
  }) {
    final badges = <String>[];
    if (plan.normalAttacks > 0) {
      badges.add(
        '${_attackLabel(strip: strip, frenzy: frenzy, powerAttack: false)}: '
        '${fmtInt(plan.normalAttacks)}',
      );
    }
    if (plan.powerAttacks > 0) {
      badges.add(
        '${_attackLabel(strip: strip, frenzy: frenzy, powerAttack: true)}: '
        '${fmtInt(plan.powerAttacks)}',
      );
    }
    if (badges.isEmpty) {
      badges.add(t('war.none', '-'));
    }
    return badges;
  }

  int _buildUsageBoostedScore({
    required WarElixirUsage usage,
    required int activeNormalPoints,
    required int? activePowerPoints,
  }) {
    final boostedNormalPoints = boostedWarPoints(
      basePoints: activeNormalPoints,
      scoreMultiplier: usage.scoreMultiplier,
    );
    final boostedPaPoints = activePowerPoints == null
        ? 0
        : boostedWarPoints(
            basePoints: activePowerPoints,
            scoreMultiplier: usage.scoreMultiplier,
          );
    return (usage.boostedNormalAttacks * boostedNormalPoints) +
        (usage.boostedPowerAttacks * boostedPaPoints);
  }

  int _buildUsageBonusScore({
    required WarElixirUsage usage,
    required int activeNormalPoints,
    required int? activePowerPoints,
  }) {
    final baseScore = (usage.boostedNormalAttacks * activeNormalPoints) +
        (usage.boostedPowerAttacks * (activePowerPoints ?? 0));
    return _buildUsageBoostedScore(
          usage: usage,
          activeNormalPoints: activeNormalPoints,
          activePowerPoints: activePowerPoints,
        ) -
        baseScore;
  }

  String _buildAttackSummary({
    required WarPlan plan,
    required bool strip,
    required bool frenzy,
    required bool powerAttack,
  }) {
    if (plan.attacks == 0) return t('war.none', '-');

    final parts = <String>[];
    final attackWord = t('war.attacks_word', 'attacchi');
    final normalLabel = _attackLabel(
      strip: strip,
      frenzy: frenzy,
      powerAttack: false,
    );
    final powerLabel = _attackLabel(
      strip: strip,
      frenzy: frenzy,
      powerAttack: powerAttack,
    );

    if (plan.normalAttacks > 0) {
      parts.add('${fmtInt(plan.normalAttacks)} $attackWord $normalLabel');
    }
    if (plan.powerAttacks > 0) {
      parts.add('${fmtInt(plan.powerAttacks)} $attackWord $powerLabel');
    }

    return parts.join(' + ');
  }

  String _attackLabel({
    required bool strip,
    required bool frenzy,
    required bool powerAttack,
  }) {
    final parts = <String>[];
    if (strip) {
      parts.add(t('war.strip', 'Strip'));
    } else {
      parts.add(t('war.base.normal', 'Normale'));
    }
    if (frenzy) {
      parts.add(t('war.frenzy', 'Frenzy'));
    }
    if (powerAttack) {
      parts.add(t('war.power_attack_short', 'PA'));
    }
    return parts.join(' ');
  }

  String _buildGemSummary(WarGemPlan gems) {
    if (gems.gems == 0) return t('war.no_packs', 'Nessun pacchetto');
    final parts = <String>[];
    _addPackSummary(parts, gems.packs4, 4);
    _addPackSummary(parts, gems.packs20, 20);
    _addPackSummary(parts, gems.packs40, 40);
    return parts.isEmpty
        ? t('war.no_packs', 'Nessun pacchetto')
        : parts.join(' + ');
  }

  String _warStrategyLabel(WarAttackStrategy strategy) {
    return switch (strategy) {
      WarAttackStrategy.normalOnly =>
        t('war.attack_strategy.normal_only', 'Normal only'),
      WarAttackStrategy.optimizedMix =>
        t('war.attack_strategy.optimized_mix', 'Optimized mix'),
      WarAttackStrategy.powerAttackOnly =>
        t('war.attack_strategy.power_attack_only', 'Only PAs'),
      WarAttackStrategy.fixedPowerAttacks => t(
          'war.attack_strategy.fixed_power_attacks',
          'Fixed PAs',
        ),
    };
  }

  String _buildSelectedPointsSummary({
    required int basePoints,
    required int frenzyPoints,
    required int paPoints,
    required int frenzyPaPoints,
    required bool strip,
    required bool frenzy,
    required bool powerAttack,
  }) {
    final steps = <String>[];
    final normalBaseLabel =
        strip ? t('war.strip', 'Strip') : t('war.base.normal', 'Normal');

    steps.add('${fmtInt(basePoints)} $normalBaseLabel');

    if (frenzy) {
      steps.add(
        '${fmtInt(frenzyPoints)} $normalBaseLabel ${t('war.frenzy', 'Frenzy')}',
      );
    }

    if (powerAttack) {
      final paValue = frenzy ? frenzyPaPoints : paPoints;
      final paLabel = frenzy
          ? '$normalBaseLabel ${t('war.frenzy', 'Frenzy')} ${t('war.power_attack_short', 'PA')}'
          : '$normalBaseLabel ${t('war.power_attack_short', 'PA')}';
      steps.add('${fmtInt(paValue)} $paLabel');
    }

    return steps.join(' -> ');
  }

  void _addPackSummary(List<String> parts, int count, int energy) {
    if (count <= 0) return;
    final packWord = count == 1
        ? t('war.pack_singular', 'pacchetto')
        : t('war.pack_plural', 'pacchetti');
    final ofWord = t('war.pack_of', 'da');
    final energyWord = t('war.energy_unit', 'energie');
    parts.add('$count $packWord $ofWord $energy $energyWord');
  }
}

class _WarElixirItem {
  final ElixirConfig config;
  final TextEditingController qty;
  int qtyValue;

  _WarElixirItem({
    required this.config,
    required this.qty,
    required this.qtyValue,
  });
}

class _WarElixirRow extends StatelessWidget {
  final _WarElixirItem item;
  final bool running;
  final String qtyHint;
  final String deleteTooltip;
  final String attacksLabel;
  final VoidCallback onRemove;

  const _WarElixirRow({
    required this.item,
    required this.running,
    required this.qtyHint,
    required this.deleteTooltip,
    required this.attacksLabel,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bonusPct = (item.config.scoreMultiplier * 100).toStringAsFixed(0);
    final attacks = item.config.durationMinutes;
    final theme = Theme.of(context);
    final textStyle = theme.textTheme.bodySmall;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.config.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _WarMetaPill(text: '+$bonusPct%'),
                    _WarMetaPill(text: '$attacks $attacksLabel'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 58,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(qtyHint, style: textStyle),
                    const SizedBox(height: 4),
                    TextField(
                      controller: item.qty,
                      enabled: !running,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 2),
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  padding: EdgeInsets.zero,
                  tooltip: deleteTooltip,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: running ? null : onRemove,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarSummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _WarSummaryTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WarPointValueEntry {
  final String label;
  final int value;
  final String detail;
  final bool isBoosted;

  const _WarPointValueEntry({
    required this.label,
    required this.value,
    required this.detail,
    this.isBoosted = false,
  });
}

class _WarElixirScoreSummary {
  final int baseScore;
  final int boostedScore;
  final int bonusScore;

  const _WarElixirScoreSummary({
    required this.baseScore,
    required this.boostedScore,
    required this.bonusScore,
  });
}

class _WarPointValuesPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_WarPointValueEntry> entries;

  const _WarPointValuesPanel({
    required this.title,
    required this.subtitle,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color:
            theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: entries
                .map(
                  (entry) => Container(
                    width: 132,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fmtInt(entry.value),
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: entry.isBoosted
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        _WarMetaPill(
                          text: entry.detail,
                          highlighted: entry.isBoosted,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _WarMetaPill extends StatelessWidget {
  final String text;
  final bool highlighted;

  const _WarMetaPill({
    required this.text,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: highlighted
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.28)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: highlighted
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
