#!/bin/sh
# Brickworks' update helper, on Linux and macOS: what the app cannot do to
# itself while it runs. src/net/updater.gd writes this beside its state and
# starts it as the app quits (docs/UPDATES.md).
#
#   helper.sh MODE PID TARGET STAGED BACKUP MARKER VERSION ABOUT LOG -- LAUNCH...
#
# restart  wait for the app (PID) to end, then start LAUNCH.
# install  wait for it to end; put STAGED in place of TARGET, the old copy
#          kept as BACKUP; ask the copy now there its version (ABOUT --about);
#          start LAUNCH and wait for the new copy to write MARKER. A copy that
#          cannot say its version, or ends before it has started, is taken
#          away and BACKUP put back, then started saying so
#          (--update-failed=VERSION). The new copy takes BACKUP away itself.
# quit     as install, but nothing is started after: the app was quitting.
set -u
mode=$1 pid=$2 target=$3 staged=$4 backup=$5 marker=$6 version=$7 about=$8 log=$9
shift 9
[ "${1:-}" = "--" ] && shift
# The app's terminal closing must not end the swap half done.
trap '' HUP

say() { printf '%s helper: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%S)" "$*" >> "$log"; }

# Gone, or a zombie its parent has not reaped yet.
gone() {
  state=$(ps -o stat= -p "$1" 2>/dev/null) || return 0
  case $state in Z*|"") return 0;; esac
  return 1
}

# The launch command in the background; its pid in $started.
start() {
  "$@" >/dev/null 2>&1 &
  started=$!
}

n=0
until gone "$pid"; do
  n=$((n + 1))
  if [ $n -gt 600 ]; then
    say "the app (pid $pid) did not end in 120 s: nothing changed"
    exit 1
  fi
  sleep 0.2
done

if [ "$mode" = restart ]; then
  start "$@"
  say "restarted (pid $started)"
  exit 0
fi

if [ ! -e "$staged" ]; then
  say "nothing staged at $staged: nothing changed"
  [ "$mode" = install ] && start "$@"
  exit 1
fi

# The swap. A folder (the tar.xz's, the .app) is moved aside and the new one
# moved in, two renames on one disk; the AppImage, one file, is replaced in
# one rename after the old one is linked aside.
if [ -d "$staged" ]; then
  if [ -e "$target" ] && ! mv "$target" "$backup"; then
    say "could not move $target aside: nothing changed"
    [ "$mode" = install ] && start "$@"
    exit 1
  fi
  if ! mv "$staged" "$target"; then
    say "could not move $staged into place: the old copy put back"
    [ -e "$backup" ] && mv "$backup" "$target"
    [ "$mode" = install ] && start "$@" "--update-failed=$version"
    exit 1
  fi
else
  ln -f "$target" "$backup" 2>/dev/null || cp -p "$target" "$backup"
  if ! mv -f "$staged" "$target"; then
    say "could not put $staged in place of $target: nothing changed"
    [ "$mode" = install ] && start "$@"
    exit 1
  fi
fi
say "put $version in place at $target"

# put_back WHY LAUNCH...: the launch command passed on, since a function's
# "$@" is its own.
put_back() {
  say "$1: putting the old copy back"
  shift
  if [ -d "$target" ]; then
    rm -rf "$backup.failed"
    mv "$target" "$backup.failed"
    [ -e "$backup" ] && mv "$backup" "$target"
  elif [ -e "$backup" ]; then
    mv -f "$backup" "$target"
  fi
  [ "$mode" = install ] && start "$@" "--update-failed=$version"
  exit 1
}

# The copy now in place asked which version it is, as a person reporting a
# bug would: a copy that cannot start says nothing.
said="$log.about"
"$about" --headless -- --about > "$said" 2>&1 &
asked=$!
n=0
until gone "$asked"; do
  n=$((n + 1))
  if [ $n -gt 600 ]; then
    kill -9 "$asked" 2>/dev/null
    put_back "the new copy did not say its version in 120 s" "$@"
  fi
  sleep 0.2
done
if ! grep -q "^Brickworks $version" "$said"; then
  put_back "the new copy says $(grep -m1 '^Brickworks' "$said" || echo nothing), not $version" "$@"
fi
rm -f "$said"
say "the new copy says it is $version"

if [ "$mode" = quit ]; then
  exit 0
fi

start "$@"
say "started $version (pid $started); waiting for it to say it is up"
n=0
until [ -e "$marker" ]; do
  if gone "$started"; then
    put_back "the new copy ended before its window was up" "$@"
  fi
  n=$((n + 1))
  if [ $n -gt 900 ]; then
    say "the new copy is still starting after 180 s: left to it"
    exit 0
  fi
  sleep 0.2
done
say "$version is up"
exit 0
