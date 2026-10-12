# Model I/O

Whether what you built is still there tomorrow, and still means the same thing.

<!-- covers: lib:save and reopen, lib:ldr read and write, cli:export a model, ui:seat an old model, ui:picture of the model, ui:parts lists for shops, ui:open a studio model, ui:open an ldd model -->

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
  `tools/web/project_flow.mjs` (types a name, saves, waits until the save and
  the named autosave are in the browser's storage, reloads, reads the tab,
  presses New). On the web the engine titles the page itself as it starts, after
  the restored model was named, so `_tell_page` puts the title back when it has
  drifted. New work begins a new model (`ModelStore.begin`) named for itself:
  the example car taken off for a design (named for its brief, then its own
  title) or a brickified model (its file's name), a design or Brickify on a
  bare Untitled baseplate, and `clear_model` from a session (Untitled). A name
  a saved model has gets a number ("Tower 2"), so new work never saves over it.
  The example kept its name through all of these, and Save saved a tower as the
  example. Clear keeps a person's own name, but not an example's
  (`ModelStore.example`, set by opening one from `res://models/`). New goes
  through `begin` too. `example_name_probe` takes the car off every way there is
  and checks the bar, the store, the window title and the file Save writes.
  A save on the web is in IndexedDB only once the engine's sync has run: 25 to
  52 s at a load of thirty to eighty drawing in software. So the page
  watches for it: the store reports each write (`_tell_page_wrote`), the shell
  polls IndexedDB until that path holds that many bytes written since
  (`brickworksWrote`, `brickworksStored`, `brickworksUnstored`), the bar says
  "saving … in this browser" until then and "saved" after, and closing the tab
  with a write on its way asks first (`beforeunload`). The flow checks the page
  sees the save land and that closing mid-save asks.
- `made parts in the file`: a model that uses a part made in the element
  maker carries it as an LDraw `0 FILE bw-….dat` section, and opening one
  builds the part first — see [elements](elements.md). `element_probe` saves
  three, reopens them into a fresh library, and has the Python reader check
  the file.
- `one way to open a model`: the first visit's sample, `--model`, a restore,
  the Open menu and an imported file all open through `ModelStore.open_text`.
  A model below the ground comes up by `lift_for`, worked out before anything
  is placed from the catalogue's bounds of every part, so it is the same lift
  whatever geometry has arrived; parts not yet fetched wait in `store.awaited`
  and are put down as they arrive (`place_awaited`, from `Main._on_part_fetched`),
  never into a world cleared since. There were two ways: the app's own opened
  the sample without lifting it, so on the web a first visit saved the car
  buried to its axles, a reload lifted it a brick, and New said it had changed;
  the store's lifted it and dropped parts still arriving. `project_probe` opens
  every shipped model as a first visit does and checks its lowest occupied cell
  is on the ground; `open_probe` (network) opens them all over the wire.
- `export a model`: `--model=<in> --out=<out>` opens, re-exports and quits, which
  is also the shortest round-trip proof there is. Export, the booklet and the
  parts list are written to Downloads under the model's name, which a design
  sets, so only the name's last part is used (`Download.give`, `ModelBar`): a
  title with "../" in it wrote outside the folder. `store_probe` names a download
  to climb out and checks it lands inside.

- `seat an old model` (`src/ui/seat_offer.gd`, `src/assembly/seating.gd`): a
  model saved before 2026-10-10 can carry parts drawn inside their footprint a
  tenth of a stud off their studs. Opening one (or the one restored at start)
  says how many, over the top of the model, with one choice: *Seat them on
  their studs*, which moves each as one undoable step, or *Leave them*. A part
  is moved only where undoing exactly the old corner's error puts its studs on
  stud middles. `src/dev/reseat.gd` does the same to files, by the same rule.
- `open a studio model` (`src/parts/studio_io.gd`, `src/ui/model_file_picker.gd`):
  File, Import (or Open → From a file) reads LDraw or BrickLink Studio's `.io` — a zip with
  Studio's published password around `model2.ldr` (or `model.ldr`), opened by
  hand (PKWARE decryption, then the raw deflate wrapped as gzip, which Godot
  inflates). The file is read as bytes, in a browser too.
  `tests/fixtures/studio_bay.io` was made by the system's `zip -P`, not by
  this app.
- `open an ldd model` (`src/parts/ldd_lxf.gd`, `src/ui/model_file_picker.gd`):
  File, Import → LEGO Digital Designer model, or Open → From a file, reads
  LDD's `.lxf` (a zip around LXFML; the zip is read by `StudioIo`'s reader) or
  a bare `.lxfml`, on the desktop and in a browser. Each part's design number,
  material and bone are turned into an LDraw line by `assets/ldraw/ldd.json`,
  which `tools/ldd_map.py` derives from the community's `ldraw.xml`
  (`tools/fetch_data.sh` fetches it; docs/ATTRIBUTION.md): M = R r⁻¹, LDraw's
  matrix A M A and position 25 A (T − M t), A = diag(1, −1, −1) — the sum
  lxf2ldr and LeoCAD do. A part the table cannot place is left out, named in
  a comment in the LDraw text and in what the status bar says ("2 LDD parts
  with no LDraw match left out (999999 ×2)"); a colour it has no match for
  is light bluish grey, and said. `src/dev/lxf_probe.gd` opens
  `src/dev/fixtures/49311_test.lxf`, saved by LDD 4.3 (sttng/LDD, MIT), and
  checks every part where LDD put it — plate on the ground, courses a brick
  apart, every brick on the plate's studs, four positions worked by hand —
  then writes the house and the castle as LDD would and reads them back to
  the same placements, all 2,438 of the castle's that LDD has numbers for.
- `picture of the model` (`src/ui/picture.gd`, File, Export → Picture): the model
  alone — no baseplate, ghost or outline — from the view's direction, framed to
  fill a 2400 x 1600 PNG on a clear background, drawn by a SubViewport looking at
  the same world with a copy of the scene's environment that clears instead of
  drawing the sky. Downloaded in a browser, written to Downloads on the desktop.
- `parts lists for shops` (`src/assembly/shop_lists.gd`, File, Export → BrickLink
  wanted list / Rebrickable parts list): BrickLink's wanted-list XML (item, its
  colour number, quantity) and Rebrickable's `Part,Color,Quantity` CSV. The
  BrickLink colour numbers are colors.json's `bricklink`, 197 colours from
  `tools/bricklink_colours.py` (see [parts](parts.md)); a lot in any other
  colour, or a made part, is left off and the status bar says how many and names
  the colours ("BrickLink has no number for Pearl Red"). Parts go out under each
  shop's own number where LDraw's `!KEYWORDS` record one
  (`PartLibrary.shop_part`, `Inventory.Lot.bricklink_id` / `rebrickable_id`:
  3069b is BrickLink's 3069, 3711 Rebrickable's 3711a), else LDraw's, less a
  formed shape's `-f1`.
- `flexible parts counted as sold` (`Inventory.of`): a sub-model whose bricks
  are all one swept kind's segments (`Flex.items_in` — as the flex tool lays
  one and as Studio and LDCad write one) is one lot of the kind's straight part
  nearest its length (`Flex.real_part`): a 9L ribbed hose of 29 pieces is one
  71917 (BrickLink and Rebrickable 78c09), a 9L pneumatic tube one 21826-f1
  (BrickLink 21826, Rebrickable 5102c09.375), the flexible axle one 72892
  (BrickLink x334c01), the 41L string one 71149 (x127c40pb01, 14226c41). A
  chain or a tread stays its links. A segment loose in the model is itself.
  The counts line (`Inventory.pieces_in`, `Main._on_rebuilt`, counted once a
  change: 15 ms over Orthanc's 9,429 parts, and the build animation redraws
  every frame), the booklet's
  piece count and its parts boxes (`Inventory.key_of`: the item's first piece
  stands for it) and the shared link's count (`api/share.js`, `FLEX_PIECES`)
  say the same number. `inventory_probe` ("flexible parts, counted as they are
  sold") lays each kind and a chain, checks the list, both shop lists, a file
  round trip, and runs the server's own `checkModel` on the written file.

## How to reach it

```sh
godot --path .     # Cmd-S saves, Cmd-Shift-S saves as, Cmd-O opens, File, Open recent,
                   # File, Export writes a .ldr
godot --headless --path . -- --model=models/car.ldr --out=/tmp/car.ldr
```

## How to check it

Static: nothing static reads `.ldr`.

Runtime:

```sh
# opening an old model offers to seat its parts; one click does, one undo
# takes it back (the "seating an old model" section)
godot --path . --resolution 1400x900 --script src/dev/handbuild_probe.gd
godot --headless --path . --script src/dev/store_probe.gd    # survives save and reopen
#   also: the build order is written as 0 STEP, and the autosave skips it
godot --headless --path . --script src/dev/keeping_probe.gd  # keeps what it was given
godot --headless --path . --script src/dev/example_name_probe.gd  # new work, its own name
godot --headless --path . --script src/dev/restore_probe.gd  # a failed design changes nothing
godot --headless --path . --script src/dev/moved_probe.gd    # the numbers still mean something
godot --headless --path . --script src/dev/import_probe.gd   # reads the format it writes
godot --headless --path . --script src/dev/lxf_probe.gd      # opens LDD's .lxf where LDD put it
python3 tools/ldd_map.py vendor/ldraw.xml   # after a newer ldraw.xml: assets/ldraw/ldd.json again
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

- **A PopupMenu reports a negative id as the item's index.** The Open menu's
  "From a file on this computer…" had id -2, so pressing it said 0 and opened
  the first model listed under it — the first saved one, or the Bench example —
  on the desktop and in a browser alike. Its id is now `1 << 30`;
  `studio_ui_probe` opens its saved model through that line and fails if no file
  dialog comes up.

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
