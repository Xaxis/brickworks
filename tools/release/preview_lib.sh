# preview_lib.sh: what ship.sh and unit_preview.sh share, sourced by both:
# a preview of a worktree, and the browser checks run on it. A unit that
# proved its site change on a preview of its own, the same way a release
# does, would not have held four release previews on 2026-10-22.
# The caller is in the worktree and sets W (it, absolute), S (where results
# go), HERE (the scripts) and WHO (the word its lines begin with).

# Every check named reported, and passed. A battery that never ran writes
# no results, and "no failed line" read as a pass: m31 went on to deploy
# production with no check run (2026-10-15).
passed() {
  local out=$1 want=$2
  [ -s "$out" ] || return 1
  grep -qE 'exit=[^0]' "$out" && return 1
  [ "$want" -eq 0 ] || [ "$(grep -c ' exit=0 ' "$out")" -eq "$want" ]
}

# The browser flows added since BASE that no check runs, by name. A new flow
# proves nothing on a deployment until a check runs it: play and designers
# were proven only against the local server and held m87 three times there
# (2026-10-19). Each one is named in preview_checks.sh, or marked there
# "# local only: NAME" with why.
unwired_flows() {
  local f
  for f in $(git diff --name-only --diff-filter=A "$1" HEAD -- 'tools/web/*_flow.mjs'); do
    grep -qF "$(basename "$f")" "$HERE/preview_checks.sh" || printf ' %s' "$(basename "$f")"
  done
}

# reused_preview NAME SHA: the preview NAME made, if it was made from this
# very commit, in URL.
reused_preview() {
  URL=""
  [ "$(cat "$S/${1}_preview.sha" 2>/dev/null)" = "$2" ] || return 1
  URL=$(grep -oE "deploy done https://[^ ]+" "$S/${1}_preview.log" | cut -d' ' -f3)
  [ -n "$URL" ] && echo "$WHO: reusing preview $URL, made from $2"
}

# The import a worktree needs before it can export the web build.
import_here() {
  ~/.claude/claude-core/bin/heavy env XDG_DATA_HOME="$PWD/.scratch-data" timeout 900 godot --headless --path . --import >/dev/null 2>&1
}

# deploy_preview NAME SHA: this worktree on Vercel, unpromoted (tools/deploy.sh
# without --prod: no domain points at it), in URL. Its log is
# NAME_preview.log, and the commit it was made from NAME_preview.sha.
deploy_preview() {
  timeout 3000 ~/.claude/claude-core/bin/heavy tools/deploy.sh > "$S/${1}_preview.log" 2>&1
  URL=$(grep -oE "deploy done https://[^ ]+" "$S/${1}_preview.log" | cut -d' ' -f3)
  [ -n "$URL" ] || { echo "$WHO: preview deploy failed"; tail -3 "$S/${1}_preview.log"; return 1; }
  echo "$2" > "$S/${1}_preview.sha"
  echo "$WHO: preview $URL"
}

# run_checks URL OUT CHECK...: the checks named, on URL, one line each in
# $S/OUT.out (tools/release/preview_checks.sh).
run_checks() {
  local url=$1 out=$2; shift 2
  rm -f "$S/$out.out"
  "$HERE/preview_checks.sh" "$url" "$W" "$out" "$@" || { echo "$WHO: held, the checks did not run"; return 1; }
}
