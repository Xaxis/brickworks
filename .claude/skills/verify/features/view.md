# View

Looking at the model: the camera, what the keys do, the booklet, mosaics, and the
picture the assistant is shown.

<!-- covers: ui:camera controls, ui:controls panel and hint, ui:pointer cursors, lib:renders for the critique, lib:studs written on the render, ui:build steps, ui:mosaic, lib:finishes, lib:true colour -->

## Sub-features

- `camera controls`: orbit, pan, zoom, and framing what is built. `_built_bounds()`
  is what everything frames against, baseplate excluded. Nothing that begins
  over the interface is the camera's: a wheel notch, a trackpad swipe or pinch,
  or a right or middle press over any panel, dialog, popup or the toolbar is
  dropped (`CadCamera._begins_over_interface`, asking `Main._over_interface`:
  the control Godot found under the pointer, or `_over_panel_at`). Godot passes
  a scroll through any control that does not use it (a list at its end, a dialog
  with nothing to scroll) and never stops a gesture, so the owner's "scrolling
  within a modal ... continues to move the model" was every panel, not one.
  `cursor_probe` scrolls every way over the bin (scrolling, at its top, at its
  end), the colours, the assistant, the toolbar, an open menu, the controls
  panel, the minifigure builder, Make a part, the mosaic, the parts list and the
  timeline and checks the camera did not move; the browser check does the same
  over the bin, the assistant and the controls panel by the view's pixels.
- `the view from the keyboard`: + and - (= without shift, the keypad, Page Up
  and Down; `Main._zoom_key`) zoom a wheel notch a tap; arrows turn the view
  and shift-arrows slide it, unless a selection (nudged) or the booklet (stepped)
  has them; held past `HOLD_AFTER` (0.22 s) the view keeps moving at a rate per
  second (`Main._steer_from_keys`, `CadCamera.key_hold`); nothing fires while a
  text field has the caret. Asked for by the owner. `controls_probe` presses each
  (zoom in, out, keypad, Page Down, turn, tilt, slide, held +, typed -), and the
  deploy's browser check (`tools/web/check.mjs`) moves the real web build with
  -, a held arrow and shift-arrows.
- `escape and quitting`: Escape steps out of whatever is up, innermost first (the
  mosaic dialog, a selection, the parts list, the timeline) and with nothing up
  does nothing. It used to quit the desktop app, which closed it from the mosaic
  dialog once and ended a design run 46 minutes in. Ctrl+Q (Cmd+Q) quits on the
  desktop. `controls_probe` presses Escape with nothing open and fails, from
  `_finalize`, if the app quit under it.
- `status line`: bricks, whether it stands and what it weighs, of the model and
  not the baseplate under it (`Main._on_rebuilt` takes `ModelStore.scenery` off
  the count and the weight): it said 62 bricks and 149 g over the 61-brick
  example car whose parts list says 48 g. An empty baseplate says "Nothing
  built yet: pick a part, then click the baseplate". It is the status bar's
  (`src/ui/status_bar.gd`), along the foot of the window — see
  [building](building.md). Batches, triangles, the catalogue count and the
  frame rate come back with `--stats` (and count everything); they were the
  first line every visitor read.
- `toolbar`: the bar across the top holds the menus (File, Edit, View, Build,
  Tools, Help), the model's name and Account; the toolbar under it the file,
  undo, the tools, the clipboard, snap and turn step and the view. Both are
  [building](building.md)'s `menus and toolbar`. The bar wraps onto a second
  line where it does not fit (an `HFlowContainer`) and the toolbar folds its
  least-needed groups away (`Toolbar._fit`): as one row the old bar set the
  width of the whole window, and on a phone the assistant's rail was off the
  page. `tools/web/fit_check.mjs` asks for New, Save and both rails on both
  phones.
- `controls panel and hint`: the on-screen list of what the keys do, opened with
  `,`, `F1` or Help, Keys and controls — and every key on it actually doing that. Its last
  line says which build this is (`BuildInfo.describe()`): "Brickworks 0.1.0,
  released 2026-10-10 (3f2a9c1)" in a release, ", development build" from
  source, and on the web the version before the deploy's commit and time. The
  desktop window title carries the version too. `--about` prints the same line
  ([release](release.md)). One table,
  `ControlsHint.for_keyboard()`, in sections (Building, Selecting, The view, The
  timeline, Panels), holds every control the handlers answer to, redo, Ctrl-A,
  Delete, Escape, the numbered views, shift-middle-drag, shift-scroll and the
  double-clicks included. Keys are drawn as caps; the mouse, trackpad and fingers
  as pictures (`assets/ui/controls/*.svg`: a mouse with the button lit, a drag
  with four arrows, the wheel, two fingers, a pinch, the arrow keys), chosen by
  `ControlsHint.pieces()`. The panel adds, beside each row, the cursor that
  control shows (`Binding.cursor`), and the words as tooltips. The middle-drag and
  shift-middle-drag rows change verb and cursor with the "middle button slides"
  box, and so does the strip. Asked for by the owner ("shouldnt their be a list of
  controls with corresponding icons"). `cursor_probe` checks the panel draws
  pictures and caps and that its middle row follows the setting, and saves
  `shots/cursors/help_dialog.png` and `strip.png` to look at.
- `pointer cursors`: `src/ui/cursors.gd`. The pointer over the model says what a
  click does and what a drag is doing: place (arrow with a blue plus), blocked
  (forbidden), busy (the held part still fetching), select (shift over a brick:
  pointing hand), remove (right button down over a brick, not yet moved: arrow
  with a red minus), orbit, slide, zoom in/out (for 350 ms after a wheel notch,
  swipe, pinch or key), box (crosshair with a dashed box), paint (C held: a
  brush). Text fields keep the I-beam; every `BaseButton` and `Slider` gets a
  pointing hand (`Cursors._point_at`, on `node_added`). `Cursors.choose()` picks
  the state from a `Situation` that `Main._cursor_state()` fills from live state
  every frame — polled, so a drag ended outside the window, a dialog closed by a
  key and Escape cannot leave a stale cursor. It is shown as Godot's default
  cursor shape; custom pictures are hung on shapes the interface never uses
  (`Cursors.SHAPES`). During a drag a full-window `MOUSE_FILTER_PASS` sheet
  (`_shield`) carries the drag's shape so a turn across a panel stays a turn.
  Pictures are `assets/ui/cursors/*.svg`, drawn by `Icons` at 1x, 1.5x or 2x by
  screen DPI on Windows and X11, 1x on a Mac (NSCursor takes pixels as points),
  and in a browser as CSS `image-set()` with 1x and 2x so a 2x screen is sharp.
  Escape now also throws away a box being drawn (its release is not a click) and
  closes the controls panel. Asked for by the owner ("the app's cursor should
  change based on which function is being performed").
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
  Highlights: the sun's specular is 0.25 and the rim's 0.3 (were 1.0 and 1.5),
  `ModelShot`'s key 0.25, and opaque plastic's `base_roughness` 0.28 (was 0.22;
  transparent keeps about 0.09). A flat glossy face at the mirror angle to one
  small light reflects it from every point, so the whole face went white: the
  eleventh Orthanc's dark bluish grey rock was drawn ringed in white bands, and
  there is no white in it (11.6% of the rock lighter than light bluish grey,
  now 3.7%). A larger sun (`light_angular_distance`) spreads the flash over
  more of the face, not less. Specular alone is a knife edge against
  `finish_probe`, which needs plastic to glint so rubber can be without one: at
  0.15 trans rubber stopped differing, at 0.25 slopes went pale; the roughness
  is what lets both hold. On the web (Compatibility) the energy is cut to
  calibrate the diffuse and the glint went with it, so specular has its own
  factor there (`BrickWorld.light_specular`, x2): the web never went pale, and
  without it trans rubber stopped differing from trans plastic. `highlight_probe` turns 48 dark bluish grey slopes of
  three kinds 16 ways, looks from eight directions at two heights and from each
  of the assistant's views, ignores edge pixels (half background), and fails
  past 2% of the model lighter than L 0.80 (the old lights: 8.1%).
- `studs written on the render`: `src/ai/shot_ruler.gd`. Two ticked, numbered
  lines along the model's near corner, drawn by projecting world positions through
  the same camera that took the picture. A render says what was built and not
  where it is, so a number read off the image is the number to write in a
  placement.
- `the timeline`: `StepsBar` (`src/ui/steps_bar.gd`), opened by B, the toolbar's
  Timeline or a design's Build steps. A slider over every brick, from an empty
  baseplate to the finished model: drag it, Start/End (Home/End), Back/Next a
  step (arrows), Play and Reverse (space plays), at 0.5x-4x, the whole build
  taking 6-40 s at 1x. Three orders: Build order (`Instructions.plan`, the
  booklet's, with its step captions), As made (brick numbers, the order what
  stands was placed — by hand, or the order Claude thought of it) and History
  (every add and removal since the baseplate was last cleared, from
  `BrickWorld.history`, which notes add/remove/move/paint/clear with a key of
  generation and number because clear() reuses numbers). In History, bricks no
  longer standing are drawn as ghosts (`BrickWorld.add_ghost`) and taken away
  when the timeline closes or changes order. A ghost is drawn and is not in the
  model: `bricks()`, `brick_count()`, `get_brick()` and the bounds leave it out,
  so a save, the autosave or Claude over the connector never sees one. They were
  plain bricks at first, and a save with History open wrote them into the file. Asked for by the owner ("how
  about both"); it was a forward-only step player. `controls_probe` plays it
  forward and back, pauses, jumps to both ends, checks As made is placement
  order, and that History shows a removed brick before its removal, not after,
  that a save made with History open writes the model as it stands, and that it
  leaves nothing behind.
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
godot --path . --resolution 1400x900 --script src/dev/cursor_probe.gd  # the pointer in every state, and back
godot --headless --path . --script src/dev/glyph_probe.gd         # the font can draw every character shown
godot --headless --path . --script src/dev/instructions_probe.gd  # a booklet could be followed
#   covers the Technic ordering case via models/kart.ldr
godot --headless --path . --script src/dev/mosaic_probe.gd        # the picture still looks like the picture
godot --path . --resolution 1200x800 --script src/dev/shot_probe.gd   # the render is of the model
godot --path . --resolution 1200x800 --script src/dev/gizmo_probe.gd  # the corner says which way you face
godot --path . --resolution 1400x900 --script src/dev/colour_probe.gd # picking a colour recolours something
godot --path . --resolution 1400x900 --script src/dev/finish_probe.gd # every finish drawn as itself
godot --path . --resolution 1400x900 --script src/dev/true_colour_probe.gd # black is black, greys are grey
godot --path . --resolution 1200x800 --script src/dev/highlight_probe.gd   # a glossy slope does not go white
# the same three on Forward+ and the GPU (the plain godot is Compatibility, in software):
~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 --script src/dev/finish_probe.gd
```

Proves it when: each exits 0 with no `FAIL`. `shot`, `gizmo` and `colour` also
leave an image — look at it; that is the point of them. So does `cursor`:
`shots/cursors/cursor_sheet.png` (every cursor at 1x and 2x on dark and light,
hotspot in red), `help_dialog.png` and `strip.png`. In a browser,
`node tools/web/cursor_check.mjs --url=http://127.0.0.1:PORT/` (a web export
served by `tools/web/serve.py`) reads the canvas's computed CSS cursor in each
state, checks the picture's 1x and 2x decode to 32 and 64 px, and leaves
`shots/cursors/web_<state>.png` with the computed cursor drawn where the pointer
is (Playwright's screenshots do not draw the pointer). So do `finish`
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

- **The cursor is read back from the display server, which a headless run
  does not have.** `DisplayServerHeadless` answers "arrow" to every shape, so
  `cursor_probe` runs in a window like the ones below. It asserts both the app's
  state (`Cursors.shown()`) and `DisplayServer.cursor_get_shape()`, because the
  default shape only shows where no control is under the pointer, and a state the
  window never showed is the bug.
- **Godot picks the cursor shape when the pointer moves.** Anything that changes
  what is under a still pointer — a dialog closing on Escape or Done, Tab folding
  a panel — left the old shape (the Done button's hand) until the mouse was
  nudged. `Cursors._input` marks a recheck on every key and button release and
  `Viewport.update_mouse_cursor_state()` replays a motion where the pointer is.
  **That replay never reaches GDScript**: Godot marks a motion it makes up
  `DEVICE_ID_INTERNAL` and `Node._call_unhandled_input` drops it, so it fixes the
  interface's shape and not the model's ghost. `Cursors.looked_again` has
  `Main._hover_again` re-aim the ghost itself; without it, after a box the pointer
  said "arrow" where a click would place. It aims at `get_mouse_position()`,
  which for the root window is the system pointer, not the last event — so
  `cursor_probe` moves the system pointer too (`Input.warp_mouse`), only under
  Xvfb, and `check.sh` always runs it there. The same replay is asked for on
  every change of state, because in Chromium `Input.set_default_cursor_shape`'s
  own replay did not land: after the wheel's moment the page said "place" and
  the canvas showed the zoom glass until the mouse moved. And whenever the
  control under the pointer changes, because a panel keeps from the model the
  motion that crossed into it: the ghost stayed drawn at the panel's edge, and a
  browser check read its going away as the view moving.
- **Six of these need a display** (`shot`, `gizmo`, `colour`, `feel`, `cursor`, and
  `marquee` in [building](building.md)). A headless run has no rendering device
  for the SubViewport, so they are last in `tools/check.sh` and flash a window
  open. **They no longer need a desktop session**: `check.sh` tries `xdpyinfo`
  first and falls back to `xvfb-run -a` when there is no display, which there is
  not from a detached shell, after the screen locks, or on a machine nobody is
  sitting at. Without it the six fail with "X11 Display is not available",
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
