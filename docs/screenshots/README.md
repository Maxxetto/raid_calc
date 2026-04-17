# Screenshots

Questa cartella contiene le screenshot "ufficiali" del progetto che vogliamo
tenere allineate con la UI reale.

## Perche esiste

Nel workspace era presente `flutter_01.png` nella root del repo, ma:

- non e tracciata da Git
- e ignorata da `.gitignore` tramite il pattern `flutter_*.png`
- non e referenziata da codice o documentazione

Quindi va trattata come screenshot locale temporanea, non come source of truth.

## Convenzione consigliata

Usare nomi espliciti e tracciabili, ad esempio:

- `home_raid_android_2026-04-01.png`
- `results_raid_graph_view_android_2026-04-01.png`
- `bulk_compare_frontier_android_2026-04-01.png`

Formato consigliato:

- `<screen>_<variant>_<platform>_<yyyy-mm-dd>.png`

## Workflow minimo

1. Aprire la schermata reale nell'app.
2. Catturare una nuova screenshot dopo ogni change visiva importante.
3. Salvare la screenshot in questa cartella con il nome convenzionale.
4. Se una screenshot precedente e obsoleta, mantenerla solo se serve storico;
   altrimenti sostituirla con una nuova versione.

## Nota pratica

Per la Home screen il titolo app e stato accorciato a `Raid Calculator`, quindi
le prossime screenshot non dovrebbero piu mostrare il crop visto nella vecchia
`flutter_01.png`.
