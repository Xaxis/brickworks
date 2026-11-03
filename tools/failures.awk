# Each failure as tools/minitest.py says it: its FAIL line and the indented
# lines after it, the first 30 and last 8, each to 300 characters. The lines
# that said FAIL or Error alone held rel-m252 on a train's log, never the
# result that failed (2026-11-03). tools/check.sh and ci_gate.sh print them
# so; nothing when there is no FAIL block (pytest's own output).
#
#   echo "$pyout" | awk -f tools/failures.awk
function out(i) {
  for (i = 1; i <= n; i++)
    if (i <= 30 || i > n - 8) print "  " substr(b[i], 1, 300)
    else if (i == 31) print "      ... (" n - 38 " lines)"
  n = 0
}
/^FAIL  / { out(); b[++n] = $0; on = 1; next }
on && /^  / { b[++n] = $0; next }
{ out(); on = 0 }
END { out() }
