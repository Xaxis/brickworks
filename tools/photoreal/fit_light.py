#!/usr/bin/env python3
"""fit_light.py: which staged key lights each shot as its photograph is lit (photoreal7).

photoreal_probe draws each shot many times, small, its staged key (StudioRender.STAGES) turned
round the model and raised, moved nearer and further and made brighter against the room:

    tools/probe.sh photoreal_probe -- --tag=fit --shots=FILE --width=160 --samples=32 \\
        --turns=0,45,...,315 --keys=20:2.5:1,45:2.5:1,...

as shots/photoreal/fit/<name>_t<turn>_k<rise>x<far>x<share>.png. This scores each against the
shot's photograph (cropped and scaled as the judge is shown it, tools/bench/photoreal.py
photo_of): the two pictures' lightness in linear light, logged, blurred a little and compared
by correlation over the whole frame. Where the light stands decides how the model's faces are
lit against each other, which way its shadow falls, and how the surface darkens away from the
light (its fall-off); none depends on the exposure, which the correlation leaves out.

    fit_light.py DRAWN --shots FILE [--out fit.json]

Prints each shot's best five and its fit, and the rule over all of them (the median of each
setting over the shots): what the app's stage key takes where a render asks for none
(StudioRender.STAGE_KEY_RISE, _FAR, _SHARE).
"""
from __future__ import annotations

import argparse
import json
import math
import re
import statistics
import sys
from pathlib import Path

from PIL import Image, ImageFilter

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from bench import photoreal  # noqa: E402

NAME = re.compile(r"^(?P<shot>.+)_t(?P<turn>-?[0-9.]+)_k(?P<rise>[0-9.]+)x(?P<far>[0-9.]+)x(?P<share>[0-9.]+)$")


LINEAR = [((v / 255.0) / 12.92) if v / 255.0 <= 0.04045 else (((v / 255.0) + 0.055) / 1.055) ** 2.4
          for v in range(256)]


def lightness(image: Image.Image, size: tuple[int, int]) -> list[float]:
    """The picture's lightness in linear light at [size], logged and blurred a little."""
    small = image.convert("RGB").resize(size, Image.LANCZOS).filter(ImageFilter.GaussianBlur(1.2))
    return [math.log(0.2126 * LINEAR[r] + 0.7152 * LINEAR[g] + 0.0722 * LINEAR[b] + 0.01)
            for r, g, b in small.getdata()]


def score(photo: list[float], drawn: list[float]) -> float:
    """Their correlation: 1 where one is the other at another exposure."""
    ma = sum(photo) / len(photo)
    mb = sum(drawn) / len(drawn)
    ab = aa = bb = 0.0
    for a, b in zip(photo, drawn):
        a -= ma
        b -= mb
        ab += a * b
        aa += a * a
        bb += b * b
    return ab / max(math.sqrt(aa * bb), 1e-12)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("drawn", type=Path)
    parser.add_argument("--shots", type=Path, default=photoreal.SHOTS)
    parser.add_argument("--out", type=Path)
    args = parser.parse_args()
    photoreal.SHOTS = args.shots
    found: dict[str, list[dict]] = {}
    for path in sorted(args.drawn.glob("*.png")):
        match = NAME.match(path.stem)
        if match:
            found.setdefault(match["shot"], []).append({"file": path, **{k: float(match[k]) for k in (
                "turn", "rise", "far", "share")}})
    fits: dict[str, dict] = {}
    for shot in photoreal.shots():
        tries = found.get(shot["name"], [])
        if not tries:
            continue
        size = Image.open(tries[0]["file"]).size
        photo = lightness(photoreal.photo_of(shot), size)
        for one in tries:
            one["score"] = round(score(photo, lightness(Image.open(one["file"]), size)), 4)
        tries.sort(key=lambda t: -t["score"])
        best = tries[0]
        fits[shot["name"]] = {k: best[k] for k in ("turn", "rise", "far", "share", "score")}
        fits[shot["name"]]["kind"] = shot["kind"]
        fits[shot["name"]]["of"] = len(tries)
        fits[shot["name"]]["worst"] = tries[-1]["score"]
        print(f"{shot['name']}: {len(tries)} tried, worst {tries[-1]['score']:.3f}")
        for one in tries[:5]:
            print(f"   {one['score']:.3f}  turn {one['turn']:5.0f}  rise {one['rise']:4.0f}  "
                  f"far {one['far']:4.1f}  share {one['share']:4.2f}")
    rule = {k: statistics.median(f[k] for f in fits.values()) for k in ("rise", "far", "share")}
    print("rule (the median over the shots): rise %.0f, far %.1f, share %.2f" % (
        rule["rise"], rule["far"], rule["share"]))
    if args.out:
        args.out.write_text(json.dumps({"fits": fits, "rule": rule}, indent=1))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
