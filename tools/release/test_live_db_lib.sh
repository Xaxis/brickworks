#!/usr/bin/env bash
# test_live_db_lib.sh: a unit's check waits its turn behind other units but
# gives way to a release within LIVE_GIVE_WAY. Runs on a scratch lock, not
# the repository's, so it never touches a real battery's slots.
set -u
cd "$(dirname "$0")/../.." || exit 1
# shellcheck source=live_db_lib.sh
. tools/release/live_db_lib.sh
T=$(mktemp -d) || exit 1
LIVE_DB="$T/live-db"; LIVE_DB_SLOTS=1; LIVE_DB_POLL=0.2
pids=()
trap 'kill "${pids[@]}" 2>/dev/null; rm -rf "$T"' EXIT
fails=0
check() { if eval "$2"; then echo "ok   $1"; else echo "FAIL $1 ($2)"; fails=$(( fails + 1 )); fi; }
hold_slot() { flock -x "$LIVE_DB.slot.0" sleep "$1" & pids+=($!); sleep 0.3; }
mark_release() { sleep 60 & pids+=($!); mkdir -p "$LIVE_DB.release"; started $! > "$LIVE_DB.release/$!"; }
took() { local t0=$EPOCHSECONDS r; ( take_live_db ); r=$?; echo "$r $(( EPOCHSECONDS - t0 ))"; }

# Free: taken at once.
read -r r s < <(LIVE_GIVE_WAY=2 LIVE_WAIT=10 took)
check "a free slot is taken at once" '[ "$r" = 0 ] && [ "$s" -le 1 ]'

# Behind another unit for longer than LIVE_GIVE_WAY: still taken.
hold_slot 4
read -r r s < <(LIVE_GIVE_WAY=2 LIVE_WAIT=10 took)
check "behind a unit it waits past LIVE_GIVE_WAY and takes the slot" '[ "$r" = 0 ] && [ "$s" -ge 3 ]'

# A release waiting: gives way after LIVE_GIVE_WAY, long before LIVE_WAIT.
mark_release
read -r r s < <(LIVE_GIVE_WAY=2 LIVE_WAIT=30 took)
check "behind a release it gives up after LIVE_GIVE_WAY" '[ "$r" = 1 ] && [ "$s" -ge 2 ] && [ "$s" -le 4 ]'

# No LIVE_GIVE_WAY (a train's own or live_db.sh's runs): LIVE_WAIT alone.
read -r r s < <(LIVE_WAIT=3 took)
check "without LIVE_GIVE_WAY it waits LIVE_WAIT" '[ "$r" = 1 ] && [ "$s" -ge 3 ] && [ "$s" -le 5 ]'

# No ticket left behind by a run that gave up.
check "no ticket left in the queue" '[ -z "$(ls -A "$LIVE_DB.queue" 2>/dev/null)" ]'
echo "$fails failed"
[ "$fails" = 0 ]
