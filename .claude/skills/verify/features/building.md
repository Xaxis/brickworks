# Building

Pointing at a stud and getting a brick there, selecting several, taking it back.

<!-- covers: scene:main, ui:place and remove, ui:box select, ui:selection edits, ui:undo and redo, ui:copy paste and duplicate, ui:move and turn a selection, ui:select by colour part or connection, ui:hide and show only, ui:menus and toolbar, ui:tool modes, ui:properties panel, ui:status bar, ui:snap and turn step, ui:lock parts, ui:stud grid, ui:tour, ui:remembered layout, ui:replace part, ui:undo history, ui:mirror a selection, ui:place under a part and on side studs, ui:swing on a hinge, ui:sub-models by hand, ui:measure -->

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
  is `Delete` (or the Delete tool): the right button is for looking, never for
  acting. The mode is always on the toolbar (Select or Place lit, Place's
  tooltip naming the part), in the status bar's hint and in the pointer.
  `tools/web/controls_flow.mjs` counts a person's first tasks in clicks and keys
  on a build, the old way (`--recipe=old`) or this one.
- `box select`: drag on empty space, and every brick whose screen position falls
  inside the box is selected. Releasing over a panel still ends the box.
- `selection edits`: with bricks selected, `C` paints them the current colour,
  the arrow keys and W A S D move them across the ground by the snap, Page Up
  and Down raise and lower them, `R` turns them by the turn step and `T` tips
  them over, `Delete` or `Backspace` removes them. `shift-click` or `Ctrl`-click
  adds to the selection; `G` takes the part under the pointer into hand, `X`
  lifts it off into hand.
- `undo and redo`: `Cmd/Ctrl-Z` and `Cmd/Ctrl-Shift-Z`, over placements, removals,
  paints, nudges and whole assistant designs. Undo belongs to the model it was
  recorded against: open a different model and the stack goes with the old one,
  and so does the selection (its ids would name the new model's bricks).
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
- `hide and show only`: `H` hides the selection, `Shift-H` hides everything
  else, `Alt-H` (or `H` with nothing selected) shows all. Hidden parts are not
  drawn, the pointer passes through them (`BrickLattice.unseen`) and boxes and
  `Ctrl-A` skip them, but they still take up their room. The timeline's end
  puts them back hidden.
- `menus and toolbar` (`src/ui/shell.gd`, `src/ui/toolbar.gd`): the bar across
  the top holds File, Edit, View, Build, Tools and Help, the model's name and
  Account; every command is defined once in `Shell._define` with its words, its
  key (shown beside it in the menu, never answered by the menu: the keys stay
  the app's own) and whether it can be used now — greyed when not, ticked when
  it is a setting that is on. File: New, Open, Open recent, Import (LDraw,
  Studio `.io`; LDD `.lxf` greyed, not yet), Save, Save as, Export, Instructions,
  Clear, Account, Quit. The toolbar under it: New/Open/Save, Undo/Redo/History,
  the tools, Copy/Paste/Mirror/Select by/Show all, snap and turn step, grid,
  orthographic, fit and three views, Measure, Properties, Timeline,
  Instructions, Parts list — each tooltip its name, key and what it does.
  Narrower than it needs, it folds its least-needed groups (all in the menus
  too); on a phone the file, history and tools stay.
- `tool modes` (`EditVerbs.mode`): Select (the default) and Place (a part in
  hand), and Move, Rotate, Hinge, Clone, Paint, Hide, Delete — a click on a part
  does that tool's one thing to it, or to the whole selection when the part is
  in it (`EditVerbs.click`). The tool in use is lit on the toolbar and ticked
  in Tools. Only Place shows the ghost; a part carried by a drag, Move or Clone
  shows its own. `V` is Select, `Q` Place; `Esc` closes whatever is up and goes
  back to Select with nothing in hand, in one press.
- `properties panel` (`src/ui/inspector.gd`): over the model's top right, under
  the axes. One part: its name, LDraw and BrickLink numbers, its colour by
  LDraw's name and code, LEGO's name and number, BrickLink's and Rebrickable's;
  X, Y, Z in LDU and its turn in degrees, typed over or stepped to move or turn
  it (refused and put back where there is no room); what it is joined to,
  which way its studs face, its sub-model, its step in the instructions (models
  of 600 parts or fewer) and whether it is locked; Joined, Lock, Hide. Several:
  how many of what, the colours, the size in studs and bricks, the group's
  corner to type over. Folds to its header; nothing selected is just the header.
- `status bar` (`src/ui/status_bar.gd`): along the foot. What was just said, or
  the tool's hint when nothing was; then the parts count and stability, how
  many are selected, the snap and turn step, and how big a stud is on screen.
- `snap and turn step`: the toolbar's Snap (stud, ½ stud, ½ plate, free) sets
  where a part in hand or a carried group can land across the ground
  (`Builder.snap_across`) and how far the arrows nudge a selection across and,
  with Shift, up (20/8, 10/8, 10/4, 2/2 LDU). Turn (90°, 45°, 15°, 5°) is how far
  `R` and the Rotate tool turn a selection (`Builder.turn_selection_by`; off a
  right angle the parts stand off the grid as turned covers). The part in hand
  always turns a quarter.
- `lock parts`: `L` (Edit, Lock the selection) locks it: no click, box,
  select-by, tool, paint or removal touches it until `Shift-L` unlocks
  everything (`Builder.locked`). Not saved with the model; Open forgets it.
- `stud grid` (`src/ui/stud_grid.gd`): View, Stud grid, or the grid button:
  lines between the baseplate's studs, every fourth brighter.
- `tour` (`src/ui/tour.gd`): Help, Take the tour: eight cards, each lighting a
  part of the window (menus, toolbar, parts bin, the model, properties, status
  bar, assistant) with the rest dimmed; Next/Back or the arrows, Esc leaves.
- `remembered layout` (`src/ui/shell_prefs.gd`): the panels open or folded, the
  properties, the key strip, the grid, the snap and the turn step are kept in
  `user://shell.cfg` and come back next time; a narrow window still folds the
  panels without forgetting how they were. Not read or written under
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
- `sub-models by hand`: `Ctrl-G` (or Build, Make a sub-model) asks for a name and makes
  the selection a sub-model of its own — the group an `.mpd` is written by and
  the booklet builds one at a time; `Ctrl-Shift-G` takes it out; Select → Same
  sub-model takes all of one from any brick of it. One step to undo
  (`Builder.name_group`, a `regroup` history step).
- `swing on a hinge`: `J` / `Shift-J` (or the Hinge tool) turns the
  selection 15° about the joint it hangs from — a hinge's pin, a clip on a
  bar, a turntable's disc: a shaft of a selected part in a bore of an
  unselected one (`Joints.rounds`). It may press only on the part it is joined
  to; anything else refuses it. The parts stand off the grid afterwards, held
  as turned covers (`Builder.swing_selection`).
- `place under a part and on side studs`: aimed at a part's underside, the part
  in hand hangs under it, the top of its body against it (never below the
  ground). A part tipped with `T` so its underside faces a wall with studs on it
  (a brick with studs on its side) goes onto those studs: a socket on the stud
  nearest the pointer, flat on the face (`Builder._onto_side_studs`).

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
godot --path . --resolution 1400x900 --script src/dev/feel_probe.gd
# what a dragged box catches, which needs a camera with a viewport to project into
godot --path . --resolution 1200x800 --script src/dev/marquee_probe.gd
# several bricks worked on at once, and taken back at once
godot --headless --path . --script src/dev/select_probe.gd
# building by hand as a person does: copy, paste, duplicate, cut, move, turn,
# select by, hide, the menus, the toolbar and its tools, the properties, the
# status bar, the tour, replace, history, the parts shelf, the seat offer and
# a 1280 x 720 window — every step a key or a click, with pictures
# in shots/handbuild/
godot --path . --resolution 1400x900 --script src/dev/handbuild_probe.gd
# undo belongs to the model it was recorded against
godot --headless --path . --script src/dev/history_probe.gd
# where a brick lands when you point at a stud
godot --headless --path . --script src/dev/snap_probe.gd
```

Proves it when: each exits 0 with no `FAIL` line, and ends on its sentence —
`snap` says "hand placement lands where the assistant would put it",
`handbuild` says "by hand: ... all work as a person uses them". Look at
`shots/handbuild/*.png` too: the ghosts in their colours, `shell.png`,
`edit_menu.png`, `tools_menu.png`, `select_tool.png`, `properties.png`,
`grid.png`, `tour.png`, the Select by and History menus, the seat offer and
the 1280 x 720 window. In a browser, the deploy's `fit_check.mjs` finds New
and Save on the toolbar at every size.

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
- **New `class_name` files need `godot --headless --path . --import --quit`** before
  a probe can name them; a checkout's class cache is only refreshed by an import.
