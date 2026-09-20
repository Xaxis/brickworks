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
cd "$(dirname "$0")/.."

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
# Project and org come from .vercel/project.json, written by `vercel link`.

if [ "$do_export" = 1 ]; then
  tools/export.sh web || exit 1
fi
[ -f "$dir/index.html" ] || { echo "deploy FAILED: no build in $dir (tools/export.sh web)"; exit 1; }

sha="$(git rev-parse --short HEAD)"
[ -n "$(git status --porcelain --untracked-files=no)" ] && sha="$sha-dirty"

rm -rf .vercel/output
mkdir -p ".vercel/output/static/b/$sha"
# The .br and .gz siblings are for a server that negotiates; Vercel does its own.
for f in "$dir"/*; do
  case "$f" in *.br|*.gz|*/build.json) continue ;; esac
  cp "$f" ".vercel/output/static/b/$sha/"
done

# The serverless endpoints, packaged the way the Build Output API wants
# them. A prebuilt deploy has no build step to discover api/, so each is
# assembled here: a directory per route, the handler inside it, and a
# .vc-config.json saying how to run it.
#
# Every route gets its own copy of the shared modules — the ones named
# with a leading underscore, which are imports rather than routes. A
# function directory is its own bundle with nothing outside it on the
# path, so a route importing ./_auth.js finds nothing unless the file is
# sitting beside it.
#
# They need ANTHROPIC_API_KEY, SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY and
# SUPABASE_SECRET_KEY set on the project. Missing the Anthropic key makes
# the assistant answer 503 and say so; missing the Supabase ones makes it
# refuse sign-in rather than fall open, which is the safer of the two
# ways to be misconfigured while holding an API key.
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
  cp web/index.html .vercel/output/static/index.html
  [ -f shots/ui3.png ] && cp shots/ui3.png .vercel/output/static/shot-app.png
  echo "deploy: landing page at /"
fi

cat > .vercel/output/config.json <<EOF
{
  "version": 3,
  "routes": [
    { "src": "/api/(.*)", "dest": "/api/\$1" },
    { "src": "/parts/(.*[.]lbm)", "headers": {
        "Cache-Control": "public, max-age=31536000, immutable" } },
    { "src": "/parts/(.*)", "status": 404,
      "headers": { "Content-Type": "text/plain" } },
    { "src": "/app/?", "status": 308, "headers": { "Location": "/b/$sha/" } },
    { "src": "/(.*)",
      "headers": {
        "Cross-Origin-Opener-Policy": "same-origin",
        "Cross-Origin-Embedder-Policy": "require-corp",
        "Cross-Origin-Resource-Policy": "same-origin",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer"
      },
      "continue": true },
    { "src": "/b/([^/]+)/(.*)",
      "headers": { "Cache-Control": "public, max-age=31536000, immutable" },
      "continue": true },
    { "src": "/b/([^/]+)/?$", "dest": "/b/\$1/index.html" },
    { "handle": "filesystem" },
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

echo "deploy $sha -> vercel ($([ "$prod" = 1 ] && echo production || echo preview))"
log="$(mktemp "${TMPDIR:-/tmp}/brickworks-deploy.XXXXXX")"
if [ "$prod" = 1 ]; then
  # --archive=tgz sends one tarball rather than a file at a time. Both
  # of this deploy's failures were in the per-file uploader: it aborted
  # Node outright on fourteen thousand files, and then twice returned a
  # 500 as an HTML page that the CLI tried to parse as JSON. Neither is
  # something this end can fix, and neither happens with one upload.
  npx --yes vercel@48 deploy --prebuilt --prod --yes --archive=tgz --token "$VERCEL_TOKEN" >"$log" 2>&1
else
  npx --yes vercel@48 deploy --prebuilt --yes --archive=tgz --token "$VERCEL_TOKEN" >"$log" 2>&1
fi
code=$?
url="$(grep -oE 'https://[a-zA-Z0-9.-]+\.vercel\.app' "$log" | tail -1)"
if [ $code -ne 0 ] || [ -z "$url" ]; then
  tail -20 "$log"; echo "deploy FAILED"; rm -f "$log"; exit 1
fi
rm -f "$log"
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

  # The landing page is what most people meet first, so a deploy that
  # serves the app but not the page is still a broken deploy.
  landing=$(curl -s -o /dev/null -w "%{http_code}" --max-time 30 \
    ${VERCEL_BYPASS:+-H "x-vercel-protection-bypass: $VERCEL_BYPASS"} "$url/")
  if [ "$landing" != "200" ]; then
    echo "deploy FAILED: the landing page answers $landing at $url/"; exit 1
  fi
  echo "deploy: landing page ok, app runs"
fi
if [ "$prod" = 1 ]; then
  echo "deploy done $url"
  echo "             https://brickworks.diy"
else
  echo "deploy done $url"
fi
