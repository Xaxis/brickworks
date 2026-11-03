#!/usr/bin/env python3
"""What colours real sets are built in, for a design to be measured against.

The judge reads a design's colour off its pictures beside the real set's,
and what separated the designs it called the set's equal in colour from
those it did not was how many colours the picture showed against the
set's own (DESIGN_SCORES.md, "The colour read", 2026-11-01). Real sets
show about eight over 1% of the model; the designs showed fewer, and the
fewer they showed the more they lost.

A set's pictures are not here, and most sets were never drawn. Its parts
list is: a colour is seen in a set's picture when it is at least 1.5% of
the set's parts, transparent ones left out. Against the pictures of the 44
sets the bench draws, that count agrees with the colours seen at r 0.84,
off by 1.2 on average, and with 132 designs' at r 0.91, off by 0.9.

Writes assets/knowledge/set_colours.json.gz from the set inventories
(tools/collection_data.py) and the set catalogue: each set of REAL_MODEL
parts or more, as [number, name, theme, parts, [[colour, per mille]...]],
its theme an index into "themes" (the top theme: City, not City > Traffic),
its colours LDraw's codes at SHARE of its parts or more, transparent ones
too, most first. ColoursSeen (src/ai/colours_seen.gd) reads it.

    tools/set_colours.py [--generated DIR] [--out FILE]
"""

from __future__ import annotations

import argparse
import gzip
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from collection_data import shard_of  # noqa: E402
from rebrickable import REAL_MODEL  # noqa: E402

OUT = ROOT / "assets" / "knowledge" / "set_colours.json.gz"
# Kept down to this share of a set's parts, per mille: below the 15 a
# colour needs to be seen, so a design is told what a set has a little of.
SHARE = 10


def _root(theme: str, themes: dict) -> str:
    seen = set()
    while themes.get(theme, [None, None])[1] is not None and theme not in seen:
        seen.add(theme)
        theme = str(themes[theme][1])
    return str(themes.get(theme, ["", None])[0])


def colours(parts: list) -> list[list[int]]:
    """[[code, per mille]] of a set's parts list ([[part, code, qty]]), at
    SHARE or more, most first."""
    total = sum(q for _p, _c, q in parts)
    by: dict[int, int] = {}
    for _part, code, qty in parts:
        by[code] = by.get(code, 0) + qty
    shares = [[code, round(1000 * n / total)] for code, n in by.items() if total]
    return sorted((s for s in shares if s[1] >= SHARE), key=lambda s: (-s[1], s[0]))


def main() -> None:
    ask = argparse.ArgumentParser(description="What colours real sets are built in.")
    ask.add_argument("--generated", type=Path, default=ROOT / "assets" / "generated",
                     help="the set_catalog.json and sets/ to read")
    ask.add_argument("--out", type=Path, default=OUT)
    args = ask.parse_args()
    catalog = json.loads((args.generated / "set_catalog.json").read_text())
    themes: list[str] = []
    rows = []
    shards: dict[int, dict] = {}
    for number, name, _year, theme, parts, *_rest in catalog["sets"]:
        if int(parts or 0) < REAL_MODEL:
            continue
        shard = shard_of(number)
        if shard not in shards:
            shards[shard] = json.loads((args.generated / "sets" / f"{shard:03d}.json")
                                       .read_text())["sets"]
        inventory = shards[shard].get(number.lower())
        if not inventory or not inventory.get("p"):
            continue
        top = _root(str(theme), catalog["themes"])
        if top not in themes:
            themes.append(top)
        rows.append([number, name, themes.index(top), int(parts), colours(inventory["p"])])
    document = {"format": 1, "share": SHARE,
                "source": "Rebrickable's set inventories (rebrickable.com/downloads)",
                "themes": themes, "sets": rows}
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_bytes(gzip.compress(json.dumps(document, separators=(",", ":"),
                                                  ensure_ascii=False).encode(), mtime=0))
    print(f"set_colours: {len(rows)} sets in {len(themes)} themes, "
          f"{args.out.stat().st_size:,} bytes, to {args.out}")


if __name__ == "__main__":
    main()
