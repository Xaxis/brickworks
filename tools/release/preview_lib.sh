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

# reused_preview NAME SHA: the preview NAME made, in URL, if it was made
# from this very commit, or from one before it when all that changed since is
# the browser checks or the release tools, which the deploy never reads. A
# fixed check otherwise cost a new preview and every check again: m145's
# profile, m148's feed and notifications checks, all on 2026-10-22.
reused_preview() {
  URL=""
  local made; made=$(cat "$S/${1}_preview.sha" 2>/dev/null)
  [ -n "$made" ] || return 1
  local since=""
  if [ "$made" != "$2" ]; then
    git merge-base --is-ancestor "$made" "$2" 2>/dev/null || return 1
    since=$(git diff --name-only "$made" "$2")
    [ -n "$since" ] || return 1
    ! printf '%s\n' "$since" | grep -qvE '^tools/web/[a-z0-9_]+_(flow|check|probe)\.mjs$|^tools/release/' || return 1
  fi
  URL=$(grep -oE "deploy done https://[^ ]+" "$S/${1}_preview.log" | cut -d' ' -f3)
  [ -n "$URL" ] && echo "$WHO: reusing preview $URL, made from $made${since:+ (since then only checks and release tools: $(printf '%s\n' "$since" | tr '\n' ' '))}"
}

# The import a worktree needs before it can export the web build.
# fresh_import.sh imports only when the class list is behind the scripts,
# waits out an import already running, and fails when it cannot finish. The
# bare `timeout 900 heavy godot --import` this was spent its time waiting for
# a slot at load, said nothing, and m155's gate then read a class list
# without the sculpt: "the tool list is not the app's" (2026-10-23).
import_here() {
  tools/fresh_import.sh
}

# deploy_preview NAME SHA [OPTION...]: this worktree on Vercel, unpromoted
# (tools/deploy.sh without --prod: no domain points at it), in URL, with the
# deploy's options (a unit's: --unit). Its log is NAME_preview.log, and the
# commit it was made from NAME_preview.sha.
deploy_preview() {
  local name=$1 sha=$2; shift 2
  timeout 3000 ~/.claude/claude-core/bin/heavy tools/deploy.sh "$@" > "$S/${name}_preview.log" 2>&1
  URL=$(grep -oE "deploy done https://[^ ]+" "$S/${name}_preview.log" | cut -d' ' -f3)
  [ -n "$URL" ] || { echo "$WHO: preview deploy failed"; tail -3 "$S/${name}_preview.log"; return 1; }
  echo "$sha" > "$S/${name}_preview.sha"
  echo "$WHO: preview $URL"
}

# run_checks URL OUT CHECK...: the checks named, on URL, one line each in
# $S/OUT.out (tools/release/preview_checks.sh).
run_checks() {
  local url=$1 out=$2; shift 2
  rm -f "$S/$out.out"
  "$HERE/preview_checks.sh" "$url" "$W" "$out" "$@" || { echo "$WHO: held, the checks did not run"; return 1; }
}
