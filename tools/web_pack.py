#!/usr/bin/env python3
"""Choose the parts the web build ships with.

The full library is 875 MB of geometry. Nobody is going to wait for that
before placing their first brick, so the web build carries a working set
and the catalogue for everything else.

What that means in practice: you can browse and search all 24,731 parts,
and the ones you can actually place are the ones in the pack. A part
without geometry is already handled — the library returns null and the
placement is refused — so the failure is a part that will not appear, not
a broken build.

The working set is chosen, not sampled:

* every part any bundled model uses, so the models that ship actually open
* the starter palette the builder and the design assistant offer
* the parts those pull in as alternates — a design that asks for a 1x6
  brick should find the 1x8 beside it

    tools/web_pack.py                 write assets/web/
    tools/web_pack.py --budget 40     stop at 40 MB
    tools/web_pack.py --list          say what would be included, write nothing
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

GENERATED = ROOT / "assets" / "generated"
WEB = ROOT / "assets" / "web"

# Families worth carrying whole: the plain bricks, plates, tiles and
# slopes that most building is done with. Matched against the part's
# description, so "Brick  1 x  4" is caught by "brick".
FAMILIES: tuple[tuple[str, int], ...] = (
    ("brick", 240),
    ("plate", 260),
    ("tile", 140),
    ("slope", 160),
    ("baseplate", 12),
)

# Parts the build is not usable without, whatever they weigh. The 32x32
# baseplate is 49,000 triangles and would sort last on every heuristic,
# but without something to build on the first brick has nowhere to go.
ESSENTIAL: tuple[str, ...] = (
    "3811",    # Baseplate 32 x 32
    "3857",    # Baseplate 16 x 16
    "3001", "3003", "3004", "3005", "3020", "3024", "3068b", "3070b",
)

# Patterns that are never worth the bytes on the web: printed variants,
# stickers, and the many near-duplicates of a mould.
SKIP = re.compile(
    r"sticker|^~|duplo|quatro|primo|scala|belville|znap|modulex|fabuland"
    r"|homemaker|mursten|electric|motor|figure ", re.IGNORECASE)


def parts_used_by_models() -> set[str]:
    """Every part id referenced by a .ldr or .mpd we ship."""
    used: set[str] = set()
    roots = [ROOT / "models", ROOT / "vendor" / "ldraw" / "models"]
    for root in roots:
        if not root.is_dir():
            continue
        for path in root.iterdir():
            if path.suffix.lower() not in (".ldr", ".mpd", ".dat"):
                continue
            for line in path.read_text(errors="ignore").splitlines():
                tokens = line.split()
                if len(tokens) >= 15 and tokens[0] == "1":
                    name = " ".join(tokens[14:]).replace("\\", "/").lower()
                    stem = name.rsplit("/", 1)[-1]
                    for suffix in (".dat", ".ldr"):
                        if stem.endswith(suffix):
                            stem = stem[: -len(suffix)]
                    used.add(stem)
    return used


def starter_palette() -> set[str]:
    """The parts the builder and the design assistant offer by name."""
    wanted: set[str] = set()

    designer = ROOT / "brain" / "designer.py"
    if designer.exists():
        text = designer.read_text()
        block = text.split("PALETTE: tuple[str, ...] = (", 1)
        if len(block) == 2:
            wanted |= set(re.findall(r'"([^"]+)"', block[1].split(")", 1)[0]))

    main = ROOT / "src" / "main.gd"
    if main.exists():
        text = main.read_text()
        block = text.split("QUICK_PARTS: Array[String] = [", 1)
        if len(block) == 2:
            wanted |= set(re.findall(r'"([^"]+)"', block[1].split("]", 1)[0]))
    return wanted


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--budget", type=float, default=48.0,
                        help="megabytes of geometry to stop at")
    parser.add_argument("--out", default=str(WEB))
    parser.add_argument("--in-storage", action="store_true",
                        help="the geometry is served from object storage, so "
                             "put none of it in the deployment and mark every "
                             "part reachable (tools/storage_parts.py)")
    parser.add_argument("--remote-budget", type=float, default=120.0,
                        help="megabytes of extra geometry to publish for "
                             "fetching on demand")
    parser.add_argument("--list", action="store_true")
    args = parser.parse_args()

    catalogue_path = GENERATED / "catalogue.json"
    if not catalogue_path.exists():
        print(f"no catalogue at {catalogue_path} — run tools/build_meshes.py")
        return 1
    document = json.loads(catalogue_path.read_text())
    by_id = {p["id"]: p for p in document["parts"]}

    required = (
        parts_used_by_models() | starter_palette() | set(ESSENTIAL)
    ) & set(by_id)
    chosen: dict[str, dict] = {pid: by_id[pid] for pid in sorted(required)}

    # Then fill the families, smallest first: a small mesh is both more
    # likely to be a plain useful part and cheaper to carry.
    for keyword, cap in FAMILIES:
        candidates = [
            p for p in document["parts"]
            if keyword in p.get("category", "").lower()
            and not SKIP.search(p.get("name", ""))
            and not p.get("unofficial", False)
            and p["id"] not in chosen
        ]
        candidates.sort(key=lambda p: p.get("triangles", 0))
        for part in candidates[:cap]:
            chosen[part["id"]] = part

    # Weigh it, dropping the largest if over budget.
    sizes: dict[str, int] = {}
    for part in chosen.values():
        path = GENERATED / "parts" / f"{part['mesh']}.lbm"
        sizes[part["mesh"]] = path.stat().st_size if path.exists() else 0

    def total() -> int:
        return sum(set_size for set_size in {
            p["mesh"]: sizes.get(p["mesh"], 0) for p in chosen.values()
        }.values())

    budget = int(args.budget * 1_000_000)
    while total() > budget:
        heaviest = max(
            (p for p in chosen.values() if p["id"] not in required),
            key=lambda p: sizes.get(p["mesh"], 0),
            default=None)
        if heaviest is None:
            break
        del chosen[heaviest["id"]]

    meshes = {p["mesh"] for p in chosen.values()}
    print(f"web pack: {len(chosen):,} parts, {len(meshes):,} meshes, "
          f"{total() / 1e6:.1f} MB of geometry")
    print(f"  required by models and palette: {len(required)}")
    if args.list:
        for part in sorted(chosen.values(), key=lambda p: p["id"])[:40]:
            print(f"    {part['id']:10s} {part['name'][:48]}")
        print(f"    ... {len(chosen) - 40} more")
        return 0

    out = Path(args.out)
    if out.exists():
        shutil.rmtree(out)
    (out / "parts").mkdir(parents=True)

    for mesh in meshes:
        source = GENERATED / "parts" / f"{mesh}.lbm"
        if source.exists():
            shutil.copy2(source, out / "parts" / f"{mesh}.lbm")

    # The catalogue keeps every part, so search still reaches the whole
    # library; a flag says which ones can actually be placed.
    for part in document["parts"]:
        part["packed"] = part["id"] in chosen
    document["web_pack"] = {
        "parts": len(chosen), "meshes": len(meshes), "bytes": total()}
    (out / "catalogue.json").write_text(
        json.dumps(document, separators=(",", ":")))
    shutil.copy2(GENERATED / "colors.json", out / "colors.json")

    _write_remote(out, document, meshes, args.remote_budget, args.in_storage)

    written = sum(f.stat().st_size for f in out.rglob("*") if f.is_file())
    print(f"  wrote {out} ({written / 1e6:.1f} MB total)")
    return 0


def _write_remote(
    out: Path, document: dict, packed: set[str], budget_mb: float,
    in_storage: bool = False,
) -> None:
    """Geometry the app fetches on demand rather than carrying.

    The pack has to be small because everyone waits for it. This set does
    not: a part is fetched the moment someone picks it, so what matters
    is that it exists at all. The cap is on the *deployment*, not on the
    wait — every file here costs upload time on each deploy and nothing
    at load time.

    Smallest first, which is not arbitrary. The library's size is a long
    tail: the smallest 20,000 meshes come to 279 MB and the remaining
    7,000 come to 747 MB, because a 48x48 baseplate is 50,000 triangles.
    Taking the small ones first buys far more parts per megabyte, and the
    ones left out are the ones nobody reaches for by accident.

    With ``--in-storage`` none of that applies. The geometry is uploaded
    once to object storage (tools/storage_parts.py) and served from
    there, so the deployment carries no parts at all, every part is
    reachable, and a deploy goes from fourteen thousand files to a few
    dozen. That is the arrangement the hosted build uses; the budget
    remains for a deployment that has to be self-contained.
    """
    if in_storage:
        for part in document["parts"]:
            part["reachable"] = True
        (out / "catalogue.json").write_text(
            json.dumps(document, separators=(",", ":")))
        print(f"  on demand: from object storage — all "
              f"{len(document['parts']):,} parts placeable, nothing in the deploy")
        return

    remote = out / "remote"
    remote.mkdir(parents=True, exist_ok=True)

    sizes: list[tuple[int, str]] = []
    for part in document["parts"]:
        mesh = part["mesh"]
        if mesh in packed:
            continue
        source = GENERATED / "parts" / f"{mesh}.lbm"
        if source.exists():
            sizes.append((source.stat().st_size, mesh))

    sizes.sort()
    budget = int(budget_mb * 1_000_000)
    used = 0
    taken: set[str] = set()
    for size, mesh in sizes:
        if mesh in taken:
            continue
        if used + size > budget:
            break
        shutil.copy2(GENERATED / "parts" / f"{mesh}.lbm", remote / f"{mesh}.lbm")
        taken.add(mesh)
        used += size

    reachable = sum(
        1 for p in document["parts"] if p["mesh"] in packed or p["mesh"] in taken)
    for part in document["parts"]:
        part["reachable"] = part["mesh"] in packed or part["mesh"] in taken
    (out / "catalogue.json").write_text(
        json.dumps(document, separators=(",", ":")))

    print(f"  on demand: {len(taken):,} more meshes, {used / 1e6:.0f} MB "
          f"— {reachable:,} of {len(document['parts']):,} parts placeable")


if __name__ == "__main__":
    raise SystemExit(main())
