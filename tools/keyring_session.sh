#!/bin/bash
# keyring_session.sh CMD... : CMD in a desktop keyring of its own, never the
# person's: a D-Bus session of its own with a fresh GNOME Keyring in it,
# unlocked and empty, removed when CMD ends. For keychain_probe, which keeps
# made-up keys in the Secret Service as the app does (src/ai/key_store.gd):
#
#   tools/keyring_session.sh tools/probe.sh keychain_probe
#
# secret-tool is the libsecret-tools package, not on every desktop: where it
# is not installed, its package is fetched (apt-get download, no root) and
# unpacked into ~/.cache/brickworks/secret-tool, and put first on PATH.
# BRICKWORKS_KEYRING_SESSION=1 says to the probe it is in one.
set -u
command -v gnome-keyring-daemon >/dev/null && command -v dbus-run-session >/dev/null || {
  echo "keyring_session: needs gnome-keyring-daemon and dbus-run-session"; exit 2; }
if ! command -v secret-tool >/dev/null; then
  cache="$HOME/.cache/brickworks/secret-tool"
  if [ ! -x "$cache/usr/bin/secret-tool" ]; then
    got=$(mktemp -d)
    (cd "$got" && apt-get download libsecret-tools >/dev/null 2>&1) && mkdir -p "$cache" \
      && dpkg -x "$got"/libsecret-tools_*.deb "$cache"
    rm -rf "$got"
  fi
  [ -x "$cache/usr/bin/secret-tool" ] && export PATH="$cache/usr/bin:$PATH"
fi
home=$(mktemp -d "${TMPDIR:-/tmp}/bw-keyring.XXXXXX")
# A socket's path is at most 108 bytes, which a scratch folder can be past.
run=$(mktemp -d /tmp/bwkr.XXXXXX)
trap 'rm -rf "$home" "$run"' EXIT
chmod 700 "$run"
# No display: a keyring that wanted to ask would ask on the person's screen.
env -u DISPLAY -u WAYLAND_DISPLAY XDG_DATA_HOME="$home" \
  XDG_RUNTIME_DIR="$run" BRICKWORKS_KEYRING_SESSION=1 \
  dbus-run-session -- bash -c '
    # Unlocking with a password on the input makes the login keyring, unlocked.
    eval "$(printf probe-pass | gnome-keyring-daemon --unlock --components=secrets 2>/dev/null)"
    for _ in $(seq 100); do
      gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
        --method org.freedesktop.DBus.NameHasOwner org.freedesktop.secrets 2>/dev/null \
        | grep -q true && break
      read -r -t 0.1 < <(:) || true
    done
    cd "$0" && "$@"' "$(pwd)" "$@"
