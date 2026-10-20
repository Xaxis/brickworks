#!/usr/bin/env bash
# Run the app, save one frame, quit.
#   tools/shot.sh                  shots/latest.png
#   tools/shot.sh shots/wall.png
#
# Runs with a real window because the frame has to come off a real GPU;
# --headless renders nothing to capture.
set -uo pipefail
# Guarded: a cd that fails leaves the script running against
# whatever directory it was started from, which for a deploy means
# shipping something else entirely.
cd "$(dirname "$0")/.." || exit 1
# Never the person's own app data (app_userdata/Brickworks under the
# default XDG_DATA_HOME), as check.sh and doctor.sh (2026-10-20).
if [ -z "${XDG_DATA_HOME:-}" ] || [ "$XDG_DATA_HOME" = "$HOME/.local/share" ]; then
  XDG_DATA_HOME="$(mktemp -d "${TMPDIR:-/tmp}/brickworks-shot-data.XXXXXX")"
  export XDG_DATA_HOME
fi
out="${1:-shots/latest.png}"
shift || true
mkdir -p "$(dirname "$out")"
rm -f "$out"
godot --path . --resolution 1600x900 --position 0,0 -- "--shot=$PWD/$out" "$@" 2>&1 \
  | grep -viE '^$|Godot Engine|Vulkan|godotengine.org|CoreAudio|TextServer' | head -30
if [ -f "$out" ]; then
  echo "wrote $out ($(du -h "$out" | cut -f1))"
else
  echo "shot FAILED: no $out"; exit 1
fi
