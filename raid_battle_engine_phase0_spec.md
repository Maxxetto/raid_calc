# Raid Battle Engine Refactor - Phase 0 Spec

## Status

This document is the Phase 0 source of truth for the new skill-based Raid/Blitz
battle engine.

Goal of Phase 0:

- freeze the canonical behavior of the new engine
- remove ambiguity before implementation
- define a stable reference for Phase 1 and later migrations

This spec intentionally focuses on Raid/Blitz non-debug first.
Epic and Debug will be migrated later, but they must reuse the same battle
semantics.

---

## 1. Core Direction

The project is moving from a mode-driven simulation model to a single
battle-driven engine.

Key principle:

- there is only one real fight: the battle
- skills are cast or activated during the battle
- old "fight modes" are temporary compatibility shims only

Implications:

- `FightMode` must stop being the behavior source
- pet skills become battle components/effects
- the engine must support combinations of skills instead of mutually-exclusive
  simulation modes

---

## 2. Scope Of Phase 0

Phase 0 does not implement the new engine yet.

Phase 0 must:

- define the canonical turn order
- define pet bar scheduling rules
- define `PetSkillUsageMode` behavior
- define skill semantics, stacking, refresh and timing
- define the editable numeric parameter model
- define the temporary compatibility strategy from legacy `FightMode`

Phase 0 does not:

- remove legacy mode files
- change the production runtime path
- migrate Epic or Debug

---

## 3. Canonical Battle Model

### 3.1 Base battle rules

These rules remain unchanged from the current simulator:

- FIFO targeting remains unchanged
- boss and knight miss/crit/evasion rules remain unchanged
- stun rules remain unchanged
- knight special cadence remains driven by JSON timing values
- boss special cadence remains driven by JSON timing values

### 3.2 Canonical turn order

Normal combined knight+pet turn:

1. knight acts
2. pet performs a normal basic attack

Combined turn when a non-immediate pet cast is scheduled:

1. knight acts
2. pet casts the selected skill
3. pet does not perform its basic attack in the same turn

Combined turn when an immediate pet cast is scheduled:

1. knight acts
2. pet casts the selected skill
3. pet immediately hits in the same turn

Immediate pet-hit casts:

- `Shadow Slash`
- `Revenge Strike`
- `Vampiric Attack`
- `Leech Strike`

Non-immediate casts include, for example:

- `Elemental Weakness`
- `Special Regeneration`
- `Special Regeneration (inf)`
- `Shatter Shield`
- `Durable Rock Shield`
- `Death Blow`
- `Ready to Crit`
- `Fortune's Call`

### 3.3 Pet cast timing

Pet bar behavior:

- max capacity is 2 full charges
- any cast consumes the full bar
- cast happens on the next combined knight+pet turn after threshold is reached
- in the cast turn, the pet does not fill the bar by itself

Current temporary rule:

- when the pet casts, the knight still generates pet-bar charge
- the charge contribution from knight action is temporarily modeled as `1.0`
- this value must remain configurable in the engine implementation

---

## 4. Pet Skill Usage Policy

The engine must preserve the current `PetSkillUsageMode` values.

Canonical behavior:

- `special1Only`
  - always use slot 1
- `special2Only`
  - always use slot 2
- `cycleSpecial1Then2`
  - cyclic sequence `1, 2, 1, 2, ...`
- `special2ThenSpecial1`
  - use slot 2 once, then always slot 1
  - sequence `2, 1, 1, 1, ...`
- `doubleSpecial2ThenSpecial1`
  - use slot 2 twice, then always slot 1
  - sequence `2, 2, 1, 1, 1, ...`

Important:

- if both slots contain the same skill, they are still treated as distinct casts
- if bar theoretically reaches 2 charges while `special1Only` is selected, slot 1
  still casts and the whole bar is consumed

---

## 5. Cyclone Always-Gem Override

If `Cyclone Boost` is present in either slot and the user enables the
always-gem option:

- pet bar is ignored completely
- `PetSkillUsageMode` is ignored completely
- any non-Cyclone skill becomes unreachable during that battle
- the pet casts `Cyclone Boost` every knight turn
- the knight uses special every knight turn
- the boss still follows its normal special cadence

This is a hard override of the normal pet scheduling pipeline.

---

## 6. Skill Parameter Model

### 6.1 General rule

All numeric parameters of a selected/imported skill are editable by the user.

Examples:

- `Elemental Weakness`: reduction percent, turns
- `Durable Rock Shield`: defense boost percent, turns
- `Soul Burn`: damage over time, turns
- `Ready to Crit`: crit chance percent, turns
- `Cyclone Boost`: attack boost percent, turns
- `Shadow Slash`: pet attack
- `Revenge Strike`: pet attack cap

### 6.2 Three layers

Every skill used by the engine must be modeled through three layers:

- `baseValues`
  - values coming from compendium/import/manual default selection
- `overrideValues`
  - user-edited values saved in setup/session
- `effectiveValues`
  - final values used by simulation

Rule:

- `effectiveValues = overrideValues when present, else baseValues`

### 6.3 Zero means disabled

If a numeric parameter is set to `0` and that parameter drives the existence of
the effect, the effect is considered not applied.

Examples:

- `turns = 0` -> timed effect is not applied
- `flatDamage = 0` -> direct-damage component is disabled

### 6.4 UI implications

- skills with duration must expose an editable duration field
- skills without duration expose only the relevant numeric fields
- values must be persisted in setup/export/import
- results must show the effective values actually used in the battle

### 6.5 Cyclone turns

`Cyclone Boost.turns` is not just duration.

It also defines the max stack cap.

Examples:

- `turns = 5` -> stacks build up to 5
- `turns = 6` -> stacks build up to 6
- `turns = 12` -> stacks build up to 12

This replaces the previous hardcoded cap.

---

## 7. Canonical Skill Catalog

### 7.1 Canonical skills

The new engine must recognize these skill families:

- `Special Regeneration`
- `Special Regeneration (inf)`
- `Elemental Weakness`
- `Shatter Shield`
- `Durable Rock Shield`
- `Cyclone Boost`
- `Death Blow`
- `Shadow Slash`
- `Revenge Strike`
- `Ready to Crit`
- `Soul Burn`
- `Vampiric Attack`
- `Leech Strike`
- `Fortune's Call`

### 7.2 Naming aliases

Runtime aliases:

- `Special Regen` -> `Special Regeneration`
- `Cyclone Air Boost` -> `Cyclone Boost`
- `Cyclone Earth Boost` -> `Cyclone Boost`
- `Leech Strike` -> runtime alias of `Vampiric Attack`

Display names may remain distinct in some UI contexts, but engine behavior must
use canonical skill families.

---

## 8. Canonical Skill Semantics

### 8.1 Special Regeneration

Behavior:

- applies when cast
- targets the currently active knight
- effect is tracked globally in battle state and follows the active knight
- each cast creates its own timed instance
- duration is 5 knight turns by default
- multiple active instances stack additively

Current temporary simulation rule:

- instead of a true special-meter engine, SR reduces expected turns to knight
  special
- 1 stack halves the expected special cadence
- 2 stacks quarter it
- minimum cadence is 1

Long-term intent:

- keep hooks ready for future true meter-charge logic

### 8.2 Special Regeneration (inf)

Behavior:

- applies when cast
- stack count is global to the battle
- stack cap is 4
- stack amount depends on currently active knight match state

Rules:

- active knight matching pet elements: cast grants +2 stacks
- active knight not matching pet elements: cast grants +1 stack
- knight in match gains infinite knight special at 2+ global stacks
- knight not in match gains infinite knight special at 4 global stacks

`SR (inf)` overrides the usefulness of normal SR.
If both are present, `SR (inf)` is the behavior that matters for permanent
special spam.

### 8.3 Elemental Weakness

Behavior:

- applied by pet cast
- targets the boss
- each recast adds a separate instance
- duration is measured in boss turns
- boss miss does not consume duration
- boss stun skip does consume duration
- strong-element multiplier remains valid

### 8.4 Shatter Shield

Behavior:

- applied by pet cast
- targets the active knight at cast time
- grants flat HP/shield value
- remains on the knight that received it
- recasts add more HP to the same knight pool

### 8.5 Durable Rock Shield

Behavior:

- applied by pet cast
- targets the active knight at cast time
- creates timed defense buff instances
- recasts stack multiplicatively

### 8.6 Cyclone Boost

Behavior:

- applied by cast
- stack state is global to the battle
- stacks pass from one knight to the next if the current knight dies
- miss counts as a turn for Cyclone duration
- stun does not count as a Cyclone turn
- max stack count is driven by skill `turns`

### 8.7 Death Blow

Behavior:

- applies a pending knight-attack buff
- buff stacks
- one knight action consumes one pending stack
- special consumes one stack but does not receive the basic-hit bonus
- miss consumes one stack
- bonus applies only to a forced basic crit

### 8.8 Ready to Crit

Behavior:

- targets the active knight
- buff duration is measured on knight turns
- multiple casts create independent timed instances
- crit bonus stacks additively

### 8.9 Shadow Slash

Behavior:

- cast is immediate
- pet attacks in the same turn
- next pet hit uses fixed `petAttack`
- effect does not stack

### 8.10 Revenge Strike

Behavior:

- cast is immediate
- pet attacks in the same turn
- attack value is derived at hit time, not cast time
- ratio uses knight HP lost at the moment of the pet hit
- effect does not stack

### 8.11 Soul Burn

Behavior:

- no immediate damage on cast
- applies a DoT only
- DoT ticks immediately after each boss action
- does not stack
- recast refreshes duration and value

### 8.12 Vampiric Attack

Behavior:

- cast is immediate
- pet attacks in the same turn
- heal is a percentage of actual boss damage dealt

### 8.13 Leech Strike

Behavior:

- same runtime behavior as `Vampiric Attack`
- kept as distinct naming for data/UI purposes if needed

### 8.14 Fortune's Call

Behavior:

- applies a persistent gold-drop state
- only one active stack exists
- persists until battle end
- if the enemy dies during the battle, gold is dropped

---

## 9. Explicit Runtime Model

Phase 1 must introduce explicit runtime objects for battle effects.

The new engine must not hide long-lived effects in scattered local variables.

Required conceptual runtime entities:

- `BattleState`
- `PetBarState`
- `QueuedPetCast`
- `EffectInstance`
- `SkillDefinitionForBattle`
- `EffectiveSkillValues`

Every effect instance must carry enough data to express:

- canonical skill family
- source slot
- owner/target
- start timing
- remaining duration
- stacking model
- effective numeric values

---

## 10. Legacy Compatibility Strategy

`FightMode` remains temporarily visible in UI, but it is no longer a valid long-
term engine abstraction.

During migration:

- legacy setups may still contain `FightMode`
- a compatibility adapter must translate legacy mode information into a
  skill-based battle configuration
- this adapter is transitional and must be deleted at the end of the refactor

Examples of legacy mapping intent:

- old `SR + EW` mode -> equivalent skill-based scheduling/state
- old `Shatter Shield` mode -> equivalent skill-based configuration
- old `Cyclone Boost` mode -> equivalent `Cyclone Boost` state with optional
  always-gem override

The final engine must not rely on `FightMode`.

---

## 11. Phase 0 Deliverables

Phase 0 is complete when all of the following are true:

- the project has a written canonical spec for the new engine
- turn ordering is frozen
- pet bar semantics are frozen
- `PetSkillUsageMode` semantics are frozen
- every supported skill has a defined runtime meaning
- numeric overrides are formally defined
- temporary legacy compatibility strategy is defined

This document is the completion artifact for Phase 0.

---

## 12. Next Phase Entry Conditions

Phase 1 may start once implementation follows these rules:

- create `lib/core/engine/`
- do not remove legacy mode files yet
- build the new engine in parallel
- begin with Raid/Blitz non-debug only
- use explicit battle/effect runtime state from the start

