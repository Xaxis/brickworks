# Minifigures

Making a minifigure from real LDraw parts, slot by slot, standing it on a stud in
the model, and the design assistant doing the same with `add_minifig`.

<!-- covers: ui:minifig builder, lib:minifig assembly, lib:add a minifig, cli:measure minifig offsets, cli:minifig browser flow, lib:custom moulds, ui:mould maker, cli:figure prints and moulds in a browser -->

## Sub-features

- `minifig assembly` (`src/minifig/minifig.gd`, `class_name Minifig`): a figure is
  slot -> part and slot -> colour (headgear, headgear extra, head, neck, back, cape,
  torso, arms, hands, hips, skirt/tail, legs, feet, in right hand, in left hand);
  `assemble(library)` places every part in the figure's own frame
  (app axes, origin the middle of the top of the two studs it stands on, facing
  +Z). The offsets are LDraw's own, in LDraw's axes, turned into the app's at the
  end (a conjugation by `FLIP`, as `LdrModel` does it):
  - arms `(∓15.552, 9, 0)` turned 9.782° about Z — 3818.dat/3819.dat HELP and
    76382.dat (the library's torso with arms and hands);
  - hands `(∓23.69, 26.774, -9.898)` — 76382.dat, which is the arm's frame times
    45° about X;
  - head `(0, -24, 0)`; headgear at the head's own origin; hips `(0, 32, 0)`; legs
    `(0, 44, 0)` (3816c.dat "Move down 12 units to align with hips");
  - the current legs (3816c/3817c) stand 1.25 LDU behind their studs (3816c.dat
    "Move at z=1.25 relative to stud grid"), so the torso is at `(0, -72, 1.25)`
    over the studs; short legs (41879a, 16709) at `(0, -56, 0)`;
  - a neck accessory lifts the head by `MinifigData.NECK_LIFT`;
  - an accessory's bar (`MinifigData.GRIPS`) is laid along the hand's grip
    (3820.dat: centre `(0, -0.8229, -9.8948)`, 14.5° off the hand's Y). Anything as
    long as a figure is tall (100 LDU), or that would reach below its feet, is held
    the way real figures hold a spear: the arm raised to "lower arm horizontal"
    (3818.dat, -45° about X — 34 real figures) and the shaft slid through the hand
    until its end is a lattice cell off the ground. Stood on the ground, no
    further than the bar the hand is on (each grip's `[from, to]` in `GRIPS`): a
    spear's shaft goes to the ground, a greatsword's hilt stops at its guard and
    pommel, so the hand is not round a blade (59, 66964, 2674a/b were, and came
    apart) or off a handle (37178-f2's). Out of the floor (6246, 51645), as far
    as that takes.
  - what the standard joints do not fit sits where the library's own assemblies
    put it (`MinifigData.PLACES`/`HANDS`/`BODIES`): 30375cs0's battle droid,
    84638's hook on the left hand, 84637b's wooden leg, 15998's baby arms,
    37364's medium legs, the skeleton, the super battle droid, wing and flipper
    arms. Choosing an odd torso brings its companions (`choose` -> `body_of`:
    the droid's head, arms and legs and no hips or hands; a body moulded from
    its feet up — Sebulba, Gollum, the babies — stands on its own); and the
    other way round, where the library only ever attaches a part to another
    (`choose`): the droid's head, which has no socket for a neck post and
    clips onto its own torso's bar, brings the droid (`HEADS_ON`); printed
    legs their printed hips in the colour 73200bpXX gives them (`LEG_HIPS`:
    3816cpx0 with 3815bpx0, 3816cp30's hips reddish brown); springs 43741 the
    hips 43221 and legs 43220 they go into, and 43220 its springs, as
    43743-f1.dat (`LEGS_WITH`; legs joined in one moulding are one part); the
    prosthetic hand 5059 the stump arm 6828, on it where 6828.dat's HELP line
    says (`ON_ARMS`; on a plain arm it pointed back up it). Each is undone
    the same way: the plain legs give the plain hips back;
  - a head sits by its neck socket (`MinifigData.SEATS`, measured off its
    geometry: 24 under the origin for the classic heads, 0 for the moulded ones
    drawn from the neck up), or by its rim if it is drawn as a brick is,
    hollow round a tube for the post (the Minions at 40, 56 and 32, the
    pencil top at 32; by the tube they sank 20 LDU over the torso);
    headgear goes where the classic head's top is;
  - a visor turns on its helmet's dimples (`MinifigData.PIVOTS`: 2447b's pins at
    its origin onto 3842b's dimples at y 5; an unknown helmet gets the classic's);
    a plume or feathers at the head's origin, or where an assembly puts them
    (`EXTRAS`: 2544c01's plume, 6122c01's dragon);
  - neck, back and cape items at the torso's origin, a cape up its own collar
    (4524 at y -2, as nine real figures wear it), the quiver turned to the back
    (`TURNED`, as 19 real figures wear it); the head up by the highest collar;
    cloth LDraw draws flat, as it is sold (50231, 14295), is worn as its
    "(Formed)" drawing (`worn_as`: 50231 -> 50231c01), as every cloth cape on a
    figure in vendor/omr is (522, 50231c02, 99464c01) — one a figure can wear,
    no lower than its feet and not out in front (not 50231c03, a curtain, or
    u9661c01, drawn folded flat); cloth with none (tuxedo tails 26697, the
    short skirt 26701, u9661) hangs straight down against the back
    (`_hung_flat`); a cape longer than the figure is tall (a full one on a
    child) is raised until it clears the ground, never swung out at an angle;
    back gear reaching the floor swings back about the shoulders;
  - hipwear at the hips' joint; legs paired by name or print (3816cp30 with
    3817cp30, 20461bp00 with 20460bp00), one-piece legs (a mermaid's tail, a
    skirt moulded on) at the hips; feet one each side, the foot on the stud
    every footwear part has at its origin (a ski's binding and a snowshoe's
    rim reach higher, round the foot), the figure raised by what is under the
    sole, which stands on the plate;
  - a one-sided part (a hook, a robot arm, a wooden leg) keeps the plain part
    opposite in the colour it had (`colours["<slot>_other"]`).
  Every part in the catalogue's `Minifig*` categories or named `Minifig ...` is
  offered in some slot (`slot_for`: the catalogue's category where LDraw has one
  for the slot, LDraw's names for the rest; `offered`), or comes as the pair of
  one: 4263 parts, 4038 offered, 225 as pairs. Choices per slot (`Minifig.choices`)
  are real parts only — no redirect, alias, sticker or shortcut, so every part is
  an element on the parts list — plain moulds first, the classic figure's mould
  first of all (973, 3626c, 3816c); the Cape slot opens on the worn drawings of
  cloth capes, 50231c01 first (its cloth is in 258 sets), and in the cloth
  slots cloth drawn flat comes last. A worn drawing is its cloth's element on
  the parts list (`PartLibrary.element_for`: 50231c01 in black is 4124171, as
  50231 is) and comes in its cloth's colours (`colours_of`). `groups` sorts a slot by mould (body) or kind
  (worn or held) for browsing. A printed part's colours are its moulding's
  (`colours_of`: 3626cp01 -> 3626c, 973 -> 76382); a part chosen for a slot not
  made in its colour comes in its most-made one (`fitting_colour`). `surprise()`
  picks real parts in colours they come in, weighted by use, on a classic body.
  Kept figures live in `user://minifigs.json` (`Minifig.shelf_file`).
- `minifig data` (`src/minifig/minifig_data.gd`, generated by `tools/minifig.py
  data`): 649 grips (everything the hands are offered that has a bar, the
  bicycle and the pot too; a ribbed hilt or handle, rings of the bar with waists
  up to `RIB` 2 LDU between, is one bar, so 66964's and the bow's are found, but
  a length as long as a hand, `HAND_LENGTH` 11, is a handle of its own, so a
  lightsaber hilt's emitter rings stay off its grip; two grips the rule gets
  wrong are kept as they were, `KEPT_GRIPS`: 11107's hilt, not the bar holder on
  its blade, and 4522b's handle, not under its head), each with how far its bar
  runs either way of the grip, 115 neck lifts (what real figures do where any do, the collar off the
  geometry otherwise), 736 torso prints' arm and hand colours from the library's
  76382pXX assemblies, and what the library's own assemblies say about the odd
  parts: 40 placements, 19 arms' hands, 8 bodies, 6 headgear extras; 73 head
  seats, 43 visor and helmet pivots, 1 part worn turned; 138 legs' hips (from
  hips-and-legs assemblies, not whole figures), 3 legs in pieces, 1 hand on an
  arm of its own (from the arms' HELP lines, the plain hand left out), 1 head
  on a body of its own. GDScript constants because
  the web build has no LDraw library to read and the export takes no loose JSON.
  The script sorts parts into slots by a copy of `slot_for`'s rule, which
  `tests/test_minifig.py` holds to the app's word for word.
- `measure minifig offsets` (`tools/minifig.py`): `measure` reads the 517 figures in
  the 105 real sets of `vendor/omr` and says, joint by joint, how many agree with
  the numbers above; `grips` checks the grip rule on the 238 accessories real
  figures hold (158 on the bar the real hand holds, 80 within 3 LDU of the same
  place); `data` writes `minifig_data.gd` (about a minute).
- `minifig builder` (`src/ui/minifig_dialog.gd`): M or the Minifig button.
  Fifteen slots down the left with what is in each; the chosen slot's parts in
  the middle, searchable, a list of the slot's moulds or kinds beside the search
  (every head mould, every kind of thing to hold), a page of 160 with a "+160"
  cell for the next, drawn with their print (`ThumbTile` with `printed`, the rows in
  sight told to `PartThumbnails.watch` as the parts bin does — see
  [parts](parts.md) `previews`; a waiting cell is a placeholder with the part
  number under it, and the slots' pictures are tiles beside their words, so the
  words do not move when a picture lands),
  and the colours with a dot on the ones the part is made in (a worn cape's are
  its cloth's, which the note under them says); the figure turning
  on the right (its own `SubViewport` and `BrickWorld`; drag to turn), a name,
  Surprise me, Keep, Place in model, and the kept figures. Escape closes it.
- `placing` (`Builder.hold_figure` / `settle_figure` / `put_figure`): Place hands
  the figure to the builder, which holds it like a part — a ghost of every part,
  red where it would stand in something; R turns it; a click stands it on a pair
  of studs (it snaps like a 1 x 2 plate and rests on the highest surface under
  either foot). One undo takes it off. Its parts share a group named after it
  (`unused_group`: a second Guard is "Guard 2"). Shift-click picks out the whole
  figure, arrows move it, X lifts it whole and the next click puts it down facing
  as it faced, Q/E turn the model without moving its arms off its shoulders.
- `saving`: `ModelStore.figure_frames()` gives each figure group its frame and
  `LdrModel.write_ldr(..., frames)` writes it as a sub-model standing at its own
  origin (torso line `0 -72 1.25`), placed where it stands — the way real sets'
  files keep figures. Reopened, it is the same parts in the same group.
- `parts list and measures`: every part of a figure is its own lot with its element
  number (`Inventory` needed nothing). `Minifig.is_body_part` keeps a figure's body
  and what it wears out of `Assistant._variety` (and `texture.without_figures` out
  of `tools/texture.py`, which says how many it left out), as Rebrickable's set inventories
  keep them in each figure's own (12,423 heads in figure inventories, 2,851 in
  sets'; no sword, shield, bow or pickaxe in a figure's); what it holds counts.
  Piece size and the style measures already left all `Minifig*` categories out.
- `add a minifig` (`src/minifig/figure_tool.gd`, `FigureTool`): the assistant's
  `add_minifig` — name, x/z in studs (the first of its two studs), y optional,
  facing (+z, towards the front view, by default), and each slot as a part number
  or words matched against the slot's part names (every slot, the left hand
  and the new ones too; the torso first, so an odd body's companions can be
  replaced by what else was asked); `colors` by slot. Refused in the
  air, in something, or on another figure's head; refused for a part in the
  way, it names the parts by number and which of the figure's parts they
  meet, and says whether it stands without its headwear or the nearest spot
  within two studs where it does (`FigureTool._in_the_way`; walk180's captain
  took five looks to find the roof plate over his hat). `minifig_probe` checks
  a figure refused by a post names it and stands at the spot it offers. Its parts are the design's own
  (`_placed_ids`), so a new submission replaces them. Offered over MCP like every
  tool; `connector_form.said` captions it.
- `minifig browser flow` (`tools/web/minifig_flow.mjs`): the same in a real browser
  on SwiftShader, driven by the positions the app publishes
  (`window.brickworksControls`, which carries the builder's buttons and slots
  while it is open, and `minifig_choice`, the first part the grid offers) and the
  part count it publishes (`window.brickworksBricks`). It also chooses a cape —
  a part the pack does not ship, fetched over the wire — and places the caped
  figure.
- `prints on a figure` (the print designer and its files are in
  [prints](prints.md)): "Draw a print…" beside the search in the Head, Torso, Hips
  and Legs slots (`MinifigDialog.PRINTED`; the hips are drawn with the legs) opens
  the print designer over the builder on the slot's part — its plain mould; a
  printed part LEGO made is started from, one made here loaded to change. A
  right leg is printed with its hips and left leg as one front. Save print puts
  the parts on the figure; a part for no slot (a tile typed into "or print on")
  goes to the parts bin and the builder says so. On a figure (`Minifig`): a part
  made here stands where the part it was made from stands (`PartPrints.bases`;
  `assemble` and `torso_local` work with a stand-in and swap the made parts back,
  a printed pair's left leg for the plain left leg, `made_with`); choosing
  printed legs brings the hips printed with them and plain legs give plain hips
  back (`_fit_hips`); made parts are offered first in their slot, in a group "My
  prints and moulds" (`MADE_HERE`), in their original's colours (`colours_of`);
  the slot index is rebuilt when the library has made parts it did not.
- `custom moulds` (`src/minifig/mould.gd`, `Mould`): a part's shape sculpted
  into another with its connection exactly where it was. `of_part` welds the
  part's built mesh into one surface (positions on a 1/1000 LDU key, LDraw's
  winding), keeps its connectors and its creases; `dome` (a cap turned from a
  profile round the classic head with a hollow stud's socket, standing for 3901)
  and `club` (a 4 LDU bar and a ball, standing for 3847, the bar on 3847's
  grip) start from nothing. Each corner has a lock, 0 to 1 (`lock_at`): inside
  what a connector needs — a stud 7 LDU round and 4.5 out, a socket 7 round and
  4.5 in along its axis, a shaft or bore of radius 6 or less with 1.5 to spare,
  a pin or clip 5.5 round 6 either way, the grip a hand closes on (the part's
  `MinifigData.GRIPS` bar, 5.5 round, 9 either way) — and, on anything worn on
  the head, the inside turned to the head and within an LDU of it
  (`head_depth`, 3626c's cylinder, rounded top and stud; `head_outward`); fading
  to 0 over 2 LDU (`FADE`). Brushes (`dab`): pull and push along the brush's
  facing, inflate along each corner's own, smooth to the neighbours, pinch to the
  middle, flatten to the plane, each weighted by a smoothstep falloff and the
  corner's freedom; with symmetry the same dab mirrored in X. `grab` and `drag`
  move what is under the brush with the pointer; the lattice (`lattice_begin`,
  `lattice_move`) is 27 handles round the part bending it by quadratic Bernstein
  weights, the mirrored handle moved with symmetry. After every change nothing
  free is nearer the head than `HEAD_MARGIN` (1 LDU) or than it began
  (`_keep_off_head`). `refine` splits every edge longer than 3.2 LDU (1.6 with
  Finer) not locked at both ends through its middle, the shape unchanged, up to
  `MOST_TRIANGLES` (9000). `walls` measures each corner's thickness straight in
  (`Rays.Grid`) and the share under 1 mm. Picking is `Rays.nearest`. The file
  (`text`) is the triangles on the mesh's 64ths of an LDU, the original's
  connectors as `0 !BRICKWORKS CONNECTOR` lines, its creases, and `0 // Moulded
  by Brickworks: from=<part>`; named `bw-<part>-m<tag>` from an MD5 of its
  corners, built by `PartForge` (`CustomParts.add`), filed under Custom. On a
  figure it stands where its original stands (`PartPrints.bases`).
- `mould maker` (`src/minifig/mould_editor.gd`, `MouldEditor`): "Make a mould…"
  beside the search in the Headgear, Headgear extra, Neck, Back, In right hand and
  In left hand slots (`MinifigDialog.MOULDED`), opened on the slot's part (3901
  or 3847 when it is empty, a dome when neither). Start from a part number,
  Dome or Club; tools Pull, Push, Inflate, Smooth, Pinch, Flatten, Grab; Size
  (LDU) and Strength; Symmetry (on); Lattice (handles drawn over the part, a
  handle dragged in the view's plane); Check walls (red under 1 mm, the thinnest
  said); Finer; Undo and Redo (Ctrl+Z). Drag on the part to sculpt, off it or
  with the right button to turn it, the wheel to come closer; a ring shows the
  brush; locked corners are tinted blue and a faint head shows the fit. Save mould
  builds it ("Building the mould…" said first) and puts it on the figure.

## How to reach it

```sh
godot --path .                     # M, or Minifig in the top bar
tools/minifig.py measure           # the offsets against 517 real figures (~30 s)
tools/minifig.py grips             # the grip rule against 238 held accessories
tools/minifig.py data              # rewrite src/minifig/minifig_data.gd (~2 min)
```

On the web the builder's parts come over the wire like any other; the default
figure's are in the pack (`tools/web_pack.py` ESSENTIAL).

Prints: M, a Head, Torso, Hips or Legs slot, **Draw a print…**. Moulds: M, a
Headgear, Neck, Back or hand slot, **Make a mould…**.

## How to check it

```sh
godot --headless --path . --script src/dev/minifig_probe.gd
godot --path . --resolution 1400x900 --script src/dev/minifig_ui_probe.gd   # needs a display: see tools/check.sh for xvfb-run
python3 tools/minitest.py tests/test_minifig.py
node tools/web/minifig_flow.mjs --url=<a build>/app --out=shots/minifig_web
godot --path . --resolution 1400x900 --script src/dev/print_ui_probe.gd     # needs a display
godot --headless --path . --script src/dev/mould_probe.gd
godot --path . --resolution 1400x900 --script src/dev/mould_ui_probe.gd     # needs a display
BW_BYPASS=$VERCEL_BYPASS node tools/web/print_flow.mjs --url=<a preview>/app --out=shots/print_web    # .env sourced
```

Proves it when:

- `minifig_probe` ends `every figure sat where real sets put its parts, stood,
  saved and counted`. Its first section compares each joint to real figures read
  out of `vendor/omr` with the app's own reader: 10218's within 0.02 LDU (the
  library's numbers), 10184's hands within 0.5 (its modeller's), 10176's short
  legs and helmet, 6973's airtanks and lifted head, 6285's cutlass 0.5 LDU from
  the real grip, 6059's raised arm and upright spear, and the legs over the studs
  where 3816c.dat's HELP line says. Then a figure on a 1 x 2 plate (each leg's hole
  on a stud, `Stability` says it stands), undo, selection, arrows, Q/E, X, a
  second of the same name, save -> reopen -> save byte-identical, the parts list,
  `_variety` unchanged by a dozen figures, and `add_minifig` (placed, on top of a
  brick, in the colour asked, refused in the air and where somebody stands).
  Cloth: the Cape slot opens on 50231c01 with its 20 worn drawings first and
  flat cloth last; 23 flat cloths worn as their worn drawings and 7 with none
  hanging straight down against the back, clear of the ground; none of 94
  capes held out at an angle on a grown figure or a child; 50231c01 is
  50231's element in its colours.
  The new slots against real figures: 6067's cape at y -2 (0.01), 6061's quiver
  turned to the back (0.01), 10176's soldiers' shields in the left hand (on the
  real hand's bar, within 3 LDU along it, as the right hand's grip rule is), the
  classic visor on the classic helmet's dimples and 1.5 LDU from 6208's B-wing
  pilot (the two drawings of the helmet differ by that). Against the library's
  own assemblies, part for part within 0.01: 30375cs0's battle droid (and the
  plain torso giving the plain parts back), 84638's hook, 84637b's wooden leg,
  15998's baby, 37364's medium legs. And the other way round, against the
  library too: the droid's head bringing the droid of 30375cs0 (fails on the
  old builder, which put it on the plain torso); Minion heads and the pencil
  top resting on the shoulders by their rim (they sank 20 and 29); 3816cpx0
  bringing 3815bpx0 as 73200bpx0, 3816cp30 reddish brown hips, the plain legs
  the plain hips back; springs 43741-f1 in 43221 over 43220 as 43743-f1, and
  43220 one part with its springs (it was two, the springs stood alone); the
  prosthetic hand on the stump as 6828.dat's HELP line says (0.001 off), the
  plain hand the plain arm back. Then: all 4263 minifig parts available
  (fails on the old builder, which offered 3284 and had no slot for 979);
  each slot opens on the classic mould; 1966 families each put together with
  nothing in the floor; 176 families of legs, feet, bodies, skirts, capes and
  back gear stood on a 6 x 6 plate with none refused by the lattice; a frogman
  with a visor, airtanks, a cape, a skirt, flippers, a spear and a shield
  stood on a plate on his flippers, their undersides on its top, lifted with
  X and put back, saved and reopened as one figure. On footwear: on each of 12
  kinds the feet are on its top and its sole on the plate (the snowshoes had
  the feet 2 LDU up, the hinged ski 9; flippers and skis stood 1 LDU above the
  plate), and the lattice takes a flipper on a plate, its origin 3 LDU up,
  but not 1 LDU into it. One piece, as the design checker reads it: each of
  15424 hands on a figure of every family of every slot, stood at four places
  (the origin, where run 4's Orthanc stood Saruman, half a stud over and a
  plate up, a quarter turn where run 5's stands him), is one piece with its
  arm alone; the figures of every kind of hand are each one piece; Saruman cut
  out of run 5's Orthanc with his staff raised
  (`src/dev/fixtures/saruman_on_orthanc.ldr`) is one piece; a hand two studs
  out from its arm is a piece of its own. Read at the nearest square turn, as
  the checker read a figure's parts before `Assistant._joined_at`, some 3700 of
  the hands came apart and Saruman was 3 pieces (run 5's whole Orthanc too:
  `candidate_probe` said 3 pieces, and says 1 now). 5059 on the stump 6828 is
  among the pairs: its hole is drawn in raw quads the connectors cannot read,
  and the stump's peg is found in it by 5059's cover all round it
  (`Joints.pushed_in`). No hand is hung on an arm with no socket for one
  (`NO_SOCKET`: 57588, 92754, 12613; `Minifig._has_socket`, which asks the
  arm's and hand's own connectors at the standard joint). Whole figures of
  every family of visors (on the helmet an assembly puts them on, or 3842b),
  capes, arms, hands, legs and both hands' held things, at the origin and a
  quarter turn on Orthanc, are each one piece: visors by their pivots, cloth
  capes round the neck post, droid and skeleton arms by the plastic in the
  torso's shoulder socket, everything held by being in the grip. The four
  swords as long as a figure (59, 66964, 2674a, 2674b) and the suitcase with its
  long handle out (37178-f2) are held on their hilt's or handle's bar
  (`BY_THE_HILT`: the hand's grip between the bar's ends, the figure one piece at
  the origin and a quarter turn; the old builder slid them through the hand by
  the blade). Still in pieces, and named (`STILL_APART`): two strings, which
  have no bar and fill no cell the grip could find (56823 none at all, 71149
  only its end studs, 16 LDU across), and the bent spring 43741-f2 turned a
  quarter (its top is never read in the hips' hole, and its foot's cells miss
  the legs' hole's middle). A
  sword two studs out of the hand, a cape two studs off the neck and a visor
  two studs off its pivots are pieces of their own. And the page's Orthanc,
  10,094 parts, is one piece: its wizards' beards are clamped on their necks
  under their heads (`ExactCheck.clamped`), though BrickNet's graph joins no
  beard worn so (docs/BRICKBENCH.md).
- `minifig_ui_probe` ends `a figure was made by clicking, named, placed on a stud
  and photographed`, and leaves `shots/minifig_builder.png`,
  `minifig_builder_surprise.png`, `minifig_figures_front.png`,
  `minifig_figures_corner.png`, `minifig_close.png`, and
  `minifig_new_slots_front.png`, `_back.png` and `_corner.png`: a spaceman with
  his visor down, a knight with a visor, cape, spear and shield, a princess in a
  moulded skirt with a tiara and a cloth cape, a frogman on flippers, a battle
  droid, a captain with a hook and a wooden leg, a mermaid, a skeleton with a
  quiver on its back. On the way it chooses a shield for the left hand and a cape
  by clicking (50231c01, its colours 50231's), pages through the torsos with the "+160" cell and shows one mould
  of them. **Look at them**: head on the neck, arms at the shoulders, hands in
  the arms, legs under the hips, the spear upright in a raised hand, the cutlass
  blade up and forward, visors over faces, capes and quivers behind. Plain
  `godot` draws them with the Compatibility renderer, the web build's; under
  `gpu env GODOT_GPU=1 ...` with Forward+.
- `minifig_flow.mjs` ends `minifig flow: made, placed and photographed`, with the
  part count up by the figure's parts, then the Cape slot found, its first part
  (50231c01, the cloth cape as it is worn) chosen and a caped figure placed too
  (up by 8 or more; `4_cape.png` shows the grid of capes and the figure wearing
  one, `5_caped.png` it standing beside the first and `5_caped_close.png` close
  up, to see the cape hang). A local export works as the hosted one does with
  `PARTS_URL=http://127.0.0.1:PORT/parts/ tools/export.sh web`, then
  `python3 tools/web/serve.py build/web PORT --parts assets/generated/parts
  --delay 300`, which answers `/api/account` with its own `/parts/`; the flow's
  `--url` is `http://127.0.0.1:PORT/index.html`.

- `print_ui_probe` ends `a face, a jacket and trousers were drawn by hand, worn and
  placed`, every mark an input event: the face drawn on a clean sheet (the editor
  first opened on 3626cp01's grin), hair round the back, a jacket front with a
  collar, pockets, a zip and a badge with "BW", "CREW" on the back, trousers with a
  belt and patches, a sign on a 3068b tile; saved, worn, the figure placed (10
  parts, 5 printed here) and the tile put down beside it. **Look at**
  `shots/print_face_editor.png`, `print_torso_editor.png`, `print_legs_editor.png`,
  `print_tile_editor.png`, `print_builder.png`, `print_figure_front.png` (face the
  right way up, badge on his left breast, belt over the hips),
  `print_figure_back.png` ("CREW" reads from behind) and `print_with_tile.png`.

- `mould_probe` ends `a mould sculpted here keeps its connection exactly, and
  stands, saves and travels`: 3901 welded (695 triangles), its inside resting on
  the head locked and its outside free, every corner round the head's stud
  locked, none of it in the head by more than a drawing's 0.3 LDU; made finer
  with every corner where it was; pulled (corners moved up to several LDU), the
  other side coming too with symmetry; every brush at full strength, the lattice
  and a grab leaving not one locked corner moved by any amount and nothing free
  pushed nearer the head than an LDU; its walls measured; undo and redo. Made
  into `bw-3901-m…`: its connectors 3901's to the float, its file under 700 kB,
  built with a cover, offered as headgear. A dome (clear of the head, its socket
  locked) with a topknot pulled up, and a club (its bar locked, a 4 LDU round,
  the 3.18 mm a hand holds) with a swollen head, both made. A figure wearing the
  hair and holding the club stands exactly as one with 3901 and 3847, is placed
  on a 1 x 2 plate and stands; the file carries both into a library that never
  saw them, the same to the cell.
- `mould_ui_probe` ends `a hairstyle and a club were sculpted by hand, worn, held
  and placed`: in the Headgear slot, "Make a mould…" opens on 3901 made finer;
  turned with the right button; the fringe grabbed and swept up and forward from
  the side, the back drawn down, the sides inflated, the crown smoothed, the
  lattice's top handle lifted — every stroke a press, a drag and a release on the
  view — not one locked corner moved; Check walls says how thin it is; saved as
  "Quiff" and worn, first in the grid; a club from Club, its ball inflated and
  pulled into spikes, saved into the right hand; the figure placed. **Look at**
  `shots/mould_hair_start.png`, `mould_hair_sculpted.png`, `mould_hair_walls.png`,
  `mould_club.png`, `mould_builder.png`, `mould_figure_front.png`,
  `mould_figure_corner.png`, `mould_figure_side.png`: the hair on the head, not
  through it, its fringe a quiff; the club in the hand where a sword would be.
- `print_flow.mjs` (`figure prints and moulds in a browser`: WebGL 2, IndexedDB
  and GDScript in WebAssembly, which no desktop probe vouches for) ends `print
  flow: drawn, sculpted, worn, placed and kept in the browser`: M, the Head
  slot's Draw a print…, a face drawn with the mouse and saved; the Torso slot's,
  a badge; the Headgear slot's Make a mould…, the hair's top pulled up and saved;
  each save one more part made here (`window.brickworksState.custom`); the figure
  placed with them (`window.brickworksBricks`); the page reloaded and all three
  still made here, the model back with the figure. **Look at**
  `shots/print_web/1_face.png` … `6_reloaded.png`.

## Gotchas

- **A hair piece is thin.** 3901's outside is within 3 LDU of the head almost
  everywhere, so a lock by distance alone locked nearly all of it. The lock is
  by facing too: only corners turned towards the head (`head_outward`, a dot
  under 0.35) and within an LDU of it are its inside; the outside a millimetre
  away is free, and kept off the head by `_keep_off_head` instead.
- **A hair's inside rests on the head's top as well as its sides.** Measured as
  radial depth only, 3901's ceiling at y 0 read as 3.9 LDU inside the head;
  `head_depth` takes the nearer of the radial and the vertical surface of each
  of the head's three pieces (cylinder, rounded top, stud).

- **Measured, not looked up**: three conventions are in real sets' files. The
  library's (76382), Mad_Marc's (hands 0.5 LDU off, sets 10176-10184) and an older
  generator's (arms at `(15.5, 8)`, 95 figures). `tools/minifig.py measure`
  counts each; the app uses the library's.
- **The legs are the current 3816c/3817c**, whose origin is 1.25 LDU from their
  stud hole. The obsolete 3816b and 3816 have it under the origin; most real-set
  files use those, so a figure here stands 1.25 LDU further back on its studs
  than one read from them, and the same everywhere else.
- **A turned part's cover is rounded out to whole 2 LDU cells**, so a shaft
  resting exactly on the ground reads as in it; held things stop a cell above.
- **Cost**: the stability status counts a figure's turned parts box by box —
  measured at about 14 ms a figure in it, 40 with a long accessory, whose cover is
  hundreds of boxes. Fine for a cast; a crowd of forty is two seconds a check.
- **The thumbnailer is shared** with the parts bin, which empties its queue
  whenever it searches, and a part fetched over the wire is drawn only when
  asked for again. The builder asks again for every missing picture twice a
  second.
- **A browser drawing in software is slow to fill the grid.** Thumbnails are one a
  frame and fetches advance a frame at a time; headless Chromium on SwiftShader at
  a load of 65 drew one frame a second and fetched ten parts in two minutes, so
  the flow places the opening figure, whose parts ship in the pack, and only
  photographs Surprise me.
- **Probes keep figures somewhere of their own** (`Minifig.shelf_file`), or a
  check run on this machine writes onto its owner's shelf.
- **Odd parts are not all put right.** Where the library has no assembly, no
  HELP line and no geometry says (the cyborg torso), a part sits at its slot's
  standard joint, LDraw's convention, and can look wrong on a classic figure —
  as it would in the hand. Mixing families (a droid's legs on a plain torso) is
  allowed: legs drawn from their feet up hang from the hips' top; legs bent at
  an angle (the springs bent 45 degrees) stand a cell up, their cover being
  rounded out. u9661c01, an unofficial worn cape, is drawn folded out in front
  and looks it when chosen; its flat cloth hangs flat instead. Something held
  in the prosthetic hand is held where a plain hand's grip would be. Look at a
  family with the contact sheets the probe's numbers stand for.
- **A web export without `PARTS_URL` offers about half the figure parts.** The
  self-contained pack publishes only 120 MB of on-demand geometry and marks the
  rest of the catalogue unreachable, which the builder (rightly) does not offer:
  2271 of the 4263 figure parts. The hosted build serves every part from object
  storage and offers all of them; a local check should export the same way.
- **LDraw draws cloth flat**, as it is sold (50231, 14295); its "(Formed)"
  versions are the shapes it is worn in, and the only ones real sets' files put
  on a figure. Both are offered and a figure wears the formed one either way;
  the slot's picture is the flat one, as sold. Flat cloth with no worn drawing
  hangs flat behind, as wide as LDraw draws it (26701 is 120 LDU across).
  106700, a robe 13 studs long, is taller than any figure: raised clear of the
  ground it stands far above the head.
- **A part's cover is reckoned from its origin's cell**, which off the lattice
  moves it up to a cell lower than the part: a flipper 3 LDU thick on a plate,
  its origin 3 LDU up, read as standing a cell into it, so figures used to
  stand up to 2 LDU above the plate. `Builder.boxes_for` (and `Stability`'s
  own) now keep a square part's cover off the lattice inside its own box
  (`BrickLattice.within`), which only takes away cells the part is not in;
  a figure stands on the plate.
- **Godot reports a missing meta key as an error even with a null default**, so
  `ThumbTile.Sight` asks `has_meta` first: the builder's "none" and "+160" cells
  have no tile, and asked for one every frame they flooded the log.
- **Q/E used to floor every origin onto the 2 LDU lattice** (`rotate_model`), which
  moved arms off shoulders; it now only rounds off float dust.
- **Stability weighs a part at the middle of its shape**, not its LDraw origin (the
  top of its body); weighed at origins a figure on two studs read as top-heavy.
