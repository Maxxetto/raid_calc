# Simulation Calibrator Plan

## Goal

Build an offline calibrator for the raid/blitz simulator that tunes a small set
of global simulation parameters against real observed raw scores collected from
manual runs.

This is **not** a model fine-tuning system. It is a constrained calibration
tool for a handful of simulator knobs.

Initial target knobs:

- Pet bar fill parameters from `assets/pet_bar_rules.json`
- Optional `cycleMultiplier` from `assets/sim_rules.json`

Deferred until later:

- Knight special meter fill parameters
- Timing durations
- Damage multipliers unrelated to cadence

## Why Start Small

The simulator score is strongly affected by action cadence. Both the pet bar and
the knight special meter influence cadence. If both families of parameters are
optimized at the same time too early, the fit can become hard to interpret: the
optimizer may compensate an error in one subsystem by distorting the other.

Recommended rollout:

1. Calibrate only pet bar knobs.
2. Optionally add `cycleMultiplier`.
3. Only later consider knight special meter knobs.

## Dataset Format

The calibrator should accept a single JSON file grouped by boss type and level.
Boss stats are not duplicated in the dataset because they already live in
`assets/boss_tables.json`.

Recommended schema:

```json
{
  "version": 1,
  "notes": "Optional free-form notes",
  "datasets": {
    "raid": {
      "4": [
        {
          "setupId": "raid4_case_001",
          "collectedAt": "2026-03-23",
          "bossElements": ["water", "fire"],
          "setup": {
            "knights": [
              {
                "atk": 75295,
                "def": 63016,
                "hp": 1827,
                "stun": 0.25,
                "elements": ["air", "water"]
              },
              {
                "atk": 71553,
                "def": 57243,
                "hp": 1817,
                "stun": 0.25,
                "elements": ["air", "air"]
              },
              {
                "atk": 66816,
                "def": 55692,
                "hp": 1973,
                "stun": 0.25,
                "elements": ["water", "water"]
              }
            ],
            "pet": {
              "atk": 4245,
              "elements": ["air"],
              "skillUsage": "doubleSpecial2ThenSpecial1",
              "cycloneAlwaysGem": false,
              "effects": [
                {
                  "canonicalEffectId": "elemental_weakness",
                  "slot": 1,
                  "values": {
                    "enemyAttackReductionPercent": 53.9,
                    "turns": 2
                  }
                },
                {
                  "canonicalEffectId": "special_regeneration_infinite",
                  "slot": 2,
                  "values": {
                    "meterChargePercent": 87
                  }
                }
              ]
            }
          },
          "observedScores": [412345, 398210, 427801]
        }
      ],
      "7": []
    },
    "blitz": {
      "6": []
    }
  }
}
```

## Dataset Rules

- `observedScores` must contain **raw final battle scores**
- Scores must come from the same scoring definition as the simulator output
- Each case should contain the full setup needed to reconstruct `Precomputed`
- Each case must also contain `bossElements`, because `boss_tables.json` only
  provides boss stats, not boss elements
- Grouping by `raid/blitz/level` is only for readability; the calibrator should
  flatten all cases internally
- The same dataset file may contain `Raid L4`, `Raid L7`, `Blitz L6`, etc.

## What To Optimize First

### Pet bar candidate knobs

From `assets/pet_bar_rules.json`:

- `ticksPerState`
- `startTicks`
- `petCritPlusOneProb`
- `bossNormal`
- `bossSpecial`
- `bossMiss`
- `stun`
- `petKnightBase`

### Strongly recommended first subset

For the first usable version, keep the search space intentionally small:

- `ticksPerState`
- `bossNormal`
- `bossSpecial`
- `bossMiss`
- `stun`
- `petKnightBase`
- optional `cycleMultiplier`

Recommended simplification for the first pass:

- assume every distribution remains single-point, weight `1.0`
- only optimize the `ticks` value of each event family

That means the first calibrator can search around ~6 or 7 scalar parameters,
not dozens.

## Comparison Target

Each setup contributes a **distribution** of observed raw scores, not only one
summary number.

The calibrator should compare:

- observed mean vs simulated mean
- observed median vs simulated median
- observed `p10` vs simulated `p10`
- observed `p90` vs simulated `p90`

This is a better first objective than trying to match the full empirical
distribution directly.

## Recommended Loss Function

Use normalized error so mixed contexts do not get dominated by the highest-score
bosses.

Per case:

```text
meanErr   = abs(simMean   - obsMean)   / max(obsMean, 1)
medianErr = abs(simMedian - obsMedian) / max(obsMedian, 1)
p10Err    = abs(simP10    - obsP10)    / max(obsP10, 1)
p90Err    = abs(simP90    - obsP90)    / max(obsP90, 1)
caseLoss  = 0.40 * meanErr
          + 0.30 * medianErr
          + 0.15 * p10Err
          + 0.15 * p90Err
```

Global loss:

- average all case losses equally
- optionally add a mild regularization penalty if parameters drift too far from
  current defaults

## Why Mixed Raid/Blitz Levels Are Valid

Mixed contexts are acceptable if:

- every case is normalized by its own observed scale
- the same parameter set is evaluated across all cases

This is useful because it prevents overfitting to only one boss level.

Suggested rollout:

1. Start with `Raid L4` only to validate the pipeline.
2. Add `Raid L7`.
3. Add `Blitz L6`.
4. Re-check whether one global parameter set still behaves well.

If later the fit shows systematic drift by context, then consider scoped knobs
by boss type, but not in v1.

## Determinism During Calibration

The simulator is Monte Carlo, so optimization can become noisy if every
evaluation uses unrelated randomness.

Rules for the calibrator:

- use fixed seeds during optimization
- use the same seed schedule for every parameter candidate
- use a moderate simulation run count during search
- run a larger validation pass only for the best candidate sets

Example:

- optimization pass: 100 runs per case using seeds `1001..1100`
- validation pass: 1000 runs per case using seeds `5001..6000`

This keeps the objective stable enough for optimization.

## Implementation Shape In This Repo

The calibrator should be an **offline tool**, not part of the runtime app flow.

Recommended structure:

- `tool/calibration/calibration_dataset.dart`
- `tool/calibration/calibration_case.dart`
- `tool/calibration/calibration_metrics.dart`
- `tool/calibration/calibration_knobs.dart`
- `tool/calibration/calibration_runner.dart`
- `tool/calibration/calibration_search.dart`
- `tool/calibrate_sim.dart`

## Important Loader Constraint

Current app loaders like:

- `lib/data/pet_bar_rules_loader.dart`
- `lib/data/sim_rules_loader.dart`

use `rootBundle`, which is convenient for the app but not ideal for a pure
offline tool. The calibrator should instead read:

- `assets/pet_bar_rules.json`
- `assets/sim_rules.json`
- `assets/boss_tables.json`

directly from the filesystem using `dart:io`, then map them into the same model
structures used by the simulator.

## How The Tool Should Run

Preferred command style:

```bash
flutter pub run tool/calibrate_sim.dart --dataset tool/calibration/data/sample.json
```

Why `flutter pub run` instead of plain `dart run`:

- this repo already depends on Flutter packages
- several existing model files import Flutter foundation types

## Search Strategy

Start simple.

### V1 search

- bounded coordinate search or hill climbing
- integer search for fill tick values
- small bounded float search for `cycleMultiplier`

This is enough for the first calibrator and easier to reason about than generic
black-box optimizers.

### V2 search

If needed later:

- random restart hill climbing
- simulated annealing
- CMA-ES style search

None of that is required for the first useful version.

## Outputs

The calibrator should emit:

- best parameter set found
- old loss vs new loss
- per-case error table
- summary grouped by `raid/blitz/level`
- a ready-to-paste JSON patch block for the tuned knobs

Example useful output:

- old `ticksPerState`: `165`
- new `ticksPerState`: `158`
- old `bossSpecial`: `4`
- new `bossSpecial`: `5`
- old `cycleMultiplier`: `1.385844`
- new `cycleMultiplier`: `1.362100`

## Validation And Regression

The calibrator should support two dataset splits:

- training cases
- validation cases

Split policy:

- split by **setup**, not by individual score
- never put scores from the same setup in both training and validation

This avoids leakage because repeated runs of the same setup are highly related.

## Proposed First Milestone

1. Add dataset schema and parser.
2. Add a flattener from grouped JSON to calibration cases.
3. Add case summary stats computation.
4. Add a runner that evaluates one candidate parameter set.
5. Add a simple local search over pet bar tick fills.
6. Print comparison report and best knob set.

## Non-Goals For V1

- in-app UI for calibration
- auto-writing tuned values into assets
- simultaneous fitting of every simulator constant
- per-pet or per-skill bespoke fitted parameters
- direct optimization against debug logs

## Summary

This calibrator should be:

- offline
- small-scope
- deterministic during search
- distribution-aware
- based on real raw-score datasets

The best first version is a constrained optimizer for pet bar fill knobs,
optionally plus `cycleMultiplier`, evaluated on mixed raid/blitz cases with
normalized per-case loss.
