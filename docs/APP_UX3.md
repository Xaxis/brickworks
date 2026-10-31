# The app against the best tools, round three

Written 2026-10-30 by appux3 against `stage225` at `9eab5c67`.
[APP_UX.md](APP_UX.md) (appux371) planned round one and
[APP_UX2.md](APP_UX2.md) (appux2) round two. Every unit of both is now in
`stage225` except studioside, which waits on the owner. This file measures
the app a third time, by hand and through a person's own Claude, says
where the field still does better, and plans round three.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second.
[COMPETITIVE.md](COMPETITIVE.md) is the feature matrix and is not repeated.
The AI designer's quality (the realset score) is design5's, not this
file's.

## How it was made

- **The walk, a third time.** appux2's script and tasks, run on the GPU at
  1280 x 720 and 1400 x 900 ([app_ux3/appux_walk.gd](app_ux3/appux_walk.gd)).
  Two sections were added, after the old ones so their numbers still
  compare:
  - `round2`: a favourite colour on three parts, Split and Merge by their
    keys, View › Split, the reference picture and the new panels;
  - `gaps`: the pictures of what this file plans.
- **The same tasks over MCP,** as the owner's Claude does them:
  - the app in a window of its own with its MCP port open;
  - the walk's 30 words, and "1x4 brick", through `search_parts`;
  - then a Claude Code session on the subscription (`claude -p`, the
    Brickworks server alone, `--tools ""`, `--restricted`, no API key in
    its environment), one turn a task, 13 tasks in two sessions. Calls are
    counted from the session's own stream.
- **Round two's bars,** read off the probes in the release logs
  (`bench/results/release-out/rel-m226_probe_*.log` and `rel-m227_*`, the
  release running from this same commit).
- **The web:**
  - `load_check` on broadband, two cold and two warm loads each, one after
    the other in the same hour: the live site (rel-m224, `26ad6c36`), the
    `stage225` preview (`442c00ef`, which holds webload) and rel-m222's
    deployment (`6b98fdd0`, the build appux2 timed this morning);
  - `fit_check` on this commit's own export, served here.
- **The field,** from each tool's help pages, release notes and changelogs
  as of 30 October 2026 (Sources). APP_UX2's list was read again and only
  what it did not cover is new here.
- **Not run:** Studio itself (Wine needs the box's password), the in-app
  assistant (it spends money), and claude.ai's connector. The MCP walk used
  the desktop's own relay to the same tools.
- **The box was shared.** The load was 7 to 43 through these runs. Seconds
  are stretched by it; counts are not.

## What the walk measured, three times

| act | appux371 | appux2 | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|---|
| desktop start, the first 120 frames | 4.4 to 6.2 s | 5.0 s | 6.6 s | 10.2 s (load 30) | walk |
| bin tiles in sight on the first open | 8 and 16 | 24 and 30 | **24**, every one named | **30**, every one named; the bar was 40 | walk `counts` |
| the bin with a part selected | folded | folded | **18 tiles, and the part's place, turn and colour under them** ([picture](app_ux3/turn_in_wall_down_1280x720.webp)) | the same | walk `turns`; `columns` (rel-m227) |
| keys sheet (F1), rows in sight | 1 | 32 and 46 of 96 | 32 of 123 | 46 of 123 | walk `counts` |
| commands with a key | 51 of 122 | 75 of 188 | **82 of 192** | the same | walk `counts` |
| Render from the model by keys | menus only | 5 presses | 5 | 5 | walk `counts` |
| the tallest menu, rows (height of 783) | Edit 39 (689) | Build 37 (689, scrolls) | **Edit 24 (464)**. File 22, View 23, Build 21, Make 12, Tools 21, Help 2: none scrolls | the same | walk `menus` |
| the part menu | 13 rows | 23 | 25 | 25 | walk `menus` |
| a wall of eight 1 x 4s from the search | 20 events, 2.7 s | 20, 2.0 s | 20, 2.6 s | 20, 3.8 s | walk `wall` |
| the ghost following the pointer, 3 frames a move | 32.8 ms, worst 44.7 | 27.5, worst 32.3 | 26.9, worst 31.0 | 51.6, worst 107.6 (load 30) | walk `wall` |
| R on a brick in a wall, 15° step | nothing | in hand, down in 3 | in hand, down in 3, 15.0° | the same | walk `turns` |
| a brick alone, 3 x R at 15° | 45° | 45° | 45° | 45° | walk `dialogs` |
| panels and dialogs | 25 open, 0.8 to 1.6 s | 0.6 to 1.0 s | 22 of 24 open, 0.6 to 1.5 s; Compare and Pattern greyed (no save, nothing selected) | 0.8 to 3.3 s | walk `dialogs` |
| search, 30 words | 25 | 27 | **27**; the same three not first (below) | the same | walk `search` |
| "1x4 brick", the first eight tiles | | two springs among them | **bricks only** | the same | walk `wall` |
| three selected parts painted Red | a click in the swatches | up to five presses and a C | **1 key** (Shift+5) | the same | walk `round2` |
| a 2 x 4 plate split, and merged back | no | no | **1 key each** (Alt+S, Alt+M) | the same | walk `round2` |
| a second view | no | no | **F8**: two views share the model's column | the same | walk `round2` |
| step keys | | | Shift+[ and ] move the selection a step; New step Shift+N; earlier, later, merge and delete have no key | the same | walk `round2` |

The search's three that are not first are the walk's own answers, as
appux2 found: "jumper" lists the newer 15573 first and 3794b sixth;
"macaroni" lists the macaroni tiles and bricks, where the walk wants a
quarter tile; "bracket" has 99781 fourth among four brackets.

**The web:**

| | appux371 | appux2 (live rel-m222, morning) | now: rel-m222 again | now: live rel-m224 | now: `stage225` preview | from |
|---|---|---|---|---|---|---|
| first visit, cold, to working | 14.8 s | 16.2 s | 27.3 s | 24.9 s | **22.5 s** | `load_check` |
| warm | 8.1 s | 9.0 s | 15.2 s | 12.0 s | 13.7 s | `load_check` |
| main thread, cold | 8.6 s | 9.6 s | 15.8 s | 15.0 s | **12.8 s** | `load_check` |
| app ready (the scripts done), cold | | 11.7 s | 16.4 to 18.4 s | 15.1 to 17.3 s | 13.0 to 14.6 s | `load_check` |
| a part from the bin to its ghost, cold and warm | 533 to 628 ms | 629 and 1,156 ms | 2,161 to 4,631 ms (one never came) | 2,064 and 1,695 ms | 2,981 and 1,918 ms | `load_check --pick` |

The three "now" columns were measured one after the other within the
hour, so they compare with each other and not with the morning's:
rel-m222's own build took 27.3 s this evening where it took 16.2 s this
morning. Between the three, `stage225` is the quickest cold, **4.8 s
sooner than rel-m222 and 2.4 s sooner than live**, so webload's gain is
real and nothing since has given it back. Warm, the three are within
noise of each other. Against A13's bar (10 s cold, 4 s warm) the start is
still more than twice too long on this box, and most of it is the main
thread before the app is ready.

**The web's fit** (`fit_check` on this worktree's own export, served
here, 13 sizes and densities, by hand and with the assistant): every check
passes ("the app fits the page at every size and density, the model
clear").

| | appux2 (live rel-m222) | now: `stage225` |
|---|---|---|
| 1280 x 720, by hand | every control; the model 60% of the width; up in 11 s | the same: every control, **60%** (72% with the assistant), up in **9 s** ([picture](app_ux3/web_1280x720.webp)) |
| 390 x 844 phone, 3x | every control; up in 14 s | every control, the model the whole width and 79% of the height (85% with the assistant), 14 targets none under 44 points, up in **12 s** |
| 844 x 390, the phone on its side | **2 checks failed**: no assistant in Settings, the key strip over the model | **all pass**: the model 54% of the height by hand, 67% with the assistant, the strip clear of it ([picture](app_ux3/web_phone_844x390.webp)) |

The phone unit's fix holds. The 1280 x 720 page still opens with the
first build's offer and "Show the assistant" over the top of the model
(the 72 px they take is inside the 60%).

**Found on the way, not part of any bar:**
- The walk's Godot still aborts at its quit ("corrupted size vs.
  prev_size in fastbins", exit 134), at both sizes, after opening the
  panels, as in appux2's runs. Its data folders are kept in
  `/tmp/probe-data.appux_walk.*`.
- The first build's offer ("Seven short steps on a new baseplate… Start,
  Skip") is still over the model's corner after a person has built a wall
  by hand, opened the car and 22 panels
  ([picture](app_ux3/split_view_first_build_offer_1280x720.webp)).
- At 1280 x 720 with the assistant on, View › Split leaves each view
  about 460 px wide, and a panel opened from the menus (Stress) stands over
  the main one (the same picture).
- A render a session asks for is written to the person's real Downloads
  folder, as Export's are. The MCP walk's was moved out again.

## Over MCP: the walk's tasks as the owner's Claude does them

**The search** answers a session exactly as the bin answers a person: the
same first part for all 31 words, in 6 to 95 ms a word. A session hears
the same three misses, and "1x4 brick" gives bricks only.

**The tasks,** each a turn of its own, in the order a person would ask:

| task | the window | over MCP: calls, time | what the session did |
|---|---|---|---|
| clear, and a red wall of eight 1 x 4s, half a brick along | 20 events | **4** (clear, search, submit, look), 12 s | exact |
| turn one brick of the top row 15° where it stands | R, aim, click: it comes up in hand and goes down elsewhere | **2**, 12 s: refused on a copy | explained both reasons (it hits its neighbours, and a turned brick holds nothing) and offered three ways; changed nothing |
| paint three bottom bricks blue | three clicks and a key | **1**, 4 s | chose which three and said so |
| a 2 x 4 plate, split into eight 1 x 1s on the same studs | a part from the bin, Alt+S | **2**, 12 s | worked out eight places itself; exact |
| three 1 x 4 plates stacked, merged into a 1 x 4 brick | three parts, select, Alt+M | **2**, 9 s | exact |
| a 3 x 6 wing, the left one, and its mirror image | the part, then select, copy, Shift+M | **4**, 17 s | found 54383 and 54384 by search; exact |
| a beam 7 standing, a pin in its second hole | Connect: 6 actions a part | **7**, 59 s | the first `attach` was refused (6558 has two pins, "say which with by"); the beam then tipped over, so it added a Technic brick foot and a pin it was not asked for |
| the angle between the beam's holes and the wall | Measure: two clicks on the holes | **0**, 1 s | **answered from its own reckoning** (90°): no tool measures an angle |
| move the top row three steps later | three presses of Shift+] | **1**, 8 s, refused | listed the steps: there is no step 9 to move to |
| render a picture | Render…, Return | **2** (render, job), 11 s | |
| a side pod of five parts, as described in words | from the bin, by hand | **13**, 64 s | five `attachment_points` calls to find places; its first `submit_design` guessed the 4 x 6 plate's number and was refused as floating |
| the pod's mirror image beside it, left and right parts swapped | select, copy, Shift+M, place | **2**, 16 s | swapped 41770a for 41769a, moved the rest; exact to the stud |
| a 2 x 2 slope split into 1-wide slopes | Alt+S | **2**, 14 s | two 3040b on the same studs; exact |

Thirteen tasks took **42 calls in 6 minutes**. Everything a part can do,
the session did, and it never changed the model when it refused. Where it
needed more than the window, or guessed:
1. **No measure.** An angle or a distance between two connectors is the
   session's own arithmetic. Measure's angle (handles2) is the window's
   alone. A hinge left at 37°, or a linkage, has no tool to read it back.
2. **Mirror, Split and Merge are the window's alone**
   ([`WINDOW_ONLY`](../src/net/app_tools.gd)). A session lays the result
   itself. On five parts it was exact; on a sub-assembly of forty, with
   left and right wedges, hinges and slopes turned every way, it is forty
   places worked out by hand. The window's Shift+M does it in one key, and
   Split knows Studio's rules (a slope into 1-wide slopes, a 1 x 1 brick
   into three plates).
3. **Steps move one at a time.** `edit_steps` has next and prev, as the
   window's Shift+[ and ] do. Moving parts from step 3 to step 17 is 14
   calls, or 14 presses (Studio: one drag).
4. **Places are found by asking.** Five parts took five
   `attachment_points` calls before the first `submit_design`, and that
   one still missed (a part number guessed). The window places a part
   where the pointer is, by its studs.
5. **What the person sees, the session does not:**
   - the reference picture a person laid on the floor
     (`WINDOW_ONLY`: "a session is given pictures in the conversation");
   - the step the timeline is at;
   - the part in the person's hand.
6. **Every `submit_design` answer pushes the designer's seven steps**
   ("review_model with no assembly… each feature… the surface pass"),
   even for a five-part side pod a person asked for by part. The session
   rightly ignored it here. A session doing a person's CAD work hears a
   designer's method in every reply.

## Round two, item by item

| unit | its bar | where it stands on `stage225` | proof |
|---|---|---|---|
| pace | 12 actions a part or fewer from the set's bin, every part exact | **met**: 8841-1 at **6.76** and 5762-1 at **6.36** actions a part, 25 of 25 exact each; Studio's modelled figure is 11.8 to 14.1 | `setwalk` (rel-m226) |
| bin2 | Sand Green filter 0 wrong of 24; prints hidden in one click; double-click replace and fit; a list of 20 rows; "1x4 brick" bricks only | **met**: 0 wrong of 24; 349 printed tiles folded in one click; 22 rows; the bricks only (walk) | `bin2`, `bin_fold` (rel-m226); walk `wall` |
| keys3 | a colour on three parts in 1 key; the selection modes on keys; every menu 25 rows or fewer and 60% of the height | **met**: 1 key; Alt+C, Alt+P, Alt+J, Alt+I; the tallest menu Edit, 24 rows, 464 of 783 (59%) | walk `round2`, `menus`; `keys`, `palette` (rel-m227) |
| bigmodels | on Orthanc's 10,105 parts select joined, duplicate, paste and replace 1.0 s or less; hidden colours 2 s or less | **met for three**: select joined 0.40 s, duplicate 0.85 s, paste 1.43 s (its own work 0.71 s). **Replace 2.18 s** (own 1.35 s) and **hidden colours 2.30 s** (own 0.61 s) are over | `command` (rel-m227) |
| refimage | added in 4 actions; typed width; 40%; locked click-through; saved; absent from renders | **met**: 4 actions, laid 16 studs wide on the floor, kept for the next save. No key, and no tool for a session | `refimage` (rel-m226) |
| splitmerge | a 2 x 4 plate to eight 1 x 1s in 1 key; three plates to a brick in 1; a 2 x 3 merge; a merge with no real part refused | **met**: each in 1 key, on the same studs to the LDU, one undo | `splitmerge` (rel-m226); walk `round2` |
| handles2 | a pane move in 2; a turn about the view in 2; Measure's angle to 0.1° | **met**: x-z pane 3 by -2 studs in 2 actions; the outer ring; the angle | `handles2` (rel-m226) |
| pages2 | a picture turned 30°, text at 50%, an arrow bent, a box onto a guide, in the PDF and PNG | **met**, and pages3 added a callout's steps posed apart and `edit_booklet`'s layout for a session | `booklet_edit` (rel-m226); preview `booklet_edit` flow |
| motion | an arm meeting a wall within 2°; a four-bar's range within 1°; a motor that stalls says so | **met** (merge `9ea1c71e`) | `motion` |
| studioside | three .io files open in Studio; Studio's own actions a part | **not done**: waits on the owner (Wine needs sudo) | |

Also built since APP_UX2 was written: a second view (split, F8), springs
and rubber bands laid in 3 or 4 clicks (`springs`), the phone's layout on
its side, an axle slid through its hole to the pointer (snap2), Build
together that never loses a change at a tab's close (closesend), and a
first visit two seconds sooner (webload, below).

**Big models, again** (Orthanc, 10,105 parts, `command`, rel-m227):

| command | appux371 | appux2 | now |
|---|---|---|---|
| select joined | 6.1 s | 7.5 s | **0.40 s** |
| paste all | 3.1 s | 5.0 s | **1.43 s** |
| duplicate all | 3.2 s | 4.4 s | **0.85 s** |
| replace | | 2.4 s | 2.18 s |
| hidden colours | | 16.7 s | **2.30 s** |
| suggest sections | | 12.3 s | 12.6 s |
| stability | | 4.4 s | 5.8 s |
| split, merge, mirror of all | | | 5.6, 4.6 and 4.4 s |
| Instructions | 28.9 s | 31.4 s | **50.7 s** |

Each says so before it holds the window. Instructions on Orthanc now takes
50.7 s, against 28.9 s in appux371's run; the release's box was shared, so
part of it may be load, but the rise is larger than load explains.

**APP_UX2's "what the best tool does", checked against the app now:**

| claim | the app now |
|---|---|
| Studio's Split and Merge | **beaten**: one key each, and Merge goes as far as it can in one go, only into parts made in that colour |
| Studio's reference image (eight handles, typed size, opacity, lock, a step row) | **met** in the window; a session cannot see it |
| Studio's colour keys (ten favourites, ten of the model's) | **met**: Shift and Ctrl+Shift with the digits |
| Studio's "Hide Unavailable Parts in the Selected Color", prints hidden | **met** |
| Studio's Replace on suggestions in 2 clicks | **met**: a double-click on a Fits tile |
| Studio's selection modes on Shift+V | **met** under the Studio preset; keys of their own in the app's |
| Studio's page objects turned, faded, arrows bent | **met** (pages2) |
| Mecabricks' two-axis panes; LeoCAD's trackball | **met** (handles2) |
| LDCad's angle between pins | **met** in the window, not over MCP |
| LDCad's springs on paths | **met** (springs) |
| LDCad's double-click to replace; Bricksmith's Insert Related | **met** (bin2) |
| Kinebrick's interference, range and stall | **met** (motion) |
| Studio's four viewports | **partly**: one second view |
| LDCad's step keys, Page Up and Down | **not**: Page Up and Down still move the selection a plate |
| LDCad's grid relative to the selection; Bricksmith's change origin and colour randomiser | **not** |
| 3Dconnexion; eight interface languages (Mecabricks), six (LeoCAD) | **not**: English only |

## What the field does that Brickworks does not, yet

The latest versions, as of 30 October 2026, are unchanged since this
morning: Studio 2.26.10_1 (27 October), LeoCAD 26.09 (and a continuous
build on 30 October), LDCad 1.7 Beta 2b (March), Bricksmith 3.1 (2022),
Kinebrick Studio v0.1.0-beta.1 (29 October). Mecabricks has no versions;
a German article from March says VR and AI build suggestions are in
testing (*unverified*).

New since September, beyond those APP_UX2 named:
- **LDraw Nova** (Show HN, 2 October): an agent's command line that writes
  Python to make LDraw, renders through LeoCAD, exports glTF and a Quest 3
  view, and built a 2,175-part model with Claude. It does not check
  collision, strength, motion or colour availability, which Brickworks
  does. No MCP server.
- **ldraw-mcp** (PyPI 0.2.3): six tools, among them rendering any LDraw
  text to a picture without placing it, and a bill of materials.
- **brckd** (iOS): photos of a real build to a 3D model, GLB out, AR on paid
  tiers. Not LDraw.
- **bricks-mcp**, **lego-oracle**: Rebrickable data over MCP, which
  `parts_list` and `gallery library=` cover.

Each tool's list is ranked by how much a person building would feel it.
Each was checked against Brickworks' commands (`shell.gd`'s `_define`),
its MCP tools and the files named.

**BrickLink Studio**
1. **Prices.** The status bar prices the selection; the colour palette
   marks each colour $, $$ or $$$ (under 0.40, under 1.60, over 1.60 USD)
   and hovering prices the selection in it; Model Info prices every part,
   from the current average or the last six months'. Brickworks shows no
   price anywhere: `collection.gd` links parts to BrickLink "rather than
   priced", because BrickLink's prices are behind its API's sign-up and
   terms ([the parts list](app_ux3/gap_parts_list_no_price_1280x720.webp)).
   Neither a person nor their Claude can build to a budget.
2. **Any step in one action.** The selection dragged in the step list (1
   drag), or Move To on the right-click (2 clicks); Ctrl+A and Ctrl+D a
   step each. Brickworks: Shift+[ or ] a step at a time, so step 3 to step
   17 is 14 presses ([picture](app_ux3/gap_steps_timeline_1280x720.webp)).
   Step earlier, later, merge and delete have no key.
3. **A wanted list into BrickLink in 3 clicks** (Add to Wanted List,
   Proceed, Add), one sub-model alone from Model Info. Brickworks writes the
   .xml; the upload is the person's (about 8 actions, not measured).
4. **A building video**: Studio's Animation renders the model built up,
   fast-forward, as well as turntables. Brickworks renders a picture, a
   turntable and motions ([picture](app_ux3/gap_render_kinds_1280x720.webp));
   the timeline plays the build but cannot be rendered.
5. **The booklet's extras:**
   - parts shown pulled out, with the way they go in (buffer exchange);
   - a 1:1 guide, for Technic axles and beams;
   - a colour guide for each step;
   - a sub-model's preview before it is built.

   None is in `booklet*.gd` ([a page today](app_ux3/gap_booklet_page_1280x800.webp),
   from pages3's `booklet_edit` run on set 30050-1).
6. **Eyesight, a path tracer,** at 128 to 512 samples or any, on an NVIDIA
   GPU; a render queue; stud logos, yellowing and scratches as material
   effects; named presets. Brickworks: Quick, Good and Best (jittered frames
   averaged), three HDRIs, no queue.
7. **A part from a 3D file** (Part Designer imports .obj, .dat or .ldr, with
   a decal tool). Brickworks' Part maker reshapes an existing part.
8. **Collision off** (a switch; colliding parts drawn as wireframe). Left
   out on purpose, as in APP_UX2: exact collision is a lead.

**Mecabricks**
1. **A render farm**: the model packed into a .blend and rendered on their
   machines (Brickset, *unverified*). A path-traced picture with no GPU of
   one's own, which a browser cannot make.
2. Touch screens and eight languages (APP_UX2). The phone layout is built;
   the languages are not.

**LDCad 1.7**
1. **The model's LDraw text beside the view**, live. Low value by hand; a
   session has `edit_model`.
2. Step keys (APP_UX2), still not here.

**LeoCAD 26.09**
1. **Array** in one dialog (its history confirms the command; that it does
   2D and 3D grids at once is *unverified*). Brickworks' Pattern does a
   row, a ring or a path, so a grid is two runs.
2. Translations: six and more.

**Bricksmith 3.1:** nothing new.

**AI tools**
1. **BricksChat's originality score**: how much of a design is copied from
   real sets and MOCs, with a person able to push towards original
   (Eurobricks, *unverified*). Rebrickable refuses copied MOCs.
2. **ldraw-mcp's render of a candidate** without placing it. Brickworks'
   `check_design` tries a candidate on a copy and answers in words; only
   what is on the baseplate has a picture.

## The gaps, by value to a person building

1. **The web app's first visit is still more than twice its bar.**
   - On the same box in the same hour: `stage225` **22.5 s** cold and
     13.7 s warm to working; live rel-m224 24.9 s and 12.0 s; rel-m222
     27.3 s and 15.2 s. webload's gain is real; A13's bar (10 s cold, 4 s
     warm) is far off.
   - The time is the main thread: the app ready at 13.0 to 14.6 s, then
     the catalogue, interface and first frames another 6 to 8 s.
   - The same build measured 16.2 s this morning and 27.3 s this evening,
     so only a same-hour A/B against live says whether a change helped.
   - The owner opens brickworks.diy/app on a laptop; this is the first
     thing every visitor feels.
2. **Steps move one at a time,** by hand and over MCP. A booklet is one of
   Brickworks' strengths, and the step list is where its author lives:
   Studio moves a selection to any step in one drag.
3. **A session cannot measure, mirror, split or merge.** It did each of
   the walk's small cases by arithmetic, exactly, in 2 to 4 calls; it
   measured nothing, and a mirrored sub-assembly of forty parts is forty
   places by hand ([the part menu's Split and Merge, the window's
   alone](app_ux3/gap_part_menu_window_only_1280x720.webp)). Every
   `submit_design` reply pushes the designer's method at a person's CAD
   request. What the person sees (the reference picture, the step, the
   part in hand) the session does not.
4. **No prices, no wanted list upload.** A builder who means to buy the
   parts goes to BrickLink by hand. Studio prices everything and uploads in
   3 clicks. This needs BrickLink's API and its terms: the owner's.
5. **No building video.** Studio renders the model built up, fast. For a
   social site, a model page that builds itself is what people share.
6. **The booklet lacks Studio's extras:** buffer exchange, a 1:1 guide, a
   colour guide, a sub-model preview.
7. **Big models still wait** for Instructions (50.7 s on Orthanc, up from
   28.9 s), suggest sections (12.6 s), stability (5.8 s); replace and
   hidden colours are just over bigmodels' bar.
8. **No path-traced render** (Studio's Eyesight, Mecabricks' farm). The
   owner has it on their list.
9. **English only** (Mecabricks eight, LeoCAD six and more; [Settings has
   no language](app_ux3/gap_settings_no_language_1280x720.webp)).
10. **Studio has never been run beside it** (studioside, waiting on the
    owner).
11. Smaller: 110 commands without a key (the reference picture, Simulate,
    Motions among them); Page Up and Down as step keys; a grid in one
    Pattern; the first build's offer that lingers; a part from an OBJ; an
    originality score; a candidate pictured without placing it.

## The units

Ten, ranked, each its own worktree off the next stage. No two own the same
file. Five files are registries, as `tools/suite/*.txt` is:
- `src/ui/shell.gd`'s `_define` and `MENUS`;
- `src/ui/keymap.gd`'s `PRESET_KEYS`;
- `src/net/app_tools.gd`'s `COMMANDS`, `WINDOW_ONLY`, `GUIDE`, its tool
  list and its dispatch (steps3 alone owns its `_edit_steps`);
- `tools/mcp_tools.json`, written by `mcp_sync_probe --write`;
- `docs-site/generated/menus.json`.

A unit that adds a command, a key or a tool adds its own lines there, in a
block of its own, and changes no one else's. Every new probe goes on its
own line in `tools/suite/*.txt`. **Owner** marks a unit that needs the
owner.

| # | unit | gaps | size | owner | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|
| 1 | **webstart** | 1 | M | | `src/boot/shell.html`; `src/net/web_packs.gd`; `src/main.gd` (its start only); `tools/web/pck_split.py`; `tools/export.sh` | see below |
| 2 | **steps3** | 2, 11 | M | | `src/ui/steps_bar.gd`; `src/assembly/author_steps.gd`; `app_tools.gd`'s `_edit_steps`; new `src/dev/steps3_probe.gd` | see below |
| 3 | **mcphand** | 3 | M | | new `src/net/hand_tools.gd` (the tools, called from `app_tools.gd`'s dispatch); `src/assembly/mirror.gd`; `src/assembly/split_merge.gd`; `src/ui/measure.gd`; new `src/dev/mcphand_probe.gd` | see below |
| 4 | **bricklink** | 4 | L | **owner: BrickLink's API, its keys and terms** | new `src/net/bricklink.gd`; new `api/bricklink.js`; `src/collection/collection.gd`; `src/ui/inventory_panel.gd`; new `src/dev/bricklink_probe.gd` | see below |
| 5 | **buildvideo** | 5 | M | | new `src/render/build_render.gd`; `src/ui/render_dialog.gd`; `src/render/animated_webp.gd`; new `src/dev/buildvideo_probe.gd` | see below |
| 6 | **booklet3** | 6 | M | | `src/render/booklet_maker.gd`; `src/render/booklet_pdf.gd`; `src/render/booklet_png.gd`; `src/assembly/booklet.gd`; new `src/dev/booklet3_probe.gd` | see below |
| 7 | **bigmodels2** | 7 | L | | `src/assembly/instructions.gd`; `src/assembly/sections.gd`; `src/assembly/stability.gd`; `src/ui/hidden_colours_panel.gd` | `command_probe` on Orthanc: Instructions **15 s or less** from the command to the booklet's first page, suggest sections **3 s**, stability **2 s**, replace and hidden colours **1.0 and 2.0 s** (bigmodels' bars); the car no slower; `instructions` and `booklet_pdf` pass |
| 8 | **pathtrace** | 8 | L | | new `src/render/path_tracer.gd` and its shader; `src/render/studio_render.gd`; `src/render/render_settings.gd`; new `src/ui/render_queue.gd`; new `src/dev/pathtrace_probe.gd` (not `render_dialog.gd`, buildvideo's) | see below |
| 9 | **languages** | 9 | M | | new `locale/` (`de.po`, `fr.po`, `es.po`); new `src/ui/language.gd`; `src/ui/controls_dialog.gd` (a row in Settings); `src/ui/shell_prefs.gd` (the saved choice applied at its first read, so `main.gd` is untouched); new `src/dev/languages_probe.gd` | see below |
| 10 | **studioside** | 10 | M | **owner: an install** | new `tools/studio/`; `src/parts/studio_io.gd`; new `docs/STUDIO_SIDE.md` | APP_UX2's bar, unchanged |

**1. webstart: the first visit's main thread, halved.**
- **Problem.**
  - `stage225` takes 22.5 s cold and 13.7 s warm to working on broadband
    on this box, against A13's 10 and 4.
  - The bytes are no longer the wait (6.9 s of network cold, 0.9 s warm).
    The main thread is: 13 to 15 s before the app is ready, then the
    catalogue, interface and first frames another 6 to 8 s.
  - The same build measures 16 s one hour and 27 s another on this box, so
    a time alone proves nothing.
- **Change.**
  - Profile the start in the browser (the Performance panel's main thread)
    and take out of it whatever the first frame and the bin do not need:
    the classes' statics, `Main._ready`'s work, the catalogue's parse, the
    interface built before it is shown.
  - Load those after the first frame, as webload loads the data pack,
    primitives and light when wanted.
- **Bar** (`load_check`, broadband, two cold and two warm, each against
  live in the same hour):
  - cold to working **40% less** than live, warm **50% less**;
  - the app ready (the scripts done) **half** of live's, cold;
  - a part from the bin to its ghost no slower than live's;
  - no more bytes before working (15.9 MB);
  - `fit_check` passes; `light_render`, `flex_skin` and `site` flows pass.

**2. steps3: any step in one action, by hand and over MCP.**
- **Change.**
  - The timeline's step row takes a drop: the selection dragged onto a
    step goes there (Studio).
  - Edit, Build steps, Move to step… with the step's number typed, and on
    the menu on a part.
  - Keys for step earlier, later, merge and delete; Page Up and Page Down
    as step keys under the LDCad preset (its own), Ctrl+A and Ctrl+D under
    Studio's.
  - `edit_steps` gains `op: "to"` with `step=`: bricks to any step in one
    call, the booklet following, one undo.
- **Bar** (`steps3_probe`, 1280 x 720):
  - a part in step 3 of a 20-step model moved to step 17 in **2 actions or
    fewer** (a drag, or the command and a typed number), one undo, the
    booklet's plan following;
  - the same by `edit_steps {"op": "to"}` in 1 call;
  - each of the four step commands has a key and does what its menu row
    does;
  - `booklet_edit`, `keys` and `palette` pass.

**3. mcphand: the window's hand tools for a session.**
- **Change.** Each a thin wrapper over the window's own code, one undo
  step, refused with what to fix:
  - `mirror_parts`: bricks= mirrored left to right as Shift+M does, left
    and right parts swapped, in place or as a copy beside;
  - `split_parts` and `merge_parts`: SplitMerge's rules on bricks=;
  - `measure`: the distance and the angle between two connectors (part and
    connector, as `attach` names them), as Measure says them;
  - `in_view`, read-only: the step the timeline is at, the part in the
    person's hand, and the reference picture (its file, size and place)
    with a picture of it under the model.
  - Not here: `submit_design`'s reply, which pushes the designer's steps
    at a five-part CAD request, is in `assistant.gd`, design5's. Written up
    for design5: under 20 parts with no features, answer it as a CAD edit.
- **Bar** (`mcphand_probe`, the tools called as a session calls them):
  - the car's left half mirrored by `mirror_parts` in 1 call, part for part
    what the window's Shift+M gives;
  - a 2 x 2 slope split, and six 1 x 1 plates merged into a 2 x 3, in 1
    call each, as Alt+S and Alt+M give;
  - `measure` gives a hinge left at 37° as 37.0°, within 0.1°;
  - `in_view` names the reference picture a probe laid, and changes
    nothing;
  - `mcp_sync_probe`, `mcp_probe` and `splitmerge` pass;
  - then the MCP walk's 13 tasks (`docs/app_ux3/mcp_walk/`) rerun by a real
    session, and its calls said beside today's 42 (said, not gated).

**4. bricklink: prices and a wanted list in 3 clicks (owner).**
- **Owner.** BrickLink's API needs a consumer key and token, and its terms
  allow showing price guide data only on conditions. Prices could instead
  come from BrickOwl's or Brickset's API, each with its own terms. The
  owner picks, signs up and puts the keys in Vercel; no money.
- **Change.**
  - The parts list and the status bar give the model's and the selection's
    price, new and used, from the price guide's six-month average, kept a
    day; the colour palette marks each colour's price band.
  - Upload a wanted list: File, Export, BrickLink wanted list, Upload, in
    3 clicks, through `api/bricklink.js` (the keys never in the app).
  - `parts_list` over MCP gives the prices, so a session can design to a
    budget.
- **Bar** (`bricklink_probe`, against a stand-in of the API):
  - the car's price is the sum of its parts' prices, to the cent;
  - the selection's price in the status bar;
  - a wanted list uploaded in 3 clicks, every part and colour in it;
  - `parts_list` over MCP gives the same total.

**5. buildvideo: the model built up, as a video.**
- **Change.**
  - Render, Building: the timeline rendered as a WebP and an MP4, each
    step's parts arriving, the camera turning slowly; length 10 to 60 s.
  - `render_model {"kind": "build"}` for a session, as a job.
- **Bar** (`buildvideo_probe`):
  - the car's 61 parts in a 20 s WebP at 720p, every frame's parts a prefix
    of the build order, the last frame the whole model;
  - **3 actions** from the model (Render, Building, Return);
  - over MCP in 1 call and its job;
  - `render` and `motion_render` pass.

**6. booklet3: Studio's booklet extras.**
- **Change.**
  - Buffer exchange: a step's part drawn pulled out along the way it goes
    in, with an arrow (Studio's offsetting parts).
  - A 1:1 guide on the step that first uses a Technic axle or beam.
  - A colour guide for a step, and a sub-model's preview before it is
    built.
  - `edit_booklet` sets each for a session.
- **Bar** (`booklet3_probe`):
  - a 4-long axle's 1:1 guide measures **32.0 mm, within 0.2 mm**, on a
    300 dpi PNG page and in the PDF;
  - a pulled-out part sits 2 studs out along its line, its arrow pointing
    in;
  - the colour guide lists the step's colours;
  - `booklet_edit`, `booklet_pdf` and `booklet_later` pass.

**8. pathtrace: a path-traced picture.**
- **Change.**
  - Best becomes path traced where the GPU allows: a progressive path
    tracer (a compute shader over the model's meshes, the HDRI as light),
    the picture getting cleaner until stopped or at its samples. Render's
    existing "Best's frames" row sets the samples, so the dialog itself,
    buildvideo's, is untouched.
  - A render queue, a panel of its own (`render_queue.gd`, its command in
    `shell.gd`'s registry): the current view added with Render's settings,
    several run one after the other.
  - On the web, the same where the GPU allows, said plainly where it does
    not.
- **Bar** (`pathtrace_probe`, on the GPU):
  - the car at 1280 x 720, 256 samples, in **60 s or less** on the box's
    RX 6700 XT;
  - its noise below a set level against a 4,096-sample reference;
  - soft shadows and light bounced off the floor where Best has none
    (measured at three points);
  - three queued renders made in turn with the window still in use;
  - `render` and `light_render` pass.

**9. languages: German, French and Spanish.**
- **Change.**
  - Godot translates a Control's words when a translation is loaded, so
    this is mostly new files and a row in Settings.
  - German first (the longest words, so the layout's test), then French and
    Spanish: three of the largest LEGO markets in Europe, and three of
    Mecabricks' eight.
  - The keys sheet, the menus, the tour and the first build in each; the
    model's own names and part names stay as they are.
- **Bar** (`languages_probe`, 1280 x 720):
  - every menu row, toolbar tooltip and panel title translated in each,
    none left in English;
  - in German, `fit_check` and `palette`'s menu bars pass: no menu taller
    than 60% of the window, no control off the page;
  - the choice survives a restart.

**7. bigmodels2 and 10. studioside** have their bars in the table.

**Next, once those land:**
- **Keys:** 110 commands have none; the reference picture, Simulate and
  Motions among them. A key each where a builder uses it often.
- **Pattern's grid** in one go (LeoCAD's Array), and a part from an OBJ
  or STL with its connectors (Studio's Part Designer).
- **An originality score** (BricksChat) from the real sets' sub-assemblies
  `find_techniques` already reads.
- **The first build's offer** goes once a person has built by hand.
- **3Dconnexion:** the owner's device and a native extension.
- **A collision switch** stays out on purpose.

## The top ten, by value to a person building

1. **webstart:** the first visit's main thread halved: 40% sooner to
   working than live, toward A13's 10 s.
2. **steps3:** any step in one action, by hand and over MCP.
3. **mcphand:** a session measures, mirrors, splits and merges as the window
   does, and sees what the person sees.
4. **bricklink:** prices and a wanted list in 3 clicks (owner).
5. **buildvideo:** the model built up, as a video, for a model page.
6. **booklet3:** buffer exchange, a 1:1 guide, colour guides.
7. **bigmodels2:** Instructions on 10,000 parts in 15 s.
8. **pathtrace:** a path-traced picture, and a queue.
9. **languages:** German, French and Spanish.
10. **studioside:** Studio run beside it (owner).

## Sources

Brickworks' own figures are from the runs above: the walk's logs and
pictures, the MCP walk's prompts and streams
([app_ux3/mcp_walk/](app_ux3/mcp_walk/)), and the release logs named. The
field's, beyond APP_UX2's Sources:
- Studio, prices: <https://studiohelp.bricklink.com/hc/en-us/articles/5705572363159>
- Studio, steps and Move To: <https://studiohelp.bricklink.com/hc/en-us/articles/7123810151063>
- Studio, wanted list upload: <https://studiohelp.bricklink.com/hc/en-us/articles/5705925898135>
- Studio, animation and building videos: <https://studiohelp.bricklink.com/hc/en-us/articles/5705001957399>
- Studio, collision: <https://studiohelp.bricklink.com/hc/en-us/articles/5412820155927>
- Studio, instruction extras: <https://studiohelp.bricklink.com/hc/en-us/articles/5627325902615>
- Studio, Eyesight render: <https://studiohelp.bricklink.com/hc/en-us/articles/6505772624023>
- Studio, Part Designer import: <https://studiohelp.bricklink.com/hc/en-us/articles/5877891573911>
- Mecabricks render farm: <https://brickset.com/article/52611/mecabricks-the-render-farm>
- Mecabricks, VR and AI in testing: <https://www.schieb.de/755442/virtueller-baukasten-fuer-lego-fans>
- LDCad features: <http://www.melkert.net/LDCad/features>, <http://www.melkert.net/LDCad/download>
- LeoCAD: <https://github.com/leozide/leocad/releases>, <https://www.leocad.org/docs/history.html>
- Kinebrick Studio: <https://github.com/fhareide/kinebrick-studio-releases/releases>
- BricksChat: <https://www.eurobricks.com/forum/forums/topic/214312-software-brickschat-generate-buildable-mocs-from-your-own-parts-and-download-instructions/>
- LDraw Nova: <https://github.com/anteloc/ldraw-nova>, <https://www.tomshardware.com/tech-industry/artificial-intelligence/open-source-tool-designs-lego-builds-with-more-than-2-000-real-pieces-their-programs-output-detailed-cad-files-but-no-models-have-been-built-yet>
- ldraw-mcp: <https://github.com/musharna/ldraw-mcp>
- brckd: <https://apps.apple.com/us/app/id6761261733>
