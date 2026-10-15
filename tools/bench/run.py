#!/usr/bin/env python3
"""Run the design bench: each subject designed, pictured, checked, measured and judged.

    python3 tools/bench/run.py list
    python3 tools/bench/run.py anchors
    heavy python3 tools/bench/run.py run [--subjects a,b] [--run N] [--date D] [--timeout S]
    python3 tools/bench/run.py run --dry-run [--subjects a]
    python3 tools/bench/run.py rejudge [--date D] [--subjects a,b]
    python3 tools/bench/run.py summary [--date D] [--append docs/DESIGN_SCORES.md]
    python3 tools/bench/run.py pairs [--subjects a,b] [--jobs 3] [--repeat 2] [--dry-run]
    gpu python3 tools/bench/run.py calibrate --draw-only      (or --software --jobs 3, no gpu)
    python3 tools/bench/run.py calibrate [--repeats 2] [--jobs 3] [--absolute]
    python3 tools/bench/run.py rank [--subjects a,b] [--out FILE]

(`heavy` is ~/.claude/claude-core/bin/heavy. A batch run as one heavy job
lets its design and probe steps use the slot it holds; run bare, each of
them queues for its own.)

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

Everything lands in the main checkout's bench/results/<date>/<subject>/<run>/
(gitignored; from a worktree too, which takes its untracked files with it
when it is removed),
and each stage is skipped when its output is there, so a batch that was
stopped is resumed by running the same command with the same --date.
--dry-run puts a canned design and a canned judge's reply in place of
the two calls and fetches nothing: the stages between run for real.

The pairwise judge (tools/bench/pairwise.py) reads every round at once:

  pairs      every two designs of a subject, from every batch, both orders,
             on the subscription; into bench/results/pairwise/<subject>/.
             --repeat 2 asks every pair again, for the judge's own noise.
  calibrate  pairs whose answer is known (tools/bench/calibrate.py): made,
             drawn (--draw-only inside one `gpu` lease, so no call to the
             judge holds the GPU; or --software, the same renderer on
             lavapipe under `heavy`), judged both orders --repeats times,
             and their agreement said; --absolute also scores each with
             the 1-10 judge, to compare the two on the same pairs.
  rank       Bradley-Terry ELO per design with 95% intervals, the run-to-run
             spread, and each lever's change across subjects.
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
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import running  # noqa: E402
from bench import calibrate, judge, pairwise, scores, suite  # noqa: E402

HERE = Path(__file__).resolve().parent


def _main_results() -> Path:
    """bench/results in the main checkout, whichever worktree runs this.

    Results are not committed, and a worktree's go with it when it is
    removed: the raw results of four rounds went that way on 2026-10-13.
    """
    common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                            cwd=ROOT, capture_output=True, text=True).stdout.strip()
    return (Path(common).parent if common else ROOT) / "bench" / "results"


RESULTS = _main_results()
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


def commit(app: Path = ROOT) -> str:
    """The app's commit, -dirty when its src has changes; "?" outside a checkout."""
    sha = subprocess.run(["git", "rev-parse", "--short", "HEAD"], cwd=app,
                         capture_output=True, text=True).stdout.strip() or "?"
    dirty = subprocess.run(["git", "status", "--porcelain", "--untracked-files=no", "src"],
                           cwd=app, capture_output=True, text=True).stdout.strip()
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


def design(subject: suite.Subject, run_dir: Path, timeout: int, canned: Path | None,
           extra: tuple[str, ...] = (), app: Path = ROOT) -> dict:
    """The real loop on one brief; `extra` goes to the app after the bench's own
    arguments (tools/bench/brickbench.py keeps its runs to a list of parts).
    `app` is the checkout whose app designs: one arm of a comparison can run
    an export of an earlier commit beside this one."""
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
    sha = commit(app)   # the code the design runs on, not the code that judges it
    log = run_dir / "design.log"
    since = time.time() - 1.0
    say(f"design {subject.id}: port {port}, up to {timeout // 60} min")
    # The timeout is inside the slot: a queue for `heavy` on a busy
    # machine is not the design's time.
    command = [HEAVY, "xvfb-run", "-a", f"--server-args={SCREEN}",
               "timeout", "--kill-after=30", str(timeout), "godot", "--path", str(app),
               "--log-file", str(run_dir / "godot_design.log"),
               "--", f"--mcp={port}", f"--ask-claude-code={subject.brief}", f"--out={ldr}",
               # The subject's own scored designs are the answer under test:
               # the designer's memory leaves them out (src/ai/design_memory.gd).
               f"--held-out={subject.id}", *extra]
    started = time.time()
    with log.open("w") as out:
        status = subprocess.run(command, cwd=app, env=_billing_free_env(),
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
        **({} if app == ROOT else {"app": str(app)}),
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


# Vulkan on the CPU: the GPU's own renderer, Forward+, with no lease to wait for.
# The godot wrapper's plain software path is the compatibility renderer, which
# shades differently; GODOT_GPU=1 pinned to this one ICD is software on purpose.
LAVAPIPE = "/usr/share/vulkan/icd.d/lvp_icd.json"


def render(model: Path, prefix: Path, log: Path, software: bool = False,
           views: tuple[str, ...] = VIEWS) -> list[Path]:
    """Corner, front and close of a model, on the GPU, as PREFIX_{view}.png.

    `software` draws the same renderer on lavapipe under `heavy` instead,
    for when the GPU's queue is long; both sides of a comparison are drawn
    the same way. `views` takes others of ModelShot's angles instead.
    """
    wanted = [prefix.parent / f"{prefix.name}_{v}.png" for v in views]
    if all(p.exists() for p in wanted):
        return wanted
    prefix.parent.mkdir(parents=True, exist_ok=True)
    command = [HEAVY if software else GPU, "xvfb-run", "-a", f"--server-args={SCREEN}",
               "timeout", "--kill-after=30", "900", "godot", "--path", str(ROOT), "--resolution", "1600x900",
               "--log-file", str(log.with_name(log.stem + "_godot.log")),
               "--script", "src/dev/bench_views.gd", "--",
               f"--model={model}", f"--views_out={prefix}",
               *([f"--views={','.join(views)}"] if views != VIEWS else [])]
    env = (_billing_free_env(GODOT_GPU="1", VK_ICD_FILENAMES=LAVAPIPE, VK_DRIVER_FILES=LAVAPIPE,
                             MESA_VK_WSI_DEBUG="sw") if software
           else _billing_free_env(MESA_VK_WSI_DEBUG="sw"))
    with log.open("w") as out:
        subprocess.run(command, cwd=ROOT, env=env, stdout=out, stderr=subprocess.STDOUT)
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


# -- the pairwise judge ----------------------------------------------------

PAIRWISE = RESULTS / "pairwise"
CANNED_PAIR = CANNED / "pair_reply.json"

# Which round each batch is. Two batches of one round (the edges round's
# second car, the shapes round's two trial cars) are more designs of it.
ROUNDS: dict[str, str] = {
    "2026-10-12": "baseline", "2026-10-13-d6": "d6", "2026-10-13-d6b": "d6b",
    "2026-10-13-surface": "surface", "2026-10-13-edges": "edges",
    "2026-10-13-edges-b": "edges", "2026-10-13-steps": "steps", "2026-10-14-sides": "sides",
    "2026-10-14-shapes": "shapes", "2026-10-14-shapes-trial": "shapes",
    "2026-10-14-cabins": "cabins", "2026-10-14-figures": "figures",
}
# Each lever against the round it was read against in docs/DESIGN_SCORES.md.
# The surface round branched from staging without d6's feature pass, so the
# baseline is what it changed.
LEVERS: tuple[tuple[str, str], ...] = (
    ("d6", "baseline"), ("d6b", "d6"), ("surface", "baseline"), ("edges", "surface"),
    ("steps", "edges"), ("sides", "steps"), ("shapes", "sides"), ("cabins", "shapes"),
    ("figures", "cabins"))
# Designs of one brief made on the same code: what luck alone moves a design.
TWINS: tuple[tuple[str, ...], ...] = (
    ("2026-10-12/1", "2026-10-12/2"),
    ("2026-10-14-shapes-trial/1", "2026-10-14-shapes-trial/2"),
    ("2026-10-14-cabins/1", "2026-10-14-cabins/2"),
    ("2026-10-14-figures/1", "2026-10-14-figures/2"))


@dataclass(frozen=True, slots=True)
class Entry:
    """A design in a subject's pool: every batch's runs that have their three views."""

    key: str                    # "2026-10-13-surface/1"
    views: tuple[Path, ...]
    parts: int
    probe: str
    scores: dict                # the 1-10 judge's, for comparing the two
    mean: float | None


def round_of(key: str) -> str:
    batch = key.split("/")[0]
    return ROUNDS.get(batch, batch)


def pool(subject_id: str, results: Path = RESULTS) -> list[Entry]:
    found: list[Entry] = []
    for batch in sorted(p for p in results.iterdir() if p.is_dir()):
        if batch.name == "anchors" or batch.name.startswith(("pairwise", "dry-")):
            continue
        runs = [p for p in (batch / subject_id).glob("*") if p.name.isdigit()]
        for run_dir in sorted(runs, key=lambda p: int(p.name)):
            views = tuple(run_dir / f"views_{v}.png" for v in VIEWS)
            if not all(v.exists() for v in views):
                continue
            record = (json.loads((run_dir / "record.json").read_text())
                      if (run_dir / "record.json").exists() else {})
            parts = int(record.get("probe", {}).get("parts")
                        or record.get("style", {}).get("parts") or 0)
            verdict = record.get("judge", {})
            found.append(Entry(f"{batch.name}/{run_dir.name}", views, parts,
                               probe_words(run_dir), verdict.get("scores", {}),
                               verdict.get("mean")))
    return found


def subject_refs(subject_id: str, results: Path = RESULTS) -> list[judge.Picture]:
    """The subject's references from the latest batch that has the most of them."""
    best: list[judge.Picture] = []
    for listed in sorted(results.glob(f"*/{subject_id}/refs/refs.json")):
        if listed.parts[-4].startswith(("pairwise", "dry-")):
            continue
        pictures = [judge.Picture(Path(r["path"]), r["what"])
                    for r in json.loads(listed.read_text()) if Path(r["path"]).exists()]
        if len(pictures) >= len(best):
            best = pictures
    return best


def _shown(key: str, views: tuple[Path, ...], parts: int, probe: str,
           into: Path) -> pairwise.Shown:
    """A design's pictures copied under a name that says nothing of its round."""
    code = pairwise.opaque(key)
    into.mkdir(parents=True, exist_ok=True)
    pictures = []
    for view, source in zip(VIEWS, views):
        out = into / f"{code}_{view}.png"
        if source != out and (not out.exists() or out.stat().st_size != source.stat().st_size):
            shutil.copyfile(source, out)
        pictures.append(judge.Picture(out, f"{view} view" + (
            " (a nearer look at one quarter)" if view == "close" else "")))
    return pairwise.Shown(tuple(pictures), parts, probe)


def judge_pair(subject: suite.Subject, where: Path, refs: list[judge.Picture],
               first: tuple[str, pairwise.Shown], second: tuple[str, pairwise.Shown],
               repeat: int, canned: Path | None, model: str) -> pairwise.Verdict | None:
    """One ordered pair asked once (or read back), into where/judged/."""
    (a_key, a), (b_key, b) = first, second
    name = f"{pairwise.opaque(a_key)}-{pairwise.opaque(b_key)}" + (
        "" if repeat == 1 else f"-{repeat}")
    done = where / "judged" / f"{name}.json"
    if done.exists():
        return pairwise.Verdict.from_dict(json.loads(done.read_text()))
    text = pairwise.prompt(subject.title, subject.brief, subject.scale, refs, a, b)
    example = where / "prompt_example.txt"
    if not example.exists():
        example.parent.mkdir(parents=True, exist_ok=True)
        example.write_text(text)
    readable = sorted({str(p.path.parent) for p in (*refs, *a.views, *b.views)})
    error = ""
    for attempt in (1, 2):
        if canned is not None:
            reply, seconds = json.loads(canned.read_text()), 0.0
        else:
            say(f"pair {subject.id} {name}: asking (attempt {attempt})")
            try:
                reply, seconds = judge.call(text, where, [Path(r) for r in readable],
                                            model=model, schema=pairwise.SCHEMA)
            except (RuntimeError, subprocess.TimeoutExpired, json.JSONDecodeError) as failed:
                error = str(failed)
                continue
        try:
            verdict = pairwise.parse(reply, a_key, b_key)
        except ValueError as failed:
            error = str(failed)
            continue
        used = sorted((reply.get("modelUsage") or {}).keys()) if isinstance(reply, dict) else []
        done.parent.mkdir(parents=True, exist_ok=True)
        _write_json(done, {**verdict.as_dict(), "repeat": repeat,
                           "model": ", ".join(used) or ("canned" if canned else model),
                           "seconds": round(seconds, 1)})
        return verdict
    say(f"pair {subject.id} {name}: no readable reply ({error[:160]})")
    return None


def _ask_all(tasks: list, jobs: int) -> list[pairwise.Verdict]:
    with ThreadPoolExecutor(max_workers=max(1, jobs)) as workers:
        return [v for v in workers.map(lambda task: judge_pair(*task), tasks) if v is not None]


def pairs(subject: suite.Subject, jobs: int, repeat: int, canned: Path | None, model: str,
          out: Path) -> list[pairwise.Verdict]:
    """Every two designs of a subject, from every batch, in both orders."""
    entries = pool(subject.id)
    if len(entries) < 2:
        say(f"pairs {subject.id}: {len(entries)} design, nothing to compare")
        return []
    where = out / subject.id
    refs = subject_refs(subject.id)
    shown = {e.key: _shown(e.key, e.views, e.parts, e.probe, where / "designs") for e in entries}
    _write_json(where / "designs.json", {pairwise.opaque(e.key): {
        "key": e.key, "round": round_of(e.key), "parts": e.parts, "mean": e.mean}
        for e in entries})
    tasks = []
    for i, x in enumerate(entries):
        for y in entries[i + 1:]:
            for a, b in ((x, y), (y, x)):
                tasks.append((subject, where, refs, (a.key, shown[a.key]), (b.key, shown[b.key]),
                              repeat, canned, model))
    say(f"pairs {subject.id}: {len(entries)} designs, {len(tasks)} ordered pairs")
    return _ask_all(tasks, jobs)


def verdicts(where: Path, repeat: int = 1) -> list[pairwise.Verdict]:
    found = []
    for path in sorted((where / "judged").glob("*.json")):
        said = json.loads(path.read_text())
        if int(said.get("repeat", 1)) == repeat:
            found.append(pairwise.Verdict.from_dict(said))
    return found


def _spearman(xs: list[float], ys: list[float]) -> float | None:
    def ranks(values: list[float]) -> list[float]:
        order = sorted(range(len(values)), key=lambda i: values[i])
        out = [0.0] * len(values)
        i = 0
        while i < len(order):
            j = i
            while j + 1 < len(order) and values[order[j + 1]] == values[order[i]]:
                j += 1
            for k in range(i, j + 1):
                out[order[k]] = (i + j) / 2
            i = j + 1
        return out
    if len(xs) < 3:
        return None
    rx, ry = ranks(xs), ranks(ys)
    mx, my = sum(rx) / len(rx), sum(ry) / len(ry)
    top = sum((a - mx) * (b - my) for a, b in zip(rx, ry))
    bottom = (sum((a - mx) ** 2 for a in rx) * sum((b - my) ** 2 for b in ry)) ** 0.5
    return top / bottom if bottom else None


def _ten(entry: Entry, dim: str) -> float | None:
    """The 1-10 judge on one dimension, overall as the mean of its six."""
    if dim == "overall":
        return entry.mean
    value = entry.scores.get(dim)
    return float(value) if value is not None else None


def rank_rounds(subjects: list[suite.Subject], draws: int, root: Path = PAIRWISE) -> str:
    """Every judged subject's ranking, the run-to-run spread, and each lever, as markdown."""
    short = {**scores.SHORT, "overall": "overall"}
    rankings: dict[str, dict[str, pairwise.Ranking]] = {}
    entries: dict[str, dict[str, Entry]] = {}
    out: list[str] = []
    for subject in subjects:
        where = root / subject.id
        said = verdicts(where)
        if not said:
            continue
        judged_keys = {v.first for v in said} | {v.second for v in said}
        found_pool = {e.key: e for e in pool(subject.id) if e.key in judged_keys}
        keys = list(found_pool)
        entries[subject.id] = found_pool
        rankings[subject.id] = {dim: pairwise.rank(keys, said, dim, draws)
                                for dim in pairwise.DIMENSIONS}
        overall = rankings[subject.id]["overall"]
        out += ["", f"### {subject.id}: {len(keys)} designs, {len(said)} verdicts", "",
                "| design | round | 1-10 mean | overall ELO (95%) | "
                + " | ".join(short[d] for d in judge.DIMENSIONS) + " |",
                "|" + "---|" * (4 + len(judge.DIMENSIONS))]
        for key in overall.order():
            e = found_pool[key]
            out.append(f"| {key} | {round_of(key)} | "
                       + (f"{e.mean:.2f}" if e.mean is not None else "") + " | "
                       + f"**{overall.elo[key]:.0f}** ({overall.low[key]:.0f}-"
                       f"{overall.high[key]:.0f}) | "
                       + " | ".join(f"{rankings[subject.id][d].elo[key]:.0f}"
                                    for d in judge.DIMENSIONS) + " |")
        rho = _spearman([overall.elo[k] for k in keys], [found_pool[k].mean or 0.0 for k in keys])
        if rho is not None:
            out.append(f"\nRank agreement with the 1-10 means (Spearman): {rho:.2f}.")
        again = verdicts(where, 2)
        if again:
            twice = {dim: pairwise.rank(keys, again, dim, 0) for dim in pairwise.DIMENSIONS}
            shift = {dim: pairwise.mean_abs([twice[dim].elo[k] - rankings[subject.id][dim].elo[k]
                                             for k in keys]) for dim in pairwise.DIMENSIONS}
            first = {(v.first, v.second): v for v in said}
            matched = [(first[(b.first, b.second)], b) for b in again
                       if (b.first, b.second) in first]
            same = sum(a.winners[d] == b.winners[d] for a, b in matched
                       for d in pairwise.DIMENSIONS)
            of = len(matched) * len(pairwise.DIMENSIONS)
            out.append(f"\nThe judge alone, every pair asked again ({len(again)} verdicts): "
                       f"the same answer {pairwise.share(same, of)}; a design's ELO moves by "
                       + ", ".join(f"{short[d]} {shift[d]:.0f}" for d in pairwise.DIMENSIONS)
                       + " on average.")
    if not rankings:
        return "no pairs judged yet\n"
    twins = {s: [[k for k in group if k in entries[s]] for group in TWINS] for s in rankings}
    spread: dict[str, float] = {}
    out += ["", "### Run to run: two designs of one brief on the same code", "",
            "| subject | designs | " + " | ".join(short[d] for d in pairwise.DIMENSIONS) + " |",
            "|" + "---|" * (2 + len(pairwise.DIMENSIONS))]
    for s, groups in twins.items():
        for group in groups:
            if len(group) == 2:
                out.append(f"| {s} | {group[0]} - {group[1]} | " + " | ".join(
                    f"{rankings[s][d].elo[group[1]] - rankings[s][d].elo[group[0]]:+.0f}"
                    for d in pairwise.DIMENSIONS) + " |")
    for dim in pairwise.DIMENSIONS:
        spread[dim] = pairwise.run_spread({s: rankings[s][dim] for s in rankings}, twins) or 0.0
    out.append("\nOne design's ELO about its code's mean, pooled (standard deviation): "
               + ", ".join(f"{short[d]} {spread[d]:.0f}" for d in pairwise.DIMENSIONS) + ".")
    out += ["", "### Levers: after minus before, ELO, mean over the subjects in both", "",
            "Bold where the interval with the run-to-run spread in it excludes 0. The 1-10 "
            "column is the old judge's change over the same subjects.", "",
            "| lever | against | subjects | dimension | ELO change | judge's 95% | "
            "with run-to-run 95% | 1-10 change |",
            "|---|---|---|---|---|---|---|---|"]
    def row(after: str, before: str, dim: str) -> str | None:
        groups = {s: ([k for k in entries[s] if round_of(k) == before],
                      [k for k in entries[s] if round_of(k) == after]) for s in rankings}
        found = pairwise.effect(after, dim, {s: rankings[s][dim] for s in rankings},
                                groups, spread[dim])
        if found is None:
            return None
        tens = []
        for s in found.subjects:
            b = [_ten(entries[s][k], dim) for k in groups[s][0]]
            a = [_ten(entries[s][k], dim) for k in groups[s][1]]
            if all(v is not None for v in (*a, *b)):
                tens.append(sum(a) / len(a) - sum(b) / len(b))  # type: ignore[arg-type]
        mark = "**" if found.low_runs > 0 or found.high_runs < 0 else ""
        return (f"| {after} | {before} | {len(found.subjects)} | {short[dim]} | "
                f"{mark}{found.mean:+.0f}{mark} | ({found.low:+.0f}, {found.high:+.0f}) | "
                f"({found.low_runs:+.0f}, {found.high_runs:+.0f}) | "
                + (f"{sum(tens) / len(tens):+.2f}" if tens else "") + " |")

    for after, before in LEVERS:
        out += [r for dim in pairwise.DIMENSIONS if (r := row(after, before, dim))]
    out += ["", "### Each round against the baseline, overall", "",
            "| round | against | subjects | dimension | ELO change | judge's 95% | "
            "with run-to-run 95% | 1-10 change |",
            "|---|---|---|---|---|---|---|---|"]
    since = sorted({round_of(k) for s in entries for k in entries[s]} - {"baseline"},
                   key=lambda r: [a for a, _b in LEVERS].index(r) if r in dict(LEVERS) else 99)
    out += [r for after in since if (r := row(after, "baseline", "overall"))]
    return "\n".join(out).lstrip("\n") + "\n"


# -- calibrating the pairwise judge ----------------------------------------


def _calibration_models(where: Path) -> tuple[dict[str, Path], list[pairwise.Known],
                                              dict[str, calibrate.Pair]]:
    """Each known pair's two models written out, once each."""
    parts = calibrate.style.Parts()
    colours = calibrate.palette()
    models = where / "models"
    models.mkdir(parents=True, exist_ok=True)
    made: dict[str, Path] = {}
    known: list[pairwise.Known] = []
    specs: dict[str, calibrate.Pair] = {}
    notes: dict[str, str] = {}
    for pair in calibrate.PAIRS:
        if pair.kind == calibrate.REAL:
            source = OMR_FILES / f"{pair.source}.mpd"
            better = f"set {pair.source}"
        else:
            source = RESULTS / pair.source / "design.ldr"
            better = f"{pair.source} as it was"
        if not source.exists():
            say(f"calibrate {pair.id}: no {source}")
            continue
        worse = f"{pair.source} with {pair.fault}"
        text = source.read_text(errors="replace")
        for key in (better, worse):
            path = models / f"{pairwise.opaque(key)}{source.suffix}"
            if not path.exists():
                if key == better:
                    made_text, said = text, "as it was"
                elif pair.fault == "naive":
                    made_text, said = calibrate.naive_stack(text, parts, colours)
                else:
                    made_text, said = calibrate.with_fault(text, pair.fault, parts, colours)
                path.write_text(made_text)
                notes[key] = said
            made[key] = path
        known.append(pairwise.Known(pair.id, pair.kind, better, worse, pair.dims))
        specs[pair.id] = pair
    if notes:
        listed = where / "models.json"
        before = json.loads(listed.read_text()) if listed.exists() else {}
        _write_json(listed, {**before, **{pairwise.opaque(k): {"key": k, "made": v}
                                          for k, v in notes.items()}})
    return made, known, specs


def _calibration_refs(pair: calibrate.Pair) -> list[judge.Picture]:
    refs = subject_refs(pair.subject)
    if pair.kind == calibrate.REAL:         # the set itself is no reference for itself
        refs = [r for r in refs if r.path.name.startswith("photo")]
    return refs


def calibration(repeats: int, jobs: int, model: str, absolute: bool, draw_only: bool = False,
                software: bool = False) -> str:
    """Known pairs made, drawn, judged both orders `repeats` times, and their agreement said.

    `draw_only` makes and draws them and stops, so no call to the judge
    holds the GPU. `software` draws them on lavapipe under `heavy`, `jobs`
    at once, each in a slot of its own.
    """
    where = PAIRWISE / "calibration"
    made, known, specs = _calibration_models(where)
    designs, logs = where / "designs", where / "logs"
    logs.mkdir(parents=True, exist_ok=True)

    def draw(key: str) -> None:
        code = pairwise.opaque(key)
        if not all((designs / f"{code}_{v}.png").exists() for v in VIEWS):
            say(f"calibrate: drawing {key}")
            render(made[key], designs / code, logs / f"{code}_render.log", software)

    with ThreadPoolExecutor(max_workers=max(1, jobs) if software else 1) as workers:
        list(workers.map(draw, made))
    pictured: dict[str, tuple[Path, ...]] = {}
    for key in made:
        code = pairwise.opaque(key)
        views = tuple(designs / f"{code}_{v}.png" for v in VIEWS)
        if all(v.exists() for v in views):
            pictured[key] = views
        else:
            say(f"calibrate: no pictures of {key}; see {logs / (code + '_render.log')}")
    if draw_only:
        return f"{len(pictured)} of {len(made)} models drawn into {designs}\n"
    tasks = []
    shown: dict[str, pairwise.Shown] = {}
    for k in known:
        if k.better not in pictured or k.worse not in pictured:
            continue
        pair = specs[k.id]
        subject = suite.by_id(pair.subject)
        refs = _calibration_refs(pair)
        for key in (k.better, k.worse):
            if key not in shown:
                count = len(calibrate.style.read(made[key].read_text(errors="replace")).placed)
                shown[key] = _shown(key, pictured[key], count, "", designs)
        for repeat in range(1, repeats + 1):
            for a, b in ((k.better, k.worse), (k.worse, k.better)):
                tasks.append((subject, where, refs, (a, shown[a]), (b, shown[b]), repeat, None,
                              model))
    say(f"calibrate: {len(known)} known pairs, {len(tasks)} ordered judgements")
    found = _ask_all(tasks, jobs)
    ten: dict[str, dict] = {}
    if absolute:
        marks = anchors(RESULTS)
        asks: dict[str, tuple] = {}
        for k in known:
            pair = specs[k.id]
            for key in (k.better, k.worse):
                if key not in asks and key in shown:
                    asks[key] = (suite.by_id(pair.subject), where, key, shown[key],
                                 _calibration_refs(pair), marks, model)
        with ThreadPoolExecutor(max_workers=max(1, jobs)) as workers:
            ten = dict(zip(asks, workers.map(lambda ask: _absolute(*ask), asks.values())))
    return calibration_report(known, found, specs, ten)


def _absolute(subject: suite.Subject, where: Path, key: str, shown: pairwise.Shown,
              refs: list[judge.Picture], marks: tuple[judge.Picture, judge.Picture],
              model: str) -> dict:
    """The 1-10 judge on one calibration model, as it judges every bench design."""
    done = where / "absolute" / f"{pairwise.opaque(key)}.json"
    if done.exists():
        return json.loads(done.read_text())
    text = judge.prompt(subject.title, subject.brief, subject.scale, marks, refs,
                        list(shown.views), shown.parts, "the build check was not run",
                        suite.ANCHOR_HIGH_SCORE, suite.ANCHOR_LOW_SCORE)
    readable = sorted({str(p.path.parent) for p in (*marks, *refs, *shown.views)})
    for attempt in (1, 2):
        say(f"calibrate: 1-10 on {key} (attempt {attempt})")
        try:
            reply, seconds = judge.call(text, where, [Path(r) for r in readable], model=model)
            verdict = judge.parse(reply)
        except (RuntimeError, ValueError, subprocess.TimeoutExpired,
                json.JSONDecodeError) as failed:
            say(f"calibrate: 1-10 on {key}: {str(failed)[:160]}")
            continue
        result = {"key": key, **verdict.as_dict(), "seconds": round(seconds, 1)}
        done.parent.mkdir(parents=True, exist_ok=True)
        _write_json(done, result)
        return result
    return {}


def calibration_report(known: list[pairwise.Known], found: list[pairwise.Verdict],
                       specs: dict[str, calibrate.Pair], ten: dict[str, dict]) -> str:
    said = pairwise.agreement(known, found)
    v, p = said["verdicts"], said["pairs"]
    low, high = pairwise.wilson(v["agree"], v["of"])
    orders, repeats, first = said["orders"], said["repeats"], said["first_pick"]
    out = [f"Known pairs: {len(known)}; verdicts: {len(found)}.", "",
           f"- One verdict names the known winner: {pairwise.share(v['agree'], v['of'])}, "
           f"95% {100 * low:.0f}-{100 * high:.0f}%.",
           f"- A pair on one dimension, every verdict in both orders and every repeat: right "
           f"{p['agree']}, split {p['split']}, wrong {p['wrong']}.",
           f"- The two orders name the same design (every dimension): "
           f"{pairwise.share(orders['same'], orders['of'])}.",
           f"- The same order asked again names the same design: "
           f"{pairwise.share(repeats['same'], repeats['of'])}.",
           f"- Picks the model shown first: {pairwise.share(first['A'], first['of'])}.",
           "", "| kind | verdicts right | pairs right on every verdict |", "|---|---|---|"]
    for kind, tally in said["kinds"].items():
        out.append(f"| {kind} | {pairwise.share(tally['agree'], tally['of'])} | "
                   f"{pairwise.share(tally['pairs_agree'], tally['pairs'])} |")
    out += ["", "| dimension | verdicts right |", "|---|---|"]
    for dim, tally in said["dims"].items():
        out.append(f"| {dim} | {pairwise.share(tally['agree'], tally['of'])} |")
    by_pair: dict[frozenset, list[pairwise.Verdict]] = {}
    for verdict in found:
        by_pair.setdefault(frozenset((verdict.first, verdict.second)), []).append(verdict)
    out += ["", "| pair | fault | " + " | ".join(pairwise.DIMENSIONS) + " |",
            "|" + "---|" * (2 + len(pairwise.DIMENSIONS))]
    for k in known:
        got = by_pair.get(frozenset((k.better, k.worse)), [])
        if not got:
            continue
        cells = [f"{sum(x.winners[dim] == k.better for x in got)}/{len(got)}"
                 + ("" if dim in k.dims else "*") for dim in pairwise.DIMENSIONS]
        out.append(f"| {k.id} | {specs[k.id].fault} | " + " | ".join(cells) + " |")
    out.append("\nEach cell: verdicts naming the model without the fault, of all on the pair; "
               "* marks a dimension the fault was not meant to change.")
    halo = [x.winners[dim] == k.better for k in known
            for x in by_pair.get(frozenset((k.better, k.worse)), [])
            for dim in pairwise.DIMENSIONS if dim not in k.dims]
    out.append(f"\nOn the dimensions a fault was not meant to change, the judge still named the "
               f"model without it in {pairwise.share(sum(halo), len(halo))} of its verdicts: a "
               "forced choice between two equals goes to the better model overall.")
    if ten:
        tally = {"higher": 0, "same": 0, "lower": 0}
        for k in known:
            a, b = ten.get(k.better, {}), ten.get(k.worse, {})
            if not a.get("scores") or not b.get("scores"):
                continue
            for dim in k.dims:
                x = a["mean"] if dim == "overall" else a["scores"][dim]
                y = b["mean"] if dim == "overall" else b["scores"][dim]
                tally["higher" if x > y else "same" if x == y else "lower"] += 1
        whole = sum(tally.values())
        out += ["", "The 1-10 judge on the same pairs, once each: the model without the fault "
                f"scored higher on {pairwise.share(tally['higher'], whole)} of the known "
                f"dimensions, the same on {pairwise.share(tally['same'], whole)}, lower on "
                f"{pairwise.share(tally['lower'], whole)}."]
    return "\n".join(out) + "\n"


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
    pair = sub.add_parser("pairs", help="judge every two designs of a subject, both orders")
    pair.add_argument("--subjects", default="", help="ids, comma-separated; all if not said")
    pair.add_argument("--jobs", type=int, default=3, help="calls at once")
    pair.add_argument("--repeat", type=int, default=1,
                      help="2 asks every pair again, kept apart: the judge's own noise")
    pair.add_argument("--judge-model", default="opus")
    pair.add_argument("--dry-run", action="store_true",
                      help="a canned reply, into bench/results/dry-pairwise/; nothing asked")
    known = sub.add_parser("calibrate", help="the pairwise judge on pairs whose answer is known")
    known.add_argument("--repeats", type=int, default=2)
    known.add_argument("--jobs", type=int, default=3)
    known.add_argument("--judge-model", default="opus")
    known.add_argument("--draw-only", action="store_true",
                       help="make and draw the models, ask nothing: run it as `gpu python3 ...`")
    known.add_argument("--software", action="store_true",
                       help="draw on lavapipe under heavy (the same pictures), not on the GPU")
    known.add_argument("--absolute", action="store_true",
                       help="also score each model 1-10, to compare the two judges")
    ranked = sub.add_parser("rank", help="ELO per design and each lever's change, as markdown")
    ranked.add_argument("--subjects", default="")
    ranked.add_argument("--draws", type=int, default=pairwise.DRAWS)
    ranked.add_argument("--dry-run", action="store_true", help="read the dry run's pairs")
    ranked.add_argument("--out", type=Path, default=None, help="also write the markdown here")
    args = parser.parse_args()

    if args.what in ("pairs", "calibrate", "rank"):
        return _pairwise_main(args)
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



def _pairwise_main(args: argparse.Namespace) -> int:
    root = RESULTS / "dry-pairwise" if getattr(args, "dry_run", False) else PAIRWISE
    if args.what == "calibrate":
        text = calibration(args.repeats, args.jobs, args.judge_model, args.absolute,
                           args.draw_only, args.software)
        if args.draw_only:
            print(text)
            return 0
        (PAIRWISE / "calibration" / "calibration.md").write_text(text)
        print(text)
        return 0
    wanted = ([suite.by_id(i.strip()) for i in args.subjects.split(",") if i.strip()]
              or list(suite.SUITE))
    if args.what == "pairs":
        canned = CANNED_PAIR if args.dry_run else None
        for subject in wanted:
            found = pairs(subject, args.jobs, args.repeat, canned, args.judge_model, root)
            say(f"pairs {subject.id}: {len(found)} verdicts")
        return 0
    text = rank_rounds(wanted, args.draws, root)
    if args.out is not None:
        args.out.write_text(text)
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
