#!/bin/bash
# ship_after.sh PREV WORKTREE TAG CHECK...
# Ship TAG once release PREV has shipped, as a queue: waits until PREV's
# result is in $RELEASE_OUT (PREV.done, its exit code, which this writes;
# or an "exit=N" last line in PREV_ship.log), ships only if it was 0, and
# writes TAG's own. PREV "-" ships at once.
#
# Waiters written by hand looked for the release before by its command
# line, and one's own grep took it out of the list: it found nothing and
# let m43's ship go at once (2026-10-17).
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
S="${RELEASE_OUT:?set RELEASE_OUT to the releases folder}"
PREV="$1"; W="$2"; TAG="$3"; shift 3

result_of() {
  if [ -e "$S/$1.done" ]; then cat "$S/$1.done"; return; fi
  [ -e "$S/${1}_ship.log" ] && tail -1 "$S/${1}_ship.log" | sed -n 's/^exit=//p'
}

if [ "$PREV" != "-" ]; then
  echo "SHIP: $TAG waits for $PREV"
  until [ -n "$(result_of "$PREV")" ]; do sleep 30; done
  if [ "$(result_of "$PREV")" != 0 ]; then
    echo "SHIP: $PREV did not ship (exit $(result_of "$PREV")); $TAG held"
    echo 1 > "$S/$TAG.done"
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
