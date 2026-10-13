#!/usr/bin/env python3
"""Run the design bench: each subject designed, pictured, checked, measured and judged.

    python3 tools/bench/run.py list
    python3 tools/bench/run.py anchors
    python3 tools/bench/run.py run [--subjects a,b] [--run N] [--date D] [--timeout S]
    python3 tools/bench/run.py run --dry-run [--subjects a]
    python3 tools/bench/run.py summary [--date D] [--append docs/DESIGN_SCORES.md]

A run is, per subject and one at a time:

  design   the real loop on the subscription: the app off-screen (Xvfb, in
           software, under `heavy`) with --ask-claude-code, the brief as
           the person would type it, Claude Code driving it over MCP on its
           own port. ANTHROPIC_API_KEY is taken out of its environment, so
           nothing is billed. Its saves are moved out of the app's user
           folder into the run's, and its connection file with them.
  views    corner, front and close, by src/dev/bench_views.gd on the GPU
           (`gpu`), the assistant's own camera.
  probe    src/dev/candidate_probe.gd: opens whole, one piece, stands, faults.
  style    tools/style.py --json against the subject's group of real sets.
  refs     the subject's photographs fetched from Commons and its real sets
           rendered, once per batch, into the subject's refs/.
  judge    Claude Code on the subscription, with only the Read tool, shown
           the two anchors, the references, the views and the probe, and a
           fixed rubric; its JSON reply read into six scores.

Everything lands in bench/results/<date>/<subject>/<run>/ (gitignored),
and each stage is skipped when its output is there, so a batch that was
stopped is resumed by running the same command with the same --date.
--dry-run puts a canned design and a canned judge's reply in place of
the two calls and fetches nothing: the stages between run for real.
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import json
import os
import re
import shutil
import socket
import subprocess
import sys
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import running  # noqa: E402
from bench import judge, scores, suite  # noqa: E402

HERE = Path(__file__).resolve().parent
RESULTS = ROOT / "bench" / "results"
CORE = Path.home() / ".claude" / "claude-core" / "bin"
HEAVY, GPU = str(CORE / "heavy"), str(CORE / "gpu")
# Where Godot keeps the app's user folder: under XDG_DATA_HOME when it is set,
# as every agent's run sets it, so a batch's saves never land beside the
# owner's models and the tidy never reads theirs.
USER_DIR = (Path(os.environ["XDG_DATA_HOME"]) if os.environ.get("XDG_DATA_HOME")
            else Path.home() / ".local" / "share") / "godot" / "app_userdata" / "Brickworks"
OMR_FILES = ROOT / "vendor" / "omr" / "files"
OMR_INDEX = ROOT / "vendor" / "omr" / "index.json"
OMR_SITE = "https://library.ldraw.org"
AGENT = {"User-Agent": "brickworks-bench/1.0 (https://brickworks.diy)"}
CANNED = ROOT / "tests" / "fixtures" / "bench"
VIEWS = ("corner", "front", "close")
SCREEN = "-screen 0 1600x900x24"


def say(text: str) -> None:
    print(f"[{datetime.datetime.now():%H:%M:%S}] {text}", flush=True)


def _billing_free_env(**extra: str) -> dict[str, str]:
    env = {k: v for k, v in os.environ.items()
           if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
    env.update(extra)
    return env


def commit() -> str:
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=ROOT,
                         capture_output=True, text=True).stdout.strip() or "?"
    dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no", "src"],
                           cwd=ROOT, capture_output=True, text=True).stdout.strip()
    return sha + ("-dirty" if dirty else "")


def _free_port() -> int:
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _write_json(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=1) + "\n")


# -- design ---------------------------------------------------------------


def _tidy_user_dir(since: float, log: str, port: int, keep: Path) -> list[str]:
    """Move what this run left in the app's user folder into the run's own.

    Only what is certainly this run's: its connection file (named for its
    port), and saves newer than its start that its log names or that were
    written as one of its "saving" steps ran. Other agents run designs here
    at the same time, and a session names only its last save in words: the
    owl's first save, barn_owl_on_branch.ldr, was left behind by the name
    rule alone.
    """
    moved: list[str] = []
    config = USER_DIR / f"claude-code-mcp-{port}.json"
    candidates = [config]
    # The session's clock starts as its connection file is written; a
    # second pass over a recorded run finds the file already kept.
    clock = config if config.exists() else keep / config.name
    started = clock.stat().st_mtime if clock.exists() else None
    if started is not None:
        since = max(since, started - 1.0)     # nothing older than the session is its
    steps =[started + t for t in scores.save_times(log)] if started is not None else []
    models = USER_DIR / "models"
    if models.is_dir():
        for f in models.iterdir():
            if not f.is_file() or f.stat().st_mtime < since:
                continue
            written = f.stat().st_mtime
            if f.name in log or any(-1.0 <= written - at <= 5.0 for at in steps):
                candidates.append(f)
    failed = USER_DIR / "failed_design.json"
    if failed.exists() and failed.stat().st_mtime >= since and "failed_design" in log:
        candidates.append(failed)
    for path in candidates:
        if path.exists():
            keep.mkdir(parents=True, exist_ok=True)
            shutil.move(str(path), keep / path.name)
            moved.append(path.name)
    return moved


def _stop_leftovers(port: int) -> list[int]:
    """A Claude Code session of this run that outlived its app (a timeout) is stopped.

    Found by its connection file, which is named for this run's port, with
    tools/running.py: pgrep -f matches whatever shell is waiting on the run.
    """
    ended, _spared = running.stop(f"claude-code-mcp-{port}.json")
    return [pid for pid, _args in ended]


def design(subject: suite.Subject, run_dir: Path, timeout: int, canned: Path | None) -> dict:
    done = run_dir / "design.json"
    if done.exists():
        result = json.loads(done.read_text())
        if result.get("port") and (run_dir / "design.log").exists():
            # Anything of this run's still in the user folder (a run
            # recorded by an older runner, or stopped before it tidied).
            late = _tidy_user_dir(time.time() - 7 * 86400, (run_dir / "design.log").read_text(
                errors="replace"), int(result["port"]), run_dir / "saves")
            if late:
                result["moved"] = result.get("moved", []) + late
                _write_json(done, result)
        return result
    ldr = run_dir / "design.ldr"
    if canned is not None:
        shutil.copy(canned, ldr)
        result = {"status": 0, "commit": commit(), "canned": str(canned), "seconds": 0.0,
                  "timed_out": False, "model": True}
        _write_json(done, result)
        return result
    port = _free_port()
    sha = commit()      # the code the design runs on, not the code that judges it
    log = run_dir / "design.log"
    since = time.time() - 1.0
    say(f"design {subject.id}: port {port}, up to {timeout // 60} min")
    # The timeout is inside the slot: a queue for `heavy` on a busy
    # machine is not the design's time.
    command = [HEAVY, "xvfb-run", "-a", f"--server-args={SCREEN}",
               "timeout", "--kill-after=30", str(timeout), "godot", "--path", str(ROOT),
               "--log-file", str(run_dir / "godot_design.log"),
               "--", f"--mcp={port}", f"--ask-claude-code={subject.brief}", f"--out={ldr}"]
    started = time.time()
    with log.open("w") as out:
        status = subprocess.run(command, cwd=ROOT, env=_billing_free_env(),
                                stdout=out, stderr=subprocess.STDOUT).returncode
    seconds = time.time() - started
    text = log.read_text(errors="replace")
    finished = [line for line in text.splitlines() if line.startswith("claude code ok=")]
    took = re.search(r"\((\d+)s\)", finished[-1]) if finished else None
    result = {
        "status": status, "seconds": round(seconds, 1), "timed_out": status in (124, 137),
        # The session's own clock, without the wait for a slot.
        "design_seconds": int(took.group(1)) if took else None,
        "commit": sha, "port": port, "model": ldr.exists() and ldr.stat().st_size > 0,
        "finished": finished[-1][:300] if finished else "",
        "moved": _tidy_user_dir(since, text, port, run_dir / "saves"),
        "stopped": _stop_leftovers(port),
    }
    if not result["model"] and not result["timed_out"] and not finished:
        # The session never ran to an end (no slot, no display, a parse
        # error, its port taken while it queued): the machine failed, not
        # the design. Not recorded, so the same command tries it again.
        raise SystemExit(f"design {subject.id}: the app never started a design "
                         f"(status {status}); see {log}")
    _write_json(done, result)
    say(f"design {subject.id}: status {status} in {seconds / 60:.1f} min, "
        f"{'a model' if result['model'] else 'NO MODEL'}")
    return result


# -- pictures, the check and the measures --------------------------------


def render(model: Path, prefix: Path, log: Path) -> list[Path]:
    """Corner, front and close of a model, on the GPU, as PREFIX_{view}.png."""
    wanted = [prefix.parent / f"{prefix.name}_{v}.png" for v in VIEWS]
    if all(p.exists() for p in wanted):
        return wanted
    prefix.parent.mkdir(parents=True, exist_ok=True)
    command = [GPU, "xvfb-run", "-a", f"--server-args={SCREEN}",
               "timeout", "--kill-after=30", "900", "godot", "--path", str(ROOT), "--resolution", "1600x900",
               "--log-file", str(log.with_name(log.stem + "_godot.log")),
               "--script", "src/dev/bench_views.gd", "--",
               f"--model={model}", f"--views_out={prefix}"]
    with log.open("w") as out:
        subprocess.run(command, cwd=ROOT, env=_billing_free_env(MESA_VK_WSI_DEBUG="sw"),
                       stdout=out, stderr=subprocess.STDOUT)
    return [p for p in wanted if p.exists()]


def probe(run_dir: Path) -> dict:
    done = run_dir / "probe.json"
    if done.exists():
        return json.loads(done.read_text())
    command = [HEAVY, "timeout", "--kill-after=30", "1800", "godot", "--headless",
               "--path", str(ROOT), "--log-file", str(run_dir / "probe_godot.log"),
               "--script", "src/dev/candidate_probe.gd", "--", str(run_dir / "design.ldr")]
    text = subprocess.run(command, cwd=ROOT, env=_billing_free_env(), capture_output=True,
                          text=True).stdout
    (run_dir / "probe.txt").write_text(text)
    found = scores.read_probe(text)
    if found["ran"]:        # one that never ran is tried again on the next pass
        _write_json(done, found)
    return found


def probe_words(run_dir: Path) -> str:
    """The probe's verdict lines, without the engine's start-up chatter."""
    text = (run_dir / "probe.txt").read_text() if (run_dir / "probe.txt").exists() else ""
    kept = [line for line in text.splitlines()
            if re.match(r"\s+(ok|FAIL|still)\s", line) or "candidate" in line]
    return "\n".join(kept) or "the build check did not run"


def style(run_dir: Path, against: str) -> dict:
    done = run_dir / "style.json"
    if done.exists():
        return json.loads(done.read_text())
    ran = subprocess.run([sys.executable, str(ROOT / "tools" / "style.py"),
                          str(run_dir / "design.ldr"), "--against", against, "--json"],
                         cwd=ROOT, capture_output=True, text=True)
    lines = [line for line in ran.stdout.splitlines() if line.startswith("{")]
    found = json.loads(lines[-1]) if lines else {"error": ran.stderr.strip()[-300:]}
    _write_json(done, found)
    return found


# -- references and anchors ----------------------------------------------


def _fetch(url: str, out: Path) -> bool:
    try:
        request = urllib.request.Request(url, headers=AGENT)
        data = urllib.request.urlopen(request, timeout=120).read()
    except OSError as error:
        say(f"  could not fetch {url}: {error}")
        return False
    out.write_bytes(data)
    return True


def _omr_file(found: suite.OmrSet, into: Path, fetch: bool) -> Path | None:
    """A real set's file: the vendored copy, else fetched from the repository."""
    local = OMR_FILES / found.file
    if local.exists():
        return local
    kept = into / found.file
    if kept.exists() or not fetch:
        return kept if kept.exists() else None
    rows = {r["number"]: r for r in json.loads(OMR_INDEX.read_text())} if OMR_INDEX.exists() else {}
    page = rows.get(found.number, {}).get("page")
    if not page:
        return None
    html = into / f"omr_{found.number}.html"
    if not _fetch(f"{OMR_SITE}/omr/sets/{page}", html):
        return None
    links = re.findall(rf'href="({re.escape(OMR_SITE)}/library/omr/[^"]+\.(?:mpd|ldr))"',
                       html.read_text(errors="replace"))
    for url in links:
        if urllib.parse.unquote(url.rsplit("/", 1)[1]) == found.file and _fetch(url, kept):
            return kept
    return None


def references(subject: suite.Subject, subject_dir: Path, fetch: bool) -> list[judge.Picture]:
    """The subject's reference pictures, made once per batch, with what each shows."""
    refs = subject_dir / "refs"
    refs.mkdir(parents=True, exist_ok=True)
    pictures: list[judge.Picture] = []
    for n, ref in enumerate(subject.references, 1):
        if isinstance(ref, suite.Photo):
            suffix = Path(urllib.parse.urlparse(ref.url).path).suffix.lower() or ".jpg"
            out = refs / f"photo{n}{'.jpg' if suffix in ('.jpeg', '') else suffix}"
            if out.exists() or (fetch and _fetch(ref.url, out)):
                pictures.append(judge.Picture(out, f"a photograph: {ref.shows} "
                                                   f"({ref.author}, {ref.licence}, Wikimedia Commons)"))
        else:
            model = _omr_file(ref, refs, fetch)
            if model is None:
                say(f"  no file for {ref.number}")
                continue
            views = render(model, refs / f"set{n}", refs / f"set{n}_render.log")
            for view in views[:2]:          # corner and front; close adds little for a set
                pictures.append(judge.Picture(view, f"{ref.shows}, {view.stem.split('_')[-1]} view, "
                                                    "rendered from LDraw's model of the set"))
    _write_json(refs / "refs.json", [{"path": str(p.path), "what": p.what} for p in pictures])
    return pictures


def anchors(results: Path) -> tuple[judge.Picture, judge.Picture]:
    """The two calibration pictures, rendered once and reused by every batch after."""
    where = results / "anchors"
    where.mkdir(parents=True, exist_ok=True)
    high_model = OMR_FILES / suite.ANCHOR_HIGH.file
    high = render(high_model, where / "high", where / "high_render.log")
    low = render(HERE / suite.ANCHOR_LOW, where / "low", where / "low_render.log")
    if not high or not low:
        raise SystemExit(f"could not render the anchors; see {where}/*_render.log")
    digest = {p.name: hashlib.sha256(p.read_bytes()).hexdigest()[:12] for p in (high[0], low[0])}
    _write_json(where / "anchors.json", digest)
    return (judge.Picture(high[0], f"{suite.ANCHOR_HIGH.shows}, rendered from LDraw's model of "
                                   "the set"),
            judge.Picture(low[0], "the same kind of car built naively: a stack of plain bricks, "
                                  "studs up everywhere, three flat colours, no shaping"))


# -- the judge -----------------------------------------------------------


def judged(subject: suite.Subject, run_dir: Path, made: dict, refs: list[judge.Picture],
           marks: tuple[judge.Picture, judge.Picture], parts: int, canned: Path | None,
           model: str, name: str = "judge") -> dict:
    done = run_dir / f"{name}.json"
    if done.exists():
        return json.loads(done.read_text())
    if not made.get("model"):
        verdict = judge.nothing_built("no model was produced")
        result = {**verdict.as_dict(), "model": "none", "seconds": 0.0}
        _write_json(done, result)
        return result
    views = [judge.Picture(run_dir / f"views_{v}.png", f"the model, {v} view"
                           + (" (a nearer look at one quarter)" if v == "close" else ""))
             for v in VIEWS if (run_dir / f"views_{v}.png").exists()]
    text = judge.prompt(subject.title, subject.brief, subject.scale, marks, refs, views,
                        parts, probe_words(run_dir), suite.ANCHOR_HIGH_SCORE,
                        suite.ANCHOR_LOW_SCORE)
    (run_dir / "judge_prompt.txt").write_text(text)
    readable = sorted({str(p.path.parent) for p in (*marks, *refs, *views)})
    last_error = ""
    for attempt in (1, 2):
        if canned is not None:
            reply, seconds = json.loads(canned.read_text()), 0.0
        else:
            say(f"judge {subject.id}: asking (attempt {attempt})")
            reply, seconds = judge.call(text, run_dir, [Path(p) for p in readable], model=model)
        _write_json(run_dir / f"{name}_raw{'' if attempt == 1 else '_2'}.json", reply)
        try:
            verdict = judge.parse(reply)
        except ValueError as error:
            last_error = str(error)
            say(f"judge {subject.id}: unreadable reply ({error})")
            continue
        used = sorted((reply.get("modelUsage") or {}).keys()) if isinstance(reply, dict) else []
        result = {**verdict.as_dict(), "model": ", ".join(used) or ("canned" if canned else model),
                  "seconds": round(seconds, 1), "pictures": len(marks) + len(refs) + len(views)}
        _write_json(done, result)
        return result
    raise SystemExit(f"judge {subject.id}: no readable reply after two tries: {last_error}")


# -- a run -----------------------------------------------------------------


def run_one(subject: suite.Subject, batch: Path, run: int, args: argparse.Namespace,
            marks: tuple[judge.Picture, judge.Picture]) -> dict:
    subject_dir = batch / subject.id
    run_dir = subject_dir / str(run)
    run_dir.mkdir(parents=True, exist_ok=True)
    record_path = run_dir / "record.json"
    if record_path.exists():
        say(f"{subject.id} run {run}: already recorded")
        return json.loads(record_path.read_text())
    canned_design = CANNED / "design.ldr" if args.dry_run else None
    canned_judge = CANNED / "judge_reply.json" if args.dry_run else None
    made = design(subject, run_dir, args.timeout, canned_design)
    found_probe: dict = {}
    measured: dict = {}
    if made.get("model"):
        say(f"{subject.id}: views")
        if len(render(run_dir / "design.ldr", run_dir / "views",
                      run_dir / "views_render.log")) < len(VIEWS):
            raise SystemExit(f"{subject.id}: no pictures of the model; see "
                             f"{run_dir / 'views_render.log'}")
        say(f"{subject.id}: probe and style")
        found_probe = probe(run_dir)
        measured = style(run_dir, subject.against)
    if args.no_judge:
        say(f"{subject.id} run {run}: designed, not judged yet")
        return {}
    refs = references(subject, subject_dir, fetch=not args.dry_run)
    parts = int(found_probe.get("parts") or measured.get("parts") or 0)
    verdict = judged(subject, run_dir, made, refs, marks, parts, canned_judge, args.judge_model)
    record = {
        "subject": subject.id, "title": subject.title, "brief": subject.brief,
        "run": run, "batch": batch.name, "commit": made.get("commit") or commit(),
        "rubric": judge.RUBRIC_VERSION,
        "dry_run": bool(args.dry_run), "design": made, "probe": found_probe,
        "style": measured, "judge": verdict,
        "references": [str(p.path.relative_to(subject_dir)) for p in refs],
    }
    _write_json(record_path, record)
    say(f"{subject.id} run {run}: mean {verdict['mean']:.1f}  "
        + "  ".join(f"{d} {verdict['scores'][d]:.0f}" for d in judge.DIMENSIONS))
    return record


def rejudge(subject: suite.Subject, record_path: Path,
            marks: tuple[judge.Picture, judge.Picture], model: str) -> None:
    """The same pictures and words judged a second time, kept beside the first.

    The run-to-run spread is the design's noise and the judge's together;
    this is the judge's alone.
    """
    record = json.loads(record_path.read_text())
    if record.get("judge_again") or not record.get("design", {}).get("model"):
        return
    run_dir = record_path.parent
    listed = json.loads((run_dir.parent / "refs" / "refs.json").read_text())
    refs = [judge.Picture(Path(r["path"]), r["what"]) for r in listed]
    parts = int(record.get("probe", {}).get("parts") or record.get("style", {}).get("parts") or 0)
    verdict = judged(subject, run_dir, record["design"], refs, marks, parts, None, model,
                     name="judge_again")
    record["judge_again"] = verdict
    _write_json(record_path, record)
    say(f"{subject.id} run {record['run']} judged again: mean {verdict['mean']:.1f} "
        f"(first {record['judge']['mean']:.1f})")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="what", required=True)
    sub.add_parser("list", help="the suite")
    one = sub.add_parser("anchors", help="render the two calibration pictures")
    one.add_argument("--results", type=Path, default=RESULTS)
    go = sub.add_parser("run", help="design, picture, check, measure and judge")
    go.add_argument("--subjects", default="", help="ids, comma-separated; all if not said")
    go.add_argument("--run", type=int, default=1, help="which run of each subject this is")
    go.add_argument("--date", default="", help="the batch folder; today if not said")
    go.add_argument("--results", type=Path, default=RESULTS)
    go.add_argument("--timeout", type=int, default=2700, help="seconds a design may take")
    go.add_argument("--judge-model", default="opus")
    go.add_argument("--dry-run", action="store_true",
                    help="a canned design and a canned judge's reply; nothing fetched")
    go.add_argument("--no-judge", action="store_true",
                    help="design, picture, check and measure only; the same command without "
                         "it later judges what is there")
    again =sub.add_parser("rejudge", help="judge recorded runs again: the judge's own noise")
    again.add_argument("--date", default="")
    again.add_argument("--subjects", default="")
    again.add_argument("--results", type=Path, default=RESULTS)
    again.add_argument("--judge-model", default="opus")
    tell = sub.add_parser("summary", help="the batch's table")
    tell.add_argument("--date", default="")
    tell.add_argument("--results", type=Path, default=RESULTS)
    tell.add_argument("--append", type=Path, default=None,
                      help="append the table to this file (docs/DESIGN_SCORES.md)")
    args = parser.parse_args()

    if args.what == "list":
        for s in suite.SUITE:
            print(f"{s.id:18} {s.against:9} {s.scale}\n{'':18} {s.brief}")
            for ref in s.references:
                print(f"{'':18}   ref: {ref.shows}"
                      + (f" ({ref.licence}, {ref.page})" if isinstance(ref, suite.Photo) else ""))
        return 0
    if args.what == "anchors":
        for picture in anchors(args.results):
            print(picture.path)
        return 0
    name = args.date or (("dry-" if getattr(args, "dry_run", False) else "")
                         + f"{datetime.date.today():%Y-%m-%d}")
    batch = args.results / name
    if args.what == "summary":
        records = scores.collect(batch)
        if not records:
            print(f"no records under {batch}", file=sys.stderr)
            return 1
        text = scores.markdown(scores.summarise(records), batch.name)
        (batch / "summary.md").write_text(text)
        print(text)
        if args.append is not None:
            before = args.append.read_text() if args.append.exists() else ""
            args.append.write_text(before.rstrip("\n") + "\n\n" + text if before else text)
            print(f"appended to {args.append}")
        return 0
    wanted = [suite.by_id(i.strip()) for i in args.subjects.split(",") if i.strip()] or list(suite.SUITE)
    if args.what == "rejudge":
        marks = anchors(args.results)
        for subject in wanted:
            for record_path in sorted((batch / subject.id).glob("*/record.json")):
                rejudge(subject, record_path, marks, args.judge_model)
        return 0
    batch.mkdir(parents=True, exist_ok=True)
    say(f"batch {batch}, run {args.run}, {len(wanted)} subjects, commit {commit()}")
    marks = anchors(args.results)
    for subject in wanted:
        run_one(subject, batch, args.run, args, marks)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
