#!/usr/bin/env python3
"""Prove the MCP relay works against a real Brickworks.

    tools/mcp_check.py              start an app, drive it, stop it
    tools/mcp_check.py --port=8787  use an app that is already running

src/dev/mcp_probe.gd covers the app's half: the socket, the tools, a
design landing on the baseplate. This covers the half that probe cannot
reach — tools/brickworks_mcp.py speaking MCP on its stdin, which is what
a Claude Code session actually talks to.

The two halves fail differently. The socket can be perfect while the
relay answers tools/list with an empty array, and a session then sees a
server with no tools and no error to explain it.
"""

from __future__ import annotations

import json
import os
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RELAY = ROOT / "tools" / "brickworks_mcp.py"
# Not the default 8787: this must not attach to the app a person has open.
PORT = 8792
# The app loads a 14 MB catalogue before it listens.
PATIENCE = 180.0

failures = 0


def check(what: str, ok: bool) -> None:
    global failures
    if ok:
        print("  ok    %s" % what)
        return
    failures += 1
    print("  FAIL  %s" % what)


class Relay:
    """tools/brickworks_mcp.py as a client would run it: a pipe each way."""

    def __init__(self, port: int) -> None:
        self.process = subprocess.Popen(
            [sys.executable, str(RELAY), "--port=%d" % port],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            stderr=subprocess.PIPE, text=True, bufsize=1)
        self._id = 0

    def call(self, method: str, params: dict | None = None) -> dict:
        self._id += 1
        message = {"jsonrpc": "2.0", "id": self._id, "method": method}
        if params is not None:
            message["params"] = params
        assert self.process.stdin and self.process.stdout
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()
        line = self.process.stdout.readline()
        if not line:
            raise RuntimeError("the relay said nothing and exited %s"
                               % self.process.poll())
        return json.loads(line)

    def notify(self, method: str) -> None:
        assert self.process.stdin
        self.process.stdin.write(json.dumps({"jsonrpc": "2.0", "method": method}) + "\n")
        self.process.stdin.flush()

    def stop(self) -> None:
        if self.process.poll() is None:
            self.process.terminate()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()


def listening(port: int) -> bool:
    try:
        with socket.create_connection(("127.0.0.1", port), timeout=2.0):
            return True
    except OSError:
        return False


def start_app(port: int) -> subprocess.Popen:
    """A headless app with the port open. Killed by whoever started it."""
    log = open("/tmp/brickworks-mcp-check-%d.log" % port, "w")
    app = subprocess.Popen(
        ["godot", "--headless", "--path", str(ROOT), "--", "--mcp=%d" % port],
        stdout=log, stderr=subprocess.STDOUT,
        # Its own process group, so terminating it cannot reach this one.
        start_new_session=True)
    waited = time.time()
    while time.time() - waited < PATIENCE:
        if app.poll() is not None:
            raise RuntimeError("the app exited %s before listening; see %s"
                               % (app.returncode, log.name))
        if listening(port):
            return app
        time.sleep(0.5)
    raise RuntimeError("the app never listened on %d within %ds; see %s"
                       % (port, PATIENCE, log.name))


def text_of(result: dict) -> str:
    return "".join(block.get("text", "") for block in result.get("content", [])
                   if block.get("type") == "text")


def drive(relay: Relay) -> None:
    hello = relay.call("initialize", {
        "protocolVersion": "2025-06-18",
        "capabilities": {},
        "clientInfo": {"name": "mcp_check", "version": "1"},
    })
    result = hello.get("result", {})
    check("initialize answers with a protocol version",
          result.get("protocolVersion") == "2025-06-18")
    check("...and names the server",
          result.get("serverInfo", {}).get("name") == "brickworks")
    check("...and declares tools",
          "tools" in result.get("capabilities", {}))
    # The app's own guidance, not a second copy written in the relay.
    # A session outside the app has the same tools, the same lattice and
    # the same catalogue; what it did not have was any of the knowledge
    # of how to use them, so it had to work out from refusals that a
    # wedge plate exists and that courses are staggered.
    said = result.get("instructions", "")
    check("...and hands over the app's own design guidance, %d characters"
          % len(said), len(said) > 3000)
    for word in ("COORDINATES", "SIDEWAYS", "COLOUR", "AT AN ANGLE",
                 "WHAT MAKES A MODEL GOOD"):
        check("  it covers %s" % word.lower(), word in said)
    relay.notify("notifications/initialized")

    check("ping answers", relay.call("ping").get("result") == {})

    listed = relay.call("tools/list").get("result", {}).get("tools", [])
    check("tools/list serves %d tools" % len(listed), len(listed) >= 9)
    named = {tool["name"] for tool in listed}
    for wanted in ("search_parts", "check_design", "submit_design",
                   "look_at_model", "view_model", "edit_model",
                   "attachment_points", "clear_model", "save_model"):
        check("  %s is offered" % wanted, wanted in named)
    # MCP's spelling, not Anthropic's. A session cannot call a tool whose
    # schema it cannot read, and the error it gets names the client.
    # Present, not non-empty: clear_model takes no arguments, and an
    # empty properties object is the correct schema for that.
    schemaless = [t["name"] for t in listed
                  if not isinstance((t.get("inputSchema") or {}).get("properties"), dict)]
    check("every tool has an inputSchema, %d without" % len(schemaless),
          not schemaless)

    found = relay.call("tools/call", {
        "name": "search_parts", "arguments": {"query": "wedge", "limit": 5}})
    answer = found.get("result", {})
    check("a search comes back", not answer.get("isError", True))
    check("...with something in it, %d characters" % len(text_of(answer)),
          len(text_of(answer)) > 20)

    # From bare ground, or the design below lands inside whatever model
    # the app restored on start-up and comes back as an overlap. A session
    # arriving at an app somebody is already using faces the same thing,
    # which is why this tool exists.
    bare = relay.call("tools/call", {"name": "clear_model", "arguments": {}})
    check("the baseplate can be cleared from outside",
          "bare" in text_of(bare.get("result", {})))

    built = relay.call("tools/call", {"name": "submit_design", "arguments": {
        "bricks": [
            {"part": "3001", "color": 1, "x": 0, "y": 0, "z": 0, "rot": 0},
            {"part": "3001", "color": 1, "x": 0, "y": 3, "z": 0, "rot": 0},
        ]}})
    said = text_of(built.get("result", {}))
    check("a design lands on the baseplate: %s" % said[:60],
          said.startswith("Built."))

    # A picture, which is the one answer that is not text.
    looked = relay.call("tools/call", {
        "name": "view_model", "arguments": {"from": "corner"}})
    blocks = looked.get("result", {}).get("content", [])
    kinds = {block.get("type") for block in blocks}
    check("looking at the model answers, %s" % sorted(kinds),
          bool(blocks) and not looked.get("result", {}).get("isError", True))
    # Headless has nothing to draw with, so a picture is not required
    # here — but if one comes, it must be MCP's shape and not Anthropic's.
    for block in blocks:
        if block.get("type") == "image":
            check("  a picture carries data and mimeType",
                  bool(block.get("data")) and bool(block.get("mimeType")))

    kept = ROOT / "models" / ".mcp_check.ldr"
    saved = relay.call("tools/call", {
        "name": "save_model", "arguments": {"path": str(kept)}})
    check("...and the model can be saved from outside",
          "Written to" in text_of(saved.get("result", {})))
    # Read back, because "Written to" is the app's word for it and the
    # file is the thing that matters.
    lines = kept.read_text().splitlines() if kept.exists() else []
    bricks = [line for line in lines if line.startswith("1 ")]
    check("...and the file holds the two bricks, %d" % len(bricks),
          len(bricks) == 2)
    kept.unlink(missing_ok=True)

    unknown = relay.call("tools/call", {"name": "no_such_tool", "arguments": {}})
    check("an unknown tool is an answer, not a crash",
          "No tool called" in text_of(unknown.get("result", {})))

    broken = relay.call("tools/call", {"arguments": {}})
    check("a call with no name is a JSON-RPC error",
          broken.get("error", {}).get("code") == -32602)


def drive_without_an_app() -> None:
    """What a session sees when the app is not running.

    This is the common case — the relay starts with the session, the app
    is opened later — and it has to read as "start the app", not as a
    broken server.
    """
    free = PORT + 1
    while listening(free):
        free += 1
    relay = Relay(free)
    try:
        relay.call("initialize", {"protocolVersion": "2025-06-18",
                                  "capabilities": {}, "clientInfo": {}})
        listed = relay.call("tools/list").get("result", {}).get("tools", [])
        check("with no app, tools/list still serves the cached tools, %d"
              % len(listed), len(listed) >= 9)
        answer = relay.call("tools/call", {
            "name": "search_parts", "arguments": {"query": "brick"}}
        ).get("result", {})
        check("...and a call says the app is not running",
              bool(answer.get("isError"))
              and "not running" in text_of(answer))
        check("...and says how to start it",
              "--mcp" in text_of(answer))
    finally:
        relay.stop()


def main(argv: list[str]) -> int:
    port = PORT
    mine = True
    for argument in argv[1:]:
        if argument.startswith("--port="):
            port = int(argument.split("=", 1)[1])
            mine = False
        else:
            print("mcp_check: unknown option %s" % argument, file=sys.stderr)
            return 2

    app: subprocess.Popen | None = None
    relay: Relay | None = None
    try:
        if mine:
            print("── starting an app on %d ──" % port)
            app = start_app(port)
        elif not listening(port):
            print("mcp_check: nothing is listening on %d" % port, file=sys.stderr)
            return 2
        print("── the relay ──")
        relay = Relay(port)
        drive(relay)
        print("── and with no app at all ──")
        drive_without_an_app()
    finally:
        if relay is not None:
            relay.stop()
        # Only what this run started. Another session's app is not ours
        # to close, which is why --port never kills anything.
        if app is not None and app.poll() is None:
            os.killpg(os.getpgid(app.pid), signal.SIGTERM)
            try:
                app.wait(timeout=20)
            except subprocess.TimeoutExpired:
                os.killpg(os.getpgid(app.pid), signal.SIGKILL)

    print("")
    if failures:
        print("%d FAILURE(S)" % failures)
        return 1
    print("a session can drive Brickworks over MCP")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
