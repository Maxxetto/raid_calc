# Localization Status

Questo file e uno snapshot operativo della copertura i18n rispetto a `assets/langs/en.json`.

Definizioni:
- `missing`: chiavi assenti o vuote
- `same_as_en`: chiavi ancora uguali all'inglese e non classificate come termini tecnici intenzionalmente invariati
- `intentional_shared`: chiavi identiche a EN ma ammesse come invarianti (es. `Premium`, `ATK`, `UA`, sequenze numeriche delle skill)
- `localized`: chiavi presenti e diverse da EN

Nota:
- termini come `Premium`, `ATK`, `DEF`, `HP`, `Raid`, `Blitz`, `Epic`, `UA` possono restare invariati quando e sensato
- questo report serve per priorita operative, non come giudizio assoluto di qualita linguistica

Dettaglio machine-readable:
- `tool/i18n_reports/untranslated_keys.json`

## Per Lingua

| Lang | Missing | Same as EN | Intentional Shared | Localized | Total |
|---|---:|---:|---:|---:|---:|
| ar | 3 | 972 | 108 | 66 | 1149 |
| da | 0 | 6 | 101 | 1042 | 1149 |
| de | 0 | 2 | 77 | 1070 | 1149 |
| en | 0 | 0 | 0 | 1149 | 1149 |
| es | 0 | 0 | 55 | 1094 | 1149 |
| fr | 0 | 4 | 74 | 1071 | 1149 |
| it | 0 | 4 | 81 | 1064 | 1149 |
| ja | 3 | 974 | 109 | 63 | 1149 |
| nl | 0 | 3 | 71 | 1075 | 1149 |
| pl | 0 | 2 | 96 | 1051 | 1149 |
| ru | 0 | 450 | 97 | 602 | 1149 |
| tr | 0 | 7 | 94 | 1048 | 1149 |
| zh | 3 | 974 | 108 | 64 | 1149 |

## Sezioni Piu Scoperte (aggregate, escl. EN)

| Prefix | Non-localized keys |
|---|---:|
| app_features | 428 |
| results | 388 |
| ua_planner | 320 |
| debug | 229 |
| news | 224 |
| wargear | 204 |
| war | 171 |
| raid_guild | 158 |
| setups | 140 |
| premium | 136 |
| pet_compendium | 127 |
| pet | 93 |
| knights | 78 |
| durations | 63 |
| boss | 48 |
| utilities | 44 |
| pet_skill | 42 |
| elixirs | 36 |
| theme | 36 |
| epic | 33 |

## Priorita Operativa

P0:
- `premium`, `nav`, `boss`, `pet`, `knights`, `wargear`

P1:
- `war`, `raid_guild`, `pet_compendium`, `app_features`

P2:
- `news`, `setups`, `friend_codes`, `results`

P3:
- `ua_planner`, `debug`

## Ordine Lingue Consigliato

1. `fr`, `es`, `de`, `nl`, `da`
2. `tr`, `pl`
3. `ar`, `ru`, `zh`, `ja`

## Focus P0 Per Lingua

| Lang | premium | nav | boss | pet | knights | wargear | total P0 |
|---|---:|---:|---:|---:|---:|---:|---:|
| ar | 34 | 3 | 16 | 31 | 26 | 51 | 161 |
| da | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| de | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| es | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| fr | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| it | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| ja | 34 | 3 | 16 | 31 | 26 | 51 | 161 |
| nl | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| pl | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| ru | 34 | 0 | 0 | 0 | 0 | 51 | 85 |
| tr | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| zh | 34 | 3 | 16 | 31 | 26 | 51 | 161 |
