// lib/util/i18n.dart
//
// Loader minimale per stringhe di interfaccia da assets JSON.
// - File attesi: assets/lang/{code}.json  (es: it.json, en.json, de.json, fr.json, es.json, nl.json, ru.json)
// - API esposta:
//     const I18n(String code, Map<String,String> map)  // costruttore pubblico e const (per default vuoto)
//     Future<I18n> I18n.fromAssets(String code)        // carica/merge con fallback a 'en' se mancano chiavi
//     Map<String,String> get map                      // mappa delle stringhe
//     String get code                                 // codice lingua
//     String t(String key, [String fallback=''])      // helper di lettura
//     List<String> I18n.supported                     // lingue supportate
//     String I18n.nativeName(String code)             // nome “umano” della lingua

import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class I18n {
  final String code;
  final Map<String, String> map;

  /// Costruttore pubblico e const: ti consente di creare un'istanza “vuota” all’avvio.
  const I18n(this.code, this.map);

  /// Lingue supportate nel menu.
  static const List<String> supported = <String>[
    'it',
    'en',
    'de',
    'fr',
    'es',
    'nl',
    'ru',
  ];

  /// Nome nativo (visualizzato nel menu).
  static String nativeName(String code) {
    switch (code) {
      case 'it':
        return 'Italiano';
      case 'en':
        return 'English';
      case 'de':
        return 'Deutsch';
      case 'fr':
        return 'Français';
      case 'es':
        return 'Español';
      case 'nl':
        return 'Nederlands';
      case 'ru':
        return 'Русский';
      default:
        return code.toUpperCase();
    }
  }

  /// Accesso comodo: i18n.t('key', 'fallback')
  String t(String key, [String fallback = '']) => map[key] ?? fallback;

  /// Carica il JSON della lingua richiesta; se alcune chiavi mancano,
  /// fa il merge con l’inglese come fallback.
  static Future<I18n> fromAssets(String code) async {
    Future<Map<String, String>> _load(String c) async {
      final path = 'assets/lang/$c.json';
      final raw = await rootBundle.loadString(path);
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v ?? '').toString()));
    }

    // carica lingua richiesta
    Map<String, String> base;
    try {
      base = await _load(code);
    } catch (_) {
      // se non trovata, ripiega direttamente su en
      base = await _load('en');
      return I18n('en', base);
    }

    // merge con inglese come fallback per eventuali chiavi mancanti
    if (code != 'en') {
      try {
        final en = await _load('en');
        // aggiungi al bisogno le chiavi mancanti
        for (final e in en.entries) {
          base.putIfAbsent(e.key, () => e.value);
        }
      } catch (_) {
        // se manca anche en, prosegui comunque con le sole chiavi disponibili
      }
    }

    return I18n(code, base);
  }
}
