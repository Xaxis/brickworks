# shellcheck shell=bash
# deploy_reads.sh: whether a build of BUILT stands for HEAD: HEAD contains
# it, and all that changed since is what the deploy never reads: the browser
# checks and their modules, the release tools, the tests. Sourced by
# preview_lib.sh (a release's preview reused) and tools/deploy.sh (that
# preview promoted), so the two cannot disagree: rel-m227's reused preview
# was refused at the promotion, and production was built afresh, half an
# hour more (2026-10-31).

# The files of tools/web a build is made from: the deploy, the export and
# the functions' packaging run them (tools/deploy.sh, tools/export.sh,
# tools/package_api.sh). Every other file there is a check or a check's
# module, which reads a deployment and never makes one. Only flows and
# checks by their names were unread before, so rel-m319's fix to
# tools/web/browser.mjs, a module of the checks, built an identical site
# twice, 457 s and 641 s in a heavy slot (2026-11-23).
# tests/test_deploy_reads.py holds this list to the build's scripts.
DEPLOY_READS_WEB=" alt_index.mjs brotli.mjs data_facts.mjs home_shelf.mjs minifig_layers.mjs static_server.mjs packaged_facts.mjs part_facts.mjs pck_split.py place_build.py start_closure.py wasm_proxy_fix.py overlook_copy.sh package.json package-lock.json "

# deploy_reads PATH: whether a change to PATH can change what a deploy makes.
deploy_reads() {
  case "$1" in
    tools/release/*|tests/*) return 1 ;;
    tools/web/*/*) return 0 ;;
    tools/web/*) case "$DEPLOY_READS_WEB" in *" ${1#tools/web/} "*) return 0 ;; esac; return 1 ;;
  esac
  return 0
}

# unread_since BUILT [HEAD]: true when HEAD is a later commit and nothing
# changed since BUILT that the deploy reads, or no file at all, as the
# commit a train makes on its merge to say what it ships past after an A/B
# with brickworks.diy (ship.sh).
unread_since() {
  local since f
  git merge-base --is-ancestor "$1" "${2:-HEAD}" 2>/dev/null || return 1
  [ "$(git rev-parse "$1")" != "$(git rev-parse "${2:-HEAD}")" ] || return 1
  since=$(git diff --name-only "$1" "${2:-HEAD}") || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    deploy_reads "$f" && return 1
  done <<< "$since"
  return 0
}
