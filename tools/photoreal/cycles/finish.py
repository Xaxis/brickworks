"""Our camera's finish on a Cycles picture's light (photoreal6): the same steps, in the same
order, as path_tracer_resolve.glsl gives the tracer's, so the two renderers' pictures differ
only in how they drew the light.

Run with Blender's own Python (it has numpy and OpenImageIO; this box's python3 has neither):

    ~/.local/opt/blender-5.2.4-linux-x64/5.2/python/bin/python3.13 tools/photoreal/cycles/finish.py \
        PICTURE.exr SCENE.cycles.json OUT.png [--grain G] [--vignette V] [--softness S] [--draw N]
        [--jpeg Q] [--white-balance R,G,B]

From render.py's EXR: the model (Combined, premultiplied) over the backdrop, drawn as the
tracer draws its shadow catcher: the backdrop's colour exactly, times the paper's pattern,
times the shadow the model casts on it (Cycles' Shadow Catcher pass). Then, as the resolve:
the lens's softness, the exposure the white card metered (the scene's, from our tracer, so
both are exposed alike), the vignette, the camera's linear saturation, camera_curve, sRGB,
a dither and the sensor's grain. --jpeg and --white-balance are the camera's own marks for
photoreal6's attribution (none by default).
"""

from __future__ import annotations

import argparse
import json
import math

import numpy as np
import OpenImageIO as oiio


def read(path: str) -> dict[str, np.ndarray]:
    image = oiio.ImageInput.open(path)
    if image is None:
        raise SystemExit(f"cannot read {path}: {oiio.geterror()}")
    found: dict[str, np.ndarray] = {}
    part = 0
    # A multi-part EXR (Blender 5's default) holds each pass in a part of its own.
    while image.seek_subimage(part, 0):
        spec = image.spec()
        pixels = np.asarray(image.read_image(part, 0, 0, spec.nchannels, "float"), dtype=np.float64)
        if pixels.ndim == 2:
            pixels = pixels[..., None]
        for i, name in enumerate(spec.channelnames):
            found.setdefault(name, pixels[..., i])
        part += 1
    image.close()
    return found


def channel(found: dict[str, np.ndarray], *words: str) -> np.ndarray | None:
    for name, plane in found.items():
        parts = name.split(".")
        if all(w in parts for w in words):
            return plane
    return None


def srgb_to_linear(c):
    c = np.asarray(c, dtype=np.float64)
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(np.maximum(c, 0.0), 1.0 / 2.4) - 0.055)


def camera_curve(c):
    """path_tracer_resolve.glsl camera_curve, white 1: linear to 0.6, then a shoulder that
    reaches white at 2.5."""
    t = np.minimum((c - 0.6) / 1.9, 1.0)
    return np.where(c <= 0.6, c, 0.6 + 0.4 * (2.0 * t - t * t))


def uncurve(y: float) -> float:
    if y <= 0.6:
        return y
    return 0.6 + 1.9 * (1.0 - math.sqrt(max(1.0 - (y - 0.6) / 0.4, 0.0)))


def luma(c):
    return c[..., 0] * 0.2126 + c[..., 1] * 0.7152 + c[..., 2] * 0.0722


def caught(scene: dict) -> np.ndarray:
    """The light the tracer's shadow catcher shows the backdrop at (studio_render.gd):
    each channel through the curve, the camera's linear saturation undone round its
    luminance, over the exposure."""
    hexed = scene["backdrop"].lstrip("#")
    srgb = [int(hexed[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    need = np.array([uncurve(float(srgb_to_linear(c))) for c in srgb])
    grey = 0.2126 * need[0] + 0.7152 * need[1] + 0.0722 * need[2]
    sat = float(scene["linear_saturation"])
    return np.maximum(grey + (need - grey) / sat, 0.0) / max(float(scene["exposure"]), 1e-4)


def raw_light(found: dict[str, np.ndarray], scene: dict) -> np.ndarray:
    rgb = np.stack([channel(found, "Combined", c) for c in "RGB"], axis=-1)
    alpha = channel(found, "Combined", "A")
    shadow = [channel(found, "Shadow Catcher", c) for c in "RGB"]
    shadow = np.stack(shadow, axis=-1) if all(s is not None for s in shadow) else np.ones_like(rgb)
    paper = channel(found, "paper", "X")
    if paper is None:
        paper = channel(found, "paper", "V")
    if paper is None:
        paper = np.ones_like(alpha)
    else:
        # The pattern about its own middle: Cycles writes the catcher's AOV once for each of
        # the two paths it splits a catcher's hit into, so its level is twice the value.
        seen = (alpha < 0.5) & (paper > 0.0)
        middle = float(np.median(paper[seen])) if seen.any() else 1.0
        paper = np.where(paper > 0.0, paper / max(middle, 1e-6), 1.0)
    # Cycles folds the catcher's shadow into Combined's alpha, (1 - A) = (1 - matte alpha) x the
    # shadow's mean, so the backdrop's share is (1 - A) / mean, and the shadow pass gives it
    # its colour: exact wherever the shadow pass is at most 1.
    mean = np.maximum(shadow.mean(axis=-1), 1e-3)
    share = (1.0 - np.clip(alpha, 0.0, 1.0)) / mean
    behind = caught(scene)[None, None, :] * paper[..., None] * shadow
    return rgb + share[..., None] * behind


def finish(light: np.ndarray, scene: dict, grain: float, vignette: float, softness: float,
           draw: int, white_balance=None) -> np.ndarray:
    h, w = light.shape[:2]
    if softness > 0.0:
        padded = np.pad(light, ((1, 1), (1, 1), (0, 0)), mode="edge")
        ring = np.zeros_like(light)
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                weight = 0.75 if dx == 0 or dy == 0 else 0.25
                ring += weight * padded[1 + dy:1 + dy + h, 1 + dx:1 + dx + w]
        light = light + (ring / 4.0 - light) * (softness / 3.0)
    colour = np.maximum(light * float(scene["exposure"]), 0.0)
    if white_balance is not None:
        colour = colour * np.asarray(white_balance)[None, None, :]
    ys, xs = np.mgrid[0:h, 0:w]
    half = math.hypot(w, h) * 0.5
    mx = (xs + 0.5 - w * 0.5) / half
    my = (ys + 0.5 - h * 0.5) / half
    colour = colour * (1.0 - vignette * (mx * mx + my * my))[..., None]
    level = luma(colour)[..., None]
    colour = np.maximum(level + (colour - level) * float(scene["linear_saturation"]), 0.0)
    colour = camera_curve(colour)
    colour = linear_to_srgb(np.clip(colour, 0.0, 1.0))
    rng = np.random.default_rng(1000 + draw)
    n = rng.random((h, w)) + rng.random((h, w)) - 1.0
    colour = colour + (n / 255.0)[..., None]
    if grain > 0.0:
        level = np.clip(luma(colour), 0.0, 1.0)
        amount = grain / 255.0 * (1.0 - level ** 6) * (0.35 + 0.65 * np.sqrt(level))
        lightness = rng.standard_normal((h, w))
        tint = rng.standard_normal((h, w, 3))
        colour = colour + amount[..., None] * (lightness[..., None] + 0.35 * tint)
    return np.clip(colour, 0.0, 1.0)


def write_png(path: str, colour: np.ndarray, jpeg: int = 0) -> None:
    pixels = np.round(colour * 255.0).astype(np.uint8)
    h, w = pixels.shape[:2]
    if jpeg > 0:
        # Through the camera's own JPEG first, at its quality, then kept as a PNG.
        tmp = path + ".jpg"
        out = oiio.ImageOutput.create(tmp)
        spec = oiio.ImageSpec(w, h, 3, "uint8")
        spec.attribute("Compression", f"jpeg:{jpeg}")
        out.open(tmp, spec)
        out.write_image(np.ascontiguousarray(pixels))
        out.close()
        back = oiio.ImageInput.open(tmp)
        pixels = np.asarray(back.read_image(format="uint8"), dtype=np.uint8)[..., :3]
        back.close()
        import os
        os.remove(tmp)
    out = oiio.ImageOutput.create(path)
    out.open(path, oiio.ImageSpec(w, h, 3, "uint8"))
    out.write_image(np.ascontiguousarray(pixels))
    out.close()


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("exr")
    p.add_argument("scene")
    p.add_argument("png")
    p.add_argument("--grain", type=float, default=None)
    p.add_argument("--vignette", type=float, default=None)
    p.add_argument("--softness", type=float, default=None)
    p.add_argument("--draw", type=int, default=1)
    p.add_argument("--jpeg", type=int, default=0)
    p.add_argument("--white-balance", default="")
    a = p.parse_args()
    scene = json.load(open(a.scene))
    found = read(a.exr)
    light = raw_light(found, scene)
    wb = [float(x) for x in a.white_balance.split(",")] if a.white_balance else None
    colour = finish(light, scene,
                    float(scene["grain"]) if a.grain is None else a.grain,
                    float(scene["vignette"]) if a.vignette is None else a.vignette,
                    float(scene["softness"]) if a.softness is None else a.softness, a.draw, wb)
    write_png(a.png, colour, a.jpeg)
    alpha = channel(found, "Combined", "A")
    shadow = channel(found, "Shadow Catcher", "R")
    print(f"{a.png}: {colour.shape[1]}x{colour.shape[0]}, model {float((alpha > 0.5).mean()):.3f} of the "
          f"picture, shadow pass {'min %.3f' % float(shadow.min()) if shadow is not None else 'absent'}, "
          f"channels {sorted(found)[:12]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
