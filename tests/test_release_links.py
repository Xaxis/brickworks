"""Every address in the download page's manifest answers a visitor.

tools/release/release_links.sh asks for each release's page and every file
in web/releases.json with no login, through GitHub's redirect to where the
file is kept, and a file must answer 200 at the size the manifest gives it.
ship.sh holds a release on it. These run it against a server on this
machine that redirects as GitHub does: a manifest whose links all answer
passes, and one with a file missing, or a file of another size, fails and
names that address.
"""

from __future__ import annotations

import functools
import http.server
import json
import shutil
import subprocess
import tempfile
import threading
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "tools" / "release" / "release_links.sh"


class _Releases(http.server.SimpleHTTPRequestHandler):
    """A release's file is a redirect to where it is kept, as on GitHub."""

    def do_HEAD(self) -> None:
        if self.path.startswith("/releases/download/"):
            self.send_response(302)
            self.send_header("Location", "/kept/" + self.path.rsplit("/", 1)[1])
            self.end_headers()
            return
        super().do_HEAD()

    def log_message(self, *args) -> None:
        pass


def _check(kept: dict[str, int | None]) -> subprocess.CompletedProcess:
    """release_links.sh on a manifest of one release with these files, each
    listed at 100 bytes and kept at the size given, or not at all (None)."""
    if not shutil.which("curl"):
        pytest.skip("no curl on this machine")
    where = Path(tempfile.mkdtemp(prefix="brickworks-links-test-"))
    (where / "kept").mkdir()
    (where / "page.html").write_text("the release's page")
    files = []
    for name, size in kept.items():
        if size is not None:
            (where / "kept" / name).write_bytes(b"x" * size)
        files.append({"name": name, "size": 100})
    server = http.server.ThreadingHTTPServer(
        ("127.0.0.1", 0), functools.partial(_Releases, directory=str(where)))
    threading.Thread(target=server.serve_forever, daemon=True).start()
    base = "http://127.0.0.1:%d" % server.server_address[1]
    for f in files:
        f["url"] = "%s/releases/download/v1.0.0/%s" % (base, f["name"])
    manifest = where / "releases.json"
    manifest.write_text(json.dumps({"latest": "1.0.0", "releases": [
        {"version": "1.0.0", "page": base + "/page.html", "notes": base + "/page.html",
         "files": files}]}))
    try:
        return subprocess.run(["bash", str(SCRIPT), str(manifest)], capture_output=True,
                              text=True, timeout=120)
    finally:
        server.shutdown()
        server.server_close()
        shutil.rmtree(where, ignore_errors=True)


def test_a_manifest_whose_files_all_answer_passes():
    done = _check({"Brickworks-1.0.0-linux-x86_64.tar.xz": 100, "SHA256SUMS": 100})
    assert done.returncode == 0, done.stdout
    assert done.stdout.count("  ok    ") == 3
    assert "all 3 addresses" in done.stdout


def test_a_file_that_is_not_there_fails_by_name():
    done = _check({"Brickworks-1.0.0-linux-x86_64.tar.xz": 100, "SHA256SUMS": None})
    assert done.returncode == 1, done.stdout
    failed = [line for line in done.stdout.splitlines() if line.startswith("  FAIL")]
    assert len(failed) == 1 and "/SHA256SUMS" in failed[0] and "'404" in failed[0], failed
    assert "1 of 3 addresses" in done.stdout


def test_a_file_of_another_size_fails():
    # Listed at 100 bytes, kept at 99: a different file from the one the
    # page gives the size and SHA-256 of.
    done = _check({"Brickworks-1.0.0-linux-x86_64.tar.xz": 99})
    assert done.returncode == 1, done.stdout
    assert "answered '200 99', not 200 100" in done.stdout
