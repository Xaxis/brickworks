#!/usr/bin/env python3
"""Where a web build's files go in the deployment, and its page pointed at them.

    python3 tools/web/place_build.py STATIC SHA [NOTHREADS]

STATIC/b/SHA/ holds the build as tools/deploy.sh copied it there (tools/
export.sh web). The engine's own files (its script, its wasm and its audio
worklets, with their .br) move to STATIC/e/HASH/, HASH being of their bytes;
the rest stays under /b/SHA/. The page's file names are made absolute to
where each file now is, and its GODOT_CONFIG names the engine's place as
"engine" (src/boot/shell.html starts the engine from there). Prints HASH.

With NOTHREADS, the same project's export without threads (export.sh web
puts it in build/web-nothreads): its engine is copied to STATIC/e/NHASH/
and the page's GODOT_CONFIG says, as "nothreads", where it is and what its
own export's page says otherwise (the wasm's size, Godot's pool sizes),
for the page to start it on an iPhone or iPad when the owner's switch is
on (nothreads, 2026-11-19; docs/PHONE.md). Nothing else of it goes: its
packs must be this build's byte for byte, and its page this page with only
those settings changed, or nothing is placed. Prints HASH NHASH.

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

import filecmp
import hashlib
import json
import os
import re
import shutil
import sys
from pathlib import Path

# The engine's own files, as Godot's web export names them after its
# executable ("index"). Its script and wasm must be there; the worklets
# come with a threaded build's audio.
ENGINE = ["index.js", "index.wasm", "index.audio.worklet.js", "index.audio.position.worklet.js"]
NEEDED = ["index.js", "index.wasm"]
# What both engines read, which a second engine must find the same: the
# packs (tools/web/pck_split.py) and the parts after the start.
PACKS = ["index.pck", "index.data.pck", "index.parts.bin", "index.primitives.bin", "index.hdri.bin", "index.fonts.bin"]
# What the export without threads may set otherwise in its page's
# GODOT_CONFIG, besides the wasm's size: Godot's own settings for threads.
THREAD_KEYS = ["emscriptenPoolSize", "godotPoolSize", "ensureCrossOriginIsolationHeaders"]


def engine_hash(build: Path) -> str:
    """The engine's address: of the bytes of each of its files there, by name."""
    digest = hashlib.sha256()
    for name in ENGINE:
        path = build / name
        if path.is_file():
            digest.update(name.encode() + b"\0" + path.read_bytes() + b"\0")
    return digest.hexdigest()[:16]


def config_of(page: str) -> tuple[dict, int, int]:
    """The page's GODOT_CONFIG, and where its value starts and ends."""
    found = re.search(r"const GODOT_CONFIG = ", page)
    if not found:
        raise ValueError("no GODOT_CONFIG in the exported page")
    config, end = json.JSONDecoder().raw_decode(page, found.end())
    return config, found.end(), end


def bare(page: str) -> str:
    """The page without its GODOT_CONFIG's value or its threads flag: what
    two exports of one project share whatever their engines."""
    _, start, end = config_of(page)
    page = page[:start] + "{}" + page[end:]
    return re.sub(r"const GODOT_THREADS_ENABLED = (true|false);", "const GODOT_THREADS_ENABLED = ?;", page)


def sizes_at(sizes: dict, base: str, engine: str, moved: set[str]) -> dict:
    """GODOT_CONFIG's fileSizes keyed by the path each file is fetched by."""
    return {(engine if k in moved else base) + k: v for k, v in sizes.items()}


def second_engine(static: Path, build: Path, page: str, digest: str, other: Path) -> dict:
    """The engine of OTHER, the export without threads, copied to
    STATIC/e/NHASH/: what the page's GODOT_CONFIG says of it as "nothreads"
    (its place, as "engine", and what its own page sets otherwise). Refused,
    saying why, when anything but the engine differs from BUILD's."""
    other_path = other / "index.html"
    if not other_path.is_file():
        raise ValueError(f"no page at {other_path}")
    missing = [name for name in NEEDED + [name + ".br" for name in NEEDED] if not (other / name).is_file()]
    if missing:
        raise ValueError(f"no {', '.join(missing)} in {other}")
    for name in PACKS:
        if (build / name).is_file() and not (other / name).is_file():
            raise ValueError(f"no {name} in {other}, which {build} has")
        if (build / name).is_file() and not filecmp.cmp(build / name, other / name, shallow=False):
            raise ValueError(f"{other / name} is not {build / name} byte for byte: the two exports' packs differ")
    other_page = other_path.read_text(encoding="utf-8")
    if bare(other_page) != bare(page):
        raise ValueError(f"{other_path} differs from {build / 'index.html'} beyond its engine's settings")
    mine, _, _ = config_of(page)
    theirs, _, _ = config_of(other_page)
    differ = sorted(k for k in set(mine) | set(theirs) if mine.get(k) != theirs.get(k))
    unknown = [k for k in differ if k not in THREAD_KEYS and k != "fileSizes"]
    if unknown:
        raise ValueError(f"the export without threads sets {', '.join(unknown)} otherwise")
    sized = {k for k in set(mine.get("fileSizes", {})) | set(theirs.get("fileSizes", {}))
             if mine.get("fileSizes", {}).get(k) != theirs.get("fileSizes", {}).get(k)}
    if sized - set(ENGINE):
        raise ValueError(f"the export without threads has other sizes for {', '.join(sorted(sized - set(ENGINE)))}")
    nhash = engine_hash(other)
    if nhash == digest:
        raise ValueError(f"{other}'s engine is {build}'s: no engine without threads")
    home = static / "e" / nhash
    home.mkdir(parents=True, exist_ok=True)
    moved = set()
    for name in ENGINE + [name + ".br" for name in NEEDED]:
        if (other / name).is_file():
            shutil.copyfile(other / name, home / name)
            moved.add(name)
    exe = theirs["executable"]
    said = {"engine": f"/e/{nhash}/{exe}",
            "fileSizes": sizes_at(theirs.get("fileSizes", {}), f"/b/{build.name}/", f"/e/{nhash}/", moved)}
    for key in THREAD_KEYS:
        if key in differ:
            said[key] = theirs[key]
    return said


def point_page(page: str, here: Path, base: str, engine: str, moved: set[str], nothreads: dict | None = None) -> str:
    """The page with each of its own files named where it is: the engine's
    under ENGINE, the rest under BASE; GODOT_CONFIG's too, with NOTHREADS
    as its "nothreads" where there is a second engine."""
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

    config, start, end = config_of(page)
    exe = config["executable"]
    # The build's own folder is still the executable's: the packs, the
    # knowledge and version.json are read beside it (src/net/origin.gd,
    # shell.html's packs and its look for a newer build).
    config["executable"] = base + exe
    # The page asks for the engine's script and wasm from here (shell.html's
    # brickworksEngine): no markup names them, as the page chooses its engine.
    config["engine"] = engine + exe
    # The engine looks a file's size up by the very path it fetches.
    config["fileSizes"] = sizes_at(config.get("fileSizes", {}), base, engine, moved)
    if nothreads:
        config["nothreads"] = nothreads
    return page[:start] + json.dumps(config, separators=(",", ":")) + page[end:]


def place(static: Path, sha: str, other: Path | None = None) -> str:
    build = static / "b" / sha
    page_path = build / "index.html"
    if not page_path.is_file():
        raise ValueError(f"no page at {page_path}")
    missing = [name for name in NEEDED if not (build / name).is_file()]
    if missing:
        raise ValueError(f"no {', '.join(missing)} in {build}")
    digest = engine_hash(build)
    page = page_path.read_text(encoding="utf-8")
    config_of(page)
    nothreads = second_engine(static, build, page, digest, other) if other else None
    home = static / "e" / digest
    home.mkdir(parents=True, exist_ok=True)
    moved = set()
    for name in ENGINE:
        for each in (name, name + ".br"):
            if (build / each).is_file():
                os.replace(build / each, home / each)
                moved.add(each)
    page = point_page(page, build, f"/b/{sha}/", f"/e/{digest}/", moved, nothreads)
    page_path.write_text(page, encoding="utf-8")
    return digest + (" " + nothreads["engine"].split("/")[2] if nothreads else "")


def main() -> int:
    if len(sys.argv) not in (3, 4) or not re.fullmatch(r"[0-9a-f]{7,40}(-dirty)?", sys.argv[2]):
        print(__doc__.split("\n\n")[1], file=sys.stderr)
        return 2
    try:
        print(place(Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3]) if len(sys.argv) == 4 else None))
    except (OSError, ValueError, KeyError) as trouble:
        print(f"place_build: {trouble}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
