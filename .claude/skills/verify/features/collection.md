# My collection

What a person owns, kept with their account: what the open model needs that
they do not have, what could stand in, the shortfall as a shopping list, and
which models they could build from what they have. Added 2026-10-12.

<!-- covers: ui:my collection, lib:collection sums, lib:collection kept with the account, lib:a rebrickable account, cli:set inventories, cli:official models' parts lists, cli:part counts probe, cli:model library, cli:model library in storage, api:/api/collection, cli:collection api probe, cli:collection browser flow, cli:apply sql to the live project, ui:loose parts in my collection, lib:a session's loose parts over mcp, cli:mybricks probe, cli:mybricks api test, ui:compare two sets or models, lib:parts compare, cli:comparesets probe -->

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
- `loose parts in my collection` (`src/ui/collection_dialog.gd`, APP_UX5 #2
  mybricks, 2026-11-06): What I own's Loose parts row adds one lot at a time:
  a part found by the bin's own search (`PartLibrary.search`, the family's
  word first, `PartsBin._named_first`), a colour's name typed with it taken
  as the colour ("red 2x4 brick", "Light Bluish Gray 3020"); from a photo of
  the part (Photo…, the bin's Brickognize and the same notice first, the
  photo's colour taken when Brickognize is sure); Like this (`PartLike`); or
  a part chosen in the bin while the page is open, in the bin's colour. The
  colour list has the colours the part was made in first. How many, Add (Enter
  in the count adds). Each lot is listed under where it came from (Loose
  parts, From Rebrickable (a fetch or an export: one list, the person's), From
  a BrickLink XML, Loose parts brought in before (kept before sources were))
  with its count changed in place (sent 0.6 s after the last change, or at
  once before any other press) and Remove; a lot of a part and colour already
  there adds to it. Written so nothing is lost (mybricks2, 2026-11-06): every
  change is one op made on the server (`CollectionStore.change`), never a
  whole collection sent, one at a time (the panel's, a session's
  edit_collection, a probe's: each waits its turn). An add is a difference
  with a request id (sent again as it was when the network failed, made
  once, and answered as the first try was: an import's counts too); a
  count, a removal, Keep them, Take back and a set's Remove carry the count
  the panel showed, and when that changed meanwhile the server refuses (409)
  with the collection as it is, which the panel shows, saying so. A reply
  is taken only when its rev is at least the one held, so a read answered
  after a later Add never drops the Add. Opening the panel reads the
  account's afresh; offline it shows this device's copy and writes nothing
  from it; a reply for an account no longer signed in is dropped, and a
  change whose answer never came for this account is told "it may have been
  made: reload My collection to see". A lot that stops at 100,000 (an Add,
  Keep them, an import) is said, with how many went over.
- `a session's loose parts over mcp` (`AppTools._edit_collection`):
  `edit_collection {"add": [{part, color, count}], "remove": [...]}` in one
  call, all or nothing; a part by its LDraw number or BrickLink's, a colour by
  its code or name; a sticker or a ~ piece refused. Each lot added is marked
  `by` (who the session is, "Claude"; any printable name, trimmed, 60
  characters at most) and `chat` (the relay's chat id; a session on the
  desktop's MCP port that names none has its connection's, `mcp-<its
  Mcp-Session-Id>` or `line-<n>` on the line protocol), a lot apart from the
  person's own of the same part and colour. remove= takes only this chat's
  lots (one lot named twice sums; a count of 0 or none takes all of it), from
  the count this chat was last shown of each (refused, nothing changed, when
  the person or another device changed it since), and names the person's own
  as theirs. With neither it reads the collection
  back, this chat's lots apart. My collection lists a session's lots first,
  under "Added by Claude", with Keep them (they join the person's own, by
  hand) and Take back what Claude added (exactly those lots out, at the
  counts shown, any number of them). Needs the person signed in.
- `build from a set's parts` (`src/collection/set_bin.gd`, `src/ui/parts_bin.gd`,
  docs/APP_UX.md B10, 2026-10-30): the parts bin as one set's parts, or
  several sets' added up, a tile for each part and colour in its own colour,
  each counting how many are left (`SetBin`). Chosen by a set's number typed
  into the bin's search ("10497-1", "set 10497": the line at the bin's top
  offers it, Build from it; Add its parts while building from one), by Build
  from it and Build from them all on My collection's What I own, and by
  `/app?parts=N` (`Main._maybe_fill_bin`). The counts are never kept: each
  model change (`BrickWorld.revision`, at most every 100 ms while it goes on)
  they are worked out again from the model's bricks (`SetBin.used_in`, its
  baseplate left out), so a part put down, undo, delete and an open all
  count alike. None left: greyed, still placeable, then "N over" on the tile
  and the line, whose count sits by All parts and is never cut short by long
  names. A tile taken takes its colour. A search and the categories pick
  among the set's parts, each category counting the set's kinds and the
  empty ones hidden; All parts on the line goes back. Kept in the
  model's saves and autosave as `0 !BRICKWORKS BIN <numbers>` after the first
  line (never in what is published or exported, as the share line is);
  followed when a model opens, kept by New, let go by Make a part's and
  Print's own categories. The web build fetches the one shard a set is in
  from the deployment's `/sets/` (about 0.2 s for 10497-1's 140 KB).
  The step's parts first (appux2 bin2 follow-up, docs/CADTASK.md section
  11): a set LDraw's repository has a model of follows that model's
  booklet (`SetBooklet`: `LdrModel.flatten`'s steps, each part in the set
  bin's key, a colour the set lacks taken as the set's own colour of the
  part). Its own model (`<number>.mpd`) or its only one by Build from it;
  with two or more, "Follow a booklet:" offers each by name under the
  set's line (`controls_by_name` "booklet <file stem>"), which builds from
  the set and follows that one. The step is worked out from the model like
  the counts (`SetBooklet.first_open`, `left_in`): the first not yet built,
  or one turned to by ‹ and › until it is built; the whole step's parts are
  listed first in its order, marked by an accent line (`in_step` meta), a
  part put in keeping its place, so the grid is listed again only when the
  step turns. The step line under the set's says
  "Balance, step 1 of 5: 24 parts to put in"; Stop lets the booklet go. The
  file is read from `vendor/omr/files` in a checkout, else the model library
  (`ModelLibrary.model_text`), parsed off the frame. Not kept in the model:
  an alternate's booklet is chosen again after the model is opened (its own
  model's is followed again by itself).
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
  sign-in by the window's own store (`Shell.collection_store`), so the
  assistant, Bring in a 3D model's box and `parts_list which=need` have it
  without the panel, which is made on first use (Later) and reads the same
  store. With the panel made on first use and fetching then, the first of
  them read nothing (leaves3, 2026-11-06): `collection_arrives_probe`.
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
- `compare two sets or models` and `parts compare` (APP_UX6 #7, comparesets,
  2026-11-07; `src/ui/compare_view.gd`'s parts sheet, `src/parts/parts_compare.gd`):
  File, Compare two sets or models… (Shell `compare_sets`) opens Compare as a
  sheet over the model, as the parts list is: A and B each a set by its number
  (`SetInventories`, its spares not counted, as Rebrickable's compare leaves
  them out), a saved model or an example (its file, as What can I build? reads
  it) or the model open now (as What do I need? counts it, stickers and made
  parts not counted). Tabs In both, Only in A and Only in B list the lots by part
  and colour with their pictures (the parts list's rows); the matching is
  `Collection.allocate` with B as needs and A as on hand (own part and colour,
  then another moulding, named "(2 as 3794a in A)"), so each side's pieces are
  counted once and the tabs add up to them. Only in B is the list to buy to
  build B from A: its BrickLink, Rebrickable and LEGO® Pick a Brick buttons
  write it through `Exports.stock_list` (the parts list's own writers,
  `ShopLists`, direct colours in their stand-ins) as B_from_A_pickabrick.csv.
  Swap turns it round. What it compared last is chosen again; another model
  opened, New or Clear closes it, as Compare with a save. `parts_list
  which="compare" a= b=` says the same to a session (a and b: a set number,
  "open", or a saved model's or example's name; "set 1234"/"model 1234"), and
  `shop=` writes the list to buy where export_model writes. A set under test in
  a bench run (`DesignMemory.holds`) is compared by neither.
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
  which rewrites every file in the folder, this one too. Each model's `c` is
  its part count as a builder counts it (`Inventory.count_of_text`): read as
  opening reads it (the parts it carries and its hoses' skins into the library
  first, `CustomParts.take_into`, then flattened), a sticker counted, a hose
  once and a hose's loose ring as itself (`Flex.kind_of_piece`), a ~ bit (a
  motor cable's 2,891 ribbon segments in the Cat D11) and an unknown
  primitive not; it is what the model says when it opens
  (`Inventory.pieces_in`). An assembly LDraw draws as its ~ halves (a shock
  absorber's cylinder and rod) counts none of them. The lots in `p` are only what of its box it uses,
  which left out the 1,679 parts the D11 carries: the card said 2,183, the
  model opened as 6,793 and its box holds 3,853; now 3,868, 3,868 and 3,853.
  `src/dev/part_counts_probe.gd` holds the card, the model opened and its box
  to one count, or the card to saying its box too, on ten sets of every size.
- `part counts probe`: `tools/probe.sh part_counts_probe` (headless, about a
  minute alone). Ten Library sets of every size (the Cat D11, the UCS Falcon,
  two modular buildings, a creator cottage, a castle shop, an ambulance, two
  Technic sets with hoses and stickers, one whose model builds part of its
  set): each read as the card counts it (`Inventory.count_of_text`, before
  the file is opened), then opened, and the two must be one count, and agree
  with the box (`ModelLibrary.box_of`) to a fiftieth or the card say the box
  too. Its table prints drawn, opened, card, box and the card before
  (models.json's lots summed): the D11 6,793 drawn, 3,868, 3,868, 3,853,
  before 2,183.
- `model library` (`tools/library_build.py`, `src/dev/library_covers.gd`): the
  data behind opening any official model from inside the app. Every
  `vendor/omr` model with a cover drawn by the app's own ModelShot (built,
  the three-quarter view, 512 x 384 WebP), staged as the parts store holds it:
  `library/index.json`, `library/omr/<file>.mpd` (LDraw's bytes, licence lines
  kept), `library/covers/<id>.webp`. The index is `{"version": 1, "models":
  [{id, kind, set, name, theme, year, parts, box, file, cover, author, licence,
  page, alternate_of}]}` in that order (the library screen reads it); name,
  set, year, theme, page and parts are models.json's (`c`, the count the model
  opens with), box the set's own inventory summed (`box_of`, 0 for a B-model:
  the card says "N parts · its box B" when they differ by more than a fiftieth,
  `ModelLibrary.parts_words`), author and licence the
  file's own main-model header ("CCAL 2.0" or "CC BY 4.0"); names carry LEGO®
  with its mark. `covers` draws on the GPU lease in drawers of up to 100
  models, each leaving after 20 s when another job waits; 1,575 covers in
  29.7 min, none failed (2026-10-22). 6360-1 is left out: its main model is
  empty, so nothing opens.
- `model library in storage` (`tools/storage_library.py`): the staged
  `library/` into the parts bucket under `library/`, beside `ldraw/parts/`, as
  `application/octet-stream` (the only type the bucket takes); a model or cover
  already there is left, the index sent last over the old one, five minutes'
  cache. 3,151 files, 388 MB (2026-10-22). On 2026-10-26 the index alone went
  up again from `bench/results/library-2026-10-26` (the 10-22 covers linked
  in, models.json rebuilt with each model's `c`), the 3,150 files there
  already left: the D11's card 2,183 to 3,868, 1,032 counts changed, 687
  cards adding their box. Read it back with
  `curl -s <PARTS_URL>library/index.json | sha256sum` against the staged one.
- `/api/collection` (`api/collection.js`, `supabase/collection.sql`,
  `supabase/collection_ops.sql`): GET, POST an op or an import, DELETE.
  Since mybricks2 (2026-11-06) every change is one op made on the row as it
  is kept and written only over the rev it read (a PATCH held to `rev`,
  which a trigger moves on at every write, the older api's too); when
  another write came first it reads again and makes it again, 12 tries. Ops
  (`{"op": ..., "id": ...}`; an id already in `recent`, the last 100, is not
  made again): `lots` (`add` and `remove` as differences, 2,000 lots at
  most, an id required), `set` (`was` → `to`), `keep` and `take_back` (a
  session's lots at the counts shown, any number), `remove_set` (at the
  count shown), `start_over` (at the rev shown). A `set`, `keep`,
  `take_back`, `remove_set` or `start_over` whose count or rev moved on is
  refused 409 with the collection as it is. Each lot and set keeps its
  source (`src`: hand, rebrickable, bricklink_xml; a Rebrickable export and
  a fetch are both `rebrickable`, the person's one list) and a session's
  lots `by` and `chat`; the lot keyed by part, colour, source, by and chat.
  An import in replace mode replaces only its own source's lots and sets
  (and those from before sources were kept, as the live api always did); a
  set typed by hand that a Rebrickable replace lists is kept once, as
  Rebrickable's. An id's reply is kept with it in `recent`, and a repeat is
  answered with it (`again: true`). A session's remove carries `was`, the
  count it was shown. An answer that held a lot at 100,000 says so
  (`done.clamped`, `clamped_lots`). A PUT (the whole collection, as rel-m267
  and desktop 0.17.0 send it to take a set out) is made as `remove_set` when
  it is exactly that: its sets the row's less one set number, its lots
  summed by part and colour the row's; anything else is refused 409 with
  words to update (it carries no read time, so no other difference made
  from it is safe). Colours must be a real colour code. Every import is parsed and
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
  DELETE; `anon` none. Nothing existing changed. `supabase/collection_ops.sql`
  (sequence `collections_rev`, columns `rev` and `recent`, trigger
  `collections_next_rev`, additive only; tried first with `--dry
  --try=tools/collection_ops_try.sql`) **applied 2026-11-06** the same way.

## How to reach it

```sh
godot --path .     # Build > My collection…  ·  P, then What do I need?
godot --path .     # File > Compare two sets or models…: 7140 for A, 9493 for B
curl -s -o /dev/null -w '%{http_code}' https://brickworks.diy/api/collection   # 401 signed out
```

## How to check it

```sh
python3 tools/minitest.py tests/test_collection.py        # a set's expansion against the raw tables
godot --headless --path . --script src/dev/collection_probe.gd
tools/probe.sh collection_arrives_probe   # fetched as they sign in, read first thing with no panel made
# two sets or models compared, and the list to buy (1400x900; PROBE_SIZE=1280x720 too)
tools/probe.sh comparesets_probe -- --shots=DIR
godot --path . --resolution 1400x900 --script src/dev/collection_ui_probe.gd   # needs a display
# building from a set's parts: the counts down, undo, delete, over, saved (1280x720; PROBE_SIZE=1400x900 too)
tools/probe.sh setbin_probe -- --shots=DIR
tools/probe.sh setbin_time_probe        # the biggest sets' bins against the whole library's
# ...and in a browser, a local export with build/web/sets linked to assets/generated/sets
node tools/web/setbin_flow.mjs --url=http://127.0.0.1:9271/ --out=shots/setbin_web
# the endpoint against the real database, two throwaway accounts (.env sourced)
node tools/web/relay_server.mjs 8790 &
node tools/web/collection_probe.mjs --url=http://127.0.0.1:8790
BW_BYPASS=$VERCEL_BYPASS node tools/web/collection_probe.mjs --url=https://<a preview>
# in a real browser, against a preview (tools/deploy.sh without --prod)
BW_BYPASS=$VERCEL_BYPASS node tools/web/collection_flow.mjs --url=https://<a preview>/app --out=shots/collection_web
# loose parts (mybricks): the endpoint's lots, then the app by hand and over MCP, on a relay
node tools/web/mybricks_api.mjs --url=http://127.0.0.1:8790
tools/relay_probe.sh mybricks                     # a window, 1280x720 (PROBE_SIZE=1400x900 too)
# rebuilding the data, after tools/fetch_data.sh or a catalogue change
python3 tools/collection_data.py
python3 tools/collection_data.py --bricklink   # only the index's BrickLink colours, after colors.json
godot --headless --path . --script src/dev/collection_models.gd
node tools/apply_sql.mjs --look        # what the live table is (PG_MODULE=…, see the file)
# the model library: covers (GPU, ~30 min), staged, held to the format, looked at
python3 tools/library_build.py covers && python3 tools/library_build.py stage
python3 tools/library_build.py check && python3 tools/library_build.py sheet --count 60
python3 tools/minitest.py tests/test_library.py
python3 -m http.server 8961 --bind 127.0.0.1 --directory bench/results/library-2026-10-26 &
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
- `comparesets_probe` (at 1400x900 and PROBE_SIZE=1280x720) ends `all good`:
  7140-1 (285 pieces, 1 spare not counted) against 9493-1 (571, 17 spares) is
  21 in both, 264 only in 7140-1 and 550 only in 9493-1 (21 + 264 = 285,
  21 + 550 = 571), each tab's rows summing to its count, Swap turning it round;
  the car (61 pieces) against 7140-1 is 5 in both and 56 to buy, its Pick a
  Brick file 27 lines summing to the 54 pieces with an element number, the 2
  without one named under the buttons; over MCP the same counts in 1 call and
  the same file to the byte; a set under test refused in both. Look at
  `comparesets_both`, `_sets` and `_car`: the sheet inside the window, each
  row's part named.
- `mybricks_api.mjs` ends `every check passed`: an old collection (two sets, a
  CSV, an XML) kept with its sources through twelve lots added, one changed,
  one taken out, a stale count refused 409; a session's twelve apart, its
  remove from a stale count refused; an older app's Remove a set (PUT) taking
  that set out with every mark kept, and from a stale copy refused; taken back
  lot for lot; a Keep held at 100,000 saying so; a Rebrickable replace taking
  its export's lots too and a typed set once; five writes at once all kept;
  one id sent twice made once and answered as the first (an import too);
  malformed changes refused with words; Start over from a stale rev refused.
- the review's repros (`bench/results/mybricks2-2026-11-06/harness/run.sh`):
  R1-R19 against the api before (92043506), mybricks2's first round
  (da2286b8) and after, at 0 and 80 ms a database call, three times each; the
  last line is `0 LOST` after (25 at 92043506, 6 at da2286b8). `harness/review/`
  runs mb2review's own tests (review.mjs, dup.mjs, perf.mjs) on the api after.
- `mybricks_probe` (tools/relay_probe.sh mybricks, with `-- --shots=DIR`) ends
  `all good`: 12 of the car's lots added by hand, each in 3 actions or fewer
  (10 by search, 2 by a photo's answer); What do I need? short by exactly
  their pieces and 12 lots fewer; What can I build? a model made of them at
  100%; each changed and taken out by itself; the same 12 over MCP in 1 call,
  `parts_list which="need"` agreeing in 1; the copy on this device and another
  device's sign-in holding them; Take back leaving the old collection lot for
  lot; Start over asking; then, nothing lost in the window: a count typed then
  Remove pressed at once, a session's count typed then Keep pressed at once, a
  reply for an account signed out dropped, two MCP sessions naming no chat
  kept apart, a session's remove from a count changed elsewhere refused, a
  read answered after a later Add leaving the Add, a session's change and the
  window's made in turn, a change answered for a signed-out account told it
  may have been made; then rel-m267's and desktop 0.17.0's own collection code
  (from git) reading every lot, importing to Rebrickable's lot, and taking a
  set out with every mark kept, refused from a stale copy. Look at the pictures: `mybricks_row`, `_like`,
  `_loose`, `_need`, `_build`, `_claude`, `_taken_back`.
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
  fetched from the served store, and three models (46, 654 and 9,163 parts)
  fetched byte for byte as LDraw has them, opened with the app's reader, their
  lots as models.json lists them (46, 635, 8,689) and their part count as the
  card says it, models.json's `c` and the index's `parts` (2026-10-26; it held
  the lots to the index before, which failed 2 of 3 once the index carried the
  builder's count); `--recount` finds every model's lots and count as
  models.json says.

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
