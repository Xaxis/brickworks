# MCP

Letting a session that is already open build in Brickworks, instead of Brickworks
asking for an API key.

<!-- covers: lib:command socket, cli:mcp server, cli:drive the app over mcp, cli:drive the app from a shell -->

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
godot --headless --path . --script src/dev/mcp_probe.gd   # the app's half
tools/mcp_check.py                                        # the relay's half
tools/mcp_check.py --port=8787                            # against an app you opened
```

Proves it when: `mcp_probe` ends on "a session outside the app can use the app's own
tools" — a client connects over real TCP, gets 9 tools all carrying schemas,
searches the real catalogue, submits a design that puts 3 bricks in the world, and
has a floating brick refused. `mcp_check.py` ends on "a session can drive
Brickworks over MCP" — initialize, ping, `tools/list` with MCP's `inputSchema`
spelling, a search, a cleared baseplate, a design that lands, a save read back off
disk, and the no-app case answering "not running" with the command to start it.

Both are in `tools/check.sh`.

## Gotchas

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
- **`check_design` puts the trial on the baseplate**, and the baseplate is saved
  and restored on the next start. A design checked at the origin overlaps that
  saved model next time, which reads as a broken checker and is not. Call
  `clear_model` first.
- **A picture needs something to draw with.** Over the socket from a headless app
  the look falls back to a text elevation; from a windowed one it is a PNG.
- Nothing about this sends the person's API key anywhere. That is the point: the
  key stays in whatever session is already holding it.
