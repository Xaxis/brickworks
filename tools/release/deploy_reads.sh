# shellcheck shell=bash
# deploy_reads.sh: whether a build of BUILT stands for HEAD: HEAD contains
# it, and all that changed since is the browser checks or the release tools,
# which the deploy never reads. Sourced by preview_lib.sh (a release's
# preview reused) and tools/deploy.sh (that preview promoted), so the two
# cannot disagree: rel-m227's reused preview was refused at the promotion,
# and production was built afresh, half an hour more (2026-10-31).

# unread_since BUILT [HEAD]: true when something changed since BUILT and
# none of it is read by the deploy.
unread_since() {
  local since
  git merge-base --is-ancestor "$1" "${2:-HEAD}" 2>/dev/null || return 1
  since=$(git diff --name-only "$1" "${2:-HEAD}")
  [ -n "$since" ] || return 1
  # No pipe: under pipefail, grep -q stops reading and printf's SIGPIPE
  # would turn a change the deploy reads into "only checks".
  ! grep -qvE '^tools/web/[a-z0-9_]+_(flow|check|probe)\.mjs$|^tools/release/' <<<"$since"
}
