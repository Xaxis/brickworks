#!/bin/bash
# release_live.sh TAG SHA [SPEC] : write down that release TAG (commit SHA)
# is live on brickworks.diy now, for the owner's console (/admin#site,
# api/_console_site.js): a row of site_releases (supabase/console2.sql)
# through site_release_live, with the train's title and units from SPEC (its
# TAG.train folder) when there is one. ship.sh calls it once the live site
# serves the release; it never fails a ship.
#
#   release_live.sh --backfill [RELEASE_OUT]   every train in RELEASE_OUT
#     (bench/results/release-out) whose result is live, each at the time its
#     result was written and with the commit main took for it, the latest
#     last: for the releases before this script.
#
# Reads SUPABASE_URL and SUPABASE_SECRET_KEY from the environment, or from
# the main checkout's .env. No Vercel token: the train knows what it shipped.
set -u
here=$(cd "$(dirname "$0")" && pwd)
R=$(dirname "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)")
if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_SECRET_KEY:-}" ]; then
  [ -f "$R/.env" ] && { set -a; . "$R/.env"; set +a; }
fi
[ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_SECRET_KEY:-}" ] || { echo "release_live: no SUPABASE_URL or SUPABASE_SECRET_KEY"; exit 0; }

# One release written down: TAG SHA LIVE_AT(iso or "") SPEC(or "").
keep() {
  local tag=$1 sha=$2 at=$3 spec=$4 title="" units=""
  if [ -n "$spec" ] && [ -d "$spec" ]; then
    title=$(head -c 2000 "$spec/title" 2>/dev/null | tr '\n' ' ')
    units=$(cat "$spec/units" 2>/dev/null | tr '\n' ' ')
  fi
  body=$(TAG="$tag" SHA="$sha" AT="$at" TITLE="$title" UNITS="$units" python3 -c '
import json, os, re
units = [u for u in os.environ["UNITS"].split() if re.fullmatch(r"[a-z0-9_-]{1,40}", u)][:60]
print(json.dumps({"p_tag": os.environ["TAG"].lower(), "p_sha": os.environ["SHA"].lower(),
  "p_title": os.environ["TITLE"].strip() or None, "p_units": units, "p_live_at": os.environ["AT"] or None}))')
  answer=$(curl -s --max-time 20 -w ' %{http_code}' -X POST "${SUPABASE_URL%/}/rest/v1/rpc/site_release_live" \
    -H "apikey: $SUPABASE_SECRET_KEY" -H "Authorization: Bearer $SUPABASE_SECRET_KEY" -H "Content-Type: application/json" \
    -d "$body" </dev/null)
  case "${answer##* }" in
    200) echo "release_live: $tag ($sha) written down, live from ${at:-now}" ;;
    *) echo "release_live: $tag not written down: ${answer: -200}" ;;
  esac
}

if [ "${1:-}" = "--backfill" ]; then
  RO=$(realpath -m "${2:-$R/bench/results/release-out}")
  # The trains that went live (the order does not matter: each keeps its own time).
  for spec in "$RO"/rel-*.train; do
    [ -d "$spec" ] || continue
    grep -qx "live" "$spec/result" 2>/dev/null || continue
    tag=$(basename "$spec" .train)
    tip=$(cat "$spec/tip" 2>/dev/null)
    [ -n "$tip" ] || continue
    # What main took for it: the first-parent commit that merged the tip, or the tip itself.
    sha=$(git -C "$R" log --first-parent --format='%H' main 2>/dev/null | grep -m1 "^$tip")
    [ -n "$sha" ] || sha=$(git -C "$R" log --first-parent --format='%H %P' main 2>/dev/null | awk -v t="$tip" '$3 == t { print $1; exit }')
    [ -n "$sha" ] || sha=$tip
    at=$(date -u -r "$spec/result" +%Y-%m-%dT%H:%M:%SZ)
    keep "$tag" "${sha:0:12}" "$at" "$spec"
  done
  exit 0
fi

tag=${1:?usage: release_live.sh TAG SHA [SPEC] | --backfill [RELEASE_OUT]}
sha=${2:?usage: release_live.sh TAG SHA [SPEC]}
keep "$tag" "${sha:0:12}" "" "${3:-}"
exit 0
