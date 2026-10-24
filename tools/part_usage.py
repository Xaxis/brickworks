#!/usr/bin/env python3
"""How much real sets use each part: in how many sets, and how many pieces.

    python3 tools/part_usage.py        -> assets/ldraw/part_usage.json

The parts bin ranks by it (src/parts/part_search.gd). A name says what a
part is and never how much it is used: "door frame" led with 80400a, the
2 x 8 x 6 in 24 sets, over 60596, the 1 x 4 x 6 in 850 (walk239 A13,
2026-10-24). The catalogue's in_sets counts sets for the 6,000 plain parts
the Rebrickable join reaches; the set inventories under
assets/generated/sets/ are already in LDraw's numbers, prints and a
figure's parts too, so they reach 13,000, and they carry how many of a part
each set has. 2780, the black friction pin, is in about as many sets as
4274 and 43093 and in two and a half times their pieces.

A set's own parts, its figures' and those of any set packed in it, spares
left out (tools/collection_data.py). Only parts the catalogue has. Run
after tools/collection_data.py.
"""

from __future__ import annotations

import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SETS = ROOT / "assets" / "generated" / "sets"
OUT = ROOT / "assets" / "ldraw" / "part_usage.json"


def main() -> int:
    catalogue = json.loads((ROOT / "assets" / "generated" / "catalogue.json").read_text())
    known = {entry["id"] for entry in catalogue["parts"]}
    sets: Counter = Counter()
    pieces: Counter = Counter()
    counted = 0
    for shard in sorted(SETS.glob("[0-9][0-9][0-9].json")):
        for record in json.loads(shard.read_text())["sets"].values():
            counted += 1
            seen = set()
            for part, _colour, quantity in record.get("p", []):
                pieces[part] += quantity
                seen.add(part)
            for part in seen:
                sets[part] += 1
    out = {part: [sets[part], pieces[part]] for part in sorted(sets) if part in known}
    OUT.write_text(json.dumps({
        "source": "Rebrickable set inventories in LDraw numbers, %d sets "
                  "(tools/part_usage.py): part -> [sets, pieces]" % counted,
        "parts": out}, separators=(",", ":")) + "\n")
    print(f"part usage: {len(out):,} parts over {counted:,} sets, "
          f"{OUT.stat().st_size // 1024} KB at {OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
