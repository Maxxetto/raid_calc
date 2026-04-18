import 'package:shared_preferences/shared_preferences.dart';

class PetFavoritesStorage {
  static const String _prefsKey = 'pet_favorite_family_ids_v1';

  static Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey) ?? const <String>[];
    return raw.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
  }

  static Future<void> save(Set<String> familyIds) async {
    final prefs = await SharedPreferences.getInstance();
    final values = familyIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList()
      ..sort();
    await prefs.setStringList(_prefsKey, values);
  }

  static Future<bool> toggle(String familyId) async {
    final trimmed = familyId.trim();
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
