# The app's UI/UX and advanced features: what to change, ranked

Written 2026-10-30 by appux371 against `main` at `1699520f`. The owner asked
to "continue working on advanced features of the app and improving its
UI/UX", with the standing bar that Brickworks beats every competitor on every
feature it has, and is an expert CAD first and an AI second.

This file is the view from a person building a model by hand: what they repeat
all day, how long it takes, and where the best tools do it better.
[COMPETITIVE.md](COMPETITIVE.md) is the feature matrix against the field and is
not repeated here. [CADTASK.md](CADTASK.md) measures building real sets
through the interface. [ROADMAP.md](ROADMAP.md) is the designer's quality
loop, which this file leaves alone, as it does the bench.

## How it was made

- **The app, driven as a person drives it.** Windowed Godot on the GPU
  (`gpu`), every act an input event against the real scene, at 1400 x 900
  and 1280 x 720:
  - `handbuild_probe`, which passed whole;
  - `cadtask_frames` on the car and Orthanc;
  - `command_probe`: every command in the shell's table, timed on the car and
    on Orthanc's 10,105 parts;
  - a walk written for this audit, [app_ux/appux_walk.gd](app_ux/appux_walk.gd).
    It opens every menu, runs 30 searches a builder types, builds a wall from
    the bin, turns a part, and opens 25 panels and dialogs.
  - The pictures are in `shots/appux/` and `shots/handbuild/` (git-ignored);
    the ones cited here are in [app_ux/](app_ux/).
- **The live web app,** in Chromium on SwiftShader: `load_check.mjs`, signed in
  as the tests' throwaway account, on 20 Mbps.
- **The field,** from help pages, release notes and forums (Sources, at the
  end): BrickLink Studio 2.26, Mecabricks, LDCad 1.7, LeoCAD 26.09, and the
  general tools whose habits people bring: Figma, Blender, Onshape, Fusion and
  SketchUp.
- **Not run here:**
  - The assistant, which spends money. Its panel was opened, and nothing was
    designed.
  - The connector, and undo across two windows. `together_probe` and
    `tabs_flow.mjs` hold the second.
  - Studio itself, which needs Wine (CADTASK.md).

## What the walk measured

| act | measured | file |
|---|---|---|
| desktop start, the first 120 frames | 4.4 to 6.2 s | walk logs |
| web, first visit, cold → working | **14.8 s**, 17.3 MB, 8.6 s of it the main thread | `load_check`, broadband |
| web, warm | 8.1 s, 7.4 s main thread | same |
| web, a part from the bin to its ghost | 533 to 628 ms | same |
| a part from the search into the hand | 11 events: a click, "1x4 brick", a click | walk, `wall` |
| then each part put down | 1 click; the part stays in hand | walk, `wall` |
| the ghost following the pointer | 11 ms a frame, worst 15 | walk, `ghost sweep` |
| the car: place, orbit, undo (median / worst) | 19.7/77, 13.7/108, 14.2/22 ms | `cadtask_frames` |
| Orthanc: place, select all, undo, delete | 17/89, 16/180, 19/232, 18/174 ms; timeline opens in 2.8 s | same |
| every command, car and Orthanc | 256 timed; 20 held a frame over 250 ms, all on Orthanc and all said first. The slowest: Instructions 28.9 s, select connected 6.1 s, duplicate or paste of all 10,105 parts 3.1 to 3.2 s | `command_probe` |
| menus | File 20 items, **Edit 39** (25 greyed with nothing selected), View 34, Build 31, Tools 17, Help 6. Edit is 689 px tall in a 720 px window | walk, `menus` |
| keys | 71 of the shell's 122 named commands have no key, among them the Move, Rotate, Hinge, Clone, Paint, Hide and Delete tools | `shell.gd` `_define` |
| a whole real set built from its booklet | **17.8 to 29.8 actions a part**, against Studio's modelled 11.8 to 14.1 | CADTASK.md, gaps 3, 4, 9 |
| search, 30 words a builder types | the wanted part first in 20; "snot" gives Technic pins; "2x4" puts Plate 2 x 4 above Brick 2 x 4 | walk, `search` |

**What is already better than the field, and should be kept:**
- The view turns about the point under the pointer and zooms towards it.
- A part dragged on a joint moves as the real one would.
- Parts sit on an exact 2 LDU lattice with exact collision.
- Colours are marked with the years each part was made in them.
- Every slow command says so before it holds the window.
- Stability, x-ray, cut-away, and the grab are all in the window as you build.

What follows is how the parts a person repeats most can match that.

## Part A: UI/UX fixes

Ranked by value to a person building a model, quick wins (S) first. **S** is
one agent in an afternoon, **M** a day, **L** several days. A **bar** is the
check that says it is better: a probe, a flow, or a walk picture.

### A1. The keys sheet shows one key (S)

**Problem.** F1 (Help › Keys and controls) opens the Controls sheet. Its list
of keys is a scroller one row tall, "select; with a part in hand, put it
down", and every other key is behind a 6 px scrollbar. The rest of the sheet
is settings. Tools › Settings opens the same sheet. It looks like this at
1400 x 900 and at 1280 x 720
([app_ux/keys_sheet_one_row.webp](app_ux/keys_sheet_one_row.webp),
`shots/handbuild/controls_1280x720.png`).

**The best tools.**
- Studio's shortcut page lists every key by group, and keys can be remapped.
- Blender's F3 also shows each command's key.

**Change.**
- Keys get a sheet of their own: grouped (Build, Select, View, Steps, File),
  filtered as you type, and as tall as the window.
- Settings stays its own dialog.
- Each row's key is read from `Shell.key_words`, so the sheet never drifts
  from the menus.

**Bar.**
- At 1280 x 720 the sheet shows at least 20 rows without scrolling.
- Typing "hinge" leaves the hinge keys.
- `controls_probe` presses every key the sheet lists.

### A2. A greyed menu row loses its words when it has the focus (S)

**Problem.** A menu opened from the keyboard focuses its first row. In Edit
that is Undo, greyed when there is nothing to undo. The row's highlight is the
same grey as its words, so it reads as a blank bar with "Ctrl+Z" at the end
([app_ux/menu_greyed_row_blank.webp](app_ux/menu_greyed_row_blank.webp)).
This is the keyboard and screen-reader path, the one COMPETITIVE.md counts as
ahead of everyone.

**Change.** In `Look`, the PopupMenu's disabled words on a highlight get a
colour that contrasts with it.

**Bar.** Every menu's rows, in each state, at 4.5:1 or better, read from a
picture of each menu (walk, `menus`).

### A3. A turn with no room is a dead end (S)

**Problem.** R on a 1 x 4 in a wall, with the turn step at 15°, does nothing.
The status bar says "no room to turn it there"
([app_ux/no_room_to_turn.webp](app_ux/no_room_to_turn.webp)). Nothing says
what is in the way, and nothing offers a next step. The same brick alone on
the floor turns 45° in three presses (walk, `free turn`).

**The best tools.** Studio's arrow keys turn a part without regard to
collision, and Ctrl+Alt+C turns collision off.

**Change.**
- Brickworks keeps its exact collision. When a turn has no room:
  - the parts in the way flash red for a second;
  - the part comes into the hand already turned, its ghost where it could go.
    That is one undo, and Esc puts it back as it was.
- The same applies to T (tip) and to the Rotate tool.

**Bar.** In the walk's wall, the turned brick is down, turned, in three actions
or fewer (R, aim, click).

### A4. The bin's tiles say what each part is (S)

**Problem.**
- A tile is a picture and a part number: 3023b, 3004, 3022, 3020.
- The +9 and +67 badges, for the printed versions folded under a part, say
  nothing until hovered.
- A person new to LDraw numbers hovers each tile to learn that 3710 is a
  1 x 4 plate ([app_ux/first_open_1400x900.webp](app_ux/first_open_1400x900.webp)).
- On the live site, opening the castle, the tiles were still blank grey
  squares eight seconds in, while the parts were fetched. All they said was
  a number ([app_ux/web_bin_blank_tiles_1600x900.webp](app_ux/web_bin_blank_tiles_1600x900.webp)).

**The best tools.**
- Studio, LeoCAD and LDCad name each part on hover and in a list mode.
- LeoCAD has a list view of names.

**Change.**
- Each tile carries a short name in words ("Plate 1 × 2", with LDraw's
  padding taken out) and its size.
- The number moves to the second line, or to hover.
- A list view (name, number, size, colours made) sits beside the tiles.

**Bar.** On the walk's first picture, every tile in sight names its part
without a hover, at 1280 x 720 too.

### A5. Search knows a builder's words (S)

**Problem.** In the walk's 30 searches the wanted part came first in 20.
"cheese slope", "jumper", "headlight", "grille" and "log" are already right.
The misses:
- "snot" lists Technic pins, not brackets and bricks with studs on the side.
- "2x4" puts Plate 2 x 4 above Brick 2 x 4.
- "macaroni" puts a 4 x 4 corner tile first.

**The best tools.** Studio filters as you type by number, words or size.
People complain that names differ between catalogues (forum, *unverified*).

**Change.**
- A table of the community's words, each mapped to parts: SNOT, macaroni,
  Erling, Travis, cheese, jumper, grille, droid arm, and so on.
- A size typed alone is ranked by how often real sets use each part (the
  usage counts `PartLibrary` already reads).

**Bar.**
- `search_rank_probe` gains 20 such words, each with its wanted part in the
  top three.
- "2x4" lists Brick 2 x 4 first.

### A6. Clone and duplicate keep a copy in hand (S)

**Problem.**
- The Clone tool is "click a part to hold a copy, then click where it goes".
- A held copy lets go after one put (`handbuild_probe`, "lets go of them").
- So five window bays take ten clicks.

**The best tools.**
- Studio's Clone (C) puts a copy under the pointer and is ready again after
  each click; right-click ends it.
- LDCad's Insert places another of the working part.

**Change.** After a clone or a Ctrl-D copy is put down, another copy stays in
hand until Esc or a right-click, as a part from the bin already does.

**Bar.** Five copies in six actions (`handbuild_probe`).

### A7. The menus hold each command once, and less of them (S)

**Problem.**
- The sub-assembly commands are in both Edit and Build.
- The step commands are in Edit › Build steps and in Build.
- Exploded view is in View and in Build.
- Edit has 39 rows ([app_ux/edit_menu_1280x720.webp](app_ux/edit_menu_1280x720.webp)).
- Studio's menus are long too; the difference is that no command lives in
  two of them.

**Change.**
- Each command has one home. Edit keeps the clipboard, selection, hide, lock,
  paint and replace. Build keeps steps, sub-assemblies and sections.
- The command palette (A9) finds anything by name.

**Bar.**
- No command is in two menus.
- Edit is at most 25 rows, and fits in 60% of a 720 px window.

### A8. The part menu holds what is done to a part (S)

**Problem.**
- The right-click menu on a part has ten rows
  ([app_ux/part_menu.webp](app_ux/part_menu.webp)): Ask Claude, select what
  is joined, hide, show only, paint, printed versions, copy, delete, make a
  sub-assembly, properties.
- Duplicate, Replace with the part in hand, Same part, Same colour, Move to
  the next or previous step, and Swing on its hinge each need a key or a menu.

**Change.** Add those six, each with its key, in the order Studio's part menu
uses for the ones it shares.

**Bar.** `handbuild_probe`'s part menu runs each of them from the menu.

### A9. Find any command by typing (M)

**Problem.**
- There is no command palette.
- 71 of the shell's 122 named commands have no key, among them the Move,
  Rotate, Hinge, Clone, Paint, Hide and Delete tools.
- They are spread over six menus of up to 39 rows, and the toolbar folds on
  a narrow window.

**The best tools.**
- Figma's Actions menu (Ctrl+K) searches and runs any action.
- Blender's F3 shows each command's menu and key.
- Onshape searches tools with Alt+C; Fusion opens a box at the pointer with S.

**Change.**
- `Ctrl+/` opens a box over the model, as Figma's did. `Ctrl+Shift+P` is the
  same on the desktop; Firefox keeps that key for itself.
  - Typing filters every command, setting and panel by its words and its
    menu path.
  - Each row shows its key and where it lives in the menus. Enter runs it
    through `Shell.run`, so a greyed command stays greyed.
  - Recent commands come first.
- A part number or name also lists the parts, so "3001" takes a brick into
  the hand.
- It is in the Brickworks menu that brand373 adds at the start of the
  toolbar, and in Help.

**Bar.**
- `palette_probe` runs every command in the shell's table from the palette,
  as its menu item does.
- Render opens in at most six keystrokes from the model.
- It works in a browser.

### A10. The parts bin and Properties get room (M)

**Problem.**
- The left column stacks the bin, the model tree, Properties, the floor and
  the 320 colours.
- At 1280 x 720 the bin shows **8 tiles**; at 1400 x 900 it shows 16, and
  on the live site at 1600 x 900, 12
  ([app_ux/first_open_1280x720.webp](app_ux/first_open_1280x720.webp)).
- With a part selected, Properties shows X and Y. Z, Turn, Tilt and Roll are
  behind a scroller ([app_ux/properties_cramped_1400x900.webp](app_ux/properties_cramped_1400x900.webp)).
  These are the fields CADTASK's builds typed every part off the pointer
  into, at about 25 actions each.
- The assistant, when on, takes the right column and folds the bin to its
  rail below 1400 px.

**The best tools.**
- Studio puts the parts palette down the whole left side, and properties and
  steps on the right.
- Figma, Blender and Onshape all put the inspector on the right.

**Change.**
- A right column holds Properties and the model tree, with the assistant as
  a tab beside them.
- The left column is the bin and its colours, the colours folding to one row
  of quick colours while a part is in hand.
- The phone and tablet layouts keep their own.

**Bar.**
- At 1280 x 720 the walk's first picture shows at least 24 tiles; at
  1400 x 900, at least 40.
- With a part selected, every Properties field is in sight at 1280 x 720.
- The assistant opens without folding the bin at 1400 px and wider.
- `handbuild_probe`, `phone_flow` and `tablet_flow` pass.

This changes what the owner sees first. It is a plan for the owner's eye
before it is built.

**Built (roomfit, 2026-11-05).** The right column of the model tree and
Properties, with the assistant as its tab, was already built (October). Still
missing at the 11-05 audit, measured by `roomfit_probe` at four sizes, parts
counted wholly inside the bin's column:

| Window | Parts, before | after | Assistant on, before | after | Model, after |
|---|---|---|---|---|---|
| 1280 x 720 | 24 | 24 | folds the bin | folds the bin | 60% |
| 1400 x 900 | 30 | 42 | folds the bin | beside it, 16 parts | 52% |
| 1600 x 900 | 28 | 40 | folds the bin | beside it, 12 parts | 54% |
| 1920 x 1080 | 28 | 40 | folds the bin | beside it, 12 parts | 54% |

- **Both columns from about 1350 px.** They show at once wherever both fit
  with the model keeping half the window (`Main.BOTH_SHARE`), so a
  1366 x 768 laptop gets them too. The old rule kept
  the model 60%, so the columns took turns up to 1835 units, which is
  1920 x 1080 too. Narrower windows (1280 x 720) still take turns, with the
  model's 60%.
- **The bin gives the right column its room.** At 1400 x 900 the bin is 7
  across while the right column is folded, and 4 across while it is open. With
  the bin at 6, the model had 41%. A first visit opens with the right column
  folded (`properties_open` now defaults to off).
- **The selected part's boxes under the bin.** Whenever Properties are out
  of sight down the right, the bin shows the part's place, turn and colour,
  as it already did at a laptop's size. This includes when the assistant is
  showing.
- **A row and a half of colours.** The palette took 14% of a tall column. It
  now stays at the row and a half a laptop's column always had. The rest is a
  scroll, a name or All away, so the bin keeps two rows of parts.
- **A bin cut off at its edge.** The grid's scroller took the grid's width as
  its least, so a bin once 7 across never narrowed again. At 1280 x 720 its
  last column of tiles, Z and Roll, and Prints and List were cut off at the
  column's edge. The scroller no longer counts it.
- **Not built: one row of quick colours while a part is in hand.** Folding
  the palette while a part is in hand would move it under the pointer just as
  a colour is chosen for that part. It would also hide the swatches that
  flows and probes click. The row and a half above gives the bin the same
  room.

`phone_flow` and `tablet_flow` need a preview. The phone's and the tablet's
layouts take none of these paths (`Main._fit_bin` returns for drawers, and
the bin's changes skip a sheet for a finger). On the desktop,
`tablet_fit_probe` and `phone_idle_probe` cover them.

### A11. Keys: every tool has one, and a person can set their own (M)

**Problem.**
- The Move, Rotate, Hinge, Clone, Paint, Hide and Delete tools have no key.
- A bare letter does a different thing from the same letter with Ctrl: C
  paints the part under the pointer when nothing is selected
  (`main.gd`, `KEY_C`), H is the Pan tool, and X lifts.
- A Studio user's C (clone), H (hinge) and L (hide) do something else here.
- Keys cannot be rebound. Settings offers navigation presets for the mouse
  only (Studio, Blender, Mecabricks).

**The best tools.** Studio, LeoCAD and Blender remap every key. Studio's
default sheet leaves Frame selection, Connect and Paint unbound, and lets each
person bind them.

**Change.**
- A key for every tool.
- C paints only a selection.
- Key presets beside the mouse presets: Studio's (C clone, H hinge, L hide,
  arrows turn), Mecabricks' (W select, S snap, D clone, M move) and LDCad's.
- Any key can be rebound in the keys sheet (A1). A clash is refused with what
  it clashes with, and the keymap goes with the account's settings.

**Bar.**
- Under the Studio preset, Studio's 20 default keys do what Studio's do.
- A rebinding survives a restart and a browser.
- `controls_probe` passes under each preset.

### A12. A first build that teaches (M)

**Problem.** A first visit gets an eight-card tour.

**The best tools.** Studio opens with an interactive tutorial at first launch.

**Change.** "Build your first model" in place of the cards, with the app
watching each act done, not described:
- a part from the bin, put down;
- a part turned and coloured;
- one selected, moved and copied;
- the view turned;
- the model saved.

It is skippable, and it comes back from Help.

**Bar.**
- A probe drives the tutorial with keys and clicks to its end in at most 25
  acts.
- `first_steps_flow` still passes.

### A13. The web's first visit (L, a known track)

**Problem.** On 20 Mbps, a first visit is interactive in 14.8 s (17.3 MB, 8.6 s
of it the main thread) and a return visit in 8.1 s. Mecabricks is a web page,
and that is who a browser visitor compares it with. The main thread's start is
the catalogue, and is known ([SLOW_DEVICES.md](SLOW_DEVICES.md), the web-load
notes). It is listed so the plan is whole, not as a new unit.

**Bar.** A return visit is interactive in 4 s or less, and a first visit in
10 s or less (`load_check --runs=3 --warm`).

**Measured** (webstart2, 2026-11-05, broadband on the box, `load_check --laps`).
- Live m260 at load 18-30, four of each: cold 12.75 s (12.0-13.7), warm 7.2
  (6.8-7.8). Local exports at load 8-14 read 11.8 and 6.6.
- Where a warm 6.6 s goes: the engine to its banner 0.6, its own start 0.3,
  the scripts' compile 2.5, the catalogue 1.0 (its JSON parse about half), the
  interface 0.75, the model 0.15, the first frame 1.1. Cold adds 4.4 s of
  network before the banner; the data pack is in before the compile ends.
- The compile is the first screen's source, 6.16 MB of the app's 10.7 (58%),
  at 0.37 s a megabyte: naming Later's 40 classes from main.gd added 4.5 MB
  and 1.65 s to it, warm and cold alike (ABBA, eight runs, load 7-10). So a
  cut of the start closure saves 0.37 s a MB. The cheapest real cuts are
  small: Grab, GrabDrag, Linkage and HingeAlign are 0.5 MB (8%) for ten
  references, but GrabDrag is made at the start to read the model's joints
  ahead of a first grab. Taking the 4 s warm bar this way means a first
  screen of about a third of today's code: an architecture change, not a unit.
- A columnar catalogue parses no faster (0.32 against 0.28-0.38 s natively).
- Done: the 101 scripts the first screen does not compile (1.6 MB of the code
  pack's 3.9, brotli) go with the data pack (`tools/web/pck_split.py`,
  `tools/web/start_closure.py`): 8.9 MB before the engine starts where it was
  10.4. ABBA at load 8-14, four of each: cold 10.85 s (10.73-11.09) against
  11.81 (11.31-12.10), the banner 4.30 against 4.94; warm 6.50 (6.26-6.81)
  against 6.58 (6.47-6.75), the same.
- With the scripts in it the data pack is 9 MB bigger, and a return visit
  then started the engine before the pack was read in 8 of 10 runs (base:
  5). Its message waited out the compile, and the rest of the parts came
  in with it under the assistant's first compile: the chat panel took
  3.6-4.3 s, where it takes 2.3-2.9 when the pack goes in with the
  engine's. The shell's `startEngine` now waits for the data pack when the
  engine's own came from the cache, at most 1 s; it waited 7-75 ms.
- ABBA of base against the cut with that wait, two sets at load 9-40,
  twelve pairs of each kind, paired cut minus base (medians). The pack went
  in with the engine's on 24 return visits of 24, base 12. Cold: usable
  -0.20 s (sooner in 7 of 12), the banner -0.37 (12 of 12). Warm: -0.21.
  With the assistant: cold -1.46, warm -1.32; the chat panel's first load
  -0.13 cold, -0.24 warm. A data pack 3 s late costs the start the 1 s
  bound; one that fails lets it go at once.
- Left: the warm start's compile (above), the catalogue and the first frame;
  the engine's own wasm is 6.9 MB of the cold 8.9.

**Step 2 plan** (firstscreen, 2026-11-05). The first screen compiles 228
scripts, 6.18 MB of the app's 10.73 (`tools/web/start_closure.py`). Each
line below makes a set of classes Later's: what the first screen's code
names of them is rewritten to reach them by name (`Later.script`,
`Later.make`, typed by their base), and the walk from `main.tscn` stops
there. MB is what leaves the closure (the classes and what only they
name), measured after the line above it. "Names" are the references left
to rewrite; the bracket counts those in main.gd, parts_bin.gd,
inspector.gd, shell_prefs.gd and assistant.gd. The start's seconds are
at 0.37 s a MB. A first use compiles the piece it needs at the rate cut 1
measured on the web after the start, about 1.7 s a MB (below); "first
use" is that piece's cost.

| # | line | MB | names | start | first use | when | risk |
|---|---|---|---|---|---|---|---|
| 1 | The grab: GrabDrag, Grab, GrabChain, Linkage, HingeAlign, Bodies, Playable (Swing, FlexFollow and Topple go with them) | 0.63 | 18 (14) | 0.23 s | 1.06 s, measured | a drag on a part, the viewer's play, Meet, Motions, Simulate, move_part | one piece; GrabDrag reads the joints ahead from the start. **Landed and measured: NO-GO**, below |
| 2 | The leaves: Sections, SectionsUi, Handles, SplitMerge, LibraryDialog, GalleryTool, CollectionDialog, Together, the updater (5), Exports (6), Minifig, MinifigData | 0.70 | 66 (21) | 0.26 s | 0.05-0.26 s a piece | each its own menu; a selection's handles; a together link; a model with figures | low: ten pieces, the largest the figures (0.15 MB) |
| 3 | Making parts: PartForge, PartEditor, ElementMaker, StudioDecor, Stickers, SvgText, PictureFile, Rays | 0.33 | 91 (2) | 0.12 s | 0.42 s for Make (0.25 MB) | Make; a print or a sticker; a model with parts of its own | medium: CustomParts reads a model's own parts as it opens |
| 4 | The rest of what moves: Mechanism, Balance, Stability, Flex, FlexTool, GearMesh, Racks, Stress, Poser, PoseAnimation, Bands, LdcadPath | 0.43 | 107 (14) | 0.16 s | up to 0.7 s | placing a gear, chain or hose; Stress; Stability is made at the start | high: Builder and Joints read gears' specs and Flex's kinds while placing, so those tables move to a core class first |
| 5 | Steps and the booklet: Instructions, BookletLooks, Booklet, BookletStudio, AuthorSteps, StepsBar, BuildSteps, SharedPages, SeenParts, HiddenColours, BuildPlayback, Helvetica | 0.57 | 195 (28) | 0.21 s | about 1 s | the timeline; Instructions; a shared model's steps | high: Shell's 770 lines of step edits (135 of the names) move out whole; the timeline is on the first screen and ModelStore reads a model's steps as it opens |
| 6 | Dialogs and the account: CompareView, ModelDiff, Versions, Feedback, Credits, CommandPalette, FirstBuild, Pattern, ReferenceImage, BuildMode; Account, CloudModels, AccountPanel, SignInForm, OrangecheckSignIn, KeymapSync; CustomParts | 0.35 | 98 (25) | 0.13 s | under 0.1 s a dialog | each its menu; the sign-in gate is on the first screen | medium: the account is read as the window is built, so its part saves nothing until the gate is a piece of its own |
| 7 | The assistant's providers: ProviderSettings, Provider, the four APIs, Streamer, KeyStore, OwnKey, ClaudeCode, CopilotCli, Brain, DesignMemory, RealSnippets | 0.19 | 52 (46) | 0.07 s | 0.32 s | the first design, which takes seconds already, or the assistant's settings | most of the names are in main.gd and assistant.gd |
| 8 | Placing: Joints, JointSnap, Exact, Carry, Attach, PartFits | 0.20 | 140 (14) | 0.07 s | 0.34 s | **the first part put down** | fails the rule |
| 9 | Editing and the bin's search: EditVerbs, TypedEntry, ConnectTool, SelectBy, Mirror, Measure; PartSearch, PartWords, SubjectWords | 0.23 | 46 (19) | 0.09 s | 0.2 s a piece | the first edit; the first letter typed in the search | both come early in a visit |

Ranked by the start's seconds for the risk, with a first use under
300 ms: **2**, then 6 and 9. Lines 1, 3, 4, 5, 7 and 8 come over it, and
wait on the penalty below being found and fixed.

Lines 1 to 9 take the closure to 2.56 MB (41%), about 1.3 s off the
start's compile. A third, 2.06 MB, needs 0.5 MB more of main.gd's own
(434 KB; its viewer is 100 KB) and of Shell, Builder and ModelStore's.

**What cut 1 measured.** It cannot be the whole story, because a feature
compiled after the start costs more than its share of the start's
compile. The grab came off the start: 5.56 MB left, a tenth less. The
window made the grab once the first screen was up, and a drag made it at
once if it came first.
- ABBA at load 15-17, four of each
  (`bench/results/firstscreen-2026-11-05/abba1`). The compile fell
  0.25 s cold and 0.5 s warm (paired medians). Usable moved -0.1 s cold
  (base 11.2-14.2) and -0.5 s warm (base 6.5-8.4): inside the base's own
  spread.
- Compiled after the start, the grab took 1.06 s (0.75-1.66, 23 loads
  at load 15-31). The page stalled 0.9-1.6 s, 0.3 s after it was usable
  (`load_check --watch`, arms1). Made after 2 s idle instead, the stall
  came later and was as long. A drag that comes first waits that long:
  over the 300 ms a first use may add.
- Natively (the editor's build, scripts as text) the same cut is in
  proportion: main's compile fell 0.59 s (4.26 to 3.67, medians of three),
  and the grab compiled after it took 0.44.
  The penalty belongs to the web. It is not what the grab names: a script
  typed with Builder, BrickWorld, PartLibrary, BrickLattice, Shell and
  ModelStore loads in 1-2 ms after the start (arms2). Nor is it the code's
  density: 57% of the grab's source is code, and 56% of the rest. Per MB
  of code, the start compiles at 0.8 s and the grab after it at 2.9.
- On a worker (`Later.script_in_background`, asked once the first frame
  was drawn) no frame waited for it. It came in 1.2-3.1 s after it was
  asked, and once not within 5 s. In that run the page stalled 3.5 s,
  2.4 s after it was usable, most likely the Render dialog (made after
  3 s idle) waiting for the compile to let go of the scripts' cache.
- The code is kept on branch `firstscreen-grab` (cee27de8).

**Next.** Line 2, the leaves: ten pieces, each first use 0.05 to 0.26 s
at the rate the grab was measured at, 0.26 s off the start. It is no
bigger than cut 1, so its ABBA needs two sets at a calm load, or the
compile lap's paired medians, to show beyond the noise. Beside it: find
why a script compiled after the start costs 3x on the web, in a Chrome
trace of the grab's load (the allocator's lock with workers busy, the
file reads, the compiler). Until then lines 1, 3, 4, 5, 7 and 8 fail the
300 ms rule, and at parity line 1 would still add 0.4 s to a first drag.
Lines 2, 6 and 9 together are 1.28 MB, 0.47 s of the start.

**Beside it, the rest of a warm start** (base laps, abba1, medians at
load 15-17): the engine 1.05 s (its banner 0.65, its own start 0.4), the
compile 2.9, the catalogue 1.15 (its JSON parse about half), the
interface 0.8, the model 0.2, the first frames 1.15. At A13's 6.6 s, a
third of the code takes the compile from 2.5 to 0.85 s and the warm start
to about 4.9. So the 4 s bar needs about 0.9 s more from the catalogue,
the interface and the first frames. The catalogue's parse cannot start
before Main's compile today. An autoload runs before it (webstart2) and
could read the file and parse it on a worker, beside the compile, if the
catalogue were in the engine's pack. The first frames are SwiftShader's;
what they compile has not been traced yet.

## Part B: Advanced features

Ranked the same way. Each says which tool does it today, or that none does.

### B1. Type a number while moving or turning (M)

**Problem.**
- A place the pointer cannot say (a pan's 4262 swung to 23.58°, a wheel's
  place along its pin, a cab on the wrong sockets) is typed into Properties,
  about 25 actions each (CADTASK.md, gaps 9 and 10).
- The Properties fields it is typed into are cramped (A10).

**The best tools.**
- Blender: G, then X, then 12 moves 12 along X; Tab goes to the next axis;
  `=` takes an expression.
- SketchUp types a distance during or right after a move.
- Onshape's triad takes a typed value while it is dragged.
- Studio's rotate dial takes an absolute angle.
- Figma's fields take arithmetic.

**Change.**
- With a part or a selection in hand (X, Ctrl-D, paste, a part from the bin),
  or right after an R or T, digits open a small field at the pointer:
  - "12" moves 12 studs along the direction it last moved;
  - "x 3", "z -2", "y 3p" (plates) or "y 7 ldu" move along an axis;
  - "r 23.58" turns, and "t 30" tilts, in degrees.
- Enter applies, and the whole is one undo.
- The field shows the result live, refused in red where there is no room.

**Bar.**
- CADTASK's four typed placements of section 9 each take 8 actions or
  fewer, from about 25.
- The 23.58° swing takes 6 or fewer.
- `offgrid_probe` drives each.

### B2. Connect: a point on the part, a point to put it on (M)

**Problem.**
- A long Technic brick on two pins has 30 ways on, and T steps through them
  one at a time.
- 8841-1's column was typed after more than a hundred presses in every run
  (CADTASK.md, gap 3).
- Whole sets take 17.8 to 29.8 actions a part, most of them aiming and
  stepping through the ways on (gap 4).

**The best tools.**
- Studio's Connect tool: click a connector on the part (they show as blue
  cubes and cylinders), then the connector it goes on.
- Mecabricks: S, then a snap point on each part.
- Blender: B picks the point of the moving thing that snaps.

**Change.**
- With a part in hand, a key (or the tool) shows its connectors: studs, holes,
  pins, axles, bars and clips, which `JointSnap` already reads.
- A click picks one; the part's ghost then follows the pointer by that point
  only, onto the target connectors that take it.
- A second click puts it down. R turns it about that joint.

**Bar.**
- 8841-1's column goes on in 6 actions or fewer.
- `cad_task_flow` on 8841-1 is at 18 actions a part or fewer, from 29.8
  (CADTASK.md, section 9).
- `placing_probe` passes.

### B3. Handles on the selection: turn about any axis, slide along any (L)

**Problem.**
- The Rotate tool is "click a part to turn it by the turn step", about the
  vertical only, and nothing on screen shows an axis
  ([app_ux/rotate_tool_no_handles.webp](app_ux/rotate_tool_no_handles.webp)).
- T tips a quarter, about whichever axis faces the view.
- The finest turn step is 5°.
- Any other angle about any other axis is typed in Properties.

**The best tools.**
- Studio's rotate gizmo snaps 90° near the centre, 5° in the dial and 1° at
  the rim, and its pivot defaults to the shared connection.
- LeoCAD 26.09 added a trackball and axis gizmo.
- Mecabricks shows axis arrows and two-axis panes.
- Onshape's triad moves along, or turns about, any of its axes.

**Change.**
- Rings and arrows drawn on the selection when the Move or Rotate tool is
  in use. They work on any axis of the part, the model or the view.
- The pivot is at the connection the selection hangs from, or at a point
  picked with Alt.
- A drag snaps to the turn step, finer towards the rim.
- A number typed mid-drag (B1) sets it exactly.
- Collision is kept: a drag stops at the last place with room, as Studio's
  does.

**Bar.**
- Any part turned about any of its three axes to any angle in 3 actions.
- `gizmo_probe` drives each handle.
- `cadtask_frames` stays within its budget with the handles drawn.

### B4. Hinge align: the hinges between two parts swing so they meet (L)

**Problem.** Curved walls, wings and domes on hinges are worked out by hand,
one hinge at a time: J swings a selection 15° about the joint it hangs from.

**The best tools.**
- **None.** LDD's Hinge Align was "notoriously buggy" and went with LDD.
- Studio has no such tool. Its forum's answer is to work the angles out by
  hand.

**Change.**
- Select a part and the part it should meet, across a chain of hinges, clips
  or turntables. `Joints` already finds those chains.
- "Meet" swings each joint in the chain so the two ends join. Each angle is
  kept within the joint's range, and the solve is one undo.
- With no exact solution, the nearest is shown, and the gap is said in plates.
- It is offered in Properties' joint row, where the part's joints are already
  listed.

**Bar.**
- A ring of eight hinge plates closes in 4 actions.
- A wing's two hinges meet its body.
- `check_design`'s joint check passes on each.
- A probe builds each from the keys.

### B5. Find what fits (M)

**Problem.** Nothing in the bin answers "what goes on this?". A person who
knows the selection takes a pin or a bar finds one by name.

**The best tools.** Studio has `=compatible("4024")` and "Find compatible
bricks", "Find alternatives" (the box filled with the selection's traits),
and Replace offering parts of a similar size.

**Change.**
- A "Fits the selection" chip in the bin lists first the parts whose
  connectors take the selection's free ones: pins in a Technic hole, bars in
  a clip, a tile on a jumper.
- "Like this" lists parts of the same footprint and kind.

**Bar.**
- A probe with ten pairs (a beam and a pin, a clip and a bar, a jumper and a
  1 x 1 round, ...) has each fitting part in the top five.
- Replace from "Like this" is 3 actions.

### B6. Patterns: copies along a line, round an axis, along a path (M)

**Problem.** Fences, colonnades, round towers, wheel spokes and roof tiles
are copied one at a time, and Ctrl-D lets go after each (A6).

**The best tools.**
- SketchUp: after a copy, `5x` makes five in a row, and `/5` divides the gap.
- Fusion and Onshape have linear and circular patterns.
- No LEGO CAD has them.

**Change.**
- After a copy is put down, a number with x repeats it by the same move:
  `5x` makes five copies.
- A Pattern dialog takes a count and spacing along an axis, or a count round
  an axis or turntable at the turn step. A flexible part's path does as well.
- Every copy is checked for room, and the whole is one undo.

**Bar.**
- A fence of 12 posts in 5 actions.
- A ring of 16 on turntables in 6.
- `handbuild_probe` drives both.

### B7. Instructions: Studio's last page tools (M)

**Problem.** The booklet is laid out by hand already, which puts it close to
Studio. What is left (INSTRUCTIONS.md, around line 1990):
- a page box cannot be turned;
- there are no rulers or guides;
- a callout's own steps are not posed apart from it;
- PNG pages are about 107 dpi;
- Helvetica is not embedded in the PDF;
- a page's layout cannot be applied to the pages after it.

**The best tools.**
- Studio's Page Design snaps to margins and centres, shows a ghost of the
  previous step for alignment, and applies a layout to "followings".

**Change.**
- Those six. The layout applied onwards is the one most felt on a 40-page
  booklet.

**Bar.**
- `booklet_edit_probe` lays out a 40-page booklet from one page and "apply
  to following" in 10 actions or fewer.
- PNG pages are 300 dpi.
- `pdffonts` shows the font embedded.

### B8. Build together: see each other, talk on the model (M)

**Problem.** Two people co-edit live with their own undo, which Studio's
Build Together does not promise. What [TOGETHER.md](TOGETHER.md) leaves open:
- changes in flight are lost when a page reloads;
- a model over 4 MB cannot start a session;
- chat has no history;
- neither person sees where the other is working.

**The best tools.**
- Figma shows each person's pointer and selection, follows a person's view,
  and pins comments to a place.
- Studio's session ends for everyone when the host leaves.

**Change.**
- Each person's pointer and selection drawn in their colour, and Follow on
  their name.
- A comment pinned to a part, kept in the file, and resolved by a click.
- In-flight changes survive a reload, and the 4 MB cap is lifted.

**Bar.**
- `together_flow`: the other's pointer is seen within 1 s at p95.
- A pinned comment survives save, open and share.
- A reload in the middle of a change loses nothing.

### B9. A second view beside the model (M)

**The best tools.**
- Studio splits into up to four viewports, each with its own lock.
- LDCad's Space switches between split views and one large view.
- Placing on a side face or under an overhang is easier with a top or front
  view beside the perspective one.

**Change.** View › Split: the perspective view and one straight-on view
(front by default), the part in hand drawn in both.

**Bar.** A part placed on side studs from the second view in no more actions
than from the main one, with `cadtask_frames` within budget.

### B10. Smaller, each worth a unit later

- **Path-traced renders.** Already planned as task 9 and
  [RENDERING.md](RENDERING.md) R2/R3. Not a new unit.
- **Springs and rubber bands** laid round circles (LDCad's path and spring
  system). Brickworks lays seven kinds of flexible part along a path and has
  neither (L).
- **A set's inventory as a bin:** "build from 10283's parts", as LDCad's bins
  and Rebrickable's alternate builds do. The collection's "What can I build?"
  is the start (S to M).
- **Studio's .io, proven in Studio.** Brickworks' `.io` export has never been
  seen opening in Studio. It needs Wine here, or the owner opening one file
  on their own machine (S, the owner's).
- **Two saves compared in the app:** added in green, removed in red. The
  gallery already says what changed by part and step (M).
- **A 3Dconnexion mouse,** as Bricksmith has; it needs a native extension (M).

## The units to start now

Seven, each its own worktree, each with no file another of them edits. Every
new probe goes on its own line in `tools/suite/*.txt`, which merge as a union.

| unit | items | size | files it owns | bar |
|---|---|---|---|---|
| **keysheet** | A1, A2 | S | `src/ui/controls_dialog.gd`, `src/ui/look.gd` | 20 or more key rows in sight at 1280 x 720 and filtered as typed; Settings apart; every menu state at 4.5:1 or better |
| **hand** | B1, A3, A6 | M | `src/ui/edit_verbs.gd`, `src/assembly/builder.gd`, `src/assembly/carry.gd`, a new `src/ui/typed_entry.gd` | CADTASK's typed placements in 8 actions or fewer; the walk's turn in a wall in 3; five clones in 6 |
| **bin** | A4, A5, B5 | M | `src/ui/parts_bin.gd`, the search's word table, `search_rank_probe` | every tile named; 20 builder words in the top three; ten fit pairs in the top five |
| **layout** | A10 | M | `src/main.gd`'s column set-up (`_stack`, the docks, the stack `shell.build` is handed), `src/ui/side_dock.gd`, `src/ui/panel_stack.gd` | 24 or more tiles at 1280 x 720; every Properties field in sight; the assistant beside the bin at 1400 px; phone and tablet flows pass |
| **hingealign** | B4 | L | a new `src/assembly/hinge_align.gd`, `src/ui/inspector.gd` (the joint row's Meet) | an eight-plate ring in 4 actions; a wing's hinges meet; the joint check passes |
| **pages** | B7 | M | `src/ui/page_editor.gd`, `src/render/booklet_maker.gd`, the PDF and PNG writers | a 40-page layout from one page in 10 actions; PNG at 300 dpi; the font embedded |
| **palette** | A9, A7, A8 | M | a new `src/ui/command_palette.gd`, `src/ui/shell.gd` (`MENUS`, `_define`, `open_context`) | every command run from the palette; Render in 6 keystrokes; no command in two menus; the part menu's six new rows |

**About brand373.** brand373 puts the Brickworks mark at the start of the
toolbar. The mark opens an app menu holding About, Website, Docs and Account,
which edits `shell.gd` and `toolbar.gd`. Of these units only **palette** shares
a file with it (`shell.gd`), so palette starts once brand373 is merged, or
rebases onto it. Palette then builds on the app menu rather than beside it:
- "Find a command… Ctrl+/" goes in brand373's menu;
- Help shrinks to Keys and Take the tour, since About, Website and Docs have
  moved into that menu.

**layout** reaches the inspector and the model tree without `shell.gd`: it
hands `shell.build` the right column's stack, not the left one's.

**Next, in this order once those land:**
1. **B2 (Connect)** and **B3 (handles)**, after **hand**. Both work in
   `edit_verbs.gd`, `builder.gd` and the toolbar.
2. **A11 (keys)**, after **palette** and **keysheet**: `shell.gd`'s keys and
   the sheet's rebinding.
3. **B6 (patterns)**, after **hand** and **palette**.
4. Then **A12**, **B8** and **B9**.

## The top ten, by value to a person building

1. **A10:** the bin and Properties get room. Every minute of building is spent
   in that column.
2. **B1:** type a number while moving or turning. That is 25 actions down to 8
   for every part the pointer cannot place.
3. **B2:** Connect, a point on the part and a point to put it on. It attacks
   the 17.8 to 29.8 actions a part.
4. **A9:** find any command by typing. 71 commands have no key.
5. **B3:** handles to turn about any axis by any angle.
6. **A1:** the keys sheet that shows one key.
7. **A3:** a turn with no room offers the turned part in hand.
8. **B4:** hinge align, which no tool has.
9. **A4 and A5:** the bin names its parts and knows builders' words.
10. **A11:** a key for every tool, Studio's keys as a preset, and rebinding.

## Sources

Brickworks' own figures are from the runs above. The field's:
- Studio's keys: <https://studiohelp.bricklink.com/hc/en-us/articles/5706320095255>
- Studio, placing and snapping: <https://studiohelp.bricklink.com/hc/en-us/articles/5412087360919>
- Studio, Connect: <https://studiohelp.bricklink.com/hc/en-us/articles/6481651047319>
- Studio, rotate and hinge gizmo: <https://studiohelp.bricklink.com/hc/en-us/articles/5411433123351>
- Studio, clone and mirror: <https://studiohelp.bricklink.com/hc/en-us/articles/5412307707031>
- Studio, search and `=compatible()`: <https://studiohelp.bricklink.com/hc/en-us/articles/6502499385111>
- Studio, selection: <https://studiohelp.bricklink.com/hc/en-us/articles/5410231515543>
- Studio, camera: <https://studiohelp.bricklink.com/hc/en-us/articles/5409213150487>
- Studio, Divide into Steps: <https://studiohelp.bricklink.com/hc/en-us/articles/7123910550039>
- Studio, Page Design: <https://studiohelp.bricklink.com/hc/en-us/articles/5627735762967-Moving-Contents>
  and <https://studiohelp.bricklink.com/hc/en-us/articles/5627373330327-Page-Layout>
- Studio, Build Together: <https://studiohelp.bricklink.com/hc/en-us/articles/6477757327767>
- Studio, no hinge align: <https://www.eurobricks.com/forum/forums/topic/178843-hinge-align-in-studio>
- Studio, snapping by view angle: <https://www.eurobricks.com/forum/forums/topic/188574-studio-how-is-the-technic-building-experience>
- Mecabricks' tools: <https://brickset.com/article/52336/let-s-build-in-mecabricks>
- LDCad's keys: <http://www.melkert.net/LDCad/docs/keys>
- LDCad, nested editing: <http://www.melkert.net/LDCad/docs/advEdit>
- LeoCAD 26.09: <https://github.com/leozide/leocad/releases/tag/v26.09>
- LeoCAD's tutorial: <https://www.leocad.org/docs/tutorial1.html>
- Figma, quick actions: <https://help.figma.com/hc/en-us/articles/23570416033943-Use-quick-actions>
- Figma, nudging and fields: <https://help.figma.com/hc/en-us/articles/360039956914>
- Blender, typed transforms: <https://docs.blender.org/manual/en/latest/scene_layout/object/editing/transform/control/numeric_input.html>
- Blender, menu search: <https://docs.blender.org/manual/en/3.3/interface/controls/templates/operator_search.html>
- Blender, snap base: <https://developer.blender.org/docs/release_notes/4.0/modeling/>
- Onshape's keys: <https://cad.onshape.com/help/Content/shortcut_keys.htm>
- Onshape's triad: <https://cad.onshape.com/help/Content/Home/triad_manipulator.htm>
- SketchUp, moving: <https://help.sketchup.com/en/sketchup/moving-entities-around>
- SketchUp, arrays from a copy: <https://prod-aws-help.sketchup.com/article/3000092>
- Fusion's S key (*unverified*, the page refused a reader):
  <https://www.autodesk.com/products/fusion-360/blog/quick-tip-the-s-key/>
