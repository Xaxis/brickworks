#!/bin/bash
# retire_wt.sh NAME... : remove a finished unit's worktree, keeping what it made.
#
# For a unit merged into a release, whose branch is not on main yet, so
# clean_worktrees.sh leaves it. Its git-ignored bench/results/* and shots/
# are copied into the main checkout's bench/results first (into a folder of
# the same name; nothing there is overwritten); a worktree with anything
# tracked changed, or a process working in it, is kept; then it is unlocked
# and removed. The branch stays.
#
# kit02's raw before and after pictures went with its worktree when the
# check and the removal ran in one command (2026-10-22), as four bench rounds
# had once before.
set -u
R=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
bad=0
for w in "$@"; do
  d="$R/.claude/worktrees/$w"
  [ -d "$d" ] || { echo "retire: no worktree $w"; bad=1; continue; }
  if [ -n "$(git -C "$d" status --porcelain --untracked-files=no)" ]; then
    echo "kept $w: tracked files changed"; bad=1; continue
  fi
  busy=""
  for p in /proc/[0-9]*; do
    c=$(readlink "$p/cwd" 2>/dev/null) || continue
    case "$c" in "$d"|"$d"/*) busy="$busy ${p#/proc/}" ;; esac
  done
  [ -n "$busy" ] && { echo "kept $w: processes$busy work in it"; bad=1; continue; }
  kept=1
  for src in "$d"/bench/results/* "$d"/shots; do
    [ -e "$src" ] && [ ! -L "$src" ] || continue
    name=$(basename "$src")
    dest="$R/bench/results/$name"
    [ "$name" = shots ] && dest="$R/bench/results/shots-$(date +%F)/$w"
    if [ -d "$src" ]; then
      mkdir -p "$dest" && cp -a --update=none "$src"/. "$dest"/ || kept=0
    else
      cp -a --update=none "$src" "$R/bench/results/" || kept=0
    fi
    [ $kept = 1 ] && echo "$w: $name kept in ${dest#"$R"/}"
  done
  [ $kept = 1 ] || { echo "kept $w: what it made could not all be copied"; bad=1; continue; }
  git -C "$R" worktree unlock "$d" 2>/dev/null
  git -C "$R" worktree remove --force "$d" && echo "removed $w" || bad=1
done
exit $bad
