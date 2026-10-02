# Building

Pointing at a stud and getting a brick there, selecting several, taking it back.

<!-- covers: scene:main, ui:place and remove, ui:box select, ui:selection edits, ui:undo and redo -->

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
  recorded against: open a different model and the stack goes with the old one.

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
# undo belongs to the model it was recorded against
godot --headless --path . --script src/dev/history_probe.gd
# where a brick lands when you point at a stud
godot --headless --path . --script src/dev/snap_probe.gd
```

Proves it when: each exits 0 with no `FAIL` line, and ends on its sentence —
`snap` says "hand placement lands where the assistant would put it".

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
