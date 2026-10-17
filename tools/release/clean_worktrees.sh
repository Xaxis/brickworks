#!/bin/bash
# clean_worktrees.sh [--dry-run] : remove the worktrees whose work is done.
#
# A worktree goes only when all of these hold:
#   - it is not locked: the agent harness locks a worktree while its agent
#     runs, and a lock is never lifted here;
#   - no process has its working directory inside it;
#   - nothing tracked is changed in it (an agent mid-unit has edits);
#   - its branch's commit is on main.
# A branch at a commit already on main is also what a running agent's looks
# like before its first commit, which is how two live agents lost their work
# to a cleanup that checked only the last condition (2026-10-16).
#
# Before removing, its shots/ are copied to bench/results/shots-<date>/<name>
# in the main checkout, and nothing else ignored is touched.
set -u
DRY=${1:-}
R=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
cd "$R" || exit 1
SHOTS="$R/bench/results/shots-$(date +%F)"
for d in "$R"/.claude/worktrees/*/; do
  d=${d%/}; w=$(basename "$d")
  git -C "$d" rev-parse HEAD >/dev/null 2>&1 || continue
  if [ -e "$(git -C "$d" rev-parse --git-dir)/locked" ]; then
    echo "kept $w: locked (an agent is running in it)"; continue
  fi
  busy=$(for p in /proc/[0-9]*; do c=$(readlink "$p/cwd" 2>/dev/null) || continue
    case "$c" in "$d"|"$d"/*) echo "${p#/proc/}";; esac; done | head -3 | tr '\n' ' ')
  if [ -n "$busy" ]; then echo "kept $w: processes inside it ($busy)"; continue; fi
  if [ -n "$(git -C "$d" status --porcelain --untracked-files=no)" ]; then
    echo "kept $w: tracked changes not committed"; continue
  fi
  h=$(git -C "$d" rev-parse HEAD)
  if ! git merge-base --is-ancestor "$h" main; then
    echo "kept $w: its work is not on main"; continue
  fi
  b=$(git -C "$d" rev-parse --abbrev-ref HEAD)
  if [ "$DRY" = --dry-run ]; then echo "would remove $w ($b)"; continue; fi
  [ -d "$d/shots" ] && mkdir -p "$SHOTS" && cp -r "$d/shots" "$SHOTS/$w"
  git worktree remove --force "$d" && echo "removed $w"
  [ "$b" != HEAD ] && git branch -d "$b" >/dev/null 2>&1
done
