#!/bin/bash
# signin6: every bar of the brief, one after another so no two share Supabase's verify bucket
# (30 from this box's address, then one each 10 s), against relays of this tree (Google, GitHub
# and Connect stood in for, the real Supabase project behind them) on 12110-12119:
#   1. signreview2's attack.mjs (61741abd2, byte for byte as attack_sr2.mjs), A,B (C and D always
#      run), on 12110 (owner O1) and 12111 (owner X).
#   2. signreview3's attack3.mjs (858347689, byte for byte): V,S,N,W,T,O,K, then X, then W again
#      with 3 rounds, on 12112 and 12113 (orangecheck's keys made up, netwatch on).
#   3. r1loop.mjs, 10 rounds, every code traded, on 12117.
#   4. ways_check on 12115.   5. orangecheck_check.   6. ways_app_probe on 12116 (probe.sh, heavy).
#   7. ways_flow five times on 12114 under strace, Chromium's net log and netwatch, as
#      signreview3's run_flows.sh, then its control, then count.mjs.
# Throwaway addresses only; each script deletes its own; left.mjs counts what is left.
cd /mnt/Projects/brickworks/.claude/worktrees/signin6 || exit 1
set -a; . ./.env; set +a
OUT=/mnt/Projects/brickworks/.claude/worktrees/signin6/bench/results/signin6-2026-11-25
SCRATCH=/tmp/claude-1000/-mnt-Projects-brickworks/1948b9a5-72ca-4d00-9696-158dbd545925/scratchpad/signin6
W=$OUT/net
RUN=${RUN:-1}
export BOX_HEAVY_WAIT=21600 PROBE_TIMEOUT=900
PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT
up() { for _ in $(seq 1 120); do curl -s -o /dev/null "http://127.0.0.1:$1/api/account" && return 0; sleep 0.5; done; return 1; }
gone() { node -e "import('./tools/web/session.mjs').then(async (s) => { console.log('deleted:', await s.deleteAccount(process.argv[1]).catch(() => false)); })" "$1" </dev/null; }
rest() { echo "-- resting ${1}s for the verify bucket"; sleep "$1"; }
echo "== signin6 bars at $(git rev-parse --short HEAD), $(date -u +%H:%M:%SZ)"

# 1.
T=$RANDOM$RANDOM
O1="delivered+bw-sr2-owner1-$T@resend.dev"
X="delivered+bw-sr2-kx-$T@resend.dev"
node tools/web/relay_server.mjs 12110 --ways-stand-in --owner="$O1" > "$OUT/relay_12110_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
node tools/web/relay_server.mjs 12111 --ways-stand-in --owner="$X" > "$OUT/relay_12111_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
up 12110 && up 12111
echo "== signreview2's attack $(date -u +%H:%M:%SZ), sha256 $(sha256sum "$OUT/attack_sr2.mjs" | cut -c1-16)"
timeout 900 node "$OUT/attack_sr2.mjs" --r1=http://127.0.0.1:12110 --r2=http://127.0.0.1:12111 --x="$X" --only=A,B </dev/null > "$OUT/sr2_attack_$RUN.log" 2>&1
echo "sr2 exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/sr2_attack_$RUN.log")"
gone "$O1"
kill "${PIDS[@]}" 2>/dev/null; PIDS=()
rest 240

# 2.
O3="delivered+bw-sr3-owner3-$RANDOM$RANDOM@resend.dev"
node tools/web/relay_server.mjs 12112 --ways-stand-in --owner="$O3" > "$OUT/relay_12112_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
OC_PROJECT_KEY=made-up-project OC_SIGNING_SECRET=made-up-secret OC_AUDIENCE=http://127.0.0.1:12113 \
  NETWATCH_LOG="$W/relay_12113_$RUN.watch" NODE_OPTIONS="--import=$OUT/netwatch.mjs" \
  node tools/web/relay_server.mjs 12113 --ways-stand-in --owner="$O3" > "$OUT/relay_12113_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
up 12112 && up 12113
for PASS in "V,S,N,W,T,O,K" "X" "W --rounds=3"; do
  ONLY=${PASS%% *}; MORE=""; [ "$PASS" != "$ONLY" ] && MORE=${PASS#* }
  NAME=$(echo "$ONLY" | tr -d ,)
  echo "== attack3 $PASS $(date -u +%H:%M:%SZ), sha256 $(sha256sum "$OUT/attack3.mjs" | cut -c1-16)"
  timeout 1500 node "$OUT/attack3.mjs" --r=http://127.0.0.1:12112 --roc=http://127.0.0.1:12113 --owner="$O3" --only="$ONLY" $MORE </dev/null > "$OUT/attack3_${NAME}_$RUN.log" 2>&1
  echo "attack3 $PASS exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/attack3_${NAME}_$RUN.log")"
  rest 120
done
kill "${PIDS[@]}" 2>/dev/null; PIDS=()

# 3.
node tools/web/relay_server.mjs 12117 --ways-stand-in > "$OUT/relay_12117_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
up 12117
echo "== r1loop $(date -u +%H:%M:%SZ)"
timeout 1800 node "$OUT/r1loop.mjs" --r=http://127.0.0.1:12117 --rounds=10 </dev/null > "$OUT/r1loop_$RUN.log" 2>&1
echo "r1loop exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/r1loop_$RUN.log")"
kill "${PIDS[@]}" 2>/dev/null; PIDS=()
rest 240

# 4.
OWNER="delivered+bw-ways-owner-$RANDOM$RANDOM@resend.dev"
node tools/web/relay_server.mjs 12115 --ways-stand-in --owner="$OWNER" > "$OUT/relay_12115_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
up 12115
echo "== ways_check $(date -u +%H:%M:%SZ)"
timeout 1800 node tools/web/ways_check.mjs --url=http://127.0.0.1:12115 --owner="$OWNER" </dev/null > "$OUT/ways_check_$RUN.log" 2>&1
echo "ways_check exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/ways_check_$RUN.log")"
kill "${PIDS[@]}" 2>/dev/null; PIDS=()
rest 240

# 5.
echo "== orangecheck_check $(date -u +%H:%M:%SZ)"
timeout 900 node tools/web/orangecheck_check.mjs </dev/null > "$OUT/orangecheck_check_$RUN.log" 2>&1
echo "orangecheck_check exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/orangecheck_check_$RUN.log")"
rest 120

# 6.
node tools/web/relay_server.mjs 12116 --ways-stand-in > "$OUT/relay_12116_$RUN.log" 2>&1 </dev/null &
PIDS+=($!)
up 12116
ADDR="delivered+bw-si6-app-$RANDOM$RANDOM@resend.dev"
echo "== ways_app_probe $(date -u +%H:%M:%SZ)"
BRICKWORKS_API=http://127.0.0.1:12116 WAYS_APP_EMAIL="$ADDR" bash tools/probe.sh ways_app_probe </dev/null > "$OUT/probe_ways_app_$RUN.log" 2>&1
echo "ways_app_probe exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/probe_ways_app_$RUN.log")"
gone "$ADDR"
kill "${PIDS[@]}" 2>/dev/null; PIDS=()
rest 120

# 7.
WATCH="--import=$OUT/netwatch.mjs"
TRACE="strace -f --seccomp-bpf -e trace=connect -qq"
: > "$W/owners.txt"
for N in 1 2 3 4 5; do
  FOWNER="delivered+bw-si6-flowowner-$RANDOM$RANDOM@resend.dev"
  echo "$FOWNER" >> "$W/owners.txt"
  NETWATCH_LOG="$W/relay_$N.watch" NODE_OPTIONS="$WATCH" $TRACE -o "$W/strace_relay_$N.log" \
    node tools/web/relay_server.mjs 12114 --ways-stand-in --owner="$FOWNER" > "$OUT/relay_12114_$N.log" 2>&1 </dev/null &
  R=$!
  up 12114
  echo "== ways_flow $N $(date -u +%H:%M:%SZ)"
  NETWATCH_LOG="$W/flow_$N.watch" NETWATCH_NETLOG_DIR="$W/netlog_$N" NODE_OPTIONS="$WATCH" \
    ~/.claude/claude-core/bin/heavy $TRACE -o "$W/strace_flow_$N.log" timeout 1500 node tools/web/ways_flow.mjs \
    --url=http://127.0.0.1:12114 --owner="$FOWNER" --out="$OUT/shots_$N" </dev/null > "$OUT/ways_flow_$N.log" 2>&1
  echo "ways_flow $N exit $? $(date -u +%H:%M:%SZ): $(grep -E '^  --    requests to' "$OUT/ways_flow_$N.log") | $(tail -1 "$OUT/ways_flow_$N.log")"
  kill $(ps -o pid= --ppid $R) 2>/dev/null
  wait $R 2>/dev/null
  rest 60
done
while read -r FOWNER; do gone "$FOWNER"; done < "$W/owners.txt"
echo "== control $(date -u +%H:%M:%SZ)"
NETWATCH_LOG="$W/control.watch" NETWATCH_NETLOG_DIR="$W/netlog_control" NODE_OPTIONS="$WATCH" \
  ~/.claude/claude-core/bin/heavy $TRACE -o "$W/strace_control.log" timeout 300 node "$OUT/control.mjs" </dev/null > "$OUT/control.log" 2>&1
echo "control exit $? $(date -u +%H:%M:%SZ)"
node "$OUT/count.mjs" "$OUT" > "$OUT/count.log" 2>&1 </dev/null
echo "count exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/count.log")"

for P in bw-sr2- bw-sr3- bw-si6- bw-ways-; do PREFIX=$P node "$OUT/left.mjs" </dev/null 2>&1 | head -1; done
echo "== done $(date -u +%H:%M:%SZ)"
