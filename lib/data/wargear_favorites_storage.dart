import 'package:shared_preferences/shared_preferences.dart';

class WargearFavoritesStorage {
  static const String _prefsKey = 'wargear_favorite_armor_ids_v1';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> save(Set<String> armorIds) async {
    final prefs = await SharedPreferences.getInstance();
    final values = armorIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    await prefs.setStringList(_prefsKey, values);
  }

  static Future<bool> toggle(String armorId) async {
    final trimmed = armorId.trim();
    if (trimmed.isEmpty) return false;
    final values = await load();
    final added = !values.remove(trimmed);
    if (added) {
      values.add(trimmed);
    }
    await save(values);
    return added;
  }
}
