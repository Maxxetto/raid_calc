import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/element_types.dart';
import '../../core/sim_types.dart';
import '../../data/share_payloads.dart';
import '../../data/setup_models.dart';
import '../../data/wargear_wardrobe_candidates.dart';
import '../../data/wargear_wardrobe_loader.dart';
import '../../data/wargear_wardrobe_simulator.dart';
import '../../util/format.dart';
import '../widgets.dart';
import 'element_selector.dart';

class WargearWardrobeSimulateReportSheet extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final WardrobeSimulateBatchResult result;

  const WargearWardrobeSimulateReportSheet({
    super.key,
    required this.t,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topResults = result.topResults(limit: 5);
    final testedPets = result.testedPets.isEmpty
        ? <SetupPetSnapshot>[result.baseSetup.pet]
        : result.testedPets;
    final petBreakdowns = _buildPetBreakdowns(testedPets);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  t('wardrobe_simulate.title', 'Wardrobe Simulate'),
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: t('results.export', 'Copy export'),
                icon: const Icon(Icons.copy),
                onPressed: () => _copyExport(context),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            t(
              'wardrobe_simulate.report.subtitle',
              'Favorite armors are re-ranked for each favorite pet and each Pet skill usage, then expanded into all 3-armor setups, slot permutations and primary/secondary permutations using the current Raid/Blitz context.',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          CompactCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  label: t('wardrobe_simulate.report.parameters', 'Parameters'),
                  theme: theme,
                ),
                const SizedBox(height: 8),
                _kv(
                  theme,
                  t('boss', 'Boss'),
                  '${_modeLabel(result.baseSetup.bossMode)} L${result.baseSetup.bossLevel} | ${_elementPairLabel(result.baseSetup.bossElements)}',
                ),
                _kv(
                  theme,
                  t('pet.favorites.title', 'Favorite pets'),
                  fmtInt(result.favoritePetCount),
                ),
                _kv(
                  theme,
                  t('pet.skill_usage', 'Pet skill usage'),
                  result.testedSkillUsages.isEmpty
                      ? fmtInt(PetSkillUsageMode.values.length)
                      : result.testedSkillUsages
                          .cast<PetSkillUsageMode>()
                          .map((mode) => mode.shortLabel())
                          .join(' | '),
                ),
                _kv(
                  theme,
                  t(
                    'wardrobe_simulate.report.runs_per_setup',
                    'Runs per setup',
                  ),
                  fmtInt(result.runsPerScenario),
                ),
                _kv(
                  theme,
                  t(
                    'wardrobe_simulate.report.generated_scenarios',
                    'Generated scenarios',
                  ),
                  fmtInt(result.totalScenarios),
                ),
                _kv(
                  theme,
                  t(
                    'wardrobe_simulate.report.matching_favorites',
                    'Matching favorites',
                  ),
                  '${fmtInt(result.candidateBatch.matchingFavoriteCount)} / ${fmtInt(result.candidateBatch.favoriteCount)}',
                ),
                _kv(
                  theme,
                  t(
                    'wardrobe_simulate.report.saved_filters',
                    'Saved Wardrobe filters',
                  ),
                  _filtersSummary(result.candidateBatch.filters),
                ),
                const SizedBox(height: 6),
                Text(
                  t(
                    'wardrobe_simulate.report.role_note',
                    'Role filter is ignored here on purpose, because Wardrobe Simulate tests all valid 1 primary + 2 secondary role assignments.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t(
                    'wardrobe_simulate.report.pet_note',
                    'Top armor candidates are recalculated separately for each favorite pet and each Pet skill usage.',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CompactCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  label: t(
                    'wardrobe_simulate.report.pet_breakdown',
                    'Per-pet breakdown',
                  ),
                  theme: theme,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < petBreakdowns.length; i++)
                  _PetBreakdownTile(
                    t: t,
                    index: i + 1,
                    breakdown: petBreakdowns[i],
                    runsPerScenario: result.runsPerScenario,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CompactCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle(
                  label: t(
                    'wardrobe_simulate.report.top_setups_global',
                    'Global top 5 setups',
                  ),
                  theme: theme,
                ),
                const SizedBox(height: 8),
                if (topResults.isEmpty)
                  Text(
                    t(
                      'wardrobe_simulate.report.no_valid',
                      'No valid setup was generated from the current favorite armors.',
                    ),
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  for (var i = 0; i < topResults.length; i++)
                    _ResultTile(
                      t: t,
                      index: i + 1,
                      result: topResults[i],
                      onCopySetup: () =>
                          _copySetup(context, topResults[i], i + 1),
                      onCopyScenario: () =>
                          _copyScenario(context, topResults[i], i + 1),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_PetBreakdownData> _buildPetBreakdowns(
      List<SetupPetSnapshot> testedPets) {
    final grouped = <String, List<WardrobeSimulateScenarioResult>>{};
    for (final scenario in result.results) {
      final key = _petKey(scenario.setup.pet);
      grouped
          .putIfAbsent(key, () => <WardrobeSimulateScenarioResult>[])
          .add(scenario);
    }
    return testedPets.map((pet) {
      final scenarios =
          grouped[_petKey(pet)] ?? const <WardrobeSimulateScenarioResult>[];
      final sorted = List<WardrobeSimulateScenarioResult>.from(scenarios)
        ..sort((a, b) {
          final byMean = b.stats.mean.compareTo(a.stats.mean);
          if (byMean != 0) return byMean;
          final byMedian = b.stats.median.compareTo(a.stats.median);
          if (byMedian != 0) return byMedian;
          return b.stats.max.compareTo(a.stats.max);
        });
      return _PetBreakdownData(
        pet: pet,
        scenarios: List<WardrobeSimulateScenarioResult>.unmodifiable(scenarios),
        topResults: List<WardrobeSimulateScenarioResult>.unmodifiable(
          sorted.take(3),
        ),
      );
    }).toList(growable: false);
  }

  String _petKey(SetupPetSnapshot pet) {
    final imported = pet.importedCompendium;
    if (imported != null && imported.familyId.trim().isNotEmpty) {
      return 'family:${imported.familyId.trim().toLowerCase()}:'
          '${pet.skillUsage.name}:'
          '${imported.selectedSkill1.name.trim().toLowerCase()}:'
          '${imported.selectedSkill2.name.trim().toLowerCase()}';
    }
    final second = pet.element2?.id ?? '-';
    return 'manual:${pet.element1.id}:$second:${pet.elementalAtk}:'
        '${pet.elementalDef}:${pet.skillUsage.name}:'
        '${pet.manualSkill1?.name ?? imported?.selectedSkill1.name ?? ''}:'
        '${pet.manualSkill2?.name ?? imported?.selectedSkill2.name ?? ''}';
  }

  String _filtersSummary(WargearWardrobeSavedFilters filters) {
    final parts = <String>[
      filters.plus ? 'Plus only' : 'Base + Plus',
      'Rank ${_rankLabel(filters.rank)}',
      '1st ${filters.firstElement == null ? 'All' : elementLabel(filters.firstElement!, t)}',
      '2nd ${filters.secondElement == null ? 'All' : elementLabel(filters.secondElement!, t)}',
      'Season ${filters.seasonFilter ?? 'All'}',
    ];
    return parts.join(' | ');
  }

  String _rankLabel(WargearGuildRank rank) {
    return switch (rank) {
      WargearGuildRank.commander => 'Comm',
      WargearGuildRank.highCommander => 'HC',
      WargearGuildRank.gcGs => 'GS / GC',
      WargearGuildRank.guildMaster => 'GM',
    };
  }

  String _modeLabel(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'raid':
        return 'Raid';
      case 'blitz':
        return 'Blitz';
      case 'epic':
        return 'Epic';
      default:
        return mode;
    }
  }

  String _elementPairLabel(List<ElementType> pair) {
    if (pair.isEmpty) return '-';
    if (pair.length == 1) return elementLabel(pair.first, t);
    return '${elementLabel(pair[0], t)} / ${elementLabel(pair[1], t)}';
  }

  Widget _kv(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _copyExport(BuildContext context) async {
    final topResults = result.topResults(limit: 20);
    final exportedAtIso = DateTime.now().toIso8601String();
    final payload = <String, Object?>{
      'kind': 'raid_calc.wardrobe_simulate_report',
      'type': 'wardrobe_simulate_report',
      'v': 1,
      'exportedAtIso': exportedAtIso,
      'baseSetup': result.baseSetup.toJson(),
      'runsPerScenario': result.runsPerScenario,
      'totalScenarios': result.totalScenarios,
      'favoritePetCount': result.favoritePetCount,
      'testedSkillUsages': result.testedSkillUsages
          .map((mode) => mode.name)
          .toList(growable: false),
      'testedPets':
          result.testedPets.map((pet) => pet.toJson()).toList(growable: false),
      'candidateBatch': <String, Object?>{
        'favoriteCount': result.candidateBatch.favoriteCount,
        'matchingFavoriteCount': result.candidateBatch.matchingFavoriteCount,
        'filters': _filtersToJson(result.candidateBatch.filters),
        'topCandidates': result.candidateBatch.topCandidates
            .map(_candidateToJson)
            .toList(growable: false),
      },
      'topResults': topResults
          .asMap()
          .entries
          .map(
            (entry) => _scenarioToJson(
              entry.value,
              includeSetup: true,
              exportedAtIso: exportedAtIso,
              rank: entry.key + 1,
            ),
          )
          .toList(growable: false),
      'allScenarioSummaries': result.results
          .map(
            (scenario) => _scenarioToJson(
              scenario,
              includeSetup: false,
              exportedAtIso: exportedAtIso,
            ),
          )
          .toList(growable: false),
    };
    await Clipboard.setData(ClipboardData(text: encodePrettyJson(payload)));
    _showCopiedSnackBar(
      context,
      t(
        'wardrobe_simulate.report.export_copied',
        'Wardrobe Simulate export copied',
      ),
    );
  }

  Map<String, Object?> _filtersToJson(WargearWardrobeSavedFilters filters) {
    return <String, Object?>{
      'seasonFilter': filters.seasonFilter,
      'firstElement': filters.firstElement?.id,
      'secondElement': filters.secondElement?.id,
      'role': filters.role.name,
      'rank': filters.rank.name,
      'plus': filters.plus,
      'sortModeName': filters.sortModeName,
    };
  }

  Map<String, Object?> _candidateToJson(WargearFavoriteCandidate candidate) {
    final best = candidate.bestScore;
    return <String, Object?>{
      'entryId': candidate.entry.id,
      'displayName': candidate.entry.displayName(plus: true),
      'seasonTag': candidate.entry.seasonTag,
      'elements': candidate.entry.elements.map((value) => value.id).toList(),
      'bestScore': <String, Object?>{
        'contextId': best.contextId,
        'contextLabel': best.contextLabel,
        'role': best.role.name,
        'score': best.score.score,
      },
    };
  }

  Map<String, Object?> _scenarioToJson(
    WardrobeSimulateScenarioResult scenario, {
    required bool includeSetup,
    required String exportedAtIso,
    int? rank,
  }) {
    return <String, Object?>{
      if (rank != null) 'rank': rank,
      'scenarioId': scenario.scenarioId,
      if (includeSetup) 'setup': scenario.setup.toJson(),
      if (includeSetup)
        'setupSharePayload': _setupSharePayloadJson(
          scenario,
          exportedAtIso: exportedAtIso,
          rank: rank,
        ),
      'pet': <String, Object?>{
        'label': _petExportLabel(scenario.setup.pet),
        'skillUsage': scenario.setup.pet.skillUsage.name,
        'skill1': _skillExportName(
          scenario.setup.pet.importedCompendium?.selectedSkill1.name,
          scenario.setup.pet.manualSkill1?.name,
        ),
        'skill2': _skillExportName(
          scenario.setup.pet.importedCompendium?.selectedSkill2.name,
          scenario.setup.pet.manualSkill2?.name,
        ),
      },
      'stats': <String, Object?>{
        'mean': scenario.stats.mean,
        'median': scenario.stats.median,
        'min': scenario.stats.min,
        'max': scenario.stats.max,
        if (scenario.stats.timing != null)
          'meanRunSeconds': scenario.stats.timing!.meanRunSeconds,
      },
      'assignments': scenario.assignments
          .map(
            (assignment) => <String, Object?>{
              'slotIndex': assignment.slotIndex,
              'entryId': assignment.entry.id,
              'entryName': assignment.entry.displayName(plus: true),
              'role': assignment.role.name,
              'resolvedStats': <String, Object?>{
                'attack': assignment.resolvedStats.attack,
                'defense': assignment.resolvedStats.defense,
                'health': assignment.resolvedStats.health,
              },
              'finalStats': <String, Object?>{
                'attack': assignment.finalStats.attack,
                'defense': assignment.finalStats.defense,
                'health': assignment.finalStats.health,
              },
              'universalArmorScore': assignment.universalArmorScore.score,
              'petAwareUniversalArmorScore':
                  assignment.petAwareUniversalArmorScore.score,
              'stunPercent': assignment.stunPercent,
            },
          )
          .toList(growable: false),
    };
  }

  Map<String, Object?> _setupSharePayloadJson(
    WardrobeSimulateScenarioResult scenario, {
    required String exportedAtIso,
    int? rank,
  }) {
    return SetupSharePayload(
      setup: scenario.setup,
      name:
          rank == null ? 'Wardrobe Simulate setup' : 'Wardrobe Simulate #$rank',
      exportedAtIso: exportedAtIso,
    ).toJson();
  }

  Future<void> _copySetup(
    BuildContext context,
    WardrobeSimulateScenarioResult scenario,
    int rank,
  ) async {
    final payload = _setupSharePayloadJson(
      scenario,
      exportedAtIso: DateTime.now().toIso8601String(),
      rank: rank,
    );
    await Clipboard.setData(ClipboardData(text: encodePrettyJson(payload)));
    _showCopiedSnackBar(
      context,
      t('wardrobe_simulate.report.setup_copied', 'Setup copied'),
    );
  }

  Future<void> _copyScenario(
    BuildContext context,
    WardrobeSimulateScenarioResult scenario,
    int rank,
  ) async {
    final exportedAtIso = DateTime.now().toIso8601String();
    final payload = <String, Object?>{
      'kind': 'raid_calc.wardrobe_simulate_scenario',
      'v': 1,
      'exportedAtIso': exportedAtIso,
      'scenario': _scenarioToJson(
        scenario,
        includeSetup: true,
        exportedAtIso: exportedAtIso,
        rank: rank,
      ),
    };
    await Clipboard.setData(ClipboardData(text: encodePrettyJson(payload)));
    _showCopiedSnackBar(
      context,
      t(
        'wardrobe_simulate.report.scenario_copied',
        'Scenario copied',
      ),
    );
  }

  void _showCopiedSnackBar(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _petExportLabel(SetupPetSnapshot pet) {
    final imported = pet.importedCompendium;
    if (imported != null && imported.tierName.trim().isNotEmpty) {
      return imported.tierName.trim();
    }
    if (imported != null && imported.familyTag.trim().isNotEmpty) {
      return imported.familyTag.trim();
    }
    final second = pet.element2;
    return second == null ? pet.element1.id : '${pet.element1.id}/${second.id}';
  }

  String _skillExportName(String? imported, String? manual) {
    final value = imported ?? manual;
    if (value == null || value.trim().isEmpty) return '-';
    return value.trim();
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final ThemeData theme;

  const _SectionTitle({
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _PetBreakdownData {
  final SetupPetSnapshot pet;
  final List<WardrobeSimulateScenarioResult> scenarios;
  final List<WardrobeSimulateScenarioResult> topResults;

  const _PetBreakdownData({
    required this.pet,
    required this.scenarios,
    required this.topResults,
  });
}

class _PetBreakdownTile extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final int index;
  final _PetBreakdownData breakdown;
  final int runsPerScenario;

  const _PetBreakdownTile({
    required this.t,
    required this.index,
    required this.breakdown,
    required this.runsPerScenario,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pet = breakdown.pet;
    final elements = <ElementType>[
      pet.element1,
      if (pet.element2 != null) pet.element2!,
    ];
    final scenarioCount = breakdown.scenarios.length;
    final totalRuns = scenarioCount * runsPerScenario;
    final best =
        breakdown.topResults.isEmpty ? null : breakdown.topResults.first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$index. ${_petLabel(pet)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${t('pet.skill_usage', 'Pet skill usage')}: ${pet.skillUsage.shortLabel()}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${t('results.pet.elements', 'Elements')}: ${_elementPairLabel(elements)} | EA ${fmtInt(pet.elementalAtk)} | ED ${fmtInt(pet.elementalDef)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${t('wardrobe_simulate.report.pet_skills', 'Pet skills')}: ${_skillName(pet.importedCompendium?.selectedSkill1.name, pet.manualSkill1?.name)} / ${_skillName(pet.importedCompendium?.selectedSkill2.name, pet.manualSkill2?.name)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                    label:
                        '${t('wardrobe_simulate.report.generated_scenarios', 'Generated scenarios')}: ${fmtInt(scenarioCount)}',
                  ),
                  _StatChip(
                    label:
                        '${t('wardrobe_simulate.confirm.total_runs', 'Total runs')}: ${fmtInt(totalRuns)}',
                  ),
                  if (best != null)
                    _StatChip(
                      label:
                          '${t('wardrobe_simulate.report.best_mean', 'Best mean')}: ${fmtInt(best.stats.mean)}',
                    ),
                ],
              ),
              if (breakdown.topResults.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  t(
                    'wardrobe_simulate.report.pet_top_results',
                    'Top results for this pet',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                for (var i = 0; i < breakdown.topResults.length; i++)
                  _PetTopResultRow(
                    t: t,
                    index: i + 1,
                    result: breakdown.topResults[i],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _petLabel(SetupPetSnapshot pet) {
    final imported = pet.importedCompendium;
    if (imported != null && imported.tierName.trim().isNotEmpty) {
      return imported.tierName.trim();
    }
    if (imported != null && imported.familyTag.trim().isNotEmpty) {
      return imported.familyTag.trim();
    }
    final second = pet.element2;
    return second == null ? pet.element1.id : '${pet.element1.id}/${second.id}';
  }

  String _elementPairLabel(List<ElementType> pair) {
    if (pair.isEmpty) return '-';
    if (pair.length == 1) return elementLabel(pair.first, t);
    return '${elementLabel(pair[0], t)} / ${elementLabel(pair[1], t)}';
  }

  String _skillName(String? imported, String? manual) {
    final value = imported ?? manual;
    if (value == null || value.trim().isEmpty) return '-';
    return value.trim();
  }
}

class _StatChip extends StatelessWidget {
  final String label;

  const _StatChip({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PetTopResultRow extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final int index;
  final WardrobeSimulateScenarioResult result;

  const _PetTopResultRow({
    required this.t,
    required this.index,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timing = result.stats.timing;
    final assignmentSummary = result.assignments
        .map((assignment) =>
            'K#${assignment.slotIndex + 1} ${assignment.entry.displayName(plus: true)}')
        .join(' | ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#$index | ${t('mean', 'Mean')} ${fmtInt(result.stats.mean)} | '
                '${t('median', 'Median')} ${fmtInt(result.stats.median)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (timing != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${t('wardrobe_simulate.report.avg_run', 'Avg run')} '
                  '${fmtDouble(timing.meanRunSeconds, maxDecimals: 2)} s',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              Text(
                assignmentSummary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final int index;
  final WardrobeSimulateScenarioResult result;
  final VoidCallback onCopySetup;
  final VoidCallback onCopyScenario;

  const _ResultTile({
    required this.t,
    required this.index,
    required this.result,
    required this.onCopySetup,
    required this.onCopyScenario,
  });

  String _petLabel(SetupPetSnapshot pet) {
    final imported = pet.importedCompendium;
    if (imported != null && imported.tierName.trim().isNotEmpty) {
      return imported.tierName.trim();
    }
    if (imported != null && imported.familyTag.trim().isNotEmpty) {
      return imported.familyTag.trim();
    }
    final second = pet.element2;
    return second == null ? pet.element1.id : '${pet.element1.id}/${second.id}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timing = result.stats.timing;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color:
              theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '#$index | ${t('mean', 'Mean')} ${fmtInt(result.stats.mean)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${t('median', 'Median')} ${fmtInt(result.stats.median)} | ${t('min', 'Min')} ${fmtInt(result.stats.min)} | ${t('max', 'Max')} ${fmtInt(result.stats.max)}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 2),
              Text(
                '${t('pet', 'Pet')} ${_petLabel(result.setup.pet)} | ${result.setup.pet.element2 == null ? elementLabel(result.setup.pet.element1, t) : '${elementLabel(result.setup.pet.element1, t)} / ${elementLabel(result.setup.pet.element2!, t)}'}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (timing != null) ...[
                const SizedBox(height: 2),
                Text(
                  '${t('wardrobe_simulate.report.avg_run', 'Avg run')} ${fmtDouble(timing.meanRunSeconds, maxDecimals: 2)} s',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              for (final assignment in result.assignments)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'K#${assignment.slotIndex + 1} | ${assignment.role == WargearRole.primary ? t('wargear.role.primary.short', 'Primary') : t('wargear.role.secondary.short', 'Secondary')} | ${assignment.entry.displayName(plus: true)} | ${t('wargear.universal_scoring.variant.armor_only.short', 'UAS')} ${fmtInt(assignment.universalArmorScore.score)} | ${t('wargear.universal_scoring.variant.pet_aware.short', 'Pet')} ${fmtInt(assignment.petAwareUniversalArmorScore.score)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: onCopySetup,
                    icon: const Icon(Icons.content_copy, size: 16),
                    label: Text(
                      t('wardrobe_simulate.report.copy_setup', 'Copy setup'),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onCopyScenario,
                    icon: const Icon(Icons.data_object, size: 16),
                    label: Text(
                      t(
                        'wardrobe_simulate.report.copy_scenario',
                        'Copy scenario',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
