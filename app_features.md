# App Features

Versione riformulata in formato card-ready, pensata come base per schede help dentro l'app.

Regola pratica:

- mantenere questo file allineato con `lib/ui/home/app_features_sheet.dart`
- se nasce una nuova card o cambia il fallback copy, aggiornare anche qui

## Raid / Blitz Simulator

Summary:
Run large battle simulations and review score, expected range, gem cost and knight breakdowns.

Quick use:
1. Set Boss, Pet and Knights on the Home screen.
2. Choose the number of simulations and active knights.
3. Press `Simulate` to open the full report.

Best for:
- testing team damage
- comparing pet loadouts

Note:
- The runtime can also drive knight SPECIAL through the Knight Special Bar when the active config enables it, instead of relying only on the legacy fixed-turn cadence.

## Graph View & Charts

Summary:
Turn on `Graph View` inside results pages to add charts alongside the detailed tables, including score range, score distribution, threshold chance, knight pressure and Bulk comparison visuals.

Quick use:
1. Open a Raid / Blitz results page or the Bulk compare page.
2. Enable `Graph View` when the toggle is available.
3. Use the charts to scan score shape, compare thresholds and read setup tradeoffs faster.

Best for:
- faster report scanning
- visual setup comparison
- spotting stable vs swingy setups

## Debug Battle Log

Summary:
Replay one deterministic battle with a turn-by-turn log, live search and log copy.

Quick use:
1. Enable `Debug` from the quick actions menu.
2. Start the simulation.
3. Search the log or copy it for troubleshooting.

Best for:
- checking skill interactions
- understanding unexpected runs

Note:
Premium only.

## Epic Simulator

Summary:
Simulate Epic Boss runs and review results with the dedicated Epic flow.

Quick use:
1. Open the Epic flow from the main Raid setup.
2. Set your knights, pet and Epic boss context.
3. Run the simulation to review the Epic results page.

Best for:
- epic boss planning
- checking epic teams

Note:
- With Premium, friend slots in Epic setups are unlocked.

## Pet Tools

Summary:
Manage pet stats, elements, selected skills, custom skill values and pet bar usage.

Quick use:
1. Set pet ATK, Elemental ATK, Elemental DEF and elements.
2. Choose Skill Slot 1, Skill Slot 2 and pet bar order.
3. Adjust skill numbers when you want custom testing.

Best for:
- fine tuning pet skills
- testing alternate values

## Pet Compendium

Summary:
Browse pet families, filter by rarity and skill, then import the selected pet directly into the Home setup.

Quick use:
1. Open `Utilities > Pet Compendium`.
2. Search by pet name, skill or family tag.
3. Pick tier, level and skill set, then tap `Use pet`.

Best for:
- fast pet lookup
- building setups quickly

Note:
- Includes an in-app thank-you note for Kasper534 for helping gather the data.

## Knight OCR Import

Summary:
Import ATK, DEF and HP for all three knights from a screenshot with crop controls and a review step.

Quick use:
1. Tap the image icon in the `Knights` section.
2. Adjust the crop values and choose your screenshot.
3. Review the detected numbers before applying them.

Best for:
- saving setup time
- copying stats from screenshots

## Wargear Wardrobe

Summary:
Import maxed armor sets with filters for elements, role, guild rank, guild element bonuses and Base / `+` version, including support for special UA and Starmetal outliers. Favorite armor shortcuts can also show a contextual `Universal Armor Score` based on the current boss, pet and slot.

Quick use:
1. Open `Utilities > Wargear Wardrobe` or the star inside a slot.
2. Filter armor by role, rank, elements, version and guild element bonuses.
3. If you opened the sheet from a knight star, compare the displayed scores and sort by the highest one.
4. Tap `Use armor` to import stats into the selected slot.

Best for:
- armor comparisons
- favorite armor quick insert

Note:
- Includes an in-app thank-you note for Kasper534 for helping gather the data.
- `Universal Armor Score` is hidden in the generic Utilities sheet and appears in the per-slot favorite import flow, where the app already knows the current boss, pet and knight context.
- On knight slots, `STUN %` also affects the `Universal Armor Score`.

## Imported Armor Badges

Summary:
Imported armor cards on the Raid Home screen show tappable badges for role, guild rank and version, so you can cycle them and recalculate stats instantly.

Quick use:
1. Import an armor into a knight or friend slot from `Wargear Wardrobe`.
2. Tap the `Role`, `Rank` or `Version` badge on the Home card.
3. Each tap cycles the badge and recalculates the imported armor stats.

Best for:
- quick role swaps
- rank comparisons
- base vs plus checks

## Universal Armor Score

Summary:
Compare favorite armors with a fast contextual score that adapts to the current boss, pet setup, knight slot and final armor stats.

Quick use:
1. Configure the current boss and pet on the Home screen.
2. Open the star inside a knight slot to browse your favorite armors.
3. Compare the displayed `Universal Armor Score`, sort by the highest value and import the armor you want.
4. After import, read `Universal Armor Score` directly on the knight card in Home.

Best for:
- faster armor decisions
- contextual armor ranking
- quick pre-sim checks

Note:
- The score is contextual, so it changes with boss mode, boss level, boss elements, pet setup and the selected knight slot.
- The score uses the armor's final resolved `ATK`, `DEF` and `HP`, then also factors in pet elemental `ATK/DEF` when the pet matches the armor.
- On knight cards, `STUN %` further modifies the score.
- This is a fast runtime heuristic inspired by the simulation battery, not a full re-run of the battle engine.

## Wardrobe Simulate

Summary:
Use the real Raid / Blitz simulator on every 3-armor setup generated from your top 5 favorite armors ranked by `Universal Armor Score`, then review the top 5 setups by mean damage.

Quick use:
1. Set the current boss, pet and simulation count on the Home screen.
2. Save at least 5 favorite armors that match your current Wardrobe filters.
3. Press `Wardrobe Simulate`.
4. Confirm the total number of generated setups and runs, then review the final ranking report.

Best for:
- premium armor optimization
- top-setup discovery
- favorite pool comparisons

Note:
- Premium only.
- Uses the current Home context for `boss`, `pet`, `pet skills`, `guild bonuses` and `runs`.
- Uses the current saved Wardrobe filters for `Plus`, `Rank`, `Season` and `elements`.
- Intentionally ignores the Wardrobe `Role` filter, because the tool must test all valid `1 Primary + 2 Secondary` assignments.
- The report shows the candidate pool, the parameters used and the top 5 simulated setups ordered by `mean total damage`.

## Boss Stats Lookup

Summary:
Check the base ATK, DEF and HP tables for Raid, Blitz and Epic Boss in one place.

Quick use:
1. Open `Utilities > Boss stats`.
2. Switch between `Raid`, `Blitz` and `Epic`.
3. Read the level table you need before building or sharing a setup.

Best for:
- quick stat checks
- verifying boss data before simulating

## Setups and Bulk Simulate

Summary:
Save your Raid / Blitz builds, reload them later, share them with others and compare multiple setups in one batch.

Quick use:
1. Save a setup from `Utilities > Save setup`.
2. Open `Setups` from the top quick actions menu to load, rename, export or import.
3. Use `Bulk Simulate` once you have at least two saved setups.

Best for:
- guild sharing
- multi-setup comparison

## War Calculator

Summary:
Plan attacks, Power Attacks, energy and gems for War milestones with EU / Global, Strip, Frenzy and elixir support.

Quick use:
1. Open the `War` tab.
2. Enter milestone and available energy.
3. Set server, toggles and PA strategy to read the final plan.

Best for:
- war planning
- gem budgeting

## Raid Guild Planner

Summary:
Estimate how many Raid or Blitz bosses your guild needs to kill to reach a target score, with both a simple boss-level estimate and a Premium fastest-path optimizer.

Quick use:
1. Open the `War` tab and switch to the Premium Raid planner from the top quick menu.
2. Use `Simple estimate` for one boss level, or `Fastest path` for multi-boss optimization.
3. In `Fastest path`, either paste one player per line like `1200000, Maxxetto` or use `Optimize on selected boss levels` to enter nicknames and averages per level.
4. Review the recommended board, kill breakdown, energy, gems and suggested first-round assignments.

Best for:
- guild score planning
- assigning players to boss slots
- estimating energy and gem cost to overtake another guild

Note:
- Premium only.
- Boss HP and flat kill bonus are read from `boss_tables.json`.
- The export button copies a JSON summary of inputs and results, including roster data and first-round assignments.

## UA Planner

Summary:
Track monthly UA progress, event rewards, placements, bonus conditions and the full event cadence with Calendar View, export and import support.

Quick use:
1. Open `UA Planner`.
2. Enable the events you are playing that month.
3. Enter score and placement values to see Elite and Elite+ progress.
4. Open `Calendar View` from the top quick actions to review War, War Blitz, Raid, Raid Blitz, Heroic and Blitz Arena dates across the planner range.

Best for:
- monthly planning
- piece forecasting
- calendar-based event tracking

Note:
- The top quick actions also include planner lock, export and import.
- Heroic date selections are saved per date, so individual Heroic runs remain restorable across app restarts.

## News and Event Shop

Summary:
Follow event schedules, track completed rows and calculate required shop currencies from event-specific shop data and your selected items.

Quick use:
1. Open the `News` tab.
2. Switch between `Active`, `Ended` and `Upcoming`.
3. Open an event with shop data, select the shop items and quantities you want, then review the required currencies.
4. Enter current inventory when needed so the planner can show what remains after owned resources.

Best for:
- event tracking
- shop planning
- currency budgeting

Note:
- Event shop planners can use the active event's own item limits, currencies and tracked table rewards.

## Friend Codes

Summary:
Search friend codes by player name, code, server and platform, then copy them with one tap.

Quick use:
1. Open `Friend Codes`.
2. Filter by server or platform.
3. Tap a code to copy it.

Best for:
- finding active contacts
- quick copy and share

## Results Sharing

Summary:
Export a results page as JSON and import it on another device or account for local review.

Quick use:
1. Open a results page.
2. Tap `Copy export`.
3. On another device, use `Utilities > Import results`.

Best for:
- support requests
- guild comparisons

## Last Results and Session Restore

Summary:
The app remembers the latest session and can reopen the latest saved results without recalculating.

Quick use:
1. Run a simulation.
2. Use `Last results` from the quick actions menu.

Best for:
- quick report review
- resuming where you left off

## Premium

Premium unlocks:

- Debug battle log
- extra setup slots
- full Bulk Simulate access
- Epic Friends section
- extended limits for elixirs and favorites
- advanced timing and premium-only result metrics where available
