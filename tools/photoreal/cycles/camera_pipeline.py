"""camera_pipeline.py FROM TO : each shot's picture in FROM through a camera's own pipeline as its photograph went
through it: a camera's sharpening (an unsharp mask, the halos the judge names in phone photographs), then the JPEG
(the photographs' own quantisation tables: quality 90 for the close-ups' Wikimedia copies, 75 for
the sets' Rebrickable pictures, both 4:2:0), kept as PNG in TO, so the judge's own JPEG at 92 is a
second generation for the renders as it is for the photographs (photoreal6's camera factor)."""
import io
import json
import sys
from pathlib import Path

from PIL import Image, ImageFilter

SHOTS = Path(__file__).resolve().parent.parent / "shots.json"
src, dst = Path(sys.argv[1]), Path(sys.argv[2])
dst.mkdir(parents=True, exist_ok=True)
for shot in json.loads(SHOTS.read_text())["shots"]:
    path = src / f"{shot['name']}.png"
    if not path.exists():
        print(f"no {path}")
        continue
    quality = 75 if shot["kind"] == "set" else 90
    buffer = io.BytesIO()
    sharp = Image.open(path).convert("RGB").filter(ImageFilter.UnsharpMask(radius=1.2, percent=60, threshold=2))
    sharp.save(buffer, "JPEG", quality=quality, subsampling=2)
    buffer.seek(0)
    Image.open(buffer).convert("RGB").save(dst / f"{shot['name']}.png")
    print(f"{shot['name']}: JPEG {quality}")
