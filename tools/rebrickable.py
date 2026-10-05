#!/usr/bin/env python3
"""What LEGO actually made, as opposed to what LDraw can draw.

LDraw models geometry.  It has no idea what was ever moulded, so it will
happily render a 4x12 wedge plate in sand green that never existed, and
a designer following that picture gets a parts list they cannot buy.

Rebrickable publishes the other half: every set inventory ever catalogued,
part by part and colour by colour.  Joining the two gives, for each part
we can draw, the colours it was really made in and the years it appeared.

The join is the whole difficulty.  The two projects number parts and name
colours independently, so this matches on normalised names, then on exact
RGB, then on part numbers stripped of print and mould suffixes.  Anything
unmatched stays *unknown*, and unknown must read as silence everywhere
downstream: half the library has no inventory data, and a checker that
turns silence into "that colour does not exist" is worse than no checker.

Reads vendor/rebrickable/*.csv.gz (tools/fetch_data.sh).  Nothing here is
redistributed; the index is derived locally.
"""

from __future__ import annotations

import csv
import gzip
import io
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
VENDOR = ROOT / "vendor" / "rebrickable"

# How far back still counts as "you could plausibly buy this".  LEGO
# retires colours and parts continuously; a part last seen in a 1994 set
# is history, not a shopping list.
RECENT_YEARS = 12


def _rows(table: str) -> list[dict[str, str]]:
    path = VENDOR / f"{table}.csv.gz"
    if not path.exists():
        raise FileNotFoundError(f"{path} missing — run tools/fetch_data.sh")
    with gzip.open(path, "rb") as raw:
        text = io.TextIOWrapper(raw, encoding="utf-8", newline="")
        return list(csv.DictReader(text))


def _plain(name: str) -> str:
    """A colour name reduced to what both projects agree on.

    LDraw writes "Dark_Bluish_Gray", Rebrickable "Dark Bluish Gray", and
    one of them spells several colours the British way.
    """
    name = name.lower().replace("gray", "grey")
    return re.sub(r"[^a-z0-9]", "", name)


# What an *undecorated* part is numbered like: an optional u or x prefix,
# digits, an optional single mould letter, an optional assembly suffix.
# 3001, 3069b, 43722a, 11293c01.
#
# Everything else carries a decoration marker — 3068bpfy, 3070bp60,
# 973pyx, 4858d02 — and exists only in the colour it was printed on.
# Testing for the plain shape is the only reliable way round: a first
# attempt listed the decoration markers instead, required a digit before
# the "p", and so read 3068bpfy as a plain 2x2 tile.
PLAIN = re.compile(r"^[ux]?\d+[a-z]?(c\d+)?$")

# One trailing letter and nothing after it: a mould variant.  3069a and
# 3069b are both the 1x2 tile, one with a groove; 3626a/b/c are the three
# minifig head mouldings.  Collapsing those is safe.  A "c01" assembly
# suffix is not: 17454c01 is a windscreen *in a frame*, and dropping the
# suffix matched it to a train front.
MOULD = re.compile(r"^(.*?\d)[a-z]$")

# Other product lines that number their parts in the same range.  LDraw
# part 2710 is a Technic figure body; Rebrickable 2710L is a Modulex
# 10x10 brick, and one letter of suffix is all that separates them.
OTHER_LINES = ("duplo", "modulex", "primo", "znap", "quatro", "fabuland",
               "scala", "belville", "mursten", "galidor")


def _bare(part: str) -> str:
    """A part number with a mould-variant suffix removed, or itself.

    Leading zeros are *not* stripped.  LDraw numbers sticker sheets with
    them, and "004324b" is a sticker, not part 4324 — which is a Fabuland
    rake.  Stripping them matched hundreds of parts to unrelated bricks.
    """
    stem = part.lower()
    hit = MOULD.match(stem)
    return hit.group(1) if hit else stem


def _guessable(entry: dict) -> bool:
    """Whether this catalogue entry is a part a buyer could hold.

    Redirects ("~Moved to 3068bp10"), aliases and obsolete subparts are
    bookkeeping inside the library, and a sticker's colour is its sheet,
    not a moulding.  Guessing availability for any of them puts another
    brick's colours on the screen.
    """
    if entry.get("moved_to"):
        return False
    if entry.get("name", "")[:1] in ("~", "="):
        return False
    if entry.get("category", "").startswith("Sticker"):
        return False
    return bool(PLAIN.match(entry["id"].lower()))


def colour_codes(ldraw_colours: list[dict]) -> dict[int, int]:
    """Rebrickable colour id -> LDraw colour code.

    By name first, because names are what both projects curate, then by
    exact RGB for the ones named differently.  A Rebrickable colour that
    matches neither is dropped: guessing a colour is how a designer ends
    up told a part comes in a shade it does not.
    """
    by_name: dict[str, int] = {}
    by_rgb: dict[str, int] = {}
    for colour in ldraw_colours:
        code = int(colour["code"])
        by_name.setdefault(_plain(colour["name"]), code)
        red, green, blue = colour["rgb"]
        by_rgb.setdefault("%02x%02x%02x" % (red, green, blue), code)

    codes: dict[int, int] = {}
    for row in _rows("colors"):
        rb = int(row["id"])
        if rb < 0:                       # [Unknown] and [No Colour]
            continue
        hit = by_name.get(_plain(row["name"]))
        if hit is None:
            hit = by_rgb.get(row["rgb"].strip().lower())
        if hit is not None:
            codes[rb] = hit
    return codes


def _years() -> dict[str, int]:
    """Rebrickable inventory id -> the year of the set it belongs to."""
    year_of_set = {r["set_num"]: int(r["year"]) for r in _rows("sets") if r["year"]}
    years: dict[str, int] = {}
    for row in _rows("inventories"):
        year = year_of_set.get(row["set_num"])
        if year:
            years[row["id"]] = year
    return years


def _seen() -> tuple[dict[str, dict[int, tuple[int, int]]], int]:
    """Rebrickable part -> {colour id: (first year, last year)}, and the latest year.

    Set inventories are the broad signal: 1.5 million rows covering every
    catalogued set.  elements.csv is the narrow one — the parts with a
    known LEGO element number — and it carries no year, so a pair known
    only from there gets a window of (0, 0), meaning "made, year unknown".
    """
    year_of = _years()
    newest = max(year_of.values(), default=0)
    seen: dict[str, dict[int, tuple[int, int]]] = {}
    for row in _rows("inventory_parts"):
        colour = int(row["color_id"])
        if colour < 0:
            continue
        year = year_of.get(row["inventory_id"], 0)
        colours = seen.setdefault(row["part_num"], {})
        first, last = colours.get(colour, (0, 0))
        colours[colour] = (
            min(first, year) if first and year else (year or first),
            max(last, year),
        )
    for row in _rows("elements"):
        colour = int(row["color_id"] or -1)
        if colour < 0:
            continue
        for part in (row["part_num"], row["design_id"]):
            if part:
                seen.setdefault(part, {}).setdefault(colour, (0, 0))
    return seen, newest


def _agrees(ldraw: str, rebrickable: str) -> bool:
    """Whether two descriptions of a part are describing the same part.

    A mould-variant match is a guess, so it has to be corroborated, and
    the only other thing both projects hold is the name.  Sharing one
    real word is a low bar deliberately: the cost of refusing a good
    match is silence about one part, and the cost of accepting a bad one
    is telling a designer that an electric motor comes in sand green.
    """
    def words(text: str) -> set[str]:
        return {w for w in re.split(r"[^a-z0-9]+", text.lower()) if len(w) >= 4}
    return bool(words(ldraw) & words(rebrickable))


def _lines() -> dict[str, str]:
    """Rebrickable part -> the product line its name starts with.

    LDraw part 2710 is a Technic figure body; Rebrickable 2710L is a
    Modulex 10x10 brick.  Only the names say so, so the names are what
    has to be read.
    """
    lines: dict[str, str] = {}
    for row in _rows("parts"):
        first = row["name"].split()[0].strip(",/").lower() if row["name"] else ""
        if first in OTHER_LINES:
            lines[row["part_num"]] = first
    return lines


def availability(entries: list[dict], ldraw_colours: list[dict]) -> dict:
    """Join the two libraries.

    Returns {"recent_since": year, "parts": {ldraw id: {"colors": [...],
    "colors_recent": [...], "years": [first, last]}}, "counts": {...}}.
    Only matched parts appear; the rest are unknown and get no entry.
    """
    codes = colour_codes(ldraw_colours)
    seen, newest = _seen()
    other_line = _lines()
    _line_of = other_line.get
    rb_name = {r["part_num"]: r["name"] for r in _rows("parts")}
    recent_since = newest - RECENT_YEARS

    # Every spelling of a Rebrickable part that an LDraw id might use.
    # The loose index keeps the shortest candidate for each key, which is
    # the undecorated base part when there is one; picking whichever row
    # came first gave a printed tile some sibling print's colours.
    direct: dict[str, str] = {}
    loose: dict[str, str] = {}
    for part in seen:
        low = part.lower()
        direct.setdefault(low, part)
        direct.setdefault(low.lstrip("0") or low, part)
        if not PLAIN.match(low) or _line_of(part) is not None:
            continue
        key = _bare(part)
        if key not in loose or len(part) < len(loose[key]):
            loose[key] = part

    parts: dict[str, dict] = {}
    how = {"direct": 0, "loose": 0, "unknown": 0, "not a part": 0}
    for entry in entries:
        part_id = entry["id"]
        if not _guessable(entry):
            how["not a part"] += 1
            continue
        low = part_id.lower()
        match = direct.get(low) or direct.get(low.lstrip("0") or low)
        route = "direct"
        if match is None:
            guess = loose.get(_bare(part_id))
            if guess and _agrees(entry.get("name", ""), rb_name.get(guess, "")):
                match = guess
            route = "loose"
        if match is None:
            how["unknown"] += 1
            continue

        ever: list[int] = []
        lately: list[int] = []
        first_year = 0
        last_year = 0
        unnamed = 0
        for rb_colour, (first, last) in seen[match].items():
            code = codes.get(rb_colour)
            if code is None:
                unnamed += 1
                continue
            ever.append(code)
            if last >= recent_since:
                lately.append(code)
            if first:
                first_year = min(first_year, first) if first_year else first
            last_year = max(last_year, last)
        if not ever:
            how["unknown"] += 1
            continue

        how[route] += 1
        made: dict[str, object] = {
            "colors": sorted(set(ever)),
            "colors_recent": sorted(set(lately)),
            "years": [first_year, last_year],
        }
        # Sixty-nine Rebrickable colours have no LDraw name — BrickLink's
        # "Dark Purple" is LEGO's "Medium Lilac", and the two swatches are
        # too far apart to match on RGB.  Nothing here guesses at them, so
        # a part made in one of them has a list that is right as far as it
        # goes and silent beyond.  Whoever reads it must not read a gap in
        # a partial list as proof the colour was never made.
        if unnamed:
            made["colors_partial"] = True
        parts[part_id] = made

    # A redirect is not a dead end.  "43722" is the wedge plate 2x3 right,
    # renamed to "43722a" when a second moulding appeared, and the AI will
    # write either number.  The target's colours are exactly right for it,
    # and following the pointer is not a guess.
    for entry in entries:
        target = entry.get("moved_to")
        if target and target in parts and entry["id"] not in parts:
            parts[entry["id"]] = parts[target]
            how["redirect"] = how.get("redirect", 0) + 1

    how["partial"] = sum(1 for m in parts.values() if m.get("colors_partial"))
    return {
        "source": "Rebrickable set inventories",
        "recent_since": recent_since,
        "colours_mapped": len(codes),
        "counts": how,
        "parts": parts,
    }
