# Building

Pointing at a stud and getting a brick there, selecting several, taking it back.

<!-- covers: scene:main, ui:place and remove, ui:box select, ui:selection edits, ui:undo and redo, ui:copy paste and duplicate, ui:move and turn a selection, ui:select by colour part or connection, ui:hide and show only, ui:edit bar, ui:replace part, ui:undo history, ui:mirror a selection, ui:place under a part and on side studs, ui:swing on a hinge, ui:sub-models by hand -->

## Sub-features

- `scene:main`: the one scene. It restores whatever was on the baseplate last
  time, falls back to a sample model, lays the baseplate under it and frames it.
- `place and remove`: a left **click** places the ghost brick; right-click removes
  the brick under the cursor. A left **drag** draws a selection box and places
  nothing — that distinction is the whole fix for "the controls feel like shit".
- `box select`: drag on empty space, and every brick whose screen position falls
  inside the box is selected. Releasing over a panel still ends the box.
- `selection edits`: with bricks selected, `C` paints them the current colour,
  the arrow keys move them, `Delete` or `Backspace` removes them. `shift-click`
  adds to the selection; `G` picks a brick's colour, `X` lifts.
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
  Select button's menu takes the same colour, the same part, both, everything
  joined by studs (a brick beside another is not joined; a sideways part is
  across its stud axis), the opposite, all, none. The baseplate is never taken.
- `hide and show only`: `H` hides the selection, `Shift-H` hides everything
  else, `Alt-H` (or `H` with nothing selected) shows all. Hidden parts are not
  drawn, the pointer passes through them (`BrickLattice.unseen`) and boxes and
  `Ctrl-A` skip them, but they still take up their room. The timeline's end
  puts them back hidden.
- `edit bar` (`src/ui/edit_bar.gd`): the verbs as buttons down the left of the
  model, each calling what its key calls (`EditVerbs.press`), with a tooltip of
  what it does and its key; the ones that need a selection are faint without
  one. Two columns when the window is too short for one. Not on a touch screen,
  where TouchTools is.
- `replace part`: Replace swaps every selected part for the part in hand, each
  in its own colour, centred on the stud grid for its own footprint and standing
  where the old one stood. One step; a part with no room is left.
- `undo history`: History lists the steps in words, newest first ("swapped 2
  parts for Brick 2 x 3", "painted 2 parts"); choosing one goes back to before
  it (`Builder.undo_steps`).
- `mirror a selection` (`src/assembly/mirror.gd`): `Shift-M` or Mirror makes the
  selection its mirror image left to right as the view sees it, in place, one
  step. A reflection is not something plastic can do, so each part goes where
  its reflection would and is turned to look reflected; a handed part (a
  "Left"/"Right" in its name, a wing or wedge plate) becomes its other hand.
- `sub-models by hand`: `Ctrl-G` (or Make a sub-model) asks for a name and makes
  the selection a sub-model of its own — the group an `.mpd` is written by and
  the booklet builds one at a time; `Ctrl-Shift-G` takes it out; Select → Same
  sub-model takes all of one from any brick of it. One step to undo
  (`Builder.name_group`, a `regroup` history step).
- `swing on a hinge`: `J` / `Shift-J` (or Swing on the edit bar) turns the
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
# select by, hide, the edit bar, replace, history, the parts shelf, the seat
# offer and a 1280 x 720 window — every step a key or a click, with pictures
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
`shots/handbuild/*.png` too: the ghosts in their colours, the edit bar, the
Select and History menus, the seat offer and the 1280 x 720 window.

For the scene itself, launch it and read the brick count in the corner: with
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
