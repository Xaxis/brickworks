# Elements

Making a part LEGO has not made — a brick, plate, tile, slope, inverted slope
or round part of any size — as a real LDraw part, and building it into the
same geometry, connectors and collision the library's own parts have.

<!-- covers: lib:element maker, lib:build a part in the app, cli:build custom parts -->

## Sub-features

- `element maker` (`ElementMaker`): a family and its dimensions in, an
  LDraw `.dat` out. Brick/plate/tile at any width x length and any height in
  plates; slopes by width, depth, run and height, with LEGO's four named
  angles (33, 45, 65, 75) as presets that set the run and height of 3298,
  3039, 60481 and 4460b; inverted slopes; round bricks, plates and tiles by
  diameter. Every part is drawn the way the library draws the part it
  resembles: `stud.dat` per stud, `stud4.dat` tubes and `stud3.dat` pins,
  `box5.dat` shell and cavity, 4 LDU walls and top. The header is the one
  ldraw.org's header spec asks of an unofficial part (`Unofficial_Part`, CC BY
  4.0, `BFC CERTIFY CCW`, a real `!CATEGORY`) and carries the spec it was made
  from, so a part can be read back and remade. `from_part()` turns a plain
  library part's name ("Brick  2 x  4") into its spec: the resize path.
  Named `bw-<shape>`, never an LDraw `u`/`t` number (those are assigned by
  the Parts Library admin).
- `build a part in the app` (`PartForge`): tools/build_meshes.py's
  conversion, step for step, in GDScript — flatten with BFC, crease-aware
  normals, per-colour surfaces, connectors from primitives, voxelise, remove
  studs, fill cavities, boxes, sockets — ending in the same `.lbm` bytes.
  Needed because neither a desktop export nor a browser has Python.
  Primitives: the nine in `assets/ldraw/` (shipped in every export) and
  `vendor/ldraw` when present.
- `build custom parts` (`tools/build_custom.py`): the Python pipeline for just
  the given parts — `.dat` files, or the parts embedded in an `.mpd` — in
  seconds rather than the full build's ninety minutes. `--out DIR` writes
  meshes and `custom.json` entries; `--into DIR` merges into a catalogue
  (replacing same ids, leaving the rest); `--summary FILE` writes the numbers
  the app's build is held against.

## How to reach it

```sh
godot --headless --path . --script src/dev/element_files_probe.gd            # check
godot --headless --path . --script src/dev/element_files_probe.gd -- --write  # rewrite fixtures
tools/build_custom.py tests/fixtures/elements/*.dat --out /tmp/custom       # needs numpy
tools/build_custom.py model.mpd --into /tmp/copy-of-generated
```

## How to check it

```sh
python3 tools/minitest.py tests/test_elements.py
godot --headless --path . --script src/dev/element_files_probe.gd
```

Proves it when: the tests say `179 passed, 2 skipped` without numpy and
`181 passed` with it (`uv venv` + `uv pip install numpy scipy`; see
pipeline.md), and the probe ends on "the maker makes the measured files, and
the app builds them as the pipeline does" with every line `ok`: each of the
19 fixtures "the same .lbm, byte for byte" built from only the shipped
primitives, and the 16 library parts the same from vendor/ldraw.

What the tests measure, each by stabbing the flattened geometry with a
vertical line the way the voxeliser does: the header lines in order; every
line parsing strictly; every reference resolving; studs on the 20 LDU grid
pointing up and only on a slope's flat rows; tubes on stud-grid corners (pins
mid-row on 1-wide parts) pointing down; walls 4 LDU (a line 3.7 in crosses
only top and bottom, 4.3 in finds the ceiling at 4); a slope's face where it
should be and 4 LDU thick; the top and bottom faces wound outward. The maker's
2 x 4 is 3001 triangle for triangle; its 1 x 1, 1 x 2 plate, 2 x 2 tile, 45 and
33 slopes, inverted 45 and 2 x 2 round have 3005's, 3023b's, 3068b's, 3039's,
3298's, 3660a's and 3941's outside, studs and tubes.

Mutations that each test was seen to catch: a slope face wound inside out
(`faces_out`), a stud 1 LDU off the grid (`studs`), a 3 LDU wall (`walls`), a
tube under a stud (`tubes`).

## Gotchas

- **LDraw parts are not closed solids, and a test that assumes they are
  fails on 3001.** A stud is an open cylinder stood on the top face; a
  brick's cavity ceiling runs straight over its tubes. "A line through it
  comes back out" is false for every brick in the library. The voxeliser's
  rule — inside wherever the signed count of crossings is above zero — is the
  one that holds, and it is blind to a face wound inside out when nothing is
  above it, so winding has its own test (top face faces up, bottom down).
- **Godot's Vector3 is 32-bit.** The forge does all geometry in 64-bit floats
  (PackedFloat64Array, plain floats) or it would not match the pipeline.
  Byte-for-byte also needed: Python's round() (halves to even), `x ** 0.5`
  (pow, not sqrt) for Vec3 lengths, numpy's sqrt where numpy has it, a
  correctly rounded decimal parse (`PartForge._num`), and the same order of
  every sum. A difference of one bit moved a cell on the 45 degree slope,
  whose face runs exactly through cell centres — which is also why that
  slope has 44 boxes and 3039 has 19: the staircase is ragged by rounding in
  both, identically.
- **Not ported:** connectivity's merging of a Technic hole's two faces and
  occupancy's clearing of a hole's bore. Nothing the maker makes has a hole;
  3700 is the library part that shows the difference and is left out of the
  probe's list on purpose.
- **A slope's named angle is a name.** LEGO's "33" is 26.6 degrees in 3298 and
  its "75" is 73.6 in 4460b. The maker titles a slope by the named angle when
  it is within five degrees of one, else by its true angle ("Slope Brick 17
  3 x 3 x 2/3").
- **The maker centres every part.** The library's slopes put their origin on
  the back stud row; the app's stud snapping assumes the footprint's centre.
  Comparisons with real slopes shift by that much.
- `tests/fixtures/elements/pipeline.json` is written by `tools/build_custom.py
  --summary` over the fixtures *and* the 16 library parts; the test that it
  is current needs numpy and skips without.
