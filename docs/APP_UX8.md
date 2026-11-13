# The app against the best tools, round eight

Written 2026-11-09 by appux8 against `pre261` at `804c14443`. The web was
measured on rel-m281 (`a65382fb6`), live then. [APP_UX.md](APP_UX.md) to
[APP_UX7.md](APP_UX7.md) planned rounds one to seven.

Round seven's units, where each stands:
- **live** (rel-m279 to m281): print3mf2, pdfcid, binrow, seatfix and
  mcpwords;
- **in `pre261` at this commit:** typingkeys, makepart3, a11ymodal,
  fetchparts, mcppalettes, and edges (round six's, merged in this round);
- **running:** donenote, subexport, rarity, lineart, sitepickabrick, and
  pdfbidi (pdfcid's right-to-left letters and emoji, found in review);
- **waiting on keeptext5 and the units after it:** copyfaults, metalines,
  heldsteps, keptbuilt, takeback, partplaces, carryrest, stepsearch,
  filmsound and realjoints5.

Also in flight:
- keeptext5, with its review's six fixes;
- drive and stepnames, with theirs;
- localbricks and video2, still being built;
- hudfront, a11ynames and a11ytree;
- the beta release: betajoin, bugreport and betahome;
- the docs: docshots;
- flowaccount.

askfirst, lightpaths and intomodel3 are queued behind keeptext5.

This file measures the app an eighth time, by hand and through a person's
own Claude. It says where the field still does better. **It also names the
features no tool in the field has that a builder would value most, judges
each, and ranks them with the gaps.** Then it plans round eight in waves
the lead can start at once.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second. On 9 November
the owner asked for "ultra advanced features and improvements". The
desktop download still says "Coming soon", so the browser is the way in.
[COMPETITIVE.md](COMPETITIVE.md) is the feature matrix,
[ROADMAP.md](ROADMAP.md) the designer's quality and
[SOCIAL.md](SOCIAL.md) the site. None is repeated or edited here.

## How it was made

- **The walk, an eighth time.** appux7's script and tasks, run on the GPU
  at 1280 x 720 and 1400 x 900, from a locked snapshot of this commit,
  imported first ([app_ux8/appux_walk.gd](app_ux8/appux_walk.gd)). One
  section was added after the old ones, so their numbers still compare:
  `round7`, which covers:
  - every bin shelf with Stress open, and Like this beside Stress;
  - the New shelf;
  - the Palettes chip's count;
  - F1, F9 and Ctrl+Shift+B pressed with the bin's search focused;
  - a 4740 dish put on a 6141 round plate by hand;
  - View › Edges and studs;
  - Check stability on the car;
  - Make a part's wedge plate with its far corner cut;
  - My collection with the assistant hidden;
  - the keys round seven's commands have.

  The first run of `round7` began with the bin closed, because round six's
  last act closes it. Its bin lines measured nothing, so the section now
  opens the bin by its rail first, as binrow's own probe does, and was run
  again alone at both sizes (`only=round7`). Every picture both runs took (99 and 99, then 12 and 12) was looked at.
- **The same tasks over MCP,** as the owner's Claude does them
  ([app_ux8/mcp_walk/](app_ux8/mcp_walk/)):
  - the app in a window of its own, with its MCP port open and its own
    Documents and Pictures;
  - signed in: `run.sh` opens a throwaway account on the live site through
    the relay, starts the app `--signed-in`, and closes the account at the
    end (`account_close.txt`). It holds a slot of the live database
    (`live_db.sh`);
  - the walk's 30 words, and "1x4 brick", through `search_parts`;
  - then Claude Code on the subscription: `claude -p`, the Brickworks
    server alone, `--tools ""`, `--restricted`, no API key.

  There was one turn per task: APP_UX7's 45 tasks, five for what round
  seven added ([prompts_round7.txt](app_ux8/mcp_walk/prompts_round7.txt)),
  and seven that ask for the features past parity, from a cleared model
  ([prompts_frontier.txt](app_ux8/mcp_walk/prompts_frontier.txt)). Calls
  are counted from the sessions' own streams.

  The run waited 1 h 42 min for a slot of the live database behind the
  units' preview checks (its first try gave up after the hour it was
  allowed, exit 75), then ran from 13:24 to 13:49 UTC. All 57 streams
  say `apiKeySource: none`, Opus 5.5, the Brickworks server's 77 tools
  and nothing else, with empty stderr. The account was deleted at the end
  (`account_close.txt`: "deleted").
- **Round seven's bars** were read off each merged unit's probe, run today
  from the same snapshot, at the sizes their headers give:
  - headless, one after another under `heavy`: `print3mf`, `seatfix`,
    `animals`, `element`, `element_files`, `art_counts`, `mosaic`, and
    `harvest` over the 1,056 real sub-models;
  - windowed, one at a time on the GPU: `typingkeys` and `words6` (1280 x
    720 and 1400 x 900), `binrow` with its pictures, `binrow_tablet`,
    `binrow_phone`, `mcppalettes`, `booklet_pdf`, `a11y_modal`,
    `element_shot`, `edges` with its pictures, `lights`, `noai` and
    `mosaic_window`.

  fetchparts' bar is from its own A/B report (`ab8`), because its flow
  needs a web export served beside the old one.
- **The web:** `load_check` on live brickworks.diy (rel-m281), on
  broadband, two cold and two warm loads and a part picked from the bin,
  and again at a phone's 390 x 844 (3x, touch).
- **The field,** from each tool's help pages, release notes, changelogs,
  store listings, READMEs, commits and papers as of 9 November 2026
  (Sources). APP_UX2's to APP_UX7's lists and COMPETITIVE were read again,
  and only what they did not cover is new here. Round seven's own "Next",
  the lead's candidates in `queue.md`, and SOCIAL's and ROADMAP's open
  rows are folded in.
- **The frontier** was judged feature by feature: what Brickworks has
  today, read from its code and the probes above; what the field has, from
  its own pages; and what a person building would feel. Studio's own
  articles on its stability check, Build Together, animation and
  Divide into steps were read for the comparison.
- **Not run:**
  - Studio itself (studioside, the owner's);
  - the in-app assistant on a key (it spends money);
  - claude.ai's connector.
- **The box was shared** with the units' probes, unit previews and the
  window sweep. The load was 23 to 39 through the walk and the probes,
  and 26 to 38 through the web runs. Seconds are stretched by it; counts
  are not.

## What the walk measured, eight times

The first five rounds' figures are in APP_UX4 to APP_UX7.

| act | appux6 (1280 / 1400) | appux7 (1280 / 1400) | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|---|
| desktop start, the first 120 frames | 6.4 / 12.9 s | 8.2 / 8.3 s | 7.3 s (load 37) | 9.1 s (load 29) | walk |
| bin tiles in sight on the first open | 24 / 42 | 24 / 42 | 24, every one named | 42, every one named | walk `counts` |
| keys sheet (F1), rows in sight | 32 / 46 of 157 | 32 / 46 of 157 | 32 of 158 | 46 of 158 | walk `counts` |
| commands with a key | 116 of 221 | 116 of 222 | 116 of 224 | the same | walk `counts` |
| the tallest menu, rows (height) | Edit 24 (464) | File 24 (482) | File 24 (482); Edit 24 (464); none scrolls | the same | walk `menus` |
| the part menu | 26 | 26 | 26 | 26 | walk `menus` |
| a wall of eight 1 x 4s from the search | 20, 2.9 / 3.3 s | 20, 3.4 / 4.7 s | 20 events, 3.7 s (2.8 s the second time) | 20, 3.9 s (3.4 s) | walk `wall`, `round6` |
| the ghost following the pointer, 3 frames a move | 37.9, worst 68.4 / 44.4, worst 73.7 | 47.8, worst 65.9 / 62.1, worst 82.8 | 55.0 ms, worst 80.5 (38.1, 54.6) | 54.8, worst 78.7 (47.7, 70.7) | walk `wall`, `round6` |
| R on a brick in a wall, 15° step | down after 2 events, 15.0° | the same | the same | the same | walk `turns` |
| a brick alone, 3 x R at 15° | 45° | 45° | 45° | 45° | walk `dialogs` |
| panels and dialogs | 22 of 24 | 22 of 24, 0.9 to 2.5 s | 22 of 24, 0.9 to 2.1 s; Compare and Pattern greyed, as before | 22 of 24, 1.3 to 2.3 s | walk `dialogs` |
| search, 30 words | 27 | 27 | 27: the same three not first | the same | walk `search` |
| three selected parts painted Red | 1 key | 1 key | 1 key | 1 key | walk `round2` |
| a 2 x 4 plate split, and merged back | 1 key each | 1 key each | 1 key each | the same | walk `round2` |
| a second view, the assistant open | F8: 490 / 385 px | the same | F8: 490 px | F8: 385 px | walk `round2` |
| a part to the last step | 4 presses | 4 | 4 | 4 | walk `round3` |
| Settings' language | four | four | English, Deutsch, Français, Español | the same | walk `round3` |
| Like this on a 2 x 4 brick after "1x4 brick", Stress open | Plate 2 x 4 seventh | not reached at 1280 / seventh | **Plate 2 x 4 seventh** (binrow) | Plate 2 x 4 seventh | walk `round3` |
| Like this beside Stress, from the bin's chip | | | chosen in 3 clicks; 3001, 39789, 6249 and the other 2 x 4s first | the same | walk `round7` |
| the status bar, the car open | "61 bricks · stands up · 52 g" | and "4.5 × 10.8 studs, 15 plates high · 3.60 × 8.64 × 4.96 cm" | the same | the same | walk `round6` |
| three parts of the car selected | "3.8 × 7.8 studs, 4½ plates high" | "3.8 × 7.8 studs, 4.5 plates high · 3.04 × 6.24 × 1.44 cm" | the same | the same | walk `round6` |
| the wall's weight: just built, a part in hand, after a turn | 8, 13, 12 g | 13, 13, 13 g | 13, 13, 13 g | the same | walk `round6` |
| the car's weight, every frame read | 52 g | 52 g | 52 g | 52 g | walk `round6` |
| Cut away by a box | 1.2 s; Alt+X, Alt+Z, Alt+Y | 1.1 s, the same keys | 1.3 s, the same keys | 1.6 s | walk `round4` |
| Cut away's strip, with Stress open | 5 of 5 | 5 of 5 | 5 of 5 | 5 of 5 | walk `round5` |
| everything open with the timeline | past the right edge | 0 past; room 639 / 769 | 0 past the edge; room 639 | 0; room 769 | walk `round6` |
| the booklet's page set up | Ctrl+Shift+B, 1 press | and three tabs | the same | the same | walk `round6` |
| Stud directions on the car | up 45, to the front 4, none 12 | the same | the same | the same | walk `round5` |
| a view saved, turned away 35°, brought back | back 0.000° | the same | the same | the same | walk `round5` |
| My collection | and Loose parts | and a set by its photo | the same | the same | walk `round6` |
| Compare two sets or models | with a save only | usable with no save; no key | the same | the same | walk `round6` |
| Export, 3D model | .glb, .gltf, .obj, .stl | and .3mf | and .3mf, **every object a closed solid** (print3mf2) | the same | walk `round6`, `print3mf` |
| Make a part's families | seven | and clip, bar, wedge | the same ten | the same | walk `round6` |
| the bin's "plate 1 x 1" and "1x1 plate" | 6141 first | 3024 first at 1400 | the bin had given way to Properties (the walk's own, as in round seven); `words6` at 1280 x 720: 3024 first, both | 3024 first, both | walk `round6` |
| 87087's tooltip | "1 x 2" | "1 x 1, a stud on one side, 1 brick" at 1400 | the bin had given way; `words6` at 1280 x 720: "1 x 1, a stud on one side, 1 brick" | the same | walk `round6` |
| the keys sheet's "cut away" | not found | 11 rows at 1280; F1 did nothing after the search at 1400 | 11 rows | **11 rows, F1 pressed from the bin's search** (typingkeys) | walk `round6` |
| File, Import, Into this model… | not offered | not offered | not offered: intomodel3 waits on keeptext5 | the same | walk `round4` |
| lights | not offered | not merged | **in Render's Add row: Bulb, Spot, Sun and the Light panel** (lights) | the same | walk `round5` |
| **round seven's own** | | | | | |
| every bin shelf with Stress open | | out of sight at 1280 | **all eight in sight, unscrolled**, the bin 322 wide beside Stress, once its rail brings it back ([picture](app_ux8/shelves_beside_stress_1280x720.webp); binrow) | the same | walk `round7` |
| the New shelf | | none | 32 tiles; "282 parts first made in 2025 or 2026, the newest first" (binrow) | 32 tiles; "282 parts first made in 2025 or 2026, the newest first" ([picture](app_ux8/new_shelf_1400x900.webp); binrow) | walk `round7` |
| F1, F9 and Ctrl+Shift+B with the bin's search focused | | F1 did nothing | **each opens in 1 press, the search focused** (typingkeys) | each opens in 1 press (typingkeys) | walk `round7` |
| a 4740 dish on a 6141 round plate by hand | | refused, a corner socket 14 LDU off | **seated: 0.00 LDU across, 8.00 above**, 9 events ([picture](app_ux8/dish_on_round_plate_1280x720.webp); seatfix) | **seated: 0.00 LDU across from the stud, 8.00 above the plate's top**, 9 events (seatfix) | walk `round7` |
| View › Edges and studs | | none | edges and studs each off and back on; no key | the same | walk `round7` |
| Check stability on the car (61 parts) | | | "it stands up — no joint is carrying more than it can hold"; "Stands, 1.9 studs inside the right edge (a 34° tilt tips it)", 21 and 22 ms after the press; Alt+K | the same, 31 and 32 ms ([picture](app_ux8/check_stability_1400x900.webp)) | walk `round7` |
| Make a part's wedge plate | | the chamfer 29 LDU off | "Far corner cut flat" offered (makepart3), but **below the fold**: the dialog must be scrolled to reach it | the same, its top edge a sliver under "Studs on top" | walk `round7`, its pictures |
| My collection with the assistant hidden | | | 0 words of Claude in sight (noai) | the same | walk `round7` |

The search's three that are not first are the walk's own answers, as
before:
- "jumper" lists 3794b sixth, after the newer 15573.
- "macaroni" lists 25269 fourteenth.
- "bracket" has 99781 fourth.

These commands have no key: View › Edges and studs, Stress, Together,
Mosaic, Make a part, My collection and its What can I build? and What do I
need?, Export 3D model and Reseat. 108 of 224 commands have none. Check
stability is Alt+K, Simulate Alt+U, Pose Alt+O, Instructions Alt+B, Page
setup Ctrl+Shift+B and Render F9.

**Found on the way:**
- **A tooltip outlives the dialog opened over it.** At 1280 x 720, a
  Stress row's tooltip ("Hinge 1 x 2 Base: carries 1.8 g on 2 studs,
  margin 100+") stays drawn on top of the dialogs the walk opened next by
  key. The walk's pointer rested on the row, as a person's does when they
  reach for a key. Godot hides a tooltip when the pointer moves, not when
  a dialog opens. Small; a line for whichever unit next touches
  `modal_dialogs.gd`.
- **keys3 fails on `pre261`:** the File menu is 24 rows and 482 px tall,
  and keys3 holds it to 470. The walk read the same 482 px, and no menu
  scrolls. subexport, which adds an export row, was told to fold its rows
  into Export.
- **lights' one timing line** (below) is the save path's cost, accepted
  when lights merged, and metalines' to fix.
- **With Stress open, a click on a part puts the bin away,** at 1400 x
  900 as well as 1280 x 720. Its rail brings it back beside Stress, with
  Properties under it and every shelf in sight, so there was room for it
  all along. binrow's own probe brings it back the same way. A person
  loses the bin they were picking from on every such click. Small; in
  Next (binstay).
- **Make a part's "Far corner cut flat" is below the fold.** With Wedge
  chosen, the dialog's form ends at "Studs on top" at 1280 x 720, and the
  far-corner box is reached only by scrolling the form; at 1400 x 900 its
  top edge shows as a sliver under the summary. The walk's own line said
  "in sight", because it asked only whether the box was shown; the
  pictures say otherwise. makepart3's bar (the chamfer within 0.01 LDU)
  is met; finding it is not. Small; in Next (makerfold).
- **The walk's own:**
  - `round7`'s first run measured a closed bin: round six's last act
    closes it, and the bin's lines read "OUT OF SIGHT" for every shelf,
    even All. Its pictures show the bin on its rail. The rerun opens it
    first.
  - At 1280 x 720 the bin gives way to Properties when a part is
    selected, so `round6`'s bin lines read the last search there (3001),
    as in round seven. `words6` measured them at 1280 x 720 instead.
  - The first build's offer comes back after Help › Take the tour, by
    design.
  - The walk opens the car without the app's `opened` signal, so its view
    keeps the last zoom. In the first run that was the 1 x 1 plate's, 297
    px a stud, and the car's pictures at 1280 x 720 are a red wall; in the
    rerun it was the dish's, 60 and 79 px a stud, and the car is cropped
    at both sizes. A person's File › Open frames the model (`main.gd`).
  - Its "in sight" for a box in a dialog asks whether the box is shown,
    not whether its scroll shows it (makerfold, above). The next walk
    should test against the scroll's rectangle, as its shelf lines do.
  - Every Godot quit cleanly (exit 0).

## The web

`load_check` on live brickworks.diy (rel-m281), broadband:

| | appux6 (live rel-m268, load 28 to 30) | appux7 (live rel-m276, load 18 to 31) | now: live rel-m281, load 26 to 38 | from |
|---|---|---|---|---|
| first visit, cold, to working | 12.0 s | 10.2 s | **17.9 s** (19.6 and 16.1) | `load_check` |
| warm | 7.6 s | 6.0 s | **11.8 s** (13.3 and 10.3) | `load_check` |
| main thread, cold | 6.9 s | 5.7 s | 9.0 s | `load_check` |
| the engine's banner, cold | 4.6 s | 4.3 s | 5.3 s | `load_check` |
| the scripts' compile, cold and warm | 2.8 s and 2.8 s | 2.2 s and 2.2 s | **4.1 s and 4.0 s** | `load_check` |
| app ready (the scripts done), cold | 8.0 to 8.2 s | 7.0 s | 10.1 s (the second run) | `load_check` |
| a part from the bin to its ghost, the longest | 389 cold, 283 warm | 214 cold, 1,426 warm | 461 cold, 311 warm; 0 part files fetched for it | `load_check --pick` |
| bytes before working | 16.51 MB | 16.71 MB | 16.84 MB | `load_check` |
| a phone, 390 x 844: first frame, cold and warm | 12.1 and 7.7 s | 10.8 and 6.7 s | **16.6 and 12.6 s** (16.3 and 16.9; 12.5 and 12.6); the compile 4.1 and 4.5 s | `load_check`, a phone's viewport |

**Every number is worse, and the compile is twice round seven's.** It is
not explained here, and it may be the box. The load was 26 to 38 on 24
cores, against 18 to 31 for appux7, and the compile is one thread on a
CPU: APP_UX5 measured 4.4 s at a load of 32 to 41. The first screen's
source grew only a little: every script's source together went from 20.02
to 20.61 MB, and the bytes before working by 0.13 MB. But m276 to m281
added pdfcid's fonts, fetchparts' fetch and binrow's shelves, and nothing
measured them on the web at an equal load. **webstart9** (unit 1) settles
it with an ABBA at equal load before anything else is ranked above it.

The pick never fetched a part file for itself, and the longest pick is a
third of round seven's 1,426 ms (fetchparts). On a phone, `load_check`'s
"working" never comes, because a phone keeps the bin behind a button, so
its run says FAIL on that line alone, as before; the first frame is the
measure. The phone's run is `load_check` with a 390 x 844 touch context
at 3x, kept beside its log in the results
(`bench/results/appux8-2026-11-09/web/load_check_phone.mjs`).

## Over MCP: the walk's tasks as the owner's Claude does them

**The search** answers a session as the bin answers a person, and as it
did in APP_UX7's run, word for word: the same first parts for every word,
in 8 to 150 ms a word. 19 of the 25 words with a part to find put it
first. The others are the three the bin also ranks lower (jumper sixth,
macaroni fourteenth, bracket fourth) and three whose newer or variant
number comes first (3023b, 6141 for 4073, 3626c). "1x4 brick" put 3010
first, and "plate 1 x 1" and "1x1 plate" put 3024 first.

**APP_UX7's 45 tasks, again:** 111 calls in 11.7 minutes of the sessions'
own time, against 105 in 10.3. No task failed, and nothing done last time
was refused this time. The rows where the count or the answer moved:

| task | APP_UX7: calls, time | now | what the session did |
|---|---|---|---|
| three 1 x 4 plates stacked, merged into a brick | 2, 7 s | 3, 14 s | two `edit_model`s, then `merge_parts` |
| a beam 7 standing, a pin in its second hole | 11, 87 s | 13, 86 s | a stand again, unasked: the session, not the app |
| the angle between the beam's holes and the wall | 0, 5 s | 0, 3 s | 90°, from the beam it had built along z (0° last time, built along x) |
| move the top row three steps later | 3, 12 s | 6, 21 s | `edit_steps next` three times, not `to`. The automatic steps had put the end brick in step 7, so it could move only one step, and it said so |
| a side pod of five parts, in words | 5, 39 s | 7, 40 s | a clear, two searches, `attachment_points`, one `submit_design`, two looks |
| a short video of the model built up | 2, 32 s | 3, 54 s | `render_model` build and two waits on its job |
| a green 16 x 16 plate, Pods into it, whole | 3, 14 s | 0, 10 s | it found Pods 27 studs long and asked which way to go before building anything. intomodel3 still waits on keeptext5 |
| a short video of the build, and what happens in it | 2, 37 s | 4, 69 s | `render_model`, two waits and a step list |
| the pods' parts kept as a palette, "Pod parts" | 1, 8 s, **refused** | **1**, 7 s, **done** | `edit_palette` make: six parts, each once in its colour, under the bin's Palettes (mcppalettes) |
| a plain 1 x 1 plate, and the 1 x 1 brick with a stud on its side | 0, 4 s | 0, 4 s | 3024, and **87087 "1 × 1 studs and 1 brick tall"**, where it read "1 x 2" before (mcpwords) |
| take back what you added | 2, 8 s, refused | 2, 8 s, refused | the lots are "under another chat" (takeback, waiting) |
| 7140 in my collection, two white 1 x 2 plates missing | 1, 9 s, refused | 1, 10 s, refused | it found 7140 has none, and cannot add a set (keptbuilt, waiting) |

Every call of every task is in
[app_ux8/mcp_walk/calls.txt](app_ux8/mcp_walk/calls.txt).

**Round seven's own:**

| task | calls, time | what the session did |
|---|---|---|
| x1: a 4740 dish on a 6141 round plate, the way sets have it | 5, 22 s | placed in one `edit_model`: "the plate's stud goes into the dish's centre tube, so the two hold together as one piece", half a stud off the grid as it must be. `find_techniques` named 76042, 6353 and 6516, which mount the dish the same way up on a tap or a bar (seatfix) |
| x2: a cover in Russian and Greek, saved as a PDF | 4, 14 s | the cover drawn with every letter as typed (pdfcid), **but no PDF**: `export_model instructions` writes an HTML booklet, and no tool writes the PDF the window does. The session said so and sent the person to the window |
| x3: a left 4 x 2 wedge plate with 54383's far corner, and a 1 x 1 clip plate on a stud | 6, 21 s | real parts again: 41770b, "Wing 2×4 Left with Chamfer", and 15712, the clip seated 0 mm and 0° off, measured. Nothing needed making, rightly |
| x4: a spotlight over the pods, and a picture in the dark | 3, 12 s | `light_model` spot, a 53° cone 9.5 studs up, then `render_model light=dark` (lights). **The picture replaced the "Three quarter" one of the same name.** The session noticed by the name; the app said only "wrote" |
| x5: a 3MF; will my slicer read every part as a closed solid? | 1, 11 s | "**I can't tell you that** … Expect the slicer to do some repair." The file is solid (print3mf2, 7 objects of 7), but the export's answer says only "44 parts, 23,038 triangles — 4 colours, an object each", so the session told the person the opposite of the truth. It also replaced the earlier pods.3mf |

**Past parity, asked in a person's words** (a new session, from a cleared
model):

| task | calls, time | what the session did | the feature |
|---|---|---|---|
| n1: a bridge of two 2 x 2 towers and 1 x 8 plates; will it hold a minifigure, and where is it weakest? | 8, 47 s | built it, stood a figure in the middle, then `check_design` and `weakest_joints`: it holds. Weakest are tipping front to back (force angle 10°, 1 stud inside the edge) and each deck plate on one stud a tower. That a deck lifted or twisted pops off was the session's own reasoning: the app does not lift (loadtest) | a build that checks itself |
| n2: could an eight-year-old build it in the booklet's order? | 3, 16 s | yes: no part under another or in the air. And what steps_score does not count: nothing fixes the towers' spacing until step 4 | instructions that teach |
| n3: easier for a six-year-old, fewer parts a step, each step's parts beside it | 17, 35 s | 9 steps of at most two parts, the parts boxes kept. It caught its own head-before-body and fixed it. 17 calls by hand, because no one call does it (agesteps, Next) | instructions that teach |
| n4: a 24-tooth gear driving an 8-tooth, each on an axle in a Technic frame; the turns, and a video | 13, 77 s | built and checked it ("brick 31 meshes brick 32: a 24 with an 8"), **but `simulate_mechanism` refused twice: "the 24 tooth gear … does not turn on anything: it is floating"**, while `move_part` turned it and its train. The 3 turns came from the teeth and the video from a saved motion. The train stands apart from the bridge, and Simulate seems to take one ground for the whole model (kinefuncs' first case) | a model that moves |
| n5: a small car from only the parts in my collection | 4, 43 s | read the collection (34 pieces in three lots), built a 26-piece car from them, and `parts_list need` to confirm: nothing needed. Done by the session's own care; ownlimit makes it the app's | owned parts driving designs |
| n6: a fire engine at a City set's quality, about 150 parts, and how it compares | 65, 5.8 min | saved the bridge first, then 158 parts and a firefighter, through `plan_scale`, `how_real_sets_build_this`, 14 checks, `fresh_eyes` and `review_model`, and said plainly where it falls short: about 7 colours against 9, 27 shapes used once or twice against 46, 13% of parts turned sideways against 23%, no curves (design20) | set quality on the person's own Claude |
| n7: my friend wants to build this with me at the same time, from their computer | 1, 12 s | "**I can't set up a live session** … None of my tools can share a model with another computer", and an .mpd to send. Together does exactly this. It is the person's to open (`WINDOW_ONLY`), but nothing tells a session it exists, so the session said there was no way | real-time collaboration |

The seven took 111 calls in 9.6 minutes. All 57 tasks took 241 calls in
22.6 minutes.

**Where a session still needed more than the window, or guessed:**
1. **It told the person a solid 3MF would need repair** (x5): the export's
   answer does not carry print3mf2's own check (mcpreach).
2. **It could not hand over the booklet's PDF** (x2): no tool writes it
   (mcpreach).
3. **A picture or an export replaces the last one of its name** without a
   word in the answer (x4, x5). With no one to ask, `exports.gd` writes to
   Downloads under a fixed name (mcpreach).
4. **It said live collaboration cannot be done** (n7): Together is the
   person's to open, and a session is never told it exists (mcpreach).
5. **Simulate calls a working gear train floating** (n4), where `move_part`
   turns it (kinefuncs).
6. **A lift is the session's guess** (n1): loadtest.
7. A resumed chat still cannot take back what it added (takeback), and a
   set still cannot be added (keptbuilt). Both wait on keeptext5.

## Round seven, item by item

Each merged unit's bar, read off its own probe today on the snapshot.
"Met" means every line of the bar that ran today passed; the numbers are
today's.

| unit | its bar | today |
|---|---|---|
| typingkeys | F1, F9, Ctrl+Shift+B, Alt+X and Ctrl+S in 1 press each with the bin's search focused; 0 commands from typed letters | **met**: 39 checks at 1400 x 900 and 39 at 1280 x 720, none failed. Each key in 1 press from the bin's search, Find's field and the assistant's brief, under 4 presets; typed text runs nothing; Ctrl+A, C, X, V and Z act on the field. The walk at both sizes: F1, F9 and Ctrl+Shift+B in 1 press each with the search focused |
| binrow | all eight shelves unscrolled at four sizes with Stress open; Like this back to Plate 2 x 4 seventh at 1280 x 720; a New shelf | **met**: 23 checks, 12 on the tablet and 12 on the phone, none failed. Every shelf in sight, unscrolled, at 1400 x 900, 1280 x 720 and 1024 x 768, as the bin first opens and with every column open; on the tablet's and the phone's parts sheet too. Plate 2 x 4 seventh at 1280 and 1400. New: 282 parts, "slope" narrows it to 31, every new slope among them. The walk: every shelf in sight beside Stress and Like this chosen, at both sizes, once the bin is brought back by its rail |
| fetchparts | 0 HTTPRequest calls for geometry; the car's shapes in half `pre261`'s time; the longest frame 506 ms or less on a laptop and 564 on a phone | **met on a laptop, missed on a phone** (its `ab8` report, not run today): 0 engine fetches; the car's shapes in 0.32 of the time on a laptop and **0.52 on a phone** (bar 0.5); the longest frame 479 ms on a laptop and **1,198 on a phone** (bar 564, before 1,641) |
| mcppalettes | a palette of 12 parts and a sub-assembly made in 1 call, the bin's byte for byte; listed and placed in 1 call each, 0.01 LDU; the MCP walk's w7 in 2 calls | **met** for its gated lines: 34 checks, none failed. Castle's twelve in their colours made in 1 call; its file entry the bin's own byte for byte (635 and 635 bytes); listed in 1 call; 4 parts placed in 1 call, each to 0.01 LDU. The MCP walk's w7: "Pod parts" made in **1 call**, where APP_UX7's session was refused |
| seatfix | 4740 on 6141 at 0.00 LDU by hand and over MCP; four sub-models at 0.00; harvest 963 or more | **met**: `seatfix` 33 checks, every distance 0.00; `animals` 63 of 63 and 27 of 27 saddles, the worst 0.00; `harvest` 963 of 1,056 (floating 27, collisions 8, overlap 24, not held 34). The walk at both sizes: the dish seated by hand, 0.00 across and 8.00 above. Over MCP (x1): seated in one edit, "the two hold together as one piece" |
| print3mf2 | lib3mf's `IsManifoldAndOriented` for each of the car's 7 objects; every edge shared by two triangles; the size within 0.1 mm; triangles no more than twice | **met**: 31 checks. 7 of 7 objects manifold (from 0 of 7); 0 of 44,328 edges unshared; 0.0000 mm off; 1.19 times the triangles. GLB and STL sameness is from its report |
| pdfcid | Cyrillic, Greek and Japanese read back by `pdftotext` as typed, 0 "?"; the export names none missing; a Latin booklet the same | **met** for what ran: `booklet_pdf` 74 checks, none failed. "Крепость у моря — сборка", "Οδηγίες συναρμολόγησης" and "城の門を組み立てる、二つ目の手順" read back as typed, with 0 "?" in the whole PDF; every font embedded, cut down to its letters and mapped to Unicode. The Latin booklet's pixels against the commit before are from its report. Hebrew and Arabic print reversed: pdfbidi, running |
| mcpwords | over MCP 87087, 4733 and 30414 read as the bin reads them; the walk's 30 words described in the bin's words; w8 in 1 call | **met** for its probe: `words6` 33 checks at each size. The MCP walk's w8: 87087 is "1 × 1 studs and 1 brick tall", in 0 calls from what the session had read (APP_UX7: "1 x 2") |
| makepart3 | a made clip on a stud 0.00 LDU up (from 1.448); 54383 copied within 0.01 LDU, chamfer and all (from 29); the other families unchanged | **met**: `element` 235 checks; the clip 0.00 up, like 61252; bw-wedge3x6rc's bounds 54383's to 0.0000 LDU and its connectors the same; `element_files` 270 and `element_shot` 39, none failed. The walk: "Far corner cut flat" offered, below the dialog's fold at both sizes (not in the bar; Found on the way) |
| a11ymodal | every open dialog modal in the accessibility tree; a window close still heard in 1 to 2 ms | **met** for its probe: `a11y_modal` 37 checks, none failed; 12 of 12 dialogs that held the window modal to a screen reader, Brickify's chooser among them, the focus inside each. The close times are dialogclose's, not run today |
| edges | Edges off draws 0 px of seam; Studs off draws no stud and keeps every part's place; kept as a preference; the default view unchanged to the pixel | **met**: `edges` 25 checks at 1400 x 900, none failed. Edges off draws 0 px of seam on the red and black walls (3,671 and 2,845 before); Studs off draws 0 of 8,142 stud pixels, moves 0 of 15 parts, and leaves the car 30% fewer triangles; on again, each picture the first to the pixel; both kept in `controls.cfg` over a restart. The walk: each off and back on |

Round six's lights, merged in this round: `lights` 73 checks, one timing line failed. A spot over the car, its cone 53°, Dark, the lights kept over save, autosave, a step edit and an open, `light_model` over MCP, and 11 light lines of someone else's kept where 8 are read. The line that failed: 200,000 junk light lines saved in 1.93 times the time of as many comments, against 1.5, at a load of 43 to 49. The lead accepted 2.09 times when lights merged; the save path's cost is metalines'. The walk: Bulb, Spot, Sun and the Light panel in Render's Add row

Also run, because round seven's units changed what they test: `noai`
92 checks, `mosaic_window` 17, `mosaic` 80 checks and
`art_counts` 54, none failed.

Round seven planned twenty-five units, and ten are merged: typingkeys,
binrow, fetchparts, mcppalettes, seatfix, print3mf2, pdfcid, mcpwords,
a11ymodal and makepart3. Round six's edges and lights merged in the same
days. **Nine met every line of their bars that ran today.** fetchparts met
its bar on a laptop and missed it on a phone: the shapes came in 0.52 of
the time against 0.5, and the longest frame was 1,198 ms against 564
(better than the 1,641 before it). Lines read from reports and not run
today: pdfcid's Latin pixels, print3mf2's GLB and STL, a11ymodal's close
times, and the whole of fetchparts. Five are running (donenote, subexport,
rarity, lineart and sitepickabrick, with pdfbidi beside them), and ten
wait on keeptext5 and the units after it.

## What the field does that Brickworks does not, yet

The latest versions, as of 9 November 2026:
- **Studio 2.26.10_1** (27 October), unchanged. Its help centre lists 125
  articles, none edited after 25 September.
- **LeoCAD 26.09**, and the continuous build of 5 November APP_UX7 read;
  nothing newer.
- **StudWorx 2026-11-08**, republished at 22:52Z with five changes in its
  notes (below).
- **LDCad 1.7 Beta 2b**, **Bricksmith 3.1** (2022) and **LPub3D 2.4.9**
  (January 2025; its last continuous build March 2025), unchanged.
- **Mecabricks**: no release. Its forum has a thread from 9 November in
  which several people's projects answer "error 404"; that is an outage,
  not a feature.
- **Phone apps:** Noppi 1.0 (28 October), new to these rounds; BrickMaster
  AI 1.0.4 (8 November) and BrickSnap 1.3.18 (6 November), both new here
  but doing what the bin's photo search and Brickify already do.
- **AI, agent and web tools:** brick-flow-agent and rebrick-me, new;
  Kinebrick's least-motion check (9 November); Brickyard and BrickCheck,
  with new commits; brick-tidy, BrickBuilder AI and lego-build-video with
  small ones.
- **Papers:** BrickBench (arXiv 2610.12452) and BrickWright (2610.31651)
  are already in [RESEARCH.md](RESEARCH.md) and COMPETITIVE. arXiv,
  Hacker News and the LDraw forum have nothing newer for a builder.
  Rebrickable refused readers again (a JavaScript wall); its Build
  settings page was read through the Wayback Machine (28 June).

Each item was checked against `shell.gd`'s commands,
`tools/mcp_tools.json` and the files named. Each list is ranked by how
much a person building would feel it.

**The desktop tools**
1. **Find and Replace that reaches every sub-model** (StudWorx
   2026-11-08). The bar floats over the view. Its part list shows each part
   in the colours it is used in, and flags a part used in more than one
   colour. Replace in Submodels makes Replace All reach every sub-model.
   - Brickworks finds by number or name (`select_find`) and replaces the
     selection with the part in hand (`edit_verbs.gd` `replace`). It has
     no colour list, no flag, and no Replace All inside sub-models.
     APP_UX6 counted plain find and replace as covered; the sub-models and
     the colours are new.
2. **A Missing and Moved Parts list on open** (StudWorx). It lists every
   part that could not be loaded or is marked moved or an alias, offers
   the part each points to, and replaces the checked ones in every
   sub-model in one undo.
   - Brickworks reads a `~Moved to` part as the part it moved to
     (`parts_only.gd`, `part_library.gd`), so it draws, but the file keeps
     the old number and nobody is told. A part with no file at all is
     drawn as missing; askfirst, queued, asks about those before laying
     the model (`model_store.gd`).
3. Smaller:
   - **the sub-model under the pointer outlined** (StudWorx's Submodel
     Hover Outline); Brickworks outlines the selection only;
   - **a joint's right-click menu** (StudWorx's Joints tree). Brickworks
     finds its joints itself and has no joints tree, so there is nothing
     to put a menu on: not a gap.

**Phone and web tools**
1. **Designs held to what the person owns, by hand and by the AI alike**
   (brick-flow-agent: per-part inventory limits "shared by manual editing
   and the LLM").
   - Brickworks: Brickify lays a shape from the collection
     (`collection: true`), and What do I need? counts what is short. But
     the bin never says how many of a part are left, and `submit_design`
     has no way to hold a design to the person's parts.
2. **Weak joints fixed for the person** (brick-flow-agent:
   inventory-aware reinforcement proposals, undoable). Brickworks' Stress
   shows each joint past or near its working load and steps to it
   (`stress_panel.gd`), and stops there.
3. **Every set ranked by how much of it is owned** (rebrick-me 0.4.0,
   about 28,000 sets; Rebrickable's Build). Brickworks' What can I build?
   ranks the examples, the person's own models and the official LDraw set
   models (`collection_dialog.gd`), although `set_inventories.gd` holds
   Rebrickable's inventory of every set.
4. **A pile counted from one photo** (Noppi 1.0: every piece outlined,
   named and counted, 240 parts, then what can be built; Brickit before
   it). Brickworks' photo search asks Brickognize for one part a picture
   (`brickognize.gd`). A pile needs a detector that Brickognize's API does
   not offer, so this is not ranked (Next).
5. **A lift, a push and a drop** (brick-flow-agent's lab has wind, rain
   and earthquakes, with the failure spreading and a score). Brickworks
   weighs the model standing still. A person lifts a model by its roof
   and pushes a car along; nobody puts a model in a gale. So the lift and
   the push are planned (loadtest), and the weather is not.
6. **The functions of real sets checked** (Kinebrick: all 186 sets, 517
   functions working, 42%, on its main branch; 449 with least-motion
   drags). Brickworks' Simulate turns gears, linkages and motors, and says
   where a mechanism hits itself and whether its motor stalls
   ([MECHANISMS.md](MECHANISMS.md) 39). It has never been measured on a
   set's own functions.
7. **SPIKE Prime motors, true to size, and one program for the screen and
   a real hub** (Brickyard: 175 and 185 rpm, 25 and 18 N·cm at 7.2 V;
   Pybricks' terms). Brickworks' stall table has Power Functions, the
   E-motor and 9 V motors, and no SPIKE or Powered Up motor. A real hub
   is a device, so that half is parked.
8. Smaller:
   - **support hull and redundancy** (brick-flow-agent): Check stability
     already says the margin to the edge and the tilt that tips it ("1.9
     studs inside the right edge, a 34° tilt"); a part held by one joint
     only is not named as such;
   - **checking a set with others** (BrickCheck's groups): still low, as
     in APP_UX7.

Checked and **not gaps:**
- brick-flow-agent's per-brick risk colours and tipping margin (Stress,
  Check stability), and its large-scene work (bigedit, `paced`);
- rebrick-me's named bins (partplaces, planned in APP_UX7);
- Rebrickable's colour sensitivity and its prints and moulds ignored
  (`Collection.as_its_set`, "in another colour" in What do I need?);
- BrickBuilder AI's OBJ, GLB and STL exports, and BrickSnap's mosaics and
  models from a photo (Export, Mosaic, Brickify);
- BrickMaster AI's single-part scan into a collection (the bin's photo
  search and My collection);
- lego-build-video's set found by name and its motion through ldraw-mecha
  (the library's set models; drive);
- StudWorx's new empty step on open (APP_UX7: already done).

**Round seven's "Next",** where each stands:
- donenote, subexport, rarity, lineart and sitepickabrick are running;
  print3mf2, pdfcid, mcpwords, a11ymodal and makepart3 are merged;
  stepsearch, partplaces, carryrest, filmsound and realjoints5 wait on
  keeptext5 and the units after it.
- Round six's queue: edges merged; video2 is running; modsteps waits on
  stepnames, watchfile on keeptext5 and panelside on watchfile.
- Not ranked then, and not built since: the model so far as a page,
  pictures of a range of steps, a Hide tool's count, a ground that follows
  the lowest part, BrickCheck, dual-moulded colours, the number colour's
  swatch and the twist in the phone's hint, a compare by shape in any
  colour, SOCIAL's mail and More like's why, and the carried list.

**The lead's candidates** (`queue.md`):
- **kt5review's #8:** a STEP inserted or removed is written as a whole
  rewrite of the lines after it, not as its own change (stepops).
- **A step edit on one copy of a sub-model placed twice spreads to the
  other on reopen** (snreview; live too): sent to copyfaults' brief.
- **TITLE and FLOOR GRID written LF into CRLF files:** sent to metalines'
  brief.
- **'det == 0' errors in `grab`** (`mechanism.gd` 575, `_rest_on_studs`,
  42125-1's steering): mechdet met for the groups; the full 25-minute
  `grab` is folded into kinefuncs, which runs it.
- **`touch_sizing.gd`'s typed loop over freed dialogs** raises a SCRIPT
  ERROR (lines 292 and 350): folded into fingertools.
- **keys3: the File menu is 482 px tall against its 470** on `pre261`:
  subexport was told to fold its rows into Export.
- **`model_view` once answered `initialize` with no capabilities** (76 of
  81 tools): one sighting, not a unit until it is seen again.
- **Godot's own Save dialog holds a window close** until it closes: the
  desktop's, which is paused.
- Closed since APP_UX7: Export's direct colours (directcolour), the
  flows' scroll race (flowscroll).
- Tooling, not units: sticker aiming about 8 times slower from 1,000 to
  5,000 parts, still under 1 ms; `age_flow`'s `--trust-stand-in`.

**SOCIAL.md's and ROADMAP.md's open rows a unit could move**
- **SOCIAL's plan rows 1 to 6 are built:** achievements with levels
  (`achievements.sql`), challenges told in Notifications
  (`challenge_notices.sql`), @mentions (`comment_mentions.sql`), the 3D
  embed and Based on. Rows 7 to 9 (the week by email, builds as a gallery
  tab, people to follow) are "low now" in SOCIAL's own words, while the
  gallery has one designer. The beta release is about to change that, so
  they are named in Next, to be ranked once the beta's first weeks show
  who comes.
- **ROADMAP's designer quality:** design16 to design19 were NO-GO, and
  design19's record names silhouettes as the next lever (design20).
- **RESEARCH unit 3, a measured accuracy for stability,** is not done
  (stabletruth).
- Measurements, not units: proportion as a norm, co-occurrence data,
  `hinge: true` tried by a run, and a run's length (ROADMAP levers 2, 5, 6
  and 7).

## Past parity: what no tool has

The brief named seven features, as examples to judge, not a list to take
on trust. Each is judged here on three things: what Brickworks has today,
what the field has (from its own pages), and what a person building would
feel. Five are worth a unit now. Collaboration is already past the field.
A phone that builds as well as a desk has to be measured before it is
planned.

**1. A build that checks itself as it is made.** Worth most of the
seven: a builder meets it every minute, in every model.
- **Brickworks today:**
  - The status bar weighs every joint on a worker each time the model
    changes, and says "stands up" or names the weak joints (`main.gd`
    `_weigh`, `Stability.Report.summary`).
  - Stress colours each joint by its margin, and steps to the worst
    (`stress_panel.gd`).
  - Check stability (Alt+K) says whether it tips, and by what tilt: the
    car "stands, 1.9 studs inside the right edge (a 34° tilt tips it)", in
    12 to 32 ms across the walk's runs.
  - A part placed into another is refused by its exact shape.
  - The build check flags a step's parts that float: 4% of the parts the
    sampled steps add, against 3% for the authors
    ([INSTRUCTIONS.md](INSTRUCTIONS.md)).
- **The field:**
  - Studio checks on demand, and its own help calls the check "very
    conservative: it often flags parts that are actually well connected".
  - brick-flow-agent colours each brick by risk, draws the support hull,
    gives a tipping margin and redundancy, and proposes reinforcements.
  - BrickSim (100% on 150 real builds) and StableLego (99.56% on 225)
    are research code; neither covers Technic or hinges.
- **What is missing:**
  - **Nobody, Brickworks included, says how often its check is right.**
    Brickworks' clutch is one constant, `GRAMS_PER_STUD` = 80 g, never
    measured against a real build (RESEARCH unit 3, not done).
  - **A weak joint is shown, not fixed.**
  - **A model is weighed standing, never lifted.**
- **Judged:** past parity already on "as it is made" (no other tool weighs
  every change), behind the research on "right". Units:
  - **stabletruth** makes the check right, and says so with a number;
  - **strengthen** fixes a weak joint in one action;
  - **loadtest** lifts a model by a part and says what comes away.

  Over MCP (n1), the person's Claude built a bridge, stood a figure on it
  and named its weak points in 8 calls, from the app's own checks: a
  force angle of 10°, and a deck plate on one stud a tower. What a lift
  pulls off was its guess.

  "Buildable by a person's hands in order" belongs to the instructions
  (2).

**2. Instructions that teach.** Worth nearly as much: a booklet is what
turns a model into something another person can build.
- **Brickworks today:** it plans its own steps and measures them against
  the authors of LDraw's official models, who follow the LEGO® booklets
  ([INSTRUCTIONS.md](INSTRUCTIONS.md)):
  - one step in thirteen floats something (7.5%), against one in eighty
    for the authors;
  - 5.7% of parts go in under one already there, against 0.9%;
  - one step in eight hides a new part (12.1%), against one in fifteen;
  - the order agrees with the authors' at Kendall's tau 0.29.
- **The field:** Studio's Divide into steps "works best on simple builds
  where the studs are on top", and its help tells a person to peel the
  model by hand otherwise. LPub3D lays out steps a person made. No tool
  measures its steps against the LEGO® booklets.
- **Judged:** Brickworks is the only tool that plans and measures, and it
  is still far from the LEGO® booklets on all three counts. A person following
  the booklet feels each one as a part that cannot go where the page
  says. Unit **buildorder**.
- A booklet for an age (fewer parts a step for a six-year-old) is the
  next step after it. It needs each set's age band, which the catalogue
  does not hold, so it is in Next. Over MCP (n3) the person's Claude made
  one by hand, 9 steps of at most two parts, in 17 calls; and asked
  whether a child could build in order (n2), it found what no measure
  counts: nothing fixes the towers' spacing until the deck goes on.

**3. A model that moves.** High for a Technic builder, middling for the
rest.
- **Brickworks today:** Simulate turns gear trains and linkages, finds
  where a mechanism hits itself (to 0.01°) and how far it goes, and says
  whether a Power Functions, E- or 9 V motor stalls under the weight it
  lifts ([MECHANISMS.md](MECHANISMS.md) 39). Drive (running) moves the
  whole model.
- **The field:**
  - Kinebrick checks the functions of all 186 Technic sets it knows: 517
    work (42%) on its main branch;
  - Brickyard drives SPIKE Prime motors true to size from one program,
    on the screen or a real hub;
  - ldraw-mecha animates mechanisms.
- **Judged:** "physics a person can trust" means a person's own question
  answered right on a real set: does the steering turn, does the boom
  lift. A falling-bricks simulation is not that question, and is not
  planned. Units:
  - **kinefuncs** measures Simulate on Kinebrick's 186 sets and fixes
    what it fails;
  - **spikemotors** adds the motors people build with today;
  - **hubprogram** (in Next) runs a program on them, on the screen only.

  Over MCP (n4), Simulate refused a 24-to-8 gear train the session had
  built right beside a bridge: "does not turn on anything: it is
  floating", while `move_part` turned it. That is kinefuncs' first case.

**4. The parts the person owns driving every design.** High: most people
build from what they have.
- **Brickworks today:**
  - Brickify lays a shape from the collection;
  - What can I build? ranks models by how much is owned;
  - What do I need? counts what is short, in the colour or in another
    colour;
  - Build from my bricks turns the bin into the person's own.
- **The gap:** none of it holds a design to the person's counts. The bin
  shows no count left, and the person's Claude can design with parts
  nobody owns. brick-flow-agent shares one limit between the hand and the
  AI.
- **Judged:** a real gap, and Brickworks already holds every piece of
  data it needs. Unit **ownlimit**, after keptbuilt (a built set is not
  free) and rarity (the bin's tiles). Over MCP (n5) the person's Claude
  kept a car to the collection by its own care, in 4 calls; nothing in
  the app would have stopped it using a part the person lacks.

**5. The assistant designing at set quality on the person's own
Claude.** The owner's first measure: realset's win rate against real
LEGO® sets on the 44 held-out subjects, on the connector path.
- **Today:** 26% overall (15 to 41), likeness 34%, technique 16%,
  creativity 44% (`realset-2026-11-04-d15l44`).
- **The last four levers were NO-GO:**
  - design16 and design17 (proportions);
  - design18 (the photo reached every session and won nothing);
  - design19 (the right photos, 4 of 4; the sessions kept 9 of 10 of the
    differences they measured, and still did not win).

  design19's record names the next lever: the silhouette, the outline of
  the model against the outline of the set from the same side.
- **The field:** BrickBench's leaders score 1.00 valid only through their
  harness, BrickAgent; without it, validity falls to 40%. No tool designs
  against real sets on a person's own subscription.
- **Judged:** the most valuable of the seven if it works, and the
  riskiest. Unit **design20**, with its NO-GO written down if it fails.
  Over MCP (n6), a 158-part fire engine took 65 calls and 5.8 minutes,
  and its own review against real City sets said where it falls short:
  fewer colours, fewer one-off shapes, less turned sideways, no curves.

**6. Collaboration in real time.** Already past the field.
- **Brickworks today:** Together runs in the browser, with presence,
  undo per person, chat and follow.
- **Studio's Build Together:** one person hosts on a network port on
  their own machine, and each person needs their own BrickLink account.
- **Judged:** a builder would miss pointing at a part for the others to
  see. Unit **pointat**, small.
- **But the person's Claude does not know it is there.** Asked to set up
  building with a friend (n7), it said "I can't set up a live session".
  Together is rightly the person's to open (`WINDOW_ONLY`: "theirs to
  decide"), but no tool's words name it, so a session cannot send the
  person to it. mcpreach names it.

**7. A phone that builds as well as a desk.** High: the web is the way
in, and a phone is the screen most people have.
- **Brickworks today:**
  - the bin, placing, two-finger twist and pinch, and touch-sized
    targets;
  - no touch in Measure, the move handles, the page editor, Pose or
    Simulate.
- **The field:** no CAD in the field builds on a phone. Mecabricks runs
  in a tablet's browser, and the phone apps scan parts or show
  instructions.
- **Judged:** worth a full round, but nobody has measured the walk by
  finger. Units:
  - **phonewalk** measures it;
  - **fingertools** gives Measure and the handles to a finger now;
  - **phonepanels** does the rest once the running units free its files.

**Not among the seven, and judged worth naming:** every set ranked by how
much of it is owned (setsbuild); Find and Replace that reaches every
sub-model (swapfind); and a pile counted from one photo (Noppi), which
waits on a detector (Next).

## The gaps and the features, by value to a person building

Round seven's open gaps (APP_UX7's copyfaults, metalines, heldsteps,
keptbuilt, takeback, partplaces, carryrest, stepsearch, filmsound and
realjoints5) keep their ranks and their bars. They wait on keeptext5 and
are not ranked again here. The first three are silent data loss, and they
stay above every new feature below. This list is what round eight adds.

1. **The web's first visit measured at nearly twice round seven's
   time:** 17.9 s cold and 11.8 s warm, the compile 4.1 s against 2.2.
   It may be the box's load. Nobody has measured m276 against m281 at an
   equal load, and with the desktop paused, the first visit is the first
   thing every new person meets. It is measured before anything else is
   built on it (webstart9).
2. **The assistant's designs lose to real sets three times in four**
   (realset 26% overall on the connector path). The owner's first
   measure. design19 names the next lever, the silhouette (design20).
3. **The booklet's steps float, bury and hide parts** six to eight times
   as often as the authors' do: 7.5% of steps against 1.25%, 5.7% of
   parts under one already there against 0.9%, 12.1% of steps hiding a
   new part against 6.7% (buildorder).
4. **Nobody knows how often "stands up" is right.** The clutch is one
   number never measured, and no CAD publishes its check's accuracy. A
   measured check is a claim no competitor can make (stabletruth).
5. **A design can use parts the person does not own,** by hand or by
   their Claude, and the bin never says how many are left (ownlimit).
6. **Nobody has walked the app by finger.** The web is the way in, and a
   phone is most people's screen. Measure first (phonewalk).
7. **Simulate has never been measured on real sets' functions,** and it
   called the MCP walk's working gear train floating (n4);
   Kinebrick has, on 186 (kinefuncs).
8. **A weak joint is shown and not fixed** (strengthen).
9. **Replace stops at the top level:** a part in a sub-model is replaced
   copy by copy, with no list of the colours a part is used in
   (swapfind).
10. **Measure and the move handles do nothing by finger** (fingertools).
11. **The person's Claude is told less than the window shows,** and so
    tells the person wrong: that a solid 3MF will need repair (x5), that
    the booklet cannot be a PDF (x2), that nobody can build together live
    (n7). And an export or a picture it makes replaces the last one of
    its name without a word (x4, x5) (mcpreach).
12. **What can I build? ranks only the sets with a model file,** though
    every set's inventory is already in the app (setsbuild).
13. **A model is weighed standing, never lifted:** pick a car up by its
    roof, and nothing says what comes away (loadtest).
14. **The page editor, Pose and Simulate do nothing by finger**
    (phonepanels).
15. **A moved or missing part is drawn, or asked about, but never
    replaced in the file** (movedparts).
16. **No SPIKE Prime or Powered Up motor in the stall table** (spikemotors).
17. **Nobody in a Together room can point at a part** (pointat).
18. **A step added or removed rewrites every line after it** in the kept
    text, where it could write its own change (stepops).

## The units

Eighteen, ranked, each in its own worktree off the next stage. The
shared registries are the same as round seven's. A unit adds its own lines
in a block of its own and changes no one else's:
- `src/ui/shell.gd`'s `_define` and `MENUS`;
- `src/ui/keymap.gd`'s `PRESET_KEYS`;
- `src/net/app_tools.gd`'s `COMMANDS`, `WINDOW_ONLY`, `GUIDE`, its tool
  list and its dispatch, and each tool's own answer function;
- `tools/mcp_tools.json`, written by `mcp_sync_probe --write`;
- `docs-site/generated/menus.json`;
- `src/ui/language.gd`'s tables and `locale/*.po` (every new word in
  German, French and Spanish);
- `tools/suite/*.txt`, one line a new probe.

Every feature added gets its entry in `.claude/skills/verify/` in the same
commit, and every unit runs `tools/release/unit_preview.sh` on its final
sha before it says ready. A unit that writes the model file or the
collection (swapfind, movedparts, stepops, ownlimit) gets an independent
review before it merges, and attacks its own save path before it says
ready. None of the eighteen needs the owner.

**The files the running units own,** read from their worktrees today.
Nothing in wave 1 touches them:
- keeptext5: `builder.gd`, `assemblies.gd`, `carry.gd`, `custom_parts.gd`,
  `ldr_model.gd`, `model_store.gd`, `source_file.gd`, `brick_world.gd`,
  `main.gd`;
- drive: `motion_player.gd`, `motions.gd`, `pose_panel.gd`, `main.gd`,
  `app_tools.gd`;
- stepnames: `instructions.gd`, `build_steps.gd`, `builder.gd`,
  `booklet.gd`, `booklet_looks.gd`, `booklet_maker.gd`, `build_mode.gd`,
  `steps_bar.gd`, `shared_pages.gd`, `build_party.gd`;
- localbricks: `collection_store.gd`, `set_bin.gd`, `collection_dialog.gd`;
- hudfront: `main.gd`, `page_editor.gd`, `render_dialog.gd`,
  `collection_dialog.gd`, `controls_dialog.gd`, `inventory_panel.gd` and
  eleven other dialogs;
- a11ynames: `pose_panel.gd`, `simulate_panel.gd`, `exports.gd`,
  `flex_tool.gd`, `access.gd`, `whats_this.gd`;
- a11ytree: `access_tree.gd`, `placed_window.gd`, `view_cube.gd`;
- rarity: `part_library.gd`, `parts_bin.gd`, `tools/collection_data.py`;
- video2 and lineart: `render_dialog.gd`, `studio_render.gd`,
  `build_render.gd`, `render_output.gd`, `render_settings.gd`;
- donenote: `main.gd`, `later.gd`, `chat_panel.gd`, `render_queue.gd`;
- subexport: `exports.gd`, `outliner.gd`, `submodel_file.gd`;
- pdfbidi: `booklet_pdf.gd`, `booklet_png.gd`;
- bugreport, betajoin, betahome and sitepickabrick: `api/` and `web/`;
- docshots: `tools/docs_shots.py`, `docs_site.py`;
- flowaccount: `tools/web/browser.mjs`, `session.mjs`, `dialogs_flow.mjs`;
- queued: askfirst (`model_store.gd`), lightpaths and intomodel3 after
  keeptext5.

| # | unit | gap | size | risk | wave | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|---|
| 1 | **webstart9** | 1 | S, M if it finds a cause | low | 1 | new `tools/web/start_abba.mjs`; a fix's files as the measure names them (a running unit's file waits for it) | see below |
| 2 | **design20** | 2 | L | high | 1 | new `src/ai/silhouette.gd`; `src/ai/model_shot.gd`; `review_model`'s answer and `submit_design`'s review in `app_tools.gd`; new `src/dev/silhouette_probe.gd` | see below |
| 3 | **buildorder** | 3 | L | high | 2 (after stepnames) | `src/assembly/instructions.gd`, `src/assembly/build_steps.gd`; `tools/steps_score.py` read only | see below |
| 4 | **stabletruth** | 4 | M | medium | 1 | `src/assembly/stability.gd` (its constants); new `tools/stablelego_ldr.py`; new `src/dev/stabletruth_probe.gd`; a table in [RESEARCH.md](RESEARCH.md) unit 3 | see below |
| 5 | **ownlimit** | 5 | M | medium | 3 (after rarity, keptbuilt) | new `src/collection/own_counts.gd`; `src/ui/parts_bin.gd` (a tile's count); `collection.gd` read only; `submit_design`'s `mine` in `app_tools.gd`; new `src/dev/ownlimit_probe.gd` | see below |
| 6 | **phonewalk** | 6 | M | low | 1 | new `tools/web/phonewalk_flow.mjs` | see below |
| 7 | **kinefuncs** | 7 | L | medium | 1 | `src/assembly/mechanism.gd`, `src/assembly/simulation.gd`; new `tools/kinefuncs.py`; new `src/dev/kinefuncs_probe.gd` | see below |
| 8 | **strengthen** | 8 | M | medium | 1 | new `src/assembly/strengthen.gd`; `src/ui/stress_panel.gd`; `weakest_joints`' answer in `app_tools.gd`; new `src/dev/strengthen_probe.gd` | see below |
| 9 | **swapfind** | 9 | M | medium | 3 (after keeptext5, copyfaults) | new `src/ui/find_replace_bar.gd`; `src/ui/edit_verbs.gd` (`replace`); `builder.gd`'s replace inside sub-models; a `replace_parts` tool; new `src/dev/swapfind_probe.gd` | the car's every Black 3023, in the model and its sub-models, made Dark Bluish Grey in one action; one undo puts back the saved file byte for byte; a part used in two colours flagged; `replace_parts` in 1 call gives the same file; `store`, `keep_text`, `copyfaults` pass; a review before merge |
| 10 | **fingertools** | 10 | S | low | 1 | `src/ui/measure.gd`, `src/ui/handles.gd`, `src/ui/touch_sizing.gd` | at 390 x 844, two studs of the car measured by two taps within 0.1 LDU of the mouse's reading; a part moved 3 studs by a handle dragged by a finger, as by a mouse; every handle's target 44 px or more; 0 SCRIPT ERRORs from `touch_sizing` over 20 dialogs opened and closed; `touch`, `touch_sizing`, `twist` pass |
| 11 | **mcpreach** | 11 | M | low | 2 (after subexport, a11ynames, video2, lineart) | `src/ui/exports.gd` (a free name when no one is asked; the 3D answer from `closed_mesh.gd`'s check); `src/render/render_output.gd` (a free name); `export_model` format `pdf` and the window-only commands named in `app_tools.gd`; `booklet_pdf.gd` read only; new `src/dev/mcpreach_probe.gd` | see below |
| 12 | **setsbuild** | 12 | M | medium | 4 (after rarity, keptbuilt, partplaces) | `tools/collection_data.py` (a compact index of every set's parts); `src/collection/set_inventories.gd`; What can I build?'s page in `collection_dialog.gd`; `parts_list`'s `build`, a block of its own | What can I build? ranks every set Rebrickable lists, not only those with a model file, by how much of it is owned; spot-checked against 10 sets by hand; on the web, the index under 2 MB and fetched only when the page opens; the first page in 2 s or less on a laptop; `collection`, `mybricks` pass |
| 13 | **loadtest** | 13 | M | medium | 2 (after stabletruth, strengthen) | `stability.gd` (a lift); new `src/assembly/lift_test.gd`; Stress's Lift (`stress_panel.gd`); `check_stability`'s `lift_by` | see below |
| 14 | **phonepanels** | 14 | M | medium | 2 (after hudfront, drive, a11ynames) | `src/ui/page_editor.gd`, `src/ui/pose_panel.gd`, `src/ui/simulate_panel.gd` (their touch only) | every act phonewalk names in these three, done by finger at 390 x 844 in no more than twice the desktop's actions; every target 44 px or more; `pose`, `simulate`, `page_editor`, `touch` pass |
| 15 | **movedparts** | 15 | M | medium | 3 (after askfirst, heldsteps) | `src/parts/model_store.gd` (the list on open); new `src/ui/moved_parts_dialog.gd`; `open_model`'s answer | 10 OMR files with moved parts and 3 with missing ones: every part listed with what it points to; the checked ones replaced in every sub-model in one undo; the saved file changes only those numbers (keep_text's byte compare); `open_model` names them over MCP; `store`, `keep_text`, `heldsteps` pass; a review before merge |
| 16 | **spikemotors** | 16 | S | low | 3 (after kinefuncs) | the stall table in `mechanism.gd` or `simulation.gd`; `motion_probe` extended | the SPIKE Prime medium and large motors and the Powered Up L and XL in Simulate's stall table, each from its maker's or Brickyard's figures, cited; an arm a SPIKE large motor lifts stalls where the virtual work says, to 1°; `motion` passes |
| 17 | **pointat** | 17 | S | low | 1 | `src/net/together.gd`, `src/ui/together_dialog.gd`, `api/together.js` (additive) | in a Together room of two tabs, a part pointed at shows on both within 500 ms with the pointer's name, gone after 5 s or on Esc; a person's Claude can point in 1 call; `together`, `together_flow` pass |
| 18 | **stepops** | 18 | M | high | 4 (after keeptext5, metalines, movedparts) | `src/parts/source_file.gd`, `model_store.gd`'s step writer; `keep_text_probe` extended | a step inserted or removed in 30 test files writes only the lines that moved, diffed against the file before; the rest byte for byte; undo gives back the file; `keep_text`, `steps_kept`, `unit_steps` pass; a review before merge |

**Which can run at once.** No two units in a wave share a file, beyond the
registries and `app_tools.gd`, and none touches a running unit's file
before that unit merges. `app_tools.gd` (4,865 lines) holds every MCP
tool, and units change it side by side as they do the registries, each in
its own tool: edges, lights, mcppalettes and booklook did so in the same
two days. drive changes 39 lines of it today.
- **Wave 1, eight at once:** webstart9, design20, stabletruth, phonewalk,
  kinefuncs, strengthen, fingertools and pointat. Each file is free today
  (checked against every running worktree), but for `app_tools.gd`:
  design20 changes `review_model`'s and `submit_design`'s answers and
  strengthen `weakest_joints`', none of them drive's tools, and each
  merges pre261 again before its ready. strengthen reads
  `stability.gd` and changes none of it; if stabletruth changes the
  clutch, strengthen's bar is read on whichever merges second.
- **Wave 2,** with round seven's copyfaults, metalines, heldsteps and
  keptbuilt, which wait on keeptext5 and localbricks:
  - buildorder after stepnames (`instructions.gd`, `build_steps.gd`);
  - loadtest after stabletruth (`stability.gd`) and strengthen
    (`stress_panel.gd`);
  - phonepanels after hudfront (`page_editor.gd`), drive and a11ynames
    (`pose_panel.gd`, `simulate_panel.gd`), and after phonewalk, whose
    table it works from;
  - mcpreach after subexport and a11ynames (`exports.gd`), and video2
    and lineart (`render_output.gd`).

  None of the four shares a file with round seven's four.
- **Wave 3,** with round seven's takeback, partplaces, carryrest and
  filmsound:
  - spikemotors after kinefuncs (`mechanism.gd`, `simulation.gd`);
  - ownlimit after rarity (`parts_bin.gd`) and keptbuilt (a built set's
    parts left out of the counts). It reads `collection.gd` and writes
    none of it, so it runs beside partplaces;
  - swapfind after keeptext5 (`builder.gd`) and copyfaults
    (`edit_model`'s swap);
  - movedparts after askfirst and heldsteps (`model_store.gd`).
- **Wave 4:** setsbuild after partplaces (`collection_dialog.gd`) and
  rarity (`tools/collection_data.py`); stepops after metalines
  (`source_file.gd`) and movedparts (`model_store.gd`); and round seven's
  realjoints5, which rebuilds the catalogue and so runs when no other unit
  is measuring against it.
- **Units that touch the same files and must wait for each other:**
  - stabletruth, then loadtest (`stability.gd`);
  - strengthen, then loadtest (`stress_panel.gd`);
  - kinefuncs, then spikemotors (`mechanism.gd`, `simulation.gd`);
  - subexport and a11ynames, then mcpreach (`exports.gd`), and video2
    and lineart, then mcpreach (`render_output.gd`);
  - copyfaults, then swapfind (`edit_model`, `builder.gd`);
  - heldsteps and askfirst, then movedparts, then stepops
    (`model_store.gd`);
  - rarity, then ownlimit (`parts_bin.gd`), and rarity, then setsbuild
    (`tools/collection_data.py`);
  - partplaces, then setsbuild (`collection_dialog.gd`).

**1. webstart9: the web's first visit, measured at an equal load.**
- **Change.** First a measure, nothing else:
  - rel-m276's build (`de20e50df`) and `pre261`'s, each exported for the
    web and served by `serve.py`;
  - loaded A, B, B, A, four times each, cold and warm, at an equal load,
    with the load beside each run (memory: an ABBA at equal load).

  If `pre261` is slower by more than 10%, find what grew the first
  screen's compile (0.37 s a MB of its source) and move it behind first
  use. Otherwise write down that it was the box, and stop.
- **Bar:**
  - the ABBA table, each run's compile, cold and warm, with its load;
  - `pre261` within 10% of m276, or brought back to it;
  - A13's 10 s cold and 4 s warm still the target;
  - `load_check` and the `web_start` checks pass.
- **Measured (2026-11-09): it was the box.** `tools/web/start_abba.mjs`,
  local exports, six blocks of A B B A at load 33 to 43: pre261 x1.02
  cold and x0.96 warm to usable, the compile x1.07 cold and x1.00 warm,
  against m276. The same m276 build took 16.9 s cold, 11.2 warm and a
  4.0 s compile, where APP_UX7 read 10.2, 6.0 and 2.2 at load 18 to 31.
  The first screen's source grew 5% (5.67 to 5.95 MB), about 0.1 s at
  0.37 s a MB. Nothing moved; A13's target stands (APP_UX.md, A13).
- **Measured again (2026-11-12), after pre261 took 541 more commits.**
  m276's own deployment against previews, four blocks of A B B A.
  pre261 at 373f62920 (load 31 to 69): usable x0.99 cold, x1.09 warm;
  compile x1.09 cold, x1.18 warm, over the bar. The first screen's source
  had grown 14%, 5.67 MB to 6.49: the model's core (source_file.gd +87 KB,
  assemblies.gd +74, model_store.gd +51, the new meta_index.gd 39 and
  submodel_file.gd 29). That is the model, and it stays. Four rarer
  features it named went behind Later: ExactCheck (Builder.room_for),
  Booklet (BookletLooks.layout_said), Linkage (Grab) and HingeAlign
  (Meet). The first screen is 6.18 MB (+9%), index.pck 2.24 MB sent
  where it was 2.36 (m276 2.06). Measured again at load 48 to 66: usable
  x1.09 cold, x1.03 warm; compile x1.25 cold, x1.12 warm. At that load
  a block's compile ratio swung 0.97 to 1.28, more than the 5% moved.
  The usable times are inside the bar in both runs; the compile is not.
  The data pack, which the start waits for at its "data" stage, grew
  5.06 MB sent to 5.93: NotoEmoji-Regular.ttf (619 KB, for the booklet's
  PDF, 11-09) is most of it. A pack of its own, read when a PDF is made,
  would take it off the start.

**2. design20: the silhouette, the next lever for set quality.**
- **Change.** The session sees its model's outline from the reference's
  own side laid over the real set's outline, with where they differ in
  studs and plates, first in `review_model`'s answer and in
  `submit_design`'s review. design19 found that sessions keep the
  differences they are given as numbers (9 of 10). This gives them the
  shape's.
- **Bar:**
  - `silhouette_probe`: for five sets and their own LDraw models, the
    outline differs by 0 studs from the set's own; for a model a stud
    wider, the answer says "a stud wider" at the right place;
  - **realset's proof 44** on the connector path (`--instructions none`),
    run by the lead on a locked snapshot, paired against today's base:
    overall up 5 points or more, with likeness up;
  - the leak audit clean, with no session opening its own held-out set;
  - if it does not win, a NO-GO written down in ROADMAP with its numbers,
    as design16 to design19 were.

**3. buildorder: steps a person can build in order.**
- **Change.** The planner's order puts nothing in under a part already
  there, leaves nothing floating at its step, and does not hide a new part
  behind an old one. It reads what each part rests on, which `_supports_of`
  does not, tuned together with the order as INSTRUCTIONS.md says it must
  be.
- **Bar** (`tools/steps_score.py run --which proof`, judged once, after
  tuning on `tune`):
  - steps floating something 2% or fewer (7.5% today; authors 1.25%);
  - parts in under one already there 1.5% or fewer (5.7%; authors 0.9%);
  - steps hiding a new part 8% or fewer (12.1%; authors 6.7%);
  - tau 0.29 or more, no worse;
  - the build check's floating 4% or fewer;
  - planning no slower than 1.33 times main's;
  - booklettest's follower no worse;
  - `instructions`, `steps_kept`, `booklet_edit`, `unit_steps` pass.

**4. stabletruth: a stability check that is measured right.**
- **Change.** RESEARCH unit 3, done. StableLego's test structures (MIT)
  are turned into LDraw: the 19 stairs that stand and the 20 that fall,
  and the stick with two loads and with three. A sample of
  StableText2Brick's structures is added. `Stability.check` is run on
  each. The clutch is compared with StableLego's 0.98 N a stud, and set
  from the real builds if they say so.
- **Bar:**
  - every one of StableLego's built structures judged as it really
    stood or fell (39 of 39, and both sticks);
  - agreement with StableText2Brick's per-brick scores 95% or more, with
    false alarms counted;
  - the agreement table in RESEARCH.md;
  - if the clutch changes: the car still "stands up", the walk's wall
    still 13 g, and the 19 Tested models' verdicts unchanged or each
    change explained;
  - `stability`, `stress`, `weighsure`, `tested_models` pass.

**5. ownlimit: designs held to the person's own parts.**
- **Change.**
  - With From my bricks on, each bin tile shows how many are left (owned,
    less built sets, less what the model already uses), and placing the
    last one says so.
  - Over MCP, `submit_design` takes `mine: true`: the design uses only
    owned parts in their colours, or names each part it goes over and by
    how many.
- **Bar:**
  - with 7140 and 12 loose lots owned, the counts left read exactly the
    pool less the model at every step of building the wall;
  - a 13th of a part owned 12 times is marked over;
  - the MCP walk's n5 (a small car from my collection) uses 0 parts not
    owned, or names each;
  - `collection`, `mybricks`, `keptbuilt`, `bin` pass;
  - a review before merge.

**6. phonewalk: the walk by finger.**
- **Change.** None to the app: a flow, `phonewalk_flow.mjs`, on a web
  export at 390 x 844 (3x, touch) and 1024 x 768 (touch). It does the
  walk's acts by finger:
  - the wall of eight from the search, a turn of 15°, three painted;
  - a split and a merge, a part to the last step;
  - Render, a booklet page, Like this, Check stability, Cut away and My
    collection;
  - Measure, Pose, Simulate and the page editor.

  Each is counted in taps beside the desktop's presses.
- **Bar:**
  - the flow runs every act at both sizes and writes the table;
  - each act that cannot be done by finger is named with its file;
  - that list becomes phonepanels' brief and anything beyond it;
  - `touch` and `twist` pass.

**7. kinefuncs: Simulate measured on real sets' functions.**
- **Change.** `tools/kinefuncs.py` opens each of the 186 Technic sets
  Kinebrick checks, from LDraw's OMR, finds its functions (a steering, a
  boom, a gearbox, read from its controls and drivers) and drives each in
  Simulate, as Kinebrick does with its drags. Where Simulate fails a
  function Kinebrick passes, the cause is fixed in `mechanism.gd` or
  `simulation.gd`. Kinebrick's own per-set list is read only if its
  licence allows; otherwise the functions are the sets' own, from their
  booklets. Its first case is the MCP walk's own: a 24-tooth gear driving
  an 8-tooth on axles in a Technic-brick frame, standing apart from a
  bridge, that `simulate_mechanism` called "floating" while `move_part`
  turned it (n4). It is reproduced before anything is changed; one ground
  for the whole model is the first suspect.
- **Bar:**
  - the n4 gear train, built beside another piece, turned by
    `simulate_mechanism` with the 24 as the driver: the 8 makes 3 turns
    to its 1, as `move_part` already turns it;
  - a table of every function, works, in part or not, beside Kinebrick's;
  - Brickworks works on 517 or more (Kinebrick's main, 42%);
  - 0 'det == 0' errors in the full 25-minute `grab`;
  - `motion`, `grab`, `mechanism`, `tested_models` pass.

**8. strengthen: a weak joint fixed in one action.**
- **Change.** Stress's panel offers Strengthen for each joint past or
  near its working load: a plate across the seam, a brick over it, or a
  pin, from the person's own parts when From my bricks is on. It is shown
  as a ghost and placed in one undo. Over MCP, `weakest_joints` answers
  each joint with its fix as a filled-in call.
- **Bar** (`strengthen_probe`, ten models with weak joints: a one-wide
  wall, a cantilever, a tower on one stud and others):
  - each proposal brings its joint above its working load in Stress;
  - it collides with nothing and adds 1 to 3 parts;
  - one undo puts everything back;
  - over MCP, the fix applied as given gives the same model;
  - `stress`, `stability`, `weighsure` pass.

**11. mcpreach: the person's Claude told what the window does.**
- **Change.**
  - `export_model` takes `pdf`: the booklet as the Instructions window
    prints it, through `booklet_pdf.gd` as it stands (pdfcid's fonts,
    pdfbidi's order once merged).
  - An STL's or a 3MF's answer says whether each object is a closed
    solid, from the check print3mf2 made (`closed_mesh.gd`), and names
    any that is not.
  - With no one to ask, an export or a picture takes the next free name
    ("pods_render 2.png") instead of replacing one, and the answer gives
    the name. A person's File › Export, with its save dialog, is
    unchanged.
  - The commands only the person runs (`WINDOW_ONLY`: Together, Share,
    Import, Comments) are named, each with where it is, in words a
    session reads before it answers (`read_guide("app")`'s first lines,
    or a tool's description). A session then sends the person to
    Together instead of saying there is none. Nothing opens a room or
    shares for them.
- **Bar:**
  - the MCP walk's x2, x4, x5 and n7 again, on the same prompts: x2
    hands over a PDF that `pdftotext` reads back as typed, in 3 calls or
    fewer; x5 says every object is a closed solid; after x4 and x5 the
    earlier picture and 3MF are still there, byte for byte, beside the
    new ones; n7 names Together and where it is, and opens nothing;
  - `mcp_sync`, `mcphand`, `print3mf`, `mesh_export` and `booklet_pdf`
    pass.

**13. loadtest: lift it by a part.**
- **Change.** Stress gets a Lift: click a part, and the model hangs from
  it. Every joint between that part and the rest carries the weight below
  it, and what lets go is tinted and named. Over MCP, `check_stability`
  takes `lift_by`.
- **Bar:**
  - a wall of eight 1 x 4 bricks lifted by a top brick: the bricks under a
    joint of one stud let go and are named, as the clutch says by hand;
  - the car lifted by its roof: the parts that come away named, the same
    over MCP in 1 call;
  - `stability`, `stress` pass.

## The top ten

1. **webstart9:** the web's first visit, measured at an equal load.
   Measured: an ABBA table of m276 against `pre261`, compile and cold and
   warm, with the load beside each run; within 10%, or brought back.
2. **design20:** the silhouette, the next lever for set quality.
   Measured: realset's proof 44 on the connector path, paired, overall up
   5 points or more; the leak audit clean.
3. **buildorder:** steps a person can build in order. Measured on the
   held-out sample: 2% of steps floating or fewer, 1.5% of parts in under
   another, 8% of steps hiding a new part, tau 0.29 or more.
4. **stabletruth:** a stability check measured right. Measured: 39 of 39
   of StableLego's built structures, and 95% agreement with
   StableText2Brick's scores.
5. **ownlimit:** designs held to the person's own parts. Measured: the
   bin's counts left exact at every step of the wall; the MCP walk's n5
   with 0 parts not owned, or each named.
6. **phonewalk:** the walk by finger. Measured: every act at 390 x 844
   and 1024 x 768, in taps beside the desktop's presses, and what cannot
   be done named with its file.
7. **kinefuncs:** Simulate on real sets' functions. Measured: 517 or more
   of the functions of Kinebrick's 186 sets working; 0 'det == 0' errors in
   the full `grab`.
8. **strengthen:** a weak joint fixed in one action. Measured: ten weak
   models, each joint above its working load after its proposal, 1 to 3
   parts, one undo.
9. **swapfind:** Find and Replace into every sub-model. Measured: the
   car's Black 3023s made Dark Bluish Grey everywhere in one action; one
   undo back to the byte; 1 call over MCP.
10. **fingertools:** Measure and the handles by finger. Measured: two taps
    within 0.1 LDU of the mouse; a handle moves a part 3 studs; 44 px
    targets.

Wave 1 starts with seven of these (webstart9, design20, stabletruth,
phonewalk, kinefuncs, strengthen, fingertools) and pointat. buildorder
waits on stepnames, ownlimit on rarity and keptbuilt, and swapfind on
keeptext5 and copyfaults.

Above all ten, already planned and waiting on keeptext5: round seven's
copyfaults, metalines and heldsteps, because each is silent data loss.
Also in flight: keeptext5, drive, stepnames, localbricks and video2, the
beta release (betajoin, bugreport, betahome) and the docs (docshots).

**Next, once those land:**
- mcpreach, setsbuild, loadtest, phonepanels, movedparts, spikemotors,
  pointat and stepops: ranked 11 to 18 above.
- Round seven's waiting units, unchanged: copyfaults, metalines,
  heldsteps, keptbuilt, takeback, partplaces, carryrest, stepsearch,
  filmsound and realjoints5. Round six's queue: modsteps, watchfile and
  panelside.
- Not ranked:
  - **hubprogram:** a program for the model's motors, run in Simulate,
    in Pybricks' terms, after spikemotors. A real hub is parked;
  - **agesteps:** a booklet for an age (fewer parts a step, the parts
    shown beside each), after buildorder. It needs each set's age band,
    which the catalogue does not hold;
  - **pilecount:** a pile counted from one photo (Noppi, Brickit). It
    needs a detector; Brickognize's API names one part a picture;
  - redundancy named in Check stability: a part held by one joint only;
  - **binstay:** with Stress open, a click on a part keeps the bin where
    it is, as its rail's return shows there is room (Found on the way);
  - **makerfold:** Make a part's family options, the far corner among
    them, in sight without a scroll at 1280 x 720 (Found on the way);
  - the sub-model under the pointer outlined (StudWorx);
  - SOCIAL rows 7 to 9 (the week by email, builds as a gallery tab,
    people to follow), to be ranked once the beta's first weeks show who
    comes;
  - BrickBench's validity measured locally again, with nothing submitted;
  - from round seven: the model so far as a page, pictures of a range of
    steps, a Hide tool's count, a ground that follows the lowest part,
    BrickCheck, dual-moulded colours, the number colour's swatch, the
    twist in the phone's hint, a compare by shape in any colour, More
    like's why, and the carried list.
- **Parked, needing the owner:**
  - bricklink (BrickLink's keys and terms), and store prices generally;
  - studioside (Studio's install);
  - 3Dconnexion (the device), and a real SPIKE hub (the device);
  - the Mac's thumbnails (the Developer ID);
  - desktop downloads ("Coming soon" until the owner says);
  - payments and live prices;
  - the Claude directory's submission;
  - tests on other AIs;
  - music shipped with Brickworks (a licence), and AI cover backgrounds
    (an image model);
  - any BrickBench leaderboard submission or MCP registry listing (ask
    first);
  - asking BrickSim's authors for their 150 labelled builds (an outside
    request). stabletruth does not need them.

  None is ranked above, and nothing above waits on any of them.
- **Out on purpose:**
  - a weather lab (wind, rain, earthquakes): a person lifts and pushes a
    model, and nobody puts one in a gale;
  - a falling-bricks physics simulation: the questions a person asks of a
    mechanism are where it stops and whether it lifts, and Simulate
    answers both;
  - a collision switch;
  - more languages;
  - a second look for the app, until the owner asks;
  - the LEGO® logo on studs ([TRADEMARKS.md](TRADEMARKS.md), 3);
  - anything for a person who is not signed in: everyone has an account.

## Sources

Brickworks' own figures are from the runs above, in
`bench/results/appux8-2026-11-09/`:
- `walk/`: the walk's logs and pictures, and `round7` again;
- `probes/`: the probes' logs, binrow's and edges' pictures, and
  `times_gpu_chain.txt`;
- `web/`: the web's runs;
- `mcp/`: the MCP sessions' streams and the app's own files;
- `sources/`: the field's pages as read today.

The MCP walk's prompts and calls are in
[app_ux8/mcp_walk/](app_ux8/mcp_walk/).

The field's sources, beyond APP_UX2's to APP_UX7's:
- StudWorx 2026-11-08: <https://github.com/nathaneltitane/studworx/releases/tag/2026-11-08>
- brick-flow-agent: <https://github.com/ninjarz/brick-flow-agent>
- Kinebrick: <https://github.com/erik-larsen/kinebrick>; its least-motion check of 9 November: <https://github.com/erik-larsen/kinebrick/commit/fc369cae1df0a150e7d20db83ea8433568b5e152>
- Brickyard: <https://github.com/genworks/brickyard>
- BrickCheck: <https://github.com/dylankiss/brickcheck>
- brick-tidy: <https://github.com/FrankAndreas/brick-tidy>
- rebrick-me: <https://github.com/maxpalermo/rebrick-me>
- BrickBuilder AI: <https://github.com/for-real-labs/brickbuilder-ai>
- lego-build-video: <https://github.com/OceanJy333/lego-build-video>
- Noppi: <https://apps.apple.com/us/app/noppi-brick-scanner-counter/id6821694403>
- BrickMaster AI: <https://apps.apple.com/us/app/id6784195498>
- BrickSnap: <https://apps.apple.com/us/app/id6760638357>
- Studio's help: Stability check <https://studiohelp.bricklink.com/hc/en-us/articles/6501498505111>; Build Together <https://studiohelp.bricklink.com/hc/en-us/articles/6477757327767>; Animation <https://studiohelp.bricklink.com/hc/en-us/articles/6507015818263>; Divide into steps <https://studiohelp.bricklink.com/hc/en-us/articles/7123910550039>; Connectivity check <https://studiohelp.bricklink.com/hc/en-us/articles/6501624386071>; Collision <https://studiohelp.bricklink.com/hc/en-us/articles/5412820155927>; the article list, `sources/studio/p1.json` and `p2.json`
- Rebrickable, Build settings: <http://web.archive.org/web/20260628131301/https://rebrickable.com/help/build-settings/>
- LeoCAD releases: <https://github.com/leozide/leocad/releases>; LPub3D releases: <https://github.com/trevorsandy/lpub3d/releases>
- Mecabricks' forum, the 404 thread of 9 November: `sources/mb/t76481.html`
- StableLego: <https://github.com/intelligent-control-lab/StableLego>, <https://arxiv.org/html/2402.10711v2>
- BrickBench: <https://arxiv.org/abs/2610.12452>; BrickWright: <https://arxiv.org/abs/2610.31651>
