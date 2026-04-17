import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'home_state.dart';
import '../../util/format.dart';
import '../widgets.dart';

class RunParametersSection extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final TextStyle themedLabel;
  final bool running;
  final bool debugEnabled;
  final bool isEpic;
  final bool isPremium;
  final TextEditingController runsCtl;
  final List<bool> activeKnights;
  final List<bool> activeFriends;
  final void Function(int index, bool value) onKnightActiveChanged;
  final void Function(int index, bool value) onFriendActiveChanged;
  final VoidCallback onSimulate;
  final bool canStop;
  final VoidCallback? onStop;
  final bool canBulkSimulate;
  final bool bulkRunning;
  final VoidCallback onBulkSimulate;
  final bool canWardrobeSimulate;
  final bool wardrobeSimulating;
  final VoidCallback? onWardrobeSimulate;
  final List<int> bulkSlots;
  final List<ProgressInfo?> bulkProgresses;
  final ValueListenable<ProgressInfo> progress;
  final ValueListenable<double> debugProgress;

  const RunParametersSection({
    super.key,
    required this.t,
    required this.themedLabel,
    required this.running,
    required this.debugEnabled,
    required this.isEpic,
    required this.isPremium,
    required this.runsCtl,
    required this.activeKnights,
    required this.activeFriends,
    required this.onKnightActiveChanged,
    required this.onFriendActiveChanged,
    required this.onSimulate,
    this.canStop = false,
    this.onStop,
    required this.canBulkSimulate,
    required this.bulkRunning,
    required this.onBulkSimulate,
    this.canWardrobeSimulate = false,
    this.wardrobeSimulating = false,
    this.onWardrobeSimulate,
    required this.bulkSlots,
    required this.bulkProgresses,
    required this.progress,
    required this.debugProgress,
  });

  String _toggleLabel(String key, bool enabled) {
    final on = t('toggle.on', 'ON');
    final off = t('toggle.off', 'OFF');
    return '$key ${enabled ? on : off}';
  }

  Widget _buildKnightToggles(BuildContext context) {
    final chips = <Widget>[];
    for (int i = 0; i < activeKnights.length; i++) {
      final value = activeKnights[i];
      chips.add(
        FilterChip(
          label: Text(_toggleLabel('K${i + 1}', value)),
          selected: value,
          onSelected: running
              ? null
              : (next) {
                  onKnightActiveChanged(i, next);
                },
        ),
      );
    }
    if (isPremium) {
      for (int i = 0; i < activeFriends.length; i++) {
        final value = activeFriends[i];
        chips.add(
          FilterChip(
            label: Text(_toggleLabel('FR${i + 1}', value)),
            selected: value,
            onSelected: running
                ? null
                : (next) {
                    onFriendActiveChanged(i, next);
                  },
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t('active_knights', 'Active knights'),
          style: themedLabel,
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: chips,
        ),
      ],
    );
  }

  Future<void> _showRunParametersTip(BuildContext context) {
    final title = t('run_parameters.tip.title', 'Run parameters tip');
    final parts = <String>[
      t(
        'run_parameters.tip.runs',
        'The simulator is very powerful, so you can also run very high simulation counts (even above 500k runs).',
      ),
      t(
        'run_parameters.tip.toggles',
        'The ON/OFF buttons enable or disable the knights used in the simulation. In Epic Boss, Premium users can also toggle 2 Friends slots.',
      ),
    ];
    if (!isEpic) {
      parts.add(
        t(
          'run_parameters.tip.bulk',
          'After saving setups, you can use Bulk Simulate to run all saved setups sequentially (up to 3 setups, or up to 5 with Premium).',
        ),
      );
    }

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(parts.join('\n\n')),
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
    final showStop = running && canStop && onStop != null;

    return CompactCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t('run_parameters', 'Parametri di esecuzione'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('run-parameters-tip-button'),
                tooltip: t('run_parameters.tip.title', 'Run parameters tip'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => _showRunParametersTip(context),
                icon: const Icon(Icons.info_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildKnightToggles(context),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: LabeledField(
                    label: t('simulations', 'Numero simulazioni'),
                    labelStyle: themedLabel,
                    child: CompactGroupedIntField(
                      controller: runsCtl,
                      hint: '100,000',
                      enabled: !running && !debugEnabled && !isEpic,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: showStop
                      ? onStop
                      : (running ? null : onSimulate),
                  icon: Icon(
                    showStop ? Icons.stop_rounded : Icons.play_arrow,
                    size: 20,
                  ),
                  label: Text(
                    showStop ? t('stop', 'Stop') : t('simulate', 'Simula'),
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: showStop
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    foregroundColor: showStop
                        ? theme.colorScheme.onError
                        : theme.colorScheme.onPrimary,
                    disabledBackgroundColor:
                        (showStop
                                ? theme.colorScheme.error
                                : theme.colorScheme.primary)
                            .withValues(alpha: 0.55),
                    disabledForegroundColor:
                        (showStop
                                ? theme.colorScheme.onError
                                : theme.colorScheme.onPrimary)
                            .withValues(alpha: 0.6),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              ),
            ],
          ),
          if (canBulkSimulate || bulkRunning) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  key: const ValueKey('bulk-simulate-button'),
                  onPressed: running ? null : onBulkSimulate,
                  icon: const Icon(Icons.playlist_play, size: 20),
                  label: Text(t('bulk_simulate', 'Bulk Simulate')),
                ),
              ),
            ),
          ],
          if (canWardrobeSimulate || wardrobeSimulating) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  key: const ValueKey('wardrobe-simulate-button'),
                  onPressed: running ? null : onWardrobeSimulate,
                  icon: const Icon(Icons.auto_awesome_motion, size: 18),
                  label: Text(
                    t('wardrobe_simulate.title', 'Wardrobe Simulate'),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ValueListenableBuilder<ProgressInfo>(
            valueListenable: progress,
            builder: (_, p, __) {
              if (!running || debugEnabled || bulkRunning) {
                return const SizedBox.shrink();
              }
              final frac = (p.total <= 0) ? 0.0 : (p.done / p.total);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (wardrobeSimulating) ...[
                    Text(
                      t('wardrobe_simulate.title', 'Wardrobe Simulate'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  LinearProgressIndicator(
                    value: frac.clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${fmtInt(p.done.floor())}/${fmtInt(p.total)}'),
                      Text('${(frac * 100).toStringAsFixed(2)}%'),
                    ],
                  ),
                ],
              );
            },
          ),
          ValueListenableBuilder<double>(
            valueListenable: debugProgress,
            builder: (_, v, __) {
              if (!running || !debugEnabled || isEpic) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: v.clamp(0.0, 1.0)),
                  const SizedBox(height: 6),
                  Text('${(v * 100).toStringAsFixed(2)}%'),
                ],
              );
            },
          ),
          if (bulkRunning) ...[
            const SizedBox(height: 10),
            for (int i = 0; i < bulkSlots.length; i++) ...[
              _BulkSlotProgressRow(
                key: ValueKey('bulk-progress-slot-${bulkSlots[i]}'),
                slot: bulkSlots[i],
                progress:
                    (i < bulkProgresses.length) ? bulkProgresses[i] : null,
                t: t,
              ),
              if (i != bulkSlots.length - 1) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _BulkSlotProgressRow extends StatelessWidget {
  final int slot;
  final ProgressInfo? progress;
  final String Function(String key, String fallback) t;

  const _BulkSlotProgressRow({
    super.key,
    required this.slot,
    required this.progress,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final done = p?.done ?? 0.0;
    final total = p?.total ?? 0.0;
    final frac = (total <= 0) ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${t('setups.slot', 'Slot')} $slot',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: frac),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              total > 0 ? '${fmtInt(done.floor())}/${fmtInt(total)}' : '0/0',
            ),
            Text('${(frac * 100).toStringAsFixed(2)}%'),
          ],
        ),
      ],
    );
  }
}
