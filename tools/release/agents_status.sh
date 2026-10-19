#!/bin/bash
# agents_status.sh : what every worktree's agent is doing, read from the
# worktree itself rather than from what the agent last said.
#
# On 2026-10-19 one agent said "I'll pick up from the regeneration's notice"
# and sat idle for three and a half hours with nothing running and nothing
# committed; another worked five hours with no commit at all. Neither showed
# in its messages. Per worktree: its branch, whether it is locked, minutes
# since its last commit on top of main, tracked files changed and not
# committed, and the processes working inside it. Flags:
#   STALE  no commit of its own for 60 minutes or more
#   IDLE   nothing running inside it, yet it is locked (an agent holds it)
set -u
R=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
now=$(date +%s)
printf '%-16s %-7s %9s %6s %6s  %s\n' worktree locked "commit" dirty procs flags
for d in "$R"/.claude/worktrees/*/; do
  d=${d%/}; w=$(basename "$d")
  git -C "$d" rev-parse HEAD >/dev/null 2>&1 || continue
  locked=no; [ -e "$(git -C "$d" rev-parse --git-dir)/locked" ] && locked=yes
  # The newest commit on this branch that main does not have: the agent's own.
  own=$(git -C "$d" log -1 --format=%ct main..HEAD 2>/dev/null)
  if [ -n "$own" ]; then age="$(( (now - own) / 60 ))m"; else age="none"; fi
  dirty=$(git -C "$d" status --porcelain --untracked-files=no | wc -l)
  procs=$(for p in /proc/[0-9]*; do c=$(readlink "$p/cwd" 2>/dev/null) || continue
    case "$c" in "$d"|"$d"/*) echo x;; esac; done | wc -l)
  flags=""
  if [ "$locked" = yes ]; then
    if [ -z "$own" ] || [ $(( (now - own) / 60 )) -ge 60 ]; then flags="$flags STALE"; fi
    [ "$procs" -eq 0 ] && flags="$flags IDLE"
  fi
  printf '%-16s %-7s %9s %6s %6s %s\n' "${w:0:16}" "$locked" "$age" "$dirty" "$procs" "$flags"
done
