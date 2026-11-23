#!/bin/bash
# tree.sh SCENES PNG_DIR EXR_DIR DRAW [render.py options...] : every photoreal shot whose scene
# our tracer wrote into SCENES (tools/probe.sh photoreal -- --cycles) drawn by Cycles with seed
# DRAW (render.py), then given our camera's finish (finish.py) into PNG_DIR/<name>.png, its
# light kept in EXR_DIR. A shot whose EXR is there already is only finished again.
#   FINISH="--jpeg 90 ..."  options for finish.py      ONLY="a b"  only these shots
#   THREADS=8               Blender's threads           BLENDER=... its folder
# Run it inside a heavy slot: `~/.claude/claude-core/bin/heavy tools/photoreal/cycles/tree.sh ...`.
# Blender and ldr_tools_blender are tools on this box (docs/RENDERING.md 5j), never the app's.
set -u
here=$(cd "$(dirname "$0")" && pwd)
B=${BLENDER:-$HOME/.local/opt/blender-5.2.4-linux-x64}
scenes=${1:?usage: tree.sh SCENES PNG_DIR EXR_DIR DRAW [options]} png=${2:?} exr=${3:?} draw=${4:?}
shift 4
[ -x "$B/blender" ] || { echo "tree.sh: no Blender at $B (docs/RENDERING.md 5j)" >&2; exit 2; }
mkdir -p "$png" "$exr"
names=${ONLY:-black_2x4 red_slope_2x4 grey_1x3 trans_round_1x1 three_2x2_top green_plate_macro set_6512 set_6532 set_6657 set_6660}
echo "== draw $draw from $scenes, ${*:-defaults}, $(date -u +%H:%M:%SZ)"
failed=0
for n in $names; do
  [ -e "$scenes/$n.cycles.json" ] || { echo "  $n: no scene"; failed=1; continue; }
  if [ ! -e "$exr/$n.exr" ]; then
    timeout 5400 "$B/blender" -b --factory-startup -t "${THREADS:-8}" --python "$here/render.py" -- \
      "$scenes/$n.cycles.json" "$exr" --draw "$draw" "$@" > "$exr/$n.blender.log" 2>&1 </dev/null
    grep -E '^rendered|Traceback|Error|^parts:' "$exr/$n.blender.log" | cut -c1-300 | head -6
  fi
  # shellcheck disable=SC2086
  timeout 600 "$B/5.2/python/bin/python3.13" "$here/finish.py" "$exr/$n.exr" "$scenes/$n.cycles.json" \
    "$png/$n.png" --draw "$draw" ${FINISH:-} </dev/null 2>&1 | tail -1 | cut -c1-200
  [ -s "$png/$n.png" ] || failed=1
done
echo "== done $(date -u +%H:%M:%SZ)"
exit $failed
