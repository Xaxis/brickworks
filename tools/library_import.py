#!/usr/bin/env python3
"""The OMR's new sets into the model library, the box's half (gallery362).

    tools/library_import.py list
    tools/library_import.py import [--most 3] [--dry-run] [--out DIR]
    tools/library_import.py publish PAGE [PAGE...]

Vercel's weekly cron looks at LDraw's Official Model Repository and writes
down what the library has not got (api/_omr_watch.js: library_arrivals,
found). Drawing a set's pictures takes the app's own renderer and the GPU,
so the rest is here, by the same path the library was built by
(tools/library_build.py, src/dev/library_covers.gd):

`import` takes up to --most arrivals that are found, oldest first, and for
each: fetches its file from LDraw, a second apart; holds it to our own
checks (the header's licence is one the site can pass on, CCAL 2.0 or CC BY
4.0, with LDraw's credit kept; it has parts; its theme and year are known
from the OMR's own set list in vendor/omr/index.json); writes its index
entry as library_build.py writes one; draws its cover, its page's picture
and its card's on the GPU; puts the file and the pictures in the parts
store; and marks it staged with its entry. A staged set shows only to a list
asked with tests=1 (/library?tests=1, its page with tests=1). One that fails
a check is refused, with why, and never tried again unless LDraw changes it.
--dry-run says what it would do and changes nothing: no drawing, no store,
no state.

`publish` lets staged sets out: their entries join the store's
library/index.json (held to library_build.py's checks first), which the
app's Library and the site both read, and each is marked live. The lead
runs it after looking at the staged pages.
"""

from __future__ import annotations

import argparse
import datetime
import json
import re
import shutil
import subprocess
import sys
import time
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import library_build  # noqa: E402

AGENT = {"User-Agent": "brickworks (https://brickworks.diy)"}
MAIN = Path(subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"], cwd=ROOT,
                           capture_output=True, text=True).stdout.strip() or ROOT / ".git").parent
OMR_INDEX = MAIN / "vendor" / "omr" / "index.json"


def env() -> dict[str, str]:
    said: dict[str, str] = {}
    for line in (MAIN / ".env").read_text().splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, _, value = line.partition("=")
            said[key.strip()] = value.strip().strip('"').strip("'")
    return said


def rpc(name: str, body: dict) -> object:
    keys = env()
    asked = urllib.request.Request(f"{keys['SUPABASE_URL'].rstrip('/')}/rest/v1/rpc/{name}",
                                   data=json.dumps(body).encode(), method="POST", headers={
                                       "apikey": keys["SUPABASE_SECRET_KEY"],
                                       "authorization": f"Bearer {keys['SUPABASE_SECRET_KEY']}",
                                       "content-type": "application/json"})
    with urllib.request.urlopen(asked, timeout=60) as answer:
        text = answer.read().decode()
    return json.loads(text) if text else None


def known_sets() -> dict[str, dict]:
    """The OMR's set list as tools/omr.py crawled it: {number: {name, theme, year, page}}."""
    if not OMR_INDEX.exists():
        return {}
    return {row["number"]: row for row in json.loads(OMR_INDEX.read_text())}


def parts_in(text: str) -> int:
    from omr import _flatten
    return len(_flatten(text))


def entry_of(arrival: dict, path: Path, sets: dict[str, dict]) -> tuple[dict | None, str]:
    """[arrival]'s index entry from its file at [path], as library_build.entries
    writes one, or (None, why it fails our checks)."""
    said_author, said_licence = library_build.header(path)
    licence = library_build.licence_of(said_licence)
    if not licence:
        return None, f"no licence the library can pass on ({said_licence!r})"
    text = path.read_text(errors="replace")
    parts = parts_in(text)
    if parts <= 0:
        return None, "no parts in it, as our reader reads it"
    known = sets.get(arrival["set_number"]) or {}
    theme = library_build.with_marks(library_build.tidy(str(known.get("theme", ""))))
    year = int(known.get("year") or 0) if str(known.get("year", "")).isdigit() else 0
    if not theme or not year:
        return None, f"its theme and year are not in the OMR's set list ({OMR_INDEX.name}); crawl it again"
    stem = library_build.safe_stem(path.stem)
    model_id = f"omr-{stem}"
    number = arrival["set_number"]
    alternate = stem.lower() != number.lower() and "_" in stem and bool(
        re.search(r"(^|-)(model-[b-z]|[b-z]-model|alternate)\b", stem.partition("_")[2], re.I))
    entry = {
        "id": model_id, "kind": "set", "set": number,
        "name": library_build.with_marks(library_build.tidy(arrival["name"])),
        "theme": theme, "year": year, "parts": parts,
        "box": library_build.box_of(number) if not alternate else 0,
        "file": f"library/omr/{stem}.mpd", "cover": f"library/covers/{model_id}.webp",
        "author": library_build.author_name(said_author) or "unknown", "licence": licence,
        "page": f"{library_build.PAGE}{arrival['page']}", "alternate_of": number if alternate else None,
    }
    wrong = library_build.problems({"version": 1, "models": [entry]})
    return (entry, "") if not wrong else (None, "; ".join(wrong)[:400])


def fetch(url: str, to: Path) -> Path:
    to.parent.mkdir(parents=True, exist_ok=True)
    with urllib.request.urlopen(urllib.request.Request(url, headers=AGENT), timeout=180) as answer:
        to.write_bytes(answer.read())
    time.sleep(1.0)
    return to


def draw(entries: list[dict], out: Path, sources: dict[str, Path], timeout: int = 1800) -> None:
    """Each entry's cover, page picture and card, drawn by the app as the library's were
    (library_build.covers' drawer), one GPU job a kind."""
    work = out / ".work"
    (work / "xdg").mkdir(parents=True, exist_ok=True)
    listing = work / "arrivals.tsv"
    listing.write_text("".join(f"{sources[e['id']]}\t{e['id']}\n" for e in entries))
    for clear in (False, True):
        folder = out / "library" / ("pages" if clear else "covers")
        folder.mkdir(parents=True, exist_ok=True)
        command = [str(library_build.CORE / "heavy"), str(library_build.CORE / "gpu"), "env",
                   f"XDG_DATA_HOME={work / 'xdg'}", "MESA_VK_WSI_DEBUG=sw",
                   "xvfb-run", "-a", "--server-args=-screen 0 640x480x24",
                   "godot", "--path", str(ROOT), "--resolution", "640x480",
                   "--script", "src/dev/library_covers.gd", "--",
                   f"--list={listing}", f"--out={folder}", f"--most={len(entries)}"]
        if clear:
            (out / "library" / "cards").mkdir(parents=True, exist_ok=True)
            command += ["--clear", f"--cards={out / 'library' / 'cards'}"]
        with (work / f"draw-{'clear' if clear else 'covers'}.log").open("w") as sink:
            subprocess.run(command, stdout=sink, stderr=subprocess.STDOUT, timeout=timeout, cwd=ROOT)


def store(out: Path, entry: dict) -> list[str]:
    """[entry]'s file and pictures into the parts store: the problems, or []."""
    from storage_library import LASTING, upload
    keys = env()
    problems = []
    for name in (entry["file"], entry["cover"], f"library/pages/{entry['id']}.webp",
                 f"library/cards/{entry['id']}.webp"):
        said = upload(keys["SUPABASE_URL"].rstrip("/"), keys["SUPABASE_SECRET_KEY"], name, out / name, LASTING, True)
        if said:
            problems.append(said)
    return problems


def list_(_: argparse.Namespace) -> int:
    for one in rpc("library_arrivals_in", {"state": None}) or []:
        print(f"{one['page']:>6} {one['set_number']:<12} {one['state']:<8} {one['name'][:40]:<40} "
              f"{one.get('why') or ''}")
    return 0


def import_(args: argparse.Namespace) -> int:
    out = args.out or (MAIN / "bench" / "results" / f"library-arrivals-{datetime.date.today().isoformat()}")
    sets = known_sets()
    found = (rpc("library_arrivals_in", {"state": "found"}) or [])[: args.most]
    if not found:
        print("import: nothing found waits")
        return 0
    entries, sources = [], {}
    for arrival in found:
        source = out / "files" / Path(arrival["file"]).name
        if not source.exists():
            fetch(arrival["file"], source)
        entry, why = entry_of(arrival, source, sets)
        if not entry:
            print(f"import: {arrival['page']} {arrival['set_number']} refused: {why}")
            if not args.dry_run:
                rpc("library_arrival_set", {"page": arrival["page"], "state": "refused", "why": why})
            continue
        print(f"import: {arrival['page']} {arrival['set_number']} {entry['name']!r} ({entry['theme']}, "
              f"{entry['year']}, {entry['parts']} parts, by {entry['author']}, {entry['licence']})"
              f"{' would be drawn and staged' if args.dry_run else ''}")
        target = out / entry["file"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        entries.append((arrival, entry))
        sources[entry["id"]] = target
    if args.dry_run or not entries:
        return 0
    (out / ".gdignore").touch()
    draw([entry for _, entry in entries], out, sources)
    staged = 0
    for arrival, entry in entries:
        drawn = all((out / path).is_file() for path in (entry["cover"], f"library/pages/{entry['id']}.webp",
                                                         f"library/cards/{entry['id']}.webp"))
        if not drawn:
            print(f"import: {entry['id']} was not drawn; left found for the next import ({out / '.work'})")
            continue
        problems = store(out, entry)
        if problems:
            print(f"import: {entry['id']} not stored: {problems[:2]}; left found")
            continue
        rpc("library_arrival_set", {"page": arrival["page"], "state": "staged", "entries": [entry]})
        staged += 1
        print(f"import: {entry['id']} staged: /library/{entry['id']}?tests=1")
    print(f"import: {staged} of {len(entries)} staged, in {out}")
    return 0 if staged == len(entries) else 1


def publish(args: argparse.Namespace) -> int:
    from storage_library import INDEX, upload
    keys = env()
    pages = {int(page) for page in args.pages}
    staged = [one for one in rpc("library_arrivals_in", {"state": "staged"}) or [] if one["page"] in pages]
    if not staged:
        raise SystemExit("publish: none of those is staged")
    root = f"{keys['SUPABASE_URL'].rstrip('/')}/storage/v1/object/public/{library_build_bucket()}/"
    with urllib.request.urlopen(f"{root}library/index.json", timeout=60) as answer:
        index = json.loads(answer.read().decode())
    have = {m["id"] for m in index["models"]}
    for one in staged:
        index["models"] += [e for e in one["entries"] if e["id"] not in have]
    wrong = library_build.problems(index)
    if wrong:
        raise SystemExit(f"publish: the index would be wrong: {wrong[:3]}")
    kept = ROOT / ".work-index.json"
    kept.write_text(json.dumps(index, ensure_ascii=False, separators=(",", ":")))
    try:
        said = upload(keys["SUPABASE_URL"].rstrip("/"), keys["SUPABASE_SECRET_KEY"], "library/index.json", kept,
                      INDEX, True)
    finally:
        kept.unlink(missing_ok=True)
    if said:
        raise SystemExit(f"publish: {said}")
    for one in staged:
        rpc("library_arrival_set", {"page": one["page"], "state": "live"})
        print(f"publish: {one['page']} {one['set_number']} is live")
    return 0


def library_build_bucket() -> str:
    from storage_parts import BUCKET
    return BUCKET


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="what", required=True)
    sub.add_parser("list")
    one = sub.add_parser("import")
    one.add_argument("--most", type=int, default=3)
    one.add_argument("--dry-run", action="store_true")
    one.add_argument("--out", type=Path, default=None)
    two = sub.add_parser("publish")
    two.add_argument("pages", nargs="+")
    args = parser.parse_args(argv)
    return {"list": list_, "import": import_, "publish": publish}[args.what](args)


if __name__ == "__main__":
    sys.exit(main())
