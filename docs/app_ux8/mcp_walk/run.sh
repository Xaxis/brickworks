#!/bin/bash
# The MCP walk (APP_UX3, rerun by APP_UX4 to APP_UX8): the app in a window of its own on
# the GPU with its MCP port open, the walk's words through search_parts, then a Claude
# Code session on the subscription doing PROMPTS' tasks, one turn each,
# continuing one session so calls count per task. A line "new|" starts a new
# session on the same app.
#
#   tools/release/live_db.sh appux8-mcp bash docs/app_ux8/mcp_walk/run.sh OUT [PROMPTS...] [PORT]
#
# APP_UX7: signed in, as everyone who uses Brickworks is (2026-10-11). APP_UX6's
# app was signed out, and its collection tasks were refused for it. The
# deployment's functions run on this machine (tools/web/relay_server.mjs, on
# PORT+1), a throwaway account is made on them (tools/web/relay_account.mjs,
# a Resend test address, as realset.py --via relay makes one), its session is
# put where a returning visitor's app keeps it (user://session.json), and the
# account is deleted at the end. Supabase is production, so the run holds a
# slot of the live database's lock (tools/release/live_db.sh), as the relay's
# probes do. The account's keys are kept out of OUT once it is deleted.
#
# APP_UX4 ran prompts_walk.txt on one port and prompts_pod.txt then
# prompts_round3.txt (round three's features, one session) on another, two
# apps at once. APP_UX5, with one GPU slot on the box, runs one app:
# prompts_walk.txt, new_session.txt, then prompts_pod.txt, prompts_round3.txt
# and prompts_round4.txt (round four's features) in the second session.
# APP_UX6 adds prompts_round5.txt (round five's features) after round four's,
# in the second session, and APP_UX7 prompts_round6.txt after that.
# APP_UX8 adds prompts_round7.txt (round seven's features) after round six's,
# then prompts_frontier.txt in a third session: the tasks past any other
# tool's reach (a build that checks itself, steps a child can follow, a model
# that moves, a design from the person's own parts, one at a set's quality,
# building together), as the person's own Claude can do them today.
# PORT is the last argument when it is a number.
#
# No API key in its environment: the session bills the subscription. Its
# renders and exports go where Export writes, the person's Downloads or
# Documents: the app is given an xdg-user-dir of its own under OUT (as
# tools/probe.sh gives a probe), so none reach the owner's real folders.
set -u
OUT=$(realpath -m "${1:?an output folder}"); shift
PORT=9930; FILES=()
for a in "$@"; do if [[ "$a" =~ ^[0-9]+$ ]]; then PORT=$a; else FILES+=("$(realpath "$a")"); fi; done
HERE=$(cd "$(dirname "$0")" && pwd)
[ ${#FILES[@]} -eq 0 ] && FILES=("$HERE/prompts_walk.txt")
cd "$HERE/../../.." || exit 1
mkdir -p "$OUT/xdg" "$OUT/stubs"
export XDG_DATA_HOME=$OUT/xdg
printf '#!/bin/sh\nd="%s/home/${1:-HOME}"\nmkdir -p "$d" && echo "$d"\n' "$OUT" > "$OUT/stubs/xdg-user-dir"
chmod +x "$OUT/stubs/xdg-user-dir"
RPORT=$((PORT + 1))
ORIGIN=http://127.0.0.1:$RPORT
setsid node --env-file=.env tools/web/relay_server.mjs "$RPORT" > "$OUT/relay.log" 2>&1 < /dev/null &
relay=$!
timeout 60 bash -c "until grep -q 'functions on' '$OUT/relay.log'; do sleep 1; done" \
  || { echo "run.sh: the relay never listened; see $OUT/relay.log" >&2; kill -TERM -- "-$relay"; exit 1; }
node --env-file=.env tools/web/relay_account.mjs open --origin="$ORIGIN" > "$OUT/account.out" 2> "$OUT/account.err" \
  || { echo "run.sh: no throwaway account; see $OUT/account.err" >&2; kill -TERM -- "-$relay"; exit 1; }
KEEP="$XDG_DATA_HOME/godot/app_userdata/Brickworks"
mkdir -p "$KEEP"
USER_ID=$(python3 -c "
import json, sys
a = json.loads(open('$OUT/account.out').read().strip().splitlines()[-1])
open('$KEEP/session.json', 'w').write(json.dumps(a['kept']))
print(a['user'])")
# Whatever happens, the account goes and its keys leave OUT.
done_with_account() {
  node --env-file=.env tools/web/relay_account.mjs close --user="$USER_ID" > "$OUT/account_close.txt" 2>&1
  echo "closed exit=$? user=$USER_ID" >> "$OUT/account_close.txt"
  rm -f "$OUT/account.out" "$KEEP/session.json"
  kill -TERM -- "-$relay" 2>/dev/null
}
trap done_with_account EXIT
unset ANTHROPIC_API_KEY OPENAI_API_KEY
cat > "$OUT/mcp.json" <<JSON
{"mcpServers": {"brickworks": {"type": "stdio", "command": "python3",
  "args": ["$PWD/tools/brickworks_mcp.py", "--port=$PORT"]}}}
JSON
timeout 5h ~/.claude/claude-core/bin/gpu env -u WAYLAND_DISPLAY PATH="$OUT/stubs:$PATH" \
  BRICKWORKS_API="$ORIGIN" BRICKWORKS_OPEN_NOTHING=1 BRICKWORKS_KEYCHAIN=off MESA_VK_WSI_DEBUG=sw \
  xvfb-run -a --server-args="-screen 0 1600x900x24" \
  godot --path . --resolution 1600x900 -- --mcp="$PORT" --signed-in > "$OUT/app.log" 2>&1 < /dev/null &
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
