#!/usr/bin/env python3
"""Every set's own picture, for the library on the site (setpics).

The site's library shows each set by our own render where LDraw has a 3D
model of it, and otherwise drew it from a few of its parts: 27,000 of the
28,441 sets were a collage of parts (the owner, 2026-10-30). Rebrickable has
a picture of nearly every set (img_url in their sets table) and lets other
sites show them with credit. A visitor's browser never asks them for one:
this fetches each picture once, here, makes the sizes the site shows, and
puts those in our storage, which brickworks.diy serves them from
(api/share.js catalog_photo).

    vendor/rebrickable/set_pictures/<set>.jpg        as Rebrickable has it
    vendor/rebrickable/set_pictures/tried.json       sets they have none of, and when asked
    vendor/rebrickable/set_pictures/webp/card/<set>.webp
                                                     a card's: 640 x 480, the set whole on white
    vendor/rebrickable/set_pictures/webp/page/<set>.webp
                                                     its page's: its own shape, at most 1200 x 900
    <PARTS_URL>sets/card/<set>.webp, sets/page/<set>.webp
                                                     in the parts bucket, as the LDraw library's
                                                     pictures are (library/cards/)
    assets/generated/set_pictures.json               the sets whose two are up: what
                                                     tools/set_catalog.py marks

Fetching asks Rebrickable's CDN at most four times a second, one picture a
set, ever: a picture here is never asked for again, and a set they have
none of is asked again after a week (a new set's picture comes after it).
A run stopped anywhere starts where it stopped. Nothing up in storage is
replaced or deleted.

    tools/set_pictures.py            all of it, for the sets not done yet: what
                                     tools/fetch_data.sh runs after the day's tables
    tools/set_pictures.py --fetch    only fetch the pictures
    tools/set_pictures.py --make     only make the WebPs (CPU: run it through heavy)
    tools/set_pictures.py --upload   only upload them and write the list
    tools/set_pictures.py --check    say what each step would do, and do nothing
"""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
import datetime
import gzip
import io
import json
import os
import re
import sys
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

VENDOR = ROOT / "vendor" / "rebrickable"
SETS = VENDOR / "sets.csv.gz"
HERE = VENDOR / "set_pictures"
TRIED = HERE / "tried.json"
WEBP = HERE / "webp"
LIST = ROOT / "assets" / "generated" / "set_pictures.json"
STORED = "sets"

# Their CDN, asked no faster than this, by this many at once.
PER_SECOND = 4
FETCHERS = 4
# Only their CDN's set pictures are fetched: an address in the table that
# points anywhere else is left alone.
CDN = "https://cdn.rebrickable.com/media/sets/"
AGENT = "Brickworks set pictures (https://brickworks.diy; once a set)"
# A set they have no picture of is asked again after this many days.
AGAIN_DAYS = 7
MOST_BYTES = 20 * 1024 * 1024

# The sizes the site shows: a card's frame is 4:3 (web/site.css .model
# .frame) and its picture covers it, so the card's is that shape with the
# set whole inside it; a page shows the picture whole (directory.css
# .picture.photo), so the page's keeps the set's own shape.
CARD = (640, 480)
PAGE_MOST = (1200, 900)
# Room round the set, a share of the shorter side.
MARGIN = 0.05
# A border nearer white than this is the photo's ground, trimmed before the
# set is placed, so each sits the same in its frame.
NEAR_WHITE = 24
QUALITY = 80

UPLOADERS = 16
LASTING = "public, max-age=604800"

# A set's number as the site takes one (api/_sets.js SET_NUMBER).
SET_NUMBER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9.-]{0,29}$")


def today() -> str:
    return datetime.date.today().isoformat()


def wanted() -> dict[str, str]:
    """Every set Rebrickable lists with its picture's address: {set: url}."""
    if not SETS.exists():
        sys.exit(f"set_pictures: no {SETS} (tools/fetch_data.sh)")
    with gzip.open(SETS, "rb") as raw:
        rows = csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8", newline=""))
        return {row["set_num"]: row["img_url"] for row in rows
                if SET_NUMBER.match(row["set_num"]) and row.get("img_url", "").startswith(CDN)}


def read_json(path: Path, empty):
    try:
        return json.loads(path.read_text())
    except (OSError, ValueError):
        return empty


def write_json(path: Path, value) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    part = path.with_suffix(path.suffix + ".part")
    part.write_text(json.dumps(value, separators=(",", ":"), sort_keys=True))
    os.replace(part, path)


def original(number: str) -> Path:
    return HERE / f"{number}.jpg"


def is_picture(head: bytes) -> bool:
    """JPEG, PNG, GIF or WebP, by its first bytes."""
    return (head[:3] == b"\xff\xd8\xff" or head[:8] == b"\x89PNG\r\n\x1a\n" or head[:4] == b"GIF8"
            or (head[:4] == b"RIFF" and head[8:12] == b"WEBP"))


# ---------------------------------------------------------------------------
# Fetching


class Pace:
    """One start every 1/PER_SECOND seconds, whoever asks."""

    def __init__(self, per_second: float) -> None:
        self.gap = 1.0 / per_second
        self.next = time.monotonic()
        self.lock = threading.Lock()

    def wait(self) -> None:
        with self.lock:
            now = time.monotonic()
            at = max(now, self.next)
            self.next = at + self.gap
        if at > now:
            time.sleep(at - now)

    def hold(self, seconds: float) -> None:
        """Nobody starts for [seconds]: they asked us to slow down."""
        with self.lock:
            self.next = max(self.next, time.monotonic() + seconds)


def fetch_one(number: str, url: str, pace: Pace) -> str:
    """'got', 'none' (they have no picture of it) or 'failed: ...'."""
    for attempt in range(4):
        pace.wait()
        request = urllib.request.Request(url, headers={"user-agent": AGENT})
        try:
            with urllib.request.urlopen(request, timeout=60) as reply:
                body = reply.read(MOST_BYTES + 1)
                length = reply.headers.get("content-length", "")
        except urllib.error.HTTPError as problem:
            if problem.code in (403, 404, 410):
                return "none"
            if problem.code == 429 or problem.code >= 500:
                pace.hold(30 * (attempt + 1) if problem.code == 429 else 2 ** attempt)
                continue
            return f"failed: HTTP {problem.code}"
        except Exception as problem:  # noqa: BLE001 - network, anything goes
            pace.hold(2 ** attempt)
            if attempt == 3:
                return f"failed: {problem}"
            continue
        # A connection that ends early still reads as a whole answer: one
        # in 3,000 came short (10328-1, 3.5 of 4.1 MB) and would not decode.
        if length.isdigit() and int(length) != len(body):
            pace.hold(2 ** attempt)
            continue
        if len(body) > MOST_BYTES or not is_picture(body[:16]):
            return "none"
        path = original(number)
        part = path.with_name(path.name + ".part")
        part.write_bytes(body)
        os.replace(part, path)
        return "got"
    return "failed: gave up"


def fetch(sets: dict[str, str], check: bool) -> int:
    HERE.mkdir(parents=True, exist_ok=True)
    tried = read_json(TRIED, {})
    soon = (datetime.date.today() - datetime.timedelta(days=AGAIN_DAYS)).isoformat()
    todo = [(number, url) for number, url in sorted(sets.items())
            if not original(number).exists() and tried.get(number, "") <= soon]
    have = sum(1 for number in sets if original(number).exists())
    print(f"fetch: {have:,} of {len(sets):,} sets' pictures here, {len(tried):,} they have none of; "
          f"{len(todo):,} to ask for, at most {PER_SECOND} a second (~{len(todo) / PER_SECOND / 60:.0f} min)")
    if check or not todo:
        return 0
    pace = Pace(PER_SECOND)
    lock = threading.Lock()
    counts = {"got": 0, "none": 0, "failed": 0}
    failures: list[str] = []
    started = time.time()
    done = 0

    def one(item: tuple[str, str]) -> None:
        nonlocal done
        number, url = item
        said = fetch_one(number, url, pace)
        with lock:
            done += 1
            if said == "none":
                tried[number] = today()
                counts["none"] += 1
            elif said == "got":
                tried.pop(number, None)
                counts["got"] += 1
            else:
                counts["failed"] += 1
                failures.append(f"{number}: {said}")
            if done % 250 == 0 or done == len(todo):
                write_json(TRIED, tried)
                spent = time.time() - started
                print(f"  {done:>6,}/{len(todo):,}  got {counts['got']:,}, none {counts['none']:,}, "
                      f"failed {counts['failed']:,}  {done / max(spent, 0.001):.2f}/s  "
                      f"{spent / 60:.1f} min", flush=True)

    with concurrent.futures.ThreadPoolExecutor(FETCHERS) as pool:
        list(pool.map(one, todo))
    write_json(TRIED, tried)
    print(f"fetch: got {counts['got']:,}, none {counts['none']:,}, failed {counts['failed']:,} "
          f"in {(time.time() - started) / 60:.1f} min")
    for line in failures[:10]:
        print(f"  {line}")
    return 1 if counts["failed"] else 0


# ---------------------------------------------------------------------------
# Making the sizes


def made(number: str, size: str) -> Path:
    return WEBP / size / f"{number}.webp"


def make_one(number: str) -> str | None:
    """Its card's and its page's WebP from its picture. An error, or None."""
    from PIL import Image, ImageChops

    try:
        with Image.open(original(number)) as opened:
            opened.load()
            picture = opened
            if picture.mode in ("RGBA", "LA", "P"):
                rgba = picture.convert("RGBA")
                picture = Image.new("RGB", rgba.size, (255, 255, 255))
                picture.paste(rgba, mask=rgba.getchannel("A"))
            else:
                picture = picture.convert("RGB")
    except Exception as problem:  # noqa: BLE001 - a broken file is said, not raised
        return f"{number}: {problem}"
    # The photo's white ground trimmed, so every set sits the same.
    ground = Image.new("RGB", picture.size, (255, 255, 255))
    differs = ImageChops.difference(picture, ground).convert("L").point(lambda v: 255 if v > NEAR_WHITE else 0)
    box = differs.getbbox()
    if box:
        picture = picture.crop(box)
    w, h = picture.size
    if w < 2 or h < 2:
        return f"{number}: nothing in its picture"

    def placed(frame_w: int, frame_h: int) -> Image.Image:
        room = MARGIN * min(frame_w, frame_h)
        scale = min((frame_w - 2 * room) / w, (frame_h - 2 * room) / h)
        size = (max(1, round(w * scale)), max(1, round(h * scale)))
        canvas = Image.new("RGB", (frame_w, frame_h), (255, 255, 255))
        canvas.paste(picture.resize(size, Image.LANCZOS),
                     ((frame_w - size[0]) // 2, (frame_h - size[1]) // 2))
        return canvas

    card = placed(*CARD)
    # The page's: its own shape with the same margin, no bigger than PAGE_MOST
    # and never enlarged past the photo.
    pad = round(MARGIN * min(w, h))
    whole_w, whole_h = w + 2 * pad, h + 2 * pad
    scale = min(1.0, PAGE_MOST[0] / whole_w, PAGE_MOST[1] / whole_h)
    page = placed(max(1, round(whole_w * scale)), max(1, round(whole_h * scale)))
    for size, image in (("card", card), ("page", page)):
        path = made(number, size)
        path.parent.mkdir(parents=True, exist_ok=True)
        part = path.with_name(path.name + ".part")
        image.save(part, "WEBP", quality=QUALITY, method=4)
        os.replace(part, path)
    return None


def make(sets: dict[str, str], check: bool, workers: int) -> int:
    todo = [number for number in sorted(sets) if original(number).exists()
            and not (made(number, "card").exists() and made(number, "page").exists()
                     and made(number, "page").stat().st_mtime >= original(number).stat().st_mtime)]
    print(f"make: {len(todo):,} sets' card and page to make")
    if check or not todo:
        return 0
    started = time.time()
    failures: list[str] = []
    done = 0
    with concurrent.futures.ProcessPoolExecutor(workers) as pool:
        for number, problem in zip(todo, pool.map(make_one, todo, chunksize=16)):
            done += 1
            if problem:
                # One that will not decode goes, so the next fetch asks for it again.
                failures.append(problem)
                original(number).unlink(missing_ok=True)
            if done % 1000 == 0 or done == len(todo):
                print(f"  {done:>6,}/{len(todo):,}  {(time.time() - started) / 60:.1f} min", flush=True)
    print(f"make: {done - len(failures):,} made, {len(failures):,} failed in {(time.time() - started) / 60:.1f} min"
          f"{', the pictures that failed taken away to be fetched again' if failures else ''}")
    for line in failures[:10]:
        print(f"  {line}")
    return 1 if failures else 0


# ---------------------------------------------------------------------------
# Uploading, and the list tools/set_catalog.py reads


def upload(sets: dict[str, str], check: bool) -> int:
    from storage_ldraw import listing
    from storage_library import upload as send

    ready = [number for number in sorted(sets) if made(number, "card").exists() and made(number, "page").exists()]
    try:
        url, key = storage_env()
    except LookupError as missing:
        print(f"upload: {missing}; {len(ready):,} sets' pictures made here and not uploaded")
        return 0 if check else 1
    up = set().union(*(listing(url, key, f"{STORED}/{size}/") for size in ("card", "page")))
    todo = [(f"{STORED}/{size}/{number}.webp", made(number, size)) for number in ready
            for size in ("card", "page") if f"{STORED}/{size}/{number}.webp" not in up]
    print(f"upload: {len(ready):,} sets' pictures made, {len(up):,} files up already, {len(todo):,} to upload "
          f"({sum(path.stat().st_size for _, path in todo) / 1e6:.1f} MB)")
    if check:
        return 0
    started = time.time()
    failures: list[str] = []
    lock = threading.Lock()
    done = 0

    def one(item: tuple[str, Path]) -> None:
        nonlocal done
        problem = send(url, key, item[0], item[1], LASTING, False)
        with lock:
            done += 1
            if problem:
                failures.append(problem)
            else:
                up.add(item[0])
            if done % 1000 == 0 or done == len(todo):
                print(f"  {done:>6,}/{len(todo):,}  {done / max(time.time() - started, 0.001):.0f}/s", flush=True)

    with concurrent.futures.ThreadPoolExecutor(UPLOADERS) as pool:
        list(pool.map(one, todo))
    # Only a set both of whose pictures are up is listed: a page never names
    # one that is not there.
    listed = [number for number in ready if all(f"{STORED}/{size}/{number}.webp" in up for size in ("card", "page"))]
    write_json(LIST, {"made": today(), "sets": listed})
    print(f"upload: {done - len(failures):,} uploaded, {len(failures):,} failed in "
          f"{(time.time() - started) / 60:.1f} min; {len(listed):,} sets listed in {LIST.relative_to(ROOT)}")
    for line in failures[:10]:
        print(f"  {line}")
    return 1 if failures else 0


def storage_env() -> tuple[str, str]:
    """SUPABASE_URL and SUPABASE_SECRET_KEY, as tools/storage_parts.py reads them; LookupError when not set."""
    values: dict[str, str] = {}
    source = ROOT / ".env"
    if source.exists():
        for line in source.read_text().splitlines():
            if "=" in line and not line.startswith("#"):
                name, _, value = line.partition("=")
                values[name.strip()] = value.strip().strip("\"'")
    url = os.environ.get("SUPABASE_URL") or values.get("SUPABASE_URL", "")
    key = os.environ.get("SUPABASE_SECRET_KEY") or values.get("SUPABASE_SECRET_KEY", "")
    if not url or not key:
        raise LookupError("no SUPABASE_URL / SUPABASE_SECRET_KEY (.env or environment)")
    return url.rstrip("/"), key


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fetch", action="store_true", help="only fetch the pictures")
    parser.add_argument("--make", action="store_true", help="only make the WebPs")
    parser.add_argument("--upload", action="store_true", help="only upload them and write the list")
    parser.add_argument("--check", action="store_true", help="say what each step would do")
    parser.add_argument("--workers", type=int, default=max(1, min(8, (os.cpu_count() or 2) // 2)),
                        help="processes making WebPs")
    args = parser.parse_args()
    every = not (args.fetch or args.make or args.upload)
    if every and not args.check:
        # The daily run (tools/fetch_data.sh): only where the pictures can be
        # put up. A clone that cannot publish them has no use for 28,000.
        try:
            storage_env()
        except LookupError as missing:
            print(f"set pictures: {missing}, so none fetched: the box that deploys keeps them")
            return 0
    sets = wanted()
    status = 0
    if every or args.fetch:
        status |= fetch(sets, args.check)
    if every or args.make:
        status |= make(sets, args.check, args.workers)
    if every or args.upload:
        status |= upload(sets, args.check)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
