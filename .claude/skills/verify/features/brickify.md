# Brickify

A 3D model — a sculpt, a scan, anything in OBJ, STL or glTF — laid in LEGO at the size the person picks, the way a builder would lay it, and placed as a sub-assembly.

<!-- covers: ui:brickify a 3d model, lib:brickify, lib:3d model files, cli:measure brickify against outside models -->

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
  keeps its edges.
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
  (`_stance`): on less than a tenth of its plan, within half a stud of
  tipping, or in pieces only the ground joins, it is given a stand
  (`grid.stand`, under its feet and centre of mass); `options.stand` false
  lays none. Then
  hollowed in whole courses behind walls two studs and three plates thick if
  asked — its surface colour sampled every 0.35 stud and matched to a current
  solid LEGO colour in Oklab (`Brickify.PALETTE`; not the mosaic's, whose
  trans-red took a red cube), and each stud's top marked a flat facet or a
  curve. Then laid by the assistant's own brickifier (`Shapes.lay`, solid kind
  `grid`): big bricks inside, slopes and curved slopes fitted where it falls
  away (straight on a facet, curved on a curve: surface `mixed`), inverted ones
  under an overhang, corner rounds and wedges where an edge runs off the square
  (the same edge parts as a design's shape; an edge part at a joint between
  pieces is laid again in plain parts so the stitch can join them — at 20
  studs the bunny's feet otherwise stood apart from its body and the prune
  kept the feet), tiles on top, studs-sideways
  panels on a flat side; every piece kept (`keep_pieces`: no prune, nothing
  left off unsaid), and every number laid the one LDraw gives the part today
  (`Shapes.current`, from the catalogue's stubs: 3023 is laid as 3023b). A stand
  is laid under it (`Brickify.lay_stand`: the model lifted two plates, strips
  along x under strips along z with their joints crossing, tiles where the
  model does not stand, black). Then `Assistant._check` as check_design runs
  it, weighed by Balance, and mended (`Brickify.mend`): join first (`_tie`, a
  1 x 2 plate under or over a joint, or the shortest pillar of 1 x 1s onto the
  rest's studs), and only a part that overlaps, or what nothing joins, taken
  out and said; weighed again, and given a stand after all if it would tip.
  The report: `coverage`, `lost` (regions of the model no part fills, a
  hundredth of it or more, each said where it is), `left_out`, `joined`,
  `tied`, `stand`, `balance`. `Brickify.said` puts it in words for the panel
  and the session: "buildable" only when it is one piece, passes, stands and
  no stud joint is past its load, with what it stands on, any stand and why,
  what was joined and what was left out. Nothing laid at a size is an error
  with the smallest size, half again a try, that lays it whole (`_keeps_at`).
- `brickify a 3d model` (`src/ui/brickify_dialog.gd`, `src/ui/mesh_file_picker.gd`):
  Ctrl-I (plain I is x-ray), Build > Brickify a 3D model…, or File > Import > 3D model to brickify. The
  file chooser (several files at once in a browser, for an `.mtl` or a `.bin`),
  then a panel: the model turning, its triangles, size in studs along its
  longest side or its scale in mm a unit (each moves the other), which way is
  up (STL defaults to Z), what it comes to in studs, bricks and centimetres,
  Hollow, A stand where it needs one (on by default), Surface (smooth, or plain
  bricks and plates), Colour (its own, one, or its own cut to at most N; a stand
  is black, or the one colour, or the darkest kept). Brickify works on a worker
  (the web's page keeps drawing); the status line is `Brickify.said` (one piece
  and standing, weighed, on what, joined, left out). Nothing laid sets the size
  to the smallest that lays it whole and says so. The result goes down beside what is built — in the middle of an
  empty baseplate — as one sub-assembly named after the file, one undo, and
  selected. The example car, untouched, is taken off first, and the model is
  then a new one called after the file ("bunny"), as it is on a bare, Untitled
  baseplate; it kept the car's name. `example_name_probe` (headless) brickifies
  the bunny over the car and reads the name.

A session does it with the `brickify` tool (`src/net/app_tools.gd`): `url=`
an http(s) link the app fetches (HTTPRequest, capped at `MeshFile.MAX_BYTES`;
an OBJ's .mtl and a .gltf's .bin from beside it; never `file://`, this
computer or its network), read by `BrickifyDialog.take` as a picked file is,
so the panel opens on it; `pick=true` opens the window's file dialog for the
person and says so (refused in a browser, which opens its chooser only from a
click); neither lays what the panel shows. The choices go through
`BrickifyDialog.choose`, so the panel shows what is laid, and laying is a job
(see mcp.md) on the panel's own Working bar. `app_tools_probe` covers it.

## How to reach it

```sh
godot --path .                     # then I, and choose a .obj/.stl/.gltf/.glb
godot --headless --path . --script src/dev/brickify_probe.gd [-- OUTDIR]   # OUTDIR gets brickify_*.ldr
godot --path . --resolution 1400x900 --script src/dev/brickify_ui_probe.gd
node tools/web/brickify_flow.mjs --url=<a preview>/app --out=shots/brickify_web   # with .env sourced and BW_BYPASS
```

`tests/fixtures/brickify/bunny.obj` is the bunny the probes make
(`BrickifySamples`, in code, CC0), written again by `brickify_probe.gd -- --fixtures`.

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
godot --path . --resolution 1400x900 --script src/dev/brickify_ui_probe.gd
#   I, the file dialog answered with the bunny, 32 typed into the size, Brickify
#   clicked: one sub-assembly "bunny" holding every part, all selected, the
#   status line saying "buildable in one piece", one undo takes it all and redo
#   puts it back; then a hollow sphere STL from the Build menu's command lands
#   beside it. shots/brickify_dialog.png and shots/brickify_placed.png.
```

In a browser: `tools/web/brickify_flow.mjs` presses Ctrl-I, answers the page's file
chooser with the bunny, types 30 into the size, presses Brickify, and reads
`window.brickworksState.tree` for `bunny#1` holding every part on the baseplate
(a first visit's example car is taken off to make room), `selected`, and
`brickified`, the status line's sentence: buildable in one piece, no part
missing. Pictures in its `--out`. Baseline 2026-10-12 on a preview, Chromium on
SwiftShader at a load of 30 to 50: the panel 20 s after the file is chosen,
the bunny down a minute and a half after Brickify is pressed, 1,057 parts as on
the desktop.

## Measuring it against outside models

`docs/BRICKIFY.md` is the write-up and has the full recipe ("Repeat it").
`src/dev/brickify_bench.gd` lays each model of a jobs file three ways (smooth,
plain, and a greedy stack of whole bricks over the same measured grid), checks
and weighs each, and writes the parts' geometry and the model's into OUT;
`tools/bench/brickify_bench.py` prepares the models (PLY to OBJ, a picked
picture for a bare OBJ), runs legolization (GPL, its own venv, never imported)
at the same scale, and measures likeness (silhouette IoU from 14 views,
Chamfer, Hausdorff95, normal error), colour (CIEDE2000 and the palette's
floor), bond (seams bridged, weak points, 1x1s) and parts in a colour no
element comes in. The models are third-party data kept in a scratch folder,
never in the repository.

```sh
python3 tools/minitest.py tests/test_trademarks.py     # (static) the doc's words
S=<scratch>; heavy $S/venv/bin/python -I tools/bench/brickify_bench.py prepare --models $S/models --into $S/prepared
XDG_DATA_HOME=$PWD/.scratch-data heavy godot --headless --path . --script src/dev/brickify_bench.gd -- $S/prepared/jobs.json $S/run
heavy $S/venv/bin/python -I tools/bench/brickify_bench.py measure $S/run
python3 tools/bench/brickify_bench.py report $S/run
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
- **The interior is one colour.** Two cells in from the surface take its colour;
  further in, the colour most of the model is, so the hidden core is a few large
  bricks rather than a patchwork.
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
