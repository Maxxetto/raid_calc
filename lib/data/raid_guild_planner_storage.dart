import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RaidGuildPlannerStorage {
  static const String _prefsKey = 'raid_guild_planner_v1';

  static Future<Map<String, Object?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) return <String, Object?>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Object?>{};
      return decoded.cast<String, Object?>();
    } catch (_) {
      return <String, Object?>{};
    }
  }

  static Future<void> save(Map<String, Object?> value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(value));
  }
}
