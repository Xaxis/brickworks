#!/usr/bin/env python3
"""The model library the app opens from: every official LDraw model of a real
set (vendor/omr), each with a cover picture, laid out as the parts store holds
it, beside the parts:

    library/index.json            what there is (the format below)
    library/omr/<file>.mpd        each model, byte for byte as LDraw has it
    library/covers/<id>.webp      each model built, from the three-quarter view

    tools/library_build.py stage  [--out DIR]   copy the models, write the index
    tools/library_build.py covers [--out DIR]   draw the covers not drawn yet (GPU)
    tools/library_build.py check  [--out DIR]   hold the index to the format and the files
    tools/library_build.py sample --to DIR [--count 30]
                                  a few models and their covers from DIR, for
                                  working on the library's screen without the store
    tools/library_build.py sheet  [--count 60]
                                  contact sheets of that many covers, spread over
                                  the library, to look through by eye

DIR is bench/results/library-2026-10-26 unless said. Nothing is uploaded here:
tools/storage_library.py sends DIR/library/ to the store.

The index, which the app's library screen reads:

    {"version": 1, "models": [{"id": "omr-10179-1", "kind": "set",
      "set": "10179-1", "name": "Millennium Falcon - UCS", "theme": "Star Wars",
      "year": 2007, "parts": 5195, "file": "library/omr/10179-1.mpd",
      "cover": "library/covers/omr-10179-1.webp", "author": "Roland Dahl",
      "licence": "CCAL 2.0", "page": "https://library.ldraw.org/omr/sets/...",
      "alternate_of": null}]}

Paths are relative to the store's root, as a part's are. The name, set, year,
theme, page and part count are models.json's (src/dev/collection_models.gd
counts each file with the app's own reader), so the library and "What can I
build?" agree; the author and licence are the file's own header, its main
model's (the first FILE). A model filed under its set with a name after the
number (10001-1_B-Model-from-Instruction.mpd) is the set's other build, and
says so in alternate_of, when the set's own model is there too or its name
says it is the B model; otherwise each of a set's models is one of its own
(10022-1's three cars). Names keep LEGO® with its mark, as docs/TRADEMARKS.md
asks (rule 1); a set's name says only which set a model is of (rule 6).

Covers are drawn by src/dev/library_covers.gd, the app's own ModelShot, in a
window on the GPU's lease. One drawer takes up to --most models, and leaves
after twenty seconds when another job waits for the GPU, so the lease is never
held long against anyone; the next drawer queues for it again. A model draws
in 0.1 to 6 s; starting a drawer is the slow part.
"""
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OMR = ROOT / "vendor" / "omr"
MODELS = ROOT / "assets" / "generated" / "sets" / "models.json"
DEFAULT_OUT = ROOT / "bench" / "results" / "library-2026-10-26"
PAGE = "https://library.ldraw.org/omr/sets/"
LICENCES = ("CCAL 2.0", "CC BY 4.0")
FIELDS = ("id", "kind", "set", "name", "theme", "year", "parts", "box", "file", "cover",
          "author", "licence", "page", "alternate_of")
CORE = Path.home() / ".claude" / "claude-core" / "bin"


SETS = ROOT / "assets" / "generated" / "sets"


def shard_of(number: str) -> int:
    """SetInventories.shard_of: the shard a set's inventory is in."""
    h = 0
    for byte in number.lower().encode():
        h = (h * 31 + byte) % 1000003
    return h % 256


_shards: dict[int, dict] = {}


def box_of(number: str) -> int:
    """The parts the set's box holds, by its inventory, spares left out: what
    a card says beside the model's own count where the two differ (0 when the
    set is not known)."""
    shard = shard_of(number)
    if shard not in _shards:
        path = SETS / f"{shard:03d}.json"
        _shards[shard] = json.loads(path.read_text()).get("sets", {}) if path.exists() else {}
    record = _shards[shard].get(number.lower()) or _shards[shard].get(number)
    return sum(int(row[2]) for row in record["p"]) if record else 0


def safe_stem(stem: str) -> str:
    """A file's name as a store path can carry it unquoted: one OMR file has an
    apostrophe (10183-1_Pig's-nose-train)."""
    return re.sub(r"[^A-Za-z0-9._-]", "", stem)


def with_marks(words: str) -> str:
    """LEGO® with its mark each time, and LEGOLAND® in capitals; never the LEGO Group."""
    words = re.sub(r"\bLEGO\b(?!®| Group)", "LEGO®", words)
    return re.sub(r"\bLegoland\b|\bLEGOLAND\b(?!®)", "LEGOLAND®", words)


def tidy(words: str) -> str:
    return re.sub(r"\s+", " ", words).strip()


def header(path: Path) -> tuple[str, str]:
    """The main model's author and licence, as its header says them: the
    lines before its first part. ("", "") when it says neither."""
    author = licence = ""
    with path.open(encoding="utf-8", errors="replace") as text:
        for n, line in enumerate(text):
            words = line.strip()
            if words.startswith("1 ") or n > 200:
                break
            low = words.lower()
            if low.startswith("0 author:") and not author:
                author = words[len("0 author:"):].strip()
            elif low.startswith("0 !license") and not licence:
                licence = words[len("0 !license"):].strip()
    return author, licence


def author_name(said: str) -> str:
    """'Roland Dahl [RolandD]' is credited as Roland Dahl; a bare login as itself."""
    name = re.sub(r"\[[^\]]*\]", "", said).strip()
    return tidy(name or said.strip("[] "))


def licence_of(said: str) -> str:
    """The licence a header names, as the index writes it, or '' for one it
    does not grant. LDraw writes CC BY as "CCAL" (Creative Commons
    Attribution Licence) as often as not, "CCAL version 4.0" once."""
    low = said.lower()
    if "ccal version 2.0" in low or "cc by 2.0" in low:
        return "CCAL 2.0"
    if "cc by 4.0" in low or "ccal version 4.0" in low:
        return "CC BY 4.0"
    return ""


def entries(models_path: Path = MODELS, files_dir: Path = OMR / "files") -> tuple[list[dict], dict]:
    """The index's models, from models.json and each file's header, and what
    was left out and why ({file: why})."""
    listed = {m["file"]: m for m in json.loads(models_path.read_text())["models"]}
    files = sorted(p for p in files_dir.glob("*.mpd"))
    plain = {p.stem.lower() for p in files if "_" not in p.stem}
    out: list[dict] = []
    left: dict[str, str] = {}
    for path in files:
        model = listed.get(path.name)
        if model is None:
            left[path.name] = "not in models.json (the app's reader counts no parts in it)"
            continue
        said_author, said_licence = header(path)
        licence = licence_of(said_licence)
        if not licence:
            left[path.name] = f"no licence the library can pass on ({said_licence!r})"
            continue
        stem = safe_stem(path.stem)
        number = model["set"]
        other = path.stem.partition("_")[2]
        alternate = bool(other) and (number.lower() in plain or bool(
            re.search(r"(^|-)(model-[b-z]|[b-z]-model|alternate)\b", other, re.I)))
        model_id = "omr-" + stem
        out.append({
            "id": model_id,
            "kind": "set",
            "set": number,
            "name": with_marks(tidy(model["n"])),
            "theme": with_marks(tidy(model["t"])),
            "year": int(model["y"]),
            # The model's own count, as the app counts a model it opens
            # (Inventory.count_of_text); the lots' sum is what of its set's
            # box it uses, which left out the parts a file carries.
            "parts": int(model.get("c", sum(int(row[2]) for row in model["p"]))),
            "box": box_of(number) if not alternate else 0,
            "file": f"library/omr/{stem}.mpd",
            "cover": f"library/covers/{model_id}.webp",
            "author": author_name(said_author) or "unknown",
            "licence": licence,
            "page": PAGE + str(model["g"]) if model.get("g") else "",
            "alternate_of": number if alternate else None,
            "_source": str(path),
        })
    return out, left


def problems(index: dict, root: Path | None = None) -> list[str]:
    """Everything wrong with an index, held to the format the library screen
    reads; with [root], its files too (each model and cover is there)."""
    wrong: list[str] = []
    if set(index) != {"version", "models"} or index.get("version") != 1:
        wrong.append(f"top level is {sorted(index)} version {index.get('version')!r}, "
                     "not {version: 1, models}")
    models = index.get("models")
    if not isinstance(models, list) or not models:
        return wrong + ["no models"]
    seen: set[str] = set()
    for n, m in enumerate(models):
        at = f"model {n} ({m.get('id', '?')})"
        if not isinstance(m, dict) or tuple(m) != FIELDS:
            wrong.append(f"{at}: fields {list(m) if isinstance(m, dict) else m!r}, not {list(FIELDS)}")
            continue
        for key in ("id", "kind", "set", "name", "theme", "file", "cover", "author", "page"):
            if not isinstance(m[key], str) or not m[key]:
                wrong.append(f"{at}: {key} {m[key]!r} is not a word")
        for key in ("year", "parts"):
            if not isinstance(m[key], int) or isinstance(m[key], bool) or m[key] <= 0:
                wrong.append(f"{at}: {key} {m[key]!r} is not a count")
        if not isinstance(m.get("box", 0), int) or isinstance(m.get("box", 0), bool) or m.get("box", 0) < 0:
            wrong.append(f"{at}: box {m.get('box')!r} is not a count")
        if m["kind"] != "set":
            wrong.append(f"{at}: kind {m['kind']!r}")
        if m["licence"] not in LICENCES:
            wrong.append(f"{at}: licence {m['licence']!r}")
        if not re.fullmatch(r"omr-[A-Za-z0-9._-]+", str(m["id"])):
            wrong.append(f"{at}: id is not omr-<file stem>")
        if m["file"] != f"library/omr/{str(m['id'])[4:]}.mpd":
            wrong.append(f"{at}: file {m['file']!r}")
        if m["cover"] != f"library/covers/{m['id']}.webp":
            wrong.append(f"{at}: cover {m['cover']!r}")
        if not str(m["page"]).startswith(PAGE):
            wrong.append(f"{at}: page {m['page']!r}")
        if not re.fullmatch(r"[0-9A-Za-z]+(-[0-9A-Za-z]+)*", str(m["set"])):
            wrong.append(f"{at}: set {m['set']!r}")
        if m["alternate_of"] is not None and m["alternate_of"] != m["set"]:
            wrong.append(f"{at}: alternate_of {m['alternate_of']!r} is neither null nor its set")
        if re.search(r"\bLEGO\b(?!®| Group)", str(m["name"]) + " " + str(m["theme"])):
            wrong.append(f"{at}: LEGO without its ® in {m['name']!r} / {m['theme']!r}")
        if m["id"] in seen:
            wrong.append(f"{at}: id twice")
        seen.add(m["id"])
        if root is not None:
            for key in ("file", "cover"):
                where = root / m[key]
                if not where.is_file() or where.stat().st_size == 0:
                    wrong.append(f"{at}: no {m[key]}")
    return wrong


def written(models: list[dict]) -> dict:
    return {"version": 1, "models": [{k: m[k] for k in FIELDS} for m in models]}


def stage(out: Path) -> int:
    models, left = entries()
    have = set()
    shelf = out / "library" / "omr"
    shelf.mkdir(parents=True, exist_ok=True)
    (out / "library" / "covers").mkdir(parents=True, exist_ok=True)
    # The staged tree is not the project's: Godot leaves it alone.
    (out / ".gdignore").touch()
    # Only models whose cover is drawn are listed, and only their files staged:
    # the screen shows each one's picture.
    drawn = [m for m in models if (out / m["cover"]).is_file()]
    for m in drawn:
        target = out / m["file"]
        source = Path(m["_source"])
        if not target.exists() or target.stat().st_size != source.stat().st_size:
            shutil.copyfile(source, target)
        have.add(target.name)
    for stray in shelf.glob("*.mpd"):
        if stray.name not in have:
            stray.unlink()
    index = written(drawn)
    (out / "library" / "index.json").write_text(
        json.dumps(index, ensure_ascii=False, separators=(",", ":")))
    by_licence: dict[str, int] = {}
    for m in drawn:
        by_licence[m["licence"]] = by_licence.get(m["licence"], 0) + 1
    failed = sorted(p.stem for p in (out / "library" / "covers").glob("*.failed"))
    print(f"library: {len(models)} models of {len(models) + len(left)} files, "
          f"{len(drawn)} with covers, in {out / 'library'}")
    print(f"  by licence: {by_licence}")
    print(f"  alternate builds: {sum(1 for m in drawn if m['alternate_of'])}")
    for name, why in left.items():
        print(f"  left out {name}: {why}")
    for model_id in failed:
        print(f"  no cover for {model_id}: "
              f"{(out / 'library' / 'covers' / (model_id + '.failed')).read_text().strip()}")
    sizes = sum(p.stat().st_size for p in (out / "library").rglob("*")
                if p.is_file() and p.suffix != ".failed")
    files = sum(1 for p in (out / "library").rglob("*") if p.is_file() and p.suffix != ".failed")
    print(f"  {files} files, {sizes / 1e6:.1f} MB to upload")
    return 0


def covers(out: Path, most: int, run_timeout: int) -> int:
    models, _ = entries()
    folder = out / "library" / "covers"
    folder.mkdir(parents=True, exist_ok=True)
    work = out / ".work"
    (work / "logs").mkdir(parents=True, exist_ok=True)
    (work / "xdg").mkdir(parents=True, exist_ok=True)
    listing = work / "covers.tsv"
    listing.write_text("".join(f"{m['_source']}\t{m['id']}\n" for m in models))

    def left() -> list[dict]:
        return [m for m in models if not (folder / f"{m['id']}.webp").exists()
                and not (folder / f"{m['id']}.failed").exists()]

    started = time.time()
    runs = idle = 0
    while (todo := left()) and idle < 3:
        runs += 1
        log = work / "logs" / f"run-{runs:03d}.log"
        command = [str(CORE / "heavy"), str(CORE / "gpu"), "env",
                   f"XDG_DATA_HOME={work / 'xdg'}", "MESA_VK_WSI_DEBUG=sw",
                   "xvfb-run", "-a", "--server-args=-screen 0 640x480x24",
                   "godot", "--path", str(ROOT), "--resolution", "640x480",
                   "--script", "src/dev/library_covers.gd", "--",
                   f"--list={listing}", f"--out={folder}", f"--most={most}"]
        with log.open("w") as sink:
            try:
                code = subprocess.run(command, stdout=sink, stderr=subprocess.STDOUT,
                                      timeout=run_timeout, cwd=ROOT).returncode
            except subprocess.TimeoutExpired:
                code = -1
        after = left()
        done = len(todo) - len(after)
        said = log.read_text(errors="replace")
        # A drawer that died on a model never said how it went: that model is
        # marked so the next drawer goes on past it.
        opening = re.findall(r"^library_covers: opening (\S+)$", said, re.M)
        if code != 0 and opening and any(m["id"] == opening[-1] for m in after):
            (folder / f"{opening[-1]}.failed").write_text(
                f"the drawer exited {code} while drawing it ({log.name})\n")
            done += 1
        idle = 0 if done else idle + 1
        print(f"covers: run {runs} drew {done} (exit {code}), {len(after)} left, "
              f"{(time.time() - started) / 60:.1f} min so far", flush=True)
    todo = left()
    drawn = sum(1 for m in models if (folder / f"{m['id']}.webp").exists())
    failed = sum(1 for m in models if (folder / f"{m['id']}.failed").exists())
    print(f"covers: {drawn} drawn, {failed} without a picture, {len(todo)} not tried, "
          f"of {len(models)}, in {(time.time() - started) / 60:.1f} min")
    return 0 if not todo else 1


def sample(source: Path, to: Path, count: int) -> int:
    """[count] models with covers, a spread of themes, sizes and alternates, in
    the same layout and format, for working on the screen without the store."""
    index = json.loads((source / "library" / "index.json").read_text())
    models = index["models"]
    chosen: list[dict] = []
    themes: set[str] = set()
    # One per top theme first, largest themes first, then the other licence,
    # alternates and the biggest and smallest, so the screen meets each kind
    # of row.
    by_theme: dict[str, list[dict]] = {}
    for m in models:
        by_theme.setdefault(m["theme"].split(" > ")[0], []).append(m)
    for theme in sorted(by_theme, key=lambda t: -len(by_theme[t])):
        if len(chosen) >= count - 7:
            break
        pick = by_theme[theme][len(by_theme[theme]) // 2]
        chosen.append(pick)
        themes.add(theme)
    extra = [m for m in models if m["licence"] != "CCAL 2.0"][:1]
    extra += [m for m in models if m["alternate_of"]][:3]
    extra += sorted(models, key=lambda m: m["parts"])[:1] + sorted(models, key=lambda m: -m["parts"])[:2]
    for m in extra:
        if m not in chosen and len(chosen) < count:
            chosen.append(m)
    for m in models:
        if len(chosen) >= count:
            break
        if m not in chosen:
            chosen.append(m)
    if to.exists():
        shutil.rmtree(to / "library", ignore_errors=True)
    for m in chosen:
        for key in ("file", "cover"):
            (to / m[key]).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / m[key], to / m[key])
    (to / ".gdignore").touch()
    (to / "library" / "index.json").write_text(
        json.dumps({"version": 1, "models": chosen}, ensure_ascii=False, indent=1))
    print(f"sample: {len(chosen)} models in {to / 'library'} "
          f"({len(themes)} themes, {sum(1 for m in chosen if m['alternate_of'])} alternates)")
    return 0


def sheet(out: Path, count: int) -> int:
    """Contact sheets of [count] covers taken evenly through the index, thirty
    a sheet, each with its id under it, in DIR/sheets/."""
    from PIL import Image, ImageDraw

    models = json.loads((out / "library" / "index.json").read_text())["models"]
    step = max(1, len(models) // max(1, count))
    picked = models[::step][:count]
    across, tile, label = 6, (256, 192), 16
    (out / "sheets").mkdir(exist_ok=True)
    for page in range(0, len(picked), 30):
        some = picked[page:page + 30]
        rows = (len(some) + across - 1) // across
        board = Image.new("RGB", (across * tile[0], rows * (tile[1] + label)), 0xFFFFFF)
        draw = ImageDraw.Draw(board)
        for n, m in enumerate(some):
            x, y = (n % across) * tile[0], (n // across) * (tile[1] + label)
            board.paste(Image.open(out / m["cover"]).convert("RGB").resize(tile), (x, y))
            draw.text((x + 4, y + tile[1] + 2), f"{m['id'][4:]} {m['parts']}", fill="black")
        where = out / "sheets" / f"sheet-{page // 30 + 1}.png"
        board.save(where)
        print(f"sheet: {where} ({len(some)} covers)")
    return 0


def check(out: Path) -> int:
    index = json.loads((out / "library" / "index.json").read_text())
    wrong = problems(index, out)
    for line in wrong[:40]:
        print("  " + line)
    print(f"check: {len(index.get('models', []))} models, {len(wrong)} problems")
    return 1 if wrong else 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("what", choices=["stage", "covers", "check", "sample", "sheet"])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--to", type=Path, help="sample: where to write it")
    parser.add_argument("--count", type=int, default=30)
    parser.add_argument("--most", type=int, default=100,
                        help="covers: the most models one drawer takes on its lease")
    parser.add_argument("--run-timeout", type=int, default=3600,
                        help="covers: seconds one drawer may take, its wait for the GPU too")
    args = parser.parse_args()
    out = args.out.resolve()
    if args.what == "stage":
        return stage(out)
    if args.what == "covers":
        return covers(out, args.most, args.run_timeout)
    if args.what == "check":
        return check(out)
    if args.what == "sheet":
        return sheet(out, args.count)
    if not args.to:
        parser.error("sample needs --to")
    return sample(out, args.to.resolve(), args.count)


if __name__ == "__main__":
    raise SystemExit(main())
