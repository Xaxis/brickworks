# Geometry

Whether a brick here is the size of a brick in your hand, and whether two of them
can occupy the same millimetre.

<!-- covers: lib:occupancy lattice, lib:sideways building, lib:angled sections, lib:stability -->

## Sub-features

- `occupancy lattice`: every part is a set of 2 LDU cells. A stud is 20 LDU
  across (10 cells), a plate 8 LDU tall (4 cells), a brick three plates. A
  placement names its lowest-leftmost-backmost cell.
- `sideways building`: a part can be held by a stud that does not point up —
  `face` (up/down/±x/±z) × `rot` (quarter turns) gives 24 orientations, and the
  occupied cells are recomputed for each.
- `angled sections`: a sub-assembly built square and then carried at an angle.
  `sections: [{name,x,y,z,axis,degrees}]` plus a `section` field on a brick.
  Collision inside a section is checked in the section's own square frame;
  everything else is checked against the turned cells with a 15-axis separating
  axis test.
- `stability`: whether what was built would survive being picked up — what rests
  on what, what is floating, and what is attached by one stud at the end of a
  cantilever.
- `technic joints`: pins, axles and ball joints as real attachments, alongside
  studs. Two pieces: the hole has to be *open* in the occupancy lattice (so a
  pin is not a collision), and the two connectors have to be *matched*
  (`Assistant._connectors_mating`, so the pinned part is not floating).

## How to reach it

GDScript: `src/assembly/lattice.gd` (cells, `cells_for_turned`, `is_square_to_grid`),
`src/assembly/stability.gd`, and `Section` in `src/ai/assistant.gd`.
Python: `tools/ldraw/occupancy.py` (the same lattice, used by the mesh build).

## How to check it

Static: the Python half is pinned by `tests/test_ldraw.py` — stud pitch 8 mm,
brick 9.6 mm, plate a third of a brick, −Y up, and the lattice dividing every LEGO
dimension. **The six tests that voxelise a part need numpy and scipy** and skip
without them, which is 25 of the 67 cases.

Runtime:

```sh
godot --headless --path . --script src/dev/dimensions_probe.gd   # in millimetres
godot --headless --path . --script src/dev/snap_probe.gd         # cells
godot --headless --path . --script src/dev/snot_probe.gd         # held sideways
godot --headless --path . --script src/dev/technic_probe.gd      # pins, axles and open holes
godot --headless --path . --script src/dev/angled_probe.gd       # not square to the grid
godot --headless --path . --script src/dev/section_probe.gd      # built square, carried at an angle
godot --headless --path . --script src/dev/stability_probe.gd    # arrangements with known answers
godot --headless --path . --script src/dev/holds_probe.gd        # and whether the assistant is told
godot --headless --path . --script src/dev/attach_probe.gd       # are the coordinates usable
python3 tools/minitest.py tests/test_ldraw.py                    # or pytest, if installed
```

Proves it when: every probe exits 0 with no `FAIL`, and `dimensions` ends on
"every measured part is the nominal size, exactly" — a 2×4 brick measured at
32.00 × 9.60 × 16.00 mm, three plates to a brick, 8.00 mm stud pitch. It prints
one `--` line on purpose: LDraw draws a 1.6 mm stud where LEGO moulds 1.8 mm.

## Gotchas

- **A vertical hole was being filled solid, which refused most of Technic.**
  `fill_cavities` closes voids layer by horizontal layer, which is right for a
  brick's underside and for an arch. A hole running *horizontally* reaches the
  edge of the part within its own layer and stays open; one running *vertically*
  is a closed circle in every layer it crosses, so it filled. Technic beam holes
  run vertically, so every liftarm in the library was solid and a pin pushed into
  one read as a collision — measured: beam 2 went from 752 voxelised cells to
  1368 filled, with both holes sealed. `fill_cavities` now takes the connector
  list and puts back its own additions inside each hole's bore, and only its own
  additions, so a wrong connector can leave a cavity open but can never remove
  plastic. Plain bricks are untouched: a 2x4 is still 9,600 cells and one box.
  The cost is box count on Technic parts only — beam 3 went 25 to 36, beam 5
  37 to 54.

- **A pin cannot be found the way a stud is found.** `_studs_reaching_in` samples
  just past a stud's tip and asks who owns that lattice cell, which works because
  a stud ends up inside the part above it. A pin ends up in a hole, which is
  deliberately *empty*, so the sample finds nothing. Pins, axles and balls are
  matched connector-to-connector instead: collinear within 0.95 of a dot product,
  within `OFF_AXIS` 4 LDU of the mate's axis line and `ALONG_AXIS` 20 LDU along
  it. Do not "simplify" one into the other.

- **A section is checked against itself in its own frame.** Checked against the
  world, a tipped section collides with itself at every angle — three overlaps,
  every time, for a model that is perfectly fine.
- **An angle has to survive a save.** Direction cosines were being trimmed to
  three decimals, which quietly straightened every section. `.ldr` now carries 8
  decimals for the nine matrix elements and 4 for the position.
- **One fault must not read as three.** An overlap also makes things float and
  come adrift; `crowded` suppresses the consequences so the report names the cause.
- **The hint that says where a section would fit was what stopped a design run.**
  Thirty-two trial placements per failing section, each voxelising the section
  against the lattice: measured at 46 s for one failing section, 82 for two and
  **182 for four** — and the relay a session talks through gives up at 180. A
  starship has four candidates, two pylons and two nacelles, so a design fighting
  its pylons made a `check_design` that never came back, and a real Voyager run
  reported "the brickworks server has stopped responding" on every call after one
  edit while the app was alive and finishing normally. Two bounds now: `HINTS_WITHIN`
  caps what one check spends on hints at four seconds and says which it was when it
  runs out (silence there reads as "there is nowhere", the answer that ends runs),
  and `_section_sits` skips the twenty-six-neighbour scan for cells strictly inside
  a brick's own extent, which cannot touch anything outside it. `_anything_in_reach`
  then asks once, before sweeping at all, whether anything of anyone else's is
  inside the box the sweep could reach — grown two plates each way and one cell for
  adjacency — because a section parked in mid-air fails all thirty-two trials the
  expensive way. Four failing sections now cost **5.9 s**, and `section_probe` fails
  if a check of them takes 30.
- **The budget has to be big enough for the case it exists for.** At four seconds
  an eight-brick model with one tipped pylon was told the time had run out when the
  answer was two trials away: a rotated part is voxelised the slow way, so one
  section's sweep is about five and a half seconds of real work. Eight seconds,
  shared across sections, and the later ones get the honest "ran out of time".
- **The sweep steps in eighths of a plate, which is half a lattice cell.** A plate
  is 8 LDU and a cell is 2, so an eighth-plate step is 1 LDU and whether it changes
  any occupied cell depends on rounding inside `_cells_for`. Worth knowing before
  making the sweep cheaper by translating cached cells rather than re-voxelising —
  the obvious optimisation, and exact only on whole cells.
- **The fit window can be a quarter of a plate wide.** `_where_it_would_meet`
  sweeps ±2 plates in eighths and says "At y=3.25 it would rest against the model
  instead of running into it", because nothing else makes it findable.
- Changing the cell size changes the Python lattice *and* the GDScript one. They
  are separate implementations of the same number; `occ.CELL` and `Lattice.CELL`
  both have to move, and `tests/test_ldraw.py` is what notices.
