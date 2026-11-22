"""camera_pipeline.py FROM TO [--only sharpen|jpeg] : each shot's picture in FROM through a camera's own
pipeline as its photograph went through it, kept as PNG in TO (photoreal6's camera factor):

- a camera's sharpening: an unsharp mask (radius 1.2, 60%, threshold 2), the halos the judge names in
  phone photographs;
- then the JPEG, at the photographs' own quantisation: quality 90 for the close-ups' Wikimedia copies,
  75 for the sets' Rebrickable pictures, both 4:2:0. The judge's own JPEG at 92 is then a second
  generation for the renders, as it is for the photographs.

--only sharpen or --only jpeg applies one step alone, to tell which carries the gain.
"""
import argparse
import io
import json
from pathlib import Path

from PIL import Image, ImageFilter

SHOTS = Path(__file__).resolve().parent.parent / "shots.json"


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("src", type=Path)
    p.add_argument("dst", type=Path)
    p.add_argument("--only", choices=["sharpen", "jpeg"], default=None)
    a = p.parse_args()
    a.dst.mkdir(parents=True, exist_ok=True)
    for shot in json.loads(SHOTS.read_text())["shots"]:
        path = a.src / f"{shot['name']}.png"
        if not path.exists():
            print(f"no {path}")
            continue
        picture = Image.open(path).convert("RGB")
        if a.only != "jpeg":
            picture = picture.filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
        quality = 75 if shot["kind"] == "set" else 90
        if a.only != "sharpen":
            buffer = io.BytesIO()
            picture.save(buffer, "JPEG", quality=quality, subsampling=2)
            buffer.seek(0)
            picture = Image.open(buffer).convert("RGB")
        picture.save(a.dst / f"{shot['name']}.png")
        print(f"{shot['name']}: {a.only or 'sharpened, JPEG'} {quality if a.only != 'sharpen' else ''}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
