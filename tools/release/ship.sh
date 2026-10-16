#!/bin/bash
# ship.sh WORKTREE TAG CHECK... : a release from a staging worktree.
# Preview deploy, the browser checks named, and only if every one passes:
# main fast-forwarded and pushed, production deployed, the live site
# checked. Release jobs take BOX_HEAVY_PRIORITY, as other projects' do.
set -u
TAG=$2
# Absolute: preview_checks runs from a copy and cds to it itself, and a
# relative path from here failed that cd (2026-10-15).
W=$(cd "$1" && pwd) || exit 1
shift 2
# The main checkout (where .env and the shared catalogue live), wherever
# this worktree is, and where the release's logs go.
R=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
HERE=${RELEASE_HERE:-$(cd "$(dirname "$0")" && pwd)}
S=${RELEASE_OUT:-${TMPDIR:-/tmp}/brickworks-release}; mkdir -p "$S"
export BOX_HEAVY_PRIORITY=1
# Every check named reported, and passed. A battery that never ran writes
# no results, and "no failed line" read as a pass: m31 went on to deploy
# production with no check run (2026-10-15).
passed() {
  local out=$1 want=$2
  [ -s "$out" ] || return 1
  grep -qE 'exit=[^0]' "$out" && return 1
  [ "$want" -eq 0 ] || [ "$(grep -c ' exit=0 ' "$out")" -eq "$want" ]
}
cd "$W" || exit 1
if [ -e "$(git rev-parse --git-dir)/merging" ]; then echo "SHIP: a merge in $W is still running its gates"; exit 1; fi
SHA=$(git rev-parse --short HEAD)
git -C $R merge-base --is-ancestor main HEAD || { echo "SHIP: $SHA does not contain main"; exit 1; }
set -a; . $R/.env; set +a
# SHIP_REUSE=1: the preview this TAG already made, if it was made from this
# very commit. A timing check that failed under load held a release twice
# on 2026-10-16, and the only way on was a fresh deploy and every check
# again. Reused, the checks named are run again on the same build, and
# all of them must pass, as ever.
URL=""
if [ -n "${SHIP_REUSE:-}" ] && [ "$(cat $S/${TAG}_preview.sha 2>/dev/null)" = "$SHA" ]; then
  URL=$(grep -oE "deploy done https://[^ ]+" $S/${TAG}_preview.log | cut -d' ' -f3)
  [ -n "$URL" ] && echo "SHIP: reusing preview $URL, made from $SHA"
fi
if [ -z "$URL" ]; then
  ~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 900 godot --headless --path . --import >/dev/null 2>&1
  timeout 3000 ~/.claude/claude-core/bin/heavy tools/deploy.sh > $S/${TAG}_preview.log 2>&1
  URL=$(grep -oE "deploy done https://[^ ]+" $S/${TAG}_preview.log | cut -d' ' -f3)
  [ -n "$URL" ] || { echo "SHIP: preview deploy failed"; tail -3 $S/${TAG}_preview.log; exit 1; }
  echo "$SHA" > $S/${TAG}_preview.sha
  echo "SHIP: preview $URL"
fi
rm -f $S/${TAG}_pv.out
"$HERE/preview_checks.sh" "$URL" "$W" ${TAG}_pv "$@" || { echo "SHIP: held, the checks did not run"; exit 1; }
cut -c1-160 $S/${TAG}_pv.out
passed $S/${TAG}_pv.out $# || { echo "SHIP: held, a check failed or did not run on the preview"; exit 1; }
git -C $R merge --ff-only "$SHA" >/dev/null && env -u GITHUB_TOKEN git -C $R push -q origin main || { echo "SHIP: could not fast-forward or push main"; exit 1; }
echo "SHIP: main is $SHA, authors: $(git -C $R log --since='1 day ago' --format='%an <%ae>' | sort | uniq -c | tr '\n' ' ')"
timeout 3000 ~/.claude/claude-core/bin/heavy tools/deploy.sh --prod > $S/${TAG}_prod.log 2>&1
grep -E "serves|deploy FAILED" $S/${TAG}_prod.log | sed 's/^/SHIP: /'
# The CDN keeps serving the last pages for a minute or so after the promotion.
sleep 90
"$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_live site share_probe
if ! passed $S/${TAG}_live.out 2; then sleep 120; "$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_live2 site share_probe; cat $S/${TAG}_live2.out | cut -c1-160; else cat $S/${TAG}_live.out | cut -c1-160; fi
