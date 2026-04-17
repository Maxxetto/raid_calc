# Working Agreements

## Scope

- Flutter/Dart app for raid, blitz, epic, war, UA, pet and wargear workflows.
- Keep diffs minimal and targeted.
- Avoid speculative refactors unless explicitly requested.
- Preserve current Premium gating and active data formats unless the task requires a deliberate change.

## Ownership map

- `lib/core/`: battle runtime and simulation engine
- `lib/data/`: loaders, storage, planners and scoring
- `lib/ui/`: pages, sheets and widgets
- `lib/premium/`: entitlement and RevenueCat layer
- `assets/`: datasets and i18n assets
- `tool/`: audits and generators
- `test/`: unit, widget and integrity tests

## Commands

- Setup: `flutter pub get`
- Analyze: `flutter analyze`
- Full tests: `flutter test`
- Text audit: `python tool/text_encoding_audit.py`

## Non-negotiables

- Keep all docs and user-facing text in UTF-8.
- If you touch copy, translations or markdown, run the encoding audit.
- If you add or change any user-facing string, update all `assets/langs/*.json`
  files listed in `assets/langs/manifest.json` in the same change set.
- Do not rely on EN/IT-only additions plus runtime fallback for newly introduced
  keys; language files must stay complete as soon as the string ships.
- Do not add dependencies unless clearly needed.
- Do not change unrelated files while doing a focused task.
- Update docs and tests when behavior or copy changes.
- Keep `app_features.md` aligned with `lib/ui/home/app_features_sheet.dart`.
- For broader project/documentation context, refer to `guidelines.md`.

## Fast paths

### Wargear UAS

- Treat the user-facing Universal Armor Score as `armor-only` by default.
- Keep `pet-aware` as an optional contextual variant; do not replace the default ranking semantics with pet factors.
- When touching UAS logic, preserve the split between stable stat weights and situational modifiers such as pet skills, usage and stun.
- Candidate pruning and initial Wardrobe ranking should stay `armor-only` unless the task explicitly asks for pet-aware comparisons.

### Feature work

1. Identify the owning layer first: `lib/ui`, `lib/data`, `lib/core` or `assets`.
2. Edit only the minimum files needed.
3. If user-facing copy changes, update `assets/langs/*.json`.
4. If a feature help card changes, update `app_features.md`.

### Pet compendium updates from screenshots

- Extract: pet name, rarity, `familyTag`, tier, level, elements, stats, skill names and skill values.
- Update the correct rarity index plus `assets/pet_compendium_compact_library.json`.
- Reuse existing `statsProfile`, `skillPayload` and `skillSet` when values already match.
- Keep one canonical profile per tier and prefer the highest available level.
- Verify with (run as one command):
  ```
  flutter test test/pet_compendium_loader_test.dart test/pet_compendium_loader_consistency_test.dart test/pet_compendium_compact_integrity_test.dart
  ```

### Wargear updates from screenshots

- Extract: base name, `seasonTag`, elements, normal stats, bonus normal, optional plus stats and optional jewelry outliers.
- Edit `assets/wargear_wardrobe.json`.
- Keep one entry per armor; fold the `+` data into the same entry instead of creating a second armor.
- Do not invent missing plus or jewelry data.
- Before adding, grep for the armor name to check for an existing entry to update in place.

#### Stats compact vector format

```
"stats": [base_atk, base_def, setBonus_atk, setBonus_def, setBonus_health,
           plus_atk, plus_def, plus_setBonus_atk, plus_setBonus_def, plus_setBonus_health]
```

- 5 values: normal only (no plus variant).
- 10 values: normal + plus.
- `setBonus_atk` / `setBonus_def` are 0 for S116 and earlier; non-zero from S117 onwards.

#### Jewelry vector — only when ring/amulet differ from global table

Global ring bonuses (atk/hp): fire 951/209 · spirit 504/318 · earth 729/268 · air 911/233 · water 866/248

Global amulet bonuses (atk/hp): fire 911/233 · spirit 273/343 · earth 639/293 · air 866/248 · water 821/258

Decision:
- Ring of armor == `ringBonuses[elements[0]]` AND amulet == `amuletBonuses[elements[1]]` → **no jewelry field**.
- Otherwise → add `"jewelry": [ring_atk, ring_hp, amulet_atk, amulet_hp, ring_atk, ring_hp, amulet_atk, amulet_hp]` (same values for normal and plus unless different).

#### Season bucket behavior (affects tests)

`_seasonFilterBucket` groups by number: S117, S117RB, S117GW all map to bucket "S117". Adding an armor with a variant seasonTag (e.g. S117GW) increases the S117 filter count in tests.

#### Test count updates required after adding a new armor entry

- `test/wargear_wardrobe_loader_test.dart` — `catalog.armors.length`: increment by 1.
- `test/wargear_wardrobe_sheet_test.dart` — `"N armor sets found"` for the bucket of the new armor's season: increment by 1.

#### Verify with (run as one command)

```
flutter test test/wargear_wardrobe_loader_test.dart test/wargear_wardrobe_sheet_test.dart test/wargear_favorites_storage_test.dart
```

Add `test/home_page_widget_test.dart` if the Home flow was touched.

### Results UI updates

- Keep the top-level order: `Performance Summary`, `Battle Context`, `Pet & Mode`, `Knights`, `Advanced Details`.
- Put overview data early, knight-specific data in knight cards, verbose/technical data in `Advanced Details`.
- Classify every Results/Bulk chart as either `score-only` or `premium-timing`.
- Any chart or metric that uses `stats.timing` or time-derived values stays Premium-only.
- Outside the Timing section, unavailable time-based content should be hidden rather than replaced with extra lock cards.
- When adding or changing Results/Bulk charts, update the Premium gating widget tests too.
- Verify with:
  - `flutter test test/results_page_widget_test.dart`
  - `flutter test test/bulk_results_page_test.dart` if bulk output might change

### Text, i18n and markdown edits

- Read `PRE_EDIT_TEXT_PROTOCOL.md` before risky text edits.
- Run before and after:
  - `python tool/text_encoding_audit.py`
- Run focused checks after text changes:
  - `flutter test test/i18n_test.dart`
  - `flutter test test/text_assets_encoding_test.dart`
- Treat split language assets as the source of truth; keep `assets/langs/*.json`
  + `assets/langs/manifest.json` and do not collapse them into a single file.

## Definition of done

- The smallest correct diff is in place.
- Relevant tests or checks were run, or any skipped verification is stated explicitly.
- Docs/assets were updated if behavior, copy or data contracts changed.
- No stale instructions or obvious drift were introduced.
