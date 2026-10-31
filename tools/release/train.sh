#!/bin/bash
# train.sh : a release staged in one command, which ships when its turn comes.
#
#   train.sh stage TAG BRANCH [--after PREV] [--checks "..."] [--probes "..."]
#                             [--units "..."] [--title "..."]
#   train.sh status [TAG...]
#   train.sh hold TAG [REASON]          train.sh release TAG
#   train.sh reship TAG [--probes "..."] [CHECK...]
#
# stage writes TAG's spec in $RELEASE_OUT/TAG.train/, a file each (branch,
# after, checks, probes, units, title), and starts the train detached
# (setsid: a background job dies with the Claude session that began it). It
# logs to $RELEASE_OUT/TAG_train.out. Each file is read only when its step
# comes, so a unit merged into BRANCH meanwhile brings its checks by an edit
# of TAG.train/checks, until the ship begins.
#
# The train waits until PREV's ship says brickworks.diy serves it, never on
# PREV's process: what ship.sh does after that touches only the live site.
# It stops if PREV held, failed or never began, and gives up at its deadline
# (TRAIN_WAIT, 6 hours from staging; TAG.train/deadline, editable). Then it
# makes the release worktree from origin/main (release_wt.sh), merges BRANCH
# as the user (merge_unit.sh), refuses a tree left dirty or mid-merge, runs
# check.sh --lists, then the probes and the ship side by side (ship.sh, which
# promotes the very preview its checks passed, and moves main only once
# every probe has passed: $RELEASE_OUT/TAG.probes). Once brickworks.diy
# serves the release it retires the release's worktree, and each unit's
# whose work is all on main. A hold ($RELEASE_OUT/HOLD for all, TAG.hold for
# one) stops it before the merge and again before the probes and the ship,
# until lifted; ship.sh itself stops at it before main moves.
#
# reship ships a release whose train stopped after its ship began, from the
# worktree it kept (with any fix committed there): the checks named, on the
# same preview when only checks or release tools changed since (SHIP_REUSE),
# beside the probes that did not pass (or those --probes names). Its record
# stays the train's, so a release staged after it waits for it to serve:
# shipped by hand, rel-m227 left its train's "stopped" for rel-m228 to stop
# on (2026-10-31).
#
# Staged, the checks named also run at once on brickworks.diy as it is
# (TAG_stale.out), and status says which already fail there: a check gone
# stale since an earlier release holds the one that next names it.
#
# This replaces the chain scripts the lead wrote by hand for each release,
# rel-m214 to m218, and the promote job beside them that ship.sh now does.
set -u
HERE=${TRAIN_HOME:-$(cd "$(dirname "$0")" && pwd)}
export TRAIN_HOME="$HERE"
R=$(dirname "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)")
RO=$(realpath -m "${RELEASE_OUT:-$R/bench/results/release-out}")
export RELEASE_OUT="$RO"
WT=$R/.claude/worktrees
LIVE=${TRAIN_LIVE:-https://brickworks.diy/app}
SITE=${TRAIN_SITE:-https://brickworks.diy}
POLL=${TRAIN_POLL:-15}

usage() { sed -n '4,8p' "$HERE/train.sh"; exit 2; }

# TAG's train if it is running, by the pid it wrote, and only while that pid
# still runs this train: a pid is reused once its process ends. KIND stale:
# its checks on brickworks.diy.
runner() {
  local kind=${2:-run} file=pid pid
  [ "$kind" = run ] || file=${kind}_pid
  pid=$(cat "$RO/$1.train/$file" 2>/dev/null) || return 1
  case "$(tr '\0' ' ' 2>/dev/null < "/proc/$pid/cmdline")" in
    *"train.sh $kind $1 ") echo "$pid" ;;
    *) return 1 ;;
  esac
}

# The build brickworks.diy/app names, /b/SHA/: the page itself says which.
serving() { curl -s --max-time 20 "$LIVE" 2>/dev/null | grep -o '/b/[^/"]*/' | head -1; }

# A spec file's words, into the array named.
words() { read -r -d '' -a "$1" < "$SPEC/$2" || true; }

stage() {
  [ $# -ge 2 ] || usage
  local tag=$1 branch=$2 after="" checks="" probes="" units="" title="" pid
  shift 2
  case "$tag" in ""|*[!A-Za-z0-9._-]*) echo "train: '$tag' is not a tag"; exit 2 ;; esac
  while [ $# -gt 0 ]; do
    [ $# -ge 2 ] || { echo "train: $1 wants a value"; exit 2; }
    case "$1" in
      --after) after=$2 ;; --checks) checks=$2 ;; --probes) probes=$2 ;;
      --units) units=$2 ;; --title) title=$2 ;;
      *) echo "train: no option $1"; exit 2 ;;
    esac
    shift 2
  done
  git -C "$R" rev-parse -q --verify "$branch^{commit}" >/dev/null || { echo "train: no branch $branch"; exit 2; }
  # A name the branch has no check or probe for fails the release an hour
  # on, "no such check": share, build and sets held rel-m222, as one held
  # m87 (2026-10-30). Named against the branch's own lists, where it has them.
  local known name unknown=""
  if known=$(git -C "$R" show "$branch:tools/release/preview_checks.sh" 2>/dev/null); then
    known=$(grep -oE '^[[:space:]]*\[[a-z_0-9]+\]=' <<< "$known" | tr -d '[]= \t')
    for name in $checks; do grep -qx "$name" <<< "$known" || unknown+=" check $name,"; done
  fi
  if git -C "$R" cat-file -e "$branch:src/dev" 2>/dev/null; then
    for name in $probes; do
      git -C "$R" cat-file -e "$branch:src/dev/$name.gd" 2>/dev/null \
        || git -C "$R" cat-file -e "$branch:src/dev/${name}_probe.gd" 2>/dev/null || unknown+=" probe $name,"
    done
    # A probe tools/suite/out.txt keeps out of runs skips itself here, and a
    # skip fails: together, which wants the relay, held rel-m225 (2026-10-30).
    out=$(git -C "$R" show "$branch:tools/suite/out.txt" 2>/dev/null)
    for name in $probes; do
      why=$(awk -v n="$name" '$1 == n { sub(/^[^#]*# */, ""); print; exit }' <<< "$out")
      [ -z "$why" ] || unknown+=" runnable probe $name ($why),"
    done
  fi
  [ -z "$unknown" ] || { echo "train: $branch has no${unknown%,}"; exit 2; }
  if pid=$(runner "$tag"); then
    echo "train: $tag's train runs (pid $pid): edit $RO/$tag.train/, or stop it (kill -- -$pid) first"; exit 1
  fi
  clear_attempt "$tag" "$branch" || exit 1
  SPEC=$RO/$tag.train
  mkdir -p "$SPEC" || exit 1
  rm -f "$SPEC"/{pid,step,result,sha,tip,shipped,reship} "$RO/$tag.probes"
  echo "$branch" > "$SPEC/branch"; echo "$after" > "$SPEC/after"
  echo "$checks" > "$SPEC/checks"; echo "$probes" > "$SPEC/probes"; echo "$units" > "$SPEC/units"
  echo "${title:-$branch}" > "$SPEC/title"
  echo $(( $(date +%s) + ${TRAIN_WAIT:-21600} )) > "$SPEC/deadline"
  # This is TAG's latest attempt: a result an attempt before left would tell
  # the release staged after it that this one had ended (m178 held on
  # m177's, 2026-10-26).
  rm -f "$RO/$tag.done" "$RO/$tag.gave_up"
  for log in lead train; do
    [ -e "$RO/${tag}_$log.out" ] && mv -f "$RO/${tag}_$log.out" "$RO/${tag}_$log.prev.out"
  done
  # The train runs from a copy: a release fast-forwards the main checkout,
  # this script with it, and bash reads a script as it goes.
  cp "$HERE/train.sh" "$SPEC/train.sh" || exit 1
  setsid -f nohup bash "$SPEC/train.sh" run "$tag" > "$RO/${tag}_train.out" 2>&1 < /dev/null
  echo "train: $tag staged: ${after:+waits for $after to serve, then }merges $branch and ships"
  echo "  spec $SPEC/ (editable until it ships), log $RO/${tag}_train.out"
  # Its checks on brickworks.diy as it is, now: one gone stale since an
  # earlier release (people, which expected the profile's tabs from before
  # achievements) held rel-m226 two hours on, at its ship (2026-10-30).
  [ -n "$checks" ] || return 0
  if pid=$(runner "$tag" stale); then
    echo "  its checks on brickworks.diy, begun when it was staged before, go on (pid $pid)"
  else
    rm -f "$RO/${tag}"_stale.{out,asked,skipped,build,changed}
    setsid -f nohup bash "$SPEC/train.sh" stale "$tag" > "$RO/${tag}_stale.log" 2>&1 < /dev/null
    echo "  its checks run on $SITE meanwhile: status says which already fail there"
  fi
}

# An attempt before that stopped leaves its worktree, kept for the lead to
# read, and its merge on a branch of TAG's name. Restaging takes both when
# they hold nothing but that merge; rel-m221 was cleared by hand before each
# of its restages (2026-10-30).
clear_attempt() {
  local tag=$1 branch=$2 own
  local ref="refs/heads/$tag"
  git -C "$R" rev-parse -q --verify "$ref" >/dev/null || ref=""
  [ -e "$WT/$tag" ] || [ -n "$ref" ] || return 0
  if [ -e "$WT/$tag" ] && [ -n "$(git -C "$WT/$tag" status --porcelain --untracked-files=no)" ]; then
    echo "train: $WT/$tag has changes of its own: retire it (retire_wt.sh $tag) or stage another tag"; return 1
  fi
  if [ -n "$ref" ]; then
    own=$(git -C "$R" log --oneline --no-merges "$ref" --not "${TRAIN_BASE:-origin/main}" "$branch" | head -3)
    [ -z "$own" ] || { echo "train: a branch $tag has commits $branch lacks:"; echo "$own"; return 1; }
  fi
  if [ -e "$WT/$tag" ]; then
    bash "$HERE/retire_wt.sh" "$tag" >/dev/null || { echo "train: retire_wt.sh kept $WT/$tag"; return 1; }
  fi
  [ -z "$ref" ] || git -C "$R" branch -q -D "$tag" || return 1
  echo "train: cleared $tag's attempt before (its merge alone)"
}

hold() {
  [ $# -ge 1 ] || usage
  local tag=$1; shift
  echo "${*:-held by hand}, $(date -u +%FT%H:%MZ)" > "$RO/$tag.hold"
  echo "train: $tag held: its train waits before its merge or its ship, and a ship under way stops before main moves"
}

release() {
  [ $# -eq 1 ] || usage
  rm -f "$RO/$1.hold"
  echo "train: $1 released"
  [ -e "$RO/HOLD" ] && echo "train: but $RO/HOLD still holds every release ($(cat "$RO/HOLD"))"
  return 0
}

reship() {
  [ $# -ge 1 ] || usage
  local tag=$1 probes="" asked="" checks=() named=() pid res f n code fails
  shift
  local SPEC=$RO/$tag.train
  while [ $# -gt 0 ]; do
    case "$1" in
      --probes) [ $# -ge 2 ] || { echo "train: --probes wants a value"; exit 2; }
        probes=$2; asked=1; shift 2 ;;
      -*) echo "train: no option $1"; exit 2 ;;
      *) checks+=("$1"); shift ;;
    esac
  done
  [ -d "$SPEC" ] || { echo "train: $tag was never staged"; exit 2; }
  if pid=$(runner "$tag"); then echo "train: $tag's train runs (pid $pid)"; exit 1; fi
  res=$(cat "$SPEC/result" 2>/dev/null)
  [ "$res" = live ] && { echo "train: $tag is live"; exit 1; }
  # Stopped before its ship, it has no build to reuse and maybe no merge.
  [ -e "$SPEC/shipped" ] && [ -d "$WT/$tag" ] \
    || { echo "train: $tag stopped before its ship (${res:-no result}): stage it again"; exit 1; }
  # By default the probes that did not pass in the attempt before: each
  # named whose answer is missing or failed.
  if [ -z "$asked" ]; then
    words named probes
    for n in "${named[@]}"; do
      f=$RO/${tag}_probe_$n.exit
      if [ -e "$f" ] && [ "$f" -nt "$SPEC/shipped" ] && read -r code fails < "$f" && probe_ok "$code" "$fails"; then
        continue
      fi
      probes+=" $n"
    done
    probes=${probes# }
  fi
  echo "${checks[*]}" > "$SPEC/reship"
  [ -e "$SPEC/probes.staged" ] || cp "$SPEC/probes" "$SPEC/probes.staged"
  echo "$probes" > "$SPEC/probes"
  # No pid and no result, as staged: a release staged after it waits.
  rm -f "$SPEC"/{pid,step,result} "$RO/$tag.done" "$RO/$tag.gave_up" "$RO/$tag.probes"
  for f in lead train; do
    [ -e "$RO/${tag}_$f.out" ] && mv -f "$RO/${tag}_$f.out" "$RO/${tag}_$f.prev.out"
  done
  cp "$HERE/train.sh" "$SPEC/train.sh" || exit 1
  setsid -f nohup bash "$SPEC/train.sh" run "$tag" > "$RO/${tag}_train.out" 2>&1 < /dev/null
  echo "train: $tag reships from $WT/$tag: ${checks[*]:-no checks} (and site, frames), probes: ${probes:- none}"
  echo "  log $RO/${tag}_train.out"
}

# --- the train itself (stage starts it as `run TAG`) ---

say() { echo "$(date -u +%H:%M:%SZ) $TAG: $*"; }

# The step it is on, in TAG.train/step (status reads it), said once.
step() {
  [ "$(cut -d' ' -f2- "$SPEC/step" 2>/dev/null)" = "$*" ] && return
  echo "$(date -u +%H:%MZ) $*" > "$SPEC/step"; say "$*"
}

past_deadline() { [ "$(date +%s)" -gt "$(cat "$SPEC/deadline" 2>/dev/null || echo 0)" ]; }

# The end, in TAG.train/result. Before the ship begins, TAG.gave_up too, as
# ship_after.sh writes: ship.sh writes TAG.done once it has begun.
finish() {
  # TAG.gave_up before the result, each written whole: prev_state reads
  # gave_up first, and a train behind that looked between the two writes
  # said "t-m7's train ended" where it says "never shipped" (a ci_gate at
  # load 22, 2026-10-30).
  if ! [ -e "$SPEC/shipped" ] && [ "$1" != live ]; then
    echo "$1" > "$RO/$TAG.gave_up.$$" && mv "$RO/$TAG.gave_up.$$" "$RO/$TAG.gave_up"
  fi
  echo "$1" > "$SPEC/result.$$" && mv "$SPEC/result.$$" "$SPEC/result"
  step "${1}"
  [ "$1" = live ] && exit 0
  exit 1
}
stop() { finish "stopped: $*"; }

# Where PREV stands: "live", "failed: why", or nothing while it is to come.
prev_state() {
  local p=$1 code res
  grep -q '^SHIP: deploy: brickworks.diy serves' "$RO/${p}_lead.out" 2>/dev/null && { echo live; return; }
  code=$(cat "$RO/$p.done" 2>/dev/null)
  [ "$code" = 0 ] && { echo live; return; }
  [ -n "$code" ] && { echo "failed: $p's ship ended exit $code, and brickworks.diy never served it"; return; }
  [ -e "$RO/$p.gave_up" ] && { echo "failed: $p never shipped: $(cat "$RO/$p.gave_up")"; return; }
  [ -d "$RO/$p.train" ] || return
  res=$(cat "$RO/$p.train/result" 2>/dev/null)
  [ -n "$res" ] && { echo "failed: $p's train ended: $res"; return; }
  # A train killed, or lost with the machine, writes no result.
  [ -e "$RO/$p.train/pid" ] && ! runner "$p" >/dev/null && [ ! -e "$RO/$p.train/result" ] \
    && echo "failed: $p's train is not running and wrote no result"
}

# Waits while a hold is set, before $1 (the merge, the ship).
unheld() {
  local h
  while :; do
    h=""
    for f in "$RO/HOLD" "$RO/$TAG.hold"; do [ -e "$f" ] && h="$f: $(cat "$f")" && break; done
    [ -z "$h" ] && return
    past_deadline && stop "held before $1 at its deadline ($h)"
    step "held before $1 by $h"
    sleep "$POLL"
  done
}

# Never ships a half-merged tree: a held merge_unit once left a unit's files
# staged in rel-m214. The sha is the one ship.sh and the deploy will name.
tree_ok() {
  local dirty
  git -C "$W" rev-parse -q --verify MERGE_HEAD >/dev/null && stop "$W is mid-merge"
  [ -e "$(git -C "$W" rev-parse --git-dir)/merging" ] && stop "a merge in $W is still running its gates"
  dirty=$(git -C "$W" status --porcelain --untracked-files=no)
  [ -z "$dirty" ] || { echo "$dirty" | head -5; stop "$W has uncommitted changes"; }
  git -C "$W" merge-base --is-ancestor "$TIP" HEAD || stop "$BRANCH at ${TIP:0:8} is not merged in $W"
  git -C "$W" rev-parse --short HEAD > "$SPEC/sha"
}

# The release's worktree, and each unit's whose work is all on main. A unit
# still working past what shipped keeps its worktree: site357 went on to
# pagination after its pages were merged into rel-m215 (2026-10-30), and a
# retire between two of its commands would take files it had not added.
retire() {
  local w d head extra
  cd "$R" || return
  bash "$HERE/retire_wt.sh" "$TAG" 2>&1 | tail -1
  words units units
  for w in "${units[@]}"; do
    d=$WT/$w
    head=$(git -C "$d" rev-parse HEAD 2>/dev/null) || { say "unit $w: no worktree"; continue; }
    git -C "$R" merge-base --is-ancestor "$head" main || { say "kept $w: it has work main lacks"; continue; }
    extra=$(git -C "$d" ls-files --others --exclude-standard | grep -vE '\.(uid|import)$' | head -3 | paste -sd' ')
    [ -z "$extra" ] || { say "kept $w: files git does not track ($extra)"; continue; }
    git -C "$R" worktree unlock "$d" 2>/dev/null
    bash "$HERE/retire_wt.sh" "$w" 2>&1 | tail -1
  done
}

# One probe in the release's tree, its log and "exit FAILs" in release-out.
probe_one() {
  local log="$RO/${TAG}_probe_$1.log" code
  (cd "$W" && bash tools/probe.sh "$1") > "$log" 2>&1
  code=$?
  echo "$code $(grep -cE '^\s*FAIL' "$log")" > "$RO/${TAG}_probe_$1.exit"
}

# Either holds: probe.sh exits 1 for a script that did not load, 2 for a
# probe not run and 3 for one that skipped itself, none with a FAIL line.
probe_ok() { [ "$1" = 0 ] && [ "$2" = 0 ]; }

# The probes' file, which ship.sh reads, written whole.
answer() { echo "$1" > "$RO/$TAG.probes.$$" && mv -f "$RO/$TAG.probes.$$" "$RO/$TAG.probes"; }

# The probes, beside the ship (run starts them as `probes TAG`, in a process
# group of their own, which it stops should the ship end first). Each has
# its own data folder and X server, and heavy and gpu queue them. One that
# fails beside others runs again alone before it counts, as ship.sh's checks
# do. They take the release's priority (BOX_HEAVY_PRIORITY): heavy holds a
# project's ordinary jobs back while its priority job runs, so ordinary
# probes would wait out the ship. Through rel-m226's gates, preview and
# checks (2026-10-30) the GPU's two slots were busy 23 of 119 minutes, every
# agent's probes held back; through its ordinary probes before, 98 of 100,
# and those probes spent 113 of their 148 minutes waiting for the GPU behind
# other agents'. TRAIN_PROBES_AT_ONCE at a time (4): the windowed ones share
# the GPU's two slots, and with both theirs, rel-m226's 35 (30 GPU minutes)
# are modelled at 19.2 minutes 2 at a time, 17.4 at 3 and 16.8 at 4 or more.
probes() {
  TAG=$1; SPEC=$RO/$TAG.train; W=$WT/$TAG
  local probe code fails at_once bad=""
  export BOX_HEAVY_PRIORITY=1
  words probes probes
  at_once=${TRAIN_PROBES_AT_ONCE:-4}
  say "probes, $at_once at a time: ${probes[*]}"
  for probe in "${probes[@]}"; do
    while [ "$(jobs -rp | wc -l)" -ge "$at_once" ]; do wait -n; done
    probe_one "$probe" &
  done
  wait
  for probe in "${probes[@]}"; do
    read -r code fails < "$RO/${TAG}_probe_$probe.exit"
    if [ "$at_once" -gt 1 ] && ! probe_ok "$code" "$fails"; then
      say "probe $probe exit=$code FAIL=$fails beside others: again alone"
      mv -f "$RO/${TAG}_probe_$probe.log" "$RO/${TAG}_probe_$probe.beside.log"
      probe_one "$probe"
      read -r code fails < "$RO/${TAG}_probe_$probe.exit"
    fi
    say "probe $probe exit=$code FAIL=$fails"
    probe_ok "$code" "$fails" || bad="$bad $probe"
  done
  [ -z "$bad" ] || { answer "failed:$bad"; exit 1; }
  rm -f "$RO/$TAG.probes"
  say "every probe passed"
}

# The checks named, on brickworks.diy as it is (stage starts them as `stale
# TAG`), from the worktree BRANCH is checked out in: the checks it would
# ship. The live database is the one previews share, so a check that makes
# accounts or sends mail does so here as it does there, and waits its turn
# at the same lock. Not the release's priority: it ships nothing. A check
# whose script changed since the build brickworks.diy serves may fail there
# for what this release adds (rel-m226's phone, its prints folded), so
# those are named apart (TAG_stale.changed).
stale() {
  TAG=$1; SPEC=$RO/$TAG.train
  local branch tree build n script
  echo $$ > "$SPEC/stale_pid"
  unset BOX_HEAVY_PRIORITY
  branch=$(cat "$SPEC/branch")
  words checks checks
  echo "${checks[*]}" > "$RO/${TAG}_stale.asked"
  tree=$(git -C "$R" worktree list --porcelain \
    | awk -v b="branch refs/heads/$branch" '/^worktree /{w = substr($0, 10)} $0 == b {print w; exit}')
  [ -n "$tree" ] || { echo "no worktree has $branch checked out" > "$RO/${TAG}_stale.skipped"; return; }
  build=$(serving); echo "$build" > "$RO/${TAG}_stale.build"
  build=${build#/b/}; build=${build%/}
  for n in "${checks[@]}"; do
    script=$(sed -n "s/^[[:space:]]*\[$n\]=\"\([^ \"]*\).*/\1/p" "$tree/tools/release/preview_checks.sh" | head -1)
    [ -n "$script" ] && [ -n "$build" ] && git -C "$tree" cat-file -e "$build^{commit}" 2>/dev/null \
      && ! git -C "$tree" diff --quiet "$build" -- "$script" 2>/dev/null && echo "$n"
  done > "$RO/${TAG}_stale.changed"
  bash "$tree/tools/release/preview_checks.sh" "$SITE" "$tree" "${TAG}_stale" "${checks[@]}"
}

run() {
  TAG=$1; SPEC=$RO/$TAG.train; W=$WT/$TAG
  cd "$R" || exit 1
  echo $$ > "$SPEC/pid"
  local code out ship ended="" bad="" reshipping="" served made
  # Killed (kill -- -PID stops what it runs too, and the probes, which run
  # in a group of their own): no result would leave the release staged
  # after it waiting until its deadline. nohup has HUP ignored.
  PROBES=""
  trap '[ -z "$PROBES" ] || kill -TERM -- "-$PROBES" 2>/dev/null; stop "killed"' TERM INT
  # The merge's import and gates at the release's priority, as its probes
  # and ship.sh are: rel-m231's merge waited behind an agent's solo checks
  # (2026-10-31).
  export BOX_HEAVY_PRIORITY=1

  if [ -e "$SPEC/reship" ]; then
    # Its merge is made and the release before it served (reship).
    reshipping=1
    BRANCH=$(cat "$SPEC/branch"); TIP=$(cat "$SPEC/tip")
    step "reships $W at $(git -C "$W" rev-parse --short HEAD)"
    tree_ok
  else
    merged
  fi

  step "check.sh --lists"
  out=$(cd "$W" && bash tools/check.sh --lists 2>&1) || { echo "$out" | tail -3; stop "check.sh --lists fails in $W"; }

  unheld "the probes and the ship"
  tree_ok
  if [ -n "$reshipping" ]; then words checks reship; else words checks checks; fi
  # Ship begun: from here ship.sh writes TAG.done, and shipped is what it was given.
  echo "${checks[*]}" > "$SPEC/shipped"
  # The probes and the ship side by side. One after the other, rel-m226's
  # 35 probes took 50 minutes and its ship an hour more (2026-10-30), while
  # the GPU the probes wait for sat idle through the ship. ship.sh moves
  # main only once the probes' file is gone, every probe passed; it says
  # "running TRAIN_PID: NAMES" until then, or "failed: NAMES".
  answer "running $$: $(cat "$SPEC/probes")"
  setsid bash "$SPEC/train.sh" probes "$TAG" &
  PROBES=$!
  step "ships $(cat "$SPEC/sha") with ${#checks[@]} checks named (and site, frames), its probes beside it"
  env LIVE_WAIT="${LIVE_WAIT:-10800}" SHIP_PROBES="$RO/$TAG.probes" \
    ${reshipping:+SHIP_REUSE=1} bash "$W/tools/release/ship.sh" "$W" "$TAG" "${checks[@]}" > "$RO/${TAG}_lead.out" 2>&1 &
  ship=$!
  wait -n -p ended "$PROBES" "$ship"; code=$?
  if [ "$ended" = "$PROBES" ]; then
    # Ended with no answer (killed, or lost its X server): the ship waits
    # while the file says running.
    grep -q '^running' "$RO/$TAG.probes" 2>/dev/null && answer "failed: (their run ended, exit $code, with no answer)"
    wait "$ship"; code=$?
  else
    # The ship ended first, so nothing waits for the probes: stopped.
    kill -TERM -- "-$PROBES" 2>/dev/null; wait "$PROBES"
    grep -q '^running' "$RO/$TAG.probes" 2>/dev/null && answer "stopped: the ship ended first"
  fi
  PROBES=""
  tail -n 4 "$RO/${TAG}_lead.out"
  # The build it serves: this commit's, or, reshipped on the preview made
  # before a check's fix, that preview's commit (ship.sh reused it).
  served=$(cat "$SPEC/sha")
  made=$(cat "$RO/${TAG}_preview.sha" 2>/dev/null) && made=$(git -C "$W" rev-parse --short "$made" 2>/dev/null) \
    && [ -n "$reshipping" ] && served="($served|$made)"
  if ! grep -qE "^SHIP: deploy: brickworks.diy serves $served\b" "$RO/${TAG}_lead.out"; then
    bad=$(sed -n 's/^failed://p' "$RO/$TAG.probes" 2>/dev/null)
    [ -z "$bad" ] || finish "stopped: probes failed:$bad (${TAG}_probe_NAME.log)"
    finish "not live: ship.sh ended exit $code: $(grep '^SHIP:' "$RO/${TAG}_lead.out" | tail -1 | cut -c1-160)"
  fi
  step "live; retiring"
  retire
  # Live, whatever the live checks after said: main has it and brickworks.diy serves it.
  [ "$code" = 0 ] || say "live, but ship.sh ended exit $code: its live checks ($RO/${TAG}_live.out)"
  finish live
}

# The wait for the release before, then TAG's worktree from main with BRANCH
# merged: what a train does before its probes and its ship.
merged() {
  local prev st base
  while prev=$(cat "$SPEC/after" 2>/dev/null) && [ -n "$prev" ]; do
    st=$(prev_state "$prev")
    case "$st" in
      live) say "$prev: brickworks.diy serves it"; break ;;
      failed:*) stop "${st#failed: }" ;;
    esac
    past_deadline && stop "gave up waiting for $prev at the deadline"
    step "waits for $prev to serve (until $(date -u -d "@$(cat "$SPEC/deadline")" +%H:%MZ))"
    sleep "$POLL"
  done

  unheld "the merge"
  base=${TRAIN_BASE:-origin/main}
  timeout 300 git -C "$R" fetch -q origin 2>&1 | tail -1
  [ -e "$W" ] && stop "$W exists"
  # A branch of this name left by an attempt before: only one whose work is
  # all on main goes (-d, never -D).
  if git -C "$R" rev-parse -q --verify "refs/heads/$TAG" >/dev/null; then
    git -C "$R" branch -d "$TAG" >/dev/null 2>&1 || stop "a branch $TAG has work main lacks"
  fi
  step "makes $W from $base ($(git -C "$R" rev-parse --short "$base" 2>/dev/null))"
  bash "$HERE/release_wt.sh" "$TAG" "$base" || stop "release_wt.sh could not make $W"

  BRANCH=$(cat "$SPEC/branch")
  # Its tip as it is now: a commit to BRANCH after this goes in the next
  # release instead of stopping this one, as one the lead made while rel-m221
  # merged stopped it (2026-10-30).
  TIP=$(git -C "$R" rev-parse -q --verify "$BRANCH^{commit}") || stop "no branch $BRANCH"
  echo "$TIP" > "$SPEC/tip"
  step "merges $BRANCH at ${TIP:0:8}"
  if ! MERGE_GATES=ship bash "$HERE/merge_unit.sh" "$W" "$TIP" "Merge: $(cat "$SPEC/title")" \
      > "$RO/${TAG}_merge.log" 2>&1; then
    tail -5 "$RO/${TAG}_merge.log"
    git -C "$W" merge --abort 2>/dev/null; git -C "$W" reset -q --hard HEAD
    stop "the merge of $BRANCH held ($RO/${TAG}_merge.log); $W is back where it began"
  fi
  tree_ok
  say "merged: $(git -C "$W" log --oneline -1 | cut -c1-100)"
}

# --- status: what is live since when, what is in flight at which step, and when it should serve ---

hm() { date -u -d "@$1" +%H:%MZ; }
ago() {
  local m=$(( ( $(date +%s) - $1 ) / 60 ))
  if [ "$m" -ge 60 ]; then echo "$(( m / 60 ))h$(printf %02d $(( m % 60 )))m"; else echo "${m}m"; fi
}

# A ship's minutes from begun to served, the median of the last five that
# served: begun when its _lead.out was made, served when its deploy ended.
ship_minutes() {
  local e f t b
  stat -c '%Y %n' "$RO"/*_prod.log 2>/dev/null | sort -rn | head -10 | while read -r e f; do
    t=$(basename "$f" _prod.log)
    grep -q '^SHIP: deploy: brickworks.diy serves' "$RO/${t}_lead.out" 2>/dev/null || continue
    b=$(stat -c %W "$RO/${t}_lead.out")
    [ "$b" -gt 0 ] && [ "$e" -gt "$b" ] && echo $(( (e - b + 59) / 60 ))
  done | head -5 | sort -n | awk '{m[NR] = $1} END {if (NR) print m[int((NR + 1) / 2)]}'
}

# When TAG should serve, or nothing: a ship under way (a train's or one
# begun by hand) from its start and the median ship.
eta_of() {
  [ -n "${ETA[$1]:-}" ] && { echo "${ETA[$1]}"; return; }
  local f=$RO/${1}_lead.out b
  [ -n "$SHIP_MIN" ] && [ -e "$f" ] && [ ! -e "$RO/$1.done" ] || return
  grep -q '^SHIP: deploy: brickworks.diy serves' "$f" && return
  b=$(stat -c %W "$f")
  [ "$b" -gt 0 ] && echo $(( b + SHIP_MIN * 60 ))
}

# The battery's line: TAG's checks passed of TOTAL (0: not known), those that
# failed, and how many are still to run.
checks_line() {
  local t=$1 total=$2 pv=$RO/${1}_pv.out passed failed="" n ran
  passed=$(grep -c ' exit=0 ' "$pv"); ran=$(grep -c ' exit=' "$pv")
  for n in $(grep -E ' exit=[^0]' "$pv" | awk '{print $1}'); do
    if grep -q ' exit=0 ' "$RO/${t}_alone_$n.out" 2>/dev/null; then failed="$failed $n (passed alone)"; else failed="$failed $n"; fi
  done
  if [ "$total" -gt 0 ]; then
    echo "  checks: $passed of $total passed${failed:+; failed:$failed}$( [ "$ran" -lt "$total" ] && echo "; $(( total - ran )) to run")"
  else
    echo "  checks: $passed passed so far${failed:+; failed:$failed}"
  fi
}

# The probes beside TAG's ship: passed of all named, those that failed, and
# how many are still to run, from this attempt's answers.
probes_line() {
  local t=$1 d=$RO/$1.train f n code fails passed=0 failed="" ran=0 total
  total=$(wc -w < "$d/probes")
  [ "$total" -gt 0 ] || return 0
  for f in "$RO/${t}"_probe_*.exit; do
    [ -e "$f" ] && [ "$f" -nt "$d/shipped" ] || continue
    n=${f#"$RO/${t}_probe_"}; n=${n%.exit}
    read -r code fails < "$f"; ran=$((ran + 1))
    if probe_ok "$code" "$fails"; then passed=$((passed + 1)); else failed="$failed $n"; fi
  done
  echo "  probes: $passed of $total passed${failed:+; failed:$failed}$( [ "$ran" -lt "$total" ] && echo "; $(( total - ran )) to run")"
}

# The checks named, as they ran on brickworks.diy when TAG was staged:
# those that fail there as live's own scripts, and those changed since.
stale_line() {
  local t=$1 f=$RO/${1}_stale.out asked ran n stale="" changed="" build left
  if [ -s "$RO/${t}_stale.skipped" ]; then
    echo "  on $SITE: not checked: $(paste -sd' ' "$RO/${t}_stale.skipped")"; return
  fi
  [ -e "$f" ] && [ -e "$RO/${t}_stale.asked" ] || return 0
  asked=$(wc -w < "$RO/${t}_stale.asked"); ran=$(grep -c ' exit=' "$f")
  for n in $(grep -E ' exit=[^0]' "$f" | awk '{print $1}'); do
    if grep -qx "$n" "$RO/${t}_stale.changed" 2>/dev/null; then changed="$changed $n"; else stale="$stale $n"; fi
  done
  build=$(cat "$RO/${t}_stale.build" 2>/dev/null); build=${build#/b/}; build=${build%/}
  left=""; grep -qx 'done' "$f" || [ "$ran" -ge "$asked" ] || left="; $(( asked - ran )) to run"
  echo "  on $SITE${build:+ (serving $build)} as staged: $(grep -c ' exit=0 ' "$f") of $asked passed$left${stale:+; already failing there:$stale}${changed:+; failing there, changed since:$changed}$( [ -n "$stale$changed" ] && echo " (${t}_stale_NAME.log)")"
}

# A ship begun by hand, not by a train: what it last said, its checks so far,
# and when it should serve.
show_hand() {
  local t=$1 f=$RO/${1}_lead.out pv=$RO/${1}_pv.out last eta
  last=$(grep '^SHIP:' "$f" | tail -1 | cut -c7-140)
  echo "$t: shipping, begun by hand at $(hm "$(stat -c %W "$f")")"
  echo "  ship: ${last:-its gates (ci_gate, the import, the parse gate, the tool list)}"
  [ -e "$pv" ] && [ "$(stat -c %W "$pv")" -ge "$(stat -c %W "$f")" ] && checks_line "$t" 0
  eta=$(eta_of "$t")
  [ -n "$eta" ] && { ETA[$t]=$eta; echo "  eta: serves about $(hm "$eta")"; }
  return 0
}

show() {
  local t=$1 d=$RO/$1.train after pid res total sha
  [ -d "$d" ] || { echo "$t: not staged"; return; }
  after=$(cat "$d/after" 2>/dev/null)
  if pid=$(runner "$t"); then pid="running (pid $pid)"; else pid="ended"; fi
  echo "$t: $(cat "$d/branch")${after:+ after $after}, $pid"
  res=$(cat "$d/result" 2>/dev/null)
  if [ -n "$res" ]; then
    echo "  result: $res"
  else
    echo "  step: $(cat "$d/step" 2>/dev/null || echo "not begun")"
  fi
  [ -z "$res" ] && [ -e "$d/shipped" ] && [ -s "$RO/${t}_lead.out" ] \
    && echo "  ship: $(grep '^SHIP:' "$RO/${t}_lead.out" | tail -1 | cut -c7-140)"
  # The checks of this attempt's battery only: one before left its own.
  if [ -e "$d/shipped" ] && [ "$RO/${t}_pv.out" -nt "$d/shipped" ]; then
    total=$( (cat "$d/shipped"; echo site frames) | tr ' ' '\n' | grep -v '^$' | sort -u | wc -l)
    checks_line "$t" "$total"
  fi
  [ -e "$d/shipped" ] && probes_line "$t"
  stale_line "$t"
  # Shipping: its start and the median ship. Before that, a lower bound:
  # no sooner than the release before it serves, and a ship after.
  local eta prev_eta now; now=$(date +%s)
  if [ -z "$res" ] && [ -n "$SHIP_MIN" ]; then
    if [ -e "$d/shipped" ]; then
      eta=$(eta_of "$t")
      if [ -n "$eta" ] && [ "$eta" -ge "$now" ]; then echo "  eta: serves about $(hm "$eta")"
      elif [ -n "$eta" ]; then echo "  eta: was $(hm "$eta"), $(ago "$eta") past a median ship"; fi
    else
      eta=$now
      prev_eta=$( [ -n "$after" ] && eta_of "$after")
      [ -n "$prev_eta" ] && [ "$prev_eta" -gt "$eta" ] && eta=$prev_eta
      eta=$(( eta + SHIP_MIN * 60 ))
      echo "  eta: serves $(hm "$eta") at the earliest"
    fi
    [ -n "$eta" ] && ETA[$t]=$eta
  fi
  sha=$(cat "$d/sha" 2>/dev/null)
  case "$LIVE_NOW" in
    "") echo "  live: brickworks.diy did not answer" ;;
    "${sha:-none}"*) echo "  live: brickworks.diy serves it ($sha)" ;;
    *) echo "  live: not yet${sha:+ ($sha)}; brickworks.diy serves $LIVE_NOW" ;;
  esac
}

status() {
  local tags=() d t f lt m since=0 who=""
  local -A ETA=()
  LIVE_NOW=$(serving); LIVE_NOW=${LIVE_NOW#/b/}; LIVE_NOW=${LIVE_NOW%/}
  SHIP_MIN=$(ship_minutes)
  # What is live, and since when: the release whose ship said it serves this
  # build, from the end of its deploy.
  if [ -z "$LIVE_NOW" ]; then
    echo "live: brickworks.diy did not answer"
  else
    for f in $(grep -l "^SHIP: deploy: brickworks.diy serves ${LIVE_NOW:0:7}" "$RO"/*_lead.out "$RO"/*_ship.log 2>/dev/null); do
      lt=$(basename "$f"); lt=${lt%_lead.out}; lt=${lt%_ship.log}
      m=$(stat -c %Y "$RO/${lt}_prod.log" 2>/dev/null || stat -c %Y "$f")
      [ "$m" -gt "$since" ] && since=$m && who=$lt
    done
    [ -n "$who" ] && who=", ${who}'s, since $(hm "$since") ($(ago "$since") ago)"
    echo "live: brickworks.diy serves $LIVE_NOW$who"
  fi
  [ -n "$SHIP_MIN" ] && echo "a ship takes about $SHIP_MIN min from begun to served (the median of the last five)"
  if [ $# -gt 0 ]; then
    tags=("$@")
  else
    # Running, or ended in the last 12 hours.
    for d in "$RO"/*.train; do
      [ -d "$d" ] || continue
      t=$(basename "$d" .train)
      runner "$t" >/dev/null || [ $(( $(date +%s) - $(stat -c %Y "$d/step" 2>/dev/null || echo 0) )) -lt 43200 ] || continue
      tags+=("$t")
    done
    # And a ship begun by hand that has not ended (ship.sh writes TAG.done as it ends).
    for f in "$RO"/*_lead.out; do
      [ -e "$f" ] || continue
      t=$(basename "$f" _lead.out)
      [ -d "$RO/$t.train" ] || [ -e "$RO/$t.done" ] && continue
      [ $(( $(date +%s) - $(stat -c %Y "$f") )) -lt 43200 ] && tags+=("$t")
    done
  fi
  [ ${#tags[@]} -gt 0 ] || { echo "train: none staged or running in $RO"; return; }
  for t in $(printf '%s\n' "${tags[@]}" | sort -V); do
    if [ -d "$RO/$t.train" ] || [ ! -e "$RO/${t}_lead.out" ]; then show "$t"; else show_hand "$t"; fi
  done
  for h in "$RO"/HOLD "$RO"/*.hold; do [ -e "$h" ] && echo "hold: $(basename "$h"): $(cat "$h")"; done
  return 0
}

cmd=${1:-}; shift || true
case "$cmd" in
  stage) stage "$@" ;;
  status) status "$@" ;;
  hold) hold "$@" ;;
  release) release "$@" ;;
  reship) reship "$@" ;;
  run|probes|stale) [ $# -eq 1 ] || usage; "$cmd" "$1" ;;
  *) usage ;;
esac
