#!/bin/bash
# timing_ab.sh BASE_WT NEW_WT ROUNDS OUT -- FLOW [ARGS...]
# A timing check that failed on a preview, played on two web builds side by
# side, alternating, so a busy box weighs on both alike: is it the change or
# the load? Each worktree's build/web (tools/export.sh web, made first) is
# served on its own port, and FLOW is run against each in turn, ROUNDS times,
# with @URL@ in its arguments replaced by that build's address. Each run's
# log is OUT/<base|new>_r<N>.log; one line a run is printed: the load it
# began at, then the lines matching AB_SHOW (an ERE; default the play
# flow's drag frames).
#
#   tools/release/timing_ab.sh .claude/worktrees/snap141 .claude/worktrees/rel-m142 3 $S/drag_ab -- \
#     node tools/web/play_flow.mjs --url=@URL@ --sizes=phone --no-house --out=@OUT@
#
# @OUT@ is the run's own folder for its pictures. AB_SERVE adds to serve.py's
# arguments (default: 8808-1 shared as play_flow's Pl4yFl0w01); AB_PORTS
# names the two ports (default 8871 8872). The flow runs from NEW_WT's
# checkout for both, so both are judged by the same check.
#
# m142's phone drag failed twice on its preview at load 35 (36.9, 38.8 ms
# against a 33 ms bar); played this way the live m141 failed the same bar 2
# runs in 3 and the two builds' means were 13.07 and 12.98 ms: the load, not
# the change (2026-10-22). Done by hand three times before this was written.
set -u
[ $# -ge 6 ] && [ "$5" = "--" ] || { sed -n 2,20p "$0"; exit 2; }
BASE=$(cd "$1" && pwd) || exit 2; NEW=$(cd "$2" && pwd) || exit 2
ROUNDS=$3; OUT=$4; shift 5
SHOW=${AB_SHOW:-"drag frames|drag frame stays"}
read -r P_BASE P_NEW <<< "${AB_PORTS:-8871 8872}"
SERVE=${AB_SERVE:-"--share Pl4yFl0w01=vendor/omr/files/8808-1.mpd"}
mkdir -p "$OUT"
for w in "$BASE" "$NEW"; do
  [ -f "$w/build/web/index.html" ] || { echo "timing_ab: no build/web in $w (tools/export.sh web)"; exit 2; }
done
pids=()
serve() {
  # shellcheck disable=SC2086
  (cd "$1" && exec python3 tools/web/serve.py build/web "$2" --parts assets/generated/parts --delay 0 $SERVE \
     > "$OUT/serve_$3.log" 2>&1) &
  pids+=($!)
}
serve "$BASE" "$P_BASE" base
serve "$NEW" "$P_NEW" new
trap 'kill "${pids[@]}" 2>/dev/null' EXIT
for port in "$P_BASE" "$P_NEW"; do
  timeout 30 bash -c "until curl -sf -o /dev/null http://127.0.0.1:$port/; do sleep 1; done" \
    || { echo "timing_ab: nothing serves on $port"; exit 1; }
done
for round in $(seq 1 "$ROUNDS"); do
  for side in base new; do
    port=$P_BASE; [ $side = new ] && port=$P_NEW
    run="$OUT/${side}_r$round"
    args=()
    for a in "$@"; do a=${a//@URL@/http://127.0.0.1:$port}; args+=("${a//@OUT@/$run}"); done
    load=$(cut -d' ' -f1 /proc/loadavg)
    (cd "$NEW" && timeout 900 ~/.claude/claude-core/bin/heavy "${args[@]}" > "$run.log" 2>&1)
    echo "$side r$round load=$load exit=$? $(grep -E "$SHOW" "$run.log" | tr -s ' ' | cut -c1-220 | tr '\n' ' ')"
  done
done
