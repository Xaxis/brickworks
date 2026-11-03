#!/usr/bin/env bash
# relay_probe.sh NAME : one of the probes tools/suite/out.txt keeps out of
# runs for want of the relay (account, connector, tabs, tabpair, together,
# desktop_cloud), run on a relay of its own: .env's keys, a free port, the
# relay's address handed the way the probe's header takes it, the live
# database's lock held (they make accounts in production Supabase), and the
# relay stopped after. Exits as the probe does.
#
# By hand, connector_probe ran with no relay once and with "--" for its port
# once, failed every check each time for the setup, and was read as the
# code's: rel-m252's, then connectany's (2026-11-03).
set -u
cd "$(dirname "$0")/.." || exit 2
name=${1:?usage: relay_probe.sh NAME}; name=${name%.gd}; name=${name##*/}; name=${name%_probe}
port=$(python3 -c 'import socket; s = socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])') || exit 2
api=http://127.0.0.1:$port
hold=(); args=(); env=()
case $name in
  connector|tabs|tabpair) args=("$port") ;;
  account|desktop_cloud) env=("BRICKWORKS_API=$api") ;;
  together) hold=("--hold=together_sessions,together_ops,together_people,together_snapshot_parts"); args=("--api=$api") ;;
  *) echo "relay_probe: $name is not one of the relay's probes (account connector tabs tabpair together desktop_cloud)" >&2; exit 2 ;;
esac
# The keys are the main checkout's: a worktree has no .env of its own.
keys=.env
[ -f "$keys" ] || keys="$(cd "$(git rev-parse --git-common-dir)/.." && pwd)/.env"
[ -f "$keys" ] || { echo "relay_probe: no .env here or in the main checkout" >&2; exit 2; }
set -a
# shellcheck disable=SC1090
. "$keys"
set +a
log=$(mktemp "${TMPDIR:-/tmp}/relay_probe.$name.XXXXXX.log") || exit 2
setsid node tools/web/relay_server.mjs "$port" "${hold[@]}" > "$log" 2>&1 < /dev/null &
relay=$!
trap 'kill -TERM -- "-$relay" 2>/dev/null' EXIT
for _ in $(seq 1 60); do curl -s -o /dev/null "$api/" && break; sleep 1; done
curl -s -o /dev/null "$api/" || { echo "relay_probe: the relay never answered on $port; its log, $log:" >&2; tail -n 5 "$log" >&2; exit 1; }
echo "relay_probe: $name on the relay at $api (its log $log)"
tools/release/live_db.sh "relay_probe $name" env "${env[@]}" tools/probe.sh "${name}_probe" "${args[@]}"
