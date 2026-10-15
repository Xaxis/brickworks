# View

Looking at the model: the camera, what the keys do, the booklet, mosaics, and the
picture the assistant is shown.

<!-- covers: ui:navigation presets, ui:left-button navigation, ui:view cube, ui:camera controls, ui:controls panel and hint, ui:pointer cursors, lib:renders for the critique, lib:studs written on the render, ui:build steps, cli:score the steps against real sets' authors, ui:the author's steps, cli:the author's steps in a browser, ui:the booklet, ui:mosaic, lib:LEGO Art layout, lib:LEGO Art plans, ui:LEGO Art designed by Claude, cli:LEGO Art in a browser, lib:finishes, lib:true colour, ui:build animation, ui:cut-away, ui:x-ray, cli:see inside in a browser, ui:drawing only what changed, ui:photo-real render, lib:studio renderer, ui:pose and animate, lib:posing joints, lib:keyframed animation, cli:render open check, cli:typing probe -->

## Sub-features

- `navigation presets` (`ViewPrefs.preset`, Settings, "Navigate like"): the
  view is driven as BrickLink Studio drives it by default — right-drag turns
  about the point under the pointer, middle-drag and shift with a right drag
  slide, the wheel zooms to the pointer, F frames the selection or everything,
  1–7 and the keypad give the views, ` squares on and back. Blender's turns
  with the middle button; Mecabricks' slides with the right and zooms with the
  middle. In all three a left drag that does not start on a part with Select
  turns the view (Shift slides) and never places — with a part in hand too
  (`ViewPrefs.drag_verb`, read by the camera, the controls list and the strip
  alike); see `left-button navigation`. Researched from each program's own help
  pages, 2026-10-11 (Studio's help centre, Mecabricks' manual, LDCad's key
  list, Onshape's, Fusion's and Blender's manuals). `feel_probe`,
  `camera_probe` and `cursor_probe` drive each preset.
- `left-button navigation`: the owner, 2026-10-11: "there should be a way to use
  the mouse to move and navigate the view and pan and not placing bricks." A
  trackpad has no middle button. A left press waits (`Main._pending_left`): if
  it comes up within 5 px it is a click (place, select, the tool's click);
  past that it is a drag, which turns the view (Shift: slides), puts nothing
  down, and leaves whatever is in hand in hand. `Ctrl`-drag (`Cmd` on a Mac)
  draws the selection box; a drag starting on a part with Select still moves
  it. Held keys lend the left button to the view in any mode, mid-placement
  too: Space slides, Alt turns, Alt-Shift slides, Ctrl/Cmd-Alt zooms; an
  Alt-click still takes the part into hand. The View group on the toolbar:
  Orbit (`O`), Pan (`H`), Zoom (`Z`) and Fit (`F`) — with one on, the left
  button only does that, the pointer says so, and `Esc` or `V` is Select
  again. Hiding moved to `Ctrl-H`. Two fingers on a trackpad turn (Shift
  slides) and a pinch zooms to the pointer (`WheelKind`); on a Mac, Ctrl-click
  is a right click. The status bar's left line says what the mouse will do
  now (`EditVerbs.hint`: tool, keys held, part under the pointer). Mecabricks
  publishes no trackpad convention we could find, so two-finger turning
  follows SketchUp for Web's. `tools/web/nav_flow.mjs` does all of it with the
  left button, the wheel, a pinch and keys and checks that no brick was put
  down; it fails on brickworks.diy as of 2026-10-11. With each view tool on it
  also clicks Paint on the toolbar and a part in the bin, which must be
  pressed: on brickworks.diy at 91ae209 neither was, with Orbit or Pan on.
  It reads the page only once the app has said it again since the input
  (`fresh()`): with frames sixty a second a read straight after a drag was
  from before it.
- `view cube`: the cube at the model's top right (`ViewCube`, replacing the
  axis dots), the one thing over the model: the model tree and the properties
  are docked in the left-hand column ([building](building.md)'s `docked
  panels`), and `Main.model_cover()` leaves out the points under the cube and
  nothing else. It turns with the view; a click on a face looks from that side, on
  an edge or corner from between two or three (`CadCamera.look_from`); a drag
  on it turns the view. Its four arrows turn a step a click (held, they keep
  turning; dragged, they follow), and under it a pad slides (click an arrow
  of it, or drag), − and + zoom, and the last fits. Each is published to the
  page (`cube_turn_left` …, `cube_pan`, `cube_zoom_in`, `cube_fit`, and
  `cube_<face>` for the faces in view). `gizmo_probe` clicks each.
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
- `centred on the model's column` (`CadCamera.seen`, `Main._model_rect`): the
  3D draws across the whole window, behind the columns, and the view is
  centred on the model's part of it (`model_cover`'s "view": between the
  columns, under the bars; on a phone, between the rails, since a drawer is
  put away to build) rather than on the window, where with one column open
  the model sat 168 units to its side. Done by shifting the lens, not the
  camera: perspective is `PROJECTION_FRUSTUM` with the same 45° across the
  window's height and a `frustum_offset`; straight-on, `h_offset`/`v_offset`,
  which for parallel lines is the same picture. Fit (F, Home, the cube's fit
  and every framing) fits the ball round the model to the narrower side of
  that part, not of the window. A column folding or opening glides the model
  to the new middle (the camera's own easing, following the column's slide)
  and holds still while any button or finger is down, so a drag never loses
  what it grabbed; the ghost is re-aimed as it glides (`lens_moved`).
  Sliding the camera instead (`h_offset` in perspective, tried 2026-10-12)
  looked at the model 10° from the side. Godot's `project_ray_normal` and
  `project_position` assume a centred frustum and are 0.09 rad out at 168
  units, so the first lens shift missed every click in `assembly_probe`: every
  ray from the screen is `CadCamera.ray_origin`/`ray_normal`, which invert
  the projection the view is drawn with (`unproject_position` is exact as it
  is), and `tests/test_lens.py` fails on the engine's two anywhere in `src/`
  but the mould editor's own camera and `camera_probe`, which calls them to
  show they miss. `camera_probe` checks the shifted view
  against a camera of its own the size of the seen rect (same picture to
  0.000 px, same framing), every ray back through what is drawn, that
  Godot's would miss, the hold mid-drag and the glide. `centring_probe`
  (Xvfb, `--resolution 1280x720`, and `--resolution 2560x1440 -- --ratio=2`
  for two pixels to the unit) folds each column in turn, presses F and
  checks the model's middle is within 2% of the middle of its part, all of
  it inside, then picks five parts from the world (a straight line from the
  eye reaches each first), checks hiding each changes the pixel at its point
  and a click there selects exactly it; on the code before this, the middle
  is 168 units out. It also takes an exported picture (`Picture.take`, the
  share card's and the Studio thumbnail's path) with the lens shifted each
  way and requires the model in the same place in both: the window's lens
  never reaches a camera of its own. Where it sits there is the picture's
  own framing, which centres the box round the model, not what is drawn
  (1.8% left and 9% low on the probe's flat scene, either way). A
  check that aims at the model must find it again after a column opens or
  folds, Q among them (it brings the bin out, and in a window with room for
  one column the model moves 338 units): `cursor_check.mjs` does, and
  `nav_flow.mjs` frames the model before the view tools, since its pinch
  at the middle of the view now ends under the baseplate. `tools/web/centre_check.mjs --url=…` does the centring
  is 168 units out. Then, at 1x only (a picture is drawn at its own size
  whatever the window's pixels), the pictures (`_pictures`): with each
  column folded, Export › Picture at 2400 x 1600 of the example car and an
  L of bricks (a long low arm, a short tall one), the car's share card
  (1200 x 630) and Studio thumbnail (800 x 600), and once Orthanc; and the
  critique's corner shot of all three drawn on clear (`ModelShot`). What is
  drawn (`Image.get_used_rect`) has its middle within 2% of the picture's,
  fills 80 to 97% of its narrower way and touches no edge (in
  `shots/centring/`). Framed on the box round the model (before 2026-10-13)
  the car's picture was 3% right and 5% low, filling 64%, and the L's 8%
  left and 9% low, filling 44%; framed on every part's corners, all within
  0.3%, filling 88 to 91%. The pictures take about 70 s of the run (358 s
  at load 30 to 40), and say how long each model took.
  `tools/web/centre_check.mjs --url=…` does the centring
  and the five clicks in Chromium at 1x and 2x (`brickworksLayout.centre`
  and `.targets`, `brickworksState.selection`).
- `the view from the keyboard`: + and - (= without shift, the keypad, Page Up
  and Down; `Main._zoom_key`) zoom a wheel notch a tap; arrows turn the view
  and shift-arrows slide it, unless a selection (nudged) or the booklet (stepped)
  has them; W A S D slide it as in Studio, and nudge a selection; Page Up and
  Down raise and lower a selection instead of zooming when there is one; held
  past `HOLD_AFTER` (0.22 s) the view keeps moving at a rate per
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
- `text fields give the keys back` (`src/ui/focus_guard.gd`): Enter, Tab,
  Escape or a press anywhere outside a text field ends the typing, in every
  field — the model's name, the part search, the brief, the properties'
  numbers, a minifigure's name — and every key acts on the model at once.
  Escape also puts the model's name back. Owner: "When the user names a build
  (renames it), the text input never loses focus and can't control the CAD
  controls." `handbuild_probe` ends a field each way and presses a view key;
  `tools/web/focus_check.mjs --url=…` does the same in a browser and reads the
  picture, so it fails on a build from before (9 failures on 2026-10-11's
  live site) and passes after. What Enter kept is what a later Escape puts
  back: a busy tab hands every key since its last frame over in one, so a name
  typed, Enter and Escape half a second later came together, and the Escape put
  the old name back (tabs_flow's rename at a load of 40 to 60, 2026-10-14).
  `typing_probe` (`xvfb-run -a godot --path . --resolution 1400x900 --script
  src/dev/typing_probe.gd`) sends the keys before one frame, and
  `focus_check`'s last case sends them in one task of the page; both fail on
  480b81a (the live site reverted the name 3 times in 3, and kept it without
  the Escape).
- `status line`: bricks, whether it stands and what it weighs, of the model and
  not the baseplate under it (`Main._on_rebuilt` takes `ModelStore.scenery` off
  the count and the weight): it said 62 bricks and 149 g over the 61-brick
  example car whose parts list says 48 g. An empty baseplate says "Nothing
  built yet: pick a part, then click the baseplate". It is the status bar's
  (`src/ui/status_bar.gd`), along the foot of the window — see
  [building](building.md). Batches, triangles, the catalogue count and the
  frame rate come back with `--stats` (and count everything); they were the
  first line every visitor read.
- `build animation`: what the assistant just put down goes up on the baseplate
  in build order instead of appearing at once (`BuildPlayback`, played from
  `Main`'s `built` handler; never in a run driven from the command line). Only
  the app's own designs go up: what a session's call puts down (the web
  connector, the MCP port; `CommandSocket.at_work`) is drawn whole as the call
  answers, because the answer tells Claude it is built. Since a check from
  outside stopped putting the design down (a8e1aa5), every design submitted to
  a tab in view went up for 2.5 s after that answer, and `arrival check` failed
  every shown case (2026-10-13); `claude_undo_probe` holds both halves. Only
  what is new: `Assistant.fresh_ids` is what the last build or edit put down or
  moved, and everything else stays on show (`BuildPlayback.play_new`), so a
  recolour plays nothing and `add_rooms` plays the rooms; a design the app's own
  run showed as a draft (or drew as it streamed in) and then submitted unchanged
  is already standing and plays nothing either. Up to
  `PLANNED_UP_TO` (200) new bricks the order is the booklet's
  (`Instructions.plan`); past it, course by course, one sort of packed keys. A
  step costs a count per batch: `BrickWorld.begin_reveal` writes each batch
  once with its bricks in build order, so the ones on show are always the first
  so many, and `reveal_through` raises `visible_instance_count`. Any change to
  the bricks being revealed ends it with everything shown (`reveal_ended`);
  a change elsewhere — the ground laid wider under a design that outgrew it,
  the moment it is built — leaves it playing. A batch written in order is not
  also rebuilt first. Outside a reveal the world on screen rebuilds a big
  change a slice a frame (`BrickWorld.rebuilds_in_slices`, set by `Main`;
  ModelShot's copy rebuilds whole, because its picture must be). The whole
  assembly takes at most `LONGEST_MS` (2.5 s), several steps to a frame on a
  big model, by the clock on the wall: the engine's frame time is smoothed
  towards the display's rate, and timed by it the Falcon's 2.5 s took 16 s in
  a browser drawing in software. A click or a key ends it, with the model whole. Nothing plays
  where nobody can see it (`Main._watch_view`): a browser tab out of view
  (`document.hidden`) or a minimised window. A tab that goes out of view
  while it plays ends it. Out of view, `Main` also turns off the window's 3D
  drawing (`disable_3d`). A design that arrives out of view, checked or
  submitted, has the camera framed on it (`_ground_for_the_model`'s
  `and_frame`), so whoever looks finds it in view, not wherever the camera
  was left. ModelShot's pictures have their own viewport, so
  they still draw. `FramePace` slices are then 200 ms rather than half a
  frame, so a design goes down at full speed while Claude waits.
  `tools/web/arrival_check.mjs` times the model's arrival in a browser,
  shown and hidden. `playback_probe` checks the order and the prefix on a small model, that
  only new bricks are hidden, and on the owner's Falcon Heavy
  (`src/dev/fixtures/falcon_heavy.json`, 4,242 parts) that starting takes
  milliseconds and no frame of it more than 30.
- `toolbar`: the bar across the top holds the menus (File, Edit, View, Build,
  Tools, Help), the model's name and Account; the toolbar under it the file,
  undo, the tools, the clipboard, snap and turn step and the view. Both are
  [building](building.md)'s `menus and toolbar`. The bar wraps onto a second
  line where it does not fit (an `HFlowContainer`) and the toolbar folds its
  least-needed groups away (`Toolbar._fit`): as one row the old bar set the
  width of the whole window, and on a phone the assistant's rail was off the
  page. `tools/web/fit_check.mjs` asks for New, Save and both rails on both
  phones, and samples the model's part of the window at every size: nothing
  but the view cube over it, and in a laptop's window 60% of the width.
- `drawing only what changed`: `IdleDraw` (`src/render/idle_draw.gd`). The
  app drew every frame with nothing moving: 3.9 ms of the RX 6700 XT a
  frame at 1400x900 (5.5 ms in the owner's bigger window), 58 a second, 23%
  of the card and 35% of a core, for a model standing still; in Chromium on
  SwiftShader the page's main thread was 106% busy and Chromium 597% of a
  core. Now Godot's low-processor mode draws a frame only when something was
  written to the RenderingServer: the camera moving or easing, an edit, a
  step of the build animation, the ghost, a button the pointer lights, a
  part's picture, the loading shimmer (a shader reading TIME is redrawn while
  it is on screen). Standing still: one frame drawn in 5 s, 0.7 ms of the
  card a second, 6% of a core; in Chromium 0 of about 900 frames drawn and
  no WebGL call at all, the main thread 4% busy. Everything still runs each frame (the connector's clock,
  the command socket, FramePace): on the desktop at 60 a second standing
  still and 144 for half a second after anything is drawn or a FramePace
  slice runs; in a browser at the page's own rate (sleep 0, the page's one
  thread cannot sleep). So nothing may write to the RenderingServer every
  frame for nothing: a value set again unchanged is a frame drawn. The
  camera set its pose every frame (`CadCamera._apply` now stops a hundredth
  of a pixel from its target and sets nothing at rest), the axis gizmo
  (the view cube since) redrew itself (now when the camera turned) and the pivot mark rebuilt its
  lines (now when they moved). A frame that draws nothing never reaches
  `frame_pre_draw`, so `OwnFrames` ends one after every node's `_process`
  for `Main._watch_own_frames`. Probes run with every frame drawn, as
  before, unless they turn low-processor mode on first (`IdleDraw.for_the_app`):
  most count on a drawn frame for every frame they wait. `--bench` draws
  every frame. `idle_probe` counts the frames drawn standing still (fails
  past one a second; the old code drew every frame, and with the mode on
  still 7 a second in software for the camera and gizmo), names the node
  whose processing draws them, and checks each change is drawn and then
  nothing: a turn easing to rest, a right drag, a brick put down, every step
  of the build animation, the ghost, a lit button, a part's picture. It opens
  a model of its own choosing, the house, or the castle with
  `-- --model=res://models/castle.ldr`, and the suite runs both: it used to
  open on whatever other probes had left on the baseplate, and passed or
  failed with that. On the castle a few frames of work redrawing the window
  for nothing is seconds of software drawing: the first part taken in hand
  drew a dozen pictures for the bin's tiles out of sight, the whole window
  each, 23 s of the castle with the pointer still (2026-10-13; the house hid
  it in under a second). Those tiles are drawn only in frames drawn anyway
  now (`PartThumbnails`).
  `tools/web/idle_check.mjs` counts the same in Chromium. Frames that draw
  nothing still run every script, so what a script does every frame must be
  in proportion to change as well. The status line and the pointer each
  asked for the part under the pointer every frame. A look that hits nothing
  marches the whole lattice: 18 to 25 ms on the desktop with the Falcon built,
  twice a frame. `EditVerbs.brick_at` now looks again only when the ray or
  `BrickLattice.revision` changed, and not out of view. `idle_probe` counts
  the looks (`EditVerbs.looked`): at most one in 2 s standing still, one when
  the pointer moves, none out of view while the model changes.
- `toolbar`: the file (Save, Open, Export), what to make of it (Parts list,
  Mosaic), Help — and Clear at the far end, which asks first, because it takes
  the undo history with it. It wraps onto a second line where it does not fit
  (an `HFlowContainer`) and its status words end in "…" rather than widen it:
  as one row it set the width of the whole window, and on a phone Clear and
  the assistant's rail were off the page. `tools/web/fit_check.mjs` requires
  both on both phones.
- `cut-away` (`src/ui/see_inside.gd` drives it, `BrickWorld.set_cut` draws it):
  `K`, View → Cut away, or the toolbar's cut button puts a plane across the
  model along Y (the axis last used), through its middle, taking away the side
  the eye is on; a strip at the foot of the model (above the key strip and the
  timeline) has X, Y and Z, a slider that drags it
  through the model (the wheel moves it too), where it is in bricks up or studs
  in, Flip (`Shift-K`), Ghost (what is cut away left faint) and ×. Each part
  is sorted by its box against the plane (`BrickWorld._write_cut`): wholly on
  the near side, drawn by its batch as ever, with the plain shader and its
  early depth test; wholly past the plane, not drawn; across it, by the
  batch's own second MultiMesh (`Batch.through`) with a `_cut` variant of its
  shader (`plastic_cut.gdshader` and five others) that is handed the plane.
  The shader that cuts must discard, which loses the early depth test: when
  every part was drawn with it, a close view of Orthanc cut through the middle
  took minutes a frame in a software browser. Each batch is written nearest
  first, so a drag changes counts and writes only the parts it crosses.
  Measured in software (llvmpipe) on Orthanc: a frame cut at 60% costs less
  than a whole one (0.4 s against 1.3 s), turning the cut on is 65 ms of the
  app's own work and dragging it 11 ms a plate. The variants discard what is past the plane and draw the back
  faces as the cut face (`PLASTIC_CAP` in `plastic_body.gdshaderinc`: flat,
  square to the plane, hatched in the part's colour) — LDraw's surfaces are
  closed, so a back face seen past the plane is exactly where the plane is
  inside plastic. The pointer goes where the eye does: `BrickLattice.cut`
  skips cells past the plane, so a click reaches the floor of a room whose roof
  is cut away. The baseplate is cut too. A model replaced (opened, cleared,
  designed afresh) ends it. The booklet and the assistant's pictures are drawn
  from worlds of their own and never see it; Export's picture is the world on
  screen and does.
- `x-ray` (`src/ui/see_inside.gd`, `BrickWorld.set_xray`): `I`, View → X-ray, or
  the toolbar: everything but the selection — or, editing inside a
  sub-assembly, everything but it — is drawn see-through
  (`see_through.gdshader`: a few percent of fill and an edge, unlit, no shadow,
  no depth), from a MultiMesh of each batch's own beside the batch's, written
  once (60 to 100 ms of work for Orthanc's 8,785 parts, spread over frames). The
  pointer passes through the ghosts (`BrickLattice.see_through`, apart from
  `unseen`, which is hiding by hand) to what is solid. With nothing selected
  and nothing entered it says what to do and stays off; leaving the
  sub-assembly it was showing ends it. The baseplate stays solid, as somewhere
  to put a part. The timeline hides what is to come from both the solid and the
  see-through; the build animation draws the model whole and splits it again
  when it ends.
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
- `pointer cursors`: `src/ui/cursors.gd`. The pointer says what the mouse will
  do now, by the tool, the keys held and what is under it, as Studio, Mecabricks
  and Blender do. The owner, on the live site (2026-10-11): "we're not seeing the
  cursor change based on the mode and context". The browser drew what the app
  chose; the app chose too little: Hide, Clone, Rotate, Hinge and Move showed
  Select's pointing hand, the background the arrow though a drag there turns the
  view, and the Orbit, Pan and Zoom tools, Space and Alt nothing.

  | Situation | State | Shown as |
  |---|---|---|
  | Select, over a part | `select` | system pointing hand |
  | Select, over nothing (a drag turns the view) | `orbit` | picture |
  | Select, Shift held (a drag slides) | `hand` | picture, open hand |
  | Select, Ctrl/Cmd: over a part (copies) / over nothing (box) | `copy` / `box` | pictures |
  | a part dragged, or the view held by any button | `grabbing` | picture, closed hand |
  | a part in hand: it fits / refused / still fetching | `place` / `blocked` / `busy` | crosshair with a plus / system forbidden / system progress |
  | a part in hand, over nothing to put it on | `orbit` | picture |
  | Paint, Delete, Hide, Clone, Rotate, Hinge, Move | `paint` `delete` `hide` `copy` `rotate` `hinge` `move` | bucket, eraser, arrow with a slashed eye / plus / turn / hinge badge, system move |
  | the Orbit, Pan, Zoom tools (Shift: the other verb, Zoom out) | `orbit` `hand` `zoom_in` | pictures |
  | Space held / Alt held (Alt-Shift slides, Ctrl-Alt zooms) | `hand` / `orbit` | pictures |
  | a wheel notch, swipe, pinch or key, for 350 ms | `zoom_in` `zoom_out` `hand` `orbit` | pictures |
  | C held | `paint` | bucket |
  | buttons, sliders, the view cube / text fields / a splitter | (the control's) | pointing hand / I-beam / Godot's split arrows |

  The tools' pointers show over parts and over nothing alike, as the three
  programs do; a drag over nothing still turns the view and says so by
  grabbing. `Main._cursor_state()` fills a `Cursors.Situation` from live state
  every frame and `Cursors.choose()` picks — polled, so a drag ended outside
  the window, a dialog closed by a key and Escape cannot leave a stale cursor.
  It is shown as Godot's default cursor shape (where no control is under the
  pointer, which is exactly the model). Every `BaseButton` and `Slider` gets a
  pointing hand (`Cursors._point_at`, on `node_added`), the view cube sets its
  own. There are thirteen pictures and Godot only hangs a picture on one of its
  seventeen system shapes, most of which the interface, the print studio's
  picker, a dialog's resize edges or a row dragged in the outliner show, so
  three shapes nothing else asks for (`Cursors.SLOTS`: help, wait, drag) take
  turns: a picture is hung when wanted (`Cursors._hang`), never on the slot on
  screen. The old table hung the zoom glass on the resize arrows and "place" on
  the drop sign. During a drag a full-window `MOUSE_FILTER_PASS` sheet
  (`_shield`) carries the grabbing hand so a turn across a panel stays one.
  Only while a button holds the drag (`Cursors.Situation.dragging()`), never
  for what a state is called. It went up for the pointer's name: on
  brickworks.diy with Orbit or Pan on, and here with Ctrl held, it covered every
  panel, and a click on a button turned the view instead (2026-10-12).
  `cursor_probe` now presses Paint and a part in the bin with each view tool on
  and with Ctrl, Space and Alt held.
  Pictures are `assets/ui/cursors/*.svg`, drawn by `Icons` at 1x, 1.5x or 2x by
  screen DPI on Windows and X11, 1x on a Mac (NSCursor takes pixels as points),
  and in a browser as CSS `image-set()` of a 32 and a 64 px PNG data URL, put
  on the canvas over Godot's own 1x `url(blob:)` style
  (`Cursors._crisp_on_the_web`), so a 2x screen is sharp. The page is told the
  state (`window.brickworksCursor`). `tools/web/cursor_check.mjs` reaches every
  row with the mouse and keys at 1x and 2x, identifies the picture the CSS
  carries by its pixels against the SVGs, and fails on brickworks.diy as of
  2026-10-11. Escape also throws away a box being drawn (its release is not a
  click) and closes the controls panel.
- `renders for the critique` (views: corner, far corner, front, back, left,
  right, top, and "face", straight down the right way up for a LEGO Art
  picture): the image handed to the assistant so it can see what
  it built, drawn by a SubViewport. Two opposite corners, so every side has been
  seen; a close look at one part of a model too big to judge whole; and, after an
  edit, the bricks that edit added or moved restaged in magenta, so the design can
  find its own change by looking rather than by re-reading coordinates. Framed
  on every staged part's corners and the ruler's ends, the camera slid to their
  middle (`ModelShot._staged_corners`; `centring_probe` checks the car, Orthanc
  and an L within 2%: an L framed on its box sat 3% high). The stage
  is a copy of the world — the model keeps the colours it was given. It is
  staged again only when the world's `revision`, what is left out or what is
  picked out changed (`ModelShot._restage`, a slice a frame by `FramePace`
  and drawn when whole), keeps no history, and is drawn
  once a try (`UPDATE_ONCE`), not every frame of six: reading a picture back
  waits for everything queued to be drawn, and on the owner's 4,242-part Falcon
  Heavy in a browser drawing in software that read was 45 s. The PNG and its
  base64 are made on a worker. `ModelShot.gpu_wait_us` sums the read-back wait,
  which `Main._watch_own_frames` reports apart from the app's own work. On
  the web the read waits for a WebGL fence first (`GpuFence`, put in a frame
  after the picture is drawn), asked once a frame without waiting, with the
  drawing held meanwhile (`RenderingServer.render_loop_enabled`): every frame
  drawn while it waited was the whole model again ahead of the read. On the
  Falcon in Chromium on SwiftShader (`freeze_check`, 2026-10-11) each read
  waited 16 to 33 s on the page's thread; now 8 to 25 ms, the longest task
  went from 17-33 s to 2-3.6 s and the slowest input from 17-33 s to 3.6 s,
  with the page running at 60 frames a second while the card drew it.
  Held for anything but the person: a key, a click or the pointer moving is
  drawn while it waits (`GpuFence._asked`, the root window's `window_input`),
  the frame it changed and whatever else changes in the 500 ms after it. The
  parts bin reads its pictures back the same way, eight at a time, and over
  Orthanc in software its first eight held the drawing 30 s and more after
  the model opened: a click on the white wizard selected him at once and the
  window went on showing the frame from before it, "nothing selected" and no
  outline (2026-10-14, `outline_check`, whose idle looks showed the
  selection never left).
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
  Timeline or a design's Build steps. Opening it works the steps out a slice
  at a time (`StepsBar.start` is a coroutine, `Instructions.plan_paced`) with
  the status bar saying which part of it and how far, and Cancel; Timeline
  pressed again, or an edit meanwhile, stops it. Orthanc's took one frame of
  6.3 s in a browser before (2026-10-12). A slider over every brick, from an empty
  baseplate to the finished model: drag it, Start/End (Home/End), Back/Next a
  step (arrows), Play and Reverse (space plays), at 0.5x-4x, the whole build
  taking 6-40 s at 1x. Three orders: Build order (`Instructions.plan`, the
  booklet's, numbered as the booklet numbers them — `Step.caption()`, "Step 12
  of 40 · Window (2x), 1 of 3": a callout's steps go up where the assembly
  will stand and carry the number of the step it goes on in; `booklet_probe`
  checks the timeline and the pages print the same numbers; what the step
  adds is a line of its own under the slider, and the buttons have faces),
  As made (brick numbers, the order what
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
  nothing placed before what holds it. A model wider than 24 studs, of 400
  parts or more (`TILED_FROM`; a smaller one was "Part 1", one step on a page
  of its own), is built a
  region at a time (`Instructions.REGION`): one tile of its plan finished before
  the next, borrowing only the bricks a region is directly waiting on, and the
  booklet starts each on a new page under a banner ("Part 2", or its name).
  On a 1,895-part castle the jump between consecutive steps went from a median
  of 12.5 studs (90th 38) to 6.2 (90th 12). `--booklet=PATH` with `--model=`
  writes the booklet and quits — about three minutes for that castle on the GPU.
  Sub-assemblies are built on the side, as a real booklet's callouts are: a
  minifigure (by its parts, `Minifig.is_figure`), and any sub-model the file
  places that is small (at most `ASSEMBLY_MOST`, 60 parts, and under 30% of
  the model) and one piece — a top-level one, or one nested a level inside a
  big one (`LdrModel.Placement.unit` keeps "House#1/Window#3", and the brick
  carries it as `Brick.unit`). Each stands in the main build as one node; its
  own steps (`Step.in_callout()`, up to `CALLOUT_PER_STEP`, a figure in one)
  come just before the step that puts it on (`Step.attaches()`, no bricks of
  its own, `copies` holding each copy). Copies of one kind (same name, parts
  and colours) ready together are built once, "2x" (`Step.times`; the picture
  shows `shown_ids`, the first copy). A callout's steps carry the number of
  the step it goes on in (`Step.number`; `Step.caption()` is what the timeline
  prints). A part with nothing under it (a tap on a side stud, a wheel) waits
  for what it touches (`_find_hangers`), outward from what is held a wave at a
  time, and one that touches nothing waits for the nearest part below it; a
  link that would make a loop (`_cycles`, the parts on a loop, not those
  downstream of one) is undone and relinked to a part that does not wait for
  it. On Orthanc, parts placed touching nothing already placed went from 193 to
  6 of 8,603, with no step forced. A pin that joins two parts goes into the
  lowest and the others go on it (`_find_joints`): waiting for both put it in
  last, buried between two beams. Wheels go on what holds them and tyres on
  their wheels (`_wheels`, by name: "Wheel …", "Tyre …"), whether or not the
  joint is known; a wheel holds nothing up, and goes in last within its
  region: the example car's booklet began with four wheels on the table. Steps take
  4 bricks under 150 parts, 6 under 500, else 8 (`_per_step`). Supports are
  found through a two-stud grid and the order through a set of ready bricks:
  the 8,603-part Orthanc planned in 87 s and now in 5.
- `score the steps against real sets' authors` (`tools/steps_score.py`,
  `src/dev/steps_score.gd`; the write-up is `docs/INSTRUCTIONS.md`): files of
  LDraw's model repository (vendor/omr) with their authors' `0 STEP` lines,
  chosen the same every run (`sample`: by a hash of the set number, a quarter
  from each of four sizes, themes taken in turn; `tune` and a disjoint `proof`
  of 100 each). Each is opened as File, Open opens it and built six ways: the
  author's steps (every sub-model built apart, as LDraw means them), the
  author's as the booklet draws them, `Instructions.plan` on the model with its
  steps taken away and its parts shuffled (with its sub-models, and without),
  file order and bottom up by height. Each part's step goes to a JSON line;
  `report` says Kendall's tau-b against the author, same-step pairs kept
  together, step counts and sizes, the author's sub-assemblies built on the
  side, and new things hidden from front and back, put in under a part already
  there, or floating at their step, each with a 95% interval from resampling
  the files; `compare BEFORE AFTER` pairs two runs file by file. "Held" is the
  probe's own graph (`Stability.contacts` and the joints the build check
  reads), not the planner's. Every run first checks the measures on models
  with known answers (a stack built from the top floats twice; a plate in a
  deep well is hidden) and scores nothing if one is wrong; the maths is pinned
  by `tests/test_steps_score.py` (scipy's own tau-b example, every pair
  against the definition).
- `the author's steps` (`src/assembly/author_steps.gd`, `AuthorSteps`): the
  steps a model's designer gave it in Studio, LDCad, LeoCAD or Bricksmith,
  kept and changed here. A file's `0 STEP` (and `0 ROTSTEP`) lines were read
  into `LdrModel.Placement.step` and dropped, and saving wrote the worked-out
  order over them, so a model opened and saved lost its booklet. Now each part
  keeps its step within its own sub-model (`BrickWorld.Brick.step`, -1 for
  none) and each sub-model copy the step it goes on in within the one that
  places it (`BrickWorld.unit_steps`, from `LdrModel.unit_steps`; a reference
  was always written first, so a window put on in step 9 came back in step 1).
  Sub-models one step places are built whole, one after another, in the order
  the file lists them (`AuthorSteps.key_of` with `first_under`): sorted by the
  step alone, 10230's five buildings went up a course of each in turn.
  `ModelStore.to_text` writes them, the autosave too, and the
  `0 !BRICKWORKS AUTHORED_STEPS` line under the model's header. A file
  Brickworks wrote with its own worked-out steps (`0 Author: Brickworks` and no
  such line: every shipped model, every save before this) is not the author's,
  and is worked out again (`LdrModel.steps_are_authored`), or a model saved
  yesterday would put a new tower in its last step. `Instructions.plan(...,
  authored=true)` groups by those steps (`_authored_plan`): a sub-model's own
  steps before the step that puts it on, a small one still a callout ("2x",
  found by unit as the worked-out plan finds one) whose put-on step also takes
  the parts of the author's step it is in; regions and the parts-a-step limit
  are ignored; parts with no step (added since, by hand or by a design) come
  after, worked out. The timeline's fourth order, **Author's steps**, is the
  default for such a model, and the booklet follows it. Edit, Build steps (and
  the timeline's row under its buttons): **Move to previous/next step**
  (`Shift-[`, `Shift-]`: the selection; from the last step makes a new one),
  **New step from selection** (`Shift-N`: after the step the timeline is on,
  everything later one on — how a step is split or put in), **Step
  earlier/later** (reorder), **Merge with the next step**, **Delete the step**
  (its parts join the step before; none is taken off). Each is one undo
  (`restep`/`unitstep` in `Builder._apply`, `AuthorSteps.squash`: an undo
  group is applied in the order kept, so a part renumbered after a move came
  back to its middle step). The first edit of a model with no steps copies the
  worked-out order in, in the same undo (`AuthorSteps.ensure`). A part put
  down, pasted or a figure placed while the timeline shows a step goes in it
  (`Builder.place_step`); moved, a part keeps its step; replaced or mirrored,
  the new part has the old one's. A design's own build keeps the worked-out
  order. Inside a sub-assembly (Enter) the edits are of its steps; Earlier,
  Later, Merge and Delete change every copy of it. `[`/`]` alone still change
  the colour in hand; the shell takes them only with Shift and a selection,
  `{`/`}` too, which is what a browser calls them. The menus cannot write `[`
  as a key and have no look-alike for it in their font, so those two lines
  say "Shift+[" in their words (`Shell.UNDRAWN`). While the timeline is up,
  the pointer passes through the parts it has not put on yet
  (`BrickLattice.ahead`, set on every reveal): a click on the step showing
  took the invisible part above it, and Shift-] moved that one;
  `handbuild_probe` clicks the yellow brick under the white one to come.
- `the booklet`: build instructions laid out as a LEGO booklet, one HTML
  file that prints on A4 and Letter (landscape; `Booklet.PAGE` is 269 x 199 mm,
  inside both) and reads on screen (`--mm` scales the same millimetres to the
  window). From the toolbar's **Instructions** (added after Timeline by
  `BookletMaker.add_button`, by its words, because `model_bar.gd` is someone
  else's at the moment), the timeline's Instructions, or `--booklet=OUT.html
  --model=M`. On the desktop it is written to Downloads and opened in the
  browser; on the web it is written into a tab opened as the button was pressed
  (`BookletMaker.open_tab`, then `fill_tab`; a page may only open a tab in
  answer to a click), or downloaded if the browser blocked the tab.
  While it works the status bar says which part of it and how far (`Working`,
  `BookletMaker.job`: planning, the parts, the views, the steps, counted, with
  Cancel, which closes the tab), and so does that tab, which is the one in
  front (`BookletMaker.tell_tab`). The plan is `Instructions.plan_paced`, and
  each picture is read back once the card has drawn it (`GpuFence`, in
  `BookletStudio._drawn`), as `ModelShot` reads: read sooner, in a browser
  drawing in software the car's booklet held the page about three seconds a
  picture (2026-10-12, `progress_check.mjs`).
  `BookletMaker` (`src/render/booklet_maker.gd`) plans, decides each step's
  view, lays out (`Booklet.lay_out`, `src/assembly/booklet.gd`) and draws;
  `BookletStudio` (`src/render/booklet_studio.gd`) draws off screen, never
  touching the person's view: the model alone, orthographic, from one fixed
  angle (`FRONT`), every part outlined in ink. The ink comes from a second
  pass where each brick is a flat colour that is its number
  (`booklet_codes.gdshader`) and a third that draws a line wherever the number
  changes (`booklet_ink.gdshader`), so the seam between two bricks of one
  colour is drawn, which is how a reader counts a wall. Bricks go on the
  stage in the order the plan builds them, so a step's picture is a prefix
  (`BrickWorld.show_first`). What a page has: a cover with the model, steps
  with a big number and a parts box above it (a picture of each part at one
  scale, `Booklet.PART_SCALE`, and its "2x"), one to four steps a page — the
  fullest page whose shared scale is still readable (`FOUR_UP` 6 mm a stud,
  `TWO_UP` 5), never more than `MOST_SCALE` (10 mm a stud) — and every step
  on a page at the same scale; a step whose new parts are hidden from the
  front (less than 40% of them in view, measured by drawing the codes again
  with only the new parts) drawn from the back with the turn sign, and turned
  back when the front shows 70%; a callout (cream box, sub-steps 1 2 3, "2x")
  with an arrow to each copy, projected through the step's own camera and
  drawn as print draws it, out of the box at a right angle and round one corner
  (`Booklet.elbow`), with a white edge so it shows on a black model, or, past
  three steps, pages of its own in a frame; a figure looked at in the face
  (`Minifig.frame_of`); the finished model front and back; then the parts by
  colour with counts and element numbers. A model too big to read whole (not
  fitting a page at 4 mm a stud) is framed on the part being built, the rest
  fading out at the picture's edges (`BookletStudio.fade`). New parts are not
  highlighted: modern booklets keep colours true and rely on the parts box and
  the ink line (the ink shader can ring them, `mark_new`, off). Pictures are
  5 px a millimetre, 4.2 past 300 steps and 3.6 past 1,000 (Orthanc's 1,405
  steps were 256 MB at 5); a step whose
  new parts are small and in one place (under 14 mm) gets a red arrow down
  onto them, as a booklet points at a flag on a tower. Inside a part a fainter
  line marks where the shading turns a corner (`crease`: stud rims, a top's
  edge), found from the lightness, within one brick. Black and the darkest
  greys are lifted towards charcoal, as print draws black so its faces can be
  told apart; coloured plastic is left alone (lifted too, a red's shaded side
  came out neon), and black stays well clear of dark bluish grey. Measured
  2026-10-11 on the GPU: house 71 pieces, 14 pages, 7 s and 1.6 MB; castle
  2,438 pieces, 364 pages, 2 min and 72 MB; Orthanc 8,603 pieces, 1,298 pages,
  6 min, 137 MB and a 105 MB PDF (LEGO's own PDFs run about 0.5 MB a page). In
  Chromium on SwiftShader the web build makes the example car's in 89 s.
- `mosaic` (Mosaic in the toolbar, then a picture; `src/ui/mosaic_dialog.gd`):
  a picture built two ways. **Brick Art**, the default, as a modern LEGO Art set
  builds one (`MosaicArt`, below); **Classic**, one 1 × 1 plate a pixel, flat,
  matched in Oklab with damped Floyd–Steinberg (`Mosaic`, unchanged). The
  dialog has the mode, panels across and down (down follows the picture's
  proportions until moved), Depth 0–6 plates (0 is flat), the element styles
  (Round texture, Contour quarters, Smooth tiles, Accent stars, Blend colours)
  and, live, the result drawn element by element (`MosaicArt.picture_of`) and
  what it comes to by element. Build it replaces the model, each panel its own
  sub-assembly ("Panel 1"…, the plates under them "Frame"), so the booklet
  builds a panel at a time and P lists the parts.
- `LEGO Art layout` (`src/assembly/mosaic_art.gd`): `analyse` reads a picture
  into a `Plan` — per stud a style, a relief and an accent flag — and `lay`
  turns any plan into parts, which is the entry point for the assistant
  composing one itself. Flat areas: in courses like brickwork, 2 × 4 tiles all
  running across, two rows a course, joints two studs along course to course,
  1 × 4 down to 1 × 1 by row where a course breaks (`_courses`; a greedy mix of
  sizes read as noise across a sky); texture:
  98138 round tiles; diagonal contours: 25269 quarter circles turned so the
  curve faces across the edge (only where what the cut corner shows is the far
  side's colour); stars: round tiles in trans-clear, glow or metallic a plate
  proud (round plates, stud proud, when flat), each alone on a calm sky: the
  glow round it is taken back to the sky's colour (`_calm`) rather than
  dithered into a cross of grey rounds; what stands out from the
  border's colour raised on merged plates with 54200 cheese slopes on the way
  down. Each element's colour only from colours that part is made in
  (`never_made_in`), matched with hue weighed 1.5 times lightness
  (`MosaicArt.gap`) after the picture's shadows are taken to LEGO Black
  (`black_point`): without them a night sky came out half Dark Brown and a
  star's halo Reddish Brown. 16 × 16 plates (91405) joined underneath by 2 × 4s across
  every seam and one under each outside edge, so the checker calls it one
  buildable piece. `mosaic_probe` proves it on a synthetic galaxy (stars as
  accent round tiles a plate proud with no halo, the sky's tiles all one way,
  the core raised to the depth, quarter
  circles on the arms' edges, one piece, nine pieces without the frame, the
  parts list part for part, the booklet nine panels) and a flat red picture
  (2 × 4 tiles in staggered courses, under a third the classic count), the switches (depth 0 flat,
  styles off unused), the turn tables against the meshes, and that the classic
  mosaic lays the probe's gradient exactly as it did. Renders of the galaxy:
  `shots/art/`.
- `LEGO Art plans` (`src/assembly/art_plan.gd`): what a LEGO Art designer
  decides, as a small JSON plan the engine keeps to (`MosaicArt.Guide`):
  panels and crop; regions over the picture (`everything`, a polygon, an
  ellipse whose radii are fractions of the width so a circle is round, or a
  rect), each changing only what it says — texture (round, smooth, or as the
  picture reads), relief in plates, whether contours run there, whether its
  points of light are stars and in what finish, or one colour for all of it;
  single stars put by hand (`points`, 1 x 1 round tiles, or with `size` 2 a
  14769 2 x 2 round tile on four studs for the brightest, the three it covers
  `Style.COVERED`); a palette; the panels' colour; and an
  SVG drawn by Claude when there is no picture (`Image.load_svg_from_string`,
  eight pixels a stud, over the panels' colour so a drawing with no
  background is no holes). Coordinates are fractions of the picture after
  the crop, 0 to 1 from the top left, so a plan survives the panel count
  changing. Wherever it says nothing the engine reads the picture as before,
  and `MosaicArt.make` is unchanged as the default. `ArtPlan.parse` is the
  edge: every field checked, every fault named at once ("regions[0].relief is
  9; it must be from 0 to 6", "\"height\" is not something a region says"),
  unknown keys refused rather than ignored. `ArtPlan.schemas()` is the tool
  definition, beside the reader, and the probe holds the two to the same
  fields.
- `LEGO Art designed by Claude`: two tools in the assistant's list, so the
  in-app loop, Claude Code on the person's plan (My Claude) and a session
  over MCP or the connector all have them: `make_art` (a plan in, laid in
  place of the model as the dialog's Build does, answered with the picture
  face on and its parts by element, so the designer can look and plan again)
  — then a look-and-revise pass, as the 3D designer's critique: the answer is
  the picture face on (rendered where there is a renderer, from the
  `ModelShot` view "face": straight down, the picture's top edge at the top
  — "top" shows a picture laid flat turned half round, and the first rerun
  was shown it upside down — else `MosaicArt.picture_of`),
  `ArtPlan.measured` (how much of the frame the raised subject spans — not
  "what is not plain", which a dithered sky made 100% every time — and how
  much is plain background, the colours on the face,
  the largest one-colour patch outside the background, the stars by size and
  finish, the relief and whether the edge is flat), `ArtPlan.CRITIQUE` (fills
  the frame? soft gradients over three or four related colours? stars of varied
  size and brightness? a harmonious palette? subject raised, background
  flat?), `ArtPlan.REFERENCE` (what makes 31212 work: the galaxy edge to
  edge, arms as soft tonal gradients of blues and whites, a warm raised core,
  a sky dense with small stars of varied size; also in the rules), and
  `ArtPlan.next_step`: revise once, twice at most, then stop. Laid again under
  the same name is a revision; another name is a first look —
  and `look_at_picture` (the person's picture — the one chosen for the mosaic,
  or the first reference — for a session that is given a sentence, not the
  picture). The rules say a picture to hang up is make_art, not
  submit_design. In the mosaic dialog, under the Art switches, a brief field
  and **Design with Claude**: the dialog closes, the assistant column opens and
  the chat panel sends `MosaicDialog.art_brief` ("Make the picture I chose
  into Brick Art with make_art: look_at_picture first…" and what was
  typed) as if typed (`ChatPanel.ask`), so it runs on the person's key or
  their own Claude exactly as a design does, and with neither says what is
  needed. However it is laid, `main._art_laid` frames it, checks it on a
  worker and says "one piece" in the status line, and publishes
  `brickworksState.art` (parts, panels, pieces, ok).
- `photo-real render` (File, Render…, and the toolbar's camera;
  `src/ui/render_dialog.gd`): a picture or a turntable of the model worth
  keeping, Studio's Eyesight and Mecabricks' Workshop being the bar. The panel's
  picture is a Quick draft drawn again a moment after any choice changes, so
  the framing, backdrop, light and lens are seen before Render is pressed.
  Choices: Quick, Good or Best; 720p, 1080p, 4K, a square or a custom size;
  a white, grey, black or coloured sweep, or none (transparent, the contact
  shadow kept as a shadow on nothing); the window's three lights or one of
  three Poly Haven HDRIs (`assets/hdri/`, CC0, docs/ATTRIBUTION.md), turned
  round by "Light from"; the contact shadow; the view looked at or six
  presets; a full-frame focal length; f-stop and focus (Best); Best's frames;
  a turntable's 24-72 frames. Done, a picture downloads (browser) or is
  written to Downloads (desktop, "Show in folder"); a turntable is an
  animated WebP (`src/render/animated_webp.gd`, stills from
  `save_webp_to_buffer` put in the animated container by hand), and on the
  desktop also its frames as PNGs and, where `ffmpeg` is found
  (`RenderOutput.ffmpeg`, PATH and the Homebrew and usual places), an MP4.
  Cancel or Escape stops it. The page publishes `window.brickworksRender`
  (state, progress, what was downloaded, and the render's longest frame and
  what it was doing then, `StudioRender.worst_step`) for a browser check.
  While it is open a veil covers the window and the window's own model is
  not drawn (`disable_3d`, put back as Main would have it on Close).
- `studio renderer` (`src/render/studio_render.gd`): off screen, in its own
  viewports with a copy of the model staged a slice a frame (`FramePace`): the
  model alone on the sweep, its floor's baseplate left out unless it is part of
  the model (`ModelFloor`), as Studio's and LEGO's own renders have it.
  The set: a sweep (`studio_backdrop.gdshader`, a floor curving into a wall,
  turned to face the camera), the contact shadow (`studio_contact.gdshader`:
  three silhouettes of the model seen from under the floor, within 6, 30 and
  110 LDU of it, blurred in proportion and stacked), and the window's own
  Sun, Fill and Rim turned with the camera, so a render from the starting
  view is lit exactly as the window is. Quick is one frame of that. Good on
  Forward+ adds SDFGI (energy 0.15, the key x1.4, 64 frames to settle), SSAO
  and a PCSS key, six frames averaged with the key moved a little, at the
  engine's finest occlusion and soft-shadow filters for the render (one frame
  of a soft shadow is noise, and at 4K it was a grid of dots on every face);
  in a browser it is 8 frames averaged under a key moved across its area. Best averages 64 frames on the desktop and 32 in a
  browser: each jittered under the pixel (R2 sequence, a Gaussian 0.42 px
  wide), the key moved across a 7 degree area, the lens across its aperture
  (a real f-number on a real-sized model: an LDU is 0.4 mm) with the focus
  plane held, and in a browser 60% of the ambient moved into a shadowed light
  from another point of the sky each frame, which is what puts occlusion
  under a ledge where there is no SSAO (`_light_sample`). The frames are
  summed in two float buffers taking turns (`studio_sum.gdshader`) as
  differences from the first (`studio_copy`), then dithered back to 8 bits
  (`studio_resolve`); the viewports are nested so the engine draws them in
  order. Exposure is metered (`_meter`): the model's mean lightness in a
  120-pixel picture of the bricks alone, against the same shot in the window's
  light, so every light and grade comes out as light as the window draws the
  model; and the sweep is metered to its colour (`_meter_floor`, `level`).
  A picture bigger than one draw (1920 x 1088 in a browser, 4096 a side on
  the desktop) is drawn in pieces with a frustum offset each, and wider than
  it needs where SSAO looks past the edge. HDRIs: `studio_panorama.gd`
  finds the brightest light (the key), its share, the average colour and a
  table for picking directions by their light (Best's sky samples).
  Kept between pictures: the staged copy (until the model changes), the
  contact shadow (drawn once per model, in no light), one environment per
  way of lighting, the sweep's mesh and the shadow atlas's size. A
  turntable's frames are encoded on workers while the next is drawn
  (`RenderOutput.add_frame`, at most three waiting). `StudioRender.animate`
  draws an animation the same way: before each frame it moves the staged
  copies of what moves (`_staged_ids`, world id -> stage id) and turns the
  pivot, frames the box they all sweep (`_reach`), and leaves the stage to be
  copied again next time — the model itself is never touched.
- `pose and animate` (Build, Pose and animate…; `src/ui/pose_panel.gd`, a
  panel over the model's left edge so the pose is seen as it is set): a
  slider per joint — every sub-assembly with a shaft of one of its parts in a
  bore of a part outside it (`Builder._joint_of`, as J finds one), a hinge or a
  turntable — from -180° to 180° about where it stood when posing began. A
  laid hose, tube, string or chain is never one (`Flex.kind_of`): its end pin
  in a hole read as a hinge, and swung, the tube tore off its other hole.
  Dragging moves it live (`Poser.stand`, nothing to undo); letting go, or a
  click on the track, keeps it as one step ("posed Arm at 45°"), as far as it
  has room, pressing only on what it is joined to (`Poser.settle`, a bisection
  between where it was and where it was asked; the panel says where it
  stopped). A joint inside another turns about its rest axis first and the
  outer carries it (`Poser.transforms_for`). After an undo the angles are read
  back off the parts (`Poser.read_back`), or found afresh if the model changed.
  At rest sets every joint to 0. Key at / Add key keeps every angle at a time;
  `PoseAnimation` runs each joint through its keys as a monotone cubic
  (Fritsch–Carlson): exact at each key, eased at the ends, never past a key.
  Play runs it in the window; Turn the model round once adds a turntable;
  Render animation draws it Quick at 480 × 300 or 720p, 12 or 24 a second,
  without a contact shadow (drawn once, it would be the rest pose's), with the
  frame drawn last shown in the panel. A browser downloads
  `<model>_animation.webp`; the desktop writes the frames, the WebP and, with
  ffmpeg, an MP4 to Downloads. `window.brickworksPose` says the joints with
  each slider's ends on the page, the keys, and the render's progress and file.
  (`RenderOutput.add_frame`, at most three waiting). Under Compatibility
  every 3D draw of the set first draws, alone and one a frame, each thing in
  it that view has not drawn in that set-up (`_warm`: a batch per shader and
  mesh format, the sweep, the contact shadow; on a layer of its own that the
  lights are put on too), the card left to finish each (`GpuFence`) before
  the next; and every picture is read back only once the card has finished
  it (`_read`), so a read-back no longer holds the page while it rasterises.
- `render open check` (`tools/web/render_open_check.mjs`): the Render
  dialog's first open in a fresh browser, from the toolbar, every frame from
  the press to the first draft timed in the page (the engine's frame
  callback, WebGL included, with the programs it linked counted apart), then
  a second open beside it. Fails past `--budget` ms (250) for a frame of the
  first open, on no draft, or on a script error.

## How to reach it

```sh
godot --path .             # right-drag turns, scroll zooms, F frames, O squares on,
                           # middle-drag slides or turns (a preference), , lists every key
godot --path . -- --shot=/tmp/model.png --model=models/car.ldr   # one render, then quit
godot --path . -- --booklet=/tmp/b.html --model=models/station.ldr  # the booklet, then quit
#   on the GPU: ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . -- --booklet=…
node tools/web/booklet_print.mjs /tmp/b.html /tmp/b   # print it: a4.pdf, letter.pdf, page-N.png
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
#   covers the Technic ordering case via models/kart.ldr, a shed whose two
#   windows are one sub-model placed twice (a "2x" callout) and a figure, and
#   31009 Skaters House from vendor/omr when it is there
godot --headless --path . --script src/dev/steps_score.gd -- --selftest  # the steps score's measures give known answers
python3 tools/minitest.py tests/test_steps_score.py                # ...and its maths (tau-b, intervals, samples)
python3 tools/steps_score.py run --which proof --out build/steps_score/proof   # ~10 min under heavy, then
python3 tools/steps_score.py report --out build/steps_score/proof  # the table docs/INSTRUCTIONS.md quotes
godot --headless --path . --script src/dev/playback_probe.gd      # the build animation: right bricks, in order, cheap
# nothing drawn standing still, every change drawn (on Xvfb: it moves the pointer)
MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1400x900x24" \
  godot --path . --resolution 1280x860 --script src/dev/idle_probe.gd
#   ...on the house; and on a big model, where a few frames for nothing are seconds
MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1400x900x24" \
  godot --path . --resolution 1280x860 --script src/dev/idle_probe.gd -- --model=res://models/castle.ldr
#   at the browser checks' size: at 1400x900 the bin's clipped-off shimmer was
#   off the window and drew nothing, at 1280x860 it drew every frame
#   on the GPU, for the card's time a frame: ~/.claude/claude-core/bin/gpu before it;
#   `-- --every-frame` runs it drawing every frame, as the app did
godot --headless --path . --script src/dev/mosaic_probe.gd        # the picture still looks like the picture, classic and Art
#   -- --ldr=shots/art/galaxy.ldr writes the galaxy, to render corner, front and close
godot --headless --path . --script src/dev/art_plan_probe.gd      # an Art plan is laid as it says; a bad one is refused
#   no network: a canned plan over a tilted galaxy (sky smooth and flat, disc
#   round and one up, core three up, three stars by hand in glow, trans-clear
#   and pearl gold) checked stud by stud against what was laid, the palette,
#   made-in colours, one piece, the parts list; a plan that draws its own
#   SVG; two 2 x 2 round stars, each the top of its four studs and one piece;
#   17 malformed plans each refused with its fault named; make_art and
#   look_at_picture called as a design calls them (a bad plan leaves the
#   baseplate alone, a good one replaces it, panels as sub-assemblies, the
#   answer the picture plus what was measured and the checklist, laid again
#   under the same name revision 1 then revision 2 and told to stop); and
#   the dialog's Design with Claude. Ends "an Art plan is laid as it says".
# In a browser, on a local web export (tools/export.sh web, then
# python3 tools/web/serve.py build/web PORT): Build > Mosaic from a picture
# (typed, then Enter), a galaxy PNG it makes into the chooser, Build it, and
# brickworksState.art read for its parts, every one on the baseplate, one
# piece, Panel N#1 and Frame#1 in the tree; then a brief typed into the
# dialog, which must take it (the tool still Select, not Orbit from its O),
# and Design with Claude, which must close the dialog, open the assistant
# and, with no key, say so.
node tools/web/art_flow.mjs --url=http://127.0.0.1:PORT/index.html --out=shots/art_web
godot --path . --resolution 1200x800 --script src/dev/shot_probe.gd   # the render is of the model
godot --path . --resolution 1200x800 --script src/dev/booklet_probe.gd  # the booklet reads like one
#   every step pictured and framed on the model, new parts in frame, a parts box
#   with a picture of every part, the shed's 2x callout with two arrows and its
#   figure, the turn sign behind a wall, the timeline's numbers = the booklet's,
#   and the app's own toolbar: Instructions after Timeline, pressed, writes
#   the booklet to Downloads (BookletMaker.open_when_written off, no browser);
#   the gatehouse (tests/fixtures/steps/gatehouse.mpd) in its author's steps:
#   pages numbered 1-6, each parts box what the author put in, the window a
#   3-step 2x callout;
#   leaves shots/booklet/{shed,house,turned,gatehouse}.html — print and look at them
# The author's steps: gatehouse.mpd and gatehouse_2025.io opened, saved (and
# the autosave), out to .io and opened again, every sub-model's steps as the
# author made them and the timeline the same; a part moved a step, saved,
# reopened, and undone. Ends "...an author's steps survive open, edit and save".
godot --headless --path . --script src/dev/io_probe.gd
# ...and changed by hand: B, Next, Shift-] / Shift-[ / Ctrl-Z, Edit > Build
# steps > New step from selection, the timeline's Back, Merge with next,
# Earlier, Delete step, a copy pasted into the step showing, and ] alone still
# a colour. Every check passed is the pass.
godot --path . --resolution 1400x900 --script src/dev/handbuild_probe.gd -- only=author_steps
# In a browser, on a local web export (tools/export.sh web, then
# python3 tools/web/serve.py build/web PORT, .env sourced): the gatehouse
# through Open > From a file, Timeline in Author's steps "Step 1 of 6", Next
# twice, a click on the yellow brick (brickworksLayout.targets now name the
# part), Shift-] -> "Step 3 of 5", Ctrl-Z -> "of 6", again, and File > Export
# > LDraw model read by Python: four steps, the yellow with the blue.
node tools/web/steps_flow.mjs --url=http://127.0.0.1:PORT/index.html --out=shots/steps_web
# In a browser, on a local web export (tools/export.sh web, then
# python3 tools/web/serve.py build/web PORT): presses Instructions, follows
# the tab it opens, checks the booklet in it and prints it to booklet.pdf
node tools/web/booklet_flow.mjs --url=http://127.0.0.1:PORT/index.html --out=shots/booklet_web
BW_BYPASS=$VERCEL_BYPASS node tools/web/booklet_flow.mjs --url=<preview>/app --out=shots/booklet_web   # the app's security policy: only a deployment sends it
godot --path . --resolution 1200x800 --script src/dev/gizmo_probe.gd  # the corner says which way you face
godot --path . --resolution 1400x900 --script src/dev/colour_probe.gd # picking a colour recolours something
xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/see_inside_probe.gd
#   the cut-away and x-ray: a closed room with a red brick inside, K and the
#   strip's slider dragged, X, Flip, Ghost; I with the brick selected and
#   inside a sub-assembly; clicks reaching it through both; the timeline with
#   both on; the booklet made with both on = made with both off; Orthanc timed.
#   Leaves shots/see_inside/*.png — look at the cut faces and the ghosts
# In a browser, on a preview (with .env sourced): an .lxf through Open > From
# a file, Orthanc cut from the toolbar and its slider clicked to just over
# Saruman's head, a double-click on him through the cut, I, K off, and a click
# on him through the ghosts. Pictures in shots/see_inside_web/.
node tools/web/see_inside_flow.mjs --url=<preview>/app --bypass=$VERCEL_BYPASS
godot --path . --resolution 1400x900 --script src/dev/finish_probe.gd # every finish drawn as itself
godot --path . --resolution 1400x900 --script src/dev/true_colour_probe.gd # black is black, greys are grey
godot --path . --resolution 1200x800 --script src/dev/highlight_probe.gd   # a glossy slope does not go white
# the same three on Forward+ and the GPU (the plain godot is Compatibility, in software):
~/.claude/claude-core/bin/gpu godot --path . --resolution 1400x900 --script src/dev/finish_probe.gd
# File, Render…: every grade the size asked, the model in it, the sweep white,
# a soft key shadow (measured by drawing it again without), the model as light
# and coloured as Quick, each HDRI as light as the three lights, transparent
# keeps the contact shadow, a 6-frame turntable as an animated WebP, Cancel,
# and the dialog through the menu writing a PNG, 24 frames, a WebP and an MP4.
# Both renderers: Good and Best are made differently on each.
godot --path . --resolution 1280x800 --script src/dev/render_probe.gd
MESA_VK_WSI_DEBUG=sw ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1280x800 --script src/dev/render_probe.gd
# one model at one setting, for looking at:
~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1280x800 \
    --script src/dev/render_probe.gd -- --model=models/castle.ldr --quality=best \
    --size=1920x1080 --view=hero --lighting=studio --picture=shots/render/castle_best.png
# In a browser (SwiftShader), on a preview deploy, with .env sourced: the
# toolbar's Render, a draft, Quick 1080p and Good 720p downloaded, a 24-frame
# turntable downloaded and decoded, Best cancelled, and the page never waiting
# more than --stall seconds
node tools/web/render_flow.mjs --url=<preview>/app --bypass=$VERCEL_BYPASS --out=shots/render_web
# Build, Pose and animate…: a crane's turret and arm on their sliders, a
# click on the track, refused past what it has room for, undone and read
# back; three keys whose frames, read off the renderer's own copy, turn each
# joint through its keys; Render animation's frames, WebP and MP4
MESA_VK_WSI_DEBUG=sw ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/pose_probe.gd
# The first open of Render in a fresh browser, every frame timed (the engine's
# frame callback, WebGL calls in it, the programs it linked): fails past
# --budget ms (250) for any frame from the press to the draft; prints a
# second open beside it. --programs lists each program linked, by its
# #defines, and the frame it was linked in. A local export, served by it:
node tools/web/render_open_check.mjs --dir=build/web --out=shots/render_open
```

Proves it when: each exits 0 with no `FAIL`. `shot`, `gizmo` and `colour` also
leave an image — look at it; that is the point of them. So does `cursor`:
`shots/cursors/cursor_sheet.png` (every cursor at 1x and 2x on dark and light,
hotspot in red), `help_dialog.png` and `strip.png`. In a browser,
`node tools/web/cursor_check.mjs --url=<preview>/app` (`.env` sourced; a
`*.vercel.app` URL takes `VERCEL_BYPASS`; `--scales=1,2` by default,
`--no-wheel` skips the slow wheel-over-panels half) reaches every row of the
`pointer cursors` table with the mouse and keys, reads the canvas's computed
CSS cursor, names the picture by its pixels against the SVGs, checks its 1x and
2x decode to 32 and 64 px, and leaves `shots/cursors/web_<context>_<n>x.png`
with the computed cursor drawn where the pointer is (Playwright's screenshots
do not draw the pointer), `web_pictures_<n>x.png` (the pictures as the browser
decoded them from the CSS) and `cursors_<n>x.json`. (The wheel half
measures the view where the model is as each wheel turns: on a laptop,
opening the bin moves the model over, a region taken from before took in the
bin, and its list scrolling failed the check at 1x and 2x, 2026-10-12.) So do `finish`
(`shots/finishes_<renderer>.png`, a row of one real colour per finish, and
`finishes_shot_<renderer>.png`, the same in the critique render) and
`true colour` (`shots/true_colour_<renderer>.png`, with the sampled boxes drawn). `shot` also times a
picture: under two seconds with vsync on, against the six seconds it used to
take, which is what made a design run give up on looking at itself.

## Gotchas

- **The first real LEGO Art run (2026-10-12), judged against 31212.** "a LEGO
  Art picture of the Milky Way galaxy", from the sentence alone, by Claude Code
  on the owner's plan (`--ask-claude-code`, Opus 5.5, 45 s, nothing billed):
  look_at_picture (none), then a plan with its own 64 x 32 SVG — a tilted
  spiral, two arms, a bulge and a core — regions for space (relief 0), arms
  (round, 1 up, trans-clear stars), bulge (round, 2) and core (smooth, 3), 14
  stars by hand. The validator refused it once, rightly by its rules:
  `palette[2] 85` (Medium Lilac, for the violet between the arms) was not an
  Art colour. Claude fixed it in one call by taking Magenta, and 2,070 parts
  on 4 x 2 panels landed in one piece. It reads at once as a spiral galaxy:
  a raised glowing core with cheese slopes up to it, round-tile arms, a calm
  black sky in courses, stars few and bright. Against 31212 it falls short:
  half the size (51 x 26 cm against about 80 x 40), two thick arms with hard
  edges where the set has many wispy ones, a near-empty sky, and Magenta
  dust lanes that read as a toy, not as a galaxy. Medium Lilac is now an Art
  colour (`MosaicArt.SOLID`); the same plan replayed offline with it lays the
  violet Claude drew (`shots/runs/artai_replay_after_1.png` against
  `artai_replay_before_2.png`). Claude looked at the face-on answer once and
  did not plan again; a second look is where the wispy arms would come from.
  The plans are in the session's transcript under `~/.claude/projects/` for
  the worktree, which is how to see what a run asked for.
- **With the look-and-revise pass, the same prompt again (2026-10-12).** Two
  reruns, 96 s and 113 s, each looked once and revised once, as told. The
  second, on the final code (upright face view): 6 x 3 panels (77 x 38 cm,
  31212's size), the drawing in SVG gradients, arms dark blue to white with
  soft dithered edges, a warm orange-to-white core three plates up, no
  Magenta, 43 stars of which 3 are 2 x 2 round tiles; 5,018 parts against
  2,070, buildable in one piece (checked again offline from the transcript's
  plan). Its measure said the raised subject spans 90% by 92% and the plain
  sky is 18%. Still short of 31212: two regular arms in an even ellipse where
  the set's are many and ragged, and the sky's 43 stars are fewer than the
  set's. Between its two plans it asked for Dark Azure (321) and was refused,
  as Medium Lilac was before; the modern colours the classic palette predates
  are now Art colours (`MosaicArt.SOLID`). Renders:
  `shots/runs/artai_milkyway_face.png` (before) and `artai_milkyway3_face.png`.
- **A viewport is cleared every time it is drawn, whatever its clear mode.**
  Best's frames were to be added into one viewport set to `CLEAR_MODE_NEVER`;
  after 64 frames it held the last frame's 1/64th, on both renderers. So two
  buffers take turns, each adding the frame to what the other holds, nested so
  the engine draws the scene, the copy and the sums in that order (a viewport
  inside another is drawn first).
- **Forward+'s float 2D buffers are half floats.** 64 sixty-fourths of a
  grey added up came out 0.502 where 0.51 was right, two steps of an 8-bit
  picture. The sums hold each frame's difference from the first, which is
  mostly nothing and adds up exactly; Compatibility's are 32-bit.
- **The sweep showed its back.** Drawn counter-clockwise from above, the
  floor was a back face; with culling off the engine turned its normal down
  and no light fell on it, so no shadow did either, and the probe's shadow
  check passed on the model's own shadows. Godot's front is clockwise.
- **Under Compatibility a light whose shadow-casters are all out of the
  picture is not drawn.** The sweep metered on its own came out without the
  key, a grey the metering "corrected" to a clipped white, and the key's
  shadow vanished from every render. The model is drawn and masked out.
- **Compatibility lights a sky in sRGB.** An HDRI's ambient tint came out
  several times too strong (a grey plate orange under the window's warm room)
  and its reflection laid a grey veil over every face once the exposure was
  metered up. In a browser an HDRI gives the light its direction, colour and
  shadows; the window's own sky stays what the plastic reflects.
- **In a browser drawing in software, every picture read back waited for the
  window's own frame.** SwiftShader in Chromium finishes everything queued
  before it hands a picture back, the window's model included, and a frame of
  that is seconds there (turning the view alone held the page 2.7-4.6 s). The
  render's slowest frames were each draft's first read-back, 8-13 s, until the
  window stopped drawing its model behind the panel. What was made new for
  every picture cost the same way and is kept now (above). Measured with
  `render_flow.mjs`, which prints each render's longest frame and what it
  was doing. On the preview of a3fc635 (2026-10-12, SwiftShader): the app
  turning its view 3.2 s; every draft and render after the first open at
  most 1.7 s; the first open 9.0 s; a 1080p Quick 3 s, a 720p Good 5 s, a
  24-frame 720p turntable 29 s.
- **The first open built eighteen shader programs in four frames.** Under
  Compatibility a shader is built for each way it is drawn, in the frame
  that first draws it so, and the set draws the bricks' shaders in ways the
  window never does (the key's orthogonal shadow pass, no light at all for
  the contact shadow's silhouettes) and has two shaders of its own (sweep,
  contact shadow). In SwiftShader each program is 10-100 ms of the page
  waiting, and every read-back in those frames waited for the card to
  compile and draw too: one frame held 11 programs and a read-back, about
  1 s (`render_open_check.mjs` on a local export; 9 s on a preview). Now
  `StudioRender._warm` draws each new thing alone, a frame each, before
  the draw that needs it, and `_read` waits on a fence before reading back:
  the longest frame of the first open 950-1,120 ms before, 115-237 ms after
  (2026-10-12, at loads of 14 to 60 on this box), the same 18 programs, at
  most 6 in a frame (the sweep: a new shader is built for all four of its
  draws at once, plus the ways it is drawn), and a second open's longest
  frame 220-300 ms before, 40-60 ms after. The first draft comes about 1.5 s
  later (5.5 s against 3.8 s), the dialog answering throughout. Two
  surprises on the way: a camera sees only the lights on layers it draws,
  so a thing drawn alone on a layer of its own was built for a set with no
  lights until the lights were put on that layer too; and a light's shadow
  takes in everything on its own cull mask whatever the camera sees, so the
  lights light and shadow the one thing while it is warmed.
- **A render's steps must make the engine draw.** The app may draw only
  what changed (IdleDraw's low-processor mode), and each step waits for the
  frame count to move; setting a viewport to `UPDATE_ONCE` is a change, a
  step that changes nothing would wait for ever. `StudioRender._quicken`
  turns low-processor mode off for the render and puts back what was there.
  On the web an assistant picture's read-back (`GpuFence`) stops drawing
  outright for up to 120 s, and a render overlapping one pauses until then.
- **Global illumination off a white sweep lights the model like a second
  sun.** At full strength the model came out half as light again as the
  window draws it, its reds pink; the key's floor shadow filled in. Hence the
  metering and `GI_ENERGY`/`GI_KEY`, and the probe's lightness and colour
  checks against Quick.

- **Under Compatibility a dark value written by a shader does not come back.**
  What the booklet's code pass writes is stored in eight bits of linear light
  and read back as sRGB: 4 came back as 0 or 6, 12 as 16, 20 as 25, and every
  value from about 60 up exactly. So the codes go out as levels from 64 up
  (`booklet_codes.gdshader`), and the tokens that prove a picture is fresh are
  light colours. The same pass under Forward+ is converted on the way out, so
  the shader writes the linear value there.
- **A booklet's pictures are JPEGs on the page colour.** WebP keeps alpha
  losslessly, and the castle's booklet was 96 MB with it; flattened, WebP
  made it 60 MB, but Chromium printing to PDF re-encodes anything but a JPEG
  without loss, and that PDF was 360 MB. As JPEGs the PDF is about the size
  of the page. Parts keep their alpha, in WebP: they sit on the parts box.
- **The corner of every picture carries the tokens** that prove it was drawn
  for the state asked for (`BookletStudio._drawn`). The ink shader once ringed
  them as if they were a brick, a dot at the corner of every part in every
  parts box; the corner is blanked now.
- **Reading a picture's pixels in GDScript is the slow part.** A walk over
  every pixel of a page-sized code image was 1.5 s a step and most of the
  castle's ten minutes; it is read at a sixth of its size now.
- **The build animation froze the page on a big model.** The owner asked the web
  app for a Falcon Heavy (4,242 parts) and it "damn near froze my computer".
  Measured on that model on the desktop GPU: every submit and every edit replayed
  the whole model; planning the booklet's order took 15.5 s in one frame; each
  step called `show_only`, which walked every brick and flushed at once, and
  every flush emitted `rebuilt`, where `Main` asked whether the model stands —
  4.4 s a time, about once a step. 848 steps of that is most of an hour, and in
  a browser the tab stopped answering the connector ("The Brickworks tab did not
  answer in time"). Now only new bricks play, a step is a count, the stability
  line is worked out only when `BrickWorld.revision` moved, and
  `Stability._check_levels` is one pass up and one down (3.3 s to 0.1 s on that
  model). `tools/web/freeze_check.mjs` times the same design in a browser.
- **The model came up long after Claude said it was done.** The owner designs
  from claude.ai with the Brickworks tab out of view. The connector keeps the
  app running there, and it went on drawing every frame for nobody, then
  played the whole build animation for nobody. Measured on the build before
  2026-10-11 (`arrival_check.mjs`, SwiftShader):
  - 300 parts: drawn 26 s after being looked at, 20 to 23 frames in;
  - 2,000 parts: not drawn after 10 minutes, at 7 to 10 s of the app's own
    work a frame;
  - 4,242 parts: not drawn after 10 minutes, at up to 60 s a frame, and the
    submit itself went unanswered.

  Now every one of them is drawn in the first frame in view, in view or
  out, on under 30 ms of the app's own work.

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
  window never showed is the bug. Run headless it stops at once with one
  failure that says so: before that it ran on and failed 107 checks, which an
  integrator read as a broken merge (2026-10-12). The suite's way is Xvfb at
  1400 x 900 (`tools/check.sh`), 231 checks.
- **A slide moves the model under a still pointer by however far the warped
  system pointer and the probe's events add up to**, which varies with the
  machine's load. After Space-drag the probe once expected "select" at the
  middle and found the middle on a part's edge, two failures in three runs on a
  loaded box. It now goes back over a part (`_part_point`) before letting go
  of Space.
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
- **Only what writes to the RenderingServer is drawn.** In low-processor
  mode (`IdleDraw`) a change made any other way is not on screen until
  something else draws: there is none in the app today, but a value written
  every frame "to be safe" is a frame drawn every frame, and
  `RenderingServer.frame_post_draw` awaited with nothing changing waits until
  something does. Set what changed, when it changed. `idle_probe` names the
  node whose processing draws frames for nothing. Nor may a shader reading
  `TIME` sit anywhere on the window: Godot culls a canvas item only once it
  is off the window, not when a scrolled parent clips it, and the bin's
  waiting tiles below its fold drew every frame at 1280 x 860
  (`ThumbTile.in_sight`, 2026-10-11).
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
