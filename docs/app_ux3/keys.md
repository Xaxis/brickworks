# Keys for the commands a builder uses often (2026-11-05, and keys2 2026-11-06)

An expert CAD is driven from the keyboard. Before this, 114 of the menus' 201 commands had
no key under the app's own keys, among them the reference picture, Simulate and Motions.
This lists every command with no key, before and after, says how
often a builder reaches for it and whether BrickLink Studio, LeoCAD or LDCad key it, and
why each one left without a key is left so.

Counted off the app itself (Shell's commands, Keymap's key for each, under each preset,
nothing set by hand), on the desktop. The web has one more under every preset: New tab,
whose Ctrl-Shift-N the browser keeps. `src/dev/keys4_probe.gd` counts them again and
fails when a command has no key and no row below; `src/dev/keys2_probe.gd` checks the
eight keys2 gave.

| Preset | Commands | Without a key before keys | After keys | Before keys2 | After |
|---|---|---|---|---|---|
| Brickworks | 210 | 115 | 110 | 112 | 104 |
| Studio | 210 | 118 | 113 | 115 | 107 |
| Mecabricks | 210 | 116 | 111 | 113 | 105 |
| LDCad | 210 | 118 | 114 | 116 | 108 |

The menus had 201 commands when keys counted. Cut away by a box, a sphere or a cylinder
(APP_UX4 8) added five, each with no key. The Pick a Brick list added one
more with none, and What's This? one with Shift-F1 under every preset: 208 when keys was
done, six more without a key after it. Page setup… (pagesetup) and Stud directions
(seeing2) added one more each with none: 210, and 112 without a key under the app's keys,
before keys2. keys2 gave eight a key under every preset, each one no command had: 104
without a key now, so 106 of the 210 have one (the walk's `counts`, APP_UX5).

APP_UX3 counted 110 with the app's keys on 2026-10-30. Eight came since with none (the
booklet's Pull out, Colour guide, 1:1 guide and Sub-model preview; Render queue; Check for
updates, Reinstall and Restart), and steps3 keyed four (Step earlier, later, merge and
delete): 114 before this.

The field's keys are from their own lists: Studio's shortcut page
(<https://studiohelp.bricklink.com/hc/en-us/articles/5706320095255>), LeoCAD's command
table (`common/lc_commands.cpp`, <https://github.com/leozide/leocad>) and LDCad's keys page
(<http://www.melkert.net/LDCad/docs/keys>), all read 2026-11-05. "—" is none.

## Given a key

Where a field tool keys the same command, its preset takes that tool's key; the app's own
preset takes the field's common key, or Alt and a letter of the menu row, as Alt-C, Alt-P,
Alt-J and Alt-I select already. Every key is on its menu row, in the keys sheet (F1), and
can be set there to another. None is fired while a field is typed in.

| Command | Menu | Studio | LeoCAD | LDCad | How often | Brickworks | Studio's keys | Mecabricks' | LDCad's |
|---|---|---|---|---|---|---|---|---|---|
| `pose` | Build › Motions | — | — | A, animation mode | a few times a model, many on a model that moves | alt-O | alt-O | alt-O | alt-O |
| `instructions` | Build › Instructions | — (Instruction Maker is a tab) | — | — | a few times a model, each time the booklet is made again | alt-B | alt-B | alt-B | alt-B |
| `select_none` | Edit › Select nothing | — | — (Select None has none) | Ctrl-Shift-A, Select none | every few minutes | Ctrl-shift-A | Ctrl-shift-A | Ctrl-shift-A | Ctrl-shift-A |
| `select_alike` | Edit › Select by › Same part and colour | Shift-V cycles to it | — | — | every few minutes | alt-A | alt-A | alt-A | alt-A |
| `select_find` | Edit › Select by › Part number or name | — (its Ctrl-F searches the palette) | Ctrl-F, Find | — (F3 filters the part bin) | a few times a session | Ctrl-F | Ctrl-shift-F | Ctrl-F | Ctrl-F |
| `replace` | Edit › Replace with the part in hand | — | — | — (a double click in the bin) | every few minutes | alt-R | alt-R | alt-R | alt-R |
| `grid` | View › Stud grid | — | — | G, the selection's editing grid | a few times a session | alt-G | alt-G | alt-G | alt-G |
| `reference` | Make › Reference picture | — | — | — | once a build, again to move or scale it | alt-N | alt-N | alt-N | alt-N |
| `stability` | Tools › Check stability | — | — | — | a few times a model, after each section | alt-K | alt-K | alt-K | alt-K |
| `simulate` | Tools › Simulate mechanism | — | — | — | a few times a model, many while a mechanism is tuned | alt-U | alt-U | alt-U | alt-U |

LDCad's G and A are the editing grid and animation mode, as Alt-G and Alt-O are here, but
under LDCad's keys G stays the pick and A the move left: each is used every minute, and A
is one of W, A, S and D. So the stud grid and Motions keep the app's own keys there.

## Given a key in round five (keys2, 2026-11-06)

The rest of what a builder reaches for once a model or more, which APP_UX5's walk found
with no key (its 9). Each has the same key under all four presets: none of the presets
gives these keys to anything, and none was a command's before. Into this model… was
planned here too, but it is not in this release (intomodel was taken out); it gets its key
when it returns. Its place went to Page setup…, new in the same round.

The app's own rule, Alt and the first free letter of the menu row, is kept where a letter
is free (Alt-X, Alt-Y, Alt-L); Render takes the wider 3D field's key, F9 (3ds Max's Render
Last, LightWave's and Modo's Render), as no LEGO® CAD keys it and Blender's F12 opens a
browser's developer tools. The sphere's own letters all have keys, so it sits beside the
box. Page setup's key on a Mac, Cmd-Shift-P, is Firefox's private window, which a page
never hears: it goes beside Alt-B, the booklet itself. The Library opens a model as Open
does, and so sits beside Ctrl-O, as a browser's own Library is Ctrl-Shift-O.

| Command | Menu | Studio | LeoCAD | LDCad | How often | Brickworks | Studio's keys | Mecabricks' | LDCad's | Why this key |
|---|---|---|---|---|---|---|---|---|---|---|
| `render` | File › Render | — | — (its POV-Ray and Blender Render have none) | — | once a model, again for each picture | F9 | F9 | F9 | F9 | the render key of 3ds Max, LightWave and Modo; Blender's F12 is a browser's |
| `render_queue` | File › Render queue | — | — | — | after Render, to see what waits | shift-F9 | shift-F9 | shift-F9 | shift-F9 | beside Render's F9 |
| `cut_box` | View › Cut away by › A box | — | — | — | a few times a model | alt-X | alt-X | alt-X | alt-X | Alt and the first free letter, boX; K then cuts away by it again |
| `cut_sphere` | View › Cut away by › A sphere | — | — | — | a few times a model | alt-Z | alt-Z | alt-Z | alt-Z | every letter of "sphere" has a key; Z beside the box's X |
| `cut_cylinder` | View › Cut away by › A cylinder | — | — | — | a few times a model | alt-Y | alt-Y | alt-Y | alt-Y | Alt and the first free letter, cYlinder |
| `booklet_page_setup` | Build › Booklet page › Page setup | — | — (Print and Print Preview have none) | — | once a booklet | Ctrl-shift-B | Ctrl-shift-B | Ctrl-shift-B | Ctrl-shift-B | beside Alt-B, Instructions, the booklet; the Mac's Cmd-Shift-P is Firefox's |
| `export_pickabrick` | File › Export › LEGO® Pick a Brick list (.csv) | — | — | — | once a model, again as it changes | alt-L | alt-L | alt-L | alt-L | Alt and the first free letter, LEGO®'s L; BrickLink's and Rebrickable's lists are on the parts list (P) |
| `library` | File › Library | — | — | — | once a session | Ctrl-shift-O | Ctrl-shift-O | Ctrl-shift-O | Ctrl-shift-O | beside Open's Ctrl-O, as a browser's Library is Ctrl-Shift-O |

## Left without a key, on purpose

"Keyless under" names the presets a command has no key in; "all" is all four.

| Command | Menu | Studio | LeoCAD | LDCad | How often | Keyless under | Why |
|---|---|---|---|---|---|---|---|
| `import_ldraw` | File › Import › LDraw model (.ldr, .mpd) | — | — | — | once a model | all | a file chosen once, from File › Import |
| `import_io` | File › Import › BrickLink Studio model (.io) | — | — | — | once a model | all | a file chosen once, from File › Import |
| `import_lxf` | File › Import › LEGO® Digital Designer model (.lxf) | — | — | — | once a model | all | a file chosen once, from File › Import |
| `import_mesh` | File › Import › 3D model to brickify (.obj, .stl, .ply, .3mf, .vox, .fbx, .gltf, .glb) | — | — | — | once a model | all | a file chosen once, from File › Import |
| `versions` | File › Versions | — | — | — | rarely | all | an older save, looked for now and then |
| `compare` | File › Compare with | — | — | — | rarely | all | two versions side by side, now and then |
| `export_ldraw` | File › Export › LDraw model (.ldr, or .mpd with its sub-models) | — | — | — | once a model | all | made once a model is done |
| `export_io` | File › Export › BrickLink Studio model (.io) | — | — | — | once a model | all | made once a model is done |
| `export_3d` | File › Export › 3D model (.glb, .gltf, .obj, .stl) | — | — | — | once a model | all | made once a model is done |
| `export_picture` | File › Export › Picture of the model (.png) | — | — | — | once a model | all | made once a model is done |
| `export_bricklink` | File › Export › BrickLink wanted list (.xml) | — | — | — | once a model | all | made once a model is done |
| `export_all` | File › Export › All my models (.zip) | — | — | — | once a model | all | made once a model is done |
| `export_rebrickable` | File › Export › Rebrickable parts list (.csv) | — | — | — | once a model | all | made once a model is done |
| `share` | File › Share | — | — | — | once a model | all | a link once a model is done |
| `together` | File › Build together | — | — | — | rarely | all | a session started once |
| `comments` | File › Comments | — | — | — | rarely | all | read when someone comments |
| `clear` | File › Clear the baseplate | — | — | — | rarely | all | takes the whole model away; a key would be too easy to hit |
| `account` | Brickworks › Account | — | — | — | rarely | all | help and the app itself, not building |
| `select_submodel` | Edit › Select by › Same sub-model | — | — | — | a few times a model | all | only on a model with sub-assemblies |
| `lock` | Edit › Lock the selection | — | — | — | a few times a model | Studio | under Studio's keys only: L is Studio's Hide tool, and Studio has no lock |
| `paint` | Edit › Paint the selection | — (Studio leaves Paint with none) | — | — | every few minutes | Studio, LDCad | under Studio's keys, as Studio has none; under LDCad's, C centres the view |
| `printed_versions` | Make › Printed versions | — | — | — | rarely | all | a maker of its own, opened once for what it makes |
| `brace` | (no menu row) | — | — | — | rarely | all | asks Claude to brace a weak part; on the part's own menu while Stress shows it weak |
| `step_new` | Build › Build steps › New step from selection | Ctrl-T, Add a step | — | — (its Ctrl-Insert appends a step: Next step here) | every few minutes | LDCad | under LDCad's keys only: Shift-N leaves nesting, and Ctrl-Insert ends a step |
| `booklet_turn_left` | Build › Booklet page › Turn the view left | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_turn_right` | Build › Booklet page › Turn the view right | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_tilt_up` | Build › Booklet page › Look from higher | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_tilt_down` | Build › Booklet page › Look from lower | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_this_view` | Build › Booklet page › Use this view for the step | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_usual_view` | Build › Booklet page › Usual view | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_zoom_in` | Build › Booklet page › Zoom in | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_zoom_out` | Build › Booklet page › Zoom out | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_bigger` | Build › Booklet page › Bigger on the page | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_smaller` | Build › Booklet page › Smaller on the page | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_new_page` | Build › Booklet page › Start a new page | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_alone` | Build › Booklet page › A page alone | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_parts` | Build › Booklet page › Parts list | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_callout` | Build › Booklet page › Callout | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_per_page` | Build › Booklet page › Steps a page | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_lay_out` | Build › Booklet page › Lay out the page | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_highlight` | Build › Booklet page › Outline new parts | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_pull` | Build › Booklet page › Pull out the selected parts | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_colours` | Build › Booklet page › Colour guide | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_actual_size` | Build › Booklet page › 1:1 guide | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `booklet_preview` | Build › Booklet page › Sub-model preview | — (its Instruction Maker keys only A and D, a step's page) | — | — | while a booklet is laid out | all | a step's look in the booklet, set while one is laid out; most are buttons on the timeline's Booklet row too |
| `flex` | Make › Hose, tube or chain | — | — | — | a few times a model | all | a hose or chain once in a while; no field tool keys it |
| `reshape_flex` | Make › Reshape the hose or chain | — | — | — (Ctrl-F5 makes its path parts again) | a few times a model | Brickworks, Studio, LDCad | only with a hose or chain; Mecabricks' F under its keys |
| `fit_selection` | View › Fit the selection | — | — | C, centre on the selection | every few minutes | Brickworks, Studio, Mecabricks | F, Fit, fits the selection when there is one; LDCad's C under its keys |
| `fit` | View › Fit | — | — | — (its Z fits the model) | every few minutes | Mecabricks | under Mecabricks' keys only: F reshapes a hose, as Mecabricks' does |
| `floor_16` | View › Floor › Baseplate 16 × 16 | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_32` | View › Floor › Baseplate 32 × 32 | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_48` | View › Floor › Baseplate 48 × 48 | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_custom` | View › Floor › Baseplate, other size | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_grid` | View › Floor › Grid floor | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_none` | View › Floor › No floor | Ctrl-B, hide the ground (a switch) | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_2` | View › Floor › Baseplate colour › Green | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_10` | View › Floor › Baseplate colour › Bright Green | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_288` | View › Floor › Baseplate colour › Dark Green | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_19` | View › Floor › Baseplate colour › Tan | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_28` | View › Floor › Baseplate colour › Dark Tan | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_71` | View › Floor › Baseplate colour › Light Bluish Grey | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_72` | View › Floor › Baseplate colour › Dark Bluish Grey | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_378` | View › Floor › Baseplate colour › Sand Green | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_1` | View › Floor › Baseplate colour › Blue | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_15` | View › Floor › Baseplate colour › White | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_0` | View › Floor › Baseplate colour › Black | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_colour_7` | View › Floor › Baseplate colour › Light Grey | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_part` | View › Floor › The baseplate is part of the model | — | — | — | once a model | all | set once; the floor stays as it is |
| `floor_default` | View › Floor › Start new models on this floor | — | — | — | once a model | all | set once; the floor stays as it is |
| `cut_x` | View › Cut away by › A plane along X | — | — | — | a few times a model | all | K cuts away and Shift-K flips it; the axis is picked once a cut |
| `cut_y` | View › Cut away by › A plane along Y | — | — | — | a few times a model | all | K cuts away and Shift-K flips it; the axis is picked once a cut |
| `cut_z` | View › Cut away by › A plane along Z | — | — | — | a few times a model | all | K cuts away and Shift-K flips it; the axis is picked once a cut |
| `cut_ghosts` | View › Cut away by › Leave a ghost of what is cut away | — | — | — | a few times a model | all | K cuts away and Shift-K flips it; the axis is picked once a cut |
| `cut_grow` | View › Cut away by › Grow it a plate | — | — | — | a few times a cut | all | the wheel over a knob, or a knob dragged, sizes the shape a face at a time; Grow is the strip's button |
| `cut_shrink` | View › Cut away by › Shrink it a plate | — | — | — | a few times a cut | all | the wheel over a knob, or a knob dragged, sizes the shape a face at a time; Shrink is the strip's button |
| `stress` | View › Stress | — | — | — | a few times a model | all | Alt-K checks stability; Stress is the colour of it, looked at after |
| `stud_map` | View › Stud directions | — | — | — | once a design | all | a check of which way studs face, looked at once and put away; it shares Stress's layer, and Stress has none either |
| `panel_parts` | View › Parts bin | — | — | — | once a session | all | a panel set once a session, and it stays |
| `panel_assistant` | View › Assistant | — | — | — | once a session | all | a panel set once a session, and it stays |
| `panel_properties` | View › Properties | — (Instruction Maker's inspector, Ctrl-Alt-2) | — | I, the information panel | once a session | all | a panel set once a session; I is X-ray here, used far more |
| `show_properties` | (no menu row) | — | — | — | rarely | all | on a part's own menu, in no menu of the bar |
| `panel_keys` | View › Key strip | — | — | — | once a session | all | a panel set once a session, and it stays |
| `collection` | File › My collection | — | — | — | rarely | all | the person's own bricks, looked at between builds |
| `collection_need` | Build › What do I need? | — | — | — | rarely | all | the person's own bricks, looked at between builds |
| `collection_build` | File › What can I build? | — | — | — | rarely | all | the person's own bricks, looked at between builds |
| `leave_assembly` | Build › Done editing the sub-assembly | — | — | Shift-N, leave nesting | a few times a model | Brickworks, Studio, Mecabricks | Esc leaves it once nothing else is up, and Esc is nobody's to set; LDCad's Shift-N under its keys |
| `make_unique` | Build › Make this copy unique | — | — | — | rarely | all | a big model's sections, now and then; Y and Shift-Y are the ones used often |
| `suggest_sections` | Build › Suggest sections | — | — | — | rarely | all | a big model's sections, now and then; Y and Shift-Y are the ones used often |
| `evaluate_section` | Build › Evaluate the section | — | — | — | rarely | all | a big model's sections, now and then; Y and Shift-Y are the ones used often |
| `put_back` | Build › Put every section back | — | — | — | rarely | all | a big model's sections, now and then; Y and Shift-Y are the ones used often |
| `panel_outliner` | View › Model tree | — | — | — | once a session | all | a panel set once a session, and it stays |
| `minifig` | Make › Minifigure builder | — | — | — | a few times a model | Mecabricks, LDCad | under Mecabricks' and LDCad's keys M is their Move |
| `mosaic` | Make › Mosaic from a picture | — | — | — | rarely | all | a maker of its own, opened once for what it makes |
| `part_maker` | Make › Part maker | — | — | — | rarely | all | a maker of its own, opened once for what it makes |
| `print_part` | Make › Print on a part | — | — | — | rarely | all | a maker of its own, opened once for what it makes |
| `sticker` | Make › Put a sticker on | — | — | — | rarely | all | a maker of its own, opened once for what it makes |
| `mode_select` | Tools › Select tool | V, Default select mode | — | — | every few minutes | LDCad | under LDCad's keys only: V is LDCad's projection |
| `mode_pan` | View › Pan tool | — | — | — | a few times a session | Studio, LDCad | under Studio's keys H is Hinge; under LDCad's H hides |
| `mode_zoom` | View › Zoom tool | — | — | — | a few times a session | LDCad | under LDCad's keys only: Z fits, as LDCad's does |
| `hidden_colours` | Tools › Colour the hidden parts | — | — | — | once a model | all | a big model's hidden parts, coloured once |
| `reseat` | Tools › Seat parts on their studs | — | — | — | rarely | all | a repair after an import |
| `connector` | Tools › Connect your AI | — | — | — | rarely | all | set up once |
| `tour` | Help › Take the tour | — | — | — | rarely | all | help and the app itself, not building |
| `check_updates` | Help › Check for updates | — | — | — | rarely | all | help and the app itself, not building |
| `reinstall` | Help › Reinstall Brickworks | — | — | — | rarely | all | help and the app itself, not building |
| `restart` | Help › Restart Brickworks | — | — | — | rarely | all | help and the app itself, not building |
| `docs` | Brickworks › Documentation | — | — | — | rarely | all | help and the app itself, not building |
| `website` | Brickworks › Brickworks website | — | — | — | rarely | all | help and the app itself, not building |
| `beta_hub` | Brickworks › Beta hub | — | — | — | rarely | all | help and the app itself, not building |
| `feedback` | Brickworks › Send feedback | — | — | — | rarely | all | help and the app itself, not building |
| `about` | Brickworks › About Brickworks | — | — | — | rarely | all | help and the app itself, not building |
| `back_to_site` | Brickworks › Back to brickworks.diy | — | — | — | rarely | all | help and the app itself, not building |
