# Geometry

Whether a brick here is the size of a brick in your hand, and whether two of them
can occupy the same millimetre.

<!-- covers: lib:occupancy lattice, lib:sideways building, lib:angled sections, lib:turned any way on hinges, lib:stability, lib:balance, ui:balance readout, lib:round joints, lib:flexible parts along a path, lib:mechanisms, lib:axles and gears on a line, ui:simulate mechanism -->

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
  occupied cells are recomputed for each. A placement names its cover's corner,
  and a cover is not always the part: on its side a wedge plate's is pulled in
  a cell at its cut end, and the 2 x 2 wedge (24299/24307) is 38 LDU across, so
  a wedge laid by its corner stands two LDU off the plate beside it. A blade
  (`Assistant._by_its_body`) seats its wedges by their mesh's bounds instead;
  `patterns_probe`'s blades have no slit between parts.
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
- `turned any way on hinges` (`src/ai/hinges.gd`, `Section` in
  `src/ai/assistant.gd`): a section turns yaw, then pitch, then roll (its +z
  the nose: yaw swings it to +x, pitch lifts it, roll lifts its +x side), or
  about any axis (`line`); is built `within` another, whose frame it rides;
  and repeats round a centre (`around`, a `yaw` step per copy, children
  copied with it). A single part's yaw/pitch/roll makes it a section of one
  (`_turned_parts`), and edit_model's `turn` turns named bricks about their
  middle, as the inspector's Turn/Tilt/Roll do (`Builder.turn_selection_basis`).
  `hinge: "tilting" | "clip" | "click"` lays both halves (`_lay_hinge`): the
  base where x, y, z say, in the parent's frame — in a frame of its own,
  `<name> hinge`, turned by the yaw about its first stud, when the yaw is off
  the square — and the top in the section, the line read off the parts'
  shaft/bore or finger/fork records (`Hinges.line_of`); "click" is offered
  only where the catalogue's 44302/44301 carry finger records. The check holds
  a leaning section only through a Joints pair with a part outside it
  (`leaning on nothing` otherwise), says a hinge asked to tip two ways, and
  reads two-axis turned bricks from a file back into a section (`_adopted`).
  `hinged_panels_probe`: two- and three-axis turns, a part turned alone,
  within, round a centre, a panel on each hinge at three yaw/pitch pairs, a
  dome 33 studs across of 12 strips (6, and 6 raised on spacers lapping over
  them as scales) of 36 hinged panels at 48 two-axis angles under a dish,
  held with no overlap, four sideways skins on side studs, an edit saying
  only a new pitch, and a part tipped by the window read back tipped. It
  fails on the code before (f2cbfe6): the dome's sections are not read at
  all ("hinge": "clip" stops the reader), and with hinge: true its panels
  lie at 2 angles with 115 overlaps. `-- --dome_ldr=PATH --band_ldr=PATH`
  writes them out to look at (`bench_views.gd --views=corner,front,right,top`).
  The quarter turns are exact (`Section.exact`) and frames lose their float
  dust (`Section.dusted`): a skin on side studs read a ten-millionth of a
  stud off was rasterised a cell away and called adrift.
- `stability`: whether what was built would survive being picked up — what rests
  on what, what is floating, and what is attached by one stud at the end of a
  cantilever. It also says when the whole model tips over on what it stands
  on ("tips", from Balance's support polygon), which its levels never could on
  a baseplate: the plate is under every cut, as wide as the ground. Masses
  count the tubes under a part; every one of seven bricks is within 6% of
  BrickLink's weight (a 2x4 2.46 g against 2.32).
- `balance` (`src/assembly/balance.gd`, pure; docs/MECHANISMS.md §4, phase S1):
  whether the model stands on what it stands on, by how much, and which stud
  joint gives first. The support polygon is the hull of every box within half
  a plate of the lowest cell (the baseplate, `floor_ids`, left out); the
  tipping margin is the centre of mass's distance to its nearest edge in
  studs, the force angle the tilt that carries it over (atan(margin/height),
  Papadopoulos and Rey). Stud joints that are bridges in the graph of what
  holds what (studs from `Stability.contacts`, pins, clips, hinges and
  turntables from `Joints`) carry everything beyond them: the moment about
  the edge they would turn on against M = Σ F·dᵢ at 1 N a stud (working) and
  3 N (lets go), and the pull on a part hung under another. Joints in bonded
  walls share load statics cannot split and are left to Stability's levels.
  Counterweight advice is the least w at the best place (within 4 studs of
  the far edge, or the middle of the base when poses tip more than one way)
  that brings every pose half a stud inside, found by bisection, or the
  studs the base would have to widen. Poses come as `{label, transforms}`:
  `Poser.sweep` gives the Pose panel's animation frames, or every joint
  swung through its reach a 15° step at a time (room checked as the slider
  does); a mechanism's cycle will hand its frames over the same way. A pose
  that puts a part through the floor is left out. check_design weighs the
  design on the lattice it was checked on (`Assistant._weighed`, worker-safe)
  and, once it stands in the world with joints to turn, over the sweep
  (`_balance_said`), and puts the numbers and what to do in its result.
- `balance readout`: Tools, Check stability (`Shell._check_stability`). The
  margin in plain words on the status bar's line, kept there while the marks
  are up (`Shell.balance_line`); the support polygon and the centre of mass
  dropped onto it drawn on the floor over the model (`BalanceMark`, green,
  amber within half a stud, red past the edge, a second ring for the worst
  pose and a line for the margin); the part past each stud joint at half its
  working load or more tinted amber to red (`BrickWorld.set_tinted`). Working
  shows while it weighs, on a worker from 600 parts. A change to the model
  takes the marks and the tint away.
- `clutch`: whether two parts that touch could really hold each other. The
  lattice is 2 LDU and the connection system is 20, so a position can be legal
  on the grid and impossible in plastic — a brick three tenths of a stud across
  from the one below, a plate half a stud along a plain plate, or standing on a
  tile (`Assistant._note_loose`). Standing on a tile is advice. A fraction of a
  stud off is a fault ("off its studs") between two parts that each have a stud
  or tube facing up or down (`_has_a_grid`); a horn or a pane has no grid to be
  off. **Half a stud off is judged by the studs, not the grid**
  (`_underside`, `_none_off`): every stud standing where the part's underside
  is (`_studs_reaching_in` gives each one's place and way; one lower, which
  only touches it, is left out) has to be somewhere the part takes a stud
  (`_underside_of`) — a socket, a top stud's place, a tube, a vertical pin
  hole or bore, the point between two sockets of a part one stud wide (a
  1 x N's post fits a hollow stud, and a jumper's is hollow; 15573 has no
  post), or, for a foot narrower than a stud, the four studs round its tube.
  A stud half a stud along from all of those stands against a wall, a post or
  a tube's side: "half a stud off", naming a jumper and the whole stud that
  grips. One half a stud both ways is in the cavity where a tube is or would
  be, which is no fault if another stud seats the part by a socket (an angled
  tile's open end), and is the edge of a plain part half a stud both ways off
  plain studs if none does. A jumper's one stud (3794a/b, 15573; 87580 for a
  2 x 2) stands on the half, so a part on one passes, and so does a part on
  the studs of a part a jumper carries. Only parts whose underside the
  catalogue describes are judged (`PLAIN_UNDERSIDES`: bricks, plates, tiles,
  slopes and the like); an animal, a windscreen, a train base or a plant is
  hollow underneath in ways it does not record. A stud 0.8 of a stud or more
  from everywhere the part takes one is not judged either. The x and z
  offered for either fault are the least move that puts a stud reaching into
  it in one of its sockets (`_nearest_move`), not the half-stud grid: that
  offered x=0.5 for a part 0.3 off a plain plate.
- `technic joints`: pins, axles and ball joints as real attachments, alongside
  studs. Two pieces: the hole has to be *open* in the occupancy lattice (so a
  pin is not a collision), and the two connectors have to be *matched*
  (`Joints.both_ways` over `Assistant._mating_entries`, so the pinned part is
  not floating). By hand the same rule decides whether a part has room
  (`Builder.room_for`): with a pin, axle, beam, clip or bar in hand the ghost
  goes onto the connector aimed at (`JointSnap`, see `building.md`, "snap
  onto a joint"), and `technic_hand_probe` asks check_design about every
  model it builds that way, and about the same parts a stud or 2 LDU off.
  Since the covers keep holes open, a pin square in a hole shares no cell
  with it; a pin turned 45° about it (a turned cover) shares 184 with 3700,
  and a bar in a hollow stud 192 with 3062b — both forgiven, the same parts
  off the line not.
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
  rounds; see `pipeline.md`. Joints are matched where a part is: one read off
  the world on no grid, outside any section and not moved by the edit (a
  minifigure's part, read back at the nearest square turn), has its joints
  read off its own transform (`Assistant._joined_at`). Read square, a hand
  turned 45 degrees in its arm had its peg nowhere near the arm's socket, so
  no hand was joined to its arm and whether a figure was one piece depended
  on which cells the squared parts shared: run 5's Orthanc had Saruman's
  raised right hand as a piece of its own. `minifig_probe`'s "one piece, as
  the design checker reads it" holds it. For pieces only (not support, not
  overlaps), `Joints.pushed_in` also joins what is pushed into what without
  two connectors to pair: a bore no wider than a pin hole (6 LDU) whose middle
  another part's cover fills (anything in a hand's grip, a clip's eye, an
  arm's socket), a peg whose middle is inside another part or that has one
  other part on every side of it (a peg in a hole the cover leaves open: the
  stump 6828's in 5059), a part whose origin is on a post's axis (a cloth
  cape round a torso's neck, drawn about it), and a visor and a helmet whose
  side pivots are one point on one axis (`MinifigData.PIVOTS`). The covers
  asked are where the parts really are (`Assistant._filled_by`), not the
  square turn the checker's lattice has them at.
- `axles and gears on a line`: an axle or a pin is in every hole along its
  whole length (`Joints.through`, by Mechanism's own rule: on the line to
  1.5 LDU, the hole's middle no more than 2 LDU past an end; a pin not in an
  axle hole), "grips" in an axle hole and "turns" in a round one. Those pairs
  hold and are forgiven like any pin (`Joints.pairs`), so one axle carries both
  walls of a frame and the gear between them. Gears that `Mechanism.build`
  finds in mesh (spur, crown, bevel, worm, ring, at the table's pitch to
  1 LDU) are forgiven too and hold nothing (`Joints.meshing`): in the check,
  by hand (`Builder.room_for`) and in `OpenPoints.test`. Two gears in one plane
  that overlap are told the spacing they mesh at (`Assistant._gears_apart`);
  two up to 6 LDU too far are said not to mesh, and the check says what each
  axle grips and turns in (`Assistant._drive_said`). A placement may be said
  by its line: `axis` (x, -x, y, -y, z, -z) and optional `joint` make x, y, z
  where that joint's middle goes (`Assistant._onto_lines`), and a joint part
  with no studs whose corner was written at another part's hole or axle, and
  overlaps it there, is put in it and told so (`Assistant._seat`). The owner's
  orrery session wrote 2780, 3706 and an axle through 3649 at the point
  attachment_points gave, and every one was refused before this.
  attachment_points numbers each part's joints with turns/grips;
  look_at_model says each joint part's line; a turntable's turning point is a
  joint, so its top goes on its base by one point.
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

- `flexible parts along a path` (`src/assembly/flex.gd`, pure): a bent hose is
  the real part's LDraw segments along the bend, as every tool that bends one
  writes it. Ribbed hose: `71944k01` ends and `71944k02` rings every 6.25 LDU
  (the 17L is 54 pieces either way). Pneumatic tube, flex-system hose: the
  one-LDU tube (`71533k03`, `77`) **stretched** piece by piece, cut wherever the
  path has turned `PIECE_TURN` (4°) and where each straight lead into a
  connector ends, end caps at the tips. Flexible axle: only the 26L (72892) has
  LDraw parts to bend (`u9011` and `u9010` rigid ends, `u9012` stretched
  between); the 7–19L are drawn from subparts and cannot be. String: `71149k01`
  stud ends on studs and `71149k02` braids every 6, hanging (its middle drops
  until it is 588 LDU, 14225's). The path is straight out of each connector,
  then a Hermite bend through any control points whose end tangents are as
  long as makes it the real part's length; too short says "the path is longer
  than this …", tighter than `bend` says so. Chains (3711) and treads (3873):
  the pin circles of `SPROCKETS` (a gear takes a link every other tooth; r =
  8 / sin(π/N)), the outer tangents between them, links chord-walked exactly 16
  apart, as many as go round rounded up, the spare hung in the longest, lowest
  run until the last link's pins are in the first one's hook. A stretched
  part's cover is its own stretched (`Builder.boxes_for`): the turned covers
  took a turn only, and gave a piece 40 long a cover one long.

## How to reach it

GDScript: `src/assembly/lattice.gd` (cells, `cells_for_turned`, `is_square_to_grid`),
`src/assembly/stability.gd`, `src/assembly/balance.gd` (with `Poser.sweep` in
`src/assembly/pose.gd`), `src/render/balance_mark.gd`, and `Section` in
`src/ai/assistant.gd`. In the app: Tools, Check stability.
Python: `tools/ldraw/occupancy.py` (the same lattice, used by the mesh build).

## How to check it

Static: the Python half is pinned by `tests/test_ldraw.py` — stud pitch 8 mm,
brick 9.6 mm, plate a third of a brick, −Y up, and the lattice dividing every LEGO®
dimension. **The six tests that voxelise a part need numpy and scipy** and skip
without them, which is 25 of the 67 cases.

Runtime:

```sh
godot --headless --path . --script src/dev/dimensions_probe.gd   # in millimetres
godot --headless --path . --script src/dev/snap_probe.gd         # cells
godot --headless --path . --script src/dev/snot_probe.gd         # held sideways
godot --headless --path . --script src/dev/technic_probe.gd      # pins, axles and open holes, a pin in 6222/18897
godot --headless --path . --script src/dev/joints_probe.gd       # clips, bars, hinges, turntables, panes
godot --headless --path . --script src/dev/hinged_panels_probe.gd # turned any way, on hinges: a dome, a band of skins
godot --headless --path . --script src/dev/flex_probe.gd         # chains on their sprockets, hoses between holes
godot --headless --path . --script src/dev/technic_hand_probe.gd # the same joints made by hand, a clip on 2540's handle
godot --headless --path . --script src/dev/axle_probe.gd         # axles through holes, gears in mesh, a crank's train at 1:3
godot --headless --path . --script src/dev/clutch_probe.gd       # positions that cannot be built
godot --headless --path . --script src/dev/angled_probe.gd       # not square to the grid
godot --headless --path . --script src/dev/section_probe.gd      # built square, carried at an angle
godot --headless --path . --script src/dev/world_view_probe.gd   # parts drawn inside their footprint sit on studs
godot --headless --path . --script src/dev/stability_probe.gd    # arrangements with known answers
godot --headless --path . --script src/dev/balance_probe.gd      # margins, joints, counterweight, poses by hand
MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 \
  --script src/dev/balance_view_probe.gd                         # the readout and the floor marks, in shots/balance/
godot --headless --path . --script src/dev/holds_probe.gd        # and whether the assistant is told
godot --headless --path . --script src/dev/attach_probe.gd       # are the coordinates usable
python3 tools/minitest.py tests/test_ldraw.py                    # or pytest, if installed
```

`joints_probe` ends on "the joints real sets use pass, and the same parts apart
do not": each family where real sets put it, and wrong — a bar through a brick
with no hole, a Technic axle in a clip, a hinge's top half a stud into its base
or 2 LDU off its pivot or swung into its base, a turntable's top 2 LDU or a stud
off its base, or turned 45 degrees about the wrong point. And parts turned 30
degrees about the upright read from a file, in the sections the assistant finds
for them (`Assistant._adopted`, see [assistant](assistant.md)): a frame and its
pane, a turntable's top on its base, each passing, and the pane not turned into
its groove refused. And real sets' sub-models tipped on a hinge about a flat
axis, read from a file (10179's hinge at 53 degrees with a jumper and a bar on
it, 6285's rail on three hinges, 75144's panel, 21307's hinge at 60): each in
one piece, where read square they were refused in two. On a catalogue built
before the rounds its first five lines fail, and every case that should pass
fails with them.

`clutch_probe`'s "half a stud off" block holds the half-stud rule both ways: a
2x2 plate half along a 2x4 plate, a 2x4 brick half along a 2x4 brick, a 2x2
half both ways (one stud in its tube) and a 1x2 back on the base grid on a
jumper-offset 2x2 are refused; a 2x2 by its tube on a 3794b, a 1x2 half both
ways on an 87580 and a 1x2 on the studs of that offset 2x2 build. Against the
rule before it, six of its lines fail. Real sets, when the rule changes
(needs `tools/omr.py fetch`; a few minutes, not in the suite):

```sh
godot --headless --path . --script src/dev/half_studs_in_sets.gd -- vendor/omr/files
```

Proves it when the last line's two refused counts are equal: every seat it
refuses has the part's own plastic inside a stud in the set file. A line
ending "NOTHING IN THE WAY" is a real seat the rule refused, and the rule's to
fix. 31 of 2,828, all in the way, on 2026-10-11.

`mechanisms` (`src/assembly/mechanism.gd`, docs/MECHANISMS.md phase P1a; no UI or
MCP tool yet): gear trains read off the parts and turned. It reads the bodies and
joints from the connectors (an axle keyed in an axle hole, an axle or a pin turning
in a round hole or a bore its size, studs in sockets, two pins through two beams, a
turntable's top on its base, a differential's planet on its casing's stub, a
driving ring on its ridged joiner and in the clutch gear it is pushed into), the
gears from `assets/ldraw/gears.json` (see [pipeline](pipeline.md), `check the gear
table`), and solves one linear equation per coupling (spur, crown, bevel, worm,
ring, chain) by sparse elimination:

```sh
godot --headless --path . --script src/dev/mechanism_probe.gd       # the ratios
MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 \
  --script src/dev/mechanism_probe.gd                                # and drawn, in shots/mechanism/
godot --headless --path . --script src/dev/mechanism_sets.gd        # 42055 and 42082 read whole
```

The probe proves it when it ends on "mechanism: gear trains read off the parts …".
Its first cases are exact ratios where the 2 LDU lattice stands gears off their
pitch: a worm 46 LDU off a 28 tooth turntable (for 45) turns it once in 28 to
1e-6, not 28.8, and is said "46 LDU apart for 45, 1 LDU loose" (`off_spacing`,
and in `Simulation.trouble_lines`); the turntable's base, resting on a 3033's
studs with no socket recorded, is held with the plate (`_rest_on_studs`); an 8
to a 40 and a 12 to a 36 three studs apart (-1/5, -1/3); a 20 to a 16 idler to a
20 on two stud diagonals (44.72 for 45), the idler -1.25 and the output exactly 1,
not said to be off. All but the 8/40 and 12/36 fail with `_gear_mesh`,
`_ring_mesh` and `_worm_mesh` putting the point at one gear's pitch circle, as
P1a did. The other cases are 8020's windmill from the OMR (9:1, crank to sails; skipped without
`tools/omr.py fetch`), an 8 driving a 24, the same axles also joined 16 to 16
(locked, both meshes named), a worm driving a 24 (1/24), a two-planet orrery
(Mars's year 1.96 Earth years against 1.8808), a 12 carried round inside four
24121 quarter rings (140/12 on its arm), a quarter held by nothing turning on its
rim (12/140, the same way), a Flex-laid chain from a 24 to an 8 (3:1, the same
way), a gearbox whose driving ring is in neutral and pushed into each clutch gear
(free, then 1:1, then 3:1), and a 62821 differential (one driver leaves one
freedom; two drivers decide it, and the sides' rates sum to twice the casing's to
1e-6, the 32-bit transforms' precision). It first checks that the catalogue it
reads has every table gear's hole: a catalogue built before `connectivity.py`
read 3648's centre axle hole fails there. The fix is a sub-build of the parts
`connectivity.py` changes, merged (`tools/build_meshes.py --only <ids and 200
unchanged controls> --out DIR`, then `tools/merge_subbuild.py DIR ids.txt`; see
[pipeline](pipeline.md)), or a full rebuild. With a display, every frame is read
back off the renderer's copy, and each output must turn its ratio times the
driver's step to 0.01°. The sets script ends on "mechanism sets: 2 read, every
gear on what it turns on or said why not": each gear that floats is a near miss
the file draws (42082 stands two 24s 2 LDU off their axles) or in a group that
touches nothing else (42055's mine truck, a second model in the file), read
again on its own with nothing floating there. Anything else fails, said with what
stands on its axis and the holes its axles nearly turn in.

Axles and gears: `axle_probe` ends on "axles: a pin and an axle go in the hole
attachment_points names, an axle carries every part on its line, gears in mesh are
not an overlap, and a crank turns an 8, a 24 and an arm at 1:3". It drives the
tools a session calls (use_tool) with the numbers they hand back: the owner's
sequence first (attachment_points on 3700 at 80, 0, 80 gives 81, 1.75, 80.5 along
z; 2780 there by a quarter turn, by face +z and by axis, axle 3706 by a quarter
turn and by axis, each applied with its middle in the hole; submit_design too; the
same pin half a stud along still overlaps), an axle through a 40's hole at the
point attachment_points gives it (grips the gear, turns in 3700); the brief's train
(a frame of 3702s, a crank liftarm with a handle, an 8 and a 24 two studs apart, a
bush and a half bush, an arm) buildable with the mesh named, then built and solved
by `Mechanism`: the arm turns -1/3 of the crank, the handle, 8 and bush with the
crank, the frame still; two 24s two studs apart refused with "60 LDU (3 studs)
apart", an 8 and a 20 said not to mesh at 35 LDU; the orrery's stages (40 with 40
five studs apart, a 24 to an 8 idler to a 24, a 20 driving a 12) with four meshes
and rates -1, 3, -1 and 5/3; a worm on a crank's axle into a turntable whose top
went on its base by the point attachment_points gave, 1/28 a turn exactly (46 LDU off
for 45), the base held still by the plate's studs it rests on; and by hand, a
24 has room two studs from an 8 and none at 36 LDU. Windowed (`MESA_VK_WSI_DEBUG=sw
xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/axle_probe.gd`)
the train is drawn turning, 16 frames read back off the renderer's copy with the
arm a third of the crank's step the other way to 0.01°, into `shots/axles/`. A
catalogue without 3648's centre axle hole (before mech1's connector fix) fails
the train: see `pipeline.md`.
`simulate mechanism` (`src/ui/simulate_panel.gd` over `src/assembly/simulation.gd`,
docs/MECHANISMS.md phases P1b and P1c's readout): Tools, Simulate mechanism…, beside
Check stability because both read the model and change none of it (Pose is under
Build because each slider is an undo step). It reads the mechanism (Working: "Reading
the mechanism…", on a worker from 600 parts), drives the part a sub-assembly named
Crank, Motor, Handle or Driver marks, else the one selected, else the one that turns
most of the train; a click on an axle or a crank (the Select tool is put in hand)
drives that. The panel is docked in its own column beside the model's (main's
`_simulate_column`), the parts column folded while it is open and put back after,
so the lens centres the model on what is left and no gear is under the panel (over
the model's left edge, at 1600 x 900 at 2x it covered half the train and a click
meant for the 8's axle selected the 24). The base is the baseplate and what stands
on its studs (a socket or none: a turntable's base resting on a plate), plus any
sub-assembly named Frame, Base, Stand or Chassis. Turning parts are tinted by speed
(blue slow to orange fast), the driver white, the meshes that lock a train red, free
bodies amber, floating gears violet, each named with part numbers in the panel. Play
turns the driver at the speed chosen, the slider covers the cycle (every turning part
round at least once), Worst balance goes to the frame where it comes nearest tipping.
The turning parts are drawn where the simulation puts them (`BrickWorld.set_drawn`):
the model, the lattice, the history and `world.revision` never move. With a body
named after a planet and another as the reference (Earth by default), periods read in
its years against NASA's sidereal periods ("Mars arm: 1.96 Earth years; real 1.8808,
+4.2%"). The balance is `Shell.weigh_balance` over 72 frames of the cycle, the polygon
and the centre of mass on the floor, and the turning part furthest past the base's
edge named. Record draws one turn of the reference (or the driver) through
`StudioRender.animate` into `RenderOutput` (WebP, and on the desktop frames and an
MP4). Over MCP `simulate_mechanism` (AppTools, `SimulatePanel.for_session`) says the
same with a picture of the worst frame; record=true is a job (`ToolJobs.long_call`),
its frames counted on it, polled with `job` and stopped by its cancel.

```sh
MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1600x900x24" godot --path . \
  --resolution 1600x900 --script src/dev/simulate_probe.gd   # add -- --write to write src/dev/fixtures/{orrery_two_planets,gears_locked}.ldr
MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 3200x1800x24" godot --path . \
  --resolution 3200x1800 --script src/dev/simulate_probe.gd  # the same layout at 2x
godot --path . --resolution 1400x900 -- --mcp=8795 &   # under xvfb; then
tools/mcp_check.py --port=8795                 # simulate_mechanism as a session asks it
```

The probe ends on "simulate: a driver clicked, played, scrubbed and recorded, …".
It builds its two models part by part on the baseplate: an 8 driving a 24 in a
3709b (with a 16 free on the 8's axle and an 8 lying loose), then two 16s meshed
too; and mechanism_probe's orrery on two pillars, its beam and turntable base named
Frame. It clicks the 24 and then the 8's axle (each its driver, 1:3 and 3:1 the
other way), plays (every played frame's 24 turns a third of the 8's step back, to
0.0000°, read off `drawn_at`), scrubs to a quarter of the cycle, records 24 frames
and reads every one back off the renderer's copy (`StudioRender.staged_transform`,
through the panel's `frame_drawn`), finds the free 16 and the loose 8 named by
number, the locked pair named and red, Mars's year "1.96 Earth years; real 1.8808,
+4.2%", the balance over 72 frames with "Furthest out: Mars arm, 3 studs past the
left edge", Worst balance going to Crank at 329°, a recording of one Earth year
(0.7143 crank turns) with Earth turning 1.4 and Mars 20/28 of every frame's crank
step, simulate_mechanism through AppTools with a picture, and every part where it
was built, the history as deep and `world.revision` unmoved throughout. Pictures:
`shots/simulate/1_train.png` … `4_orrery_worst.png`, `5_session_picture.png` (the
hero view a session gets), the recordings in `shots/simulate/{train,orrery}/`.
On 2026-10-13 under a load of 50 on this box a 24-frame Quick recording took 79-88
s, so over MCP a recording is a job, and mcp_check polls it to its end. With the solver broken on
purpose (the two sides of a mesh pulling the same way, `_row`) eight checks fail:
both clicks' ratios, the readout, every played and every recorded frame of the
train, Earth's and Mars's rates and the recorded year; put back, all pass.
`mcp_check` opens the two fixtures (written by the probe's `--write`) as a session
can, and checks the driver, Mars's year, the balance, the picture (or, headless,
that it says why there is none), reference= and targets= (Earth 0.5102 Mars years
against 0.5 asked for, +2.0%), a refusal, record=true (a job at once, polled to its
end, the WebP and MP4 read off disk), and the locked train's meshes and floating gear
by number. Any call that becomes a job (past 20 s: a windowed app weighing and drawing
the orrery on a loaded box) is followed with `job` as a session would
(`followed`). Run the windowed app with its own `XDG_CONFIG_HOME` whose
`user-dirs.dirs` points Downloads at a scratch folder: a recording saves where
Render does.

Balance: `balance_probe` ends on "balance: the margins, the joints and the
counterweight come out as worked by hand, the shipped models stand, and the
worst pose is found". Its cases and their answers by hand: a 1x8 plate on one
stud of a 1x1 (the plate's weight on a 3 stud lever against 0.4 N·cm, and the
whole 2.13 studs past the 1x1); a staircase of 2x4 plates a stud further out
each (0.5 studs inside at 4, on the edge at 5, 0.5 past at 6; the root of 6
carries five plates on 1 stud against 7.2 N·cm); a tower of 2x2s on a 1x1
(half a stud, force angle atan(10/93.4) = 6.11°, no moment at its foot); a
1x1 hung under a plate (pulled by its weight); a 2x2 held only by a link
(adrift without it, carried by the foot with it); a 6x6 base with an arm 18
studs out (tips 2.8 past; the advice, w·L = m·d with half a stud to spare,
followed with 2x4 bricks, stands 0.6 inside, and Stability's own verdict says
"tips" before and not after); house, car, lighthouse, castle and kart
standing; a turntable arm over a 2x8 base, standing as built and 1.1 studs
past the front edge at 90° of the 24-pose sweep, its middle-of-the-base
counterweight m(1 + 2d) by hand, and the same pose found from a keyed
animation; and check_design's words. On 2026-10-13 every check was made to
fail once by breaking the code it guards (moment about the edge, the tubes,
Stability's tipping, the sweep's two ways, the floor, the ground edges, the
links, the hull's sign, the worst-pose pick, the advice's spare, the widen,
the animation frames, a sweep that moved the model, check_design's weigh
flag), each a one-line change, and passed again once put back.

`balance_view_probe` ends on "balance view: the readout, the polygon and the
centre of mass on the floor, the overloaded joint in red, the counterweight it
asked for holds it up, and the worst pose of a sweep is found". Look at
`shots/balance/1_tips.png` (red polygon under the 6x6 base, the white drop
line and ring 4 studs right of it, the posts and the first arm plate tinted,
the status line "Tips over, 4.1 studs past the right edge. Add 22 g …"),
`2_stands.png` (green, the ring just inside the right edge beside the stack
of 2x4s) and `3_swept.png` (a second, red ring past the front edge for "Arm
at 90°"). Broken on purpose, it fails on: no Working line, no tint, the
words gone with the message after 4 s, marks left after a change, no
counterweight in the words, the marks never shown, and no poses swept.

Proves it when: every probe exits 0 with no `FAIL`, and `dimensions` ends on
"every measured part is the nominal size, exactly" — a 2×4 brick measured at
32.00 × 9.60 × 16.00 mm, three plates to a brick, 8.00 mm stud pitch. It prints
one `--` line on purpose: LDraw draws a 1.6 mm stud where the LEGO Group moulds 1.8 mm.

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
  The contact graph on Orthanc (`models/orthanc.ldr`, 8,785 parts, 5,345 of
  them turned) was 10.4 s of an 11.0 s check, four times building it: a turned
  part's cover is a slice a cell deep for every z it spans (38 boxes on
  average, 837 for the biggest turned plate), and two covers were compared box
  against box twice, once by `blockers_boxes` to find what touches and again
  by `shared_cells` to count it (3.8 s and 6.5 s). Now the candidates are
  every brick whose bounds meet (`BrickLattice.near_bounds`), the count is the
  test, and a cover of eight boxes or more is sorted into its slices once
  (`slices_of`) so each box of the other meets only the slices at its own z
  (`shared_cells_sliced`): the graph is 1.6 s and the check 2.2 s, 0.78 times
  building it, with every pair's count the same (all 23,501, compared
  2026-10-11) and the same 7,531 joints and verdict. `stability_probe`
  compares the two counts on every joint of a thousand of Orthanc's turned
  parts and holds the check under twice the cost of building it; the old code
  was 4.4 times.
- **The lattice stores boxes, and anything that asks it per *cell* is a bug.**
  It used to be a Dictionary with one entry per 2 LDU cell — 9,600 for a single
  2x4 brick — plus `_columns` holding the same volume again. Eight thousand
  bricks took **9.24 GB**, which is more than a browser gives the whole app, so
  the size of a model was capped by how collision was stored rather than by
  anything about LEGO® bricks. Fifty thousand bricks now cost **180 MB** and 938 ms.

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
  477 half-stud seats in the 328 fetched real sets. `half_studs_in_sets.gd`
  settles each against the upper part's own mesh: plastic inside the stud's
  ring is a file with two solids in one place, none is a real seat the rule
  refused. Sockets are measured from the part's own edge, so a part narrower
  than a stud or with an overhang has them off its grid (3957a at 2, 2; a
  tree 4 LDU; a hinge plate 2): `_underside_of` moves them onto the grid of
  its top studs or tubes, and adds the top studs' places (4488 records two
  sockets of four). A 1 x N's post fits a hollow stud (10218, 10276), 15573
  has no post at all, 60474 takes a jumper in a corner bore, a pot's narrow
  foot sits between four studs (98374, six times in 75969), an angled tile's
  open end has a stud in it (22385, five times), an inverted slope's stud 4
  LDU down only touches the plate on it (10197), and a pig, a roll cage, a
  train base and flower stems stood on nothing but air. Now 31 of 2,828,
  none on a jumper, and the mesh puts the part's plastic inside a stud in
  every one: a sub-assembly seated half a stud off the one under it, all of
  it agreeing with itself (6542's deck on its boat studs, 7735's
  platform, 31049's cockpit, 6541's crane on its turntable), or one part
  typed half a stud out between two that agree (6598's 2x2 plate at z=70
  between a 6x10 plate and a box at z=60). Each is the probe's own case, a
  plain plate half a stud off plain studs. Half-shifted data hid too: 16
  worked examples stood half a stud off any floor as a whole (all shifted
  back), "taper" put a 1x1 on a plain 2x2's middle (an 87580 now), the
  bedside lamp's tap sat half off its jumper, and the lighthouse's eight
  slopes were half off their bricks (seated; its two overlaps were two of
  them). A stud exactly on a part's edge reaches it only on its low side
  (cell rounding), so the lamp's fault showed at two of four turns; all 73
  section-free examples pass at every turn now.

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

- **Past 64 boxes a cover was its bounding box, holes and all.** `to_boxes`
  falls back to the bounding box when a cover will not reduce to 64 boxes,
  which over-reports and was thought safe. In a hole it refuses the one
  placement the hole is for: of 2,790 parts with a pin or axle hole a primitive
  declares, 2,104 had one filled solid that way, and none any other way —
  every Technic beam from 7 up (beam 5 is 54 boxes), every Technic brick from
  1 x 8, and 6222 and 18897, the 4x4 and 6x6 round bricks with holes (118 and
  330 boxes). The checker hid most of it, because a pin is forgiven against
  the part its `pin_hole` names (`Joints.pairs`), but 6222 has no such
  connector and was refused. Now a hole brings its own boxes
  (`occupancy.to_boxes(solid, connections)`, `HOLE_BOXES` 16 a hole), which
  keeps beams 7 to 15 (72 to 144 boxes), bricks 1 x 8 to 1 x 16 and 6222
  exact; past that the cover is the bounding box except on each hole's line,
  where it is the part's own cells (18897: 42 boxes). That carving stops at
  `CARVED_LIMIT` 2,048 boxes, past which four assembled parts (2518c01,
  2536c01, 42941, 52258p01c01) keep their plain bounding box. The largest
  cover in the library went from 64 boxes to 1,444 (42938, a curved car
  track); every geometry probe below still passes.

- **Some Technic holes are drawn without a peghole.** 6222's and 18897's side
  holes are plain cylinders turned inside out, so no `pin_hole` connector
  exists and `fill_cavities` never cleared them; where 6222's meets the tube
  inside the brick the voxeliser closed 48 of the 128 cells down its middle.
  `connectivity.rounds` finds them as bores, and `occupancy.holes` takes a bore
  as a hole when it is a pin's radius (6, within 0.5), all the way round
  (`Connection.arc`: a curved top's underside is half a bore), not along the
  stud axis, and not filled by the part's own shaft (a hinge complete with its
  pin). Along the stud axis a round hole is a tube or an anti-stud, where a
  *stud* goes, and `_studs_reaching_in` finds what a stud holds by plastic past
  its tip — cleared, a stud pushed into one would hold nothing. So 87081's
  centre pin hole, which is vertical, stays solid as a tube does. A drawn hole
  is cleared along its own length only,
  since 6222's opposite holes share a line through the tube in the middle.
  `tests/test_ldraw.py` (`test_a_round_brick_cover_leaves_its_side_holes_open`,
  `test_a_pin_in_any_hole_misses_the_cover`) holds both rules to the `.lbm` the
  build writes.

- **A bar in a loop was buried in the fill.** A handle is a bar held off a
  part at both ends, and in 2540's own layers the plate's edge, the two arms
  and the bar close a ring, so `fill_cavities` filled the gap a clip goes
  into. A clip on that bar was refused by hand and by check_design, unless it
  was held with its plate straight out from the handle: its open side then
  faces the plate and its jaw stays out of the loop. Now `occupancy.bars`
  takes every shaft a bar's size (4, within 0.5) across the stud axis, and
  where nothing but the bar, air and the fill is within `CLIP_REACH` (8: the
  thick clips are 7.6 round) of its axis along it, the fill there is taken
  back out (`_clip_rooms`). Only the fill's cells: plastic never goes. The
  plastic test is what keeps it to bars a clip can go on. Without it, every
  shaft within 1 of a bar's size had its fill taken, 2,467 parts and 1,423 of
  them minifig parts: the pin of a hip inside its legs, a pump's rod inside
  its cylinder. Upright bars are left alone. The fill never closes a loop
  round one (2921's handle was always open), and what it does close round an
  upright round is a brick's underside, where a 1 x 2's post is a bar's size.
  A bar with room brings its own boxes (`HOLE_BOXES` each), and past the limit
  each bar's room is carved out of the bounding box as a hole's line is:
  69934, a 10 x 16 plate with eight handles, was one box. Of the 4,318 parts
  with a sideways shaft of radius 3 to 5, 187 had a bar's loop filled
  (handles on plates, bricks, windscreens and dishes, rod frames, grilles,
  rigging, snowshoes) and 324 more had a bar buried in a bounding box; 511
  covers changed, each only losing cells. `PartForge` does not do this, as
  it does not do drawn holes; no element fixture moved (`pipeline.md`).
  `test_a_clip_on_a_handle_misses_the_cover` holds it for 2540, 60478, 48336,
  30236, 78257 and 69934: a 4085c on each handle, its plate out, up or down,
  shares no cell outside its bore, and 2 LDU toward the plate it still does.
  `technic_hand_probe` ("a clip on a plate's handle") does it by hand.

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
