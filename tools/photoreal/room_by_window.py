#!/usr/bin/env python3
"""tools/photoreal/room_by_window.py [SOURCE.hdr] [OUT.hdr] : the "Window light" place as a part on a table by
the window sees it (photoreal34), from Poly Haven's Photo Studio Loft Hall, photographed from the middle of the
room.

A part photographed by a window mirrors the window in its tops. Seen from the middle of the loft hall its
windows reach 23 degrees up, and a camera looking down at 40 degrees sees a level top mirror the plaster above
them: the black 2x4's top came out 1.2 stops under its side, where its photograph's is 7.4 over (RENDERING.md
5ah). On a table 0.6 m from the window the same window rises to 70 degrees and fills the top. So the
panorama is drawn again from there: the room taken as a box of the size its photograph shows (the window wall
2.7 m off, the floor 1.5 m under the lens, the ceiling 2.35 m over it, the windows' sills and heads where they
are), each way from the table met with the box's walls, and the photograph read where that point of the wall
is. What the part mirrors is then the room's own window: its sky, its frame, the buildings across the street,
the plaster round it, darker away from it, each where it would be.

The window is turned to stand across the model from the camera, a little to its left, as a photographer
stands a glossy part with a window behind it: StudioRender turns every place with the camera (its _dress), so
the middle of the window is put where that turn sees "behind the model" (BEHIND, photoreal34's pano34.py:
u 0.097 whatever the camera's heading), WINDOW_SIDE further round.

How near is what the photographs say. A window near and large lights the table as brightly as a top mirrors
it: the black 2x4's leather is L* 71 in its photograph and its top 0.32, a little under it. From 1.2 m the
window lit the table less, the exposure rose to meet it, and every top mirrored the sky at white (the black
2x4's top 0.97, the green plate's 0.84 against 0.35), with nothing of the window's gradient left in them. From
0.6 m the black 2x4's top is 0.48 with a gradient across it and the green plate's 0.35.

Not used (photoreal34, RENDERING.md 5ai): with the room it draws as Window light, the solo judge called the
black 2x4 a photograph in 0 of 36 verdicts (pre261's: 36 of 36), its top "chrome", and the green plate in 12
of 36 (36 of 36). Its output goes beside this file in rooms/ (gdignored, not exported) for a later round.

Only numpy. Reads a Radiance file (run-length coded or flat) and writes one (run-length coded).
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np

HERE = Path(__file__).resolve().parent
SOURCE = HERE.parent.parent / "assets" / "hdri" / "photo_studio_loft_hall.hdr"
OUT = HERE / "rooms" / "loft_hall_by_window.hdr"

# The room as its photograph shows it (metres, from the lens): the window wall's middle is at WALL_U of the
# panorama, WALL m away; the floor FLOOR under the lens and the ceiling CEILING over it (the floor's line
# under the windows at -29 degrees, the cornice at +41); the side walls and the back wall roughly where the
# panorama's corners are. Only the window wall needs to be near right: it is what a part by it mirrors.
WALL_U = 0.535
WALL = 2.7
FLOOR = 1.5
CEILING = 2.35
SIDE = 3.5
BACK = 3.0
# The table: its top 0.8 m over the floor, AWAY m from the window wall, opposite the window at WINDOW_U (the
# brightest, with nothing on its sill: the middle window's stuffed bird stood across every top).
TABLE_HEIGHT = 0.8
AWAY = 0.6
WINDOW_U = 0.66
# The sun through that window is a patch of 800 where its sky is 50 to 100: drawn whole it put a hard glint on
# every satin stud top and a hard shadow under the part, where a part photographed by a window is lit by its
# sky. It is clipped to the sky's level (luminance, its colour kept), as a sheer over the glass would.
SKY = 120.0
# Where StudioRender's turn puts "behind the model, across from the camera", and how far round from there
# the window's middle stands (a share of a turn: +0.05 is 18 degrees).
BEHIND = 0.097
WINDOW_SIDE = 0.05


def read_hdr(path: Path) -> np.ndarray:
    data = path.read_bytes()
    at = 0
    while True:
        end = data.index(b"\n", at)
        line = data[at:end]
        at = end + 1
        if line.startswith(b"-Y") or line.startswith(b"+Y"):
            break
    parts = line.split()
    height, width = int(parts[1]), int(parts[3])
    out = np.zeros((height, width, 4), dtype=np.uint8)
    body = memoryview(data)[at:]
    p = 0
    for y in range(height):
        if 8 <= width < 32768 and body[p] == 2 and body[p + 1] == 2 and not body[p + 2] & 0x80:
            p += 4
            for c in range(4):
                x = 0
                while x < width:
                    n = body[p]
                    p += 1
                    if n > 128:
                        out[y, x:x + n - 128, c] = body[p]
                        p += 1
                        x += n - 128
                    else:
                        out[y, x:x + n, c] = np.frombuffer(body[p:p + n], dtype=np.uint8)
                        p += n
                        x += n
        else:
            out[y] = np.frombuffer(body[p:p + width * 4], dtype=np.uint8).reshape(width, 4)
            p += width * 4
    e = out[..., 3].astype(np.int32)
    scale = np.where(e > 0, np.ldexp(1.0, e - 136), 0.0)
    return out[..., :3].astype(np.float64) * scale[..., None]


def write_hdr(path: Path, rgb: np.ndarray) -> None:
    height, width = rgb.shape[:2]
    top = rgb.max(axis=2)
    mantissa, exponent = np.frexp(top)
    scale = np.where(top > 1e-32, mantissa * 256.0 / np.maximum(top, 1e-32), 0.0)
    rgbe = np.zeros((height, width, 4), dtype=np.uint8)
    rgbe[..., :3] = np.clip(rgb * scale[..., None], 0, 255).astype(np.uint8)
    rgbe[..., 3] = np.where(top > 1e-32, exponent + 128, 0).astype(np.uint8)
    chunks = [b"#?RADIANCE\nFORMAT=32-bit_rle_rgbe\n\n", f"-Y {height} +X {width}\n".encode()]
    for y in range(height):
        chunks.append(bytes([2, 2, width >> 8, width & 255]))
        for c in range(4):
            row = rgbe[y, :, c].tobytes()
            for x in range(0, width, 128):
                piece = row[x:x + 128]
                chunks.append(bytes([len(piece)]) + piece)
    path.write_bytes(b"".join(chunks))


def direction(u: np.ndarray, v: np.ndarray) -> np.ndarray:
    """StudioPanorama.direction: across atan2(x, -z) from 0 to 1, down acos(y) from 0 to 1."""
    around = u * 2.0 * math.pi
    down = v * math.pi
    return np.stack([np.sin(around) * np.sin(down), np.cos(down), -np.cos(around) * np.sin(down)], -1)


def sample(img: np.ndarray, way: np.ndarray) -> np.ndarray:
    height, width = img.shape[:2]
    around = np.arctan2(way[..., 0], -way[..., 2]) % (2.0 * math.pi)
    u = around / (2.0 * math.pi) * width - 0.5
    v = np.arccos(np.clip(way[..., 1], -1.0, 1.0)) / math.pi * height - 0.5
    x0 = np.floor(u).astype(int)
    y0 = np.clip(np.floor(v).astype(int), 0, height - 1)
    y1 = np.clip(y0 + 1, 0, height - 1)
    fx = (u - x0)[..., None]
    fy = np.clip(v - np.floor(v), 0.0, 1.0)[..., None]
    x0 %= width
    x1 = (x0 + 1) % width
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x1] * fx * (1 - fy)
            + img[y1, x0] * (1 - fx) * fy + img[y1, x1] * fx * fy)


def by_window(img: np.ndarray, width: int) -> np.ndarray:
    height = width // 2
    v, u = np.meshgrid((np.arange(height) + 0.5) / height, (np.arange(width) + 0.5) / width, indexing="ij")
    # The way out of the table in the source panorama's own frame: the window wall's middle, which this
    # panorama has at WALL_U, is put at BEHIND + WINDOW_SIDE.
    way = direction(u + (WALL_U - (BEHIND + WINDOW_SIDE)), v)
    ahead = direction(np.array(WALL_U), np.array(0.5))
    right = np.array([-ahead[2], 0.0, ahead[0]])
    up = np.array([0.0, 1.0, 0.0])
    along = WALL * math.tan((WINDOW_U - WALL_U) * 2.0 * math.pi)
    table = ahead * (WALL - AWAY) + right * along + up * (TABLE_HEIGHT - FLOOR)
    f = way @ ahead
    r = way @ right
    h = way @ up
    tf = table @ ahead
    th = table @ up
    tr = table @ right
    big = 1e9
    with np.errstate(divide="ignore", invalid="ignore"):
        t = np.full(f.shape, big)
        for d, now, at in ((f, tf, WALL), (f, tf, -BACK), (r, tr, SIDE), (r, tr, -SIDE), (h, th, CEILING),
                           (h, th, -FLOOR)):
            hit = (at - now) / d
            t = np.where((hit > 1e-6) & (hit < t), hit, t)
    met = table[None, None, :] + way * t[..., None]
    seen = met / np.linalg.norm(met, axis=-1, keepdims=True)
    room = sample(img, seen)
    level = room @ np.array([0.2126, 0.7152, 0.0722])
    return room * np.minimum(1.0, SKY / np.maximum(level, 1e-9))[..., None]


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    source = Path(args[0]) if args else SOURCE
    out = Path(args[1]) if len(args) > 1 else OUT
    img = read_hdr(source)
    room = by_window(img, img.shape[1])
    out.parent.mkdir(parents=True, exist_ok=True)
    write_hdr(out, room)
    print(f"{out}: {room.shape[1]} x {room.shape[0]}, mean {room.mean():.3f} (the room's {img.mean():.3f})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
