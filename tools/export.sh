#!/usr/bin/env bash
# Export a build with the presets in export_presets.cfg, then print its sizes.
#   tools/export.sh web             build/web/            threads (needs COOP/COEP: tools/web.sh serves them)
#   tools/export.sh web-nothreads   build/web-nothreads/  for hosts that cannot send those headers
#   tools/export.sh mac             build/mac/Brickworks.app universal, ad-hoc signed
#   tools/export.sh all
# Add --debug for a debug template. Web builds get .br and .gz siblings of the
# big files so a server can send them precompressed (tools/web.sh does).
#
# --config=NAME makes the build from a master configuration (configs/NAME.json,
# docs/DEV.md). Every build is stamped, with a configuration or without one: the
# stamp (src/dev/stamp_build.gd) is written to stamp/build.json for the export to
# pack, taken away again after, and kept beside the build as build.json with the
# sizes, so the shelf, a note and the running build all say what it is.
set -uo pipefail
# Guarded: a cd that fails leaves the script running against
# whatever directory it was started from, which for a deploy means
# shipping something else entirely.
cd "$(dirname "$0")/.." || exit 1
target="${1:-web}"; shift || true
mode=release
for a in "$@"; do
  case "$a" in
    --debug) mode=debug ;;
  esac
done

# Fail up front, in one line, on anything this script runs that is missing: a
# missing brotli used to fail silently in a background job and leave wrong sizes.
need() {
  local missing=() t
  for t in "$@"; do command -v "$t" >/dev/null 2>&1 || missing+=("$t"); done
  if [ ${#missing[@]} -gt 0 ]; then
    echo "export FAILED: not on PATH: ${missing[*]}"; exit 1
  fi
}

human() { awk -v b="$1" 'BEGIN { if (b >= 1048576) printf "%.1f MB", b / 1048576; else printf "%.0f KB", b / 1024 }'; }
bytes() { stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null || echo 0; }

# Two exports in one copy of the project would trip over each other, so
# they take turns: the lock is a directory (made atomically), and one older
# than an hour was left by a run that died without its trap.
LOCK=build/.export-lock
mkdir -p build
waited=0
until mkdir "$LOCK" 2>/dev/null; do
  if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +60 2>/dev/null)" ]; then rm -rf "$LOCK"; continue; fi
  [ $waited -eq 0 ] && echo "export waiting: another export is running in this copy ($LOCK)"
  waited=$((waited + 1))
  [ $waited -gt 1200 ] && { echo "export FAILED: $LOCK held for 20 minutes"; exit 1; }
  sleep 1
done
trap 'rm -rf "$LOCK"' EXIT


export_one() {
  local preset="$1" out="$2"
  local dir; dir="$(dirname "$out")"
  rm -rf "$dir"; mkdir -p "$dir"
  local log; log="$(mktemp "${TMPDIR:-/tmp}/brickworks-export.XXXXXX")"
  local t0; t0=$(python3 -c 'import time; print(time.time())')
  godot --headless --path . "--export-$mode" "$preset" "$out" >"$log" 2>&1
  local code=$?
  local t1; t1=$(python3 -c 'import time; print(time.time())')
  if [ $code -ne 0 ] || [ ! -e "$out" ] || grep -qE 'SCRIPT ERROR|Parse Error|Compile Error' "$log"; then
    grep -vE '^\s*at: ' "$log" | grep -iE 'error|cannot|failed' | head -30
    echo "export FAILED: $preset -> $out"; rm -f "$log"; return 1
  fi
  rm -f "$log"
  printf "export %s -> %s in %.1f s\n" "$preset" "$dir" "$(echo "$t1 - $t0" | bc)"
}

# Precompressed siblings: the wasm is ~40 MB raw and ~9 MB as brotli.
compress_web() {
  local dir="$1" pids=() f p
  for f in "$dir"/*.wasm "$dir"/*.pck "$dir"/*.js "$dir"/*.html; do
    [ -f "$f" ] || continue
    brotli -f -q 9 -o "$f.br" "$f" & pids+=($!)
    gzip -9 -k -f "$f" & pids+=($!)
  done
  for p in "${pids[@]}"; do
    wait "$p" || { echo "export FAILED: compressing $dir"; return 1; }
  done
  for f in "$dir/index.wasm" "$dir/index.pck"; do
    [ -f "$f.br" ] && [ -f "$f.gz" ] || { echo "export FAILED: no .br/.gz beside $f"; return 1; }
  done
}

report_web() {
  local dir="$1"
  local wasm="$dir/index.wasm" pck="$dir/index.pck"
  printf "  wasm %-9s br %-9s gz %s\n" "$(human "$(bytes "$wasm")")" "$(human "$(bytes "$wasm.br")")" "$(human "$(bytes "$wasm.gz")")"
  printf "  pck  %-9s br %-9s gz %s\n" "$(human "$(bytes "$pck")")" "$(human "$(bytes "$pck.br")")" "$(human "$(bytes "$pck.gz")")"
  local total=0 f
  for f in "$dir"/*; do
    case "$f" in *.br|*.gz) continue ;; esac
    if [ -f "$f.br" ]; then total=$(( total + $(bytes "$f.br") )); else total=$(( total + $(bytes "$f") )); fi
  done
  printf "  over the wire (brotli where it helps): %s\n" "$(human $total)"
}

build_web() {
  local preset="$1" dir="$2"
  export_one "$preset" "$dir/index.html" || return 1
  compress_web "$dir" || return 1
  report_web "$dir"
}

build_mac() {
  export_one "macOS" "build/mac/Brickworks.app" || return 1
  local app=build/mac/Brickworks.app
  printf "  app %s (pck %s)\n" "$(du -sh "$app" | cut -f1)" "$(human "$(bytes "$app/Contents/Resources/Brickworks.pck")")"
}

case "$target" in
  web|web-nothreads|all) need godot python3 bc brotli gzip ;;
  *) need godot python3 bc ;;
esac
mkdir -p build && touch build/.gdignore
case "$target" in
  web|web-nothreads|all)
    python3 tools/web_pack.py || { echo "export FAILED: web pack"; exit 1; } ;;
esac
godot --headless --import >/dev/null 2>&1 || true
case "$target" in
  web) build_web "Web" build/web ;;
  web-nothreads) build_web "Web (no threads)" build/web-nothreads ;;
  mac) build_mac ;;
  all) build_web "Web" build/web && build_web "Web (no threads)" build/web-nothreads && build_mac ;;
  *) echo "usage: tools/export.sh web|web-nothreads|mac|all [--debug]"; exit 2 ;;
esac
