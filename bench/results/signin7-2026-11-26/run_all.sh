#!/bin/bash
# signin7: every bar of the brief, one after another so no two share Supabase's verify bucket
# (30 from this box's address, then one each 10 s), against relays of this tree (Google, GitHub and
# Connect stood in for, the real Supabase project behind them) on 12270-12279. The reviewers' scripts
# are copied byte for byte from signreview4's results (branch signreview4, 264e236a6):
#   1. signreview2's attack.mjs (attack_sr2.mjs), A,B (C and D always run), on 12271 (owner O1), 12272 (owner X).
#   2. signreview3's attack3.mjs: V,S,N,W,T,O,K, then X, then W with 3 rounds, on 12273 (fault4 between it
#      and what it asks) and 12274 (orangecheck's keys made up).
#   3. signreview4's flood4.mjs on 12276 (Supabase's verify answered by fault4: none spent).
#   4. ways_check on 12277.   5. orangecheck_check.   6. ways_app_probe on 12278 (probe.sh, heavy).
#   7. signreview4's attack4.mjs L,B,C,D on 12273, F on 12275 (orangecheck's hosts answered by fault4, counted).
#   8. ways_flow five times on 12279 under strace, Chromium's net log and netwatch, then its control, then
#      count.mjs, and orangecheck's hosts counted too.
# Throwaway addresses only; each script deletes its own; left.mjs counts what is left.
# STEPS=1,...,8 (default all) runs some of them.
cd /mnt/Projects/brickworks/.claude/worktrees/signin7 || exit 1
set -a; . ./.env; set +a
unset VERCEL_ENV
OUT=/mnt/Projects/brickworks/.claude/worktrees/signin7/bench/results/signin7-2026-11-26
SCRATCH=/tmp/claude-1000/-mnt-Projects-brickworks/e06e4b1a-8ee1-4555-9551-53502405c858/scratchpad/signin7
W=$OUT/net
mkdir -p "$W"
RUN=${RUN:-1}
STEPS=${STEPS:-1,2,3,4,5,6,7,8}
export BOX_HEAVY_WAIT=21600 PROBE_TIMEOUT=900
PIDS=()
trap 'kill "${PIDS[@]}" 2>/dev/null' EXIT
up() { for _ in $(seq 1 120); do curl -s -o /dev/null "http://127.0.0.1:$1/api/account" && return 0; sleep 0.5; done; return 1; }
gone() { node -e "import('./tools/web/session.mjs').then(async (s) => { console.log('deleted:', await s.deleteAccount(process.argv[1]).catch(() => false)); })" "$1" </dev/null; }
rest() { echo "-- resting ${1}s for the verify bucket"; sleep "$1"; }
step() { [[ ",$STEPS," == *",$1,"* ]]; }
sha() { sha256sum "$1" | cut -c1-16; }
echo "== signin7 bars at $(git rev-parse --short HEAD), $(date -u +%H:%M:%SZ)"

relays34() {
  echo '{}' > "$SCRATCH/rules_12273.json"
  FAULT4_FILE="$SCRATCH/rules_12273.json" FAULT4_LOG="$OUT/fault_12273_$RUN.log" NODE_OPTIONS="--import=$OUT/fault4.mjs" \
    node tools/web/relay_server.mjs 12273 --ways-stand-in --owner="$O3" > "$OUT/relay_12273_$RUN.log" 2>&1 </dev/null &
  PIDS+=($!)
  OC_PROJECT_KEY=made-up-project OC_SIGNING_SECRET=made-up-secret OC_AUDIENCE=http://127.0.0.1:12274 \
    NETWATCH_LOG="$W/relay_12274_$RUN.watch" NODE_OPTIONS="--import=$OUT/netwatch.mjs" \
    node tools/web/relay_server.mjs 12274 --ways-stand-in --owner="$O3" > "$OUT/relay_12274_$RUN.log" 2>&1 </dev/null &
  PIDS+=($!)
  up 12273 && up 12274
}

if step 1; then
  T=$RANDOM$RANDOM
  O1="delivered+bw-sr2-owner1-$T@resend.dev"
  X="delivered+bw-sr2-kx-$T@resend.dev"
  node tools/web/relay_server.mjs 12271 --ways-stand-in --owner="$O1" > "$OUT/relay_12271_$RUN.log" 2>&1 </dev/null &
  PIDS+=($!)
  node tools/web/relay_server.mjs 12272 --ways-stand-in --owner="$X" > "$OUT/relay_12272_$RUN.log" 2>&1 </dev/null &
  PIDS+=($!)
  up 12271 && up 12272
  echo "== signreview2's attack $(date -u +%H:%M:%SZ), sha256 $(sha "$OUT/attack_sr2.mjs")"
  timeout 900 node "$OUT/attack_sr2.mjs" --r1=http://127.0.0.1:12271 --r2=http://127.0.0.1:12272 --x="$X" --only=A,B </dev/null > "$OUT/sr2_attack_$RUN.log" 2>&1
  echo "sr2 exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/sr2_attack_$RUN.log")"
  gone "$O1"; gone "$X"
  kill "${PIDS[@]}" 2>/dev/null; PIDS=()
  rest 180
fi

O3="delivered+bw-sr3-owner3-$RANDOM$RANDOM@resend.dev"
if step 2; then
  relays34
  for PASS in "V,S,N,W,T,O,K" "X" "W --rounds=3"; do
    ONLY=${PASS%% *}; MORE=""; [ "$PASS" != "$ONLY" ] && MORE=${PASS#* }
    NAME=$(echo "$ONLY" | tr -d ,)
    echo "== attack3 $PASS $(date -u +%H:%M:%SZ), sha256 $(sha "$OUT/attack3.mjs")"
    timeout 1500 node "$OUT/attack3.mjs" --r=http://127.0.0.1:12273 --roc=http://127.0.0.1:12274 --owner="$O3" --only="$ONLY" $MORE </dev/null > "$OUT/attack3_${NAME}_$RUN.log" 2>&1
    echo "attack3 $PASS exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/attack3_${NAME}_$RUN.log")"
    rest 120
  done
  kill "${PIDS[@]}" 2>/dev/null; PIDS=()
fi

if step 3; then
  echo '{}' > "$SCRATCH/rules_12276.json"
  : > "$OUT/fault_12276_$RUN.log"
  FAULT4_FILE="$SCRATCH/rules_12276.json" FAULT4_LOG="$OUT/fault_12276_$RUN.log" NODE_OPTIONS="--import=$OUT/fault4.mjs" \
    node tools/web/relay_server.mjs 12276 --ways-stand-in > "$OUT/relay_12276_$RUN.log" 2>&1 </dev/null &
  PIDS+=($!)
  up 12276
  echo "== flood4 $(date -u +%H:%M:%SZ), sha256 $(sha "$OUT/flood4.mjs")"
  timeout 1200 node "$OUT/flood4.mjs" --r=http://127.0.0.1:12276 --rules="$SCRATCH/rules_12276.json" --log="$OUT/fault_12276_$RUN.log" </dev/null > "$OUT/flood4_$RUN.log" 2>&1
  echo "flood4 exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/flood4_$RUN.log")"
  kill "${PIDS[@]}" 2>/dev/null; PIDS=()
  rest 30
fi

if step 4; then
  OWNER="delivered+bw-ways-owner-$RANDOM$RANDOM@resend.dev"
  node tools/web/relay_server.mjs 12277 --ways-stand-in --owner="$OWNER" > "$OUT/relay_12277_$RUN.log" 2>&1 </dev/null &
  PIDS+=($!)
  up 12277
  echo "== ways_check $(date -u +%H:%M:%SZ)"
  timeout 1800 node tools/web/ways_check.mjs --url=http://127.0.0.1:12277 --owner="$OWNER" </dev/null > "$OUT/ways_check_$RUN.log" 2>&1
  echo "ways_check exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/ways_check_$RUN.log")"
  gone "$OWNER"
  kill "${PIDS[@]}" 2>/dev/null; PIDS=()
  rest 240
fi

if step 5; then
  echo "== orangecheck_check $(date -u +%H:%M:%SZ)"
  timeout 900 node tools/web/orangecheck_check.mjs </dev/null > "$OUT/orangecheck_check_$RUN.log" 2>&1
  echo "orangecheck_check exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/orangecheck_check_$RUN.log")"
  rest 120
fi

if step 6; then
  node tools/web/relay_server.mjs 12278 --ways-stand-in > "$OUT/relay_12278_$RUN.log" 2>&1 </dev/null &
  PIDS+=($!)
  up 12278
  ADDR="delivered+bw-si7-app-$RANDOM$RANDOM@resend.dev"
  echo "== ways_app_probe $(date -u +%H:%M:%SZ)"
  BRICKWORKS_API=http://127.0.0.1:12278 WAYS_APP_EMAIL="$ADDR" bash tools/probe.sh ways_app_probe </dev/null > "$OUT/probe_ways_app_$RUN.log" 2>&1
  echo "ways_app_probe exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/probe_ways_app_$RUN.log")"
  gone "$ADDR"
  kill "${PIDS[@]}" 2>/dev/null; PIDS=()
  rest 120
fi

if step 7; then
  relays34
  echo '{"oc": ["oc-auth-stand-in.invalid", "oc-me-stand-in.invalid"]}' > "$SCRATCH/rules_12275.json"
  : > "$OUT/fault_12275_$RUN.log"
  OC_PROJECT_KEY=made-up-project OC_SIGNING_SECRET=made-up-secret OC_AUDIENCE=http://127.0.0.1:12275 \
    OC_ISSUER=https://oc-auth-stand-in.invalid OC_ME_ORIGIN=https://oc-me-stand-in.invalid \
    FAULT4_FILE="$SCRATCH/rules_12275.json" FAULT4_LOG="$OUT/fault_12275_$RUN.log" NODE_OPTIONS="--import=$OUT/fault4.mjs" \
    node tools/web/relay_server.mjs 12275 --ways-stand-in > "$OUT/relay_12275_$RUN.log" 2>&1 </dev/null &
  PIDS+=($!)
  up 12275
  echo "== attack4 $(date -u +%H:%M:%SZ), sha256 $(sha "$OUT/attack4.mjs"); way_try applied: $(node -e "
    fetch(process.env.SUPABASE_URL + '/rest/v1/rpc/way_try_back', { method: 'POST', headers: { apikey: process.env.SUPABASE_SECRET_KEY,
      authorization: 'Bearer ' + process.env.SUPABASE_SECRET_KEY, 'content-type': 'application/json' },
      body: JSON.stringify({ try_key: 'signin7 probe', tried_at: '2000-01-01T00:00:00Z' }) }).then((r) => console.log(r.status === 200 ? 'yes' : 'no ' + r.status))" </dev/null)"
  timeout 2400 node "$OUT/attack4.mjs" --r=http://127.0.0.1:12273 --roc=http://127.0.0.1:12275 --owner="$O3" \
    --rules="$SCRATCH/rules_12273.json" --roclog="$OUT/fault_12275_$RUN.log" ${ATTACK4_ONLY:+--only=$ATTACK4_ONLY} </dev/null > "$OUT/attack4_$RUN.log" 2>&1
  echo "attack4 exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/attack4_$RUN.log")"
  gone "$O3"
  kill "${PIDS[@]}" 2>/dev/null; PIDS=()
  rest 120
fi

if step 8; then
  WATCH="--import=$OUT/netwatch.mjs"
  TRACE="strace -f --seccomp-bpf -e trace=connect -qq"
  : > "$W/owners.txt"
  for N in 1 2 3 4 5; do
    FOWNER="delivered+bw-si7-flowowner-$RANDOM$RANDOM@resend.dev"
    echo "$FOWNER" >> "$W/owners.txt"
    NETWATCH_LOG="$W/relay_$N.watch" NODE_OPTIONS="$WATCH" $TRACE -o "$W/strace_relay_$N.log" \
      node tools/web/relay_server.mjs 12279 --ways-stand-in --owner="$FOWNER" > "$OUT/relay_12279_$N.log" 2>&1 </dev/null &
    R=$!
    up 12279
    echo "== ways_flow $N $(date -u +%H:%M:%SZ)"
    NETWATCH_LOG="$W/flow_$N.watch" NETWATCH_NETLOG_DIR="$W/netlog_$N" NODE_OPTIONS="$WATCH" \
      ~/.claude/claude-core/bin/heavy $TRACE -o "$W/strace_flow_$N.log" timeout 1500 node tools/web/ways_flow.mjs \
      --url=http://127.0.0.1:12279 --owner="$FOWNER" --out="$SCRATCH/shots_$N" </dev/null > "$OUT/ways_flow_$N.log" 2>&1
    echo "ways_flow $N exit $? $(date -u +%H:%M:%SZ): $(grep -E '^  --    requests to' "$OUT/ways_flow_$N.log") | $(tail -1 "$OUT/ways_flow_$N.log")"
    kill $(ps -o pid= --ppid $R) 2>/dev/null
    kill $R 2>/dev/null
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
  echo "== orangecheck's hosts in the flows' lookups and connects (netwatch): $(cat "$W"/relay_[0-9].watch "$W"/flow_*.watch 2>/dev/null | grep -ciE 'ochk|orangecheck')"
fi

for P in bw-sr2- bw-sr3- bw-sr4- bw-si7- bw-ways-; do PREFIX=$P node "$OUT/left.mjs" </dev/null 2>&1 | head -1; done
echo "== done $(date -u +%H:%M:%SZ)"
