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
# Checks that ran but left something out, which is neither a pass nor a
# failure and has to be said out loud either way.
skipped=0

run() {
  local label="$1"; shift
  local output status
  # Once, not twice. This used to run each probe a second time to read
  # its exit code, which doubled the slowest part of the suite to save
  # a variable.
  output=$("$@" 2>&1); status=$?
  # Godot exits 0 when a script fails to parse. So a probe with a typo
  # in it reported as passing, and did so for as long as it took
  # somebody to read the file — the stability probe had not run since
  # `_grams` was renamed, and the suite called it ok every time.
  if echo "$output" | grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script'; then
    status=1
  fi
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
# A machine with no pytest still runs the file. Ubuntu 24.04 ships no pip
# and no ensurepip, and apt wants a password, so "install pytest" is not
# something a check script can do on its own: tools/minitest.py runs the
# same file instead. Tests that need numpy skip by name.
if python3 -c 'import pytest' 2>/dev/null; then
  suite=(python3 -m pytest tests/ -q)
else
  suite=(python3 tools/minitest.py tests/test_ldraw.py)
fi
pyout=$("${suite[@]}" 2>&1); pystatus=$?
# The verdict is printed either way, because a check that silently skipped
# twenty-five measurements reads exactly like one that made them.
verdict=$(echo "$pyout" | grep -oE '[0-9]+ passed[^(]*' | tail -1 | sed 's/ *$//')
[ -n "$verdict" ] || verdict="no verdict line — read the output"
if [ "$pystatus" = 0 ]; then
  printf '  ok    pipeline — %s\n' "$verdict"
  if echo "$verdict" | grep -q skipped; then
    skipped=$((skipped + 1))
    echo "$pyout" | grep '^SKIP' | sed 's/^SKIP  //;s/ —.*//' | sort -u \
      | head -3 | sed 's/^/          skipped: /'
  fi
else
  printf '  FAIL  pipeline — %s\n' "$verdict"
  echo "$pyout" | grep -E 'FAIL|Error|error' | head -10 | sed 's/^/          /'
  fail=1
fi

echo "── godot probes ──"
for name in dimensions snap stability history restore store instructions search inventory mosaic world_view controls snot rules angled section scale edit scanner attach import select reader camera brain keeping glyph fetch busy dropped vocab reference search_quality moved holds mcp; do
  probe "$name"
done

# Needs a real window: the previews are drawn by a SubViewport, and a
# headless run has no rendering device to draw them with. It flashes a
# window open for a few seconds, which is why it is last.
echo "── on screen ──"
run "colour" godot --path . --resolution 1400x900 \
  --script src/dev/colour_probe.gd
# Same reason, and one more: the picture the assistant is shown only
# exists where there is something to draw with, so a headless suite
# would never once exercise the path the app actually takes.
run "model shot" godot --path . --resolution 1200x800 \
  --script src/dev/shot_probe.gd
run "axis gizmo" godot --path . --resolution 1200x800 \
  --script src/dev/gizmo_probe.gd
# Also a window: what a dragged box catches depends on where each brick
# lands on screen, which needs a camera with a viewport to project into.
run "box select" godot --path . --resolution 1200x800 \
  --script src/dev/marquee_probe.gd
# And the one that asks whether the controls feel right rather than
# whether they are wired: it drives the real scene with the gestures a
# person reaches for by habit. It found left-drag placing a brick,
# which every binding test had passed over because there was no
# binding to test.
run "feel" godot --path . --resolution 1400x900 \
  --script src/dev/feel_probe.gd

# Two processes and a socket between them, which is a different kind of
# failure from anything a single probe can have: the app's half can be
# perfect while the relay answers tools/list with an empty array, and a
# session then sees a server with no tools and nothing to explain it.
echo "── over MCP ──"
run "a session drives the app" python3 tools/mcp_check.py

if [ "$network" = 1 ]; then
  echo "── network ──"
  probe remote
  run "open (over the wire)" godot --path . --script src/dev/open_probe.gd
fi

echo ""
if [ "$fail" = 0 ]; then
  if [ "$skipped" = 0 ]; then
    echo "all checks pass  (${SECONDS}s)"
  else
    echo "checks pass, $skipped of them with tests skipped  (${SECONDS}s)"
  fi
else
  echo "something failed  (${SECONDS}s)"
fi
exit $fail
