"""The release train: tools/release/train.sh stages a release and ships it in turn.

Each test makes a repository of its own with an origin, a staged branch and
unit worktrees. train.sh, ship.sh, preview_lib.sh and retire_wt.sh are the
real ones; stand-ins take the place of what a real release spends an hour
on, and of what reaches past the yard: release_wt.sh makes the worktree
alone, merge_unit.sh merges as git does, the gates pass, deploy.sh makes a
preview and promotes it into a file that stands for brickworks.diy/app (curl
reads that file, heavy runs its command at once, godot says the tool list
is in step), preview_checks.sh writes each check's exit, and
tools/check.sh and tools/probe.sh pass and say what ran. The train itself
runs detached, as staged, and is read through its files and `train.sh
status`.

What they prove: the train waits for the release before it to serve and
then ships; edits to its spec after staging are what it ships; a hold stops
it before the merge and before the probes and the ship, and one set while
the ship waits still holds; a tree left dirty or mid-merge, or a probe that
failed or skipped itself, is never shipped; it stops when the release before
did not ship, was stopped or died, or at its deadline; and status says each
step, the checks, the probes and what is live. Its probes run beside the
ship, four at a time, one failing beside others again alone, and main moves
only once every one has passed. It ships the tip it merged when the branch
moves on meanwhile, and a restage clears a stopped attempt's own merge but
never a fix made in it. Its checks run on the live site as it is staged, and
status says which already fail there.
"""

from __future__ import annotations

import os
import shutil
import signal
import subprocess
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
pytestmark = pytest.mark.skipif(
    not (shutil.which("setsid") and shutil.which("git")),
    reason="the train needs setsid and git")

STUBS = {
    "tools/release/release_wt.sh": """#!/bin/bash
# stand-in: the worktree alone, without the links a deploy needs
set -eu
R=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
git -C "$R" worktree add -q "$R/.claude/worktrees/$1" -b "$1" "$2"
echo "$R/.claude/worktrees/$1 at $(git -C "$R/.claude/worktrees/$1" log --oneline -1)"
""",
    "tools/release/merge_unit.sh": """#!/bin/bash
# stand-in: the merge as git makes it. STUB_DIRTY leaves a tracked file
# changed after it, STUB_HALF a merge not committed, each saying it passed.
# STUB_MERGE_GATE writes GATE.merged once merged, then holds until GATE is
# there, as the real one's import and gates take a minute or two.
cd "$1" || exit 1
if [ -n "${STUB_HALF:-}" ]; then git merge -q --no-ff --no-commit "$2"; exit 0; fi
git merge -q --no-ff -m "$3" "$2" || exit 2
if [ -n "${STUB_MERGE_GATE:-}" ]; then
  : > "$STUB_MERGE_GATE.merged"
  for _ in $(seq 1 600); do [ -e "$STUB_MERGE_GATE" ] && break; sleep 0.05; done
fi
if [ -n "${STUB_DIRTY:-}" ]; then echo dirt >> README; fi
exit 0
""",
    "tools/release/ci_gate.sh": """#!/bin/bash
# stand-in: the version, the suite and the scripts pass; with STUB_CI_FAIL
# they fail, once a probe has begun beside them.
[ -z "${STUB_CI_FAIL:-}" ] && exit 0
for _ in $(seq 1 600); do [ -e "$RELEASE_OUT/probe_times" ] && break; sleep 0.05; done
exit 1
""",
    "tools/release/parse_gate.sh": "#!/bin/bash\n# stand-in: every script parses\nexit 0\n",
    "tools/release/release_links.sh": "#!/bin/bash\n# stand-in: every download answers\nexit 0\n",
    "tools/fresh_import.sh": "#!/bin/bash\n# stand-in: the class list is up to date\nexit 0\n",
    "tools/deploy.sh": """#!/bin/bash
# stand-in: a preview of this commit, or that preview promoted (--promote,
# --prod), which then stands for brickworks.diy/app; when, in promoted.
SHA=$(git rev-parse --short HEAD)
case "${1:-}" in
  --promote=*|--prod)
    echo "$(date +%s.%N) $SHA" >> "$RELEASE_OUT/promoted"
    echo "<script src=\\"/b/$SHA/index.js\\"></script>" > "$STUB_LIVE"
    echo "deploy: brickworks.diy serves $SHA" ;;
  *) echo "deploy done https://preview.invalid/$SHA" ;;
esac
""",
    "tools/release/preview_checks.sh": """#!/bin/bash
# stand-in: one line a check as the real one writes it, at once, and when
# each began in check_times. STUB_FLAKY fails that check in the battery and
# passes it alone; STUB_GATE holds the battery's last check until that file
# is there; STUB_STALE_FAILS fails those on the live site as a train is
# staged.
P=$1 WT=$2 OUT=$3; shift 3
S=$RELEASE_OUT
# The checks it has, as the real one's table names them for train.sh stage.
declare -A CMD=(
  [io]="tools/web/io_flow.mjs --url=$P/app"
  [gallery]="tools/web/gallery_flow.mjs --url=$P"
  [people]="tools/web/people_flow.mjs --url=$P"
  [light_render]="tools/web/light_render_flow.mjs --url=$P/app"
)
echo "$P $WT $*" > "$S/${OUT}_args"
: > "$S/$OUT.out"
n=0
for c in "$@"; do
  n=$((n + 1))
  echo "$OUT $c began $(date +%s.%N)" >> "$S/check_times"
  fail=""
  case "$OUT" in
    *_pv)
      if [ "$n" -eq $# ] && [ -n "${STUB_GATE:-}" ]; then
        for _ in $(seq 1 600); do [ -e "$STUB_GATE" ] && break; sleep 0.05; done
      fi
      [ "$c" = "${STUB_FLAKY:-}" ] && fail="FAIL beside others" ;;
    *_stale) case " ${STUB_STALE_FAILS:-} " in *" $c "*) fail="FAIL on the live site" ;; esac ;;
  esac
  if [ -n "$fail" ]; then echo "$c exit=1 fails=1 1s :: $fail" >> "$S/$OUT.out"
  else echo "$c exit=0 fails=0 1s :: passed" >> "$S/$OUT.out"; fi
done
echo done >> "$S/$OUT.out"
""",
    "tools/check.sh": """#!/bin/bash
# stand-in: every probe is in a list. STUB_LISTS_HOLD sets HOLD, as the
# lead would between a release's merge and its probes.
[ -n "${STUB_LISTS_HOLD:-}" ] && echo "set while it listed" > "$RELEASE_OUT/HOLD"
exit 0
""",
    "tools/probe.sh": """#!/bin/bash
# stand-in: says which probe ran. The probe sets_a_hold sets HOLD, as the
# lead would while a release probes. fails and *_fails say FAIL and exit 0;
# skips exits 3 and says no FAIL, as probe.sh does for a probe that skipped
# itself. slow_* runs a second, gated* until RELEASE_OUT/probe_gate is
# there, each noting when it began and ended; flaky fails the first time it
# runs and passes after.
echo "$1" >> "$RELEASE_OUT/probes_run"
case "$1" in slow_*|gated*)
  echo "$1 began $(date +%s.%N)" >> "$RELEASE_OUT/probe_times"
  case "$1" in
    slow_*) sleep 1 ;;
    *) for _ in $(seq 1 600); do [ -e "$RELEASE_OUT/probe_gate" ] && break; sleep 0.05; done ;;
  esac
  echo "$1 ended $(date +%s.%N)" >> "$RELEASE_OUT/probe_times" ;;
esac
if [ "$1" = flaky ] && [ ! -e "$RELEASE_OUT/flaky_ran" ]; then
  : > "$RELEASE_OUT/flaky_ran"; echo "  FAIL the stand-in failed beside others"; exit 0
fi
if [ "$1" = sets_a_hold ]; then echo "set while it probed" > "$RELEASE_OUT/HOLD"; fi
case "$1" in fails|*_fails) echo "  FAIL the stand-in failed"; exit 0 ;; esac
if [ "$1" = skips ]; then echo "skips probe: SKIPPED"; exit 3; fi
echo "$1: all passed"
""",
}

# Outside the repository: what ship.sh reaches by its home and its PATH.
BIN_STUBS = {
    "home/.claude/claude-core/bin/heavy": "#!/bin/bash\n# stand-in: a slot at once\nexec \"$@\"\n",
    "bin/godot": "#!/bin/bash\n# stand-in: the tool list probe\necho \"the MCP is in step with the app\"\n",
    "bin/curl": "#!/bin/bash\n# stand-in: brickworks.diy/app, whatever is asked\ncat \"$STUB_LIVE\"\n",
}


class Yard:
    """A main checkout with an origin, a staged branch stage2 and three units:
    unitA, whose work is stage2's; unitB, a commit past it; unitC, at
    stage2 with a file git does not track."""

    def __init__(self, where: Path) -> None:
        self.r = where / "repo"
        self.wt = self.r / ".claude" / "worktrees"
        self.ro = self.r / "bench" / "results" / "release-out"
        self.live = where / "live.html"
        self.live.write_text('<script src="/b/0000000/index.js"></script>\n')
        for name, text in BIN_STUBS.items():
            path = where / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text)
            path.chmod(0o755)
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(("GIT_", "TRAIN_", "STUB_", "SHIP_", "RELEASE_", "LIVE_WAIT", "BOX_"))}
        env.update(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                   GIT_AUTHOR_NAME="Xaxis", GIT_AUTHOR_EMAIL="william.neeley@gmail.com",
                   GIT_COMMITTER_NAME="Xaxis", GIT_COMMITTER_EMAIL="william.neeley@gmail.com",
                   HOME=str(where / "home"), PATH="%s:%s" % (where / "bin", os.environ["PATH"]),
                   TRAIN_LIVE="https://brickworks.diy/app", STUB_LIVE=str(self.live),
                   TRAIN_POLL="0.1", SHIP_POLL="0.1", SHIP_CDN_WAIT="0")
        self.env = env
        self.git(where, "init", "-q", "--bare", "--initial-branch=main", str(where / "origin.git"))
        self.git(where, "init", "-q", "--initial-branch=main", str(self.r))
        for name in ("train.sh", "retire_wt.sh", "ship.sh", "preview_lib.sh"):
            self.put("tools/release/" + name, (ROOT / "tools" / "release" / name).read_text())
        for name, text in STUBS.items():
            self.put(name, text)
        self.put(".gitignore", "bench/results/\n.claude/worktrees/\n.env\n")
        self.put("README", "a release yard\n")
        self.git(self.r, "add", "-A")
        self.git(self.r, "commit", "-q", "-m", "the yard")
        (self.r / ".env").write_text("")
        self.git(self.r, "remote", "add", "origin", str(where / "origin.git"))
        self.git(self.r, "push", "-q", "-u", "origin", "main")
        self.base = self.git(self.r, "rev-parse", "main")
        self.unit("unitA", "main", "a.txt")
        self.git(self.r, "branch", "stage2", "unitA")
        self.git(self.r, "worktree", "lock", str(self.wt / "unitA"))
        self.unit("unitB", "unitA", "b.txt")
        self.git(self.r, "worktree", "add", "-q", "-b", "unitC", str(self.wt / "unitC"), "stage2")
        (self.wt / "unitC" / "notes.txt").write_text("not added yet\n")

    def put(self, name: str, text: str) -> None:
        path = self.r / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if name.endswith(".sh"):
            path.chmod(0o755)

    def git(self, where: Path, *args: str) -> str:
        return subprocess.run(["git", "-C", str(where), *args], env=self.env, check=True,
                              capture_output=True, text=True).stdout.strip()

    def unit(self, name: str, base: str, made: str) -> None:
        self.git(self.r, "worktree", "add", "-q", "-b", name, str(self.wt / name), base)
        (self.wt / name / made).write_text(name + "\n")
        self.git(self.wt / name, "add", made)
        self.git(self.wt / name, "commit", "-q", "-m", name + "'s work")

    def train(self, *args: str, **extra: str) -> subprocess.CompletedProcess:
        return subprocess.run(["bash", str(self.r / "tools/release/train.sh"), *args], cwd=self.r,
                              env={**self.env, **extra}, capture_output=True, text=True, timeout=60)

    def spec(self, tag: str, name: str) -> str:
        try:
            return (self.ro / (tag + ".train") / name).read_text().strip()
        except FileNotFoundError:
            return ""

    def text(self, name: str) -> str:
        try:
            return (self.ro / name).read_text()
        except FileNotFoundError:
            return ""

    def until(self, what, seconds: float = 30) -> None:
        end = time.time() + seconds
        while not what():
            assert time.time() < end, "waited %ss; trains said:\n%s" % (seconds, self.logs())
            time.sleep(0.05)

    def logs(self) -> str:
        return "\n".join(p.read_text() for p in sorted(self.ro.glob("*_train.out")) + sorted(self.ro.glob("*_lead.out")))

    def times(self, name: str) -> dict:
        """probe_times or check_times: each NAME's began and ended, as epoch seconds."""
        spans: dict = {}
        for line in self.text(name).splitlines():
            *who, what, when = line.split()
            spans.setdefault(" ".join(who), {})[what] = float(when)
        return spans

    def unmoved(self) -> None:
        """Main and origin are where the yard began, and nothing was promoted."""
        assert self.git(self.r, "rev-parse", "main") == self.base
        assert self.git(self.r.parent / "origin.git", "rev-parse", "main") == self.base
        assert not (self.ro / "promoted").exists(), self.text("promoted")
        assert "/b/0000000/" in self.live.read_text()

    def shipping(self, tag: str) -> None:
        """TAG's ship begun by hand, its preview made."""
        self.ro.mkdir(parents=True, exist_ok=True)
        (self.ro / (tag + "_lead.out")).write_text("SHIP: preview https://preview.invalid/%s\n" % tag)

    def shipped_in(self, tag: str, minutes: int) -> None:
        """A release before, whose ship served MINUTES after it began."""
        self.serves(tag)
        prod = self.ro / (tag + "_prod.log")
        prod.write_text("deploy: brickworks.diy serves 1111111\n")
        began = os.stat(self.ro / (tag + "_lead.out")).st_mtime
        os.utime(prod, (began + minutes * 60 - 10, began + minutes * 60 - 10))

    def serves(self, tag: str) -> None:
        """TAG's ship said brickworks.diy serves it, as ship.sh says it."""
        self.ro.mkdir(parents=True, exist_ok=True)
        # In place, as ship.sh's log grows: the file keeps the time it was made.
        with open(self.ro / (tag + "_lead.out"), "a") as log:
            log.write("SHIP: preview https://preview.invalid/%s\nSHIP: main is 1111111\n"
                      "SHIP: deploy: brickworks.diy serves 1111111\n" % tag)

    def stop(self) -> None:
        """Ends every train still running, as `kill -- -PID` would, and its checks on the live site."""
        for pid_file in [*self.ro.glob("*.train/pid"), *self.ro.glob("*.train/stale_pid")]:
            pid = int(pid_file.read_text())
            try:
                if "train.sh" in Path("/proc/%d/cmdline" % pid).read_text():
                    os.killpg(pid, signal.SIGTERM)
            except (FileNotFoundError, ProcessLookupError, PermissionError):
                pass


def _minute(text: str, after: str) -> float:
    """The HH:MMZ after AFTER in TEXT, as minutes from now (UTC)."""
    hhmm = text.split(after, 1)[1][:5]
    now = time.gmtime()
    return (int(hhmm[:2]) * 60 + int(hhmm[3:]) - now.tm_hour * 60 - now.tm_min) % 1440


def _running(what: str) -> list:
    """The processes whose command line holds WHAT."""
    found = []
    for cmdline in Path("/proc").glob("[0-9]*/cmdline"):
        try:
            if what in cmdline.read_text().replace("\0", " "):
                found.append(cmdline.parent.name)
        except OSError:
            pass
    return found


def _births(where: Path) -> bool:
    """Whether this file system keeps when a file was made (stat %W), which ETAs need."""
    probe = where / "born"
    probe.write_text("")
    return subprocess.run(["stat", "-c", "%W", str(probe)], capture_output=True,
                          text=True).stdout.strip() not in ("", "0")


def test_a_train_waits_for_the_release_before_it_then_ships_its_spec_as_edited(tmp_path):
    y = Yard(tmp_path)
    gate = tmp_path / "gate"
    births = _births(tmp_path)
    try:
        # Two releases before served 30 minutes after their ships began; the
        # one just before, t-m1, is shipping by hand.
        y.shipped_in("t-m0", 30)
        y.shipped_in("t-m00", 30)
        y.shipping("t-m1")
        staged = y.train("stage", "t-m2", "stage2", "--after", "t-m1", "--checks", "io",
                         "--probes", "first_probe", "--title", "the first title",
                         STUB_GATE=str(gate), STUB_FLAKY="io")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        assert "waits for t-m1 to serve" in staged.stdout
        y.until(lambda: "waits for t-m1 to serve" in y.spec("t-m2", "step"))
        time.sleep(1)  # ten polls, and still waiting
        assert "waits for t-m1 to serve" in y.spec("t-m2", "step")
        assert not (y.wt / "t-m2").exists()
        waiting = y.train("status").stdout
        assert waiting.startswith("live: brickworks.diy serves 0000000\n"), waiting
        assert "t-m1: shipping, begun by hand at " in waiting, waiting
        assert "ship: preview https://preview.invalid/t-m1" in waiting, waiting
        assert "t-m2: stage2 after t-m1, running (pid " in waiting, waiting
        assert "waits for t-m1 to serve (until " in waiting, waiting
        assert "live: not yet; brickworks.diy serves 0000000" in waiting, waiting
        if births:
            assert "a ship takes about 30 min from begun to served" in waiting, waiting
            # t-m1 serves 30 minutes from its start, and t-m2 no sooner than a ship after.
            assert 29 <= _minute(waiting, "eta: serves about ") <= 31, waiting
            later = waiting.split("t-m2:", 1)[1]
            assert "at the earliest" in later and 59 <= _minute(later, "eta: serves ") <= 61, waiting

        # Edited after staging, as a unit merged into stage2 meanwhile would.
        spec = y.ro / "t-m2.train"
        (spec / "checks").write_text("io gallery\n")
        (spec / "probes").write_text("second_probe third_probe\n")
        (spec / "title").write_text("the title as edited\n")
        (spec / "units").write_text("unitA unitB unitC\n")
        y.serves("t-m1")

        # The battery's last check is held: status mid-ship.
        y.until(lambda: (y.ro / "t-m2_pv.out").exists()
                and (y.ro / "t-m2_pv.out").read_text().count(" exit=") == 3)
        sha = y.spec("t-m2", "sha")
        assert sha == y.git(y.wt / "t-m2", "rev-parse", "--short", "HEAD")
        shipping = y.train("status", "t-m2").stdout
        assert "step: " in shipping and "ships %s with 2 checks named" % sha in shipping, shipping
        assert "ship: preview https://preview.invalid/%s" % sha in shipping, shipping
        assert "checks: 2 of 4 passed; failed: io; 1 to run" in shipping, shipping
        assert "live: not yet (%s); brickworks.diy serves 0000000" % sha in shipping, shipping
        if births:
            assert 29 <= _minute(shipping, "eta: serves about ") <= 31, shipping
        gate.write_text("go")

        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert y.text("t-m2_pv_args").split()[2:] == ["io", "gallery", "site", "frames"]
        assert y.text("t-m2_alone_io_args").split()[2:] == ["io"]
        assert sorted((y.ro / "probes_run").read_text().split()) == ["second_probe", "third_probe"]
        assert y.git(y.r, "log", "-1", "--format=%s", "main") == "Merge: the title as edited"
        assert y.git(y.r, "rev-parse", "--short", "main") == sha
        assert "/b/%s/" % sha in y.live.read_text()

        # Retired: the release's worktree, and unitA's, whose work is all on
        # main (locked, as the harness leaves one). Kept: unitB, a commit
        # past it, and unitC, with a file it has not added.
        assert not (y.wt / "t-m2").exists()
        assert not (y.wt / "unitA").exists()
        assert (y.wt / "unitB" / "b.txt").exists()
        assert (y.wt / "unitC" / "notes.txt").exists()
        log = y.logs()
        assert "kept unitB: it has work main lacks" in log, log
        assert "kept unitC: files git does not track (notes.txt" in log, log

        done = y.train("status", "t-m2").stdout
        assert done.startswith("live: brickworks.diy serves %s, t-m2's, since " % sha), done
        assert "eta:" not in done, done
        assert "t-m2: stage2 after t-m1, ended" in done, done
        assert "result: live" in done, done
        assert "checks: 3 of 4 passed; failed: io (passed alone)" in done, done
        assert "live: brickworks.diy serves it (%s)" % sha in done, done
    finally:
        y.stop()


def test_a_hold_stops_it_before_the_merge_and_again_before_the_probes_and_the_ship(tmp_path):
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--after", "t-m1", "--probes", "first_probe",
                       STUB_LISTS_HOLD="1").returncode == 0
        held = y.train("hold", "t-m2", "the owner wants a look")
        assert held.returncode == 0 and "t-m2 held" in held.stdout, held.stdout
        assert (y.ro / "t-m2.hold").read_text().startswith("the owner wants a look, ")
        y.serves("t-m1")
        y.until(lambda: "held before the merge by " in y.spec("t-m2", "step"))
        time.sleep(1)
        assert not (y.wt / "t-m2").exists(), "merged while held"
        status = y.train("status").stdout
        assert "step: " in status and "held before the merge by %s/t-m2.hold: the owner wants a look" % y.ro in status, status
        assert "hold: t-m2.hold: the owner wants a look" in status, status

        assert "t-m2 released" in y.train("release", "t-m2").stdout
        # Merged and listed; the lists set HOLD, so neither the probes nor the ship begin.
        y.until(lambda: "held before the probes and the ship by %s/HOLD" % y.ro in y.spec("t-m2", "step"))
        time.sleep(1)
        assert (y.wt / "t-m2" / "a.txt").exists()
        assert not (y.ro / "probes_run").exists(), "probed while held"
        assert not (y.ro / "t-m2_lead.out").exists(), "shipped while held"
        again = y.train("release", "t-m2").stdout
        assert "HOLD still holds every release (set while it listed)" in again, again
        time.sleep(0.5)
        assert not (y.ro / "t-m2_lead.out").exists(), "shipped under HOLD"
        (y.ro / "HOLD").unlink()
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert y.text("probes_run").split() == ["first_probe"]
    finally:
        y.stop()


def test_a_hold_set_while_the_ship_waits_for_its_probes_still_holds(tmp_path):
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "gated").returncode == 0
        y.until(lambda: "main waits for the probes" in y.text("t-m2_lead.out"))
        assert y.train("hold", "t-m2", "a regression seen on the preview").returncode == 0
        (y.ro / "probe_gate").write_text("go")
        y.until(lambda: y.spec("t-m2", "result"))
        result = y.spec("t-m2", "result")
        assert result.startswith("not live: ship.sh ended exit 1: SHIP: held by %s/t-m2.hold (a regression seen" % y.ro), y.logs()
        assert "SHIP: every probe passed" in y.text("t-m2_lead.out")
        assert not (y.ro / "t-m2.probes").exists()
        y.unmoved()
        assert y.text("t-m2.done").strip() == "1"
    finally:
        y.stop()


def test_the_ship_checks_beside_the_probes_and_promotes_once_they_pass(tmp_path):
    y = Yard(tmp_path)
    try:
        sha_of = lambda: y.spec("t-m2", "sha")
        assert y.train("stage", "t-m2", "stage2", "--checks", "io gallery",
                       "--probes", "gated slow_a fine").returncode == 0
        # Every check ran while the probes still ran, and main waits for them.
        y.until(lambda: "main waits for the probes" in y.text("t-m2_lead.out"))
        assert y.text("t-m2_pv.out").count(" exit=0 ") == 4
        y.until(lambda: "probes: 2 of 3 passed; 1 to run" in y.train("status", "t-m2").stdout)
        waiting = y.train("status", "t-m2").stdout
        assert "ships %s with 2 checks named (and site, frames), its probes beside it" % sha_of() in waiting, waiting
        assert "checks: 4 of 4 passed" in waiting, waiting
        assert "probes: 2 of 3 passed; 1 to run" in waiting, waiting
        assert "ship: the checks passed; main waits for the probes (3 named)" in waiting, waiting
        time.sleep(0.5)
        y.unmoved()
        (y.ro / "probe_gate").write_text("go")
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()

        probes, checks = y.times("probe_times"), y.times("check_times")
        battery = [span["began"] for who, span in checks.items() if who.startswith("t-m2_pv ")]
        probes_ended = max(span["ended"] for span in probes.values())
        promoted = float(y.text("promoted").split()[0])
        assert len(battery) == 4 and max(battery) < probes_ended, (checks, probes)
        assert promoted > probes_ended, (promoted, probes)
        assert y.git(y.r, "rev-parse", "--short", "main") == sha_of()
        assert "/b/%s/" % sha_of() in y.live.read_text()
        assert not (y.ro / "t-m2.probes").exists()
        log = y.logs()
        assert "every probe passed" in log and "SHIP: every probe passed" in log, log
        done = y.train("status", "t-m2").stdout
        assert "probes: 3 of 3 passed" in done and "result: live" in done, done
    finally:
        y.stop()


def test_a_probe_failing_while_the_ship_runs_stops_it_before_main_moves(tmp_path):
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--checks", "io",
                       "--probes", "fine gated_fails").returncode == 0
        y.until(lambda: "main waits for the probes" in y.text("t-m2_lead.out"))
        (y.ro / "probe_gate").write_text("go")
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "stopped: probes failed: gated_fails (t-m2_probe_NAME.log)", y.logs()
        log = y.logs()
        assert "probe gated_fails exit=0 FAIL=1 beside others: again alone" in log, log
        assert "SHIP: held, the probes failed: gated_fails" in y.text("t-m2_lead.out"), log
        # The battery began while the probe still ran: the ship ran beside it.
        began = min(span["began"] for who, span in y.times("check_times").items() if who.startswith("t-m2_pv "))
        assert began < y.times("probe_times")["gated_fails"]["ended"]
        y.unmoved()
        assert y.text("t-m2.done").strip() == "1"
        assert y.text("t-m2.probes").strip() == "failed: gated_fails"
        status = y.train("status", "t-m2").stdout
        assert "result: stopped: probes failed: gated_fails" in status, status
        assert "probes: 1 of 2 passed; failed: gated_fails" in status, status

        # Failed before the battery began: none of it runs.
        (y.ro / "probe_gate").unlink()
        assert y.train("stage", "t-m3", "stage2", "--checks", "io", "--probes", "fails").returncode == 0
        y.until(lambda: y.spec("t-m3", "result"))
        assert y.spec("t-m3", "result") == "stopped: probes failed: fails (t-m3_probe_NAME.log)", y.logs()
        y.unmoved()
    finally:
        y.stop()


def test_a_tree_left_dirty_or_mid_merge_or_a_failed_probe_is_never_shipped(tmp_path):
    y = Yard(tmp_path)
    try:
        for tag, how, args, why in (
                ("t-m2", "STUB_DIRTY", (), "%s has uncommitted changes" % (y.wt / "t-m2")),
                ("t-m3", "STUB_HALF", (), "%s is mid-merge" % (y.wt / "t-m3")),
                ("t-m4", "STUB_NONE", ("--probes", "fine fails skips"), "probes failed: fails skips (t-m4_probe_NAME.log)")):
            assert y.train("stage", tag, "stage2", *args, **{how: "1"}).returncode == 0
            y.until(lambda: y.spec(tag, "result"))
            assert y.spec(tag, "result") == "stopped: " + why, y.logs()
            if how == "STUB_NONE":
                # The ship began beside the probes, and stopped before main moved.
                assert "SHIP: held, the probes failed: fails skips" in y.text(tag + "_lead.out"), y.logs()
                assert y.text(tag + ".done").strip() == "1"
            else:
                assert not (y.ro / (tag + "_pv_args")).exists()
                assert not (y.ro / (tag + "_lead.out")).exists()
                assert (y.ro / (tag + ".gave_up")).read_text().strip() == y.spec(tag, "result")
            assert (y.wt / tag).exists(), "kept for the lead to read"
        y.unmoved()
        assert "result: stopped: %s has uncommitted changes" % (y.wt / "t-m2") in y.train("status").stdout
    finally:
        y.stop()


def test_probes_run_four_at_a_time_and_one_failing_beside_others_runs_again_alone(tmp_path):
    y = Yard(tmp_path)
    try:
        probes = "slow_a slow_b slow_c slow_d slow_e flaky"
        assert y.train("stage", "t-m2", "stage2", "--probes", probes).returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        spans = {}
        for line in (y.ro / "probe_times").read_text().splitlines():
            name, what, when = line.split()
            spans.setdefault(name, {})[what] = float(when)
        def together(at: float) -> int:
            return sum(1 for s in spans.values() if s["began"] <= at < s["ended"])
        most = max(together(s["began"]) for s in spans.values())
        assert most == 4, "at most %d probes at once: %s" % (most, spans)
        log = y.logs()
        assert "probe flaky exit=0 FAIL=1 beside others: again alone" in log, log
        assert "probe flaky exit=0 FAIL=0" in log, log
        assert (y.ro / "t-m2_probe_flaky.beside.log").read_text().count("FAIL") == 1
        assert (y.ro / "probes_run").read_text().split().count("flaky") == 2

        # One at a time, a failure is not run again.
        (y.ro / "flaky_ran").unlink()
        assert y.train("stage", "t-m3", "stage2", "--probes", "flaky",
                       TRAIN_PROBES_AT_ONCE="1").returncode == 0
        y.until(lambda: y.spec("t-m3", "result"))
        assert y.spec("t-m3", "result") == "stopped: probes failed: flaky (t-m3_probe_NAME.log)", y.logs()
    finally:
        y.stop()


def test_a_commit_to_the_branch_while_it_merges_waits_for_the_next_release(tmp_path):
    y = Yard(tmp_path)
    gate = tmp_path / "merge_gate"
    try:
        tip = y.git(y.r, "rev-parse", "stage2")
        assert y.train("stage", "t-m2", "stage2", STUB_MERGE_GATE=str(gate)).returncode == 0
        y.until(lambda: Path(str(gate) + ".merged").exists())
        y.git(y.r, "branch", "-f", "stage2", "unitB")  # the lead commits to stage2 meanwhile
        gate.write_text("go")
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert y.spec("t-m2", "tip") == tip
        assert "merges stage2 at %s" % tip[:8] in y.logs(), y.logs()
        shipped = y.git(y.r, "ls-tree", "--name-only", "main").split()
        assert "a.txt" in shipped and "b.txt" not in shipped, shipped
    finally:
        y.stop()


def test_restaging_a_stopped_train_clears_its_merge_but_never_work_of_its_own(tmp_path):
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--probes", "fails").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result").startswith("stopped: probes failed: fails"), y.logs()
        assert (y.wt / "t-m2").exists()
        again = y.train("stage", "t-m2", "stage2")
        assert again.returncode == 0, again.stdout
        assert "train: cleared t-m2's attempt before (its merge alone)" in again.stdout, again.stdout
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()

        # A fix committed in a stopped release's worktree, or one left
        # uncommitted there, is never restaged over.
        assert y.train("stage", "t-m3", "stage2", "--probes", "fails").returncode == 0
        y.until(lambda: y.spec("t-m3", "result"))
        (y.wt / "t-m3" / "fix.txt").write_text("a fix made in the release\n")
        y.git(y.wt / "t-m3", "add", "fix.txt")
        dirty = y.train("stage", "t-m3", "stage2")
        assert dirty.returncode == 1 and "t-m3 has changes of its own" in dirty.stdout, dirty.stdout
        y.git(y.wt / "t-m3", "commit", "-q", "-m", "a fix made in the release")
        own = y.train("stage", "t-m3", "stage2")
        assert own.returncode == 1 and "a branch t-m3 has commits stage2 lacks" in own.stdout, own.stdout
        assert "a fix made in the release" in own.stdout, own.stdout
        assert (y.wt / "t-m3" / "fix.txt").exists()
        assert y.spec("t-m3", "result").startswith("stopped: probes failed"), "restaged over"
    finally:
        y.stop()


def test_a_check_or_probe_the_branch_has_no_name_for_is_refused_when_staged(tmp_path):
    y = Yard(tmp_path)
    try:
        y.put("tools/release/preview_checks.sh", 'CMD=(\n  [io]="tools/web/io.mjs"\n  [sets_flow]="x"\n)\n')
        y.put("src/dev/fits_probe.gd", "extends SceneTree\n")
        y.put("src/dev/offgrid.gd", "extends SceneTree\n")
        y.put("src/dev/together_probe.gd", "extends SceneTree\n")
        y.put("tools/suite/out.txt", "together   # needs the relay\n")
        y.git(y.r, "checkout", "-q", "stage2")
        y.git(y.r, "add", "tools/release/preview_checks.sh", "src/dev", "tools/suite")
        y.git(y.r, "commit", "-q", "-m", "the branch's lists")
        y.git(y.r, "checkout", "-q", "main")
        bad = y.train("stage", "t-m2", "stage2", "--checks", "io sets share", "--probes", "fits nope offgrid")
        assert bad.returncode == 2, bad.stdout + bad.stderr
        assert "train: stage2 has no check sets, check share, probe nope" in bad.stdout, bad.stdout
        # 2026-10-30: together, kept out of runs for want of the relay, skipped itself and held rel-m225.
        out = y.train("stage", "t-m2", "stage2", "--probes", "fits together")
        assert out.returncode == 2, out.stdout + out.stderr
        assert "train: stage2 has no runnable probe together (needs the relay)" in out.stdout, out.stdout
        assert not (y.ro / "t-m2.train" / "pid").exists() and y.spec("t-m2", "checks") == ""
        good = y.train("stage", "t-m2", "stage2", "--checks", "io sets_flow", "--probes", "fits offgrid")
        assert good.returncode == 0, good.stdout + good.stderr
    finally:
        y.stop()


def test_it_stops_when_the_release_before_did_not_ship_or_its_wait_runs_out(tmp_path):
    y = Yard(tmp_path)
    try:
        y.ro.mkdir(parents=True)
        (y.ro / "t-m1.done").write_text("1\n")  # held: ship.sh ended 1, never serving
        assert y.train("stage", "t-m2", "stage2", "--after", "t-m1").returncode == 0
        assert y.train("stage", "t-m3", "stage2", "--after", "t-m2").returncode == 0
        assert y.train("stage", "t-m5", "stage2", "--after", "t-m4", TRAIN_WAIT="1").returncode == 0
        for tag in ("t-m2", "t-m3", "t-m5"):
            y.until(lambda: y.spec(tag, "result"))
        assert y.spec("t-m2", "result") == \
            "stopped: t-m1's ship ended exit 1, and brickworks.diy never served it"
        assert y.spec("t-m3", "result").startswith("stopped: t-m2 never shipped: stopped: t-m1's ship")
        assert y.spec("t-m5", "result") == "stopped: gave up waiting for t-m4 at the deadline"
        assert not any((y.wt / t).exists() for t in ("t-m2", "t-m3", "t-m5"))
        assert not (y.ro / "probes_run").exists()

        # Stopped by hand, as `kill -- -PID` stops it, it says so, and the one
        # behind stops; killed outright, it says nothing, and the one behind
        # stops all the same.
        for prev, behind, how, why in (
                ("t-m7", "t-m8", signal.SIGTERM, "stopped: t-m7 never shipped: stopped: killed"),
                ("t-m9", "t-m10", signal.SIGKILL, "stopped: t-m9's train is not running and wrote no result")):
            assert y.train("stage", prev, "stage2", "--after", "t-m99").returncode == 0
            assert y.train("stage", behind, "stage2", "--after", prev).returncode == 0
            y.until(lambda: "waits" in y.spec(prev, "step") and "waits" in y.spec(behind, "step"))
            os.killpg(int(y.spec(prev, "pid")), how)
            y.until(lambda: y.spec(behind, "result"))
            assert y.spec(behind, "result") == why, y.logs()

        missing = y.train("stage", "t-m6", "no-such-branch")
        assert missing.returncode == 2 and "no branch no-such-branch" in missing.stdout
    finally:
        y.stop()


def test_its_checks_run_on_the_live_site_as_it_is_staged_and_status_says_which_fail_there(tmp_path):
    y = Yard(tmp_path)
    try:
        y.git(y.r, "worktree", "add", "-q", str(y.wt / "stage2"), "stage2")
        # A check the branch changed since the build brickworks.diy serves.
        (y.wt / "stage2" / "tools/web").mkdir(parents=True)
        (y.wt / "stage2" / "tools/web/light_render_flow.mjs").write_text("// a check of what stage2 adds\n")
        y.git(y.wt / "stage2", "add", "tools/web")
        y.git(y.wt / "stage2", "commit", "-q", "-m", "a new check")
        build = y.git(y.r, "rev-parse", "--short", "main")
        y.live.write_text('<script src="/b/%s/index.js"></script>\n' % build)
        # Staged behind a release still shipping: its checks run on the live
        # site now, not two hours on at its own ship.
        y.shipping("t-m1")
        staged = y.train("stage", "t-m2", "stage2", "--after", "t-m1",
                         "--checks", "io people gallery light_render",
                         STUB_STALE_FAILS="people light_render")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        assert "its checks run on https://brickworks.diy meanwhile" in staged.stdout, staged.stdout
        y.until(lambda: y.text("t-m2_stale.out").endswith("done\n"))
        assert y.text("t-m2_stale_args").split() == [
            "https://brickworks.diy", str(y.wt / "stage2"), "io", "people", "gallery", "light_render"]
        status = y.train("status", "t-m2").stdout
        assert "waits for t-m1 to serve" in status, status
        assert ("on https://brickworks.diy (serving %s) as staged: 2 of 4 passed; already failing there: "
                "people; failing there, changed since: light_render (t-m2_stale_NAME.log)" % build) in status, status
        assert not (y.ro / "probes_run").exists() and not (y.wt / "t-m2").exists()

        # A branch no worktree has checked out is not checked there, and says why.
        y.git(y.r, "worktree", "remove", str(y.wt / "stage2"))
        assert y.train("stage", "t-m3", "stage2", "--after", "t-m1", "--checks", "io").returncode == 0
        y.until(lambda: y.text("t-m3_stale.skipped"))
        status = y.train("status", "t-m3").stdout
        assert "on https://brickworks.diy: not checked: no worktree has stage2 checked out" in status, status
    finally:
        y.stop()


def test_a_ship_that_ends_first_stops_the_probes_beside_it(tmp_path):
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "gated",
                       STUB_CI_FAIL="1").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == ("not live: ship.sh ended exit 1: SHIP: held, the version, "
                                            "the Python suite or a shell script (ci_gate.sh)"), y.logs()
        assert y.text("t-m2.probes").strip() == "stopped: the ship ended first"
        # Stopped, not left to run on: it never ended, and nothing of it runs.
        assert "gated" in y.times("probe_times") and "ended" not in y.times("probe_times")["gated"]
        time.sleep(0.5)
        assert not _running(str(y.r / "tools/probe.sh"))
        y.unmoved()
    finally:
        y.stop()


def test_the_checks_run_at_once_as_asked_and_none_begins_once_the_probes_failed(tmp_path):
    """The real preview_checks.sh, its node and heavy stood in for."""
    y = Yard(tmp_path)
    y.put("tools/release/preview_checks.sh", (ROOT / "tools/release/preview_checks.sh").read_text())
    (y.r / ".env").write_text("VERCEL_BYPASS=bypass\n")
    node = tmp_path / "bin" / "node"
    node.write_text("""#!/bin/bash
# stand-in: a check that takes a moment, noting when; the one named in
# STUB_FAILS_PROBES says the probes failed as it runs.
name=$(basename "$1" .mjs)
echo "$name began $(date +%s.%N)" >> "$RELEASE_OUT/check_spans"
[ "$name" = "${STUB_FAILS_PROBES:-}" ] && echo "failed: fails" > "$SHIP_PROBES"
sleep 0.5
echo "$name ended $(date +%s.%N)" >> "$RELEASE_OUT/check_spans"
echo "$name: all passed"
""")
    node.chmod(0o755)
    heavy = tmp_path / "home/.claude/claude-core/bin/heavy"
    heavy.write_text('#!/bin/bash\n# stand-in: a slot at once, solo or not\n[ "$1" = --solo ] && shift\nexec "$@"\n')
    y.ro.mkdir(parents=True)
    env = {**y.env, "RELEASE_OUT": str(y.ro), "TMPDIR": str(tmp_path)}

    def battery(tag: str, *names: str, **extra: str) -> list:
        subprocess.run(["bash", str(y.r / "tools/release/preview_checks.sh"), "https://preview.invalid",
                        str(y.r), tag, *names], env={**env, **extra}, check=True, timeout=60,
                       capture_output=True)
        return y.text(tag + ".out").splitlines()

    five = ("io", "gallery", "keys", "palette", "docs")
    out = battery("t-wide", *five)
    assert sorted(line.split()[0] for line in out[:-1]) == sorted(five) and out[-1] == "done", out
    assert all(" exit=0 " in line for line in out[:-1]), out
    spans = y.times("check_spans")
    most = max(sum(1 for s in spans.values() if s["began"] <= t["began"] < s["ended"]) for t in spans.values())
    assert most == 3, spans
    (y.ro / "check_spans").unlink()
    battery("t-two", *five, PC_AT_ONCE="2")
    spans = y.times("check_spans")
    assert max(sum(1 for s in spans.values() if s["began"] <= t["began"] < s["ended"]) for t in spans.values()) == 2

    # The probes fail while io runs: io ends as it would, and nothing more begins, frames (alone) neither.
    probes = y.ro / "t-m9.probes"
    probes.write_text("running 1: a\n")
    out = battery("t-held", "io", "gallery", "keys", "frames", PC_AT_ONCE="1", SHIP_PROBES=str(probes),
                  STUB_FAILS_PROBES="io_flow")
    assert out[0].startswith("io exit=0 "), out
    assert [line.split()[:2] for line in out[1:-1]] == [["gallery", "exit=125"], ["keys", "exit=125"],
                                                       ["frames", "exit=125"]], out
    assert all("not run: the release's probes failed" in line for line in out[1:-1]) and out[-1] == "done", out
