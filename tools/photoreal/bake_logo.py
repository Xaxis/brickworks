#!/usr/bin/env python3
"""bake_logo.py: the stud logo's letters as the path tracer raises them (photoreal7).

LDraw's raised stud logo (p/logo5.dat, Magnus Forsberg, CC BY 4.0) drawn from above into a
height map, assets/render/stud_logo.png: 12 LDU square round a stud's middle (the stud is
12 across), each pixel how high the letters stand there, 0 to 1 of LOGO_HEIGHT in
path_tracer.glsl. Its letters' own outlines, not a drawn stand-in: photoreal3 to 6 drew them
as strokes and the judge read them as "mirrored", "garbled" or "drawn on" in 32 to 47 of 80
verdicts.

The tracer reads it with p (stud_logo: x along the letters, y towards their tops) as
uv = p / 12 + 0.5, so a column is p.x and a row p.y. logo5.dat's letters read along its +z
with their tops towards -x, so p.x is z and p.y is -x.

Each letter's edge rounds over, a quarter circle ROUND LDU across up to its top (a moulded
letter's shoulder, which catches the light as a line), where logo5.dat's chamfer is flat.

    tools/photoreal/bake_logo.py [--logo vendor/ldraw/p/logo5.dat] [--out assets/render/stud_logo.png]
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

SPAN = 12.0
SIZE = 512
FINE = 4
ROUND = 0.22


def faces(path: Path) -> list[list[tuple[float, float]]]:
    """logo5.dat's faces seen from above, each as (p.x, p.y) points."""
    found = []
    for line in path.read_text().splitlines():
        f = line.split()
        if not f or f[0] not in ("3", "4"):
            continue
        v = [float(t) for t in f[2:]]
        found.append([(v[i + 2], -v[i]) for i in range(0, len(v), 3)])
    return found


def footprint(shapes: list[list[tuple[float, float]]]) -> Image.Image:
    """Where the letters stand, FINE times SIZE across, 255 inside."""
    n = SIZE * FINE
    image = Image.new("L", (n, n), 0)
    draw = ImageDraw.Draw(image)
    for shape in shapes:
        draw.polygon([((x / SPAN + 0.5) * n, (y / SPAN + 0.5) * n) for x, y in shape], fill=255)
    return image


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    root = Path(__file__).resolve().parents[2]
    parser.add_argument("--logo", type=Path, default=root / "vendor/ldraw/p/logo5.dat")
    parser.add_argument("--out", type=Path, default=root / "assets/render/stud_logo.png")
    args = parser.parse_args()
    shapes = faces(args.logo)
    inside = footprint(shapes).resize((SIZE, SIZE), Image.BOX)
    inside = inside.point(lambda v: 255 if v >= 128 else 0)
    # How far in from the edge, a pixel at a time: each erosion, alternately a square and a
    # cross, takes one off, so the count of erosions a pixel lives through is near its
    # distance in.
    step = SPAN / SIZE
    rings = math.ceil(ROUND / step)
    deep = Image.new("L", (SIZE, SIZE), 0)
    left = inside
    for n in range(rings):
        deep = ImageChops.add(deep, left.point(lambda v: 1 if v else 0))
        if n % 2:
            left = left.filter(ImageFilter.MinFilter(3))
        else:
            # A cross's erosion: the least of the pixel and its four neighbours.
            moved = [ImageChops.offset(left, dx, dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
            for m in moved:
                left = ImageChops.darker(left, m)

    def height(count: int) -> int:
        if count <= 0:
            return 0
        d = min((count - 0.5) * step, ROUND) / ROUND
        return round(255 * math.sqrt(max(0.0, 1.0 - (1.0 - d) ** 2)))

    out = deep.point([height(v) for v in range(256)]).filter(ImageFilter.GaussianBlur(0.6))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    out.save(args.out, optimize=True)
    print(f"{args.out}: {SIZE} square over {SPAN:g} LDU, {len(shapes)} faces, shoulder {ROUND} LDU "
          f"({rings} pixels)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
