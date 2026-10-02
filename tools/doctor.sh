#!/usr/bin/env bash
# Is this checkout worth driving? One read-only look, before anything else.
#
# Every line below is something that has made a check fail in a way that
# pointed at the wrong thing: a missing LDraw library reads as a part that
# has no studs, an unbuilt mesh cache reads as a part that will not load,
# no DISPLAY reads as six probes failing for no stated reason.
#
#   tools/doctor.sh              what this machine can run
#   tools/doctor.sh --network    also whether the live site answers
#
# Prints nothing secret: key names, never key values. Exits non-zero only
# when the app itself cannot be driven at all.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

network=0
for a in "$@"; do
  case "$a" in
    --network) network=1 ;;
    *) echo "doctor: unknown option $a"; exit 2 ;;
  esac
done

blocked=0
say() { printf '  %-5s %s\n' "$1" "$2"; }
ok()   { say ok "$1"; }
no()   { say "--" "$1"; }
bad()  { say FAIL "$1"; blocked=1; }

echo "── the app ──"
if command -v godot >/dev/null; then
  version=$(godot --version 2>/dev/null | tail -1)
  case "$version" in
    4.7.*) ok "godot $version" ;;
    *) bad "godot $version — the project is 4.7; other versions fail to open scenes" ;;
  esac
else
  bad "no godot on PATH — the app and every probe need it"
fi
# A scene that does not parse takes every probe with it and says so in a
# message that names the probe rather than the broken file.
parse=$(godot --headless --path . --quit 2>&1)
if echo "$parse" | grep -qE 'SCRIPT ERROR|Parse Error'; then
  bad "the project does not parse — run tools/check.sh to see which file"
  echo "$parse" | grep -E 'SCRIPT ERROR|Parse Error' | head -3 | sed 's/^/        /'
else
  ok "every script and scene parses"
fi
commit=$(git rev-parse --short HEAD 2>/dev/null || echo unknown)
dirty=$(git status --porcelain 2>/dev/null | grep -cv '^??')
ok "build is $commit${dirty:+, $dirty tracked file(s) modified}"

echo "── the parts ──"
if [ -d vendor/ldraw/parts ]; then
  ok "LDraw library present ($(ls vendor/ldraw/parts | wc -l) part files)"
else
  bad "no vendor/ldraw — run tools/fetch_data.sh. Every dimension check needs it"
fi
meshes=$(find assets/generated/parts -name '*.lbm' 2>/dev/null | wc -l)
if [ "$meshes" -gt 1000 ]; then
  ok "$meshes meshes built"
else
  bad "only $meshes meshes in assets/generated/parts — run tools/build_meshes.py (~45 min)"
fi
if [ -f assets/generated/catalogue.json ]; then
  ok "catalogue.json present ($(du -h assets/generated/catalogue.json | cut -f1))"
else
  bad "no assets/generated/catalogue.json — run tools/refresh_catalogue.py"
fi

echo "── what can be checked here ──"
if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
  ok "a display is attached — the six windowed probes can run"
else
  no "no DISPLAY: colour, shot, gizmo, marquee, feel and open probes cannot run"
fi
if python3 -c 'import pytest' 2>/dev/null; then
  ok "pytest present"
else
  no "no pytest — tools/check.sh falls back to tools/minitest.py"
fi
if python3 -c 'import numpy, scipy' 2>/dev/null; then
  ok "numpy and scipy present"
else
  no "no numpy/scipy: 25 occupancy tests skip, and tools/build_meshes.py cannot run"
fi
command -v node >/dev/null && ok "node $(node --version)" || no "no node — no web deploy or browser check"
# It lives beside the script that imports it, not at the repo root.
if [ -d tools/web/node_modules/playwright ]; then
  ok "playwright present — tools/web/check.mjs can prove a deploy"
else
  no "no playwright — run (cd tools/web && npm install && npx playwright install chromium)"
fi

echo "── the hosted side ──"
if [ -f .env ]; then
  # Names only. A doctor that printed a token would put it in a log.
  missing=""
  for key in VERCEL_TOKEN SUPABASE_URL SUPABASE_SECRET_KEY PARTS_URL; do
    grep -q "^$key=." .env || missing="$missing $key"
  done
  if [ -z "$missing" ]; then
    ok ".env has the keys the deploy and the API need"
  else
    no ".env is missing:$missing"
  fi
else
  no "no .env — the deploy and the hosted API cannot be driven from here"
fi
if [ "$network" = 1 ]; then
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 https://brickworks.diy/app)
  [ "$code" = 200 ] && ok "brickworks.diy/app answers 200" || no "brickworks.diy/app answered $code"
else
  no "live site not checked — pass --network"
fi

echo ""
if [ "$blocked" = 0 ]; then
  echo "the app can be driven here"
else
  echo "the app CANNOT be driven here — fix the FAIL lines above first"
fi
exit $blocked
