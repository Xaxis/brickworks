#!/bin/bash
# signin6: orangecheck_check on signin5's tree (cb7956146, where it passed at 12:15) and on this one,
# in turn twice (A B A B), with rests for the verify bucket: whether the stalls past 3 s and 15 s that
# met this tree's runs since 23:50Z meet signin5's too in the same hour.
OUT=/mnt/Projects/brickworks/.claude/worktrees/signin6/bench/results/signin6-2026-11-25
for ROUND in 1 2; do
  for TREE in signin5 signin6; do
    cd "/mnt/Projects/brickworks/.claude/worktrees/$TREE" || exit 1
    set -a; . ./.env; set +a
    echo "== $TREE ($(git rev-parse --short HEAD)) round $ROUND $(date -u +%H:%M:%SZ)"
    timeout 900 node tools/web/orangecheck_check.mjs </dev/null > "$OUT/ab_${TREE}_$ROUND.log" 2>&1
    echo "$TREE exit $? $(date -u +%H:%M:%SZ): $(tail -1 "$OUT/ab_${TREE}_$ROUND.log"); stalls: $(grep -c 'no answer in' "$OUT/ab_${TREE}_$ROUND.log")"
    sleep 150
  done
done
echo "== done $(date -u +%H:%M:%SZ)"
