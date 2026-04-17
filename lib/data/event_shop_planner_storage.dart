import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'event_shop_inventory_storage.dart';

class EventShopPlannerStateData {
  final Map<String, int> inventory;
  final Map<int, int> quantities;

  const EventShopPlannerStateData({
    required this.inventory,
    required this.quantities,
  });

  bool get isEmpty => inventory.isEmpty && quantities.isEmpty;
}

class EventShopPlannerStorage {
  static const _prefsKey = 'news_events_shop_planner_v1';

  static Future<Map<String, EventShopPlannerStateData>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.trim().isEmpty) {
      final legacyInventory = await EventShopInventoryStorage.load();
      if (legacyInventory.isEmpty) {
        return <String, EventShopPlannerStateData>{};
      }
      return {
        for (final entry in legacyInventory.entries)
          entry.key: EventShopPlannerStateData(
            inventory: Map<String, int>.from(entry.value),
            quantities: const <int, int>{},
          ),
      };
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, EventShopPlannerStateData>{};
      final out = <String, EventShopPlannerStateData>{};
      for (final entry in decoded.entries) {
        final eventId = entry.key.toString().trim();
        if (eventId.isEmpty || entry.value is! Map) continue;
        final map = (entry.value as Map).cast<Object?, Object?>();

        final inventory = <String, int>{};
        final rawInventory = map['inventory'];
        if (rawInventory is Map) {
          for (final invEntry in rawInventory.entries) {
            final currencyId = invEntry.key.toString().trim();
            if (currencyId.isEmpty) continue;
            final parsed = int.tryParse(invEntry.value.toString().trim());
            if (parsed == null || parsed <= 0) continue;
            inventory[currencyId] = parsed;
          }
        }

        final quantities = <int, int>{};
        final rawQuantities = map['quantities'];
        if (rawQuantities is Map) {
          for (final qtyEntry in rawQuantities.entries) {
            final index = int.tryParse(qtyEntry.key.toString().trim());
            final qty = int.tryParse(qtyEntry.value.toString().trim());
            if (index == null || index < 0 || qty == null || qty <= 0) continue;
            quantities[index] = qty;
          }
        }

        final state = EventShopPlannerStateData(
          inventory: inventory,
          quantities: quantities,
        );
        if (!state.isEmpty) out[eventId] = state;
      }
      return out;
    } catch (_) {
      return <String, EventShopPlannerStateData>{};
    }
  }

  static Future<void> save(
    Map<String, EventShopPlannerStateData> value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = <String, Map<String, Object>>{};
    for (final entry in value.entries) {
      final eventId = entry.key.trim();
      if (eventId.isEmpty) continue;

      final inventory = <String, int>{};
      for (final invEntry in entry.value.inventory.entries) {
        final currencyId = invEntry.key.trim();
        if (currencyId.isEmpty || invEntry.value <= 0) continue;
        inventory[currencyId] = invEntry.value;
      }

      final quantities = <String, int>{};
      for (final qtyEntry in entry.value.quantities.entries) {
        if (qtyEntry.key < 0 || qtyEntry.value <= 0) continue;
        quantities[qtyEntry.key.toString()] = qtyEntry.value;
      }

      if (inventory.isEmpty && quantities.isEmpty) continue;
      encoded[eventId] = {
        'inventory': inventory,
        'quantities': quantities,
      };
    }

    await prefs.setString(_prefsKey, jsonEncode(encoded));
  }
}
