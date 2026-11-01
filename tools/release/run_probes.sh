#!/bin/bash
# run_probes.sh OUT_PREFIX PROBE[:ARGS]... : the probes a release owes, one
# at a time through tools/probe.sh, each judged by its exit and its lines.
#
#   tools/release/run_probes.sh $S/rel/m125 fetch_retry_probe "grab_probe:--only=racks"
#
# Prints one line a probe, "NAME exit=N ok=K fail=F", and exits 1 if any
# failed. A probe that exits 0 but says nothing passed is "unproven" and
# fails too: open_probe and remote_probe printed no ok line and kept their
# data when the worktree had no web pack, and a hand-written loop that read
# $? after a grep called them passed (m125, 2026-10-20).
# Logs: OUT_PREFIX_NAME.log.
set -u
cd "$(dirname "$0")/../.." || exit 1
# The probes run in the checkout this script is in, not the caller's: main's
# copy called from a release worktree probed main (2026-10-22). Said first.
echo "run_probes: in $(pwd) at $(git log --oneline -1 | cut -c1-60)"
prefix="$1"; shift
bad=0
for spec in "$@"; do
  name="${spec%%:*}"
  # A bare name runs as the suite lists it: rel-m234's spec named
  # open_menu_reach, which tools/suite runs with --phone, and the probe laid
  # the desktop out in a phone's window and failed (2026-11-01).
  if [ "$spec" = "$name" ]; then
    listed=$(sed 's/#.*//' tools/suite/windowed.txt tools/suite/headless.txt \
      | awk -v n="${name%_probe}" '{ split($1, p, ":"); s = p[1]; sub(/_probe$/, "", s) } s == n && $1 ~ /:/ { print $1; exit }')
    [ -n "$listed" ] && spec="$name:${listed#*:}"
  fi
  args=()
  [ "$spec" != "$name" ] && read -r -a args <<< "${spec#*:}"
  log="${prefix}_${name}.log"
  args=("${args[@]/#@out/${prefix}_${name}_out}")
  timeout 2400 tools/probe.sh "$name" "${args[@]}" > "$log" 2>&1
  code=$?
  # "ok   ..." in most probes, "PASS: ..." in some (own_copies_probe).
  ok=$(grep -cE '^\s*(ok |PASS:)' "$log")
  fail=$(grep -ciE '^\s*FAIL' "$log")
  verdict="passed"
  if [ "$code" != 0 ] || [ "$fail" != 0 ]; then
    verdict="FAILED"; bad=1
  elif [ "$ok" = 0 ] && ! grep -qE 'lossless|passed|every check|all ok' "$log"; then
    verdict="unproven (no ok line)"; bad=1
  fi
  echo "$name exit=$code ok=$ok fail=$fail $verdict"
  [ "$verdict" = passed ] || grep -E '^\s*FAIL|no web pack|SKIPPED|SCRIPT ERROR|two scripts are|not run:' "$log" | head -3 | sed 's/^/    /'
done
exit $bad
