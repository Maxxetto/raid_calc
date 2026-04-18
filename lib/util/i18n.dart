// lib/util/i18n.dart
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'text_encoding_guard.dart';

/// Lightweight i18n loader with EN fallback.
///
/// Supported JSON formats:
///
/// A) Split assets:
/// - `assets/langs/manifest.json`
/// - `assets/langs/en.json`
/// - `assets/langs/it.json`
/// - ...
///
/// Fallback rules:
/// - If a key is missing (or empty) in the selected language, we fall back to EN.
/// - If a key is missing even in EN, we fall back to the provided [fallback] or the key itself.
/// - For compatibility with historical key styles, lookups try a few variants
///   (e.g. `app.title` <-> `app_title`).
class I18n {
  final String code;
  final Map<String, String> map;

  const I18n(this.code, this.map);

  /// Populated on first load (kept synchronous-friendly for UI menus).
  static List<String> supported = <String>[
    'en',
    'it',
    'fr',
    'de',
    'es',
    'nl',
    'da',
    'tr',
    'pl',
    'ar',
    'ru',
    'zh',
    'ja',
  ];

  static const Map<String, String> _nativeNames = <String, String>{
    'en': 'English',
    'it': 'Italiano',
    'fr': 'Fran\u00e7ais',
    'de': 'Deutsch',
    'es': 'Espa\u00f1ol',
    'nl': 'Nederlands',
    'da': 'Dansk',
    'tr': 'T\u00fcrk\u00e7e',
    'pl': 'Polski',
    'ar': '\u0627\u0644\u0639\u0631\u0628\u064a\u0629',
    'ru': '\u0420\u0443\u0441\u0441\u043a\u0438\u0439',
    'zh': '\u4e2d\u6587',
    'ja': '\u65e5\u672c\u8a9e',
  };

  static String nativeName(String code) => _nativeNames[code] ?? code;

  /// Translate key with EN fallback.
  ///
  /// Important: [fallback] is only used if the key is missing even in EN.
  String t(String key, [String? fallback]) {
    for (final k in _keyVariants(key)) {
      final v = map[k];
      if (v != null && v.isNotEmpty) return v;
    }
    return fallback ?? key;
  }

  /// Loads translations from assets, always guaranteeing EN fallback.
  static Future<I18n> fromAssets(String code) async {
    final bundle = await _LangBundle.load();

    // Update supported list dynamically if the asset declares it.
    if (bundle.langs.isNotEmpty) {
      supported = List<String>.unmodifiable(bundle.langs);
    }

    final String resolved = bundle.langs.contains(code) ? code : 'en';
    final map = bundle.buildMergedMap(resolved);
    return I18n(resolved, map);
  }

  static Iterable<String> _keyVariants(String key) sync* {
    // Exact
    yield key;

    // Common legacy conversions
    final dotToUnd = key.replaceAll('.', '_').replaceAll('-', '_');
    if (dotToUnd != key) yield dotToUnd;

    final undToDot = key.replaceAll('_', '.');
    if (undToDot != key) yield undToDot;

    final undToDash = key.replaceAll('_', '-');
    if (undToDash != key) yield undToDash;

    final dashToUnd = key.replaceAll('-', '_');
    if (dashToUnd != key && dashToUnd != dotToUnd) yield dashToUnd;
  }
}

/// Internal cache of the language bundle.
class _LangBundle {
  _LangBundle._(
    this.langs,
    this.en,
    this.byLang,
  );

  final List<String> langs;
  final Map<String, String> en;
  final Map<String, Map<String, String>> byLang; // includes 'en'

  static _LangBundle? _cache;

  static Future<_LangBundle> load() async {
    final c = _cache;
    if (c != null) return c;

    final splitBundle = await _tryLoadSplitAssets();
    if (splitBundle == null) {
      throw StateError('Split language assets are missing or invalid.');
    }
    _cache = splitBundle;
    return splitBundle;
  }

  Map<String, String> buildMergedMap(String code) {
    if (code == 'en') return Map<String, String>.unmodifiable(en);
    final m = byLang[code];
    if (m == null) return Map<String, String>.unmodifiable(en);
    // Already contains EN fallback; expose immutable copy.
    return Map<String, String>.unmodifiable(m);
  }

  static Future<_LangBundle?> _tryLoadSplitAssets() async {
    try {
      final rawManifest =
          await rootBundle.loadString('assets/langs/manifest.json');
      final decoded = jsonDecode(rawManifest);
      final manifest = decoded is List
          ? decoded.cast<Object?>()
          : (decoded as Map).cast<String, Object?>()['langs'] as List?;
      if (manifest == null) return null;

      final langs = <String>[
        for (final value in manifest)
          if ((value ?? '').toString().trim().isNotEmpty)
            value.toString().trim(),
      ];
      if (langs.isEmpty || !langs.contains('en')) {
        return null;
      }

      final byLang = <String, Map<String, String>>{};
      for (final lang in langs) {
        final raw = await rootBundle.loadString('assets/langs/$lang.json');
        final decodedMap = jsonDecode(raw);
        if (decodedMap is! Map) {
          throw StateError('assets/langs/$lang.json is not a JSON object');
        }
        final out = <String, String>{};
        decodedMap.cast<String, Object?>().forEach((key, value) {
          if (value is String && value.trim().isNotEmpty) {
            out[key] = TextEncodingGuard.repairLikelyMojibake(value);
          }
        });
        byLang[lang] = out;
      }

      final en = Map<String, String>.from(byLang['en'] ?? const {});
      for (final lang in langs) {
        if (lang == 'en') continue;
        final map = byLang[lang]!;
        for (final entry in en.entries) {
          map.putIfAbsent(entry.key, () => entry.value);
        }
      }

      return _LangBundle._(langs, en, byLang);
    } catch (_) {
      return null;
    }
  }
}
