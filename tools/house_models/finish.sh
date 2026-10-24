#!/bin/bash
# A design made buildable as its steps say: flattened, its steps put right, and
# what the Tested mark still finds.
#
#   tools/house_models/finish.sh IN.ldr OUT.ldr "TITLE" [--steps]
#
# flatten.py (printed parts back as real ones; --steps keeps the design's own
# step order, which made finer steps than the worked-out one for the tractor
# and the fox), then fixsteps.gd. OUT.flat is kept beside OUT: fix colours
# (colours.py --check) or drop hidden parts (drop.py) in it, then run
# fixsteps.gd on it again. Q=heavy|gpu picks the queue (gpu by default: a
# minute's headless run, and heavy waits whenever the box is past its load
# gate). XDG_DATA_HOME defaults to OUT's folder.
#
# Used by seed211 (2026-10-24) on each of the twelve house models.
set -u
in=$1; out=$2; title=$3; shift 3
here=$(cd "$(dirname "$0")" && pwd); root=$(cd "$here/../.." && pwd)
python3 "$here/flatten.py" "$in" "$out.flat" "$title" "$@" || exit 1
mkdir -p "$(dirname "$out")/xdg"
cd "$root" && XDG_DATA_HOME="${XDG_DATA_HOME:-$(dirname "$out")/xdg}" timeout 2400 \
  ~/.claude/claude-core/bin/${Q:-gpu} godot --headless --path . --script tools/house_models/fixsteps.gd -- "$out.flat" "$out" 2>&1 \
  | grep "^  \|SCRIPT ERROR\|^fixsteps" | head -60
[ -f "$out" ] && sed -i "1s/.*/0 $title/" "$out"
