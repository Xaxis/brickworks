#!/usr/bin/env bash
# live_db.sh [--alone] WHO CMD... : run CMD on the live site holding a slot
# of the live database's lock, taken as a check in preview_checks.sh takes
# it: after any release that waits or runs, and written in live-db.log as
# WHO. --alone holds all of it, for a run that reads what every account
# changes (preview_checks.sh's ALONE_DB). A unit's own A/B or diagnostic
# run against brickworks.diy takes the lock only through this. hover's took
# it with a bare flock from a scratch script, gave way to no release, and
# held rel-m233's checks twice, 33 and 38 minutes (2026-10-31). Exits as
# CMD does, or 75 if the lock stayed busy (LIVE_WAIT seconds, an hour).
alone=""
[ "${1:-}" = --alone ] && { alone=alone; shift; }
[ $# -ge 2 ] || { echo "usage: live_db.sh [--alone] WHO CMD..." >&2; exit 2; }
who=$1; shift
. "$(cd "$(dirname "$0")" && pwd)/live_db_lib.sh"
t0=$(date +%s)
if ! take_live_db $alone; then
  echo "live_db: the live database stayed busy: $(tail -1 "$LIVE_DB.log" 2>/dev/null)" >&2
  exit 75
fi
echo "$(date '+%F %T') took $who after $(( $(date +%s) - t0 ))s ($LIVE_DB_HOW)" >> "$LIVE_DB.log"
without_live_db "$@"
code=$?
leave_live_db
echo "$(date '+%F %T') left $who exit=$code" >> "$LIVE_DB.log"
exit $code
