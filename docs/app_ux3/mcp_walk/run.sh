#!/bin/bash
# The MCP walk (APP_UX3): the app in a window of its own on the GPU with
# its MCP port open, the walk's words through search_parts, then a Claude
# Code session on the subscription doing PROMPTS' tasks, one turn each,
# continuing one session so calls count per task.
#
#   bash docs/app_ux3/mcp_walk/run.sh OUT [PROMPTS] [PORT]
#
# No API key in its environment: the session bills the subscription. Its
# renders go where Export writes, the Downloads folder: move them out.
set -u
OUT=$(realpath -m "${1:?an output folder}"); PROMPTS=$(realpath "${2:-$(dirname "$0")/prompts_walk.txt}")
PORT=${3:-8936}; HERE=$(cd "$(dirname "$0")" && pwd)
cd "$HERE/../../.." || exit 1
mkdir -p "$OUT/xdg"
export XDG_DATA_HOME=$OUT/xdg
unset ANTHROPIC_API_KEY OPENAI_API_KEY
cat > "$OUT/mcp.json" <<JSON
{"mcpServers": {"brickworks": {"type": "stdio", "command": "python3",
  "args": ["$PWD/tools/brickworks_mcp.py", "--port=$PORT"]}}}
JSON
timeout 3h ~/.claude/claude-core/bin/gpu env MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1600x900x24" \
  godot --path . --resolution 1600x900 -- --mcp="$PORT" > "$OUT/app.log" 2>&1 &
app=$!
timeout 1800 bash -c "until grep -q 'command socket: listening' '$OUT/app.log'; do sleep 2; done"
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
done < "$PROMPTS"
python3 "$HERE/summarise.py" "$OUT"/*.jsonl > "$OUT/calls.txt"
kill $app; pkill -P $app; wait
