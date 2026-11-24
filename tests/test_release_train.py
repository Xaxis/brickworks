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
did not ship, was stopped or died, or at its deadline; stopped by hand, it
says so and nothing of it runs on, its probes included, nor a ship's
promotion; a unit's preview killed while it deploys takes its deploy with
it, and the next run reads its own deploy's URL alone; and status says each
step, the checks, the probes and what is live. Its probes run beside the
ship, four at a time, one failing beside others again alone, and main moves
only once every one has passed. It ships the tip it merged when the branch
moves on meanwhile, and a restage clears a stopped attempt's own merge but
never a fix made in it. Every check failing on the preview runs again alone,
whatever else failed (a timing check never), and what still fails runs on
the live site only after the preview's battery, as a unit's check, the
train's mark on the live database gone; status says which already fail
there. It ships past such a check with --accept only where the live site
fails it too, naming it in the merge message, the log and status. A timing
check still failing runs on the preview and the live site by turns instead,
P L L P, and holds the release only where the preview is worse beyond the
noise; shipped past, its numbers are in the log, status and the commit main
moves to, whose build is the merge's. Staging
adds to the checks named those flows_for.py finds for what the branch changed,
and says which. Named no probes, it runs every headless one the branch's
tools/suite/headless.txt lists, never a windowed one or one out.txt keeps
out; a list named is kept as it is, none is run only when named none with a
reason, which the log and status say, and --probes "" is refused.
"""

from __future__ import annotations

import os
import re
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
echo "MERGE_ONLY=${MERGE_ONLY:-}" >> "$RELEASE_OUT/merge_env"
if [ -n "${STUB_HALF:-}" ]; then git merge -q --no-ff --no-commit "$2"; exit 0; fi
git merge -q --no-ff -m "$3" "$2" || exit 2
if [ -n "${STUB_MERGE_GATE:-}" ]; then
  : > "$STUB_MERGE_GATE.merged"
  for _ in $(seq 1 6000); do [ -e "$STUB_MERGE_GATE" ] && break; sleep 0.05; done
fi
if [ -n "${STUB_DIRTY:-}" ]; then echo dirt >> README; fi
exit 0
""",
    "tools/release/ci_gate.sh": """#!/bin/bash
# stand-in: the version, the suite and the scripts pass; with STUB_CI_FAIL
# they fail, once a probe has begun beside them.
[ -z "${STUB_CI_FAIL:-}" ] && exit 0
for _ in $(seq 1 6000); do [ -e "$RELEASE_OUT/probe_times" ] && break; sleep 0.05; done
[ -z "${STUB_CI_SAYS:-}" ] || printf '%s\n' "$STUB_CI_SAYS"
exit 1
""",
    "tools/release/parse_gate.sh": "#!/bin/bash\n# stand-in: every script parses\nexit 0\n",
    "tools/release/release_links.sh": "#!/bin/bash\n# stand-in: every download answers\nexit 0\n",
    "tools/fresh_import.sh": "#!/bin/bash\n# stand-in: the class list is up to date\necho \"import $PWD\" >> \"$RELEASE_OUT/imports\"\nexit 0\n",
    "tools/deploy.sh": """#!/bin/bash
# stand-in: a preview of this commit, or that preview promoted (--promote,
# --prod), which then stands for brickworks.diy/app; when, in promoted. A
# preview promoted serves the commit it was made from, as the real one does.
# STUB_DEPLOY_GATE holds a preview, STUB_PROMOTE_GATE a promotion, until that
# file is there, as a real one takes minutes: it says STUB_DEPLOY_SAYS lines
# first, its pid in deploy_pids, and a preview so held has a URL of its own.
SHA=$(git rev-parse --short HEAD)
echo "$*" >> "$RELEASE_OUT/deploy_args"
# Its export in build/web, as tools/export.sh makes it, unless given one (--dir) or promoting.
case " $* " in *" --dir="*|*" --promote="*) ;; *) mkdir -p build/web && echo "$SHA" > build/web/index.html ;; esac
case "${1:-}" in --promote=*) SHA=${1##*/} ;; esac
case "${1:-}" in --promote=*|--prod) gate=${STUB_PROMOTE_GATE:-} ;; *) gate=${STUB_DEPLOY_GATE:-} ;; esac
if [ -n "$gate" ]; then
  echo $$ >> "$RELEASE_OUT/deploy_pids"
  for i in $(seq 1 "${STUB_DEPLOY_SAYS:-1}"); do echo "deploy: the stand-in's work, line $i of its own"; done
  for _ in $(seq 1 2400); do [ -e "$gate" ] && break; sleep 0.05; done
fi
case "${1:-}" in
  --promote=*|--prod)
    echo "$(date +%s.%N) $SHA" >> "$RELEASE_OUT/promoted"
    echo "<script src=\\"/b/$SHA/index.js\\"></script>" > "$STUB_LIVE"
    echo "deploy: brickworks.diy serves $SHA" ;;
  *) echo "deploy done https://preview.invalid/$SHA${STUB_DEPLOY_GATE:+-$$}" ;;
esac
""",
    "tools/release/preview_checks.sh": """#!/bin/bash
# stand-in: one line a check as the real one writes it, at once, and when
# each began and ended in check_times, with the priority it ran at. STUB_FLAKY
# fails those in the battery and passes them alone; STUB_FAILS fails those
# on the preview, alone too, and STUB_MISSING writes no line for those in
# the battery; STUB_GATE holds the battery's last check until that file is
# there; STUB_STALE_FAILS fails those on the live site. Each writes its
# log, the stand-in's own work in ms against a bar of 100: 150 where it
# fails, else 60; run by turns on the preview and on the live site
# (live_ab.sh, TAG_ab_NAME_<P|L>N), the next of STUB_AB_HERE's or
# STUB_AB_THERE's numbers (50 when none is left), failing over the bar.
P=$1 WT=$2 OUT=$3; shift 3
S=$RELEASE_OUT
# The checks it has, as the real one's table names them for train.sh stage,
# and those that run the engine from the tree, as the real one says them.
ENGINE_CHECKS="together"
declare -A CMD=(
  [together]="tools/web/together_flow.mjs --url=$P"
  [io]="tools/web/io_flow.mjs --url=$P/app"
  [gallery]="tools/web/gallery_flow.mjs --url=$P"
  [people]="tools/web/people_flow.mjs --url=$P"
  [light_render]="tools/web/light_render_flow.mjs --url=$P/app"
  [keys]="tools/web/keys_flow.mjs --url=$P/app"
  [progress]="tools/web/progress_check.mjs --url=$P/app"
  [site]="tools/web/site_check.mjs --url=$P"
  [model_view]="tools/web/model_view_check.mjs --url=$P/app"
  [console]="tools/web/console_flow.mjs --url=$P"
)
echo "$P $WT $*" > "$S/${OUT}_args"
: > "$S/$OUT.out"
n=0
for c in "$@"; do
  n=$((n + 1))
  echo "$OUT $c began $(date +%s.%N)" >> "$S/check_times"
  marks=0
  for f in "$(git rev-parse --path-format=absolute --git-common-dir)"/live-db.release/*; do
    [ -e "$f" ] && kill -0 "${f##*/}" 2>/dev/null && marks=$((marks + 1))
  done
  echo "$OUT $c priority=${BOX_HEAVY_PRIORITY:-0} marks=$marks" >> "$S/check_how"
  fail=""; ms=""
  case "$OUT" in
    *_ab_*)
      side=${OUT##*_}; side=${side:0:1}
      nums=${STUB_AB_HERE:-}; [ "$side" = L ] && nums=${STUB_AB_THERE:-}
      k=$(cat "$S/${OUT%_*}.$side" 2>/dev/null || echo 0); echo $((k + 1)) > "$S/${OUT%_*}.$side"
      read -r -a each <<< "$nums"; ms=${each[$k]:-50}
      [ "${ms%.*}" -gt 100 ] && fail="FAIL by turns" ;;
    *_pv)
      if [ "$n" -eq $# ] && [ -n "${STUB_GATE:-}" ]; then
        for _ in $(seq 1 6000); do [ -e "$STUB_GATE" ] && break; sleep 0.05; done
      fi
      case " ${STUB_MISSING:-} " in *" $c "*) continue ;; esac
      case " ${STUB_FLAKY:-} ${STUB_FAILS:-} " in *" $c "*) fail="FAIL beside others" ;; esac ;;
    *_alone_*) case " ${STUB_FAILS:-} " in *" $c "*) fail="FAIL alone too" ;; esac ;;
    *_stale) case " ${STUB_STALE_FAILS:-} " in *" $c "*) fail="FAIL on the live site" ;; esac ;;
  esac
  if [ -n "$fail" ]; then echo "$c exit=1 fails=1 1s :: $fail" >> "$S/$OUT.out"
  else echo "$c exit=0 fails=0 1s :: passed" >> "$S/$OUT.out"; fi
  if [ -n "$fail" ]; then said=FAIL; ms=${ms:-150}; else said=ok; ms=${ms:-60}; fi
  echo "  $said  the stand-in's own work stays under 100 ms on average ($ms ms)  [1s]" > "$S/${OUT}_$c.log"
  echo "$OUT $c ended $(date +%s.%N)" >> "$S/check_times"
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
# there and held_* until RELEASE_OUT/held_gate, each noting when it began
# and ended; flaky fails the first time it runs and passes after.
echo "$1" >> "$RELEASE_OUT/probes_run"
echo $$ >> "$RELEASE_OUT/probe_pids"
case "$1" in slow_*|gated*|held_*)
  echo "$1 began $(date +%s.%N)" >> "$RELEASE_OUT/probe_times"
  gate=$RELEASE_OUT/probe_gate; case "$1" in held_*) gate=$RELEASE_OUT/held_gate ;; esac
  case "$1" in
    slow_*) sleep 1 ;;
    *) for _ in $(seq 1 6000); do [ -e "$gate" ] && break; sleep 0.05; done ;;
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
               # PC_ and BW_ too: ship.sh exports PC_AT_ONCE=6 before its gate, and a yard that kept it ran five
               # checks at once where the default is three (rel-m325's gate, 2026-11-23).
               if not k.startswith(("GIT_", "TRAIN_", "STUB_", "SHIP_", "RELEASE_", "LIVE_WAIT", "LIVE_DB", "BOX_",
                                    "PC_", "BW_"))}
        env.update(GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1",
                   GIT_AUTHOR_NAME="Xaxis", GIT_AUTHOR_EMAIL="william.neeley@gmail.com",
                   GIT_COMMITTER_NAME="Xaxis", GIT_COMMITTER_EMAIL="william.neeley@gmail.com",
                   HOME=str(where / "home"), PATH="%s:%s" % (where / "bin", os.environ["PATH"]),
                   TRAIN_LIVE="https://brickworks.diy/app", STUB_LIVE=str(self.live),
                   TRAIN_POLL="0.1", SHIP_POLL="0.1", SHIP_CDN_WAIT="0", LIVE_DB_POLL="0.1",
                   # The yard has no heavy queue for an outer timeout to count.
                   ALLOW_QUEUE_TIMEOUT="1")
        self.env = env
        self.git(where, "init", "-q", "--bare", "--initial-branch=main", str(where / "origin.git"))
        self.git(where, "init", "-q", "--initial-branch=main", str(self.r))
        for name in ("train.sh", "retire_wt.sh", "ship.sh", "preview_lib.sh", "deploy_reads.sh", "flows_for.py",
                     "live_ab.sh", "timing_judge.py", "live_export.sh", "live_db.sh", "live_db_lib.sh", "queue_wrap.sh",
                     "lean.py"):
            self.put("tools/release/" + name, (ROOT / "tools" / "release" / name).read_text())
        for name, text in STUBS.items():
            self.put(name, text)
        # The suite's lists, empty: a train named no probes runs every
        # headless one, here none.
        for name in ("headless", "windowed", "out"):
            self.put("tools/suite/%s.txt" % name, "# the yard's %s probes, one a line\n" % name)
        self.put(".gitignore", "bench/results/\n.claude/worktrees/\n.env\nbuild/\n")
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
                              env={**self.env, **extra}, capture_output=True, text=True, timeout=120)

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

    def until(self, what, seconds: float = 120) -> None:
        end = time.time() + seconds
        while not what():
            assert time.time() < end, "waited %ss; trains said:\n%s" % (seconds, self.logs())
            time.sleep(0.05)

    def logs(self) -> str:
        """What each train wrote as its result, a line each, then their logs
        and the ships': a train's log says its result only after writing it,
        and ci_gate.sh once showed a failure's first line alone."""
        results = ["%s: %s" % (d.name[:-6], self.spec(d.name[:-6], "result") or "(none)")
                   for d in sorted(self.ro.glob("*.train"))]
        return "results:\n%s\n\n%s" % ("\n".join(results), "\n".join(
            p.read_text() for p in sorted(self.ro.glob("*_train.out")) + sorted(self.ro.glob("*_lead.out"))))

    def times(self, name: str) -> dict:
        """probe_times or check_times: each NAME's began and ended, as epoch seconds."""
        spans: dict = {}
        for line in self.text(name).splitlines():
            *who, what, when = line.split()
            spans.setdefault(" ".join(who), {})[what] = float(when)
        return spans

    def probes_running(self) -> list:
        """The stand-in probes of this yard still running."""
        found = []
        for pid in self.text("probe_pids").split():
            try:
                if "tools/probe.sh" in Path("/proc/%s/cmdline" % pid).read_text():
                    found.append(pid)
            except OSError:
                pass
        return found

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


def _group(pgid: int) -> list:
    """The command lines of the processes in process group PGID."""
    found = []
    for stat in Path("/proc").glob("[0-9]*/stat"):
        try:
            if int(stat.read_text().rsplit(")", 1)[1].split()[2]) == pgid:
                found.append((stat.parent / "cmdline").read_text().replace("\0", " "))
        except (OSError, IndexError, ValueError):
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
        # Waiting, it keeps nothing off the live database: its mark there
        # held rel-m319's own runs on brickworks.diy while it waited for
        # rel-m319 (2026-11-23). It is made once t-m1 serves.
        mark = y.r / ".git" / "live-db.release" / y.spec("t-m2", "pid").strip()
        assert not mark.exists()
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

        # The battery's last check is held: status mid-ship, and until its
        # battery is done no unit's battery begins (preview_checks.sh).
        y.until(lambda: (y.ro / "t-m2_pv.out").exists()
                and (y.ro / "t-m2_pv.out").read_text().count(" exit=") == 3)
        assert mark.exists()
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
        # Held until the first four have begun: a second's sleep each took it
        # that all four began within that second, which a loaded box need not.
        # Four as asked (TRAIN_PROBES_AT_ONCE); six when not.
        probes = "held_a held_b held_c held_d held_e flaky"
        assert y.train("stage", "t-m2", "stage2", "--probes", probes, TRAIN_PROBES_AT_ONCE="4").returncode == 0
        y.until(lambda: len(y.times("probe_times")) == 4)
        time.sleep(0.5)  # and while they run, no fifth begins
        assert sorted(y.times("probe_times")) == ["held_a", "held_b", "held_c", "held_d"], y.text("probe_times")
        (y.ro / "held_gate").write_text("go")
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        spans = y.times("probe_times")
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


def test_a_stopped_release_reships_with_its_fix_and_the_one_staged_after_waits_for_it(tmp_path):
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--checks", "io gallery",
                       "--probes", "fine gated_fails").returncode == 0
        # Its preview made and checked, a probe fails: rel-m230's booklet_stream.
        y.until(lambda: "main waits for the probes" in y.text("t-m2_lead.out"))
        (y.ro / "probe_gate").write_text("go")
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result").startswith("stopped: probes failed: gated_fails"), y.logs()
        made = y.text("t-m2_preview.sha").strip()
        assert made
        # The check's fix, committed in the release's worktree, as the lead
        # made rel-m227's.
        (y.wt / "t-m2" / "tools/web").mkdir(parents=True)
        (y.wt / "t-m2" / "tools/web/io_flow.mjs").write_text("// the check, fixed\n")
        y.git(y.wt / "t-m2", "add", "tools/web/io_flow.mjs")
        y.git(y.wt / "t-m2", "commit", "-q", "-m", "the io check, fixed")
        fixed = y.git(y.wt / "t-m2", "rev-parse", "--short", "HEAD")
        ran_before = y.text("probes_run").split()

        out = y.train("reship", "t-m2", "--probes", "fine", "io")
        assert out.returncode == 0, out.stdout + out.stderr
        assert "t-m2 reships from" in out.stdout and "io (and site, frames), probes: fine" in out.stdout, out.stdout
        assert y.spec("t-m2", "probes.why") == "named at reship"
        # Staged after it while it reships: it waits, never stops on the stop before.
        assert y.train("stage", "t-m3", "stage2", "--after", "t-m2").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        lead = y.text("t-m2_lead.out")
        assert "reusing preview https://preview.invalid/" in lead and made in lead, lead
        assert y.text("t-m2_pv_args").split()[2:] == ["io", "site", "frames"]
        assert y.text("probes_run").split()[len(ran_before):] == ["fine"]
        # Main has the fix; the domain serves the build the checks passed.
        assert y.git(y.r, "rev-parse", "--short", "main") == fixed
        assert y.text("promoted").split()[1] == y.git(y.r, "rev-parse", "--short", made), y.text("promoted")
        assert "SHIP: held, the probes failed: gated_fails" in y.text("t-m2_lead.prev.out"), "the attempt before is kept"
        y.until(lambda: y.spec("t-m3", "result"))
        assert y.spec("t-m3", "result") == "live", y.logs()
        assert "t-m2: brickworks.diy serves it" in y.text("t-m3_train.out")

        # Live, it is not reshipped; nor is one that stopped before its ship.
        again = y.train("reship", "t-m2", "io")
        assert again.returncode == 1 and "t-m2 is live" in again.stdout, again.stdout
        assert y.train("stage", "t-m4", "stage2", STUB_DIRTY="1").returncode == 0
        y.until(lambda: y.spec("t-m4", "result"))
        early = y.train("reship", "t-m4")
        assert early.returncode == 1 and "stopped before its ship" in early.stdout, early.stdout

        # By default the probes that did not pass run again, and those alone.
        assert y.train("stage", "t-m5", "stage2", "--probes", "fine fails").returncode == 0
        y.until(lambda: y.spec("t-m5", "result"))
        ran_before = y.text("probes_run").split()
        out = y.train("reship", "t-m5", "io")
        assert "probes: fails" in out.stdout, out.stdout
        y.until(lambda: y.spec("t-m5", "result"))
        assert y.spec("t-m5", "result").startswith("stopped: probes failed: fails"), y.logs()
        assert set(y.text("probes_run").split()[len(ran_before):]) == {"fails"}
        assert y.spec("t-m5", "probes.staged") == "fine fails"
        # The log says why these: not the reason those staged were.
        assert "probes, 6 at a time (those that did not pass before): fails" in y.text("t-m5_train.out"), y.logs()

        # And the checks that did not pass: named none, rel-m242's reship ran
        # site and frames alone, past the check that held it (2026-11-01).
        assert y.train("stage", "t-m6", "stage2", "--checks", "io gallery",
                       "--probes", "fails").returncode == 0
        y.until(lambda: y.spec("t-m6", "result"))
        # Held by gallery, as rel-m242 was by site_lang.
        (y.ro / "t-m6_pv.out").write_text("io exit=0 fails=0 1s :: passed\n"
                                          "gallery exit=1 fails=2 1s :: FAIL\ndone\n")
        out = y.train("reship", "t-m6", "--probes", "fine")
        assert out.returncode == 0, out.stdout + out.stderr
        assert "reships from" in out.stdout and ": gallery (and site, frames)" in out.stdout, out.stdout
        y.until(lambda: y.spec("t-m6", "result"))
        assert y.text("t-m6_pv_args").split()[2:] == ["gallery", "site", "frames"], y.logs()
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
        assert "train: stage2 has no runnable probe together (needs the relay; tools/relay_probe.sh runs it by hand)" in out.stdout, out.stdout
        # 2026-11-03: named by its file, connector_probe passed where connector would not, and held rel-m252.
        out = y.train("stage", "t-m2", "stage2", "--probes", "fits together_probe")
        assert out.returncode == 2, out.stdout + out.stderr
        assert "train: stage2 has no runnable probe together_probe (needs the relay; tools/relay_probe.sh runs it by hand)" in out.stdout, out.stdout
        assert not (y.ro / "t-m2.train" / "pid").exists() and y.spec("t-m2", "checks") == ""
        good = y.train("stage", "t-m2", "stage2", "--checks", "io sets_flow", "--probes", "fits offgrid")
        assert good.returncode == 0, good.stdout + good.stderr
    finally:
        y.stop()


def test_a_branch_origin_has_moved_past_is_refused_when_staged(tmp_path):
    """2026-11-24: a gate fix pushed to origin/pre261 from another tree was not
    in the local pre261, and rel-m335 staged without it."""
    y = Yard(tmp_path)
    try:
        y.git(y.r, "push", "-q", "origin", "stage2")
        y.git(y.r, "fetch", "-q", "origin")
        ahead = y.git(y.wt / "unitC", "rev-parse", "HEAD")
        (y.wt / "unitC" / "fix.txt").write_text("the gate fix\n")
        y.git(y.wt / "unitC", "add", "fix.txt")
        y.git(y.wt / "unitC", "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-q", "-m", "the fix")
        y.git(y.wt / "unitC", "push", "-q", "origin", "HEAD:stage2")
        assert ahead == y.git(y.r, "rev-parse", "stage2")
        out = y.train("stage", "t-m2", "stage2")
        assert out.returncode == 2, out.stdout + out.stderr
        assert "train: stage2 is behind origin/stage2" in out.stdout, out.stdout
        assert not (y.ro / "t-m2.train" / "pid").exists()
        y.git(y.r, "fetch", "-q", "origin")
        y.git(y.r, "branch", "-f", "stage2", "origin/stage2")
        good = y.train("stage", "t-m2", "stage2")
        assert good.returncode == 0, good.stdout + good.stderr
    finally:
        y.stop()


def _connector_change(y: Yard) -> None:
    """model_view's flow on main, and on stage2 a change to what a chat hears first, which that flow reaches."""
    y.put("tools/web/model_view_check.mjs", "await fetch(`${site}/api/mcp`, { method: 'POST' });\n")
    y.git(y.r, "add", "tools/web/model_view_check.mjs")
    y.git(y.r, "commit", "-q", "-m", "the flow")
    y.git(y.r, "push", "-q", "origin", "main")
    y.git(y.r, "checkout", "-q", "stage2")
    y.git(y.r, "merge", "-q", "--no-edit", "main")
    y.put("src/net/claude_connector.gd", "class_name ClaudeConnector\n")
    y.git(y.r, "add", "src/net/claude_connector.gd")
    y.git(y.r, "commit", "-q", "-m", "what a chat hears first")
    y.git(y.r, "checkout", "-q", "main")


def test_staging_adds_the_checks_whose_flows_reach_what_the_branch_changed(tmp_path):
    """A change to what a session hears through the connector runs model_view
    when the lead named only site: rel-m237 changed it under a hand-picked
    list, and model_view went unrun to rel-m250 (mcpview, 2026-11-02)."""
    y = Yard(tmp_path)
    try:
        _connector_change(y)
        staged = y.train("stage", "t-m2", "stage2", "--checks", "site")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        assert "lean.py against the build brickworks.diy serves (%s): " % y.git(y.r, "rev-parse", "--short", "main") \
            in staged.stdout and "; adds model_view to the checks named\n" in staged.stdout, staged.stdout
        assert y.spec("t-m2", "checks") == "site model_view"
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert y.text("t-m2_pv_args").split()[2:] == ["site", "model_view", "frames"], y.logs()
        # A diff no flow reaches adds none, and says so.
        again = y.train("stage", "t-m3", "unitB", "--checks", "io")
        assert again.returncode == 0, again.stdout + again.stderr
        assert "adds no check to those named" in again.stdout and y.spec("t-m3", "checks") == "io", again.stdout
    finally:
        y.stop()


def test_only_checks_ships_exactly_the_checks_named_at_staging_and_at_the_ship(tmp_path):
    """lean.py named 96 and 107 checks for rel-m326's and rel-m327's fixes, and
    the lead's trim of TAG.train/checks was widened again once the merge was
    made, so the lead stopped each train and ran the proving checks by hand
    (2026-11-23). --only-checks keeps the list named through the ship."""
    y = Yard(tmp_path)
    try:
        _connector_change(y)
        staged = y.train("stage", "t-m2", "stage2", "--checks", "site", "--only-checks")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        assert "adds none: exactly those named (--only-checks), at the ship too" in staged.stdout, staged.stdout
        assert y.spec("t-m2", "checks") == "site"
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert y.text("t-m2_pv_args").split()[2:] == ["site", "frames"], y.logs()
        assert "checks: exactly those named (--only-checks): site" in y.text("t-m2_train.out"), y.logs()
        both = y.train("stage", "t-m3", "unitB", "--checks", "io", "--only-checks", "--every-check")
        assert both.returncode == 2 and "train: --every-check or --only-checks, not both" in both.stdout, both.stdout
    finally:
        y.stop()


def _web_only(y: Yard, name: str) -> None:
    """A branch NAME from main that changes a page, its route and a note:
    nothing a web export is made from."""
    y.git(y.r, "checkout", "-q", "-b", name, "main")
    y.put("web/page.html", "<p>a page</p>\n")
    y.put("api/route.js", "export default () => 1;\n")
    y.put("docs/NOTES.md", "a note\n")
    y.git(y.r, "add", "-A")
    y.git(y.r, "commit", "-q", "-m", "a page and its route")
    y.git(y.r, "checkout", "-q", "main")


def _keep(y: Yard, tag: str, sha: str, where: Path) -> subprocess.CompletedProcess:
    """An export kept as brickworks.diy's (live_export.sh keep), as a release's ship keeps its own."""
    where.mkdir(parents=True, exist_ok=True)
    (where / "index.html").write_text("the build %s serves\n" % tag)
    return subprocess.run(["bash", str(y.r / "tools/release/live_export.sh"), "keep", tag, sha, str(where)],
                          cwd=y.r, env={**y.env, "RELEASE_OUT": str(y.ro)}, capture_output=True, text=True, timeout=60)


def test_a_branch_that_changes_no_app_file_ships_on_the_live_export_with_no_import_or_probe(tmp_path):
    """The social desk changed web/ and api/ alone, and its train still ran
    all 294 probes and made an export, so the lead shipped it by hand on the
    live release's build/web (fastlane, 2026-11-18). A release that makes an
    export keeps it as it goes live; a branch that changes nothing an export
    is made from ships on it after: no import, no probe, the checks named and
    those its change reaches, and the same preview, promotion and record."""
    y = Yard(tmp_path)
    try:
        # A release with probes and an app change: the export lane, which keeps its export.
        _lists_on_stage2(y, "beams\nplates\n")
        staged = y.train("stage", "t-m1", "stage2", "--checks", "io")
        assert staged.returncode == 0 and "  lane: full: an app file changed: " in staged.stdout, staged.stdout
        y.until(lambda: y.spec("t-m1", "result"))
        assert y.spec("t-m1", "result") == "live", y.logs()
        kept = y.ro / "exports" / "t-m1"
        assert (kept / "built_from").read_text().strip() == y.git(y.r, "rev-parse", "main")
        assert (y.ro / "live_web").resolve() == kept and (kept / "web" / "index.html").exists()
        assert "SHIP: live_export: t-m1's export kept, made from" in y.text("t-m1_lead.out"), y.logs()
        main = y.git(y.r, "rev-parse", "main")
        _web_only(y, "webonly")
        for f in ("probes_run", "imports", "merge_env", "deploy_args"):
            (y.ro / f).unlink(missing_ok=True)

        # Planned: what it would run, and nothing staged.
        plan = y.train("stage", "t-m2", "webonly", "--checks", "io", "--plan")
        assert plan.returncode == 0, plan.stdout + plan.stderr
        lane = "web: no app file changed; ships on t-m1's export (made from %s), no import or probe" % main[:9]
        assert "  lane: %s\n" % lane in plan.stdout, plan.stdout
        assert "  checks: io (and site, frames)\n" in plan.stdout, plan.stdout
        assert "  probes: none: the web lane, its app the live export's\n" in plan.stdout, plan.stdout
        assert not (y.ro / "t-m2.train").exists() and not (y.ro / "t-m2_train.out").exists()

        staged = y.train("stage", "t-m2", "webonly", "--checks", "io")
        assert staged.returncode == 0 and "  lane: %s\n" % lane in staged.stdout, staged.stdout
        assert y.spec("t-m2", "probes") == "" and y.spec("t-m2", "lane") == lane
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        # No probe, no import in its tree, its merge with none; its preview the kept export.
        assert not (y.ro / "probes_run").exists(), y.text("probes_run")
        assert str(y.wt / "t-m2") not in y.text("imports"), y.text("imports")
        assert y.text("merge_env").split() == ["MERGE_ONLY=1"], y.text("merge_env")
        deploys = y.text("deploy_args").splitlines()
        assert deploys[0] == "--dir=%s --no-fit" % (kept / "web") and deploys[1].startswith("--promote="), deploys
        # The web lane's app is live's, so frames (the app's draws) is not run.
        assert y.text("t-m2_pv_args").split()[2:] == ["io", "site"], y.logs()
        assert "/b/%s/" % y.spec("t-m2", "sha") in y.live.read_text()
        assert y.git(y.r, "log", "-1", "--format=%s", "main") == "Merge: webonly"
        assert "t-m2: the web lane: ships on t-m1's export" in y.text("t-m2_train.out"), y.logs()
        # It made no export of its own: t-m1's is still the one to ship on.
        assert (y.ro / "live_web").resolve() == kept
        status = y.train("status", "t-m2").stdout
        assert "  lane: web: no app file changed" in status and "probes: none run, none: the web lane" in status, status
    finally:
        y.stop()


def test_the_web_lane_is_refused_where_an_app_file_differs_and_its_merge_is_checked_again(tmp_path):
    y = Yard(tmp_path)
    try:
        _web_only(y, "webonly")
        none = y.train("stage", "t-m2", "webonly", "--web")
        assert none.returncode == 2 and "train: not the web lane: no export brickworks.diy serves is kept" in none.stdout, none.stdout
        assert "  lane: full: no export is kept for the web lane" in y.train("stage", "t-m2", "webonly", "--plan").stdout
        kept = _keep(y, "t-m1", y.base, tmp_path / "export")
        assert kept.returncode == 0 and "live_export: t-m1's export kept, made from %s" % y.base[:9] in kept.stdout, kept
        # stage2 changes a.txt, which is neither a page, the API, a doc, a test, SQL nor a tool.
        refused = y.train("stage", "t-m2", "stage2", "--web")
        assert refused.returncode == 2, refused.stdout + refused.stderr
        assert "train: not the web lane: app files differ from the export brickworks.diy serves: a.txt" in refused.stdout
        assert not (y.ro / "t-m2.train").exists()
        assert "  lane: full: an app file changed: a.txt\n" in y.train("stage", "t-m2", "stage2", "--plan").stdout
        assert "  lane: full: asked (--full)\n" in y.train("stage", "t-m2", "webonly", "--full", "--plan").stdout
        assert "--web or --full, not both" in y.train("stage", "t-m2", "webonly", "--web", "--full").stdout

        # Staged after a release, it is checked again once its merge is made:
        # main took an app file meanwhile, which the export was not made from.
        y.shipping("t-m1x")
        staged = y.train("stage", "t-m3", "webonly", "--after", "t-m1x", "--web")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        assert ", checked again once t-m1x serves\n" in staged.stdout, staged.stdout
        y.put("src/app.gd", "extends Node\n")
        y.git(y.r, "add", "src/app.gd")
        y.git(y.r, "commit", "-q", "-m", "an app change the export lacks")
        y.git(y.r, "push", "-q", "origin", "main")
        y.serves("t-m1x")
        y.until(lambda: y.spec("t-m3", "result"))
        assert y.spec("t-m3", "result") == ("stopped: the web lane, but app files differ from t-m1's export "
                                            "(made from %s): src/app.gd: stage it again with --full" % y.base[:9]), y.logs()
        assert not (y.ro / "promoted").exists() and not (y.ro / "t-m3_lead.out").exists()
    finally:
        y.stop()


def _together_change(y: Yard, name: str) -> None:
    """A branch NAME from main that changes together's flow alone: no app
    file, and lean.py adds together, which runs the engine from the tree."""
    y.git(y.r, "checkout", "-q", "-b", name, "main")
    y.put("tools/web/together_flow.mjs", "await fetch(`${site}/api/together`);\n")
    y.git(y.r, "add", "-A")
    y.git(y.r, "commit", "-q", "-m", "together's flow")
    y.git(y.r, "checkout", "-q", "main")


def test_the_web_lane_never_names_a_check_that_runs_the_engine_from_its_tree(tmp_path):
    """rel-m331's comments check made its models with godot from the
    release's tree, which the web lane never imports: godot wrote nothing,
    and the flow died on ENOENT at the ship (2026-11-24). together's desktop
    half needs the engine as it runs, so the web lane refuses it named, at
    staging and at a reship, and leaves it out, saying so, where lean.py adds
    it, at staging and again once merged; the full lane runs it."""
    y = Yard(tmp_path)
    why = "it runs the desktop app from the release's tree, which the web lane never imports"
    try:
        assert _keep(y, "t-m1", y.base, tmp_path / "export").returncode == 0
        _together_change(y, "webtogether")
        for asked in ((), ("--web",), ("--only-checks",)):
            refused = y.train("stage", "t-m2", "webtogether", "--checks", "io together", *asked)
            assert refused.returncode == 2, refused.stdout + refused.stderr
            assert ("train: the web lane cannot run together: %s. Stage it with --full, or name the checks without it\n"
                    % why) in refused.stdout, refused.stdout
            assert not (y.ro / "t-m2.train").exists()
        full = y.train("stage", "t-m2", "webtogether", "--checks", "io together", "--full", "--plan")
        assert full.returncode == 0 and "  checks: io together (and site, frames)\n" in full.stdout, full.stdout
        assert "left out" not in full.stdout, full.stdout

        plan = y.train("stage", "t-m2", "webtogether", "--checks", "io", "--plan")
        assert plan.returncode == 0 and "  lane: web: " in plan.stdout, plan.stdout
        assert "  checks: io (and site, frames)\n" in plan.stdout and "; adds no check to those named\n" in plan.stdout
        assert "  left out: together: %s (--full runs it)\n" % why in plan.stdout, plan.stdout
        staged = y.train("stage", "t-m2", "webtogether", "--checks", "io", STUB_FAILS="io")
        assert staged.returncode == 0 and "  left out: together: %s" % why in staged.stdout, staged.stdout
        assert y.spec("t-m2", "checks") == "io"
        y.until(lambda: y.spec("t-m2", "result"))
        assert "held, failed on the preview: io" in y.spec("t-m2", "result"), y.logs()
        # Chosen again once merged (lean_now), and left out again: never run.
        assert "t-m2: leaves out together: %s (--full runs it)" % why in y.text("t-m2_train.out"), y.logs()
        assert y.text("t-m2_pv_args").split()[2:] == ["io", "site"], y.logs()
        assert "together" not in y.text("check_times"), y.text("check_times")

        refused = y.train("reship", "t-m2", "together")
        assert refused.returncode == 2 and "train: the web lane cannot run together: %s." % why in refused.stdout, \
            refused.stdout
        again = y.train("reship", "t-m2", STUB_FAILS="")
        assert again.returncode == 0 and ": io (and site, frames)" in again.stdout, again.stdout
        assert y.spec("t-m2", "reship") == "io"
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert "together" not in y.text("check_times"), y.text("check_times")
    finally:
        y.stop()


def test_a_check_that_changes_what_is_live_never_runs_on_brickworks_diy(tmp_path):
    """console flipped the real beta's switch there until b66e9044a, and
    console3's Run now runs the real crons there: such a check is never run
    on brickworks.diy. Failing on a preview, it holds the release at once,
    with no run there of the rest, and only the lead's word (--accept)
    ships past it (fastship, 2026-11-23: rel-m319 waited 45 minutes there
    for a check that could not run)."""
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m1", "stage2", "--checks", "console people",
                       STUB_FAILS="console people", STUB_STALE_FAILS="console people").returncode == 0
        y.until(lambda: y.spec("t-m1", "result"))
        assert y.spec("t-m1", "result").endswith(
            "held, failed on the preview: console, which cannot run on brickworks.diy: the lead judges it "
            "(train.sh reship t-m1 --accept NAME \"why\")"), y.logs()
        assert not (y.ro / "t-m1_stale_args").exists(), y.logs()
        y.unmoved()
        assert y.train("stage", "t-m2", "stage2", "--checks", "console people", "--accept", "console", "fails there too",
                       STUB_FAILS="console people", STUB_STALE_FAILS="console people").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result").endswith(
            "held, failed on the preview: people (failing on brickworks.diy too: people)"), y.logs()
        assert y.text("t-m2_stale_args").split()[2:] == ["people"], y.logs()
        lead = y.text("t-m2_lead.out")
        assert "SHIP: never run on brickworks.diy, as each changes what is live there or its script refuses it: console" in lead
        assert "SHIP: ships past console, which cannot run on brickworks.diy, as the lead judged: fails there too" in lead
        assert "not run there: console" in y.train("status", "t-m2").stdout
        y.unmoved()
    finally:
        y.stop()


def _lists_on_stage2(y: Yard, headless: str) -> None:
    """stage2's own probes and lists, as the app's are: HEADLESS, window
    windowed, and spend kept out."""
    y.git(y.r, "checkout", "-q", "stage2")
    for name in ("beams", "plates", "hinge", "gears", "window", "spend"):
        y.put("src/dev/%s_probe.gd" % name,
              "## godot --headless --path . --script src/dev/%s_probe.gd\nextends SceneTree\n" % name)
    y.put("tools/suite/headless.txt", headless)
    y.put("tools/suite/windowed.txt", "window\n")
    y.put("tools/suite/out.txt", "spend   # spends money: a design on the API key\n")
    y.git(y.r, "add", "-A")
    y.git(y.r, "commit", "-q", "-m", "the branch's probes and lists")
    y.git(y.r, "checkout", "-q", "main")


def test_named_no_probes_a_train_runs_every_headless_one_its_branch_lists(tmp_path):
    """Staged with --probes "" every time, no release ran a probe, and eight
    went red on main unseen between v0.15.0 and rel-m256 (desktop016,
    2026-11-04). Picked by what featuremap affected reaches, three of the six
    headless ones would have run; all 209 take about 20 minutes, beside a
    battery of two hours. So asked for all (--probes all), a train runs
    every probe the branch's own headless.txt lists, one it adds among them;
    named none, those its change reaches (lean.py), every one each night
    (nightly.sh, fastship 2026-11-23): here all four, as the branch adds
    each of them."""
    y = Yard(tmp_path)
    try:
        _lists_on_stage2(y, "# run headless\nbeams\nplates   # a comment\nhinge:--quick\ngears\n")
        lean = y.train("stage", "t-m1", "stage2", "--checks", "io", "--plan")
        assert lean.returncode == 0 and "  probes: lean: 4 of 4 headless reach its change" in lean.stdout, lean.stdout
        staged = y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "all")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        said = "all 4 headless (--probes all) (1 windowed left to the suite)"
        assert "  probes: %s\n" % said in staged.stdout, staged.stdout
        assert y.spec("t-m2", "probes") == "beams plates hinge gears" and y.spec("t-m2", "probes.why") == said
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert sorted(y.text("probes_run").split()) == ["beams", "gears", "hinge", "plates"], y.logs()
        assert "probes, 6 at a time (%s): beams plates hinge gears" % said in y.text("t-m2_train.out"), y.logs()
        assert "probes: 4 of 4 passed" in y.train("status", "t-m2").stdout
        # A branch with no list to take them from is refused, not run with none.
        y.git(y.r, "checkout", "-q", "-b", "bare", "main")
        y.git(y.r, "rm", "-q", "tools/suite/headless.txt")
        y.git(y.r, "commit", "-q", "-m", "no list")
        y.git(y.r, "checkout", "-q", "main")
        # (In the full lane: a web lane runs no probe, and t-m2 kept an export.)
        bare = y.train("stage", "t-m3", "bare", "--full")
        assert bare.returncode == 2, bare.stdout + bare.stderr
        assert "train: bare has no tools/suite/headless.txt: name the probes" in bare.stdout, bare.stdout
        assert not (y.ro / "t-m3.train").exists()
    finally:
        y.stop()


def test_no_probes_run_only_when_named_none_with_the_reason(tmp_path):
    """None is said, and why, in the stage's output, the log and status."""
    y = Yard(tmp_path)
    try:
        for args, said in ((("--probes", "none"), 'train: --probes none wants --why "the reason", which its log says'),
                           (("--probes", "none", "--why", " "), 'train: --probes none wants --why "the reason"'),
                           (("--why", "docs alone"), "train: --why is the reason for --probes none"),
                           (("--probes", "fine", "--why", "docs alone"), "train: --why is the reason for --probes none")):
            refused = y.train("stage", "t-m2", "stage2", *args)
            assert refused.returncode == 2 and said in refused.stdout, (args, refused.stdout)
        assert not (y.ro / "t-m2.train").exists()
        staged = y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "none", "--why", "the docs alone changed")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        assert "  probes: none: the docs alone changed\n" in staged.stdout, staged.stdout
        assert y.spec("t-m2", "probes") == "" and y.spec("t-m2", "probes.why") == "none: the docs alone changed"
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert not (y.ro / "probes_run").exists(), y.text("probes_run")
        assert "t-m2: runs no probe: none: the docs alone changed" in y.text("t-m2_train.out"), y.logs()
        assert "probes: none run, none: the docs alone changed" in y.train("status", "t-m2").stdout
    finally:
        y.stop()


def test_an_empty_probes_list_is_refused(tmp_path):
    y = Yard(tmp_path)
    try:
        for empty in ("", "  "):
            refused = y.train("stage", "t-m2", "stage2", "--probes", empty)
            assert refused.returncode == 2, refused.stdout + refused.stderr
            assert 'train: --probes "" names no probe: leave --probes out for every headless one stage2 lists, ' \
                   'or say --probes none --why "the reason"' in refused.stdout, refused.stdout
        assert not (y.ro / "t-m2.train").exists()
    finally:
        y.stop()


def test_a_named_list_of_probes_is_kept_as_it_is(tmp_path):
    """Neither the rest of headless.txt added, nor a windowed one named taken out."""
    y = Yard(tmp_path)
    try:
        _lists_on_stage2(y, "beams\nplates\nhinge\n")
        staged = y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "window beams")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        assert "  probes: named at staging: window beams\n" in staged.stdout, staged.stdout
        assert y.spec("t-m2", "probes") == "window beams" and y.spec("t-m2", "probes.why") == "named at staging"
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert sorted(y.text("probes_run").split()) == ["beams", "window"], y.logs()
    finally:
        y.stop()


def test_out_and_windowed_probes_are_never_run_unnamed(tmp_path):
    """out.txt's skip themselves, and a skip fails (together held rel-m225),
    and windowed ones are the suite's: named none, neither runs, nor a name
    in headless.txt's comments."""
    y = Yard(tmp_path)
    try:
        _lists_on_stage2(y, "beams   # not spend, nor window\n# window\n#spend\n")
        staged = y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "all")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        assert "  probes: all 1 headless (--probes all) (1 windowed left to the suite)\n" in staged.stdout, staged.stdout
        assert y.spec("t-m2", "probes") == "beams"
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert y.text("probes_run").split() == ["beams"], y.logs()
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


def test_a_train_stopped_by_hand_stops_its_work_and_its_probes_and_says_so(tmp_path):
    """Its work runs beside the shell named in its pid, which only waits, so
    the trap that says "killed" never runs as bash parses a "$(...)": there
    it failed to parse and the train died saying nothing (2026-11-03)."""
    y = Yard(tmp_path)
    try:
        # While its ship waits for its probes, by its group as status says
        # (kill -- -PID), or by its pid alone: its probes, in a group of their
        # own, stop with it, and its work writes nothing after. The ship,
        # stopped with the group, says it did not ship (143); left to run on,
        # it holds, its train gone (1).
        for tag, kill, done in (("t-m2", os.killpg, "143"), ("t-m3", os.kill, "1")):
            assert y.train("stage", tag, "stage2", "--checks", "io", "--probes", "gated").returncode == 0
            y.until(lambda: "main waits for the probes" in y.text(tag + "_lead.out") and y.probes_running())
            kill(int(y.spec(tag, "pid")), signal.SIGTERM)
            y.until(lambda: y.spec(tag, "result"))
            y.until(lambda: not y.probes_running(), 60)
            y.until(lambda: y.text(tag + ".done"))
            assert y.spec(tag, "result") == "stopped: killed", y.logs()
            assert y.text(tag + ".done").strip() == done, y.logs()
            if done == "1":
                assert "SHIP: held, the train running the probes" in y.text(tag + "_lead.out"), y.logs()
            y.unmoved()

        # Waiting: an INT, which a job in the background ignores, stops its
        # work all the same; killed outright by its pid alone, the work takes
        # no step after, and nothing of the train runs on.
        for tag, kill, said in (("t-m4", lambda pid: os.killpg(pid, signal.SIGINT), "stopped: killed"),
                                ("t-m5", lambda pid: os.kill(pid, signal.SIGKILL), "")):
            assert y.train("stage", tag, "stage2", "--after", "t-m99").returncode == 0
            y.until(lambda: "waits" in y.spec(tag, "step"))
            pid = int(y.spec(tag, "pid"))
            kill(pid)
            y.until(lambda: not any("train.sh run " in c for c in _group(pid)), 60)
            assert y.spec(tag, "result") == said, y.logs()
            assert not (y.wt / tag).exists()
    finally:
        y.stop()


def _deploying(y: Yard) -> list:
    """The pids of the yard's held stand-in deploys (STUB_DEPLOY_GATE, STUB_PROMOTE_GATE) still running."""
    found = []
    for pid in y.text("deploy_pids").split():
        try:
            if "tools/deploy.sh" in Path("/proc/%s/cmdline" % pid).read_text():
                found.append(int(pid))
        except OSError:
            pass
    return found


def _end_deploys(y: Yard) -> None:
    """Ends the yard's stand-in deploys still running, each with its group."""
    for pid in _deploying(y):
        try:
            os.killpg(os.getpgid(pid), signal.SIGTERM)
        except ProcessLookupError:
            pass


def test_a_killed_unit_preview_takes_its_deploy_with_it_and_the_next_reads_only_its_own(tmp_path):
    """A unit's run killed while it deploys, by its group as agents stop one
    (kill -- -PGID), by its pid alone, or outright: the next run's preview
    is its own deploy's alone. The timeout around heavy is a process group
    of its own, so hubprogram's deploy went on after its run was killed and
    wrote a second "deploy done" into the next run's log, which took both
    URLs and ran its checks on neither (2026-11-18)."""
    y = Yard(tmp_path)
    for name in ("unit_preview.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools" / "release" / name).read_text())
    unit = y.wt / "unitB"
    sha = y.git(unit, "rev-parse", "--short", "HEAD")

    def preview(gate: Path, says: int) -> subprocess.Popen:
        return subprocess.Popen(
            ["bash", str(y.r / "tools/release/unit_preview.sh"), str(unit), "io"],
            env={**y.env, "RELEASE_OUT": str(y.ro), "UNIT_RETRY_75": "0",
                 "STUB_DEPLOY_GATE": str(gate), "STUB_DEPLOY_SAYS": str(says)},
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)

    try:
        for n, (how, kill) in enumerate((("by its group", lambda p: os.killpg(p.pid, signal.SIGTERM)),
                                         ("by its pid", lambda p: os.kill(p.pid, signal.SIGTERM)),
                                         ("outright", lambda p: os.killpg(p.pid, signal.SIGKILL)))):
            gate_a, gate_b = tmp_path / ("gate_a%d" % n), tmp_path / ("gate_b%d" % n)
            a = preview(gate_a, 1)
            y.until(lambda: len(_deploying(y)) == 1, 60)
            (deploy_a,) = _deploying(y)
            kill(a)
            a.communicate(timeout=60)
            end = time.time() + 10
            while deploy_a in _deploying(y) and time.time() < end:
                time.sleep(0.05)
            ran_on = deploy_a in _deploying(y)
            # The next run's deploy says more first; A's, run on, ends while B's is under way.
            b = preview(gate_b, 6)
            y.until(lambda: len(set(_deploying(y)) - {deploy_a}) == 1, 60)
            (deploy_b,) = set(_deploying(y)) - {deploy_a}
            gate_a.touch()
            y.until(lambda: deploy_a not in _deploying(y), 60)
            gate_b.touch()
            out, _ = b.communicate(timeout=120)
            mine = "https://preview.invalid/%s-%d" % (sha, deploy_b)
            log = y.text("unitB_unit_preview.log")
            assert re.findall(r"deploy done (\S+)", log) == [mine], "killed %s:\n%s\n%s" % (how, log, out)
            assert "UNIT: checks on %s: io site\n" % mine in out, how + ":\n" + out
            assert "UNIT: exit=0, 2 checks passed on %s\n" % mine in out, how + ":\n" + out
            assert y.text("unitB_unit_preview.sha").strip() == sha
            # Its deploy ended with it, but for the kill no trap sees.
            assert ran_on == (how == "outright"), "killed %s, its deploy ran on" % how
    finally:
        _end_deploys(y)


def test_a_ship_stopped_while_it_promotes_promotes_nothing_after(tmp_path):
    """ship.sh stopped (its work's pid alone, as a train's kill reaches it)
    ends the deploy it is in: run on, the promotion put the release live
    after its ship had said 143, not shipped, and wrote its "serves" line
    into the next ship's log of the same tag."""
    y = Yard(tmp_path)
    gate = tmp_path / "promote_gate"
    try:
        y.git(y.r, "worktree", "add", "-q", str(y.wt / "stage2"), "stage2")
        ship = subprocess.Popen(
            ["bash", str(y.wt / "stage2/tools/release/ship.sh"), str(y.wt / "stage2"), "t-m2", "io"],
            cwd=y.wt / "stage2", env={**y.env, "RELEASE_OUT": str(y.ro), "STUB_PROMOTE_GATE": str(gate)},
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, start_new_session=True)
        y.until(lambda: _deploying(y), 60)
        (promote,) = _deploying(y)
        os.kill(ship.pid, signal.SIGTERM)
        out, _ = ship.communicate(timeout=60)
        end = time.time() + 10
        while promote in _deploying(y) and time.time() < end:
            time.sleep(0.05)
        gate.touch()
        y.until(lambda: promote not in _deploying(y), 60)
        assert y.text("t-m2.done").strip() == "143", out
        assert not (y.ro / "promoted").exists(), "promoted after its ship was stopped:\n" + out
        assert "/b/0000000/" in y.live.read_text()
    finally:
        _end_deploys(y)


def test_what_fails_on_the_preview_runs_on_the_live_site_after_its_battery_as_a_units_check(tmp_path):
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
        staged = y.train("stage", "t-m2", "stage2", "--checks", "io people gallery light_render keys",
                         STUB_FLAKY="io", STUB_FAILS="people light_render keys",
                         STUB_STALE_FAILS="people light_render")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        # Staged, nothing runs on the live site: rel-m249's 72 there beside its
        # preview's doubled the load and the lock (2026-11-02).
        assert "meanwhile" not in staged.stdout, staged.stdout
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == (
            "not live: ship.sh ended exit 1: SHIP: held, failed on the preview: people light_render keys "
            "(failing on brickworks.diy too: people)"), y.logs()
        # Each failure ran again alone first; only what failed alone too went there.
        assert [y.text("t-m2_alone_%s_args" % n).split()[2:] for n in ("io", "people", "light_render", "keys")] \
            == [["io"], ["people"], ["light_render"], ["keys"]]
        assert y.text("t-m2_stale_args").split() == [
            "https://brickworks.diy", str(y.wt / "t-m2"), "people", "light_render", "keys"]
        spans = y.times("check_times")
        here = max(s["ended"] for who, s in spans.items() if not who.startswith("t-m2_stale "))
        there = min(s["began"] for who, s in spans.items() if who.startswith("t-m2_stale "))
        assert here < there, spans
        # The preview's battery at the release's priority with the train's mark up;
        # on the live site as a unit's, the mark gone while the train still ran.
        how = {" ".join(line.split()[:2]): line.split()[2:] for line in y.text("check_how").splitlines()}
        assert how["t-m2_pv io"] == ["priority=1", "marks=1"], how
        assert how["t-m2_alone_io io"] == ["priority=1", "marks=1"], how
        assert how["t-m2_stale keys"] == ["priority=0", "marks=0"], how
        status = y.train("status", "t-m2").stdout
        assert ("on https://brickworks.diy (serving %s): already failing there: people; "
                "failing there, changed since: light_render; passing there: keys (t-m2_stale_NAME.log)" % build) \
            in status, status
        assert "checks: 3 of 7 passed; failed: io (passed alone) people light_render keys" in status, status
        assert y.git(y.r, "rev-parse", "main") == y.base and not (y.ro / "promoted").exists()

        # Nothing failed alone: nothing runs there.
        assert y.train("stage", "t-m3", "stage2", "--checks", "io", STUB_FLAKY="io").returncode == 0
        y.until(lambda: y.spec("t-m3", "result"))
        assert y.spec("t-m3", "result") == "live", y.logs()
        assert not (y.ro / "t-m3_stale_args").exists() and "on https://" not in y.train("status", "t-m3").stdout
    finally:
        y.stop()


def test_every_check_failing_beside_others_runs_again_alone_whatever_else_failed(tmp_path):
    """rel-m249: progress, a timing check, failed beside keys, library, model_page and together,
    and none of the four ran again alone (2026-11-02)."""
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--checks", "io gallery keys progress",
                       STUB_FLAKY="io keys progress", STUB_MISSING="gallery",
                       STUB_AB_HERE="150 160", STUB_AB_THERE="60 65").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        lead = y.text("t-m2_lead.out")
        assert "SHIP: io failed beside others; once more, alone" in lead, lead
        assert "SHIP: keys failed beside others; once more, alone" in lead, lead
        assert "SHIP: gallery did not run; once, alone" in lead, lead
        # A timing check gets no second go: alone it would pass what the load
        # showed. It runs by turns with brickworks.diy instead, never once there.
        assert not (y.ro / "t-m2_alone_progress_args").exists()
        assert y.spec("t-m2", "result") == ("not live: ship.sh ended exit 1: SHIP: held, failed on the preview: "
                                            "progress (by turns with brickworks.diy: t-m2_ab_NAME.judge)"), y.logs()
        assert not (y.ro / "t-m2_stale_args").exists()
        y.unmoved()
    finally:
        y.stop()


def test_it_ships_past_a_check_only_where_brickworks_diy_fails_it_too(tmp_path):
    y = Yard(tmp_path)
    reason = "the people page is late on brickworks.diy too, and this release does not touch it"
    try:
        # Held on people, which fails on brickworks.diy too, and keys, which passes there.
        assert y.train("stage", "t-m2", "stage2", "--checks", "keys people",
                       STUB_FAILS="keys people", STUB_STALE_FAILS="people").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result").endswith(
            "held, failed on the preview: keys people (failing on brickworks.diy too: people)"), y.logs()
        merge = y.git(y.wt / "t-m2", "rev-parse", "HEAD")
        made = y.text("t-m2_preview.sha").strip()

        # Never past one that passes there: its failure is the release's own.
        refused = y.train("reship", "t-m2", "--accept", "keys", "it is flaky")
        assert refused.returncode == 1, refused.stdout + refused.stderr
        assert "train: keys passes on https://brickworks.diy (keys exit=0 " in refused.stdout, refused.stdout
        assert "not one to ship past" in refused.stdout, refused.stdout
        assert y.spec("t-m2", "accept") == "" and y.git(y.wt / "t-m2", "rev-parse", "HEAD") == merge
        assert not (y.ro / "t-m2_accepted").exists()
        assert "--accept wants a check and the reason" in y.train("reship", "t-m2", "--accept", "people").stdout
        both = y.train("reship", "t-m2", "--accept", "people", reason, "--accept", "keys", "x")
        assert both.returncode == 1 and "keys passes on" in both.stdout, both.stdout
        assert y.spec("t-m2", "accept") == "" and y.git(y.wt / "t-m2", "rev-parse", "HEAD") == merge

        # keys fixed in the release's worktree; people shipped past.
        (y.wt / "t-m2" / "keys.txt").write_text("keys, fixed\n")
        y.git(y.wt / "t-m2", "add", "keys.txt")
        y.git(y.wt / "t-m2", "commit", "-q", "-m", "keys, fixed")
        out = y.train("reship", "t-m2", "--accept", "people", reason, STUB_FAILS="")
        assert out.returncode == 0, out.stdout + out.stderr
        assert "t-m2's merge now says: Ships past people where it fails on brickworks.diy too: " + reason \
            in out.stdout, out.stdout
        assert "reships from" in out.stdout and ": keys (and site, frames)" in out.stdout, out.stdout
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        # The merge's words, the trees as they were and the fix on top; a preview of that commit.
        assert y.git(y.r, "log", "-1", "--format=%s", "main") == "keys, fixed"
        assert y.git(y.r, "log", "-1", "--format=%B", "main^") == (
            "Merge: stage2\n\nShips past people where it fails on brickworks.diy too: " + reason)
        assert y.git(y.r, "rev-parse", "main^^{tree}") == y.git(y.r, "rev-parse", "%s^{tree}" % merge)
        assert y.git(y.r, "log", "-1", "--format=%an <%ae>", "main^") == "Xaxis <william.neeley@gmail.com>"
        assert y.text("t-m2_preview.sha").strip() not in ("", made)
        assert "reusing preview" not in y.text("t-m2_lead.out")
        assert y.text("t-m2_pv_args").split()[2:] == ["keys", "site", "frames"]
        record = y.text("t-m2_accepted")
        assert record.startswith("people: %s\n  here: people exit=1 " % reason), record
        assert "FAIL alone too" in record and "  there: people exit=1 fails=1 1s :: FAIL on the live site" in record
        assert "shipped past what fails on brickworks.diy too, or is no worse there by turns:\n  people: " + reason in y.text("t-m2_train.out")
        status = y.train("status", "t-m2").stdout
        assert "ships past what fails on https://brickworks.diy too, or is no worse there by turns:\n    people: " + reason in status, status
        assert "      there: people exit=1" in status, status

        # Given when staged: shipped past where it fails there too, held where it passes there.
        assert y.train("stage", "t-m3", "unitB", "--checks", "people", "--accept", "people", reason,
                       STUB_FAILS="people", STUB_STALE_FAILS="people").returncode == 0
        y.until(lambda: y.spec("t-m3", "result"))
        assert y.spec("t-m3", "result") == "live", y.logs()
        assert "SHIP: ships past people, which fails on brickworks.diy too: " + reason in y.text("t-m3_lead.out")
        assert ("Ships past people where it fails on brickworks.diy too: " + reason
                in y.git(y.r, "log", "-1", "--format=%B", "main"))
        assert y.train("stage", "t-m4", "stage2", "--checks", "people", "--accept", "people", reason,
                       STUB_FAILS="people").returncode == 0
        waiting = y.train("status", "t-m4").stdout
        assert "may ship past people should it fail on https://brickworks.diy too: " + reason in waiting, waiting
        y.until(lambda: y.spec("t-m4", "result"))
        assert y.spec("t-m4", "result") == "not live: ship.sh ended exit 1: SHIP: held, failed on the preview: people"
        assert not (y.ro / "t-m4_accepted").exists()
        bad = y.train("stage", "t-m5", "stage2", "--accept", "nosuch", "why")
        assert bad.returncode == 2 and "has no check nosuch" in bad.stdout, bad.stdout
    finally:
        y.stop()


def test_a_timing_check_failing_on_the_preview_runs_by_turns_with_brickworks_diy_and_holds_only_where_worse(tmp_path):
    """rel-m287 held twice on play while brickworks.diy passed it once, and an
    A/B by hand, P L L P P L, found the preview no slower (2026-11-11)."""
    y = Yard(tmp_path)
    try:
        # No worse than live: shipped past, both sides' numbers said.
        assert y.train("stage", "t-m2", "stage2", "--checks", "progress", STUB_FAILS="progress",
                       STUB_AB_HERE="95 70", STUB_AB_THERE="110 80").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        # P L L P, the same check from the release's tree, at the release's priority on both sides.
        runs = [y.text("t-m2_ab_progress_%s_args" % r).split() for r in ("P1", "L2", "L3", "P4")]
        preview = y.text("t-m2_pv_args").split()[0]
        assert [r[0] for r in runs] == [preview, "https://brickworks.diy", "https://brickworks.diy", preview], runs
        assert all(r[1:] == [str(y.wt / "t-m2"), "progress"] for r in runs), runs
        how = {" ".join(line.split()[:2]): line.split()[2] for line in y.text("check_how").splitlines()}
        assert all(how["t-m2_ab_progress_%s progress" % r] == "priority=1" for r in ("P1", "L2", "L3", "P4")), how
        assert not (y.ro / "t-m2_stale_args").exists()
        lead = y.text("t-m2_lead.out")
        assert "SHIP: progress ships past: the preview no worse than brickworks.diy beyond the noise " \
               "(2 runs on the preview, 2 on brickworks.diy)" in lead, lead
        measure = ("the stand-in's own work stays under # on average # ms (bar 100): here 95 70 (mean 82.5), "
                   "there 110 80 (mean 95) (in the battery 150); noise 30; failed 0 of 2, 1 of 2: no worse")
        record = y.text("t-m2_accepted")
        assert record.startswith("progress: by turns with brickworks.diy, ships past: "), record
        assert "\n  " + measure + "\n" in record, record
        # The numbers in the commit main moved to, on the merge with its tree; the
        # build brickworks.diy serves is the merge's, the one its checks passed.
        merge = y.git(y.r, "rev-parse", "--short", "main^")
        assert y.git(y.r, "log", "-1", "--format=%s", "main") == (
            "Ships past progress: no worse here than on brickworks.diy beyond the noise, by turns")
        assert measure in y.git(y.r, "log", "-1", "--format=%b", "main")
        assert y.git(y.r, "log", "-1", "--format=%s", "main^").startswith("Merge: ")
        assert y.git(y.r, "rev-parse", "main^{tree}") == y.git(y.r, "rev-parse", "main^^{tree}")
        assert y.git(y.r, "log", "-1", "--format=%an <%ae>", "main") == "Xaxis <william.neeley@gmail.com>"
        assert "/b/%s/" % merge in y.live.read_text() and y.text("t-m2_preview.sha").strip() == merge
        assert "shipped past what fails on brickworks.diy too, or is no worse there by turns:\n  progress: by turns" in y.text("t-m2_train.out")
        status = y.train("status", "t-m2").stdout
        assert "by turns with https://brickworks.diy, progress ships past: the preview no worse" in status, status
        assert "    " + measure in status, status
        assert "live: brickworks.diy serves it (%s)" % merge in status, status
        shipped = y.git(y.r, "rev-parse", "main")

        # Worse than live beyond the noise: held, both sides' numbers said.
        assert y.train("stage", "t-m3", "unitB", "--checks", "progress", STUB_FAILS="progress",
                       STUB_AB_HERE="150 160", STUB_AB_THERE="60 65").returncode == 0
        y.until(lambda: y.spec("t-m3", "result"))
        assert y.spec("t-m3", "result") == ("not live: ship.sh ended exit 1: SHIP: held, failed on the preview: "
                                            "progress (by turns with brickworks.diy: t-m3_ab_NAME.judge)"), y.logs()
        assert y.git(y.r, "rev-parse", "main") == shipped and not (y.ro / "t-m3_accepted").exists()
        status = y.train("status", "t-m3").stdout
        assert ("by turns with https://brickworks.diy, progress holds: the preview is worse than brickworks.diy "
                "beyond the noise (2 runs on the preview, 2 on brickworks.diy): the stand-in's own work") in status, status
        assert ("here 150 160 (mean 155), there 60 65 (mean 62.5) (in the battery 150); noise 10; "
                "failed 2 of 2, 0 of 2: worse") in status, status

        # Over the bar on both sides alike: shipped past, and said so.
        assert y.train("stage", "t-m4", "unitB", "--checks", "progress", STUB_FAILS="progress",
                       STUB_AB_HERE="140 120", STUB_AB_THERE="150 125").returncode == 0
        y.until(lambda: y.spec("t-m4", "result"))
        assert y.spec("t-m4", "result") == "live", y.logs()
        assert ("here 140 120 (mean 130), there 150 125 (mean 137.5) (in the battery 150); noise 25; "
                "failed 2 of 2, 2 of 2: no worse") in y.git(y.r, "log", "-1", "--format=%b", "main")

        # Another check holding the release: no A/B, it is not needed.
        assert y.train("stage", "t-m5", "unitB", "--checks", "keys progress", STUB_FAILS="keys progress").returncode == 0
        y.until(lambda: y.spec("t-m5", "result"))
        assert y.spec("t-m5", "result") == ("not live: ship.sh ended exit 1: SHIP: held, failed on the preview: "
                                            "keys progress"), y.logs()
        assert "SHIP: progress not run by turns with brickworks.diy: the release holds on keys" in y.text("t-m5_lead.out")
        assert y.text("t-m5_stale_args").split()[2:] == ["keys"] and not (y.ro / "t-m5_ab_progress_P1_args").exists()
    finally:
        y.stop()


def test_a_ship_that_ends_first_stops_the_probes_beside_it(tmp_path):
    y = Yard(tmp_path)
    try:
        assert y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "gated",
                       STUB_CI_FAIL="1").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result").startswith("not live: ship.sh ended exit 1: SHIP: held, the version, "
                                                   "the Python suite or a shell script (ci_gate.sh exit 1"), y.logs()
        assert y.text("t-m2.probes").strip() == "stopped: the ship ended first"
        # Stopped, not left to run on: it never ended, and nothing of it runs.
        assert "gated" in y.times("probe_times") and "ended" not in y.times("probe_times")["gated"]
        assert y.text("probe_pids")
        y.until(lambda: not y.probes_running(), 60)
        y.unmoved()
    finally:
        y.stop()


def test_the_checks_run_at_once_as_asked_and_none_begins_once_the_probes_failed(tmp_path):
    """The real preview_checks.sh, its node and heavy stood in for."""
    y = Yard(tmp_path)
    for name in ("preview_checks.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools/release" / name).read_text())
    (y.r / ".env").write_text("VERCEL_BYPASS=bypass\n")
    node = tmp_path / "bin" / "node"
    node.write_text("""#!/bin/bash
# stand-in: a check that takes a moment, noting when; the one named in
# STUB_FAILS_PROBES says the probes failed as it runs. With STUB_TOGETHER=N
# it holds until N have begun: half a second each took it that the first N
# began within that half second, which a loaded box need not.
name=$(basename "$1" .mjs)
echo "$name began $(date +%s.%N)" >> "$RELEASE_OUT/check_spans"
[ "$name" = "${STUB_FAILS_PROBES:-}" ] && echo "failed: fails" > "$SHIP_PROBES"
for _ in $(seq 1 1200); do [ "$(grep -c ' began ' "$RELEASE_OUT/check_spans")" -ge "${STUB_TOGETHER:-1}" ] && break; sleep 0.05; done
sleep 0.5
echo "$name ended $(date +%s.%N)" >> "$RELEASE_OUT/check_spans"
echo "$name: all passed"
""")
    node.chmod(0o755)
    heavy = tmp_path / "home/.claude/claude-core/bin/heavy"
    heavy.write_text('#!/bin/bash\n# stand-in: a slot at once, solo or not, noting how each was asked for\n'
                     '[ "$1" = --solo ] && echo "solo gap=${BOX_HEAVY_SOLO_GAP:-unset} priority=${BOX_HEAVY_PRIORITY:-0}"'
                     ' >> "$RELEASE_OUT/heavy_asked"\n[ "$1" = --solo ] && shift\nexec "$@"\n')
    y.ro.mkdir(parents=True)
    env = {**y.env, "RELEASE_OUT": str(y.ro), "TMPDIR": str(tmp_path)}

    def battery(tag: str, *names: str, **extra: str) -> list:
        subprocess.run(["bash", str(y.r / "tools/release/preview_checks.sh"), "https://preview.invalid",
                        str(y.r), tag, *names], env={**env, **extra}, check=True, timeout=60,
                       capture_output=True)
        return y.text(tag + ".out").splitlines()

    five = ("io", "gallery", "keys", "palette", "docs")
    out = battery("t-wide", *five, STUB_TOGETHER="3")
    assert sorted(line.split()[0] for line in out[:-1]) == sorted(five) and out[-1] == "done", out
    assert all(" exit=0 " in line for line in out[:-1]), out
    spans = y.times("check_spans")
    most = max(sum(1 for s in spans.values() if s["began"] <= t["began"] < s["ended"]) for t in spans.values())
    assert most == 3, spans
    (y.ro / "check_spans").unlink()
    battery("t-two", *five, PC_AT_ONCE="2", STUB_TOGETHER="2")
    spans = y.times("check_spans")
    assert max(sum(1 for s in spans.values() if s["began"] <= t["began"] < s["ended"]) for t in spans.values()) == 2

    # A solo check outside a release is a run of its own; a release's keep the gap.
    battery("t-solo", "frames")
    battery("t-solo-release", "frames", BOX_HEAVY_PRIORITY="1")
    assert y.text("heavy_asked").splitlines() == ["solo gap=0 priority=0", "solo gap=unset priority=1"], \
        y.text("heavy_asked")

    # The probes fail while io runs: io ends as it would, and nothing more begins, frames (alone) neither.
    probes = y.ro / "t-m9.probes"
    probes.write_text("running 1: a\n")
    out = battery("t-held", "io", "gallery", "keys", "frames", PC_AT_ONCE="1", SHIP_PROBES=str(probes),
                  STUB_FAILS_PROBES="io_flow")
    assert out[0].startswith("io exit=0 "), out
    assert [line.split()[:2] for line in out[1:-1]] == [["gallery", "exit=125"], ["keys", "exit=125"],
                                                       ["frames", "exit=125"]], out
    assert all("not run: the release's probes failed" in line for line in out[1:-1]) and out[-1] == "done", out


def _tickets(y: Yard, line: str = "queue") -> list:
    """The runs waiting in live-db.LINE (queue, or release): their TIME.PID tickets, a train's
    mark (PID) not among them. A run has come once its ticket is there."""
    d = y.r / ".git" / ("live-db." + line)
    return sorted(f.name for f in d.iterdir() if "." in f.name) if d.exists() else []


def _took(y: Yard) -> list:
    """Who took the live database, as live-db.log says: take_live_db writes it before its
    ticket goes, so in the order they took it."""
    log = y.r / ".git" / "live-db.log"
    return [line.split()[3] for line in log.read_text().splitlines() if " took " in line] if log.exists() else []


def _begun(y: Yard) -> list:
    """The stand-in checks begun so far, from the yard's spans."""
    f = y.r / "spans"
    return [line.split()[0] for line in f.read_text().splitlines() if " began " in line] if f.exists() else []


def test_a_release_takes_the_live_database_before_a_unit_that_waited_longer(tmp_path):
    """The real preview_checks.sh: a unit's arrival and a release's wait for the live database's
    lock, the unit's first; once it is let go the release's runs first, and leaves no mark. The
    release's checks on the live site take it as a unit's do, in the order they came."""
    import fcntl
    y = Yard(tmp_path)
    for name in ("preview_checks.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools/release" / name).read_text())
    y.put("tools/web/arrival_check.mjs", "await deleteAccount(session)\n")
    (y.r / ".env").write_text("VERCEL_BYPASS=bypass\n")
    node = tmp_path / "bin" / "node"
    node.write_text('#!/bin/bash\necho "$TAG_SEEN began $(date +%s.%N)" >> "$RELEASE_OUT/check_spans"\n'
                    'sleep 0.5\necho "arrival: all passed"\n')
    node.chmod(0o755)
    heavy = tmp_path / "home/.claude/claude-core/bin/heavy"
    heavy.write_text('#!/bin/bash\n[ "$1" = --solo ] && shift\nexec "$@"\n')
    y.ro.mkdir(parents=True)
    env = {**y.env, "RELEASE_OUT": str(y.ro), "TMPDIR": str(tmp_path)}

    def battery(tag: str, **extra: str) -> subprocess.Popen:
        return subprocess.Popen(["bash", str(y.r / "tools/release/preview_checks.sh"), "https://preview.invalid",
                                 str(y.r), tag, "arrival"], env={**env, "TAG_SEEN": tag, **extra},
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    held = open(y.r / ".git" / "live-db.lock", "a")
    fcntl.flock(held, fcntl.LOCK_EX)
    # Each comes once its ticket is there, not a second after the one before,
    # which a start slow at load can outlast.
    unit = battery("t-unit")
    y.until(lambda: len(_tickets(y)) == 1)
    release = battery("t-release", BOX_HEAVY_PRIORITY="1")
    y.until(lambda: len(_tickets(y, "release")) == 1)
    time.sleep(0.5)  # several polls, and neither begins while the lock is held
    assert not (y.ro / "check_spans").exists()
    fcntl.flock(held, fcntl.LOCK_UN)
    held.close()
    assert release.wait(timeout=120) == 0 and unit.wait(timeout=120) == 0
    # The order taken, from the log: with three slots the unit takes one the
    # moment the release has, and its check's first line came first (binrow's
    # and bugbar's ci_gate, 2026-11-08 and 11-13).
    assert _took(y) == ["t-release", "t-unit"], _took(y)
    assert sorted(line.split()[0] for line in y.text("check_spans").splitlines()) == ["t-release", "t-unit"]
    assert not any((y.r / ".git" / "live-db.release").iterdir())

    # A train's mark (a file named for its pid, as train.sh run leaves until its battery is
    # done): a unit's battery begins nothing on the live database while it is there, and
    # neither do the release's own checks on the live site, which wait their turn as a unit's.
    (y.ro / "check_spans").unlink()
    train = subprocess.Popen(["sleep", "600"])
    try:
        mark = y.r / ".git" / "live-db.release" / str(train.pid)
        mark.write_text("")
        unit = battery("t-unit2")
        y.until(lambda: len(_tickets(y)) == 1)
        # LIVE_DB_RELEASE, which put a train's checks there ahead of every unit, counts for nothing:
        # a train copied before trainlean still sets it.
        stale = battery("t-stale", LIVE_DB_RELEASE="1")
        y.until(lambda: len(_tickets(y)) == 2)
        time.sleep(0.5)  # several polls
        assert unit.poll() is None and stale.poll() is None and not (y.ro / "check_spans").exists(), \
            "a check ran while the train's mark was there"
        mark.unlink()  # as ship.sh takes it away once the release's battery is done
        assert unit.wait(timeout=120) == 0 and stale.wait(timeout=120) == 0
        assert train.poll() is None, "the train ended first"
        assert _took(y)[2:] == ["t-unit2", "t-stale"], _took(y)
    finally:
        train.kill()
        train.wait()


def test_a_units_own_run_on_the_live_site_waits_for_a_release(tmp_path):
    """live_db.sh, which a unit's own A/B takes the live database through: while a train runs
    it begins nothing; then it runs, says so in live-db.log, and exits as its command did."""
    y = Yard(tmp_path)
    for name in ("live_db.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools/release" / name).read_text())
    began = tmp_path / "began"
    marks = y.r / ".git" / "live-db.release"
    marks.mkdir(parents=True, exist_ok=True)
    train = subprocess.Popen(["sleep", "600"])
    try:
        (marks / str(train.pid)).write_text("")
        unit = subprocess.Popen(["bash", str(y.r / "tools/release/live_db.sh"), "ab-hover",
                                 "bash", "-c", f"touch {began}; exit 3"], cwd=y.r, env=y.env)
        y.until(lambda: len(_tickets(y)) == 1)
        time.sleep(0.5)  # several polls
        assert unit.poll() is None and not began.exists(), "the unit's run began while the train ran"
    finally:
        train.kill()
        train.wait()
    assert unit.wait(timeout=120) == 3 and began.exists()
    log = (y.r / ".git" / "live-db.log").read_text().splitlines()
    assert [line.split()[2:4] for line in log] == [["took", "ab-hover"], ["left", "ab-hover"]], log
    assert log[1].endswith("exit=3")


def test_units_on_the_live_site_take_it_in_the_order_they_came(tmp_path):
    """Five units' runs wait behind a train; once it ends they take it in the order they came, as
    live-db.log says, not as flock happens to wake them (a unit's run after run held connect3's
    91 minutes). Each comes once its ticket is there, not 0.4 s after the one before, which a
    start slow at load can outlast; and the order is the log's, as with three slots the
    commands' own first lines raced each other (panelfold's, kinefuncs' and bugbar's ci_gate,
    2026-11-13)."""
    y = Yard(tmp_path)
    for name in ("live_db.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools/release" / name).read_text())
    marks = y.r / ".git" / "live-db.release"
    marks.mkdir(parents=True, exist_ok=True)
    train = subprocess.Popen(["sleep", "600"])
    try:
        (marks / str(train.pid)).write_text("")
        names = ["u1", "u2", "u3", "u4", "u5"]
        units = []
        for k, name in enumerate(names, 1):
            units.append(subprocess.Popen(["bash", str(y.r / "tools/release/live_db.sh"), name,
                                           "bash", "-c", "sleep 0.3"], cwd=y.r, env=y.env))
            y.until(lambda: len(_tickets(y)) == k)
        assert not _took(y), "a unit took it while the train ran"
    finally:
        train.kill()
        train.wait()
    assert all(unit.wait(timeout=120) == 0 for unit in units)
    assert _took(y) == names, _took(y)
    assert not list((y.r / ".git" / "live-db.queue").iterdir()), "a ticket was left behind"


def test_a_ticket_left_by_a_killed_run_holds_no_one(tmp_path):
    """A run killed whole never runs its trap, so its ticket stays. One whose process is gone,
    or whose pid now names another process, is removed when seen, not read as a run still
    waiting (17 such were left by 2026-11-04); a living run's ticket still holds the line."""
    y = Yard(tmp_path)
    y.put("tools/release/live_db_lib.sh", (ROOT / "tools/release/live_db_lib.sh").read_text())
    queue = y.r / ".git" / "live-db.queue"
    queue.mkdir(parents=True, exist_ok=True)
    gone = subprocess.Popen(["true"])
    gone.wait()
    stranger = subprocess.Popen(["sleep", "30"])
    stat = Path(f"/proc/{stranger.pid}/stat").read_text()
    began = stat.rsplit(") ", 1)[1].split()[19]

    def older_waits(*tickets: tuple[str, str]) -> int:
        for name, text in tickets:
            (queue / name).write_text(text)
        return subprocess.run(["bash", "-c", "source tools/release/live_db_lib.sh; older_waits 9"],
                              cwd=y.r, env=y.env).returncode

    try:
        assert older_waits((f"1.{gone.pid}", "")) == 1, "a dead run's ticket held the line"
        assert older_waits((f"2.{stranger.pid}", "1")) == 1, "a reused pid held the line"
        assert not list(queue.iterdir()), "a dead or reused ticket was kept"
        assert older_waits((f"3.{stranger.pid}", began)) == 0, "a living run's ticket was passed"
        assert older_waits((f"4.{stranger.pid}", "")) == 0, "an unmarked living ticket was passed"
        assert sorted(f.name for f in queue.iterdir()) == [f"3.{stranger.pid}", f"4.{stranger.pid}"]
    finally:
        stranger.kill()
        stranger.wait()


def spans(path: Path) -> dict[str, tuple[float, float]]:
    """NAME began T / NAME ended T lines, as each stand-in check writes them: NAME's (began, ended)."""
    seen: dict[str, list[float]] = {}
    for line in path.read_text().splitlines():
        name, what, when = line.split()
        seen.setdefault(name, [0.0, 0.0])[0 if what == "began" else 1] = float(when)
    return {name: (began, ended) for name, (began, ended) in seen.items()}


def most_at_once(span: dict[str, tuple[float, float]]) -> int:
    edges = sorted([(b, 1) for b, _ in span.values()] + [(e, -1) for _, e in span.values()])
    now = most = 0
    for _, step in edges:
        now += step
        most = max(most, now)
    return most


def held(y: Yard, name: str, seconds: float, *before: str, gate: Path | None = None) -> list[str]:
    """live_db.sh's command for a stand-in check NAME that holds the live database SECONDS, or
    until GATE is there (five minutes at most)."""
    spans = y.r / "spans"
    hold = f"sleep {seconds}" if gate is None else \
        f"for _ in $(seq 1 6000); do [ -e {gate} ] && break; sleep 0.05; done"
    return [*before, str(y.r / "tools/release/live_db.sh"), name, "bash", "-c",
            f"echo {name} began $(date +%s.%N) >> {spans}; {hold}; echo {name} ended $(date +%s.%N) >> {spans}"]


def test_a_battery_runs_three_live_checks_at_once_and_one_that_reads_every_accounts_alone(tmp_path):
    """The real preview_checks.sh and its lock (LIVE_DB_SLOTS 3, PC_AT_ONCE 3): five live checks
    run three at a time, where one at a time held rel-m254's lock for 3.1 hours; challenges, which
    reads the site's one test challenge (ALONE_DB), runs with no other live check beside it."""
    y = Yard(tmp_path)
    for name in ("preview_checks.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools/release" / name).read_text())
    shared = ["share_flow", "versions", "age", "comments", "tested"]
    flows = {"share_flow": "share_flow", "versions": "versions_flow", "age": "age_flow",
             "comments": "comments_flow", "tested": "tested_flow", "challenges": "challenges_flow"}
    for flow in flows.values():
        y.put(f"tools/web/{flow}.mjs", "await deleteAccount(session)\n")
    (y.r / ".env").write_text("VERCEL_BYPASS=bypass\n")
    node = tmp_path / "bin" / "node"
    # Each holds until three have begun, then a moment more: 1.5 s each took
    # it that the first three began within that time, which a loaded box need not.
    node.write_text('#!/bin/bash\nname=$(basename "$1" .mjs)\n'
                    'echo "$name began $(date +%s.%N)" >> "$RELEASE_OUT/spans"\n'
                    'for _ in $(seq 1 1200); do [ "$(grep -c " began " "$RELEASE_OUT/spans")" -ge 3 ] && break; sleep 0.05; done\n'
                    'sleep 0.5\n'
                    'echo "$name ended $(date +%s.%N)" >> "$RELEASE_OUT/spans"\necho "$name: all passed"\n')
    node.chmod(0o755)
    y.ro.mkdir(parents=True)
    env = {**y.env, "RELEASE_OUT": str(y.ro), "TMPDIR": str(tmp_path), "PC_AT_ONCE": "3", "LIVE_DB_SLOTS": "3"}
    battery = subprocess.run(["bash", str(y.r / "tools/release/preview_checks.sh"), "https://preview.invalid",
                              str(y.r), "t-slots", "share_flow", "versions", "challenges", "age", "comments", "tested"],
                             env=env, capture_output=True, text=True, timeout=300)
    assert battery.returncode == 0, battery.stderr
    out = (y.ro / "t-slots.out").read_text().splitlines()
    assert len([line for line in out if " exit=0 " in line]) == 6 and out[-1] == "done", out
    span = {name: spans(y.ro / "spans")[flow] for name, flow in flows.items()}
    assert most_at_once({n: span[n] for n in shared}) == 3, span
    began, ended = span["challenges"]
    beside = [n for n in shared if span[n][0] < ended and span[n][1] > began]
    assert not beside, f"{beside} ran beside challenges"
    log = (y.r / ".git" / "live-db.log").read_text().splitlines()
    assert any("took t-slots challenges" in line and line.endswith("(alone)") for line in log), log
    assert any("took t-slots age" in line and "of 3)" in line for line in log), log
    assert not list((y.r / ".git" / "live-db.queue").iterdir()), "a ticket was left behind"


def test_three_hold_the_live_database_at_once_a_release_first_and_units_in_the_order_they_came(tmp_path):
    """live_db.sh with three slots: six units waiting behind a train's mark take them in the order
    they came, never more than three at once; a release's check that comes once the first three
    hold them goes before the three units that waited longer."""
    y = Yard(tmp_path)
    for name in ("live_db.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools/release" / name).read_text())
    marks = y.r / ".git" / "live-db.release"
    marks.mkdir(parents=True, exist_ok=True)
    gate = tmp_path / "gate"
    env = {**y.env, "LIVE_DB_SLOTS": "3"}
    units = []
    train = subprocess.Popen(["sleep", "600"])
    try:
        (marks / str(train.pid)).write_text("")
        # Each comes once its ticket is there; the first three hold their
        # slots until the gate opens. Spaced by sleeps and held 2.5 s, a slow
        # start came out of turn, and the first three's own first lines came
        # u1 u3 u2 (askfirst's ci_gate, 2026-11-10).
        for k in range(1, 7):
            units.append(subprocess.Popen(held(y, f"u{k}", 0.5, gate=gate if k <= 3 else None), cwd=y.r, env=env))
            y.until(lambda: len(_tickets(y)) == k)
    finally:
        train.kill()
        train.wait()
    y.until(lambda: len(_begun(y)) == 3)
    release = subprocess.Popen(held(y, "rel", 0.5), cwd=y.r, env={**env, "BOX_HEAVY_PRIORITY": "1"})
    y.until(lambda: len(_tickets(y, "release")) == 1)
    time.sleep(0.5)  # several polls: the slots are full, and none begins
    assert sorted(_begun(y)) == ["u1", "u2", "u3"], _begun(y)
    gate.write_text("go")
    assert release.wait(timeout=120) == 0 and all(unit.wait(timeout=120) == 0 for unit in units)
    assert _took(y) == ["u1", "u2", "u3", "rel", "u4", "u5", "u6"], _took(y)
    span = spans(y.r / "spans")
    assert most_at_once(span) == 3, span
    assert sorted(span) == ["rel", "u1", "u2", "u3", "u4", "u5", "u6"] and all(b and e for b, e in span.values()), span
    assert not list((y.r / ".git" / "live-db.queue").iterdir()), "a ticket was left behind"
    assert not [f for f in marks.iterdir() if "." in f.name], "a release's ticket was left behind"


def test_one_that_holds_the_live_database_alone_runs_with_no_other_and_none_passes_it(tmp_path):
    """live_db.sh --alone: it waits for the two units holding slots to leave, runs with nothing
    beside it, and the two that came after it, though slots were free, wait until it is done."""
    y = Yard(tmp_path)
    for name in ("live_db.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools/release" / name).read_text())
    env = {**y.env, "LIVE_DB_SLOTS": "3"}
    gate = tmp_path / "gate"
    # a and b hold their slots until c and d have come; each comes once it
    # has begun (a, b) or its ticket is there (x, c, d), not after a sleep.
    runs = [subprocess.Popen(held(y, "a", 0, gate=gate), cwd=y.r, env=env)]
    y.until(lambda: _begun(y) == ["a"])
    runs.append(subprocess.Popen(held(y, "b", 0, gate=gate), cwd=y.r, env=env))
    y.until(lambda: _begun(y) == ["a", "b"])
    cmd = held(y, "x", 0.5)
    runs.append(subprocess.Popen([cmd[0], "--alone", *cmd[1:]], cwd=y.r, env=env))
    y.until(lambda: len(_tickets(y)) == 1)
    runs.append(subprocess.Popen(held(y, "c", 0.3), cwd=y.r, env=env))
    y.until(lambda: len(_tickets(y)) == 2)
    runs.append(subprocess.Popen(held(y, "d", 0.3), cwd=y.r, env=env))
    y.until(lambda: len(_tickets(y)) == 3)
    time.sleep(0.5)  # several polls: a slot is free, and neither c nor d passes x
    assert _begun(y) == ["a", "b"], _begun(y)
    gate.write_text("go")
    assert all(run.wait(timeout=120) == 0 for run in runs)
    span = spans(y.r / "spans")
    began, ended = span["x"]
    assert span["a"][1] <= began and span["b"][1] <= began, span
    assert span["c"][0] >= ended and span["d"][0] >= ended, span
    assert span["a"][0] < span["b"][1], "a and b did not share the live database"
    log = (y.r / ".git" / "live-db.log").read_text()
    assert "took x after" in log and "(alone)" in log, log


def test_a_run_killed_while_it_waited_holds_no_one(tmp_path):
    """A unit's run killed whole while it waited leaves its ticket, and a train's run killed
    leaves its mark, its pid then another process's: neither holds the next run, which begins
    at once and takes both away."""
    import fcntl
    y = Yard(tmp_path)
    for name in ("live_db.sh", "live_db_lib.sh"):
        y.put("tools/release/" + name, (ROOT / "tools/release" / name).read_text())
    env = {**y.env, "LIVE_DB_SLOTS": "3"}
    queue = y.r / ".git" / "live-db.queue"
    lock = y.r / ".git" / "live-db.lock"
    lock.parent.mkdir(parents=True, exist_ok=True)
    whole = open(lock, "a")
    fcntl.flock(whole, fcntl.LOCK_EX)
    waiter = subprocess.Popen(held(y, "killed", 1), cwd=y.r, env=env)
    y.until(lambda: len(_tickets(y)) == 1)  # the waiter's ticket
    waiter.kill()
    waiter.wait()
    assert list(queue.iterdir()), "the killed run's ticket went with it (no trap runs on a kill)"
    fcntl.flock(whole, fcntl.LOCK_UN)
    whole.close()
    stranger = subprocess.Popen(["sleep", "30"])
    marks = y.r / ".git" / "live-db.release"
    marks.mkdir(exist_ok=True)
    (marks / str(stranger.pid)).write_text("1\n")  # the start time of the train that had its pid
    try:
        # Held by either, it would wait LIVE_WAIT, an hour.
        run = subprocess.Popen(held(y, "next", 0.2), cwd=y.r, env=env)
        try:
            assert run.wait(timeout=120) == 0
        except subprocess.TimeoutExpired:
            run.kill()
            raise AssertionError("the next run waited on a dead ticket or mark")
        assert "killed" not in spans(y.r / "spans")
        assert not list(queue.iterdir()) and not list(marks.iterdir()), "a dead ticket or mark was kept"
    finally:
        stranger.kill()
        stranger.wait()



def test_a_rehearsal_runs_every_gate_and_stops_before_main_moves(tmp_path):
    """The release path timed on a preview (TRAIN_REHEARSE, fastship
    2026-11-23): merged, deployed, checked, its probes beside it, and ended
    where main would move, with how long it took; main, the domain and the
    train's worktree as they were."""
    y = Yard(tmp_path)
    try:
        main = y.git(y.r, "rev-parse", "main").strip()
        assert y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "beams",
                       TRAIN_REHEARSE="1").returncode == 0
        y.until(lambda: y.spec("t-m2", "result"))
        result = y.spec("t-m2", "result")
        assert result.startswith("rehearsed: every gate passed; a release would move main to "), y.logs()
        assert " s after the ship began; " in result and result.endswith(" s from its merge"), result
        assert y.git(y.r, "rev-parse", "main").strip() == main
        assert not any(a.startswith("--promote=") for a in y.text("deploy_args").split()), y.text("deploy_args")
        assert not (y.wt / "t-m2").exists()
        assert "beams" in y.text("probes_run").split(), y.logs()
    finally:
        y.stop()


def test_a_check_that_cannot_run_on_the_live_site_goes_to_the_leads_judgement_at_once(tmp_path):
    """rel-m319's designer_period refuses brickworks.diy (exit 2), and its
    run there queued 45 minutes to learn so (2026-11-23). One whose script
    refuses the live site, given the check's options, holds the release at
    once with no run there, and ships past only as the lead judges it."""
    y = Yard(tmp_path)
    try:
        y.git(y.r, "worktree", "add", "-q", str(y.wt / "stage2"), "stage2")
        (y.wt / "stage2" / "tools/web").mkdir(parents=True)
        (y.wt / "stage2" / "tools/web/keys_flow.mjs").write_text(
            "const site = process.argv[2];\n"
            "if (/^(?:www\\.)?brickworks\\.diy$/.test(new URL(site).host)) {\n"
            "  console.error(\"keys_flow: never on brickworks.diy; give a preview\");\n"
            "  process.exit(2);\n}\n")
        # Refused only with an option the check does not pass: it runs there.
        (y.wt / "stage2" / "tools/web/people_flow.mjs").write_text(
            "if (/brickworks\\.diy/.test(site) && args[\"signed-in\"]) {\n"
            "  console.error(\"people_flow: --signed-in never on brickworks.diy\");\n  process.exit(2);\n}\n")
        y.git(y.wt / "stage2", "add", "tools/web")
        y.git(y.wt / "stage2", "commit", "-q", "-m", "two checks that know the live site")
        staged = y.train("stage", "t-m2", "stage2", "--checks", "io people keys", STUB_FAILS="people keys")
        assert staged.returncode == 0, staged.stdout + staged.stderr
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == (
            "not live: ship.sh ended exit 1: SHIP: held, failed on the preview: keys, which cannot run on "
            "brickworks.diy: the lead judges it (train.sh reship t-m2 --accept NAME \"why\")"), y.logs()
        assert not (y.ro / "t-m2_stale_args").exists(), "nothing ran on the live site"
        assert y.text("t-m2_stale.never").split() == ["keys"]
        # The lead's word ships past it, with the fix to people.
        again = y.train("reship", "t-m2", "--accept", "keys", "checked by hand on the preview", "io",
                        STUB_FAILS="keys")
        assert again.returncode == 0, again.stdout + again.stderr
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        accepted = y.text("t-m2_accepted")
        assert "keys: checked by hand on the preview" in accepted and "there: never run (the lead judged it)" in accepted, accepted
    finally:
        y.stop()


def test_the_python_suites_failures_the_lead_judged_ship_from_the_spec(tmp_path):
    """SHIP_GATE_OK (rel-m321 held 40 minutes on 7 known failures), kept in
    the train's spec (--gate-ok, TAG.train/gate_ok) for its reships too:
    the gate beside the ship fails only in those files, and it ships."""
    y = Yard(tmp_path)
    try:
        said = "  FAIL  tests/test_known.py::test_a: a picture yet to be made"
        assert y.train("stage", "t-m2", "stage2", "--checks", "io", "--probes", "slow_one",
                       "--gate-ok", "tests/test_known.py", STUB_CI_FAIL="1", STUB_CI_SAYS=said).returncode == 0
        assert y.spec("t-m2", "gate_ok") == "tests/test_known.py"
        y.until(lambda: y.spec("t-m2", "result"))
        assert y.spec("t-m2", "result") == "live", y.logs()
        assert "SHIP: ships past the Python suite's judged failures (SHIP_GATE_OK): tests/test_known.py" \
            in y.text("t-m2_lead.out"), y.text("t-m2_lead.out")
        # One more failure, in a file not judged: held.
        more = said + "\n  FAIL  tests/test_new.py::test_b: new"
        assert y.train("stage", "t-m3", "unitB", "--checks", "io", "--probes", "slow_one",
                       "--gate-ok", "tests/test_known.py", STUB_CI_FAIL="1", STUB_CI_SAYS=more).returncode == 0
        y.until(lambda: y.spec("t-m3", "result"))
        assert y.spec("t-m3", "result").startswith(
            "not live: ship.sh ended exit 1: SHIP: held, the version, the Python suite or a shell script"), y.logs()
        assert y.spec("t-m3", "result").endswith(": not judged: tests/test_new.py"), y.spec("t-m3", "result")
    finally:
        y.stop()
