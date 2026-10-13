#!/usr/bin/env python3
"""Prove the MCP relay works against a real Brickworks.

    tools/mcp_check.py              start an app, drive it, stop it
    tools/mcp_check.py --port=8787  use an app that is already running
    tools/mcp_check.py --port=8787 --jobs
                                    ...in a window, and also render a
                                    turntable of Orthanc as a job and
                                    cancel a second one (drive_jobs)

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
import shutil
import re
import os
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path
from typing import Callable

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


def followed(relay: "Relay", result: dict) -> dict:
    """A call that became a job (src/net/tool_jobs.gd), polled with job to its
    end as a session does: the job's own answer, its "is done" line taken off.
    Any call still going after 20 s becomes one, so on a loaded machine a
    simulate_mechanism that weighs and draws a model is one too."""
    started = re.match(r"Started job (\d+)", text_of(result))
    if not started:
        return result
    waited = time.time()
    while time.time() - waited < 1800:
        answer = relay.call("tools/call", {"name": "job", "arguments": {
            "id": int(started.group(1))}}).get("result", {})
        if " is still going" in text_of(answer):
            continue
        blocks = list(answer.get("content", []))
        if blocks and blocks[0].get("type") == "text":
            rest = re.sub(r"^Job \d+ \([^)]*\) is done, after \d+ s:\n?", "",
                          blocks[0].get("text", ""))
            blocks = ([{"type": "text", "text": rest}] if rest else []) + blocks[1:]
        return dict(answer, content=blocks)
    return result


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
                   "attachment_points", "clear_model", "save_model",
                   "add_minifig", "make_part", "selection", "edit_selection",
                   "where_to_attach"):
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

    # Asked with the subject before building, it also hands over our own
    # scored designs of the nearest one and the judge's faults in them
    # (src/ai/design_memory.gd). Not with the app started --held-out.
    recalled = relay.call("tools/call", {
        "name": "how_real_sets_build_this", "arguments": {"subject": "race car"}})
    said = text_of(recalled.get("result", {}))
    check("how_real_sets_build_this \"race car\" hands over our best Porsche "
          "and what the judge faulted",
          "FROM OUR OWN SCORED DESIGNS" in said and "Porsche" in said
          and "What the judge faulted" in said)

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

    # By name, into the app's own models: the answer says where that is.
    saved = relay.call("tools/call", {
        "name": "save_model", "arguments": {"name": "mcp-check-%d.ldr" % os.getpid()}})
    said = text_of(saved.get("result", {}))
    check("...and the model can be saved from outside", "Written to" in said)
    where = re.search(r"\(([^()]*\.ldr)\)", said)
    kept = Path(where.group(1)) if where else ROOT / "nowhere.ldr"
    # Read back, because "Written to" is the app's word for it and the
    # file is the thing that matters.
    lines = kept.read_text().splitlines() if kept.exists() else []
    bricks = [line for line in lines if line.startswith("1 ")]
    check("...and the file holds the two bricks, %d" % len(bricks),
          len(bricks) == 2)
    kept.unlink(missing_ok=True)

    # The window's own commands, which a session has as tools too
    # (src/net/app_tools.gd): read back off the model, not off the answer.
    def say(name: str, arguments: dict) -> str:
        return text_of(followed(relay, relay.call("tools/call", {
            "name": name, "arguments": arguments}).get("result", {})))

    said = say("set_floor", {"kind": "grid"})
    check("the floor is chosen from outside: %s" % said, "grid floor" in said)
    said = say("set_floor", {})
    check("...and reads back as it was set: %s" % said, "grid floor" in said)
    said = say("undo", {})
    check("undo takes it back: %s" % said[:60],
          said.startswith("Undid floor") and "grid" not in say("set_floor", {}))
    listed = say("edit_steps", {})
    check("the build steps are listed: %s" % listed.splitlines()[0] if listed else "",
          "step" in listed and "#" in listed)
    parts = say("parts_list", {})
    check("the parts list counts the two bricks: %s" % parts.splitlines()[0] if parts else "",
          parts.startswith("2 pieces in 1 lots") and "3001" in parts)
    said = say("lay_flex", {"kind": "rope"})
    check("a refusal says what to fix: %s" % said[:50], said.startswith("kind is one of"))

    simulate(relay, say, kept.parent)
    # The gallery (src/net/gallery_tool.gd), read-only, from the app's own
    # deployment (BRICKWORKS_API, or brickworks.diy): searched, and one
    # model opened as a reference with its credit, licence and picture.
    found = say("gallery", {"sort": "newest"})
    first = re.search(r"^1\. .*?\(([A-Za-z0-9]{10})\)", found, re.M)
    check("the gallery searched over MCP: %s" % (found.splitlines()[0][:80] if found else "nothing"),
          found.startswith("The gallery at") and first is not None and "credit them" in found)
    if first:
        opened = relay.call("tools/call", {"name": "gallery", "arguments": {"open": first.group(1)}})
        blocks = opened.get("result", {}).get("content", [])
        words = text_of(opened.get("result", {}))
        check("...one opened as a reference, with its licence and size: %s" % words.splitlines()[0][:70],
              "Licence:" in words and "Size:" in words and "Read-only" in words)
        check("...and its picture as an MCP image block",
              any(b.get("type") == "image" and b.get("mimeType", "").startswith("image/")
                  and len(b.get("data", "")) > 500 for b in blocks))

    cached = json.loads((ROOT / "tools" / "mcp_tools.json").read_text())
    check("tools/mcp_tools.json names every tool the app serves, %d" % len(cached),
          {tool["name"] for tool in cached} == named)

    unknown = relay.call("tools/call", {"name": "no_such_tool", "arguments": {}})
    check("an unknown tool is an answer, not a crash",
          "No tool called" in text_of(unknown.get("result", {})))

    broken = relay.call("tools/call", {"arguments": {}})
    check("a call with no name is a JSON-RPC error",
          broken.get("error", {}).get("code") == -32602)


def drive_jobs(relay: Relay) -> None:
    """Long work as a job, on Orthanc: a turntable, then one cancelled.

    A Claude session waits about three minutes for an answer, and a
    turntable of Orthanc's 9,429 parts takes longer than that, so it is a
    job (src/net/tool_jobs.gd): answered at once, polled with job, and
    stopped by it. Needs an app in a window, which renders; started with
    --mcp=PORT and driven with --port=PORT --jobs.
    """
    def call(name: str, arguments: dict) -> tuple[str, float]:
        began = time.time()
        result = relay.call("tools/call", {"name": name, "arguments": arguments})
        return text_of(result.get("result", {})), time.time() - began

    said, _ = call("open_model", {"name": "Orthanc", "discard_changes": True})
    check("Orthanc is open: %s" % said[:50], said.startswith("Opened Orthanc"))

    said, took = call("render_model", {"kind": "turntable"})
    started = re.match(r"Started job (\d+)", said)
    job = int(started.group(1)) if started else 0
    check("a turntable of Orthanc answers at once, in %.2f s: %s" % (took, said[:60]),
          bool(started) and took < 2.0)
    check("...saying how to follow it",
          ('job {"id": %d}' % job) in said and '"cancel": true' in said)
    busy, took = call("look_at_model", {})
    check("a call meanwhile is told what the app is busy with, in %.2f s: %s"
          % (took, busy[:60]), busy.startswith("The app is busy with job %d" % job))

    frames: list[int] = []
    final = ""
    began = time.time()
    while time.time() - began < 3600:
        said, _ = call("job", {"id": job})
        if " is still going" not in said:
            final = said
            break
        counted = re.search(r"(\d+) of 36", said)
        if counted:
            frames.append(int(counted.group(1)))
    print("        frames seen while polling: %s" % frames)
    check("polling shows the frames going by, %d polls over %.0f s"
          % (len(frames), time.time() - began),
          len(set(frames)) >= 3 and frames == sorted(frames))
    check("...and the job ends done: %s" % final.splitlines()[0] if final else "never",
          " is done, after " in final)
    wrote = re.search(r"wrote (\S+\.webp)", final)
    webp = Path(wrote.group(1)) if wrote else ROOT / "nowhere.webp"
    data = webp.read_bytes() if webp.exists() else b""
    check("the WebP arrives: %s, %d bytes, %d frames"
          % (webp.name, len(data), data.count(b"ANMF")),
          data[:4] == b"RIFF" and data[8:12] == b"WEBP" and data.count(b"ANMF") == 36)
    webp.unlink(missing_ok=True)

    said, took = call("render_model", {"kind": "turntable"})
    started = re.match(r"Started job (\d+)", said)
    job = int(started.group(1)) if started else 0
    check("a second one is a job too, in %.2f s" % took, job > 0 and took < 2.0)
    counted = None
    while job and counted is None:
        said, _ = call("job", {"id": job})
        counted = re.search(r"([1-9]\d*) of 36", said)
        if " is still going" not in said:
            break
    said, took = call("job", {"id": job, "cancel": True})
    # A frame of Orthanc being drawn in software is finished first.
    while " is still going" in said:
        said, more = call("job", {"id": job})
        took += more
    check("cancelled at frame %s of 36, stopped %.1f s later: %s"
          % (counted.group(1) if counted else "?", took, said[:70]),
          " was cancelled after " in said)
    after, _ = call("parts_list", {})
    check("...the app is free again: %s" % after.splitlines()[0][:50] if after else "",
          " pieces in " in after)
    time.sleep(10)
    check("...and nothing more was drawn: no WebP was written", not webp.exists())
    said, _ = call("job", {})
    check("...and job still says so: %s" % said[:60], " was cancelled after " in said)
FIXTURES = ROOT / "src" / "dev" / "fixtures"


def simulate(relay: Relay, say: Callable[[str, dict], str], models: Path) -> None:
    """simulate_mechanism, as a session asks it of a model it has open.

    The models are src/dev/simulate_probe.gd's, written there with --write:
    a session cannot yet seat an axle in a hole over MCP, so they are put in
    the app's models and opened with open_model, which a session can do.
    """
    opened: list[Path] = []
    try:
        for fixture, name in (("orrery_two_planets.ldr", "orrery"),
                              ("gears_locked.ldr", "gears")):
            target = models / ("mcp-check-%s-%d.ldr" % (name, os.getpid()))
            target.write_text((FIXTURES / fixture).read_text())
            opened.append(target)
        said = say("open_model", {"name": opened[0].stem, "discard_changes": True})
        check("the two-planet orrery opens: %s" % said[:50], said.startswith("Opened"))
        answer = followed(relay, relay.call("tools/call", {"name": "simulate_mechanism",
                                                           "arguments": {}}).get("result", {}))
        said = text_of(answer)
        print("    %s" % said.replace("\n", " | ")[:900])
        check("simulate_mechanism turns it from the crank its name marks",
              said.startswith("Driven by Crank"))
        check("...with Mars's year in Earth years against NASA's",
              "Mars arm: 1.96 Earth years; real 1.8808, +4.2%" in said)
        check("...and the balance over the whole cycle, the arm furthest out named",
              "Balance over 72 frames of the cycle" in said and "Furthest out: Mars arm" in said)
        blocks = answer.get("content", [])
        drawn = any(block.get("type") == "image" for block in blocks)
        if drawn:
            check("...and a picture of it at its worst",
                  all(block.get("data") and block.get("mimeType") == "image/png"
                      for block in blocks if block.get("type") == "image"))
        else:
            check("...and, headless, says why there is no picture", "No picture" in said)
        said = say("simulate_mechanism", {"reference": "Mars arm",
                                          "targets": {"Earth": 0.5}})
        check("reference= and targets= count Earth in Mars years against the one asked for",
              "Earth: 0.5102 Mars years; asked for 0.5, +2.0%" in said)
        said = say("simulate_mechanism", {"driver": "no such part"})
        check("a driver that is not there is a refusal that says what to give: %s" % said[:40],
              said.startswith("No part or sub-assembly"))
        if drawn:
            # A recording is a job, as a render is: answered at once, then
            # polled with job until it gives the answer.
            began = time.time()
            said = text_of(relay.call("tools/call", {"name": "simulate_mechanism", "arguments": {
                "record": True, "frames": 8}}).get("result", {}))
            took = time.time() - began
            started = re.match(r"Started job (\d+)", said)
            check("record=true is a job, answered in %.1f s: %s" % (took, said[:60]),
                  bool(started) and took < 5.0)
            job = int(started.group(1)) if started else 0
            counted: list[int] = []
            waited = time.time()
            while job and time.time() - waited < 1800:
                said = say("job", {"id": job})
                if " is still going" not in said:
                    break
                frame = re.search(r"(\d+) of 8", said)
                if frame:
                    counted.append(int(frame.group(1)))
            print("        frames seen while polling: %s" % counted)
            check("...polled to its end, the frames counted on it: %s" % said.splitlines()[0][:80],
                  " is done, after " in said and counted == sorted(counted))
            written = re.findall(r"wrote (\S+\.(?:webp|mp4))", said)
            check("record=true keeps it: %s" % (", ".join(written) or said[-120:]),
                  "Recorded 8 frames" in said and bool(written)
                  and all(Path(path).exists() for path in written))
            # Written where Render saves, the person's Downloads: taken away.
            for path in written:
                Path(path).unlink(missing_ok=True)
            for folder in re.findall(r"frames in (\S+?)[;.]?(?:\s|$)", said):
                if Path(folder).is_dir() and Path(folder).name.endswith("_mechanism"):
                    shutil.rmtree(folder)
        said = say("open_model", {"name": opened[1].stem, "discard_changes": True})
        said = say("simulate_mechanism", {})
        print("    %s" % said.replace("\n", " | ")[:600])
        check("a locked train is said to be locked, its meshes by number",
              "LOCKED" in said and "The ones that fight: #" in said)
        check("...and a gear on no axle floating, by number",
              "Floating (on no axle" in said)
        said = say("clear_model", {})
    finally:
        for target in opened:
            target.unlink(missing_ok=True)


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
    jobs = False
    for argument in argv[1:]:
        if argument.startswith("--port="):
            port = int(argument.split("=", 1)[1])
            mine = False
        elif argument == "--jobs":
            jobs = True
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
        if jobs:
            print("── long work as jobs, on Orthanc ──")
            drive_jobs(relay)
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
