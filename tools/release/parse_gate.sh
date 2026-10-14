#!/bin/bash
# parse_gate.sh WORKTREE [BASE] : every GDScript file the last merge changed,
# parsed by Godot. Two units each added a "dome" key to one dictionary; git
# merged both without a conflict, Godot could not parse assistant.gd, and the
# tool-list probe hung on it for 20 minutes instead of failing (2026-10-13).
cd "$1" || exit 1
BASE=${2:-HEAD^1}
FILES=$(git diff --name-only "$BASE" HEAD -- '*.gd' | while read -r f; do [ -f "$f" ] && echo "$f"; done)
[ -z "$FILES" ] && { echo "parse gate: no GDScript changed"; exit 0; }
OUT=$(XDG_DATA_HOME="$PWD/.scratch-data" ~/.claude/claude-core/bin/heavy bash -c '
  for f in '"$(echo $FILES)"'; do
    timeout 120 godot --headless --path . --check-only --script "$f" 2>&1 | grep -E "Parse Error|Compile Error" | sed "s|^|$f: |"
  done')
if [ -n "$OUT" ]; then echo "PARSE ERRORS:"; echo "$OUT"; exit 3; fi
echo "parse gate: $(echo $FILES | wc -w) GDScript files parse"
