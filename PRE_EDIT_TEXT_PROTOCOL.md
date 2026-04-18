# Pre-Edit Text Protocol

Questo file va consultato prima di modificare:

- `assets/langs/*.json`
- documentazione `.md`
- qualunque testo utente mostrato in app

## Obiettivo

Evitare in modo rigoroso ogni regressione di encoding come:

- `è` -> `Ã¨`
- `—` -> `â€”`
- `∞` -> `âˆž`
- caratteri sostituiti con `?` o `�`

## Regole Obbligatorie

1. Tutti i file testo devono restare in UTF-8.
2. Non usare editor o script che salvano in cp1252 / latin1.
3. Prima di toccare traduzioni o documentazione, eseguire:

```bash
python tool/text_encoding_audit.py
```

4. Dopo le modifiche, rieseguire:

```bash
python tool/text_encoding_audit.py
flutter test test/i18n_test.dart
flutter test test/text_assets_encoding_test.dart
```

5. Se l'audit trova mojibake, riparare prima di continuare:

```bash
python tool/text_encoding_audit.py --fix
```

6. Non introdurre workaround locali sparsi per stringhe corrotte. La source of truth è:
   - `lib/util/text_encoding_guard.dart`
   - `tool/text_encoding_audit.py`

## Note Operative

- Il loader i18n ripara in runtime le stringhe evidentemente corrotte, ma questo è solo un paracadute: i file devono comunque restare puliti su disco.
- Se compare anche un solo `Ã`, `Â`, `â€`, `ðŸ`, `�`, fermarsi e lanciare l'audit.
- Per testi multilingua, preferire patch su file UTF-8 e non editing via terminale con codepage ambigua.
- Non fidarsi della sola resa di `Get-Content` o della console PowerShell: se la codepage del terminale è sbagliata, il file può sembrare corrotto anche quando è UTF-8 corretto. La verifica vera è sempre:
  - `python tool/text_encoding_audit.py`
  - `flutter test test/i18n_test.dart`
  - `flutter test test/text_assets_encoding_test.dart`
