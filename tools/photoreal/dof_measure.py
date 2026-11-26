"""How a set's picture falls out of focus, against its photograph (photoreal22, photoreal23).

In boxes on the near, middle and far parts of a set (the same parts in the photograph and in our renders,
set by eye on the 1024-wide pictures), an edge's width in pixels: the box's L* range (3rd to 97th
percentile) over its steepest gradient (99th percentile, Sobel). A blurred edge is wider. A photograph's
focus is read from the three: the sharpest box is where its focus plane lies, and far/middle and
near/middle are how hard it falls off.

    python3 tools/photoreal/dof_measure.py DIR...      each DIR's set_*.png beside the photograph
    python3 tools/photoreal/dof_measure.py --sweep DIR every <set>__<variant>.png in DIR, best fit first

The fit's miss is the root mean square of log(ours / the photograph's) over the three widths; 0 is the
photograph's. The boxes measure only what is in them: a lamp that changes no lens moved 6532's widths
about 5% (photoreal21's), and two draws of one tree differ by about 1%. 6512's picture is a render with
everything in focus, so it has no boxes. Needs numpy and Pillow."""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SHOTS = {s["name"]: s for s in json.loads((ROOT / "tools/photoreal/shots.json").read_text())["shots"]}

# x0, y0, x1, y1 on the 1024-wide picture: (the photograph's box, the render's box).
BOXES = {
    "set_6532": {"near": ((30, 600, 230, 790), (0, 600, 200, 800)),  # headlights, front block
                 "middle": ((190, 290, 340, 420), (240, 280, 400, 410)),  # minifig head and helmet
                 "far": ((780, 470, 950, 650), (800, 480, 980, 690))},  # rear wheel
    "set_6660": {"near": ((800, 480, 1000, 700), (870, 500, 1024, 720)),  # front grille, yellow lights
                 "middle": ((560, 200, 780, 330), (580, 200, 820, 330)),  # cab roof, yellow stud
                 "far": ((10, 230, 230, 470), (90, 240, 330, 480))},  # crane hook, red arm
    "set_6657": {"near": ((400, 540, 770, 620), (386, 540, 756, 620)),  # the near skid
                 "middle": ((400, 270, 580, 440), (406, 270, 586, 440)),  # the pilot, the door's flame
                 "far": ((70, 280, 240, 385), (61, 285, 226, 380))},  # the tail
}


def lstar(im: Image.Image) -> np.ndarray:
    c = np.asarray(im.convert("RGB"), float) / 255.0
    c = np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)
    y = c @ np.array([0.2126, 0.7152, 0.0722])
    return np.where(y > 216 / 24389, 116 * np.cbrt(y) - 16, 24389 / 27 * y)


def width(lightness: np.ndarray, box: tuple) -> float:
    x0, y0, x1, y1 = box
    a = lightness[y0:y1, x0:x1]
    gx = (a[1:-1, 2:] - a[1:-1, :-2]) * 2 + (a[:-2, 2:] - a[:-2, :-2]) + (a[2:, 2:] - a[2:, :-2])
    gy = (a[2:, 1:-1] - a[:-2, 1:-1]) * 2 + (a[2:, :-2] - a[:-2, :-2]) + (a[2:, 2:] - a[:-2, 2:])
    g = np.hypot(gx, gy) / 8.0
    spread = np.percentile(a, 97) - np.percentile(a, 3)
    return float(spread / max(np.percentile(g, 99), 1e-6))


def widths(shot: str, im: Image.Image, photo: bool) -> dict:
    lightness = lstar(im)
    return {k: width(lightness, pb if photo else rb) for k, (pb, rb) in BOXES[shot].items()}


_photo: dict = {}


def photo_widths(shot: str) -> dict:
    if shot not in _photo:
        s = SHOTS[shot]
        im = Image.open(ROOT / s["photo"]).convert("RGB").resize(tuple(s["size"]), Image.LANCZOS)
        _photo[shot] = widths(shot, im, True)
    return _photo[shot]


def miss(w: dict, p: dict) -> float:
    return math.sqrt(sum(math.log(w[k] / p[k]) ** 2 for k in p) / len(p))


def line(label: str, w: dict, p: dict | None = None) -> str:
    s = (f"  {label:28s} near {w['near']:4.2f}  middle {w['middle']:4.2f}  far {w['far']:4.2f}"
         f"   far/mid {w['far'] / w['middle']:4.2f}  near/mid {w['near'] / w['middle']:4.2f}")
    if p is not None:
        s += f"   miss {miss(w, p):.3f}"
    return s


def main() -> None:
    args = sys.argv[1:]
    if args and args[0] == "--sweep":
        rows = []
        for f in sorted(Path(args[1]).glob("set_*__*.png")):
            shot, variant = f.stem.split("__", 1)
            if shot in BOXES:
                w = widths(shot, Image.open(f).convert("RGB"), False)
                rows.append((shot, miss(w, photo_widths(shot)), variant, w))
        for shot in BOXES:
            mine = sorted((r for r in rows if r[0] == shot), key=lambda r: r[1])
            if mine:
                print(f"== {shot}: best fit first")
                print(line("photograph", photo_widths(shot)))
                for _, _, variant, w in mine:
                    print(line(variant, w, photo_widths(shot)))
        return
    for shot in BOXES:
        p = photo_widths(shot)
        print(f"== {shot}: edge width in px at 1024 wide (wider = softer)")
        print(line("photograph", p))
        for d in args:
            f = Path(d) / f"{shot}.png"
            if f.exists():
                print(line(Path(d).name, widths(shot, Image.open(f).convert("RGB"), False), p))


if __name__ == "__main__":
    main()
