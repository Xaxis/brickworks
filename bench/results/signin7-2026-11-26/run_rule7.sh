#!/bin/bash
# signin7: rule7.mjs (the one rule on orangecheck's link and unlink, the age answer, the console and
# Settings' Link again) on its own relay, 12270, Google and GitHub stood in for, a throwaway its owner.
cd /mnt/Projects/brickworks/.claude/worktrees/signin7 || exit 1
set -a; . ./.env; set +a
unset VERCEL_ENV
OUT=/mnt/Projects/brickworks/.claude/worktrees/signin7/bench/results/signin7-2026-11-26
SCRATCH=/tmp/claude-1000/-mnt-Projects-brickworks/e06e4b1a-8ee1-4555-9551-53502405c858/scratchpad/signin7
RUN=${RUN:-1}
export BOX_HEAVY_WAIT=21600
OWNER="delivered+bw-si7-owner-$RANDOM$RANDOM@resend.dev"
node tools/web/relay_server.mjs 12270 --ways-stand-in --owner="$OWNER" > "$OUT/relay_12270_rule7_$RUN.log" 2>&1 </dev/null &
R=$!
trap 'kill $R 2>/dev/null' EXIT
for _ in $(seq 1 120); do curl -s -o /dev/null "http://127.0.0.1:12270/api/account" && break; sleep 0.5; done
echo "== rule7 at $(git rev-parse --short HEAD) $(date -u +%H:%M:%SZ)"
~/.claude/claude-core/bin/heavy timeout 1200 node "$OUT/rule7.mjs" --r=http://127.0.0.1:12270 --owner="$OWNER" --out="$OUT/shots_rule7_$RUN" </dev/null
echo "rule7 exit $? $(date -u +%H:%M:%SZ)"
PREFIX=bw-si7- node "$OUT/left.mjs" </dev/null 2>&1 | head -1
