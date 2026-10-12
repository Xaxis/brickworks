#!/usr/bin/env python3
"""What is in each set, in LDraw's numbers: the data "My collection" opens.

A person says what they own as sets ("10237-1") as often as parts, and a
set means nothing to the app until it is a list of parts in colours. The
list is Rebrickable's set inventories, which tools/fetch_data.sh fetches
(at most once a day, a condition of their grant) and which is the only
copy this reads. Nothing here goes over the network.

Written as 256 shards and an index under assets/generated/sets/:

    index.json    the joins: Rebrickable part numbers that are not
                  LDraw's, Rebrickable colour ids to LDraw codes, how many
                  sets, and the shard rule
    NNN.json      {"sets": {"10237-1": {"n": name, "y": year,
                  "p": [[part, colour, qty], ...], "s": [...spares]}}}

Sharded because the whole thing is several megabytes and a person types
one set number at a time. The desktop reads the shards from its own
files; the web build fetches one from the deployment's /sets/ (deploy.sh
copies them), so a set typed costs one small request rather than a
download everybody waits for.

A set's parts are its own inventory's, version 1 as the rest of the
pipeline counts it, plus its minifigures' parts and the parts of any set
packed inside it (inventory_minifigs, inventory_sets). Spare parts are
kept apart, because Rebrickable's own set lists say per set whether the
spares count.

A part Rebrickable numbers differently is renamed through the one join
the catalogue already uses (rebrickable._matcher); one the join cannot
place keeps Rebrickable's number, which is BrickLink's or LDraw's for
nearly every plain part. A colour the join cannot name is left out and
counted, never guessed.

    tools/collection_data.py              write assets/generated/sets/
    tools/collection_data.py --check      say what would be written
    tools/collection_data.py --bricklink  rewrite only the index's BrickLink
                                          colours, from colors.json
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import rebrickable as rb  # noqa: E402

GENERATED = ROOT / "assets" / "generated"
OUT = GENERATED / "sets"

SHARDS = 256


def shard_of(set_num: str) -> int:
    """Which file a set is in. Collection.shard_of in the app is the same
    sum, and the two must agree or a typed set is looked for in the wrong
    file and reported unknown."""
    h = 0
    for byte in set_num.strip().lower().encode("utf-8"):
        h = (h * 31 + byte) % 1_000_003
    return h % SHARDS


def bricklink_colours(colours: list[dict]) -> dict[int, int]:
    """BrickLink colour number -> LDraw code, from colors.json's bricklink
    numbers, which the app exports wanted lists with, so the import and the
    export cannot come to disagree. Where two LDraw codes share a BrickLink
    number the lower code, the plain one, wins."""
    out: dict[int, int] = {}
    for entry in sorted(colours, key=lambda e: e["code"]):
        if "bricklink" in entry:
            out.setdefault(int(entry["bricklink"]), int(entry["code"]))
    return out


def _renames(entries: list[dict], rb_parts: set[str]) -> dict[str, str]:
    """Rebrickable part -> LDraw id, for the parts numbered differently."""
    match = rb._matcher(rb_parts)
    claims: dict[str, list[str]] = defaultdict(list)
    for entry in entries:
        found = match(entry)
        if found is not None:
            claims[found].append(entry["id"].lower())
    renamed: dict[str, str] = {}
    for part, ids in claims.items():
        low = part.lower()
        if low in ids:
            continue                      # the same number: nothing to say
        # The undecorated drawing when several claim one Rebrickable part:
        # the shortest id, then the first by spelling, so a run is stable.
        renamed[low] = sorted(ids, key=lambda i: (len(i), i))[0]
    return renamed


def build() -> tuple[dict, dict[int, dict]]:
    catalogue = json.loads((GENERATED / "catalogue.json").read_text())
    colours = json.loads((GENERATED / "colors.json").read_text())
    entries = catalogue["parts"]
    colour_of = rb.colour_codes(colours)

    first_version: dict[str, tuple[int, str]] = {}
    for row in rb._rows("inventories"):
        version = int(row["version"] or 1)
        held = first_version.get(row["set_num"])
        if held is None or version < held[0]:
            first_version[row["set_num"]] = (version, row["id"])
    inventory_of = {s: v[1] for s, v in first_version.items()}
    wanted = set(inventory_of.values())

    rows: dict[str, list[tuple[str, int, int, bool]]] = defaultdict(list)
    rb_parts: set[str] = set()
    for row in rb._rows("inventory_parts"):
        if row["inventory_id"] not in wanted:
            continue
        rows[row["inventory_id"]].append((
            row["part_num"], int(row["color_id"]), int(row["quantity"]),
            row["is_spare"] == "True"))
        rb_parts.add(row["part_num"])
    figures: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for row in rb._rows("inventory_minifigs"):
        figures[row["inventory_id"]].append((row["fig_num"], int(row["quantity"])))
    inside: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for row in rb._rows("inventory_sets"):
        inside[row["inventory_id"]].append((row["set_num"], int(row["quantity"])))

    renamed = _renames(entries, rb_parts)
    counts = {"sets": 0, "lots": 0, "colour unknown": 0, "renamed parts": len(renamed),
              "with minifigures": 0, "with sets inside": 0}

    def expand(set_num: str, times: int, into: dict, depth: int = 0) -> None:
        inventory = inventory_of.get(set_num)
        if inventory is None or depth > 3:
            return
        for part, colour, qty, spare in rows.get(inventory, ()):
            code = colour_of.get(colour)
            if code is None:
                counts["colour unknown"] += 1
                continue
            low = part.lower()
            key = (renamed.get(low, low), code, spare)
            into[key] = into.get(key, 0) + qty * times
        for fig, qty in figures.get(inventory, ()):
            expand(fig, times * qty, into, depth + 1)
        for other, qty in inside.get(inventory, ()):
            expand(other, times * qty, into, depth + 1)

    info = {r["set_num"]: (r["name"], int(r["year"] or 0)) for r in rb._rows("sets")}
    shards: dict[int, dict] = defaultdict(dict)
    for set_num in sorted(info):
        if set_num not in inventory_of:
            continue
        pile: dict = {}
        expand(set_num, 1, pile)
        if not pile:
            continue
        inventory = inventory_of[set_num]
        counts["with minifigures"] += bool(figures.get(inventory))
        counts["with sets inside"] += bool(inside.get(inventory))
        kept = sorted(([p, c, q] for (p, c, s), q in pile.items() if not s),
                      key=lambda r: (r[0], r[1]))
        spare = sorted(([p, c, q] for (p, c, s), q in pile.items() if s),
                       key=lambda r: (r[0], r[1]))
        name, year = info[set_num]
        record: dict = {"n": name, "y": year, "p": kept}
        if spare:
            record["s"] = spare
        shards[shard_of(set_num)][set_num.lower()] = record
        counts["sets"] += 1
        counts["lots"] += len(kept) + len(spare)

    index = {
        "format": 1,
        "source": "Rebrickable set inventories (rebrickable.com/downloads)",
        "generated": int(time.time()),
        "shards": SHARDS,
        "shard_rule": "h = (h * 31 + byte) % 1000003 over the lowercased set number; h % shards",
        "colours": {str(k): v for k, v in sorted(colour_of.items())},
        "parts": dict(sorted(renamed.items())),
        "bricklink_colours": {str(k): v for k, v in sorted(bricklink_colours(colours).items())},
        "counts": counts,
    }
    return index, shards


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="write nothing")
    parser.add_argument("--bricklink", action="store_true",
                        help="rewrite only index.json's bricklink_colours, from colors.json")
    args = parser.parse_args()
    if args.bricklink:
        # The shards and the part join are left as they were built: a new
        # colour number changes neither.
        index = json.loads((OUT / "index.json").read_text())
        colours = json.loads((GENERATED / "colors.json").read_text())
        index["bricklink_colours"] = {
            str(k): v for k, v in sorted(bricklink_colours(colours).items())}
        (OUT / "index.json").write_text(json.dumps(index, separators=(",", ":")))
        print(f"  {len(index['bricklink_colours'])} BrickLink colours in {OUT / 'index.json'}")
        return 0
    index, shards = build()
    sizes = [len(json.dumps({"sets": s}, separators=(",", ":"))) for s in shards.values()]
    print(f"sets: {index['counts']['sets']:,} sets, {index['counts']['lots']:,} lots, "
          f"{index['counts']['renamed parts']:,} parts renamed, "
          f"{index['counts']['colour unknown']:,} rows in a colour with no LDraw code")
    print(f"  {len(shards)} shards, {sum(sizes) / 1e6:.1f} MB, largest {max(sizes) / 1e3:.0f} kB")
    if args.check:
        return 0
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("*.json"):
        old.unlink()
    for number, sets in shards.items():
        (OUT / f"{number:03d}.json").write_text(
            json.dumps({"sets": sets}, separators=(",", ":")))
    (OUT / "index.json").write_text(json.dumps(index, separators=(",", ":")))
    print(f"  wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
