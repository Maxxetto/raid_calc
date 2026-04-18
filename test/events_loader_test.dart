import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/events_loader.dart';

void main() {
  test('EventsCatalog parses celestial steed schema', () {
    final root = jsonDecode(_sampleJson) as Map<String, dynamic>;
    final catalog = EventsCatalog.fromJson(root.cast<String, Object?>());

    expect(catalog.schemaVersion, 1);
    expect(catalog.events, hasLength(1));

    final event = catalog.events.single;
    expect(event.id, 'celestial_steed_2026_02');
    expect(event.name, 'Celestial Steed');
    expect(event.materials.length, 4);
    expect(event.rows.length, 2);
    expect(event.specialEventShop.length, 2);
    expect(event.rows.first.values['lunar_bell'], 'INF');
    expect(event.rows.last.values['jade_steed'], '283');
    expect(event.specialEventShop.first.name, '[115] Shadowbound Steed T1');
    expect(event.specialEventShop.first.cost.amount, 500);
    expect(event.specialEventShop.first.cost.currencyId, 'lunar_bell');
    expect(event.specialEventShop.first.buyLimit, 2);
    expect(event.specialEventShop.last.buyLimit, isNull);
  });

  test('Event display status follows active -> ended grace -> hidden', () {
    final root = jsonDecode(_sampleJson) as Map<String, dynamic>;
    final event = EventsCatalog.fromJson(root.cast<String, Object?>()).events.single;

    expect(
      event.displayStatusAt(DateTime(2026, 2, 17)),
      EventDisplayStatus.upcoming,
    );
    expect(
      event.displayStatusAt(DateTime(2026, 2, 24)),
      EventDisplayStatus.active,
    );
    expect(
      event.displayStatusAt(DateTime(2026, 3, 18)),
      EventDisplayStatus.active,
    );
    expect(
      event.displayStatusAt(DateTime(2026, 3, 19)),
      EventDisplayStatus.endedGrace,
    );
    expect(
      event.displayStatusAt(DateTime(2026, 3, 25)),
      EventDisplayStatus.endedGrace,
    );
    expect(
      event.displayStatusAt(DateTime(2026, 3, 26)),
      EventDisplayStatus.hidden,
    );
  });
}

const String _sampleJson = '''
{
  "schemaVersion": 1,
  "events": [
    {
      "id": "celestial_steed_2026_02",
      "name": "Celestial Steed",
      "startDate": "2026-02-18",
      "endDate": "2026-03-18",
      "hideAfterDays": 7,
      "materials": [
        { "id": "lunar_bell", "label": "[S115] Lunar Bell" },
        { "id": "guardian_hoof", "label": "[S115] Guardian Hoof" },
        { "id": "jade_steed", "label": "[S115] Jade Steed" },
        { "id": "collection_score", "label": "[S115] Collection Score" }
      ],
      "rows": [
        {
          "activity": "Rare Spawn",
          "startDate": "2026-02-18",
          "endDate": "2026-03-11",
          "values": { "lunar_bell": "INF" }
        },
        {
          "activity": "Raid Boss",
          "startDate": "2026-02-20",
          "endDate": "2026-02-22",
          "values": {
            "lunar_bell": 1375,
            "guardian_hoof": 1150,
            "jade_steed": 283,
            "collection_score": 2292
          }
        }
      ],
      "specialEventShop": [
        {
          "name": "[115] Shadowbound Steed T1",
          "cost": { "amount": 500, "currencyId": "lunar_bell", "currencyLabel": "Lunar Bell" },
          "buyLimit": 2
        },
        {
          "name": "Lunar Steed",
          "cost": { "amount": 500, "currencyId": "lunar_bell", "currencyLabel": "Lunar Bell" },
          "buyLimit": "INF"
        }
      ]
    }
  ]
}
''';
