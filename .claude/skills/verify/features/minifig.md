# Minifigures

Making a minifigure from real LDraw parts, slot by slot, standing it on a stud in
the model, and the design assistant doing the same with `add_minifig`.

<!-- covers: ui:minifig builder, lib:minifig assembly, lib:add a minifig, cli:measure minifig offsets, cli:minifig browser flow -->

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
    until its end is a lattice cell off the ground.
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
  data`): 518 grips (everything the hands are offered, the bicycle and the pot
  too), 115 neck lifts (what real figures do where any do, the collar off the
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
  the numbers above; `grips` checks the grip rule on the 236 accessories real
  figures hold (157 on the bar the real hand holds, 77 within 3 LDU of the same
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
  air, in something, or on another figure's head. Its parts are the design's own
  (`_placed_ids`), so a new submission replaces them. Offered over MCP like every
  tool; `connector_form.said` captions it.
- `minifig browser flow` (`tools/web/minifig_flow.mjs`): the same in a real browser
  on SwiftShader, driven by the positions the app publishes
  (`window.brickworksControls`, which carries the builder's buttons and slots
  while it is open, and `minifig_choice`, the first part the grid offers) and the
  part count it publishes (`window.brickworksBricks`). It also chooses a cape —
  a part the pack does not ship, fetched over the wire — and places the caped
  figure.

## How to reach it

```sh
godot --path .                     # M, or Minifig in the top bar
tools/minifig.py measure           # the offsets against 517 real figures (~30 s)
tools/minifig.py grips             # the grip rule against 236 held accessories
tools/minifig.py data              # rewrite src/minifig/minifig_data.gd (~2 min)
```

On the web the builder's parts come over the wire like any other; the default
figure's are in the pack (`tools/web_pack.py` ESSENTIAL).

## How to check it

```sh
godot --headless --path . --script src/dev/minifig_probe.gd
godot --path . --resolution 1400x900 --script src/dev/minifig_ui_probe.gd   # needs a display: see tools/check.sh for xvfb-run
python3 tools/minitest.py tests/test_minifig.py
node tools/web/minifig_flow.mjs --url=<a build>/app --out=shots/minifig_web
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
  but not 1 LDU into it.
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

## Gotchas

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
