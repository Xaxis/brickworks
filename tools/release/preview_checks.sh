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
  [booklet]="tools/web/booklet_flow.mjs --url=$P/app --out=$S/${TAG}_booklet_web"
  [flex_pose]="tools/web/flex_pose_flow.mjs --url=$P/app $B --out=$S/${TAG}_flex_pose_web"
  [grab]="tools/web/grab_flow.mjs --url=$P/app $B --out=$S/${TAG}_grab_web"
  [progress]="tools/web/progress_check.mjs --url=$P/app"
  [share_probe]="tools/web/share_probe.mjs --url=$P"
  [site]="tools/web/site_check.mjs --url=$P"
  [download]="tools/web/download_check.mjs --url=$P/download"
  [tabs]="tools/web/tabs_flow.mjs --url=$P/app --out=$S/${TAG}_tabs"
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
  [placing]="tools/web/placing_flow.mjs --url=$P/app $B --out=$S/${TAG}_placing_web"
  [flex_skin]="tools/web/flex_skin_flow.mjs --url=$P/app $B --out=$S/${TAG}_flex_skin_web $R/vendor/omr/files/8202-1.mpd"
  [brickify]="tools/web/brickify_flow.mjs --url=$P/app --out=$S/${TAG}_brickify_web"
  [brickify_fox]="tools/web/brickify_flow.mjs --url=$P/app --model=tests/fixtures/brickify/fox.obj --studs=24 --least=60 --says=stand --out=$S/${TAG}_brickify_fox_web"
)
ORDER="art io steps floor outline knowledge arrival idle cursor share_flow booklet flex_pose grab progress share_probe site download"
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
# frames for 7 moves, and 16 every time alone (2026-10-13).
SOLO=" idle arrival progress cursor "
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
