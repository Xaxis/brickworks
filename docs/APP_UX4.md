# The app against the best tools, round four

Written 2026-11-05 by appux4 against `pre261` at `c48180cf`. The web was
measured on rel-m264 (`e0ed0018`), live then; rel-m265 went live from the
same `c48180cf` afterwards. [APP_UX.md](APP_UX.md), [APP_UX2.md](APP_UX2.md) and
[APP_UX3.md](APP_UX3.md) planned rounds one to three. Every unit of round
three is in `pre261` except bricklink and studioside, which wait on the
owner. Since then A10 (the bin and Properties get room), B5 (Like this),
Instructions that keep the castle's steps and desktop 0.17.0 have shipped
too. This file measures the app a fourth time, by hand and through a
person's own Claude, says where the field still does better, and plans
round four.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second.
[COMPETITIVE.md](COMPETITIVE.md) is the feature matrix and
[ROADMAP.md](ROADMAP.md) the designer's quality; neither is repeated.

## How it was made

- **The walk, a fourth time.** appux3's script and tasks, run on the GPU
  at 1280 x 720 and 1400 x 900 from a locked snapshot of this commit
  ([app_ux4/appux_walk.gd](app_ux4/appux_walk.gd)). One section was added
  after the old ones, so their numbers still compare: `round3`, Move to
  step by its key and a typed number, the step keys, Render's Building and
  the render queue, whether Best is path traced, the booklet page's extras,
  Settings' language, Cut away, Like this by two clicks, the first build's
  offer after building by hand, and the keys round three's "Next" named.
  Every picture it took (62 and 63) was looked at.
- **The same tasks over MCP,** as the owner's Claude does them
  ([app_ux4/mcp_walk/](app_ux4/mcp_walk/)):
  - the app in a window of its own with its MCP port open;
  - the walk's 30 words, and "1x4 brick", through `search_parts`;
  - then Claude Code on the subscription (`claude -p`, the Brickworks
    server alone, `--tools ""`, `--restricted`, no API key: the streams say
    `apiKeySource: none`), one turn a task. APP_UX3's 13 tasks in two
    sessions, then five tasks for what round three added, in the second.
    Calls are counted from the sessions' own streams.
- **Round three's bars,** read off each unit's probe run today from the
  same snapshot (`steps3`, `languages`, `booklet3`, `buildvideo`,
  `pathtrace`, `bigmodels2`, and `command` on Orthanc), and `mcphand` off
  today's release (rel-m264).
- **The web:** `load_check` on live brickworks.diy (rel-m264), broadband,
  two cold and two warm loads with a part picked from the bin.
- **The field,** from each tool's help pages, release notes, changelogs
  and commits as of 5 November 2026 (Sources). APP_UX2's and APP_UX3's
  lists and COMPETITIVE were read again; only what they did not cover is
  new here.
- **Not run:** Studio itself (studioside, the owner's), the in-app
  assistant on a key (it spends money), and claude.ai's connector.
- **The box was shared,** with one GPU slot (a reset on 11-05 took it down
  from two) and a load of 17 to 37 through these runs. Seconds are
  stretched by it; counts are not.

## What the walk measured, four times

| act | appux371 | appux2 | appux3 (1280 / 1400) | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|---|---|
| desktop start, the first 120 frames | 4.4 to 6.2 s | 5.0 s | 6.6 / 10.2 s | 8.6 s (load 19) | 6.3 s | walk |
| bin tiles in sight on the first open | 8 and 16 | 24 and 30 | 24 / 30 | 24, every one named | **42**, every one named (A10's bar 40) | walk `counts` |
| Properties with a part selected | | | | **every field in sight**; the bin gives way to it | **every field in sight, the bin beside it** | walk `turns` |
| keys sheet (F1), rows in sight | 1 | 32 and 46 of 96 | 32 / 46 of 123 | 32 of 128 | 46 of 128 | walk `counts` |
| commands with a key | 51 of 122 | 75 of 188 | 82 of 192 | **87 of 201** | the same | walk `counts` |
| Render from the model by keys | menus only | 5 presses | 5 | 5 | 5 | walk `counts` |
| the tallest menu, rows (height) | Edit 39 (689) | Build 37 (689) | Edit 24 (464) | Edit 24 (464); File 23, View 23, Build 21, Tools 21, Make 12, Help 6: none scrolls | the same | walk `menus` |
| the part menu | 13 rows | 23 | 25 | 26 (Move to step… is new) | 26 | walk `menus` |
| a wall of eight 1 x 4s from the search | 20 events, 2.7 s | 20, 2.0 s | 20, 2.6 / 3.8 s | 20, 2.4 s | 20, 3.2 s | walk `wall` |
| the ghost following the pointer, 3 frames a move | 32.8 ms, worst 44.7 | 27.5, worst 32.3 | 26.9, worst 31.0 / 51.6, worst 107.6 | 34.3, worst 58.8 (load 20 to 33) | 42.0, worst 52.9 | walk `wall` |
| R on a brick in a wall, 15° step | nothing | in hand, down in 3 | the same | in hand, down in 3, 15.0° | the same | walk `turns` |
| a brick alone, 3 x R at 15° | 45° | 45° | 45° | 45° | 45° | walk `dialogs` |
| panels and dialogs | 25 open, 0.8 to 1.6 s | 0.6 to 1.0 s | 22 of 24, 0.6 to 1.5 / 0.8 to 3.3 s | 22 of 24, 0.8 to 1.8 s; Compare and Pattern greyed (no save, nothing selected) | 22 of 24, 1.0 to 2.0 s | walk `dialogs` |
| search, 30 words | 25 | 27 | 27 | **27**: the same three not first; three more answered by LDraw's new numbers (below) | the same | walk `search` |
| "1x4 brick", the first eight tiles | | two springs among them | bricks only | bricks only | the same | walk `wall` |
| three selected parts painted Red | a click in the swatches | up to five presses and a C | 1 key | 1 key | 1 key | walk `round2` |
| a 2 x 4 plate split, and merged back | no | no | 1 key each | 1 key each | the same | walk `round2` |
| a second view | no | no | F8 at both | **greyed** with the assistant on: the model's column is under the 640 points two views need | F8: the second view 385 px wide | walk `round2` |
| a part to the last step | | | Shift+] a step at a time | **Alt+T, the number, Return**: step 14 to 15 in 4 key presses ([picture](app_ux4/move_to_step_1280x720.webp)) | the same | walk `round3` |
| step keys | | | earlier, later, merge, delete without | Alt+[, Alt+], Alt+E, Alt+Delete, Alt+T | the same | walk `round3` |
| Render | a picture, a turntable, motions | | the same | **and Building** ([picture](app_ux4/render_building_1280x720.webp)); Best is path traced on this card | the same | walk `round3` |
| Settings' language | English | | English | **English, Deutsch, Français, Español** ([picture](app_ux4/settings_language_1280x720.webp)) | the same | walk `round3` |
| Like this on a 2 x 4 brick | | | | **2 clicks**; 18 tiles in sight | 2 clicks; 16 tiles | walk `round3` |

The search's three that are not first are the walk's own answers, as
appux2 and appux3 found: "jumper" lists 3794b sixth after the newer 15573;
"macaroni" lists the macaroni tiles and bricks, where the walk wants a
quarter tile (25269 is fourteenth); "bracket" has 99781 fourth. Three more
now list a renumbered part first, which is the part a builder means:
"1x2 plate" 3023b, "round 1x1" 6141 (LDraw moved 4073 there), "minifig
head" 3626c.

**Found on the way:**
- **Like this is narrowed by words typed before it was chosen.** The wall
  was built from a search for "1x4 brick", whose words stay in the bin.
  A 2 x 4 brick clicked and Like this chosen then listed only bricks:
  twelve 2 x 4s, eight of them prints of one curved brick (4744p01 to
  4744p0s), each a tile of its own, and no 2 x 4 plate in the first twelve
  ([picture](app_ux4/like_this_after_a_search_1280x720.webp)). On an
  empty search, `likethis` puts the plate seventh. Its note says "Parts
  like Brick 2 x 4: its size and kind first" and nothing of the words.
  `_find` hands every shelf the search's words, Like this and Fits
  included (`parts_bin.gd`).
- **The first build's offer is still over the model** ("Seven short steps
  on a new baseplate… Start, Skip") after a person has built a wall of
  eight by hand, opened the car and 22 panels, at both sizes
  ([picture](app_ux4/gap_first_build_offer_lingers_1280x720.webp)). APP_UX3
  listed it under "Next".
- **The render queue stays up and on top.** Opened from File, it does not
  close with Escape, and it stands over what opens after it: over Cut
  away's X, Y, Z strip at both sizes
  ([picture](app_ux4/gap_cut_away_one_plane_1280x720.webp)) and, at
  1400 x 900, over Settings' foot, its Done button among it.
- **View, Split is greyed at 1280 x 720 with the assistant on.** appux3's
  walk, the same script in the same order, had F8 at both sizes. Now the
  columns beside the model leave it under `SplitView.least()`, two views
  of 320 points, so a laptop with the assistant open has no second view.
  At 1400 x 900 it is offered, 385 px a view.
- The walk's Godot still aborts at its quit at both sizes (exit 134, as in
  appux2's and appux3's runs), after every step and "WALK done".
- Instructions writes the booklet as a file; the window shows nothing of
  it, so the walk's picture of it is the model.

**The web** (`load_check`, broadband, live, load 18 to 20):

| | appux371 | appux2 (live rel-m222) | appux3 (live rel-m224) | now: live rel-m264 | from |
|---|---|---|---|---|---|
| first visit, cold, to working | 14.8 s | 16.2 s | 24.9 s | **13.1 s** (14.7 and 11.6) | `load_check` |
| warm | 8.1 s | 9.0 s | 12.0 s | **8.0 s** (9.1 and 6.9) | `load_check` |
| main thread, cold | 8.6 s | 9.6 s | 15.0 s | **7.4 s** | `load_check` |
| app ready (the scripts done), cold | | 11.7 s | 15.1 to 17.3 s | **7.8 to 9.0 s** | `load_check` |
| a part from the bin to its ghost, cold and warm | 533 to 628 ms | 629 and 1,156 ms | 2,064 and 1,695 ms | 1,572 and 278 ms cold, 214 and 219 warm | `load_check --pick` |
| bytes before working | | | 15.9 MB | 16.49 MB | `load_check` |

The columns were measured on different days at different loads, so only
large differences count, and these are large: the cold start is about half
what appux3 found, and the main thread before the app is ready halved.
Of a cold 13.1 s, the engine's banner is at 4.6 s (the bytes), the
scripts' compile 3.1 s, the catalogue 1.2 s, the interface 0.9 s and the
first frames 2.3 s. A13's bar (10 s cold, 4 s warm) is still not met; the
lead's `firstscreen`, `leaves` and `spinworker` units are on it now.

## Over MCP: the walk's tasks as the owner's Claude does them

**The search** answers a session exactly as the bin answers a person: the
same first part for all 31 words, in 5 to 129 ms a word.

**APP_UX3's thirteen tasks, again:**

| task | APP_UX3: calls, time | now: calls, time | what the session did |
|---|---|---|---|
| clear, and a red wall of eight 1 x 4s, half a brick along | 4, 12 s | **2**, 10 s | clear and `submit_design`; exact, and said the stepped ends |
| turn one brick of the top row 15° where it stands | 2, 12 s, refused | 1, 13 s, refused | tried it on a copy, said both reasons, offered three ways; changed nothing |
| paint three bottom bricks blue | 1, 4 s | 1, 4 s | chose which three and said so |
| a 2 x 4 plate, split into eight 1 x 1s | 2, 12 s, by arithmetic | 3, 9 s | **`split_parts`**, then a `view_model` to see it |
| three 1 x 4 plates stacked, merged into a brick | 2, 9 s, by arithmetic | 3, 7 s | **`merge_parts`**, then a look |
| a 3 x 6 wing, the left one, and its mirror image | 4, 17 s | 6, 19 s | **`mirror_parts`** swapped 54384 for 54383; a look, and an edit naming the pair |
| a beam 7 standing, a pin in its second hole | 7, 59 s | 9, 57 s | the beam tips, so it added two plates and a Technic brick it was not asked for, and said so |
| the angle between the beam's holes and the wall | 0, 1 s | 0, 2 s | 90°, right, from its own placing: "I didn't measure it". `measure` was there and not used |
| move the top row three steps later | 1, 8 s, refused | 3, 12 s | **`edit_steps {"op": "to"}`** in one call, between two lists; the fourth brick was already last |
| render a picture | 2, 11 s | 2, 8 s | written to the app's own folder, no longer the person's Downloads |
| a side pod of five parts, in words | 13, 64 s | **9**, 41 s | one `attachment_points` call for four parts; the plate turned the wrong way once, then right |
| the pod's mirror image beside it | 2, 16 s, by hand | 3, 12 s | **`mirror_parts`**: 41770a to 41769a, the rest in mirrored places |
| a 2 x 2 slope split into 1-wide slopes | 2, 14 s | 4, 10 s | **`split_parts`**: two 3040b on the same studs |

Thirteen tasks took **46 calls in 3.4 minutes** of the sessions' own time
(APP_UX3: 42 in 4.0 by the same count). Every hand tool round three added
was found and used unprompted, and each result is now exact by
construction, where APP_UX3's were worked out place by place. The four
calls more are looks: `split_parts`, `merge_parts` and `mirror_parts`
answer in words alone, where `edit_model` can answer with the change
pictured, so each was followed by a `view_model`. A submit_design or
edit_model reply no longer pushes the designer's seven steps at a CAD
request (APP_UX3's sixth point).

**Round three's own, in the second session** (the pods on the baseplate):

| task | calls, time | what the session did |
|---|---|---|
| a short video of the model built up | **2**, 46 s | `render_model {"kind": "build"}` and its job: 15 s, MP4 and WebP, four steps |
| parts like the headlight brick, three picked, nothing changed | **1**, 12 s | `search_parts {"like": "4070"}`; picked 87087, 26604 and 3062b, each with why |
| what step the window shows, and the part in hand | **1**, 3 s | `in_view`: no step showing, nothing in hand, nothing selected, no reference picture |
| the wing pulled out in the booklet, colour guides, and how the first page looks | 5, 11 s | `edit_booklet` pull and colours_all, `booklet_layout` read back; **"I haven't drawn or exported it, so I haven't seen the page itself"** |
| a picture at the best quality, and how it was lit | 2, 13 s | `render_model` Best with the product look; **"the app didn't say whether Best was path-traced… 4 seconds suggests averaged frames, but that's a guess"** |

Where a session still needed more than the window, or guessed:
1. **It cannot see a booklet page.** `booklet_layout` is numbers ("without
   drawing a picture"); the session described page 2 in millimetres and
   said it had not seen it. A person sees the page.
2. **It sees one view a call, and nothing picked out on asking.**
   `view_model` takes `from` and `where`. A check from three sides is three
   calls; a sub-assembly inside the model cannot be seen through its
   shell; the parts it means cannot be picked out unless it just changed
   them. The new agent tools in the field draw exactly these (below).
3. **The hand tools answer in words.** Three looks in thirteen tasks were
   only to see what `split_parts`, `merge_parts` and `mirror_parts` did.
4. **render_model does not say how Best was drawn,** where Render's
   dialog does (`RenderSettings.best_words`), so the session guessed.

## Round three, item by item

| unit | its bar | where it stands on `pre261` | proof |
|---|---|---|---|
| webstart | cold to working 40% less than live, warm 50% less; the app ready half of live's; the pick no slower; no more bytes (15.9 MB) | **cold met** against appux3's live (24.9 to 13.1 s, 47% less); **app ready met** (15.1 to 17.3 s, now 7.8 to 9.0); **pick met**; **warm missed** (12.0 to 8.0 s, 33% less); **bytes missed** by 0.6 MB (16.49). Measured on another day, not in the same hour | `load_check` on live, above |
| steps3 | step 3 to 17 in 2 actions or fewer; `edit_steps {"op": "to"}` in 1 call; a key for each step command | **met**, 35 checks, none failed: step 3 to 17 in **one drag** on the timeline's row, or **2 actions** by Alt+T and the number, one undo each; `edit_steps {"op": "to"}` in 1 call, a step not there refused with the range; Alt+[, Alt+], Alt+E and Alt+Delete each do what its menu row does; LDCad's Page Up and Down and Studio's Ctrl+A and D on the timeline | `steps3` today |
| mcphand | the car's half mirrored in 1 call as Shift+M; split and merge in 1 call; a hinge at 37° read as 37.0°; `in_view` changes nothing | **met**, every check; and used unprompted by the MCP walk's sessions | `mcphand` (rel-m264); MCP walk |
| bricklink | prices and a wanted list in 3 clicks | **parked**: BrickLink's keys and terms are the owner's | |
| buildvideo | the car's 61 parts in a 20 s WebP at 720p, each frame a prefix of the order; 3 actions; 1 call over MCP | **met**, 20 checks, none failed: the car's 61 parts in a 20 s WebP of 480 frames at 1280 x 720, every frame the first so many of the timeline's order, the last the whole model to 0.00 grey levels; 3 actions (Render, Building's 20 s, Return), 33 s; 1 call and its job over MCP, 35 s; written in the app's own folder, the model and its undo untouched | `buildvideo` today; MCP walk (2 calls) |
| booklet3 | a 4-long axle's 1:1 guide 32.0 mm within 0.2 mm in the PNG and PDF; a part pulled 2 studs out; a colour guide | **met**, 49 checks, none failed: the 4-long axle's 1:1 guide 32.09 mm on the 300 dpi PNG and 32.00 mm in the PDF, the beam's 56.0 mm within 0.2; the axle pulled 2 studs (40 LDU) along its own line, its arrow pointing back in; a step's colours, each once, on the page and in the PDF's words; the pod shown finished on its first page; each one undo, and kept over a save | `booklet3` today; MCP walk (5 calls) |
| bigmodels2 | on Orthanc: Instructions 15 s or less to the first page, suggest sections 3 s, stability 2 s, replace 1.0 s, hidden colours 2.0 s | **partly met**, at a load of 29 to 34 on 24 cores. **Met:** Instructions' first page of steps **8.3 s** (the bar 15; the whole booklet, 568 steps, 57 s); stability **0.75 s** (2; was 5.8), though 2.4 s the first time on a model just opened. **Just over:** suggest sections **3.09 s** (3; was 12.6), replace **1.09 s** (1.0; was 2.18). **Over:** hidden colours **2.65 s** (2.0; was 2.30). Each spends 80 to 570 ms of its own; the rest is the frames and workers it waits on. `bigmodels2`'s 18 checks and `command` passed; `instructions` and `booklet_pdf` were not run here | `bigmodels2`, `command` today |
| pathtrace | the car at 1280 x 720, 256 samples, 60 s or less; noise against 4,096 samples; soft shadows and bounced light; three queued renders | **met**, 20 checks, none failed: the car at 1280 x 720, 256 samples, path traced in **2.8 s** of its own on the RX 6700 XT (the bar 60 s); its noise against 4,096 samples 0.0084 (at most 0.02); a shadow that softens from 4.0 to 11.0 LDU; light off an orange floor on the car's underside at 3 of 3 points; three renders queued and made one after the other in 27.3 s, each its own view, while the window turned at a median 24 ms a frame | `pathtrace` today |
| languages | every menu row, tooltip and panel title in German, French and Spanish; German within the menus' bars; the choice kept | **met**, 104 checks, none failed: in German, French and Spanish every one of 217 menu rows, 135 menu tooltips, 37 toolbar tooltips, 19 panel titles, 437 panels' words and 1,248 dialogs' translated; the bin's first 48 tiles named in the language; German's menus within 25 rows and 60% of the height (Ansicht 482 of 783), the widest 353 px, the menu bar inside the window; Deutsch kept over a restart | `languages` today; walk `round3` |
| studioside | three .io files open in Studio | **parked**: Studio's Wine install is the owner's | |

**Built since round three's plan, beyond it:**
- **A10, room** (live rel-m264): 42 tiles in sight at 1400 x 900 against
  APP_UX's 40; every Properties field in sight at both sizes; at 1400 x 900
  the bin stays beside Properties and the assistant (walk).
- **B5, Like this** (live rel-m264): two clicks from a selected part to its
  list (walk), one call over MCP; narrowed by stale words, as above.
- Instructions that keep an author's steps when a sub-model is renamed,
  ungrouped or copied (unitsteps, stepsiblings).

**APP_UX3's "what the field does", checked against the app now:**

| claim | the app now |
|---|---|
| Studio's Move To and its step drag | **met**: Alt+T and a number, the menu on a part, a drag onto the step row; over MCP in one call |
| Studio's building video | **met**: Render, Building; `render_model {"kind": "build"}` |
| Studio's booklet extras (buffer exchange, 1:1 guide, colour guide, sub-model preview) | **met** (`booklet3`): in the Build menu with no key, and over MCP in 5 calls, whose session could not see the page it made |
| Studio's Eyesight; Mecabricks' render farm | **met for Eyesight** (`pathtrace`): path traced, with a queue; no farm, so a browser on a weak GPU still draws Best by averaged frames, and a session is not told which (above) |
| Mecabricks' eight languages, LeoCAD's six | four (English, German, French, Spanish), by choice |
| LDCad's step keys | **met**: Page Up and Down under its preset |
| ldraw-mcp's render of a candidate | partly: `check_design` answers a candidate in words |
| Studio's prices and wanted list upload | **parked** (bricklink) |
| Studio's four viewports | one second view, and none at 1280 x 720 with the assistant on |

## What the field does that Brickworks does not, yet

The latest versions, as of 5 November 2026:
- **Studio 2.26.10_1** (27 October), ten bug fixes; the help centre has no
  article newer than 25 September. bricklink.com itself was down for
  maintenance today.
- **LeoCAD 26.09** (20 September), and a continuous build today.
- **StudWorx**, new: a LeoCAD fork, its first release today.
- **LDCad 1.7 Beta 2b** (March) and **Bricksmith 3.1** (2022): nothing
  since.
- **Mecabricks** has no versions and announces nothing new.
- **Kinebrick Studio v0.2.0-beta.1** (2 November, download lines only),
  and **Kinebrick Play**, a web viewer of Technic sets that move.
- Phone apps: Brickit 5.8.0 (4 November), LEGO Builder 4.3.11
  (20 October), brckd 1.0: bug fixes only.

Each tool's list is ranked by how much a person building would feel it,
and was checked against `shell.gd`'s commands, `tools/mcp_tools.json` and
the files named.

**LeoCAD, continuous build since 26.09**
1. **Train tracks joined by a drag.** A dragged track snaps to a free
   matching end within 12 px, and the sleepers it needs come in the same
   undo. StudWorx adds Rotate Train Track: the piece turns to its next
   connection. Brickworks: the 9V and 6-wide tracks (74746, 74747, 53400,
   53401) have studs, tubes, holes and shafts in `catalogue.json` and no
   track end, so a curve after a straight is placed and turned by eye.
2. **Other model files in the parts bin.** A Files category lists the
   .ldr, .mpd and .dat files beside the project; one goes in as a
   reference in 2 actions. Brickworks: Import replaces the model
   (`model_bar.gd`'s `_import` asks first) and the library opens a set in
   a tab of its own, so a model into this one is open, select all, copy,
   switch, paste: about 5 actions, and a copy.
3. **Where the part goes, in the status bar, while it is placed.**
   Brickworks' status bar says the selection, not the hand's place.
4. **What's This:** a click on any control, or F1 on the one with the
   focus, says what it does. Brickworks: F1 is the keys sheet; commands
   have tooltips, most panels' controls not.
5. Smaller: panels docked side by side anywhere; with nothing selected the
   view turns about what is in sight; Traditional Chinese.

**StudWorx** (its FEATURES page)
1. **Cutaways by a box, a sphere or a cylinder,** the cut faces filled,
   pushed or pulled a plate at a time, saved with the model. Brickworks'
   Cut away is one plane along X, Y or Z
   ([picture](app_ux4/gap_cut_away_one_plane_1280x720.webp)).
2. **Model thumbnails in the file manager** (a KDE plugin and a desktop
   thumbnailer). Brickworks registers .ldr, .mpd and .io with the system
   and draws no thumbnail for them.
3. **BrickLink export's options:** condition, which wanted list, notify,
   and the upload page opened. Brickworks' XML (`shop_lists.gd`) writes
   the item, colour and quantity only.
4. Ten languages, and light and dark themes. Brickworks has four languages
   and one look; neither is planned here: more languages are outside the
   agreed scope, and the app's look changes when the owner asks.

**Kinebrick Play** (web)
1. **A link that opens with the mechanism running:** `autospin=PART,cw`
   and `rpm=`, as its README's model cards use. Brickworks' viewer plays
   what moves when it is dragged (`share_view.gd`); no link plays on
   opening.

**AI, MCP and web tools**
1. **Pictures an agent checks its work with.** ldraw-xray, made "for
   agents to inspect LDraw models" (LDraw Nova uses it): named parts edged
   in magenta with the rest ghosted, x-ray of a shell, a sub-model in its
   parent, a picture per step with its new parts marked, and labelled
   boards of several views in one PNG. Brickforge's `capture_model` gives
   six views in one PNG and Emmet has `render --highlight` (each
   *unverified*, from their READMEs as reported). Brickworks' `view_model`:
   one view a call, nothing picked out but what an edit just changed.
2. **A Pick a Brick list.** LEGO's Pick a Brick takes a CSV or JSON of
   `elementId` and `quantity`, up to 400 lines and 999 of each, into the
   cart in about 4 actions (US and Canada when New Elementary wrote it).
   Brick Basket (iOS and Android beta, 2 November) exports one
   (*unverified*: its thread refuses readers). Brickworks writes
   BrickLink's XML and Rebrickable's CSV, though `parts_list` already has
   the element ids.
3. **Part by part within a step:** BUF3D (Android, 2 November) shows the
   next part alone, highlighted, and counts each placed (*unverified*).
   Brickworks' Build it shows a whole step at a time (`build_mode.gd`).
4. Smaller: vector instructions (Brick Blueprint's SVG and PDF line art;
   Brickworks' PDF holds pictures); STEP files to bricks (mesh2brick;
   `import_mesh` has no .step); eight angles at 4K in one export
   (BrickMine3D, *unverified*); Emmet's models as code with sliders.

**Mecabricks, LDCad, Bricksmith, Studio:** nothing new since APP_UX3.
BricksChat's thread has been quiet since 23 October.

**Round three's own "Next, once those land",** where each stands:
- **Keys:** 114 of 201 commands have none (walk `counts`): the render
  queue, the booklet page's four extras, the reference picture, Simulate,
  Motions, Render and Instructions among them. The lead's `keys` unit is
  queued.
- **Pattern's grid** (LeoCAD's Array): Pattern still makes a row, a ring or
  a path (`PatternDialog.KINDS`), so a grid is two runs.
- **A part from an OBJ or STL with its connectors** (Studio's Part
  Designer): not built; Part maker reshapes a part.
- **An originality score** (BricksChat): not built.
- **The first build's offer** after building by hand: still shown (above).
- **3Dconnexion:** parked, the owner's device.
- **A collision switch:** out on purpose, as before.

## The gaps, by value to a person building

1. **The web's first visit,** still over A13's bar: 13.1 s cold and 8.0 s
   warm on live, against 10 and 4. Half what appux3 found; the lead's
   units are on it. Carried, not planned again here.
2. **A session sees less than a person does.** One view a call; nothing
   picked out or seen through on asking; no booklet page at all; the hand
   tools answer in words; render_model does not say how Best was drawn.
   The owner builds through their own Claude, and the field's new agent
   tools (ldraw-xray, Brickforge) are built around exactly these pictures.
3. **Like this and Fits keep a search's old words,** and Like this shows
   each print as a tile of its own: after building from "1x4 brick", a
   2 x 4 brick's Like this had no plate in its first twelve. Every person
   who searched first meets it; B5 shipped today.
4. **No model into this one.** A builder making a scene, a layout or a
   MOC from sub-models brings in a model they already made in about 5
   actions, as a copy; LeoCAD does it in 2, as a reference.
5. **Buying the parts goes through BrickLink alone,** and BrickLink is
   parked. LEGO's own Pick a Brick takes a list of element ids, which the
   parts list already has. StudWorx's wanted list carries condition and
   notify; Brickworks' does not.
6. **Train tracks are laid by eye.** Tracks have no ends to join, so an
   oval is sixteen curves turned and placed by hand. LeoCAD joins them in
   a drag; LEGO trains are one of the largest parts of the hobby.
7. **A grid of copies is two runs of Pattern** (LeoCAD's Array: one).
8. **Build it shows a whole step;** BUF3D shows the next part alone and
   counts them, which is how a child, or anyone at a busy step, builds.
9. **Cut away is one plane;** StudWorx cuts a box, a sphere or a cylinder
   with the cut filled, and keeps it with the model.
10. **The first build's offer lingers,** the render queue stays on top of
    what opens after it, and a laptop with the assistant open has lost its
    second view since round three.
11. **No What's This, and no place for the part in hand** in the status
    bar (LeoCAD).
12. Smaller: a link that plays a motion on opening (Kinebrick Play); model
    thumbnails in the file manager (StudWorx); 114 commands without a key
    (the lead's `keys`); vector booklets; STEP import; gamepads; an
    originality score; a part from an OBJ with its connectors.

## The units

Ten, ranked, each its own worktree off the next stage. No two own the same
file. These are registries, as `tools/suite/*.txt` is, and a unit adds its
own lines there, in a block of its own, and changes no one else's:
- `src/ui/shell.gd`'s `_define` and `MENUS`;
- `src/ui/keymap.gd`'s `PRESET_KEYS`;
- `src/net/app_tools.gd`'s `COMMANDS`, `WINDOW_ONLY`, `GUIDE`, its tool
  list and its dispatch;
- `tools/mcp_tools.json`, written by `mcp_sync_probe --write`;
- `docs-site/generated/menus.json`;
- `src/ui/language.gd`'s tables (every new word in German, French and
  Spanish, as the languages scope asks).

Every new probe goes on its own line in `tools/suite/*.txt`, and every
feature added gets its entry in `.claude/skills/verify/` in the same
commit. None of the ten needs the owner.

| # | unit | gap | size | risk | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|
| 1 | **seeing** | 2 | M | low | new `src/net/see_tools.gd` (its tools, called from `app_tools.gd`'s dispatch); `src/ai/model_shot.gd`; `src/render/booklet_png.gd`, which already draws every page as a PNG, for one page alone; `split_merge`'s and `mirror`'s replies in `app_tools.gd`, a block of its own; new `src/dev/seeing_probe.gd` | see below |
| 2 | **likewords** | 3 | S | low | `src/ui/parts_bin.gd`; new `src/dev/likewords_probe.gd` | see below |
| 3 | **intomodel** | 4 | M | medium | `src/ui/model_bar.gd`'s import; `src/ui/library_dialog.gd`; `src/parts/model_store.gd`'s open into a sub-model; new `src/dev/intomodel_probe.gd` | see below |
| 4 | **picklist** | 5 | S | low | `src/assembly/shop_lists.gd`; `src/ui/exports.gd`; `src/ui/inventory_panel.gd`'s buttons; new `src/dev/picklist_probe.gd` | see below |
| 5 | **tracks** | 6 | L | medium | new `tools/track_ends.py` and `assets/ldraw/track_ends.json` (read at class load, as `gears.json` is); new `src/assembly/track_snap.gd`, called from the builder's snap in a block of its own; new `src/dev/tracks_probe.gd` | see below |
| 6 | **grid** | 7 | S | low | `src/ui/pattern_dialog.gd`; `src/assembly/pattern.gd`; new `src/dev/grid_probe.gd` | Pattern's "In a grid": 2 x 2 bricks in 4 columns, 3 rows and 2 layers, every 3 studs and 3 bricks up, in **one dialog**: 24 parts, each at its place to the LDU, one undo; a grid that would collide is refused with where; `patterns` passes |
| 7 | **partbypart** | 8 | M | low | `src/ui/build_mode.gd`; new `src/dev/partbypart_probe.gd` | see below |
| 8 | **cutshapes** | 9 | M | medium | `src/ui/see_inside.gd` and its shader; new `src/dev/cutshapes_probe.gd` | see below |
| 9 | **quiet** | 10 | S | low | `src/ui/first_build.gd`; `src/ui/render_queue.gd`; `src/ui/split_view.gd`; new `src/dev/quiet_probe.gd` | the first build's offer gone once a person has put down 3 parts by hand, opened a model of theirs or the car, and still offered on a first empty baseplate; the render queue closes with Escape, and Settings, Cut away's strip and every dialog opened after it are drawn over it, at 1280 x 720 and 1400 x 900; at 1280 x 720 with the assistant open, View, Split shows two views of 320 points or more (the assistant folds to its tab while the split is on, or the split takes the bin's room; one choice, said in the menu's tooltip); `first_build`, `split`, `roomfit` pass |
| 10 | **whatsthis** | 11 | M | low | new `src/ui/whats_this.gd`; `src/ui/status_bar.gd`; new `src/dev/whatsthis_probe.gd` | see below |

**1. seeing: a session sees what a person sees.**
- **Change.**
  - `view_board`: up to six views (front, back, left, right, top, corner)
    drawn as one labelled picture in one call, each the view
    `view_model` gives alone;
  - `view_model`'s options in the new tool: `highlight=` parts edged in
    magenta with the rest ghosted (ldraw-xray), `xray=` parts drawn see-
    through, `step=` the model as built to a step, its new parts marked;
  - `booklet_page {"page": N}`: the page as Instructions draws it, as a
    picture, so a session that edits the booklet sees what it did;
  - `split_parts`, `merge_parts` and `mirror_parts` take `picture=` and
    answer with the change pictured, as `edit_model` does;
  - `render_model`'s answer says how Best was drawn, in Render's words.
  - Not `view_model` itself: it is in `assistant.gd`, design's.
- **Bar** (`seeing_probe`, the tools called as a session calls them):
  - six views of the car in **1 call**, one picture, each labelled and
    within a small difference of the same `view_model` view;
  - `highlight=` three parts: those parts' edges magenta, every other part
    drawn at 40% or less;
  - `xray=` the car's roof: the seats under it in the picture where they
    were hidden;
  - `step=3`: the model of steps 1 to 3, step 3's parts marked;
  - `booklet_page` page 2 of the car within a small difference of the
    PDF's page 2 at the same size;
  - `split_parts` with `picture=true` answers with a picture;
  - `render_model` Best says "path traced, N samples" where the card
    traces and "frames averaged" where it does not;
  - `mcp_sync`, `mcp`, `mcphand` pass;
  - then the MCP walk's 18 tasks (`docs/app_ux4/mcp_walk/`) rerun by a real
    session, its looks counted beside today's (said, not gated).
- **Done** (unit seeing, 2026-11-05; `seeing` red on `pre261`, where
  neither tool is served and `split_parts` takes no `picture=`; green at
  1280 x 720 and 1400 x 900, every check, the pictures in
  `bench/results/seeing-2026-11-05/`):
  - six views of the car in **1 call**, 0.8 s, one 1536 x 1092 picture,
    six labels, each view at most 0.0003 apart from `view_model`'s;
  - `highlight=` the headlight brick, a 1 x 1 and a mudguard: 100% of each
    one's edge magenta; the 21 other parts seen alone on the line of sight
    at 19% of their strength at most;
  - `xray=` the roof: the blue seat, 0 px in sight from the top without it,
    33,594 px with it, all in the seat's own colour;
  - `step=3`: steps 1 to 3's 15 parts, 0.0000 apart from them drawn alone;
    100% of step 3's six parts' edges magenta, none elsewhere;
  - `booklet_page` page 2 in 0.7 s, 0.0041 apart from the PDF's page 2
    drawn by poppler at 1399 x 1035; nothing changed by either tool;
  - `split_parts picture=true` answers with the whole model, the eight
    pieces edged; unasked, `merge_parts` answers with a close look;
    `picture=false` words alone;
  - Best: "Path traced, 256 samples" on the RX 6700 XT; "64 frames
    averaged", and why, with nothing behind the model or a card that
    cannot trace;
  - `mcp_sync`, `mcp`, `mcphand` pass, and `read_only`, `mcp_lean`,
    `mcp_walk3`, `booklet_pdf`, `booklet3`, `buildvideo`;
  - the MCP walk's 18 tasks again: **52 calls**, 57 before. Looks after
    a hand tool, **0** (4 before): each of the five split, merge and
    mirror calls answered with its picture. The pod checked from three
    sides in one `view_board`. The booklet task looked at pages 2 and 3
    with `booklet_page` and described them, where before it said it had
    not seen the page. The Best render said "path traced, 256 samples",
    where before it guessed.

**2. likewords: Like this is about the part, not the last search.**
- **Change.**
  - Choosing Like this or Fits starts from no words: the search keeps
    what was typed for All, and words typed while in Like this narrow it,
    said in its note ("parts like Brick 2 x 4, with 'curved'").
  - Like this folds prints under their part, as All does (bin2's bar).
- **Bar** (`likewords_probe`, at 1280 x 720 and 1400 x 900):
  - "1x4 brick" typed and a wall built from it; then a 2 x 4 brick clicked
    and Like this chosen: the 2 x 4 plate in the first 12, as on an empty
    search;
  - no two of the first 12 tiles the same mould, printed or not;
  - "curved" typed while in Like this: only curved parts like it, said;
  - Fits the same after a search;
  - `likethis`, `bin2` and `bin_fold` pass.

**3. intomodel: a model into this one.**
- **Change.**
  - File, Import, Into this model… (.ldr, .mpd, .io, .lxf): the model
    comes in hand as a sub-assembly with its own steps, put down by a
    click, one undo.
  - The library's "Put in this model" on a set or a community model,
    within what its licence allows.
  - `open_model {"into": true}` for a session.
- **Bar** (`intomodel_probe`):
  - a saved model into the car in **2 actions** (choose it, click to put
    it down) as one sub-assembly, every part at its place relative to the
    others to the LDU, its author's steps kept as the sub-assembly's;
  - one undo takes it all out;
  - over MCP in 1 call;
  - an .io with Studio-only parts comes in with them;
  - `unit_steps`, `steps_kept`, `io` and `given_file` pass.

**4. picklist: buying from LEGO, and a fuller BrickLink list.**
- **Change.**
  - File, Export, LEGO Pick a Brick list (.csv): `elementId` and
    `quantity`, split into files of 400; parts with no element id listed
    apart, by name, in the parts list and the file's note.
  - BrickLink's XML takes a condition (new, used or either), a wanted
    list's number and notify, from the parts list's BrickLink button.
  - `export_model {"format": "pickabrick"}` and the same options over MCP.
- **Bar** (`picklist_probe`):
  - the car's list: every lot with an element id, the quantities summing
    to its parts that have one, the rest named;
  - a 450-lot model in two files of 400 and 50;
  - the XML's CONDITION, WANTEDLISTID and NOTIFY as chosen, and
    each tag as BrickLink's wanted list help documents it (nothing
    uploaded: an upload is bricklink's, parked);
  - `inventory` passes.

**5. tracks: train tracks join end to end.**
- **Change.**
  - A table of track ends (position and direction of each end) for the
    9V, 12V, 4.5V, RC, 6-wide and roller coaster tracks, made from their
    geometry by `tools/track_ends.py`, as `gears.json` is.
  - A track in hand snaps to a free end of a track within 12 px of the
    pointer; R turns it to its next end (StudWorx); the sleepers a joint
    needs come with it, in the same undo.
  - `attach` over MCP by `track[0]` and `track[1]`.
- **Bar** (`tracks_probe`):
  - a 9V curve brought near a straight's free end joins it in **1 drag**:
    ends within 0.5 LDU, directions within 0.1°;
  - sixteen curves laid by sixteen clicks close a circle within 1 LDU;
  - R on a curve in hand puts its other end to the joint;
  - an oval of 16 curves and 4 straights by a session in 3 calls or fewer;
  - `snap`, `connect` and `attach` pass.

**6. grid: a grid of copies in one dialog.** Its Change and Bar are its row
above.
- **Done** (grid, 2026-11-05; `grid_probe`, red on pre261, which has no In a
  grid (only In a row, Round and Along a hose, so a 4 x 3 x 2 block was a
  row, that row copied, then that layer copied up), green with 29 checks at
  1280 x 720 and at 1400 x 900):
  1. Pattern's **In a grid**: one 2 x 2 brick, a click, Ctrl+Shift+D, In a
     grid, then 4 columns, 3 rows and 2 levels, every 3 studs, 3 studs and
     9 plates, typed with Tab between them, and Enter: 15 actions in **one
     dialog**, which says "23 copies · 4 columns 3 studs apart · 3 rows 3
     studs apart · 2 levels 3 bricks apart · each has room" and draws the
     copies before anything is put down;
  2. **24 parts**, each within 0.01 LDU of its place (60 LDU a column and
     a row, 72 a level), square to the grid, none in another's room;
  3. **one undo**: one step; one Ctrl+Z takes the 23 copies back, and redo
     puts each back at its place;
  4. a 1 x 4 brick where column 3, row 2, level 1 would go is **refused with
     where**: "the copy in column 3, row 2, level 1 has no room: Brick 1 x 4
     is in the way", drawn red, Put them down greyed, and Enter puts nothing
     down;
  5. **`patterns` passes** (229 checks), and so does the dialog's own
     `handbuild_probe -- only=patterns` (27: the fence, `/4`, the ring and
     the hose). The dialog's words are in German, French and Spanish, and
     it opens inside the window in each; `languages` (104), `tooltip_fit`
     and `typed_moves` (75) pass.
  6. **The same grid over MCP**, as the owner's Claude lays it: the new
     `pattern_parts` tool (columns, rows and levels, `column_studs`,
     `row_studs` and `level_plates`, each spacing the parts' own size when
     not given) runs the same `Pattern.grid`, room check and undo step as the
     dialog. In `grid_probe`, the same 4 x 3 x 2 is **1 call**: 24 bricks,
     each within 0.01 LDU of its place, none in another's room. It is **one
     undo**: the session's `undo`, called once, takes all 23 copies back.
     With the 1 x 4 brick in the way it is **refused with where**: "the copy
     in column 3, row 2, level 1 has no room: Brick 1 x 4 is in the way
     (#26). Nothing changed", and no step is added. Left to their own size,
     2 x 2 bricks lay touching (40 LDU, 24 LDU). The person's selection is
     left as it was. 40 checks at 1280 x 720 and at 1400 x 900; `mcp_sync`,
     `mcp` (75), `mcp_lean` (27) and `patterns` (229) pass. The window's
     default level spacing now rounds a 2 x 2 brick's 28 LDU height down to
     3 plates rather than up to 4, so a level, or a row going up, touches
     the one below.

**7. partbypart: Build it a part at a time.**
- **Change.** Build it, a part at a time: the next part alone highlighted
  and the rest of the step faded, "3 of 8 in this step", Next and Back by
  a tap or a swipe as now; the step at a time kept as a choice.
- **Bar** (`partbypart_probe`, on a phone's 390 x 844 and a tablet):
  - a step of five parts is five taps, each showing exactly one new part
    in full colour and its count;
  - Back undoes one part; the last part's Next goes to the next step;
  - the targets 44 points or more; `viewer_steps` and `step_link` pass.

**8. cutshapes: a box, a sphere or a cylinder cut away.**
- **Change.** Cut away by a box, a sphere or a cylinder, with handles,
  pushed or pulled a plate at a time, the cut faces filled in the part's
  colour, kept with the model; the plane as now.
- **Bar** (`cutshapes_probe`):
  - a box through the car's cab shows the seats: pixels inside the box's
    outline change, outside unchanged;
  - no inside face of a part drawn in the cut (a cap colour or what is
    behind, never a back face);
  - the cut kept over a save and an open; Render and the booklet draw the
    model whole;
  - check.sh's "see inside" (`see_inside_probe`), `command` and `outline`
    pass.

**10. whatsthis: what any control does, and where the part goes.**
- **Change.** Help, What's This (Shift+F1): the next click on any control
  says what it does instead of doing it; while a part is in hand, the
  status bar says where it would go, in studs and plates.
- **Bar** (`whatsthis_probe`):
  - every toolbar button, bin chip, Properties field and panel button
    answers with words, none empty, none the same as another's;
  - the click does nothing else;
  - while carrying, the status bar's x, z and height are where the part
    then lands, to the stud and plate.

**Next, once those land:**
- **Keys** for the 114: the lead's `keys` unit.
- **Orthanc's three:** suggest sections, replace and hidden colours, 0.09,
  0.09 and 0.65 s over their bars at a load of 34; measured again at a
  quiet hour first, and a small unit only if they stay over.
- **A link that plays a motion** on opening (Kinebrick Play):
  `?motion=NAME` on a share link.
- **Thumbnails in the file manager** for .ldr, .mpd and .io (StudWorx):
  Linux and Windows first; the Mac's Quick Look extension may need the
  Developer ID the owner holds.
- **A part from an OBJ or STL with its connectors** (Studio's Part
  Designer); **an originality score** (BricksChat); vector booklets; STEP
  import; gamepads.
- **Parked, needing the owner:** bricklink (BrickLink's keys and terms),
  studioside (Studio's install), 3Dconnexion (the device), and the Mac's
  thumbnails if they need the Developer ID. None is ranked above.
- **Out on purpose:** a collision switch; more languages; a second look
  for the app, until the owner asks.

## The top ten, by value to a person building

1. **seeing:** a session sees boards of views, parts picked out, a booklet
   page, and its own hand tools' results.
2. **likewords:** Like this and Fits about the part, not the last search.
3. **intomodel:** a model into this one in 2 actions.
4. **picklist:** a LEGO Pick a Brick list, and BrickLink's options.
5. **tracks:** train tracks join end to end in a drag.
6. **grid:** Pattern's grid in one dialog.
7. **partbypart:** Build it a part at a time.
8. **cutshapes:** a box, a sphere or a cylinder cut away.
9. **quiet:** the first build's offer goes; the render queue gives way;
   the second view back on a laptop with the assistant open.
10. **whatsthis:** What's This, and the hand's place in the status bar.

Above all ten, and not planned here: the web's first visit (A13), which
the lead's units are on.

## Sources

Brickworks' own figures are from the runs above: the walk's logs and
pictures and the MCP sessions' streams, in
`bench/results/appux4-2026-11-05/` (`walk/`, `mcp/`, `web/`, `probes/`),
the MCP walk's prompts and calls ([app_ux4/mcp_walk/](app_ux4/mcp_walk/)),
and `bench/results/release-out/rel-m264_probe_mcphand.log`. The field's,
beyond APP_UX2's and APP_UX3's Sources:
- Studio 2.26.10_1's notes: <https://github.com/microsoft/winget-pkgs/pull/463222>
- Studio's help centre, newest articles: <https://studiohelp.bricklink.com/api/v2/help_center/en-us/articles.json?sort_by=created_at&sort_order=desc>
- LeoCAD releases and continuous build: <https://github.com/leozide/leocad/releases>
- LeoCAD, train tracks snapped by their ends: <https://github.com/leozide/leocad/commit/b44c2b7>, <https://github.com/leozide/leocad/commit/ffcd885>
- LeoCAD, project files in the parts bin: <https://github.com/leozide/leocad/commit/9d85108>
- LeoCAD, the place in the status bar: <https://github.com/leozide/leocad/commit/359824a>
- LeoCAD, What's This: <https://github.com/leozide/leocad/commit/7829c6f>
- StudWorx features and first release: <https://github.com/nathaneltitane/studworx/blob/main/FEATURES.md>, <https://github.com/nathaneltitane/studworx/releases>
- LDCad: <http://www.melkert.net/LDCad/download>
- Bricksmith: <https://bricksmith.sourceforge.io/VersionHistory.html>
- Kinebrick Studio: <https://github.com/fhareide/kinebrick-studio-releases/releases>
- Kinebrick Play, its URL parameters: <https://github.com/erik-larsen/kinebrick>
- ldraw-xray: <https://github.com/anteloc/ldraw-xray>
- Brickforge: <https://github.com/josemmc1992/brickforge>
- Emmet: <https://github.com/barrymortenson/emmet>
- Pick a Brick's list upload: <https://www.newelementary.com/2024/10/pick-brick-new-upload-feature-now-live.html>
- Brick Basket: <https://www.eurobricks.com/forum/forums/topic/214380-brick-basket-parts-finder-and-wanted-lists/>
- BUF3D: <https://www.eurobricks.com/forum/forums/topic/214372-software-buf3d-for-android-build-your-ldraw-and-ldd-models-step-by-step-on-your-phone/>
- Brick Blueprint: <https://github.com/ch3pasov/brick-blueprint>
- mesh2brick: <https://github.com/leckermatz79/mesh2brick>
- BrickMine3D: <https://www.eurobricks.com/forum/forums/topic/214314-brickmine3d-in-browser-3d-renderer-for-studio-io-and-ldraw-ldr-files-threejs-webgl/>
