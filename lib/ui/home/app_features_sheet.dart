import 'package:flutter/material.dart';

import '../home_constants.dart';

class AppFeatureHelpEntry {
  final IconData icon;
  final String title;
  final String summary;
  final List<String> quickSteps;
  final List<String> bestFor;
  final bool isPremiumFeature;
  final String? premiumNote;
  final bool hasPremiumUpsell;

  const AppFeatureHelpEntry({
    required this.icon,
    required this.title,
    required this.summary,
    required this.quickSteps,
    required this.bestFor,
    required this.isPremiumFeature,
    this.premiumNote,
    this.hasPremiumUpsell = false,
  });
}

class _AppFeatureHelpEntryDef {
  final IconData icon;
  final String keyStem;
  final String titleFallback;
  final String summaryFallback;
  final List<String> quickStepFallbacks;
  final List<String> bestForFallbacks;
  final bool isPremiumFeature;
  final String? premiumNoteFallback;
  final bool hasPremiumUpsell;
  final bool visibleInSheet;

  const _AppFeatureHelpEntryDef({
    required this.icon,
    required this.keyStem,
    required this.titleFallback,
    required this.summaryFallback,
    required this.quickStepFallbacks,
    required this.bestForFallbacks,
    this.isPremiumFeature = false,
    this.premiumNoteFallback,
    this.hasPremiumUpsell = false,
    this.visibleInSheet = true,
  });
}

const List<_AppFeatureHelpEntryDef> _appFeatureEntryDefs =
    <_AppFeatureHelpEntryDef>[
  _AppFeatureHelpEntryDef(
    icon: Icons.shield_outlined,
    keyStem: 'app_features.raid_blitz',
    titleFallback: 'Raid / Blitz Simulator',
    summaryFallback:
        'Run large battle simulations and review score, range, gem cost and detailed knight breakdowns.',
    quickStepFallbacks: <String>[
      'Set Boss, Pet and Knights on the Home screen.',
      'Choose the number of simulations and active knights.',
      'Press Simulate to open the full report.',
    ],
    bestForFallbacks: <String>[
      'testing team damage',
      'comparing pet loadouts',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.show_chart,
    keyStem: 'app_features.graph_view',
    titleFallback: 'Graph View & Charts',
    summaryFallback:
        'Turn on Graph View inside results pages to add charts alongside the full tables, including score range, distribution, threshold chance, bulk compare charts and other visual summaries.',
    quickStepFallbacks: <String>[
      'Open a Raid / Blitz results page or a Bulk compare page.',
      'Enable Graph View when the toggle is available.',
      'Use the charts to compare score shape, thresholds, timing pressure and setup tradeoffs faster.',
    ],
    bestForFallbacks: <String>[
      'faster report scanning',
      'visual setup comparison',
      'spotting stability vs high-roll setups',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.bug_report_outlined,
    keyStem: 'app_features.debug_log',
    titleFallback: 'Debug Battle Log',
    summaryFallback:
        'Replay one deterministic battle with a turn-by-turn log, live search and log copy.',
    quickStepFallbacks: <String>[
      'Enable Debug from the quick actions menu.',
      'Start the simulation.',
      'Search the log or copy it for troubleshooting.',
    ],
    bestForFallbacks: <String>[
      'checking skill interactions',
      'understanding unexpected runs',
    ],
    isPremiumFeature: true,
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.groups_2_outlined,
    keyStem: 'app_features.epic_simulator',
    titleFallback: 'Epic Simulator',
    summaryFallback:
        'Simulate Epic Boss runs and review results with the dedicated Epic flow.',
    quickStepFallbacks: <String>[
      'Open the Epic flow from the main Raid setup.',
      'Set your knights, pet and Epic boss context.',
      'Run the simulation to review the Epic results page.',
    ],
    bestForFallbacks: <String>[
      'epic boss planning',
      'checking epic teams',
    ],
    premiumNoteFallback: 'With Premium: unlock friend slots in Epic setups.',
    hasPremiumUpsell: true,
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.auto_awesome_outlined,
    keyStem: 'app_features.pet_tools',
    titleFallback: 'Pet Tools',
    summaryFallback:
        'Manage pet stats, elements, selected skills, custom skill values and pet bar usage.',
    quickStepFallbacks: <String>[
      'Set pet ATK, Elemental ATK, Elemental DEF and elements.',
      'Choose Skill Slot 1, Skill Slot 2 and pet bar order.',
      'Adjust skill numbers when you want custom testing.',
    ],
    bestForFallbacks: <String>[
      'fine tuning pet skills',
      'testing alternate values',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.pets_outlined,
    keyStem: 'app_features.pet_compendium',
    titleFallback: 'Pet Compendium',
    summaryFallback:
        'Browse pet families, filter by rarity and skill, then import the selected pet directly into the Home setup.',
    quickStepFallbacks: <String>[
      'Open Utilities > Pet Compendium.',
      'Search by pet name, skill or family tag.',
      'Pick tier, level and skill set, then tap Use pet.',
    ],
    bestForFallbacks: <String>[
      'fast pet lookup',
      'building setups quickly',
      'data-backed pet checks',
    ],
    premiumNoteFallback:
        'With Premium: unlock the full favorites and advanced pet workflow.',
    hasPremiumUpsell: true,
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.image_search_outlined,
    keyStem: 'app_features.knight_ocr',
    titleFallback: 'Knight OCR Import',
    summaryFallback:
        'Import ATK, DEF and HP for all three knights from a screenshot with crop controls and a review step.',
    quickStepFallbacks: <String>[
      'Tap the image icon in the Knights section.',
      'Adjust the crop values and choose your screenshot.',
      'Review the detected numbers before applying them.',
    ],
    bestForFallbacks: <String>[
      'saving setup time',
      'copying stats from screenshots',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.shield_moon_outlined,
    keyStem: 'app_features.wargear_wardrobe',
    titleFallback: 'Wargear Wardrobe',
    summaryFallback:
        'Import maxed armor sets with filters for elements, role, guild rank, guild element bonuses and Base / + version, including special UA and Starmetal outliers.',
    quickStepFallbacks: <String>[
      'Open Utilities > Wargear Wardrobe or the star inside a slot.',
      'Filter armor by role, rank, elements, version and guild element bonuses.',
      'Tap Use armor to import stats into the selected slot.',
    ],
    bestForFallbacks: <String>[
      'armor comparisons',
      'favorite armor quick insert',
      'UA and outlier imports',
    ],
    premiumNoteFallback:
        'With Premium: unlock favorite armor shortcuts and contextual score-assisted comparison.',
    hasPremiumUpsell: true,
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.style_outlined,
    keyStem: 'app_features.armor_badges',
    titleFallback: 'Imported Armor Badges',
    summaryFallback:
        'Imported armor cards on the Raid Home screen show tappable badges for role, guild rank and version, so you can cycle them and recalculate stats instantly.',
    quickStepFallbacks: <String>[
      'Import an armor into a knight or friend slot from Wargear Wardrobe.',
      'Tap the Role, Rank or Version badge on the Home card.',
      'Each tap cycles the badge and recalculates the imported armor stats.',
    ],
    bestForFallbacks: <String>[
      'quick role swaps',
      'rank comparisons',
      'base vs plus checks',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.workspace_premium_outlined,
    keyStem: 'app_features.universal_score',
    titleFallback: 'Universal Armor Score',
    summaryFallback:
        'Compare favorite armors with a fast contextual score based on the current boss, pet setup, knight slot and resolved armor stats.',
    quickStepFallbacks: <String>[
      'Set the current boss and pet on the Home screen.',
      'Open the star inside a knight slot to browse favorite armors.',
      'Sort by score, compare the shown values and import the armor you want.',
    ],
    bestForFallbacks: <String>[
      'faster armor decisions',
      'contextual armor ranking',
      'quick pre-sim checks',
    ],
    isPremiumFeature: true,
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.view_in_ar_outlined,
    keyStem: 'app_features.wardrobe_simulate',
    titleFallback: 'Wardrobe Simulate',
    summaryFallback:
        'Use the real Raid / Blitz simulator on every 3-armor setup generated from your top 5 favorite armors ranked by Universal Armor Score, then review the top 5 setups by mean damage.',
    quickStepFallbacks: <String>[
      'Set the current boss, pet and simulation count on the Home screen.',
      'Save at least 5 favorite armors that match your current Wardrobe filters.',
      'Press Wardrobe Simulate to compare the generated setups and review the final ranking report.',
    ],
    bestForFallbacks: <String>[
      'premium armor optimization',
      'top-setup discovery',
      'favorite pool comparisons',
    ],
    isPremiumFeature: true,
    visibleInSheet: false,
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.workspace_premium_outlined,
    keyStem: 'app_features.raid_guild_planner',
    titleFallback: 'Raid Guild Planner',
    summaryFallback:
        'Estimate how many Raid or Blitz bosses your guild needs to kill, compare a simple estimate with the fastest path, and distribute simultaneous player hits across up to 5 active bosses.',
    quickStepFallbacks: <String>[
      'Open War tab > quick actions > Open Raid planner.',
      'Set target guild points, boss mode and either average attack or full player roster.',
      'Use Fastest path with Force levels when you want a more realistic guild board plan.',
    ],
    bestForFallbacks: <String>[
      'guild push planning',
      'boss board optimization',
      'premium raid coordination',
    ],
    isPremiumFeature: true,
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.query_stats_outlined,
    keyStem: 'app_features.boss_stats',
    titleFallback: 'Boss Stats Lookup',
    summaryFallback:
        'Check the base ATK, DEF and HP tables for Raid, Blitz and Epic Boss in one place.',
    quickStepFallbacks: <String>[
      'Open Utilities > Boss stats.',
      'Switch between Raid, Blitz and Epic.',
      'Read the level table you need before simulating or sharing a setup.',
    ],
    bestForFallbacks: <String>[
      'quick stat checks',
      'verifying boss data',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.save_alt_outlined,
    keyStem: 'app_features.setups_bulk',
    titleFallback: 'Setups and Bulk Simulate',
    summaryFallback:
        'Save your Raid / Blitz builds, reload them later, share them with others and compare multiple setups in one batch.',
    quickStepFallbacks: <String>[
      'Save a setup from Utilities > Save setup.',
      'Open Setups from the top quick actions menu to load, rename, export or import.',
      'Use Bulk Simulate once you have at least two saved setups.',
    ],
    bestForFallbacks: <String>[
      'guild sharing',
      'multi-setup comparison',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.sports_martial_arts_outlined,
    keyStem: 'app_features.war_calculator',
    titleFallback: 'War Calculator',
    summaryFallback:
        'Plan attacks, Power Attacks, energy and gems for War milestones with EU / Global, Strip, Frenzy and elixir support.',
    quickStepFallbacks: <String>[
      'Open the War tab.',
      'Enter milestone and available energy.',
      'Set server, toggles and PA strategy to read the final plan.',
    ],
    bestForFallbacks: <String>[
      'war planning',
      'gem budgeting',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.calendar_month_outlined,
    keyStem: 'app_features.ua_planner',
    titleFallback: 'UA Planner',
    summaryFallback:
        'Track monthly UA progress, event rewards, placements and bonus conditions with export and import support.',
    quickStepFallbacks: <String>[
      'Open UA Planner.',
      'Enable the events you are playing that month.',
      'Enter score and placement values to see Elite and Elite+ progress.',
    ],
    bestForFallbacks: <String>[
      'monthly planning',
      'piece forecasting',
    ],
  ),
  _AppFeatureHelpEntryDef(
    icon: Icons.event_note_outlined,
    keyStem: 'app_features.news_shop',
    titleFallback: 'News and Event Shop',
    summaryFallback:
        'Follow event schedules, track completed rows and calculate required shop currencies from your selected items.',
    quickStepFallbacks: <String>[
      'Open the News tab.',
      'Switch between Active, Ended and Upcoming events.',
      'Use the event shop planner to total the currencies you still need.',
    ],
    bestForFallbacks: <String>[
      'event tracking',
      'shop planning',
    ],
  ),
];

class AppFeaturesSheet extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final bool isPremium;

  const AppFeaturesSheet({
    super.key,
    required this.t,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleDefs = _appFeatureEntryDefs
        .where((def) => def.visibleInSheet)
        .where((def) => isPremium || !def.isPremiumFeature)
        .toList(growable: false);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('app_features.title', 'App Features'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              t(
                'app_features.subtitle',
                'Quick help cards for the main tools in the app. Open the ones you need and keep scrolling for the rest.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.separated(
                itemCount: visibleDefs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final def = visibleDefs[index];
                  final entry = AppFeatureHelpEntry(
                    icon: def.icon,
                    title: t('${def.keyStem}.title', def.titleFallback),
                    summary: t('${def.keyStem}.summary', def.summaryFallback),
                    quickSteps: <String>[
                      for (var i = 0; i < def.quickStepFallbacks.length; i++)
                        t(
                          '${def.keyStem}.quick_${i + 1}',
                          def.quickStepFallbacks[i],
                        ),
                    ],
                    bestFor: <String>[
                      for (var i = 0; i < def.bestForFallbacks.length; i++)
                        t(
                          '${def.keyStem}.best_${i + 1}',
                          def.bestForFallbacks[i],
                        ),
                    ],
                    isPremiumFeature: def.isPremiumFeature,
                    premiumNote: def.premiumNoteFallback == null
                        ? null
                        : t('${def.keyStem}.premium', def.premiumNoteFallback!),
                    hasPremiumUpsell: def.hasPremiumUpsell,
                  );
                  return _FeatureHelpCard(
                    entry: entry,
                    quickUseLabel: t('app_features.quick_use', 'Quick use'),
                    bestForLabel: t('app_features.best_for', 'Best for'),
                    premiumLabel: t('app_features.premium_badge', 'Premium'),
                    premiumUnlocksLabel: t(
                      'app_features.premium_unlocks',
                      'With Premium',
                    ),
                    isPremiumActive: isPremium,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureHelpCard extends StatelessWidget {
  final AppFeatureHelpEntry entry;
  final String quickUseLabel;
  final String bestForLabel;
  final String premiumLabel;
  final String premiumUnlocksLabel;
  final bool isPremiumActive;

  const _FeatureHelpCard({
    required this.entry,
    required this.quickUseLabel,
    required this.bestForLabel,
    required this.premiumLabel,
    required this.premiumUnlocksLabel,
    required this.isPremiumActive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final highlight =
        isPremiumActive && (entry.isPremiumFeature || entry.hasPremiumUpsell);
    final gold = const Color(0xFFD4A73B);
    return Container(
      decoration: HomeUI.cardDecoration(theme).copyWith(
        border: Border.all(
          color: highlight
              ? gold.withValues(alpha: 0.92)
              : cs.outlineVariant.withValues(alpha: 0.5),
          width: highlight ? 1.6 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: highlight
                      ? gold.withValues(alpha: 0.16)
                      : cs.primaryContainer.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  entry.icon,
                  color: highlight ? gold : cs.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (entry.isPremiumFeature) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: gold.withValues(alpha: 0.72),
                          ),
                        ),
                        child: Text(
                          premiumLabel,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: gold,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      entry.summary,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SectionLabel(label: quickUseLabel),
          const SizedBox(height: 8),
          for (final step in entry.quickSteps) ...[
            _HelpBullet(text: step),
            if (step != entry.quickSteps.last) const SizedBox(height: 6),
          ],
          const SizedBox(height: 12),
          _SectionLabel(label: bestForLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tip in entry.bestFor)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(
                    tip,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (entry.premiumNote != null) ...[
            const SizedBox(height: 12),
            _SectionLabel(label: premiumUnlocksLabel),
            const SizedBox(height: 8),
            Text(
              entry.premiumNote!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

class _HelpBullet extends StatelessWidget {
  final String text;

  const _HelpBullet({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Icon(
            Icons.arrow_forward_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(height: 1.35),
          ),
        ),
      ],
    );
  }
}
