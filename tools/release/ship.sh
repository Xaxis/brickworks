#!/bin/bash
# ship.sh WORKTREE TAG CHECK... : a release from a staging worktree.
# Preview deploy, the browser checks named, and only if every one passes:
# main fast-forwarded and pushed, production deployed, the live site
# checked. Release jobs take BOX_HEAVY_PRIORITY, as other projects' do.
set -u
W=$1; TAG=$2; shift 2
# The main checkout (where .env and the shared catalogue live), wherever
# this worktree is, and where the release's logs go.
R=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
HERE=${RELEASE_HERE:-$(cd "$(dirname "$0")" && pwd)}
S=${RELEASE_OUT:-${TMPDIR:-/tmp}/brickworks-release}; mkdir -p "$S"
export BOX_HEAVY_PRIORITY=1
cd "$W" || exit 1
SHA=$(git rev-parse --short HEAD)
git -C $R merge-base --is-ancestor main HEAD || { echo "SHIP: $SHA does not contain main"; exit 1; }
set -a; . $R/.env; set +a
~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 900 godot --headless --path . --import >/dev/null 2>&1
timeout 3000 ~/.claude/claude-core/bin/heavy tools/deploy.sh > $S/${TAG}_preview.log 2>&1
URL=$(grep -oE "deploy done https://[^ ]+" $S/${TAG}_preview.log | cut -d' ' -f3)
[ -n "$URL" ] || { echo "SHIP: preview deploy failed"; tail -3 $S/${TAG}_preview.log; exit 1; }
echo "SHIP: preview $URL"
"$HERE/preview_checks.sh" "$URL" "$W" ${TAG}_pv "$@"
cat $S/${TAG}_pv.out | cut -c1-160
if grep -qE "exit=[^0]" $S/${TAG}_pv.out; then echo "SHIP: held, a check failed on the preview"; exit 1; fi
git -C $R merge --ff-only "$SHA" >/dev/null && env -u GITHUB_TOKEN git -C $R push -q origin main || { echo "SHIP: could not fast-forward or push main"; exit 1; }
echo "SHIP: main is $SHA, authors: $(git -C $R log --since='1 day ago' --format='%an <%ae>' | sort | uniq -c | tr '\n' ' ')"
timeout 3000 ~/.claude/claude-core/bin/heavy tools/deploy.sh --prod > $S/${TAG}_prod.log 2>&1
grep -E "serves|deploy FAILED" $S/${TAG}_prod.log | sed 's/^/SHIP: /'
# The CDN keeps serving the last pages for a minute or so after the promotion.
sleep 90
"$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_live site share_probe
if grep -qE "exit=[^0]" $S/${TAG}_live.out; then sleep 120; "$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_live2 site share_probe; cat $S/${TAG}_live2.out | cut -c1-160; else cat $S/${TAG}_live.out | cut -c1-160; fi
