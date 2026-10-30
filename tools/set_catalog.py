#!/usr/bin/env python3
"""Every set in Rebrickable's catalogue, for the site's set pages (sets364).

The library on the site was LDraw's official models of real sets, a few
hundred sets somebody built in 3D. The owner asked for every set there is.
Rebrickable's catalogue is already here (tools/fetch_data.sh, at most once a
day, a condition of their grant), and every set's parts list is already
joined to LDraw's numbers and colours in tools/collection_data.py's shards.
This writes what those shards do not say: every set's name, year, theme,
part count, minifigures and the sets packed in it, the theme tree, and for
each set the few parts its picture is drawn from. Nothing here goes over the
network.

Written as one file, assets/generated/set_catalog.json:

    themes   {id: [name, parent id or null]}
    sets     [[number, name, year, theme id, parts, minifigures, lots], ...]
             by number; parts and lots are the shard's list's (its
             minifigures' parts and the sets inside it counted in, spares
             not), else Rebrickable's own count for a set with no inventory
    inside   {number: [[set inside it, how many], ...]}
    picks    {number: ["part/colour", ...]}: its most distinctive parts, the
             few its picture is drawn from (api/_flatlay.js), rarest across
             every set first, each one LDraw has geometry for

A page reads its set from here and its parts from the shard (api/_sets.js).
The file goes beside the share function at deploy (tools/deploy.sh), which
runs this first: it is quick, and rewrites the file only when what it
would write has changed, so a rerun touches nothing.

    tools/set_catalog.py           write assets/generated/set_catalog.json
    tools/set_catalog.py --check   say what would be written
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import rebrickable as rb  # noqa: E402

GENERATED = ROOT / "assets" / "generated"
SHARDS = GENERATED / "sets"
OUT = GENERATED / "set_catalog.json"

# How many parts a set's picture lays out, and which a picture leaves out:
# a sticker is flat, and a sticker shortcut is a part with one on.
PICKS = 6
NOT_PICKED = {"Sticker", "Sticker Shortcut", "Moved", "Obsolete"}
# At most this many of a set's picks are a figure's: a set is not its
# minifigures, though a printed torso is as telling as anything in it.
FIGURE_PICKS = 2
FIGURE = ("Minifig", "Figure")
# A part this small is lost in a picture of six; one this heavy costs a
# function too long to draw (the median part is about a thousand triangles).
LEAST_SIZE = 16.0
MOST_TRIANGLES = 30000


def _inventories() -> dict[str, str]:
    """Each set's first inventory, as tools/collection_data.py takes it."""
    first: dict[str, tuple[int, str]] = {}
    for row in rb._rows("inventories"):
        version = int(row["version"] or 1)
        held = first.get(row["set_num"])
        if held is None or version < held[0]:
            first[row["set_num"]] = (version, row["id"])
    return {number: held[1] for number, held in first.items()}


def _shards() -> dict[str, dict]:
    """Every set's record in tools/collection_data.py's shards, by its
    lower-cased number."""
    found: dict[str, dict] = {}
    for path in sorted(SHARDS.glob("[0-9][0-9][0-9].json")):
        found.update(json.loads(path.read_text())["sets"])
    return found


def picks(records: dict[str, dict], parts: dict[str, dict]) -> dict[str, list[str]]:
    """Each set's most distinctive parts: those in the fewest sets first (a
    part in every set says nothing of this one), more of it in the set
    breaking a tie, one colour of a part, each one LDraw draws."""
    used_in: dict[str, int] = defaultdict(int)
    for record in records.values():
        for part in {lot[0] for lot in record.get("p", ())}:
            used_in[part] += 1
    every = max(1, len(records))
    out: dict[str, list[str]] = {}
    for number, record in records.items():
        scored = []
        for part, colour, qty in record.get("p", ()):
            info = parts.get(part)
            if not info or not info.get("mesh") or info.get("category") in NOT_PICKED:
                continue
            if max(info.get("size_ldu") or [0]) < LEAST_SIZE or info.get("triangles", 0) > MOST_TRIANGLES:
                continue
            rarity = math.log(every / used_in[part])
            scored.append((-(rarity * (1 + math.log(qty))), part, colour, info.get("category", "")))
        scored.sort()
        chosen: list[str] = []
        seen: set[str] = set()
        figures = 0
        for _score, part, colour, category in scored:
            if part in seen:
                continue
            figure = category.startswith(FIGURE)
            if figure and figures >= FIGURE_PICKS:
                continue
            seen.add(part)
            figures += figure
            chosen.append(f"{part}/{colour}")
            if len(chosen) == PICKS:
                break
        if chosen:
            out[number] = chosen
    return out


def build() -> dict:
    themes = {row["id"]: [row["name"], int(row["parent_id"]) if row["parent_id"] else None]
              for row in rb._rows("themes")}
    inventory_of = _inventories()
    figures: dict[str, int] = defaultdict(int)
    for row in rb._rows("inventory_minifigs"):
        figures[row["inventory_id"]] += int(row["quantity"])
    inside: dict[str, list[list]] = defaultdict(list)
    for row in rb._rows("inventory_sets"):
        inside[row["inventory_id"]].append([row["set_num"], int(row["quantity"])])
    records = _shards()
    catalogue = json.loads((GENERATED / "catalogue.json").read_text())
    parts = {entry["id"]: entry for entry in catalogue["parts"]}

    rows = []
    packed: dict[str, list[list]] = {}
    for row in sorted(rb._rows("sets"), key=lambda one: one["set_num"].lower()):
        number = row["set_num"]
        record = records.get(number.lower())
        inventory = inventory_of.get(number, "")
        if record:
            lots = len(record.get("p", ()))
            count = sum(lot[2] for lot in record.get("p", ()))
        else:
            lots = 0
            count = int(row["num_parts"] or 0)
        rows.append([number, row["name"].strip(), int(row["year"] or 0), int(row["theme_id"] or 0),
                     count, figures.get(inventory, 0), lots])
        if inside.get(inventory):
            packed[number] = sorted(inside[inventory])
    chosen = picks(records, parts)
    known = {row[0].lower(): row[0] for row in rows}
    return {
        "format": 1,
        "source": "Rebrickable's catalogue and set inventories (rebrickable.com/downloads)",
        "themes": {key: themes[key] for key in sorted(themes, key=int)},
        "sets": rows,
        "inside": packed,
        "picks": {known[number]: chosen[number] for number in sorted(chosen) if number in known},
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="write nothing")
    args = parser.parse_args()
    started = time.monotonic()
    made = build()
    text = json.dumps(made, separators=(",", ":"), ensure_ascii=False)
    with_parts = sum(1 for row in made["sets"] if row[4] > 0)
    print(f"set catalogue: {len(made['sets']):,} sets ({with_parts:,} with parts), "
          f"{len(made['themes']):,} themes, {len(made['picks']):,} with a picture's parts, "
          f"{len(text.encode()) / 1e6:.1f} MB, {time.monotonic() - started:.1f} s")
    if args.check:
        return 0
    if OUT.exists() and OUT.read_text(encoding="utf-8") == text:
        print(f"  {OUT} as it was")
        return 0
    if OUT.is_symlink():
        OUT.unlink()
    OUT.write_text(text, encoding="utf-8")
    print(f"  wrote {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
