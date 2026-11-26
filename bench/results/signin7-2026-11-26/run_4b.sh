#!/bin/bash
# signin7: signreview4's attack4b.mjs (Y, Z: Delete account from a Google or GitHub session, and from one
# an Unlink has just ended), byte for byte, on a relay of this tree (12270), Google and GitHub stood in for.
cd /mnt/Projects/brickworks/.claude/worktrees/signin7 || exit 1
set -a; . ./.env; set +a
unset VERCEL_ENV
OUT=/mnt/Projects/brickworks/.claude/worktrees/signin7/bench/results/signin7-2026-11-26
RUN=${RUN:-1}
node tools/web/relay_server.mjs 12270 --ways-stand-in > "$OUT/relay_12270_$RUN.log" 2>&1 </dev/null &
R=$!
trap 'kill $R 2>/dev/null' EXIT
for _ in $(seq 1 120); do curl -s -o /dev/null "http://127.0.0.1:12270/api/account" && break; sleep 0.5; done
echo "== attack4b at $(git rev-parse --short HEAD) $(date -u +%H:%M:%SZ), sha256 $(sha256sum "$OUT/attack4b.mjs" | cut -c1-16)"
timeout 600 node "$OUT/attack4b.mjs" --r=http://127.0.0.1:12270 </dev/null
echo "attack4b exit $? $(date -u +%H:%M:%SZ)"
