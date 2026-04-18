import 'package:flutter/material.dart';

import '../../core/element_types.dart';
import '../widgets.dart';
import 'element_selector.dart';

class BossSection extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final TextStyle themedLabel;
  final bool running;
  final bool isEpic;
  final bool isPremium;
  final String bossMode;
  final int bossLevel;
  final List<int> bossLevels;
  final List<ElementType> bossElements;
  final List<double> bossAdvVsK;
  final List<double> bossAdvVsF;
  final TextEditingController milestoneTargetCtl;
  final TextEditingController startEnergiesCtl;
  final TextEditingController epicThresholdCtl;
  final int epicThresholdDefault;
  final ValueChanged<String> onBossModeChanged;
  final ValueChanged<int> onBossLevelChanged;
  final ValueChanged<int> onBossElementCycle;

  const BossSection({
    super.key,
    required this.t,
    required this.themedLabel,
    required this.running,
    required this.isEpic,
    required this.isPremium,
    required this.bossMode,
    required this.bossLevel,
    required this.bossLevels,
    required this.bossElements,
    required this.bossAdvVsK,
    required this.bossAdvVsF,
    required this.milestoneTargetCtl,
    required this.startEnergiesCtl,
    required this.epicThresholdCtl,
    required this.epicThresholdDefault,
    required this.onBossModeChanged,
    required this.onBossLevelChanged,
    required this.onBossElementCycle,
  });

  Widget _buildBossMultipliers(TextStyle style) {
    final items = <Widget>[
      for (int i = 0; i < bossAdvVsK.length; i++)
        Text('K${i + 1} ${formatMultiplier(bossAdvVsK[i])}', style: style),
    ];
    if (isEpic && isPremium) {
      for (int i = 0; i < bossAdvVsF.length; i++) {
        items.add(
          Text('FR${i + 1} ${formatMultiplier(bossAdvVsF[i])}', style: style),
        );
      }
    }
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      children: items,
    );
  }

  Future<void> _showBossTip(BuildContext context) {
    final title = t('boss.tip.title', 'Boss tip');
    final modeSpecific = isEpic
        ? t(
            'boss.tip.epic',
            'Select boss elements and the minimum victory threshold you are interested in.',
          )
        : t(
            'boss.tip.raid_blitz',
            'Select the boss level and elements you want to simulate, plus the milestone you want to reach for the gem cost calculation.',
          );
    final autoAdv = t(
      'boss.tip.auto_advantage',
      'Boss advantage is calculated automatically based on the selected elements.',
    );
    final epicPremiumFriends = isEpic
        ? t(
            'boss.tip.epic_premium_friends',
            'With Premium active, 2 Friends slots are unlocked for Epic Boss.',
          )
        : null;

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          [
            modeSpecific,
            if (epicPremiumFriends != null) epicPremiumFriends,
            autoAdv,
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
                  t('section.boss', 'Boss'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('boss-tip-button'),
                tooltip: t('boss.tip.title', 'Boss tip'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                icon: const Icon(Icons.info_outline, size: 18),
                onPressed: () => _showBossTip(context),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: LabeledField(
                  label: t('boss.mode', 'Boss Mode'),
                  labelStyle: themedLabel,
                  child: BossModeToggleButton(
                    value: bossMode,
                    enabled: !running,
                    onChanged: onBossModeChanged,
                    raidLabel: t('raid', 'Raid'),
                    blitzLabel: t('blitz', 'Blitz'),
                    epicLabel: t('epic', 'Epic'),
                  ),
                ),
              ),
              if (isEpic) ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 124,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        t('epic.threshold', 'Threshold'),
                        style: themedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 64,
                            child: CompactIntField(
                              controller: epicThresholdCtl,
                              hint: epicThresholdDefault.toString(),
                              enabled: !running,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('%', style: themedLabel),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(width: 12),
                SizedBox(
                  width: 112,
                  child: LabeledField(
                    label: t('boss.level', 'Livello'),
                    labelStyle: themedLabel,
                    child: DropdownButtonFormField<int>(
                      key: const ValueKey('boss-level-dropdown'),
                      initialValue: bossLevel,
                      items: bossLevels
                          .map(
                            (v) => DropdownMenuItem(
                              value: v,
                              child: Text('L$v'),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: running
                          ? null
                          : (v) {
                              if (v == null) return;
                              onBossLevelChanged(v);
                            },
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (!isEpic) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: LabeledField(
                    label: t('milestone_required', 'Milestone richiesta'),
                    labelStyle: themedLabel,
                    child: CompactGroupedIntField(
                      controller: milestoneTargetCtl,
                      hint: '1,000,000,000',
                      enabled: !running,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: LabeledField(
                    label: t('energies_available', 'Energie disponibili'),
                    labelStyle: themedLabel,
                    child: CompactIntField(
                      controller: startEnergiesCtl,
                      hint: '0',
                      enabled: !running,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Text(
            t('boss.elements', 'Boss elements'),
            style: themedLabel,
          ),
          const SizedBox(height: 8),
          ElementPairRow(
            first: bossElements[0],
            second: bossElements[1],
            onCycle: onBossElementCycle,
            enabled: !running,
            t: t,
          ),
          const SizedBox(height: 6),
          _buildBossMultipliers(themedLabel),
        ],
      ),
    );
  }
}
