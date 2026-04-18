import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/util/war_calc.dart';

void main() {
  const set = WarPointsSet(
    base: 100,
    frenzy: 150,
    powerAttack: 220,
    frenzyPowerAttack: 300,
  );

  test('pointsPerAttack selects correct variant', () {
    expect(pointsPerAttack(set: set, frenzy: false, powerAttack: false), 100);
    expect(pointsPerAttack(set: set, frenzy: true, powerAttack: false), 150);
    expect(pointsPerAttack(set: set, frenzy: false, powerAttack: true), 220);
    expect(pointsPerAttack(set: set, frenzy: true, powerAttack: true), 300);
  });

  test('boostedWarPoints uses the same round rule as war optimizer', () {
    expect(boostedWarPoints(basePoints: 760, scoreMultiplier: 0.40), 1064);
    expect(boostedWarPoints(basePoints: 2712, scoreMultiplier: 0.66), 4502);
  });

  test('computeWarPlan uses minimal packs for energy', () {
    final plan = computeWarPlan(
      milestonePoints: 1000,
      pointsPerAttackValue: 200,
      pointsPerPowerAttackValue: 0,
      availableEnergy: 0,
    );
    // 1000 / 200 = 5 attacks, energy 5.
    expect(plan.attacks, 5);
    expect(plan.normalAttacks, 5);
    expect(plan.powerAttacks, 0);
    expect(plan.gems.energyNeeded, 5);
    // Min packs for 5 energy -> buy 8 energy (2x4) = 20 gems.
    expect(plan.gems.gems, 20);
    expect(plan.gems.energyBought, 8);
  });

  test('computeWarPlan prefers PA when more efficient', () {
    final plan = computeWarPlan(
      milestonePoints: 1000,
      pointsPerAttackValue: 200,
      pointsPerPowerAttackValue: 1000,
      availableEnergy: 0,
    );
    // One PA attack covers the milestone (energy 4).
    expect(plan.attacks, 1);
    expect(plan.normalAttacks, 0);
    expect(plan.powerAttacks, 1);
    expect(plan.gems.energyNeeded, 4);
    // Best is one 4-energy pack (10 gems).
    expect(plan.gems.gems, 10);
    expect(plan.gems.energyBought, 4);
  });

  test('computeWarPlan subtracts available energy', () {
    final plan = computeWarPlan(
      milestonePoints: 1000,
      pointsPerAttackValue: 200,
      pointsPerPowerAttackValue: 0,
      availableEnergy: 5,
    );
    // 5 attacks -> energy 5, available 5 -> need 0.
    expect(plan.gems.energyNeeded, 0);
    expect(plan.gems.gems, 0);
  });

  test('WarPlan serializes and restores', () {
    const plan = WarPlan(
      pointsPerAttack: 780,
      pointsPerPowerAttack: 2286,
      normalAttacks: 3,
      powerAttacks: 2,
      gems: WarGemPlan(
        energyNeeded: 11,
        energyBought: 12,
        gems: 30,
        packs4: 3,
        packs20: 0,
        packs40: 0,
        leftover: 1,
      ),
    );

    final copy = WarPlan.fromJson(plan.toJson());
    expect(copy.pointsPerAttack, 780);
    expect(copy.pointsPerPowerAttack, 2286);
    expect(copy.normalAttacks, 3);
    expect(copy.powerAttacks, 2);
    expect(copy.gems.energyNeeded, 11);
    expect(copy.gems.energyBought, 12);
    expect(copy.gems.gems, 30);
    expect(copy.gems.packs4, 3);
    expect(copy.gems.leftover, 1);
  });

  test('computeWarPlan emits progress for mixed search', () {
    int calls = 0;
    int lastDone = -1;
    int lastTotal = -1;

    final _ = computeWarPlan(
      milestonePoints: 50000,
      pointsPerAttackValue: 780,
      pointsPerPowerAttackValue: 1905,
      availableEnergy: 0,
      onProgress: (done, total) {
        calls++;
        lastDone = done;
        lastTotal = total;
      },
    );

    expect(calls, greaterThan(0));
    expect(lastTotal, greaterThan(0));
    expect(lastDone, lastTotal);
  });

  test('computeWarPlan can return mixed normal+PA when energy is tied', () {
    final plan = computeWarPlan(
      milestonePoints: 1000,
      pointsPerAttackValue: 200,
      pointsPerPowerAttackValue: 900,
      availableEnergy: 0,
    );

    // 1 PA + 1 normal = 1100 points, 5 energy (same energy as 5 normals),
    // with fewer attacks.
    expect(plan.totalEnergy, 5);
    expect(plan.normalAttacks, 1);
    expect(plan.powerAttacks, 1);
  });

  test('computeWarPlan prefers lower energy over fewer attacks', () {
    final plan = computeWarPlan(
      milestonePoints: 900,
      pointsPerAttackValue: 200,
      pointsPerPowerAttackValue: 450,
      availableEnergy: 0,
    );

    // 2 PA => 8 energy (2 attacks), 5 normals => 5 energy (5 attacks).
    // Same gem bucket (20), so lower energy must win.
    expect(plan.gems.gems, 20);
    expect(plan.totalEnergy, 5);
    expect(plan.normalAttacks, 5);
    expect(plan.powerAttacks, 0);
  });

  test('EU base with PA enabled does not force unnecessary PA', () {
    final plan = computeWarPlan(
      milestonePoints: 1000000,
      pointsPerAttackValue: 780,
      pointsPerPowerAttackValue: 1905,
      availableEnergy: 0,
    );

    // With current points, normal attacks are more energy-efficient.
    expect(plan.normalAttacks, 1283);
    expect(plan.powerAttacks, 0);
    expect(plan.totalEnergy, 1283);
  });

  test('computeWarPlan can force only PAs for non-optimal plans', () {
    final plan = computeWarPlan(
      milestonePoints: 1000,
      pointsPerAttackValue: 200,
      pointsPerPowerAttackValue: 450,
      availableEnergy: 0,
      strategy: WarAttackStrategy.powerAttackOnly,
    );

    expect(plan.normalAttacks, 0);
    expect(plan.powerAttacks, 3);
    expect(plan.totalEnergy, 12);
  });

  test('computeWarPlan can force a fixed number of PAs and fill the rest with normals', () {
    final plan = computeWarPlan(
      milestonePoints: 1000,
      pointsPerAttackValue: 200,
      pointsPerPowerAttackValue: 450,
      availableEnergy: 0,
      strategy: WarAttackStrategy.fixedPowerAttacks,
      forcedPowerAttacks: 1,
    );

    expect(plan.powerAttacks, 1);
    expect(plan.normalAttacks, 3);
    expect(plan.totalEnergy, 7);
  });

  test('war elixir bonus uses round and applies to attack coverage', () {
    final plan = computeWarPlan(
      milestonePoints: 1003,
      pointsPerAttackValue: 912,
      pointsPerPowerAttackValue: 0,
      availableEnergy: 0,
      elixirs: const <ElixirInventoryItem>[
        ElixirInventoryItem(
          name: 'Test',
          gamemode: 'War',
          scoreMultiplier: 0.10,
          durationMinutes: 1,
          quantity: 1,
        ),
      ],
    );

    expect(plan.normalAttacks, 1);
    expect(plan.powerAttacks, 0);
    expect(plan.boostSummary.boostedNormalAttacks, 1);
    expect(plan.boostSummary.unboostedNormalAttacks, 0);
    expect(plan.elixirUsages, hasLength(1));
    expect(plan.elixirUsages.first.usedAttacks, 1);
    expect(plan.elixirUsages.first.boostedNormalAttacks, 1);
    expect(plan.elixirUsages.first.boostedPowerAttacks, 0);
  });

  test('war elixir allocation prefers normal before PA when PA is not better per 4 energy', () {
    final plan = computeWarPlan(
      milestonePoints: 1900,
      pointsPerAttackValue: 400,
      pointsPerPowerAttackValue: 1500,
      availableEnergy: 0,
      elixirs: const <ElixirInventoryItem>[
        ElixirInventoryItem(
          name: 'Test',
          gamemode: 'War',
          scoreMultiplier: 0.10,
          durationMinutes: 1,
          quantity: 1,
        ),
      ],
    );

    expect(plan.normalAttacks, 1);
    expect(plan.powerAttacks, 1);
    expect(plan.boostSummary.boostedNormalAttacks, 1);
    expect(plan.boostSummary.boostedPowerAttacks, 0);
  });

  test('war elixir usage follows inventory order and spills to PA when normals are exhausted', () {
    final plan = computeWarPlan(
      milestonePoints: 2300,
      pointsPerAttackValue: 400,
      pointsPerPowerAttackValue: 1500,
      availableEnergy: 0,
      elixirs: const <ElixirInventoryItem>[
        ElixirInventoryItem(
          name: 'First',
          gamemode: 'War',
          scoreMultiplier: 0.10,
          durationMinutes: 1,
          quantity: 1,
        ),
        ElixirInventoryItem(
          name: 'Second',
          gamemode: 'War',
          scoreMultiplier: 0.50,
          durationMinutes: 1,
          quantity: 1,
        ),
      ],
    );

    expect(plan.normalAttacks, 1);
    expect(plan.powerAttacks, 1);
    expect(plan.elixirUsages, hasLength(2));
    expect(plan.elixirUsages[0].name, 'First');
    expect(plan.elixirUsages[0].boostedNormalAttacks, 1);
    expect(plan.elixirUsages[0].boostedPowerAttacks, 0);
    expect(plan.elixirUsages[1].name, 'Second');
    expect(plan.elixirUsages[1].boostedNormalAttacks, 0);
    expect(plan.elixirUsages[1].boostedPowerAttacks, 1);
  });
}
