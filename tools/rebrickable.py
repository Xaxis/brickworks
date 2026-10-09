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
from collections.abc import Callable, Iterable
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


## The sizes real sets come in, as the bands norms are measured over.
SET_BANDS = ((60, 150), (150, 350), (350, 800), (800, 1800), (1800, 5000))

## Themes whose sets are not a model of anything: a pile of parts to
## build from, a picture made of tiles, or another system's bricks.
## A set is left out if any theme above it is one of these.
##
## Decided by what the product is, never by how varied it is, because
## leaving out the thin sets for being thin would move the threshold
## for thinness.  What it fixes was measured: the thinnest twenty sets
## of 1,800 parts or more were mosaics, LEGO Art and bulk tubs, so the
## fifth percentile of shapes there was 21 — where the median is 240 —
## and a 1,828-part castle with 30 shapes was never told it was thin.
NOT_A_MODEL = frozenset({
    "Universal Building Set", "Educational and Dacta", "Service Packs",
    "Supplemental", "Bulk Bricks", "Make & Create", "Classic", "DOTS",
    "LEGO Art", "Mosaic", "Brick Sketches", "Database Sets",
    "FIRST LEGO League", "Collectible Minifigures", "Gear", "Books",
    "Duplo", "Primo", "Quatro", "Soft Bricks", "Jumbo Bricks", "Scala",
    "Clikits", "Modulex", "Znap",
})
## And the same said in a set's name, for the ones filed elsewhere:
## LEGO put its bulk tubs under Creator in the 2000s, and a mosaic of a
## film character goes under the film.
NAMED_NOT_A_MODEL = frozenset({"mosaic", "bucket", "tub", "canister", "bulk"})


def _models() -> set[str]:
    """The set numbers whose product is a model."""
    themes = {r["id"]: (r["name"], r["parent_id"]) for r in _rows("themes")}

    def is_model(theme: str) -> bool:
        while theme:
            name, theme = themes.get(theme, ("", ""))
            if name in NOT_A_MODEL:
                return False
        return True

    def named_one(name: str) -> bool:
        return not NAMED_NOT_A_MODEL.isdisjoint(
            re.split(r"[^a-z0-9]+", name.lower()))

    return {r["set_num"] for r in _rows("sets")
            if is_model(r["theme_id"]) and not named_one(r["name"])}


def set_norms() -> dict:
    """What a real LEGO set of a given size is actually made of.

    The checker can say whether a model stands up.  It cannot say
    whether it reads as a set, and that judgement was resting on taste.
    This measures it instead, over every catalogued set: how many
    distinct part-and-colour lots a set of five hundred parts has, how
    many different shapes, and how many of one part is normal.

    The numbers are worth stating plainly because they are not what a
    designer guesses.  A real five hundred part set has about a hundred
    and forty lots and a hundred different shapes, and its most repeated
    part appears about twenty times — where a model built to be merely
    buildable will happily use eighty-six of one brick.

    Spare parts are left out: they are packaging, not design.  Only the
    first version of each inventory is counted, so a set revised later
    is one set.  And only models: see NOT_A_MODEL.
    """
    models = _models()
    inventories = {r["id"]: r["set_num"] for r in _rows("inventories")
                   if r["version"] == "1" and r["set_num"] in models}
    per_set: dict[str, list] = {}
    for row in _rows("inventory_parts"):
        set_num = inventories.get(row["inventory_id"])
        if set_num is None or row["is_spare"] != "False":
            continue
        per_set.setdefault(set_num, []).append(
            (row["part_num"], row["color_id"], int(row["quantity"])))

    def at(values: list[float], share: float) -> float:
        """The value this far along the sorted list, 0.5 being the median."""
        if not values:
            return 0.0
        values.sort()
        return values[min(len(values) - 1, int(len(values) * share))]

    def middle(values: list[float]) -> float:
        return at(values, 0.5)

    bands = []
    for low, high in SET_BANDS:
        lots, shapes, most, colours, accents = [], [], [], [], []
        for items in per_set.values():
            total = sum(q for _, _, q in items)
            if not (low <= total < high):
                continue
            lots.append(float(len(items)))
            shapes.append(float(len({p for p, _, _ in items})))
            most.append(float(max(q for _, _, q in items)))
            colours.append(float(len({c for _, c, _ in items})))
            # Shapes a set uses only once or twice.  This is where most
            # of a set's variety is: a real set of 1,100 parts has some
            # 177 shapes and 85 of them are one or two of a part, where
            # the best castle built here had 71 and 21.  The shapes used
            # many times were close; the gap was nearly all of this.
            per_part: dict[str, int] = {}
            for p, _, q in items:
                per_part[p] = per_part.get(p, 0) + q
            accents.append(float(sum(1 for q in per_part.values() if q <= 2)))
        if len(lots) < 25:          # too few to be a norm
            continue
        # The medians say what a real set of this size is like, and are
        # what a designer wants told.  The tails are what a *check* must
        # use, and that distinction cost something: thresholds set at
        # six tenths of the median and twice the median fired on 29-34%
        # of real LEGO sets, band by band.  A third of real sets told
        # they are repetitive is noise, not advice.
        #
        # The fifth and ninety-fifth bring it to 8.5-10%, and catch
        # models/station.ldr, whose thirty shapes sit at the 1.1st
        # percentile of real models and whose eighty-six of one brick at
        # the 95.8th.  Measured with the mosaics still in, the thirty
        # shapes sat at the 4.2nd and the second and ninety-eighth missed
        # it on both counts.
        bands.append({
            "from": low, "to": high, "sets": len(lots),
            "lots": round(middle(lots)),
            "shapes": round(middle(shapes)),
            "most_of_one": round(middle(most)),
            "colours": round(middle(colours)),
            "lots_thin": round(at(lots, 0.05)),
            "shapes_thin": round(at(shapes, 0.05)),
            "colours_thin": round(at(colours, 0.05)),
            "most_of_one_high": round(at(most, 0.95)),
            "accents": round(middle(accents)),
        })
    return {"source": "Rebrickable set inventories", "bands": bands}


# Words in a set's name that say nothing about what it is: product
# lines, packaging, sizes, and the colours a set happens to be named for.
# A kind has to be a thing somebody builds.
NOT_A_KIND = set("""
the a an and or of with for in on at to from set mini micro midi maxi
build buildable ii iii jr junior polybag promo pack edition exclusive
series collection value kit box bag blister foil card cards sticker
stickers magnet keychain key chain backpack pencil pen eraser case
bucket tub canister shoes shoe watch clock lamp torch light up bricks
brick lego duplo belville scala znap primo quatro fabuland modulex
accessory accessories figure figures minifigure minifig polybags
exclusive limited anniversary special promotional giveaway sample
assorted miscellaneous other spare spares replacement part parts piece
pieces random bulk lot lots sealed new used complete incomplete
red blue green yellow black white grey gray orange purple pink brown
tan silver gold bronze clear trans transparent light dark bright medium
sand metallic pearl classic basic creator ideas super world movie
adidas nike levi puma reebok vans converse
large small big giant huge tiny first second final ultimate deluxe
starter grand great opening play playset fun creative challenge
version variant alternate battle attack defence defense chase rescue
team man woman boy girl kids adult plates baseplate calendar advent
mobile portable transformable buildable collectible display
""".split())

# Why this is a word list and not a measurement.  A kind whose parts are
# not distinctive ought to be the useless one, and it is not: measured
# over all 367, "play" tops out at 190x and "version" at 121x — above
# castle's 26 — while farm is 3.3, car 4.2 and fire 4.5.  A lift
# threshold deletes farm and car and keeps play.  "A kind of thing
# somebody builds" is a meaning, and the meaning is not in the
# inventories.  It mattered because a brief like "a large castle"
# matched both and the most specific-looking kind goes first, so the
# useless word outranked the real one.

# Categories that are never an answer to "what is this built from":
# decals, retired numbers, and another product line's bricks.
NOT_A_PART = {"Sticker", "Sticker Shortcut", "Moved", "Obsolete",
              "Duplo", "Figure"}
# And the ones that are what a set carries rather than what it is made
# of.  A pirate set really does have four cutlasses, and a designer
# asking what a pirate set is built from should not be told about them
# first: measured, swords and flintlocks took the top four places and
# the hull and the barrels came after.
A_PROP = {"Minifig", "Minifig Accessory", "Minifig Headwear", "Animal"}

## How many sets a kind has to cover before it is a kind at all, and how
## much of a kind's sets a part has to be in before it is characteristic
## of it rather than an accident of one set.
KIND_FLOOR = 20
PART_FLOOR = 0.15
## How many of a kind's most used parts to keep, by how many of its sets
## use them rather than by lift.  See kinds().  Forty was used up: a
## castle told about them came out with 37 of the 40, so a pass now
## reaches down the list as the top of it is used.
COMMON = 100
REAL_MODEL = 20          # parts; below this a "set" is merchandise


def kinds(entries: list[dict], ldraw_colours: list[dict]) -> dict:
    """What real sets of a kind are actually built from.

    The prompt can tell a designer to tile a roof and curve a bonnet.
    It cannot tell it that castle sets reach for 40066, the arch panel,
    sixty-five times as often as sets at large do, and build in tan and
    pearl gold; that space sets reach for brackets, antennas and
    cut-corner wedge plates in white and light grey; that a tractor is
    Technic gears and bent beams.  Nothing in this project knew that,
    and thirty thousand set inventories do.

    A "kind" is a word in a set's name — castle, fire, space, tractor,
    pirate, train — which is crude and is also what a brief says.  What
    makes it useful is lift rather than count: the parts a kind reaches
    for *more than other kinds do*, so the answer is what is
    characteristic and not the plates every set is made of.

    Only sets of REAL_MODEL parts or more, or the kinds are keychains
    and backpacks.  Only parts that join to an LDraw id, because a part
    this app cannot place is not a recommendation.  Only colours with an
    LDraw code, for the same reason.

    Returns {"kinds": {word: {"sets": n, "parts": [[ldraw id, lift]],
    "colors": [[code, lift]], "props": [[ldraw id, lift]]}}, ...}.
    """
    import collections
    import re

    codes = colour_codes(ldraw_colours)
    other_line = _lines()
    ldraw_of: dict[str, str] = {}
    a_prop: dict[str, bool] = {}
    for entry in entries:
        if entry.get("category") in NOT_A_PART:
            continue
        a_prop[entry["id"]] = entry.get("category") in A_PROP
    seen, _newest = _seen()
    match = _matcher(seen)
    for entry in entries:
        if entry["id"] not in a_prop:
            continue
        found = match(entry)
        # Another product line's brick is not an answer either, and
        # LDraw files Duplo train track under Train: "train" came back
        # led by two Duplo tracks at seventy times the base rate.
        if found is not None and found not in ldraw_of \
                and other_line.get(found) is None:
            ldraw_of[found] = entry["id"]

    # A castle mosaic or a castle bucket is not how a castle is built.
    models = _models()
    big = {r["set_num"]: r["name"] for r in _rows("sets")
           if r["num_parts"] and int(r["num_parts"]) >= REAL_MODEL
           and r["set_num"] in models}
    inventories = {r["id"]: r["set_num"] for r in _rows("inventories")
                   if r["version"] == "1" and r["set_num"] in big}
    per_set: dict[str, list] = {}
    for row in _rows("inventory_parts"):
        set_num = inventories.get(row["inventory_id"])
        if set_num is None or row["is_spare"] != "False":
            continue
        per_set.setdefault(set_num, []).append(
            (row["part_num"], int(row["color_id"]), int(row["quantity"])))

    words: dict[str, list[str]] = {}
    for set_num in per_set:
        for word in re.split(r"[^a-z0-9]+", big[set_num].lower()):
            if len(word) >= 3 and word not in NOT_A_KIND and not word.isdigit():
                words.setdefault(word, []).append(set_num)
    words = {w: s for w, s in words.items() if len(s) >= KIND_FLOOR}

    # What every kind does, to divide out of what one kind does.
    everywhere: collections.Counter = collections.Counter()
    colour_everywhere: collections.Counter = collections.Counter()
    all_pieces = 0
    for items in per_set.values():
        # Sets, not lots: a set with the 1 x 2 plate in four colours is
        # one set that uses it.  Counted by lot, the castle's "share" of
        # 1 x 2 plates came to 346%, and the 15% floor below was a floor
        # on lots.
        for part in {p for p, _c, _q in items}:
            everywhere[part] += 1
        for part, colour, quantity in items:
            colour_everywhere[colour] += quantity
            all_pieces += quantity
    sets_total = len(per_set)

    out: dict[str, dict] = {}
    for word, members in words.items():
        in_sets: collections.Counter = collections.Counter()
        colours: collections.Counter = collections.Counter()
        pieces = 0
        for set_num in members:
            for part in {p for p, _c, _q in per_set[set_num]}:
                in_sets[part] += 1
            for _p, colour, quantity in per_set[set_num]:
                colours[colour] += quantity
                pieces += quantity
        if not pieces:
            continue
        floor = max(3, int(len(members) * PART_FLOOR))
        ranked: list[tuple[float, str]] = []
        props: list[tuple[float, str]] = []
        for part, count in in_sets.items():
            if count < floor or part not in ldraw_of:
                continue
            base = everywhere[part] / sets_total
            if base <= 0:
                continue
            lift = round((count / len(members)) / base, 1)
            # A part no more common here than anywhere else says nothing
            # about the kind.  Without this the thinner kinds padded
            # their twelve out with ordinary plates: 68 entries across
            # the 367 kinds, every one of them true and useless.
            if lift <= 1.0:
                continue
            id_of = ldraw_of[part]
            (props if a_prop[id_of] else ranked).append((lift, id_of))
        ranked.sort(reverse=True)
        props.sort(reverse=True)
        tinted = []
        for colour, quantity in colours.items():
            code = codes.get(colour)
            if code is None or quantity < pieces * 0.01:
                continue
            base = colour_everywhere[colour] / all_pieces
            if base <= 0:
                continue
            lift = round((quantity / pieces) / base, 1)
            if lift <= 1.0:               # as above, for the palette
                continue
            tinted.append((lift, code))
        tinted.sort(reverse=True)
        if not ranked:
            continue
        # And what most of them use at all, which lift cannot say.  Lift
        # finds what makes a castle a castle; a castle of 1,895 parts also
        # has some 260 shapes, and most of them are ordinary — the 1 x 2
        # plate is in 80% of castle sets.  Measured on the best castle the
        # assistant had built: 24 of the 40 parts castle sets use most,
        # missing the 1 x 1 and 2 x 3 plates, both jumpers and both cheese
        # slopes, each in more than half of them.
        common = []
        for part, count in in_sets.most_common():
            if part not in ldraw_of or a_prop[ldraw_of[part]]:
                continue
            common.append([ldraw_of[part], round(100 * count / len(members))])
            if len(common) == COMMON:
                break
        out[word] = {
            "sets": len(members),
            "parts": [[part, lift] for lift, part in ranked[:12]],
            "colors": [[code, lift] for lift, code in tinted[:6]],
            "common": common,
        }
        if props:
            out[word]["props"] = [[part, lift] for lift, part in props[:5]]
    return {"source": "Rebrickable set inventories",
            "measured_over": sets_total, "kinds": out}


def elements(entries: list[dict], ldraw_colours: list[dict]) -> dict:
    """LDraw part and colour -> the LEGO element number you would order.

    A design is not orderable until each line of its parts list names a
    real element.  "Brick 2x4 in Bright Red" is a description; 300521 is
    the thing a warehouse picks.  Rebrickable's elements table carries
    them, keyed by their part number and colour.

    Returns {"pairs": {"<id>/<code>": "<element>"}, "counts": {...}}.
    Only exact and corroborated matches go in: ordering the wrong brick
    is worse than ordering from a description, so a part whose number
    only matches after a mould suffix is dropped has to agree by name
    as well, exactly as availability() requires.
    """
    codes = colour_codes(ldraw_colours)
    rb_name = {r["part_num"]: r["name"] for r in _rows("parts")}

    ## Rebrickable spelling -> the LDraw entry it belongs to.
    exact: dict[str, dict] = {}
    loose: dict[str, dict] = {}
    whole: dict[str, dict] = {e["id"].lower(): e for e in entries}
    for entry in entries:
        if not _guessable(entry):
            continue
        low = entry["id"].lower()
        exact.setdefault(low, entry)
        exact.setdefault(low.lstrip("0") or low, entry)
        bare = _bare(low)
        if bare != low and bare not in loose:
            loose[bare] = entry

    # Which moulding a bare number means, according to LDraw rather than
    # according to the alphabet.  3023a and 3023b are both "Plate 1 x 2"
    # and both reduce to 3023, so the first one seen took the number and
    # every 3023 element went to 3023a — while every model in the repo
    # uses 3023b.  LDraw settles it: part 3023 is "~Moved to 3023b", so
    # the redirect names the current part and the guess becomes a fact.
    for entry in entries:
        target = entry.get("moved_to")
        if not target:
            continue
        current = whole.get(target.lower())
        if current is not None and _guessable(current):
            low = entry["id"].lower()
            loose[low] = current
            loose[low.lstrip("0") or low] = current

    pairs: dict[str, str] = {}
    how = {"exact": 0, "by mould variant": 0, "no colour": 0, "no part": 0}
    for row in _rows("elements"):
        code = codes.get(int(row["color_id"] or -1))
        if code is None:
            how["no colour"] += 1
            continue
        entry = None
        route = "exact"
        for candidate in (row["part_num"], row["design_id"]):
            if not candidate:
                continue
            entry = exact.get(candidate.lower())
            if entry is not None:
                break
            guess = loose.get(candidate.lower())
            if guess is not None and _agrees(
                    guess.get("name", ""), rb_name.get(row["part_num"], "")):
                entry = guess
                route = "by mould variant"
                break
        if entry is None:
            how["no part"] += 1
            continue
        key = "%s/%d" % (entry["id"], code)
        if key not in pairs:
            pairs[key] = row["element_id"]
            how[route] += 1
    return {"source": "Rebrickable elements", "counts": how, "pairs": pairs}


def _matcher(rb_parts: Iterable[str]) -> Callable[[dict], str | None]:
    """An LDraw catalogue entry -> the Rebrickable part it is, or None.

    The one join between the two libraries.  Two readers want it — which
    colours a part was moulded in, and how many sets it is in — and two
    copies of a join drift apart, so it is built once here.

    Every spelling of a Rebrickable part that an LDraw id might use.  The
    loose index keeps the shortest candidate for each key, which is the
    undecorated base part when there is one; picking whichever row came
    first gave a printed tile some sibling print's colours.
    """
    other_line = _lines()
    _line_of = other_line.get
    rb_name = {r["part_num"]: r["name"] for r in _rows("parts")}
    direct: dict[str, str] = {}
    loose: dict[str, str] = {}
    for part in rb_parts:
        low = part.lower()
        direct.setdefault(low, part)
        direct.setdefault(low.lstrip("0") or low, part)
        if not PLAIN.match(low) or _line_of(part) is not None:
            continue
        key = _bare(part)
        if key not in loose or len(part) < len(loose[key]):
            loose[key] = part

    def match(entry: dict) -> str | None:
        if not _guessable(entry):
            return None
        low = entry["id"].lower()
        found = direct.get(low) or direct.get(low.lstrip("0") or low)
        if found is not None:
            return found
        guess = loose.get(_bare(entry["id"]))
        if guess and _agrees(entry.get("name", ""), rb_name.get(guess, "")):
            return guess
        return None

    return match


def usage(entries: list[dict]) -> dict:
    """How many catalogued sets each part is really in.

    Returns {ldraw id: sets}, and only for the parts that join, because
    a part with no entry is one nobody has data about rather than one
    nobody used.  Four fifths of the LDraw library is in that position,
    so an absence may never be read as "never used": this promotes the
    parts known to be staples and says nothing at all about the rest.

    Filling the gap with explicit zeros, so that a part Rebrickable
    knows and no set contains could be pushed down, was written and
    measured and taken out.  It moved 221 parts and changed no ranking.

    Why it is worth having: a search ranked by what a name looks like
    led "round brick 1 x 1" with 71075a, which is in seventeen sets,
    over 3062b, which is in four and a half thousand — and both are
    named like the ordinary thing.  A name cannot tell you that.  Thirty
    thousand set inventories can.

    Spare parts are left out and only the first version of each
    inventory is counted, the same way set_norms does it, so a set
    revised later is one set.
    """
    inventories = {r["id"]: r["set_num"] for r in _rows("inventories")
                   if r["version"] == "1"}
    in_sets: dict[str, set] = {}
    for row in _rows("inventory_parts"):
        set_num = inventories.get(row["inventory_id"])
        if set_num is None or row["is_spare"] != "False":
            continue
        in_sets.setdefault(row["part_num"], set()).add(set_num)
    counts = {part: len(sets) for part, sets in in_sets.items()}
    match = _matcher(counts)
    out: dict[str, int] = {}
    for entry in entries:
        found = match(entry)
        if found is not None:
            out[entry["id"]] = counts[found]
    # A redirect is not a dead end, for the same reason as in
    # availability: the target's count is exactly this part's count.
    for entry in entries:
        target = entry.get("moved_to")
        if target and target in out and entry["id"] not in out:
            out[entry["id"]] = out[target]
    return out


def availability(entries: list[dict], ldraw_colours: list[dict]) -> dict:
    """Join the two libraries.

    Returns {"recent_since": year, "parts": {ldraw id: {"colors": [...],
    "colors_recent": [...], "years": [first, last]}}, "counts": {...}}.
    Only matched parts appear; the rest are unknown and get no entry.
    """
    codes = colour_codes(ldraw_colours)
    seen, newest = _seen()
    recent_since = newest - RECENT_YEARS

    matched = _matcher(seen)
    parts: dict[str, dict] = {}
    how = {"matched": 0, "unknown": 0, "not a part": 0}
    for entry in entries:
        part_id = entry["id"]
        if not _guessable(entry):
            how["not a part"] += 1
            continue
        match = matched(entry)
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

        how["matched"] += 1
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
