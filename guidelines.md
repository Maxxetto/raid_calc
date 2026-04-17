# Raid Calculator Guidelines

Questo file e la mappa umana della documentazione del repo.

- `AGENTS.md` contiene le istruzioni operative per Codex e gli altri agent.
- `guidelines.md` resta il riferimento compatto per capire dove sta la verita del progetto e quali documenti usare.

## 1. Snapshot del progetto

`Raid Calculator` e una app Flutter/Dart per simulazioni Raid, Blitz, Epic e per strumenti collegati come War, UA Planner, Friend Codes, News, pet workflows e Wargear Wardrobe.

Aree principali del repo:

- `lib/core/`: engine di simulazione, runtime battle, isolate e modelli core
- `lib/data/`: loader asset, storage, planner math, scoring e resolver
- `lib/ui/`: app shell, pagine, sheet e componenti Home/Results
- `lib/premium/`: RevenueCat, entitlement e gating Premium
- `assets/`: dataset gameplay, i18n split assets e cataloghi statici
- `tool/`: audit, report generator e script operativi
- `test/`: test unit, widget, integrazione e integrity checks

Asset chiave attuali:

- `assets/sim_rules.json`
- `assets/pet_bar_rules.json`
- `assets/knight_bar_rules.json`
- `assets/boss_tables.json`
- `assets/elixirs.json`
- `assets/war_points.json`
- `assets/events.json`
- `assets/ocr_defaults.json`
- `assets/pet_compendium_compact_index_three_star.json`
- `assets/pet_compendium_compact_index_four_star.json`
- `assets/pet_compendium_compact_index_five_star.json`
- `assets/pet_compendium_compact_index_primal.json`
- `assets/pet_compendium_compact_index_shadowforged.json`
- `assets/pet_compendium_compact_library.json`
- `assets/pet_skill_definitions.json`
- `assets/pet_skill_semantics.json`
- `assets/wargear_wardrobe.json`
- `assets/langs/*.json` con indice in `assets/langs/manifest.json`

## 2. Mappa dei markdown

Documenti attivi e operativi:

- `AGENTS.md`
  - istruzioni persistenti per agent, comandi di verifica e workflow rapidi
- `README.md`
  - quickstart del repo e mappa minima delle directory
- `app_features.md`
  - source of truth editoriale per le help cards delle app features
  - va mantenuto allineato con `lib/ui/home/app_features_sheet.dart`
- `PRE_EDIT_TEXT_PROTOCOL.md`
  - protocollo anti-mojibake per testi, traduzioni e `.md`
- `LOCALIZATION_STATUS.md`
  - snapshot generato da `tool/localization_status_report.py`
- `wargear_scoring_parameters.md`
  - riferimento analitico per capire il razionale dietro al runtime scoring armor
- `docs/screenshots/README.md`
  - naming e workflow per screenshot ufficiali

Documenti tecnici utili ma non da trattare come istruzioni globali:

- `raid_battle_engine_phase0_spec.md`
  - spec e decision history del refactor engine
- `raid_config_split_plan.md`
  - piano storico dello split config/assets
- `raid_results_charts_proposal.md`
  - proposta e stato di rollout dei grafici Results
- `sim_calibrator_plan.md`
  - piano per un calibratore offline, non ancora parte del flusso standard
- `wishlistfeatures.md`
  - backlog leggero di idee prodotto

Regola pratica:

- se un file descrive il modo corrente di lavorare sempre, va in `AGENTS.md` o qui
- se un file descrive una singola iniziativa, spec o piano, resta documento dedicato
- se un piano e completamente superato, puo essere spostato in `docs/archive/` in un secondo pass

## 3. Regole stabili del repo

- Evitare refactor non richiesti: il repo e ampio e in movimento.
- Le modifiche devono restare minime, mirate e verificabili.
- Le feature Premium devono continuare a rispettare il gating attuale.
- Le traduzioni restano split in `assets/langs/*.json`; non tornare a un file unico.
- `app_features.md` non e opzionale: quando cambiano le cards o i fallback della relativa sheet, va aggiornato.
- I documenti generati, come `LOCALIZATION_STATUS.md`, non vanno editati a mano se esiste gia uno script che li produce.

## 4. Workflow rapidi consigliati

### 4.1 Nuova feature o modifica funzionale

Usare questo ordine mentale:

1. identificare il layer proprietario:
   - `lib/ui` per layout, fogli, pagine, copy e UX
   - `lib/data` per loader, storage, mapping asset e logica dominio
   - `lib/core` per runtime ed engine
   - `assets` per dataset e configurazioni
2. toccare solo i file strettamente necessari
3. aggiornare testi, traduzioni e test se il comportamento utente cambia
4. aggiornare `app_features.md` se cambia una help card o se nasce una nuova feature-card

### 4.2 Aggiungere pet da screenshot

Workflow rapido corretto:

1. Estrarre dallo screenshot:
   - nome pet
   - rarity
   - `familyTag` se presente
   - tier
   - level mostrato
   - elementi
   - stats
   - nomi skill
   - valori skill
2. Individuare la family corretta:
   - aggiornare family esistente se il pet appartiene gia a quella linea
   - creare nuova family solo se davvero assente
3. Aggiornare l'indice giusto:
   - `three_star`, `four_star`, `five_star`, `primal` o `shadowforged`
4. Aggiornare `assets/pet_compendium_compact_library.json`:
   - riusare `statsProfile` se i numeri coincidono
   - riusare `skillPayload` se `name + values` coincidono
   - riusare `skillSet` se la tripletta dei tre slot coincide
5. Mantenere una sola versione canonica per tier:
   - preferire il profilo di livello piu alto disponibile
6. Verificare con:
```
flutter test test/pet_compendium_loader_test.dart test/pet_compendium_loader_consistency_test.dart test/pet_compendium_compact_integrity_test.dart
```

### 4.3 Aggiungere armor da screenshot

Workflow rapido corretto:

1. Estrarre dallo screenshot: nome base, `seasonTag`, elementi, blocco normal, bonus normal, eventuale plus e bonus plus, eventuale jewelry custom per outlier.
2. Verificare se l'armor esiste gia: cercare il nome in `assets/wargear_wardrobe.json` — in quel caso aggiornare in place, non duplicare.
3. Aggiornare `assets/wargear_wardrobe.json` con il template seguente:

```json
{
  "id": "lowercase_snake_case",
  "name": "Title Case Name",
  "seasonTag": "S###",
  "elements": ["fire", "air"],
  "stats": [
    BASE_ATK, BASE_DEF, SETBONUS_ATK, SETBONUS_DEF, SETBONUS_HP,
    PLUS_ATK, PLUS_DEF, PLUS_SETBONUS_ATK, PLUS_SETBONUS_DEF, PLUS_SETBONUS_HP
  ]
}
```

Formato `stats`: `[base_atk, base_def, setBonus_atk, setBonus_def, setBonus_health]` x 2 (normal + plus). Omettere i 5 valori plus se non esiste la variante `+`. `setBonus_atk/def` sono 0 per S116 e precedenti, non-zero da S117 in poi.

4. Decidere se serve il campo `jewelry`:

Tabella global ring (atk/hp): fire 951/209 · spirit 504/318 · earth 729/268 · air 911/233 · water 866/248

Tabella global amulet (atk/hp): fire 911/233 · spirit 273/343 · earth 639/293 · air 866/248 · water 821/258

Se ring == `ringBonuses[elements[0]]` e amulet == `amuletBonuses[elements[1]]` → nessun `jewelry`. Altrimenti aggiungere:
```json
"jewelry": [ring_atk, ring_hp, amulet_atk, amulet_hp, ring_atk, ring_hp, amulet_atk, amulet_hp]
```

5. Mantenere una sola entry per armor; la variante `+` va nello stesso record. Non inventare valori mancanti.

6. Aggiornare i test (obbligatorio dopo ogni nuova armor):
   - `test/wargear_wardrobe_loader_test.dart`: `catalog.armors.length` +1
   - `test/wargear_wardrobe_sheet_test.dart`: `"N armor sets found"` per il bucket della stagione +1
   - Nota bucket: S117, S117RB, S117GW → tutti bucket "S117" (la funzione raggruppa per numero)

7. Verificare con:
```
flutter test test/wargear_wardrobe_loader_test.dart test/wargear_wardrobe_sheet_test.dart test/wargear_favorites_storage_test.dart
```

### 4.4 Results UI

La Results page deve restare leggibile e non tornare al clutter.

Ordine canonico ad alto livello:

1. `Performance Summary`
2. `Battle Context`
3. `Pet & Mode`
4. `Knights`
5. `Advanced Details`

Regola pratica:

- overview nei primi tre blocchi
- dettagli per-cavaliere nelle card `Knights`
- dettagli tecnici o verbosi dentro `Advanced Details`

Test minimi quando la Results UI cambia:

- `flutter test test/results_page_widget_test.dart`
- `flutter test test/bulk_results_page_test.dart` se il bulk puo essere impattato

### 4.5 Testi, traduzioni e documentazione

Prima di toccare testi utente o `.md`:

- leggere `PRE_EDIT_TEXT_PROTOCOL.md`
- eseguire `python tool/text_encoding_audit.py`

Dopo le modifiche:

- `python tool/text_encoding_audit.py`
- `flutter test test/i18n_test.dart`
- `flutter test test/text_assets_encoding_test.dart`

## 5. Cosa resta fuori da questo file

Questo file non prova piu a duplicare:

- l'intera spec dell'engine
- tutto il dettaglio storico dei rollout
- ogni singola regola di una singola feature

Se una regola e duratura e ricorrente, sta in `AGENTS.md`.
Se e una reference tecnica di dominio, resta nel markdown dedicato.
Se e una decision history superata, puo essere archiviata.

## 6. Secondo pass consigliato

Dopo questo riordino, il pass naturale successivo e:

1. spostare in `docs/archive/` i piani ormai eseguiti o chiusi
2. tenere in root solo i markdown attivi davvero usati nel day-to-day
3. creare eventuali `AGENTS.md` piu specifici solo se una sottocartella sviluppa regole realmente diverse dal root
