# Pipeline

The Python side: LDraw in, mesh cache and catalogue out.

<!-- covers: cli:build the meshes, cli:refresh the catalogue, cli:pack the web parts, cli:upload parts to storage, cli:export for linux, cli:export for windows, cli:export for macos -->

## Sub-features

- `build the meshes`: every LDraw part flattened, wound consistently, split into one
  surface per colour role, voxelised onto the 2 LDU lattice, and written as `.lbm`
  with its connectors, boxes and sockets. ~27,000 files, ~45 minutes, 1.1 GB.
- `refresh the catalogue`: `assets/generated/catalogue.json` (14 MB) — the index the
  app searches, with each part's title, category and size.
- `pack the web parts`: chooses which parts the WebAssembly build carries, smallest
  mesh first, with per-family caps so no family is absent entirely. Everything else
  is a fetch away at run time.
- `upload parts to storage`: puts the rest in the Supabase bucket under
  content-hash names, cached for a year, so a name's bytes can never change.

- `export for linux` / `windows` / `macos`: the downloadable builds.
  `tools/export.sh desktop` makes all three. Each carries the whole part
  library — a 70-104 MB binary beside a 995 MB `.pck` — so the app works with
  no network at all, which the web build cannot.

## How to reach it

```sh
tools/fetch_data.sh                   # vendor/ldraw and vendor/rebrickable, first of all
tools/build_meshes.py                 # ~90 min on 20 cores; needs numpy and scipy
tools/build_meshes.py --only 3001 ... --out DIR   # just those parts
tools/merge_subbuild.py DIR ids.txt   # merge such a build back, with a safety check
tools/refresh_catalogue.py            # also joins colour availability, ~10s of it
tools/web_pack.py --list              # say what would be included, write nothing
tools/web_pack.py --budget 40         # stop at 40 MB
tools/storage_parts.py --check        # say what would be uploaded
tools/storage_parts.py --all          # re-upload everything
tools/export.sh desktop               # mac, linux and windows, ~10 min
tools/export.sh linux                 # one of them
```

## Gotchas

- **The Python tests silently skip the half that matters without numpy.** `python
  -m pytest -q` reports "42 passed, 25 skipped" on a bare interpreter, and the
  skipped ones are `test_collision_is_exact_on_the_lattice`,
  `test_lattice_divides_every_lego_dimension` and the rest of the occupancy
  cover — exactly what a change to `tools/ldraw/occupancy.py` needs. There is no
  `pip` or `ensurepip` here, so use `uv venv` and run pytest from it: all 67
  pass. A green suite with 25 skips is not a green suite.

- **A full mesh build is ~90 minutes and writes nothing until the end.** An
  interrupted run therefore costs the whole thing, but leaves the old catalogue
  consistent. `tools/merge_subbuild.py` exists for that: build the affected
  parts with `--only`, include a few hundred parts that did *not* change, and it
  refuses to merge unless every one of those comes out identical.

- **`build_meshes.py` rewrites `catalogue.json` from scratch**, which drops the
  colour availability and element fields. Always follow it with
  `tools/refresh_catalogue.py`.

## How to check it

Static:

```sh
pyright                                            # 0 errors, 3 warnings (numpy/scipy absent)
python3 -m pytest tests/ -q                        # or:
python3 tools/minitest.py tests/test_ldraw.py      # 42 passed, 25 skipped
```

`tests/test_ldraw.py` is the real check on this area: it measures the shipped
geometry rather than quoting a wiki. Stud pitch 8 mm, brick 9.6 mm, plate a third
of a brick, −Y up, studs pointing up, tubes pointing down and sitting between
studs, no degenerate triangles, the official colours, a redirect still rendering
its target.

Runtime, without spending 45 minutes:

```sh
tools/web_pack.py --list | tail -5        # what the web build would carry
tools/storage_parts.py --check | tail -5  # what is missing from the bucket
godot --headless --path . --script src/dev/dimensions_probe.gd   # what the app sees
```

For a desktop build, run the thing you just made:

```sh
build/linux/brickworks.x86_64 --headless -- --model=models/car.ldr --out=/tmp/x.ldr
file build/windows/Brickworks.exe     # PE32+ executable (GUI) x86-64
```

Proves those when: the Linux binary prints "wrote /tmp/x.ldr (61 parts)", and
the Windows one is a PE32+ x86-64 executable. A Windows build cannot be run from
here; that it links and carries its pck is what can be checked.

Proves it when: `--list` ends with a part number and a count of what follows;
`--check` prints `storage: 27,364 meshes`, `already up:` and `to upload : 0`, and
names the largest of anything missing; `dimensions` ends on "every measured part is
the nominal size, exactly". After a real
`tools/build_meshes.py`, that probe plus the pytest suite is the proof — the
numbers it prints come from the files that were just written.

## Gotchas

- **numpy and scipy are not installed here.** `tools/build_meshes.py` cannot run,
  and 25 of the 67 pipeline test cases skip. `apt install python3-numpy
  python3-scipy`.
- **There is no pip and no ensurepip either**, so `tools/check.sh` falls back to
  `tools/minitest.py` for the test file. It implements `approx`, `fixture`,
  `mark.parametrize` and `mark.skipif` and raises by name on anything else — add
  to it rather than working around it.
- **−Y is up in LDraw.** Every axis conversion is `(x, -y, -z)`, and a mesh and its
  connectors have to get the same treatment or the studs end up on the bottom.
- **A box is six numbers.** `build_meshes.py` unpacks them explicitly so a box that
  is not six fails there instead of being written out short.
- `assets/generated/` and `vendor/` are gitignored and reproducible. Nothing here
  belongs in a commit.
