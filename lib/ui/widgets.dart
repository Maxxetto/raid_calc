// lib/ui/widgets.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'home_constants.dart';

class ModeToggleButton extends StatelessWidget {
  final bool isRaid;
  final VoidCallback onToggle;
  final String raidLabel;
  final String blitzLabel;

  const ModeToggleButton({
    super.key,
    required this.isRaid,
    required this.onToggle,
    required this.raidLabel,
    required this.blitzLabel,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment<bool>(value: true, label: Text(raidLabel)),
        ButtonSegment<bool>(value: false, label: Text(blitzLabel)),
      ],
      selected: {isRaid},
      onSelectionChanged: (_) => onToggle(),
    );
  }
}

/// Boss mode selector (Raid / Blitz / Epic).
///
/// Values are stringly-typed on purpose to keep this widget independent from
/// HomePage private enums.
class BossModeToggleButton extends StatelessWidget {
  static const String raid = 'raid';
  static const String blitz = 'blitz';
  static const String epic = 'epic';

  final String value;
  final ValueChanged<String> onChanged;
  final String raidLabel;
  final String blitzLabel;
  final String epicLabel;
  final bool enabled;

  const BossModeToggleButton({
    super.key,
    required this.value,
    required this.onChanged,
    required this.raidLabel,
    required this.blitzLabel,
    required this.epicLabel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment<String>(
          value: raid,
          label: Text(
            raidLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ButtonSegment<String>(
          value: blitz,
          label: Text(
            blitzLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ButtonSegment<String>(
          value: epic,
          label: Text(
            epicLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      selected: {value},
      onSelectionChanged: enabled
          ? (s) {
              if (s.isEmpty) return;
              onChanged(s.first);
            }
          : null,
    );
  }
}

class PremiumStarButton extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onTap;
  final String tooltip;

  const PremiumStarButton({
    super.key,
    required this.isPremium,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      icon: Icon(
        isPremium ? Icons.star : Icons.star_border,
        semanticLabel: tooltip,
        color: isPremium ? Theme.of(context).colorScheme.primary : null,
      ),
      onPressed: onTap,
    );
  }
}

class DebugBugButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  final String tooltip;

  const DebugBugButton({
    super.key,
    required this.enabled,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fontSize = Theme.of(context).textTheme.titleMedium?.fontSize ?? 18;
    return Semantics(
      label: tooltip,
      button: true,
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(
          Icons.bug_report,
          semanticLabel: tooltip,
          size: fontSize,
          color: enabled ? cs.tertiary : cs.onSurfaceVariant,
        ),
        onPressed: onTap,
      ),
    );
  }
}

class AppShortcutSheetItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? iconColor;
  final Key? tileKey;

  const AppShortcutSheetItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
    this.iconColor,
    this.tileKey,
  });
}

class AppBarShortcutsMenuButton extends StatelessWidget {
  final String tooltip;
  final String title;
  final List<AppShortcutSheetItem> items;
  final Key? buttonKey;

  const AppBarShortcutsMenuButton({
    super.key,
    required this.tooltip,
    required this.title,
    required this.items,
    this.buttonKey,
  });

  Future<void> _openSheet(BuildContext context) async {
    final visibleItems = items.where((item) => item.label.trim().isNotEmpty);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in visibleItems)
                    ListTile(
                      key: item.tileKey,
                      enabled: item.enabled,
                      leading: Icon(
                        item.icon,
                        color: item.enabled
                            ? item.iconColor
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                      title: Text(item.label),
                      onTap: item.enabled && item.onTap != null
                          ? () {
                              Navigator.of(ctx).pop();
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                item.onTap!.call();
                              });
                            }
                          : null,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    Widget miniIcon(IconData icon, Color color) {
      return Icon(icon, size: 14, color: color);
    }

    return Tooltip(
      message: tooltip,
      child: Semantics(
        label: tooltip,
        button: true,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: buttonKey,
              borderRadius: BorderRadius.circular(999),
              onTap: () => _openSheet(context),
              child: Ink(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.82),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.9),
                  ),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    miniIcon(Icons.auto_awesome_rounded, cs.primary),
                    const SizedBox(width: 5),
                    miniIcon(Icons.history_rounded, cs.secondary),
                    const SizedBox(width: 5),
                    miniIcon(Icons.palette_outlined, cs.tertiary),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: cs.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CompactCard extends StatelessWidget {
  final Widget child;

  const CompactCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: HomeUI.cardDecoration(theme),
      padding: const EdgeInsets.all(12),
      child: child,
    );
  }
}

class LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  final TextStyle? labelStyle;

  const LabeledField({
    super.key,
    required this.label,
    required this.child,
    this.labelStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: labelStyle ??
              theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class ThousandsSeparatorInputFormatter extends TextInputFormatter {
  final String separator;

  ThousandsSeparatorInputFormatter({this.separator = ','});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final raw = newValue.text;
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    final formatted = _formatDigits(digits);

    // Cursor: map "digits to the left" -> position in formatted text.
    final base = newValue.selection.baseOffset.clamp(0, raw.length);
    final digitsLeft = _countDigits(raw.substring(0, base));
    final newCursor = _cursorForDigitsLeft(formatted, digitsLeft);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  String _formatDigits(String digits) {
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      final idxFromEnd = digits.length - i;
      buf.write(digits[i]);
      final isGroupPos = idxFromEnd > 1 && (idxFromEnd - 1) % 3 == 0;
      if (isGroupPos) buf.write(separator);
    }
    return buf.toString();
  }

  int _countDigits(String s) => RegExp(r'[0-9]').allMatches(s).length;

  int _cursorForDigitsLeft(String formatted, int digitsLeft) {
    if (digitsLeft <= 0) return 0;
    var seen = 0;
    for (int i = 0; i < formatted.length; i++) {
      final cu = formatted.codeUnitAt(i);
      if (cu >= 48 && cu <= 57) {
        seen++;
        if (seen >= digitsLeft) return i + 1;
      }
    }
    return formatted.length;
  }
}

class CompactNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;

  const CompactNumberField({
    super.key,
    required this.controller,
    required this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

/// Integer-only numeric field (digits only).
class CompactIntField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;

  const CompactIntField({
    super.key,
    required this.controller,
    required this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

/// Integer field with thousands separators (US style, e.g. 1,000,000).
class CompactGroupedIntField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool enabled;

  const CompactGroupedIntField({
    super.key,
    required this.controller,
    required this.hint,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [ThousandsSeparatorInputFormatter(separator: ',')],
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}

class SmallSwitchTile extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const SmallSwitchTile({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title)),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
