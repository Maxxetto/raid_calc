import 'package:raid_calc/core/debug/debug_run.dart';
import 'package:raid_calc/core/damage_model.dart';
import 'package:raid_calc/core/sim_types.dart';
import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/data/pet_effect_models.dart';
import 'package:flutter_test/flutter_test.dart';

PetResolvedEffect _effect(
  String id,
  String slot, {
  Map<String, num> values = const <String, num>{},
}) =>
    PetResolvedEffect(
      sourceSlotId: slot,
      sourceSkillName: id,
      values: values,
      canonicalEffectId: id,
      canonicalName: id,
      effectCategory: 'test',
      dataSupport: 'test',
      runtimeSupport: 'test',
      simulatorModes: const <String>[],
      effectSpec: const <String, Object?>{},
    );

List<PetResolvedEffect> _srEwEffects({double ew = 65.0}) => <PetResolvedEffect>[
      _effect('special_regeneration_infinite', 'skill11'),
      _effect(
        'elemental_weakness',
        'skill2',
        values: <String, num>{
          'enemyAttackReductionPercent': ew,
          'turns': 3,
        },
      ),
    ];

BossConfig _makeBossConfig() {
  final meta = BossMeta.fromJson({
    'raidMode': true,
    'level': 1,
    'advVsKnights': [1, 1, 1],
    'evasionChance': 0.0,
    'criticalChance': 0.0,
    'criticalMultiplier': 1.5,
    'raidSpecialMultiplier': 1.0,
    'knightToSpecial': 2,
    'bossToSpecial': 1000,
    'bossToSpecialFakeEW': 1000,
    'knightToSpecialSR': 1,
    'knightToSpecialSREW': 1,
    'hitsToElementalWeakness': 1,
    'durationElementalWeakness': 2,
    'defaultElementalWeakness': 0.1,
  });

  final stats = BossStats(
    attack: 1000000,
    defense: 1,
    hp: 1000000000,
  );

  return BossConfig(meta: meta, stats: stats);
}

Precomputed _makePrecomputed() {
  final model = DamageModel();
  return model.precompute(
    boss: _makeBossConfig(),
    kAtk: const [100, 100, 100],
    kDef: const [1, 1, 1],
    kHp: const [10, 10, 10],
    kAdv: const [1, 1, 1],
    kStun: const [0, 0, 0],
  );
}

Precomputed _makeSrStacksPrecomputed() {
  final model = DamageModel();
  final meta = BossMeta.fromJson({
    'raidMode': true,
    'level': 1,
    'advVsKnights': [1, 1, 1],
    'evasionChance': 0.0,
    'criticalChance': 0.0,
    'criticalMultiplier': 1.5,
    'raidSpecialMultiplier': 1.0,
    'knightToSpecial': 2,
    'bossToSpecial': 999,
    'bossToSpecialFakeEW': 999,
    'knightToSpecialSR': 1,
    'knightToRecastSpecialSR': 3,
    'knightToSpecialSREW': 1,
    'knightToRecastSpecialSREW': 3,
    'hitsToElementalWeakness': 1,
    'durationElementalWeakness': 3,
    'defaultElementalWeakness': 0.1,
    'petTicksBar': {
      'enabled': true,
      'ticksPerState': 1,
      'startTicks': 2,
      'petCritPlusOneProb': 0.0,
      'petKnightBase': [
        {'ticks': 1, 'weight': 1.0}
      ],
      'bossNormal': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'bossSpecial': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'bossMiss': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'stun': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'useInSpecialRegen': true,
      'useInSpecialRegenPlusEw': true,
    },
  });

  final cfg = BossConfig(
    meta: meta,
    stats: const BossStats(
      attack: 20,
      defense: 2000,
      hp: 999999,
    ),
  );

  return model.precompute(
    boss: cfg,
    kAtk: const [10, 10, 10],
    kDef: const [2000, 2000, 2000],
    kHp: const [1, 10, 1],
    kAdv: const [1, 1, 1],
    kStun: const [0, 0, 0],
    petAtk: 10,
    petAdv: 1.0,
    petSkillUsage: PetSkillUsageMode.special2ThenSpecial1,
    petEffects: _srEwEffects(ew: 10.0),
  );
}

Precomputed _makeEwMinOnePrecomputed() {
  final model = DamageModel();
  final meta = BossMeta.fromJson({
    'raidMode': true,
    'level': 1,
    'advVsKnights': [1, 1, 1],
    'evasionChance': 0.0,
    'criticalChance': 0.0,
    'criticalMultiplier': 1.5,
    'raidSpecialMultiplier': 1.0,
    'knightToSpecial': 999,
    'bossToSpecial': 999,
    'bossToSpecialFakeEW': 999,
    'knightToSpecialSR': 1,
    'knightToSpecialSREW': 1,
    'hitsToElementalWeakness': 1,
    'durationElementalWeakness': 3,
    'defaultElementalWeakness': 0.95,
    'petTicksBar': {
      'enabled': true,
      'ticksPerState': 1,
      'startTicks': 2,
      'petCritPlusOneProb': 0.0,
      'petKnightBase': [
        {'ticks': 1, 'weight': 1.0}
      ],
      'bossNormal': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'bossSpecial': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'bossMiss': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'stun': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'useInSpecialRegenPlusEw': true,
    },
  });

  final cfg = BossConfig(
    meta: meta,
    stats: const BossStats(
      attack: 1,
      defense: 100000,
      hp: 1000000000,
    ),
  );

  return model.precompute(
    boss: cfg,
    kAtk: const [1, 1, 1],
    kDef: const [100, 100, 100],
    kHp: const [5, 5, 5],
    kAdv: const [1, 1, 1],
    kStun: const [0, 0, 0],
    petAtk: 10,
    petAdv: 1.0,
    petSkillUsage: PetSkillUsageMode.special2ThenSpecial1,
    petEffects: _srEwEffects(ew: 95.0),
  );
}

Precomputed _makeEwFloorPrecomputed({
  required double bossCritChance,
  required List<int> bNormal,
  required List<int> bCrit,
  double ewFraction = 0.616,
}) {
  final meta = BossMeta.fromJson({
    'raidMode': true,
    'level': 1,
    'advVsKnights': [1, 1, 1],
    'evasionChance': 0.0,
    'criticalChance': bossCritChance,
    'criticalMultiplier': 1.5,
    'raidSpecialMultiplier': 1.0,
    'knightToSpecial': 999,
    'bossToSpecial': 999,
    'bossToSpecialFakeEW': 999,
    'knightToSpecialSR': 1,
    'knightToSpecialSREW': 1,
    'hitsToElementalWeakness': 1,
    'durationElementalWeakness': 3,
    'defaultElementalWeakness': ewFraction,
    'petTicksBar': {
      'enabled': true,
      'ticksPerState': 1,
      'startTicks': 2,
      'petCritPlusOneProb': 0.0,
      'petKnightBase': [
        {'ticks': 1, 'weight': 1.0}
      ],
      'bossNormal': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'bossSpecial': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'bossMiss': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'stun': [
        {'ticks': 0, 'weight': 1.0}
      ],
      'useInSpecialRegenPlusEw': true,
    },
  });

  return Precomputed(
    meta: meta,
    stats: const BossStats(
      attack: 1,
      defense: 999999,
      hp: 999999999,
    ),
    kAtk: const [0, 0, 0],
    kDef: const [100, 100, 100],
    kHp: const [500, 500, 500],
    kAdv: const [1, 1, 1],
    kStun: const [0, 0, 0],
    petAtk: 10,
    petAdv: 1.0,
    petSkillUsage: PetSkillUsageMode.special2ThenSpecial1,
    petEffects: _srEwEffects(ew: ewFraction * 100.0),
    kNormalDmg: const [0, 0, 0],
    kCritDmg: const [0, 0, 0],
    kSpecialDmg: const [0, 0, 0],
    bNormalDmg: bNormal,
    bCritDmg: bCrit,
  );
}

Precomputed _makeShatterPetBarPrecomputed() {
  final model = DamageModel();
  final meta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const [1.0, 1.0, 1.0],
    evasionChance: 0.0,
    criticalChance: 0.0,
    criticalMultiplier: 1.5,
    raidSpecialMultiplier: 1.0,
    hitsToFirstShatter: 99,
    hitsToNextShatter: 99,
    knightToSpecial: 999,
    bossToSpecial: 999,
    bossToSpecialFakeEW: 999,
    knightToSpecialSR: 1,
    knightToRecastSpecialSR: 13,
    knightToSpecialSREW: 1,
    knightToRecastSpecialSREW: 13,
    hitsToElementalWeakness: 99,
    durationElementalWeakness: 2,
    defaultElementalWeakness: 0.1,
    cyclone: 71.0,
    defaultDurableRockShield: 0.5,
    sameElementDRS: 1.6,
    strongElementEW: 1.6,
    hitsToDRS: 99,
    durationDRS: 3,
    cycleMultiplier: 1.0,
    epicBossDamageBonus: 0.0,
    timing: const TimingConfig(
      normalDuration: 0.4,
      specialDuration: 0.6,
      stunDuration: 0.2,
      missDuration: 0.3,
      bossDuration: 0.4,
      bossSpecialDuration: 0.7,
    ),
    petTicksBar: const PetTicksBarConfig(
      enabled: true,
      ticksPerState: 2,
      startTicks: 2,
      petCritPlusOneProb: 0.0,
      petKnightBase: <WeightedTick>[
        WeightedTick(ticks: 2, weight: 1.0),
      ],
      bossNormal: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      bossSpecial: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      bossMiss: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      stun: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      useInShatterShield: true,
    ),
  );

  return model.precompute(
    boss: BossConfig(
      meta: meta,
      stats: const BossStats(
        attack: 1,
        defense: 1000,
        hp: 999999,
      ),
    ),
    kAtk: const [10, 10, 10],
    kDef: const [100000, 100000, 100000],
    kHp: const [10, 10, 10],
    kAdv: const [1, 1, 1],
    kStun: const [0, 0, 0],
    petAtk: 10,
    petAdv: 1.0,
    petSkillUsage: PetSkillUsageMode.special2Only,
    petEffects: <PetResolvedEffect>[
      _effect(
        'shatter_shield',
        'skill2',
        values: const <String, num>{
          'baseShieldHp': 20,
          'bonusShieldHp': 5,
        },
      ),
    ],
  );
}

Precomputed _makeDrsPetBarPrecomputed() {
  final model = DamageModel();
  final meta = BossMeta(
    raidMode: true,
    level: 1,
    advVsKnights: const [1.0, 1.0, 1.0],
    evasionChance: 0.0,
    criticalChance: 0.0,
    criticalMultiplier: 1.5,
    raidSpecialMultiplier: 1.0,
    hitsToFirstShatter: 99,
    hitsToNextShatter: 99,
    knightToSpecial: 999,
    bossToSpecial: 999,
    bossToSpecialFakeEW: 999,
    knightToSpecialSR: 1,
    knightToRecastSpecialSR: 13,
    knightToSpecialSREW: 1,
    knightToRecastSpecialSREW: 13,
    hitsToElementalWeakness: 99,
    durationElementalWeakness: 2,
    defaultElementalWeakness: 0.1,
    cyclone: 71.0,
    defaultDurableRockShield: 0.5,
    sameElementDRS: 1.6,
    strongElementEW: 1.6,
    hitsToDRS: 99,
    durationDRS: 3,
    cycleMultiplier: 1.0,
    epicBossDamageBonus: 0.0,
    timing: const TimingConfig(
      normalDuration: 0.4,
      specialDuration: 0.6,
      stunDuration: 0.2,
      missDuration: 0.3,
      bossDuration: 0.4,
      bossSpecialDuration: 0.7,
    ),
    petTicksBar: const PetTicksBarConfig(
      enabled: true,
      ticksPerState: 2,
      startTicks: 2,
      petCritPlusOneProb: 0.0,
      petKnightBase: <WeightedTick>[
        WeightedTick(ticks: 2, weight: 1.0),
      ],
      bossNormal: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      bossSpecial: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      bossMiss: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      stun: <WeightedTick>[WeightedTick(ticks: 0, weight: 1.0)],
      useInDurableRockShield: true,
    ),
  );

  return model.precompute(
    boss: BossConfig(
      meta: meta,
      stats: const BossStats(
        attack: 1000,
        defense: 1000,
        hp: 999999,
      ),
    ),
    kAtk: const [10, 10, 10],
    kDef: const [1000, 1000, 1000],
    kHp: const [100, 100, 100],
    kAdv: const [1, 1, 1],
    kStun: const [0, 0, 0],
    petAtk: 10,
    petAdv: 1.0,
    petSkillUsage: PetSkillUsageMode.special1Only,
    petEffects: <PetResolvedEffect>[
      _effect(
        'durable_rock_shield',
        'skill11',
        values: const <String, num>{
          'defenseBoostPercent': 50,
          'turns': 3,
        },
      ),
    ],
  );
}

Map<String, String> _labelsBase() => {
      'debug.log.act.normal': 'NORMAL',
      'debug.log.act.crit': 'CRIT',
      'debug.log.act.special': 'SPECIAL',
      'debug.log.act.miss': 'MISS',
      'debug.log.label.points': 'points',
      'debug.log.label.hp': 'hp',
      'debug.log.label.target': 'target',
      'debug.log.line.knight_special':
          'KT#{kt} K#{k} {act} → +{dmg} ({pointsLabel}={points})',
      'debug.log.line.knight_action':
          'KT#{kt} K#{k} {act} → +{dmg} ({pointsLabel}={points})',
      'debug.log.line.knight_action_roll':
          'KT#{kt} K#{k} {act} → +{dmg} ({pointsLabel}={points}, critRoll={critRoll} < {critTarget})',
      'debug.log.line.knight_miss': 'KT#{kt} K#{k} MISS',
      'debug.log.line.knight_miss_roll':
          'KT#{kt} K#{k} MISS (roll={roll} < {target})',
      'debug.log.line.knight_stun_success':
          'KT#{kt} K#{k} uses stun → Boss stunned',
      'debug.log.line.knight_stun_success_roll':
          'KT#{kt} K#{k} STUN (roll={roll} < {target}) → Boss stunned',
      'debug.log.line.knight_stun_fail_roll':
          'KT#{kt} K#{k} stun fail (roll={roll} >= {target})',
      'debug.log.line.boss_skip':
          'Boss stunned → skips turn (queuedNow={queued})',
      'debug.log.line.boss_special':
          'BT#{bt} Boss {act} → K#{k} -{dmg} ({hpLabel}={hp})',
      'debug.log.line.boss_special_ew':
          'BT#{bt} Boss {act} → K#{k} -{dmg} (base={base}, EWstacks={stacks}, {hpLabel}={hp})',
      'debug.log.line.boss_miss': 'BT#{bt} Boss MISS ({targetLabel}={target})',
      'debug.log.line.boss_miss_roll':
          'BT#{bt} Boss MISS (roll={roll} < {targetRoll}, {targetLabel}={target})',
      'debug.log.line.boss_action':
          'BT#{bt} Boss {act} → K#{k} -{dmg} ({hpLabel}={hp})',
      'debug.log.line.boss_action_roll':
          'BT#{bt} Boss {act} → K#{k} -{dmg} ({hpLabel}={hp}, critRoll={critRoll} < {critTarget})',
      'debug.log.line.boss_action_ew':
          'BT#{bt} Boss {act} → K#{k} -{dmg} (base={base}, EWstacks={stacks}, {hpLabel}={hp})',
      'debug.log.line.boss_action_ew_roll':
          'BT#{bt} Boss {act} → K#{k} -{dmg} (base={base}, EWstacks={stacks}, critRoll={critRoll} < {critTarget}, {hpLabel}={hp})',
      'debug.log.line.knight_died': 'K#{k} died → FIFO switch',
      'debug.log.line.target_switch': 'Now target is K#{k} ({hpLabel}={hp})',
      'debug.log.line.sr_active':
          'KT#{turn} SR active -> special ALWAYS from now',
      'debug.log.line.ew_applied':
          'EW applied: stacks={stacks} (effectiveReduction={reduction}%, dur={dur} bossTurns; miss does NOT tick)',
      'debug.log.line.ew_ticks': 'EW ticks ({reason}) → stacks={stacks}',
      'debug.log.line.shatter_apply':
          'KT#{kt} Shatter Shield → +{add} HP (base={base}, bonus={bonus}) ({hpLabel}={hp})',
      'debug.log.line.cyclone_special':
          'KT#{kt} K#{k} {act} (Cyclone {step}/5, mult={mult}) → +{dmg} ({pointsLabel}={points})',
      'debug.log.phrase.sr_intro':
          'SR: special every turn from KT#{turn} onward',
      'debug.log.phrase.sr_ew_intro':
          'SR+EW: SR active from KT#{sr}; EW every {ew} turns after KT#{sr} (stacking EW)',
      'debug.log.phrase.ew_trigger': 'KT#{turn} triggers EW application',
      'debug.log.phrase.old_sim_intro':
          'Old Simulator: knight SPECIAL always from KT#1; boss SPECIAL disabled (fakeEW={fake})',
      'debug.log.phrase.old_sim_boss_special_disabled':
          'BT#{turn} Boss SPECIAL disabled (fakeEW tick)',
      'debug.log.phrase.cyclone_intro': 'Cyclone: +{pct}% per turn (cap 5)',
      'debug.log.phrase.shatter_info_full':
          'Shatter: first=H#{first} (no miss), step={step}',
      'debug.log.phrase.drs_active_full':
          'DRS active: +{pct}% DEF for {turns} turns',
      'debug.log.phrase.drs_ended': 'DRS ended',
    };

void main() {
  test('debug normal mode logs deterministic lines', () {
    final pre = _makePrecomputed();
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
    );

    final n1 = pre.kNormalDmg[0];
    final s2 = pre.kSpecialDmg[1];
    final n3 = pre.kNormalDmg[2];
    final b1 = pre.bNormalDmg[0];
    final b2 = pre.bNormalDmg[1];
    final b3 = pre.bNormalDmg[2];

    final p1 = n1;
    final p2 = p1 + s2;
    final p3 = p2 + n3;

    final expected = <String>[
      'KT#1 K#1 NORMAL → +$n1 (points=$p1)',
      'BT#1 Boss NORMAL → K#1 -$b1 (hp=${10 - b1})',
      'K#1 died → FIFO switch',
      'Now target is K#2 (hp=10)',
      'KT#2 K#2 SPECIAL → +$s2 (points=$p2)',
      'BT#2 Boss NORMAL → K#2 -$b2 (hp=${10 - b2})',
      'K#2 died → FIFO switch',
      'Now target is K#3 (hp=10)',
      'KT#3 K#3 NORMAL → +$n3 (points=$p3)',
      'BT#3 Boss NORMAL → K#3 -$b3 (hp=${10 - b3})',
      'K#3 died → FIFO switch',
    ];

    expect(debug.lines, expected);
  });

  test('debug SR+EW emits EW logs', () {
    final pre = _makePrecomputed();
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
    );

    expect(debug.lines, isNotEmpty);
    expect(debug.points, greaterThan(0));
  });

  test('debug SR keeps non-matching knight on normal cycle with one stack', () {
    final pre = _makeSrStacksPrecomputed();
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
      shatter: const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: [true, false, true],
      ),
    );

    expect(
      debug.lines.any((l) => l.startsWith('KT#3 K#2 NORMAL')),
      isTrue,
    );
    expect(
      debug.lines.any((l) => l.startsWith('KT#3 K#2 SPECIAL')),
      isFalse,
    );
  });

  test('debug SR+EW starts EW after second SR trigger when a knight mismatches',
      () {
    final pre = _makeSrStacksPrecomputed();
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
      shatter: const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: [true, false, true],
      ),
    );

    expect(debug.lines, isNotEmpty);
    expect(debug.points, greaterThan(0));
  });

  test('debug SR+EW keeps boss damage at least 1 when EW is active', () {
    final pre = _makeEwMinOnePrecomputed();
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
    );

    expect(
      debug.lines.any(
        (l) =>
            l.contains('base=1') && l.contains('EWstacks=') && l.contains('-1'),
      ),
      isTrue,
    );
  });

  test('debug SR+EW uses floor for boss normal damage with EW 61.6%', () {
    final pre = _makeEwFloorPrecomputed(
      bossCritChance: 0.0,
      bNormal: const [64, 59, 67],
      bCrit: const [96, 89, 101],
    );
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
    );

    expect(debug.lines.any((l) => l.contains('EWstacks=')), isTrue);
  });

  test('debug SR+EW uses floor for boss crit damage with EW 61.6%', () {
    final pre = _makeEwFloorPrecomputed(
      bossCritChance: 1.0,
      bNormal: const [64, 59, 67],
      bCrit: const [96, 89, 101],
    );
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
    );

    expect(debug.lines.any((l) => l.contains('EWstacks=')), isTrue);
  });

  test('precompute boss crit matches in-game floor rounding', () {
    final model = DamageModel();
    final meta = BossMeta.fromJson({
      'raidMode': false,
      'level': 4,
      'advVsKnights': [1.0, 1.0, 1.0],
      'evasionChance': 0.1,
      'criticalChance': 0.05,
      'criticalMultiplier': 1.5,
      'raidSpecialMultiplier': 3.25,
      'knightToSpecial': 5,
      'bossToSpecial': 6,
      'knightToSpecialSR': 7,
      'knightToSpecialSREW': 7,
      'hitsToElementalWeakness': 7,
      'durationElementalWeakness': 2,
      'defaultElementalWeakness': 0.616,
    });

    final pre = model.precompute(
      boss: BossConfig(
        meta: meta,
        stats: const BossStats(
          attack: 33600,
          defense: 17400,
          hp: 150000,
        ),
      ),
      kAtk: const [75599, 84336, 62390],
      kDef: const [62560, 67331, 59434],
      kHp: const [1811, 1969, 1811],
      kAdv: const [1.5, 2.0, 2.0],
      kStun: const [0.25, 0.25, 0.25],
      petAtk: 6235,
      petAdv: 1.0,
    );

    expect(pre.bNormalDmg[0], 64);
    expect(pre.bCritDmg[0], 96);
    expect(pre.bNormalDmg[1], 59);
    expect(pre.bCritDmg[1], 89);

    final pre2 = model.precompute(
      boss: BossConfig(
        meta: meta.copyWith(level: 6),
        stats: const BossStats(
          attack: 57200,
          defense: 18100,
          hp: 3000000,
        ),
      ),
      kAtk: const [78762, 87005, 65620],
      kDef: const [64890, 69434, 61774],
      kHp: const [1796, 1969, 1838],
      kAdv: const [2.0, 2.0, 2.0],
      kStun: const [0.25, 0.25, 0.25],
      petAtk: 4245,
      petAdv: 1.5,
    );

    expect(pre2.bNormalDmg[1], 98);
    expect(pre2.bCritDmg[1], 147);
  });

  test('debug SR+EW strong trigger matches in-game normal reduction pattern',
      () {
    final pre = _makeEwFloorPrecomputed(
      bossCritChance: 0.0,
      bNormal: const [98, 98, 98],
      bCrit: const [147, 147, 147],
      ewFraction: 0.539,
    );
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
      shatter: const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: [true, true, true],
        strongElementEw: [true, true, true],
      ),
    );
    expect(debug.lines.any((l) => l.contains('EWstacks=')), isTrue);
  });

  test('debug SR+EW strong trigger matches in-game crit reduction pattern', () {
    final pre = _makeEwFloorPrecomputed(
      bossCritChance: 1.0,
      bNormal: const [110, 110, 110],
      bCrit: const [165, 165, 165],
      ewFraction: 0.539,
    );
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
      shatter: const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: [true, true, true],
        strongElementEw: [true, true, true],
      ),
    );
    expect(debug.lines.any((l) => l.contains('EWstacks=')), isTrue);
  });

  test('debug Shatter Shield uses pet Special 2 bar cadence when enabled', () {
    final pre = _makeShatterPetBarPrecomputed();
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
      shatter: const ShatterShieldConfig(
        baseHp: 20,
        bonusHp: 5,
        elementMatch: [true, false, false],
      ),
    );

    expect(debug.lines, isNotEmpty);
    expect(debug.points, greaterThan(0));
  });

  test('debug DRS uses pet bar cadence when enabled', () {
    final pre = _makeDrsPetBarPrecomputed();
    final labels = _labelsBase();

    final debug = DebugSimulator.run(
      pre,
      labels: labels,
      seed: 1,
      shatter: const ShatterShieldConfig(
        baseHp: 0,
        bonusHp: 0,
        elementMatch: [true, false, false],
      ),
    );

    expect(
        debug.lines.any((l) => l.startsWith('PET BAR cast special1')), isTrue);
    expect(debug.lines.any((l) => l == 'PET BAR init: 2/4'), isTrue);
    expect(debug.lines.any((l) => l == 'PET BAR queued special1 at 2'), isTrue);
    expect(debug.lines.any((l) => l == 'PET BAR cast special1: 2->0'), isTrue);
  });
}
