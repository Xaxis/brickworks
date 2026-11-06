#!/usr/bin/env python3
"""The one MCP server a booklet builder's session has (tools/bench/booklet_follow.py).

    booklet_mcp.py --port=N --pages=DIR --run=DIR --models=DIR [--reading=FILE]

A builder is a Claude Code session that builds a model from its booklet as a
person at a table does: it sees the pages and what it has built, and never the
model's file. So the session is given this server alone (--strict-mcp-config,
no built-in tools) and this server gives it:

  booklet_page   a page of the booklet as its picture (DIR/page-N.png); how its pages
                 read is a Brickworks booklet's (READING) or FILE's
  page_done      the builder's word that a page is built, and what the page did
                 not let it tell; the app's model is saved as it stands then
                 (run/snapshots/page-N.ldr)
  and the few app tools a person's hands and eyes stand for: look_at_model,
  view_model, edit_model, attachment_points, search_parts, undo, relayed to
  the app (brickworks_mcp.App). Nothing else of the app's reaches the session:
  open_model, the gallery and the library would hand it the very model.

Every call and answer's text goes to run/calls.jsonl, a page's word to
run/pages.jsonl. Stdlib only, as brickworks_mcp.py is.
"""

from __future__ import annotations

import base64
import json
import os
import re
import shutil
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import brickworks_mcp  # noqa: E402

# The app's tools a builder may use: its eyes and its hands, no more.
RELAYED = ("look_at_model", "view_model", "edit_model", "attachment_points", "search_parts",
           "undo")
# A call still going after 20 s becomes one of the app's jobs, and the app answers "Started
# job N" or, to the next call, "The app is busy with job N" (src/net/tool_jobs.gd). A picture
# waits for the GPU's lease, which other work on the box can hold for minutes. A person's
# eyes wait for the picture, so the relay waits on the job and hands its answer on, as the app's
# own design loop does (designer_loop._wait_for); the builder has no job tool. Without it, on
# 2026-11-05 a builder was told "busy with job 4" for a minute, stopped twice, and its run lost
# page 6. page_done's save waits the same way. JOB_WAIT is the longest wait, in seconds.
JOB = re.compile(r"(Started job|The app is busy with job) (\d+)")
JOB_WAIT = 600.0
WHY = ("hidden", "position", "too_many", "callout", "turn", "part", "colour", "count", "other")

# How a Brickworks booklet's pages read. A booklet drawn another way (a printed LEGO® one,
# measured against ours) says how its own read: booklet_follow's reading.json, "page".
READING = (
    "Page 1 is the cover; the steps begin on page 2; the finished model and the parts list "
    "come last. Each step on a page has its number, a box of the parts it adds with how many "
    "of each (2x), and a picture of the model with the step's new parts outlined. A yellow "
    "box is a sub-assembly built on the side, put on whole in the step its arrow points to.")
PAGE_TOOL = {
    "name": "booklet_page",
    "description": (
        f"One page of the booklet, as its picture. {READING} Look at any page you like, "
        "before or after the one you are building."),
    "inputSchema": {"type": "object", "additionalProperties": False,
                    "properties": {"page": {"type": "integer"}}, "required": ["page"]},
    "annotations": {"readOnlyHint": True},
}

DONE_TOOL = {
    "name": "page_done",
    "description": (
        "Say a page is built, once every part its steps add is placed as well as you can "
        "tell. The model is kept as it stands now. placed: how many parts you put in for "
        "this page. unclear: each thing the page did not let you tell, with why: hidden (a "
        "new part, or where it goes, could not be seen), position (it could be seen but not "
        "where exactly: which stud, how far along), too_many (too many parts or steps on one "
        "picture to follow), callout (a sub-assembly's box: what it is or where it goes), "
        "turn (the model was drawn from another side or turned, and you lost your way), part "
        "(which part it is), colour, count (how many), other. notes: anything you want to "
        "remember for the pages after this one (which way the model faces, where things "
        "are)."),
    "inputSchema": {"type": "object", "additionalProperties": False, "properties": {
        "page": {"type": "integer"},
        "placed": {"type": "integer"},
        "unclear": {"type": "array", "items": {
            "type": "object", "additionalProperties": False,
            "properties": {"step": {"type": "integer"}, "what": {"type": "string"},
                           "why": {"type": "string", "enum": list(WHY)}},
            "required": ["what", "why"]}},
        "notes": {"type": "string"}},
        "required": ["page", "placed"]},
}

INSTRUCTIONS = (
    "You are building a LEGO® model from its instruction booklet, as a person at a table "
    "does, in Brickworks, a LEGO CAD app. You have the booklet's pages (booklet_page) and "
    "what you have built (look_at_model lists it, view_model shows it); nothing else tells "
    "you what the model is. Coordinates are studs across (x), plates up (y, a brick is 3) "
    "and studs deep (z), to a part's low corner; look_at_model prints every part's. "
    "edit_model's add places parts; attachment_points gives a stud's exact coordinates; "
    "undo takes back the last change. Build a page, compare view_model with its picture, "
    "then call page_done.")



def _text(answer: dict) -> str:
    """The first words of an answer."""
    for block in answer.get("content", []):
        if block.get("type") == "text":
            return str(block.get("text", ""))
    return ""


class Server:
    """What one session may reach: the pages, its run's records, the relayed tools."""

    def __init__(self, port: int, pages: Path, run: Path, models: Path,
                 app: brickworks_mcp.App | None = None, reading: str | None = None) -> None:
        self.app = app or brickworks_mcp.App(port)
        self.pages = pages
        self.page_tool = PAGE_TOOL if reading is None else {
            **PAGE_TOOL, "description": PAGE_TOOL["description"].replace(READING, reading)}
        self.run = run
        self.models = models
        (run / "snapshots").mkdir(parents=True, exist_ok=True)

    def page_count(self) -> int:
        return len(list(self.pages.glob("page-*.png")))

    def tools(self) -> list[dict]:
        # The app's own list, read and never written back: brickworks_mcp.live_tools
        # keeps a copy in tools/mcp_tools.json, which a bench run must not change.
        try:
            listed = self.app.ask("__tools__", {}).get("tools") or []
        except ConnectionError:
            listed = json.loads(brickworks_mcp.CACHED_TOOLS.read_text())
        relayed = [t for t in brickworks_mcp._as_mcp(listed) if t["name"] in RELAYED]
        return [self.page_tool, DONE_TOOL, *relayed]

    def _log(self, name: str, record: dict) -> None:
        with (self.run / name).open("a") as out:
            out.write(json.dumps({"at": round(time.time(), 1), **record}) + "\n")

    def call(self, name: str, arguments: dict) -> dict:
        if name == "booklet_page":
            answer = self.page(int(arguments.get("page", 0)))
        elif name == "page_done":
            answer = self.done(arguments)
        elif name in RELAYED:
            answer = self.relay(name, arguments)
        else:
            answer = {"content": [{"type": "text", "text": f"There is no tool {name} here."}],
                      "isError": True}
        said = " ".join(b.get("text", "") for b in answer.get("content", [])
                        if b.get("type") == "text")
        self._log("calls.jsonl", {"tool": name, "input": arguments, "error": answer["isError"],
                                  "said": said[:4000],
                                  "images": sum(b.get("type") == "image"
                                                for b in answer.get("content", []))})
        return answer

    def relay(self, name: str, arguments: dict) -> dict:
        """The app's answer to the call, waited for when it became a job: the job's answer
        when the call started it, the call made again once the job it waited behind ends."""
        answer = brickworks_mcp.call(self.app, name, arguments)
        for _ in range(3):
            found = JOB.match(_text(answer))
            if found is None:
                return answer
            ended = self.wait(int(found.group(2)))
            if found.group(1) == "Started job":
                return ended
            answer = brickworks_mcp.call(self.app, name, arguments)
        return answer

    def wait(self, job: int) -> dict:
        """Job `job`'s answer once it ends (each ask waits up to 45 s in the app), or what
        the app last said of it after JOB_WAIT seconds."""
        until = time.time() + JOB_WAIT
        while True:
            answer = brickworks_mcp.call(self.app, "job", {"id": job})
            going = re.match(rf"Job {job} \(.*?\) is still going", _text(answer))
            if going is None or answer["isError"] or time.time() > until:
                return answer

    def page(self, number: int) -> dict:
        picture = self.pages / f"page-{number}.png"
        if not picture.exists():
            return {"content": [{"type": "text", "text":
                                 f"There is no page {number}: the booklet has pages 1 to "
                                 f"{self.page_count()}."}], "isError": True}
        data = base64.b64encode(picture.read_bytes()).decode()
        return {"content": [{"type": "text", "text": f"Page {number} of {self.page_count()}."},
                            {"type": "image", "data": data, "mimeType": "image/png"}],
                "isError": False}

    def done(self, arguments: dict) -> dict:
        number = int(arguments.get("page", 0))
        name = f"follow-page-{number}"
        kept = ""
        try:
            answer = self._save_when_free(name)
            saved = self.models / f"{name}.ldr"
            if answer.get("ok") and saved.exists():
                target = self.run / "snapshots" / f"page-{number}.ldr"
                shutil.copy(saved, target)
                kept = str(target)
        except ConnectionError as gone:
            kept = f"not kept: {gone}"
        unclear = [u for u in arguments.get("unclear") or [] if isinstance(u, dict)]
        self._log("pages.jsonl", {"page": number, "placed": arguments.get("placed"),
                                  "unclear": unclear, "notes": arguments.get("notes", ""),
                                  "snapshot": kept})
        return {"content": [{"type": "text", "text":
                             f"Page {number} noted; the model is kept as it stands."}],
                "isError": False}

    def _save_when_free(self, name: str) -> dict:
        """save_model, once the job the builder's last edit started has finished.

        A builder may say page_done while its edit is still a job (the edit's picture
        waits for the GPU): the save was then answered "busy", nothing was kept, and the
        page scored as nothing built. 2 of 3 runs of 7140 page 18 were lost so
        (blackedges, 2026-11-05)."""
        end = time.time() + JOB_WAIT
        while True:
            answer = self.app.ask("save_model", {"name": name})
            said = " ".join(b.get("text", "") for b in answer.get("content") or []
                            if isinstance(b, dict))
            busy = re.match(r"The app is busy with job (\d+)", said)
            if not busy or time.time() > end:
                return answer
            self.wait(int(busy.group(1)))

    def handle(self, message: dict) -> dict | None:
        method = message.get("method", "")
        sent_id = message.get("id")
        params = message.get("params") or {}
        if sent_id is None:
            return None

        def result(payload: dict) -> dict:
            return {"jsonrpc": "2.0", "id": sent_id, "result": payload}

        if method == "initialize":
            wanted = params.get("protocolVersion")
            return result({
                "protocolVersion": wanted if wanted in brickworks_mcp.KNOWN_PROTOCOLS
                else brickworks_mcp.PROTOCOL,
                "capabilities": {"tools": {"listChanged": False}},
                "serverInfo": {"name": "booklet", "version": "1"},
                "instructions": INSTRUCTIONS})
        if method == "ping":
            return result({})
        if method == "tools/list":
            return result({"tools": self.tools()})
        if method == "tools/call":
            return result(self.call(str(params.get("name", "")), params.get("arguments") or {}))
        if method in ("resources/list", "prompts/list"):
            return result({"resources": [], "prompts": []})
        return {"jsonrpc": "2.0", "id": sent_id,
                "error": {"code": -32601, "message": "no method %r" % method}}


def main(argv: list[str]) -> int:
    options = dict(a[2:].split("=", 1) for a in argv[1:] if a.startswith("--") and "=" in a)
    if not {"port", "pages", "run", "models"} <= options.keys():
        print(__doc__, file=sys.stderr)
        return 2
    reading = Path(options["reading"]).read_text().strip() if "reading" in options else None
    server = Server(int(options["port"]), Path(options["pages"]), Path(options["run"]),
                    Path(options["models"]), reading=reading)
    out = sys.stdout
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            message = json.loads(line)
        except ValueError:
            continue
        try:
            answer = server.handle(message)
        except Exception as wrong:  # noqa: BLE001 - never die on one bad call
            answer = {"jsonrpc": "2.0", "id": message.get("id"),
                      "error": {"code": -32603, "message": str(wrong)}}
        if answer is not None:
            out.write(json.dumps(answer) + "\n")
            out.flush()
    return 0


if __name__ == "__main__":
    os.umask(0o022)
    sys.exit(main(sys.argv))
