import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/config_models.dart';
import 'home_state.dart';
import '../widgets.dart';

class ElixirsSection extends StatelessWidget {
  final String Function(String key, String fallback) t;
  final TextStyle themedLabel;
  final Color accent;
  final bool running;
  final bool isPremium;
  final List<ElixirConfig> elixirs;
  final List<ElixirItem> inventory;
  final Key dropdownKey;
  final int maxElixirs;
  final ValueChanged<String> onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<ElixirItem> onQtyChanged;

  const ElixirsSection({
    super.key,
    required this.t,
    required this.themedLabel,
    required this.accent,
    required this.running,
    required this.isPremium,
    required this.elixirs,
    required this.inventory,
    required this.dropdownKey,
    required this.maxElixirs,
    required this.onAdd,
    required this.onRemove,
    required this.onQtyChanged,
  });

  Future<void> _showElixirsTip(BuildContext context) {
    final title = t('elixirs.tip.title', 'Elixirs tip');
    final body = t(
      'elixirs.tip.body',
      'Elixirs provide a points boost for a limited time and are used in the gem cost calculation to reach the required milestone. They are applied in the same order you add them. Free users can add up to 5 elixirs, while Premium users can select all available elixirs.',
    );
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
                  t('elixirs.title', 'Inventario Elixirs'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('elixirs-tip-button'),
                tooltip: t('elixirs.tip.title', 'Elixirs tip'),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 24,
                  height: 24,
                ),
                color: theme.colorScheme.onSurfaceVariant,
                onPressed: () => _showElixirsTip(context),
                icon: const Icon(Icons.info_outline, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LabeledField(
            label: t('elixirs.add', 'Aggiungi elixir'),
            labelStyle: themedLabel,
            child: Builder(
              builder: (_) {
                final available = elixirs
                    .where(
                      (e) => !inventory.any((i) => i.config.name == e.name),
                    )
                    .toList(growable: false);

                final canPick = !running &&
                    available.isNotEmpty &&
                    inventory.length < maxElixirs;

                return DropdownButtonFormField<String>(
                  key: dropdownKey,
                  items: available
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.name,
                          child: Text(e.name),
                        ),
                      )
                      .toList(growable: false),
                  initialValue: null,
                  onChanged: canPick
                      ? (v) {
                          if (v == null) return;
                          onAdd(v);
                        }
                      : null,
                  decoration: const InputDecoration(
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  hint: Text(
                    t('elixirs.add', 'Aggiungi elixir'),
                  ),
                );
              },
            ),
          ),
          if (inventory.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (int i = 0; i < inventory.length; i++) ...[
              _ElixirRow(
                item: inventory[i],
                accent: accent,
                running: running,
                qtyHint: t('elixirs.qty', 'Qty'),
                deleteTooltip: t('elixirs.delete', 'Remove'),
                onQtyChanged: () => onQtyChanged(inventory[i]),
                onRemove: () => onRemove(i),
              ),
              if (i != inventory.length - 1) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }
}

class _ElixirRow extends StatelessWidget {
  final ElixirItem item;
  final Color accent;
  final bool running;
  final String qtyHint;
  final String deleteTooltip;
  final VoidCallback onQtyChanged;
  final VoidCallback onRemove;

  const _ElixirRow({
    required this.item,
    required this.accent,
    required this.running,
    required this.qtyHint,
    required this.deleteTooltip,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final bonusPct = (item.config.scoreMultiplier * 100).toStringAsFixed(0);
    final minutes = item.config.durationMinutes;
    final textStyle = Theme.of(context).textTheme.bodySmall;

    return Row(
      children: [
        Expanded(
          flex: 3,
          child: Text(
            item.config.name,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            '+$bonusPct%',
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          flex: 2,
          child: Text(
            '${minutes}m',
            style: textStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: TextField(
            controller: item.qty,
            enabled: !running,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: InputDecoration(
              hintText: qtyHint,
              isDense: true,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            onChanged: (_) => onQtyChanged(),
          ),
        ),
        IconButton(
          tooltip: deleteTooltip,
          icon: const Icon(Icons.delete_outline),
          onPressed: running ? null : onRemove,
        ),
      ],
    );
  }
}
