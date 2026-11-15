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
    colours_NN.json  {"parts": {"3001": [colour, sets, colour, sets, ...]}}:
                  in how many sets each part comes in each colour, the
                  parts bin's "rare in this colour" (PartLibrary.sets_in_colour)
    all_sets.bin  every set's parts at once, as few bytes as What can I
                  build? can rank every set from (write_index, SetRanking)

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
    tools/collection_data.py --colours    rewrite only the colours_NN.json, from
                                          the shards written
    tools/collection_data.py --index      rewrite only all_sets.bin, from the
                                          shards written
"""

from __future__ import annotations

import argparse
import json
import re
import struct
import sys
import time
from collections import defaultdict
from collections.abc import Callable
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import rebrickable as rb  # noqa: E402
from ldraw.parser import read_text  # noqa: E402

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


COLOUR_SHARDS = 64


def colour_shard_of(part: str) -> int:
    """Which colours file a part is in: shard_of's sum over its number, in 64
    files. PartLibrary.colour_shard_of in the app is the same sum."""
    h = 0
    for byte in part.strip().lower().encode("utf-8"):
        h = (h * 31 + byte) % 1_000_003
    return h % COLOUR_SHARDS


## Rebrickable's "Database Sets" (theme 746): "2001 - Unused Parts Database
## Set" and the like, which hold the parts no set has. Not sets: 3001 in
## Bright Green read "in 1 set" through one.
NOT_SETS = {"746"}


def _what_sets_are() -> tuple[set[str], dict[str, list[str]]]:
    """The set numbers that are not sets (NOT_SETS), and each set that packs
    others -> the sets packed in it, by their first inventories, lowercased
    as the shards key them."""
    skip = {r["set_num"].lower() for r in rb._rows("sets") if r["theme_id"] in NOT_SETS}
    first: dict[str, tuple[int, str]] = {}
    for row in rb._rows("inventories"):
        version = int(row["version"] or 1)
        if row["set_num"] not in first or version < first[row["set_num"]][0]:
            first[row["set_num"]] = (version, row["id"])
    owner = {inventory: number.lower() for number, (_v, inventory) in first.items()}
    packs: dict[str, list[str]] = defaultdict(list)
    for row in rb._rows("inventory_sets"):
        pack = owner.get(row["inventory_id"])
        if pack is not None:
            packs[pack].append(row["set_num"].lower())
    return skip, packs


def colour_sets(shards: dict, known: set[str], skip: set[str],
                packs: dict[str, list[str]]) -> dict[int, dict[str, list[int]]]:
    """Colours file -> {part: [colour, sets, colour, sets, ...]}: in how many
    sets each part the catalogue has comes in each colour, colours in order.

    A set counts once however many it holds, its own parts and its figures',
    as its shard has them; a spare alone does not count, as part_usage.py
    counts. A set that packs others (a co-pack, a value pack) counts only
    for what is not in the sets packed in it, which count themselves: 4740
    in Brown is in 7126 and 7171, and in VP-4 because it packs 7171. And
    Rebrickable's database sets (NOT_SETS) are none. BrickMissing says a
    part and colour in three sets or fewer is rare, and that is what a
    person replacing a lost piece asks (APP_UX7 rarity). The catalogue's
    in_sets counts sets per part only.

    In the app's first screen they would be 104 kB (brotli) more for every
    visit, for a tooltip: so beside the shards, fetched a part's file at a
    time on the web, as a typed set's shard is."""
    records: dict[str, dict] = {}
    for sets in shards.values():
        records.update(sets)

    def pairs(number: str) -> set[tuple[str, int]]:
        return {(p, c) for p, c, _q in records.get(number, {}).get("p", ())}

    counted: dict[tuple[str, int], int] = defaultdict(int)
    for number in records:
        if number in skip:
            continue
        own = pairs(number)
        for packed in packs.get(number, ()):
            own -= pairs(packed)
        for part, colour in own:
            if part in known:
                counted[(part, colour)] += 1
    out: dict[int, dict[str, list[int]]] = defaultdict(dict)
    for (part, colour), sets_in in sorted(counted.items()):
        out[colour_shard_of(part)].setdefault(part, []).extend((colour, sets_in))
    return out


def write_colour_sets(shards: dict, known: set[str]) -> None:
    files = colour_sets(shards, known, *_what_sets_are())
    pairs = 0
    for number in range(COLOUR_SHARDS):
        parts = files.get(number, {})
        pairs += sum(len(row) // 2 for row in parts.values())
        (OUT / f"colours_{number:02d}.json").write_text(json.dumps({"parts": parts},
            separators=(",", ":")))
    print(f"  {pairs:,} parts in a colour counted, in {COLOUR_SHARDS} colours files")


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
            for line in read_text(path).splitlines():
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


# --- every set at once: What can I build? (setsbuild, docs/APP_UX8.md #12) ---
#
# What can I build? ranks every set Rebrickable lists by how much of it a
# person owns, where it ranked only the few hundred with a model file. A set
# is looked up one shard at a time; ranking all 20,000 wants all of them,
# and the shards are 26 MB. So beside them, one file of only what a ranking
# reads, which the page fetches as it opens (SetRanking in the app):
#
#   - a set's parts as What do I need? and the bin count them (OwnCounts,
#     Collection.ownable): a part nobody owns on its own (a sticker sheet,
#     a ~ piece, a number LDraw does not draw) is not counted, and each
#     part and colour is spelled as Collection.key_of spells it. _Owning
#     reads the catalogue as the app does; src/dev/setsbuild_probe.gd
#     checks it against the app's own sums, set by set;
#   - inverted, part and colour -> the sets it is in, because a ranking
#     only ever asks for the parts the person owns;
#   - a set that packs others (a value pack, a co-pack) as its own parts
#     and the sets in it, which are listed already (an eighth of the lots);
#   - the sets ordered by theme and era, so a part's sets lie close
#     together and the gaps between them take few bits.
#
# Under 2 MB on the web, where it is fetched from /sets/ beside the shards
# (deploy.sh copies it, cached as they are), never from Supabase storage.

INDEX = "all_sets.bin"
INDEX_MAGIC = b"BWAS"
INDEX_FORMAT = 1
INDEX_ZSTD = 1
## The most the file may be: the web fetches it as the page opens.
INDEX_MOST = 2_000_000
## A quantity this big or over is written in "over", not its byte.
INDEX_OVER = 255
## Another moulding of one part: Collection._MOULD, the same expression.
MOULD = re.compile(r"^([ux]?\d+)[a-z]$")


def family_of(part: str) -> str:
    """Collection.family_of: 3794a and 3794b are 3794's family."""
    found = MOULD.search(part)
    return found.group(1) if found else part


class _Owning:
    """Collection.key_of and Collection.ownable, as the app reads the same
    catalogue.json and colors.json (PartLibrary.resolve, plain_code)."""

    def __init__(self, parts: list[dict], colours: list[dict]) -> None:
        self.parts = {entry["id"]: entry for entry in parts}
        self.plain = {int(entry["code"]): int(entry.get("plain_code", entry["code"]))
                      for entry in colours}

    def resolve(self, part: str) -> str:
        at = part
        for _hop in range(8):
            info = self.parts.get(at)
            if info is None or not info.get("moved_to") or info["moved_to"] not in self.parts:
                return at
            at = info["moved_to"]
        return at

    def key(self, part: str, colour: int) -> str | None:
        """The part and colour as Collection.key_of spells them, or None for a
        part nobody owns on its own (Collection.ownable)."""
        part = self.resolve(part.lower())
        info = self.parts.get(part)
        if info is None or info.get("category") == "Sticker" or "Flexible_Section" in info.get("kind", ""):
            return None
        if info["name"].startswith("~") and not info.get("moved_to") and "(Obsolete)" not in info["name"]:
            return None
        return f"{part}/{self.plain.get(colour, colour)}"


def index_needs(records: dict[str, dict], owning: _Owning, skip: set[str]) -> dict[str, dict[str, int]]:
    """Each set's parts as What can I build? counts them: its lots, no
    spares, every piece anybody owns on its own, by Collection.key_of. A set
    with none (a book, a sticker sheet, gear) and Rebrickable's database sets
    ([param skip]) are left out: there is nothing in them to build."""
    out: dict[str, dict[str, int]] = {}
    for number, record in records.items():
        if number in skip:
            continue
        needs: dict[str, int] = {}
        for part, colour, qty in record.get("p", ()):
            key = owning.key(part, int(colour))
            if key is not None:
                needs[key] = needs.get(key, 0) + int(qty)
        if needs:
            out[number] = needs
    return out


def _index_packs(needs: dict[str, dict[str, int]], packs: dict[str, list[str]],
                 times: dict[tuple[str, str], int]) -> dict[str, tuple[dict[str, int], dict[str, int]]]:
    """Each set that packs others, as {leaf set: how many} and what is its
    own beyond them, where the two add up to its parts exactly. A leaf is a
    set packing none, so a pack's parts are only ever its own and its
    leaves'; one whose own would come out below nothing for any part is
    left whole."""
    def leaves(number: str, many: int, into: dict[str, int], depth: int = 0) -> None:
        for inside in dict.fromkeys(packs.get(number, ())):
            count = many * times.get((number, inside), 1)
            if inside in packs and depth < 3:
                leaves(inside, count, into, depth + 1)
            elif inside in needs:
                into[inside] = into.get(inside, 0) + count

    out: dict[str, tuple[dict[str, int], dict[str, int]]] = {}
    for number in packs:
        if number not in needs:
            continue
        refs: dict[str, int] = {}
        leaves(number, 1, refs)
        own = dict(needs[number])
        for leaf, count in refs.items():
            for key, qty in needs[leaf].items():
                own[key] = own.get(key, 0) - qty * count
        if refs and min(own.values(), default=0) >= 0:
            out[number] = (refs, {k: v for k, v in own.items() if v > 0})
    # A leaf is written whole, its parts its own: one that is a pack too
    # (packed deeper than leaves looks) is left whole.
    for refs, _own in list(out.values()):
        for leaf in refs:
            out.pop(leaf, None)
    return out


def _varints(numbers) -> bytes:
    out = bytearray()
    for n in numbers:
        n = int(n)
        while n >= 0x80:
            out.append((n & 0x7F) | 0x80)
            n >>= 7
        out.append(n)
    return bytes(out)


def _natural(number: str) -> list:
    return [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", number)]


def encode_index(records: dict[str, dict], needs: dict[str, dict[str, int]],
                 packs: dict[str, tuple[dict[str, int], dict[str, int]]],
                 era: Callable[[str], tuple], generated: int, not_sets: list[str] | None = None,
                 models: dict[str, list[str]] | None = None) -> bytes:
    """all_sets.bin: "BWAS", format, 1 (zstd), two bytes nought, the
    payload's size (u32), then the payload, zstd, as sections each its byte
    length (u32) then its bytes:

        0 meta      JSON: what is in it
        1 numbers   the sets' numbers, lowercased, a line each
        2 names     their names, a line each
        3 years     a byte each, the year less 1940 (0: not known)
        4 pieces    varint each, its pieces counted (index_needs)
        5 pairs     every part and colour in a set, "3001/4", a line each,
                    by family (Collection.family_of) then spelling
        6 families  varint each family in order: its pairs << 1, | 1 where
                    its name is its first pair's part less the last letter
        7 counts    varint each pair: how many sets it is in
        8 low       a byte each set a pair is in, pair by pair: the gap
        9 high      from the set before, low | high << 8; sets in order
       10 qty       a byte each: how many; 255 says see over
       11 over      varint pairs: postings since the last, how many
       12 packs     varint: the pack, its leaves, then each leaf and how
                    many; a pack's own parts are in the postings
       13 same      varint pairs: a set, the earlier set it is the same as;
                    it has no postings, and is ranked as that one is

    Sets are numbered in the order of "numbers"."""
    order = sorted(needs, key=lambda number: (era(number), _natural(number)))
    # A set whose parts are another's exactly is ranked as that one. Packs
    # are neither: a book packing one polybag holds just its parts, and
    # made the polybag's own, its only leaf, read as nothing.
    first_of: dict[tuple, str] = {}
    same: dict[str, str] = {}
    for number in order:
        if number in packs:
            continue
        sign = tuple(sorted(needs[number].items()))
        if sign in first_of:
            same[number] = first_of[sign]
        else:
            first_of[sign] = number
    at = {number: i for i, number in enumerate(order)}
    postings: dict[str, list[tuple[int, int]]] = defaultdict(list)
    for number in order:
        if number in same:
            continue
        own = packs[number][1] if number in packs else needs[number]
        for key, qty in own.items():
            postings[key].append((at[number], qty))
    pairs = sorted(postings, key=lambda key: (family_of(key.split("/")[0]), key))
    families: list[int] = []
    run_family = None
    for key in pairs:
        part = key.split("/")[0]
        family = family_of(part)
        if family != run_family:
            families.append(int(family != part))     # its flag; its count is added
            run_family = family
        families[-1] += 2
    counts: list[int] = []
    low = bytearray()
    high = bytearray()
    qty_bytes = bytearray()
    over: list[int] = []
    last_over = 0
    posting = 0
    for key in pairs:
        listed = sorted(postings[key])
        counts.append(len(listed))
        last = -1
        for number, qty in listed:
            gap = number - last - 1
            last = number
            low.append(gap & 0xFF)
            high.append(gap >> 8)
            if qty >= INDEX_OVER:
                qty_bytes.append(INDEX_OVER)
                over += [posting - last_over, qty]
                last_over = posting
            else:
                qty_bytes.append(qty)
            posting += 1
    packed: list[int] = []
    for number in sorted(packs, key=lambda n: at[n]):
        refs = packs[number][0]
        # A leaf that is ranked as another set carries that set's parts.
        leaves: dict[int, int] = {}
        for leaf, count in refs.items():
            whole = at[same.get(leaf, leaf)]
            leaves[whole] = leaves.get(whole, 0) + count
        packed += [at[number], len(leaves)]
        for leaf in sorted(leaves):
            packed += [leaf, leaves[leaf]]
    same_pairs: list[int] = []
    for number in order:
        if number in same:
            same_pairs += [at[number], at[same[number]]]
    meta = {"format": INDEX_FORMAT, "generated": generated,
            "source": "Rebrickable set inventories (rebrickable.com/downloads), as the shards beside it",
            "sets": len(order), "pairs": len(pairs), "families": len(families), "postings": posting,
            "packs": len(packs), "same": len(same),
            # Rebrickable's database sets in the shards, which are no sets.
            "not_sets": sorted(not_sets or []),
            # The sets with an official LDraw model (models.json): number ->
            # [its first model's file under vendor/omr/files, its page at the
            # OMR], so the page offers Open or See it without that 2 MB file.
            "models": {n: models[n] for n in order if n in (models or {})}}
    sections = [
        json.dumps(meta, separators=(",", ":")).encode(),
        "\n".join(order).encode(),
        "\n".join(str(records[n].get("n", "")).replace("\n", " ") for n in order).encode(),
        bytes(max(0, min(255, int(records[n].get("y", 0)) - 1940)) for n in order),
        _varints(sum(needs[n].values()) for n in order),
        "\n".join(pairs).encode(),
        _varints(families),
        _varints(counts),
        bytes(low), bytes(high), bytes(qty_bytes),
        _varints(over), _varints(packed), _varints(same_pairs),
    ]
    payload = b"".join(struct.pack("<I", len(s)) + s for s in sections)
    import zstandard  # the system's python3-zstandard; the app decompresses it (COMPRESSION_ZSTD)
    squeezed = zstandard.ZstdCompressor(level=22).compress(payload)
    return INDEX_MAGIC + bytes([INDEX_FORMAT, INDEX_ZSTD, 0, 0]) + struct.pack("<I", len(payload)) + squeezed


def decode_index(blob: bytes) -> dict:
    """all_sets.bin read back: {"meta", "numbers", "names", "years",
    "pieces", "needs": {set: {key: qty}}}, every set's parts put together
    again from the postings, its packs and the sets it is the same as. What
    tests/test_collection.py checks the file by; the app reads it with
    SetRanking."""
    import zstandard
    if blob[:4] != INDEX_MAGIC or blob[4] != INDEX_FORMAT or blob[5] != INDEX_ZSTD:
        raise ValueError("not an all_sets.bin of format 1")
    size = struct.unpack("<I", blob[8:12])[0]
    payload = zstandard.ZstdDecompressor().decompress(blob[12:], max_output_size=size)
    sections: list[bytes] = []
    at = 0
    while at < len(payload):
        length = struct.unpack("<I", payload[at:at + 4])[0]
        sections.append(payload[at + 4:at + 4 + length])
        at += 4 + length

    def varints(raw: bytes) -> list[int]:
        out, value, shift = [], 0, 0
        for byte in raw:
            value |= (byte & 0x7F) << shift
            shift += 7
            if byte < 0x80:
                out.append(value)
                value, shift = 0, 0
        return out

    meta = json.loads(sections[0])
    numbers = sections[1].decode().split("\n")
    pairs = sections[5].decode().split("\n")
    counts = varints(sections[7])
    low, high, qty = sections[8], sections[9], sections[10]
    over = varints(sections[11])
    big: dict[int, int] = {}
    posting = 0
    for i in range(0, len(over), 2):
        posting += over[i]
        big[posting] = over[i + 1]
    own: list[dict[str, int]] = [dict() for _ in numbers]
    posting = 0
    for key, count in zip(pairs, counts):
        number = -1
        for _n in range(count):
            number += low[posting] + (high[posting] << 8) + 1
            own[number][key] = big.get(posting, qty[posting])
            posting += 1
    packed = varints(sections[12])
    whole = [dict(o) for o in own]
    i = 0
    while i < len(packed):
        pack, many = packed[i], packed[i + 1]
        i += 2
        for _n in range(many):
            leaf, count = packed[i], packed[i + 1]
            i += 2
            for key, q in own[leaf].items():
                whole[pack][key] = whole[pack].get(key, 0) + q * count
    same = varints(sections[13])
    for i in range(0, len(same), 2):
        whole[same[i]] = dict(whole[same[i + 1]])
    return {"meta": meta, "numbers": numbers, "names": sections[2].decode().split("\n"),
            "years": [y + 1940 if y else 0 for y in sections[3]], "pieces": varints(sections[4]),
            "needs": dict(zip(numbers, whole))}


def _official_models() -> dict[str, list[str]]:
    """The official models src/dev/collection_models.gd wrote beside the
    shards (models.json), each set's first: number -> [file, OMR page]."""
    models: dict[str, list[str]] = {}
    if (OUT / "models.json").exists():
        for model in json.loads((OUT / "models.json").read_text()).get("models", []):
            models.setdefault(str(model.get("set", "")).lower(), [str(model.get("file", "")), str(model.get("g", ""))])
    return models


def write_index(records: dict[str, dict], write: bool = True,
                models: dict[str, list[str]] | None = None) -> int:
    """Write all_sets.bin from the sets' records, {number: {"n", "y", "p"}}
    as the shards hold them (only say what it would be, without [param
    write]), with [param models] (_official_models, read from the folder
    when not given). 1, writing nothing, when it would be over INDEX_MOST."""
    catalogue = json.loads((GENERATED / "catalogue.json").read_text())
    colours = json.loads((GENERATED / "colors.json").read_text())
    skip, packs = _what_sets_are()
    needs = index_needs(records, _Owning(catalogue["parts"], colours), skip)
    # How many of a set another holds, by their first inventories.
    first: dict[str, tuple[int, str]] = {}
    for row in rb._rows("inventories"):
        version = int(row["version"] or 1)
        if row["set_num"] not in first or version < first[row["set_num"]][0]:
            first[row["set_num"]] = (version, row["id"])
    owner = {inventory: number.lower() for number, (_v, inventory) in first.items()}
    times: dict[tuple[str, str], int] = {}
    for row in rb._rows("inventory_sets"):
        pack = owner.get(row["inventory_id"])
        if pack is not None:
            key = (pack, row["set_num"].lower())
            times[key] = times.get(key, 0) + int(row["quantity"])
    # The theme each set is under, by its top theme, and its era in fives.
    parent = {row["id"]: row["parent_id"] for row in rb._rows("themes")}

    def top(theme: str) -> int:
        for _hop in range(8):
            if not parent.get(theme):
                break
            theme = parent[theme]
        return int(theme or 0)

    theme_of = {row["set_num"].lower(): top(row["theme_id"]) for row in rb._rows("sets")}
    blob = encode_index(records, needs, _index_packs(needs, packs, times),
                        lambda n: (theme_of.get(n, 0), int(records[n].get("y", 0)) // 5), int(time.time()),
                        [n for n in records if n in skip], _official_models() if models is None else models)
    meta = decode_index(blob)["meta"]
    print(f"  {INDEX}: {meta['sets']:,} sets ({meta['packs']:,} packs as their sets, {meta['same']:,} the same as "
          f"another), {meta['pairs']:,} parts in a colour, {meta['postings']:,} postings, {len(blob):,} bytes")
    if len(blob) > INDEX_MOST:
        print(f"collection_data: {INDEX} would be {len(blob):,} bytes, over the {INDEX_MOST:,} the web fetches "
              "as What can I build? opens: not written", file=sys.stderr)
        return 1
    if write:
        (OUT / INDEX).write_bytes(blob)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="write nothing")
    parser.add_argument("--bricklink", action="store_true",
                        help="rewrite only index.json's bricklink_colours, from colors.json")
    parser.add_argument("--colours", action="store_true",
                        help="rewrite only the colours_NN.json, from the shards written")
    parser.add_argument("--index", action="store_true",
                        help=f"rewrite only {INDEX}, from the shards written")
    args = parser.parse_args()
    known = {entry["id"] for entry in
             json.loads((GENERATED / "catalogue.json").read_text())["parts"]}
    if args.colours or args.index:
        shards = {int(path.stem): json.loads(path.read_text())["sets"]
                  for path in sorted(OUT.glob("[0-9][0-9][0-9].json"))}
        if args.index:
            records: dict[str, dict] = {}
            for sets in shards.values():
                records.update(sets)
            return write_index(records, write=not args.check)
        write_colour_sets(shards, known)
        return 0
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
    records = {}
    for sets in shards.values():
        records.update(sets)
    if args.check:
        return write_index(records, write=False)
    OUT.mkdir(parents=True, exist_ok=True)
    # Which sets have an official model, kept from the models.json about to
    # go: collection_models.gd matches each model's parts to the new shards
    # after, but a model's set and file are its own.
    models = _official_models()
    for old in OUT.glob("*.json"):
        old.unlink()
    for number, sets in shards.items():
        (OUT / f"{number:03d}.json").write_text(
            json.dumps({"sets": sets}, separators=(",", ":")))
    (OUT / "index.json").write_text(json.dumps(index, separators=(",", ":")))
    write_colour_sets(shards, known)
    # The ranking's file is rebuilt with the shards it is made from, so the
    # daily Rebrickable data reaches What can I build? with them.
    failed = write_index(records, models=models)
    print(f"  wrote {OUT}")
    return failed


if __name__ == "__main__":
    raise SystemExit(main())
