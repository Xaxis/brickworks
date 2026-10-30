#!/usr/bin/env python3
"""The gallery's weekly AI showcase: made on this box, never public by itself (gallery362).

    tools/showcase.py run [--brief ID] [--timeout S] [--dry-run]
    tools/showcase.py drafts
    tools/showcase.py publish RUN

A systemd user timer runs `run` once a week (tools/systemd/brickworks-showcase.*,
installed by tools/install_showcase_timer.sh, which leaves it off: the lead
turns it on after looking at a first run by hand). One run:

1. **Skips when the box is busy**, and says so in the log: when anything
   waits in `heavy`'s queue or more threads want a CPU than its gate. A run
   that waited a night for a slot would hold one through the next morning.
2. **Skips when Claude will not answer**: one short question first, on the
   owner's subscription as every design is (no API key). "hit your 5-hour
   limit", a usage limit or "OAuth session expired" ends the run with a line
   in the log. Never a retry, and never a loop: next week's run asks again.
3. Takes the next brief of tools/showcase_briefs.json not yet made
   (owner-style ideas, not the bench's subjects).
4. Designs it as the bench does on the owner's path, in a `heavy` slot:
   Claude through the connector relay to the app as a throwaway account's tab,
   with no Claude Code in the tab (tools/bench/realset.py design_via_relay).
5. Renders it in the Product look (render_model look=product, File › Render's),
   on the GPU, the app signed in as the showcase account; and saves it to
   that account's saved models there (api/models.js): a draft, which no page
   shows.
6. Writes it down: bench/results/showcase/<date>-<brief>/ holds design.ldr,
   render.png, the session and draft.json; showcase.log a line for every run,
   made or skipped.

`publish RUN` is the one command that puts a draft in the gallery: shared by
the showcase account, listed, made with the assistant, its render as its
picture. A person runs it after looking at the render; nothing AI-made goes
public otherwise.

The showcase account is BRICKWORKS_SHOWCASE_EMAIL (showcase@brickworks.diy
unless set), signed in from .env's secret key as the probes are
(tools/web/session.mjs), never an address of a test's: a test account's
models are kept out of the gallery.
"""

from __future__ import annotations

import argparse
import base64
import datetime
import io
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

BRIEFS = ROOT / "tools" / "showcase_briefs.json"
CORE = Path.home() / ".claude" / "claude-core" / "bin"
HEAVY = str(CORE / "heavy")
EMAIL = os.environ.get("BRICKWORKS_SHOWCASE_EMAIL", "showcase@brickworks.diy")
AUTHOR = "Brickworks"
SITE = os.environ.get("BRICKWORKS_SITE", "https://brickworks.diy")
# What Claude Code says when the owner's subscription will not answer now.
LIMITS = re.compile(r"hit your [\w -]*limit|5-hour limit|usage limit|limit reached|"
                    r"oauth session (has )?expired|oauth token has expired|please run /login|"
                    r"invalid api key|credit balance is too low", re.I)
# The whole run in its slot: a design is up to 40 minutes, and the render.
DESIGN_TIMEOUT = 2400
RUN_TIMEOUT = 4200


def results() -> Path:
    """The main checkout's bench/results/showcase/, as every bench run's."""
    from bench import run as bench
    return bench.RESULTS / "showcase"


def log(line: str, out: Path | None = None) -> None:
    """A line in showcase.log, and on the screen."""
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    print(f"[{stamp}] {line}", flush=True)
    where = out or results()
    where.mkdir(parents=True, exist_ok=True)
    with (where / "showcase.log").open("a") as said:
        said.write(f"{stamp} {line}\n")


# -- the gates ----------------------------------------------------------------

def heavy_busy(status: str) -> str:
    """Why `heavy --status` says the box is too busy for a showcase now, or ""."""
    first = status.splitlines()[0] if status.strip() else ""
    wanting = re.search(r"(\d+) threads want a CPU \(gate (\d+)\)", first)
    if not wanting:
        return f"heavy said nothing it could be read by: {first[:120]!r}"
    if int(wanting[1]) >= int(wanting[2]):
        return f"{wanting[1]} threads want a CPU, at or over heavy's gate of {wanting[2]}"
    waiting = [line for line in status.splitlines()[1:] if line.strip().startswith("wait")]
    if waiting:
        return f"{len(waiting)} job(s) wait in heavy's queue"
    return ""


def claude_says(text: str) -> str:
    """Why an answer from Claude Code says the owner's limits stop a run, or ""."""
    found = LIMITS.search(text or "")
    return found[0] if found else ""


def ask_claude(timeout: int = 180) -> str:
    """One short question to Claude Code on the owner's subscription: its answer's words."""
    env = {k: v for k, v in os.environ.items() if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
    try:
        done = subprocess.run(["claude", "-p", "Reply with the one word: ready", "--output-format", "json",
                               "--tools", ""], capture_output=True, text=True, timeout=timeout, env=env,
                              cwd=str(results().parent))
    except (OSError, subprocess.TimeoutExpired) as trouble:
        return f"claude did not answer: {trouble}"
    return f"{done.stdout}\n{done.stderr}"


# -- the briefs ---------------------------------------------------------------

def briefs() -> list[dict]:
    said = json.loads(BRIEFS.read_text())["briefs"]
    ids = [one["id"] for one in said]
    assert len(ids) == len(set(ids)), "a brief's id twice"
    return said


def made(out: Path) -> dict[str, str]:
    """When each brief was last made: {id: date}, from the drafts written."""
    last: dict[str, str] = {}
    for draft in sorted(out.glob("*/draft.json")):
        record = json.loads(draft.read_text())
        if record.get("brief") and record.get("model"):
            last[record["brief"]] = max(last.get(record["brief"], ""), record.get("date", ""))
    return last


def next_brief(every: list[dict], last: dict[str, str]) -> dict:
    """The first brief never made, or else the one made longest ago."""
    return min(every, key=lambda one: (last.get(one["id"], ""), every.index(one)))


# -- the showcase account -----------------------------------------------------

def session(email: str = EMAIL) -> dict:
    """The showcase account signed in, as tools/web/session.mjs signs in a probe:
    the session the app keeps ({access_token, refresh_token, user, ...})."""
    script = ("import { mintSession } from './tools/web/session.mjs';"
              f"const s = await mintSession({json.dumps(email)});"
              "console.log(JSON.stringify(s));")
    done = subprocess.run(["node", f"--env-file={ROOT / '.env'}", "--input-type=module", "-e", script],
                          cwd=ROOT, capture_output=True, text=True, timeout=120)
    if done.returncode != 0:
        raise SystemExit(f"the showcase account would not sign in: {done.stderr[-300:]}")
    return json.loads(done.stdout.strip().splitlines()[-1])


def _ask_app(port: int, tool: str, arguments: dict, timeout: int = 600) -> dict:
    with socket.create_connection(("127.0.0.1", port), timeout=timeout) as sock:
        sock.sendall(json.dumps({"id": 1, "tool": tool, "input": arguments}).encode() + b"\n")
        got = b""
        while b"\n" not in got:
            chunk = sock.recv(1 << 16)
            if not chunk:
                break
            got += chunk
    return json.loads(got.split(b"\n", 1)[0] or b"{}")


def words(answer: dict) -> str:
    content = answer.get("content")
    if isinstance(content, list):
        return " ".join(str(block.get("text", "")) for block in content if isinstance(block, dict))
    return str(content or answer.get("error") or "")


def render(model: Path, name: str, out: Path, port: int, timeout: int = 900) -> dict:
    """[model] opened in the app signed in as the showcase account, saved there as
    [name] (its draft: the account's saved models, which no page shows) and
    rendered in the Product look: {render, saved, seconds}."""
    from bench import run as bench
    home = out / "app-home"
    user_dir = home / "godot" / "app_userdata" / "Brickworks"
    (user_dir / "models").mkdir(parents=True, exist_ok=True)
    (user_dir / "session.json").write_text(json.dumps(session()))
    shutil.copy(model, user_dir / "models" / f"{name}.ldr")
    started = time.time()
    env = bench._billing_free_env(XDG_DATA_HOME=str(home), MESA_VK_WSI_DEBUG="sw")
    with (out / "render.log").open("w") as said:
        app = subprocess.Popen([*bench.DRAWER, "--path", str(ROOT), "--", f"--mcp={port}", "--signed-in"],
                               cwd=ROOT, stdout=said, stderr=subprocess.STDOUT, env=env, start_new_session=True)
    result: dict = {}
    try:
        end = time.time() + 300
        while time.time() < end:
            try:
                _ask_app(port, "__ping__", {}, timeout=10)
                break
            except OSError:
                time.sleep(3)
        opened = words(_ask_app(port, "open_model", {"name": name, "discard_changes": True}))
        saved = words(_ask_app(port, "save_model", {"name": f"{name}.ldr"}))
        drawn = _ask_app(port, "render_model", {"look": "product", "backdrop": "gradient", "quality": "good",
                                                "size": "1080p", "view": "hero"}, timeout=timeout)
        said = words(drawn)
        job = re.search(r'"?job"?\s*[:=]\s*"?([A-Za-z0-9_-]+)', said)
        while job and not re.search(r"\.png\b", said) and time.time() < started + timeout:
            time.sleep(5)
            said = words(_ask_app(port, "job", {"id": job[1]}))
        found = re.search(r"(/[^\s\"']+\.png)", said)
        if found and Path(found[1]).is_file():
            shutil.copy(found[1], out / "render.png")
        result = {"render": (out / "render.png").is_file(), "opened": opened[:200], "saved": saved[:200],
                  "said": said[:300], "seconds": round(time.time() - started, 1)}
    finally:
        for sig in (15, 9):
            try:
                os.killpg(app.pid, sig)
                app.wait(20)
                break
            except (ProcessLookupError, subprocess.TimeoutExpired):
                continue
        shutil.rmtree(home, ignore_errors=True)
    return result


# -- the run ------------------------------------------------------------------

def run(args: argparse.Namespace) -> int:
    out = results()
    if not os.environ.get("BOX_HEAVY_HELD"):
        # The gates first, outside the queue: a busy box or a spent limit is a
        # line in the log, never a night's wait.
        status = subprocess.run([HEAVY, "--status"], capture_output=True, text=True, timeout=60).stdout
        busy = heavy_busy(status)
        if busy:
            log(f"skipped: the box is busy ({busy})", out)
            return 0
        stopped = claude_says(ask_claude())
        if stopped:
            log(f"skipped: Claude will not answer now ({stopped}); not retried", out)
            return 0
        if args.dry_run:
            choice = next_brief(briefs(), made(out))
            log(f"dry run: would design {choice['id']} ({choice['title']})", out)
            return 0
        os.environ["BRICKWORKS_SHOWCASE_GATED"] = "1"
        argv = [sys.executable, str(Path(__file__).resolve()), "run", "--timeout", str(args.timeout)]
        if args.brief:
            argv += ["--brief", args.brief]
        os.execv(HEAVY, [HEAVY, "timeout", str(RUN_TIMEOUT), *argv])
    return design_and_draft(args, out)


def design_and_draft(args: argparse.Namespace, out: Path) -> int:
    from bench import realset, suite
    every = briefs()
    choice = next((one for one in every if one["id"] == args.brief), None) if args.brief \
        else next_brief(every, made(out))
    if choice is None:
        raise SystemExit(f"no brief {args.brief!r} in {BRIEFS}")
    date = datetime.date.today().isoformat()
    run_dir = out / f"{date}-{choice['id']}"
    run_dir.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("XDG_DATA_HOME", str(run_dir / "data"))
    started = time.time()
    subject = suite.Subject(f"showcase-{choice['id']}", choice["title"], choice["brief"], "", "other")
    designed = realset.design_via_relay(subject, run_dir, args.timeout, ROOT, claude_code=False)
    design_seconds = round(time.time() - started, 1)
    stopped = claude_says(designed.get("finished", "")) or claude_says(
        (run_dir / "session.jsonl").read_text(errors="replace")[-4000:] if (run_dir / "session.jsonl").exists() else "")
    record = {"brief": choice["id"], "title": choice["title"], "words": choice["brief"], "date": date,
              "state": "draft", "design": designed, "design_seconds": design_seconds,
              "model": (run_dir / "design.ldr").is_file()}
    if stopped:
        record["skipped"] = f"Claude stopped: {stopped}"
        (run_dir / "draft.json").write_text(json.dumps(record, indent=1))
        log(f"skipped: the design ended on Claude's limits ({stopped}); not retried", out)
        return 0
    if not record["model"]:
        (run_dir / "draft.json").write_text(json.dumps(record, indent=1))
        log(f"made nothing: {choice['id']} ended with no model in {design_seconds / 60:.1f} min", out)
        return 1
    from bench import run as bench
    port = bench._free_port()
    try:
        # The app on the GPU's lease for this one render (bench.DRAWER takes it).
        record["render"] = render(run_dir / "design.ldr", f"showcase-{choice['id']}", run_dir, port)
    finally:
        bench._port_back(port)
    record["seconds"] = round(time.time() - started, 1)
    (run_dir / "draft.json").write_text(json.dumps(record, indent=1))
    log(f"draft: {choice['id']} in {record['seconds'] / 60:.1f} min (design {design_seconds / 60:.1f}), "
        f"render {'drawn' if (run_dir / 'render.png').is_file() else 'NOT drawn'}: {run_dir}", out)
    return 0 if (run_dir / "render.png").is_file() else 1


# -- the drafts, and letting one out --------------------------------------------

def drafts(_: argparse.Namespace) -> int:
    for draft in sorted(results().glob("*/draft.json")):
        record = json.loads(draft.read_text())
        print(f"{draft.parent.name}: {record.get('state')} {record.get('title')!r} model={record.get('model')} "
              f"render={(draft.parent / 'render.png').is_file()} {record.get('link', '')}")
    return 0


def pictures(render_png: Path) -> tuple[str, str]:
    """The render as the share takes it: a PNG under 600 KB, and a WebP card under 64 KB."""
    from PIL import Image
    picture = Image.open(render_png).convert("RGB")
    big = picture.copy()
    big.thumbnail((1200, 900))
    for colours in (None, 256, 128):
        kept = io.BytesIO()
        (big if colours is None else big.quantize(colours)).save(kept, "PNG", optimize=True)
        if kept.tell() <= 600 * 1024:
            break
    small = picture.copy()
    small.thumbnail((480, 360))
    for quality in (80, 65, 50):
        card = io.BytesIO()
        small.save(card, "WEBP", quality=quality)
        if card.tell() <= 64 * 1024:
            break
    return base64.b64encode(kept.getvalue()).decode(), base64.b64encode(card.getvalue()).decode()


def publish(args: argparse.Namespace) -> int:
    run_dir = results() / args.run
    record = json.loads((run_dir / "draft.json").read_text())
    if record.get("state") == "published":
        print(f"already published: {record.get('link')}")
        return 0
    if not record.get("model") or not (run_dir / "render.png").is_file():
        raise SystemExit(f"{args.run} has no model or no render to publish")
    image, thumb = pictures(run_dir / "render.png")
    signed = session()
    body = {"name": record["title"][:80], "author": AUTHOR, "model": (run_dir / "design.ldr").read_text(),
            "image": image, "thumb": thumb, "listed": True, "made_with": "assistant",
            "description": f"Designed by the Brickworks assistant from the brief: {record['words']}"[:1000],
            "kind": None}
    body = {k: v for k, v in body.items() if v is not None}
    asked = urllib.request.Request(f"{SITE}/api/share", data=json.dumps(body).encode(), method="POST", headers={
        "content-type": "application/json", "authorization": f"Bearer {signed['access_token']}"})
    with urllib.request.urlopen(asked, timeout=120) as answer:
        said = json.loads(answer.read().decode())
    record.update(state="published", link=said.get("url") or said.get("id"),
                  published_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    (run_dir / "draft.json").write_text(json.dumps(record, indent=1))
    log(f"published: {args.run} as {record['link']}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="what", required=True)
    one = sub.add_parser("run")
    one.add_argument("--brief", default="")
    one.add_argument("--timeout", type=int, default=DESIGN_TIMEOUT)
    one.add_argument("--dry-run", action="store_true", help="the gates and the brief, nothing designed")
    sub.add_parser("drafts")
    out = sub.add_parser("publish")
    out.add_argument("run", help="a draft's folder under bench/results/showcase/")
    args = parser.parse_args(argv)
    return {"run": run, "drafts": drafts, "publish": publish}[args.what](args)


if __name__ == "__main__":
    sys.exit(main())
