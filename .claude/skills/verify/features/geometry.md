# Geometry

Whether a brick here is the size of a brick in your hand, and whether two of them
can occupy the same millimetre.

<!-- covers: lib:occupancy lattice, lib:sideways building, lib:angled sections, lib:stability, lib:round joints -->

## Sub-features

- `occupancy lattice`: every part is a set of 2 LDU cells, **stored as the boxes
  those cells came from**. `BrickLattice` keeps six ints per box, a coarse
  two-stud bucket index, and an exact box-overlap test. An ordinary brick is one
  box; a Technic beam is 36. A stud is 20 LDU
  across (10 cells), a plate 8 LDU tall (4 cells), a brick three plates. A
  placement names its lowest-leftmost-backmost cell, across and deep of the
  whole studs it stands on. A part's boxes are counted from its origin's cell;
  for a square part placed off the lattice (a minifigure's) that sits up to a
  cell below the part, so `Builder.boxes_for` and `Stability` keep such a cover
  inside the part's own box, rounded out (`BrickLattice.within`) — it only
  ever drops cells the part is not in (a flipper on a plate read as in it).
  Turned covers stay rounded out all round: tipped sections find what they
  lean on by them (`section_probe` fails if they are cut back too).
- `sideways building`: a part can be held by a stud that does not point up —
  `face` (up/down/±x/±z) × `rot` (quarter turns) gives 24 orientations, and the
  occupied cells are recomputed for each.
- `angled sections`: a sub-assembly built square and then carried at an angle.
  `sections: [{name,x,y,z,axis,degrees}]` plus a `section` field on a brick.
  Collision inside a section is checked in the section's own square frame;
  everything else is checked against the turned cells with a 15-axis separating
  axis test. `cells_for_turned` works out the axes once per box and, since the
  touching cells along any line are one run, finds each row's ends from the
  slabs and settles them with the exact test — every cell of the bounding box
  used to be tested, with the axes rebuilt each time, and an Orthanc of a
  thousand angled bricks took 185 s to place on the app's only thread (its
  looks timed out); 9.5 s now. `turned_probe` checks the cells are identical to
  the old way's over 300 random turned boxes, and quicker (14.3 s to 0.84 s).
- `stability`: whether what was built would survive being picked up — what rests
  on what, what is floating, and what is attached by one stud at the end of a
  cantilever.
- `clutch`: whether two parts that touch could really hold each other. The
  lattice is 2 LDU and the connection system is 20, so a position can be legal
  on the grid and impossible in plastic — a brick three tenths of a stud across
  from the one below, a plate half a stud along a plain plate, or standing on a
  tile (`Assistant._note_loose`). Standing on a tile is advice. A fraction of a
  stud off is a fault ("off its studs") between two parts that each have a stud
  or tube facing up or down (`_has_a_grid`); a horn or a pane has no grid to be
  off. **Half a stud off is judged by the studs, not the grid**
  (`_underside`, `_none_off`): every stud reaching up into the part
  (`_studs_reaching_in` gives each one's place and way) has to be somewhere
  the part takes a stud (`_underside_of`) — a socket, a top stud's place, a
  tube, a vertical pin hole or bore, or the point between two sockets of a
  part one stud wide (a 1 x N's post fits a hollow stud, and a jumper's is
  hollow; 15573 has no post). A stud half a stud from all of those stands
  against a wall or a tube: "half a stud off", naming a jumper and the whole
  stud that grips. A jumper's one stud (3794a/b, 15573; 87580 for a 2 x 2)
  stands on the half, so a part on one passes, and so does a part on the studs
  of a part a jumper carries. A stud 0.8 of a stud or more from everywhere the
  part takes one is not judged (the catalogue does not describe that stretch).
  The x and z offered for either fault are the least move that puts a stud
  reaching into it in one of its sockets (`_nearest_move`), not the half-stud
  grid: that offered x=0.5 for a part 0.3 off a plain plate.
- `technic joints`: pins, axles and ball joints as real attachments, alongside
  studs. Two pieces: the hole has to be *open* in the occupancy lattice (so a
  pin is not a collision), and the two connectors have to be *matched*
  (`Joints.both_ways` over `Assistant._mating_entries`, so the pinned part is
  not floating).
- `round joints`: something round turning in something round that fits it —
  a clip on a bar, a bar in a hollow stud, a hinge's pin in its eye, a 2x2
  turntable's top on its base, at any angle about their shared axis. The
  pipeline records each part's **shafts** (cylinders facing out) and **bores**
  (facing in, after `BFC INVERTNEXT`) with radius and length
  (`connectivity.rounds`); `Joints.rounds` pairs a shaft with a coaxial bore of
  the same size (within `ROUND_FIT` 1 LDU across and `ROUND_OFF_AXIS` 1 LDU off
  the axis) that it reaches into, and the checker forgives an overlap between
  the two only where every shared cell lies inside a bore on that axis that the
  other part reaches into, and not in plastic standing inside that bore
  (`Joints.overlap_within`, `Assistant._joints_out`) — so the same two parts
  meeting anywhere else still collide. A round joint holds both ways for
  support and pieces, as a pin does. Pins, panes and rounds are forgiven inside
  a section too, which nothing was before. Needs a catalogue built with the
  rounds; see `pipeline.md`.
- `leaning on a joint`: a section turned about x or z must turn on a joint whose
  pin lies along its axis — a hinge brick, finger hinge plates, a clip on a bar,
  a ball — with one half outside the section and the other in it, or it is
  refused as "leaning on nothing" (`Assistant._check_sections_attached`,
  `_turns_on_a_joint`). Touching was enough before, and a horn tip tipped out on
  the studs below gripped none of them. Turning about y and quarter turns are
  exempt. Two halves of a joint turned against each other, and the rest of a
  section turning on a joint against that joint's other half, are forgiven a
  shared cell at either part's surface (`Joints.overlap_within` with `own`,
  `Assistant._turns_against`): 3938 tipped ten degrees shared 99 cells with
  3937 outside the pin, all grazing. Deeper is still a collision — the top
  swung on round into its own base is refused. `hinge: true` on a section
  is the one-line way (`Section.hinge`, `Assistant._fit_hinge`): the app puts a
  3937 where the section's x, y, z say and a 3938 in it, the section's own
  0,0,0 is the top's studs, and it turns about the pin read off 3937's flat
  bore — 1.75 plates up and half a stud in, the studs 1.25 above it. A repeat
  gives each copy its own base; an edit moving the section moves its base
  (`_rehinge`). `section_probe` ("a section on a hinge"): leans of -20 to 25
  degrees about x and z hold, closed it stacks exactly where a brick would.

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
godot --headless --path . --script src/dev/joints_probe.gd       # clips, bars, hinges, turntables, panes
godot --headless --path . --script src/dev/clutch_probe.gd       # positions that cannot be built
godot --headless --path . --script src/dev/angled_probe.gd       # not square to the grid
godot --headless --path . --script src/dev/section_probe.gd      # built square, carried at an angle
godot --headless --path . --script src/dev/world_view_probe.gd   # parts drawn inside their footprint sit on studs
godot --headless --path . --script src/dev/stability_probe.gd    # arrangements with known answers
godot --headless --path . --script src/dev/holds_probe.gd        # and whether the assistant is told
godot --headless --path . --script src/dev/attach_probe.gd       # are the coordinates usable
python3 tools/minitest.py tests/test_ldraw.py                    # or pytest, if installed
```

`joints_probe` ends on "the joints real sets use pass, and the same parts apart
do not": each family where real sets put it, and wrong — a bar through a brick
with no hole, a Technic axle in a clip, a hinge's top half a stud into its base
or 2 LDU off its pivot or swung into its base, a turntable's top 2 LDU or a stud
off its base, or turned 45 degrees about the wrong point. On a catalogue built
before the rounds its first five lines fail, and every case that should pass
fails with them.

`clutch_probe`'s "half a stud off" block holds the half-stud rule both ways: a
2x2 plate half along a 2x4 plate, a 2x4 brick half along a 2x4 brick, a 2x2
half both ways (one stud in its tube) and a 1x2 back on the base grid on a
jumper-offset 2x2 are refused; a 2x2 by its tube on a 3794b, a 1x2 half both
ways on an 87580 and a 1x2 on the studs of that offset 2x2 build. Against the
rule before it, six of its lines fail. Real sets, when the rule changes
(needs `tools/omr.py fetch`; about ten minutes, not in the suite):

```sh
godot --headless --path . --script src/dev/half_studs_in_sets.gd -- vendor/omr/files
```

Proves it when: every probe exits 0 with no `FAIL`, and `dimensions` ends on
"every measured part is the nominal size, exactly" — a 2×4 brick measured at
32.00 × 9.60 × 16.00 mm, three plates to a brick, 8.00 mm stud pitch. It prints
one `--` line on purpose: LDraw draws a 1.6 mm stud where LEGO moulds 1.8 mm.

## Gotchas

- **Checking whether a model stands up cost 37 ms a brick.** `Stability.check`
  asked the lattice what was in the cell above every cell of every brick — 9,600
  a brick, ten million lookups for a thousand-brick model. **41s for a
  1,106-brick castle, 30s for the shipped fire station, six minutes for the ten
  thousand the lattice holds** — and the app runs it on every change. A brick's
  boxes lifted one cell is the space whatever rests on it occupies, so one bucket
  query plus `BrickLattice.shared_cells`, three subtractions and a product:
  **87ms and 58ms**, 730x and 520x. Checked against the cell-by-cell count on
  seven real pairs of parts first: identical.

  **Two answers changed and the old ones were wrong.** The graph took the box
  *span* of a turned part for the lower brick and the lattice's exact cells for
  the upper, so it disagreed with itself — the kart reported 41 joints where a
  cell-by-cell walk of the lattice finds 42. Both sides read `lattice.boxes_of`
  now. On the lighthouse the boxes find 58 where the walk finds 56, and that is
  the index, not the model: `brick_at` names one owner per cell, so where a tyre
  is registered around a hub the walk sees one relationship and the boxes see
  both. No risk appeared or disappeared on any of eleven models. (The
  lighthouse's two were slopes half a stud off the bricks below, reaching into
  the brick beside; seated on their studs on 2026-10-11, both counts are 53.)

  Rejected by measurement: skipping pairs whose boxes overlap, on the theory that
  a part inside another is not resting on it. A stud belongs to the brick below
  and reaches into the one above, so nearly every real joint overlaps — the kart
  went 42 joints to 14, the car 53 to 44.

  **The cost guard is not a clock and not a ratio of sizes.** The old version was
  linear in bricks too, with a constant 400x larger (100 bricks 3.7s, 800 bricks
  29.5s — the same curve). What measures a constant without a clock is something
  else on the same machine: the old check cost **84x** what building the model
  cost, the new one a tenth. `stability_probe` asserts under 3x, and the old code
  fails it.
- **A tall model made the check slow where a wide one never did.** Whether it
  leans or is top-heavy is asked at every course, of everything above and below
  it, and `_check_levels` summed every brick at every cut: on the owner's Falcon
  Heavy (4,242 parts, 332 plates, about seven hundred cuts) that was 3.3 s of a
  3.5 s check, and the app ran it after every change and, while the build
  animation played, about once a frame. The 800-brick wall above is forty
  courses and never showed it. Now the load above each cut is summed once from
  the top and the footprint below grown once from the bottom: 0.25 s, the same
  risks to four decimals on all eleven shipped models, the square Orthanc, run
  18's 8,506-part tower and run 1's Falcon. `stability_probe` holds the Falcon
  under three times the cost of building it; the old code was twelve times.
  Still slow: on run 18's Orthanc the contact graph itself is 10 s, all of it
  `BrickLattice.shared_cells` between turned parts, whose covers are many small
  boxes.
- **The lattice stores boxes, and anything that asks it per *cell* is a bug.**
  It used to be a Dictionary with one entry per 2 LDU cell — 9,600 for a single
  2x4 brick — plus `_columns` holding the same volume again. Eight thousand
  bricks took **9.24 GB**, which is more than a browser gives the whole app, so
  the size of a model was capped by how collision was stored rather than by
  anything about LEGO. Fifty thousand bricks now cost **180 MB** and 938 ms.

  The migration's whole difficulty is that `brick_at` was a dictionary lookup
  and is now a search of the boxes near a cell. Four places asked it per cell
  and each had to become one box query — `_check_support` (the whole underside,
  800 questions for a 2x4), `_section_sits` (every cell, then all 26 neighbours
  of each), `_anything_in_reach` (a whole grown bounding volume), and
  `_count_pieces` (every cell, to find what sits on top). If you add a fifth,
  it will not look slow in review; it will quietly take the checker from three
  seconds to forty. Ask the lattice about a box.

- **Cells come *out* of the boxes, never worked out twice.** A turned part's
  cover costs a separating-axis test on every candidate cell, so computing it
  once as boxes and again as cells runs the expensive half twice:
  `BrickLattice.cells_in(packed)` expands, and `Builder.boxes_for` caches turned
  covers by part and angle, so a section of two hundred bricks pays for one.

- **`PackedInt32Array` is a value type.** `(dict[key] as PackedInt32Array)
  .append(x)` appends to a copy and throws it away. That made `compress()`
  return almost nothing, so collisions and support silently vanished — 82
  failures in `attach`. Read it out, append, put it back.

- **Measure the baseline before optimising this.** `section_probe` was 28 s and
  its four-failing-sections case 6.5 s before any of this. Three rounds were
  spent optimising the hint sweep on the strength of a guess; disabling hints
  entirely still took 42 s, which proved the time had never been there.

- **"No studs on top" is not the same as "nothing grips".** The smooth-face
  advice first fired whenever no stud *reached* the part, which
  `_studs_reaching_in` answers by sampling 5 LDU past a stud's tip — and for a
  part whose underside the occupancy left open, that sample lands in the cavity.
  A flower correctly pressed onto a 2x2 round brick was told the brick had no
  studs; it has four. Then, basing it on `stud_count == 0` instead, it
  complained about both hinges in `models/car.ldr`, because a hinge base holds
  by a hinge and the library has no connector kind for one. It is now limited to
  `SMOOTH_ON_TOP` — Tile, Slope, Panel, Baseplate — which is a positive list on
  purpose. The regression guard is that all eight shipped models produce **zero**
  complaints; mutate the category guard away and `clutch_probe` reports the
  car's two hinges.

- **Reconstructing a placement from an LDraw transform needs `_corner_cell`.**
  A placement's x is the part's *corner*; an LDraw origin is wherever the author
  put it. Dividing the origin by a stud puts a 1x1 plate half a stud out and
  invents off-grid offsets — six of them, across models that have none. Invert
  `_square_transform`: `to_cell(origin) + _corner_cell(part, id, basis)`, and
  `_corners_in_studs` does.

- **Half a stud is judged by where the studs went, and the socket data lies.**
  Taken at their word — sockets and 2 x N tubes only — the catalogue refused
  477 half-stud seats in the 328 fetched real sets. Sockets are
  measured from the part's own edge, so a part narrower than a stud or with
  an overhang has them off its grid (3957a at 2, 2; a tree 4 LDU; a hinge
  plate 2): `_underside_of` moves them onto the grid of its top studs or
  tubes, and adds the top studs' places (4488 records two sockets of four). A
  1 x N's post fits a hollow stud (10218, 10276), 15573 has no post at all,
  60474 takes a jumper in a corner bore, a narrow foot's tube sits between four
  studs (6255, 98374, 4022), and a train buffer's studs are 6 LDU off. Then 59
  of 2,828 (`half_studs_in_sets.gd`), none on a jumper: plain plates exactly half a stud off in the set
  file (31049, 7735, 10190, 6542), flower stems (3741) between four studs,
  train and turntable parts. Half-shifted data hid too: 16 worked examples
  stood half a stud off any floor as a whole (all shifted back), "taper" put a
  1x1 on a plain 2x2's middle (an 87580 now), the bedside lamp's tap sat half
  off its jumper, and the lighthouse's eight slopes were half off their
  bricks (seated; its two overlaps were two of them). A stud exactly on a
  part's edge reaches it only on its low side (cell rounding), so the lamp's
  fault showed at two of four turns; all 73 section-free examples pass at
  every turn now.

- **The corner is the footprint's, not the cover's.** For a part drawn inside
  its footprint the two differ: a 4 x 4 wing (3935) starts at -38 of a -40 box, a
  turntable's top is 36 across on a 2 x 2. Named by the cover's corner, every
  one placed at whole studs stood 2 LDU off the studs below — 24 wing tips on the
  owner's tower of Orthanc — while the wing patterns had meant the footprint all
  along. `_footprint_start` moves the corner to the *nearest* line of the
  part's own stud grid (outward only on a tie — a seat's backrest overhangs 4
  LDU, and snapped outward its corner was a stud off), read off its upward
  studs (tubes where it has none). A stud is mid-square unless the cover lies
  exactly on the half-shifted grid and not on the other, which is a jumper; a
  looser test let a tap's spout win. A part with neither, a pane or a pin,
  keeps the cover's corner, and so does a minifigure part (`_figure_part`): a
  skeleton's neck stud sits on a line and figures are put together by
  transforms. Upright parts only. `world_view_probe` checks it; switch the
  snapping off and it reports 78 placements off and the ellipse's wings 2.0
  LDU off. Changing it means rewriting every worked example that names such a
  part so it stays put (15 did, most to cleaner numbers), and
  `techniques_probe` now stands each on a floor, which found three read off
  real sets a tenth or two off the grid as a whole.

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

- **Which way a cylinder faces is its INVERTNEXTs, not its matrix.**
  `geometry.flatten` reverses the winding under a mirrored matrix, but only
  because mirroring reversed it first; the two cancel. Counting the mirror in
  `connectivity._round_walk` made every bar of the lance 3849 a bore (its
  cylinders are laid along z by a matrix with a negative determinant) and every
  clip's eye a shaft. `test_a_mirrored_bar_is_still_a_shaft` holds it.
- **A round joint's zone has slack, and a turned part needs more.** A square
  part's cells are those whose middles are inside it, and its boxes reach half a
  cell's diagonal (1.41 LDU) past a curve, so `ROUND_SLACK` is 1.5. A turned part
  keeps every cell its boxes touch at all, another half diagonal (1.73), so
  `ROUND_SLACK_TURNED` is 3.2. Measured with `joints_probe`: at 1.5 a turntable's
  top turned 10, 30 or 45 degrees on its base is an overlap; at 2.5 it passes.
  Only the zone grows; the joint itself still needs the axes within 1 LDU.
- **A bore is empty only between its wall and what stands inside it.** 3941, a
  2x2 round brick, is a bore 16 across with its centre tube, a shaft 8 across,
  inside it. So a joint's zone is each part's bores on that axis *that the
  other's shafts reach*, less the part's own narrower shafts in them (`cores`,
  `Joints._zones_of`). Taking every coaxial bore as empty would have forgiven
  anything overlapping the tube once a pin was in its foot; the probe's
  synthetic 3941 fails without the cores.
- **A loose fit is not a joint.** A bar 4 across in a tube 6 across (the
  bottom of 3062b) is physically clear of it, but it is also what a bar pushed
  into solid plastic would look like to a looser rule, so `ROUND_FIT` stays at
  1 LDU and that lamp (31038) stays refused.
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
