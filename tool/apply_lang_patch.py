import json
import sys
from pathlib import Path


def main() -> None:
    if len(sys.argv) not in (2, 3):
        raise SystemExit("usage: apply_lang_patch.py <lang> [json-patch]")
    lang = sys.argv[1].strip()
    raw_patch = sys.argv[2] if len(sys.argv) == 3 else sys.stdin.read()
    patch = json.loads(raw_patch)
    path = Path("assets/langs") / f"{lang}.json"
    data = json.loads(path.read_text(encoding="utf-8"))
    data.update(patch)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
