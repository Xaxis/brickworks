"""A Claude Code session hears when the app's tools change.

tools/brickworks_mcp.py hands a session the app's tools once, when it
lists them, and the session goes on with that list. The app is updated and
started again — or was not running at all when the session listed the
copy in tools/mcp_tools.json — and the session never learned of a new
tool, because the bridge said listChanged: false.

Played here with the real bridge, as a session runs it (a pipe each way),
and a stand-in for the app on a port of its own that speaks the app's line
protocol (src/net/command_socket.gd): one build's tools, then, started
again on the same port, a newer build's. The bridge's copy of the list is
pointed at a file of the test's own, never the repository's.
"""

from __future__ import annotations

import json
import os
import select
import socket
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BRIDGE = ROOT / "tools" / "brickworks_mcp.py"


def _tool(name: str) -> dict:
    return {"name": name, "description": name.replace("_", " "),
            "input_schema": {"type": "object", "properties": {}}}


OLDER = [_tool("look_at_model")]
NEWER = [_tool("look_at_model"), _tool("newer_tool")]


class FakeApp:
    """The app's line protocol on 127.0.0.1:port, serving [tools]."""

    def __init__(self, port: int, tools: list[dict]) -> None:
        self.tools = tools
        self.server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.server.bind(("127.0.0.1", port))
        self.server.listen(4)
        self.clients: list[socket.socket] = []
        self.thread = threading.Thread(target=self._serve, daemon=True)
        self.thread.start()

    def _serve(self) -> None:
        while True:
            try:
                client, _ = self.server.accept()
            except OSError:
                return
            self.clients.append(client)
            threading.Thread(target=self._talk, args=(client,), daemon=True).start()

    def _talk(self, client: socket.socket) -> None:
        rest = b""
        while True:
            try:
                chunk = client.recv(65536)
            except OSError:
                return
            if not chunk:
                return
            rest += chunk
            while b"\n" in rest:
                line, rest = rest.split(b"\n", 1)
                asked = json.loads(line)
                tool = asked.get("tool")
                if tool == "__tools__":
                    said = {"id": asked["id"], "ok": True, "tools": self.tools}
                elif tool == "__about__":
                    said = {"id": asked["id"], "ok": True, "instructions": "a stand-in"}
                else:
                    names = ",".join(t["name"] for t in self.tools)
                    said = {"id": asked["id"], "ok": True,
                            "content": [{"type": "text", "text": "served by " + names}]}
                try:
                    client.sendall(json.dumps(said).encode() + b"\n")
                except OSError:
                    return

    def stop(self) -> None:
        # Shut down first: a close alone leaves the accept waiting in its
        # thread holding the port, and the next app could not take it.
        try:
            self.server.shutdown(socket.SHUT_RDWR)
        except OSError:
            pass
        self.server.close()
        self.thread.join(timeout=5)
        for client in self.clients:
            try:
                client.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            client.close()


class Session:
    """The bridge, as Claude Code runs it."""

    def __init__(self, port: int, cache: Path) -> None:
        env = dict(os.environ, BRICKWORKS_MCP_CACHE=str(cache))
        self.process = subprocess.Popen(
            [sys.executable, str(BRIDGE), "--port=%d" % port],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, env=env)
        self.sent = 0
        self.rest = b""

    def lines(self, wait: float) -> list[dict]:
        """Every message the bridge writes within [wait] seconds."""
        assert self.process.stdout is not None
        found: list[dict] = []
        out = self.process.stdout.fileno()
        while True:
            ready, _, _ = select.select([out], [], [], wait)
            if not ready:
                return found
            chunk = os.read(out, 65536)
            if not chunk:
                return found
            self.rest += chunk
            while b"\n" in self.rest:
                line, self.rest = self.rest.split(b"\n", 1)
                found.append(json.loads(line))
            wait = 0.6

    def ask(self, method: str, params: dict | None = None) -> list[dict]:
        """A request, and everything the bridge says after it."""
        assert self.process.stdin is not None
        self.sent += 1
        message = {"jsonrpc": "2.0", "id": self.sent, "method": method, "params": params or {}}
        self.process.stdin.write(json.dumps(message).encode() + b"\n")
        self.process.stdin.flush()
        return self.lines(20.0)

    def close(self) -> None:
        if self.process.stdin:
            self.process.stdin.close()
        self.process.wait(timeout=10)


def _free_port() -> int:
    probe = socket.socket()
    probe.bind(("127.0.0.1", 0))
    port = probe.getsockname()[1]
    probe.close()
    return port


def _told(said: list[dict]) -> bool:
    return any(m.get("method") == "notifications/tools/list_changed" for m in said)


def test_a_session_is_told_once_when_the_app_serves_other_tools() -> None:
    port = _free_port()
    with tempfile.TemporaryDirectory() as scratch:
        app = FakeApp(port, OLDER)
        session = Session(port, Path(scratch) / "tools.json")
        try:
            started = session.ask("initialize", {"protocolVersion": "2025-06-18"})
            assert started[0]["result"]["capabilities"]["tools"]["listChanged"] is True
            listed = session.ask("tools/list")
            assert [t["name"] for t in listed[0]["result"]["tools"]] == ["look_at_model"]
            first = session.ask("tools/call", {"name": "look_at_model", "arguments": {}})
            assert len(first) == 1 and not _told(first), first

            # The app updated and started again, on the same port.
            app.stop()
            app = FakeApp(port, NEWER)
            after = session.ask("tools/call", {"name": "look_at_model", "arguments": {}})
            assert after[0].get("id") == session.sent, after
            assert "newer_tool" in after[0]["result"]["content"][0]["text"]
            assert _told(after), after
            again = session.ask("tools/call", {"name": "look_at_model", "arguments": {}})
            assert not _told(again), again
            relisted = session.ask("tools/list")
            assert "newer_tool" in [t["name"] for t in relisted[0]["result"]["tools"]]

            # Started again as it was: nothing has changed, nothing is said.
            app.stop()
            app = FakeApp(port, NEWER)
            same = session.ask("tools/call", {"name": "look_at_model", "arguments": {}})
            assert not _told(same), same
        finally:
            session.close()
            app.stop()


def test_a_session_that_listed_the_copy_is_told_when_the_app_comes_up() -> None:
    port = _free_port()
    with tempfile.TemporaryDirectory() as scratch:
        cache = Path(scratch) / "tools.json"
        cache.write_text(json.dumps(OLDER))
        session = Session(port, cache)
        app = None
        try:
            listed = session.ask("tools/list")
            assert [t["name"] for t in listed[0]["result"]["tools"]] == ["look_at_model"]
            app = FakeApp(port, NEWER)
            first = session.ask("tools/call", {"name": "look_at_model", "arguments": {}})
            assert _told(first), first
            assert json.loads(cache.read_text()) == NEWER
            assert (ROOT / "tools" / "mcp_tools.json").read_text() != cache.read_text()
        finally:
            session.close()
            if app is not None:
                app.stop()
