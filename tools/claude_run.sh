#!/usr/bin/env bash
# Design a brief with the Claude Code on this machine, the way a person
# builds from claude.ai over the connector, and measure what it built.
#
#   tools/claude_run.sh NAME [--brief "..."] [--against fantasy] [--out DIR]
#
# The Orthanc brief is the default, because it is the one the owner judged
# ("too symmetric, functional square bricks") and every run since has been
# measured against it: docs/ROADMAP.md, "Beyond variety: beauty".
#
# Off-screen, on the GPU: the app renders into Xvfb, so no window opens on
# the owner's desktop — a run that did was ended by a stray Escape, which
# quits the app, and kept only what it had saved so far. Its own port, so
# two runs and a session on 8787 never meet. On your Claude plan; nothing
# is billed here.
set -u
cd "$(dirname "$0")/.." || exit 1

name="${1:?a name for the run, e.g. orthanc_10}"
shift
brief="The Tower of Orthanc, Saruman's fortress at Isengard from The Lord of the Rings, as a LEGO display model: the tall many-sided tower of black stone rising to four sharp horns around a high platform, standing on a rocky base. Make it as detailed and creative as a set LEGO would release."
against="fantasy"
out="shots/runs"
while [ $# -gt 0 ]; do
  case "$1" in
    --brief) brief="$2"; shift 2 ;;
    --against) against="$2"; shift 2 ;;
    --out) out="$2"; shift 2 ;;
    *) echo "unknown: $1"; exit 2 ;;
  esac
done
mkdir -p "$out"

# A port nobody is listening on.
port=$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')

echo "run $name on port $port -> $out/$name.ldr"
timeout 5400 ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw \
  xvfb-run -a --server-args="-screen 0 1600x900x24" \
  godot --path . -- --mcp="$port" --ask-claude-code="$brief" \
  --out="$out/$name.ldr" > "$out/$name.log" 2>&1
status=$?
grep "claude code ok=" "$out/$name.log" | cut -c1-120
python3 tools/style.py "$out/$name.ldr" --against "$against" 2>&1 \
  | grep -E "parts,|snot |angled|curve |texture|plain|symmetry |shapes|colours"
exit $status
