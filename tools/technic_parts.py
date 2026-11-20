#!/usr/bin/env python3
"""A LEGO® Technic set's seen parts, read from real sets: what shows on a Technic
set's surface, and how each of those parts is held where it meets a studded body.

    tools/technic_parts.py build          vendor/omr -> assets/knowledge/technic_parts.json.gz
    tools/technic_parts.py show [ROLE]    the table, or one role, as the app says it
    tools/technic_parts.py measure MODEL.ldr...   each model's seen surface by role

The nine Technic subjects of the bench's 44 lost every verdict in both of
design24's arms, on parts, not form. In October four studless levers lifted
technique and lost likeness (docs/DESIGN_SCORES.md): a bare beam frame does not
read as the thing. So the session keeps the System body it builds well, and
lays on its surface the parts a Technic set shows. This reads which parts those
are, by what shows and not by any name: every Technic set's main model in the
LDraw model repository from 2000 on is drawn as boxes from its four sides and
from above, on a grid of SEEN_CELL LDU, and each part counts the cells where it
is the nearest thing (`seen`). Each part has one role (ROLES, by its LDraw
name): curved panels and fairings, flat panels, mudguards, straight beams, bent
liftarms and frames, thin liftarms, gears and turntables, wheels with their
hubs and tyres, mechanisms (shock absorbers, pneumatics, engines, steering,
tracks), and connectors with the pins and axles that show. Technic bricks with
holes, System parts and the rest are counted too, so the shares add to the
whole.

How a part is held is read from where pins and axles go (`holds`): each pin or
axle is a line along its box's long side, and the parts whose own boxes hold
points along it are the parts it joins. A part on a pin whose other end is in
a studded part is held on a studded body, and the holder says how: a Technic
brick with holes, a brick with an axle hole, a plate with holes, a pin
connector plate or a bracket (the bracket way), another studded part; or it
lies on studs, a stud in its hole. Those ways are read over every set from
2000 on, not only Technic ones: a System set is where Technic parts meet studs
most.

For each role the table says: its share of what a Technic set shows (the
median over the sets, and in how many sets it shows at all), from which sides
it shows, the parts that make it ranked by how much of them shows over how
many sets, the ways it is held on a studded body with the pin or axle each
takes, and the sets it came from (credited: number, name, modeller).
src/ai/technic_parts.gd reads it; a Technic subject's first build is told it
(Assistant._technic_first_build).

Held out: every set of realset.py's two halves, by number and by name (as
DesignMemory.holds reads a name), is left out before any file is read, so no
subject the bench measures against is in what the table says. The table lists
every set it read and every set it held out, and
src/dev/technic_parts_probe.gd checks the two never meet.
"""

from __future__ import annotations

import argparse
import gzip
import json
import math
import re
import statistics
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))
sys.path.insert(0, str(ROOT / "tools" / "bench"))

import style  # noqa: E402

FILES = ROOT / "vendor" / "omr" / "files"
INDEX = ROOT / "vendor" / "omr" / "index.json"
CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"
OUT = ROOT / "assets" / "knowledge" / "technic_parts.json.gz"

SINCE = 2000
# The grid the sides are drawn on, in LDU: a fifth of a stud, half a plate.
SEEN_CELL = 4.0
# The sides a set is drawn from: its four sides and its top (LDraw y is down).
SIDES = {"left": (0, -1), "right": (0, 1), "back": (2, -1), "front": (2, 1), "top": (1, -1)}
# A role's parts and sets, at most.
MOST_PARTS = 10
MOST_SETS = 10
MOST_HOLDS = 6
# How far inside a part's box a pin's point must be to be in it, in LDU.
INSIDE = 0.5

# What a part is on a Technic set's surface, by its LDraw name (lower case),
# first match wins. The order matters: a mudguard is a panel, a turntable a
# gear, a thin liftarm a beam.
ROLES: list[tuple[str, re.Pattern[str]]] = [
    ("mudguard", re.compile(r"\bmudguard\b|\bwheel arch\b|\bwheel well\b")),
    ("curved_panel", re.compile(r"^technic panel\b.*\b(fairing|curved|bent|smooth|car|hood"
                                r"|cylinder|wedge|dome|windscreen)\b|^technic panel fairing")),
    ("flat_panel", re.compile(r"^technic panel\b|^technic plate panel\b")),
    ("thin_liftarm", re.compile(r"^technic beam\b.*\bx +0\.5\b|^technic liftarm\b.*\bthin\b")),
    ("bent_liftarm", re.compile(r"^technic beam\b.*\b(bent|frame|triangle|double|angle|90"
                                r"|curved|quarter ellipse)\b|^technic beam \d+ x +\d+")),
    ("beam", re.compile(r"^technic beam\b|^technic liftarm\b")),
    ("gear", re.compile(r"^technic (gear|worm|turntable|differential)\b|^technic .*\bgear\b"
                        r"|^technic wedge belt wheel\b")),
    ("wheel", re.compile(r"^(wheel|tyre|tire)\b(?!.*\bholder\b)|^technic (wheel|tyre)\b")),
    ("mechanism", re.compile(r"^technic (shock|pneumatic|linear|engine|steering|suspension|chain"
                             r"|tread|universal|gearbox|transmission|link|rotor|changeover"
                             r"|driving ring|clutch|piston|cylinder|excavator|crane)\b"
                             r"|^electric\b|^technic power functions\b")),
    ("connector", re.compile(r"^technic (axle|pin|bush|connector|cross|angle connector"
                             r"|axle and pin|beam connector|knob|ball|disc|tooth|rotation"
                             r"|toggle|joint)\b")),
]
TECHNIC_ROLES = [name for name, _ in ROLES]
# Said as a person would, for the table and the app.
CALLED = {
    "curved_panel": "curved panels and fairings",
    "flat_panel": "flat panels",
    "mudguard": "mudguards over the wheels",
    "beam": "straight beams as the frame's lines",
    "bent_liftarm": "bent liftarms and frames",
    "thin_liftarm": "thin liftarms",
    "gear": "gears and turntables",
    "wheel": "wheels with their hubs and tyres",
    "mechanism": "mechanisms: shock absorbers, pistons, pneumatics, steering, tracks",
    "connector": "connectors, pins and axles",
    "technic_brick": "Technic bricks and plates with holes",
    "system": "System parts: bricks, plates, slopes, tiles",
    "other": "the rest",
}
TECHNIC_BRICK = re.compile(r"^technic (brick|plate)\b")

# How a seen part is held where it meets a studded body: the holder's kind,
# first match wins, and what a builder does there.
HOLDS: list[tuple[str, re.Pattern[str] | None, str]] = [
    ("axle_hole", re.compile(r"axle ?hole|axlehole|cross ?hole"),
     "an axle through a brick or a plate with an axle hole (32064 Technic brick 1 x 2 with "
     "axle hole, 4032 round plate 2 x 2, 3941 round brick 2 x 2), the part on its end, a bush "
     "(3713) outside"),
    ("technic_brick", re.compile(r"^technic brick\b"),
     "a Technic brick with holes laid in the body's wall course, its holes facing out "
     "(3700 1 x 2, 3701 1 x 4, 3894 1 x 6, 3702 1 x 8); a pin in a hole, the part's hole on "
     "the pin's other end"),
    ("technic_plate", re.compile(r"^technic plate\b|^plate\b.*\bholes\b"),
     "a plate with holes in a floor or a roof (3709b 2 x 4, 3738 2 x 8): a pin or an axle "
     "down through it"),
    ("bracket", re.compile(r"\bbracket\b|\bpin connector plate\b|\b(pin ?hole|peg ?hole)\b"
                           r"|\bwith (\w+ )?pin\b"),
     "the bracket way: a plate or a bracket with a pin hole under or beside a course (18677 "
     "plate 1 x 2 with a pin hole underneath, 32530 pin connector plate), the part pinned to it"),
    ("studded", None,
     "the hole of another studded part: a round brick's middle, a wheel holder, a pin "
     "with a stud (4274)"),
    ("on_studs", None,
     "laid flat on studs: a stud in each of its holes, held down by the course above"),
]
HOLD_SAID = {name: said for name, _, said in HOLDS}
# Parts that are lines: a pin or an axle goes through what it joins.
LINE = re.compile(r"^technic (pin|axle)\b(?!.*\bconnector\b)(?!.*\bjoiner\b)")
STUDLESS = re.compile(r"^technic (beam|liftarm|panel|connector|cross|axle and pin"
                      r"|angle connector|steering|shock|pneumatic|linear|gear|turntable)\b")


# -- the holdout ----------------------------------------------------------------

def words(text: str) -> set[str]:
    """A set's name as RealSnippets.words reads it, which DesignMemory.holds
    compares: stemmed, no filler, no word under three letters."""
    import snippets  # noqa: E402
    return set(snippets.words(text))


def held_out() -> list[tuple[str, str]]:
    """Every subject of realset.py's two halves: (number, name)."""
    import realset  # noqa: E402  (reads vendor/omr; only for build)
    out = []
    for which in realset.HALVES:
        for c in realset.sample(which):
            out.append((c.number, realset.clean_name(c.name)))
    return out


def holds_out(number: str, name: str, held: list[tuple[str, str]]) -> bool:
    """DesignMemory.holds, for every held-out subject at once: the set's base
    number, or its name's words all a held name's, or a held name's all its."""
    base = number.split("-")[0]
    said = words(name)
    for held_number, held_name in held:
        if held_number.split("-")[0] == base:
            return True
        other = words(held_name)
        if said and other and (said <= other or other <= said):
            return True
    return False


# -- the parts -------------------------------------------------------------------

class Catalogue:
    """Each part's studs, from the catalogue: a studded part has studs on it."""

    def __init__(self, path: Path = CATALOGUE) -> None:
        self.studs: dict[str, int] = {}
        # A part a builder can take from a box: not a sub-part ("~Technic
        # Shock Absorber 6.5L Cylinder", half of one), nor a stub moved to
        # another number ("~Moved to 2853a"), which is listed as that one.
        self.whole: set[str] = set()
        self.moved: dict[str, str] = {}
        if path.exists():
            for entry in json.loads(path.read_text())["parts"]:
                self.studs[entry["id"]] = int(entry.get("stud_count") or 0)
                if entry.get("moved_to"):
                    self.moved[entry["id"]] = str(entry["moved_to"]).lower()
                elif not str(entry.get("name", "")).startswith(("~", "_", "=", "|")):
                    self.whole.add(entry["id"])

    def listed(self, part: str) -> str:
        """The number a builder knows [part] by, or "" for none."""
        for _ in range(6):
            if part not in self.moved:
                break
            part = self.moved[part]
        return part if part in self.whole else ""

    def studded(self, part: str) -> bool:
        return self.studs.get(part, 0) > 0


def role_of(info: style.PartInfo | None) -> str:
    if info is None:
        return "other"
    name = " ".join(info.name.lower().split())
    for role, rule in ROLES:
        if rule.search(name):
            return role
    if TECHNIC_BRICK.search(name):
        return "technic_brick"
    if style.building(info) and not name.startswith("technic"):
        return "system"
    return "other"


class Box:
    """A part's box placed: its own axes, its middle and half sizes."""

    __slots__ = ("index", "part", "colour", "role", "info", "axes", "middle", "half",
                 "low", "high")

    def __init__(self, index: int, placed: style.Placed, info: style.PartInfo, role: str):
        self.index = index
        self.part = placed.part
        self.colour = placed.colour
        self.role = role
        self.info = info
        lo, hi = info.box  # type: ignore[misc]
        m = placed.matrix
        local = [(lo[k] + hi[k]) / 2 for k in range(3)]
        self.half = [max((hi[k] - lo[k]) / 2, 0.5) for k in range(3)]
        rows = ((m.a, m.b, m.c, m.x), (m.d, m.e, m.f, m.y), (m.g, m.h, m.i, m.z))
        self.middle = [r[0] * local[0] + r[1] * local[1] + r[2] * local[2] + r[3] for r in rows]
        # Columns: where each of the part's own axes points, unit length.
        cols = []
        for k in range(3):
            v = [rows[0][k], rows[1][k], rows[2][k]]
            n = math.sqrt(sum(c * c for c in v)) or 1.0
            cols.append([c / n for c in v])
            self.half[k] *= n
        self.axes = cols
        ext = [sum(abs(cols[k][j]) * self.half[k] for k in range(3)) for j in range(3)]
        self.low = [self.middle[j] - ext[j] for j in range(3)]
        self.high = [self.middle[j] + ext[j] for j in range(3)]

    def holds_point(self, p: list[float], inside: float = INSIDE) -> bool:
        d = [p[j] - self.middle[j] for j in range(3)]
        for k in range(3):
            if abs(sum(d[j] * self.axes[k][j] for j in range(3))) > self.half[k] - inside:
                return False
        return True

    def line(self) -> tuple[list[float], list[float], float]:
        """A pin's or an axle's line: its middle, the way it runs, half its length."""
        k = max(range(3), key=lambda n: self.half[n])
        return self.middle, self.axes[k], self.half[k]


def boxes_of(text: str, parts: style.Parts) -> list[Box]:
    model = style.read(text)
    out = []
    for p in model.placed:
        info = parts.get(p.part, model.embedded)
        if info is None or info.box is None:
            continue
        name = info.name.lower()
        if name.startswith(("minifig", "sticker", "~", "animal")) or "sticker" in name:
            continue
        out.append(Box(len(out), p, info, role_of(info)))
    return out


# -- what shows ------------------------------------------------------------------

def seen(boxes: list[Box]) -> tuple[list[dict[str, int]], int]:
    """Each box's cells where it is the nearest thing, by side, and all the cells."""
    by_box: list[dict[str, int]] = [dict() for _ in boxes]
    total = 0
    for side, (axis, sign) in SIDES.items():
        u, v = [k for k in range(3) if k != axis]
        nearest: dict[tuple[int, int], tuple[float, int]] = {}
        for b in boxes:
            depth = -b.high[axis] if sign > 0 else b.low[axis]
            # Looking from +axis the nearest is the highest; from -axis the lowest.
            key_depth = depth
            for i in range(int(math.floor(b.low[u] / SEEN_CELL)), int(math.ceil(b.high[u] / SEEN_CELL))):
                for j in range(int(math.floor(b.low[v] / SEEN_CELL)), int(math.ceil(b.high[v] / SEEN_CELL))):
                    had = nearest.get((i, j))
                    if had is None or key_depth < had[0]:
                        nearest[(i, j)] = (key_depth, b.index)
        total += len(nearest)
        for _depth, index in nearest.values():
            by_box[index][side] = by_box[index].get(side, 0) + 1
    return by_box, total


# -- how it is held ---------------------------------------------------------------

class Grid:
    """Boxes by the cells of a coarse grid they reach, to find what holds a point."""

    CELL = 40.0

    def __init__(self, boxes: list[Box]) -> None:
        self.cells: dict[tuple[int, int, int], list[Box]] = defaultdict(list)
        for b in boxes:
            for i in range(int(math.floor(b.low[0] / self.CELL)), int(math.floor(b.high[0] / self.CELL)) + 1):
                for j in range(int(math.floor(b.low[1] / self.CELL)), int(math.floor(b.high[1] / self.CELL)) + 1):
                    for k in range(int(math.floor(b.low[2] / self.CELL)), int(math.floor(b.high[2] / self.CELL)) + 1):
                        self.cells[(i, j, k)].append(b)

    def at(self, p: list[float]) -> list[Box]:
        return self.cells.get(tuple(int(math.floor(c / self.CELL)) for c in p), [])  # type: ignore[arg-type]


def joined(boxes: list[Box]) -> tuple[dict[int, list[tuple[int, str]]], set[int]]:
    """Which parts each part is joined to through a pin or an axle: index ->
    [(other index, the line part's id)], and the indices that are lines."""
    grid = Grid(boxes)
    links: dict[int, list[tuple[int, str]]] = defaultdict(list)
    lines = set()
    for b in boxes:
        if not LINE.search(" ".join(b.info.name.lower().split())):
            continue
        lines.add(b.index)
        middle, way, half = b.line()
        reached: list[int] = []
        steps = max(2, int(half * 2 / 10))
        for n in range(steps):
            t = -half + 5.0 + (2 * half - 10.0) * n / max(steps - 1, 1)
            p = [middle[j] + way[j] * t for j in range(3)]
            for other in grid.at(p):
                if other.index == b.index or other.index in reached:
                    continue
                if LINE.search(" ".join(other.info.name.lower().split())):
                    continue
                if other.holds_point(p):
                    reached.append(other.index)
        for one in reached:
            for two in reached:
                if one != two:
                    links[one].append((two, b.part))
    return links, lines


def on_studs(b: Box, boxes_below: list[Box], catalogue: Catalogue) -> bool:
    """A beam, liftarm or panel lying flat on a studded part's top: its holes
    upright and its bottom on the other's top (LDraw y is down)."""
    upright = abs(b.axes[1][1]) > 0.95 or abs(b.axes[0][1]) > 0.95 or abs(b.axes[2][1]) > 0.95
    if not upright:
        return False
    for o in boxes_below:
        if o.index == b.index or not catalogue.studded(o.part) or o.role in TECHNIC_ROLES:
            continue
        if abs(b.high[1] - o.low[1]) <= 4.5 and b.low[0] < o.high[0] - 2 and o.low[0] < b.high[0] - 2 \
                and b.low[2] < o.high[2] - 2 and o.low[2] < b.high[2] - 2:
            return True
    return False


def hold_of(holder: Box, catalogue: Catalogue) -> str | None:
    """The way a part is held when [holder] is what its pin or axle goes into,
    when that is a studded part; None when it is studless."""
    name = " ".join(holder.info.name.lower().split())
    if not catalogue.studded(holder.part) or holder.role in TECHNIC_ROLES \
            or holder.role == "other":
        return None
    for kind, rule, _said in HOLDS:
        if rule is not None and rule.search(name):
            return kind
    return "studded"


# -- reading the sets ---------------------------------------------------------------

def author_of(text: str) -> str:
    for line in text.splitlines()[:30]:
        found = re.match(r"\s*0\s+Author:\s*(.+)", line, re.I)
        if found:
            return re.sub(r"\s*\[.*?\]\s*$", "", found.group(1)).strip()
    return ""


def read_set(path: Path, parts: style.Parts, catalogue: Catalogue, want_seen: bool) -> dict:
    text = path.read_text(errors="replace")
    boxes = boxes_of(text, parts)
    out: dict = {"parts": len(boxes), "by": author_of(text)}
    links, lines = joined(boxes)
    grid = Grid(boxes)
    # Each part of a Technic role: the holds it has on a studded body.
    held: list[tuple[int, str, list[tuple[str, str]]]] = []
    for b in boxes:
        if b.role not in TECHNIC_ROLES or b.index in lines:
            continue
        ways = []
        for other, line_part in links.get(b.index, []):
            kind = hold_of(boxes[other], catalogue)
            if kind is not None:
                ways.append((kind, line_part))
        if not ways and b.role in ("beam", "bent_liftarm", "thin_liftarm", "flat_panel"):
            below = grid.at([b.middle[0], b.high[1] + 2.0, b.middle[2]])
            if on_studs(b, below, catalogue):
                ways.append(("on_studs", ""))
        held.append((b.index, b.role, ways))
    out["held"] = held
    if want_seen:
        by_box, total = seen(boxes)
        out["seen"] = by_box
        out["total"] = total
    out["boxes"] = boxes
    return out


def technic_sets(rows: list[dict]) -> list[dict]:
    return [r for r in rows if str(r.get("theme", "")).split(" > ")[0] == "Technic"
            and _year(r.get("year")) >= SINCE]


def _year(value: object) -> int:
    try:
        return int(str(value))
    except ValueError:
        return 0


def _clean(name: str) -> str:
    return " ".join(re.sub(r"\((needs work|obsolete)\)", "", name, flags=re.I).split())


def build(args: argparse.Namespace) -> int:
    rows = json.loads(INDEX.read_text())
    held = held_out()
    parts = style.Parts()
    catalogue = Catalogue()
    held_seen: dict[str, str] = {}
    read: list[dict] = []
    technic = {r["number"] for r in technic_sets(rows)}
    since = [r for r in rows if _year(r.get("year")) >= SINCE]
    # Per role: seen share per Technic set, side cells, part cells and sets,
    # and the holds of its parts on a studded body over every set.
    share_of: dict[str, list[float]] = defaultdict(list)
    sides_of: dict[str, Counter] = defaultdict(Counter)
    part_cells: dict[str, Counter] = defaultdict(Counter)
    part_sets: dict[str, dict[str, set]] = defaultdict(lambda: defaultdict(set))
    role_sets: dict[str, Counter] = defaultdict(Counter)
    hold_count: dict[str, Counter] = defaultdict(Counter)
    hold_lines: dict[str, dict[str, Counter]] = defaultdict(lambda: defaultdict(Counter))
    hold_sets: dict[str, dict[str, set]] = defaultdict(lambda: defaultdict(set))
    hold_parts: dict[str, dict[str, Counter]] = defaultdict(lambda: defaultdict(Counter))
    held_parts: Counter = Counter()
    studded_parts: Counter = Counter()
    set_rows: list[dict] = []
    for r in sorted(since, key=lambda r: r["number"]):
        number = r["number"]
        name = _clean(str(r.get("name", "")))
        path = FILES / f"{number}.mpd"
        if not path.exists():
            path = FILES / f"{number}.ldr"
        if not path.exists():
            continue
        if holds_out(number, name, held):
            held_seen[number] = name
            continue
        is_technic = number in technic
        try:
            found = read_set(path, parts, catalogue, want_seen=is_technic)
        except Exception as error:  # a file the reader cannot follow is not a set read
            print(f"{number}: {error}", file=sys.stderr)
            continue
        boxes: list[Box] = found["boxes"]
        if not boxes:
            continue
        theme = str(r.get("theme", ""))
        # How it is held, on a studded body, in any set.
        for index, role, ways in found["held"]:
            held_parts[role] += 1
            if ways:
                studded_parts[role] += 1
            for kind in {k for k, _ in ways}:
                hold_count[role][kind] += 1
                hold_sets[role][kind].add(number)
                hold_parts[role][kind][boxes[index].part] += 1
            for kind, line_part in ways:
                if line_part:
                    hold_lines[role][kind][line_part] += 1
        if not is_technic:
            continue
        read.append({"number": number, "name": name, "year": _year(r.get("year")),
                     "theme": theme, "by": found["by"], "parts": found["parts"]})
        total = max(found["total"], 1)
        cells: Counter = Counter()
        for b, by_side in zip(boxes, found["seen"]):
            n = sum(by_side.values())
            if not n:
                continue
            cells[b.role] += n
            if b.role in TECHNIC_ROLES:
                for side, c in by_side.items():
                    sides_of[b.role][side] += c
                part_cells[b.role][b.part] += n
                part_sets[b.role][b.part].add(number)
        shares = {role: round(cells.get(role, 0) / total, 4) for role in CALLED}
        for role in CALLED:
            share_of[role].append(shares[role])
            if cells.get(role, 0) / total >= 0.01:
                role_sets[role][number] = cells[role]
        set_rows.append({"number": number, "name": name, "words": sorted(words(name)),
                         "seen": {k: v for k, v in shares.items() if v > 0}})
        print(f"{number} {name}: " + ", ".join(f"{k} {v:.0%}" for k, v in shares.items() if v >= 0.03),
              file=sys.stderr)
    roles = {}
    named = {r["number"]: r for r in read}
    for role in TECHNIC_ROLES:
        values = share_of.get(role, [])
        side = sides_of[role]
        side_total = sum(side.values()) or 1
        cells_of: Counter = Counter()
        sets_of: dict[str, set] = defaultdict(set)
        for part, n in part_cells[role].items():
            known = catalogue.listed(part)
            if known:
                cells_of[known] += n
                sets_of[known] |= part_sets[role][part]
        ranked = sorted(cells_of.items(), key=lambda kv: (-len(sets_of[kv[0]]), -kv[1]))
        listed = []
        for part, n in ranked[:MOST_PARTS]:
            info = parts.get(part)
            listed.append({"part": part, "name": _clean(info.name) if info else part,
                           "sets": len(sets_of[part]), "seen": n})
        ways = []
        for kind, n in hold_count[role].most_common(MOST_HOLDS):
            uses: Counter = Counter()
            for line_part, c in hold_lines[role][kind].items():
                known = catalogue.listed(line_part)
                if known:
                    uses[known] += c
            lines_used = [{"part": p, "name": _clean(parts.get(p).name) if parts.get(p) else p, "uses": c}
                          for p, c in uses.most_common(3)]
            ways.append({"way": kind, "said": HOLD_SAID[kind], "parts": n,
                         "share": round(n / max(held_parts[role], 1), 4),
                         "sets": len(hold_sets[role][kind]),
                         "lines": lines_used,
                         "examples": sorted(hold_sets[role][kind])[:MOST_SETS]})
        from_sets = []
        for number, n in role_sets[role].most_common(MOST_SETS):
            r = named.get(number, {})
            from_sets.append({"number": number, "name": r.get("name", ""), "by": r.get("by", "")})
        roles[role] = {
            "called": CALLED[role],
            "median": round(statistics.median(values), 4) if values else 0.0,
            "upper": round(sorted(values)[int(0.9 * (len(values) - 1))], 4) if values else 0.0,
            "in_sets": sum(1 for v in values if v >= 0.01),
            "sides": {k: round(v / side_total, 3) for k, v in side.most_common()},
            "parts": listed,
            "held_parts": held_parts[role],
            "on_studded": studded_parts[role],
            "holds": ways,
            "sets": from_sets,
        }
    others = {role: {"called": CALLED[role],
                     "median": round(statistics.median(share_of[role]), 4) if share_of[role] else 0.0}
              for role in ("technic_brick", "system", "other")}
    document = {
        "format": 1,
        "about": "A LEGO Technic set's seen surface by role, and how each role's parts are held "
                 "on a studded body: tools/technic_parts.py build.",
        "seen_cell": SEEN_CELL,
        "since": SINCE,
        "roles": roles,
        "others": others,
        "sets": set_rows,
        "read": read,
        "held_out": [{"number": n, "name": name} for n, name in sorted(held_seen.items())],
        "subjects": [{"number": n, "name": name} for n, name in sorted(held)],
    }
    OUT.parent.mkdir(parents=True, exist_ok=True)
    blob = json.dumps(document, separators=(",", ":"), sort_keys=True).encode()
    with gzip.GzipFile(OUT, "wb", mtime=0) as f:
        f.write(blob)
    print(f"wrote {OUT}: {len(read)} Technic sets read, {len(held_seen)} held out, "
          f"{len(blob)} bytes", file=sys.stderr)
    return 0


# -- saying it --------------------------------------------------------------------

def show(args: argparse.Namespace) -> int:
    document = json.loads(gzip.open(OUT).read())
    for role, row in document["roles"].items():
        if args.role and role != args.role:
            continue
        print(f"{role}: {row['called']} — median {row['median']:.0%} of what shows "
              f"(to {row['upper']:.0%}), in {row['in_sets']} of {len(document['read'])} sets; "
              f"sides {row['sides']}")
        for p in row["parts"]:
            print(f"    {p['part']:<9} {p['name']:<52} {p['sets']} sets")
        print(f"  held on a studded body: {row['on_studded']} of {row['held_parts']} parts")
        for w in row["holds"]:
            lines = ", ".join(f"{l['part']} x{l['uses']}" for l in w["lines"])
            print(f"    {w['way']:<14} {w['parts']:>5} parts in {w['sets']} sets ({lines})")
        print("  from: " + ", ".join(f"{s['number']} {s['name']}" for s in row["sets"]))
    print("others: " + ", ".join(f"{k} {v['median']:.0%}" for k, v in document["others"].items()))
    print(f"read {len(document['read'])}, held out {len(document['held_out'])}")
    return 0


def measure(args: argparse.Namespace) -> int:
    parts = style.Parts()
    for path in args.models:
        boxes = boxes_of(Path(path).read_text(errors="replace"), parts)
        if not boxes:
            print(json.dumps({"model": path, "parts": 0}))
            continue
        by_box, total = seen(boxes)
        cells: Counter = Counter()
        counts: Counter = Counter()
        for b, by_side in zip(boxes, by_box):
            counts[b.role] += 1
            cells[b.role] += sum(by_side.values())
        total = max(total, 1)
        print(json.dumps({"model": path, "parts": len(boxes),
                          "seen": {r: round(cells[r] / total, 4) for r in CALLED if cells[r]},
                          "count": dict(counts)}))
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("build")
    one = sub.add_parser("show")
    one.add_argument("role", nargs="?", default="")
    many = sub.add_parser("measure")
    many.add_argument("models", nargs="+")
    args = parser.parse_args(argv)
    return {"build": build, "show": show, "measure": measure}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
