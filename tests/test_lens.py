"""Every ray from the screen goes through the lens the view is drawn with.

The view's lens is shifted to the middle of the model's column
(``CadCamera``): a frustum whose middle is not the window's.  Godot's
``Camera3D.project_ray_normal`` and ``project_position`` assume a frustum
centred on the window, so through this one they point up to 0.2 rad away
from what is under the pointer.  The first time the lens was shifted, every
click in ``assembly_probe`` missed its part for exactly that reason.  So a
ray from the screen is ``CadCamera.ray_origin`` and ``ray_normal``, and the
engine's own are kept out of the app.

``unproject_position`` is exact (it is the projection matrix itself) and is
allowed.  The one camera with a lens of its own, never shifted, is the
minifigure mould editor's.
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ENGINE_RAYS = re.compile(r"\.(project_ray_origin|project_ray_normal|project_position"
                         r"|project_local_ray_normal)\(")
# Files whose cameras are their own and centred on their own viewport, and
# the probe that calls the engine's rays to show they miss through the
# shifted lens (so that its check of ray_normal is known to be able to fail).
OWN_LENS = {"src/minifig/mould_editor.gd", "src/dev/camera_probe.gd"}


def test_no_ray_from_the_screen_skips_the_lens():
    found = []
    for path in sorted((ROOT / "src").rglob("*.gd")):
        name = path.relative_to(ROOT).as_posix()
        if name in OWN_LENS:
            continue
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            code = line.split("#", 1)[0]
            if ENGINE_RAYS.search(code):
                found.append(f"{name}:{number}: {line.strip()}")
    assert not found, ("a ray from the screen through Godot's own projection, which "
                       "ignores the lens shift; use CadCamera.ray_origin and ray_normal:\n  "
                       + "\n  ".join(found))
