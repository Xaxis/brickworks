#!/usr/bin/env python3
"""tools/photoreal/reflect_measure.py [--only a,b] [--overlay DIR] [LABEL=DIR ...] : what each close-up's glossy
faces mirror, the photographs beside renders (photoreal14).

A glossy part is mostly what it reflects. The lead's look at photoreal13's pictures: the black 2x4's top
mirrors a bright room in its photograph and is darker than its side in ours, and the red slope lacks the
softbox's sharp lines along its edges. These are those, measured on boxes and lines placed by hand on each
photograph and on the render's camera (shots.json "reflect": the same place on the part in both):

  top/side  a flat top's light over a side's, in stops: log2 of the mean linear luminance (sRGB decoded)
            of the top's box over the side's, each box's lightest and darkest tenth left out. A glossy top
            facing a bright source is many stops over a side facing the room.
  lines     each edge's line of light, read across the edge at 15 places along it and averaged, each
            profile slid onto its own peak first: width, the full width at half of the peak's rise over
            the brighter face beside it (pixels at the shot's size, 1024 wide); rise, the peak over that
            face in stops; sharp, the steepest step on the profile's flanks as a share of the rise per
            pixel (1 a line with no flank, about 0.5 a line two pixels wide)

  LABEL=DIR       renders: DIR/<shot>.png for each close-up (photoreal_probe's tags)
  --overlay DIR   also write DIR/<shot>.jpg: each box and line drawn on the photograph and on the first render
  --json FILE     also write every number to FILE
"""
from __future__ import annotations

import json
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from bench import photoreal  # noqa: E402

PROFILES = 15
HALF = 14  # pixels either side of an edge, read across it
SLIDE = 6  # how far a profile may slide onto its own peak


def lin(c: float) -> float:
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def luminance_of(image: Image.Image) -> list[list[float]]:
    px = image.load()
    w, h = image.size
    table = [lin(v) for v in range(256)]
    return [[0.2126 * table[px[x, y][0]] + 0.7152 * table[px[x, y][1]] + 0.0722 * table[px[x, y][2]]
             for x in range(w)] for y in range(h)]


def box_level(lum: list[list[float]], box: list[float]) -> float:
    h, w = len(lum), len(lum[0])
    x0, y0 = int(box[0] * w), int(box[1] * h)
    x1, y1 = max(int(box[2] * w), x0 + 1), max(int(box[3] * h), y0 + 1)
    values = sorted(lum[y][x] for y in range(y0, y1) for x in range(x0, x1))
    cut = len(values) // 10
    kept = values[cut: len(values) - cut] or values
    return sum(kept) / len(kept)


def sample(lum: list[list[float]], x: float, y: float) -> float:
    h, w = len(lum), len(lum[0])
    x = min(max(x, 0.0), w - 1.001)
    y = min(max(y, 0.0), h - 1.001)
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    return (lum[y0][x0] * (1 - fx) * (1 - fy) + lum[y0][x0 + 1] * fx * (1 - fy)
            + lum[y0 + 1][x0] * (1 - fx) * fy + lum[y0 + 1][x0 + 1] * fx * fy)


def line_profile(lum: list[list[float]], seg: list[float]) -> list[float]:
    """The mean profile across an edge, from seg[0:2] to seg[2:4] (fractions), each slid onto its peak."""
    h, w = len(lum), len(lum[0])
    ax, ay, bx, by = seg[0] * w, seg[1] * h, seg[2] * w, seg[3] * h
    length = math.hypot(bx - ax, by - ay)
    tx, ty = (bx - ax) / length, (by - ay) / length
    nx, ny = -ty, tx
    total = [0.0] * (2 * HALF + 1)
    for i in range(PROFILES):
        t = 0.15 + 0.7 * i / (PROFILES - 1)
        cx, cy = ax + (bx - ax) * t, ay + (by - ay) * t
        wide = [sample(lum, cx + nx * s, cy + ny * s) for s in range(-HALF - SLIDE, HALF + SLIDE + 1)]
        middle = range(SLIDE, len(wide) - SLIDE)
        # the peak nearest the drawn line, within SLIDE of it
        peak = max(range(HALF, HALF + 2 * SLIDE + 1), key=lambda k: wide[k])
        shift = peak - (HALF + SLIDE)
        for k in range(2 * HALF + 1):
            total[k] += wide[k + SLIDE + shift]
        del middle
    return [v / PROFILES for v in total]


def line_measure(profile: list[float]) -> dict:
    mid = HALF
    peak = profile[mid]
    left = sorted(profile[: mid - 5])[len(profile[: mid - 5]) // 2]
    right = sorted(profile[mid + 6:])[len(profile[mid + 6:]) // 2]
    face = max(left, right)
    rise = peak - face
    if rise <= 1e-5:
        return {"width": float("nan"), "rise": 0.0, "sharp": float("nan")}
    half = face + rise / 2
    # the half crossings either side, interpolated
    a = mid
    while a > 0 and profile[a] > half:
        a -= 1
    b = mid
    while b < len(profile) - 1 and profile[b] > half:
        b += 1
    fa = a + (half - profile[a]) / (profile[a + 1] - profile[a]) if profile[a + 1] != profile[a] else a
    fb = b - (half - profile[b]) / (profile[b - 1] - profile[b]) if profile[b - 1] != profile[b] else b
    steps = [abs(profile[k + 1] - profile[k]) for k in range(max(a - 2, 0), min(b + 2, len(profile) - 1))]
    return {"width": fb - fa, "rise": math.log2(peak / max(face, 1e-5)), "sharp": max(steps) / rise}


def measure(image: Image.Image, said: dict, who: str) -> dict:
    lum = luminance_of(image)
    out: dict = {}
    if "top" in said and "side" in said:
        top, side = box_level(lum, said["top"][who]), box_level(lum, said["side"][who])
        out["top"] = top
        out["side"] = side
        out["stops"] = math.log2(max(top, 1e-5) / max(side, 1e-5))
    out["lines"] = {}
    for line in said.get("lines", []):
        out["lines"][line["name"]] = line_measure(line_profile(lum, line[who]))
    return out


def overlay(image: Image.Image, said: dict, who: str) -> Image.Image:
    image = image.copy()
    d = ImageDraw.Draw(image)
    w, h = image.size
    for key, colour in (("top", (0, 255, 0)), ("side", (255, 0, 255))):
        if key in said:
            b = said[key][who]
            d.rectangle([b[0] * w, b[1] * h, b[2] * w, b[3] * h], outline=colour, width=2)
    for line in said.get("lines", []):
        s = line[who]
        d.line([s[0] * w, s[1] * h, s[2] * w, s[3] * h], fill=(0, 255, 255), width=1)
        d.text((s[0] * w + 3, s[1] * h + 3), line["name"], fill=(255, 255, 0))
    return image


def row(label: str, m: dict) -> str:
    parts = [f"  {label:12s}"]
    if "stops" in m:
        parts.append(f"top/side {m['stops']:+5.2f} stops (top {m['top']:.4f}, side {m['side']:.4f})")
    for name, v in m["lines"].items():
        parts.append(f"| {name}: width {v['width']:4.1f} px rise {v['rise']:+4.2f} sharp {v['sharp']:.2f}")
    return " ".join(parts)


def main() -> int:
    args = sys.argv[1:]
    only, over, dump = None, None, None
    if "--only" in args:
        i = args.index("--only"); only = args[i + 1].split(","); del args[i:i + 2]
    if "--overlay" in args:
        i = args.index("--overlay"); over = Path(args[i + 1]); del args[i:i + 2]
    if "--json" in args:
        i = args.index("--json"); dump = Path(args[i + 1]); del args[i:i + 2]
    trees = [a.split("=", 1) if "=" in a else (Path(a).name, a) for a in args]
    if over:
        over.mkdir(parents=True, exist_ok=True)
    found: dict = {}
    for shot in photoreal.shots(only):
        said = shot.get("reflect")
        if shot["kind"] != "closeup" or not said:
            continue
        print(shot["name"])
        photo = photoreal.photo_of(shot)
        found[shot["name"]] = {"photo": measure(photo, said, "photo")}
        print(row("photo", found[shot["name"]]["photo"]))
        first = None
        for label, d in trees:
            f = Path(d) / f"{shot['name']}.png"
            if not f.exists():
                continue
            image = Image.open(f).convert("RGB").resize(tuple(shot["size"]))
            first = first or image
            found[shot["name"]][label] = measure(image, said, "render")
            print(row(label, found[shot["name"]][label]))
        if over:
            w, h = photo.size
            sheet = Image.new("RGB", (w * 2 + 8, h), "white")
            sheet.paste(overlay(photo, said, "photo"), (0, 0))
            if first is not None:
                sheet.paste(overlay(first, said, "render"), (w + 8, 0))
            sheet.save(over / f"{shot['name']}.jpg", quality=88)
    if dump:
        dump.write_text(json.dumps(found, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
