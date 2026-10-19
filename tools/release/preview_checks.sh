#!/usr/bin/env bash
# preview_checks.sh ORIGIN WORKTREE TAG [NAME...] : chosen browser checks
# against a preview, two at a time; all of them when no names are given.
# Results: $S/TAG.out, one line a check; logs $S/TAG_NAME.log.
# Run from a copy: bash reads a script as it goes, so an edit made while a
# battery ran broke it at line 55 and the timing checks never ran.
if [ -z "${PC_COPY:-}" ]; then
  copy=$(mktemp "${TMPDIR:-/tmp}/preview_checks.XXXXXX.sh"); cp "$0" "$copy"
  RELEASE_HERE=$(cd "$(dirname "$0")" && pwd) PC_COPY=1 exec bash "$copy" "$@"
fi
P="$1"; WT="$2"; TAG="$3"; shift 3
cd "$WT" || exit 1
S=${RELEASE_OUT:-${TMPDIR:-/tmp}/brickworks-release}; mkdir -p "$S"
R=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")
set -a; . "$R/.env"; set +a
H=~/.claude/claude-core/bin/heavy
export BW_BYPASS="$VERCEL_BYPASS"; B="--bypass=$VERCEL_BYPASS"
declare -A CMD=(
  [art]="tools/web/art_flow.mjs --url=$P/app $B --out=$S/${TAG}_art_web"
  [io]="tools/web/io_flow.mjs --url=$P/app $B --out=$S/${TAG}_io_web"
  [steps]="tools/web/steps_flow.mjs --url=$P/app $B --out=$S/${TAG}_steps_web"
  [floor]="tools/web/floor_flow.mjs --url=$P/app $B --out=$S/${TAG}_floor_web"
  [outline]="tools/web/outline_check.mjs --url=$P/app $B"
  [knowledge]="tools/web/knowledge_check.mjs --url=$P/app $B"
  [arrival]="tools/web/arrival_check.mjs --url=$P/app"
  [idle]="tools/web/idle_check.mjs --url=$P/app"
  [cursor]="tools/web/cursor_check.mjs --url=$P/app $B"
  [share_flow]="tools/web/share_flow.mjs --url=$P/app --out=$S/${TAG}_share_web"
  [versions]="tools/web/versions_flow.mjs --url=$P --out=$S/${TAG}_versions"
  [age]="tools/web/age_flow.mjs --url=$P --out=$S/${TAG}_age"
  [comments]="tools/web/comments_flow.mjs --url=$P --out=$S/${TAG}_comments"
  [tested]="tools/web/tested_flow.mjs --url=$P --out=$S/${TAG}_tested"
  [digest]="tools/web/digest_flow.mjs --url=$P --out=$S/${TAG}_digest"
  [builds]="tools/web/builds_flow.mjs --url=$P --out=$S/${TAG}_builds"
  [follows]="tools/web/follows_flow.mjs --url=$P --out=$S/${TAG}_follows"
  # Top builds, this week's pick and small builds, and the owner's choice of
  # the pick on /admin: API routes only, with the bypass (supabase/discovery.sql).
  [discovery]="tools/web/discovery_flow.mjs --url=$P --out=$S/${TAG}_discovery"
  # A designer's page (what their models earned) and their own numbers, for
  # them alone and never cached: API routes only, with the bypass
  # (supabase/designers.sql).
  [designers]="tools/web/designers_flow.mjs --url=$P --out=$S/${TAG}_designers"
  [booklet]="tools/web/booklet_flow.mjs --url=$P/app --out=$S/${TAG}_booklet_web"
  # The booklet edited by hand: a set's steps turned, zoomed, paged, merged
  # and undone by the timeline's buttons and keys, a page laid out by the
  # mouse (a picture dragged onto the margin, a parts list's corner, words
  # and a picture added); its booklet and file say so.
  [booklet_edit]="tools/web/booklet_edit_flow.mjs --url=$P/app $B --model=$R/vendor/omr/files/106-1.mpd --out=$S/${TAG}_booklet_edit_web"
  [flex_pose]="tools/web/flex_pose_flow.mjs --url=$P/app $B --out=$S/${TAG}_flex_pose_web"
  [grab]="tools/web/grab_flow.mjs --url=$P/app $B --out=$S/${TAG}_grab_web"
  [progress]="tools/web/progress_check.mjs --url=$P/app"
  [share_probe]="tools/web/share_probe.mjs --url=$P"
  [site]="tools/web/site_check.mjs --url=$P"
  # Every page and dialog, each visible control judged against the design
  # system's tokens (web/site.css, docs/DESIGN_SYSTEM.md); the API answered
  # by its stand-in, so no account is made.
  [design]="tools/web/design_flow.mjs --url=$P --out=$S/${TAG}_design"
  [download]="tools/web/download_check.mjs --url=$P/download"
  [tabs]="tools/web/tabs_flow.mjs --url=$P/app --out=$S/${TAG}_tabs"
  # Two chats, two tabs: the relay's rules alone, then the app in two tabs.
  [tabpair_probe]="tools/web/tabpair_probe.mjs --url=$P"
  [tabpair]="tools/web/tabpair_flow.mjs --url=$P/app --out=$S/${TAG}_tabpair"
  [people]="tools/web/people_flow.mjs --url=$P --out=$S/${TAG}_people"
  [moderation]="tools/web/moderation_flow.mjs --url=$P --out=$S/${TAG}_moderation"
  [reload]="tools/web/reload_flow.mjs --url=$P/app $B --out=$S/${TAG}_reload"
  [keep]="tools/web/keep_flow.mjs --url=$P/app $B --out=$S/${TAG}_keep"
  [decor]="tools/web/decor_flow.mjs --url=$P/app --out=$S/${TAG}_decor"
  [model_view]="tools/web/model_view_check.mjs --url=$P/app --out=$S/${TAG}_model_view"
  # ext-apps' basic-host, built: BW_APP_HOST names its examples/basic-host.
  [app_host]="tools/web/app_host_check.mjs --url=$P/app --host=${BW_APP_HOST:-} --out=$S/${TAG}_app_host"
  [focus]="tools/web/focus_check.mjs --url=$P/app $B --out=$S/${TAG}_focus"
  [list_changed]="tools/web/list_changed_check.mjs --url=$P $B"
  [noai]="tools/web/noai_flow.mjs --url=$P/app --relay $B --out=$S/${TAG}_noai"
  [oauth]="tools/web/oauth_flow.mjs --url=$P/app $B"
  [technic]="tools/web/technic_flow.mjs --url=$P/app $B --out=$S/${TAG}_technic"
  [assembly]="tools/web/assembly_flow.mjs --url=$P/app $B --out=$S/${TAG}_assembly_web"
  [sections]="tools/web/sections_flow.mjs --url=$P/app $B --out=$S/${TAG}_sections_web"
  [placing]="tools/web/placing_flow.mjs --url=$P/app $B --out=$S/${TAG}_placing_web"
  [flex_skin]="tools/web/flex_skin_flow.mjs --url=$P/app $B --out=$S/${TAG}_flex_skin_web $R/vendor/omr/files/8202-1.mpd"
  # A set's carried parts drawn from LDraw's own subparts, fetched from the
  # parts bucket as it opens (tools/storage_ldraw.py must have run).
  [carried]="tools/web/carried_flow.mjs --url=$P/app $B --label=preview --out=$S/${TAG}_carried_web $R/vendor/omr/files/21321-1.mpd"
  [brickify]="tools/web/brickify_flow.mjs --url=$P/app --out=$S/${TAG}_brickify_web"
  [brickify_fox]="tools/web/brickify_flow.mjs --url=$P/app --model=tests/fixtures/brickify/fox.obj --studs=24 --least=60 --says=on.a.stand --out=$S/${TAG}_brickify_fox_web"
  # What a frame costs the app on a big model (75969-1, 925 parts): each press
  # of the timeline's Next and an orbit's frames held to 200 ms of the app's
  # own work, select all to 400 (cad_frames --gate). steps_flow checks what
  # a step shows, not
  # what it costs: the grab's drag handles, found twice a second, took a step
  # from 75 ms to 6.7 s and every check passed (CADTASK.md, section 6).
  [frames]="tools/web/cad_frames.mjs --url=$P/app $B --gate --arrive=300 --only=orbit,select_all,step --out=$S/${TAG}_frames_web $R/vendor/omr/files/75969-1.mpd"
  # Render's first open in a fresh browser, every frame timed: alone, below.
  [render_open]="tools/web/render_open_check.mjs --url=$P/app --out=$S/${TAG}_render_open"
  # Build it from a shared link on a slowed phone: each page turn timed, and
  # the first step's arrival; publishes from a throwaway account, deleted after.
  # A shared link built on a throttled phone: every step and turn timed and
  # said; until the steps are carried with the link (sharesteps, round 2),
  # the first step takes 9-12 s, so the times are said, not held to a bar.
  [share_steps]="tools/web/share_steps_flow.mjs --url=$P --publish --report-only --sizes=300,1000 --out=$S/${TAG}_share_steps"
)
ORDER="art io steps floor outline knowledge arrival idle cursor share_flow booklet booklet_edit flex_pose grab progress share_probe site design download frames"
NAMES="${*:-$ORDER}"
run() {
  local name="$1" t0=$(date +%s)
  # A name not in the map ran bare node, which exits 0 at once: technic
  # "passed" in 0 s without running (2026-10-13).
  if [ -z "${CMD[$name]:-}" ]; then echo "$name exit=127 fails=1 0s :: FAIL no such check" >> "$S/$TAG.out"; return; fi
  # The limit is on the check, inside heavy: around heavy it counted the wait
  # for a slot, and at load 50 tabs and keep ran out queued, never run.
  "$H" timeout 2700 node ${CMD[$name]} > "$S/${TAG}_$name.log" 2>&1
  local code=$?
  echo "$name exit=$code fails=$(grep -c 'FAIL' "$S/${TAG}_$name.log") $(( $(date +%s) - t0 ))s :: $(grep -vE '^\s*$' "$S/${TAG}_$name.log" | tail -1 | cut -c1-200)" >> "$S/$TAG.out"
}
: > "$S/$TAG.out"
# Timing checks run alone: beside a heavy flow, idle's ghost drew 4 or 6
# frames for 7 moves, and 16 every time alone (2026-10-13). grab times the
# page's longest wait in a drag: paired, the four-bar's read 551 ms (m54).
# frames holds the app's own work a frame on 75969-1 (200 ms, select all 400).
SOLO=" idle arrival progress cursor render_open grab share_steps frames "
PAIRED=""; ALONE=""
for n in $NAMES; do case "$SOLO" in *" $n "*) ALONE="$ALONE $n";; *) PAIRED="$PAIRED $n";; esac; done
set -- $PAIRED
while [ $# -gt 0 ]; do
  run "$1" & shift
  if [ $# -gt 0 ]; then run "$1" & shift; fi
  wait
done
for n in $ALONE; do run "$n"; done
echo done >> "$S/$TAG.out"
