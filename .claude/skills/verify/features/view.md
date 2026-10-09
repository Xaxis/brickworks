# View

Looking at the model: the camera, what the keys do, the booklet, mosaics, and the
picture the assistant is shown.

<!-- covers: ui:camera controls, ui:controls panel and hint, lib:renders for the critique, lib:studs written on the render, ui:build steps, ui:mosaic -->

## Sub-features

- `camera controls`: orbit, pan, zoom, and framing what is built. `_built_bounds()`
  is what everything frames against, baseplate excluded.
- `controls panel and hint`: the on-screen list of what the keys do, opened with
  `,` or the Controls button — and every key on it actually doing that.
- `renders for the critique`: the image handed to the assistant so it can see what
  it built, drawn by a SubViewport. Two opposite corners, so every side has been
  seen; a close look at one part of a model too big to judge whole; and, after an
  edit, the bricks that edit added or moved restaged in magenta, so the design can
  find its own change by looking rather than by re-reading coordinates. The stage
  is a copy of the world — the model keeps the colours it was given.
- `studs written on the render`: `src/ai/shot_ruler.gd`. Two ticked, numbered
  lines along the model's near corner, drawn by projecting world positions through
  the same camera that took the picture. A render says what was built and not
  where it is, so a number read off the image is the number to write in a
  placement.
- `build steps`: the model split into steps a person could follow in order,
  nothing placed before what holds it. A model wider than 24 studs is built a
  region at a time (`Instructions.REGION`): one tile of its plan finished before
  the next, borrowing only the bricks a region is directly waiting on, and the
  booklet frames each region on its own and names it ("Step 39 of 350 · part 2").
  On a 1,895-part castle the jump between consecutive steps went from a median
  of 12.5 studs (90th 38) to 6.2 (90th 12). `--booklet=PATH` with `--model=`
  writes the booklet and quits — about three minutes for that castle on the GPU.
- `mosaic`: a picture turned into a plate of tiles that still looks like the
  picture.

## How to reach it

```sh
godot --path .             # right-drag turns, scroll zooms, F frames, O squares on,
                           # middle-drag slides or turns (a preference), , lists every key
godot --path . -- --shot=/tmp/model.png --model=models/car.ldr   # one render, then quit
godot --path . -- --booklet=/tmp/b.html --model=models/station.ldr  # the booklet, then quit
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
#   covers the Technic ordering case via models/kart.ldr
godot --headless --path . --script src/dev/mosaic_probe.gd        # the picture still looks like the picture
godot --path . --resolution 1200x800 --script src/dev/shot_probe.gd   # the render is of the model
godot --path . --resolution 1200x800 --script src/dev/gizmo_probe.gd  # the corner says which way you face
godot --path . --resolution 1400x900 --script src/dev/colour_probe.gd # picking a colour recolours something
```

Proves it when: each exits 0 with no `FAIL`. `shot`, `gizmo` and `colour` also
leave an image — look at it; that is the point of them. `shot` also times a
picture: under two seconds with vsync on, against the six seconds it used to
take, which is what made a design run give up on looking at itself.

## Gotchas

- **Five of these need a display** (`shot`, `gizmo`, `colour`, `feel`, and
  `marquee` in [building](building.md)). A headless run has no rendering device
  for the SubViewport, so they are last in `tools/check.sh` and flash a window
  open. **They no longer need a desktop session**: `check.sh` tries `xdpyinfo`
  first and falls back to `xvfb-run -a` when there is no display, which there is
  not from a detached shell, after the screen locks, or on a machine nobody is
  sitting at. Without it the five fail with "X11 Display is not available",
  which reads like a broken probe and is not. Rendering works the same there and
  is faster — a frame costs 124 ms on Xvfb against 989 ms on the compositor.
  A design run can have one the same way:
  `MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1500x950x24" godot --path . -- --ask=…`
  **With that env var**, or the real GPU is not used at all: Xvfb cannot hand the
  driver a buffer to present, so Godot falls back to lavapipe and draws on the CPU
  — a ten-frame scene cost 8.6 s of CPU against 0.33 s with it. `check.sh` sets it
  for the on-screen checks already; a design run has to be given it by hand. Every
  Voyager benchmark on 2026-10-03 was measured without it, so those picture
  timings are pessimistic.
- **A window nobody is looking at runs at one frame a second.** Measured on this
  machine: 989 ms a frame with vsync as shipped, 20 ms with it off. Everything in
  these probes is counted in frames, so the 150-frame wait for the catalogue was
  two and a half minutes of nothing, and a picture — six frames — took six
  seconds at *every* model size from one brick to four hundred. The model was
  never the cost. So: `ModelShot.take` turns vsync off for the duration and puts
  it back; a run driven from the command line turns it off for the whole run
  (`_unthrottle_if_nobody_is_watching` in `src/main.gd`, because the command
  socket polls in `_process` and every tool call waited up to a second each way);
  and the windowed probes turn it off at start-up. An interactive window is left
  alone — a CAD program spinning at four hundred frames a second is a laptop fan.
- **A picture is capped in seconds, not frames.** Ninety frames is half a second
  on an idle machine and ten minutes on one running four other copies of the
  engine, which is an ordinary afternoon here. The relay gives up at three
  minutes, so a slow picture is not a slow picture — it is a design left blind,
  and a real run said so: "every request timed out, so I haven't checked those
  proportions by eye." `give_up_after` is twenty seconds, and then the caller
  draws the letters, which show the plan and an elevation and hide nothing. A
  worse picture beats no picture.
- **`shot_probe` puts vsync back on for its speed check, deliberately.** A check
  that measured its own fast setting would pass however slow a picture really is.
  It asserts under two seconds with vsync on, which is the condition that broke a
  real design run.
- **`glyph_probe` exists because a missing glyph is invisible.** A character the
  font cannot draw shows as nothing at all, and nothing is what an empty label
  also looks like.
- **Framing uses `_built_bounds()`**, not the world's bounds; the baseplate is
  scenery and would frame the scenery.
- `_ground_for_the_model` must not be called inside the `built` signal — it
  rebuilds the ground from inside the signal that says the ground changed, and the
  run hangs with no output. `call_deferred` it.
