#!/bin/bash
# release_links.sh [MANIFEST] : does every address in the download page's
# manifest answer a visitor? Each release's page and notes, and every file,
# asked for its headers with no login and followed through GitHub's redirect;
# a file must answer 200 with the size the manifest gives it. MANIFEST is
# this checkout's web/releases.json unless named.
#
# The download page and the changelog link only to what web/releases.json
# says, and a link that 404s fails where nobody sees it but the person who
# clicked. tools/web/download_check.mjs asks for the links on the page, the
# latest release's, in a browser; this asks for all of them, older releases'
# too, in seconds. Making Xaxis/brickworks private would have turned every one
# into a 404 (2026-10-27). ship.sh runs it before a release goes out.
set -u
M=${1:-$(cd "$(dirname "$0")/../.." && pwd)/web/releases.json}
[ -f "$M" ] || { echo "release_links: no manifest at $M"; exit 2; }
n=0
bad=0
while read -r kind size url; do
  n=$((n + 1))
  # Twice before it counts: a network blip is not a broken link.
  for _ in 1 2; do
    got=$(curl -sSIL --max-time 60 -o /dev/null -w '%{http_code} %header{content-length}' "$url" 2>&1)
    case $got in 200*) break;; esac
  done
  if [ "$kind" = file ]; then
    want="200 $size"
    [ "$got" = "$want" ] && ok=1 || ok=0
  else
    want=200
    [ "${got%% *}" = 200 ] && ok=1 || ok=0
  fi
  if [ "$ok" = 1 ]; then
    echo "  ok    $url"
  else
    echo "  FAIL  $url  answered '$got', not $want"
    bad=$((bad + 1))
  fi
done < <(python3 -c '
import json, sys
seen = set()
for release in json.load(open(sys.argv[1])).get("releases", []):
    rows = [("page", "-", release.get("page")), ("notes", "-", release.get("notes"))]
    rows += [("file", f["size"], f["url"]) for f in release.get("files", [])]
    for kind, size, url in rows:
        if url and url not in seen:
            seen.add(url)
            print(kind, size, url)
' "$M")
[ "$n" -gt 0 ] || { echo "release_links: $M lists no address"; exit 1; }
if [ "$bad" = 0 ]; then
  echo "release_links: all $n addresses in $M answer"
else
  echo "release_links: $bad of $n addresses in $M do not answer as it says"
  exit 1
fi
