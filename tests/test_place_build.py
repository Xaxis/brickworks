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
<link rel="preload" href="index.pck" as="fetch" crossorigin>
<link rel="icon" href="index.icon.png">
<link rel="stylesheet" href="https://fonts.example/x.css">
<script>
const GODOT_CONFIG = {"args":[],"emscriptenPoolSize":8,"ensureCrossOriginIsolationHeaders":true,"executable":"index","fileSizes":{"index.pck":1300,"index.wasm":3900},"godotPoolSize":4,"mainPack":""};
const GODOT_THREADS_ENABLED = true;
</script></head><body>
</body></html>
"""
# The same project's export without threads, as Godot writes it: only its
# pool sizes, its isolation flag, its wasm's size and its threads flag differ.
PAGE_NT = (PAGE.replace('"emscriptenPoolSize":8', '"emscriptenPoolSize":4').replace('"godotPoolSize":4', '"godotPoolSize":2')
           .replace('"ensureCrossOriginIsolationHeaders":true', '"ensureCrossOriginIsolationHeaders":false')
           .replace('"index.wasm":3900', '"index.wasm":4100').replace("GODOT_THREADS_ENABLED = true", "GODOT_THREADS_ENABLED = false"))


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


def export_nothreads(where: Path, build: Path) -> Path:
    """The export without threads beside BUILD: its packs BUILD's, its engine its own."""
    other = where / "web-nothreads"
    other.mkdir(parents=True)
    (other / "index.html").write_text(PAGE_NT)
    for name in ["index.pck", "index.data.pck", "index.audio.worklet.js", "index.audio.position.worklet.js", "index.icon.png"]:
        (other / name).write_bytes((build / name).read_bytes())
    for name, body in [("index.js", b"engine script, no threads"), ("index.wasm", b"\0asm engine, no threads")]:
        (other / name).write_bytes(body)
        (other / (name + ".br")).write_bytes(b"br " + body)
    (other / "index.wasm.gz").write_bytes(b"gz")
    return other


def config_of(page: str) -> dict:
    found = re.search(r"const GODOT_CONFIG = ", page)
    return json.JSONDecoder().raw_decode(page, found.end())[0]


def run(static: Path, sha: str, *other: Path) -> subprocess.CompletedProcess:
    return subprocess.run([sys.executable, str(SCRIPT), str(static), sha, *map(str, other)],
                          capture_output=True, text=True, timeout=60)


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
    # The page asks for the engine it chose from GODOT_CONFIG.engine: no
    # markup names the engine's files.
    assert "index.js" not in page and "index.wasm\"" not in page.split("const GODOT_CONFIG")[0]
    assert '<link rel="preload" href="/b/abc1234/index.pck"' in page
    assert 'href="/b/abc1234/index.icon.png"' in page
    assert 'href="https://fonts.example/x.css"' in page
    config = config_of(page)
    # The build's own folder stays the executable's: the packs, knowledge
    # and version.json are read beside it.
    assert config["executable"] == "/b/abc1234/index"
    assert config["engine"] == f"/e/{digest}/index"
    assert config["fileSizes"] == {"/b/abc1234/index.pck": 1300, f"/e/{digest}/index.wasm": 3900}
    assert "nothreads" not in config


def test_the_page_compressed_before_it_was_pointed_goes(tmp_path):
    # export.sh writes index.html.br of the unpointed page. serve.py
    # --compressed sends it in the page's place to a browser taking brotli
    # (Chromium, from 127.0.0.1): its engine "index", moved away, and
    # "Engine is not defined" on every Chromium start (webstart13's proofs).
    build = export(tmp_path, "abc1234")
    (build / "index.html.br").write_bytes(b"br " + PAGE.encode())
    (build / "index.html.gz").write_bytes(b"gz " + PAGE.encode())
    said = run(tmp_path, "abc1234")
    assert said.returncode == 0, said.stderr
    assert not (build / "index.html.br").exists()
    assert not (build / "index.html.gz").exists()
    assert config_of((build / "index.html").read_text())["engine"].startswith("/e/")
    # The packs keep theirs: those are what the deployment sends as brotli.
    assert (build / "index.pck.br").is_file()


def test_the_engine_without_threads_is_placed_beside_and_named_with_only_what_differs(tmp_path):
    build = export(tmp_path / "static", "abc1234")
    other = export_nothreads(tmp_path, build)
    said = run(tmp_path / "static", "abc1234", other)
    assert said.returncode == 0, said.stderr
    digest, nhash = said.stdout.split()
    assert digest != nhash and re.fullmatch(r"[0-9a-f]{16}", nhash)
    home = tmp_path / "static" / "e" / nhash
    assert sorted(p.name for p in home.iterdir()) == sorted(["index.js", "index.js.br", "index.wasm", "index.wasm.br",
                                                             "index.audio.worklet.js", "index.audio.position.worklet.js"])
    assert (home / "index.wasm").read_bytes() == b"\0asm engine, no threads"
    # Copied, not moved: the export keeps its own; its packs are never placed.
    assert (other / "index.wasm").is_file()
    assert not any(p.name.startswith("index.pck") or p.name.startswith("index.data") for p in (tmp_path / "static" / "e").rglob("*"))
    config = config_of((build / "index.html").read_text())
    assert config["engine"] == f"/e/{digest}/index"
    assert config["nothreads"] == {"engine": f"/e/{nhash}/index",
                                   "fileSizes": {"/b/abc1234/index.pck": 1300, f"/e/{nhash}/index.wasm": 4100},
                                   "emscriptenPoolSize": 4, "godotPoolSize": 2, "ensureCrossOriginIsolationHeaders": False}


def test_an_engine_without_threads_whose_packs_or_page_differ_is_refused(tmp_path):
    for spoil in ["pack", "page", "config", "same"]:
        where = tmp_path / spoil
        build = export(where / "static", "abc1234")
        other = export_nothreads(where, build)
        if spoil == "pack":
            (other / "index.data.pck").write_bytes(b"other data")
        elif spoil == "page":
            (other / "index.html").write_text(PAGE_NT.replace("<body>", "<body><p>more</p>"))
        elif spoil == "config":
            (other / "index.html").write_text(PAGE_NT.replace('"mainPack":""', '"mainPack":"other.pck"'))
        else:
            for name in ["index.js", "index.wasm", "index.js.br", "index.wasm.br"]:
                (other / name).write_bytes((build / name).read_bytes())
        said = run(where / "static", "abc1234", other)
        assert said.returncode == 1, (spoil, said.stdout)
        assert {"pack": "byte for byte", "page": "beyond its engine's settings", "config": "mainPack",
                "same": "no engine without threads"}[spoil] in said.stderr, (spoil, said.stderr)
        # Nothing placed: the threaded engine is still in the build, the page as it was.
        assert (build / "index.wasm").is_file() and "/e/" not in (build / "index.html").read_text()


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
    # The engine without threads the same: its brotli and its types.
    assert '\\"dest\\": \\"/e/$engine_nt/\\$1.br\\"' in deploy
    assert '\\"e/$engine_nt/index.wasm.br\\": { \\"contentType\\": \\"application/wasm\\" }' in deploy
    # Sent with nosniff, the script runs only as a script's type, and the
    # wasm streams only as application/wasm.
    assert '\\"e/$engine/index.js.br\\": { \\"contentType\\": \\"application/javascript; charset=utf-8\\" }' in deploy
    assert '\\"e/$engine/index.wasm.br\\": { \\"contentType\\": \\"application/wasm\\" }' in deploy
    assert "b/$sha/index.js.br" not in deploy and "b/$sha/index.wasm.br" not in deploy
    assert 'engines="$(python3 tools/web/place_build.py .vercel/output/static "$sha" ${second[@]+"${second[@]}"})"' in deploy
    assert 'nothreads_dir="${dir%/}-nothreads"' in deploy


def test_the_shell_starts_the_engine_from_its_own_address():
    shell = (ROOT / "src/boot/shell.html").read_text()
    assert "engine.init(GODOT_CONFIG.engine || engine.config.executable)" in shell
    # It chooses the engine before any of it is asked for: no markup names it.
    assert "$GODOT_URL" not in shell and 'href="index.wasm"' not in shell
    assert "brickworksEngine.ready.then(function (chosen) {" in shell
