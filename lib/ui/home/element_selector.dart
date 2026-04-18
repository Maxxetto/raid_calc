import 'package:flutter/material.dart';

import '../../core/element_types.dart';

Color elementColor(ElementType e) {
  return switch (e) {
    ElementType.fire => const Color(0xFFD84A3A), // ruby
    ElementType.spirit => const Color(0xFF8A56C7), // amethyst
    ElementType.earth => const Color(0xFF8D6E63), // earth/stone
    ElementType.air => const Color(0xFFB0BEC5), // opal/cloud
    ElementType.water => const Color(0xFF3B7DD8), // sapphire
    ElementType.starmetal => const Color(0xFF546E7A), // steel/stellar
  };
}

String elementLabel(ElementType e, String Function(String, String) t) {
  return switch (e) {
    ElementType.fire => t('element.fire', 'Fire'),
    ElementType.spirit => t('element.spirit', 'Spirit'),
    ElementType.earth => t('element.earth', 'Earth'),
    ElementType.air => t('element.air', 'Air'),
    ElementType.water => t('element.water', 'Water'),
    ElementType.starmetal => t('element.starmetal', 'Starmetal'),
  };
}

String formatMultiplier(double v) => 'x${v.toStringAsFixed(1)}';

class ElementButton extends StatelessWidget {
  final ElementType value;
  final VoidCallback? onPressed;
  final String Function(String, String) t;

  const ElementButton({
    super.key,
    required this.value,
    required this.onPressed,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    final base = elementColor(value);
    final enabled = onPressed != null;
    final isDark =
        ThemeData.estimateBrightnessForColor(base) == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return SizedBox(
      height: 38,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: enabled ? base : base.withValues(alpha: 0.55),
          foregroundColor: textColor.withValues(alpha: enabled ? 1.0 : 0.6),
          disabledBackgroundColor: base.withValues(alpha: 0.55),
          disabledForegroundColor: textColor.withValues(alpha: 0.6),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            elementLabel(value, t),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: textColor.withValues(alpha: enabled ? 1.0 : 0.6),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
          ),
        ),
      ),
    );
  }
}

class ElementPairRow extends StatelessWidget {
  final ElementType first;
  final ElementType second;
  final ValueChanged<int> onCycle;
  final bool enabled;
  final String Function(String, String) t;
  final Widget? trailing;

  const ElementPairRow({
    super.key,
    required this.first,
    required this.second,
    required this.onCycle,
    required this.enabled,
    required this.t,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElementButton(
            value: first,
            onPressed: enabled ? () => onCycle(0) : null,
            t: t,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ElementButton(
            value: second,
            onPressed: enabled ? () => onCycle(1) : null,
            t: t,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}
