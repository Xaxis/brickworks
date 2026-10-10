# Model I/O

Whether what you built is still there tomorrow, and still means the same thing.

<!-- covers: lib:save and reopen, lib:ldr read and write, cli:export a model -->

## Sub-features

- `save and reopen`: the app writes what is on the baseplate to `user://` and
  restores it on start-up — bricks, colours, orientations, sections and the
  camera. A design that fails must leave the model it was asked to change alone.
- `ldr read and write`: real LDraw `.ldr`. Written files open in other LDraw
  tools, and files from them open here.
- `assemblies in the file`: a brick's `group` — the assembly a design named,
  tagged as the run ends (`Assistant._tag_assemblies`), or the sub-model it was
  read from — goes out as an `.mpd` with one sub-model per group, titled as the
  design wrote it ("north-east tower" in `north_east_tower.ldr`), and comes back
  in with every brick in its group. The booklet builds by those groups and names
  them. `store_probe` asserts the round trip and the named parts.
- `a model's name, and a new one`: `ModelStore.title` is the model's name — set
  by Save, read from an opened file's first line (a placeholder such as
  "Working model" falls back to the file name, the autosave's to Untitled), and
  written into the autosave, so the app reopens a saved model under its name.
  It wrote "Working model", and the bar took no name from what it opened: the
  owner reloaded a saved, named model and was shown Untitled. The name shows in
  the browser tab and the window title (`Main._show_name`). New (Ctrl+N on the
  desktop) begins an empty baseplate, Untitled, with a fresh chat; it asks first
  when the model is not saved as it stands (`has_unsaved_work`: Untitled with
  bricks, or bricks unlike the saved file's). There was no way to begin another
  model. `project_probe` (headless; puts this machine's autosave back) and
  `tools/web/project_flow.mjs` (types a name, saves, reloads, reads the tab,
  presses New).
- `made parts in the file`: a model that uses a part made in the element
  maker carries it as an LDraw `0 FILE bw-….dat` section, and opening one
  builds the part first — see [elements](elements.md). `element_probe` saves
  three, reopens them into a fresh library, and has the Python reader check
  the file.
- `export a model`: `--model=<in> --out=<out>` opens, re-exports and quits, which
  is also the shortest round-trip proof there is. Export, the booklet and the
  parts list are written to Downloads under the model's name, which a design
  sets, so only the name's last part is used (`Download.give`, `ModelBar`): a
  title with "../" in it wrote outside the folder. `store_probe` names a download
  to climb out and checks it lands inside.

## How to reach it

```sh
godot --path .     # Cmd-S saves, Cmd-O opens, Export writes a .ldr
godot --headless --path . -- --model=models/car.ldr --out=/tmp/car.ldr
```

## How to check it

Static: nothing static reads `.ldr`.

Runtime:

```sh
godot --headless --path . --script src/dev/store_probe.gd    # survives save and reopen
#   also: the build order is written as 0 STEP, and the autosave skips it
godot --headless --path . --script src/dev/keeping_probe.gd  # keeps what it was given
godot --headless --path . --script src/dev/restore_probe.gd  # a failed design changes nothing
godot --headless --path . --script src/dev/moved_probe.gd    # the numbers still mean something
godot --headless --path . --script src/dev/import_probe.gd   # reads the format it writes
tools/check.sh --network   # adds open_probe: opening the way the browser has to
```

And the round trip, which is the one to run after touching the writer:

```sh
godot --headless --path . -- --model=models/car.ldr --out=/tmp/car.ldr
grep -c '^1 ' /tmp/car.ldr
```

Proves it when: it prints `wrote /tmp/car.ldr (61 parts)`, exits 0, and the grep
says `61`. Every one of the nine files in `models/` is a fair target; `car.ldr`
is 61 parts, and the count printed and the count in the file must agree.

## Gotchas

- **The build order is written to the file, but not by the autosave.** Working it
  out compares every brick with every other: measured at 96 ms for 400 bricks,
  552 ms for a thousand and **2.2 s for two thousand**, and the autosave fires a
  second after every change. So `to_text(title, with_steps)` defaults to off, and
  `save_as` and `export_to` pass true. Without the `0 STEP` lines an exported
  model opens in Stud.io or LDCad as one flat pile, and for a mechanism the order
  is not recoverable by eye — a pin has to follow the part it goes into.

- **Sections are flattened on save.** An angled sub-assembly is written as loose
  bricks at their world transforms, not as an LDraw sub-model, so the grouping
  the designer worked in is lost on reopening. The geometry is exact; the
  structure is not. Nothing depends on it yet, and `LdrModel` can already *read*
  sub-models, so writing them is the missing half.

- **`--out` used to be written once, after the design returned.** A ninety-minute
  Voyager run reached 371 bricks, lost its connection twice to a TLS fault, and
  was still retrying when its clock ran out — so no file was written and the whole
  run was wasted. The model stands on the baseplate the entire time, so a driven
  run (`--ask`, `--ask-claude-code`) now exports on every `built` signal:
  `_keep_as_it_builds` in `src/main.gd`. Last write wins, each one the whole model
  as it then stood. Proved by polling the path during a real design — "kept 7
  parts" appeared at 80 s while the run was still going. **`--autobuild` does not
  test this**: it builds procedurally without the assistant, so `built` never
  fires and only the final write happens. That run looked like a pass and was not.

- **The file is written even when a design failed.** `--out` writes the last
  version that held together and signals failure through the exit code, because
  throwing the model away would be the worse answer. Read `$?`, not just the file.
- **`--model` means two different things.** On its own it is the model file to
  open; with `--ask` it is also passed to `Brain.use_model`, which falls back to
  the default when the name is not a model it knows. Do not pass both.
- **Three decimals straightened every angle.** A writer rounding direction cosines
  loses a section's rotation silently. 8 decimals for the nine matrix elements.
- The scenery (baseplate) is excluded from the exported count:
  `_world.brick_count() - _store.scenery.size()`.
