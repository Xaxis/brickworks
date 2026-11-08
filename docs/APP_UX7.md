# The app against the best tools, round seven

Written 2026-11-08 by appux7 against `pre261` at `e34945098`. The web was
measured on rel-m276 (`de20e50df`), live then. [APP_UX.md](APP_UX.md) to
[APP_UX6.md](APP_UX6.md) planned rounds one to six. Of round six's
twenty-three units, fifteen are merged:
- in `pre261` at this commit: timelinefit, mcpsee3, weighsure, booklook
  (with booklook2), mysets, comparesets, words6, makepart2, print3mf,
  palettes, twist, mechdet, and realjoints3, which was reverted and came
  back as realjoints4;
- after this snapshot: pullkept (`a5a0514c8`), and mosaic2 as mosaic3
  (`f102cbfa5`).

househang, outside the plan, also merged after it (`e1712f156`).

Eight are not merged:
- localbricks is being rebuilt for signed-in people only;
- drive is running;
- stepnames started at 16:47Z today;
- modsteps, video2, edges, watchfile and panelside wait on the files of
  units still running.

Also in flight: lights (its third review says SHIP), keeptext5, and
smallwords (two word faults mosaic3 found); then intomodel3 and
lightpaths.

This file measures the app a seventh time, by hand and through a person's
own Claude. It says where the field still does better, and plans round
seven in waves the lead can start at once.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second. The desktop
download says "Coming soon", so the browser is the way in, and the web's
numbers weigh more than before. [COMPETITIVE.md](COMPETITIVE.md) is the
feature matrix, [ROADMAP.md](ROADMAP.md) the designer's quality and
[SOCIAL.md](SOCIAL.md) the site. None is repeated or edited here.

## How it was made

- **The walk, a seventh time.** appux6's script and tasks, run on the GPU
  at 1280 x 720 and 1400 x 900, from a locked snapshot of this commit,
  imported first ([app_ux7/appux_walk.gd](app_ux7/appux_walk.gd)). One
  section was added after the old ones, so their numbers still compare:
  `round6`, which covers:
  - the wall's weight just built, with a part in hand and after a turn;
  - the car's weight and size, and three parts' size;
  - everything open with the timeline;
  - Page setup's tabs;
  - Compare two sets or models;
  - My collection's set by its photo;
  - Export's 3MF;
  - Make a part's families;
  - the bin's Palettes;
  - the bin's "plate 1 x 1", "1x1 plate" and "87087";
  - the keys sheet's "cut away";
  - the keys round six's commands have.

  Every picture it took (87 and 87) was looked at.
- **The same tasks over MCP,** as the owner's Claude does them
  ([app_ux7/mcp_walk/](app_ux7/mcp_walk/)):
  - the app in a window of its own, with its MCP port open and its own
    Documents and Pictures;
  - **signed in this time.** `run.sh` opens a throwaway account on the
    live site through the relay (`relay_account.mjs open`), starts the app
    `--signed-in` against brickworks.diy's API, and closes the account at
    the end (`account_close.txt`). It holds a slot of the live database
    (`live_db.sh`). Round six's collection tasks need an account, and
    round five's were refused for want of one;
  - the walk's 30 words, and "1x4 brick", through `search_parts`;
  - then Claude Code on the subscription: `claude -p`, the Brickworks
    server alone, `--tools ""`, `--restricted`, no API key.
    All 45 streams say `apiKeySource: none`. The account was deleted at
    the end (`account_close.txt`: deleted, exit 0).

  There was one turn per task: APP_UX6's 37 tasks, then eight for what
  round six added ([prompts_round6.txt](app_ux7/mcp_walk/prompts_round6.txt)).
  Calls are counted from the sessions' own streams
  ([calls.txt](app_ux7/mcp_walk/calls.txt)).
- **Round six's bars** were read off each merged unit's probe, run today
  from the same snapshot, at the sizes their headers give:
  - headless, one after another under `heavy`: `print3mf`, `element`,
    `no_size`, `animals`, and `harvest` over realjoints3's 1,056 real
    sub-models;
  - windowed, one at a time on the GPU: `timelinefit` (1280 x 720 and
    1400 x 900) and `timelinefit_tablet`, `mcpsee3`, `weighsure`,
    `booklook`, `comparesets`, `words6`, `palettes`, `twist`, and
    `grab --only=groups`;
  - `mysets` through `relay_probe.sh`, signed in. It waited its hour for
    a slot of the live database behind rel-m277's preview checks, and did
    not run.

  pullkept's bar is from its report and pkreview's third review, because
  it merged after the snapshot.
- **The web:** `load_check` on live brickworks.diy (rel-m276), on
  broadband, with two cold and two warm loads and a part picked from the
  bin. It was run again at a phone's 390 x 844 (3x, touch).
- **The field,** from each tool's help pages, release notes, changelogs,
  store listings, READMEs and commits as of 8 November 2026 (Sources).
  APP_UX2's to APP_UX6's lists and COMPETITIVE were read again, and only
  what they did not cover is new here. Round six's own "Next", the lead's
  candidates in `queue.md`, and SOCIAL's and ROADMAP's open rows are
  folded in.
- **Not run:**
  - Studio itself (studioside, the owner's);
  - the in-app assistant on a key (it spends money);
  - claude.ai's connector.
- **The box was shared** with the units' probes and the next train's
  preview flows. The load was 24 to 42
  through the walk and 7 to 40 through the probes. Seconds are stretched
  by it; counts are not.

## What the walk measured, seven times

The first four rounds' figures are in APP_UX4 to APP_UX6.

| act | appux5 (1280 / 1400) | appux6 (1280 / 1400) | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|---|
| desktop start, the first 120 frames | 9.1 / 8.9 s | 6.4 / 12.9 s | 8.2 s (load 24) | 8.3 s (load 42) | walk |
| bin tiles in sight on the first open | 24 / 42 | 24 / 42 | 24, every one named | 42, every one named | walk `counts` |
| Properties with a part selected | every field; the bin gives way / beside it | the same | every field in sight; the bin gives way | every field, the bin beside it | walk `turns` |
| keys sheet (F1), rows in sight | 32 / 46 of 139 | 32 / 46 of 157 | 32 of 157 | 46 of 157 | walk `counts` |
| commands with a key | 98 of 209 | 116 of 221 | 116 of 222 | the same | walk `counts` |
| Render from the model by keys | 5 | 1: F9 | 1: F9 | 1 | walk `round5` |
| the tallest menu, rows (height) | Edit 24 (464) | Edit 24 (464); View 20 (412) | **File 24 (482)**, with Compare two sets or models; Edit 24 (464); none scrolls | the same | walk `menus` |
| the part menu | 26 | 26 | 26 | 26 | walk `menus` |
| a wall of eight 1 x 4s from the search | 20 events, 2.5 / 4.5 s | 20, 2.9 / 3.3 s | 20, 3.4 s (2.8 s the second time) | 20, 4.7 s (3.9 s) | walk `wall`, `round6` |
| the ghost following the pointer, 3 frames a move | 33.9, worst 51.4 / 53.9, worst 82.5 ms | 37.9, worst 68.4 / 44.4, worst 73.7 | 47.8, worst 65.9 (46.9, 68.9) | 62.1, worst 82.8 (47.9, 59.2) | walk `wall`, `round6` |
| R on a brick in a wall, 15° step | in hand, down in 3 | in hand, down after 2 events, 15.0° | the same | the same | walk `turns` |
| a brick alone, 3 x R at 15° | 45° | 45° | 45° | 45° | walk `dialogs` |
| panels and dialogs | 22 of 24 | 22 of 24, 0.9 to 2.9 / 1.0 to 4.3 s | 22 of 24, 0.9 to 2.1 s; Compare with a save and Pattern greyed (no save, nothing selected) | 22 of 24, 1.0 to 2.5 s | walk `dialogs` |
| search, 30 words | 27 | 27 | 27: the same three not first | the same | walk `search` |
| three selected parts painted Red | 1 key | 1 key | 1 key | 1 key | walk `round2` |
| a 2 x 4 plate split, and merged back | 1 key each | 1 key each | 1 key each | the same | walk `round2` |
| a second view, the assistant open | F8: 490 / 385 px | F8: 490 / 385 px | F8: 490 px | F8: 385 px | walk `round2` |
| a part to the last step | 4 presses | 4 | 4 | 4 | walk `round3` |
| Settings' language | four | four | English, Deutsch, Français, Español | the same | walk `round3` |
| Like this on a 2 x 4 brick after "1x4 brick", Stress open | Plate 2 x 4 seventh | Plate 2 x 4 seventh | **not reached: the Like this chip is out of sight** ([picture](app_ux7/like_this_out_of_sight_1280x720.webp); Found on the way) | Plate 2 x 4 seventh | walk `round3` |
| the status bar, the car open, nothing selected | "61 bricks · stands up · 52 g" | and "4½ × 10.8 studs, 15 plates high · 3.6 × 8.64 × 4.96 cm" | **"4.5 × 10.8 studs, 15 plates high · 3.60 × 8.64 × 4.96 cm"** (weighsure) | the same | walk `round6` |
| three parts of the car selected | | "3.8 × 7.8 studs, 4½ plates high · 3.04 × 6.24 × 1.44 cm" | **"3.8 × 7.8 studs, 4.5 plates high · 3.04 × 6.24 × 1.44 cm"** | the same | walk `round6` |
| the wall's weight: just built, a part in hand, after a turn | | 8, 13, 12 g / 7, 13, 12 g | **13, 13, 13 g, at every frame read** (weighsure) | the same | walk `round6` |
| the car's weight, every frame read | | 52 g | 52 g | 52 g | walk `round6` |
| Cut away by a box | 0.8 / 1.3 s; no keys | 1.2 s; Alt+X, Alt+Z, Alt+Y | 1.1 s, the same keys | 1.1 s | walk `round4` |
| Cut away's strip, with Stress open | the × under a column | 5 of 5 buttons inside the model's room | 5 of 5 | 5 of 5 | walk `round5` |
| the timeline with Properties (a wheel rim) and Stress open | | **past the window's right edge** | **0 past the edge; Instructions and Done inside; the model's room 639 units** ([picture](app_ux7/timeline_in_the_window_1280x720.webp); timelinefit) | 0; room 769 | walk `round6` |
| the booklet's page set up | fixed 269 x 199 | Ctrl+Shift+B, 1 press; four papers, both ways up | **and three tabs: Page, Cover, Steps** ([picture](app_ux7/page_setup_cover_1280x720.webp); booklook) | the same | walk `round6` |
| Stud directions on the car | | up 45, to the front 4, no studs 12; no key | the same | the same | walk `round5` |
| a view saved, turned away 35°, brought back | | Alt+V, Return; back 0.000° and 0.000 LDU off | the same | the same | walk `round5` |
| My collection | sets and lists | and Loose parts, in sight | **and a set by its photo, in sight** (mysets) | the same | walk `round6` |
| comparing two sets or models | | Compare with a save only | **Compare two sets or models…, usable with no save** ([picture](app_ux7/compare_two_sets_1400x900.webp); comparesets); no key | the same | walk `round6` |
| Export, 3D model | .glb, .gltf, .obj, .stl | the same | **and .3mf** (print3mf); no key | the same | walk `round6` |
| Make a part's families | brick, slope, inverted, round, curved, bracket, technic | the same | **and clip, bar, wedge** (makepart2) | the same | walk `round6` |
| the bin's own palettes | Favourites only | the same | the bin had given way to Properties | **Palettes, a chip of its own; "No palettes yet: New palette makes one, and Add fills it from the model"** ([picture](app_ux7/palettes_1400x900.webp); palettes) | walk `round6` |
| the bin's "plate 1 x 1" and "1x1 plate" | 6141 first | 6141 first | the bin had given way | **3024 first, both** (words6) | walk `round6` |
| 87087's tooltip | "1 x 2" | "1 x 2" | the bin had given way | **"1 x 1, a stud on one side, 1 brick"** (words6) | walk `round6` |
| the keys sheet's "cut away" | the box, sphere and cylinder not found | the same | **11 rows: the box, the sphere and the cylinder among them** ([picture](app_ux7/keys_cut_away_1280x720.webp); words6) | **F1 did nothing** after the bin's search (Found on the way) | walk `round6` |
| the parts list's shops | BrickLink, Rebrickable, Pick a Brick | the same; Pick a Brick Alt+L | the same | the same | walk `round4` |
| File, Import, Into this model… | offered | not offered | not offered: intomodel3 waits on keeptext5 | the same | walk `round4` |
| lights | | not offered | not offered: lights is not merged | the same | walk `round5` |

The search's three that are not first are the walk's own answers, as
before:
- "jumper" lists 3794b sixth, after the newer 15573.
- "macaroni" lists 25269 fourteenth.
- "bracket" has 99781 fourth.

These commands have no key: Compare two sets or models, Export 3D model,
Make a part, My collection and its What do I need? and What can I build?,
Stud directions, Render each saved view, and Stress. 106 of 222 commands
have none.

**Found on the way:**
- **Like this is out of sight on a laptop with Stress open**
  ([picture](app_ux7/like_this_out_of_sight_1280x720.webp)). At
  1280 x 720 with Stress's panel open, the bin is about 300 px wide. Its
  shelf chips get one row in a scrolling window, and that row holds All,
  Recent, Favourites and Palettes. Techniques, Fits and Like this sit in
  rows below it, with only a thin scroll bar to say so. The walk's click
  on Like this missed, and the bin kept "1x4 brick". In round six the same
  act gave Plate 2 x 4 seventh, because the bin was 450 px wide and had no
  Palettes chip.
  - `parts_bin.gd` `_fit_palette` gives the category chips two rows, or
    one in a column shorter than `SHORT`.
  - Two merged units met here: timelinefit gives Stress's column its
    width out of the bin's (`_fit_bin`), and palettes added a chip.
- **Keys do nothing while a text field has the focus.** At 1400 x 900 the
  walk typed "87087" in the bin's search, then pressed F1, and the keys
  sheet did not open. The cause is `main.gd` `_unhandled_key_input`
  (lines 10578 to 10581): while a LineEdit or TextEdit has the focus, it
  returns on every key. Its comment says it is there so that a
  single-letter shortcut never fires while someone types, but it takes F1,
  F9, Ctrl+S, Ctrl+Shift+B and Alt+X with it. A person who searches the
  bin and then presses a key gets nothing, and no word why. At 1280 x 720
  the bin had given way to Properties, the search never had the focus,
  and F1 found 11 rows.
- **The step number's colour reads as unset.** Page setup's Steps tab shows
  the number's colour as a swatch. Its default is near black (21, 25, 30),
  on the dark dialog with no border, so the swatch looks empty
  (`page_setup_dialog.gd` `_colour_field`).
- **The walk's own:**
  - At 1280 x 720 the bin had given way to Properties, so the bin's
    `round6` lines read the last search there (3001). The 1400 x 900 lines
    are the measure.
  - The everything-open act had the bin and the assistant closed:
    `set_assistant` turns the assistant on without opening its column, and
    the bin had given way. timelinefit's own probe opens all five, and
    holds (below).
  - The first build's offer comes back after Help › Take the tour, by
    design, as in round six.
  - Both Godots quit cleanly (exit 0).

**The web** (`load_check`, broadband, live):

| | appux5 (live rel-m266, load 32 to 41) | appux6 (live rel-m268, load 28 to 30) | now: live rel-m276, load 18 to 31 | from |
|---|---|---|---|---|
| first visit, cold, to working | 17.2 s | 12.0 s | **10.2 s** (10.2 and 10.3) | `load_check` |
| warm | 11.0 s | 7.6 s | **6.0 s** (6.2 and 5.7) | `load_check` |
| main thread, cold | 9.4 s | 6.9 s | 5.7 s | `load_check` |
| the engine's banner, cold | 5.2 s | 4.6 s | 4.3 s | `load_check` |
| the scripts' compile, cold and warm | 4.4 s | 2.8 s and 2.8 s | **2.2 s and 2.2 s** | `load_check` |
| app ready (the scripts done), cold | 9.3 to 12.0 s | 8.0 to 8.2 s | 7.0 s | `load_check` |
| a part from the bin to its ghost | 1,538 and 552 cold, 551 and 431 warm | 249 and 389 cold, 139 and 283 warm | 151 and 214 cold; **1,426** and 346 warm | `load_check --pick` |
| bytes before working | 16.42 MB | 16.51 MB | 16.71 MB | `load_check` |
| a phone, 390 x 844: first frame, cold and warm | 19.9 and 10.7 s | 12.1 and 7.7 s | **10.8 and 6.7 s** (10.5 and 11.2; 6.0 and 7.5), at a load of 17 to 41 | `load_check`, a phone's viewport |

A cold visit is 1.8 s faster than round six's, and a warm one 1.6 s. The
compile is 0.6 s shorter both ways, and it is still the same warm as cold.
A13's bar (10 s cold, 4 s warm) is not met: cold is 0.2 s over, warm 2.0.

On a phone the first frame came 1.3 s sooner cold and 1.0 s sooner warm
than in round six. `load_check`'s "working" never comes there, because a
phone keeps the bin behind a button, so its run says FAIL on that line
alone, as in round six; the first frame is the measure.

One warm pick took 1,426 ms, with no part file fetched for it. The other
three took 151 to 346. It came while the rest of the parts were still
coming in. It was one run in four, and it is not explained here.

## Over MCP: the walk's tasks as the owner's Claude does them

**The search** answers a session as the bin answers a person. Each of
the walk's 30 words put the same part first in both, in 4 to 68 ms a
word. "1x4 brick" put 3010 first, and "plate 1 x 1" and "1x1 plate" now
put 3024 first, as the bin does (words6).

**APP_UX5's thirteen tasks, a third time:**

| task | APP_UX6: calls, time | now: calls, time | what the session did |
|---|---|---|---|
| clear, and a red wall of eight 1 x 4s, half a brick along | 3, 13 s | **2**, 11 s | clear, then `submit_design` with no check first; it explained the stepped ends and offered 1 x 2s for flush ones |
| turn one brick of the top row 15° where it stands | 1, 14 s, refused | 1, 13 s, refused | `check_design` with the turn: it hits its neighbours; nothing changed |
| paint three bottom bricks blue | 1, 4 s | 1, 5 s | it chose which three, and said so |
| a 2 x 4 plate, split into eight 1 x 1s | 2, 9 s | 2, 10 s | `edit_model`, then `split_parts` |
| three 1 x 4 plates stacked, merged into a brick | 2, 8 s | 2, 7 s | `merge_parts` |
| a 3 x 6 wing, the left one, and its mirror image | 5, 28 s | 5, 17 s | `mirror_parts`: 54384 became 54383 |
| a beam 7 standing, a pin in its second hole | 8, 74 s | 11, 87 s | **it built a stand again**, six parts to hold the beam up, and said so. The session, not the app |
| the angle between the beam's holes and the wall | 0, 2 s | 0, 5 s | 0°, from the beam it had built |
| move the top row three steps later | 4, 15 s | **3**, 12 s | `edit_steps` `to` for all four bricks; it found the fourth on its own step and kept the row together |
| render a picture | 2, 10 s | 2, 9 s | `render_model` and its job |
| a side pod of five parts, in words | 7, 33 s | **5**, 39 s | `attachment_points` once, then `submit_design` twice and a look |
| the pod's mirror image beside it | 1, 7 s | 1, 10 s | `mirror_parts`: 41770 became 41769 |
| a 2 x 2 slope split into 1-wide slopes | 2, 7 s | 2, 7 s | `split_parts`: two 3040 |

The thirteen took **37 calls in 3.9 minutes**, against 38 in 3.7. The
beam's unasked stand is 11 of them.

**Round three's own:**

| task | APP_UX6 | now | what the session did |
|---|---|---|---|
| a short video of the model built up | 2, 42 s | 2, 32 s | `render_model` build and its job; it described six of its frames |
| parts like the headlight brick, three picked | 1, 10 s | 2, 13 s | `search_parts` `like` 4070, once with a stray query; 87087, 26604 and 3005, each with a reason |
| what step the window shows, the part in hand | 1, 3 s | 1, 3 s | `in_view` |
| the wing pulled out, colour guides, the first page | 5, 13 s | 6, 18 s | `edit_booklet` pull by brick number, both drawn, and both pages looked at |
| a picture at the best quality, and how it was lit | 2, 13 s | 2, 11 s | Best: path-traced |

**Round four's own:**

| task | APP_UX6 | now | what the session did |
|---|---|---|---|
| the pods from three sides: true mirror images? | 2, 11 s | 2, 12 s | `view_board` and `look_at_model`: a table, pair by pair |
| only the two headlight bricks picked out | 2, 8 s, the quoted number refused | **1**, 7 s | **`highlight` with the quoted part number, taken** (mcpsee3) |
| page 2 of the instructions as a person sees it | 1, 11 s | 1, 11 s | `booklet_page` |
| a 4 x 3 x 2 block of 2 x 2 bricks | 2, 10 s | 2, 10 s | one brick, then `pattern_parts` |
| a Pick a Brick file, and what it left out | 1, 8 s | 1, 8 s | 36 pieces, none left out |
| save as Pods | 1, 6 s | 1, 5 s | `save_model`; it mentioned the 16 loose pieces |
| a green 16 x 16 plate, Pods into it, whole | 0, 10 s | 3, 14 s | the plate, then "I can't import a saved model into another one": intomodel3 waits on keeptext5. It also found Pods 6 studs too wide for the plate |
| how big, and how heavy | 1, 5 s | 1, 5 s | `in_view` |
| a closed oval of 9V track | 9, 35 s | **7**, 31 s | 20 pieces joined end to end by `attach`, then `measure` on the last joint |

**Round five's own** (the track, then Pods again):

| task | APP_UX6 | now | what the session did |
|---|---|---|---|
| how big is the oval, how heavy | 1, 5 s | 1, 4 s | `in_view`: 97.4 x 71.8 cm, about 429 g |
| open Pods; which way every part's studs point | 3, 11 s | 3, 9 s | `view_board` `studs`: up 32 |
| every headlight brick picked out | 3, 12 s, the quoted number refused | **2**, 6 s | the quoted `highlight` taken, then `look_at_model` for where each is |
| save this view as "Three quarter", then a picture from it | 2, 13 s, no tool | **3**, 11 s | **`save_view`**, then `render_model` from it and its job. mcpsee3's bar said 1 call; a render is a job, so it is 2 at least |
| A4, upright, a pale blue page; page 1 as it prints | 2, 14 s | 2, 11 s | `page_setup`, `booklet_page` |
| a short video of the build, and what happens in it | 4, 115 s | **2**, 37 s | `render_model` and one wait on its job |
| check for problems, show where each is | 4, 18 s | 4, 13 s | `check_design`, `weakest_joints`, `look_at_model`, `view_board` |
| pull out brick 3 of the first step; show the page | 4, 16 s | 4, 15 s | step 1 holds one part, so it pulled brick 3 in step 2 and said why. **It found the old wing pull no longer drawn** (pullkept, merged after the snapshot, keeps it) |
| add my loose bricks to my collection; what would I still need | 2, 9 s, refused: signed out | 2, 9 s, **done** | `edit_collection` add, signed in, then `parts_list` need |
| take back what you added | 0, 4 s, nothing to take | 2, 8 s, **refused** | "The app now lists them as added by a different chat". Each turn is a new connection, so the app counts the lots as another chat's (gap 10) |

**Round six's own:**

| task | calls, time | what the session did |
|---|---|---|
| a cover titled "Twin Pods", a footer, the parts boxes framed in dark blue; the cover as it prints | **2**, 9 s | `page_setup` with title, subtitle, footer and `box_frame`, then `booklet_page 1` |
| 7140 and 9493 in common, and a Pick a Brick list to build 9493 from 7140 | **1**, 12 s | `parts_list` `compare` with `shop`: 21 in 9 lots in common, and the file |
| the open model from 7140's parts | **1**, 8 s | `compare` against the open model: none of Pods' 36 in their colours. Its "a few of the shapes are in 7140" read only the 30 of 124 lots the answer lists by default |
| export for a colour printer; how many colours | **1**, 6 s | `export_model` 3mf: 3 colours, an object each |
| a clip plate, a 4-long bar and a pair of wedge plates | 4, 26 s | **real parts**, 15712, 30374, 41770 and 41769, where a made part was not needed: an expert's answer |
| 7140 in my collection, two white 1 x 2 plates marked missing | 1, 9 s, **refused** | it found 7140 has no white 1 x 2 plates, and said "I can't add a set to your collection or mark parts of one missing" (keptbuilt, after localbricks' `missing`) |
| the pods' parts kept as a palette, "Pod parts" | 1, 8 s, **refused** | `read_guide`, then "none of my tools can create or save one" (mcppalettes) |
| a plain 1 x 1 plate, and the 1 x 1 brick with a stud on its side | 0, 4 s | from what it had read before: 3024, and 87087 "the app counts its footprint as 1 x 2 studs" (mcpwords) |

All 45 tasks took **105 calls in 10.3 minutes** of the sessions' own
time. APP_UX6's 37 took 94 calls today, against 93.

Where a session still needed more than the window, or guessed:
1. **A resumed chat cannot take back what it added.** The lots and edits
   are its own, but each new connection is a new chat to the app. The
   session told the person to take them back by hand (takeback).
2. **No tool keeps a palette** (mcppalettes), and **none adds a set or
   marks its missing parts** (keptbuilt).
3. **A side-stud brick reads 1 x 2** to a session (mcpwords).
4. **Nothing puts one saved model into another**: intomodel3, in
   flight.
5. A compare's default 30 lots left the session reading part of the
   list. The answer says `limit=` for more, and the session did not ask
   for it.

## Round six, item by item

Each merged unit's bar, read off its own probe today on the snapshot.
"Met" means every line of the bar passed today; the numbers are today's.

| unit | its bar | today |
|---|---|---|
| timelinefit | with every panel open, 0 px past the right edge at 1280 x 720, 1400 x 900 and 1024 x 768; Done and Instructions answer a click; the model's room 400 px or more | **met**: 30 checks and 16 on the tablet, none failed. 0 px at all three sizes; the room 586 and 588, 706 and 707, and 617 px; Done and Instructions answer. The walk: 0 past the edge, room 639 and 769 |
| mcpsee3 | `save_view` in 1 call, back within 0.1° and 0.1 LDU; `"4070"` picks exactly #6 and #11 with or without quotes; v3 and v4 in 1 call each over MCP (said, not gated) | **met** for its gated lines: 17 checks at 1400 x 900, none failed; the view back 0.0000; the three quote forms pick #6 and #11. **Not met** over MCP: v3 took 2 calls and v4 3, because a render is a job |
| weighsure | one weight in every frame; the car 52 g from its first number; the same weight with all shapes or none; the size in one style | **met**: 28 checks. The wall 13 g in 441 of 441 frames; the car 52 g in 364 of 364; 19 of 19 models weigh the same with no shapes; 0 of 53 sizes mix a fraction with a decimal. The walk: 13, 13, 13 g |
| booklook (and booklook2) | the person's cover, header, footer, box frame and colours read back off the PNG and the PDF; the default booklet unchanged to the pixel; a style moved in 2 actions | **met**: 160 checks, none failed. The pixel line against the commit before is from its report (0 px). The walk: three tabs. The PDF's "?" for non-Latin letters was outside the bar (pdfcid) |
| mysets | a set from a box photo in 3 actions; 7140 with 12 missing lists exactly 12, and 5 added loose leaves 7; an older collection unchanged | **not run today**: `relay_probe` waited its hour for a slot of the live database, held by rel-m277's preview checks, and never started (no account was made). Its report: 55 checks at each size and the API's 29 of 29. The walk: a set by its photo, in sight. Over MCP, v9 added lots signed in. Build from still offers marked-missing parts, which localbricks takes |
| comparesets | 7140 against 9493 adds up; the car against 7140 gives a Pick a Brick to-buy file; 1 call over MCP | **met**: 38 checks. 21 in both, 264 only in 7140, 550 only in 9493; the car 56 to buy. Over MCP, w2 and w3 in 1 call each |
| words6 | "plate 1 x 1" puts 3024 first; the walk's 30 words keep their firsts; 87087 and 4733 read their side studs; "cut away" finds the box, sphere and cylinder | **met**: 25 checks. The walk: 3024 first for both words; 87087 "1 x 1, a stud on one side, 1 brick"; 11 rows for "cut away". Over MCP 87087 still reads 1 x 2, outside its bar (mcpwords) |
| makepart2 | a clip, a bar and wedge plates within 0.01 LDU of the parts they copy; a made clip on a made bar; each in 1 MCP call | **met**: `element`, 214 checks, none failed. The walk: clip, bar and wedge offered. Outside the bar: 54383's chamfer and the clip's seat (makepart3) |
| realjoints3, then realjoints4 | real sub-models from 957 to 963 or more, none newly refused; each named pair by hand and over MCP | **met**: `harvest` 963 of 1,056 (refused: overlap 24, not held 34, floating 27, collisions 8); `animals` 63 of 63 by hand and 27 of 27 saddles, the worst 0.00 LDU. The dish on a round plate and four sub-models 2 LDU off are open (seatfix) |
| print3mf | one object a colour with its RGB; a strict reader passes; every triangle faces out; the size within 0.1 mm; GLB and STL unchanged | **met**: 25 checks. 7 objects; the XSD, the rules and lib3mf strict all clean; 24,909 of 24,921 triangles out, 0 in; 0.0000 mm off; the dialog's and `export_model`'s file the same to the byte. GLB and STL sameness is from its report. **0 of 7 objects manifold**, outside the bar (print3mf2) |
| palettes | 12 parts and a sub-assembly, named, kept, and opened in another model in 2 actions; Favourites unchanged | **met**: 45 checks at 1280 x 720. The walk at 1400 x 900: the chip and its empty state. At 1280 x 720 with Stress open the chip row hides Like this (binrow); no MCP tool (mcppalettes) |
| twist | at 390 x 844, two fingers turned 90° turn the view 90° ±5°; a pinch and a slide within 1% | **met**: 26 checks. 90.0°, the tilt 26.00° before and after; a pinch 0.3333 against 0.3333 |
| mechdet | 0 'det == 0' errors in `grab`; its results and the steering unchanged | **met** for what ran: `grab --only=groups`, 4 checks, 0 errors, the steering 30° of 30; `no_size` 14 checks. The full 25-minute `grab` was not run |
| pullkept | every per-step booklet line (pull, colours, turn, zoom, notes, place, page) read back to its step on open; Pods' step 1 pulls 41770a and 41769a as saved; every booklet line kept over open, save and open | merged after the snapshot (`a5a0514c8`): its report and pkreview's third review (SHIP), 36 saves and 27 step lists the same to the byte. Over MCP, v8 found the old pull gone on the snapshot, which is the bug it fixes |

**Round six's units not merged:**
- localbricks is being rebuilt for signed-in people only, after lbreview's
  FIX FIRST.
- drive is green at 1400 x 900 (the link in sight in 558 frames, 0 out).
- stepnames started at 16:47Z; pkreview3's undo label went into it.
- modsteps waits on stepnames; video2 and edges on lights; watchfile on
  keeptext5; panelside on watchfile.

**Merged beyond the plan:** playweb (the link moving in 1,218 ms on a
laptop; its longer frames are fetchparts), comingsoon, techfix, artfix,
bintech, and househang, after the snapshot (`e1712f156`).

mosaic3 (mosaic2, stopped after 19 hours, rebuilt) merged after the
snapshot. Its bar is from its report: the car's mixed plate sizes cut its
plates by 32.3% (bar 30%), with 0 studs different.

Round six planned 23 units, and fifteen merged. **Eleven met every line
of their bars that ran today.** Three lines of theirs are from their
reports, because they compare with the commit before or take 25 minutes:
booklook's pixels, print3mf's GLB and STL, and mechdet's full `grab`.
mcpsee3 met its gated lines and missed its ungated one. mysets, pullkept
and mosaic3 are from their reports. What they left open is planned below:
binrow, mcppalettes, mcpwords, makepart3, print3mf2, pdfcid and seatfix.

## What the field does that Brickworks does not, yet

The latest versions, as of 8 November 2026:
- **Studio 2.26.10_1** (27 October), unchanged. Its help centre lists 125
  articles, none edited after 25 September. bricklink.com was down for
  maintenance again, so the version is from Wikipedia's page.
- **LeoCAD 26.09**, and a continuous build of 5 November: Qt
  compatibility work and the rotation-axes fix APP_UX5 listed.
- **StudWorx**: its 6 November release was republished on 8 November with
  one new notice; no feature changed.
- **LDCad 1.7 Beta 2b**; 2c is still not out. **Bricksmith 3.1** (2022).
  **LPub3D 2.4.9** (January 2025).
- **Mecabricks**: no release.
- **Phone apps:**
  - LEGO Builder 4.3.11 and Brickit 5.8.0, unchanged;
  - BrickBack 2026.11.7 and BrickBuilder AI 1.0.5;
  - **Brickium 1.4** (3 November), new to these rounds;
  - Bricksee 5.4, Brickly Scan 1.3.2, Pileometer;
  - BUF3D Lite 1.261103 and Buf3D+ 1.261024; brckd 1.0.
- **AI and agent tools:**
  - the Brickognize API 1.0.0, unchanged;
  - ldraw-mecha v0.5.0, Kinebrick (no release), brick-tidy (no release);
  - **mesh2brick v1.3.0**, new;
  - **lego-build-video**, **brick-build-guide-kit**, **Brickyard**,
    **BrickCheck** and **Brickfolio**, all new.
- The LDraw forum has no thread after 4 November, and Hacker News and
  arXiv nothing for a builder. Rebrickable refused readers (403) again;
  its help pages were read through the Wayback Machine, and its API
  description still serves.

Each list is ranked by how much a person building would feel it. Each
item was checked against `shell.gd`'s commands, `tools/mcp_tools.json`
and the files named.

**Phone and web tools**
1. **Sets kept built** (Rebrickable's Assembled Lists; Brickium; Brickly
   Scan). A set or model left built is marked so, and its parts are left
   out of what can be built until it is taken apart. Rebrickable also
   lets a set list be left out of Build's sums.
   - Brickworks: `collection.gd` `pool()` counts every set's parts, less
     only those marked missing. `rebrickable_account.gd` reads the
     person's sets and parts with no per-list flag. Neither
     `edit_collection` nor the dialog has a "built" state.
   - So a person with a full display shelf is told they can build things
     from bricks that are glued into Hogwarts.
2. **Told when a long design is done** (Brickium 1.4). Once the request is
   accepted, the person can leave the screen; a notification says when it
   is finished. Brickworks' window title is always the model's name
   (`main.gd`), `web/` never calls the browser's Notification API, and
   nothing asks the window for attention. A design takes minutes ("a
   house took 11 minutes" on the assistant's own page), and so do Best
   renders and build videos.
3. **Where each part is kept** (Pileometer, sold with a storage system and
   "parts location guidance"; Brickfolio, a location per set). Brickworks'
   lots hold part, colour, count and where they came from
   (`collection.gd`). No list can say "drawer B3".
4. **A New parts shelf** (Studio's default palettes). Brickworks' bin has
   Recent, Favourites, Palettes, Techniques, Fits and Like this
   (`parts_bin.gd`), and `catalogue.json` already holds the years each
   part was made.
5. **Line art and comic looks** (BUF3D Lite 1.261103): the model drawn as
   lines to ink or colour over, with halftone and a transparent picture.
   `src/render/` and Render have no such look. The edges unit, waiting on
   lights, adds the lines it needs.
6. **A soundtrack under the build film** (lego-build-video, cut to the
   beat). `build_render.gd` and `render_output.gd` write MP4 and WebP with
   no sound. The person's own music needs nobody; music shipped with
   Brickworks needs a licence, which is the owner's.
7. Smaller:
   - **searching the step list** by part number, name or colour (Studio);
     `steps_bar.gd` has no filter, and `select_find` selects in the view
     only;
   - **how rare a part is in a colour** (BrickMissing: in three sets or
     fewer); `part_library.gd` counts sets per part, not per colour;
   - **a dragged part carries what rests on it**, Shift to move it alone
     (Brickyard); Brickworks moves the selection, and `select_connected`
     exists;
   - **checking a set piece by piece with others** (BrickCheck); low
     while sets with missing parts are one person's;
   - **both halves of a dual-moulded part recoloured** (Mecabricks'
     forum); the minifigure builder pairs dual-moulded legs, and nothing
     else has a second colour.

**The desktop tools** have nothing new since 7 November. Studio's articles
that no earlier round cited were checked, and each is already in
Brickworks: Step view (`booklet_this_view`), the Move tool's own axes, the
Paint tool, Grid, editing inside a sub-model with X-ray and isolate, a set
brought into the view (`set_bin.gd`), backup files (Versions), and key
rebinding. LPub3D's length rings are the booklet's 1:1 guide.

Checked and **not gaps:**
- StudWorx's 8 November notice (an opened model's new parts start a new
  step): `instructions.gd` `_authored_plan` already does it.
- mesh2brick 1.3: its size in centimetres, its parts allow-list and its
  named sections are brickify's `studs`, `collection=true` and palettes,
  and `suggest_sections`. Its "put these together in your hand first"
  box is the attachstep idea, measured as a NO-GO.
- brick-build-guide-kit (a step's parts found on a photo of the table):
  round six's Brickit row.
- BrickBack's store prices (parked with prices) and its loose bricks by
  count (mysets).
- Brickium's adding by photo or box (Brickognize, mysets), its checks
  before delivery (`check_design`), resuming a build
  (`BuildSteps.remember`), and its AI cover backgrounds, which need an
  image model (parked).
- Rebrickable's "any colour" internal parts (`Collection.as_its_set`'s
  stand-ins), its prints and moulds ignored (`as_its_set`), its
  multi-store buying (parked with prices), and its mail for new buildable
  models (SOCIAL's notifications, low while the gallery has one designer).
- Brickognize's colour (`brickognize.gd` reads it), Mecabricks' colour
  simulator (the bin dims colours a part was never made in), and a
  SpaceMouse (3Dconnexion, parked).

**Round six's "Next",** where each stands:
- video2, drive, watchfile, makepart2's families, realjoints3, modsteps,
  print3mf, edges, panelside, palettes, twist and mechdet: makepart2,
  realjoints (as realjoints4), print3mf, palettes, twist and mechdet are
  merged; drive is running; the rest are queued behind lights, keeptext5
  and stepnames.
- Not ranked then, and not built since: the model so far as a page
  (LPub3D); sub-models flattened, a selection moved into a new sub-model,
  and each exported (StudWorx); pictures of a range of steps; a Hide
  tool's count; a ground that follows the lowest part; a pile photo's step
  parts; SOCIAL's mail and More like's why; and round five's carried list.
  Sub-models is planned below (submodels).

**The lead's candidates** (`queue.md`):
- **copyfaults**, after keeptext5: renaming or duplicating Tower#1
  recolours Tower#2; undoing a rename leaves Turret#2; VIEW, TITLE and CUT
  lines land above a sub-model's title; `edit_model` swaps a part by
  removing and adding it, losing its origin, group and sub-model; undoing
  `clear_model` loses steps and looks, and redoing it adds a part twice.
- **metalines**, after keeptext5 and lights:
  - SavedViews drops view lines it cannot read, silently;
  - about twelve meta writers (TITLE and FLOOR among them) write LF into
    CRLF files, and `model_floor.gd` has no line-end handling;
  - every `0 !BRICKWORKS` reader keeps its own index;
  - the save path's cost per MB (`BookletLooks._written_in`,
    `_without_app_lines`);
  - a trailing CR, a mixed-case FiLe and a tab are not read as the clean
    forms;
  - booklook's follow-ups: a sub-model's page picture is dropped on save,
    and the main model's `behind.jpg` replaces a sub-model's picture of
    that name;
  - pkreview3's older find: a step edit drops a file's own empty step and
    its lines (`booklet_looks.gd` 812 to 815).
- **heldsteps**, after keeptext5 (pkreview3, MEDIUM): a missing part moves
  its step, and the step's ZOOM is lost (`ModelStore._absent`).
- **a11ymodal**: since dialogclose, dialogs lose the engine's modal flag
  for accessibility (`modal_dialogs.gd`).
- **The 3MF is not manifold**: lib3mf's `IsManifoldAndOriented` is false
  for every object; T-junctions and studs on faces are not stitched
  (`mesh_3mf.gd`). The probe read 0 of 7 today.
- **Geometry through the page's own fetch**: on the web, only exact shapes
  (`.bwx`) come through `_ask_page`; geometry still comes through
  HTTPRequest at about 7 frames a shape (`part_library.gd` `_ask`).
  playweb, which merged with it, made the longest frame worse: 718 ms on a
  laptop against 506, and 1,014 on a phone against 564.
- **A CID font for the PDF**: letters outside Latin print as "?"; the
  export now names them (`booklet_pdf.gd` `_font`).
- **4740 onto 6141 by hand** lands on a corner socket about 14 LDU off and
  is refused; KnownFits is keyed by turn. Four passing sub-models (42088,
  42105, 6542, 10297) are still seated 2 LDU from where their sets have
  them, and `animals_probe`'s as-set check reads the written spot, not the
  set's.
- **pkreview3's undo label** (Delete emptying a step undoes as "changed
  N+1 parts") went into stepnames.
- From the units' own reports, not on the queue: `assistant.gd`'s
  "covers %dx%d studs" from the bounding box (87087 reads 1 x 2 over MCP);
  no MCP tool for palettes; a made part with no stud-seat height (a made
  clip rests 1.448 LDU up) and 54383's chamfer 29 LDU off (makepart2);
  the twist not in the phone's hint; mcpsee3's v4 taking 3 calls.
- Tooling, not units: sticker aiming grows about 8x from 1,000 to 5,000
  parts (still under 1 ms); bigmodel's "opened while weighed" is
  wall-clock; `age_flow`'s `--trust-stand-in` gives 4 local failures.

**SOCIAL.md's and ROADMAP.md's open rows a unit could move**
- **The model page's parts export has no Pick a Brick file,** only
  BrickLink's XML and Rebrickable's CSV (SOCIAL, lines 655 to 664). The
  app writes one (picklist).
- **Real joints' last refusals** (ROADMAP lever 4): panes 57895, 60601
  and 60608, and the bars in 18651, 59443 and 40344, need the parts
  pipeline.
- **SOCIAL**, all low while the gallery has one designer, none ranked:
  the week by email (row 7), an email for a mention, Based on from a
  search and for work made elsewhere, More like's why.
- Measurements, not units: proportion as a norm (lever 2); co-occurrence
  data, read (lever 5); `hinge: true` tried by a run (lever 6); a modern
  LEGO booklet calibrated, black edges again, a run's length (lever 7).
- **Stale lines for their owners:**
  - SOCIAL line 615 says the embed's button "still says View in 3D", but
    row 4 made the embed 3D;
  - SOCIAL lines 669 and 670 say the part pictures "come later", but
    `web/part-pictures.js` draws each lot;
  - ROADMAP lever 4 says the pipeline "records no bar connector anywhere"
    and that bars are "the next unit"; custom elements' "Next: clips,
    bars, wedge plates" is built (makepart2);
  - ROADMAP lever 1's "Next: what the short bricks are" may be stale
    (run 24).

## The gaps, by value to a person building

Above all of these, and not planned here: **the web's first visit** (A13),
10.2 s cold and 6.0 s warm against 10 and 4, on the lead's web-start
work. With the desktop paused, it is the first thing every new person
meets.

1. **A copy can change its twin, and undo can lose steps or add a part.**
   Renaming or duplicating one tower recolours the other. Undoing a rename
   leaves a stray copy, and undoing a clear loses the steps and looks.
   Nothing says so. This breaks the baselines of no silent data loss and
   undo per actor (copyfaults).
2. **Saved views, line ends, page pictures and empty steps are lost or
   changed on save.** A view line this build cannot read is dropped
   without a word. A CRLF file comes back with LF lines in it. A
   sub-model's page picture is dropped, and an empty step the author made
   goes with a step edit (metalines).
3. **A part whose file is missing moves its step, and the step's zoom is
   lost** (heldsteps).
4. **Keys do nothing after typing in a field.** Every bin search leaves the
   focus in the search, and F1, F9, Ctrl+S and the rest are then dead,
   with no word why (typingkeys).
5. **On a laptop with Stress open, Like this, Fits and Techniques are out
   of sight.** Round five's Like this is reached by a scroll bar 4 px
   wide. Studio's bin also has a New parts shelf, and Brickworks' has
   none (binrow).
6. **On the web, parts come one shape per 7 frames,** and the longest
   frame got worse with playweb: 718 ms on a laptop against 506. The web
   is now the way in (fetchparts).
7. **Sets kept built are counted as free bricks.** What can I build? and
   Build from my bricks count every set a person owns, built or not
   (Rebrickable, Brickium). A person's Claude cannot add a set at all, nor
   mark its missing parts (w6) (keptbuilt).
8. **The person's own Claude cannot keep or use a palette.** Palettes are
   in the bin only (mcppalettes). Asked to keep the pods' parts as a
   palette, the session said "none of my tools can create or save one".
9. **A dish clicked onto a round plate is refused by hand,** and four real
   sub-models sit 2 LDU from where their sets have them (seatfix).
10. **A resumed chat cannot take back what it added.** Over MCP, a
    person's Claude added three lots, then could not take them back a turn
    later: each new connection is a new chat to the app, so its own lots
    and edits read as another chat's. It told the person to do it by hand
    (takeback).
11. **Nothing says when a long design, a Best render or a build video is
    done,** so a person who looks away keeps checking back (Brickium)
    (donenote).
12. **The 3MF is not manifold,** so a slicer must repair each colour
    before it prints (print3mf2).
13. **A booklet in Cyrillic, Greek or Japanese prints "?"** in its PDF
    (pdfcid).
14. **A session hears a side-stud brick as 1 x 2,** where the bin now says
    1 x 1 with a stud on one side (mcpwords).
15. Smaller:
    - dialogs not modal to a screen reader (a11ymodal);
    - a made clip resting 1.448 LDU up, and 54383's chamfer (makepart3);
    - the step list with no search (stepsearch);
    - where each part is kept (partplaces);
    - each sub-model exported as its own file (subexport);
    - a dragged part carrying what rests on it (carryrest);
    - how rare a part is in a colour (rarity);
    - line art and comic looks (lineart);
    - a soundtrack under the build film (filmsound);
    - Pick a Brick on the model page (sitepickabrick);
    - the last panes and bars real sets join (realjoints5);
    - the number colour's swatch, and the twist in the phone's hint.

## The units

Twenty-five, ranked, each in its own worktree off the next stage. The
registries below are shared, as `tools/suite/*.txt` is. A unit adds its
own lines there, in a block of its own, and changes no one else's:
- `src/ui/shell.gd`'s `_define` and `MENUS`;
- `src/ui/keymap.gd`'s `PRESET_KEYS`;
- `src/net/app_tools.gd`'s `COMMANDS`, `WINDOW_ONLY`, `GUIDE`, its tool
  list and its dispatch;
- `tools/mcp_tools.json`, written by `mcp_sync_probe --write`;
- `docs-site/generated/menus.json`;
- `src/ui/language.gd`'s tables and `locale/*.po` (every new word in
  German, French and Spanish).

Every new probe goes on its own line in `tools/suite/*.txt`. Every feature
added gets its entry in `.claude/skills/verify/` in the same commit, and
every unit runs `tools/release/unit_preview.sh` on its final sha before it
says ready. A unit that writes the model file or the collection
(copyfaults, metalines, heldsteps, keptbuilt, takeback, partplaces,
subexport) gets
an independent review before it merges, and its probe checks the reopened
model's parts and lines. None of the twenty-five needs the owner.

The units running now own these files, and nothing in wave 1 touches
them:
- keeptext5: `builder.gd`, `assemblies.gd`, `carry.gd`, `custom_parts.gd`,
  `ldr_model.gd`, `model_store.gd`, `source_file.gd`, `brick_world.gd`;
- lights: `scene_lights.gd`, `together.gd`, `command_socket.gd`, the
  plastic shaders, `render_settings.gd`, `studio_render.gd`,
  `render_dialog.gd`, `saved_views.gd`, `model_bar.gd`, `api/together.js`,
  and the same model-file four;
- localbricks: `collection_store.gd`, `set_bin.gd`, `collection_dialog.gd`,
  `later.gd`, `api/collection.js`;
- stepnames: `instructions.gd`, `build_steps.gd`, `booklet_looks.gd`,
  `steps_bar.gd`, `build_mode.gd`, `booklet.gd`;
- drive: `motions.gd`, `motion_player.gd`, `pose_panel.gd`;
- smallwords: `collection_dialog.gd` (`_rebrickable_note`), the mosaic
  dialog's and `art_plan`'s count words, and its new words in the
  language tables.

keeptext5, lights, localbricks and drive also change `main.gd`, each in
functions of its own (checked against their branches): none changes
`_unhandled_key_input`. smallwords had no commits yet.

| # | unit | gap | size | risk | wave | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|---|
| 1 | **copyfaults** | 1 | M | high | 2 (after keeptext5) | `src/assembly/builder.gd` (`regroup`, rename, duplicate, the undo of a clear); `_edit_model` in `app_tools.gd`, a block of its own; new `src/dev/copyfaults_probe.gd` | see below |
| 2 | **metalines** | 2 | M | high | 2 (after keeptext5, lights) | new `src/parts/meta_index.gd`; `src/ui/saved_views.gd`; `src/assembly/model_floor.gd`; `source_file.gd`'s line end for every meta writer; `booklet_looks.gd` (`_written_in`, `_without_app_lines`, the empty step at 812 to 815); the page pictures' names (`booklet_sheet.gd`); new `src/dev/metalines_probe.gd` | see below |
| 3 | **heldsteps** | 3 | S | medium | 2 (after keeptext5) | `src/parts/model_store.gd` `_absent`; new `src/dev/heldsteps_probe.gd` | see below |
| 4 | **typingkeys** | 4 | S | low | 1 | `src/main.gd` `_unhandled_key_input` only; new `src/dev/typingkeys_probe.gd` | see below |
| 5 | **binrow** | 5 | S | low | 1 | `src/ui/parts_bin.gd` (`_build_categories`, `_fit_palette`'s rows, a NEW shelf); new `src/dev/binrow_probe.gd` | see below |
| 6 | **fetchparts** | 6 | M | medium | 1 | `src/parts/part_library.gd` (`_ask`, `_ask_page`); new `tools/web/fetchparts_flow.mjs` | see below |
| 7 | **keptbuilt** | 7 | M | medium | 2 (after localbricks, smallwords) | `src/collection/collection.gd` (`pool`, a set's built state), `collection_dialog.gd`, `set_bin.gd`, `rebrickable_account.gd` (a list's buildable flag); `api/collection.js`, additive only; `edit_collection`'s `sets` (a set by number, built, its parts missing), a block of its own; new `src/dev/keptbuilt_probe.gd` and its API test | see below |
| 8 | **mcppalettes** | 8 | S | low | 1 | a `palettes` tool, a block of its own in `app_tools.gd`; `src/ui/part_shelf.gd` read only; new `src/dev/mcppalettes_probe.gd` | see below |
| 9 | **seatfix** | 9 | M | medium | 1 | `src/ai/exact_check.gd` (the seat), `src/ai/known_fits.gd` (keyed by more than the turn); `src/dev/animals_probe.gd`'s as-set check. **Not** `builder.gd` | see below |
| 10 | **takeback** | 10 | M | medium | 3 (after keptbuilt: `_edit_collection`) | `src/net/app_tools.gd` (`chat`, `_undo`, `_edit_collection`, blocks of its own); `src/net/claude_connector.gd` `_chat_said`; new `src/dev/takeback_probe.gd` | see below |
| 11 | **donenote** | 11 | S | low | 2 (after typingkeys: `main.gd`) | new `src/ui/done_note.gd`; `main.gd` where the assistant and the render queue are made; a Settings row; new `src/dev/donenote_probe.gd` | see below |
| 12 | **print3mf2** | 12 | M | medium | 1 | `src/parts/mesh_3mf.gd` (T-junctions and studs on faces stitched); `print3mf_probe` extended | lib3mf's `IsManifoldAndOriented` true for each of the car's 7 objects (from 0 of 7) and the print, mirror and no-front parts' 3; every edge shared by exactly two triangles; the size still within 0.1 mm; the GLB and STL unchanged to the byte; triangles no more than twice today's 24,921; `print3mf` passes |
| 13 | **pdfcid** | 13 | M | low | 1 | `src/render/booklet_pdf.gd` (`_font`: a Type0 font with CID glyphs, subset to the letters used); `booklet_pdf_probe` extended | a cover title in Cyrillic, a footer in Greek and a step note in Japanese read back by `pdftotext` exactly as typed, with 0 "?", wherever the app's own fonts have the letters; the export names none missing; a Latin booklet the same at 300 dpi to the pixel, its file no more than 10% bigger; `booklet_pdf`, `booklook` pass |
| 14 | **mcpwords** | 14 | S | low | 1 | `src/ai/assistant.gd` (the "covers %dx%d studs" words at 6336: the bin's own words); `words6_probe` extended | over MCP, 87087 reads "1 x 1, a stud on one side, 1 brick", 4733 "1 x 1, studs on four sides" and 30414 "1 x 4, studs on one side", as the bin does; every part the walk's 30 words find is described in the bin's words; the MCP walk's w8 right in 1 call; `words6`, `mcp` pass |
| 15 | **a11ymodal** | 15 | S | medium | 2 (free: may start in wave 1) | `src/ui/modal_dialogs.gd` | every open dialog is modal in the accessibility tree; a window close with a dialog up is still heard in 1 to 2 ms and quits in 30 ms or less (dialogclose's bar); `dialogclose`, `touch_sizing` pass |
| 16 | **makepart3** | 15 | S | medium | 2 (free) | `src/parts/element_maker.gd` (a stud seat for made parts; the chamfer); `element_probe` extended | a made clip on a stud rests 0.00 LDU up (from 1.448); 54383 copied within 0.01 LDU, chamfer and all (from 29); the other families unchanged; `element`, `element_files`, `element_shot` pass |
| 17 | **stepsearch** | 15 | S | low | 2 (after stepnames) | `src/ui/steps_bar.gd` (a filter); new `src/dev/stepsearch_probe.gd` | "3024" in the timeline's filter shows exactly the steps that place a 3024 in the car; a name and a colour likewise; Enter goes to the first; `stepnames`, `timelinefit` pass |
| 18 | **partplaces** | 15 | M | low | 3 (after keptbuilt) | `collection.gd` (a lot's or a set's place), `collection_dialog.gd`, `api/collection.js` additive; `parts_list`'s places, a block of its own | a place ("drawer B3") on 12 lots and a set, kept with the account and on another device; the parts list, What do I need? and Build it's step parts say each part's place; `parts_list` over MCP gives them; `collection`, `mybricks`, `keptbuilt` pass; a review before merge |
| 19 | **subexport** | 15 | S | medium | 3 (free) | `src/ui/exports.gd` (a row), the model tree's menu (`src/ui/outliner.gd`); `export_model`'s `submodels`, a block of its own; new `src/dev/subexport_probe.gd` | each of a model's sub-models written as its own `.ldr`, with its own sub-models and steps, from the model tree and in 1 call over MCP; each opens alone to the same parts, 0.001 LDU; the whole model's export unchanged to the byte; `exports`, `store` pass |
| 20 | **carryrest** | 15 | M | medium | 3 (after keeptext5: `carry.gd`) | `src/assembly/carry.gd`; new `src/dev/carryrest_probe.gd` | a 2 x 4 brick dragged carries the bricks resting on it, 0.00 LDU apart; Shift moves it alone; one undo puts all back; by finger the same; `grab`, `drag`, `touch` pass |
| 21 | **rarity** | 15 | S | low | 3 (after fetchparts, binrow) | `part_library.gd` (sets per part and colour); `parts_bin.gd`'s colour tooltip | a colour's tooltip says in how many sets the part comes in it; a part and colour in three sets or fewer reads "rare in this colour"; spot-checked against 10 Rebrickable inventories; `bin` passes |
| 22 | **lineart** | 15 | S | low | 3 (after edges) | a look in `render_settings.gd`, its shader beside the plastic ones; Render's Look row | Line art and Comic looks: black lines on white with halftone shading, on a transparent background when asked; the default render the same to the pixel; `render`, `pathtrace` pass |
| 23 | **filmsound** | 15 | S | low | 3 (after video2, lineart: `render_dialog.gd`) | `src/render/build_render.gd`, `render_output.gd`; Render's row | the person's own sound file under the build video: the MP4 carries it, cut to the video's length and faded out; a WebP the same as before; `render`, `motions_render` pass |
| 24 | **sitepickabrick** | 15 | S | low | 3 (free) | `api/_parts.js` (the exports), `api/share.js` (the route), the model page's Export row | the model page offers a LEGO Pick a Brick file (`/m/X/parts-pab.csv`), its lines the app's own Pick a Brick export of the same version, word for word; a part with no element number counted, never guessed; `parts_page` passes |
| 25 | **realjoints5** | 15 | L | high | 4 (alone: the only catalogue rebuild in flight) | the parts pipeline (`tools/`), `catalogue.json` rebuilt | panes 57895, 60601 and 60608 and the bars of 18651, 59443 and 40344 join as their sets have them; the real sub-models from 963 to more, none newly refused; each pane placed in its frame by hand and over MCP; `harvest`, `animals`, `tested_models` pass |

**Which can run at once.** Each wave's files are its own: no two units
in a wave share a file, beyond the registries.
- **Wave 1, eight at once:** typingkeys, binrow, fetchparts, mcppalettes,
  seatfix, print3mf2, pdfcid, mcpwords. None touches a running unit's
  files, and typingkeys' one function of `main.gd` is changed by no
  running branch.
- **Wave 2, eight,** each once the unit it names has merged:
  - copyfaults and heldsteps after keeptext5 (`builder.gd`,
    `model_store.gd`);
  - metalines after keeptext5 and lights (`source_file.gd`,
    `saved_views.gd`). If it must change `ModelStore`'s writers, it goes
    after heldsteps;
  - keptbuilt after localbricks and smallwords (`collection_dialog.gd`,
    `set_bin.gd`, `api/collection.js`, `_edit_collection`);
  - donenote after typingkeys (`main.gd`);
  - stepsearch after stepnames (`steps_bar.gd`);
  - a11ymodal and makepart3 share nothing with anyone, and could start in
    wave 1 if a slot is free.
- **Wave 3, eight:**
  - takeback after keptbuilt: both change `_edit_collection`;
  - partplaces after keptbuilt (`collection.gd`, `collection_dialog.gd`);
    it shares nothing with takeback;
  - carryrest after keeptext5 (`carry.gd`);
  - rarity after fetchparts and binrow (`part_library.gd`,
    `parts_bin.gd`);
  - lineart after edges (the plastic shaders), and filmsound after video2
    and lineart (`render_dialog.gd`);
  - subexport and sitepickabrick share nothing with anyone.
- **Wave 4:** realjoints5 alone. It rebuilds the catalogue every probe
  reads, so it runs when no other unit is measuring against it.
- The three that write the model file (copyfaults, metalines, heldsteps)
  run in the same wave on different files. Whichever merges second
  rebases, and its review reads both together.

**1. copyfaults: a copy never changes its twin, and undo gives back what
it took.**
- **Change.** A sub-model's rename and duplicate touch only the one asked
  for. An undo of a rename leaves no copy behind. VIEW, TITLE and CUT lines
  stay under their own sub-model's title. `edit_model` changes a part in
  place, keeping its origin, group and sub-model. Undoing `clear_model`
  brings back every step and look, and redoing it adds nothing twice.
- **Bar** (`copyfaults_probe`, red first on `pre261`):
  - Tower#1 renamed, and duplicated: Tower#2's colours and lines byte for
    byte as before;
  - a rename undone: no Turret#2 in the model or the file;
  - VIEW, TITLE and CUT lines under their sub-model's title over save and
    open, on 10 files with sub-models;
  - an `edit_model` swap keeps the part's origin, group and sub-model;
  - `clear_model` undone: steps and looks as before, byte for byte; redone:
    the same part count;
  - `unit_steps`, `steps_kept`, `kt3r` and `keep_text` pass;
  - a review before merge.

**2. metalines: what a save does not understand, it keeps as it was.**
- **Change.**
  - One index of every `0 !BRICKWORKS` line, read once per open, for every
    reader.
  - A line a reader cannot read is kept where it was and written back
    unchanged. SavedViews is the first such reader.
  - Every meta line is written in the file's own line end.
  - A trailing CR, a mixed-case `FiLe` and a tab read as the clean forms.
  - A sub-model's page picture is kept, and two pictures of one name get
    two names.
  - A step edit keeps a file's own empty step and its lines.
- **Bar** (`metalines_probe`):
  - a file with a view line from a newer build, opened and saved: the line
    back byte for byte;
  - 30 test files written CRLF, edited and saved: 0 LF-only lines;
  - the castle saved in no more time per MB than `pre261`;
  - a sub-model's page picture, and two of one name, back after a save and
    an open;
  - pkreview3's empty-step file: its empty step and lines kept over a step
    edit;
  - `steps_kept`, `booklet_edit`, `pagesetup`, `savedviews`, `keep_text`
    and `pullkept` pass;
  - a review before merge.

**3. heldsteps: a missing part keeps its step and its looks.**
- **Change.** A part whose file is absent stays a part of its own step,
  and the step's ZOOM and other looks stay with it (`ModelStore._absent`).
- **Bar** (`heldsteps_probe`): pkreview3's model, with its part's file
  taken away, opened, saved and opened: the part on its own step, the
  ZOOM and every look byte for byte; with the file back, the model as it
  was; `steps_kept`, `pullkept`, `booklet_edit` pass; a review before
  merge.

**4. typingkeys: the keys work while a field has the focus.**
- **Change.** While a field has the focus, only keys the field would take
  stay with it: letters, digits, Space and the editing keys, with no Ctrl,
  Alt or Cmd. Function keys and modified keys reach their commands, unless
  the field itself used them (Ctrl+A, C, V, X and Z on its text).
- **Bar** (`typingkeys_probe`, at 1280 x 720 and 1400 x 900, under all
  four presets):
  - with "87087" typed in the bin's search and the focus there, F1 opens
    the keys sheet, F9 Render, Ctrl+Shift+B Page setup, Alt+X the box, and
    Ctrl+S saves, in 1 press each;
  - the same from the assistant's brief and from Find's field;
  - letters, digits and Space typed there run 0 commands: the model the
    same byte for byte, its undo list the same length;
  - Ctrl+A, C, V, X and Z in the field act on its text, not on the model;
  - the walk's keys sheet finds 11 rows for "cut away" at 1400 x 900;
  - `keys`, `keys2`, `keysheet`, `search` and `palettes` pass.

**5. binrow: every shelf in sight, and a New shelf.**
- **Change.** The bin's shelves (All, Recent, Favourites, Palettes, New,
  Techniques, Fits, Like this) always fit in what is in sight: they wrap,
  or shorten their words, before any is scrolled away. The categories
  (Brick, Plate…) may scroll as now. A New shelf lists the parts first
  made in the catalogue's latest two years, newest first.
- **Bar** (`binrow_probe`, at 1280 x 720 with Stress open, 1400 x 900,
  1024 x 768 and 390 x 844):
  - every shelf in sight with no scroll, with every column open;
  - the walk's Like this gives Plate 2 x 4 seventh at both sizes;
  - New lists parts first made in the latest two years, each one the
    catalogue has, newest first;
  - 42 tiles in sight at 1400 x 900 on the first open, as now;
  - `bin`, `palettes`, `words6`, `roomfit` and `quiet` pass.

**6. fetchparts: the web fetches shapes as fast as the page can.**
- **Change.** On the web, every part file comes through the page's own
  fetch (`_ask_page`), as exact shapes already do, many at once and written
  in without holding a frame. HTTPRequest is left to the desktop.
- **Bar** (`fetchparts_flow`, a web export served by `serve.py`, broadband
  and a throttled phone, ABBA at equal load):
  - 0 HTTPRequest calls for geometry on the web, counted;
  - the car's shapes all in, in half `pre261`'s time or less;
  - the longest frame while it opens 506 ms or less on a laptop and 564
    on a phone (before playweb);
  - `play_flow` still moving within 2 s; the Brick Art flow says one
    piece; `load_check` interactive no worse;
  - `bin` and `art` pass.

**7. keptbuilt: what is built on the shelf is not free to build with.**
- **Change.** A set (or a saved model) in What I own can be marked as
  built. Its parts are then left out of What can I build?, Build from my
  bricks and a design from the person's own parts, until it is marked as
  taken apart. A Rebrickable list that is not buildable is read as built.
  Over MCP, `edit_collection` adds a set by number, built or not, with
  parts marked missing (localbricks' marks); a session cannot add a set
  today (w6).
- **Bar** (`keptbuilt_probe`, signed in, and the API test):
  - 7140 marked built: What can I build? and Build from my bricks leave
    out exactly its 285 pieces; taken apart, they are back;
  - a Rebrickable list flagged not buildable read as built;
  - kept over a restart and on another device; an older collection the
    same lot for lot;
  - over MCP in 1 call; the MCP walk's w6 (7140 with two parts missing)
    in 1 call, the set then in the dialog as the person's own;
  - `collection`, `mybricks`, `mysets` and `setbin` pass;
  - a review before merge.

**8. mcppalettes: the person's Claude keeps and uses palettes.**
- **Change.** A `palettes` tool lists the person's palettes, makes one
  from the model or a selection, adds and takes away parts, and places a
  palette's sub-assembly. It reads and writes the same palettes file the
  bin does.
- **Bar** (`mcppalettes_probe`, the tool called as a session calls it):
  - a palette of 12 parts in their colours and one sub-assembly, made in 1
    call, is the one the bin shows, byte for byte in the file;
  - listed in 1 call, and its sub-assembly placed whole in 1 call, within
    0.01 LDU;
  - the list is read-only, and the rest are not (`read_only`);
  - the MCP walk's w7 done in 2 calls or fewer;
  - `mcp_sync`, `mcp`, `read_only` and `palettes` pass.

**9. seatfix: a dish on a round plate, and real sub-models where their
sets have them.**
- **Change.** A part clicked onto a stud seats on that stud, whichever way
  it is turned: KnownFits is keyed by what fits, not by the turn alone. A
  part a real set puts on a stud is seated exactly there.
- **Bar:**
  - 4740 clicked onto 6141's stud by hand: placed, 0.00 LDU from its
    centre; the same over MCP;
  - 42088's, 42105's, 6542's and 10297's sub-models seated where their sets
    have them, 0.00 LDU;
  - `harvest`: 963 or more of 1,056, none newly refused;
  - `animals`: 63 of 63 and 27 of 27, its as-set check reading the set's
    own spot;
  - `grab`, `exact`, `joints` and `tested_models` pass.

**10. takeback: a chat takes back its own work after a resume.**
- **Change.** Each answer that adds lots or changes the model carries a
  short receipt for what this chat did. A resumed chat that quotes it is
  the same chat to the app: it can take back its lots and undo its own
  changes. A chat with no receipt, or another's, is refused as now, and
  the person still sees each lot under Added by Claude. A receipt is
  good only in the tab that gave it.
- **Bar** (`takeback_probe`, connections in turn as `claude -p --resume`
  makes them):
  - three lots added in one connection, taken back in the next in 1 call
    by the receipt; the collection as before, lot for lot;
  - an edit made in one connection undone in the next in 1 call;
  - a third connection with no receipt, a made-up one or another chat's:
    refused, nothing changed;
  - the MCP walk's v10 done in 1 call;
  - `claude_undo`, `collection`, `mybricks`, `mcp` and `read_only` pass;
  - a review before merge (it writes the collection, and a receipt is a
    permission).

**11. donenote: a long job says when it is done.**
- **Change.** When a design, a Best render, the render queue or a build
  video finishes while the person is not looking, the app says so:
  - on the desktop, the window asks for attention and its title starts
    with "Done ·";
  - on the web, one notification with the model's name and what finished.
    Permission is asked when a person first starts a long job, never on
    load.

  Nothing happens while the window has the focus. It can be turned off in
  Settings, and the choice is kept.
- **Bar** (`donenote_probe`, a stand-in for the browser's Notification and
  for the window's attention):
  - each of the four jobs finished unfocused: 1 attention request on the
    desktop, and 1 notification on the web;
  - finished focused: 0;
  - turned off: 0;
  - `quiet`, `render` and `assistant` pass.

**12 to 25** are in the table.

## The top ten, by value to a person building

1. **copyfaults:** a copy never changes its twin, and undo gives back what
   it took. Measured: Tower#2 byte for byte after Tower#1's rename and
   duplicate; `clear_model` undone to the byte, and redone with no part
   twice.
2. **metalines:** what a save does not understand, it keeps. Measured: a
   newer view line back byte for byte; 0 LF-only lines in 30 CRLF files;
   the empty step and the page pictures kept.
3. **heldsteps:** a missing part keeps its step and its zoom. Measured:
   pkreview3's model byte for byte over open, save and open.
4. **typingkeys:** keys work after typing in a field. Measured: F1, F9,
   Ctrl+Shift+B, Alt+X and Ctrl+S in 1 press each with the bin's search
   focused; 0 commands from typed letters.
5. **binrow:** every bin shelf in sight, and a New shelf. Measured: all
   eight shelves unscrolled at four sizes with Stress open; the walk's Like
   this back to Plate 2 x 4 seventh at 1280 x 720.
6. **fetchparts:** the web's shapes through the page's own fetch.
   Measured: 0 HTTPRequest calls for geometry; the car's shapes in half
   the time; the longest frame back to 506 ms.
7. **keptbuilt:** a built set is not free to build with. Measured: 7140
   marked built takes exactly its 285 pieces out of What can I build?;
   the MCP walk's w6 in 1 call.
8. **mcppalettes:** the person's Claude keeps and uses palettes. Measured:
   a palette made in 1 call is the bin's, byte for byte; the MCP walk's w7
   in 2 calls.
9. **seatfix:** a dish on a round plate, and real sub-models where their
   sets have them. Measured: 4740 on 6141 at 0.00 LDU by hand and over
   MCP; four sub-models at 0.00; harvest 963 or more.
10. **takeback:** a resumed chat takes back its own work. Measured:
    three lots added in one connection taken back in the next in 1 call;
    another chat's still refused; the MCP walk's v10 in 1 call.

Wave 1 starts with five of these (typingkeys, binrow, fetchparts,
mcppalettes, seatfix) and three from below the ten (print3mf2, pdfcid,
mcpwords). The first three of the ten wait on keeptext5, keptbuilt on
localbricks, and takeback on keptbuilt.

Above all ten, and not planned here: the web's first visit (A13), on the
lead's web-start work. Its new numbers: 10.2 s cold and 6.0 s warm, and
the compile 2.2 s on both. Also above them and in flight: lights,
keeptext5, localbricks, stepnames, drive and smallwords, then intomodel3
and lightpaths.

**Next, once those land:**
- donenote, print3mf2, pdfcid, mcpwords, a11ymodal, makepart3,
  stepsearch, partplaces, subexport, carryrest, rarity, lineart,
  filmsound, sitepickabrick and realjoints5: ranked 11 to 25 above.
- Round six's queue, unchanged: modsteps, video2, edges, watchfile and
  panelside.
- Not ranked:
  - the model so far as a page (LPub3D), and pictures of a range of steps;
  - a Hide tool's count, and a ground that follows the lowest part;
  - checking a set piece by piece with others (BrickCheck);
  - both halves of a dual-moulded part recoloured;
  - the number colour's swatch, and the twist in the phone's hint (each a
    line for whichever unit next touches Page setup or the hint);
  - sticker aiming on a 5,000-part model;
  - a compare by shape in any colour (w3), so "could I build it from
    7140" can say what it would be in 7140's colours;
  - SOCIAL's mail and More like's why;
  - from earlier rounds, carried: an exploded view's spread, four
    viewports, a wanted list as a counted bin, a reverse booklet,
    Orthanc's three, a part from an OBJ with its connectors, an
    originality score, vector booklets, STEP import, gamepads, and a pile
    photo's step parts.
- **Parked, needing the owner:**
  - bricklink (BrickLink's keys and terms; a mosaic's and a list's price
    wait on it), and store prices generally;
  - studioside (Studio's install);
  - 3Dconnexion (the device);
  - the Mac's thumbnails (the Developer ID);
  - desktop downloads ("Coming soon" until the owner says);
  - payments and live prices;
  - the Claude directory's submission;
  - tests on other AIs;
  - music shipped with Brickworks (a licence), and AI cover backgrounds
    (an image model).

  None is ranked above, and nothing above waits on any of them.
- **Out on purpose:**
  - a collision switch;
  - more languages;
  - a second look for the app, until the owner asks;
  - the LEGO logo on studs ([TRADEMARKS.md](TRADEMARKS.md), 3);
  - anything for a person who is not signed in: everyone has an account
    (localbricks' decision, 8 November).

## Sources

Brickworks' own figures are from the runs above, in
`bench/results/appux7-2026-11-08/`:
- `walk/`: the walk's logs and its 174 pictures;
- `probes/`: the probes' logs and their times;
- `web/`: the web's runs;
- `mcp/`: the MCP sessions' streams and the app's own files;
- `sources/`: the field's pages as read today.

The MCP walk's prompts and calls are in
[app_ux7/mcp_walk/](app_ux7/mcp_walk/).

The field's sources, beyond APP_UX2's to APP_UX6's:
- Rebrickable, Assembled Lists: <https://web.archive.org/web/20260128150833/https://rebrickable.com/help/assembled-lists/>; set lists left out of Build: <https://web.archive.org/web/20260304105555/https://rebrickable.com/help/lists-sets/>
- Brickium: <https://apps.apple.com/us/app/brickium-ai-brick-builder/id6812500807>
- Pileometer: <https://apps.apple.com/us/app/pileometer-by-brickit/id6590601507>
- Brickfolio: <https://github.com/scoobydrew83/brickfolio>
- Studio, New Parts palette: <https://studiohelp.bricklink.com/hc/en-us/articles/5432369871383>; the step list's search: <https://studiohelp.bricklink.com/hc/en-us/articles/6508513723543>
- BUF3D Lite: <https://play.google.com/store/apps/details?id=com.cimplus.buf3dlite>
- lego-build-video: <https://github.com/OceanJy333/lego-build-video>
- BrickMissing: <https://www.eurobricks.com/forum/forums/topic/213529-brickmissing-free-parts-checker-that-tells-you-if-a-lost-piece-is-actually-replaceable/>
- Brickyard: <https://github.com/genworks/brickyard>
- BrickCheck: <https://github.com/dylankiss/brickcheck>
- Mecabricks' forum, dual-moulded parts: topic 76393, `sources/mb/t76393.html`
- StudWorx releases: <https://github.com/nathaneltitane/studworx/releases>
- LeoCAD releases: <https://github.com/leozide/leocad/releases>
