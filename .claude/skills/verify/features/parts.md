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
tools/check.sh --network    # adds remote_probe: geometry over the wire
```

Proves it when: each exits 0 with no `FAIL`. `search` prints its answers for a
handful of queries — read them, they are the point. `vocab` is the one that fails
when the index stops answering a plain English word.

For the bin, launch the app, press `P`, type "wedge": the results are parts whose
titles contain it, drawn in the current colour. **No probe covers the panel** —
it is hands-only, so say so rather than claiming it.

## Gotchas

- **The catalogue load is the 15–20s start-up.** Every probe pays it.
- `fetch` covers the case that broke: two callers asking for the same part, one of
  them never being told it arrived.
- The web build cannot read `assets/generated/parts` — it carries a smaller pack
  chosen by `tools/web_pack.py` and fetches the rest. A part that works on the
  desktop can still be missing on the web; `remote_probe` is what checks the path
  the web build uses.
