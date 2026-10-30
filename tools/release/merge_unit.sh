#!/bin/bash
# merge_unit.sh WORKTREE REF "MESSAGE"
# Merge an agent's unit into a staging worktree as the user. The feature map
# is regenerated into the merge commit, and Godot re-imports so new
# class_names resolve; forgetting that broke probes after merges twice.
#
# Several units at once: MERGE_ONLY=1 for each but the last, which runs the
# gates once for all of them given MERGE_BASE=<the commit before the first>.
# Each merge's import and gates waited 15 minutes for heavy, so three units
# took most of an hour (2026-10-30).
set -u
# Before the cd below: $0 may be relative to where it was called from.
HERE=$(cd "$(dirname "$0")" && pwd)
REF=$2; MSG=$3
# Absolute, since the parse gate is handed it after the cd.
W=$(cd "$1" && pwd) || exit 1
cd "$W" || exit 1
# Held until the last gate is done: ship.sh refuses a worktree whose merge
# is still checking, as m26 was shipped while its tool list was (2026-10-14).
LOCK="$(git rev-parse --git-dir)/merging"; touch "$LOCK"; trap 'rm -f "$LOCK"' EXIT
ID=(-c user.name=Xaxis -c user.email=william.neeley@gmail.com)
# Untracked files Godot's import made (.uid) that the branch also carries
# would stop the merge: take them out first. The branch's committed one
# wins even when it differs: the import here made its own for a script the
# release already had untracked, and git refused lib219 silently (m164,
# 2026-10-24). The import below writes any that are missing.
for f in $(git diff --name-only HEAD...$REF -- '*.uid' 2>/dev/null); do
  if [ -f "$f" ] && ! git ls-files --error-unmatch "$f" >/dev/null 2>&1; then rm "$f"; fi
done
merged=0; out=$(git "${ID[@]}" merge --no-ff --no-commit "$REF" 2>&1) && merged=1
# A merge that would not start (an untracked file in the way) leaves no
# conflicts to resolve: say why rather than commit nothing.
if [ $merged = 0 ] && ! git rev-parse -q --verify MERGE_HEAD >/dev/null; then
  echo "MERGE: did not start"; echo "$out" | tail -5; exit 3
fi
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
[ "${MERGE_ONLY:-}" = 1 ] && exit 0
BASE=${MERGE_BASE:-HEAD^1}
# Imported in every mode: a probe run on the staged worktree before it
# ships finds no class_names without it (rel-m79's grab_probe, "Could not
# find type BrickWorld", the third time a missed import cost a run).
mkdir -p .scratch-data
~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 900 godot --headless --path . --import > .scratch-data/import.log 2>&1
# An import ended early (its timeout, or a pass that leaves some out) still
# writes the class list, and a probe needing a font or a picture fails far
# from the cause: rel-m222's booklet_pdf, its font "cannot be read" after
# its train's import ran out its 900 s (2026-10-30). fresh_import imports
# again what is unmade, or says what is and stops here.
tools/fresh_import.sh || { echo "$(basename "$0"): $PWD is not imported whole; its import said:"; tail -5 .scratch-data/import.log | sed 's/^/  /'; exit 1; }
echo "imported"
# A unit that did not commit the .uid its import made beside a new script
# or shader brings the script alone; this import made one, and it goes in
# the merge (tests/test_script_uids.py fails a release without it).
uids=$(git ls-files --others --exclude-standard -- '*.gd.uid' '*.gdshader.uid' '*.gdshaderinc.uid')
if [ -n "$uids" ]; then
  echo "$uids" | xargs -d '\n' git add -- && git "${ID[@]}" commit -q --amend --no-edit \
    && echo "with the .uid of $(echo "$uids" | wc -l) new scripts: $(git log --oneline -1)"
fi
# A probe the merge brings in that no suite list names fails the merge here,
# not hours later in a full suite (drag_cost and seated, then step_link).
if grep -q -- '--lists' tools/check.sh 2>/dev/null && ! tools/check.sh --lists >/dev/null 2>&1; then
  tools/check.sh --lists 2>&1 | tail -2; echo "merge_unit: name it once in tools/suite (headless.txt, windowed.txt or out.txt)"; exit 4
fi
# MERGE_GATES=ship: the parse gate and the tool list are left to ship.sh,
# which runs them once for every unit merged, under the release's priority.
if [ "${MERGE_GATES:-}" = ship ]; then
  ~/.claude/claude-core/bin/featuremap check 2>&1 | tail -1
  exit 0
fi
"$HERE/parse_gate.sh" "$W" "$BASE" || exit 3
if ! git diff --quiet "$BASE" HEAD -- src/net src/ai tools/mcp_tools.json 2>/dev/null; then
  ~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 1200 godot --headless --path . --script src/dev/mcp_sync_probe.gd -- --write 2>&1 | grep -E "^  (ok|FAIL)|in step" 
  if ! git diff --quiet -- tools/mcp_tools.json; then
    git add tools/mcp_tools.json
    git "${ID[@]}" commit -q -m "The tool list as the merged app serves it" && git log --oneline -1
  fi
fi
~/.claude/claude-core/bin/featuremap check 2>&1 | tail -3
