# View

Looking at the model: the camera, what the keys do, the booklet, mosaics, and the
picture the assistant is shown.

<!-- covers: ui:camera controls, ui:controls panel and hint, lib:renders for the critique, ui:build steps, ui:mosaic -->

## Sub-features

- `camera controls`: orbit, pan, zoom, and framing what is built. `_built_bounds()`
  is what everything frames against, baseplate excluded.
- `controls panel and hint`: the on-screen list of what the keys do, opened with
  `,` or the Controls button — and every key on it actually doing that.
- `renders for the critique`: the image handed to the assistant so it can see what
  it built, drawn by a SubViewport.
- `build steps`: the model split into steps a person could follow in order,
  nothing placed before what holds it.
- `mosaic`: a picture turned into a plate of tiles that still looks like the
  picture.

## How to reach it

```sh
godot --path .             # right-drag turns, scroll zooms, F frames, O squares on,
                           # middle-drag slides or turns (a preference), , lists every key
godot --path . -- --shot=/tmp/model.png --model=models/car.ldr   # one render, then quit
tools/shot.sh              # the screenshots used in the README and the site
```

## How to check it

Static: the project parse check only.

Runtime:

```sh
godot --headless --path . --script src/dev/camera_probe.gd        # the view controls do something
godot --headless --path . --script src/dev/controls_probe.gd      # every advertised key works
godot --headless --path . --script src/dev/glyph_probe.gd         # the font can draw every character shown
godot --headless --path . --script src/dev/instructions_probe.gd  # a booklet could be followed
godot --headless --path . --script src/dev/mosaic_probe.gd        # the picture still looks like the picture
godot --path . --resolution 1200x800 --script src/dev/shot_probe.gd   # the render is of the model
godot --path . --resolution 1200x800 --script src/dev/gizmo_probe.gd  # the corner says which way you face
godot --path . --resolution 1400x900 --script src/dev/colour_probe.gd # picking a colour recolours something
```

Proves it when: each exits 0 with no `FAIL`. `shot`, `gizmo` and `colour` also
leave an image — look at it; that is the point of them.

## Gotchas

- **Four of these need a display** (`shot`, `gizmo`, `colour`, and `marquee` in
  [building](building.md)). A headless run has no rendering device for the
  SubViewport, so they are last in `tools/check.sh` and flash a window open.
- **`glyph_probe` exists because a missing glyph is invisible.** A character the
  font cannot draw shows as nothing at all, and nothing is what an empty label
  also looks like.
- **Framing uses `_built_bounds()`**, not the world's bounds; the baseplate is
  scenery and would frame the scenery.
- `_ground_for_the_model` must not be called inside the `built` signal — it
  rebuilds the ground from inside the signal that says the ground changed, and the
  run hangs with no output. `call_deferred` it.
