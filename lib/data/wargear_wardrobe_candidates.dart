import '../core/element_types.dart';
import 'wargear_favorites_storage.dart';
import 'wargear_universal_scoring.dart';
import 'wargear_wardrobe_loader.dart';
import 'wargear_wardrobe_sheet_storage.dart';

class WargearFavoriteCandidateContext {
  final String id;
  final String label;
  final WargearUniversalScoreContext scoreContext;
  final WargearUniversalScoreVariant scoreVariant;

  const WargearFavoriteCandidateContext({
    required this.id,
    required this.label,
    required this.scoreContext,
    this.scoreVariant = WargearUniversalScoreVariant.armorOnly,
  });
}

class WargearFavoriteCandidateScore {
  final String contextId;
  final String contextLabel;
  final WargearRole role;
  final WargearStats resolvedStats;
  final WargearStats finalStats;
  final WargearUniversalScoreResult score;

  const WargearFavoriteCandidateScore({
    required this.contextId,
    required this.contextLabel,
    required this.role,
    required this.resolvedStats,
    required this.finalStats,
    required this.score,
  });
}

class WargearFavoriteCandidate {
  final WargearWardrobeEntry entry;
  final List<WargearFavoriteCandidateScore> scores;

  const WargearFavoriteCandidate({
    required this.entry,
    required this.scores,
  });

  WargearFavoriteCandidateScore get bestScore {
    var best = scores.first;
    for (final item in scores.skip(1)) {
      if (item.score.score > best.score.score) {
        best = item;
      }
    }
    return best;
  }
}

class WargearFavoriteCandidateBatch {
  final WargearWardrobeSavedFilters filters;
  final int favoriteCount;
  final int matchingFavoriteCount;
  final List<WargearFavoriteCandidate> topCandidates;

  const WargearFavoriteCandidateBatch({
    required this.filters,
    required this.favoriteCount,
    required this.matchingFavoriteCount,
    required this.topCandidates,
  });
}

class WargearWardrobeSavedFilters {
  final String? seasonFilter;
  final ElementType? firstElement;
  final ElementType? secondElement;
  final WargearRole role;
  final WargearGuildRank rank;
  final bool plus;
  final String? sortModeName;

  const WargearWardrobeSavedFilters({
    required this.seasonFilter,
    required this.firstElement,
    required this.secondElement,
    required this.role,
    required this.rank,
    required this.plus,
    required this.sortModeName,
  });

  factory WargearWardrobeSavedFilters.fromJson(Map<String, Object?> json) {
    final seasonFilter = (json['seasonFilter'] as String?)?.trim();
    return WargearWardrobeSavedFilters(
      seasonFilter:
          seasonFilter == null || seasonFilter.isEmpty ? null : seasonFilter,
      firstElement: _decodeElement(json['firstElement'] as String?),
      secondElement: _decodeElement(json['secondElement'] as String?),
      role: WargearRole.values.firstWhere(
        (value) => value.name == (json['role'] as String?)?.trim(),
        orElse: () => WargearRole.primary,
      ),
      rank: WargearGuildRank.values.firstWhere(
        (value) => value.name == (json['rank'] as String?)?.trim(),
        orElse: () => WargearGuildRank.commander,
      ),
      plus: json['plus'] == true,
      sortModeName: (json['sortMode'] as String?)?.trim(),
    );
  }

  static ElementType? _decodeElement(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    for (final value in ElementType.values) {
      if (value.id == raw) return value;
    }
    return null;
  }
}

class WargearFavoriteCandidateSelector {
  const WargearFavoriteCandidateSelector();

  Future<WargearFavoriteCandidateBatch> loadTopFavoriteCandidates({
    required List<WargearFavoriteCandidateContext> contexts,
    required Map<ElementType, int> guildElementBonuses,
    int maxCandidates = 5,
  }) async {
    final catalog = await WargearWardrobeLoader.load();
    final favoriteIds = await WargearFavoritesStorage.load();
    final rawFilters = await WargearWardrobeSheetStorage.load();
    final filters = WargearWardrobeSavedFilters.fromJson(rawFilters);
    return rankFavorites(
      catalog: catalog,
      favoriteIds: favoriteIds,
      filters: filters,
      contexts: contexts,
      guildElementBonuses: guildElementBonuses,
      maxCandidates: maxCandidates,
    );
  }

  WargearFavoriteCandidateBatch rankFavorites({
    required WargearWardrobeCatalog catalog,
    required Set<String> favoriteIds,
    required WargearWardrobeSavedFilters filters,
    required List<WargearFavoriteCandidateContext> contexts,
    required Map<ElementType, int> guildElementBonuses,
    int maxCandidates = 5,
  }) {
    if (favoriteIds.isEmpty || contexts.isEmpty || maxCandidates <= 0) {
      return WargearFavoriteCandidateBatch(
        filters: filters,
        favoriteCount: favoriteIds.length,
        matchingFavoriteCount: 0,
        topCandidates: const <WargearFavoriteCandidate>[],
      );
    }

    final normalizedGuildBonuses =
        normalizeWargearGuildElementBonuses(guildElementBonuses);
    final scoring = const WargearUniversalScoringEngine();

    final matching = catalog.armors
        .where((entry) => favoriteIds.contains(entry.id))
        .where((entry) => _matchesFilters(entry, filters))
        .toList(growable: false);

    final ranked = matching.map((entry) {
      final scores = <WargearFavoriteCandidateScore>[];
      for (final role in WargearRole.values) {
        final resolvedStats = entry.resolveStats(
          role: role,
          rank: filters.rank,
          plus: filters.plus,
          guildElementBonuses: normalizedGuildBonuses,
        );
        for (final context in contexts) {
          final finalStats = _finalStatsFor(
            resolvedStats: resolvedStats,
            armorElements: entry.elements,
            scoreContext: context.scoreContext,
          );
          scores.add(
            WargearFavoriteCandidateScore(
              contextId: context.id,
              contextLabel: context.label,
              role: role,
              resolvedStats: resolvedStats,
              finalStats: finalStats,
              score: scoring.score(
                stats: finalStats,
                armorElements: entry.elements,
                context: context.scoreContext,
                variant: context.scoreVariant,
              ),
            ),
          );
        }
      }
      return WargearFavoriteCandidate(entry: entry, scores: scores);
    }).toList(growable: false)
      ..sort((a, b) {
        final byScore = b.bestScore.score.score.compareTo(a.bestScore.score.score);
        if (byScore != 0) return byScore;
        final bySeason =
            _seasonSortValue(b.entry.seasonTag).compareTo(_seasonSortValue(a.entry.seasonTag));
        if (bySeason != 0) return bySeason;
        return a.entry.name.toLowerCase().compareTo(b.entry.name.toLowerCase());
      });

    return WargearFavoriteCandidateBatch(
      filters: filters,
      favoriteCount: favoriteIds.length,
      matchingFavoriteCount: matching.length,
      topCandidates: ranked.take(maxCandidates).toList(growable: false),
    );
  }

  bool _matchesFilters(
    WargearWardrobeEntry entry,
    WargearWardrobeSavedFilters filters,
  ) {
    if (filters.plus && !entry.supportsPlus) return false;
    if (filters.seasonFilter != null && entry.seasonTag != filters.seasonFilter) {
      return false;
    }
    if (filters.firstElement != null && entry.elements.first != filters.firstElement) {
      return false;
    }
    if (filters.secondElement != null &&
        (entry.elements.length < 2 || entry.elements[1] != filters.secondElement)) {
      return false;
    }
    return true;
  }

  WargearStats _finalStatsFor({
    required WargearStats resolvedStats,
    required List<ElementType> armorElements,
    required WargearUniversalScoreContext scoreContext,
  }) {
    final matchCount = _petArmorBonusMatchCount(
      armorElements: armorElements,
      petElements: scoreContext.petElements,
    );
    return WargearStats(
      attack:
          resolvedStats.attack + (scoreContext.petElementalAttack * matchCount),
      defense:
          resolvedStats.defense + (scoreContext.petElementalDefense * matchCount),
      health: resolvedStats.health,
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
      if (armorFirst == petFirst && armorSecond == petFirst) return 2;
      if (armorSecond == petFirst) return 2;
      if (armorFirst == petFirst) return 1;
      return 0;
    }
    if (armorElements[0] == petFirst && armorElements[1] == petSecond) {
      return 2;
    }
    return armorElements.contains(petFirst) ? 1 : 0;
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
}
