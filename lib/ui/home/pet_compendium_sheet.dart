import 'package:flutter/material.dart';

import '../../core/element_types.dart';
import '../../data/favorites_limits.dart';
import '../../data/pet_favorites_storage.dart';
import '../../data/pet_compendium_loader.dart';
import '../../data/pet_skill_definitions_loader.dart';
import '../../util/format.dart';
import 'element_selector.dart';
import '../theme_helpers.dart';
import '../widgets.dart';

enum PetCompendiumViewMode {
  cards,
  table,
}

class PetCompendiumSelection {
  final PetCompendiumEntry family;
  final bool useAltSkillSet;
  final String selectedTierId;
  final String statsProfileId;

  const PetCompendiumSelection({
    required this.family,
    required this.useAltSkillSet,
    required this.selectedTierId,
    required this.statsProfileId,
  });

  PetCompendiumTierVariant get selectedTier =>
      family.tierById(selectedTierId) ?? family.highestTier;
  PetCompendiumStatsProfile get selectedProfile =>
      selectedTier.profileById(statsProfileId) ?? selectedTier.defaultProfile;
  PetCompendiumSkillDetails get selectedSkill1Details =>
      selectedProfile.skillOrFallback(useAltSkillSet ? 'skill12' : 'skill11',
          useAltSkillSet ? selectedTier.skill12 : selectedTier.skill11);
  PetCompendiumSkillDetails get selectedSkill2Details =>
      selectedProfile.skillOrFallback('skill2', selectedTier.skill2);
  String get selectedSkill1 => selectedSkill1Details.name;
  String get selectedSkill2 => selectedSkill2Details.name;
}

class PetCompendiumSheet extends StatefulWidget {
  final String Function(String key, String fallback) t;
  final bool isPremium;

  const PetCompendiumSheet({
    super.key,
    required this.t,
    this.isPremium = false,
  });

  @override
  State<PetCompendiumSheet> createState() => _PetCompendiumSheetState();
}

class _PetCompendiumSheetState extends State<PetCompendiumSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _season;
  String? _rarity;
  String? _tier;
  String? _skillPrimary;
  String? _skillSecondary;
  ElementType? _element;
  bool _favoritesOnly = false;
  bool _filtersCollapsed = true;
  PetCompendiumViewMode _viewMode = PetCompendiumViewMode.cards;
  final Map<String, bool> _useAltSkillSet = <String, bool>{};
  final Map<String, String> _selectedTierId = <String, String>{};
  final Map<String, String> _selectedProfileId = <String, String>{};
  Set<String> _favoriteIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final ids = await PetFavoritesStorage.load();
    if (!mounted) return;
    setState(() => _favoriteIds = ids);
  }

  Future<void> _showCompendiumTip(BuildContext context) {
    final t = widget.t;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t('pet_compendium.tip.title', 'Pet Compendium tip')),
        content: Text(
          [
            t(
              'pet_compendium.subtitle',
              'Browse pets, filter by rarity, tier or skill, and import the selected pet into the Pet section.',
            ),
            t(
              'pet_compendium.thanks',
              'Big thanks to Kasper534 for the help gathering all the data.',
            ),
            t(
              'pet_compendium.tip.body',
              'Search by pet name or skill to find the whole pet family. Cards always open on the highest tier and highest level available. Tap the Tier badge to cycle through the data we have recorded.',
            ),
          ].join('\n\n'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('cancel', 'Close')),
          ),
        ],
      ),
    );
  }

  String _normalizeSkill(String value) {
    final normalized = value
        .toLowerCase()
        .replaceAll('∞', '(inf)')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized
        .replaceAll(
            'special regeneration infinite', 'special regeneration (inf)')
        .replaceAll(
            'special regeneration infinity', 'special regeneration (inf)');
  }

  bool _matches(PetCompendiumEntry family) {
    if (_favoritesOnly && !_isFavorite(family)) return false;
    if (_season != null && family.familyTag != _season) return false;
    if (_rarity != null && family.rarity != _rarity) return false;
    if (_tier != null && !family.containsTier(_tier!)) return false;
    if (_skillPrimary != null) {
      final wanted = _normalizeSkill(_skillPrimary!);
      final hasSkill = family.allSkills.any(
        (skill) => _normalizeSkill(skill) == wanted,
      );
      if (!hasSkill) return false;
    }
    if (_skillSecondary != null) {
      final wanted = _normalizeSkill(_skillSecondary!);
      final hasSkill = family.allSkills.any(
        (skill) => _normalizeSkill(skill) == wanted,
      );
      if (!hasSkill) return false;
    }
    if (_element != null && !family.allElements.contains(_element))
      return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (family.familyTag.toLowerCase().contains(q)) return true;
    if (family.allNames.any((name) => name.toLowerCase().contains(q))) {
      return true;
    }
    return family.allSkills.any((skill) => skill.toLowerCase().contains(q));
  }

  bool _altSelectedFor(PetCompendiumEntry family) =>
      _useAltSkillSet[family.id] ?? false;

  String _tierIdFor(PetCompendiumEntry family) {
    final stored = _selectedTierId[family.id];
    if (stored != null && family.tierById(stored) != null) return stored;
    if (_tier != null) {
      final filtered = family.tierById(_tier!);
      if (filtered != null) return filtered.id;
    }
    return family.highestTier.id;
  }

  PetCompendiumTierVariant _selectedTierFor(PetCompendiumEntry family) =>
      family.tierById(_tierIdFor(family)) ?? family.highestTier;

  String _profileIdFor(PetCompendiumEntry family) =>
      _selectedProfileId[family.id] ??
      _selectedTierFor(family).defaultProfile.id;

  PetCompendiumStatsProfile _selectedProfileFor(PetCompendiumEntry family) =>
      _selectedTierFor(family).profileById(_profileIdFor(family)) ??
      _selectedTierFor(family).defaultProfile;

  void _setAltSelected(PetCompendiumEntry family, bool value) {
    setState(() => _useAltSkillSet[family.id] = value);
  }

  void _setTierSelected(PetCompendiumEntry family, String tierId) {
    final tier = family.tierById(tierId);
    if (tier == null) return;
    setState(() {
      _selectedTierId[family.id] = tier.id;
      final currentProfileId = _selectedProfileId[family.id];
      if (currentProfileId == null ||
          tier.profileById(currentProfileId) == null) {
        _selectedProfileId[family.id] = tier.defaultProfile.id;
      }
    });
  }

  void _setProfileSelected(PetCompendiumEntry family, String profileId) {
    setState(() => _selectedProfileId[family.id] = profileId);
  }

  void _cycleTier(PetCompendiumEntry family) {
    final sortedTiers = family.tiers.toList(growable: false)
      ..sort((a, b) => PetCompendiumTierVariant.tierRank(b.tier)
          .compareTo(PetCompendiumTierVariant.tierRank(a.tier)));
    if (sortedTiers.isEmpty) return;
    final currentTierId = _tierIdFor(family);
    final currentIndex =
        sortedTiers.indexWhere((tier) => tier.id == currentTierId);
    final nextTier = sortedTiers[
        ((currentIndex < 0 ? 0 : currentIndex) + 1) % sortedTiers.length];
    _setTierSelected(family, nextTier.id);
  }

  void _cycleProfile(PetCompendiumEntry family) {
    final tier = _selectedTierFor(family);
    if (tier.profiles.isEmpty) return;
    final sortedProfiles = tier.profiles.toList(growable: false)
      ..sort((a, b) => b.level.compareTo(a.level));
    final currentProfileId = _profileIdFor(family);
    final currentIndex = sortedProfiles.indexWhere(
      (profile) => profile.id == currentProfileId,
    );
    final nextProfile = sortedProfiles[
        ((currentIndex < 0 ? 0 : currentIndex) + 1) % sortedProfiles.length];
    _setProfileSelected(family, nextProfile.id);
  }

  void _applySkillFilter(String skill) {
    setState(() {
      if (_skillPrimary == null) {
        _skillPrimary = skill;
        return;
      }
      if (_normalizeSkill(_skillPrimary!) == _normalizeSkill(skill)) {
        _skillPrimary = skill;
        return;
      }
      _skillSecondary = skill;
    });
  }

  bool _isDisplayableSkillName(String value) =>
      value.trim().isNotEmpty && value.trim().toLowerCase() != 'none';

  bool _isDisplayableSkill(PetCompendiumSkillDetails skill) =>
      _isDisplayableSkillName(skill.name);

  List<PetCompendiumSkillDetails> _visibleSkillsForTier(
    PetCompendiumTierVariant tier,
    PetCompendiumStatsProfile profile,
  ) {
    return <PetCompendiumSkillDetails>[
      profile.skillOrFallback('skill11', tier.skill11),
      profile.skillOrFallback('skill12', tier.skill12),
      profile.skillOrFallback('skill2', tier.skill2),
    ].where(_isDisplayableSkill).toList(growable: false);
  }

  String _skillSetChoiceLabel({
    required String primarySlotLabel,
    required bool hasSkill2,
  }) {
    return hasSkill2 ? '$primarySlotLabel + 2' : primarySlotLabel;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _query = '';
      _season = null;
      _rarity = null;
      _tier = null;
      _skillPrimary = null;
      _skillSecondary = null;
      _element = null;
      _favoritesOnly = false;
    });
  }

  bool get _hasActiveFilters =>
      _query.trim().isNotEmpty ||
      _season != null ||
      _rarity != null ||
      _tier != null ||
      _skillPrimary != null ||
      _skillSecondary != null ||
      _element != null ||
      _favoritesOnly;

  List<String> _activeFilterLabels(String Function(String, String) t) {
    final labels = <String>[];
    final query = _query.trim();
    if (query.isNotEmpty) labels.add('Search: $query');
    if (_favoritesOnly) {
      labels.add(t('pet_compendium.filter.favorites_only', 'Favorites only'));
    }
    if (_season != null) {
      labels.add(
        '${t('pet_compendium.filter.season', 'Season')}: $_season',
      );
    }
    if (_rarity != null) {
      labels.add(
        '${t('pet_compendium.filter.rarity', 'Rarity')}: $_rarity',
      );
    }
    if (_tier != null) {
      labels.add('${t('pet_compendium.filter.tier', 'Tier')}: $_tier');
    }
    if (_element != null) {
      labels.add(
        '${t('pet_compendium.filter.element', 'Element')}: ${elementLabel(_element!, t)}',
      );
    }
    if (_skillPrimary != null) {
      labels.add(
        '${t('pet_compendium.filter.skill_1', 'Skill 1')}: $_skillPrimary',
      );
    }
    if (_skillSecondary != null) {
      labels.add(
        '${t('pet_compendium.filter.skill_2', 'Skill 2')}: $_skillSecondary',
      );
    }
    return labels;
  }

  bool _isFavorite(PetCompendiumEntry family) =>
      _favoriteIds.contains(family.id);

  int _seasonSortValue(String familyTag) {
    final normalized = familyTag.trim().toUpperCase();
    if (normalized.isEmpty) return -1;
    final match = RegExp(r'(\d+)').firstMatch(normalized);
    final number = match == null ? -1 : (int.tryParse(match.group(1)!) ?? -1);
    if (normalized.startsWith('S')) return 100000 + number;
    if (normalized.startsWith('UA')) return 50000 + number;
    return number;
  }

  String _favoritesLimitMessage() {
    return widget
        .t(
          'pet.favorites.limit.message',
          'Favorite pets: {count}/{limit}. Premium unlocks up to {premiumLimit} favorite pets.',
        )
        .replaceAll('{count}', _favoriteIds.length.toString())
        .replaceAll(
          '{limit}',
          (widget.isPremium ? premiumFavoritePetsLimit : freeFavoritePetsLimit)
              .toString(),
        )
        .replaceAll('{premiumLimit}', premiumFavoritePetsLimit.toString());
  }

  void _showFavoritesLimitReached() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget
              .t(
                'pet.favorites.limit.reached',
                'You can save up to {limit} favorite pets. You are at {count}/{limit}.',
              )
              .replaceAll('{count}', _favoriteIds.length.toString())
              .replaceAll(
                '{limit}',
                (widget.isPremium
                        ? premiumFavoritePetsLimit
                        : freeFavoritePetsLimit)
                    .toString(),
              )
              .replaceAll(
                  '{premiumLimit}', premiumFavoritePetsLimit.toString()),
        ),
      ),
    );
  }

  Widget _favoritesLimitBanner(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      key: const ValueKey('pet-favorites-limit-banner'),
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
              _favoritesLimitMessage(),
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

  Future<void> _toggleFavorite(PetCompendiumEntry family) async {
    final alreadyFavorite = _isFavorite(family);
    if (!alreadyFavorite &&
        !canAddFavorite(
          isPremium: widget.isPremium,
          currentCount: _favoriteIds.length,
          freeLimit: freeFavoritePetsLimit,
          premiumLimit: premiumFavoritePetsLimit,
        )) {
      _showFavoritesLimitReached();
      return;
    }
    setState(() {
      final next = Set<String>.from(_favoriteIds);
      if (alreadyFavorite) {
        next.remove(family.id);
      } else {
        next.add(family.id);
      }
      _favoriteIds = next;
    });

    await PetFavoritesStorage.save(_favoriteIds);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget
              .t(
                alreadyFavorite
                    ? 'pet_compendium.favorite.removed'
                    : 'pet_compendium.favorite.added',
                alreadyFavorite
                    ? '{name} removed from favorite pets.'
                    : '{name} added to favorite pets.',
              )
              .replaceAll('{name}', family.highestTier.name),
        ),
      ),
    );
  }

  Widget _favoriteButton(BuildContext context, PetCompendiumEntry family) {
    final selected = _isFavorite(family);
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      key: ValueKey('pet-compendium-favorite-${family.id}'),
      tooltip: widget.t(
        selected
            ? 'pet_compendium.favorite.remove'
            : 'pet_compendium.favorite.add',
        selected ? 'Remove from favorite pets' : 'Add to favorite pets',
      ),
      visualDensity: VisualDensity.compact,
      onPressed: () => _toggleFavorite(family),
      icon: Icon(
        selected ? Icons.star : Icons.star_border,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
    );
  }

  Widget _sectionTitle(
    BuildContext context,
    String label,
  ) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        color: themedLabelColor(theme),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _filterToggleButton({
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
      child: Text(label),
    );
  }

  Widget _filterFieldShell({
    required double width,
    required Widget child,
  }) {
    return SizedBox(
      width: width,
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = widget.t;
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, viewport) {
          final availableHeight = viewport.maxHeight.isFinite
              ? viewport.maxHeight
              : MediaQuery.of(context).size.height;
          final filterPanelMaxHeight =
              (availableHeight * 0.24).clamp(150.0, 250.0);

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: FutureBuilder<List<Object>>(
              future: Future.wait<Object>([
                PetCompendiumLoader.load(rarity: _rarity),
                PetSkillDefinitionsLoader.load(),
              ]),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final payload = snapshot.data ?? const <Object>[];
                if (payload.length < 2) {
                  return const Center(child: CircularProgressIndicator());
                }
                final catalog = payload[0] as PetCompendiumCatalog;
                final skillDefinitions =
                    payload[1] as PetSkillDefinitionsCatalog;
                final pets = catalog.pets;
                final rarityOptions = PetCompendiumLoader.supportedRarities;
                final seasonOptions = pets
                    .map((e) => e.familyTag)
                    .where((tag) => tag.trim().isNotEmpty)
                    .toSet()
                    .toList(growable: false)
                  ..sort((a, b) =>
                      _seasonSortValue(b).compareTo(_seasonSortValue(a)));
                final tierOptions = pets
                    .expand((e) => e.availableTiers)
                    .toSet()
                    .toList(growable: false)
                  ..sort(
                      (a, b) => PetCompendiumTierVariant.tierRank(b).compareTo(
                            PetCompendiumTierVariant.tierRank(a),
                          ));
                final skillOptions = pets
                    .expand((e) => e.allSkills)
                    .toSet()
                    .toList(growable: false)
                  ..sort();
                final filtered = pets.where(_matches).toList(growable: false);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            t('pet_compendium.title', 'Pet Compendium'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('pet-compendium-tip-button'),
                          tooltip: t(
                            'pet_compendium.tip.title',
                            'Pet Compendium tip',
                          ),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints.tightFor(
                            width: 24,
                            height: 24,
                          ),
                          icon: const Icon(Icons.info_outline, size: 18),
                          onPressed: () => _showCompendiumTip(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!widget.isPremium ||
                        _favoriteIds.length >= freeFavoritePetsLimit) ...[
                      _favoritesLimitBanner(context),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            cs.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  t(
                                    'pet_compendium.filters.title',
                                    'Search and filters',
                                  ),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              if (_hasActiveFilters)
                                TextButton(
                                  key: const ValueKey(
                                      'pet-compendium-clear-filters'),
                                  onPressed: _clearFilters,
                                  child: Text(
                                    t('pet_compendium.filter.clear', 'Clear'),
                                  ),
                                ),
                              TextButton.icon(
                                key: const ValueKey(
                                    'pet-compendium-toggle-filters'),
                                onPressed: () => setState(
                                  () => _filtersCollapsed = !_filtersCollapsed,
                                ),
                                icon: Icon(
                                  _filtersCollapsed
                                      ? Icons.unfold_more_rounded
                                      : Icons.unfold_less_rounded,
                                ),
                                label: Text(
                                  t(
                                    _filtersCollapsed
                                        ? 'pet_compendium.filters.show'
                                        : 'pet_compendium.filters.hide',
                                    _filtersCollapsed ? 'Show' : 'Hide',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final label in _activeFilterLabels(t))
                                _chip(context, label),
                            ],
                          ),
                          if (_activeFilterLabels(t).isNotEmpty)
                            const SizedBox(height: 10),
                          if (!_filtersCollapsed) ...[
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                  maxHeight: filterPanelMaxHeight),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final width = constraints.maxWidth.isFinite
                                      ? constraints.maxWidth
                                      : (MediaQuery.of(context).size.width - 64)
                                          .clamp(220.0, 1200.0);
                                  final useThreeColumns = width >= 700;
                                  final useTwoColumns = width >= 300;
                                  final fieldWidth = useThreeColumns
                                      ? (width - 16) / 3
                                      : useTwoColumns
                                          ? (width - 8) / 2
                                          : width;
                                  return Scrollbar(
                                    thumbVisibility: width >= 480,
                                    child: SingleChildScrollView(
                                      primary: false,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          TextField(
                                            key: const ValueKey(
                                                'pet-compendium-search-field'),
                                            controller: _searchController,
                                            onChanged: (value) =>
                                                setState(() => _query = value),
                                            decoration: InputDecoration(
                                              border:
                                                  const OutlineInputBorder(),
                                              prefixIcon:
                                                  const Icon(Icons.search),
                                              isDense: true,
                                              hintText: t(
                                                'pet_compendium.search',
                                                'Search by pet or skill...',
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          _sectionTitle(
                                            context,
                                            t(
                                              'pet_compendium.filters.group.main',
                                              'Filters',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _filterFieldShell(
                                                width: fieldWidth,
                                                child: _filterToggleButton(
                                                  key: const ValueKey(
                                                    'pet-compendium-favorites-only-filter',
                                                  ),
                                                  label: t(
                                                    'pet_compendium.filter.favorites_only',
                                                    'Favorites only',
                                                  ),
                                                  selected: _favoritesOnly,
                                                  onPressed: () => setState(
                                                    () => _favoritesOnly =
                                                        !_favoritesOnly,
                                                  ),
                                                ),
                                              ),
                                              _filterFieldShell(
                                                width: fieldWidth,
                                                child: DropdownButtonFormField<
                                                    String?>(
                                                  key: const ValueKey(
                                                    'pet-compendium-season-filter',
                                                  ),
                                                  initialValue: _season,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    border:
                                                        const OutlineInputBorder(),
                                                    isDense: true,
                                                    labelText: t(
                                                      'pet_compendium.filter.season',
                                                      'Season',
                                                    ),
                                                  ),
                                                  items: [
                                                    DropdownMenuItem<String?>(
                                                      value: null,
                                                      child: Text(
                                                        t('pet_compendium.filter.all',
                                                            'All'),
                                                      ),
                                                    ),
                                                    for (final option
                                                        in seasonOptions)
                                                      DropdownMenuItem<String?>(
                                                        value: option,
                                                        child: Text(option),
                                                      ),
                                                  ],
                                                  onChanged: (value) =>
                                                      setState(() =>
                                                          _season = value),
                                                ),
                                              ),
                                              _filterFieldShell(
                                                width: fieldWidth,
                                                child: DropdownButtonFormField<
                                                    String?>(
                                                  key: const ValueKey(
                                                    'pet-compendium-rarity-filter',
                                                  ),
                                                  initialValue: _rarity,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    border:
                                                        const OutlineInputBorder(),
                                                    isDense: true,
                                                    labelText: t(
                                                      'pet_compendium.filter.rarity',
                                                      'Rarity',
                                                    ),
                                                  ),
                                                  items: [
                                                    DropdownMenuItem<String?>(
                                                      value: null,
                                                      child: Text(
                                                        t('pet_compendium.filter.all',
                                                            'All'),
                                                      ),
                                                    ),
                                                    for (final option
                                                        in rarityOptions)
                                                      DropdownMenuItem<String?>(
                                                        value: option,
                                                        child: Text(option),
                                                      ),
                                                  ],
                                                  onChanged: (value) =>
                                                      setState(() =>
                                                          _rarity = value),
                                                ),
                                              ),
                                              _filterFieldShell(
                                                width: fieldWidth,
                                                child: DropdownButtonFormField<
                                                    String?>(
                                                  key: const ValueKey(
                                                    'pet-compendium-tier-filter',
                                                  ),
                                                  initialValue: _tier,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    border:
                                                        const OutlineInputBorder(),
                                                    isDense: true,
                                                    labelText: t(
                                                      'pet_compendium.filter.tier',
                                                      'Tier',
                                                    ),
                                                  ),
                                                  items: [
                                                    DropdownMenuItem<String?>(
                                                      value: null,
                                                      child: Text(
                                                        t('pet_compendium.filter.all',
                                                            'All'),
                                                      ),
                                                    ),
                                                    for (final option
                                                        in tierOptions)
                                                      DropdownMenuItem<String?>(
                                                        value: option,
                                                        child: Text(option),
                                                      ),
                                                  ],
                                                  onChanged: (value) =>
                                                      setState(
                                                          () => _tier = value),
                                                ),
                                              ),
                                              _filterFieldShell(
                                                width: fieldWidth,
                                                child: DropdownButtonFormField<
                                                    ElementType?>(
                                                  key: const ValueKey(
                                                    'pet-compendium-element-filter',
                                                  ),
                                                  initialValue: _element,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    border:
                                                        const OutlineInputBorder(),
                                                    isDense: true,
                                                    labelText: t(
                                                      'pet_compendium.filter.element',
                                                      'Element',
                                                    ),
                                                  ),
                                                  items: [
                                                    DropdownMenuItem<
                                                        ElementType?>(
                                                      value: null,
                                                      child: Text(
                                                        t('pet_compendium.filter.all',
                                                            'All'),
                                                      ),
                                                    ),
                                                    for (final option
                                                        in ElementTypeCycle
                                                            .bossCycle)
                                                      DropdownMenuItem<
                                                          ElementType?>(
                                                        value: option,
                                                        child: Text(
                                                            elementLabel(
                                                                option, t)),
                                                      ),
                                                  ],
                                                  onChanged: (value) =>
                                                      setState(() =>
                                                          _element = value),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          _sectionTitle(
                                            context,
                                            t(
                                              'pet_compendium.filters.group.skills',
                                              'Skill filters',
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              _filterFieldShell(
                                                width: fieldWidth,
                                                child: DropdownButtonFormField<
                                                    String?>(
                                                  key: const ValueKey(
                                                    'pet-compendium-skill-filter-1',
                                                  ),
                                                  initialValue: _skillPrimary,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    border:
                                                        const OutlineInputBorder(),
                                                    isDense: true,
                                                    labelText: t(
                                                      'pet_compendium.filter.skill_1',
                                                      'Skill 1',
                                                    ),
                                                  ),
                                                  items: [
                                                    DropdownMenuItem<String?>(
                                                      value: null,
                                                      child: Text(
                                                        t('pet_compendium.filter.all',
                                                            'All'),
                                                      ),
                                                    ),
                                                    for (final option
                                                        in skillOptions)
                                                      DropdownMenuItem<String?>(
                                                        value: option,
                                                        child: Text(option),
                                                      ),
                                                  ],
                                                  onChanged: (value) =>
                                                      setState(() =>
                                                          _skillPrimary =
                                                              value),
                                                ),
                                              ),
                                              _filterFieldShell(
                                                width: fieldWidth,
                                                child: DropdownButtonFormField<
                                                    String?>(
                                                  key: const ValueKey(
                                                    'pet-compendium-skill-filter-2',
                                                  ),
                                                  initialValue: _skillSecondary,
                                                  isExpanded: true,
                                                  decoration: InputDecoration(
                                                    border:
                                                        const OutlineInputBorder(),
                                                    isDense: true,
                                                    labelText: t(
                                                      'pet_compendium.filter.skill_2',
                                                      'Skill 2',
                                                    ),
                                                  ),
                                                  items: [
                                                    DropdownMenuItem<String?>(
                                                      value: null,
                                                      child: Text(
                                                        t('pet_compendium.filter.all',
                                                            'All'),
                                                      ),
                                                    ),
                                                    for (final option
                                                        in skillOptions)
                                                      DropdownMenuItem<String?>(
                                                        value: option,
                                                        child: Text(option),
                                                      ),
                                                  ],
                                                  onChanged: (value) =>
                                                      setState(
                                                    () =>
                                                        _skillSecondary = value,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: cs.surface
                                                  .withValues(alpha: 0.55),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                  color: cs.outlineVariant),
                                            ),
                                            child: Text(
                                              t(
                                                'pet_compendium.filter.skill_combo_hint',
                                                'Pick one or two skills to match pet combos more easily.',
                                              ),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: SegmentedButton<PetCompendiumViewMode>(
                            segments: [
                              ButtonSegment<PetCompendiumViewMode>(
                                value: PetCompendiumViewMode.cards,
                                icon: const Icon(Icons.view_agenda_outlined),
                                label: Text(
                                  t('pet_compendium.view.cards', 'Cards'),
                                ),
                              ),
                              ButtonSegment<PetCompendiumViewMode>(
                                value: PetCompendiumViewMode.table,
                                icon: const Icon(Icons.table_rows_outlined),
                                label: Text(
                                  t('pet_compendium.view.table', 'Table'),
                                ),
                              ),
                            ],
                            selected: <PetCompendiumViewMode>{_viewMode},
                            onSelectionChanged: (selection) {
                              if (selection.isEmpty) return;
                              setState(() => _viewMode = selection.first);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      t('pet_compendium.results', '{count} pets found')
                          .replaceAll('{count}', filtered.length.toString()),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: themedLabelColor(theme),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: Text(
                                t(
                                  'pet_compendium.no_results',
                                  'No pets match the current filters.',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            )
                          : _viewMode == PetCompendiumViewMode.cards
                              ? ListView.separated(
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final family = filtered[index];
                                    return _buildPetCard(
                                      context,
                                      family,
                                      skillDefinitions,
                                    );
                                  },
                                )
                              : _buildCompactTable(
                                  context,
                                  filtered,
                                  skillDefinitions,
                                ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    String label, {
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor ?? cs.surfaceContainerHighest,
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
    final isDark =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
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

  Widget _gradientPetName(
    ThemeData theme,
    PetCompendiumTierVariant tier,
    String Function(String, String) t,
  ) {
    final base = elementColor(tier.element);
    final secondary =
        tier.secondElement != null ? elementColor(tier.secondElement!) : null;
    final gradient = LinearGradient(
      colors: [
        Color.lerp(base, Colors.white, 0.32)!,
        secondary ?? base,
      ],
    );
    return ShaderMask(
      shaderCallback: (bounds) => gradient.createShader(
        Rect.fromLTWH(
            0, 0, bounds.width == 0 ? 200 : bounds.width, bounds.height),
      ),
      blendMode: BlendMode.srcIn,
      child: Text(
        tier.name,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _statPill(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: RichText(
        text: TextSpan(
          style: theme.textTheme.bodySmall?.copyWith(
            color: cs.onSurface,
          ),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  Widget _buildPetCard(
    BuildContext context,
    PetCompendiumEntry family,
    PetSkillDefinitionsCatalog skillDefinitions,
  ) {
    final theme = Theme.of(context);
    final t = widget.t;
    final tier = _selectedTierFor(family);
    final selectedProfile = _selectedProfileFor(family);
    final skill11 = selectedProfile.skillOrFallback('skill11', tier.skill11);
    final skill12 = selectedProfile.skillOrFallback('skill12', tier.skill12);
    final skill2 = selectedProfile.skillOrFallback('skill2', tier.skill2);
    final visibleSkills = _visibleSkillsForTier(tier, selectedProfile);
    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _gradientPetName(theme, tier, t),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _favoriteButton(context, family),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                key: ValueKey('pet-compendium-apply-${family.id}'),
                onPressed: () => Navigator.of(context).pop(
                  PetCompendiumSelection(
                    family: family,
                    selectedTierId: _tierIdFor(family),
                    useAltSkillSet: _altSelectedFor(family),
                    statsProfileId: _profileIdFor(family),
                  ),
                ),
                icon: const Icon(Icons.upload_outlined),
                label: Text(
                  t('pet_compendium.use', 'Use pet'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _elementChip(context, tier.element),
              if (tier.secondElement != null)
                _elementChip(context, tier.secondElement!),
              if (family.familyTag.isNotEmpty) _chip(context, family.familyTag),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(context, family.rarity),
              _cycleChip(
                context,
                key: ValueKey('pet-tier-cycle-${family.id}'),
                label: '${t('pet_compendium.tier', 'Tier')} ${tier.tier}',
                onTap: () => _cycleTier(family),
                compact: false,
                enabled: family.tiers.length > 1,
              ),
              _chip(context, 'Lv: ${selectedProfile.level}'),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statPill(
                context,
                t('pet_compendium.pet_attack', 'Pet attack'),
                fmtInt(selectedProfile.petAttack),
              ),
              _statPill(
                context,
                t('pet.elemental_atk', 'Elemental ATK'),
                fmtInt(selectedProfile.petAttackStat),
              ),
              _statPill(
                context,
                t('pet.elemental_def', 'Elemental DEF'),
                fmtInt(selectedProfile.petDefenseStat),
              ),
            ],
          ),
          if (visibleSkills.isNotEmpty) ...[
            const SizedBox(height: 10),
            _skillSetToggle(context, family),
            const SizedBox(height: 10),
            if (_isDisplayableSkill(skill11)) ...[
              _skillChipRow(
                context,
                t('pet_compendium.skill_11', 'Skill 1.1'),
                skill11,
                skillDefinitions,
              ),
              const SizedBox(height: 6),
            ],
            if (_isDisplayableSkill(skill12)) ...[
              _skillChipRow(
                context,
                t('pet_compendium.skill_12', 'Skill 1.2'),
                skill12,
                skillDefinitions,
              ),
              const SizedBox(height: 6),
            ],
            if (_isDisplayableSkill(skill2))
              _skillChipRow(
                context,
                t('pet_compendium.skill_2', 'Skill 2'),
                skill2,
                skillDefinitions,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactTable(
    BuildContext context,
    List<PetCompendiumEntry> families,
    PetSkillDefinitionsCatalog skillDefinitions,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = widget.t;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListView.separated(
        itemCount: families.length + 1,
        separatorBuilder: (_, __) =>
            Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.5)),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Text(
                      t('pet_compendium.table.pet', 'Pet'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      t('pet_compendium.table.skills', 'Skill set'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      t('pet_compendium.pet_attack', 'Pet attack'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 44,
                    child: Text(
                      widget.t('pet_compendium.favorite.short', 'Fav'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 52,
                    child: Text(
                      t('pet_compendium.use', 'Use pet'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            );
          }
          final family = families[index - 1];
          final tier = _selectedTierFor(family);
          final selectedProfile = _selectedProfileFor(family);
          final selectedSkill1 = selectedProfile
              .skillOrFallback(
                _altSelectedFor(family) ? 'skill12' : 'skill11',
                _altSelectedFor(family) ? tier.skill12 : tier.skill11,
              )
              .name;
          final selectedSkill2 =
              selectedProfile.skillOrFallback('skill2', tier.skill2).name;
          final summarySkills = <String>[
            selectedSkill1,
            selectedSkill2,
          ].where(_isDisplayableSkillName).toList(growable: false);
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _gradientPetName(theme, tier, t),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (family.familyTag.isNotEmpty)
                                _chip(context, family.familyTag),
                              _elementChip(context, tier.element),
                              if (tier.secondElement != null)
                                _elementChip(context, tier.secondElement!),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _selectionBadgeRow(
                            context,
                            family,
                            compact: true,
                          ),
                          const SizedBox(height: 6),
                          _skillSetToggle(context, family, compact: true),
                          if (summarySkills.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              summarySkills.join(' + '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${fmtInt(selectedProfile.petAttack)}\nLv ${selectedProfile.level}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 44,
                      child: Center(
                        child: _favoriteButton(context, family),
                      ),
                    ),
                    const SizedBox(width: 10),
                    FilledButton.tonal(
                      key: ValueKey('pet-compendium-table-apply-${family.id}'),
                      onPressed: () => Navigator.of(context).pop(
                        PetCompendiumSelection(
                          family: family,
                          selectedTierId: _tierIdFor(family),
                          useAltSkillSet: _altSelectedFor(family),
                          statsProfileId: _profileIdFor(family),
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(52, 34),
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        t('pet_compendium.use_short', 'Use'),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _skillSetToggle(
    BuildContext context,
    PetCompendiumEntry family, {
    bool compact = false,
  }) {
    final tier = _selectedTierFor(family);
    final profile = _selectedProfileFor(family);
    final skill12 = profile.skillOrFallback('skill12', tier.skill12);
    final skill2 = profile.skillOrFallback('skill2', tier.skill2);
    final hasSkill12 = _isDisplayableSkill(skill12);
    final hasSkill2 = _isDisplayableSkill(skill2);
    if (!hasSkill12) {
      return const SizedBox.shrink();
    }
    final selectedAlt = _altSelectedFor(family);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ChoiceChip(
          key: ValueKey('pet-skillset-primary-${family.id}'),
          label: Text(
            _skillSetChoiceLabel(primarySlotLabel: '1.1', hasSkill2: hasSkill2),
          ),
          selected: !selectedAlt,
          onSelected: (_) => _setAltSelected(family, false),
          visualDensity: compact
              ? const VisualDensity(horizontal: -4, vertical: -4)
              : VisualDensity.standard,
          materialTapTargetSize: compact
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
          labelStyle: compact ? Theme.of(context).textTheme.labelSmall : null,
        ),
        ChoiceChip(
          key: ValueKey('pet-skillset-alt-${family.id}'),
          label: Text(
            _skillSetChoiceLabel(primarySlotLabel: '1.2', hasSkill2: hasSkill2),
          ),
          selected: selectedAlt,
          onSelected: (_) => _setAltSelected(family, true),
          visualDensity: compact
              ? const VisualDensity(horizontal: -4, vertical: -4)
              : VisualDensity.standard,
          materialTapTargetSize: compact
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
          labelStyle: compact ? Theme.of(context).textTheme.labelSmall : null,
        ),
      ],
    );
  }

  Widget _selectionBadgeRow(
    BuildContext context,
    PetCompendiumEntry family, {
    bool compact = false,
  }) {
    final t = widget.t;
    final selectedTier = _selectedTierFor(family);
    final selectedProfile = _selectedProfileFor(family);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        _cycleChip(
          context,
          key: ValueKey('pet-tier-cycle-${family.id}'),
          label: '${t('pet_compendium.tier', 'Tier')} ${selectedTier.tier}',
          onTap: () => _cycleTier(family),
          compact: compact,
          enabled: family.tiers.length > 1,
        ),
        _cycleChip(
          context,
          key: ValueKey('pet-profile-cycle-${family.id}'),
          label: selectedProfile.label,
          onTap: () => _cycleProfile(family),
          compact: compact,
          enabled: selectedTier.profiles.length > 1,
        ),
      ],
    );
  }

  Widget _cycleChip(
    BuildContext context, {
    required Key key,
    required String label,
    required VoidCallback onTap,
    required bool compact,
    required bool enabled,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      key: key,
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: enabled
              ? cs.primaryContainer.withValues(alpha: 0.2)
              : cs.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: (compact
                      ? theme.textTheme.labelSmall
                      : theme.textTheme.labelMedium)
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.sync_alt_rounded,
              size: compact ? 14 : 16,
              color: cs.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  String _humanizeSkillValueKey(String key) {
    final chars = key.split('');
    final buffer = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      final isUpper = char.toUpperCase() == char && char.toLowerCase() != char;
      if (i > 0 && isUpper) buffer.write(' ');
      buffer.write(i == 0 ? char.toUpperCase() : char);
    }
    return buffer.toString();
  }

  String _formatSkillMetricValue(String key, num value) {
    final isWhole = value == value.roundToDouble();
    final base = isWhole ? value.toInt().toString() : value.toString();
    if (key.toLowerCase().contains('percent')) return '$base%';
    return base;
  }

  List<String> _skillMetricLabels(
    PetCompendiumSkillDetails skill,
    PetSkillDefinitionsCatalog skillDefinitions,
  ) {
    if (skill.values.isEmpty) return const <String>[];
    final definition = skillDefinitions[skill.name];
    final orderedKeys = <String>[
      ...?definition?.valueOrder,
      ...skill.values.keys.where(
        (key) => !(definition?.valueOrder.contains(key) ?? false),
      ),
    ];
    return orderedKeys.where(skill.values.containsKey).map((key) {
      final label = definition?.valueLabels[key] ?? _humanizeSkillValueKey(key);
      final value = skill.values[key]!;
      return '$label ${_formatSkillMetricValue(key, value)}';
    }).toList(growable: false);
  }

  Widget _skillMetricChip(BuildContext context, String label) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _skillChipRow(
    BuildContext context,
    String label,
    PetCompendiumSkillDetails skill,
    PetSkillDefinitionsCatalog skillDefinitions,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final metricLabels = _skillMetricLabels(skill, skillDefinitions);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _skillFilterChip(context, skill.name),
              if (metricLabels.isNotEmpty) ...[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final metric in metricLabels)
                      _skillMetricChip(context, metric),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _skillFilterChip(
    BuildContext context,
    String value, {
    bool outlined = false,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => _applySkillFilter(
          value.contains(' + ') ? value.split(' + ').first : value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: outlined
              ? Colors.transparent
              : cs.primaryContainer.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: cs.outlineVariant),
        ),
        child: Text(
          value,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
