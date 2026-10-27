#!/bin/bash
# ship_after.sh PREV WORKTREE TAG CHECK...
# Ship TAG once release PREV has shipped, as a queue: waits until PREV's
# result is in $RELEASE_OUT (PREV.done, its exit code, which ship.sh and
# this write), ships only if it was 0, and writes TAG's own. PREV "-" ships
# at once. A waiter that gives up writes TAG.gave_up, never TAG.done: TAG
# never ran.
#
# Waiters written by hand looked for the release before by its command
# line, and one's own grep took it out of the list: it found nothing and
# let m43's ship go at once (2026-10-17).
#
# A result is the latest attempt's or none. m177's first waiter gave up when
# m175 held and wrote m177.done = 1; m177 shipped later, and m178's waiter
# read that 1 while m177's checks still ran, and held (2026-10-26). So TAG
# queued clears what its attempts before left (ship.sh does too, for a ship
# begun by hand), and the log before is kept as TAG_ship.prev.log.
#
# The log is never read for a result. An "exit=N" ending PREV_ship.log was
# once read when PREV.done was missing, which is just when PREV has begun
# again: m181's promote, begun by hand, cleared m181.done, and m182's waiter
# read the held battery's "exit=1" from the log while the promote ran, and
# held (2026-10-26).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
# Absolute: ship.sh runs from the worktree, where a relative folder is another
# one; m144's first ship failed "preview deploy failed" on it (2026-10-22).
S="$(realpath -m "${RELEASE_OUT:?set RELEASE_OUT to the releases folder}")"
export RELEASE_OUT="$S"
PREV="$1"; W="$2"; TAG="$3"; shift 3

result_of() {
  if [ -e "$S/$1.done" ]; then echo "exit $(cat "$S/$1.done")"; return; fi
  if [ -e "$S/$1.gave_up" ]; then echo "never begun: $(cat "$S/$1.gave_up")"; fi
}

rm -f "$S/$TAG.done" "$S/$TAG.gave_up"
[ -e "$S/${TAG}_ship.log" ] && mv -f "$S/${TAG}_ship.log" "$S/${TAG}_ship.prev.log"
if [ "$PREV" != "-" ]; then
  echo "SHIP: $TAG waits for $PREV"
  # Read once: a second read can fall after PREV's next attempt cleared it.
  until result=$(result_of "$PREV"); [ -n "$result" ]; do sleep 30; done
  if [ "$result" != "exit 0" ]; then
    echo "SHIP: $PREV did not ship ($result); $TAG held"
    echo "$PREV did not ship ($result)" > "$S/$TAG.gave_up"
    exit 1
  fi
fi
# Not begun while a hold is set ($S/HOLD, $S/TAG.hold): ship.sh would
# stop at production anyway, after a preview and its checks for nothing.
while [ -e "$S/HOLD" ] || [ -e "$S/$TAG.hold" ]; do sleep 30; done
"$HERE/ship.sh" "$W" "$TAG" "$@" > "$S/${TAG}_ship.log" 2>&1
code=$?
echo "exit=$code" >> "$S/${TAG}_ship.log"
echo "$code" > "$S/$TAG.done"
tail -4 "$S/${TAG}_ship.log"
exit $code
