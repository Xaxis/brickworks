#!/usr/bin/env python3
"""Convert the LDraw library into the app's mesh files and catalogue.

    tools/build_meshes.py                     everything
    tools/build_meshes.py --limit 200         a sample, for iterating
    tools/build_meshes.py --only 3001 3024    named parts
    tools/build_meshes.py --out DIR           somewhere other than the default

Output, under ``assets/generated/``:

    parts/<id>.lbm        geometry, one file per distinct shape
    catalogue.json        every part: name, size, category, connectors,
                          and which mesh file to load

Geometry is de-duplicated by content hash.  Aliases ("~Moved to ...") and
parts that differ only in metadata then share one file, and the catalogue
points several ids at it.

Parts are independent, so this fans out across cores.  A full build is a
few minutes; it is incremental only in the sense that it is cheap enough
not to need to be.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sys
import time
from dataclasses import asdict, dataclass, field
from multiprocessing import Pool
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from ldraw import meshfile  # noqa: E402
from ldraw.colors import Palette  # noqa: E402
from ldraw.connectivity import extract as extract_connections  # noqa: E402
from ldraw.geometry import flatten  # noqa: E402
from ldraw.library import Library  # noqa: E402
from ldraw import occupancy as occ  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_LDRAW = ROOT / "vendor" / "ldraw"
DEFAULT_OUT = ROOT / "assets" / "generated"


@dataclass
class PartRecord:
    """One catalogue entry.  Mirrors what the runtime needs, nothing more."""

    id: str                      # "3001", the LDraw number without .dat
    name: str                    # "Brick  2 x  4"
    category: str
    kind: str                    # Part / Shortcut / Part Alias / ...
    mesh: str                    # content hash naming the .lbm file
    triangles: int
    size_ldu: tuple[float, float, float]
    bounds_min: tuple[float, float, float]
    bounds_max: tuple[float, float, float]
    # Counts only. The connectors, collision boxes and sockets themselves
    # live in the .lbm beside the geometry, because they are wanted at the
    # same moment it is and putting them here took the catalogue past 25 MB.
    stud_count: int = 0
    socket_count: int = 0
    connector_counts: dict[str, int] = field(default_factory=dict)
    box_count: int = 0
    keywords: list[str] = field(default_factory=list)
    # Colours the part is moulded in when it is not recolourable.
    fixed_colors: list[int] = field(default_factory=list)
    recolourable: bool = True
    unofficial: bool = False
    # Set when this id is a redirect stub: the part it was renamed to.
    # 1,160 of these exist and none is tagged as an Alias, so they can
    # only be found by their title.
    moved_to: str = ""


_LIBRARY: Library | None = None
_LDRAW_ROOT: Path = DEFAULT_LDRAW


def _init(ldraw_root: str) -> None:
    global _LIBRARY, _LDRAW_ROOT
    _LDRAW_ROOT = Path(ldraw_root)
    _LIBRARY = Library(_LDRAW_ROOT)


def _convert(name: str) -> tuple[str, bytes, dict] | tuple[str, None, dict]:
    """Convert one part.  Returns (mesh hash, blob, record dict).

    Runs in a worker process, so it returns plain data rather than
    objects and never raises: one malformed part must not stop a build of
    twenty thousand.
    """
    assert _LIBRARY is not None
    part_id = name[:-4] if name.endswith(".dat") else name

    try:
        ldfile = _LIBRARY.get(name)
        if ldfile is None:
            return (part_id, None, {"error": "not found"})

        mesh = flatten(_LIBRARY, name)
        if not mesh.triangles:
            return (part_id, None, {"error": "no geometry"})

        part = meshfile.build(mesh)

        # Occupancy: solid volume for collision, and the underside sockets
        # the primitives cannot tell us about.
        connections = extract_connections(_LIBRARY, name)
        solid = occ.fill_cavities(occ.remove_studs(occ.voxelise(mesh), connections))

        counts: dict[str, int] = {}
        for connection in connections:
            counts[connection.kind.value] = counts.get(connection.kind.value, 0) + 1
            part.connectors.append(meshfile.ConnectorOut(
                kind=connection.kind.value,
                gender=connection.gender.value,
                # The same axis change the mesh gets, so the two agree.
                pos=(connection.position.x, -connection.position.y,
                     -connection.position.z),
                axis=(connection.axis.x, -connection.axis.y, -connection.axis.z),
            ))
        part.boxes = [tuple(int(v) for v in box) for box in occ.to_boxes(solid)]
        part.sockets = [(float(x), float(z)) for x, z in occ.bottom_sockets(solid)]
        part.cell_ldu = occ.CELL

        blob = meshfile.write(part)
        digest = hashlib.blake2b(blob, digest_size=10).hexdigest()

        fixed = sorted({s.color for s in part.surfaces if s.color != 16})
        record = PartRecord(
            id=part_id,
            name=ldfile.description,
            category=ldfile.category,
            kind=ldfile.part_type or "Part",
            mesh=digest,
            triangles=part.triangle_count,
            size_ldu=tuple(round(v, 3) for v in part.size_ldu()),  # type: ignore[arg-type]
            bounds_min=tuple(round(v, 3) for v in part.bounds_min),  # type: ignore[arg-type]
            bounds_max=tuple(round(v, 3) for v in part.bounds_max),  # type: ignore[arg-type]
            stud_count=counts.get("stud", 0),
            socket_count=len(part.sockets),
            connector_counts=counts,
            box_count=len(part.boxes),
            keywords=ldfile.keywords[:12],
            fixed_colors=fixed,
            recolourable=any(s.color == 16 for s in part.surfaces),
            unofficial="unofficial" in str(ldfile.path),
            moved_to=ldfile.moved_to,
        )
        return (part_id, blob, asdict(record))

    except Exception as exc:  # noqa: BLE001 — a worker must not take the build down
        return (part_id, None, {"error": f"{type(exc).__name__}: {exc}"})


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--ldraw", default=str(DEFAULT_LDRAW))
    parser.add_argument("--out", default=str(DEFAULT_OUT))
    parser.add_argument("--limit", type=int, default=0)
    parser.add_argument("--only", nargs="*", default=None)
    parser.add_argument("--jobs", type=int, default=os.cpu_count() or 4)
    args = parser.parse_args()

    ldraw_root = Path(args.ldraw)
    out = Path(args.out)
    (out / "parts").mkdir(parents=True, exist_ok=True)

    library = Library(ldraw_root)
    if args.only:
        names = [n if n.endswith(".dat") else f"{n}.dat" for n in args.only]
    else:
        names = library.part_names()
        if args.limit:
            names = names[: args.limit]

    print(f"converting {len(names):,} parts with {args.jobs} workers")
    started = time.time()

    catalogue: list[dict] = []
    failures: list[tuple[str, str]] = []
    written: set[str] = set()
    bytes_written = 0
    deduped = 0

    with Pool(args.jobs, initializer=_init, initargs=(str(ldraw_root),)) as pool:
        for n, (part_id, blob, record) in enumerate(
            pool.imap_unordered(_convert, names, chunksize=32), start=1
        ):
            if blob is None:
                failures.append((part_id, record.get("error", "unknown")))
            else:
                digest = record["mesh"]
                if digest in written:
                    deduped += 1
                else:
                    (out / "parts" / f"{digest}.lbm").write_bytes(blob)
                    written.add(digest)
                    bytes_written += len(blob)
                catalogue.append(record)

            if n % 2000 == 0:
                rate = n / (time.time() - started)
                print(f"  {n:6,}/{len(names):,}  {rate:5.0f}/s  {len(written):,} meshes")

    # Meshes from a previous build that nothing points at any more. The
    # content hash means most survive a rebuild untouched, so this is
    # usually a handful — but without it a library update leaves the old
    # geometry on disk forever.
    orphans = 0
    freed = 0
    if not args.only and not args.limit:
        for mesh_file in (out / "parts").iterdir():
            if mesh_file.suffix == ".lbm" and mesh_file.stem not in written:
                freed += mesh_file.stat().st_size
                mesh_file.unlink()
                orphans += 1

    catalogue.sort(key=lambda r: r["id"])
    palette = Palette.from_file(ldraw_root / "LDConfig.ldr")

    index = {
        "format": 1,
        "unit": "LDU",
        "ldu_mm": meshfile.LDU_MM,
        "cell_ldu": occ.CELL,
        "up_axis": "+Y",
        "generated": int(time.time()),
        "counts": {
            "parts": len(catalogue),
            "meshes": len(written),
            "failed": len(failures),
            "colors": len(palette),
        },
        "parts": catalogue,
    }
    (out / "catalogue.json").write_text(json.dumps(index, separators=(",", ":")))
    _write_colors(out, palette)

    elapsed = time.time() - started
    print(f"\ndone in {elapsed:.0f}s")
    print(f"  parts catalogued : {len(catalogue):,}")
    print(f"  distinct meshes  : {len(written):,}  ({deduped:,} shared an existing one)")
    print(f"  geometry on disk : {bytes_written / 1e6:,.0f} MB")
    if orphans:
        print(f"  orphans removed  : {orphans:,}  ({freed / 1e6:,.0f} MB freed)")
    print(f"  failed           : {len(failures):,}")
    for part_id, reason in failures[:10]:
        print(f"      {part_id}: {reason}")
    if len(failures) > 10:
        print(f"      ... and {len(failures) - 10:,} more")
    return 0


def _write_colors(out: Path, palette: Palette) -> None:
    colors = []
    for color in palette:
        entry = {
            "code": color.code,
            "name": color.name.replace("_", " "),
            "rgb": list(color.value),
            "edge": list(color.edge),
            "alpha": color.alpha,
            "luminance": color.luminance,
            "finish": color.finish.value,
        }
        if color.material:
            entry["material"] = {
                "kind": color.material.kind.lower(),
                "rgb": list(color.material.value),
                "fraction": color.material.fraction,
            }
        colors.append(entry)
    (out / "colors.json").write_text(json.dumps(colors, separators=(",", ":")))


if __name__ == "__main__":
    raise SystemExit(main())
