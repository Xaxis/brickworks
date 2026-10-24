#!/bin/bash
# unit_preview.sh WORKTREE [CHECK...] : a unit proves its site changes on a
# preview of its own before it says ready. Deploys the worktree to Vercel,
# unpromoted (never production, never main), then runs the browser checks
# for what the unit changed (flows_for.py since the commit it was made
# from), or the checks named, and site always. One pass or FAIL line a
# check; exits 0 only when every one passed. The preview goes without the
# secrets unreviewed code is not to hold (tools/deploy.sh --unit):
# orangecheck's signing secret, kept for code assembled for release.
#
# Four release previews held on 2026-10-22, each about an hour, and every
# time the fault was a check a unit had not run: units are not to deploy,
# so a flow that needed a deployment first ran on the release's preview.
#
# Results go to $RELEASE_OUT/<branch>_unit_*: the deploy's log and commit
# (_unit_preview.log, .sha), the checks' lines (_unit_pv.out) and each
# check's log (_unit_pv_<check>.log). UNIT_REUSE=1 runs the checks again on
# the preview this branch last made, if it was made from this very commit.
set -u
W=$(cd "${1:?usage: unit_preview.sh WORKTREE [CHECK...]}" && pwd) || exit 1
shift
# The worktree's own scripts, which know its own checks (ship.sh, m87).
mine="$W/tools/release/unit_preview.sh"
if [ -z "${RELEASE_HERE:-}" ] && [ -x "$mine" ] && [ "$(realpath "$0")" != "$(realpath "$mine")" ]; then
  exec "$mine" "$W" "$@"
fi
HERE=${RELEASE_HERE:-$(cd "$(dirname "$0")" && pwd)}
S=$(realpath -m "${RELEASE_OUT:-${TMPDIR:-/tmp}/brickworks-release}"); mkdir -p "$S"
# The release's priority is the release's alone.
unset BOX_HEAVY_PRIORITY
WHO=UNIT
. "$HERE/preview_lib.sh" || exit 1
cd "$W" || exit 1
R=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
BRANCH=$(git rev-parse --abbrev-ref HEAD)
[ "$BRANCH" != HEAD ] || { echo "UNIT: $W is on no branch"; exit 1; }
case "$BRANCH" in main|rel-*) echo "UNIT: $BRANCH is a release's, not a unit's"; exit 1;; esac
TAG=${BRANCH//\//-}_unit
SHA=$(git rev-parse --short HEAD)
# What the unit changed: since where it left main, or the release branch it
# was made from when that is later. A unit made from rel-m147 before m147
# shipped would otherwise run every check m147's own changes call for.
BASE=$(git merge-base HEAD main) || exit 1
FROM=main
for ref in $(git for-each-ref --format='%(refname:short)' 'refs/heads/rel-*'); do
  mb=$(git merge-base HEAD "$ref") || continue
  # A release that has merged this unit already holds all of it.
  [ "$mb" = "$(git rev-parse HEAD)" ] && continue
  if [ "$mb" != "$BASE" ] && git merge-base --is-ancestor "$BASE" "$mb"; then BASE=$mb; FROM=$ref; fi
done
# What is deployed is the working tree, and what is checked is the commit.
dirty=$(git status --porcelain --untracked-files=no; git status --porcelain -- web api tools/web ':!tools/web/node_modules')
[ -z "$dirty" ] || { echo "UNIT: commit first, a preview proves a commit:"; echo "$dirty" | sort -u | head -5; exit 1; }
echo "UNIT: $BRANCH at $SHA, changed since $(git rev-parse --short "$BASE") ($FROM): $(git diff --name-only "$BASE" HEAD | wc -l) files"
if [ $# -eq 0 ]; then
  flows=$(python3 tools/release/flows_for.py --since "$BASE") || exit 1
  echo "$flows" | sed 's/^/  /'
  set -- $(echo "$flows" | sed -n 's/^checks: \([a-z_0-9 ]*\)$/\1/p')
fi
case " $* " in *" site "*) ;; *) set -- "$@" site;; esac
set -- $(printf '%s\n' "$@" | awk '!seen[$0]++')
unwired=$(unwired_flows "$BASE")
[ -z "$unwired" ] || { echo "UNIT: held, a new flow no check runs:$unwired (name it in preview_checks.sh, or mark it there '# local only: NAME')"; exit 1; }
set -a; . "$R/.env"; set +a
URL=""
[ -n "${UNIT_REUSE:-}" ] && reused_preview "$TAG" "$SHA"
if [ -z "$URL" ]; then
  import_here || { echo "unit_preview: the import did not finish (tools/fresh_import.sh)"; exit 1; }
  deploy_preview "$TAG" "$SHA" --unit || exit 1
fi
echo "UNIT: checks on $URL: $*"
run_checks "$URL" "${TAG}_pv" "$@" || exit 1
for name in "$@"; do
  line=$(grep -m1 "^$name exit=" "$S/${TAG}_pv.out")
  case "$line" in
    "") echo "FAIL $name did not report" ;;
    "$name exit=0 "*) echo "pass $line" | cut -c1-200 ;;
    *) echo "FAIL $line" | cut -c1-200 ;;
  esac
done
if passed "$S/${TAG}_pv.out" $#; then
  echo "UNIT: exit=0, $# checks passed on $URL"; exit 0
fi
echo "UNIT: exit=1, a check failed or did not run on $URL (logs: $S/${TAG}_pv_<check>.log)"; exit 1
