#!/usr/bin/env python3
"""A person's own key in the system's real keychain, through the app's own
KeyStore (src/ai/key_store.gd), across restarts: a Mac's login Keychain and
Windows' Credential Manager on a release's runners, where keychain_probe can
only drive stand-ins, and the Secret Service on Linux inside
tools/keyring_session.sh.

    tools/keychain_check.py GODOT
        GODOT: a Godot 4.7 binary (the editor, as a runner downloads it).
        A project of its own is made in a temporary folder with this
        checkout's key_store.gd in it, and each step is a new run of GODOT,
        as a restart of the app is: a made-up key kept, in the keychain and
        no file; read back after a restart; the system's own tool asked
        whether it holds it (security, cmdkey, secret-tool); removed; read
        back as gone, and the tool asked again. No file of the run's data
        holds the key at any step, and no step is given it on its command
        line.

It keeps a key, so it runs only where the keychain is a throwaway's: a
GitHub runner (GITHUB_ACTIONS), or on Linux a keyring_session.sh.
"""

from __future__ import annotations

import json
import os
import secrets
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
NAME = "keychain-check.key"
PROJECT = 'config_version=5\n\n[application]\n\nconfig/name="Brickworks keychain check"\n'
# One step of the app, in a run of its own. It prints what it found, never
# the key: "same" says whether what came back is what was given.
DRIVE = """extends SceneTree

const Store := preload("res://src/ai/key_store.gd")
const PATH := "user://%s"


func _initialize() -> void:
	var step: String = OS.get_cmdline_user_args()[0]
	var key: String = OS.get_environment("KEYCHAIN_CHECK_KEY")
	var said: Dictionary = {"step": step, "route": Store.keychain(),
		"data": OS.get_user_data_dir(), "hash": OS.get_user_data_dir().sha256_text().left(16)}
	match step:
		"save":
			said["went"] = Store.write(PATH, key)
		"read":
			said["same"] = Store.read(PATH) == key
		"remove":
			Store.remove(PATH)
		"gone":
			said["length"] = Store.read(PATH).length()
	said["place"] = Store.place(PATH)
	said["words"] = Store.said(Store.place(PATH), false)
	said["file"] = FileAccess.file_exists(PATH)
	print("keychain-check: " + JSON.stringify(said))
	quit(0)
""" % NAME

failures = 0


def check(what: str, ok: bool, detail: str = "") -> None:
    global failures
    print("  %s  %s" % ("ok  " if ok else "FAIL", what), flush=True)
    if not ok:
        failures += 1
        for line in detail.strip().splitlines()[-15:]:
            print("        " + line, flush=True)


def step(godot: str, project: Path, name: str, key: str) -> dict:
    done = subprocess.run([godot, "--headless", "--path", str(project), "--script", "res://drive.gd",
                           "--", name], env=dict(os.environ, KEYCHAIN_CHECK_KEY=key),
                          capture_output=True, text=True, errors="replace", timeout=300)
    for line in done.stdout.splitlines():
        if line.startswith("keychain-check: "):
            return json.loads(line[len("keychain-check: "):])
    raise SystemExit("keychain_check: the %s step said nothing (exit %d)\n%s" % (
        name, done.returncode, (done.stdout + done.stderr)[-3000:]))


def held(said: dict, key: str) -> tuple[bool, str]:
    """Whether the system's own tool finds the key KeyStore kept, and what
    it says of where; asked as a person would ask it, not through the app."""
    account = "%s@%s" % (NAME, said["hash"])
    if sys.platform == "darwin":
        where = subprocess.run(["security", "find-generic-password", "-s", "Brickworks", "-a", account],
                               capture_output=True, text=True)
        secret = subprocess.run(["security", "find-generic-password", "-s", "Brickworks", "-a", account,
                                 "-w"], capture_output=True, text=True)
        keychain = next((line.split(":", 1)[1].strip() for line in where.stdout.splitlines()
                         if line.startswith("keychain:")), "no keychain")
        return secret.returncode == 0 and secret.stdout.strip() == key, \
            "security find-generic-password: %s, exit %d" % (keychain, where.returncode)
    if os.name == "nt":
        target = "Brickworks/" + account
        listed = subprocess.run(["cmdkey", "/list:" + target], capture_output=True, text=True)
        # Its heading names the target whether it is there or not ("* NONE *").
        found = next((line.strip() for line in listed.stdout.splitlines()
                      if line.strip().startswith("Target:") and line.strip().endswith(target)), "")
        return bool(found), "cmdkey /list: %s" % (found or "* NONE *")
    looked = subprocess.run(["secret-tool", "lookup", "application", "brickworks", "key", NAME,
                             "data", said["hash"]], capture_output=True, text=True)
    return looked.returncode == 0 and looked.stdout.strip() == key, \
        "secret-tool lookup: exit %d" % looked.returncode


def in_files(folder: Path, key: str) -> list[str]:
    if not folder.exists():
        return []
    return sorted(str(path.relative_to(folder)) for path in folder.rglob("*")
                  if path.is_file() and key.encode() in path.read_bytes())


def main(argv: list[str]) -> int:
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    if not (os.environ.get("GITHUB_ACTIONS") == "true"
            or sys.platform.startswith("linux") and os.environ.get("BRICKWORKS_KEYRING_SESSION") == "1"):
        print("keychain_check: SKIPPED: it keeps a key, so only on a runner or inside "
              "tools/keyring_session.sh, never in a person's keychain")
        return 3
    godot = argv[0]
    # Made up here and given in each step's environment, never as an
    # argument; a real key's shape, so nothing passes for being short.
    key = "sk-ant-api03-check-" + secrets.token_urlsafe(32)
    with tempfile.TemporaryDirectory(prefix="brickworks-keychain-") as scratch:
        project = Path(scratch)
        (project / "project.godot").write_text(PROJECT)
        (project / "src" / "ai").mkdir(parents=True)
        shutil.copy2(ROOT / "src" / "ai" / "key_store.gd", project / "src" / "ai" / "key_store.gd")
        (project / "drive.gd").write_text(DRIVE)
        saved = step(godot, project, "save", key)
        data = Path(saved["data"])
        try:
            print("── KeyStore in %s, data in %s ──" % (saved["route"], data), flush=True)
            check("a made-up key given is kept in %s: %s" % (saved["went"] or "nothing", saved["words"]),
                  saved["went"] == saved["route"] and saved["route"] != "file" and not saved["file"],
                  json.dumps(saved))
            found, how = held(saved, key)
            check("...the system's own tool finds it there: %s" % how, found)
            back = step(godot, project, "read", key)
            check("read back after a restart, from %s: %s" % (back["place"], "the same key" if back["same"]
                                                              else "not the key given"),
                  back["same"] and back["place"] == saved["route"] and not back["file"], json.dumps(back))
            check("no file of the app's data holds it: %s" % (", ".join(in_files(data, key)) or "none does"),
                  not in_files(data, key))
            removed = step(godot, project, "remove", key)
            gone = step(godot, project, "gone", key)
            found, how = held(saved, key)
            check("removed, the next run reads no key (%d characters), kept nowhere (%s)"
                  % (gone["length"], gone["place"] or "no place"),
                  gone["length"] == 0 and not gone["place"] and not removed["file"] and not gone["file"],
                  json.dumps(gone))
            check("...and the system's own tool finds it no more: %s" % how, not found)
        finally:
            # The run's data folder, and the key wherever a failed step left it.
            if held(saved, key)[0]:
                step(godot, project, "remove", key)
            shutil.rmtree(data, ignore_errors=True)
    print("")
    if failures:
        print("keychain_check: %d check(s) failed in %s" % (failures, saved["route"]))
        return 1
    print("keychain_check: a key kept in %s, read back after a restart, and removed" % saved["route"])
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
