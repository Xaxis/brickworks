#!/usr/bin/env python3
"""Let a Claude Code session build in Brickworks, instead of Brickworks
asking for an API key.

The app already holds the design loop: the real catalogue answers
searches, the real lattice decides whether a brick fits, and what holds
together goes on the baseplate. Nothing in that needs a key — only the
model proposing the placements does. If a session is already open, it can
be the model, and the key stays wherever that session keeps it.

So this is an MCP server over stdio that relays to a running Brickworks:

    Claude Code  --MCP/stdio-->  this  --TCP--> Brickworks (src/net/command_socket.gd)

Add it to a session with:

    claude mcp add brickworks -- /mnt/Projects/brickworks/tools/brickworks_mcp.py

and start the app with the port open:

    godot --path . -- --mcp          # or --mcp=PORT for a second one

The tools are not defined here. They are fetched from the app, which
serves the same list it offers Claude, so the two cannot drift. A copy in
tools/mcp_tools.json is used only to answer tools/list while the app is
closed, so a session that connects first still knows what it will be able
to do.

And the list changes: the app is updated and started again, or was not
running when the session listed the copy. A session went on with the list
it was given for good. So this says listChanged: true, and whenever it has
had to connect to the app afresh it asks the app's list again; when that
is not the list the session was last given, it sends
notifications/tools/list_changed after the answer, once, and the session
lists the tools again.

No dependencies: stdlib only, because the machines this runs on do not all
have pip.
"""

from __future__ import annotations

import hashlib
import json
import os
import socket
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# BRICKWORKS_MCP_CACHE moves it, for a test playing an app of its own.
CACHED_TOOLS = Path(os.environ.get("BRICKWORKS_MCP_CACHE") or ROOT / "tools" / "mcp_tools.json")
DEFAULT_PORT = 8787
# Long enough for a tool that fetches geometry or draws a picture, short
# enough that a wedged app does not hang the session forever.
PATIENCE = 180.0
# And long enough to get *in*. Five seconds was not: the app answers the
# socket from its frame loop, and the first picture of a session compiles
# shaders, which stops the loop for longer than that. The connection then
# timed out and the session was told Brickworks was not running, while it
# sat there in front of the person drawing their model.
WAY_IN = 45.0

PROTOCOL = "2025-06-18"
KNOWN_PROTOCOLS = {"2024-11-05", "2025-03-26", PROTOCOL}

NOT_RUNNING = (
    "Brickworks is not running, or is not listening on port %d.\n"
    "Start it with:  godot --path %s -- --mcp\n"
    "and the window will show what you build as you build it."
)
# Said apart from the above on purpose. The two look identical from here
# and mean opposite things: one is "open the app", the other is "it is
# open and working, ask again".
TOO_SLOW = (
    "Brickworks is listening on port %d but did not answer within %ds. "
    "It is busy — the first picture of a session compiles shaders, and a "
    "large design takes a moment to check. Ask again."
)
DROPPED = (
    "The connection to Brickworks on port %d dropped twice (%s). The app "
    "is up; something went wrong mid-request."
)


class App:
    """The connection to the running app, reopened whenever it drops.

    One socket, one request at a time. The app answers in order on the
    same connection, and a session only ever has one tool call in flight.
    """

    def __init__(self, port: int) -> None:
        self.port = port
        self._sock: socket.socket | None = None
        self._rest = b""
        self._next_id = 0
        # How many times a connection has been made: one more than before
        # means the app may be another one, started since.
        self.connected = 0

    def ask(self, tool: str, arguments: dict) -> dict:
        """One request. Raises ConnectionError, saying which kind."""
        broke: BaseException | None = None
        for _attempt in (1, 2):
            try:
                return self._ask_once(tool, arguments)
            except ConnectionError:
                # Already says exactly what is wrong. Retrying a refused
                # port or a busy app just doubles the wait.
                raise
            except (OSError, ValueError) as wrong:
                broke = wrong
                self._drop()
        raise ConnectionError(DROPPED % (self.port, broke))

    def _ask_once(self, tool: str, arguments: dict) -> dict:
        sock = self._connect()
        self._next_id += 1
        line = json.dumps({"id": self._next_id, "tool": tool, "input": arguments})
        sock.sendall(line.encode() + b"\n")
        return json.loads(self._read_line(sock))

    def _connect(self) -> socket.socket:
        if self._sock is not None:
            return self._sock
        try:
            sock = socket.create_connection(
                ("127.0.0.1", self.port), timeout=WAY_IN)
        except (ConnectionRefusedError, socket.gaierror):
            raise ConnectionError(NOT_RUNNING % (self.port, ROOT)) from None
        except (socket.timeout, TimeoutError):
            raise ConnectionError(TOO_SLOW % (self.port, int(WAY_IN))) from None
        sock.settimeout(PATIENCE)
        self._sock = sock
        self._rest = b""
        self.connected += 1
        return sock

    def _read_line(self, sock: socket.socket) -> bytes:
        while b"\n" not in self._rest:
            try:
                chunk = sock.recv(1 << 16)
            except (socket.timeout, TimeoutError):
                raise ConnectionError(
                    TOO_SLOW % (self.port, int(PATIENCE))) from None
            if not chunk:
                raise OSError("the app closed the connection")
            self._rest += chunk
        line, self._rest = self._rest.split(b"\n", 1)
        return line

    def _drop(self) -> None:
        if self._sock is not None:
            try:
                self._sock.close()
            finally:
                self._sock = None
        self._rest = b""


def _cached() -> list[dict] | None:
    """The copy kept for when the app is closed, or None. Compared before
    it is written again, so a session listing the tools of an app that has
    not changed leaves the file (and the checkout) as it was."""
    try:
        return json.loads(CACHED_TOOLS.read_text())
    except (OSError, ValueError):
        return None


def live_tools(app: App) -> list[dict] | None:
    """The app's own list, or None when it cannot be asked."""
    try:
        answer = app.ask("__tools__", {})
    except ConnectionError:
        return None
    tools = answer.get("tools") or []
    if tools and tools != _cached():
        CACHED_TOOLS.write_text(json.dumps(tools, indent=2, ensure_ascii=False) + "\n")
    return _as_mcp(tools)


def tool_list(app: App) -> list[dict]:
    """The tools, from the app when it is up and from the copy when not."""
    live = live_tools(app)
    if live is not None:
        return live
    if not CACHED_TOOLS.exists():
        return []
    return _as_mcp(json.loads(CACHED_TOOLS.read_text()))


def _as_mcp(tools: list[dict]) -> list[dict]:
    """The app's schemas are Anthropic's shape (`input_schema`); MCP wants
    `inputSchema`. Translated here because it is the only difference. The
    annotations (title, readOnlyHint and the rest) come from the app as
    they are, from its one table of them (CommandSocket.HINTS)."""
    listed = []
    for tool in tools:
        if not tool.get("name"):
            continue
        one = {
            "name": tool["name"],
            "description": tool.get("description", ""),
            "inputSchema": tool.get("input_schema") or tool.get("inputSchema") or {},
        }
        if tool.get("annotations"):
            one["annotations"] = tool["annotations"]
        listed.append(one)
    return listed


# Said only when the app is shut, which is the one time the real thing
# cannot be fetched. Everything specific lives in the app.
ABOUT = (
    "Brickworks is a dimensionally exact CAD app for LEGO® bricks, open in a "
    "window the "
    "person is looking at. These tools are the same ones its own assistant "
    "uses: search the real part catalogue, check a design against the real "
    "collision lattice, look at what is built, and submit a design to stand "
    "it up on the baseplate. Coordinates are studs across (x), plates up "
    "(y) and studs deep (z), to a brick's low corner. The app is not "
    "running yet, so this is the short version — start it and the rest "
    "arrives with the tools."
)


def guidance(app: App) -> str:
    """How to design well here, in the app's own words.

    Fetched rather than written down, for the reason the tool list is:
    two copies of advice drift, and the one that drifts is the one
    nobody is testing.
    """
    try:
        answer = app.ask("__about__", {})
    except ConnectionError:
        return ABOUT
    said = str(answer.get("instructions") or "").strip()
    return said or ABOUT


def call(app: App, name: str, arguments: dict) -> dict:
    """One tool call, as MCP tool-result content."""
    try:
        answer = app.ask(name, arguments)
    except ConnectionError as gone:
        return {"content": [{"type": "text", "text": str(gone)}], "isError": True}
    if not answer.get("ok", False):
        return {
            "content": [{"type": "text", "text": str(answer.get("error", "the app said no"))}],
            "isError": True,
        }
    content = answer.get("content") or []
    # An empty answer is still an answer, but MCP wants at least one block
    # and a client shows nothing for an empty list.
    return {"content": content or [{"type": "text", "text": "(nothing)"}], "isError": False}


def _hash(tools: list[dict]) -> str:
    return hashlib.sha256(json.dumps(tools, sort_keys=True).encode()).hexdigest()[:16]


LIST_CHANGED = {"jsonrpc": "2.0", "method": "notifications/tools/list_changed"}


class Listing:
    """Which tools the session was last given, so it can be told when the
    app it reaches serves others."""

    def __init__(self) -> None:
        self.given: str | None = None
        self.told: str | None = None
        self.on = -1

    def gave(self, tools: list[dict], app: App) -> None:
        self.given = self.told = _hash(tools)
        self.on = app.connected

    def changed(self, app: App) -> bool:
        """True, once, when the app has been connected to afresh since the
        session listed the tools and serves another list now."""
        if self.given is None or app.connected == self.on:
            return False
        self.on = app.connected
        live = live_tools(app)
        if live is None:
            return False
        now = _hash(live)
        if now in (self.given, self.told):
            return False
        self.told = now
        return True


def handle(app: App, message: dict, listing: Listing | None = None) -> dict | None:
    """A JSON-RPC request in, a response out, or None for a notification."""
    method = message.get("method", "")
    sent_id = message.get("id")
    params = message.get("params") or {}

    if sent_id is None:  # a notification: initialized, cancelled, progress
        return None

    def result(payload: dict) -> dict:
        return {"jsonrpc": "2.0", "id": sent_id, "result": payload}

    if method == "initialize":
        wanted = params.get("protocolVersion")
        return result({
            "protocolVersion": wanted if wanted in KNOWN_PROTOCOLS else PROTOCOL,
            "capabilities": {"tools": {"listChanged": True}},
            "serverInfo": {"name": "brickworks", "version": "1"},
            "instructions": guidance(app),
        })
    if method == "ping":
        return result({})
    if method == "tools/list":
        tools = tool_list(app)
        if listing is not None:
            listing.gave(tools, app)
        return result({"tools": tools})
    if method == "tools/call":
        name = str(params.get("name", ""))
        if not name:
            return {"jsonrpc": "2.0", "id": sent_id,
                    "error": {"code": -32602, "message": "no tool named"}}
        return result(call(app, name, params.get("arguments") or {}))
    if method in ("resources/list", "prompts/list"):
        # Answered rather than refused: a client that asks for these and
        # gets an error logs it as a broken server.
        return result({"resources": [], "prompts": []})
    return {"jsonrpc": "2.0", "id": sent_id,
            "error": {"code": -32601, "message": "no method %r" % method}}


def main(argv: list[str]) -> int:
    port = int(os.environ.get("BRICKWORKS_PORT", DEFAULT_PORT))
    for argument in argv[1:]:
        if argument.startswith("--port="):
            port = int(argument.split("=", 1)[1])
        elif argument in ("-h", "--help"):
            print(__doc__)
            return 0
        else:
            print("brickworks_mcp: unknown option %s" % argument, file=sys.stderr)
            return 2
    app = App(port)
    listing = Listing()
    # Line-buffered stdout, and nothing else may ever be written to it:
    # one stray print corrupts the stream and the session loses the server.
    out = sys.stdout
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            out.write(json.dumps({"jsonrpc": "2.0", "id": None,
                "error": {"code": -32700, "message": "not JSON"}}) + "\n")
            out.flush()
            continue
        try:
            answer = handle(app, message, listing)
        except Exception as wrong:  # noqa: BLE001 - never die on one bad call
            answer = {"jsonrpc": "2.0", "id": message.get("id"),
                      "error": {"code": -32603, "message": str(wrong)}}
        if answer is not None:
            out.write(json.dumps(answer) + "\n")
            out.flush()
        try:
            told = message.get("method") not in ("initialize", "tools/list") and listing.changed(app)
        except Exception:  # noqa: BLE001 - a check, never a reason to stop
            told = False
        if told:
            out.write(json.dumps(LIST_CHANGED) + "\n")
            out.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
