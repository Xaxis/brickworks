#!/bin/bash
# vendor_model_viewer.sh : <model-viewer>, Google's element that places a
# 3D model in a room (WebXR's immersive AR on an Android phone or a headset,
# AR Quick Look on an iPhone or iPad), into the site for In your room
# (web/room.js; APP_UX5 #13, arview).
#
#   web/model-viewer-4.4.0/model-viewer.min.js
#                         @google/model-viewer@4.4.0's dist/model-viewer.min.js
#                         (three.js and lit inside it), less its source map's
#                         address. Served from our own origin, as every page
#                         runs under script-src 'self', and asked for only when
#                         a visitor taps In your room, never on a page's load.
#   web/model-viewer-4.4.0/LICENSE
#                         its licence (Apache-2.0), beside it.
#
# Committed, as tools/web/axe-core is, so a deploy never fetches it; this
# says where it came from and writes it again.
#
# Pinned: the version is in the folder's name, and the package must be the
# one npm published (its sha512), or nothing is written. To move to another
# version, change VERSION and INTEGRITY, run this, and point web/room.js at
# the new folder.
set -euo pipefail
VERSION=4.4.0
INTEGRITY="sha512-8z1SB5sPlzKoak5mdx/D31brBakPYm3Qi31EfAucHAUrtrHHCbabypkKvSwReYhUpPaxyJ46oT47uWE/hrs1Zw=="
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
curl -fsSL -o "$work/package.tgz" "https://registry.npmjs.org/@google/model-viewer/-/model-viewer-$VERSION.tgz"
got="sha512-$(openssl dgst -sha512 -binary "$work/package.tgz" | base64 -w0)"
[ "$got" = "$INTEGRITY" ] || { echo "vendor_model_viewer: the package is not the one npm published ($got)" >&2; exit 1; }
mkdir -p "$work/package"
tar -xzf "$work/package.tgz" -C "$work"
out="web/model-viewer-$VERSION"
mkdir -p "$out"
grep -v '^//# sourceMappingURL=' "$work/package/dist/model-viewer.min.js" > "$out/model-viewer.min.js"
cp "$work/package/LICENSE" "$out/LICENSE"
echo "vendor_model_viewer: $out/model-viewer.min.js ($(wc -c < "$out/model-viewer.min.js") bytes) from @google/model-viewer@$VERSION"
