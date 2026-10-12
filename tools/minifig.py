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

`data` also writes what the standard joints cannot say about the parts
that are not the classic figure's. Where the library's own assemblies
put each odd part (30375cs0.dat's battle droid, 84638.dat's hook,
84637b.dat's wooden leg) and what an odd body comes with; where each
head's neck socket opens (a goblin's head is drawn from its neck up, a
classic head from its top); where each visor turns and each helmet takes
it, off their pins and dimples; and which neck parts real figures wear
turned round (the quiver). And what only ever attaches to something
else: the hips printed legs come with (73200bpXX), the hips and legs
springs go into (43743-f1), the arm a prosthetic hand goes on (6828.dat's
HELP line), the body a droid's head clips onto. Which parts those are is
decided by the same slot rule the app offers parts by (Minifig.slot_for).
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
# How far apart two lengths of one bar may be and still be one bar to a
# hand, in LDU. A ribbed hilt is rings of that bar with narrower waists
# between them, 1.3 to 1.5 LDU long (2674b, 66964), and a hand 11 LDU
# long closes over several at once.
RIB = 2.0
# How long a closed hand is along its grip (3820.dat's bore), in LDU. A
# length of bar as long as that is a handle of its own, and the rings a
# rib away from it are something else: a lightsaber hilt's emitter above
# its grip (64567a, which real figures hold by the grip), a telescope's
# other tube.
HAND_LENGTH = 11.0


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
    bar meet end to end, or are rings a rib apart (see [RIB] and
    [HAND_LENGTH])."""
    found: list[tuple[tuple, tuple]] = []      # (start, end)
    _bars(library, pid + ".dat", IDENTITY, found, 0)
    # [low, high, origin, axis, its longest piece]
    joined: list[list] = [[0.0, math.dist(s, e), s, _unit(tuple(b - a for a, b in zip(s, e))),
                           math.dist(s, e)] for s, e in found]
    # Joined until nothing more joins, so the order the pieces are drawn
    # in does not matter.
    merged = True
    while merged:
        merged = False
        for one in joined:
            for other in joined:
                if other is one:
                    continue
                ends = [tuple(o + a * t for o, a in zip(other[2], other[3]))
                        for t in (other[0], other[1])]
                if _collinear(one, ends[0], ends[1], other[3],
                              max(one[4], other[4]) < HAND_LENGTH):
                    one[0] = min(one[0], _along(one, ends[0]), _along(one, ends[1]))
                    one[1] = max(one[1], _along(one, ends[0]), _along(one, ends[1]))
                    one[4] = max(one[4], other[4])
                    joined.remove(other)
                    merged = True
                    break
            if merged:
                break
    out = []
    for low, high, origin, axis, _longest in joined:
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


def _collinear(bar: list, start: tuple, end: tuple, axis: tuple, ribs: bool) -> bool:
    """Whether a length of bar is on a bar's line and meets it, end to end
    or, where both are [ribs], a rib apart."""
    if abs(abs(sum(a * b for a, b in zip(axis, bar[3]))) - 1.0) > 1e-3:
        return False
    for p in (start, end):
        t = _along(bar, p)
        foot = tuple(o + d * t for o, d in zip(bar[2], bar[3]))
        if math.dist(foot, p) > 0.05:
            return False
    lo, hi = sorted((_along(bar, start), _along(bar, end)))
    apart = RIB if ribs else 0.5
    return lo <= bar[1] + apart and hi >= bar[0] - apart


# Where the rule below gets a grip wrong, the grip it found before it
# joined ribs: the point and the axis, by part.
KEPT_GRIPS: dict[str, tuple[tuple, tuple]] = {
    # The hilt is the bar from the pommel at the origin to y -20. The
    # longest bar along Y is the bar holder on the back of the blade, y
    # -40 to -62, three lengths of bar end to end.
    "11107": ((0.0, -10.0, 0.0), (0.0, 1.0, 0.0)),
    # The origin is 1.67 down the handle from the head, so it is "on the
    # bar, not at its end" as the bow's is, and held there the mallet is
    # upside down: its handle in the air and its head in the fist.
    "4522b": ((0.0, 23.167, 0.0), (0.0, 1.0, 0.0)),
}


def grip_of(library: Library, pid: str) -> tuple:
    """Where a hand holds a part: (point, axis) in the part's own frame,
    the axis pointing from the business end towards the handle's end.

    LDraw draws a held accessory with its handle along Y and, where it
    can, its grip at the origin. So a bar along Y through the origin is
    held there; failing that the longest bar along Y is held at its
    middle, then any bar through the origin, then the longest bar. A
    part with no bar at all is held at its origin along Y. The bow
    (4499) is held at its origin too, by real figures and here: its
    handle is ribbed, a bar to a hand ([RIB]), and the origin is on it
    an LDU and a bit short of its end. And [KEPT_GRIPS], where that is
    wrong."""
    if pid in KEPT_GRIPS:
        return KEPT_GRIPS[pid]
    found = bars(library, pid)
    upright = [b for b in found if abs(b[1][1]) > 0.99]
    for group in (upright, found):
        for centre, axis, length in sorted(group, key=lambda b: -b[2]):
            t = sum(-c * a for c, a in zip(centre, axis))
            foot = tuple(c + a * t for c, a in zip(centre, axis))
            # Inside it, not at an end: a sword's origin is at its
            # guard, where the handle starts, and the hand is lower down.
            if math.dist(foot, (0, 0, 0)) <= 1.0 and abs(t) <= length / 2 - 1.0:
                return (foot, _pointing(library, pid, foot, axis))
        if group:
            centre, axis, _length = max(group, key=lambda b: b[2])
            return (centre, _pointing(library, pid, centre, axis))
    return ((0.0, 0.0, 0.0), (0.0, 1.0, 0.0))


def along_bar(library: Library, pid: str, at: tuple, axis: tuple) -> tuple | None:
    """How far a hand holding a part at [at] can slide along [axis] and
    still be on the bar it holds there: (from, to) in LDU along [axis],
    from the grip, or None where the grip is on no bar at all."""
    for centre, way, length in bars(library, pid):
        if abs(abs(sum(a * b for a, b in zip(way, axis))) - 1.0) > 1e-3 \
                or _off_line(at, centre, way) > 0.05:
            continue
        ends = sorted(sum((c + w * t - a) * d for c, w, a, d in zip(centre, way, at, axis))
                      for t in (-length / 2, length / 2))
        if ends[0] <= 0.05 and ends[1] >= -0.05:
            return (min(ends[0], 0.0), max(ends[1], 0.0))
    return None


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


# -- which slot a part fills -------------------------------------------------
#
# The same rule as Minifig.slot_for in src/minifig/minifig.gd, which is
# the one the app offers parts by; this copy only decides which parts the
# tables below are worked out for. The catalogue's own categories first,
# where LDraw has one for the slot; LDraw's names for the rest, which file
# every head, torso, arm and leg under plain "Minifig".

HAT_EXTRA_NAMES = re.compile(
    r"^(Helmet Visor|Visor|Plume|Feathers|Helmet Ornament|Crown Tiara"
    r"|Cap Aviator Goggles|Hair Decoration|Helmet Floodlight|Carrot Nose)\b")
BACK_NAMES = re.compile(
    r"^(Airtanks|Jet-Pack|Jetpack|Backpack|Arrow Quiver|Scuba Tank|Wings|Eagle Wing"
    r"|Bat Wing|Container D-Basket|Sack|Scabbard|Neck Bracket|Bracket"
    r"|Breathing Apparatus|Fire Helmet Breathing Hose|Ninja Turtle Shell)\b")
NAME_RULES = [
    ("hat_extra", r"^Helmet Visor\b"),
    ("torso", r"^Mechanical Head and Torso\b"),
    ("head", r"^(Head|Baby Head|Martian Head|Mechanical Head)\b"),
    ("headwear", r"^(Hat|Helmet|Hair|Cap|Headdress|Crown|Mask|Hood)\b"),
    ("arms", r"^(Arm|Mechanical Arm|Skeleton Arm|Mechanical Shoulder|Body Dug Arm)\b"),
    ("hands", r"^(Hand|Boxing Glove)\b"),
    ("legs", r"^(Leg|Legs|Robot Leg|Mechanical Leg|Mechanical Legs|Skeleton Leg"
             r"|Martian Legs|Hips and Legs|Hips and Skirt|Lower Body|Centaur Body"
             r"|Hips Mermaid|Hips Ghost|Hips Genie|Hips Snake|Hips with Tentacles)\b"),
    ("hips", r"^Hips\b"),
    ("neck", r"^(Armour|Breastplate)\b"),
    ("torso", r"^(Torso|Mechanical Torso|Mechanical Cuboid Torso|Skeleton Torso|Body"
              r"|Baby Body|Bundled Baby|Gollum|Figure Sebulba|Mutant Fish)\b"),
]


def plain_name(name: str) -> str:
    return " ".join(name.split())


def is_minifig(name: str, category: str) -> bool:
    name = plain_name(name)
    return category.startswith("Minifig") or name.startswith(("Minifig ", "Keychain Minifig "))


def slot_of(name: str, category: str) -> str:
    """Which slot of the builder a part fills, or "" for none."""
    full = plain_name(name)
    if not is_minifig(full, category):
        return ""
    short = full.removeprefix("Keychain ").removeprefix("Minifig ")
    if category == "Minifig Headwear":
        return "hat_extra" if HAT_EXTRA_NAMES.search(short) else "headwear"
    if category == "Minifig Neckwear":
        if re.search(r"^Cape\b", short):
            return "cape"
        return "back" if BACK_NAMES.search(short) else "neck"
    if category == "Minifig Hipwear":
        return "hipwear"
    if category == "Minifig Footwear":
        return "footwear"
    if category == "Minifig Accessory":
        return "accessory"
    if category == "Sheet Fabric":
        return "hipwear" if re.search(r"^(Skirt|Tuxedo Tails)\b", short) else "cape"
    for slot, rule in NAME_RULES:
        if re.search(rule, short):
            return slot
    return "accessory"


def real_part(entry: dict) -> bool:
    """What Minifig._real calls a part: not a redirect, alias, shortcut,
    sticker or anything else that is not an element."""
    if entry.get("moved_to") or not entry.get("reachable", True):
        return False
    if entry["kind"] not in ("Part", "Unofficial_Part"):
        return False
    return not entry["name"].strip().startswith(("~", "=", "_", "Figure "))


def family(pid: str) -> str:
    """A printed part's plain mould: 3816cp0b -> 3816c. The same as
    Minifig._family."""
    found = re.match(r"^([a-z]?\d+[a-z]?(?:-f\d)?)(p[0-9a-z]+)?$", pid)
    return found.group(1) if found else pid


# -- where the library's own assemblies put each part ------------------------


TYPE1 = re.compile(r"^1\s+(\S+)\s+((?:\S+\s+){12})(.+?)\s*$")


def _type1(path: Path) -> list[tuple[Mat, str]]:
    out = []
    for line in path.read_text(encoding="latin-1").splitlines():
        found = TYPE1.match(line.strip())
        if not found:
            continue
        try:
            numbers = [float(v) for v in found.group(2).split()]
        except ValueError:
            continue
        ref = found.group(3).lower().replace("\\", "/").removesuffix(".dat")
        out.append((mat(numbers), ref))
    return out


def library_assemblies(library: Library, minifig: dict[str, str]) -> list[tuple[str, list]]:
    """Every file of the library that puts two or more minifigure parts
    together — a torso with its arms and hands, hips with their legs, a
    battle droid — opened down to those parts: [(file, [(part, at)])]."""
    found = []
    roots = [LDRAW / "parts", LDRAW / "unofficial" / "parts"]
    for root in roots:
        if not root.is_dir():
            continue
        for path in sorted(root.glob("*.dat")):
            text = path.read_text(encoding="latin-1")
            if text.startswith("0 ~Moved"):
                continue
            placed: list[tuple[str, Mat]] = []
            _open_up(library, minifig, path, IDENTITY, placed, 0, top=path.stem.lower())
            if len(placed) >= 2:
                found.append((path.stem.lower(), placed))
    return found


def _open_up(library: Library, minifig: dict, path: Path, at: Mat, out: list,
             depth: int, top: str = "") -> None:
    for m, ref in _type1(path):
        if ref.startswith("s/") or "/" in ref:
            continue
        here = mul(at, m)
        if ref in minifig and ref != top:
            out.append((ref, here))
            continue
        if depth >= 3:
            continue
        sub = library.resolve(ref + ".dat")
        if sub is None or sub.parent.name == "p" or sub.parent.parent.name == "p":
            continue
        _open_up(library, minifig, sub, here, out, depth + 1)


def _key(m: Mat) -> tuple:
    return tuple(round(m[i][j], 3) + 0.0 for i in range(3) for j in (3, 0, 1, 2))


def _close(a: tuple, b: tuple, within: float = 0.02) -> bool:
    return all(abs(x - y) <= within for x, y in zip(a, b))


def unmirrored(m: Mat, symmetric: bool = False) -> Mat:
    """A placement turned rather than mirrored. The library mirrors a
    left arm to stand for the right one (the bird wing, the flipper), and
    now and then a hand; a real part cannot be mirrored, only turned, and
    the app draws a mirrored part inside out. A part the same both sides
    of its own X (a hand) loses the mirror; any other has its own Z
    flipped as well, which makes the mirror the half turn about Y that
    puts the same moulding on the other side."""
    r = [row[:3] for row in m[:3]]
    det = (r[0][0] * (r[1][1] * r[2][2] - r[1][2] * r[2][1])
           - r[0][1] * (r[1][0] * r[2][2] - r[1][2] * r[2][0])
           + r[0][2] * (r[1][0] * r[2][1] - r[1][1] * r[2][0]))
    if det >= 0:
        return m
    if symmetric:
        return [[-row[0], row[1], row[2], row[3]] for row in m[:3]] + [m[3]]
    return [[row[0], row[1], -row[2], row[3]] for row in m[:3]] + [m[3]]


def _numbers(key: tuple) -> list[float]:
    """A placement as twelve numbers in the order a type-1 line writes
    them: x y z, then the rotation by rows."""
    return [key[0], key[4], key[8], key[1], key[2], key[3], key[5], key[6], key[7],
            key[9], key[10], key[11]]


STANDARD_FAMILIES = re.compile(r"^(973|76382|3626[abc]?|28621|3818|3819|3820|3815b?|3816c?|3817c?)$")


def _standard(slot: str, side: str) -> Mat | None:
    """Where the standard joints put a part of a slot, on a side."""
    if slot == "arms":
        return joint("arm_r" if side == "r" else "arm_l")
    if slot == "hands":
        return joint("hand_r" if side == "r" else "hand_l")
    if slot in ("head", "hips", "legs"):
        return joint("leg_r" if slot == "legs" else slot)
    return None


def placements(library: Library, catalogue: list[dict]) -> dict:
    """What the library's own assemblies say about the parts the standard
    joints do not fit — its complete battle droid, its skeleton, its
    torso with a hook for a left hand, its hips with a wooden leg:

    places: torso family ("*" for any torso) -> part family -> side ->
        twelve numbers, where the part sits relative to the torso in
        LDraw's axes, for every part not where the standard joint puts it;
    hands: arm family -> side -> where its hand sits relative to the arm,
        and {} for an arm that has none;
    bodies: torso family -> the parts the library puts with it, "" for a
        slot its complete figure leaves empty;
    extras: headwear extra -> [headwear, twelve numbers relative to the
        head], where an assembly puts a visor or a plume on its helmet."""
    minifig: dict[str, str] = {}
    side_of: dict[str, str] = {}
    for entry in catalogue:
        if real_part(entry):
            slot = slot_of(entry["name"], entry["category"])
            if slot:
                minifig[entry["id"]] = slot
                # A part's own side, from its geometry: a right leg is
                # modelled off to -X of its origin.
                centre = (entry["bounds_min"][0] + entry["bounds_max"][0]) / 2
                side_of[entry["id"]] = "r" if centre < -1 else ("l" if centre > 1 else "c")
    hips_at = joint("hips")
    seen: dict[tuple, Counter] = defaultdict(Counter)   # (torso, part, slot, side)
    hands_on: dict[str, dict[str, Counter]] = defaultdict(lambda: defaultdict(Counter))
    bare_arms: Counter = Counter()
    bodies: dict[str, dict[str, str]] = {}
    extras: dict[str, Counter] = defaultdict(Counter)
    for _name, placed in library_assemblies(library, minifig):
        slots = [minifig[p] for p, _m in placed]
        torsos = [(p, m) for (p, m), s in zip(placed, slots) if s == "torso"]
        hips = [m for (p, m), s in zip(placed, slots) if s == "hips"]
        hats = [m for (p, m), s in zip(placed, slots) if s == "headwear"]
        if len(torsos) > 1:
            continue
        if not torsos and not hips and len(hats) == 1:
            # A helmet with its visor or plume: the extra relative to the
            # helmet, which sits at the head's own origin.
            hat = [p for (p, _m), s in zip(placed, slots) if s == "headwear"][0]
            for (pid, m), slot in zip(placed, slots):
                if slot == "hat_extra":
                    extras[family(pid)][(hat, _key(mul(inv(hats[0]), m)))] += 1
            continue
        if torsos:
            body, anchor = family(torsos[0][0]), torsos[0][1]
        elif len(hips) == 1:
            body, anchor = "", mul(hips[0], inv(hips_at))
        else:
            continue
        back = inv(anchor)
        relative = []
        for (pid, m), slot in zip(placed, slots):
            here = unmirrored(mul(back, m), side_of.get(pid) == "c")
            x = here[0][3]
            side = "r" if x < -2 else ("l" if x > 2 else side_of.get(pid, "c"))
            relative.append((pid, slot, side, here))
            if slot in ("head", "arms", "hands", "hips", "legs"):
                seen[(body, family(pid), slot, side)][_key(here)] += 1
        # The hand an arm takes, relative to that arm, on its side.
        arms = [(p, s, m) for p, sl, s, m in relative if sl == "arms"]
        hands = [(p, s, m) for p, sl, s, m in relative if sl == "hands"]
        for arm, side, arm_at in arms:
            mine = [m for _p, s, m in hands if s == side]
            if mine:
                hands_on[family(arm)][side][_key(mul(inv(arm_at), mine[0]))] += 1
            else:
                bare_arms[family(arm)] += 1
        # What an odd body comes with. A complete figure (one with legs)
        # says which slots it leaves empty; an upper body only whether
        # its arms take hands.
        if body and not STANDARD_FAMILIES.match(body):
            found: dict[str, str] = {}
            for p, sl, s, _m in sorted(relative, key=lambda r: r[2] == "l"):
                if sl in ("head", "arms", "hands", "hips", "legs"):
                    found.setdefault(sl, p)
            whole = "legs" in found or "hips" in found
            mine = bodies.setdefault(body, {})
            for slot in ("head", "arms", "hands", "hips", "legs"):
                if slot in found:
                    mine.setdefault(slot, found[slot])
                elif whole and slot != "head" or slot == "hands" and "arms" in found:
                    mine.setdefault(slot, "")
    # The most common placement of each part, over every torso and then
    # with each torso, kept only where it says something the standard
    # joints and the any-torso entry do not.
    # "Any torso" is what the library does on the plain torso (or under
    # hips alone): a battle droid's legs hang from a droid's torso, and
    # are no guide to where they go on anybody else's.
    over_all: dict[tuple, Counter] = defaultdict(Counter)
    for (body, part, slot, side), counts in seen.items():
        if not body or STANDARD_FAMILIES.match(body):
            over_all[(part, slot, side)].update(counts)
    places: dict[str, dict[str, dict[str, list[float]]]] = {"*": {}}
    best_any: dict[tuple, tuple] = {}
    for (part, slot, side), counts in sorted(over_all.items()):
        best = counts.most_common(1)[0][0]
        best_any[(part, slot, side)] = best
        standard = _standard(slot, side)
        if STANDARD_FAMILIES.match(part):
            continue
        if standard is not None and _close(best, _key(standard)):
            continue
        places["*"].setdefault(part, {})[side] = _numbers(best)
    # A part the library only ever puts on an odd body (a skeleton's arm)
    # still says how it is drawn: on any other torso it is turned the way
    # the library turns it, at that torso's own joint.
    exotic: dict[tuple, Counter] = defaultdict(Counter)
    for (body, part, slot, side), counts in seen.items():
        if (part, slot, side) not in over_all:
            exotic[(part, slot, side)].update(counts)
    for (part, slot, side), counts in sorted(exotic.items()):
        standard = _standard(slot, side)
        if standard is None or STANDARD_FAMILIES.match(part):
            continue
        best = counts.most_common(1)[0][0]
        at = [list(row) for row in mat(_numbers(best))]
        for i in range(3):
            at[i][3] = standard[i][3]
        key = _key(at)
        best_any[(part, slot, side)] = key
        if not _close(key, _key(standard)):
            places["*"].setdefault(part, {})[side] = _numbers(key)
    for (body, part, slot, side), counts in sorted(seen.items()):
        if not body or STANDARD_FAMILIES.match(body):
            continue
        best = counts.most_common(1)[0][0]
        standard = _standard(slot, side)
        anywhere = best_any.get((part, slot, side))
        if anywhere is not None and _close(best, anywhere) \
                or anywhere is None and standard is not None and _close(best, _key(standard)):
            continue
        places.setdefault(body, {}).setdefault(part, {})[side] = _numbers(best)
    hand_places: dict[str, dict[str, list[float]]] = {}
    standard_hand = {s: _key(mul(inv(joint("arm_" + s)), joint("hand_" + s))) for s in "rl"}
    for arm, sides in hands_on.items():
        for side, counts in sides.items():
            best = counts.most_common(1)[0][0]
            if not STANDARD_FAMILIES.match(arm) and not _close(best, standard_hand[side]):
                hand_places.setdefault(arm, {})[side] = _numbers(best)
    for arm in bare_arms:
        if arm not in hands_on:
            hand_places[arm] = {}
    # A body's companions say something only where they are not the
    # parts every figure starts with.
    for body in list(bodies):
        mine = {slot: pid for slot, pid in bodies[body].items()
                if not (pid and STANDARD_FAMILIES.match(family(pid)))}
        if mine:
            bodies[body] = mine
        else:
            del bodies[body]
    on_hats: dict[str, list] = {}
    for part, counts in extras.items():
        (hat, key), _n = counts.most_common(1)[0]
        on_hats[part] = [hat, *_numbers(key)]
    hips, companions = _legs_and_hips(minifig, side_of)
    return {"places": places, "hands": hand_places, "bodies": bodies, "extras": on_hats,
            "leg_hips": hips, "legs_with": companions,
            "on_arms": _hands_on_arms(minifig, side_of)}


TYPE1_COLOUR = re.compile(r"^1\s+(\S+)\s+((?:\S+\s+){12})(.+?)\s*$")


def _own_lines(path: Path, help_lines: bool = False) -> list[tuple[str, str, Mat]]:
    """A library file's own type-1 lines, unopened: [(part, colour, at)].
    With help_lines, the ones its HELP lines write out instead — how the
    library says a part goes on another it does not include."""
    out = []
    for line in path.read_text(encoding="latin-1").splitlines():
        line = line.strip()
        if help_lines:
            found = re.match(r"^0\s+!HELP\s+(1\s.*)$", line)
            if not found:
                continue
            line = found.group(1)
        found = TYPE1_COLOUR.match(line)
        if not found:
            continue
        try:
            numbers = [float(v) for v in found.group(2).split()]
        except ValueError:
            continue
        ref = found.group(3).lower().replace("\\", "/").removesuffix(".dat")
        out.append((ref, found.group(1), mat(numbers)))
    return out


def _library_files() -> list[Path]:
    out: list[Path] = []
    for root in (LDRAW / "parts", LDRAW / "unofficial" / "parts"):
        if root.is_dir():
            out += sorted(root.glob("*.dat"))
    return out


def _legs_and_hips(minifig: dict[str, str], side_of: dict[str, str]) -> tuple[dict, dict]:
    """What the library's hips-and-legs assemblies (73200bpXX, 43743-f1)
    put together, read off their own lines:

    leg_hips: legs (a right leg, or legs of a piece) -> [hips, colour or
        -1 for the legs' own], where they are not the plain hips in the
        legs' colour: 3816cpx0's printed belt is 3815bpx0, 3816cp30's
        hips are reddish brown, springs 43741-f1 go into 43221;
    legs_with: legs -> [[part, twelve numbers relative to the torso]],
        the other legs parts a set of springs is put together with —
        43741-f1's 43220 under them, 43220's springs in it — where the
        assembly's legs are all of a piece rather than a right and a
        left."""
    hips_at = joint("hips")
    hips_of: dict[str, Counter] = defaultdict(Counter)
    with_of: dict[str, Counter] = defaultdict(Counter)
    for path in _library_files():
        lines = _own_lines(path)
        hips = [(p, c, m) for p, c, m in lines if minifig.get(p) == "hips"]
        legs = [(p, c, m) for p, c, m in lines if minifig.get(p) == "legs"]
        # Hips and legs alone, not a whole figure: the SMART Play torso's
        # figure has hips of its own with the medium legs.
        if len(hips) != 1 or not legs or any(minifig.get(p) == "torso" for p, _c, _m in lines):
            continue
        hip, hip_colour, hip_at = hips[0]
        for pid, colour, _m in legs:
            if side_of.get(pid) == "l":
                continue
            own = -1 if hip_colour in ("16", colour) else int(hip_colour)
            print_match = family(hip) != hip and hip[len(family(hip)):] == pid[len(family(pid)):]
            hips_of[pid][(hip, own, print_match)] += 1
        families = {family(p) for p, _c, _m in legs}
        if len(families) < 2 or any(side_of.get(p) != "c" for p, _c, _m in legs):
            continue
        back = inv(mul(hip_at, inv(hips_at)))
        for mine in families:
            others = tuple((p, tuple(_numbers(_key(mul(back, m)))))
                           for p, _c, m in legs if family(p) != mine)
            for pid, _c, _m in legs:
                if family(pid) == mine:
                    with_of[pid][others] += 1
    leg_hips: dict[str, list] = {}
    for pid, counts in hips_of.items():
        # The most usual, and of two as usual the one printed to match.
        (hip, own, _match), _n = max(counts.items(), key=lambda kv: (kv[1], kv[0][2]))
        if hip == "3815b" and own == -1:
            continue
        leg_hips[pid] = [hip, own]
    legs_with = {pid: [[p, list(n)] for p, n in counts.most_common(1)[0][0]]
                 for pid, counts in with_of.items()}
    return leg_hips, legs_with


def _hands_on_arms(minifig: dict[str, str], side_of: dict[str, str]) -> dict:
    """hand family -> [arm, twelve numbers relative to the arm]: a hand
    the library puts only on an arm of its own, by that arm's HELP line —
    6828.dat, the arm with a stump, says where the prosthetic hand 5059
    goes on it, which no assembly has, since it is optional."""
    out: dict[str, list] = {}
    for path in _library_files():
        arm = path.stem.lower()
        if minifig.get(arm) != "arms":
            continue
        for pid, _c, m in _own_lines(path, help_lines=True):
            # Not the plain hand, which goes on every arm.
            if minifig.get(pid) == "hands" and not STANDARD_FAMILIES.match(family(pid)):
                out.setdefault(family(pid), [arm, *_numbers(_key(m))])
    return out


# -- where a visor turns --------------------------------------------------------


def pivot_of(library: Library, pid: str) -> tuple[float, float] | None:
    """Where a visor turns on its helmet, or where a helmet takes one:
    (y, z) of the pins and dimples at its sides, which LDraw draws as
    small primitives along X at 12 LDU or more from the middle. None
    for a part with no such place, or several that do not agree.

    Measured, not assumed: the old visor 2447.dat turns at y 6.5 of the
    head, as the old helmet 2446.dat does, and real figures wear the
    pair at the head's own origin; the current 2447b.dat turns at its
    own origin, and the current helmets 3842a/b at y 5."""
    found: list[tuple[float, float, str]] = []
    _pins(library, pid + ".dat", IDENTITY, found, 0)
    # The bumps a visor clicks on with and the dimples a helmet takes
    # them in, where the part has them: the rings and cylinders round a
    # visor's hinge are decoration as often as not (2594a's sit 2.7 LDU
    # off the bump it turns on, which is where 6059's knight wears it).
    clicks = [(y, z) for y, z, name in found if "bump" in name or "sphe" in name]
    places = clicks or [(y, z) for y, z, _name in found]
    if len(places) < 2:
        return None
    (y, z), n = Counter(places).most_common(1)[0]
    if n < 2 or n / len(places) < 0.6:
        return None
    return (y + 0.0, z + 0.0)


def _pins(library: Library, name: str, at: Mat, out: list, depth: int) -> None:
    found = library.get(name)
    if found is None or depth > 8:
        return
    for command in found.commands:
        if not isinstance(command, SubfileRef):
            continue
        k = command.matrix
        here = mul(at, mat([k.x, k.y, k.z, k.a, k.b, k.c, k.d, k.e, k.f, k.g, k.h, k.i]))
        sub = library.get(command.filename)
        if sub is not None and sub.is_primitive:
            axis = (here[0][1], here[1][1], here[2][1])
            size = math.sqrt(sum(v * v for v in axis)) or 1.0
            if abs(axis[0]) / size > 0.95 and abs(here[0][3]) >= 12.0:
                out.append((round(here[1][3], 1), round(here[2][3], 1),
                            command.filename.split("/")[-1]))
            continue
        _pins(library, command.filename, here, out, depth + 1)


# -- where a head sits on its neck ---------------------------------------------


def neck_seat(library: Library, pid: str) -> float | None:
    """How far below a head's origin it sits on the shoulders: where its
    neck socket opens to take the torso's neck post (973.dat, a cylinder
    of radius 6 from y -12 to 0). 24 for the classic heads, whose origin
    is their top; 0 for most of the moulded ones (Yoda, the Muppets, the
    Simpsons), drawn from the neck up. The lowest opening of a cylinder
    on the head's axis of radius 3.5 to 6.5 (a baby's neck is 4), or
    None if it has none.

    A head drawn as a brick is — a Minion, a pencil top — is hollow
    underneath, its socket a tube up inside it, and its rim reaches below
    the socket's opening, past the post: it rests on the shoulders by
    that rim, the lowest edge of a cylinder on its axis wider than the
    post. Seated by its socket, a Minion sank 20 LDU over the torso."""
    found: list[float] = []
    rims: list[float] = []
    _sockets(library, pid + ".dat", IDENTITY, found, 0, rims)
    if not found:
        return None
    return max([max(found), *rims]) + 0.0


def _sockets(library: Library, name: str, at: Mat, out: list, depth: int,
             rims: list) -> None:
    found = library.get(name)
    if found is None or depth > 8:
        return
    for command in found.commands:
        if not isinstance(command, SubfileRef):
            continue
        k = command.matrix
        here = mul(at, mat([k.x, k.y, k.z, k.a, k.b, k.c, k.d, k.e, k.f, k.g, k.h, k.i]))
        sub = library.get(command.filename)
        if sub is not None and sub.is_primitive:
            stem = command.filename.split("/")[-1]
            if "cyl" not in stem:
                continue
            axis = (here[0][1], here[1][1], here[2][1])
            size = math.sqrt(sum(v * v for v in axis)) or 1.0
            radius = math.sqrt(here[0][0] ** 2 + here[1][0] ** 2 + here[2][0] ** 2)
            if abs(axis[1]) / size > 0.95 and abs(here[0][3]) < 0.6 \
                    and abs(here[2][3]) < 0.6:
                lowest = round(max(here[1][3], here[1][3] + axis[1]), 2)
                if 3.5 <= radius <= 6.5:
                    out.append(lowest)
                elif radius > 6.5:
                    rims.append(lowest)
            continue
        _sockets(library, command.filename, here, out, depth + 1, rims)


_REAL: dict[str, bool] = {}


def real_part_of(catalogue: list[dict], pid: str) -> bool:
    if not _REAL:
        for entry in catalogue:
            _REAL[entry["id"]] = real_part(entry)
    return _REAL.get(pid, False)


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
        # Everything the hands can be given: LDraw's accessories, and the
        # minifig-scale things filed elsewhere (a bicycle, a pot, a comb).
        if slot_of(entry["name"], entry["category"]) != "accessory" \
                or "Shortcut" in entry["kind"]:
            continue
        found = grip_of(library, entry["id"])
        # And how far along its bar the hand can go, where it is on one:
        # a spear's shaft slides through the hand to the ground, a
        # sword's hilt stops at the guard and the pommel.
        span = along_bar(library, entry["id"], *found)
        # Rounded, and without negative zeros, so a rerun diffs clean.
        grip = [round(v, 3) + 0.0 for v in (*found[0], *found[1], *(span or ()))]
        # What a part with no entry gets: held at its origin along Y.
        if grip != [0.0, 0.0, 0.0, 0.0, 1.0, 0.0]:
            held[entry["id"]] = grip

    # How far a neck accessory lifts the head: what real figures wearing
    # it do, where any does, and otherwise its collar off the geometry.
    # The collar alone agrees with real sets for about half the parts
    # both know (`measure`), so it is the fallback and not the rule.
    worn: dict[str, Counter] = defaultdict(Counter)
    # Which way round real figures wear it: every one of the 19 wearing
    # the arrow quiver has it turned to the back, which LDraw draws on
    # the chest.
    facing: dict[str, Counter] = defaultdict(Counter)
    for figure in figures(parts):
        torso = next(m for _p, m, _c, r in figure["parts"] if r == "torso")
        head = next(m for _p, m, _c, r in figure["parts"] if r == "head")
        lift = round(-24 - mul(inv(torso), head)[1][3])
        for pid, m, _c, role in figure["parts"]:
            if role == "neck":
                worn[pid][lift] += 1
                here = mul(inv(torso), m)
                facing[pid][180 if here[0][0] < -0.5 and here[2][2] < -0.5 else 0] += 1
    turned = {pid: n.most_common(1)[0][0] for pid, n in facing.items()
              if n.most_common(1)[0][0] != 0}
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
        "## from the business end towards the end of the handle; then, where the",
        "## grip is on a round bar, [from, to]: how far the bar runs each way of",
        "## the grip along that direction, which is as far as a hand slides on it.",
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

    found = placements(library, catalogue)
    # A head with no socket for the neck post, which the library's
    # figures only ever put on a body of their own: a battle droid's head
    # clips onto its torso's bar, and a plain torso has none.
    heads_on: dict[str, str] = {}
    bodies_of: dict[str, set] = defaultdict(set)
    for body, slots in found["bodies"].items():
        if slots.get("head"):
            bodies_of[family(slots["head"])].add(body)
    for head, bodies in sorted(bodies_of.items()):
        if len(bodies) == 1 and not STANDARD_FAMILIES.match(head) \
                and neck_seat(library, head) is None:
            heads_on[head] = next(iter(bodies))
    # Where each head's neck socket opens, where it is not where the
    # classic head's is.
    seats: dict[str, float] = {}
    for entry in usable:
        if "Shortcut" in entry["kind"] or family(entry["id"]) != entry["id"]:
            continue
        if slot_of(entry["name"], entry["category"]) != "head":
            continue
        seat = neck_seat(library, entry["id"])
        if seat is not None and abs(seat - 24.0) > 0.5:
            seats[entry["id"]] = seat
    # Where visors turn, and where the helmets they turn on take them.
    pivots: dict[str, list[float]] = {}
    for entry in usable:
        if "Shortcut" in entry["kind"] or family(entry["id"]) != entry["id"]:
            continue
        slot = slot_of(entry["name"], entry["category"])
        if slot == "hat_extra" or slot == "headwear" and "Helmet" in entry["name"]:
            pivot = pivot_of(library, entry["id"])
            if pivot is not None:
                pivots[entry["id"]] = list(pivot)
    table = [
        ("PLACES", found["places"],
         ["Torso family (\"*\" for any) -> part family -> side (r, l, c) -> where",
          "the part sits relative to the torso, twelve numbers in LDraw's axes as",
          "a type-1 line writes them: from the library's own assemblies, for every",
          "part the standard joints do not put where the library does."]),
        ("HANDS", found["hands"],
         ["Arm family -> side -> where its hand sits relative to the arm; {} for",
          "an arm with no hand to take (a wing, a clip, a hand moulded on)."]),
        ("BODIES", found["bodies"],
         ["Torso family -> the parts the library's complete figure puts with it,",
          "\"\" for a slot it leaves empty (a battle droid has no hips or hands)."]),
        ("EXTRAS", found["extras"],
         ["Headgear extra -> [the headgear an assembly puts it on, then twelve",
          "numbers: where it sits relative to the head]."]),
        ("SEATS", seats,
         ["Head -> LDU below its origin that its neck socket opens (neck_seat),",
          "for heads not drawn, as the classic ones are, from their top: 24",
          "everywhere else."]),
        ("PIVOTS", pivots,
         ["Helmet or headgear extra -> [y, z] in the head's frame where a visor",
          "turns on it (pivot_of): a visor drawn about its own pivot is put",
          "where its helmet's is."]),
        ("TURNED", turned,
         ["Neck, back or cape part -> degrees about Y that real figures wear it",
          "turned by, where most of them do."]),
        ("LEG_HIPS", found["leg_hips"],
         ["Legs -> [the hips the library's assemblies put them with, their",
          "colour or -1 for the legs' own], where not the plain hips in the",
          "legs' colour: a printed belt, springs' hips."]),
        ("LEGS_WITH", found["legs_with"],
         ["Legs -> [[part, twelve numbers relative to the torso]]: the other",
          "legs parts an assembly of legs in pieces puts with them (springs",
          "and the legs they go into)."]),
        ("ON_ARMS", found["on_arms"],
         ["Hand family -> [the arm the library puts it on, then twelve numbers:",
          "where it sits relative to that arm], from the arm's HELP lines."]),
        ("HEADS_ON", heads_on,
         ["Head family -> the torso family it clips onto: a head with no",
          "socket for a neck post, which the library only puts on its own body."]),
    ]
    for name, value, about in table:
        lines += ["## " + line for line in about]
        lines += [f"const {name} := {{"]
        lines += [f'\t"{k}": {json.dumps(v)},' for k, v in sorted(value.items())]
        lines += ["}", ""]
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines))
    print(f"wrote {OUT.relative_to(ROOT)}: {len(held)} grips, {len(lifts)} neck lifts, "
          f"{len(hands)} torso hand colours, {sum(len(v) for v in found['places'].values())} "
          f"placements, {len(found['hands'])} arms' hands, {len(found['bodies'])} bodies, "
          f"{len(found['extras'])} headgear extras, {len(seats)} head seats, {len(pivots)} pivots, "
          f"{len(turned)} turned, {len(found['leg_hips'])} legs' hips, "
          f"{len(found['legs_with'])} legs in pieces, {len(found['on_arms'])} hands on arms, "
          f"{len(heads_on)} heads on bodies")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", choices=["measure", "grips", "data"])
    args = parser.parse_args()
    return {"measure": measure, "grips": grips, "data": data}[args.what]()


if __name__ == "__main__":
    sys.exit(main())
