import 'package:flutter/material.dart';

import '../../core/element_types.dart';
import '../../data/favorites_limits.dart';
import '../../data/wargear_favorites_storage.dart';
import '../../data/wargear_universal_scoring.dart';
import '../../data/wargear_wardrobe_loader.dart';
import '../../data/wargear_wardrobe_sheet_storage.dart';
import '../theme_helpers.dart';
import '../widgets.dart';
import 'element_selector.dart';
import 'home_state.dart';

enum WargearImportTargetKind {
  knight,
  friend,
}

class WargearImportTarget {
  final WargearImportTargetKind kind;
  final int index;
  final String label;

  const WargearImportTarget({
    required this.kind,
    required this.index,
    required this.label,
  });

  String get id => '${kind.name}-$index';
}

class WargearWardrobeSelection implements WargearWardrobeSelectionLike {
  final WargearWardrobeEntry entry;
  final WargearRole role;
  final WargearGuildRank rank;
  final bool plus;
  final WargearStats stats;

  const WargearWardrobeSelection({
    required this.entry,
    required this.role,
    required this.rank,
    required this.plus,
    required this.stats,
  });

  String get displayName => entry.displayName(plus: plus);
  @override
  String get entryId => entry.id;

  @override
  List<ElementType> get elements => entry.elements;
}

class WargearWardrobeImportResult {
  final WargearImportTarget target;
  final WargearWardrobeSelection selection;

  const WargearWardrobeImportResult({
    required this.target,
    required this.selection,
  });
}

enum _WargearWardrobeSortMode {
  season,
  score,
}

class WargearWardrobeSheet extends StatefulWidget {
  final String Function(String key, String fallback) t;
  final List<WargearImportTarget> availableTargets;
  final WargearImportTarget? initialTarget;
  final bool favoritesOnlyMode;
  final bool isPremium;
  final Map<ElementType, int> guildElementBonuses;
  final ValueChanged<Map<ElementType, int>>? onGuildElementBonusesChanged;
  final WargearUniversalScoreContext Function(WargearImportTarget target)?
      scoreContextBuilder;
  final WargearUniversalScoreVariant scoreVariant;

  const WargearWardrobeSheet({
    super.key,
    required this.t,
    required this.availableTargets,
    this.initialTarget,
    this.favoritesOnlyMode = false,
    this.isPremium = false,
    this.guildElementBonuses = const <ElementType, int>{},
    this.onGuildElementBonusesChanged,
    this.scoreContextBuilder,
    this.scoreVariant = WargearUniversalScoreVariant.armorOnly,
  });

  @override
  State<WargearWardrobeSheet> createState() => _WargearWardrobeSheetState();
}

class _WargearWardrobeSheetState extends State<WargearWardrobeSheet> {
  static const List<ElementType?> _elementCycle = <ElementType?>[
    null,
    ElementType.fire,
    ElementType.spirit,
    ElementType.earth,
    ElementType.air,
    ElementType.water,
    ElementType.starmetal,
  ];

  String _query = '';
  String? _seasonFilter;
  ElementType? _firstElementFilter;
  ElementType? _secondElementFilter;
  WargearRole _role = WargearRole.primary;
  WargearGuildRank _rank = WargearGuildRank.commander;
  bool _plus = false;
  bool _favoritesOnly = false;
  bool _filtersVisible = true;
  Set<String> _favoriteIds = <String>{};
  bool _favoritesLoaded = false;
  final TextEditingController _searchController = TextEditingController();
  late Map<ElementType, int> _guildElementBonuses;
  late WargearImportTarget _selectedTarget;
  late _WargearWardrobeSortMode _sortMode;

  bool get _showsScores => widget.scoreContextBuilder != null;
  bool get _favoritesOnlyActive => widget.favoritesOnlyMode || _favoritesOnly;

  @override
  void initState() {
    super.initState();
    _selectedTarget = widget.initialTarget ?? widget.availableTargets.first;
    _guildElementBonuses =
        normalizeWargearGuildElementBonuses(widget.guildElementBonuses);
    _sortMode = _showsScores
        ? _WargearWardrobeSortMode.score
        : _WargearWardrobeSortMode.season;
    _loadFavorites();
    _loadSavedFilters();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final ids = await WargearFavoritesStorage.load();
    if (!mounted) return;
    setState(() {
      _favoriteIds = ids;
      _favoritesLoaded = true;
    });
  }

  Future<void> _loadSavedFilters() async {
    final saved = await WargearWardrobeSheetStorage.load();
    if (!mounted || saved.isEmpty) return;

    final savedFirst = saved['firstElement'] as String?;
    final savedSecond = saved['secondElement'] as String?;
    final savedRole = saved['role'] as String?;
    final savedRank = saved['rank'] as String?;
    final savedSortMode = saved['sortMode'] as String?;

    setState(() {
      final savedSeasonFilter = (saved['seasonFilter'] as String?)?.trim();
      _seasonFilter = (savedSeasonFilter == null || savedSeasonFilter.isEmpty)
          ? null
          : _seasonFilterBucket(savedSeasonFilter);
      _firstElementFilter = _decodeElement(savedFirst, allowStarmetal: true);
      _secondElementFilter = _decodeElement(savedSecond, allowStarmetal: true);
      _role = WargearRole.values.firstWhere(
        (value) => value.name == savedRole,
        orElse: () => WargearRole.primary,
      );
      _rank = WargearGuildRank.values.firstWhere(
        (value) => value.name == savedRank,
        orElse: () => WargearGuildRank.commander,
      );
      _plus = saved['plus'] == true;
      _favoritesOnly = saved['favoritesOnly'] == true;
      _filtersVisible = saved['filtersVisible'] != false;
      final loadedSortMode = _WargearWardrobeSortMode.values.firstWhere(
        (value) => value.name == savedSortMode,
        orElse: () => _showsScores
            ? _WargearWardrobeSortMode.score
            : _WargearWardrobeSortMode.season,
      );
      _sortMode =
          !_showsScores && loadedSortMode == _WargearWardrobeSortMode.score
              ? _WargearWardrobeSortMode.season
              : loadedSortMode;
    });
  }

  bool _matches(WargearWardrobeEntry entry) {
    if (_favoritesOnlyActive && !_favoriteIds.contains(entry.id)) {
      return false;
    }

    if (_plus && !entry.supportsPlus) {
      return false;
    }

    final q = _query.trim().toLowerCase();
    final searchable = <String>[
      entry.name.toLowerCase(),
      entry.seasonTag.toLowerCase(),
    ].join(' ');
    if (q.isNotEmpty && !searchable.contains(q)) {
      return false;
    }

    final seasonFilter = _seasonFilter;
    if (seasonFilter != null &&
        _seasonFilterBucket(entry.seasonTag) !=
            _seasonFilterBucket(seasonFilter)) {
      return false;
    }

    final firstFilter = _firstElementFilter;
    if (firstFilter != null && entry.elements.first != firstFilter) {
      return false;
    }

    final secondFilter = _secondElementFilter;
    if (secondFilter != null && entry.elements.length < 2) {
      return false;
    }
    if (secondFilter != null && entry.elements[1] != secondFilter) {
      return false;
    }

    return true;
  }

  void _cycleFirstElement() {
    setState(() {
      _firstElementFilter = _nextElement(_firstElementFilter);
    });
    _persistFilters();
  }

  void _cycleSecondElement() {
    setState(() {
      _secondElementFilter = _nextElement(_secondElementFilter);
    });
    _persistFilters();
  }

  void _setSeasonFilter(String? value) {
    setState(() {
      _seasonFilter = value;
    });
    _persistFilters();
  }

  void _cycleRole() {
    setState(() {
      _role = _role == WargearRole.primary
          ? WargearRole.secondary
          : WargearRole.primary;
    });
    _persistFilters();
  }

  void _cycleRank() {
    final values = WargearGuildRank.values;
    final index = values.indexOf(_rank);
    setState(() {
      _rank = values[(index + 1) % values.length];
    });
    _persistFilters();
  }

  void _cycleGuildElementBonus(ElementType element) {
    setState(() {
      final current = _guildElementBonuses[element] ?? 10;
      _guildElementBonuses[element] = (current + 1) % 11;
    });
    widget.onGuildElementBonusesChanged?.call(
      Map<ElementType, int>.unmodifiable(_guildElementBonuses),
    );
  }

  void _cycleSortMode() {
    setState(() {
      _sortMode = _sortMode == _WargearWardrobeSortMode.season
          ? _WargearWardrobeSortMode.score
          : _WargearWardrobeSortMode.season;
    });
    _persistFilters();
  }

  void _toggleFavoritesOnly(bool value) {
    if (widget.favoritesOnlyMode) return;
    setState(() => _favoritesOnly = value);
    _persistFilters();
  }

  void _toggleFiltersVisible() {
    setState(() => _filtersVisible = !_filtersVisible);
    _persistFilters();
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _seasonFilter = null;
      _firstElementFilter = null;
      _secondElementFilter = null;
      _role = WargearRole.primary;
      _rank = WargearGuildRank.commander;
      _plus = false;
      _favoritesOnly = false;
      _filtersVisible = true;
    });
    _persistFilters();
  }

  ElementType? _decodeElement(String? raw, {required bool allowStarmetal}) {
    if (raw == null || raw.isEmpty) return null;
    ElementType? element;
    for (final value in ElementType.values) {
      if (value.id == raw) {
        element = value;
        break;
      }
    }
    if (element == null) return null;
    if (!allowStarmetal && element == ElementType.starmetal) return null;
    return element;
  }

  Future<void> _persistFilters() {
    return WargearWardrobeSheetStorage.save(<String, Object?>{
      'seasonFilter': _seasonFilter,
      'firstElement': _firstElementFilter?.id,
      'secondElement': _secondElementFilter?.id,
      'role': _role.name,
      'rank': _rank.name,
      'plus': _plus,
      'favoritesOnly': _favoritesOnly,
      'filtersVisible': _filtersVisible,
      'sortMode': _sortMode.name,
    });
  }

  Future<void> _toggleFavorite(WargearWardrobeEntry entry) async {
    final isFavorite = _favoriteIds.contains(entry.id);
    if (!isFavorite &&
        !canAddFavorite(
          isPremium: widget.isPremium,
          currentCount: _favoriteIds.length,
          freeLimit: freeFavoriteArmorsLimit,
          premiumLimit: premiumFavoriteArmorsLimit,
        )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget
                .t(
                  'wargear.favorites.limit.reached',
                  'Free users can save up to {limit} favorite armors. You are at {count}/{limit}. Premium unlocks up to {premiumLimit} favorite armors.',
                )
                .replaceAll('{count}', _favoriteIds.length.toString())
                .replaceAll('{limit}', freeFavoriteArmorsLimit.toString())
                .replaceAll(
                  '{premiumLimit}',
                  premiumFavoriteArmorsLimit.toString(),
                ),
          ),
        ),
      );
      return;
    }
    setState(() {
      final next = Set<String>.from(_favoriteIds);
      if (isFavorite) {
        next.remove(entry.id);
      } else {
        next.add(entry.id);
      }
      _favoriteIds = next;
    });

    await WargearFavoritesStorage.save(_favoriteIds);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget
              .t(
                isFavorite
                    ? 'wargear.favorite.removed'
                    : 'wargear.favorite.added',
                isFavorite
                    ? '{name} removed from favorite armors.'
                    : '{name} added to favorite armors.',
              )
              .replaceAll('{name}', entry.displayName(plus: false)),
        ),
      ),
    );
  }

  ElementType? _nextElement(ElementType? current) {
    final index = _elementCycle.indexOf(current);
    if (index < 0) return _elementCycle.first;
    return _elementCycle[(index + 1) % _elementCycle.length];
  }

  int _seasonSortValue(String seasonTag) {
    final normalized = seasonTag.trim().toUpperCase();
    if (normalized.isEmpty) return -1;
    final match = RegExp(r'(\d+)').firstMatch(normalized);
    final number = match == null ? -1 : (int.tryParse(match.group(1)!) ?? -1);
    if (normalized.startsWith('S')) return 100000 + number;
    if (normalized.startsWith('UA')) return 50000 + number;
    return number;
  }

  String _seasonFilterBucket(String seasonTag) {
    final normalized = seasonTag.trim().toUpperCase();
    if (normalized.isEmpty) return normalized;
    if (normalized.startsWith('S')) {
      final match = RegExp(r'^S(\d+)').firstMatch(normalized);
      if (match != null) {
        final number = match.group(1)!;
        return 'S$number';
      }
    }
    return normalized;
  }

  WargearWardrobeSelection _selectionFor(WargearWardrobeEntry entry) {
    return WargearWardrobeSelection(
      entry: entry,
      role: _role,
      rank: _rank,
      plus: _plus,
      stats: entry.resolveStats(
        role: _role,
        rank: _rank,
        plus: _plus,
        guildElementBonuses: _guildElementBonuses,
      ),
    );
  }

  WargearStats _finalStatsFor(WargearWardrobeSelection selection) {
    final context = widget.scoreContextBuilder?.call(_selectedTarget);
    if (context == null) {
      return selection.stats;
    }
    final petMatchCount = _petArmorBonusMatchCount(
      armorElements: selection.elements,
      petElements: context.petElements,
    );
    return WargearStats(
      attack:
          selection.stats.attack + (context.petElementalAttack * petMatchCount),
      defense: selection.stats.defense +
          (context.petElementalDefense * petMatchCount),
      health: selection.stats.health,
    );
  }

  int _petArmorBonusMatchCount({
    required List<ElementType> armorElements,
    required List<ElementType> petElements,
  }) {
    if (petElements.isEmpty) return 0;
    final petFirst = petElements[0];
    final petSecond = petElements.length > 1 ? petElements[1] : null;

    if (petSecond == null) {
      return armorElements.contains(petFirst) ? 1 : 0;
    }

    if (petSecond == petFirst) {
      final armorFirst = armorElements[0];
      final armorSecond = armorElements[1];
      if (armorFirst == petFirst && armorSecond == petFirst) {
        return 2;
      }
      if (armorSecond == petFirst) return 2;
      if (armorFirst == petFirst) return 1;
      return 0;
    }

    if (armorElements[0] == petFirst && armorElements[1] == petSecond) {
      return 2;
    }
    return armorElements.contains(petFirst) ? 1 : 0;
  }

  WargearUniversalScoreResult? _scoreSelection(
      WargearWardrobeSelection selection) {
    final context = widget.scoreContextBuilder?.call(_selectedTarget);
    if (context == null) return null;
    final engine = const WargearUniversalScoringEngine();
    return engine.score(
      stats: _finalStatsFor(selection),
      armorElements: selection.elements,
      context: context,
      variant: widget.scoreVariant,
    );
  }

  Widget _chip(BuildContext context, String label) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _elementChip(BuildContext context, ElementType element) {
    final theme = Theme.of(context);
    final base = elementColor(element);
    final textColor =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark
            ? Colors.white
            : Colors.black;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: base,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        elementLabel(element, widget.t),
        style: theme.textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _cycleButton({
    required Key key,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _toggleButton({
    required Key key,
    required String label,
    required bool selected,
    required VoidCallback onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    return OutlinedButton(
      key: key,
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: selected ? cs.onPrimaryContainer : null,
        backgroundColor:
            selected ? cs.primaryContainer.withValues(alpha: 0.82) : null,
        side: BorderSide(
          color: selected ? cs.primary.withValues(alpha: 0.9) : cs.outline,
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _seasonMenuButton(List<String> options) {
    final t = widget.t;
    return PopupMenuButton<String?>(
      key: const ValueKey('wargear-season-menu'),
      tooltip: '',
      initialValue: _seasonFilter,
      onSelected: _setSeasonFilter,
      itemBuilder: (context) => <PopupMenuEntry<String?>>[
        PopupMenuItem<String?>(
          value: null,
          child: Text(t('all', 'All')),
        ),
        ...options.map(
          (season) => PopupMenuItem<String?>(
            value: season,
            child: Text(season),
          ),
        ),
      ],
      child: IgnorePointer(
        child: _cycleButton(
          key: const ValueKey('wargear-cycle-season'),
          label:
              '${t('wargear.season.short', 'Season')}: ${_seasonFilter ?? t('all', 'All')}',
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _guildBonusButton(BuildContext context, ElementType element) {
    final theme = Theme.of(context);
    final color = elementColor(element);
    final bonus = _guildElementBonuses[element] ?? 10;
    return OutlinedButton(
      key: ValueKey('wargear-guild-bonus-${element.id}'),
      onPressed: () => _cycleGuildElementBonus(element),
      style: OutlinedButton.styleFrom(
        foregroundColor:
            ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                ? Colors.white
                : Colors.black,
        side: BorderSide(color: color.withValues(alpha: 0.8)),
        backgroundColor: color.withValues(alpha: 0.18),
      ),
      child: Text(
        '${elementLabel(element, widget.t)} $bonus%',
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  String _roleLabel(WargearRole role) {
    return switch (role) {
      WargearRole.primary => widget.t('wargear.role.primary.short', 'Primary'),
      WargearRole.secondary =>
        widget.t('wargear.role.secondary.short', 'Secondary'),
    };
  }

  String _roleLongLabel(WargearRole role) {
    return switch (role) {
      WargearRole.primary => widget.t('wargear.role.primary', 'Primary knight'),
      WargearRole.secondary =>
        widget.t('wargear.role.secondary', 'Secondary knight'),
    };
  }

  String _rankShortLabel(WargearGuildRank rank) {
    return switch (rank) {
      WargearGuildRank.commander =>
        widget.t('wargear.rank.commander.short', 'Comm'),
      WargearGuildRank.highCommander =>
        widget.t('wargear.rank.high_commander.short', 'HC'),
      WargearGuildRank.gcGs => widget.t('wargear.rank.gc_gs', 'GS / GC'),
      WargearGuildRank.guildMaster =>
        widget.t('wargear.rank.guild_master.short', 'GM'),
    };
  }

  String _firstElementLabel(ElementType? element) {
    if (element == null) return widget.t('pet_compendium.filter.all', 'All');
    return elementLabel(element, widget.t);
  }

  Widget _favoritesLimitBanner(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      key: const ValueKey('wargear-favorites-limit-banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.star_outline, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget
                  .t(
                    'wargear.favorites.limit.message',
                    'Favorite armors: {count}/{limit}. Premium unlocks up to {premiumLimit} favorite armors.',
                  )
                  .replaceAll('{count}', _favoriteIds.length.toString())
                  .replaceAll('{limit}', freeFavoriteArmorsLimit.toString())
                  .replaceAll(
                    '{premiumLimit}',
                    premiumFavoriteArmorsLimit.toString(),
                  ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = widget.t;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FutureBuilder<WargearWardrobeCatalog>(
          future: WargearWardrobeLoader.load(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !_favoritesLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data!.armors.where(_matches).map((entry) {
              final selection = _selectionFor(entry);
              return _WargearWardrobeEntryView(
                entry: entry,
                selection: selection,
                finalStats: _finalStatsFor(selection),
                score: _scoreSelection(selection),
              );
            }).toList(growable: false);

            final seasonOptions = snapshot.data!.armors
                .map((entry) => _seasonFilterBucket(entry.seasonTag))
                .where((tag) => tag.trim().isNotEmpty)
                .toSet()
                .toList(growable: false)
              ..sort(
                  (a, b) => _seasonSortValue(b).compareTo(_seasonSortValue(a)));

            items.sort((a, b) {
              if (_sortMode == _WargearWardrobeSortMode.score &&
                  a.score != null &&
                  b.score != null) {
                final byScore = b.score!.score.compareTo(a.score!.score);
                if (byScore != 0) return byScore;
              }
              final bySeason = _seasonSortValue(b.entry.seasonTag)
                  .compareTo(_seasonSortValue(a.entry.seasonTag));
              if (bySeason != 0) return bySeason;
              return a.entry.name.compareTo(b.entry.name);
            });

            final title = widget.favoritesOnlyMode
                ? t('wargear.favorites.title', 'Favorite armors')
                : t('wargear.title', 'Wargear Wardrobe');
            final subtitle = widget.favoritesOnlyMode
                ? t(
                    'wargear.favorites.subtitle',
                    'Quickly insert your saved armors using the current role, rank and plus filters.',
                  )
                : t(
                    'wargear.subtitle',
                    'Browse saved maxed armor sets, filter them quickly, then import the resolved stats and elements into the selected slot.',
                  );
            final scoreSubtitle = _showsScores
                ? t(
                    'wargear.score.subtitle',
                    'Scores use the current boss, pet and guild context.',
                  )
                : null;

            return ListView(
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (scoreSubtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    scoreSubtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  t(
                    'wargear.thanks',
                    'Big thanks to Kasper534 for the help gathering all the data.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                if (!widget.isPremium) ...[
                  _favoritesLimitBanner(context),
                  const SizedBox(height: 12),
                ],
                if (widget.availableTargets.length > 1) ...[
                  Text(
                    t('wargear.target', 'Import target'),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: themedLabelColor(theme),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final target in widget.availableTargets)
                        ChoiceChip(
                          key: ValueKey('wargear-target-${target.id}'),
                          label: Text(target.label),
                          selected: _selectedTarget.id == target.id,
                          onSelected: (_) =>
                              setState(() => _selectedTarget = target),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  _chip(
                    context,
                    t(
                      'wargear.target.single',
                      'Importing into {target}',
                    ).replaceAll('{target}', _selectedTarget.label),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  key: const ValueKey('wargear-search-field'),
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    hintText: t(
                      'wargear.search',
                      'Search armor by name...',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t('wargear.filters.title', 'Filters'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: themedLabelColor(theme),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.end,
                        children: [
                          TextButton(
                            key: const ValueKey('wargear-toggle-filters'),
                            onPressed: _toggleFiltersVisible,
                            child: Text(
                              _filtersVisible
                                  ? t('wargear.filters.hide', 'Hide filters')
                                  : t('wargear.filters.show', 'Show filters'),
                            ),
                          ),
                          TextButton.icon(
                            key: const ValueKey('wargear-clear-filters'),
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.filter_alt_off_outlined),
                            label: Text(
                              t('wargear.filter.clear', 'Clear all filters'),
                            ),
                          ),
                        ],
                      ),
                      if (_filtersVisible) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _cycleButton(
                              key:
                                  const ValueKey('wargear-cycle-first-element'),
                              label:
                                  '${t('wargear.element.first', '1st')}: ${_firstElementLabel(_firstElementFilter)}',
                              onPressed: _cycleFirstElement,
                            ),
                            _cycleButton(
                              key: const ValueKey(
                                  'wargear-cycle-second-element'),
                              label:
                                  '${t('wargear.element.second', '2nd')}: ${_firstElementLabel(_secondElementFilter)}',
                              onPressed: _cycleSecondElement,
                            ),
                            _seasonMenuButton(seasonOptions),
                            if (!widget.favoritesOnlyMode)
                              _toggleButton(
                                key: const ValueKey(
                                  'wargear-favorites-only-filter',
                                ),
                                label: t(
                                  'wargear.filter.favorites_only',
                                  'Favorites only',
                                ),
                                selected: _favoritesOnly,
                                onPressed: () =>
                                    _toggleFavoritesOnly(!_favoritesOnly),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          t('wargear.modifiers.title', 'Modifiers'),
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: themedLabelColor(theme),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _cycleButton(
                              key: const ValueKey('wargear-cycle-rank'),
                              label:
                                  '${t('wargear.guild_rank.short', 'Rank')}: ${_rankShortLabel(_rank)}',
                              onPressed: _cycleRank,
                            ),
                            _cycleButton(
                              key: const ValueKey('wargear-cycle-role'),
                              label:
                                  '${t('wargear.role.short', 'Role')}: ${_roleLabel(_role)}',
                              onPressed: _cycleRole,
                            ),
                            _cycleButton(
                              key: const ValueKey('wargear-cycle-plus'),
                              label: _plus
                                  ? t('wargear.plus.short.on', 'Version: +')
                                  : t('wargear.plus.short.off',
                                      'Version: Base'),
                              onPressed: () {
                                setState(() => _plus = !_plus);
                                _persistFilters();
                              },
                            ),
                            if (_showsScores)
                              _cycleButton(
                                key: const ValueKey('wargear-cycle-sort'),
                                label: _sortMode ==
                                        _WargearWardrobeSortMode.score
                                    ? t('wargear.sort.score', 'Sort: Score')
                                    : t('wargear.sort.season', 'Sort: Season'),
                                onPressed: _cycleSortMode,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  t('wargear.guild_bonuses', 'Guild element bonuses'),
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: themedLabelColor(theme),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'wargear.guild_bonuses.tip',
                    'Tap an element to cycle its guild bonus from 0% to 10%. The first armor element uses the ring bonus, the second uses the amulet bonus.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final element in wargearGuildBonusElements)
                      _guildBonusButton(context, element),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  t('wargear.results', '{count} armor sets found')
                      .replaceAll('{count}', items.length.toString()),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: themedLabelColor(theme),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                if (_favoritesOnlyActive && _favoriteIds.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      t(
                        'wargear.favorites.empty',
                        'No favorite armors yet. Star an armor in the Wargear Wardrobe to see it here.',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      _favoritesOnlyActive
                          ? t(
                              'wargear.favorites.no_results',
                              'No favorite armors match the current search.',
                            )
                          : t(
                              'wargear.no_results',
                              'No armor set matches the current filters.',
                            ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (int index = 0; index < items.length; index++) ...[
                    if (index != 0) const SizedBox(height: 8),
                    Builder(
                      builder: (context) {
                        final item = items[index];
                        final entry = item.entry;
                        final selection = item.selection;
                        final isFavorite = _favoriteIds.contains(entry.id);
                        return CompactCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text(
                                      selection.displayName,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    key: ValueKey(
                                      'wargear-favorite-${entry.id}',
                                    ),
                                    tooltip: t(
                                      isFavorite
                                          ? 'wargear.favorite.remove'
                                          : 'wargear.favorite.add',
                                      isFavorite
                                          ? 'Remove from favorite armors'
                                          : 'Add to favorite armors',
                                    ),
                                    onPressed: () => _toggleFavorite(entry),
                                    icon: Icon(
                                      isFavorite
                                          ? Icons.star
                                          : Icons.star_outline,
                                      color: isFavorite ? cs.primary : null,
                                    ),
                                  ),
                                  FilledButton.tonalIcon(
                                    key: ValueKey(
                                      'wargear-apply-${entry.id}',
                                    ),
                                    onPressed: () => Navigator.of(context).pop(
                                      WargearWardrobeImportResult(
                                        target: _selectedTarget,
                                        selection: selection,
                                      ),
                                    ),
                                    icon: const Icon(Icons.upload_outlined),
                                    label: Text(
                                      t('wargear.use', 'Use armor'),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (entry.seasonTag.isNotEmpty)
                                    _chip(context, entry.seasonTag),
                                  for (final element in selection.elements)
                                    _elementChip(
                                      context,
                                      element,
                                    ),
                                  _chip(
                                    context,
                                    _roleLongLabel(_role),
                                  ),
                                  _chip(
                                    context,
                                    _rankShortLabel(_rank),
                                  ),
                                  if (item.score != null)
                                    _chip(
                                      context,
                                      '${t('wargear.universal_scoring.short', 'UAS')}: ${HomeState.formatIntUs(item.score!.score.round())}',
                                    ),
                                  _chip(
                                    context,
                                    '${t('atk', 'ATK')}: ${HomeState.formatIntUs(item.finalStats.attack)}',
                                  ),
                                  _chip(
                                    context,
                                    '${t('def', 'DEF')}: ${HomeState.formatIntUs(item.finalStats.defense)}',
                                  ),
                                  _chip(
                                    context,
                                    '${t('hp', 'HP')}: ${HomeState.formatIntUs(item.finalStats.health)}',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _WargearWardrobeEntryView {
  final WargearWardrobeEntry entry;
  final WargearWardrobeSelection selection;
  final WargearStats finalStats;
  final WargearUniversalScoreResult? score;

  const _WargearWardrobeEntryView({
    required this.entry,
    required this.selection,
    required this.finalStats,
    required this.score,
  });
}
