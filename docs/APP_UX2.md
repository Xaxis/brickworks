# The app against the best tools, round two

Written 2026-10-30 by appux2 against `stage225` at `b94dd1d8`.
[APP_UX.md](APP_UX.md) (appux371, against `1699520f` the same morning) measured
the app, planned A1 to A13 and B1 to B10, and every one of them has since been
built or is being built. This file measures the app again, item by item, says
where the field still does better, and plans the next round.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second.
[COMPETITIVE.md](COMPETITIVE.md) is the feature matrix and is not repeated.
[CADTASK.md](CADTASK.md) measures building real sets through the interface.

## How it was made

- **appux371's walk, rerun on `stage225`.** Its script and its tasks
  ([app_ux2/appux_walk.gd](app_ux2/appux_walk.gd)), windowed on the GPU at
  1280 x 720 and 1400 x 900. It was run twice:
  - first unchanged;
  - then with two changes. A `counts` section reads what appux371's bars
    count: tiles in sight, keys in sight, commands with a key, and Render
    from the palette. The turn in a wall was rewritten, because R there
    now puts the part in hand (A3), and the old script read a part that was
    no longer in the model.
- **Round one's bars,** read off the probes the units wrote, as the
  releases that carry them ran them (`release-out/rel-m222_probe_*.log`,
  `rel-m224_probe_*.log`, and the lead's `stage225` runs). Each line below
  names its probe.
- **The web export of `stage225`,** built here and served locally by
  `relay_server.mjs`, through `fit_check` at its sizes, 1280 x 720 and
  390 x 844 among them.
- **The live site's load,** with `load_check` on broadband, cold and warm,
  at 1280 x 800 (the only size it runs), as appux371 timed it. The live
  site serves rel-m222 (`6b98fdd0`), which holds most of round one; A13's
  own work is still in webload's worktree. The local server sends the
  export uncompressed and uncached (110 MB, 51 s cold and warm alike), so
  it cannot stand in for the site's load.
- **The field,** from each tool's help pages, release notes and changelogs
  as of 30 October 2026 (Sources). Studio's articles on Split and Merge,
  colour shortcuts, reference images and the parts palette's filters were
  read in full.
- **The box was shared.** The load average was about 30 through the second
  walk, against single figures for appux371's. Seconds and frame times are
  stretched by that; counts are not. Where a time matters, the cleaner run
  is given too.
- **Not run:** Studio itself (Wine needs the box's password), the assistant
  (it spends money), and the connector.

## What the walk measured, then and now

| act | appux371 (`1699520f`) | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|
| desktop start, the first 120 frames | 4.4 to 6.2 s | 5.0 s (8.4 s at load 30) | 5.0 s (10.0 s at load 30) | walk |
| bin tiles in sight on the first open | 8 at 1280 x 720, 16 at 1400 x 900 | **24**, every one named ([picture](app_ux2/first_open_1280x720.webp)) | **30**, every one named; the bar was 40 ([picture](app_ux2/first_open_1400x900_30_tiles.webp)) | walk `counts` |
| keys sheet (F1), rows in sight | 1 | **32 of 96** ([picture](app_ux2/keys_sheet_1280x720.webp)) | **46 of 96** | walk `counts`; `keysheet` 36 of 85 at rel-m221 |
| commands with a key (default keys) | 51 of 122 | **75 of 188** | same | walk `counts` |
| Render from the model by keys | menus only | **5 presses** (Ctrl+/, R, E, N, Return; [picture](app_ux2/palette_ren_1280x720.webp)) | same | walk `counts`, `palette` |
| menus: rows, and height in the interface's units (a 1280 x 720 window is 783 tall) | File 20, **Edit 39 (689)**, View 34, Build 31, Tools 17, Help 6 | File 19, Edit 25 (486), View 33 (644), **Build 37 (689, and it scrolls)**, Tools 17, Help 2 | the same rows; Build 732 | walk `menus` |
| the part menu | 13 rows | 23 rows | 23 | walk `menus` |
| a wall of eight 1 x 4s from the search | 20 events, 2.7 s | 20 events, 2.0 s | 20 events, 2.6 s | walk `wall` |
| the ghost following the pointer, 3 frames a move | 32.8 ms, worst 44.7 | 27.5 ms, worst 32.3 (50.9 and 106 at load 30) | 32.7, worst 42.2 (38.9 and 49.7 at load 30) | walk `wall` |
| R on a brick in a wall, 15° step | nothing: "no room to turn it there" | **in hand, turned; down in 3 actions** (R, aim, click), 15.0° ([picture](app_ux2/turn_in_wall_down_1280x720.webp)) | the same | walk `turns` |
| Properties with a part selected | X and Y in sight, the rest behind a scroller | **every field in sight**, but the bin folds to its rail ([picture](app_ux2/bin_properties_take_turns_1280x720.webp)) | the same: the bin folds ([picture](app_ux2/bin_properties_take_turns_1400x900.webp)) | walk `turns` |
| a brick alone, 3 x R at 15° | 45° | 45° | 45° | walk `dialogs` |
| 25 panels and dialogs opened | all open, 0.8 to 1.6 s with 90 frames | all open, 0.6 to 1.0 s (0.7 to 2.0 at load 30) | 0.8 to 1.3 s (1.1 to 1.7 at load 30) | walk `dialogs` |
| search, 30 words | the wanted part first in 20 (its count); 25 by the count here | **27**: 19 of the 22 words with a wanted part, and all 8 that name a kind | same | walk `search` |
| web, first visit, cold → working | 14.8 s, 17.3 MB, main thread 8.6 s | **16.2 s**, 17.9 MB, main thread 9.6 s (live rel-m222, load 30) | | `load_check` |
| web, warm | 8.1 s, main thread 7.4 s | **9.0 s**, main thread 8.3 s | | `load_check` |
| web, a part from the bin to its ghost | 533 to 628 ms | 629 ms cold, 1,156 ms warm | | `load_check --pick` |
| web, the page's controls and the model's share | | every control on the page; the model **60%** of the width (the bar is 60%), 72% with the assistant; up in 11 s ([picture](app_ux2/web_1280x720.webp)) | 1400 x 900 at 1x and 2x pass | `fit_check` |
| web, a phone (390 x 844, 3x) | | every control on the page, the model 93% of the width, up in 14 s ([picture](app_ux2/web_phone_390x844.webp)). **Turned on its side (844 x 390), 2 checks fail:** the assistant cannot be turned on in Settings, and its rail is not shown; the key strip covers most of the model's 128 px of height ([picture](app_ux2/web_phone_844x390_strip_over_model.webp)) | | `fit_check` |

The search's 30 words, against appux371's run:
- **"2x4"** lists Brick 2 x 4 first (Plate 2 x 4 was first).
- **"snot"** lists the headlight brick, 87087, brackets and 11211 (it
  listed Technic pins).
- **"macaroni"** lists 27925, 85080 and 3063b first: the macaroni tiles and
  bricks. The walk still says rank 14, because it wants 25269, which is a
  quarter tile. The walk's own answer was wrong, not the search.
- **"jumper"** lists 15573, the jumper made today, first; the walk wants the
  older 3794b, which is sixth.
- **"bracket"** has 99781 fourth, after three other brackets.
- **"1x4 brick"** lists Brick 1 x 4 first, but two springs among the first
  eight tiles ([app_ux2/search_1x4_brick_springs.webp](app_ux2/search_1x4_brick_springs.webp)).

**Found on the way, not part of any bar:**
- The walk's Godot aborts at its quit, after opening 25 panels: "corrupted
  size vs. prev_size in fastbins", exit 134, at both sizes and in both runs.
  The release's probes quit cleanly. Not narrowed down here. Its data
  folders are kept in `/tmp/probe-data.appux_walk.*`.
- At 1280 x 720 the key strip along the model's foot takes three to five
  rows, about 100 px of the model's 650.
- A phone on its side (844 x 390) fails two of `fit_check`'s checks: the
  assistant cannot be turned on in Settings, and its rail is not shown.
  The key strip covers most of the model there. This is for the phone
  unit, which is building the phone's fit now.

## Round one, item by item

| item | its bar | where it stands on `stage225` | proof |
|---|---|---|---|
| A1 keys sheet | 20 rows in sight at 1280 x 720, filtered as typed | **met**: 32 of 96 rows (walk), 36 of 85 (probe); "hinge" leaves the hinge rows | walk `counts`; `keysheet` (rel-m221) |
| A2 greyed rows | 4.5:1 in every state | **met**: the lowest is 5.94:1 | `keysheet` (rel-m221) |
| A3 turn with no room | down, turned, in 3 actions | **met**: 3 actions, 15.0° | walk `turns`; `typed_moves` (rel-m224) |
| A4 tiles say what they are | every tile in sight named, 1280 x 720 too | **met**: 24 of 24. *Not built:* the list view (name, number, size, colours) | walk `counts`; `bin_names` (rel-m222) |
| A5 builders' words | 20 words in the top three; "2x4" gives the brick | **met**: 27 of 30 in the walk; the three not first are below | walk `search`; `search_rank` (rel-m222) |
| A6 copies stay in hand | 5 copies in 6 actions | **met**: 6 | `typed_moves` (rel-m224) |
| A7 each command once | none in two menus; Edit ≤ 25 rows in 60% of 720 | **met for Edit** (24 rows, 464 of 783). **Build grew from 31 to 37 rows** and scrolls at 1280 x 720; View is 33 rows, 644 of 783 | `palette` (rel-m224); walk `menus` |
| A8 the part menu | the six new rows run from it | **met**: 23 rows | `palette` (rel-m224) |
| A9 command palette | every command; Render in ≤ 6 presses | **met**: Render in 5 | walk `counts`; `palette` (rel-m224) |
| A10 room | 24 tiles at 1280 x 720, 40 at 1400 x 900; every Properties field in sight | **24 at 1280 x 720 (met); 30 at 1400 x 900 (not met: the 60% rule for the model holds the bin to six across).** Every field is in sight, but at 1280 x 720 and at 1400 x 900 the bin and Properties **take turns**: opening one folds the other | walk `counts`, `turns`; `columns` (rel-m224) |
| A11 keys | a key for every tool; Studio's 20 keys; rebinding | **met**. 113 of 188 commands still have no key in the default keys, among them Same colour, Same part, Select joined and Replace | `keys` (rel-m224); walk `counts` |
| A12 first build | ≤ 25 acts | **met**: 19 | `first_build` (rel-m224) |
| A13 web load | warm ≤ 4 s, cold ≤ 10 s | **being built** (webload). The live site is 16.2 s cold and 9.0 s warm, about a second more main thread than appux371 measured | `load_check` |
| B1 typed numbers | CADTASK's placements in ≤ 8; the 23.58° swing in ≤ 6 | **met**: 3 to 8 actions; the swing in 3 | `typed_moves`, `offgrid` (rel-m224) |
| B2 Connect | 8841-1's column in ≤ 6; ≤ 18 actions a part | **met**: 6; the walk's 25 parts at **17.80 a part** (from 29.76). Studio's modelled figure is **11.8 to 14.1** | `connect` (rel-m224) |
| B3 handles | any axis, any angle, 3 actions | **met**: x, y and z each in 3 | `handles` (rel-m224) |
| B4 Meet | a ring of eight in ≤ 4 | **met**: 3 actions, one undo | `hinge_align_ui` (rel-m224) |
| B5 Fits | ten pairs in the top five | **met** | `fits` (rel-m222) |
| B6 patterns | a fence of 12 in 5; a ring of 16 in 6 | **fence met** (5). **The ring is not measured by any probe** | `handbuild` (rel-m224) |
| B7 booklet | 40 pages from one in ≤ 10; 300 dpi; the font embedded | **met**: 46 pages, 38 exactly as the first and 7 moved and said; PNG pages at 300 dpi on the desktop (on the web 300 up to 134 pages, 93 at 1,405); LiberationSans embedded. *Not built:* a box turned, rulers and guides, a callout's steps posed apart | `booklet_later`, `booklet_pdf` (rel-m222) |
| B8 together | the other's pointer; pinned comments; nothing lost to a reload | **built**: pointers, Follow, pins, the 4 MB cap lifted. Closing a session can still lose changes (closesend is on it) | `together_pins` (stage225) |
| B9 a second view | | **being built** (split) | |
| B10 springs | | **being built** (springs) | |
| B10 a set as a bin | | **built**: 295 tiles for 10497-1's 295 kinds, each counting down | `setbin` (stage225) |
| B10 compare two saves | | **built**: 5,000 parts compared in 163 ms | `compare` (stage225) |
| B10 .io proven in Studio | | **not done**: needs Studio, so the owner | |
| B10 3Dconnexion | | **not done**: needs the device and a native extension | |

**appux371's "what the best tool does", checked again.** Each claim was read
against the tool's current page (Sources), and against the app:

| claim | still true of the tool? | the app now |
|---|---|---|
| Studio lists every key by group and remaps them; Frame selection, Connect and Paint are unbound | yes | the same: grouped sheet, rebinding, presets |
| Studio's arrows turn without regard to collision; Ctrl+Alt+C turns collision off | yes. Its own pages disagree on the arrows' step: 45° on one, 90° on another | a turn with no room puts the part in hand. No collision switch, by choice: exact collision is a lead |
| Studio's Clone is ready again after each click; right-click ends it | yes | the same, 5 copies in 6 actions |
| LDCad's Insert places another of the working part | yes | Q puts the last part back in hand |
| Studio's Connect: a connector on the part, then its target | yes, and Ctrl adds a second point | the same, with typed turns |
| Mecabricks: S, then a point on each part | **partly**: one point is clicked, on the other part | |
| Studio's rotate gizmo: 90° near the centre, 5° in the dial, 1° at the rim; pivot at the shared connection | yes | rings on any axis, typed angles |
| LeoCAD 26.09 added a trackball and axis gizmo | **reworded**: trackball, camera-plane and camera-axis rotation | **no free turn** about the view |
| Mecabricks shows axis arrows and two-axis panes | yes (2020) | arrows, **no panes** |
| No tool has hinge align; LDD's was "notoriously buggy" | yes, but the quote is from Eurobricks, 2016, not the source appux371 named | Meet |
| Studio's `=compatible()`, Find compatible, Find alternatives | yes. "Replace offers parts of a similar size" could not be confirmed: the page says "good candidates" | Fits |
| Studio's Page Design snaps to margins and centres, ghosts the previous step, applies to followings | yes; the ghost only when the camera matches | applied onwards; no guides |
| Studio's Build Together ends for everyone when the host leaves | yes | each person keeps their own undo; what happens when the first person leaves was not checked here |
| Studio: four viewports, each locked; LDCad's Space between split and one view | yes | being built (split) |
| Studio opens with a tutorial | yes, and Help, Welcome brings it back | Build your first model |
| Bricksmith turns parts with a 3Dconnexion mouse | yes (2.5); for parts, the camera is not said | no |
| LDCad lays springs and bands on paths | yes: `PATH_POINT` circles and `SPRING_SECTION` windings | being built (springs) |

## What the field does that Brickworks does not, yet

The latest versions, as of 30 October 2026:
- **Studio 2.26.10_1**, 27 October; 2.26.9_1 on 30 September.
- **LeoCAD 26.09**, 19 September.
- **LDCad 1.7 Beta 2b**, 15 March. The last stable release is 1.6d2, from
  June 2022.
- **Bricksmith 3.1**, February 2022, nothing since.
- **Mecabricks** has no versions. Its 2.0 was announced in October 2023
  and was still not out in September 2026 (forum, *unverified*).

Each tool's list is ranked by how much a person building by hand would feel
it. Items Brickworks already has were taken out after checking its source:
select connected, invert, show only, Measure, linked sub-assemblies, editing
inside one, Together's chat, and Motions.

**BrickLink Studio**
1. **Split and Merge** ("Split and merge" article). Alt+S splits:
   - plates into 1 x 1 plates;
   - bricks into 1 x 1 bricks, and a 1 x 1 brick into three 1 x 1 plates;
   - tiles into 1 x 1 tiles;
   - slopes and curved slopes into 1-wide slopes.

   Alt+M merges parts of one kind into a bigger one, one merge at a time.
   BrickLink's home page lists it under what is new. Brickworks splits only
   a mesh, in Brickify ([app_ux2/part_menu_no_split.webp](app_ux2/part_menu_no_split.webp)).
2. **A reference image** (Model, Add Reference Image).
   - A PNG or JPG on a plane in the scene, with eight scale handles and a
     typed size in units.
   - Opacity from 0 to 100%, a lock, and a row in the step list.

   Brickworks has nothing to trace over
   ([app_ux2/view_menu_no_reference.webp](app_ux2/view_menu_no_reference.webp)).
3. **Colours on keys.** Up to ten favourite colours and ten of the model's
   own each get a key a person sets; a key paints the whole selection.
   Brickworks' [ and ] step through ten fixed quick colours, and C paints
   the selection in the one chosen: red to blue is three presses and a C.
   Any other colour is a click in the swatches or Shift+C and its name
   ([app_ux2/colours_no_keys_1280x720.webp](app_ux2/colours_no_keys_1280x720.webp)).
4. **The parts palette filtered by colour.**
   - "Hide Unavailable Parts in the Selected Color" leaves only parts made
     in it.
   - A button shows or hides printed and stickered parts.

   Brickworks' swatches answer the reverse question: which colours the part
   in hand was made in.
5. **Replace opens on suggestions**, in 2 clicks. Brickworks replaces with
   the part in hand.
6. **Selection modes on one key.** Shift+V cycles single, colour, type, type
   and colour, connected and window. Brickworks has every mode, but none
   has a key in the default keys.
7. **Instruction pages.**
   - Text and pictures turn by degrees, flip, and take an opacity.
   - Arrows bend by as many control points as are added.

   Brickworks' boxes cannot be turned (B7's leftovers).
8. Smaller: a Pose tool on posable parts, Ctrl to glide an axle without its
   stud snap, and a model's size in several units.

**Mecabricks**
1. **Two-axis panes** beside the move arrows (Brickset, 2020). Brickworks'
   handles have arrows and rings, no panes
   ([app_ux2/handles_no_panes_1280x720.webp](app_ux2/handles_no_panes_1280x720.webp)).
2. **Eight interface languages**: German, English, Spanish, French,
   Italian, Portuguese, Russian and Swedish. Brickworks has English only.
3. **Touch screens** (2020). Brickworks' phone fit is being built.
4. A node animation editor (forum titles only, *unverified*), and a
   Blender add-on for renders ($25, revision 2.1.17).

**LDCad 1.7**
1. **Springs and bands** on paths, with spring windings and shock absorber
   templates. Being built here.
2. **The angle between selected pins,** used to place springs and
   linkages. Brickworks' Measure gives a distance only
   ([app_ux2/measure_no_angle_1280x720.webp](app_ux2/measure_no_angle_1280x720.webp)).
3. **One action each:**
   - Insert places another of the working part;
   - Shift+Insert brings back the last model;
   - a double-click on a part in the bin replaces the selection with it.
4. **A grid relative to the selection** (O), and snapping the selection to
   it on two axes or three (Home, Shift+Home).
5. **Step keys:** Page Up and Page Down, Ctrl for the first and last, and
   Ctrl+Insert appends a step. 126 keys in all. Brickworks' Page Up and
   Page Down move the selection a plate; its steps are on B, E and
   Shift+[ and ].
6. A colour wheel with six saved views and a history; Lua macros.

**Bricksmith 3.1**
1. **Insert Related** adds the matching part in one command: a tyre for a
   wheel, a drawer for a cupboard. Brickworks' route is the Fits chip,
   a pick and a put: 3 actions at least.
2. A **3Dconnexion mouse** to turn parts.
3. **A colour randomiser** for foliage, rock and mosaics.
4. **Change origin** of a sub-model, correcting every place it is used.

**LeoCAD 26.09**
1. **A trackball turn**, and turns in the camera's plane and about its
   axis.
2. **Translations:** Simplified Chinese new in 26.09; Spanish, Czech,
   German and Ukrainian before.
3. **Several files merged into one project**; the model list reordered by
   dragging; sub-models opened from the parts picker.
4. A **train track layout editor** (25.09), undocumented.
5. Undo of camera, light, visibility and properties changes.

**New in the field since the summer**
- **Kinebrick Studio v0.1.0-beta.1, 29 October 2026,** for Windows, macOS
  and Linux. These are the author's claims, *unverified*:
  - a Technic editor and simulator that opens .ldr, .mpd and .io, tested
    to 46,000 parts;
  - Technic-aware snapping, and helpers for chains, bands and shock
    absorbers;
  - motors that stall under load, interference checked over the whole
    motion cycle, and range of motion shown.

  It is the nearest new rival to Brickworks' Motions and Simulate.
- **BricksChat** (22 October): a web AI that designs from text, a picture
  or a person's own parts. About 100 parts takes 9.5 to 12 minutes, and
  there are two free builds (*unverified*).
- **BrickStep** (August): automatic instructions on the web from Studio or
  LDraw files, up to 1,000 parts.
- **Eurobricks' "dream LEGO CAD" thread** (July to September) asks for:
  - a part turned to face a stud, hole or clip;
  - angles and distances in studs;
  - instructions that keep the build angle across pages;
  - Technic kinematics;
  - LDD's ease.

## The gaps, by value to a person building

1. **Actions a part are still above Studio's.**
   - Connect brought the walk from 29.76 to 17.80, against Studio's
     modelled 11.8 to 14.1.
   - Connect's own placings take 6 actions. The rest goes on finding the
     part and its colour, and on the parts Connect does not place.
   - The set's bin (B10) now holds every part of a set in its colour, and
     no walk has used it yet.
2. **Colour is still slow.**
   - Every part has one. [ and ] step through ten fixed colours, so a
     colour is up to five presses and a C; none of a person's own colours
     is on a key.
   - The bin cannot be asked for "parts made in Sand Green". Studio does
     both, LDCad the second.
3. **Big models wait.** On Orthanc's 10,105 parts (`command`, rel-m224):

   | command | appux371 | now |
   |---|---|---|
   | select joined | 6.1 s | **7.5 s** |
   | paste all | 3.1 s | **5.0 s** |
   | duplicate all | 3.2 s | **4.4 s** |
   | stability | | 4.4 s |
   | timeline | 2.8 s | 2.5 s |
   | replace | | 2.4 s |
   | hidden colours | | **16.7 s** |
   | suggest sections | | **12.3 s** |
   | Instructions | 28.9 s | **31.4 s** |

   Every one says so before it holds the window. The release's box was
   shared, so part of the rise may be load. Kinebrick claims 46,000 parts.
4. **Nothing to trace over.** A MOC from a photo or a plan has no
   reference picture (Studio).
5. **A laptop's bin and Properties take turns.**
   - At 1280 x 720 and at 1400 x 900, opening Properties folds the bin,
     and the bin folds Properties.
   - A typed placement and the next part cost a rail click each way.
   - B1's typed numbers took most of the typing out of Properties, so this
     is felt less than in round one.
6. **No split or merge** of parts (Studio's newest headline feature).
7. **No panes or free turn on the handles, and no angles in Measure**
   (Mecabricks, LeoCAD 26.09, LDCad).
8. **The menus grew back.** Build has 37 rows and scrolls in a 720 window
   ([app_ux2/build_menu_scrolls_1280x720.webp](app_ux2/build_menu_scrolls_1280x720.webp)).
   View has 33. The selection modes have no key in the default keys.
9. **One action for the obvious part** (Insert Related, LDCad's
   double-click to replace), and the bin has no list view.
10. **Booklet pages:** a box, text or picture cannot be turned; there are no
    guides; arrows do not bend (Studio).
11. **Simulate against Kinebrick:** no stall under load, no interference
    over the cycle, no range of motion.
12. **Studio has never been run beside it.** Brickworks' .io export has
    not been seen opening in Studio, and every Studio number in CADTASK is
    modelled.
13. **English only** (LeoCAD has six languages and more; Mecabricks eight).

In flight, so not ranked here:
- **The web's start** is a little slower than appux371 measured: 16.2 s
  cold and 9.0 s warm on the live site, about a second more on the main
  thread. webload is on it (A13).
- **The phone on its side** fails two `fit_check` checks; the phone unit
  is on it.
- **Springs and a second view** are being built.

## The units

Ten, ranked, each its own worktree off the next stage. No two own the same
file. Three files are registries, as `tools/suite/*.txt` is:
- `src/ui/shell.gd`'s `_define` and `MENUS`;
- `src/net/app_tools.gd`'s `COMMANDS`;
- `docs-site/generated/menus.json`.

A unit that adds a command adds its own lines there, in a block of its own.
Only **keys3** changes what is already in them.

Every new probe goes on its own line in `tools/suite/*.txt`. **Owner**
marks a unit that needs the owner.

| # | unit | gaps | size | owner | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|
| 1 | **pace** | 1 | M | | new `src/dev/setwalk_probe.gd`; `src/ui/connect_tool.gd`; `src/assembly/carry.gd`; `docs/CADTASK.md` | `setwalk_probe` builds 8841-1's 25 walk parts and 5762-1's first 25 from the set's bin, through the window, at **12 actions a part or fewer**, each exact; `connect_probe` passes |
| 2 | **bin2** | 2, 9 | M | | `src/ui/parts_bin.gd`; `src/parts/part_fits.gd`; `src/dev/search_rank_probe.gd`; new `src/dev/bin2_probe.gd` | see below |
| 3 | **keys3** | 2, 8 | M | | `src/ui/shell.gd` (rows and keys); `src/ui/keymap.gd`; `src/ui/controls_dialog.gd`; new `src/ui/colour_keys.gd`; new `src/dev/keys3_probe.gd` | see below |
| 4 | **bigmodels** | 3 | L | | `src/assembly/select_by.gd`; `src/ui/edit_verbs.gd`; `src/assembly/builder.gd`; `src/ui/hidden_colours_panel.gd` | `command_probe` on Orthanc: select joined, duplicate, paste and replace of all 10,105 parts **1.0 s or less each**; hidden colours 2 s or less; the car no slower; `cadtask_frames` within budget |
| 5 | **refimage** | 4 | M | | new `src/ui/reference_image.gd`; `src/parts/model_store.gd`; new `src/dev/refimage_probe.gd` | see below |
| 6 | **splitmerge** | 6 | M | | new `src/assembly/split_merge.gd`; new `src/dev/splitmerge_probe.gd` | see below |
| 7 | **handles2** | 7 | M | | `src/ui/handles.gd`; `src/ui/measure.gd`; new `src/dev/handles2_probe.gd` | see below |
| 8 | **pages2** | 10 | M | | `src/ui/page_editor.gd`; `src/render/booklet_maker.gd`; `src/render/booklet_pdf.gd`; `src/render/booklet_png.gd`; `src/dev/booklet_edit_probe.gd` | see below |
| 9 | **motion** | 11 | L | | `src/assembly/simulation.gd`; `src/assembly/motions.gd`; `src/ui/simulate_panel.gd`; new `src/dev/motion_probe.gd` | see below |
| 10 | **studioside** | 12 | M | **owner: an install** | new `tools/studio/`; `src/parts/studio_io.gd`; new `docs/STUDIO_SIDE.md` | see below |

**1. pace: a set from its own bin at Studio's pace.**
- **Problem.**
  - The walk is 17.80 actions a part with Connect, against Studio's
    modelled 11.8 to 14.1.
  - The walk's own lines say a part by Connect takes 6 actions, and 13
    once it is found in the bin.
  - So most of what is left is finding: typing a search, choosing a
    colour, looking through tiles.
- **Change.**
  - Run the walk from the set's bin (B10), which holds each of the set's
    parts in its colour, counted.
  - Then cut where the actions still go, in Connect and the hand. Keep the
    two sets of CADTASK §9 beside it.
  - Whatever needs the bin itself (for example the step's parts first) is
    written up for bin2, not done here.
- **Bar.** 12 actions a part or fewer, every part exact; written into
  CADTASK as a new section.

**2. bin2: colour in the bin, and the obvious part in one action.**
- **Change.**
  - "Only parts made in this colour" on the colour panel, from the years
    data the swatches already use (Studio's "Hide Unavailable Parts in the
    Selected Color").
  - One button hides printed and stickered tiles.
  - A double-click on a tile replaces the selection with it (LDCad).
  - A double-click on a Fits tile puts that part on the selection's free
    connector, through Connect's API (Bricksmith's Insert Related).
  - A list view: name, number, size, colours made (A4's unbuilt half).
  - "1x4 brick" lists bricks before springs.
- **Bar** (`bin2_probe`, at 1280 x 720):
  - Sand Green chosen and the filter on: every tile in sight is a part
    made in Sand Green, 0 wrong of 24 or more.
  - One click hides every printed tile.
  - A double-click replaces three selected parts in 1 action, one undo.
  - A pin goes into a selected beam's hole from Fits in 1 action.
  - The list view shows 20 rows or more.
  - "1x4 brick" has bricks only in its first eight tiles.
  - `bin_names`, `fits`, `setbin` and `search_rank` pass.

**3. keys3: colours on keys, selection on keys, and menus that fit.**
- **Change.**
  - Ten keys paint the selection, or the part in hand, in ten favourite
    colours, and ten more in the model's ten most used. The unit picks
    keys that are free in the app and in Chrome and Firefox: Ctrl+1 to 8
    switch tabs in every browser, and Alt+1 to 9 do in Firefox on Linux.
    [ and ] keep their quick colours.
  - Favourites are set in the keys sheet and kept with the account's
    keys. Under the Studio preset they start unbound, as Studio's do.
  - A key each for Same colour, Same part, Select joined and Invert in the
    default keys, and Shift+V cycling them under the Studio preset.
  - Build split so that every menu is 25 rows or fewer, for example a Make
    menu for the minifigure, mosaic, brickify, part maker, print and
    sticker. View shortened to match. Still no command in two menus.
- **Bar** (`keys3_probe`, 1280 x 720):
  - A colour key paints three selected parts in 1 key, one undo, on the
    desktop and in the web build.
  - A favourite set in the sheet survives a restart.
  - Each of the four selection keys selects what its menu row does.
  - Every menu is 25 rows or fewer and 60% of the window's height or
    less, measured as `palette` measures Edit.
  - `palette`, `keys`, `keysheet` and `controls` pass.

**4. bigmodels: a 10,000-part model answers at once.**
- **Change.** Profile each command in the table of gap 3, and take the
  time out where it is spent: the joined search, the copy's register, the
  replace, the colour pass. Each says so before it holds the window, as
  now.

**5. refimage: a picture to build over.**
- **Change.**
  - View, Reference picture…: a PNG or JPG on a plane through the floor or
    a side, with corner handles.
  - Its width typed in studs; opacity; a lock that lets clicks through to
    the model.
  - Kept in the model's file, on a line other programs ignore.
  - Never in a render, the instructions or the parts list unless asked.
- **Bar** (`refimage_probe`):
  - Added in 4 actions or fewer.
  - Its typed width exact to 1 LDU.
  - Drawn at 40% opacity.
  - Locked, a click through it selects the part behind.
  - Saved and opened again the same.
  - Absent from a render and from the booklet.

**6. splitmerge: split and merge parts.**
- **Change.**
  - Studio's rules for Split.
  - Merge goes further than Studio's: it merges as far as it can in one
    go, where Studio does one merge at a time, and only into parts made in
    that colour.
  - Joints and collision are kept; one undo each.
- **Bar** (`splitmerge_probe`):
  - A 2 x 4 plate becomes eight 1 x 1 plates on the same studs in 1 key.
  - Three stacked 1 x 4 plates become one 1 x 4 brick in 1 key.
  - Six 1 x 1 plates in a 2 x 3 become one 2 x 3 plate.
  - A merge with no real part says so and changes nothing.

**7. handles2: panes, a free turn, and angles.**
- **Change.**
  - Three small panes on the Move handles, for two axes at once
    (Mecabricks).
  - An outer ring that turns about the view's axis, and a trackball
    inside it (LeoCAD 26.09).
  - Measure between two connectors says the angle between them as well as
    the distance (LDCad).
- **Bar** (`handles2_probe`):
  - A part moved on the x-z plane by its pane in 2 actions.
  - Turned about the view's axis by the outer ring in 2.
  - Measure says the angle between two pin holes to 0.1°.
  - `handles` passes.

**8. pages2: Studio's page objects.**
- **Change.**
  - A picture, text or box turned by degrees and given an opacity.
  - Arrows bent by control points.
  - Guides dragged from rulers, which boxes snap to.
  - A callout's steps posed apart from its parent's.
- **Bar** (`booklet_edit_probe`):
  - A picture turned 30° and a text at 50% opacity, 3 actions or fewer
    each.
  - An arrow bent through two points.
  - A box dropped near a guide lands on it, to 1 px.
  - The PDF and the PNG show each.

**9. motion: Simulate to Kinebrick's mark.**
- **Change.**
  - Interference over the whole cycle: the first angle where moving parts
    meet, said and shown.
  - The range of motion of a hinge or linkage, in degrees.
  - A motor's torque against its load: a train that stalls says where.
- **Bar** (`motion_probe`):
  - An arm that meets a wall at 140° is reported within 2°.
  - A four-bar linkage's range is within 1° of its worked value.
  - A Power Functions M motor on a load past its torque stalls and says
    so.
  - `simulate_probe` and `motions_probe` pass.

**10. studioside: Studio beside it (owner).**
- **Problem.**
  - Brickworks' .io export has never been seen opening in Studio.
  - Every Studio number in CADTASK is modelled.
  - Wine needs the box's password (CADTASK gap 6).
- **The owner, one of:**
  - install Studio 2.26.10 under Wine here (sudo);
  - or open three .io files on their own machine and send back what
    Studio shows.

  No money.
- **Bar.**
  - Three models exported as .io (the car, Orthanc, a set with
    sub-models) open in Studio with every part, colour and step.
  - Studio's actions a part timed on 5762-1's first eight parts, by
    CADTASK's rules, replacing the modelled 14.1.

**Next, once those land:**
- **Languages:** the owner picks which first. Godot translates a Control's
  words when a translation is loaded, so this is mostly new files and a
  setting. Starts after keys3, for the settings row.
- **3Dconnexion:** the owner's device, and a native extension.
- **A train track layout** (LeoCAD 25.09).
- **A collision switch** (Studio's Ctrl+Alt+C) is left out on purpose:
  exact collision is one of the things Brickworks does better.

## The top ten, by value to a person building

1. **pace:** 17.80 actions a part to 12 or fewer, below Studio's modelled
   11.8 to 14.1.
2. **bin2:** the bin by colour, and the obvious part in one action.
3. **keys3:** a colour, or a selection, in one key, and menus that fit.
4. **bigmodels:** Orthanc's slow commands under a second.
5. **refimage:** a picture to build over.
6. **splitmerge:** Studio's newest headline feature, done further.
7. **handles2:** panes, a free turn and angles.
8. **pages2:** turned, faded and bent page objects, and guides.
9. **motion:** Simulate past Kinebrick's beta.
10. **studioside:** Studio run beside it, the .io proven, and its numbers
    measured (owner).

## Sources

Brickworks' own figures are from the runs above. The field's:
- Studio, latest release: <https://github.com/microsoft/winget-pkgs/pull/463222>, <https://en.wikipedia.org/wiki/BrickLink_Studio>
- Studio, Split and merge: <https://studiohelp.bricklink.com/hc/en-us/articles/6482107372823>
- Studio, reference image: <https://studiohelp.bricklink.com/hc/en-us/articles/15341721435799>
- Studio, colour shortcuts: <https://studiohelp.bricklink.com/hc/en-us/articles/7125031712663>
- Studio, filtering parts: <https://studiohelp.bricklink.com/hc/en-us/articles/43766580540567>
- Studio, Replace: <https://studiohelp.bricklink.com/hc/en-us/articles/6507503981207>
- Studio, selection tool: <https://studiohelp.bricklink.com/hc/en-us/articles/5410231515543-Selection-Tool>
- Studio, page objects: <https://studiohelp.bricklink.com/hc/en-us/articles/5680831206039>
- Studio, Pose: <https://studiohelp.bricklink.com/hc/en-us/articles/6502749986967>
- Studio, keys: <https://studiohelp.bricklink.com/hc/en-us/articles/5706320095255> and <https://studiohelp.bricklink.com/hc/en-us/articles/5410338956695>
- Studio, rotate and hinge: <https://studiohelp.bricklink.com/hc/en-us/articles/5411433123351>
- Studio, placing: <https://studiohelp.bricklink.com/hc/en-us/articles/5412087360919>
- Studio, clone: <https://studiohelp.bricklink.com/hc/en-us/articles/5412307707031>
- Studio, Connect: <https://studiohelp.bricklink.com/hc/en-us/articles/6481651047319>
- Studio, search and `=compatible()`: <https://studiohelp.bricklink.com/hc/en-us/articles/6502499385111>
- Studio, page design: <https://studiohelp.bricklink.com/hc/en-us/articles/5627735762967> and <https://studiohelp.bricklink.com/hc/en-us/articles/5627373330327>
- Studio, Build Together: <https://studiohelp.bricklink.com/hc/en-us/articles/6477757327767>
- Studio, camera and viewports: <https://studiohelp.bricklink.com/hc/en-us/articles/5409213150487>
- Studio, the tutorial: <https://studiohelp.bricklink.com/hc/en-us/articles/6476848743447>
- Studio, model info: <https://studiohelp.bricklink.com/hc/en-us/articles/8117822782103>
- LDD's hinge align, "notoriously buggy": <https://www.eurobricks.com/forum/forums/topic/142145-ldd-hinge-align-tool-issue>
- Mecabricks: <https://www.mecabricks.com/>, <https://brickset.com/article/52336/let-s-build-in-mecabricks>, <https://www.mecabricks.com/en/shop/product/4>, <https://www.mecabricks.com/en/forum/topic/69160/21>, <https://www.mecabricks.com/en/forum/topic/76253>, <https://www.mecabricks.com/en/forum/category/11>
- LDCad: <http://www.melkert.net/LDCad/download>, <http://www.melkert.net/LDCad/docs/keys>, <http://www.melkert.net/LDCad/docs/advEdit>, <http://www.melkert.net/LDCad/docs/gui>, <http://www.melkert.net/LDCad/tech/meta>, <http://www.melkert.net/LDCad/features>, <https://forums.ldraw.org/thread-29440.html>, <https://forums.ldraw.org/thread-29320.html>
- Bricksmith: <https://bricksmith.sourceforge.io/VersionHistory.html>
- LeoCAD: <https://www.leocad.org/docs/history.html>, <https://github.com/leozide/leocad/releases/tag/v26.09>
- Kinebrick Studio: <https://www.eurobricks.com/forum/forums/topic/214347-kinebrick-studio/>, <https://github.com/fhareide/kinebrick-studio-releases/releases/tag/v0.1.0-beta.1>
- BricksChat: <https://www.eurobricks.com/forum/forums/topic/214312-software-brickschat-generate-buildable-mocs-from-your-own-parts-and-download-instructions/>
- BrickStep: <https://www.eurobricks.com/forum/forums/topic/213829-software-brickstep-automatic-instruction-generator-for-lego-models/>
- The "dream LEGO CAD" thread: <https://www.eurobricks.com/forum/forums/topic/213692-what-features-would-you-have-in-your-dream-lego-cad/>
