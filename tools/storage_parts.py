#!/usr/bin/env python3
"""Put the part geometry somewhere the web build can reach all of it.

The web build ships a working set and fetches the rest on demand. Until
now "the rest" meant files copied into the deployment, and that ran into
a wall: Vercel takes at most 15,000 files in a deployment and the
geometry alone was 13,100 of them. So the on-demand set had to stop at
120 MB, and 15,350 of 28,319 parts were placeable in the browser against
all of them on the desktop — the missing ones being, by construction,
the big interesting pieces, because the budget takes the smallest meshes
first.

Object storage has no such limit. The meshes are named by content hash,
so they are immutable and cacheable forever, and they no longer have to
be re-uploaded on every deploy — which takes the deployment from ~14,000
files to a few dozen.

    tools/storage_parts.py              upload whatever is missing
    tools/storage_parts.py --check      say what would be uploaded
    tools/storage_parts.py --all        re-upload everything

Reads SUPABASE_URL and SUPABASE_SECRET_KEY from .env beside the project.
The bucket is public: this is geometry derived from a CC BY licensed
library, and putting a signature on every request would cost a round
trip per part to protect nothing.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import os
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUCKET = "parts"
# A year. The names are content hashes, so a given name's bytes can
# never change and the only reason to come back is a new part.
CACHE_CONTROL = "public, max-age=31536000, immutable"
WORKERS = 24


def env() -> tuple[str, str]:
    values: dict[str, str] = {}
    source = ROOT / ".env"
    if source.exists():
        for line in source.read_text().splitlines():
            if "=" in line and not line.startswith("#"):
                key, _, value = line.partition("=")
                values[key.strip()] = value.strip().strip("\"'")
    url = os.environ.get("SUPABASE_URL") or values.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SECRET_KEY") or values.get("SUPABASE_SECRET_KEY", "")
    if not url or not key:
        sys.exit("storage: no SUPABASE_URL / SUPABASE_SECRET_KEY (.env or environment)")
    return url.rstrip("/"), key


def listing(url: str, key: str) -> set[str]:
    """What is already up there.

    Paged, because the bucket holds tens of thousands of objects and the
    endpoint caps a page well below that — a single unpaged call comes
    back looking like an almost-empty bucket, and every run would then
    re-upload the lot.
    """
    import json

    have: set[str] = set()
    offset = 0
    page = 1000
    while True:
        body = json.dumps({"prefix": "", "limit": page, "offset": offset}).encode()
        request = urllib.request.Request(
            f"{url}/storage/v1/object/list/{BUCKET}",
            data=body,
            method="POST",
            headers={
                "apikey": key,
                "authorization": f"Bearer {key}",
                "content-type": "application/json",
            },
        )
        with urllib.request.urlopen(request, timeout=60) as reply:
            rows = json.load(reply)
        if not rows:
            break
        have.update(row["name"] for row in rows)
        if len(rows) < page:
            break
        offset += page
    return have


def upload(url: str, key: str, path: Path) -> str | None:
    """Send one mesh. Returns an error to report, or None."""
    data = path.read_bytes()
    request = urllib.request.Request(
        f"{url}/storage/v1/object/{BUCKET}/{path.name}",
        data=data,
        method="POST",
        headers={
            "apikey": key,
            "authorization": f"Bearer {key}",
            "content-type": "application/octet-stream",
            "cache-control": CACHE_CONTROL,
            # Overwrite rather than fail when a previous run died partway
            # through a file.
            "x-upsert": "true",
        },
    )
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=120):
                return None
        except urllib.error.HTTPError as problem:
            if problem.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(2 ** attempt)
                continue
            return f"{path.name}: HTTP {problem.code}"
        except Exception as problem:  # noqa: BLE001 - network, anything goes
            if attempt < 3:
                time.sleep(2 ** attempt)
                continue
            return f"{path.name}: {problem}"
    return f"{path.name}: gave up"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true",
                        help="say what would be uploaded and stop")
    parser.add_argument("--all", action="store_true",
                        help="re-upload even what is already there")
    args = parser.parse_args()

    url, key = env()
    source = ROOT / "assets" / "generated" / "parts"
    meshes = sorted(source.glob("*.lbm"))
    if not meshes:
        sys.exit(f"storage: no geometry in {source} (tools/build_meshes.py)")

    total_bytes = sum(mesh.stat().st_size for mesh in meshes)
    print(f"storage: {len(meshes):,} meshes, {total_bytes / 1e6:.0f} MB on disk")

    have: set[str] = set() if args.all else listing(url, key)
    if have:
        print(f"  already up: {len(have):,}")
    todo = [mesh for mesh in meshes if mesh.name not in have]
    todo_bytes = sum(mesh.stat().st_size for mesh in todo)
    print(f"  to upload : {len(todo):,}  ({todo_bytes / 1e6:.0f} MB)")
    if args.check or not todo:
        return 0

    done = 0
    failures: list[str] = []
    lock = threading.Lock()
    started = time.time()

    def send(mesh: Path) -> None:
        nonlocal done
        problem = upload(url, key, mesh)
        with lock:
            done += 1
            if problem:
                failures.append(problem)
            if done % 500 == 0 or done == len(todo):
                rate = done / max(time.time() - started, 0.001)
                left = (len(todo) - done) / max(rate, 0.001)
                print(f"  {done:>6,}/{len(todo):,}  {rate:>5.0f}/s  "
                      f"{left / 60:>4.1f} min left", flush=True)

    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        list(pool.map(send, todo))

    print(f"\n  uploaded {done - len(failures):,} in "
          f"{(time.time() - started) / 60:.1f} min")
    if failures:
        print(f"  failed {len(failures):,}:")
        for line in failures[:10]:
            print(f"    {line}")
        return 1
    print(f"  public at {url}/storage/v1/object/public/{BUCKET}/<hash>.lbm")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
