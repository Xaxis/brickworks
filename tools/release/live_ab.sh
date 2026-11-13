#!/bin/bash
# live_ab.sh WORKTREE TAG NAME PREVIEW : a timing check that failed on a
# release's preview, run again on that preview (P) and on brickworks.diy (L)
# by turns, P L L P (AB_ROUNDS pairs, 2; a third adds P L), and judged by the
# measures it prints (timing_judge.py): the change, or the load? Each run is
# the check as the release's battery runs it, from the release's tree on
# both sides (preview_checks.sh: under heavy, solo, at the live database's
# lock), so both are measured by the same script on the same box, one after
# the other. TAG_ab_NAME.order names the runs, TAG_ab_NAME.runs gets a line
# as each ends (the load it began at, its result), its log is
# TAG_ab_NAME_<run>_NAME.log, and TAG_ab_NAME.judge holds the verdict and a
# line a measure, both sides' numbers. Exits 0 to ship past, 1 to hold.
#
# One run on brickworks.diy is luck: at load ~35 it fails play's phone bar 1
# run in 3. rel-m287 held twice on play (3324, 3685 ms against 3000) while
# live passed (1267, 1953), and the lead's A/B, P L L P P L, found the
# preview no slower: 2511 against 2809 ms mean. m142's drag frames
# (timing_ab.sh) and rel-m249's were the same, each A/B done by hand
# (2026-11-11). AB_LIVE names the other side (brickworks.diy).
set -u
[ $# -eq 4 ] || { sed -n 2,12p "$0"; exit 2; }
W=$(cd "$1" && pwd) || exit 2
TAG=$2 NAME=$3 P=$4
HERE=${RELEASE_HERE:-$(cd "$(dirname "$0")" && pwd)}
S=$(realpath -m "${RELEASE_OUT:-${TMPDIR:-/tmp}/brickworks-release}"); mkdir -p "$S"
L=${AB_LIVE:-https://brickworks.diy}
AB=$S/${TAG}_ab_$NAME
runs=(); n=0
for r in $(seq 1 "${AB_ROUNDS:-2}"); do
  pair="P L"; [ $((r % 2)) = 0 ] && pair="L P"
  for side in $pair; do n=$((n + 1)); runs+=("$side$n"); done
done
rm -f "$AB.judge"
# A reship of the same preview adds its runs to the earlier rounds', kept
# as TAG_ab_NAME_r<k><run>_NAME.log and listed in TAG_ab_NAME.kept; a new
# preview starts over. Two runs a side cannot see a check's own swing:
# rel-m290's play held twice, its verdict flipping between sizes (laptop
# no worse then worse, phone worse then no worse) with brickworks.diy alone
# swinging 1956 ms; pooled four a side, both no worse (2026-11-12).
judged=()
if [ "$(cat "$AB.preview" 2>/dev/null)" = "$P" ] && [ -s "$AB.order" ]; then
  k=1; while [ -e "$AB.round$k" ]; do k=$((k + 1)); done
  : > "$AB.round$k"
  read -r -a earlier < "$AB.order"
  for run in "${earlier[@]}"; do
    f=$S/${TAG}_ab_${NAME}_${run}_$NAME.log o=$S/${TAG}_ab_${NAME}_$run.out
    [ -e "$f" ] || continue
    code=$(sed -n "s/^$NAME exit=\([0-9]*\) .*/\1/p" "$o" 2>/dev/null | head -1)
    mv -f "$f" "$S/${TAG}_ab_${NAME}_r$k${run}_$NAME.log"
    [ -e "$o" ] && mv -f "$o" "$S/${TAG}_ab_${NAME}_r$k$run.out"
    echo "${run:0:1} ${code:-127} $S/${TAG}_ab_${NAME}_r$k${run}_$NAME.log" >> "$AB.kept"
  done
else
  rm -f "$AB.runs" "$AB.kept" "$AB".round*
fi
echo "$P" > "$AB.preview"
while read -r side code path; do
  [ -e "$path" ] && judged+=(--run "$side" "$code" "$path")
done < <(cat "$AB.kept" 2>/dev/null)
echo "${runs[*]}" > "$AB.order"
for run in "${runs[@]}"; do
  side=${run:0:1}; url=$P; [ "$side" = L ] && url=$L
  load=$(cut -d' ' -f1 /proc/loadavg)
  # Through preview_checks.sh, which clears the answer first, as run_checks does.
  "$HERE/preview_checks.sh" "$url" "$W" "${TAG}_ab_${NAME}_$run" "$NAME" >/dev/null 2>&1
  line=$(grep -m1 "^$NAME exit=" "$S/${TAG}_ab_${NAME}_$run.out" 2>/dev/null)
  code=$(sed -n 's/^[^ ]* exit=\([0-9]*\) .*/\1/p' <<< "$line")
  echo "$run load=$load ${line:-$NAME exit=127 :: wrote no line}" | cut -c1-240 >> "$AB.runs"
  judged+=(--run "$side" "${code:-127}" "$S/${TAG}_ab_${NAME}_${run}_$NAME.log")
done
python3 "$HERE/timing_judge.py" --battery "$S/${TAG}_pv_$NAME.log" "${judged[@]}" > "$AB.judge.$$" 2>&1
code=$?
mv -f "$AB.judge.$$" "$AB.judge"
cat "$AB.judge"
exit "$code"
