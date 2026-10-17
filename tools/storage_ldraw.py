#!/usr/bin/env python3
"""Put the LDraw library's parts/ beside the geometry, for the web to fetch.

A model file can carry parts of its own (CustomParts.take_from), and the app
builds each from its LDraw text (PartForge). Most draw on the library's own
subparts, and some on its parts: 42082-1's three wheel rims (13971) are drawn
from s\\13971s01.dat. A desktop reads those from vendor/ldraw. No build ships
them: parts/ is 34,000 files and about 500 MB, where every export carries the
primitives (p/, 1.4 MB compressed) and nothing more. So the web fetches the
few a file names (CustomParts.fetch_sources) from the parts bucket, under
ldraw/parts/ as LDraw lays it out:

    <PARTS_URL>ldraw/parts/s/13971s01.dat

    tools/storage_ldraw.py              upload what is not up there yet
    tools/storage_ldraw.py --check      say what would be uploaded, and the size

Additive only: a file already there is left as it is (no upsert), and nothing
is ever deleted, so the live site keeps working through a run. Reads
SUPABASE_URL and SUPABASE_SECRET_KEY as tools/storage_parts.py does.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import json
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from storage_parts import BUCKET, ROOT, env  # noqa: E402

PREFIX = "ldraw/parts/"
# A week: the library changes a few times a year, and a file is only ever
# added here, never replaced.
CACHE_CONTROL = "public, max-age=604800"
WORKERS = 24


def listing(url: str, key: str, folder: str) -> set[str]:
    """The names already up in [folder] (one level), paged as storage_parts does."""
    have: set[str] = set()
    offset = 0
    page = 1000
    while True:
        body = json.dumps({"prefix": folder.rstrip("/"), "limit": page,
                           "offset": offset}).encode()
        request = urllib.request.Request(
            f"{url}/storage/v1/object/list/{BUCKET}", data=body, method="POST",
            headers={"apikey": key, "authorization": f"Bearer {key}",
                     "content-type": "application/json"})
        with urllib.request.urlopen(request, timeout=60) as reply:
            rows = json.load(reply)
        if not rows:
            break
        # A folder comes back as a row with no id.
        have.update(folder + row["name"] for row in rows if row.get("id"))
        if len(rows) < page:
            break
        offset += page
    return have


def upload(url: str, key: str, name: str, path: Path) -> str | None:
    """Send one file, never over one there. An error to report, or None."""
    request = urllib.request.Request(
        f"{url}/storage/v1/object/{BUCKET}/{name}", data=path.read_bytes(), method="POST",
        headers={"apikey": key, "authorization": f"Bearer {key}",
                 # The bucket takes the meshes' type and no text type (415).
                 "content-type": "application/octet-stream",
                 "cache-control": CACHE_CONTROL, "x-upsert": "false"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=120):
                return None
        except urllib.error.HTTPError as problem:
            text = problem.read().decode("utf-8", "replace")
            # Already there (a run that died after sending it): left alone.
            if problem.code == 409 or "Duplicate" in text or "already exists" in text:
                return None
            if problem.code in (429, 500, 502, 503, 504) and attempt < 3:
                time.sleep(2 ** attempt)
                continue
            return f"{name}: HTTP {problem.code} {text[:120]}"
        except Exception as problem:  # noqa: BLE001 - network, anything goes
            if attempt < 3:
                time.sleep(2 ** attempt)
                continue
            return f"{name}: {problem}"
    return f"{name}: gave up"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true",
                        help="say what would be uploaded and stop")
    args = parser.parse_args()

    source = ROOT / "vendor" / "ldraw" / "parts"
    files = sorted(p for p in source.rglob("*.dat") if p.is_file())
    if not files:
        sys.exit(f"storage: no LDraw parts in {source} (tools/fetch_data.sh)")
    # Lower case, "/" between folders: the name PartForge.normalise gives a
    # reference, which is what the web asks for.
    named = {PREFIX + p.relative_to(source).as_posix().lower(): p for p in files}
    total = sum(p.stat().st_size for p in files)
    sub = sum(1 for n in named if n.startswith(PREFIX + "s/"))
    print(f"storage: {len(named):,} LDraw files ({len(named) - sub:,} parts, "
          f"{sub:,} subparts), {total / 1e6:.0f} MB")

    url, key = env()
    have = listing(url, key, PREFIX) | listing(url, key, PREFIX + "s/")
    print(f"  already up: {len(have & set(named)):,}")
    todo = [(n, p) for n, p in named.items() if n not in have]
    todo_bytes = sum(p.stat().st_size for _, p in todo)
    print(f"  to upload : {len(todo):,}  ({todo_bytes / 1e6:.0f} MB)")
    if args.check or not todo:
        return 0

    done = 0
    failures: list[str] = []
    lock = threading.Lock()
    started = time.time()

    def send(item: tuple[str, Path]) -> None:
        nonlocal done
        problem = upload(url, key, *item)
        with lock:
            done += 1
            if problem:
                failures.append(problem)
            if done % 1000 == 0 or done == len(todo):
                rate = done / max(time.time() - started, 0.001)
                left = (len(todo) - done) / max(rate, 0.001)
                print(f"  {done:>6,}/{len(todo):,}  {rate:>5.0f}/s  "
                      f"{left / 60:>4.1f} min left", flush=True)

    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        list(pool.map(send, todo))

    print(f"\n  uploaded {done - len(failures):,} in {(time.time() - started) / 60:.1f} min")
    if failures:
        print(f"  failed {len(failures):,}:")
        for line in failures[:10]:
            print(f"    {line}")
        return 1
    print(f"  public at {url}/storage/v1/object/public/{BUCKET}/{PREFIX}<name>")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
