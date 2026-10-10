# View

Looking at the model: the camera, what the keys do, the booklet, mosaics, and the
picture the assistant is shown.

<!-- covers: ui:camera controls, ui:controls panel and hint, lib:renders for the critique, lib:studs written on the render, ui:build steps, ui:mosaic, lib:finishes, lib:true colour -->

## Sub-features

- `camera controls`: orbit, pan, zoom, and framing what is built. `_built_bounds()`
  is what everything frames against, baseplate excluded.
- `the view from the keyboard`: + and - (= without shift, the keypad, Page Up
  and Down; `Main._zoom_key`) zoom a wheel notch a tap; arrows turn the view
  and shift-arrows slide it, unless a selection (nudged) or the booklet (stepped)
  has them; held past `HOLD_AFTER` (0.22 s) the view keeps moving at a rate per
  second (`Main._steer_from_keys`, `CadCamera.key_hold`); nothing fires while a
  text field has the caret. Asked for by the owner. `controls_probe` presses each
  (zoom in, out, keypad, Page Down, turn, tilt, slide, held +, typed -), and the
  deploy's browser check (`tools/web/check.mjs`) moves the real web build with
  -, a held arrow and shift-arrows.
- `status line`: bricks, whether it stands and what it weighs. Batches,
  triangles, the catalogue count and the frame rate come back with `--stats`;
  they were the first line every visitor read.
- `toolbar`: the file (Save, Open, Export), what to make of it (Parts list,
  Mosaic), Help — and Clear at the far end, which asks first, because it takes
  the undo history with it.
- `controls panel and hint`: the on-screen list of what the keys do, opened with
  `,` or the Help button — and every key on it actually doing that. Its last
  line says which build this is (`BuildInfo.describe()`): "Brickworks 0.1.0,
  released 2026-10-10 (3f2a9c1)" in a release, ", development build" from
  source, and on the web the version before the deploy's commit and time. The
  desktop window title carries the version too. `--about` prints the same line
  ([release](release.md)).
- `renders for the critique`: the image handed to the assistant so it can see what
  it built, drawn by a SubViewport. Two opposite corners, so every side has been
  seen; a close look at one part of a model too big to judge whole; and, after an
  edit, the bricks that edit added or moved restaged in magenta, so the design can
  find its own change by looking rather than by re-reading coordinates. The stage
  is a copy of the world — the model keeps the colours it was given.
- `seams between bricks`: `src/render/plastic_body.gdshaderinc`. A real brick
  is 0.2 mm short of its pitch, so two that meet show a seam; the meshes carry no
  edge lines, and without one a wall of forty bricks and a wall of four drew as
  the same grey slab. Each batch's material copy carries its part's box
  (`BrickWorld._create_batch`), and a fragment near two of the box's faces is on
  an edge and is darkened, half an LDU or one pixel wide, whichever is wider. A
  zero box draws none, so parts-bin previews have none. Check it by eye: the
  gallery's castle and house show their courses, under Forward+ and under
  `--rendering-method gl_compatibility` (what the web build uses, under Xvfb).
- `finishes`: `src/render/plastic_body.gdshaderinc` (FINISHES). Every LEGO
  finish is drawn as itself: chrome (a mirror of a drawn studio), metallic paint
  (the same, blurred, with flake), pearl (sheen), speckle and glitter (flecks in
  LDConfig's own fleck colour and fraction; glitter's flash with the view), opal
  (milky trans with an edge shimmer), glow-in-the-dark (waxy, faint light,
  drawn opaque), fluorescent trans-neon (lit from inside), rubber and fabric
  (matte; fabric woven), milky white (light spreads). `PartLibrary.finish_for()`
  reads LDConfig's finish, MATERIAL and name; `BrickColor.instance_custom` packs
  the finish number, fleck fraction and fleck colour, and `BrickWorld` carries it
  per brick in the MultiMesh's custom data, so a finish costs no batch, no
  material and no draw call: 14 colours of 3001 in every finish are 2 batches.
  The parts-bin previews take it as `finish_override`.
- `true colour`: what a palette value looks like on screen. `PartLibrary.shown_for()`
  draws the black family neutral (LDraw's black is #1B2A34, a blue-black that lit
  read as navy); the lights in `main.tscn` and `ModelShot` are neutral and set so
  a lit face shows about its own colour; `BrickWorld.light_energy()` weakens them
  under Compatibility, which lights in sRGB space. The parts-bin previews keep
  their brighter light: a preview is judged by whether its average reads as the
  colour, and at true exposure a lit blue averaged nearer black.
- `studs written on the render`: `src/ai/shot_ruler.gd`. Two ticked, numbered
  lines along the model's near corner, drawn by projecting world positions through
  the same camera that took the picture. A render says what was built and not
  where it is, so a number read off the image is the number to write in a
  placement.
- `the timeline`: `StepsBar` (`src/ui/steps_bar.gd`), opened by B, the toolbar's
  Timeline or a design's Build steps. A slider over every brick, from an empty
  baseplate to the finished model: drag it, Start/End (Home/End), Back/Next a
  step (arrows), Play and Reverse (space plays), at 0.5x-4x, the whole build
  taking 6-40 s at 1x. Two orders: Build order (`Instructions.plan`, the
  booklet's, with its step captions) and As made (brick numbers, the order
  bricks were placed — by hand, or the order Claude thought of them). Asked for
  by the owner; it was a forward-only step player. `controls_probe` plays it
  forward and back, pauses, jumps to both ends and checks As made is placement
  order.
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
godot --path . --resolution 1400x900 --script src/dev/finish_probe.gd # every finish drawn as itself
godot --path . --resolution 1400x900 --script src/dev/true_colour_probe.gd # black is black, greys are grey
# the same three on Forward+ and the GPU (the plain godot is Compatibility, in software):
~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 --script src/dev/finish_probe.gd
```

Proves it when: each exits 0 with no `FAIL`. `shot`, `gizmo` and `colour` also
leave an image — look at it; that is the point of them. So do `finish`
(`shots/finishes_<renderer>.png`, a row of one real colour per finish, and
`finishes_shot_<renderer>.png`, the same in the critique render) and
`true colour` (`shots/true_colour_<renderer>.png`, with the sampled boxes drawn). `shot` also times a
picture: under two seconds with vsync on, against the six seconds it used to
take, which is what made a design run give up on looking at itself.

## Gotchas

- **The two renderers do not light in the same colour space.** Forward+ lights
  linear values and converts on output; Compatibility (the web build's) lights
  the sRGB values themselves and writes them out as they are. Measured: a
  shader writing linear 0.214 shows #7F7F7F under Forward+ and #363636 under
  Compatibility. So the shader linearises only under Forward+
  (`BrickWorld._linearise_colors`), and twice the light doubles an sRGB value on
  the web where it moves it a fifth of the way to white on the desktop. The
  same lights washed every grey to white on the web; `BrickWorld.light_energy`
  is the one place that compensates. I believed the opposite for an hour and
  removed the switch; the measurement put it back.
- **Under Compatibility a light that casts shadows is far stronger than its
  energy says.** It is drawn as a pass of its own: with the sun's shadow turned
  off the lit greys dropped from L 0.74 to 0.57 at the same energy, and a sun at
  a ninth of its energy added what all of it adds under Forward+. So the sun
  gets 0.11 there and the other lights 0.6 (`light_energy(…, casts_shadows)`).
  Measured on the desktop's Compatibility renderer and then seen in Chromium on
  a local web export: the greys, black, red and blue read the same.
- **The finishes' own light is linear, and Compatibility writes sRGB.** A
  mirror's floor of 0.09 is a mid-dark grey under Forward+ and black under
  Compatibility, its sky white in both: chrome on the web was white faces and
  black holes. Every finish's emission is worked out in linear light and
  encoded for Compatibility at the end of the shader.
- **Black read as navy, and the colour data was not the main reason.** Every
  lit face got about three times its own colour (dark bluish grey #646464 came
  out #BDBFC2), the sky it reflects and the ambient were blue-grey, and the
  fill was cool. Black's small blue tint, multiplied by three, was slate blue
  (#3F5D77 on top). Fixed in the light (a third of it, neutral) and in
  `PartLibrary.shown_for` (dark, nearly grey values lose most of their tint);
  the palette data is untouched, and the saturation/contrast adjustment went:
  red's lit front reads #CC0014 against LEGO's #C91A09 without it.
- **The seam's highlight on dark plastic never reached black.** The cut was
  linear luminance 0.02 and black is 0.0214, so black got the dark seam it
  could not show. It is 0.025 now, judged in linear on both renderers.
- **A flat face reflects one direction.** Chrome against a studio fixed in the
  world came out the same grey from most angles. The studio in
  `plastic_body.gdshaderinc` is held to the eye: tops of bricks mirror the
  bright overhead, faces turned to you mirror a dark floor, studs carry bands.
  Chrome needs that contrast; the engine's own sky reflection is kept small on
  metals because it washes the dark faces out.
- **Flecks finer than a pixel crawl.** Speckle, glitter, opal and metallic flake
  fade to their average when a fleck is under about two pixels, and glitter's
  flash fades with it. Derivatives are taken outside the per-finish branches.
- **The palette's swatches are filled rectangles only.** Drawn with polygons,
  circles and lines, 84 swatches cost 149 draw calls a frame (2-4 ms on a
  200,000-brick model, more than the finishes cost in 3D); as rectangles the
  whole frame is 431 draws against 463 for the old 44-swatch row.
- **A probe that waits in the `heavy` queue runs whatever code is on disk when
  it starts.** On a loaded machine that is minutes later. Do not edit while
  measuring, or the numbers belong to neither version.

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
- **`glyph_probe` exists because a missing glyph is invisible.** It also reads
  every string literal in `src/ui/*.gd` and `main.gd`, because text that only
  appears at runtime (the run card's ticks) was never in the tree it walked. A character the
  font cannot draw shows as nothing at all, and nothing is what an empty label
  also looks like.
- **Framing uses `_built_bounds()`**, not the world's bounds; the baseplate is
  scenery and would frame the scenery.
- `_ground_for_the_model` must not be called inside the `built` signal — it
  rebuilds the ground from inside the signal that says the ground changed, and the
  run hangs with no output. `call_deferred` it.
