# MCP

Letting a session that is already open build in Brickworks, instead of Brickworks
asking for an API key.

<!-- covers: lib:command socket, cli:mcp server, cli:drive the app over mcp, cli:drive the app from a shell, ui:design on your own subscription, lib:the window's commands over mcp, cli:keep the mcp in step, lib:the gallery over mcp, cli:gallery tool probe, cli:mcp walk probe, lib:the model in Claude, cli:model view check, ui:the model in Claude in 3D, lib:the viewer's own tools, lib:the model packed for the viewer, cli:viewer tools probe, cli:build the viewer, cli:viewer readers check, cli:viewer first paint, cli:app host check -->

## Sub-features

- `command socket`: a line-delimited JSON port the app opens on 127.0.0.1 when
  `--mcp` asks for it. One object in, one out. `__tools__` answers with the tool
  list, `__ping__` with the app's name and port, and anything else is run through
  `Assistant.use_tool` — the same implementations the app's own assistant calls.
- `mcp server`: `tools/brickworks_mcp.py`, which speaks MCP on stdio and relays to
  that port. Stdlib only, no dependencies. It carries no tool definitions of its
  own: it fetches them from the app, so the two cannot drift, and keeps a copy in
  `tools/mcp_tools.json` only to answer `tools/list` while the app is closed. The
  MCP `instructions` are fetched the same way (`__about__`) — all 56k characters
  of the app's own design guidance, the same words the in-app loop is given, so a
  session is not left working out from refusals that wedge plates exist. But
  **Claude Code reads only about the first 3,800 characters** of a server's
  instructions and marks the rest "… [truncated]": asked what it was given, a
  session quoted LEGO ART, COORDINATES, SIDEWAYS and half of the pins section,
  and could not see HOW TO WORK (character 12,868), the rules, the shapes or
  what a subject needs. So the guidance is headed by `Assistant.GUIDE_HEAD`
  (about 1,900 characters: the process — silhouette as shapes with a face,
  features, review, each feature, each assembly, touches — the three rules, and
  the sections there are), and `read_guide(section)` serves any section in full
  ("work", "rules", "shapes", "subject", "angle", "pins", ...: the heading's
  text to the next heading, `Assistant.read_guide`). `mcp_probe` checks the
  head is inside the first 3,500 characters and that read_guide("shapes")
  serves SAY THE SHAPE with the face in it. To see what a session reads:
  start the app with `--mcp=PORT` and ask `claude -p` (no tools,
  `--strict-mcp-config`, on the subscription) to quote the first words under
  HOW TO WORK and the last sentence it can see.
- `drive the app over mcp`: `tools/mcp_check.py` starts a headless app, drives the
  relay as a client would, and stops the app it started.
- `design on your own subscription`: **My Claude** in the design panel. The app
  starts the Claude Code on this machine and points it back at itself over MCP, so
  the thinking is paid for by the person's Claude subscription — no API key, no
  account, nothing billed by us. Desktop only; a browser cannot start a program.
- `the window's commands over mcp`: `src/net/app_tools.gd` (AppTools), what
  the person does from the menus besides designing, as tools a session has
  and the design loop does not: `set_floor` (View, Floor), `edit_steps`
  (Edit, Build steps; the timeline), `lay_flex` (Build, Hose, tube or
  chain; Reshape), `pose_model` (Build, Pose; the hinge tool),
  `animate_model` (its keys kept as the motion "Animation", played once to
  render), `list_motions`, `define_motion`, `play_motion` and `render_motion`
  (the model's own motions, docs/MOTIONS.md; see [view](view.md)'s
  `motions`; `src/dev/motions_probe.gd` calls each over `tools/call`),
  `simulate_mechanism` (Tools, Simulate mechanism; `SimulatePanel.for_session`,
  see [geometry](geometry.md)), `undo` (Edit,
  Undo and Redo), `open_model` (File, Open), `parts_list` (Build, Parts
  list; My collection, What do I need, What can I build), `render_model`
  (File, Render), `export_model` (File, Export, and Instructions),
  `brickify` (Build, Brickify a 3D model…; File, Import, 3D model),
  `print_part` (Build, Print on a part… and Put a sticker on…),
  `suggest_sections`, `make_sections`, `break_out_section` and
  `evaluate_section` (Build, Suggest sections, the model tree's Accept,
  Break out, Put back and Evaluate the section…; see [building](building.md)'s
  `sections`; `src/dev/sections_probe.gd` calls each over `tools/call`),
  `make_unique` (Edit, Make this copy unique) and `colour_hidden_parts`
  (Tools, Colour the hidden parts…; `HiddenColoursPanel.for_session`, which
  previews unless `apply` and `agreed`, see [geometry](geometry.md)). Each
  is a thin wrapper over the code the command runs — `Shell.change_steps`,
  `FlexTool.lay`, `PosePanel.joints_now`/`set_angle`/`render_animation`,
  `RenderDialog.render_for`,
  `ModelBar.export_now`, `Exports`, main's `choose_floor` and
  `_export_booklet`, `BrickifyDialog.take`/`choose`/`brickify`,
  `PrintStudio.print_on`/`sticker_on` (the print designer's own
  `draw_and_save`), `EditVerbs.make_unique` — one undo step where it changes the model
  (`Builder.fold_since` folds a call that took two of the window's steps),
  and a refusal that says what to fix. They take their turn in the queue as
  the assistant's tools do. Guidance: `AppTools.GUIDE`, the "THE REST OF THE
  APP" section, which `read_guide("app")` serves and `guidance()` ends with.
  **Long work is a job** (`src/net/tool_jobs.gd`, `ToolJobs`, 2026-10-13). A
  session waits about three minutes for an answer (the connector's relay four),
  and a turntable or a booklet of Orthanc takes longer, so the session was told
  it timed out while the app was still drawing. A call known to be long
  (`ToolJobs.long_call`: `render_model`, `animate_model`'s rendering,
  `simulate_mechanism`'s `record=true`, `export_model`'s studio, picture and
  instructions, `make_art`) answers at
  once with "Started job N: …" and the work starts on the next frame; any
  other call still going after `after_s` (20 s) becomes a job where it stands
  (timed on Orthanc in software: the first `view_model` over 75 s,
  `check_design` of the Falcon over it 43 s). The `job` tool waits up to
  `wait_s` (10 s) for it to end, then says how far it has got ("12 of 36"),
  gives the answer (picture and all) once done, or that it was cancelled or
  failed; `cancel=true` stops it where it can be stopped. The job **is** the
  `Working` job the person sees along the foot of the window — its words, its
  count, its Cancel — handed down as `work` to `RenderDialog.render_for`,
  `PosePanel.render_animation`, `SimulatePanel.record_of` and main's
  `_export_booklet`, so the window's
  Cancel stops the session's render and the session's cancel takes the bar
  away. A job keeps the app's turn until it ends; every other call meanwhile is
  answered at once with "The app is busy with job N". A call that would be
  refused at once (nothing built, nothing to draw with, a plan that will not
  parse) is not a job, so its refusal is the answer. The guidance is in the
  answers themselves and one line of `GUIDE_HEAD`.
  **A job's answer is the call's own** (2026-10-16): once done, one call of
  `job` gives a line saying which job, then the call's answer block for
  block, words and picture (a string answer is a block of its own too, so
  the words match the inline answer exactly), and, to a client that shows
  pages (the relay asks for it on `job` calls too, `asksViews`), the same
  `_meta["brickworks/view"]` the inline answer would have carried, drawn
  once for that job (`Entry.shown`), with `_meta["brickworks/job"]` = {id,
  tool, done, input: its from and name}. The answer that started a job
  carries that `brickworks/job` (not done) and no model. Before, the job's
  answer had no `_meta`: release m33's `model_view` check at load 75 had
  `view_model` become a job three times and the card nothing to draw.
  `--jobs-after=S` (`/app?jobs-after=S`) sets `after_s`; at 0 every call is
  a job, even one that never waited, so a check walks the path on any
  model: `viewer_tools_probe` (`_as_jobs`), `model_view_check.mjs` section
  4, and `mcp_check.py --window` against an app started `--jobs-after=0`.
  **Why a picture took over 20 s in the browser** (measured 2026-10-16, a
  local export in Chromium on SwiftShader under `heavy`, load 30 to 45,
  nothing touching the page): the app's own work for a `view_model` is under
  0.1 s; the rest is waiting for SwiftShader to rasterise (`GpuFence` holds:
  5.7 to 13.8 s on 6 parts, 32 to 36 s on the 535-part station), with the
  page's main thread at 60 frames a second. Behind it was needless drawing:
  the connector panel's "Claude is building — N calls, m:ss" ticked every
  second from Claude's first call on, and the run card's clock every frame,
  so after any call of Claude's the page drew a whole frame back to back,
  12 to 15 CPU-seconds of the GPU process each (89 to 185 CPU-seconds in 20 s
  standing still, against 0.2 before the first call), and every picture
  waited behind the frames queued. Both now move with Claude's calls
  (`ChatPanel`, `ConnectorForm._tick`; `chat_probe` checks nothing runs on a
  timer between calls). After: nothing drawn standing still after Claude's
  calls (0 frames in 20 s, 12 to 14 before); on 6 parts (the `model_view`
  check's tower) `look_at_model` 1.5 to 2.1 s (9 to 10 before) and
  `view_model` 4.6 to 5.8 s, 25 to 32 CPU-seconds of SwiftShader each, after
  a first of 13.3 s (7.7 to 23.9 s before); on the station `look_at_model`
  2.3 to 2.6 s (21 and 32 before), `view_model` 9 to 16 s once the first
  picture of the session has built its viewport (37.7 s, still a job), 22 to
  53 s before. What is left is SwiftShader under load: on the RX 6700 XT the
  same picture is under a second ("Job 3 (view_model) is done, after 0 s").
- **Every tool says what it does to the person's work** (2026-10-14): MCP's
  `annotations` — `title`, `readOnlyHint`, `destructiveHint` (can take work
  away: clear, submit, edit, open, undo, Brick Art, restyle), `idempotentHint`
  and `openWorldHint` (fetches from outside: references, the gallery, a
  brickify or print link) — from one table, `CommandSocket.HINTS`, a row per
  tool with its title and kind (look, file, add, remove). They are in
  `served_tools` (the desktop's port, the connector's tab), `__tools__`, so
  `tools/mcp_tools.json` and `tools/brickworks_mcp.py`, and the relay passes
  them on, adding its own for `tabs` and `select_tab` (`api/mcp.js`). Claude
  reads them in deciding what to ask about; the per-tool switches in Claude's
  connector settings stay Claude's. `mcp_sync_probe` fails on a tool with no
  row or a row with no tool, `read_only_probe` calls every read-only one,
  `connector_probe` checks the relay's tools/list carries them as the table
  says, and `mcp_check.py` that `tools/brickworks_mcp.py` passes them on.
- `keep the mcp in step`: `src/dev/mcp_sync_probe.gd`. Fails when
  `tools/mcp_tools.json` is not what the app serves (`-- --write` writes it
  again from the app; it was four tools behind when this was written), when
  `GUIDE_HEAD` reaches 3,500 characters, or the connector's note
  (`ClaudeConnector.CONNECTED_NOTE`) and the head together do (they were
  3,537 when this check was added, 2026-10-13: the note was cut to what a
  session cannot learn from the answers), when a tool is named in neither the
  head nor a section `read_guide` serves (`make_part` and `clear_model` were
  in neither), and when one of the window's commands (Shell) is in neither
  `AppTools.COMMANDS` (the tool that does it) nor `AppTools.WINDOW_ONLY`
  (why it is the window's alone). A command added to the menus fails it
  until it is placed in one.
- Over the connector (`api/mcp.js`, not the desktop's port) a session also
  has the relay's own `tabs` and `select_tab`, and a `target` argument on
  every tool, to choose between the account's open tabs; every answer from a
  tab begins by naming it and its model. See [web](web.md), "Several tabs,
  one account". They are not the app's tools, so `tools/mcp_tools.json` does
  not list them.
- `the model in Claude` (MCP Apps, 2026-10-14): claude.ai and the Claude
  apps show the model inline beside `submit_design`, `look_at_model`,
  `view_model` and `edit_model`. The relay serves one `ui://brickworks/model.html`
  resource (`api/_viewer.js`, `text/html;profile=mcp-app`, self-contained:
  site colours, system fonts, no WebGL), answers `resources/list` and
  `resources/read` without the tab, says `resources` and the
  `io.modelcontextprotocol/ui` extension at `initialize`, and names the page
  on those four tools in `_meta.ui.resourceUri` (and the older flat
  `"ui/resourceUri"`). Only a client that says at `initialize` (or in a
  request's `_meta`, protocol 2026-07-28) that it shows such pages is given
  more: its session id starts `app`, and its calls to those tools carry
  `_meta["brickworks/views"]` to the tab, which adds `_meta["brickworks/view"]`
  to the answer (`src/net/model_views.gd`): the parts count and, for
  `submit_design` and `look_at_model`, a turntable of four corners, 480 px
  WebP, under 100,000 characters, drawn once per change of the model. Never
  `structuredContent`: Claude Code gives the model that in place of the
  words. Every other client's answers are byte for byte what they were. A
  call that became a job carries only which job it is
  (`_meta["brickworks/job"]`); the `job` tool's answer once it is done
  carries the call's whole share, and the card beside the call follows the
  job through the host (`job {id, target}`, each call waiting up to 10 s;
  where the host will not let it, `viewer_scene` until the tab is no longer
  working) and shows that answer as the call's (`brickworksCard.job`,
  `.followed`).
  `tools/web/model_view_check.mjs` proves it on a deployment: the relay's
  half, a real tab, a session that shows pages and one that does not, and
  the page in a sandboxed frame under the policy it declares, sent the
  real answers as a host sends them, in a browser with no WebGL (the
  turntable fallback, asked for through the host).
- `the model in Claude in 3D` (2026-10-15): the page is the real model in
  3D. Source `tools/viewer/` (`card.html`, `card.js`, `lbm.js`, `scene.js`);
  `tools/viewer/build.mjs` bundles it with three.js 0.186.1 into one
  self-contained page, `api/_viewer_page.js` (committed: the deploy builds
  nothing; `--check` holds the source to the build). The tab packs the model
  (`src/net/model_scene.gd`: per brick its number, part, colour, place and
  turn, in deflated columns, a few bytes a brick) and the page fetches each
  part's own `.lbm` from where the app does (`PARTS_URL`, the one origin in
  `_meta.ui.csp.connectDomains`), drawn instanced in the app's own colours
  (`BrickColor.shown`). It orbits (drag, wheel or pinch, arrow keys, 0 back),
  picks a part (an outline, `ui/update-model-context` saying "brick #N, a
  3022 … in Red, at the front left, near the top", and `viewer_pick`
  selecting it in the tab so `selection` reads it), asks for full screen
  (`ui/request-display-mode`), and calls the tab back through the host:
  Check (`viewer_check`: Tools, Check stability's weak joints and the stud
  joints at half their working load or more, tinted as the app tints them,
  amber to red, the rest clay; "Ask Claude to fix them" is `ui/message`),
  Instructions (`viewer_steps`: the booklet's own `Instructions.plan`, a
  step at a time, the step's parts outlined and listed), Parts
  (`viewer_parts`: `Inventory` and the BrickLink wanted list, downloaded by
  `ui/download-file` where the host offers it, else copied or shown), and
  Open in Brickworks (`ui/open-link` to `/app?tab=<id>`). It does not wait
  on `_meta`: with none (a host that strips it, or a session that never said
  it shows pages, which is most of claude.ai's), it asks `viewer_scene`
  itself, and from a host that will not call a tool its model was not
  listed, reads `brickworks://viewer/scene` (and `/check`, `/steps`,
  `/parts`), which the relay turns into the same call. A frame without WebGL
  asks `viewer_scene {views: true}` for the four-corner turntable. The
  renderer is let go 20 s after the card leaves the screen (a conversation
  has a card per build, a browser only so many WebGL contexts) and comes back
  when it returns. Answers that carry the model now carry the front corner
  only, not four, and the scene; the turntable is drawn only when asked.
- `the viewer's own tools` (`src/net/viewer_tools.gd`): `viewer_scene`,
  `viewer_check`, `viewer_steps`, `viewer_parts`, `viewer_pick`, answered in
  `CommandSocket.answer_rpc` before any of the app's, without taking the
  app's turn (a card asks while Claude works). Listed by the relay with
  `_meta.ui.visibility ["app"]`, and only to a session that shows pages: a
  client that does not is listed the same 49 tools as before. Not in the
  app's catalogue, so `tools/mcp_tools.json` and `mcp_sync_probe` do not
  change, and the tab's panel does not say Claude is at work for them
  (`ClaudeConnector._answer`). None changes the model; `viewer_pick` selects,
  and only while the card's model is the tab's (`of`).
- `viewer tools probe`, `viewer readers check`, `app host check`: below.
- `drive the app from a shell`: `tools/brick.py` calls one tool and prints the
  answer, writing any picture to `--png=PATH`. The same socket without the MCP
  wrapping, for a script, a person reading along, or an agent that would rather
  open the picture as a file.

Nine tools reach a session: the assistant's seven (`search_parts`, `check_design`,
`attachment_points`, `edit_model`, `look_at_model`, `view_model`, `submit_design`)
plus two the design loop never needs — `clear_model`, because a loop clears the
board itself when a design begins and a session has no such moment, and
`save_model`, because the person normally saves from the window.
`clear_model` (`Main.clear_model`) begins a new model, Untitled, as well as
emptying the board: it kept the name of what it took off, so Save would write
the session's lighthouse over the person's saved house. The design's
`submit_design` name then names it (`Assistant.titled`). `example_name_probe`.
(The list has grown since; among the later ones is `make_part`, with which a
session makes a part LEGO has not made and builds with it — see
[elements](elements.md) — and `make_art` and `look_at_picture`, with which
it lays a picture as a LEGO Art set to a plan of its own — see
[view](view.md); and `selection`, `where_to_attach` and `edit_selection`,
with which a session is told what the person has selected in the window,
where it can take a part, and changes that alone, as **Ask Claude about
this…** does — see assistant.md, "ask claude about the selection"; and
the window's commands, ten more — see "the window's commands over mcp"
above; and `choose_sketch`, with `submit_design`'s `sketch: true`, for
Sketch first — see assistant.md, "sketch first". 38 in all on 2026-10-13;
`mcp_sync_probe` keeps the count honest.)
`settle_feature`, with which a session accepts, adjusts or rejects the real
piece the app laid for each feature, and without which `save_model` refuses
— see assistant.md, the design loop's features.)
above. 41 in all on 2026-10-13, with `job`, `brickify`, `print_part` and `make_unique`; 42 with `gallery`
(below); `mcp_sync_probe` keeps the count honest.)
- `the gallery over mcp` (`src/net/gallery_tool.gd`, `GalleryTool`, the
  `gallery` tool of `AppTools`, 2026-10-13): read-only. With no `open`, a page
  of brickworks.diy/gallery (`/api/share?op=list` of the app's own deployment,
  `Deployment.api_base`; never a URL a session names) for `q`, `kind` (the
  gallery's own kinds, `ModelKinds`), `size`, `technic`, `instructions`, `sort`
  and `page`: one line a model with its link id, part count, credit, kind,
  licence, counts, how many built it, own steps, Technic, what moves in it
  ("moves: steering, boom") and its Tested mark, then how to read one and to
  credit its builder. The sorts are the gallery's (2026-10-19): newest,
  views, likes, remixes, `builds` (Most built), `top` (Top builds, said how
  it weighs) and `owned` (Parts I own: asked with the person's own session
  and `mine=1`, each line saying how many of its pieces they own; refused in
  words, asking nothing, when nobody is signed in). `shelves=true`: the
  gallery's front (`?op=shelves`): this week's pick and why, the small
  builds, and with a sign-in what they can build now. `open=<id>`: the viewer's own request (`/api/share?id=`), read
  compactly — the link, the credit, what its owner wrote, its kind and tags,
  its licence said as what a session may do with it (CC BY, CC BY-SA, all
  rights reserved, or none chosen: learn, do not copy), what it was remixed
  from, then from its file (`LdrModel.parse`, `flatten` against the
  catalogue) its sub-assemblies and steps, its size in studs and bricks, its
  parts by catalogue kind and the ten most used by part and colour — and its
  small picture (or the big one when it has none) as an image block;
  `picture=false` leaves it out. Nothing on the baseplate changes, and it is
  answered in a tab showing a shared model too (`_while_looking`). In
  `AppTools.GUIDE`. The viewer's JSON carries `description`, `tags` and
  `kind` for it since then. A model's own motions (docs/MOTIONS.md, unit 3,
  2026-10-20): a list's line says them, `motions: "Open the gates", "Open
  the mailbox"` (the card's `motions`, once supabase/motions.sql is
  applied); `open=` reads them from the file itself (`Motions.read`,
  `GalleryTool.motions_words`): `Its motions (2): "Open the gates" (2 s, 2
  joints), "Open the mailbox" (1 s, 1 joint).` and how to play one
  (`open_model link=`, then `play_motion name=`). `open_model` names the
  motions of whatever it opened (a saved model, a version, an example, a
  link's copy) the same way (`AppTools._opened_motions`).
- **The second walk-through** (2026-10-19, rel-m86; transcripts in
  `bench/results/mcpwalk2-2026-10-19/`, git-ignored). Real Claude Code
  sessions on the subscription (`claude -p` with `--strict-mcp-config
  --mcp-config <file> --tools "" --restricted`, under `env -u
  ANTHROPIC_API_KEY`) against a windowed app on its own data, the gallery
  from rel-m86's API on this machine (`relay_server.mjs` over the real
  project, read-only use), a collection of two sets on the device. Asked
  what a person asks, they met six gaps, each now answered in the MCP layer:
  - "find the most built small model and open it": the list said nothing of
    builds at nought, so "most built" read as a count the list left out; and
    a session could only read a gallery model and send the person to its
    page. Each line now says "not built yet" at nought (`GalleryTool._built`);
    `open` says how many built it and its Tested mark; and **`open_model
    link=<id>`** (or its `/m/` address) opens a copy saved in the person's
    models under a name of its own, remixed from its link, as Open in
    Brickworks does (`AppTools._open_link`, after main's `_maybe_copy`),
    refused over changes not saved as any open is.
  - "what in this model moves? steer it left and back": move_part needed
    part=, so a session tried five parts one at a time to find the kart's
    steering, and pose_model said "Nothing here turns". **move_part with no
    part=** now changes nothing and lists what moves: what its link's card
    says (`Playable.read`, the words "Moves: steering, boom" and the part a
    person takes hold of for each), then every body on a joint a drag
    moves, biggest first, by a part that moves it, with its joint and where
    (`AppTools._what_moves`, 16 at most). pose_model's refusal (`NO_JOINTS`)
    and the guide point to it.
  - "what can I build from my collection?": parts_list which="buildable"
    measured only the saved models, so a person with two sets was told
    nothing could be built. It now ranks what My collection's What can I
    build? ranks (`CollectionDialog._fill_build`): saved models, the
    examples and the official LDraw models of real sets, most of it owned
    first, 25 at most unless limit= is given.
  - "who made the orrery, has anybody built it or commented, follow them":
    a session could say none of it. `open` now reads its comments (`?op=comments`:
    the count, closed or not, the three newest quoted as people wrote them,
    hidden ones left out) and the photos of real builds (`?op=photos`); a
    list names a model's designer as "by Name (@handle)"; **`designer=<handle>`**
    reads their page (`api/people.js ?op=profile`): who they are, what their
    models earned, their models by Top builds. Liking, commenting and
    following stay the person's own on the site, and the answers say where
    (`GalleryTool.FOLLOWING`); nothing here writes to the account.
  - "steer the wheels left and back": `Playable` called the Technic
    Go-Kart's steering nothing and its frame's shear a "boom" (its knuckles
    are connector blocks on frictionless pins, no part named a steering
    arm). Whatever carries a wheel and turns on an upright line (within the
    cosine 0.9 `Poser.Joint.kind` reads a turntable by) is now steering,
    taken by its biggest part, a toy's front axle on a turntable too; a boom
    lifts, so a body on an upright line is not one. The kart's card says
    "Moves: steering", by #7 and #14, its knuckles.
  - "turned 20, then 15: where is it?": move_part said "now 15°", that
    call's turn. It now says "turned 15° (asked 15°)" and then "Its joint
    now stands 35° from where it was built", read as the moving part's turn
    against the part across the joint (`Grab.from_built`, against where each
    part stood before a grab first moved it, `Grab._built_at`, kept as
    `_moved_since_built` is); with part= alone, "Its joint stands …".
    `grab_probe` reads a call's turn from "turned N°".
  - "show me it turning": animate_model took pose_model's joints alone
    (sub-assemblies on a hinge, a turntable or a clip), so the car the
    session steered with move_part "had nothing that turns". animate_model's
    keys now take a part on its joint as move_part names it ("#7"), in
    degrees from where it was built: each frame is the grab's own turn
    (`GrabDrag.turning_for_session`: its stops, its loop, the gears it
    drives), drawn by `PosePanel.render_animation` over pose's joints and
    never put on the baseplate. The panel takes it afresh by its name each
    time (`PosePanel.turning_for`, `GrabDrag.Turning`), so render=false sets
    keys the person's Play turns, and keys a render left there play and
    render again; the answer says where a part stopped short ("#143 stops at
    0° of the 30° asked: …"). A session's render is framed on the model and
    what it sweeps ("hero", as simulate_mechanism's recording is), not drawn
    through the window's camera, and the answer carries its frames at its
    keys as one picture (`PosePanel.sheet`), with "drawn in N s" for how
    long drawing took. pose_model's list marks a joint with no room to turn
    10° or 90° either way and points to move_part (`Poser.has_room_to`)
    (animaudit, 2026-10-20; docs/ANIMATION.md).
  Checked by `src/dev/mcp_walk_probe.gd` (headless: the kart's listing,
  its card saying steering and not boom, the part it names turning both
  front wheels and not the back ones, 20° then 15° said as 35° from where
  it was built and back to where it was built, an animation frame of the
  steering by its part turning both front wheels with nothing on the
  baseplate moved, render=false refused, a part not there; the pose pointer; a played
  gallery answer opened by its address, saved, remixed from it, refused
  over unsaved changes and for a bad link; a collection of the Bench's
  pieces ranking the Bench first, with the official models) and
  `gallery_tool_probe -- --played` (nought builds, builds and Tested on
  open, comments newest first without the hidden one, photos, the designer's
  handle and page, a handle nobody has, one that is not a handle). Both
  pass; against rel-m86's app_tools.gd and gallery_tool.gd, 17 of
  mcp_walk_probe's checks and 14 of the gallery's fail, and against the
  merge with rel-m87 before the three fixes above, 6 of its checks fail and
  the animation's call does not exist.
  Walked again on the fixed app (the same five asks, the same way, the
  gallery from a local relay over the real project, a collection of sets
  31070-1 and 6061-1; `*_after` beside the first transcripts): all five
  done. t1 found the only small model, said nobody had built it and
  opened a copy (2 calls). t2 read "Moves: steering" by its knuckles, turned
  #7 25° and back, told "now stands where it was built" (6 calls, 31 s,
  against 13 calls of guessing). t3 built a car whose front axle pivots on
  one stud, read "Moves: steering", turned it 30° each way and rendered a
  6.2 s animation of it by "#7" (75 frames, WebP and MP4; the front axle
  turns in them), 47 calls in 243 s against 110 in 756 s with no
  animation. t4 ranked 343 models, the two sets' own official models first.
  t5 said who made the orrery, that nobody has built or commented on it,
  what else they made, and that following is the person's own.
  Still in the way, not in this unit: a set the person owns measures 96%
  and 84% against its own official model (the LDraw model's parts are not
  all the set inventory's numbers), so t4 heard "nothing can be built
  completely"; the project's seed account has no handle, so designer= has
  no page to read and t5 searched by name; move_part's first line names
  the loop's biggest part ("The Technic Beam 13, 34 parts") when a knuckle
  was taken; the kart's frame is beams on single friction pins, so a turn
  of knuckle #7 can shear it as the loop solves (friction is not weighed);
  a 2x2 turntable under a wheel plate gripped by its studs did not turn
  (t3 built a single-stud pivot instead); an animation of a small car was
  drawn small, through the window's camera (framed since, docs/ANIMATION.md).

## How to reach it

```sh
godot --path .                     # then tick "My Claude" in the design panel
godot --path . -- --ask-claude-code="a small post box"   # the same, from a script
godot --path . -- --mcp            # the app, with the port open on 8787
godot --path . -- --mcp=8790       # a second one, beside the first
claude mcp add brickworks -- /mnt/Projects/brickworks/tools/brickworks_mcp.py
```

By hand, without MCP at all:

```sh
tools/brick.py __about__ --port=8787      # how to design well here
tools/brick.py __tools__ --port=8787
tools/brick.py search_parts '{"query": "wedge 4x2", "limit": 5}' --port=8787
tools/brick.py check_design "$(cat design.json)" --png=/tmp/look.png --port=8787
tools/brick.py clear_model --port=8787
```

Or with nothing but a shell:

```sh
printf '{"id":1,"tool":"__ping__"}\n' | timeout 5 nc 127.0.0.1 8787
```

## How to check it

Static: `pyright` covers both Python files.

Runtime:

```sh
godot --headless --path . --script src/dev/mcp_probe.gd   # the app's half, queue included
godot --headless --path . --script src/dev/mcp_sync_probe.gd       # the list, the guide, the menus in step
godot --headless --path . --script src/dev/read_only_probe.gd      # a tool that looks changes nothing
godot --headless --path . --script src/dev/claude_undo_probe.gd    # what a session changes is one undo step
godot --headless --path . --script src/dev/app_tools_probe.gd      # the window's commands as tools
BRICKWORKS_API=http://127.0.0.1:8790 godot --headless --path . --script src/dev/gallery_tool_probe.gd   # the gallery, with relay_server.mjs 8790 running
godot --headless --path . --script src/dev/gallery_tool_probe.gd -- --played   # its played answers alone: licences, sorts, moves, the front, builds, comments, designers; no server
godot --headless --path . --script src/dev/mcp_walk_probe.gd       # what the 2026-10-19 walk-through's sessions met: what moves, the steering's angle, animating it, a gallery copy, What can I build?
tools/mcp_check.py                                        # the relay's half
tools/mcp_check.py --port=8787                            # against an app you opened
BW_BYPASS=$VERCEL_BYPASS node tools/web/model_view_check.mjs --url=<a preview>/app --out=shots/model_view   # the model shown in Claude (MCP Apps)
node tools/web/model_view_check.mjs --url=http://127.0.0.1:8797/app --relay-only   # ...its relay half, with relay_server.mjs 8797
godot --headless --path . --script src/dev/viewer_tools_probe.gd            # the viewer's own tools, on the real scene, and a job's answer
MESA_VK_WSI_DEBUG=sw xvfb-run -a godot --path . --resolution 1400x900 --script src/dev/viewer_tools_probe.gd   # ...in a window (on the GPU lease): the picture through the job
godot --path . -- --mcp=8847 --jobs-after=0 & tools/mcp_check.py --port=8847 --window   # every call a job, in a window: the bridge's answers followed, view_model's picture
node tools/viewer/scene_check.mjs --scene=.scratch-data/godot/app_userdata/Brickworks/viewer_tools_probe/scene.json   # the card reads what the tab packed
node tools/viewer/build.mjs --deps=DIR --check                               # the committed page is the build of tools/viewer/
BW_BYPASS=$VERCEL_BYPASS node tools/web/app_host_check.mjs --url=<a preview>/app --host=DIR/basic-host --out=shots/app_host   # in the MCP Apps reference host
node tools/viewer/first_paint.mjs --scene=.scratch-data/godot/app_userdata/Brickworks/viewer_tools_probe/scene_400.json --scene=.../scene_4000.json   # sizes and first paint, after viewer_tools_probe -- --sizes
```

The reference host is ext-apps' `examples/basic-host`, used as it is, in a
directory of its own (downloaded code): `git clone --depth 1
https://github.com/modelcontextprotocol/ext-apps`, copy `examples/basic-host`
out, `npm install --ignore-scripts` there, then build its two pages with its own
vite (`INPUT=<dir>/index.html` and `INPUT=<dir>/sandbox.html`, `vite build <dir>
--config <dir>/vite.config.ts`). The check runs its `serve.ts` with node, points
the browser from its fixed sandbox address (`localhost:8081`) to `--port`+1, and
stands three MCP connections between it and the relay, each signed in with
OAuth: one that strips `_meta` from every result, one that never says it shows
pages and refuses the page any tool its model was not listed, and one that
passes everything on.

Proves it when: "the page asks the tab for the model itself (tools/call
viewer_scene)" and "draws the model in 3D: WebGL …% of it the model" with every
part drawn, for the host that strips `_meta`, first; then a drag turns it, a
click is in basic-host's Model Context and in the tab's `selection`, Check
tints (warm pixels up, the rest clay), the instructions step forward and back,
Parts gives the BrickLink list, full screen is given, Open in Brickworks opens
`/app?tab=<the tab>`; the strict host's page reads `brickworks://viewer/scene`
and draws the same; the host that passes `_meta` draws from it without asking,
and keeps the viewer's tools from its own list. Against main it fails at "the
page asks the tab for the model itself".

```sh
tools/mcp_check.py --port=8846 --jobs                     # ...in a window: Orthanc's turntable as a job
```

A job's answer (2026-10-16): `viewer_tools_probe` ends with "a call that
became a job answers, once done, as it would have at once" — view_model and
look_at_model asked inline, then with `after_s` 0: each "Started job N" with
`brickworks/job` in its `_meta`, then one `job` call giving the call's own
blocks (in a window `text,text,image`), the same `brickworks/view` parts,
scene and views, and a client that does not show pages the same words and
picture with no `_meta`. `model_view_check.mjs` section 4 does the same
through the relay in a second tab opened `/app?jobs-after=0` (called with
`target`), and shows the card the "Started job" answer: it calls `job`
through the host and draws the picture. Against m33 section 4 fails at "job,
once done, gives its answer with the _meta it would have carried at once".

For the subscription path:

```sh
godot --headless --path . --script src/dev/claude_code_probe.gd
```

Proves it when: it ends on "a design run can reach the bricks and nothing else" —
the command carries `--strict-mcp-config`, `--tools ""` and `--restricted`, and
never anything with "dangerously" or "bypass" in it. That is what makes the
feature safe, and it is not the allowlist: `--allowedTools` only grants
permission, it never takes any away. And "the session sees no key and no token:
key=none token=none" — a real child started the way a design starts, with
`ANTHROPIC_API_KEY` and `ANTHROPIC_AUTH_TOKEN` set in the app, must not see
either, or Claude Code bills the key instead of the subscription (it did, from
any shell that had sourced `.env`); the app keeps both afterwards. A plain
`OS.execute_with_pipe` fails it. A real run spends somebody's subscription and
is done by hand with `--ask-claude-code=`; it prints "on your subscription, 9
tools, all of them this app's" when it connects.

And `mcp_probe` ends on "a session outside the app can use the app's own
tools" — a client connects over real TCP, gets every tool (41 on 2026-10-13) carrying a schema,
searches the real catalogue, submits a design that puts 3 bricks in the world, and
has a floating brick refused, and three clients asking at once each get their
own answer while the app does them one at a time. Over HTTP, a body with an
accent in it is answered, and so is a second request sent in the same write.
`mcp_check.py` ends on "a session can drive
Brickworks over MCP" — initialize, ping, `tools/list` with MCP's `inputSchema`
spelling, a search, a cleared baseplate, a design that lands, a save read back off
disk, and the no-app case answering "not running" with the command to start it.

`gallery_tool_probe` ends on "a session can search the gallery and read a model
in it, and only read" (30 checks against the local functions and the live
database, 2026-10-13): `gallery` in `tools/list` with the gallery's own 11
kinds; a page newest first, each line a model with its link id, credit,
licence and counts, and how to read one crediting its builder; a search, a
kind most viewed first, nothing found said so; a kind, a size, a sort and an
open that are not one refused in words, and a link never shared; one opened
with its link, licence, sub-assemblies, size, parts by kind, the most used and
"Read-only", its picture an image block, `picture=false` leaving it out;
every model on the first page opened in turn, each printed with what its owner
wrote, its kind and tags and its licence, which must be the one its line in
the list gave (one check a model: the seven seed models, 2026-10-13); the
baseplate's part count unchanged, and still answered while the tab shows a
shared model; then, from answers played by `FakeGallery`, each licence's
words, the owner's description, kind and tags, a size and kinds read from the
file, and the most used part named. And, played too, the newer questions: the
seven sorts offered and `shelves`; Top builds and Most built said; a line's
builds, moves and Tested mark; Parts I own refused to nobody signed in with
nothing asked, then asked as the person (`mine=1`, their session) with "you
own 80 of its 93 pieces"; the front's pick and why ("built 3 times this week,
remixed once this week") with its moves, the small builds, and what they can
build now only when signed in. `-- --played` runs only the played part, with
no server (18 checks, all ok, 2026-10-19). `mcp_check.py`, with the app's
`BRICKWORKS_API` at a deployment that has the directory (or the local
functions), also searches the gallery over MCP and opens a model with its
licence, size and picture as an MCP image block: the newest the list itself
(`/api/share?op=list` of `BRICKWORKS_API` or brickworks.diy, up to three
pages) says has a picture (`image`), named in the line ("the gallery lists a
model with a picture: <name> (<id>)", then "<id> opened as a reference").
Until 2026-10-17 it opened the newest, which was a probe's model with no
picture while share_probe ran on the live site, and all five desktop release
jobs failed on it (run 39017125610). A real session, on
the subscription (`env -u ANTHROPIC_API_KEY claude -p ... --strict-mcp-config
--tools "" --restricted --allowedTools mcp__brickworks__gallery`, against an
app started with `--mcp=PORT`), asked for a castle as a reference, answered
from the tool alone with its maker, its size and main parts and that, with no
licence chosen, it may be learned from but not copied (2026-10-13).

`mcp_sync_probe` ends on "the MCP is in step with the app". `app_tools_probe`
ends on "a session can do what the person does from the menus": every one of
the ten called through `answer_rpc` (the connector's and the HTTP port's
path) and read back off the model — the floor it stands on, the step a part
is in, the tube's pieces, the turret's transform, the file on disk — one undo
each, and each refusal naming what to give. Headless, `render_model` and the
picture and booklet exports are refused with "without a window"; in a window
(it runs again on screen in the suite) a quick 720p render comes back with
its picture and is written where Render writes, the crane's animation is
written as a WebP, and the picture and the
booklet are written where Export writes. The probe points `Exports.folder`
and `RenderDialog.folder` and `PosePanel.folder` at its own folder, so nothing lands in Downloads.
Its brickify part serves `tests/fixtures/brickify/bunny.obj` from a web
server of its own on 127.0.0.1 (`AppTools.fetch_near`, which only a probe
sets) and reads the bunny back off the model as one sub-assembly, one undo
step; a link to this computer, a link naming no 3D model and a file over the
cap are each refused, and a link that is not http(s) is told to use `file=`.
`file=` (and a path given as `url=`) lays the same bunny from its path on
disk, one sub-assembly; `file:///etc/passwd` is not read (not a 3D model's
kind) and a path that is not there is said so. Its prints part prints an svg on a 2 x 2 tile and reads
the printed part back where the tile stood, in its colour, one undo step, and
sticks a sticker on a brick's -z face facing -z. Its make_unique part cuts
Wheel (copy 2) loose, by name and by a part in it, and reads the paths back.
Its "long work, as jobs" part: a Studio file answers at once with a job that
is the window's bar, a call meanwhile is told the app is busy, `job` gives the
.io once done and refuses a number that is not one, and `open_model` with
`after_s` at 0 becomes a job part way; in a window, a turntable is counted in
frames by `job` and stopped by its cancel with no WebP written.

The turntable of Orthanc over the real relay needs an app in a window with its
port open, its own data folder and its own Downloads (an `XDG_CONFIG_HOME`
whose `user-dirs.dirs` points `XDG_DOWNLOAD_DIR` at a scratch folder), then
`tools/mcp_check.py --port=PORT --jobs`: the first answer in under 2 s, the
frames counting up as it is polled, the WebP read off disk with its 36 frames,
and a second turntable cancelled part way with no WebP written.
`mcp_check.py` also sets a floor, undoes it, lists the steps and the parts
over the real relay, and checks `tools/mcp_tools.json` names every tool.

All of these are in `tools/check.sh`.

## Gotchas

- **The port is for programs on this machine, not web pages.** It answered
  every origin (`Access-Control-Allow-Origin: *`), so any page open while the
  app listened could clear the baseplate or save over any file. A request with
  an `Origin` header (every request a page makes) or a `Host` that is not
  127.0.0.1, localhost or [::1] (DNS rebinding) gets a 403 and runs nothing;
  Claude Code, curl and Python send neither. `save_model` takes a file name, not
  a path, and writes it with the app's own models (`ModelStore.SAVE_DIR`, where
  Open lists them), never over one the session did not write itself: a design
  run had left `orthanc.ldr` in the directory the app was started from. While
  the design has assemblies without a close review, the answer carries the
  next one's (`Assistant.next_review`; see assistant.md, "reviewed from
  outside"). `mcp_probe` listens on the first free port from 8791, since
  another session's relay can hold it.
  `mcp_probe` sends a page's request and a rebound one (the baseplate keeps its
  bricks), a path that climbs to /tmp, and a save over the person's model.
- **Content-Length counts bytes.** The socket read the body in characters, so
  one accented letter left it a byte short for ever: the app never saw the call,
  and the session waited out the ten-minute tool timeout. Orthanc run 10 lost both
  its submits to "the palantír" in a note. A call that "times out" while the app
  stays responsive to every other tool is this kind of bug, not a slow check.

- **The two halves fail differently.** The socket can be perfect while the relay
  answers `tools/list` with an empty array, and a session then sees a server with
  no tools and no error to explain it. That is why there are two checks and why
  `mcp_check.py` reads `inputSchema` rather than `input_schema`.
- **`properties: {}` is a correct schema.** `clear_model` takes no arguments. A
  check that asks for a *non-empty* properties object fails it, which is a bug in
  the check.
- **The app restores its last model on start-up.** A design submitted at the origin
  lands inside whatever was already standing and comes back as an overlap. Call
  `clear_model` first — a session arriving at an app somebody is using faces
  exactly this.
- **`submit_design` alone does not build anything.** Inside the loop it sets a
  design aside and the loop then checks it and stands it up. `Assistant.use_tool`
  does that second step, which is the only reason it exists rather than the socket
  calling `_run_tool` directly.
- **127.0.0.1 only, and off unless asked for.** An open port that drives the app is
  not something to run by default, and binding the wildcard address would offer it
  to the network. There is no authentication beyond that.
- **One port per app.** Parallel sessions must pass `--mcp=PORT`; the second app on
  8787 says the port is taken and carries on without a socket.
- **One call at a time, across every client.** A session may open several
  connections and send a call down each in the same breath — Claude Code does,
  three `look_at_model` in one turn. There is one baseplate, one lattice and one
  thing that takes pictures, and two picture takers sharing a viewport interleave
  their waits until one of them never gets the frame it is waiting for. The call
  then sits there until the relay's three minutes run out. A real Voyager design
  run said so out loud — "the renderer keeps timing out" — and spent its last ten
  minutes unable to look at what it had built. `_take_a_turn` / `_hand_back` queue
  them; the per-client `busy` flag was never enough, because the second call
  arrives on a different client. The queue waits on **frames**, not on a
  hand-back signal: waiting on the signal alone reads as a deadline and is not
  one — if whoever holds the app never finishes, the signal never comes, the line
  that checks the clock is never reached, and the hang is back one layer down.
  `queued_for` is a variable rather than a constant so the probe can shorten it;
  nobody runs a check that waits a hundred seconds.
- **No assembly animation when nobody is watching.** Every submit and every edit
  emits `built`, and the window then plans build steps for the whole model and
  shows it assembling a step at a time, each step walking every brick
  (`BuildPlayback`). On run 15's 3,000-part Orthanc driven off-screen a frame
  took 13 s while it played, so a look took 130-220 s, `add_rooms` 159 s and a
  restyle 249 s; the session waited on an animation in a window nobody could
  see. An app driven from the command line (`main._driven`, the same flags that
  turn vsync off) skips it: the same calls took 3.6 s, 11.6 s and 11.8 s, and a
  look 0.3 s. Time a driven session's calls with `tools/brick.py` before
  blaming the model's size. Since 2026-10-11 the animation is cheap in a window
  too (only what is new, a step a count per batch; see view.md's build
  animation), so this is now about not drawing for nobody rather than about
  surviving it.
- **A check from outside changes nothing.** `check_design` put its trial on the
  baseplate as the app's own run shows a draft, unless the session had built
  the model standing there itself: the owner's test gear and axle landed on an
  opened model as bricks #223 and #224 (2026-10-13). Only the app's own run
  (`_busy`) shows a draft now. `read_only_probe` opens a model and calls every
  tool that only looks — check_design, the searches, the guides, the looks,
  the selection, where_to_attach, edit_selection check_only, review_model of
  the whole and the creative pass, search_gear_ratio, look_at_picture,
  find_reference, and through the socket on the app's scene parts_list, gallery
  and job — and the parts, colours and transforms are the same to the byte
  after each; and it fails if a tool `CommandSocket.HINTS` calls read-only (so
  Claude is told it is) is not among them. (review_model with a feature lays a
  real set's piece by design: a change, one step to undo, so it is not
  read-only.)
- **What a session changes is one undo step, its own.** An edit_model from
  outside went into no history at all, so the person's Undo after it took back
  their own last part and left Claude's edit standing. Every call through
  `CommandSocket._run` (the MCP port, the web connector, a subscription
  session) that changes the model (its row of `CommandSocket.HINTS` is not
  look or file) and is not in `NOT_A_STEP` has its change made one
  step, "Claude's edit model (1 put down)": a call that keeps its own history
  (the window's commands, edit_selection) folded into one, any other as the
  difference (`SelectionScope.steps_back`). The socket's own tools too:
  review_model with a feature lays a piece, save_model can hand the next
  feature back laid, and clear_model begins a new model as New does, its one
  step putting the old one back.
  `claude_undo_probe`: the person places a brick, a session edits, Undo takes
  the edit and keeps the brick, a second Undo takes the brick; then
  submit_design, review_model of a feature, edit_model (recolour, move,
  remove), restyle_model, add_minifig and clear_model, each one step that
  Undo puts back exactly, and each told to the autosave: a call that moved
  the world's revision raises `CommandSocket.model_changed`, which Main
  wires to `_on_model_changed` for the connector's socket and the port's.
  A figure goes down past the builder's signals (`Builder.put_figure`), so
  before 2026-10-19 a minifigure Claude stood up was lost on reload, and a
  clear_model went unsaved (the probe calls through the app's own connector
  socket, and fails both without it).
- **A tool waits for geometry; it never says "not arrived".** On the web a
  part's geometry comes from the parts bucket the first time it is asked for.
  attachment_points answered "has not arrived yet" for 32523 and 87559, both
  in the bucket (`tools/storage_parts.py --check`: 0 to upload; the live pack
  names the same hashes): it never waited. It waits now
  (`Assistant._geometry_of`), and `_ensure_parts` waits until each part has
  come or is not coming, on the Working bar, not a fixed 20 s, which a browser
  drawing in software at a frame every few seconds ran out of before a gear
  arrived.
- **A picture needs something to draw with.** Over the socket from a headless app
  the look falls back to a text elevation; from a windowed one it is a PNG.
- **`--allowedTools` grants, it does not restrict.** The first run of the
  subscription feature inherited everything the person's own Claude Code has: a
  shell, a file writer, and whatever MCP servers they use — on the machine this
  was built on, their email and their documents. It called `Bash` twice before
  anybody asked it to. Three flags take away: `--strict-mcp-config`, `--tools ""`,
  `--restricted`. The probe checks all three.
- **Not a credential proxy.** Services exist that borrow subscription tokens and
  serve them as an API endpoint. They break the terms the subscription is granted
  under and would put the person's account at risk, so this runs the program they
  installed, as them, on their machine, instead.
- Nothing about this sends the person's API key anywhere. That is the point: the
  key stays in whatever session is already holding it.
