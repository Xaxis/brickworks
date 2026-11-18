#!/bin/bash
# live_export.sh : the web export brickworks.diy serves, kept for the web lane.
#
#   live_export.sh show                  "DIR SHA TAG": the export kept, the commit it was made
#                                        from and the release that made it; exit 1 when none is
#   live_export.sh keep TAG SHA DIR      DIR (a build/web) kept as the live export, made from SHA
#   live_export.sh app FROM TO           the files between commits or trees FROM and TO that a
#                                        web export is made from, one a line (none: the web lane)
#
# A release whose app is the one brickworks.diy already runs needs no export,
# no import and no probe: the social desk's train ran all 294 probes and
# named 62 checks for a change to web/ and api/ alone, and the lead shipped
# it by hand on the live release's build/web instead (fastlane, 2026-11-18).
# A train's release worktree goes once it is live (train.sh retire), its
# build/web with it, so ship.sh keeps the export here as it goes live:
# $RELEASE_OUT/exports/TAG/{web/,built_from}, and $RELEASE_OUT/live_web
# names the live one. The one before it is kept too; older ones go.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
R=$(dirname "$(git -C "$HERE" rev-parse --path-format=absolute --git-common-dir)")
RO=$(realpath -m "${RELEASE_OUT:-$R/bench/results/release-out}")

# What a web export is made from (export.sh web): the Godot project, which
# exports every resource (export_presets.cfg) and assets/, data/ and models/
# beside them, and the scripts export.sh runs. Not the site's pages and
# styles (web/ has a .gdignore), the API, the docs, the tests, the
# database's SQL, or a tool run outside the export: the deploy and the
# checks run from the release's own tree. tools/mcp_tools.json is the app's
# tool list, which ship.sh's sync probe holds to the app's own.
app_files() {
  local f
  while IFS= read -r f; do
    case "$f" in
      ""|web/*|api/*|docs/*|docs-site/*|tests/*|.claude/*|supabase/*|.github/*|*.md|.gitignore|.gitattributes|pyproject.toml|LICENSE) ;;
      tools/export.sh|tools/fetch_data.sh|tools/web_pack.py|tools/web/brotli.mjs|tools/web/pck_split.py|tools/web/wasm_proxy_fix.py|tools/mcp_tools.json) echo "$f" ;;
      tools/*) ;;
      *) echo "$f" ;;
    esac
  done
}

case "${1:-}" in
  show)
    d=$(realpath -e "$RO/live_web" 2>/dev/null) && [ -f "$d/web/index.html" ] && [ -s "$d/built_from" ] || exit 1
    echo "$d/web $(cat "$d/built_from") $(basename "$d")" ;;
  keep)
    [ $# -eq 4 ] || { echo "usage: live_export.sh keep TAG SHA DIR"; exit 2; }
    tag=$2 dir=$4
    sha=$(git -C "$R" rev-parse -q --verify "$3^{commit}") || { echo "live_export: no commit $3"; exit 2; }
    [ -f "$dir/index.html" ] || { echo "live_export: no export in $dir"; exit 1; }
    d=$RO/exports/$tag
    mkdir -p "$RO/exports" && rm -rf "$d.$$" && mkdir "$d.$$" || exit 1
    cp -a --reflink=auto "$dir" "$d.$$/web" && echo "$sha" > "$d.$$/built_from" || { rm -rf "$d.$$"; exit 1; }
    # Whole, then named: a web lane reading live_web finds the export before or this one.
    was=$(realpath -e "$RO/live_web" 2>/dev/null)
    rm -rf "$d" && mv -T "$d.$$" "$d" && ln -sfnT "exports/$tag" "$RO/live_web.$$" && mv -T "$RO/live_web.$$" "$RO/live_web" || exit 1
    for old in "$RO"/exports/*; do
      [ "$old" = "$d" ] || [ "$old" = "$was" ] || rm -rf "$old"
    done
    echo "live_export: $tag's export kept, made from ${sha:0:9}" ;;
  app)
    [ $# -eq 3 ] || { echo "usage: live_export.sh app FROM TO"; exit 2; }
    git diff --name-only "$2" "$3" -- | app_files ;;
  *) sed -n '4,9p' "$0"; exit 2 ;;
esac
