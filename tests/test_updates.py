"""The desktop updater's two edges outside the app (docs/UPDATES.md).

latest.json, as tools/release.py signs it and checks it the way the app
reads it (src/net/updates.gd): believed only under a signature by a key the
app carries, over its exact words, and refused when anything in it is not a
release's. And the helper that swaps a copy for its update once the app has
quit (src/net/update_helper.sh): the new copy in place and started, or, when
it cannot say its version or ends before its window is up, the old one put
back and started saying so. Both run on throwaway keys and folders.

The app's own half (the version order, the manifest read in GDScript, the
notice, the menu and the setting) is updater_probe's; a real package
updating itself end to end is tools/update_check.py's.
"""

from __future__ import annotations

import base64
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import release  # noqa: E402
import update_check  # noqa: E402

HELPER = ROOT / "src" / "net" / "update_helper.sh"
HAVE_OPENSSL = shutil.which("openssl") is not None


def _key(where: Path) -> tuple[bytes, str, str]:
    """A throwaway RSA key: its private PEM, its id and its public PEM."""
    private = where / "key.pem"
    subprocess.run(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048",
                    "-out", str(private)], check=True, capture_output=True)
    public = subprocess.run(["openssl", "pkey", "-in", str(private), "-pubout"], check=True,
                            capture_output=True, text=True).stdout
    der = subprocess.run(["openssl", "pkey", "-in", str(private), "-pubout", "-outform", "DER"],
                         check=True, capture_output=True).stdout
    return private.read_bytes(), release.update_key_id(der), public


def _manifest(url: str = "") -> dict:
    name = "Brickworks-9.0.0-linux-x86_64.AppImage"
    return {"product": release.UPDATE_PRODUCT, "version": "9.0.0", "date": "2026-11-03",
            "tag": "v9.0.0", "page": "https://github.com/%s/releases/tag/v9.0.0" % release.REPO,
            "notes": "Better.", "files": [{"os": "linux", "kind": "AppImage", "name": name,
             "url": url or "https://github.com/%s/releases/download/v9.0.0/%s" % (release.REPO, name),
             "size": 12, "sha256": "ab" * 32}]}


@pytest.mark.skipif(not HAVE_OPENSSL, reason="no openssl")
def test_a_signed_manifest_holds_and_a_changed_one_does_not() -> None:
    with tempfile.TemporaryDirectory() as scratch:
        pem, key_id, public = _key(Path(scratch))
        envelope = release.sign_update_manifest(_manifest(), keys=[pem])
        assert [s["key"] for s in envelope["signatures"]] == [key_id]
        assert release.check_update_manifest(envelope, {key_id: public}) == []
        # One byte of the words changed after signing: the version the app
        # would install.
        forged = dict(envelope, signed=envelope["signed"].replace("9.0.0", "9.0.1"))
        assert release.check_update_manifest(forged, {key_id: public}) == [
            "no signature by a key the app carries holds"]
        # A key the app does not carry signs nothing it believes.
        other, other_id, other_public = _key(Path(scratch) / "..")
        assert release.check_update_manifest(envelope, {other_id: other_public}) == [
            "no signature by a key the app carries holds"]


@pytest.mark.skipif(not HAVE_OPENSSL, reason="no openssl")
def test_a_manifest_off_the_release_is_refused() -> None:
    with tempfile.TemporaryDirectory() as scratch:
        pem, key_id, public = _key(Path(scratch))
        wrong = _manifest("https://example.com/Brickworks-9.0.0-linux-x86_64.AppImage")
        wrong["product"] = "something-else"
        problems = release.check_update_manifest(release.sign_update_manifest(wrong, keys=[pem]),
                                                 {key_id: public})
        assert any("product" in p for p in problems)
        assert any("not on the release" in p for p in problems)


def test_the_keys_the_app_carries_are_the_ids_it_names() -> None:
    """Each public key in updates.gd is under the id of its own DER: a key
    pasted under another's id, or cut short, is caught here, not by every
    copy of the app refusing the next release."""
    keys = release.app_update_keys()
    assert len(keys) == 2, keys.keys()
    for key_id, pem in keys.items():
        if HAVE_OPENSSL:
            assert release.update_key_id(release._public_der(pem)) == key_id
        der = base64.b64decode("".join(pem.strip().splitlines()[1:-1]))
        assert len(der) > 400, "%s is not a 3072-bit RSA key" % key_id


def test_the_manifest_lists_every_package_on_its_release() -> None:
    files = [{"os": "linux", "kind": "AppImage", "name": "Brickworks-0.1.0-linux-x86_64.AppImage",
              "size": 10, "sha256": "a" * 64},
             {"os": "windows", "kind": "zip", "name": "Brickworks-0.1.0-windows-x86_64.zip",
              "size": 20, "sha256": "b" * 64}]
    urls = {f["name"]: "https://github.com/%s/releases/download/v0.1.0/%s" % (release.REPO, f["name"])
            for f in files}
    kept = release.ROOT
    with tempfile.TemporaryDirectory() as scratch:
        (Path(scratch) / "CHANGELOG.md").write_text(
            "# Changelog\n\n## [0.1.0] - 2026-10-10\n\nThe first one.\n\n### Added\n- All.\n")
        release.ROOT = Path(scratch)
        try:
            made = release.update_manifest("0.1.0", "v0.1.0", files, "2026-10-10", urls)
        finally:
            release.ROOT = kept
    assert made["product"] == release.UPDATE_PRODUCT and made["version"] == "0.1.0"
    assert made["notes"] == "The first one."
    assert [(f["os"], f["kind"], f["size"], f["sha256"]) for f in made["files"]] == [
        ("linux", "AppImage", 10, "a" * 64), ("windows", "zip", 20, "b" * 64)]
    assert all(f["url"] == urls[f["name"]] for f in made["files"])


# -- the helper -------------------------------------------------------------

def _app(folder: Path, version: str, starts: bool = True) -> Path:
    """A stand-in for Brickworks in [folder]: says [version] to --about, and
    started as the app, writes down how and writes the marker (when it
    [starts]) as the real one does once its window is up."""
    folder.mkdir(parents=True, exist_ok=True)
    program = folder / "brickworks.x86_64"
    program.write_text("#!/bin/sh\n"
                       'case "$*" in *--about*) echo "Brickworks %s, released 2026-11-03"; exit 0;; esac\n'
                       'echo "%s $*" >> "$(dirname "$0")/../launched"\n' % (version, version)
                       + ('touch "$UPDATE_MARKER"\nsleep 1\n' if starts else "exit 3\n"))
    program.chmod(0o755)
    return program


def _helper(mode: str, target: Path, staged: Path, backup: Path, marker: Path, version: str,
            about: Path, log: Path, launch: list[str]) -> int:
    gone = subprocess.Popen(["sleep", "0.3"])
    done = subprocess.run(["/bin/sh", str(HELPER), mode, str(gone.pid), str(target), str(staged),
                           str(backup), str(marker), version, str(about), str(log), "--", *launch],
                          env=dict(os.environ, UPDATE_MARKER=str(marker)), timeout=90)
    gone.wait()
    return done.returncode


def _wait_for(path: Path, words: str, seconds: float = 10.0) -> str:
    until = time.time() + seconds
    while time.time() < until:
        if path.exists() and words in path.read_text():
            return path.read_text()
        time.sleep(0.1)
    return path.read_text() if path.exists() else ""


@pytest.mark.skipif(os.name == "nt", reason="the POSIX helper")
def test_the_helper_puts_the_new_copy_in_and_starts_it() -> None:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        target = root / "Brickworks"
        _app(target, "1.0.0")
        stage = root / ".brickworks-update" / "2.0.0"
        staged = stage / "Brickworks-2.0.0-linux-x86_64"
        _app(staged, "2.0.0")
        log, marker = root / "log.txt", root / "started-2.0.0"
        code = _helper("install", target, staged, stage / "previous", marker, "2.0.0",
                       target / "brickworks.x86_64", log,
                       [str(target / "brickworks.x86_64"), "--", "--session=abcd"])
        said = log.read_text()
        assert code == 0, said
        assert "2.0.0 is up" in said
        assert "Brickworks 2.0.0" in subprocess.run([str(target / "brickworks.x86_64"), "--about"],
                                                    capture_output=True, text=True).stdout
        assert (stage / "previous" / "brickworks.x86_64").exists(), "the old copy kept until it started"
        assert not staged.exists()
        assert (root / "launched").read_text().split() == ["2.0.0", "--", "--session=abcd"]


@pytest.mark.skipif(os.name == "nt", reason="the POSIX helper")
@pytest.mark.parametrize("fault", ["says another version", "ends before its window is up"])
def test_a_new_copy_that_cannot_start_is_put_back(fault: str) -> None:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        target = root / "Brickworks"
        _app(target, "1.0.0")
        stage = root / ".brickworks-update" / "2.0.0"
        staged = stage / "Brickworks-2.0.0-linux-x86_64"
        _app(staged, "2.0.1" if fault == "says another version" else "2.0.0", starts=False)
        log, marker = root / "log.txt", root / "started-2.0.0"
        code = _helper("install", target, staged, stage / "previous", marker, "2.0.0",
                       target / "brickworks.x86_64", log,
                       [str(target / "brickworks.x86_64"), "--", "--session=abcd"])
        said = log.read_text()
        assert code == 1, said
        assert "putting the old copy back" in said
        assert "Brickworks 1.0.0" in subprocess.run([str(target / "brickworks.x86_64"), "--about"],
                                                    capture_output=True, text=True).stdout
        launched = _wait_for(root / "launched", "1.0.0 ")
        # The old one, started again, told which version did not start.
        assert "1.0.0 -- --session=abcd --update-failed=2.0.0" in launched, launched


@pytest.mark.skipif(os.name == "nt", reason="the POSIX helper")
def test_on_quit_the_update_goes_in_and_nothing_starts() -> None:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        target = root / "Brickworks"
        _app(target, "1.0.0")
        stage = root / ".brickworks-update" / "2.0.0"
        staged = stage / "Brickworks-2.0.0-linux-x86_64"
        _app(staged, "2.0.0")
        log = root / "log.txt"
        code = _helper("quit", target, staged, stage / "previous", root / "started-2.0.0", "2.0.0",
                       target / "brickworks.x86_64", log, [str(target / "brickworks.x86_64"), "--"])
        assert code == 0, log.read_text()
        assert "says it is 2.0.0" in log.read_text()
        time.sleep(0.5)
        assert not (root / "launched").exists()


@pytest.mark.skipif(os.name == "nt", reason="the POSIX helper")
def test_an_appimage_is_replaced_in_one_rename_with_the_old_one_kept() -> None:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        image = _app(root / "apps", "1.0.0").rename(root / "apps" / "Brickworks.AppImage")
        stage = root / "apps" / ".brickworks-update" / "2.0.0"
        new = _app(stage, "2.0.0").rename(stage / "Brickworks.AppImage")
        log, marker = root / "log.txt", root / "started-2.0.0"
        code = _helper("install", image, new, stage / "previous.AppImage", marker, "2.0.0", image,
                       log, [str(image), "--"])
        assert code == 0, log.read_text()
        assert "Brickworks 2.0.0" in subprocess.run([str(image), "--about"], capture_output=True,
                                                    text=True).stdout
        kept = stage / "previous.AppImage"
        assert "Brickworks 1.0.0" in subprocess.run([str(kept), "--about"], capture_output=True,
                                                    text=True).stdout


@pytest.mark.skipif(os.name == "nt", reason="the POSIX helper")
def test_restart_starts_it_again_once_the_app_has_gone() -> None:
    with tempfile.TemporaryDirectory() as scratch:
        root = Path(scratch)
        program = _app(root / "Brickworks", "1.0.0")
        log = root / "log.txt"
        code = _helper("restart", Path("-"), Path("-"), Path("-"), root / "started-1.0.0", "1.0.0",
                       Path("-"), log, [str(program), "--", "--session=abcd"])
        assert code == 0
        assert "1.0.0 -- --session=abcd" in _wait_for(root / "launched", "--session=abcd")


def test_the_helpers_are_shipped_in_every_desktop_package() -> None:
    presets = (ROOT / "export_presets.cfg").read_text()
    for preset in ("macOS", "Linux", "Windows"):
        block = presets.split('name="%s"' % preset, 1)[1].split("[preset.", 1)[0]
        assert "src/net/update_helper.sh" in block and "src/net/update_helper.ps1" in block, preset


def test_shellcheck_has_nothing_to_say_of_the_helper() -> None:
    if shutil.which("shellcheck") is None:
        pytest.skip("no shellcheck")
    done = subprocess.run(["shellcheck", "-s", "sh", str(HELPER)], capture_output=True, text=True)
    assert done.returncode == 0, done.stdout


def test_a_test_package_s_version_is_read_without_its_system():
    # "-linux" once read as a pre-release: 0.91.0-linux, which no copy says.
    assert update_check.version_in("Brickworks-0.91.0-linux-x86_64.AppImage") == "0.91.0"
    assert update_check.version_in("Brickworks-0.91.0-macos-universal.zip") == "0.91.0"
    assert update_check.version_in("Brickworks-1.0.0-beta.2-windows-x86_64.zip") == "1.0.0-beta.2"
