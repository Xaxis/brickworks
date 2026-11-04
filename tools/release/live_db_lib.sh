# shellcheck shell=bash
# live_db_lib.sh: the live database's lock, sourced by preview_checks.sh
# and live_db.sh from inside a worktree.
# Checks on the live site make and delete real accounts, and sign in as them
# and all they do as that account between. Two runs at once collided on
# 2026-10-22: 429s in profile, and another run's model took discovery's
# pick. So each took one lock for the whole machine, whichever battery it
# is in (a release's, a unit's unit_preview.sh): files in the repository's
# git folder, which every worktree shares. live-db.log beside them says who
# took it and left it, how, and when.
# Those were particular collisions. Since the day after, a flow's sessions
# are signed in by password (session.mjs), from a bucket of 30 at once and
# then one every 2 s, which a battery's 53 live checks draw on about 180
# times in all, 12 at once at most. Every flow makes accounts of its own and
# judges its own models by id, but for the few in preview_checks.sh's
# ALONE_DB, which read what every account changes (the week's pick, the one
# test challenge). Held one at a time, rel-m254's 53 held the lock for 3.1
# hours, and four units waiting behind it gave up after three (2026-11-03).
# So LIVE_DB_SLOTS (3) hold it at once, each with one of the files
# live-db.slot.N under a shared hold of live-db.lock; a check that must run
# with no other holds live-db.lock alone. A run of the scripts from before
# this holds live-db.lock alone too, so the two never meet.
LIVE_DB="$(git rev-parse --path-format=absolute --git-common-dir)/live-db"
LIVE_DB_SLOTS=${LIVE_DB_SLOTS:-3}
[ "$LIVE_DB_SLOTS" -ge 1 ] 2>/dev/null || LIVE_DB_SLOTS=1
# A release's check goes first. flock serves no one in order, and a unit's
# A/B of together runs, taking the lock run after run, held rel-m232's
# arrival for 24 minutes (2026-10-31). So a release's battery, waiting,
# leaves a ticket in live-db.release, as its train leaves a mark named for
# its pid until its battery on the preview is done (train.sh run, ship.sh),
# and no other run takes the lock while one is there. The release's own
# battery (BOX_HEAVY_PRIORITY) takes it. What failed on its preview then
# runs on brickworks.diy as a unit's checks do (ship.sh, SHIP_STALE): given
# a release's turn, rel-m249's 72 checks there, from its staging, took the
# lock as often as its preview's did (2026-11-02).
release_waits() {
  local f n
  for f in "$LIVE_DB.release"/*; do
    n=${f##*/}
    [ -e "$f" ] && waiting "$f" "${n##*.}" && return 0
  done
  return 1
}
# A mark or a ticket holds its process's start time. One whose process is
# gone, or whose pid now names another process, is removed when seen: a run
# killed whole never runs its trap, and its pid, reused, would be read as a
# run still waiting, holding every later one until that stranger exits. 17
# were left by units' killed runs by 2026-11-04. An empty one (a train's
# mark from before this) is judged by its pid alone.
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
# The rest take it in the order they came, and so do a release's own among
# themselves. Each waits with a ticket named for when it came and its pid
# (in live-db.queue, or a release's in live-db.release), and only the first
# living one of its line takes a slot: then one that must be alone, waiting
# for the slots to empty, is not passed by those that came after it.
# Without it, a unit's together runs, 35 minutes each, took the lock again
# and again while connect3's runs waited 91 minutes and two gave up
# (2026-11-01).
older_waits() {
  local f n
  for f in "${2:-$LIVE_DB.queue}"/*.*; do
    [ -e "$f" ] || continue
    n=${f##*/}
    [[ "$n" < "$1" ]] && waiting "$f" "${n##*.}" && return 0
  done
  return 1
}
# take_live_db [alone]: a slot of the live database, or with "alone" all of
# it, waiting LIVE_WAIT seconds (an hour) at most. Held by LIVE_DB_HOLD and
# LIVE_DB_SLOT, open in this shell, until leave_live_db; LIVE_DB_HOW says
# which, for live-db.log.
take_live_db() {
  local alone="${1:-}" until=$(( EPOCHSECONDS + ${LIVE_WAIT:-3600} )) line=queue ticket i fd
  [ "${BOX_HEAVY_PRIORITY:-}" = 1 ] && line=release
  mkdir -p "$LIVE_DB.$line"; ticket="$(date +%s%N).$BASHPID"
  started "$BASHPID" > "$LIVE_DB.$line/$ticket"
  exec {LIVE_DB_HOLD}>>"$LIVE_DB.lock"
  LIVE_DB_SLOT=""; LIVE_DB_HOW=""
  while [ "$EPOCHSECONDS" -lt "$until" ]; do
    if { [ $line = release ] && ! older_waits "$ticket" "$LIVE_DB.release"; } \
        || { [ $line = queue ] && ! release_waits && ! older_waits "$ticket"; }; then
      if [ -n "$alone" ]; then
        flock -x -n "$LIVE_DB_HOLD" && LIVE_DB_HOW="alone"
      elif flock -s -n "$LIVE_DB_HOLD"; then
        for (( i = 0; i < LIVE_DB_SLOTS; i++ )); do
          exec {fd}>>"$LIVE_DB.slot.$i"
          if flock -n "$fd"; then LIVE_DB_SLOT=$fd; LIVE_DB_HOW="slot $(( i + 1 )) of $LIVE_DB_SLOTS"; break; fi
          exec {fd}>&-
        done
        [ -n "$LIVE_DB_SLOT" ] || flock -u "$LIVE_DB_HOLD"
      fi
      if [ -n "$LIVE_DB_HOW" ]; then
        rm -f "${LIVE_DB:?}.$line/${ticket:?}"
        return 0
      fi
    fi
    sleep 1
  done
  rm -f "${LIVE_DB:?}.$line/${ticket:?}"
  leave_live_db
  return 1
}
leave_live_db() {
  [ -n "${LIVE_DB_SLOT:-}" ] && exec {LIVE_DB_SLOT}>&-
  [ -n "${LIVE_DB_HOLD:-}" ] && exec {LIVE_DB_HOLD}>&-
  LIVE_DB_SLOT=""; LIVE_DB_HOLD=""
}
# CMD, run with none of the lock's files open: a browser it leaves behind
# must not hold the live database from every other run.
without_live_db() {
  (
    [ -n "${LIVE_DB_SLOT:-}" ] && exec {LIVE_DB_SLOT}>&-
    [ -n "${LIVE_DB_HOLD:-}" ] && exec {LIVE_DB_HOLD}>&-
    exec "$@"
  )
}
