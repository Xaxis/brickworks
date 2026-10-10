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
# Not run here: anything that spends money. Those are
# src/dev/{revise,sideways,stream,bakeoff}_probe.gd, run by hand when the
# thing they exercise has changed.
set -uo pipefail
# Guarded: a cd that fails leaves the script running against
# whatever directory it was started from, which for a deploy means
# shipping something else entirely.
cd "$(dirname "$0")/.." || exit 1

# In this machine's queue for heavy jobs, where it has one. Several
# projects share the box, and the windowed probes starve above a load of
# about twelve: run beside another project's encode, the suite measures
# the encode. `heavy` waits for a slot and runs at batch priority.
heavy="$HOME/.claude/claude-core/bin/heavy"
if [ -z "${BOX_HEAVY_HELD:-}" ] && [ -x "$heavy" ]; then
  exec "$heavy" "$PWD/tools/check.sh" "$@"
fi

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
# And checks that never finished. A run with one of these in it has not
# proven what it set out to, whatever the rest of it says.
unproven=0

run() {
  local label="$1"; shift
  local output status
  # Once, not twice. This used to run each probe a second time to read
  # its exit code, which doubled the slowest part of the suite to save
  # a variable.
  # Bounded, because a probe that hangs stops the whole run rather than
  # failing it. One did: it forced a draw from inside a frame, deadlocked
  # on a busy machine, and the suite sat at "on screen" until somebody
  # noticed. The windowed probes also starve on a machine shared with
  # other projects' suites — above about load twelve they wait for frames
  # that never come — and that is not a pass either.
  output=$(timeout "${PROBE_SECONDS:-420}" "$@" 2>&1); status=$?
  # Godot exits 0 when a script fails to parse. So a probe with a typo
  # in it reported as passing, and did so for as long as it took
  # somebody to read the file — the stability probe had not run since
  # `_grams` was renamed, and the suite called it ok every time.
  if echo "$output" | grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script'; then
    status=1
  fi
  if [ "$status" = 124 ]; then
    # Not a pass and not a failure: nothing was proven either way, and
    # saying "ok" or "FAIL" would both be claims nobody can stand up.
    printf '  ----  %s TIMED OUT after %ss\n' "$label" "${PROBE_SECONDS:-420}"
    printf '          nothing was proven. Check the load: these starve above about 12\n'
    unproven=$((unproven + 1))
  elif [ "$status" = 0 ]; then
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
  suite=(python3 tools/minitest.py tests/test_ldraw.py tests/test_style.py \
    tests/test_minifig.py)
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
for name in dimensions snap stability history restore store instructions search inventory mosaic world_view controls snot technic clutch variety repeat usage kinds rules angled section scale edit scanner attach import select reader camera brain keeping glyph fetch busy dropped vocab reference search_quality moved availability holds mcp claude_code techniques patterns style turned detail chat minifig; do
  probe "$name"
done

# Needs a real window: the previews are drawn by a SubViewport, and a
# headless run has no rendering device to draw them with. It flashes a
# window open for a few seconds, which is why it is last.
echo "── on screen ──"

# A window even when nobody is logged in.
#
# These seven need a rendering device. The desktop session is the obvious
# one and it is not always there: a run from a detached shell, or after
# the screen locks, or on a machine nobody is sitting at, finds no
# display and seven checks fail for a reason that has nothing to do with
# the code — "X11 Display is not available", which reads like a broken
# probe. Xvfb gives them one, and the pictures come out the same: a
# frame costs 124 ms there against 989 ms on the compositor, so it is
# faster as well.
#
# Xvfb cannot hand the GPU driver a buffer to present (it has no DRI3), so
# Godot quietly fell back to lavapipe there and drew on the CPU.
# MESA_VK_WSI_DEBUG=sw has Mesa copy each frame to Xvfb itself, and the
# real GPU draws: a 10-frame scene took 0.33 s of CPU against 8.6 s.
screen=()
if ! timeout 5 xdpyinfo >/dev/null 2>&1; then
  if command -v xvfb-run >/dev/null 2>&1; then
    screen=(env MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1400x900x24")
    echo "        no display, so these run on Xvfb"
  else
    echo "        no display and no xvfb-run — these will fail"
  fi
fi

run "colour" "${screen[@]}" godot --path . --resolution 1400x900 \
  --script src/dev/colour_probe.gd
# Whether a colour on screen is the colour it is (black was navy, and on
# the web every grey was white), and whether chrome, glitter, rubber and
# the other finishes are each drawn as themselves. Both ask the pixels;
# both leave pictures in shots/ worth a look. The plain `godot` here is
# the Compatibility renderer, which is the web build's.
run "true colour" "${screen[@]}" godot --path . --resolution 1400x900 \
  --script src/dev/true_colour_probe.gd
run "finishes" "${screen[@]}" godot --path . --resolution 1400x900 \
  --script src/dev/finish_probe.gd
# Same reason, and one more: the picture the assistant is shown only
# exists where there is something to draw with, so a headless suite
# would never once exercise the path the app actually takes.
run "model shot" "${screen[@]}" godot --path . --resolution 1200x800 \
  --script src/dev/shot_probe.gd
run "axis gizmo" "${screen[@]}" godot --path . --resolution 1200x800 \
  --script src/dev/gizmo_probe.gd
# Also a window: what a dragged box catches depends on where each brick
# lands on screen, which needs a camera with a viewport to project into.
run "box select" "${screen[@]}" godot --path . --resolution 1200x800 \
  --script src/dev/marquee_probe.gd
# And the one that asks whether the controls feel right rather than
# whether they are wired: it drives the real scene with the gestures a
# person reaches for by habit. It found left-drag placing a brick,
# which every binding test had passed over because there was no
# binding to test.
run "feel" "${screen[@]}" godot --path . --resolution 1400x900 \
  --script src/dev/feel_probe.gd
# The minifigure builder, used by clicking: slots, parts, colours, a
# name, Place in model, a click on a stud. Its live figure and its
# thumbnails are drawn, so it needs a window; it leaves pictures of the
# builder and of a row of figures in shots/minifig_*.png.
run "minifig builder" "${screen[@]}" godot --path . --resolution 1400x900 \
  --script src/dev/minifig_ui_probe.gd

# Two processes and a socket between them, which is a different kind of
# failure from anything a single probe can have: the app's half can be
# perfect while the relay answers tools/list with an empty array, and a
# session then sees a server with no tools and nothing to explain it.
echo "── over MCP ──"
run "a session drives the app" python3 tools/mcp_check.py

if [ "$network" = 1 ]; then
  echo "── network ──"
  probe remote
  probe reference_lookup
  run "open (over the wire)" godot --path . --script src/dev/open_probe.gd
fi

echo ""
if [ "$unproven" != 0 ]; then
  # Said first and counted as a failure of the run, because "everything
  # else passed" about a run that could not finish is how a hang gets
  # read as a pass.
  echo "$unproven check(s) NEVER FINISHED — nothing is proven about them  (${SECONDS}s)"
  echo "  if the machine is busy, run them again when it is not:"
  echo "    uptime; tools/check.sh"
  exit 1
fi
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
