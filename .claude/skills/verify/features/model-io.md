# Model I/O

Whether what you built is still there tomorrow, and still means the same thing.

<!-- covers: lib:save and reopen, lib:ldr read and write, cli:export a model, ui:seat an old model, ui:picture of the model, ui:parts lists for shops, ui:open a studio model, ui:save as a studio model, ui:open an ldd model, ui:3d model export, lib:a session per tab, ui:reload a model saved elsewhere, cli:tabs browser flow, cli:two windows check, ui:new tab or window, cli:new window probe, cli:new tab browser flow, lib:model versions, ui:versions of a model, lib:browser keeps the models, ui:models may be cleared warning, cli:versions probe, cli:empty save probe, cli:autosave paths probe, cli:keep browser flow, ui:working model that could not open, cli:unrestored probe, cli:cad task test, cli:round trip probe, cli:fidelity probe, cli:flex skin probe, cli:flexible parts in a browser, cli:carried fetch probe, cli:carried parts at once, cli:worker first run, cli:table race, cli:carried parts in a browser, cli:LDraw files in storage, cli:own copies read as their parts -->

## Sub-features

- `save and reopen`: the app writes what is on the baseplate to `user://` and
  restores it on start-up — bricks, colours, orientations, sections and the
  camera. Written 2.5 s after a change settles, and as the app closes, so an
  edit made just before is kept (view's `quitting cleanly`, `quit_probe`). The Open list counts a model as the app does once it is open
  (`ModelStore.count_in`): each copy of a sub-model as its parts, a made part as
  one. It counted a sub-model's reference as a brick, "My House — 14 bricks" of
  a house the app called 13; `store_probe` checks both against what opens. A design that fails must leave the model it was asked to change alone.
  What the model stands on goes with it (`ModelFloor`, see [building](building.md)
  `floor`): `0 !BRICKWORKS FLOOR BASEPLATE 32 32 288`, `GRID` or `NONE` in the
  head of the model, in the autosave, saves, LDraw and Studio exports and the
  text a shared link carries, and is read back on open; a file without it gets
  the floor new models start on. `floor_probe` round-trips each.
- `working model that could not open` (`ModelStore.restore`,
  `src/ui/restore_notice.gd`): at start-up a working model none of whose parts
  can be had (not in this build's catalogue, or not LDraw) is kept as it was,
  among the saved models as "<its name> - could not open", or nowhere new when
  it is saved as it is already; the window says so above the model, with where
  it is, until "Got it". The sample car then opens. Before 2026-10-14 the car's
  autosave went over it a few seconds later and nothing was said. A model
  whose parts are on their way (on the web, not fetched yet) counts as
  restored, so the car is not opened over it. `unrestored_probe` plays the
  start-up as Main does and fails on 480b81a (8 failures).
- `ldr read and write`: real LDraw `.ldr`. Written files open in other LDraw
  tools, and files from them open here. A file's own build steps (`0 STEP`,
  `0 ROTSTEP`, a sub-model's steps of its own and the step each copy of it is
  put on in) are kept through open, edit and save, `.io` and `.lxf` alike,
  since all open through `open_text`: see "the author's steps" in
  [view](view.md). They were read and dropped, and saving wrote Brickworks's
  own order over them.
- `someone else's file kept` (`src/parts/source_file.gd`, `SourceFile`;
  `ModelStore._source_text`, 2026-10-16): a file whose `0 Author:` is not
  Brickworks (the LDraw model repository, Studio, LDCad, LeoCAD, an `.io`)
  is kept when it opens, and every save of it (Save, the autosave, Export,
  `.io`, a share link, `save_model` over MCP: all `ModelStore._text_into`) is
  that file again with only what changed. Each part on the baseplate is paired
  with the line it was read from by what it is (number, colour, place in the
  file's coordinates, sub-model copy), never by id, so undo, a move by picking
  up and an edit over MCP pair alike. A part as it was keeps its line byte for
  byte; moved, turned, recoloured or swapped, its line is rewritten in place,
  in its sub-model's frame, under the number the file used when it is the same
  part (`30028` stays `30028`, placed where its stub puts `30028b`); taken
  away, its line goes; added, a line at the end of its step in its sub-model.
  Lines the app does not read (author, `!LICENSE`, `!HISTORY`, `BFC`, LDCad's
  `!LDCAD` blocks, comments, the parts a file carries) are never touched. The
  lift that stands a model on the ground is the view's: taken off again on
  every save, so the file keeps its coordinates (whole-model saves too).
  What cannot be one line is written whole (`write` returns null): a copy of
  a sub-model changed apart from its other copies, an assembly made or
  renamed, steps given to a model that had none, a copy put in another step.
  Then the author's header lines are kept in place of `0 Author: Brickworks`
  (`SourceFile.header`, and `0 !BRICKWORKS WORKED_STEPS` when the steps are
  the app's), and what the app could not show is carried in
  (`SourceFile.carried_into`). Saved under another name, the name goes in a
  `0 !BRICKWORKS TITLE` line, the author's first line untouched. The app's own
  lines (floor, share, set) are the only lines added. A file Brickworks wrote
  (`0 Author: Brickworks`) is written whole, as before.
- `parts the app cannot show` (`ModelStore.unshown`, `SourceFile.unshown`):
  a part of the file the library has not got, a part the file carries that
  cannot be built (on the web, one drawn from an official part or subpart,
  which a build does not ship: 42082-1's 13971, 8202-1's 57719), or a
  flexible part whose skin cannot be built, is never dropped: it stays in the
  file and is saved back, and File, Open says how many and which, a flexible
  part once by its sub-model ("… (ropeLQ-1 (flexible))"). `fidelity_probe`
  checks it, and the cad task test counts a part lost on open only when it
  is neither shown nor kept.
- `flexible parts drawn` (`CustomParts.begin_skins`, `PartForge.build_skin`):
  LDCad writes a hose's, a rope's or a band's skin after `0 !LDCAD
  GENERATED` in its sub-model (primitives bent a segment at a time, a donor
  section, polygons), with the parts at its ends. Each such sub-model's skin
  is a part of its own (`<sub-model>-flex`, category Flexible, not in the
  bin, not kept), built from its own lines without its parts, each on a
  worker thread at high priority, begun before the file's carried parts are
  built and joined after (`CustomParts.begin_skins`, `end_skins`: the model
  opens with it; the pool's low side is the app's checks, busy for seconds;
  a `Thread` started for each hung a browser page, whose new workers start
  only when the page is free), and
  put in the sub-model as one piece paired with the GENERATED line: one
  piece a copy, in the copy's colour, in its step, selectable and hideable
  (a cover of 4-LDU blocks along its surface), its end parts parts still.
  Saved untouched the file is itself; the piece moved, recoloured, taken
  away or added writes the model whole (`SourceFile.write` returns null),
  the skin carried as `0 FILE <sub-model>-flex.dat` with its donors, which
  opens again as a skin (`0 !CATEGORY Flexible`). A generated copy of only
  parts (a pneumatic hose of 166 segments, a chain) has no skin: its parts
  were drawn already, and `Flex.items_in` reads it as one hose. Every build
  ships LDraw's primitives (`PartForge.SHIPPED`, copied by tools/export.sh),
  so skins and most carried parts build on the web and in a desktop
  download: 42082-1 in a browser went from 167 not shown to 3.
  `flex_skin_probe` proves the fixture and, given files, that every
  flexible part of each is drawn and the file saves as itself;
  `tools/web/flex_skin_flow.mjs` the same in a browser.
- `carried parts at once` and `worker first run` (`CustomParts._built_at_once`,
  `begin_skins`, `PartForge.warm`, `WorkerTasks.first_here`): the parts a
  file carries, and those kept in `user://custom_parts` at start-up, are
  built on every worker at once, and a file's skins each on a worker of
  its own. Godot 4.7.2 crashes when two threads run a GDScript operator on a
  value of no fixed type for its first time at once: it writes what the
  operator takes into the bytecode as it runs, the operand types before the
  function (`modules/gdscript/gdscript_vm.cpp:805-809`), and a thread in
  between calls address 0. The app went the moment it started with parts
  kept from files (a worker's GDScript backtrace at `PartForge._walk`'s
  `if source == null:`, and the crash handler, on the worker, saying `/root`
  cannot be told from it). So work about to run on several threads asks
  `WorkerTasks.first_here(kind, work)` first, which runs it once on the
  asking thread the first time in a run: the forge's part and skin
  (`PartForge.warm`, 60 ms once) before the carried parts and the skins, the
  first turned cover before the rest (`Builder.prepare_covers`,
  `Grab`'s grabbed parts). `carried_at_once_probe` builds files' carried
  parts at once round after round, each the same to the byte as built alone;
  `worker_first_run_probe` runs fresh scripts' cold operators on every worker
  at the same instant through first_here (and, with `-- cold`, without: the
  engine's crash, which it shows within ~4,000 rounds), and checks the warm-up
  goes all the way and that the carried parts ask for it.
- `own copies read as their parts` (`CustomParts.copy_of`, `read_as_copy`,
  `PartInfo.copy_of`, `PartLibrary.shaped_as`): Studio writes the parts it
  has versions of into the file as "<set> - <part>.dat", their subparts and
  primitives renamed the same way, so built from that text a copy has no
  joint and no exact shape. One named for a part the library has, and drawn
  as that part is to within 1 LDU (every corner of either's triangles to the
  other's surface, and its box), takes that part's connectors, cover and
  exact shape; its triangles and text stay its own. On the web the parts'
  geometry is fetched before the file opens (`_fetch_copied`). Every lookup
  of the gear table by part (gears, turntables, driving rings, racks,
  actuators, and Flex's sprockets) reads a copy as its part
  (`Mechanism.reads_as`, `entry_of`, `Racks.spec_of`), so a copied gear
  meshes. `own_copies_probe` opens 42125-1, then drives a copied gear in
  42121-1, 42083-1 and 42115-1 (Simulate's rate and Grab's turn at the
  teeth's ratio) and 42054-1's copied turntable top in Simulate; `-- --gears`
  lists every OMR copy of a part the gear table keys and whether it is read
  so (60 in 44 files, 55, ~1 min).
- `table race` (`Mechanism.table`, `Flex.kind_of_piece`, `Exact._sphere`,
  `Exact.shape_for`, `Style.norms`, `Collection._sizes`): a static table
  read at first use, and reached by a worker, is either made as its class
  loads or read and filled under a lock. Put on one thread while another
  copies it, the copy holds nothing: a session's look_at_model while a
  750-part model opened (Grab reading its joints on a worker) stopped the
  app at `mechanism.gd:78`, `Dictionary::is_empty` reading address 0x34
  (racefix, 2026-10-20). Warming a table on the main thread before a
  worker starts (`Assistant._checked`, `Sections`) covers only that
  caller's worker. `table_race_probe` lets a worker and the main thread go
  at once on each table, a run of the engine per try, and every run must
  stay up; on main before the fix 35 of 80 died on the gear table.
- `carried parts fetched` (`CustomParts.fetch_sources`, `unreached_by`,
  `PartForge.keep_fetched`): a part a file carries, or a skin, may be drawn
  from LDraw's own subparts and parts, which the desktop reads from
  `vendor/ldraw` and no build ships. On the web every open of a file
  (`ModelStore.open_text_fetched`, `open_fetched`, `restore_fetched`,
  `open_version`; the file picker, a saved model, an example, the start-up
  restore, a shared model, MCP's open) first asks `PartForge.unreached` what
  its carried parts and skins name that this build cannot read, and fetches
  those from `<PARTS_URL>ldraw/parts/<name>` six at a time, and what each
  names as it arrives (`_fetch_each`: every answer heard by a callable of
  its own, in any order; no time limit, as a mesh fetch has none, since a
  request is polled once a frame), the status bar's Working line saying
  "Fetching N LDraw files…". Kept for the session; a file not there
  (Supabase answers 400, a server 404) or a web page is not taken, and the
  part is said not shown with why (`CustomParts._with_why`; the flow prints
  the console's "could not fetch" lines). A carried print gets the file's
  subparts too (`PartPrints.build`'s others). A carried part the web kept
  (`CustomParts.dir`) that needs such files is built at start-up once they
  come (`load_all` defers it to `_load_later`). The desktop, and a file that
  carries nothing, wait for no frame. `tools/storage_ldraw.py` put the library's parts/
  (34,122 files, 495 MB) in the bucket, additive only; run it after
  `tools/fetch_data.sh` brings a newer library. `carried_fetch_probe`
  proves it with the library withheld (`PartForge.withheld`) and served by
  python's http.server on 8841: each file's carried parts as the desktop
  builds them, answers heard in any order, two files in one session,
  the start-up restore, a kept part at start-up, nothing fetched twice, 404
  and HTML refused;
  `-- --timing FILE` says what looking costs a file that needs nothing; `-- --census
  OUT.json` counts what every file in vendor/omr needs.
  `tools/web/carried_flow.mjs` opens files in a browser from a local export
  served by `tools/web/serve.py DIR PORT --parts-url "$PARTS_URL"` (the real
  bucket) and fails on a carried part said not shown, a console line saying
  one did not build, or a script error; `--reload` reloads after the last
  file and checks it, put back at start-up, builds again.
- `assemblies in the file`: a brick's `group` — the assembly a design named,
  tagged as the run ends (`Assistant._tag_assemblies`), or the sub-model it was
  read from — goes out as an `.mpd` with one sub-model per group, titled as the
  design wrote it ("north-east tower" in `north_east_tower.ldr`), and comes back
  in with every brick in its group. The booklet builds by those groups and names
  them. `store_probe` asserts the round trip and the named parts.
- `a session per tab`: every tab of the site in a browser (and every window
  of the desktop app) works on a model of its own (`src/parts/tab_session.gd`,
  `TabSession`, 2026-10-13). Its working model and its Claude connector live
  under `user://sessions/<id>/` (`ModelStore.autosave()`, `ClaudeConnector`'s
  file); the person's saved models and settings stay shared on purpose. The id
  is five letters and digits that cannot be misread (`TabSession.LETTERS`). On
  the web the page chooses it before the engine starts
  (`src/boot/shell.html`, `claimTab`): kept in sessionStorage (a reload keeps
  it, no other tab has it) and held with a Web Lock for the life of the page,
  one tab choosing at a time (`brickworks-claim`). A tab with none takes the
  most recently written session no open tab holds, so closing the browser and
  coming back tomorrow opens what was there; a duplicated tab, whose id its
  original holds, gets another; a shared model opened to look at
  (`?view=`) takes none. The one `user://autosave.ldr` and
  `claude_connector.json` from before go to the first tab to open, once
  (`brickworks.legacy` in localStorage). On the desktop a window holds a
  session by a folder with its process id in it, renamed into place (`_hold`:
  a rename onto a folder that holds something fails, so two windows cannot
  both win, and none ever sees a hold without its id — made empty and filled
  after, two windows started together both took one), refreshed every
  minute (`TabSession.still_here`), good for three minutes, gone at once
  where `/proc` says the process has, and let go on exit. Not
  `OS.is_process_running`, which knows only processes this one started and
  called every other window's hold gone. A run driven from the command line
  holds none (`TabSession.driven`). **Why the page had to change as well
  as the app:** the engine keeps user:// as a copy in memory and after each
  write makes IndexedDB match its copy wholesale (Emscripten's
  `IDBFS.reconcile`: every file it holds put back, every file it lacks
  deleted). So with two tabs open a model saved in one was deleted by the
  other's next autosave, a setting changed in one was put back, and both tabs
  reopened the one autosave under the last writer's name. The shell now stands
  between the engine and IndexedDB: a tab stores only files it changed itself
  (`seen`, the stored version its copy is), deletes only files it knew and
  nobody has changed since, never a folder with anything left in it, and says
  what it stored over a BroadcastChannel; the other tabs copy those files into
  their own user:// (`engine.copyToFS`), never over a write of their own still
  on its way (`brickworksWrote`, `brickworksWriting`). So Open lists a model
  another tab saved, and the parts bin's shelf another tab changed is read
  again before this one writes it (`PartShelf._read_at`, `reread`). A copy
  of another tab's file is never put back as this tab's (`pulled`, compared
  byte for byte).
- `reload a model saved elsewhere`: when another tab or window saves the model
  this one has open, this one is told and asked (`ReloadOffer`, a strip over the
  model like the seat offer: **Reload it** or **Keep mine**), never saved over
  in silence. `ModelStore.saved_elsewhere` compares the file of the model's name
  with what this tab last read or wrote of it (`know`: on open, on every save,
  and when the name changes), by time and then by its brick lines, so a save of
  the same bricks asks nothing; Main asks once a second
  (`_watch_other_tabs`). Saving over a file changed elsewhere since is refused
  with the reason in the bar (`refused`, `saved_by_another`), and the offer
  comes up; Keep mine takes the other's save as seen, and saving then replaces
  it, as the person chose.
- `tabs browser flow`: `tools/web/tabs_flow.mjs`, three pages of one browser
  context (one IndexedDB, one account): the house, the kart and the tree, each
  renamed by typing and with a part clicked and deleted; three ids, and each
  autosave in the browser's storage under its own session; each tab reloaded
  to its own name and part count, in the same session; a model saved in one
  still stored after the other two changed and autosaved theirs; and the tree's
  tab opening that saved model, the house's tab saving it again, and the tree's
  offered a reload that brings it in part for part; then Claude through the
  relay (see [web](web.md), "Several tabs, one account"): each tab's connector
  on by itself, `tabs` listing the three by the pages' ids and names, a look
  targeted at each answered by that page with its own part count, an edit
  targeted at the kart in the kart's page alone, and the tree's tab closed
  reported on the next call. On a local export (2026-10-13) all of it passes.
  Against the live build of before, it failed from the first step: no tab
  had an id or a session, and the house's tab, reloaded, showed the tree's
  model ("Tabs Tree"), then said its sign-in had ended.
- `two windows check`: `tools/windows_check.py`, the desktop's half, with real
  processes in a data folder of their own: a working model from before
  sessions in the folder; two headless apps started together hold a session
  each (each with its own process id) and only one takes the old model; each
  given a different model over its port autosaves into its own session; both
  stopped and started again one after the other, the first reopens the model
  written last and the second the other one, not the same one twice.
- `new tab or window`: File, New tab in a browser (New window on the
  desktop, Ctrl+Shift+N there; the browser keeps Ctrl+T, Ctrl+N and
  Ctrl+Shift+N) starts another model in a tab of its own, this one left as
  it is (`TabSession.open_another`, 2026-10-19). The owner asked how a person
  even starts a new model in another tab: there was no way from the app, and
  a tab opened by hand came up on the newest model no tab held. On the web it
  opens `?new=1` on the deployment's own path, in the click itself
  (`Shell.IN_THE_PRESS`: a browser opens a tab only in answer to one),
  `noopener` so the two pages do not share one thread; `claimTab` takes a new
  id at once for `?new`, never one another tab left, and takes `new` out of
  the address once chosen, so a reload keeps the tab's session as any tab's.
  On the desktop the app starts again (`OS.create_instance` with
  `TabSession.window_arguments`: `--path` when run from source, the renderer
  this window uses, `-- --new-session`; not this run's own switches, so not
  `--mcp` or `--model`), and `_claim_here(false)` takes a new session. Either
  begins on an empty baseplate, Untitled, its working model written at once
  (Main, `TabSession.opened_new`), and a working model with no parts comes
  back empty under its name (`ModelStore.left_empty`): it came back as the
  example car, so a reload after New, or of a new tab, showed the car. The
  window's own in `AppTools.WINDOW_ONLY` (no tool: a session works in the tab
  it is connected to); `command_probe` skips it, since it starts a window.
- `new window probe`: `tools/probe.sh new_window_probe` (headless). A session
  nobody holds with a tower of four, written moments before; the probe's
  window has the car. File's second row is New window, with its tooltip and
  Ctrl+Shift+N (Ctrl+N still New); pressing it starts a second process that
  holds a session of its own (its `/proc` command line has `--new-session`),
  not the tower's, its working model written at once with no parts and
  Untitled; the tower's session is still nobody's and unchanged, and the
  probe's window has its car. Then the same command line without the flag
  takes the tower's session, the newest no window holds. It stops both copies
  (every child of its process) by id. Not in the suite: two more copies of the
  app take ~20 s each to come up.
- `new tab browser flow`: `tools/web/newtab_flow.mjs`, against a local export
  (`node tools/web/relay_server.mjs 8890 --static=build/web`, `.env`
  sourced, signed in as the test account). An older tab renamed and closed,
  so its session is nobody's (stored, with its name on its
  `0 !BRICKWORKS TITLE` line: the example car keeps its own first line);
  tab A renamed. File > New tab clicked in A (the
  menu's second row, by position) opens B at `?new=1` on the same path; B has
  an id of its own (not A's, not the older one's), `?new` gone from its
  address, an empty baseplate, Untitled, and its empty working model stored
  under its session; A is as it was. B reloaded is B and still empty; a 2 x 4
  brick put down in it, stored, and B reloaded again keeps it. A third tab
  opened by hand takes the older model's session, as before. Pictures of the
  File menu at 1280 and 390 px wide (`1_file_menu.png`,
  `6_file_menu_390.png`).
- `a model's name, and a new one`: `ModelStore.title` is the model's name — set
  by Save, read from an opened file's first line (a placeholder such as
  "Working model" falls back to the file name, the autosave's to Untitled), and
  written into the autosave, so the app reopens a saved model under its name.
  It wrote "Working model", and the bar took no name from what it opened: the
  owner reloaded a saved, named model and was shown Untitled. The name shows in
  the browser tab and the window title (`Main._show_name`). A click on it takes
  the whole name, so what is typed replaces it (`select_all_on_focus`): it
  put the caret at the end, and "Untitled" typed over came out "UntitledMy
  House" (2026-10-12); `handbuild_probe` checks the name is what was typed.
  New (Ctrl+N on the
  desktop) begins an empty baseplate, Untitled, with a fresh chat; it asks first
  when the model is not saved as it stands (`has_unsaved_work`: Untitled with
  bricks, or bricks unlike the saved file's). An example as it shipped — the
  first visit's car — is nobody's work: untouched (nothing to undo since it
  opened), New asks nothing; it asked whether to save the car. There was no way to begin another
  model. `project_probe` (headless; puts this machine's autosave back) and
  `tools/web/project_flow.mjs` (types a name, saves, waits until the save and
  the named autosave are in the browser's storage, reloads, reads the tab,
  presses New). On the web the engine titles the page itself as it starts, after
  the restored model was named, so `_tell_page` puts the title back when it has
  drifted. New work begins a new model (`ModelStore.begin`) named for itself:
  the example car taken off for a design (named for its brief, then its own
  title) or a brickified model (its file's name), a design or Brickify on a
  bare Untitled baseplate, and `clear_model` from a session (Untitled). A name
  a saved model has gets a number ("Tower 2"), so new work never saves over it.
  The example kept its name through all of these, and Save saved a tower as the
  example. Clear keeps a person's own name, but not an example's
  (`ModelStore.example`, set by opening one from `res://models/`). New goes
  through `begin` too. `example_name_probe` takes the car off every way there is
  and checks the bar, the store, the window title and the file Save writes.
  A save on the web is in IndexedDB only once the engine's sync has run: 25 to
  52 s at a load of thirty to eighty drawing in software. So the page
  watches for it: the store reports each write (`_tell_page_wrote`), the shell
  polls IndexedDB until that path holds that many bytes written since
  (`brickworksWrote`, `brickworksStored`, `brickworksUnstored`), the bar says
  "saving … in this browser" until then and "saved" after, and closing the tab
  with a write on its way asks first (`beforeunload`). The flow checks the page
  sees the save land and that closing mid-save asks.
- `made parts in the file`: a model that uses a part made in the element
  maker carries it as an LDraw `0 FILE bw-….dat` section, and opening one
  builds the part first — see [elements](elements.md). `element_probe` saves
  three, reopens them into a fresh library, and has the Python reader check
  the file.
- `one way to open a model`: the first visit's sample, `--model`, a restore,
  the Open menu and an imported file all open through `ModelStore.open_text`.
  A model below the ground comes up by `lift_for`, worked out before anything
  is placed from the catalogue's bounds of every part, so it is the same lift
  whatever geometry has arrived; parts not yet fetched wait in `store.awaited`
  and are put down as they arrive (`place_awaited`, from `Main._on_part_fetched`),
  never into a world cleared since. Except a part turned off the grid, whose
  box hangs below it where it does not fill it (`Lbm.PartMesh.lowest_at`, read
  off its cover): a car whose wheels are drawn spun on their axles stood on its
  tyres' boxes 8 to 12 LDU up, and every part of 8281's sidecar floated. Where
  such a part's geometry has not arrived (the web, outside the pack) the box
  stands in, and once the last awaited part lands the model comes down to the
  height a desktop opens it at (`ModelStore._settle`), before it is whole and
  saved. And a file another tool wrote (its `Author` not Brickworks) comes down
  by whole cells when it is drawn up in the air, since its origin is that
  tool's: 30285's dinosaur is drawn 21 LDU up, and every part of it floated; one
  this app saved keeps its height. `joints_probe` ("stood on the ground by its
  shape") opens a wheel spun 16 degrees on its axle both ways and with its tyre
  fetched late, and two bricks drawn 76 LDU up, by another tool and by this one.
  A part a
  file carries is built from its carried subparts and primitives as well (see
  [elements](elements.md), `made parts in the library and in files`). There were two ways: the app's own opened
  the sample without lifting it, so on the web a first visit saved the car
  buried to its axles, a reload lifted it a brick, and New said it had changed;
  the store's lifted it and dropped parts still arriving. `project_probe` opens
  every shipped model as a first visit does and checks its lowest occupied cell
  is on the ground; `open_probe` (network) opens them all over the wire.
- `export a model`: `--model=<in> --out=<out>` opens, re-exports and quits, which
  is also the shortest round-trip proof there is. Export, the booklet and the
  parts list are written to Downloads under the model's name, which a design
  sets, so only the name's last part is used (`Download.give`, `ModelBar`): a
  title with "../" in it wrote outside the folder. `store_probe` names a download
  to climb out and checks it lands inside.

- `seat an old model` (`src/ui/seat_offer.gd`, `src/assembly/seating.gd`): a
  model saved before 2026-10-10 can carry parts drawn inside their footprint a
  tenth of a stud off their studs. Opening one (or the one restored at start)
  says how many, over the top of the model, with one choice: *Seat them on
  their studs*, which moves each as one undoable step, or *Leave them*. A part
  is moved only where undoing exactly the old corner's error puts its studs on
  stud middles. `src/dev/reseat.gd` does the same to files, by the same rule.
- `open a studio model` (`src/parts/studio_io.gd`, `src/ui/model_file_picker.gd`):
  File, Import → BrickLink Studio model (or Open → From a file) reads Studio's
  `.io`, on the desktop and in a browser (read as bytes). Two files Studio saved
  were opened to learn the format (2.2.1, 2021, locked; 2.25.2, 2025, not
  locked; neither kept, neither ours): a zip holding `model.ldr` (plain LDraw,
  LDraw's colour and part numbers, `0 FILE` sub-models, `0 STEP`, a byte-order
  mark and CRLF), `model2.ldr` (the same model in **BrickLink's** numbers —
  white 1, black 11, tile 3068 — carrying every part's geometry),
  `modelv1.ldr`/`modelv2.ldr` (Studio's own `10`/`11` lines), `.info`
  (`{"version":"2.25.2_1","total_parts":1500,…}`), `thumbnail.png`,
  `errorPartList.err` (`[]`) and `CustomParts/`. Only `model.ldr` is read,
  through the LDraw reader, so no colour needs mapping. It read `model2.ldr`
  first and opened a real set in BrickLink's colour numbers read as LDraw's;
  its fixture had been made by hand with LDraw's numbers in `model2.ldr`. A
  locked zip is opened by hand (Studio's published password, PKWARE's cipher,
  its check byte refusing any other password; then raw deflate wrapped as
  gzip), and so is one locked with WinZip's AES-128 or 256 (`StudioIo._aes`:
  PBKDF2-HMAC-SHA1, AES-CTR on a little-endian counter, its HMAC checked; AE-2
  states no CRC, so it inflates through `StreamPeerGZIP`, whose buffer has to
  hold the whole output or it takes nothing in), which some early Studio
  builds wrote by another reader's account. `io_probe` opens libarchive's own
  AES-256 test file (`libarchive_aes256.zip`, BSD-2, docs/ATTRIBUTION.md) with
  libarchive's password to its stated 6,818 bytes, then `bay_aes.io`. Studio's
  "Untitled Model" first line is no name: the file's name is used. Studio
  names a part it drew itself `bl_<BrickLink number>`; where the library has
  that number it is that part (`ModelStore.studio_part`: bl_5095 is 5095);
  otherwise it comes from the file itself, with its picture (2026-10-14:
  `StudioDecor.carried`, from `model2.ldr`'s flattened copy or `CustomParts/`;
  see [prints](prints.md)), and what still cannot be had is left out and named
  in the status bar — every opened file's missing parts are named so (`open_text`'s
  `missing_ids`). The 2025 set placed 1,498 of 1,501 with three BrickLink-only
  prints named; it now places all 1,501 with the three prints drawn
  (`decor_probe -- --real=`). The 2021 one all 103. Since 2026-10-19 any other
  part the library has not got as one of its own comes from the file too (the
  picker hands `StudioIo.read` the library; `StudioDecor.carried`): a part newer
  than the library, which `model.ldr` names by LDraw's number and `model2.ldr`
  carries by that number or by BrickLink's, found then by the line of
  `model2.ldr` that puts a part where `model.ldr`'s line does
  (`StudioDecor.bricklink_names`; lines that do not match map nothing). Its
  colours are BrickLink's there and come out LDraw's (`_colour`, through
  `colors.json`'s `bricklink`). `whole_2025.io` (a `bl_` print, a Part Designer
  decal, `3070bpr9104` carried as BrickLink's `3070bpb9104`, and `65999`) placed
  4 of 6 before and 6 of 6 since, each print drawn, BrickLink's black (11) as
  LDraw's 0 and not light turquoise; saved as `.mpd` it carries all four, and
  opens whole into a library that has never seen them (`io_probe`, and
  `io_flow.mjs`'s last step in a browser, `4_whole.png`). `bay_2025.io`'s Part
  Designer part (a `1 16 … 3001.dat` in `CustomParts/parts/`) is built where the
  checkout has the LDraw library and named as left out where it has not (the
  web build): `io_probe` and `handbuild_probe` expect whichever this checkout can do.
  `tests/fixtures/studio/make_fixtures.py` makes `bay_2025.io` and
  `bay_2021.io` (locked by the system's `zip -P`) in those two shapes, and
  `bay_aes.io`, with `model2.ldr` in BrickLink's numbers so reading the wrong
  member fails, and `whole_2025.io` (`make_fixtures.py whole`). A damaged member makes Godot print `ERROR: Condition "err !=
  1"` from its inflater: expected in `io_probe`'s refusals, not a failure.
- `save as a studio model` (`src/ui/exports.gd` `studio_io`, `StudioIo.pack`):
  File, Export → BrickLink Studio model (.io) writes `<name>.io` (downloaded in
  a browser, to Downloads on the desktop): `model.ldr` (the model's LDraw with
  its build order, CRLF), `.info` (`total_parts`, and the version of the older
  Studio read, 2.2.1), `errorPartList.err` and an 800 x 600 thumbnail drawn by
  `Picture` (none in a headless run), deflated, not locked, as Studio 2.25
  writes its own. The zip is built in memory (Godot's ZIPPacker writes only to
  a path); deflate and CRC come from Godot's gzip. **Not seen opening in
  Studio** — there is no Studio on this machine — so nothing of Studio's own
  (`model2.ldr`, `modelv2.ldr`) is guessed at; `model.ldr` is standard LDraw,
  which Studio's own LDraw import reads. `io_probe` checks Godot's zip reader
  and the system's `unzip -t` open it, and the round trip: the castle out to
  .io and back is the same parts, colours, places and sub-models, the .io
  carrying its LDraw and 510 steps exactly. That claim was the zip's: what
  went in came out. The steps were lost on either side of it — dropped on
  open, worked out afresh on save — so a Studio model's steps never reached
  the file. `io_probe` now opens `gatehouse_2025.io` (made by
  `make_fixtures.py` from `tests/fixtures/steps/gatehouse.mpd`) and the
  `.mpd`, saves, packs as .io, reads and opens again, and compares every
  sub-model's steps with the author's.
- `3d model export` (`src/parts/mesh_export.gd`, `Exports.model_3d` and
  `ask_model_3d` in `src/ui/exports.gd`; File, Export → 3D model (.glb, .gltf,
  .obj, .stl)…, and `export_model` format `glb`/`gltf`/`obj`/`stl` over MCP):
  a dialog with GLB chosen (or the format chosen last) and a line on what each
  is for and, for OBJ and STL, the cap and this model's triangles; Export
  writes it with the Working bar and Cancel. Real size: glTF and OBJ in
  metres with +Y up, STL in millimetres with +Z up for a slicer. **glTF is
  written by hand, not by `GLTFDocument.append_from_scene`**: measured on
  4.7.2 it writes a mesh for every `MeshInstance3D` (a thousand instances of
  one box came out as a thousand meshes), a `MultiMesh` comes out in one
  colour, and an `ImporterMeshInstance3D` not at all, all in one call no
  frame can be given back from. Here each shape is written once, a mesh is a
  shape in a colour sharing its data (glTF's own instancing, read the same by
  Blender, three.js and Godot), every part is a node (its matrix; extras
  `ldraw_part`, `ldraw_colour`) under a node per sub-model
  (`Assemblies.path_of`), and colours are `MeshExport.material_for`'s
  `StandardMaterial3D` (colors.json's colour turned linear, a see-through
  colour's alpha with `BLEND`, roughness and metallic from the finish as the
  plastic shader has them, `doubleSided` for a two-sided surface). OBJ writes
  every part as an object with its own vertices and an MTL (Kd, d, Pr, Pm,
  Ns); STL is binary (a fifth of text's size), one mesh of every part's
  triangles. In a browser it is a download, an OBJ and its MTL as one zip
  deflated a slice at a time (`MeshExport.zip`, `StudioIo.zip` taking a
  member already deflated); on the desktop it goes to Downloads. A part with
  no shape here (on the web, one still arriving) is left out and named. Caps
  (`MeshExport.most_triangles`), as OBJ and STL cannot share a shape: OBJ
  1,000,000 triangles (about 106 bytes a triangle, held twice over while a
  browser zips it, in a tab whose heap stops at 2 GB), STL 3,000,000.
  Measured 2026-10-13 headless on this box at load 16, every slice timed
  (`mesh_export_probe -- --orthanc`): Orthanc (9,429 parts, 2,575,061
  triangles, 101 shapes) as GLB 0.4 s, 4.7 MB, 221 meshes, no frame held
  past 63 ms; as .gltf 0.5 s, 5.5 MB, 114 ms; as STL 2.5 s, 123 MB, 187 ms,
  which is the one 123 MB buffer being had at all; as OBJ, past its cap by
  the probe, 22.9 s and 273 MB with the process at 987 MB. The castle's 1.59
  million triangles as OBJ: 8.9 s, 162 MB. What held frames before they
  were sliced: `JSON.stringify` of Orthanc's whole document (300 ms; each
  node is now its JSON as it is made), a loop turning a baseplate's 100,000
  triangles round (`indices.reverse()` does it natively), and a big shape's
  OBJ lines or STL corners written in one go. In three.js (r182, Chromium on
  SwiftShader) the car's GLB, .gltf, OBJ and STL, the castle's GLB and STL
  and Orthanc's GLB all load with no error and look like the model: the
  same triangles, colours, see-through glass, standing up. STL closed
  volumes: 54 of the car's 61 parts are closed, and the other 7 have gaps in
  LDraw's own geometry (4600 is open underneath by 0.8 mm, 3829c01 by
  1.6 mm), written as LDraw draws them, for a slicer to mend; the probe
  checks the file adds no gap the part does not have.
- `open an ldd model` (`src/parts/ldd_lxf.gd`, `src/ui/model_file_picker.gd`):
  File, Import → LEGO Digital Designer model, or Open → From a file, reads
  LDD's `.lxf` (a zip around LXFML; the zip is read by `StudioIo`'s reader) or
  a bare `.lxfml`, on the desktop and in a browser. Each part's design number,
  material and bone are turned into an LDraw line by `assets/ldraw/ldd.json`,
  which `tools/ldd_map.py` derives from the community's `ldraw.xml`
  (`tools/fetch_data.sh` fetches it; docs/ATTRIBUTION.md): M = R r⁻¹, LDraw's
  matrix A M A and position 25 A (T − M t), A = diag(1, −1, −1) — the sum
  lxf2ldr and LeoCAD do. A part the table cannot place is left out, named in
  a comment in the LDraw text and in what the status bar says ("2 LDD parts
  with no LDraw match left out (999999 ×2)"); a colour it has no match for
  is light bluish grey, and said. `src/dev/lxf_probe.gd` opens
  `src/dev/fixtures/49311_test.lxf`, saved by LDD 4.3 (sttng/LDD, MIT), and
  checks every part where LDD put it — plate on the ground, courses a brick
  apart, every brick on the plate's studs, four positions worked by hand —
  then writes the house and the castle as LDD would and reads them back to
  the same placements, all 2,438 of the castle's that LDD has numbers for.
- `picture of the model` (`src/ui/picture.gd`, File, Export → Picture): the model
  alone — no baseplate unless it is part of the model, no ghost, outline or grid
  — from the view's direction, framed to
  fill a 2400 x 1600 PNG on a clear background, drawn by a SubViewport looking at
  the same world with a copy of the scene's environment that clears instead of
  drawing the sky. Downloaded in a browser, written to Downloads on the desktop.
  Framed on what is drawn (`Picture._frame`): every part's box corners, seen
  from an eye as far back as a ball round the model needs, and the lens
  shifted and narrowed so they sit in the middle and fill 90% of the narrower
  way. The share card and the Studio thumbnail are the same picture at other
  sizes. `centring_probe` measures all three, with either column folded. In a
  browser, `share_flow.mjs` on a local export (2026-10-13) got a card
  (`og_image.png`) with the car's middle 0.0% off the picture's, filling 88%.
- `parts lists for shops` (`src/assembly/shop_lists.gd`, File, Export → BrickLink
  wanted list / Rebrickable parts list): BrickLink's wanted-list XML (item, its
  colour number, quantity) and Rebrickable's `Part,Color,Quantity` CSV. The
  BrickLink colour numbers are colors.json's `bricklink`, 197 colours from
  `tools/bricklink_colours.py` (see [parts](parts.md)); a lot in any other
  colour, or a made part, is left off and the status bar says how many and names
  the colours ("BrickLink has no number for Pearl Red"). Parts go out under each
  shop's own number where LDraw's `!KEYWORDS` record one
  (`PartLibrary.shop_part`, `Inventory.Lot.bricklink_id` / `rebrickable_id`:
  3069b is BrickLink's 3069, 3711 Rebrickable's 3711a), else LDraw's, less a
  formed shape's `-f1`.
- `flexible parts counted as sold` (`Inventory.of`): a sub-model whose bricks
  are all one swept kind's segments (`Flex.items_in` — as the flex tool lays
  one and as Studio and LDCad write one) is one lot of the kind's straight part
  nearest its length (`Flex.real_part`): a 9L ribbed hose of 29 pieces is one
  71917 (BrickLink and Rebrickable 78c09), a 9L pneumatic tube one 21826-f1
  (BrickLink 21826, Rebrickable 5102c09.375), the flexible axle one 72892
  (BrickLink x334c01), the 41L string one 71149 (x127c40pb01, 14226c41). A
  chain or a tread stays its links. A segment loose in the model is itself.
  The counts line (`Inventory.pieces_in`, `Main._on_rebuilt`, counted once a
  change: 15 ms over Orthanc's 9,429 parts, and the build animation redraws
  every frame), the booklet's
  piece count and its parts boxes (`Inventory.key_of`: the item's first piece
  stands for it) and the shared link's count (`api/share.js`, `FLEX_PIECES`)
  say the same number. `inventory_probe` ("flexible parts, counted as they are
  sold") lays each kind and a chain, checks the list, both shop lists, a file
  round trip, and runs the server's own `checkModel` on the written file.
- `model versions` and `versions of a model` (2026-10-14,
  `src/parts/model_versions.gd`, `src/ui/versions_dialog.gd`): every save
  (Save, Save as, a copy, `save_model` over MCP) is also kept under
  `user://versions/<model>/<ms>-<parts>-<bytes>.ldr.gz`, gzipped, the last 20
  of each model, all of them under 16 MB together (oldest first, never a
  model's newest). A save that changes nothing keeps no second copy. File,
  Versions… lists the model on the baseplate's, newest first, and Open on one
  puts it there under the model's name (`ModelBar.open_version`), so Save
  makes it the newest; with changes not saved it says so, with Save beside it.
  `open_model` over MCP lists them (`versions=true`) and opens one
  (`version=N`). File, Export, All my models (`Exports.all_models`,
  `export_model all_models`) downloads every saved model in one .zip.
- `the empty-save guard` (`ModelStore._write`, `ModelStore.emptied`): no
  write of a model with no parts goes over a file with parts unless the
  person emptied the baseplate (Clear, New, their own edit taking the last
  part off). The autosave wrote whatever the baseplate held a few seconds
  after any change, an empty one too.
- `the autosave of a model short of a part` (`ModelStore.tick`,
  `ModelStore._text_into`): a model with parts not yet fetched, that never
  come (`ModelStore.awaited`), or that the catalogue has not got
  (`ModelStore._absent` for the app's own file; `SourceFile` keeps someone
  else's) is autosaved like any other, those parts written where the file had
  them, and reopens with every part, the missing ones awaited and put down when
  they come. Until 2026-10-20 the store wrote nothing of such a model (the flag
  `whole`, now gone), so one part that never came lost everything done to it
  for the session; and the app's own file dropped a part the catalogue lacks
  once edited. What still guards a file: nothing written loses a part it had,
  an empty model is not written over parts (`emptied`), and a model changed
  while the paced autosave makes its text is written again, not half.
  `fetch_retry_probe`'s last part (a host on 9191 or `-- --port=N`, 4519 always
  404) checks both kinds of file and a whole autosave reopened while its parts
  are on their way; `keeping_probe`, `empty_save_probe` and `unrestored_probe`
  check what a short model writes; `fetch_retry_flow` reloads a browser tab on
  a model whose part 404s. On 5625ed7b fetch_retry fails 7 of its 26 checks,
  keeping_probe 1, and the flow's reload brings back the model before (the
  crane, 29 parts) instead.
- `browser keeps the models` and `models may be cleared warning`
  (`src/net/storage_keep.gd`, `src/ui/storage_offer.gd`, and "Keeping the
  models" in `src/boot/shell.html`): on the web the app asks
  `navigator.storage.persist()` at the first save, or as somebody with saved
  models arrives, once a page, and the page keeps the answer in localStorage
  (`brickworks.storage`). Account says which it is ("Your models are kept on
  this device…" or "…may be cleared by the browser"), and that the account
  keeps no copy. Refused, unsupported, or Safari (seven days without a visit),
  a strip above the model warns once a device (`ShellPrefs` `storage_warned`),
  with Download my models (the .zip) and This one for Studio (.io).
  `brickworksState.storage` carries all of it for a browser check.

- `cad task test` (`tools/bench/cadtask.py`, 2026-10-16; the write-up is
  `docs/CADTASK.md`): is building here as faithful and as fast as in Studio.
  `roundtrip` takes 48 real sets' files (vendor/omr, eight from each of six
  sizes in hash order, one a set) and every `.io` and `.lxf` the repository
  carries through `round trip probe`, then compares every part's number,
  colour, place to the LDU and turn, its sub-model (by membership, not name)
  and its step path (each copy's step, then its own; empty steps and
  renumbering do not count). Strict, up to the lift `open_text` gives a model
  drawn off the ground, and up to renumbering, where a retired number's stub
  (`0 ~Moved to`) is read from `vendor/ldraw` and composed with the part's
  place. `frames` and `build` are in [view](view.md) and [building](building.md).
  `report` writes `REPORT.md` into `bench/results/cadtask-<date>/` of the main
  checkout. The sampler and the comparison are pinned by
  `tests/test_cadtask.py`. Baseline 2026-10-16: 5 of 54 exact, 44 the same
  shapes; every save writes `0 Author: Brickworks` and drops `!LICENSE`.
  It also judges the saved file itself (`exact_file`: the file read as the
  original was, numbers as written, the file's coordinates, steps,
  sub-models, every meta line and the author, and the app's model the same
  opened again), counts a part lost on open only when it is neither shown nor
  kept (`open_lost`, `unshown_kept`), and pairs each part with the nearest
  that fits (the first that fits called a rope read twice moved). The same
  day, after `someone else's file kept`: 54 of 54 exact (0 before), 0 parts
  lost on open (4,715 before, now kept), 42043-1 saved in 0.35 s (695 s).
- `round trip probe` (`src/dev/roundtrip_probe.gd`): each path read by
  `ModelFilePicker.take`, opened by `open_text`, written by `to_text(title,
  true)` and by `StudioIo.pack` around it, and each written file opened again;
  one JSON line a file with every part as "id colour x y z a..i|steps|unit|group"
  at each stage, the file's meta lines counted, and the open and save times;
  whether the store kept the file (`kept`), what it could not show
  (`unshown`), and how many lines the saved LDraw has that the file had not
  and the other way (`lines_differ`). Judges nothing. Appends, so a run that
  dies keeps what it measured.

## How to reach it

```sh
godot --path .     # Cmd-S saves, Cmd-Shift-S saves as, Cmd-O opens, File, Open recent,
                   # File, Export writes a .ldr
godot --headless --path . -- --model=models/car.ldr --out=/tmp/car.ldr
```

## How to check it

Static: nothing static reads `.ldr`.

Runtime:

```sh
# opening an old model offers to seat its parts; one click does, one undo
# takes it back (the "seating an old model" section)
godot --path . --resolution 1400x900 --script src/dev/handbuild_probe.gd
godot --headless --path . --script src/dev/store_probe.gd    # survives save and reopen
#   also: the build order is written as 0 STEP (a 1 x 1 plate in a step before
#   the 3 x 3 that hides it), and the autosave skips it
godot --headless --path . --script src/dev/keeping_probe.gd  # keeps what it was given
godot --headless --path . --script src/dev/example_name_probe.gd  # new work, its own name
godot --headless --path . --script src/dev/restore_probe.gd  # a failed design changes nothing
godot --headless --path . --script src/dev/moved_probe.gd    # the numbers still mean something
godot --headless --path . --script src/dev/import_probe.gd   # reads the format it writes
godot --headless --path . --script src/dev/lxf_probe.gd      # opens LDD's .lxf where LDD put it
godot --headless --path . --script src/dev/io_probe.gd       # Studio's .io: read, parts only the file has, write, round trip, refusals
godot --headless --path . --script src/dev/fidelity_probe.gd -- vendor/omr/files/3315-1.mpd vendor/omr/files/42082-1.mpd   # someone else's file comes back as it went in, edits as such
godot --headless --path . --script src/dev/flex_skin_probe.gd -- vendor/omr/files/42082-1.mpd vendor/omr/files/8202-1.mpd vendor/omr/files/42058-1.mpd vendor/omr/files/42053-1.mpd   # LDCad's flexible parts drawn, one piece each, the file still itself
# ...and in a browser, on a local export (tools/export.sh web), served with tools/web/serve.py
node --env-file=.env tools/web/flex_skin_flow.mjs --url=http://127.0.0.1:8871/ --out=shots/flex_skin vendor/omr/files/42082-1.mpd
godot --headless --path . --script src/dev/carried_fetch_probe.gd -- vendor/omr/files/21321-1.mpd   # carried parts built from LDraw files fetched over HTTP, the library withheld
godot --headless --path . --script src/dev/carried_fetch_probe.gd -- --census bench/results/census.json   # which of vendor/omr's files need the library's files, and which
godot --headless --path . --script src/dev/own_copies_probe.gd   # 42125-1's own copies of LEGO parts read as those parts: joints, exact shapes, tie rods held, written back as they came; copied gears turning theirs (~3 min)
godot --headless --path . --script src/dev/own_copies_probe.gd -- --gears   # ...every OMR copy of a gear, turntable, ring, rack or actuator, read as its part or its own
godot --headless --path . --script src/dev/own_copies_probe.gd -- --survey --shard=0/2   # ...and how many of the OMR's copies are read so (run 1/2 too, ~4 min each)
godot --headless --path . --script src/dev/carried_at_once_probe.gd -- rounds=12   # files' carried parts built on every worker at once, each as built alone
godot --headless --path . --script src/dev/carried_at_once_probe.gd -- dir=$PWD/.scratch-data/godot/app_userdata/Brickworks/custom_parts   # ...the parts kept from files, as start-up builds them
godot --headless --path . --script src/dev/worker_first_run_probe.gd   # cold operators on every worker at once, through first_here: none wrong, no crash (~70 s)
godot --headless --path . --script src/dev/worker_first_run_probe.gd -- cold rounds=8000   # the engine as it is: ends on SIGSEGV, rip 0x0 (expected; under gdb to see it)
godot --headless --path . --script src/dev/table_race_probe.gd -- --tries=80   # each table read first on a worker and here at once, a run per try: every run stays up (~25 min; -- --only=mechanism for the crash alone)
python3 tools/web/serve.py build/web 8840 --parts-url "$PARTS_URL" &   # a local export reading the real parts bucket
node tools/web/carried_flow.mjs --url=http://127.0.0.1:8840/ --out=shots/carried vendor/omr/files/42082-1.mpd vendor/omr/files/21321-1.mpd
godot --headless --path . --script src/dev/mesh_export_probe.gd   # 3D model: the car as GLB, glTF, OBJ, STL, read back
godot --headless --path . --script src/dev/mesh_export_probe.gd -- --orthanc   # ...and the castle and Orthanc, every format, timed (~6 min)
node tools/web/model3d_flow.mjs --url=http://127.0.0.1:8147/index.html   # a browser: the car's GLB from the menu, downloaded and read
python3 tests/fixtures/studio/make_fixtures.py   # after changing what the .io fixtures hold
node tools/web/io_flow.mjs --url=http://127.0.0.1:8147/index.html   # a browser: open an .io, export one, open it again, then whole_2025.io
python3 tools/ldd_map.py vendor/ldraw.xml   # after a newer ldraw.xml: assets/ldraw/ldd.json again
tools/check.sh --network   # adds open_probe: opening the way the browser has to
# several tabs, one browser: a local export served with the relay, .env sourced
node tools/web/relay_server.mjs 8790 --static=build/web &
node tools/web/tabs_flow.mjs --url=http://127.0.0.1:8790/app --out=shots/tabs
tools/windows_check.py      # two windows of the desktop app, a model each
# versions, the browser asked to keep the models, the one warning, over MCP too
godot --headless --path . --script src/dev/versions_probe.gd
godot --headless --path . --script src/dev/empty_save_probe.gd   # no empty save over parts
godot --headless --path . --script src/dev/autosave_paths_probe.gd   # a figure stood up by any path survives a reload
godot --headless --path . --script src/dev/unrestored_probe.gd   # a working model that cannot open is kept, and said
# real sets' files round-tripped, judged, REPORT.md (run bare: it uses heavy itself; ~20 min)
python3 tools/bench/cadtask.py roundtrip && python3 tools/minitest.py tests/test_cadtask.py
# the page's half in real Chromium, persist() played refused and granted
BW_BYPASS=$VERCEL_BYPASS node tools/web/keep_flow.mjs --url=<deployment>/app --bypass=$VERCEL_BYPASS --out=shots/keep
```

`versions_probe` proves it when it ends "a model's last 20 saves are kept and
open again, and the browser is asked to keep them" (Account follows the
browser's answer while it is open: it was read once as the panel opened, up to
400 ms old, and keep_flow's granted half read the unanswered words); `empty_save_probe` when it
ends "no save of no parts goes over a model with parts unless the person
emptied it" (on main both its empty checks fail: the autosave and Save wrote
the empty model); `autosave_paths_probe` when it ends "whatever path changed
the model, a reload brings it back" (on f78934bc the in-app assistant's
minifigure did not come back, 1 of 11 parts, nor a sub-model named past the
store); `unrestored_probe` when it ends "a working model that cannot
be opened is kept, and said to be"; `keep_flow` when it ends "the browser is asked to keep the
models, a refusal is warned of once, and every save is kept to open again".
On production before 2026-10-14 the flow fails at the first save (never asked).

And the round trip, which is the one to run after touching the writer:

```sh
godot --headless --path . -- --model=models/car.ldr --out=/tmp/car.ldr
grep -c '^1 ' /tmp/car.ldr
```

Proves it when: it prints `wrote /tmp/car.ldr (61 parts)`, exits 0, and the grep
says `61`. Every one of the nine files in `models/` is a fair target; `car.ldr`
is 61 parts, and the count printed and the count in the file must agree.

## Gotchas

- **Typing into the menus in a browser test presses more than it means.**
  `model3d_flow.mjs` first typed "3D model" into File, Export: "3" is View,
  From the left, and the space pressed whichever line was lit, so the LDraw
  file came down and "model" went to the app as keys (M opened the
  minifigure maker). It now goes down to the line with the arrow keys and
  fails unless what downloads is a `.glb`. Words typed to find a line must
  find it before their first space.

- **A PopupMenu reports a negative id as the item's index.** The Open menu's
  "From a file on this computer…" had id -2, so pressing it said 0 and opened
  the first model listed under it — the first saved one, or the Bench example —
  on the desktop and in a browser alike. Its id is now `1 << 30`;
  `studio_ui_probe` opens its saved model through that line and fails if no file
  dialog comes up.

- **The build order is written to the file, but not by the autosave.** Working it
  out compares every brick with every other: measured at 96 ms for 400 bricks,
  552 ms for a thousand and **2.2 s for two thousand**, and the autosave fires a
  second after every change. So `to_text(title, with_steps)` defaults to off, and
  `save_as` and `export_to` pass true. An author's steps are the exception: they
  are the model's, cost nothing to write, and the autosave writes them too (with
  `0 !BRICKWORKS AUTHORED_STEPS`), or a restart would lose them. A worked-out
  order Brickworks wrote is not read back as anyone's steps (`0 Author:
  Brickworks` and no such line). A sub-model's reference now goes in the step
  it is put on in, not first in its section. Without the `0 STEP` lines an exported
  model opens in Stud.io or LDCad as one flat pile, and for a mechanism the order
  is not recoverable by eye — a pin has to follow the part it goes into.

- **Sections are flattened on save.** An angled sub-assembly is written as loose
  bricks at their world transforms, not as an LDraw sub-model, so the grouping
  the designer worked in is lost on reopening. The geometry is exact; the
  structure is not. Nothing depends on it yet, and `LdrModel` can already *read*
  sub-models, so writing them is the missing half.

- **`--out` used to be written once, after the design returned.** A ninety-minute
  Voyager run reached 371 bricks, lost its connection twice to a TLS fault, and
  was still retrying when its clock ran out — so no file was written and the whole
  run was wasted. The model stands on the baseplate the entire time, so a driven
  run (`--ask`, `--ask-claude-code`) now exports on every `built` signal:
  `_keep_as_it_builds` in `src/main.gd`. Last write wins, each one the whole model
  as it then stood. Proved by polling the path during a real design — "kept 7
  parts" appeared at 80 s while the run was still going. **`--autobuild` does not
  test this**: it builds procedurally without the assistant, so `built` never
  fires and only the final write happens. That run looked like a pass and was not.

- **The file is written even when a design failed.** `--out` writes the last
  version that held together and signals failure through the exit code, because
  throwing the model away would be the worse answer. Read `$?`, not just the file.
- **`--model` means two different things.** On its own it is the model file to
  open; with `--ask` it is also passed to `Brain.use_model`, which falls back to
  the default when the name is not a model it knows. Do not pass both.
- **Three decimals straightened every angle.** A writer rounding direction cosines
  loses a section's rotation silently. 8 decimals for the nine matrix elements.
- The scenery (baseplate) is excluded from the exported count:
  `_world.brick_count() - _store.scenery.size()`.
