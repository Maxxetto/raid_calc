# Raid Calculator

Flutter app for raid/war/epic simulation workflows with Premium gating and
multi-language UI.

## Main Modules

- `lib/ui/`: app shell and pages (`home_page`, `results_page`, `war_page`,
  `epic_results_page`, `debug_results_page`, `friend_codes_page`)
- `lib/core/`: simulation engine, modes, debug hooks, epic/war isolates
- `lib/data/`: config loaders and last-session persistence
- `lib/premium/`: RevenueCat entitlement/service layer
- `lib/util/`: i18n, formatting, elixir and war calculators
- `assets/`: gameplay config and translations

## Key Assets

- `assets/sim_rules.json`: shared simulation rules, thresholds, timing
- `assets/pet_bar_rules.json`: pet special bar / ticks rules
- `assets/boss_tables.json`: Raid, Blitz and Epic boss tables
- `assets/elixirs.json`: elixir catalog
- `assets/war_points.json`: War point sets and modes
- `assets/ocr_defaults.json`: default OCR crop values
- `assets/langs/manifest.json`: i18n index for split language files
- `assets/friendCodes_data.json`: static friend code dataset

## Development

1. Install dependencies
   - `flutter pub get`
2. Static analysis
   - `flutter analyze`
3. Run tests
   - `flutter test`
4. Run app
   - `flutter run`

## Notes

- Premium is integrated with RevenueCat (`purchases_flutter` + `purchases_ui_flutter`).
- Android RevenueCat key can be provided with:
  - `--dart-define=RC_ANDROID_API_KEY=...`
  - or `android/key.properties` (`revenueCatApiKey`) as fallback wiring.
- Agent instructions and verification rules live in `AGENTS.md`.
- Human-facing project reference and doc map live in `guidelines.md`.
