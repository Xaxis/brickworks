#!/bin/bash
# ci_gate.sh WORKTREE : what CI's check.yml ran on every push, run here before
# main moves. One version in VERSION, project.godot and CHANGELOG.md; the
# Python suite; and tools/*.sh and tools/release/*.sh linted by shellcheck,
# where this machine has it. CI ran them on GitHub and was red from
# 2026-10-13 to 10-26, a lint warning and then a test that needed a file CI
# lacked, and nobody read it.
# A check that only reports is not read; one that holds the release is.
cd "$1" || exit 1
# In a heavy slot, as the other gates; the timeout counts the run, not the queue.
if [ -z "${BOX_HEAVY_HELD:-}" ]; then
  exec ~/.claude/claude-core/bin/heavy timeout 600 "$0" "$PWD"
fi
fail=0
python3 tools/release.py version || fail=1
# The suite as tools/check.sh runs it: pytest where it is installed, else
# tools/minitest.py on the same files (no pip on this machine).
if python3 -c 'import pytest' 2>/dev/null; then
  suite=(python3 -m pytest tests/ -q)
else
  suite=(python3 tools/minitest.py tests/test_*.py)
fi
pyout=$("${suite[@]}" 2>&1); pystatus=$?
verdict=$(echo "$pyout" | grep -oE '[0-9]+ passed[^(]*' | tail -1 | sed 's/ *$//')
if [ "$pystatus" = 0 ]; then
  echo "ci gate: python ok, ${verdict:-no verdict line}"
else
  echo "ci gate: python FAILED, ${verdict:-no verdict line}"
  echo "$pyout" | grep -E 'FAIL|Error|error' | head -10 | sed 's/^/  /'
  fail=1
fi
# -S warning: style opinions on a deploy script are noise, a quoting bug in
# one is a broken release. A machine without shellcheck says so and goes on.
if command -v shellcheck >/dev/null; then
  if shellcheck -S warning tools/*.sh tools/release/*.sh; then
    echo "ci gate: shellcheck ok, $(ls tools/*.sh tools/release/*.sh | wc -l) scripts"
  else
    echo "ci gate: shellcheck FAILED"; fail=1
  fi
else
  echo "ci gate: no shellcheck here, tools/*.sh and tools/release/*.sh not linted (koalaman/shellcheck v0.10.0 into ~/.local/bin)"
fi
# The viewer's two bundles are committed builds (the deploy builds nothing),
# so a change to tools/viewer/ or a merge of two can leave them stale, with
# nothing else to notice. Its pinned three.js and esbuild are kept apart from
# the checkout, as downloaded code is, and fetched once.
deps=${VIEWER_DEPS:-$HOME/.cache/brickworks/viewerdeps}
if [ ! -d "$deps/node_modules/three" ] || [ ! -d "$deps/node_modules/esbuild" ]; then
  mkdir -p "$deps" && npm install --prefix "$deps" --ignore-scripts --save-exact three@0.186.1 esbuild@0.28.2 >/dev/null 2>&1
fi
if viewer=$(node tools/viewer/build.mjs --deps="$deps" --check 2>&1); then
  echo "ci gate: viewer bundles ok"
else
  echo "ci gate: viewer bundles FAILED"; echo "$viewer" | tail -5 | sed 's/^/  /'; fail=1
fi
echo "ci gate: $SECONDS s in its slot"
exit $fail
