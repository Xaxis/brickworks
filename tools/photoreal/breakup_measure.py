#!/usr/bin/env python3
"""tools/photoreal/breakup_measure.py [--only a,b] [--overlay DIR] [--json FILE] [LABEL=DIR ...] : how broken
each close-up's gloss is, the photographs beside renders (photoreal15).

Moulded ABS is never a perfect mirror. A real top's highlight is broken and wobbly: an orange-peel waviness
bends what it mirrors, the plastic sinks over thick sections (round each stud's foot, over the tubes), and
it carries polish lines and tiny scuffs. A render's face mirrors one smooth room through one roughness. These
measure that, on boxes and lines placed by hand on each photograph and on the render's camera (shots.json
"breakup", the same place on the part in both; "reflect"'s top and side boxes and lines too):

  mottle    a face's broken light: the spread (sd, stops) of its log luminance, smoothed a pixel (sigma 1,
            at the shot's size) less the plane that fits it best over the box and what is left of a slow
            fall (a blur of sigma 6 within the box): a band from about 2 to 12 pixels, with nothing from
            the faces beside it. A perfect mirror of a smooth room is near 0.
  specks    the share of the face's pixels more than a quarter stop off that slow fall: scratches, scuffs,
            dust and pits, each a point or a line of light or dark.
  wobble    a highlight line's waviness: across the line at 41 places along it, where the line's middle
            is (half its rise either side); the spread (sd, px) of those places about a straight line
            through them. A ruled line is near 0.
  width cv  how much the line's width (full width at half its rise) strays along it: sd over mean.
  edge      a step's waviness (photoreal15's "edges": the outline of a stud mirrored in a top, a
            highlight's edge): where it crosses halfway between its two sides at 41 places along it, the
            spread (sd, px) of those places about the parabola that fits them best; and the step's width (10 to 90 percent).
  dip       sink round a stud (photoreal15's "sinks", a line from just off a stud's foot out across the
            flat top): the darkest of the line's first quarter against its last half, in stops. Over a
            highlight a sink dips it; with nothing bright mirrored there is nothing to dip.

  A "breakup" may name reflect's boxes to "skip" where they are not one flat face on both pictures.

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

ALONG = 41
HALF = 12
SLIDE = 6


def _lin(c: float) -> float:
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


TABLE = [_lin(v) for v in range(256)]


def luminance(image: Image.Image) -> list[list[float]]:
    px = image.load()
    w, h = image.size
    return [[0.2126 * TABLE[px[x, y][0]] + 0.7152 * TABLE[px[x, y][1]] + 0.0722 * TABLE[px[x, y][2]]
             for x in range(w)] for y in range(h)]


def _blur(grid: list[list[float]], sigma: float) -> list[list[float]]:
    """A separable Gaussian blur of a small grid, its edges held."""
    r = max(int(3 * sigma), 1)
    k = [math.exp(-(i * i) / (2 * sigma * sigma)) for i in range(-r, r + 1)]
    total = sum(k)
    k = [v / total for v in k]
    h, w = len(grid), len(grid[0])
    rows = [[sum(k[j] * row[min(max(x + j - r, 0), w - 1)] for j in range(len(k))) for x in range(w)]
            for row in grid]
    return [[sum(k[j] * rows[min(max(y + j - r, 0), h - 1)][x] for j in range(len(k))) for x in range(w)]
            for y in range(h)]


def _box(w: int, h: int, box: list[float]) -> tuple[int, int, int, int]:
    x0, y0 = int(box[0] * w), int(box[1] * h)
    return x0, y0, max(int(box[2] * w), x0 + 2), max(int(box[3] * h), y0 + 2)


def face_measure(lum: list[list[float]], box: list[float]) -> dict:
    """The face's log luminance, smoothed a pixel (sigma 1), less the plane that fits it best over the box:
    its broken light without its own slow fall, and nothing from the faces beside it."""
    h, w = len(lum), len(lum[0])
    x0, y0, x1, y1 = _box(w, h, box)
    pad = 3
    px0, py0, px1, py1 = max(x0 - pad, 0), max(y0 - pad, 0), min(x1 + pad, w), min(y1 + pad, h)
    log = [[math.log2(max(lum[y][x], 1e-4)) for x in range(px0, px1)] for y in range(py0, py1)]
    fine = _blur(log, 1.0)
    pts = [(x, y, fine[y - py0][x - px0]) for y in range(y0, y1) for x in range(x0, x1)]
    n = len(pts)
    mx, my, mv = sum(p[0] for p in pts) / n, sum(p[1] for p in pts) / n, sum(p[2] for p in pts) / n
    sxx = sum((p[0] - mx) ** 2 for p in pts)
    syy = sum((p[1] - my) ** 2 for p in pts)
    sxy = sum((p[0] - mx) * (p[1] - my) for p in pts)
    sxv = sum((p[0] - mx) * (p[2] - mv) for p in pts)
    syv = sum((p[1] - my) * (p[2] - mv) for p in pts)
    det = sxx * syy - sxy * sxy
    a = (sxv * syy - syv * sxy) / det if det > 1e-9 else 0.0
    b = (syv * sxx - sxv * sxy) / det if det > 1e-9 else 0.0
    rest = [[fine[y - py0][x - px0] - (mv + a * (x - mx) + b * (y - my)) for x in range(x0, x1)]
            for y in range(y0, y1)]
    # what is left of the face's own fall over a few pixels, within the box only (its edges held)
    slow = _blur(rest, 6.0)
    band = [rest[j][i] - slow[j][i] for j in range(y1 - y0) for i in range(x1 - x0)]
    n = len(band)
    sd = math.sqrt(sum(v * v for v in band) / n)
    specks = sum(abs(v) > 0.25 for v in band) / n
    return {"mottle": sd, "specks": specks}


def sample(lum: list[list[float]], x: float, y: float) -> float:
    h, w = len(lum), len(lum[0])
    x = min(max(x, 0.0), w - 1.001)
    y = min(max(y, 0.0), h - 1.001)
    x0, y0 = int(x), int(y)
    fx, fy = x - x0, y - y0
    return (lum[y0][x0] * (1 - fx) * (1 - fy) + lum[y0][x0 + 1] * fx * (1 - fy)
            + lum[y0 + 1][x0] * (1 - fx) * fy + lum[y0 + 1][x0 + 1] * fx * fy)


def _crossings(profile: list[float], mid: int) -> tuple[float, float, float] | None:
    """The half-rise crossings either side of the peak at mid, and the rise in stops; None for no line."""
    left = sorted(profile[: max(mid - 4, 1)])
    right = sorted(profile[mid + 5:]) or [profile[-1]]
    face = max(left[len(left) // 2], right[len(right) // 2])
    peak = profile[mid]
    rise = peak - face
    if rise <= 1e-5 or peak < face * 1.08:
        return None
    half = face + rise / 2
    a = mid
    while a > 0 and profile[a] > half:
        a -= 1
    b = mid
    while b < len(profile) - 1 and profile[b] > half:
        b += 1
    if a == 0 or b == len(profile) - 1:
        return None
    fa = a + (half - profile[a]) / (profile[a + 1] - profile[a]) if profile[a + 1] != profile[a] else float(a)
    fb = b - (half - profile[b]) / (profile[b - 1] - profile[b]) if profile[b - 1] != profile[b] else float(b)
    return fa, fb, math.log2(peak / max(face, 1e-5))


def line_measure(lum: list[list[float]], seg: list[float]) -> dict:
    """Each of ALONG profiles across the line: its middle's place (px across) and its width."""
    h, w = len(lum), len(lum[0])
    ax, ay, bx, by = seg[0] * w, seg[1] * h, seg[2] * w, seg[3] * h
    length = math.hypot(bx - ax, by - ay)
    tx, ty = (bx - ax) / length, (by - ay) / length
    nx, ny = -ty, tx
    places, widths, rises, ts = [], [], [], []
    for i in range(ALONG):
        t = 0.1 + 0.8 * i / (ALONG - 1)
        cx, cy = ax + (bx - ax) * t, ay + (by - ay) * t
        # a little smoothing along the line (a third of a pixel either side) keeps one pixel's noise out
        wide = [sum(sample(lum, cx + nx * s + tx * e, cy + ny * s + ty * e) for e in (-0.35, 0.0, 0.35)) / 3
                for s in range(-HALF - SLIDE, HALF + SLIDE + 1)]
        peak = max(range(HALF, HALF + 2 * SLIDE + 1), key=lambda k: wide[k])
        got = _crossings(wide, peak)
        if got is None:
            continue
        fa, fb, rise = got
        places.append((fa + fb) / 2 - (HALF + SLIDE))
        widths.append(fb - fa)
        rises.append(rise)
        ts.append(t * length)
    if len(places) < ALONG // 2:
        return {"wobble": float("nan"), "width": float("nan"), "width_cv": float("nan"), "rise": 0.0,
                "found": len(places)}
    n = len(places)
    mt, mp = sum(ts) / n, sum(places) / n
    slope = sum((t - mt) * (p - mp) for t, p in zip(ts, places)) / max(sum((t - mt) ** 2 for t in ts), 1e-9)
    resid = [p - (mp + slope * (t - mt)) for t, p in zip(ts, places)]
    wobble = math.sqrt(sum(r * r for r in resid) / n)
    mw = sum(widths) / n
    cv = math.sqrt(sum((x - mw) ** 2 for x in widths) / n) / max(mw, 1e-6)
    return {"wobble": wobble, "width": mw, "width_cv": cv, "rise": sum(rises) / n, "found": n}


def _less_quadratic(ts: list[float], ys: list[float]) -> list[float]:
    """ys less the parabola in ts that fits them best (a mirrored stud's outline is a curve)."""
    n = len(ts)
    mt = sum(ts) / n
    xs = [t - mt for t in ts]
    s = [sum(x ** k for x in xs) for k in range(5)]
    b = [sum(y * x ** k for x, y in zip(xs, ys)) for k in range(3)]
    m = [[s[0], s[1], s[2]], [s[1], s[2], s[3]], [s[2], s[3], s[4]]]

    def det(a: list[list[float]]) -> float:
        return (a[0][0] * (a[1][1] * a[2][2] - a[1][2] * a[2][1]) - a[0][1] * (a[1][0] * a[2][2] - a[1][2] * a[2][0])
                + a[0][2] * (a[1][0] * a[2][1] - a[1][1] * a[2][0]))
    d = det(m)
    if abs(d) < 1e-12:
        mean = sum(ys) / n
        return [y - mean for y in ys]
    c = []
    for k in range(3):
        mk = [row[:] for row in m]
        for r in range(3):
            mk[r][k] = b[r]
        c.append(det(mk) / d)
    return [y - (c[0] + c[1] * x + c[2] * x * x) for x, y in zip(xs, ys)]


def edge_measure(lum: list[list[float]], seg: list[float]) -> dict:
    """A step's waviness: across the step (a highlight's edge, a mirrored stud's outline) at ALONG places,
    where it crosses halfway between its two sides (each side's median, in stops); the spread (sd, px) of
    those places about a straight line through them, and the step's width (10 to 90 percent of it, px)."""
    h, w = len(lum), len(lum[0])
    ax, ay, bx, by = seg[0] * w, seg[1] * h, seg[2] * w, seg[3] * h
    length = math.hypot(bx - ax, by - ay)
    tx, ty = (bx - ax) / length, (by - ay) / length
    nx, ny = -ty, tx
    places, widths, ts = [], [], []
    for i in range(ALONG):
        t = 0.1 + 0.8 * i / (ALONG - 1)
        cx, cy = ax + (bx - ax) * t, ay + (by - ay) * t
        prof = [math.log2(max(sum(sample(lum, cx + nx * s + tx * e, cy + ny * s + ty * e)
                                  for e in (-0.35, 0.0, 0.35)) / 3, 1e-5)) for s in range(-HALF, HALF + 1)]
        lo_side = sorted(prof[:6])[3]
        hi_side = sorted(prof[-6:])[3]
        if abs(hi_side - lo_side) < 0.5:
            continue
        up = hi_side > lo_side
        def cross(level: float) -> float | None:
            for k in range(len(prof) - 1):
                a, b = prof[k], prof[k + 1]
                if (a - level) * (b - level) <= 0 and a != b:
                    return k + (level - a) / (b - a)
            return None
        mid = cross((lo_side + hi_side) / 2)
        c10 = cross(lo_side + 0.1 * (hi_side - lo_side))
        c90 = cross(lo_side + 0.9 * (hi_side - lo_side))
        if mid is None:
            continue
        places.append(mid - HALF)
        if c10 is not None and c90 is not None:
            widths.append(abs(c90 - c10))
        ts.append(t * length)
        del up
    if len(places) < ALONG // 2:
        return {"wobble": float("nan"), "width": float("nan"), "found": len(places)}
    resid = _less_quadratic(ts, places)
    return {"wobble": math.sqrt(sum(r * r for r in resid) / len(resid)),
            "width": sum(widths) / len(widths) if widths else float("nan"), "found": len(places)}


def dip_measure(lum: list[list[float]], seg: list[float]) -> dict:
    h, w = len(lum), len(lum[0])
    ax, ay, bx, by = seg[0] * w, seg[1] * h, seg[2] * w, seg[3] * h
    length = math.hypot(bx - ax, by - ay)
    steps = max(int(length), 8)
    tx, ty = (bx - ax) / length, (by - ay) / length
    nx, ny = -ty, tx
    prof = [sum(sample(lum, ax + (bx - ax) * i / steps + nx * e, ay + (by - ay) * i / steps + ny * e)
                for e in (-1.0, 0.0, 1.0)) / 3 for i in range(steps + 1)]
    near = prof[: max(len(prof) // 4, 2)]
    far = sorted(prof[len(prof) // 2:])
    return {"dip": math.log2(max(min(near), 1e-5) / max(far[len(far) // 2], 1e-5))}


def measure(image: Image.Image, shot: dict, who: str) -> dict:
    lum = luminance(image)
    out: dict = {"faces": {}, "lines": {}, "sinks": {}}
    reflect = shot.get("reflect", {})
    said = shot.get("breakup", {})
    faces = {k: reflect[k][who] for k in ("top", "side") if k in reflect and k not in said.get("skip", [])}
    faces.update({f["name"]: f[who] for f in said.get("faces", [])})
    for name, box in faces.items():
        out["faces"][name] = face_measure(lum, box)
    lines = {ln["name"]: ln[who] for ln in reflect.get("lines", [])}
    lines.update({ln["name"]: ln[who] for ln in said.get("lines", [])})
    for name, seg in lines.items():
        out["lines"][name] = line_measure(lum, seg)
    out["edges"] = {e["name"]: edge_measure(lum, e[who]) for e in said.get("edges", [])}
    dips = [dip_measure(lum, s[who])["dip"] for s in said.get("sinks", [])]
    if dips:
        out["sinks"] = {"dip": sum(dips) / len(dips), "each": dips}
    return out


def overlay(image: Image.Image, shot: dict, who: str) -> Image.Image:
    image = image.copy()
    d = ImageDraw.Draw(image)
    w, h = image.size
    reflect = shot.get("reflect", {})
    said = shot.get("breakup", {})
    boxes = [(k, reflect[k][who]) for k in ("top", "side") if k in reflect and k not in said.get("skip", [])]
    boxes += [(f["name"], f[who]) for f in said.get("faces", [])]
    for name, b in boxes:
        d.rectangle([b[0] * w, b[1] * h, b[2] * w, b[3] * h], outline=(0, 255, 0), width=2)
        d.text((b[0] * w + 2, b[1] * h - 11), name, fill=(0, 255, 0))
    for ln in reflect.get("lines", []) + said.get("lines", []):
        s = ln[who]
        d.line([s[0] * w, s[1] * h, s[2] * w, s[3] * h], fill=(0, 255, 255), width=1)
        d.text((s[0] * w + 3, s[1] * h + 3), ln["name"], fill=(255, 255, 0))
    for e in said.get("edges", []):
        s = e[who]
        d.line([s[0] * w, s[1] * h, s[2] * w, s[3] * h], fill=(255, 128, 0), width=1)
        d.text((s[2] * w + 3, s[3] * h), e["name"], fill=(255, 128, 0))
    for sk in said.get("sinks", []):
        s = sk[who]
        d.line([s[0] * w, s[1] * h, s[2] * w, s[3] * h], fill=(255, 0, 255), width=1)
    return image


def row(label: str, m: dict) -> str:
    parts = [f"  {label:12s}"]
    for name, v in m["faces"].items():
        parts.append(f"{name}: mottle {v['mottle']:.3f} specks {100 * v['specks']:4.1f}%")
    for name, v in m["lines"].items():
        parts.append(f"| {name}: wobble {v['wobble']:4.2f} px width {v['width']:4.1f} cv {v['width_cv']:.2f}"
                     f" ({v['found']})")
    for name, v in m.get("edges", {}).items():
        parts.append(f"| {name}: wobble {v['wobble']:4.2f} px step {v['width']:4.1f} px ({v['found']})")
    if m.get("sinks"):
        parts.append(f"| sink dip {m['sinks']['dip']:+.2f} stops")
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
        if shot["kind"] != "closeup" or not (shot.get("reflect") or shot.get("breakup")):
            continue
        print(shot["name"])
        photo = photoreal.photo_of(shot)
        found[shot["name"]] = {"photo": measure(photo, shot, "photo")}
        print(row("photo", found[shot["name"]]["photo"]))
        first = None
        for label, d in trees:
            f = Path(d) / f"{shot['name']}.png"
            if not f.exists():
                continue
            image = Image.open(f).convert("RGB").resize(tuple(shot["size"]))
            first = first or image
            found[shot["name"]][label] = measure(image, shot, "render")
            print(row(label, found[shot["name"]][label]))
        if over:
            w, h = photo.size
            sheet = Image.new("RGB", (w * 2 + 8, h), "white")
            sheet.paste(overlay(photo, shot, "photo"), (0, 0))
            if first is not None:
                sheet.paste(overlay(first, shot, "render"), (w + 8, 0))
            sheet.save(over / f"{shot['name']}.jpg", quality=88)
    if dump:
        dump.write_text(json.dumps(found, indent=1))
    return 0


if __name__ == "__main__":
    sys.exit(main())
