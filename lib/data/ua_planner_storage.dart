import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class UaPlannerStorage {
  static const String _fileName = 'ua_planner_state.json';
  static const String _tmpSuffix = '.tmp';
  static const String _backupSuffix = '.bak';
  static Future<void> _saveLock = Future<void>.value();

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/raid_calc');
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return File('${folder.path}/$_fileName');
  }

  static Future<void> save(Map<String, Object?> data) async {
    _saveLock = _saveLock.then((_) async {
      try {
        final f = await _file();
        final raw = jsonEncode(data);
        final tmp = File('${f.path}$_tmpSuffix');
        final backup = File('${f.path}$_backupSuffix');
        await tmp.writeAsString(raw, flush: true);
        if (await f.exists()) {
          await f.copy(backup.path);
          await f.delete();
        }
        try {
          await tmp.rename(f.path);
          if (await backup.exists()) {
            await backup.delete();
          }
        } catch (_) {
          if (!await f.exists() && await backup.exists()) {
            await backup.copy(f.path);
          }
          rethrow;
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('UaPlannerStorage.save failed: $e');
        }
      }
    });
    await _saveLock;
  }

  static Future<Map<String, Object?>?> load() async {
    try {
      final f = await _file();
      final tmp = File('${f.path}$_tmpSuffix');
      final backup = File('${f.path}$_backupSuffix');
      final candidates = <File>[f, tmp, backup];
      Map<String, Object?>? best;
      DateTime? bestModified;

      for (final candidate in candidates) {
        final decoded = await _readCandidate(candidate);
        if (decoded == null) continue;
        final modified = await candidate.lastModified();
        if (best == null ||
            bestModified == null ||
            modified.isAfter(bestModified)) {
          best = decoded;
          bestModified = modified;
        }
      }

      if (best != null) {
        await save(best);
      }
      return best;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UaPlannerStorage.load failed: $e');
      }
      return null;
    }
  }

  static Future<Map<String, Object?>?> _readCandidate(File file) async {
    try {
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return decoded.cast<String, Object?>();
    } catch (_) {
      return null;
    }
  }
}
