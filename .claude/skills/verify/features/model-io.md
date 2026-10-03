# Model I/O

Whether what you built is still there tomorrow, and still means the same thing.

<!-- covers: lib:save and reopen, lib:ldr read and write, cli:export a model -->

## Sub-features

- `save and reopen`: the app writes what is on the baseplate to `user://` and
  restores it on start-up — bricks, colours, orientations, sections and the
  camera. A design that fails must leave the model it was asked to change alone.
- `ldr read and write`: real LDraw `.ldr`. Written files open in other LDraw
  tools, and files from them open here.
- `export a model`: `--model=<in> --out=<out>` opens, re-exports and quits, which
  is also the shortest round-trip proof there is.

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
says `61`. Every one of the eight files in `models/` is a fair target; `car.ldr`
is 61 parts, and the count printed and the count in the file must agree.

## Gotchas

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
