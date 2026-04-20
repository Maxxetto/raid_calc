import 'dart:convert';

import 'package:flutter/services.dart';

class HallOfFameEntry {
  final int schemaVersion;
  final String id;
  final String eventDate;
  final String postedDate;
  final String mode;
  final String scope;
  final int rankLimit;
  final String title;
  final String winnerName;
  final String armorName;
  final String sourceUrl;
  final String imageSourceUrl;
  final String notes;

  const HallOfFameEntry({
    required this.schemaVersion,
    required this.id,
    required this.eventDate,
    required this.postedDate,
    required this.mode,
    required this.scope,
    required this.rankLimit,
    required this.title,
    required this.winnerName,
    required this.armorName,
    required this.sourceUrl,
    required this.imageSourceUrl,
    required this.notes,
  });

  factory HallOfFameEntry.fromJson(Map<String, Object?> json) {
    String read(String key) => (json[key] ?? '').toString().trim();

    return HallOfFameEntry(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 0,
      id: read('id'),
      eventDate: read('eventDate'),
      postedDate: read('postedDate'),
      mode: read('mode').toLowerCase(),
      scope: read('scope').toLowerCase(),
      rankLimit: (json['rankLimit'] as num?)?.toInt() ?? 0,
      title: read('title'),
      winnerName: read('winnerName'),
      armorName: read('armorName'),
      sourceUrl: read('sourceUrl'),
      imageSourceUrl: read('imageSourceUrl'),
      notes: read('notes'),
    );
  }

  bool get isValid =>
      schemaVersion == 1 &&
      id.isNotEmpty &&
      _isIsoDate(eventDate) &&
      (postedDate.isEmpty || _isIsoDate(postedDate)) &&
      (mode == 'raid' || mode == 'blitz' || mode == 'war') &&
      scope.isNotEmpty &&
      rankLimit > 0 &&
      title.isNotEmpty &&
      winnerName.isNotEmpty &&
      armorName.isNotEmpty &&
      sourceUrl.isNotEmpty;

  static bool _isIsoDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    return DateTime.tryParse(value) != null;
  }
}

class HallOfFamesLoader {
  static const String _assetPrefix = 'assets/hall_of_fames/';
  static const String _assetSuffix = '.json';

  static List<HallOfFameEntry>? _cache;

  static Future<List<HallOfFameEntry>> load() async {
    if (_cache != null) return _cache!;

    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final paths = manifest
        .listAssets()
        .where((path) => path.startsWith(_assetPrefix))
        .where((path) => path.endsWith(_assetSuffix))
        .toList()
      ..sort();

    final jsonByPath = <String, String>{};
    for (final path in paths) {
      jsonByPath[path] = await rootBundle.loadString(path);
    }

    _cache = parseEntriesForTest(jsonByPath);
    return _cache!;
  }

  static List<HallOfFameEntry> parseEntriesForTest(
    Map<String, String> jsonByPath,
  ) {
    final out = <HallOfFameEntry>[];

    for (final raw in jsonByPath.values) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is! Map) continue;
        final entry = HallOfFameEntry.fromJson(
          decoded.cast<String, Object?>(),
        );
        if (entry.isValid) out.add(entry);
      } catch (_) {
        continue;
      }
    }

    out.sort((a, b) => b.eventDate.compareTo(a.eventDate));
    return out;
  }

  static void clearCache() {
    _cache = null;
  }
}
