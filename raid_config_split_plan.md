# Raid Config Split Plan

## Phase 1: Current-State Mapping

This document maps the current `assets/raidComplete_data.json` monolith,
the public loader API built on top of it, and the proposed split target.

The goal is to separate the file by domain without breaking runtime behavior,
tests, exports, or existing model contracts.

## 1. Why Split

`assets/raidComplete_data.json` currently mixes multiple domains:

- shared simulation rules
- pet bar rules
- boss stat tables
- OCR import defaults
- elixir catalog
- war points rules

This creates three maintenance problems:

1. `ConfigLoader` reads one large root object and exposes unrelated concerns.
2. `BossMeta.fromJson` currently depends on a "mega-root" shape.
3. It is difficult to search for ownership and safely change one domain without
   accidentally touching another.

## 2. Current Top-Level Map

Current top-level keys in `assets/raidComplete_data.json`:

### A. Shared simulation rules

- `cycleMultiplier`
- `thresholdEpicBoss`
- `raidFreeEnergies`
- `epicBossDamageBonus`
- `evasionChance`
- `criticalChance`
- `criticalMultiplier`
- `raidSpecialMultiplier`
- `knightToSpecial`
- `bossToSpecial`
- `knightToSpecialSR`
- `knightToRecastSpecialSR`
- `knightToSpecialSREW`
- `knightToRecastSpecialSREW`
- `hitsToElementalWeakness`
- `defaultElementalWeakness`
- `durationElementalWeakness`
- `bossToSpecialFakeEW`
- `hitsToFirstShatter`
- `hitsToNextShatter`
- `cyclone`
- `cycloneBarion`
- `hitsToDRS`
- `durationDRS`
- `defaultDurableRockShield`
- `sameElementDRS`
- `strongElementEW`

### B. Pet bar rules

- `petTicksBar`

Notes:

- `petTicksBar` currently contains active fields and legacy comparison fields:
  - active: `enabled`, `ticksPerState`, `startTicks`,
    `petCritPlusOneProb`, `bossNormal`, `bossSpecial`, `bossMiss`, `stun`,
    `petKnightBase`, `modes`, `requireFirstKnightMatchForSrModes`
  - legacy-looking / candidate for removal after validation:
    `bossNormalORGINAL`, `bossSpecialORIGINAL`, `petKnightORIGINAL`

### C. OCR defaults

- `defaultOcrCropLeft`
- `defaultOcrCropRight`
- `defaultOcrCropTop`
- `defaultOcrCropBottom`

### D. Timing config

- `normalDuration`
- `specialDuration`
- `stunDuration`
- `missDuration`
- `bossDuration`
- `bossSpecial`

Notes:

- These are parsed through `TimingConfig.fromJson(...)` from the root object.
- `bossSpecial` is legacy naming; internally the app uses
  `bossSpecialDuration`.

### E. Boss tables

- `tables.Raid`
- `tables.Blitz`
- `tables.Epic`

### F. Elixir catalog

- `elixirs`

### G. War points config

- `War`

### H. Candidate unused / stale root block

- `boss`

Current code search did not reveal runtime reads of `root['boss']`.
It appears to be stale data and should be validated during migration.

## 3. Public Loader API and Ownership

Current file: `lib/data/config_loader.dart`

### Reads shared simulation rules / composed boss config

- `loadBoss(...)`
  - uses root simulation rules + `tables.Raid/Blitz`
  - builds `metaJson` by cloning the full root
  - builds `BossMeta.fromJson(metaJson)`
  - used in:
    - `lib/ui/home_page.dart:2496`
    - `lib/ui/home_page.dart:3217`
    - `lib/ui/home_page.dart:3943`
    - `lib/ui/home_page.dart:4099`
    - `test/mode_single_run_dump_test.dart:212`

- `loadEpicMeta(...)`
  - uses root simulation rules only
  - builds `BossMeta.fromJson(metaJson)`
  - used in:
    - `lib/ui/home_page.dart:3151`

- `loadEpicThreshold()`
  - reads `thresholdEpicBoss`
  - used in:
    - `lib/ui/home_page.dart:331`

- `loadRaidFreeEnergies()`
  - reads `raidFreeEnergies`
  - used in:
    - `lib/ui/home_page.dart:350`
    - `test/elixirs_test.dart:17`

- `loadDefaultDurableRockShield()`
  - reads root by passing the full object into `BossMeta.fromJson(root)`
  - used in:
    - `lib/ui/home_page.dart:356`

- `loadDefaultElementalWeakness()`
  - reads root by passing the full object into `BossMeta.fromJson(root)`
  - used in:
    - `lib/ui/home_page.dart:357`

### Reads OCR defaults

- `loadDefaultKnightImportCrop()`
  - reads OCR crop defaults
  - used in:
    - `lib/ui/home_page.dart:392`
    - `test/elixirs_test.dart:22`

### Reads boss tables

- `loadEpicTable()`
  - reads `tables.Epic`
  - used in:
    - `lib/ui/home_page.dart:3117`

- `loadBossTable(raidMode: ...)`
  - reads `tables.Raid` or `tables.Blitz`
  - used in:
    - `lib/ui/home_page.dart:1447`

### Reads elixir catalog

- `loadElixirs({String? gamemode})`
  - reads `elixirs`
  - used in:
    - `lib/ui/home_page.dart:319`
    - `lib/ui/home_page.dart:1292`
    - `lib/ui/war_page.dart:154`
    - `test/elixirs_test.dart:10`

### Reads war points

- `loadWarPoints()`
  - reads `War`
  - used in:
    - `lib/ui/war_page.dart:147`

## 4. Model Contracts Touched by the Split

### `BossMeta`

Current issue:

- `BossMeta.fromJson(...)` accepts a broad root-shaped object.
- It parses:
  - simulation rules
  - timing
  - pet bar
- This is convenient for a monolith, but it ties runtime loading to the old
  file structure.

Split implication:

- runtime loading should move toward a composed source model, for example:
  - `BossMeta.fromSources(...)`
  - or a dedicated aggregate loader that produces `BossMeta`

Important:

- `BossMeta.fromJson(...)` is still needed for:
  - test fixtures
  - exported `Precomputed` / result payloads
  - isolate payload reconstruction

So Phase 2 should not remove it.

### `TimingConfig`

Current issue:

- timing can be parsed from nested `timing` or directly from root.
- current asset still uses flat root timing keys.

Split implication:

- move to a clean `timing` object in `sim_rules.json`
- keep root fallback in `TimingConfig.fromJson(...)` until migration is stable

### `PetTicksBarConfig`

Current issue:

- `PetTicksBarConfig.fromRootJson(...)` expects the `petTicksBar` block to live
  inside the root object.

Split implication:

- add a direct parser such as `PetTicksBarConfig.fromJson(...)`
- keep `fromRootJson(...)` as compatibility wrapper during migration

## 5. Active vs Legacy Classification

### Confirmed active

- all values used by `BossMeta.fromJson(...)`
- all values used by `loadBossTable`, `loadEpicTable`
- `elixirs`
- `War`
- OCR crop defaults
- active `petTicksBar` fields

### Legacy / technical debt candidates

- `bossSpecial` flat key name
  - should become `timing.bossSpecialDuration`
- `petTicksBar.bossNormalORGINAL`
- `petTicksBar.bossSpecialORIGINAL`
- `petTicksBar.petKnightORIGINAL`
- root `boss`

### Keep for now, even if old-looking

- `hitsToFirstShatter`
- `hitsToNextShatter`

Reason:

- they are still parsed and still used as fallback when pet bar logic is not
  enabled for `Shatter Shield`.

## 6. Proposed Split Target

Target asset layout:

- `assets/sim_rules.json`
- `assets/pet_bar_rules.json`
- `assets/boss_tables.json`
- `assets/elixirs.json`
- `assets/war_points.json`
- `assets/ocr_defaults.json`

### 6.1 `assets/sim_rules.json`

Owns:

- all shared simulation rules
- threshold / free energies
- timing

Proposed shape:

```json
{
  "cycleMultiplier": 1.385844,
  "thresholdEpicBoss": 80,
  "raidFreeEnergies": 30,
  "epicBossDamageBonus": 0.25,
  "evasionChance": 0.1,
  "criticalChance": 0.05,
  "criticalMultiplier": 1.5,
  "raidSpecialMultiplier": 3.25,
  "knightToSpecial": 5,
  "bossToSpecial": 6,
  "knightToSpecialSR": 7,
  "knightToRecastSpecialSR": 13,
  "knightToSpecialSREW": 7,
  "knightToRecastSpecialSREW": 13,
  "hitsToElementalWeakness": 7,
  "defaultElementalWeakness": 0.65,
  "durationElementalWeakness": 2,
  "bossToSpecialFakeEW": 1000,
  "hitsToFirstShatter": 7,
  "hitsToNextShatter": 13,
  "cyclone": 71.0,
  "cycloneBarion": 97.625,
  "hitsToDRS": 7,
  "durationDRS": 3,
  "defaultDurableRockShield": 0.5,
  "sameElementDRS": 1.6,
  "strongElementEW": 1.6,
  "timing": {
    "normalDuration": 0.4,
    "specialDuration": 0.6,
    "stunDuration": 0.2,
    "missDuration": 0.3,
    "bossDuration": 0.4,
    "bossSpecialDuration": 0.7
  }
}
```

### 6.2 `assets/pet_bar_rules.json`

Owns:

- all `petTicksBar` fields

Proposed shape:

```json
{
  "enabled": true,
  "ticksPerState": 165,
  "startTicks": 165,
  "petCritPlusOneProb": 0.4,
  "bossNormal": {
    "1": 1.0
  },
  "bossSpecial": {
    "2": 1.0
  },
  "bossMiss": {
    "1": 1.0
  },
  "stun": {
    "1": 1.0
  },
  "petKnightBase": {
    "10": 1.0
  },
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
```

Notes:

- exclude `*ORIGINAL` legacy blocks from the target shape
- if you want to preserve them temporarily for auditing, keep them in a
  separate scratch file, not in production config

### 6.3 `assets/boss_tables.json`

Owns:

- `Raid`
- `Blitz`
- `Epic`

Proposed shape:

```json
{
  "Raid": [...],
  "Blitz": [...],
  "Epic": [...]
}
```

### 6.4 `assets/elixirs.json`

Owns:

- `elixirs`

Proposed shape:

```json
{
  "elixirs": [...]
}
```

### 6.5 `assets/war_points.json`

Owns:

- `War`

Proposed shape:

```json
{
  "War": {
    "EU": { "normal": {...}, "strip": {...} },
    "Global": { "normal": {...}, "strip": {...} }
  }
}
```

### 6.6 `assets/ocr_defaults.json`

Owns:

- OCR crop defaults only

Proposed shape:

```json
{
  "defaultOcrCropLeft": 20,
  "defaultOcrCropRight": 15,
  "defaultOcrCropTop": 5,
  "defaultOcrCropBottom": 55
}
```

## 7. Migration Strategy Constraints

The split should not directly break:

- `ConfigLoader` public API
- exported result payloads relying on `BossMeta.toJson()`
- test fixtures using `BossMeta.fromJson(...)`
- isolate payload reconstruction using `BossMeta.fromJson(...)`

Therefore the first refactor target is:

- move file ownership
- keep runtime call sites stable
- introduce a compatibility facade in `ConfigLoader`

## 8. Recommended Phase Order

### Phase 2

- create the new asset files
- copy validated data into them
- keep the old monolith untouched

### Phase 3

- add specialized loaders:
  - `sim_rules_loader.dart`
  - `pet_bar_rules_loader.dart`
  - `boss_tables_loader.dart`
  - `elixirs_loader.dart`
  - `war_points_loader.dart`
  - `ocr_defaults_loader.dart`

### Phase 4

- add composed parsing for `BossMeta`
- add direct `PetTicksBarConfig.fromJson(...)`

### Phase 5

- convert `ConfigLoader` into a compatibility facade

### Phase 6

- migrate UI/runtime call sites implicitly through the facade
- add test coverage for every new loader

### Phase 7

- remove dependence on `_loadRoot()` for runtime paths
- validate old/unused keys

### Phase 8

- remove `assets/raidComplete_data.json`
- remove legacy fields and update `guidelines.md`

## 9. Decision Summary

Recommended split:

- `sim_rules.json`
- `pet_bar_rules.json`
- `boss_tables.json`
- `elixirs.json`
- `war_points.json`
- `ocr_defaults.json`

Recommended architectural rule:

- keep `ConfigLoader` stable for callers during migration
- move new logic behind specialized loaders
- do not remove `BossMeta.fromJson(...)` in the same refactor

## 10. Phase 6 Audit Result

After the facade migration:

- runtime reads no longer directly load `assets/raidComplete_data.json`
- `ConfigLoader` delegates to split-domain loaders
- remaining references are compatibility-only:
  - `BossMeta.fromJson(...)`
  - `PetTicksBarConfig.fromRootJson(...)`
  - tests validating backward compatibility

This means the project is ready for the final cleanup phases:

- remove residual compatibility that is no longer needed
- remove the monolith asset from runtime ownership
- update documentation to reflect the new config topology

## 11. Phase 7 Cleanup Result

Phase 7 removed the last active model-level coupling between split-source
composition and the old root-shaped config contract:

- `BossMeta.fromSources(...)` no longer builds a pseudo-root map and bounces
  through `BossMeta.fromJson(...)`
- `BossMeta.fromSources(...)` now parses split sim rules and pet bar maps
  directly through shared internal parsing logic
- `BossMeta.fromJson(...)` remains available for compatibility with:
  - exported payload reconstruction
  - isolate payload reconstruction
  - legacy/root-shaped fixtures in tests
- `PetTicksBarConfig.fromRootJson(...)` is explicitly compatibility-only and
  deprecated in favor of `PetTicksBarConfig.fromJson(...)`

At the end of Phase 7:

- runtime uses split assets and split loaders
- active composition paths no longer depend on the monolith root shape
- remaining legacy helpers are compatibility wrappers only

## 12. Phase 8 Finalization Result

Phase 8 completes the config split:

- `assets/raidComplete_data.json` is removed from the project
- project documentation now points to split ownership by domain:
  - `assets/sim_rules.json`
  - `assets/pet_bar_rules.json`
  - `assets/boss_tables.json`
  - `assets/elixirs.json`
  - `assets/war_points.json`
  - `assets/ocr_defaults.json`
- runtime remains compatible because callers still use `ConfigLoader`
- compatibility helpers intentionally remain for:
  - legacy/root-shaped test fixtures
  - payload reconstruction in exports/imports
  - isolate payload reconstruction

Final state:

- no runtime dependency on the monolith asset
- no monolith asset bundled in the project
- split config topology documented as the new source of truth
