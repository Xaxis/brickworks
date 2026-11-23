"""photo_trees.py OUT (from a checkout's root) : the photograph side of the attribution (photoreal6). Each shot's photograph as
the judge is shown it (photoreal.py photo_of), written as a tree of its own:

- OUT/photoasis_d1: unchanged, a control (a photograph judged as a tree should score as the photographs);
- OUT/photosoft_d1: through a 5-pixel median, which takes out what a render lacks and keeps the
  shapes, light, colour, framing and focus: dust, scratches, scuffs, mould marks, the plastic's fine
  texture, sensor noise and JPEG blocks.

What the photograph loses between the two is what that fine surface carries, with the renderer,
the scene and the staging held as the real ones.
"""
import json
import sys
from pathlib import Path

from PIL import ImageFilter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent.parent / "bench"))
import photoreal  # noqa: E402

out = Path(sys.argv[1])
shots = json.loads((HERE.parent / "shots.json").read_text())["shots"]
for tree in ("photoasis_d1", "photosoft_d1"):
    (out / tree).mkdir(parents=True, exist_ok=True)
for shot in shots:
    photo = photoreal.photo_of(shot).convert("RGB")
    photo.save(out / "photoasis_d1" / f"{shot['name']}.png")
    photo.filter(ImageFilter.MedianFilter(5)).save(out / "photosoft_d1" / f"{shot['name']}.png")
    print(shot["name"], photo.size)
