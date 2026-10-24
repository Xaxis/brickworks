# My collection

What a person owns, kept with their account: what the open model needs that
they do not have, what could stand in, the shortfall as a shopping list, and
which models they could build from what they have. Added 2026-10-12.

<!-- covers: ui:my collection, lib:collection sums, lib:collection kept with the account, lib:a rebrickable account, cli:set inventories, cli:official models' parts lists, cli:model library, cli:model library in storage, api:/api/collection, cli:collection api probe, cli:collection browser flow, cli:apply sql to the live project -->

## Sub-features

- `my collection` (`src/ui/collection_dialog.gd`, built by `Shell`): Build, My
  collection… / What do I need?… / What can I build?…, and the parts list's
  **What do I need?** button. One panel over the model, three pages:
  - **What I own**: sets typed by number ("10237", which is 10237-1), a
    Rebrickable CSV export (a sets list or a parts list), a BrickLink XML (a
    wanted list or an inventory), or the person's Rebrickable account (their
    API key and user token, or once their username and password, which
    Rebrickable trades for a token). The sets by name with their piece counts
    and Remove, the loose parts by lot, Start over (asks first). Every import
    goes through the account; what the server left out is said, with why.
  - **What do I need?**: the model on the baseplate against the collection —
    each lot short, "short of" how many, its colour, its BrickLink page, and
    what could stand in. The shortfall downloads as a BrickLink wanted list
    (`ShopLists.bricklink_xml`) or a Rebrickable CSV, at the counts short.
    BrickLink's prices are not free to read (its API wants a seller's keys and
    its terms), so the panel links each part's catalogue page instead.
  - **What can I build?**: the examples, the person's saved models and the 1,575
    official LDraw set models (`vendor/omr`), ranked by how much of each is
    owned in its own colour, then in any colour; Open puts one on the baseplate
    and shows its shortfall. An official model opens where `vendor/omr` is
    (a checkout); elsewhere See it links its page at library.ldraw.org.
- `collection sums` (`src/collection/collection.gd`, pure): the pool (sets
  expanded through their inventories, plus loose parts), the shortfall, the
  plan of what could stand in, and coverage. One spelling for both sides: a
  part by the number it means today (`PartLibrary.resolve`) and a colour by the
  one a shop files it under (`plain_code`). Before anything is called short,
  another moulding of the same part stands in (3794b for 3794a: a number that
  is digits and one letter). Then, out of what the model does not itself use,
  each spare piece promised once: the same part in another colour, and two
  smaller bricks, plates or tiles in the needed colour that make the same
  footprint (a 1 x 4 from two 1 x 2s, a 2 x 4 from two 1 x 4s).
- `collection kept with the account` (`src/collection/collection_store.gd`):
  the account's copy (`/api/collection`) is the one that counts, and a copy is
  written to `user://collection.json` whenever it arrives, tagged with whose it
  is; with no network the desktop works from that copy and says so. Loaded at
  sign-in, so the assistant has it without the panel opening.
- `a rebrickable account` (`src/collection/rebrickable_account.gd`): the app
  calls rebrickable.com itself (its API answers any page; the deploy's content
  security policy names it), `/users/{token}/sets/` and `/users/{token}/parts/`
  a thousand at a time, paced under Rebrickable's one request a second, and
  stops at a 429. The key goes nowhere else and is not kept; what came back is
  sent on as `rebrickable_api` and replaces the sets and loose parts.
  **Not yet run against a real Rebrickable account** (nobody here has one with
  a key): `collection_probe` drives it against
  `tests/fixtures/collection/fake_rebrickable.py`, which answers in the shape
  Rebrickable's API documents.
- `the assistant, from my collection` (`Assistant.owned`, a small hook): a brief
  with "my collection", "parts I own", "what I have" and the like
  (`Collection.wanted_in`) opens with what the person owns — pieces, colours
  most first, the most plentiful parts — and `search_parts` lists what they own
  first, each line saying how many of each colour ("you own 34: Red 30, Black
  4"). A brief that does not ask hears nothing about it.
- `set inventories` (`tools/collection_data.py`): every set's parts in LDraw's
  numbers, from Rebrickable's downloaded tables (never fetched here; the copy
  `tools/fetch_data.sh` keeps is the source, and it fetches at most once a day):
  version 1 of each set's inventory, its minifigures' parts and any set packed
  inside it (`inventory_minifigs`, `inventory_sets`, added to `fetch_data.sh`
  2026-10-12), spares apart. Rebrickable colours through the catalogue's own
  colour join; a Rebrickable part number that is not LDraw's renamed to the
  LDraw part whose own header names it ("Rebrickable 3626apr0001" on
  3626ap01: prints, assemblies such as a torso with its arms and hands, moulds
  numbered apart; an alias gives its target), then through the catalogue's
  part join (7,763 renamed, 146 before 2026-10-19); a figure's hips and legs
  (970c28) and its torso with arms and hands (973c03h01) where LDraw names no
  assembly, as the parts LDraw draws, colours from Rebrickable's names (so the
  Magic Shop is 49 pieces, not Rebrickable's 47); BrickLink colours from colors.json's `bricklink`,
  the numbers the wanted list is written in (where two codes share one, the lower
  wins: BrickLink 77 reads as 148, not 316). 21,173 sets, 256 shards, 26 MB, under
  `assets/generated/sets/`; the shard rule is the same sum in the Python and in
  `SetInventories.shard_of`.
- `official models' parts lists` (`src/dev/collection_models.gd`): the 1,575
  `vendor/omr` models counted with the app's own LDraw reader, leaving out
  what nobody can own (a primitive drawn into the model, a sub-model the file
  names and does not carry, a sticker, a hose or chain drawn link by link, a ~
  piece: `Collection.ownable`), then matched to their own set's inventory
  (`Collection.as_its_set`: another mould, the assembly or its parts, an alias,
  another colour the box has left, another part of the same shape), into
  `assets/generated/sets/models.json` (2.1 MB). Owning a set builds its own
  model whole for 624 of 1,234 sets and within 1% for 880; the rest draw a
  few pieces more than the box holds (2 of 246 whole before, 2026-10-19,
  `bench/results/ownedsets-2026-10-19`). Run after `tools/collection_data.py`,
  which rewrites every file in the folder, this one too.
- `model library` (`tools/library_build.py`, `src/dev/library_covers.gd`): the
  data behind opening any official model from inside the app. Every
  `vendor/omr` model with a cover drawn by the app's own ModelShot (built,
  the three-quarter view, 512 x 384 WebP), staged as the parts store holds it:
  `library/index.json`, `library/omr/<file>.mpd` (LDraw's bytes, licence lines
  kept), `library/covers/<id>.webp`. The index is `{"version": 1, "models":
  [{id, kind, set, name, theme, year, parts, file, cover, author, licence,
  page, alternate_of}]}` in that order (the library screen reads it); name,
  set, year, theme, page and parts are models.json's, author and licence the
  file's own main-model header ("CCAL 2.0" or "CC BY 4.0"); names carry LEGO®
  with its mark. `covers` draws on the GPU lease in drawers of up to 100
  models, each leaving after 20 s when another job waits; 1,575 covers in
  29.7 min, none failed (2026-10-22). 6360-1 is left out: its main model is
  empty, so nothing opens.
- `model library in storage` (`tools/storage_library.py`): the staged
  `library/` into the parts bucket under `library/`, beside `ldraw/parts/`, as
  `application/octet-stream` (the only type the bucket takes); a model or cover
  already there is left, the index sent last over the old one, five minutes'
  cache. 3,151 files, 388 MB (2026-10-22, not yet uploaded).
- `/api/collection` (`api/collection.js`, `supabase/collection.sql`): GET, POST
  an import, PUT the whole collection, DELETE. Every import is parsed and
  mapped here (Rebrickable CSV with quoted fields, BrickLink XML, Rebrickable's
  API rows, typed set numbers) and nowhere else. Refuses: no sign-in (401),
  naming any account (`?owner=`, `?user_id=`, a body's `owner`: 403 — there is
  no way to ask for another's), a body over 1 MB or a collection over 5,000
  sets or 20,000 lots (413), a file that is not what it says, with its line
  (400). The table: one row per account, `owner` → `auth.users` on delete
  cascade, `sets` and `parts` as JSON arrays with size checks, row security on
  and, since 2026-10-24 (`supabase/no_client_access.sql`), no policy and no
  grant for any key a page holds: only `/api/collection` reaches it.
  **Applied to the live project 2026-10-12** with `tools/apply_sql.mjs`
  (the pooler, one transaction; the project keeps no Supabase CLI migration
  table, so it is recorded here and in HANDOFF.md, not there): table
  `public.collections`, its four check constraints, policies
  `collections_read_own`, `collections_insert_own`, `collections_update_own`,
  `collections_delete_own`; grants: `authenticated` SELECT, INSERT, UPDATE,
  DELETE; `anon` none. Nothing existing changed.

## How to reach it

```sh
godot --path .     # Build > My collection…  ·  P, then What do I need?
curl -s -o /dev/null -w '%{http_code}' https://brickworks.diy/api/collection   # 401 signed out
```

## How to check it

```sh
python3 tools/minitest.py tests/test_collection.py        # a set's expansion against the raw tables
godot --headless --path . --script src/dev/collection_probe.gd
godot --path . --resolution 1400x900 --script src/dev/collection_ui_probe.gd   # needs a display
# the endpoint against the real database, two throwaway accounts (.env sourced)
node tools/web/relay_server.mjs 8790 &
node tools/web/collection_probe.mjs --url=http://127.0.0.1:8790
BW_BYPASS=$VERCEL_BYPASS node tools/web/collection_probe.mjs --url=https://<a preview>
# in a real browser, against a preview (tools/deploy.sh without --prod)
BW_BYPASS=$VERCEL_BYPASS node tools/web/collection_flow.mjs --url=https://<a preview>/app --out=shots/collection_web
# rebuilding the data, after tools/fetch_data.sh or a catalogue change
python3 tools/collection_data.py
python3 tools/collection_data.py --bricklink   # only the index's BrickLink colours, after colors.json
godot --headless --path . --script src/dev/collection_models.gd
node tools/apply_sql.mjs --look        # what the live table is (PG_MODULE=…, see the file)
# the model library: covers (GPU, ~30 min), staged, held to the format, looked at
python3 tools/library_build.py covers && python3 tools/library_build.py stage
python3 tools/library_build.py check && python3 tools/library_build.py sheet --count 60
python3 tools/minitest.py tests/test_library.py
python3 -m http.server 8961 --bind 127.0.0.1 --directory bench/results/library-2026-10-22 &
godot --headless --path . --script src/dev/library_open_probe.gd -- --base=http://127.0.0.1:8961/
godot --headless --path . --script src/dev/library_open_probe.gd -- --recount
tools/storage_library.py --check       # what the upload would send; without --check it sends it
```

Proves it when:

- `test_collection` passes: 6020-1, 10237-1 and 3931-1 come out of the shards
  exactly as a straight count of the raw CSVs (their own parts, their
  minifigures' parts, spares apart) says, and BrickLink 5, 86 and 11 read back
  as LDraw 4, 71 and 0 (and 9, 10, 77, 15, 74, 95 as 7, 8, 148, 43, 41, 315); every
  colour the shipped models use and the 30 commonest in the set inventories has a
  BrickLink number; colors.json carries `tools/bricklink_colours.py` exactly.
- `collection_probe` ends `every sum came out as it should`: the example car,
  owned as `collection_flow.mjs` owns it, is 61 pieces with 26 lots short, and
  its BrickLink wanted list carries all 26 (21 before colors.json had BrickLink
  numbers); 6020-1 is the Magic Shop's 47 pieces in 33 lots, a made-up set is named not guessed, two shops,
  Orthanc with spares and loose bricks sum exactly; 4073 compares as 6141 and a
  rubber tyre as black; the hand-made shortfall (12 pieces, 5 owned, 7 short;
  5/12 exact, 9/12 in any colour); 3794b standing in for 3794a, and 3660a,
  3660c and 4287a for the 3660b and 4287c Brickify lays; white 2 x 4s
  for red and blue, two 1 x 2s for a 1 x 4 twice with one left, three spares
  offered three times not four; the wanted list asking for 2 of 3001 and 3 of
  3010; three official models counting the same opened as listed; owning a set
  covering on average over 80% of its own official model (83% measured — the
  rest is the model's author and Rebrickable disagreeing: Light Grey for Light
  Bluish Grey, a hinge's two halves for the pair, a hose link by link); the copy
  on this device read back offline; the Rebrickable stand-in read over two
  pages, a token traded once, a bad key and a wrong password in words; and the
  assistant told what is owned and leading `search_parts` with it.
- `collection_ui_probe` ends `the shortfall, the ranking and the collection on
  screen`; look at `shots/collection_need.png`, `collection_build.png`,
  `collection_own.png`.
- `collection_probe.mjs` ends `every check passed` (44 checks): every import in
  LDraw's numbers, the other account refused by the endpoint, and straight at
  the database every session refused, the owner's too, and the anonymous key, the
  three size limits, ten malformed files refused with their line, and both
  accounts and their rows gone at the end.
- `collection_flow.mjs` ends `imported, short, exported, ranked and opened in a
  browser`; look at `1_need_empty.png` to `5_opened.png`.
- `library_build.py check` says `0 problems` and `test_library` passes (the
  checker caught each of eleven ways of breaking a model, and the index built
  from every file holds: an author and a licence for each). Look at
  `bench/results/library-2026-10-22/sheets/`: every cover a built model,
  framed with a margin. `library_open_probe` ends `0 failures`: the index
  fetched from the served store, and three models (44, 635 and 8,968 parts)
  fetched byte for byte as LDraw has them, opened with the app's reader and
  counted as models.json counts them; `--recount` finds every model as
  models.json says (1,575 of 1,575, 2026-10-22).

Last proven 2026-10-12 on the preview of `133ed75`
(brickworks-4ox4aq5lj-xaxis-projects.vercel.app): `collection_probe.mjs` 44 of
44 against the deployed function, and `collection_flow.mjs` end to end — the
example car 61 pieces, 19 owned after the import and the typed 6020, 42 short
in 26 lots; the BrickLink list carried 32 pieces in 21 lots and said 5 lots
were left off, because the hand-made colour table had no number for the car's
Light Grey and Trans Very Light Blue. colors.json's `bricklink` (2026-10-12)
closed that: `collection_probe` has the same car and all 26 lots on the list.
A deployment carries the numbers once `colors.json` is rebuilt
(`tools/refresh_catalogue.py --colours`) and the index's BrickLink join with it
(`tools/collection_data.py --bricklink`, which leaves the shards alone).

## Gotchas

- **Godot exits 0 on a parse error**: read the probe for `SCRIPT ERROR`.
- New classes here (`Collection`, `CollectionStore`, `SetInventories`,
  `RebrickableAccount`, `CollectionDialog`, `TextFilePicker`) are not known to a
  `--script` run until `godot --headless --path . --import --quit` has scanned
  them: "Identifier not declared" from a probe means that, not a typo.
- The web build fetches `/sets/NNN.json` from its own deployment. A local
  export served by `relay_server.mjs --static` has none, and a typed set then
  adds no parts and says so ("the set inventories did not arrive").
- `What can I build?` reads the person's saved models from `user://models/`, so
  a probe on this machine ranks the owner's own saves too ("Yours").
- Minifigures and sets inside sets are expanded; BrickLink minifigures in an
  XML are not (nothing here says what is in one) and are counted as left out.
