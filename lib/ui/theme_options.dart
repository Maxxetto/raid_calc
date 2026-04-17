import 'package:flutter/material.dart';

import 'theme_helpers.dart';

class ThemeOption {
  final String id;
  final String labelKey;
  final String fallback;
  final Color seed;

  const ThemeOption({
    required this.id,
    required this.labelKey,
    required this.fallback,
    required this.seed,
  });
}

const List<ThemeOption> themeOptions = <ThemeOption>[
  ThemeOption(
    id: 'sky',
    labelKey: 'theme.sky',
    fallback: 'Sky',
    seed: Color(0xFF88D1FF),
  ),
  ThemeOption(
    id: 'strawberry',
    labelKey: 'theme.strawberry',
    fallback: 'Strawberry',
    seed: Color(0xFFFF9BB1),
  ),
  ThemeOption(
    id: 'mint',
    labelKey: 'theme.mint',
    fallback: 'Mint',
    seed: Color(0xFF8EE9CD),
  ),
  ThemeOption(
    id: 'orange',
    labelKey: 'theme.orange',
    fallback: 'Orange',
    seed: Color(0xFFFFC07A),
  ),
  ThemeOption(
    id: 'pineapple',
    labelKey: 'theme.pineapple',
    fallback: 'Pineapple',
    seed: Color(0xFFFFE08A),
  ),
  ThemeOption(
    id: 'ocean',
    labelKey: 'theme.ocean',
    fallback: 'Ocean',
    seed: Color(0xFF7AB8FF),
  ),
  ThemeOption(
    id: 'forest',
    labelKey: 'theme.forest',
    fallback: 'Forest',
    seed: Color(0xFF7ACB8A),
  ),
];

ThemeOption resolveThemeOption(String? id) {
  if (id != null) {
    for (final opt in themeOptions) {
      if (opt.id == id) return opt;
    }
  }
  return themeOptions.first;
}

ThemeData buildSeededTheme(
  ThemeData base,
  String? themeId, {
  bool amoled = false,
}) {
  final opt = resolveThemeOption(themeId);
  final brightness = amoled ? Brightness.dark : base.colorScheme.brightness;
  final seeded = ColorScheme.fromSeed(
    seedColor: opt.seed,
    brightness: brightness,
  );
  final seed = opt.seed;
  final onSeed = (ThemeData.estimateBrightnessForColor(seed) == Brightness.dark)
      ? Colors.white
      : Colors.black;
  var scheme = seeded.copyWith(
    primary: seed,
    onPrimary: onSeed,
    primaryContainer: seed.withValues(alpha: 0.15),
    onPrimaryContainer: onSeed,
    secondary: seed,
    onSecondary: onSeed,
    secondaryContainer: seed.withValues(alpha: 0.15),
    onSecondaryContainer: onSeed,
    tertiary: seed,
    onTertiary: onSeed,
    tertiaryContainer: seed.withValues(alpha: 0.15),
    onTertiaryContainer: onSeed,
    surfaceTint: seed,
    error: seeded.error,
    onError: seeded.onError,
    errorContainer: seeded.errorContainer,
    onErrorContainer: seeded.onErrorContainer,
  );

  if (amoled) {
    scheme = scheme.copyWith(
      surface: Colors.black,
      surfaceDim: Colors.black,
      surfaceBright: const Color(0xFF101010),
      surfaceContainerLowest: Colors.black,
      surfaceContainerLow: const Color(0xFF060606),
      surfaceContainer: const Color(0xFF0A0A0A),
      surfaceContainerHigh: const Color(0xFF111111),
      surfaceContainerHighest: const Color(0xFF181818),
    );
  }

  final bumpedText = bumpTextTheme(base.textTheme, 1.0).apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  final background = amoled ? Colors.black : base.scaffoldBackgroundColor;
  final sheetColor =
      amoled ? scheme.surfaceContainer : base.bottomSheetTheme.backgroundColor;
  final dialogBg =
      amoled ? scheme.surfaceContainer : base.dialogTheme.backgroundColor;

  return base.copyWith(
    brightness: scheme.brightness,
    colorScheme: scheme,
    textTheme: bumpedText,
    disabledColor: scheme.onSurface.withValues(alpha: 0.38),
    iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    primaryIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return scheme.onSurface.withValues(alpha: 0.38);
          }
          return scheme.onSurfaceVariant;
        }),
      ),
    ),
    scaffoldBackgroundColor: background,
    canvasColor: background,
    cardColor: amoled ? scheme.surfaceContainerLow : base.cardColor,
    dividerColor:
        amoled ? Colors.white.withValues(alpha: 0.14) : base.dividerColor,
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: amoled ? Colors.black : base.appBarTheme.backgroundColor,
      surfaceTintColor:
          amoled ? Colors.transparent : base.appBarTheme.surfaceTintColor,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      actionsIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      titleTextStyle: bumpedText.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    dialogTheme: base.dialogTheme.copyWith(backgroundColor: dialogBg),
    bottomSheetTheme:
        base.bottomSheetTheme.copyWith(backgroundColor: sheetColor),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.primary.withValues(alpha: 0.18),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.all(scheme.primary),
      trackColor: WidgetStateProperty.all(
        scheme.primary.withValues(alpha: 0.35),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(scheme.primary),
        foregroundColor: WidgetStateProperty.all(scheme.onPrimary),
      ),
    ),
  );
}
