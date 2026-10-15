#!/usr/bin/env python3
"""Brickworks' designer on BrickBench's Model setting, run here and judged against BrickAgent.

    python3 tools/bench/brickbench.py prompts --upstream DIR    the ten prompts, the brief each is given
                                              [--skip 10]       ...or the ten after them, held out
    python3 tools/bench/brickbench.py parts --upstream DIR      BrickNet's parts, as --parts-only reads them
    heavy python3 tools/bench/brickbench.py design [--tasks model-001,...] [--jobs 2]
    python3 tools/bench/brickbench.py export --python PY        model.mpd and build.py for each design
    python3 tools/bench/brickbench.py verify --upstream DIR --python PY [--which ours,theirs]
    python3 tools/bench/brickbench.py zip --upstream DIR        the submission zip, and their check of it
    python3 tools/bench/brickbench.py fetch                     BrickAgent's Opus 5.5 builds of the same ten
    python3 tools/bench/brickbench.py views [--software]        four views of every build, by our renderer
    python3 tools/bench/brickbench.py pairs [--repeat 2]        our pairwise judge, both orders
    python3 tools/bench/brickbench.py report [--out FILE]       the tables docs/BRICKBENCH.md quotes

A comparison of arms on held-out prompts, each arm the app of one checkout:

    brickbench.py prompts --start 21 --date D                  model-021 to model-030
    heavy brickbench.py design --date D --arm A --runs 2 [--app DIR]   two designs a prompt
    brickbench.py export|verify --date D --arm A --runs 2
    brickbench.py views|pairs --date D --arms A,B --runs 2     each design against every other and theirs
    brickbench.py compare --date D --arms A,B --runs 2         ELO a arm, head to head, what they are made of

BrickBench (Kulits et al., 2026; MIT code at https://github.com/kulits/BrickAgent)
ranks AI LEGO® designers on 300 prompts. Its Model setting asks for at most 400
pieces, from BrickNet's 14,441 parts only, and a submission is a folder a
prompt holding `model.mpd` and the `build.py` its `scripts/verify.py` rebuilds.

- **prompts** takes the first ten of `benchmark/model/tasks.json`, in file
  order: model-001 to model-010. Each is designed from the prompt and the
  setting's own limit, "Use at most 400 pieces."
- **design** is run.py's design stage, the real loop on the subscription
  (no API key, under `heavy`, at most two at a time), started with
  `--parts-only=bricknet_parts.txt` (src/parts/parts_only.gd): search lists
  only those parts and a design or an edit with any other is refused, so
  the designer swaps it. Without the flag the app is unchanged.
- **export** flattens each design and writes a `build.py` that adds every
  part where the design put it, its rotation made exactly orthonormal
  (brickagent's Pose refuses one off by more than 1e-8, and an LDraw line
  rounds to six places); `model.mpd` is what that build writes.
- **verify** runs their `verify.py`: part limits, BrickNet's collisions at
  1 LDU, and each connected piece under gravity in PyBullet. On their
  builds too, so the check is seen to pass what they published as valid.
- **zip** builds the submission (at most 10 MB) and runs their
  `check_submission.py`. Nothing is sent anywhere: the owner decides that.
- **fetch** downloads BrickAgent's Claude Opus 5.5 builds of the same ten
  from https://gallery.brickben.ch for comparison here only. They are not
  ours: never committed, never republished.
- **views** draws both sides with our renderer from the same four cameras,
  and **pairs** asks our pairwise judge (pairwise.py) about each prompt's
  two builds, both orders. It is our judge, not BrickBench's: their VQA
  and ELO need Gemma 4 31B in about 62 GB of GPU memory, and this machine
  has 12.9 GB.

`--upstream` is a clone of BrickAgent, `--python` a Python with brickagent
and pybullet installed (its colliders in BRICKNET_DATA). Their code and
their builds run with `python -I`, paths passed as arguments. Everything a
run makes is in the main checkout's bench/results/brickbench-<date>/,
git-ignored.
"""

from __future__ import annotations

import argparse
import datetime
import json
import lzma
import math
import os
import random
import re
import shutil
import statistics
import subprocess
import sys
import urllib.request
import zipfile
from collections.abc import Callable
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import style  # noqa: E402
from bench import judge, pairwise, suite  # noqa: E402
from bench import run as bench  # noqa: E402

SETTING = "model"
COUNT = 10
MOST_PARTS = 400
LIMIT_WORDS = "Use at most 400 pieces."
PARTS_FILE = "bricknet_parts.txt"
PARTS_NAME = "BrickNet's 14,441 parts, BrickBench's rule: no stickers, no unofficial parts"
OURS, THEIRS = "brickworks", "opus55"
SYSTEMS = {OURS: "Brickworks", THEIRS: "Claude Opus 5.5 in BrickAgent"}
# Their published Table 1 row for Opus 5.5 on the Model setting.
PUBLISHED = {"valid": 1.00, "vqa": 0.952, "design_elo": 1252, "usd": 5.90}
GALLERY = "https://gallery.brickben.ch/"
# Four cameras, the same for both sides: the two three-quarter views see every
# face between them, and front and back the elevations.
VIEWS4 = ("corner", "front", "far corner", "back")
# An LDraw entry this close to -1, 0 or 1 is that, before the rotation is squared up.
SNAP = 1e-6
AGENT = {"User-Agent": "brickworks-bench/1.0 (https://brickworks.diy)"}


def say(text: str) -> None:
    bench.say(text)


def batch_dir(date: str) -> Path:
    return bench.RESULTS / f"brickbench-{date or f'{datetime.date.today():%Y-%m-%d}'}"


# -- the prompts and the parts -------------------------------------------


def first_tasks(tasks_json: str, count: int = COUNT, start: int = 1) -> list[dict]:
    """`count` prompts of a setting from the `start`-th, in the file's order, each with its
    brief: the first ten by default, or a held-out ten (start 21) that nothing was tuned on."""
    tasks = json.loads(tasks_json)
    return [{"id": t["id"], "prompt": t["prompt"], "brief": brief_for(t["prompt"]),
             "questions": len(t.get("questions", []))} for t in tasks[start - 1:start - 1 + count]]


def brief_for(prompt: str) -> str:
    """What our designer is asked: the prompt, and the setting's limit in its own words."""
    return f"{prompt.strip()} {LIMIT_WORDS}"


def title_of(prompt: str) -> str:
    """The prompt's first sentence, for the judge's heading."""
    first = re.split(r"(?<=[.!?])\s", prompt.strip(), maxsplit=1)[0]
    return first.rstrip(".")


def parts_text(stems: list[str]) -> str:
    """The list --parts-only reads: a note naming it, then a part a line."""
    return f"# {PARTS_NAME}\n" + "".join(f"{s}\n" for s in sorted(set(stems)))


def bricknet_stems(upstream: Path) -> list[str]:
    """The parts brickagent supports: the keys of its bounds table, BrickNet's 14,441."""
    table = upstream / "src" / "brickagent" / "_data" / "v1" / "bounds.json.xz"
    return sorted(json.loads(lzma.decompress(table.read_bytes())))


def read_allowed(path: Path) -> set[str]:
    return {line.strip().lower() for line in path.read_text().splitlines()
            if line.strip() and not line.startswith("#")}


# -- the export -----------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Part:
    """One part of a flattened design, in LDraw's axes: a row-major rotation and a position."""

    stem: str
    colour: int
    rot: tuple[float, ...]
    pos: tuple[float, float, float]


def _det(m: list[list[float]]) -> float:
    return (m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
            - m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0])
            + m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]))


def _inverse_transpose(m: list[list[float]]) -> list[list[float]]:
    """The inverse's transpose: the cofactors over the determinant."""
    d = _det(m)
    cof = [[m[(i + 1) % 3][(j + 1) % 3] * m[(i + 2) % 3][(j + 2) % 3]
            - m[(i + 1) % 3][(j + 2) % 3] * m[(i + 2) % 3][(j + 1) % 3]
            for j in range(3)] for i in range(3)]
    return [[cof[i][j] / d for j in range(3)] for i in range(3)]


def _snap(value: float, within: float) -> float:
    for exact in (-1.0, 0.0, 1.0):
        if abs(value - exact) <= within:
            return exact
    return value


def orthonormality(rot: tuple[float, ...]) -> float:
    """The largest entry of R^T R - I: brickagent's Pose wants it at most 1e-8."""
    m = [rot[0:3], rot[3:6], rot[6:9]]
    worst = 0.0
    for i in range(3):
        for j in range(3):
            dot = sum(m[k][i] * m[k][j] for k in range(3))
            worst = max(worst, abs(dot - (1.0 if i == j else 0.0)))
    return worst


def orthonormal(rot: tuple[float, ...]) -> tuple[float, ...]:
    """The nearest proper rotation to an LDraw matrix, row-major.

    Entries within SNAP of -1, 0 or 1 are taken as those, so a quarter turn
    stays exact; then the polar factor by Newton's iteration, R <- (R + R^-T)/2,
    which for a matrix this near a rotation settles in a few steps. A mirror
    (negative determinant) has no rotation near it and is refused.
    """
    if len(rot) != 9 or not all(math.isfinite(v) for v in rot):
        raise ValueError("a rotation needs nine finite numbers")
    m = [[_snap(rot[3 * i + j], SNAP) for j in range(3)] for i in range(3)]
    if _det(m) <= 1e-6:
        raise ValueError(f"not a rotation (determinant {_det(m):.3g}): a mirrored or flattened part")
    for _ in range(60):
        inv_t = _inverse_transpose(m)
        nxt = [[(m[i][j] + inv_t[i][j]) / 2.0 for j in range(3)] for i in range(3)]
        moved = max(abs(nxt[i][j] - m[i][j]) for i in range(3) for j in range(3))
        m = nxt
        if moved < 1e-16:
            break
    out = tuple(_snap(m[i][j], 1e-12) for i in range(3) for j in range(3))
    if orthonormality(out) > 1e-12:
        raise ValueError("the rotation would not square up")
    return out


def flatten(text: str) -> list[Part]:
    """Every part of an LDraw model or .mpd, sub-models followed, in world LDraw axes."""
    out = []
    for placed in style.read(text).placed:
        m = placed.matrix
        out.append(Part(placed.part, int(placed.colour), (m.a, m.b, m.c, m.d, m.e, m.f, m.g, m.h, m.i),
                        (m.x, m.y, m.z)))
    return out


def _number(value: float) -> str:
    """A float as Python reads it back exactly, without a trailing .0 or -0."""
    if value == 0.0:
        return "0"
    if value == int(value) and abs(value) < 1e15:
        return str(int(value))
    return repr(value)


def build_source(task: str, prompt: str, parts: list[Part], note: str) -> str:
    """A build.py whose build() adds every part, as verify.py imports it."""
    rows = []
    for p in parts:
        rot = ", ".join(_number(v) for v in p.rot)
        pos = ", ".join(_number(v) for v in p.pos)
        rows.append(f"    ({p.stem!r}, {p.colour}, ({rot}), ({pos})),")
    head = " ".join(prompt.split())
    return "\n".join([
        f'"""{task}: {head}',
        "",
        f"{note}",
        '"""',
        "from brickagent import Assembly, Pose",
        "",
        "# (LDraw part, LDraw colour, rotation row-major, position in LDU), LDraw's axes: -y up.",
        "PARTS = [",
        *rows,
        "]",
        "",
        "",
        "def build():",
        f"    model = Assembly({task!r})",
        "    for part, colour, rot, at in PARTS:",
        "        model.add(part, pose=Pose(rot, at), color=colour)",
        "    return model",
        "",
        "",
        'if __name__ == "__main__":',
        '    build().write("model.mpd")',
        "",
    ])


def export_one(task: str, prompt: str, ldr: Path, out: Path, allowed: set[str],
               note: str, current: Callable[[str], str] = lambda stem: stem) -> dict:
    """design.ldr as out/build.py, and what stands in the way of it being valid.

    `current` gives a part's current number (style.Parts.canonical): a part
    LDraw has moved, 3023 to 3023b, is written as the number BrickNet lists,
    whose geometry the old one's stub draws."""
    parts = [Part(current(p.stem), p.colour, p.rot, p.pos) for p in flatten(ldr.read_text(errors="replace"))]
    squared, refused, moved = [], [], 0.0
    for n, p in enumerate(parts):
        try:
            rot = orthonormal(p.rot)
        except ValueError as error:
            refused.append(f"part {n} ({p.stem}): {error}")
            continue
        moved = max(moved, max(abs(a - b) for a, b in zip(rot, p.rot)))
        squared.append(Part(p.stem, p.colour, rot, p.pos))
    off = sorted({p.stem for p in parts if p.stem not in allowed})
    out.mkdir(parents=True, exist_ok=True)
    (out / "build.py").write_text(build_source(task, prompt, squared, note))
    return {"parts": len(parts), "written": len(squared), "off_list": off, "refused": refused,
            "rotation_moved": moved, "over_limit": len(parts) > MOST_PARTS}


# -- what verify.py said ----------------------------------------------------


def verify_row(report: dict) -> dict:
    """verify.py's report read into the table's columns."""
    errors = [str(e) for e in report.get("errors", [])]
    text = "\n".join(errors)
    pairs = re.search(r"(\d+) collision pairs", text)
    unstable = len(re.findall(r"unstable component", text))
    return {
        "valid": bool(report.get("valid")),
        "parts": report.get("parts"),
        "distinct": report.get("distinct_parts"),
        "components": report.get("connected_components"),
        "collisions": int(pairs.group(1)) if pairs else (0 if report.get("full_default_check") == "passed"
                                                       else None),
        "unstable": unstable,
        "stability_run": "stability not simulated" not in text,
        "reproduced": report.get("mpd_geometry_reproduced"),
        "check": report.get("full_default_check", "not run"),
        "first_error": _first_error(errors),
    }


def _first_error(errors: list[str]) -> str:
    if not errors:
        return ""
    lines = [line for line in errors[0].splitlines() if line.strip()]
    head = lines[0] if lines else errors[0]
    detail = lines[1] if len(lines) > 1 else ""
    return (head + ("; " + detail if detail else ""))[:240]


def verify_words(report: dict) -> str:
    """BrickBench's own check of one build, in words, as both sides of a pair are told it."""
    row = verify_row(report)
    if row["valid"]:
        return (f"BrickBench's verify.py: valid. {row['parts']} parts in {row['components']} "
                "connected piece(s); no collisions; every piece stands under gravity.")
    found = [f"{row['collisions']} colliding pairs" if row["collisions"] else "",
             f"{row['unstable']} piece(s) fall or slide" if row["unstable"] else "",
             "stability not simulated until the collisions are resolved"
             if not row["stability_run"] else ""]
    said = "; ".join(f for f in found if f) or row["first_error"]
    return (f"BrickBench's verify.py: not valid. {row['parts']} parts in {row['components']} "
            f"connected piece(s); {said}.")


# -- our judge across the ten -------------------------------------------------


def system_of(key: str) -> str:
    return key.split("/")[0]


def task_of(key: str) -> str:
    return key.split("/")[1]


@dataclass(frozen=True, slots=True)
class Standing:
    """Two systems on one dimension: ELO for each, 95% intervals, and the share of verdicts."""

    dim: str
    elo: dict[str, float]
    low: dict[str, float]
    high: dict[str, float]
    won: int            # verdicts our designer won
    of: int
    pairs: dict[str, int]   # prompts won in both orders, split, lost in both


def standing(verdicts: list[pairwise.Verdict], dim: str, draws: int = pairwise.DRAWS,
             seed: int = 0) -> Standing:
    """The systems' Bradley-Terry ELO over every prompt, resampling prompts for the interval.

    As BrickBench's elo.py: one fit over all the verdicts with half a virtual
    tie between the two (pairwise.fit), and 95% intervals from resampling the
    prompts with their verdicts, so a prompt's two orders stay together.
    """
    systems = [OURS, THEIRS]

    def fit(chosen: list[pairwise.Verdict]) -> dict[str, float]:
        won: dict[tuple[str, str], float] = {}
        for v in chosen:
            winner = system_of(v.winners[dim])
            loser = system_of(v.second if v.winners[dim] == v.first else v.first)
            won[(winner, loser)] = won.get((winner, loser), 0.0) + 1.0
        return {k: pairwise.elo(s) for k, s in pairwise.fit(systems, won).items()}

    point = fit(verdicts)
    by_task: dict[str, list[pairwise.Verdict]] = {}
    for v in verdicts:
        by_task.setdefault(task_of(v.first), []).append(v)
    tasks = sorted(by_task)
    rng = random.Random(f"{seed}:{dim}")
    sampled = [fit([v for _ in tasks for v in by_task[rng.choice(tasks)]]) for _ in range(draws)] \
        if tasks else []
    low = {k: pairwise._percentile([d[k] for d in sampled], 0.025) if sampled else point[k]
           for k in systems}
    high = {k: pairwise._percentile([d[k] for d in sampled], 0.975) if sampled else point[k]
            for k in systems}
    won = sum(system_of(v.winners[dim]) == OURS for v in verdicts)
    pairs = {"won": 0, "split": 0, "lost": 0}
    for task in tasks:
        share = sum(system_of(v.winners[dim]) == OURS for v in by_task[task]) / len(by_task[task])
        pairs["won" if share == 1 else "lost" if share == 0 else "split"] += 1
    return Standing(dim, point, low, high, won, len(verdicts), pairs)


# -- the stages -----------------------------------------------------------------


def _upstream(args: argparse.Namespace) -> Path:
    found = args.upstream or os.environ.get("BRICKAGENT_DIR", "")
    if not found or not (Path(found) / "scripts" / "verify.py").exists():
        raise SystemExit("--upstream: a clone of https://github.com/kulits/BrickAgent "
                         "(or BRICKAGENT_DIR)")
    return Path(found).resolve()


def _python(args: argparse.Namespace) -> str:
    found = args.python or os.environ.get("BRICKAGENT_PYTHON", "")
    if not found or not Path(found).exists():
        raise SystemExit("--python: a Python with brickagent and pybullet (or BRICKAGENT_PYTHON)")
    return found


def _tasks(batch: Path, wanted: str) -> list[dict]:
    listed = batch / "prompts.json"
    if not listed.exists():
        raise SystemExit(f"no {listed}: run `prompts` first")
    tasks = json.loads(listed.read_text())
    names = [t.strip() for t in wanted.split(",") if t.strip()]
    return [t for t in tasks if not names or t["id"] in names]


def subject_for(task: dict) -> suite.Subject:
    return suite.Subject(task["id"], title_of(task["prompt"]), task["brief"],
                         f"at most {MOST_PARTS} pieces (BrickBench's Model setting)", "other")


def do_prompts(args: argparse.Namespace, batch: Path) -> int:
    upstream = _upstream(args)
    tasks = first_tasks((upstream / "benchmark" / SETTING / "tasks.json").read_text(), COUNT, args.start)
    batch.mkdir(parents=True, exist_ok=True)
    commit = subprocess.run(["git", "-C", str(upstream), "rev-parse", "--short", "HEAD"],
                            capture_output=True, text=True).stdout.strip()
    bench._write_json(batch / "prompts.json", tasks)
    chosen = ("the first ten, in file order" if args.start == 1
              else f"ten from {tasks[0]['id'] if tasks else args.start}, in file order, held out")
    bench._write_json(batch / "upstream.json", {"repository": "https://github.com/kulits/BrickAgent",
                                                 "commit": commit, "chosen": chosen})
    for t in tasks:
        print(f"{t['id']}  {t['prompt']}")
    return 0


def do_parts(args: argparse.Namespace, batch: Path) -> int:
    stems = bricknet_stems(_upstream(args))
    batch.mkdir(parents=True, exist_ok=True)
    (batch / PARTS_FILE).write_text(parts_text(stems))
    print(f"{len(stems)} parts -> {batch / PARTS_FILE}")
    return 0


def do_design(args: argparse.Namespace, batch: Path) -> int:
    if not os.environ.get("XDG_DATA_HOME"):
        raise SystemExit("set XDG_DATA_HOME to a scratch folder: a design run's saves must not "
                         "land among the owner's models")
    parts = batch / PARTS_FILE
    if not parts.exists():
        raise SystemExit(f"no {parts}: run `parts` first")
    tasks = _tasks(batch, args.tasks)
    app = Path(args.app).resolve() if args.app else bench.ROOT
    if not (app / "project.godot").exists():
        raise SystemExit(f"--app {app}: not a checkout of the app")
    jobs = [(task, run_dir) for task in tasks for run_dir in _run_dirs(batch, args.arm, task["id"], args.runs)]

    def one(job: tuple[dict, Path]) -> str:
        task, run_dir = job
        run_dir.mkdir(parents=True, exist_ok=True)
        named = f"{task['id']}" + (f" {args.arm} {run_dir.name}" if args.arm else "")
        try:
            made = bench.design(subject_for(task), run_dir, args.timeout, None,
                                extra=(f"--parts-only={parts}",), app=app)
        except SystemExit as stopped:
            return f"{named}: {stopped}"
        log = (run_dir / "design.log").read_text(errors="replace") if (run_dir / "design.log").exists() else ""
        took = "parts only" in log
        return (f"{named}: {'a model' if made.get('model') else 'NO MODEL'}, "
                f"{made.get('design_seconds')} s, list {'taken' if took else 'NOT TAKEN'}")

    # Each prompt's first design before any prompt's second: a batch stopped
    # part way still has one design of every prompt.
    jobs.sort(key=lambda job: (job[1].name, job[0]["id"]) if args.arm else (job[0]["id"], ""))
    with ThreadPoolExecutor(max_workers=max(1, min(2, args.jobs))) as workers:
        for line in workers.map(one, jobs):
            say(line)
    return 0


def _run_dirs(batch: Path, arm: str, task: str, runs: int) -> list[Path]:
    """Where a prompt's designs go: ours/<task> for the one design of the first
    batch, or arms/<arm>/<task>/run<n> for each design of a comparison's arm."""
    if not arm:
        return [batch / "ours" / task]
    return [batch / "arms" / arm / task / f"run{n}" for n in range(1, runs + 1)]


def _side_dirs(batch: Path, arm: str, task: str, runs: int) -> list[tuple[str, Path]]:
    """Each design of a prompt as (side, run folder): the side names it in views and pairs."""
    if not arm:
        return [(OURS, batch / "ours" / task)]
    return [(f"{arm}-{d.name}", d) for d in _run_dirs(batch, arm, task, runs)]


def _note(run_dir: Path) -> str:
    made = run_dir / "design.json"
    commit = json.loads(made.read_text()).get("commit", "?") if made.exists() else "?"
    return (f"Brickworks' designer (https://brickworks.diy), commit {commit}, exported by "
            "tools/bench/brickbench.py: every part where\nthe design put it, each rotation "
            "made orthonormal for brickagent's Pose.")


def _submission(batch: Path, run_dir: Path, task: str) -> Path:
    """Where a design's build.py and model.mpd go: the first batch's submission
    folder, or beside the design in a comparison's arm."""
    return batch / "submission" / task if run_dir.parent.name == "ours" else run_dir / "submission"


def do_export(args: argparse.Namespace, batch: Path) -> int:
    python = _python(args)
    allowed = read_allowed(batch / PARTS_FILE)
    known = style.Parts()
    for task in _tasks(batch, args.tasks):
        for side, run_dir in _side_dirs(batch, args.arm, task["id"], args.runs):
            named = task["id"] + ("" if side == OURS else f" {side}")
            ldr = run_dir / "design.ldr"
            out = _submission(batch, run_dir, task["id"])
            if not ldr.exists():
                say(f"{named}: no design")
                continue
            found = export_one(task["id"], task["prompt"], ldr, out, allowed, _note(run_dir), known.canonical)
            # The model.mpd is the one the build writes, so verify.py finds them the same.
            wrote = subprocess.run([python, "-I", str(out / "build.py")], cwd=out, capture_output=True,
                                   text=True, env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
            found["mpd"] = (out / "model.mpd").exists() and wrote.returncode == 0
            found["mpd_error"] = wrote.stderr.strip()[-400:] if wrote.returncode else ""
            bench._write_json(run_dir / "export.json", found)
            say(f"{named}: {found['parts']} parts, off the list {found['off_list'] or 'none'}, "
                f"rotations moved at most {found['rotation_moved']:.2g}, "
                f"{'model.mpd written' if found['mpd'] else 'NO model.mpd: ' + found['mpd_error'][-160:]}")
    return 0


def do_verify(args: argparse.Namespace, batch: Path) -> int:
    upstream, python = _upstream(args), _python(args)
    if not os.environ.get("BRICKNET_DATA"):
        raise SystemExit("set BRICKNET_DATA to where `python -m bricknet fetch-meshes` put the colliders")
    which = [w.strip() for w in args.which.split(",") if w.strip()]
    for task in _tasks(batch, args.tasks):
        mine = [(side, _submission(batch, run_dir, task["id"]))
                for side, run_dir in _side_dirs(batch, args.arm, task["id"], args.runs)]
        for side, folder in [*mine, ("theirs", batch / "theirs" / task["id"])]:
            wanted = "theirs" if side == "theirs" else "ours"
            if wanted not in which or not (folder / "build.py").exists():
                continue
            if (folder / "verification.json").exists() and args.arm:
                continue
            ran = subprocess.run([bench.HEAVY, python, "-I", str(upstream / "scripts" / "verify.py"),
                                  str(folder), "--split", SETTING], capture_output=True, text=True,
                                 env={**os.environ, "PYTHONDONTWRITEBYTECODE": "1"})
            (folder / "verify.log").write_text(ran.stderr[-20000:])
            report = folder / "verification.json"
            if not report.exists():
                say(f"{task['id']} {side}: verify.py wrote nothing (exit {ran.returncode})")
                continue
            row = verify_row(json.loads(report.read_text()))
            say(f"{task['id']} {side}: {'valid' if row['valid'] else 'NOT valid'}, {row['parts']} parts, "
                f"{row['components']} pieces, {row['collisions']} collisions, {row['unstable']} unstable"
                + (f" — {row['first_error'][:140]}" if row["first_error"] else ""))
    return 0


def do_zip(args: argparse.Namespace, batch: Path) -> int:
    upstream = _upstream(args)
    out = batch / "submission.zip"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
        for task in _tasks(batch, args.tasks):
            folder = batch / "submission" / task["id"]
            for name in ("build.py", "model.mpd"):
                if (folder / name).exists():
                    archive.write(folder / name, f"{task['id']}/{name}")
    ran = subprocess.run([sys.executable, "-I", str(upstream / "scripts" / "check_submission.py"),
                          str(out)], capture_output=True, text=True)
    said = (ran.stdout + ran.stderr).strip()
    (batch / "check_submission.txt").write_text(f"exit {ran.returncode}\n{said}\n")
    print(f"{out} ({out.stat().st_size / 1e6:.2f} MB)\n{said}\ncheck_submission.py exit {ran.returncode}")
    print("Not submitted: the owner decides that.")
    return ran.returncode


def _gallery_entries() -> tuple[dict, dict]:
    request = urllib.request.Request(GALLERY, headers=AGENT)
    page = urllib.request.urlopen(request, timeout=120).read().decode()
    found = re.search(r'<script id="payload" type="application/json">(.*?)</script>', page, re.S)
    if not found:
        raise SystemExit("the gallery page has no payload")
    data = json.loads(found.group(1))
    entries = {}
    for task in data["tasks"]:
        for shown in task["renders"]:
            if shown["system"] == THEIRS:
                entries[task["task"]] = shown
    return data.get("origins", {}), entries


def _asset(origins: dict, path: str) -> str:
    head, rest = path.split("/", 1)
    return f"{origins.get(head, GALLERY.rstrip('/') + '/' + head)}/{rest}?v=1"


def do_fetch(args: argparse.Namespace, batch: Path) -> int:
    origins, entries = _gallery_entries()
    for task in _tasks(batch, args.tasks):
        shown = entries.get(task["id"])
        if shown is None:
            say(f"{task['id']}: not in the gallery")
            continue
        into = batch / "theirs" / task["id"]
        into.mkdir(parents=True, exist_ok=True)
        bench._write_json(into / "gallery.json", shown)
        wanted = [(shown["file"], "model.mpd"), (shown["script"], "build.py")]
        wanted += [(f"{shown['views']}{n}.avif", f"view{n}.avif") for n in range(int(shown.get("nviews", 8)))]
        for path, name in wanted:
            if not (into / name).exists():
                bench._fetch(_asset(origins, path), into / name)
        say(f"{task['id']}: {shown['parts']} parts, published {shown['verdict']}")
    return 0


def _model_of(batch: Path, side: str, task: str) -> Path:
    if side in (OURS, THEIRS):
        return batch / ("submission" if side == OURS else "theirs") / task / "model.mpd"
    arm, run = side.rsplit("-", 1)
    return batch / "arms" / arm / task / run / "submission" / "model.mpd"


def views_of(batch: Path, side: str, task: str) -> tuple[Path, ...]:
    return tuple(batch / "views" / side / f"{task}_{v}.png" for v in VIEWS4)


def sides_of(args: argparse.Namespace) -> list[str]:
    """The builds of each prompt to draw and judge: ours and theirs, or each
    design of each arm named in --arms, and theirs."""
    arms = [a.strip() for a in args.arms.split(",") if a.strip()]
    if not arms:
        return [OURS, THEIRS]
    return [f"{arm}-run{n}" for arm in arms for n in range(1, args.runs + 1)] + [THEIRS]


def arm_of(side: str) -> str:
    """A design's arm: brickworks or opus55 as they are, an arm's run without its number."""
    return side if side in (OURS, THEIRS) else side.rsplit("-", 1)[0]


def do_views(args: argparse.Namespace, batch: Path) -> int:
    """Both sides of every prompt by one renderer: on the GPU one at a time, or
    with --software on lavapipe, --jobs at once (at most two)."""
    def draw(job: tuple[dict, str]) -> str:
        task, side = job
        model = _model_of(batch, side, task["id"])
        if not model.exists():
            return f"{task['id']} {side}: no model.mpd"
        prefix = batch / "views" / side / task["id"]
        drawn = bench.render(model, prefix, prefix.with_name(f"{task['id']}_render.log"),
                             software=args.software, views=VIEWS4)
        return f"{task['id']} {side}: {len(drawn)} of {len(VIEWS4)} views"

    jobs = [(task, side) for task in _tasks(batch, args.tasks) for side in sides_of(args)]
    with ThreadPoolExecutor(max_workers=max(1, min(2, args.jobs)) if args.software else 1) as workers:
        for line in workers.map(draw, jobs):
            say(line)
    return 0


def _shown(key: str, views: tuple[Path, ...], parts: int, words: str, into: Path) -> pairwise.Shown:
    """A build's four pictures copied under a name that says nothing of who made it."""
    code = pairwise.opaque(key)
    into.mkdir(parents=True, exist_ok=True)
    pictures = []
    for view, source in zip(VIEWS4, views):
        out = into / f"{code}_{view.replace(' ', '_')}.png"
        if not out.exists() or out.stat().st_size != source.stat().st_size:
            shutil.copyfile(source, out)
        pictures.append(judge.Picture(out, f"{view} view"))
    return pairwise.Shown(tuple(pictures), parts, words)


def _verification(batch: Path, side: str, task: str) -> dict:
    found = _model_of(batch, side, task).parent / "verification.json"
    return json.loads(found.read_text()) if found.exists() else {}


def do_pairs(args: argparse.Namespace, batch: Path) -> int:
    """Every two builds of a prompt, both orders, `--repeat` times: ours against
    theirs, or with --arms every design of every arm against each other and theirs."""
    asks = []
    for task in _tasks(batch, args.tasks):
        sides = {}
        for side in sides_of(args):
            views = views_of(batch, side, task["id"])
            report = _verification(batch, side, task["id"])
            if not all(v.exists() for v in views) or not report:
                say(f"{task['id']} {side}: no views or no verification yet")
                continue
            key = f"{side}/{task['id']}"
            sides[side] = (key, _shown(key, views, int(report.get("parts") or 0),
                                       verify_words(report), batch / "pairwise" / task["id"] / "designs"))
        if len(sides) < 2 or (not args.arms and len(sides) < len(sides_of(args))):
            continue
        subject = subject_for(task)
        where = batch / "pairwise" / task["id"]
        shown = list(sides.values())
        for repeat in range(1, args.repeat + 1):
            for i, x in enumerate(shown):
                for y in shown[i + 1:]:
                    for a, b in ((x, y), (y, x)):
                        asks.append((subject, where, [], a, b, repeat, None, args.judge_model))
    say(f"pairs: {len(asks)} ordered judgements")
    found = bench._ask_all(asks, args.jobs)
    say(f"pairs: {len(found)} verdicts")
    return 0


def _verdicts(batch: Path) -> list[pairwise.Verdict]:
    out = []
    for path in sorted((batch / "pairwise").glob("*/judged/*.json")):
        out.append(pairwise.Verdict.from_dict(json.loads(path.read_text())))
    return out


def _session(log: str) -> dict:
    """What a design's log says it took and spent (src/main.gd's last lines)."""
    found: dict = {}
    took = re.search(r"claude code ok=(\w+) bricks=(\d+)\s+\((\d+)s\)", log)
    if took:
        found.update(ok=took.group(1) == "true", bricks=int(took.group(2)), seconds=int(took.group(3)))
    spent = re.search(r"tokens fresh=(\d+) written=(\d+) cached=(\d+) out=(\d+) api_usd=([\d.]+)", log)
    if spent:
        found.update(fresh=int(spent.group(1)), written=int(spent.group(2)), cached=int(spent.group(3)),
                     out=int(spent.group(4)), api_usd=float(spent.group(5)))
    replies = re.search(r"the session spent .* over (\d+) replies", log)
    if replies:
        found["replies"] = int(replies.group(1))
    found["refused_off_list"] = len(re.findall(r"not among this run's parts", log))
    return found


def report(batch: Path) -> str:
    tasks = json.loads((batch / "prompts.json").read_text())
    out = ["### The ten prompts", "", "| task | prompt |", "|---|---|"]
    out += [f"| {t['id']} | {t['prompt']} |" for t in tasks]
    out += ["", "### verify.py on each build", "",
            "Ours as submitted; theirs as the gallery has them, checked again here with the same "
            "verify.py and colliders.", "",
            "| task | ours: valid | parts | pieces | collisions | unstable | theirs: valid | parts | "
            "pieces | why ours is not valid |", "|---|---|---|---|---|---|---|---|---|---|"]
    valid = {OURS: 0, THEIRS: 0}
    for t in tasks:
        a, b = (verify_row(_verification(batch, s, t["id"])) for s in (OURS, THEIRS))
        valid[OURS] += a["valid"]
        valid[THEIRS] += b["valid"]
        out.append(f"| {t['id']} | {'yes' if a['valid'] else '**no**'} | {a['parts']} | {a['components']} | "
                   f"{a['collisions']} | {a['unstable']} | {'yes' if b['valid'] else 'no'} | {b['parts']} | "
                   f"{b['components']} | {a['first_error'].replace('|', '/')[:160]} |")
    sessions = []
    for t in tasks:
        log = batch / "ours" / t["id"] / "design.log"
        sessions.append(_session(log.read_text(errors="replace")) if log.exists() else {})
    usd = [s["api_usd"] for s in sessions if "api_usd" in s]
    secs = [s["seconds"] for s in sessions if "seconds" in s]
    out += ["", "### Beside their Table 1", "",
            "| system | valid | VQA | Design ELO | cost a build | time a build |", "|---|---|---|---|---|---|",
            f"| Claude Opus 5.5 in BrickAgent, published (100 prompts) | {PUBLISHED['valid']:.2f} | "
            f"{PUBLISHED['vqa']:.3f} | {PUBLISHED['design_elo']} | ${PUBLISHED['usd']:.2f} | |",
            f"| Their builds of these ten, verify.py here | {valid[THEIRS] / len(tasks):.2f} | | | | |",
            f"| Brickworks, these ten | {valid[OURS] / len(tasks):.2f} | not run | not run | "
            + (f"${sum(usd) / len(usd):.2f} at API prices; $0 billed |" if usd else "|")
            + (f" {sum(secs) / len(secs) / 60:.0f} min |" if secs else " |")]
    out += ["", "| task | minutes | replies | tokens in (cached) | out | API price | refusals off the list |",
            "|---|---|---|---|---|---|---|"]
    for t, s in zip(tasks, sessions):
        total_in = s.get("fresh", 0) + s.get("written", 0) + s.get("cached", 0)
        out.append(f"| {t['id']} | {s.get('seconds', 0) / 60:.0f} | {s.get('replies', '')} | "
                   f"{total_in / 1e6:.1f}M ({s.get('cached', 0) / 1e6:.1f}M) | {s.get('out', 0) / 1e3:.0f}k | "
                   f"${s.get('api_usd', 0):.2f} | {s.get('refused_off_list', 0)} |")
    said = _verdicts(batch)
    if said:
        out += ["", f"### Our pairwise judge: {len(said)} verdicts", "",
                "Bradley-Terry over the ten prompts, 95% intervals from resampling prompts. Our "
                "judge, not BrickBench's.", "",
                "| dimension | Brickworks ELO (95%) | Opus 5.5 ELO (95%) | verdicts for Brickworks | "
                "prompts won both orders / split / lost |", "|---|---|---|---|---|"]
        for dim in pairwise.DIMENSIONS:
            st = standing(said, dim)
            low, high = pairwise.wilson(st.won, st.of)
            out.append(f"| {dim} | {st.elo[OURS]:.0f} ({st.low[OURS]:.0f}-{st.high[OURS]:.0f}) | "
                       f"{st.elo[THEIRS]:.0f} ({st.low[THEIRS]:.0f}-{st.high[THEIRS]:.0f}) | "
                       f"{pairwise.share(st.won, st.of)}, 95% {100 * low:.0f}-{100 * high:.0f}% | "
                       f"{st.pairs['won']} / {st.pairs['split']} / {st.pairs['lost']} |")
        out += ["", "| task | overall: verdicts for Brickworks | the judge's reasons, overall |", "|---|---|---|"]
        for t in tasks:
            mine = [v for v in said if task_of(v.first) == t["id"]]
            if not mine:
                continue
            won = sum(system_of(v.winners["overall"]) == OURS for v in mine)
            reasons = " / ".join(
                f"({'ours first' if system_of(v.first) == OURS else 'theirs first'}) "
                + v.reasons.get("overall", "") for v in mine[:2])
            out.append(f"| {t['id']} | {won} of {len(mine)} | {reasons.replace('|', '/')[:600]} |")
    return "\n".join(out) + "\n"


# -- a comparison of arms -------------------------------------------------------


# A figure's parts, which the style measures leave out and a character is built of.
FIGURE = re.compile(r"^(minifig|figure|animal)", re.I)
# A brick or a plate with nothing to its shape but its outline, studs up: what a
# statue is stacked from. A round brick or a round plate with a hole counts; a
# curved slope, a wedge or a part with a clip, a bar or a side stud does not.
STACKED = re.compile(r"^(brick|plate)\b(?!.*(slope|wedge|curved|hinge|bracket|technic|modified|side|clip|"
                     r"bar|handle|pin|axle|ball|socket|door|window|lamp|light|wheel|ladder|rail|tooth|"
                     r"grille|masonry|log|profile))", re.I)


def vocabulary(model: Path, parts: "style.Parts") -> dict:
    """What a build is made of and how big it is: the share of its building parts
    stacked studs-up (STACKED), plain, shaped (a curve, a slope or at an angle), a
    tile, a clip, bar, hinge or ball; its figure parts; its size; any baseplate."""
    read = style.read(model.read_text(errors="replace"))
    built, figures, stacked, plain, shaped, tile, joints, bases = 0, 0, 0, 0, 0, 0, 0, []
    low, high = [math.inf] * 3, [-math.inf] * 3
    for placed in read.placed:
        info = parts.get(placed.part, read.embedded)
        if info is None:
            continue
        if info.box is not None:
            m = placed.matrix
            rows = ((m.a, m.b, m.c, m.x), (m.d, m.e, m.f, m.y), (m.g, m.h, m.i, m.z))
            for corner in [(x, y, z) for x in (info.box[0][0], info.box[1][0])
                           for y in (info.box[0][1], info.box[1][1]) for z in (info.box[0][2], info.box[1][2])]:
                at = [r[0] * corner[0] + r[1] * corner[1] + r[2] * corner[2] + r[3] for r in rows]
                low = [min(a, b) for a, b in zip(low, at)]
                high = [max(a, b) for a, b in zip(high, at)]
        if FIGURE.match(info.category) or FIGURE.match(info.name):
            figures += 1
            continue
        if info.category.lower() == "baseplate" or info.name.lower().startswith("baseplate"):
            bases.append(info.name)
        built += 1
        kinds = style.kinds(info)
        stacked += bool(STACKED.match(info.name)) and style.facing(placed.matrix) == "up"
        plain += "plain" in kinds
        shaped += bool(kinds & {"curve", "slope"}) or style.angled(placed.matrix)
        tile += "tile" in kinds
        joints += "angle_parts" in kinds

    def share(n: int) -> float:
        return round(n / built, 3) if built else 0.0

    size = [round((h - lo) / unit, 1) if h > lo else 0.0 for lo, h, unit in zip(low, high, (20, 8, 20))]
    return {"parts": built + figures, "figure_parts": figures, "stacked": share(stacked), "plain": share(plain),
            "shaped": share(shaped), "tile": share(tile), "joints": share(joints),
            "across": max(size[0], size[2]), "deep": min(size[0], size[2]), "tall_plates": size[1],
            "baseplate": bases[0] if bases else ""}


# The measures of `vocabulary` that are shares of a build's building parts.
SHARES = ("stacked", "plain", "shaped", "tile", "joints")


@dataclass(frozen=True, slots=True)
class Field:
    """Several arms on one dimension: ELO with 95% intervals, prompts resampled."""

    dim: str
    elo: dict[str, float]
    low: dict[str, float]
    high: dict[str, float]


def field_of(verdicts: list[pairwise.Verdict], dim: str, arms: list[str], draws: int = pairwise.DRAWS,
             seed: int = 0) -> Field:
    """Bradley-Terry over arms, as BrickBench's elo.py fits systems: each verdict a
    game between the two designs' arms (two designs of one arm are not a game),
    half a virtual tie between every two, and the prompts resampled with all their
    verdicts for the interval, so a prompt's designs and orders stay together."""
    def fit(chosen: list[pairwise.Verdict]) -> dict[str, float]:
        won: dict[tuple[str, str], float] = {}
        for v in chosen:
            winner = arm_of(system_of(v.winners[dim]))
            loser = arm_of(system_of(v.second if v.winners[dim] == v.first else v.first))
            if winner != loser:
                won[(winner, loser)] = won.get((winner, loser), 0.0) + 1.0
        return {k: pairwise.elo(s) for k, s in pairwise.fit(arms, won).items()}

    point = fit(verdicts)
    by_task: dict[str, list[pairwise.Verdict]] = {}
    for v in verdicts:
        by_task.setdefault(task_of(v.first), []).append(v)
    tasks = sorted(by_task)
    rng = random.Random(f"{seed}:{dim}")
    sampled = [fit([v for _ in tasks for v in by_task[rng.choice(tasks)]]) for _ in range(draws)] if tasks else []
    low = {k: pairwise._percentile([d[k] for d in sampled], 0.025) if sampled else point[k] for k in arms}
    high = {k: pairwise._percentile([d[k] for d in sampled], 0.975) if sampled else point[k] for k in arms}
    return Field(dim, point, low, high)


def head_to_head(verdicts: list[pairwise.Verdict], dim: str, a: str, b: str) -> tuple[int, int, dict]:
    """Of the verdicts between arm a's designs and arm b's: how many went to a, of
    how many, and the prompts a won every time, split, or lost every time."""
    mine = [v for v in verdicts if {arm_of(system_of(v.first)), arm_of(system_of(v.second))} == {a, b}]
    won = sum(arm_of(system_of(v.winners[dim])) == a for v in mine)
    tally = {"won": 0, "split": 0, "lost": 0}
    for task in sorted({task_of(v.first) for v in mine}):
        here = [v for v in mine if task_of(v.first) == task]
        got = sum(arm_of(system_of(v.winners[dim])) == a for v in here)
        tally["won" if got == len(here) else "lost" if got == 0 else "split"] += 1
    return won, len(mine), tally


def compare(batch: Path, arms: list[str], runs: int) -> str:
    """The comparison's tables: each arm's ELO among the arms and theirs, every two
    arms head to head, and what each arm's builds are made of."""
    tasks = json.loads((batch / "prompts.json").read_text())
    sides = [f"{arm}-run{n}" for arm in arms for n in range(1, runs + 1)]
    systems = [*arms, THEIRS]
    said = [v for v in _verdicts(batch)
            if arm_of(system_of(v.first)) in systems and arm_of(system_of(v.second)) in systems]
    out = [f"### {len(said)} verdicts over {len({task_of(v.first) for v in said})} prompts", "",
           "Bradley-Terry over the arms (two designs of one arm are not a game), half a virtual tie "
           "between every two, 95% intervals from resampling the prompts with all their verdicts. "
           "Our judge, not BrickBench's.", "",
           "| dimension | " + " | ".join(f"{s} ELO (95%)" for s in systems) + " |",
           "|---|" + "---|" * len(systems)]
    for dim in pairwise.DIMENSIONS:
        found = field_of(said, dim, systems)
        out.append(f"| {dim} | " + " | ".join(
            f"{found.elo[s]:.0f} ({found.low[s]:.0f}-{found.high[s]:.0f})" for s in systems) + " |")
    out += ["", "| pair | dimension | verdicts for the first | 95% | prompts won every time / split / lost |",
            "|---|---|---|---|---|"]
    for i, a in enumerate(systems):
        for b in systems[i + 1:]:
            for dim in ("overall", "technique", "likeness", "surface"):
                won, of, tally = head_to_head(said, dim, a, b)
                if not of:
                    continue
                lo, hi = pairwise.wilson(won, of)
                out.append(f"| {a} vs {b} | {dim} | {pairwise.share(won, of)} | {100 * lo:.0f}-{100 * hi:.0f}% | "
                           f"{tally['won']} / {tally['split']} / {tally['lost']} |")
    known = style.Parts()
    keys = ["parts", "figure_parts", "stacked", "plain", "shaped", "tile", "joints", "across", "tall_plates"]
    out += ["", "What each arm's builds are made of, the median over its designs (stacked: building parts that "
            "are a brick or a plate of any outline, studs up; shaped: a curve, a slope or at an angle; "
            "joints: a clip, bar, hinge or ball; across in studs):", "",
            "| arm | designs | valid (verify.py) | baseplates | " + " | ".join(keys) + " |",
            "|---|---|---|---|" + "---|" * len(keys)]
    for system in systems:
        mine = [s for s in [*sides, THEIRS] if arm_of(s) == system]
        rows, valid = [], 0
        for task in tasks:
            for side in mine:
                model = _model_of(batch, side, task["id"])
                if model.exists():
                    rows.append(vocabulary(model, known))
                    valid += bool(_verification(batch, side, task["id"]).get("valid"))
        if not rows:
            continue
        medians = {k: statistics.median([r[k] for r in rows]) for k in keys}
        out.append(f"| {system} | {len(rows)} | {valid} | {sum(bool(r['baseplate']) for r in rows)} | "
                   + " | ".join(f"{100 * medians[k]:.0f}%" if k in SHARES else f"{medians[k]:g}"
                                for k in keys) + " |")
    return "\n".join(out) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", choices=["prompts", "parts", "design", "export", "verify", "zip", "fetch",
                                         "views", "pairs", "report", "compare"])
    parser.add_argument("--date", default="", help="the batch: bench/results/brickbench-<date>")
    parser.add_argument("--upstream", default="", help="a clone of BrickAgent")
    parser.add_argument("--python", default="", help="a Python with brickagent and pybullet")
    parser.add_argument("--tasks", default="", help="task ids, comma-separated; all ten if not said")
    parser.add_argument("--skip", type=int, default=0,
                        help="prompts: the ten after the first SKIP (10: model-011 to model-020); --start SKIP+1")
    parser.add_argument("--jobs", type=int, default=2, help="designs (at most 2) or judge calls at once")
    parser.add_argument("--timeout", type=int, default=2700, help="seconds a design may take")
    parser.add_argument("--which", default="ours,theirs", help="verify: ours, theirs or both")
    parser.add_argument("--software", action="store_true", help="views: on lavapipe under heavy")
    parser.add_argument("--repeat", type=int, default=1, help="pairs: ask every pair this many times")
    parser.add_argument("--judge-model", default="opus")
    parser.add_argument("--out", type=Path, default=None, help="report: also write it here")
    parser.add_argument("--start", type=int, default=1, help="prompts: the first prompt's place in the file")
    parser.add_argument("--arm", default="", help="design, export, verify: one arm of a comparison")
    parser.add_argument("--arms", default="", help="views, pairs, compare: the arms, comma-separated")
    parser.add_argument("--runs", type=int, default=1, help="designs a prompt in each arm")
    parser.add_argument("--app", default="", help="design: the checkout whose app designs (this one)")
    args = parser.parse_args()
    # Two ways of saying where the ten start, from two units merged together:
    # --skip N is the ten after the first N, the same as --start N+1.
    if args.skip and args.start == 1:
        args.start = args.skip + 1
    batch = batch_dir(args.date)
    stages = {"prompts": do_prompts, "parts": do_parts, "design": do_design, "export": do_export,
              "verify": do_verify, "zip": do_zip, "fetch": do_fetch, "views": do_views, "pairs": do_pairs}
    if args.what in stages:
        return stages[args.what](args, batch)
    arms = [a.strip() for a in args.arms.split(",") if a.strip()]
    text = compare(batch, arms, args.runs) if args.what == "compare" else report(batch)
    (batch / ("compare.md" if args.what == "compare" else "report.md")).write_text(text)
    if args.out is not None:
        args.out.write_text(text)
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
