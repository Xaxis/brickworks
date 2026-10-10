# MCP

Letting a session that is already open build in Brickworks, instead of Brickworks
asking for an API key.

<!-- covers: lib:command socket, cli:mcp server, cli:drive the app over mcp, cli:drive the app from a shell, ui:design on your own subscription -->

## Sub-features

- `command socket`: a line-delimited JSON port the app opens on 127.0.0.1 when
  `--mcp` asks for it. One object in, one out. `__tools__` answers with the tool
  list, `__ping__` with the app's name and port, and anything else is run through
  `Assistant.use_tool` — the same implementations the app's own assistant calls.
- `mcp server`: `tools/brickworks_mcp.py`, which speaks MCP on stdio and relays to
  that port. Stdlib only, no dependencies. It carries no tool definitions of its
  own: it fetches them from the app, so the two cannot drift, and keeps a copy in
  `tools/mcp_tools.json` only to answer `tools/list` while the app is closed. The
  MCP `instructions` are fetched the same way (`__about__`) — all 13k characters
  of the app's own design guidance, the same words the in-app loop is given, so a
  session is not left working out from refusals that wedge plates exist.
- `drive the app over mcp`: `tools/mcp_check.py` starts a headless app, drives the
  relay as a client would, and stops the app it started.
- `design on your own subscription`: **My Claude** in the design panel. The app
  starts the Claude Code on this machine and points it back at itself over MCP, so
  the thinking is paid for by the person's Claude subscription — no API key, no
  account, nothing billed by us. Desktop only; a browser cannot start a program.
- `drive the app from a shell`: `tools/brick.py` calls one tool and prints the
  answer, writing any picture to `--png=PATH`. The same socket without the MCP
  wrapping, for a script, a person reading along, or an agent that would rather
  open the picture as a file.

Nine tools reach a session: the assistant's seven (`search_parts`, `check_design`,
`attachment_points`, `edit_model`, `look_at_model`, `view_model`, `submit_design`)
plus two the design loop never needs — `clear_model`, because a loop clears the
board itself when a design begins and a session has no such moment, and
`save_model`, because the person normally saves from the window.

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
tools/mcp_check.py                                        # the relay's half
tools/mcp_check.py --port=8787                            # against an app you opened
```

For the subscription path:

```sh
godot --headless --path . --script src/dev/claude_code_probe.gd
```

Proves it when: it ends on "a design run can reach the bricks and nothing else" —
the command carries `--strict-mcp-config`, `--tools ""` and `--restricted`, and
never anything with "dangerously" or "bypass" in it. That is what makes the
feature safe, and it is not the allowlist: `--allowedTools` only grants
permission, it never takes any away. A real run spends somebody's subscription and
is done by hand with `--ask-claude-code=`; it prints "on your subscription, 9
tools, all of them this app's" when it connects.

And `mcp_probe` ends on "a session outside the app can use the app's own
tools" — a client connects over real TCP, gets 9 tools all carrying schemas,
searches the real catalogue, submits a design that puts 3 bricks in the world, and
has a floating brick refused, and three clients asking at once each get their
own answer while the app does them one at a time. Over HTTP, a body with an
accent in it is answered, and so is a second request sent in the same write.
`mcp_check.py` ends on "a session can drive
Brickworks over MCP" — initialize, ping, `tools/list` with MCP's `inputSchema`
spelling, a search, a cleared baseplate, a design that lands, a save read back off
disk, and the no-app case answering "not running" with the command to start it.

Both are in `tools/check.sh`.

## Gotchas

- **The port is for programs on this machine, not web pages.** It answered
  every origin (`Access-Control-Allow-Origin: *`), so any page open while the
  app listened could clear the baseplate or save over any file. A request with
  an `Origin` header (every request a page makes) or a `Host` that is not
  127.0.0.1, localhost or [::1] (DNS rebinding) gets a 403 and runs nothing;
  Claude Code, curl and Python send neither. `save_model` takes a file name, not
  a path, and writes it with the app's own models (`ModelStore.SAVE_DIR`, where
  Open lists them), never over one the session did not write itself: a design
  run had left `orthanc.ldr` in the directory the app was started from.
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
