import 'package:flutter/material.dart';

import '../../core/element_types.dart';
import '../../data/wargear_wardrobe_loader.dart';
import '../widgets.dart';
import 'element_selector.dart';

typedef ElementCycle = void Function(int index, int elementIndex);

class KnightsSection extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final TextStyle themedLabel;
  final bool running;
  final bool importBusy;
  final List<TextEditingController> kAtk;
  final List<TextEditingController> kDef;
  final List<TextEditingController> kHp;
  final List<List<ElementType>> kElements;
  final List<double> kAdv;
  final List<TextEditingController> kStun;
  final List<String?> armorImportSummaries;
  final List<WargearImportSnapshot?> armorImportSnapshots;
  final String? Function(int index)? universalScoreLabelBuilder;
  final List<bool> canRecalculateArmor;
  final ElementCycle onElementCycle;
  final VoidCallback? onImportFromScreenshot;
  final ValueChanged<int>? onOpenFavoriteArmors;
  final ValueChanged<int>? onRecalculateArmor;
  final ValueChanged<int>? onCycleArmorRole;
  final ValueChanged<int>? onCycleArmorRank;
  final ValueChanged<int>? onCycleArmorVersion;
  final List<bool> hiddenKnights;
  final ValueChanged<int>? onToggleKnightHidden;

  const KnightsSection({
    super.key,
    required this.t,
    required this.themedLabel,
    required this.running,
    this.importBusy = false,
    required this.kAtk,
    required this.kDef,
    required this.kHp,
    required this.kElements,
    required this.kAdv,
    required this.kStun,
    required this.armorImportSummaries,
    required this.armorImportSnapshots,
    this.universalScoreLabelBuilder,
    required this.canRecalculateArmor,
    required this.onElementCycle,
    this.onImportFromScreenshot,
    this.onOpenFavoriteArmors,
    this.onRecalculateArmor,
    this.onCycleArmorRole,
    this.onCycleArmorRank,
    this.onCycleArmorVersion,
    this.hiddenKnights = const <bool>[false, false, false],
    this.onToggleKnightHidden,
  });

  String _roleLabel(WargearRole role) {
    return switch (role) {
      WargearRole.primary => t('wargear.role.primary.short', 'Primary'),
      WargearRole.secondary => t('wargear.role.secondary.short', 'Secondary'),
    };
  }

  String _rankLabel(WargearGuildRank rank) {
    return switch (rank) {
      WargearGuildRank.commander =>
        t('wargear.rank.commander.short', 'Comm'),
      WargearGuildRank.highCommander =>
        t('wargear.rank.high_commander.short', 'HC'),
      WargearGuildRank.gcGs => t('wargear.rank.gc_gs', 'GS / GC'),
      WargearGuildRank.guildMaster =>
        t('wargear.rank.guild_master.short', 'GM'),
    };
  }

  String _readField(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? '0' : value;
  }

  Future<void> _showKnightsTip(BuildContext context) {
    final title = t('knights.tip.title', 'Knights tip');
    final body = t(
      'knights.tip.body',
      'Enter the knight information: ATK, DEF, HP, stun chance and elements. The image icon imports stats from a screenshot, while the star icon quickly inserts a favorite armor.',
    );
    final autoAdv = t(
      'knights.tip.auto_advantage',
      'Knight advantage is calculated automatically based on the selected elements.',
    );
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text('$body\n\n$autoAdv'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t('cancel', 'Close')),
          ),
        ],
      ),
    );
  }

  Widget _hiddenKnightRecap(BuildContext context, int index) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('atk', 'ATK')} ${_readField(kAtk[index])} | ${t('def', 'DEF')} ${_readField(kDef[index])} | ${t('hp', 'HP')} ${_readField(kHp[index])}',
            key: ValueKey('knight-hidden-stats-$index'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${elementLabel(kElements[index][0], t)} / ${elementLabel(kElements[index][1], t)} ${formatMultiplier(kAdv[index])} | ${t('stun_chance', 'STUN %')} ${_readField(kStun[index])}',
            key: ValueKey('knight-hidden-elements-$index'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('knights', 'Cavalieri'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (importBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: t(
                    'knights.import_screenshot',
                    'Import from screenshot',
                  ),
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: (running || onImportFromScreenshot == null)
                      ? null
                      : onImportFromScreenshot,
                  icon: const Icon(Icons.image_search_outlined),
                ),
              IconButton(
                key: const ValueKey('knights-tip-button'),
                tooltip: t('knights.tip.title', 'Knights tip'),
                visualDensity: VisualDensity.compact,
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => _showKnightsTip(context),
                icon: const Icon(Icons.info_outline, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < 3; i++) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    'K#${i + 1}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton.icon(
                  key: ValueKey('knight-toggle-hidden-$i'),
                  onPressed: onToggleKnightHidden == null
                      ? null
                      : () => onToggleKnightHidden!(i),
                  icon: Icon(
                    (i < hiddenKnights.length && hiddenKnights[i])
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18,
                  ),
                  label: Text(
                    (i < hiddenKnights.length && hiddenKnights[i])
                        ? t('common.show', 'Show')
                        : t('common.hide', 'Hide'),
                  ),
                ),
                IconButton(
                  key: ValueKey('knight-favorite-armor-$i'),
                  tooltip: t(
                    'wargear.favorites.open',
                    'Open favorite armors',
                  ),
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: (running || onOpenFavoriteArmors == null)
                      ? null
                      : () => onOpenFavoriteArmors!(i),
                  icon: const Icon(Icons.star_outline),
                ),
                IconButton(
                  key: ValueKey('knight-recalculate-armor-$i'),
                  tooltip: t(
                    'wargear.recalculate',
                    'Recalculate imported armor',
                  ),
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.onSurfaceVariant,
                  onPressed: (running ||
                          onRecalculateArmor == null ||
                          !canRecalculateArmor[i])
                      ? null
                      : () => onRecalculateArmor!(i),
                  icon: const Icon(Icons.refresh_outlined),
                ),
              ],
            ),
            if ((armorImportSummaries[i] ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                armorImportSummaries[i]!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (armorImportSnapshots[i] != null) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    key: ValueKey('knight-armor-role-$i'),
                    label: Text(_roleLabel(armorImportSnapshots[i]!.role)),
                    onPressed: (running || onCycleArmorRole == null)
                        ? null
                        : () => onCycleArmorRole!(i),
                  ),
                  ActionChip(
                    key: ValueKey('knight-armor-rank-$i'),
                    label: Text(_rankLabel(armorImportSnapshots[i]!.rank)),
                    onPressed: (running || onCycleArmorRank == null)
                        ? null
                        : () => onCycleArmorRank!(i),
                  ),
                  ActionChip(
                    key: ValueKey('knight-armor-version-$i'),
                    label: Text(
                      armorImportSnapshots[i]!.plus
                          ? t('wargear.plus.short.on', 'Version: +')
                          : t('wargear.plus.short.off', 'Version: Base'),
                    ),
                    onPressed: (running || onCycleArmorVersion == null)
                        ? null
                        : () => onCycleArmorVersion!(i),
                  ),
                ],
              ),
            ],
            if (universalScoreLabelBuilder != null) ...[
              const SizedBox(height: 4),
              ListenableBuilder(
                listenable: Listenable.merge(<Listenable>[
                  kAtk[i],
                  kDef[i],
                  kHp[i],
                  kStun[i],
                ]),
                builder: (context, child) {
                  final label = universalScoreLabelBuilder!(i);
                  if ((label ?? '').trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    label!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 8),
            if (i < hiddenKnights.length && hiddenKnights[i])
              _hiddenKnightRecap(context, i)
            else ...[
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: t('atk', 'ATK'),
                      labelStyle: themedLabel,
                      child: CompactGroupedIntField(
                        controller: kAtk[i],
                        hint: '0',
                        enabled: !running,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: t('def', 'DEF'),
                      labelStyle: themedLabel,
                      child: CompactGroupedIntField(
                        controller: kDef[i],
                        hint: '0',
                        enabled: !running,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: t('hp', 'HP'),
                      labelStyle: themedLabel,
                      child: CompactGroupedIntField(
                        controller: kHp[i],
                        hint: '0',
                        enabled: !running,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: t('elements', 'Elements'),
                      labelStyle: themedLabel,
                      child: ElementPairRow(
                        first: kElements[i][0],
                        second: kElements[i][1],
                        onCycle: (elementIndex) =>
                            onElementCycle(i, elementIndex),
                        enabled: !running,
                        t: t,
                        trailing: Text(
                          formatMultiplier(kAdv[i]),
                          style: themedLabel,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: LabeledField(
                      label: t('stun_chance', 'STUN %'),
                      labelStyle: themedLabel,
                      child: CompactNumberField(
                        controller: kStun[i],
                        hint: '0',
                        enabled: !running,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (i != 2) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}
