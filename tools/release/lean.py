#!/usr/bin/env python3
"""What a release must run: what its own change reaches, less what was proven since.

    lean.py checks --live L --head H --tree DIR [--smoke "site"] [--named "a b"]
    lean.py probes --live L --head H --tree DIR [--list tools/suite/headless.txt]
    lean.py record checks NAME BUILT AT OUT...    a preview's passes, as proof
    lean.py record probes NAME SHA SHA --passed "a b"   a train's (or the night's) probes

A release used to run every check flows_for.py named for what its branch
changed since main, and every headless probe, whatever had been proven.
rel-m319's 24 units named 146 of the 150 checks: api/_oc.js alone named 94,
web/site.css 70, and its 8 attempts ran 207 checks and 494 probes over 13
hours (2026-11-23). Now it runs:

1. What its change reaches: flows_for.py (checks) or what each probe names
   (probes: those whose own source names a changed script, its class or a
   control it gives) on the files that differ between the build
   brickworks.diy serves (L) and the release (H), never since an older base.
2. Less each one carried: one that passed on a preview built from commit P,
   its scripts at commit A, is carried when neither P..H nor A..H reaches it.
   It holds by the same rule that says a check not named still passes on
   live, and it is what makes a release of proven units fast: a unit that
   passed its own checks on its own preview is re-run only where what merged
   beside it reaches the same check. P must be in H's history and the proof
   at most LEAN_MAX_AGE hours old (36): the shared database and the services
   the checks call drift.
3. And the smoke: site on every release, frames when an app file changed.

Proof is written as it is made (ship.sh, unit_preview.sh, train.sh's probes,
nightly.sh): $RELEASE_OUT/proofs/KIND/NAME.EPOCH, a JSON of the commits and
the names that passed. Nothing else counts: a reused preview's commit is not
the commit its checks ran from, and a record says both.

The night's full run on pre261 (nightly.sh) proves everything once a day, so a
release the next day runs only what merged since. A check or probe the lean
list leaves out and that breaks is found that night at the latest.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
MAX_AGE_H = float(os.environ.get("LEAN_MAX_AGE", "36"))


def git(*args: str, ok: tuple[int, ...] = (0,)) -> str:
    run = subprocess.run(["git", "-C", str(REPO), *args], capture_output=True, text=True)
    if run.returncode not in ok:
        raise SystemExit(f"lean: git {' '.join(args)}: {run.stderr.strip()[:200]}")
    return run.stdout


def full(ref: str) -> str:
    return git("rev-parse", "--verify", "-q", ref + "^{commit}").strip()


def is_ancestor(a: str, b: str) -> bool:
    """Whether commit a is in b's history (b may be a commit or a merge's
    tree-ish written as COMMIT; a tree has no history, so the caller passes
    the commits the merge will have as parents)."""
    return subprocess.run(["git", "-C", str(REPO), "merge-base", "--is-ancestor", a, b],
                          capture_output=True).returncode == 0


def diff_files(a: str, b: str) -> list[str]:
    return [f for f in git("diff", "--name-only", a, b).splitlines() if f]


def out_dir() -> Path:
    return Path(os.environ.get("RELEASE_OUT") or REPO / "bench" / "results" / "release-out").resolve()


# --- what a change reaches ---

def flows_named(tree: Path, a: str, b: str) -> set[str]:
    """The checks flows_for.py (the release's own, in TREE) names for what
    differs between a and b."""
    files = diff_files(a, b)
    if not files:
        return set()
    with tempfile.NamedTemporaryFile("w", suffix=".diff", delete=False) as fh:
        fh.write(git("diff", "-U0", a, b, "--", "web"))
        diff = fh.name
    try:
        run = subprocess.run([sys.executable, "tools/release/flows_for.py", "--diff", diff, *files],
                             cwd=tree, capture_output=True, text=True)
    finally:
        os.unlink(diff)
    if run.returncode != 0:
        raise SystemExit(f"lean: flows_for.py failed: {(run.stderr or run.stdout).strip()[-300:]}")
    m = re.search(r"^checks: ([a-z_0-9 ]*)$", run.stdout, re.M)
    return set(m.group(1).split()) if m else set()


def suite(tree: Path, listed: str) -> list[str]:
    """The probes a tools/suite list names, as check.sh and train.sh read it."""
    names = []
    for line in (tree / listed).read_text().splitlines():
        line = re.sub(r"(^|\s)#.*", "", line).strip()
        if line:
            names.append(line.split()[0].split(":")[0])
    return names


FUNC_AT = re.compile(r"^(?:static\s+)?func\s+(\w+)")


def _changed_lines(a: str, b: str, f: str) -> tuple[set[int], list[str]]:
    """The new side's lines a diff from a to b changed in file f (beside a
    line taken out too), and every line it put in or took out."""
    lines: set[int] = set()
    said: list[str] = []
    at = 0
    for line in git("diff", "-U0", a, b, "--", f).splitlines():
        m = re.match(r"@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@", line)
        if m:
            at = int(m.group(1))
            count = 1 if m.group(2) is None else int(m.group(2))
            lines.update(range(at, at + count) if count else {max(at, 1), at + 1})
        elif line.startswith(("+", "-")) and not line.startswith(("+++", "---")):
            said.append(line[1:])
    return lines, said


def probes_reached(tree: Path, a: str, b: str, listed: set[str]) -> set[str]:
    """The listed probes a change from a to b reaches: each whose own source
    names a changed file (its res:// path or its file name), a function the
    change is inside, a control name or other underscored word on a line it
    changed, or the file's class_name when it changed the class outside its
    functions; and each probe changed itself. featuremap affected reaches
    every probe from any script (each loads src/main.gd, which loads
    everything: 569 tests for a dialog's script), so it chose them all for
    an app change and could carry none. A probe names what it drives; what
    this misses, the night's run of every probe finds (nightly.sh)."""
    files = diff_files(a, b)
    if not files or not listed:
        return set()
    words: set[str] = set()
    found: set[str] = set()
    for f in files:
        path = Path(f)
        if path.parts[:2] == ("src", "dev") and path.suffix == ".gd":
            stem = path.stem
            if stem in listed:
                found.add(stem)
            if stem.endswith("_probe") and stem[: -len("_probe")] in listed:
                found.add(stem[: -len("_probe")])
            continue
        if path.suffix in (".uid", ".import") or not (f.startswith(("src/", "assets/", "data/", "models/", "locale/"))
                                                       or f in ("project.godot", "export_presets.cfg")):
            continue
        words.add("res://" + f)
        words.add(path.name)
        if path.suffix not in (".gd", ".tscn", ".tres") or not (tree / f).is_file():
            continue
        text = (tree / f).read_text(errors="ignore").split("\n")
        lines, said = _changed_lines(a, b, f)
        words.update(w for line in said for w in re.findall(r"\b([a-z][a-z0-9]*(?:_[a-z0-9]+)+)\b", line))
        outside = False
        for n in sorted(lines):
            inside = next((FUNC_AT.match(text[k]).group(1) for k in range(min(n, len(text)) - 1, -1, -1)
                           if FUNC_AT.match(text[k])), None)
            if inside:
                words.add(inside)
            else:
                outside = True
        cls = next((m.group(1) for line in text if (m := re.match(r"class_name\s+(\w+)", line))), None)
        if cls and (outside or path.suffix != ".gd"):
            words.add(cls)
    # A private function or an engine callback (_ready, _process) is every
    # probe's, as are words most probes say (model_name, part_count): a word
    # named by more than COMMON of the probes picks out none of them, and
    # is left to the night's run.
    words = {w for w in words if len(w) > 3 and not w.startswith("_")}
    sources: dict[str, str] = {}
    for name in listed:
        for src in (tree / "src" / "dev" / f"{name}.gd", tree / "src" / "dev" / f"{name}_probe.gd"):
            if src.is_file():
                sources[name] = src.read_text(errors="ignore")
                break
    common = max(12, int(len(sources) * float(os.environ.get("LEAN_COMMON", "0.1"))))
    # A word is looked up in each probe's own words; a path or a file name
    # is searched for. rel-m321's 400 files took 2 minutes by search alone.
    tokens = {n: set(re.findall(r"\w+", text)) for n, text in sources.items()}
    for w in sorted(words):
        if re.fullmatch(r"\w+", w):
            said = {n for n, have in tokens.items() if w in have}
        else:
            at = re.compile(r"(?<![\w])" + re.escape(w) + r"(?![\w])")
            said = {n for n, text in sources.items() if w in text and at.search(text)}
        if len(said) <= common:
            found |= said
    return found


# What a change from C to a release's tree reaches is the same whenever it
# is asked: train.sh asks at staging (main with the branch merged, a tree)
# and again once merged (that same tree, as a commit), and flows_for.py
# took 75 s of each for rel-m321's 400 files (2026-11-23). Kept by C and the
# release's tree, which holds the tools that decide; REACH_RULE changes with
# the rule here.
REACH_RULE = "2"


def memo(kind: str, c: str, head: str, work) -> set[str]:
    try:
        commit, tree = full(c), git("rev-parse", head + "^{tree}").strip()
    except SystemExit:
        return work()
    if not commit or not tree:
        return work()
    key = f"{kind}-{commit}-{tree}-{REACH_RULE}"
    path = out_dir() / "proofs" / "reach" / key
    if path.is_file():
        return set(path.read_text().split())
    got = work()
    path.parent.mkdir(parents=True, exist_ok=True)
    part = path.with_name(path.name + f".{os.getpid()}")
    part.write_text(" ".join(sorted(got)) + "\n")
    os.replace(part, path)
    for old in path.parent.iterdir():
        try:
            if time.time() - old.stat().st_mtime > 2 * 86400:
                old.unlink()
        except OSError:
            pass
    return got


# --- proof ---

def records(kind: str) -> list[dict]:
    d = out_dir() / "proofs" / kind
    found = []
    now = time.time()
    for f in sorted(d.glob("*.*")) if d.is_dir() else []:
        try:
            r = json.loads(f.read_text())
        except (OSError, ValueError):
            continue
        if now - r.get("time", 0) > MAX_AGE_H * 3600:
            continue
        r["file"] = f.name
        found.append(r)
    return found


def record(kind: str, name: str, built: str, at: str, passed: list[str]) -> Path:
    d = out_dir() / "proofs" / kind
    d.mkdir(parents=True, exist_ok=True)
    body = {"kind": kind, "name": name, "built": full(built), "at": full(at),
            "passed": sorted(set(passed)), "time": int(time.time())}
    f = d / f"{name}.{body['time']}"
    tmp = f.with_suffix(f".{os.getpid()}.tmp")
    tmp.write_text(json.dumps(body) + "\n")
    tmp.replace(f)
    return f


def passed_in(outs: list[Path]) -> list[str]:
    """The checks a battery's files say passed: NAME exit=0 lines, a later
    file (a check run again alone) over an earlier one."""
    state: dict[str, bool] = {}
    for out in outs:
        if not out.exists():
            continue
        for line in out.read_text(errors="ignore").splitlines():
            m = re.match(r"^([a-z_0-9]+) exit=(\d+) ", line)
            if m:
                state[m.group(1)] = m.group(2) == "0"
    return [n for n, ok in state.items() if ok]


# --- the choice ---

def choose(candidates: set[str], proofs: list[dict], heads: list[str],
           reach: "callable[[str], set[str]]") -> tuple[set[str], dict[str, str]]:
    """The candidates to run, and each carried with the proof that carries
    it. reach(P) is what a change from P to the release reaches; heads are
    the commits the release has as its history (a merge's parents). Each
    commit's reach is worked out once, four at a time: flows_for.py takes a
    minute on a 500-file change at load 100."""
    useful = [r for r in sorted(proofs, key=lambda r: -r["time"])
              if candidates & set(r["passed"]) and any(is_ancestor(r["built"], h) for h in heads)]
    commits = sorted({c for r in useful for c in (r["built"], r["at"])})
    with ThreadPoolExecutor(max_workers=4) as pool:
        seen = dict(zip(commits, pool.map(reach, commits)))
    left = set(candidates)
    carried: dict[str, str] = {}
    for r in useful:
        for n in sorted((left & set(r["passed"])) - seen[r["built"]] - seen[r["at"]]):
            left.discard(n)
            carried[n] = f"{r['name']} ({r['built'][:9]}, {int((time.time() - r['time']) / 3600)} h ago)"
    return left, carried


# --- checks that cannot run on brickworks.diy ---
# A flow that refuses brickworks.diy says so as it starts and exits 2
# ("designer_period_flow: never on brickworks.diy; give a preview"), some
# only given an option ("homefeed_check: --signed-in never on
# brickworks.diy"). ship.sh ran rel-m319's designer_period there anyway, to
# learn whether it failed there too: 45 minutes queued for a run that
# could never say (2026-11-23).
REFUSAL = re.compile(r"""console\.error\(\s*["'`][^"'`]*never (?:on|against|runs (?:on|against)) brickworks\.diy""")
OPTION = re.compile(r"""args\[\s*["']([\w-]+)["']\s*\]|args\.(\w+)""")


def check_commands(tree: Path) -> dict[str, str]:
    """Each check of preview_checks.sh: its command line, as its map says."""
    text = (tree / "tools" / "release" / "preview_checks.sh").read_text(errors="ignore")
    return dict(re.findall(r'^\s*\[([a-z_0-9]+)\]="([^"]*)"', text, re.M))


def never_live(tree: Path, names: list[str]) -> list[str]:
    """Those of NAMES whose script, given that check's options, refuses
    brickworks.diy: a refusal whose test names no option refuses always;
    one that names options refuses when the check passes every one."""
    commands = check_commands(tree)
    found = []
    for name in names:
        words = commands.get(name, "").split()
        if not words or not words[0].endswith(".mjs"):
            continue
        script = tree / words[0]
        if not script.is_file():
            continue
        lines = script.read_text(errors="ignore").splitlines()
        given = {w[2:].split("=", 1)[0] for w in words[1:] if w.startswith("--")}
        for i, line in enumerate(lines):
            if not REFUSAL.search(line):
                continue
            test = next((lines[k] for k in range(i, max(i - 4, -1), -1) if re.match(r"\s*(}\s*else\s+)?if\s*\(", lines[k])), "")
            options = {a or b for a, b in OPTION.findall(test)} - {"url"}
            if options <= given:
                found.append(name)
                break
    return found


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    for kind in ("checks", "probes"):
        s = sub.add_parser(kind)
        s.add_argument("--live", required=True, help="the commit brickworks.diy serves")
        s.add_argument("--head", required=True, help="the release: a commit, or a tree (git merge-tree)")
        s.add_argument("--parents", default="", help="for a tree, the commits it merges (its history)")
        s.add_argument("--tree", required=True, help="a checkout of the release, whose tools decide")
        s.add_argument("--named", default="", help="named by the lead: always run")
        s.add_argument("--smoke", default="", help="always run")
        s.add_argument("--every", action="store_true", help="carry nothing over (the full list)")
        if kind == "probes":
            s.add_argument("--list", default="tools/suite/headless.txt")
    n = sub.add_parser("never-live", help="those of the checks named whose script refuses brickworks.diy")
    n.add_argument("--tree", required=True)
    n.add_argument("names", nargs="*")
    r = sub.add_parser("record")
    r.add_argument("kind", choices=("checks", "probes"))
    r.add_argument("name")
    r.add_argument("built")
    r.add_argument("at")
    r.add_argument("outs", nargs="*", help="a battery's TAG_pv.out, then its TAG_alone_*.out, oldest first")
    r.add_argument("--passed", default="", help="the names that passed, said outright (a train's probes)")
    a = p.parse_args()

    if a.cmd == "never-live":
        print(" ".join(never_live(Path(a.tree).resolve(), a.names)))
        return 0

    if a.cmd == "record":
        passed = a.passed.split() + passed_in([Path(o) for o in a.outs])
        if not passed:
            print(f"lean: nothing passed in {a.name}'s run: no proof written")
            return 0
        f = record(a.kind, a.name, a.built, a.at, passed)
        print(f"lean: {len(passed)} {a.kind} proven at {a.built[:9]} ({f.name})")
        return 0

    tree = Path(a.tree).resolve()
    live = full(a.live)
    if not live:
        raise SystemExit(f"lean: no commit {a.live}")
    head = a.head
    heads = a.parents.split() or [head]
    if a.cmd == "checks":
        reach = lambda c: memo("checks", c, head, lambda: flows_named(tree, c, head))  # noqa: E731
    else:
        listed = set(suite(tree, a.list))
        reach = lambda c: memo("probes", c, head, lambda: probes_reached(tree, c, head, listed))  # noqa: E731
    files = diff_files(live, head)
    candidates = reach(live)
    named, smoke = set(a.named.split()), set(a.smoke.split())
    print(f"lean: {len(files)} files differ from the build brickworks.diy serves ({live[:9]})")
    print(f"reached ({len(candidates)}): {' '.join(sorted(candidates)) or 'none'}")
    if a.every:
        left, carried = set(candidates), {}
    else:
        left, carried = choose(candidates, records(a.cmd), heads, reach)
    for n in sorted(carried):
        print(f"carried {n:16} passed on {carried[n]}, and nothing since reaches it")
    run = left | named | smoke
    if named - left:
        print(f"named: {' '.join(sorted(named - left))}")
    if smoke - left - named:
        print(f"smoke: {' '.join(sorted(smoke - left - named))}")
    # The lead's in the lead's order (the battery runs them first), then the rest.
    order = list(dict.fromkeys(a.named.split())) + sorted(run - named)
    print(f"{a.cmd}: {' '.join(order)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
