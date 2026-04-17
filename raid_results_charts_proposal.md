# Raid Results Charts Proposal

## Status Snapshot

Last updated: 2026-04-01

### Implemented

- P0 `Graph View` toggle added to Raid / Blitz Results
- P0 `Score Range Chart` added in `Performance Summary`
- P0 `Knight Outgoing Damage Chart` added in `Knights`
- P0 `Knight Incoming Pressure Chart` added in `Knights`
- P0 `Timing Breakdown Chart` added in `Fight duration data (Premium)`
- P0 `Bulk Frontier Chart` added in `Bulk Results Comparison`
- i18n keys added for chart titles, series labels and `Graph View` copy
- screenshot workflow documented in `docs/screenshots/README.md`
- Phase 2 `SimulationSeries` checkpoints added to `SimStats`
- Phase 2 first chart shipped: `Convergence` line in `Performance Summary`
- Phase 2 `Convergence Band v1` shipped using checkpoint min/max range
- Phase 2 `Histogram bins` added to the simulation output
- Phase 2 `Score Distribution` histogram added in `Performance Summary`
- Phase 2 `Target Probability` / exceedance chart added in `Performance Summary`
- Phase 2 percentile chips added under `Target Probability`
- Phase 2 interactive quick target selectors added above `Target Probability`
- UX polish pass started for compact/mobile chart density and label handling
- Bulk compare now includes histogram-derived `Bulk Target Chance` insight
- Bulk compare now includes `Bulk Score Range` and `Bulk Percentile Comparison`
- visual QA pass started:
  - grouped damage / chance bars now render left-aligned with a visible minimum width
  - convergence, histogram, and target probability now use distinct palettes instead of a single theme-tinted family
  - convergence now shows checkpoint score points plus explicit mean, median, min, max and min/max band guides for clearer reading
  - score distribution histogram now uses 3 percentile bands (`<40%`, `40%-60%`, `>60%`) instead of the earlier 5-band palette
  - knight outgoing and incoming charts now support a second histogram-style comparison view via toggle
  - knight outgoing and incoming bar charts now use a per-series zoomed scale so cross-knight differences are easier to notice
  - chart axis summaries now stack cleanly on narrow screens instead of compressing into a single row
  - quick target chips now use a denser mobile layout with short numeric formatting
- chart help tooltips added for each shipped chart card
- shared chart widgets extracted into `lib/ui/results_charts.dart`
- additive rollout confirmed:
  - charts do not replace the existing tables
  - Premium timing gating is preserved

### Still Missing From P0

- final visual QA pass on spacing and label balance across a wider device range

### Next Recommended Step

1. finish the visual QA pass on very narrow screens and tablets
2. evaluate whether Bulk should get percentile or target-threshold chips as well
3. decide whether to add export-safe chart summary fields to shared results payloads

### Recent additions

- `Wardrobe Simulate` report now supports export via copyable JSON payload

## Goal

Define a concrete proposal for introducing charts in the Raid / Blitz Results flow, grounded in the current codebase and designed to minimize regression risk.

This document focuses on:

- which charts are worth building first
- which data is already available today
- which new data should be captured for higher-value charts
- where the implementation should hook into the current app
- a phased rollout plan

## Current Data Surface

### Home Raid Inputs

The Home Raid flow already captures enough context to drive multiple chart families.

Main sources:

- `lib/data/setup_models.dart`
- `lib/ui/home_page.dart`
- `lib/data/config_models.dart`

Available input dimensions:

- boss mode and boss level
- boss elements
- fight mode
  - `normal`
  - `specialRegen`
  - `specialRegenPlusEw`
  - `specialRegenEw`
  - `shatterShield`
  - `cycloneBoost`
  - `durableRockShield`
- 3 knight slots with:
  - `ATK`
  - `DEF`
  - `HP`
  - `stun`
  - 2 elements
  - active/inactive state
- pet with:
  - `ATK`
  - `elementalAtk`
  - `elementalDef`
  - up to 2 elements
  - skill usage mode
  - selected/imported skills
  - resolved effects
- mode effects with:
  - `cycloneUseGemsForSpecials`
  - `cycloneBoostPercent`
  - `shatterBaseHp`
  - `shatterBonusHp`
  - `drsDefenseBoost`
  - `ewWeaknessEffect`
- run configuration:
  - total runs
  - milestone target points
  - starting energies
  - free raid energies
- optional elixir inventory

### Current Results Outputs

Main sources:

- `lib/core/battle_outcome.dart`
- `lib/core/damage_model.dart`
- `lib/core/timing_acc.dart`
- `lib/ui/results_page.dart`
- `lib/data/bulk_results_models.dart`
- `lib/data/share_payloads.dart`

Already available output metrics:

- score summary:
  - `mean`
  - `median`
  - `min`
  - `max`
- expected range derived from mean
- full timing aggregate:
  - mean run seconds
  - mean boss seconds
  - mean survival seconds per knight
  - mean own-action seconds per knight
  - per-knight action counts and seconds for:
    - normal
    - special
    - stun
    - miss
  - boss action counts and seconds per target knight for:
    - normal
    - special
    - miss
- precomputed combat values:
  - knight normal/crit/special damage to boss
  - boss normal/crit damage to each knight
  - pet normal/crit damage
- mode-specific recap values for:
  - SR
  - EW
  - DRS
  - Shatter
  - Cyclone
  - Old Simulator
- energy and gem planning:
  - runs needed
  - free energy
  - extra energy
  - packs
  - gems
  - leftover energy
- bulk comparison metrics:
  - mean points
  - mean run seconds
  - points per second

### Important Limitation Today

The engine currently computes and keeps per-run values internally during simulation, but only exposes aggregate stats.

In `lib/core/damage_model.dart`:

- each run score is stored in an `Int32List values`
- that list is used to compute median
- then it is discarded

This means:

- we can already build many good charts from aggregates
- we cannot yet build proper distribution or convergence charts without adding a new output structure

## Chart Catalogue

This section is the recommended chart catalogue, grouped by implementation priority.

### P0 - High Value, Low Risk

These charts use data that already exists and can be introduced without changing simulation semantics.

#### 1. Score Range Chart

Type:

- lollipop chart or compact bar cluster

Data:

- `min`
- `median`
- `mean`
- `max`

Why:

- immediate readability
- turns the current summary table into something much easier to scan
- almost zero product risk

Suggested placement:

- top of `Performance Summary`

Implementation cost:

- low

#### 2. Knight Outgoing Damage Chart

Type:

- grouped bars by knight

Series:

- normal
- crit
- special

Data source:

- `pre.kNormalDmg`
- `pre.kCritDmg`
- `pre.kSpecialDmg`

Why:

- gives instant understanding of role distribution across K1/K2/K3
- highlights whether a setup is balanced or over-dependent on one knight

Suggested placement:

- inside or right after the `Knights` section

Implementation cost:

- low

#### 3. Knight Incoming Pressure Chart

Type:

- grouped bars by knight

Series:

- boss normal
- boss crit

Data source:

- `pre.bNormalDmg`
- `pre.bCritDmg`

Why:

- visually explains survivability pressure
- pairs naturally with outgoing damage

Suggested placement:

- same visual block as outgoing damage

Implementation cost:

- low

#### 4. Timing Breakdown Chart

Type:

- stacked bars per knight

Series:

- normal seconds
- special seconds
- stun seconds
- miss seconds

Optional second view:

- action counts instead of seconds

Data source:

- `TimingStats`

Why:

- one of the strongest data assets already in the app
- converts a dense table into something much more digestible

Suggested placement:

- `Fight duration data (Premium)`

Implementation cost:

- low to medium

#### 5. Bulk Frontier Chart

Type:

- scatter plot

Axes:

- X = mean points
- Y = points per second

Optional encoding:

- bubble size = mean run seconds

Data source:

- `BulkSimulationRunResult`
- `BulkSimulationBatchResult`

Why:

- very strong for setup comparison
- makes bulk results feel meaningfully more advanced

Suggested placement:

- top of `Bulk Results Comparison`

Implementation cost:

- medium

### P1 - High Value, Requires New Simulation Series Data

These are the charts that justify extending the engine output.

#### 6. Convergence Line

Type:

- line chart

Series:

- cumulative mean score over checkpoints

Example checkpoints:

- every 500 runs
- every 1000 runs

Why:

- directly answers "have I simulated enough?"
- ideal for Premium and power users
- matches the exact idea proposed in brainstorming

Suggested placement:

- new `Stability` or `Convergence` panel in Results

Implementation cost:

- medium

#### 7. Convergence Band

Type:

- line with band

Series:

- cumulative mean
- optional lower/upper band

Recommended band options:

- cumulative min / max so far
- rolling interquartile approximation
- rolling stddev band

Why:

- makes stability visible instead of only a single line

Implementation cost:

- medium to high

#### 8. Score Distribution Histogram

Type:

- histogram

Data:

- binned run scores

Why:

- best chart for understanding outcome shape
- shows variance, skew, outliers, floor/ceiling behavior

Implementation cost:

- medium

#### 9. Target Probability Curve

Type:

- exceedance / survival curve

Axes:

- X = target score
- Y = probability of reaching or exceeding target

Why:

- extremely useful for milestone planning
- more actionable than min/mean/max

Implementation cost:

- medium to high

#### 10. Stability Heatmap

Type:

- heatmap or segmented progress strip

Data:

- delta in cumulative mean per checkpoint

Why:

- compact visualization of convergence quality
- ideal for showing whether 10k, 50k, 100k runs materially changed the estimate

Implementation cost:

- medium

### P2 - More Experimental / Out Of The Box

These are differentiated charts that can give the app a stronger identity.

#### 11. Build Fingerprint Radar

Axes:

- K1 outgoing
- K2 outgoing
- K3 outgoing
- pet damage
- incoming pressure
- survival

Why:

- visually striking
- makes each build feel unique

Risk:

- radar charts are easy to make noisy if overused

Implementation cost:

- medium

#### 12. Mode Signature Card

Type:

- mini timeline / state diagram

Purpose:

- visualize mode logic for SR / EW / DRS / Shatter / Cyclone

Why:

- reduces cognitive load for advanced users
- especially useful in the `Pet & Mode` section

Implementation cost:

- medium

#### 13. Milestone Cost Curve

Type:

- line chart

Axes:

- X = target score
- Y = gems needed

Why:

- better than showing only one target milestone
- lets users reason about "what if I push a bit more"

Implementation cost:

- medium

#### 14. Elixir Marginal Value Chart

Type:

- waterfall or delta bars

Series:

- each elixir's added score
- each elixir's estimated gem savings

Why:

- turns elixir planning into a real decision tool

Implementation cost:

- medium to high

## Recommended New Data Model

To unlock P1 charts cleanly, introduce a new result companion object instead of bloating `SimStats`.

Suggested type:

```dart
class SimulationSeries {
  final int checkpointEvery;
  final List<SimulationCheckpoint> checkpoints;
  final List<HistogramBin> histogram;
  final int sampleCount;
}

class SimulationCheckpoint {
  final int runIndex;
  final int cumulativeMean;
  final int cumulativeMin;
  final int cumulativeMax;
}

class HistogramBin {
  final int lowerInclusive;
  final int upperExclusive;
  final int count;
}
```

### Why this shape

- `checkpoints` unlock convergence charts
- `histogram` unlocks distribution and probability charts
- avoids storing every raw run
- easier to export/share than a giant run list
- much lower memory and payload cost than preserving all per-run values

### What not to do first

Avoid this as the first implementation:

- storing every raw score for every run in `ResultsSharePayload`
- exposing gigantic arrays in setup/result export
- adding chart-specific ad hoc fields directly inside `ResultsPage`

## Engine Capture Strategy

### Recommended v1

During simulation, while iterating over `values` in `DamageModel.simulate()`:

- keep the existing aggregate stats
- every `N` runs, append a checkpoint summary
- build a histogram incrementally

Recommended defaults:

- checkpoint interval:
  - 500 for runs <= 20k
  - 1000 for larger runs
- histogram bins:
  - 24 to 40 bins
  - computed after min/max are known, or updated with an adaptive binning strategy

### Simpler rollout option

If we want to minimize engine complexity for phase 1:

- add checkpoints first
- postpone histogram to phase 2

This would already enable the most valuable new chart: convergence.

## Implementation Hooks

### Engine / Data Layer

Primary files:

- `lib/core/damage_model.dart`
- `lib/core/battle_outcome.dart`
- `lib/data/share_payloads.dart`
- `lib/data/bulk_results_models.dart`

Expected work:

- add a `SimulationSeries?` to the result payload stack
- compute checkpoints during simulation
- optionally compute histogram bins
- decide whether bulk results should also retain `SimulationSeries`

### UI Layer

Primary files:

- `lib/ui/results_page.dart`
- `lib/ui/bulk_results_page.dart`

Suggested structure:

- keep existing tables/cards
- add a new `Charts` block under `Performance Summary`
- for Premium-only charts, follow the same gating style already used by timing tables

### Shared UI Components

Suggested new files:

- `lib/ui/results_charts.dart`
- `lib/ui/chart_widgets.dart`

Suggested widget split:

- `ScoreRangeChart`
- `KnightDamageChart`
- `TimingBreakdownChart`
- `BulkFrontierChart`
- `ConvergenceChart`
- `ScoreDistributionChart`

## Proposed Rollout

### Phase 1

Ship charts using only current aggregates.

Scope:

- Score Range Chart
- Knight Outgoing Damage Chart
- Knight Incoming Pressure Chart
- Timing Breakdown Chart
- Bulk Frontier Chart

Current status:

- implemented:
  - Score Range Chart
  - Knight Outgoing Damage Chart
  - Knight Incoming Pressure Chart
  - Timing Breakdown Chart
  - Bulk Frontier Chart
- pending:
  - none for the planned P0 chart set

Benefits:

- no engine semantic change
- fastest path to visible value
- safest for regression control

### Phase 2

Add `SimulationSeries` with checkpoints.

Scope:

- Convergence Line
- Convergence Band v1

Current status:

- implemented:
  - `SimulationSeries` with checkpoint snapshots
  - `Convergence Line`
  - `Convergence Band v1`
- pending:
  - histogram-backed charts

Benefits:

- directly supports the "every 500 / 1000 runs" idea
- low storage overhead

### Phase 3

Add histogram bins and more advanced planning visuals.

Scope:

- Score Distribution Histogram
- Target Probability Curve
- Milestone Cost Curve
- Elixir Marginal Value Chart

## Recommended First Implementation Set

If we want the best ratio between usefulness, polish, and implementation risk, the recommended first set is:

1. Score Range Chart
2. Knight Outgoing / Incoming dual chart block
3. Timing Breakdown Chart
4. Bulk Frontier Chart
5. Simulation checkpoints in engine

This combination gives:

- immediate UX improvement
- stronger value for Premium timing
- a real path toward more advanced charts
- minimal risk of disturbing the simulation core

## Open Decisions

Before implementation, we should decide:

1. whether charts are always visible or partly Premium-gated
2. whether `SimulationSeries` should be included in shared/exported results
3. whether histogram support ships together with checkpoints or later
4. whether we want one chart tab or inline cards inside Results

Current decision snapshot:

- `Graph View` toggle has been introduced as an additive inline mode
- existing detailed tables remain the source of truth
- Premium gating is currently preserved only where it already existed (`timing`)

## Final Recommendation

Build charts in two steps, not one:

- first, use existing aggregate data to ship obvious visual wins
- second, add checkpoint-based simulation series for convergence and distribution

This keeps the first release safe and useful, while leaving room for much stronger visual analytics without forcing a large engine refactor up front.
