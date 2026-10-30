#!/bin/bash
# install_showcase_timer.sh [CHECKOUT] : put the weekly AI showcase's timer
# (tools/systemd/brickworks-showcase.*) in ~/.config/systemd/user/, written
# for CHECKOUT (the main checkout unless said), and tell systemd. It is NOT
# enabled: the lead turns it on after looking at a first run by hand,
#   systemctl --user enable --now brickworks-showcase.timer
# and off again with disable --now. Run again after the units change.
set -eu
root=$(cd "${1:-$(dirname "$0")/..}" && pwd)
units="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
mkdir -p "$units"
# node and claude where this shell finds them, for a service's bare PATH.
path="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
for tool in node claude godot; do
  found=$(command -v "$tool" || true)
  [ -n "$found" ] && path="$(dirname "$found"):$path"
done
for unit in brickworks-showcase.service brickworks-showcase.timer; do
  sed -e "s|@ROOT@|$root|g" -e "s|@PATH@|$path|g" "$root/tools/systemd/$unit" > "$units/$unit"
  echo "installed $units/$unit"
done
if command -v systemctl >/dev/null; then
  systemctl --user daemon-reload
  echo "timer: $(systemctl --user is-enabled brickworks-showcase.timer 2>/dev/null || true) (left as it was; enable it by hand)"
fi
