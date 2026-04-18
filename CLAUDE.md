# CLAUDE.md

Istruzioni operative per Claude Code nel repo `raid_calc`.

Questo file è analogo a `AGENTS.md` e lo completa per il workflow con Claude.
Per contesto generale e mappa della documentazione, fare riferimento anche a `guidelines.md`.
Se una regola di questo file entra in conflitto con `AGENTS.md`, prevale `AGENTS.md`.

## Working agreements

## Scope

- Flutter/Dart app per workflow raid, blitz, epic, war, UA, pet e wargear.
- Obiettivo principale: implementare e aggiungere nuove feature o migliorie in modo seamless, senza rompere comportamento esistente, gating Premium o formati dati attivi.
- Mantenere i diff piccoli, mirati e verificabili.
- Evitare refactor speculativi se non richiesti dal task.

## Ownership map

- `lib/core/`: battle runtime, simulation engine, isolate e modelli core
- `lib/data/`: loader, storage, planner, scoring e resolver
- `lib/ui/`: pagine, sheet e widget
- `lib/premium/`: entitlement e integrazione RevenueCat
- `assets/`: dataset, cataloghi statici e asset i18n
- `tool/`: audit, generator e script operativi
- `test/`: test unit, widget e integrity checks

## Read first

- `AGENTS.md`: regole operative stabili e fast path di lavoro
- `guidelines.md`: mappa dei documenti e source of truth del repo
- `PRE_EDIT_TEXT_PROTOCOL.md`: da leggere prima di toccare `.md`, traduzioni o testo utente
- `app_features.md`: da mantenere allineato a `lib/ui/home/app_features_sheet.dart` quando cambiano help card o feature card

## Commands

- Setup: `flutter pub get`
- Analyze: `flutter analyze`
- Full tests: `flutter test`
- Text audit: `python tool/text_encoding_audit.py`

## Non-negotiables

- Tenere tutti i file testuali in UTF-8.
- Se si toccano copy, traduzioni o markdown, eseguire l'encoding audit prima e dopo.
- Se si aggiunge o modifica una stringa utente, aggiornare tutti i file `assets/langs/*.json` elencati in `assets/langs/manifest.json` nello stesso change set.
- Non affidarsi a fallback runtime EN/IT per nuove chiavi: i file lingua devono restare completi subito.
- Non aggiungere dipendenze senza una necessità chiara.
- Non modificare file non correlati durante task focalizzati.
- Aggiornare documentazione e test quando cambia comportamento, copy o contratto dati.
- Mantenere `app_features.md` allineato con `lib/ui/home/app_features_sheet.dart`.
- Preservare il gating Premium corrente salvo richiesta esplicita di cambiarlo.
- Preservare i formati dati attivi in `assets/` salvo richiesta esplicita o necessità strettamente legata al task.

## Default execution model

1. Identificare prima il layer proprietario: `lib/ui`, `lib/data`, `lib/core` oppure `assets`.
2. Leggere i file coinvolti e capire i flussi esistenti prima di modificare.
3. Applicare il diff minimo corretto.
4. Verificare che la nuova feature o miglioria si integri senza regressioni evidenti su UX, gating, storage e asset.
5. Eseguire i test o check più pertinenti alla modifica.
6. Dichiarare esplicitamente eventuali verifiche non eseguite.

## Fast paths

### Feature work

1. Identificare il layer proprietario.
2. Editare solo i file strettamente necessari.
3. Se cambia testo utente, aggiornare `assets/langs/*.json`.
4. Se cambia una help card o feature card, aggiornare `app_features.md`.
5. Verificare in modo mirato la superficie toccata per evitare regressioni.

### Wargear UAS

- Trattare l'Universal Armor Score visibile all'utente come `armor-only` di default.
- Mantenere `pet-aware` come variante contestuale opzionale.
- Conservare la separazione tra pesi stabili delle stat e modificatori situazionali come pet skill, usage e stun.
- Candidate pruning e ranking iniziale Wardrobe devono restare `armor-only` salvo richiesta esplicita diversa.

### Pet compendium updates from screenshots

- Estrarre: nome pet, rarity, `familyTag`, tier, level, elementi, stats, nomi skill e valori skill.
- Aggiornare l'indice di rarity corretto più `assets/pet_compendium_compact_library.json`.
- Riutilizzare `statsProfile`, `skillPayload` e `skillSet` quando i valori coincidono.
- Mantenere una sola versione canonica per tier e preferire il livello più alto disponibile.
- Verificare con:

```bash
flutter test test/pet_compendium_loader_test.dart test/pet_compendium_loader_consistency_test.dart test/pet_compendium_compact_integrity_test.dart
```

### Wargear updates from screenshots

- Estrarre: base name, `seasonTag`, elementi, stat normali, bonus normali, eventuali plus stats e eventuali outlier jewelry.
- Cercare prima il nome armor per capire se va aggiornata in place.
- Editare `assets/wargear_wardrobe.json`.
- Tenere una sola entry per armor; i dati `+` vanno nello stesso record.
- Non inventare valori plus o jewelry mancanti.

#### Stats compact vector format

```json
"stats": [base_atk, base_def, setBonus_atk, setBonus_def, setBonus_health,
           plus_atk, plus_def, plus_setBonus_atk, plus_setBonus_def, plus_setBonus_health]
```

- 5 valori: solo normal.
- 10 valori: normal + plus.
- `setBonus_atk` e `setBonus_def` sono 0 fino a S116 incluso; non-zero da S117 in poi.

#### Jewelry vector

- Se ring e amulet coincidono con la tabella globale derivata dagli elementi, non aggiungere `jewelry`.
- Altrimenti usare:

```json
"jewelry": [ring_atk, ring_hp, amulet_atk, amulet_hp, ring_atk, ring_hp, amulet_atk, amulet_hp]
```

- Salvo evidenza diversa, i valori normal e plus coincidono anche nel vettore jewelry.

#### Season bucket behavior

- `S117`, `S117RB` e `S117GW` ricadono tutti nel bucket `"S117"` per i test filtro stagione.

#### Test count updates required after new armor entries

- `test/wargear_wardrobe_loader_test.dart`: incrementare `catalog.armors.length` di 1.
- `test/wargear_wardrobe_sheet_test.dart`: incrementare `"N armor sets found"` per il bucket stagione corretto.

#### Verify with

```bash
flutter test test/wargear_wardrobe_loader_test.dart test/wargear_wardrobe_sheet_test.dart test/wargear_favorites_storage_test.dart
```

- Aggiungere `test/home_page_widget_test.dart` se è stato toccato il flow Home.

### Results UI updates

- Mantenere l'ordine top-level: `Performance Summary`, `Battle Context`, `Pet & Mode`, `Knights`, `Advanced Details`.
- Mettere i dati overview all'inizio, i dettagli per knight nelle card, e i dettagli più verbosi o tecnici in `Advanced Details`.
- Classificare ogni chart o metrica Results/Bulk come `score-only` oppure `premium-timing`.
- Ogni chart o metrica che usa `stats.timing` o valori derivati dal tempo resta Premium-only.
- Fuori dalla sezione Timing, i contenuti time-based non disponibili vanno nascosti, non sostituiti con lock card extra.
- Quando si modifica Results/Bulk UI, aggiornare anche i test del Premium gating.
- Verificare con:
  - `flutter test test/results_page_widget_test.dart`
  - `flutter test test/bulk_results_page_test.dart` se il bulk output può cambiare

### Text, i18n and markdown edits

- Leggere `PRE_EDIT_TEXT_PROTOCOL.md` prima di modifiche rischiose su testo.
- Eseguire prima e dopo:
  - `python tool/text_encoding_audit.py`
- Dopo modifiche a testo o markdown, eseguire anche:
  - `flutter test test/i18n_test.dart`
  - `flutter test test/text_assets_encoding_test.dart`
- Considerare `assets/langs/*.json` più `assets/langs/manifest.json` come source of truth, senza ricompattare i file in un asset unico.

## What seamless means here

- Le nuove feature devono innestarsi sui flussi esistenti senza rompere navigazione, persistenza, gating o asset.
- Le migliorie devono preservare semantica e ordering delle superfici già consolidate, salvo task esplicito.
- Quando una modifica ha rischio laterale, preferire integrazioni incrementali, guardrail nei test e verifiche mirate invece di ristrutturazioni ampie.
- Se il workspace contiene cambi già presenti ma non pertinenti, non toccarli e non ripulirli.

## Definition of done

- È in place il diff più piccolo corretto.
- I test o check pertinenti sono stati eseguiti, oppure quelli saltati sono dichiarati esplicitamente.
- Docs o asset sono stati aggiornati se cambiano comportamento, copy o contratti dati.
- Non sono state introdotte istruzioni stale, drift documentale o regressioni ovvie.
