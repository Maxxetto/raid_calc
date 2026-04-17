from __future__ import annotations

import json
import re
from collections import Counter
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
LANGS_DIR = ROOT / "assets" / "langs"
OUTPUT = ROOT / "LOCALIZATION_STATUS.md"
DETAILS_OUTPUT = ROOT / "tool" / "i18n_reports" / "untranslated_keys.json"

PREFIX_PRIORITY = [
    "premium",
    "nav",
    "boss",
    "pet",
    "knights",
    "wargear",
    "war",
    "raid_guild",
    "pet_compendium",
    "app_features",
    "news",
    "ua_planner",
    "results",
    "setups",
    "friend_codes",
    "debug",
]

P0_PREFIXES = ["premium", "nav", "boss", "pet", "knights", "wargear"]
INTENTIONAL_SHARED_EXACT = {
    "ATK",
    "DEF",
    "HP",
    "Premium",
    "Raid",
    "Blitz",
    "Epic",
    "UA",
    "UA Planner",
    "Arena",
    "Boss",
    "Comm",
    "GM",
    "HC",
    "GS / GC",
    "Element",
    "Role",
    "Score",
    "Pet",
    "Season",
    "Version: +",
    "{family} | {tier} | {profile} | 1: {skill1} | 2: {skill2}",
    "PA",
    "N",
    "-",
    "EU",
    "Global",
    "Base",
    "Normal",
    "Strip",
    "Frenzy",
    "bonus",
    "Slot",
    "Server",
    "Level",
    "Nickname",
    "pack",
    "packs",
    "Packs",
    "Fav",
    "K1",
    "K2",
    "K3",
    "INF",
    "OK",
    "FAQ",
    "Starmetal",
    "Arcade",
    "Aurora",
    "Ocean",
    "Orange",
    "Cyclone Boost",
    "Durable Rock Shield",
    "Shatter Shield",
    "Wargear Wardrobe",
    "Universal Armor Score",
    "Wardrobe Simulate",
    "SR + EW",
    "Bulk Simulate",
    "ON",
    "OFF",
    "min",
    "max",
    "Elixir",
    "Elite",
    "Elite+",
    "Total",
    "Standard",
    "Base + Plus",
}
INTENTIONAL_SHARED_EXACT_BY_LANG = {
    "da": {"April", "August", "December", "November", "Parameter", "Platform", "September", "Shatter:", "Start", "Version", "median"},
    "de": {"April", "August", "November", "Parameter", "September"},
    "es": {"Manual", "No"},
    "it": {"No"},
    "fr": {"Air", "pts"},
    "nl": {"April", "December", "November", "Parameter", "Platform", "September", "Water"},
    "tr": {"Platform"},
}
INTENTIONAL_SHARED_PATTERN = re.compile(
    r"^[0-9][0-9., /+|:{}_-]*$"
)
INTENTIONAL_SHARED_EXTRA_PATTERNS = (
    re.compile("^Boss \u2192 K[1-3]$"),
)


def prefix_for(key: str) -> str:
    if "." in key:
        return key.split(".", 1)[0]
    return key.split("_", 1)[0]


def load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def is_intentionally_shared(lang: str, value: str) -> bool:
    stripped = value.strip()
    if stripped in INTENTIONAL_SHARED_EXACT:
        return True
    if stripped in INTENTIONAL_SHARED_EXACT_BY_LANG.get(lang, set()):
        return True
    if INTENTIONAL_SHARED_PATTERN.fullmatch(stripped):
        return True
    if any(pattern.fullmatch(stripped) for pattern in INTENTIONAL_SHARED_EXTRA_PATTERNS):
        return True
    return False


def build_details(
    *,
    lang: str,
    data: dict,
    en: dict,
) -> dict[str, object]:
    missing: list[dict[str, str]] = []
    same_as_en: list[dict[str, str]] = []
    intentional_shared: list[dict[str, str]] = []
    localized = 0
    sections = Counter()

    for key, en_value in en.items():
        prefix = prefix_for(key)
        value = data.get(key)
        if not isinstance(value, str) or value == "":
            sections[prefix] += 1
            missing.append(
                {
                    "key": key,
                    "prefix": prefix,
                    "english": en_value,
                }
            )
            continue
        if lang != "en" and value == en_value:
            if is_intentionally_shared(lang, en_value):
                intentional_shared.append(
                    {
                        "key": key,
                        "prefix": prefix,
                        "english": en_value,
                    }
                )
                continue
            sections[prefix] += 1
            same_as_en.append(
                {
                    "key": key,
                    "prefix": prefix,
                    "english": en_value,
                }
            )
            continue
        localized += 1

    return {
        "missing": len(missing),
        "same_as_en": len(same_as_en),
        "intentional_shared": len(intentional_shared),
        "localized": localized,
        "total": len(en),
        "sections": dict(sorted(sections.items())),
        "missing_keys": missing,
        "same_as_en_keys": same_as_en,
        "intentional_shared_keys": intentional_shared,
    }


def write_details_json(details: dict[str, object]) -> None:
    DETAILS_OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    DETAILS_OUTPUT.write_text(
        json.dumps(details, ensure_ascii=True, indent=2) + "\n",
        encoding="utf-8",
    )


def main() -> None:
    en = load_json(LANGS_DIR / "en.json")
    langs = [
        p.stem
        for p in sorted(LANGS_DIR.glob("*.json"))
        if p.name != "manifest.json"
    ]

    summaries: dict[str, dict[str, object]] = {}
    aggregate = Counter()
    details_payload: dict[str, object] = {
        "generatedAtUtc": utc_now_iso(),
        "source": "assets/langs/en.json",
        "totalKeys": len(en),
        "langs": {},
    }

    for lang in langs:
        data = load_json(LANGS_DIR / f"{lang}.json")
        summary = build_details(lang=lang, data=data, en=en)
        summaries[lang] = summary
        details_payload["langs"][lang] = summary
        if lang != "en":
            aggregate.update(summary["sections"])

    write_details_json(details_payload)

    lines = [
        "# Localization Status",
        "",
        "Questo file e uno snapshot operativo della copertura i18n rispetto a `assets/langs/en.json`.",
        "",
        "Definizioni:",
        "- `missing`: chiavi assenti o vuote",
        "- `same_as_en`: chiavi ancora uguali all'inglese e non classificate come termini tecnici intenzionalmente invariati",
        "- `intentional_shared`: chiavi identiche a EN ma ammesse come invarianti (es. `Premium`, `ATK`, `UA`, sequenze numeriche delle skill)",
        "- `localized`: chiavi presenti e diverse da EN",
        "",
        "Nota:",
        "- termini come `Premium`, `ATK`, `DEF`, `HP`, `Raid`, `Blitz`, `Epic`, `UA` possono restare invariati quando e sensato",
        "- questo report serve per priorita operative, non come giudizio assoluto di qualita linguistica",
        "",
        "Dettaglio machine-readable:",
        f"- `{DETAILS_OUTPUT.relative_to(ROOT).as_posix()}`",
        "",
        "## Per Lingua",
        "",
        "| Lang | Missing | Same as EN | Intentional Shared | Localized | Total |",
        "|---|---:|---:|---:|---:|---:|",
    ]

    for lang in langs:
        s = summaries[lang]
        lines.append(
            f"| {lang} | {s['missing']} | {s['same_as_en']} | {s['intentional_shared']} | {s['localized']} | {s['total']} |"
        )

    lines.extend(
        [
            "",
            "## Sezioni Piu Scoperte (aggregate, escl. EN)",
            "",
            "| Prefix | Non-localized keys |",
            "|---|---:|",
        ]
    )

    for prefix, count in aggregate.most_common(20):
        lines.append(f"| {prefix} | {count} |")

    lines.extend(
        [
            "",
            "## Priorita Operativa",
            "",
            "P0:",
            "- `premium`, `nav`, `boss`, `pet`, `knights`, `wargear`",
            "",
            "P1:",
            "- `war`, `raid_guild`, `pet_compendium`, `app_features`",
            "",
            "P2:",
            "- `news`, `setups`, `friend_codes`, `results`",
            "",
            "P3:",
            "- `ua_planner`, `debug`",
            "",
            "## Ordine Lingue Consigliato",
            "",
            "1. `fr`, `es`, `de`, `nl`, `da`",
            "2. `tr`, `pl`",
            "3. `ar`, `ru`, `zh`, `ja`",
            "",
            "## Focus P0 Per Lingua",
            "",
            "| Lang | premium | nav | boss | pet | knights | wargear | total P0 |",
            "|---|---:|---:|---:|---:|---:|---:|---:|",
        ]
    )

    for lang in langs:
        if lang == "en":
            continue
        sections = summaries[lang]["sections"]
        values = [int(sections.get(prefix, 0)) for prefix in P0_PREFIXES]
        lines.append(
            f"| {lang} | {values[0]} | {values[1]} | {values[2]} | {values[3]} | {values[4]} | {values[5]} | {sum(values)} |"
        )

    OUTPUT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"Wrote {OUTPUT}")
    print(f"Wrote {DETAILS_OUTPUT}")


if __name__ == "__main__":
    main()
