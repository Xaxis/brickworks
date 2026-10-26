# Brickify

A 3D model — a sculpt, a scan, anything in OBJ, STL, glTF, PLY, 3MF, VOX or FBX — laid in LEGO at the size the person picks, the way a builder would lay it, and placed as a sub-assembly.

<!-- covers: ui:brickify a 3d model, lib:brickify, lib:3d model files, cli:measure brickify against outside models, lib:brickify steps, lib:brickify from a collection -->

## Sub-features

- `3d model files` (`src/parts/mesh_file.gd`): OBJ (vertex colours after the
  position, `vn`, `vt`, `usemtl` and an `.mtl`'s `Kd` and `map_Kd`), STL (binary
  by its own count, text otherwise; Z up), glTF and GLB through Godot's own
  `GLTFDocument` (material colour, texture, vertex colours). Read as bytes, never
  a path: a browser has none. Files a model names beside itself come in
  `extras` by name; a `.gltf` with its `.bin` is written to
  `user://brickify_import/` for the engine to read and removed at once. A file
  with no normals (STL) gets them worked out, smooth where faces meet under 30
  degrees and creased above, so a sphere reads as round and a chamfered cube
  keeps its edges. Since unit 9 (`docs/BRICKIFY.md` section 12): PLY, text and
  binary of either byte order, read by its header's own list of properties
  (vertex position, normal and colour as bytes or fractions; faces of any
  corner count, fanned; anything else stepped over by its size); 3MF, a zip
  unpacked from bytes by `StudioIo._entries`/`_unpack` (no `ZIPReader`: it
  wants a path), its build items and components placed (a mirrored one turned
  round), objects in other model files (`p:path`), colours from base
  materials, colour groups and texture groups, supports left out, Z up; VOX,
  MagicaVoxel's chunks with its default palette when the file has none, the
  scene's transforms (`nTRN`'s packed rotation byte) placing each model about
  its middle, hidden nodes and layers left out, the outside faces of the
  voxels as triangles, a voxel a unit cube, Z up (a file with no scene is its
  first model: the rest were animation frames); FBX through `FBXDocument`,
  named by `ClassDB` so a build without it still loads, vertex colours kept as
  sRGB (glTF's are turned from linear); USDZ refused with a reason. An OBJ
  chosen with exactly one picture and no material naming one takes it as its
  texture; on the desktop `MeshFilePicker.read_path` reads the one picture
  beside an OBJ that names no `.mtl`. Every count is checked against the bytes
  before it is believed: `MAX_BYTES` unpacked in all, `MOST_TRIANGLES` before
  any triangle is made, `MOST_VOXELS` and `MOST_VOXEL_BOX`.
- `brickify` (`src/assembly/brickify.gd`): the mesh measured on the stud and plate
  grid — a ray up every third of a stud, inside where more faces have been gone
  in by than come out of (two shells pushed into each other are one solid;
  faces wound the wrong way are read the other way; a scan left open
  underneath is closed from the ground, never up into the sky); then what is
  thinner than a stud or a plate (`_thin`): a cell the surface passes through
  (`_touched`, triangle against cell by separating axes) counts where nothing
  measured is in the 26 round it, the cells it passes through between such a
  part and the body join them, and a part one plate thick is made two, so a
  fox's legs, a spout or a wing claim their cells at the size chosen and a
  thick body comes out no fatter. Then join, don't drop (`_join`): each piece
  apart is joined to the rest by the cheapest way (`_reach`: through the
  model free, along its thin surface cheaply, through air a plate up or down
  2 and a stud across 5), a floating largest piece is stood on the ground by
  a pillar, a piece on the ground too far to join is kept for a stand, and
  only dust (a speck reachable only by its own pillar) or a piece too far is
  left out, in `grid.left_out` with where and why. Then whether it stands
  (`_stance`): on feet none bigger than three studs (`THIN_FOOT`), within
  half a stud of tipping, or in pieces only the ground joins, it is given a stand
  (`grid.stand`, under its feet and centre of mass); `options.stand` false
  lays none. Then
  hollowed in whole courses behind walls two studs and three plates thick if
  asked — its surface colour sampled every 0.35 stud, each sample voting for
  the cell whose face shows it (`_shown_at`: out along the surface's normal,
  the last of the model's cells before the air; a surface with more than 1.5
  studs of the model in front of it, `HIDDEN_STUDS`, or buried in another
  part of it, the model's inside a quarter stud before and behind it
  (`BURIED_STUDS`, `Grid.within`: a figure's head under its hair), votes for
  nothing, and a face wound the wrong way is read the other way), and
  matched to a current solid LEGO colour by CIEDE2000 (`Brickify.de2000`,
  `_nearest`; Oklab sent a 25% grey to Reddish Brown) among `Brickify.PALETTE`
  (not the mosaic's, whose trans-red took a red cube), and each stud's top
  marked a flat facet or a curve. Then laid by the assistant's own brickifier
  (`Shapes.lay`, solid kind `grid`): big bricks inside, slopes and curved
  slopes fitted where it falls away (straight on a facet, curved on a curve:
  surface `mixed`), each in the colour of the surface it stands for
  (`colour_shown`, `Plan._shown`: the top plate of the studs it covers, not
  the stud above it; a design's shape keeps the stud above), inverted ones
  under an overhang, corner rounds and wedges where an edge runs off the square
  (the same edge parts as a design's shape; an edge part at a joint between
  pieces is laid again in plain parts so the stitch can join them — at 20
  studs the bunny's feet otherwise stood apart from its body and the prune
  kept the feet), tiles on top, studs-sideways
  panels on a flat side; steep sides on their sides (`Options.snot`,
  Shapes' `cubes`): the model's surface summed by area and the way it faces
  into cubes two studs by five plates by two studs (`Brickify._cubes`,
  Lambrecht's), a cube steeper than about 65 degrees (`STEEP`) facing out along x or z,
  and cut again with its courses started 2, 4, 1 and 3 plates up
  (`CUBE_PHASES`, `Grid.cube_phases`, `Plan._phase`), each later cut tried only
  where no shell has any of the cube (`_cube_shelled`);
  the cubes facing one way at one depth one shell (`Plan._cube_shells`,
  `_cube_shell`), and a cube with the one past it at the same height facing
  out too, the two one shell two cubes deep (`CUBE_DEEP`, the shell's
  `"depth"`), each cube the side's outermost with the core three studs
  behind it (`CUBE_BACK`) and no cap or ledge a plate or two thick on it unless the
  cap runs on back over the core behind the cube, on the core there, laid as a design's
  curved side is (`lay_shell`, its up turned out) and held by bricks with side
  studs (30414, 11211, 87087) in the core's wall behind each cube's top row
  (`_anchored`; first tier only); its slopes fitted by distance to the side
  (`Grid.side`, rays along x and z at thirds of a stud), one on the core's
  face only where a side stud grips it; a cube its shell covers under
  `CUBE_KEEPS` given back to the core and the shell cut again; laid once (the
  trial kept where the core kept its side studs); a piece of the core of 16
  parts or fewer a shell cuts off joined to the rest first, a plate of it and
  one of the rest side by side laid again across, a brick beside it laid again
  as plates (`Plan.join_cut_off`, `Shapes.last["joined_cut_off"]`), and what
  that leaves taken out before the check (`Plan.cut_off`,
  `Shapes.last["cut_off"]`; what the cubes came to in `Shapes.last["cubes"]`;
  what the shells took, gave back and cut off in `Shapes.last["shelled"]`,
  `"given_back"`, `"cut_cells"`, `"shell_frames"`); a side-stud brick never
  plain to the stitch (`Plan._plain`); a stud joint past its working load
  left after the props, beside a shell, has the cubes about it and what it
  hangs from laid again upright in the build itself, as a wall is patched
  (`_past_load_by_shells`, `_upright_about`), and the build with fewer such
  joints kept;
  the rays across cast only through cubes facing that way; a build that
  leaves a region out laid again unbonded and by the flag with its sides
  upright, two lays at most as on `main`; one colour asked for keeps its
  slopes to colours they are sold in on every path (`sold_only`);
  each surface part fitted by distance (`fine`,
  `Grid.fine`, `Plan._fit_near`): every slope, curved and inverted slope in
  every turn and height that stands on the shape laid against the model's
  own surface at thirds of a stud (each part's surface read off its mesh,
  `Plan.SLOPES`/`INVERTED`' last column), the nearest kept or the longest
  within `Plan.LONGER` of it, only where nearer than the plates, only in a
  colour it is sold in; 65 degree slopes (60481a, 3678b) and the curved top
  1 x 3 x 2 (33243) laid this way only (a design's shapes keep `_fit` and
  the flag, `prefer`); a build that
  leaves a region of the model out laid again unbonded and by the flag
  (`Options.near` false), as `main` laid it, and the fuller kept;
  the core bonded as a builder bonds it (`bond`,
  `Plan.shows`, `Plan.shown_colour`, `Plan._bonded`, `Plan.merge`): only
  what shows of a brick is laid in its colour and what is hidden in any (a
  brick none of which shows in the model's main colour), so three plates of
  the body are a brick whatever colour the measuring gave the hidden ones
  (but in a thin part's columns, `plain_at`, as measured); each course's
  studs, fewest free beside them first, under the first brick that fits in
  one colour where it shows and is sold in it (`Plan._made`); a shape that is
  its own mirror keeps its strip and mirrored halves; and once stitched, two
  plain parts side by side that make a part we lay, and three plates of one
  footprint stacked, merged (a merge only joins, so never more pieces); a
  bonded build that leaves a region of the model out laid again by the colours
  measured (`Options.bond` false) and the one filling more kept, both times
  counted (the temple at 48 studs keeps its moon so, at twice the time);
  every piece kept (`keep_pieces`: no prune, nothing
  left off unsaid) and, once the grid's own stitch is spent (the plan mapped
  once a round for it, not once a piece tried; its first ways, kept
  unchecked, taken back to the plan at its fewest pieces once a round's
  pieces apart are ones seen before, or after `Plan.STALLED` rounds that
  leave no fewer, and checked with the rejoin's from then on: they once
  laid the same pair until all 96 rounds ran out), the plates and
  then the slopes about each joint laid again as plates crossing it, and
  last a plate across a colour's edge laying the fewest studs in the other
  colour (`_pair_across` with colours) (`rejoin`, each way kept only if it
  leaves fewer pieces; the parts it may lay again mapped once a round; the
  pieces counted in packed arrays, in the same order); the columns of
  thin cells laid plain (`plain_at`: no slope, wedge or top tile); and every
  number laid the one LDraw gives the part today
  (`Shapes.current`, from the catalogue's stubs: 3023 is laid as 3023b), in a
  colour it is made in: no slope sold in none of the palette's colours
  (`sold_in`, `Plan._sold`, by Rebrickable's elements: the inverted 2 x 2
  3660a has no element at all and the 3 x 1 4287a is in 7 of the palette's
  colours, so `Plan.INVERTED` lays the moulds sold now, 3660b and 4287c;
  `shapes_probe` checks each is sold in white, black, both greys, red and
  yellow), and any part with no
  element in its colour laid in the nearest colour by CIEDE2000 it has one
  in (`Brickify.made_colours`, after laying and again after the mend; one
  colour asked for is kept). A stand
  is laid under it (`Brickify.lay_stand`: the model lifted two plates, strips
  along x under strips along z with their joints crossing, tiles where the
  model does not stand, black). Then `Assistant._check` as check_design runs
  it, weighed by Balance once it passes in one piece (`weigh_whole`; a check
  that fails is not weighed, and a mend that ends failing weighs its last),
  without its advice (`advise` false; the faults are the same), the check
  again without dressing that gave way asked the same (`_without_dressing`,
  which dropped both, so the first check came back unweighed and the mend
  checked a third time),
  and mended (`Brickify.mend`, in few checks): what
  collides (the lattice, or the exact check's `colliding`) out in one round;
  then join (`_tie`, a 1 x 2 plate under or over a joint, or the shortest
  pillar of 1 x 1s onto anything held, each stud checked against the part's
  real cover; a round that joins nothing taken back), at most two rounds;
  then what is still apart, floating or unheld (the exact check's `unheld`,
  and its `come_away`: a part resting where nothing joins it, which this
  lattice joins to what it rests on; the forty-stud bunny upright had a 1 x 1
  brick so) taken out together and said, never the body. Weighed again: given a stand
  after all if it would tip or all but (`needs_help`), and a joint past its
  working load propped (`_prop`) if that leaves fewer: a pillar under the
  piece beyond the joint, near its centre of mass, onto the model
  (`_beyond`, `_prop_under`), else under the part beyond the joint; with
  sides turned, slivers of three parts or fewer at the core's top taken out
  before the check (`Plan.caps_apart`).
  The report: `coverage`, `lost` (regions of the model no part fills, a
  hundredth of it or more, each said where it is), `left_out`, `joined`,
  `tied`, `propped`, `stand`, `balance`. `Brickify.said` puts it in words for the panel
  and the session: "buildable" only when it is one piece, passes, stands and
  no stud joint is past its load, with what it stands on, any stand and why,
  what was joined and what was left out. Nothing laid at a size is an error
  with the smallest size, half again a try, that lays it whole (`_keeps_at`).
- `brickify a 3d model` (`src/ui/brickify_dialog.gd`, `src/ui/mesh_file_picker.gd`):
  Ctrl-I (plain I is x-ray), Build > Brickify a 3D model…, or File > Import > 3D model to brickify. The
  file chooser (several files at once in a browser, for an `.mtl` or a `.bin`;
  on the desktop in Downloads, then where the last came from: `OpenFrom`),
  then a panel: the model turning, its triangles, size in studs along its
  longest side or its scale in mm a unit (each moves the other), which way is
  up (STL defaults to Z), what it comes to in studs, bricks and centimetres,
  Hollow, A stand where it needs one (on by default), Surface (smooth, or plain
  bricks and plates), Colour (its own, one, or its own cut to at most N; a stand
  is black, or the one colour, or the darkest kept). Brickify works on a worker
  (the web's page keeps drawing), one model at a time: it waits for a design's
  sculpt being laid, and a sculpt for it (`Brickify.begin_laying`). Cancel, closing the panel, quitting, or the
  library having to add a part (a file opened meanwhile) tell the run to stop
  (`BrickifyDialog._stop`, `Brickify.Progress.stop`): it ends at its next step,
  between laying's steps too, and nothing is put down (`quit_probe`'s brickify
  run). The status line is `Brickify.said` (one piece
  and standing, weighed, on what, joined, left out). Nothing laid sets the size
  to the smallest that lays it whole and says so. The result goes down beside what is built — in the middle of an
  empty baseplate — as one sub-assembly named after the file, one undo, and
  selected. The example car, untouched, is taken off first, and the model is
  then a new one called after the file ("bunny"), as it is on a bare, Untitled
  baseplate; it kept the car's name. `example_name_probe` (headless) brickifies
  the bunny over the car and reads the name. Once it is down the panel stays
  up, in the bottom right corner (`BrickifyDialog._set_landed`; `covers` lets
  the model be turned and picked past it), saying its parts, its steps and
  what the collection gave, with Booklet, BrickLink, Rebrickable (and What do
  I need? when it was laid from the collection) and Done: the booklet and the
  lists of the build alone (`Main._outside_of`: every other brick skipped),
  through the app's own exporters (`Main._export_booklet` with a skip and the
  build's name, `Exports.shop_list(shop, skip)`), the need page
  `CollectionDialog.open("need")`. Escape or Done puts it away; choosing
  another file, or a session's brickify, makes it the choosing panel again.
- `brickify steps` (`src/assembly/brickify_steps.gd`, docs/BRICKIFY.md unit
  7): the build's own steps, worked out on the worker after it is laid
  (`BrickifyDialog.finish`) and put down as the file's "0 STEP" lines
  (`BrickWorld.Brick.step`, `world.unit_steps`), so the timeline, the booklet
  (`Instructions._authored_plan`) and a saved file follow them. A course a
  plate tall a step, bottom up, a course of fewer than 8 parts in with the
  next (`FEWEST`, at most 3 plates of them; the top's few with the course
  under them); each part in the first step at which something already there
  holds it by a stud (a stud of either part pushed into the other's
  underside, any way it points, never against an edge: `_reach`, a
  bottleneck path a bucket a step, so an inverted slope goes in with the
  ledge it hangs from), not by resting on a tile; the sideways parts held to one another and facing one way, four
  or more (`PANEL_FEWEST`; fewer go in where they stand), a panel (`<build> <side> panel N`, named after the build so no two
  builds' panels are copies of one definition), a sub-assembly inside the
  build built a layer out from the core a step and put on in the step the
  last core part it is held to goes in. Every step's partial build weighed by
  Balance (with the contacts read once, `Balance.measure(..., contacts)`, and
  the sideways studs as links): standing, no stud joint past its working
  load, nothing adrift; a step whose build would not stand goes in with the
  next. `Plan.said()` is the line the status bar ends with. One undo takes the
  build off with its panels' steps (`unitstep` entries in its group).
- `brickify from a collection` (`src/assembly/brickify_stock.gd`): Lay it from
  my collection (the panel's box, `owned` = the CollectionStore's
  `on_hand`; `collection=true` over MCP). After laying, each part drawn from
  what is on hand, what shows first: as it is (or its other moulding), then
  the same part in the nearest colour on hand (CIEDE2000; a part that shows
  only within `shown_most`, 16, about white against light bluish grey; inside
  any colour), then two smaller parts of its kind that make its footprint
  (`Collection._splits`), kept only while the check passes in one piece (the
  splits near what came apart taken back, three rounds, then all). What
  shows is a stud-and-plate grid of the parts' boxes flooded from outside
  (`BrickifyStock.shows`). `BrickifyStock.said` is the panel's line: drawn,
  how, the colour difference where it shows, and the shortfall by lots.

A session does it with the `brickify` tool (`src/net/app_tools.gd`): `file=`
a path on this computer (desktop only, `AppTools._brickify_file`: an .obj,
.stl, .gltf or .glb and nothing else, read with what it names beside it by
`MeshFilePicker.read_path` as the file dialog reads it; a path or a `file://`
given as `url=` is taken as `file=`), or `url=`
an http(s) link the app fetches (HTTPRequest, capped at `MeshFile.MAX_BYTES`;
an OBJ's .mtl and a .gltf's .bin from beside it; never this
computer or its network, and the refusal names `file=`), read by `BrickifyDialog.take` as a picked file is,
so the panel opens on it; `pick=true` opens the window's file dialog for the
person and says so (refused in a browser, which opens its chooser only from a
click); neither lays what the panel shows. The choices go through
`BrickifyDialog.choose`, so the panel shows what is laid, and laying is a job
(see mcp.md) on the panel's own Working bar. `collection=true` lays it from
the person's collection (refused, said, when they keep none). Its answer ends
with how to get its booklet (export_model format=instructions) and its lists
(format=bricklink, format=rebrickable), says when those would take in more
than the build, and that there is no price (BrickLink's price guide needs a
seller's keys). `app_tools_probe` covers it.

## How to reach it

```sh
godot --path .                     # then I, and choose a .obj/.stl/.gltf/.glb/.ply/.3mf/.vox/.fbx
godot --headless --path . --script src/dev/brickify_probe.gd [-- OUTDIR]   # OUTDIR gets brickify_*.ldr
godot --path . --resolution 1400x900 --script src/dev/brickify_ui_probe.gd
node tools/web/brickify_flow.mjs --url=<a preview>/app --out=shots/brickify_web   # with .env sourced and BW_BYPASS
tools/probe.sh mesh_formats_probe [--fixtures] [--bench=bench/data/brickify] [--real=DIR]
node tools/web/mesh_formats_flow.mjs --url=<a preview>/app --out=shots/mesh_formats_web
```

`tests/fixtures/brickify/bunny.obj` is the bunny the probes make
(`BrickifySamples`, in code, CC0), written again by `brickify_probe.gd -- --fixtures`.
`tests/fixtures/brickify/formats/` holds a file of each newer kind
(`MeshFormatSamples`, in code, CC0), written again by `mesh_formats_probe -- --fixtures`.

## How to check it

Static: the project parse check only.

Runtime:

```sh
godot --headless --path . --script src/dev/brickify_probe.gd
#   reads a binary and a text STL, a GLB, a .gltf with its .bin and an OBJ; then
#   a sphere, a chamfered cube and a bunny at 24 to 28 studs, each passing the
#   check in one piece with at least 97% of the model in a part; the sphere's
#   top curved and sloped (no stepped studs), the cube's chamfers straight
#   slopes in its material's red, the bunny white, Bright Pink and black; a
#   dome left open underneath a solid half of the sphere;
#   hollow under 75% of the plastic and no more parts; plain without a slope or
#   a tile; two colours, one colour; and a forty-stud bunny in under 20 s.
#   Baseline 2026-10-12 at a load of 50: 41 ok, sphere 1,524 parts in 1.9 s,
#   forty-stud bunny 1,963 parts in 4.5 s (measure 0.7, lay 1.7, check 2.1).
#   With edge parts measured against the shape (same day, load 50-70): 42 ok,
#   sphere 1,496 parts in 3.5 s, forty-stud bunny 2,011 in 7.5 s (lay 6.0):
#   the edge search is most of the lay now.
#   Then the whole model (fails on main 4138091, 7 FAIL): the fox
#   (tests/fixtures/brickify/fox.obj, CC0 model, CC BY 4.0 conversion; its legs
#   a third of a stud across) laid at 24 studs with each of its four legs there
#   from the foot up, 97% of it in a part and nothing left out, one piece and
#   standing (Balance); a body with a cube floating over it (BrickifySamples
#   .floating) with a part at the cube's middle, one piece; a post with a block
#   past its edge (BrickifySamples.overhang) given a stand and standing on it;
#   every number laid in the probe's builds the one LDraw gives the part today
#   (no 3023), and none of the 86 Brickify may lay a stub that turns it.
#   2026-10-15 after main 4138091 (its exact check costs every check more), at a
#   load of 30 to 50: all ok, forty-stud bunny 2,249 parts in 12.9 s (measure
#   0.8, lay 7.7, check 4.5; main 12.0 s).
#   Then colour that reads right (unit 2): CIEDE2000 against Sharma, Wu and
#   Dalal's test pair (2.0425); greys from black to white matched to Black, Dark
#   Bluish Grey, Light Bluish Grey and White, never a colour (Oklab sent a 25%
#   grey to Reddish Brown); every part of the 28-stud bunny in its own colours
#   has an element number (PartLibrary.element_for, by today's number).
#   2026-10-16 on the unit 2 branch, at a load of 10 to 60: 57 ok; hollow sphere
#   1,599 parts against the solid's 1,606; forty-stud bunny 2,069 parts in 17.2 s
#   (measure 1.2, lay 7.6, check 8.4: its mend takes 3 parts out and checks
#   twice, where main's passes at once). Main beside it in one job (brickify_phases): 15.8 s, the
#   branch 17.7 s; the lay 2.0 s faster, the second check 3 s slower.
#   Then unit 2b: every stitch ends before its 96 rounds run out (the first ways,
#   kept unchecked, once laid the same pair until they did); the fox laid plain is
#   whole too (it lost 21 parts); two plates of two colours side by side are joined
#   by a plate across the edge, each side keeping its colour but a stud; the hollow
#   sphere is less plastic with nothing taken out and at most a tenth more parts
#   (it met "no more parts" once only by its mend taking 45 out). 2026-10-16 on the
#   unit 2b branch at a load of 15 to 45: 60 ok; hollow sphere 1,670 parts against
#   the solid's 1,606; forty-stud bunny 2,062 parts, one check, 12.0 s (median of six)
#   against main's 14.6 in one job (brickify_phases), 0.82 times.
#   Then unit 3, "bonded as a builder bonds": a block red only where nothing shows
#   laid as two courses of white bricks (4 parts; by the colours measured, 15); three
#   plates of one footprint merged into a brick and two side by side into one plate;
#   the forty-stud bunny's hidden core bricks, plates at most half as many (on main
#   a1d1998 203 bricks and 159 plates; the branch 280 and 118); and the sphere, the
#   plain sphere and the forty-stud bunny in fewer parts and 1 x 1s than main's, seams
#   bridged and weak points within two points of main's, measured as the bench
#   measures them (_bond). 2026-10-17 on the unit 3 branch: 66 ok; sphere 1,548 parts
#   (main 1,606), plain 1,218 (1,266), forty-stud bunny 2,027 (2,062) in 9.7 s.
#   Then unit 5, "steep sides on their sides" (docs/BRICKIFY.md section 10): the sphere
#   and the forty-stud bunny against themselves laid upright (Options.snot false; unit
#   3's bond checks now run on those): 100 more parts on their sides or more, at most 25%
#   and 15% more parts, 97% in a part; a block turned 30 degrees about its up, its sides
#   on their sides with slopes facing out; the 65 degree ledge laid upright. 2026-10-17
#   on the unit 5 branch: 84 ok; sphere 416 on their sides (44), 1,948 parts (1,589);
#   forty-stud bunny 286 (53), 2,146 (1,943); turned block 357 (81). 2026-10-21, the
#   fourth round (cubes at every phase, caps held by the core): 84 ok; sphere 386 on
#   their sides (44), 1,832 parts (1,589, +15.3% of 25%); forty-stud bunny 420 (53),
#   2,205 (1,943, +13.5% of 15%): near its bound, so a change that turns more must
#   weigh the parts it costs. 2026-10-21, the fifth round (shells two cubes deep): the
#   bound is now the bench's bar, 1.15 times m137's parts (sphere 1,948, bunny 2,143,
#   laid on m137 the same night); sphere 499 on their sides, 1,986 parts (+25.0%),
#   bunny 445, 2,250 (+15.8%, 1.05 times m137's), each 98.6% or more in a part; 83 of
#   84: the blue bunny at 20 studs 96.6% in a part, 4 mended (m137 98.7%). Cubes facing
#   out from 60 degrees fail the bunny at 28 studs (96.4%), and so do the bands
#   between phases (95.5%): the check that holds what a shell leaves out.
XDG_DATA_HOME=<scratch> godot --headless --path . --script src/dev/brickify_buy_probe.gd \
    [-- --models=FILE@STUDS@UP,... --out=DIR]
#   unit 7, buy it or build it from what you own (docs/BRICKIFY.md section 11): the
#   bunny and the fox fixtures at 24 studs (or the models named), each laid, its steps
#   worked out (every step's partial build standing by Balance, none held by nothing),
#   put down by the panel's own _put_down beside a brick of somebody else's, the
#   booklet's plan read back (its steps the build's own, a callout a panel, the other
#   brick after them), each step's highest foot no lower than the last's, every
#   step's build (about twelve of them, evenly spread) checked by the design check in the
#   booklet's order (passing, nothing floating, standing; in pieces only each on the ground, as feet before the body joins them), and the BrickLink and
#   Rebrickable lists of it alone written (Exports.shop_list with a skip) and their
#   pieces counted. Then laid from a collection of set 10698's 790 parts
#   (SetInventories, never the person's): drawn, how, never more than on hand, the
#   shortfall, the colour cost against the build laid without it, still one piece;
#   and again taking any colour where it shows. "none held by nothing" caught unit 5's
#   fourth round: four parts of the bunny's shells left resting on its core, held by
#   no stud, until a shell was pruned again after parts were taken out of it
#   (BrickifySteps.Plan.unheld_at names them). --out writes NAME_STUDS.ldr with its
#   steps and buy.json. Broken on purpose (each part at its own course, or no step put
#   in with the next) it fails: 352 held by nothing and the first step in 8 pieces;
#   the fox's steps 8 and 9 with 3 stud joints overloaded. Its lists and files go to
#   user://sessions/probe/brickify_buy (run it with XDG_DATA_HOME of its own).
#   2026-10-17 on the unit 7 branch at a load of 35 to 65: all ok; the fixture bunny 44
#   steps, every partial build standing; the bench's Stanford bunny at 48 studs 5,959
#   parts in 104 steps (10 courses in with the next), 87 panels, the steps 13 s of a 46 s
#   build; --steps-only over the 14 at 24 and 48 studs, every partial build of the 28
#   standing; from 10698, the grey Stanford bunny at 24 draws 15.8% at 0.18 ΔE2000 where
#   it shows (any colour: 26.9% at 5.7).
godot --headless --path . --script src/dev/brickify_phases.gd -- 3 [FILE:STUDS:UP ...]
#   where the time goes: the forty-stud bunny laid three times, and any model
#   named, each with its phases (measure.*, lay.*, lay.stitch.*, check.*), and
#   what one check costs alone and weighed. Run main's beside the branch's in
#   one heavy job: on a shared box only the ratio means anything.
XDG_DATA_HOME=<scratch> godot --headless --path . --script src/dev/snot_gaps.gd -- bunny:20:one bunny:28 [FILE:STUDS:UP ...]
#   unit 5's sixth round (docs/BRICKIFY.md section 10): which of a model no part fills with
#   its sides turned that the build with them upright fills, laid step by step, by why (cut
#   off beside a shell and where against it, a shell's plate no part fills, the mend, both
#   miss it), before and after the mend. GAPS_AT=x,j,z draws the cells round one, GAPS_WHY=1
#   says why the cubes there stayed upright, GAPS_BUILD=1 lays it with Brickify.build too.
#   2026-10-21 on the fifth round's code, the blue bunny at 20 studs: 70 cells of 2,072 lost
#   against upright's 10, 43 of them cut off before the stitch. On snot85: 46 lost.
godot --path . --resolution 1400x900 --script src/dev/brickify_ui_probe.gd
#   I, the file dialog answered with the bunny, 32 typed into the size, Brickify
#   clicked: one sub-assembly "bunny" holding every part (its side panels inside it),
#   all selected, the status line saying "buildable in one piece"; the panel stays up
#   in the corner saying its steps, BrickLink and Rebrickable pressed and their files
#   read (every piece wanted), Booklet pressed and its pages' steps counted, Done puts
#   it away; one undo takes it all, its panels' steps too, and redo puts it back; then
#   a hollow sphere STL from the Build menu's command lands beside it.
#   shots/brickify_dialog.png, shots/brickify_landed.png and shots/brickify_placed.png.
#   With XDG_DATA_HOME of its own: its lists and booklet go to
#   user://sessions/probe/brickify_ui.
tools/probe.sh mesh_formats_probe
#   headless. The fixtures in tests/fixtures/brickify/formats/ are what
#   MeshFormatSamples writes (the 3MF member for member: a zip carries its
#   time); each is read back as it was made: text PLY the bunny within
#   0.00001 and half a byte of colour, binary little-endian exactly, the
#   big-endian prism's 6- and 4-cornered faces fanned into 20 triangles, 8 red
#   and 12 blue, facing out; the 3MF's 46 triangles (support left out), a
#   mirrored cube facing out, a second file's cube, a triangle coloured a
#   corner at a time, a square on its picture's halves; the VOX scene's 300
#   triangles, one model moved and one turned, the hidden third left out;
#   MagicaVoxel's own palette; the FBX's 1,716 bunny triangles found where its
#   node puts them at 0.01 a unit, colours within 0.01, the cube in its red;
#   an OBJ with one picture and no .mtl textured, with two not guessed, and
#   the desktop reading the one picture beside it. Then 26 bad files refused,
#   each saying why, under a second (cut short, counts past the bytes, a zip
#   stating 4 GB or unpacking past its size, 64 MB of nothing, components in
#   a loop or 1.2 billion triangles deep, a scene holding itself, voxels a
#   million apart, USDZ); six fixtures laid at 24 studs, one piece; at 12
#   studs a voxel of scene.vox is a stud (12 x 4 studs, 20 plates).
#   2026-10-20 at a load of 10 to 30: 54 ok in about 90 s (the picker
#   refusing a USDZ and a .txt as MeshFile does among them).
#   --bench=bench/data/brickify (a checkout's, git-ignored): the Stanford
#   bunny and Armadillo PLYs and Spot (OBJ and PNG, no .mtl) as they came,
#   against bench/data/brickify/prepared's converted copies: the same cells
#   in the same colours at 24 and 48 studs and the same parts at 24 (bunny
#   6,943 and 55,137 cells, 1,183 parts; Armadillo 2,409 and 18,991, 692,
#   read in 2.9 s; Spot 4,829 and 39,166, 998 in 7 colours). About 3 more
#   minutes. --real=DIR reads and lays every .3mf/.vox/.ply/.fbx in DIR:
#   docs/BRICKIFY.md section 12 has the ten measured and where they are from.
```

In a browser, every kind of file: `tools/web/mesh_formats_flow.mjs` presses
Control+I eight times, answering the chooser with each fixture in
`tests/fixtures/brickify/formats/` (the OBJ and its PNG together), and waits
for the panel to come up holding it (`window.brickworksState.brickify_read`:
name, triangles, coloured, pictures, up), with the desktop's triangles and in
colour, then presses Cancel; an FBX refused passes only as "this build cannot
read". Wired into `tools/release/preview_checks.sh` as `mesh_formats`.
2026-10-20 on a local export of the branch (`--export-release Web` after
`tools/web_pack.py`, which a worktree needs for `assets/web/`; `serve.py` on
a port of its own), Chromium on SwiftShader: 17 of 17, each file in the panel
a second or two after it is chosen, the FBX read too.

In a browser: `tools/web/brickify_flow.mjs` presses Ctrl-I, answers the page's file
chooser with the bunny, types 30 into the size, presses Brickify, and reads
`window.brickworksState.tree` for `bunny#1` holding every part on the baseplate
(its own and its side panels', `bunny#1/bunny left panel 1#1`; a first visit's
example car is taken off to make room), `selected`, and `brickified`, the status
line's sentence: buildable in one piece, no part missing, its steps by courses.
Then, from the panel that stays up, BrickLink and Rebrickable pressed (each
download's pieces counted against the build's) and Booklet (its tab read for
pages of steps holding at least the build's own steps, two of them
photographed, `5_booklet_steps_N.png`); `--after=no` leaves those out. On a local
export (`tools/export.sh web`, `serve.py build/web PORT --parts assets/generated/parts
--delay 0`, the flow's `--url=http://127.0.0.1:PORT/index.html`), 2026-10-17 at a load of
40 to 50: all ok, the bunny at 30 studs 1,224 parts in 51 steps with 11 panels, both
lists 1,224 pieces, the booklet's tab filled in 740 s (its pictures drawn in software). Pictures in its `--out`. Baseline 2026-10-12 on a preview, Chromium on
SwiftShader at a load of 30 to 50: the panel 20 s after the file is chosen,
the bunny down a minute and a half after Brickify is pressed, 1,057 parts as on
the desktop. With `--model=tests/fixtures/brickify/fox.obj --studs=24 --least=60
--says=stand` it lays the fox, whose legs are thinner than a stud, and its line
must say it stands on a stand. Both are in `tools/release/preview_checks.sh`
as `brickify` and `brickify_fox`.

## Measuring it against outside models

`docs/BRICKIFY.md` is the write-up and has the full recipe ("Repeat it").
`src/dev/brickify_bench.gd` lays each model of a jobs file three ways (smooth,
plain, and a greedy stack of whole bricks over the same measured grid), checks
and weighs each, and writes the parts' geometry and the model's into OUT;
`tools/bench/brickify_bench.py` prepares the models (PLY to OBJ, a picked
picture for a bare OBJ), runs legolization (GPL, its own venv, never imported)
at the same scale, and measures likeness (silhouette IoU from 14 views,
Chamfer, Hausdorff95, normal error), colour (CIEDE2000 and the palette's
floor, and the share of the model's neutral surface, CIELAB chroma under 5,
laid in a strong colour, chroma 20 or more), bond (seams bridged, weak points,
1x1s) and parts in a colour no element comes in; each run's JSON has its
phases (`ms`). `pictures --before RUN0` draws each arm as RUN0 laid it beside
as RUN laid it (`--arms smooth` for one). The models are third-party data kept
in a scratch folder, never in the repository.

```sh
python3 tools/minitest.py tests/test_trademarks.py     # (static) the doc's words
S=<scratch>; heavy $S/venv/bin/python -I tools/bench/brickify_bench.py prepare --models $S/models --into $S/prepared
XDG_DATA_HOME=$PWD/.scratch-data heavy godot --headless --path . --script src/dev/brickify_bench.gd -- $S/prepared/jobs.json $S/run
heavy $S/venv/bin/python -I tools/bench/brickify_bench.py measure $S/run
python3 tools/bench/brickify_bench.py report $S/run
heavy $S/venv/bin/python -I tools/bench/brickify_bench.py faces $S/run   # where the error is, by facing
#   2026-10-17 after unit 5 (docs/BRICKIFY.md section 10), against d24d4d6: steep faces
#   ("out" in faces) 34.9° from 36.4° at 48 studs (the bar was 30% less), 30% of them now
#   nearest a part on its side at 29.0°; side views' Hausdorff95 ("sides") 0.86 from 0.84;
#   28 of 28 whole and one piece, the temple's moon kept; parts 8.1% more at 48. faces
#   splits the steep faces by the part nearest (out_on_side, out_upright).
#   2026-10-21, unit 5's fourth round (docs/BRICKIFY.md section 10): a job's "arms" may
#   name "upright" (smooth with Options.snot false, the studs-up build SNOT is measured
#   against); faces gives "turned", "turned_out" and "turned_down", the share of what
#   faces out or down whose nearest part has its top toward it (up within 60 degrees);
#   each smooth arm's JSON has "cubes_asked", "cubes_turned" and "cubes_why" (every
#   phase, by foot plate; why each was refused) and its joints past their load
#   ("balance"."over_joints"); pictures --views
#   corner,front,back,left,right,under draws each from every side and underneath.
#   2026-10-17 after unit 3 (docs/BRICKIFY.md section 8), against a1d1998: smooth at
#   48 studs 52,160 parts from 59,156 (2.42 times the greedy stack's from 2.74), 1x1s
#   35.1% from 37.8%, seams bridged 44.9% from 42.1%, weak points 27.2% from 25.9%;
#   whole 28 of 28 smooth and 27 plain, likeness and ΔE2000 unchanged; the temple at 48
#   laid twice (bonded, it lost its moon), about twice its time. `bond OUT` gives the
#   bond figures without ray casting; `pictures --cut` draws each build cut in half.
#   2026-10-16 after unit 2 (docs/BRICKIFY.md section 6), against 2789cd0: ΔE2000
#   on the 10 coloured models 1.28 times the floor at 48 studs (from 1.54), 1.54 at
#   24 (from 2.00); Spot's neutral surface laid in a colour 0% (from 40%), the
#   figure's 8% (from 72%); no part without an element (from 1.3%); smooth whole
#   24 of 28 (from 25), plain 25 (from 27).
#   2026-10-15 after unit 1 (docs/BRICKIFY.md section 5), on main 4138091: smooth
#   laid 28 of 28, whole 25 of 28, one piece 28, none tips (8 on a stand).
#   2026-10-15 on 7a55e86, 14 models at 24 and 48 studs: smooth laid 24 of 28,
#   whole (lost95 at most a stud) 13 of 28; the fox, the Kenney figure and the
#   Bell X-1 came out with no parts at 24 studs (legs and gear thinner than a
#   stud never reach the grid, the body floats, and the mend takes out every
#   floating part). legolization (outside) at 24: 9 of 14 in 30 minutes each.
```

## Gotchas

- **Shapes prunes from the foot.** Laid as the assistant's shapes are (prune,
  then stitch), a bunny standing on its feet kept its feet — the lowest parts —
  and lost the body, which met them only side by side: 473 parts became 28, and
  at 28 studs a model passed the check with an ear gone. Brickify asks for
  `stitch_first`, and the probe checks coverage, not only the check.
- **Wedges were most of the time.** Trying each of 72 wedges at every corner of
  every plate was six of a forty-stud sphere's eight seconds; `near_edges` tries
  only corners whose cut side lands on a stud the edge cuts across, and lays
  exactly the same parts (checked part for part on two spheres).
- **The stitch joins one piece a round.** Pairing every piece it could in one
  round halved the 48-stud scans' pairing time, but it changed which joins
  were made: the hollow sphere came out with more parts than the solid one
  (1,682 against 1,624) and the forty-stud bunny no faster. Taken out; the
  plan is mapped once a round instead, which by construction lays the same
  parts.
- **Colour is matched as the bench scores it.** By Oklab's straight line a
  25% grey is nearer Reddish Brown than Black, so a cow's black patches came
  out brown; CIEDE2000 (`Brickify.de2000`) keeps greys grey. A surface buried
  in another part of the model (a head under hair) colours nothing.
- **The interior is one colour where nothing shows.** Two cells in from the
  surface take its colour; further in, the colour most of the model is. Laid by
  those colours, a course was three plates wherever two met out of sight, so
  Shapes' `bond` lets only what shows of a brick decide its colour (`Plan.shows`)
  and lays a brick none of which shows in the main colour. A longer brick is
  laid or merged only in a colour it is sold in (`Plan._made`): a 1 x 8 in Bright
  Green was recoloured Green by `made_colours`, and an avocado's flesh changed.
- **Most of smooth's parts show.** At 48 studs, three quarters of them are the
  plate staircase under each stud's slope and the slopes and tiles themselves;
  refining the hidden core took the bench from 2.74 to 2.36 times the greedy
  stack's parts, and no core layout reaches 1.6.
- **A worker never loads a part.** Every part Shapes may lay
  (`Brickify.parts_needed()`, 80) is loaded — fetched, on the web — before the
  worker starts, and the tables filled on first use are filled first
  (`BrickifyDialog._warm`), as `Assistant._checked` does. A part not here yet
  is remembered as absent by those tables (`Shapes._parts`, the wedge tables),
  so `_warm` drops what they remember as absent and fills them again. The same
  bunny came out 1,057 parts in one browser and 1,004 in the next: 22 of its
  parts were queued behind the thumbnails the parts bin asks for, still there
  two minutes on. They are asked for as urgent (ahead of the queue) as soon as
  the panel opens, waited for up to two minutes, and the status line names any
  part that never came — which the flow fails on.
- **Hollow is less plastic, not fewer parts.** Measured on the 24-stud sphere:
  59% of the plastic in 1,517 parts against 1,524. Cut through a course, the
  hollow's floor and ceiling were plates and it came out a fifth more parts, so
  it is hollowed in whole courses.
