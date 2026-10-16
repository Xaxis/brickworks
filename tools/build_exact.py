#!/usr/bin/env python3
"""Write each part's exact shape for the build check: BrickNet's convex colliders and connectors.

    tools/build_exact.py --bricknet DIR --colliders DIR          every part BrickNet has
    tools/build_exact.py --bricknet DIR --colliders DIR --only 3001 11211
    tools/build_exact.py ... --out DIR                           somewhere other than assets/generated

BrickBench judges a build with BrickNet's colliders (a part as a compound of
convex pieces, overlaps allowed up to 1 LDU) and its connector labels (which
stud meets which hole, within 3 LDU). Our check is a 2 LDU lattice that
forgives a stud and a joint, and it handed over designs whose side studs were
pushed into the next brick. So the check reads the same shapes, here turned
into one small file a shape: ``exact/<mesh hash>.bwx`` beside ``parts/``.

``--bricknet`` is the ``bricknet/_data/v1`` folder of the `bricknet` package
(MIT): ``labels.json.xz``, ``part_names.json``, ``part_aliases.json.xz``.
``--colliders`` is the folder of ``<stem>.cvx.obj`` files its
``python -m bricknet fetch-meshes`` downloads. Both are read as data, never
run. A part BrickNet calls an alias of another gets that part's shape moved
by the alias's matrix, as BrickNet itself does (``T_new = T_part @ T``).

Each convex piece's hull is worked out here (scipy's Qhull), so the app has
only to project: its vertices, its face normals and its edge directions,
which are every axis a separating-axis test needs.

The file, little-endian, all in the app's frame (LDraw's x, -y, -z):

    u32 magic "BWX1"   u16 version 1   u16 pieces   u16 connectors   u16 0
    f32 scale (LDU a vertex step)   f32 lo[3]   f32 hi[3]
    connectors: u8 kind, u8 sub, u8 polarity, u8 0, f32 length,
                f32 x axis[3], y axis[3], z axis[3], origin[3]
                (each axis the direction BrickNet's frame column is, in the
                app's frame: the connector points along minus its y axis)
    pieces:     u16 vertices, u16 normals, u16 edges,
                i16 vertex[3] * scale, i16 normal[3] / 32767, i16 edge[3] / 32767

kind: stud 0, hole 1, hinge 2, fixed 3, ball 4, axle 5 (BrickNet's Kind).
sub: stud 0, open 1, hole 2, tube 3, post 4, bar 5, clip 6, axle 7, cross 8,
pin 9, socket 10 (BrickNet's encoding); a numbered sub is 100 + its number.
polarity: in 0, on 1, none 255.
"""

from __future__ import annotations

import argparse
import json
import lzma
import math
import os
import struct
import sys
from multiprocessing import Pool
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = ROOT / "assets" / "generated"

MAGIC = 0x31585742  # "BWX1" little-endian
VERSION = 1
KINDS = {"stud": 0, "hole": 1, "hinge": 2, "fixed": 3, "ball": 4, "axle": 5}
NAMED_SUBS = {"stud": 0, "open": 1, "hole": 2, "tube": 3, "post": 4,
              "bar": 5, "clip": 6, "axle": 7, "cross": 8, "pin": 9, "socket": 10}
POLARITY = {"in": 0, "on": 1, None: 255}
# Normals and edges this close to parallel are one axis.
SAME = 1e-9


def sub_code(sub: str) -> int:
    if sub in NAMED_SUBS:
        return NAMED_SUBS[sub]
    number = int(sub)
    if not 0 <= number <= 155:
        raise ValueError(f"sub {sub} out of range")
    return 100 + number


def frame(row: list[float], kind: str) -> list[list[float]]:
    """A connector's 4x4 frame from its label row, as bricknet.data builds it."""
    px, py, pz = row[0], row[1], row[2]
    pitch = math.radians(row[3] if len(row) > 3 else 0.0)
    roll = math.radians(row[4] if len(row) > 4 else 0.0)
    yaw = math.radians(row[5] if kind == "fixed" and len(row) > 5 else 0.0)
    cx, cz, cy = math.cos(pitch), math.cos(roll), math.cos(yaw)
    sx, sz, sy = math.sin(pitch), math.sin(roll), math.sin(yaw)
    return [
        [cy * cz + sy * sx * sz, -cy * sz + sy * sx * cz, sy * cx, px],
        [cx * sz, cx * cz, -sx, py],
        [-sy * cz + cy * sx * sz, sy * sz + cy * sx * cz, cy * cx, pz],
        [0.0, 0.0, 0.0, 1.0],
    ]


def connectors_of(kinds: dict) -> list[tuple[str, str, str | None, float, list[list[float]]]]:
    """(kind, sub, polarity, length, frame) in BrickNet's canonical flat order."""
    out = []
    for kind in sorted(kinds):
        for sub in sorted(kinds[kind]):
            val = kinds[kind][sub]
            groups = [(p, val[p]) for p in sorted(val)] if isinstance(val, dict) else [(None, val)]
            for pol, rows in groups:
                for row in rows:
                    length = row[5] if kind == "axle" and len(row) > 5 else 0.0
                    out.append((kind, sub, pol, float(length), frame(row, kind)))
    return out


def matmul(a: list[list[float]], b: list[list[float]]) -> list[list[float]]:
    return [[sum(a[i][k] * b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]


def read_obj(path: Path) -> list[list[tuple[float, float, float]]]:
    """The convex pieces of a collider: each `o` group's vertices, as its faces use them.

    As BrickBench reads them (brickagent.physics._mesh): the file's vertices are
    one list, and a group's faces may use any of them. BrickNet's files share
    them, so a group's own `v` lines are only the vertices new to it: of 3033's
    785 groups 679 use one written under another, and read by its own lines its
    piece 783, a tilted slab 4.6 LDU thick, was a flat quad 0.7 LDU deep, so a
    flame 1.27 LDU into the 6 x 10 plate (model-047, 2026-10-15) was clear. A group
    with no faces is its own lines, as it was."""
    vertices: list[tuple[float, float, float]] = []
    own: list[list[int]] = []
    used: list[list[int]] = []
    for line in path.read_text().splitlines():
        if line.startswith("o "):
            own.append([])
            used.append([])
        elif line.startswith("v "):
            x, y, z = (float(v) for v in line.split()[1:4])
            vertices.append((x, y, z))
            if not own:
                own.append([])
                used.append([])
            own[-1].append(len(vertices) - 1)
        elif line.startswith("f ") and used:
            for field in line.split()[1:]:
                k = int(field.split("/")[0])
                used[-1].append(k - 1 if k > 0 else len(vertices) + k)
    pieces = []
    for mine, faces in zip(own, used):
        chosen = sorted(set(faces)) if faces else mine
        if chosen:
            pieces.append([vertices[i] for i in chosen])
    return pieces


def _add(axes: list, d, either_way: bool) -> None:
    """Append a unit direction unless it is one already there (or its opposite)."""
    import numpy as np

    length = float(np.linalg.norm(d))
    if length < 1e-9:
        return
    d = d / length
    for e in axes:
        dot = float(d @ e)
        if dot > 1 - SAME or (either_way and dot < -1 + SAME):
            return
    axes.append(d)


def _flat(pts):
    """A piece with no volume, as Bullet takes it: a point, a segment or a polygon.

    Its axes are those of the polygon as a prism of no thickness: the plane's
    normal and each side's, and its edges with the normal among them."""
    import numpy as np
    from scipy.spatial import ConvexHull, QhullError

    middle = pts.mean(0)
    _, s, vt = np.linalg.svd(pts - middle)
    rank = int((s > 1e-7 * max(float(s[0]), 1e-12)).sum()) if len(s) else 0
    normals: list = []
    edges: list = []
    if rank == 0:
        return pts[:1], normals, edges
    if rank == 1:
        ends = (pts - middle) @ vt[0]
        keep = [int(ends.argmin()), int(ends.argmax())]
        _add(edges, pts[keep[1]] - pts[keep[0]], True)
        return pts[keep], normals, edges
    n = np.cross(vt[0], vt[1])
    flat2 = np.stack(((pts - middle) @ vt[0], (pts - middle) @ vt[1]), axis=1)
    try:
        order = ConvexHull(flat2).vertices
    except QhullError:
        order = np.arange(len(pts))
    ring = pts[order]
    _add(normals, n, True)
    _add(edges, n, True)
    for k in range(len(ring)):
        e = ring[(k + 1) % len(ring)] - ring[k]
        _add(edges, e, True)
        _add(normals, np.cross(n, e), True)
    return ring, normals, edges


def hull(points):
    """Hull vertices, unit face normals and unit edge directions of one convex piece."""
    import numpy as np
    from scipy.spatial import ConvexHull, QhullError

    pts = np.unique(np.round(np.asarray(points, dtype=float), 9), axis=0)
    if len(pts) < 4:
        return _flat(pts)
    try:
        h = ConvexHull(pts)
    except QhullError:
        return _flat(pts)
    if h.volume < 1e-9:
        return _flat(pts)
    normals: list = []
    for eq in h.equations:
        n = eq[:3] / np.linalg.norm(eq[:3])
        if not any(float(n @ m) > 1 - SAME for m in normals):
            normals.append(n)
    facets_at: dict = {}
    for f, simplex in enumerate(h.simplices):
        for a, b in ((0, 1), (1, 2), (2, 0)):
            key = tuple(sorted((int(simplex[a]), int(simplex[b]))))
            facets_at.setdefault(key, []).append(f)
    edges: list = []
    for (a, b), facets in facets_at.items():
        if len(facets) == 2:
            na, nb = h.equations[facets[0], :3], h.equations[facets[1], :3]
            if float(na @ nb) > 1 - SAME:
                continue  # the diagonal of a flat face, not an edge of the shape
        d = pts[b] - pts[a]
        length = float(np.linalg.norm(d))
        if length < 1e-9:
            continue
        d = d / length
        if not any(abs(float(d @ e)) > 1 - SAME for e in edges):
            edges.append(d)
    return pts[h.vertices], normals, edges


def godot(v):
    """LDraw's frame to the app's: x, -y, -z."""
    return (v[0], -v[1], -v[2])


def encode(connectors, pieces) -> bytes:
    """One shape's file. Everything given in LDraw's frame; written in the app's."""
    shaped = [hull(p) for p in pieces]
    every = [godot(v) for verts, _, _ in shaped for v in verts]
    lo = [min(v[i] for v in every) for i in range(3)] if every else [0.0] * 3
    hi = [max(v[i] for v in every) for i in range(3)] if every else [0.0] * 3
    reach = max([abs(x) for x in lo + hi] + [1.0])
    scale = 1.0 / 64.0
    while reach / scale > 32000:
        scale *= 2.0
    out = bytearray(struct.pack("<IHHHH", MAGIC, VERSION, len(shaped), len(connectors), 0))
    out += struct.pack("<7f", scale, *lo, *hi)
    for kind, sub, pol, length, f in connectors:
        # Each of the frame's axes as the same direction in the app's frame, so
        # BrickNet's rules, which are dot products of them, read unchanged.
        axes = [godot((f[0][c], f[1][c], f[2][c])) for c in range(3)]
        origin = godot((f[0][3], f[1][3], f[2][3]))
        out += struct.pack("<BBBBf", KINDS[kind], sub_code(sub), POLARITY[pol], 0, length)
        for a in axes:
            out += struct.pack("<3f", *a)
        out += struct.pack("<3f", *origin)
    for verts, normals, edges in shaped:
        out += struct.pack("<HHH", len(verts), len(normals), len(edges))
        for v in verts:
            g = godot(v)
            out += struct.pack("<3h", *(int(round(c / scale)) for c in g))
        for n in list(normals) + list(edges):
            g = godot(n)
            out += struct.pack("<3h", *(int(round(max(-1.0, min(1.0, c)) * 32767)) for c in g))
    return bytes(out)


def decode(data: bytes) -> dict:
    """A shape's file read back: {scale, lo, hi, connectors: [...], pieces: [(vertices, normals, edges)]}."""
    magic, version, piece_count, connector_count, _ = struct.unpack_from("<IHHHH", data, 0)
    if magic != MAGIC or version != VERSION:
        raise ValueError("not a BWX1 shape")
    scale, *bounds = struct.unpack_from("<7f", data, 12)
    at = 40
    connectors = []
    for _ in range(connector_count):
        kind, sub, pol, _, length = struct.unpack_from("<BBBBf", data, at)
        values = struct.unpack_from("<12f", data, at + 8)
        connectors.append({"kind": kind, "sub": sub, "polarity": pol, "length": length,
                           "x": values[0:3], "y": values[3:6], "z": values[6:9], "origin": values[9:12]})
        at += 56
    pieces = []
    for _ in range(piece_count):
        nv, nn, ne = struct.unpack_from("<HHH", data, at)
        at += 6
        raw = struct.unpack_from(f"<{3 * (nv + nn + ne)}h", data, at)
        at += 6 * (nv + nn + ne)
        verts = [tuple(c * scale for c in raw[3 * i:3 * i + 3]) for i in range(nv)]
        rest = [tuple(c / 32767 for c in raw[3 * i:3 * i + 3]) for i in range(nv, nv + nn + ne)]
        pieces.append((verts, rest[:nn], rest[nn:]))
    if at != len(data):
        raise ValueError(f"{len(data) - at} bytes left over")
    return {"scale": scale, "lo": tuple(bounds[:3]), "hi": tuple(bounds[3:]),
            "connectors": connectors, "pieces": pieces}


_STATE: dict = {}


def _init(bricknet: str, colliders: str) -> None:
    data = Path(bricknet)
    _STATE["labels"] = json.loads(lzma.decompress((data / "labels.json.xz").read_bytes()))
    _STATE["names"] = json.loads((data / "part_names.json").read_text())
    aliases = {}
    for row in json.loads(lzma.decompress((data / "part_aliases.json.xz").read_bytes()))["rows"]:
        v = row["final_matrix_3x4"]  # LDraw line-type-1 order: x y z a b c d e f g h i
        m = [[v[3], v[4], v[5], v[0]], [v[6], v[7], v[8], v[1]], [v[9], v[10], v[11], v[2]], [0, 0, 0, 1]]
        aliases[row["src"]] = (row["dst"], m)
    _STATE["aliases"] = aliases
    _STATE["colliders"] = Path(colliders)


def source_of(part_id: str):
    """(BrickNet stem, wrapper matrix or None) for one of our part ids, or None."""
    names, aliases = _STATE["names"], _STATE["aliases"]
    if part_id in names:
        return part_id, None
    if part_id in aliases and aliases[part_id][0] in names:
        return aliases[part_id]
    return None


def convert(job: tuple[str, str, str]) -> tuple[str, str, int]:
    """(part id, mesh hash, out dir) -> (hash, what happened, bytes written)."""
    part_id, mesh, out_dir = job
    found = source_of(part_id)
    if found is None:
        return mesh, "not in BrickNet", 0
    stem, wrap = found
    kinds = _STATE["labels"].get(stem + ".dat", {})
    connectors = connectors_of(kinds)
    path = _STATE["colliders"] / f"{stem}.cvx.obj"
    pieces = read_obj(path) if path.exists() else []
    if wrap is not None:
        connectors = [(k, s, p, ln, matmul(wrap, f)) for k, s, p, ln, f in connectors]
        pieces = [[tuple(sum(wrap[i][k] * (v[k] if k < 3 else 1.0) for k in range(4)) for i in range(3))
                   for v in piece] for piece in pieces]
    try:
        data = encode(connectors, pieces)
    except Exception as exc:  # one odd collider is no reason to stop the rest
        return mesh, f"failed: {exc}", 0
    (Path(out_dir) / f"{mesh}.bwx").write_bytes(data)
    return mesh, "written" if pieces else "connectors only", len(data)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--bricknet", required=True, help="bricknet/_data/v1 of the bricknet package")
    parser.add_argument("--colliders", required=True, help="the folder of <stem>.cvx.obj files")
    parser.add_argument("--catalogue", default=str(DEFAULT_OUT / "catalogue.json"))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--only", nargs="*", default=None)
    parser.add_argument("--only-from", default=None, help="a file of part ids, one a line")
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    args = parser.parse_args()
    if args.only_from:
        args.only = (args.only or []) + [w.strip() for w in Path(args.only_from).read_text().split() if w.strip()]

    catalogue = json.loads(Path(args.catalogue).read_text())
    out_dir = Path(args.out) / "exact"
    out_dir.mkdir(parents=True, exist_ok=True)
    _init(args.bricknet, args.colliders)
    jobs, seen = [], set()
    wanted = set(args.only) if args.only else None
    # A direct match before an alias: two ids sharing one mesh take the one
    # BrickNet names itself.
    def aliased(entry: dict) -> bool:
        source = source_of(entry["id"])
        return source is None or source[1] is not None

    entries = sorted(catalogue["parts"], key=aliased)
    for entry in entries:
        if wanted is not None and entry["id"] not in wanted:
            continue
        if not entry.get("mesh") or entry["mesh"] in seen or source_of(entry["id"]) is None:
            continue
        seen.add(entry["mesh"])
        jobs.append((entry["id"], entry["mesh"], str(out_dir)))
    counts: dict[str, int] = {}
    total = 0
    with Pool(max(1, args.jobs), initializer=_init, initargs=(args.bricknet, args.colliders)) as pool:
        for n, (_mesh, said, size) in enumerate(pool.imap_unordered(convert, jobs, chunksize=16), 1):
            key = said.split(":")[0]
            counts[key] = counts.get(key, 0) + 1
            total += size
            if n % 1000 == 0:
                print(f"  {n} of {len(jobs)}", file=sys.stderr)
    print(f"{len(jobs)} shapes: " + ", ".join(f"{v} {k}" for k, v in sorted(counts.items()))
          + f"; {total / 1e6:.1f} MB in {out_dir}")
    return 0 if counts.get("failed", 0) == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
