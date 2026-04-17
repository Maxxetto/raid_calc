import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/util/i18n.dart';
import 'package:raid_calc/util/text_encoding_guard.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('I18n loads assets and theme keys', () async {
    final it = await I18n.fromAssets('it');

    expect(it.code, 'it');
    expect(I18n.supported.contains('it'), isTrue);
    expect(it.t('theme.sky', ''), 'Cielo');
    expect(it.t('theme.strawberry', ''), 'Fragola');
    expect(it.t('theme.mint', ''), 'Menta');
    expect(it.t('theme.orange', ''), 'Arancia');
    expect(it.t('theme.pineapple', ''), 'Ananas');
  });

  test('I18n falls back to EN for unsupported language code', () async {
    final en = await I18n.fromAssets('en');
    final xx = await I18n.fromAssets('xx');

    expect(xx.code, 'en');
    expect(xx.t('app_title', ''), en.t('app_title', ''));
  });

  test('split language assets have EN/IT values for every key', () async {
    final bundle = await _loadSplitLangs();
    final en = bundle['en']!;
    final it = bundle['it']!;

    final missing = <String>[];
    for (final key in en.keys) {
      if ((en[key] ?? '').trim().isEmpty) missing.add('en:$key');
    }
    for (final key in it.keys) {
      if ((it[key] ?? '').trim().isEmpty) missing.add('it:$key');
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing or empty EN/IT translations: ${missing.join(', ')}',
    );
  });

  test(
      'every non-empty EN key exists and is non-empty in every manifest language',
      () async {
    final bundle = await _loadSplitLangs();
    final manifestLangs = await _loadManifestLangs();
    final en = bundle['en']!;

    final missing = <String>[];
    for (final lang in manifestLangs) {
      final map = bundle[lang];
      if (map == null) {
        missing.add('$lang:<missing language file>');
        continue;
      }
      for (final entry in en.entries) {
        if (entry.value.trim().isEmpty) continue;
        final text = (map[entry.key] ?? '').trim();
        if (text.isEmpty) {
          missing.add('$lang:${entry.key}');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason:
          'Missing or empty translations for manifest languages: ${missing.join(', ')}',
    );
  });

  test('debug.log.line.* keys exist in split EN/IT assets', () async {
    final bundle = await _loadSplitLangs();
    final en = bundle['en']!;
    final it = bundle['it']!;
    final keys = en.keys.where((k) => k.startsWith('debug.log.line.')).toList()
      ..sort();
    expect(keys, isNotEmpty);

    final missing = <String>[];
    for (final key in keys) {
      if ((en[key] ?? '').trim().isEmpty) missing.add('en:$key');
      if ((it[key] ?? '').trim().isEmpty) missing.add('it:$key');
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing or empty debug.log.line.* EN/IT: ${missing.join(', ')}',
    );
  });

  test('all t(...) keys used in lib/ exist in split language assets', () async {
    final bundle = await _loadSplitLangs();
    final keysInAssets = bundle.values.expand((map) => map.keys).toSet();

    final tCallPattern = RegExp(r"\bt\(\s*'([^']+)'\s*,");
    final usedKeys = <String>{};

    for (final entity
        in Directory('lib').listSync(recursive: true, followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final src = entity.readAsStringSync();
      for (final match in tCallPattern.allMatches(src)) {
        final key = match.group(1);
        if (key != null && key.isNotEmpty && !key.contains(r'${')) {
          usedKeys.add(key);
        }
      }
    }

    final missing =
        usedKeys.where((key) => !keysInAssets.contains(key)).toList()..sort();

    expect(
      missing,
      isEmpty,
      reason:
          'Missing i18n keys in split language assets: ${missing.join(', ')}',
    );
  });

  test('bottom navigation keys are translated for all split languages',
      () async {
    final bundle = await _loadSplitLangs();
    const navKeys = <String>[
      'nav.epic',
      'nav.war',
      'nav.ua_planner',
      'nav.news',
    ];

    final missing = <String>[];
    for (final entry in bundle.entries) {
      for (final key in navKeys) {
        final text = (entry.value[key] ?? '').trim();
        if (text.isEmpty) {
          missing.add('${entry.key}:$key');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing bottom-nav translations: ${missing.join(', ')}',
    );
  });

  test('app features help-card keys are present for all split languages',
      () async {
    final bundle = await _loadSplitLangs();
    final appFeatureKeys = bundle['en']!
        .keys
        .where((key) => key.startsWith('app_features.'))
        .toList()
      ..sort();

    final missing = <String>[];
    for (final entry in bundle.entries) {
      for (final key in appFeatureKeys) {
        final text = (entry.value[key] ?? '').trim();
        if (text.isEmpty) {
          missing.add('${entry.key}:$key');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing app feature translations: ${missing.join(', ')}',
    );
  });

  test(
      'app title and footer caption keys are translated for all split languages',
      () async {
    final bundle = await _loadSplitLangs();
    const keys = <String>['app.title', 'app.bottom.title'];

    final missing = <String>[];
    for (final entry in bundle.entries) {
      for (final key in keys) {
        final text = (entry.value[key] ?? '').trim();
        if (text.isEmpty) {
          missing.add('${entry.key}:$key');
        }
      }
    }

    expect(
      missing,
      isEmpty,
      reason: 'Missing app title/footer translations: ${missing.join(', ')}',
    );
  });

  test('French and Russian UI labels do not contain placeholder ?', () async {
    final bundle = await _loadSplitLangs();
    final fr = bundle['fr']!;
    final ru = bundle['ru']!;

    const keys = <String>[
      'app.title',
      'app.bottom.title',
      'nav.epic',
      'nav.war',
      'nav.ua_planner',
      'nav.news',
      'utilities.title',
      'utilities.elements',
      'utilities.elixirs',
      'utilities.boss_stats',
      'elixirs.title',
      'elixirs.add',
      'elixirs.limit_free',
      'elixirs.limit_premium',
      'lang',
    ];

    final broken = <String>[];
    for (final key in keys) {
      final frText = fr[key] ?? '';
      final ruText = ru[key] ?? '';
      if (frText.contains('?')) broken.add('fr:$key');
      if (ruText.contains('?')) broken.add('ru:$key');
    }

    expect(
      broken,
      isEmpty,
      reason: 'Broken FR/RU placeholders found: ${broken.join(', ')}',
    );
  });

  test('split translations do not contain mojibake or broken replacement chars',
      () async {
    final bundle = await _loadSplitLangs();

    final broken = <String>[];
    final leadingQuestion = RegExp(r'\?[A-Za-zÀ-ÿА-Яа-яЁё]');
    final innerQuestion =
        RegExp(r'[A-Za-zÀ-ÿА-Яа-яЁё]\?(?=[A-Za-zÀ-ÿА-Яа-яЁё])');
    final punctuationQuestion = RegExp(r'[A-Za-zÀ-ÿА-Яа-яЁё]\?(?=[\.,:;])');
    final controlChars = RegExp(r'[\u0080-\u009F]');
    final euroMojibake = RegExp(r'Ã¢[\u0080-\u00BF]');

    for (final entry in bundle.entries) {
      final lang = entry.key;
      for (final kv in entry.value.entries) {
        final text = kv.value;
        final hasBrokenQuestion = leadingQuestion.hasMatch(text) ||
            innerQuestion.hasMatch(text) ||
            punctuationQuestion.hasMatch(text);
        final hasMojibake = TextEncodingGuard.containsLikelyMojibake(text) ||
            text.contains('\uFFFD') ||
            controlChars.hasMatch(text) ||
            euroMojibake.hasMatch(text);
        if (hasBrokenQuestion || hasMojibake) {
          broken.add('$lang:${kv.key}');
        }
      }
    }

    expect(
      broken,
      isEmpty,
      reason:
          'Mojibake/broken chars found in split assets: ${broken.join(', ')}',
    );
  });

  test('English split asset stays fully English for core UI labels', () async {
    final bundle = await _loadSplitLangs();
    final en = bundle['en']!;

    expect(en['applied'], 'Applied');
    expect(en['attack'], 'Attack');
    expect(en['boss_adv_vs_friends'], 'Boss advantage vs friends');
    expect(en['boss_adv_vs_knights'], 'Boss advantage vs knights');
    expect(en['boss_level'], 'Boss level');
    expect(en['boss_mode'], 'Boss mode');
    expect(en['boss_stats'], 'Boss stats');
    expect(en['boss_time'], 'Boss time');
    expect(en['element.fire'], 'Fire');
    expect(en['element.spirit'], 'Spirit');
    expect(en['element.earth'], 'Earth');
    expect(en['element.air'], 'Air');
    expect(en['element.water'], 'Water');
    expect(en['elixirs.add'], 'Add elixir');
    expect(en['elixirs.duration'], 'Duration');
    expect(en['elixirs.qty'], 'Qty');
    expect(en['elixirs.result'], 'Elixir');
    expect(en['elixirs.tip.title'], 'Elixirs tip');
    expect(en['elixirs.title'], 'Elixirs inventory');
    expect(en['knights'], 'Knights');
    expect(en['max'], 'max');
    expect(en['mode'], 'Mode');
    expect(en['pet.imported.source'], 'Imported pet source: {summary}');
    expect(en['theme.amoled'], 'AMOLED mode');
    expect(
      en['theme.amoled.hint'],
      'Pure black background with theme-colored accents.',
    );
    expect(en['theme.forest'], 'Forest');
    expect(en['theme.sky'], 'Sky');
    expect(en['theme.strawberry'], 'Strawberry');
    expect(en['theme.mint'], 'Mint');
    expect(en['theme.orange'], 'Orange');
    expect(en['theme.title'], 'Theme');
    expect(en['theme.tooltip'], 'Themes');

    const foreignMarkers = <String>[
      'anvendt',
      'angreb',
      'boss-fordel',
      'boss-niveau',
      'boss-tilstand',
      'boss-statistik',
      'boss-tid',
      'luft',
      'tilfoej',
      'varighed',
      'eliksir',
      'riddere',
      'indtast',
      'himmel',
      'jordbaer',
      'mynte',
      'appelsin',
      'skov',
      'temaer',
      'parametri di esecuzione',
      'numero simulazioni',
    ];

    final suspicious = <String>[];
    for (final entry in en.entries) {
      final lower = entry.value.toLowerCase();
      if (foreignMarkers.any(lower.contains)) {
        suspicious.add(entry.key);
      }
    }

    expect(
      suspicious,
      isEmpty,
      reason: 'Non-English strings found in EN asset: ${suspicious.join(', ')}',
    );
  });

  test(
      'core UI labels are not contaminated by Danish text in EN/IT/FR/ES/TR/PL/AR',
      () async {
    final bundle = await _loadSplitLangs();
    const langs = <String>['en', 'it', 'fr', 'es', 'tr', 'pl', 'ar'];
    const keys = <String>[
      'knights',
      'element.fire',
      'element.spirit',
      'element.earth',
      'element.air',
      'element.water',
      'elixirs.add',
      'elixirs.title',
      'theme.sky',
      'theme.strawberry',
      'theme.tooltip',
    ];
    const forbidden = <String>[
      'Riddere',
      'Ild',
      'Aand',
      'Jord',
      'Luft',
      'Vand',
      'Tilfoej eliksir',
      'Eliksiroversigt',
      'Himmel',
      'Jordbaer',
      'Temaer',
    ];

    final broken = <String>[];
    for (final lang in langs) {
      final map = bundle[lang]!;
      for (final key in keys) {
        final value = map[key] ?? '';
        if (forbidden.contains(value)) {
          broken.add('$lang:$key=$value');
        }
      }
    }

    expect(
      broken,
      isEmpty,
      reason:
          'Cross-language contamination found in core UI labels: ${broken.join(', ')}',
    );
  });
}

Future<Map<String, Map<String, String>>> _loadSplitLangs() async {
  final rawManifest = await rootBundle.loadString('assets/langs/manifest.json');
  final decodedManifest = jsonDecode(rawManifest);
  final langs = decodedManifest is List
      ? decodedManifest.cast<Object?>()
      : (decodedManifest as Map<String, dynamic>)['langs'] as List<dynamic>;

  final out = <String, Map<String, String>>{};
  for (final value in langs) {
    final lang = (value ?? '').toString().trim();
    if (lang.isEmpty) continue;
    final raw = await rootBundle.loadString('assets/langs/$lang.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    out[lang] = decoded.map(
      (key, value) => MapEntry(key, (value ?? '').toString()),
    );
  }
  return out;
}

Future<List<String>> _loadManifestLangs() async {
  final rawManifest = await rootBundle.loadString('assets/langs/manifest.json');
  final decodedManifest = jsonDecode(rawManifest);
  final langs = decodedManifest is List
      ? decodedManifest.cast<Object?>()
      : (decodedManifest as Map<String, dynamic>)['langs'] as List<dynamic>;
  return <String>[
    for (final value in langs)
      if ((value ?? '').toString().trim().isNotEmpty) value.toString().trim(),
  ];
}
