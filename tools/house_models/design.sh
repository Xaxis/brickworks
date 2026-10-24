#!/bin/bash
# One design by the app's own designer, on this machine's Claude plan, off-screen.
#
#   tools/house_models/design.sh NAME PORT heavy|gpu BRIEF.txt OUTDIR
#
# The desktop app under Xvfb runs --ask-claude-code with the brief, on PORT,
# and writes OUTDIR/NAME/NAME.ldr on every build (and its log beside it, whose
# "api_usd=" line is Claude Code's own price for the run: nothing is billed on
# the plan). Its app data, and the Downloads folder its renders go to, are in
# OUTDIR/NAME: a session's render_model once wrote into the owner's ~/Downloads.
# ANTHROPIC_API_KEY and ANTHROPIC_AUTH_TOKEN are taken out so it never bills
# the key in .env. heavy queues on the CPU, gpu takes the GPU for this run only.
#
# Used by seed211 (2026-10-24) for the twelve house models in the gallery,
# two or three at a time; each took 7 to 28 minutes and $2 to $12.
set -u
name=$1; port=$2; queue=$3; brief=$(cat "$4"); out=$5/$1
root=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$out/xdg" "$out/config" "$out/downloads"
printf 'XDG_DOWNLOAD_DIR="%s"\n' "$out/downloads" > "$out/config/user-dirs.dirs"
cd "$root" || exit 1
echo "design $name on port $port via $queue -> $out/$name.ldr"
timeout 3300 ~/.claude/claude-core/bin/$queue env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN \
  XDG_DATA_HOME="$out/xdg" XDG_CONFIG_HOME="$out/config" MESA_VK_WSI_DEBUG=sw \
  xvfb-run -a --server-args="-screen 0 1600x900x24" \
  godot --path . -- --mcp="$port" --ask-claude-code="$brief" \
  --out="$out/$name.ldr" > "$out/$name.log" 2>&1
status=$?
grep -E "claude code ok=|api_usd=" "$out/$name.log" | cut -c1-200
exit $status
