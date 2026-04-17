import 'package:flutter/material.dart';

TextTheme bumpTextTheme(TextTheme base, double delta) {
  TextStyle? bump(TextStyle? s) {
    if (s == null) return null;
    final size = s.fontSize ?? 14.0;
    return s.copyWith(fontSize: size + delta);
  }

  return base.copyWith(
    displayLarge: bump(base.displayLarge),
    displayMedium: bump(base.displayMedium),
    displaySmall: bump(base.displaySmall),
    headlineLarge: bump(base.headlineLarge),
    headlineMedium: bump(base.headlineMedium),
    headlineSmall: bump(base.headlineSmall),
    titleLarge: bump(base.titleLarge),
    titleMedium: bump(base.titleMedium),
    titleSmall: bump(base.titleSmall),
    bodyLarge: bump(base.bodyLarge),
    bodyMedium: bump(base.bodyMedium),
    bodySmall: bump(base.bodySmall),
    labelLarge: bump(base.labelLarge),
    labelMedium: bump(base.labelMedium),
    labelSmall: bump(base.labelSmall),
  );
}

Color themedLabelColor(ThemeData theme) {
  final primary = theme.colorScheme.primary;
  final surface = theme.colorScheme.surface;
  final onSurface = theme.colorScheme.onSurface;
  if (_contrast(primary, surface) >= 3.0) return primary;

  // If primary is too light for small text, blend toward onSurface.
  for (double t = 0.1; t <= 1.0; t += 0.1) {
    final adjusted = Color.lerp(primary, onSurface, t)!;
    if (_contrast(adjusted, surface) >= 3.0) return adjusted;
  }
  return onSurface;
}

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}
