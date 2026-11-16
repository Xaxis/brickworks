"""tools/web/place_build.py: deploy.sh puts the engine's own files at an
address of their bytes, /e/<hash>/, and the rest of the build under
/b/<sha>/, and points the page at each, so a person back after a release
keeps the 6.9 MB engine while it is the same (webstart10, 2026-11-16).

A build is made here as Godot's export lays it out, with the page's
GODOT_CONFIG and the shell's preloads, and placed twice under two shas.
"""

from __future__ import annotations

import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "tools/web/place_build.py"
_spec = importlib.util.spec_from_file_location("place_build", SCRIPT)
place_build = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(place_build)

PAGE = """<!DOCTYPE html><html><head>
<link rel="preload" href="index.wasm" as="fetch" crossorigin>
<link rel="preload" href="index.pck" as="fetch" crossorigin>
<link rel="icon" href="index.icon.png">
<link rel="stylesheet" href="https://fonts.example/x.css">
</head><body>
<script src="index.js"></script>
<script>
const GODOT_CONFIG = {"args":[],"executable":"index","fileSizes":{"index.pck":1300,"index.wasm":3900},"mainPack":""};
</script></body></html>
"""


def export(static: Path, sha: str, wasm: bytes = b"\0asm engine") -> Path:
    """A build as deploy.sh copies it to STATIC/b/SHA/."""
    build = static / "b" / sha
    build.mkdir(parents=True)
    (build / "index.html").write_text(PAGE)
    for name, body in [("index.js", b"engine script"), ("index.wasm", wasm), ("index.pck", b"pack " + sha.encode()),
                       ("index.data.pck", b"data"), ("index.audio.worklet.js", b"worklet"),
                       ("index.audio.position.worklet.js", b"position"), ("index.icon.png", b"png")]:
        (build / name).write_bytes(body)
    for name in ["index.js", "index.wasm", "index.pck", "index.data.pck"]:
        (build / (name + ".br")).write_bytes(b"br " + (build / name).read_bytes())
    return build


def config_of(page: str) -> dict:
    found = re.search(r"const GODOT_CONFIG = ", page)
    return json.JSONDecoder().raw_decode(page, found.end())[0]


def run(static: Path, sha: str) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), str(static), sha], capture_output=True, text=True, timeout=60)


def test_the_engine_moves_to_an_address_of_its_bytes_and_the_page_names_it(tmp_path):
    build = export(tmp_path, "abc1234")
    said = run(tmp_path, "abc1234")
    assert said.returncode == 0, said.stderr
    digest = said.stdout.strip()
    assert re.fullmatch(r"[0-9a-f]{16}", digest)
    home = tmp_path / "e" / digest
    for name in ["index.js", "index.js.br", "index.wasm", "index.wasm.br",
                 "index.audio.worklet.js", "index.audio.position.worklet.js"]:
        assert (home / name).is_file(), name
        assert not (build / name).exists(), name
    for name in ["index.pck", "index.pck.br", "index.data.pck", "index.icon.png", "index.html"]:
        assert (build / name).is_file(), name
    page = (build / "index.html").read_text()
    assert f'<script src="/e/{digest}/index.js">' in page
    assert f'<link rel="preload" href="/e/{digest}/index.wasm"' in page
    assert '<link rel="preload" href="/b/abc1234/index.pck"' in page
    assert 'href="/b/abc1234/index.icon.png"' in page
    assert 'href="https://fonts.example/x.css"' in page
    config = config_of(page)
    # The build's own folder stays the executable's: the packs, knowledge
    # and version.json are read beside it.
    assert config["executable"] == "/b/abc1234/index"
    assert config["engine"] == f"/e/{digest}/index"
    assert config["fileSizes"] == {"/b/abc1234/index.pck": 1300, f"/e/{digest}/index.wasm": 3900}


def test_two_releases_of_one_engine_share_its_address_and_a_new_engine_does_not(tmp_path):
    export(tmp_path, "aaaaaaa")
    export(tmp_path, "bbbbbbb")
    first, second = run(tmp_path, "aaaaaaa"), run(tmp_path, "bbbbbbb")
    assert first.returncode == 0 and second.returncode == 0, first.stderr + second.stderr
    assert first.stdout == second.stdout
    pages = [(tmp_path / "b" / sha / "index.html").read_text() for sha in ("aaaaaaa", "bbbbbbb")]
    assert config_of(pages[0])["engine"] == config_of(pages[1])["engine"]
    assert config_of(pages[0])["executable"] != config_of(pages[1])["executable"]
    export(tmp_path, "ccccccc", wasm=b"\0asm another engine")
    third = run(tmp_path, "ccccccc")
    assert third.returncode == 0, third.stderr
    assert third.stdout != first.stdout
    # The first engine's files are still where its pages say.
    assert (tmp_path / "e" / first.stdout.strip() / "index.wasm").read_bytes() == b"\0asm engine"


def test_a_build_with_no_engine_or_no_config_is_refused(tmp_path):
    build = export(tmp_path, "abc1234")
    (build / "index.wasm").unlink()
    said = run(tmp_path, "abc1234")
    assert said.returncode == 1 and "index.wasm" in said.stderr
    build2 = export(tmp_path, "def5678")
    (build2 / "index.html").write_text(PAGE.replace("const GODOT_CONFIG = ", "const OTHER = "))
    said = run(tmp_path, "def5678")
    assert said.returncode == 1 and "GODOT_CONFIG" in said.stderr
    assert run(tmp_path, "not-a-sha").returncode == 2


def test_deploy_serves_the_engine_as_it_serves_the_build():
    """deploy.sh's routes give /e/ the app's isolation and policy (each of the
    engine's threads runs by the policy its script was sent with), cache it
    for good and send its brotli."""
    deploy = (ROOT / "tools/deploy.sh").read_text()
    assert '"src": "/(app|b/.*|e/.*)"' in deploy
    assert re.search(r'"src": "/e/\(\[\^/\]\+\)/\(\.\*\)",\s*"headers": \{ "Cache-Control": "public, max-age=31536000, immutable"', deploy)
    assert '"dest": "/e/$engine/\\$1.br"' in deploy
    # Sent with nosniff, the script runs only as a script's type, and the
    # wasm streams only as application/wasm.
    assert '\\"e/$engine/index.js.br\\": { \\"contentType\\": \\"application/javascript; charset=utf-8\\" }' in deploy
    assert '\\"e/$engine/index.wasm.br\\": { \\"contentType\\": \\"application/wasm\\" }' in deploy
    assert "b/$sha/index.js.br" not in deploy and "b/$sha/index.wasm.br" not in deploy
    assert 'engine="$(python3 tools/web/place_build.py .vercel/output/static "$sha")"' in deploy


def test_the_shell_starts_the_engine_from_its_own_address():
    shell = (ROOT / "src/boot/shell.html").read_text()
    assert "engine.init(GODOT_CONFIG.engine || engine.config.executable)" in shell
