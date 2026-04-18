from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TARGETS = [
    ROOT / "assets" / "langs",
    ROOT / "AGENTS.md",
    ROOT / "guidelines.md",
    ROOT / "app_features.md",
    ROOT / "wargear_scoring_parameters.md",
]

SUSPICIOUS_FRAGMENTS = (
    "\uFFFD",
    "Ã",
    "Â",
    "â€",
    "â†’",
    "â€™",
    "â€œ",
    "â€�",
    "â€“",
    "â€”",
    "â€¦",
    "âˆž",
    "ðŸ",
)

CP1252_ENCODINGS = ("latin1", "cp1252")


def iter_target_files(paths: list[Path]) -> list[Path]:
    files: list[Path] = []
    for path in paths:
        if path.is_dir():
            files.extend(sorted(path.rglob("*.json")))
        elif path.is_file():
            files.append(path)
    return files


def contains_likely_mojibake(text: str) -> bool:
    if any(fragment in text for fragment in SUSPICIOUS_FRAGMENTS):
        return True
    return any(0x80 <= ord(ch) <= 0x9F for ch in text)


def suspicion_score(text: str) -> int:
    score = sum(text.count(fragment) for fragment in SUSPICIOUS_FRAGMENTS)
    score += sum(2 for ch in text if 0x80 <= ord(ch) <= 0x9F)
    return score


def repair_likely_mojibake(text: str, max_rounds: int = 3) -> str:
    if not contains_likely_mojibake(text):
        return text

    best = text
    best_score = suspicion_score(text)
    current = text

    for _ in range(max_rounds):
        repaired = best_single_round_repair(current)
        if repaired is None:
            break
        if repaired == current:
            break
        current = repaired
        score = suspicion_score(current)
        if score < best_score:
            best = current;
            best_score = score
        if score == 0:
            return current
    return best


def best_single_round_repair(text: str) -> str | None:
    candidates: list[str] = []
    for encoding in CP1252_ENCODINGS:
        try:
            candidate = text.encode(encoding).decode("utf-8")
        except UnicodeError:
            continue
        candidates.append(candidate)
    if not candidates:
        return None
    candidates.sort(key=lambda value: (suspicion_score(value), len(value)))
    return candidates[0]


def repair_json_value(value: Any) -> Any:
    if isinstance(value, str):
        return repair_likely_mojibake(value)
    if isinstance(value, list):
        return [repair_json_value(item) for item in value]
    if isinstance(value, dict):
        return {key: repair_json_value(item) for key, item in value.items()}
    return value


def process_file(path: Path, fix: bool) -> bool:
    raw = path.read_text(encoding="utf-8")
    if path.suffix == ".json":
        decoded = json.loads(raw)
        repaired = repair_json_value(decoded)
        changed = repaired != decoded
        output = json.dumps(repaired, ensure_ascii=False, indent=2) + "\n"
    else:
        output = "".join(
            repair_likely_mojibake(line) for line in raw.splitlines(keepends=True)
        )
        changed = output != raw
    if fix and changed:
        path.write_text(output, encoding="utf-8", newline="\n")
    return changed


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Audit and optionally repair mojibake in repo text assets."
    )
    parser.add_argument("paths", nargs="*", help="Optional custom files/directories")
    parser.add_argument("--fix", action="store_true", help="Repair files in place")
    args = parser.parse_args()

    targets = [Path(p).resolve() for p in args.paths] if args.paths else DEFAULT_TARGETS
    files = iter_target_files(targets)
    changed = [path for path in files if process_file(path, fix=args.fix)]

    if changed:
        action = "Repaired" if args.fix else "Detected"
        for path in changed:
            print(f"{action}: {path.relative_to(ROOT)}")
        return 0 if args.fix else 1

    print("No mojibake detected.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
