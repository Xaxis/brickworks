# Building

Pointing at a stud and getting a brick there, selecting several, taking it back.

<!-- covers: scene:main, ui:place and remove, ui:box select, ui:selection outline, cli:selection outline in a browser, ui:selection edits, ui:undo and redo, ui:copy paste and duplicate, ui:patterns, ui:move and turn a selection, ui:select by colour part or connection, ui:hide and show only, ui:menus and toolbar, ui:the app menu, cli:app menu probe, cli:app menu in a browser, ui:tooltips let clicks through, ui:tool modes, ui:properties panel, ui:status bar, ui:accessibility, ui:snap and turn step, ui:lock parts, ui:stud grid, ui:tour, ui:remembered layout, ui:assistant on or off, cli:no AI in a browser, ui:replace part, ui:undo history, ui:mirror a selection, ui:place under a part and on side studs, ui:snap onto a joint, ui:swing on a hinge, ui:typed place and hinge, cli:off-grid probe, cli:placing probe, cli:placing in a browser, ui:hoses and chains by hand, cli:hoses and chains by hand in a browser, ui:bands and springs by hand, cli:springs probe, ui:sub-assemblies, ui:model tree, ui:sections, lib:sections suggested, cli:sections in a browser, ui:measure, ui:docked panels, ui:what the app is busy with, ui:floor, cli:floor in a browser, cli:build a real set by hand in a browser, ui:grab and move on a joint, lib:rigid bodies and joints, lib:moving a body on its joint, cli:grab in a browser, lib:moving a chain of joints, lib:closed loops of joints, lib:racks and their pinions, lib:worms hold their gears, lib:linear actuators, lib:a model that tips falls, lib:swinging on a free joint, lib:coasting when flung, lib:hoses follow a grab, cli:the builder's frames after a change, ui:gears put in mesh by hand, ui:meet on hinges, ui:type a number while moving, cli:typed moves probe, ui:find a command, cli:palette probe, cli:first build probe, cli:palette in a browser, ui:connect by a point, cli:connect probe, ui:handles on the selection, cli:handles probe, cli:set walk probe, ui:split and merge parts, cli:splitmerge probe -->

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
  on a build, the old way (`--recipe=old`) or this one. On a touch screen a
  finger held 0.48 s on a part, with a part in hand, takes it off; held is what
  the frames saw (`main.gd` `_touch_hold`, `src/ui/press_hold.gd`: from the
  first frame after the one that handled the touch), so a tap across one
  slow frame is a tap, and so is one whose own frame does 600 ms of work
  before the app sees it or after, drawing (`src/dev/slow_frames_probe.gd`,
  windowed on the GPU).
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
  over them, and go all the way round. It finds the parts' inside with the
  view's anti-aliasing and glow off: they smear a part's colour into a gap
  between two selected parts that the line rightly fills (Saruman's hand at
  his robe read as 2 of his 190 pixels inside outlined). Run it at `--resolution 2800x1800 --
  --tag=2x` for a 2x screen. `tools/web/outline_check.mjs` is the browser's
  picture at 1x and 2x, and its frames of the window standing still (what is
  drawn off screen alone counted apart); before the picture it
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
  the clock, not that), once the app's workers have gone quiet after Orthanc
  opens (a core each for about 4 s): with all of Orthanc selected a frame with
  the view still within a twentieth of the bare one and turning within a
  tenth, and the line back each time the view rests. Selecting all of it, and
  every part of one colour, is timed by the main thread alone (the clock less
  its wait for a core), under 400 ms: the worst of five 159 to 278 ms at
  load 15 to 34. Timed by the whole process it counted the workers too, 430
  to 1,010 ms. Measured under heavy on llvmpipe:
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
  A part an undo or redo puts back keeps its number (`BrickWorld.add_brick`
  `as_id`), so what named it still does: a session's next edit, the
  assistant's record, the surface pass's pieces (`undo_ids_probe`).
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
  as one step and selects it; `R` turns it; `Esc` puts it away. After `Ctrl-D`
  or a click with the Clone tool another copy stays in hand (`Carry.repeats`,
  APP_UX A6), as Studio's Clone does, until `Esc`, a right click or another
  tool; a paste and a `Ctrl`-drag copy go once (`typed_moves_probe -- only=clones`:
  five copies in six actions, one undo each). The group's frame
  is a stud centre or corner at its bottom, so whole-stud moves and quarter turns
  keep every part on the studs; it drops onto whatever is highest under any of
  its parts, and a side face pushes it out until its edge meets the face. Copy
  also writes LDraw lines to the system clipboard (where they were in the model),
  and LDraw another program put there pastes in.
- `patterns` (`src/assembly/pattern.gd`, `src/ui/pattern_dialog.gd`; APP_UX B6):
  copies laid out at once. Straight after a `Ctrl-D` or Clone copy is put down,
  `11x` (or `11*`, `*11`) makes it one of 11 in the row, each the same move
  again, and `/4` cuts the gap from where it came from in four; read through
  `TypedEntry.reads` (`EditVerbs._copies_read`) while that copy is still the last
  change, and folded with it into one undo. `x 11` stays a move. Edit,
  Pattern… (`Ctrl+Shift+D`): In a row (along x, z or up, every so many studs or
  plates), Round (what it stands on, the joint it hangs on, or the floor's
  middle; each turn the whole way round shared out until one is typed), Along a
  hose (a laid hose, tube or chain's centreline, the copies turned as it
  turns). "In all" counts the selection. Every copy is checked by
  `Builder.room_for` against the model and the copies before it (stood in the
  lattice under negative ids), drawn as ghosts, red where it has no room, and a
  refusal says which copy and what is in the way; nothing is put down unless all
  fit. `handbuild_probe -- only=patterns`: a fence of 12 posts in 5 actions, `/4`,
  a row through a brick refused, a ring of 16 bricks on turntables in 6 actions,
  four along a pneumatic tube, each one Ctrl+Z.
- `move and turn a selection`: `X` with a selection picks it up to follow the
  pointer; a click puts it down (lifting and putting down are one undo); `Esc`
  puts it back. `R` / `Shift-R` turn a selection where it stands, about the
  same point each time, so four turns come back exactly. Where a turn (`R`, `T`,
  the Rotate tool) has no room, the parts in the way are tinted red (amber on a red part) for a second
  (`Builder.refused_by`, `EditVerbs._flash`) and the selection comes into hand
  already turned (`Carry.reshape`): a click puts it down where it fits, lifting
  and putting down one undo, and `Esc` puts it back as it was (APP_UX A3;
  `typed_moves_probe -- only=wall`: the walk's brick down at 15 degrees in R, an
  aim and a click). Half round (the
  properties panel's Turn of 180) goes round the middle on a half stud each
  way and lands on its own footprint, as Mirror does (`mirror_probe`).
- `select by colour part or connection` (`src/assembly/select_by.gd`): the
  toolbar's Select by (and Edit, Select by) takes the same colour, the same part, both, everything
  joined by studs (a brick beside another is not joined; a sideways part is
  across its stud axis), the opposite, all, none. The baseplate is never taken.
  And a part by what it is called: Part number or name… opens the parts list
  with its find to type into (`SelectBy.wanted`: "3004", "3023" for 3023b,
  "brick 1x2" with every word as the parts bin searches, a colour of the
  model's by name, or both, "blue 1x2 brick"); Enter selects every row it
  kept. In the list each row shows its part's picture in its colour
  (`ThumbTile`, drawn as it comes into sight), and a click selects that lot's
  every piece (a hose's every segment), frames them and says how many, with I
  for a buried one; the list opens again where it was. Parts inside
  sub-models are taken as any other. A row clicked twice selects as once:
  the second click, which lands on the model once the list has gone, is the
  list's (`Main._found_at`, `_eat_release`); it went into the sub-model under
  the pointer and left nothing selected on the Cat D11 (walk256 D10,
  `find_submodels_probe`). Escape over the list
  closes it before it clears a selection under it. In a shared model's viewer
  a row does the same, and Escape then lets go of them (`share_view_probe`). The MCP's twin is
  look_at_model's `part=` and `color=`, which list where each one is: no
  session tool sets the person's selection (`AppTools.WINDOW_ONLY`).
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
  it is a setting that is on. Each command is in one menu (appux371 A7; the
  `palette probe` counts every menu's ids): File: New, Open, Open recent,
  Import (LDraw, Studio `.io`; LDD `.lxf` greyed, not yet), Save, Save as,
  Export, Render… (see [view](view.md)), Clear, Quit. Edit (25 rows) keeps
  the clipboard, the selection, hide, lock, paint and replace; Build the
  steps (Next step, Build steps), Instructions, the sub-assemblies and the
  sections (Exploded view); Help is Keys and the tour, and About, Send feedback,
  the docs, the website, Beta hub (a tester's) and Account are in the app
  menu. A phone's More lists the
  app menu's rows under Help (`Shell.touch_menus`). The toolbar under it: New/Open/Save, Undo/Redo/History,
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
- `the app menu` (`ModelBar.mark`, `Shell.APP_MENU`): the mark (web/icon.svg,
  drawn from its copy `assets/ui/mark.svg`, which `tools/web/make_icons.mjs`
  writes and `tests/test_mark.py` holds byte for byte) and the app's name,
  first in the menu bar, where the name in words was. It opens About
  Brickworks, Brickworks website, Documentation, Account and, in a browser
  only (`Shell.WEB_ONLY`), Back to brickworks.diy, which takes this tab to the
  site's own `/` (a preview's on a preview). F6 from the model goes to it
  first; Return opens it. Where the bar has no room for the name on one line
  (`ModelBar._fit_mark`), the mark alone. Never on the model, a render or an
  export. `app menu probe` (windowed) checks it first at the bar's left at
  the window's width and narrower to 720 units, the bar one line and the
  bar and toolbar exactly as with the old name in words, the rows, About from
  them, the keys, and every row of it and of Select by running its own
  command after the assistant is turned on (`Shell._fill` gives a command one
  id for good; a menu made again once handed its ids to others).
  `app menu in a browser` (preview check `app_menu`) does it in a browser at
  1280 and 390 wide, reads the mark's colours off the canvas, and follows
  Back to brickworks.diy to the site's header.
- `find a command` (`src/ui/command_palette.gd`, `Shell.palette`): Ctrl+/
  (and Ctrl+Shift+P on the desktop; a browser keeps that one), or the app
  menu's Find a command…, opens a box over the model with the keys in it.
  Typing filters every command by the words of its name and of its menu
  (each word typed begins a word there, or is inside the name; at three
  letters a word of its tooltip): "same colour", "turn left", "xray".
  Each row says its key and its menu ("Edit › Select by"); one that cannot
  be used now stays, greyed, saying why (`Shell.why_not`, `Command.needs`),
  and Return runs nothing. Return runs the lit row through `Shell.run`, as
  its menu row does; Up, Down, Page Up and Down move; Escape puts it away.
  The last eight run from it come first (`ShellPrefs` `palette_recent`).
  `palette probe` (windowed, 1280 x 720; 1400 x 900 by `PROBE_SIZE`) walks
  every command in `Shell._commands`: typed by its words, reached by Down,
  Return hands exactly it to the run (a stand-in, so no file dialog,
  browser or network) or, greyed, nothing; Render opens for real in five
  presses (Ctrl+/, R, E, N, Return). It also checks no command in two menus,
  Edit at most 25 rows and 60% of the window, and the menu on a part's
  Duplicate, Replace, Select the same part and colour, the step moves and
  Swing on its hinge (`swing`, J), each run from the menu. `palette in a
  browser` (preview check `palette`) drives it by keys in a browser
  (`brickworksState.palette`).
- `tool modes` (`EditVerbs.mode`): Select (the default) and Place (a part in
  hand), and Move, Rotate, Hinge, Clone, Paint, Hide, Delete — a click on a part
  does that tool's one thing to it, or to the whole selection when the part is
  in it (`EditVerbs.click`). Move and Rotate first pick a part out that is not
  selected, its handles on it (`handles on the selection`); a click on it again
  picks it up or turns it a turn step, as before. The tool in use is lit on the toolbar and ticked
  in Tools. Only Place shows the ghost; a part carried by a drag, Move or Clone
  shows its own. `V` is Select, `Q` Place; `Esc` closes whatever is up and goes
  back to Select with nothing in hand, in one press.
- `properties panel` (`src/ui/inspector.gd`): in the right-hand column, under
  the model tree (`docked panels`); View, Properties with the column folded,
  or showing the assistant, opens it on them (`SideDock.of`). Nothing
  selected, it is its header and the floor alone ("nothing selected",
  `Inspector.is_idle`) and the tree has the column. With a part selected it
  is as tall as all it holds (`PanelStack.keep_whole`), the tree giving back
  room: at 1280 x 720 every field is in sight, where in the left column it
  showed X and Y and the rest behind a scroller (appux371, 2026-10-30).
  Probe: `columns_probe`. One part: its name, LDraw and BrickLink numbers, its colour by
  LDraw's name and code, LEGO's name and number, BrickLink's and Rebrickable's;
  X, Y, Z in LDU and its turn in degrees, typed over or stepped to move or turn
  it (refused and put back where there is no room); what it is joined to,
  which way its studs face, its sub-model, its step in the instructions (models
  of 600 parts or fewer) and whether it is locked; Joined, Lock, Hide. Several:
  how many of what, the colours, the size in studs and bricks, the group's
  corner to type over. Folds to its header; scrolls when the column gives it
  less room than it needs.
- `docked panels` (`src/ui/panel_stack.gd`, `src/ui/side_dock.gd`,
  `Main._fit_panels`, 2026-10-30, appux371's A10): the left column is the
  parts bin with its colours under it, as Studio keeps its parts palette down
  the left, as many tiles across as the model's share leaves room for
  (`Main._fit_panels`, `PartsBin._tiles_across`: six at 1280 x 720 and
  1400 x 900, five at 1100 x 700, four at the least and on a phone);
  the right column is the model tree over the properties, as
  Figma, Blender and Onshape keep the inspector on the right, with the
  assistant as a tab beside them (`SideDock.share_edge`: the two rails one
  over another in one strip, one of the two showing; opening one while the
  other shows swaps them where they stand). In one column with the bin the
  tree and the properties left it 8 parts in sight at 1280 x 720 and the
  properties X and Y. The colours are as tall as the column says
  (`PartsBin._fit_palette`: 14% of it, two category rows from a 700-unit
  column; under that, on a desktop, a row and a half of colours and one
  row of categories, so a laptop's 1280 x 720 has four rows of six parts
  in sight), so a part taken into hand moves the parts grid's foot and never
  the palette. In the right column the tree has its dragged height and the
  properties the rest, all they hold in sight (`PanelStack.keep_whole`);
  with nothing selected the tree has the column (`PanelStack._filler`). The
  bar between two drags the height of the one that does not fill. The tree
  comes out of its fold once, the first time a device has the right column
  (`right_column`): folded, the column was an empty Properties. The model's
  part of the window is what is left, with nothing over it but the view cube:
  the tree and the properties floated over its top corners, where clicks
  meant for a part landed on them. The sub-assembly banner and the offer to
  seat old parts are in a strip above the model (`Main._notices`), not over
  it. The model keeps 60% of the window's width (`Main.MODEL_SHARE`, what
  `tools/web/fit_check.mjs` asks of a laptop's window): with both columns
  open at 1400 x 900 it had 41%. Both show only where both fit round that, a
  window about twice as wide as it is tall (1835 units); else the columns
  take turns, opening one folding the other side's (`Main._column_opening`),
  and a part put in hand (Q, the bin, the eyedropper) brings the bin out
  (`Main._bring_out_bin`). A first visit opens on the bin; the Properties
  rail brings out the tree and every property, folding it. The assistant
  turned on opens as the right column's tab, folding the bin where they
  take turns. On a phone or a tablet they are drawers, as before: the drawer down the
  left holds the tree, the properties and the colours, and there is no right
  column. Each rail carries its icon and its name ("Parts", "Properties",
  "Assistant"), tinted with the accent down its edge while folded, and
  switching is one click on it. Probe: `columns_probe` (1280 x 720, and
  PROBE_SIZE=1400x900 or 1920x1080: 24 parts in sight with the bin open,
  every property with theirs, the model's 60% at every step) and
  `columns_saved_probe` (a layout kept before the right column). A folded column's
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
- `phone layout` (`src/ui/phone.gd`, `src/ui/phone_shell.gd`, 2026-10-23): on a
  phone the app was the desktop shrunk (walk180 P1: 14-point buttons, 9-point
  swatches, a drawer over half the model, "right-click" and "Shift-drag").
  `Phone.on()`, decided once at start: the web, a touchscreen, the main
  pointer coarse with no fine one, and the screen under 600 points in its
  short direction; a touch laptop and every desktop keep the desktop layout
  to the pixel. Then `Main._dress_for_phone` puts the menus, toolbar, key
  strip, status line (shown only while busy) and view cube away, and
  `PhoneShell` lays out in points (`Phone.px`, about 1.85 units a point at
  390): along the top the model's name, Undo and Redo; along the foot one row,
  Parts, Colour (the colour in hand), Turn, Tip, Select (lets go, as a right
  click), Delete (the selection, else the Delete tool) and More; a line over
  the model in touch words (what was just said, `Phone.touch_words`, or what a
  finger does now); Fit in the corner. Sheets from the foot: the parts bin
  (Main's own, `PartsBin.zoom`, a finger's drag scrolling it), half the
  screen, its handle swiped to the whole screen or away, gone with a pick;
  the colours, 46-point swatches by group (`PartsBin.choose_colour`, what a
  swatch press does: it paints a selection); More, every menu's commands a
  row each, greyed and lit as the menus are; and a finger held still on a
  part (`Main._on_phone_hold`, `HOLD_MS`) brings its actions, the right-click
  menu's rows. Two fingers turn the view and pinch zooms
  (`CadCamera.phone`); a finger that lands on a part with Select moves it and
  the view stays (`finger_taken`). The shared viewer keeps its own. The
  notices strip is drawn for a finger (`Main._for_a_finger`). Proved by
  `tools/web/phone_flow.mjs` (preview check `phone`), at 390 x 844 and
  430 x 932 at 3x with touch events: More, New; the parts sheet half, swiped
  full and back; searched 3001 and picked; six bricks, a door and a roof
  slope tapped down; Select, a brick tapped, Colour, blue painting it, Undo;
  a held finger's actions; two fingers turning and spreading; at each step
  the app's own audit (`window.brickworksAskPhone`, `Main._phone_audit`):
  every target 44 points or more, no text under 12, nothing off the screen.
  The dialogs More opens are sized for a finger too (`touch dialogs`, below).
  walk256 (T1, T2, 2026-10-25): More is the menus' names, File to Help, each
  a row that a tap opens to its commands and folds again
  (`Sheet.add_section`, `phone_section_<menu>`; every menu folded each time
  More opens), not every command in one list a hundred rows long; Fit keeps
  under the notices strip on a phone as on a tablet (`PhoneShell._fit_top`:
  at 390 it sat over "Show the assistant"); and a part's "+N" of folded
  prints is a fingertip in its tile's foot, right of its number, clear of
  its picture (`PartsBin._fold_badge` by finger): in the top corner it
  covered the picture's middle and the first tap opened the prints. The
  flows check each: Fit clear of the strip, More's six names and no rows,
  File opened to its rows; 3004's picture tapped takes it and opens
  nothing, its "+N" opens and folds the prints.
  Words the bar says with keys after a
  dash ("1 selected — Ctrl-C copies, X moves...") are said without them
  (`Phone.touch_words`), and a count of the selection alone is left to the
  hint. The bin's fold badges ("+42") are 11 units by a finger, not 10, which
  came out 11.4 points. Two fingers turn by how far each went from where it
  was seen last (`CadCamera`, `moved`), not the event's relative: on the web a
  second finger's first relative was its whole position, and a level drag
  turned the view to look from under the baseplate (`tablet_flow` checks the
  tilt is kept).
- `tablet layout` (`Phone.wide`, `PhoneShell.wide`, 2026-10-24): a tablet (the
  short side 600 to 1100 points, touch the only pointer) was the desktop driven
  by fingers: buttons 24 to 37 points, 38 of the 39 named controls under 44 at
  768 x 1024, tooltips that never came, nothing for a right click. The
  desktop's toolbar alone (21 buttons) is wider than any tablet at 44 points a
  button, so the phone layout is laid out wide instead, with all its gestures
  and touch words: the sheets are panels between the bars, 400 points wide, the
  parts down the left (kept open while building: a pick does not close it) and
  Colour, More and a held part's actions down the right; where both would leave
  the model under 300 points one puts the other away until it goes
  (`PhoneShell._make_room`, `Sheet.set_aside`). The model is framed in the room
  between them (`PhoneShell.model_room`, through `Main._model_rect`), and the
  hint, Fit and the notices strip's words keep to that room. The row's buttons
  are 96 points, in the middle; the name field 320. A point is 720 units over
  the short side whichever way round (`Phone.tablet_factor`, in
  `Main._match_screen_density`), so turning it lays nothing out again; the
  shell looks again twice a second in case the browser said its new size late,
  and keeps what was open when it does lay out again. The app's page has
  `minimum-scale=1` (`src/boot/shell.html`): turned from landscape, Chromium
  zoomed out to fit the canvas's old width and the app stayed laid out 1024
  wide. Proved by `tools/web/tablet_flow.mjs` (preview check `tablet`), at
  768 x 1024, 1024 x 768 and 1024 x 1366 at 2x with touch events: the phone's
  steps (More, New; Parts; 3001 searched and picked, the panel kept; Fit and
  six bricks tapped down beside it; a door and a roof slope; Select, a brick,
  Colour, blue, Undo; a held finger's actions; two fingers turning, the tilt
  kept, and spreading), then the tablet turned round with the parts open, each step
  audited as the phone's (`window.brickworksAskPhone`, now with `wide` and
  `sheets`). On base it fails at once with the desktop's named controls
  counted. The desktop is unchanged: `tools/web/desktop_same.mjs` (local only:
  it needs a base build served beside) shoots 1280 x 800 by a mouse, ready,
  3001 searched and the File menu, against a base build, 0 pixels different
  and the base against itself 0.
  Standing still it draws nothing (2026-10-25, m174's tablet check: its first
  picture waited 30 s for a frame). The row's colour in hand redrew itself
  every frame (`PhoneShell.RowPicture`) and the hint was laid out every frame,
  set to nothing and back, so the whole window was drawn every frame
  (IdleDraw): 2 to 5 s a frame in software at 768 x 1024 at 2x, frozen from
  the moment it showed, which since the sign-in went behind the model is the
  moment it is used. Now each is set only when it changes. Proved by
  `tools/probe.sh phone_idle_probe` (windowed, the tablet's layout made in a
  window; `-- --phone` the phone's): settled, at most a frame a second standing
  still; a new colour in hand drawn, its picture the new colour; words over the
  model drawn, then still again. On the base standing still draws every frame.
- `touch dialogs` (`src/ui/touch_sizing.gd`, `TouchSizing`, 2026-10-24): on a
  phone or a tablet (`Phone.on`) every dialog and panel over the model takes
  the layout's sizing, one rule for all as `Access` is for the keys: its text
  grown from the desktop's units to points (the desktop's 11 is 12 points,
  the rest in proportion, none under 12), every target 44 points or more each
  way, a list's and a tree's rows and a menu's items too (a menu's words
  shrunk to fit the screen across, never under 12), a Window's title bar and
  close button a fingertip, an AcceptDialog's words wrapped and its buttons
  sized through its theme (`buttons_min_height`). Godot's dialogs are found as
  they are made (`node_added`) and sized each time they show; Main's panels
  over the model come through `Main._inset` (`TouchSizing.place_panel`). Placed
  for a finger: on a phone a dialog is a sheet along the foot, as wide as the
  screen, and a panel the whole screen; on a tablet both in the middle. Above
  the on-screen keyboard while one is up (the visual viewport's lost height,
  `window.brickworksKeyboardNow`, read while a field in a dialog has the
  focus), the field scrolled into sight. A dialog wider than the screen is
  made narrower (`TouchSizing._narrower`): a line too long wraps, and a row of
  buttons too long flows onto a second line inside its own row. And again
  whenever what it holds grows wider than it was laid out while it is open
  (`TouchSizing._grew`, on the panel's or the window's
  `minimum_size_changed`, fig257): Render's status line, told the picture's
  file name once it was downloaded, ran it and its Close off a 430-point
  phone. A dialog already placed never moves under a finger
  (`TouchSizing._place`, `finger_down`, press271): laid out again while a
  finger or a mouse button is down, it waits for the lift. Pressing Save or
  Rename takes the keys from the field, so the keyboard counted as gone and
  the dialog moved from under the finger before it lifted: a finger rolled a
  pixel was let go and nothing was saved or renamed (dialogs_1024 on m175,
  Save as at 390). The Minifigure builder's figure comes back after the
  search the same way (`MinifigDialog._make_way`). Proved by
  `dialogs_flow.mjs --only=save_as,saved --hold=150` and `--hold=600`, whose
  held tap rolls 2 px before it lifts: on the base, held 150 ms, Rename is
  missed at 390 and at 1024 x 768 and every delete check after it fails
  (Rename left open over the list); held 600, Save as is missed at both.
  Targets in a
  scrolling list pass a
  finger's drag to the list (`MOUSE_FILTER_PASS`), so More's list and a
  dialog's rows scroll under a finger; they did not. A notice's words and
  buttons in a row are laid words over buttons on a phone (`Main._words_over_buttons`):
  the browser's warning about keeping models ran off the screen. The model
  tree and the properties' drawer is sized the same (`TouchSizing.size_panel`,
  with Motions, Colour the hidden parts, Simulate, Stress, the busy line and
  the sign-in screen, whose card is as wide in points as the desktop's,
  `SignInGate._fit`: its address field was 199 x 20 points on a phone);
  on a phone it is the screen beside its rail (the notices strip waits while
  it is open), and on a tablet it takes the parts panel's place while it is
  open (`PhoneShell.dock_toggled`). The booklet's bar is a fingertip under
  `(pointer: coarse)` (`src/assembly/booklet.gd`), and on the web
  Instructions runs in the tap's own frame (`Shell.OPENS_A_TAB`): said first,
  it waited for its busy line, and under load the tap's leave to open the
  booklet's tab had gone. The audit
  (`Main._phone_audit`) now walks into Godot's dialogs (their internal
  buttons, title, close button), a menu's items and a tree's rows, says what
  is open (`dialogs`), the keyboard and the field typed in (`typing`), and
  counts a dialog's part under the keyboard as off the screen. Proved by
  `tools/web/dialogs_flow.mjs` (preview checks `dialogs`, `dialogs_430`,
  `dialogs_768` and `dialogs_1024`, a size each), at 390 x 844,
  430 x 932 (3x), 768 x 1024 and 1024 x 768 (2x) with touch events: from More,
  scrolled to by a finger, Save as typed into above the keyboard and saved;
  Open's menu, Rename or delete saved models, one renamed and deleted and its
  Undo; a version opened from Versions; Share's name typed, published by link
  where signed in; Settings, Reduce motion changed and back; Build together
  started where signed in; a 3D model and an LDraw model exported (downloads);
  Find typed into; the booklet's tab, asked for inside the tap's activation
  (`navigator.userActivation` read at the app's `window.open`: the headless
  shell has no popup blocker, so any ask opened one) and heard from before
  More is scrolled (a wait begun then ran out while More's drags took two
  minutes under load, booklet262); its Save as PDF (its bar measured in the
  tab, a PDF downloaded); Model tree and Properties (on a tablet the parts
  panel not under them, and back as they fold); Library, "UNICEF" typed
  above the keyboard and the van opened, its 65 parts in a tab of its own
  (fig257); Render, a quick picture made and downloaded; Parts list, My
  collection, Part maker, Colour the hidden parts, Keys and controls, About,
  Clear and Floor size opened and put away by their own close buttons; the
  Minifigure builder (below), a torso searched for above the keyboard, chosen
  by its tile and the figure placed by a tap on an empty baseplate; and last
  Account's Sign out, the sign-in screen up and audited where the test
  account was signed in; each step audited. Each size's check has an hour
  (`preview_checks.sh`; the rest have 45 minutes): with the main actions a
  size took about 2,600 s. Locally the server is given the parts bucket
  (`--parts-url`), where the live library is. On base it fails with the
  named controls under 44 counted and no dialogs said. The desktop is
  unchanged (`desktop_same.mjs`, 0 pixels).
- `a thrown list glides as a phone's` (`src/ui/fling_scroll.gd`, `FlingScroll`,
  fling272): Godot's ScrollContainer slows a finger's throw by a fixed 1,000
  units a second every second, so its glide grows as the square of the
  speed: on a phone (1.85 units a point) 237, 931, 3,707 and 14,741 points
  thrown at 0.5, 1, 2 and 4 points a ms, where iOS's UIScrollView ("normal",
  0.998 a ms) glides 250, 500, 1,000 and 2,000 (first258: a 434-point drag
  on More threw it 8,500 points, end to end). On a phone or a tablet
  (`Phone.on`, Main makes it) the root window's `window_input` hears every
  press and lift first, a dialog's (Saved models) and the parts bin's too
  (its cells scroll it themselves and take the lift); while a finger is down
  every list showing is looked at once a frame, and on a lift moving the
  list's speed (least squares over its last 100 ms of frames, or three
  frames, from where it set off; not the lift's own look) goes on and slows
  by 0.998 a ms, Godot's own glide cancelled first (setting a scroll cancels
  its drag). Lifted still (100 ms, and twice the time between its last two
  moves, as `Grab.fling_rate` has it) it stays; a press catches a glide; a
  list scrolled by anything else stops gliding; nothing runs a frame once
  the glides end. A finger's move reaches a list twice on the web, as the
  touch's (`DEVICE_ID_EMULATION`) and as the page's pointermove of type
  touch, which Godot's web input reads as a mouse's: the list and the parts
  bin went 2.00 points for each the finger went, and threw twice as fast.
  The list's own `gui_input` takes the second while a finger is down; the
  bin scrolls by the pressing device's moves alone. `tools/probe.sh
  fling_probe` (headless; events through `Input.parse_input_event`, each
  move twice as the web sends it) throws a 72,800-unit list at 0.5 to 4
  pt/ms at a phone's and a tablet's scale, again at 8 frames a second as a
  browser drawing in software draws, and a list that grows as it is
  scrolled, its foot met mid-glide: each glide within 25% of iOS's, the
  list 1:1 under the finger, a drag held still 200 ms not gliding, a tap
  tapping, and nothing processing after. On ada7c2aa 12 checks fail (2.00
  a point, glides +34% to +1,847%); with it every throw is within 2%.
  The bin let go of the tile's press as it scrolls
  (`NOTIFICATION_SCROLL_BEGIN`): the touch's own lift came after the
  mouse's and tapped the tile still under the finger, taking the part and
  shutting the sheet, which the base hid by running the grid away at
  twice the finger's pace. A glide waits three frames at a list's foot,
  for the bin's next page of tiles. In the web build (`--parts-url`, 390 x
  844, CDP touch, a device ratio of 1 so that SwiftShader keeps up; a
  throw whose moves the browser held up 120 ms is thrown again), More's
  list glides 243 to 254 points at 0.5 pt/ms, 405 to 728 at 1 and 1,020
  to 1,048 at 2 (iOS 250, 499, 999; 10 of 12 within 25%, the two outside
  where CDP's moves landed 37 to 50 ms off the frames), in 3.3 to 5.0 s
  to its last frame drawn (iOS 3.1 to 3.8 to under half a point left);
  the parts bin 282 and 328, 391 and 579, 954 and 1,162 (5 of 6); Saved
  models (12 saves, a 383-point list) 168 and 259 at 0.5 pt/ms, faster
  throws stopping at its foot. Each list 1.00 a point under a drag held
  still, and that drag not gliding. On ada7c2aa More ran to its end on
  every throw (2,090, 1,970, 1,760 points), the bin and Saved models went
  2.00 a point, and the bin glided nothing. Standing still after each
  list, 0 frames drawn in 6 s on both. A tap on More's View folds it.
- `minifig builder by finger` (`MinifigDialog._arrange`, fig257): the
  builder's three columns want 860 units across at the least, and a phone
  has 720 (a tablet held upright too): its figure, Keep and Place in model
  were off a phone's screen. On a phone or a tablet (`Phone.on`) it is laid
  out for the room there is before it shows, and again as the screen turns:
  where the columns fit (900 units across, a tablet held sideways) as on the
  desktop; where they do not, the slots and a slot's choices take turns in
  one column (a slot pressed shows its choices, Back the slots again), and
  on a phone the figure is over them a fifth of the screen tall, with Keep
  and Place in model along the foot, the name on a line of its own and the
  figures kept under the slots. The search row's moulds and Draw a print…
  go on a second line, the colours scroll in a list of their own two and a
  half rows tall (84 at a fingertip each are taller than a phone), and the
  grid's columns are worked out with a fingertip's cell. While the keyboard
  is up on a phone the figure and the colours make way for what the search
  finds (`_make_way`). The same controls moved, never made again; nothing is
  moved on a desktop. The page is told the figure on the bench and whether
  one is held (`bench`, `figure_held` in `window.brickworksState`).
- `tooltips kept inside the window` (`Tooltips.keep_inside`, 2026-10-25):
  every tooltip put up is moved inside the window, and one with a line
  longer than `Tooltips.WIDEST` (480 units, or the window less its edges) is
  laid out as lines that wide (`autowrap` on Godot's own label, once it has
  placed it). A technique's hover text was one line of three hundred
  letters and ran off the window at 1280 (walk256 TQ1). `tooltip_fit_probe`
  rests the pointer on Techniques rows found for "door" and on a part's tile,
  at 1280 x 800 and at 390 x 844, and reads each tooltip's rect against the
  window's. Never over the pointer (above it, else beside it): one over it
  is the pointer's, and Godot takes it away. On a phone or a tablet no
  tooltip comes at all (`PhoneShell`), and none is fitted there: fitting
  each one Godot put up and PhoneShell put away kept a phone drawing two
  frames a second (86 drawn in 40 s against 13).
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
  under them said. Fails on b79d427: the click in one go pressed nothing. On
  Xvfb it moves the system's pointer with its events (as `cursor_probe` does):
  the app's look-again replay (`Cursors._process`) goes where the system says
  the pointer is, and with it left mid-screen no tooltip in the window came.
- `status bar` (`src/ui/status_bar.gd`): along the foot. What was just said, or
  the tool's hint when nothing was; then the parts count and stability, how
  many are selected, the snap and turn step, and how big a stud is on screen.
- `accessibility` (`src/ui/access.gd`, `src/ui/focus_guard.gd`, Settings,
  2026-10-24; docs/COMPETITIVE.md item 14). A screen reader hears every
  control by its name (Godot 4.7's AccessKit: `accessibility_name`, or a
  button's words, a field's placeholder): the toolbar's words and key
  ("Select, V"), a part tile's title and number ("Brick 2 x 4, 3001"), a
  colour's name, a technique's, every dialog's sliders, numbers and fields;
  `Access` names the parts of Godot's own file dialog it leaves unnamed. The
  status line is a live region, read out as it is said. F6 from the model
  goes into the frame, and Tab does while a screen reader runs (without one
  Tab folds the panels, as before: `FocusGuard._tab_in`): the name field,
  then (Tab in a field gives the keys back to the model, as the owner asked;
  the next F6 goes on) the toolbar, the bin's buttons, tabs, parts and
  colours, the view cube's buttons; Tab goes along, arrows walk a row or
  the grid, Return presses, F6 goes back to the model. A click never keeps
  the keys on these (`FocusGuard.by_keyboard`), and `Access` puts every
  button made with no focus in reach as it is made: menus, dialogs, the
  sign-in screen. The sign-in screen and Main's inset dialogs are
  `FocusGuard.OVER`: while one shows, F6 and Tab go into it and Tab in its
  fields goes on (`a11y_keys_probe` walks the sign-in screen offline;
  `BRICKWORKS_API=http://127.0.0.1:PORT tools/probe.sh a11y_keys_probe live`,
  with `tools/web/relay_server.mjs PORT` and .env, signs in by keys alone
  with a minted code and deletes the account). Return on a part takes it with its
  ghost at the middle of the view; W, A, S, D and the arrows move the view
  under it, Return puts it down (`Main._aim_by_keys`). Settings, Interface
  size (85 to 150%, `ShellPrefs.interface_size`) multiplies
  `Main.screen_factor`, as far as the frame keeps 620 units down
  (`Main.sized_factor`: 150% is 140% on a 1280 x 800 laptop); a phone's
  point-sized controls too (`Phone.per_point`; the row of tools shares its
  width and goes to pictures alone where its words do not fit,
  `PhoneShell._share_row`). Settings, Reduce motion: no
  build animation, no shimmer on a waiting picture, no camera easing.
  Checks: `tools/probe.sh a11y_names_probe` (every operable control in the
  frame, the bin's tabs, a selection and 30-odd dialogs and panels has a
  name: 0 of 1,895 without; 666 of 1,888 on m166), `a11y_keys_probe` (from
  launch by keys alone: toolbar, a part, put down, a colour, the view cube),
  `a11y_motion_probe` (each of the three moving, then still),
  `a11y_size_probe` (85% and 150% at 1280 x 800, nothing off the window,
  pictures in shots/a11y_size/); `tools/web/app_a11y_flow.mjs` (preview
  check `app_a11y`: both sizes at 1280 and on a phone at 390, and whether a
  screen reader in the browser hears the app: it does not, Godot builds no
  AccessKit for the web). Orca on the desktop: in a private
  `dbus-run-session` (never the owner's bus) start an Xvfb,
  `/usr/libexec/at-spi-bus-launcher --launch-immediately`, `orca --replace
  --debug-file=FILE -u PREFS` with HOME and XDG_* in a scratch folder, and
  `godot --path . --accessibility always --script HOLD.gd` (a script that
  instantiates `src/main.tscn` and waits: under `--script` there is no
  sign-in); give its window the keyboard with `XSetInputFocus` (no window
  manager) and press Tab through XTest. FILE's `SPEECH OUTPUT:` lines are
  what Orca says: "Model name entry", "New, Ctrl+N push button", ...,
  "Select, V toggle button pressed", and the status line's "opened Car — 61
  bricks" as it is said.
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
- `tour` (`src/ui/first_build.gd`, `FirstBuild`): Build your first model
  (APP_UX A12), a line in the strip along the top of the model, never over
  it. Offered once on a device (`first_build` in `user://shell.cfg`: offered,
  skipped or done), on a first visit, to a person in front of the window once
  signed in, and only while the example car is untouched: never to a viewer,
  a model opened from a link, a phone, or someone whose own model came back.
  Nothing changes until **Start**, which takes the car off for "My first
  model" (`Main._make_room`), or over the person's own model runs File, New,
  which asks first when it is unsaved. **Skip** ends it in one click; Help,
  Take the tour brings it back. Seven steps, each one short line naming the
  key the person's keymap gives (`Keymap.written`) and a frame round what to
  use: a part put down (the bin), turned (Rotate tool, R), coloured (the
  palette), moved (Move tool, W A S D), copied (Clone tool, Ctrl+D), the view
  turned (the view cube; the drag the view preset turns with, or 1 to 7), and
  saved (Save, Ctrl+S); then Done. A step moves on when the model, the view
  or the store shows it done, whatever way it was asked for: it reads the
  model as the step began against the model now, never the input. The last
  line names the assistant only while it is shown. `first build probe`
  (windowed, 1280 x 720; 1400 x 900 by `PROBE_SIZE`) checks the offer by
  itself with the car untouched and nothing covering the model, Skip in one
  click, not offered again in a run of its own on the same data folder, then
  Help to Done by keys and clicks in 25 acts or fewer (a part put down
  unturned, a turn in hand not yet put down and the wheel's zoom each leave
  their step where it is), and each step again another way (File, New over
  a saved model, R on a selection, a colour clicked with it selected, a drag,
  Edit, Copy and Paste, 1, File, Save). `columns probe` checks its first step
  brings the bin out of its fold and frames its parts.
- `assistant on or off` (`src/ui/controls_dialog.gd`, `ShellPrefs.assistant_shown`,
  `Main.set_assistant`): Tools, Settings…, **Assistant (AI)**: "Build by hand
  only" or "Show the assistant", kept on this device (`assistant` in
  `user://shell.cfg`). Off, nothing of AI is anywhere in the window: no
  assistant column or rail (its key form, Sketch first and the connector's
  switch are in it), no Ask Claude in Edit or on a part and Ctrl+K does
  nothing, no View, Assistant or Tools, Claude connector…, no brief or Design
  with Claude in Brick Art, no Claude in Account, the sign-in screen, My
  collection or About, and Build your first model without its last line about it. The connector is held
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
  (`parts_open`, and the right column's tab, `assistant_open` or else
  `properties_open`, for a wide window; `narrow_side`, "parts", "properties"
  or "assistant", for which one a narrow window shows; a first visit opens on
  the parts and the properties, the assistant folded until asked for; a
  layout kept before the right column loads as it was, the assistant open
  being its tab), the model tree and the properties folded and their heights
  in their column (`tree_height`, `properties_height`), the key
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
  The plane is the selection's middle on that axis, on a half stud, so it
  lands on its own footprint. `tools/probe.sh mirror_probe` (headless, ~1
  min): all of Orthanc both ways, each of its figures, its first step on the
  timeline among its neighbours, the same two bricks built between theirs,
  and a reflection onto a part not selected refused. The point a turn goes
  round (`Carry.pivot_of`) was the plane until 2026-10-19: chosen as much by
  the other axis, it put Orthanc's first step a stud over, onto the 2 x 8s
  beside it, and progress_check's mirror step said "no room to mirror it
  there" on every build back to m87.
- `split and merge parts` (`src/assembly/split_merge.gd`, APP_UX2 gap 6): `Alt-S`
  splits the selection by Studio's rules (a plate, brick or tile into 1 x 1s, a
  1 x 1 brick into three plates, a slope into the 1-wide slope of its angle,
  length and height, a curved one into the 1-wide curved one); `Alt-M` merges the
  selected plates, bricks and tiles of each colour into the fewest real parts made
  in that colour (`PartInfo.colors`), biggest first, three plates high a brick, as
  far as it goes in one press (Studio merges once a press). Both are on the menu on
  a part and in Find a command, not in Edit (Edit is at its 25 rows). Each split
  is checked once a part against the part itself (`SplitMerge._fills`: inside its
  box, filling its cover, its studs and the places beneath it kept), so a slope
  is turned the way it slopes; a part a split or merge would run into something
  with is left. One undo; no session tool (`AppTools.WINDOW_ONLY`).
  `tools/probe.sh splitmerge_probe` (windowed 1400x900, `PROBE_SIZE=1280x720`
  too, about 2 min): every bar of APP_UX2 §6 by the real keys, with the joins
  (`SelectBy.connected`) and the lattice read after each.
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
  it — a banner above the model says which, the model staying where it was
  under the pointer, so a second double-click there goes a level deeper
  (view.md's `centred on the model's column`), a click takes one part, a part put
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
- `model tree`: at the top of the right-hand column, over the properties
  (View, Model tree, or its header) lists the
  model and its sub-assemblies inside one another with their part counts. A
  row selects its parts, a double-click edits inside it, `F2` renames it in
  place, its eye and lock hide and lock it whole, and dragging a row onto
  another nests it there (onto Model, back to the top). Folded or open as it
  was left (`outliner_open`). Probe: `assembly_probe`.
- `sections`: a model split as a builder builds it, one section at a time
  (`src/assembly/sections.gd`, `src/ui/sections_ui.gd`). Build, Suggest
  sections (or the model tree's Suggest sections) lists suggestions under
  the tree's rows, numbered in build order, each with its part count: a
  click selects its parts, a double-click or `F2` renames it, dragging one
  onto another or Merge joins it to the one it is held to most, Split
  parts it where it is held least, the tick or Accept makes it a
  sub-assembly, Accept all makes every one in one undo step. How it
  decides: the booklet planner's reading (`Instructions._survey`,
  supports, `_find_assemblies`, `_find_bundles`) and the build check's
  joint graph as Balance builds it (`Stability.contacts` studs, `Joints`
  pins, axles, clips); a sub-model the file has that fits a section and is
  one piece, and the planner's sub-builds, stay whole; the booklet's own
  order is cut near every bag's worth (about one section for every 90
  parts, 2 to 40) where least holds the parts before to the parts after,
  each run split into its pieces so each section is one piece, numbered so
  each comes after what it needs; minifigures are a
  section of their own. `Y` (Build, Break out the section, or the tree's
  Break out) pulls the chosen sub-assembly up off the studs it stands on,
  or out the side of the model it is on, two studs clear, by whole studs
  and bricks, one undo step; `Y` again (or Edit, Put every section back)
  puts each part back exactly. Where each stood is kept on the world
  (`BrickWorld.broken_out`, carried by the history's `sectionout` step) and
  a file is written with every section in place (`BrickWorld.home_of`,
  `ModelStore`). `Shift+Y` (View or Build, Exploded view) draws every
  section apart, lifted by its place in the stack and spread from the
  middle, over 0.6 s, and back; framed on what is drawn, and a click
  picks what is drawn under the pointer (`SectionsUi.pick_drawn` through
  `EditVerbs.brick_at`), so a section is chosen where it is seen. A model of
  600 parts or more is suggested on a worker, with Cancel, the window
  drawing meanwhile
  (`BrickWorld.set_drawn`: nothing of the model moves). Evaluate the
  section… shows the chosen one alone: parts as the parts list counts
  them, lots, weight, one piece by the joint graph and by the build check
  on it alone (`Assistant._checked`), whether it stands on its own base
  (Balance), the studs and pins that join it to the rest and what that
  carries (80 g a stud, Stability; the studs read as the suggestion reads
  them, `Stability.stud_joints` over the section and the parts beside it,
  so two parts whose covers overlap are no stud joint; a pair the lift reads
  only across an overlap, no stud's tip in either, is one pin, axle or clip
  joint, held by its pin, axle, hinge or turntable or seated, there and in a
  suggestion's "joined by": 1793-1's turntable no longer stands on 18
  studs; a part seated in another by no stud and no named joint, 6753-1's
  control stick in its base, is one such joint, weighed as one stud,
  `Sections.SEATED`, and two turned covers that only touch,
  `Stability.beside`, are joined by nothing), and its own steps;
  with its parts list,
  BrickLink wanted list and booklet (`_export_booklet` with the rest left
  out). All of it works with the assistant off. For other code:
  `Sections.graph_of` (the joint graph, static: studs, turns, pins, fixed)
  and `break_out_parts(ids)` for parts that are no sub-assembly. Probes:
  `sections_probe`, and `seated_probe` for parts seated in each other,
  only touching, or turned to each other on real sets (6753-1, 1793-1);
  in a browser, `tools/web/sections_flow.mjs`.
- `swing on a hinge`: `J` / `Shift-J` (or the Hinge tool) turns the
  selection 15° about the joint it hangs from — a hinge's pin, a clip on a
  bar, a turntable's disc: a shaft of a selected part in a bore of an
  unselected one (`Joints.rounds`). It may press only on the part it is joined
  to; anything else refuses it. The parts stand off the grid afterwards, held
  as turned covers (`Builder.swing_selection`).
- `meet on hinges` (`src/assembly/hinge_align.gd`, Properties' `Hinges  Meet`
  with two parts selected; docs/APP_UX.md B4): every hinge, clip and
  turntable between the two (Bodies' tree, each side back to the body both
  hang from) swings so a free end of the one meets a free end of the other
  that takes it — a click hinge's finger in a fork, a pin in its eye, a clip
  on a bar — with the least bending, the new joint's bend counted too, so a
  line of eight hinges closes into a regular octagon. Click hinges end on
  their 22.5° clicks; every part must have room where it ends up and stay
  above the model's lowest point. One step to undo. Otherwise nothing moves
  and the status bar says why: not joined, nothing between them turns, no
  free ends that take each other, "the nearest leaves them N plates apart",
  "they meet only between the hinges' clicks", or what would run into what.
  Probes: `hinge_align_probe` (a ring of eight click hinge plates, a wing
  and its strut, the build check on each, the refusals) and, in a window,
  `hinge_align_ui_probe` (the ring closed in three actions, one Ctrl+Z).
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
  bisects). A gear drives its train by the teeth (`Mechanism`, as Simulate),
  and what hangs on a driven body by a joint of its own goes round with it
  (`Grab._follow_driven`). A closed loop moves as it allows (`Linkage`, below);
  a locked train or a loop with no freedom is said, not moved. While dragging the model
  is drawn moved (`BrickWorld.set_drawn`; revision, lattice and history
  untouched), weighed each 50 ms (`Balance.weigh_pose`): polygon and centre of
  mass on the floor, loaded stud joints tinted, the model leaning 4° when it
  would tip, a status line. Let go: a joint without friction (a pin without
  ridges, an axle, a turntable) swings down under its weight (`Grab.settle`),
  and so does every free joint inside what moved ("2 free joints inside it
  swung down too"); one undo step ("turned the arm, 2 parts, on its hinge to
  45°"), and the status bar says how it stands. A model then past its edge
  falls over (`Topple`, below) in 0.5 s, in the same step. Escape puts it
  back. Past 40 moving parts a frame's room test stops at 10 ms and the rest
  is checked on pauses and, let go, on a worker (`Grab.verify_step`,
  "checked when you pause"), and kept with its cells, bounds and rows worked
  out on a worker (`BrickLattice.cover_for`; Grab 15: 7191-1's keeping frame
  107 ms to 18, `grab_probe -- --only=big`); a stop met and not yet found is dropped once
  the section stands where its whole test finds room (`Grab._shown_on_trust`),
  and a slide drawn on past a stop is not tested again; a press on a big model
  before its joints are read says so. A turned part whose cover is not kept is
  asked where something is, not worked out whole (`Grab._blocked_turned`,
  `BrickLattice.TurnedCover`): `grab_probe -- --check-covers` works each out
  whole too and fails where the two answer differently. Over MCP: `move_part` (degrees=, along=, or to= [x, y, z]
  studs: the part drawn there by its chain, `GrabDrag._chain_for_session`).
  Headless gear check without a pointer: `grab_probe -- --gears` (8020's
  crank turns the sails 1 in 9).
  A copy of a shared sub-assembly posed is made its own first, in the same
  step (`GrabDrag._own_copies`; `grab_probe -- --only=copies`, two alike
  minifigures and move_part). Held still 0.4 s, then dragged: the part by its
  chain of joints (`src/assembly/grab_chain.gd`, "chain" in the status bar;
  `grab_probe -- --only=chain`, a hand and 4096's crane end). Held is what a
  frame saw (`main.gd` `_press_hold`, `src/ui/press_hold.gd`): pressed and
  dragged at once across one 600 ms frame it is an ordinary grab, as in a
  browser drawing a frame a second. The hold is timed from the first frame
  after the one that handled the press, so that frame's own work is never
  held: a press whose own frame does 600 ms of work before the app's
  process (`src/dev/press_frame_work.gd`, as a slow page reads the bodies
  there), then a drag, is an ordinary grab, and so is one whose frame draws
  for 600 ms, the pointer still where it was pressed in the next frame (the
  browser sends the move a frame late), then a drag. Timed from the press,
  or from that frame's process, each was a chain, and grab_flow's flywheel
  on m81's preview said "Chain: the Technic Gear 40 Tooth…" and never spun.
  Turned and turned back over MCP: `grab_probe -- --only=steer` builds a real
  session's buggy (`tests/fixtures/mcpwalk/steering_buggy.json`) and turns its
  steering wheel +30, -60 and +30, back where it was built, the chassis still.
  Two parts askew to each other (`Bodies._askew`) hold by more than one stud
  only where the studs go into sockets or holes (`Bodies._takes_stud`); a
  lone stud the turned part does not take holds nothing (6753-1's fifth
  wheel, tipped 19° on its axle over a chassis brick's stud, turns on its
  axle), and one it takes is a joint that turns on that stud, as a plate
  swung on one stud does (`Stability.turned_to`; `seated_probe`). A
  joint whose line stands upright says its weight does not turn it
  (`GrabDrag.for_session`). `grab_probe -- --only=kart` (in the full run; G8,
  MECHANISMS §17): a session's kart (`steering_kart.json`) turned the same
  way, its front axle checked to turn with the column one for one, then the
  same kart with its front axle put back as a section as the session did,
  made a sub-assembly (`Assemblies.make`), and with its bushes on the deck
  (`steering_kart_bushes.json`). A tyre stands on no baseplate stud (58090's
  tread gaps read as sockets: the turn back swung the chassis, the section's
  turn locked its gears); a part with no socket takes a stud only in a hole
  (`Bodies._no_sockets`: the bush on the deck locked the column). Then what
  holds a part that will not move: a round brick 2 x 2 gripping the column on
  the deck's studs, and move_part and the status bar (`GrabDrag.press`, carried
  instead) must name it and the deck's studs (`Bodies.held_words`); the deck
  and a front tyre locked, the gears lock and both are named
  (`Bodies.what_stays`); unlocked, it turns again (`GrabDrag.is_ready` compares
  the locked parts). `grab_probe -- --only=kart2` (in the full run and in
  `--only=kart`): the G8 re-run session's own kart, saved from its app where
  its turn back failed (`steering_kart2.ldr`), turned +60, -120 and +60, its
  pivot's 24 a third of the wheel's turn the other way each time (a gear on
  studs stands on them only through its holes, `Mechanism._in_a_hole`).
  `grab_probe -- --only=steering` (in the full run): every
  steering in the probe's sets (8020-1_Jeep, 8841-1, 8808-1, 8054-1, 8828-1,
  8062-1) turned +30, -60 and +30 over MCP from where it stands: each moves,
  the rack goes one way then the other, every part back within 0.1 LDU, what
  stays still; `--steer-set=FILE` for another. 42050-1 and 8273-1 too (G9:
  a block with pins on two lines, 48989, is not a lone pin,
  `Bodies._pins_on_lines`). G11 (MECHANISMS §19) adds 42076-1 (half pins in
  a steering rack's groove, `Bodies._in_a_groove`), 8862-1 (a shaft on a
  loop's line, `Grab._thin_on`),
  8832-1 (the round rack 2790a, loose in its holder) and 42043-1 (18942 in
  its housing 18940). Each turns back by the turn measured from where it
  stood. `-- --only=moving` (in the full run): 8074-1's crane on its
  turntable (a cable bends out of the way; G13b: its inner free joints swing
  180° on the first turn, and the turn back turns aside the one it presses)
  and 10220-1's door (what touched as built is forgiven in each later grab,
  as a pair: G13) moved +30, -60 and back, and
  10295-1's right door (G12, MECHANISMS §20: two parts block a move only
  where their exact shapes overlap, `Grab._clear_exactly`), and 6765-1's
  safe door on the hinge only BrickNet's labels name (G14b,
  `Bodies._labelled_hinge`); each also
  checks that no turn stopped where only the two parts' covers met.
  `-- --only=grooved` (in the full run): 8448-1's racer, turned at its
  steering wheel through its column's two 4L universal joints, and 5533-1,
  at its pinion: the rack with holes (32185, 6630) slides on the studs
  standing in its groove and comes back on the next turn
  (`Bodies._grooves_by_shape`; Grab 19, MECHANISMS §30); and 8466-1, turned
  at the pinion at its rack's end +30, -60 and back as the sweep turns it:
  the turn back still turns the loop, and the rack comes back within 0.05
  LDU (a loop carries no pinion off its rack, `Linkage._within`; Grab 22,
  MECHANISMS §36). Both 5533-1 and 8466-1 come back within the sweep's 0.02
  LDU (a loop measured from how it was built, `Linkage._from_built`), and
  8466-1's four universal joints drawn as one part (9244) are each a cross on
  two hinges square to each other (`Bodies._whole_crosses`; Grab 23,
  MECHANISMS §37). `-- --only=kingpin` (in the full run):
  9392-1's steering arm on two balls turns on the line through them
  (`Grab._kingpin`).
  `-- --only=swept` (in the full run): 41999-1 (a pinion lodged where no hole
  names its axle turns on its axis, `Bodies._driving_pinion`) steers as the
  sweep turns it (`_sweep_one`), both ways and back. `-- --only=meets` (in the full run): a move
  stopped by the model names the two parts that met (`GrabDrag._met_words`),
  and (G13) a made arm turned 90° towards a plate over its way stops at the
  plate, which a test of the end alone went through, and the other way stops
  6° round on its hinge's own base (`-- --only=path`). `-- --only=beams` (in the full run, and with
  `--only=moving`): 10205-1's and 10183-1's buffer beam is one body with the
  plate it sits on and turns with it. `-- --only=gapjudge` (or
  `--gap=FILE:DRIVER:MOVER:OTHER` for another pair) writes, for the
  eight stops G12 left (MECHANISMS §20), where the two parts stand, what
  holds the part met, and their exact shapes' overlap each half degree, to
  `gapjudge.jsonl`; `tools/shape_gap.py` (numpy and scipy) sets that against
  the parts' own solids, voxelised with their studs at 0.5 LDU;
  `-- --only=sockets`: 42111-1's steering links (2739a, sockets drawn as
  plain rounds) hang on their towballs by ball joints. Every OMR set with a
  steering: `tools/steer_sweep.py run LABEL` (181 files, four headless jobs
  under heavy, ~20 min; `--only=SET,...`, `--shots` windowed with pictures
  from above) runs `grab_probe -- --only=sweep --list=FILE` and writes
  `sweep_LABEL.jsonl` and `.md` to bench/results/grab13-2026-10-19 (G9's in
  grab9-2026-10-18, G11's in grab11-2026-10-18, G12's in grab12-2026-10-18); `table LABEL --against=OTHER`
  sets two side by side (MECHANISMS §20: 51 of 168 before G12; §22: 55
  before G13). Each row says how far the steering
  arms turned; every shared sub-assembly is made its own before the turns;
  each Godot it starts gets a data folder of its own (`.scratch-data`), never
  the owner's app data (opening a real set saves the parts it carries).
  The other moving things: `tools/move_sweep.py run LABEL` (the OMR files
  with a turntable, a door, ramp, hatch, gate, flap or lid, or a crane;
  `grab_probe -- --only=movesweep`) moves a turntable's top, a door and the
  biggest boom or arm on a hinge, pin or axle +30, -60 and back, and writes
  `movesweep_LABEL.jsonl` and `.md`. Each turn stopped where two parts meet
  is judged again by the two parts' exact shapes, the moving one a degree on
  (a click hinge a click on): `meeting` in its row, "real", "false" (their
  covers only) or "unjudged", and the table splits the meetings so; a thing
  that moves as far as its real parts let it counts as moving to its stop
  (G12). `--shots` runs it windowed under heavy and the GPU lease, with
  pictures of each thing before and at each turn (`move_SET_KIND_*.png`).
  Why a rack does not go: `grab_probe --
  --only=steerdebug --steer-set=FILE [--turn=ID or SET:ID] [--pair=A,B]
  [--links=ID] [--first=ID:DEG,...]`
  prints the rack's joins to the part its pinion turns in, every shaft near
  it, how far a turn's loop closes, where two parts stand and whose studs
  reach which, a part's body's joints (`--links`), after moves made first
  over MCP (`--first`), and pictures of the rack's neighbourhood when
  windowed.
  `-- --only=stays` (in the full run): 42081-1's tyre "23798" named from the
  catalogue, and what stays the biggest body, not its bucket (535 g by its
  box).
  Probe: `grab_probe` (real sets, simulated pointer events; windowed, the
  pointer cases need a window); browser: `tools/web/grab_flow.mjs`. Each case
  starts clean (`_clean_slate`: no button down, drag, grab, part in hand or
  selection left by the last) and presses only once the view has stopped
  easing (`_camera_still`); a case that dies on a script error counts as a
  failure. `-- --only=cases` runs the single-joint cases in the full run's
  order. A turn stopped by the model names the two parts that met, in the
  status bar and in move_part's answer. A tyre scrubs on the baseplate and a
  part that bends (a hose, a cable or rubber band skin) is never in a move's
  way; what touched where the model was built is forgiven in each later
  grab as in the first (`Grab._built_touching`), pair by pair and only
  where their exact shapes overlap as built or one has none; what a moving
  part's cover overlaps where a grab begins is forgiven for that part alone
  (`Grab._pair_forgiven`, G13: 10220-1's door went on through the tile one
  of its parts had stopped at). A loop's own joints turn their two parts
  against each other, and each pair that can meet as its joint turns is
  tested against each other by exact shapes (`Grab._meeting_pairs`,
  `_pair_clear_at`; not a pin, an axle or a round part on the joint's line,
  nor two parts a plane square to it keeps apart), asked only past the turns
  and slides already found clear, and in a loop's drag on the pause, not each
  frame (Grab 15, MECHANISMS §25), and not at all where no piece of one shares
  a place along the line and a distance from it with a piece of the other
  (`Grab._about_line`, `_pieces_apart`, Grab 16: 8808-1's six pairs). A pause
  checks a loop's way 4 ms a frame (`GrabDrag.PAUSE_BUDGET_MS`,
  `Grab.pause_budget_ms`). `-- --only=clipped` (MECHANISMS §26): 4002020-1's
  turntable, whose loop holds a clip on a bar with a ball end, turns +13°,
  -44° and back to 0.0001 LDU; 21019-1's, whose clip fills its handle's bar,
  is locked; neither clip ends into its bar's part by their exact shapes.
- `rigid bodies and joints` (`src/assembly/bodies.gd`): the model as rigid
  bodies (two studs or more, an axle in an axle hole, glue: one body; two
  joints on different lines between two bodies: one body) and the joints
  between them, from `Joints`' rules (studs_in, through, rounds, balls,
  held_otherwise). Resting with no stud in it holds nothing; resting on a
  joint's half with its studs under the foot is carried by it (a hinge brick
  on a turntable's top). A joint between two parts overrides their shared
  studs and cells (turntable top and base, hinge halves, click halves); a
  tyre is one with its wheel (a tyre drawn with no connector by the bore
  `occupancy.ring_bore` gives it), and a stud against a tyre holds nothing
  (rubber, no socket: 8054-1's steering wheel, a rim with its tyre, read as
  held by two dash studs, locked its column); a lone pin is part of the
  first thing it is in.
  tyre is one with its wheel; a lone pin is part of the first thing it is in
  (which pins are alone is read before any is joined). A piece nothing holds
  where it is (no part on the baseplate's studs, none locked; not the
  biggest, at most 300 parts) lodged in another is held by what it is lodged
  in (`Bodies._lodge`, MECHANISMS §16): an axle in a pin's stop bush or a
  joiner, a gear a file carries as a part of its own, a log in a gripper.
  A lone part sharing no cell with anything, where it or what it is in has
  no exact shape, is held by what goes through its middle, else by what its
  box is most into (G13: 8074-1's belt wheel on its axle, 10015-1's magnet in
  its coupling). One standing in round holes of two parts or more (a stud
  or a shaft in a bore no joint names, `Bodies._in_a_bore`) is lodged in
  each of them, and holds them together: 8808-1's side panels, each on two
  headlight bricks' side studs, are one with the chassis (of grab_probe's
  47 sets, only 8808-1 has such a part).
  A hose, a tube or a chain (`Flex.strung`) bends: it closes no loop, carries
  nothing on and is tested for room by nothing (`Bodies.flexible`).
  Racks (MECHANISMS §19): a rack in its housing (18942 in 18940) slides on
  the housing's line ("housing"); studs standing up into a grooved steering
  rack (87761, 64781, and the racks with holes 6630, 6592 and 32185, G12)
  ride in its groove ("groove"), found from the rack's shape wherever it
  has slid to (`Bodies._grooves_by_shape`); a piece with a rack its
  pinion holds slides where it rests instead of being lodged ("rests"); the
  round rack 2790a is loose in its holder; a socket drawn as plain rounds a
  ball's size holds a ball (`Joints.balls`). G14b (MECHANISMS §24): a
  pinion lodged in a piece whose rack it stands in turns on its own axis
  (`Bodies._driving_pinion`); a door, a hatch, a lid, a shutter or a
  window's pane held by nothing hangs on the part it is lodged in, where
  that part is in its piece's biggest body and BrickNet's labels name a
  hinge between the two (`Bodies._labelled_hinge`, `Exact.hinge_between`,
  `Bodies._stays`; door184 added shutters and panes, which were lodged).
  Each piece's anchor: a locked part's body, else what stands on the
  baseplate (a stud in a socket; never a tyre), else the body with the most
  parts, unless a body standing on the floor (within 2 LDU of the piece's
  lowest point, not by a tyre) is heavier (`Bodies.anchor_why`; not the
  heaviest outright, which a shell's box fools; MECHANISMS §18). Studs pressed on a part with no socket hold only in
  its holes (`Bodies.pressed_on`), or in one of BrickNet's holes or tubes
  (`Bodies._in_a_hole_exactly`, G13: a train's buffer beam 4022 takes the
  plate's studs in its cap, above its bottom face, where the catalogue reads
  no socket); a stud's tip is in every part but its own whose cover has its
  cell (`BrickLattice.bricks_at`), of several the first with a socket where
  the stud stands, facing it (`Joints.socket_at`; 9470-1's plate on Shelob's
  wedge turned with the winch axle over it); a stud the lattice finds in two
  parts that turn against each other is in the one its foot meets the face
  of, of those that reach the stud and take it by a socket or a hole (plates
  on 8836-1's Technic bricks held axles 35-70 LDU off that turn in them),
  but where that one has no socket, in the one the lattice found with a
  BrickNet hole for it (`Bodies._sits_on`); why parts are one body is kept
  (`Bodies.joined_by`) for the words of what holds one (`held_words`). Read ahead once a
  revision, on a worker wherever there are threads (`GrabDrag._ready_ahead`;
  from 300 parts until 2026-10-21), the parts' exact shapes read first on the
  main thread; a press before it is done waits for the rest below 300 parts
  (`GrabDrag._ready_now`) and says so from 300. The status bar's weighing
  (`Main._weigh`) is on a worker too. `the builder's frames after a change`
  (`tools/probe.sh ahead_probe -- --most-ms=50`, headless, about 3 min):
  move_part, Ctrl+Z and a click placing a part on the Ducati, 8808-1 and
  42004-1, each act's longest main-thread frame under 50 ms (9 to 18; on
  85bd1c4a 0.17 to 2.2 s), a press while the worker reads taking hold with
  its reading, and one during a session's move saying why it does nothing.
  `grab_probe -- --survey FILE` prints the bodies and joints.
- `moving a body on its joint` (`src/assembly/grab.gd`, `Grab`): one grab's
  state, pure until `commit`: `begin` (what moves, on what, or "rigid",
  "loop", "locked" with `why`), `turn_to`/`slide_to`/`ball_to` (tested along
  the way in steps that move no point more than 2 LDU, `Grab._walk`, and
  bisected to the last pose with room from the first step with none; G13,
  MECHANISMS §22; a loop is put back as it was after the walk,
  `Linkage.kept_state`, so its end is solved as if there were no steps; a
  free joint inside what moves that the model presses is turned aside,
  `Grab._push_aside`; a small section's drag tests its way for 2 ms a frame,
  `walk_budget_ms`, the rest checked on a pause; a loop's turn is put on a
  quarter-degree grid in a drag only, a session's goes where it asks; what
  stands near each moving part is asked of the lattice for its cells and four
  more, at the press, and sifted from that, `Grab._near`, G14a, MECHANISMS
  §23; what stays across a joint is forgiven only for its partner,
  `Grab._across`, a slide tests what its turn's sweeps left out,
  `_turn_only`, and a pair whose covers overlap where a grab begins, one
  with no exact shape, goes no deeper than it began, `_no_deeper`, Grab
  17, MECHANISMS §28, `grab_probe -- --only=bearing` and `--only=path`; the
  joint turned alone's two parts are judged by their exact shapes but the
  pieces its line goes through and what was built into each other, worked
  out at the press and asked along the way where due, a click hinge's at
  each click, `_meeting_pairs`, `_pair_forgives`, `_pairs_due`, hinge77,
  MECHANISMS §35, `--only=hingerange`: a 3937/3938 top stops 6° the wrong
  way and 95° the other),
  `follow` (the pointer's ray to an angle, a slide
  or a ball's turn), `settle` (a free joint down under its weight), `commit`
  (one undo step). `grab_probe` checks each on real sets.
- `closed loops of joints` (`src/assembly/linkage.gd`, `Linkage`; MECHANISMS
  §11): a part held at both ends (Bodies' closing links) moves as its loop
  allows: the loop's joint angles (and slides, and a ball's three turns)
  solved by damped Gauss-Newton with exact derivatives, from the last pose,
  in steps sized by the fastest turning joint (0.5 rad), each started along
  the last step's slope, closed to 0.5 LDU on the way and 0.05 at the end; a
  part that spins on its own (a screw's input and what it drives) solved
  after the rest (`Linkage._reach_parted`; MECHANISMS §15). Stops at the
  nearest pose that closes ("its loop closes no
  further that way"); "Locked: this loop has no freedom" when it closes
  neither a degree one way nor the other. An engine's piston slides in its
  cylinder and its rod's ball end sits in it (`Bodies._slide_within`,
  `Bodies._bores_across`). A clip slides along its bar, and a hole along its
  axle, only as far as the two parts' rounds let it (`Bodies._rounds_room`: a
  flange, a ball end, the plate a handle is on); a loop's clip is held inside
  that by the solve (`Linkage._bounded`), by the two parts' exact shapes where
  they are at hand (`Bodies.exact_room`); an axle's slide and a piston's are
  not (MECHANISMS §26). The joints solved are those between groups of
  bodies their joints hold as one (`Bodies.held_together`: a frame on four
  pins is one), each group placed with its lead, so a steering in a chassis
  of pins takes in the joints that move (42125-1: 35 of 257); an axle's
  slide is damped a thousand times a turn (`SLIDE_WEIGHT`), a friction
  bearing, and an axle a part of the loop slides along in what carries it
  (`Linkage._carried`: `motions_probe`'s observatory, its telescope played
  out and back), a thousand times that; a rack hung on balls alone rests
  on what it lies on (`Bodies._rest_racks`), and a universal joint's
  centre turned off its end's fork, 3L or 4L, is pinned in it (`Bodies._cross_in_forks`), Grab
  18, MECHANISMS §29: `grab_probe -- --only=groups` checks them on 42125-1
  (knuckles 11.5° each way) and a tyre judged by its round on 8820-1. Each
  step starts along the loop's least change (`Linkage._tangent`, Grab 19,
  MECHANISMS §30): `grab_probe -- --only=bigstep` turns 8808-1's wheel 90,
  -180 and 90 in three moves and back within 0.01 LDU. `grab_probe -- --only=loops`: 8020-1_Jeep's
  steering (a four-bar: the rocker against two circles meeting) and 8218-1's
  engine (a crank-slider: the piston against the quadratic, the stroke twice
  the throw); `-- --debug` prints the joints, residuals and the derivatives
  against finite differences. `-- --only=fourbar` (windowed) also takes the
  drag's frames apart: the window's idle frame (30 before the press), the
  renderer's CPU and GPU time, the drag's own work and the batches rewritten,
  and checks the drawing's share of a frame under 4 ms. Whole frames depend
  on the box's load (MECHANISMS §13): read them on a quiet box.
- `racks and their pinions` (`src/assembly/racks.gd`, `Racks`; MECHANISMS
  §12): a pinion standing in a gear rack (the gear table's `racks`: teeth 8
  LDU apart, each rack's pitch line as measured on the OMR's sets) is one
  more equation of a loop in `Linkage`: the rack goes a tooth for each tooth
  of the pinion's turn against it. A 1980s steering turns from its column.
  `grab_probe -- --only=racks` (windowed): 8841-1_Chassis, 8808-1, and
  8054-1 and 8828-1 turned at the column above their bevels (the train's
  meshes offered to the loop, `Grab._train_to_racks`; the pinion's turn
  against the bevels' teeth), the steering turned by the pointer, every frame the rack
  against its teeth and both arms against the track rod's pins and the
  rack's place, by hand; pictures cut over the pinion. A loop that can only
  slide its grabbed joint is driven by the slide: `-- --only=scissor` makes a
  two-stage scissor lift and drags its foot along its rail, the top against
  2·sqrt(160² − x²). The loop pictures hide the drag's balance mark. A gear
  mesh offered to a loop is read against the line between the two gears'
  axes (`Linkage._gear_turns`), so a column riding on joints the loop moves
  turns its pinion exactly: 8062-1's column in its cab of hinges is in the
  racks run (the pinion against the column, both against the column's
  carrier); what carries the driver is held first (`Linkage._carrying`).
- `worms` (`Mechanism.worms_back_driven`, `Grab._worm_holding`; MECHANISMS
  §13): a worm turns its gear a tooth a turn and holds it; a grab on the
  gear's side is refused in words ("Held by a worm … self-locking").
  `grab_probe -- --only=worms` (windowed): 42042-1's winch (1/8), 8063-1's
  sower (1/24, its gear's side a loop), 8049-1's grabber and 8062-1's crane
  winch, each worm turned two turns by the pointer and its gear checked
  against the teeth its name gives every frame, then the gear's side
  pressed. On 8062-1 the winch's shafts go through two universal joints
  (`Bodies.universals`, `Mechanism.join_universals`, `Grab._pose_crosses`;
  MECHANISMS §15): every frame the shaft past each joint turns as the one
  before it (in line, one for one), with pictures of the driveline drawn
  alone before and after (`u_before`, `u_turned`). `--worm-set=FILE` tries
  another set. A joint at an angle turns its far shaft and the gears past
  it by Cardano's relation (`Grab._cardan`; MECHANISMS §16): `grab_probe --
  --only=cardan` (headless will do) makes 8062-1's joint with its far half
  turned 30°, both towers locked, turns the crank two turns, and holds the
  far shaft to tan ψ2 = tan ψ1 cos β worked by hand (the mean is 4.1° off).
- `linear actuators` (the gear table's `actuators`, `Bodies._actuators`,
  `Racks.screws`; MECHANISMS §13): a rod in its actuator or cylinder slides
  and does not turn, never past the stroke the library's contracted and
  extended files draw (`tools/gears.py check`, `tests/test_gears.py`); in a
  loop it is a joint of the tree; the small actuator's input drives the rod
  a stroke over 19.9 turns; the loop's other joints are held by the screw,
  said; a pneumatic cylinder has no screw, so what its rod raises taken
  hold of and turned draws the rod (MECHANISMS §16).
  `grab_probe -- --only=actuators` (windowed): 42081-1's digging arm,
  42024-1's small actuator and 42080-1's crane on its two pneumatic
  cylinders (their rods pinned to the cab: the pointer drags the cylinder
  along its rod), the rod dragged past both ends, the arm
  against the law of cosines by hand, nothing it carries left behind (no
  part that stays lodged in one that moved, with no joint between them; a
  hose bends), the drag's own work a frame (mean and
  95% under 33 ms: about 11 and 18 on 42081-1, 10 and 23 on 42024-1, from
  253 and 148 mean before G6; the worst frame is printed, and passes 33 now
  and then on a loaded box), let go checked and kept in under 10 s (about 6
  and 0.5, from 19 and 3) and kept where it was let go, the arm grabbed and
  refused, the input turned over MCP. Each frame's pose is written to
  `poses_<set>.json` in the results folder, to set a run before a change
  against one after. `--actuator-set=FILE` tries another set.
- `a model that tips falls` (`src/assembly/topple.gd`, `Topple`): let go past
  its edge, the model turns about that edge until another corner of its
  cover reaches the floor, again while it still does not stand, and kept in
  the grab's undo step; "tipped over to the left and lies on its side,
  falling for 0.21 s". How it gets there is `Topple.timed`: a rigid body
  turning about the edge from rest under gravity, its moment of inertia from
  the parts, drawn by the clock (`GrabDrag._fall_frame`). What hangs on a
  free joint in it is held while it falls and swings on as it lands
  (`Grab.land_begin`, `Swing.carry`). Not on a baseplate's studs, which hold
  it ("It does not fall: it stands on the baseplate's studs"), nor a model
  Balance reads as past its edge where it stood.
  `grab_probe -- --only=falling` (windowed): a made crane (a tall arm on a
  hinge on a 2x2 tower) dragged out on no floor falls 42.79° as atan2 over
  every drawn vertex says, in 0.2110 s against 0.2109 by the energy integral
  by hand, no frame below the floor, then stays standing on a baseplate's
  studs; then a crane with a beam 3 on a free pin at its tower's side
  falls (0.1970 s against 0.1974) and the beam swings on as it lands and
  hangs within its friction (`-- --only=landing` alone); pictures before,
  falling, fallen, and a sequence of the landing. `-- --only=tipping` scans
  real sets through move_part. `-- --only=follow`: an arm hung on a driven
  axle turns by the tooth ratio (a made 8:24 train, 8418's B model).
- `swinging on a free joint` (`src/assembly/swing.gd`, `Swing`; MECHANISMS
  §14): let go, a section on a pin without friction, an axle in a round hole
  or a free turntable swings as a rigid pendulum about its joint, a chain of
  free joints together (Newton-Euler in the joints' turns, semi-implicit
  Euler at 1 ms), losing 2μr/d a half swing to the joint's friction, stopped
  dead by the room test, at rest within asin(μr/d) of hanging; drawn by the
  clock (`GrabDrag._swing_frame`, 8 ms a frame at most), one undo step with
  the drag, a click catches it (`GrabDrag.catch`), Escape puts it back;
  move_part runs it to rest and says how it swung.
  `grab_probe -- --only=swing` (windowed): a made beam 7 on a free pin, its
  period against 2π√(I/(m g d)) worked by hand from its parts and lengthened
  by the elliptic integral (under 1%), its loss a half swing against 2μr/d,
  its rest against statics and the settle, its energy never above where it
  was let go; 75° out with a sequence of pictures; caught by a press; over
  MCP; a column in its swing stopping it where a drag stops. `-- --only=double`:
  two beams on two free pins swinging together, the outer coming to rest
  where the settle hangs it, with pictures. The swing's own frame cost is
  checked under 33 ms and written to timings.json. A stop pushes on the
  stopped joint alone (through the inverse mass) and a meet keeps the other
  joints' momentum, so a wheel on a free axle in a stopped frame does not
  spin up; move_part's run stops after `Swing.RUN_MOST_MS` (8 s) by the
  clock, kept where it was last tested, and says so:
  `swing_bound_probe` (headless, by hand without a model; each check fails
  on the code before it). A session's move_part is worked out on a worker
  (`GrabDrag.for_session`, a coroutine: the joints read from copies, the part
  taken hold of, its turn, its swing or settle, its cells; the words and the
  step on the main thread), so the window draws and a move past 20 s answers
  as a job (ToolJobs); a press meanwhile says it is reading the joints
  (`GrabDrag.READING_WORDS`) and does nothing (`is_settling`).
  `src/dev/replay_session.gd` replays a session's calls on the real scene,
  each with its time and its longest frame, a job followed to its answer, and
  the calls with a frame over 100 ms listed at the end; `--idle=MS` waits as
  a session thinks between calls (else the app's own work after a change,
  its weigh and its joints read ahead, falls in the next call). The technic
  lever's Ducati (hang60's calls, 191 of them): before, 13 calls held a frame
  over 1 s, the chassis turned 40° 16.8-19.7 s; after, with `--idle=1000`,
  none, and no move_part over 150 ms. A technic4 loader session (127 calls):
  14 over 1 s before, one after (review_model surface, 1.7 s).
- `coasting when flung` (`Grab.fling_rate`, `Swing.fling`, `Swing.add_geared`;
  MECHANISMS §16): let go while the pointer turns it, a section on a free
  joint starts at the pointer's rate (the slope of the turn against the
  clock over its last steady moves, within 0.1 s; still for 60 ms, or slower
  than 11° a second, is from rest; still is what the frames saw,
  `GrabDrag._held_seen_usec`, so a release read a slow frame late still
  coasts: `grab_probe -- --only=coast`, "let go across a 600 ms frame") and coasts against its bearing's
  friction; a gear train the joint drives turns with it, each gear at its
  ratio (its inertia times the ratio squared, its bearing's friction times
  the ratio); a turntable bears at two thirds of its disc's radius. A joint
  that holds by friction does not coast. The status bar says "coasting at
  1.8 turns a second, 2.3 turns so far"; the step "let go turning at …, it
  coasted … turns in … s against its bearing's friction, and came to rest
  at …";
  `move_part spin=` (degrees a second) over MCP.
  `grab_probe -- --only=coast` (windowed): a made gear 40 on an axle turned
  by the pointer at 1,080° a second by the clock and let go turning, its
  start against the pointer's rate, its coast against ω²/2α and ω/α worked
  by hand from its parts, then the same with a gear 8 it drives (the 8 at
  rest where five times the 40's turn puts it), a picture mid-coast and at
  rest, one undo, move_part spin=720 against the hand form, and 4096's hinge
  flicked the same way staying where it was let go (spin= says it does not
  coast). Each fails with its fix taken out.
- `hoses follow a grab` (`src/assembly/flex_follow.gd`, `FlexFollow`;
  MECHANISMS §18): a pneumatic tube, a ribbed hose, a flex-system hose, a
  flexible axle or a string (Flex's swept kinds, and the same parts LDCad laid:
  165 and 166 read as 71533k01 and k03, 79 and 80 as 71944k01 and k02) whose
  one end is held by a part a grab moves and the other by one it does not is
  read at the press (`Grab._chosen`): its ends off its own end pieces
  (`Flex.ends_of_item`, which way each points told by its pieces, LDCad's
  bulged end being the other way round), the part across the hose's joint
  nearest each tip, its length along its pieces, its bend (`Flex.fit_bend`, as
  Reshape reads one). Each drawn frame (`Grab.drawn`, from every
  `world.set_drawn` of a drag, a swing, a coast, a settle) it is laid again
  between its ends' new places by `Flex.lay_swept`, its bend points carried by
  both ends, the length search started from the last laying's (`hint`): in a
  drag's frame for 2 ms at most (`FlexFollow.BUDGET_MS`, by 50 points), the
  rest carried from their last laying by their ends' moves (`_carry`) and laid
  in the next frames or while the pointer rests; kept, every one in full (100
  points, `FlexFollow.POINTS`). A pose that puts its
  ends further apart than it reaches (straight runs plus the line between)
  is no pose (`Grab._test`): the drag stops there and the status bar and
  move_part say "the pneumatic tube from the … holds it". Kept, it moves piece
  for piece, or is laid afresh in its place (`FlexFollow.swap`) when its layout
  lays more or fewer pieces, own end parts and colours kept, in the grab's one
  undo step. Saved, a hose LDCad laid gets its `PATH_POINT`s and `PATH_CAP`s
  where it now lies (`src/parts/ldcad_path.gd`), in a file written back over
  its source and in one written whole. `grab_probe -- --only=hoses` (windowed
  for pictures; `--hose=made|42080|42043|42050`, `--debug` prints the fit): a
  tube the app lays from the floor to an arm on a hinge, turned 20° (its ends
  in their holes, its length kept), kept, one undo, saved and opened again,
  then a tube 3% longer than the way between its holes stopping the arm
  and named by move_part; 42080-1's arm lowered 6° with its tubes from the cab
  (its T-pieces, held by nothing, hold nothing by a tube's length)
  (saved and reopened, LDCad's path between the new ends), 42043-1's cylinder,
  42050-1's ribbed hoses. What laying them costs a frame is judged by each
  hose laid again where it stands, the fastest of seven layings
  (`FlexFollow.lay_cost`): a hose's mean at most 2 ms, and the budget plus the
  costliest laying within 3.5. The drag's worst frame, a wall-clock figure
  other jobs on the box inflate, is said, not judged (G13b). `--slow-lay=US`
  makes every laying that many microseconds slower (`FlexFollow.slow_usec`):
  at 3000 the cost checks fail, as they must.
  `grab_probe -- --flex-survey FILE...` lists every
  flexible thing held at both ends and the joint between its ends (FLEX rows).
- `grab in a browser` (`tools/web/grab_flow.mjs`): opens a crane from a file,
  takes the arm by mouse where `window.brickworksGrab.handles` says it is,
  drags it up (turns on its hinge mid-drag, kept on release, said; its far
  end, a handle's `far_x`/`far_y`, stands 5 px or more elsewhere), Ctrl+Z
  puts it back (the far end within 2 px), then turns the turret on its turntable, then drags a crank of
  a flat four-bar beside it round and the loop carries the coupler and the
  other crank, then drags a beam 3 on a free pin out and lets go: it swings
  and comes to rest, and the swing's own frame cost is read from the page;
  then takes a gear 40 on a free axle by its rim, turns it round at half a
  turn a second by the clock and lets go turning: it coasts and says how far
  (`coast_deg_s` on the page), its coasting frames' own work under 33 ms;
  then opens a tube laid from the floor to an arm on a hinge
  (`tests/fixtures/grab10/made_hose.ldr`) and drags the arm: the page says the
  tube was laid again (`hoses`, `hose_worst_ms`) and the drag frames' own work
  stays under 33 ms
  (eight handles at most; the page asks for them with
  `window.brickworksGrabAsk`, and the app finds none unless asked); the
  app's frame cost of a drag and the page's longest wait (said with its ratio
  to a frame of the view turning; it fails only past a minute, a frozen page,
  since drawing in software grows with the box's load). `--big=FILE
  --only-big` opens a big model instead, waits for the page to go quiet,
  and times its frames standing still, the page not asking for handles (no
  frame past 100 ms; none found), then asks (found once, its cost said). On
  42082-1 drawn by SwiftShader: 1,201 frames in 20 s, none past 17 ms; the
  build before the page had to ask drew 20, each over a second. The swing
  also reports its frames against turning the view, both in frames the app
  drew a second (`window.brickworksGrab.drawn`; the page's median gap is
  mostly frames with nothing drawn), said and not gated: on SwiftShader on
  this box every drawn frame of the crane, a swing's, a turn's or a drag's,
  costs 0.1 to 1 s with the same WebGL calls (MECHANISMS §14). The swing is
  gated on the app's own work in its frames (under 33 ms), no page wait
  past 5 s, and coming to rest; it and the flywheel's coast on the app's
  own work at the let-go and at the keep (`let_go_ms`, `kept_ms` on the
  page), each under 100 ms (`--keep=MS`), and on the joints read again
  after it (`ready_ms`) under 250 ms (`--read=MS`). The crane's: 0.2 to 0.3,
  15 (the flywheel's 66) and 51 to 82 ms. Grab 15 (MECHANISMS §25): the
  flywheel's keep 30 to 34 ms, against m98's 91 to 152 run beside it, its
  gear's turned cover worked out a line of cells at a time. The page's wait
  at a let-go is SwiftShader drawing the swing's first frames, and grows
  with the box's load: with the browser held to three cores
  (`taskset -c`), m78 and m79 alike waited 8 s (MECHANISMS §14, letgo).
  `--trace=FILE`, `--trace-drag=FILE`, `--trace-view=FILE`
  write Chromium performance traces of the swing, the arm's drag and the view
  turning. In `preview_checks.sh`'s map as
  `grab`. Its waits over 250 ms come under load, on live's build as on new
  ones, mostly in the first drag (MECHANISMS §13): the balance mark's shaders
  are built before the press (`BalanceMark.warm`); what is left is the GPU
  process drawing in software, which a Chromium trace of the drag shows
  (`browser.startTracing` round the drag; long `FireAnimationFrame` tasks
  waiting in `GetBooleanv`).
- `snap onto a joint` (`src/assembly/joint_snap.gd`, `Builder._onto_a_joint`):
  as BrickLink Studio does it. With a part in hand that has a Technic or a
  bar end, aimed at a connector it fits, the ghost goes onto it: a pin into a
  pin hole (collar at the near mouth), an axle into an axle hole or a round
  one (through it, its tip at the far mouth), a beam's or a gear's hole onto
  a pin (against the collar) or an axle's tip (flush), a clip onto a bar
  where the pointer is along it (half-plate steps), a bar into a clip or
  a hollow stud, and a tyre round a rim (2026-10-17): a part's `tyre` end is
  a bore wider than a Technic hole's counterbore or a pin's collar (over 8
  LDU, `JointSnap.WIDE`), across its stud axis, that nothing
  of its cover comes inside, and a `rim` end a shaft that nothing reaches
  outside (`JointSnap._wraps`, the bores or shafts on one line at one size
  as one end); a tyre goes on a rim whose barrel is its hole's size, within
  1 LDU, the middles of their rounds together, either way round (`T`),
  turned about the rim by `R`, and a rim into a tyre the same way. A tyre
  drawn with no primitive, and so with no connector, has its hole as a bore
  (`occupancy.ring_bore`: a ring round a line along x or z through its
  middle), so it is joined to its rim (`Joints.rounds`) and turns with its
  wheel: unjoined, 8020-1's and 8808-1's steering stopped against their own
  tyres once their holes were open (`grab_probe -- --only=fourbar`,
  `--only=racks`). A wheel
  that comes with its tyre on has neither end, and goes on its pin or axle
  by its hub as a rim does. Aimed at the rim's middle. The connector aimed at is the one nearest the pointer's
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
  Brick 1 x 2 with Hole") and what R and T do there. A door, a shutter or a
  window's pane goes on its holder's hinge (door184, 2026-10-23: walk180's
  door stood beside its frame or on its studs): the halves are BrickNet's
  labels from the exact shapes (`JointSnap.hinges_of`; the catalogue's
  connectors have none, a door's pins being drawn as bumps), one half on
  the other of its subtype, laid frame on frame as `Attach.pose` lays them,
  hung shut over the holder's middle (`JointSnap._shut`), R swinging it
  open about the hinge. Aimed at the hinge's line within 12 LDU, or
  anywhere through the holder's box, its hinges nearest where the line
  enters first, the first one with room some way (`JointSnap.framed`,
  `Builder._has_room_on`: a shutter over 3853's middle goes on the hinge
  outside, not a pane's inside). A hinge's halves are let into each other's
  covers where their exact shapes are clear (`Builder._hinged_clear`). In a
  browser a shape that comes after its part was put down measures that
  part again (`Builder._on_exact_fetched`, `BrickGrid.remeasure`). Probe:
  `technic_hand_probe`; `door_probe` (seven doors, shutters and panes on
  their holders, shut where real sets have them, held, and swung by Grab);
  `placing_probe -- only=wheels` puts 8643-1's tyres
  on their rims where the file has them, and wheels with their tyres on a
  wheel pin and an axle; `-- only=doors` the doors and a shutter by the
  pointer, pictures in shots/placing/door_ghost_*.png. In a browser: `tools/web/technic_flow.mjs`, which
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
- `rests by its own shape` (`Builder._sinks_by`, 2026-10-17): a part
  dropped onto what is under it rests where each box of its cover meets what
  is under that box's own columns (`BrickLattice.rise_onto`, as a copy in
  hand rests), not where its box's rectangle first meets something. A part
  that is not a box has room its box has not: 8643-1's two 2420 corner
  plates go round the arm of a wheel holder (6157) in their missing corners,
  and by their box they stood on the arm, a plate up, in the build flow and
  by hand. Only ever lower than by the box, never below what is under it,
  and only where the part is held by its sockets there
  (`Builder._seated_by_sockets`): 5762-1's 4488 stands on a wedge plate by
  the block under half of it, where its sockets are, and the wedge's cover
  is short of its slanted edge under that block, so lowered by its cover
  it sank a plate into the wing. Every plain part, one box across, rests as
  before. Probe: `placing_probe -- only=parts` (the two corner plates
  beside a 6157, as the set has them, aimed at their corner studs; the
  4488 on its wedge; each fails with its rule undone).
- `held below the ground` (`Builder._held_below_ground`, `place`,
  2026-10-17, never moving the model since 2026-10-24): a part the model
  holds below the ground (resting on a part of it with what hangs past it
  lower, on a joint, hung under it, on its side studs) has its ghost there,
  the floor's baseplate not in its way (`room_for(..., held)`,
  `_not_scenery`); put down, it goes there through the floor and nothing
  else moves, and the status line says how far below the floor it reaches
  (`Builder.below`). A model is built up from its first part on the ground,
  and 8643-1's front bracket hangs 4 LDU below that part, its wheels 3 and
  its tyres 8. Until walk239 the model rose to stand on such a part: a 24
  on an axle in a Technic brick on the baseplate lifted the brick off the
  baseplate's studs, and the gears could not be turned by hand. Never under
  the floor's own baseplate. Probes: `placing_probe -- only=parts` (a 2436a
  on the edge of the plate a model stands on: its ghost below the ground,
  put there with the plate unmoved, one undo back); `floor_gears_probe`
  (two 24s on axles in a Technic brick on the floor: nothing moves as they
  go down, they mesh, a press grabs the first on its axle and turning it
  turns the other; red with the rise put back).
- `on studs off the grid, by its own studs, against a side`
  (`Builder._on_studs_off_the_grid`, `_on_its_own_grid`, `_out_from_face`,
  2026-10-18): a part aimed at the top of a part sits on that part's studs
  where they stand off the stud grid (a jumper plate's middle stud, and
  every stud of a part on one: 5762-1's tail fin and the slope on it); a
  part whose box is not whole studs across takes its phase across that axis
  from its own top studs, and a part with no socket on the grid its box's
  middle where the box's count puts one (8643-1's flared cab roof, 50948);
  a part aimed at a side face goes against it by whole studs as a carried
  group does, at the plate the pointer is on, and not up onto what
  overhangs it (8841-1's 1 x 12 beam beside the 1 x 2 under the 1 x 4's
  end). Probe: `placing_probe -- only=wholeset` (the fin and its slope on
  three jumpers, the roof on the cab's two 1 x 4s, the beam beside the
  1 x 2; each fails with its rule taken out). A hole goes on an axle
  anywhere along it, a whole LDU at a time, where the pointer is along the
  shaft (`JointSnap.End.back`, `ways`): an axle and nothing else has the
  shaft behind each tip, and a wheel, a bush or a beam on it slides
  (8841-1's belt wheel halfway along its axle; probe: the same section).
  The build flow's side of it:
  `tests/test_cadtask.py` (a part on its side aimed at by its underside; a
  beam hung from its middle out).
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
- `type a number while moving` (`src/ui/typed_entry.gd`, `EditVerbs._begin_typing`,
  `Builder.pin_hand` / `typed_hand`, `Carry.pin` / `show_moved`, APP_UX B1):
  with a part or a copy in hand (its ghost aimed), or straight after `R` or `T`,
  a digit, `.` or `-` opens a field at the pointer. What is in hand stays where
  its ghost stood; the text is read whole after every key (`TypedEntry.parse`:
  `3x`, `-2z`, `2py`, `-14ly`, `5mm x`, `23.58r`, `30t`, `40/2+1lx`, `2x-1py`; a
  stud the unit, a number alone along `Builder.last_way`, or after `R`/`T` a turn
  or tilt taking their step's place) and shown in hand, red where `room_for` (a
  part) or the lattice (a group) refuses. `Enter` puts it down through `place()`,
  one undo; `Esc` leaves it as before typing. On the model, straight after `R`/`T`
  turned a selection, the turn is undone and the selection lifted where it stood
  to type its turn instead. The field reads only the keys' characters
  (`InputEventKey.unicode`, the keypad's codes), as a browser sends them. While it
  is open it takes every key, so a digit is not a view key then; with nothing in
  hand the digits are views as before. `R` or `T` stays "just pressed" until the
  pointer moves 6 px from where it was pressed (`EditVerbs._input`): a number
  after aiming again moves the part as `R` left it. The field opens under the
  ghost's screen box (`TypedEntry.clear_of`), not on it. Probe: `typed_moves_probe`
  (headers its command; sections reading, clones, wall, typed, sets; `only=` takes
  several, comma-separated). In a browser: `tools/web/typed_flow.mjs` against a
  local export (`tools/export.sh web`, then `tools/web/serve.py build/web PORT
  --parts assets/generated/parts --delay 0`): Q, "3x", Enter, Ctrl-Z, "-1py", Esc,
  read through `window.brickworksState` and `brickworksWords`.
- `typed moves probe` (`src/dev/typed_moves_probe.gd`): windowed 1400x900, about
  four minutes. `sets` opens each set's file for the truth, puts the parts before
  the one typed (found by its line among the file's parts: the runs typed their
  places in a model lifted on the floor), takes it into hand, aims, turns it with
  `R`/`T` to the nearest quarter only if the ghost is not turned as it goes,
  aims again and types the difference; its rows go to `shots/typed/sets.json`
  with the actions counted (point, click, key, a typed number one; characters
  beside). Each section starts on an empty floor.
- `connect by a point` (`src/ui/connect_tool.gd`, `EditVerbs.start_connect`,
  `Builder.connect_end` / `hold_still` / `follow_by`, APP_UX B2): with a part in hand,
  `N` (or the toolbar's Connect, Build's tool row) holds it still where its ghost
  stood (where the view looks if it stood nowhere) and draws its ends
  (`JointSnap.ends_for`: pins, axles, pin and axle holes, bars, clips, tyres,
  rims, hinge halves) as blue rings (holes, clips) and dots (pins, axles, bars)
  on a 2D layer over the view (`ConnectPoints`); the one under the pointer
  lights amber. A click on one makes it the only end the hand goes
  on by (`_onto_a_joint` takes `[connect_end]`), so a 1 x 16 on a pin has two
  ways, not thirty, and of ways joining as many parts `_best_on_joint` takes the
  one above the floor and then the one turned least from how it stood
  (`_turned_from_picked`); a pin or an axle picked goes in from the face
  pointed at while it has room there, not on through to a beam behind for one
  join more (`_best_on_joint` stops after the first way); the click on a point and its release are eaten
  (`ConnectTool._unhandled_input`), and `place()` refuses while points are
  offered. `R` turns about the joint, `T` the other way on, `N` again picks
  another point, `Esc` back to placing. With nothing in hand the tool waits for
  a part: a click takes it off the model into hand where it stands
  (`lift_brick`), and its putting down folds with that into one undo
  (`fold_since`, "connected …"); `Esc` or Undo puts it back. Studs go by the
  stud grid as before (a part with no ends is said so). In a browser the stage
  and the points on the page are `window.brickworksState.connect`.
- `handles on the selection` (`src/ui/handles.gd`, `Builder.drag_begin` /
  `drag_fits` / `drag_room` / `drag_end` / `hung_from`, APP_UX B3): with the Rotate tool, rings
  on the selection; with Move, arrows. They are on the first selected part's own
  axes, the model's or the view's: the tag beside them ("Part axes") says which,
  and a click on it goes to the next (`Handles.frame`). They stand where the
  selection hangs from: the round joint `_joint_of` finds (60 parts or fewer),
  else the stud R turns about (`Carry.pivot_of`), else the middle of a part off
  the grid; Alt-click on the model picks another point (a pin, hole or bar of the
  part there if one is within a few pixels), Alt-click on nothing goes back
  (`EditVerbs.pick_at` → `Handles.pick_pivot`). Rings are 64 to 120 px round the
  selection on the screen. A ring's drag snaps to 90° inside 0.6 of its radius,
  the toolbar's turn step on it, 5° past 1.3 and 1° past 2.0 (`Handles.ZONES`,
  guide circles drawn while dragging); an arrow's to the snap, or 2 LDU further
  than a radius from its line. While the button is held the model does not
  change: the selection is drawn moved (`BrickWorld.set_drawn`), out of the
  lattice (`drag_begin`), each snapped stop and the way to it weighed by
  `room_for` (5° or 4 LDU apart, 3 ms a frame and one part over at most:
  `drag_room` goes on part by part in the frames after, and a part with nothing
  near it is cleared without its cover worked out, `_clear_round`; 92 parts of
  4883-1 turned 90° take about 45 frames of 20 ms, not one of 1.4 s; let go, the
  rest of the way is weighed then; a selection over 300 parts is weighed once
  when let go), and it stops at the last with room, the part in
  the way lit (`EditVerbs._flash`). Let go, one step to undo (`drag_end`, "turned
  1 part +23.58° about its own x"). A digit while dragging, or straight after
  (until the pointer moves 6 px or another key), opens the typed field for the
  handle (`TypedEntry`, routed by `Handles.wants_typing` / `is_typing`): degrees
  for a ring, a length along an arrow (`3`, `2p`, `x 1`); after a drag it takes
  the drag's place in one undo, and Esc puts the drag back as it was let go. Esc
  or a right click while dragging puts it back; the release that follows is eaten,
  or Move would pick the part up. A press and release on a handle with no move is
  the tool's click. Drawn again only when what it shows changed (IdleDraw).
  Probe: `handles_probe`.
- `handles probe` (`src/dev/handles_probe.gd`): windowed, about three minutes,
  `PROBE_SIZE=1280x720` for the small window. `rings`: a 2 x 4 turned 20° and
  tipped 10° turned about each of its own axes by 23.58, -41.2 and 67.5° (click,
  drag, number: 3 actions each, one undo each), and a 1 x 16 on an axle through a
  3701 turned 30° and tilted 25°, its rings on the joint, turned 23.58° about the
  axle, its hole still on it. `arrows`: each of its own axes, on the snap; `3`
  typed mid-drag; Esc mid-drag. `axes`: the tag's three, then each ring and arrow
  of the model's and the view's axes. `pivot`: Alt-click on its end, a turn about
  it, Alt-click on nothing. `snaps`: the view's z ring swept at 0.4, 1.0, 1.65 and
  2.4 of its radius (90, 15, 5 and 1° stops). `typed`: `30` after a drag, then
  `12` and Esc. `stopped`: a 1 x 4 turned into a 1 x 1, a 2 x 4 slid into another,
  each stopped and the one in the way lit. Pictures in `shots/handles/WxH/`.
  `cadtask_frames` times the rings drawn on 100 parts while the view turns
  (`handles`) and one dragged round (`handle_drag`).
- `connect probe` (`src/dev/connect_probe.gd`): windowed, about five minutes;
  `PROBE_SIZE=1280x720` for the small window. `column`: 8841-1's parts 1 to 20
  from the file, the column taken, aimed at its pin, `N`, its end hole, the pin,
  a click (bar 6 actions), against the build flow's 25 presses of `T`/`R`
  without Connect; one undo; another hole puts it on the pin by that hole. `turned`: a
  1 x 16 by its fourth hole onto a pin in a 1 x 4 turned 30° and tilted 25°, `R`
  about the joint. `through`: a 3L pin into the front hole of two 1 x 4s,
  turned and tilted, through both; the belt wheel by its axle hole onto each end
  of an axle through a turned 1 x 4, where it is pointed at. `model`: the toolbar's Connect on a column lying on the floor,
  `Esc` puts it back, then moved onto its pins in one undo. `walk`: 8841-1's nine
  joint parts of section 9's 25 by Connect, counted, and the run's 744 actions
  with them in (each part its run's take and colour overhead plus Connect's
  count less the tile's click the overhead holds, where that is fewer and lands
  where the file has it; bar 18 a part). The view turns to the side the joint is
  in sight from (`_look_at_joint`), and the point picked is the one whose hole's
  middle is on the other's shaft (`_gap`): #17's pin into the back of its beam,
  #25's belt wheel by its hole on the axle, each a check. Rows in
  `shots/connect/walk.json`, pictures in `shots/connect/WxH/`.
- `set walk probe` (`src/dev/setwalk_probe.gd`): windowed, about ten
  minutes for both sets; `PROBE_SIZE=1400x900` for the big window. Builds
  8841-1's 25 walk parts (section 9's order) and 5762-1's first 25 from the
  set's bin: the bin's search clicked, the set's number typed, Build from it;
  then each part's tile (wheel notches, or the scroll bar dragged when it is
  more than a row off), `R` and `T` to its turn, the view by its keys or the
  cube, the pointer aimed with up to four corrections and a click, a joint
  part by its joint or by Connect (`N`, its end, the point it goes on), and
  a typed rest (`-1lz`, Enter) where the pointer cannot slide it. Every
  input is counted as CADTASK counts it (a click elsewhere a point and a
  click, a key or character 1, a wheel notch 1, a scroll-bar drag 3); the
  view and the turns are judged uncounted and then pressed counted. Bar:
  12 actions a part or fewer for each set, and every part exact (the set's
  number and colour, place to 0.05 LDU, turn to 0.002 or one the part looks
  the same in, by its own mesh). `-- only=8841-1|5762-1`, `shots=1` for
  pictures in `shots/setwalk/WxH/`, `from=library` for the same walk taken
  from the whole library (search, the number, the tile, the swatch), the
  figure before the set's bin. Rows in `shots/setwalk/<set>.json`.
- `typed place and hinge` (`src/ui/inspector.gd`, `Builder.move_selection_by`,
  `Builder.hinge_angle`, 2026-10-17): Properties' X, Y and Z move the
  selection by exactly the difference typed, to the hundredth of an LDU
  (whole cells go through `move_selection`, which keeps each cover); they
  moved by whole 2 LDU cells only. Hinge, shown only when the selection
  hangs from a round joint (`Builder._joint_of`: a hinge's pin, a clip on a
  bar, a pin or an axle in a round hole), is its turn about that joint in
  degrees off square; a number typed swings it there (`swing_selection`, as
  J does by 15). And a part aimed at the studs, the underside or the side of a part
  that stands square but off the 2 LDU lattice is put in that part's frame
  (`Builder._in_frame_of`: the part's place past its cell added to what
  the lattice found, since its cover is counted from that cell), where it
  went up to a cell off. Probe: `offgrid_probe` puts the 39 parts the CAD
  task's three sets have off the grid through the interface, part by part:
  8841-1's two pans (each 4262 onto the axle, Hinge typed to 23.58,
  its slide along the axle typed; the pins, 3651s, plates and the second
  4262 aimed and clicked), its axle 1 LDU along, 5762-1's lights and
  propellers, 8643-1's wheels and tyres; each against the file to 0.05
  LDU and 0.002 of its matrix, rows in `shots/offgrid/offgrid.json`. A part
  the run cannot put is put from the file for the parts after it. 8643-1's
  eight tyres go on their rims by their ghosts (`snap onto a joint`), their
  holes open (`tools/ldraw/occupancy.py`: a seam counted once, a tyre's
  hole carved out of a coarse cover).
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
- `bands and springs by hand` (`src/assembly/bands.gd`, the tool's part in
  `src/ui/flex_tool.gd`, LDCad's path and spring the reference): a rubber belt
  (85543, 85545, 85546, u151) or a shock absorber picked in the bin opens the
  flexible part tool on it instead of putting it down (`Main._on_part_chosen`,
  `FlexTool.lays_part`); a bare spring is Build, Hose, tube or chain…, Spring
  or shock. A band: click the pulleys, wheels, bushes or axles it goes round in
  order (pointing lights one yellow; a groove before an axle). Each click lays
  it again: tangent runs and arcs (`Bands.loop`), each round wrapped on the
  side the order turns at it, its centreline the band's half thickness out of
  the groove measured off the part's mesh (`Bands.round_of`, so it needs a
  renderer: a headless run finds nothing round). The band is "The band that
  fits" (the longest no longer than the loop) or one chosen; slack or more
  than twice stretched is said. A spring: two clicks on pin holes, pins, axle
  holes or axles; its coil gets as many turns as its length gives at its
  pitch, and keeps them when stretched or squeezed; a shock is its cylinder,
  coil and rod on pins beside the holes, 88 to 110 LDU between its eyes. Both
  are sub-assemblies of pieces the app makes (`bw-belt-<band>`, `bw-coil-
  <spring>-<turns>`, saved inside the file as LDraw can read them, never in
  the bin), counted as the real band or shock. Making or reshaping is one undo
  step however many clicks. Nudging or moving a part one is on lays it again
  there in the same undo step (`FlexTool.follow_moved`, from
  `Main._on_model_edited`); its pieces never stop that move
  (`Builder._only_bands`). Reshape reads one back off its pieces. Probe:
  `springs_probe` (windowed; `PROBE_SIZE=1280x720` for a laptop).
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
  part, a click, and `E` once a step's parts are down. A step's parts go
  lowest first, but a part whose middle is inside a bigger part of the step
  after the smallest such (`handOrder`, from the catalogue's boxes; a part's
  middle is its box's, not its origin, which is a plate's top): a pin
  after the brick it goes in; and of those, the lowest that is held by what
  is down already (into it, on it or under it, not only beside it), an
  earlier step's parts, this step's put before it or the floor, asked in a
  swung part's own frame where it is off the square, and
  a part that touches before the part its middle is in (`handOrders`): a
  balance's pans built down from the arms they hang on, a pin, its
  connector, the plates, not their plates first in the air. The pointer goes first under the
  part's origin, at the bottom of the part (`footOf`: the spot on what it
  stands on, as a person points there), then at the origin itself, as it
  first did; a brick's origin is the top of it, and aimed there a 1 x 4
  brick on a stack one stud wide went past the stack (8841-1, 2026-10-17).
  A part off the 24 turns or off the whole LDU is held at the nearest of the
  24 and tried, not skipped: on a joint the app swings it onto a second one
  and puts it in the frame of a part off the lattice. A part with holes and
  no pin of its own is aimed at the pins over its place on the page last,
  when the studs would not take it (a Technic brick on its side; `within`),
  and on a joint a ghost
  turned as the file has it but along the joint from its place is slid
  there by the pointer, as a wheel along its pin. A part still not down is
  tried again from its own side of the model (a view key, 1 to 4, tipped
  up 20 degrees by Up twice, and 0 after: a wheel on the far side's pin is
  behind the body; `sideKey`), a part near the middle from the side it
  leans to; the view waited for until it stops moving (`settledView`). The
  foot is along the part's own down, and for a part on its side a stud's
  height out from its underside (a light in a clip's ring). Before typing,
  the part is aimed at the faces of the parts down it meets
  (`contactsOf`, `atContacts`: a side at the lowest plate they share, an
  underside from below with the model framed first). Of parts that hang
  at one height the most held goes first, and a plate that hangs waits for
  the parts of its step it also hangs from (`tests/test_cadtask.py`;
  docs/CADTASK.md section 9).
  Where the pointer cannot say it, the part goes down where its ghost may go within 60 LDU of its
  place, is selected by a click on it, and its Hinge (its swing off square
  about its joint, worked out from the file's turn, either sign) and X, Y, Z
  are typed in Properties (`putNearAndType`, `typeTo`), as offgrid_probe
  types them; read back from where the app says the part stands
  (`brickworksState.put`), and undone if it does not come to its place. A part that goes into or round another's
  (`brickworksState.held_ends` has a pin, an axle, a tyre or a rim) and is
  not where the file has it at the first aim is aimed at the joints on the
  page that take it (`brickworksState.joints`), nearest where it goes
  first, and on one, R and T until its ghost stands at the file's place and
  turn (`onItsJoint`, `ghost_pose`): a pin into its hole, not aimed as a
  brick (8841-1's pins, 2026-10-17). A ghost on a joint is put down only
  turned as the file has it, else, standing in the file's place, R and T
  there first: a pin the other way round in its hole stands in the same
  place (four ways onto a pin: either end in, from either face). The comparison takes each
  kind of match (exact, recoloured, turned, moved) over the whole file
  before the next, so a part not built cannot take an exact one's as
  moved. At the end, Right on
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
# a long hover text inside the window: Techniques for "door" and a part's
# tile, at 1280 x 800 and (PROBE_SIZE=390x844) as a phone is wide
tools/probe.sh tooltip_fit_probe
# several bricks worked on at once, and taken back at once
godot --headless --path . --script src/dev/select_probe.gd
# a part found in the Boutique Hotel: the list's pictures, a row clicked (57
# selected, framed, said), Select by, Part number or name… typed key by key
# ("blue 1x2 brick", "3004"), Escape, look_at_model part=; then Orthanc's
# 1,074-piece row against Select all, longest frame (-- --no-time, --time-only,
# --rounds=N; on a base checkout only Select all). shots/findpart_*.png
tools/probe.sh find_part_probe
# Find on the Cat D11 (42131-1, 188 sub-models) opened as the Library opens
# it: "liftarm 1 x 5" and Enter (98), "11478" and Enter (49, all inside
# sub-models), a row clicked (14 black), a row clicked twice (35 yellow;
# on base 0: the second click went into the sub-model under the pointer).
# shots/findsub_*.png
tools/probe.sh find_submodels_probe
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
# by the processor's time, against the same frames with nothing selected; and
# selecting all of it, by the main thread's time
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
# a door, a shutter and a pane each pointed onto its holder's hinge, shut where
# real sets have it, held by check_design and swung by Grab (seven pairs)
godot --headless --path . --script src/dev/door_probe.gd
# every part the CAD task's three sets have off the grid (39) put where the
# file has it through the interface: aimed and clicked, Hinge or X, Y, Z
# typed in Properties where the pointer cannot say it (-- only=5762|8643|8841)
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
  --resolution 1400x900 --script src/dev/offgrid_probe.gd
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
# sections on four real sets (21016-1 one model, 31025-1 its author's
# sub-models, 42093-1 Technic, 10179-1 big): suggestions cover the model,
# each connected and one piece by the build check alone, parts and weight
# adding up; accepted in one undo; broken out and put back to the bit, one
# undo each, the file written meanwhile unchanged; the exploded view moving
# nothing; suggest/evaluate/make/break out over MCP. --shots=DIR for the
# GPU's pictures (windowed, under xvfb-run)
godot --headless --path . --script src/dev/sections_probe.gd
MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
  --resolution 1400x900 --script src/dev/sections_probe.gd -- --shots=shots/sections
# ...and in a browser, by clicks and keys on 21016-1: suggested, renamed,
# split, merged, accepted, evaluated, Y out and back, undone and redone,
# Shift+Y apart and together
node tools/web/sections_flow.mjs --url=<preview>/app --bypass=… --out=shots/sections_web
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
# a band from the bin round two wedge belt wheels and three, within 1 LDU of
# the tangents and arcs by hand; turned and tilted; following a wheel nudged;
# a spring stretched 4 to 6 studs keeping its turns; a shock; saved and opened.
# Pictures and the saved file in shots/springs/
bash tools/probe.sh springs_probe; PROBE_SIZE=1280x720 bash tools/probe.sh springs_probe
```

Proves it when: each exits 0 with no `FAIL` line, and ends on its sentence —
`snap` says "hand placement lands where the assistant would put it",
`springs` says "springs: bands round two wheels and three, ...",
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


### Gears put in mesh by hand

`tools/probe.sh gear_mesh_probe`: each gear pair is pointed onto its axles the way the editor places it, the second seats where it meshes (GearMesh, src/assembly/gear_mesh.gd), and Grab turns one: the other turns at the teeth's ratio. Spur 8/12/16/20/24/36/40, double bevels at right angles, a worm with a 24, a 24 in a crossblock. Fails on a build before gears186 (34 of 42), passes after; ends "gear_mesh probe:" with its count.
