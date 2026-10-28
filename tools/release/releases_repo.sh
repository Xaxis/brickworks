#!/bin/bash
# releases_repo.sh [--go] [--dir=DIR] : move the desktop downloads to a public
# repository of builds only, Xaxis/brickworks-releases, so they still answer
# once the source repository is private.
#
# The packages are release assets on Xaxis/brickworks, and the download page
# links to them there. A private repository's assets answer 404 to everyone
# else, so making the source private breaks every download. Gamewright did the
# same (Xaxis/gamewright-releases, 2026-10-06): a public repository holding a
# README and the releases, nothing else.
#
# Without --go it changes nothing anywhere. It reads both repositories,
# downloads every asset of each release in TAGS into DIR (a read), checks each
# file against GitHub's SHA-256 and the release's SHA256SUMS, prints them, and
# prints each step --go would take, word for word. With --go, and only with
# the owner's yes:
#   1. creates Xaxis/brickworks-releases, public, seeded with one commit by
#      Xaxis: releases_repo/README.md, and releases_repo/release.yml, the
#      three-system smoke (free there; macOS minutes cost ten times Linux's
#      on a private repository);
#   2. copies each release with its tag, title, notes and every asset, as a
#      draft, compares GitHub's SHA-256 of every uploaded file with the
#      original's, and publishes it only when all of them match;
#   3. asks for every published file with no login, as a visitor would, and
#      checks it answers 200 with the file's size.
# Any mismatch exits 1 and leaves that release a draft nobody else can see.
# Run again, it picks up where it stopped: what is already there is checked,
# not made again. Xaxis/brickworks is only ever read: every call to it goes
# through from_source, which runs reads and refuses anything else.
set -u
SRC=Xaxis/brickworks
DEST=Xaxis/brickworks-releases
# Oldest first, so the one made last is also the newest.
TAGS=(v0.8.0 v0.9.0)
LATEST=v0.9.0
DESCRIPTION="Brickworks downloads: the built packages only. Get them from https://brickworks.diy/download"
HOMEPAGE=https://brickworks.diy/download
HERE=$(cd "$(dirname "$0")" && pwd)

GO=0
DIR=${TMPDIR:-/tmp}/brickworks-releases-repo
for arg in "$@"; do
  case $arg in
    --go) GO=1;;
    --dir=*) DIR=${arg#--dir=};;
    -h|--help) sed -n '2,/^set -u/{/^set -u/d;s/^# \{0,1\}//;p}' "$0"; exit 0;;
    *) echo "releases_repo: no such option $arg (--go, --dir=DIR)" >&2; exit 2;;
  esac
done
mkdir -p "$DIR" && DIR=$(cd "$DIR" && pwd) || exit 1
# Never from inside a checkout: a gh command that named no repository would
# take the checkout's, and that is the source.
cd "$DIR" || exit 1

fail() { echo "releases_repo: FAILED, $*" >&2; exit 1; }
gh_() { env -u GITHUB_TOKEN gh "$@"; }
# A command as it would be typed: words with spaces quoted.
said() {
  local a out=""
  for a in "$@"; do
    case $a in *[[:space:]]*) out+=" '$a'";; *) out+=" $a";; esac
  done
  echo "${out# }"
}
# The source, read only: these three reads and nothing else.
from_source() {
  case "$1 $2" in
    "release view"|"release download") gh_ "$@" -R "$SRC";;
    *) echo "releases_repo: refused, $SRC is read only here: gh $*" >&2; exit 2;;
  esac
}
# Every change this makes, all of them on the new repository, which each one
# names. A dry run prints it and does nothing.
write() {
  local a named=0
  for a in "$@"; do
    [ "$a" = "$SRC" ] && { echo "releases_repo: refused, a write naming $SRC: $*" >&2; exit 2; }
    case $a in "$DEST"|"git@github.com:$DEST.git") named=1;; esac
  done
  [ "$named" = 1 ] || { echo "releases_repo: refused, a write that does not name $DEST: $*" >&2; exit 2; }
  if [ "$GO" != 1 ]; then echo "  would: $(said "$@")"; return 0; fi
  echo "  run:   $(said "$@")"
  if [ "$1" = gh ]; then shift; gh_ "$@"; else "$@"; fi
}
human() { numfmt --to=si --suffix=B --format=%.1f "$1"; }

if [ "$GO" = 1 ]; then
  echo "releases_repo: --go: creating $DEST and copying ${TAGS[*]} from $SRC"
else
  echo "releases_repo: dry run: nothing is created, uploaded or changed (--go does it)"
fi
gh_ auth status >/dev/null 2>&1 || fail "gh is not logged in (gh auth login)"
echo "  files in $DIR"

echo "── 1. the releases on $SRC, read only ──"
total=0
for tag in "${TAGS[@]}"; do
  out=$DIR/$tag
  mkdir -p "$out/files"
  from_source release view "$tag" --json name,tagName,body,isDraft,isPrerelease,assets \
    > "$out/source.json" || fail "cannot read $tag on $SRC"
  [ "$(jq -r .isDraft "$out/source.json")" = false ] || fail "$tag on $SRC is a draft"
  jq -j .body "$out/source.json" > "$out/notes.md"
  bytes=$(jq '[.assets[].size] | add' "$out/source.json")
  total=$((total + bytes))
  echo "  $tag  '$(jq -r .name "$out/source.json")'  $(jq '.assets | length' "$out/source.json") files," \
    "$(human "$bytes"), notes $(wc -l < "$out/notes.md") lines"
  if grep -q "github.com/${SRC}[/)]" "$out/notes.md"; then
    echo "  note: $tag's notes link to $SRC, which will not answer once it is private"
  fi
  # Downloaded once: a file already here with GitHub's SHA-256 is kept.
  while read -r name size digest; do
    file=$out/files/$name
    want=${digest#sha256:}
    if [ -z "$want" ] || [ "$want" = null ]; then fail "GitHub gives no SHA-256 for $tag's $name"; fi
    have=""
    [ -f "$file" ] && have=$(sha256sum "$file" | cut -d' ' -f1)
    if [ "$have" != "$want" ]; then
      from_source release download "$tag" --dir "$out/files" --pattern "$name" --clobber \
        || fail "could not download $tag's $name"
      have=$(sha256sum "$file" | cut -d' ' -f1)
    fi
    [ "$have" = "$want" ] || fail "$tag's $name has SHA-256 $have, GitHub says $want"
    [ "$(stat -c %s "$file")" = "$size" ] || fail "$tag's $name is not $size bytes"
    printf '  %s  %s  %s\n' "$have" "$name" "$(human "$size")"
  done < <(jq -r '.assets[] | "\(.name) \(.size) \(.digest)"' "$out/source.json")
  # And the release's own list agrees, naming every package and nothing else.
  listed=$(awk '{print $2}' "$out/files/SHA256SUMS" | sort | tr '\n' ' ')
  packages=$(jq -r '.assets[].name | select(. != "SHA256SUMS")' "$out/source.json" | sort | tr '\n' ' ')
  [ "$listed" = "$packages" ] || fail "$tag's SHA256SUMS lists $listed, the release has $packages"
  (cd "$out/files" && sha256sum --check --quiet SHA256SUMS) || fail "$tag's files do not match its SHA256SUMS"
  echo "  $tag: every file matches GitHub's SHA-256 and SHA256SUMS"
done
echo "  $(human "$total") to copy"

echo "── 2. $DEST: public, its README and the smoke workflow ──"
seed=$DIR/seed
rm -rf "$seed"
mkdir -p "$seed/.github/workflows"
cp "$HERE/releases_repo/README.md" "$seed/README.md"
cp "$HERE/releases_repo/release.yml" "$seed/.github/workflows/release.yml"
git -C "$seed" init -q -b main
git -C "$seed" add README.md .github/workflows/release.yml
git -C "$seed" -c user.name=Xaxis -c user.email=william.neeley@gmail.com commit -q -F - <<'MSG' || fail "could not commit the README"
Keep Brickworks' downloads public, wherever its source is

The download page at brickworks.diy links to the releases here. The
workflow checks each draft on macOS and Windows before it is published.
MSG
echo "  the first commit, $(git -C "$seed" log -1 --format='%h by %an <%ae>: %s'):"
git -C "$seed" show --stat --format= | sed 's/^/    /'
if found=$(gh_ repo view "$DEST" --json visibility,isEmpty --jq '"\(.visibility) \(.isEmpty)"' 2>&1); then
  exists=1
elif echo "$found" | grep -q "Could not resolve to a Repository"; then
  exists=0
else
  fail "cannot ask GitHub about $DEST: $found"
fi
if [ "$exists" = 0 ]; then
  echo "  $DEST does not exist yet"
  write gh repo create "$DEST" --public --description "$DESCRIPTION" --homepage "$HOMEPAGE" \
    || fail "could not create $DEST"
  found="PUBLIC true"
fi
case $found in
  "PUBLIC true")
    # Over SSH: the workflow file needs a token with the workflow scope over
    # HTTPS, and gh's has none.
    write git -C "$seed" push -q "git@github.com:$DEST.git" main || fail "could not push the README to $DEST";;
  "PUBLIC false") echo "  $DEST exists, public, with commits: left as it is";;
  *) fail "$DEST exists but is not public ($found)";;
esac

step=3
for tag in "${TAGS[@]}"; do
  out=$DIR/$tag
  echo "── $step. $tag: a draft on $DEST, checked against the original, then published ──"
  step=$((step + 1))
  title=$(jq -r .name "$out/source.json")
  files=()
  while read -r name; do files+=("$out/files/$name"); done < <(jq -r '.assets[].name' "$out/source.json")
  extra=()
  [ "$(jq -r .isPrerelease "$out/source.json")" = true ] && extra+=(--prerelease)
  latest=--latest=false
  [ "$tag" = "$LATEST" ] && latest=--latest
  state=absent
  if [ "$exists" = 1 ] || [ "$GO" = 1 ]; then
    if view=$(gh_ release view "$tag" -R "$DEST" --json isDraft,assets 2>&1); then
      state=$([ "$(echo "$view" | jq -r .isDraft)" = true ] && echo draft || echo published)
    elif ! echo "$view" | grep -qi "not found"; then
      fail "cannot ask GitHub about $tag on $DEST: $view"
    fi
  fi
  case $state in
    absent)
      write gh release create "$tag" -R "$DEST" --draft --title "$title" --notes-file "$out/notes.md" \
        --target main "${extra[@]}" "${files[@]}" || fail "could not upload $tag to $DEST";;
    draft)
      missing=()
      for file in "${files[@]}"; do
        echo "$view" | jq -e --arg n "${file##*/}" '.assets | any(.name == $n)' >/dev/null || missing+=("$file")
      done
      echo "  a draft $tag is there, ${#missing[@]} file(s) still to upload"
      if [ "${#missing[@]}" -gt 0 ]; then
        write gh release upload "$tag" -R "$DEST" "${missing[@]}" || fail "could not upload to $tag on $DEST"
      fi;;
    published) echo "  $tag is published there already: checking it";;
  esac

  if [ "$GO" != 1 ] && [ "$state" = absent ]; then
    echo "  would check: GitHub's SHA-256 of each of the ${#files[@]} files on $DEST's $tag is the one above;" \
      "the title and notes are $SRC's"
  else
    copy=$(gh_ release view "$tag" -R "$DEST" --json name,body,isDraft,assets) || fail "cannot read $tag on $DEST"
    wrong=0
    while read -r name size digest; do
      theirs=$(echo "$copy" | jq -r --arg n "$name" '.assets[] | select(.name == $n) | "\(.size) \(.digest)"')
      local_sum=$(sha256sum "$out/files/$name" | cut -d' ' -f1)
      if [ "$theirs" = "$size $digest" ] && [ "sha256:$local_sum" = "$digest" ]; then
        echo "  ok    $name  ${digest#sha256:}"
      else
        echo "  FAIL  $name  $SRC has $size $digest, $DEST has ${theirs:-nothing}"
        wrong=$((wrong + 1))
      fi
    done < <(jq -r '.assets[] | "\(.name) \(.size) \(.digest)"' "$out/source.json")
    others=$(echo "$copy" | jq -r --slurpfile s "$out/source.json" \
      '[.assets[].name] - [$s[0].assets[].name] | join(" ")')
    [ -z "$others" ] || { echo "  FAIL  $DEST's $tag also has $others"; wrong=$((wrong + 1)); }
    [ "$(echo "$copy" | jq -r .name)" = "$title" ] || { echo "  FAIL  the title is not '$title'"; wrong=$((wrong + 1)); }
    [ "$(echo "$copy" | jq -j .body | sed 's/[[:space:]]*$//')" = "$(sed 's/[[:space:]]*$//' "$out/notes.md")" ] \
      || { echo "  FAIL  the notes differ from $SRC's"; wrong=$((wrong + 1)); }
    if [ "$wrong" != 0 ]; then
      if [ "$(echo "$copy" | jq -r .isDraft)" = true ]; then
        fail "$wrong difference(s) between $DEST's $tag and $SRC's: left a draft nobody else sees." \
          "To try again: gh release delete $tag -R $DEST --yes, then run this again"
      fi
      fail "$wrong difference(s) between $DEST's $tag, which is published, and $SRC's"
    fi
    echo "  every file, the title and the notes are $SRC's"
  fi
  if [ "$state" != published ]; then
    write gh release edit "$tag" -R "$DEST" --draft=false "$latest" || fail "could not publish $tag on $DEST"
  fi

  # As a visitor: no login, the address the page will link to.
  if [ "$GO" = 1 ]; then
    while read -r name size; do
      url=https://github.com/$DEST/releases/download/$tag/$name
      got=$(curl -sSIL --max-time 60 -o /dev/null -w '%{http_code} %header{content-length}' "$url" 2>&1)
      [ "$got" = "200 $size" ] || fail "$url answered '$got', not 200 with $size bytes"
      echo "  ok    $url"
    done < <(jq -r '.assets[] | "\(.name) \(.size)"' "$out/source.json")
  else
    echo "  would fetch with no login: https://github.com/$DEST/releases/download/$tag/<each file>, 200 with its size"
  fi
done

echo "── done ──"
if [ "$GO" = 1 ]; then
  echo "  $DEST holds ${TAGS[*]}, each the same as $SRC's. $SRC was only read."
  echo "  next: merge the branch that points Brickworks at $DEST and deploy; then"
  echo "  tools/release/release_links.sh web/releases.json passes. Once $SRC is private, set"
  echo "  BRICKWORKS_SOURCE_TOKEN on $DEST (a fine-grained token: Contents read, $SRC only)."
else
  echo "  dry run: nothing was created, uploaded or changed. With the owner's yes:"
  echo "  tools/release/releases_repo.sh --go --dir=$DIR"
fi
