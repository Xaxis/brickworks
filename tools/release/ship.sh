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
# The release's own scripts, not the copy this was started from: m87 was
# started from main's, whose preview_checks did not know the three checks
# m87 added, and held on "no such check" (2026-10-19).
mine="$W/tools/release/ship.sh"
if [ -z "${RELEASE_HERE:-}" ] && [ -x "$mine" ] && [ "$(realpath "$0")" != "$(realpath "$mine")" ]; then
  exec "$mine" "$W" "$TAG" "$@"
fi
# Every release runs the site check and the frames check, named or not: a
# feature that taxed every frame (the grab handles, found twice a second)
# held a big model's timeline step at 6 s for hours while every check named
# passed (2026-10-17).
for always in site frames; do
  case " $* " in *" $always "*) ;; *) set -- "$@" "$always";; esac
done
# The main checkout (where .env and the shared catalogue live), wherever
# this worktree is, and where the release's logs go.
R=$(dirname "$(git -C "$(dirname "$0")" rev-parse --path-format=absolute --git-common-dir)")
HERE=${RELEASE_HERE:-$(cd "$(dirname "$0")" && pwd)}
S=$(realpath -m "${RELEASE_OUT:-${TMPDIR:-/tmp}/brickworks-release}"); mkdir -p "$S"
# Begun, this is TAG's latest attempt: a result left by one before, or by a
# waiter that gave up, would tell the release queued behind it that it had
# ended (m178 held on m177's, 2026-10-26). And it writes its own as it ends,
# begun by hand or queued: m181's promote, begun by hand, wrote none, and
# m182 queued behind it could only have waited for ever (2026-10-26).
rm -f "$S/$TAG.done" "$S/$TAG.gave_up"
trap 'echo $? > "$S/$TAG.done"' EXIT
export BOX_HEAVY_PRIORITY=1
# The preview and its checks, as unit_preview.sh makes and runs them.
. "$HERE/preview_lib.sh" SHIP || exit 1
cd "$W" || exit 1
if [ -e "$(git rev-parse --git-dir)/merging" ]; then echo "SHIP: a merge in $W is still running its gates"; exit 1; fi
SHA=$(git rev-parse --short HEAD)
git -C $R merge-base --is-ancestor main "$SHA" || { echo "SHIP: $SHA does not contain main"; exit 1; }
unwired=$(unwired_flows main)
[ -z "$unwired" ] || { echo "SHIP: held, a new flow no check runs:$unwired (name it in preview_checks.sh, or mark it there '# local only: NAME')"; exit 1; }
set -a; . $R/.env; set +a
# SHIP_REUSE=1: the preview this TAG already made, if it was made from this
# very commit. A timing check that failed under load held a release twice
# on 2026-10-16, and the only way on was a fresh deploy and every check
# again. Reused, the checks named are run again on the same build, and
# all of them must pass, as ever.
URL=""
[ -n "${SHIP_REUSE:-}" ] && reused_preview "$TAG" "$SHA"
if [ -z "$URL" ]; then
  # What CI ran on every push and nobody read: the version, the Python
  # suite, the shell scripts. First, as it needs no import: two minutes in
  # its slot at load 40 (2026-10-26).
  "$HERE/ci_gate.sh" "$W" || { echo "SHIP: held, the version, the Python suite or a shell script (ci_gate.sh)"; exit 1; }
  import_here || { echo "SHIP: held, the import did not finish (tools/fresh_import.sh)"; exit 1; }
  # The merge gates, here under the release's priority: every GDScript file
  # changed since main parses, and the tool list is the app's. Run per merge
  # without priority, each waited 30 to 70 minutes for a slot at load 50 on
  # 2026-10-16, before the release waited again (MERGE_GATES=ship).
  "$HERE/parse_gate.sh" "$W" main || { echo "SHIP: held, a script does not parse"; exit 1; }
  sync=$(~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 1200 godot --headless --path . --script src/dev/mcp_sync_probe.gd 2>&1)
  echo "$sync" | grep -q "the MCP is in step with the app" \
    || { echo "SHIP: held, the tool list is not the app's"; echo "$sync" | grep -E "FAIL" | head -3; exit 1; }
  deploy_preview "$TAG" "$SHA" || exit 1
fi
run_checks "$URL" ${TAG}_pv "$@" || exit 1
cut -c1-160 $S/${TAG}_pv.out
# A check that failed in the battery, two at a time beside other previews'
# batteries, runs once more alone before the release holds. m162's oc, and
# m164's oc and cloud_library, each stalled under load and passed alone on
# the same deployment (2026-10-24), and each time the rerun was done by
# hand. Timing checks never get a second go: alone they would pass what the
# load showed. Both answers are kept: TAG_pv.out keeps the first, and
# TAG_alone_NAME.out the second.
if ! passed $S/${TAG}_pv.out $#; then
  failed=$(grep -E ' exit=[^0]' $S/${TAG}_pv.out | awk '{print $1}')
  timing=$(echo "$failed" | grep -xE 'frames|play|progress|placing|grab|drag_cost' || true)
  ran=$(grep -cE ' exit=' $S/${TAG}_pv.out)
  if [ -z "$timing" ] && [ -n "$failed" ] && [ "$ran" -eq $# ]; then
    for name in $failed; do
      echo "SHIP: $name failed beside others; once more, alone"
      # Through run_checks, which clears the answer first: a run that died
      # before writing one would leave the last attempt's pass to be read.
      run_checks "$URL" ${TAG}_alone_$name $name >/dev/null 2>&1
      cut -c1-160 $S/${TAG}_alone_$name.out | head -1
      passed $S/${TAG}_alone_$name.out 1 || { echo "SHIP: held, $name failed alone too"; exit 1; }
    done
    echo "SHIP: every check that failed beside others passed alone"
  else
    echo "SHIP: held, a check failed or did not run on the preview"; exit 1
  fi
fi
# A hold set by hand stops a release here, before main moves, even one
# already under way: $S/HOLD for every release, $S/<tag>.hold for this one.
# Stopping the waiter that queued it does not stop a ship already started:
# m50 went out with a regression the session thought it had held (2026-10-17).
for hold in "$S/HOLD" "$S/${TAG}.hold"; do
  [ -e "$hold" ] && { echo "SHIP: held by $hold ($(cat "$hold" 2>/dev/null))"; exit 1; }
done
git -C $R merge --ff-only "$SHA" >/dev/null && env -u GITHUB_TOKEN git -C $R push -q origin main || { echo "SHIP: could not fast-forward or push main"; exit 1; }
echo "SHIP: main is $SHA, authors: $(git -C $R log --since='1 day ago' --format='%an <%ae>' | sort | uniq -c | tr '\n' ' ')"
timeout 3000 ~/.claude/claude-core/bin/heavy tools/deploy.sh --prod > $S/${TAG}_prod.log 2>&1
deployed=$?
grep -E "serves|deploy FAILED" $S/${TAG}_prod.log | sed 's/^/SHIP: /'
# A failed deploy is a failed ship. m174's lost one size of its start check
# to a timed-out connection, was never promoted, and still wrote done 0: its
# live checks passed against m173, and m175's ship began on top of it
# (2026-10-26).
if [ $deployed -ne 0 ]; then
  echo "SHIP: main is $SHA but production is not (deploy exit $deployed): deploy it again with tools/deploy.sh --prod"
  exit 1
fi
# The CDN keeps serving the last pages for a minute or so after the promotion.
sleep 90
# And the live checks go on only against this build.
serves() { curl -s --max-time 30 https://brickworks.diy/app | grep -q "/b/$SHA/"; }
serves || { sleep 120; serves; } || {
  echo "SHIP: deployed, but https://brickworks.diy/app does not serve /b/$SHA/"; exit 1; }
# canary: sign-up still shut and a new person still signs in by a code, on
# production's own route and settings (api/_canary.js, 2026-10-24).
# Cleared first, as run_checks clears: an attempt before may have left its own.
rm -f $S/${TAG}_live.out $S/${TAG}_live2.out
"$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_live site share_probe canary
if ! passed $S/${TAG}_live.out 3; then sleep 120; "$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_live2 site share_probe canary; cat $S/${TAG}_live2.out | cut -c1-160; else cat $S/${TAG}_live.out | cut -c1-160; fi
