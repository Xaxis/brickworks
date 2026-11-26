#!/usr/bin/env bash
# Prints the address every release commit is authored by: Vercel seat-checks the
# author and refuses any other, silently. It is never written into the repo (a
# privacy guard refuses to run scripts that hold it). It comes from the owner:
# BW_COMMIT_EMAIL in their shell, or the file below, written by them once:
#   mkdir -p ~/.config/brickworks && echo ADDRESS > ~/.config/brickworks/commit_email
# A file reaches shells already running (agents, trains) without a restart.
f=${XDG_CONFIG_HOME:-$HOME/.config}/brickworks/commit_email
a=${BW_COMMIT_EMAIL:-}
[ -n "$a" ] || { [ -r "$f" ] && a=$(tr -d '[:space:]' < "$f"); }
case $a in
  ?*@?*.?*) printf '%s\n' "$a" ;;
  *) echo "no commit author: set BW_COMMIT_EMAIL, or write the address to $f" >&2; exit 1 ;;
esac
