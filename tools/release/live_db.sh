#!/usr/bin/env bash
# live_db.sh WHO CMD... : run CMD on the live site holding the live
# database's lock, taken as a check in preview_checks.sh takes it: after any
# release that waits or runs, and written in live-db.log as WHO. A unit's own
# A/B or diagnostic run against brickworks.diy takes the lock only through
# this. hover's took it with a bare flock from a scratch script, gave way to
# no release, and held rel-m233's checks twice, 33 and 38 minutes
# (2026-10-31). Exits as CMD does, or 75 if the lock stayed busy (LIVE_WAIT
# seconds, an hour).
[ $# -ge 2 ] || { echo "usage: live_db.sh WHO CMD..." >&2; exit 2; }
who=$1; shift
. "$(cd "$(dirname "$0")" && pwd)/live_db_lib.sh"
t0=$(date +%s)
exec {lock}>>"$LIVE_DB.lock"
if ! take_live_db "$lock"; then
  echo "live_db: the live database stayed busy: $(tail -1 "$LIVE_DB.log" 2>/dev/null)" >&2
  exit 75
fi
echo "$(date '+%F %T') took $who after $(( $(date +%s) - t0 ))s" >> "$LIVE_DB.log"
# Held by this shell only: a browser CMD leaves behind must not hold it.
"$@" {lock}>&-
code=$?
echo "$(date '+%F %T') left $who exit=$code" >> "$LIVE_DB.log"
exit $code
