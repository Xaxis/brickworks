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
prefix="$1"; shift
bad=0
for spec in "$@"; do
  name="${spec%%:*}"
  args=()
  [ "$spec" != "$name" ] && read -r -a args <<< "${spec#*:}"
  log="${prefix}_${name}.log"
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
  [ "$verdict" = passed ] || grep -E '^\s*FAIL|no web pack|SKIPPED|SCRIPT ERROR' "$log" | head -3 | sed 's/^/    /'
done
exit $bad
