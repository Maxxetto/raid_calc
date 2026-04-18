import 'package:flutter/material.dart';

import '../../core/element_types.dart';
import '../../data/pet_compendium_loader.dart';
import '../../data/favorites_limits.dart';
import '../../data/pet_favorites_storage.dart';
import '../theme_helpers.dart';
import '../widgets.dart';
import 'element_selector.dart';
import 'pet_compendium_sheet.dart';

class PetFavoritesSheet extends StatefulWidget {
  final String Function(String key, String fallback) t;
  final bool isPremium;

  const PetFavoritesSheet({
    super.key,
    required this.t,
    this.isPremium = false,
  });

  @override
  State<PetFavoritesSheet> createState() => _PetFavoritesSheetState();
}

class _PetFavoritesSheetState extends State<PetFavoritesSheet> {
  String _query = '';
  Set<String> _favoriteIds = <String>{};
  bool _favoritesLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final ids = await PetFavoritesStorage.load();
    if (!mounted) return;
    setState(() {
      _favoriteIds = ids;
      _favoritesLoaded = true;
    });
  }

  bool _matches(PetCompendiumEntry family) {
    if (!_favoriteIds.contains(family.id)) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    if (family.familyTag.toLowerCase().contains(q)) return true;
    return family.allNames.any((name) => name.toLowerCase().contains(q));
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
              .replaceAll('{premiumLimit}', premiumFavoritePetsLimit.toString()),
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
    final isFavorite = _favoriteIds.contains(family.id);
    if (!isFavorite &&
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
      if (isFavorite) {
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
                isFavorite
                    ? 'pet_compendium.favorite.removed'
                    : 'pet_compendium.favorite.added',
                isFavorite
                    ? '{name} removed from favorite pets.'
                    : '{name} added to favorite pets.',
              )
              .replaceAll('{name}', family.highestTier.name),
        ),
      ),
    );
  }

  PetCompendiumSelection _favoriteSelectionFor(PetCompendiumEntry family) {
    final tier = family.highestTier;
    return PetCompendiumSelection(
      family: family,
      selectedTierId: tier.id,
      statsProfileId: tier.defaultProfile.id,
      useAltSkillSet: false,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = widget.t;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FutureBuilder<PetCompendiumCatalog>(
          future: PetCompendiumLoader.load(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !_favoritesLoaded) {
              return const Center(child: CircularProgressIndicator());
            }

            final favorites = snapshot.data!.pets
                .where(_matches)
                .toList(growable: false)
              ..sort(
                  (a, b) => a.highestTier.name.compareTo(b.highestTier.name));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('pet.favorites.title', 'Favorite pets'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'pet.favorites.subtitle',
                    'Quickly insert your saved pets using the highest tier and highest level available.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                if (!widget.isPremium) ...[
                  _favoritesLimitBanner(context),
                  const SizedBox(height: 12),
                ],
                TextField(
                  key: const ValueKey('pet-favorites-search-field'),
                  onChanged: (value) => setState(() => _query = value),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    hintText: t(
                      'pet.favorites.search',
                      'Search favorite pets...',
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  t('pet_compendium.results', '{count} pets found')
                      .replaceAll('{count}', favorites.length.toString()),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: themedLabelColor(theme),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _favoriteIds.isEmpty
                      ? Center(
                          child: Text(
                            t(
                              'pet.favorites.empty',
                              'No favorite pets yet. Star a pet in the Pet Compendium to see it here.',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        )
                      : favorites.isEmpty
                          ? Center(
                              child: Text(
                                t(
                                  'pet.favorites.no_results',
                                  'No favorite pets match the current search.',
                                ),
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.separated(
                              itemCount: favorites.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final family = favorites[index];
                                final tier = family.highestTier;
                                final profile = tier.defaultProfile;
                                return CompactCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tier.name,
                                                  style: theme
                                                      .textTheme.titleSmall
                                                      ?.copyWith(
                                                    fontWeight: FontWeight.w900,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 6,
                                                  children: [
                                                    if (family
                                                        .familyTag.isNotEmpty)
                                                      _chip(context,
                                                          family.familyTag),
                                                    _elementChip(
                                                        context, tier.element),
                                                    if (tier.secondElement !=
                                                        null)
                                                      _elementChip(context,
                                                          tier.secondElement!),
                                                    _chip(
                                                        context, family.rarity),
                                                    _chip(context,
                                                        'Tier ${tier.tier}'),
                                                    _chip(
                                                        context, profile.label),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            key: ValueKey(
                                                'pet-favorites-toggle-${family.id}'),
                                            tooltip: t(
                                              'pet_compendium.favorite.remove',
                                              'Remove from favorite pets',
                                            ),
                                            onPressed: () =>
                                                _toggleFavorite(family),
                                            icon: Icon(
                                              Icons.star,
                                              color: cs.primary,
                                            ),
                                          ),
                                          FilledButton.tonalIcon(
                                            key: ValueKey(
                                                'pet-favorites-apply-${family.id}'),
                                            onPressed: () =>
                                                Navigator.of(context).pop(
                                                    _favoriteSelectionFor(
                                                        family)),
                                            icon: const Icon(
                                                Icons.upload_outlined),
                                            label: Text(
                                              t('pet.favorites.use', 'Use pet'),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _chip(context, 'Lv ${profile.level}'),
                                          _chip(
                                            context,
                                            '${t('pet_compendium.pet_attack', 'Pet attack')}: ${profile.petAttack}',
                                          ),
                                          _chip(
                                            context,
                                            'ATK: ${profile.petAttackStat}',
                                          ),
                                          _chip(
                                            context,
                                            'DEF: ${profile.petDefenseStat}',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
