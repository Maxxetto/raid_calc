import 'package:flutter/material.dart';

enum ButtonStyleMode {
  silk,
  aurora,
  arcade,
}

extension ButtonStyleModeId on ButtonStyleMode {
  String get id => switch (this) {
        ButtonStyleMode.silk => 'silk',
        ButtonStyleMode.aurora => 'aurora',
        ButtonStyleMode.arcade => 'arcade',
      };
}

ButtonStyleMode buttonStyleFromId(String? id) {
  return switch (id) {
    'silk' => ButtonStyleMode.silk,
    'aurora' => ButtonStyleMode.aurora,
    'arcade' => ButtonStyleMode.arcade,
    _ => ButtonStyleMode.arcade,
  };
}

Color _shiftHue(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  final h = (hsl.hue + delta) % 360.0;
  return hsl.withHue(h).toColor();
}

Color _adjustLightness(Color c, double delta) {
  final hsl = HSLColor.fromColor(c);
  final l = (hsl.lightness + delta).clamp(0.0, 1.0);
  return hsl.withLightness(l).toColor();
}

class GradientButtonStyle {
  final LinearGradient gradient;
  final LinearGradient overlayGradient;
  final Color borderColor;
  final double borderWidth;
  final Color shadowColor;
  final double shadowBlur;
  final Offset shadowOffset;
  final Color textColor;

  const GradientButtonStyle({
    required this.gradient,
    required this.overlayGradient,
    required this.borderColor,
    required this.borderWidth,
    required this.shadowColor,
    required this.shadowBlur,
    required this.shadowOffset,
    required this.textColor,
  });
}

GradientButtonStyle resolveGradientStyle(
  Color base,
  ButtonStyleMode mode, {
  required bool enabled,
}) {
  final isDark = ThemeData.estimateBrightnessForColor(base) == Brightness.dark;
  final text = isDark ? Colors.white : Colors.black;
  final alpha = enabled ? 1.0 : 0.55;

  LinearGradient gradient;
  late final LinearGradient overlay;
  Color borderBase;
  Color shadowBase;
  double borderAlpha;
  double shadowAlpha;
  double borderWidth;
  double blur;
  Offset offset;

  switch (mode) {
    case ButtonStyleMode.silk:
      gradient = LinearGradient(
        colors: [
          _adjustLightness(_shiftHue(base, 6), 0.14),
          _adjustLightness(_shiftHue(base, -6), 0.06),
        ],
      );
      borderBase = Colors.white;
      shadowBase = base;
      borderAlpha = 0.18;
      shadowAlpha = 0.10;
      borderWidth = 0.9;
      blur = 4;
      offset = const Offset(0, 2);
      overlay = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      );
      break;
    case ButtonStyleMode.aurora:
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _adjustLightness(_shiftHue(base, 28), 0.30),
          _adjustLightness(_shiftHue(base, 8), 0.12),
          _adjustLightness(_shiftHue(base, -18), -0.02),
        ],
        stops: const [0.0, 0.45, 1.0],
      );
      borderBase = Colors.white;
      shadowBase = base;
      borderAlpha = 0.45;
      shadowAlpha = 0.45;
      borderWidth = 1.2;
      blur = 16;
      offset = const Offset(0, 6);
      overlay = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: 0.45),
          Colors.transparent,
          Colors.white.withValues(alpha: 0.12),
        ],
        stops: const [0.0, 0.55, 1.0],
      );
      break;
    case ButtonStyleMode.arcade:
      gradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          _adjustLightness(_shiftHue(base, 22), -0.06),
          _adjustLightness(_shiftHue(base, -18), 0.18),
        ],
      );
      borderBase = Colors.black;
      shadowBase = base;
      borderAlpha = 0.22;
      shadowAlpha = 0.55;
      borderWidth = 1.6;
      blur = 20;
      offset = const Offset(0, 7);
      overlay = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.20),
          Colors.transparent,
        ],
      );
      break;
  }

  return GradientButtonStyle(
    gradient: LinearGradient(
      colors: gradient.colors
          .map((c) => c.withValues(alpha: alpha))
          .toList(growable: false),
      begin: gradient.begin,
      end: gradient.end,
      stops: gradient.stops,
    ),
    overlayGradient: LinearGradient(
      colors: overlay.colors
          .map((c) => c.withValues(alpha: alpha))
          .toList(growable: false),
      begin: overlay.begin,
      end: overlay.end,
      stops: overlay.stops,
    ),
    borderColor: borderBase.withValues(alpha: borderAlpha * alpha),
    borderWidth: borderWidth,
    shadowColor: shadowBase.withValues(alpha: shadowAlpha * alpha),
    shadowBlur: blur,
    shadowOffset: offset,
    textColor: text.withValues(alpha: alpha),
  );
}

class GradientActionButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final Color baseColor;
  final ButtonStyleMode mode;
  final EdgeInsets padding;
  final double height;

  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.baseColor,
    required this.mode,
    this.icon,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.height = 42,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final style = resolveGradientStyle(baseColor, mode, enabled: enabled);
    final radius = BorderRadius.circular(20);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: style.shadowColor,
            blurRadius: style.shadowBlur,
            offset: style.shadowOffset,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: radius,
            child: Ink(
              height: height,
              padding: padding,
              decoration: BoxDecoration(
                gradient: style.gradient,
                borderRadius: radius,
                border: Border.all(
                  color: style.borderColor,
                  width: style.borderWidth,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: style.overlayGradient,
                          borderRadius: radius,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 20, color: style.textColor),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          label,
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: style.textColor,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.2,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
