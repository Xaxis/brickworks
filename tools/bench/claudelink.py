#!/usr/bin/env python3
"""Change it with your Claude, measured as the person does it (claudelink).

    python3 tools/bench/claudelink.py --out=DIR [--models=ID,ID,ID] [--asks=recolour,add,stand]
        [--ports=11380-11389] [--jobs=3] [--timeout=1800] [--app=CHECKOUT]

A model's page has, beside Open in Brickworks, With your Claude: an ask typed, and
Copy for Claude copies a message naming the model's link and the one call that
opens a copy of it (open_model link=). This gives a Claude Code session on the
subscription that message and nothing else, through the connector relay as the
owner's path is (tools/bench/realset.py --via relay --instructions none): this
checkout's relay (tools/web/relay_server.mjs) with the server's instructions
withheld, a throwaway account of the checks' pool opened for each session and
deleted after (tools/web/relay_account.mjs), and the app headless as that
account's tab (src/dev/claudelink_tab.gd). The message is the page's own,
copied in a browser from the relay's /m/<id> (tools/web/claude_copy.mjs).

No tool publishes: only the person shares. So once the session ends, the tab
does what the person's File › Share…, Publish does, unlisted. Then, for each of
the three models and three asks (a recolour, a part added to the build, a stand
with a nameplate), nine sessions:

  - published, and remixed_from is the original, with its version
    (/api/share?id=<remix>);
  - the remix's page credits it: "Remixed from <a href="/m/<original>">";
  - changed as asked, from the two files' parts (each a part and colour):
    recolour, dark blue (272) up by half the main colour's count or more and
    the part count within a tenth; add, two parts or more added and nine
    tenths of the original kept; stand, three or more added, nine tenths kept
    and a tile among them (its LDraw name);
  - 12 calls or fewer, none to a tool there is not and no part number the
    library lacks (from the session's own stream).

Everything lands in DIR: per session <model>-<ask>/ with the message, the
stream (session.jsonl), the tab's log, the published answer, the remix's JSON,
page and picture, and result.json; summary.json and SUMMARY.txt for the lot.
Exit 0 when all nine hold. Run it under ~/.claude/claude-core/bin/heavy: it
starts a browser, three tabs at a time, and their drawers on the GPU's lease.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

from bench import realset  # noqa: E402
from bench import run as bench  # noqa: E402

ASKS = {
    "recolour": "Make its main colour dark blue, and keep everything else as it is.",
    "add": "Add a flag on a pole at its highest point.",
    "stand": "Put it on a display stand, with a nameplate tile on the front of the stand.",
}
MOST_CALLS = 12
DARK_BLUE = "272"
# The relay's own tools, beside the app's (api/mcp.js).
RELAY_TOOLS = {"tabs", "select_tab", "job"}
LIBRARY = [ROOT / "vendor" / "ldraw" / "parts", ROOT / "vendor" / "ldraw" / "unofficial" / "parts"]


def _get(url: str, timeout: int = 60) -> tuple[int, bytes]:
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"accept": "*/*"}),
                                    timeout=timeout) as got:
            return got.status, got.read()
    except urllib.error.HTTPError as trouble:
        return trouble.code, trouble.read()
    except OSError:
        return 0, b""


def _json(url: str) -> dict:
    code, body = _get(url)
    try:
        return json.loads(body) if code == 200 else {}
    except ValueError:
        return {}


def pick_models(origin: str, wanted: str) -> list[dict]:
    """The models: those named, or the gallery's top three small ones of 20 to 500 parts."""
    if wanted:
        return [_json(f"{origin}/api/share?id={one}") | {"id": one} for one in wanted.split(",")]
    for size in ("small", "medium"):
        listed = _json(f"{origin}/api/share?op=list&sort=top&size={size}&page=1").get("models") or []
        chosen = [one for one in listed if isinstance(one, dict) and 20 <= int(one.get("parts") or 0) <= 500]
        if len(chosen) >= 3:
            return chosen[:3]
    raise SystemExit("claudelink: the gallery has no three models of 20 to 500 parts")


def parts_of(text: str) -> Counter:
    """A model file's parts, each (part, colour), over all its files."""
    held: Counter = Counter()
    for line in text.splitlines():
        bits = line.split()
        if len(bits) >= 15 and bits[0] == "1" and bits[14].lower().endswith(".dat"):
            held[(bits[14].lower().removesuffix(".dat"), bits[1])] += 1
    return held


def _library_name(part: str) -> str:
    for folder in LIBRARY:
        file = folder / f"{part.lower().removesuffix('.dat')}.dat"
        if file.exists():
            return file.read_text(errors="replace").split("\n", 1)[0].removeprefix("0").strip()
    return ""


def changed_as_asked(ask: str, before: Counter, after: Counter) -> tuple[bool, str]:
    total_before, total_after = sum(before.values()), sum(after.values())
    kept = sum((before & after).values()) / max(total_before, 1)
    added = after - before
    if ask == "recolour":
        colours = Counter()
        for (_, colour), n in before.items():
            colours[colour] += n
        main, main_n = colours.most_common(1)[0] if colours else ("?", 0)
        blue_before = sum(n for (_, c), n in before.items() if c == DARK_BLUE)
        blue_after = sum(n for (_, c), n in after.items() if c == DARK_BLUE)
        ok = blue_after - blue_before >= max(1, main_n // 2) and abs(total_after - total_before) <= total_before / 10
        return ok, (f"main colour {main} x{main_n}; dark blue {blue_before} to {blue_after}; "
                    f"parts {total_before} to {total_after}")
    names = sorted({_library_name(part) for (part, _) in added})
    if ask == "add":
        ok = sum(added.values()) >= 2 and kept >= 0.9
    else:
        ok = sum(added.values()) >= 3 and kept >= 0.9 and any(name.startswith("Tile") for name in names)
    return ok, (f"{sum(added.values())} added ({', '.join(names[:8])}), {kept:.0%} of the original kept, "
                f"parts {total_before} to {total_after}")


def calls_of(stream: Path) -> list[dict]:
    """Every tool call of a session, in order, with its answer's first words."""
    calls: list[dict] = []
    answers: dict[str, str] = {}
    for line in stream.read_text(errors="replace").splitlines() if stream.exists() else []:
        try:
            content = (json.loads(line).get("message") or {}).get("content")
        except (ValueError, AttributeError):
            continue
        for block in content if isinstance(content, list) else []:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "tool_use":
                calls.append({"id": block.get("id"), "name": str(block.get("name", "")).rsplit("__", 1)[-1],
                              "input": block.get("input") or {}})
            elif block.get("type") == "tool_result":
                said = block.get("content")
                answers[block.get("tool_use_id")] = (" ".join(b.get("text", "") for b in said if isinstance(b, dict))
                                                     if isinstance(said, list) else str(said))
    for call in calls:
        call["answer"] = answers.get(call.pop("id"), "")[:300]
    return calls


def _parts_named(value) -> list[str]:
    if isinstance(value, dict):
        return [str(v) for k, v in value.items() if k == "part" and isinstance(v, str)] \
            + [p for k, v in value.items() if k != "part" for p in _parts_named(v)]
    if isinstance(value, list):
        return [p for v in value for p in _parts_named(v)]
    return []


def misnamed(calls: list[dict]) -> tuple[list[str], list[str]]:
    """The tools called that there are not, and the part numbers named that the library lacks."""
    tools = {t["name"] for t in json.loads((ROOT / "tools" / "mcp_tools.json").read_text())} | RELAY_TOOLS
    no_tool = [c["name"] for c in calls if c["name"] not in tools or realset.NO_SUCH_TOOL in c["answer"]]
    no_part = sorted({p for c in calls if c["name"] != "search_parts" for p in _parts_named(c["input"])
                      if not _library_name(p)})
    return no_tool, no_part


def one_session(model: dict, ask: str, ports: tuple[int, int], origin: str, out: Path, app: Path,
                timeout: int) -> dict:
    """One model changed as asked, by a session given only the page's message."""
    _, app_port = ports
    link = str(model["id"])
    run = out / f"{link}-{ask}"
    run.mkdir(parents=True, exist_ok=True)
    done = run / "result.json"
    if done.exists():
        return json.loads(done.read_text())
    result: dict = {"model": link, "name": model.get("name"), "ask": ask, "words": ASKS[ask]}
    # The message, as the page copies it.
    copied = subprocess.run(["node", str(ROOT / "tools" / "web" / "claude_copy.mjs"), f"--origin={origin}",
                             f"--id={link}", f"--ask={ASKS[ask]}", f"--shot={run / 'panel.png'}"],
                            cwd=ROOT, capture_output=True, text=True, timeout=600)
    try:
        message = json.loads(copied.stdout.strip().splitlines()[-1])["message"]
    except (ValueError, IndexError, KeyError):
        result["trouble"] = f"no message copied: {copied.stderr[-300:]}"
        done.write_text(json.dumps(result, indent=1))
        return result
    (run / "message.txt").write_text(message)
    tab_home = run / "home"
    user_dir = tab_home / "godot" / "app_userdata" / "Brickworks"
    account: dict = {}
    tab = None
    try:
        opened = realset._node(str(realset.RELAY_ACCOUNT), "open", f"--origin={origin}")
        if opened.returncode != 0:
            raise SystemExit(f"no throwaway account: {opened.stderr[-300:]}")
        account = json.loads(opened.stdout.strip().splitlines()[-1])
        user_dir.mkdir(parents=True, exist_ok=True)
        (user_dir / "session.json").write_text(json.dumps(account["kept"]))
        now, published = run / "publish.now", run / "published.json"
        for stale in (now, published):
            stale.unlink(missing_ok=True)
        with (run / "tab.log").open("w") as log:
            tab = subprocess.Popen(
                ["godot", "--headless", "--path", str(app), "--log-file", str(run / "godot.log"),
                 "--script", "src/dev/claudelink_tab.gd", "--", f"--mcp={app_port}", "--assistant=on",
                 "--signed-in", "--draw-by=" + json.dumps(bench.DRAWER),
                 f"--publish-when={now}", f"--published={published}"],
                cwd=app, stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
                env=bench._billing_free_env(XDG_DATA_HOME=str(tab_home), BRICKWORKS_API=origin,
                                            MESA_VK_WSI_DEBUG="sw"))
        if not realset._until(lambda: tab.poll() is None and realset._tab_open(origin, account["token"]),
                              realset.TAB_WAIT_S, 3.0):
            raise SystemExit("the tab never switched its connector on")
        config = run / "relay-mcp.json"
        config.write_text(json.dumps({"mcpServers": {"brickworks": {
            "type": "http", "url": f"{origin}/api/mcp", "timeout": realset.TOOL_TIMEOUT_MS,
            "headers": {"Authorization": f"Bearer {account['token']}"}}}}))
        env = {k: v for k, v in bench._billing_free_env().items() if not realset.SECRETS.search(k)}
        env.update(MCP_TOOL_TIMEOUT=str(realset.TOOL_TIMEOUT_MS), MCP_TIMEOUT="120000")
        stream = run / "session.jsonl"
        started = time.time()
        with stream.open("w") as said:
            status = subprocess.run(
                ["timeout", "--kill-after=30", str(timeout), "claude", "-p", message,
                 "--mcp-config", str(config), "--strict-mcp-config", "--tools", "",
                 "--restricted", "--allowedTools", "mcp__brickworks",
                 "--output-format", "stream-json", "--verbose"],
                cwd=app, env=env, stdout=said, stderr=subprocess.STDOUT).returncode
        ended = realset._session_end(stream)
        result.update(status=status, seconds=round(time.time() - started, 1),
                      finished=str(ended.get("result", ""))[:400], turns=ended.get("num_turns"))
        # The person's Publish, now the session has ended.
        now.write_text("publish")
        realset._until(lambda: published.exists() or tab.poll() is not None, 900, 2.0)
        shared = json.loads(published.read_text()) if published.exists() else {}
        result["published"] = shared
        remix = str(shared.get("id", ""))
        if remix:
            row = _json(f"{origin}/api/share?id={remix}&tests=1")
            (run / "remix.json").write_text(json.dumps({k: v for k, v in row.items() if k != "model"}, indent=1))
            frm = row.get("remixed_from") or {}
            result["remixed_from"] = frm.get("id") if isinstance(frm, dict) else frm
            result["remixed_from_version"] = frm.get("version") if isinstance(frm, dict) else None
            code, page = _get(f"{origin}/m/{remix}?tests=1")
            (run / "remix.html").write_bytes(page)
            result["page_credits"] = code == 200 and f'Remixed from <a href="/m/{link}">' in page.decode(errors="replace")
            code, picture = _get(f"{origin}/m/{remix}.png")
            if code == 200 and picture:
                (run / "remix.png").write_bytes(picture)
            before = parts_of(_get(f"{origin}/m/{link}.mpd")[1].decode(errors="replace"))
            after = parts_of(str(row.get("model") or _get(f"{origin}/m/{remix}.mpd")[1].decode(errors="replace")))
            result["changed"], result["change"] = changed_as_asked(ask, before, after)
    except SystemExit as trouble:
        result["trouble"] = str(trouble)
    finally:
        realset._stop(tab)
        if account.get("user"):
            closed = realset._node(str(realset.RELAY_ACCOUNT), "close", f"--user={account['user']}")
            result["account_deleted"] = closed.returncode == 0
    calls = calls_of(run / "session.jsonl")
    no_tool, no_part = misnamed(calls)
    result.update(calls=len(calls), called=[c["name"] for c in calls], no_such_tool=no_tool, no_such_part=no_part)
    (run / "calls.json").write_text(json.dumps(calls, indent=1))
    result["ok"] = bool(result.get("remixed_from") == link and result.get("page_credits") and result.get("changed")
                        and result["calls"] <= MOST_CALLS and not no_tool and not no_part)
    done.write_text(json.dumps(result, indent=1))
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--models", default="", help="three link ids; the gallery's top small ones when omitted")
    parser.add_argument("--asks", default=",".join(ASKS))
    parser.add_argument("--ports", default="11380-11389", help="the relay's, then one a tab")
    parser.add_argument("--jobs", type=int, default=3)
    parser.add_argument("--timeout", type=int, default=1800, help="a session's seconds at most")
    parser.add_argument("--app", type=Path, default=ROOT)
    args = parser.parse_args()
    low, high = (int(p) for p in args.ports.split("-"))
    if high - low < args.jobs:
        raise SystemExit("claudelink: --ports needs the relay's and one a job")
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    origin = f"http://127.0.0.1:{low}"
    relay_log = out / "relay.log"
    with relay_log.open("w") as log:
        relay = subprocess.Popen(["node", f"--env-file={ROOT / '.env'}", str(realset.RELAY_SERVER), str(low),
                                  "--instructions=none"], cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                                 start_new_session=True)
    try:
        if not realset._until(lambda: "functions on" in relay_log.read_text(errors="replace"), 60, 0.5):
            raise SystemExit(f"claudelink: the relay never listened; see {relay_log}")
        models = pick_models(origin, args.models)
        (out / "models.json").write_text(json.dumps([{k: m.get(k) for k in ("id", "name", "parts", "author")}
                                                     for m in models], indent=1))
        work = [(model, ask) for model in models for ask in args.asks.split(",")]
        free = list(range(low + 1, high + 1))
        lock = __import__("threading").Lock()

        def go(job: tuple[dict, str]) -> dict:
            with lock:
                port = free.pop(0)
            try:
                bench.say(f"{job[0]['id']} {job[1]} on {port}")
                return one_session(job[0], job[1], (low, port), origin, out, args.app.resolve(), args.timeout)
            finally:
                with lock:
                    free.append(port)

        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            results = list(pool.map(go, work))
    finally:
        realset._stop(relay)
    lines = [f"{'ok  ' if r.get('ok') else 'FAIL'}  {r['model']} {r['ask']}: {r.get('calls')} calls "
             f"({' '.join(r.get('called', []))}); remixed_from {r.get('remixed_from')} v{r.get('remixed_from_version')}, "
             f"page credits {r.get('page_credits')}; {r.get('change', r.get('trouble', ''))}"
             + (f"; no such tool {r['no_such_tool']}" if r.get("no_such_tool") else "")
             + (f"; no such part {r['no_such_part']}" if r.get("no_such_part") else "")
             for r in results]
    held = sum(bool(r.get("ok")) for r in results)
    lines.append(f"{held} of {len(results)} held")
    (out / "SUMMARY.txt").write_text("\n".join(lines) + "\n")
    (out / "summary.json").write_text(json.dumps(results, indent=1))
    print("\n".join(lines))
    return 0 if held == len(results) else 1


if __name__ == "__main__":
    sys.exit(main())
