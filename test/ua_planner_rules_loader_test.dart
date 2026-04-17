import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/ua_planner_rules_loader.dart';

void main() {
  test('UA rules catalog parses baseline ruleset', () {
    final root = jsonDecode(_sampleJson) as Map<String, dynamic>;
    final catalog = UaPlannerRulesCatalog.fromJson(
      root.cast<String, Object?>(),
    );

    expect(catalog.schemaVersion, 1);
    expect(catalog.rulesets, hasLength(1));

    final rules = catalog.activeRuleset!;
    expect(rules.id, 'ua_2021_v1');
    expect(
        rules.eventRules.keys,
        containsAll(<String>[
          'weekend_raid',
          'blitz_raid',
          'weekend_war',
          'blitz_war',
          'heroic',
        ]));
  });

  test('Weekend Raid score and placement are cumulative', () {
    final rules = _rules();
    final raid = rules.eventRules['weekend_raid']!;
    final score = raid.scorePieces(500000000, isFirstBlitzOfMonth: false);
    final guild = raid.guildPlacementPieces(3, isFirstBlitzOfMonth: false);
    final individual = raid.individualPlacementPieces(
      4,
      isFirstBlitzOfMonth: false,
    );
    expect(score, 2);
    expect(guild, 2);
    expect(individual, 1);
    expect(score + guild + individual, 5);
  });

  test('Blitz Raid rules match expected thresholds', () {
    final rules = _rules();
    final blitzRaid = rules.eventRules['blitz_raid']!;
    expect(
      blitzRaid.scorePieces(8200000, isFirstBlitzOfMonth: false),
      1,
    );
    expect(
      blitzRaid.guildPlacementPieces(1, isFirstBlitzOfMonth: false),
      0,
    );
    expect(
      blitzRaid.individualPlacementPieces(1, isFirstBlitzOfMonth: false),
      2,
    );
    expect(
      blitzRaid.individualPlacementPieces(4, isFirstBlitzOfMonth: false),
      0,
    );
  });

  test('Weekend War and Blitz War first blitz exceptions', () {
    final rules = _rules();
    final weekendWar = rules.eventRules['weekend_war']!;
    expect(
      weekendWar.scorePieces(1825000, isFirstBlitzOfMonth: false),
      5,
    );

    final blitzWar = rules.eventRules['blitz_war']!;
    expect(
      blitzWar.scorePieces(475000, isFirstBlitzOfMonth: true),
      2,
    );
    expect(
      blitzWar.scorePieces(475000, isFirstBlitzOfMonth: false),
      3,
    );
    expect(
      blitzWar.guildPlacementPieces(1, isFirstBlitzOfMonth: true),
      0,
    );
    expect(
      blitzWar.guildPlacementPieces(1, isFirstBlitzOfMonth: false),
      1,
    );
  });

    test('EB second entry gives +1 and depends on first entry', () {
    final rules = _rules();
    final eb = rules.bonusRules['eb_collection']!;
    expect(eb, hasLength(2));
    expect(eb[0].pieces, 1);
      expect(eb[1].pieces, 1);
      expect(eb[1].dependsOn, 'eb_current_month');
    });
}

UaRuleset _rules() {
  final root = jsonDecode(_sampleJson) as Map<String, dynamic>;
  final catalog = UaPlannerRulesCatalog.fromJson(root.cast<String, Object?>());
  return catalog.activeRuleset!;
}

const String _sampleJson = '''
{
  "schemaVersion": 1,
  "rulesets": [
    {
      "id": "ua_2021_v1",
      "label": "UA Ruleset (Nov 2021 baseline)",
      "source": "Cheat Sheet for Elite Pieces - Knights and Dragons (as of November 2021)",
      "active": true,
      "appUpdateRequiredOnChange": true,
      "eventRules": {
        "weekend_raid": {
          "enabled": true,
          "scoreMilestones": [
            { "minPoints": 50000000, "pieces": 1 },
            { "minPoints": 200000000, "pieces": 1 }
          ],
          "guildPlacementTiers": [
            { "rankFrom": 1, "rankTo": 1, "pieces": 4 },
            { "rankFrom": 2, "rankTo": 2, "pieces": 3 },
            { "rankFrom": 3, "rankTo": 3, "pieces": 2 },
            { "rankFrom": 4, "rankTo": 7, "pieces": 1 }
          ],
          "individualPlacementTiers": [
            { "rankFrom": 1, "rankTo": 1, "pieces": 4 },
            { "rankFrom": 2, "rankTo": 2, "pieces": 3 },
            { "rankFrom": 3, "rankTo": 3, "pieces": 2 },
            { "rankFrom": 4, "rankTo": 7, "pieces": 1 }
          ],
          "allSourcesCumulative": true
        },
        "blitz_raid": {
          "enabled": true,
          "scoreMilestones": [
            { "minPoints": 8200000, "pieces": 1 }
          ],
          "guildPlacementTiers": [],
          "individualPlacementTiers": [
            { "rankFrom": 1, "rankTo": 1, "pieces": 2 },
            { "rankFrom": 2, "rankTo": 3, "pieces": 1 }
          ],
          "allSourcesCumulative": true
        },
        "weekend_war": {
          "enabled": true,
          "scoreMilestones": [
            { "minPoints": 105000, "pieces": 1 },
            { "minPoints": 260000, "pieces": 1 },
            { "minPoints": 475000, "pieces": 1 },
            { "minPoints": 931000, "pieces": 1 },
            { "minPoints": 1825000, "pieces": 1 }
          ],
          "guildPlacementTiers": [
            { "rankFrom": 1, "rankTo": 1, "pieces": 3 },
            { "rankFrom": 2, "rankTo": 2, "pieces": 2 },
            { "rankFrom": 3, "rankTo": 10, "pieces": 1 }
          ],
          "individualPlacementTiers": [],
          "allSourcesCumulative": true
        },
        "blitz_war": {
          "enabled": true,
          "scoreMilestones": [
            { "minPoints": 105000, "pieces": 1 },
            { "minPoints": 260000, "pieces": 1 },
            { "minPoints": 475000, "pieces": 1, "excludeOnFirstBlitzOfMonth": true }
          ],
          "guildPlacementTiers": [
            { "rankFrom": 1, "rankTo": 1, "pieces": 1, "excludeOnFirstBlitzOfMonth": true },
            { "rankFrom": 2, "rankTo": 2, "pieces": 1, "excludeOnFirstBlitzOfMonth": true }
          ],
          "individualPlacementTiers": [],
          "allSourcesCumulative": true
        },
        "heroic": {
          "enabled": true,
          "piecesPerCompletedHeroic": 1
        }
      },
      "bonusRules": {
        "eb_collection": [
          {
            "id": "eb_current_month",
            "label": "Obtained T20 armor of the current month",
            "pieces": 1
          },
          {
            "id": "eb_current_and_past",
            "label": "Obtained T20 armor of current and past month",
            "pieces": 1,
            "dependsOn": "eb_current_month"
          }
        ]
      }
    }
  ]
}
''';
