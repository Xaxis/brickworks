# The app against the best tools, round five

Written 2026-11-06 by appux5 against `pre261` at `58280f45`. The web was
measured on rel-m266 (`a209f558`), live then. [APP_UX.md](APP_UX.md) to
[APP_UX4.md](APP_UX4.md) planned rounds one to four. Nine of round four's
ten are in `pre261`, every bar met: seeing, likewords (merged today),
intomodel, picklist, grid, partbypart, cutshapes, quiet and whatsthis.
The tracks unit is still running, and intomodel2 is fixing three losses a
review found in intomodel after it merged. This file measures the app a
fifth time, by hand and through a person's own Claude, says where the
field still does better, and plans round five.

The standing bar is unchanged: Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second.
[COMPETITIVE.md](COMPETITIVE.md) is the feature matrix,
[ROADMAP.md](ROADMAP.md) the designer's quality and [SOCIAL.md](SOCIAL.md)
the site; none is repeated.

## How it was made

- **The walk, a fifth time.** appux4's script and tasks, run on the GPU at
  1280 x 720 and 1400 x 900 from a locked snapshot of this commit,
  imported first ([app_ux5/appux_walk.gd](app_ux5/appux_walk.gd)). One
  section was added after the old ones, so their numbers still compare:
  `round4`, the status bar with nothing selected, What's This on a
  toolbar button, the hand's place in the status bar, Cut away by a box,
  Pattern's grid, the parts list's shops, Into this model, the train
  tracks, and the keys round four's commands have. Every picture it took
  (69 and 69) was looked at.
- **The same tasks over MCP,** as the owner's Claude does them
  ([app_ux5/mcp_walk/](app_ux5/mcp_walk/)):
  - the app in a window of its own with its MCP port open;
  - the walk's 30 words, and "1x4 brick", through `search_parts`;
  - then Claude Code on the subscription (`claude -p`, the Brickworks
    server alone, `--tools ""`, `--restricted`, no API key: all 27 streams
    say `apiKeySource: none`), one turn a task. APP_UX4's 18 tasks, then
    nine for what round four added ([prompts_round4.txt](app_ux5/mcp_walk/prompts_round4.txt)),
    in two sessions: the walk's ten in the first, the pod's three, round
    three's five and round four's nine in the second. Calls are counted
    from the sessions' own streams ([calls.txt](app_ux5/mcp_walk/calls.txt)).
- **Round four's bars,** read off each unit's probe run today from the
  same snapshot, one size each, as its header says: `seeing`, `likewords`,
  `intomodel`, `picklist`, `grid`, `partbypart` (a phone's 390 x 844 and a
  tablet's 1024 x 768), `cutshapes`, `cutshapes_kept`, `quiet` and
  `whatsthis`. All eleven passed.
- **The web:** `load_check` on live brickworks.diy (rel-m266), broadband,
  two cold and two warm loads with a part picked from the bin; and the
  same on a phone's 390 x 844 (3x, touch).
- **The field,** from each tool's help pages, release notes, changelogs,
  READMEs and commits as of 6 November 2026 (Sources). APP_UX2's to
  APP_UX4's lists and COMPETITIVE were read again; only what they did not
  cover is new here.
- **Not run:** Studio itself (studioside, the owner's), the in-app
  assistant on a key (it spends money), and claude.ai's connector.
- **The box was shared,** with one GPU slot and a load of 27 to 41
  through these runs, nearly twice APP_UX4's. Seconds are stretched by it;
  counts are not.

## What the walk measured, five times

The first two rounds' figures are in APP_UX4.

| act | appux3 (1280 / 1400) | appux4 (1280 / 1400) | now, 1280 x 720 | now, 1400 x 900 | from |
|---|---|---|---|---|---|
| desktop start, the first 120 frames | 6.6 / 10.2 s | 8.6 / 6.3 s (load 19) | 9.1 s (load 27 to 34) | 8.9 s | walk |
| bin tiles in sight on the first open | 24 / 30 | 24 / 42 | 24, every one named | 42, every one named | walk `counts` |
| Properties with a part selected | | every field; the bin gives way / beside it | every field in sight; the bin gives way | every field, the bin beside it | walk `turns` |
| keys sheet (F1), rows in sight | 32 / 46 of 123 | 32 / 46 of 128 | 32 of 139 | 46 of 139 | walk `counts` |
| commands with a key | 82 of 192 | 87 of 201 | **98 of 209** (the lead's `keys`) | the same | walk `counts` |
| Render from the model by keys | 5 presses | 5 | 5: Render still has no key | 5 | walk `counts` |
| the tallest menu, rows (height) | Edit 24 (464) | Edit 24 (464) | Edit 24 (464); Help 7, What's This? new; none scrolls | the same | walk `menus` |
| the part menu | 25 rows | 26 | 26 | 26 | walk `menus` |
| a wall of eight 1 x 4s from the search | 20 events, 2.6 / 3.8 s | 20, 2.4 / 3.2 s | 20, 2.5 s | 20, 4.5 s | walk `wall` |
| the ghost following the pointer, 3 frames a move | 26.9, worst 31.0 / 51.6, worst 107.6 ms | 34.3, worst 58.8 / 42.0, worst 52.9 | 33.9, worst 51.4 | 53.9, worst 82.5 (load 30 to 34) | walk `wall` |
| R on a brick in a wall, 15° step | in hand, down in 3 | the same | the same, 15.0° | the same | walk `turns` |
| a brick alone, 3 x R at 15° | 45° | 45° | 45° | 45° | walk `dialogs` |
| panels and dialogs | 22 of 24 | 22 of 24, 0.8 to 1.8 / 1.0 to 2.0 s | 22 of 24, 0.7 to 2.1 s; Compare and Pattern greyed (no save, nothing selected) | 22 of 24, 1.4 to 3.2 s | walk `dialogs` |
| search, 30 words | 27 | 27 | 27: the same three not first | the same | walk `search` |
| "1x4 brick", the first eight tiles | bricks only | bricks only | bricks only | the same | walk `wall` |
| three selected parts painted Red | 1 key | 1 key | 1 key | 1 key | walk `round2` |
| a 2 x 4 plate split, and merged back | 1 key each | 1 key each | 1 key each | the same | walk `round2` |
| a second view, the assistant open | F8 at both | **greyed** / 385 px | **F8: two views of 490 px**, the assistant folded to its tab ([picture](app_ux5/split_with_the_assistant_1280x720.webp)) | F8: 385 px | walk `round2` |
| a part to the last step | Shift+] a step at a time | Alt+T, the number, Return: 4 presses | 4 presses | 4 | walk `round3` |
| Render | a picture, a turntable, motions | and Building; Best path traced | the same | the same | walk `round3` |
| Settings' language | English | four | English, Deutsch, Français, Español | the same | walk `round3` |
| Like this on a 2 x 4 brick after a search for "1x4 brick" | | 2 clicks; no plate in the first twelve | **2 clicks; the box empty, Plate 2 x 4 seventh**, as on an empty search ([picture](app_ux5/like_this_after_a_search_1280x720.webp)) | 2 clicks; 16 tiles in sight | walk `round3` |
| the first build's offer, after building by hand | shown | shown | **gone** | gone | walk `round3` |
| the status bar, the car open, nothing selected | | | "61 bricks · stands up · 52 g": weight, no size | the same | walk `round4` |
| What's This (Shift+F1) on Move | | | 2 events: its words in a bubble, the tool unchanged ([picture](app_ux5/whats_this_1280x720.webp)) | the same | walk `round4` |
| a 2 x 4 brick in hand over the car | | | the status bar: "x −2, z 3 studs · 13¾ plates up" ([picture](app_ux5/place_in_hand_1280x720.webp)) | the same | walk `round4` |
| Cut away by a box | | one plane | 0.8 s; "2.4 × 5.6 studs, 9 plates high", Shrink, Grow, Ghost ([picture](app_ux5/cut_away_by_a_box_1280x720.webp)); no key for the box, the sphere or the cylinder | 1.3 s | walk `round4` |
| Pattern | a row, a ring, a path | the same | **and In a grid** | the same | walk `round3` |
| the parts list's shops | BrickLink, Rebrickable | the same | **and LEGO® Pick a Brick** ([picture](app_ux5/parts_list_shops_1280x720.webp)); no key for its File, Export row | the same | walk `round4` |
| File, Import, Into this model… | | | offered, no key | the same | walk `round4` |
| train tracks | laid by eye | the same | the same: no track ends (tracks is not merged) | the same | walk `round4` |

The search's three that are not first are the walk's own answers, as
before: "jumper" lists 3794b sixth after the newer 15573; "macaroni" lists
the macaroni tiles and bricks, where the walk wants a quarter tile (25269
is fourteenth); "bracket" has 99781 fourth. "1x2 plate", "round 1x1" and
"minifig head" list LDraw's renumbered part first (3023b, 6141, 3626c),
the part a builder means.

**Found on the way:**
- **Cut away's strip runs past the model's room** with Stress's panel, the
  bin and the assistant open. At 1400 x 900 its Ghost box is cut in half
  and its × lies under the assistant's column; at 1280 x 720 the × is
  half under the right-hand column's edge
  ([picture](app_ux5/cut_away_by_a_box_1280x720.webp)). K puts the model
  back and the status bar says so, but the strip's own button is out of
  reach. quiet narrowed the render queue to the model's room; the strip
  was not.
- **The three APP_UX4 found are gone** (quiet): the first build's offer
  after building by hand, the render queue over what opens after it
  (Settings is drawn over it at both sizes), and the laptop's lost second
  view.
- **Render still has no key** under any preset, nor the render queue, the
  three cut shapes, Into this model, the Pick a Brick list and the library:
  111 of 209 commands have none (walk `counts` and `round4` keys).
- **A probe writes into the owner's own folders.** Instructions saves the
  booklet in the person's Documents, as designed, and says where with Show
  in folder. `probe.sh` gives each run its own data folder but not its own
  Documents or Pictures, so the walk wrote `car_instructions.html` and
  `.pdf` into the owner's real Documents (deleted after), and the
  reference picture's dialog opened on their real Pictures. A tooling fix,
  not the app's.
- **Most runs imported again before they ran,** 9 to 17 s each under
  heavy, 9 of the 13: probes put their pictures under the checkout's
  `shots/`, which has no `.gdignore`, so the next run found unimported
  PNGs.
- The walk's Godot quit cleanly at 1280 x 720 (exit 0) and aborted at
  1400 x 900 ("double free or corruption", exit 134), after "WALK done":
  the lead's `quitabort`.
- The walk's own: Escape leaves Stress's panel and its colours up (Close
  puts them away, as a docked panel's does), so the car is drawn in
  Stress's colours in every picture after it; and the walk's Pattern
  section typed into the bin's search, so its picture is not Pattern's
  (`grid` checks Pattern).

**The web** (`load_check`, broadband, live, load 32 to 41):

| | appux3 (live rel-m224) | appux4 (live rel-m264, load 18 to 20) | now: live rel-m266 | from |
|---|---|---|---|---|
| first visit, cold, to working | 24.9 s | 13.1 s | **17.2 s** (19.1 and 15.3) | `load_check` |
| warm | 12.0 s | 8.0 s | **11.0 s** (12.8 and 9.1) | `load_check` |
| main thread, cold | 15.0 s | 7.4 s | 9.4 s | `load_check` |
| app ready (the scripts done), cold | 15.1 to 17.3 s | 7.8 to 9.0 s | 9.3 to 12.0 s | `load_check` |
| the scripts' compile, cold | | 3.1 s | 4.4 s | `load_check` |
| a part from the bin to its ghost | 2,064 and 1,695 ms | 1,572 and 278 cold, 214 and 219 warm | 1,538 and 552 cold, 551 and 431 warm | `load_check --pick` |
| bytes before working | 15.9 MB | 16.49 MB | 16.42 MB | `load_check` |
| a phone, 390 x 844: first frame, cold and warm | | | 19.9 s (16.6, 23.3) and 10.7 s (11.8, 9.7); the page shown at 25.5 and 14.4 | `load_check`, a phone's viewport |

Every stage is longer than APP_UX4's by about the load's own stretch (the
banner 5.2 s against 4.6, the compile 4.4 against 3.1) with the same
bytes, so these columns do not show a change in the app; only an ABBA at
equal load would. A13's bar (10 s cold, 4 s warm) is not met; the lead's
`leaves3` is on it. On a phone `load_check`'s "working" waits for the bin,
which a phone keeps behind a button, so its figure there is the first
frame.

## Over MCP: the walk's tasks as the owner's Claude does them

**The search** answers a session as the bin answers a person: the same
first part for all 31 words (the walk's and the session's compared), in 7
to 126 ms a word.

**APP_UX4's thirteen tasks, again:**

| task | APP_UX4: calls, time | now: calls, time | what the session did |
|---|---|---|---|
| clear, and a red wall of eight 1 x 4s, half a brick along | 2, 10 s | 2, 10 s | clear and `submit_design`; said the stepped ends |
| turn one brick of the top row 15° where it stands | 1, 13 s, refused | 1, 10 s, refused | both reasons; three ways offered; nothing changed |
| paint three bottom bricks blue | 1, 4 s | 1, 3 s | chose which three, and said so |
| a 2 x 4 plate, split into eight 1 x 1s | 3, 9 s | 3, 12 s | `split_parts`, then `look_at_model` |
| three 1 x 4 plates stacked, merged into a brick | 3, 7 s | **2**, 7 s | `merge_parts`; no look after it |
| a 3 x 6 wing, the left one, and its mirror image | 6, 19 s | **4**, 17 s | `mirror_parts` across x 13: 54384 to 54383 |
| a beam 7 standing, a pin in its second hole | 9, 57 s | 6, 30 s | **refused twice**: the beam tips on its rounded end. Before, the session added a footing it was not asked for; now it offered three and asked |
| the angle between the beam's holes and the wall | 0, 2 s | 0, 3 s | no beam to measure; 90° from the try, said as such |
| move the top row three steps later | 3, 12 s | 5, 17 s | `edit_steps` `next`, then `new`: the row two steps later, the last step, and why not three. APP_UX4's session used `op: "to"` in one call |
| render a picture | 2, 8 s | 2, 8 s | in the app's own folder |
| a side pod of five parts, in words | 9, 41 s | 8, 39 s | `attachment_points` once; slopes turned the wrong way, seen in the picture and turned |
| the pod's mirror image beside it | 3, 12 s | **2**, 16 s | `mirror_parts` with its picture: 41770a to 41769a |
| a 2 x 2 slope split into 1-wide slopes | 4, 10 s | **2**, 6 s | `split_parts`: two 3040b |

Thirteen tasks took **38 calls in 3.0 minutes** (APP_UX4: 46 in 3.4). No
picture was asked for after a hand tool: `split_parts`, `merge_parts` and
`mirror_parts` answer with theirs (seeing). Twice a session read the
parts' places in words after one (`look_at_model` after `split_parts` and
after `mirror_parts`). With round three's five the eighteen took 52
calls, the number seeing's own rerun found.

**Round three's own, in the second session:**

| task | APP_UX4 | now | what the session did |
|---|---|---|---|
| a short video of the model built up | 2, 46 s | 2, 43 s | `render_model {"kind": "build"}` and its job: 15 s, MP4 and WebP. **"I haven't watched it myself"** |
| parts like the headlight brick, three picked | 1, 12 s | 1, 13 s | `search_parts {"like": "4070"}`: 87087, 26604 and 3005, each with why |
| what step the window shows, the part in hand | 1, 3 s | 1, 3 s | `in_view`: no step, nothing in hand, nothing selected |
| the wing pulled out in the booklet, colour guides, the first page | 5, 11 s | 8, 22 s | `edit_booklet` pull with `parts: [3]`, its brick number, **accepted and drew nothing**; the session saw that on `booklet_page`, pulled it again by part id, and described pages 1 and 2 |
| a picture at the best quality, and how it was lit | 2, 13 s | 2, 17 s | Best with the product look: **"path traced with 256 samples per pixel"** |

**Round four's own, the same session** (the pods, then a block, a file,
a model in a model, and a track):

| task | calls, time | what the session did |
|---|---|---|
| the two pods from the front, the left and the top: true mirror images? | **1**, 13 s | `view_board` front, left and top, with `where`: yes, each part's place said against x = 4 |
| only the two headlight bricks picked out, the rest faded | **1**, 6 s | `view_board highlight=[5, 11]`; where each is |
| page 2 of the instructions as a person sees it | **1**, 8 s | `booklet_page {"page": 2}`: both steps, the pull's arrow, the colour guides, the progress bar; "from the drawing alone I can't tell which pod's wing is the floating one" |
| a 4 x 3 x 2 block of 2 x 2 bricks, each touching | **2**, 9 s | one brick, then `pattern_parts` 4, 3, 2: 24 bricks; said the columns do not lock |
| a Pick a Brick file, and what it could not include | **1**, 8 s | `export_model {"format": "pickabrick"}`: 8 lines for 36 pieces, none left out |
| save as Pods | 1, 5 s | `save_model`; said the 16 loose pieces |
| clear, a green 16 x 16 plate, Pods into it, whole, on the plate | 6, 13 s | `open_model {"into": true}` once: `Pods#1`, 36 parts, its 5 steps kept; checked and looked |
| how big, in studs and centimetres, and how heavy | **0**, 4 s | 16 x 16 studs, 7 plates; 12.8 x 12.8 x 2.2 cm, worked out; about 80 g from the check it had read. No tool says a model's size in centimetres |
| a closed oval of 9V track | 11, 101 s | 16 curves and 4 straights, 98 x 72 cm. **"Joined connector to connector, the app turned each piece 90° wrong"**, so it placed every piece by its own arithmetic and measured one joint, 0 mm apart |

Twenty-seven tasks took **76 calls in 7.4 minutes**. Every round-four tool
was found and used unprompted, in one call each: `view_board` with views,
`where` and `highlight`, `booklet_page`, `pattern_parts`, `export_model`
pickabrick and `open_model` into.

Where a session still needed more than the window, or guessed:
1. **It cannot watch a video it made.** `render_model` build answers with
   files; the session said it had not watched it. A person watches it.
2. **A booklet pull named by brick number is accepted and draws nothing.**
   `edit_booklet`'s pull takes part ids; `parts: [3]` became the id "3.0",
   matched nothing and was kept without a word (`app_tools.gd`
   `_booklet_extras`). The session found it only by looking at the page.
3. **Train tracks joined by `attach` turn 90° wrong.** Eleven calls and
   arithmetic for an oval; the tracks unit's bar is three calls.
4. **No tool says a model's size,** in studs or centimetres, as Studio's
   Model Info does; the session worked it out from what it had built.
5. **Nothing shows which way studs point.** A session reads one part's
   facing in words; the design records say its misplacements sit "on real
   studs, wrong ones" (follower), and ldraw-xray's agents get a stud map.

## Round four, item by item

| unit | its bar | where it stands on `pre261` today | proof |
|---|---|---|---|
| seeing | six views in 1 call; highlight; x-ray; a step; a booklet page; hand tools answer with a picture; Best says how it was drawn | **met**, 30 checks, none failed, at 1400 x 900: six views in 1 call, 1.1 s, each within 0.0003 of `view_model`'s; three parts' rings 100% magenta, the 21 others at 19% at most; the seat through the roof, 33,594 px. Over MCP: the pods from three sides in 1 call, two parts picked out in 1, page 2 read in 1; no picture asked for after a hand tool; Best "path traced with 256 samples" | `seeing` today; MCP walk |
| likewords | after a search, Like this lists what it lists on an empty one; no two tiles one mould; words typed narrow it | **met**, 27 checks, none failed, at 1280 x 720: after "1x4 brick" and four bricks, Like this starts with the box empty, Plate 2 x 4 seventh, the first twelve as on an empty search, no two one mould; "curved" gives 54 tiles, every one curved and like the brick. The walk saw the same at both sizes | `likewords` today; walk |
| intomodel | a saved model into this one in 2 actions, every part to the LDU, its steps kept, one undo, 1 call over MCP | **met**, 53 checks, none failed, at 1280 x 720: the gatehouse in 2 actions as `Gatehouse#1`, 0.0000 LDU off, its 5 steps kept, one Ctrl+Z; over MCP Pods went into a new model in 1 call with its 5 steps. The three losses imreview found after (a sub-model shown only by its copies, parts not in the library, ROTSTEP and author lines) are intomodel2's, running, and not in this snapshot | `intomodel` today; MCP walk |
| picklist | the car's Pick a Brick list; 400-line files; BrickLink's condition, list and notify | **met**, 43 checks, none failed, at 1280 x 720: 31 lines for the 59 of 61 pieces with an element, the windscreen named; the parts list's button the same; over MCP the pods' file in 1 call, none left out | `picklist` today; MCP walk |
| tracks | a curve joins a straight in 1 drag; sixteen curves close a circle; an oval by a session in 3 calls | **not merged**; running. Today's baseline: the walk finds no track ends; a session took **11 calls** and placed each piece by arithmetic, `attach` turning them 90° wrong | walk; MCP walk |
| grid | 4 x 3 x 2 in one dialog, each to the LDU, one undo, refused with where; 1 call over MCP | **met**, 40 checks, none failed, at 1400 x 900: 24 bricks in 15 actions, one step to undo, a brick in the way refused with where; over MCP the block in 2 calls (a brick, then `pattern_parts`) | `grid` today; MCP walk |
| partbypart | a step of five parts in five taps, one new part each; Back undoes one; targets 44 points | **met**, 48 checks on a phone's 390 x 844 and 48 on a tablet's 1024 x 768, none failed: each tap one part in its own colour with "k of 5"; the smallest target One part's 92 x 44 points, Next 216 x 61 | `partbypart` today |
| cutshapes | a box shows the seats; only pixels inside its outline change; no inside face; kept over a save; Render and the booklet whole | **met**, 44 checks and `cutshapes_kept`'s 33, none failed, at 1400 x 900: 56,413 pixels inside the box's outline changed, 0 further out (the drum and the ball the same); 1,333 px of filled faces, 0 of an inside face; each shape one line in the file and back where it was | `cutshapes`, `cutshapes_kept` today |
| quiet | the offer goes after 3 parts by hand; the render queue under every dialog and closed by Escape; Split at 1280 with the assistant | **met**, 41 checks, none failed, at 1280 x 720: the offer stays for parts 1 and 2 and goes at the 3rd; Split two views of 450 and 451 points with Stress and the assistant open. The walk: no offer at either size, F8 at 1280 | `quiet` today; walk |
| whatsthis | every control answers with words of its own; the click does nothing else; the status bar says where the part lands | **met**, 34 checks, none failed, at 1280 x 720: 33 toolbar buttons, 100 bin chips, 28 panel buttons and 7 fields each answered; four placements read off the bar to the stud and plate | `whatsthis` today; walk |

**Built since round four's plan, beyond it:** the lead's `keys` (a key for
find, replace, simulate, motions and more: 98 of 209 commands have one,
live rel-m266); `bintiles` (the bin's frame a keystroke 12 to 43 ms);
`partsbox` (parts told apart turned over in a booklet's parts box, live
rel-m266); `rotroll` (the booklet keeps an author's ROTSTEP roll and turns
a step over when its parts go on from below).

**Round four's "Next, once those land",** where each stands:
- **Keys** for the 114: the lead's `keys` gave 11 more; 111 of 209 still
  have none, Render among them (unit keys2 below).
- **Orthanc's three** (suggest sections, replace, hidden colours): not
  measured again here; carried.
- **A link that plays a motion** (Kinebrick Play): not built (playlink).
- **Thumbnails in the file manager** (StudWorx): not built (thumbs; the
  Mac's part parked).
- **A part from an OBJ or STL with its connectors, an originality score,
  vector booklets, STEP import, gamepads:** not built; carried, unranked.

## What the field does that Brickworks does not, yet

The latest versions, as of 6 November 2026:
- **Studio 2.26.10_1** (27 October), unchanged. Its help centre has no
  article newer than 25 September. bricklink.com was offline for
  maintenance again today, so its gallery and wanted-list pages could not
  be read.
- **LeoCAD 26.09**, and a continuous build of 5 November.
- **StudWorx**: its one release, 5 November.
- **LDCad 1.7 Beta 2b**; Beta 2c announced on 3 November, not out.
  **Bricksmith 3.1** (2022). **Mecabricks**: no versions; its forum
  answered 503 today.
- Phone apps: LEGO Builder 4.3.11 and Brickit 5.8.0, bug fixes; **BUF3D**
  is now two apps, Lite and + (2 November).
- AI and agent tools: ldraw-xray 0.5.0 (2 November); LDraw Nova 0.6.0
  (flexible parts, 22 October); Brickforge 0.3.0-beta.12; Emmet's photo
  to model (5 November); ldraw-mcp 0.3.1; **bricky** 0.1.0 (30 October)
  and **LEGO from my bricks** (November), new; BrickWright, a paper of 22
  October from BrickGPT's authors.

Each list is ranked by how much a person building would feel it, and was
checked against `shell.gd`'s commands, `tools/mcp_tools.json` and the files
named.

**Studio** (its help pages; nothing new in them since APP_UX4, but not
covered before)
1. **The booklet's page set up.** Page size, orientation and margins; a
   page colour or a picture behind every page; lines between rows and
   columns; a "Global Style" of fonts and numbers saved and used again.
   StudWorx has page presets, units, margins and orientation too.
   Brickworks' page is fixed at 269 x 199 mm landscape
   (`booklet_pdf.gd:18`), its colour a constant (`booklet_maker.gd`'s
   `PAGE_COLOUR`), and `BookletLooks` keeps none of these.
2. **The model's size:** Model Info's physical information gives the
   smallest box round the model in several units and an estimated weight;
   the status line gives the selection's size in studs. Brickworks' status
   bar has the weight ("61 bricks · stands up · 52 g", COMPETITIVE's
   row is right) and no size; `look_at_model` gives a span over MCP only.
   APP_UX2 cited the article and listed no gap.
3. **Eyesight's glowing colours and presets:** Glowing Neon, Luminous and
   Glow in Dark drawn as light, with the ambient lowered; background,
   light and camera presets saved by name; UV yellowing and scratches.
   No Brickworks plastic emits (no `emission` in any part shader), and
   Render keeps no preset.
4. Smaller: up to four viewports (Brickworks: two); a wanted list
   imported "with quantity" as a palette whose counts fall as parts are
   used (Brickworks' counted bin comes from a set or the sets owned);
   Sketchfab, POV-Ray and LXFML exports.

**LeoCAD, its commits since APP_UX4**
1. **Train tracks reworked** on 2 and 3 November: ends chosen and joined
   by their connection points. The tracks unit's reference.
2. **A trackpad's twist turns the view** (29 October). Brickworks reads
   the trackpad's pan and pinch (`cad_camera.gd`), not a twist.
3. Smaller: keyboard turns keep their axes over repeated turns; LDraw
   files offered to the system on install; a selection outline that fills
   what is hidden behind.

**StudWorx** (its release of 5 November and FEATURES.md)
1. **Lights in the model:** point, spot, directional and area lights,
   placed and kept with it, and cameras kept in the model with switching
   between them. Brickworks' light is the studio or an HDRI
   (`render_settings.gd`); no light is placed, no view is kept.
2. **Animated GIF** of a turntable, the steps or a pose. Brickworks writes
   animated WebP and MP4.
3. **Exploded view** with a spread in per cent, anchors, connection lines
   and a saved copy. Brickworks' Shift+Y spreads the sections a fixed way.

**LEGO Builder** (App Store, 4.3.11)
1. **Build Together:** several people, each on their own phone, join one
   model by a PIN, split its building and finish it together. Brickworks'
   Build together… is live designing in the CAD; Build it plays one
   device's steps.

**AI, MCP and web tools**
1. **A photo of a pile of loose bricks becomes the collection.** LEGO from
   my bricks reads every part in a pile photo into the inventory (add or
   replace, with an undo), then lists what can be built now and what is
   close, with the missing parts; BricksChat's page offers "a photo of a
   shelf or pile of bricks". Brickworks' My collection takes a Rebrickable
   account, a CSV, a BrickLink XML or set numbers
   (`collection_dialog.gd`); a photo finds one part at a time in the bin
   (Brickognize), and nothing adds a loose part to the collection, by hand
   or over MCP.
2. **A stud map:** ldraw-xray colours every part by where its studs point,
   with a legend, as a render or a board. Brickworks' Properties says one
   part's facing; `view_board` takes `views`, `where`, `highlight`,
   `xray` and `step`.
3. **Pictures beyond seeing:** slices at depths and a hinge drawn at
   several angles (ldraw-xray's cutaway and pivot boards); selectors by
   part number, colour and step (`part:3001*`, `colour:`, `step:`);
   check findings tinted and labelled in the same answer (bricky;
   BrickWright's "highlight colliding bricks"). Brickworks' `check_design`
   answers in words, and `highlight=` takes the bricks' own numbers.
4. **The model in a room or a headset:** brckd's AR viewer and shared AR;
   LDraw Nova on a Quest 3. Brickworks' model page has View in 3D; its GLB
   export works in AR viewers, but nothing opens one.
5. Smaller: how to take a model apart, a reverse booklet (LEGO from my
   bricks); BUF3D's sun that moves its shadows, meshes that thin with
   distance, and a library from your own LDraw ZIP.

Checked and **not gaps:** BrickMedic's "what comes loose if I remove this"
(`check_design edit=` and `weakest_joints`); Emmet's "fix it" from a check
(Stress's Ask Claude to brace this); LDraw Nova's glTF with part data (our
GLB's `extras`); designing from what you own (`Collection.owned_first`,
brickify `collection=true`); BUF3D's part at a time (partbypart); StudWorx's
poses (Motions); a photo beside the model (Reference picture…). Brick
Basket and BrickMine3D still refuse readers. Rebrickable's changelog
refuses readers too, and its blog has no tool news this year.

**SOCIAL.md's and ROADMAP.md's open rows a unit could move**
- **Build it does not turn the model the way its booklet now does**
  (ROADMAP 7, rotroll: "The step player still does not roll"). The booklet
  keeps an author's ROTSTEP roll and turns a step over when its parts go
  on from below (`booklet_maker.gd`'s `_turn_over`); Build it looks from
  the turn's direction with the camera upright (`build_steps.gd`'s
  `view`, `main.gd`'s `look_from`), so its page and the booklet's differ
  where it matters most.
- **Real joints' last refusals** (ROADMAP 4): 957 of 1,056 real
  sub-models pass; 4595's side studs, the 60608 and 86210 panes' pins,
  4346's doors and 3710 under 2582's lip each need the parts pipeline and
  a catalogue rebuild. After `telescope`, on the same code.
- **The moulded animals' last four** (the lead's plan status): 59 of 63
  go on by hand; the scorpion's tube and a wolf 4 LDU off its studs, and
  saddles 1 LDU low.
- **Make a part's next families** (ROADMAP): clips and bars, wedge
  plates, round cut-outs (`element_maker.gd` lists brick, slope, inverted,
  round, curved, bracket and technic).
- **SOCIAL's tails,** low while the gallery has one designer: /builds
  cards load the whole kept photo (up to 2,048 px); Based on by searching
  a set's name; @ suggestions from any profile; More like this on a
  person's own page.
- Measurements, not units: blackedges again now the parts box shows the
  dome; a modern LEGO booklet built the same way; ROADMAP 5's parts used
  together (a design bench round).

## The gaps, by value to a person building

1. **The web's first visit,** still over A13's bar: 17.2 s cold and 11.0
   warm on live at twice APP_UX4's load, against 10 and 4. The lead's
   `leaves3` is on it. Carried, not planned again here.
2. **Build it and its booklet turn the model differently.** A person on a
   phone following Build it sees a step that goes on underneath from
   above, where the booklet now turns the model over. Build it is how
   most people build from a phone.
3. **A collection is sets and lists only.** Most people own a tub of
   loose bricks, not a Rebrickable inventory, and What can I build?,
   Parts you own, brickify from the collection and the gallery's "owned"
   sort all start from it.
4. **A session sees parts, not how they join,** nor its own video; a
   booklet pull by brick number fails without a word. The owner builds
   through their own Claude; the follower record names the builder's eyes
   as the next lever.
5. **The booklet's page is one size and one colour.** A person printing
   on A4 or Letter in portrait, or sharing instructions in their own
   style, cannot (Studio, StudWorx).
6. **Building one model together on several phones** (LEGO Builder):
   families and classes build this way.
7. **The model's size** is nowhere, in the window or over MCP: "will it
   fit the shelf" (Studio's Model Info).
8. **No light in a scene, no colour that glows:** night scenes and lit
   windows are common gallery renders (StudWorx, Studio).
9. **No saved views or render presets:** the same angles are set up
   again after every change (StudWorx, Studio).
10. **Render and 110 more commands have no key.**
11. Smaller: a link that plays a motion; Cut away's strip past the
    model's room; thumbnails in the file manager; the model in a room
    (AR); real joints' last refusals; the moulded animals' last four;
    SOCIAL's tails; a trackpad's twist; GIF; an exploded view's spread;
    four viewports; a wanted list as a counted bin; a reverse booklet;
    Make a part's next families.

## The units

Sixteen, ranked, each its own worktree off the next stage. These are
registries, as `tools/suite/*.txt` is, and a unit adds its own lines there,
in a block of its own, and changes no one else's:
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
commit. None of the sixteen needs the owner.

| # | unit | gap | size | risk | files it owns | bar a probe checks |
|---|---|---|---|---|---|---|
| 1 | **buildturn** | 2 | M | medium | `src/assembly/build_steps.gd`'s `view`; `main.gd`'s Build it view (where it calls `look_from`); `src/camera/cad_camera.gd`'s `look_from` (an up as well as a direction); new `src/dev/buildturn_probe.gd`. Reads `BookletLooks` and `BookletMaker`, edits neither | see below |
| 2 | **mybricks** | 3 | M | medium | `src/ui/collection_dialog.gd`; `src/collection/collection.gd`, `collection_store.gd`; `api/collection.js` (loose lots, additive only); new `src/dev/mybricks_probe.gd` and its API test | see below |
| 3 | **seeing2** | 4 | M | low | `src/net/see_tools.gd`; `src/ai/model_shot.gd`; `app_tools.gd`'s `_booklet_extras` and the render jobs' answers, a block of its own; new `src/ui/stud_map.gd`; new `src/dev/seeing2_probe.gd` | see below |
| 4 | **pagesetup** | 5 | M | medium | `src/render/booklet_pdf.gd`, `booklet_maker.gd`'s page, `booklet_png.gd`; `src/assembly/booklet_looks.gd`; `app_tools.gd`'s `_booklet_layout`; new `src/dev/pagesetup_probe.gd` | see below |
| 5 | **buildparty** | 6 | L | medium | `src/ui/share_view.gd`; `src/ui/build_mode.gd`; `src/net/together.gd` and `api/together.js`, a block of their own; new `src/dev/buildparty_probe.gd` and a two-phone web flow | see below |
| 6 | **modelinfo** | 7 | S | low | `src/ui/status_bar.gd`'s counts; `src/ui/inspector.gd`'s nothing-selected page; `in_view`'s answer in `app_tools.gd`, a block of its own; new `src/dev/modelinfo_probe.gd` | the car's width, depth and height on the status bar, in studs and plates and in centimetres, within 0.1 mm of its parts' bounds; with parts selected, the selection's size; current within a frame of an edit; nothing cut at 1280 x 720 with every column open; Properties with nothing selected says size and weight; `in_view` says the size in centimetres and the weight; `whatsthis`, `roomfit` and `languages` pass |
| 7 | **lights** | 8 | L | medium | new `src/assembly/scene_lights.gd` (lights kept as `0 !BRICKWORKS LIGHT` lines, as `cut_shape.gd` keeps its cut); `src/render/studio_render.gd`, `path_tracer.gd` and `.glsl`; the plastic shaders' emission; the light in `src/render/render_settings.gd` and `src/ui/render_dialog.gd`; new `src/dev/lights_probe.gd` | a spot light over the car: inside its cone the lit side brighter by a set amount, outside it 0 px changed, rasterised and path traced; a 1 x 1 brick in Trans Neon Green in a dark scene lights the parts round it; kept over a save and an open, and `pre261` opens the file whole, its light lines left alone; `pathtrace`, `render`, `true_colour` pass |
| 8 | **savedviews** | 9 | M | low | new `src/ui/saved_views.gd` (views kept as `0 !BRICKWORKS VIEW` lines; the camera through its own calls, `cad_camera.gd` not edited); `src/ui/render_queue.gd`; Render's presets in `src/render/render_settings.gd` and `src/ui/render_dialog.gd`; new `src/dev/savedviews_probe.gd` | three views saved, the model closed and opened: each back within 0.1° and 0.1 LDU; a key each, none taken from another command; a queued render of each draws exactly that view; a render preset saved and chosen again in 2 actions; `view_model {"view": NAME}` and `render_model {"view": NAME}` in 1 call; `pre261` opens the file whole; `pathtrace`, `store` pass |
| 9 | **keys2** | 10 | S | low | `src/ui/keymap.gd`'s `PRESET_KEYS`, a block of its own; the keys page; new `src/dev/keys2_probe.gd` | Render, the render queue, Cut away by a box, a sphere and a cylinder, Into this model…, the Pick a Brick list and the library each have a key under all four presets, none taken from a command that has one; each key does what its menu row does; walk `counts` 98 to 106 or more; `keys4`, `languages` pass |
| 10 | **playlink** | 11 | S | low | `src/ui/share_view.gd`'s opening; the share dialog's Open playing; `api/_viewer_page.js`; new `src/dev/playlink_probe.gd` | a link with `?motion=boom` to a model with that motion opens with it playing within 2 s of the model shown, its parts' angle changing frame to frame, looping; an unknown name opens still and says so; `share_view`, `motions` pass; a web flow on the preview |
| 11 | **striproom** | 11 | S | low | `src/ui/see_inside.gd`'s strip; new `src/dev/striproom_probe.gd` | Cut away's strip inside the model's room, every button in sight and reachable, at 1280 x 720 and 1400 x 900 with Stress, the bin and the assistant open (it wraps, or narrows as the render queue does); `cutshapes`, `quiet` pass |
| 12 | **thumbs** | 11 | M | medium | the Linux package's thumbnailer entry and `tools/release/`'s Linux packaging; a small headless picture command (`--thumbnail IN OUT`) | `.ldr`, `.mpd` and `.io` drawn as a 256 px picture by the installed thumbnailer in 3 s or less, each the model's corner view; a file with parts not in the library still drawn. Windows' thumbnail provider next; the Mac's parked |
| 13 | **arview** | 11 | M | low | the model page's View in 3D (`api/share.js`, `web/`); `<model-viewer>` loaded on a tap only | on a phone the model page offers In your room, its GLB the one Export writes, under a set size; on a desktop it is not offered; the page's first load no heavier |
| 14 | **realjoints3** | 11 | L | high | the parts pipeline (`tools/`), `catalogue.json` rebuilt (the 90-minute mesh build, then `refresh_catalogue`); after `telescope` | the real sub-models from 957 to 963 or more, none newly refused; each named pair placed by hand (`technic_hand_probe`) and over MCP |
| 15 | **animals** | 11 | S | low | the moulded animals' connectors in the parts pipeline | 63 of 63 by hand; every saddle seated at 0 LDU |
| 16 | **socialtails** | 11 | M | low | `api/` and `web/` for /builds, Based on and the profile | /builds cards 480 px wide or less; Based on finds 7140 by its name; `based_on_flow` passes |

**Which can run at once.** buildturn and savedviews meet at the camera:
savedviews uses `cad_camera.gd`'s own calls and edits nothing there, or it
waits for buildturn. buildparty and playlink both open `share_view.gd`, so
one waits for the other. lights and savedviews both reach Render's
settings (`render_settings.gd`, `render_dialog.gd`), so one waits.
seeing2 and pagesetup both edit `app_tools.gd`, in different functions
(`_booklet_extras`, `_booklet_layout`): they can run at once, the second
to merge rebased on the first. pagesetup owns `booklet_looks.gd`; buildturn
only reads it. modelinfo's `in_view` answer and mybricks' tool sit in
`app_tools.gd` too, each in a block of its own beside the registries.
arview and socialtails both edit the site's pages (`api/share.js`), so
one waits. realjoints3 and animals both rebuild the catalogue: one at a
time, after `telescope`. The rest share nothing: buildturn, mybricks,
seeing2, modelinfo and keys2 can all run at once.

**1. buildturn: Build it turns the model as its booklet does.**
- **Change.** Build it's view of a page takes the booklet page's whole
  turn: an author's ROTSTEP with its roll, and the model turned over at a
  step whose parts go on from below, upright again after, as
  `BookletMaker` draws the page. The camera looks from the turn with the
  turn's up, so a turned-over step is seen from under; a drag still turns
  the view from there, and leaving Build it puts the model upright. The
  same in the web's viewer, which is the same code.
- **Bar** (`buildturn_probe`, on a phone's 390 x 844 and at 1280 x 720):
  - on the sports car and every one of the 44 files with authored
    ROTSTEPs, each page's view direction and up within 1° of the booklet
    page's;
  - the sports car's step 6 shown turned over, its new parts in sight at
    least as much as on the booklet's page (pixels of those parts);
  - a page with no turn unchanged (0° from today);
  - a drag on a turned page turns the view, and Next after it goes to
    the next page's own turn;
  - `partbypart`, `viewer_steps`, `step_link`, `build_steps` and
    `share_view` pass.

**2. mybricks: the bricks a person owns, loose.**
- **Change.**
  - My collection's What I own takes loose parts: a part chosen from the
    bin's search, from Like this, or from a photo of one part (the bin's
    Brickognize), with a colour and a count, in one row; listed under
    Loose parts, apart from the sets; each lot changed or taken out by
    itself.
  - Over MCP, `edit_collection {"add": [{part, color, count}], "remove":
    [...]}` and its read back, so a person's own Claude can look at a
    photo of their pile with its own eyes and add what it sees. Every lot
    a session adds is marked as its, listed for the person, and one "Take
    back what Claude added" removes exactly those.
  - The account's copy (`api/collection.js`) takes loose lots as it takes
    a BrickLink XML's; Supabase additive only.
- **Bar** (`mybricks_probe` and its API test):
  - 12 loose lots added by hand, each in 3 actions or fewer (search or a
    photo, a count, Add), listed under Loose parts;
  - What do I need? for the car falls by exactly those lots, and What
    can I build? puts a model made only of them at 100%;
  - over MCP the same 12 in 1 call, read back by `parts_list
    which="need"` in 1 call; Take back removes exactly those 12;
  - kept over a restart and over a sign-in on another device;
  - a collection made before (sets, an XML, a CSV) **unchanged lot for
    lot** through all of it; Start over still asks first;
  - `collection`, `inventory`, `mcp_sync` and `mcp` pass;
  - then a real session given a photo of ten loose parts, its lots
    counted against the photo's (said, not gated: a session's eyes vary).

**3. seeing2: a session sees how parts join, and what it made.**
- **Change.**
  - `view_board {"studs": true}`: every part coloured by where its studs
    point (up, down and the four sides), a legend in the picture; View,
    Stud directions shows the same in the window.
  - `highlight=` and `xray=` take part numbers ("3024"), colours ("red")
    and a step ("step:3") as well as the bricks' own numbers.
  - `render_model` build and `render_motion` answer with six frames of
    what they made, in one picture.
  - `check_design`'s answer pictures the parts its findings name,
    highlighted.
  - `edit_booklet`'s pull takes the step's brick numbers as well as part
    ids, and refuses a part not in the step, naming the step's parts.
- **Bar** (`seeing2_probe`, the tools called as a session calls them):
  - the car's stud map in 1 call: each part's colour that of its studs'
    facing, 61 of 61, read off the picture's parts; the window's view the
    same;
  - `highlight="3024"` picks out exactly the car's eight 1 x 1 plates;
    `highlight="step:3"` exactly step 3's parts;
  - the build video answered with six frames, the last the whole model;
  - a finding's parts magenta in `check_design`'s picture;
  - `pull {"parts": [3]}`, brick 3 in the step, pulls it; a part id not in
    the step is refused with the step's parts, nothing changed;
  - `seeing`, `mcp_sync`, `mcp`, `read_only` and `booklet3` pass;
  - then the MCP walk's 27 tasks rerun (said, not gated).

**4. pagesetup: the booklet's page, the person's way.**
- **Change.** Instructions' Page setup: size (the booklet's own 269 x 199,
  A4, US Letter, A5), portrait or landscape, margins; a page colour or a
  picture behind every page; the step number's and the parts box's sizes;
  kept with the model, and saved by a name to use on another model.
  `booklet_layout {"page": {...}}` over MCP.
- **Bar** (`pagesetup_probe`):
  - A4 portrait: the PDF's pages 210 x 297 mm within 0.5 mm, every step on
    a page, each step's picture inside its page's margins; the 4-long
    axle's 1:1 guide still 32.0 mm within 0.2;
  - US Letter landscape the same at 279.4 x 215.9 mm;
  - a page colour read back off the PNG page;
  - a style saved, then given to the gatehouse in 2 actions: the same
    size, colour and number size;
  - kept over a save and an open; the default page unchanged to the pixel;
  - over MCP in 1 call;
  - `booklet_pdf`, `booklet3`, `booklet_edit` and `instructions` pass.

**5. buildparty: one model, several phones.**
- **Change.** Build it, Build together: the share link's player gives a
  short code; up to four phones join by it; the model's sub-assemblies, or
  its steps in runs, are dealt out one each; each phone builds its own
  part by part, everyone sees each other's progress (each phone's name and
  "4 of 9"), and
  the step that joins them is shown to all once each is done. Through
  together's relay; no account needed to join.
- **Bar** (`buildparty_probe` and a two-phone web flow at 390 x 844):
  - two phones join one link in 2 actions each;
  - the car dealt so each phone's steps hold only its own parts, all 61
    once between them;
  - a part done on one shows on the other within 2 s;
  - the joining step shown to both when both are done;
  - one phone leaving and joining again keeps its place;
  - `share_view`, `partbypart` and `together` pass.

## The top ten, by value to a person building

1. **buildturn:** Build it turns the model as its booklet does.
   Measured: each page's view against the booklet page's, within 1°, on
   the sports car and the 44 files with authored turns.
2. **mybricks:** loose bricks in the collection, by hand, by a part's
   photo, and over MCP from a photo of a pile. Measured: 12 lots in 3
   actions each and in 1 call; What do I need? and What can I build?
   change by exactly them; an older collection unchanged lot for lot.
3. **seeing2:** a session sees stud directions, its own video, its
   check's findings; a pull by brick number works or is refused.
   Measured: the car's stud map 61 of 61 right in 1 call; selectors pick
   exactly their parts; six frames of the video.
4. **pagesetup:** the booklet on A4, Letter or A5, either way up, in the
   person's colours. Measured: the PDF's page in millimetres, every step
   inside its margins, the 1:1 guide still 32.0 mm.
5. **buildparty:** several phones build one model together. Measured:
   two phones, the car dealt between them, all 61 once, progress across in
   2 s.
6. **modelinfo:** the model's size in studs and centimetres. Measured:
   within 0.1 mm of its bounds, in the window and over MCP.
7. **lights:** lights in the scene and colours that glow. Measured: the
   lit side brighter inside the cone and 0 px changed outside, both ways
   of drawing.
8. **savedviews:** views and render presets kept with the model.
   Measured: each view back within 0.1° and 0.1 LDU; a queued render of
   each the view itself.
9. **keys2:** a key for Render, the render queue, the cut shapes, Into
   this model, the Pick a Brick list and the library. Measured: walk
   `counts` 106 or more of 209; each key does its menu row's command.
10. **playlink:** a link that opens with a motion playing. Measured: the
    motion's angle changing within 2 s of the model shown.

Above all ten, and not planned here: the web's first visit (A13), which
the lead's `leaves3` is on, and round four's tracks and intomodel2,
running.

**Next, once those land:**
- striproom, thumbs (Linux first), arview, realjoints3 after `telescope`,
  animals, socialtails: ranked 11 to 16 above.
- **Tooling, for the lead:** `probe.sh` gives each run its own Documents
  and Pictures (`XDG_CONFIG_HOME` with its own `user-dirs.dirs`), so no
  probe writes the owner's folders; a `.gdignore` in `shots/`, so a
  probe's pictures do not make the next probe import again.
- A trackpad's and a phone's twist turning the view (LeoCAD); animated GIF
  (StudWorx); an exploded view's spread (StudWorx); four viewports
  (Studio); a wanted list as a counted bin (Studio); a reverse booklet;
  Make a part's clips, bars and wedge plates; Orthanc's three, measured
  again at a quiet hour; and round four's carried: a part from an OBJ with
  its connectors, an originality score, vector booklets, STEP import,
  gamepads.
- **Parked, needing the owner:** bricklink (BrickLink's keys and terms),
  studioside (Studio's install), 3Dconnexion (the device), the Mac's
  thumbnails (the Developer ID), payments and live prices, the Claude
  directory's submission, and tests on other AIs. None is ranked above.
- **Out on purpose:** a collision switch; more languages; a second look
  for the app, until the owner asks; the LEGO logo on studs
  ([TRADEMARKS.md](TRADEMARKS.md), 3).

## Sources

Brickworks' own figures are from the runs above: the walk's logs and
pictures, the probes' logs, the web's and the MCP sessions' streams, in
`bench/results/appux5-2026-11-06/` (`walk/`, `probes/`, `web/`, `mcp/`),
and the MCP walk's prompts and calls ([app_ux5/mcp_walk/](app_ux5/mcp_walk/)).
The field's, beyond APP_UX2's to APP_UX4's Sources:
- Studio's help centre, newest articles: <https://studiohelp.bricklink.com/api/v2/help_center/en-us/articles.json?sort_by=created_at&sort_order=desc>
- Studio, Page Setup: <https://studiohelp.bricklink.com/hc/en-us/articles/5627444093335-Page-Setup>
- Studio, background colour, background image and line separator: <https://studiohelp.bricklink.com/hc/en-us/articles/6476675846295-Background-color-background-image-and-line-separator>
- Studio, Global Style Preset: <https://studiohelp.bricklink.com/hc/en-us/articles/5627392706199-Global-Style-Preset>
- Studio, model dimensions: <https://studiohelp.bricklink.com/hc/en-us/articles/8117822782103-Model-dimensions>
- Studio, Render (glowing colours): <https://studiohelp.bricklink.com/hc/en-us/articles/5705001957399-Render>
- Studio, Photoreal Eyesight options: <https://studiohelp.bricklink.com/hc/en-us/articles/6505772624023-Photoreal-Eyesight-options>
- Studio, viewports: <https://studiohelp.bricklink.com/hc/en-us/articles/5409213150487>
- Studio, a wanted list as a palette: <https://studiohelp.bricklink.com/hc/en-us/articles/6483161921303>
- Studio, exports: <https://studiohelp.bricklink.com/hc/en-us/articles/6502197862679>
- Studio's winget releases: <https://github.com/microsoft/winget-pkgs/pulls?q=is%3Apr+BrickLink.Studio>
- LeoCAD releases and commits: <https://github.com/leozide/leocad/releases>, <https://github.com/leozide/leocad/commits/master>
- StudWorx features and release: <https://github.com/nathaneltitane/studworx/blob/main/FEATURES.md>, <https://github.com/nathaneltitane/studworx/releases>
- LDCad 1.7 Beta 2c announced: <https://forums.ldraw.org/printthread.php?tid=29440>
- LEGO Builder (Build Together): <https://apps.apple.com/us/app/lego-builder/id1486159728>
- Brickit: <https://apps.apple.com/us/app/brickit-app/id1477221636>
- brckd: <https://apps.apple.com/us/app/id6761261733>
- BUF3D: <https://forums.ldraw.org/printthread.php?tid=29692>
- LEGO from my bricks: <https://github.com/elcodabra/lego-build-inventory>
- BricksChat: <https://brickschat.com/>
- ldraw-xray: <https://github.com/anteloc/ldraw-xray>
- LDraw Nova: <https://github.com/anteloc/ldraw-nova/commits/master>
- bricky: <https://github.com/maxencefaldor/bricky>
- BrickWright: <https://arxiv.org/abs/2610.31651>, <https://avalovelace1.github.io/brickwright/>
- Emmet: <https://github.com/barrymortenson/emmet/commits/main>
- ldraw-mcp: <https://raw.githubusercontent.com/musharna/ldraw-mcp/main/CHANGELOG.md>
- Kinebrick Play: <https://github.com/erik-larsen/kinebrick/commits/main>
- Pick a Brick's saved lists: <https://brickset.com/article/133221>
- Rebrickable: <https://rebrickable.com/blog/959/rebrickable-turns-15/>
- Mecabricks' forum: <https://www.mecabricks.com/en/forum>
