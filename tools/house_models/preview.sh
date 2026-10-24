#!/bin/bash
# What the Share panel would publish for a list of seeds, and whether each is Tested.
#
#   tools/house_models/preview.sh LIST.json OUTDIR [gpu|heavy]
#
# The gallery seed's Godot half (src/dev/gallery_seed.gd) on LIST (entries as
# tools/web/gallery_seeds/seeds.json has them), into OUTDIR: each body as the
# panel sends it (<n>.json, its picture <n>.png and card <n>-thumb.png), then
# each one's Tested finding, test by test. OUTDIR is what gallery_seed.mjs
# publishes. The timeout counts the time in the queue.
#
# Used by seed211 (2026-10-24) to look at each house model's picture and to
# make the two DIRs of six it published (the site lists six an hour).
set -u
list=$1; out=$2; q=${3:-gpu}
root=$(cd "$(dirname "$0")/../.." && pwd)
rm -rf "$out"; mkdir -p "$out/xdg"
cd "$root" || exit 1
timeout 3000 ~/.claude/claude-core/bin/$q env XDG_DATA_HOME="$out/xdg" MESA_VK_WSI_DEBUG=sw \
  xvfb-run -a --server-args="-screen 0 1400x900x24" \
  godot --path . --resolution 1400x900 --script src/dev/gallery_seed.gd -- \
  --seed-list="$list" --seed-out="$out" > "$out/seed.log" 2>&1
echo "exit $?"
grep -E "^  (ok|FAIL)|FAILED|the gallery's models" "$out/seed.log"
python3 - "$out" <<'PY'
import glob, json, os, sys
bodies = [f for f in glob.glob(os.path.join(sys.argv[1], "*.json")) if os.path.basename(f).split(".")[0].isdigit()]
for f in sorted(bodies, key=lambda p: int(os.path.basename(p).split(".")[0])):
    b = json.load(open(f)); tests = b.get("tested", {}).get("tests", {})
    passed = bool(tests) and all(v.get("ok") for v in tests.values())
    print("%s %s: %s" % (os.path.basename(f), b.get("name"), "TESTED" if passed else "not tested"))
    for k, v in tests.items():
        print("    %s %s: %s" % (k, "ok" if v.get("ok") else "FAILS", str(v.get("why"))[:300]))
PY
