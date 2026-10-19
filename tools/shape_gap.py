#!/usr/bin/env python3
"""Whether a stop the exact shapes call real is in the parts themselves (G13, docs/MECHANISMS.md §21).

    tools/shape_gap.py [ROWS] [--cell=LDU]

ROWS is what ``grab_probe -- --only=gapjudge`` wrote (gapjudge.jsonl in
bench/results/grab13-2026-10-19 by default): for each stop, the moved part and
the part it met, where each stands, and how far their exact shapes overlap
with the moved one turned each way, half a degree at a time.

The exact shapes are BrickNet's: each part a few convex pieces. A convex piece
cannot follow a part into a hollow, so where a part is a shell (a buffer
beam's underside, a bogie's frame) a piece may fill space the part does not.
Here both parts are made solid from their own LDraw geometry
(tools/ldraw/occupancy.voxelise, the solid the covers are cut from, at a
finer cell), the moved one turned as the move turns it, and the two set
against each other: how thick their overlap is at each turn, beside the exact
shapes' depth. For the convex pieces that overlap a degree on, how much of
the space where they overlap each part's own solid fills.

A stop is the parts' own when their solids overlap by more than the 1 LDU a
build check allows; the judge's when only the pieces do.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from scipy.ndimage import distance_transform_edt
from scipy.spatial import ConvexHull, QhullError

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw import occupancy as occ  # noqa: E402
from ldraw.connectivity import ConnectorKind, Gender  # noqa: E402
from ldraw.connectivity import extract as extract_connections  # noqa: E402
from ldraw.geometry import flatten  # noqa: E402
from ldraw.library import Library  # noqa: E402

ROWS = Path("/mnt/Projects/brickworks/bench/results/grab13-2026-10-19/gapjudge.jsonl")
TAU = 1.0


def _transform(flat: list[float]) -> np.ndarray:
    """A 4 x 4 matrix from the probe's twelve numbers: basis x, y, z columns, then the origin."""
    m = np.eye(4)
    m[:3, 0] = flat[0:3]
    m[:3, 1] = flat[3:6]
    m[:3, 2] = flat[6:9]
    m[:3, 3] = flat[9:12]
    return m


class Solid:
    """A part's own solid, voxelised in the app's frame (x, -y, -z) at ``cell`` LDU, with its studs.

    voxelise leaves a stud out: drawn as an open barrel standing on the part's closed top, it winds
    the wrong way. A stud is solid plastic, and it is what meets a buffer beam's underside, so its
    barrel is put back here (a cylinder 12 LDU across and 4 tall on each male stud).
    """

    def __init__(self, library: Library, part: str, cell: float) -> None:
        mesh = flatten(library, part + ".dat")
        found = occ.voxelise(mesh, cell=cell)
        studs = [c for c in extract_connections(library, part + ".dat")
                 if c.kind is ConnectorKind.STUD and c.gender is Gender.MALE]
        # Room above the top for the studs.
        pad = int(np.ceil(5.0 / cell))
        grid = np.pad(found.to_grid().astype(bool), pad)
        self.cell = cell
        self.origin = np.array(found.origin) - pad
        centres = [(np.arange(grid.shape[n]) + self.origin[n] + 0.5) * cell for n in range(3)]
        gx, gy, gz = np.meshgrid(*centres, indexing="ij")
        for stud in studs:
            base = np.array([stud.position.x, -stud.position.y, -stud.position.z])
            axis = np.array([stud.axis.x, -stud.axis.y, -stud.axis.z])
            if np.linalg.norm(axis) < 1e-9:
                continue
            axis = axis / np.linalg.norm(axis)
            along = (gx - base[0]) * axis[0] + (gy - base[1]) * axis[1] + (gz - base[2]) * axis[2]
            radial = np.sqrt((gx - base[0] - along * axis[0]) ** 2 + (gy - base[1] - along * axis[1]) ** 2
                             + (gz - base[2] - along * axis[2]) ** 2)
            grid |= (along > 0.0) & (along < 4.0) & (radial < 6.0)
        self.grid = grid
        filled = np.argwhere(self.grid)
        self.centres = (filled + self.origin + 0.5) * cell

    def holds(self, points: np.ndarray) -> np.ndarray:
        """Which of ``points`` (in the part's frame) are inside its solid."""
        index = np.floor(points / self.cell).astype(np.int64) - self.origin
        inside = np.all((index >= 0) & (index < np.array(self.grid.shape)), axis=1)
        out = np.zeros(len(points), dtype=bool)
        held = index[inside]
        out[inside] = self.grid[held[:, 0], held[:, 1], held[:, 2]]
        return out


def overlap_thickness(mover: Solid, mover_at: np.ndarray, other: Solid, other_at: np.ndarray) -> tuple[float, float]:
    """How thick the two solids' overlap is, LDU (the widest ball inside it), and its volume, LDU³."""
    to_other = np.linalg.inv(other_at) @ mover_at
    points = mover.centres @ to_other[:3, :3].T + to_other[:3, 3]
    index = np.floor(points / other.cell).astype(np.int64) - other.origin
    inside = np.all((index >= 0) & (index < np.array(other.grid.shape)), axis=1)
    index = index[inside]
    index = index[other.grid[index[:, 0], index[:, 1], index[:, 2]]]
    if len(index) == 0:
        return 0.0, 0.0
    lo = index.min(axis=0)
    hi = index.max(axis=0) + 1
    mask = np.zeros(tuple(hi - lo + 2), dtype=bool)
    shifted = index - lo + 1
    mask[shifted[:, 0], shifted[:, 1], shifted[:, 2]] = True
    depth = distance_transform_edt(mask)
    thickness = 2.0 * float(depth.max()) * other.cell
    volume = float(mask.sum()) * other.cell ** 3
    return thickness, volume


def _hull(verts: list[list[float]]) -> np.ndarray | None:
    try:
        return ConvexHull(np.array(verts)).equations
    except QhullError:
        return None


def pieces_filled(piece: dict, mover: Solid, mover_at: np.ndarray, other: Solid, other_at: np.ndarray) -> dict:
    """Where a pair of convex pieces overlap, a degree on: its volume, and how much of it each part's own solid
    fills, and both at once. Sampled at the cells of the part met."""
    mine = _hull(piece["mover_verts"])
    theirs = _hull(piece["other_verts"])
    if mine is None or theirs is None:
        return {}
    to_mover = np.linalg.inv(mover_at) @ other_at
    verts = np.array(piece["other_verts"])
    lo = verts.min(axis=0)
    hi = verts.max(axis=0)
    cell = other.cell
    axes = [np.arange(np.floor(lo[k] / cell), np.ceil(hi[k] / cell)) * cell + cell / 2 for k in range(3)]
    grid = np.stack(np.meshgrid(*axes, indexing="ij"), axis=-1).reshape(-1, 3)
    in_theirs = np.all(grid @ theirs[:, :3].T + theirs[:, 3] <= 1e-6, axis=1)
    grid = grid[in_theirs]
    in_mover_frame = grid @ to_mover[:3, :3].T + to_mover[:3, 3]
    in_mine = np.all(in_mover_frame @ mine[:, :3].T + mine[:, 3] <= 1e-6, axis=1)
    both = grid[in_mine]
    if len(both) == 0:
        return {"volume": 0.0}
    real_other = other.holds(both)
    real_mover = mover.holds(in_mover_frame[in_mine])
    return {"volume": round(len(both) * cell ** 3, 1),
            "other_fills": round(float(real_other.mean()), 3),
            "mover_fills": round(float(real_mover.mean()), 3),
            "both_fill": round(float((real_other & real_mover).mean()), 3)}


def main(argv: list[str]) -> int:
    flags = {a.split("=", 1)[0]: a.split("=", 1)[1] for a in argv if a.startswith("--") and "=" in a}
    words = [a for a in argv if not a.startswith("--")]
    rows_path = Path(words[0]) if words else ROWS
    cell = float(flags.get("--cell", "0.5"))
    library = Library(ROOT / "vendor" / "ldraw")
    solids: dict[str, Solid] = {}
    out: list[dict] = []
    for line in rows_path.read_text().splitlines():
        if not line.strip():
            continue
        row = json.loads(line)
        turns = row.get("turns", [])
        if not turns:
            print(f"{row['set']}: no turns ({row.get('state')}, {row.get('mode')})")
            continue
        for part in (row["mover_part"], row["other_part"]):
            if part not in solids:
                solids[part] = Solid(library, part, cell)
        mover = solids[row["mover_part"]]
        other = solids[row["other_part"]]
        other_at = _transform(row["other_at"])
        report = {"set": row["set"], "pair": f"#{row['mover']} {row['mover_part']} / #{row['other']} {row['other_part']}",
                  "said": row.get("said", ""), "other_body": row.get("other_body", ""), "turns": []}
        first_exact: dict[int, float | None] = {1: None, -1: None}
        first_real: dict[int, float | None] = {1: None, -1: None}
        for turn in turns:
            deg = float(turn["deg"])
            thick, volume = overlap_thickness(mover, _transform(turn["at"]), other, other_at)
            entry = {"deg": deg, "exact": turn["depth"], "solid": round(thick, 2), "solid_volume": round(volume, 1)}
            if "pieces" in turn:
                entry["pieces"] = [dict(pieces_filled(p, mover, _transform(turn["at"]), other, other_at),
                                        depth=p["depth"], piece_mover=p["piece_mover"], piece_other=p["piece_other"])
                                   for p in turn["pieces"]]
            report["turns"].append(entry)
            way = 1 if deg > 0 else -1
            if deg != 0:
                was = first_exact[way]
                if turn["depth"] > TAU and (was is None or abs(deg) < abs(was)):
                    first_exact[way] = deg
                was = first_real[way]
                if thick > TAU and (was is None or abs(deg) < abs(was)):
                    first_real[way] = deg
        at_rest = next((t for t in report["turns"] if t["deg"] == 0), {})
        report["first_exact"] = first_exact
        report["first_solid"] = first_real
        out.append(report)
        print(f"\n{row['set']}: {report['pair']} ({row.get('said', '')})")
        print(f"  the part met is with: {row.get('other_body', '')[:160]}")
        print(f"  as built: exact {at_rest.get('exact')} LDU, solids {at_rest.get('solid')} LDU thick")
        print("  first over 1 LDU, by exact shapes: {:+}° / {:+}°; by their own solids: {} / {}".format(
            first_exact[1] if first_exact[1] is not None else 0, first_exact[-1] if first_exact[-1] is not None else 0,
            f"{first_real[1]:+}°" if first_real[1] is not None else "none to +30°",
            f"{first_real[-1]:+}°" if first_real[-1] is not None else "none to -30°"))
        for t in report["turns"]:
            if abs(t["deg"]) in (1.0, 2.0, 5.0, 10.0, 30.0):
                print(f"  {t['deg']:+5.1f}°: exact {t['exact']:.2f}, solids {t['solid']:.2f} LDU thick"
                      f" ({t['solid_volume']:.0f} LDU³)")
                for p in t.get("pieces", []):
                    print(f"         pieces {p['piece_mover']}/{p['piece_other']} overlap {p['depth']:.2f}:"
                          f" {p.get('volume', 0):.0f} LDU³, the part met fills {p.get('other_fills', 0):.0%},"
                          f" the moved part {p.get('mover_fills', 0):.0%}, both {p.get('both_fill', 0):.0%}")
    (rows_path.parent / "shape_gap.json").write_text(json.dumps(out, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
