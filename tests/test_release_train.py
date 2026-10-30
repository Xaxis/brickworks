"""The release train: tools/release/train.sh stages a release and ships it in turn.

Each test makes a repository of its own with an origin, a staged branch and
unit worktrees, and stand-ins for what a real release spends an hour on:
release_wt.sh makes the worktree alone, merge_unit.sh merges as git does,
ship.sh writes the lines the real one writes (its preview, each check's
exit, main fast-forwarded, "brickworks.diy serves SHA") and puts the sha in
a file that stands for brickworks.diy/app. tools/check.sh and tools/probe.sh
pass and say what ran. retire_wt.sh is the real one. The train itself runs
detached, as staged, and is read through its files and `train.sh status`.

What they prove: the train waits for the release before it to serve and
then ships; edits to its spec after staging are what it ships; a hold stops
it before the merge and before the ship; a tree left dirty or mid-merge, or
a probe that failed or skipped itself, is never shipped; it stops when the
release before did not ship, was stopped or died, or at its deadline; and
status says each step, the checks, and what is live. Its probes run three
at a time, one failing beside others again alone. It ships the tip it
merged when the branch moves on meanwhile, and a restage clears a stopped
attempt's own merge but never a fix made in it.
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
    not (shutil.which("setsid") and shutil.which("curl") and shutil.which("git")),
    reason="the train needs setsid, curl and git")

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
    "tools/release/ship.sh": """#!/bin/bash
# stand-in: the lines ship.sh writes, at once. STUB_FLAKY fails one check
# beside others and passes it alone; STUB_GATE holds the last check until
# that file is there.
W=$1 TAG=$2; shift 2
S=$RELEASE_OUT
for always in site frames; do
  case " $* " in *" $always "*) ;; *) set -- "$@" "$always";; esac
done
R=$(dirname "$(git -C "$W" rev-parse --path-format=absolute --git-common-dir)")
SHA=$(git -C "$W" rev-parse --short HEAD)
echo "$*" > "$S/${TAG}_ship_args"
echo "SHIP: preview https://preview.invalid/$TAG"
: > "$S/${TAG}_pv.out"
n=0
for c in "$@"; do
  n=$((n + 1))
  if [ "$n" -eq $# ] && [ -n "${STUB_GATE:-}" ]; then
    for _ in $(seq 1 600); do [ -e "$STUB_GATE" ] && break; sleep 0.05; done
  fi
  if [ "$c" = "${STUB_FLAKY:-}" ]; then
    echo "$c exit=1 fails=1 1s :: FAIL beside others" >> "$S/${TAG}_pv.out"
    echo "$c exit=0 fails=0 1s :: passed alone" > "$S/${TAG}_alone_$c.out"
  else
    echo "$c exit=0 fails=0 1s :: passed" >> "$S/${TAG}_pv.out"
  fi
done
echo done >> "$S/${TAG}_pv.out"
for hold in "$S/HOLD" "$S/$TAG.hold"; do
  [ -e "$hold" ] && { echo "SHIP: held by $hold"; echo 1 > "$S/$TAG.done"; exit 1; }
done
git -C "$R" merge -q --ff-only "$SHA" || { echo "SHIP: could not fast-forward main"; echo 1 > "$S/$TAG.done"; exit 1; }
echo "SHIP: main is $SHA"
echo "deploy: brickworks.diy serves $SHA" > "$S/${TAG}_prod.log"
echo "<script src=\\"/b/$SHA/index.js\\"></script>" > "$STUB_LIVE"
echo "SHIP: deploy: brickworks.diy serves $SHA"
echo 0 > "$S/$TAG.done"
""",
    "tools/check.sh": """#!/bin/bash
# stand-in: every probe is in a list
exit 0
""",
    "tools/probe.sh": """#!/bin/bash
# stand-in: says which probe ran. The probe sets_a_hold sets HOLD, as the
# lead would while a release is between its merge and its ship. fails says
# FAIL and exits 0; skips exits 3 and says no FAIL, as probe.sh does for a
# probe that skipped itself.
# slow_* runs a second and notes when it began and ended; flaky fails the
# first time it runs and passes after.
echo "$1" >> "$RELEASE_OUT/probes_run"
case "$1" in slow_*)
  echo "$1 began $(date +%s.%N)" >> "$RELEASE_OUT/probe_times"; sleep 1
  echo "$1 ended $(date +%s.%N)" >> "$RELEASE_OUT/probe_times" ;;
esac
if [ "$1" = flaky ] && [ ! -e "$RELEASE_OUT/flaky_ran" ]; then
  : > "$RELEASE_OUT/flaky_ran"; echo "  FAIL the stand-in failed beside others"; exit 0
fi
if [ "$1" = sets_a_hold ]; then echo "set while it probed" > "$RELEASE_OUT/HOLD"; fi
if [ "$1" = fails ]; then echo "  FAIL the stand-in failed"; exit 0; fi
if [ "$1" = skips ]; then echo "skips probe: SKIPPED"; exit 3; fi
echo "$1: all passed"
""",
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
        env = {k: v for k, v in os.environ.items()
               if not k.startswith(("GIT_", "TRAIN_", "STUB_", "RELEASE_OUT", "LIVE_WAIT"))}
        env.update(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                   GIT_AUTHOR_NAME="Xaxis", GIT_AUTHOR_EMAIL="william.neeley@gmail.com",
                   GIT_COMMITTER_NAME="Xaxis", GIT_COMMITTER_EMAIL="william.neeley@gmail.com",
                   TRAIN_LIVE="file://%s" % self.live, STUB_LIVE=str(self.live),
                   TRAIN_POLL="0.1")
        self.env = env
        self.git(where, "init", "-q", "--bare", "--initial-branch=main", str(where / "origin.git"))
        self.git(where, "init", "-q", "--initial-branch=main", str(self.r))
        for name in ("train.sh", "retire_wt.sh"):
            self.put("tools/release/" + name, (ROOT / "tools" / "release" / name).read_text())
        for name, text in STUBS.items():
            self.put(name, text)
        self.put(".gitignore", "bench/results/\n.claude/worktrees/\n")
        self.put("README", "a release yard\n")
        self.git(self.r, "add", "-A")
        self.git(self.r, "commit", "-q", "-m", "the yard")
        self.git(self.r, "remote", "add", "origin", str(where / "origin.git"))
        self.git(self.r, "push", "-q", "-u", "origin", "main")
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

    def until(self, what, seconds: float = 30) -> None:
        end = time.time() + seconds
        while not what():
            assert time.time() < end, "waited %ss; trains said:\n%s" % (seconds, self.logs())
            time.sleep(0.05)

    def logs(self) -> str:
        return "\n".join(p.read_text() for p in sorted(self.ro.glob("*_train.out")))

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
        """Ends every train still running, as `kill -- -PID` would."""
        for pid_file in self.ro.glob("*.train/pid"):
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
        assert "ship: preview https://preview.invalid/t-m2" in shipping, shipping
        assert "checks: 2 of 4 passed; failed: io (passed alone); 1 to run" in shipping, shipping
        assert "live: not yet (%s); brickworks.diy serves 0000000" % sha in shipping, shipping
        if births:
            assert 29 <= _minute(shipping, "eta: serves about ") <= 31, shipping
        gate.write_text("go")

        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert (y.ro / "t-m2_ship_args").read_text().split() == ["io", "gallery", "site", "frames"]
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


def test_a_hold_stops_it_before_the_merge_and_again_before_the_ship(tmp_path):
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--after", "t-m1", "--probes", "sets_a_hold").returncode == 0
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
        # Merged and probed; the probe set HOLD, so it waits before the ship.
        y.until(lambda: "held before the ship by %s/HOLD" % y.ro in y.spec("t-m2", "step"))
        time.sleep(1)
        assert (y.wt / "t-m2" / "a.txt").exists()
        assert not (y.ro / "t-m2_ship_args").exists(), "shipped while held"
        again = y.train("release", "t-m2").stdout
        assert "HOLD still holds every release (set while it probed)" in again, again
        time.sleep(0.5)
        assert not (y.ro / "t-m2_ship_args").exists(), "shipped under HOLD"
        (y.ro / "HOLD").unlink()
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert (y.ro / "t-m2_ship_args").exists()
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
            assert not (y.ro / (tag + "_ship_args")).exists()
            assert not (y.ro / (tag + "_lead.out")).exists()
            assert (y.ro / (tag + ".gave_up")).read_text().strip() == y.spec(tag, "result")
            assert (y.wt / tag).exists(), "kept for the lead to read"
        assert y.git(y.r, "rev-parse", "main") == y.git(y.r, "rev-parse", "origin/main")
        assert "result: stopped: %s has uncommitted changes" % (y.wt / "t-m2") in y.train("status").stdout
    finally:
        y.stop()


def test_probes_run_three_at_a_time_and_one_failing_beside_others_runs_again_alone(tmp_path):
    y = Yard(tmp_path)
    try:
        probes = "slow_a slow_b slow_c slow_d flaky"
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
        assert most == 3, "at most %d probes at once: %s" % (most, spans)
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
