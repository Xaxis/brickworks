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
