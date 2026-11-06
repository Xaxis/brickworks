#!/bin/bash
# The MCP walk (APP_UX3, rerun by APP_UX4): the app in a window of its own on the GPU with
# its MCP port open, the walk's words through search_parts, then a Claude
# Code session on the subscription doing PROMPTS' tasks, one turn each,
# continuing one session so calls count per task.
#
#   bash docs/app_ux4/mcp_walk/run.sh OUT [PROMPTS...] [PORT]
#
# APP_UX4 runs prompts_walk.txt on one port and prompts_pod.txt then
# prompts_round3.txt (round three's features, one session) on another.
# PORT is the last argument when it is a number.
#
# No API key in its environment: the session bills the subscription. Its
# renders go where Export writes, the Downloads folder: move them out.
set -u
OUT=$(realpath -m "${1:?an output folder}"); shift
PORT=8936; FILES=()
for a in "$@"; do if [[ "$a" =~ ^[0-9]+$ ]]; then PORT=$a; else FILES+=("$(realpath "$a")"); fi; done
HERE=$(cd "$(dirname "$0")" && pwd)
[ ${#FILES[@]} -eq 0 ] && FILES=("$HERE/prompts_walk.txt")
cd "$HERE/../../.." || exit 1
mkdir -p "$OUT/xdg"
export XDG_DATA_HOME=$OUT/xdg
unset ANTHROPIC_API_KEY OPENAI_API_KEY
cat > "$OUT/mcp.json" <<JSON
{"mcpServers": {"brickworks": {"type": "stdio", "command": "python3",
  "args": ["$PWD/tools/brickworks_mcp.py", "--port=$PORT"]}}}
JSON
timeout 3h ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1600x900x24" \
  godot --path . --resolution 1600x900 -- --mcp="$PORT" > "$OUT/app.log" 2>&1 < /dev/null &
app=$!
timeout 10800 bash -c "until grep -q 'command socket: listening' '$OUT/app.log'; do sleep 2; done"
python3 "$HERE/search_words.py" "$PORT" "$OUT/search.json" > "$OUT/search.txt" 2>&1
sid=""
while IFS='|' read -r name prompt; do
  [ -z "$name" ] && continue
  resume=(); [ -n "$sid" ] && resume=(--resume "$sid")
  timeout --kill-after=30 1200 claude -p "$prompt" "${resume[@]}" \
    --mcp-config "$OUT/mcp.json" --strict-mcp-config --tools "" --restricted \
    --allowedTools mcp__brickworks --output-format stream-json --verbose \
    > "$OUT/$name.jsonl" 2> "$OUT/$name.stderr" < /dev/null
  sid=$(python3 -c "
import json
for l in open('$OUT/$name.jsonl'):
    try: d = json.loads(l)
    except ValueError: continue
    if d.get('session_id'): print(d['session_id']); break")
done < <(cat "${FILES[@]}")
python3 "$HERE/summarise.py" "$OUT"/*.jsonl > "$OUT/calls.txt"
kill $app; pkill -P $app; wait $app
