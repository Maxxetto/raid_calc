# Wishlist Features

Raccolta di possibili feature future per l'app.

Uso consigliato:

- quando una feature viene scelta per l'implementazione, spostarla in un piano dedicato oppure rimuoverla da qui;
- quando una feature non interessa piu, eliminarla;
- mantenere descrizioni brevi e orientate all'utente.

## Priorita alta (impatto utente)

- [ ] OCR party completo (knights + pet + boss)
  - Estendere l'import screenshot per leggere anche pet (ATK + elementi) e boss (livello + elementi), oltre ai cavalieri.
  - Obiettivo: ridurre drasticamente input manuale e tempi di setup.

- [ ] Confronto rapido setup A/B (senza bulk completo)
  - Schermata/flow veloce per confrontare 2 setup con delta su media, range atteso, punti/sec e metriche principali.
  - Utile per decisioni rapide senza lanciare un bulk con piu slot.

- [ ] Assist suggerimento abilita pet
  - Modalita guidata che testa automaticamente piu abilita pet (es. DRS/SS/EW) e suggerisce quella migliore.
  - Prima versione semplice: confronto su un set fisso di abilita.

- [ ] Storico risultati locale con tag/nome
  - Salvare risultati simulazioni (non solo setups) con nome/tag (es. "Raid L4 DRS water").
  - Permette confronti nel tempo e riduce simulazioni duplicate.

## Priorita media (qualita d'uso)

- [x] Condivisione setup/risultati (export/import)
  - Export/import JSON via clipboard per setup (Setups sheet) e risultati (Simulation Report / Utilities).
  - Include tips contestuali per spiegare il flow di condivisione/import.

- [ ] Preset rapidi boss / recenti / preferiti
  - Accesso rapido a boss usati spesso o ultimi selezionati.
  - Riduce input ripetitivo in Home.

- [ ] Warning intelligenti / validazioni avanzate
  - Esempi: valori OCR improbabili, combinazioni non supportate, campi incoerenti.
  - Obiettivo: prevenire errori silenziosi.

- [ ] ETA simulazione (tempo stimato rimanente)
  - Mostrare stima del tempo residuo durante simulazioni lunghe.
  - Utile soprattutto con runs elevati e bulk simulate.

## Power users / Premium oriented

- [ ] Batch optimizer di combinazioni
  - Data una rosa di cavalieri/pet/abilita, testare combinazioni e proporre le migliori.
  - Feature ad alto valore ma piu costosa lato performance/UX.

- [ ] Metriche avanzate di distribuzione
  - Percentili (p10/p50/p90), probabilita di superare una soglia, misure di consistenza.
  - Aiuta a scegliere setup stabili vs setup ad alto picco.

- [ ] Profili multipli (account/loadout separati)
  - Profili locali separati (main/alt/etc.) con stati e setup indipendenti.
  - Utile per utenti che gestiscono piu account.

## Quick wins UX (semplici ma utili)

- [x] Nomi personalizzati per i setup (hotswap)
  - Invece di solo Slot 1/2/3, supportare nomi come "Raid L4 SS" o "Blitz DRS Water".

- [x] Duplica setup / clone slot
  - Requisiti UX gia definiti (source of truth per futura implementazione).
  - Copiare uno slot in un altro per modificare solo 1-2 parametri.
  - Se lo slot destinazione e gia occupato: richiedere conferma overwrite con riepilogo.
  - Dopo aver scelto il clone, chiedere un nuovo nome al setup (non duplicare il nome con suffisso automatico).
  - Utile insieme a hotswap/bulk per testare varianti rapide (es. stessa base con abilita pet diversa).

- [ ] Preferenze sticky / lock campi
  - Mantenere alcuni parametri preferiti tra sessioni (es. runs, boss mode, toggles specifici).

- [x] Tooltip / mini guida in-app
  - Tips contestuali aggiunte nelle sezioni principali (Home, Results, War) per onboarding e spiegazioni rapide.

## Note per futura selezione

- Criteri suggeriti per prioritizzare:
  - impatto reale sull'utente (tempo risparmiato / errori evitati),
  - complessita implementativa,
  - rischio regressioni,
  - riuso del codice gia presente (OCR, setups, bulk, results).
