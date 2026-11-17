#!/usr/bin/env python3
"""Where a web build's files go in the deployment, and its page pointed at them.

    python3 tools/web/place_build.py STATIC SHA

STATIC/b/SHA/ holds the build as tools/deploy.sh copied it there (tools/
export.sh web). The engine's own files (its script, its wasm and its audio
worklets, with their .br) move to STATIC/e/HASH/, HASH being of their bytes;
the rest stays under /b/SHA/. The page's file names are made absolute to
where each file now is, and its GODOT_CONFIG names the engine's place as
"engine" (src/boot/shell.html starts the engine from there). Prints HASH.

Why: every release is a new /b/<sha>/, so a person who came back after a
release fetched the whole engine again, and releases go out about daily.
The engine's wasm is 6.89 of the 9.29 MB its start waits for, 2.8 of
broadband's 7.7 s to its banner, and the same bytes in every release of one
Godot (live m304's and pre261's were byte for byte the same; webstart10,
2026-11-16). At an address of its own bytes the browser keeps it across
releases, as /parts/ is kept: a return after a release waits only for the
packs, which are the release's own.

Everything under /e/ and /b/ is cached for good (deploy.sh's routes), so an
address must never name other bytes: a new engine is a new HASH. A tab open
from before a release asks for its own engine's address, which the new
deployment serves only if the engine is the same, as an old /b/<sha>/ is not
served at all.

The page is served at /app as well as /b/SHA/, and its security policy says
base-uri 'none', so no <base> can point it at its files: each name is made
absolute instead. Exits non-zero, saying why, rather than leave a page that
would load nothing.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
from pathlib import Path

# The engine's own files, as Godot's web export names them after its
# executable ("index"). Its script and wasm must be there; the worklets
# come with a threaded build's audio.
ENGINE = ["index.js", "index.wasm", "index.audio.worklet.js", "index.audio.position.worklet.js"]
NEEDED = ["index.js", "index.wasm"]


def engine_hash(build: Path) -> str:
    """The engine's address: of the bytes of each of its files there, by name."""
    digest = hashlib.sha256()
    for name in ENGINE:
        path = build / name
        if path.is_file():
            digest.update(name.encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()[:16]


def point_page(page: str, here: Path, base: str, engine: str, moved: set[str]) -> str:
    """The page with each of its own files named where it is: the engine's
    under ENGINE, the rest under BASE; GODOT_CONFIG's too."""
    def absolute(m: re.Match) -> str:
        name = m.group(2)
        if "/" in name or ":" in name:
            return m.group(0)
        if name in moved:
            return f'{m.group(1)}="{engine}{name}"'
        if not (here / name).is_file():
            return m.group(0)
        return f'{m.group(1)}="{base}{name}"'
    page = re.sub(r'\b(src|href)="([^"]*)"', absolute, page)

    found = re.search(r"const GODOT_CONFIG = ", page)
    if not found:
        raise ValueError("no GODOT_CONFIG in the exported page")
    config, end = json.JSONDecoder().raw_decode(page, found.end())
    exe = config["executable"]
    # The build's own folder is still the executable's: the packs, the
    # knowledge and version.json are read beside it (src/net/origin.gd,
    # shell.html's packs and its look for a newer build).
    config["executable"] = base + exe
    config["engine"] = engine + exe
    # The engine looks a file's size up by the very path it fetches.
    config["fileSizes"] = {(engine if k in moved else base) + k: v
                           for k, v in config.get("fileSizes", {}).items()}
    page = page[:found.end()] + json.dumps(config, separators=(",", ":")) + page[end:]
    if f'src="{engine}{exe}.js"' not in page:
        raise ValueError(f"the engine's script ({exe}.js) is not named from {engine}")
    return page


def place(static: Path, sha: str) -> str:
    build = static / "b" / sha
    page_path = build / "index.html"
    if not page_path.is_file():
        raise ValueError(f"no page at {page_path}")
    missing = [name for name in NEEDED if not (build / name).is_file()]
    if missing:
        raise ValueError(f"no {', '.join(missing)} in {build}")
    digest = engine_hash(build)
    home = static / "e" / digest
    home.mkdir(parents=True, exist_ok=True)
    moved = set()
    for name in ENGINE:
        for each in (name, name + ".br"):
            if (build / each).is_file():
                os.replace(build / each, home / each)
                moved.add(each)
    page = point_page(page_path.read_text(encoding="utf-8"), build, f"/b/{sha}/", f"/e/{digest}/", moved)
    page_path.write_text(page, encoding="utf-8")
    return digest


def main() -> int:
    if len(sys.argv) != 3 or not re.fullmatch(r"[0-9a-f]{7,40}(-dirty)?", sys.argv[2]):
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    try:
        print(place(Path(sys.argv[1]), sys.argv[2]))
    except (OSError, ValueError, KeyError) as trouble:
        print(f"place_build: {trouble}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
