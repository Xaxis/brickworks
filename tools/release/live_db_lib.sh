# shellcheck shell=bash
# live_db_lib.sh: the live database's one lock, sourced by preview_checks.sh
# and live_db.sh from inside a worktree.
# Checks on the live site make and delete real accounts, and sign in as them
# and all they do as that account between. Two runs at once collided on
# 2026-10-22: 429s in profile, and another run's model took discovery's
# pick. So each takes one lock for the whole machine, whichever battery it
# is in (a release's, a unit's unit_preview.sh): a file in the repository's
# git folder, which every worktree shares. live-db.log beside it says who
# took it and left it, and when.
LIVE_DB="$(git rev-parse --path-format=absolute --git-common-dir)/live-db"
# A release's check goes first. flock serves no one in order, and a unit's
# A/B of together runs, taking the lock run after run, held rel-m232's
# arrival for 24 minutes (2026-10-31). So a release's battery, waiting,
# leaves a file named for its pid in live-db.release, as its train does
# until its battery on the preview is done (train.sh run, ship.sh), and any
# other run that gets the lock while one is there hands it back and waits.
# The release's own battery (BOX_HEAVY_PRIORITY) takes it. What failed on
# its preview then runs on brickworks.diy as a unit's checks do (ship.sh,
# SHIP_STALE): given a release's turn, rel-m249's 72 checks there, from its
# staging, took the lock as often as its preview's did (2026-11-02).
release_waits() {
  local f
  for f in "$LIVE_DB.release"/*; do
    [ -e "$f" ] && waiting "$f" "${f##*/}" && return 0
  done
  return 1
}
# A mark or a ticket holds its process's start time. One whose process is
# gone, or whose pid now names another process, is removed when seen: a run
# killed whole never runs its trap, and its pid, reused, would be read as a
# run still waiting, holding every later one until that stranger exits. 17
# were left by units' killed runs by 2026-11-04. An empty one (train.sh's
# mark, or one from before this) is judged by its pid alone.
started() {
  local stat
  stat=$(cat "/proc/$1/stat" 2>/dev/null) || return 1
  stat=${stat##*) }
  # shellcheck disable=SC2086
  set -- $stat
  echo "${20}"
}
waiting() {
  local was now
  if now=$(started "$2"); then
    was=$(cat "$1" 2>/dev/null) || return 1
    { [ -z "$was" ] || [ "$was" = "$now" ]; } && return 0
  fi
  rm -f -- "$1"
  return 1
}
# The rest take it in the order they came. Each waits with a ticket in
# live-db.queue named for when it came and its pid, and one that gets the
# lock while an older living ticket is there hands it back too. Without it,
# a unit's together runs, 35 minutes each, took the lock again and again
# while connect3's runs waited 91 minutes and two gave up (2026-11-01).
older_waits() {
  local f
  for f in "$LIVE_DB.queue"/*; do
    [ -e "$f" ] || continue
    [[ "${f##*/}" < "$1" ]] && waiting "$f" "${f##*.}" && return 0
  done
  return 1
}
take_live_db() {
  local lock="$1" until=$(( $(date +%s) + ${LIVE_WAIT:-3600} )) mine="" ticket="" left
  if [ "${BOX_HEAVY_PRIORITY:-}" = 1 ]; then
    mkdir -p "$LIVE_DB.release"; mine="$BASHPID"; started "$mine" > "$LIVE_DB.release/$mine"
  else
    mkdir -p "$LIVE_DB.queue"; ticket="$(date +%s%N).$BASHPID"
    started "$BASHPID" > "$LIVE_DB.queue/$ticket"
  fi
  while left=$(( until - $(date +%s) )); [ "$left" -gt 0 ] && flock -w "$left" "$lock"; do
    if [ -n "$mine" ] || { ! release_waits && ! older_waits "$ticket"; }; then
      [ -n "$mine" ] && rm -f "${LIVE_DB:?}.release/${mine:?}"
      [ -n "$ticket" ] && rm -f "${LIVE_DB:?}.queue/${ticket:?}"
      return 0
    fi
    flock -u "$lock"; sleep 2
  done
  [ -n "$mine" ] && rm -f "${LIVE_DB:?}.release/${mine:?}"
  [ -n "$ticket" ] && rm -f "${LIVE_DB:?}.queue/${ticket:?}"
  return 1
}
