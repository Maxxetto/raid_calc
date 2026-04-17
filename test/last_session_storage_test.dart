import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/element_types.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/last_session_storage.dart';
import 'package:raid_calc/data/setup_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel pathChannel =
      MethodChannel('plugins.flutter.io/path_provider');

  late Directory docsDir;

  setUpAll(() async {
    docsDir = await Directory.systemTemp.createTemp('raid_calc_session_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      pathChannel,
      (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return docsDir.path;
        }
        return null;
      },
    );
  });

  tearDown(() async {
    await LastSessionStorage.clear();
  });

  SetupSlotRecord slotRecord(int slot, {required String bossMode}) {
    return SetupSlotRecord(
      slot: slot,
      savedAt: DateTime.utc(2026, 2, 22, 10, slot, 0),
      setup: SetupSnapshot(
        bossMode: bossMode,
        bossLevel: bossMode == 'raid' ? 4 : 3,
        bossElements: const <ElementType>[ElementType.fire, ElementType.water],
        knights: List<SetupKnightSnapshot>.generate(
          3,
          (i) => SetupKnightSnapshot(
            atk: 1000 + (slot * 100) + i,
            def: 2000 + i,
            hp: 3000 + i,
            stun: i * 5.0,
            elements: const <ElementType>[ElementType.fire, ElementType.fire],
            active: i != 1,
          ),
          growable: false,
        ),
        pet: const SetupPetSnapshot(
          atk: 123,
          element1: ElementType.air,
          element2: null,
        ),
        modeEffects: const SetupModeEffectsSnapshot(
          cycloneUseGemsForSpecials: false,
        ),
      ),
    );
  }

  test('save/load with 0 setups keeps homeState valid', () async {
    final data = LastSessionData(
      homeState: <String, Object?>{
        'v': 12,
        'shellIndex': 2,
        'bossMode': 'raid',
        'bossLevel': 1,
        'saveLastSimulationPersistently': false,
        'setups': <Object?>[],
      },
      lastStats: null,
      openResultsOnStart: false,
      premiumExpiryMs: 0,
      savedAt: DateTime.utc(2026, 2, 22),
    );

    await LastSessionStorage.save(data);
    final loaded = await LastSessionStorage.load();

    expect(loaded, isNotNull);
    expect(loaded!.homeState['bossMode'], 'raid');
    expect(loaded.homeState['shellIndex'], 2);
    expect(loaded.homeState['saveLastSimulationPersistently'], isFalse);
    final setups = (loaded.homeState['setups'] as List?)?.cast<Object?>();
    expect(setups, isNotNull);
    expect(setups, isEmpty);
  });

  test('save/load with 1 setup preserves setup payload', () async {
    final slot1 = slotRecord(1, bossMode: 'raid');
    final data = LastSessionData(
      homeState: <String, Object?>{
        'v': 12,
        'bossMode': 'blitz',
        'setups': <Object?>[slot1.toJson()],
      },
      lastStats: null,
      openResultsOnStart: false,
      premiumExpiryMs: 0,
      savedAt: DateTime.utc(2026, 2, 22),
    );

    await LastSessionStorage.save(data);
    final loaded = await LastSessionStorage.load();

    final setups = (loaded!.homeState['setups'] as List?)!
        .whereType<Map>()
        .map((e) => SetupSlotRecord.fromJson(e.cast<String, Object?>()))
        .toList(growable: false);

    expect(setups, hasLength(1));
    expect(setups.single.slot, 1);
    expect(setups.single.setup.bossMode, 'raid');
    expect(setups.single.setup.knights[0].atk, 1100);
  });

  test('save/load with 3 setups preserves all slots', () async {
    final records = <SetupSlotRecord>[
      slotRecord(1, bossMode: 'raid'),
      slotRecord(2, bossMode: 'blitz'),
      slotRecord(3, bossMode: 'raid'),
    ];

    final data = LastSessionData(
      homeState: <String, Object?>{
        'v': 12,
        'setups': records.map((e) => e.toJson()).toList(growable: false),
      },
      lastStats: null,
      openResultsOnStart: false,
      premiumExpiryMs: 0,
      savedAt: DateTime.utc(2026, 2, 22),
    );

    await LastSessionStorage.save(data);
    final loaded = await LastSessionStorage.load();

    final setups = (loaded!.homeState['setups'] as List?)!
        .whereType<Map>()
        .map((e) => SetupSlotRecord.fromJson(e.cast<String, Object?>()))
        .toList(growable: false);

    expect(setups, hasLength(3));
    expect(setups.map((e) => e.slot), orderedEquals(<int>[1, 2, 3]));
    expect(setups[1].setup.bossMode, 'blitz');
  });

  test('LastSessionData.fromJson remains compatible without setups key', () {
    final legacy = <String, Object?>{
      'homeState': <String, Object?>{
        'v': 12,
        'bossMode': 'raid',
        'bossLevel': 4,
      },
      'lastStats': null,
      'openResultsOnStart': false,
      'premiumExpiryMs': 0,
      'savedAtIso': '2026-02-22T00:00:00.000Z',
    };

    final parsed = LastSessionData.fromJson(legacy);

    expect(parsed.homeState['bossMode'], 'raid');
    expect(parsed.homeState.containsKey('setups'), isFalse);
  });

  test('storage load handles raw legacy file without setups', () async {
    final dir = Directory('${docsDir.path}/raid_calc');
    await dir.create(recursive: true);
    final file = File('${dir.path}/raid_calc_last_session.json');

    final raw = <String, Object?>{
      'homeState': <String, Object?>{
        'v': 12,
        'bossMode': 'blitz',
        'bossLevel': 2,
      },
      'lastStats': null,
      'openResultsOnStart': false,
      'premiumExpiryMs': 0,
      'savedAtIso': '2026-02-22T00:00:00.000Z',
    };
    await file.writeAsString(jsonEncode(raw), flush: true);

    final loaded = await LastSessionStorage.load();

    expect(loaded, isNotNull);
    expect(loaded!.homeState['bossMode'], 'blitz');
    expect(loaded.homeState.containsKey('setups'), isFalse);
  });

  test('legacy setup in session storage rebuilds pet loadout metadata',
      () async {
    final dir = Directory('${docsDir.path}/raid_calc');
    await dir.create(recursive: true);
    final file = File('${dir.path}/raid_calc_last_session.json');

    final raw = <String, Object?>{
      'homeState': <String, Object?>{
        'v': 12,
        'bossMode': 'raid',
        'setups': <Object?>[
          <String, Object?>{
            'slot': 1,
            'savedAtIso': '2026-03-21T10:00:00.000Z',
            'setup': <String, Object?>{
              'v': 1,
              'bossMode': 'raid',
              'bossLevel': 4,
              'bossElements': <Object?>['air', 'water'],
              'knights': <Object?>[
                <String, Object?>{
                  'atk': 1000,
                  'def': 1000,
                  'hp': 1000,
                  'stun': 0
                },
                <String, Object?>{
                  'atk': 1000,
                  'def': 1000,
                  'hp': 1000,
                  'stun': 0
                },
                <String, Object?>{
                  'atk': 1000,
                  'def': 1000,
                  'hp': 1000,
                  'stun': 0
                },
              ],
              'knightElements': <Object?>[
                <Object?>['fire', 'fire'],
                <Object?>['fire', 'fire'],
                <Object?>['fire', 'fire'],
              ],
              'activeKnights': <Object?>[true, true, true],
              'pet': <String, Object?>{
                'atk': 6583,
                'elementalAtk': 1393,
                'elementalDef': 1174,
                'elements': <Object?>['water', 'fire'],
                'skillUsage': PetSkillUsageMode.special2Only.name,
                'importedCompendium': <String, Object?>{
                  'familyId': 's101sf_ignitide',
                  'familyTag': 'S101SF',
                  'rarity': 'Shadowforged',
                  'tierId': 'V',
                  'tierName': '[S101SF] Ignitide',
                  'profileId': 'max',
                  'profileLabel': 'Max 99',
                  'useAltSkillSet': false,
                  'selectedSkill1': <String, Object?>{
                    'slotId': 'skill11',
                    'name': 'Revenge Strike',
                    'values': <String, Object?>{'petAttackCap': 12912},
                  },
                  'selectedSkill2': <String, Object?>{
                    'slotId': 'skill2',
                    'name': 'Shatter Shield',
                    'values': <String, Object?>{
                      'baseShieldHp': 178,
                      'bonusShieldHp': 48,
                    },
                  },
                },
              },
            },
          },
        ],
      },
      'lastStats': null,
      'openResultsOnStart': false,
      'premiumExpiryMs': 0,
      'savedAtIso': '2026-03-21T10:00:00.000Z',
    };
    await file.writeAsString(jsonEncode(raw), flush: true);

    final loaded = await LastSessionStorage.load();
    final setups = (loaded!.homeState['setups'] as List?)!
        .whereType<Map>()
        .map((e) => SetupSlotRecord.fromJson(e.cast<String, Object?>()))
        .toList(growable: false);

    expect(setups.single.setup.pet.resolvedEffects, hasLength(2));
    expect(
      setups.single.setup.pet.importedCompendium?.selectedSkill2
          .canonicalEffectId,
      'shatter_shield',
    );
  });
}
