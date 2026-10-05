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
- `element numbers`: the LEGO element a part in a colour actually is —
  `3001` in red is `300121` — so a parts list is orderable rather than
  descriptive. `rebrickable.elements()` writes `assets/generated/elements.json`
  (0.8 MB, 40,474 pairs over 5,298 parts); `PartLibrary.element_for()` loads it
  lazily; `Inventory.Lot.element` carries it into the CSV and the booklet.

## How to reach it

```sh
godot --path .     # press P, or the Parts button, then type
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
