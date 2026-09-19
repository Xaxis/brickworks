#!/usr/bin/env bash
# Run the app, save one frame, quit.
#   tools/shot.sh                  shots/latest.png
#   tools/shot.sh shots/wall.png
#
# Runs with a real window because the frame has to come off a real GPU;
# --headless renders nothing to capture.
set -uo pipefail
cd "$(dirname "$0")/.."
out="${1:-shots/latest.png}"
mkdir -p "$(dirname "$out")"
rm -f "$out"
godot --path . --resolution 1600x900 --position 0,0 -- "--shot=$PWD/$out" 2>&1 \
  | grep -viE '^$|Godot Engine|Vulkan|godotengine.org|CoreAudio|TextServer' | head -30
if [ -f "$out" ]; then
  echo "wrote $out ($(du -h "$out" | cut -f1))"
else
  echo "shot FAILED: no $out"; exit 1
fi
