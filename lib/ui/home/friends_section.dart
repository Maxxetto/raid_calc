import 'package:flutter/material.dart';

import '../../core/element_types.dart';
import '../../data/wargear_wardrobe_loader.dart';
import '../widgets.dart';
import 'element_selector.dart';

typedef ElementCycle = void Function(int index, int elementIndex);

class FriendsSection extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final TextStyle themedLabel;
  final bool running;
  final bool isPremium;
  final List<TextEditingController> frAtk;
  final List<TextEditingController> frDef;
  final List<TextEditingController> frHp;
  final List<List<ElementType>> frElements;
  final List<double> frAdv;
  final List<TextEditingController> frStun;
  final List<String?> armorImportSummaries;
  final List<WargearImportSnapshot?> armorImportSnapshots;
  final String? Function(int index)? universalScoreLabelBuilder;
  final List<bool> canRecalculateArmor;
  final ElementCycle onElementCycle;
  final ValueChanged<int>? onOpenFavoriteArmors;
  final ValueChanged<int>? onRecalculateArmor;
  final ValueChanged<int>? onCycleArmorRole;
  final ValueChanged<int>? onCycleArmorRank;
  final ValueChanged<int>? onCycleArmorVersion;

  const FriendsSection({
    super.key,
    required this.t,
    required this.themedLabel,
    required this.running,
    required this.isPremium,
    required this.frAtk,
    required this.frDef,
    required this.frHp,
    required this.frElements,
    required this.frAdv,
    required this.frStun,
    required this.armorImportSummaries,
    required this.armorImportSnapshots,
    this.universalScoreLabelBuilder,
    required this.canRecalculateArmor,
    required this.onElementCycle,
    this.onOpenFavoriteArmors,
    this.onRecalculateArmor,
    this.onCycleArmorRole,
    this.onCycleArmorRank,
    this.onCycleArmorVersion,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('friends', 'Friends'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          if (!isPremium)
            Text(
              t(
                'friends.premium_only',
                'Friends section is available after upgrading to Premium.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            )
          else ...[
            for (int i = 0; i < 2; i++) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'FR#${i + 1}',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('friend-favorite-armor-$i'),
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
                    key: ValueKey('friend-recalculate-armor-$i'),
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
                      key: ValueKey('friend-armor-role-$i'),
                      label: Text(_roleLabel(armorImportSnapshots[i]!.role)),
                      onPressed: (running || onCycleArmorRole == null)
                          ? null
                          : () => onCycleArmorRole!(i),
                    ),
                    ActionChip(
                      key: ValueKey('friend-armor-rank-$i'),
                      label: Text(_rankLabel(armorImportSnapshots[i]!.rank)),
                      onPressed: (running || onCycleArmorRank == null)
                          ? null
                          : () => onCycleArmorRank!(i),
                    ),
                    ActionChip(
                      key: ValueKey('friend-armor-version-$i'),
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
                    frAtk[i],
                    frDef[i],
                    frHp[i],
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
              Row(
                children: [
                  Expanded(
                    child: LabeledField(
                      label: t('atk', 'ATK'),
                      labelStyle: themedLabel,
                      child: CompactGroupedIntField(
                        controller: frAtk[i],
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
                        controller: frDef[i],
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
                        controller: frHp[i],
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
                        first: frElements[i][0],
                        second: frElements[i][1],
                        onCycle: (elementIndex) =>
                            onElementCycle(i, elementIndex),
                        enabled: !running,
                        t: t,
                        trailing: Text(
                          formatMultiplier(frAdv[i]),
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
                        controller: frStun[i],
                        hint: '0',
                        enabled: !running,
                      ),
                    ),
                  ),
                ],
              ),
              if (i != 1) const Divider(height: 18),
            ],
          ],
        ],
      ),
    );
  }
}
