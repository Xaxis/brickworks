# Pipeline

The Python side: LDraw in, mesh cache and catalogue out.

<!-- covers: cli:build the meshes, cli:refresh the catalogue, cli:pack the web parts, cli:upload parts to storage, cli:export for linux, cli:export for windows, cli:export for macos -->

## Sub-features

- `build the meshes`: every LDraw part flattened, wound consistently, split into one
  surface per colour role, voxelised onto the 2 LDU lattice, and written as `.lbm`
  with its connectors, boxes and sockets. ~27,000 files, ~45 minutes, 1.1 GB.
- `refresh the catalogue`: `assets/generated/catalogue.json` (14 MB) — the index the
  app searches, with each part's title, category and size — and `colors.json`
  (86 KB), through `write_colors`, the one writer of it: `build_meshes.py` calls
  the same function, and the two copies there were before had drifted to the
  point where neither filled the cross-references. It prints a `colour join:`
  line (210 LDraw colours with a Rebrickable colour, 77 current, 185 with a LEGO
  number). See [parts](parts.md) for what each colour carries.
- `pack the web parts`: chooses which parts the WebAssembly build carries, smallest
  mesh first, with per-family caps so no family is absent entirely. Everything else
  is a fetch away at run time.
- `upload parts to storage`: puts the rest in the Supabase bucket under
  content-hash names, cached for a year, so a name's bytes can never change.

- `export for linux` / `windows` / `macos`: the raw exports.
  `tools/export.sh desktop` makes all three. Each carries the whole part
  library — a 70-104 MB binary beside a 995 MB `.pck` — so the app works with
  no network at all, which the web build cannot. What people download is made
  by `tools/release.py build` instead ([release](release.md)): from the
  commit, with only the meshes the catalogue names, packaged and read back.
  The macOS app from `tools/export.sh mac` carries Godot's own signature,
  which is malformed (release.md, Gotchas); give a Mac the release build.

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
  -m pytest -q` reports "45 passed, 25 skipped" on a bare interpreter, and the
  skipped ones are `test_collision_is_exact_on_the_lattice`,
  `test_lattice_divides_every_lego_dimension` and the rest of the occupancy
  cover — exactly what a change to `tools/ldraw/occupancy.py` needs. There is no
  `pip` or `ensurepip` here, so use `uv venv` and run pytest from it: all 70
  pass. A green suite with 25 skips is not a green suite.

- **A full mesh build is ~90 minutes and writes nothing until the end.** An
  interrupted run therefore costs the whole thing, but leaves the old catalogue
  consistent. `tools/merge_subbuild.py` exists for that: build the affected
  parts with `--only`, include a few hundred parts that did *not* change, and it
  refuses to merge unless every one of those comes out identical.

- **`build_meshes.py` rewrites `catalogue.json` from scratch**, which drops the
  colour availability and element fields. Always follow it with
  `tools/refresh_catalogue.py`.

- **The shipped catalogue predates shafts and bores (2026-10-10).** The round
  joints the checker forgives (`geometry.md`, `round joints`) are records in
  each part's `.lbm`, kinds `shaft` and `bore`, whose gender byte is a radius in
  quarter LDU and whose axis runs the round's length (`meshfile.py`). 17,539 of
  29,591 parts gain at least one, so until the meshes are rebuilt the checker
  forgives none of them and `joints_probe` fails its first five lines. The way
  in that was measured: the 2,379 of them the harvest, the shipped models and the
  techniques use, plus every bar, clip, hinge, turntable, antenna, flag,
  handle and holder by name, with 261 unchanged controls, built with `--only`
  in **343 s on 8 jobs**, then `merge_subbuild.py`: all 261 controls agreed.
  That leaves 15,160 parts without their rounds, so a full build is still owed
  (then `refresh_catalogue.py`, then `storage_parts.py` for the web, which has
  every changed mesh under a new name to upload).

- **A change to which holes a cover opens moves only parts with holes.**
  The covers fixed on 2026-10-11 (`geometry.md`: holes past the box limit,
  holes drawn without a peghole) were rebuilt without a full build. The
  candidates were read off the built `.lbm` files: every part whose cover
  was one box and has a `pin_hole`, `axle_hole` or a sideways bore of radius
  6, and every part with such a bore — 3,619 — plus 300 random controls.
  Built with `--only` in 396 s on 8 jobs, 2,571 changed (only `mesh` and
  `box_count`), and the other 1,348 came out identical before
  `merge_subbuild.py` took them. 2,376 new meshes, 196 MB, are for
  `storage_parts.py` to upload; `refresh_catalogue.py` afterwards changed no
  part.

- **A pale face on a black right-hand wedge is the sun, not the mirror.** A
  design stopped using 41769a (Wing 2 x 4 Right) for a "near-white cut face".
  Its body is 41770a's subpart under `-1 0 0 / 0 1 0 / 0 0 1`, so the
  reflection was suspected, and measured (2026-10-12): every one of its 521
  triangles has a twin in 41770a's mesh mirrored, facing the mirrored way,
  normals within 3°; the same for 41769b, 43722a and 3935. Across the
  catalogue, the 10,375 parts that reach a part or subpart through a mirror
  have normals against their winding no more often than the 18,051 that do
  not (8.9% of parts and 0.018% of triangles against 8.3% and 0.037%; those
  are slivers, not mirrors), and none is inside out: the 58 with a negative
  signed volume are formed stickers and open panels, whose volume means
  nothing, as are the plain 57. In black, turned all four ways, the two hands
  are drawn within 0.006 L of each other in all seven of the assistant's
  views on both renderers, with no pixel past L 0.80. What does go pale is a
  flat black top at the mirror angle to the main view's sun: 30% of a part
  past L 0.6 (to 0.81) from yaw 245, 35 up. Swapping the two rows of parts
  moved that 30% from the right hand to the left: it follows where a part
  stands, and a symmetric model stands its wings on opposite sides. Nothing
  was rebuilt. `test_a_mirrored_twin_is_drawn_as_its_twins_reflection` is
  the only test that fails if `geometry.flatten` stops counting a mirror.

- **`merge_subbuild.py` dropped a field it did not know refresh added.** It
  carries over a fixed list of refresh-only fields, and `in_sets` was missing,
  so the merge above first took it off 1,239 parts, which search and the bin
  rank by. It is in the list now; check a merge with a diff of the field names.

## How to check it

Static:

```sh
pyright                                            # 0 errors, 3 warnings (numpy/scipy absent)
python3 -m pytest tests/ -q                        # or:
python3 tools/minitest.py tests/test_ldraw.py      # 65 passed, 38 skipped (103 passed with numpy)
```

`tests/test_ldraw.py` is the real check on this area: it measures the shipped
geometry rather than quoting a wiki. Stud pitch 8 mm, brick 9.6 mm, plate a third
of a brick, −Y up, studs pointing up, tubes pointing down and sitting between
studs, no degenerate triangles, the official colours, a redirect still rendering
its target, and a right-hand wing built from its left twin's body reflected
(41769a, 41769b, 43722a, 3935) coming out of `meshfile` as that twin's exact
reflection: the same signed volume, its x moment negated, every normal on the
side its triangle faces.

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
  and 25 of the 70 pipeline test cases skip. `apt install python3-numpy
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
