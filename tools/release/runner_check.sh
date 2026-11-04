#!/bin/bash
# runner_check.sh VERSION LAID OUT
# A release's draft on Xaxis/brickworks-releases, checked where only a
# runner can (tools/release/ci/runner_check.yml): each installed copy updated
# to the release's own package, a key in the real keychain, and what an
# unsigned first launch shows. Then everything it made taken away.
#
#   VERSION  the draft to check (v$VERSION must be a draft there)
#   LAID     a folder of laid-macos, laid-windows, laid-windows-zip and
#            laid-ubuntu, each made by `tools/update_check.py lay --old OLD
#            --new dist/$VERSION/<that system's package> --port=8697 --out=...`
#            (the manifests are signed here: a runner has no key)
#   OUT      where the run's log and artifacts are kept
#
# What it makes, all deleted however it ends, then looked for again so the
# report says what is gone: a draft runner-check-$VERSION holding the laid
# scenarios (without the release's packages, which the runner takes from
# the release's own draft), a branch runner-check-$VERSION in the releases
# repository holding the workflow alone (pushed over SSH: gh's token has no
# workflow scope), and its runs. The tools are this checkout's HEAD, which
# must be pushed: the workflow checks Xaxis/brickworks out at it.
# WORKFLOW=FILE runs another workflow of the same form in its place (a part
# of it, run again).
set -u
VERSION=$1 LAID=$2 OUT=$3
REPO=Xaxis/brickworks-releases
NAME=runner-check-$VERSION
HERE=$(cd "$(dirname "$0")/../.." && pwd)
WORKFLOW=${WORKFLOW:-$HERE/tools/release/ci/runner_check.yml}
SOURCE=$(git -C "$HERE" rev-parse HEAD)
# env runs the program, never this function: GITHUB_TOKEN here is stale (docs/RELEASING.md).
gh() { env -u GITHUB_TOKEN gh "$@"; }
mkdir -p "$OUT"
git -C "$HERE" fetch -q origin
[ -n "$(git -C "$HERE" branch -r --contains "$SOURCE")" ] || {
  echo "runner_check: $SOURCE is not pushed, and the workflow checks it out: push it first"; exit 1; }
gh release view "v$VERSION" --repo "$REPO" --json isDraft -q .isDraft | grep -qx true || {
  echo "runner_check: v$VERSION is not a draft on $REPO"; exit 1; }
clone=$(mktemp -d "$OUT/clone.XXXXXX")

cleanup() {
  for id in $(gh run list --repo "$REPO" --branch "$NAME" --limit 50 --json databaseId -q '.[].databaseId'); do
    gh run delete "$id" --repo "$REPO" >/dev/null 2>&1 && echo "deleted run $id"
  done
  git -C "$clone" push -q origin --delete "$NAME" 2>/dev/null && echo "deleted branch $NAME"
  gh release delete "$NAME" --repo "$REPO" --yes --cleanup-tag 2>/dev/null && echo "deleted draft $NAME"
  rm -rf "$clone" "$OUT"/laid-*.tar
  echo "-- what is left --"
  echo "branch: $(git ls-remote "git@github.com:$REPO.git" "refs/heads/$NAME" | wc -l)"
  echo "tag: $(git ls-remote "git@github.com:$REPO.git" "refs/tags/$NAME" | wc -l)"
  echo "draft: $(gh release list --repo "$REPO" --limit 100 --json tagName -q ".[] | select(.tagName == \"$NAME\")" | wc -l)"
  echo "runs: $(gh run list --repo "$REPO" --branch "$NAME" --limit 50 --json databaseId -q '.[].databaseId' | wc -l)"
}
trap cleanup EXIT

# Each scenario folder without the release's own package: the runner
# downloads it from the release's draft, the same bytes the manifests name.
tars=()
for laid in laid-macos laid-windows laid-windows-zip laid-ubuntu; do
  new=$(python3 -c "import json, sys; print(json.load(open(sys.argv[1]))['new'])" "$LAID/$laid/laid.json") || exit 1
  tar -cf "$OUT/$laid.tar" -C "$LAID/$laid" --anchored --exclude="./files/$new" . || exit 1
  tars+=("$OUT/$laid.tar")
done
ls -l "${tars[@]}"
gh release create "$NAME" --repo "$REPO" --draft --title "runner check of $VERSION (temporary)" \
  --notes "The updater's scenarios for $VERSION's runner check; deleted after." "${tars[@]}" || exit 1

git clone -q --depth 1 "git@github.com:$REPO.git" "$clone" || exit 1
mkdir -p "$clone/.github/workflows"
sed -e "s/@BRANCH@/$NAME/; s/@TAG@/v$VERSION/; s/@LAID@/$NAME/; s/@SOURCE@/$SOURCE/" \
  "$WORKFLOW" > "$clone/.github/workflows/runner_check.yml"
git -C "$clone" add .github/workflows/runner_check.yml
git -C "$clone" -c user.name=Xaxis -c user.email=william.neeley@gmail.com \
  commit -q -m "Temporary: $VERSION checked on macOS, Windows and Ubuntu runners."
commit=$(git -C "$clone" rev-parse HEAD)
git -C "$clone" push -q origin "HEAD:refs/heads/$NAME" || exit 1
echo "pushed $commit to $NAME, tools at $SOURCE"

run=""
for _ in $(seq 60); do
  run=$(gh run list --repo "$REPO" --branch "$NAME" --limit 1 --json databaseId,headSha \
    -q ".[] | select(.headSha == \"$commit\") | .databaseId")
  [ -n "$run" ] && break
  sleep 5
done
[ -n "$run" ] || { echo "no run started for $commit"; exit 1; }
echo "run $run: https://github.com/$REPO/actions/runs/$run"
timeout 6000 gh run watch "$run" --repo "$REPO" --interval 30 --exit-status > "$OUT/watch.txt" 2>&1
status=$?
gh run view "$run" --repo "$REPO" --log > "$OUT/run-$run.log" 2>&1
gh run download "$run" --repo "$REPO" --dir "$OUT/artifacts" 2>&1 | tail -n 2
gh run view "$run" --repo "$REPO" --json jobs -q '.jobs[] | "\(.name): \(.conclusion)"'
grep -E "  (ok|FAIL)  |check\(s\) failed|every refusal held|apt installs it|keychain_check: " "$OUT/run-$run.log" \
  | sed -E 's/^([^\t]*)\t[^\t]*\t[0-9TZ:.-]+ /\1: /'
echo "watch exit $status"
exit $status
