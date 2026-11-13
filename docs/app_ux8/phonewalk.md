# The walk by finger: what phonepanels and fingertools work from

APP_UX8 unit 6 (phonewalk), 2026-11-13. `tools/web/phonewalk_flow.mjs` walked a
preview of pre261 at 0fbb19330 (`brickworks-evv08ch5h`) by touch alone, at
390 x 844 (3x) and 1024 x 768 (2x), signed in as an account of the run's own.
Every act ran at both sizes, and all 46 were done by finger. 21 of them took
over twice the desktop's presses, and 8 touched a control under 44 points
across. The full table follows.

## What a finger needs, by file

- **`src/ui/page_editor.gd`** (phonepanels): the page editor is the
  desktop's editor, drawn at a phone's size. Its controls under 44 points
  across (width x height, points): Lay out the page… 51 x 13 (101 x 26 on the
  tablet), the corner handle 9 x 9 (17 x 17), Add words 38 x 17 (75 x 33), the
  words field 130 x 17 (256 x 33), Done 21 x 14 (42 x 33). The tap that
  brings the phone's keyboard up drops the words field's select-all. "Your
  words" is drawn selected, but "Hi" goes on its end, so it takes 12 deletes
  and "Hi" again: 18 taps against the desktop's 3. Properties' Turn, also a
  typed field, keeps its select-all.
- **`src/ui/pose_panel.gd`, `src/main.gd`** (phonepanels): a door dragged
  while Motions records does record, but the drag also selects 152 parts and
  opens their actions over the panel (`_on_phone_hold`: a finger still for
  480 ms is the part's actions). Its Done comes before Stop: 13 taps against
  4 on the phone. A joint's slider sits under the panel's fold: 4 to 6 swipes
  bring it into sight, 5 to 7 taps against 1.
- **`src/ui/simulate_panel.gd`** (phonepanels): Play and the cycle's slider
  sit under the panel's fold. Played: 9 against 2. Scrubbed: 3 to 4 against 1.
- **`src/main.gd`, `src/ui/edit_verbs.gd`**: a tap in Select replaces the
  selection, and nothing adds to it by finger, so three parts are painted one
  at a time: 9 against 4.
- **`src/ui/phone_shell.gd` (More)**: a command is More, its menu and its
  row, plus the swipes to bring the row into sight. Render 6 to 7 against 2,
  Instructions 4 against 1, Check stability 4 to 5 against 1, Cut away 9 to 11
  against 2, Measure 7 against 3 on the tablet.
- Done in no more than twice the presses: a part to the last step, Like this,
  My collection, Measure on the phone, the page editor's open, move and Done
  (by count), split and merge, a 15° turn through Properties' Turn (9 against
  5), the wall of eight, and Motions' suggested motion. The part's own Turn row
  turns by the turn step (90° out of the box) with no way to choose another by
  finger.
- fingertools (Measure and the move handles): Measure was done by finger in
  6 to 7 taps. The walk does not drive the move handles.

The run's own table follows (`--out`'s phonewalk.md), unedited.

## The table

Written by tools/web/phonewalk_flow.mjs on 2026-11-13T17:27Z against https://brickworks-evv08ch5h-xaxis-projects.vercel.app/app
(390 x 844 and 1024 x 768, touch alone, SwiftShader).
A tap, a finger held, a drag and a key of the on-screen keyboard each count one;
a More row is More, its menu and the row. ✓ done by finger, ✗ not; "small": a control it took
is under 44 points across (named, width x height).

| act | desktop | 390 x 844 | 1024 x 768 | what stops a finger, and its file |
|---|---|---|---|---|
| a part to the last step | 5: the part clicked, Alt+T, the step's 2 digits, Enter (walk `round3`: 4 after the click) | ✓ 8 | ✓ 8 |  |
| Render: a picture made | 2: F9, Picture | ✓ 6 (over 2x) | ✓ 7 (over 2x) | 390x844: 6 taps for the desktop's 2, the command three taps deep in More (render: More, its menu (file), 2 drags to bring it into sight, the row); 1024x768: 7 taps for the desktop's 2, the command three taps deep in More (render: More, its menu (file), 3 drags to bring it into sight, the row) — **src/ui/phone_shell.gd (More: every command is More, its menu and its row)** |
| a booklet page: Instructions, its pages in a tab | 1: Alt+B | ✓ 4 (over 2x) | ✓ 4 (over 2x) | 390x844: 4 taps for the desktop's 1, the command three taps deep in More (instructions: More, its menu (build), 1 drag to bring it into sight, the row); 1024x768: 4 taps for the desktop's 1, the command three taps deep in More (instructions: More, its menu (build), 1 drag to bring it into sight, the row) — **src/ui/phone_shell.gd (More: every command is More, its menu and its row)** |
| Like this: parts like the one selected | 2: the part clicked, the bin's Like this (walk `round3`) | ✓ 3 | ✓ 3 |  |
| Check stability | 1: Alt+K | ✓ 4 (over 2x) | ✓ 5 (over 2x) | 390x844: 4 taps for the desktop's 1, the command three taps deep in More (stability: More, its menu (tools), 1 drag to bring it into sight, the row); 1024x768: 5 taps for the desktop's 1, the command three taps deep in More (stability: More, its menu (tools), 2 drags to bring it into sight, the row) — **src/ui/phone_shell.gd (More: every command is More, its menu and its row)** |
| Cut away, its plane moved | 2: K, the strip's slider dragged | ✓ 9 (over 2x) | ✓ 11 (over 2x) | 390x844: 9 taps for the desktop's 2, the command three taps deep in More (cut: More, its menu (view), 5 drags to bring it into sight, the row); 1024x768: 11 taps for the desktop's 2, the command three taps deep in More (cut: More, its menu, 7 drags to bring it into sight, the row) — **src/ui/phone_shell.gd (More: every command is More, its menu and its row)** |
| My collection | 2: File, My collection… | ✓ 3 | ✓ 3 |  |
| Measure: two points of the car | 3: U, two clicks | ✓ 6 | ✓ 7 (over 2x) | 1024x768: 7 taps for the desktop's 3, the command three taps deep in More (measure: More, its menu (tools), 2 drags to bring it into sight, the row) — **src/ui/phone_shell.gd (More: every command is More, its menu and its row)** |
| the page editor opened on a step | 2: B (the timeline), Lay out the page… | ✓ 4 (1 small) | ✓ 4 (1 small) | 390x844: done, but under 44 points: booklet_lay_out 51 x 13; 1024x768: done, but under 44 points: booklet_lay_out 101 x 26 — **src/ui/page_editor.gd, src/ui/steps_bar.gd (booklet_lay_out)** |
| the page editor: an item dragged | 1: a drag | ✓ 1 | ✓ 1 |  |
| the page editor: an item resized by its corner | 1: a drag | ✓ 2 (1 small) | ✓ 1 (1 small) | 390x844: done, but under 44 points: page_resize 9 x 9; 1024x768: done, but under 44 points: page_resize 17 x 17 — **src/ui/page_editor.gd (the corner handle)** |
| the page editor: words added | 3: Add words, "Hi" typed | ✓ 18 (over 2x) (2 small) | ✓ 18 (over 2x) (2 small) | 390x844: 18 taps for the desktop's 3; "Hi" went on the end of "Your words", drawn selected: the tap that brings a phone's keyboard up drops the field's select-all, so 12 deletes, a letter each, and "Hi" again; under 44 points: page_add_text 38 x 17, page_words 130 x 17; 1024x768: 18 taps for the desktop's 3; "Hi" went on the end of "Your words", drawn selected: the tap that brings a phone's keyboard up drops the field's select-all, so 12 deletes, a letter each, and "Hi" again; under 44 points: page_add_text 75 x 33, page_words 256 x 33 — **src/ui/page_editor.gd (page_add_text, page_words)** |
| the page editor: Done | 1: Done | ✓ 1 (1 small) | ✓ 1 (1 small) | 390x844: done, but under 44 points: page_done 21 x 14; 1024x768: done, but under 44 points: page_done 42 x 33 — **src/ui/page_editor.gd (page_done)** |
| a 2 x 4 plate split, and merged back | 4: the plate clicked, Alt+S; Ctrl+A, Alt+M (walk `round2`: 1 key each) | ✓ 7 | ✓ 7 |  |
| a turn of 15° | 5: the toolbar's turn step, 15° (2 clicks); the part clicked, R, a click (walk `turns`: 2 after the click) | ✓ 9 | ✓ 9 |  |
| a wall of eight 1 x 4s from the search | 20: a click in the search, "1x4 brick" (9 keys), the tile, 8 clicks, Esc (walk `wall`) | ✓ 21 | ✓ 21 |  |
| three of them painted | 4: a click, two Shift-clicks, Shift+5 (walk `round2`: 1 key after the clicks) | ✓ 9 (over 2x) | ✓ 9 (over 2x) | 390x844: 9 taps for the desktop's 4; a tap in Select replaces the selection, and nothing adds to it by finger: each part tapped and painted on its own; 1024x768: 9 taps for the desktop's 4; a tap in Select replaces the selection, and nothing adds to it by finger: each part tapped and painted on its own — **src/main.gd, src/ui/edit_verbs.gd (a tap in Select replaces the selection: no adding to it by finger)** |
| Motions: the suggested motion kept and played | 3: Alt+O, Keep, Play | ✓ 6 | ✓ 6 |  |
| Motions: a motion recorded by dragging a part | 4: New motion, Record, a door dragged, Stop | ✓ 13 (over 2x) | ✓ 8 | 390x844: 13 taps for the desktop's 4; each drag of a door while recording also left 152 parts selected and their actions opened over the panel, put away by its Done to reach Stop — **src/ui/pose_panel.gd (recording through Grab in the view), src/main.gd (_on_phone_hold: a finger held 480 ms is the part's actions)** |
| Motions: a joint set by its slider | 1: a drag | ✓ 5 (over 2x) | ✓ 7 (over 2x) | 390x844: 5 taps for the desktop's 1; 4 drags to bring motions_joint_0 into sight (a phone's sheet or panel shows a few rows at a time); 1024x768: 7 taps for the desktop's 1; 6 drags to bring motions_joint_0 into sight (a phone's sheet or panel shows a few rows at a time) — **src/ui/pose_panel.gd (the joints' sliders)** |
| Simulate: played | 2: Alt+U, Play | ✓ 9 (over 2x) | ✓ 9 (over 2x) | 390x844: 9 taps for the desktop's 2, the command three taps deep in More (simulate: More, its menu, 1 drag to bring it into sight, the row); 4 drags to bring simulate_play into sight (a phone's sheet or panel shows a few rows at a time); 1024x768: 9 taps for the desktop's 2, the command three taps deep in More (simulate: More, its menu (tools), 2 drags to bring it into sight, the row); 3 drags to bring simulate_play into sight (a phone's sheet or panel shows a few rows at a time) — **src/ui/simulate_panel.gd** |
| Simulate: the cycle scrubbed | 1: the slider dragged | ✓ 4 (over 2x) | ✓ 3 (over 2x) | 390x844: 4 taps for the desktop's 1; 3 drags to bring simulate_scrub into sight (a phone's sheet or panel shows a few rows at a time); 1024x768: 3 taps for the desktop's 1; 2 drags to bring simulate_scrub into sight (a phone's sheet or panel shows a few rows at a time) — **src/ui/simulate_panel.gd (simulate_scrub)** |
| Simulate: another part made the driver | 1: a click on it | ✓ 2 | ✓ 3 (over 2x) | 1024x768: 3 taps for the desktop's 1 — **src/ui/simulate_panel.gd (_on_selection), src/main.gd (a tap's selection)** |

### What each act did

#### 390 x 844

- **step_to** (8 taps, 13 s): from step 12: "moved 1 part to step 15"
- **render** (6 taps, 28 s): render: More, its menu (file), 2 drags to bring it into sight, the row; downloaded car_render.png
- **booklet** (4 taps, 18 s): instructions: More, its menu (build), 1 drag to bring it into sight, the row; the booklet's tab: 1 pages
- **like_this** (3 taps, 6 s): first tiles 3023b, 15573, 35480, 2540; "Parts like Plate 1×2: its size and kind "
- **stability** (4 taps, 19 s): stability: More, its menu (tools), 1 drag to bring it into sight, the row; said "Stands, 1.9 studs inside the right edge (a 34° tilt tips it)."
- **cut** (9 taps, 46 s): cut: More, its menu (view), 5 drags to bring it into sight, the row; the plane from 63 to 97 on 1
- **collection** (3 taps, 6 s): collection: More, its menu (file), the row; open: ["CollectionDialog @PanelContainer@2576"]
- **measure** (6 taps, 21 s): measure: More, its menu (tools), 1 drag to bring it into sight, the row; read "9.3 mm — 1 deep, 1.5 plates up"; said ""; 0 selected (was 0), mode select
- **page_open** (4 taps, 14 s): timeline: More, its menu (build), the row; page 2: page_number_1, page_number_2, page_number_3, page_number_4, page_parts_1, page_parts_2, page_parts_3, page_parts_4, page_picture_1, page_picture_2, page_picture_3, page_picture_4
- **page_move** (1 taps, 4 s): page_picture_1 from [9,9,122.5,84.5] to [31.1,39.3,122.5,84.5]; said "Overlapping: step 1's parts list was on step 1's picture: moved off it; step 3's picture was on step 1's parts list: moved off it; step 3's parts list was on step 1's picture: moved off it; step 4's picture was on step 3's parts list: moved off it; step 4's parts list was on step 1's picture: moved off it."
- **page_resize** (2 taps, 27 s): 5 items tried before one whose corner was on the screen; page_parts_2 from [137.5,9,41.6,22.8] to [137.5,9,63.9,22.8]
- **page_words** (18 taps, 13 s): 1 item added; its field held "Your words" after the tap that brings the keyboard up, 12 deletes to empty it; it reads "Hi"
- **page_done** (1 taps, 1 s): 
- **split_merge** (7 taps, 29 s): split: 8 parts (3024); select_all: More, its menu (edit), the row; merged: 1 part (3020); said "merged 8 parts into a Plate 2 x 4"
- **turn** (9 taps, 31 s): Properties' Turn held "0.0", typed 15: it read "15"; Enter turned it 15.0°, and with the drawer folded 15.0° (said "turned +15°"); the row's Turn turns by the turn step (90°)
- **wall** (21 taps, 20 s): 8 of 8 down (3010), 4 on the others; 0 taps put nothing down
- **paint** (9 taps, 18 s): 3 of 3 painted blue, one at a time (a tap in Select replaces the selection, and nothing adds to it by finger); the same colour selects 3
- **motions_play** (6 taps, 30 s): pose: More, its menu (edit), 1 drag to bring it into sight, the row; suggested ["Open the doors","Drive and turn left"]; "Played "Open the doors": #122 went from 0° to -90°, clear all the way; #123 went from 0° to -90°, cl"
- **motions_record** (13 taps, 80 s): swung #122 (3186) by a finger: 152 selected, "152 parts selected" opened; "Recording "New motion": drag the parts that move in the view, as far and as fast"; swung #123 (3186) by a finger: 152 selected, "152 parts selected" opened; "Recording "New motion": drag the parts that move in the view, as far and as fast"; 2 motions (was 1); 2 keys; "Kept "New motion": 1 drag of 1 joint, 2 keys over 16.4 s. The model is back where it was. Play plays"
- **motions_slider** (5 taps, 44 s): the joint from -69 to 62
- **simulate_play** (9 taps, 73 s): simulate: More, its menu, 1 drag to bring it into sight, the row; playing true; driver "Driver: Crank (#9 46372, #10 3706, and 1 more), the model marks it. Click an axle or a crank to drive that instead."; "3 of 3 joints turn; 0 freedoms left, 0 bodies undecided, following what carries them
Earth: 1.4 turn"
- **simulate_scrub** (4 taps, 36 s): from [1.651,"3 of 3 joints turn; 0 freedoms left, 0 bodies undecided, following what  to [0.988,"3 of 3 joints turn; 0 freedoms left, 0 bodies undecided, following what 
- **simulate_drive** (2 taps, 9 s): the driver from "Driver: Crank (#9 46372, #10 3706, and 1 more), the model marks it. Click an axle or a crank to drive that instead." to "Driver: Earth (#15 6632, #16 3704, and 4 more), clicked. Click an axle or a crank to drive that instead."

#### 1024 x 768

- **step_to** (8 taps, 15 s): from step 12: "moved 1 part to step 15"
- **render** (7 taps, 58 s): render: More, its menu (file), 3 drags to bring it into sight, the row; downloaded car_render.png
- **booklet** (4 taps, 31 s): instructions: More, its menu (build), 1 drag to bring it into sight, the row; the booklet's tab: 1 pages
- **like_this** (3 taps, 10 s): first tiles 3023b, 15573, 35480, 2540; "Parts like Plate 1×2: its size and kind "
- **stability** (5 taps, 26 s): stability: More, its menu (tools), 2 drags to bring it into sight, the row; said "Stands, 1.9 studs inside the right edge (a 34° tilt tips it)."
- **cut** (11 taps, 119 s): cut: More, its menu, 7 drags to bring it into sight, the row; the plane from 63 to 97 on 1
- **collection** (3 taps, 8 s): collection: More, its menu (file), the row; open: ["CollectionDialog @PanelContainer@2536"]
- **measure** (7 taps, 32 s): measure: More, its menu (tools), 2 drags to bring it into sight, the row; read "8.9 mm — 1 deep, 1.3 plates up"; said "measuring — click two points; U or Esc puts the ruler away"; 0 selected (was 0), mode select
- **page_open** (4 taps, 15 s): timeline: More, its menu (build), the row; page 2: page_number_1, page_number_2, page_number_3, page_number_4, page_parts_1, page_parts_2, page_parts_3, page_parts_4, page_picture_1, page_picture_2, page_picture_3, page_picture_4
- **page_move** (1 taps, 10 s): page_picture_1 from [9,9,122.5,84.5] to [17.9,20.4,122.5,84.5]; said "Overlapping: step 1's parts list was on step 1's picture: moved off it; step 3's parts list was on step 1's picture: moved off it; step 4's parts list was on step 3's parts list: moved off it."
- **page_resize** (1 taps, 11 s): page_picture_1 from [17.9,20.4,122.5,84.5] to [17.9,20.4,134,95.3]
- **page_words** (18 taps, 15 s): 1 item added; its field held "Your words" after the tap that brings the keyboard up, 12 deletes to empty it; it reads "Hi"
- **page_done** (1 taps, 2 s): 
- **split_merge** (7 taps, 53 s): split: 8 parts (3024); select_all: More, its menu (edit), the row; merged: 1 part (3020); said "merged 8 parts into a Plate 2 x 4"
- **turn** (9 taps, 48 s): Properties' Turn held "0.0", typed 15: it read "15"; Enter turned it 15.0°, and with the drawer folded 15.0° (said "turned +15°"); the row's Turn turns by the turn step (90°)
- **wall** (21 taps, 31 s): 8 of 8 down (3010), 4 on the others; 0 taps put nothing down
- **paint** (9 taps, 42 s): 3 of 3 painted blue, one at a time (a tap in Select replaces the selection, and nothing adds to it by finger); the same colour selects 3
- **motions_play** (6 taps, 31 s): pose: More, its menu (build), 1 drag to bring it into sight, the row; suggested ["Open the doors","Drive and turn left"]; "Played "Open the doors": #122 went from 0° to -90°, clear all the way; #123 went from 0° to -90°, cl"
- **motions_record** (8 taps, 36 s): swung #122 (3186) by a finger: 152 selected, "152 parts selected" opened; "Recording "New motion": drag the parts that move in the view, as far and as fast"; swung #123 (3186) by a finger: 152 selected, "152 parts selected" opened; "Recording "New motion": drag the parts that move in the view, as far and as fast"; 2 motions (was 1); 4 keys; "Kept "New motion": 1 drag of 1 joint, 4 keys over 6.6 s. The model is back where it was. Play plays "
- **motions_slider** (7 taps, 41 s): the joint from -71 to 62
- **simulate_play** (9 taps, 45 s): simulate: More, its menu (tools), 2 drags to bring it into sight, the row; playing true; driver "Driver: Crank (#9 46372, #10 3706, and 1 more), the model marks it. Click an axle or a crank to drive that instead."; "3 of 3 joints turn; 0 freedoms left, 0 bodies undecided, following what carries them
Earth: 1.4 turn"
- **simulate_scrub** (3 taps, 38 s): from [1.726,"3 of 3 joints turn; 0 freedoms left, 0 bodies undecided, following what  to [0.985,"3 of 3 joints turn; 0 freedoms left, 0 bodies undecided, following what 
- **simulate_drive** (3 taps, 14 s): the driver from "Driver: Crank (#9 46372, #10 3706, and 1 more), the model marks it. Click an axle or a crank to drive that instead." to "Driver: Earth (#15 6632, #16 3704, and 4 more), clicked. Click an axle or a crank to drive that instead."

