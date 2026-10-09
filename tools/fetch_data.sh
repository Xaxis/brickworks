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

# Rebrickable's parts tables, which record which part was ever actually
# made in which colour.  LDraw models geometry and has no idea what LEGO
# ever moulded: it will happily render a 4x12 wedge plate in sand green
# that never existed.  These tables are what let the checker say so, and
# what gives a bill of materials real element numbers.
#
# https://rebrickable.com/downloads/ — we fetch and derive a part->colours
# index locally (tools/build_availability.py) rather than redistributing
# their tables.  Read the .csv.gz directly; unpacked they are much larger
# and nothing needs them unpacked.
# Their grant permits automated downloading "at most once a day", so
# --force does not apply to them until the files are a day old.  That
# is a condition of the licence, not a courtesy, which is why it is
# here and not in docs/ATTRIBUTION.md.
mkdir -p vendor/rebrickable
for table in colors parts elements themes \
             inventories inventory_parts sets; do
  out="vendor/rebrickable/$table.csv.gz"
  if [ -e "$out" ] && [ -z "$(find "$out" -mtime +0 2>/dev/null)" ]; then
    echo "have  Rebrickable $table (fetched today)"
    continue
  fi
  fetch "Rebrickable $table" \
    "https://cdn.rebrickable.com/media/downloads/$table.csv.gz" \
    "rebrickable/$table.csv.gz"
done

# The Official Model Repository once came down here too — real sets as
# .mpd files, described in this script as "the reference corpus for the
# AI".  Nothing ever read it.  It was a large download on every fetch
# for nobody, and the line telling you where to read about it pointed at
# a docs/DATA.md that does not exist.  If it comes back it comes back
# with something that uses it:
#
#   https://omr.ldraw.org/files/omr.zip

echo
echo "vendor/ contents:"
du -sh vendor/* 2>/dev/null || true
