import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

@immutable
class EventMaterialColumn {
  final String id;
  final String label;

  const EventMaterialColumn({
    required this.id,
    required this.label,
  });

  factory EventMaterialColumn.fromJson(Map<String, Object?> j) {
    final id = (j['id'] ?? '').toString().trim();
    final label = (j['label'] ?? '').toString().trim();
    return EventMaterialColumn(id: id, label: label);
  }

  bool get isValid => id.isNotEmpty && label.isNotEmpty;
}

@immutable
class EventScheduleRow {
  final String activity;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, String> values;

  const EventScheduleRow({
    required this.activity,
    required this.startDate,
    required this.endDate,
    required this.values,
  });

  factory EventScheduleRow.fromJson(Map<String, Object?> j) {
    final activity = (j['activity'] ?? '').toString().trim();
    final startDate = _parseDate(j['startDate']);
    final endDate = _parseDate(j['endDate']);
    final rawValues =
        (j['values'] as Map?)?.cast<Object?, Object?>() ?? const {};
    final values = <String, String>{};
    for (final entry in rawValues.entries) {
      final key = (entry.key ?? '').toString().trim();
      if (key.isEmpty) continue;
      final value = entry.value;
      if (value == null) continue;
      values[key] = value.toString().trim();
    }
    return EventScheduleRow(
      activity: activity,
      startDate: startDate,
      endDate: endDate,
      values: Map.unmodifiable(values),
    );
  }

  bool get isValid =>
      activity.isNotEmpty && !endDate.isBefore(startDate) && values.isNotEmpty;
}

enum EventDisplayStatus {
  upcoming,
  active,
  endedGrace,
  hidden,
}

@immutable
class EventShopCost {
  final int amount;
  final String currencyId;
  final String currencyLabel;

  const EventShopCost({
    required this.amount,
    required this.currencyId,
    required this.currencyLabel,
  });

  factory EventShopCost.fromJson(Map<String, Object?> j) {
    return EventShopCost(
      amount: _readInt(j['amount'], fallback: 0, min: 0, max: 2000000000),
      currencyId: (j['currencyId'] ?? '').toString().trim(),
      currencyLabel: (j['currencyLabel'] ?? '').toString().trim(),
    );
  }

  bool get isValid =>
      amount > 0 && currencyId.isNotEmpty && currencyLabel.isNotEmpty;
}

@immutable
class EventShopItem {
  final String name;
  final EventShopCost cost;
  final int? buyLimit; // null => infinite

  const EventShopItem({
    required this.name,
    required this.cost,
    required this.buyLimit,
  });

  factory EventShopItem.fromJson(Map<String, Object?> j) {
    final costMap = (j['cost'] as Map?)?.cast<String, Object?>() ?? const {};
    final rawLimit = j['buyLimit'];
    int? buyLimit;
    if (rawLimit != null) {
      final rawStr = rawLimit.toString().trim().toUpperCase();
      if (rawStr != 'INF') {
        buyLimit = _readInt(rawLimit, fallback: 1, min: 1, max: 999999);
      }
    }
    return EventShopItem(
      name: (j['name'] ?? '').toString().trim(),
      cost: EventShopCost.fromJson(costMap),
      buyLimit: buyLimit,
    );
  }

  bool get isValid => name.isNotEmpty && cost.isValid;
}

@immutable
class EventDefinition {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final int hideAfterDays;
  final List<EventMaterialColumn> materials;
  final List<EventScheduleRow> rows;
  final List<EventShopItem> specialEventShop;

  const EventDefinition({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.hideAfterDays,
    required this.materials,
    required this.rows,
    required this.specialEventShop,
  });

  factory EventDefinition.fromJson(Map<String, Object?> j) {
    final materialsRaw = (j['materials'] as List?)?.cast<Object?>() ?? const [];
    final rowsRaw = (j['rows'] as List?)?.cast<Object?>() ?? const [];
    final materials = materialsRaw
        .whereType<Map>()
        .map((e) => EventMaterialColumn.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);
    final rows = rowsRaw
        .whereType<Map>()
        .map((e) => EventScheduleRow.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);
    final shopRaw =
        (j['specialEventShop'] as List?)?.cast<Object?>() ?? const [];
    final shop = shopRaw
        .whereType<Map>()
        .map((e) => EventShopItem.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);

    final hideAfterDays =
        _readInt(j['hideAfterDays'], fallback: 7, min: 0, max: 365);
    return EventDefinition(
      id: (j['id'] ?? '').toString().trim(),
      name: (j['name'] ?? '').toString().trim(),
      startDate: _parseDate(j['startDate']),
      endDate: _parseDate(j['endDate']),
      hideAfterDays: hideAfterDays,
      materials: materials,
      rows: rows,
      specialEventShop: shop,
    );
  }

  bool get isValid =>
      id.isNotEmpty &&
      name.isNotEmpty &&
      !endDate.isBefore(startDate) &&
      materials.isNotEmpty &&
      rows.isNotEmpty;

  DateTime get hiddenAfterDate =>
      _dateOnly(endDate).add(Duration(days: hideAfterDays + 1));

  EventDisplayStatus displayStatusAt(DateTime now) {
    final d = _dateOnly(now);
    final start = _dateOnly(startDate);
    final end = _dateOnly(endDate);
    final hiddenFrom = hiddenAfterDate;
    if (d.isBefore(start)) return EventDisplayStatus.upcoming;
    if (!d.isAfter(end)) return EventDisplayStatus.active;
    if (d.isBefore(hiddenFrom)) return EventDisplayStatus.endedGrace;
    return EventDisplayStatus.hidden;
  }

  bool isVisibleAt(DateTime now) =>
      displayStatusAt(now) != EventDisplayStatus.hidden;
}

class EventsCatalog {
  final int schemaVersion;
  final List<EventDefinition> events;

  const EventsCatalog({
    required this.schemaVersion,
    required this.events,
  });

  factory EventsCatalog.fromJson(Map<String, Object?> j) {
    final raw = (j['events'] as List?)?.cast<Object?>() ?? const [];
    final events = raw
        .whereType<Map>()
        .map((e) => EventDefinition.fromJson(e.cast<String, Object?>()))
        .where((e) => e.isValid)
        .toList(growable: false);
    return EventsCatalog(
      schemaVersion:
          _readInt(j['schemaVersion'], fallback: 1, min: 1, max: 9999),
      events: events,
    );
  }

  List<EventDefinition> visibleEventsAt(DateTime now) =>
      events.where((e) => e.isVisibleAt(now)).toList(growable: false);
}

class EventsLoader {
  static EventsCatalog? _cache;

  static Future<EventsCatalog> load() async {
    if (_cache != null) return _cache!;
    final raw = await rootBundle.loadString('assets/events.json');
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      _cache =
          const EventsCatalog(schemaVersion: 1, events: <EventDefinition>[]);
      return _cache!;
    }
    _cache = EventsCatalog.fromJson(decoded.cast<String, Object?>());
    return _cache!;
  }

  static void clearCache() {
    _cache = null;
  }
}

DateTime _parseDate(Object? raw) {
  final s = (raw ?? '').toString().trim();
  final parsed = DateTime.tryParse(s);
  if (parsed == null) return DateTime(2000, 1, 1);
  return _dateOnly(parsed);
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

int _readInt(
  Object? raw, {
  required int fallback,
  required int min,
  required int max,
}) {
  int? v;
  if (raw is int) {
    v = raw;
  } else if (raw is num) {
    v = raw.toInt();
  } else if (raw is String) {
    v = int.tryParse(raw.trim());
  }
  if (v == null) return fallback;
  return v.clamp(min, max);
}
