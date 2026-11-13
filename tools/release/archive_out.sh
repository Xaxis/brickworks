#!/bin/bash
# Moves release-out's old output to the archive, never deleting it.
#   archive_out.sh [--dry]
# It moves the releases (rel-mNNN*) older than the newest $RELEASE_KEEP (8)
# and any other entry, a unit's preview say, that nothing has touched for
# $RELEASE_IDLE_DAYS (3) days. They go to $RELEASE_ARCHIVE
# (~/brickworks-archive/release-out, on the root disk), and release-out/archive
# links there, so release-out/X can still be read as release-out/archive/X.
# A train still running, a hold and the archive itself are never moved.
#
# Why: release-out had grown to 61 GB in 25,000 entries, with /mnt/Projects at
# 93% (2026-11-11). train.sh runs this once a release is live. The last five
# _prod.log files (ship_minutes) and the live release's _lead.out (status)
# are always among the releases kept.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
R=$(dirname "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)")
RO=$(realpath -m "${RELEASE_OUT:-$R/bench/results/release-out}")
AR=${RELEASE_ARCHIVE:-$HOME/brickworks-archive/release-out}
KEEP=${RELEASE_KEEP:-8}
IDLE=$(( ${RELEASE_IDLE_DAYS:-3} * 1440 ))
dry=0; [ "${1:-}" = --dry ] && dry=1
[ -d "$RO" ] || { echo "archive_out: no $RO"; exit 0; }
cd "$RO" || exit 1

# A train still running, by the pid it wrote (as train.sh's runner reads it).
running() {
  local pid
  pid=$(cat "$RO/$1.train/pid" 2>/dev/null) || return 1
  case "$(tr '\0' ' ' 2>/dev/null < "/proc/$pid/cmdline")" in *"train.sh run $1 "*) return 0 ;; esac
  return 1
}

nums=$(ls -1 | sed -nE 's/^rel-m([0-9]+).*/\1/p' | sort -un)
cut=$(tail -n "$KEEP" <<< "$nums" | head -1)
moved=0 kept=0
move() {
  local e=$1 to="$AR/$1"
  [ -e "$to" ] && to="$AR/$1.moved-$(date -u +%Y%m%dT%H%M%S)"
  if [ "$dry" = 1 ]; then echo "would move $e"; moved=$((moved+1)); return; fi
  mkdir -p "$AR"
  ionice -c3 nice -n 19 mv -T -- "$e" "$to" && moved=$((moved+1))
}
for e in *; do
  [ -e "$e" ] || [ -L "$e" ] || continue
  case "$e" in archive|README.archive|HOLD|*.hold) continue ;; esac
  if [[ $e =~ ^(rel-m([0-9]+)) ]]; then
    n=${BASH_REMATCH[2]}
    { [ -z "$cut" ] || [ "$n" -ge "$cut" ]; } && continue
    running "${BASH_REMATCH[1]}" && { kept=$((kept+1)); continue; }
    move "$e"
  else
    [ -n "$(find "$e" -mmin "-$IDLE" -print -quit 2>/dev/null)" ] && continue
    move "$e"
  fi
done
if [ "$dry" = 0 ] && [ -d "$AR" ]; then
  ln -sfn "$AR" "$RO/archive"
  [ -e "$RO/README.archive" ] || printf 'Older release and unit-preview output is moved (never deleted) by tools/release/archive_out.sh to\n%s\nrelease-out/archive links there: release-out/X is then release-out/archive/X.\n' "$AR" > "$RO/README.archive"
fi
k=""; [ "$kept" -gt 0 ] && k="; $kept of a running train kept"
echo "archive_out: moved $moved entries to $AR (releases before rel-m${cut:-?} and others idle ${RELEASE_IDLE_DAYS:-3} days)$k"
