#!/bin/bash
# signin7: ways_flow once more (run_all_1's five each stopped on one of the flow's own 60 s waits at
# load ~60 on 24 cores), on 12279 under netwatch, as run_all.sh step 8 runs it. N names the run.
cd /mnt/Projects/brickworks/.claude/worktrees/signin7 || exit 1
set -a; . ./.env; set +a
unset VERCEL_ENV
OUT=/mnt/Projects/brickworks/.claude/worktrees/signin7/bench/results/signin7-2026-11-26
SCRATCH=/tmp/claude-1000/-mnt-Projects-brickworks/e06e4b1a-8ee1-4555-9551-53502405c858/scratchpad/signin7
W=$OUT/net
N=${N:-6}
export BOX_HEAVY_WAIT=21600
WATCH="--import=$OUT/netwatch.mjs"
FOWNER="delivered+bw-si7-flowowner-$RANDOM$RANDOM@resend.dev"
NETWATCH_LOG="$W/relay_$N.watch" NODE_OPTIONS="$WATCH" \
  node tools/web/relay_server.mjs 12279 --ways-stand-in --owner="$FOWNER" > "$OUT/relay_12279_$N.log" 2>&1 </dev/null &
R=$!
trap 'kill $R 2>/dev/null' EXIT
for _ in $(seq 1 120); do curl -s -o /dev/null "http://127.0.0.1:12279/api/account" && break; sleep 0.5; done
echo "== ways_flow $N at $(git rev-parse --short HEAD) $(date -u +%H:%M:%SZ), load $(cut -d' ' -f1-3 /proc/loadavg)"
NETWATCH_LOG="$W/flow_$N.watch" NETWATCH_NETLOG_DIR="$W/netlog_$N" NODE_OPTIONS="$WATCH" \
  ~/.claude/claude-core/bin/heavy timeout 1500 node tools/web/ways_flow.mjs \
  --url=http://127.0.0.1:12279 --owner="$FOWNER" --out="$SCRATCH/shots_$N" </dev/null > "$OUT/ways_flow_$N.log" 2>&1
echo "ways_flow $N exit $? $(date -u +%H:%M:%SZ): $(grep -E '^  --    requests to' "$OUT/ways_flow_$N.log") | $(tail -1 "$OUT/ways_flow_$N.log")"
node -e "import('./tools/web/session.mjs').then(async (s) => { console.log('deleted:', await s.deleteAccount(process.argv[1]).catch(() => false)); })" "$FOWNER" </dev/null
echo "== provider and orangecheck hosts in this run's lookups and connects (netwatch): $(cat "$W/relay_$N.watch" "$W/flow_$N.watch" 2>/dev/null | grep -ciE 'google|github|ochk|orangecheck')"
