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

A part Rebrickable numbers differently is renamed to the LDraw part
whose own file names that Rebrickable number (_said: prints, assemblies,
moulds numbered apart), else through the one join the catalogue already
uses (rebrickable._matcher); one neither can place keeps Rebrickable's
number, which is BrickLink's or LDraw's for nearly every plain part. A
figure's legs on their hips and its torso with arms and hands, which
Rebrickable numbers as one piece and LDraw draws as its parts, are written
as those parts (_figure_parts). A colour the join cannot name is left out
and counted, never guessed.

Every .json in the folder is rewritten, models.json with them: run
src/dev/collection_models.gd after, which matches each official model to
the inventory written here.

    tools/collection_data.py              write assets/generated/sets/
    tools/collection_data.py --check      say what would be written
    tools/collection_data.py --bricklink  rewrite only the index's BrickLink
                                          colours, from colors.json
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
from collections import defaultdict
from collections.abc import Callable
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


LDRAW = ROOT / "vendor" / "ldraw"


def _drawn_with(part: str) -> list[str]:
    """The parts an LDraw shortcut file places, by number; none for a part
    file or one this checkout does not have."""
    for folder in (LDRAW / "parts", LDRAW / "unofficial" / "parts"):
        path = folder / f"{part}.dat"
        if path.exists():
            out = []
            for line in path.read_text(errors="replace").splitlines():
                words = line.split()
                if len(words) >= 15 and words[0] == "1":
                    out.append(" ".join(words[14:]).lower().removesuffix(".dat"))
            return out
    return []


def _said(entries: list[dict], rb_parts: set[str]) -> dict[str, str]:
    """Rebrickable part -> LDraw id, where LDraw's own file says so.

    An LDraw header names the Rebrickable number of what it draws
    ("!KEYWORDS Rebrickable 3626apr0001" on 3626ap01): eleven thousand of
    them do, for the prints Rebrickable numbers pr0001 where LDraw numbers
    p01, the assemblies it lists as one piece (973c28h01pr0040, a torso
    with its arms and hands, is LDraw's 76382p0003) and the moulds the two
    number apart (32005a is LDraw's 2739a). Read nowhere before, a set
    holding any of them held a number no model is drawn with.

    Where several files name one number they are the assembly and its
    parts, each saying what it comes in: the assembly is the one that
    places the others. Otherwise it is left to the other join. A file that
    is only an alias (4723, "=Slope Brick 45 2 x 2 Double Concave") gives
    the part it is an alias of (3046), the number models are drawn with."""
    known = {entry["id"].lower() for entry in entries}
    alias = {entry["id"].lower() for entry in entries if "Alias" in entry.get("kind", "")}
    named: dict[str, list[str]] = defaultdict(list)
    for entry in entries:
        for word in entry.get("keywords", []):
            source, _, number = word.partition(" ")
            if source.lower() == "rebrickable" and number.strip():
                named[number.strip().lower()].append(entry["id"].lower())
    said: dict[str, str] = {}
    for part in rb_parts:
        low = part.lower()
        ids = sorted(set(named.get(low, ())))
        if not ids or low in known:
            continue
        if len(ids) > 1:
            whole = [one for one in ids if set(ids) - {one} <= set(_drawn_with(one))]
            if len(whole) != 1:
                continue
            ids = whole
        target = _drawn_with(ids[0]) if ids[0] in alias else []
        said[low] = target[0] if len(target) == 1 and target[0] in known else ids[0]
    return said


def _renames(entries: list[dict], rb_parts: set[str]) -> dict[str, str]:
    """Rebrickable part -> LDraw id, for the parts numbered differently:
    what LDraw's own files say first (_said), then the catalogue's join."""
    match = rb._matcher(rb_parts)
    claims: dict[str, list[str]] = defaultdict(list)
    for entry in entries:
        found = match(entry)
        if found is not None:
            claims[found].append(entry["id"].lower())
    renamed: dict[str, str] = _said(entries, rb_parts)
    for part, ids in claims.items():
        low = part.lower()
        if low in ids or low in renamed:
            continue                      # the same number, or LDraw said
        # The undecorated drawing when several claim one Rebrickable part:
        # the shortest id, then the first by spelling, so a run is stable.
        renamed[low] = sorted(ids, key=lambda i: (len(i), i))[0]
    return renamed


## A minifigure's legs on its hips (970c28, "Hips and Blue Legs") and its
## torso with arms and hands (973c28h01, "Torso, Blue Arms, Yellow Hands
## [Plain]"): Rebrickable's numbers for what a set's figures are made of,
## which no LDraw file names, because LDraw draws a figure as its parts.
## The row's colour is the hips' or the torso's; the name says the rest.
FIGURE_LEGS = re.compile(r"^970c\d+$")
FIGURE_TORSO = re.compile(r"^973c\d+h\d+(pr\d+)?$")
LEGS_NAMED = re.compile(r"^Hips and (.+) Legs$")
ARMS_NAMED = re.compile(r", ([^,]+) Arms(?: and Hands|, ([^,]+) Hands)(?: \[Plain\])?$")


def _figure_parts(rb_names: dict[str, str], rb_colours: dict[str, int],
                  colour_of: dict[int, int]) -> Callable[[str, int], list[tuple[str, int]] | None]:
    """A figure assembly Rebrickable numbers as one piece -> the LDraw parts
    it is drawn with, [(part, LDraw colour)], given the row's colour; None
    for anything else, or a name that does not say its colours."""
    def colour(words: str) -> int | None:
        found = rb_colours.get(words.strip().lower().replace("gray", "grey"))
        return colour_of.get(found) if found is not None else None

    def parts(part: str, code: int) -> list[tuple[str, int]] | None:
        name = rb_names.get(part, "")
        if FIGURE_LEGS.match(part):
            said = LEGS_NAMED.match(name)
            legs = colour(said.group(1)) if said else None
            return None if legs is None else [("3815b", code), ("3816c", legs), ("3817c", legs)]
        torso = FIGURE_TORSO.match(part)
        if torso:
            said = ARMS_NAMED.search(name)
            arms = colour(said.group(1)) if said else None
            hands = colour(said.group(2)) if said and said.group(2) else arms
            if arms is None or hands is None:
                return None
            # A printed torso keeps Rebrickable's number, the only one its
            # print has; a plain one is LDraw's.
            return [(part if torso.group(1) else "973", code), ("3818", arms), ("3819", arms),
                    ("3820", hands), ("3820", hands)]
        return None

    return parts


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
    rb_colours = {r["name"].strip().lower().replace("gray", "grey"): int(r["id"])
                  for r in rb._rows("colors")}
    figure = _figure_parts({r["part_num"].lower(): r["name"] for r in rb._rows("parts")},
                           rb_colours, colour_of)
    counts = {"sets": 0, "lots": 0, "colour unknown": 0, "renamed parts": len(renamed),
              "figure parts drawn apart": 0, "with minifigures": 0, "with sets inside": 0}

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
            drawn = None if low in renamed else figure(low, code)
            if drawn is not None:
                counts["figure parts drawn apart"] += 1
            for one, colour in drawn or [(renamed.get(low, low), code)]:
                key = (one, colour, spare)
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
