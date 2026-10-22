#!/usr/bin/env python3
"""Brickify against outside models and a plain greedy stack: how like the model, how sound, how dear.

    python3 tools/bench/brickify_bench.py jobs --models DIR --out JOBS.json [--sizes 24,48]
    heavy godot --headless --path . --script src/dev/brickify_bench.gd -- JOBS.json OUT
    heavy PY tools/bench/brickify_bench.py measure OUT
    heavy PY tools/bench/brickify_bench.py faces OUT [--only a,b]
    PY tools/bench/brickify_bench.py pictures OUT --into docs/brickify [--only a,b]
    python3 tools/bench/brickify_bench.py report OUT

PY is a Python with numpy, scipy, trimesh, embreex and Pillow:
`uv venv V && VIRTUAL_ENV=V uv pip install numpy scipy trimesh embreex pillow`.
`jobs` and `report` need none of them.

**jobs** reads DIR/<slug>/LICENCE.json for each model (its "files"[0] the
model, "up" its up axis) and writes the list brickify_bench.gd lays.

**measure** scores each build against the model it came from, both in the
build's own LDU (src/dev/brickify_bench.gd writes the frame):

- *Likeness.* Both are ray cast from 14 directions (the six faces and the
  eight corners), orthographic, 320 x 320 over the model's bounding sphere.
  Silhouette IoU is the mean over the views of the pixels both cover over the
  pixels either covers. The points the rays hit are each one's visible
  surface; the Chamfer distance is the mean of the two mean nearest-point
  distances, Hausdorff the larger of the two largest, and F@0.5 the harmonic
  mean of the shares of each within half a stud of the other. In studs, so
  the two sizes compare as builds; and per cent of the longest side, so they
  compare as likenesses.
- *Colour.* For a model with colours of its own: each visible point of the
  model against the brick nearest it, ΔE in Oklab (x100) and CIEDE2000; and
  the floor, the model's colour against the nearest colour in Brickify's
  palette, which no layout can beat.
- *Bond.* From the parts' boxes on the stud and plate grid: the pairs of
  parts side by side in a course, and how many of those pairs a third part
  joins from above or below (a seam bridged, as STABLE and Legolization
  count); and the parts whose removal parts the model (articulation points of
  the graph of parts on parts), Legolization's weak points.
- *Parts.* How many are 1 x 1 in plan.

**faces** sorts the model's visible points by which way their surface faces (up, up and
out, out, down and out, down) and gives each arm's normal error and distance for each: where
the error is, and what a surface part can reach. The steep ("out") faces are split again by
whether the nearest part of the build lies on its side; and seen from the four sides alone,
the Hausdorff95 of the model's points and the build's ("sides"). Of the points leaning 10 to
40 degrees from all six axes, the share whose nearest part face is within 10 degrees of the
model's ("matched": the lean laid); and the error and distance over every face ("every").

**pictures** draws the model and each build from the same corner, lit the
same, and lays them side by side, one file a model and size.

**report** writes the tables docs/BRICKIFY.md quotes.

Downloaded models are data: read, never run. Everything a run makes stays in
OUT (a scratch folder); the pictures go where --into says.
"""

from __future__ import annotations

import argparse
import json
import math
import statistics
import sys
from pathlib import Path

ARMS = ("smooth", "upright", "plain", "greedy", "outside")
VIEWS_RES = 320
HALF_STUD = 10.0  # LDU
STUD = 20.0
# A neutral of the model's (a grey, a black, a white: CIELAB chroma under this) laid in a colour
# of chroma this or more has turned chromatic: a dark grey laid Reddish Brown (36.8), black
# hair laid Dark Blue (27.4). Black itself (9.0) and the sand colours (15 to 16) do not count.
NEUTRAL_CHROMA = 5.0
CHROMATIC = 20.0


# -- prepare and jobs -----------------------------------------------------------


def _up_of(info: dict) -> str:
    said = str(info.get("up_axis", info.get("up", "+Y"))).upper()
    for axis in ("+Y", "+Z", "-Z", "+X", "-X", "-Y"):
        if said.startswith(axis):
            return axis
    return "+Y"


def _glb_without(src: Path, dst: Path, word: str) -> int:
    """A GLB with every node whose name holds `word` taken out of its scenes and parents."""
    import struct

    data = src.read_bytes()
    length = struct.unpack_from("<I", data, 12)[0]
    doc = json.loads(data[20:20 + length])
    rest = data[20 + length:]
    gone = {n for n, node in enumerate(doc.get("nodes", [])) if word.lower() in str(node.get("name", "")).lower()}
    for scene in doc.get("scenes", []):
        scene["nodes"] = [n for n in scene.get("nodes", []) if n not in gone]
    for node in doc.get("nodes", []):
        if "children" in node:
            node["children"] = [n for n in node["children"] if n not in gone]
    text = json.dumps(doc).encode()
    text += b" " * (-len(text) % 4)
    body = struct.pack("<II", len(text), 0x4E4F534A) + text + rest
    dst.write_bytes(b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body)
    return len(gone)


def _vertex_colours(geometry):
    """A mesh's colour at each vertex: its texture there, else its vertex or material colour."""
    import numpy as np
    import trimesh

    visual = geometry.visual
    n = len(geometry.vertices)
    try:
        if visual.kind == "texture" and visual.uv is not None:
            material = visual.material
            image = getattr(material, "baseColorTexture", None) or getattr(material, "image", None)
            if image is not None:
                colours = trimesh.visual.color.uv_to_color(visual.uv, image)
            else:
                colours = visual.to_color().vertex_colors
        else:
            colours = visual.vertex_colors
        colours = np.asarray(colours)
        if colours.shape[0] != n:
            raise ValueError("colours do not match the vertices")
        return colours
    except Exception:
        material = getattr(visual, "material", None)
        main = getattr(material, "main_color", None) if material is not None else None
        return np.tile(np.asarray(main if main is not None else [200, 200, 200, 255]), (n, 1))


def do_prepare(args: argparse.Namespace) -> int:
    """Each model as Brickify reads it, and as an OBJ with vertex colours for an outside tool.

    PLY becomes OBJ (Brickify reads no PLY). An OBJ that names no material but
    comes with one picture is given a material naming it, as a person would
    pick both. A node named in --drop (slug:word) is taken out of a GLB."""
    import shutil

    import trimesh

    models, into = Path(args.models), Path(args.into)
    drops = dict(d.split(":", 1) for d in args.drop.split(",") if ":" in d)
    jobs = []
    for licence in sorted(models.glob("*/LICENCE.json")):
        info = json.loads(licence.read_text())
        slug = licence.parent.name
        main = licence.parent / info["files"][0]
        out = into / slug
        out.mkdir(parents=True, exist_ok=True)
        note = ""
        kind = main.suffix.lower()
        if kind == ".ply":
            mesh = trimesh.load(main, force="mesh", process=False)
            target = out / (main.stem + ".obj")
            target.write_text(trimesh.exchange.obj.export_obj(mesh, include_normals=False, include_color=False,
                                                              include_texture=False))
            note = "PLY written as OBJ"
        elif slug in drops and kind == ".glb":
            target = out / main.name
            note = f"{_glb_without(main, target, drops[slug])} node(s) named '{drops[slug]}' left out"
        else:
            for name in info["files"]:
                source = licence.parent / name
                if source.is_file():
                    (out / name).parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, out / name)
            target = out / main.name
            text = target.read_text(errors="replace") if kind == ".obj" else ""
            pictures = [n for n in info["files"] if Path(n).suffix.lower() in (".png", ".jpg", ".jpeg")]
            if kind == ".obj" and "mtllib" not in text and len(pictures) == 1:
                (out / "picked.mtl").write_text(f"newmtl picked\nKd 1 1 1\nmap_Kd {pictures[0]}\n")
                target.write_text("mtllib picked.mtl\nusemtl picked\n" + text)
                note = f"given a material naming {pictures[0]}"
        # The outside tool's copy: one mesh, colours at the vertices.
        scene = trimesh.load(target, force="scene", process=False)
        parts = []
        for geometry_name, geometry in scene.geometry.items():
            if not isinstance(geometry, trimesh.Trimesh):
                continue
            g = trimesh.Trimesh(vertices=geometry.vertices.copy(), faces=geometry.faces.copy(), process=False)
            g.visual = trimesh.visual.ColorVisuals(g, vertex_colors=_vertex_colours(geometry))
            for node in scene.graph.geometry_nodes.get(geometry_name, []):
                placed = g.copy()
                placed.apply_transform(scene.graph.get(node)[0])
                parts.append(placed)
        whole = trimesh.util.concatenate(parts)
        (out / "outside.obj").write_text(trimesh.exchange.obj.export_obj(whole, include_normals=False,
                                                                          include_color=True, include_texture=False))
        jobs.append({"slug": slug, "file": str(target.resolve()), "up": _up_of(info),
                     "sizes": [int(s) for s in args.sizes.split(",")], "outside_input": str((out / "outside.obj").resolve()),
                     "licence": info.get("licence"), "note": note})
        print(f"{slug}: {target.name}{' (' + note + ')' if note else ''}")
    (into / "jobs.json").write_text(json.dumps({"models": jobs}, indent=1))
    return 0


def _obj_bounds(path: Path) -> tuple[list[float], list[float]]:
    lo, hi = [math.inf] * 3, [-math.inf] * 3
    with path.open() as handle:
        for line in handle:
            if line.startswith("v "):
                p = [float(v) for v in line.split()[1:4]]
                lo = [min(a, b) for a, b in zip(lo, p)]
                hi = [max(a, b) for a, b in zip(hi, p)]
    return lo, hi


def do_outside(args: argparse.Namespace) -> int:
    """legolization (hbmartin/legolization, GPL-3.0, PyPI) on each model, at Brickify's own scale.

    Its --pitch is file units a stud, so the scale Brickify chose (frame.json)
    is passed as is. Run from its own virtual environment; nothing of it is
    imported here. It wants the LDraw library and pyldraw3's generated modules
    under --home (`ldraw generate --yes` there, the library unpacked from
    vendor/'s zip into HOME/.cache/pyldraw3/). The builds land in
    OUT/<slug>/<studs>/outside.mpd, and jobs.json learns where, for
    brickify_bench.gd to check and measure them."""
    import subprocess
    import time

    out = Path(args.out)
    jobs_path = Path(args.jobs)
    jobs = json.loads(jobs_path.read_text())
    only = set(args.only.split(",")) if args.only else None
    for job in jobs["models"]:
        if only and job["slug"] not in only:
            continue
        for studs in job["sizes"]:
            size_dir = out / job["slug"] / str(studs)
            size_dir.mkdir(parents=True, exist_ok=True)
            if (size_dir / "frame.json").exists():
                pitch = 1.0 / json.loads((size_dir / "frame.json").read_text())["scale"]
            else:
                # Brickify's own scale: the longest side over the studs asked for.
                lo, hi = _obj_bounds(Path(job["outside_input"]))
                pitch = max(h - l for l, h in zip(lo, hi)) / studs
            target = size_dir / "outside.mpd"
            log = size_dir / "outside.log"
            if target.exists() and log.exists() and "\nexit 0 in " in log.read_text():
                # Made already: kept, and said where, as a fresh run would.
                said = log.read_text().split("\nexit 0 in ", 1)[1].split(" s", 1)[0]
                job.setdefault("outside", {})[str(studs)] = {"file": str(target), "seconds": float(said),
                                                              "exit": 0, "pitch": pitch}
                jobs_path.write_text(json.dumps(jobs, indent=1))
                continue
            up = {"+Y": "y", "-Y": "y", "+Z": "z", "-Z": "z", "+X": "x", "-X": "x"}[job["up"]]
            command = [args.tool, job["outside_input"], "-o", str(target), "--pitch", repr(pitch),
                       "--up", up, "--mesh-colour-mode", "sampled", "--slopes", "--tiles", "--snot",
                       "--largest-component-only", "--restarts", "1", "--bom", str(size_dir / "outside_bom.json"),
                       # Its smart instruction steps more than double its time (the avocado at 24 studs:
                       # 1,151 s against 501 s) and lay the same parts; a step a layer is enough here.
                       "--steps", "layer", "--no-subassemblies"]
            started = time.time()
            try:
                ran = subprocess.run(command, capture_output=True, text=True, timeout=args.timeout,
                                     env={"PATH": "/usr/bin:/bin", "LEGOLIZATION_RENDERER": "none",
                                          "HOME": args.home, "XDG_CONFIG_HOME": f"{args.home}/.config",
                                          "XDG_CACHE_HOME": f"{args.home}/.cache",
                                          "XDG_DATA_HOME": f"{args.home}/.local/share"},
                                     cwd=str(size_dir))
                code, tail = ran.returncode, ran.stdout[-2000:] + "\n--- stderr ---\n" + ran.stderr[-1500:]
            except subprocess.TimeoutExpired:
                code, tail = "timeout", ""
            seconds = time.time() - started
            (size_dir / "outside.log").write_text(f"{' '.join(command)}\nexit {code} in {seconds:.1f} s\n{tail}")
            job.setdefault("outside", {})[str(studs)] = {"file": str(target) if target.exists() else "",
                                                          "seconds": seconds, "exit": code, "pitch": pitch}
            print(f"{job['slug']} {studs}: exit {code} in {seconds:.0f} s", flush=True)
            jobs_path.write_text(json.dumps(jobs, indent=1))
    return 0


def do_jobs(args: argparse.Namespace) -> int:
    models = Path(args.models)
    sizes = [int(s) for s in args.sizes.split(",")]
    out = []
    for licence in sorted(models.glob("*/LICENCE.json")):
        info = json.loads(licence.read_text())
        main = (info.get("files") or [""])[0]
        path = licence.parent / main
        if not path.exists():
            print(f"{licence.parent.name}: no {main}", file=sys.stderr)
            continue
        out.append({"slug": licence.parent.name, "file": str(path.resolve()), "up": _up_of(info), "sizes": sizes})
    Path(args.out).write_text(json.dumps({"models": out}, indent=1))
    print(f"{len(out)} models into {args.out}")
    return 0


# -- geometry -------------------------------------------------------------------


def _np():
    import numpy as np

    return np


class Library:
    """The parts' triangles, read once."""

    def __init__(self, out: Path, colours: dict[int, tuple[float, float, float]]):
        self.out = out
        self.colours = colours
        self.cache: dict[str, tuple] = {}

    def part(self, pid: str):
        np = _np()
        if pid not in self.cache:
            safe = pid.replace("/", "_").replace("\\", "_")
            tris = np.fromfile(self.out / "parts" / f"{safe}.f32", dtype=np.float32).reshape(-1, 3, 3)
            meta = json.loads((self.out / "parts" / f"{safe}.json").read_text())
            codes = np.concatenate([np.full(s["triangles"], s["colour"], dtype=np.int32) for s in meta["surfaces"]]) \
                if meta["surfaces"] else np.zeros(0, dtype=np.int32)
            fixed = np.concatenate([np.tile(np.array(s["rgb"], dtype=np.float32), (s["triangles"], 1))
                                    for s in meta["surfaces"]]) if meta["surfaces"] else np.zeros((0, 3), np.float32)
            self.cache[pid] = (tris, codes, fixed, meta["bounds"])
        return self.cache[pid]


def load_colours() -> dict[int, tuple[float, float, float]]:
    path = Path(__file__).resolve().parents[2] / "assets" / "generated" / "colors.json"
    out = {}
    for c in json.loads(path.read_text()):
        out[int(c["code"])] = tuple(v / 255.0 for v in c["rgb"])
    return out


def stand_of(arm: dict) -> tuple[set[int], float]:
    """The stand Brickify laid the build on: its parts (indices into "placed") and how far it
    lifted the model, LDU. Empty and 0 for none."""
    stand = arm.get("stand") or {}
    return set(int(n) for n in stand.get("parts", [])), float(stand.get("lift_ldu", 0))


def build_mesh(arm: dict, lib: Library, stand: bool = False, cut: float | None = None,
               sideways: list | None = None, ups: list | None = None):
    """Every part's triangles placed, and each triangle's colour. Lowered by a stand's lift, so
    the model lines up with the model it came from; the stand itself only when asked (a
    picture shows it; likeness is of the model). With `cut` (LDU along z), only the parts whose
    middle is short of it, each a shade lighter or darker than the next, so the courses inside
    show part by part. With `sideways` (a list), it gets for each triangle whether its part
    lies on its side (the part's up not the world's); with `ups`, the way its part's up points."""
    np = _np()
    tris, cols = [], []
    skip, lift = stand_of(arm)
    for n, (pid, code, m) in enumerate(arm["placed"]):
        if n in skip and not stand:
            continue
        t, codes, fixed, _ = lib.part(pid)
        if len(t) == 0:
            continue
        mat = np.array(m, dtype=np.float64).reshape(3, 4)
        placed = t.reshape(-1, 3).astype(np.float64) @ mat[:, :3].T + mat[:, 3]
        if cut is not None and (placed[:, 2].min() + placed[:, 2].max()) / 2 > cut:
            continue
        placed[:, 1] -= lift
        tris.append(placed.reshape(-1, 3, 3).astype(np.float32))
        if sideways is not None:
            # LDraw's up is -y: a part whose -y is within 60 degrees of level lies on its side.
            sideways.append(np.full(len(t), abs((mat[:, :3] @ np.array([0.0, -1.0, 0.0]))[1]) < 0.5))
        if ups is not None:
            # The parts' own frames are the app's, y up (an upright part's up is the world's).
            up = mat[:, :3] @ np.array([0.0, 1.0, 0.0])
            ups.append(np.tile(up / max(np.linalg.norm(up), 1e-9), (len(t), 1)))
        rgb = np.array(lib.colours.get(int(code), (1.0, 0.0, 1.0)), dtype=np.float32)
        c = fixed.copy()
        c[codes == 16] = rgb
        c[codes == 24] = rgb * 0.6  # edge colour, if a part carries one
        if cut is not None:
            c = np.clip(c * (0.6 + 0.65 * ((n * 2654435761) % 1000) / 1000.0), 0, 1).astype(np.float32)
        cols.append(c)
    if not tris:
        return np.zeros((0, 3, 3), np.float32), np.zeros((0, 3), np.float32)
    return np.concatenate(tris), np.concatenate(cols)


def source_mesh(model_dir: Path, frame: dict):
    np = _np()
    pts = np.fromfile(model_dir / "source.f32", dtype=np.float32).reshape(-1, 3).astype(np.float64)
    return to_ldu(pts, frame).reshape(-1, 3, 3)


def to_ldu(pts, frame: dict):
    np = _np()
    turn = np.array(frame["turn"], dtype=np.float64).reshape(3, 3)
    p = pts @ turn.T - np.array(frame["corner"])
    s = float(frame["scale"])
    shift = np.array(frame["shift"])
    return np.stack([(p[:, 0] * s + shift[0]) * STUD, p[:, 1] * s * STUD, (p[:, 2] * s + shift[2]) * STUD], axis=1)


def source_colours(model_dir: Path, frame: dict):
    np = _np()
    raw = np.fromfile(model_dir / "colour.f32", dtype=np.float32).reshape(-1, 6).astype(np.float64)
    return to_ldu(raw[:, :3], frame), raw[:, 3:]


def caster(tris):
    import trimesh

    np = _np()
    v = tris.reshape(-1, 3).astype(np.float64)
    f = np.arange(len(v)).reshape(-1, 3)
    mesh = trimesh.Trimesh(vertices=v, faces=f, process=False, validate=False)
    try:
        from trimesh.ray.ray_pyembree import RayMeshIntersector
    except ImportError:  # pragma: no cover
        from trimesh.ray.ray_triangle import RayMeshIntersector
    return RayMeshIntersector(mesh)


def view_dirs():
    np = _np()
    dirs = [(1, 0, 0), (-1, 0, 0), (0, 1, 0), (0, -1, 0), (0, 0, 1), (0, 0, -1)]
    dirs += [(x, y, z) for x in (1, -1) for y in (1, -1) for z in (1, -1)]
    return [np.array(d, dtype=np.float64) / np.linalg.norm(d) for d in dirs]


def basis_for(d):
    np = _np()
    up = np.array([0.0, 1.0, 0.0]) if abs(d[1]) < 0.9 else np.array([0.0, 0.0, 1.0])
    u = np.cross(up, d)
    u /= np.linalg.norm(u)
    v = np.cross(d, u)
    return u, v


def cast(intersector, centre, radius, d, res):
    """Orthographic rays along d over a square 2r wide: the hit mask, points, triangles."""
    np = _np()
    u, v = basis_for(d)
    px = 2.0 * radius / res
    ii, jj = np.meshgrid(np.arange(res), np.arange(res), indexing="ij")
    a = (ii.ravel() - res / 2 + 0.5) * px
    b = (res / 2 - jj.ravel() - 0.5) * px
    origins = centre + np.outer(a, u) + np.outer(b, v) - d * (3.0 * radius)
    dirs = np.tile(d, (len(origins), 1))
    tri = intersector.intersects_first(origins, dirs)
    hit = tri >= 0
    loc = np.zeros((len(origins), 3))
    if hit.any():
        locs, rays, tris = intersector.intersects_location(origins[hit], dirs[hit], multiple_hits=False)
        idx = np.nonzero(hit)[0][rays]
        loc[idx] = locs
        tri[idx] = tris
    return hit, loc, tri


def facing(normals, d):
    """Unit normals turned toward the eye looking along d."""
    np = _np()
    n = normals / np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-12)
    return np.where((n @ d)[:, None] > 0, -n, n)


def srgb_to_oklab(rgb):
    np = _np()
    c = np.clip(rgb, 0.0, 1.0)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m1 = np.array([[0.4122214708, 0.5363325363, 0.0514459929],
                   [0.2119034982, 0.6806995451, 0.1073969566],
                   [0.0883024619, 0.2817188376, 0.6299787005]])
    lms = np.cbrt(lin @ m1.T)
    m2 = np.array([[0.2104542553, 0.7936177850, -0.0040720468],
                   [1.9779984951, -2.4285922050, 0.4505937099],
                   [0.0259040371, 0.7827717662, -0.8086757660]])
    return lms @ m2.T


def srgb_to_lab(rgb):
    np = _np()
    c = np.clip(rgb, 0.0, 1.0)
    lin = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    m = np.array([[0.4124564, 0.3575761, 0.1804375], [0.2126729, 0.7151522, 0.0721750],
                  [0.0193339, 0.1191920, 0.9503041]])
    xyz = lin @ m.T / np.array([0.95047, 1.0, 1.08883])
    f = np.where(xyz > (6 / 29) ** 3, np.cbrt(xyz), xyz / (3 * (6 / 29) ** 2) + 4 / 29)
    return np.stack([116 * f[:, 1] - 16, 500 * (f[:, 0] - f[:, 1]), 200 * (f[:, 1] - f[:, 2])], axis=1)


def ciede2000(lab1, lab2):
    np = _np()
    L1, a1, b1 = lab1.T
    L2, a2, b2 = lab2.T
    C1, C2 = np.hypot(a1, b1), np.hypot(a2, b2)
    Cm = (C1 + C2) / 2
    G = 0.5 * (1 - np.sqrt(Cm ** 7 / (Cm ** 7 + 25 ** 7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = np.hypot(a1p, b1), np.hypot(a2p, b2)
    h1p = np.degrees(np.arctan2(b1, a1p)) % 360
    h2p = np.degrees(np.arctan2(b2, a2p)) % 360
    dLp = L2 - L1
    dCp = C2p - C1p
    dh = h2p - h1p
    dh = np.where(dh > 180, dh - 360, np.where(dh < -180, dh + 360, dh))
    dh = np.where(C1p * C2p == 0, 0, dh)
    dHp = 2 * np.sqrt(C1p * C2p) * np.sin(np.radians(dh) / 2)
    Lpm = (L1 + L2) / 2
    Cpm = (C1p + C2p) / 2
    hs = h1p + h2p
    hpm = np.where(C1p * C2p == 0, hs,
                   np.where(np.abs(h1p - h2p) <= 180, hs / 2, np.where(hs < 360, (hs + 360) / 2, (hs - 360) / 2)))
    T = (1 - 0.17 * np.cos(np.radians(hpm - 30)) + 0.24 * np.cos(np.radians(2 * hpm))
         + 0.32 * np.cos(np.radians(3 * hpm + 6)) - 0.20 * np.cos(np.radians(4 * hpm - 63)))
    dtheta = 30 * np.exp(-(((hpm - 275) / 25) ** 2))
    Rc = 2 * np.sqrt(Cpm ** 7 / (Cpm ** 7 + 25 ** 7))
    Sl = 1 + 0.015 * (Lpm - 50) ** 2 / np.sqrt(20 + (Lpm - 50) ** 2)
    Sc = 1 + 0.045 * Cpm
    Sh = 1 + 0.015 * Cpm * T
    Rt = -np.sin(np.radians(2 * dtheta)) * Rc
    return np.sqrt((dLp / Sl) ** 2 + (dCp / Sc) ** 2 + (dHp / Sh) ** 2 + Rt * (dCp / Sc) * (dHp / Sh))


# -- bond -----------------------------------------------------------------------


def bond(arm: dict, lib: Library) -> dict:
    """Seams bridged and weak points, from the parts' boxes on the stud and plate grid. Of the
    model's own parts: a stand's plates are bonded by construction and would flatter it."""
    np = _np()
    owner: dict[tuple[int, int, int], int] = {}
    one_by_one = 0
    boxes = []
    skip, _lift = stand_of(arm)
    placed = [one for n, one in enumerate(arm["placed"]) if n not in skip]
    for pid, _code, m in placed:
        _, _, _, b = lib.part(pid)
        # A 1 x 1 by the part itself, whichever way it is turned: a plate, a tile, a cheese
        # slope, a brick with a stud on its side.
        if round(b[3] / 20) == 1 and round(b[5] / 20) == 1:
            one_by_one += 1
        mat = np.array(m, dtype=np.float64).reshape(3, 4)
        lo = np.array(b[:3])
        hi = lo + np.array(b[3:])
        corners = np.array([[x, y, z] for x in (lo[0], hi[0]) for y in (lo[1], hi[1]) for z in (lo[2], hi[2])])
        w = corners @ mat[:, :3].T + mat[:, 3]
        boxes.append((w.min(axis=0), w.max(axis=0)))
    # Each build on its own grid: an outside tool's may sit half a stud off ours.
    def grid_offset(values, pitch):
        counts: dict[int, int] = {}
        for v in values:
            k = int(round(v % pitch)) % int(pitch)
            counts[k] = counts.get(k, 0) + 1
        return max(counts, key=lambda k: counts[k]) if counts else 0
    off = np.array([grid_offset([b[0][0] for b in boxes], 20), grid_offset([b[0][1] for b in boxes], 8),
                    grid_offset([b[0][2] for b in boxes], 20)], dtype=np.float64)
    for n, (p0, p1) in enumerate(boxes):
        p0, p1 = p0 - off, p1 - off
        x0, x1 = int(round(p0[0] / 20)), int(round(p1[0] / 20))
        z0, z1 = int(round(p0[2] / 20)), int(round(p1[2] / 20))
        for j in range(int(math.floor(p0[1] / 8)), int(math.ceil(p1[1] / 8))):
            centre = (j + 0.5) * 8
            if centre < p0[1] or centre > p1[1] - 3.9:
                continue
            for x in range(x0, x1):
                for z in range(z0, z1):
                    owner.setdefault((x, j, z), n)
    vertical: dict[int, set[int]] = {}
    for (x, j, z), a in owner.items():
        c = owner.get((x, j + 1, z))
        if c is not None and c != a:
            vertical.setdefault(a, set()).add(c)
            vertical.setdefault(c, set()).add(a)
    pairs = set()
    for (x, j, z), a in owner.items():
        for dx, dz in ((1, 0), (0, 1)):
            b = owner.get((x + dx, j, z + dz))
            if b is not None and b != a:
                pairs.add((min(a, b), max(a, b)))
    bridged = sum(1 for a, b in pairs if vertical.get(a, set()) & vertical.get(b, set()))
    weak = articulation_points(len(placed), vertical)
    parts = max(1, len(placed))
    return {"seams": len(pairs), "seams_bridged": bridged,
            "seam_share": bridged / len(pairs) if pairs else 1.0,
            "weak_points": len(weak), "weak_share": len(weak) / parts,
            "one_by_one": one_by_one, "one_by_one_share": one_by_one / parts}


def articulation_points(n: int, graph: dict[int, set[int]]) -> set[int]:
    """Tarjan's, iteratively: the parts whose removal splits what they are in."""
    disc = [-1] * n
    low = [0] * n
    out: set[int] = set()
    timer = 0
    for root in range(n):
        if disc[root] != -1 or root not in graph:
            continue
        disc[root] = low[root] = timer
        timer += 1
        children = 0
        stack = [(root, -1, iter(graph[root]))]
        while stack:
            node, parent, it = stack[-1]
            advanced = False
            for nxt in it:
                if disc[nxt] == -1:
                    disc[nxt] = low[nxt] = timer
                    timer += 1
                    if node == root:
                        children += 1
                    stack.append((nxt, node, iter(graph.get(nxt, ()))))
                    advanced = True
                    break
                if nxt != parent:
                    low[node] = min(low[node], disc[nxt])
            if advanced:
                continue
            stack.pop()
            if parent != -1:
                low[parent] = min(low[parent], low[node])
                if parent != root and low[node] >= disc[parent]:
                    out.add(parent)
        if children > 1:
            out.add(root)
    return out


# -- measure --------------------------------------------------------------------


def aligned(tris, src_pts, src_flat, centre, radius):
    """An outside build in its own frame, moved onto the model: its box's middle
    over the model's and its foot on the model's foot, then nudged (translation
    only, three rounds) toward the nearest visible surface. It can only gain by
    this; Brickify's own builds are measured where they were laid."""
    np = _np()
    from scipy.spatial import cKDTree

    flat = tris.reshape(-1, 3).astype(np.float64)
    lo, hi = flat.min(axis=0), flat.max(axis=0)
    slo, shi = src_flat.min(axis=0), src_flat.max(axis=0)
    move = np.array([(slo[0] + shi[0] - lo[0] - hi[0]) / 2, slo[1] - lo[1], (slo[2] + shi[2] - lo[2] - hi[2]) / 2])
    tree = cKDTree(src_pts)
    for _round in range(3):
        moved = (flat + move).reshape(-1, 3, 3)
        c = caster(moved)
        seen = np.concatenate([loc[hit] for hit, loc, _ in (cast(c, centre, radius, d, 160) for d in view_dirs()[:6])])
        dist, idx = tree.query(seen)
        near = dist < STUD
        if near.sum() < 10:
            break
        step = (src_pts[idx[near]] - seen[near]).mean(axis=0)
        move = move + step
        if np.linalg.norm(step) < 0.5:
            break
    return (flat + move).reshape(-1, 3, 3).astype(np.float32)


def measure_one(model_dir: Path, size_dir: Path, lib: Library, palette_lab, palette_rgb, coloured: bool,
                arms: tuple[str, ...] = ARMS) -> dict:
    np = _np()
    from scipy.spatial import cKDTree

    frame = json.loads((size_dir / "frame.json").read_text())
    src = source_mesh(model_dir, frame)
    flat = src.reshape(-1, 3)
    lo, hi = flat.min(axis=0), flat.max(axis=0)
    centre = (lo + hi) / 2
    radius = float(np.linalg.norm(hi - lo) / 2 * 1.08)
    longest = float((hi - lo).max())
    dirs = view_dirs()
    src_caster = caster(src)
    src_hits = [cast(src_caster, centre, radius, d, VIEWS_RES) for d in dirs]
    src_pts = np.concatenate([loc[hit] for hit, loc, _ in src_hits])
    src_nrm = np.concatenate([facing(src_caster.mesh.face_normals[tri[hit]], d)
                              for d, (hit, _, tri) in zip(dirs, src_hits)])
    src_tree = cKDTree(src_pts)
    src_rgb = np.zeros((len(src_pts), 3))
    if coloured:
        cpos, crgb = source_colours(model_dir, frame)
        ctree = cKDTree(cpos)
        _, ci = ctree.query(src_pts)
        src_rgb = crgb[ci]
    out: dict = {"longest_ldu": longest}
    for arm_name in arms:
        path = size_dir / f"{arm_name}.json"
        if not path.exists():
            continue
        arm = json.loads(path.read_text())
        if "placed" not in arm or not arm["placed"]:
            continue
        tris, cols = build_mesh(arm, lib)
        if arm.get("align"):
            tris = aligned(tris, src_pts, flat, centre, radius)
        bc = caster(tris)
        ious, pts, pcol, pnrm = [], [], [], []
        for d, (shit, _, _) in zip(dirs, src_hits):
            hit, loc, tri = cast(bc, centre, radius, d, VIEWS_RES)
            inter = np.logical_and(hit, shit).sum()
            union = np.logical_or(hit, shit).sum()
            ious.append(inter / union if union else 1.0)
            pts.append(loc[hit])
            pcol.append(cols[tri[hit]])
            pnrm.append(facing(bc.mesh.face_normals[tri[hit]], d))
        bpts = np.concatenate(pts)
        bnrm = np.concatenate(pnrm)
        bcol = np.concatenate(pcol)
        btree = cKDTree(bpts)
        d_sb, nearest = btree.query(src_pts)
        d_bs, _ = src_tree.query(bpts)
        prec = float((d_bs < HALF_STUD).mean())
        rec = float((d_sb < HALF_STUD).mean())
        row = {
            "iou": float(np.mean(ious)),
            "iou_min": float(np.min(ious)),
            "chamfer_studs": float((d_sb.mean() + d_bs.mean()) / 2 / STUD),
            "hausdorff_studs": float(max(d_sb.max(), d_bs.max()) / STUD),
            "hausdorff95_studs": float(max(np.percentile(d_sb, 95), np.percentile(d_bs, 95)) / STUD),
            # Each way apart: the model's surface the build is far from (lost), and the build's
            # surface far from the model (added). A fox's legs are lost; a fat build adds.
            "lost95_studs": float(np.percentile(d_sb, 95) / STUD),
            "added95_studs": float(np.percentile(d_bs, 95) / STUD),
            "kept_within_stud": float((d_sb < STUD).mean()),
            "chamfer_pct": float((d_sb.mean() + d_bs.mean()) / 2 / longest * 100),
            "hausdorff_pct": float(max(d_sb.max(), d_bs.max()) / longest * 100),
            "f_half_stud": 2 * prec * rec / (prec + rec) if prec + rec else 0.0,
            # How far the surface turns from the model's where it is seen: what
            # shading shows, and what a slope can change and a stud cannot.
            "normal_deg": float(np.degrees(np.arccos(np.clip(np.abs((src_nrm * bnrm[nearest]).sum(axis=1)),
                                                             0, 1))).mean()),
            "triangles": int(len(tris)),
        }
        if coloured:
            mine = bcol[nearest]
            de_ok = np.linalg.norm(srgb_to_oklab(src_rgb) - srgb_to_oklab(mine), axis=1) * 100
            de00 = ciede2000(srgb_to_lab(src_rgb), srgb_to_lab(mine))
            row["de_ok"] = float(de_ok.mean())
            row["de2000"] = float(de00.mean())
            # The model's neutral surface laid in a strong colour, of all its neutral surface.
            neutral = np.hypot(*srgb_to_lab(src_rgb)[:, 1:].T) < NEUTRAL_CHROMA
            row["neutral_share"] = float(neutral.mean())
            if neutral.any():
                row["neutral_chromatic"] = float((np.hypot(*srgb_to_lab(mine[neutral])[:, 1:].T)
                                                  >= CHROMATIC).mean())
        row.update(bond(arm, lib))
        out[arm_name] = row
    if coloured:
        s_lab = srgb_to_oklab(src_rgb)
        gap = np.linalg.norm(s_lab[:, None, :] - palette_lab[None, :, :], axis=2)
        best = gap.argmin(axis=1)
        out["floor_de_ok"] = float(gap.min(axis=1).mean() * 100)
        out["floor_de2000"] = float(ciede2000(srgb_to_lab(src_rgb), srgb_to_lab(palette_rgb[best])).mean())
    return out


def do_bond(args: argparse.Namespace) -> int:
    """The bond figures again, alone (no ray casting), into OUT/measures.json."""
    out = Path(args.out)
    lib = Library(out, load_colours())
    target = out / "measures.json"
    results = json.loads(target.read_text()) if target.exists() else {}
    for model_dir in sorted(p for p in out.iterdir() if (p / "source.json").exists()):
        for size_dir in sorted(p for p in model_dir.iterdir() if (p / "frame.json").exists()):
            key = f"{model_dir.name}/{size_dir.name}"
            for arm_name in ARMS:
                path = size_dir / f"{arm_name}.json"
                if not path.exists():
                    continue
                arm = json.loads(path.read_text())
                if not arm.get("placed"):
                    continue
                results.setdefault(key, {}).setdefault(arm_name, {}).update(bond(arm, lib))
            print(key, flush=True)
    target.write_text(json.dumps(results, indent=1))
    return 0


FACES = (("up", 0.966, 1.01), ("up and out", 0.5, 0.966), ("out", -0.5, 0.5),
         ("down and out", -0.966, -0.5), ("down", -1.01, -0.966))
# The views from the four sides, of view_dirs(): +x, -x, +z, -z.
SIDE_VIEWS = (0, 1, 4, 5)
# A face leaning this far from all six axes (degrees) is one a slope's lean can match, and is
# matched when the build's face nearest it is within MATCHED_DEG of it.
LEAN_FROM, LEAN_TO, MATCHED_DEG = 10.0, 40.0, 10.0


def do_faces(args: argparse.Namespace) -> int:
    """Where the normal error and the distance are: the model's visible points sorted by which way
    their surface faces (the up part of its outward normal: up, up and out, out within 30 degrees of
    level, down and out, down), and each arm's mean normal error and mean distance from the model to
    the build for each; of the faces leaning 10 to 40 degrees from every axis, the share the build
    matches within 10 degrees ("matched"); and over every face ("every"). Into OUT/faces.json, and
    printed."""
    np = _np()
    from scipy.spatial import cKDTree

    out = Path(args.out)
    lib = Library(out, load_colours())
    only = set(args.only.split(",")) if args.only else None
    target = out / "faces.json"
    results = json.loads(target.read_text()) if target.exists() else {}
    for model_dir in sorted(p for p in out.iterdir() if (p / "source.json").exists()):
        if only and model_dir.name not in only:
            continue
        for size_dir in sorted((p for p in model_dir.iterdir() if (p / "frame.json").exists()),
                               key=lambda p: int(p.name)):
            frame = json.loads((size_dir / "frame.json").read_text())
            src = source_mesh(model_dir, frame)
            flat = src.reshape(-1, 3)
            lo, hi = flat.min(axis=0), flat.max(axis=0)
            centre = (lo + hi) / 2
            radius = float(np.linalg.norm(hi - lo) / 2 * 1.08)
            dirs = view_dirs()
            sc = caster(src)
            hits = [cast(sc, centre, radius, d, args.res) for d in dirs]
            pts = np.concatenate([loc[hit] for hit, loc, _ in hits])
            # facing() turns a normal toward the eye: for a closed surface seen from outside, outward.
            nrm = np.concatenate([facing(sc.mesh.face_normals[tri[hit]], d) for d, (hit, _, tri) in zip(dirs, hits)])
            bins = [(name, (nrm[:, 1] > a) & (nrm[:, 1] <= b)) for name, a, b in FACES]
            row: dict = {"share": {name: float(m.mean()) for name, m in bins}}
            for arm_name in ARMS:
                path = size_dir / f"{arm_name}.json"
                if not path.exists():
                    continue
                arm = json.loads(path.read_text())
                if not arm.get("placed"):
                    continue
                on_side: list = []
                part_up: list = []
                tris, _ = build_mesh(arm, lib, sideways=on_side, ups=part_up)
                tri_side = np.concatenate(on_side) if on_side else np.zeros(0, dtype=bool)
                tri_up = np.concatenate(part_up) if part_up else np.zeros((0, 3))
                bc = caster(tris)
                bp, bn, bs, bu = [], [], [], []
                for d in dirs:
                    hit, loc, tri = cast(bc, centre, radius, d, args.res)
                    bp.append(loc[hit])
                    bn.append(facing(bc.mesh.face_normals[tri[hit]], d))
                    bs.append(tri_side[tri[hit]])
                    bu.append(tri_up[tri[hit]])
                # Seen from the four sides alone: the model's points and the build's in those views,
                # the larger of the two 95th percentiles of each from the other (Hausdorff95), studs.
                side_m = np.concatenate([hits[i][1][hits[i][0]] for i in SIDE_VIEWS])
                side_b = np.concatenate([bp[i] for i in SIDE_VIEWS])
                d_mb, _ = cKDTree(side_b).query(side_m)
                d_bm, _ = cKDTree(side_m).query(side_b)
                bp, bn, bs, bu = np.concatenate(bp), np.concatenate(bn), np.concatenate(bs), np.concatenate(bu)
                dist, near = cKDTree(bp).query(pts)
                err = np.degrees(np.arccos(np.clip(np.abs((nrm * bn[near]).sum(axis=1)), 0, 1)))
                row[arm_name] = {name: {"normal_deg": float(err[m].mean()) if m.any() else None,
                                        "lost_studs": float(dist[m].mean() / STUD) if m.any() else None}
                                 for name, m in bins}
                # The steep ("out") faces whose nearest part of the build lies on its side, and the
                # rest: how much of the side SNOT reaches, and what each does there.
                steep = dict(bins)["out"]
                for which, m in (("on_side", steep & bs[near]), ("upright", steep & ~bs[near])):
                    row[arm_name]["out_" + which] = {
                        "share": float(m.sum() / max(1, steep.sum())),
                        "normal_deg": float(err[m].mean()) if m.any() else None,
                        "lost_studs": float(dist[m].mean() / STUD) if m.any() else None}
                # SNOT in every direction: of the faces that face out within 30 degrees of level,
                # or down, those whose nearest part has its top turned to face them (its up within
                # 60 degrees of their way out): on its side facing out, or upside down under them.
                # "turned" is all of those; "turned_out" the steep ones alone, "turned_down" the
                # rest.
                facing_part = (nrm * bu[near]).sum(axis=1) >= 0.5
                for which, m in (("turned", nrm[:, 1] <= 0.5), ("turned_out", steep),
                                 ("turned_down", nrm[:, 1] <= -0.5)):
                    row[arm_name][which] = {
                        "share": float((m & facing_part).sum() / max(1, m.sum())),
                        "normal_deg": float(err[m].mean()) if m.any() else None,
                        "there_deg": float(err[m & facing_part].mean()) if (m & facing_part).any() else None,
                        "lost_studs": float(dist[m].mean() / STUD) if m.any() else None}
                # The lean (docs/BRICKIFY.md, "Where the error is: the lean"): of everything seen that
                # leans 10 to 40 degrees from the nearest of the six ways a part can face, the share
                # whose nearest part face is within 10 degrees of it ("matched"); and every face's
                # error and distance together ("every").
                lean = np.degrees(np.arccos(np.clip(np.abs(nrm).max(axis=1), 0, 1)))
                leaning = (lean >= LEAN_FROM) & (lean < LEAN_TO)
                row[arm_name]["matched"] = {
                    "seen": float(leaning.mean()),
                    "share": float((leaning & (err < MATCHED_DEG)).sum() / max(1, leaning.sum())),
                    "normal_deg": float(err[leaning].mean()) if leaning.any() else None}
                row[arm_name]["every"] = {"normal_deg": float(err.mean()), "lost_studs": float(dist.mean() / STUD)}
                row[arm_name]["sides"] = {
                    "hausdorff95_studs": float(max(np.percentile(d_mb, 95), np.percentile(d_bm, 95)) / STUD),
                    "lost95_studs": float(np.percentile(d_mb, 95) / STUD),
                    "added95_studs": float(np.percentile(d_bm, 95) / STUD)}
            key = f"{model_dir.name}/{size_dir.name}"
            results[key] = row
            print(key, " ".join(f"{name} {row['share'][name]:.0%}" for name, _, _ in FACES), flush=True)
            for arm_name in ARMS:
                if arm_name in row:
                    print(f"  {arm_name:7s}", " | ".join(
                        f"{name} {row[arm_name][name]['normal_deg'] or 0:4.1f}° {row[arm_name][name]['lost_studs'] or 0:.2f}"
                        for name, _, _ in FACES), f"| sides H95 {row[arm_name]['sides']['hausdorff95_studs']:.2f}",
                        f"| out on its side {row[arm_name]['out_on_side']['share']:.0%}"
                        f" {row[arm_name]['out_on_side']['normal_deg'] or 0:.1f}°"
                        f"| turned {row[arm_name]['turned']['share']:.0%}"
                        f" (out {row[arm_name]['turned_out']['share']:.0%},"
                        f" down {row[arm_name]['turned_down']['share']:.0%})"
                        f" | matched {row[arm_name]['matched']['share']:.1%}"
                        f" | every {row[arm_name]['every']['normal_deg']:.1f}° {row[arm_name]['every']['lost_studs']:.3f}",
                        flush=True)
            target.write_text(json.dumps(results, indent=1))
    return 0


def do_measure(args: argparse.Namespace) -> int:
    np = _np()
    out = Path(args.out)
    lib = Library(out, load_colours())
    palette = json.loads((out / "palette.json").read_text())
    palette_rgb = np.array([p["rgb"] for p in palette], dtype=np.float64)
    palette_lab = srgb_to_oklab(palette_rgb)
    target = out / args.file
    results = json.loads(target.read_text()) if target.exists() else {}
    only = set(args.only.split(",")) if args.only else None
    for model_dir in sorted(p for p in out.iterdir() if (p / "source.json").exists()):
        if only and model_dir.name not in only:
            continue
        info = json.loads((model_dir / "source.json").read_text())
        for size_dir in sorted((p for p in model_dir.iterdir() if (p / "frame.json").exists()),
                               key=lambda p: int(p.name)):
            key = f"{model_dir.name}/{size_dir.name}"
            arms = tuple(a for a in ARMS if not args.arms or a in args.arms.split(","))
            fresh = measure_one(model_dir, size_dir, lib, palette_lab, palette_rgb, bool(info["coloured"]), arms)
            results.setdefault(key, {}).update(fresh)
            r = results[key]
            print(key, " ".join(f"{a}: IoU {r[a]['iou']:.3f} CD {r[a]['chamfer_studs']:.2f}"
                                for a in ARMS if a in r), flush=True)
            target.write_text(json.dumps(results, indent=1))
    return 0


# -- pictures -------------------------------------------------------------------


def render(intersector, colour_of, centre, radius, res, d, light):
    """A lit picture along d: Lambert from `light`, over a white ground."""
    np = _np()
    hit, loc, tri = cast(intersector, centre, radius, d, res)
    img = np.ones((res * res, 3))
    if hit.any():
        mesh = intersector.mesh
        normals = mesh.face_normals[tri[hit]]
        normals = np.where((normals @ d)[:, None] > 0, -normals, normals)
        lam = np.clip(normals @ -light, 0, 1)
        rim = np.clip(normals @ -d, 0, 1)
        shade = 0.42 + 0.48 * lam + 0.22 * rim
        img[hit] = np.clip(colour_of(tri[hit], loc[hit]) * shade[:, None], 0, 1)
    return (img.reshape(res, res, 3).transpose(1, 0, 2) * 255).astype(np.uint8)


def do_pictures(args: argparse.Namespace) -> int:
    np = _np()
    from PIL import Image, ImageDraw, ImageFont
    from scipy.spatial import cKDTree

    out = Path(args.out)
    into = Path(args.into)
    into.mkdir(parents=True, exist_ok=True)
    lib = Library(out, load_colours())
    only = set(args.only.split(",")) if args.only else None
    arms = [a for a in ARMS if not args.arms or a in args.arms.split(",")]
    before = Path(args.before) if args.before else None
    before_lib = Library(before, load_colours()) if before else None
    for view in args.views.split(","):
        _pictures_from(args, view, out, into, lib, only, arms, before, before_lib)
    return 0


# Where each picture looks from, the way the eye looks: a corner above, each side a little
# above it, and from underneath.
VIEWS = {"corner": (-0.62, -0.42, -0.66), "front": (0.0, -0.3, -1.0), "back": (0.0, -0.3, 1.0),
         "left": (1.0, -0.3, 0.0), "right": (-1.0, -0.3, 0.0), "under": (-0.35, 0.9, -0.3)}


def _pictures_from(args, view, out, into, lib, only, arms, before, before_lib):
    np = _np()
    from PIL import Image, ImageDraw, ImageFont
    from scipy.spatial import cKDTree

    # Cut, the cut face nearly head on.
    d = np.array([-0.3, -0.35, -0.89]) if args.cut else np.array(VIEWS[view], dtype=np.float64)
    d /= np.linalg.norm(d)
    light = np.array([0.35, -0.8, -0.45]) if view != "under" else np.array([0.35, 0.8, -0.45])
    light /= np.linalg.norm(light)
    res = args.res
    for model_dir in sorted(p for p in out.iterdir() if (p / "source.json").exists()):
        if only and model_dir.name not in only:
            continue
        info = json.loads((model_dir / "source.json").read_text())
        for size_dir in sorted((p for p in model_dir.iterdir() if (p / "frame.json").exists()),
                               key=lambda p: int(p.name)):
            frame = json.loads((size_dir / "frame.json").read_text())
            src = source_mesh(model_dir, frame)
            flat = src.reshape(-1, 3)
            lo, hi = flat.min(axis=0), flat.max(axis=0)
            centre = (lo + hi) / 2
            # As big as the model allows from this side: its widest extent across the view.
            u, v = basis_for(d)
            radius = float(max(np.abs((flat - centre) @ u).max(), np.abs((flat - centre) @ v).max()) * 1.06)
            looks = None
            if info["coloured"]:
                cpos, crgb = source_colours(model_dir, frame)
                looks = (cKDTree(cpos), crgb)

            def src_colour(tri, loc, looks=looks):
                if looks is None:
                    return np.tile(np.array([0.82, 0.82, 0.82]), (len(tri), 1))
                return looks[1][looks[0].query(loc)[1]]
            panels = [("model", render(caster(src), src_colour, centre, radius, res, d, light))]

            def arm_panel(path, parts, said, src=src, flat=flat, centre=centre, radius=radius):
                arm = json.loads(path.read_text())
                if not arm.get("placed"):
                    # Nothing laid is a result too: an empty panel, said.
                    return (f"{said}: nothing laid", np.full((res, res, 3), 255, dtype=np.uint8))
                tris, cols = build_mesh(arm, parts, stand=True, cut=float(centre[2]) if args.cut else None)
                if arm.get("align"):
                    sc = caster(src)
                    seen = np.concatenate([loc[hit] for hit, loc, _ in
                                           (cast(sc, centre, radius, v, 160) for v in view_dirs())])
                    tris = aligned(tris, seen, flat, centre, radius)
                on_stand = " on a stand" if stand_of(arm)[0] else ""
                return (f"{said}: {len(arm['placed']):,} parts{on_stand}",
                        render(caster(tris), lambda tri, _l, cols=cols: cols[tri], centre, radius, res, d, light))
            for arm_name in arms:
                path = size_dir / f"{arm_name}.json"
                if not path.exists():
                    continue
                if before is not None:
                    # The same model and size laid before, beside each arm as it is now.
                    then = before / model_dir.name / size_dir.name / f"{arm_name}.json"
                    if then.exists():
                        panels.append(arm_panel(then, before_lib, f"before, {arm_name}"))
                    panels.append(arm_panel(path, lib, f"after, {arm_name}"))
                else:
                    panels.append(arm_panel(path, lib, arm_name))
            label = 26
            font = ImageFont.load_default(size=16)
            sheet = Image.new("RGB", (res * len(panels), res + label), 0xFFFFFF)
            draw = ImageDraw.Draw(sheet)
            for n, (name, pixels) in enumerate(panels):
                sheet.paste(Image.fromarray(pixels), (n * res, label))
                draw.text((n * res + 8, 4), name, fill=(40, 40, 40), font=font)
            seen_from = "" if view == "corner" else f"-{view}"
            target = into / f"{model_dir.name}-{size_dir.name}{'-cut' if args.cut else seen_from}.jpg"
            sheet.save(target, quality=args.quality, optimize=True)
            print(target)


# -- report ---------------------------------------------------------------------


def _mean(values):
    values = [v for v in values if v is not None]
    return statistics.mean(values) if values else None


def _median(values):
    values = [v for v in values if v is not None]
    return statistics.median(values) if values else None


_MOVED: dict[str, str] = {}


def current_number(pid: str) -> str:
    """A part by the number LDraw gives it today: 3023 says "~Moved to 3023b"."""
    if pid not in _MOVED:
        seen, now = set(), pid
        root = Path(__file__).resolve().parents[2] / "vendor" / "ldraw" / "parts"
        while now not in seen:
            seen.add(now)
            path = root / f"{now}.dat"
            if not path.exists():
                break
            with path.open(errors="replace") as handle:
                first = handle.readline()
            if "~Moved to" not in first:
                break
            now = first.split("~Moved to", 1)[1].strip()
        _MOVED[pid] = now
    return _MOVED[pid]


def not_real(arm: dict, pairs: dict) -> int:
    """Parts in a colour no element of theirs comes in, by Rebrickable's element list."""
    return sum(1 for pid, code, _ in arm["placed"] if f"{current_number(pid)}/{code}" not in pairs)


def rows(out: Path) -> list[dict]:
    measures = {}
    for path in sorted(out.glob("measures*.json")):
        for key, value in json.loads(path.read_text()).items():
            # Merged a level down too: a later file with fewer figures for an arm adds, never erases.
            into = measures.setdefault(key, {})
            for name, figure in value.items():
                if isinstance(figure, dict) and isinstance(into.get(name), dict):
                    into[name].update(figure)
                else:
                    into[name] = figure
    table = []
    elements = Path(__file__).resolve().parents[2] / "assets" / "generated" / "elements.json"
    pairs = json.loads(elements.read_text())["pairs"]
    for model_dir in sorted(p for p in out.iterdir() if (p / "source.json").exists()):
        info = json.loads((model_dir / "source.json").read_text())
        for size_dir in sorted((p for p in model_dir.iterdir() if (p / "frame.json").exists()),
                               key=lambda p: int(p.name)):
            m = measures.get(f"{model_dir.name}/{size_dir.name}", {})
            for arm_name in ARMS:
                path = size_dir / f"{arm_name}.json"
                if not path.exists():
                    continue
                arm = json.loads(path.read_text())
                if "error" in arm:
                    table.append({"model": model_dir.name, "studs": int(size_dir.name), "arm": arm_name,
                                  "error": arm["error"]})
                    continue
                k = arm["kinds"]
                parts = max(1, arm["parts"])
                ms = arm["ms"]
                row = {
                    "model": model_dir.name, "studs": int(size_dir.name), "arm": arm_name,
                    "coloured": info["coloured"], "triangles_in": info["triangles"],
                    "parts": arm["parts"], "lots": arm["lots"], "colours": arm["colours"],
                    "shaped_share": (k["curved"] + k["sloped"] + k["tile"]) / parts,
                    "curved": k["curved"], "sloped": k["sloped"], "tiles": k["tile"], "sideways": k["sideways"],
                    "top_shaped": (lambda t: (t["curved"] + t["sloped"] + t["tile"]) / max(1, sum(t.values())))(arm["tops"]),
                    "bare_studs": arm["bare_studs"],
                    "ok": arm["ok"], "pieces": arm["pieces"], "summary": arm["summary"],
                    "one_piece": arm["ok"] and arm["pieces"] == 1,
                    "mended": arm.get("mended", 0), "coverage": arm.get("coverage"),
                    "no_element_parts": not_real(arm, pairs),
                    "over": (arm.get("balance") or {}).get("over"),
                    "stands": (arm.get("balance") or {}).get("stands"),
                    "on_stand": bool(stand_of(arm)[0]), "stand_parts": len(stand_of(arm)[0]),
                    "tied": arm.get("tied", 0), "joined": arm.get("joined", 0), "thin": arm.get("thin", 0),
                    "left_out": arm.get("left_out", 0), "lost_share": arm.get("lost_share"),
                    "seconds": (ms.get("measure", 0) + ms.get("lay", 0) + ms.get("check", 0)) / 1000.0,
                    "grid": arm["grid"],
                }
                row.update({f"m_{key}": value for key, value in m.get(arm_name, {}).items()})
                row["floor_de_ok"] = m.get("floor_de_ok")
                row["floor_de2000"] = m.get("floor_de2000")
                table.append(row)
    return table


def _fmt(v, spec):
    if v is None:
        return "—"
    return format(v, spec)


WHOLE_STUDS = 1.0  # a build "keeps the model" when 95% of the model is within this of it


def _line(cells: list[str]) -> str:
    return "| " + " | ".join(cells) + " |"


def _common(models, s, arms, by) -> list[str]:
    return [m for m in models if all((m, s, a) in by and by[(m, s, a)]["parts"] > 0
                                     and _whole(by[(m, s, a)], by) for a in arms)]


def do_report(args: argparse.Namespace) -> int:
    """Three tables: whether each arm laid the model at all and whole, how good the
    layout is where every arm kept the model, and each model."""
    out = Path(args.out)
    table = [r for r in rows(out) if "error" not in r]
    sizes = sorted({r["studs"] for r in table})
    arms = [a for a in ARMS if any(r["arm"] == a for r in table)]
    models = sorted({r["model"] for r in table})
    by = {(r["model"], r["studs"], r["arm"]): r for r in table}
    lines = ["### Did it lay the model, and all of it?", "",
             "Of the models, at each size: laid at all; whole (95% of the model's visible surface within a "
             "stud of the build's); in one "
             "piece with the check passing; that, and standing by Balance with no stud joint past its "
             "working load; parts the mend took out (mean).", "",
             _line(["Studs", "Arm", "Laid", "Whole", "One piece, check passes", "And stands, no joint past its load",
                    "Of those, on a stand", "Mended (mean)", "Seconds (mean)", "Seconds (most)"]),
             "|" + "---|" * 10]
    n = len(models)
    for s in sizes:
        for a in arms:
            rs = [r for r in table if r["studs"] == s and r["arm"] == a]
            if not rs:
                continue
            laid = [r for r in rs if r["parts"] > 0]
            whole = [r for r in laid if _whole(r, by)]
            lines.append(_line([str(s), a, f"{len(laid)}/{n}", f"{len(whole)}/{n}",
                                f"{sum(1 for r in rs if r['one_piece'] and r['parts'] > 0)}/{n}",
                                f"{sum(1 for r in laid if r['one_piece'] and r.get('stands') and not r.get('over'))}/{n}",
                                str(sum(1 for r in laid if r['one_piece'] and r.get('stands') and not r.get('over')
                                        and r.get('on_stand'))),
                                _fmt(_mean([r["mended"] for r in rs]), ".0f"),
                                _fmt(_mean([r["seconds"] for r in rs]), ".1f"),
                                _fmt(max((r["seconds"] for r in rs), default=None), ".0f")]))
    header = [_line(["Studs", "Arm", "Parts", "Lots", "Shaped parts", "Tops shaped", "Bare studs", "IoU",
                     "Chamfer (studs)", "Lost95 (studs)", "Added95 (studs)", "F@0.5 stud", "Normal error (°)",
                     "ΔE2000 (coloured)", "Seams bridged", "Weak points", "1x1 share", "Not a real element"]),
              "|" + "---|" * 18]

    def block(s: int, arms_here: list[str], common: list[str]) -> list[str]:
        out = []
        for a in arms_here:
            rs = [by[(m, s, a)] for m in common]
            col = [r for r in rs if r["coloured"]]
            out.append(_line([
                str(s), a, _fmt(_mean([r["parts"] for r in rs]), ",.0f"), _fmt(_mean([r["lots"] for r in rs]), ",.0f"),
                _fmt(_mean([r["shaped_share"] for r in rs]), ".0%"), _fmt(_mean([r["top_shaped"] for r in rs]), ".0%"),
                _fmt(_mean([r["bare_studs"] for r in rs]), ",.0f"),
                _fmt(_mean([r.get("m_iou") for r in rs]), ".3f"),
                _fmt(_mean([r.get("m_chamfer_studs") for r in rs]), ".2f"),
                _fmt(_mean([r.get("m_lost95_studs") for r in rs]), ".2f"),
                _fmt(_mean([r.get("m_added95_studs") for r in rs]), ".2f"),
                _fmt(_mean([r.get("m_f_half_stud") for r in rs]), ".3f"),
                _fmt(_mean([r.get("m_normal_deg") for r in rs]), ".1f"),
                _fmt(_mean([r.get("m_de2000") for r in col]), ".1f"),
                _fmt(_mean([r.get("m_seam_share") for r in rs]), ".0%"),
                _fmt(_mean([r.get("m_weak_share") for r in rs]), ".1%"),
                _fmt(_mean([r.get("m_one_by_one_share") for r in rs]), ".0%"),
                _fmt(_mean([r["no_element_parts"] / max(1, r["parts"]) for r in rs]), ".1%")]))
        floor = _mean([by[(m, s, "smooth")].get("floor_de2000") for m in common if (m, s, "smooth") in by])
        if floor is not None:
            out.append(_line([str(s), "palette floor"] + [""] * 11 + [f"{floor:.1f}"] + [""] * 4))
        return out

    ours = [a for a in ("smooth", "plain", "greedy") if a in arms]
    lines += ["", "### The layout, where all three of ours kept the model whole", ""]
    rows3 = []
    for s in sizes:
        common = _common(models, s, ours, by)
        lines.append(f"At {s} studs, {len(common)} models: {', '.join(common)}.")
        rows3 += block(s, ours, common)
    lines += [""] + header + rows3
    if "outside" in arms:
        lines += ["", "### Against the outside tool, on the models it laid", ""]
        rows4 = []
        for s in sizes:
            if not any((m, s, "outside") in by for m in models):
                continue
            both = [m for m in models if all((m, s, a) in by and by[(m, s, a)]["parts"] > 0
                                             for a in ("smooth", "outside"))]
            lines.append(f"At {s} studs, {len(both)} models both Brickify and it laid: {', '.join(both)}.")
            rows4 += block(s, ours + ["outside"], both)
        lines += [""] + header + rows4
    lines += ["", "### Each model", "",
              _line(["Model", "Studs", "Arm", "Parts", "Coverage", "Shaped", "IoU", "Chamfer", "Lost95", "Added95",
                     "Normal (°)", "ΔE2000", "Neutral laid chromatic", "No element", "Check", "Pieces",
                     "Stands", "Seams bridged", "Seconds"]),
              "|" + "---|" * 19]
    for m in models:
        for s in sizes:
            for a in arms:
                r = by.get((m, s, a))
                if r is None:
                    continue
                check = ("passes" if r["ok"] and r["parts"] > 0
                         else "nothing laid" if r["parts"] == 0 else r["summary"][:48])
                lines.append(_line([
                    m, str(s), a, f"{r['parts']:,}", _fmt(r.get("coverage"), ".0%") if a != "outside" else "—",
                    f"{r['shaped_share']:.0%}", _fmt(r.get("m_iou"), ".3f"), _fmt(r.get("m_chamfer_studs"), ".2f"),
                    _fmt(r.get("m_lost95_studs"), ".2f"), _fmt(r.get("m_added95_studs"), ".2f"),
                    _fmt(r.get("m_normal_deg"), ".1f"),
                    _fmt(r.get("m_de2000"), ".1f"), _fmt(r.get("m_neutral_chromatic"), ".1%"),
                    f"{r['no_element_parts'] / max(1, r['parts']):.1%}", check, str(r["pieces"]),
                    ("on a stand" if r.get("on_stand") else "yes") if r.get("stands") else "no",
                    _fmt(r.get("m_seam_share"), ".0%"),
                    f"{r['seconds']:.1f}"]))
    text = "\n".join(lines) + "\n"
    if args.write:
        Path(args.write).write_text(text)
    print(text)
    return 0


def _whole(r: dict, by: dict) -> bool:
    """Kept the model, judged the same way for every arm, ours or not: laid, and 95% of the
    model's visible surface within a stud of the build's. A lost spout or ear fails it; a
    build grown past the model does not (that is added95). Brickify's own coverage figure
    missed the teapot's spout."""
    return r["parts"] > 0 and r.get("m_lost95_studs") is not None and r["m_lost95_studs"] <= WHOLE_STUDS


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("prepare")
    p.add_argument("--models", required=True)
    p.add_argument("--into", required=True)
    p.add_argument("--sizes", default="24,48")
    p.add_argument("--drop", default="toy-car:fabric")
    p = sub.add_parser("outside")
    p.add_argument("out")
    p.add_argument("--jobs", required=True)
    p.add_argument("--tool", required=True)
    p.add_argument("--home", required=True, help="a scratch HOME holding its LDraw library and generated modules")
    p.add_argument("--only", default="")
    p.add_argument("--timeout", type=int, default=1200)
    p = sub.add_parser("jobs")
    p.add_argument("--models", required=True)
    p.add_argument("--out", required=True)
    p.add_argument("--sizes", default="24,48")
    p = sub.add_parser("measure")
    p.add_argument("out")
    p.add_argument("--only", default="")
    p.add_argument("--file", default="measures.json", help="under OUT; report merges every measures*.json")
    p.add_argument("--arms", default="", help="only these arms, the rest of the file kept")
    p = sub.add_parser("bond")
    p.add_argument("out")
    p = sub.add_parser("faces")
    p.add_argument("out")
    p.add_argument("--only", default="")
    p.add_argument("--res", type=int, default=200)
    p = sub.add_parser("pictures")
    p.add_argument("out")
    p.add_argument("--into", required=True)
    p.add_argument("--only", default="")
    p.add_argument("--res", type=int, default=300)
    p.add_argument("--quality", type=int, default=80)
    p.add_argument("--arms", default="", help="only these arms")
    p.add_argument("--before", default="", help="an earlier run of the same models: each arm before, then after")
    p.add_argument("--cut", action="store_true",
                   help="each build cut in half across z, its parts shaded apart, to see the core's courses")
    p.add_argument("--views", default="corner",
                   help="from where, any of " + ",".join(VIEWS) + " (one sheet each)")
    p = sub.add_parser("report")
    p.add_argument("out")
    p.add_argument("--write", default="")
    args = parser.parse_args()
    return {"prepare": do_prepare, "outside": do_outside, "jobs": do_jobs, "measure": do_measure, "bond": do_bond,
            "faces": do_faces, "pictures": do_pictures, "report": do_report}[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
