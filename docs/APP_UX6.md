# The app against the best tools, round six

Written 2026-11-07 by appux6 against `pre261` at `a3f8fb7d`. The web was
measured on rel-m268 (`e309dec8`), live then. [APP_UX.md](APP_UX.md) to
[APP_UX5.md](APP_UX5.md) planned rounds one to five. Of round five's
sixteen units, thirteen are merged: buildturn and pagesetup are live in
rel-m268; mybricks (as mybricks2), seeing2, buildparty, modelinfo,
savedviews, keys2, striproom, thumbs, arview and socialtails are in
`pre261`; and playlink merged after this snapshot. Three are not merged:
lights is fixing its review's nine findings, animals is held over its
catalogue, and realjoints3 waits for animals. keeptext4, and then
intomodel3 (APP_UX4 #3), are in flight.

This file measures the app a sixth time, by hand and through a person's
own Claude. It says where the field still does better, and plans round
six in waves the lead can start at once.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second.
[COMPETITIVE.md](COMPETITIVE.md) is the feature matrix,
[ROADMAP.md](ROADMAP.md) the designer's quality and [SOCIAL.md](SOCIAL.md)
the site. None is repeated or edited here.

## How it was made

- **The walk, a sixth time.** appux5's script and tasks, run on the GPU at
  1280 x 720 and 1400 x 900, in one `gpu` job from a locked snapshot of
  this commit, imported first ([app_ux6/appux_walk.gd](app_ux6/appux_walk.gd)).
  One section was added after the old ones, so their numbers still
  compare: `round5`, which covers:
  - the model's size on the status bar, with nothing selected and with
    three parts selected;
  - Render by its key;
  - Page setup by its key, and its papers;
  - Stud directions;
  - a view saved, then brought back after turning away;
  - My collection's loose parts;
  - Cut away's strip, with Stress's panel open;
  - the keys round five's commands have;
  - lights.

  Every picture it took (77 and 77) was looked at.
- **The same tasks over MCP,** as the owner's Claude does them
  ([app_ux6/mcp_walk/](app_ux6/mcp_walk/)):
  - the app in a window of its own, with its MCP port open and its own
    Documents and Pictures;
  - the walk's 30 words, and "1x4 brick", through `search_parts`;
  - then Claude Code on the subscription: `claude -p`, the Brickworks
    server alone, `--tools ""`, `--restricted`, no API key. All 37 streams
    say `apiKeySource: none`.

  There was one turn per task: APP_UX5's 27 tasks, then ten for what round
  five added ([prompts_round5.txt](app_ux6/mcp_walk/prompts_round5.txt)).
  They ran in two sessions: the walk's ten in the first, and all the rest
  in the second. Calls are counted from the sessions' own streams
  ([calls.txt](app_ux6/mcp_walk/calls.txt)). The app was signed out, as
  a first visit is.
- **Round five's bars** were read off each merged unit's probe, run today
  from the same snapshot, in one `heavy` job, one size each, as its header
  says:
  - `arview`, `buildturn`, `pagesetup`, `seeing2`, `buildparty`,
    `modelinfo`, `savedviews`, `keys2`, `striproom`, `thumbs` and `tracks`;
  - `mybricks` through `relay_probe.sh`, signed in.

  All twelve passed, with no check failing (`probes/times.txt`). socialtails
  is the site's, so its bars were read off rel-m271's preview flows.
  playlink's are from its report, because it merged after the snapshot.
- **The web:** `load_check` on live brickworks.diy (rel-m268), on
  broadband, with two cold and two warm loads and a part picked from the
  bin. It was run again at a phone's 390 x 844 (3x, touch).
- **The field,** from each tool's help pages, release notes, changelogs,
  READMEs and commits as of 7 November 2026 (Sources). APP_UX2's to
  APP_UX5's lists and COMPETITIVE were read again, and only what they did
  not cover is new here. Round five's own "Next", the lead's candidates in
  `queue.md`, and SOCIAL's and ROADMAP's open rows are folded in.
- **Not run:**
  - Studio itself (studioside, the owner's);
  - the in-app assistant on a key (it spends money);
  - claude.ai's connector.
- **The box was shared.** The GPU had one slot. The load was 29 to 37
  through the walk and 62 to 77 through the web's phone runs and the
  probes, two to three times APP_UX5's. Seconds are stretched by it;
  counts are not.

## What the walk measured, six times

The first three rounds' figures are in APP_UX4 and APP_UX5.

| act | appux4 (1280 / 1400) | appux5 (1280 / 1400) | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|---|
| desktop start, the first 120 frames | 8.6 / 6.3 s | 9.1 / 8.9 s | 6.4 s (load 37) | 12.9 s (load 35) | walk |
| bin tiles in sight on the first open | 24 / 42 | 24 / 42 | 24, every one named | 42, every one named | walk `counts` |
| Properties with a part selected | every field; the bin gives way / beside it | the same | every field in sight; the bin gives way | every field, the bin beside it | walk `turns` |
| keys sheet (F1), rows in sight | 32 / 46 of 128 | 32 / 46 of 139 | 32 of 157 | 46 of 157 | walk `counts` |
| commands with a key | 87 of 201 | 98 of 209 | **116 of 221** (keys2) | the same | walk `counts` |
| Render from the model by keys | 5 presses | 5 | **1: F9** (keys2) | 1 | walk `round5` |
| the tallest menu, rows (height) | Edit 24 (464) | Edit 24 (464) | Edit 24 (464); View 20 (412, menurows); none scrolls | the same | walk `menus` |
| the part menu | 26 | 26 | 26 | 26 | walk `menus` |
| a wall of eight 1 x 4s from the search | 20 events, 2.4 / 3.2 s | 20, 2.5 / 4.5 s | 20, 2.9 s | 20, 3.3 s | walk `wall` |
| the ghost following the pointer, 3 frames a move | 34.3, worst 58.8 / 42.0, worst 52.9 ms | 33.9, worst 51.4 / 53.9, worst 82.5 | 37.9, worst 68.4 | 44.4, worst 73.7 | walk `wall` |
| R on a brick in a wall, 15° step | in hand, down in 3 | the same | in hand, down after 2 events, 15.0° | the same | walk `turns` |
| a brick alone, 3 x R at 15° | 45° | 45° | 45° | 45° | walk `dialogs` |
| panels and dialogs | 22 of 24 | 22 of 24 | 22 of 24, 0.9 to 2.9 s; Compare and Pattern greyed (no save, nothing selected) | 22 of 24, 1.0 to 4.3 s | walk `dialogs` |
| search, 30 words | 27 | 27 | 27: the same three not first | the same | walk `search` |
| three selected parts painted Red | 1 key | 1 key | 1 key | 1 key | walk `round2` |
| a 2 x 4 plate split, and merged back | 1 key each | 1 key each | 1 key each | the same | walk `round2` |
| a second view, the assistant open | greyed / 385 px | F8: 490 / 385 px | F8: two views of 490 px | F8: 385 px | walk `round2` |
| a part to the last step | 4 presses | 4 | 4 | 4 | walk `round3` |
| Settings' language | four | four | English, Deutsch, Français, Español | the same | walk `round3` |
| Like this on a 2 x 4 brick after "1x4 brick" | 2 clicks | Plate 2 x 4 seventh | Plate 2 x 4 seventh | the same | walk `round3` |
| the status bar, the car open, nothing selected | | "61 bricks · stands up · 52 g" | **and "4½ × 10.8 studs, 15 plates high · 3.6 × 8.64 × 4.96 cm"** ([picture](app_ux6/size_on_the_status_bar_1280x720.webp)) | the same | walk `round5` |
| three parts of the car selected | | | "3.8 × 7.8 studs, 4½ plates high · 3.04 × 6.24 × 1.44 cm" | the same | walk `round5` |
| Cut away by a box | one plane | 0.8 / 1.3 s; no keys | 1.2 s; Alt+X, Alt+Z, Alt+Y | 0.95 s | walk `round4` |
| Cut away's strip, with Stress, the bin and the assistant open | | the × under a column | **5 of 5 buttons inside the model's room** ([picture](app_ux6/cut_strip_in_the_room_1400x900.webp)) | 5 of 5 | walk `round5` |
| the booklet's page set up | fixed 269 x 199 | the same | **Ctrl+Shift+B, 1 press**: Booklet 269 x 199, A4, US Letter, A5; landscape or portrait ([picture](app_ux6/page_setup_1280x720.webp)) | the same | walk `round5` |
| Stud directions on the car | | | View: up 45, to the front 4, no studs 12, with a legend ([picture](app_ux6/stud_directions_1280x720.webp)); no key | the same | walk `round5` |
| a view saved, turned away 35°, brought back | | | Alt+V, Return: 2 presses; Alt+Shift+1 brings it back **0.000° and 0.000 LDU off** | the same | walk `round5` |
| My collection | sets and lists | the same | **and Loose parts**, in sight; no key | the same | walk `round5` |
| the parts list's shops | BrickLink, Rebrickable | and Pick a Brick | the same; Pick a Brick Alt+L | the same | walk `round4` |
| File, Import, Into this model… | | offered | **not offered**: intomodel was taken out, and intomodel3 is pending | the same | walk `round4` |
| train tracks | laid by eye | the same | TrackSnap, `track_ends.json` (tracks, live) | the same | walk `round4` |
| lights | | | not offered (lights is not merged) | the same | walk `round5` |

The search's three that are not first are the walk's own answers, as
before:
- "jumper" lists 3794b sixth, after the newer 15573.
- "macaroni" lists 25269 fourteenth.
- "bracket" has 99781 fourth.

"1x2 plate", "round 1x1" and "minifig head" list LDraw's renumbered part
first (3023b, 6141, 3626c), which is the part a builder means.

These round five commands have no key: Stud directions, Render each
saved view, My collection, and its What do I need? and What can I build?
105 of 221 commands have none.

**Found on the way:**
- **The timeline runs past the window at 1280 x 720**
  ([picture](app_ux6/timeline_past_the_window_1280x720.webp)). This is
  with the bin, Properties (a wheel rim selected), Stress's panel and the
  timeline open. The whole layout is wider than the window, so these lie
  past its right edge:
  - the Account button and the right-hand column;
  - the timeline's "Step N of M", Instructions and Done;
  - the key strip's right end;
  - the status bar's right half.

  APP_UX5's picture of the same act shows the same, unreported. At
  1400 x 900 the timeline fits, but the assistant's column is cut in
  half. The cause is in the code:
  - The timeline's rows never wrap: `steps_bar.gd` `_build`, with its
    caption 190 wide, its buttons 52 wide and Instructions 92 wide. Only
    its booklet row wraps.
  - `main.gd` `_fit_bin` does not take the tool column's 360 (Stress's
    panel) from the room it gives.
- **The weight changes with nothing added.** The same eight 1 x 4 bricks
  read 8 g just built (7 g at 1400 x 900). They read 13 g with the next
  part in hand, 12 g after one brick is turned, then 13 g again.
  - The status bar sums the parts it has weighed so far
    (`Stability.check` skips a part whose shape is not loaded yet) and
    gives no sign that the number is not final.
  - `ModelSize.weight_words` ("About N g") exists, and nothing calls it.
- **The size mixes number styles.** "4½ × 10.8 studs" puts a fraction
  beside a decimal, and "3.6 × 8.64 × 4.96 cm" mixes one and two decimal
  places. The causes: `StatusBar.amount` gives quarters, or else two
  decimals, and `ModelSize.cm` gives two decimals.
- **A part number picked out over MCP fails as its description invites.**
  `view_board`'s `highlight` says "a part number as a string ("3024")".
  Both sessions that used it sent the quotes too, `"\"4070\""`, and were
  refused: "\"4070\" is no part's number, part number, colour or step
  here". Each then picked the two bricks by their numbers in a second
  call (round four's u2, round five's v3).
- **A booklet pull did not come back after a save and an open.** In the
  pods session, both wing plates were pulled out in step 1 (round three's
  r4), and the model was saved as Pods (u6). Pods.ldr keeps
  `0 !BRICKWORKS PULL 2 41770a 41769a` on the main model's step 1, and
  the model has `AUTHORED_STEPS`.

  Opened again (v2), its step 1 is the side pod's own sub-model step.
  `booklet_layout`, which names a step's pulls (`BookletLooks.said`),
  named none, and the session found the pull gone (v8). It was not
  reproduced alone. The bar of unit 1 below starts by reproducing it from
  the saved file (`bench/results/appux6-2026-11-07/mcp/run/xdg/godot/app_userdata/Brickworks/models/Pods.ldr`).
- **No tool saves a view.** savedviews let a session draw from a saved
  view by its name. Asked to keep the window's view as "Three quarter"
  (v4), the session could not: `save_view` is `WINDOW_ONLY`. It drew from
  the app's own three-quarter angle and told the person how to save it
  (View › Viewpoint).
- **The first build's offer is back in the walk's later pictures.** The
  cause is the walk itself, not the app: it opens Help › Take the tour,
  which offers the first build again by design. APP_UX5's pictures show
  the same.
- **APP_UX5's tooling asks are done:** `probe.sh` gives each run its own
  Documents and Pictures (an `xdg-user-dir` stub), and `shots/` has its
  `.gdignore`. Both of the walk's Godots quit cleanly (exit 0), so
  quitabort holds at 1400 x 900 as well.
- The walk's own: the Instructions picture shows no booklet, because
  `BRICKWORKS_OPEN_NOTHING` keeps the HTML from opening. Tooltips from
  Stress's list linger in two pictures (the pointer's place).

**The web** (`load_check`, broadband, live):

| | appux4 (live rel-m264, load 18 to 20) | appux5 (live rel-m266, load 32 to 41) | now: live rel-m268, load 28 to 30 | from |
|---|---|---|---|---|
| first visit, cold, to working | 13.1 s | 17.2 s | **12.0 s** (12.1 and 11.9) | `load_check` |
| warm | 8.0 s | 11.0 s | **7.6 s** (8.9 and 6.4) | `load_check` |
| main thread, cold | 7.4 s | 9.4 s | 6.9 s | `load_check` |
| the engine's banner, cold | 4.6 s | 5.2 s | 4.6 s | `load_check` |
| the scripts' compile, cold and warm | 3.1 s | 4.4 s | **2.8 s and 2.8 s** | `load_check` |
| app ready (the scripts done), cold | 7.8 to 9.0 s | 9.3 to 12.0 s | 8.0 to 8.2 s | `load_check` |
| a part from the bin to its ghost | 1,572 and 278 cold, 214 and 219 warm | 1,538 and 552 cold, 551 and 431 warm | **249 and 389 cold, 139 and 283 warm** | `load_check --pick` |
| bytes before working | 16.49 MB | 16.42 MB | 16.51 MB | `load_check` |
| a phone, 390 x 844: first frame, cold and warm | | 19.9 s (16.6, 23.3) and 10.7 s (11.8, 9.7) | 12.1 and 7.7 s in the first pair; 29.6 and 35.9 s in the second, at a load of 69 to 77 | `load_check`, a phone's viewport |

leaves3 is live in rel-m268. At the lower load the cold visit is back
under APP_UX4's, and the pick is a quarter of APP_UX5's. A13's bar
(10 s cold, 4 s warm) is still not met.

One number is new: **a warm visit compiles the scripts for as long as a
cold one** (2.8 s both). Nothing of the compile is kept between visits,
so on a warm visit it is the largest single stage. On a phone,
`load_check`'s "working" waits for the bin, which a phone keeps behind a
button, so its figure there is the first frame. The phone's second pair
ran at more than three times the box's cores and says nothing about the
app.

## Over MCP: the walk's tasks as the owner's Claude does them

**The search** answers a session as the bin answers a person. Each of
the walk's 30 words put the same part first in both, and "1x4 brick" put
3010 first, all in 3 to 73 ms a word.

**APP_UX5's thirteen tasks, again:**

| task | APP_UX5: calls, time | now: calls, time | what the session did |
|---|---|---|---|
| clear, and a red wall of eight 1 x 4s, half a brick along | 2, 10 s | 3, 13 s | clear, `check_design`, `submit_design`; it explained the stepped ends |
| turn one brick of the top row 15° where it stands | 1, 10 s, refused | 1, 14 s, refused | it gave both reasons, offered three other ways, and changed nothing |
| paint three bottom bricks blue | 1, 3 s | 1, 4 s | it chose which three, and said so |
| a 2 x 4 plate, split into eight 1 x 1s | 3, 12 s | **2**, 9 s | `edit_model`, then `split_parts`, which answers with its picture |
| three 1 x 4 plates stacked, merged into a brick | 2, 7 s | 2, 8 s | `merge_parts` |
| a 3 x 6 wing, the left one, and its mirror image | 4, 17 s | 5, 28 s | `mirror_parts` across x 3: 54384 became 54383 |
| a beam 7 standing, a pin in its second hole | 6, 30 s | 8, 74 s | **it built a column it was not asked for**: seven parts to hold the beam up, then said so. APP_UX5's session offered three ways and asked. This is the session, not the app |
| the angle between the beam's holes and the wall | 0, 3 s | 0, 2 s | 0°, read from the beam it had built |
| move the top row three steps later | 5, 17 s | **4**, 15 s | `edit_steps` with `op: "to"` for three bricks; the fourth went to the last step, and it said why |
| render a picture | 2, 8 s | 2, 10 s | the picture was saved in the app's own folder |
| a side pod of five parts, in words | 8, 39 s | **7**, 33 s | `attachment_points` once; it checked, then submitted |
| the pod's mirror image beside it | 2, 16 s | **1**, 7 s | `mirror_parts` with its picture: 41770a became 41769a |
| a 2 x 2 slope split into 1-wide slopes | 2, 6 s | 2, 7 s | `split_parts`: two 3040 |

The thirteen took **38 calls in 3.7 minutes**, the same number of calls as
APP_UX5. The extra time is the beam's unasked column.

**Round three's own:**

| task | APP_UX5 | now | what the session did |
|---|---|---|---|
| a short video of the model built up | 2, 43 s | 2, 42 s | `render_model` build and its job. **It now says what is in the video**, from the six frames seeing2 added: "Each step's parts drop into place while the camera turns slowly round" |
| parts like the headlight brick, three picked | 1, 13 s | 1, 10 s | `search_parts {"like": "4070"}`: 87087, 26604 and 3005, each with a reason |
| what step the window shows, the part in hand | 1, 3 s | 1, 3 s | `in_view`, which now gives the size and weight as well (modelinfo) |
| the wing pulled out, colour guides, the first page | 8, 22 s | **5**, 13 s | `edit_booklet` pull with `parts: [3, 8]`, by brick number: **both drawn** (seeing2). APP_UX5's pull by number drew nothing |
| a picture at the best quality, and how it was lit | 2, 17 s | 2, 13 s | Best: "path-traces the light, here with 256 samples" |

**Round four's own:**

| task | APP_UX5 | now | what the session did |
|---|---|---|---|
| the pods from three sides: true mirror images? | 1, 13 s | 2, 11 s | `view_board` front, left and top with `where`, then `look_at_model`: a table, pair by pair |
| only the two headlight bricks picked out | 1, 6 s | 2, 8 s | **`highlight` with the quoted part number was refused**; then it used the bricks' numbers |
| page 2 of the instructions as a person sees it | 1, 8 s | 1, 11 s | `booklet_page`; it also suggested moving the blue slopes to the end |
| a 4 x 3 x 2 block of 2 x 2 bricks | 2, 9 s | 2, 10 s | one brick, then `pattern_parts` |
| a Pick a Brick file, and what it left out | 1, 8 s | 1, 8 s | `export_model` pickabrick: 8 lines, 36 pieces, none left out |
| save as Pods | 1, 5 s | 1, 6 s | `save_model`; it mentioned the 16 loose pieces |
| a green 16 x 16 plate, Pods into it, whole | 6, 13 s | **0**, 10 s | "the app can't merge a saved model into another one": intomodel was taken out of `pre261`, and intomodel3 waits on keeptext4. It offered three ways and asked |
| how big, in studs and centimetres, and how heavy | 0, 4 s | **1**, 5 s | `in_view`: 24 x 6 studs, 6 plates; 19.2 x 4.8 x 2.1 cm; about 46 g "usually within about 6%". APP_UX5's session worked it out by hand |
| a closed oval of 9V track | 11, 101 s | **9**, 35 s | 16 curves and 4 straights, **joined end to end by `attach`** in one check and one submit; it then measured the last joint, which was 0 apart. APP_UX5's session placed each piece by its own arithmetic |

**Round five's own** (the same session: the track, then Pods again):

| task | calls, time | what the session did |
|---|---|---|
| how big is the oval, how heavy | **1**, 5 s | `in_view`: 122 x 90 studs, 97.4 x 71.8 cm, about 429 g |
| open Pods; which way every part's studs point | **3**, 11 s | `view_board {"studs": true}`: up 32, front 2, none 2; the two headlight bricks named |
| every headlight brick picked out | 3, 12 s | `highlight="\"4070\""` **refused again**; `look_at_model part=4070`, then `highlight=[6, 11]`. The session called the refusal "a bug in the app" |
| save this view as "Three quarter", then a picture from it | 2, 13 s | **no tool saves a view**; it drew from the app's three-quarter angle and told the person how to save one |
| A4, upright, a pale blue page; page 1 as it prints | **2**, 14 s | `page_setup` once, then `booklet_page 1`. It noted that a landscape page would fit the long model better |
| a short video of the build, and what happens in it | 4, 115 s | `render_model` build, and its job three times (20 s, 12 steps). It described six frames, and noticed the camera is framed for the finished model, so "the single plate and the pods look small, up in the top left corner" |
| check for problems, show where each is | 4, 18 s | `check_design`, `weakest_joints`, `look_at_model`, then a `view_board` highlight of the 16 loose pieces' bases |
| pull out brick 3 of the first step; show the page | 4, 16 s | `edit_booklet` pull `parts: [3]`, which was taken. It found that **the earlier pull of both wings had not come back** after the reopen (Found on the way) |
| add my loose bricks to my collection; what would I still need | 2, 9 s | **refused: signed out**. The need list was right (36 pieces, 8 kinds); it said none of the three parts was in Pods |
| take back what you added | 0, 4 s | nothing to take back, and it said so |

All 37 tasks took **93 calls in 10.4 minutes**. Every round five tool a
session could reach was found and used unprompted, each in one call:
`view_board` studs, `page_setup`, `in_view`'s size, a pull by brick
number, and the build video's frames.

Where a session still needed more than the window, or guessed:
1. **A part number in `highlight` is refused when quoted,** and its own
   description shows it quoted. This happened twice, costing a call each
   time, and once the session called it a bug.
2. **No tool saves a view,** and none lists the saved ones. A person who
   asks their Claude to keep an angle is told to do it by hand.
3. **A booklet pull may not survive a save and an open** (Found on the
   way). The session could not tell whether the pull was lost or
   overwritten.
4. **The build video frames the finished model,** so its first steps are
   small in a corner of the picture. A person sees the same.
5. **The collection needs an account.** Signed out, `edit_collection` is
   refused and the dialog is read-only. LEGO from my bricks keeps a
   person's bricks without one.
6. **Nothing puts one saved model into another.** That is intomodel3,
   in flight.

## Round five, item by item

Every merged unit's bar is met on its probe today, except playlink's web
half. The units that are not merged are lights, animals and realjoints3.
Two things the bars did not hold showed up through a session:
- seeing2's part-number selector fails as sessions call it;
- savedviews gives a session no way to save a view.

| unit | its bar | where it stands on `pre261` today | proof |
|---|---|---|---|
| buildturn | each Build it page's view and up within 1° of its booklet page's, on the car and the 44 files with authored turns; step 6 turned over | **met**, 28 checks, none failed, on a phone's 390 x 844. 832 of 832 turned pages are within 1° over 45 files (worst 0.00°), and 3,850 others are upright as before. The car's step 6 is seen from under, with its new parts 70.2% in sight (75.5% on its booklet page). A drag turns the view 75°, and Next goes to step 7's own view | `buildturn` today |
| mybricks (mybricks2) | 12 loose lots, 3 actions each; What do I need? falls by exactly them; 1 call over MCP and Take back exact; kept over a restart and a sign-in elsewhere; older collections unchanged lot for lot | **met**, 62 checks, none failed, at 1280 x 720, signed in. 12 lots took 3 actions at most each. What do I need? fell from 31 lots to 19. Over MCP: the 12 in 1 call, the need in 1, and Take back exactly the 12. Kept over a restart and on another device; the old collection lot for lot. The MCP walk was signed out and was refused (the bar's calls are made signed in) | `mybricks` (relay) today; MCP walk |
| seeing2 | a stud map in 1 call; selectors by part number, colour and step; six frames of a video; a check's findings pictured; a pull by brick number | **met**, 31 checks, none failed. The car's stud map in 1 call, 61 of 61 right. `highlight="3024"` picks exactly the 10 1 x 1 plates, and `"step:3"` exactly 6 parts. The video comes as six frames, the findings in magenta. A pull by brick number is kept, and a part not in the step refused. Over MCP: the stud map in 1 call, both pulls by brick number drawn, and the video described from its frames. **The part-number selector fails as sessions call it** (quoted) | `seeing2` today; MCP walk |
| pagesetup (and pagesetup2) | A4 portrait in mm within 0.5; Letter landscape; page colour; a style given to another model in 2 actions; kept; 1 call over MCP | **met**, 127 checks, none failed. A4 upright is 210.0 x 297.0 mm, and Letter on its side 279.4 x 215.9, on every page. The 1:1 guide is 32.00 mm (32.09 in the PDF), the page colour reads back off the PNG and the PDF, and a style went to the gatehouse in 2 actions. Kept over an open. Walk: Ctrl+Shift+B, four papers, both ways up. MCP: `page_setup` in 1 call | `pagesetup` today; walk; MCP walk |
| buildparty | two phones join in 2 actions each; the car dealt, all 61 once; progress across in 2 s; the joining step; leave and rejoin | **met**, 22 checks, none failed, on a phone's 390 x 844. Two phones joined, and the car was dealt 31 and 30 (61, none twice). A part done on one showed on the other in 14 ms of its own, at a load of 82. The joining step was shown, a phone that joined again was back on its page, and every target is 44 points or more. rel-m271's preview: "two phones built the car together, each its own share, and put it together" | `buildparty` today; m271 `buildparty` flow |
| modelinfo | the size within 0.1 mm, in studs, plates and cm; the selection's; current within a frame; nothing cut at 1280; `in_view` | **met**, 54 checks, none failed, at 1400 x 900. The car's and each selection's size are within 0.1 mm (0.000 off). The size is current a frame after an edit, an undo and a redo, and nothing on the status bar is cut. Walk: both, at both sizes. MCP: `in_view` in 1 call, twice. **The number styles are mixed, and the weight beside it moves** (Found on the way) | `modelinfo` today; walk; MCP walk |
| lights | a spot light changes 0 px outside its cone; neon lights its neighbours; kept | **not merged.** Its report met every line, but lreview found nine faults, which are being fixed. The walk finds no lights | walk |
| savedviews | three views back within 0.1° and 0.1 LDU; a key each; queued renders; presets; `view_model`/`render_model` by name in 1 call | **met**, 41 checks, none failed, at 1280 x 720. Three views came back within 0.0002 LDU and 0.0000°. Ten keys under each preset, none taken. A queued render is the window's view, 0.0004 apart. Render has presets, and `view_model` and `render_model` work by name in 1 call. Walk: back 0.000° and 0.000 LDU off. **Over MCP a view can be used but not saved** | `savedviews` today; walk; MCP walk |
| keys2 | Render, the queue, the cut shapes, Into this model, the Pick a Brick list and the library keyed under four presets; walk 106 or more | **met**, 41 checks, none failed. The eight are keyed under all four presets and on the web, none taken. Walk: **116 of 221**, F9 in 1 press. The keys sheet's "a box/a sphere/a cylinder" are still not found by "cut away" | `keys2` today; walk |
| playlink | a `?motion=` link moving within 2 s of the model shown | **merged after the snapshot** (`f41961d7`). On the desktop it is met: 393 to 572 ms. On the web it is not met: 3.2 s on a laptop and 5.7 s on a phone, down from 8.9 and 7.8. playweb is on it | its report |
| striproom | Cut away's strip inside the model's room at both sizes with every column open | **met**, 103 checks, none failed, at 1280 x 720: every control of the strip (6 to 9) is inside the model's room for each shape, with each column open. Walk: 5 of 5 buttons inside, at both sizes | `striproom` today; walk |
| thumbs | `.ldr`, `.mpd`, `.io` as 256 px pictures by the installed thumbnailer in 3 s or less; unknown parts drawn | **met**, 28 checks, none failed. `.ldr`, `.mpd` and `.io` are drawn at 256 x 256 in 465 to 605 ms (at most 3,000). Each is the app's corner view, with 0.994 to 0.996 of its outline shared. Its report: 426 to 702 ms through GNOME's own factory | `thumbs` today |
| arview | In your room on a phone, its GLB the one Export writes, under a set size; not on a desktop; the first load no heavier | **met** for its GLB: on five files the page's GLB is Export's, with 0 parts differing. The phone's offer and the size cap are its web flow's, which passed in its report. Not live: rel-m271 does not carry it | `arview` today |
| realjoints3 | 957 to 963 or more real sub-models | **not started**: it waits for animals' catalogue | the lead's queue |
| animals | 63 of 63 by hand; every saddle at 0 LDU | **ready, held**: 63 of 63, and saddles 27 of 27 at 0.00. Its catalogue rebuild carries 716 parts' socket drift, which folds into realjoints3 | its report |
| socialtails | /builds cards 480 px wide or less; Based on finds 7140 by name; `based_on_flow` | **met** on rel-m271's preview: a build photo's card copy is 480 x 720. "X-wing Fighter" offers 7140-1 sixth, and Down 5 then Enter puts it in. `based_on`, `builds`, `mentions`, `people`, `designers` and `profile` all passed | m271 preview flows |
| tracks (round four's) | a curve joins a straight in 1 drag; sixteen curves close a circle; an oval by a session in 3 calls | **met**, 25 checks, none failed, at 1280 x 720. A curve goes down in 1 drag, and the next goes on its end 0.000 LDU off. 16 curves in 16 clicks close the circle, 0.001 LDU apart, and an oval of 20 takes 2 calls with 0 free ends. Over MCP the oval was joined by `attach`: the build itself took 3 calls (clear, check, submit), and 9 with the session's own looks and its measurement, 0 apart | `tracks` today; MCP walk |

**Built since round five's plan, beyond it:**
- mirrorfix: every mirrored part is its mirror image or is named as
  having none.
- mirrorpattern: a pattern's pod is the same as `mirror_parts`'s.
- menurows: View down to 412 units.
- booksafe and togethersafe: a model file can put no script into a
  booklet, and a peer can send no model that runs code.
- figlift, checks267, leaves3 (the web's start), pyfast (the Python suite
  in 114 s), and directcolour (each writer gives a direct colour its own
  RGB).

**Round five's "Next",** where each stands:
- **A trackpad's and a phone's twist** (LeoCAD): not built. `cad_camera.gd`
  reads pan and pinch, no twist (unit twist).
- **Animated GIF** (StudWorx): not built. Renders write WebP and MP4;
  GIF appears only as an input (unit video2).
- **An exploded view's spread, four viewports, a wanted list as a counted
  bin, a reverse booklet, Orthanc's three:** not built; carried.
- **Make a part's clips, bars and wedge plates:** not built.
  `element_maker.gd` `FAMILIES` is brick, slope, inverted, round, curved,
  bracket and technic (unit makepart2).
- **The tooling asks** (a probe's own Documents and Pictures, and
  `shots/.gdignore`): done.

## What the field does that Brickworks does not, yet

The latest versions, as of 7 November 2026:
- **Studio 2.26.10_1** (27 October), unchanged. Its help centre has no
  article newer than 25 September. bricklink.com was down for maintenance
  again and sent every page to its notice.
- **LeoCAD 26.09**, and a continuous build of 5 November.
- **StudWorx**: a release dated 6 November, new since APP_UX5.
- **LDCad 1.7 Beta 2b**; 2c is still not out. **Bricksmith 3.1** (2022).
- **LPub3D 2.4.9** (January 2025), read for its booklet features, which no
  earlier round covered.
- **Mecabricks**: no release. Its forum asks for near-identical parts to
  be folded behind a "show variants" box, which Brickworks' bin already
  does (a tile's +N).
- **Phone apps:**
  - LEGO Builder 4.3.11 and Brickit 5.8.0 (4 November);
  - BUF3D Lite 1.261103 and Buf3D+ 1.261024;
  - brckd 1.0;
  - **BrickBack** (iOS) and **BrickBuilder AI** 1.0.5, both new.
- **AI and agent tools:**
  - **Kinebrick Studio v0.2.0-beta.1**;
  - **ldraw-mecha v0.5.0**;
  - **brick-tidy**, **ldraw2print** and **EasyCraft VR**, all new;
  - "Make it Walk" (arXiv, 29 October);
  - the Brickognize API 1.0.0.
- Rebrickable refused readers (403) again; its set compare was read
  through the Wayback Machine.

Each list is ranked by how much a person building would feel it. Each
item was checked against `shell.gd`'s commands, `tools/mcp_tools.json`
and the files named.

**Studio** (help pages not covered before)
1. **The booklet's own look:**
   - piece styles for the parts box (frame, fill, corners), the step
     number and the new parts' outline;
   - page locks, so a page laid out by hand stays as it is;
   - a cover the designer lays out.

   Brickworks' `BookletSheet` keeps the paper, the margins, the colour, a
   picture, the number's size and the parts' scale (`booklet_sheet.gd`).
   The parts box, the number's font and colour, and the outline are
   fixed. These are drawn in `booklet.gd` `_head` and `_entry`,
   `booklet_read.gd` `LOOKS`, and `booklet_studio.gd`'s ink. The cover
   (`booklet.gd` `_cover`) is a fixed blue band, badge and title.
2. **Step descriptions:** a step can have a name or a line of text, shown
   while stepping through the model and printed in the booklet.
   Brickworks' steps are numbers only: `Instructions.Step` has none, and
   `build_steps.gd` `caption()` is "Step N".
3. **Custom palettes:**
   - a palette of chosen parts and colours, kept and shared between
     models;
   - sub-assemblies kept in a palette and used again.

   Brickworks has Favourites (`part_shelf.gd`), one list, of parts only.
4. **The mosaic maker's controls:**
   - the picture cropped where the person wants;
   - the colours chosen (BrickLink's, or a set list);
   - mixed plate sizes to cut the part count;
   - a price.

   Brickworks crops to the middle (`mosaic_art.gd` `picture_cells`). Its
   palettes are fixed (`mosaic.gd`) or set by a guide, and it has no size
   mixing.
5. Smaller:
   - a Hide tool that counts what is hidden;
   - a ground that lowers itself to the lowest part;
   - linked sub-models (Brickworks' copies of a sub-model are already one
     sub-model, and Make unique parts them, so this is not a gap).

**StudWorx** (its 6 November release and FEATURES.md)
1. **A file changed by another program is noticed.** Brickworks watches
   only its own save file, `user://models/<title>.ldr`
   (`model_store.gd` `saved_elsewhere`, polled from `main.gd`
   `_watch_other_tabs`). A model opened from anywhere else, and edited in
   LDCad or a text editor, is not watched.
2. **Sub-models:** flatten one into its parent, move a selection into a
   new sub-model, and export each sub-model as its own file. Brickworks
   makes a sub-model from a selection and ungroups one, but exports only
   the whole model.
3. **Pictures of a range of steps** at a chosen ratio. Brickworks writes
   the booklet's pages and a render of the current view.
4. Smaller: zoom to a drawn region; look square at a face; a right-click
   menu that can be rearranged; toon and matte looks; stud styles; upright
   grids.

**LPub3D** (its release notes and site)
1. **The designer's cover, header and footer,** with their own text and
   pictures, on every page. Brickworks' cover is fixed, and its pages
   carry the page number and a progress bar.
2. **Build modifications:** a later step can take parts off or move them,
   such as a temporary support or a door shown open, and the booklet draws
   each step as it then stands. Brickworks' steps only ever add parts.
3. **The model so far, as a page** at any step: a full-page picture between
   steps. Brickworks draws the finished model at the end only.
4. Smaller: the parts list sorted and split across pages, and a part's
   picture swapped for another.

**Phone and web tools**
1. **Putting old sets back together from a mixed tub** (BrickBack,
   brick-tidy). A person marks the sets they once owned. The app tracks
   each one's found and missing parts, and says which set is closest to
   whole. Brickworks' collection holds sets as complete and loose parts as
   loose. Nothing tracks a set with parts missing.
2. **A photo finds a set or a minifigure** (the Brickognize API's
   `/predict/sets/` and `/predict/figs/`; LEGO Builder reads a booklet's QR
   code; LEGO from my bricks' photo analysis). Brickworks calls only
   `/predict/parts/` (`brickognize.gd`), and sets are added by typing their
   numbers (`collection_dialog.gd`).
3. **The step's parts found in a photo of a pile** (Brickit). Brickworks
   finds one part at a time from a photo.
4. **The whole model moves** (Kinebrick Studio's car drives; ldraw-mecha
   animates a plane taking off). Brickworks' motions turn and slide joints
   (`motions.gd`). Nothing moves the whole model along a path.
5. **Comparing two sets** (Rebrickable's set compare): the parts in both,
   the parts in only one, and what to buy to build one from the other.
   Brickworks' Compare compares a model with its own saved versions
   (`compare_view.gd`). Its What do I need? compares a model with the
   whole collection.
6. **3D printing** (ldraw2print): a multicolour 3MF, with parts scaled
   and their fitting faces kept, and test pieces. Brickworks writes STL as
   one mesh with no colours (`exports.gd`), and reads 3MF but does not
   write it.
7. Smaller:
   - Rebrickable's Workbench (low while the gallery has one designer);
   - EasyCraft VR;
   - a walker by its gait ("Make it Walk");
   - BUF3D's progress through each batch.

Checked and **not gaps:**
- a photo of a pile over MCP (`edit_collection`, signed in);
- build and take-apart films, named sub-models, the stud map and the
  selectors, saved views, the app as a PWA, `.io` import, loose parts
  flagged, challenges, collections, set inventories, buying a model's
  parts, the gallery by theme, guided building, What do I need, AR (arview)
  and lights (once merged), and text or a photo to a model;
- from the desktop tools: typed position and rotation, connectivity,
  copy-mirror, a set-to-build bin, colours never made, recent parts, the
  render queue, the licence choice, a transparent background, a turned
  step, keymap presets, and turned and faded notes;
- StudWorx's find and replace, select connected, isolate, cutaways,
  explode and What's This;
- the page editor's rulers. COMPETITIVE's "no rulers" is out of date.

**The lead's candidates** (`queue.md`):
- **The bin's search puts 6141 (Plate Round 1 x 1) first for
  "plate 1 x 1",** where a person means 3024 (unit words6).
- **The keys sheet does not find "a box", "a sphere" and "a cylinder" by
  "cut away"** (keys2's open item). `controls_dialog.gd` `_says` matches
  each typed word against the keys, the description and the section, and
  the cut shapes' rows do not say "cut away" (unit words6).
- **grab_probe logs 15 to 20 'det == 0' engine errors** in 42125-1's
  steering cases. `mechanism.gd` `_rest_on_studs` inverts a part's
  transform that has no size (unit mechdet).
- **A window close waits for Godot's own Save dialog**: dialogclose is
  running. **The flows' scrollTo race**: flowscroll is running. **Direct
  colours in Export**: directcolour is merged. **A 1,118-brick edit**:
  bigedit is live (rel-m267). **The racer's finger reds**: fixed on
  stage225. **Units take a free live-DB slot** (trainspeed): the lead's
  own tooling, not planned here.
- **intomodel3**, after keeptext4: in flight.

**SOCIAL.md's and ROADMAP.md's open rows a unit could move**
- **Real joints' last refusals** (ROADMAP 4): realjoints3, after animals.
  Carried.
- **Make a part's next families** (ROADMAP): clips, bars and wedge plates
  (unit makepart2).
- **The bin's tooltip counts side studs as footprint** (87087 reads
  "1 x 2", 4733 "2 x 2", 30414 "4 x 2"). `parts_bin.gd` reads
  `footprint_studs`, which is the part's bounding box (unit words6).
- **A panel moved to the other edge** (Properties, the assistant, the
  bin): the edges are fixed in `main.gd`'s `SideDock` setup (unit
  panelside).
- **Edge lines and a studs-off view:** there is no setting for either.
  The edges are shading in `plastic_body.gdshaderinc`. This waits for
  lights, which edits the same shaders (unit edges).
- **SOCIAL:**
  - the week by email (SOCIAL 7, "low now");
  - an email for a mention;
  - Based on's pictures of works made elsewhere;
  - More like this saying why.

  All are low while the gallery has one designer, and none is ranked
  (Next).
- Measurements, not units:
  - the booklet showing a run's length (ROADMAP 7);
  - black edges again, now that the parts box shows the dome;
  - a modern LEGO booklet, calibrated;
  - the parts real sets use together, and the designer's silhouette lever
    (design bench rounds).
- **Stale lines for their owners:** ROADMAP 7 still says "The step player
  still does not roll", but buildturn is live. SOCIAL's /builds,
  Based on, @ and More like rows still list what socialtails built
  (`7d3b2ede`).

## The gaps, by value to a person building

1. **The web's first visit:** 12.0 s cold and 7.6 s warm against 10 and 4.
   A warm visit compiles the scripts for as long as a cold one. This is
   carried to the lead's web-start work and not planned here.
2. **Work in the booklet may be lost on a save and an open.** A person
   who pulls parts out, then saves and opens the model again, finds the
   pulls gone, without a word. This breaks the baseline of no silent data
   loss.
3. **On a laptop the timeline's Done and Instructions are past the
   window** with the usual panels open. They cannot be reached, and
   nothing says they are there.
4. **The person's own Claude cannot keep a view or pick out a part number
   the way its own tool describes.** The owner builds this way.
5. **The weight moves with nothing added, and the size mixes number
   styles.** A number that changes by itself is not trusted.
6. **The booklet looks like every other Brickworks booklet.** Designers
   who share or sell their instructions want their own cover and their
   own styles (Studio, LPub3D).
7. **Sets owned with parts missing, and adding a set by its photo.** Most
   people own old sets mixed in a tub (BrickBack, brick-tidy, Brickognize).
8. **Can I build this from that set?** This is Rebrickable's most used
   question, and Brickworks compares a model only with its own saves.
9. **A collection needs an account.** A first visit cannot say what they
   own (LEGO from my bricks).
10. **Steps have no names.** "Build the cockpit" helps a reader through a
    long booklet (Studio).
11. **The mosaic maker crops to the middle and picks its own colours.**
    Mosaics are among the most shared builds (Studio).
12. **The build video frames only the finished model, and there is no
    GIF.** People share these (StudWorx).
13. **A model cannot drive or fly** (Kinebrick Studio, ldraw-mecha).
14. **A file edited in another program is not noticed** (StudWorx).
15. Smaller:
    - the bin's "plate 1 x 1", the keys sheet's "cut away", and the
      tooltip's footprint;
    - Make a part's clips, bars and wedge plates;
    - a colour 3MF for printing;
    - panels on the other edge;
    - custom palettes;
    - a phone's twist;
    - edge lines and studs off;
    - the 'det == 0' errors;
    - build modifications;
    - the model so far as a page;
    - sub-models flattened and exported each;
    - pictures of a range of steps.

## The units

Twenty-three, ranked, each in its own worktree off the next stage. The
registries below are shared, as `tools/suite/*.txt` is. A unit adds its
own lines there, in a block of its own, and changes no one else's:
- `src/ui/shell.gd`'s `_define` and `MENUS`;
- `src/ui/keymap.gd`'s `PRESET_KEYS`;
- `src/net/app_tools.gd`'s `COMMANDS`, `WINDOW_ONLY`, `GUIDE`, its tool
  list and its dispatch;
- `tools/mcp_tools.json`, written by `mcp_sync_probe --write`;
- `docs-site/generated/menus.json`;
- `src/ui/language.gd`'s tables (every new word in German, French and
  Spanish).

Every new probe goes on its own line in `tools/suite/*.txt`. Every feature
added gets its entry in `.claude/skills/verify/` in the same commit. A
unit that writes the model file (pullkept, stepnames, watchfile,
localbricks) gets an independent review before it merges, and its probe
checks the reopened model's parts and lines. None of the twenty-three
needs the owner.

| # | unit | gap | size | risk | wave | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|---|
| 1 | **pullkept** | 2 | S | medium | 1 | `src/assembly/booklet_looks.gd` (`read`, `_step_lines`, `_booklet_lines`); new `src/dev/pullkept_probe.gd`. `model_store.gd` read only | see below |
| 2 | **timelinefit** | 3 | M | medium | 1 | `src/ui/steps_bar.gd` `_build`; `main.gd` `_fit_panels`, `_fit_bin`, `_tool_column_shown`, `_arrange_columns`; new `src/dev/timelinefit_probe.gd` | see below |
| 3 | **mcpsee3** | 4 | S | low | 1 | `src/net/see_tools.gd` `_selected`; `src/ui/saved_views.gd` (a save from a given camera, and the list); a `save_view` tool and `in_view`'s saved views, each a block of its own in `app_tools.gd`; new `src/dev/mcpsee3_probe.gd` | see below |
| 4 | **weighsure** | 5 | S | low | 1 | `src/assembly/stability.gd` (`check`, `Report.summary`), `balance.gd` `_read`, `model_size.gd`, `src/ui/status_bar.gd` (`amount`, `_show_size`); new `src/dev/weighsure_probe.gd`. **Not** `main.gd` | see below |
| 5 | **booklook** | 6 | M | medium | 1 | `src/assembly/booklet.gd` (`_cover`, `_head`, `_entry`'s box), `booklet_sheet.gd`, `booklet_read.gd` `LOOKS`, `src/render/booklet_pdf.gd` `_font`, `booklet_studio.gd`'s ink, `src/ui/page_setup_dialog.gd`; new `src/dev/booklook_probe.gd`. **Not** `booklet_looks.gd` | see below |
| 6 | **mysets** | 7 | M | medium | 1 | `src/net/brickognize.gd` (sets and figs); `src/ui/collection_dialog.gd`; `src/collection/collection.gd` (a set's found and missing lots); `api/collection.js`, additive only; new `src/dev/mysets_probe.gd` and its API test | see below |
| 7 | **comparesets** | 8 | M | low | 1 | `src/ui/compare_view.gd` (a second mode: any two of a model, a set, a saved model); new `src/parts/parts_compare.gd`; `parts_list`'s `compare` in `app_tools.gd`, a block of its own; new `src/dev/comparesets_probe.gd`. `collection.gd` read only | see below |
| 8 | **localbricks** | 9 | M | high | 2 (after mysets) | `src/collection/collection_store.gd`, `collection.gd`, `src/ui/collection_dialog.gd`; `_edit_collection` in `app_tools.gd`; new `src/dev/localbricks_probe.gd` | signed out: 12 loose lots and 2 sets added, kept over a restart; What do I need? uses them; `edit_collection` works, and Take back is exact. At sign-in the two are offered as one, with nothing lost: an account with its own lots ends with every lot of both, the person asked first. Signed out again, the account's lots are not left editable on the device. `mybricks`, `collection` pass; a review before merge |
| 9 | **stepnames** | 10 | M | medium | 2 (after pullkept, timelinefit, booklook) | `src/assembly/instructions.gd` `Step`; `build_steps.gd` `caption`; `booklet_looks.gd` (a step's name, `0 !BRICKWORKS STEP_NAME`); `src/ui/steps_bar.gd` `_show`; `build_mode.gd` `show_page`; `booklet.gd` `_entry`; new `src/dev/stepnames_probe.gd` | a name given to step 3 shows in the timeline, in Build it on a phone, and on the booklet page beside its number; kept over a save and an open, byte for byte; an older build opens the file whole and keeps the line; `edit_steps {"op": "name"}` in 1 call; `booklet_edit`, `steps_kept`, `build_steps` pass; a review before merge |
| 10 | **mosaic2** | 11 | M | low | 1 | `src/ui/mosaic_dialog.gd`, `src/assembly/mosaic_art.gd`, `mosaic.gd`; `mosaic_probe` extended | a crop drawn on the picture: every cell from inside that rectangle, 0 from outside; a palette chosen (all, a set list, what I own) honoured cell for cell; mixed plate sizes cut the car photo's part count by 30% or more with the picture the same to the cell; a parts list and a Pick a Brick file for it; `mosaic` passes |
| 11 | **video2** | 12 | M | low | 3 (after lights) | `src/render/build_render.gd`, `studio_render.gd` `_prepare`'s framing, `render_output.gd`, new `src/render/animated_gif.gd`, `src/ui/render_dialog.gd`; new `src/dev/video2_probe.gd` | the build video's first step's parts fill 40% or more of the frame's height, the last frame the whole model; GIF of a turntable at 256 colours, 8 MB or less, plays in a browser; `render`, `motions_render` pass |
| 12 | **drive** | 13 | M | medium | 3 (after playweb) | `src/assembly/motions.gd` (a path), `motion_player.gd`, `src/ui/pose_panel.gd`, `src/render/motion_render.gd`; new `src/dev/drive_probe.gd` | the racer drives a 32-stud straight and a quarter circle; its wheels turn once per wheel circumference travelled, within 2%; kept in the file; rendered; a play link plays it; `motions`, `motions_panel` pass |
| 13 | **watchfile** | 14 | M | medium | 2 (after keeptext4, timelinefit) | `src/parts/model_store.gd` (`know`, `saved_elsewhere`, `_changed_since_known`, `save_file`); `main.gd` `_watch_other_tabs`; `src/ui/reload_offer.gd`; new `src/dev/watchfile_probe.gd` | a model opened from any folder, then changed by another program (a brick added by a text edit), is offered back within 2 s; with unsaved edits the offer asks first and loses neither; the app's own saves are never offered; a file deleted elsewhere is said; `store`, `autosave_paths` pass; a review before merge |
| 14 | **words6** | 15 | S | low | 2 | `src/parts/part_search.gd` (ranking); `parts_bin.gd`'s tooltip (studs on top, not the bounding box); `src/ui/controls_dialog.gd` `_says` and the cut shapes' words; new `src/dev/words6_probe.gd` | "plate 1 x 1" and "1x1 plate" put 3024 first; the walk's 30 words still 27 first, and the MCP search's the same; 87087 reads "1 x 1, a stud on one side", 4733 "1 x 1, studs on four sides"; "cut away" in the keys sheet finds the box, the sphere and the cylinder; `search`, `keysheet`, `library_search` pass |
| 15 | **makepart2** | 15 | M | medium | 2 | `src/parts/element_maker.gd` (`FAMILIES`), `src/ui/element_dialog.gd`; `element_probe` extended | a clip, a bar and a wedge plate (left and right) made: each part's bounds within 0.01 LDU of the LDraw part it copies, its connectors the same in number and kind; a made clip snaps onto a made bar by hand; each in 1 call over MCP; `element`, `element_files` pass |
| 16 | **realjoints3** | 15 | L | high | 3 (after animals) | the parts pipeline (`tools/`), `catalogue.json` rebuilt; animals' 716 parts' socket drift folded in | the real sub-models from 957 to 963 or more, none newly refused; each named pair placed by hand and over MCP |
| 17 | **modsteps** | 15 | L | high | 3 (after stepnames) | `instructions.gd`, `build_steps.gd`, `booklet_looks.gd` (a later step taking parts off or moving them, kept as lines of its own); `booklet.gd`; new probe | a support added in step 2 and taken off in step 5: the booklet draws it in steps 2 to 4 and not after, the parts list counts it once; Build it the same; kept over a save and an open; an older build opens the file whole |
| 18 | **print3mf** | 15 | S | low | 2 | new `src/parts/mesh_3mf.gd`, beside `mesh_export.gd`; `src/ui/exports.gd`'s row; the export registry | the car as a 3MF: one object per colour, each with its colour's RGB; read back by a strict reader (the 3MF core schema), every triangle's winding outward; its size in mm the model's within 0.1; the GLB and STL exports unchanged to the byte |
| 19 | **edges** | 15 | M | medium | 3 (after lights) | `src/render/plastic_body.gdshaderinc` and the plastic shaders; `brick_world.gd`; `src/camera/view_prefs.gd`; a View row | View, Edges: off draws 0 px of seam; Studs off draws no stud and keeps every part's place; kept as a preference; the default view unchanged to the pixel; `pathtrace`, `true_colour` pass |
| 20 | **panelside** | 15 | M | medium | 3 (after timelinefit, watchfile) | `main.gd`'s columns (4893-5174, `_fit_panels`, `_model_rect`); `src/ui/side_dock.gd`; `split_view.gd`; `shell_prefs.gd` | Properties and the assistant on the left and the bin on the right, by a View row and by dragging a panel's tab; kept over a restart; every field in sight at 1280 x 720 and 1400 x 900 both ways round; `roomfit`, `quiet`, `timelinefit` pass |
| 21 | **palettes** | 15 | M | low | 3 (after words6) | `src/ui/part_shelf.gd`; `parts_bin.gd`'s chips; new `src/dev/palettes_probe.gd` | a palette of 12 parts in their colours and one sub-assembly, named, kept, opened in another model in 2 actions; the sub-assembly placed whole from it; Favourites unchanged |
| 22 | **twist** | 15 | S | low | 2 | `src/camera/cad_camera.gd` (two fingers' turn from their screen drags); new `src/dev/twist_probe.gd` | on a phone's 390 x 844, two fingers turned 90° turn the view 90° ±5° about the vertical; a pinch and a slide do what they did, within 1%; `camera`, `touch` pass |
| 23 | **mechdet** | 15 | S | low | 2 | `src/assembly/mechanism.gd` (`_rest_on_studs` and its callers; the root, not a guard) | `grab_probe` logs 0 'det == 0' errors (from 15 to 20), and its results are unchanged; the steering cases the same to the degree |

**Which can run at once.** Each wave's files are its own: no two units
in a wave share a file, beyond the registries.
- **Wave 1, eight at once:** pullkept, timelinefit, mcpsee3, weighsure,
  booklook, mysets, comparesets, mosaic2.
  - booklook keeps out of `booklet_looks.gd` (pullkept's). If its cover
    must be kept per model, it waits for pullkept.
  - weighsure keeps out of `main.gd` (timelinefit's).
  - comparesets reads `collection.gd` and does not edit it (mysets').
  - m271reds, running, is fixing CollectionDialog's label at 768 px, so
    mysets rebases on it.
  - pullkept and keeptext4 both write the model file: whichever merges
    second rebases, and the review reads both together.
- **Wave 2, eight at once,** each once its wave 1 owner has merged:
  - localbricks after mysets (`collection.gd`, `collection_dialog.gd`);
  - stepnames after pullkept, timelinefit and booklook (`booklet_looks.gd`,
    `steps_bar.gd`, `booklet.gd`);
  - watchfile after keeptext4 (`model_store.gd`) and timelinefit
    (`main.gd`);
  - words6, makepart2, print3mf, twist and mechdet share nothing with
    anyone and could start in wave 1 if a slot is free.
- **Wave 3, seven:**
  - video2 and edges after lights (`studio_render.gd`, `render_dialog.gd`,
    the plastic shaders);
  - drive after playweb (motion playback);
  - panelside after watchfile (`main.gd`);
  - palettes after words6 (`parts_bin.gd`);
  - realjoints3 after animals (the catalogue);
  - modsteps after stepnames (`instructions.gd`, `booklet_looks.gd`).

**1. pullkept: what is set in the booklet comes back.**
- **Change.** Every per-step booklet line is read back on open, to the step
  it was written for: pull, colours, turn, zoom, notes, place and page.
  This includes a step whose parts open as a sub-model's own steps, as
  Pods' did. A line that matches no step is kept in the file and named on
  open ("the pull on step 1 matches no step now"), never dropped.
  `booklet_layout`, which names each step's pulls, names them after an
  open as before it.
- **Bar** (`pullkept_probe`):
  - red first: the MCP walk's Pods.ldr opened, and step 1 pulls 41770a
    and 41769a, as when saved;
  - every booklet line of every test model that has them (the 44 files
    with authored steps among them) kept over open, save and open, byte
    for byte;
  - a step's parts moved into a sub-model after a pull: the pull follows
    its parts, or is named on open;
  - `booklet_edit`, `steps_kept`, `booklet3` and `pagesetup` pass;
  - a review before merge.

**2. timelinefit: the timeline and the status bar inside the window.**
- **Change.** At any window size the model's room gives way before
  anything leaves the window. The timeline's rows wrap or fold into More,
  as its booklet row already does. `_fit_bin` takes the tool column's
  width into account. Nothing a person needs to press is ever past the
  edge.
- **Bar** (`timelinefit_probe`, at 1280 x 720, 1400 x 900 and a tablet's
  1024 x 768):
  - with the bin, Properties, Stress's panel, the assistant and the
    timeline open, every control of the timeline, the top bar and the
    status bar lies inside the window: 0 px past the right edge;
  - Done and Instructions answer a click;
  - the model's room is 400 px wide or more;
  - `roomfit`, `quiet`, `striproom` and `split` pass.

**3. mcpsee3: a session keeps a view and picks a part out first time.**
- **Change.**
  - `save_view {"name": ...}` saves the window's view under a name, as
    Save this view… does. `in_view` lists the saved views.
  - `highlight=` and `xray=` take a part number with or without quotes.
    The description shows it bare (`3024`), and a refusal echoes what was
    sent without quotes of its own.
- **Bar** (`mcpsee3_probe`, the tools called as a session calls them):
  - `save_view` in 1 call, back within 0.1° and 0.1 LDU by Alt+Shift+N
    and by `render_model {"view": NAME}`;
  - on the MCP walk's Pods, `highlight="4070"`, `"\"4070\""` and
    `"'4070'"` each pick out exactly #6 and #11, its two headlight bricks;
  - `mcp_sync`, `mcp`, `read_only`, `seeing2` and `savedviews` pass;
  - then the MCP walk's round five tasks rerun: v3 and v4 in 1 call each
    (said, not gated).

**4. weighsure: one weight, one style of number.**
- **Change.**
  - The weight on the status bar counts every part. A part whose shape
    is not loaded yet is counted from the catalogue's mass, or the number
    reads "about" until all are weighed.
  - Each line of the size is in one style. Studs and plates are in
    quarters only when every number is a whole quarter, and otherwise in
    decimals throughout. Centimetres are to two places throughout.
- **Bar** (`weighsure_probe`, at 1280 x 720):
  - the walk's eight 1 x 4s read the same weight at every frame after the
    last is placed, with a part in hand and after a turn;
  - the car reads 52 g from its first number;
  - every model `tested_models` opens weighs the same with all shapes
    loaded and with none;
  - the car reads "4.5 × 10.8 studs, 15 plates high · 3.60 × 8.64 ×
    4.96 cm", with no fraction beside a decimal, and modelinfo's 0.1 mm
    still holds;
  - `modelinfo`, `whatsthis` and `languages` pass.

**5. booklook: the booklet, the designer's way.**
- **Change.** Page setup gains the following, all kept with the model and
  in saved styles:
  - a Cover page: title, subtitle, a picture of the model or the person's
    own, and a line of their text, laid out on the cover;
  - a header and a footer of their own text on every page;
  - the parts box's frame colour, fill and corners;
  - the step number's colour and font size;
  - the new parts' outline colour.
- **Bar** (`booklook_probe`):
  - a cover with the person's title, picture and line, read back off the
    PNG and the PDF;
  - a footer on every page of the gatehouse's booklet;
  - a parts box drawn in the chosen frame colour, with 0 px of the old
    colour;
  - the default booklet unchanged to the pixel;
  - a style with all of these given to another model in 2 actions;
  - `booklet_pdf`, `booklet3`, `pagesetup` and `instructions` pass.

**6. mysets: the sets a person owns, as they really are.**
- **Change.**
  - Add sets takes a photo: of a box, a booklet's cover or a
    minifigure, through Brickognize's `/predict/sets/` and
    `/predict/figs/`, with the top three to choose from.
  - A set in What I own can be marked as having parts missing. Its
    found and missing lots are then kept, and its loose parts count
    towards it. "Closest to whole" lists the sets by how much is missing.
  - What do I need? uses only what is really there.
- **Bar** (`mysets_probe`, a stand-in Brickognize server for the photos,
  and the API test):
  - a box photo's set added in 3 actions;
  - 7140 marked with 12 parts missing: What do I need? for 7140 lists
    exactly those 12, and adding 5 of them as loose parts brings it to 7;
  - an older collection unchanged lot for lot;
  - `collection`, `mybricks` and `inventory` pass;
  - then 10 real box photos through the live API, counted as found
    (said, not gated).

**7. comparesets: what one set or model shares with another.**
- **Change.** Compare takes any two of a set, a saved model or the open
  model. It lists the parts in both and the parts in only one, by part and
  colour, and "to build B from A, buy these", which goes to the parts
  list's shops. Over MCP, `parts_list {"which": "compare", ...}`.
- **Bar** (`comparesets_probe`):
  - 7140 against 9493: counts in both and in each alone, adding up to
    each inventory's pieces exactly;
  - the car against 7140: the to-buy list a Pick a Brick file whose lines
    sum to it;
  - over MCP in 1 call;
  - `compare`, `inventory` and `picklist` pass.

**8 to 10** are in the table: localbricks, stepnames and mosaic2.

## The top ten, by value to a person building

1. **pullkept:** what is set in the booklet comes back after a save and
   an open. Measured: Pods.ldr's two pulls back on open; every test
   model's booklet lines byte for byte over open, save and open.
2. **timelinefit:** the timeline's Done and Instructions inside the
   window at 1280 x 720 with every panel open. Measured: 0 px past the
   edge at three sizes; Done answers a click.
3. **mcpsee3:** a session saves a view and picks out a part number first
   time. Measured: `save_view` back within 0.1° and 0.1 LDU; three
   spellings of "4070" pick out exactly the headlight bricks.
4. **weighsure:** one weight for one model, and one style of number.
   Measured: the same grams at every frame, and with no shapes loaded, on
   every model `tested_models` opens.
5. **booklook:** the designer's cover, header, footer and piece styles.
   Measured: read back off the PNG and the PDF; the default booklet
   unchanged to the pixel.
6. **mysets:** a set added by its photo, and kept with its missing parts.
   Measured: 3 actions; What do I need? lists exactly the 12 missing.
7. **comparesets:** any two sets or models compared, and the parts to
   buy. Measured: 7140 against 9493, adding up to each inventory exactly.
8. **localbricks:** a collection without an account, joined to the
   account at sign-in with nothing lost. Measured: 12 lots and 2 sets kept
   over a restart, and the sum after sign-in.
9. **stepnames:** a step's name in the timeline, Build it and the
   booklet. Measured: shown in all three, and kept byte for byte.
10. **mosaic2:** a mosaic cropped and coloured the person's way, with
    fewer parts. Measured: 0 cells from outside the crop; 30% fewer parts.

Above all ten, and not planned here: the web's first visit (A13), on the
lead's web-start work. Its new number is that a warm visit compiles for
2.8 s, as a cold one does. Also above them: lights, playweb, animals,
keeptext4 and intomodel3, all in flight.

**Next, once those land:**
- video2, drive, watchfile, words6, makepart2, realjoints3, modsteps,
  print3mf, edges, panelside, palettes, twist and mechdet: ranked 11 to 23
  above.
- Not ranked:
  - the model so far as a page (LPub3D);
  - sub-models flattened, a selection moved into a new sub-model, and
    each exported (StudWorx);
  - pictures of a range of steps at a ratio;
  - a Hide tool's count;
  - a ground that follows the lowest part;
  - the step's parts in a pile photo (Brickit), which needs a detector
    trained on piles;
  - SOCIAL's mail and More like's why;
  - from round five, carried: an exploded view's spread, four viewports,
    a wanted list as a counted bin, a reverse booklet, Orthanc's three, a
    part from an OBJ with its connectors, an originality score, vector
    booklets, STEP import, and gamepads.
- **Parked, needing the owner:**
  - bricklink (BrickLink's keys and terms; a mosaic's price waits on
    it);
  - studioside (Studio's install);
  - 3Dconnexion (the device);
  - the Mac's thumbnails (the Developer ID);
  - payments and live prices;
  - the Claude directory's submission;
  - tests on other AIs.

  None is ranked above.
- **Out on purpose:**
  - a collision switch;
  - more languages;
  - a second look for the app, until the owner asks;
  - the LEGO logo on studs ([TRADEMARKS.md](TRADEMARKS.md), 3).

## Sources

Brickworks' own figures are from the runs above, in
`bench/results/appux6-2026-11-07/`:
- `walk/`: the walk's logs and its 154 pictures;
- `probes/`: the probes' logs;
- `web/`: the web's runs;
- `mcp/`: the MCP sessions' streams and the app's own files;
- `sources/`: the field's pages as read today.

The MCP walk's prompts and calls are in
[app_ux6/mcp_walk/](app_ux6/mcp_walk/). rel-m271's preview flows are in
`bench/results/release-out/rel-m271_pv_*.log`.

The field's sources, beyond APP_UX2's to APP_UX5's:
- Studio, Custom palette: <https://studiohelp.bricklink.com/hc/en-us/articles/5456164357527-Custom-palette>, <https://studiohelp.bricklink.com/hc/en-us/articles/5458323172887>
- Studio, Linked submodels: <https://studiohelp.bricklink.com/hc/en-us/articles/7124823329815-Linked-submodels>
- Studio, step descriptions: <https://studiohelp.bricklink.com/hc/en-us/articles/5626298196247>, <https://studiohelp.bricklink.com/hc/en-us/articles/7124207283351>
- Studio, piece styles and page locks: <https://studiohelp.bricklink.com/hc/en-us/articles/5627862550935>, <https://studiohelp.bricklink.com/hc/en-us/articles/5627816977815>, <https://studiohelp.bricklink.com/hc/en-us/articles/5627936266135>, <https://studiohelp.bricklink.com/hc/en-us/articles/5628095076759>
- Studio, Mosaic: <https://studiohelp.bricklink.com/hc/en-us/articles/5625025298327-Mosaic>
- Studio, Hide: <https://studiohelp.bricklink.com/hc/en-us/articles/5412918811287>; the ground: <https://studiohelp.bricklink.com/hc/en-us/articles/6481520864279>
- StudWorx features and release: <https://github.com/nathaneltitane/studworx/blob/main/FEATURES.md>, <https://github.com/nathaneltitane/studworx/releases>
- LPub3D release notes and site: <https://raw.githubusercontent.com/trevorsandy/lpub3d/master/mainApp/docs/RELEASE_NOTES.html>, <https://trevorsandy.github.io/lpub3d/>
- LeoCAD releases: <https://github.com/leozide/leocad/releases>
- Mecabricks' forum: <https://www.mecabricks.com/en/forum>
- BrickBack: <https://apps.apple.com/us/app/brickback-for-lego-sets/id6807854786>
- brick-tidy: <https://github.com/FrankAndreas/brick-tidy>
- the Brickognize API: <https://api.brickognize.com/openapi.json>
- Brickit: <https://apps.apple.com/us/app/brickit-app/id1477221636>
- Kinebrick Studio: <https://github.com/erik-larsen/kinebrick/commit/31084b1>
- ldraw-mecha: <https://github.com/anteloc/ldraw-mecha/tree/v0.5.0>, <https://news.ycombinator.com/item?id=50397325>
- Rebrickable's set compare: <https://web.archive.org/web/20260412143304/https://rebrickable.com/sets/compare/slow/>
- ldraw2print: <https://github.com/andrewimm/ldraw2print>
- EasyCraft VR: <https://forums.ldraw.org/printthread.php?tid=29689>
- Make it Walk: <https://arxiv.org/abs/2610.29505>
