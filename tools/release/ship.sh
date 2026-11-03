#!/bin/bash
# ship.sh WORKTREE TAG CHECK... : a release from a staging worktree.
# Preview deploy, the browser checks named, and only if every one passes
# (or fails on brickworks.diy too, where a train accepts it: SHIP_ACCEPT),
# and every probe a train runs beside it (SHIP_PROBES): main fast-forwarded
# and pushed, that very preview promoted, the live site checked. Release
# jobs take BOX_HEAVY_PRIORITY, as other projects' do.
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
# Stopped, it did not ship: without these the EXIT trap wrote the status of
# the command the signal cut short, 0, and a waiter read a stopped m185 as
# shipped (2026-10-27).
trap 'exit 129' HUP; trap 'exit 130' INT; trap 'exit 143' TERM
export BOX_HEAVY_PRIORITY=1
# A train runs the release's probes beside its ship (train.sh) and names in
# SHIP_PROBES the file it keeps while they run: "running PID: NAMES", then
# "failed: NAMES", gone once every one has passed. Main never moves while
# it is there. A ship begun by hand names none and waits for none.
probes_failed() {
  local st; st=$(cat "${SHIP_PROBES:-/nonexistent}" 2>/dev/null) || return 1
  case "$st" in failed:*) echo "SHIP: held, the probes failed:${st#failed:}"; return 0 ;; esac
  return 1
}
# The preview and its checks, as unit_preview.sh makes and runs them.
. "$HERE/preview_lib.sh" SHIP || exit 1
cd "$W" || exit 1
if [ -e "$(git rev-parse --git-dir)/merging" ]; then echo "SHIP: a merge in $W is still running its gates"; exit 1; fi
SHA=$(git rev-parse --short HEAD)
git -C $R merge-base --is-ancestor main "$SHA" || { echo "SHIP: $SHA does not contain main"; exit 1; }
unwired=$(unwired_flows main)
[ -z "$unwired" ] || { echo "SHIP: held, a new flow no check runs:$unwired (name it in preview_checks.sh, or mark it there '# local only: NAME')"; exit 1; }
# Every download the page and the changelog link to answers, in seconds: a
# file that 404s fails only the person who clicked it. A manifest naming a
# repository that does not exist yet, or a source repository made private,
# breaks them all at once (the releases' move to Xaxis/brickworks-releases,
# 2026-10-27).
"$HERE/release_links.sh" "$W/web/releases.json" > "$S/${TAG}_links.out" 2>&1 \
  || { echo "SHIP: held, a download link does not answer (release_links.sh)"; grep FAIL "$S/${TAG}_links.out" | head -3; exit 1; }
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
  probes_failed && exit 1
  deploy_preview "$TAG" "$SHA" || exit 1
fi
probes_failed && exit 1
run_checks "$URL" ${TAG}_pv "$@" || exit 1
cut -c1-160 $S/${TAG}_pv.out
probes_failed && exit 1
# A check that failed in the battery, two at a time beside other previews'
# batteries, runs once more alone before the release holds. m162's oc, and
# m164's oc and cloud_library, each stalled under load and passed alone on
# the same deployment (2026-10-24), and each time the rerun was done by
# hand. Each one does, whatever else failed: one timing check among rel-m249's
# five kept keys, library, model_page and together from theirs, and the lead
# reshipped them by hand (2026-11-02). Timing checks never get a second go:
# alone they would pass what the load showed. One that wrote no line gets
# its first. Both answers are kept: TAG_pv.out keeps the first, and
# TAG_alone_NAME.out the second.
still=""; again=""
for name in "$@"; do
  line=$(grep -m1 "^$name exit=" $S/${TAG}_pv.out)
  case "$line" in *" exit=0 "*) continue ;; esac
  if [ -z "$line" ]; then
    echo "SHIP: $name did not run; once, alone"
  else
    case "$name" in frames|play|progress|placing|grab) still="$still $name"; continue ;; esac
    echo "SHIP: $name failed beside others; once more, alone"
  fi
  probes_failed && exit 1
  # Through run_checks, which clears the answer first: a run that died
  # before writing one would leave the last attempt's pass to be read.
  run_checks "$URL" ${TAG}_alone_$name $name >/dev/null 2>&1
  cut -c1-160 $S/${TAG}_alone_$name.out | head -1
  again=1
  passed $S/${TAG}_alone_$name.out 1 || still="$still $name"
done
[ -n "$again" ] && [ -z "$still" ] && echo "SHIP: every check that failed beside others passed alone"
# The release is done with the live database until it is live: the train's
# mark goes, and units take it in their turn again (live_db_lib.sh). Left
# until each train ended, the marks kept units off it for all but an hour
# of the sixteen from rel-m247's staging on, and 13 of their checks gave up
# after an hour each (2026-11-02).
[ -n "${SHIP_LIVE_MARK:-}" ] && rm -f "$SHIP_LIVE_MARK"
# What still fails here runs on brickworks.diy as it is, as a unit's check
# would: no release's priority at the lock or for a slot. A train staged
# runs it (SHIP_STALE). Every check named used to run there from the
# train's staging, beside the preview's battery: rel-m249's 74, ten hours
# of checks, at load 43 on 24 cores, and its preview's checks waited three
# hours for the lock behind them, to say which of the five that failed on
# its preview already failed there (2026-11-02).
# TAG_stale.failing: those that ran there and failed, as the same script
# (live's build has it unchanged), which a train may ship past
# (SHIP_ACCEPT: CHECK<TAB>REASON lines).
if [ -n "$still" ] && [ -n "${SHIP_STALE:-}" ]; then
  still=${still# }
  echo "SHIP: failed here: $still; each runs on brickworks.diy as it is now"
  rm -f $S/${TAG}_stale.{out,failing}
  echo "$still" > $S/${TAG}_stale.asked
  built=$(curl -s --max-time 20 https://brickworks.diy/app | grep -o '/b/[^/"]*/' | head -1)
  echo "$built" > $S/${TAG}_stale.build; built=${built#/b/}; built=${built%/}
  for name in $still; do
    script=$(sed -n "s/^[[:space:]]*\[$name\]=\"\([^ \"]*\).*/\1/p" tools/release/preview_checks.sh | head -1)
    [ -n "$script" ] && [ -n "$built" ] && git cat-file -e "$built^{commit}" 2>/dev/null \
      && ! git diff --quiet "$built" HEAD -- "$script" 2>/dev/null && echo "$name"
  done > $S/${TAG}_stale.changed
  env -u BOX_HEAVY_PRIORITY "$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_stale $still >/dev/null 2>&1
  for name in $still; do
    case "$(grep -m1 "^$name exit=" $S/${TAG}_stale.out)" in
      ""|*" exit=0 "*|*" exit=75 "*|*" exit=125 "*|*" exit=127 "*) ;;
      *) grep -qx "$name" $S/${TAG}_stale.changed || echo "$name" ;;
    esac
  done > $S/${TAG}_stale.failing
  held=""
  for name in $still; do
    why=$(awk -F'\t' -v n="$name" '$1 == n {print $2; exit}' "${SHIP_ACCEPT:-/dev/null}" 2>/dev/null)
    if [ -n "$why" ] && grep -qx "$name" $S/${TAG}_stale.failing; then
      here=$(grep -m1 "^$name exit=" $S/${TAG}_alone_$name.out 2>/dev/null || grep -m1 "^$name exit=" $S/${TAG}_pv.out)
      printf '%s: %s\n  here: %s\n  there: %s\n' "$name" "$why" "$(cut -c1-200 <<< "$here")" \
        "$(grep -m1 "^$name exit=" $S/${TAG}_stale.out | cut -c1-200)" >> $S/${TAG}_accepted
      echo "SHIP: ships past $name, which fails on brickworks.diy too: $why"
    else
      held="$held $name"
    fi
  done
  there=$(grep -xF -f $S/${TAG}_stale.failing <<< "$(tr ' ' '\n' <<< "${held# }")" | paste -sd' ')
  [ -z "$held" ] || { echo "SHIP: held, failed on the preview:$held${there:+ (failing on brickworks.diy too: $there)}"; exit 1; }
elif [ -n "$still" ]; then
  echo "SHIP: held, failed on the preview:$still"; exit 1
fi
# The train's probes, until every one has passed. The train's pid is in
# the file: one gone with no answer holds the release, where a train
# killed outright would otherwise leave this waiting for SHIP_PROBES_WAIT.
if [ -n "${SHIP_PROBES:-}" ]; then
  until=$(( $(date +%s) + ${SHIP_PROBES_WAIT:-10800} )); said=""
  while [ -e "$SHIP_PROBES" ]; do
    probes_failed && exit 1
    pid=$(sed -n 's/^running \([0-9]*\):.*/\1/p' "$SHIP_PROBES" 2>/dev/null)
    if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
      sleep 1  # its answer, written as it ended
      [ -e "$SHIP_PROBES" ] || break
      probes_failed && exit 1
      echo "SHIP: held, the train running the probes (pid $pid) is gone, with no answer"; exit 1
    fi
    [ "$(date +%s)" -lt "$until" ] || { echo "SHIP: held, the probes ran past SHIP_PROBES_WAIT"; exit 1; }
    [ -n "$said" ] || { said=1; echo "SHIP: the checks passed; main waits for the probes ($(cut -d: -f2- "$SHIP_PROBES" | wc -w) named)"; }
    sleep "${SHIP_POLL:-10}"
  done
  echo "SHIP: every probe passed"
fi
# A hold set by hand stops a release here, before main moves, even one
# already under way: $S/HOLD for every release, $S/<tag>.hold for this one.
# Stopping the waiter that queued it does not stop a ship already started:
# m50 went out with a regression the session thought it had held (2026-10-17).
for hold in "$S/HOLD" "$S/${TAG}.hold"; do
  [ -e "$hold" ] && { echo "SHIP: held by $hold ($(cat "$hold" 2>/dev/null))"; exit 1; }
done
# Godot's import makes a .uid beside each script with none. One the release
# now carries, made here untracked, would stop the fast-forward; the
# release's wins, as in merge_unit.sh (stage223's 106, 2026-10-30).
for f in $(git -C $R diff --name-only main "$SHA" -- '*.uid'); do
  if [ -f "$R/$f" ] && ! git -C $R ls-files --error-unmatch "$f" >/dev/null 2>&1; then rm "${R:?}/${f:?}"; fi
done
git -C $R merge --ff-only "$SHA" >/dev/null && env -u GITHUB_TOKEN git -C $R push -q origin main || { echo "SHIP: could not fast-forward or push main"; exit 1; }
# The main checkout's scripts moved, its class list did not: a bench run
# from it drew no pictures ("TouchSizing not declared", 2026-10-27). Its
# import takes 10+ minutes, so it runs beside the deploy, not before it.
(cd "$R" && setsid nohup bash tools/fresh_import.sh > "$S/${TAG}_main_import.log" 2>&1 &)
echo "SHIP: main is $SHA, authors: $(git -C $R log --since='1 day ago' --format='%an <%ae>' | sort | uniq -c | tr '\n' ' ')"
# The build the checks passed goes live itself (deploy.sh --promote): the
# preview is a production build no domain points at yet. m214 waited
# minutes more on deploy.sh --prod, which built, uploaded and checked the
# same commit again, and the lead promoted the preview by hand (2026-10-30).
# Never a unit's preview, which lacks secrets production needs: this one
# was made above without --unit, or is this TAG's own, reused, whose log
# would say so. Should the promotion not go, production is deployed afresh,
# as it was before.
: > "$S/${TAG}_prod.log"
deployed=0
# What the domain will serve: the preview's own commit, before SHA when only
# checks changed since (reused_preview), or SHA built afresh.
LIVE=${PREVIEW_MADE:-$SHA}
if grep -q "a unit's preview" "$S/${TAG}_preview.log" \
    || ! SHIP_DEPLOY=1 timeout 900 tools/deploy.sh --promote="$URL" >> "$S/${TAG}_prod.log" 2>&1; then
  echo "SHIP: $URL not promoted; deploying production afresh"
  LIVE=$SHA
  SHIP_DEPLOY=1 timeout 10800 ~/.claude/claude-core/bin/heavy timeout 3000 tools/deploy.sh --prod >> "$S/${TAG}_prod.log" 2>&1
  deployed=$?
fi
grep -E "serves|deploy FAILED" $S/${TAG}_prod.log | sed 's/^/SHIP: /'
# A failed deploy is a failed ship. m174's lost one size of its start check
# to a timed-out connection, was never promoted, and still wrote done 0: its
# live checks passed against m173, and m175's ship began on top of it
# (2026-10-26).
if [ $deployed -ne 0 ]; then
  echo "SHIP: main is $SHA but production is not (deploy exit $deployed): deploy it again with PROD_BY_HAND=\"$TAG's deploy failed\" tools/deploy.sh --prod"
  exit 1
fi
# The CDN keeps serving the last pages for a minute or so after the promotion.
sleep "${SHIP_CDN_WAIT:-90}"
# And the live checks go on only against this build.
serves() { curl -s --max-time 30 https://brickworks.diy/app | grep -q "/b/$LIVE/"; }
serves || { sleep 120; serves; } || {
  echo "SHIP: deployed, but https://brickworks.diy/app does not serve /b/$LIVE/"; exit 1; }
# canary: sign-up still shut and a new person still signs in by a code, on
# production's own route and settings (api/_canary.js, 2026-10-24).
# Cleared first, as run_checks clears: an attempt before may have left its own.
rm -f $S/${TAG}_live.out $S/${TAG}_live2.out
"$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_live site share_probe canary
if ! passed $S/${TAG}_live.out 3; then sleep 120; "$HERE/preview_checks.sh" https://brickworks.diy "$W" ${TAG}_live2 site share_probe canary; cat $S/${TAG}_live2.out | cut -c1-160; else cat $S/${TAG}_live.out | cut -c1-160; fi
