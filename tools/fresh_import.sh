#!/bin/bash
# fresh_import.sh [--check] : import the checkout this is run in when its
# class list is behind its scripts, one import at a time.
#
# A probe, like the app, reads .godot and never writes it: the class list
# (.godot/global_script_class_cache.cfg) is written only by an editor run,
# `godot --import` (traced, 2026-10-22). A .godot copied from another
# worktree, or kept across a merge, a checkout or a bisect, names the
# classes of the commit it was made at, and every script that uses a class
# missing from it fails to compile, far from the cause. surface108's three
# probes failed so with 9,377 script errors, "BestOfTwo" not declared, then
# passed once something had imported. It was put down to running them at
# once; a list without BestOfTwo gives the same errors to the line with one
# probe alone.
#
# Behind: the scripts' `class_name` lines, read as Godot scans (no hidden
# folder, none under a .gdignore, linked folders followed), are not the
# list's classes at the same paths. Then it imports holding
# .godot/import.lock, so runs started together import once: the others
# wait for the lock and find the list made. Exits 0 when the list is the
# scripts', 1 with the difference when it is not even after an import.
#   --check   say what is behind, import nothing
set -u
check=; [ "${1:-}" = --check ] && check=1
list=.godot/global_script_class_cache.cfg

# "Name res://path" for each class, sorted: the scripts', then the list's.
in_scripts() {
  find -L . -name '.?*' -type d -prune -o -type f \( -name '*.gd' -o -name .gdignore \) -print \
    | awk '{ line[NR] = $0 }
        /\/\.gdignore$/ { d = $0; sub(/\.gdignore$/, "", d); skip[++n] = d }
        END { for (i = 1; i <= NR; i++) {
          if (line[i] ~ /\.gdignore$/) continue
          for (j = 1; j <= n; j++) if (index(line[i], skip[j]) == 1) break
          if (j > n) print line[i] } }' \
    | xargs -r -d '\n' grep -m1 -HoE '^class_name[[:space:]]+[A-Za-z_][A-Za-z0-9_]*' \
    | sed -E 's|^\./(.*):class_name[[:space:]]+(.*)$|\2 res://\1|' | LC_ALL=C sort
}
in_list() {
  [ -f "$list" ] && awk -F'"' '/^"class": /{ c = $4 } /^"path": /{ print c, $4 }' "$list" | LC_ALL=C sort
}
behind() {
  LC_ALL=C comm -23 <(in_scripts) <(in_list) | sed 's/^/  not in the class list: /'
  LC_ALL=C comm -13 <(in_scripts) <(in_list) | sed 's/^/  in the class list, not in a script: /'
}

said=$(behind)
[ -z "$said" ] && exit 0
if [ -n "$check" ]; then
  echo "fresh_import: $(pwd)'s class list is behind its scripts:"; echo "$said" | head -10; exit 1
fi
mkdir -p .godot
exec 9>>.godot/import.lock
if ! flock -n 9; then
  echo "fresh_import: another run is importing $(pwd); waiting for it"
  flock -w 1200 9 || { echo "fresh_import: still importing after 20 minutes; gave up" >&2; exit 1; }
  said=$(behind)
  [ -z "$said" ] && exit 0
fi
echo "fresh_import: $(pwd)'s class list is behind its scripts, so importing first:"
echo "$said" | head -5
core="$HOME/.claude/claude-core/bin"
heavy=(); [ -x "$core/heavy" ] && heavy=("$core/heavy")
data=$(mktemp -d "${TMPDIR:-/tmp}/fresh-import.XXXXXX")
log="$data/import.log"
started=$SECONDS
"${heavy[@]}" env XDG_DATA_HOME="$data" timeout 900 godot --headless --path . --import > "$log" 2>&1
said=$(behind)
if [ -n "$said" ]; then
  echo "fresh_import: still behind after an import ($((SECONDS - started)) s):"; echo "$said" | head -10
  tail -5 "$log" | sed 's/^/  import: /'
  rm -rf "$data"; exit 1
fi
rm -rf "$data"
echo "fresh_import: imported in $((SECONDS - started)) s"
