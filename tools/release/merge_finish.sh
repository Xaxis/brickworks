#!/bin/bash
# merge_finish.sh WORKTREE "MESSAGE" : finish a merge that merge_unit.sh stopped
# on with CONFLICTS, once they are resolved and added by hand: the same feature
# map, commit, import and tool-list steps.
set -u
# Before the cd below: $0 may be relative to where it was called from.
HERE=$(cd "$(dirname "$0")" && pwd)
MSG=$2
# Absolute, since the parse gate is handed it after the cd.
W=$(cd "$1" && pwd) || exit 1
cd "$W"
# Held until the last gate is done: ship.sh refuses a worktree whose merge
# is still checking, as m26 was shipped while its tool list was (2026-10-14).
LOCK="$(git rev-parse --git-dir)/merging"; touch "$LOCK"; trap 'rm -f "$LOCK"' EXIT
ID=(-c user.name=Xaxis -c user.email=william.neeley@gmail.com)
if git diff --name-only --diff-filter=U | grep -q .; then echo "STILL CONFLICTED:"; git diff --name-only --diff-filter=U; exit 2; fi
~/.claude/claude-core/bin/featuremap generate --write >/dev/null 2>&1
git add .claude/skills/verify/features.json 2>/dev/null
git "${ID[@]}" commit -q -m "$MSG" || exit 1
git log --oneline -1
~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 900 godot --headless --path . --import >/dev/null 2>&1
echo "imported"
"$HERE/parse_gate.sh" "$W" || exit 3
if ! git diff --quiet HEAD^1 HEAD -- src/net src/ai tools/mcp_tools.json 2>/dev/null; then
  ~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 1200 godot --headless --path . --script src/dev/mcp_sync_probe.gd -- --write 2>&1 | grep -E "^  (ok|FAIL)|in step"
  if ! git diff --quiet -- tools/mcp_tools.json; then
    git add tools/mcp_tools.json
    git "${ID[@]}" commit -q -m "The tool list as the merged app serves it" && git log --oneline -1
  fi
fi
~/.claude/claude-core/bin/featuremap check 2>&1 | tail -3
