#!/usr/bin/env bash
# package_api.sh OUT [--export=DIR] [--stand-in] [ROUTE...]
# The serverless functions as tools/deploy.sh ships them: OUT/api/<route>.func
# for every api/<route>.js (or the ROUTEs named), each with the shared
# modules beside it and what it reads (deploy.sh says what each route is).
# deploy.sh packages with it, and so do the checks that have to run a
# function as it is deployed (tools/release/ci_gate.sh, lb2check's bundled
# run), so the two cannot differ.
#   --export=DIR   the web build's folder (tools/export.sh web), for the
#                  share function's part names in each language
#   --stand-in     the stand-in Admission beside each (a unit's preview,
#                  deploy.sh --billing-stand-in)
# Run from the checkout's root. Fails, naming what is missing, when a file a
# function reads is not there, and when a packaged function cannot read the
# catalogue's facts.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1
out=""; dir=build/web; stand_in=0; only=()
for a in "$@"; do
  case "$a" in
    --export=*) dir="${a#--export=}" ;;
    --stand-in) stand_in=1 ;;
    --*) echo "package_api: unknown option $a"; exit 2 ;;
    *) if [ -z "$out" ]; then out="$a"; else only+=("$a"); fi ;;
  esac
done
[ -n "$out" ] || { echo "package_api: name the folder to package into"; exit 2; }
wanted() { [ "${#only[@]}" = 0 ] || [[ " ${only[*]} " == *" $1 "* ]]; }

# The catalogue's facts, made once for every function: which parts are
# Technic and which make a model move (api/_directory.js), and the part
# numbers LDraw moved and the colours a shop files under another
# (api/_owned.js ownedFacts), and for the share function its parts list's
# and 3D view's tables. Every function gets _part_facts.json, as every one
# gets every shared module: rel-m285 gave it to /api/share alone, so
# /api/collection (a Rebrickable fetch's marks) and /api/admin (a challenge
# set's parts) counted every part by the number it was written with, and
# 4073 was not 6141 (lb2check M2).
facts=$(mktemp -d "${TMPDIR:-/tmp}/package_api.XXXXXX") || exit 1
trap 'rm -rf "$facts"' EXIT
tables=()
if wanted share; then tables=(--parts="$facts/_parts_table.json" --scene="$facts/_scene_table.json"); fi
if ! node tools/web/part_facts.mjs "$facts/_part_facts.json" "${tables[@]}" | sed 's/^/deploy: /' \
    || [ ! -s "$facts/_part_facts.json" ]; then
  echo "deploy FAILED: no part facts for the functions (tools/web/part_facts.mjs)"; exit 1
fi

packed=()
for handler in api/*.js; do
  [ -f "$handler" ] || continue
  route=$(basename "$handler" .js)
  case "$route" in _*) continue ;; esac
  wanted "$route" || continue

  fn="$out/api/$route.func"
  mkdir -p "$fn"
  cp "$handler" "$fn/index.mjs"
  for shared in api/_*.js; do
    [ -f "$shared" ] && cp "$shared" "$fn/"
  done
  cp "$facts/_part_facts.json" "$fn/_part_facts.json"
  # The one model card (web/card.js), which api/_card.js passes through in
  # a checkout: here the file itself, so a function needs no web/.
  cp web/card.js "$fn/_card.js"
  # And the one pager (web/pager.js), which api/_pager.js passes through.
  cp web/pager.js "$fn/_pager.js"
  # A part's geometry as the app reads it (web/lbm.js), which api/_lbm.js
  # passes through in a checkout: the pictures the share function draws of
  # a set's parts (api/_flatlay.js).
  cp web/lbm.js "$fn/_lbm.js"
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
  # A page in German, French or Spanish (/de/library/set/<n>, /de/m/<id>,
  # /de/u/<handle>): the gallery's copy for its header and footer, and the
  # words the site says in each language (tools/site_lang.py), as
  # api/_directory.js reads them. Every route that asks siteWords: people's
  # profiles went without until rel-m245's preview answered 404.
  if [ "$route" = share ] || [ "$route" = people ]; then
    for words in web/*/words.json; do
      lang=$(basename "$(dirname "$words")")
      cp "$words" "$fn/_words_$lang.json"
      cp "web/$lang/gallery.html" "$fn/_site_$lang.html"
    done
  fi
  # And a parts list's part, colour and category names in each, as the
  # build's app says them (tools/export.sh, src/dev/write_part_names.gd).
  if [ "$route" = share ]; then
    for words in web/*/words.json; do
      lang=$(basename "$(dirname "$words")")
      if ! cp "$dir/part_names/part_names_$lang.json" "$fn/_part_names_$lang.json"; then
        echo "deploy FAILED: no $dir/part_names/part_names_$lang.json (tools/export.sh web)"; exit 1
      fi
    done
  fi
  # /challenge?id=N is the challenge page with that challenge's own head
  # (api/_challenges.js challengeHead), so a link to one shows it; and
  # /de/challenge?id=N its copy's (tools/site_lang.py).
  if [ "$route" = people ]; then
    cp web/challenge.html "$fn/_challenge.html"
    for copy in web/*/challenge.html; do
      cp "$copy" "$fn/_challenge_$(basename "$(dirname "$copy")").html"
    done
  fi
  if [ "$route" = share ]; then
    # /sitemap.xml is made there: the site's own pages, from web/sitemap.xml,
    # and every listed model, profile and public collection.
    cp web/sitemap.xml "$fn/_sitemap.xml"
    cp "$facts/_parts_table.json" "$fn/_parts_table.json"
    cp "$facts/_scene_table.json" "$fn/_scene_table.json"
    # Every set in Rebrickable's catalogue, a page each at /library/set/<n>
    # (api/_sets.js): written from the vendored CSVs and the set shards,
    # a few seconds, and only rewritten when it would change.
    if ! python3 tools/set_catalog.py | sed 's/^/deploy: /' || [ ! -f assets/generated/set_catalog.json ]; then
      echo "deploy FAILED: no set catalogue for /api/share (tools/set_catalog.py)"; exit 1
    fi
    cp assets/generated/set_catalog.json "$fn/_set_catalog.json"
  fi
  # The handler is .mjs and so is unambiguously a module; the shared
  # files it imports are .js, which Node classifies by the nearest
  # package.json — and a function bundle has none. Node 22 does detect
  # module syntax and gets it right without this, so the marker is not
  # load-bearing today; it is here so the answer does not depend on a
  # heuristic that a runtime bump could change underneath us.
  echo '{ "type": "module" }' > "$fn/package.json"
  # Build together's poll answers a line at a time, who is in it and where
  # each is working as it changes (api/together.js poll): without this
  # Vercel holds every line until the last, and a pointer is seen up to
  # 20 s late.
  streams=false; [ "$route" = together ] && streams=true
  cat > "$fn/.vc-config.json" <<JSON
{
  "runtime": "nodejs22.x",
  "handler": "index.mjs",
  "launcherType": "Nodejs",
  "shouldAddHelpers": true,
  "supportsResponseStreaming": $streams,
  "maxDuration": 300
}
JSON
  packed+=("$route")
  echo "deploy: packaged /api/$route"
done
[ "${#packed[@]}" -gt 0 ] || { echo "deploy FAILED: no function packaged (${only[*]:-api/*.js})"; exit 1; }

# Each function as packaged, its own shared modules read from its own folder,
# with nothing of the checkout's beside it: the catalogue's facts there.
if ! node tools/web/packaged_facts.mjs "$out" "${packed[@]}"; then
  echo "deploy FAILED: a packaged function cannot read the catalogue's facts (tools/web/packaged_facts.mjs)"; exit 1
fi
