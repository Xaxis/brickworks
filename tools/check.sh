#!/usr/bin/env bash
# Everything that can be checked without a person looking at it.
#
#   tools/check.sh              the offline suite
#   tools/check.sh --network    also the checks that need the internet
#
# Three layers, because they fail in different ways.
#
# The Python suite covers the offline pipeline: parsing LDraw, winding,
# connectivity, occupancy, the design validator. The Godot probes cover
# what only exists at run time — search ranking, whether a model
# survives a save, whether the step order can actually be followed,
# whether a part is the size it claims. And a parse check, which catches
# the class of mistake that makes every other check fail at once.
#
# Not run here: anything that spends money or needs an account. Those
# are src/dev/{account,revise,assistant}_probe.gd, run by hand when the
# thing they exercise has changed.
set -uo pipefail
# Guarded: a cd that fails leaves the script running against
# whatever directory it was started from, which for a deploy means
# shipping something else entirely.
cd "$(dirname "$0")/.." || exit 1

network=0
for argument in "$@"; do
  case "$argument" in
    --network) network=1 ;;
    *) echo "check: unknown option $argument"; exit 2 ;;
  esac
done

fail=0

run() {
  local label="$1"; shift
  local output status
  # Once, not twice. This used to run each probe a second time to read
  # its exit code, which doubled the slowest part of the suite to save
  # a variable.
  output=$("$@" 2>&1); status=$?
  if [ "$status" = 0 ]; then
    printf '  ok    %s\n' "$label"
  else
    printf '  FAIL  %s\n' "$label"
    echo "$output" | grep -E 'FAIL|Error|error' | head -8 | sed 's/^/          /'
    fail=1
  fi
}

probe() {
  run "$1" godot --headless --path . --script "src/dev/$1_probe.gd"
}

echo "── the project parses ──"
# A parse error takes every probe down with it, and the message from a
# probe that could not load says nothing about which file is wrong.
parse=$(godot --headless --path . --quit 2>&1)
if echo "$parse" | grep -qE 'SCRIPT ERROR|Parse Error'; then
  echo "$parse" | grep -E 'SCRIPT ERROR|Parse Error|at:' | head -10 | sed 's/^/  /'
  echo "  FAIL  the project does not parse — nothing below would mean anything"
  exit 1
fi
echo "  ok    no script errors"

echo "── python ──"
run "pipeline (pytest)" python3 -m pytest tests/ -q

echo "── godot probes ──"
for name in dimensions stability store instructions search inventory mosaic world_view controls; do
  probe "$name"
done

# Needs a real window: the previews are drawn by a SubViewport, and a
# headless run has no rendering device to draw them with. It flashes a
# window open for a few seconds, which is why it is last.
echo "── on screen ──"
run "colour" godot --path . --resolution 1400x900 \
  --script src/dev/colour_probe.gd

if [ "$network" = 1 ]; then
  echo "── network ──"
  probe remote
  run "open (over the wire)" godot --path . --script src/dev/open_probe.gd
fi

echo ""
if [ "$fail" = 0 ]; then
  echo "all checks pass  (${SECONDS}s)"
else
  echo "something failed  (${SECONDS}s)"
fi
exit $fail
