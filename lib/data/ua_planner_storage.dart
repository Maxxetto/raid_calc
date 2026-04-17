import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class UaPlannerStorage {
  static const String _fileName = 'ua_planner_state.json';
  static const String _tmpSuffix = '.tmp';
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
        await tmp.writeAsString(raw, flush: true);
        if (await f.exists()) {
          await f.delete();
        }
        await tmp.rename(f.path);
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
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      if (raw.trim().isEmpty) return null;
      final decoded = (jsonDecode(raw) as Map).cast<String, Object?>();
      return decoded;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UaPlannerStorage.load failed: $e');
      }
      return null;
    }
  }
}
