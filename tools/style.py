#!/usr/bin/env python3
"""How a model is built, not what it is made of: its style, against real sets.

    tools/style.py model.ldr [--against castle]   a model, against a group's norms
    tools/style.py norms                          real sets -> style_norms.json
    tools/style.py sets 9469-1 10176-1            real sets from vendor/omr, by number

tools/texture.py counts what a model is made of and tools/layout.py how
it stands. Neither can see that a design is every brick studs-up, square
to the grid and the same on both sides, which is what a person sees
first. Official LDraw models of real sets record every part's full
transform, so they can say how real sets are built. This measures:

  orientation  of the parts with a defined up (studs or anti-studs), the
               share whose studs do not point up: sideways, upside-down,
               or tilted between (snot); and the share whose rotation is
               not a multiple of 90 degrees about some axis (angled).
               LDraw is -Y up, so a part's studs point along its matrix
               times (0, -1, 0), and the cosine with up is the matrix's
               middle entry. Taken from the transform only: a bracket or
               a headlight brick placed upright is counted by its kind,
               under snot_parts, not here.
  kinds        the share of parts of each kind, by the part's LDraw name
               and category (rules in CLASSES): curve, slope,
               snot_parts, angle_parts, texture, tile, organic, plain.
               A part can be of more than one kind (a round tile is a
               curve and a tile), so they do not sum to one; plain is
               only a rectangular brick or plate with nothing else to it.
  symmetry     the share of parts with a mirror partner across the
               model's best vertical mirror plane: the same part, or its
               Left/Right twin, in the same colour, its box mirrored to
               within TOLERANCE. Planes are tried across x and across z,
               through the centre and wherever pairs of like parts vote
               for one. Also the same, for the lower and upper half of
               the parts by height.
  shaped       the share of parts that are curves, slopes or angled;
               near_shaped, the share that are one or touch one, which
               says whether the shaping is spread through the model or
               all on its roof.
  counts       parts, shapes (distinct parts), colours.

Minifigures, their gear, animals and stickers are left out of every
measure: the designs here have none, and a real castle has dozens. A
real set saved turned or tilted on a stand is squared up first; one
saved lying on a quarter turn is not, because it cannot be told from
one built on its side (75060 Slave I reads 95% SNOT for that reason).

`norms` measures every model in vendor/omr/files (tools/omr.py fetch),
groups them by theme (THEMES, split by name where a theme mixes
buildings and vehicles, SETS where a name cannot say), and writes the
10th, 50th and 90th percentile of each measure per group, overall, and
for sets from 2010 on, to assets/generated/style_norms.json, which is
gitignored like the rest of assets/generated: rerun this to make it.

Measured 2026-10-10 over 273 real models of 100+ parts, median (10th-90th):

                 castle (14)    fantasy (16)    since 2010 (144)
  snot           4% (0-21)      19% (8-41)      25% (6-66)
  angled         3% (0-21)      27% (12-56)     13% (2-49)
  curve          9% (6-16)      20% (12-31)     15% (7-26)
  plain          53% (40-65)    28% (24-36)     33% (22-47)
  near_shaped    75% (52-85)    91% (84-97)     82% (53-93)
  symmetry       53% (28-85)    31% (19-76)     59% (19-94)

  models/castle.ldr (run 24)    0% SNOT, 0% angled, 3% curves,
                                71% plain, 22% near a shaped part,
                                55% symmetric

Twelve of the fourteen castles are from 1984-1993, which is why castle
SNOT is so low; 21325 Medieval Blacksmith (2021) is 34% SNOT, 26%
angled, 25% plain. The repository has no 10237 Orthanc, 10333 Barad-dur
or 10316 Rivendell; its Lord of the Rings sets are five from 2012, the
largest 9476 The Orc Forge (326 parts: 23% SNOT, 22% angled, 24% plain,
19% symmetric).
"""

from __future__ import annotations

import argparse
import itertools
import json
import math
import re
import sys
from collections import Counter, defaultdict
from collections.abc import Sequence
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw.parser import Matrix, SubfileRef, normalise_filename, parse_line  # noqa: E402

CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"
LDRAW = ROOT / "vendor" / "ldraw"
OMR = ROOT / "vendor" / "omr"
NORMS = ROOT / "assets" / "generated" / "style_norms.json"

# Within this many LDU a part's box counts as mirrored onto another's:
# a fifth of a stud, well under the half stud real layouts move in.
TOLERANCE = 4.0
# Studs within 20 degrees of up are up; within 20 of level, sideways.
UP_COS = math.cos(math.radians(20))
LEVEL_COS = math.sin(math.radians(20))
# A rotation entry this close to -1, 0 or 1 is square to the grid.
SQUARE = 0.02


# -- reading a model ------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Placed:
    """One part in a flattened model: what, what colour, and where."""

    part: str           # normalised, without ".dat": "3001", "3626bp01"
    colour: int
    matrix: Matrix      # world transform, LDraw axes (y down)


@dataclass(slots=True)
class PartInfo:
    """What the measures need to know about a part."""

    name: str
    category: str = ""
    # Its box in its own LDraw axes, y down: (low, high). None when the
    # part is not in the catalogue, which costs it its place in the
    # spatial measures but not the counts.
    box: tuple[tuple[float, float, float], tuple[float, float, float]] | None = None
    # Studs or anti-studs say which way is up. A pin, an axle, a hose
    # or a wheel has no up, so turning one is not a building technique.
    oriented: bool = True


@dataclass(slots=True)
class Model:
    placed: list[Placed]
    # Parts defined inside the document itself (an .mpd may carry
    # unofficial parts): their own header says what they are.
    embedded: dict[str, PartInfo] = field(default_factory=dict)


def _part_id(name: str) -> str:
    name = normalise_filename(name)
    return name[:-4] if name.endswith(".dat") else name


def read(text: str) -> Model:
    """A model's every part, sub-models flattened with their transforms.

    The first file of an .mpd is the model; any other file it refers to,
    directly or through another, is a sub-model and is followed, unless
    its header says it is a part, in which case it is one part. Colour
    16 takes the colour of the line that placed the sub-model.
    """
    files: dict[str, list[SubfileRef]] = {}
    headers: dict[str, dict[str, str]] = {}
    order: list[str] = []
    current: str | None = None

    def begin(name: str) -> str:
        files.setdefault(name, [])
        headers.setdefault(name, {})
        order.append(name)
        return name

    for raw in text.splitlines():
        bits = raw.split()
        if not bits:
            continue
        if bits[0] == "0":
            # Read raw: the parser upper-cases a meta line's first word,
            # and an embedded part's first line is its name.
            word = bits[1].upper() if len(bits) > 1 else ""
            if word == "FILE":
                current = begin(normalise_filename(" ".join(bits[2:])))
                continue
            if word == "NOFILE":
                current = None
                continue
            if current is None and not order:
                current = begin("<main>")
            if current is None:
                continue
            head = headers[current]
            body = " ".join(bits[1:])
            head.setdefault("description", body)
            if word == "!LDRAW_ORG" and len(bits) > 2:
                head["type"] = bits[2].lower()
            elif word == "!CATEGORY":
                head["category"] = " ".join(bits[2:])
            continue
        if bits[0] != "1":
            continue
        try:
            command = parse_line(raw)
        except ValueError:
            continue
        if not isinstance(command, SubfileRef):
            continue
        if current is None:
            if order:
                continue
            current = begin("<main>")
        files[current].append(command)
    if not order:
        return Model([])

    embedded: dict[str, PartInfo] = {}
    for name, head in headers.items():
        kind = head.get("type", "")
        is_part = ("part" in kind and "subpart" not in kind) or "shortcut" in kind
        if name != order[0] and is_part:
            description = " ".join(head.get("description", name).split())
            category = head.get("category") or _first_word(description)
            embedded[_part_id(name)] = PartInfo(description, category)

    placed: list[Placed] = []

    def walk(name: str, where: Matrix, colour: int, depth: int) -> None:
        for ref in files.get(name, []):
            here = where @ ref.matrix
            tint = colour if ref.color == 16 else ref.color
            if ref.filename in files and _part_id(ref.filename) not in embedded and depth < 16:
                walk(ref.filename, here, tint, depth + 1)
            else:
                placed.append(Placed(_part_id(ref.filename), tint, here))

    walk(order[0], Matrix.identity(), 16, 0)
    return Model(placed, embedded)


def _clean(name: str) -> str:
    """A part's name as a person reads it: no ~ prefix, no (Obsolete)."""
    name = re.sub(r"\(obsolete\)", "", name, flags=re.I).lstrip("~_=| ")
    return " ".join(name.split())


def _first_word(description: str) -> str:
    words = _clean(description).split()
    return words[0] if words else ""


# -- what each part is ----------------------------------------------------


# Left out of every measure: they are not building, and the designs
# compared against real sets have none of them. LSynth and hose
# segments are a flexible part drawn as dozens of short pieces at every
# angle, and would read as the most angled building in the repository.
NOT_BUILDING = re.compile(r"^(minifig|sticker|animal|figure|duplo|znap|electric|"
                          r"string|hose|chain|lsynth|ls\d|pattern|moved)", re.I)


def building(info: PartInfo | None) -> bool:
    if info is None:
        return False
    return not (NOT_BUILDING.match(info.category) or NOT_BUILDING.match(info.name))


class Parts:
    """Part id -> PartInfo, from the catalogue, then the LDraw library.

    A part renamed in LDraw is a stub that says "~Moved to 3023b"; it is
    read as the part it moved to, or a third of the repository's plates
    are a category called Moved.
    """

    def __init__(self, catalogue: Path | None = CATALOGUE, ldraw: Path | None = LDRAW) -> None:
        self._info: dict[str, PartInfo | None] = {}
        self._mirror: dict[str, str] = {}
        self._moved: dict[str, str] = {}
        self._ldraw = ldraw
        self._library = None
        by_name: dict[str, str] = {}
        moved: dict[str, str] = {}
        if catalogue is not None and catalogue.exists():
            for entry in json.loads(catalogue.read_text())["parts"]:
                low, high = entry["bounds_min"], entry["bounds_max"]
                # The catalogue is +Y up; LDraw is +Y down.
                box = ((low[0], -high[1], low[2]), (high[0], -low[1], high[2]))
                # Studs, or anti-studs, say which way is up. The catalogue
                # counts a pin's ends as sockets, and a pin has no up.
                joints = entry.get("connector_counts") or {}
                oriented = bool(entry.get("stud_count")) or bool(
                    entry.get("socket_count") and not {"pin", "axle"} & set(joints))
                name = _clean(entry["name"])
                category = entry["category"]
                if category in ("Moved", "Obsolete", "") or not category[:1].isalpha():
                    category = _first_word(name)
                self._info[entry["id"]] = PartInfo(name, category, box, oriented)
                if entry.get("moved_to"):
                    moved[entry["id"]] = entry["moved_to"].lower()
                else:
                    by_name.setdefault(name.lower(), entry["id"])
        for part, target in moved.items():
            for _ in range(6):
                if target not in moved:
                    break
                target = moved[target]
            if self._info.get(target) is not None:
                self._info[part] = self._info[target]
                self._moved[part] = target
        # A Left part's mirror image is its Right twin, by name.
        for name, part in by_name.items():
            if re.search(r"\bleft\b", name):
                twin = by_name.get(re.sub(r"\bleft\b", "right", name))
                if twin:
                    self._mirror[part], self._mirror[twin] = twin, part

    def get(self, part: str, embedded: dict[str, PartInfo] | None = None) -> PartInfo | None:
        if part in self._info:
            return self._info[part]
        if embedded and part in embedded:
            # A set's own copy of a part, as "10276 - 20310.dat" titled
            # "20310", or "Set - 30350cp01": the part it names says more.
            for said in (embedded[part].name.lower(), part):
                named = re.fullmatch(r"(?:.* - )?([0-9a-z]+)", said)
                if named and self._info.get(named.group(1)) is not None:
                    return self._info[named.group(1)]
            return embedded[part]
        found = self._from_library(part)
        self._info[part] = found
        return found

    def canonical(self, part: str) -> str:
        """The part's current number: 41770 has moved to 41770a."""
        return self._moved.get(part, part)

    def mirror(self, part: str) -> str:
        """The part a mirror image of this one is: its Left/Right twin, or itself."""
        part = self.canonical(part)
        return self._mirror.get(part, part)

    @classmethod
    def of(cls, infos: dict[str, PartInfo], twins: dict[str, str] | None = None) -> "Parts":
        """Parts known by hand, with no catalogue or library behind them."""
        made = cls(catalogue=None, ldraw=None)
        made._info.update(infos)
        for left, right in (twins or {}).items():
            made._mirror[left], made._mirror[right] = right, left
        return made

    def _from_library(self, part: str) -> PartInfo | None:
        if self._library is None:
            if self._ldraw is None or not (self._ldraw / "parts").is_dir():
                return None
            from ldraw.library import Library
            self._library = Library(self._ldraw)
        found = self._library.get(part + ".dat")
        if found is None:
            return None
        if found.moved_to:
            return self.get(found.moved_to)
        name = _clean(found.description)
        if found.is_primitive or found.is_subpart:
            # Drawn into a model directly, a primitive is a surface.
            return PartInfo(name, "Pattern", None, False)
        category = found.category or _first_word(name)
        oriented = bool(re.match(r"(brick|plate|tile|slope|panel|bracket|wedge|arch|"
                                 r"window|door|cylinder|cone|dish|baseplate)", category, re.I))
        return PartInfo(name, category, None, oriented)


# -- kinds of part --------------------------------------------------------


def _any(*words: str) -> str:
    return r"\b(" + "|".join(words) + r")\b"


# Each kind is a rule over a part's cleaned, lower-case LDraw name and
# its category, written against the 300 names real sets use most. A part
# may be of several kinds; `plain` is only a rectangular brick or plate.
CLASSES: dict[str, re.Pattern[str]] = {
    # Anything whose outline is not a rectangle by a curve or a diagonal.
    "curve": re.compile(
        _any("curved", "arch", "round", "rounded end", "round ends", "macaroni",
             "cone", "dome", "domed", "dish", "cylinder", "quarter", "circle",
             "semicircle", "half circle", "bow", "arc", "sphere", "radar",
             "wedge", "wing", "triangular", "angled end", "facet", "octagonal",
             "barrel", "arched", "rounded top")
        + r"|\|(arch|cone|dish|cylinder|wedge|wing)$"),
    "slope": re.compile(r"^slope\b|^[^|]*\|slope$"),
    # Parts whose own geometry turns studs sideways or down.
    "snot_parts": re.compile(
        r"^bracket\b|headlight|\bstuds? on\b[^|]*\b(sides?|end)\b|\bside studs?\b"
        r"|^[^|]*\|bracket$"),
    # Parts that let a part sit at any angle: hinges, clips on bars,
    # turntables and ball joints.
    "angle_parts": re.compile(
        _any("hinge", "clips?", "bar", "turntable", "ball", "socket", "towball",
             "click", "rotation", "swivel", "handle", "joint-8", "finger")
        + r"|^[^|]*\|(hinge|turntable|bar)$"),
    # What breaks up a flat face: grilles, ingots, masonry and log
    # bricks, 1 x 1 round plates and tiles, cheese slopes, teeth.
    "texture": re.compile(
        _any("grille", "grill", "ingot", "profile", "masonry", "embossed", "log",
             "palisade", "lattice", "corrugated", "ribbed", "tooth", "teeth", "slats",
             "scroll", "spindled")
        + r"|^brick\b[^|]*\bgroove\b|^(plate|tile) 1 x 1 round\b"
        + r"|^slope brick 31 1 x [12] x 0\.667"),
    # A smooth top.
    "tile": re.compile(r"^tile\b(?![^|]*\binverted\b)"),
    "organic": re.compile(
        _any("rock", "plant", "leaf", "leaves", "flower", "petals?", "stem", "vine",
             "tree", "grass", "seaweed", "bamboo", "frond", "palm", "fern",
             "branch", "boulder", "fruit", "flowers")
        + r"|^[^|]*\|(plant|rock)$"),
    "plain": re.compile(
        r"^(brick|plate) \d+ x \d+( x \d+(\.\d+)?)?"
        r"( (with|without) (centre|bottom|center) (tube|stud)| without understud)?\|"),
}


def kinds(info: PartInfo) -> set[str]:
    """The kinds a part is, by its name and category."""
    said = f"{info.name.lower()}|{info.category.lower()}"
    found = {kind for kind, rule in CLASSES.items() if rule.search(said)}
    if said.startswith("technic"):
        # A Technic bush or a round pin joiner is not a curve in a wall.
        found &= {"angle_parts", "snot_parts"}
    if "curve" in found:
        found.discard("slope")      # a curved slope is a curve
    if "plain" in found and len(found) > 1:
        found.discard("plain")
    if "texture" in found and said.startswith("plate 1 x 2 with groove"):
        found.discard("texture")    # a jumper's groove is underneath
    return found


# -- measuring ------------------------------------------------------------


def _columns(m: Matrix) -> list[tuple[float, float, float]]:
    """The part's own x, y and z axes in the world, each of unit length."""
    out = []
    for column in ((m.a, m.d, m.g), (m.b, m.e, m.h), (m.c, m.f, m.i)):
        length = math.sqrt(sum(v * v for v in column)) or 1.0
        out.append((column[0] / length, column[1] / length, column[2] / length))
    return out


def facing(m: Matrix) -> str:
    """Where a part's studs point: up, down, sideways, or tilted between.

    LDraw is -Y up, so a part's studs point along m times (0, -1, 0); its
    cosine with up, (0, -1, 0), is the y entry of the part's own y axis.
    """
    cos = _columns(m)[1][1]
    if cos >= UP_COS:
        return "up"
    if cos <= -UP_COS:
        return "down"
    if abs(cos) <= LEVEL_COS:
        return "sideways"
    return "tilted"


def angled(m: Matrix) -> bool:
    """Turned by something other than a multiple of 90 degrees."""
    return any(min(abs(v), abs(abs(v) - 1.0)) > SQUARE
               for column in _columns(m) for v in column)


def _from_columns(u, v, w) -> Matrix:
    return Matrix(u[0], v[0], w[0], u[1], v[1], w[1], u[2], v[2], w[2])


def _transpose(m: Matrix) -> Matrix:
    return Matrix(m.a, m.d, m.g, m.b, m.e, m.h, m.c, m.f, m.i)


# The 24 quarter-turn rotations of a cube.
QUARTERS = [m for order in itertools.permutations(range(3))
            for signs in itertools.product((1.0, -1.0), repeat=3)
            for m in [Matrix(*[signs[r] if order[r] == k else 0.0
                               for r in range(3) for k in range(3)])]
            if m.determinant() > 0]
SQUARE_FRAME = ((1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0))


def _frame(m: Matrix) -> tuple[tuple, tuple]:
    """The grid a part sits square on, whichever quarter turn it takes on it.

    A quarter turn swaps and flips a part's axes, so the grid is its three
    axes with their signs and their order forgotten: rounded, to vote
    with, and exact, to undo.
    """
    axes = []
    for axis in _columns(m):
        lead = next((v for v in axis if abs(v) > 0.01), 1.0)
        sign = 1.0 if lead > 0 else -1.0
        exact = tuple(sign * v for v in axis)
        axes.append((tuple(round(v, 2) + 0.0 for v in exact), exact))
    axes.sort(reverse=True)
    return tuple(a[0] for a in axes), tuple(a[1] for a in axes)


def _square_up(placed: list[tuple[Placed, PartInfo]]) -> tuple[list[tuple[Placed, PartInfo]], float]:
    """The model square to the grid it was built on.

    A real set saved turned on the spot or tilted on a display stand
    would otherwise read as every part angled and nothing mirrored, so
    the turn most of its parts share is undone, if more share it than
    sit square. Returns that turn's smallest angle, in degrees.

    A model saved lying down on a quarter turn is left as it is: it
    cannot be told from one built on its side, and real sets are
    (21021 Marina Bay Sands' towers, 75272's wings: most of their studs
    point sideways, and those sets stand up).
    """
    oriented = [p for p, info in placed if info.oriented]
    if not oriented:
        return placed, 0.0
    votes: Counter = Counter()
    exact: dict[tuple, tuple] = {}
    for p in oriented:
        key, axes = _frame(p.matrix)
        votes[key] += 1
        exact.setdefault(key, axes)
    frame, most = votes.most_common(1)[0]
    fix = Matrix.identity()
    if frame != SQUARE_FRAME and most > votes[SQUARE_FRAME]:
        u, v, w = exact[frame]
        grid = _from_columns(u, v, w)
        if grid.determinant() < 0:
            grid = _from_columns(u, v, tuple(-c for c in w))
        # Undone up to a quarter turn, so take the quarter turn that
        # leaves the least turning: a set turned 30 degrees is turned
        # back 30, not laid on its side.
        fix = max((q @ _transpose(grid) for q in QUARTERS), key=lambda t: t.a + t.e + t.i)
    if all(abs(a - b) < 1e-9 for a, b in zip(
            (fix.a, fix.b, fix.c, fix.d, fix.e, fix.f, fix.g, fix.h, fix.i),
            (1, 0, 0, 0, 1, 0, 0, 0, 1))):
        return placed, 0.0
    angle = math.degrees(math.acos(max(-1.0, min(1.0, (fix.a + fix.e + fix.i - 1) / 2))))
    return [(Placed(p.part, p.colour, fix @ p.matrix), info) for p, info in placed], round(angle, 1)


@dataclass(slots=True)
class _Box:
    index: int
    part: str
    twin: str
    colour: int
    centre: tuple[float, float, float]
    half: tuple[float, float, float]


def _boxes(placed: list[tuple[Placed, PartInfo]], parts: Parts) -> list[_Box]:
    out = []
    for index, (p, info) in enumerate(placed):
        if info.box is None:
            continue
        low, high = info.box
        local = [(low[k] + high[k]) / 2 for k in range(3)]
        size = [(high[k] - low[k]) / 2 for k in range(3)]
        m = p.matrix
        rows = ((m.a, m.b, m.c, m.x), (m.d, m.e, m.f, m.y), (m.g, m.h, m.i, m.z))
        centre = tuple(r[0] * local[0] + r[1] * local[1] + r[2] * local[2] + r[3] for r in rows)
        half = tuple(abs(r[0]) * size[0] + abs(r[1]) * size[1] + abs(r[2]) * size[2]
                     for r in rows)
        out.append(_Box(index, parts.canonical(p.part), parts.mirror(p.part), p.colour,
                        centre, half))  # type: ignore[arg-type]
    return out


def _cell(point: Sequence[float]) -> tuple[int, ...]:
    return tuple(int(math.floor(v / TOLERANCE)) for v in point)


def _mirrored(boxes: list[_Box], axis: int, at: float) -> list[bool]:
    """Which boxes have a partner mirrored across the plane axis = at.

    One partner each, nearest first; a part across the plane from
    itself is its own partner.
    """
    grid: dict[tuple, list[int]] = defaultdict(list)
    for n, box in enumerate(boxes):
        grid[(box.part, box.colour) + _cell(box.centre)].append(n)
    matched = [False] * len(boxes)
    for n, box in enumerate(boxes):
        if matched[n]:
            continue
        target = list(box.centre)
        target[axis] = 2 * at - target[axis]
        home = _cell(target)
        best, best_gap = -1, TOLERANCE + 1e-6
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    key = (box.twin, box.colour, home[0] + dx, home[1] + dy, home[2] + dz)
                    for other in grid.get(key, ()):
                        if matched[other] and other != n:
                            continue
                        them = boxes[other]
                        gap = max(abs(them.centre[k] - target[k]) for k in range(3))
                        if gap > best_gap:
                            continue
                        if max(abs(them.half[k] - box.half[k]) for k in range(3)) > TOLERANCE:
                            continue
                        best, best_gap = other, gap
        if best >= 0:
            matched[n] = matched[best] = True
    return matched


def _planes(boxes: list[_Box], axis: int, most: int = 3) -> list[float]:
    """Where a mirror plane across this axis might be.

    Pairs of like parts level with each other vote for the plane halfway
    between them; the plane through the middle of the model is always
    tried too.
    """
    others = [k for k in range(3) if k != axis]
    buckets: dict[tuple, list[float]] = defaultdict(list)
    for box in boxes:
        key = (min(box.part, box.twin), box.colour,
               round(box.centre[others[0]] / TOLERANCE), round(box.centre[others[1]] / TOLERANCE),
               round(box.half[axis]), round(box.half[others[1]]))
        buckets[key].append(box.centre[axis])
    votes: Counter = Counter()
    for values in buckets.values():
        values = sorted(values)[:120]
        for i in range(len(values)):
            for j in range(i + 1, len(values)):
                votes[round((values[i] + values[j]) / 2 / 2) * 2] += 1
    found = [float(at) for at, _ in votes.most_common(most)]
    low = min(box.centre[axis] - box.half[axis] for box in boxes)
    high = max(box.centre[axis] + box.half[axis] for box in boxes)
    middle = sum(box.centre[axis] for box in boxes) / len(boxes)
    return found + [middle, (low + high) / 2]


def symmetry(boxes: list[_Box]) -> dict:
    """The best vertical mirror plane, and the share of parts it mirrors."""
    if not boxes:
        return {"symmetry": 0.0, "plane": None, "matched": []}
    best: tuple[float, int, float, list[bool]] = (-1.0, 0, 0.0, [])
    for axis in (0, 2):
        for at in _planes(boxes, axis):
            matched = _mirrored(boxes, axis, at)
            share = sum(matched) / len(boxes)
            if share > best[0]:
                best = (share, axis, at, matched)
    share, axis, at, matched = best
    return {"symmetry": share, "plane": ("xz"[axis // 2], round(at, 1)), "matched": matched}


def _near(boxes: list[_Box], shaped: set[int]) -> int:
    """How many boxes are shaped or touch a shaped one, within 1 LDU."""
    cell = 40.0
    grid: dict[tuple[int, int, int], list[_Box]] = defaultdict(list)

    def cells(box: _Box):
        lo = [int(math.floor((box.centre[k] - box.half[k] - 1) / cell)) for k in range(3)]
        hi = [int(math.floor((box.centre[k] + box.half[k] + 1) / cell)) for k in range(3)]
        for i in range(lo[0], hi[0] + 1):
            for j in range(lo[1], hi[1] + 1):
                for k in range(lo[2], hi[2] + 1):
                    yield (i, j, k)

    for box in boxes:
        if box.index in shaped:
            for key in cells(box):
                grid[key].append(box)
    near = 0
    for box in boxes:
        if box.index in shaped:
            near += 1
            continue
        touching = False
        for key in cells(box):
            for other in grid.get(key, ()):
                if all(abs(other.centre[k] - box.centre[k]) <= other.half[k] + box.half[k] + 1
                       for k in range(3)):
                    touching = True
                    break
            if touching:
                break
        near += touching
    return near


def _share(count: float, total: int) -> float:
    return round(count / total, 3) if total else 0.0


def measure(model: Model, parts: Parts) -> dict:
    """Every style measure of a model, as plain numbers."""
    placed = [(p, info) for p in model.placed
              for info in [parts.get(p.part, model.embedded)] if building(info)]
    placed, turned = _square_up(placed)  # type: ignore[arg-type]
    total = len(placed)
    out: dict = {"parts": total}
    if not total:
        return out

    oriented = [p for p, info in placed if info.oriented]
    faces = Counter(facing(p.matrix) for p in oriented)
    out["snot"] = _share(len(oriented) - faces["up"], len(oriented))
    for way in ("sideways", "down", "tilted"):
        out[way] = _share(faces[way], len(oriented))
    turned_parts = {i for i, (p, info) in enumerate(placed) if info.oriented and angled(p.matrix)}
    out["angled"] = _share(len(turned_parts), len(oriented))

    of_kind = [kinds(info) for _, info in placed]
    for kind in CLASSES:
        out[kind] = _share(sum(kind in found for found in of_kind), total)
    out["other"] = _share(sum(not found for found in of_kind), total)

    shaped = {i for i, found in enumerate(of_kind) if found & {"curve", "slope"}} | turned_parts
    out["shaped"] = _share(len(shaped), total)
    boxes = _boxes(placed, parts)
    out["near_shaped"] = _share(_near(boxes, shaped), len(boxes))

    mirror = symmetry(boxes)
    out["symmetry"] = round(mirror["symmetry"], 3)
    if boxes:
        heights = sorted(-box.centre[1] for box in boxes)
        middle = heights[len(heights) // 2]
        low = [m for box, m in zip(boxes, mirror["matched"]) if -box.centre[1] <= middle]
        high = [m for box, m in zip(boxes, mirror["matched"]) if -box.centre[1] > middle]
        out["symmetry_low"] = _share(sum(low), len(low))
        out["symmetry_high"] = _share(sum(high), len(high))
    out["shapes"] = len({parts.canonical(p.part) for p, _ in placed})
    out["colours"] = len({p.colour for p, _ in placed if p.colour != 16})
    out["lots"] = len({(parts.canonical(p.part), p.colour) for p, _ in placed})
    out["plane"] = mirror["plane"]
    out["turned"] = turned
    out["unboxed"] = total - len(boxes)
    return out


# -- real sets, by kind ---------------------------------------------------


# What the norms are kept for, in the order they are printed.
MEASURES = ["snot", "sideways", "down", "tilted", "angled",
            "curve", "slope", "snot_parts", "angle_parts", "texture", "tile",
            "organic", "plain", "other", "shaped", "near_shaped",
            "symmetry", "symmetry_low", "symmetry_high", "shapes", "colours"]

# A theme's top level -> the group its sets are judged in. Themes that
# mix buildings and vehicles (Town, City, Creator, Icons, Ideas, ...)
# are split by the set's name; SETS settles the ones a name cannot.
THEMES = {
    "Castle": "castle",
    "The Hobbit and Lord of the Rings": "fantasy", "Harry Potter": "fantasy",
    "Elves": "fantasy", "Pharaoh's Quest": "fantasy", "Monster Fighters": "fantasy",
    "Legends of Chima": "fantasy", "Minecraft": "fantasy", "Adventurers": "fantasy",
    "Space": "space", "Star Wars": "space",
    "Architecture": "architecture",
    "Modular Buildings": "buildings",
    "Train": "vehicles", "Racers": "vehicles", "Speed Champions": "vehicles",
    "Model Team": "vehicles", "Boat": "vehicles",
    "Technic": "technic",
    "Town": "buildings", "City": "buildings", "Creator": "buildings",
    "Friends": "buildings", "Western": "buildings", "Pirates": "buildings",
    "Legoland": "buildings", "LEGO Ideas and CUUSOO": "buildings",
    "Icons": "buildings", "Seasonal": "buildings",
}
MIXED = {"Town", "City", "Creator", "Friends", "Pirates", "Legoland",
         "LEGO Ideas and CUUSOO", "Icons", "Train"}
VEHICLE = re.compile(_any(
    "car", "cars", "truck", "bus", "train", "locomotive", "express", "metroliner",
    "chief", "plane", "jet", "boat", "ship", "schooner", "barracuda", "cruiser",
    "racer", "roadsters", "camper", "van", "beetle", "cooper", "ferrari", "porsche",
    "mustang", "fiat", "aston", "harley-davidson", "vespa", "bike", "dragster",
    "buggy", "crane", "loader", "transport", "pickup", "convertible", "rig",
    "flyer", "camel", "helicopter", "offroad", "caterham", "titanic", "triple-e",
    "emerald", "horizon", "wagon", "crawler", "freight", "goods", "push-along",
    "container double", "passenger", "power", "railroad", "railway", "boom"), re.I)
NOT_VEHICLE = re.compile(_any("station", "depot", "airport", "jetport", "seaport",
                              "house", "coaster", "ride", "center", "centre", "hq",
                              "garage", "gas n' wash"), re.I)
SETS = {
    "21325-1": "castle",
    "10283-1": "space", "21309-1": "space", "21321-1": "space", "1682-1": "space",
    "6339-1": "space", "6346-1": "space", "10213-1": "space",
    "10276-1": "architecture", "10214-1": "architecture", "10253-1": "architecture",
    "10256-1": "architecture", "10272-1": "architecture",
    "21303-1": "other", "21311-1": "other", "21323-1": "other", "10261-1": "other",
    "75276-1": "other", "75277-1": "other", "10018-1": "other", "75253-1": "other",
    "4404-1": "vehicles", "4888-1": "vehicles", "6571-1": "vehicles",
}


def group_of(row: dict) -> str:
    if row["number"] in SETS:
        return SETS[row["number"]]
    theme = row["theme"].split(" > ")[0]
    group = THEMES.get(theme, "other")
    if theme in MIXED:
        name = row["name"]
        vehicle = (theme == "Train" or bool(VEHICLE.search(name))) and not NOT_VEHICLE.search(name)
        group = "vehicles" if vehicle else "buildings"
    return group


def _number(path: Path) -> str:
    return path.name.split("_")[0].removesuffix(".mpd").removesuffix(".ldr")


def _percentile(values: list[float], q: float) -> float:
    values = sorted(values)
    if not values:
        return 0.0
    at = (len(values) - 1) * q
    low = int(math.floor(at))
    high = min(low + 1, len(values) - 1)
    return values[low] + (values[high] - values[low]) * (at - low)


def _band(rows: list[dict]) -> dict:
    out: dict = {"models": len(rows)}
    for key in MEASURES:
        values = [r[key] for r in rows if key in r]
        digits = 0 if key in ("shapes", "colours") else 3
        out[key] = [round(_percentile(values, q), digits) for q in (0.1, 0.5, 0.9)]
    return out


# Too small to say how a set is built: a 35-part polybag is one vignette.
LEAST = 100
SINCE = 2010
LOTR = "The Hobbit and Lord of the Rings"


def real_sets(parts: Parts) -> list[dict]:
    """Every model in vendor/omr/files, measured, with its set's row."""
    rows = {r["number"]: r for r in json.loads((OMR / "index.json").read_text())}
    out = []
    for path in sorted((OMR / "files").glob("*")):
        row = rows.get(_number(path), {"number": _number(path), "name": path.stem,
                                       "theme": "?", "year": "0"})
        found = measure(read(path.read_text(encoding="latin-1")), parts)
        found.update(file=path.name, number=row["number"], name=row["name"],
                     theme=row["theme"], year=int(row["year"] or 0), group=group_of(row))
        out.append(found)
    return out


def norms(measured: list[dict]) -> dict:
    kept = [r for r in measured if r["parts"] >= LEAST]
    groups: dict[str, list[dict]] = defaultdict(list)
    for r in kept:
        groups[r["group"]].append(r)
    bands = {name: _band(rows) for name, rows in sorted(groups.items())}
    bands["all"] = _band(kept)
    bands[f"since_{SINCE}"] = _band([r for r in kept if r["year"] >= SINCE])
    for name, rows in sorted(groups.items()):
        recent = [r for r in rows if r["year"] >= SINCE]
        if len(recent) >= 5 and len(recent) < len(rows):
            bands[f"{name}_since_{SINCE}"] = _band(recent)
    named = {f"{r['number']} {r['name']}": {k: r[k] for k in MEASURES + ["parts"] if k in r}
             for r in measured if r["theme"].startswith(LOTR)}
    return {
        "format": 1,
        "about": "How real sets are built, from LDraw's Official Model Repository: "
                 "[10th, 50th, 90th] percentile of each measure per group of models "
                 f"of {LEAST}+ parts. Shares are of parts; see tools/style.py.",
        "measured_over": len(kept),
        "measures": MEASURES,
        "groups": bands,
        "sets": {g: sorted({r["number"] for r in rows}) for g, rows in sorted(groups.items())},
        "lord_of_the_rings": named,
    }


# -- the command line -----------------------------------------------------


def _says(key: str, value: float) -> str:
    if key in ("shapes", "colours"):
        return f"{value:.0f}"
    return f"{value:.1%}" if 0 < value < 0.095 else f"{value:.0%}"


def report(name: str, found: dict, against: dict | None, label: str) -> None:
    print(f"{name}: {found['parts']} parts, {found.get('shapes', 0)} shapes, "
          f"{found.get('colours', 0)} colours"
          + (f"; turned {found['turned']:.0f} degrees to square it up" if found.get("turned") else "")
          + (f"; mirror plane across {found['plane'][0]} at {found['plane'][1]}"
             if found.get("plane") else ""))
    if against:
        print(f"  against {label}, {against['models']} real models: 10th / median / 90th")
    for key in MEASURES:
        if key not in found:
            continue
        line = f"  {key:14} {_says(key, found[key]):>5}"
        if against and key in against:
            low, mid, high = against[key]
            flag = "  LOW" if found[key] < low else "  HIGH" if found[key] > high else ""
            line += (f"    {_says(key, low):>5} {_says(key, mid):>5} {_says(key, high):>5}{flag}")
        print(line)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", nargs="+", help="model files, or `norms`, or `sets NUMBER...`")
    parser.add_argument("--against", default="", help="a group in the norms: castle, fantasy, ...")
    parser.add_argument("--norms", type=Path, default=NORMS)
    parser.add_argument("--json", action="store_true", help="print the measures as JSON")
    args = parser.parse_args()
    parts = Parts()

    if args.what[0] == "norms":
        measured = real_sets(parts)
        made = norms(measured)
        args.norms.parent.mkdir(parents=True, exist_ok=True)
        args.norms.write_text(json.dumps(made, separators=(",", ":")) + "\n")
        print(f"{made['measured_over']} real models of {LEAST}+ parts -> {args.norms} "
              f"({args.norms.stat().st_size // 1024} KB)")
        heads = [g.replace(f"_since_{SINCE}", f" {SINCE}+").replace(f"since_{SINCE}", f"{SINCE}+")
                 for g in made["groups"]]
        print("  median and 10th-90th percentile, per group")
        print(f"  {'':14}" + "".join(f"{h[:15]:>16}" for h in heads))
        print(f"  {'models':14}" + "".join(f"{b['models']:>16}" for b in made["groups"].values()))
        for key in MEASURES:
            cells = []
            for band in made["groups"].values():
                low, mid, high = band[key]
                cells.append(f"{_says(key, mid)} {_says(key, low)}-{_says(key, high)}")
            print(f"  {key:14}" + "".join(f"{c:>16}" for c in cells))
        return 0

    saved = json.loads(args.norms.read_text()) if args.norms.exists() else None
    against = saved["groups"].get(args.against) if saved and args.against else None
    if args.against and against is None:
        known = ", ".join(saved["groups"]) if saved else "none: run tools/style.py norms"
        print(f"no group {args.against!r} in {args.norms} ({known})", file=sys.stderr)
        return 2

    if args.what[0] == "sets":
        files = sorted((OMR / "files").glob("*"))
        paths = [p for n in args.what[1:] for p in files
                 if _number(p) in (n, f"{n}-1")]
    else:
        paths = [Path(p) for p in args.what]
    for path in paths:
        found = measure(read(path.read_text(encoding="latin-1")), parts)
        if args.json:
            print(json.dumps({"file": path.name, **found}))
        else:
            report(path.name, found, against, args.against)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
