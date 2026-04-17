// lib/data/last_session_storage.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

@immutable
class LastSessionData {
  final Map<String, Object?> homeState;
  final Map<String, Object?>? lastStats;
  final bool openResultsOnStart;
  final int premiumExpiryMs;
  final String savedAtIso;

  LastSessionData({
    required this.homeState,
    required this.lastStats,
    required this.openResultsOnStart,
    required this.premiumExpiryMs,
    DateTime? savedAt,
  }) : savedAtIso = (savedAt ?? DateTime.now()).toIso8601String();

  Map<String, Object?> toJson() => {
        'homeState': homeState,
        'lastStats': lastStats,
        'openResultsOnStart': openResultsOnStart,
        'premiumExpiryMs': premiumExpiryMs,
        'savedAtIso': savedAtIso,
      };

  factory LastSessionData.fromJson(Map<String, Object?> j) => LastSessionData(
        homeState: (j['homeState'] as Map?)?.cast<String, Object?>() ??
            const <String, Object?>{},
        lastStats: (j['lastStats'] is Map)
            ? (j['lastStats'] as Map).cast<String, Object?>()
            : null,
        openResultsOnStart: (j['openResultsOnStart'] as bool?) ?? false,
        premiumExpiryMs: (j['premiumExpiryMs'] as num?)?.toInt() ?? 0,
        savedAt: DateTime.tryParse((j['savedAtIso'] as String?) ?? ''),
      );
}

class LastSessionStorage {
  static const String _fileName = 'raid_calc_last_session.json';
  static const String _tmpSuffix = '.tmp';
  static Future<void> _saveLock = Future<void>.value();

  static Future<File> _file() async {
    // Persistente su Android/iOS/desktop
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/raid_calc');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return File('${folder.path}/$_fileName');
  }

  static Future<void> save(LastSessionData data) async {
    _saveLock = _saveLock.then((_) async {
      try {
        final f = await _file();
        final raw = jsonEncode(data.toJson());
        final tmp = File('${f.path}$_tmpSuffix');
        await tmp.writeAsString(raw, flush: true);
        if (await f.exists()) {
          await f.delete();
        }
        await tmp.rename(f.path);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LastSessionStorage.save failed: $e');
        }
      }
    });
    await _saveLock;
  }

  static Future<LastSessionData?> load() async {
    try {
      final f = await _file();
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return null;
      try {
        final j = (jsonDecode(raw) as Map).cast<String, Object?>();
        return LastSessionData.fromJson(j);
      } catch (e) {
        if (kDebugMode) {
          debugPrint('LastSessionStorage.load failed: $e');
        }
        final tmp = File('${f.path}$_tmpSuffix');
        if (await tmp.exists()) {
          final rawTmp = await tmp.readAsString();
          if (rawTmp.trim().isEmpty) return null;
          final j = (jsonDecode(rawTmp) as Map).cast<String, Object?>();
          return LastSessionData.fromJson(j);
        }
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() async {
    try {
      final f = await _file();
      if (await f.exists()) {
        await f.writeAsString('', flush: true);
      }
    } catch (_) {}
  }

  static bool isPremiumActive(int expiryMs) {
    if (expiryMs <= 0) return false;
    return DateTime.now().millisecondsSinceEpoch < expiryMs;
  }

  static int grantPremiumMonths(int months) {
    final now = DateTime.now();
    final dt = DateTime(now.year, now.month + months, now.day, now.hour,
        now.minute, now.second);
    return dt.millisecondsSinceEpoch;
  }
}
