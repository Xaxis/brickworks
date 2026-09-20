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

# The design assistant's proxy, packaged the way the Build Output API
# wants it. A prebuilt deploy has no build step to discover api/, so the
# function is assembled here: a directory per route, the handler inside
# it, and a .vc-config.json saying how to run it.
#
# It needs ANTHROPIC_API_KEY set on the project. Without it the endpoint
# answers 503 and says the assistant is not configured, which is a
# better failure than a blank panel.
if [ -f api/claude.js ]; then
  fn=.vercel/output/functions/api/claude.func
  mkdir -p "$fn"
  cp api/claude.js "$fn/index.mjs"
  cat > "$fn/.vc-config.json" <<'JSON'
{
  "runtime": "nodejs22.x",
  "handler": "index.mjs",
  "launcherType": "Nodejs",
  "shouldAddHelpers": true,
  "maxDuration": 300
}
JSON
  echo "deploy: packaged /api/claude"
fi

cat > .vercel/output/config.json <<EOF
{
  "version": 3,
  "routes": [
    { "src": "/api/(.*)", "dest": "/api/\$1" },
    { "src": "/", "status": 308, "headers": { "Location": "/b/$sha/" } },
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
    { "src": "/(.*)", "status": 308, "headers": { "Location": "/b/$sha/" } }
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
  npx --yes vercel@48 deploy --prebuilt --prod --yes --token "$VERCEL_TOKEN" >"$log" 2>&1
else
  npx --yes vercel@48 deploy --prebuilt --yes --token "$VERCEL_TOKEN" >"$log" 2>&1
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
  node tools/web/web.mjs --url="$url" --out=shots/export/deploy --play --reload || {
    echo "deploy FAILED: the build does not run at $url"; exit 1; }
fi
if [ "$prod" = 1 ]; then
  echo "deploy done $url"
  echo "             https://brickworks.diy"
else
  echo "deploy done $url"
fi
