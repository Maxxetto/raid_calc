import 'package:flutter/material.dart';

import '../widgets.dart';

class UtilitiesSection extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final VoidCallback onElements;
  final VoidCallback onElixirs;
  final VoidCallback onBossStats;
  final VoidCallback onPetCompendium;
  final VoidCallback onWargearWardrobe;
  final VoidCallback onAppFeatures;
  final VoidCallback onSaveSetup;
  final VoidCallback onImportResults;

  const UtilitiesSection({
    super.key,
    required this.t,
    required this.onElements,
    required this.onElixirs,
    required this.onBossStats,
    required this.onPetCompendium,
    required this.onWargearWardrobe,
    required this.onAppFeatures,
    required this.onSaveSetup,
    required this.onImportResults,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('utilities.title', 'Utilities'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _UtilityButton(
                key: const ValueKey('utility-elements'),
                icon: Icons.grid_on,
                label: t('utilities.elements', 'Elements table'),
                onTap: onElements,
                textStyle: labelStyle,
              ),
              _UtilityButton(
                key: const ValueKey('utility-elixirs'),
                icon: Icons.local_drink,
                label: t('utilities.elixirs', 'Elixirs list'),
                onTap: onElixirs,
                textStyle: labelStyle,
              ),
              _UtilityButton(
                key: const ValueKey('utility-boss-stats'),
                icon: Icons.query_stats,
                label: t('utilities.boss_stats', 'Boss stats'),
                onTap: onBossStats,
                textStyle: labelStyle,
              ),
              _UtilityButton(
                key: const ValueKey('utility-save-setup'),
                icon: Icons.save_outlined,
                label: t('utilities.save_setup', 'Save setup'),
                onTap: onSaveSetup,
                textStyle: labelStyle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _UtilityButton(
                key: const ValueKey('utility-pet-compendium'),
                icon: Icons.pets,
                label: t('utilities.pet_compendium', 'Pet compendium'),
                onTap: onPetCompendium,
                textStyle: labelStyle,
              ),
              _UtilityButton(
                key: const ValueKey('utility-wargear-wardrobe'),
                icon: Icons.shield_outlined,
                label: t('utilities.wargear', 'Wargear Wardrobe'),
                onTap: onWargearWardrobe,
                textStyle: labelStyle,
              ),
              _UtilityButton(
                key: const ValueKey('utility-import-results'),
                icon: Icons.download_for_offline_outlined,
                label: t('utilities.import_results', 'Import results'),
                onTap: onImportResults,
                textStyle: labelStyle,
              ),
              _UtilityButton(
                key: const ValueKey('utility-app-features'),
                icon: Icons.auto_awesome_outlined,
                label: t('utilities.app_features', 'App features'),
                onTap: onAppFeatures,
                textStyle: labelStyle,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UtilityButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final TextStyle? textStyle;

  const _UtilityButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        label: label,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: label,
                  child: Icon(
                    icon,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: textStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
