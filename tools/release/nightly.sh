#!/bin/bash
# nightly.sh : every browser check and every headless probe on pre261, once a
# day at the box's quiet hours, never per release (fastship, 2026-11-23).
#
#   nightly.sh run [REF]     REF (origin/pre261): a preview of it, every check
#                            preview_checks.sh knows, each failure once more
#                            alone, and every probe tools/suite/headless.txt
#                            lists, inside NIGHTLY_HOURS (4); the passes
#                            written as proof as they come (lean.py)
#   nightly.sh plan [REF]    what a run would run, in what order, each check's
#                            bound and the time it would take, and nothing else
#   nightly.sh dry [CHECK...]  the run's scheduling, its phases and its alone
#                            reruns, on the checks named (6 by default), each
#                            a sleep of its bound over NIGHTLY_DRY_SCALE (60)
#   nightly.sh install [HH:MM]   a systemd user timer that runs it daily at
#                            HH:MM local time (18:00), from the main checkout
#   nightly.sh status        the last run's summary, or the one under way's
#
# Why: a release ran every check its branch's files named since main and
# every headless probe: rel-m319's 24 units named 146 of 150 checks and 293
# probes, and its 8 attempts took 13 hours (2026-11-23). A release now runs
# only what its own change against live reaches, less what was proven since
# (lean.py), and this run proves everything once a day, so a check or probe
# the lean list left out is found the next morning at the latest, and a
# release that day carries its proof: it runs only what merged since.
#
# The quiet hours: sar's 1-minute load, averaged per hour over the week to
# 2026-11-23, was lowest from 18:00 to 22:00 local (44-47 on 24 cores; 69 at
# its peak, 07:00). It takes no release's priority: a train's jobs go first.
#
# Inside the quiet hours (nightreds, 2026-11-24): the first run took 9.5 hours
# for its 162 checks and its alone reruns went one at a time behind them, past
# 05:00 into the working day, holding slots that units waited on; and its
# proof was written only at its end, so a run stopped early proved nothing.
# Now, NIGHTLY_HOURS (4) from its start, it is done:
#   - each check stops at its own bound (preview_checks.sh PC_BOUNDS), twice
#     what it took the last times it passed here, 300 to 2,700 s (3,600 for a
#     dialogs check), not 2,700 s for every one; none is begun whose bound
#     would end past the time, and none waits for a slot past it
#     (PC_DEADLINE): it says "not run", and is the next night's to prove;
#   - the checks run NIGHTLY_AT_ONCE (5) at a time, the longest first, so the
#     last to end is not a long one begun late;
#   - the timing checks run alone after them, with no probe of the run's own
#     begun meanwhile (PC_CALM): each waited out 600 s of them, eight times
#     the first night (nightly-20261124_pv_calm.log), and now waits for the
#     project's other jobs NIGHTLY_SOLO_WAIT (120 s) at most;
#   - the failures run again alone NIGHTLY_ALONE_AT_ONCE (4) at a time;
#   - the probes run NIGHTLY_PROBES_AT_ONCE (3) at a time beside the checks,
#     each at most NIGHTLY_PROBE_BOUND (1,200 s);
#   - what passed is recorded every minute something new does (lean.py
#     record, the run's earlier record of it replaced), and the summary so far
#     written, so a run stopped at any point leaves what it proved.
#
# Its output: $RELEASE_OUT/nightly-YYYYMMDD_* (the preview, pv.out, alone_*,
# probe_*, bounds), nightly-YYYYMMDD.summary, and nightly.latest naming the
# last summary. Its worktree and branch go when it ends. It never moves main,
# never promotes, and runs nothing on brickworks.diy.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ORIG=$HERE
R=$(dirname "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)")
S=$(realpath -m "${RELEASE_OUT:-$R/bench/results/release-out}"); mkdir -p "$S"
export RELEASE_OUT=$S
HOURS=${NIGHTLY_HOURS:-4}
AT_ONCE=${NIGHTLY_AT_ONCE:-5}
ALONE_AT_ONCE=${NIGHTLY_ALONE_AT_ONCE:-4}
PROBES_AT_ONCE=${NIGHTLY_PROBES_AT_ONCE:-3}
PROBE_BOUND=${NIGHTLY_PROBE_BOUND:-1200}
SOLO_WAIT=${NIGHTLY_SOLO_WAIT:-120}
ALONE_SHARE=${NIGHTLY_ALONE_SHARE:-10}
TIMED_SHARE=${NIGHTLY_TIMED_SHARE:-30}

# Every check preview_checks.sh knows, by its map's keys.
all_checks() { grep -oE '^[[:space:]]*\[[a-z_0-9]+\]=' "$1/tools/release/preview_checks.sh" | tr -d '[]= \t' | awk '!seen[$0]++'; }
# The timing checks, which preview_checks.sh runs alone after the rest.
solo_checks() { sed -n 's/^SOLO=" *\(.*\) *"$/\1/p' "$1/tools/release/preview_checks.sh" | head -1; }
# The probes a tools/suite list names, as check.sh and train.sh read it.
suite_names() { sed -E 's/(^|[[:space:]])#.*//' "$1" | awk 'NF { split($1, p, ":"); print p[1] }'; }
# bounds OUT NAME...: each check's bound, NAME SECONDS a line: twice the
# middle of what its last five passes here took (a battery's, a unit's or an
# alone rerun's line, NAME exit=0 ... Ns, archived ones too), else of its last
# five runs, 300 s at least and 2,700 at most (3,600 for a dialogs check).
# In the order they run: those with no proof of the last 36 hours first, then
# those proven longest ago (lean.py oldest), each lot the longest first, so
# what the time leaves for the next night is what a release proved today.
bounds() {
  local out=$1 n cap b; shift
  local files=()
  mapfile -t files < <(ls -t "$S"/*_pv.out "$S"/*_alone_*.out "$S"/archive/*_pv.out "$S"/archive/*_alone_*.out 2>/dev/null | head -600)
  : > "$out.tmp"
  for n in "$@"; do
    cap=2700; case "$n" in dialogs*) cap=3600 ;; esac
    b=""
    for ran in "exit=0 " "exit=[0-9]+ "; do
      [ -n "$b" ] && break
      b=$( { [ ${#files[@]} -eq 0 ] || grep -hE -m1 "^$n $ran" "${files[@]}" 2>/dev/null; } | head -5 \
        | awk '{ s = $4; sub(/s$/, "", s); if (s + 0 > 0) print s + 0 }' | sort -n \
        | awk -v cap="$cap" '{ v[NR] = $1 } END { if (!NR) exit; b = 2 * v[int((NR + 1) / 2)]
            if (b < 300) b = 300; if (b > cap) b = cap; print int(b) }')
    done
    echo "$n ${b:-$cap}" >> "$out.tmp"
  done
  sort -k2,2nr -k1,1 "$out.tmp" > "$out.long"
  local order=() names=()
  mapfile -t names < <(cut -d' ' -f1 "$out.long")
  read -r -a order <<< "$(python3 "${LEAN:-$HERE/lean.py}" oldest checks "${names[@]}" 2>/dev/null)"
  if [ ${#order[@]} -eq "$(wc -l < "$out.long")" ]; then
    for n in "${order[@]}"; do grep -m1 "^$n " "$out.long"; done > "$out"
  else
    cp "$out.long" "$out"
  fi
  rm -f "$out.tmp" "$out.long"
}
# split BOUNDS SOLO: the paired checks then the timing ones, longest first,
# as PAIRED and TIMED.
split() {
  PAIRED=(); TIMED=()
  local n b
  while read -r n b; do
    case " $2 " in *" $n "*) TIMED+=("$n") ;; *) PAIRED+=("$n") ;; esac
  done < "$1"
}
# The time a battery would take: its paired checks AT_ONCE at a time, then
# its timing ones one by one, at what they took when last passed (half the
# bound) and at most (the bound), in minutes.
forecast() {
  awk -v solo=" $2 " -v k="$AT_ONCE" '{ if (index(solo, " " $1 " ")) t += $2; else p += $2 }
    END { printf "%d to %d minutes (the checks %d at a time, then the timing ones alone)", (p / k + t) / 120, (p / k + t) / 60, k }' "$1"
}

case "${1:-}" in
  plan)
    ref=${2:-origin/pre261}
    tree=$(mktemp -d) || exit 1
    git -C "$R" archive "$ref" tools/release/preview_checks.sh tools/suite/headless.txt | tar -x -C "$tree"
    mapfile -t checks < <(all_checks "$tree")
    bounds "$tree/bounds" "${checks[@]}"
    solo=$(solo_checks "$tree")
    split "$tree/bounds" "$solo"
    echo "nightly: $ref at $(git -C "$R" rev-parse --short "$ref"): ${#checks[@]} checks, $(suite_names "$tree/tools/suite/headless.txt" | wc -l) headless probes, inside $HOURS hours"
    echo "  the checks, $AT_ONCE at a time, longest first: ${#PAIRED[@]}"
    echo "  then the timing checks, each alone, waiting ${SOLO_WAIT}s at most: ${#TIMED[@]} (${TIMED[*]})"
    echo "  then each failure again alone, $ALONE_AT_ONCE at a time (the timing ones one by one)"
    echo "  the probes beside them, $PROBES_AT_ONCE at a time, ${PROBE_BOUND}s each at most, none begun while a timing check runs"
    echo "  the battery: $(forecast "$tree/bounds" "$solo")"
    # How many the time holds, at what each took when it last passed, in the
    # order they run: what is left over is the next night's, and was proven
    # most lately.
    awk -v solo=" $solo " -v k="$AT_ONCE" -v span=$(( HOURS * 3600 )) -v alone="$ALONE_SHARE" -v most="$TIMED_SHARE" '
      { n[NR] = $1; t[NR] = $2 / 2; timed[NR] = index(solo, " " $1 " ") > 0; if (timed[NR]) tt += t[NR] }
      END { a = span * alone / 100; if (tt > span * most / 100) tt = span * most / 100; room = (span - a - tt) * k
            for (i = 1; i <= NR; i++) if (!timed[i]) { if (used + t[i] <= room) { used += t[i]; p++ } else left++ } else tc++
            for (i = 1; i <= NR; i++) if (timed[i]) { if (tu + t[i] <= tt) { tu += t[i]; tk++ } else tl++ }
            printf "  inside %d hours: about %d of %d checks and %d of %d timing ones; %d left for the next night, those proven most lately\n",
              span / 3600, p, p + left, tk, tc, left + tl }' "$tree/bounds"
    echo "  each check's bound (s), the longest first:"
    awk '{ printf "    %-22s %5d\n", $1, $2 }' "$tree/bounds" | column -c 120
    rm -rf "$tree"; exit 0 ;;
  status)
    f=$(realpath -e "$S/nightly.latest" 2>/dev/null) || { echo "nightly: no run yet"; exit 1; }
    cat "$f"; exit 0 ;;
  install)
    at=${2:-18:00}
    case "$at" in [0-2][0-9]:[0-5][0-9]) ;; *) echo "nightly: install HH:MM"; exit 2 ;; esac
    u=$HOME/.config/systemd/user; mkdir -p "$u"
    printf '[Unit]\nDescription=Brickworks: every check and probe on pre261 (tools/release/nightly.sh)\n\n[Service]\nType=oneshot\nWorkingDirectory=%s\nExecStart=/bin/bash %s/tools/release/nightly.sh run\nTimeoutStartSec=6h\n' "$R" "$R" > "$u/brickworks-nightly.service"
    printf '[Unit]\nDescription=Brickworks nightly checks at the quiet hours\n\n[Timer]\nOnCalendar=*-*-* %s:00\nPersistent=false\n\n[Install]\nWantedBy=timers.target\n' "$at" > "$u/brickworks-nightly.timer"
    systemctl --user daemon-reload && systemctl --user enable --now brickworks-nightly.timer \
      && systemctl --user list-timers brickworks-nightly.timer --no-pager | head -2
    exit ;;
  run|dry) ;;
  *) sed -n '4,17p' "$0"; exit 2 ;;
esac

MODE=$1; shift
say() { echo "$(date -u +%H:%M:%SZ) $TAG: $*"; }
t0=$EPOCHSECONDS
DEADLINE=$(( t0 + HOURS * 3600 ))
unset BOX_HEAVY_PRIORITY BOX_HEAVY_NICE
export BOX_HEAVY_WAIT=${BOX_HEAVY_WAIT:-21600}

if [ "$MODE" = run ]; then
  REF=${1:-origin/pre261}
  TAG=nightly-$(date -u +%Y%m%d)
  W=$R/.claude/worktrees/$TAG
  exec 9> "$S/nightly.lock"
  flock -n 9 || { echo "nightly: a run is under way ($S/nightly.lock)"; exit 1; }
  timeout 300 git -C "$R" fetch -q origin 2>&1 | tail -1
  [ -e "$W" ] && { say "$W exists: retire it (retire_wt.sh $TAG) first"; exit 1; }
  git -C "$R" rev-parse -q --verify "refs/heads/$TAG" >/dev/null && git -C "$R" branch -q -D "$TAG"
  bash "$HERE/release_wt.sh" "$TAG" "$REF" >/dev/null || { say "could not make $W"; exit 1; }
  # Its worktree and branch go whatever happens: they hold nothing of their own.
  trap 'kill "${RECORDER:-}" 2>/dev/null; cd "$R" && bash "$ORIG/retire_wt.sh" "$TAG" >/dev/null 2>&1; git -C "$R" branch -q -D "$TAG" 2>/dev/null' EXIT
  cd "$W" || exit 1
else
  # A dry run: this checkout's scripts, no preview and no probes, its lines
  # and proof in a folder of their own (dry/).
  TAG=nightly-dry-$(date -u +%Y%m%d%H%M%S)
  W=$(git -C "$HERE" rev-parse --show-toplevel)
  cd "$W" || exit 1
  export PC_DRY=${NIGHTLY_DRY_SCALE:-60}
  # The first two named fail and the last, to be run again alone.
  [ $# -gt 0 ] || set -- age builds makes studiostart play load
  export PC_DRY_FAIL="${NIGHTLY_DRY_FAIL:-$1 $2 ${*: -1}}"
  DEADLINE=$(( t0 + HOURS * 3600 / PC_DRY ))
fi
# Each check's bound from what this folder's runs took (a dry run's own lines
# kept apart, so they never read as passes).
mapfile -t checks < <(all_checks "$W")
[ "$MODE" = dry ] && checks=("$@")
BOUNDS=$S/${TAG}_bounds
bounds "$BOUNDS" "${checks[@]}"
if [ "$MODE" = dry ]; then
  S=$S/dry; mkdir -p "$S"; export RELEASE_OUT=$S; mv -f "$BOUNDS" "$S/"; BOUNDS=$S/${TAG}_bounds
fi
SHA=$(git rev-parse HEAD)
say "every check and headless probe on ${REF:-this checkout} at ${SHA:0:9}, inside $HOURS hours (by $(date -u -d "@$DEADLINE" +%H:%MZ))"
# Its own tree's scripts decide what runs, as a release's do; the proof is
# written by this one's lean.py where the tree has none yet.
HERE=$W/tools/release
LEAN=$HERE/lean.py; [ -f "$LEAN" ] || LEAN=$ORIG/lean.py
. "$HERE/preview_lib.sh" UNIT || exit 1
CALM=$S/$TAG.calm; rm -f "$CALM"
SOLO=$(solo_checks "$W")
split "$BOUNDS" "$SOLO"
export PC_BOUNDS=$BOUNDS PC_DEADLINE=$DEADLINE PC_CALM=$CALM
# The time's shares: the alone reruns keep the last NIGHTLY_ALONE_SHARE
# percent (10) of it, the timing checks before them what they took when last
# passed (half their bounds), at most NIGHTLY_TIMED_SHARE percent (30), and the
# rest of the checks the time before that. 164 checks and 308 probes are
# about 31 slot-hours of the box, and 4 hours of brickworks' 8 slots are 32,
# less what the timing checks leave idle: a night holds about three in four,
# and the rest, proven most lately, are the next night's (nightly.sh plan).
span=$(( DEADLINE - t0 ))
alone_share=$(( span * ALONE_SHARE / 100 ))
timed_share=$(awk -v solo=" $SOLO " -v scale="${PC_DRY:-1}" 'index(solo, " " $1 " ") { t += $2 / 2 / scale } END { print int(t) }' "$BOUNDS")
[ "$timed_share" -le $(( span * TIMED_SHARE / 100 )) ] || timed_share=$(( span * TIMED_SHARE / 100 ))
PAIRED_BY=$(( DEADLINE - alone_share - timed_share )); TIMED_BY=$(( DEADLINE - alone_share ))

# What the run has proven so far, written as it goes: the checks that passed
# (a later alone rerun's line over the battery's) and the probes, each kind
# one record of this run's, replaced as it grows, and the summary so far.
outs() { local f; echo "$S/${TAG}_pv.out"; for f in "$S/${TAG}"_alone_*.out; do [ -e "$f" ] && echo "$f"; done; }
probes_passed() {
  local p code fails
  for p in "${probes[@]}"; do
    read -r code fails < "$S/${TAG}_probe_$p.exit" 2>/dev/null || continue
    [ "$code" = 0 ] && [ "$fails" = 0 ] && echo "$p"
  done
}
keep_one() {
  local kind=$1 said=$2 f made
  made=$(sed -n 's/.*(\([^()]*\))$/\1/p' <<< "$said")
  [ -n "$made" ] || return 0
  for f in "$S/proofs/$kind/$TAG".*; do [ -e "$f" ] && [ "${f##*/}" != "$made" ] && rm -f "$f"; done
}
summarize() {
  local state=$1 n line failed=() unrun=() ok
  for n in "${checks[@]}"; do
    line=$(grep -h -m1 "^$n exit=" "$S/${TAG}_alone_$n.out" 2>/dev/null || grep -h -m1 "^$n exit=" "$S/${TAG}_pv.out" 2>/dev/null)
    case "$line" in *" exit=0 "*) ;; "") unrun+=("$n") ;; *" exit=125 "*) unrun+=("$n") ;; *) failed+=("$n") ;; esac
  done
  ok=$(probes_passed | wc -l)
  {
    echo "nightly $TAG: ${REF:-dry} at ${SHA:0:9}, $(( (EPOCHSECONDS - t0) / 60 )) minutes, $state, preview $(grep -oE 'https://[^ ]+' "$S/${TAG}_deploy.out" 2>/dev/null | tail -1)"
    echo "checks: $(( ${#checks[@]} - ${#failed[@]} - ${#unrun[@]} )) of ${#checks[@]} passed${failed[*]:+; failed, beside others and alone: ${failed[*]}}${unrun[*]:+; not run yet: ${unrun[*]}}"
    echo "probes: $ok of ${#probes[@]} passed$(red=$(for p in "${probes[@]}"; do read -r c f < "$S/${TAG}_probe_$p.exit" 2>/dev/null && { [ "$c" = 0 ] && [ "$f" = 0 ] || printf ' %s' "$p"; }; done); [ -n "$red" ] && echo "; failed:$red")"
  } > "$S/$TAG.summary.tmp" && mv -f "$S/$TAG.summary.tmp" "$S/$TAG.summary"
  ln -sfn "$TAG.summary" "$S/nightly.latest"
}
record_now() {
  # A dry run's go to its own folder's proofs (RELEASE_OUT is dry/ then),
  # which no release reads.
  local state=${1:-under way} said list
  mapfile -t list < <(outs)
  said=$(python3 "$LEAN" record checks "$TAG" "$SHA" "$SHA" "${list[@]}" 2>&1) && keep_one checks "$said"
  list=("$(probes_passed | tr '\n' ' ')")
  [ -n "${list[0]// /}" ] && said=$(python3 "$LEAN" record probes "$TAG" "$SHA" "$SHA" --passed "${list[0]}" 2>&1) \
    && keep_one probes "$said"
  summarize "$state"
}

probes=()
if [ "$MODE" = run ]; then
  set -a; . "$R/.env"; set +a
  import_here > "$S/${TAG}_import.log" 2>&1 || { say "the import did not finish (${TAG}_import.log)"; exit 1; }
  mapfile -t probes < <(suite_names tools/suite/headless.txt)
  # Those proven longest ago first, as the checks: the time may not hold all.
  read -r -a oldest_first <<< "$(python3 "$LEAN" oldest probes "${probes[@]}" 2>/dev/null)"
  [ ${#oldest_first[@]} -eq ${#probes[@]} ] && probes=("${oldest_first[@]}")
fi
# Every minute, when something new has ended, the proof so far.
(
  seen=""
  while :; do
    mapfile -t ended < <(outs)
    now=$(cat "${ended[@]}" 2>/dev/null | wc -l):$(find "$S" -maxdepth 1 -name "${TAG}_probe_*.exit" 2>/dev/null | wc -l)
    [ "$now" != "$seen" ] && { record_now; seen=$now; }
    sleep 60
  done
) &
RECORDER=$!
# The probes beside the checks, PROBES_AT_ONCE at a time, each under heavy as
# probe.sh runs it, bounded inside heavy; none begun while a timing check
# runs alone, nor once its bound would end past the run's time.
(
  for p in "${probes[@]}"; do
    while [ "$(jobs -rp | wc -l)" -ge "$PROBES_AT_ONCE" ]; do wait -n; done
    while [ -e "$CALM" ]; do sleep 15; done
    left=$(( DEADLINE - EPOCHSECONDS - PROBE_BOUND ))
    if [ "$left" -lt 0 ]; then echo "125 1" > "$S/${TAG}_probe_$p.exit"; echo "not run: the run's time" > "$S/${TAG}_probe_$p.log"; continue; fi
    ( BOX_HEAVY_WAIT=$(( left < 60 ? 60 : left )) PROBE_TIMEOUT=$PROBE_BOUND PROBE_LISTED=1 bash tools/probe.sh "$p" > "$S/${TAG}_probe_$p.log" 2>&1
      echo "$? $(grep -cE '^\s*FAIL' "$S/${TAG}_probe_$p.log")" > "$S/${TAG}_probe_$p.exit" ) &
  done
  wait
) &
PROBES=$!
URL=https://dry.invalid
if [ "$MODE" = run ]; then
  deploy_preview "$TAG" "${SHA:0:9}" > "$S/${TAG}_deploy.out" 2>&1 || { say "the preview did not deploy ($(tail -1 "$S/${TAG}_deploy.out"))"; wait "$PROBES"; record_now "stopped: no preview"; exit 1; }
  URL=$(grep -oE 'https://[^ ]+' "$S/${TAG}_deploy.out" | tail -1)
fi
say "preview $URL: ${#PAIRED[@]} checks $AT_ONCE at a time, then ${#TIMED[@]} timing checks alone; ${#probes[@]} probes beside them"
say "the battery: $(forecast "$BOUNDS" "$SOLO")"
# The battery: the paired checks, the longest first, then the timing ones,
# each alone (preview_checks.sh's own order, PC_CALM held meanwhile).
say "the checks by $(date -u -d "@$PAIRED_BY" +%H:%MZ), the timing ones by $(date -u -d "@$TIMED_BY" +%H:%MZ), the reruns by $(date -u -d "@$DEADLINE" +%H:%MZ)"
PC_DEADLINE=$PAIRED_BY PC_SOLO_DEADLINE=$TIMED_BY BOX_HEAVY_SOLO_WAIT=$SOLO_WAIT PC_AT_ONCE=$AT_ONCE \
  run_checks "$URL" "${TAG}_pv" "${PAIRED[@]}" "${TIMED[@]}" > /dev/null 2>&1
say "the battery ended: $(grep -c ' exit=0 ' "$S/${TAG}_pv.out") of ${#checks[@]} passed"
record_now
# Each failure once more alone: the paired ones ALONE_AT_ONCE at a time, then
# the timing ones one by one, as the battery ran them.
again=(); again_timed=()
for n in "${PAIRED[@]}"; do grep -q "^$n exit=0 " "$S/${TAG}_pv.out" || again+=("$n"); done
for n in "${TIMED[@]}"; do grep -q "^$n exit=0 " "$S/${TAG}_pv.out" || again_timed+=("$n"); done
(
  for n in "${again[@]}"; do
    while [ "$(jobs -rp | wc -l)" -ge "$ALONE_AT_ONCE" ]; do wait -n; done
    run_checks "$URL" "${TAG}_alone_$n" "$n" > /dev/null 2>&1 &
  done
  wait
)
for n in "${again_timed[@]}"; do BOX_HEAVY_SOLO_WAIT=$SOLO_WAIT run_checks "$URL" "${TAG}_alone_$n" "$n" > /dev/null 2>&1; done
say "the alone reruns ended"
wait "$PROBES"
kill "$RECORDER" 2>/dev/null; wait "$RECORDER" 2>/dev/null
record_now "ended"
cat "$S/$TAG.summary"
