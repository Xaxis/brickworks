# Building

Pointing at a stud and getting a brick there, selecting several, taking it back.

<!-- covers: scene:main, ui:place and remove, ui:box select, ui:selection outline, cli:selection outline in a browser, ui:selection edits, ui:undo and redo, ui:copy paste and duplicate, ui:move and turn a selection, ui:select by colour part or connection, ui:hide and show only, ui:menus and toolbar, ui:tooltips let clicks through, ui:tool modes, ui:properties panel, ui:status bar, ui:snap and turn step, ui:lock parts, ui:stud grid, ui:tour, ui:remembered layout, ui:assistant on or off, cli:no AI in a browser, ui:replace part, ui:undo history, ui:mirror a selection, ui:place under a part and on side studs, ui:snap onto a joint, ui:swing on a hinge, ui:grab and move on a joint, lib:rigid bodies and joints, lib:moving a body on its joint, cli:grab in a browser, cli:placing probe, cli:placing in a browser, ui:hoses and chains by hand, cli:hoses and chains by hand in a browser, ui:sub-assemblies, ui:model tree, ui:measure, ui:docked panels, ui:what the app is busy with, ui:floor, cli:floor in a browser, cli:build a real set by hand in a browser -->

## Sub-features

- `scene:main`: the one scene. It restores whatever was on the baseplate last
  time, falls back to a sample model, lays the baseplate under it and frames it.
- `place and remove`: as BrickLink Studio does it (2026-10-11; the owner: "it's
  super awkward to switch between selecting a placed piece and placing a new
  piece"). Select is where the app rests, with nothing in hand: a click on a
  part selects it, a **drag** on a part moves it on the studs, `Ctrl`-drag
  copies it, a drag on empty space boxes, `Alt`-click (or `G`) takes that part
  into hand. Choosing a part in the bin, or `Q` for the last one, puts it in
  hand: its ghost follows the pointer and each click puts one down, staying in
  hand for the next as Studio's "repeat inserting" does by default. `Esc` or a
  right click lets go, back to Select, leaving nothing behind. Taking a part off
  is `Delete` (or the Delete tool). At rest, a right click on a part (not a
  right drag, which turns the view) selects it, unless it is in the selection
  already, and opens its menu (`Shell.open_context`): Select everything joined
  to it, Hide, Show only the selection, Paint with the colour in hand (named),
  Copy, Delete, Make a sub-assembly…, Properties, each Edit's or Build's own
  command, greyed where it would do nothing. It did nothing (2026-10-12). The mode is always on the toolbar (Select or Place lit, Place's
  tooltip naming the part), in the status bar's hint and in the pointer.
  `tools/web/controls_flow.mjs` counts a person's first tasks in clicks and keys
  on a build, the old way (`--recipe=old`) or this one.
- `box select`: `Ctrl`-drag (`Cmd` on a Mac) from empty space, and every brick
  whose screen position falls inside the box is selected (Shift adds to the
  selection). A plain drag there turns the view instead (`left-button
  navigation`). Releasing over a panel still ends the box.
- `selection outline` (`src/render/selection_outline.gd`): what is selected has
  one yellow line round its silhouette, as Studio, Fusion and Onshape draw it,
  2.5 points wide (twice the pixels at 2x), over whatever hides it so a
  selection is never lost; with Select in hand, the part a click would take
  (its whole sub-assembly or figure) has a paler, finer blue line while the
  pointer is on it, and the share viewer outlines the part it names the same way.
  It was a box round every brick: a chain of 29 links came out as a yellow
  scribble over the links (live, 2026-10-12). Drawn by the window, not in the
  world: the selected parts go again, plain white, into a mask (a SubViewport
  with a world of its own, looking through the view's own camera, attached by
  `RenderingServer.viewport_attach_camera`, so a lens that shifts its frustum
  is followed for free), then two passes over the selection's rectangle on
  screen find each pixel's distance to the mask, along its row then down its
  column (`outline_rows.gdshader`, `outline_line.gdshader`). Follows the cut-away
  (what is cut off is not outlined, unless the cut leaves ghosts) and x-ray;
  never in a picture, render or booklet, which draw the world in viewports of
  their own. `outline_probe` asks the picture: one brick, a chain alone and on
  its gears, Gandalf and Saruman on Orthanc, all 9,429 of Orthanc (a frame within
  twice the bare one, nothing drawn standing still; then nothing selected, the
  window-sized targets let go of at once and no frame drawn for it after), a
  guard cut through and in x-ray, and the hover — what selecting changed must lie round the parts, not
  over them, and go all the way round. Run it at `--resolution 2800x1800 --
  --tag=2x` for a 2x screen. `tools/web/outline_check.mjs` is the browser's
  picture at 1x and 2x, and its frames standing still; before the picture it
  leaves the page 6 s (`--idle`) with no input and looks at the selection
  four times a second, which nothing but input may take away. It failed on
  the live site with the selection there all along: the parts bin's
  read-backs held the drawing (`GpuFence`) and the picture was of the frame
  before the click; a person's input is now drawn through the hold. The mask and the
  passes are drawn again only when the selection, the lens, the cut or the
  window changed, and the overlay otherwise lays the line it has; the mask is
  depth-tested, so a fragment behind more of the selection is not drawn. A
  selection of over 100,000 triangles (`MOST_WHILE_MOVING`), and in a
  software renderer any selection, has its line put away while the view
  moves and drawn again once it rests. All of Orthanc outlined made every
  frame several times dearer in a browser drawing in software, the progress
  bar's too: a frame 8 s, Mirror's bar 11.4 s to appear (2026-10-13). A
  batch of the world's whose every part is selected goes into the mask as the
  world's own MultiMesh (`BrickWorld.drawn_as`), not copied a part at a time.
  `outline_cost_probe` times it by the processor (a busy machine stretches
  the clock, not that): with all of Orthanc selected a frame with the view
  still within a twentieth of the bare one and turning within a tenth, and
  the line back each time the view rests. Measured under heavy on llvmpipe:
  still 6,090 ms against 5,532 bare before, 5,832 against 5,600 after;
  turning 6,098 against 5,498 before, 5,925 against 5,735 after. In Chromium
  on SwiftShader the browser's processor time for a frame where only the
  interface changed, all of Orthanc selected: 150 to 290 s before, 9 to 18 s
  after, against 5 to 10 s with nothing selected.
- `selection edits`: with bricks selected, `C` paints them the current colour
  (so does a colour clicked in the palette, see [parts](parts.md)'s `palette`),
  the arrow keys and W A S D move them across the ground by the snap, Page Up
  and Down raise and lower them, `R` turns them by the turn step and `T` tips
  them over, `Delete` or `Backspace` removes them. `shift-click` or `Ctrl`-click
  adds to the selection; `G` takes the part under the pointer into hand, `X`
  lifts it off into hand.
- `undo and redo`: `Cmd/Ctrl-Z` and `Cmd/Ctrl-Shift-Z`, over placements, removals,
  paints, nudges and whole assistant designs. Each says in the status line what
  it took back or put back ("undid: made the sub-assembly Body of 2 parts"),
  the keys and Edit's Undo alike (`EditVerbs.press`, `Builder.redo_words`): it
  said nothing, and undoing a sub-assembly made changes nothing on screen. Undo belongs to the model it was
  recorded against: open a different model and the stack goes with the old one,
  and so does the selection (its ids would name the new model's bricks).
  On a big model an undo or redo is the parts' own work and nothing more: a
  part moved by whole cells (a nudge, its undo and redo) has its lattice cover
  moved (`BrickLattice.shift`, `occupy_moved`), not worked out again from the
  part, and a part taken off carries its cover in the step for the undo that
  puts it back; the step an undo or redo leaves newest is `Builder.settled`,
  so `Assemblies.after_edit` does not match every sub-model copy again.
  42082-1 (4,139 parts here): Ctrl-A, D, Ctrl-Z took 2.8 s and Ctrl-Shift-Z
  6.8 s headless, now 0.5 s each; the move 12.6 s, now 1.4 s (`bigmodel`
  probe; docs/CADTASK.md). A part shifted by whole cells leaves only the
  buckets it no longer reaches and joins only the new ones
  (`BrickLattice._rebucket`); the probe checks every part's cover against its
  part's own after the moves.
- `the ghost`: the part about to go down is drawn in its own colour, shaded,
  translucent; refused, it is red and striped (`src/render/ghost.gdshader`). It
  was 55% green, so a green brick's ghost and the colour about to be placed
  could not be told apart.
- `copy paste and duplicate` (`src/assembly/carry.gd`): `Ctrl-C` copies the
  selection, `Ctrl-V` holds a copy as one ghost, `Ctrl-D` holds a copy of the
  selection without touching the clipboard, `Ctrl-X` cuts. A click puts it down
  as one step and selects it; `R` turns it; `Esc` puts it away. The group's frame
  is a stud centre or corner at its bottom, so whole-stud moves and quarter turns
  keep every part on the studs; it drops onto whatever is highest under any of
  its parts, and a side face pushes it out until its edge meets the face. Copy
  also writes LDraw lines to the system clipboard (where they were in the model),
  and LDraw another program put there pastes in.
- `move and turn a selection`: `X` with a selection picks it up to follow the
  pointer; a click puts it down (lifting and putting down are one undo); `Esc`
  puts it back. `R` / `Shift-R` turn a selection where it stands, about the
  same point each time, so four turns come back exactly.
- `select by colour part or connection` (`src/assembly/select_by.gd`): the
  toolbar's Select by (and Edit, Select by) takes the same colour, the same part, both, everything
  joined by studs (a brick beside another is not joined; a sideways part is
  across its stud axis), the opposite, all, none. The baseplate is never taken.
- `hide and show only`: `Ctrl-H` hides the selection (`H` alone is the Pan
  tool), `Shift-H` hides everything else, `Alt-H` (or `Ctrl-H` with nothing
  selected) shows all, and the status line names those keys. Hidden parts are not
  drawn, the pointer passes through them (`BrickLattice.unseen`) and boxes and
  `Ctrl-A` skip them, but they still take up their room. The timeline's end
  puts them back hidden.
- `menus and toolbar` (`src/ui/shell.gd`, `src/ui/toolbar.gd`): the bar across
  the top holds File, Edit, View, Build, Tools and Help, the model's name and
  Account; every command is defined once in `Shell._define` with its words, its
  key (shown beside it in the menu, never answered by the menu: the keys stay
  the app's own) and whether it can be used now — greyed when not, ticked when
  it is a setting that is on. File: New, Open, Open recent, Import (LDraw,
  Studio `.io`; LDD `.lxf` greyed, not yet), Save, Save as, Export, Render…
  (see [view](view.md)), Instructions, Clear, Account, Quit. The toolbar under it: New/Open/Save, Undo/Redo/History,
  the tools, Copy/Paste/Mirror/Select by/Show all, snap and turn step, grid,
  orthographic, fit and three views, Measure, Properties, Timeline,
  Instructions, Render, Parts list — each tooltip its name, key and what it does.
  Narrower than it needs, it folds its least-needed groups (all in the menus
  too); on a phone the file, history and tools stay.
  One name, one command: Edit's Cut is `cut_parts` and the cut-away (`K`) is
  `cut`, which had replaced it, so Edit, Cut sliced the model open
  (`Shell._add` now refuses a second command of a name).
  A key is shown as the binding a press really reaches, written as a person
  writes it (`Shell.key_text`: Shift+Q turns the model, `` ` `` is
  orthographic, `,` Settings; never the engine's "QuoteLeft" or "Comma"). The
  menus can only draw the engine's name for a key, so one it misnames is
  handed the character it then draws (`Shell.menu_accel`).
- `tool modes` (`EditVerbs.mode`): Select (the default) and Place (a part in
  hand), and Move, Rotate, Hinge, Clone, Paint, Hide, Delete — a click on a part
  does that tool's one thing to it, or to the whole selection when the part is
  in it (`EditVerbs.click`). The tool in use is lit on the toolbar and ticked
  in Tools. Only Place shows the ghost; a part carried by a drag, Move or Clone
  shows its own. `V` is Select, `Q` Place; `Esc` closes whatever is up and goes
  back to Select with nothing in hand, in one press.
- `properties panel` (`src/ui/inspector.gd`): in the left-hand column, under
  the parts bin and the model tree and over the colours (`docked panels`);
  View, Properties with the column folded opens it with them. Nothing
  selected, it is its header alone ("nothing selected", `Inspector.is_idle`)
  and the parts grid has its room: an empty Properties took 200 px of the
  column at 1440 x 900, and the grid had room for two rows (2026-10-12). One part: its name, LDraw and BrickLink numbers, its colour by
  LDraw's name and code, LEGO's name and number, BrickLink's and Rebrickable's;
  X, Y, Z in LDU and its turn in degrees, typed over or stepped to move or turn
  it (refused and put back where there is no room); what it is joined to,
  which way its studs face, its sub-model, its step in the instructions (models
  of 600 parts or fewer) and whether it is locked; Joined, Lock, Hide. Several:
  how many of what, the colours, the size in studs and bricks, the group's
  corner to type over. Folds to its header; scrolls when the column gives it
  less room than it needs.
- `docked panels` (`src/ui/panel_stack.gd`, `Main._fit_panels`): the left
  column holds everything for building by hand, the parts bin with the model
  tree, the properties and the colours under it (`PanelStack`), as Studio
  keeps its palettes down the left with the colours at the foot, and Blender
  stacks its outliner over its properties. The colours are as tall as the
  column says (`PartsBin._fit_palette`: 14% of it, two category rows from a
  700-unit column), so a part taken into hand, a brick selected or the tree
  opened moves the parts grid's foot and never the palette; the grid takes
  the rest — four rows and more at 1440 x 900 with nothing selected, where it
  had two; the right column is the assistant's alone. (Stacked over the
  assistant they would not fit: waiting for a key it asks for 783 units of a
  laptop column's 666 to 883.) The tree and the properties fold to their
  headers (the tree starts folded) and the bar between two drags the height
  of the one that is not the bin; the bin has the rest. The model's part of
  the window is what is left, with nothing over it but the view cube: the
  tree and the properties floated over its top corners, where clicks meant
  for a part landed on them, and at 1100 x 700 they left no room to build.
  The sub-assembly banner and the offer to seat old parts are in a strip above
  the model (`Main._notices`), not over it. Below 1600 units across (every
  laptop: 1100 x 700, 1280 x 720, 1440 x 900 at any density) the columns take
  turns: opening one folds the other (`Main._column_opening`) and the model
  keeps over 60% of the width. A first visit shows the assistant, the parts
  bin folded to its rail (`narrow_side` "assistant": designing with Claude is
  what the landing page sends people in for); a person who switches keeps
  their choice, and a part put in hand (Q, the bin, the eyedropper) brings
  the bin out (`Main._bring_out_bin`). On a phone they are drawers, as
  before, and nothing brings one out over the model. Each rail carries its
  icon and its name ("Parts", "Assistant"), tinted with the accent down its
  edge while folded, and switching is one click on it. A folded column's
  content is hidden, not clipped: its fields cannot take the keys and the
  page is not told its buttons are there. The 3D view is centred on the
  model's part of the window, and glides over as a column folds or opens
  ([view](view.md)'s `centred on the model's column`).
  `Main.model_cover()` samples a 12 x 8 grid over the model and says
  what a click at each point would reach instead (the app's own list of
  panels, and any control on any canvas layer that takes the mouse);
  `assembly_probe` and `handbuild_probe` call it, and
  `tools/web/fit_check.mjs` reads it on the page (`window.brickworksLayout`,
  asked for with `brickworksAskLayout`). From a build that publishes only
  centres it works the model's rectangle out from the rails and the toolbar,
  so it fails on a build with floating panels.
- `tooltips let clicks through` (`src/ui/tooltips.gd`, `Tooltips.let_clicks_through`,
  2026-10-15): a tooltip never takes a click meant for what is under it. Godot's
  tooltip is a window of its own embedded in the app's, and a pointer on it is
  over it, not over the button below, which then ignores the press; a plain one
  closes when the pointer enters it, but only at the end of the frame, so a move
  and a click in one frame (Playwright's, or a quick hand on the web) found it
  there, and a press on one over a dialog or a menu took the window's focus, which
  closes a menu. Account's Open in Claude over Disconnect Claude was the case found
  (oauth_flow). Every press, and a pointer moving onto one, now closes it before
  the window routes the event (`Window.window_input`, which comes first). Proves
  it: `tooltip_probe` (windowed, the real scene): a link with a tooltip stacked
  over a button, the button clicked through the tooltip moved-then-clicked and in
  one go, the same in a dialog and a menu, then every panel a person opens (the
  window, Properties, the assistant, Account, Settings, Render) rested on control
  by control, a click through each tooltip that covers something clickable caught
  at that control with the pointer over it, and the menus' rows that cover the row
  under them said. Fails on b79d427: the click in one go pressed nothing.
- `status bar` (`src/ui/status_bar.gd`): along the foot. What was just said, or
  the tool's hint when nothing was; then the parts count and stability, how
  many are selected, the snap and turn step, and how big a stud is on screen.
- `what the app is busy with` (`src/ui/working.gd`, `Working`, 2026-10-12): the
  one progress pattern for every slow thing, at the left of the status bar in
  place of the hint while it lasts — the words ("Laying out 9,429 parts in
  steps… 3,200 of 9,429"), a bar that fills where the work is counted and a
  block that runs along it where it is not, and Cancel where stopping makes
  sense; gone when it is done. The owner asked for it after pressing Timeline
  on a big model and seeing nothing for seconds. Work reports to a
  `Working.Job` (`begin`, `say`, `count`, `due`/`next` for FramePace slices,
  `shown`, `end`; a probe or the command line has a job and no bar); the bar
  is brought up to date at most every 250 ms, and on the web not again until
  the card has drawn its last change (`GpuFence.put`/`passed`, the fence the
  picture reads wait on), since every frame drawn draws the model too: in a
  browser drawing in software over Orthanc, redrawn every 250 ms regardless,
  the frames queued up behind each other and the timeline took 77 s instead
  of 8, and the booklet's first part picture waited 17 s for them. `shown()` waits for a frame to be
  drawn, not for the next process_frame: a press is handled before its
  frame's processing, so that is the same frame, still to be drawn. Reporting now: Timeline (`StepsBar.start`, worked out by
  `Instructions.plan_paced`, Cancel or Timeline again stops it, and an edit
  meanwhile does), Instructions (`BookletMaker.job`: planning, the parts, the
  views, the steps, counted, with Cancel, and the line also in the tab the
  booklet goes to on the web), LEGO Art's Build (`MosaicArt.put_down_paced`),
  Brickify (beside its panel's own line; its spinning preview stands still
  while it works and on the web turns only once the card has drawn the last
  turn, so it queues no frames ahead of the bar — though the bar still waits
  for whatever else the card has in hand, a picture being read among it:
  125 ms and 4.9 s in two runs, 4.3 s before, 2026-10-13), opening a model (from a file, Open's list or Recent,
  `ModelBar.open_with_progress`), one long frame, said first. Put down a
  slice at a time with the bar counting, Orthanc's open in a browser
  drawing in software took 15.7 s against 3.7 s in one frame, with the
  page's state told only every two seconds (it was 15.9 s without that, so
  that was not it), and 8.8 s in slices of a tenth of a second (2026-10-13):
  every frame given back cost more than the work done in it, so it is one
  frame again, and a delete, undo, redo,
  New or Clear of 300 parts or more (`EditVerbs.BIG_CHANGE`), one long frame
  each, said first. Made a slice at a time, a delete of all of Orthanc in a
  browser drawing in software took 231 s instead of 1.2 and its undo 19 s
  instead of 2.3, with an 8 s frame after the delete not yet explained;
  each slice changed what is on screen, the selection's outline among it,
  which is the likeliest cost (2026-10-12), so they are one frame again. Not the parts bin's pictures: their tiles say they are
  coming, and a line as well came and went with every scroll and drew the
  window again each time; each is read back after the card's fence instead
  (`PartThumbnails._render`), which took the bin's first open from eight
  seconds of the page held to half a second. In the shared model's viewer
  the status bar is hidden except while there is work (`StatusBar.only_the_work`).
  The page reads it as `brickworksState.working` and `window.brickworksWork`
  (when each job was first drawn and when it ended, in the page's clock), and
  Cancel as `brickworksControls.work_cancel`. Proves it: `progress_probe`
  (windowed, Orthanc and the car: the bar up in the frame pressed, before the
  work; the timeline's longest frame against 200 ms; the sub-assembly
  search's longest frame of its own, process to drawing, against 100 ms,
  judged in software too (one frame of 161 ms on b79d427: `_find_assemblies`,
  `_contract` and its loop walk `_cycles` are a slice at a time now, and the
  flexible things' search `_find_bundles` too, 120 ms to 58 ms windowed on
  2026-10-16); the same steps as
  `Instructions.plan`; Cancel and a second press stop it; Open's list says
  "Opening…" before Orthanc lands; delete all and undo say so first; Check
  stability and Everything connected through `Shell.run` on Orthanc, and
  Everything connected as the properties panel hands it to `Shell.attend`,
  the bar up every frame until their work is done, the cost kept for them
  at least as long as the work was seen going, and no "async function
  without await" caught from the engine (an `OS.add_logger` Logger); the
  car's booklet counted and stoppable) and
  `tools/web/progress_check.mjs` ([web](web.md)).
  Every command, too, without asking (2026-10-13, the owner: "when I clicked
  'Save and then new' it seemingly froze the app … for probably all actions
  comprehensively"): `Shell.run` (the menus, the toolbar, the context menu),
  every key that is a command's shortcut (`Main._unhandled_key_input` →
  `Shell.command_for_key`), and the dialogs' and the properties panel's
  buttons (`Shell.attend`, `ModelBar.attend`) go through `Working.attend`.
  It keeps what each command cost by how much it had to do (`Shell.work_size`:
  the selection for one that works on it, what is in hand for Paste, else
  the model's parts, in sizes going up by fours), kept between visits in
  `user://command_costs.json` (not read or written under `--script`); one
  known to be slow — the least of its last and its average cost over
  `SAY_FIRST_MS` (150), or `Shell.SLOW_FROM` before it has ever run — has
  the bar up with its own words (`Shell.DOING`: "Saving…", "Mirroring…")
  and drawn before it runs, the frame after. `SLOW_FROM` was swept on
  Orthanc with `command_probe --judge` (2026-10-15): every command holding a
  frame a fifth of a second or more there unsaid is in it (Versions, the
  cut-away by axis, Make a sub-assembly, Same sub-model, Copy, Settings and
  Keys, Print on a part, the tour, the picture), and the minifigure builder
  and What do I need? from nothing, since they cost the same on the car (415
  and 385 ms). A command that goes on after
  it returns (a coroutine) is awaited to its end (`Working._Going`, called
  without await so only what it does before its first await counts as
  inside it), its cost timed to that end, and when it goes on more than two
  frames with no job of its own its words are on the bar until then. Every
  command's work awaits what it sets going (the menu lambdas, `_key_pressed`,
  `_save_named`, `ask_for_new`; the exports and Timeline call their work
  straight off rather than through a signal). Until 2026-10-13 it took a
  coroutine's result without await and looked for its
  GDScriptFunctionState, as Godot 3 did, so every async command (Check
  stability, Save of a big model, Everything connected) was timed only to
  its first await; and a debug build stops a caller that takes it with
  "Trying to call an async function without await", so there `Shell.run`
  took every one for finished at once, and one handed straight to
  `Working.attend` (a dialog's button, the properties panel's) stopped
  `Working.attend` itself, leaving every later command taken for one inside
  it. A command a browser only lets happen inside the press (a file dialog,
  full screen, a page) is never put off (`Shell.IN_THE_PRESS`).
  Save, the exports and Share work out a big model's build order a slice at
  a time (`ModelStore.to_text_paced`, `text_for_file`, `save_as_paced`,
  `export_paced`; `ModelBar._on_save` returns whether it saved), with
  Cancel; "Save, then start new" starts new only once the save is made.
  The audit is `src/dev/command_probe.gd` (windowed or headless; `--judge`
  fails a command over 250 ms of its own work in one frame that was not
  said first): every command in the shell's table on Orthanc and the car,
  the selection everything where one is needed, undone after, its exports
  into `user://command_probe_downloads` (`Download.folder`), never
  Downloads. It found, on Orthanc on the desktop: taking all of it off
  (Delete, Cut) a minute on one frame, because every part removed ran the
  whole model's after-edit work (`Main._edited_soon` now runs it once a
  frame); Same colour, Same part, Same part and colour over a minute each
  with all of it selected, asked part by part (`SelectBy.matching_any`);
  Everything connected 14 s (`EditVerbs.select_connected`, paced, with
  Cancel; the properties panel counts the joined parts up to 500,
  `Inspector.JOINED_MOST`, since every click on one part of Orthanc counted
  all 9,428); and Save 2.7 s with its build order on one frame. Writing a
  file sorts by a key the engine compares and writes whole numbers straight
  off (`ModelStore._in_file_order`, `LdrModel._line_numbers`): the same
  bytes, checked on car, castle, Orthanc, house and station, Orthanc's
  text in 300 ms instead of 390. In Chromium on SwiftShader on a loaded box
  (`progress_check.mjs`, Orthanc): Save held the page 3.3 s with nothing on
  screen, and now has the bar up in 100 ms and holds it 0.9 s at most; "Save,
  then start new" the same, 139 ms and 0.9 s; Delete of all of it 130 s,
  now 1.3 s; Mirror of all of it 125 s, now 20 s, most of it drawing all of
  Orthanc outlined as selected (an 8 s frame in software, which also holds
  the bar back: the selection outline's cost, not the command's); Shift-E
  4.6 s unsaid, now said in 69 ms.
- `snap and turn step`: the toolbar's Snap (stud, ½ stud, ½ plate, free) sets
  where a part in hand or a carried group can land across the ground
  (`Builder.snap_across`) and how far the arrows nudge a selection across and,
  with Shift, up (20/8, 10/8, 10/4, 2/2 LDU). Turn (90°, 45°, 15°, 5°) is how far
  `R` and the Rotate tool turn a selection (`Builder.turn_selection_by`; off a
  right angle the parts stand off the grid as turned covers). The part in hand
  turns a quarter on the studs; on a round joint 45°, or the turn step if
  finer (`snap onto a joint`).
- `lock parts`: `L` (Edit, Lock the selection) locks it: no click, box,
  select-by, tool, paint or removal touches it until `Shift-L` unlocks
  everything (`Builder.locked`). Not saved with the model; Open forgets it.
- `stud grid` (`src/ui/stud_grid.gd`): View, Stud grid, or the grid button:
  lines between the baseplate's studs, every fourth brighter; with no
  baseplate, over the ground the floor covers (`FloorLayer.area`).
- `floor` (`src/render/floor_layer.gd`, `src/parts/model_floor.gd`): what the
  model stands on, per model. View, Floor: Baseplate 16, 32 or 48 square, or
  any size in eights (Baseplate, other size…, cut into the baseplates LDraw
  has: 24 x 24 is a 3334 and a 3497), in a colour baseplates come in
  (Baseplate colour); Grid floor (no plate: a faint ground with a line
  between every stud); No floor. With no plate the model's shadow still falls
  on the ground (`floor_shadow.gdshader`: a quad at y = 0 lit by the sun alone,
  in the grey of the view's background where the sun reaches it — its own
  grey under Forward+ (`FloorLayer.LINEAR_SHADOW_TINT`), as the web's
  Compatibility grey drew a pale disc on a GPU — faded out
  round the model as far as its shadow goes, refitted as it grows by
  `FloorLayer.follow`), so a part on nothing does not float; on the grid
  floor the grid's own ground takes it, lit by the sun alone. `floor_probe`
  compares the view with and without what takes the shadow (the pair in
  `shots/floor/shadow_<floor>_with.png`, `_without.png`), on the GPU under
  `gpu` as the suite runs it and in software for the web's renderer, and
  `idle_check --floor=none` that it costs no frame standing still. Godot's
  shadow to opacity drew nothing in the Compatibility renderer. The same in the properties with nothing
  selected (`FloorPicker`, two rows under the header), and Settings, New
  models start on (`ShellPrefs` `new_floor`; also View, Floor, Start new
  models on this floor). Each choice is one undo (`Builder` step `floor`) and
  nothing built moves; plates are centred on the model and tiled to cover it,
  as the one 32 x 32 always was. A baseplate is scenery (`ModelStore.scenery`):
  not saved, not counted. The baseplate is part of the model (View, Floor, or
  Part of the model in the properties) makes it a real part — counted in the
  parts list and shop lists, saved, step 1 of the booklet, in a shared link's
  count — and back, one undo each (`Builder` step `scenery`), nothing moving. A
  model with a baseplate of its own lying at the ground (`FloorLayer.own_plates`,
  a set opened from elsewhere) gets no plate laid under it, and is not lifted by
  its plate's thickness on open (`ModelStore.lift_for`); deleting the model's
  own plate brings the floor's back, and undoing that takes it away. With no
  plate a part aimed at nothing falls to the ground at y = 0 and settles on the
  same studs, so the first part lands exactly where it would on a plate; the
  box, Fit, the cut-away and stability all work against the ground. Saved as
  `0 !BRICKWORKS FLOOR BASEPLATE 32 32 288` / `GRID` / `NONE` in the head of
  the model (`ModelFloor.written_into`), in the autosave, saves, LDraw and
  Studio exports and shared links; a file that says nothing gets the floor new
  models start on. Pictures are of the model: renders, Export picture, the
  share card, the Studio thumbnail, the booklet and the designer's own pictures
  show a baseplate only when it is part of the model (it is in the box), on the
  studio's clean floor otherwise, and never the grid or the shadow's ground;
  the view keeps the floor as chosen. `floor_probe` draws the example car on
  the default floor, with its plate made part of it, and on no floor. The designer chooses
  (`submit_design` `floor`, `floor_colour`): none for a vehicle, a baseplate
  in its ground's colour for a scene, made part of the build when the design
  is done, and says so in the chat.
- `tour` (`src/ui/tour.gd`): Help, Take the tour: eight cards, each lighting a
  part of the window (menus, toolbar, parts bin, the model, properties, status
  bar, assistant) with the rest dimmed; Next/Back or the arrows, Esc leaves.
  Seven with the assistant off: its card goes with it.
- `assistant on or off` (`src/ui/controls_dialog.gd`, `ShellPrefs.assistant_shown`,
  `Main.set_assistant`): Tools, Settings…, **Assistant (AI)**: "Build by hand
  only" or "Show the assistant", kept on this device (`assistant` in
  `user://shell.cfg`). Off, nothing of AI is anywhere in the window: no
  assistant column or rail (its key form, Sketch first and the connector's
  switch are in it), no Ask Claude in Edit or on a part and Ctrl+K does
  nothing, no View, Assistant or Tools, Claude connector…, no brief or Design
  with Claude in Brick Art, no Claude in Account, the sign-in screen, My
  collection or About, and the tour without its card. The connector is held
  off (`ClaudeConnector.hold`): nothing switches it on, a sign-in or a
  connection to the account included, and Settings says "Claude connections
  are off while the assistant is off". On again, all of it is back and the
  connector as it was; its column opens, since it was asked for. A first visit
  builds by hand (a builder on Reddit, 2026-10-13: "a LOT of us… building
  freely and building things that are not AI designed"), with one button along
  the top of the model, "Show the assistant", shown once: one press does what
  Settings does. Anyone who comes for the assistant or the connector reaches
  it in one step: `/app?assistant=on` (`--assistant=on` on the desktop,
  `Main._assistant_from_address`) turns it on and remembers it before
  anything is built, opens its column, and takes the parameter off the
  address with `history.replaceState`; the site's links about Claude and the
  connector use it. Claude at a connector whose tab is not open, or whose
  assistant is off, is told by the relay (`api/mcp.js` `NOT_OPEN`,
  `notOpenFor`) how to turn it on: "Settings, Assistant, or open
  brickworks.diy/app?assistant=on". A device that has used Claude before (its
  key, its connector or its choice of model kept on it) keeps the assistant
  until someone chooses. A probe is a first visit and sees the button only
  with `offer_for_probe`; a probe about the assistant's own panel turns it on
  (`set_assistant(true)`). The desktop's `--mcp` port is asked for on the
  command line and is not held.
- `remembered layout` (`src/ui/shell_prefs.gd`): the columns open or folded
  (`parts_open`, `assistant_open` for a wide window; `narrow_side`, "parts" or
  "assistant", for which one a narrow window shows; a first visit opens on the
  parts, the assistant folded until asked for), the model tree and the
  properties folded and their heights in the column (`tree_height`,
  `properties_height`), the key
  strip, the grid, the snap and the turn step are kept in `user://shell.cfg`
  and come back next time; a narrow window shows one column without
  forgetting how a wide one had them. Not read or written under
  `--script`, so a probe neither sees nor changes anyone's layout.
- `replace part`: Edit, Replace with the part in hand swaps every selected part for the part in hand, each
  in its own colour, centred on the stud grid for its own footprint and standing
  where the old one stood. One step; a part with no room is left.
- `undo history`: History (on the toolbar, and Edit, History) lists the steps in words, newest first ("swapped 2
  parts for Brick 2 x 3", "painted 2 parts"); choosing one goes back to before
  it (`Builder.undo_steps`).
- `mirror a selection` (`src/assembly/mirror.gd`): `Shift-M` or Edit, Mirror makes the
  selection its mirror image left to right as the view sees it, in place, one
  step. A reflection is not something plastic can do, so each part goes where
  its reflection would and is turned to look reflected; a handed part (a
  "Left"/"Right" in its name, a wing or wedge plate) becomes its other hand.
- `measure`: `U` (or Measure on the toolbar) takes out a ruler (`src/ui/measure.gd`):
  click a point, then another, and the label over the model says the
  distance in millimetres and across each axis in studs and plates; points
  snap to half a stud across and a cell up. While it is out a click places
  nothing; the right and middle buttons still turn the view; `U` or `Esc` puts
  it away.
- `sub-assemblies`: `Ctrl-G` (Edit or Build, Make a sub-assembly) asks for a
  name and makes the selection a sub-assembly inside the one being edited; a
  click with Select then takes all of it, and every move, turn, hinge, copy,
  mirror, hide and lock takes it whole. A double-click (or `Enter`) edits inside
  it — a banner over the model says which, a click takes one part, a part put
  down goes into it — and `Esc` steps out a level. `Ctrl-D`/`Ctrl-C` of one is
  another copy of the same definition (`Wing#2`), and after any edit the other
  copies are built again from the edited one, mirrored where they were
  mirrored, in the same undo step (`Assemblies.after_edit`, matched by
  `best_match`). An assembly every part of which the edit moved alike (all of
  it nudged or turned) is the shape it was, and its copies are left alone; an
  undo or redo brings its copies' steps with it and builds none again. The
  pass reads the model once (`Assemblies._begin_pass`), not once an assembly. Make unique cuts a copy loose (a session's `make_unique`,
by the copy's path, name or a part in it: `EditVerbs.make_unique(path)`); `F2` renames a definition in
  every copy; `Ctrl-Shift-G` takes one apart a level. The tree is nothing but
  each brick's `unit` path (`"Plane#1/Wing#2"`), the booklet's interface too,
  so undo, save and the timeline carry it. Saved, it is a nested `.mpd`: each
  definition once, each copy a `1` line, a mirrored copy by a reflecting matrix
  (`LdrModel.write_tree`), each with `0 !BRICKWORKS COPY n` before it, as
  the file is in build order and copies read back by their place in it swapped
  (`LdrModel.COPY_META`); read back, a mirrored reference is put in the other
  hand (`Assemblies.unmirror`). Probe: `assembly_probe` (windowed), which saves
  as Save does (with the steps) and finds each copy the one it was, and also
  opens `vendor/omr`'s 31037 and finds its two propellers as two copies.
- `model tree`: under the parts bin in the left-hand column (View, Model
  tree, or its header) lists the
  model and its sub-assemblies inside one another with their part counts. A
  row selects its parts, a double-click edits inside it, `F2` renames it in
  place, its eye and lock hide and lock it whole, and dragging a row onto
  another nests it there (onto Model, back to the top). Folded or open as it
  was left (`outliner_open`). Probe: `assembly_probe`.
- `swing on a hinge`: `J` / `Shift-J` (or the Hinge tool) turns the
  selection 15° about the joint it hangs from — a hinge's pin, a clip on a
  bar, a turntable's disc: a shaft of a selected part in a bore of an
  unselected one (`Joints.rounds`). It may press only on the part it is joined
  to; anything else refuses it. The parts stand off the grid afterwards, held
  as turned covers (`Builder.swing_selection`).
- `grab and move on a joint` (`src/ui/grab_drag.gd` over `src/assembly/grab.gd`;
  owner, 2026-10-17): with the Select tool a drag on a part that hangs on a
  joint moves its whole rigid body and everything beyond it about that joint,
  as the real thing moves; no tool or panel first. A click still selects; a
  drag on a part held rigidly to what stays still carries it (`EditVerbs.
  drag_start`), as does Ctrl's copy-drag and a locked part. Turn: a hinge, a
  clip, a turntable, a pin or an axle in a round hole, a 1x1 part on one stud;
  a click hinge on 22.5° clicks. Slide: a drag along the line of a clip on a
  bar or a hole on an axle (the first few pixels decide). Ball: every way.
  It stops at the last angle the lattice has room for (`Grab.turn_to`
  bisects). A gear drives its train by the teeth (`Mechanism`, as Simulate). A
  closed loop or a locked train is said, not moved. While dragging the model
  is drawn moved (`BrickWorld.set_drawn`; revision, lattice and history
  untouched), weighed each 50 ms (`Balance.weigh_pose`): polygon and centre of
  mass on the floor, loaded stud joints tinted, the model leaning 4° when it
  would tip, a status line. Let go: a joint without friction (a pin without
  ridges, an axle, a turntable) swings down under its weight (`Grab.settle`),
  one undo step ("turned the arm, 2 parts, on its hinge to 45°"), and the
  status bar says how it stands. Escape puts it back. Past 40 moving parts a
  frame's room test stops at 10 ms and the rest is checked on pauses and at
  the release (`Grab.verify_step`, "checked when you pause"); a press on a
  big model before its joints are read says so. Over MCP: `move_part`.
  Headless gear check without a pointer: `grab_probe -- --gears` (8020's
  crank turns the sails 1 in 9).
  Probe: `grab_probe` (real sets, simulated pointer events); browser:
  `tools/web/grab_flow.mjs`.
- `rigid bodies and joints` (`src/assembly/bodies.gd`): the model as rigid
  bodies (two studs or more, an axle in an axle hole, glue: one body; two
  joints on different lines between two bodies: one body) and the joints
  between them, from `Joints`' rules (studs_in, through, rounds, balls,
  held_otherwise). Resting with no stud in it holds nothing; resting on a
  joint's half with its studs under the foot is carried by it (a hinge brick
  on a turntable's top). A joint between two parts overrides their shared
  studs and cells (turntable top and base, hinge halves, click halves); a
  tyre is one with its wheel; a lone pin is part of the first thing it is in.
  Each piece's anchor: a locked part's body, else what stands on the
  baseplate (a stud in a socket), else the heaviest body. Read ahead once a
  revision, on a worker from 300 parts (`GrabDrag._ready_ahead`).
  `grab_probe -- --survey FILE` prints the bodies and joints.
- `moving a body on its joint` (`src/assembly/grab.gd`, `Grab`): one grab's
  state, pure until `commit`: `begin` (what moves, on what, or "rigid",
  "loop", "locked" with `why`), `turn_to`/`slide_to`/`ball_to` (bisected to
  the last pose with room), `follow` (the pointer's ray to an angle, a slide
  or a ball's turn), `settle` (a free joint down under its weight), `commit`
  (one undo step). `grab_probe` checks each on real sets.
- `grab in a browser` (`tools/web/grab_flow.mjs`): opens a crane from a file,
  takes the arm by mouse where `window.brickworksGrab.handles` says it is,
  drags it up (turns on its hinge mid-drag, kept on release, said), Ctrl+Z
  puts it back, then turns the turret on its turntable; the app's frame cost
  of a drag and the page's longest wait. In `preview_checks.sh`'s map as
  `grab`.
- `snap onto a joint` (`src/assembly/joint_snap.gd`, `Builder._onto_a_joint`):
  as BrickLink Studio does it. With a part in hand that has a Technic or a
  bar end, aimed at a connector it fits, the ghost goes onto it: a pin into a
  pin hole (collar at the near mouth), an axle into an axle hole or a round
  one (through it, its tip at the far mouth), a beam's or a gear's hole onto
  a pin (against the collar) or an axle's tip (flush), a clip onto a bar
  where the pointer is along it (half-plate steps) and a bar into a clip or
  a hollow stud. The connector aimed at is the one nearest the pointer's
  line, within 12 LDU, and not behind what the line met. `R` turns the part
  about the joint — a cross in a cross by quarters, anything round by 45°
  or the toolbar's turn step if finer, stopping too where it also joins
  another part (`swung onto a second joint`) — and `T` takes the next way onto it
  (in from the other face, the other way up, the next hole of a beam,
  the other end of a bar). Until either is pressed, the way with room that
  joins the most parts is found (a beam aimed at one of two pins goes on
  both). Whether it has room is `Builder.room_for`, check_design's own rule
  (`Assistant._joints_out`): nothing in its way but a part it is pinned to
  (`Joints.both_ways`), a frame it nests in, or something round it fits
  where the two meet inside the round — and, on a joint, not below the
  ground. The same rule now decides the ordinary ghost too. The status
  bar says what it is on ("Placing Technic Pin on the pin hole of Technic
  Brick 1 x 2 with Hole") and what R and T do there. Probe:
  `technic_hand_probe`. In a browser: `tools/web/technic_flow.mjs`, which
  aims each part at the connector where the page says it is
  (`brickworksState.joints`, with `on_joint` and `can_place`).
- `placed by its sockets` (`Builder._socket_phase`, `Builder._hangs_below`,
  2026-10-16): a part whose box is not its plate — a clip plate's clip, a
  bracket's arm, anything that hangs past or below where it stands — goes
  across the stud grid where its sockets say, not where its box's size says,
  and down onto its plate where that leaves room, not onto the bottom of what
  hangs below. 5762-1's two 4081b clip plates stood half a stud aside and 2
  to 10 LDU up, and could not be put where the set has them by hand.
  Plain parts, whose box and sockets agree, are placed as before, and only
  sockets on the half-stud grid count: a wedge plate's (51739) and 6157's are
  not, and taken at their word put those 2 to 16 LDU off their studs in the
  build flow's run. `handbuild_probe -- only=build_from_a_booklet` aims both
  clips by the pointer and checks place and turn exactly, and checks every
  upright part of the CAD task's three sets against where its file has it
  across the grid: 97 of 140 by the sockets' rule, 87 by the box alone,
  worse for none.
- `what the ghost shows is where it goes` (`Main._true_point`, 2026-10-16):
  a click aims before it puts (a finger has no move before it), and in a
  browser the click was aimed somewhere else: Godot reads a move from the
  browser's pointermove, to the fraction of a CSS pixel, and a press or
  release from mousedown and mouseup, whose clientX Chrome cuts to the whole
  pixel. On the edge of a face, or against a side where the place steps by
  2 LDU, that put the part other than where its ghost stood: the plane's
  clip plates a stud forward and 2 LDU up, and 16 of 35 clicks stepped
  across a plate's edge. A press, a release, the system's pointer (a ghost
  re-aimed after a key, a fetched part, a closed box) and a part dropped
  from the bin within a CSS pixel of the last move are taken at that move's
  place (`Main._pointer`, `Main._pointed`). The page tells the ghost's whole
  pose and the pose of the last part put down
  (`brickworksState.ghost_pose`, `.put`), and where the app last saw the
  pointer and where the system says it is (`.pointer`). A ghost re-aimed with
  no event of its own (a part's shape arriving, a colour, a key) is aimed
  where the app last saw the pointer move or press, not at the system's
  pointer, unless that has moved since over a window of the app's own
  (`Main._pointer`): with a probe's events, a part whose shape arrived after
  the move onto the model had its ghost put back 260 pixels off. And a move
  the app never saw is followed from the system's pointer once the moves
  stop (`Main._follow_unseen_move`): in a browser the last move off a part's
  tile went to the tile's tooltip, and the ghost stood 500 LDU off behind the
  bin until the next move (not while a button is down or a menu or dialog is
  up; docs/CADTASK.md section 5). Probe: `placing_probe` (a
  part taken from its tile and moved onto the model in one move and two; each click
  sent as a browser sends one, the move fractional and the press cut down:
  35 clicks across the edge, then a clip plate, a bar in its clip, a hinge,
  slopes, a pin in a hole, and 8841-1's Technic plates; every put-down
  equal to its ghost to 0.01 LDU). In a browser: `tools/web/placing_flow.mjs`.
- `swung onto a second joint` (`Builder._closings`, 2026-10-16): a part on
  something round in something round (a hole on a pin, on an axle's tip) is
  turned about it to where another of its ends comes onto an end of a part
  down that takes it, as Studio turns a part to fit its connections: found
  for the person until R or T is pressed, a stop of R's on the way round,
  and where `T`'s next way onto the joint lands when it can. 8841-1's two
  4262s hang from an axle at 66.4 degrees with their lower holes on two
  pins, off the 24 turns and the whole LDU: aimed at a pin, each stands
  where the file has it to 0.001 LDU (one with one `T`). A round hole a pin's
  size through a plate's thickness that LDraw draws as a plain cylinder
  (4262's steering ends) is a pin hole, its mouth a collar's half out from a
  Technic hole's (`JointSnap.ends_of`, `COUNTERBORE`). Probe: `placing_probe
  -- only=balance`; in a browser, `placing_flow.mjs --only=balance` opens the
  set's file up to its plates and puts both through the interface.
- `place under a part and on side studs`: aimed at a part's underside, the part
  in hand hangs under it, the top of its body against it (never below the
  ground). A part tipped with `T` so its underside faces a wall with studs on it
  (a brick with studs on its side) goes onto those studs: a socket on the stud
  nearest the pointer, flat on the face (`Builder._onto_side_studs`).
- `hoses and chains by hand` (`src/ui/flex_tool.gd`, the laying itself in
  `src/assembly/flex.gd`): Build, Hose, tube or chain… opens a panel over the
  model's left edge — what to lay (pneumatic tube, ribbed hose, flex-system
  hose, flexible axle, string with end studs, Technic chain, tread) and how long
  a real part ("The shortest that fits" by default: the shortest that neither
  falls short nor bends tighter than it goes). The tool has the left button,
  as the ruler does (`Main._unhandled_input` asks `FlexTool.takes` first):
  pointing lights a connector it takes, a click picks it (the face of a hole
  looking at the camera unless the other end says otherwise), the second click
  lays it. A chain: click two or more sprockets or gears, each click lays it
  again. Then Add a bend puts a ball on the path where it lies; dragging it
  draws the new path blue, or amber where it would kink, and letting go lays
  it — unless that bends it tighter than the real part goes, which leaves it
  as it was and says so. Each lay is one undo step ("laid …", "reshaped …").
  The item is a sub-assembly of its segments ("Pneumatic Tube 9L#1", a name of
  its own so it is never taken for a copy of another), so a click takes all of
  it and it saves as its own LDraw sub-model of segments. Edit, Reshape the
  hose or chain reopens it; after an undo or a reopen it is read off its own
  pieces (`Flex.ends_of_item`, `centreline`): ends on the connectors they are
  at, length the nearest real one's, the fewest bend points that lay it within
  a few LDU of where it lies. `window.brickworksFlex` says the stage, the item,
  and where on screen each connector, sprocket and bend point is. Probe:
  `flex_ui_probe` (windowed). The parts list, the shop lists, the counts line,
  the booklet and a shared link count a laid hose, tube, flexible axle or
  string as the one part sold (`Flex.items_in`, `Flex.real_part`, see
  [model-io](model-io.md)); a chain or a tread as its links.
- `build a real set by hand in a browser` (`tools/web/cad_task_flow.mjs`,
  `tools/bench/cadtask_klm.py`, 2026-10-16; run by `tools/bench/cadtask.py
  build`, written up in `docs/CADTASK.md`): three small real sets (20 to 80
  parts, the author's steps, no sub-models, hash order: 5762-1, 8643-1,
  8841-1) built one after another from their steps with only what a person
  has: the parts search and its first tile, a colour swatch found on screen
  by its look (the app's palette, `assets/generated/colors.json`, not
  LDConfig's, whose old greys are other values: the run of 2026-10-16 found a
  brown for 8 by them) and taken only when plainly that colour, the note under
  the palette read back (`brickworksState.colour`), else its name typed
  (`Shift-C`, the name until the line over the palette names it first,
  `brickworksState.colour_first`, Enter), R/T to the file's turn, the pointer moved
  until the ghost (`brickworksState.ghost`) stands where the file has the
  part, a click, and `E` once a step's parts are down. At the end, Right on
  the timeline after a tile was clicked (`focus`), and whether each of the
  file's steps came out one step of the model's (`compared.steps`).
  Every input is counted by kind; a part the UI cannot get to its place in a
  few tries is a gap, with why, and nothing is put there. The model is then
  exported by File, Export, LDraw and compared part by part with the file,
  up to the one shift a baseplate gives; the set's own file is opened beside
  it for a side-by-side picture. `cadtask_klm.py --merge` adds a
  keystroke-level model of the same parts in Brickworks and in Studio
  (modelled, not measured; Studio's sequence from its help pages, every
  assumption listed) and how the measured run differs from its own model.
  `tests/test_cadtask_klm.py` pins the model. A `stop` file in `--out` ends
  the building early. On this box a part takes about a minute.

## How to reach it

```sh
godot --path .                  # click places, right-click removes, left-drag boxes,
                                # right-drag turns the view, Cmd/Ctrl-Z undoes
godot --path . -- --model=models/car.ldr   # with a known model loaded
```

`,` lists every binding the app advertises — `controls_probe` presses all of them,
so that list and the behaviour cannot drift apart.

## How to check it

Static: `tools/check.sh` runs all of the below. `pyright` does not reach GDScript;
the only static check for this area is that the project parses.

Runtime:

```sh
# the real gestures, in a real window — this is the one that catches feel
# (a box let go over a column, whichever side it is: the parts bin's, on the
# left, on a first visit)
godot --path . --resolution 1400x900 --script src/dev/feel_probe.gd
# what a dragged box catches, which needs a camera with a viewport to project into
godot --path . --resolution 1200x800 --script src/dev/marquee_probe.gd
# a tooltip never takes a click meant for what is under it: stacked, in a
# dialog, in a menu, and every panel's tooltips over what they cover
# (-- --no-sweep for the stacks alone, a few minutes; the sweep is half an
# hour in software and its panels may cover each other: it says what the
# pointer was over where no tooltip came)
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
  --resolution 1400x900 --script src/dev/tooltip_probe.gd
# several bricks worked on at once, and taken back at once
godot --headless --path . --script src/dev/select_probe.gd
# the selection's outline round its silhouette, never over it, for one brick,
# a chain and Orthanc, through the cut and x-ray, and the hover's; its targets
# let go of at once when nothing is outlined, with no frame drawn; at 1x and
# at 2x (2800x1800 is the app at twice the pixels). Pictures in shots/outline/
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
  --resolution 1400x900 --script src/dev/outline_probe.gd
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 2800x1800x24" godot --path . \
  --resolution 2800x1800 --script src/dev/outline_probe.gd -- --tag=2x
# ...and in a browser, at 1x and 2x: a click's selection kept through 6 s with no
# input and drawn round, and standing still drawing nothing
node tools/web/outline_check.mjs --dir=build/web   # after tools/export.sh web, .env sourced
# what the outline costs a frame with all of Orthanc selected, still and turning,
# by the processor's time, against the same frames with nothing selected
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
  --resolution 1400x900 --script src/dev/outline_cost_probe.gd
# what the model stands on: each floor saved and read back, one undo each, the
# model never moving; the first part on the grid floor and on none landing on
# the same studs as on a plate, stacking, standing up; the stud grid, a box,
# Fit and the cut-away with no plate; the plate made part of the model
# (counted, saved, the booklet's step 1, reopened with none under it) and back;
# a file's own plate; pictures on each floor. Pictures in shots/floor/
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
  --resolution 1400x900 --script src/dev/floor_probe.gd
# ...View, Floor and the properties by hand (handbuild's floor_menu section)
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
  --resolution 1400x900 --script src/dev/handbuild_probe.gd -- only=floor_menu
# ...and in a browser: View > Floor switched to none, grid and a 16 x 16, a part
# put down on each, Tan, and the plate made part of the model
PARTS_URL=http://127.0.0.1:8761/parts/ tools/export.sh web
python3 tools/web/serve.py build/web 8761 --parts assets/generated/parts &
node tools/web/floor_flow.mjs --url=http://127.0.0.1:8761/index.html --out=shots/floor_web
# building by hand as a person does: copy, paste, duplicate, cut, move, turn,
# select by, hide, the menus, the toolbar and its tools, the properties, the
# status bar, the tour, replace, history, the parts shelf, the seat offer and
# a 1280 x 720 window with nothing over the model, and the columns taking
# turns (a first visit on the parts with no assistant, the assistant turned on
# opening its column, Q bringing the parts bin out, a rail's click switching)
# — every step a key or a click, with pictures in shots/handbuild/
godot --path . --resolution 1400x900 --script src/dev/handbuild_probe.gd
# what the ghost shows is where the part goes: each click sent as a browser
# sends one (the move fractional, the press cut to the whole pixel), 35 across
# a plate's edge, then a clip plate, a bar in its clip, a hinge, slopes, a pin
# in a hole and 8841-1's 4262s swung onto their axle; every put-down equal to
# its ghost. Pictures in shots/placing/ (-- only=edge|parts|balance)
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
  --resolution 1400x900 --script src/dev/placing_probe.gd
# ...and in a browser: the ghost's pose (brickworksState.ghost_pose) against
# the part each click put down (.put); edge, parts, and 8841-1's file opened up
# to its plates and both put through the interface
PARTS_URL=x tools/export.sh web
python3 tools/web/serve.py build/web 8931 --parts assets/generated/parts --delay 0 &
node --env-file=.env tools/web/placing_flow.mjs --url=http://127.0.0.1:8931/ --out=shots/placing_web
# the assistant off: the first run on the parts bin with the model in view and
# its one button offering the assistant; nothing of AI by name or by text in
# the window, any menu, the menu on a part, Brick Art, Account, My collection,
# the tour, About, the keys list, the sign-in screen, Check stability, the
# parts list or Simulate; Ctrl+K inert; the connector held off; then the
# button pressed, everything back; off and on by clicks in Settings; and a
# build by hand to a step, the booklet, an LDraw file and a GLB. Pictures in
# shots/noai/. Again with --assistant=on, as /app?assistant=on: on, kept, its
# column open, no button
godot --path . --resolution 1280x800 --script src/dev/noai_probe.gd
godot --path . --resolution 1280x800 --script src/dev/noai_probe.gd -- --assistant=on
# ...and in a browser, against a local export and the deployment's functions,
# with .env sourced: the first visit, every word the window shows searched for
# AI (window.brickworksWords), the button pressed, Settings off by clicks, a
# build by hand to the booklet's tab and a downloaded LDraw file, the setting
# kept when the page is opened again; a fresh visitor at /app?assistant=on
# (on, column open, the parameter gone from the address, kept); and the
# relay's words to Claude when no tab is open (--relay)
tools/export.sh web
node tools/web/relay_server.mjs 8790 --static=build/web &
node tools/web/noai_flow.mjs --url=http://127.0.0.1:8790/index.html --relay --out=shots/noai_web
# sub-assemblies and the model tree, at any window size: nothing over the
# model, and the tree opened by its header
godot --path . --resolution 1100x700 --script src/dev/assembly_probe.gd
# the model clear at every size and density, in a browser (fails on a build
# whose panels float over the model)
node tools/web/fit_check.mjs --url=<preview>/app --bypass=…
# undo belongs to the model it was recorded against
godot --headless --path . --script src/dev/history_probe.gd
# where a brick lands when you point at a stud
godot --headless --path . --script src/dev/snap_probe.gd
# Technic by hand: a pin into a hole, an axle through a beam with a gear on
# it, a beam onto two pins, a clip on a bar, a clip on 2540's handle (room
# with its plate out, up or down, not into the plate) and a bar in a clip,
# each aimed at, clicked, joined, and passed by check_design; the same pin a
# stud off and the same clip or bar 2 LDU off the line refused by both
godot --headless --path . --script src/dev/technic_hand_probe.gd
# a pneumatic tube laid by clicking two pin holes, bent by a dragged ball,
# refused past its bend, undone; Pose offering the laid tube no slider; a chain
# round two gears by two clicks; saved, reopened and reshaped from its pieces.
# Pictures in shots/flex/
MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/flex_ui_probe.gd
```

Proves it when: each exits 0 with no `FAIL` line, and ends on its sentence —
`snap` says "hand placement lands where the assistant would put it",
`technic_hand` says "by hand: a pin into a hole, ... and check_design agrees",
`handbuild` says "by hand: ... all work as a person uses them", `outline` says
"a selection is drawn as a line round its silhouette, never over it, ..." (look
at `shots/outline/<tag>/*.png`: a thin yellow line hugging each selection, the
chain's inner edge too, no box anywhere). Look at
`shots/handbuild/*.png` too: the ghosts in their colours, `shell.png`,
`edit_menu.png`, `tools_menu.png`, `select_tool.png`, `properties.png`,
`grid.png`, `tour.png`, the Select by and History menus, the seat offer and
the 1280 x 720 window. In a browser, the deploy's `fit_check.mjs` finds New
and Save on the toolbar at every size, and on a preview

```sh
node tools/web/technic_flow.mjs --url=<preview>/app --bypass=$VERCEL_BYPASS   # .env sourced
```

builds two beams joined by pins, an axle through the upper one with a gear
on its top, and a bar in a hollow stud with a clip on it, every part aimed
at its connector and clicked, and ends "technic flow (1x): two beams joined
by pins, an axle with a gear and a clip on a bar, built by hand" with
pictures in `shots/technic_web/` (2026-10-12: 33 checks, nine parts,
"stands up").
and Save on the toolbar at every size, and nothing over the model: each case
prints "nothing over the model (model [x,y,w,h], 96 points, columns turns, N%
of the width)", and the pictures in its `--out` show the columns.

For the scene itself, launch it and read the brick count in the status bar: with
`--model=models/car.ldr` it is 61 parts, which is what
`godot --headless --path . -- --model=models/car.ldr --out=/tmp/car.ldr` writes.

## Gotchas

- **A windowed probe needs a display.** `feel` and `marquee` cannot run headless:
  the preview is drawn by a SubViewport and what a box catches depends on where
  each brick lands on screen.
- **The ghost aims at the event, not the cursor.** `_refresh_preview(at)` takes
  the position from the event being handled. A probe that synthesises a click
  without moving the real mouse used to place the brick wherever the OS cursor
  happened to be.
- **Clicks need the preview settled.** `feel_probe` waits for
  `_builder.hovered_brick() != 0` after `hide_preview()` rather than counting
  frames; counting frames passed on a fast machine and failed on a slow one.
- **The baseplate is scenery, not model.** `_lay_baseplate()` removes the previous
  scenery bricks as well as forgetting them. It once only forgot them, and a
  stale baseplate blocked every edit underneath it.
- ~15–20s of catalogue loading before anything appears. Not a hang.
- **The system clipboard is the person's.** `handbuild_probe` copies, which writes
  LDraw to it; it keeps what was there and puts it back at the end. On a real
  desktop session a probe run still briefly replaces it.
- **A connector is aimed at by the pointer's line, not by the lattice.** A
  hole is empty in the cover, so a line looking down it meets nothing, or
  the baseplate behind; the hole is found by its distance from the line
  (`JointSnap.aimed_at`), limited to a little past whatever the line did
  meet. Hidden parts' connectors are skipped as their cells are.
- **Connector conventions differ by kind, so the pose reads the part.** A
  pin's connector is at its collar, an axle's at each tip (3705) but an
  axle pin's at its collar (3749), a pin hole's at its middle, 6632's axle
  hole at its face. `JointSnap.ends_of` takes a hole's depth from its own
  bores (a pin hole is a bore 6 across with an 8 counterbore at each mouth)
  or the part's thickness through it, and whether a male end is a collar or
  a tip from how far the part goes on past it.
- **A plate with a handle (2540) takes no clip, by hand or by check_design.**
  Its cover fills the loop of the handle, as `fill_cavities` fills any hole
  running upright, so a clip round that bar overlaps it outside the round.
  A free bar (30374 in a 3062b's hollow stud, or in a clip) takes one.
- **New `class_name` files need `godot --headless --path . --import --quit`** before
  a probe can name them; a checkout's class cache is only refreshed by an import.
