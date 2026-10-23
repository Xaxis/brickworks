#!/usr/bin/env python3
"""The words set inventories name a part by, where LDraw's name lacks them.

    python3 tools/part_names.py        -> assets/ldraw/part_names.json

LDraw files 27925 as "Tile 2 x 2 Corner Round"; the set inventories
(Rebrickable, and BrickLink much the same) list it as "Tile 2 x 2 Curved,
Macaroni". 553, LDraw's "Cylinder 2 x 2 with Dome Top", is "Brick Round
2 x 2 Dome Top" there; 22388 is a "Quadruple Convex [Pyramid]" slope. Those
are the words a builder asks in, and Claude: BrickBench's m147 designs
searched in them and were told the parts did not exist (docs/BRICKBENCH.md,
2026-10-22). search_parts reads these beside each name (src/parts/part_search.gd).

Only the words a plain part's LDraw name, number, category and keywords do
not already have, through rebrickable._matcher, the one join between the two
libraries. Fractions are written as LDraw writes them (2/3 is 0.667). Reads
assets/generated/catalogue.json and vendor/rebrickable/parts.csv.gz.
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import rebrickable  # noqa: E402

OUT = ROOT / "assets" / "ldraw" / "part_names.json"
# Words that say nothing about which part, as src/parts/part_search.gd drops them.
STOP = {"with", "and", "or", "on", "of", "the", "a", "an", "for", "in", "to", "x"}
MIXED = re.compile(r"(\d+) (\d+)/(\d+)")
FRACTION = re.compile(r"(\d+)/(\d+)")


def _number(value: float) -> str:
    return str(int(value)) if abs(value - round(value)) < 1e-6 else f"{value:.3f}"


def words(text: str) -> set[str]:
    """part_search.gd's words_of, fractions as decimals first."""
    text = MIXED.sub(lambda m: _number(int(m[1]) + int(m[2]) / max(1, int(m[3]))), text.lower())
    text = FRACTION.sub(lambda m: _number(int(m[1]) / max(1, int(m[2]))), text)
    return {w.rstrip(".") for w in re.split(r"[^\w.]+|_", text) if w.rstrip(".")}


def main() -> int:
    catalogue = json.loads((ROOT / "assets" / "generated" / "catalogue.json").read_text())
    entries = catalogue["parts"]
    named = {r["part_num"]: r["name"] for r in rebrickable._rows("parts")}
    match = rebrickable._matcher(named)
    out: dict[str, str] = {}
    for entry in entries:
        name = entry.get("name") or ""
        if re.search(r"pattern|sticker", name, re.I):
            continue
        found = match(entry)
        if found is None:
            continue
        have = words(" ".join([entry["id"], name, entry.get("category") or ""]
                              + list(entry.get("keywords") or [])))
        extra = sorted(w for w in words(named[found]) - have if w not in STOP)
        if extra:
            out[entry["id"]] = " ".join(extra)
    OUT.write_text(json.dumps({
        "source": "Rebrickable parts.csv, words not in each LDraw name (tools/part_names.py)",
        "words": dict(sorted(out.items()))}, indent=0, separators=(",", ":")) + "\n")
    print(f"part names: {len(out):,} parts given {sum(len(v.split()) for v in out.values()):,} "
          f"words, {OUT.stat().st_size // 1024} KB at {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
