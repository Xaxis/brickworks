# View

Looking at the model: the camera, what the keys do, the booklet, mosaics, and the
picture the assistant is shown.

<!-- covers: ui:navigation presets, ui:left-button navigation, ui:view cube, ui:split view, ui:camera controls, ui:controls panel and hint, ui:keys of one's own, ui:pointer cursors, lib:renders for the critique, lib:studs written on the render, ui:build steps, cli:score the steps against real sets' authors, cli:the same plans from two checkouts, ui:the author's steps, cli:the author's steps in a browser, ui:the booklet, ui:the booklet as a PDF and as PNG pages, ui:the booklet by hand, ui:the booklet page by hand, cli:the booklet by hand in a browser, ui:mosaic, lib:LEGO Art layout, lib:LEGO Art plans, ui:LEGO Art designed by Claude, cli:LEGO Art in a browser, lib:finishes, lib:true colour, ui:build animation, ui:cut-away, ui:x-ray, ui:stress view, cli:technic stress probe, cli:see inside in a browser, ui:drawing only what changed, ui:photo-real render, lib:studio renderer, lib:product look, cli:product look in a browser, ui:motions panel, lib:posing joints, lib:keyframed animation, cli:animation probe, cli:animation walk, lib:motions, lib:playing motions, cli:motions probe, cli:motions panel probe, cli:motions render probe, cli:render open check, cli:typing probe, cli:cad task frames, cli:cad task frames in a browser, cli:big models stay fast, lib:quitting cleanly, cli:quit probe, ui:a lighter look where frames are slow -->

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
  are docked in the right-hand column ([building](building.md)'s `docked
  panels`), and `Main.model_cover()` leaves out the points under the cube and
  nothing else. It turns with the view; a click on a face looks from that side, on
  an edge or corner from between two or three (`CadCamera.look_from`); a drag
  on it turns the view. Its four arrows turn a step a click (held, they keep
  turning; dragged, they follow), and under it a pad slides (click an arrow
  of it, or drag), − and + zoom, and the last fits. A click is quick by what
  the frames saw (`NavButton._hold`, `src/ui/press_hold.gd`: from the first
  frame after the one that handled the press): one across a slow frame is a
  click, and so is one whose own frame does 600 ms of work before the cube
  sees it or after, drawing: the same step (`src/dev/slow_frames_probe.gd`). Each is published to the
  page (`cube_turn_left` …, `cube_pan`, `cube_zoom_in`, `cube_fit`, and
  `cube_<face>` for the faces in view). `gizmo_probe` clicks each.
- `split view` (`SplitView`, `src/ui/split_view.gd`; APP_UX B9): View ›
  Split (F8 in every preset; LDCad's Space is one of Keymap's FIXED keys, so
  no preset takes it) puts a second, orthographic view beside the model, from
  the front, top, side or back (the buttons at its top; `×` closes). Its
  SubViewport shares the window's World3D and draws only while shown; its
  camera follows the main view's focus and zoom (pixels per LDU), so a part
  in hand is drawn in both. It is a column of `layout` after the model's
  own, so its width comes out of the model's: the bin and the right column
  keep theirs, the main view's `seen` rect is the rest, and `model_cover()`
  covers both views, less its header. A click over it places, picks and
  connects through its own camera: `CadCamera.beside` (`SplitView.ray_at`)
  gives `ray_origin`/`ray_normal` from the second camera wherever the point
  is over its picture. Overlays stay in the main view: the pivot mark is on
  `SplitView.MAIN_ONLY` (render layer 19), the view cube and the handles are
  2D over the main view. Off out of the box, kept per device (ShellPrefs
  `split`, `split_side`); greyed with "The window is too small for two views"
  where the model's column cannot give each view 320 points (`Room`, not
  units: a phone at 3x lays 900 units across 390 points), on a phone (short
  side under `Phone.NARROW`) and on a touch tablet held upright. fit_check
  with F8 pressed showed the split on both its phones until it was counted
  in points. Published to the page as `brickworksState.split`,
  `brickworksLayout.split`, and the controls `split_front` … `split_close`.
  `split_probe` (1280x720 and 1400x900) puts an 87087 on a side stud of a
  2 x 2 from the main view and from the second one, counting the actions (the
  second takes no more), checks the columns' widths, the narrow window's grey,
  the sides, the overlays, and that an idle split draws nothing; `-- unrouted`
  takes the routing away and must fail. Not routed through it: the connect
  tool's second pick and the handles, which use the main camera.
- `camera controls`: orbit, pan, zoom, and framing what is built. `_built_bounds()`
  is what everything frames against, baseplate excluded. View > Default view
  (0, `Main.default_view`) turns to the usual angle and frames what is built,
  the baseplate when nothing is, as Fit does: it turned the camera alone, so
  a view lost in empty space stayed lost (walk180 A2; `default_view_probe`,
  headless). Nothing that begins
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
  the model sat 168 units to its side. From the top of the column, the
  notices strip's place included, so a notice coming or going never moves
  the model: centred under the strip, the sub-assembly banner a double-click
  shows slid it 22 px from under the pointer, and the next double-click
  missed the part inside (2026-10-19). `assembly_probe` double-clicks twice
  at a still pointer across a 600 ms frame and checks the part has not moved
  going in or coming out (21.9 px before). Done by shifting the lens, not the
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
- `quitting cleanly` (`src/render/worker_tasks.gd`, `WorkerTasks`; `Main._exit_tree`):
  the window's close button, File, Quit, Ctrl+Q and any `quit()` end the app
  with exit 0 and the working model written. The engine keeps a worker task,
  and the GDScript it runs, until somebody waits for it; one waited for over
  frames was not when the app quit in between (a model of 600 parts or more is
  weighed on a worker after every change, `Main._weigh`), and the engine freed
  it after GDScript had gone: SIGSEGV in the task's destructor, then SIGABRT,
  every time a big file was closed straight after opening (2026-10-16; it was
  read as "files that carry parts" because the sets tried were big). Every
  task the app waits for goes through `WorkerTasks.add` and `collect`, and
  those still out when the tree goes are collected then; Brickify's dialog
  tells its run to stop (`Brickify.Progress.stop`, asked between its steps,
  inside the laying too, `Shapes.lay`'s "stop") and collects it before
  freeing the checker it reads: a 64-stud bunny held the quit 24.6 s, and
  goes in 0.6 s. And the autosave
  waits 2.5 s for a change to settle, so an edit made just before closing
  was lost: `Main._exit_tree` writes the working model now
  (`ModelStore.write_now`). `quit_probe` (headless) runs the app twice, a
  1,000-part model each time, deletes a part (its sub-model copy with it)
  while the weigh is out and quits by the close request and by File, Quit:
  each exits 0 with a task out, and its autosave is the model as it stood at
  the quit; and a third run closes the window 3 s into Brickify's run on the
  bunny at 64 studs: gone within 8 s (`--only=brickify` runs that one).
  Pass: exit 0 and `quit: quits cleanly and keeps the last edit`.
  On main both runs exit 134 and their autosave still has the 50 parts. The
  windowed close button is pressed for real with WM_DELETE_WINDOW from
  outside, which on a bare Xvfb needs the atom made first (Godot asks for it
  only if it exists, as a window manager makes it): results for 2026-10-16
  in `bench/results/quitcrash-2026-10-16/` of the main checkout.
  And with File, Render… at work (`RenderDialog._exit_tree`,
  `RenderOutput.close_now`): the window closed during the draft of its first
  open (`render`) and of its second (`render-again`) exits 0; a 4K picture
  being encoded as it closes is written whole (`render-keep`; it used to be
  lost without a word), a Good picture half drawn writes nothing and the
  log says `render, as the app closed: the picture was not finished`
  (`render-cut`), and a turntable keeps its frames drawn and says how many
  (`render-turn`). The draft needs a display: `-- --windowed` under
  `gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --headless … quit_probe.gd`
  runs the app windowed; headless, `render` and `render-again` open and
  close the panel with no draft, and the rest are left out. `--runs=N`
  runs each way N times, closing the draft 0 to 7 frames in. Every render
  way also lists what of the app's scripts is still on the signals of
  RenderingServer and every other engine singleton as the tree goes
  (`LEFT-ON-ENGINE`), which must be none: they outlive GDScript, and a
  lambda left on `RenderingServer.frame_pre_draw` (no `self` in it, or a
  static function's) aborts the exit, exit 134, every time. That was the
  abort quitting during a second open's draft once (2026-10-17): a probe's
  own timing lambda, not the app; a node's method or a lambda using `self`
  goes with the node (planted, the check names the first and the run exits
  134; it passes the second). Results in
  `bench/results/renderquit-2026-10-17/`.
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
  the Escape). Nothing in the parts bin but its search takes the keys
  (2026-10-16): a part's tile, a category, Make a part, Print and Stickers
  were buttons that kept the focus once clicked, and Right on the timeline
  then walked the focus round the bin instead of stepping (the CAD task
  test's browser run). `handbuild_probe -- only=build_from_a_booklet` takes a
  part by its tile and presses Right and Left on the timeline;
  `focus_check` does it in a browser, reading the timeline's place.
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
  frame for nothing: a value set again unchanged is a frame drawn. Nor a
  label on a timer: the Claude panel's "Claude is building — N calls, m:ss"
  ticked every second from Claude's first call until the tab was switched
  off, so in Chromium on SwiftShader, after any call of Claude's, the page
  drew a frame of 12 to 15 CPU-seconds back to back for good (89 to 185
  CPU-seconds of the GPU process in 20 s standing still, 0.2 before the
  first call, on 6 parts and on the 535-part station alike) and every
  picture Claude asked for waited behind the frames queued (2026-10-16; it
  and the run card's clock now move with Claude's calls). The
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
- `a lighter look where frames are slow` (`src/render/frame_budget.gd`,
  `FrameBudget`, made by `Main._watch_frame_cost`; docs/SLOW_DEVICES.md).
  It times each drawn frame that follows a drawn frame: the time from one
  drawing's end to the next, less the frame's own work. Two seconds in, it
  draws frames on purpose until ten are timed. Where the second fastest of
  the last six is over 50 ms, it cuts the next rung (dense, msaa, scale,
  shadow, glow; ssao first on Forward+), several at once when frames are
  4x or 16x over, and looks again while a rung is left (a look after the
  last drew 12 frames standing still in `outline_check`, m93). On the web each frame of a look has a fence
  after it (`GpuFence`) and is timed by when the card passed it, from when
  the card had done the frame before: the page hands frames over at 17 ms
  while SwiftShader draws each in 0.3 to 2 s. The look draws its next frame
  only while fewer than two of its frames are still to be drawn
  (`IN_FLIGHT`), skips no warm frames, and three in a row each over 200 ms
  (`SOON`, `FAR_MS`) are judged at once: a slow device is cut after three
  frames, not twelve, and no frame at full cost is left queued ahead of
  the cut. Holds (the parts bin's read-backs) cannot fool a frame timed
  by its own fence. So the empty editor is cut on its own while it loads,
  not at the first turn of the view. It never raises the look again. A probe leaves it off unless it calls `watch()`. The page
  reads `brickworksState.look`, and a check pins cuts with
  `window.brickworksLookAsk = {cuts: [...] | null, look: N}`.
  `tools/probe.sh look_probe` checks the judgment on a budget of its own,
  on the GPU that nothing is cut, and a look timed by fences of a card of
  its own (`FrameBudget.fence_by`): a quick one, the drawing stopped
  inside the look, cuts nothing; a slow one (400 ms) is judged after three
  frames, never more than two ahead of it. `-- --shots=DIR` writes three views
  to `cmp` against a checkout before: identical to rel-m87 on Forward+, and
  on Compatibility through zink (the env is in the probe's header; under
  Xvfb without it, Compatibility draws on llvmpipe, in software).
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
  app's own work and dragging it 11 ms a plate. On the GPU (2026-10-16) the
  cut on is 162 ms of that work and a plate 2.0 ms; `see_inside_probe` holds a
  move under a tenth of the work of turning the cut on (a whole frame was the
  yardstick, and on the GPU a frame is 18 ms of the GPU's own). The variants discard what is past the plane and draw the back
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
- `stress view` (`src/ui/stress_view.gd`, `BrickWorld.set_stress`): View →
  Stress (under X-ray) tints each part by the one stud joint that alone holds
  it, as Balance weighs it as the model stands (`Stability.check` with
  `with_margins`, on the status bar's own worker weighing, `Main._weigh`):
  red under a margin of 1 (past the studs' working load, 1 N a stud), amber
  under 2, every other part its own colour faded; the baseplate faded too. A
  joint that shares its load with others (a bonded wall) is never weighed and
  never tinted, and a contact on a part with no studs (an axle through a
  cross block) is not a stud joint. A touch shares no joint's load (Balance):
  what stands on a touch alone past where it touches is red ("stands on a
  touch alone, its weight past where it touches"), and what stands on one
  over it says so. The weighing is `Main.weigh_joints`, which the status
  bar's verdict asks too (with its margins wherever there are threads), and
  a session's `weakest_joints` reads the same numbers, so the three agree. Pointing at a part (Select in hand) puts on
  the status bar's left what it carries: "Plate 2 x 10: carries 11 g on 1
  stud, margin 0.7", or how it is held when no one joint holds it. A red or
  amber part's right-click menu has Ask Claude to brace this under Ask Claude
  about this… (only then, and never with the assistant off): it selects the
  part and what holds it and writes the request with the joint's numbers into
  the assistant. Its panel (`src/ui/stress_panel.gd`, `StressPanel`), down
  the model's right edge under the view cube while Stress is on, has the
  legend (red past its working load, amber within twice it, faded the rest),
  the count ("6 past working load · 0 near it", "0 past working load · 0
  near it" on a model that holds; `StressView.ranked`/`count_words`, which
  `weakest_joints` says too), and the weakest, worst first (a piece on a
  touch past it first, then by margin; every red and amber one, and the
  weakest of the rest to make 8): a row, Next or Previous selects its part
  and frames it with what holds it (`Main._show_weak`), and says why in the
  words pointing at it says and what would fix it (`StressView.fix_words`:
  "It needs 1.4 times the hold it has: brace it, give it more studs, or move
  weight back over the Brick 1 x 1"). Close turns Stress off. Drawn only: no
  paint, no history step, no revision. Off, it
  costs nothing; on, each change's weighing takes longer (1 s after turning it
  on for 75969-1's 925 parts, 3 s for Orthanc's 9,541, on the GPU box).
  A joint pins or axles alone make is weighed too (Balance's pins: "on a
  friction pin", "on an axle keyed in its hole"), and its words and the
  brace request say so. On the Cat D11 (6,793 parts drawn) Stress took 47 s
  and listed 14 joints, every one on studs (walk256's D12); it takes 7-9 s
  at load 35-50 (`technic_stress_probe`, under 10) and weighs 146, 125 of
  them pins or axles; `weakest_joints` answered in 11.6 s in the app at load
  49.
  Known gaps: a part standing on the floor or a baseplate is held by the
  floor, so a tower's foot is not weighed; a clip, hinge, ball or turntable
  is not weighed. `tools/probe.sh stress_probe` (hand-worked cantilevers, a bonded
  wall, the shipped models none red), `touch_probe` (walk180's tug bow amber
  at 0.86 with its ladder and without, a plate on a touch past it red and a
  weak joint, columns pressed down standing on studs and on a tile, and in
  the app the verdict, the view and `weakest_joints` agreeing) and
  `technic_stress_probe` (the D11 weighed as Stress weighs it, timed, its
  pins and axles among the joints and in the words), `stress_view_probe` (the menu, the
  tint, the hover, the brace offer, two OMR sets and Orthanc pictured in
  shots/stress/), `stress_list_probe` (the panel on hand-worked cantilevers
  and a plate on a touch: the count as `weakest_joints` says it, the worst
  first, every row clicked and stepped selecting and framing its part; then
  10297-1's 3,164 parts reading "0 past working load · 0 near it"; pictures
  in shots/stress_list/; `-- time FILE RUNS` times Stress coming on, for a
  base checkout too); `src/dev/stress_sets.gd -- FILE.mpd ...` counts red and
  amber on any sets.
- `controls panel and hint`: the keys sheet, opened with `F1` or Help, Keys and
  controls, and every key on it actually doing that; Settings (`,`, Tools,
  Settings…) is the same panel's other face (`ControlsDialog.open()` and
  `open_keys()`), never shown with it (APP_UX A1: the keys were a scroller one
  row tall over the settings). The sheet is `SHEET_WIDE` (Main insets it again
  on `face_changed`, at `wide()`), two columns of whole sections as tall as the
  window; its box (focused as it opens, not on a touchscreen) keeps the rows
  whose keys, words or section say every word typed, and the letters typed run
  no tool; Escape in it closes the sheet. Besides the list it adds each key a
  menu shows that the list does not name (Open, Save as, the steps, the
  cut-away, F2, Y), in the menu's words, from `Shell.key_text`.
  `keysheet_probe` (1280 x 720; PROBE_SIZE=1400x900 too) counts the rows wholly
  in sight (36 of 85 at 1280 x 720, 51 at 1400 x 900; 20 needed), types "hinge" and "undo" with real
  keys, and checks `,` and Tools, Settings show the settings and no key. Settings'
  last line says which build this is (`BuildInfo.describe()`): "Brickworks 0.1.0,
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
- `keys of one's own` (`src/ui/keymap.gd`, `src/account/keymap_sync.gd`,
  APP_UX A11, 2026-10-30): every tool has a key (Shift-X Move, Shift-O Rotate,
  Shift-I Hinge, Shift-V Clone, Shift-P Paint, Shift-G Hide, Shift-Delete
  Delete), C paints the selection alone (with nothing selected it says how to
  paint), and the sheet's "Keys like" (and Settings') puts on BrickLink
  Studio's, Mecabricks' or LDCad's keys. Clicking a key's chip on the sheet and
  pressing another sets it; Esc keeps it, Backspace leaves none; a key that is
  another's is refused saying whose, the keys kept for themselves (Esc, Enter,
  Tab, F1, F6, Space, Home, End, Backspace) and, on the web, the browser's own
  (Ctrl-N, T, W, Tab, R) are refused too. "Back to these keys" drops one's own.
  `Keymap.read()` turns each key into the key the handlers already answer
  (`EditVerbs`, `Shell`, `Main._key_pressed`) or into a command run by name;
  layers are own, preset, Brickworks' tool keys, then the handlers' own, and a
  key a higher layer takes unbinds the lower. Kept in `ShellPrefs` (`key_preset`,
  `keys`, `keys_at`) and, signed in, on the account: `GET/POST
  /api/account?op=keys` (`profiles.keys`, `supabase/keymap.sql`, additive), the
  newer of device and account winning. `keys_probe` (windowed, 1280 x 720;
  `PROBE_SIZE=1400x900` too; `--shots=DIR`) presses each tool's key, Studio's
  twenty keys under its preset (V H C L, Ctrl-L, Ctrl-Shift-L, Ctrl-Shift-V,
  WASD, the arrows and Shift-arrows, Ctrl-G, Ctrl-U, Ctrl-T, Ctrl-0, Ctrl-= and
  -, Ctrl-F), Mecabricks' and LDCad's, sets Shift-B in the sheet with a clash
  and Tab refused, and starts the app again on its data folder to find Shift-B
  still the Paint tool's. `controls_probe` presses every advertised key, then
  runs itself again under each preset (one alone: `-- --preset=studio`). On the web,
  `tools/web/keys_flow.mjs` sets Shift-B and reloads the page (local build or
  a preview, `preview_checks.sh … keys`). Not proven by a check: the account's
  half before keymap.sql is applied (the API answers `ready: false` and the keys
  stay on the device).
  Every key a message, tooltip or name read out names is the keymap's now
  (`Keymap.filled`: "{show_all|shows everything}" is "alt-H shows everything",
  Ctrl-shift-L under Studio's; a command with no key is named by its menu row,
  or the palette's key and its words). Tooltips set once are told with
  `Keymap.tell` and told again on a keys change (`Keymap.retell`, Main);
  `Command.tip` fills its own. `tests/test_keys_named.py` (in `minitest.py`)
  fails on a string in `src/` that spells out a key a person can set, Esc, Enter,
  Tab and the other kept keys aside; its EXCUSED list says why each left is
  left, and fails when one is gone. `keys_probe` checks the hide message says
  Ctrl-Shift-L under Studio's and Ctrl-Shift-H under LDCad's; `mould_ui_probe`
  and `print_ui_probe` press the keymap's Undo and Redo in their editors.
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
  and an L within 2%: an L framed on its box sat 3% high). Lit by a key and a
  fill, the fill without a glint (`highlight_probe`, windowed: no view more than
  2% pale; with the engine's glint the front left one drew dark stud tops white,
  2.3%). The stage
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
- `the timeline`: `StepsBar` (`src/ui/steps_bar.gd`), opened by B (Left and Right
  step it, listed in the controls since 2026-10-16), the toolbar's
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
  nothing placed before what holds it. On the timeline (B) a step, forwards or
  back, is a count raised or lowered in each batch (`StepsBar.reveal_upto`,
  `BrickWorld.reveal_upto`): the batches are written once in the order, and a
  step writes nothing again; under a cut or x-ray it falls back to
  `show_only`. An edit to a batch of the order ends it (`reveal_ended`) and the
  bar shows its step again. A step of 42082-1 was 50 to 58 ms headless, now
  the frame's own ~7 ms (`bigmodel` probe). A model wider than 24 studs, of 400
  parts or more (`TILED_FROM`; a smaller one was "Part 1", one step on a page
  of its own), is built a
  region at a time (`Instructions.REGION`): one tile of its plan finished before
  the next, borrowing only the bricks a region is directly waiting on, and the
  booklet starts each on a new page under a banner ("Part 2", or its name).
  On a 1,895-part castle the jump between consecutive steps went from a median
  of 12.5 studs (90th 38) to 6.2 (90th 12). `--booklet=PATH` with `--model=`
  writes the booklet and quits — about three minutes for that castle on the GPU.
  What rests on what is read off the studs (`Instructions._supports_of`): a
  stud reaching up into a part is under it, one reaching down is on a part
  turned over on top of it. The rule is the build check's (`Joints.studs_in`,
  which `Assistant._studs_reaching_in` calls too): the check asks its lattice
  what is past a stud's tip, the booklet asks the parts' own covers
  (`Instructions.Covers`, a point against each candidate's boxes in its own
  frame), and `instructions_probe` holds the two to the same stud pairs on the
  station. A stud from the side holds a part without its resting
  (`Node2.held_by`), and a part no stud seats rests on what its box sits on,
  as before. A
  plate pressed up under parts by its own studs with nothing beneath it goes in
  in the step of the last of them (`_pressed_up`, `Node2.under`), even past the
  step's size. On the held-out steps-score sample (2026-10-16, against main at
  2789cd0): things put in under one already there 19.6% to 11.3%, steps with a
  floating thing 18.1% to 14.9%, steps with a hidden new thing 19.2% to 13.8%,
  tau 0.27 to 0.31; planning the 100 files 16.0 s to 19.2 s, the 1,454-part
  Rebel Snowspeeder 0.58 s. Then pins by reach and a model on its stand in
  its own frame (2026-10-16, against 33da719, side by side): put in under
  11.3% to 6.4%, steps with a floating thing 13.0% to 11.0% (a piece begun on
  the table; 14.9% to 12.7% by the old rule), the 7 Technic files 31.5% to
  24.0%, hidden steps 13.8% to 14.3% and tau 0.31 within noise, planning 1.09
  times, the Snowspeeder 0.33 s.
  Then steps a builder can follow (2026-10-17): a step is drawn as it is
  filled, front and back, by the parts' boxes (`Instructions.Pictures`), and
  a part that would hide one the step holds waits for the next step; a step
  takes what is near any of its parts, and one more of a part it holds at
  that height from twelve studs (`_near_step`, `LIKE_REACH`); a step that puts
  a sub-assembly on takes the parts beside it (`ATTACH_TAKES_PARTS`, and the
  step player lists them on that page, `BuildSteps.lots`); what rests on what
  is read off the covers too (`_contacts_of`: a part no stud seats rests on
  what its cover rests on, a hanging part hangs from what its cover touches);
  a part hanging under one resting on it goes in that one's step on the model
  (`_hung_under`); and a ready part that joins no standing piece of the build
  so far goes after one that does (`_touching`, `UNJOINED_LATER`,
  `_steadier`). A step of wheels is wheels. `instructions_probe` checks a 3 x 3
  plate on a 1 x 1 goes in the step after it, three tiles five studs apart in
  one step, and that a page putting a sub-assembly on lists exactly its loose
  parts. On the held-out steps-score sample (2026-10-17, against d24d4d6):
  steps with a hidden new thing 14.5% to 11.7%, steps with a floating thing
  11.2% to 8.5%, things put in under 6.3% to 5.5%, parts the build check
  calls floating 17.3% to 4.0%, steps of one thing 23.3% to 19.6%, and tau
  0.30 to 0.26, a loss (docs/INSTRUCTIONS.md). A wheel whose name LDraw
  marks as an alias ("=Wheel Rim") is a wheel. Then (2026-10-17, later):
  wheels go on last again (`WHEELS_WITH_HOLDER` off, as the authors build);
  a part hangs only from what holds it from the side or by touch
  (`_hung_under`), not from the part on its studs; the table is under the
  model as it stands; what hides a step's part is drawn near it only
  (`Pictures.open_of`, `in_front`); the covers are read only where a part no
  stud seats is one of the two; and a section of one step goes under its
  neighbour's banner (`_fold_lone_sections`, checked by `instructions_probe`).
  On the held-out sample, judged once against d24d4d6 with the measure as it
  now is: steps with a hidden new thing 14.5% to 12.1%, steps with a floating
  thing 10.3% to 7.5%, things put in under 6.3% to 5.7%, the build check's
  floating 12.2% to 8.0%, steps of one thing 23.3% to 19.5%, tau 0.30 to
  0.28; planning about twice main's. Then (2026-10-17, planner2): what hides
  a step's part is looked for in the cells of space near it
  (`Pictures._built`, `_cover`), a part on studs is asked about covers only
  against parts no stud seats, and `_steadier` reads what a region waits on
  only when another region has a part ready, all three changing no step; a
  loop gives up a pin's, a side stud's or a pressed-up plate's need across a
  sub-assembly before the sub-assembly (`_ease`, level 3); and a sub-model
  off the table joined to the rest is a sub-assembly though it waits on
  nothing outside (`_holds_together`). `instructions_probe` holds 71200's
  subModel-4 and 8032's steering knuckles to callouts. On the held-out
  sample, judged once against 82e027d: the authors' sub-assemblies built on
  the side 51.1% to 54.2%, steps with a hidden new thing 12.1% to 11.4%,
  things put in under 5.7% to 5.3%, steps with a floating thing 7.5% to
  7.7% (within noise), tau 0.284 to 0.285; planning still about twice
  main's. The steps score's build check stands the table where the parts
  reach (`Lbm.PartMesh.lowest_at`), not at the lowest box, which a turned
  wheel's hangs below: the authors' own row 6.3% to 0.9%.
  Sub-assemblies are built on the side, as a real booklet's callouts are: a
  minifigure (by its parts, `Minifig.is_figure`), and any sub-model the file
  places that is small (at most `ASSEMBLY_MOST`, 60 parts, and under 30% of
  the model) and one piece — a top-level one, or one nested a level inside a
  big one (`LdrModel.Placement.unit` keeps "House#1/Window#3", and the brick
  carries it as `Brick.unit`) — or one put on at an angle (most of its parts
  off the square, `_turned`) of any size up to half the model, or short of the
  whole when the model places it itself (a model on its stand, 76161's
  Batwing), built square in the hand with steps of a page's size and kept in
  the order the build would have reached it as a section (its region). What
  rests on what in a turned one, and so its order in the hand, is read in the
  frame most of its parts stand square in, upright as most of them stand
  (`_frame_turned`, `_frame_of`, `Assembly.framed`); `instructions_probe`'s
  wing on its edge is built brick on brick in its own frame. A flexible thing
  inside one goes in as one there too (`Assembly.bundles`). A loop that would cost one its
  callout gives up the needs guessed from touching boxes first, then those
  read off a box, then any but a stud's across a sub-assembly on it (a pin's,
  a side stud's, a pressed-up plate's), and only then the smallest assembly
  on it (`_contract`, `_ease`). A flexible thing drawn in pieces outside a callout goes in as one
  part (`_find_bundles`, `Assembly.whole`). Each stands in the main build as one node; its
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
  6 of 8,603, with no step forced. A pin that joins two parts goes into one
  and the others go on it (`_find_joints`): waiting for both put it in last,
  buried between two beams. It goes into the one nearest the table through
  what holds it (`_reach`: studs, side studs, pins and axles either way, what
  a box sits on, from the lowest part that is neither a wheel nor a pin), then
  the lowest, and the lowest where the nearest would close a loop; a joint
  read both ways round is one, held by the nearer. A part held only by a
  guess (off the table, needing only what its box touches) goes in after what
  is held for certain (`Node2.guessed`), and a forced step takes the lowest
  part that is not a wheel. Wheels go on what holds them and tyres on
  their wheels (`_wheels`, by name: "Wheel …", "Tyre …"), whether or not the
  joint is known; a wheel holds nothing up, and goes in last within its
  region: the example car's booklet began with four wheels on the table. Steps take
  4 bricks under 150 parts, 6 under 500, else 8 (`_per_step`). Supports are
  found through a two-stud grid and the order through a set of ready bricks:
  the 8,603-part Orthanc planned in 87 s and now in 5. A model's steps are
  the same however it was reached: `instructions_probe` opens 8159-1, 7410-1
  and 6531-1 as File > Open does (their own parts, skins and figures) and
  8159-1 again, and holds its two plans (worked out, and the author's as the
  booklet draws them) to the same every field (`_same_however_reached`).
  Then the worked-out steps pass the Tested mark's steps test by themselves
  (steps223, 2026-10-24, `HeldSteps`, the last stage of `Instructions.plan`
  and `plan_paced`, so the timeline, booklet, saves and shares agree): the
  steps are built as the mark builds them (`Tested.Steps`, by its joints,
  `Tested.holds_into`), a part that would be in the air waits for the first
  step where something standing holds it, a sub-assembly put on before what
  holds it waits too, each piece of a sub-assembly built in the hand begins
  in its box's first step, and a part a step would hide goes in with what
  holds it, then the first of it. What already builds is left as planned.
  Of seed211's twelve house designs as saved, steps passed 4 before and 10
  after (the fox's two parts its body hides even beside their holders and
  the rover's figure's arm and hand still named); sculpt170's six bench
  designs 2 to 5. The castle's plan 1.1 to 1.5 s. `held_steps_probe` holds
  the fox, the pagoda and the robot (fixtures/house) to it, red without the
  mend, and sculpt170-043 to its plan unchanged. Authored steps are the
  author's and are not touched.
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
  there, or floating at their step (held to nothing on the table: the model's
  first parts, and the first parts of each piece of the finished model a step
  begins, as the authors build a second vehicle in the hand; and again with
  only the model's first parts), each with a 95% interval from resampling
  the files; `compare BEFORE AFTER` pairs two runs file by file. "Held" is the
  probe's own graph (`Stability.contacts` and the joints the build check
  reads), not the planner's. Every run first checks the measures on models
  with known answers (a stack built from the top floats twice; a plate in a
  deep well is hidden; a second tower begun from its top floats once when a
  piece begins on the table, twice by the model's first parts alone) and
  scores nothing if one is wrong; `--explain` prints, for ours, each
  floating, hidden and put-in-under thing with what the planner had it need
  and what the measure's graph holds it to, and a `CLASS` line saying whether
  a floating one floated on its own (a root) or went on one, and why the
  planner thought it held; each hidden thing found says whether earlier steps
  hid it or only its own step's parts, and each floating one how many steps
  it waited to be held. Since 2026-10-17 a stud from the side holds in the
  probe's graph (`Joints.studs_in` on the check's lattice), each piece of the
  finished model rests at each step on a table at its own lowest point, and
  the build check is asked with the ground at the lowest point of the model
  as it stands (`Assistant._ground_at`, `ExactCheck.ground`); the readings
  before are rows of their own, and the self-test holds a plate on a side
  stud and a car body before its wheels; the maths is pinned
  by `tests/test_steps_score.py` (scipy's own tau-b example, every pair
  against the definition).
- `the same plans from two checkouts` (`src/dev/plan_dump.gd`,
  `tools/plan_diff.py`, 2026-10-17, planspeed): a change meant only to make
  planning faster must not move a step, and the steps score's measures can
  stay put while steps move. `plan_dump.gd -- --dump --out=F --list=FILES`
  (a `res://` path a line; under an `XDG_DATA_HOME` of its own) writes four
  plans a file: as opened, the author's as the booklet draws them, and ours
  with the parts shuffled with and without their sub-models as the steps
  score plans them, each step's every field and the step player's view of
  each page (`BuildSteps.view`). Copy the script into an older checkout to
  dump that one; `tools/plan_diff.py A B` prints each file that differs and
  where, and the steps and callouts compared. `--time` times
  `Instructions.plan` alone on each file as opened. Over the 100 proof and
  100 tune files, 607928d against the planspeed change: 0 of 200 differ,
  87,856 steps (`bench/results/planspeed-2026-10-17/`). A plan moves with
  its parts too: a dump's first line is the md5 of the catalogue it read and
  each file's row has `geometry`, a digest of its parts' mesh files (of the
  text of a part the file carries); `plan_diff.py` says when the two read
  different catalogues and which differing files' parts differ (samebooklet,
  2026-10-17: for 13 minutes that day the shared catalogue gave 421 wheels
  and tyres other covers, and two dumps of one checkout either side of it
  differed in 7 files). In one process, shuffled or in reverse, or each in
  a process of its own, m73 plans each of the 200 the same
  (`bench/results/samebooklet-2026-10-17/`).
- `cad task frames` and `cad task frames in a browser`
  (`src/dev/cadtask_frames.gd`, `tools/web/cad_frames.mjs`; run by
  `tools/bench/cadtask.py frames`, written up in `docs/CADTASK.md`): the frames
  a builder feels at 100, 1,000 and 5,000 parts (the first real set's file in
  hash order within 10% of each: 4883-1, 75969-1, 42082-1). Desktop, windowed
  under xvfb-run with vsync off: the file opened as File, Open does, then a
  right-drag orbit, a 2 x 4 swept over the model in hand, 100 parts selected,
  Delete and Ctrl-Z, Ctrl-A, and B with Right five times; each frame timed
  between one frame and the next. Browser, on SwiftShader: the same by the
  page's own events (Ctrl-A for the selection), every engine frame timed by a
  wrapped requestAnimationFrame with its WebGL time apart. Budgets 16.7 ms and
  33 ms. Judges nothing: the numbers are this box's under load, and a suite
  check would compare ratios, never these. The browser rows also carry the
  app's scripts apart from the engine (`scripts_max_ms`: the worst frame the
  page's `window.brickworksState.busy` and `.slow` list, frames whose own
  work, process to drawing, was over 8 and 50 ms; Main._watch_own_frames;
  each of them in `scripts_each`), and each drawn frame's own work less its
  WebGL (`drawn_own_median_ms`, `drawn_own_p95_ms`, `drawn_own_each`): with a
  part swept in hand a drawn frame is a move, so this is what a move costs
  the app. The process-to-drawing window misses the pointer's own handling
  (input is flushed before the frame's process) and catches WebGL work done
  in it, so for a move the drawn frame less its WebGL is the measure.
  `--arrive=SECONDS` waits, up to that long, for the parts a model fetches as
  it opens (`brickworksState.awaited`) before the acts, so they are measured
  on the whole model and not on one changing at every arrival.
  `--gate` (2026-10-17) judges, and exits 1 on a miss: the app's own work,
  the frame less its WebGL, in each press of the timeline's Next's worst
  frame and an orbit's drawn frames at their 95th percentile under 200 ms,
  and select all's worst frame under 400 (a good build's read 114 to 190 ms
  here; `--step-ms`, `--orbit-ms`, `--select-ms`);
  `--bypass=` for a protected preview. It is the release's `frames` preview
  check on 75969-1 (`tools/release/preview_checks.sh`, alone): no check held
  a frame's cost, and the grab's drag handles, found twice a second in every
  browser, took a step there from 75 ms to 6.7 s while `steps_flow` passed.
  On a build with them it fails on every press of Next, and passes with
  grab's `420422d` (docs/CADTASK.md, section 6).
- `big models stay fast` (`src/dev/bigmodel_probe.gd`, in `tools/check.sh`):
  headless, so what is timed is the app's own work. Bare, it makes two models
  of 1,000 and 5,000 parts (towers of four bricks in eight colours, one size
  of the four a Technic brick with holes, fifty to a sub-model, author's steps
  of ten), opens each as File, Open does, and makes a part in hand swept
  across the model a step a frame (a 2 x 4 brick, a Technic pin, a copy of
  eight parts by Copy and Paste, a figure, a sticker; 40 moves each), a
  right-drag orbit, Ctrl-A, D, Ctrl-Z, Ctrl-Shift-Z, Delete and Ctrl-Z, B and
  Next, each by its key or click; the select, the move, its undo and redo and
  the Delete twice, the quicker kept. It holds ratios, never times: an orbit
  frame, a move with each of the five in hand (its frame, and the aiming
  alone, `Main._refresh_preview` at each place the pointer was, the median,
  floored at 1 ms) and a step of the timeline (and ten steps alone) no more
  than 3x from 1,000 to 5,000 parts, select all, the move, undo, redo, Delete
  and its undo no more than 9x (linear is 5, quadratic 25), the model asked
  what is under the pointer at most 3 times in a 30-frame turn (the press),
  every part's lattice cover its part's own after the moves, undo and redo,
  and what the web build tells the page of the sub-assemblies kept while
  nothing changes (`Main._page_assemblies`). And that what the aiming asks,
  the parts near the line kept by where they are (`BrickGrid`), finds what
  asking every one did: the builder's connectors are `JointSnap.sites_in`'s
  in its order, the end a pin is aimed at with and without the grid the
  same at every move, every part a sticker's line meets in `Stickers._along`
  in the world's order, and the part it goes on the one every part's faces
  asked in order strike first (windowed only: headless there are no
  triangles). Main at aad2371 fails two: aiming a pin 3.8x and a sticker
  5.3x (every connector and every part asked at every move). Main at 63cab62 fails six: the move
  13.1x, its redo 11.8x and Delete's undo 14.2x (sub-model copies matched
  again at every edit), ten steps 11.8x, 29 asks a turn, and the page's
  answer worked out at every asking. Then, where the checkout has
  `vendor/omr`, two real sets' files opened as File, Open does, each once
  and first, so the parts the file carries are built (kept nowhere:
  `CustomParts.keeps` off): 42082-1 opened whole (4,139 parts), and opening
  it takes no more than LINEAR's share of its 4.5 times 75969-1's parts
  (at most 8.0x; 4.7x here, main 5.3x). Without `vendor/omr` it says so and
  judges nothing there. Then it quits as a window closes after a big model:
  at once, the model up and its weigh on a worker (`quitting with the model's
  weigh on a worker`), so a crash on the way out fails it. Until 2026-10-16
  the engine dumped core there (see `quitting cleanly`), and this cleared
  the model and opened the real sets in a process of its own to step round
  it. Pass:
  exit 0 and `bigmodel: every act grows no faster than the model`. With
  `-- --open [--times=N] [--dump=DIR] [--profile] PATH...` it only opens
  each file N times (3): the open to its second frame and until it settles,
  its phases (`ModelStore.open_phases`: parse, carried, flatten, known,
  source, clear, lift, covers, draw, covered, place, meta), with `--profile`
  the bar's opened handlers one by one and their pieces alone, and with
  `--dump` the world of the first open written part by part (number,
  colour, transform, sub-model path, step, lattice cover; the store's and
  the history's state), so two builds' opens are compared with `cmp`. With
  `-- --profile PATH...` it opens real sets' files instead, judges nothing,
  and prints where each act's time went: every handler of the builder's,
  world's, timeline's and store's signals timed one by one, every node's
  `_process` in the orbit, and the pieces of an edit and an undo
  (`assemblies.copies_follow`, the lattice's let go, collide and put in, the
  world's flush) timed alone. With `-- --sweep [--profile] [--shots=DIR]
  [PATH...]` it opens each model and only sweeps, judged as above when it
  made the models: with `--profile` the aiming's pieces at each move
  (lattice raycast, `_onto_a_joint`, `_onto_side_studs`, `_settle`,
  `room_for`, `Stickers.face_at`), a 32 x 20 grid of places over the model
  each aimed at alone with the worst five in pieces (one line across misses
  where aiming is dear), and what a change to the model costs the kept
  connectors; windowed, `--shots` keeps a picture of each sweep halfway.
  Each sweep's ghosts (place to 0.01 LDU, turn, whether it could go down)
  are written with `--bigmodel-out`, so two builds' sweeps are compared
  move for move. Not `--out=`: Main reads that as "export the model and
  quit" (cadtask_frames hit the same). Results for 2026-10-16 are in
  `bench/results/bigmodels-2026-10-16/` and `bench/results/sweep-2026-10-16/`
  of the main checkout and `docs/CADTASK.md`.
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
  authored=true)` groups by those steps (`_authored_plan`; on Timeline and a
  share, `plan_paced`, what holds what is read a slice at a time, as for a
  worked-out plan: in one go the Wizard's Tower's own steps held a frame for
  1.7 s, orthsteps212): a sub-model's own
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
  (its parts join the step before; none is taken off). **Next step** (`E`,
  Edit, Build steps and the Build menu, 2026-10-16): the parts put down since
  the last step make a step after it, and the next part starts another, as
  Studio's step button does (`AuthorSteps.close_step`): a builder following a
  booklet, or writing one, ends each step as they build it, where before
  every step was its parts shift-clicked and Shift-N after. In a model with
  no steps the parts so far are step 1; with nothing put down since, it says
  so and makes no empty step ("step 2 is done: the next part starts step
  3"). `handbuild_probe -- only=build_from_a_booklet` presses it twice over
  the plane's first parts, undoes and redoes it, and opens the timeline on
  the steps it made. Each edit is one undo
  (`restep`/`unitstep` in `Builder._apply`, `AuthorSteps.squash`: an undo
  group is applied in the order kept, so a part renumbered after a move came
  back to its middle step). The first edit of a model with no steps copies the
  worked-out order in, in the same undo (`AuthorSteps.ensure`). An edit reads
  only what it changes: every sub-model's steps in one pass
  (`AuthorSteps.items_in`; the steps' looks only when a step has one), and the
  timeline's plan after it from what the last plan read of the model's shape
  (`Instructions._shaped`: what rests on and is joined to what, and the
  sub-assemblies, kept while no part moves, is recoloured or changes sub-model),
  and the timeline's new order drawn by re-ranking its batches in place
  (`BrickWorld._reranked`; a batch is written again only where its own parts
  changed order). A one-part edit on the Wizard's Tower held the window
  2.2-4.7 s and now 0.14-0.2 s at load 24, the saved file the same to the
  byte (race244); `step_edit_cost_probe` holds it under 300 ms of its own
  work, and checks the timeline draws what writing every batch draws. A part put
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
- `the booklet as a PDF and as PNG pages`: **Save as PDF** and **Save pages as PNG** sit beside Print in the
  booklet's bar (pdf249, 2026-10-24), shown where they work: on the desktop
  while the app serves the booklet (`Booklet.SAVE_SCRIPT` asks the app with
  `POST /save?pdf|png`; `BookletOut.save_wanted`, `Main.save_booklet_as`
  opens the Save dialog and answers with where it went), on the web in the
  app's tab (`BookletOut.finish` wires them; a download); from the file
  alone, Print only. On the desktop Instructions also writes the PDF beside
  the page it was asked to save, unasked (`Main._pdf_file`; walk256 D9:
  `save_dialog_probe`). The booklet is read back from itself a page at a time
  (`BookletRead`: the file on the desktop, the tab's sections on the web)
  into a PDF written by hand (`BookletPdf`: the step pictures the booklet's
  own JPEGs as DCTDecode, a part's picture once, boxes and arrows as paths,
  words as text in Liberation Sans, Helvetica's widths, the TrueType file
  embedded whole as FontFile2 with its WinAnsi widths read from its own
  hmtx and cmap: `BookletPdf.TYPE`, `font_metrics`; `assets/fonts/`, SIL
  OFL, credited in `Credits.LIST` "liberation"; 269 x 199 mm pages) or a
  zip of a PNG a page at 300 dpi (`BookletPng.DPI`, a pHYs chunk saying so,
  `dpi_chunk`; the words in the same type; drawn with `force_draw`, as the
  web's app tab is out of view and gets no frames). `booklet_pdf_probe`
  presses Instructions and then both Saves as the browser does, and
  `tools/booklet_pdf_check.py` reads the result with poppler and pypdf:
  page count, page size, every font embedded (`pdffonts`), every step
  picture byte for byte, the title and the element numbers as words, the
  zip's first and last pages 300 dpi in pixels and pHYs and against the
  PDF drawn by poppler (`--shots` against the browser's own pictures, from
  `booklet_print.mjs --shots-only`). `booklet_flow.mjs` presses both in a
  browser and runs the same check on the downloads.
- `the booklet`: build instructions laid out as a LEGO booklet, one HTML
  file that prints on A4 and Letter (landscape; `Booklet.PAGE` is 269 x 199 mm,
  inside both) and reads on screen (`--mm` scales the same millimetres to the
  window). From the toolbar's **Instructions** (added after Timeline by
  `BookletMaker.add_button`, by its words, because `model_bar.gd` is someone
  else's at the moment), the timeline's Instructions, or `--booklet=OUT.html
  --model=M`. It goes out as it is drawn (`BookletMaker.wrote`, a piece at a
  time: the cover first, then the parts' pictures as a stylesheet of their
  own, then each page as soon as its pictures are), and is read while the rest
  is drawn (`BookletOut`, `src/net/booklet_out.gd`, 2026-10-23): on the
  desktop into the file chosen (as NAME.part until it is whole) and, to be
  read, over HTTP from 127.0.0.1 on a port of its own, the browser opened on
  it with the first piece (a page opened from a file is read only as far as
  it then goes); the pieces are kept, so the page opens again while the app
  runs. On the web it is written into a tab opened as the button was pressed
  (`BookletMaker.open_tab`, then `document.write` a piece at a time; a page
  may only open a tab in answer to a click), or downloaded whole if the
  browser blocked the tab. `booklet_stream_probe` presses Instructions on
  the castle and reads the HTTP stream as a browser does: the cover within
  5 s, the first page of steps long before the last, what it read the file
  written, the page opened again whole, no frame of the app's over 500 ms.
  The browser flows wait for the tab's document to close (`bookletWhole` in
  `booklet_flow.mjs`, `booklet_edit_flow.mjs`, `brickify_flow.mjs`), and
  `booklet_flow` says when the first page and the first page of steps came.
  While it works the status bar says which part of it and how far (`Working`,
  `BookletMaker.job`: planning, the parts, the views, the steps, counted, with
  Cancel, which closes the tab), and so does that tab, which is the one in
  front (`BookletMaker.tell_tab`). The plan is `Instructions.plan_paced`
  (in a browser with the booklet's tab in front, with the drawing held,
  `GpuFence.hold`: each frame given back drew the model again, a second each
  in software), and each picture is read back once the card has drawn it
  (`GpuFence`, in `BookletStudio._drawn`), as `ModelShot` reads: read sooner,
  in a browser drawing in software the car's booklet held the page about
  three seconds a picture (2026-10-12, `progress_check.mjs`). Pictures are
  drawn several at a frame (2026-10-23): each in a lane of its own
  (`BookletStudio.PictureLane`, `PICTURE_LANES`, a copy of its stage's
  MultiMeshes, `BrickWorld.drawing`), the maker setting that many going at
  once (`BookletMaker._soon`) and putting what comes of them in place in
  step order; each picture's cutting down, model and new-part rectangles and
  JPEG are done on a worker thread (`BookletStudio._develop`); the views are
  measured eight at a frame (`measure_all`, `Lane`), the codes and the new
  parts alone drawn as masks the engine counts (`_count_marked`, the codes'
  `mask`). The castle's booklet (2,497 parts, 400 steps) went from 79-95 s
  to about 15 s on the desktop's card, every page byte for byte the same.
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
  front (less than 40% of them in view, measured by drawing the new parts
  again alone) drawn from the back with the turn sign, and turned
  back when the front shows 70%; a callout (cream box, sub-steps 1 2 3, "2x")
  with an arrow to each copy, projected through the step's own camera and
  drawn as print draws it, out of the box at a right angle and round one corner
  (`Booklet.elbow`), with a white edge so it shows on a black model, or, past
  three steps, pages of its own in a frame; a figure looked at in the face
  (`Minifig.frame_of`); the finished model front and back; then the parts by
  colour with counts and element numbers. A model too big to read whole (not
  fitting a page at 4 mm a stud) is framed on the part being built, the rest
  fading out at the picture's edges (`BookletStudio.shoot`'s fade). A section that
  touches nothing built before it (a second vehicle, by the parts' boxes) is
  drawn on a stage of its own for its steps, as a callout is, and framed on
  itself (`BookletMaker._find_apart`, `_where`), for 7636's harvester, which
  began as an axle plate drawn in the air over the hay bales. Read page by
  page on the desktop (2026-10-16, `--model=… --booklet=…` on Xvfb, then
  `tools/web/booklet_print.mjs`): 7636's first 40 pages each buildable, the
  harvester's first steps on a stage of their own, its axle plate still in
  the air beside the base until step 18 joins them; docs/INSTRUCTIONS.md has
  the pages. New parts are not
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
- `the booklet by hand` and `the booklet by hand in a browser` (`src/assembly/booklet_looks.gd`, `BookletLooks`, and
  `Shell.change_look`): how each step is printed, set by its designer as
  Studio's Instruction Maker sets it. On the timeline (B), in the build order
  or the author's steps, a **Booklet** row for the step showing: Turn left /
  Turn right (45 degrees), Higher / Lower (15), This view (the angle the window
  looks from), Usual view, Zoom in / out (0.5x to 3x, framed on what the step
  adds), Bigger / Smaller (0.6x to 2x on the page), New page, Alone, Parts
  list, Callout (the sub-assembly the step puts on, in a box or on pages of
  its own), Per page (as fit, 1, 2, 4); the row's line says how the step is
  set ("turned 45°, zoom 1.25x, new page"). The same are Build, Booklet page.
  Each is one undo (`steplooks` in `Builder._apply`: the table as it was);
  the first on a model with no steps of its own gives it the worked-out
  ones in the same undo. Kept in `BrickWorld.step_looks` by sub-model and
  step, and moved with their parts by a step edit (`BookletLooks.follow`;
  a turn by what its parts were seen from, `_turns_follow`). In the file a
  turn is LDraw's `0 ROTSTEP x y z REL|ABS|ADD` ending the step before (it
  turns the step after it, as MLCad reads it and LDraw's model repository
  writes it, and holds until another or `0 ROTSTEP END`; a sub-model's
  first step's goes before its first part); the rest are the app's own
  lines inside the step (`0 !BRICKWORKS PAGE NEW|ALONE`, `ZOOM`, `SIZE`,
  `PARTS OFF`, `CALLOUT OFF` in a sub-model, `PER_PAGE` in the model),
  written by `BookletLooks.written_into` on every save and read on open.
  Someone else's file whose steps were merged, split or reordered is
  written again a sub-model at a time (`SourceFile._restep`): a merge is its
  STEP line out, a split one in, a reorder whole steps moved with their
  ROTSTEP, every other line byte for byte; a step of only a ROTSTEP in a
  sub-model that is edited is taken out, its turn given to the step it
  turned. Earlier refuses a step whose parts stand on the one before
  (`AuthorSteps.blocked_swap`, read off the parts' boxes), and Earlier,
  Later and Merge go to the nearest step with parts. `BookletMaker` draws a
  turned step from its turn (`entry.fixed`), a zoomed one framed on its new
  parts (`_zoomed`), lays pages out with the breaks, per-page most and sizes
  (`Booklet.lay_out`), leaves a parts box off, and gives a callout turned off
  pages of its own (`Callout.own_pages`); `lay_out_only` lays the pages out
  drawing nothing, which is what `booklet_layout` reads. Over MCP:
  `booklet_layout` (read-only: pages, steps and each step's look) and
  `edit_booklet` (step=, turn=, tilt=, zoom=, size=, page=, parts=, callout=,
  per_page=; one undo). `booklet_edit_probe` (`gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a godot
  --path . --resolution 1280x800 --script src/dev/booklet_edit_probe.gd --
  --into=DIR`: windowed on Xvfb, or the pictures are never drawn; never
  `--out=`, which Main takes as an export; `--no-booklet` headless) first does steps_flow.mjs's own moves on gatehouse.mpd (Shift-] on the yellow
  brick, Ctrl-Z, Shift-] again; the export four steps of the model's own, the
  blue brick's ending in its ROTSTEP, read as LDraw reads it: a ROTSTEP ends a
  step as STEP does, which steps_flow's reader missed in m65; `--only=gatehouse`
  alone), then what is set on a step stays on it (`_settings_stay`,
  `--only=stay`, headless with `--no-booklet` in about 3 minutes):
  `tests/fixtures/steps/row.mpd` (seven steps of two bricks of a colour,
  none on another, and the pair, a callout of three steps of its own on
  the green bricks, its callout turned off here). The yellow
  step gets every kind of setting a step has (turn, zoom, size, page alone,
  parts off, sign off, picture, parts and number placed, words, a picture,
  an arrow) by the Booklet row and `edit_booklet`; the black and the pair's
  second step get a few; the booklet gets two a page and no outline. Then
  the yellow step is moved every way on the timeline and by `edit_steps`
  (earlier, later, merge with next, the one before merged into it, split
  twice, a part moved out and one in, Delete step before it), the black
  and the pair's step are moved, each undone and redone. After each, the
  step holding the yellow brick has exactly its settings and its turn, the
  others theirs, no other step any, and the undo gives the file back. Then
  mcpwalk t2: a step's parts taken off by `edit_model`, saved and opened
  again, another's taken off, a part put on, `edit_steps later` (the step
  asked moves, not the next) and a merge, saved and opened again (the same
  settings, and saved again the same text). It does this on the file
  written back over and on a copy written whole (Author: Brickworks): 181
  checks, of which 19 fail on the code before stepsettings. Windowed, it
  also puts a step earlier with Lay out page… up on its page and checks no
  step there shows a picture drawn of another (`_pictures_follow`), and
  writes `row_before_move.html` and `row_after_earlier.html` to print
  (the whole probe windowed on the GPU: 524 checks, 2026-10-18). Then it opens
  30050-1 (ROTSTEPs, ABS), 106-1 and 10016-1 (no steps) as
  File, Open does; checks a file
  opened and saved unchanged is the file; merges, splits, reorders (and is
  refused where a step stands on the one before), moves a part, each one
  undo, parts' lines only moved, every part seen from the side it was, and
  the undo giving the file back byte for byte; each look alone adds exactly
  its line (a turn: the STEP before it a ROTSTEP) and undoes exactly; every
  look at once survives a save and reopen and saves to the same text; and
  the booklet made from them has the new page's step heading its page, the
  step alone alone, at most the steps a page asked, the parts box off, the
  callout on its own pages, the turned step drawn from its turn and the
  zoomed one larger, and its pages laid out without pictures are the same.
  It writes each set's booklet before and after with their pages as JSON;
  `node tools/web/booklet_print.mjs SET_after.html DIR` prints the PDF and
  checks it has the booklet's pages. `booklet_edit_flow.mjs` does it in a
  browser by the row's buttons and the keys (Right, Ctrl-Z, Ctrl-Shift-Z) on
  106-1, makes the booklet from the timeline's Instructions, reads its pages
  (`section.page[data-steps]`), prints it to PDF and exports the file.
- `the booklet page by hand` (the Booklet row's Lay out page…, or Build,
  Booklet page, Lay out the page…; `src/ui/page_editor.gd`): the step's page
  to scale, from `BookletMaker.lay_out_only`, then its steps' pictures and
  parts drawn by `BookletMaker.draw_steps` (those steps alone; not
  headless). Each step's picture, parts list, callout and number is a
  control named `page_picture_N`, `page_parts_N`, `page_callout_N`,
  `page_number_N` (words and pictures added `page_text_N_I`,
  `page_image_N_I`; the selected one's corner `page_resize`) to drag, and
  the corner sizes it; `Booklet.snapped_to` snaps it within 2.5 mm to the
  margins, the page's middle and the other boxes. A drop is one undo
  (`Shell.change_look` "place", "note"; "text" and "image" add; "highlight"
  the outline). Saved by `BookletLooks` as `0 !BRICKWORKS PLACE PICTURE x y
  w h`, `PLACE PARTS x y w`, `PLACE CALLOUT x y w h`, `PLACE NUMBER x y`,
  `TEXT x y w h size words`, `IMAGE x y w h name` with the picture as `0
  !DATA name`, and `HIGHLIGHT OFF`, in page mm; `Booklet._by_hand` lays
  them out and `Booklet._notes` prints the words and pictures. The new
  parts' band is `booklet_ink`'s `mark_new` (`halo`). A step alone may be
  drawn up to `ALONE_MOST` times ten mm a stud; `BuildSteps.view` follows
  `BookletLooks.turn_at`; `AuthorSteps._copies_alike` steps a sub-model's
  copies as its first when the worked-out steps are taken. Over MCP
  `edit_booklet` `place=` / `text=` / `highlight=`, read by
  `booklet_layout`. What is placed is kept with the step's room on its page
  (`0 !BRICKWORKS PANEL x y w h`, Shell.change_look's `room=`, from
  `Entry.panel`): `Booklet._by_hand` moves and scales it into the step's
  room now (`BookletLooks.rebased`), and a merge (`BookletLooks.follow`)
  keeps both steps' words, pictures and arrows. `Booklet._settle` keeps
  nothing on a page of steps on anything else (`things_on`: a picture is
  its model's ink, `ink_of`; placed things first, then laid out, then words
  and pictures; the one that lands on another goes to the nearest free room,
  `Page.overlaps`), and a page laid out by hand has its step pictures drawn
  clear behind the model (`Entry.clear`, WebP). The page editor outlines
  what moved in red and says it; `booklet_layout` says "overlapping: ...".
  Arrows: Draw an arrow (`page_add_arrow`), a drag on the canvas, the
  selected arrow's `page_arrow_start` / `_end` / `_bend` handles,
  `page_arrow_colour`, `page_arrow_width`, Delete; `0 !BRICKWORKS ARROW
  RED|BLACK width x1 y1 x2 y2 [bx by]` on the step whose room it points into
  (Shell.change_look "arrow", "arrow_edit"), printed by `Booklet.drawn_arrow`
  (`path.drawn-arrow`); `edit_booklet arrow=`, whose answer says whether the
  tip is on the step's new parts (`AppTools._aimed`, `Entry.adds` from
  `BookletMaker._adds`), and `booklet_layout` gives each step's "its new
  parts at x-x x y-y mm"; `booklet_probe` holds every drawn step's new parts
  (`measured` "new parts of step N") inside where the layout says they are. The turn sign
  (`Booklet._turn_sign`, `g.turn-sign`, under the number, `sign_rect`) is due
  past `BookletMaker.TURN_ROUND` (60°) round or `TURN_OVER` (45°) up or down
  (`_round_from`); `page_sign_N` on the page editor, Delete / Put back
  (change_look "sign", `0 !BRICKWORKS TURN_SIGN OFF`), `edit_booklet
  sign=`. A callout's own pages (`kind` "callout" in `page_state`, framed)
  are among the editor's pages; their steps carry the sub-model's looks
  (`BookletMaker._hand_look`, plan index as the entry's "step" meta), are
  settled inside the frame (`Booklet._room_of`), and are drawn with the
  step that puts the callout on (`_attach_of`; pictures keyed by page and
  step, `_shot_key`). `booklet_edit_probe` drags by the mouse (windowed),
  checks each edit's line, undo and reopen, the dry layout (the placed
  boxes, the step alone filling its page), a placed step moved by a merge
  (or a page alone) taking its picture and words into its new room and no
  page with one thing on another (`_follows`), a picture dropped on
  another's said while held and moved when let go (`_overlap_said`), an arrow drawn, bent,
  recoloured and widened by the mouse and one over MCP (`_arrows`), the
  sign at 30° and 60° lower, off and back (`_signs`), a callout turned off
  and its own page laid out by hand, Previous / Next page to it, its first
  step's picture dragged and an arrow drawn (`_callout_by_hand`), the step player's
  turns, and the booklet's HTML (the page as placed, the arrow printed and
  none before, a sign per turned step, nothing printed on anything else, the
  outline's orange pixels on and off); `booklet_edit_flow.mjs` drags the
  picture onto the margin and the parts list's corner by the mouse in a
  browser, adds words and a picture through the file chooser, draws an
  arrow, Ctrl-Z / Ctrl-Shift-Z, then moves that step: Later or Earlier on
  the timeline, and where both are refused (106-1's step 4, 2026-10-18)
  Merge with next on step 1, which brings it to step 3. It reads the row of
  the moved step (still a new page) and of the alone step (still alone), the
  printed page of the moved step's new number (the picture as dragged, the
  words, the picture and `path.drawn-arrow`, none on any other page) and the
  exported file (ARROW, PANEL). It ends "...a page laid out by hand and its
  step moved with its arrow..." (47 checks, 2026-10-18, on a local export).
  **Apply to later pages** (`page_apply_later`; `PageEditor.later_layout`,
  recorded as one undo by `Shell.place_pages`; over MCP `edit_booklet
  follow=true`): every later page of the same kind with as many steps
  takes the page's layout, each step's placed picture, parts list, number
  and callout moved into its own room (`BookletLooks.rebased`), a parts
  list or callout only where the later step has one, the list as wide as
  its own parts need and kept to its side, nothing else placed, and a
  placed picture's box cut to what the step's list leaves of it
  (`PageEditor.clear_of`) and shrunk round its centre so the later model is
  no larger than the booklet draws a step (`Booklet._most` x `_grown`), a
  page's steps alike; pages of another number of steps are said as left.
  `booklet_later_probe` lays 42004-1's booklet out at one step a page by
  the mouse in 9 acts (bar 10) and checks every later page against the
  first, the cap, nothing on anything or off the page, the callouts where
  the booklet lays them, Ctrl-Z byte for byte, `follow=true` the same file,
  and a reopen laid out the same.
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
  Choices: Quick, Good or Best; the look, As in the window or Product (see
  `product look`); 720p, 1080p, 4K, a square or a custom size;
  a white, gradient, grey, dark or coloured sweep, or none (transparent, the
  contact shadow kept as a shadow on nothing; `RenderSettings.BACKDROPS`, the
  same names render_model takes); the window's three lights or one of
  three Poly Haven HDRIs (`assets/hdri/`, CC0, docs/ATTRIBUTION.md), turned
  round by "Light from"; the contact shadow; the view looked at or six
  presets; a full-frame focal length; f-stop and focus (Best); Best's frames;
  a turntable's 24-72 frames; Animation, one of the model's motions or
  All, in order (`Motions.in_order`), its camera As I see it (as the
  picture is) or Framed on what moves (`RenderSettings.on_what_moves`: the
  camera fitted to the corners of every moving part in every frame,
  `MotionRender.swept`, `StudioRender._fit_points`, the set still laid
  under the model and the sweep). Animation is `MotionRender`, the one path
  the Motions panel's Render animation (`PosePanel.render_poses`) and
  render_motion take: the frames played through Grab (`frames_of`; a
  sequence kept motion by motion and taken back with
  `Builder.take_back_to`, redo kept) and the files named after the model
  and the motion, numbered when taken (`RenderOutput.begin_animation`,
  "main Open the doors 2.webp"). Done, a picture downloads (browser) or is
  written to Downloads (desktop, "Show in folder"); a turntable is an
  animated WebP (`src/render/animated_webp.gd`, stills from
  `save_webp_to_buffer` put in the animated container by hand), and on the
  desktop also its frames as PNGs and, where `ffmpeg` is found
  (`RenderOutput.ffmpeg`, PATH and the Homebrew and usual places), an MP4.
  Cancel or Escape stops it. The page publishes `window.brickworksRender`
  (state, progress, what was downloaded, and the render's longest frame and
  what it was doing then, `StudioRender.worst_step`) for a browser check.
  While it is open a veil covers the window and the window's own model is
  not drawn (`disable_3d`, put back as Main would have it on Close). Before
  it is first opened, the first time nobody has touched the window for 3 s
  and nothing on it has been drawn for as long, and never while nobody can
  see it, the panel has its renderer made ready (`_warm_when_idle`,
  `StudioRender.warm_up`), each step waiting while anyone is using the window
  or anything else wants a frame of it (FrameBudget's look, a picture of the
  bin): its set, eight pixels square, is then drawn alone, off screen, in a
  draw forced with the window's viewport left out (`StudioRender._draw_alone`),
  not in frames of the window. Each step was one, the whole model again, 1 to
  5 s a frame over Orthanc in software (2026-10-19): `render_probe.gd --
  --first-open` counts the window's frames while it is made ready (at most
  one, for the set's nodes laid out; 7 before). Not in a probe that does not
  ask (`RenderDialog.warms_when_idle`), as IdleDraw leaves a probe be:
  idle_probe counted them as 9 frames drawn in 5 s standing still.
- `product look` (`RenderSettings.look` "product"; Render's Look, render_model's
  `look=product`, with `backdrop` and `depth_of_field`; docs/RENDERING.md):
  the render's copy of the model drawn in the `plastic_product*` shaders
  (`BrickWorld.product`, `PRODUCT_SHADERS`; `PLASTIC_PRODUCT` in
  `plastic_body.gdshaderinc`: a clear coat over the plastic, edges of the
  part's body box and studs' top rims rounded by a bent normal (`bevelled`,
  `stud_rim`), chrome and metal reflecting the studio's sky; clear parts in
  two passes, `plastic_product_glass` multiplying what is behind by what
  each surface lets through, every surface, so a clear part's own walls and
  tubes and the clear parts behind it show, then the reflections added on
  top; on nothing, the None backdrop, blended as the window's glass,
  `over_nothing`), a key, fill and rim (`StudioRender.PRODUCT_RIG`) over the
  softbox HDRI on the desktop with its room flagged down to
  `PRODUCT_ROOM` (`studio_sky.gdshader`: black stays black, the softboxes
  still give every highlight), Filmic graded by `PRODUCT_WHITE`,
  `_SATURATION`, `_CONTRAST` and `_EXPOSURE`, a key shadow biased past its
  soft filter (no hatching at Good), the meter blind to the look's glass,
  and the sweep's fall of light (`studio_backdrop.gdshader` `fall`, `pool`)
  for the gradient and dark backdrops. Check: `tools/probe.sh
  product_render_probe` (GPU, Forward+; it SKIPs, which fails, on another
  renderer) prints 18 ok lines: every batch of the render's copy in a
  product shader and none of the window's, Filmic, a picture that differs
  from the window's look, white corners above 0.85, the gradient at least
  0.1 darker in its corners than under the model, dark corners below 0.12,
  depth of field at f/2 losing detail, the window's own GPU time per frame
  (median of 120) within 10% + 0.3 ms of before, its environment as it was;
  then sixteen colour swatches at Good, each lit face's CIEDE2000 from
  LDConfig printed: black's bricks' mean lightness under 0.19 (0.218 before
  render342), dark bluish grey within 6, red, yellow, blue, green, white
  and tan within 5 on average, the clear colours within 4.5 (4.11 at
  render342, 2.76 at render353), and a light grey face's grain under 0.012
  (0.038 hatched); then a wall of trans-clear 1 x 4s in front of a
  trans-red one: the clear wall's face red by at least 0.25 (r - (g+b)/2;
  0.00 before render353, the red wall not there behind it, 0.34 after),
  and the same drawn on nothing glass, alpha over 0.3 and lightness over
  0.35 (black before, 1.00 and 0.16); pictures in `shots/render/product_*`,
  `product_swatches.png` the swatches, `product_glass*.png` the walls.
  In a browser: `cli:product look in a browser`.
  A model: `tools/probe.sh render_probe -- --model=models/sports_car.ldr
  --look=product --gradient=1 --backdrop=#f5f6f8 --quality=best
  --size=1280x720 --picture=OUT.png`. Over MCP: render_model with
  look=product (mcp_sync_probe keeps tools/mcp_tools.json in step).
- `product look in a browser` (`tools/web/product_render_flow.mjs`): the
  web build's Product look under Compatibility, where the desktop's probe
  cannot vouch for it and where the first Product glass read the wrong
  picture (a pale patch on the sports car's windscreen). Opens a black
  2 x 4 wall behind a taller, longer wall of trans-clear ones and a white
  wall behind trans red ones, presses Render, Product, Quick and 720p, and
  draws each of white, gradient, grey and dark, each downloaded. Check:
  `tools/web/serve.py build/web PORT --parts assets/generated/parts` after
  `tools/export.sh web`, then with .env sourced `node
  tools/web/product_render_flow.mjs --url=http://127.0.0.1:PORT/index.html
  --out=OUT` (or `--url=<preview>/app --bypass=$VERCEL_BYPASS`;
  preview_checks.sh's `product_render`, run alone): `the glass walls opened
  (16 parts of 16)`, the dialog opens, and on each backdrop a 1280x720 PNG
  whose lightness spreads over 0.01 and at least 0.5% of it red (redder by
  0.15 than green or blue; 0.05% on dark, where the glass has little light
  behind it); on white the model at least 2% of the picture and
  at least 0.5% near black (the black wall, seen only through the clear
  glass), no script errors. `--also=models/sports_car.ldr,…` draws those
  models too at Good on white, for pictures.
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
  copied again next time — the model itself is never touched. `warm_up`
  makes the set ahead of the first render, on both renderers: the viewports,
  and the sweep and the contact shadow drawn once, each alone (`_warm`); a
  render asked for meanwhile waits the few frames left (`_prepare`).
- `motions panel` (Build, Motions…, once Pose and animate…; `src/ui/pose_panel.gd`,
  class `PosePanel`, over the model's left edge so what moves is seen; the
  owner's ask, 2026-10-20, docs/MOTIONS.md "What unit 2 built"). The list:
  the model's motions, a row each (chosen for Render animation by its radio,
  Play, Play backwards, Edit); Play all (`Motions.in_order`, each after the
  one it follows) and Loop; "Suggested from what moves" (`MotionPlayer.suggest`)
  with Keep; New motion. Play is `MotionPlayer.play` kept (one step), its
  frames drawn over the model (`BrickWorld.set_drawn`, 12 a second) and its
  words (`MotionPlayer.said`) in the status line. The editor: Name (rename is
  one step, AFTER follows it), Remove, Record (every Grab drag in the view
  sampled 30 a second, thinned to keys within 2° or 0.1 stud, from where the
  joint stood to where the drag kept it; at Stop the drags are undone and
  the motion is one step), Play, Play backwards, At (the time; the model
  drawn as the motion has it then, played to look), a slider for each of
  Grab's joints that moves (`MotionPlayer.movable`: Playable's first, a
  joint with no room for 10° either way left out; five besides its own until
  Show all), each moved through Grab live (`MotionPlayer.hold`, `step_to`) and
  let go a key at that time, and its keys on a strip (`PosePanel.KeyStrip`:
  pressed chosen, dragged moved in time, between them the time set), the key
  chosen Eased, Linear or Held, or removed. Every change is a "motions" step,
  and the panel reads the history each frame it is open (an int and a
  reference), so an undo or a session's define_motion shows at once. Closed,
  it does not process. Render animation draws the chosen (or edited) motion
  through `render_poses`, as render_motion does: Quick, 480 × 300 or 720p,
  12 or 24 a second; a browser downloads `<model>_<motion>.webp`; the desktop
  writes the frames, the WebP and, with ffmpeg, an MP4. pose_model's joints
  (`Poser`, `set_angle`, `joints_now`) and animate_model's keys
  (`animation`) stay on the class for MCP. `window.brickworksMotions` says
  the view, the motions, the suggestions, each joint slider's ends on the
  page, the time slider's, recording, playing, and the render's progress and
  file; `controls_by_name` names `motions_*` and `motion_*_N`. A sequence
  (unit 5) is a row like any motion; New sequence keeps one of every motion
  in Play all's order (`PosePanel.new_sequence`, one step, named "Show it
  all") and opens its editor (`_view` "sequence": Name, Remove, Play, Play
  backwards, its motions in order each with Up, Down and Take out, and Add
  from the model's motions; each change one step), named `sequence_*` and
  `sequence_up_N`/`_down_N`/`_out_N`. A sequence and Play all are played by
  `MotionPlayer.play_in_order`, each frame with every part
  (`MotionRender.whole_frames`). A rename renames it in every sequence.
  The status line is shown whole, the panel grown to it (`_fit`; trimmed
  with its words in the tooltip only when the window has no room).
  (`RenderOutput.add_frame`, at most three waiting). Under Compatibility
  every 3D draw of the set first draws, alone and one a frame, each thing in
  it that view has not drawn in that set-up (`_warm`: a batch per shader and
  mesh format, the sweep, the contact shadow; on a layer of its own that the
  lights are put on too), the card left to finish each (`GpuFence`) before
  the next; and every picture is read back only once the card has finished
  it (`_read`), so a read-back no longer holds the page while it rasterises.
- `motions` and `playing motions` (`src/assembly/motions.gd`,
  `src/assembly/motion_player.gd`; docs/MOTIONS.md): a model's own named
  movements, "Open the doors", kept in its file as `0 !BRICKWORKS MOTION`,
  `MOTION_TRACK`, `MOTION_KEY` and `MOTION_DRIVER` lines in the head of the
  main model after the floor's, written the same every time (the save, the
  autosave, an export, an .io, a shared link's text) and read as the file
  opens (`BrickWorld.motions`; define and remove are a "motions" history
  step). A track's joint is found by its sub-assembly or its part's number,
  colour and place, and measured from where the model was built (AT, so a
  door saved open opens no further). Played through Grab (`GrabDrag.held_of`,
  a frame at a time, loops 3° at a time), it stops where it meets the model
  and says so by name and degree; kept, one undo step. Suggested from what
  moves (Playable). Over MCP: list_motions, define_motion, play_motion,
  render_motion (Render animation's path, `PosePanel.render_poses`);
  animate_model keeps its keys as the motion "Animation" and plays it once
  to render. In the window: `motions panel`. A sequence (unit 5): `0
  !BRICKWORKS MOTION "Show it all" SEQUENCE "A" "B"`, the motions it plays by
  name (`Motions.played_by`, `flat`, `seconds_of`), each from where the one
  before left the model, backwards in reverse order; a name the model lacks
  is kept and said, "passed over". AFTER lines are read and written as
  before and Play all follows them, but a sequence is never in a chain and
  nothing makes AFTER any more. play_motion's picture is from the view that
  sees most of what moves (`MotionRender.seen_from`, `best_view`: the
  lattice marched from each moving part toward each of StudioRender.VIEWS).
- `render open check` (`tools/web/render_open_check.mjs`): the Render
  dialog's first open in a fresh browser, from the toolbar, every frame from
  the press to the first draft timed in the page (the engine's frame
  callback, WebGL included, with the programs it linked counted apart), then
  a second open, closed and pressed again once the page is quiet. Fails past
  `--budget` ms (250) for a frame of either open, on no draft, or on a
  script error; `--port=N` serves the export there. It presses Render after
  the page has gone quiet, so the panel has made its renderer ready by then.
  The desktop's half is `render_probe.gd -- --first-open`: the same two
  opens on the sample car, every frame timed, fails past `--budget` ms
  (100); left alone first as a person leaves it, or pressed `--at-once`
  before that, or `--during` the making ready while it waits for someone
  using the window (it must wait, and the press must not).

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
godot --headless --path . --script src/dev/held_steps_probe.gd    # worked-out steps pass the Tested mark's steps test
#   the fox, pagoda and robot as the designer saved them, red without the mend
godot --headless --path . --script src/dev/steps_score.gd -- --selftest  # the steps score's measures give known answers
python3 tools/minitest.py tests/test_steps_score.py                # ...and its maths (tau-b, intervals, samples)
python3 tools/steps_score.py run --which proof --out build/steps_score/proof   # ~10 min under heavy, then
python3 tools/steps_score.py report --out build/steps_score/proof  # the table docs/INSTRUCTIONS.md quotes
# the frames a builder feels at 100, 1,000 and 5,000 parts, desktop and browser
# (run bare: heavy, xvfb-run, serve.py and .env are its own business; the
# browser half needs build/web exported from this checkout)
python3 tools/bench/cadtask.py frames && python3 tools/bench/cadtask.py report
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
godot --path . --resolution 1280x800 --script src/dev/booklet_stream_probe.gd  # the castle's booklet read as it is drawn
godot --path . --resolution 1280x800 --script src/dev/booklet_pdf_probe.gd -- --into=DIR  # the castle's booklet saved as a PDF and as PNG pages from its own Save buttons; --model=res://models/orthanc.ldr for the tower
#   every step pictured and framed on the model, new parts in frame, a parts box
#   with a picture of every part, the shed's 2x callout with two arrows and its
#   figure, the turn sign behind a wall (plates against its back), plates a hand's
#   width away drawn on a stage of their own from the front (_find_apart),
#   the timeline's numbers = the booklet's,
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
# A one-part step edit on the Wizard's Tower (next, previous, a new step):
# under 300 ms of its own work each, the least of three tries (its time less
# what the main thread waited for a CPU; 900 ms at a load past the cores,
# where the work itself slows: 277-353 ms at load 30-48, 125-264 at 26-27,
# base 2.6-4.5 s), the plan after it the plan read afresh, the timeline
# drawn as writing every batch again draws it, the undo the file to the byte;
# the gatehouse's alongside (~2 ms). -- --into=DIR writes
# each edit's file, to cmp against another checkout's. Ends "every check passed".
godot --headless --path . --script src/dev/step_edit_cost_probe.gd
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
# the tab it opens, checks the booklet in it and prints it to booklet.pdf.
# Serve with --parts assets/generated/parts --delay 0 so parts come from this
# checkout. 2026-10-16, SwiftShader at load ~50: the car's booklet in 259 s.
# --model waits until the app says no part is still on its way
# (brickworksState.awaited): 7636's 372 took 146 s, and the old test (the count
# holding between two looks) photographed it at 324. Each frame of it drawn in
# SwiftShader at load 60-90 takes 5-14 s (a key turning the view), so app.png
# waits up to 180 s and is not a check. Its booklet did not arrive in 1,500 s
# here at load 40-90 (--wait=1500): a big model's booklet is for the preview.
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
# View, Stress: a loaded 2x10 cantilever's root red on 1x1s, plain on 2x2s; a
# bare one and a bonded wall not red; nothing painted; the shipped models none
# red. Then in the window: the menu, the tint, what pointing says, Ask Claude
# to brace this only on a weak part, 75969-1 and 21318-1 (one part red at most)
# and Orthanc pictured in shots/stress/ — look at what reads red.
# The panel: the count as weakest_joints says it, the weakest first, each row
# and Next selecting and framing its part, the hotel 0 past working load.
tools/probe.sh stress_probe && tools/probe.sh stress_view_probe && tools/probe.sh stress_list_probe
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
# (also: a crane opened from a file with a motion in its head, rendered from
# Animation framed on what moves: "<model> Turn the turret.webp", 25 frames,
# decoded at 1280x720; tools/release/preview_checks.sh runs it as `render`)
# File, Render's Animation pressed as a person presses it
# (src/dev/motions_render_probe.gd): 1484-1's doors as I see it and framed
# on what moves (every frame, frames that differ where the doors move, the
# sweep filling more of the frame framed on it, the second file numbered),
# All, in order (both motions, the gate closing last, redo kept), Cancel part
# way (nothing kept); 4096-1's boom framed on what moves filling the frame
# against the whole model's box; the same camera, the same places and the
# same pixels within the renderer's own as the panel's Render animation and
# render_motion. Pictures of the dialog at each window size.
tools/probe.sh motions_render_probe bench/results/motions4-2026-10-20
PROBE_SIZE=1280x720 tools/probe.sh motions_render_probe bench/results/motions4-2026-10-20 pictures
# Build, Motions…, a new motion on a crane: the turret's and the arm's
# sliders (Grab's joints), a click on the track a key, stopped short where
# the arm meets the turret and said; keys at 0, 1 and 2 s whose frames, read
# off the renderer's own copy, turn each joint through them; Render
# animation's frames, WebP and MP4
tools/probe.sh pose_probe
# Build, Motions… driven as a person drives it (src/dev/motions_panel_probe.gd):
# 1484-1's doors kept from the suggestion, played and played backwards; a
# gate recorded from a drag in the view, the model put back, one step, and
# played to where the drag left it; a key made linear and one put by a slider,
# undone; Play all and its undo; saved and opened again with the lines back;
# a motion a session defines shown in the open panel. 8808-1's steering kept
# and played both ways through its rack; the steering wheel recorded turns
# the arms when played; only joints that move offered; Render animation.
# The observatory: its copied "Show it all" removed, New sequence (undo, redo),
# Down, Up, Take out and Add each one step and undone, Play (99 frames, every
# part in each) and Play backwards to as built, saved and opened byte for byte.
# Pictures of each state; and again in a 1280 x 720 window.
tools/probe.sh motions_panel_probe -- bench/results/motions5-2026-10-20
PROBE_SIZE=1280x720 tools/probe.sh motions_panel_probe -- bench/results/motions5-2026-10-20
# What the animation audit found broken, on real sets (docs/ANIMATION.md;
# src/dev/animation_probe.gd):
# 31070-1's back window posed out and back stands where it was built, Play
# of a motion on it out and back moves nothing, animate_model on 8808-1's
# steering with the window zoomed far out spans over half its frame and its
# answer carries its frames, the panel then plays and renders the session's
# keys as the motion "Animation",
# Cancel stops a render, a part that meets the model at once is said, and an
# MP4 of 6 frames after one of 12 of the same name is 6 at 12 a second; and
# pose_model marks 8808-1's steering arms as having no room to turn. 15 of
# its 23 checks fail on 32bccfcc.
tools/probe.sh animation_probe
# A model's own motions on real sets (src/dev/motions_probe.gd): 1484-1's
# doors suggested and kept, 8808-1's steering both ways through its rack,
# 4096-1's boom lifted, 8841-1's chassis driven from its steering wheel,
# 31070-1's windscreen stopped and said; each defined over MCP, saved as .mpd
# and opened again with its lines byte for byte, played, reversed, rendered
# (a WebP and an MP4 whose frames move); a door saved open opens no further;
# a part taken off is said; an .ldr, an .io and the autosave carry them.
# The walk's observatory (tests/fixtures/mcpwalk3/small-observatory.ldr) given
# a real "Show it all" sequence: its line byte for byte, played in order and
# backwards to as built, rendered whole, a gone motion passed over and said,
# the AFTER chain still played, the back wall's panels seen best from the back.
# Headless it checks all but the renders.
tools/probe.sh motions_probe
# Every way of recording what moves, walked on five real sets, every answer
# printed and every file kept (src/dev/anim_walk_probe.gd: checks nothing;
# the audit's evidence)
~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/anim_walk_probe.gd -- --into=shots/anim_walk
# The first open of Render in a fresh browser, every frame timed (the engine's
# frame callback, WebGL calls in it, the programs it linked): fails past
# --budget ms (250) for any frame from the press to the draft, of the first
# open and of a second. --programs lists each program linked, by its
# #defines, and the frame it was linked in. A local export, served by it
# (on --port=N if given):
node tools/web/render_open_check.mjs --dir=build/web --out=shots/render_open
# The same on the desktop, on the card (Forward+): every frame from the press
# to the draft under --budget ms (100), both opens, the drafts left as
# shots/render/{first,second}_draft_<renderer>.png. A fresh XDG_DATA_HOME is a machine
# that has never rendered (no shader cache); --at-once presses before the
# panel has made its renderer ready, --during while it is waiting for a touch.
MESA_VK_WSI_DEBUG=sw ~/.claude/claude-core/bin/gpu xvfb-run -a godot --path . --resolution 1400x900 \
    --script src/dev/render_probe.gd -- --first-open
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
- **A shader the engine has never drawn is built four ways at once.** Under
  Compatibility the first draw of a new shader, whatever it is drawn for,
  links its four variants (colour and depth, instanced and not) at the
  default specialisation, none of which a render then uses, and then the
  way it is being drawn; no warming within the open can split that. The
  sweep's first draw was six programs in one frame (four, its depth pass and
  its lit colour pass), the open's slowest, 136-140 ms at loads of 4-8 here
  (2026-10-17); the contact shadow's five in another. So the panel makes its
  renderer ready before it is first opened, while nobody is using the window
  (`RenderDialog._warm_when_idle`, `StudioRender.warm_up`): after it, the
  first open links 6 programs instead of 18, one a frame at most, its
  longest frame 88-91 ms, the draft 3.3 s instead of 3.8-4.3 s, and the
  draft pixel for pixel the same; the 14 programs moved to before the press.
  On the desktop the same warm-up takes the set's first-use shader compiles
  (90-133 ms in the open's first frame on a machine that had never rendered,
  41-66 ms once it had) out of the open: 19 ms, the warm-up's own frame 88 ms
  while nobody was using the window (`render_probe.gd -- --first-open`).
  Pressed before the warm-up (`--at-once`), an open is as it was.
  A second open's longest frame was a read-back, 170-800 ms, two of them
  (`readPixels`, 130-550 ms after the press): its fence had passed, and the
  read waited for the window's frames drawn after it, which GpuFence lets
  draw for half a second after a press to answer it (`GpuFence.ANSWER_MS`).
  `GpuFence.finished` now follows a fence that passes with frames drawn
  after it by another, until one passes with none: the second open's
  longest frame 243-266 ms before (one over 250), 34-42 ms after (three
  runs each, `render_open_check.mjs`, 2026-10-17), the first open's 85-94
  ms either way, both drafts pixel for pixel the same, the second draft
  1.9-2.0 s instead of 1.5 s (its reads wait out the half second). The
  desktop has no fences (`GpuFence.put` is 0) and reads at once: its second
  open 9 frames, the longest 16 ms (`render_probe.gd -- --first-open`).
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
