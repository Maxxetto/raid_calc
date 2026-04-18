import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class EventShopInventoryStorage {
  static const _prefsKey = 'news_events_shop_inventory_v1';

  static Future<Map<String, Map<String, int>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      return <String, Map<String, int>>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, int>>{};
      final out = <String, Map<String, int>>{};
      for (final eventEntry in decoded.entries) {
        final eventId = eventEntry.key.toString().trim();
        if (eventId.isEmpty || eventEntry.value is! Map) continue;
        final rawMap = (eventEntry.value as Map).cast<Object?, Object?>();
        final eventValues = <String, int>{};
        for (final currencyEntry in rawMap.entries) {
          final currencyId = currencyEntry.key.toString().trim();
          if (currencyId.isEmpty) continue;
          final parsed = int.tryParse(currencyEntry.value.toString().trim());
          if (parsed == null || parsed <= 0) continue;
          eventValues[currencyId] = parsed;
        }
        if (eventValues.isNotEmpty) {
          out[eventId] = eventValues;
        }
      }
      return out;
    } catch (_) {
      return <String, Map<String, int>>{};
    }
  }

  static Future<void> save(Map<String, Map<String, int>> value) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, Map<String, int>>{};
    for (final eventEntry in value.entries) {
      final eventId = eventEntry.key.trim();
      if (eventId.isEmpty) continue;
      final eventValues = <String, int>{};
      for (final currencyEntry in eventEntry.value.entries) {
        final currencyId = currencyEntry.key.trim();
        if (currencyId.isEmpty || currencyEntry.value <= 0) continue;
        eventValues[currencyId] = currencyEntry.value;
      }
      if (eventValues.isNotEmpty) {
        encoded[eventId] = eventValues;
      }
    }
    await prefs.setString(_prefsKey, jsonEncode(encoded));
  }
}
