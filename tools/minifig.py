#!/usr/bin/env python3
"""Where a minifigure's parts go, measured on real sets.

    tools/minifig.py measure       every joint, over every real figure in vendor/omr
    tools/minifig.py grips         where each accessory is held, checked on real hands
    tools/minifig.py data          write src/minifig/minifig_data.gd

A figure is nine parts on fixed offsets, and none of them is on the stud
grid: an arm sits 15.552 LDU out from the middle of the torso and is
turned 9.782 degrees to follow its slope. Guessed, a figure reads as
broken at once — a hand floating off its wrist, a head sunk into the
torso. So nothing here is guessed.

The offsets come from the LDraw library itself, which states them twice:
in the HELP lines of the parts (3818.dat "Place at -15.552 9 0 relative
to torso", 3816c.dat "Move down 12 units to align with hips") and in the
assemblies it ships (76382.dat, the torso with arms and hands, and
10679b.dat, hips with the current legs). `measure` reads every figure in
LDraw's Official Model Repository — real sets, modelled part by part by
people who own them — and says how many of them agree with each number,
and what the rest used instead.

The other two read the LDraw library for what differs part by part. An
accessory is held by its bar, a cylinder 4 LDU in radius (the 3.2 mm
that fits a hand), so `grips` finds that bar in each accessory and
`data` writes where it is; `grips` also checks the rule against every
accessory a real figure holds. A neck accessory lifts the head by the
thickness of its collar, which `data` measures from the geometry and
`measure` checks against the heads real sets lift.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw.geometry import flatten  # noqa: E402
from ldraw.library import Library  # noqa: E402
from ldraw.parser import SubfileRef  # noqa: E402

OMR = ROOT / "vendor" / "omr" / "files"
LDRAW = ROOT / "vendor" / "ldraw"
CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"
OUT = ROOT / "src" / "minifig" / "minifig_data.gd"

# A 4x4 affine as rows, LDraw's own axes (+Y down, a figure faces -Z).
Mat = list[list[float]]

# What the LDraw library says, relative to the torso. The same numbers
# are in src/minifig/minifig.gd; `measure` is how they were checked.
JOINTS: dict[str, tuple[tuple[float, float, float], tuple[float, ...]]] = {
    # 76382.dat lines 1-5, and 3818/3819.dat "Place at -15.552 9 0
    # relative to torso ... rotate 9.782 about z".
    "arm_r": ((-15.552, 9, 0), (0.985, -0.17, 0, 0.17, 0.985, 0, 0, 0, 1)),
    "arm_l": ((15.552, 9, 0), (0.985, 0.17, 0, -0.17, 0.985, 0, 0, 0, 1)),
    "hand_r": ((-23.69, 26.774, -9.898),
               (0.985, -0.12, 0.12, 0.17, 0.696, -0.696, 0, 0.707, 0.707)),
    "hand_l": ((23.69, 26.774, -9.898),
               (0.985, 0.12, -0.12, -0.17, 0.696, -0.696, 0, 0.707, 0.707)),
    # Not written anywhere in the library: the hips are where every real
    # figure puts them (see `measure`), and the legs 12 below the hips,
    # which 3816c.dat says and 10679b.dat does.
    "hips": ((0, 32, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1)),
    "leg_r": ((0, 44, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1)),
    "leg_l": ((0, 44, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1)),
    "head": ((0, -24, 0), (1, 0, 0, 0, 1, 0, 0, 0, 1)),
}

# Where a hand holds, in the hand's own frame: 3820.dat, "The centre of
# the grip is at x, y -.8229, z -9.8948", and the grip axis 14.5 degrees
# off the hand's Y ("The Hand angle is 14.5 degrees").
GRIP = (0.0, -0.8229, -9.8948)
GRIP_AXIS = (0.0, 0.968148, 0.25038)
# A bar a hand holds: 3.2 mm across, 0.4 mm to the LDU.
BAR_RADIUS = 4.0


# -- matrices --------------------------------------------------------------


def mat(v: list[float]) -> Mat:
    """Twelve numbers of a type-1 line (x y z a b c d e f g h i)."""
    return [[v[3], v[4], v[5], v[0]], [v[6], v[7], v[8], v[1]],
            [v[9], v[10], v[11], v[2]], [0.0, 0.0, 0.0, 1.0]]


def mul(a: Mat, b: Mat) -> Mat:
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def inv(m: Mat) -> Mat:
    """Inverse of a rigid transform (the rotation's transpose)."""
    r = [[m[j][i] for j in range(3)] for i in range(3)]
    t = [-sum(r[i][k] * m[k][3] for k in range(3)) for i in range(3)]
    return [r[0] + [t[0]], r[1] + [t[1]], r[2] + [t[2]], [0.0, 0.0, 0.0, 1.0]]


def apply(m: Mat, p: tuple[float, ...]) -> tuple[float, float, float]:
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3]
                 for i in range(3))  # type: ignore[return-value]


def turn(m: Mat, p: tuple[float, ...]) -> tuple[float, float, float]:
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2]
                 for i in range(3))  # type: ignore[return-value]


IDENTITY: Mat = mat([0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1])


def joint(name: str) -> Mat:
    (x, y, z), r = JOINTS[name]
    return mat([x, y, z, *r])


def apart(a: Mat, b: Mat) -> tuple[float, float]:
    """How far apart two placements are: LDU between origins, and the
    largest difference in any rotation entry."""
    move = math.dist([a[i][3] for i in range(3)], [b[i][3] for i in range(3)])
    spin = max(abs(a[i][j] - b[i][j]) for i in range(3) for j in range(3))
    return move, spin


# -- the parts of a figure ---------------------------------------------------


class Parts:
    """Names and kinds of LDraw parts, read from the library's headers."""

    def __init__(self) -> None:
        self.library = Library(LDRAW)
        self._seen: dict[str, tuple[str, str, list]] = {}
        self.category: dict[str, str] = {}
        if CATALOGUE.exists():
            for entry in json.loads(CATALOGUE.read_text())["parts"]:
                self.category[entry["id"]] = entry["category"]

    def header(self, pid: str) -> tuple[str, str, list]:
        if pid not in self._seen:
            found = self.library.get(pid + ".dat")
            if found is None:
                self._seen[pid] = ("", "", [])
            else:
                refs = [c for c in found.commands if isinstance(c, SubfileRef)]
                self._seen[pid] = (found.description, found.part_type, refs)
        return self._seen[pid]

    def role(self, pid: str) -> str | None:
        """Which joint of a figure a part is, or None."""
        name = self.header(pid)[0].lower()
        if name.startswith("~moved to"):
            return self.role(name.split()[-1])
        if "minifig torso" in name and pid.startswith(("973", "76382")):
            return "torso"
        if name.startswith("minifig head") and pid.startswith("3626"):
            return "head"
        if pid.startswith("3818") or name.startswith("minifig arm right"):
            return "arm_r"
        if pid.startswith("3819") or name.startswith("minifig arm left"):
            return "arm_l"
        if pid.startswith("3820") or name.startswith("minifig hand"):
            return "hand"
        if "hips and legs" in name:
            return "hipslegs"
        if re.match(r"^(3815|970)[a-z]?(p\w+)?$", pid) or name.startswith("minifig hips"):
            return "hips"
        if pid.startswith("3816") or name.startswith("minifig leg right"):
            return "leg_r"
        if pid.startswith("3817") or name.startswith("minifig leg left"):
            return "leg_l"
        category = self.category.get(pid, "")
        if category == "Minifig Headwear":
            return "headwear"
        if category == "Minifig Neckwear":
            return "neck"
        if category == "Minifig Accessory":
            return "accessory"
        return None


def _submodels(text: str) -> dict[str, list[tuple[int, Mat, str]]]:
    files: dict[str, list[tuple[int, Mat, str]]] = {}
    current = None
    for line in text.splitlines():
        bits = line.split()
        if bits[:2] == ["0", "FILE"]:
            current = " ".join(bits[2:]).lower()
            files[current] = []
        elif current is not None and len(bits) >= 15 and bits[0] == "1":
            try:
                numbers = [float(v) for v in bits[2:14]]
            except ValueError:
                continue
            ref = " ".join(bits[14:]).lower().replace("\\", "/")
            files[current].append((int(bits[1]) if bits[1].isdigit() else 16, mat(numbers), ref))
    return files


def figures(parts: Parts) -> list[dict]:
    """Every real figure in the repository: a sub-model of one set with
    exactly one torso and one head and not more than 25 parts, so it is
    a figure and not a scene. Torso and hips-and-legs assemblies are
    opened up, since the arms inside 973p01c01 are placed the same way
    as loose ones."""
    found = []
    for path in sorted(OMR.glob("*")):
        files = _submodels(path.read_text(errors="replace"))
        for name in files:
            flat: list[tuple[str, Mat, int]] = []
            _flatten(parts, files, name, IDENTITY, flat, 0)
            roles = [parts.role(pid) for pid, _m, _c in flat]
            if roles.count("torso") != 1 or roles.count("head") != 1 or len(flat) > 25:
                continue
            found.append({"set": path.name.split(".")[0], "model": name,
                          "parts": [(pid, m, c, r) for (pid, m, c), r in zip(flat, roles)]})
    return found


def _flatten(parts: Parts, files: dict, name: str, at: Mat,
             out: list, depth: int) -> None:
    for colour, m, ref in files.get(name, []):
        here = mul(at, m)
        if ref in files and depth < 8:
            _flatten(parts, files, ref, here, out, depth + 1)
            continue
        pid = ref.removesuffix(".dat").split("/")[-1]
        _name, kind, refs = parts.header(pid)
        if "Shortcut" in kind and parts.role(pid) in ("torso", "hipslegs"):
            inner = [(r.filename.removesuffix(".dat").split("/")[-1], r) for r in refs]
            if any(parts.role(sub) for sub, _r in inner):
                for sub, r in inner:
                    if parts.role(sub):
                        k = r.matrix
                        out.append((sub, mul(here, mat([k.x, k.y, k.z, k.a, k.b, k.c,
                                                        k.d, k.e, k.f, k.g, k.h, k.i])),
                                    colour if r.color == 16 else r.color))
                continue
        out.append((pid, here, colour))


# -- measure -----------------------------------------------------------------


def measure() -> int:
    parts = Parts()
    found = figures(parts)
    sets = {f["set"].split("_")[0] for f in found}
    print(f"{len(found)} figures in {len(sets)} real sets of {OMR}")
    print("each joint relative to the torso, LDraw's axes (+Y down, facing -Z);")
    print("a hand relative to its own arm, since a raised arm carries its hand.")
    print("'posed' is in the same place and turned: a raised arm, a turned head.\n")
    for which in ["head", "arm_r", "arm_l", "hand_r", "hand_l", "hips", "leg_r", "leg_l"]:
        want = joint(which)
        if which.startswith("hand"):
            want = mul(inv(joint("arm" + which[4:])), want)
        exact = near = posed = seen = 0
        other: Counter = Counter()
        examples: dict = defaultdict(set)
        for figure in found:
            torso = next(m for _p, m, _c, r in figure["parts"] if r == "torso")
            back = inv(torso)
            for pid, m, _c, role in figure["parts"]:
                side = role
                if role == "hand":
                    side = "hand_r" if mul(back, m)[0][3] < 0 else "hand_l"
                if side != which:
                    continue
                here = mul(back, m)
                if role == "hand":
                    arm = [a for _p, a, _c, r in figure["parts"] if r == "arm" + side[4:]]
                    if len(arm) != 1:
                        continue
                    here = mul(inv(arm[0]), m)
                seen += 1
                move, spin = apart(here, want)
                if move <= 0.05 and spin <= 0.01:
                    exact += 1
                elif move <= 1.0 and spin <= 0.05:
                    near += 1
                elif move <= 1.0:
                    posed += 1
                else:
                    key = tuple(round(here[i][3], 1) for i in range(3))
                    other[key] += 1
                    examples[key].add(figure["set"])
        x, y, z = (want[i][3] for i in range(3))
        what = "of its arm" if which.startswith("hand") else ""
        print(f"  {which:7} at ({x:g}, {y:g}, {z:g}) {what}: {exact} of {seen} exactly, "
              f"{near} more within 1 LDU, {posed} posed")
        for key, n in other.most_common(3):
            print(f"           {n:4} at {key}, e.g. {', '.join(sorted(examples[key])[:3])}")
    _measure_hats_and_necks(parts, found)
    return 0


def _measure_hats_and_necks(parts: Parts, found: list[dict]) -> None:
    on_head = Counter()
    lifted: dict[str, Counter] = defaultdict(Counter)
    bare = Counter()
    for figure in found:
        torso = next(m for _p, m, _c, r in figure["parts"] if r == "torso")
        head = next(m for _p, m, _c, r in figure["parts"] if r == "head")
        lift = round(-24 - mul(inv(torso), head)[1][3])
        necks = [p for p, _m, _c, r in figure["parts"] if r == "neck"]
        if necks:
            for neck in necks:
                lifted[neck][lift] += 1
        else:
            bare[lift] += 1
        for _p, m, _c, role in figure["parts"]:
            if role == "headwear":
                move, spin = apart(mul(inv(head), m), IDENTITY)
                on_head["exact" if move <= 0.05 and spin <= 0.01 else "other"] += 1
    total = sum(on_head.values())
    print(f"\n  headwear at the head's own origin: {on_head['exact']} of {total}")
    print(f"  head lift with no neck accessory: {dict(bare.most_common())}")
    print("  head lift over a neck accessory (LDU above the usual 24), and the "
          "collar measured off its geometry:")
    library = parts.library
    for neck, counts in sorted(lifted.items(), key=lambda kv: -sum(kv[1].values())):
        print(f"    {neck:8} {dict(counts.most_common())}  collar {collar(library, neck):g}")


# -- the collar a neck accessory puts under the head -------------------------


def collar(library: Library, pid: str) -> float:
    """How far a neck accessory rises above the top of the torso round the
    neck, in LDU: what the head has to sit up by.

    The head's underside is at the torso's top (y 0) and the neck post
    rises through a ring about 6 LDU across; a collar is whatever of the
    accessory is inside 10 LDU of that axis and above the shoulders.
    Rounded to whole LDU, which is how real sets lift it."""
    mesh = flatten(library, pid + ".dat")
    top = 0.0
    for t in mesh.triangles:
        for p in (t.a, t.b, t.c):
            if p.x * p.x + p.z * p.z <= 100.0 and -12.0 < p.y < 0.0:
                top = min(top, p.y)
    return float(round(-top))


# -- where an accessory is held ----------------------------------------------


CYLINDER = re.compile(r"^(?:48/|8/)?(\d+)-(\d+)cyl[a-z0-9]*\.dat$")


def bars(library: Library, pid: str) -> list[tuple[tuple, tuple, float]]:
    """The bars a hand could hold in a part: (centre, unit axis, length)
    of every cylinder 4 LDU in radius in it, joined where pieces of one
    bar meet end to end."""
    found: list[tuple[tuple, tuple]] = []      # (start, end)
    _bars(library, pid + ".dat", IDENTITY, found, 0)
    joined: list[list] = []
    for start, end in found:
        axis = _unit(tuple(e - s for s, e in zip(start, end)))
        for bar in joined:
            if _collinear(bar, start, end, axis):
                bar[0] = min(bar[0], _along(bar, start), _along(bar, end))
                bar[1] = max(bar[1], _along(bar, start), _along(bar, end))
                break
        else:
            joined.append([0.0, math.dist(start, end), start, axis])
    out = []
    for low, high, origin, axis in joined:
        if high - low < 2.0:
            continue
        mid = (low + high) / 2.0
        centre = tuple(o + a * mid for o, a in zip(origin, axis))
        out.append((centre, axis, high - low))
    return out


def _bars(library: Library, name: str, at: Mat, out: list, depth: int) -> None:
    found = library.get(name)
    if found is None or depth > 12:
        return
    for command in found.commands:
        if not isinstance(command, SubfileRef):
            continue
        k = command.matrix
        here = mul(at, mat([k.x, k.y, k.z, k.a, k.b, k.c, k.d, k.e, k.f, k.g, k.h, k.i]))
        stem = command.filename.split("\\")[-1]
        if CYLINDER.match(stem):
            across = math.hypot(here[0][0], here[1][0], here[2][0])
            deep = math.hypot(here[0][2], here[1][2], here[2][2])
            if abs(across - BAR_RADIUS) < 0.15 and abs(deep - BAR_RADIUS) < 0.15:
                start = apply(here, (0, 0, 0))
                end = apply(here, (0, 1, 0))
                if math.dist(start, end) > 0.2:
                    out.append((start, end))
            continue
        if stem.startswith(("stud", "box", "rect", "disc", "ndis", "edge", "con", "ring")):
            continue
        sub = library.get(command.filename)
        if sub is not None and sub.part_type.lower().startswith("primitive"):
            continue
        _bars(library, command.filename, here, out, depth + 1)


def _unit(v: tuple) -> tuple:
    n = math.sqrt(sum(c * c for c in v)) or 1.0
    return tuple(c / n for c in v)


def _along(bar: list, p: tuple) -> float:
    return sum((a - o) * d for a, o, d in zip(p, bar[2], bar[3]))


def _collinear(bar: list, start: tuple, end: tuple, axis: tuple) -> bool:
    if abs(abs(sum(a * b for a, b in zip(axis, bar[3]))) - 1.0) > 1e-3:
        return False
    for p in (start, end):
        t = _along(bar, p)
        foot = tuple(o + d * t for o, d in zip(bar[2], bar[3]))
        if math.dist(foot, p) > 0.05:
            return False
    lo, hi = sorted((_along(bar, start), _along(bar, end)))
    return lo <= bar[1] + 0.5 and hi >= bar[0] - 0.5


def grip_of(library: Library, pid: str) -> tuple:
    """Where a hand holds a part: (point, axis) in the part's own frame,
    the axis pointing from the business end towards the handle's end.

    LDraw draws a held accessory with its handle along Y and, where it
    can, its grip at the origin. So a bar along Y through the origin is
    held there; failing that the longest bar along Y is held at its
    middle, then any bar through the origin, then the longest bar. A
    part with no bar at all is held at its origin along Y, which is
    where real figures hold the bow, the one common accessory without
    one."""
    found = bars(library, pid)
    upright = [b for b in found if abs(b[1][1]) > 0.99]
    for group in (upright, found):
        for centre, axis, length in sorted(group, key=lambda b: -b[2]):
            t = sum(-c * a for c, a in zip(centre, axis))
            foot = tuple(c + a * t for c, a in zip(centre, axis))
            # Inside it, not at an end: a sword's origin is at its
            # guard, where the handle starts, and the hand is lower down.
            if math.dist(foot, (0, 0, 0)) <= 1.0 and abs(t) <= length / 2 - 2.0:
                return (foot, _pointing(library, pid, foot, axis))
        if group:
            centre, axis, _length = max(group, key=lambda b: b[2])
            return (centre, _pointing(library, pid, centre, axis))
    return ((0.0, 0.0, 0.0), (0.0, 1.0, 0.0))


def _pointing(library: Library, pid: str, at: tuple, axis: tuple) -> tuple:
    """The axis signed so the bulk of the part is on its negative side,
    which is up in the hand: a sword's blade, a torch's flame."""
    lo, hi = flatten(library, pid + ".dat").bounds()
    middle = ((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, (lo.z + hi.z) / 2)
    toward = sum((m - a) * d for m, a, d in zip(middle, at, axis))
    if abs(toward) < 0.5:
        # Balanced about the grip: keep LDraw's own sense, +Y down.
        return axis if axis[1] >= 0 else tuple(-c for c in axis)
    return axis if toward < 0 else tuple(-c for c in axis)


def grips() -> int:
    """Check the rule on every accessory a real figure holds: where the
    real hand's grip is, against the bar the rule picks."""
    parts = Parts()
    library = parts.library
    held = same_bar = close = 0
    misses: Counter = Counter()
    rules: dict[str, tuple] = {}
    for figure in figures(parts):
        hands = [m for _p, m, _c, r in figure["parts"] if r == "hand"]
        for pid, m, _c, role in figure["parts"]:
            if role != "accessory" or not hands:
                continue
            hand = min(hands, key=lambda h: math.dist(
                [h[i][3] for i in range(3)], [m[i][3] for i in range(3)]))
            back = inv(m)
            # The real hand's grip, in the accessory's frame.
            point = apply(back, apply(hand, GRIP))
            axis = turn(back, turn(hand, GRIP_AXIS))
            # Not in the hand: a shield on an arm, a cup by a hand.
            if math.dist(point, (0, 0, 0)) > 60:
                continue
            held += 1
            if pid not in rules:
                rules[pid] = grip_of(library, pid)
            at, along = rules[pid]
            aligned = abs(sum(a * b for a, b in zip(axis, along)))
            if _off_line(point, at, along) <= 1.5 and aligned > math.cos(math.radians(12)):
                same_bar += 1
                if math.dist(point, at) <= 3.0:
                    close += 1
                else:
                    misses[f"{pid} (same bar, {math.dist(point, at):.0f} LDU along)"] += 1
            else:
                misses[pid + " (elsewhere)"] += 1
    print(f"{held} accessories held in a real figure's hand. The rule puts the grip on the "
          f"bar the real hand holds for {same_bar}, within 3 LDU of the same place for {close}.")
    for what, n in misses.most_common(14):
        print(f"  {n:3} {what}")
    return 0


def _off_line(p: tuple, centre: tuple, axis: tuple) -> float:
    t = sum((a - c) * d for a, c, d in zip(p, centre, axis))
    foot = tuple(c + d * t for c, d in zip(centre, axis))
    return math.dist(foot, p)


# -- data --------------------------------------------------------------------


def data() -> int:
    """Write the per-part tables the app needs and cannot work out at run
    time, because the web build has no LDraw library to read."""
    parts = Parts()
    library = parts.library
    catalogue = json.loads(CATALOGUE.read_text())["parts"]
    usable = [e for e in catalogue if not e["name"].startswith(("~", "=", "_"))
              and "Alias" not in e["kind"] and not e["moved_to"]]

    held: dict[str, list[float]] = {}
    for entry in usable:
        if entry["category"] != "Minifig Accessory" or "Shortcut" in entry["kind"]:
            continue
        found = grip_of(library, entry["id"])
        # Rounded, and without negative zeros, so a rerun diffs clean.
        grip = [round(v, 3) + 0.0 for v in (*found[0], *found[1])]
        # What a part with no entry gets: held at its origin along Y.
        if grip != [0.0, 0.0, 0.0, 0.0, 1.0, 0.0]:
            held[entry["id"]] = grip

    # How far a neck accessory lifts the head: what real figures wearing
    # it do, where any does, and otherwise its collar off the geometry.
    # The collar alone agrees with real sets for about half the parts
    # both know (`measure`), so it is the fallback and not the rule.
    worn: dict[str, Counter] = defaultdict(Counter)
    for figure in figures(parts):
        torso = next(m for _p, m, _c, r in figure["parts"] if r == "torso")
        head = next(m for _p, m, _c, r in figure["parts"] if r == "head")
        lift = round(-24 - mul(inv(torso), head)[1][3])
        for pid, _m, _c, role in figure["parts"]:
            if role == "neck":
                worn[pid][lift] += 1
    lifts: dict[str, int] = {}
    for entry in usable:
        if entry["category"] != "Minifig Neckwear":
            continue
        pid = entry["id"]
        lift = worn[pid].most_common(1)[0][0] if worn[pid] else int(collar(library, pid))
        if lift > 0:
            lifts[pid] = lift

    # The hands a printed torso comes with, from the library's torso
    # assemblies (76382pXX = 973pXX with arms and hands): arms in the
    # torso's colour unless the assembly says otherwise.
    hands: dict[str, list[int]] = {}
    for path in sorted((LDRAW / "parts").glob("76382*.dat")):
        found = library.get(path.name)
        if found is None:
            continue
        refs = [c for c in found.commands if isinstance(c, SubfileRef)]
        torso = [r for r in refs if r.filename.startswith("973")]
        arm = [r for r in refs if r.filename.startswith(("3818", "3819"))]
        hand = [r for r in refs if r.filename.startswith("3820")]
        if len(torso) != 1 or not hand:
            continue
        pid = torso[0].filename.removesuffix(".dat")
        if pid == "973" or not arm or arm[0].filename not in ("3818.dat", "3819.dat"):
            continue
        hands.setdefault(pid, [arm[0].color if arm[0].color != 16 else -1, hand[0].color])

    lines = [
        "## Generated by tools/minifig.py data from the LDraw library. Do not edit:",
        "## rerun it. Each table says, part by part, what the figure rules in",
        "## minifig.gd need and the web build cannot read for itself.",
        "class_name MinifigData",
        "extends RefCounted",
        "",
        "## Accessory -> [grip x, y, z, axis x, y, z] in the part's LDraw frame: the",
        "## middle of the bar a hand closes on, and the bar's direction, pointing",
        "## from the business end towards the end of the handle.",
        "const GRIPS := {",
    ]
    lines += [f'\t"{k}": {json.dumps(v)},' for k, v in sorted(held.items())]
    lines += ["}", "",
              "## Neck accessory -> LDU its collar rises above the torso, which",
              "## is how far the head sits up on it.",
              "const NECK_LIFT := {"]
    lines += [f'\t"{k}": {v},' for k, v in sorted(lifts.items())]
    lines += ["}", "",
              "## Printed torso -> [arm colour, or -1 for the torso's own; hand colour],",
              "## from the library's torso assemblies (76382pXX).",
              "const TORSO_HANDS := {"]
    lines += [f'\t"{k}": {json.dumps(v)},' for k, v in sorted(hands.items())]
    lines += ["}", ""]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines))
    print(f"wrote {OUT.relative_to(ROOT)}: {len(held)} grips, {len(lifts)} neck lifts, "
          f"{len(hands)} torso hand colours")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", choices=["measure", "grips", "data"])
    args = parser.parse_args()
    return {"measure": measure, "grips": grips, "data": data}[args.what]()


if __name__ == "__main__":
    sys.exit(main())
