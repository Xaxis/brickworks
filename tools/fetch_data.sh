#!/usr/bin/env bash
# Fetch the upstream data this project is built on into vendor/.
#
# Nothing here is committed: it is large, it is versioned upstream, and it
# is not ours to redistribute in source form.  The generated assets that
# ship with the app are derived from it by tools/build_*.py.
#
#   tools/fetch_data.sh          everything that is missing
#   tools/fetch_data.sh --force  re-fetch even if present
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p vendor
force=0
[ "${1:-}" = "--force" ] && force=1

fetch() {
  local name="$1" url="$2" out="vendor/$3"
  if [ -e "$out" ] && [ "$force" = 0 ]; then
    echo "have  $name"
    return 0
  fi
  echo "fetch $name <- $url"
  curl -sSL --fail -o "$out.tmp" "$url" || { echo "FAILED: $name"; return 1; }
  mv "$out.tmp" "$out"
}

# The LDraw Parts Library: the geometry of every modelled part, CC BY 4.0.
# https://library.ldraw.org/  — attribution is required and lives in
# docs/ATTRIBUTION.md and in the app's about screen.
if [ ! -d vendor/ldraw ] || [ "$force" = 1 ]; then
  fetch "LDraw complete library" \
    "https://library.ldraw.org/library/updates/complete.zip" complete.zip
  echo "unpack LDraw"
  rm -rf vendor/ldraw
  unzip -q -o vendor/complete.zip -d vendor/
fi

# Unofficial parts: the Parts Tracker's in-review geometry.  Adds several
# thousand parts that are modelled but not yet certified, which matters for
# recent sets.  Kept separate so the catalogue can mark them as such.
fetch "LDraw unofficial parts" \
  "https://library.ldraw.org/library/unofficial/ldrawunf.zip" ldrawunf.zip
if [ -f vendor/ldrawunf.zip ]; then
  mkdir -p vendor/ldraw/unofficial
  unzip -q -o vendor/ldrawunf.zip -d vendor/ldraw/unofficial/ 2>/dev/null || true
fi

# The Official Model Repository: real LEGO sets as .mpd files, every part
# placed as the designers placed it.  The reference corpus for the AI.
fetch "LDraw OMR" "https://omr.ldraw.org/files/omr.zip" omr.zip || \
  echo "note: OMR not fetched; see docs/DATA.md for alternatives"

echo
echo "vendor/ contents:"
du -sh vendor/* 2>/dev/null || true
