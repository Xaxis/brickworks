#!/usr/bin/env python3
"""Simulate measured on real sets' functions, beside Kinebrick's (docs/APP_UX8.md, kinefuncs).

    tools/kinefuncs.py fetch                   Kinebrick at its pinned commit, and each set's OMR file
    tools/kinefuncs.py jobs                    every function's parts, read from its model as Kinebrick reads them
    tools/kinefuncs.py run LABEL [--jobs=N] [--only=SET,...] [--timeout=S] [--app=DIR] [--dump] [--drag]
                                               drive each function in Simulate, in the app, headless;
                                               --dump writes each set's gear reading to OUT/kinefuncs_LABEL_dump/;
                                               --drag drives each control by move_part's drag too
    tools/kinefuncs.py table LABEL [--against=LABEL] [--write]
                                               the table, beside Kinebrick's; --write puts it in docs/KINEFUNCS.md

Kinebrick (github.com/erik-larsen/kinebrick, MIT; its data CC BY-SA 4.0) lists, for each of 186
LEGO Technic sets in LDraw's Official Model Repository, what each of the set's controls does, read
from the set's instructions: the part a person turns or pushes (`control`), the parts that must
move with it (`moves`), those that must not (`stays`), each against the frame or a part named, and
controls to work first (`first`). It checks each with its own drags and writes what it found into
the set's `generated`. This reads the same lists, at the commit pinned below, and drives each
function in Brickworks' Simulate as a person does: the model opened (File, Open), the control's
part picked as the driver, and the driver turned 1.5 radians each way (Kinebrick's REACH). A part
moved when it went 1 LDU or turned 1 degree against what it is measured against (Kinebrick's
MOVED). A function works when, for each of its controls, one way went at least half as far as it
was worked, with every part in `moves` moving and none in `stays`; partly when something moved;
no when nothing did. A control that slides is pushed 20 LDU each way (Kinebrick's PUSH). The rules
are Kinebrick's own (scripts/check-functions.ts), so the two columns are read alike.

A part is named as Kinebrick names it: `p` and its place among the model's parts in file order,
submodels read where their line is, LDraw primitives left out and the parts Kinebrick reads as
their pieces (packed/pieces.json: a 4 x 4 turntable is a base and a top) read so. `jobs` reads each
model so, checks every name against the part there, and hands the probe where each part stands;
the probe finds the brick standing there in the model as the app opened it. A set's model is the
file Kinebrick checks: the OMR's at the version its CSV pins, or Kinebrick's own corrected copy in
its models/ (each correction commented there).

`run` opens each set in the app, headless (src/dev/kinefuncs_probe.gd -- --functions=... --rows=...), sets shared
among --jobs processes, each under ~/.claude/claude-core/bin/heavy with a data folder of its own;
a set that takes longer than --timeout seconds (1800, Kinebrick's 30 minutes) is stopped and said
so, and its process goes on from the next set. --app names the checkout to run (a locked snapshot;
default this one). Rows go to OUT/kinefuncs_LABEL.jsonl and the table to kinefuncs_LABEL.md, OUT
being bench/results/kinefuncs-2026-11-09 or the folder KINEFUNCS_OUT names. Kinebrick's files are
kept in bench/data/kinebrick, or the folder KINEFUNCS_DATA names.
"""

from __future__ import annotations

import csv
import json
import os
import re
import signal
import subprocess
import sys
import threading
import time
import urllib.request
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAIN = Path("/mnt/Projects/brickworks")
DATA = Path(os.environ.get("KINEFUNCS_DATA", str((MAIN if MAIN.exists() else ROOT) / "bench" / "data" / "kinebrick")))
OUT = Path(os.environ.get("KINEFUNCS_OUT", str((MAIN if MAIN.exists() else ROOT) / "bench" / "results"
                                               / "kinefuncs-2026-11-09")))
HEAVY = Path.home() / ".claude" / "claude-core" / "bin" / "heavy"
REPO = "https://github.com/erik-larsen/kinebrick.git"
# Kinebrick's main on 2026-11-09: its README counts 517 functions working of 1,224 (42%); its
# sets' own generated results, some checked again since, 522.
PIN = "f46de815366d47de1231b92af63831ce7bb9a9aa"
DOC = ROOT / "docs" / "KINEFUNCS.md"
RESULTS = ("works", "partly", "no", "skipped", "not checked", "error", "timed out")


# -- fetching ---------------------------------------------------------------------------------


def _checkout() -> Path:
    return DATA / "repo"


def fetch() -> int:
    repo = _checkout()
    DATA.mkdir(parents=True, exist_ok=True)
    if not (repo / ".git").exists():
        subprocess.run(["git", "clone", "--quiet", "--no-checkout", "--filter=blob:none", REPO, str(repo)], check=True)
    head = subprocess.run(["git", "-C", str(repo), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    if head != PIN:
        subprocess.run(["git", "-C", str(repo), "fetch", "--quiet", "origin", PIN], check=True)
    if head != PIN or not (repo / "models" / "technic-sets.csv").exists():
        subprocess.run(["git", "-C", str(repo), "-c", "advice.detachedHead=false", "checkout", "--quiet", PIN],
                       check=True)
    omr = DATA / "omr"
    omr.mkdir(exist_ok=True)
    pins = {row["set_num"]: row for row in csv.DictReader((repo / "models" / "technic-sets.csv").open())}
    versions_path = omr / "versions.json"
    versions = json.loads(versions_path.read_text()) if versions_path.exists() else {}
    fetched = 0
    for one in _sets():
        for model in sorted({fn.get("model") or one["curated"]["model"] for fn in one["curated"]["functions"]}):
            if not model.startswith("omr/"):
                continue
            name = model[len("omr/"):]
            url = pins.get(one["set"], {}).get("omr_file", "")
            if not url:
                print(f"{one['set']}: no OMR file pinned for {model}")
                continue
            if versions.get(name) == url and (omr / name).exists():
                continue
            request = urllib.request.Request(url, headers={"User-Agent": "brickworks (https://brickworks.diy)"})
            with urllib.request.urlopen(request, timeout=120) as reply:
                (omr / name).write_bytes(reply.read())
            versions[name] = url
            fetched += 1
            time.sleep(0.2)
    versions_path.write_text(json.dumps(versions, indent=1, sort_keys=True) + "\n")
    print(f"Kinebrick at {PIN[:7]} in {repo}; {fetched} OMR files fetched, {len(versions)} in {omr}")
    return 0


def _sets() -> list[dict]:
    out = []
    for path in sorted((_checkout() / "data" / "sets").glob("*.json")):
        one = json.loads(path.read_text())
        if one.get("curated", {}).get("functions"):
            out.append(one)
    return out


def _model_path(model: str) -> Path:
    return DATA / "omr" / model[len("omr/"):] if model.startswith("omr/") else _checkout() / model


# -- reading a model as Kinebrick does ---------------------------------------------------------


def _name(text: str) -> str:
    return text.strip().lower().replace("\\", "/")


def _files(text: str) -> dict[str, list[str]]:
    """Kinebrick's modelFiles: each file of an MPD by name, in order; the first is the model."""
    files: dict[str, list[str]] = {}
    current: list[str] | None = None
    for line in re.split(r"\r?\n", text):
        tokens = line.split()
        if len(tokens) >= 2 and tokens[0] == "0" and tokens[1] == "FILE":
            current = []
            name = _name(" ".join(tokens[2:]))
            files.setdefault(name, current)
            continue
        if len(tokens) >= 2 and tokens[0] == "0" and tokens[1] in ("NOFILE", "!DATA"):
            current = None
            continue
        if current is None and not files:
            current = files.setdefault("", [])
        if current is not None:
            current.append(line)
    return files


PART_HEADER = re.compile(r"^\s*0\s+!LDRAW_ORG\s+(Unofficial_)?(Part|Subpart|Primitive|8_Primitive|48_Primitive|Shortcut)\b",
                         re.I)


def _mul(a: list[float], b: list[float]) -> list[float]:
    return [sum(a[r * 4 + k] * b[k * 4 + c] for k in range(4)) for r in range(4) for c in range(4)]


def flatten(text: str, primitives: set[str], pieces: dict[str, list[str]]) -> list[dict]:
    """Kinebrick's parseModel: every part, submodels read where their line is, primitives left out,
    a part read as its pieces read so. Each {name, at (4x4, row by row), of (the part a piece is
    of, {name, at}) or absent}."""
    files = _files(text)
    submodels = {name: lines for name, lines in files.items() if name and not any(PART_HEADER.match(l) for l in lines)}
    parts: list[dict] = []

    def place(lines: list[str], at: list[float], depth: int, of: dict | None) -> None:
        if depth > 64:
            raise ValueError("submodels nested too deep")
        for line in lines:
            tokens = line.split()
            if not tokens or tokens[0] != "1" or len(tokens) < 15:
                continue
            x, y, z, a, b, c, d, e, f, g, h, i = (float(t) for t in tokens[2:14])
            here = _mul(at, [a, b, c, x, d, e, f, y, g, h, i, z, 0, 0, 0, 1])
            name = _name(" ".join(tokens[14:]))
            if name in primitives:
                continue
            if name in submodels:
                place(submodels[name], here, depth + 1, of)
            elif name in pieces:
                # A piece read as its own pieces again, as Kinebrick reads it (a linear actuator's
                # 92693c03 is a 92693c01-f2 and more, and that its three parts); each is of the
                # part the file places, the one brick the app reads.
                place(pieces[name], here, depth + 1, of or {"name": name, "at": here})
            else:
                parts.append({"name": name, "at": here, **({"of": of} if of else {})})

    first = next(iter(files.values()), [])
    place(first, [1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1], 0, None)
    return parts


REF = re.compile(r"^\s*p(\d+)\s+(.*?)\s*$")


def _ref(text: str, parts: list[dict]) -> dict:
    """A part as Kinebrick names it, "p483 3736", where it stands; or {error}."""
    found = REF.match(text)
    if not found:
        return {"ref": text, "error": f"{text} names no part"}
    index = int(found.group(1))
    if index >= len(parts):
        return {"ref": text, "error": f"{text}: the model has {len(parts)} parts"}
    part = parts[index]
    said = _name(found.group(2))
    have = part["name"][:-4] if part["name"].endswith(".dat") else part["name"]
    if said != have and not have.startswith(said.split(" ")[0]):
        return {"ref": text, "error": f"{text}: part {index} is a {have}"}
    out = {"ref": text.strip(), "name": have, "at": part["at"]}
    if "of" in part:
        of = part["of"]
        out["of"] = {"name": of["name"][:-4] if of["name"].endswith(".dat") else of["name"], "at": of["at"]}
    return out


def _against(text: str, parts: list[dict]) -> dict:
    one, _, other = text.partition(" against ")
    out = {"part": _ref(one, parts)}
    if other:
        out["against"] = _ref(other, parts)
    return out


def jobs() -> Path:
    repo = _checkout()
    primitives = {_name(n) for n in json.loads((repo / "packed" / "primitives.json").read_text())}
    pieces = {_name(k): v for k, v in json.loads((repo / "packed" / "pieces.json").read_text()).items()}
    read: dict[str, list[dict]] = {}
    out = []
    for one in _sets():
        curated = one["curated"]
        kinebrick = one.get("generated", {}).get("functions", [])
        by_model: dict[str, list[dict]] = {}
        for n, fn in enumerate(curated["functions"]):
            model = fn.get("model") or curated["model"]
            path = _model_path(model)
            if model not in read:
                read[model] = flatten(path.read_text(errors="replace"), primitives, pieces) if path.exists() else []
            parts = read[model]
            row: dict = {"set": one["set"], "n": n, "does": fn.get("does", ""),
                         "mechanisms": fn.get("mechanisms", []),
                         "kinebrick": (kinebrick[n] if n < len(kinebrick) else {}).get("result", ""),
                         "kinebrick_why": (kinebrick[n] if n < len(kinebrick) else {}).get("why", [])}
            if fn.get("skip"):
                row["skip"] = fn["skip"]
            elif not parts:
                row["error"] = f"no model file {model}"
            elif fn.get("control"):
                controls = fn["control"] if isinstance(fn["control"], list) else [fn["control"]]
                row["control"] = [_ref(c, parts) for c in controls]
                row["moves"] = [_against(m, parts) for m in fn.get("moves", [])]
                row["stays"] = [_against(s, parts) for s in fn.get("stays", [])]
                row["first"] = [{"control": _ref(f["control"], parts), "by": float(f.get("by", 0.0))}
                                for f in fn.get("first", [])]
            by_model.setdefault(str(path), []).append(row)
        for path, rows in by_model.items():
            out.append({"set": one["set"], "file": path, "functions": rows})
    OUT.mkdir(parents=True, exist_ok=True)
    target = OUT / "jobs.json"
    target.write_text(json.dumps({"pin": PIN, "sets": out}))
    errors = sum(1 for s in out for f in s["functions"] for r in f.get("control", []) + [m["part"] for m in
                 f.get("moves", [])] if "error" in r)
    print(f"{sum(len(s['functions']) for s in out)} functions in {len(out)} models, {len(_sets())} sets;"
          f" {errors} named parts not found as named; {target}")
    return target


# -- running ------------------------------------------------------------------------------------


def _run_shard(models: list[dict], label: str, job: int, timeout: float, app: Path, dump: bool = False,
               drag: bool = False) -> None:
    rows_path = OUT / f"kinefuncs_{label}_{job}.jsonl"
    log = (OUT / f"kinefuncs_{label}_{job}.log").open("a")
    left = list(models)
    data = OUT / f".data_{label}_{job}"
    data.mkdir(parents=True, exist_ok=True)
    while left:
        listing = OUT / f"kinefuncs_{label}_{job}.json"
        listing.write_text(json.dumps({"sets": left}))
        done_before = len(rows_path.read_text().splitlines()) if rows_path.exists() else 0
        process = subprocess.Popen(
            [str(HEAVY), "godot", "--headless", "--path", str(app), "--script", "src/dev/kinefuncs_probe.gd", "--",
             f"--functions={listing}", f"--rows={rows_path}"]
            + ([f"--dump={OUT / f'kinefuncs_{label}_dump'}"] if dump else []) + (["--drag"] if drag else []),
            cwd=app, stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
            # A data folder of its own: user:// is otherwise the owner's app data.
            env=dict(os.environ, XDG_DATA_HOME=str(data)))
        began, began_at = "", 0.0
        while process.poll() is None:
            time.sleep(2)
            lines = rows_path.read_text().splitlines()[done_before:] if rows_path.exists() else []
            if lines:
                last = json.loads(lines[-1])
                if last.get("begin") and last["file"] != began:
                    began, began_at = last["file"], time.time()
                elif last.get("end"):
                    began = ""
            if began and time.time() - began_at > timeout:
                os.killpg(process.pid, signal.SIGTERM)
                try:
                    process.wait(timeout=60)
                except subprocess.TimeoutExpired:
                    os.killpg(process.pid, signal.SIGKILL)
                    process.wait()
                with rows_path.open("a") as handle:
                    handle.write(json.dumps({"file": began, "end": True, "timed_out": int(timeout)}) + "\n")
                break
        ended = {json.loads(l)["file"] for l in rows_path.read_text().splitlines()
                 if l.strip() and json.loads(l).get("end")} if rows_path.exists() else set()
        rest = [m for m in left if m["file"] not in ended]
        if len(rest) == len(left):
            with rows_path.open("a") as handle:
                for m in rest:
                    handle.write(json.dumps({"file": m["file"], "end": True, "failed": "the probe stopped before it"})
                                 + "\n")
            break
        left = rest
    log.close()


def run(label: str, jobs_n: int, only: list[str], timeout: float, app: Path, dump: bool = False,
        drag: bool = False) -> None:
    listing = json.loads((OUT / "jobs.json").read_text())
    models = [m for m in listing["sets"] if not only or any(o == m["set"] or o == m["set"].split("-")[0] for o in only)]
    for old in OUT.glob(f"kinefuncs_{label}_*"):
        if old.is_file():
            old.unlink()
    if dump:
        (OUT / f"kinefuncs_{label}_dump").mkdir(parents=True, exist_ok=True)
    sizes = {m["file"]: Path(m["file"]).stat().st_size if Path(m["file"]).exists() else 0 for m in models}
    shards: list[list[dict]] = [[] for _ in range(jobs_n)]
    load = [0] * jobs_n
    for m in sorted(models, key=lambda one: -sizes[one["file"]]):
        n = load.index(min(load))
        shards[n].append(m)
        load[n] += sizes[m["file"]]
    threads = [threading.Thread(target=_run_shard, args=(shard, label, n, timeout, app, dump, drag))
               for n, shard in enumerate(shards) if shard]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()
    merged = OUT / f"kinefuncs_{label}.jsonl"
    with merged.open("w") as out:
        for n in range(jobs_n):
            part = OUT / f"kinefuncs_{label}_{n}.jsonl"
            if part.exists():
                out.write(part.read_text())
    text = table(label)
    (OUT / f"kinefuncs_{label}.md").write_text(text)
    print(text.split("\n\n")[1])


# -- the table -----------------------------------------------------------------------------------


def _rows(label: str) -> dict[tuple[str, int], dict]:
    """Every function's row by (set, n): the probe's, or one said for a model that timed out or failed."""
    listing = json.loads((OUT / "jobs.json").read_text())
    path = OUT / f"kinefuncs_{label}.jsonl"
    lines = [json.loads(l) for l in path.read_text().splitlines() if l.strip()] if path.exists() else []
    rows: dict[tuple[str, int], dict] = {}
    for line in lines:
        if "n" in line and "set" in line and "result" in line:
            rows[(line["set"], int(line["n"]))] = line
    for line in lines:
        if line.get("end") and (line.get("timed_out") or line.get("failed")):
            for m in listing["sets"]:
                if m["file"] == line["file"]:
                    for fn in m["functions"]:
                        rows.setdefault((fn["set"], fn["n"]), {
                            "set": fn["set"], "n": fn["n"], "result": "timed out" if line.get("timed_out") else "error",
                            "why": [f"timed out after {line['timed_out']} s" if line.get("timed_out")
                                    else line["failed"]]})
    return rows


def _short(text: str, most: int = 90) -> str:
    text = " ".join(str(text).split()).replace("|", "/")
    return text if len(text) <= most else text[: most - 1] + "…"


def cause_of(row: dict) -> str:
    """The first reason a function did not work, short, to count them by."""
    if row.get("result") == "works":
        return ""
    why = " ".join(row.get("why", []))
    rules = [
        (r"timed out", "the model took too long"),
        (r"not in the model as opened|no brick stands", "a named part is not in the model as opened"),
        (r"names no part|the model has|is a ", "a named part is not as Kinebrick names it"),
        (r"is the base|part of the base", "the control is held with the base"),
        (r"floating", "the control turns on nothing the reading found"),
        (r"slides", "the control slides"),
        (r"locked|lock", "the train locks"),
        (r"no joint|turns on nothing|does not turn", "the control turns on nothing"),
    ]
    for pattern, short in rules:
        if re.search(pattern, why):
            return short
    if row.get("still"):
        return "turned, but parts that should move did not"
    if row.get("moved"):
        return "parts that should stay moved"
    return row.get("result", "") + (": " + _short(why, 60) if why else "")


def table(label: str, against: str = "") -> str:
    listing = json.loads((OUT / "jobs.json").read_text())
    rows = _rows(label)
    before = _rows(against) if against else {}
    functions = [fn for m in listing["sets"] for fn in m["functions"]]
    ours = Counter(rows.get((fn["set"], fn["n"]), {}).get("result", "not run") for fn in functions)
    theirs = Counter(fn["kinebrick"] for fn in functions)
    both = sum(1 for fn in functions if fn["kinebrick"] == "works"
               and rows.get((fn["set"], fn["n"]), {}).get("result") == "works")
    sets = sorted({fn["set"] for fn in functions})
    every = [s for s in sets if all(rows.get((fn["set"], fn["n"]), {}).get("result") in ("works", "skipped",
                                    "not checked") for fn in functions if fn["set"] == s)]
    lines = [f"# Simulate on real sets' functions, beside Kinebrick ({label})", ""]
    lines.append(f"Brickworks' Simulate works {ours['works']} of the {len(functions)} functions of Kinebrick's"
                 f" {len(sets)} sets ({100 * ours['works'] / max(1, len(functions)):.0f}%); Kinebrick's main"
                 f" ({PIN[:7]}) works {theirs['works']} by its sets' own results (its README: 517). Both work"
                 f" {both}. Every function of {len(every)} sets works in Simulate.")
    if before:
        was = Counter(r.get("result") for r in before.values())
        lines.append(f"Against {against}: {was['works']} worked then.")
    lines.append("")
    lines.append("| result | Brickworks | Kinebrick |")
    lines.append("|---|---|---|")
    for result in RESULTS + ("not run",):
        if ours[result] or theirs[result]:
            lines.append(f"| {result} | {ours[result]} | {theirs[result]} |")
    lines.append("")
    causes = Counter(cause_of(rows.get((fn["set"], fn["n"]), {"result": "not run"})) for fn in functions
                     if rows.get((fn["set"], fn["n"]), {}).get("result") not in ("works", "skipped", "not checked"))
    lines.append("| why a function does not work in Simulate | functions |")
    lines.append("|---|---|")
    for cause, count in causes.most_common():
        lines.append(f"| {cause} | {count} |")
    lines.append("")
    kinds: dict[str, Counter] = {}
    for fn in functions:
        for kind in fn["mechanisms"] or ["(none)"]:
            kinds.setdefault(kind.split(":")[0], Counter())[
                ("ours " if rows.get((fn["set"], fn["n"]), {}).get("result") == "works" else "")
                + ("theirs" if fn["kinebrick"] == "works" else "")] += 1
    lines.append("| mechanism | functions | Brickworks works | Kinebrick works |")
    lines.append("|---|---|---|---|")
    for kind, count in sorted(kinds.items(), key=lambda kv: -sum(kv[1].values())):
        total = sum(count.values())
        lines.append(f"| {kind} | {total} | {count['ours '] + count['ours theirs']} |"
                     f" {count['theirs'] + count['ours theirs']} |")
    lines.append("")
    lines.append("| set | # | what it does | Kinebrick | Brickworks | how Simulate drove it, or why not |")
    lines.append("|---|---|---|---|---|---|")
    for fn in functions:
        row = rows.get((fn["set"], fn["n"]), {"result": "not run"})
        result = row.get("result", "not run")
        if before and (fn["set"], fn["n"]) in before and before[(fn["set"], fn["n"])].get("result") != result:
            result += f" (was {before[(fn['set'], fn['n'])].get('result')})"
        how = row.get("how", "")
        if row.get("result") != "works":
            how = "; ".join(filter(None, [how, _short(" ".join(row.get("why", [])), 110),
                                          ("still: " + ", ".join(row["still"][:3])) if row.get("still") else "",
                                          ("moved: " + ", ".join(row["moved"][:3])) if row.get("moved") else ""]))
        lines.append(f"| {fn['set']} | {fn['n'] + 1} | {_short(fn['does'])} | {fn['kinebrick'] or '—'} | {result} |"
                     f" {_short(how, 200)} |")
    return "\n".join(lines) + "\n"


def write_doc(label: str) -> None:
    text = table(label)
    head = ("<!-- Written by tools/kinefuncs.py table LABEL --write; do not edit by hand. -->\n"
            f"<!-- Kinebrick {PIN}: github.com/erik-larsen/kinebrick (MIT; its data CC BY-SA 4.0). -->\n\n")
    DOC.write_text(head + text)
    print(f"wrote {DOC}")


def main(argv: list[str]) -> int:
    if not argv or argv[0] not in ("fetch", "jobs", "run", "table"):
        print(__doc__)
        return 2
    flags = {a.split("=", 1)[0]: (a.split("=", 1)[1] if "=" in a else "") for a in argv[1:] if a.startswith("--")}
    words = [a for a in argv[1:] if not a.startswith("--")]
    if argv[0] == "fetch":
        return fetch()
    if argv[0] == "jobs":
        jobs()
        return 0
    if not words:
        print("a LABEL is needed")
        return 2
    if argv[0] == "table":
        if "--write" in flags:
            write_doc(words[0])
        else:
            print(table(words[0], flags.get("--against", "")))
        return 0
    only = [s for s in flags.get("--only", "").split(",") if s]
    run(words[0], int(flags.get("--jobs", "4")), only, float(flags.get("--timeout", "1800")),
        Path(flags.get("--app", str(ROOT))).resolve(), "--dump" in flags, "--drag" in flags)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
