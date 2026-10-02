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

No dependencies: stdlib only, because the machines this runs on do not all
have pip.
"""

from __future__ import annotations

import json
import os
import socket
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CACHED_TOOLS = ROOT / "tools" / "mcp_tools.json"
DEFAULT_PORT = 8787
# Long enough for a tool that fetches geometry or draws a picture, short
# enough that a wedged app does not hang the session forever.
PATIENCE = 180.0

PROTOCOL = "2025-06-18"
KNOWN_PROTOCOLS = {"2024-11-05", "2025-03-26", PROTOCOL}

NOT_RUNNING = (
    "Brickworks is not running, or is not listening on port %d.\n"
    "Start it with:  godot --path %s -- --mcp\n"
    "and the window will show what you build as you build it."
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

    def ask(self, tool: str, arguments: dict) -> dict:
        """One request. Raises ConnectionError when the app is not there."""
        for attempt in (1, 2):
            try:
                return self._ask_once(tool, arguments)
            except (OSError, ValueError):
                self._drop()
                if attempt == 2:
                    raise ConnectionError(NOT_RUNNING % (self.port, ROOT))
        raise ConnectionError(NOT_RUNNING % (self.port, ROOT))

    def _ask_once(self, tool: str, arguments: dict) -> dict:
        sock = self._connect()
        self._next_id += 1
        line = json.dumps({"id": self._next_id, "tool": tool, "input": arguments})
        sock.sendall(line.encode() + b"\n")
        return json.loads(self._read_line(sock))

    def _connect(self) -> socket.socket:
        if self._sock is not None:
            return self._sock
        sock = socket.create_connection(("127.0.0.1", self.port), timeout=5.0)
        sock.settimeout(PATIENCE)
        self._sock = sock
        self._rest = b""
        return sock

    def _read_line(self, sock: socket.socket) -> bytes:
        while b"\n" not in self._rest:
            chunk = sock.recv(1 << 16)
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


def tool_list(app: App) -> list[dict]:
    """The tools, from the app when it is up and from the copy when not.

    The app's schemas are Anthropic's shape (`input_schema`); MCP wants
    `inputSchema`. Translated here because it is the only difference.
    """
    try:
        answer = app.ask("__tools__", {})
        tools = answer.get("tools") or []
        if tools:
            CACHED_TOOLS.write_text(json.dumps(tools, indent=2) + "\n")
    except ConnectionError:
        if not CACHED_TOOLS.exists():
            return []
        tools = json.loads(CACHED_TOOLS.read_text())
    return [
        {
            "name": tool["name"],
            "description": tool.get("description", ""),
            "inputSchema": tool.get("input_schema") or tool.get("inputSchema") or {},
        }
        for tool in tools
        if tool.get("name")
    ]


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


def handle(app: App, message: dict) -> dict | None:
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
            "capabilities": {"tools": {"listChanged": False}},
            "serverInfo": {"name": "brickworks", "version": "1"},
            "instructions": (
                "Brickworks is a dimensionally exact LEGO CAD app, open in a "
                "window the person is looking at. These tools are the same ones "
                "its own assistant uses: search the real part catalogue, check a "
                "design against the real collision lattice, look at what is "
                "built, and submit a design to stand it up on the baseplate. "
                "Coordinates are studs across (x), plates up (y) and studs deep "
                "(z), to a brick's low corner. Check before you submit, and look "
                "at what you built — a model that holds together is not the same "
                "as one that reads as the thing it is meant to be."
            ),
        })
    if method == "ping":
        return result({})
    if method == "tools/list":
        return result({"tools": tool_list(app)})
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
            answer = handle(app, message)
        except Exception as wrong:  # noqa: BLE001 - never die on one bad call
            answer = {"jsonrpc": "2.0", "id": message.get("id"),
                      "error": {"code": -32603, "message": str(wrong)}}
        if answer is not None:
            out.write(json.dumps(answer) + "\n")
            out.flush()
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
