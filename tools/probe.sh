#!/bin/bash
# probe.sh NAME [ARGS…] : run one probe the way its own header says.
#
# A probe's header gives its command: headless, or in a window at a size.
# Run from memory, share_view_probe went headless twice and failed where
# it passes in a window; the second time it kept m82's hold (2026-10-18).
# So the header decides here. NAME is the probe's file name without .gd
# (share_view_probe), and ARGS go to the probe after its `--`.
#
# Headless runs go in a CPU slot (`heavy`); a window gets the GPU lease
# and Xvfb as tools/check.sh gives it, with MESA_VK_WSI_DEBUG=sw so the
# GPU draws rather than lavapipe. A header naming no size gets 1400x900.
# BOX_HEAVY_PRIORITY passes through for a release's own probes.
#
# Every run gets its own data folder (XDG_DATA_HOME), printed first: a
# probe's user:// is never the owner's app data, and never another run's.
# It is removed when the probe passes and kept when it fails.
# PROBE_DATA=DIR names one instead. The exit is the probe's, 1 when
# the script failed to load (Godot exits 0 for that), and 3 when the
# probe skipped itself.
# PROBE_DRY=1 prints the command and runs nothing.
set -u
name=${1:?usage: probe.sh NAME [ARGS…]}; shift
name=${name%.gd}; name=${name##*/}
cd "$(dirname "$0")/.." || exit 1
file="src/dev/$name.gd"
[ -f "$file" ] || { echo "probe.sh: no $file" >&2; exit 2; }

# The header's command: the line naming this script, and the lines it
# continues with a backslash.
block=$(awk -v s="--script $file" '
  NR > 80 { exit }
  /^##/ { line = $0; sub(/^##[ \t]*/, "", line)
          if (cont) cmd = cmd " " line; else cmd = line
          if (index(line, s)) { print cmd; exit }
          cont = (line ~ /\\$/); next }
  { cont = 0 }' "$file")
if [ -z "$block" ]; then
  echo "probe.sh: $file's header gives no command (--script $file); write one there first" >&2
  exit 2
fi

data=${PROBE_DATA:-}; made=
if [ -z "$data" ] && [ -z "${PROBE_DRY:-}" ]; then
  data=$(mktemp -d "${TMPDIR:-/tmp}/probe-data.$name.XXXXXX"); made=1
fi
echo "probe.sh: $name, data in $data"
core="$HOME/.claude/claude-core/bin"
heavy=(); [ -x "$core/heavy" ] && heavy=("$core/heavy")
gpu=(); [ -x "$core/gpu" ] && gpu=("$core/gpu")
tail=(); [ $# -gt 0 ] && tail=(-- "$@")

case " $block " in
  *" --headless "*)
    how="headless"
    cmd=("${heavy[@]}" env XDG_DATA_HOME="$data"
      godot --headless --path . --script "$file" "${tail[@]}") ;;
  *)
    size=$(grep -oE -- '--resolution [0-9]+x[0-9]+' <<<"$block" | head -1 | cut -d' ' -f2)
    size=${size:-1400x900}
    how="in a ${size} window on the GPU"
    cmd=("${heavy[@]}" "${gpu[@]}" env XDG_DATA_HOME="$data" MESA_VK_WSI_DEBUG=sw
      xvfb-run -a --server-args="-screen 0 ${size}x24"
      godot --path . --resolution "$size" --script "$file" "${tail[@]}") ;;
esac
echo "probe.sh: $how, as its header says"
if [ -n "${PROBE_DRY:-}" ]; then echo "${cmd[*]}"; exit 0; fi

# Godot exits 0 when the script fails to load, and prints nothing more:
# a probe with a typo reports success. Read for that, as check.sh does.
out=$(mktemp "${TMPDIR:-/tmp}/probe-out.$name.XXXXXX")
"${cmd[@]}" 2>&1 | tee "$out"
code=${PIPESTATUS[0]}
if grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script' "$out"; then
  echo "probe.sh: $name printed a script error (above), so it failed"
  [ "$code" = 0 ] && code=1
fi
# And a probe that skipped itself exits 0 having checked nothing: covers2's
# joint check "passed" that way with its parts' exact shapes gone, which
# would have shipped 942 parts with no shape to judge a move by (2026-10-19).
if [ "$code" = 0 ] && grep -qE '^[a-z_ ]+probe: SKIPPED' "$out"; then
  echo "probe.sh: $name skipped itself (above), which proves nothing, so it failed"
  code=3
fi
rm -f "$out"
# A folder made here goes when the probe passed, and stays to be read when
# it failed. One named by PROBE_DATA is the caller's.
if [ -n "$made" ]; then
  if [ "$code" = 0 ]; then rm -rf "$data"; else echo "probe.sh: its data kept in $data"; fi
fi
exit "$code"
