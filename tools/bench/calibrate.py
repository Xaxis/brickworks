"""Pairs whose answer is known, to measure the pairwise judge before it measures anything.

Two kinds, each a model and a version of it that is worse in a way nobody
would argue with:

- **A real set against a naive stack of itself.** The set's own shape,
  filled a stud by a brick with plain bricks, studs up everywhere, in its
  three commonest colours, with no shaping (what the bench's naive car
  anchor is). The set should win every visual dimension and overall.
- **One of our designs against itself with one fault put in.** Its tiles
  taken off, so its studs are bare (surface and overall), or one tile in
  four, the fault at a quarter of its size; every part in its commonest
  colour (colour and overall); its figures and animals taken out
  (creativity). The design as it was should win those.

Both sides of a pair are drawn by the same renderer on the same code, so
the fault is the only difference the judge can see. What each pair should
say, and on which dimensions, is `PAIRS`; the reading of the answers is
`pairwise.agreement`.
"""

from __future__ import annotations

import json
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import style

COLOURS = Path(__file__).resolve().parents[2] / "assets" / "generated" / "colors.json"

# A cell of the naive stack: one 1 x 1 brick, LDraw units.
STUD, BRICK = 20.0, 24.0
# Sample points in a cell (2 x 3 x 2); the cell is filled when half are inside a part.
_FRACTIONS_XZ = (0.25, 0.75)
_FRACTIONS_Y = (1 / 6, 0.5, 5 / 6)
FILLED = 6
# Plain bricks the stack is laid in, largest first: (studs along x, along z, part).
BRICKS = ((4, 2, "3001"), (2, 4, "3001"), (2, 2, "3003"), (4, 1, "3010"), (1, 4, "3010"),
          (3, 1, "3622"), (1, 3, "3622"), (2, 1, "3004"), (1, 2, "3004"), (1, 1, "3005"))
TURNED = "0 0 1 0 1 0 -1 0 0"      # a quarter turn about the vertical
SQUARE = "1 0 0 0 1 0 0 0 1"


@dataclass(frozen=True, slots=True)
class Pair:
    """One known pair: what to make of what, and which dimensions it must win."""

    id: str
    kind: str
    subject: str            # the suite's subject whose brief and references it is judged by
    source: str             # an OMR set ("75895-1") or a design ("2026-10-13-steps/corner_shop/1")
    fault: str              # "naive", "bare studs", "some studs bare", "one colour", "no figures"
    dims: tuple[str, ...]


VISUAL = ("likeness", "surface", "colour", "technique", "creativity", "overall")
REAL = "a real set against a naive stack of itself"
FAULT = "a design against itself with a fault put in"

# Which dimensions each fault must lose. Overall is claimed only where the
# fault is plain enough that no designer would ship the faulty one.
FAULTS: dict[str, tuple[str, ...]] = {
    "naive": VISUAL,
    "bare studs": ("surface", "overall"),
    "some studs bare": ("surface", "overall"),
    "one colour": ("colour", "overall"),
    "no figures": ("creativity",),
}

_SETS = (("75895-1", "speed_champions"), ("10194-1", "steam_locomotive"),
         ("6286-1", "sailing_ship"), ("10281-1", "bonsai"), ("75102-1", "starfighter"))
_ALL = ("bare studs", "some studs bare", "one colour", "no figures")
_DESIGNS = (("2026-10-13-steps/corner_shop/1", _ALL),
            ("2026-10-13-steps/starfighter/1", _ALL),
            ("2026-10-14-sides/steam_locomotive/1", _ALL),
            ("2026-10-14-shapes/speed_champions/1", _ALL),
            # The owl has one figure, a mouse: too little to take out.
            ("2026-10-14-sides/barn_owl/1", ("bare studs", "some studs bare", "one colour")))


def _slug(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", text.lower()).strip("_")


PAIRS: tuple[Pair, ...] = (
    *(Pair(f"{number}_naive", REAL, subject, number, "naive", FAULTS["naive"])
      for number, subject in _SETS),
    *(Pair(f"{source.split('/')[1]}_{_slug(fault)}", FAULT, source.split("/")[1], source, fault,
           FAULTS[fault])
      for source, faults in _DESIGNS for fault in faults),
)


# -- what a part is ---------------------------------------------------------


def _info(parts: style.Parts, part: str, model: style.Model) -> style.PartInfo | None:
    return parts.get(part, model.embedded)


def is_tile(info: style.PartInfo | None) -> bool:
    """A tile that covers studs: not an inverted one, which holds what is under it."""
    return bool(info) and info.category == "Tile" and "inverted" not in info.name.lower()


def is_figure(info: style.PartInfo | None) -> bool:
    if not info:
        return False
    return bool(re.match(r"(minifig|figure|animal)", info.category, re.I)
                or re.match(r"(minifig|figure)\b", info.name, re.I))


# -- a design with a fault put in -------------------------------------------


def _submodels(text: str) -> set[str]:
    return {style.normalise_filename(line.split(None, 2)[2])
            for line in text.splitlines()
            if re.match(r"\s*0\s+FILE\s+", line, re.I) and len(line.split(None, 2)) > 2}


def _part_lines(text: str):
    """Each line, and for a line that places a part (not a sub-model) its part id."""
    inside = _submodels(text)
    for line in text.splitlines():
        bits = line.split()
        if len(bits) >= 15 and bits[0] == "1":
            name = style.normalise_filename(" ".join(bits[14:]))
            if name not in inside:
                yield line, bits, style._part_id(name)
                continue
        yield line, None, None


def _header(text: str, what: str) -> str:
    return f"0 {what}\n0 Name: calibration.ldr\n0 Author: Brickworks design bench\n\n" + text


def without(text: str, parts: style.Parts, drop) -> tuple[str, int]:
    """The model with every part `drop(info)` is true of taken out, and how many went."""
    model = style.read(text)
    kept, gone = [], 0
    for line, bits, part in _part_lines(text):
        if part is not None and drop(_info(parts, part, model)):
            gone += 1
            continue
        kept.append(line)
    return "\n".join(kept) + "\n", gone


def _transparent(code: int, palette: dict[int, dict]) -> bool:
    entry = palette.get(code)
    return bool(entry) and (entry.get("alpha", 255) < 255 or "trans" in entry.get("group", ""))


def palette(path: Path = COLOURS) -> dict[int, dict]:
    return {int(c["code"]): c for c in json.loads(path.read_text())} if path.exists() else {}


def one_colour(text: str, colours: dict[int, dict]) -> tuple[str, int, int]:
    """Every solid part in the model's commonest solid colour; glass keeps its own.

    Returns the text, the colour, and how many parts changed.
    """
    model = style.read(text)
    counts = Counter(p.colour for p in model.placed if not _transparent(p.colour, colours))
    if not counts:
        return text, -1, 0
    target = counts.most_common(1)[0][0]
    out, changed = [], 0
    for line, bits, part in _part_lines(text):
        if part is not None and bits is not None:
            colour = int(bits[1]) if re.fullmatch(r"\d+", bits[1]) else 16
            if colour != target and not _transparent(colour, colours):
                bits = [bits[0], str(target), *bits[2:]]
                line = " ".join(bits)
                changed += 1
        out.append(line)
    return "\n".join(out) + "\n", target, changed


def with_fault(text: str, fault: str, parts: style.Parts, colours: dict[int, dict]) -> tuple[str, str]:
    """The design with one fault put in, and a line saying what was done."""
    if fault == "bare studs":
        made, gone = without(text, parts, is_tile)
        return _header(made, f"{gone} tiles taken off"), f"{gone} tiles taken off"
    if fault == "some studs bare":
        seen = [0]

        def every_fourth(info: style.PartInfo | None) -> bool:
            if not is_tile(info):
                return False
            seen[0] += 1
            return seen[0] % 4 == 0
        made, gone = without(text, parts, every_fourth)
        said = f"{gone} tiles of {seen[0]} taken off, one in four"
        return _header(made, said), said
    if fault == "no figures":
        made, gone = without(text, parts, is_figure)
        return _header(made, f"{gone} figure parts taken out"), f"{gone} figure parts taken out"
    if fault == "one colour":
        made, colour, changed = one_colour(text, colours)
        said = f"{changed} parts recoloured to colour {colour}"
        return _header(made, said), said
    raise ValueError(f"no such fault: {fault}")


# -- a real set as a naive stack ----------------------------------------------


def naive_stack(text: str, parts: style.Parts, colours: dict[int, dict]) -> tuple[str, str]:
    """A model's shape as plain bricks, studs up, in its three commonest colours.

    Every cell a 1 x 1 brick in size is filled when half of it is inside
    some part's box; each cell takes the colour most of it is, and every
    colour but the three commonest becomes the nearest of those. Each
    course is then laid in the largest plain bricks that fit one colour.
    """
    model = style.read(text)
    placed = [(p, info) for p in model.placed
              if (info := _info(parts, p.part, model)) is not None and style.building(info)]
    boxes = style._boxes(placed, parts)
    if not boxes:
        raise ValueError("no part with a box to stack")
    low = [min(b.centre[k] - b.half[k] for b in boxes) for k in range(3)]
    bottom = max(b.centre[1] + b.half[1] for b in boxes)       # LDraw: y grows downward
    votes: dict[tuple[int, int, int], Counter] = {}
    for b in boxes:
        lo = [b.centre[k] - b.half[k] for k in range(3)]
        hi = [b.centre[k] + b.half[k] for k in range(3)]
        cx = range(int((lo[0] - low[0]) // STUD), int((hi[0] - low[0]) // STUD) + 1)
        cz = range(int((lo[2] - low[2]) // STUD), int((hi[2] - low[2]) // STUD) + 1)
        cy = range(int((bottom - hi[1]) // BRICK), int((bottom - lo[1]) // BRICK) + 1)
        for i in cx:
            for k in cz:
                for j in cy:
                    inside = 0
                    for fx in _FRACTIONS_XZ:
                        x = low[0] + (i + fx) * STUD
                        if not lo[0] <= x <= hi[0]:
                            continue
                        for fz in _FRACTIONS_XZ:
                            z = low[2] + (k + fz) * STUD
                            if not lo[2] <= z <= hi[2]:
                                continue
                            for fy in _FRACTIONS_Y:
                                y = bottom - (j + fy) * BRICK
                                if lo[1] <= y <= hi[1]:
                                    inside += 1
                    if inside:
                        votes.setdefault((i, j, k), Counter())[b.colour] += inside
    # A sample point inside two parts counts twice; at most 12 points are in a cell.
    filled = {cell: count.most_common(1)[0][0] for cell, count in votes.items()
              if min(sum(count.values()), 12) >= FILLED}
    commonest = [c for c, _n in Counter(filled.values()).most_common(3)]

    def rgb(code: int) -> tuple[int, int, int]:
        return tuple(colours.get(code, {}).get("rgb", (128, 128, 128)))  # type: ignore[return-value]

    def nearest(code: int) -> int:
        if code in commonest:
            return code
        r = rgb(code)
        return min(commonest, key=lambda c: sum((a - b) ** 2 for a, b in zip(rgb(c), r)))

    cells = {cell: nearest(colour) for cell, colour in filled.items()}
    lines = []
    for j in sorted({c[1] for c in cells}):
        course = {(i, k): colour for (i, jj, k), colour in cells.items() if jj == j}
        for (i, k) in sorted(course):
            if (i, k) not in course:
                continue
            colour = course[(i, k)]
            for along_x, along_z, part in BRICKS:
                block = [(i + a, k + c) for a in range(along_x) for c in range(along_z)]
                if all(course.get(cell) == colour for cell in block):
                    for cell in block:
                        del course[cell]
                    x = low[0] + (i + along_x / 2) * STUD
                    z = low[2] + (k + along_z / 2) * STUD
                    y = bottom - (j + 1) * BRICK
                    turn = TURNED if along_z > along_x else SQUARE
                    lines.append(f"1 {colour} {x:g} {y:g} {z:g} {turn} {part}.dat")
                    break
    said = (f"{len(cells)} cells of {len(boxes)} parts as {len(lines)} plain bricks in "
            f"colours {', '.join(map(str, commonest))}")
    return _header("\n".join(lines) + "\n", f"A naive stack: {said}"), said
