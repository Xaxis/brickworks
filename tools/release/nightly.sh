#!/bin/bash
# nightly.sh : every browser check and every headless probe on pre261, once a
# day at the box's quiet hours, never per release (fastship, 2026-11-23).
#
#   nightly.sh run [REF]     REF (origin/pre261): a preview of it, every check
#                            preview_checks.sh knows, each failure once more
#                            alone, and every probe tools/suite/headless.txt
#                            lists; the passes written as proof (lean.py)
#   nightly.sh plan [REF]    what a run would run, and nothing else
#   nightly.sh install [HH:MM]   a systemd user timer that runs it daily at
#                            HH:MM local time (18:00), from the main checkout
#   nightly.sh status        the last run's summary
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
# Its output: $RELEASE_OUT/nightly-YYYYMMDD_* (the preview, pv.out, alone_*,
# probe_*), nightly-YYYYMMDD.summary, and nightly.latest naming the last
# summary. Its worktree and branch go when it ends. It never moves main,
# never promotes, and runs nothing on brickworks.diy.
set -u
HERE=$(cd "$(dirname "$0")" && pwd); ORIG=$HERE
R=$(dirname "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)")
S=$(realpath -m "${RELEASE_OUT:-$R/bench/results/release-out}"); mkdir -p "$S"
export RELEASE_OUT=$S

# Every check preview_checks.sh knows, by its map's keys.
all_checks() { grep -oE '^[[:space:]]*\[[a-z_0-9]+\]=' "$1/tools/release/preview_checks.sh" | tr -d '[]= \t' | awk '!seen[$0]++'; }
# The probes a tools/suite list names, as check.sh and train.sh read it.
suite_names() { sed -E 's/(^|[[:space:]])#.*//' "$1" | awk 'NF { split($1, p, ":"); print p[1] }'; }

case "${1:-}" in
  plan)
    ref=${2:-origin/pre261}
    tree=$(mktemp -d) || exit 1
    git -C "$R" archive "$ref" tools/release/preview_checks.sh tools/suite/headless.txt | tar -x -C "$tree"
    echo "nightly: $ref at $(git -C "$R" rev-parse --short "$ref"): $(all_checks "$tree" | wc -l) checks, $(suite_names "$tree/tools/suite/headless.txt" | wc -l) headless probes"
    rm -rf "$tree"; exit 0 ;;
  status)
    f=$(realpath -e "$S/nightly.latest" 2>/dev/null) || { echo "nightly: no run yet"; exit 1; }
    cat "$f"; exit 0 ;;
  install)
    at=${2:-18:00}
    case "$at" in [0-2][0-9]:[0-5][0-9]) ;; *) echo "nightly: install HH:MM"; exit 2 ;; esac
    u=$HOME/.config/systemd/user; mkdir -p "$u"
    printf '[Unit]\nDescription=Brickworks: every check and probe on pre261 (tools/release/nightly.sh)\n\n[Service]\nType=oneshot\nWorkingDirectory=%s\nExecStart=/bin/bash %s/tools/release/nightly.sh run\nTimeoutStartSec=12h\n' "$R" "$R" > "$u/brickworks-nightly.service"
    printf '[Unit]\nDescription=Brickworks nightly checks at the quiet hours\n\n[Timer]\nOnCalendar=*-*-* %s:00\nPersistent=false\n\n[Install]\nWantedBy=timers.target\n' "$at" > "$u/brickworks-nightly.timer"
    systemctl --user daemon-reload && systemctl --user enable --now brickworks-nightly.timer \
      && systemctl --user list-timers brickworks-nightly.timer --no-pager | head -2
    exit ;;
  run) ;;
  *) sed -n '4,13p' "$0"; exit 2 ;;
esac

REF=${2:-origin/pre261}
TAG=nightly-$(date -u +%Y%m%d)
W=$R/.claude/worktrees/$TAG
LOCK=$S/nightly.lock
exec 9> "$LOCK"
flock -n 9 || { echo "nightly: a run is under way ($LOCK)"; exit 1; }
say() { echo "$(date -u +%H:%M:%SZ) $TAG: $*"; }
timeout 300 git -C "$R" fetch -q origin 2>&1 | tail -1
[ -e "$W" ] && { say "$W exists: retire it (retire_wt.sh $TAG) first"; exit 1; }
git -C "$R" rev-parse -q --verify "refs/heads/$TAG" >/dev/null && git -C "$R" branch -q -D "$TAG"
bash "$HERE/release_wt.sh" "$TAG" "$REF" >/dev/null || { say "could not make $W"; exit 1; }
# Its worktree and branch go whatever happens: they hold nothing of their own.
trap 'cd "$R" && bash "$ORIG/retire_wt.sh" "$TAG" >/dev/null 2>&1; git -C "$R" branch -q -D "$TAG" 2>/dev/null' EXIT
cd "$W" || exit 1
SHA=$(git rev-parse HEAD)
say "every check and headless probe on $REF at ${SHA:0:9}"
unset BOX_HEAVY_PRIORITY BOX_HEAVY_NICE
export BOX_HEAVY_WAIT=${BOX_HEAVY_WAIT:-21600}
# Its own tree's scripts decide what runs, as a release's do; the proof is
# written by this one's lean.py where the tree has none yet.
HERE=$W/tools/release
LEAN=$HERE/lean.py; [ -f "$LEAN" ] || LEAN=$ORIG/lean.py
. "$HERE/preview_lib.sh" UNIT || exit 1
set -a; . "$R/.env"; set +a
t0=$EPOCHSECONDS
import_here > "$S/${TAG}_import.log" 2>&1 || { say "the import did not finish (${TAG}_import.log)"; exit 1; }
mapfile -t probes < <(suite_names tools/suite/headless.txt)
# The probes beside the battery, NIGHTLY_PROBES_AT_ONCE at a time (4), each
# under heavy as probe.sh runs it.
(
  at_once=${NIGHTLY_PROBES_AT_ONCE:-4}
  for p in "${probes[@]}"; do
    while [ "$(jobs -rp | wc -l)" -ge "$at_once" ]; do wait -n; done
    ( PROBE_LISTED=1 bash tools/probe.sh "$p" > "$S/${TAG}_probe_$p.log" 2>&1
      echo "$? $(grep -cE '^\s*FAIL' "$S/${TAG}_probe_$p.log")" > "$S/${TAG}_probe_$p.exit" ) &
  done
  wait
) &
PROBES=$!
deploy_preview "$TAG" "${SHA:0:9}" > "$S/${TAG}_deploy.out" 2>&1 || { say "the preview did not deploy ($(tail -1 "$S/${TAG}_deploy.out"))"; wait "$PROBES"; exit 1; }
URL=$(grep -oE 'https://[^ ]+' "$S/${TAG}_deploy.out" | tail -1)
mapfile -t checks < <(all_checks "$W")
say "preview $URL: ${#checks[@]} checks, ${#probes[@]} probes beside them"
run_checks "$URL" "${TAG}_pv" "${checks[@]}" > /dev/null 2>&1
alone=()
for n in "${checks[@]}"; do
  grep -q "^$n exit=0 " "$S/${TAG}_pv.out" && continue
  run_checks "$URL" "${TAG}_alone_$n" "$n" > /dev/null 2>&1
  alone+=("$S/${TAG}_alone_$n.out")
done
wait "$PROBES"
python3 "$LEAN" record checks "$TAG" "$SHA" "$SHA" "$S/${TAG}_pv.out" "${alone[@]}"
ok=(); red=()
for p in "${probes[@]}"; do
  read -r code fails < "$S/${TAG}_probe_$p.exit" 2>/dev/null || { red+=("$p"); continue; }
  if [ "$code" = 0 ] && [ "$fails" = 0 ]; then ok+=("$p"); else red+=("$p"); fi
done
[ ${#ok[@]} -eq 0 ] || python3 "$LEAN" record probes "$TAG" "$SHA" "$SHA" --passed "${ok[*]}"
failed=()
for n in "${checks[@]}"; do
  line=$(grep -h -m1 "^$n exit=" "$S/${TAG}_alone_$n.out" 2>/dev/null || grep -m1 "^$n exit=" "$S/${TAG}_pv.out")
  case "$line" in *" exit=0 "*) ;; *) failed+=("$n") ;; esac
done
{
  echo "nightly $TAG: $REF at ${SHA:0:9}, $(( (EPOCHSECONDS - t0) / 60 )) minutes, preview $URL"
  echo "checks: $(( ${#checks[@]} - ${#failed[@]} )) of ${#checks[@]} passed${failed[*]:+; failed, beside others and alone: ${failed[*]}}"
  echo "probes: ${#ok[@]} of ${#probes[@]} passed${red[*]:+; failed: ${red[*]}}"
} > "$S/$TAG.summary"
ln -sfn "$TAG.summary" "$S/nightly.latest"
cat "$S/$TAG.summary"
