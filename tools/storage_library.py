#!/usr/bin/env python3
"""Put the model library beside the part geometry, for the app to open from.

tools/library_build.py stages it as the parts store holds it, and this sends
that folder's library/ up to the parts bucket under the same names:

    <PARTS_URL>library/index.json
    <PARTS_URL>library/omr/10179-1.mpd
    <PARTS_URL>library/covers/omr-10179-1.webp

    tools/storage_library.py [DIR]           upload what is not up there yet
    tools/storage_library.py [DIR] --check   say what would be uploaded, and the size
    tools/storage_library.py DIR --pictures  only the website's pictures
                                             (library_build.py pictures), never
                                             the index: library/pages/<id>.webp
                                             and library/cards/<id>.webp

DIR is bench/results/library-2026-10-26 unless said. A model or cover already
there is left as it is, never deleted, as tools/storage_ldraw.py leaves the
LDraw files; the index is sent every time, last, over the one there, so the
live index never names a file that is not up yet. Reads SUPABASE_URL and
SUPABASE_SECRET_KEY as tools/storage_parts.py does.
"""
from __future__ import annotations

import argparse
import concurrent.futures
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from storage_ldraw import listing  # noqa: E402
from storage_parts import BUCKET, ROOT, env  # noqa: E402

DEFAULT = ROOT / "bench" / "results" / "library-2026-10-26"
# A week for the models and covers, which a new build of the library adds
# to and never changes in place; five minutes for the index, which changes.
LASTING = "public, max-age=604800"
INDEX = "public, max-age=300"
WORKERS = 24


def upload(url: str, key: str, name: str, path: Path, cache: str, replace: bool) -> str | None:
    """Send one file. An error to report, or None."""
    request = urllib.request.Request(
        f"{url}/storage/v1/object/{BUCKET}/{name}", data=path.read_bytes(), method="POST",
        headers={"apikey": key, "authorization": f"Bearer {key}",
                 # The bucket takes only this type (415 for any other).
                 "content-type": "application/octet-stream",
                 "cache-control": cache, "x-upsert": "true" if replace else "false"})
    for attempt in range(4):
        try:
            with urllib.request.urlopen(request, timeout=120):
                return None
        except urllib.error.HTTPError as problem:
            text = problem.read().decode("utf-8", "replace")
            if not replace and (problem.code == 409 or "Duplicate" in text
                                or "already exists" in text):
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
    parser.add_argument("dir", nargs="?", type=Path, default=DEFAULT)
    parser.add_argument("--check", action="store_true",
                        help="say what would be uploaded and stop")
    parser.add_argument("--pictures", action="store_true",
                        help="only the website's pictures, library/pages and library/cards; no index")
    args = parser.parse_args()

    shelf = args.dir.resolve() / "library"
    index = shelf / "index.json"
    if not index.is_file() and not args.pictures:
        sys.exit(f"storage: no {index} (tools/library_build.py stage)")
    files = {f"library/{p.relative_to(shelf).as_posix()}": p
             for p in sorted(shelf.rglob("*"))
             if p.is_file() and p.suffix in (".mpd", ".webp")
             and (not args.pictures or p.parent.name in ("pages", "cards"))}
    total = sum(p.stat().st_size for p in files.values()) + (0 if args.pictures else index.stat().st_size)
    models = sum(1 for n in files if n.endswith(".mpd"))
    print(f"storage: {models:,} models, {len(files) - models:,} covers and the index, "
          f"{total / 1e6:.1f} MB")

    url, key = env()
    have = set().union(*(listing(url, key, f"library/{folder}/") for folder in
                         (("pages", "cards") if args.pictures else ("omr", "covers", "pages", "cards"))))
    print(f"  already up: {len(have & set(files)):,}")
    todo = [(n, p) for n, p in files.items() if n not in have]
    todo_bytes = sum(p.stat().st_size for _, p in todo)
    print(f"  to upload : {len(todo):,} and the index  ({todo_bytes / 1e6:.1f} MB)")
    if args.check:
        return 0

    done = 0
    failures: list[str] = []
    lock = threading.Lock()
    started = time.time()

    def send(item: tuple[str, Path]) -> None:
        nonlocal done
        problem = upload(url, key, item[0], item[1], LASTING, False)
        with lock:
            done += 1
            if problem:
                failures.append(problem)
            if done % 500 == 0 or done == len(todo):
                print(f"  {done:>6,}/{len(todo):,}  "
                      f"{done / max(time.time() - started, 0.001):>5.0f}/s", flush=True)

    with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
        list(pool.map(send, todo))
    if failures:
        print(f"  failed {len(failures):,}{'' if args.pictures else ', so the index was not sent'}:")
        for line in failures[:10]:
            print(f"    {line}")
        return 1
    if args.pictures:
        print(f"\n  uploaded {done:,} pictures in {(time.time() - started) / 60:.1f} min")
        return 0
    problem = upload(url, key, "library/index.json", index, INDEX, True)
    if problem:
        print(f"  the index: {problem}")
        return 1
    print(f"\n  uploaded {done:,} and the index in {(time.time() - started) / 60:.1f} min")
    print(f"  public at {url}/storage/v1/object/public/{BUCKET}/library/index.json")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
