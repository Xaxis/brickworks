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

    made = _availability(document, colors)
    ordered = _elements(document, colors)
    normal = _set_norms(document)

    document["generated"] = int(time.time())
    path.write_text(json.dumps(document, separators=(",", ":")))

    from collections import Counter
    buckets = Counter(c["finish"] for c in colors)
    print(f"catalogue: {len(document['parts']):,} parts, {changed:,} updated, "
          f"{redirects:,} redirects marked")
    print(f"colours: {len(colors)} — " +
          ", ".join(f"{k} {v}" for k, v in buckets.most_common()))
    print(made)
    print(ordered)
    print(normal)
    return 0


def _set_norms(document: dict) -> str:
    """Record what a real set of each size is made of.

    Small enough to live in the catalogue header — five bands of four
    numbers — and it has to travel with the app, because the question it
    answers is asked while designing.
    """
    document.pop("set_norms", None)
    try:
        import rebrickable
    except ImportError:
        return "set norms: skipped (tools/rebrickable.py missing)"
    try:
        norms = rebrickable.set_norms()
    except FileNotFoundError as missing:
        return f"set norms: skipped ({missing})"
    document["set_norms"] = norms
    bands = norms["bands"]
    counted = sum(band["sets"] for band in bands)
    middle = bands[len(bands) // 2] if bands else {}
    return ("set norms: %d bands over %d real sets — one of %d-%d parts has "
            "%d lots, %d shapes, at most %d of any one part"
            % (len(bands), counted, middle.get("from", 0), middle.get("to", 0),
               middle.get("lots", 0), middle.get("shapes", 0),
               middle.get("most_of_one", 0)))


def _elements(document: dict, colors: list[dict]) -> str:
    """Write the part-and-colour to LEGO element number index.

    Kept out of the catalogue and in its own file: it is 0.8 MB that only
    a parts list needs, and the catalogue is loaded at start-up by
    everything.
    """
    path = GENERATED / "elements.json"
    try:
        import rebrickable
    except ImportError:
        return "elements: skipped (tools/rebrickable.py missing)"
    try:
        found = rebrickable.elements(document["parts"], colors)
    except FileNotFoundError as missing:
        return f"elements: skipped ({missing})"
    path.write_text(json.dumps(found, separators=(",", ":")))
    counts = found["counts"]
    return ("elements: %d part-and-colour pairs over %d parts, %d by mould "
            "variant, %.1f MB"
            % (len(found["pairs"]),
               len({key.split("/")[0] for key in found["pairs"]}),
               counts["by mould variant"],
               path.stat().st_size / 1e6))


def _availability(document: dict, colors: list[dict]) -> str:
    """Write onto each part the colours it was really made in.

    Optional on purpose.  A clone that has not run tools/fetch_data.sh
    still gets a working catalogue; it just cannot say what is buyable,
    and every reader treats a missing list as "no idea" rather than as
    "never made".
    """
    entries = document["parts"]
    document.pop("availability", None)
    for entry in entries:                 # never leave a stale answer behind
        for field in ("colors", "colors_recent", "colors_partial", "years"):
            entry.pop(field, None)
    try:
        import rebrickable
    except ImportError:
        return "availability: skipped (tools/rebrickable.py missing)"
    try:
        made = rebrickable.availability(entries, colors)
    except FileNotFoundError as missing:
        return f"availability: skipped ({missing})"

    for entry in entries:
        entry.update(made["parts"].get(entry["id"], {}))
    document["availability"] = {
        "source": made["source"],
        "recent_since": made["recent_since"],
        "colours_mapped": made["colours_mapped"],
    }
    counts = made["counts"]
    known = len(made["parts"])
    return ("availability: %d parts of %d with a colour list (%d of those "
            "partial), %d colours named, recent means %d or later"
            % (known, known + counts["unknown"], counts["partial"],
               made["colours_mapped"], made["recent_since"]))


if __name__ == "__main__":
    raise SystemExit(main())
