#!/usr/bin/env python3
"""tools/photoreal/app_shots.py OUT [--older] : the photo bench's scenes as a person's own Render draws them
(photoreal12), for src/dev/photoreal_probe.gd -- --shots=OUT.

shots.json stands each scene where its photograph's camera stood and stages it as the photograph was
staged: its own light (a window, daylight), the light turned to where the photograph's stood, the
photograph's camera's grain, vignette, sharpening and JPEG, its parts' age and dust, its table matched by
measure. A person who opens the model and presses Render gets none of that: Best, the product look, the
studio's light, and the background they choose. This writes each scene as that: the camera where the
photograph's stood (its place, lens and focus, a person's choices in the dialog), the studio's light,
the light unturned, and the background the photograph shows, chosen as Render offers it: the desk,
the leather pad or the stone counter (StudioRender.STAGES, in its own colour) where the photograph's
table is one, the seamless in the photograph's colour otherwise. Everything else is the product look's own.

  --older   for a tree before photoreal11: the stone counter is terrazzo there, and the tables' colours
            are its own (photoreal10's STAGES)
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "tools" / "photoreal" / "shots.json"

# Where the scene stands and how it is seen: the camera, kept.
KEPT = ["name", "kind", "model", "photo", "size", "yaw", "pitch", "zoom", "shift", "focal_mm", "f_stop",
        "focus", "roll", "faces", "gloss", "mask", "fit_overlap", "photo_is_render", "crop"]
# The table each surface is, as Render names it, and its colour (StudioRender.STAGES).
TABLES = {1: "desk", 2: "leather", 3: "stone"}
COLOURS = {"desk": "#c4bcae", "leather": "#9c9585", "stone": "#b4a98e"}
OLDER = {"desk": ("desk", "#c4bdad"), "leather": ("leather", "#5c5752"), "stone": ("terrazzo", "#736152")}


def app_shot(shot: dict, older: bool) -> dict:
    out = {k: shot[k] for k in KEPT if k in shot}
    out["lighting"] = "studio"
    table = TABLES.get(int(shot.get("surface", 0)))
    if table:
        stage, colour = OLDER[table] if older else (table, COLOURS[table])
        out["stage"] = stage
        out["backdrop"] = colour
    else:
        out["stage"] = "none"
        out["backdrop"] = shot.get("backdrop", "#ffffff")
    return out


def main() -> int:
    args = sys.argv[1:]
    older = "--older" in args
    args = [a for a in args if a != "--older"]
    if not args:
        print(__doc__)
        return 2
    said = json.loads(SHOTS.read_text())
    shots = [app_shot(s, older) for s in said["shots"]]
    Path(args[0]).write_text(json.dumps({"about": "tools/photoreal/app_shots.py: the bench's scenes as a "
                                         "person's own Render draws them" + (" (an older tree)" if older else ""),
                                         "shots": shots}, indent=1))
    for s in shots:
        print(f"  {s['name']:18s} stage {s['stage'] or 'none':9s} backdrop {s['backdrop']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
