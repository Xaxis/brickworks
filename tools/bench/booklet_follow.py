#!/usr/bin/env python3
"""Can a builder follow a Brickworks booklet? One builds the model from the pages alone,
and what it built is compared with the model, part for part and page by page.

    tools/bench/booklet_follow.py make MODEL --out DIR [--app CHECKOUT]
    tools/bench/booklet_follow.py build DIR --run NAME --port N [--from P] [--to Q]
        [--pages-a-session K] [--app CHECKOUT] [--minutes M] [--reading FILE]
    tools/bench/booklet_follow.py score DIR --run NAME
    tools/bench/booklet_follow.py report DIR --run NAME [--run NAME2 ...]

`make` writes the booklet as Instructions does and, from the same plan, what each page
adds (src/dev/booklet_truth.gd, a window on the GPU's lease): DIR/booklet.html and
DIR/truth.json. Then the pages as a browser shows them (tools/web/booklet_print.mjs
--shots-only, under heavy): DIR/pages/page-N.png, and the parts in the box,
DIR/inventory.json.

`build` is the builder: a Claude Code session on the owner's subscription (no API key:
`ANTHROPIC_API_KEY` is taken out of its environment) whose one MCP server is
tools/bench/booklet_mcp.py. It sees a page as its picture and what it has built, and
places parts in a fresh model in a headless app (`--mcp=N`) as a person places them; it
never sees the model's file. A session builds a few pages and says, for each, what the
page did not let it tell (booklet_mcp's page_done); the next session is handed the notes
it left. The model is kept after every page (runs/NAME/snapshots/page-N.ldr). --from
starts later in the book on the model as the pages before leave it, built right: the
castle's 300 pages are measured a stretch at a time. The builder is told how a Brickworks
booklet's pages read; DIR/reading.json (or --reading) says how another's do, so a printed
LEGO® booklet, its pages photographed into DIR/pages and its steps mapped onto truth.json,
is built and scored the same way.

`score` compares the last snapshot with the model (`compare`): the build is first turned
and moved onto the model (the builder chooses where its first part goes), then each of
the model's parts the pages built is

    right     that part, in that colour, filling the same space (a part turned half
              round on its own symmetry fills it too: "turned" counts those)
    near      that part in that colour on the stud or pin it goes on, seated less
              than half a stud (half a plate) off: the CAD's seat, not the reading
    colour    that part where it goes, in another colour
    place     that part in that colour somewhere else: how far, in studs and plates
    part      another part where it goes
    missing   nothing of it

and the parts the builder put in that the model has not are "extra". Each of the
model's parts counts on the page that puts it on the model (a sub-assembly built on
pages of its own counts where it goes on). A part "place" moved by just what a part
it touches from an earlier page was moved is "carried" too (`carried`): that page
was followed, on a model an earlier one had left wrong. Written to runs/NAME/score.json with a row a
page; `report` prints the rows and the totals of one run or of several.
"""

from __future__ import annotations

import argparse
import collections
import json
import math
import os
import re
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
CORE = Path.home() / ".claude" / "claude-core" / "bin"
GPU, HEAVY = str(CORE / "gpu"), str(CORE / "heavy")
SCREEN = "-screen 0 1600x900x24"
# The pages are photographed twice as fine as the screen shows them at print size: at 7.6
# px a millimetre, the 5 the booklet's pictures are drawn at. At one, a builder saw the
# castle's step pictures and the parts box at three quarters and two fifths of what they
# hold, below what a person reads on paper and below what the model can see (2576 px).
SCALE = 2
DRAWER = [GPU, "--brief", "xvfb-run", "-a", f"--server-args={SCREEN}", "godot"]
MCP_SERVER = ROOT / "tools" / "bench" / "booklet_mcp.py"
SECRETS = re.compile(r"KEY|TOKEN|SECRET|PASSWORD", re.I)
# A part's box within this of the model's, LDU on every side, fills the same space.
SAME_BOX = 2.0
# Two orientations are one when no entry of their matrices is further apart than this.
SAME_TURN = 0.01
# A builder's part over this share of the model's part's box, the smaller of the two,
# stands where it goes.
OVERLAP = 0.5
# Less than half a stud across and half a plate up: the right stud or pin, the CAD's seat
# not exact (a wheel pushed a little less far onto its pin). A whole stud is a stud.
NEAR = (10.0, 4.0, 10.0)
KINDS = ("right", "near", "colour", "place", "part", "missing")


# -- LDraw -----------------------------------------------------------------------------


class Placed:
    """One part where it stands: LDraw's 12 numbers, x y z then the matrix by rows."""

    def __init__(self, part: str, colour: int, numbers: list[float], ident: str = "") -> None:
        self.part = part.lower().removesuffix(".dat")
        self.colour = colour
        self.at = [float(v) for v in numbers[:3]]
        self.turn = [float(v) for v in numbers[3:12]]
        self.ident = ident

    def key(self) -> tuple[str, int]:
        return (same_part(self.part), self.colour)


def same_part(part: str) -> str:
    """The part a builder's choice counts as: one mould under its letters (3794a, 3794b)."""
    found = re.fullmatch(r"(\d+)[a-d]", part)
    return found.group(1) if found else part


def read_ldraw(text: str) -> list[Placed]:
    """Every part of an LDraw file, its sub-models placed in it (0 FILE ... 0 NOFILE)."""
    files: dict[str, list[str]] = {}
    order: list[str] = []
    current = None
    for line in text.splitlines():
        words = line.split()
        if len(words) >= 3 and words[0] == "0" and words[1] == "FILE":
            current = " ".join(words[2:]).lower()
            files[current] = []
            order.append(current)
            continue
        if words[:2] == ["0", "NOFILE"]:
            current = None
            continue
        files.setdefault(current if current is not None else "", []).append(line)
    main = order[0] if order else ""
    out: list[Placed] = []

    def walk(name: str, colour: int, at: list[float], turn: list[float], depth: int) -> None:
        if depth > 16:
            return
        for line in files.get(name, []):
            words = line.split()
            if len(words) < 15 or words[0] != "1":
                continue
            code = int(words[1]) if words[1].lstrip("-").isdigit() else 16
            code = colour if code == 16 else code
            local = [float(v) for v in words[2:14]]
            ref = " ".join(words[14:]).lower()
            child_turn = _mul(turn, local[3:12])
            child_at = _add(_apply(turn, local[:3]), at)
            if ref in files and ref != name:
                walk(ref, code, child_at, child_turn, depth + 1)
            else:
                out.append(Placed(ref, code, child_at + child_turn))

    walk(main, 16, [0.0, 0.0, 0.0], [1, 0, 0, 0, 1, 0, 0, 0, 1], 0)
    return out


def _mul(a: list[float], b: list[float]) -> list[float]:
    return [sum(a[r * 3 + k] * b[k * 3 + c] for k in range(3)) for r in range(3) for c in range(3)]


def _apply(m: list[float], v: list[float]) -> list[float]:
    return [sum(m[r * 3 + k] * v[k] for k in range(3)) for r in range(3)]


def _add(a: list[float], b: list[float]) -> list[float]:
    return [a[i] + b[i] for i in range(3)]


# -- the parts' boxes -------------------------------------------------------------------


class Bounds:
    """Each part's box in its own LDraw axes, from the catalogue (Godot's: y and z the
    other way)."""

    def __init__(self, boxes: dict[str, tuple[list[float], list[float]]]) -> None:
        self.boxes = boxes

    @staticmethod
    def load(catalogue: Path = ROOT / "assets" / "generated" / "catalogue.json") -> "Bounds":
        parts = json.loads(catalogue.read_text())["parts"]
        boxes = {}
        for p in parts:
            lo, hi = p.get("bounds_min"), p.get("bounds_max")
            if lo and hi:
                boxes[p["id"].lower()] = ([lo[0], -hi[1], -hi[2]], [hi[0], -lo[1], -lo[2]])
        return Bounds(boxes)

    def world(self, placed: Placed, turn: list[float] | None = None,
              shift: list[float] | None = None) -> tuple[list[float], list[float]]:
        """The part's box where it stands, after the whole build is turned and moved."""
        lo, hi = self.boxes.get(placed.part) or self.boxes.get(same_part(placed.part)) \
            or ([-1.0] * 3, [1.0] * 3)
        m, at = placed.turn, placed.at
        if turn is not None:
            m = _mul(turn, m)
            at = _apply(turn, at)
        if shift is not None:
            at = _add(at, shift)
        corners = [_add(_apply(m, [x, y, z]), at)
                   for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])]
        return ([min(c[i] for c in corners) for i in range(3)],
                [max(c[i] for c in corners) for i in range(3)])


def _same_box(a: tuple, b: tuple) -> bool:
    return all(abs(a[s][i] - b[s][i]) <= SAME_BOX for s in (0, 1) for i in range(3))


def _centre(box: tuple) -> list[float]:
    return [(box[0][i] + box[1][i]) / 2 for i in range(3)]


def _overlap(a: tuple, b: tuple) -> float:
    """How much of the smaller box the two share."""
    inside = 1.0
    for i in range(3):
        side = min(a[1][i], b[1][i]) - max(a[0][i], b[0][i])
        if side <= 0:
            return 0.0
        inside *= side
    smaller = min(math.prod(max(a[1][i] - a[0][i], 1.0) for i in range(3)),
                  math.prod(max(b[1][i] - b[0][i], 1.0) for i in range(3)))
    return inside / smaller


# Turns about LDraw's vertical (y): a builder's model may face any way.
YAWS = {deg: [round(math.cos(math.radians(deg))), 0, round(math.sin(math.radians(deg))),
              0, 1, 0,
              -round(math.sin(math.radians(deg))), 0, round(math.cos(math.radians(deg)))]
        for deg in (0, 90, 180, 270)}


def align(model: list[Placed], build: list[Placed], bounds: Bounds,
          most_pairs: int = 400_000) -> tuple[int, list[float]]:
    """The turn and move that lay the build on the model with the most parts together.
    Every pair of one part in one colour votes for the move that would lay its box's
    middle on the other's, under each turn, to 2 LDU; of each turn's three best moves,
    the one that puts the most boxes exactly on the model's wins. A column of bricks
    has as many votes turned a quarter round as not: only the boxes say which."""
    by_key: dict = collections.defaultdict(list)
    exact: dict = collections.defaultdict(set)
    for p in model:
        box = bounds.world(p)
        by_key[p.key()].append(_centre(box))
        exact[p.key()].add(_rounded(box))
    candidates = []
    for deg, turn in YAWS.items():
        votes: collections.Counter = collections.Counter()
        pairs = 0
        for b in build:
            mine = _centre(bounds.world(b, turn))
            for there in by_key.get(b.key(), []):
                votes[tuple(round((there[i] - mine[i]) / 2) for i in range(3))] += 1
                pairs += 1
            if pairs > most_pairs:
                break
        for move, count in votes.most_common(3):
            shift = [2.0 * v for v in move]
            fits = sum(_rounded(bounds.world(b, turn, shift)) in exact.get(b.key(), ())
                       for b in build)
            candidates.append((fits, count, -deg, shift))
    if not candidates:
        return 0, [0.0, 0.0, 0.0]
    fits, count, deg, shift = max(candidates, key=lambda c: (c[0], c[1], c[2]))
    return -deg, shift


def _rounded(box: tuple) -> tuple:
    return tuple(round(v / SAME_BOX) for side in box for v in side)


def pieces(boxes: list[tuple], touch: float = 1.0) -> list[list[int]]:
    """The model's parts in the pieces they stand in, by their boxes meeting (within
    `touch` LDU), largest first: a second vehicle beside the first, a figure standing
    apart. Where the builder stands a piece apart is its own to choose."""
    parent = list(range(len(boxes)))

    def root(i: int) -> int:
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    cell = 40.0
    grid: dict = collections.defaultdict(list)
    for i, (lo, hi) in enumerate(boxes):
        for cx in range(int(math.floor((lo[0] - touch) / cell)), int((hi[0] + touch) // cell) + 1):
            for cy in range(int(math.floor((lo[1] - touch) / cell)),
                            int((hi[1] + touch) // cell) + 1):
                for cz in range(int(math.floor((lo[2] - touch) / cell)),
                                int((hi[2] + touch) // cell) + 1):
                    grid[(cx, cy, cz)].append(i)
    for members in grid.values():
        for a in range(len(members)):
            for b in range(a + 1, len(members)):
                i, j = members[a], members[b]
                if root(i) == root(j):
                    continue
                if all(boxes[i][0][k] <= boxes[j][1][k] + touch and
                       boxes[j][0][k] <= boxes[i][1][k] + touch for k in range(3)):
                    parent[root(i)] = root(j)
    groups: dict = collections.defaultdict(list)
    for i in range(len(boxes)):
        groups[root(i)].append(i)
    return sorted(groups.values(), key=lambda g: (-len(g), g[0]))


# A piece apart of fewer parts than this is judged where the largest piece puts it:
# alone, a part could be laid on anything of its kind.
PIECE_ALONE = 3


def compare(model: list[Placed], build: list[Placed], bounds: Bounds,
            judged: set[int] | None = None) -> dict:
    """Each of the model's parts (by index; only `judged` ones, when given) as right,
    near, colour, place, part or missing against the build, and the build's extra
    parts. The build is laid on each piece of the model in turn (`pieces`), largest
    first, on what the pieces before it left. Returns {"yaw", "shift" (the largest
    piece's), "parts": {index: {kind, ...}}, "extra": [...], "earlier_lost"}."""
    boxes_m = [bounds.world(p) for p in model]
    free = set(range(len(build)))
    out: dict[int, dict] = {}
    wanted_all = {i for i in range(len(model)) if judged is None or i in judged}
    by_key: dict = collections.defaultdict(list)
    by_part: dict = collections.defaultdict(list)
    for j, b in enumerate(build):
        by_key[b.key()].append(j)
        by_part[same_part(b.part)].append(j)
    placed_boxes: dict = {}

    def box_b(j: int, laid: tuple) -> tuple:
        key = (j, laid[0], tuple(laid[1]))
        if key not in placed_boxes:
            placed_boxes[key] = bounds.world(build[j], YAWS[laid[0]], laid[1])
        return placed_boxes[key]

    laid_of: dict[int, tuple] = {}
    groups = pieces(boxes_m)
    first = None
    for group in groups:
        if first is None or len(group) >= PIECE_ALONE:
            rest = sorted(free)
            yaw, shift = align([model[i] for i in group], [build[j] for j in rest], bounds)
            laid = (yaw, shift)
            first = first or laid
        else:
            laid = first
        turn = YAWS[laid[0]]
        for i in group:
            laid_of[i] = laid
        wanted = [i for i in group if i in wanted_all]
        others = [i for i in group if i not in wanted_all]
        # The parts not judged (built before the stretch measured) take theirs first, so
        # a part of the stretch is not counted right for standing in an earlier one's place.
        for i in others + wanted:
            for j in by_key.get(model[i].key(), []):
                if j in free and _same_box(boxes_m[i], box_b(j, laid)):
                    free.discard(j)
                    turned = any(abs(a - b) > SAME_TURN for a, b in
                                 zip(model[i].turn, _mul(turn, build[j].turn)))
                    out[i] = {"kind": "right", "turned": turned, "by": j}
                    break
        for i in wanted:
            if i in out:
                continue
            for j in by_part.get(same_part(model[i].part), []):
                if j in free and _same_box(boxes_m[i], box_b(j, laid)):
                    free.discard(j)
                    out[i] = {"kind": "colour", "was": build[j].colour, "by": j}
                    break
        # Near: where it goes, seated a little off.
        for i in wanted:
            if i in out:
                continue
            here = _centre(boxes_m[i])
            for j in by_key.get(model[i].key(), []):
                if j in free and all(abs(c - h) < lim for c, h, lim in
                                     zip(_centre(box_b(j, laid)), here, NEAR)):
                    free.discard(j)
                    out[i] = {"kind": "near", "by": j}
                    break
    wanted = sorted(wanted_all)
    # Moved: as many of one part and colour as are left on both sides, nearest first,
    # each measured as its own piece lays the build.
    pairs = []
    for i in wanted:
        if i in out:
            continue
        here = _centre(boxes_m[i])
        for j in by_key.get(model[i].key(), []):
            if j in free:
                pairs.append((math.dist(here, _centre(box_b(j, laid_of[i]))), i, j))
    pairs.sort()
    for _d, i, j in pairs:
        if i in out or j not in free:
            continue
        free.discard(j)
        here, there = _centre(boxes_m[i]), _centre(box_b(j, laid_of[i]))
        off = [there[k] - here[k] for k in range(3)]
        out[i] = {"kind": "place", "by": j,
                  # Studs across, plates up, studs deep (LDraw's y is down).
                  "off": [round(off[0] / 20, 2) + 0.0, round(-off[1] / 8, 2) + 0.0,
                          round(off[2] / 20, 2) + 0.0]}
    for i in wanted:
        if i in out:
            continue
        best = max(((_overlap(boxes_m[i], box_b(j, laid_of[i])), j) for j in free),
                   default=(0.0, -1))
        if best[0] >= OVERLAP:
            free.discard(best[1])
            out[i] = {"kind": "part", "was": build[best[1]].part, "by": best[1]}
        else:
            out[i] = {"kind": "missing"}
    extra = [{"part": build[j].part, "colour": build[j].colour} for j in sorted(free)]
    lost_before = [i for i in range(len(model)) if i not in wanted_all and i not in out]
    yaw, shift = first or (0, [0.0, 0.0, 0.0])
    return {"yaw": yaw, "shift": shift, "parts": {i: out[i] for i in wanted}, "extra": extra,
            "earlier_lost": len(lost_before),
            "pieces": sum(1 for g in groups if len(g) >= PIECE_ALONE)}


# -- the truth: what each page adds ------------------------------------------------------


class Truth:
    """truth.json read: the model's parts, and for each the page that puts it on."""

    def __init__(self, data: dict) -> None:
        self.data = data
        self.ids = sorted(data["bricks"], key=int)
        self.parts = [Placed(data["bricks"][i]["part"], int(data["bricks"][i]["colour"]),
                             data["bricks"][i]["ldraw"], i) for i in self.ids]
        self.index = {ident: n for n, ident in enumerate(self.ids)}
        page_of_step: dict[int, int] = {}
        for page in data["pages"]:
            for step in page["steps"]:
                page_of_step.setdefault(int(step["plan"]), int(page["number"]))
        self.page_of_step = page_of_step
        attach_page: dict[int, int] = {}
        for step in data["plan"]:
            if step["attaches"] and step["index"] in page_of_step:
                attach_page[int(step["callout"])] = page_of_step[step["index"]]
        self.placed_on: dict[int, int] = {}
        self.built_on: dict[int, int] = {}
        self.step_of: dict[int, int] = {}
        for step in data["plan"]:
            page = page_of_step.get(step["index"])
            if page is None:
                continue
            put = attach_page.get(int(step["callout"]), page) if step["callout_step"] > 0 \
                else page
            for brick in step["bricks"]:
                n = self.index.get(str(brick))
                if n is not None and n not in self.placed_on:
                    self.placed_on[n] = put
                    self.built_on[n] = page
                    # The number its page prints: a callout's steps carry the number
                    # of the step that puts the callout on.
                    self.step_of[n] = int(step.get("number", 0))

        # A hose or a cable drawn in segments (LSynth's "~... Segment" parts) is one
        # flexible part in the box; a builder lays it, never its forty segments one at a
        # time. Kept in the model, never judged.
        names = _names()
        self.flex = {n for n, p in enumerate(self.parts)
                     if re.match(r"~.*segment", names.get(p.part, ""), re.I)}

    @staticmethod
    def load(path: Path) -> "Truth":
        return Truth(json.loads(path.read_text()))

    def step_pages(self) -> list[int]:
        return [int(p["number"]) for p in self.data["pages"] if p["kind"] in ("steps", "callout")]

    def page(self, number: int) -> dict:
        return next(p for p in self.data["pages"] if int(p["number"]) == number)

    def ldraw(self, indices: list[int], title: str = "seed") -> str:
        lines = [f"0 {title}", f"0 Name: {title}.ldr", ""]
        for n in indices:
            p = self.parts[n]
            lines.append(" ".join(["1", str(p.colour), *(_number(v) for v in p.at + p.turn),
                                   p.part + ".dat"]))
        return "\n".join(lines) + "\n"


_NAMES: dict[str, str] = {}


def _names() -> dict[str, str]:
    """Each part's catalogue name, or none where there is no catalogue."""
    if not _NAMES:
        try:
            for p in json.loads((ROOT / "assets" / "generated" / "catalogue.json")
                                .read_text())["parts"]:
                _NAMES[p["id"].lower()] = re.sub(r"\s+", " ", p["name"]).strip()
        except (OSError, ValueError, KeyError):
            pass
    return _NAMES


def _number(v: float) -> str:
    return ("%.4f" % v).rstrip("0").rstrip(".") if v != int(v) else str(int(v))


def inventory(truth: Truth) -> list[dict]:
    """The parts in the box: part, its name, colour, colour's name, how many. A hose's
    segments are not parts in a box."""
    catalogue = _names()
    colours = {c["code"]: c["name"] for c in
               json.loads((ROOT / "assets" / "generated" / "colors.json").read_text())}
    counts = collections.Counter((p.part, p.colour) for n, p in enumerate(truth.parts)
                                 if n not in truth.flex)
    return [{"part": part, "name": catalogue.get(part, part),
             "colour": colour, "colour_name": colours.get(colour, str(colour)), "count": n}
            for (part, colour), n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))]


# -- score ----------------------------------------------------------------------------


def score(truth: Truth, build: list[Placed], first: int, last: int, bounds: Bounds,
          said: dict[int, dict] | None = None) -> dict:
    """The build against the model's parts placed on pages first..last, a row a page."""
    judged = {n for n, page in truth.placed_on.items()
              if first <= page <= last and n not in truth.flex}
    before = {n for n, page in truth.placed_on.items() if page < first}
    # The parts built before the stretch are in the build too (its seed): compared
    # against the model's parts up to its end only.
    scope = sorted(judged | before)
    model = [truth.parts[n] for n in scope]
    local = {n: k for k, n in enumerate(scope)}
    result = compare(model, build, bounds, {local[n] for n in judged})
    rows: dict[int, dict] = {}
    for n in judged:
        page = truth.placed_on[n]
        row = rows.setdefault(page, {"page": page, "parts": 0, **{k: 0 for k in KINDS},
                                     "turned": 0, "carried": 0, "offsets": [], "wrong": []})
        got = result["parts"][local[n]]
        row["parts"] += 1
        row[got["kind"]] += 1
        row["turned"] += 1 if got.get("turned") else 0
        if got["kind"] not in ("right", "near"):
            p = truth.parts[n]
            row["wrong"].append({"part": p.part, "colour": p.colour,
                                 "step": truth.step_of.get(n, 0),
                                 **{k: v for k, v in got.items() if k != "by"}})
        if got["kind"] == "place":
            row["offsets"].append(got["off"])
    for page, row in rows.items():
        row["steps"] = [s["number"] for s in truth.page(page)["steps"]]
        row["built_on"] = sorted({truth.built_on[n] for n in judged
                                  if truth.placed_on[n] == page})
        if said and page in said:
            row["unclear"] = said[page].get("unclear", [])
            row["placed_said"] = said[page].get("placed")
    for n in carried(truth, judged, scope, result["parts"], local, bounds):
        rows[truth.placed_on[n]]["carried"] += 1
        got = result["parts"][local[n]]
        got["carried"] = True
        for wrong in rows[truth.placed_on[n]]["wrong"]:
            if wrong.get("off") == got["off"] and wrong["part"] == truth.parts[n].part \
                    and not wrong.get("carried"):
                wrong["carried"] = True
                break
    causes: collections.Counter = collections.Counter()
    for row in rows.values():
        said_steps = collections.defaultdict(list)
        for u in row.get("unclear", []):
            said_steps[int(u.get("step") or 0)].append(str(u.get("why", "other")))
        for wrong in row["wrong"]:
            if wrong.get("carried"):
                causes["carried"] += 1
                continue
            whys = said_steps.get(wrong["step"]) or said_steps.get(0) or ["unsaid"]
            for why in whys:
                causes[why] += 1 / len(whys)
    totals = {k: sum(r[k] for r in rows.values())
              for k in ("parts", *KINDS, "turned", "carried")}
    return {"pages": [rows[p] for p in sorted(rows)], "totals": totals,
            # Wrong parts by what the builder said of their step (a page's word without
            # a step for the rest; "unsaid" where it said nothing), shared among its whys.
            "said_causes": {k: round(v, 1) for k, v in causes.most_common()},
            "extra": len(result["extra"]), "extra_parts": result["extra"][:200],
            "earlier_lost": result["earlier_lost"], "yaw": result["yaw"],
            "shift": result["shift"]}


# Two parts moved by the same studs and plates, to this much.
SAME_OFF = 0.3


def _touch(a: tuple, b: tuple, gap: float = 1.0) -> bool:
    return all(a[0][k] <= b[1][k] + gap and b[0][k] <= a[1][k] + gap for k in range(3))


def carried(truth: Truth, judged: set[int], scope: list[int], parts: dict[int, dict],
            local: dict[int, int], bounds: Bounds) -> set[int]:
    """The judged parts put somewhere else only because what they stand on or beside was:
    each moved by the same studs and plates as a part it touches that an earlier page put
    on, or that is carried itself. A builder who read a layer one brick low lays the next
    layer right on it, and that page was followed; its parts are wrong, its page is not."""
    off = {n: parts[local[n]]["off"] for n in judged if parts[local[n]]["kind"] == "place"}
    if not off:
        return set()
    boxes = {n: bounds.world(truth.parts[n]) for n in scope}
    near = {n: [m for m in off if m != n and _touch(boxes[n], boxes[m])] for n in off}
    out: set[int] = set()
    for page in sorted({truth.placed_on[n] for n in off}):
        here = [n for n in off if truth.placed_on[n] == page]
        grew = True
        while grew:
            grew = False
            for n in here:
                if n in out:
                    continue
                if any((truth.placed_on[m] < page or m in out)
                       and all(abs(a - b) <= SAME_OFF for a, b in zip(off[m], off[n]))
                       for m in near[n]):
                    out.add(n)
                    grew = True
    return out


# -- make -----------------------------------------------------------------------------


def make(model: Path, out: Path, app: Path, only: list[int] | None = None) -> None:
    """The booklet and its truth, and its pages photographed: every page, or `only` these
    (the castle's 324 take most of an hour, and a stretch needs a dozen)."""
    out.mkdir(parents=True, exist_ok=True)
    home = out / "xdg-make"
    home.mkdir(exist_ok=True)
    env = {k: v for k, v in os.environ.items() if k not in ("ANTHROPIC_API_KEY", "WAYLAND_DISPLAY")}
    # Without it Vulkan under Xvfb finds no window system on the card and draws on
    # llvmpipe, lease or not: thirty times slower.
    env.update(XDG_DATA_HOME=str(home), MESA_VK_WSI_DEBUG="sw")
    if not (out / "truth.json").exists():
        with (out / "truth.log").open("w") as log:
            status = subprocess.run(
                [GPU, "xvfb-run", "-a", f"--server-args={SCREEN}", "godot", "--path", str(app),
                 "--resolution", "1200x800", "--script", "src/dev/booklet_truth.gd", "--",
                 f"--model={model.resolve()}", f"--html={(out / 'booklet.html').resolve()}",
                 f"--json={(out / 'truth.json').resolve()}"],
                cwd=app, env=env, stdout=log, stderr=subprocess.STDOUT).returncode
        if status != 0 or not (out / "truth.json").exists():
            raise SystemExit(f"make: no booklet (status {status}); see {out / 'truth.log'}")
    truth = Truth.load(out / "truth.json")
    count = len(truth.data["pages"])
    shots = out / "pages"
    wanted = [n for n in (only or range(1, count + 1)) if 1 <= n <= count]
    if any(not (shots / f"page-{n}.png").exists() for n in wanted) or page_scale(out) != SCALE:
        pages = ",".join(str(n) for n in wanted)
        with (out / "pages.log").open("w") as log:
            status = subprocess.run(
                [HEAVY, "node", str(ROOT / "tools" / "web" / "booklet_print.mjs"),
                 str(out / "booklet.html"), str(shots), "--shots-only", f"--pages={pages}",
                 f"--scale={SCALE}"],
                cwd=ROOT, stdout=log, stderr=subprocess.STDOUT).returncode
        if status != 0:
            raise SystemExit(f"make: the pages were not photographed; see {out / 'pages.log'}")
        (shots / "scale.txt").write_text(f"{SCALE}\n")
    (out / "inventory.json").write_text(json.dumps(inventory(truth), indent=1) + "\n")
    shutil.rmtree(home, ignore_errors=True)
    print(f"make: {count} pages, {len(truth.parts)} parts, {len(truth.step_pages())} of steps")


def _page_list(text: str) -> list[int]:
    """Pages as a list says them: "2-5,9" is 2, 3, 4, 5 and 9."""
    pages: list[int] = []
    for piece in text.split(","):
        low, _, high = piece.partition("-")
        pages.extend(range(int(low), int(high or low) + 1))
    return pages


def page_scale(out: Path) -> int:
    """How much finer than the screen's print size DIR's pages were photographed."""
    said = out / "pages" / "scale.txt"
    return int(said.read_text().strip()) if said.exists() else 1


# -- build ----------------------------------------------------------------------------


PROMPT = """You are building a LEGO® model from its instruction booklet, the way a person at a \
table follows one, in Brickworks, a LEGO CAD app, through the booklet server's tools. You have \
the booklet's pages (booklet_page) and the parts in the box, and nothing else: build what the \
pages show, never what you think the model ought to be.

The parts in the box ({kinds} kinds, {pieces} pieces), part number, name, colour code and \
name, how many:
{parts}

{start}
{notes}
Now build pages {first} to {last}, a page at a time:
1. booklet_page shows a page. {step_reading} Look at the page before or after when it \
helps.
2. Find where each new part goes on what is built (look_at_model lists every part with its \
coordinates; view_model shows the model from a side, as the booklet draws it from the \
front-left corner unless the page shows a turn), and place it with edit_model's add, a step \
at a time. attachment_points gives a stud's exact coordinates.
3. view_model, compare it with the page's picture, and fix what differs (edit_model, undo).
4. page_done for the page: how many parts you placed, and each thing the page did not let \
you tell, with why. Then the next page.

The app holds a model to its ground, y=0, as a design tool does: it refuses a change that \
would put a part below y=0, or leave a part held by nothing. Where a person would lift the \
model to put a part under it, move every part up (edit_model's move, dy in plates) in the \
same call that adds the part under it. A part held only by a part still to come goes in the \
same call as that part. The ground is the app's rule, not the booklet's: say nothing of it \
in page_done. A sub-assembly the booklet builds on {apart} is built apart, as a person builds \
it in their hand: beside the model, named with edit_model's \
assemblies (the app refuses a piece apart that nothing names), then moved onto the model \
(edit_model's move) on the page that puts it on. Building it where it goes from the start is \
as good, when you can tell where that is.
Keep going until page_done({last}) is said. Do not ask questions: decide as a person would, \
and say in page_done what you were unsure of."""


# How a Brickworks booklet's pages read, in the prompt. A booklet drawn another way says how
# its own read in DIR/reading.json (or build's --reading): "step" for these, "apart" for
# where it builds a sub-assembly, "page" for the page tool's (booklet_mcp.READING).
READING = {
    "step": "Each step on it has its number, a box of the parts it adds (with how many), and a "
            "picture of the model with those new parts outlined in orange.",
    "apart": "pages of its own (a yellow page)",
}


def reading(out: Path, given: Path | None = None) -> dict[str, str]:
    """How DIR's pages read: READING, with what DIR/reading.json (or `given`) says."""
    path = given or out / "reading.json"
    said = json.loads(path.read_text()) if path.exists() else {}
    return {**READING, **{k: str(v) for k, v in said.items() if k in ("step", "apart", "page")}}


def _env() -> dict[str, str]:
    env = {k: v for k, v in os.environ.items() if not SECRETS.search(k)}
    env.update(MCP_TOOL_TIMEOUT="300000", MCP_TIMEOUT="120000")
    return env


def _wait_for(path: Path, words: str, seconds: float, process: subprocess.Popen) -> bool:
    end = time.time() + seconds
    while time.time() < end:
        if path.exists() and words in path.read_text(errors="replace"):
            return True
        if process.poll() is not None:
            return False
        time.sleep(1.0)
    return False


def _ask(port: int, tool: str, arguments: dict) -> dict:
    sys.path.insert(0, str(ROOT / "tools"))
    import brickworks_mcp  # noqa: PLC0415
    return brickworks_mcp.App(port).ask(tool, arguments)


def _said(run: Path) -> dict[int, dict]:
    """Each page's last page_done."""
    out: dict[int, dict] = {}
    path = run / "pages.jsonl"
    for line in path.read_text().splitlines() if path.exists() else []:
        try:
            row = json.loads(line)
        except ValueError:
            continue
        out[int(row.get("page", 0))] = row
    return out


def build(out: Path, name: str, port: int, first: int | None, last: int | None, each: int,
          app: Path, minutes: int, scratch: Path, read_as: Path | None = None) -> None:
    truth = Truth.load(out / "truth.json")
    reads = reading(out, read_as)
    pages = truth.step_pages()
    first = first if first is not None else pages[0]
    last = last if last is not None else pages[-1]
    todo = [p for p in pages if first <= p <= last]
    run = out / "runs" / name
    run.mkdir(parents=True, exist_ok=True)
    home = run / "xdg"
    models = home / "godot" / "app_userdata" / "Brickworks" / "models"
    models.mkdir(parents=True, exist_ok=True)
    seed = sorted(n for n, page in truth.placed_on.items() if page < first)
    tail = ["--", f"--mcp={port}", "--draw-by=" + json.dumps(DRAWER)]
    if seed:
        (run / "seed.ldr").write_text(truth.ldraw(seed, f"seed before page {first}"))
        tail.insert(1, f"--model={(run / 'seed.ldr').resolve()}")
    record = {"model": truth.data["model"], "first": first, "last": last, "pages": todo,
              "seed_parts": len(seed), "each": each, "port": port,
              "page_scale": page_scale(out), "reading": reads,
              "app": str(app), "commit": subprocess.run(
                  ["git", "rev-parse", "--short", "HEAD"], cwd=app, capture_output=True,
                  text=True).stdout.strip(), "started": time.strftime("%Y-%m-%d %H:%M:%S")}
    (run / "run.json").write_text(json.dumps(record, indent=1) + "\n")
    env = {k: v for k, v in os.environ.items() if k not in ("ANTHROPIC_API_KEY", "WAYLAND_DISPLAY")}
    env.update(XDG_DATA_HOME=str(home), MESA_VK_WSI_DEBUG="sw")
    log = run / "app.log"
    # Stopped by a signal, the app and its session are stopped too (the finally below).
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    with log.open("w") as said:
        process = subprocess.Popen(["godot", "--headless", "--path", str(app), "--log-file",
                                    str(run / "godot.log"), *tail], cwd=app, env=env,
                                   stdout=said, stderr=subprocess.STDOUT, start_new_session=True)
    try:
        if not _wait_for(log, "command socket: listening", 300, process):
            raise SystemExit(f"build: the app never listened; see {log}")
        if not seed:
            _ask(port, "clear_model", {})
        stock = json.loads((out / "inventory.json").read_text())
        parts = "\n".join(f"  {s['part']} {s['name']}, colour {s['colour']} {s['colour_name']}: "
                          f"{s['count']}" for s in stock)
        cwd = scratch / f"cwd-{out.name}-{name}"
        cwd.mkdir(parents=True, exist_ok=True)
        config = run / "mcp.json"
        server = [str(MCP_SERVER), f"--port={port}", f"--pages={(out / 'pages').resolve()}",
                  f"--run={run.resolve()}", f"--models={models.resolve()}"]
        if "page" in reads:
            (run / "reading-page.txt").write_text(reads["page"] + "\n")
            server.append(f"--reading={(run / 'reading-page.txt').resolve()}")
        config.write_text(json.dumps({"mcpServers": {"booklet": {
            "command": sys.executable, "args": server}}}))
        tries: collections.Counter = collections.Counter()
        while True:
            done = _said(run)
            left = [p for p in todo if p not in done]
            if not left:
                break
            chunk_first = left[0]
            tries[chunk_first] += 1
            if tries[chunk_first] > 2:
                # A page two sessions could not finish is left; the score says so.
                todo.remove(chunk_first)
                (run / "skipped.txt").open("a").write(f"{chunk_first}\n")
                continue
            chunk = left[:each]
            notes = [done[p]["notes"] for p in sorted(done) if done[p].get("notes")]
            start = (f"The booklet's pages before page {first} are built already, exactly as "
                     "they show: look_at_model and view_model show the model as they leave it."
                     if seed and chunk_first == todo[0] else
                     "Pages before these are built: look_at_model and view_model show what you "
                     "built." if chunk_first != pages[0] else
                     "Nothing is built yet: the model starts from nothing on page "
                     f"{chunk_first}.")
            prompt = PROMPT.format(kinds=len(stock), pieces=sum(s["count"] for s in stock),
                                   parts=parts, start=start,
                                   notes=("Your notes from the pages before:\n" +
                                          "\n".join(f"- {n}" for n in notes[-6:]) + "\n")
                                   if notes else "", first=chunk[0], last=chunk[-1],
                                   step_reading=reads["step"], apart=reads["apart"])
            stream = run / f"session-{chunk[0]}-{chunk[-1]}-{tries[chunk_first]}.jsonl"
            started = time.time()
            with stream.open("w") as said:
                status = subprocess.run(
                    ["timeout", "--kill-after=30", str(minutes * 60), "claude", "-p", prompt,
                     "--mcp-config", str(config), "--strict-mcp-config", "--tools", "",
                     "--restricted", "--allowedTools", "mcp__booklet",
                     "--output-format", "stream-json", "--verbose"],
                    cwd=cwd, env=_env(), stdout=said, stderr=subprocess.STDOUT).returncode
            print(f"[{time.strftime('%H:%M:%S')}] pages {chunk[0]}-{chunk[-1]}: status "
                  f"{status} in {(time.time() - started) / 60:.1f} min, done "
                  f"{sorted(p for p in _said(run) if p in chunk)}", flush=True)
    finally:
        try:
            os.killpg(process.pid, signal.SIGTERM)
            process.wait(30)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    record["ended"] = time.strftime("%Y-%m-%d %H:%M:%S")
    (run / "run.json").write_text(json.dumps(record, indent=1) + "\n")


def last_snapshot(run: Path) -> Path | None:
    shots = sorted((run / "snapshots").glob("page-*.ldr"),
                   key=lambda p: int(p.stem.split("-")[1]))
    return shots[-1] if shots else None


def score_run(out: Path, name: str) -> dict:
    run = out / "runs" / name
    record = json.loads((run / "run.json").read_text())
    truth = Truth.load(out / "truth.json")
    shot = last_snapshot(run)
    build_parts = read_ldraw(shot.read_text()) if shot else []
    result = score(truth, build_parts, int(record["first"]), int(record["last"]), Bounds.load(),
                   _said(run))
    result.update(run=name, snapshot=str(shot) if shot else "", seed_parts=record["seed_parts"],
                  first=record["first"], last=record["last"],
                  minutes=_minutes(run))
    (run / "score.json").write_text(json.dumps(result, indent=1) + "\n")
    return result


def _minutes(run: Path) -> float:
    total = 0.0
    for stream in run.glob("session-*.jsonl"):
        for line in stream.read_text(errors="replace").splitlines():
            if '"type":"result"' in line.replace(" ", ""):
                try:
                    total += float(json.loads(line).get("duration_ms", 0)) / 60000
                except ValueError:
                    pass
    return round(total, 1)


def report(results: list[dict]) -> str:
    lines = []
    for r in results:
        t = r["totals"]
        share = (lambda k: f"{100 * t[k] / t['parts']:.0f}%" if t["parts"] else "-")
        lines.append(f"{r['run']}: pages {r['first']}-{r['last']}, {t['parts']} parts: right "
                     f"{t['right']} ({share('right')}), near {t.get('near', 0)}, colour "
                     f"{t['colour']}, place {t['place']} ({t.get('carried', 0)} carried), "
                     f"part {t['part']}, missing {t['missing']}; extra {r['extra']}; earlier "
                     f"pages' parts lost {r['earlier_lost']}; {r['minutes']} min")
        lines.append("| page | steps | parts | right | near | colour | place (carried) | part | "
                     "missing | builder could not tell |")
        lines.append("|---|---|---|---|---|---|---|---|---|---|")
        for row in r["pages"]:
            unclear = "; ".join(f"{u.get('why')}: {u.get('what', '')[:80]}"
                                for u in row.get("unclear", []))
            lines.append(f"| {row['page']} | {','.join(map(str, row['steps']))} | "
                         f"{row['parts']} | {row['right']} | {row.get('near', 0)} | "
                         f"{row['colour']} | {row['place']} ({row.get('carried', 0)}) | "
                         f"{row['part']} | {row['missing']} | {unclear} |")
        lines.append("")
    return "\n".join(lines)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    m = sub.add_parser("make")
    m.add_argument("model", type=Path)
    m.add_argument("--out", type=Path, required=True)
    m.add_argument("--app", type=Path, default=ROOT)
    m.add_argument("--pages", type=_page_list, help="photograph only these: 2-5,9")
    b = sub.add_parser("build")
    b.add_argument("out", type=Path)
    b.add_argument("--run", required=True)
    b.add_argument("--port", type=int, required=True)
    b.add_argument("--from", dest="first", type=int)
    b.add_argument("--to", dest="last", type=int)
    b.add_argument("--pages-a-session", dest="each", type=int, default=3)
    b.add_argument("--app", type=Path, default=ROOT)
    b.add_argument("--minutes", type=int, default=30, help="a session's most")
    b.add_argument("--scratch", type=Path, default=Path(os.environ.get("TMPDIR", "/tmp")))
    b.add_argument("--reading", type=Path, help="how the pages read, for DIR/reading.json")
    s = sub.add_parser("score")
    s.add_argument("out", type=Path)
    s.add_argument("--run", required=True)
    r = sub.add_parser("report")
    r.add_argument("out", type=Path)
    r.add_argument("--run", action="append", required=True)
    args = parser.parse_args(argv[1:])
    if args.command == "make":
        make(args.model, args.out, args.app.resolve(), args.pages)
    elif args.command == "build":
        build(args.out, args.run, args.port, args.first, args.last, args.each,
              args.app.resolve(), args.minutes, args.scratch, args.reading)
        print(report([score_run(args.out, args.run)]))
    elif args.command == "score":
        print(report([score_run(args.out, args.run)]))
    else:
        print(report([json.loads((args.out / "runs" / n / "score.json").read_text())
                      for n in args.run]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
