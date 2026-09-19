#!/usr/bin/env python3
"""Rewrite catalogue.json and colors.json without rebuilding geometry.

The meshes are the expensive part of a build and they only change when
the geometry does. Metadata — names, categories, redirects, colour
finishes — changes far more often, and re-voxelising 24,731 parts to
correct a field is forty-five minutes spent to move some strings.

This reads the existing catalogue for the mesh hashes and per-part
geometry facts, and refreshes everything that comes from the library
headers and LDConfig around them.
"""

from __future__ import annotations

import json
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from ldraw.colors import Palette          # noqa: E402
from ldraw.library import Library         # noqa: E402

GENERATED = ROOT / "assets" / "generated"
LDRAW = ROOT / "vendor" / "ldraw"


def main() -> int:
    path = GENERATED / "catalogue.json"
    if not path.exists():
        print(f"no catalogue at {path} — run tools/build_meshes.py first")
        return 1

    document = json.loads(path.read_text())
    library = Library(LDRAW)

    changed = 0
    redirects = 0
    for entry in document["parts"]:
        ldfile = library.get(entry["id"] + ".dat")
        if ldfile is None:
            continue
        before = dict(entry)
        entry["name"] = ldfile.description
        entry["category"] = ldfile.category
        entry["kind"] = ldfile.part_type or "Part"
        entry["moved_to"] = ldfile.moved_to
        if ldfile.moved_to:
            redirects += 1
        if entry != before:
            changed += 1

    document["generated"] = int(time.time())
    path.write_text(json.dumps(document, separators=(",", ":")))

    palette = Palette.from_file(LDRAW / "LDConfig.ldr")
    colors = []
    for color in palette:
        item = {
            "code": color.code,
            "name": color.name.replace("_", " "),
            "rgb": list(color.value),
            "edge": list(color.edge),
            "alpha": color.alpha,
            "luminance": color.luminance,
            "finish": color.finish.value,
        }
        if color.material:
            item["material"] = {
                "kind": color.material.kind.lower(),
                "rgb": list(color.material.value),
                "fraction": color.material.fraction,
            }
        colors.append(item)
    (GENERATED / "colors.json").write_text(json.dumps(colors, separators=(",", ":")))

    from collections import Counter
    buckets = Counter(c["finish"] for c in colors)
    print(f"catalogue: {len(document['parts']):,} parts, {changed:,} updated, "
          f"{redirects:,} redirects marked")
    print(f"colours: {len(colors)} — " +
          ", ".join(f"{k} {v}" for k, v in buckets.most_common()))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
