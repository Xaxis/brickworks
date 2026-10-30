#!/usr/bin/env bash
# Put the web build on Vercel and prove it runs there.
#   tools/deploy.sh                 a preview URL, for looking at
#   tools/deploy.sh --prod          the one the domain points at
#   tools/deploy.sh --unit          a unit's preview (unit_preview.sh), without
#                                   the secrets unreviewed code is not to hold
#   tools/deploy.sh --unit --billing-stand-in
#                                   and with plans on in test mode against the
#                                   stand-in Admission, in its functions'
#                                   own process (api/_billing.js), for
#                                   tools/web/billing_flow.mjs
#   tools/deploy.sh --unit --billing-test
#                                   and with plans on in test mode against
#                                   the real Admission: ADMISSION_TEST_KEY
#                                   and, when set, ADMISSION_TEST_WEBHOOK_SECRET
#                                   from .env, for this deployment alone
#   tools/deploy.sh --unit --beta-open
#                                   and with the beta open (BRICKWORKS_BETA,
#                                   api/_beta.js), for tools/web/beta_flow.mjs
#   tools/deploy.sh --no-export     deploy what is already in build/web
#   tools/deploy.sh --no-check      skip the browser proof (not advised)
#   tools/deploy.sh --dir=DIR       deploy a build from elsewhere (a kept build: build/kept/<id>/web);
#                                   implies --no-export
#
# Needs VERCEL_TOKEN, from .env here or from the environment (CI). Never commit it.
#
# The build goes under /b/<sha>/ and /app serves its page, so every file can be
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

prod=0; unit=0; stand_in=0; billing_test=0; beta_open=0; do_export=1; do_check=1; dir=build/web
for a in "$@"; do
  case "$a" in
    --prod) prod=1 ;;
    --unit) unit=1 ;;
    --billing-stand-in) stand_in=1 ;;
    --billing-test) billing_test=1 ;;
    --beta-open) beta_open=1 ;;
    --no-export) do_export=0 ;;
    --no-check) do_check=0 ;;
    --dir=*) dir="${a#--dir=}"; do_export=0 ;;
    *) echo "deploy: unknown option $a"; exit 2 ;;
  esac
done
if [ "$prod" = 1 ] && [ "$unit" = 1 ]; then echo "deploy: --unit is a preview, never --prod"; exit 2; fi
if [ "$stand_in" = 1 ] && [ "$unit" = 0 ]; then echo "deploy: --billing-stand-in is a unit's preview's alone (--unit)"; exit 2; fi
if [ "$billing_test" = 1 ] && [ "$unit" = 0 ]; then echo "deploy: --billing-test is a unit's preview's alone (--unit)"; exit 2; fi
if [ "$billing_test" = 1 ] && [ "$stand_in" = 1 ]; then echo "deploy: --billing-test or --billing-stand-in, not both"; exit 2; fi
if [ "$beta_open" = 1 ] && [ "$unit" = 0 ]; then echo "deploy: --beta-open is a unit's preview's alone (--unit)"; exit 2; fi

[ -f .env ] && set -a && . ./.env && set +a
# A test key only, by its shape (api/_billing.js KEYS): a live key never
# reaches a preview, whatever .env holds. Never printed.
if [ "$billing_test" = 1 ] && ! [[ "${ADMISSION_TEST_KEY:-}" =~ ^adm_test_[0-9A-Za-z]{32}$ ]]; then
  echo "deploy: --billing-test needs an adm_test_ key in ADMISSION_TEST_KEY (.env)"; exit 2
fi
if [ "$billing_test" = 1 ] && [ -n "${ADMISSION_TEST_WEBHOOK_SECRET:-}" ] \
    && ! [[ "$ADMISSION_TEST_WEBHOOK_SECRET" =~ ^adm_whsec_ ]]; then
  echo "deploy: ADMISSION_TEST_WEBHOOK_SECRET is not an adm_whsec_ secret"; exit 2
fi
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
# The .gz siblings are for a server that negotiates; Vercel does its own.
# The .br of the engine, its packs and its script go too, and are what a
# browser taking brotli is sent (the route below): Vercel compressed them
# on the fly, which sent the wasm as 9.6 MB and the pack as 21 MB, where
# export.sh's brotli 11 makes 6.9 and 15 (load250, 2026-10-24).
SENT_BR="index.wasm index.pck index.parts.bin index.js"
for f in "$dir"/*; do
  case "$f" in *.gz|*/build.json) continue ;; esac
  case "$f" in *.br) case " $SENT_BR " in *" $(basename "$f" .br) "*) ;; *) continue ;; esac ;; esac
  [ -d "$f" ] && continue           # knowledge/, copied below
  cp "$f" ".vercel/output/static/b/$sha/"
done
for name in $SENT_BR; do
  [ -f ".vercel/output/static/b/$sha/$name.br" ] || { echo "deploy FAILED: no $name.br in $dir (tools/export.sh web)"; exit 1; }
done
# The real-set index beside the build (export.sh web), fetched by the app
# the first time a design asks for a technique; under /b/<sha>/, so cached
# forever like the rest of the build.
if [ ! -f "$dir/knowledge/snippets.json.gz" ] || [ ! -f "$dir/knowledge/part_looks.json" ]; then
  echo "deploy FAILED: no knowledge/ beside the build in $dir (tools/export.sh web)"; exit 1
fi
mkdir -p ".vercel/output/static/b/$sha/knowledge"
cp "$dir"/knowledge/* ".vercel/output/static/b/$sha/knowledge/"
# What this build is and when it went out, read by the app's Help panel.
# The owner, looking at the live site, could not tell when it had last
# been deployed.
printf '{"commit": "%s", "deployed": "%s"}\n' "$sha" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > ".vercel/output/static/b/$sha/version.json"
# And the same at the root, which is the build live wherever this deployment
# is: a tab open since an earlier deploy asks it now and then, never cached
# (the route below), and offers to reload once it names another build
# (src/boot/shell.html). People keep a tab open for hours.
cp ".vercel/output/static/b/$sha/version.json" .vercel/output/static/version.json

# The app is served at /app itself, not redirected to /b/<sha>/, so the
# address bar says brickworks.diy/app rather than a build hash. The page
# Godot exports names its files relative to itself (index.js, and an
# executable "index" the engine adds .wasm, .pck and .js to), which from
# /app would mean /index.js. A <base> would fix that in one line, but the
# security policy below says base-uri 'none' and stays that strict, so the
# names are made absolute here instead: the same file then works at /app
# and at /b/<sha>/, and every file it loads is still under /b/<sha>/ and
# cached forever. Fails rather than ship a page that would load nothing.
if ! python3 - ".vercel/output/static/b/$sha/index.html" "/b/$sha/" <<'PY'
import json, os, re, sys
path, base = sys.argv[1], sys.argv[2]
here = os.path.dirname(path)
page = open(path, encoding="utf-8").read()

def absolute(m):
    name = m.group(2)
    if "/" in name or ":" in name or not os.path.isfile(os.path.join(here, name)):
        return m.group(0)
    return f'{m.group(1)}="{base}{name}"'
page = re.sub(r'\b(src|href)="([^"]*)"', absolute, page)

found = re.search(r"const GODOT_CONFIG = ", page)
if not found:
    sys.exit("no GODOT_CONFIG in the exported page")
config, end = json.JSONDecoder().raw_decode(page, found.end())
exe = config["executable"]
config["executable"] = base + exe
# The engine looks sizes up by the very path it fetches, so the keys move too.
config["fileSizes"] = {base + k: v for k, v in config.get("fileSizes", {}).items()}
page = page[:found.end()] + json.dumps(config, separators=(",", ":")) + page[end:]
if f'src="{base}{exe}.js"' not in page:
    sys.exit(f"the engine's script ({exe}.js) is not named from {base}")
open(path, "w", encoding="utf-8").write(page)
PY
then
  echo "deploy FAILED: could not point the app's page at /b/$sha/"; exit 1
fi

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
# one for a visitor's read): /m/<id>, its pictures (.png, .cutout.png for
# its page, and .webp for the gallery's cards) and its card are mapped
# onto it, and the LDraw library's sets, each a page at /library/<id> with its
# pictures (.webp the card's, .cutout.webp the page's, .cover.webp the app's
# cover), its file (.mpd) and its parts (api/_library.js; /library is
# web/library.html). /api/people is who shares them and what is done with them
# (supabase/people.sql): profiles at /u/<handle>, collections at /c/<id>,
# likes and favourites; the site's header and footer beside it too, as
# _site.html. The viewer is /app?view=<id>: /app is the app's page itself,
# query and all, so it needs no route of its own. Vercel's cron calls /api/share/sweep at
# 04:17 UTC every day, with CRON_SECRET (set on the project, and in .env
# for share_probe): it takes away the files of models whose row went with
# a deleted account. At 04:47 it calls /api/otp/canary (api/_canary.js), the
# same way: a public sign-up, an unconfirmed address and a new person's code
# played through, the owner mailed if one fails. At 00:07 it calls
# /api/share/feature, which keeps the day's choice of the gallery's front
# (api/_featured.js), and on Mondays at 05:37 /api/share/omr, the week's
# look at LDraw's OMR for sets the library has not got (api/_omr_watch.js);
# each under its own lock, each run written down (supabase/gallery_crons.sql).
# At 05:07 the beta's daily run (/api/plans/beta-daily, api/_beta.js): a
# tester's month given once Pro launches, a reminder three days before one
# ends, and declined applications erased after 90 days.
# Its pages send their own
# security policy; the app's below does not change, since the viewer talks
# only to its own site.
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
  # The one model card (web/card.js), which api/_card.js passes through in
  # a checkout: here the file itself, so a function needs no web/.
  cp web/card.js "$fn/_card.js"
  # The stand-in Admission, beside the function only on a preview that asks
  # for it: no other deployment holds it at all.
  if [ "$stand_in" = 1 ]; then cp tests/fixtures/billing/fake_admission.mjs "$fn/_admission_stand_in.mjs"; fi
  if [ "$route" = collection ]; then
    if [ ! -f assets/generated/sets/index.json ]; then
      echo "deploy FAILED: no assets/generated/sets/index.json for /api/collection (tools/collection_data.py)"; exit 1
    fi
    cp assets/generated/sets/index.json "$fn/_collection_index.json"
  fi
  # The relay lists the tools of the app build it serves until a tab has
  # said hello (api/mcp.js, ownTools): the app's own list, from this build.
  if [ "$route" = mcp ] && ! cp tools/mcp_tools.json "$fn/_mcp_tools.json"; then
    echo "deploy FAILED: no tools/mcp_tools.json for /api/mcp"; exit 1
  fi
  # A shared model's page, and what the gallery filters on (api/_directory.js):
  # the site's header and footer, from the gallery's own page, so /m/<id> is a
  # page of the site and changes when the site's do; and which parts are
  # Technic and which make a model move, from the catalogue, counted when a
  # model is published.
  if [ "$route" = share ] || [ "$route" = people ]; then
    cp web/gallery.html "$fn/_site.html"
  fi
  if [ "$route" = share ]; then
    # /sitemap.xml is made there: the site's own pages, from web/sitemap.xml,
    # and every listed model, profile and public collection.
    cp web/sitemap.xml "$fn/_sitemap.xml"
    if ! node tools/web/part_facts.mjs "$fn/_part_facts.json" --parts="$fn/_parts_table.json" | sed 's/^/deploy: /'; then
      echo "deploy FAILED: no part facts for /api/share (tools/web/part_facts.mjs)"; exit 1
    fi
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
  # And their exact shapes for the build check, fetched from beside them.
  cp assets/web/remote/*.bwx .vercel/output/static/parts/ 2>/dev/null || true
  count=$(ls -1 .vercel/output/static/parts 2>/dev/null | wc -l | tr -d ' ')
  echo "deploy: $count parts served on demand"
fi

# The landing page sits at the root and the application at /app. Before
# this, / redirected straight into the build, so there was nowhere to
# say what the thing is.
#
# Everything in web/, not just the page. It copied index.html alone,
# which meant the favicon, the manifest and the Open Graph image —
# every file the page references by an absolute path — were simply
# absent from the deployment, and a shared link showed no picture.
# tools/site.py does the copying (leaving out working files whose names
# start with an underscore) and writes the changelog page from
# CHANGELOG.md, so it cannot say anything the release notes do not.
python3 tools/site.py .vercel/output/static | sed 's/^/deploy: /' || {
  echo "deploy FAILED: could not put the website together (tools/site.py)"; exit 1; }
[ -f .vercel/output/static/index.html ] && [ -f .vercel/output/static/404.html ] || {
  echo "deploy FAILED: the website has no index.html or 404.html"; exit 1; }

# The site's pages at addresses without .html: /download, not
# /download.html. The owner, 2026-10-12: "do you realize how oldschool
# that is?" Every page but three is served at its bare name (the
# override), and its old .html address answers with a permanent redirect
# to it, so a link anyone kept still lands. The three: index.html is /,
# 404.html is what any unknown address gets, with a 404, and
# authorize.html is only ever /oauth/authorize, where Claude sends people.
pages=""
# The .br files keep their own file's type: instantiateStreaming takes a
# wasm only as application/wasm.
overrides="\"b/$sha/index.wasm.br\": { \"contentType\": \"application/wasm\" },
    \"b/$sha/index.pck.br\": { \"contentType\": \"application/octet-stream\" },
    \"b/$sha/index.parts.bin.br\": { \"contentType\": \"application/octet-stream\" },
    \"b/$sha/index.js.br\": { \"contentType\": \"application/javascript; charset=utf-8\" }"
for page in .vercel/output/static/*.html; do
  name=$(basename "$page" .html)
  case "$name" in index|404|authorize) continue ;; esac
  pages="$pages${pages:+|}$name"
  overrides="$overrides${overrides:+,}\"$name.html\": { \"path\": \"$name\", \"contentType\": \"text/html; charset=utf-8\" }"
done
echo "deploy: pages at /${pages//|/, /}"
# The documentation (tools/docs_site.py, run by tools/site.py): /docs is
# docs.html, a page like the others above, and each of its pages is
# /docs/<name>, from docs/<name>.html, its .html address redirected below.
docs=0
for page in .vercel/output/static/docs/*.html; do
  [ -e "$page" ] || continue
  name=$(basename "$page" .html)
  overrides="$overrides,\"docs/$name.html\": { \"path\": \"docs/$name\", \"contentType\": \"text/html; charset=utf-8\" }"
  docs=$((docs + 1))
done
[ "$docs" -gt 0 ] || { echo "deploy FAILED: tools/site.py wrote no documentation pages (docs/)"; exit 1; }
# A docs page that moved (docs-site/_moved.json) answers at its old address
# with a 308 to its new one, so a link anyone kept still lands.
docs_moved=$(python3 -c 'import json; m = json.load(open("docs-site/_moved.json"))
print("".join("    { \"src\": \"/docs/%s(/|[.]html)?\", \"status\": 308, \"headers\": { \"Location\": \"/docs/%s\" } },\n" % (a, b)
               for a, b in sorted(m.items()) if not a.startswith("$")), end="")') || {
  echo "deploy FAILED: could not read docs-site/_moved.json"; exit 1; }
echo "deploy: $docs documentation pages at /docs/"

# What the pages may load and, above all, where they may send anything.
#
# The app holds a person's Anthropic key in the browser. The best defence
# for that is a short list of places the page can talk to at all: itself,
# Anthropic, Wikimedia (reference pictures), Rebrickable (a person's own
# sets and parts lists, read with their own Rebrickable key: My collection),
# Brickognize (a photo the person chose, to find the part in it: the parts
# bin's camera, src/net/brickognize.gd), the parts store and the sign-in service — so even a script that should
# never have run has nowhere to send a key. The page's one inline script is allowed by its
# hash, not by allowing inline scripts; 'unsafe-eval' stays because
# Godot's JavaScript bridge evaluates what the app asks of the browser
# (its size, its address, the clipboard).
#
# The sign-in service is Supabase (SUPABASE_URL), where a code is
# redeemed and a session renewed. Named on its own: it was reachable only
# because the parts store happens to be in the same project, and moving
# the parts would have broken every sign-in without a word.
#
# The hash is of the page as served, after its file names were made
# absolute above, not of the page the export wrote.
inline_hashes="$(python3 - ".vercel/output/static/b/$sha/index.html" <<'PY'
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
csp="default-src 'self'; script-src 'self' 'unsafe-eval' 'wasm-unsafe-eval' ${inline_hashes} https://overlook.technology; worker-src 'self' blob:; connect-src 'self' https://overlook.technology https://api.anthropic.com https://commons.wikimedia.org https://upload.wikimedia.org https://rebrickable.com https://api.brickognize.com ${connect_extra}; img-src 'self' data: blob:; style-src 'self' 'unsafe-inline'; font-src 'self' data:; media-src 'self' blob:; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
# Where Claude sends someone to sign in (web/authorize.html). Stricter than
# the app's: no eval, and it talks only to itself and the sign-in service.
# And none of the cross-origin isolation headers: the app's threaded build
# needs those, and a page claude.ai opens must not cut itself off from the
# window that opened it, which Cross-Origin-Opener-Policy would.
authorize_csp="default-src 'self'; script-src 'self'; connect-src 'self' ${signin_origin}; img-src 'self' data:; style-src 'self' 'unsafe-inline'; object-src 'none'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"

# The site's other pages may open a window that answers them: orangecheck's
# sign-in window hands the page its token through window.opener, which
# Cross-Origin-Opener-Policy: same-origin cuts (2026-10-23,
# api/orangecheck.js). So they send same-origin-allow-popups, and only the
# app keeps same-origin (/app and the build under /b/): cross-origin
# isolation, which its threads need, asks for exactly that.

# Addresses that are not pages, said once each. An unknown one used to be
# redirected to the landing page, which told a mistyped link nothing and
# told a search engine every typo was the home page. It gets the 404 page,
# with a 404, now. The app is /app itself (a rewrite, so the address bar
# keeps it, ?view= and ?model= and all), never cached, since it is what
# names the build; the build it names under /b/<sha>/ is cached forever.
cat > .vercel/output/config.json <<EOF
{
  "version": 3,
  "crons": [ { "path": "/api/share/sweep", "schedule": "17 4 * * *" },
             { "path": "/api/otp/canary", "schedule": "47 4 * * *" },
             { "path": "/api/share/feature", "schedule": "7 0 * * *" },
             { "path": "/api/share/omr", "schedule": "37 5 * * 1" },
             { "path": "/api/plans/beta-daily", "schedule": "7 5 * * *" } ],
  "overrides": { $overrides },
  "routes": [
    { "src": "/index[.]html", "status": 308, "headers": { "Location": "/" } },
    { "src": "/authorize[.]html", "status": 308, "headers": { "Location": "/oauth/authorize" } },
    { "src": "/challenges/?", "status": 308, "headers": { "Location": "/challenge" } },
    { "src": "/([A-Za-z0-9_-]+)[.]html", "status": 308, "headers": { "Location": "/\$1" } },
$docs_moved
    { "src": "/docs/([A-Za-z0-9_-]+)[.]html", "status": 308, "headers": { "Location": "/docs/\$1" } },
    { "src": "/(app|$pages)/", "status": 308, "headers": { "Location": "/\$1" } },
    { "src": "/api/share/sweep", "dest": "/api/share?op=sweep" },
    { "src": "/api/otp/canary", "dest": "/api/otp?op=canary" },
    { "src": "/api/share/feature", "dest": "/api/share?op=feature" },
    { "src": "/api/share/omr", "dest": "/api/share?op=omr" },
    { "src": "/api/plans/beta-daily", "dest": "/api/plans?op=beta_daily" },
    { "src": "/sitemap[.]xml", "dest": "/api/share?op=sitemap" },
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
    { "src": "/m/([A-Za-z0-9]{10})/v/([1-9][0-9]{0,5})/?", "dest": "/api/share?op=page&id=\$1&v=\$2" },
    { "src": "/m/([A-Za-z0-9]{10})/v/([1-9][0-9]{0,5})[.]mpd", "dest": "/api/share?op=file&id=\$1&v=\$2" },
    { "src": "/m/([A-Za-z0-9]{10})/v/([1-9][0-9]{0,5})/parts[.](json|xml|csv)", "dest": "/api/share?op=parts&id=\$1&v=\$2&as=\$3" },
    { "src": "/m/([A-Za-z0-9]{10})/v/([1-9][0-9]{0,5})[.]png", "dest": "/api/share?op=image&id=\$1&v=\$2" },
    { "src": "/m/([A-Za-z0-9]{10})/v/([1-9][0-9]{0,5})[.]cutout[.]png", "dest": "/api/share?op=cutout&id=\$1&v=\$2" },
    { "src": "/m/([A-Za-z0-9]{10})/?", "dest": "/api/share?op=page&id=\$1" },
    { "src": "/m/([A-Za-z0-9]{10})[.]png", "dest": "/api/share?op=image&id=\$1" },
    { "src": "/m/([A-Za-z0-9]{10})[.]cutout[.]png", "dest": "/api/share?op=cutout&id=\$1" },
    { "src": "/m/([A-Za-z0-9]{10})[.]webp", "dest": "/api/share?op=thumb&id=\$1" },
    { "src": "/m/([A-Za-z0-9]{10})[.]mpd", "dest": "/api/share?op=file&id=\$1" },
    { "src": "/m/([A-Za-z0-9]{10})/parts[.](json|xml|csv)", "dest": "/api/share?op=parts&id=\$1&as=\$2" },
    { "src": "/m/([A-Za-z0-9]{10})/embed/?", "dest": "/api/share?op=embed&id=\$1" },
    { "src": "/u/([a-z0-9-]{3,24})/?", "dest": "/api/people?op=page&handle=\$1" },
    { "src": "/c/([A-Za-z0-9]{10})/?", "dest": "/api/people?op=list_page&id=\$1" },
    { "src": "/collections/?", "dest": "/api/people?op=collections_page" },
    { "src": "/library/([a-z]{2,8}-[A-Za-z0-9_-]{1,120})/?", "dest": "/api/share?op=set&id=\$1" },
    { "src": "/library/([a-z]{2,8}-[A-Za-z0-9_-]{1,120})[.]webp", "dest": "/api/share?op=set_cover&id=\$1" },
    { "src": "/library/([a-z]{2,8}-[A-Za-z0-9_-]{1,120})[.](cutout|cover)[.]webp", "dest": "/api/share?op=set_cover&id=\$1&as=\$2" },
    { "src": "/library/([a-z]{2,8}-[A-Za-z0-9_-]{1,120})[.]mpd", "dest": "/api/share?op=set_file&id=\$1" },
    { "src": "/library/([a-z]{2,8}-[A-Za-z0-9_-]{1,120})/parts[.](json|xml|csv)", "dest": "/api/share?op=set_parts&id=\$1&as=\$2" },
    { "src": "/parts/(.*[.](lbm|bwx))", "headers": {
        "Cache-Control": "public, max-age=31536000, immutable" } },
    { "src": "/(.*)",
      "headers": {
        "Cross-Origin-Opener-Policy": "same-origin-allow-popups",
        "Cross-Origin-Embedder-Policy": "require-corp",
        "Cross-Origin-Resource-Policy": "same-origin",
        "X-Content-Type-Options": "nosniff",
        "Referrer-Policy": "no-referrer",
        "Content-Security-Policy": "$csp"
      },
      "continue": true },
    { "src": "/(app|b/.*)",
      "headers": { "Cross-Origin-Opener-Policy": "same-origin" },
      "continue": true },
    { "src": "/b/([^/]+)/(.*)",
      "headers": { "Cache-Control": "public, max-age=31536000, immutable",
        "X-Robots-Tag": "noindex" },
      "continue": true },
    { "src": "/b/$sha/(index[.](wasm|pck|js|parts[.]bin))",
      "has": [ { "type": "header", "key": "accept-encoding", "value": ".*br.*" } ],
      "dest": "/b/$sha/\$1.br",
      "headers": { "Content-Encoding": "br", "Vary": "Accept-Encoding" } },
    { "src": "/b/$sha/(index[.](wasm|pck|js|parts[.]bin))",
      "headers": { "Vary": "Accept-Encoding" },
      "continue": true },
    { "src": "/img/(.*)",
      "headers": { "Cache-Control": "public, max-age=86400, stale-while-revalidate=2592000" },
      "continue": true },
    { "src": "/version[.]json",
      "headers": { "Cache-Control": "no-store" },
      "continue": true },
    { "src": "/app", "dest": "/b/$sha/index.html",
      "headers": { "Cache-Control": "no-cache" } },
    { "src": "/b/([^/]+)/?$", "dest": "/b/\$1/index.html" },
    { "handle": "filesystem" },
    { "src": "/parts/(.*)", "status": 404,
      "headers": { "Content-Type": "text/plain" } },
    { "src": "/sets/(.*)", "status": 404,
      "headers": { "Content-Type": "text/plain" } },
    { "src": "/(.*)", "status": 404, "dest": "/404.html" }
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
# Always uploaded unpromoted, even when the domain is the destination.
#
# --prod alone promotes on upload, so the check that follows runs against a
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
#
# --prod --skip-domain: a production build that no domain points at until
# it is promoted. Vercel builds a team's production deployments before its
# previews, and while the team's other projects deployed to production one
# after another, a preview of this one sat queued for 49 minutes, twice,
# until the release gave up (m112, 2026-10-20). Staged, it waits its turn
# as production does, and promoting it moves the domain onto this build
# rather than queueing a second one. Preview and production differ only in
# a key no page or API here reads, so the checks see what production runs.
#
# So every deployment gets every production secret, and a unit's preview
# runs code nobody has reviewed. --unit withholds the four it never needs:
# OC_SIGNING_SECRET, which orangecheck asked be kept from unreviewed branch
# code, since their review covers what ships (2026-10-23), and for the same
# reason OC_CONNECT_KEY, which makes and deletes orangecheck accounts
# (2026-10-24, api/_oc.js provision); RESEND_API_KEY,
# so unreviewed code cannot send mail from brickworks.diy (2026-10-24; a
# test inbox still signs in, api/otp.js deliver); and ANTHROPIC_API_KEY,
# which nothing has read since the proxy that spent it went (2026-10-09). --env NAME= sets one to nothing for this deployment
# alone, over the project's value. Never --env NAME: that sends the value
# in .env. A release's preview and production are reviewed code, and keep
# both.
withheld=(OC_SIGNING_SECRET OC_CONNECT_KEY RESEND_API_KEY ANTHROPIC_API_KEY)
blank=()
if [ "$unit" = 1 ]; then
  for k in "${withheld[@]}"; do blank+=(--env "$k="); done
  echo "deploy: a unit's preview, without ${withheld[*]}"
fi
# Plans on for this deployment alone, never on the project (api/_billing.js):
# test mode, the stand-in's own key and webhook secret (a test's, nobody's
# real one: tests/fixtures/billing/fake_admission.mjs), and the stand-in
# asked for by name, so no request leaves the function for Admission.
if [ "$stand_in" = 1 ]; then
  blank+=(--env BRICKWORKS_BILLING=test --env ADMISSION_KEY=adm_test_00000000000000000000000000000000
    --env ADMISSION_URL=stand-in --env ADMISSION_WEBHOOK_SECRET=adm_whsec_standin0000000000000000000000)
  echo "deploy: plans on in test mode, against the stand-in Admission"
fi
# Or against the real Admission in test mode (billtest358, 2026-10-29): its
# test key, Stripe's sandbox, no money. ADMISSION_URL set to nothing, so
# the client asks admission.sh whatever the project holds. The webhook
# secret only when .env has one (Admission's test webhook, pointed at this
# preview with the protection bypass on its URL); without it the webhook
# answers 404 here and the rest still runs.
if [ "$billing_test" = 1 ]; then
  blank+=(--env BRICKWORKS_BILLING=test --env "ADMISSION_KEY=$ADMISSION_TEST_KEY" --env ADMISSION_URL=
    --env "ADMISSION_WEBHOOK_SECRET=${ADMISSION_TEST_WEBHOOK_SECRET:-}")
  echo "deploy: plans on in test mode, against Admission's test mode$([ -n "${ADMISSION_TEST_WEBHOOK_SECRET:-}" ] && echo ", its webhook signed" || echo ", no webhook secret")"
fi
# The beta open for this deployment alone (api/_beta.js), never on the
# project: production's stays off until the owner says.
if [ "$beta_open" = 1 ]; then
  blank+=(--env BRICKWORKS_BETA=open)
  echo "deploy: the beta open"
fi
npx --yes vercel@48 deploy --prebuilt --prod --skip-domain --yes --archive=tgz \
  ${blank[@]+"${blank[@]}"} --token "$VERCEL_TOKEN" >"$log" 2>&1
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
  # It says 2 when the app did not start at a size, which on a loaded
  # machine is not the layout.
  node tools/web/fit_check.mjs --url="$url/app" --quick --out=shots/fit \
      ${VERCEL_BYPASS:+--bypass="$VERCEL_BYPASS"}
  case $? in
    0) ;;
    2) echo "deploy FAILED: the app did not start at every size at $url/app"; exit 1 ;;
    *) echo "deploy FAILED: the app does not fit the page at $url/app"; exit 1 ;;
  esac

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
    # /app is the page itself now, which names its build's files; a
    # deployment from before that redirected to /b/<sha>/ instead.
    live="$(curl -s --max-time 20 https://brickworks.diy/app | grep -o '/b/[^/"]*/' | head -1 || true)"
    [ -z "$live" ] && live="$(curl -s -o /dev/null -w '%{redirect_url}' https://brickworks.diy/app || true)"
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
