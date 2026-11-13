# shellcheck shell=bash
# deploy_reads.sh: whether a build of BUILT stands for HEAD: HEAD contains
# it, and all that changed since is the browser checks or the release tools,
# which the deploy never reads. Sourced by preview_lib.sh (a release's
# preview reused) and tools/deploy.sh (that preview promoted), so the two
# cannot disagree: rel-m227's reused preview was refused at the promotion,
# and production was built afresh, half an hour more (2026-10-31).

# unread_since BUILT [HEAD]: true when HEAD is a later commit and nothing
# changed since BUILT that the deploy reads: only checks or release tools,
# or no file at all, as the commit a train makes on its merge to say what
# it ships past after an A/B with brickworks.diy (ship.sh).
unread_since() {
  local since
  git merge-base --is-ancestor "$1" "${2:-HEAD}" 2>/dev/null || return 1
  [ "$(git rev-parse "$1")" != "$(git rev-parse "${2:-HEAD}")" ] || return 1
  since=$(git diff --name-only "$1" "${2:-HEAD}") || return 1
  [ -n "$since" ] || return 0
  # No pipe: under pipefail, grep -q stops reading and printf's SIGPIPE
  # would turn a change the deploy reads into "only checks".
  ! grep -qvE '^tools/web/[a-z0-9_]+_(flow|check|probe)\.mjs$|^tools/release/' <<<"$since"
}
