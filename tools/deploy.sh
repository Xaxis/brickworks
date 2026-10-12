#!/usr/bin/env bash
# Put the web build on Vercel and prove it runs there.
#   tools/deploy.sh                 a preview URL, for looking at
#   tools/deploy.sh --prod          the one the domain points at
#   tools/deploy.sh --no-export     deploy what is already in build/web
#   tools/deploy.sh --no-check      skip the browser proof (not advised)
#   tools/deploy.sh --dir=DIR       deploy a build from elsewhere (a kept build: build/kept/<id>/web);
#                                   implies --no-export
#
# Needs VERCEL_TOKEN, from .env here or from the environment (CI). Never commit it.
#
# The build goes under /b/<sha>/ and / redirects to it, so every file can be
# cached forever and a player who comes back after a deploy can never end up
# running a new pack against an old engine. The threaded build needs the page to
# be cross-origin isolated, so the headers below are not optional: without them
# the engine refuses to start, which is why the proof at the end loads the real
# URL in a real browser rather than trusting that we sent them.
set -uo pipefail
# Guarded: a cd that fails leaves the script running against
# whatever directory it was started from, which for a deploy means
# shipping something else entirely.
cd "$(dirname "$0")/.." || exit 1

prod=0; do_export=1; do_check=1; dir=build/web
for a in "$@"; do
  case "$a" in
    --prod) prod=1 ;;
    --no-export) do_export=0 ;;
    --no-check) do_check=0 ;;
    --dir=*) dir="${a#--dir=}"; do_export=0 ;;
    *) echo "deploy: unknown option $a"; exit 2 ;;
  esac
done

[ -f .env ] && set -a && . ./.env && set +a
if [ -z "${VERCEL_TOKEN:-}" ]; then echo "deploy FAILED: no VERCEL_TOKEN (.env or environment)"; exit 1; fi

# Every part the catalogue names must be in object storage before a build
# that names it ships: the web build fetches meshes from there, not from the
# deploy. On 2026-10-11 a catalogue with 2,376 rebuilt meshes went out
# before they were uploaded, and every Technic beam from 7 up failed to load
# on the live site until they were. Uploads only what is missing.
echo "deploy: part meshes in object storage"
if ! python3 tools/storage_parts.py >/tmp/deploy_storage_$$.log 2>&1; then
  tail -5 /tmp/deploy_storage_$$.log
  echo "deploy FAILED: could not put the part meshes in object storage"; rm -f /tmp/deploy_storage_$$.log; exit 1
fi
tail -2 /tmp/deploy_storage_$$.log | sed 's/^/  /'; rm -f /tmp/deploy_storage_$$.log
# Project and org come from .vercel/project.json, written by `vercel link`.

if [ "$do_export" = 1 ]; then
  tools/export.sh web || exit 1
fi
[ -f "$dir/index.html" ] || { echo "deploy FAILED: no build in $dir (tools/export.sh web)"; exit 1; }

sha="$(git rev-parse --short HEAD)"
# Dirty means a change to something that ships. Docs, tools, tests and the
# verify skill do not, and a roadmap edited while a deploy sat in the
# machine's queue stamped two builds "-dirty" whose code was exactly HEAD.
[ -n "$(git status --porcelain --untracked-files=no -- . \
    ':!docs' ':!tools' ':!tests' ':!.claude' ':!*.md')" ] && sha="$sha-dirty"

rm -rf .vercel/output
mkdir -p ".vercel/output/static/b/$sha"
# The .br and .gz siblings are for a server that negotiates; Vercel does its own.
for f in "$dir"/*; do
  case "$f" in *.br|*.gz|*/build.json) continue ;; esac
  cp "$f" ".vercel/output/static/b/$sha/"
done
# What this build is and when it went out, read by the app's Help panel.
# The owner, looking at the live site, could not tell when it had last
# been deployed.
printf '{"commit": "%s", "deployed": "%s"}\n' "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > ".vercel/output/static/b/$sha/version.json"

# The serverless endpoints, packaged the way the Build Output API wants
# them. A prebuilt deploy has no build step to discover api/, so each is
# assembled here: a directory per route, the handler inside it, and a
# .vc-config.json saying how to run it.
#
# Every route gets its own copy of the shared modules — the ones named
# with a leading underscore, which are imports rather than routes. A
# function directory is its own bundle with nothing outside it on the
# path, so a route importing a shared ./_*.js finds nothing unless the
# file is sitting beside it.
#
# Six routes. /api/account says where the parts are (PARTS_URL) and
# where to sign in (SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY); without those
# the app asks nobody to sign in. /api/otp emails a sign-in code
# (SUPABASE_SECRET_KEY, RESEND_API_KEY, EMAIL_FROM, EMAIL_FROM_FALLBACK).
# /api/admin is the owner's account list (MASTER_EMAIL). /api/mcp, the
# Claude connector's relay, needs SUPABASE_URL and SUPABASE_SECRET_KEY for
# its queue; without them it says the connector is not configured.
# /api/oauth is how Claude signs in to it (the same keys); the paths OAuth
# clients look for are mapped onto it in the routes below. /api/collection
# keeps what a person owns (the same keys, supabase/collection.sql), and
# reads the Rebrickable and BrickLink joins it maps imports through from
# the index tools/collection_data.py writes, put beside it here.
# /api/share is a model shared by link (the same keys, and the publishable
# one for a visitor's read): /m/<id>, its picture and its card are mapped
# onto it. The viewer is /app?view=<id>: Vercel carries a query across the
# /app 308 by itself (measured 2026-10-12, /app?foo=x to /b/<sha>/?foo=x),
# so it needs no route of its own. Vercel's cron calls /api/share/sweep at
# 04:17 UTC every day, with CRON_SECRET (set on the project, and in .env
# for share_probe): it takes away the files of models whose row went with
# a deleted account. Its pages send their own security policy; the app's below
# does not change, since the viewer talks only to its own site.
for handler in api/*.js; do
  [ -f "$handler" ] || continue
  route=$(basename "$handler" .js)
  case "$route" in _*) continue ;; esac

  fn=".vercel/output/functions/api/$route.func"
  mkdir -p "$fn"
  cp "$handler" "$fn/index.mjs"
  for shared in api/_*.js; do
    [ -f "$shared" ] && cp "$shared" "$fn/"
  done
  if [ "$route" = collection ]; then
    if [ ! -f assets/generated/sets/index.json ]; then
      echo "deploy FAILED: no assets/generated/sets/index.json for /api/collection (tools/collection_data.py)"; exit 1
    fi
    cp assets/generated/sets/index.json "$fn/_collection_index.json"
  fi
  # The handler is .mjs and so is unambiguously a module; the shared
  # files it imports are .js, which Node classifies by the nearest
  # package.json — and a function bundle has none. Node 22 does detect
  # module syntax and gets it right without this, so the marker is not
  # load-bearing today; it is here so the answer does not depend on a
  # heuristic that a runtime bump could change underneath us.
  echo '{ "type": "module" }' > "$fn/package.json"
  cat > "$fn/.vc-config.json" <<'JSON'
{
  "runtime": "nodejs22.x",
  "handler": "index.mjs",
  "launcherType": "Nodejs",
  "shouldAddHelpers": true,
  "maxDuration": 300
}
JSON
  echo "deploy: packaged /api/$route"
done

# What is in every set, and the official models' parts lists, for My
# collection (tools/collection_data.py, src/dev/collection_models.gd). Not in
# the pack, which everybody waits for: 26 MB in 258 files, and the app
# fetches the one shard a typed set is in (SetInventories). Same origin, so
# the content security policy needs nothing new for it.
if [ ! -f assets/generated/sets/index.json ] || [ ! -f assets/generated/sets/models.json ]; then
  echo "deploy FAILED: no set inventories in assets/generated/sets (tools/collection_data.py, src/dev/collection_models.gd)"; exit 1
fi
mkdir -p .vercel/output/static/sets
cp assets/generated/sets/*.json .vercel/output/static/sets/
echo "deploy: $(ls -1 .vercel/output/static/sets | wc -l | tr -d ' ') set inventory files at /sets/"

# Geometry the app fetches when someone picks a part the build does not
# carry. Served from /parts/ at the deployment root rather than under
# /b/<sha>/, because it is the same bytes every deploy and the browser
# should keep it across them.
if [ -d assets/web/remote ]; then
  mkdir -p .vercel/output/static/parts
  cp assets/web/remote/*.lbm .vercel/output/static/parts/ 2>/dev/null || true
  count=$(ls -1 .vercel/output/static/parts 2>/dev/null | wc -l | tr -d ' ')
  echo "deploy: $count parts served on demand"
fi

# The landing page sits at the root and the application at /app. Before
# this, / redirected straight into the build, so there was nowhere to
# say what the thing is.
if [ -f web/index.html ]; then
  # Everything in web/, not just the page. It copied index.html alone,
  # which meant the favicon, the manifest and the Open Graph image —
  # every file the page references by an absolute path — were simply
  # absent from the deployment, and a shared link showed no picture.
  #
  # Files starting with an underscore are working parts of the build
  # (the render the share image is composed from) and are not served.
  count=0
  for asset in web/*; do
    name=$(basename "$asset")
    case "$name" in _*) continue ;; esac
    [ -f "$asset" ] || continue
    cp "$asset" ".vercel/output/static/$name"
    count=$((count + 1))
  done
  echo "deploy: landing page and $count file(s) at /"
fi

# What the pages may load and, above all, where they may send anything.
#
# The app holds a person's Anthropic key in the browser. The best defence
# for that is a short list of places the page can talk to at all: itself,
# Anthropic, Wikimedia (reference pictures), Rebrickable (a person's own
# sets and parts lists, read with their own Rebrickable key: My collection),
# the parts store and the sign-in service — so even a script that should
# never have run has nowhere to send a key. The page's one inline script is allowed by its
# hash, not by allowing inline scripts; 'unsafe-eval' stays because
# Godot's JavaScript bridge evaluates what the app asks of the browser
# (its size, its address, the clipboard).
#
# The sign-in service is Supabase (SUPABASE_URL), where a code is
# redeemed and a session renewed. Named on its own: it was reachable only
# because the parts store happens to be in the same project, and moving
# the parts would have broken every sign-in without a word.
inline_hashes="$(python3 - "$dir/index.html" <<'PY'
import base64, hashlib, re, sys
page = open(sys.argv[1], encoding="utf-8").read()
for body in re.findall(r"<script>(.*?)</script>", page, re.S):
    print("'sha256-%s'" % base64.b64encode(hashlib.sha256(body.encode()).digest()).decode(), end=" ")
PY
)"
origin_of() {
  python3 -c 'import sys, urllib.parse as u; p = u.urlparse(sys.argv[1]); print(f"{p.scheme}://{p.netloc}")' "$1"
}
parts_origin=""
[ -n "${PARTS_URL:-}" ] && parts_origin="$(origin_of "$PARTS_URL")"
signin_origin=""
[ -n "${SUPABASE_URL:-}" ] && signin_origin="$(origin_of "$SUPABASE_URL")"
# Once each, even when they are the same place, as they are today.
connect_extra="$(printf '%s\n' "$parts_origin" "$signin_origin" | awk 'NF && !seen[$0]++' | tr '\n' ' ')"
csp="default-src 'self'; script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval' ${inline_hashes}; worker-src 'self' blob:; connect-src 'self' https://api.anthropic.com https://commons.wikimedia.org https://upload.wikimedia.org https://rebrickable.com ${connect_extra}; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; font-src 'self' data:; media-src 'self' blob:; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
# Where Claude sends someone to sign in (web/authorize.html). Stricter than
# the app's: no eval, and it talks only to itself and the sign-in service.
# And none of the cross-origin isolation headers: the app's threaded build
# needs those, and a page claude.ai opens must not cut itself off from the
# window that opened it, which Cross-Origin-Opener-Policy would.
authorize_csp="default-src 'self'; script-src 'self'; connect-src 'self' ${signin_origin}; img-src 'self' data:; style-src 'self' 'unsafe-inline'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"

cat > .vercel/output/config.json <<EOF
{
  "version": 3,
  "crons": [ { "path": "/api/share/sweep", "schedule": "17 4 * * *" } ],
  "routes": [
    { "src": "/api/share/sweep", "dest": "/api/share?op=sweep" },
    { "src": "/api/(.*)", "dest": "/api/\$1" },
    { "src": "/[.]well-known/oauth-protected-resource(/.*)?", "dest": "/api/oauth?op=resource" },
    { "src": "/[.]well-known/oauth-authorization-server(/.*)?", "dest": "/api/oauth?op=metadata" },
    { "src": "/oauth/register/?", "dest": "/api/oauth?op=register" },
    { "src": "/oauth/token/?", "dest": "/api/oauth?op=token" },
    { "src": "/oauth/revoke/?", "dest": "/api/oauth?op=revoke" },
    { "src": "/oauth/authorize/?", "dest": "/authorize.html",
      "headers": {
        "Content-Security-Policy": "$authorize_csp",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
        "Cache-Control": "no-store" } },
    { "src": "/sets/(.*[.]json)", "headers": {
        "Cache-Control": "public, max-age=3600, stale-while-revalidate=86400" } },
    { "src": "/m/([A-Za-z0-9]{10})/?", "dest": "/api/share?op=page&id=\$1" },
    { "src": "/m/([A-Za-z0-9]{10})[.]png", "dest": "/api/share?op=image&id=\$1" },
    { "src": "/m/([A-Za-z0-9]{10})/embed/?", "dest": "/api/share?op=embed&id=\$1" },
    { "src": "/parts/(.*[.]lbm)", "headers": {
        "Cache-Control": "public, max-age=31536000, immutable" } },
    { "src": "/app/?", "status": 308, "headers": { "Location": "/b/$sha/" } },
    { "src": "/(.*)",
      "headers": {
        "Cross-Origin-Opener-Policy": "same-origin",
        "Cross-Origin-Embedder-Policy": "require-corp",
        "Cross-Origin-Resource-Policy": "same-origin",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
        "Content-Security-Policy": "$csp"
      },
      "continue": true },
    { "src": "/b/([^/]+)/(.*)",
      "headers": { "Cache-Control": "public, max-age=31536000, immutable" },
      "continue": true },
    { "src": "/b/([^/]+)/?$", "dest": "/b/\$1/index.html" },
    { "handle": "filesystem" },
    { "src": "/parts/(.*)", "status": 404,
      "headers": { "Content-Type": "text/plain" } },
    { "src": "/sets/(.*)", "status": 404,
      "headers": { "Content-Type": "text/plain" } },
    { "src": "/(.*)", "status": 308, "headers": { "Location": "/" } }
  ]
}
EOF

# .vercel/project.json is written by `vercel link` and says which project
# this deploys to. Without it the CLI would prompt, which a script cannot
# answer, so fail with the fix rather than hang.
if [ ! -f .vercel/project.json ]; then
  echo "deploy FAILED: no .vercel/project.json — run:"
  echo "  npx vercel@48 link --yes --project brickworks --token \$VERCEL_TOKEN"
  exit 1
fi

echo "deploy $sha -> vercel ($([ "$prod" = 1 ] && echo "production, after checking" || echo preview))"
log="$(mktemp "${TMPDIR:-/tmp}/brickworks-deploy.XXXXXX")"
# Always uploaded as a preview, even when the domain is the destination.
#
# --prod promotes on upload, so the check that follows runs against a
# build that is already the one everybody is getting. It did its job
# once — caught a parse error that stopped the app loading at all — and
# reported it as "deploy FAILED" after the broken build had been live
# for two minutes. A check that runs after the promotion is not a gate,
# it is a postmortem.
#
# --archive=tgz sends one tarball rather than a file at a time. Both of
# this deploy's failures were in the per-file uploader: it aborted Node
# outright on fourteen thousand files, and then twice returned a 500 as
# an HTML page that the CLI tried to parse as JSON. Neither is
# something this end can fix, and neither happens with one upload.
npx --yes vercel@48 deploy --prebuilt --yes --archive=tgz --token "$VERCEL_TOKEN" >"$log" 2>&1
code=$?
url="$(grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app' "$log" | tail -1)"
if [ $code -ne 0 ] || [ -z "$url" ]; then
  tail -20 "$log"; echo "deploy FAILED"; rm -f "$log"; exit 1
fi
echo "deploy ok $url"

if [ "$do_check" = 1 ]; then
  # The same proof a local build gets, against what the host actually serves:
  # the title, a new game played through the loading page, and a reload that
  # must find the save still there.
  if [ ! -d tools/web/node_modules/playwright ]; then
    npm install --prefix tools/web --no-audit --no-fund >/dev/null || { echo "deploy FAILED: npm install"; exit 1; }
    npx --prefix tools/web playwright install chromium-headless-shell >/dev/null 2>&1 || true
  fi
  mkdir -p shots
  # tools/web/check.mjs, with the arguments it actually takes. This said
  # web.mjs and passed --play --reload, none of which exist, so the proof
  # at the end of every deploy was a MODULE_NOT_FOUND printed under a
  # line reading "deploy FAILED" — a check that could only ever fail is
  # worth less than no check, because its failure says nothing.
  # /app, not /. The root is the landing page now, and pointing the
  # check at it meant waiting two minutes for a canvas that was never
  # going to appear on a page of prose.
  node tools/web/check.mjs --url="$url/app" --out=shots/deploy.png \
      ${VERCEL_BYPASS:+--bypass="$VERCEL_BYPASS"} || {
    echo "deploy FAILED: the build does not run at $url/app"; exit 1; }
  # And that it fits the page. At two device pixels to the point the
  # toolbar ran off at "He…" and the assistant was off the page, on every
  # Retina screen, while every check here passed at one.
  node tools/web/fit_check.mjs --url="$url/app" --quick --out=shots/fit \
      ${VERCEL_BYPASS:+--bypass="$VERCEL_BYPASS"} || {
    echo "deploy FAILED: the app does not fit the page at $url/app"; exit 1; }

  # The landing page is what most people meet first, so a deploy that
  # serves the app but not the page is still a broken deploy.
  landing=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 \
    ${VERCEL_BYPASS:+-H "x-vercel-protection-bypass: $VERCEL_BYPASS"} "$url/")
  if [ "$landing" != "200" ]; then
    echo "deploy FAILED: the landing page answers $landing at $url/"; exit 1
  fi
  # A status code cannot see a page that renders wrong. This one loads it
  # in a browser at phone width and at laptop width: the page had been
  # scrolling sideways on every phone for as long as it has existed,
  # because five header links are 405px in a 358px bar and nothing
  # wrapped them, and a 200 said nothing about it.
  if ! VERCEL_BYPASS="${VERCEL_BYPASS:-}" node tools/web/landing_check.mjs \
      --url="$url/"; then
    echo "deploy FAILED: the landing page does not hold together at $url/"
    exit 1
  fi
  echo "deploy: landing page ok, app runs"
fi
if [ "$prod" = 1 ]; then
  # Promoted only now, with the same build that just passed. Nothing
  # is rebuilt in between, so what goes to the domain is the artefact
  # that was checked rather than another one like it.
  echo "deploy: promoting the checked build"
  # --scope, which deploy does not need and promote does: deploy reads
  # the team out of .vercel/project.json and promote looks the
  # deployment up under whatever the token's default team is, which is
  # not this one. "Deployment belongs to a different team" is what that
  # looks like.
  scope="$(sed -n 's/.*"orgId":"\([^"]*\)".*/\1/p' .vercel/project.json)"
  if ! npx --yes vercel@48 promote "$url" --yes --scope "$scope" \
      --token "$VERCEL_TOKEN" >"$log" 2>&1; then
    tail -20 "$log"; echo "deploy FAILED: could not promote $url"; exit 1
  fi
  # Promoted is not the same as live. The domain went on answering with
  # the previous build for seconds to a minute after promote returned,
  # twice, and a check run straight after "done" measured the old build
  # and nearly reported it as the new one. Done means the domain says so.
  live=""
  for _ in $(seq 1 60); do
    live="$(curl -s -o /dev/null -w '%{redirect_url}' https://brickworks.diy/app || true)"
    case "$live" in */b/"$sha"/*) break ;; esac
    sleep 3
  done
  case "$live" in
    */b/"$sha"/*) echo "deploy: brickworks.diy serves $sha" ;;
    *) echo "deploy FAILED: promoted, but brickworks.diy still serves ${live:-nothing} after 3 minutes"; exit 1 ;;
  esac
  echo "deploy done $url"
  echo "             https://brickworks.diy"
else
  echo "deploy done $url"
fi
rm -f "$log"
