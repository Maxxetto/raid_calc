import 'package:flutter_test/flutter_test.dart';

import 'package:raid_calc/data/config_models.dart';
import 'package:raid_calc/util/elixir_calc.dart';

void main() {
  test('runsPerElixir rounds up generous coverage', () {
    final runs = runsPerElixir(durationMinutes: 9, meanRunSeconds: 120);
    expect(runs, 5);
  });

  test('runsPerElixir returns 0 for invalid inputs', () {
    expect(runsPerElixir(durationMinutes: 0, meanRunSeconds: 120), 0);
    expect(runsPerElixir(durationMinutes: 10, meanRunSeconds: 0), 0);
  });

  test('runsNeededWithElixirs applies elixir segment first', () {
    final elixirs = [
      const ElixirInventoryItem(
        name: 'Test',
        gamemode: 'Raid',
        scoreMultiplier: 0.1,
        durationMinutes: 10,
        quantity: 1,
      ),
    ];
    final runs = runsNeededWithElixirs(
      basePerRun: 100,
      targetPoints: 300,
      meanRunSeconds: 120,
      elixirs: elixirs,
    );
    expect(runs, 3);
  });

  test('runsNeededWithElixirs falls back to base after elixirs', () {
    final elixirs = [
      const ElixirInventoryItem(
        name: 'Test',
        gamemode: 'Raid',
        scoreMultiplier: 0.1,
        durationMinutes: 10,
        quantity: 1,
      ),
    ];
    final runs = runsNeededWithElixirs(
      basePerRun: 100,
      targetPoints: 1000,
      meanRunSeconds: 120,
      elixirs: elixirs,
    );
    expect(runs, 10);
  });

  test('runsNeededWithElixirs respects order and quantities', () {
    final elixirs = [
      const ElixirInventoryItem(
        name: 'A',
        gamemode: 'Raid',
        scoreMultiplier: 0.5,
        durationMinutes: 5,
        quantity: 1,
      ),
      const ElixirInventoryItem(
        name: 'B',
        gamemode: 'Raid',
        scoreMultiplier: 0.2,
        durationMinutes: 5,
        quantity: 1,
      ),
    ];
    final runs = runsNeededWithElixirs(
      basePerRun: 100,
      targetPoints: 1000,
      meanRunSeconds: 120,
      elixirs: elixirs,
    );
    // 5 min @120s => 3 runs.
    // A: 3 runs * 150 = 450
    // B: 3 runs * 120 = 360 (total 810)
    // Base: 190 -> 2 runs => 8 total
    expect(runs, 8);
  });

  test('runsNeededWithElixirs handles user example with partial last run', () {
    final elixirs = [
      const ElixirInventoryItem(
        name: 'Uncommon',
        gamemode: 'Raid',
        scoreMultiplier: 0.1,
        durationMinutes: 11,
        quantity: 1,
      ),
    ];
    final runs = runsNeededWithElixirs(
      basePerRun: 5000000,
      targetPoints: 11000000,
      meanRunSeconds: 180, // 3m -> 11m gives ceil(3.66)=4 covered runs
      elixirs: elixirs,
    );
    // 2 runs with +10% already reach the target (11M)
    expect(runs, 2);
  });

  test('runsNeededWithElixirs ignores invalid elixirs (no bonus / no duration)',
      () {
    final elixirs = [
      const ElixirInventoryItem(
        name: 'Invalid no bonus',
        gamemode: 'Raid',
        scoreMultiplier: 0.0,
        durationMinutes: 10,
        quantity: 1,
      ),
      const ElixirInventoryItem(
        name: 'Invalid no duration',
        gamemode: 'Raid',
        scoreMultiplier: 0.2,
        durationMinutes: 0,
        quantity: 1,
      ),
    ];
    final runs = runsNeededWithElixirs(
      basePerRun: 100,
      targetPoints: 1000,
      meanRunSeconds: 120,
      elixirs: elixirs,
    );
    // Falls back entirely to base runs.
    expect(runs, 10);
  });
}
