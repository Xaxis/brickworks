"""Cap every stud that shows on a BrickBench build with a tile of its part's colour.

    BRICKNET_DATA=... VENV/bin/python -I tools/brickbench/skin.py IN.mpd OUT.ldr [--report OUT.json] [--up-only]

IN is a flat build (brickbench.py export's model.mpd), OUT the same build with
the tiles added, one line a tile after the build's own. A stud shows when no
joint uses it and no part's box lies over it along its axis (gap228's measure
in docs/BRICKBENCH.md); --up-only leaves the studs that point sideways. The
studs a part shows in one plane are covered by the largest tiles that fit
them (2 x 4 down to 1 x 1), turned with the part; a round part's by round
1 x 1 tiles, or one 2 x 2 round tile when all four of a round 2 x 2 show. A
tile that collides by BrickNet's colliders, or that BrickNet's graph does not
join to the build, is left off, so the build stays as valid as it was.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import defaultdict
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import flat  # noqa: E402
from brickagent import name as part_name  # noqa: E402

# Tiles by their studs along their own x and z.
TILES = {(1, 1): "3070b", (2, 1): "3069b", (3, 1): "63864", (4, 1): "2431",
         (2, 2): "3068b", (3, 2): "26603", (4, 2): "87079"}
ROUND_1, ROUND_2 = "98138", "14769"
ROUND_WORDS = ("round", "cone", "dome", "cylinder", "dish", "radar")
PITCH = 20.0


def showing(parts: list[flat.Placed], c: flat.Check, up_only: bool) -> list[flat.Stud]:
    boxes = [flat.world_box(p) for p in parts]
    out = []
    for i in range(len(parts)):
        for s in flat.studs(parts, i):
            if (i, s.index) in c.used:
                continue
            up = s.axis @ flat.UP
            if up < -0.01 or (up_only and up < 0.99):
                continue        # studs pointing down are under something by nature
            if not flat.covered_above(parts, s, boxes):
                out.append(s)
    return out


def _frame(parts: list[flat.Placed], s: flat.Stud) -> np.ndarray:
    from bricknet.graph import _part_info
    return _part_info(flat.pid(parts[s.part].stem)).frames[s.index]


def tiles_for(parts: list[flat.Placed], shown: list[flat.Stud]) -> list[flat.Placed]:
    """The tiles over each part's showing studs, grouped by plane."""
    groups: dict[tuple, list[flat.Stud]] = defaultdict(list)
    for s in shown:
        f = _frame(parts, s)
        key = (s.part, tuple(np.round(f[:3, :3], 3).reshape(-1)), round(float(f[:3, 1] @ f[:3, 3]), 1))
        groups[key].append(s)
    out = []
    for (i, _, _), group in groups.items():
        part = parts[i]
        f0 = _frame(parts, group[0])
        inv = np.linalg.inv(f0)
        at = {}
        for s in group:
            q = inv @ _frame(parts, s)[:, 3]
            at[(round(q[0], 1), round(q[2], 1))] = s
        round_part = any(w in part_name(part.stem).lower() for w in ROUND_WORDS)
        for stem, cx, cz, turn in _cover(set(at), round_part, part_name(part.stem).lower()):
            local = f0 @ flat.matrix(flat.rot_y(turn), (cx, 0, cz)) @ flat.matrix(at=(0, -8, 0))
            out.append(flat.Placed(stem, part.colour, part.m @ local, note=f"skin on #{i} {part.stem}"))
    return out


def _cover(points: set, round_part: bool, name: str) -> list[tuple[str, float, float, float]]:
    """Tiles over the points (stud places in their plane), largest first."""
    left = set(points)
    out = []
    if round_part:
        if "2x2" in name and len(left) == 4:
            xs, zs = sorted({p[0] for p in left}), sorted({p[1] for p in left})
            if len(xs) == 2 and len(zs) == 2 and xs[1] - xs[0] == PITCH and zs[1] - zs[0] == PITCH:
                return [(ROUND_2, sum(xs) / 2, sum(zs) / 2, 0.0)]
        return [(ROUND_1, x, z, 0.0) for x, z in sorted(left)]
    sizes = sorted({(a, b) for a, b in TILES} | {(b, a) for a, b in TILES}, key=lambda d: (-d[0] * d[1], -d[0]))
    for nx, nz in sizes:
        for x0, z0 in sorted(left):
            cells = [(round(x0 + PITCH * u, 1), round(z0 + PITCH * v, 1)) for u in range(nx) for v in range(nz)]
            if all(c in left for c in cells):
                left -= set(cells)
                cx, cz = x0 + PITCH * (nx - 1) / 2, z0 + PITCH * (nz - 1) / 2
                stem, turn = (TILES[(nx, nz)], 0.0) if (nx, nz) in TILES else (TILES[(nz, nx)], 90.0)
                out.append((stem, cx, cz, turn))
    return out


def skin(parts: list[flat.Placed], up_only: bool = False) -> tuple[list[flat.Placed], dict]:
    before = flat.check(parts)
    shown = showing(parts, before, up_only)
    tiles = tiles_for(parts, shown)
    base = len(parts)
    dropped = {"collides": 0, "loose": 0}
    while True:
        trial = parts + tiles
        c = flat.check(trial)
        bad = {j - base for pair in c.collisions for j in pair if j >= base}
        main = set(c.components[0]) if c.components else set()
        loose = {k for k in range(len(tiles)) if base + k not in main}
        if not bad and not loose:
            break
        dropped["collides"] += len(bad)
        dropped["loose"] += len(loose - bad)
        tiles = [t for k, t in enumerate(tiles) if k not in bad | loose]
    after = flat.check(parts + tiles)
    left = showing(parts + tiles, after, up_only)
    counts = defaultdict(int)
    for t in tiles:
        counts[t.stem] += 1
    report = {
        "parts_before": base, "parts_after": base + len(tiles),
        "studs_showing_before": len(shown),
        "studs_showing_up_before": sum(1 for s in shown if s.axis @ flat.UP > 0.99),
        "studs_showing_after": len(left),
        "tiles": len(tiles), "tiles_by_part": dict(sorted(counts.items())), "left_off": dropped,
        "check_before": flat.say_check(before, base), "check_after": flat.say_check(after, base + len(tiles)),
        "collisions_after": len(after.collisions), "pieces_after": len(after.components),
        "covered": [f"{parts[s.part].stem} colour {parts[s.part].colour}" for s in shown],
    }
    return parts + tiles, report


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("model", type=Path)
    ap.add_argument("out", type=Path)
    ap.add_argument("--report", type=Path)
    ap.add_argument("--up-only", action="store_true")
    args = ap.parse_args()
    built, report = skin(flat.read(args.model), args.up_only)
    flat.write(built, args.out)
    if args.report:
        args.report.write_text(json.dumps(report, indent=1) + "\n")
    print(f"{args.model}: {report['studs_showing_before']} studs showing ({report['studs_showing_up_before']} up), "
          f"{report['tiles']} tiles {report['tiles_by_part']}, left off {report['left_off']}, "
          f"{report['studs_showing_after']} showing after; {report['check_after']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
