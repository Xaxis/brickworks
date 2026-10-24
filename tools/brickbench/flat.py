"""A flat LDraw build read and checked by BrickNet's own rules, for editing a
BrickBench build by hand or by script.

Runs in the venv that has brickagent and bricknet (BRICKNET_DATA set), with
`python -I`: the BrickBench recipe in .claude/skills/verify/features/assistant.md
sets that up. A build is the `model.mpd` brickbench.py's export writes: one
file, one line a part. Studs, holes and what joins what are BrickNet's
(bricknet.graph), collisions its convex colliders at verify.py's 1 LDU, and
boxes brickagent's LDraw bounds, so an edit checked here is checked as
verify.py will check it.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from itertools import product
from pathlib import Path

import numpy as np

from brickagent import catalog
from bricknet.collision import colliding_pairs
from bricknet.data import load_catalog
from bricknet.graph import _part_info, parse_ldr

UP = np.array([0.0, -1.0, 0.0])     # LDraw's up


@dataclass
class Placed:
    stem: str
    colour: int
    m: np.ndarray                    # 4 x 4, LDraw axes
    note: str = ""                   # what an edit added it for; "" for the build's own

    def line(self) -> str:
        r, t = self.m[:3, :3], self.m[:3, 3]
        nums = [*t, *r.reshape(-1)]
        return f"1 {self.colour} " + " ".join(_num(v) for v in nums) + f" {self.stem}.dat"


def _num(v: float) -> str:
    v = round(float(v), 6)
    if v == 0:
        return "0"
    return str(int(v)) if v == int(v) else f"{v:.6f}".rstrip("0").rstrip(".")


def matrix(rot=None, at=(0.0, 0.0, 0.0)) -> np.ndarray:
    m = np.eye(4)
    if rot is not None:
        m[:3, :3] = np.asarray(rot, dtype=float).reshape(3, 3)
    m[:3, 3] = at
    return m


def rot_y(deg: float) -> np.ndarray:
    a = math.radians(deg)
    c, s = round(math.cos(a), 12), round(math.sin(a), 12)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def rot_x(deg: float) -> np.ndarray:
    a = math.radians(deg)
    c, s = round(math.cos(a), 12), round(math.sin(a), 12)
    return np.array([[1, 0, 0], [0, c, -s], [0, s, c]])


def rot_z(deg: float) -> np.ndarray:
    a = math.radians(deg)
    c, s = round(math.cos(a), 12), round(math.sin(a), 12)
    return np.array([[c, -s, 0], [s, c, 0], [0, 0, 1]])


def read(path: Path) -> list[Placed]:
    out = []
    for raw in Path(path).read_text(errors="replace").splitlines():
        bits = raw.split()
        if len(bits) >= 15 and bits[0] == "1":
            nums = [float(v) for v in bits[2:14]]
            m = matrix(np.array(nums[3:12]).reshape(3, 3), nums[0:3])
            out.append(Placed(bits[14].rsplit(".", 1)[0].lower(), int(bits[1]), m))
    return out


def text(parts: list[Placed], name: str = "model.ldr") -> str:
    head = [f"0 FILE {name}", "0 Model", f"0 Name: {name}", "0 Author: Brickworks"]
    return "\n".join(head + [p.line() for p in parts]) + "\n0 NOFILE\n"


def write(parts: list[Placed], path: Path) -> None:
    Path(path).write_text(text(parts))


def pid(stem: str) -> int:
    return load_catalog().stem_to_id[stem]


def box(stem: str) -> tuple[np.ndarray, np.ndarray]:
    """The part's LDraw box, part-local: (low, high)."""
    lo, hi = catalog._load("bounds.json.xz")[stem]
    return np.array(lo, dtype=float), np.array(hi, dtype=float)


def world_box(p: Placed) -> tuple[np.ndarray, np.ndarray]:
    lo, hi = box(p.stem)
    pts = np.array(list(product(*zip(lo, hi))))
    w = pts @ p.m[:3, :3].T + p.m[:3, 3]
    return w.min(0), w.max(0)


@dataclass
class Stud:
    part: int
    index: int                       # BrickNet's flat connector index on the part
    local: np.ndarray                # part-local position
    world: np.ndarray
    axis: np.ndarray                 # outward, world


def studs(parts: list[Placed], i: int) -> list[Stud]:
    info = _part_info(pid(parts[i].stem))
    out = []
    for k, (conn, frame) in enumerate(zip(info.conns, info.frames)):
        if conn[0] != "stud":
            continue
        w = parts[i].m @ frame
        out.append(Stud(i, k, frame[:3, 3].copy(), w[:3, 3].copy(), -w[:3, 1] / np.linalg.norm(w[:3, 1])))
    return out


def connector(stem: str, kind: str, sub: str | None = None, n: int = 0) -> int:
    """The flat index of a part's n-th connector of a kind (stud, hole, hinge, ball, axle) and subtype."""
    found = [k for k, c in enumerate(_part_info(pid(stem)).conns) if c[0] == kind and (sub is None or c[1] == sub)]
    return found[n]


def frame(p: Placed, k: int) -> np.ndarray:
    """Connector k of a placed part, in world LDraw axes."""
    return p.m @ _part_info(pid(p.stem)).frames[k]


def mate(onto: np.ndarray, stem: str, k: int, colour: int, yaw: float = 0.0, flip: bool = False,
         turn: np.ndarray | None = None, note: str = "", slide: float = 0.0) -> Placed:
    """A new part placed so its connector k sits in the world frame `onto` (another part's
    connector), as brickagent's placement() mates them: turned `yaw` degrees about the
    joint's axis, flipped end for end on a hinge, or any `turn` (3 x 3) on a ball; an axle
    joint slid `slide` LDU along its axis."""
    r = rot_y(yaw) if turn is None else turn
    if flip:
        r = r @ rot_x(180)
    src = _part_info(pid(stem)).frames[k]
    return Placed(stem, colour, onto @ matrix(at=(0, slide, 0)) @ matrix(r) @ np.linalg.inv(src), note)


@dataclass
class Check:
    collisions: list[tuple[int, int]]
    components: list[tuple[int, ...]]
    used: set[tuple[int, int]] = field(default_factory=set)   # (part, connector) in a joint
    edges: int = 0

    def piece_of(self, i: int) -> int:
        for n, c in enumerate(self.components):
            if i in c:
                return n
        return -1


def check(parts: list[Placed]) -> Check:
    """Collisions and BrickNet's joints, as verify.py finds them."""
    ids = [pid(p.stem) for p in parts]
    mats = np.stack([p.m for p in parts])
    hits = [tuple(sorted(map(int, pair))) for pair in colliding_pairs(ids, mats)]
    graph = parse_ldr(text(parts))
    used = set()
    for e in graph.edges:
        used.add((int(e["a"]), int(e["a_conn"])))
        used.add((int(e["b"]), int(e["b_conn"])))
    comps = sorted((tuple(sorted(map(int, c))) for c in graph.components), key=len, reverse=True)
    return Check(hits, comps, used, len(graph.edges))


def covered_above(parts: list[Placed], s: Stud, boxes=None, skip=()) -> bool:
    """Does any other part's box lie over the stud along its axis (gap228's 'showing' test)?"""
    boxes = boxes or [world_box(p) for p in parts]
    for j, (lo, hi) in enumerate(boxes):
        if j == s.part or j in skip:
            continue
        if _ray_hits(lo, hi, s.world + s.axis * 0.5, s.axis):
            return True
    return False


def _ray_hits(lo, hi, origin, way, length=1e5) -> bool:
    t0, t1 = 0.0, length
    for k in range(3):
        if abs(way[k]) < 1e-9:
            if origin[k] <= lo[k] + 0.5 or origin[k] >= hi[k] - 0.5:
                return False
            continue
        a, b = (lo[k] - origin[k]) / way[k], (hi[k] - origin[k]) / way[k]
        if a > b:
            a, b = b, a
        t0, t1 = max(t0, a), min(t1, b)
        if t0 > t1:
            return False
    return True


def say_check(c: Check, n: int) -> str:
    return (f"{n} parts, {len(c.collisions)} collisions, {len(c.components)} pieces "
            f"{[len(x) for x in c.components][:6]}, {c.edges} joints")
