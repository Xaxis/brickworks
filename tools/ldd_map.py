#!/usr/bin/env python3
"""LEGO Digital Designer's numbers, mapped to LDraw's: assets/ldraw/ldd.json.

An LDD model (.lxf) names its parts by LEGO design number, its colours by
LEGO material number, and places each part by its own origin, in its own
axes, in centimetres. LDraw names parts by its own file names, colours by
LDConfig's codes, and puts a part's origin somewhere else (a brick's at the
top, LDD's at the bottom). The table that says how for each part is
ldraw.xml, written for LDD's own LDraw export and kept up by the LDraw
community since; Studio and LeoCAD read the same table. This reads it and
writes the three things the app's importer (src/parts/ldd_lxf.gd) needs, in
a form small enough to ship in every build:

    colours  LEGO material -> LDraw colour code
    parts    LDD design number -> LDraw part, where they differ
    origins  LDraw part -> where LDD's origin is in it: tx, ty, tz in LDD
             units, and a turn about (ax, ay, az) by angle radians

Where ldraw.xml names one number twice, the last one is the one meant (its
own notes say so, and lxf2ldr reads it that way).

    tools/fetch_data.sh                       # fetches vendor/ldraw.xml
    python3 tools/ldd_map.py [vendor/ldraw.xml] [assets/ldraw/ldd.json]
"""

from __future__ import annotations

import json
import re
import sys
import xml.etree.ElementTree as ElementTree
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def _name(ldraw: str) -> str:
    """An LDraw file name as the app's catalogue keys it: no .dat, lower case."""
    return re.sub(r"\.dat$", "", ldraw.strip(), flags=re.IGNORECASE).lower()


def _number(text: str) -> float | int:
    value = float(text)
    return int(value) if value.is_integer() else round(value, 6)


def read(path: Path) -> dict:
    root = ElementTree.parse(path).getroot()
    colours: dict[str, int] = {}
    parts: dict[str, str] = {}
    origins: dict[str, list] = {}
    for element in root:
        tag = element.tag
        if tag == "Material":
            lego, ldraw = element.get("lego"), element.get("ldraw")
            if lego and ldraw and ldraw.lstrip("-").isdigit():
                colours[lego] = int(ldraw)
        elif tag == "Brick":
            lego, ldraw = element.get("lego"), element.get("ldraw")
            if lego and ldraw:
                parts[lego] = _name(ldraw)
        elif tag == "Transformation":
            ldraw = element.get("ldraw")
            if not ldraw:
                continue
            try:
                origins[_name(ldraw)] = [_number(element.get(k, "0")) for k in
                                         ("tx", "ty", "tz", "ax", "ay", "az", "angle")]
            except ValueError:
                continue
    # A design number that is its own LDraw name needs no row.
    parts = {lego: ldraw for lego, ldraw in parts.items() if ldraw != lego.lower()}
    comment = root.get("comment", "")
    dated = ""
    raw = path.read_text(encoding="utf-8", errors="replace")
    found = re.search(r"<!--\s*\n?\s*(\d{4}-\d{2}-\d{2})", raw)
    if found:
        dated = found.group(1)
    return {
        "source": "ldraw.xml %s (%s): LDD's LDraw table as kept by Sylvain Sauvage "
                  "and others; see docs/ATTRIBUTION.md" % (dated, comment),
        "colours": dict(sorted(colours.items(), key=lambda kv: int(kv[0]))),
        "parts": dict(sorted(parts.items())),
        "origins": dict(sorted(origins.items())),
    }


def main(argv: list[str]) -> int:
    source = Path(argv[1]) if len(argv) > 1 else ROOT / "vendor" / "ldraw.xml"
    target = Path(argv[2]) if len(argv) > 2 else ROOT / "assets" / "ldraw" / "ldd.json"
    if not source.exists():
        print(f"no {source}: tools/fetch_data.sh fetches it", file=sys.stderr)
        return 1
    table = read(source)
    target.write_text(json.dumps(table, separators=(",", ":")) + "\n", encoding="utf-8")
    print(f"wrote {target}: {len(table['colours'])} colours, {len(table['parts'])} parts "
          f"renamed, {len(table['origins'])} origins, {target.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
