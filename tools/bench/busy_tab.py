#!/usr/bin/env python3
"""Does a tab stay open to Claude while it works a long job? A design's calls made through
the connector relay to a tab started as the relay bench starts one, with the tab's word to
the relay watched the whole time.

    python3 tools/bench/busy_tab.py --app=CHECKOUT --calls=FILE [--only=0,16,29,35]
        [--ports=9860-9861] [--out=DIR] [--think=1.0] [--stall]

The Charger of design19 (bench/results/realset-2026-11-05-d19lev/42111-1) lost its whole
build: a 1,118-part edit_model was a job, its picture waited two minutes for the GPU, the
session asked the job how it went, waited its 45 s, and its next call a second later was
told "The tab this chat was working in ... has closed, so nothing was done" (bigedit,
2026-11-06). The relay judges a tab by when it last spoke (api/mcp.js TAB_GONE_MS, 45 s),
and a desktop window spoke only when it asked for work, which it does again only once the
call it holds is answered.

This plays that session's part. The relay is the checkout's own (tools/web/relay_server.mjs,
production Supabase, an account opened for the run and deleted after); the tab is the
checkout's app, headless, signed in, its connector on, as tools/bench/realset.py starts
one. --stall gives it a drawer that never draws, as the bench's GPU queue held one: every
picture then waits its two minutes, and an edit is a long job. FILE is one JSON line a
call, {n, name, input}, as src/dev/replay_session.gd reads (job, tabs and select_tab are
the session's own and left out). A call answered "Started job N" is followed as Claude
Code follows one: job {"id": N}, --think seconds after each answer, until it is done.

Watched, and said at the end:
  - every call's answer: none may say the tab has closed, is not open or did not answer;
  - the tab's last word to the relay (relay_tabs.seen_at), read every half second: the
    longest it went without one, and how old it was the moment each job answer came back,
    which is when the session's next call finds it. 45 s or more is a tab the relay calls
    gone;
  - each job's progress, as each asking of it said it;
  - one undo after each edit job takes the model back to its parts before it.
Results in DIR/busy_tab.json and the tab's log beside it. Exit 0 when all hold.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from bench import realset  # noqa: E402

# The relay's limit (api/mcp.js TAB_GONE_MS), and the room a working tab keeps under it.
GONE_S = 45.0
BAR_S = 15.0
# A drawer that never draws: the bench's, held in the GPU's queue.
STALLED = ["bash", "-c", "sleep 900", "drawer"]
TROUBLE = re.compile(r"has closed|is not open|did not answer|not answered for|No Brickworks tab")


def _env(keys: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    for line in keys.read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            k, v = line.split("=", 1)
            out[k.strip()] = v.strip().strip('"').strip("'")
    return out


class Watch(threading.Thread):
    """relay_tabs.seen_at of the account's tab, every half second, as the relay reads it."""

    def __init__(self, keys: dict[str, str], owner: str):
        super().__init__(daemon=True)
        self.url = (keys["SUPABASE_URL"].rstrip("/") + "/rest/v1/relay_tabs?owner=eq."
                    + owner + "&select=seen_at,open,visible")
        self.key = keys["SUPABASE_SECRET_KEY"]
        self.stop = False
        self.seen: list[float] = []
        self.longest = 0.0
        self.longest_at = ""

    def read(self) -> float | None:
        asked = urllib.request.Request(self.url, headers={
            "apikey": self.key, "authorization": f"Bearer {self.key}"})
        try:
            with urllib.request.urlopen(asked, timeout=10) as answer:
                rows = json.loads(answer.read().decode())
        except (OSError, ValueError):
            return None
        if not rows or not rows[0].get("seen_at"):
            return None
        return datetime.fromisoformat(rows[0]["seen_at"].replace("Z", "+00:00")).timestamp()

    def run(self) -> None:
        while not self.stop:
            seen = self.read()
            if seen is not None:
                if not self.seen or seen != self.seen[-1]:
                    if self.seen and seen - self.seen[-1] > self.longest:
                        self.longest = seen - self.seen[-1]
                        self.longest_at = datetime.fromtimestamp(seen, timezone.utc).isoformat()
                    self.seen.append(seen)
                # Still waiting for the next word: as long as it has been.
                quiet = time.time() - self.seen[-1]
                if quiet > self.longest:
                    self.longest = quiet
                    self.longest_at = "now"
            time.sleep(0.5)

    def age(self) -> float | None:
        seen = self.read()
        return None if seen is None else time.time() - seen


class Claude:
    """An MCP session on the relay, as Claude Code keeps one."""

    def __init__(self, origin: str, token: str):
        self.url = f"{origin}/api/mcp"
        self.token = token
        self.session = ""
        self.sent = 0

    def ask(self, method: str, params: dict) -> dict:
        self.sent += 1
        headers = {"content-type": "application/json", "accept": "application/json",
                   "authorization": f"Bearer {self.token}"}
        if self.session:
            headers["mcp-session-id"] = self.session
        asked = urllib.request.Request(self.url, method="POST", headers=headers, data=json.dumps(
            {"jsonrpc": "2.0", "id": self.sent, "method": method, "params": params}).encode())
        with urllib.request.urlopen(asked, timeout=300) as answer:
            self.session = answer.headers.get("mcp-session-id") or self.session
            return json.loads(answer.read().decode())

    def call(self, name: str, arguments: dict) -> str:
        said = self.ask("tools/call", {"name": name, "arguments": arguments})
        result = said.get("result") or {}
        text = "\n".join(b.get("text", "") for b in result.get("content", [])
                         if isinstance(b, dict) and b.get("type") == "text")
        return text or json.dumps(said.get("error") or said)[:400]


def main() -> int:
    ask = argparse.ArgumentParser()
    ask.add_argument("--app", required=True)
    ask.add_argument("--calls", required=True)
    ask.add_argument("--only", default="")
    ask.add_argument("--ports", default="9860-9861")
    ask.add_argument("--out", default=str(ROOT / "shots" / "busy_tab"))
    ask.add_argument("--think", type=float, default=1.0)
    ask.add_argument("--stall", action="store_true")
    args = ask.parse_args()
    app = Path(args.app).resolve()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    keys_file = ROOT / ".env"
    if not keys_file.exists():
        keys_file = Path(subprocess.run(["git", "rev-parse", "--path-format=absolute",
                                         "--git-common-dir"], cwd=ROOT, capture_output=True,
                                        text=True).stdout.strip()).parent / ".env"
    keys = _env(keys_file)
    only = {int(n) for n in args.only.split(",") if n.strip()}
    calls = [json.loads(line) for line in Path(args.calls).read_text().splitlines() if line.strip()]
    calls = [c for c in calls if not only or int(c.get("n", 0)) in only]
    relay_port, app_port = (int(p) for p in args.ports.split("-"))
    origin = f"http://127.0.0.1:{relay_port}"
    home = out / "tab_home"
    user_dir = home / "godot" / "app_userdata" / "Brickworks"
    relay = tab = None
    account: dict = {}
    rows: list[dict] = []
    watch: Watch | None = None
    started = time.time()

    def say(text: str) -> None:
        print(f"[{time.time() - started:7.1f} s] {text}", flush=True)

    def node(*words: str) -> subprocess.CompletedProcess:
        return subprocess.run(["node", f"--env-file={keys_file}", *words], cwd=app,
                              capture_output=True, text=True, timeout=180)

    try:
        with (out / "relay.log").open("w") as log:
            relay = subprocess.Popen(["node", f"--env-file={keys_file}",
                                      str(app / "tools/web/relay_server.mjs"), str(relay_port)],
                                     cwd=app, stdout=log, stderr=subprocess.STDOUT,
                                     start_new_session=True)
        if not realset._until(lambda: "functions on" in (out / "relay.log").read_text(), 30, 0.5):
            raise SystemExit("the relay never listened")
        opened = node(str(app / "tools/web/relay_account.mjs"), "open", f"--origin={origin}")
        if opened.returncode != 0:
            raise SystemExit(f"no account: {opened.stderr[-300:]}")
        account = json.loads(opened.stdout.strip().splitlines()[-1])
        user_dir.mkdir(parents=True, exist_ok=True)
        (user_dir / "session.json").write_text(json.dumps(account["kept"]))
        drawer = STALLED if args.stall else realset.bench.DRAWER
        env = realset.bench._billing_free_env(XDG_DATA_HOME=str(home), BRICKWORKS_API=origin,
                                              MESA_VK_WSI_DEBUG="sw")
        with (out / "tab.log").open("w") as log:
            tab = subprocess.Popen(
                ["godot", "--headless", "--path", str(app), "--", f"--mcp={app_port}",
                 "--assistant=on", "--signed-in", "--draw-by=" + json.dumps(drawer)],
                cwd=app, stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
                env=realset._tab_env(env, home, False))
        if not realset._until(lambda: tab.poll() is None
                              and realset._tab_open(origin, account["token"]), 300, 3.0):
            raise SystemExit("the tab never switched its connector on")
        say(f"tab listening: relay {origin}, app {app_port}, {app}")
        watch = Watch(keys, account["user"])
        watch.start()
        claude = Claude(origin, account["token"])
        claude.ask("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                  "clientInfo": {"name": "busy_tab", "version": "1"}})
        claude.ask("tools/list", {})
        for call in calls:
            name, given = str(call["name"]), call.get("input", {})
            began = time.time()
            text = claude.call(name, given)
            row = {"n": call.get("n"), "call": name, "said": [text[:600]], "progress": [],
                   "ages_at_answer": [], "trouble": bool(TROUBLE.search(text))}
            job = re.search(r"Started job (\d+)", text)
            while job and not row["trouble"]:
                age = watch.age()
                row["ages_at_answer"].append(round(age, 1) if age is not None else None)
                time.sleep(args.think)
                text = claude.call("job", {"id": int(job.group(1))})
                row["said"].append(text[:600])
                row["trouble"] = bool(TROUBLE.search(text))
                going = re.search(r"is still going, (\d+) s in[^:]*: (.*?) Call job", text, re.S)
                if not going:
                    break
                row["progress"].append(f"{going.group(1)} s: {going.group(2).strip()}")
            row["seconds"] = round(time.time() - began, 1)
            parts = re.findall(r"(\d+) (?:bricks|parts)", text)
            row["parts"] = int(parts[0]) if parts else None
            rows.append(row)
            say(f"{name} {row['seconds']} s{' TROUBLE' if row['trouble'] else ''}, "
                f"tab's word at each job answer {row['ages_at_answer']} s old, "
                f"progress {row['progress']}: {text[:160]!r}")
            time.sleep(args.think)
        # One undo after the last call takes it back: the parts before it, read again.
        before = next((r["parts"] for r in reversed(rows[:-1]) if r["parts"]), None)
        undone = claude.call("undo", {})
        looked = claude.call("look_at_model", {})
        now = re.search(r"(\d+) parts are on the baseplate", looked)
        rows.append({"call": "undo", "said": [undone[:400], looked[:200]],
                     "parts": int(now.group(1)) if now else None, "before": before,
                     "trouble": bool(TROUBLE.search(undone + looked))})
        say(f"undo: {undone[:160]!r}; then {looked[:120]!r}")
    finally:
        if watch is not None:
            watch.stop = True
        realset._stop(tab)
        if account.get("user"):
            closed = node(str(app / "tools/web/relay_account.mjs"), "close",
                          f"--user={account['user']}")
            if closed.returncode != 0:
                print(f"the account {account.get('email')} was NOT deleted: {closed.stderr[-300:]}")
        realset._stop(relay)
    ages = [a for r in rows for a in r.get("ages_at_answer", []) if a is not None]
    result = {
        "app": str(app), "commit": realset.bench.commit(app), "stall": args.stall,
        "think": args.think, "rows": rows,
        "longest_silence_s": round(watch.longest, 1) if watch else None,
        "longest_silence_at": watch.longest_at if watch else "",
        "words": len(watch.seen) if watch else 0,
        "oldest_at_a_job_answer_s": max(ages) if ages else None,
    }
    (out / "busy_tab.json").write_text(json.dumps(result, indent=1) + "\n")
    jobs = [r for r in rows if r.get("ages_at_answer")]
    undo = rows[-1] if rows and rows[-1].get("call") == "undo" else {}
    checks = [
        ("no answer said the tab had closed, was not open or did not answer",
         not any(r["trouble"] for r in rows)),
        (f"the tab's longest silence {result['longest_silence_s']} s is under {BAR_S:.0f} s "
         f"(the relay calls one of {GONE_S:.0f} s gone)",
         result["longest_silence_s"] is not None and result["longest_silence_s"] < BAR_S),
        (f"its word at every job answer at most {result['oldest_at_a_job_answer_s']} s old",
         not ages or max(ages) < BAR_S),
        (f"{len(jobs)} call(s) were jobs, each asked of said what it was doing",
         all(r["progress"] for r in jobs if len(r["said"]) > 2)),
        ("every job came to its answer", all("is done" in r["said"][-1] for r in jobs)),
        (f"one undo took it back to {undo.get('before')} parts: {undo.get('parts')}",
         bool(undo) and undo.get("parts") == undo.get("before")),
    ]
    for words, held in checks:
        print(f"{'ok  ' if held else 'FAIL'} {words}")
    failed = sum(1 for _, held in checks if not held)
    print(f"busy_tab: {'all held' if not failed else f'{failed} failed'}; {out / 'busy_tab.json'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
