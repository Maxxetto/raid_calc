import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/config_models.dart';

void main() {
  test('PetTicksBarConfig.fromJson parses split pet bar file shape', () {
    final cfg = PetTicksBarConfig.fromJson(
      <String, Object?>{
        'enabled': true,
        'ticksPerState': 165,
        'startTicks': 165,
        'petCritPlusOneProb': 0.4,
        'bossNormal': <String, Object?>{'1': 1.0},
        'bossSpecial': <String, Object?>{'2': 1.0},
        'bossMiss': <String, Object?>{'1': 1.0},
        'stun': <String, Object?>{'1': 1.0},
        'petKnightBase': <String, Object?>{'10': 1.0},
        'modes': <String, Object?>{
          'normal': true,
          'specialRegen': true,
          'specialRegenPlusEw': true,
          'specialRegenEw': true,
          'shatterShield': true,
          'cycloneBoost': true,
          'durableRockShield': true,
          'epic': true,
        },
        'requireFirstKnightMatchForSrModes': true,
      },
    );

    expect(cfg.enabled, isTrue);
    expect(cfg.ticksPerState, 165);
    expect(cfg.startTicks, 165);
    expect(cfg.bossNormal.single.ticks, 1);
    expect(cfg.bossSpecial.single.ticks, 2);
    expect(cfg.petKnightBase.single.ticks, 10);
    expect(cfg.useInShatterShield, isTrue);
    expect(cfg.useInEpic, isTrue);
  });

  test('PetTicksBarConfig.fromRootJson remains compatible', () {
    // ignore: deprecated_member_use_from_same_package
    final fromRoot = PetTicksBarConfig.fromRootJson(
      <String, Object?>{
        'petTicksBar': <String, Object?>{
          'enabled': true,
          'ticksPerState': 100,
          'startTicks': 50,
          'modes': <String, Object?>{'normal': true},
        },
      },
    );

    expect(fromRoot.enabled, isTrue);
    expect(fromRoot.ticksPerState, 100);
    expect(fromRoot.startTicks, 50);
    expect(fromRoot.useInNormal, isTrue);
  });

  test('BossMeta.fromSources composes split sources with runtime overrides', () {
    final meta = BossMeta.fromSources(
      simRules: <String, Object?>{
        'cycleMultiplier': 1.385844,
        'thresholdEpicBoss': 80,
        'raidFreeEnergies': 30,
        'epicBossDamageBonus': 0.25,
        'evasionChance': 0.1,
        'criticalChance': 0.05,
        'criticalMultiplier': 1.5,
        'raidSpecialMultiplier': 3.25,
        'knightToSpecial': 5,
        'bossToSpecial': 6,
        'knightToSpecialSR': 7,
        'knightToRecastSpecialSR': 13,
        'knightToSpecialSREW': 7,
        'knightToRecastSpecialSREW': 13,
        'hitsToElementalWeakness': 7,
        'defaultElementalWeakness': 0.65,
        'durationElementalWeakness': 2,
        'bossToSpecialFakeEW': 1000,
        'hitsToFirstShatter': 7,
        'hitsToNextShatter': 13,
        'cyclone': 71.0,
        'hitsToDRS': 7,
        'durationDRS': 3,
        'defaultDurableRockShield': 0.5,
        'sameElementDRS': 1.6,
        'strongElementEW': 1.6,
        'timing': <String, Object?>{
          'normalDuration': 0.4,
          'specialDuration': 0.6,
          'stunDuration': 0.2,
          'missDuration': 0.3,
          'bossDuration': 0.4,
          'bossSpecialDuration': 0.7,
        },
      },
      petTicksBar: <String, Object?>{
        'enabled': true,
        'ticksPerState': 165,
        'startTicks': 165,
        'modes': <String, Object?>{'shatterShield': true},
      },
      overrides: <String, Object?>{
        'raidMode': false,
        'level': 4,
        'advVsKnights': <double>[1.0, 1.5, 2.0],
      },
    );

    expect(meta.raidMode, isFalse);
    expect(meta.level, 4);
    expect(meta.advVsKnights, <double>[1.0, 1.5, 2.0]);
    expect(meta.bossToSpecial, 6);
    expect(meta.petTicksBar.enabled, isTrue);
    expect(meta.petTicksBar.useInShatterShield, isTrue);
    expect(meta.timing.bossSpecialDuration, 0.7);
  });

  test('BossMeta.fromSources does not require a root-shaped petTicksBar field',
      () {
    final meta = BossMeta.fromSources(
      simRules: <String, Object?>{
        'evasionChance': 0.1,
        'criticalChance': 0.05,
        'criticalMultiplier': 1.5,
        'raidSpecialMultiplier': 3.25,
        'knightToSpecial': 5,
        'bossToSpecial': 6,
        'knightToSpecialSR': 7,
        'knightToRecastSpecialSR': 13,
        'knightToSpecialSREW': 7,
        'knightToRecastSpecialSREW': 13,
        'hitsToElementalWeakness': 7,
        'defaultElementalWeakness': 0.65,
        'durationElementalWeakness': 2,
        'bossToSpecialFakeEW': 1000,
        'hitsToFirstShatter': 7,
        'hitsToNextShatter': 13,
        'cyclone': 71.0,
        'hitsToDRS': 7,
        'durationDRS': 3,
        'defaultDurableRockShield': 0.5,
        'sameElementDRS': 1.6,
        'strongElementEW': 1.6,
        'cycleMultiplier': 1.385844,
        'timing': <String, Object?>{
          'bossSpecialDuration': 0.7,
        },
      },
      petTicksBar: <String, Object?>{
        'enabled': true,
        'ticksPerState': 200,
        'startTicks': 120,
        'modes': <String, Object?>{
          'specialRegen': true,
        },
      },
      overrides: <String, Object?>{
        'raidMode': true,
        'level': 2,
      },
    );

    expect(meta.petTicksBar.enabled, isTrue);
    expect(meta.petTicksBar.ticksPerState, 200);
    expect(meta.petTicksBar.startTicks, 120);
    expect(meta.petTicksBar.useInSpecialRegen, isTrue);
    expect(meta.petTicksBar.useInNormal, isTrue);
  });
}
