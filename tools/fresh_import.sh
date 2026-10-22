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
# wait for the lock and find the list made. A run that finds the list
# current still waits out an import under way: Godot writes the list early
# and goes on importing, and the second of two runs started at once found
# it current a second in and ran its probe with half a minute of the
# first's import to go (2026-10-22). Exits 0 when the list is the scripts',
# 1 with the difference when it is not even after an import, and 1 without
# importing when two scripts have one class_name.
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
# One walk of the tree, the cost of a run whose list is current: comm -3
# prints the scripts' lines bare and the list's after a tab.
behind() {
  LC_ALL=C comm -3 <(in_scripts) <(in_list) \
    | sed -e 's/^\t/  in the class list, not in a script: /;t' -e 's/^/  not in the class list: /'
}

# Takes the import lock, shared (-s) or alone (-x), after another's import.
hold() {
  flock -n "$1" 9 && return
  echo "fresh_import: another run is importing $(pwd); waiting for it"
  flock -w 1200 "$1" 9 || { echo "fresh_import: still importing after 20 minutes; gave up" >&2; exit 1; }
}

said=$(behind)
if [ -z "$said" ]; then
  if [ -z "$check" ] && [ -f .godot/import.lock ]; then exec 9<.godot/import.lock; hold -s; fi
  exit 0
fi
# Two scripts of one class_name: the list keeps one, so no import ends it,
# and Godot's import says nothing of it (tried, 2026-10-22).
twice=$(in_scripts | awk '{ n[$1]++; at[$1] = at[$1] " " $2 }
  END { for (c in n) if (n[c] > 1) print "  two scripts are class_name " c ":" at[c] }')
if [ -n "$twice" ]; then
  echo "fresh_import: no import can bring $(pwd)'s class list up to date:"; echo "$twice"; exit 1
fi
if [ -n "$check" ]; then
  echo "fresh_import: $(pwd)'s class list is behind its scripts:"; echo "$said" | head -10; exit 1
fi
mkdir -p .godot
exec 9>>.godot/import.lock
hold -x
said=$(behind)  # another run's import, waited for, may have made it
[ -z "$said" ] && exit 0
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
