import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/hall_of_fames_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('HallOfFamesLoader loads static entries', () async {
    HallOfFamesLoader.clearCache();
    final list = await HallOfFamesLoader.load();

    expect(list, isNotEmpty);
    final gareth = list.firstWhere(
      (item) => item.id == '2026-03-20_raid_worldwide_top50',
    );
    expect(gareth.winnerName, 'Gareth');
    expect(gareth.armorName, 'Soul of Gareth');
    expect(gareth.rankLimit, 50);
    expect(gareth.mode, 'raid');

    final tempest = list.firstWhere(
      (item) => item.id == '2026-03-06_raid_worldwide_top50',
    );
    expect(tempest.winnerName, 'TempestTKF');
    expect(tempest.armorName, "TempestTKF's Legend");

    final bruh = list.firstWhere(
      (item) => item.id == '2026-02-20_raid_worldwide_top50',
    );
    expect(bruh.winnerName, 'BRUH Captain');
    expect(bruh.armorName, "BRUH Captain's Soul");

    final entry = list.firstWhere(
      (item) => item.id == '2026-04-03_raid_worldwide_top50',
    );
    expect(entry.winnerName, 'Volskaya');
    expect(entry.armorName, 'Volskaya Century');
    expect(entry.rankLimit, 50);
    expect(entry.mode, 'raid');
  });

  test('HallOfFamesLoader sorts descending and skips invalid entries', () {
    final validOld = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'id': '2026-04-03_raid_worldwide_top50',
      'eventDate': '2026-04-03',
      'postedDate': '2026-04-14',
      'mode': 'raid',
      'scope': 'worldwide',
      'rankLimit': 50,
      'title': 'Hall of Fame - Top 50 Worldwide',
      'winnerName': 'Volskaya',
      'armorName': 'Volskaya Century',
      'sourceUrl': 'https://example.com/old',
    });
    final validNew = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'id': '2026-04-17_blitz_worldwide_top50',
      'eventDate': '2026-04-17',
      'postedDate': '2026-04-28',
      'mode': 'blitz',
      'scope': 'worldwide',
      'rankLimit': 50,
      'title': 'Hall of Fame - Top 50 Worldwide',
      'winnerName': 'New Winner',
      'armorName': 'New Armor',
      'sourceUrl': 'https://example.com/new',
    });
    final invalid = jsonEncode(<String, Object?>{
      'schemaVersion': 1,
      'id': 'invalid',
      'eventDate': 'not-a-date',
      'mode': 'raid',
    });

    final list = HallOfFamesLoader.parseEntriesForTest(<String, String>{
      'assets/hall_of_fames/old.json': validOld,
      'assets/hall_of_fames/new.json': validNew,
      'assets/hall_of_fames/invalid.json': invalid,
      'assets/hall_of_fames/broken.json': '{',
    });

    expect(list.map((e) => e.id), <String>[
      '2026-04-17_blitz_worldwide_top50',
      '2026-04-03_raid_worldwide_top50',
    ]);
  });
}
