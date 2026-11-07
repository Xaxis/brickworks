#!/bin/bash
# The MCP walk (APP_UX3, rerun by APP_UX4, APP_UX5 and APP_UX6): the app in a window of its own on
# the GPU with its MCP port open, the walk's words through search_parts, then a Claude
# Code session on the subscription doing PROMPTS' tasks, one turn each,
# continuing one session so calls count per task. A line "new|" starts a new
# session on the same app.
#
#   bash docs/app_ux6/mcp_walk/run.sh OUT [PROMPTS...] [PORT]
#
# APP_UX4 ran prompts_walk.txt on one port and prompts_pod.txt then
# prompts_round3.txt (round three's features, one session) on another, two
# apps at once. APP_UX5, with one GPU slot on the box, runs one app:
# prompts_walk.txt, new_session.txt, then prompts_pod.txt, prompts_round3.txt
# and prompts_round4.txt (round four's features) in the second session.
# APP_UX6 adds prompts_round5.txt (round five's features) after round four's,
# in the second session.
# PORT is the last argument when it is a number.
#
# No API key in its environment: the session bills the subscription. Its
# renders and exports go where Export writes, the person's Downloads or
# Documents: the app is given an xdg-user-dir of its own under OUT (as
# tools/probe.sh gives a probe), so none reach the owner's real folders.
set -u
OUT=$(realpath -m "${1:?an output folder}"); shift
PORT=8936; FILES=()
for a in "$@"; do if [[ "$a" =~ ^[0-9]+$ ]]; then PORT=$a; else FILES+=("$(realpath "$a")"); fi; done
HERE=$(cd "$(dirname "$0")" && pwd)
[ ${#FILES[@]} -eq 0 ] && FILES=("$HERE/prompts_walk.txt")
cd "$HERE/../../.." || exit 1
mkdir -p "$OUT/xdg" "$OUT/stubs"
export XDG_DATA_HOME=$OUT/xdg
printf '#!/bin/sh\nd="%s/home/${1:-HOME}"\nmkdir -p "$d" && echo "$d"\n' "$OUT" > "$OUT/stubs/xdg-user-dir"
chmod +x "$OUT/stubs/xdg-user-dir"
unset ANTHROPIC_API_KEY OPENAI_API_KEY
cat > "$OUT/mcp.json" <<JSON
{"mcpServers": {"brickworks": {"type": "stdio", "command": "python3",
  "args": ["$PWD/tools/brickworks_mcp.py", "--port=$PORT"]}}}
JSON
timeout 5h ~/.claude/claude-core/bin/gpu env -u WAYLAND_DISPLAY PATH="$OUT/stubs:$PATH" \
  BRICKWORKS_OPEN_NOTHING=1 BRICKWORKS_KEYCHAIN=off MESA_VK_WSI_DEBUG=sw xvfb-run -a --server-args="-screen 0 1600x900x24" \
  godot --path . --resolution 1600x900 -- --mcp="$PORT" > "$OUT/app.log" 2>&1 < /dev/null &
app=$!
timeout 17000 bash -c "until grep -q 'command socket: listening' '$OUT/app.log'; do sleep 2; done"
python3 "$HERE/search_words.py" "$PORT" "$OUT/search.json" > "$OUT/search.txt" 2>&1
sid=""
while IFS='|' read -r name prompt; do
  [ -z "$name" ] && continue
  if [ "$name" = new ]; then sid=""; continue; fi
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
