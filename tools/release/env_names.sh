#!/bin/bash
# env_names.sh : write down the names of the Vercel project's variables and
# the environments each is in (production, preview, development), never a
# value, for the owner's console (/admin#switches, api/_console_switches.js):
# site_env through site_env_note (supabase/console3.sql). ship.sh calls it
# once a release is live, beside release_live.sh; it never fails a ship.
#
# `vercel env ls --format json` lists each variable with its value (or its
# encrypted form); only its key and target are read here, in this process,
# and nothing else of it is kept, printed or sent.
#
# Reads SUPABASE_URL and SUPABASE_SECRET_KEY from the environment, or from
# the main checkout's .env, and VERCEL_TOKEN likewise (else the CLI's own
# sign-in on this box).
set -u
here=$(cd "$(dirname "$0")" && pwd)
R=$(dirname "$(git -C "$here" rev-parse --path-format=absolute --git-common-dir)")
if [ -z "${SUPABASE_URL:-}" ] || [ -z "${SUPABASE_SECRET_KEY:-}" ] || [ -z "${VERCEL_TOKEN:-}" ]; then
  [ -f "$R/.env" ] && { set -a; . "$R/.env"; set +a; }
fi
[ -n "${SUPABASE_URL:-}" ] && [ -n "${SUPABASE_SECRET_KEY:-}" ] || { echo "env_names: no SUPABASE_URL or SUPABASE_SECRET_KEY"; exit 0; }
token=()
[ -n "${VERCEL_TOKEN:-}" ] && token=(--token "$VERCEL_TOKEN")
# Linked to the project as the main checkout is (its .vercel/project.json);
# vercel@48, which deploys, has no --format json.
listed=$(cd "$R" && timeout 90 npx --yes vercel@61.1.0 env ls --format json ${token[@]+"${token[@]}"} </dev/null 2>/dev/null)
body=$(printf '%s' "$listed" | python3 -c '
import json, re, sys
try:
    envs = json.load(sys.stdin).get("envs") or []
except Exception:
    sys.exit(1)
seen = {}
for one in envs:
    name = str(one.get("key") or "")
    if not re.fullmatch(r"[A-Z][A-Z0-9_]{0,63}", name):
        continue
    target = one.get("target") or []
    target = [target] if isinstance(target, str) else target
    seen.setdefault(name, set()).update(t for t in target if t in ("production", "preview", "development"))
print(json.dumps({"p_vars": [{"name": n, "environments": sorted(e)} for n, e in sorted(seen.items())]}))
') || { echo "env_names: Vercel did not list the variables"; exit 0; }
answer=$(curl -s --max-time 20 -w ' %{http_code}' -X POST "${SUPABASE_URL%/}/rest/v1/rpc/site_env_note" \
  -H "apikey: $SUPABASE_SECRET_KEY" -H "Authorization: Bearer $SUPABASE_SECRET_KEY" -H "Content-Type: application/json" \
  -d "$body" </dev/null)
case "${answer##* }" in
  200) echo "env_names: ${answer% *} variables written down" ;;
  *) echo "env_names: not written down: ${answer: -200}" ;;
esac
exit 0
