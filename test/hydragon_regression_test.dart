import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/debug/debug_run.dart';
import 'package:raid_calc/data/config_models.dart';

const _preJson = r'''
{
  "meta": {
    "raidMode": true,
    "level": 4,
    "advVsKnights": [1.0, 1.5, 2.0],
    "evasionChance": 0.1,
    "criticalChance": 0.05,
    "criticalMultiplier": 1.5,
    "raidSpecialMultiplier": 3.25,
    "hitsToFirstShatter": 7,
    "hitsToNextShatter": 13,
    "knightToSpecial": 5,
    "bossToSpecial": 6,
    "bossToSpecialFakeEW": 1000,
    "knightToSpecialSR": 7,
    "knightToRecastSpecialSR": 13,
    "knightToSpecialSREW": 7,
    "knightToRecastSpecialSREW": 13,
    "hitsToElementalWeakness": 7,
    "durationElementalWeakness": 2,
    "defaultElementalWeakness": 0.65,
    "cyclone": 71.0,
    "defaultDurableRockShield": 0.5,
    "sameElementDRS": 1.6,
    "strongElementEW": 1.6,
    "hitsToDRS": 7,
    "durationDRS": 3,
    "cycleMultiplier": 1.385844,
    "epicBossDamageBonus": 0.25,
    "timing": {
      "normalDuration": 0.4,
      "specialDuration": 0.6,
      "stunDuration": 0.2,
      "missDuration": 0.3,
      "bossDuration": 0.4,
      "bossSpecialDuration": 0.7
    },
    "petTicksBar": {
      "enabled": true,
      "ticksPerState": 165,
      "startTicks": 165,
      "petCritPlusOneProb": 0.1,
      "bossNormal": [{"ticks": 2, "weight": 1.0}],
      "bossSpecial": [{"ticks": 4, "weight": 1.0}],
      "bossMiss": [{"ticks": 1, "weight": 1.0}],
      "stun": [{"ticks": 1, "weight": 1.0}],
      "petKnightBase": [{"ticks": 12, "weight": 1.0}],
      "modes": {
        "normal": true,
        "specialRegen": true,
        "specialRegenPlusEw": true,
        "specialRegenEw": true,
        "shatterShield": true,
        "cycloneBoost": true,
        "durableRockShield": true,
        "epic": true
      },
      "requireFirstKnightMatchForSrModes": true
    }
  },
  "stats": {
    "attack": 20300.0,
    "defense": 3250.0,
    "hp": 100000000
  },
  "kAtk": [78066.0, 78724.0, 84336.0],
  "kDef": [64867.0, 65885.0, 67331.0],
  "kHp": [1821, 1827, 1969],
  "kAdv": [1.0, 1.0, 1.0],
  "kStun": [0.25, 0.25, 0.25],
  "petAtk": 6235.0,
  "petAdv": 1.0,
  "petSkillUsage": "doubleSpecial2ThenSpecial1",
  "petEffects": [
    {
      "sourceSlotId": "skill11",
      "sourceSkillName": "Elemental Weakness",
      "values": {"enemyAttackReductionPercent": 61.6, "turns": 2},
      "canonicalEffectId": "elemental_weakness",
      "canonicalName": "Elemental Weakness",
      "effectCategory": "boss_attack_debuff",
      "dataSupport": "structured_values",
      "runtimeSupport": "mode_specific",
      "simulatorModes": ["specialRegenPlusEw", "specialRegenEw"],
      "effectSpec": {}
    },
    {
      "sourceSlotId": "skill2",
      "sourceSkillName": "Special Regeneration",
      "values": {"meterChargePercent": 101.5},
      "canonicalEffectId": "special_regeneration",
      "canonicalName": "Special Regeneration",
      "effectCategory": "special_meter_acceleration",
      "dataSupport": "structured_values",
      "runtimeSupport": "mode_specific",
      "simulatorModes": ["specialRegen", "specialRegenPlusEw"],
      "effectSpec": {}
    }
  ],
  "kNormalDmg": [3939, 3973, 4256],
  "kCritDmg": [5909, 5959, 6384],
  "kSpecialDmg": [12802, 12912, 13832],
  "petNormalDmg": 315,
  "petCritDmg": 472,
  "bNormalDmg": [37, 55, 72],
  "bCritDmg": [56, 83, 108]
}
''';

void main() {
  test('Hydragon SR+EW regression snapshot', () async {
    final pre = Precomputed.fromJson(
      (jsonDecode(_preJson) as Map<String, dynamic>).cast<String, Object?>(),
    );
    final model = DamageModel();
    const shatter = ShatterShieldConfig(
      baseHp: 178,
      bonusHp: 48,
      elementMatch: <bool>[true, true, false],
      strongElementEw: <bool>[false, false, false],
    );
    final stats = await model.simulate(
      pre,
      runs: 1000,
      shatter: shatter,
      withTiming: false,
    );
    final debug = DebugSimulator.run(
      pre,
      labels: const <String, String>{},
      shatter: shatter,
      seed: 12345,
    );
    expect(stats.mean, greaterThan(0));
    expect(debug.points, greaterThan(0));
  });

  test('skill-driven pet effects force the generic runner even on isolate path',
      () async {
    final pre = Precomputed.fromJson(
      (jsonDecode(_preJson) as Map<String, dynamic>).cast<String, Object?>(),
    );
    const shatter = ShatterShieldConfig(
      baseHp: 178,
      bonusHp: 48,
      elementMatch: <bool>[true, true, false],
      strongElementEw: <bool>[false, false, false],
    );
    final model = DamageModel();

    final small = await model.simulate(
      pre,
      runs: 1000,
      shatter: shatter,
      withTiming: false,
    );
    final large = await model.simulate(
      pre,
      runs: 60000,
      shatter: shatter,
      withTiming: false,
    );

    expect((large.mean - small.mean).abs(), lessThan(150000));
  });

  test(
      'Hydragon infinite SR yields more score than normal SR on the same setup',
      () async {
    final baseMap =
        (jsonDecode(_preJson) as Map<String, dynamic>).cast<String, Object?>();
    final infiniteEffects = List<Map<String, Object?>>.from(
      ((baseMap['petEffects'] as List?) ?? const <Object?>[])
          .whereType<Map>()
          .map((e) => e.cast<String, Object?>()),
    );
    infiniteEffects[1] = <String, Object?>{
      ...infiniteEffects[1],
      'sourceSkillName': 'Special Regeneration (inf)',
      'canonicalEffectId': 'special_regeneration_infinite',
      'canonicalName': 'Special Regeneration (inf)',
      'values': <String, Object?>{'meterChargePercent': 70},
    };

    final normalPre = Precomputed.fromJson(baseMap);
    final infinitePre = Precomputed.fromJson(
      <String, Object?>{
        ...baseMap,
        'petEffects': infiniteEffects,
      },
    );
    final model = DamageModel();
    const shatter = ShatterShieldConfig(
      baseHp: 178,
      bonusHp: 48,
      elementMatch: <bool>[true, true, false],
      strongElementEw: <bool>[false, false, false],
    );

    final normalStats = await model.simulate(
      normalPre,
      runs: 2000,
      shatter: shatter,
      withTiming: false,
    );
    final infiniteStats = await model.simulate(
      infinitePre,
      runs: 2000,
      shatter: shatter,
      withTiming: false,
    );

    expect(infiniteStats.mean, greaterThan(normalStats.mean));
  });
}
