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
# leaves a file named for its pid in live-db.release, as its train does for
# as long as it runs (train.sh run), and any other run that gets the lock
# while one is there hands it back and waits. The release's own (its
# battery, BOX_HEAVY_PRIORITY; its checks on the live site, LIVE_DB_RELEASE)
# take it.
release_waits() {
  local f
  for f in "$LIVE_DB.release"/*; do
    [ -e "$f" ] && kill -0 "${f##*/}" 2>/dev/null && return 0
  done
  return 1
}
take_live_db() {
  local lock="$1" until=$(( $(date +%s) + ${LIVE_WAIT:-3600} )) mine="" left
  if [ "${BOX_HEAVY_PRIORITY:-}" = 1 ]; then
    mkdir -p "$LIVE_DB.release"; mine="$BASHPID"; : > "$LIVE_DB.release/$mine"
  fi
  while left=$(( until - $(date +%s) )); [ "$left" -gt 0 ] && flock -w "$left" "$lock"; do
    if [ -n "$mine" ] || [ "${LIVE_DB_RELEASE:-}" = 1 ] || ! release_waits; then
      [ -n "$mine" ] && rm -f "${LIVE_DB:?}.release/${mine:?}"
      return 0
    fi
    flock -u "$lock"; sleep 2
  done
  [ -n "$mine" ] && rm -f "${LIVE_DB:?}.release/${mine:?}"
  return 1
}
