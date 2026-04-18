import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EventProgressStorage {
  static const _prefsKey = 'news_events_progress_v1';

  static Future<Map<String, Set<String>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return <String, Set<String>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Set<String>>{};
      final out = <String, Set<String>>{};
      for (final entry in decoded.entries) {
        final eventId = entry.key.toString().trim();
        if (eventId.isEmpty) continue;
        final v = entry.value;
        final set = <String>{};
        if (v is List) {
          for (final rowKey in v) {
            final s = rowKey?.toString().trim() ?? '';
            if (s.isNotEmpty) set.add(s);
          }
        }
        if (set.isNotEmpty) out[eventId] = set;
      }
      return out;
    } catch (_) {
      return <String, Set<String>>{};
    }
  }

  static Future<void> save(Map<String, Set<String>> value) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, List<String>>{};
    for (final entry in value.entries) {
      final key = entry.key.trim();
      if (key.isEmpty || entry.value.isEmpty) continue;
      encoded[key] = entry.value.toList()..sort();
    }
    await prefs.setString(_prefsKey, jsonEncode(encoded));
  }
}
