# Parts

Finding one of 28,000 parts by the words a builder would type, and getting its
geometry in front of them.

<!-- covers: lib:part search, ui:parts bin, lib:mesh fetch -->

## Sub-features

- `part search`: ranked search over the catalogue (`assets/generated/catalogue.json`,
  14 MB). Matches the LDraw title, the category and the number, and is judged on
  whether the *first* few answers are usable rather than on recall.
- `parts bin`: the panel that shows the results, with a category filter and the
  current colour applied to the thumbnails.
- `mesh fetch`: a part whose mesh is not in the shipped pack is fetched from the
  storage bucket at run time. Several callers can ask for the same part at once,
  and every one of them has to hear that it arrived.
- `availability`: which colours each part was really moulded in, and the years it
  appeared in a set. Joined from Rebrickable's tables by `tools/rebrickable.py`
  at catalogue-build time; read by `PartInfo.colors` / `colors_recent` /
  `never_made_in()`; surfaced on the search line and as `check_design` advice.
- `how often a part is really used`: `rebrickable.usage()` counts the distinct
  catalogued sets each part appears in and writes `in_sets` onto every part that
  joins. `PartLibrary.staples(n)` gives the most used, `PartsBin._usage_score`
  folds it into search ranking, and `Assistant._what_sets_are_built_from()` puts
  the top thirty in the system prompt.
- `how a kind of set is built`: `rebrickable.kinds()` measures, for every word
  that names 20+ real models, the parts those sets reach for *more often than
  sets in general* and the colours they build in — 267 kinds in 86 KB of the
  catalogue, over models only (see `set norms` below for what is not one). Each
  kind also carries `common`: its 40 most used parts by the share of its sets
  that use them at all, which lift cannot say — lift finds what makes a castle a
  castle, and a 1,895-part castle also has some 260 shapes, mostly ordinary ones.
  Both are counted in **sets, not lots**: counted by lot, a set with the 1 x 2
  plate in four colours used it four times, and the castle's share of 1 x 2
  plates came to 346%. `PartLibrary.kinds_for(brief)` matches a brief's words against it
  and `how_real_sets_build_this`, a tool, is how the assistant asks.
- `set norms`: what a real LEGO set of a given size is made of — lots, shapes,
  colours, how many of one piece is normal, shapes used once or twice, its main
  colour's share, and the share of its pieces as big as a 2 x 4 brick (`big`,
  sized through the one LDraw join by `rebrickable.piece_size`; a median 9-11%
  at every size) — measured over every catalogued model set by
  `rebrickable.set_norms(entries)` and written into the catalogue header.
  `PartLibrary.normal_for(parts)` gives the band; `Assistant._variety()` says
  when a design is well under it; the system prompt carries the whole table.
- `element numbers`: the LEGO element a part in a colour actually is —
  `3001` in red is `300121` — so a parts list is orderable rather than
  descriptive. `rebrickable.elements()` writes `assets/generated/elements.json`
  (0.8 MB, 40,474 pairs over 5,298 parts); `PartLibrary.element_for()` loads it
  lazily; `Inventory.Lot.element` carries it into the CSV and the booklet.

## How to reach it

```sh
godot --path .     # press P, or the Parts list button, then type
```

The bucket behind `mesh fetch` is `PARTS_URL` in `.env`, also announced by
`GET /api/account` as `parts_url`.

## How to check it

Static: the catalogue itself is built by `tools/refresh_catalogue.py` (see
[pipeline](pipeline.md)); nothing static covers the ranking.

Runtime:

```sh
godot --headless --path . --script src/dev/search_probe.gd          # what it returns
godot --headless --path . --script src/dev/vocab_probe.gd           # the words a builder types
godot --headless --path . --script src/dev/search_quality_probe.gd  # how much is worth reading
godot --headless --path . --script src/dev/inventory_probe.gd       # parts lists of known models
godot --headless --path . --script src/dev/fetch_probe.gd           # every caller hears it arrived
godot --headless --path . --script src/dev/availability_probe.gd    # what was really made, and silence otherwise
godot --headless --path . --script src/dev/variety_probe.gd        # whether a model reads as a set
godot --headless --path . --script src/dev/usage_probe.gd         # whether search leads with the part sets use
godot --headless --path . --script src/dev/kinds_probe.gd         # whether a castle knows it is arches
tools/check.sh --network    # adds remote_probe: geometry over the wire
```

Proves it when: each exits 0 with no `FAIL`. `search` prints its answers for a
handful of queries — read them, they are the point. `vocab` is the one that fails
when the index stops answering a plain English word.

For the bin, launch the app, press `P`, type "wedge": the results are parts whose
titles contain it, drawn in the current colour. **No probe covers the panel** —
it is hands-only, so say so rather than claiming it.

## Gotchas

- **"Another way" was the whole question.** A search result said a part had
  "N studs on top and M facing another way", which is true of a bracket, a
  headlight brick and anything with a stud underneath — and whether the part
  does the job in hand then cost an `attachment_points` call. It says which
  way now: `87087` is "1 stud on top and 1 facing sideways", `99207` is "2 on
  top and 4 facing sideways". Named in the part's own frame and not the
  world's, because an unplaced part has no world and `rot` decides where it
  ends up, so "+x" would be a claim about something nobody has chosen yet.

- **A name can only say so much about a part.** Ranking built out of plainness,
  qualifiers, prints and sizes cannot tell you that 3062b, "Brick 1 x 1 Round
  with Hollow Stud", is in 4,496 sets while 71075a, named just as plainly, is in
  seventeen. Over 35 ordinary queries: **12 led with the part real sets use most
  and the leader carried 71% of the usage the best match had; 16 and 81% once
  `in_sets` counted.** It fixed "round brick 1 x 1", "hinge" (4625, 190 sets ->
  3937, 2,174), "antenna" (104, 5 -> 3957a, 918) and "jumper" (1745, 367 ->
  87580, 2,941).

  Two disciplines hold it up, both asserted. **It promotes and never demotes**:
  5,988 of 29,479 parts join to an inventory, so a zero is silence. And it is
  **capped under the weakest name tier** (100 against 140), so "plate 4 x 4"
  still leads with the 4x4 in 3,603 sets, not the 2x4 in 7,969. Filling the gap
  with explicit zeros to push down parts no set contains moved 221 parts and
  changed no ranking; it is not here.

  Score a ranking against the same usage number the ranking reads. The first
  diagnostic counted inventory *rows* and reported 3023 in "25,944 sets" and 7891
  in none; the honest figures are 9,285 distinct sets and 1.
- **The one join between the libraries is `rebrickable._matcher`.** Colours and
  usage both need to know which Rebrickable part an LDraw id is, and two copies
  of a join drift apart. Extracting it changed nothing: 6,419 parts with colour
  lists and 40,474 element pairs before and after, **0 answers different** — the
  check that made the refactor safe to keep.

- **Lift, not count, or every kind of set is the same list of plates.** Counted
  plainly a castle and a spaceship are both mostly 1x2 plates — true and useless.
  Dividing by what sets in general do gives a castle the arch door at **26x**,
  arched window panels at 15x, lattice windows at 14x, in tan and pearl gold; a
  spaceship the round brick with fins at 9.5x, 2x2 brackets at 7x, in white and
  grey. `kinds_probe` asserts the thing that could fail: **a castle and a
  spaceship share 0 of twelve parts.**

  Four defects it found, each fixed in the data: LDraw files Duplo train track
  under "Train", so `train` led with two Duplo tracks at 70x; minifig
  accessories took the top four places for `pirate` and buried the hull, so
  categories split what a set is *built from* from what it *carries*; 68 entries
  across 367 kinds had lift <= 1.0, the thinner kinds padding their twelve out
  with ordinary plates; and `REAL_MODEL = 20` parts, or the kinds are keychains,
  backpacks and Adidas shoes. Only parts that join to a placeable LDraw id, which
  is asserted over all of them.

  **A kind of thing is a meaning, and the meaning is not in the inventories.**
  Generic words got through — `large`, `play`, `version` — and it mattered because
  the most specific-looking kind goes first, so "a large castle" led with `large`
  over 88 sets instead of `castle` over 175. Dropping kinds whose parts are not
  distinctive was measured and **refuted**: `play` tops out at 190x and `version`
  at 121x, above castle's 26x, while `farm` is 3.3, `car` 4.2 and `fire` 4.5. So
  `NOT_A_KIND` is a word list, 343 kinds, and the probe asserts both halves.

  **It arrives with the brief, not as a tool to call.** Measured twice on this
  project: a capability a design can get by without is one it never uses — it
  reached for sideways building because a smooth sign face is impossible
  studs-up, and never for a wedge plate across three runs. `opening_for()` puts
  it in the first message; a revision naming no kind gets nothing, asserted. It
  admits ignorance: a lighthouse matches nothing and says so. A prefix match at
  4+ letters makes "spaceship" find `space`, the word real sets use.
- **The prompt now says what a set is made of, not what I think it should be.**
  Every other piece of advice in it about what to reach for was mine: tile a
  roof, curve a bonnet, use a bracket for a sign. `_what_sets_are_built_from()`
  is the catalogue counting instead, and the first thing it says is not advice at
  all — **a LEGO set is mostly plates.** Eight of the ten most used parts are
  plates; the 2x4 brick everyone pictures is number 22. A design reaches for what
  it remembers, and what a model remembers about LEGO is bricks.

- **"Does it read as a set" is measured, not judged.** Banded by size over 8,243
  models: one of 350-800 parts has about 158 part-and-colour lots, 123 shapes, 19
  colours, and at most about 23 of any one piece. `models/station.ldr` is the
  fixture because it provoked this — 535 parts, 45 lots, 30 shapes, **86 of one
  brick**: the right size, the wrong texture, and nothing said so.

  **A multiple of the median read like a tolerance and was not one.** Firing
  below 0.6x the median shapes and above 2x the median repeat fires on **29-34%
  of real LEGO sets**, measured against the same inventories the norms come from.
  A third of real sets told they are repetitive is noise, and this project holds
  advice to the standard that it must not fire on good models. The bands carry
  their tails now — 5th percentile for lots, shapes and colours, 95th for the
  largest lot — which is **9.1% of real models overall, worst band 10.2%**. The
  medians are still what gets *reported*, because "a real set this size has
  about 123 shapes" is the useful sentence; the percentile only decides whether
  to speak.

  **A tail is only as good as the population under it.** The norms were first
  measured over every set, and the thinnest sets of every size are not models:
  mosaics, LEGO Art, DOTS, bulk tubs, education packs, Duplo. Over 1,800 parts
  that put the 5th percentile at **21 shapes** (2,305 tiles in two shapes is a
  "set") and the 95th of one piece at 660, so a 1,828-part castle with 30 shapes
  and 320 of one brick was told nothing at all. `rebrickable.NOT_A_MODEL` leaves
  them out by theme, and `NAMED_NOT_A_MODEL` by name for the ones filed
  elsewhere (Creator bulk tubs, a film character's mosaic). Decided by what the
  product is, never by how varied it is, or the cut would move the threshold it
  sets. Over 1,800 parts it is **134 shapes** now, median 262, and 511 of one.
  The station's 30 shapes moved from the 4.2nd percentile to the 1.1st.

  2nd/98th would be rarer and was rejected on evidence, measured with the
  mosaics in: it missed the fire station on both counts. `variety_probe` asserts both directions, including that a model with a
  real set's median spread is left alone and so is one using 58 of a piece, which
  nine real sets in ten are under and the old rule called repetitive at 48.

  Advice, never a fault. Beware testing it with a control that is itself thin:
  mine had 20 shapes, the check correctly flagged it, and for a moment that
  looked like a false positive.
- **Which moulding a bare part number means is settled by LDraw's redirects, not
  by the alphabet.** `3023a` and `3023b` are both "Plate 1 x 2" and both reduce
  to `3023`, so whichever was indexed first took the number — and every `3023`
  element went to `3023a`, while every model in the repo uses `3023b`. LDraw
  itself answers it: part `3023` is "~Moved to 3023b". Following the redirect
  took element coverage on the pairs real models use from 94% to 97%.

- **The element join is confirmed by LEGO's own numbering, independently.** An
  old-style element number is the design number with a two-digit colour
  appended, so `3001` + red is `300121` and `3024` + black is `302426`. Of the
  3,846 pairs whose element is six digits or fewer, **98.4%** begin with the
  design number — a check the join never consulted. Do not run that test over
  7-digit elements: those are sequential and carry no design number, and
  including them scores 14% and looks like a broken join.

- **The connector table is classified from the primitives' own descriptions,
  not their filenames.** `axlehol8` is "Technic Axle Perimeter" — part of a solid
  axle — and registering it as a hole made every Technic axle report an
  `axle_hole`: part 3705, a plain Axle 4, came out as `{axle: 2, axle_hole: 1}`.
  `axl2hol8` is "Technic Axle Hole Reduced Perimeter" and really is a hole. One
  letter apart, opposite meanings. Nine registered names (`bar`, `bar2`,
  `barhole`, `ball`, `balljnt`, `socket`, `socket2`, `axle2`, `npeghol1`) did not
  exist in the library at all, so BAR, BALL and SOCKET had never been detected
  once. There is still **no bar primitive**: a bar is a plain 3.2 mm cylinder, so
  finding one needs a radius measured, not a filename read — which is why a clip
  has nothing to grip.

  **Measuring the radius was tried and is not enough.** Part 30374, "Bar 4L
  Lightsaber Blade", is a single `4-4cyli` scaled `(4, 80, 4)`, so the obvious
  test is a cylinder whose two perpendicular scales are ~4 LDU with a third at
  least half a stud long. Measured against the 570 parts whose name says bar,
  antenna or rod, that finds 45% of them — and fires on **19.8% of a 400-part
  sample of everything else**: minifig arms, torsos and heads are full of
  radius-4 cylinders. A false bar lets a clip hold thin air, which is the
  direction that costs something, so radius alone cannot ship. What it needs is
  some test that the cylinder is *exposed* with a free end, which is geometry
  work rather than a tree walk.

  **Nor by shape and name.** Of the 313 parts whose name says bar, antenna or
  rod, only **six** are thin rods by their bounding box — 104, 30374, 87994 and
  three others. The rest are a bar with something on the end: a hilt, a flag, a
  tool. So the bar has to be found *inside* the part, which is the same geometry
  problem again.

  **Nor by the shape of its collision boxes.** The boxes are the
  stud-removed cover, so a bar ought to stand out: part 30374 is two of them,
  4x40x2 and 2x40x4, a cross approximating a 4 LDU rod. Testing for a box thin
  in two axes and long in the third finds 63% of bar-named parts and fires on
  **39.3%** of everything else — worse than the radius test, because the greedy
  cover produces thin slivers for any part that is not boxy. Four approaches
  have now been measured and rejected; what would work is a curated list of
  which parts are bars, gated by name, using the rod-shaped box for the
  position. That is semantic knowledge, not geometry.

  **And clips cannot be inverted to avoid it.** The tempting shortcut is to skip
  bars and say a clip grips whatever occupies its jaw. Two things stop it: the
  bar part itself has no connectors at all, so there is no pair to confirm; and a
  clip's own position is often inside its own plastic (4085b, Plate 1x1 with Clip
  Vertical), so a gripped bar *overlaps* the clip rather than sitting in free
  space. Forgiving that overlap would need a far looser rule than the pin's —
  which demands collinear axes within 4 LDU — and a loose rule here would hide
  real faults. 213 parts carry a clip and none of them can grip anything yet.

- **Hinges have no connector kind, and adding one buys little.** The old
  hinges — 3937/3938, 4213/4214, the ones `models/car.ldr` is built with — are
  drawn from plain cylinders and boxes, so there is nothing to detect by name.
  The click-lock family does have primitives (`clh1`..`clh15`, `arm1`..`arm3`,
  `4-4crh1/2`), but only **78 parts in the library reference them**, which is
  not worth a new ConnectorKind, a format bump and a 90-minute rebuild. Some
  hinge plates (2430) already get a `pin` because they are drawn with
  `connect2`. Until this changes, a hinge holds in the checker only because
  there is material in the cell below it.

- **`npeghol*` is subtracted geometry, not a connector.** "Technic Peg Hole
  Negative" marks where material is *missing*, which is not the same as where a
  pin can go: Technic Beam 2 draws one at its waist, between its two real holes,
  so the beam reported three holes and the middle one took no pin.

- **Unknown is not "never made", and the whole feature turns on that.** The join
  knows 6,419 of the 8,591 plain parts, and 846 of those have a *short* list
  because sixty-nine Rebrickable colours have no LDraw counterpart (BrickLink's
  "Dark Purple" is LEGO's "Medium Lilac"). `never_made_in()` therefore refuses to
  answer for an empty list *or* a `colors_partial` one — read `colors` directly
  only if you have handled both. Matching the leftover colours by swatch was
  tried and measured: nearest-ΔE picks Dark Blue Violet for Dark Purple and
  merges pearlescent "Pearl Sand Blue" into solid "Sand Blue" at ΔE 2.9, while
  name-matched pairs are only 50% within ΔE 8.2. It does not work; do not retry
  it without new data.

- **A check against a colour the part was made in proves nothing.** The first
  version of this probe asserted `not 3001.never_made_in(484)` — but 3001 *was*
  made in Dark Orange, so deleting the `colors_partial` guard altogether still
  passed. It uses Light Violet (20) now, which is genuinely absent from 3001's
  short list. Mutate the guard away and watch that check fail before trusting it.

- **The loose part-number match is name-gated, and was wrong without it.**
  Stripping a mould suffix matched LDraw `6216c` (an electric motor) to
  Rebrickable `6216` (a curved brick), `3240a` to a Duplo door, and LDraw's
  zero-padded sticker `004324b` to part `4324`, a Fabuland rake. It now requires
  the two names to share a four-letter word, which took the disagreement rate
  from 2.5% to 0 across 182 matches.

- **Rebrickable's grant allows one download a day.** `tools/fetch_data.sh --force`
  deliberately will not re-fetch their tables if the local copy is less than a
  day old. That is a licence condition; see `docs/ATTRIBUTION.md`, which also
  carries the required "Catalog data: Rebrickable" credit and where it must show.

- **The catalogue load is the 15–20s start-up.** Every probe pays it.
- `fetch` covers the case that broke: two callers asking for the same part, one of
  them never being told it arrived.
- The web build cannot read `assets/generated/parts` — it carries a smaller pack
  chosen by `tools/web_pack.py` and fetches the rest. A part that works on the
  desktop can still be missing on the web; `remote_probe` is what checks the path
  the web build uses.
