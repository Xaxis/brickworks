#!/bin/bash
# signin6: the three bars run 2 failed, again at this tree's commit, one after another (Supabase's
# verify bucket): attack3 X (12112, 12113), ways_check (12115), orangecheck_check. Logs end _$RUN.
cd /mnt/Projects/brickworks/.claude/worktrees/signin6 || exit 1
set -a; . ./.env; set +a
OUT=/mnt/Projects/brickworks/.claude/worktrees/signin6/bench/results/signin6-2026-11-25
W=$OUT/net
RUN=${RUN:-3}
PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT
up() { for _ in $(seq 1 120); do curl -s -o /dev/null "http://127.0.0.1:$1/api/account" && return 0; sleep 0.5; done; return 1; }
rest() { echo "-- resting ${1}s for the verify bucket"; sleep "$1"; }
echo "== signin6 again at $(git rev-parse --short HEAD), $(date -u +%H:%M:%SZ)"

O3="delivered+bw-sr3-owner3-$RANDOM$RANDOM@resend.dev"
node tools/web/relay_server.mjs 12112 --ways-stand-in --owner="$O3" > "$OUT/relay_12112_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
OC_PROJECT_KEY=made-up-project OC_SIGNING_SECRET=made-up-secret OC_AUDIENCE=http://127.0.0.1:12113 \
  NETWATCH_LOG="$W/relay_12113_$RUN.watch" NODE_OPTIONS="--import=$OUT/netwatch.mjs" \
  node tools/web/relay_server.mjs 12113 --ways-stand-in --owner="$O3" > "$OUT/relay_12113_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
up 12112 && up 12113
echo "== attack3 X $(date -u +%H:%M:%SZ), sha256 $(sha256sum "$OUT/attack3.mjs" | cut -c1-16)"
timeout 1500 node "$OUT/attack3.mjs" --r=http://127.0.0.1:12112 --roc=http://127.0.0.1:12113 --owner="$O3" --only=X </dev/null > "$OUT/attack3_X_$RUN.log" 2>&1
echo "attack3 X exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/attack3_X_$RUN.log")"
kill "${PIDS[@]}" 2>/dev/null; PIDS=()
rest 120

OWNER="delivered+bw-ways-owner-$RANDOM$RANDOM@resend.dev"
node tools/web/relay_server.mjs 12115 --ways-stand-in --owner="$OWNER" > "$OUT/relay_12115_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
up 12115
echo "== ways_check $(date -u +%H:%M:%SZ)"
timeout 1800 node tools/web/ways_check.mjs --url=http://127.0.0.1:12115 --owner="$OWNER" </dev/null > "$OUT/ways_check_$RUN.log" 2>&1
echo "ways_check exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/ways_check_$RUN.log")"
kill "${PIDS[@]}" 2>/dev/null; PIDS=()
rest 240

echo "== orangecheck_check $(date -u +%H:%M:%SZ)"
timeout 900 node tools/web/orangecheck_check.mjs </dev/null > "$OUT/orangecheck_check_$RUN.log" 2>&1
echo "orangecheck_check exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/orangecheck_check_$RUN.log")"

for P in bw-sr3- bw-ways- bw-oc-; do PREFIX=$P node "$OUT/left.mjs" </dev/null 2>&1 | head -1; done
echo "== done $(date -u +%H:%M:%SZ)"
