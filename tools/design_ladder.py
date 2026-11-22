#!/usr/bin/env python3
"""A ladder for each held-out real set, so the judge can say how far up it a design is.

    python3 tools/design_ladder.py build [--which proof|tune] [--subjects N,N]
    python3 tools/design_ladder.py render [--which ...] [--subjects ...] [--jobs 3]
    heavy python3 tools/design_ladder.py order [--which proof] [--jobs 6] [--cap 1500]
    heavy python3 tools/design_ladder.py place --arm d24p44base --date 2026-11-16 --which proof
    heavy python3 tools/design_ladder.py place ... --again      (the same designs, judged afresh)
    python3 tools/design_ladder.py seed [--before DIR]      (an earlier ladder's verdicts)
    python3 tools/design_ladder.py report [--out DIR] [--before DIR]
    python3 tools/design_ladder.py sheet [--subjects N,N]
    python3 tools/design_ladder.py leaks ARM_DIR...
    python3 tools/design_ladder.py reach [--port 10830]

realset.py asks whether a design beats the real set. Over eight lever rounds
(design20 to design27) that answer moved for no lever: the subject decided the
verdict, 30 of the 44 proof subjects lost to every design, and a lever's step
was smaller than the noise (docs/APP_UX11.md, "The design track"). A ladder
gives the judge rungs between the set and nothing:

  1. the set as it is;
  1.5. half its SNOT taken out (ladder2): on a Technic set its skin (panels,
     fairings and the System parts on it) laid as plates and its working part
     left (beams, pins, gears, links); on any other set its SNOT parts laid
     smallest first while they are no more than half its SNOT's volume;
  2. its SNOT taken out: every part whose studs do not point up (style.py's
     `facing`) replaced, in its own colour, by plain plates studs up filling
     the room it took, but its wheels, tyres and axles, which a studs-up build
     still rolls on (ladder2: they were laid as slabs, and half the designs sat
     between the set and this rung);
  3. its curves stepped: rung 2 with its wheels laid too, and every part
     style.py calls a curve (curved slopes, arches, rounds, cones, domes,
     wedges) replaced by plain plates, in columns a stud across, each as high
     as the part's own top over it, so a curved slope steps down and an arch
     is filled in;
  4. its colours flattened: every solid colour made the nearest of the three
     the model has most of, by volume; glass keeps its own;
  5. a naive stack of its outline in plain bricks, studs up, in three
     colours (calibrate.naive_stack, realset's own calibration anchor).

Rungs 1.5 to 4 each keep only parts the rung above kept, where they were, so a
rung is never better than the one above it. Each is drawn by
realset's renderer (run.render: the same cameras, views and GPU) and judged
by realset's judge as it is (realset.ask, both orders, its prompt untouched):
the judge sees only pictures under names that say nothing. A rung remade is a
new version with a new key (`ladder:N:r2:v2`), so `seed` can copy an earlier
ladder's verdicts in and only what changed is asked again.

The ladder is made from the sets' own files, so it is an answer key. It lives
in the main checkout's bench/ladder/, which nothing a design session runs can
open: the session has no file tools (realset starts Claude Code with
`--tools ""`), open_model opens the person's saved models, the examples, the
library shelf (held out) and links, brickify reads only meshes, and the
folder has a .gdignore, so Godot never imports or exports it. `reach` starts
the app as realset does and asks each of those tools for a ladder file, and
`leaks` is design24's leak audit (an answer naming the set's own file or
number) with any mention of the ladder added.

Placing a design: it is judged against rung 3, then up or down the ladder
until a verdict splits or the end is reached, both orders each time; the
design's own verdicts against the set (its record) are rung 1's, asked afresh
on a second judging (--again). Its place is a number from 0.5 (above the set)
to 5.5 (below the naive stack): a rung it ties is its place, and between two
rungs it sits halfway (between 1 and 1.5 is 1.25).
"""

from __future__ import annotations

import argparse
import json
import math
import os
import random
import re
import shutil
import signal
import subprocess
import sys
import threading
import time
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

import style  # noqa: E402
from bench import calibrate, judge, pairwise, realset  # noqa: E402
from bench import run as bench  # noqa: E402
from ldraw.parser import Matrix  # noqa: E402

LADDER = bench.RESULTS.parent / "ladder"
OUT = bench.RESULTS / "ladder2-2026-11-22"      # the ladder's verdicts, from designmeasure's on
BEFORE = bench.RESULTS / "designmeasure-2026-11-20"
RUNGS: dict[float, str] = {
    1: "the set as it is",
    1.5: "half its SNOT taken out: a Technic set's skin, or the smaller half of a set's SNOT",
    2: "its SNOT taken out, laid studs up, its wheels kept",
    3: "its curves stepped", 4: "its colours flattened to the main three",
    5: "a naive stack of its outline in bricks"}
ORDER = tuple(RUNGS)                    # best first
ADJACENT = tuple(zip(ORDER, ORDER[1:]))
PAIRS = ADJACENT + ((1, 5),)
# What rolls: kept at rung 2, since a studs-up build still rolls on them.
ROLLING = re.compile(r"(?<!steering )\b(wheel|tyre|tire|tread|track)s?\b(?! arch)"
                     r"|^technic axle \d", re.I)
# A Technic set's skin, laid at rung 1.5; its beams, pins, gears and links, its
# working part, are left. Its parts of other categories (tiles, plates, slopes) are skin too.
SKIN = re.compile(r"\b(panel|fairing|hose|mudguard|bumper|windscreen|spoiler)s?\b", re.I)
PLATE, STUD = 8.0, 20.0
# A cell a stud across and a plate high is laid when this share of it is
# taken by the parts it replaces, and left when half of it is a kept part's.
FILL, TAKEN = 0.4, 0.5
# Plain plates a course is laid in, largest first: (studs along x, along z, part).
PLATES = ((4, 2, "3020"), (2, 4, "3020"), (3, 2, "3021"), (2, 3, "3021"), (2, 2, "3022"),
          (4, 1, "3710"), (1, 4, "3710"), (3, 1, "3623"), (1, 3, "3623"), (2, 1, "3023"),
          (1, 2, "3023"), (1, 1, "3024"))
TURNED = Matrix(0, 0, 1, 0, 1, 0, -1, 0, 0)
COLOURS_KEPT = 3
CAP = 1500          # judge calls in all, as the brief allows


# -- a rung: the parts kept, and cells laid in plain plates ---------------------


@dataclass
class Rung:
    kept: list[tuple[style.Placed, style.PartInfo | None]]
    cells: dict[tuple[int, int, int], int]      # (x, course, z) -> colour
    origin: tuple[float, float, float]           # x0, bottom (LDraw y, down), z0
    fix: Matrix                                  # squared frame -> the file's frame
    embedded: dict[str, str] = field(default_factory=dict)   # FILE blocks the kept need
    said: list[str] = field(default_factory=list)


def _blocks(text: str) -> dict[str, str]:
    """An .mpd's files by their normalised name, each as written."""
    out: dict[str, list[str]] = {}
    current = None
    for line in text.splitlines():
        bits = line.split()
        if len(bits) >= 3 and bits[0] == "0" and bits[1].upper() == "FILE":
            current = style.normalise_filename(" ".join(bits[2:]))
            out[current] = []
            continue
        if len(bits) >= 2 and bits[0] == "0" and bits[1].upper() == "NOFILE":
            current = None
            continue
        if current is not None:
            out[current].append(line)
    return {name: "\n".join(lines) for name, lines in out.items()}


def _transpose3(m: Matrix) -> Matrix:
    return Matrix(m.a, m.d, m.g, m.b, m.e, m.h, m.c, m.f, m.i)


def _rot(m: Matrix) -> Matrix:
    return Matrix(m.a, m.b, m.c, m.d, m.e, m.f, m.g, m.h, m.i)


def start(text: str, parts: style.Parts) -> Rung:
    """Rung 1, read: every part in the frame it was built square in."""
    model = style.read(text)
    pairs = [(p, parts.get(p.part, model.embedded)) for p in model.placed]
    # Every part goes through the square-up, those with no info as unoriented:
    # only oriented parts vote on the frame, and all are turned with it.
    shown = [(p, info if info is not None else style.PartInfo(p.part, "", None, False))
             for p, info in pairs]
    squared, _angle = style._square_up(shown)  # type: ignore[arg-type]
    # squared = F @ file for every part; F is a turn, so the file's frame is F^T @ squared.
    fix = Matrix()
    for (old, _i), (new, _j) in zip(shown, squared):
        if abs(abs(old.matrix.determinant()) - 1.0) < 0.01:
            fix = _transpose3(_rot(new.matrix) @ _transpose3(_rot(old.matrix)))
            break
    kept = [(new, info) for (new, _shown), (_p, info) in zip(squared, pairs)]
    boxes = [b for b in style._boxes([(p, i) for p, i in kept if i is not None and i.box],
                                     parts)]
    if boxes:
        bottom = max(b.centre[1] + b.half[1] for b in boxes)
        lows = Counter()
        for b in boxes:
            lows[(round(b.centre[0] - b.half[0]) % 20, round(b.centre[2] - b.half[2]) % 20)] += 1
        (x0, z0), _n = lows.most_common(1)[0]
    else:
        bottom, x0, z0 = 0.0, 0, 0
    blocks = _blocks(text)
    embedded = {name: body for name, body in blocks.items()
                if style._part_id(name) in model.embedded}
    return Rung(kept, {}, (float(x0), bottom, float(z0)), fix, embedded)


def _cell_of(rung: Rung, x: float, y: float, z: float) -> tuple[int, int, int]:
    x0, bottom, z0 = rung.origin
    return (math.floor((x - x0) / STUD), math.floor((bottom - y) / PLATE),
            math.floor((z - z0) / STUD))


def _cover(rung: Rung, boxes, into: dict, colours: dict | None = None) -> None:
    """How much of each cell the boxes take, summed (a cell's volume is 1)."""
    x0, bottom, z0 = rung.origin
    volume = STUD * PLATE * STUD
    for b in boxes:
        lo = [b.centre[k] - b.half[k] for k in range(3)]
        hi = [b.centre[k] + b.half[k] for k in range(3)]
        for i in range(math.floor((lo[0] - x0) / STUD), math.floor((hi[0] - x0) / STUD) + 1):
            ox = min(hi[0], x0 + (i + 1) * STUD) - max(lo[0], x0 + i * STUD)
            if ox <= 0:
                continue
            for k in range(math.floor((lo[2] - z0) / STUD), math.floor((hi[2] - z0) / STUD) + 1):
                oz = min(hi[2], z0 + (k + 1) * STUD) - max(lo[2], z0 + k * STUD)
                if oz <= 0:
                    continue
                for j in range(math.floor((bottom - hi[1]) / PLATE),
                               math.floor((bottom - lo[1]) / PLATE) + 1):
                    oy = min(hi[1], bottom - j * PLATE) - max(lo[1], bottom - (j + 1) * PLATE)
                    if oy <= 0:
                        continue
                    share = ox * oy * oz / volume
                    into[(i, j, k)] = into.get((i, j, k), 0.0) + share
                    if colours is not None:
                        colours.setdefault((i, j, k), Counter())[b.colour] += share


def _taken(rung: Rung, parts: style.Parts) -> dict:
    taken: dict = {}
    _cover(rung, style._boxes([(p, i) for p, i in rung.kept if i is not None and i.box],
                              parts), taken)
    return taken


def _lay(rung: Rung, votes: dict[tuple[int, int, int], Counter], parts: style.Parts) -> int:
    """Votes' cells laid, unless a kept part already takes half of one."""
    taken = _taken(rung, parts)
    laid = 0
    for cell, count in votes.items():
        if cell in rung.cells or taken.get(cell, 0.0) >= TAKEN:
            continue
        rung.cells[cell] = count.most_common(1)[0][0]
        laid += 1
    return laid


def off_up(p: style.Placed, info: style.PartInfo | None) -> bool:
    """A building part, with a place in space, whose studs do not point up."""
    return (info is not None and info.box is not None and info.oriented
            and style.building(info) and style.facing(p.matrix) != "up")


def rolling(info: style.PartInfo) -> bool:
    return bool(ROLLING.search(f"{info.name}|{info.category}"))


def snot_out(rung: Rung, parts: style.Parts, keep_rolling: bool = False,
             only: set[int] | None = None, said: str = "") -> Rung:
    """Rung 2: every part whose studs do not point up, laid as plates studs up; its
    wheels, tyres and axles kept as the set has them when keep_rolling. With `only`
    (indexes into rung.kept), just those parts: rung 1.5."""
    out, gone, rolled = [], [], 0
    for n, (p, info) in enumerate(rung.kept):
        laid = off_up(p, info)
        if laid and keep_rolling and info is not None and rolling(info):
            laid, rolled = False, rolled + 1
        if laid and only is not None and n not in only:
            laid = False
        (gone if laid else out).append((p, info))
    made = Rung(out, dict(rung.cells), rung.origin, rung.fix, rung.embedded, list(rung.said))
    cover: dict = {}
    votes: dict = {}
    _cover(made, style._boxes(gone, parts), cover, votes)
    laid = _lay(made, {c: v for c, v in votes.items() if cover[c] >= FILL}, parts)
    if said:
        made.said.append(f"{said}: {len(gone)} parts laid as {laid} plate cells")
    else:
        made.said.append(f"SNOT out: {len(gone)} parts not studs up, laid as {laid} plate cells"
                         + (f"; {rolled} wheels, tyres and axles kept" if rolled else ""))
    return made


def _volume(info: style.PartInfo) -> float:
    lo, hi = info.box or ((0, 0, 0), (0, 0, 0))
    return abs((hi[0] - lo[0]) * (hi[1] - lo[1]) * (hi[2] - lo[2]))


def half_out(rung: Rung, parts: style.Parts, technic: bool) -> Rung:
    """Rung 1.5: half of what rung 2 lays, so it sits between the set and rung 2.

    A Technic set's skin is laid (its panels and fairings, and the System parts
    on it) and its working part left: beams, pins, gears and links. Rung 2 lays
    those too, and fills the frame solid; the judge named that every time it
    put rung 2 under the set, and a design with an open frame beats it.

    Any other set's SNOT is laid smallest part first while the parts laid are no
    more than half its volume: the details go and the big sideways walls stay.
    Rung 2 lays the rest.
    Either way rung 1.5 lays only parts rung 2 lays, never a wheel."""
    laid_at_two = [(n, p, info) for n, (p, info) in enumerate(rung.kept)
                   if off_up(p, info) and info is not None and not rolling(info)]
    if technic:
        chosen = {n for n, _p, info in laid_at_two
                  if info.category.lower() != "technic" or SKIN.search(info.name)}
        said = "half the SNOT out (the Technic skin, its working part left)"
    else:
        whole = sum(_volume(info) for _n, _p, info in laid_at_two)
        chosen, so_far = set(), 0.0
        for n, _p, info in sorted(laid_at_two, key=lambda row: (_volume(row[2]), row[0])):
            if so_far + _volume(info) > whole / 2:
                break               # a set of one big SNOT part keeps it for rung 2
            chosen.add(n)
            so_far += _volume(info)
        said = "half the SNOT out (its smaller parts, half its volume)"
    return snot_out(rung, parts, keep_rolling=True, only=chosen, said=said)


_PROFILES: dict[str, list[tuple[float, float, int, float]] | None] = {}
_LIBRARY = None
_PLOCK = threading.Lock()


def profile(part: str) -> list[tuple[float, float, int, float]] | None:
    """A part as columns a stud across: (x, z, plates high, bottom y), in its own axes.

    Each column is as high as the part's own top over it, read from the part's
    triangles sampled every 4 LDU; studs, 4 LDU, are under the rounding.
    """
    global _LIBRARY
    with _PLOCK:
        if part in _PROFILES:
            return _PROFILES[part]
        from ldraw.geometry import flatten
        from ldraw.library import Detail, Library
        if _LIBRARY is None:
            _LIBRARY = Library(style.LDRAW)
        try:
            mesh = flatten(_LIBRARY, part + ".dat", detail=Detail.LOW)
        except Exception:       # a part the library cannot read: laid by its box
            mesh = None
        if mesh is None or not mesh.triangles:
            _PROFILES[part] = None
            return None
        lo, hi = mesh.bounds()
        across = max(1, round((hi.x - lo.x) / STUD))
        deep = max(1, round((hi.z - lo.z) / STUD))
        wx, wz = (hi.x - lo.x) / across, (hi.z - lo.z) / deep
        top: dict[tuple[int, int], float] = {}
        for t in mesh.triangles:
            edge = max((t.b - t.a).length(), (t.c - t.b).length(), (t.a - t.c).length())
            n = max(1, math.ceil(edge / 4.0))
            for u in range(n + 1):
                for v in range(n + 1 - u):
                    s, r = u / n, v / n
                    px = t.a.x + s * (t.b.x - t.a.x) + r * (t.c.x - t.a.x)
                    py = t.a.y + s * (t.b.y - t.a.y) + r * (t.c.y - t.a.y)
                    pz = t.a.z + s * (t.b.z - t.a.z) + r * (t.c.z - t.a.z)
                    key = (min(across - 1, max(0, int((px - lo.x) // wx))),
                           min(deep - 1, max(0, int((pz - lo.z) // wz))))
                    if py < top.get(key, math.inf):
                        top[key] = py
        columns = []
        for (ci, ck), y in sorted(top.items()):
            plates = math.floor((hi.y - y + 3.0) / PLATE)
            if plates > 0:
                columns.append((lo.x + (ci + 0.5) * wx, lo.z + (ck + 0.5) * wz, plates, hi.y))
        _PROFILES[part] = columns or None
        return _PROFILES[part]


def curves_stepped(rung: Rung, parts: style.Parts) -> Rung:
    """Rung 3: every curve laid as plain plates in columns as high as its top."""
    out, gone = [], []
    for p, info in rung.kept:
        if (info is not None and info.oriented and style.building(info)
                and "curve" in style.kinds(info)):
            gone.append((p, info))
        else:
            out.append((p, info))
    made = Rung(out, dict(rung.cells), rung.origin, rung.fix, rung.embedded, list(rung.said))
    votes: dict = {}
    boxed = []
    for p, info in gone:
        columns = profile(parts.canonical(p.part))
        if columns is None:
            if info is not None and info.box is not None:
                boxed.append((p, info))
            continue
        m = p.matrix
        for x, z, plates, bottom in columns:
            for level in range(plates):
                y = bottom - (level + 0.5) * PLATE
                wx = m.a * x + m.b * y + m.c * z + m.x
                wy = m.d * x + m.e * y + m.f * z + m.y
                wz = m.g * x + m.h * y + m.i * z + m.z
                votes.setdefault(_cell_of(made, wx, wy, wz), Counter())[p.colour] += 1
    cover: dict = {}
    boxed_votes: dict = {}
    _cover(made, style._boxes(boxed, parts), cover, boxed_votes)
    for cell, count in boxed_votes.items():
        if cover[cell] >= FILL:
            votes.setdefault(cell, Counter()).update(count)
    laid = _lay(made, votes, parts)
    made.said.append(f"curves stepped: {len(gone)} curved parts laid as {laid} plate cells")
    return made


def _transparent(code: int, palette: dict[int, dict]) -> bool:
    return calibrate._transparent(code, palette)


def colours_flattened(rung: Rung, parts: style.Parts, palette: dict[int, dict]) -> Rung:
    """Rung 4: every solid colour the nearest of the three the model has most of."""
    weight: defaultdict[int, float] = defaultdict(float)
    for b in style._boxes([(p, i) for p, i in rung.kept if i is not None and i.box], parts):
        if b.colour != 16 and not _transparent(b.colour, palette):
            weight[b.colour] += 8 * b.half[0] * b.half[1] * b.half[2]
    for colour in rung.cells.values():
        if not _transparent(colour, palette):
            weight[colour] += STUD * PLATE * STUD
    main = sorted(weight, key=lambda c: weight[c], reverse=True)[:COLOURS_KEPT]

    def rgb(code: int) -> tuple[int, ...]:
        return tuple(palette.get(code, {}).get("rgb", (128, 128, 128)))

    def nearest(code: int) -> int:
        if not main or code in main or code == 16 or _transparent(code, palette):
            return code
        r = rgb(code)
        return min(main, key=lambda c: sum((a - b) ** 2 for a, b in zip(rgb(c), r)))

    kept = [(style.Placed(p.part, nearest(p.colour), p.matrix), info) for p, info in rung.kept]
    changed = sum(1 for (p, _i), (q, _j) in zip(rung.kept, kept) if p.colour != q.colour)
    made = Rung(kept, {c: nearest(v) for c, v in rung.cells.items()}, rung.origin, rung.fix,
                rung.embedded, list(rung.said))
    made.said.append(f"colours flattened to {', '.join(map(str, main))}: {changed} parts "
                     "recoloured")
    return made


def _number(v: float) -> str:
    text = f"{v:.4f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def _line(colour: int, m: Matrix, part: str) -> str:
    values = (m.x, m.y, m.z, m.a, m.b, m.c, m.d, m.e, m.f, m.g, m.h, m.i)
    return f"1 {colour} " + " ".join(_number(v) for v in values) + f" {part}.dat"


def plates(rung: Rung) -> list[str]:
    """The rung's cells laid course by course in the largest plain plates of one colour."""
    x0, bottom, z0 = rung.origin
    lines = []
    for j in sorted({c[1] for c in rung.cells}):
        course = {(i, k): colour for (i, jj, k), colour in rung.cells.items() if jj == j}
        for (i, k) in sorted(course):
            if (i, k) not in course:
                continue
            colour = course[(i, k)]
            for along_x, along_z, part in PLATES:
                block = [(i + a, k + c) for a in range(along_x) for c in range(along_z)]
                if all(course.get(cell) == colour for cell in block):
                    for cell in block:
                        del course[cell]
                    at = Matrix(x=x0 + (i + along_x / 2) * STUD, y=bottom - (j + 1) * PLATE,
                                z=z0 + (k + along_z / 2) * STUD)
                    turn = TURNED if along_z > along_x else Matrix()
                    placed = rung.fix @ (at @ turn)
                    lines.append(_line(colour, placed, part))
                    break
    return lines


def write(rung: Rung, title: str) -> str:
    """The rung as an LDraw file: kept parts where they were, cells as plates."""
    lines = [f"0 FILE ladder.ldr", f"0 {title}", "0 Name: ladder.ldr",
             "0 Author: Brickworks design ladder", *[f"0 {s}" for s in rung.said], ""]
    for p, _info in rung.kept:
        # Back in the file's own frame, where they were written.
        lines.append(_line(p.colour, p.matrix if _identity(rung.fix) else rung.fix @ p.matrix,
                           p.part))
    lines += plates(rung)
    lines.append("0 NOFILE")
    for name, body in rung.embedded.items():
        lines += [f"0 FILE {name}", body, "0 NOFILE"]
    return "\n".join(lines) + "\n"


def _identity(m: Matrix) -> bool:
    return all(abs(a - b) < 1e-9 for a, b in zip(
        (m.a, m.b, m.c, m.d, m.e, m.f, m.g, m.h, m.i), (1, 0, 0, 0, 1, 0, 0, 0, 1)))


def ladder(text: str, parts: style.Parts, palette: dict[int, dict],
           technic: bool = False) -> dict[float, tuple[str, str]]:
    """Rungs 1.5 to 5 of a set's file: each rung's LDraw text and a line saying what was done.

    Each rung is never better than the one above it: 1.5 lays half of what 2
    lays; 2 lays every part off studs up but what rolls; 3 is the SNOT out with
    the wheels too, and its curves stepped; 4 is 3 with its colours flattened."""
    first = start(text, parts)
    half = half_out(first, parts, technic)
    second = snot_out(first, parts, keep_rolling=True)
    third = curves_stepped(snot_out(first, parts), parts)
    fourth = colours_flattened(third, parts, palette)
    naive, said = calibrate.naive_stack(text, parts, palette)
    return {1.5: (write(half, RUNGS[1.5]), half.said[-1]),
            2: (write(second, RUNGS[2]), second.said[-1]),
            3: (write(third, RUNGS[3]), third.said[-1]),
            4: (write(fourth, RUNGS[4]), fourth.said[-1]),
            5: (naive, f"naive stack: {said}")}


def label(rung: float) -> str:
    """A rung's name in its files and keys: 1, 1.5, 2."""
    return f"{rung:g}"


def is_technic(theme: str) -> bool:
    return theme.split(">")[0].strip().lower() == "technic"


# -- the sets ---------------------------------------------------------------------


def wanted(which: str, subjects: str = "") -> list[realset.Candidate]:
    found = realset.sample(which)
    if subjects:
        keep = {s.strip() for s in subjects.split(",") if s.strip()}
        found = [c for c in found if c.number in keep]
    return found


def subjects_of(arm: str, date: str) -> list[str]:
    where = realset.arm_dir(date, arm)
    return sorted(p.name for p in where.iterdir() if (p / "record.json").exists())


def _guard() -> None:
    """Godot never imports the ladder, and git never takes it."""
    LADDER.mkdir(parents=True, exist_ok=True)
    (LADDER / ".gdignore").touch()
    (LADDER / "README").write_text(
        "The design ladder (tools/design_ladder.py): rungs made from held-out real sets' own "
        "files. An answer key: never put within a design session's reach.\n")


def _parts_of(text: str) -> list[str]:
    """A rung file's part lines: what it draws, whatever its comments say."""
    return [line for line in text.splitlines() if line.strip() and not line.lstrip().startswith("0")]


def build(args: argparse.Namespace) -> int:
    """Each set's rungs written. A rung whose parts changed gets a new version: its
    pictures move to the results' superseded/ to be drawn again, and its key changes,
    so no verdict on the old one is read back for it."""
    _guard()
    parts, palette = style.Parts(), calibrate.palette()
    for c in wanted(args.which, args.subjects):
        where = LADDER / c.number
        where.mkdir(parents=True, exist_ok=True)
        text = (realset.FILES / c.file).read_text(errors="replace")
        made = ladder(text, parts, palette, is_technic(c.theme))
        before = (json.loads((where / "ladder.json").read_text())
                  if (where / "ladder.json").exists() else {})
        versions = dict(before.get("versions", {}))
        record = {"number": c.number, "name": c.name, "theme": c.theme, "which": args.which,
                  "rungs": {"1": RUNGS[1]}, "versions": versions}
        (where / "r1.mpd").write_text(text)
        changed = []
        for k, (body, said) in made.items():
            name, target = label(k), where / f"r{label(k)}.mpd"
            if target.exists() and _parts_of(target.read_text(errors="replace")) != _parts_of(body):
                old = int(versions.get(name, 1))
                versions[name] = old + 1
                gone = Path(args.out) / "superseded" / c.number
                gone.mkdir(parents=True, exist_ok=True)
                for path in where.glob(f"r{name}[._]*"):
                    shutil.move(str(path), gone / f"{path.name.replace(f'r{name}', f'r{name}v{old}', 1)}")
                changed.append(name)
            target.write_text(body)
            record["rungs"][name] = said
        bench._write_json(where / "ladder.json", record)
        _VERSIONS.pop(c.number, None)
        print(c.number, c.name, "|", " | ".join(s for _b, s in made.values()),
              f"| changed: {', '.join(changed) or 'none'}", flush=True)
    return 0


_VERSIONS: dict[str, dict[str, int]] = {}


def version(number: str, rung: float) -> int:
    """A rung's version: 1 as first built, one more each time its parts changed."""
    if number not in _VERSIONS:
        made = LADDER / number / "ladder.json"
        _VERSIONS[number] = (json.loads(made.read_text()).get("versions", {})
                             if made.exists() else {})
    return int(_VERSIONS[number].get(label(rung), 1))


def key_of(number: str, rung: float) -> str:
    """The rung's name to the judge's ledger: a new version is a new key."""
    v = version(number, rung)
    return f"ladder:{number}:r{label(rung)}" + (f":v{v}" if v > 1 else "")


def rung_of(key: str) -> float:
    return float(key.split(":")[2][1:])


def views(number: str, rung: float) -> list[Path]:
    return [LADDER / number / f"r{label(rung)}_{v}.png" for v in realset.VIEWS]


def set_pictures(number: str) -> list[Path]:
    """Rung 1's pictures: the set as realset drew it, the very pictures a run's judge sees."""
    return [realset.SETS_DIR / number / f"set_{v}.png" for v in realset.VIEWS]


def render(args: argparse.Namespace) -> int:
    # The app's own data folder, as realset's runs give it one: the shared default
    # holds hundreds of custom parts, and pre261's start never ends on them.
    os.environ.setdefault("XDG_DATA_HOME", str(OUT / "render-data"))
    Path(os.environ["XDG_DATA_HOME"]).mkdir(parents=True, exist_ok=True)
    jobs = []
    for c in wanted(args.which, args.subjects):
        if all(p.exists() for p in set_pictures(c.number)):
            for got, kept in zip(set_pictures(c.number), views(c.number, 1)):
                if not kept.exists():
                    shutil.copyfile(got, kept)
        for k in RUNGS:
            model = LADDER / c.number / f"r{label(k)}.mpd"
            if model.exists() and not all(p.exists() for p in views(c.number, k)):
                jobs.append((model, LADDER / c.number / f"r{label(k)}",
                             LADDER / c.number / f"r{label(k)}_render.log"))

    def one(job) -> str:
        model, prefix, log = job
        got = bench.render(model, prefix, log)
        return f"{prefix.parent.name} {prefix.name}: {len(got)} views"

    # The best rungs last: a design is placed from rung 3 down, and fewer climb to them.
    jobs.sort(key=lambda job: job[1].name in ("r1.5", "r2"))
    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as workers:
        for said in workers.map(one, jobs):
            print(said, flush=True)
    return 0


# -- the judge, counted -------------------------------------------------------------

_CALLS = threading.Lock()


def _count_calls(out: Path, cap: int) -> None:
    """judge.call, counted into out/calls.jsonl, refused past the cap."""
    real = judge.call
    ledger = out / "calls.jsonl"
    out.mkdir(parents=True, exist_ok=True)

    def counted(text, cwd, readable, model="opus", timeout=900, schema=None):
        with _CALLS:
            made = sum(1 for _ in ledger.open()) if ledger.exists() else 0
            if made >= cap:
                raise RuntimeError(f"the judge's cap of {cap} calls is reached")
            with ledger.open("a") as f:
                f.write(json.dumps({"at": time.time(), "cwd": str(cwd)}) + "\n")
        return real(text, cwd, readable, model=model, timeout=timeout, schema=schema)

    judge.call = counted


def calls_made(out: Path = OUT) -> int:
    ledger = out / "calls.jsonl"
    return sum(1 for _ in ledger.open()) if ledger.exists() else 0


def _brief(number: str, c: realset.Candidate | None = None) -> str:
    record = json.loads((realset.SETS_DIR / number / "set.json").read_text())
    if c is None:
        c = next(x for h in realset.HALVES for x in realset.sample(h) if x.number == number)
    return realset.brief(c, tuple(record["plan"]))


def rung_side(number: str, rung: float) -> tuple[str, tuple]:
    key = key_of(number, rung)
    return key, realset.shown(key, views(number, rung), number)


def order(args: argparse.Namespace) -> int:
    """Adjacent rungs, both orders, and the set against its naive stack."""
    out = Path(args.out)
    _count_calls(out, args.cap)
    pairs = PAIRS
    tasks = []
    for c in wanted(args.which, args.subjects):
        if not all(all(p.exists() for p in views(c.number, k)) for k in RUNGS):
            print(f"{c.number}: not every rung drawn, left out", flush=True)
            continue
        text = _brief(c.number, c)
        for hi, lo in pairs:
            tasks.append((c.number, text, hi, lo))

    def judged(task):
        number, text, hi, lo = task
        found = realset.both_orders(text, number, rung_side(number, hi), rung_side(number, lo),
                                    out / "order" / number, args.judge_model)
        return number, hi, lo, len(found)

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as workers:
        for number, hi, lo, n in workers.map(judged, tasks):
            print(f"{number} r{hi} v r{lo}: {n} verdicts ({calls_made(out)} calls)", flush=True)
    return 0


def _verdicts(where: Path) -> list[pairwise.Verdict]:
    return [pairwise.Verdict.from_dict(json.loads(p.read_text()))
            for p in sorted(where.glob("*-*.json"))]


def _share(found: list[pairwise.Verdict], key: str, dim: str = "overall") -> float | None:
    return sum(v.winners[dim] == key for v in found) / len(found) if found else None


def place_one(record: dict, arm_folder: Path, number: str, into: Path, model: str,
              fresh: bool = False) -> dict:
    """A design's place on its set's ladder, judged up or down from rung 3. Rung 1's
    verdicts are the run's own (its record), or judged afresh when fresh: the second
    judging of a design then shares no verdict with the first."""
    ours = record["keys"]["ours"]
    pictures = [arm_folder / number / f"views_{v}.png" for v in realset.VIEWS]
    if not all(p.exists() for p in pictures):
        return {"number": number, "place": None, "asked": {}}
    side = (ours, realset.shown(ours, pictures, number))
    asked: dict[float, float] = {}

    def vs(rung: int) -> float | None:
        if rung == 1 and not fresh:
            said = record.get("verdicts") or []
            if said:
                asked[1] = sum(v["winners"]["overall"] == ours for v in said) / len(said)
                return asked[1]
        if not all(p.exists() for p in views(number, rung)):
            return None                     # not drawn yet: placed on a later pass
        found = realset.both_orders(record["brief"], number, side, rung_side(number, rung),
                                    into, model)
        share = _share(found, ours)
        if share is not None:
            asked[rung] = share
        return share

    place = walk(vs)
    return {"number": number, "place": place, "asked": asked}


def walk(vs, rungs: tuple[float, ...] = ORDER, first: float = 3) -> float | None:
    """The place from shares won against rungs: from rung 3 up while it wins both, down
    while it loses both; a split is the rung's own place, else halfway between two
    (between 1.5 and 2 is 1.75); above the set is 0.5, below the stack 5.5."""
    at = rungs.index(first)
    s = vs(rungs[at])
    if s is None:
        return None
    if 0 < s < 1:
        return float(rungs[at])
    step = -1 if s == 1 else 1
    while True:
        nxt = at + step
        if nxt < 0 or nxt >= len(rungs):
            return rungs[at] + step * 0.5
        s = vs(rungs[nxt])
        if s is None:
            return None
        if 0 < s < 1:
            return float(rungs[nxt])
        if (s == 1) != (step == -1):        # turned: it sits between the two
            return (rungs[at] + rungs[nxt]) / 2
        at = nxt


def place(args: argparse.Namespace) -> int:
    out = Path(args.out)
    _count_calls(out, args.cap)
    folder = realset.arm_dir(args.date, args.arm)
    numbers = subjects_of(args.arm, args.date)
    if args.subjects:
        keep = {s.strip() for s in args.subjects.split(",")}
        numbers = [n for n in numbers if n in keep]
    kind = "place2" if args.again else "place"

    def one(number: str) -> dict:
        record = json.loads((folder / number / "record.json").read_text())
        if not record.get("keys") or not (LADDER / number / "r1.mpd").exists():
            return {"number": number, "place": None, "asked": {}, "why": "no design or ladder"}
        return place_one(record, folder, number, out / kind / args.arm / number,
                         args.judge_model, fresh=args.again)

    with ThreadPoolExecutor(max_workers=max(1, args.jobs)) as workers:
        found = list(workers.map(one, numbers))
    bench._write_json(out / f"{kind}-{args.arm}.json", found)
    for row in found:
        print(row["number"], row["place"], row["asked"], flush=True)
    print(f"{calls_made(out)} judge calls made in all", flush=True)
    return 0


def seed(args: argparse.Namespace) -> int:
    """An earlier ladder's verdicts copied in, so only what changed is asked again: a
    verdict is read back by its two keys, and a remade rung has a new key."""
    before, out = Path(args.before), Path(args.out)
    copied = 0
    for kind in ("order", "place", "place2"):
        for path in (before / kind).rglob("*-*.json") if (before / kind).exists() else ():
            target = out / path.relative_to(before)
            if not target.exists():
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(path, target)
                copied += 1
    print(f"{copied} verdicts copied from {before} into {out}")
    return 0


# -- what the verdicts say ------------------------------------------------------------


def wilson(wins: float, n: int) -> tuple[float, float, float]:
    if not n:
        return float("nan"), float("nan"), float("nan")
    p, z = wins / n, 1.96
    centre = (p + z * z / (2 * n)) / (1 + z * z / n)
    half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / (1 + z * z / n)
    return p, max(0.0, centre - half), min(1.0, centre + half)


def order_table(out: Path, numbers: list[str]) -> dict:
    """Per pair of rungs and dimension: verdicts, right, and right with the better shown first."""
    table: dict = {}
    reasons: dict = defaultdict(list)
    for number in numbers:
        for found in _verdicts(out / "order" / number):
            hi_key, lo_key = sorted((found.first, found.second), key=rung_of)
            hi, lo = rung_of(hi_key), rung_of(lo_key)
            if key_of(number, hi) != hi_key or key_of(number, lo) != lo_key:
                continue                # a verdict on a rung since remade
            first_better = found.first == hi_key
            for dim in realset.DIMS:
                row = table.setdefault((hi, lo, dim), {"n": 0, "right": 0, "n_first": 0,
                                                       "right_first": 0, "subjects": set()})
                right = found.winners[dim] == hi_key
                row["n"] += 1
                row["right"] += right
                row["n_first"] += first_better
                row["right_first"] += right and first_better
                row["subjects"].add(number)
                if dim == "overall" and not right:
                    reasons[(hi, lo)].append((number, found.reasons.get("overall", "")))
    return {"table": table, "wrong": reasons}


# The proof half's Technic sets: studless beams, which rung 2 lays as solid plates.
TECHNIC = {"42033-1", "42060-1", "42062-1", "42063-1", "42072-1", "42075-1", "42081-1",
           "42093-1", "42111-1"}


def technic(number: str) -> bool:
    """A Technic set, by the theme its ladder was built with (the tune half's too)."""
    made = LADDER / number / "ladder.json"
    if made.exists():
        return is_technic(json.loads(made.read_text()).get("theme", ""))
    return number in TECHNIC


SEEN = 0.005        # a step under half a percent of a picture's pixels is no step to see


def step_seen(number: str, hi: float, lo: float) -> float:
    """The share of pixels two rungs' pictures differ in, the most of the three views:
    a rung that took nothing away from a set (no curves to step) shows the same picture."""
    from PIL import Image, ImageChops
    most = 0.0
    for a, b in zip(views(number, hi), views(number, lo)):
        if not (a.exists() and b.exists()):
            return float("nan")
        x, y = Image.open(a).convert("RGB"), Image.open(b).convert("RGB")
        if x.size != y.size:
            y = y.resize(x.size)
        changed = ImageChops.difference(x, y).convert("L").point(lambda v: 255 if v > 24 else 0)
        most = max(most, changed.histogram()[255] / (x.size[0] * x.size[1]))
    return most


def agreement(out: Path, numbers: list[str], hi: float, lo: float) -> dict[str, int]:
    """Per set, how many of the pair's two orders put the higher rung first (overall)."""
    got: dict[str, int] = {}
    for number in numbers:
        found = [v for v in _verdicts(out / "order" / number)
                 if {v.first, v.second} == {key_of(number, hi), key_of(number, lo)}]
        if len(found) == 2:
            got[number] = sum(v.winners["overall"] == key_of(number, hi) for v in found)
    return got


def seen_rows(out: Path, numbers: list[str], name: str) -> list[str]:
    """The bar's own table: each pair of rungs, both orders, over the sets whose two
    pictures differ (a step to see), with how many sets showed the same picture twice."""
    rows = [f"Pairs whose pictures differ, {name} ({len(numbers)}):", "",
            "| rungs | verdicts | right (95%) | better shown first | better shown second "
            "| sets with the same picture |", "|---|---|---|---|---|---|"]
    for hi, lo in PAIRS:
        got = agreement(out, numbers, hi, lo)
        seen = [n for n in got if step_seen(n, hi, lo) >= SEEN]
        row = order_table(out, seen)["table"].get((hi, lo, "overall"))
        if not row:
            rows.append(f"| {hi} over {lo} | 0 | | | | {len(got)} |")
            continue
        p, low, high = wilson(row["right"], row["n"])
        n_second = row["n"] - row["n_first"]
        first = 100 * row["right_first"] / row["n_first"] if row["n_first"] else float("nan")
        second = 100 * (row["right"] - row["right_first"]) / n_second if n_second else float("nan")
        rows.append(f"| {hi} over {lo} | {row['n']} | {100 * p:.0f}% ({100 * low:.0f}-"
                    f"{100 * high:.0f}) | {first:.0f}% | {second:.0f}% | {len(got) - len(seen)} |")
    return rows


def report(args: argparse.Namespace) -> int:
    out = Path(args.out)
    numbers = sorted(p.name for p in (out / "order").iterdir()) if (out / "order").exists() else []
    read = order_table(out, numbers)
    lines = [f"# The design ladder: what the judge orders ({len(numbers)} sets, "
             f"{calls_made(out)} judge calls)", ""]
    lines += ["| rungs | verdicts | overall right (95%) | better shown first | better shown second "
              "| likeness | surface | colour | technique | creativity |", "|---|---|---|---|---|---|---|---|---|---|"]
    for hi, lo in PAIRS:
        row = read["table"].get((hi, lo, "overall"))
        if not row:
            continue
        p, low, high = wilson(row["right"], row["n"])
        first = row["right_first"] / row["n_first"] if row["n_first"] else float("nan")
        n_second = row["n"] - row["n_first"]
        second = ((row["right"] - row["right_first"]) / n_second) if n_second else float("nan")
        dims = []
        for dim in ("likeness", "surface", "colour", "technique", "creativity"):
            d = read["table"][(hi, lo, dim)]
            dims.append(f"{100 * d['right'] / d['n']:.0f}%")
        lines.append(f"| {hi} over {lo} | {row['n']} | {100 * p:.0f}% ({100 * low:.0f}-"
                     f"{100 * high:.0f}) | {100 * first:.0f}% | {100 * second:.0f}% | "
                     + " | ".join(dims) + " |")
    adjacent = [read["table"][(h, lo, "overall")] for h, lo in ADJACENT
                if (h, lo, "overall") in read["table"]]
    if adjacent:
        n = sum(r["n"] for r in adjacent)
        right = sum(r["right"] for r in adjacent)
        p, low, high = wilson(right, n)
        lines += ["", f"Adjacent rungs in all: {right} of {n} right, {100 * p:.0f}% "
                      f"({100 * low:.0f}-{100 * high:.0f})."]
        # Only the pairs whose pictures differ: a rung that took nothing from its set
        # (no curves left to step) is the same picture twice, and no judge can order it.
        seen_n = seen_right = 0
        unseen = []
        for h, lo in ADJACENT:
            for number, both in agreement(out, numbers, h, lo).items():
                share = step_seen(number, h, lo)
                if share >= SEEN:
                    seen_n, seen_right = seen_n + 2, seen_right + both
                else:
                    unseen.append(f"{number} r{label(h)}-r{label(lo)} ({100 * share:.2f}% of pixels, "
                                  f"{both} of 2 right)")
        if seen_n:
            p, low, high = wilson(seen_right, seen_n)
            lines += ["", f"Adjacent rungs whose pictures differ (at least {100 * SEEN:.1f}% of a "
                          f"view's pixels): {seen_right} of {seen_n} right, {100 * p:.0f}% "
                          f"({100 * low:.0f}-{100 * high:.0f}). Left out as no step to see: "
                          f"{len(unseen)} pairs" + (": " + "; ".join(unseen) if unseen else "") + "."]
        technic_sets = [n for n in numbers if technic(n)]
        for name, group in (("every set", numbers), ("Technic sets", technic_sets),
                            ("the rest", [n for n in numbers if not technic(n)])):
            if group:
                lines += ["", *seen_rows(out, group, name)]
    lines += ["", "## Where it was wrong, in its words (overall)", ""]
    for (hi, lo), rows in sorted(read["wrong"].items()):
        lines.append(f"### Rung {lo:g} preferred to rung {hi:g}: {len(rows)}")
        for number, reason in rows:
            lines.append(f"- {number}: {reason}")
        lines.append("")
    lines += ["## Each pair of a set, both orders together (overall)", "",
              "| rungs | both right | one right (the order decided) | both wrong |",
              "|---|---|---|---|"]
    for hi, lo in PAIRS:
        tally = Counter(agreement(out, numbers, hi, lo).values())
        lines.append(f"| {hi} over {lo} | {tally[2]} | {tally[1]} | {tally[0]} |")
    technic_sets = [n for n in numbers if technic(n)]
    if technic_sets:
        lines += ["", f"Technic sets apart ({len(technic_sets)}: their sideways beams fill solid at "
                      "rung 2):"]
        for name, group in (("Technic", technic_sets),
                            ("the rest", [n for n in numbers if n not in technic_sets])):
            t = order_table(out, group)["table"]
            rows = [t[(h, lo, "overall")] for h, lo in ADJACENT if (h, lo, "overall") in t]
            n, right = sum(r["n"] for r in rows), sum(r["right"] for r in rows)
            if n:
                p, low, high = wilson(right, n)
                lines.append(f"- {name}: adjacent rungs {right} of {n} right, {100 * p:.0f}% "
                             f"({100 * low:.0f}-{100 * high:.0f})")
    lines += ["", "## Designs placed", "",
              "A place is a rung (it split its verdicts with that rung) or halfway between two "
              "(it beat the lower, lost to the higher). 1 is the set, 1.5 half its SNOT out, 2 "
              "the rest of it out but the wheels, 5 its naive stack; 0.5 is above the set, 5.5 "
              "below the stack. Smaller is better.", ""]
    placed_by: dict[str, dict[str, float]] = {}
    for kind in ("place", "place2"):
        for path in sorted(out.glob(f"{kind}-*.json")):
            rows = json.loads(path.read_text())
            placed_by[path.stem] = {r["number"]: r["place"] for r in rows if r["place"] is not None}
            placed = list(placed_by[path.stem].values())
            if placed:
                lines.append(f"- {path.stem}: {len(placed)} designs, mean place "
                             f"{sum(placed) / len(placed):.2f}; "
                             + ", ".join(f"{k:g}: {placed.count(k)}"
                                         for k in sorted(set(placed))))
    lines.append("")
    for base, lever in (("place-d24p44base", "place-d24p44lev"), ("place-d25base", "place-d25lev")):
        a, b = placed_by.get(base, {}), placed_by.get(lever, {})
        both = sorted(set(a) & set(b))
        if both:
            # base minus lever: positive is the lever's designs higher on the ladder
            gap, low, high = realset.paired_gap([a[n] for n in both], [b[n] for n in both])
            up = sum(b[n] < a[n] for n in both)
            down = sum(b[n] > a[n] for n in both)
            lines.append(f"- {lever.split('-', 1)[1]} against {base.split('-', 1)[1]}, "
                         f"{len(both)} subjects paired: the lever moved designs {gap:+.2f} rungs "
                         f"up (95% {low:+.2f} to {high:+.2f}); {up} up, {down} down, "
                         f"{len(both) - up - down} level")
    once, twice = placed_by.get("place-d24p44base", {}), placed_by.get("place2-d24p44base", {})
    again = sorted(set(once) & set(twice))
    if again:
        near = sum(abs(once[n] - twice[n]) <= 1 for n in again)
        same = sum(once[n] == twice[n] for n in again)
        p, low, high = wilson(near, len(again))
        lines.append(f"- One design judged twice (design24's base, {len(again)} designs): within one "
                     f"rung {near} of {len(again)}, {100 * p:.0f}% ({100 * low:.0f}-{100 * high:.0f}); "
                     f"the same place {same}")
    if args.before:
        lines += ["", f"### Where the designs that sat between the set and rung 2 went "
                      f"(before: {args.before})", "",
                  "| arm | between 1 and 2 before | now 0.5 to 1 | 1.25 | 1.5 | 1.75 | 2 | below 2 "
                  "| of them Technic: 1 or above / 1.25 to 1.75 / 2 or below |",
                  "|---|---|---|---|---|---|---|---|---|"]
        for stem, now in sorted(placed_by.items()):
            old_path = Path(args.before) / f"{stem}.json"
            if not old_path.exists():
                continue
            old = {r["number"]: r["place"] for r in json.loads(old_path.read_text())}
            sat = [n for n, v in old.items() if v == 1.5 and n in now]
            went = [now[n] for n in sat]
            tech = [now[n] for n in sat if technic(n)]
            lines.append(
                f"| {stem} | {len(sat)} | {sum(v <= 1 for v in went)} | {went.count(1.25)} | "
                f"{went.count(1.5)} | {went.count(1.75)} | {went.count(2)} | "
                f"{sum(v > 2 for v in went)} | {sum(v <= 1 for v in tech)} / "
                f"{sum(1 < v < 2 for v in tech)} / {sum(v >= 2 for v in tech)} of {len(tech)} |")
    text = "\n".join(lines) + "\n"
    (out / "ladder_report.md").write_text(text)
    print(text)
    return 0


# -- a contact sheet ------------------------------------------------------------------


def sheet(args: argparse.Namespace) -> int:
    from PIL import Image, ImageDraw
    numbers = ([s.strip() for s in args.subjects.split(",") if s.strip()] if args.subjects
               else sorted(p.name for p in LADDER.iterdir() if (p / "ladder.json").exists()))
    size = args.size
    view = args.view
    rows = [n for n in numbers
            if all((LADDER / n / f"r{label(k)}_{view}.png").exists() for k in RUNGS)]
    canvas = Image.new("RGB", (size * len(ORDER), (size + 18) * len(rows)), 0xFFFFFF)
    draw = ImageDraw.Draw(canvas)
    for r, number in enumerate(rows):
        for column, k in enumerate(ORDER):
            pic = Image.open(LADDER / number / f"r{label(k)}_{view}.png").convert("RGB")
            pic.thumbnail((size, size))
            canvas.paste(pic, (column * size, r * (size + 18) + 18))
            draw.text((column * size + 4, r * (size + 18) + 3), f"{number} rung {label(k)}",
                      fill="black")
    target = Path(args.into)
    target.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(target)
    print(target)
    return 0


# -- the leak audit --------------------------------------------------------------------

SEARCH = ("find_reference", "gallery", "how_real_sets_build_this", "search_parts",
          "find_techniques", "find_parts_like", "plan_scale", "parts_list")
LADDER_SAID = re.compile(r"bench/ladder|design.ladder|ladder\.(ldr|mpd)|\br[1-5](\.5)?_(corner|front|close)"
                         r"\.png|\br[1-5](\.5)?\.mpd", re.I)


def _texts(content) -> str:
    if isinstance(content, str):
        return content
    return "\n".join(c.get("text", "") for c in content or []
                     if isinstance(c, dict) and c.get("type") == "text")


def leak_hits(session: Path, number: str, title: str) -> list[str]:
    """design24's audit of one design's transcript, with the ladder added: a call naming
    the set in a search, and an answer naming its own file or number, or the ladder."""
    own = re.compile(rf"(?<![\d.])(?<!relay-)({re.escape(number)}-1(?:\.mpd)?|omr-"
                     rf"{re.escape(number)})(?!\d)", re.I)
    bare = re.compile(rf"(?<![\d.]){re.escape(number)}(?![\d.])")
    hits, names = [], {}
    for line in session.read_text(errors="replace").splitlines():
        try:
            e = json.loads(line)
        except ValueError:
            continue
        msg = e.get("message") or {}
        if e.get("type") == "assistant":
            for c in msg.get("content", []) if isinstance(msg.get("content"), list) else []:
                if c.get("type") != "tool_use":
                    continue
                name = c["name"].split("__")[-1]
                names[c["id"]] = name
                text = json.dumps(c.get("input", {}), ensure_ascii=False)
                if bare.search(text) and name in SEARCH:
                    hits.append(f"call {name}: number in {text[:140]}")
                if title and title.lower() in text.lower() and name in SEARCH[:3]:
                    hits.append(f"call {name}: title in {text[:140]}")
                if LADDER_SAID.search(text):
                    hits.append(f"call {name}: the ladder in {text[:140]}")
        elif e.get("type") == "user" and isinstance(msg.get("content"), list):
            for c in msg["content"]:
                if not isinstance(c, dict) or c.get("type") != "tool_result":
                    continue
                text = _texts(c.get("content"))
                for rule, what in ((own, "its own file or number"), (LADDER_SAID, "the ladder")):
                    m = rule.search(text)
                    if m:
                        at = m.start()
                        hits.append(f"answer of {names.get(c.get('tool_use_id'), '?')}: {what}: "
                                    f"{text[max(0, at - 80):at + 60]!r}")
    return hits


def leaks(args: argparse.Namespace) -> int:
    bad = 0
    for arm in map(Path, args.arms):
        print(f"=== {arm.name}")
        for sub in sorted(p for p in arm.iterdir() if p.is_dir()):
            session = sub / "session.jsonl"
            if not session.exists():
                continue
            rec = json.loads((sub / "record.json").read_text()) if (sub / "record.json").exists() else {}
            hits = leak_hits(session, sub.name.split("-")[0], rec.get("name", ""))
            bad += sum(1 for h in hits if h.startswith("answer of"))
            print(f"{sub.name} {rec.get('name', '')}: held_out_said={rec.get('held_out_said')}; "
                  f"hits {len(hits)}")
            for h in hits:
                print("   ", h[:260])
    print("LEAK HITS (the set's own file or number, or the ladder, in an answer)", bad)
    return 1 if bad else 0


# -- can a session reach the ladder? --------------------------------------------------


def reach(args: argparse.Namespace) -> int:
    """Start the app as realset starts a design's, and ask each tool that opens a file
    for a ladder file; none may open it or name it."""
    number = args.subject
    c = next(x for h in realset.HALVES for x in realset.sample(h) if x.number == number)
    target = LADDER / number / "r2.mpd"
    if not target.exists():
        raise SystemExit(f"no ladder for {number}: build it first")
    home = Path(args.home)
    home.mkdir(parents=True, exist_ok=True)
    log = home / "reach_godot.log"
    env = bench._billing_free_env(XDG_DATA_HOME=str(home))
    app = subprocess.Popen(
        ["timeout", "600", "godot", "--headless", "--path", str(ROOT), "--log-file", str(log),
         "--", f"--mcp={args.port}", "--assistant=on", f"--held-out={number}",
         f"--held-out-name={realset.clean_name(c.name)}"],
        cwd=ROOT, env=env, stdout=subprocess.DEVNULL, stderr=subprocess.STDOUT,
        start_new_session=True)
    asks = [
        ("open_model", {"name": str(target)}),
        ("open_model", {"name": "r2"}),
        ("open_model", {"name": "ladder"}),
        ("open_model", {"link": f"file://{target}"}),
        ("open_model", {"link": str(target)}),
        ("open_model", {"library": number}),
        ("open_model", {"library": realset.clean_name(c.name)}),
        ("open_model", {"into": True, "name": str(target)}),
        ("brickify", {"file": str(target)}),
        ("brickify", {"file": str(LADDER / number / "r2_corner.png")}),
        ("open_model", {"name": str(LADDER / number / "r1.5.mpd")}),
        ("open_model", {"name": "r1.5"}),
        ("brickify", {"file": str(LADDER / number / "r1.5.mpd")}),
        ("brickify", {"file": str(LADDER / number / "r1.5_corner.png")}),
        ("gallery", {"library": True, "q": realset.clean_name(c.name)}),
        ("gallery", {"library": True, "q": "ladder"}),
        ("compare_with_set", {"set": number}),
    ]
    failures = 0
    try:
        up = False
        for _ in range(120):
            try:
                if realset._ask_app(args.port, "__ping__", {}):
                    up = True
                    break
            except OSError:
                time.sleep(2)
        if not up:
            raise SystemExit(f"the app never answered on {args.port}; see {log}")
        realset._ask_app(args.port, "clear_model", {})
        for tool, given in asks:
            said = realset._ask_app(args.port, tool, given)
            text = json.dumps(said, ensure_ascii=False)
            count = json.dumps(realset._ask_app(args.port, "parts_list", {}))
            parts_now = re.findall(r"(\d+) (?:parts|pieces)", count)
            opened = any(int(n) > 0 for n in parts_now)
            # What the answer says beyond echoing what it was asked for.
            beyond = text
            for value in given.values():
                if isinstance(value, str):
                    beyond = beyond.replace(value, "")
            named = bool(LADDER_SAID.search(beyond) or
                         re.search(rf"(?<![\d.]){re.escape(number.split('-')[0])}(?![\d.])",
                                   beyond))
            ok = not opened and not named
            failures += not ok
            print(f"  {'ok' if ok else 'FAIL'}  {tool} {json.dumps(given)[:90]}: "
                  f"{text[:220]}", flush=True)
            if opened:
                realset._ask_app(args.port, "clear_model", {})
    finally:
        try:
            os.killpg(app.pid, signal.SIGTERM)
        except ProcessLookupError:
            pass
        app.wait(timeout=60)
    read = log.read_text(errors="replace") if log.exists() else ""
    opened_files = [line for line in read.splitlines() if "bench/ladder" in line
                    and "open" in line.lower() and "No model" not in line]
    print(f"  {'ok' if not opened_files else 'FAIL'}  the app's log names no ladder file "
          f"it opened ({len(opened_files)})")
    failures += bool(opened_files)
    print(f"reach: {len(asks) + 1 - failures} of {len(asks) + 1} held")
    return 1 if failures else 0


# -- the command line -----------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n")[0])
    sub = parser.add_subparsers(dest="command", required=True)
    for name in ("build", "render", "seed", "order", "place", "report", "sheet", "leaks",
                 "reach"):
        p = sub.add_parser(name)
        p.add_argument("--which", default="proof", choices=realset.HALVES)
        p.add_argument("--subjects", default="")
        p.add_argument("--out", default=str(OUT))
        p.add_argument("--jobs", type=int, default=3)
        p.add_argument("--judge-model", default="opus")
        p.add_argument("--cap", type=int, default=CAP)
        if name == "place":
            p.add_argument("--arm", required=True)
            p.add_argument("--date", required=True)
            p.add_argument("--again", action="store_true")
        if name == "sheet":
            p.add_argument("--size", type=int, default=240)
            p.add_argument("--view", default="corner")
            p.add_argument("--into", default=str(OUT / "ladder_sheet.png"))
        if name == "leaks":
            p.add_argument("arms", nargs="+")
        if name in ("seed", "report"):
            p.add_argument("--before", default=str(BEFORE) if name == "seed" else "")
        if name == "reach":
            p.add_argument("--subject", default="21013-1")
            p.add_argument("--port", type=int, default=10830)
            p.add_argument("--home", default=str(OUT / "reach_home"))
    args = parser.parse_args(argv)
    return {"build": build, "render": render, "seed": seed, "order": order, "place": place,
            "report": report, "sheet": sheet, "leaks": leaks, "reach": reach}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
