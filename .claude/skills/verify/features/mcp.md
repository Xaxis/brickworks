# MCP

Letting a session that is already open build in Brickworks, instead of Brickworks
asking for an API key.

<!-- covers: lib:command socket, cli:mcp server, cli:drive the app over mcp, cli:drive the app from a shell, ui:design on your own subscription, lib:the window's commands over mcp, cli:keep the mcp in step -->

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
  `animate_model` (Pose and animate's keys and Render), `undo` (Edit,
  Undo and Redo), `open_model` (File, Open), `parts_list` (Build, Parts
  list; My collection, What do I need, What can I build), `render_model`
  (File, Render), `export_model` (File, Export, and Instructions),
  `brickify` (Build, Brickify a 3D model…; File, Import, 3D model),
  `print_part` (Build, Print on a part… and Put a sticker on…) and
  `make_unique` (Edit, Make this copy unique). Each
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
  `export_model`'s studio, picture and instructions, `make_art`) answers at
  once with "Started job N: …" and the work starts on the next frame; any
  other call still going after `after_s` (20 s) becomes a job where it stands
  (timed on Orthanc in software: the first `view_model` over 75 s,
  `check_design` of the Falcon over it 43 s). The `job` tool waits up to
  `wait_s` (10 s) for it to end, then says how far it has got ("12 of 36"),
  gives the answer (picture and all) once done, or that it was cancelled or
  failed; `cancel=true` stops it where it can be stopped. The job **is** the
  `Working` job the person sees along the foot of the window — its words, its
  count, its Cancel — handed down as `work` to `RenderDialog.render_for`,
  `PosePanel.render_animation` and main's `_export_booklet`, so the window's
  Cancel stops the session's render and the session's cancel takes the bar
  away. A job keeps the app's turn until it ends; every other call meanwhile is
  answered at once with "The app is busy with job N". A call that would be
  refused at once (nothing built, nothing to draw with, a plan that will not
  parse) is not a job, so its refusal is the answer. The guidance is in the
  answers themselves and one line of `GUIDE_HEAD`.
- `keep the mcp in step`: `src/dev/mcp_sync_probe.gd`. Fails when
  `tools/mcp_tools.json` is not what the app serves (`-- --write` writes it
  again from the app; it was four tools behind when this was written), when
  `GUIDE_HEAD` reaches 3,500 characters, when a tool is named in neither the
  head nor a section `read_guide` serves (`make_part` and `clear_model` were
  in neither), and when one of the window's commands (Shell) is in neither
  `AppTools.COMMANDS` (the tool that does it) nor `AppTools.WINDOW_ONLY`
  (why it is the window's alone). A command added to the menus fails it
  until it is placed in one.
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
above. 41 in all on 2026-10-13, with `job`, `brickify`, `print_part` and `make_unique`; `mcp_sync_probe` keeps the count honest.)

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
godot --headless --path . --script src/dev/app_tools_probe.gd      # the window's commands as tools
tools/mcp_check.py                                        # the relay's half
tools/mcp_check.py --port=8787                            # against an app you opened
tools/mcp_check.py --port=8846 --jobs                     # ...in a window: Orthanc's turntable as a job
```

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
step; `file://`, this computer, a link naming no 3D model and a file over the
cap are each refused. Its prints part prints an svg on a 2 x 2 tile and reads
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
- **`check_design` puts the trial on the baseplate**, and the baseplate is saved
  and restored on the next start. A design checked at the origin overlaps that
  saved model next time, which reads as a broken checker and is not. Call
  `clear_model` first.
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
