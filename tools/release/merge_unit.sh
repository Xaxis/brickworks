#!/bin/bash
# merge_unit.sh WORKTREE REF "MESSAGE"
# Merge an agent's unit into a staging worktree as the user. The feature map
# is regenerated into the merge commit, and Godot re-imports so new
# class_names resolve; forgetting that broke probes after merges twice.
set -u
# Before the cd below: $0 may be relative to where it was called from.
HERE=$(cd "$(dirname "$0")" && pwd)
REF=$2; MSG=$3
# Absolute, since the parse gate is handed it after the cd.
W=$(cd "$1" && pwd) || exit 1
cd "$W"
# Held until the last gate is done: ship.sh refuses a worktree whose merge
# is still checking, as m26 was shipped while its tool list was (2026-10-14).
LOCK="$(git rev-parse --git-dir)/merging"; touch "$LOCK"; trap 'rm -f "$LOCK"' EXIT
ID=(-c user.name=Xaxis -c user.email=william.neeley@gmail.com)
# Untracked files Godot's import made (.uid) that the branch also carries,
# byte for byte, would stop the merge: take them out first.
for f in $(git diff --name-only HEAD...$REF -- '*.uid' 2>/dev/null); do
  if [ -f "$f" ] && ! git ls-files --error-unmatch "$f" >/dev/null 2>&1       && cmp -s <(git show "$REF:$f" 2>/dev/null) "$f"; then rm "$f"; fi
done
merged=0; git "${ID[@]}" merge --no-ff --no-commit "$REF" >/dev/null 2>&1 && merged=1
# A unit begun before a version was cut: its changelog entries go under
# [Unreleased], not the dated section git merges them into, with or
# without a conflict. Before the docs union below, which would keep both.
python3 "$HERE/changelog_merge.py" "$REF"
if [ $merged = 0 ]; then
  # The cached tool list is generated: take either side, write it again below.
  if git diff --name-only --diff-filter=U | grep -qx tools/mcp_tools.json; then
    git checkout --ours tools/mcp_tools.json && git add tools/mcp_tools.json
  fi
  # Docs and the generated feature map: the same union every time.
  for f in $(git diff --name-only --diff-filter=U | grep -E '\.md$'); do
    out=$(python3 "$HERE/resolve_docs.py" "$f") && { echo "$out" | grep DOUBLED; git add "$f"; }
  done
  if git diff --name-only --diff-filter=U | grep -qx .claude/skills/verify/features.json; then
    git checkout --theirs .claude/skills/verify/features.json && git add .claude/skills/verify/features.json
  fi
  if git diff --name-only --diff-filter=U | grep -q .; then
    echo "CONFLICTS:"; git diff --name-only --diff-filter=U; exit 2
  fi
fi
~/.claude/claude-core/bin/featuremap generate --write >/dev/null 2>&1
git add .claude/skills/verify/features.json 2>/dev/null
git "${ID[@]}" commit -q -m "$MSG" || exit 1
git log --oneline -1
# Imported in every mode: a probe run on the staged worktree before it
# ships finds no class_names without it (rel-m79's grab_probe, "Could not
# find type BrickWorld", the third time a missed import cost a run).
~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 900 godot --headless --path . --import >/dev/null 2>&1
echo "imported"
# A probe the merge brings in that no suite list names fails the merge here,
# not hours later in a full suite (drag_cost and seated, then step_link).
if grep -q -- '--lists' tools/check.sh 2>/dev/null && ! tools/check.sh --lists >/dev/null 2>&1; then
  tools/check.sh --lists 2>&1 | tail -2; echo "merge_unit: name it in tools/check.sh"; exit 4
fi
# MERGE_GATES=ship: the parse gate and the tool list are left to ship.sh,
# which runs them once for every unit merged, under the release's priority.
if [ "${MERGE_GATES:-}" = ship ]; then
  ~/.claude/claude-core/bin/featuremap check 2>&1 | tail -1
  exit 0
fi
"$HERE/parse_gate.sh" "$W" || exit 3
if ! git diff --quiet HEAD^1 HEAD -- src/net src/ai tools/mcp_tools.json 2>/dev/null; then
  ~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 1200 godot --headless --path . --script src/dev/mcp_sync_probe.gd -- --write 2>&1 | grep -E "^  (ok|FAIL)|in step" 
  if ! git diff --quiet -- tools/mcp_tools.json; then
    git add tools/mcp_tools.json
    git "${ID[@]}" commit -q -m "The tool list as the merged app serves it" && git log --oneline -1
  fi
fi
~/.claude/claude-core/bin/featuremap check 2>&1 | tail -3
