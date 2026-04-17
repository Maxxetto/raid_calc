# Wargear Scoring Parameters

This file explains the main parameters produced by the boss simulation battery and how they are used to reason about armor scoring.

## 1. Scenario Parameters

These describe the exact setup that was simulated.

- `mode`
  - The boss mode being tested.
  - Values: `raid`, `blitz`.

- `boss_level`
  - The target boss level for that scenario.

- `mode_level`
  - A combined target key such as `raid_L4` or `blitz_L6`.
  - This is the real combat context.
  - It matters a lot because different targets have very different score ranges.

- `stat_tier_id`
  - The stat package used in the test.
  - Example: `tier_1` up to `tier_7`.

- `attack_def_swapped`
  - Whether the tier used its normal ATK/DEF distribution or the swapped one.
  - This was used to measure whether more defensive distributions perform better.

- `layout`
  - Knight arrangement inside the team.
  - Values:
    - `pss` = primary, secondary, secondary
    - `sps` = secondary, primary, secondary
    - `ssp` = secondary, secondary, primary

- `primary_slot`
  - The slot occupied by the primary knight.
  - Values: `1`, `2`, `3`.

- `pet_primary_skill`
  - The pet skill tested in slot 1.
  - Main tested values:
    - `soul_burn`
    - `vampiric_attack`
    - `elemental_weakness`

- `pet_strategy`
  - The pet special usage pattern.
  - Main tested values:
    - `double_s2_then_s1` = `2, 2, then 1`
    - `s2_then_s1` = `2, then 1`

- `knight_adv_vector`
  - Knight advantage against the boss for the three knight slots.
  - Example: `1-1_5-2`.

- `knight_adv_mean`
  - Mean value of the knight advantage vector.
  - Higher is better.

- `boss_adv_vector`
  - Boss advantage against the knights for the three slots.
  - Example: `1-1_5-2`.

- `boss_adv_mean`
  - Mean value of the boss advantage vector.
  - Lower is better.

## 2. Aggregate Result Metrics

These summarize the repeated runs of one scenario.

- `final_score`
  - The derived scenario score produced by the scoring layer.
  - It is built from the aggregate metrics, not from a single run.

- `mean_total_damage`
  - Average total damage across all runs for that scenario.

- `median_total_damage`
  - Middle total damage value.
  - Useful to compare with the mean when the distribution is skewed.

- `min_total_damage` / `max_total_damage`
  - Lowest and highest result observed for the scenario.

- `stddev_total_damage`
  - Damage volatility.
  - Lower means more consistency.

- `p10`, `p25`, `p75`, `p90`
  - Damage percentiles.
  - These show weak, low-mid, high-mid and strong outcomes.

- `completion_rate`
  - How often the scenario completes the target, when applicable.

- `survival_rate`
  - How often the team survives, when applicable.

- `mean_turns_survived`
  - Average number of turns survived.

- `mean_pet_cast_count`
  - Average pet casts per run.

- `mean_damage_by_knight`
  - Average damage contribution of each knight.

- `mean_special_usage_by_knight`
  - Average special usage count of each knight, when available.

## 3. Influence Metrics

These measure how much each parameter affects the result.

- `eta_squared`
  - Share of variance explained by a factor.
  - Higher means the factor is more influential.

- `mean_score_range`
  - Difference between the best and worst average score inside that factor.

- `mean_score_range_pct`
  - Same range expressed as a percentage.

- `top_level`
  - The best-performing value inside that factor.

- `bottom_level`
  - The worst-performing value inside that factor.

## 4. Raw vs Adjusted Influence

There are two useful ways to read influence:

- `raw`
  - Measures total impact without controlling for target context.
  - Here, factors like `mode_level` and `stat_tier_id` dominate.

- `adjusted`
  - Results are centered by `mode_level + stat_tier_id`.
  - This answers the more useful question:
  - "At the same target and stat tier, what really changes performance?"

This adjusted view is the important one for Wargear scoring design.

## 5. What the Simulation Showed

The strongest practical findings were:

- `mode_level` matters a lot.
  - Armor scoring should be target-specific, not globally absolute.

- `stat_tier_id` matters a lot.
  - More stats obviously push performance upward.

- After controlling for target and tier, the most important factors are:
  - `boss_adv_vector`
  - `knight_adv_vector`
  - `pet_primary_skill`
  - `attack_def_swapped`
  - `pet_strategy`

- `layout` and `primary_slot` are almost irrelevant.
  - This means the final Wardrobe score should not give meaningful weight to slot order.

- `swapped` usually beats `normal`.
  - This suggests defensive value is stronger than a naive ATK-only reading.

- `elemental_weakness` performed best among the tested primary pet skills.

## 6. How This Feeds Wargear Scoring

These reports are not yet saying:

- "This armor is rank 1 globally."

They are saying:

- which variables move the outcome the most;
- which variables are almost noise;
- which levers should be reflected inside a future armor score.

For the in-app Wardrobe scoring, this means:

- use the current boss target as part of the score context;
- weight DEF slightly more than a naive ATK-only model;
- apply strong context sensitivity to knight advantage and boss penalty;
- treat pet primary skill as a secondary modifier;
- treat pet usage strategy as a small modifier;
- avoid giving real weight to layout or primary slot order.

## 7. Practical Reading Guide

If you want the fastest path through the simulation outputs:

1. Read `post_processing_summary.md`
2. Check `factor_influence_adjusted.csv`
3. Check `swapped_vs_normal.csv`
4. Check `mode_level_summary.csv`

That is enough to understand which parameters should influence the Wardrobe score and which ones should stay neutral.

## 8. Current Universal Score Runtime Model

The in-app `Universal Scoring` is a contextual heuristic built on top of the simulation findings.

It is not a replay of the full simulation battery.
It is a fast runtime score used to compare armors inside the current Home setup.

### 8.1 Runtime Inputs

The current runtime score uses:

- current boss mode
- current boss level
- current boss elements
- current pet elemental ATK
- current pet elemental DEF
- current pet selected skills
- current pet usage mode
- current armor elements
- current armor resolved ATK / DEF / HP
- current guild element bonuses
- current role and guild rank already baked into the resolved armor stats
- current knight `STUN %` only when the score is shown for a knight slot

The score is shown:

- in the favorite armor picker opened from the knight star shortcut
- on the knight card in Home as `Universal Scoring`

It is intentionally not shown when opening `Utilities > Wargear Wardrobe`.

### 8.2 Stat Weights

Base weighted stats:

- `weightedStats = atk * attackWeight + def * defenseWeight + hp * healthWeight`

Current weights by target:

- `raid_L4`
  - `attackWeight = 1.00`
  - `defenseWeight = 1.16`
  - `healthWeight = 34`
  - `modeScale = 4.00`
  - `knightAdvantageSlope = 0.32`
  - `bossAdvantageSlope = 0.24`

- `raid_L6`
  - `attackWeight = 1.00`
  - `defenseWeight = 1.18`
  - `healthWeight = 36`
  - `modeScale = 2.20`
  - `knightAdvantageSlope = 0.32`
  - `bossAdvantageSlope = 0.24`

- `raid_L7`
  - `attackWeight = 1.00`
  - `defenseWeight = 1.20`
  - `healthWeight = 38`
  - `modeScale = 1.15`
  - `knightAdvantageSlope = 0.32`
  - `bossAdvantageSlope = 0.24`

- `blitz_L4`
  - `attackWeight = 1.00`
  - `defenseWeight = 1.10`
  - `healthWeight = 22`
  - `modeScale = 0.85`
  - `knightAdvantageSlope = 0.28`
  - `bossAdvantageSlope = 0.22`

- `blitz_L5`
  - `attackWeight = 1.00`
  - `defenseWeight = 1.12`
  - `healthWeight = 24`
  - `modeScale = 0.58`
  - `knightAdvantageSlope = 0.28`
  - `bossAdvantageSlope = 0.22`

- `blitz_L6`
  - `attackWeight = 1.00`
  - `defenseWeight = 1.14`
  - `healthWeight = 26`
  - `modeScale = 0.50`
  - `knightAdvantageSlope = 0.28`
  - `bossAdvantageSlope = 0.22`

- `epic_default`
  - `attackWeight = 1.00`
  - `defenseWeight = 1.16`
  - `healthWeight = 30`
  - `modeScale = 1.80`
  - `knightAdvantageSlope = 0.30`
  - `bossAdvantageSlope = 0.22`

### 8.3 Pet Elemental Bonus Handling

Before scoring, the candidate armor gets the current pet elemental bonuses:

- `finalAtk = resolvedArmorAtk + petElementalAtk * matchCount`
- `finalDef = resolvedArmorDef + petElementalDef * matchCount`
- `finalHp = resolvedArmorHp`

Where `matchCount` follows the same armor import rules already used by the Home page.

### 8.4 Advantage Factors

The current runtime score uses:

- `knightFactor = 1 + ((knightAdvantage - 1.5) * knightAdvantageSlope)`
- `bossFactor = 1 - ((bossAdvantage - 1.0) * bossAdvantageSlope)`

This reflects the simulation output where:

- knight advantage matters strongly
- boss advantage matters strongly
- boss penalty must lower the final score

### 8.5 Pet Skill Factors

Current primary skill multipliers:

- `Elemental Weakness = 1.034`
- `Vampiric Attack = 0.997`
- `Soul Burn = 0.971`
- fallback / unknown = `1.000`

Current secondary skill multipliers:

- `Special Regeneration Infinite = 1.012`
- `Special Regeneration = 1.006`
- fallback / unknown = `1.000`

### 8.6 Pet Usage Factors

Current usage multipliers:

- `doubleSpecial2ThenSpecial1 = 0.993`
- `special2ThenSpecial1 = 1.007`
- `special1Only = 0.985`
- `special2Only = 0.992`
- `cycleSpecial1Then2 = 1.000`

### 8.7 Stun Factor

`STUN %` is currently treated as a direct multiplier only for knight-slot scoring.

Formula:

- `stunFactor = 1 + stunPercent / 100`

Examples:

- `0% -> x1.00`
- `1% -> x1.01`
- `10% -> x1.10`
- `25% -> x1.25`

Rules:

- clamp range: `0% -> 25%`
- applies only when scoring a knight slot
- not used in the generic Utilities Wardrobe view

### 8.8 Final Runtime Formula

Current runtime structure:

- `finalScore = weightedStats * modeScale * knightFactor * bossFactor * petPrimarySkillFactor * petSecondarySkillFactor * petUsageFactor * stunFactor`

This should be treated as configurable project logic, not as a fixed eternal formula.
