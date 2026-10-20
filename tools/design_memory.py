#!/usr/bin/env python3
"""Our own scored designs, found by what they are: the designer's memory.

    tools/design_memory.py build [--results DIR ...]   bench records -> the index
    tools/design_memory.py list                        what the index holds

The design bench (tools/bench, docs/DESIGN_SCORES.md) designs ten held-out
subjects and has a calibrated judge score each design on six dimensions,
with a line of reason each. Those reasons are the best criticism a design
here has had, and they were read once, by whoever wrote up the batch. This
keeps every one: for each scored design its subject and brief, its scores,
the judge's reasons, how it was built (tools/style.py's measures, its
most-used shaped parts, and from its log the features it worked, the
worked techniques it read and the real-set pieces it laid) and a small
picture of it. The app searches it the way it searches the real-set index
(src/ai/design_memory.gd, beside src/ai/real_snippets.gd): BM25 over
weighted words, stemmed by tools/snippets.py's words(), with a subject
also asking for its kinds (an eagle asks for birds and animals).

`build` reads every <batch>/<subject>/<run>/record.json under each
--results folder (by default the main checkout's bench/results, where
tools/bench/run.py writes from any worktree; a dry run and the records a
re-score set aside are left out), and keeps what the index already holds
for runs it cannot see: bench results are not committed, and the raw
results of four rounds went with the worktrees that ran them. The index
is what keeps their critiques now. Rerun it after a batch.
"""

from __future__ import annotations

import argparse
import base64
import gzip
import io
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import snippets  # noqa: E402
from ldraw.parser import read_text  # noqa: E402
import style  # noqa: E402
from bench.judge import DIMENSIONS  # noqa: E402
from bench.run import RESULTS  # noqa: E402

OUT = ROOT / "assets" / "knowledge" / "designs.json.gz"
SCORES = ROOT / "docs" / "DESIGN_SCORES.md"
# The build check before 26ddb89 misread hinged parts and fired picture
# faults written for Orthanc, so buildability judged on it is no fault to
# design out. The baseline was re-scored on the fixed check, and its build
# is taken from that table in docs/DESIGN_SCORES.md (a batch, and a word of
# its re-score's heading); the judge's words for it were not kept, having
# gone with the worktree that ran it. The design5 batches were never
# re-scored, and their build is not told.
RESCORED = {"2026-10-12": "re-scored"}
OLD_CHECK = {"2026-10-12-d5", "2026-10-12-d5b"}
# What the eye judges; buildability is the build check's, scored from its
# words, and was mis-scored by the check before 26ddb89.
VISUAL = [d for d in DIMENSIONS if d != "buildability"]
FIELDS = {"title": 3.0, "brief": 1.5, "kinds": 1.0, "features": 1.0, "reasons": 0.3}
THUMB = 192
# Words of a title that do not name what it is: "a Star-Wars-like
# starfighter" is not about likeness, nor "a small modular corner shop"
# about smallness. A query must share a named word or a kind of subject
# with a design for it to be near at all, or "make it two studs taller"
# would be handed the gatehouse's critique.
NOT_NAMING = set("like small large big little detailed display scale lego model style "
                 "functions function".split())


def _subject_kinds(*texts: str) -> list[str]:
    """The kinds of subject the words name: a barn owl is a bird and an animal."""
    found: set[str] = set()
    for text in texts:
        for word in snippets.words(text):
            found.update(snippets.SUBJECT_OF.get(word, ()))
    return sorted(found)


def _process(log: str) -> dict:
    """What a design session did, from the app's lines in its log: the
    features it worked, the worked techniques it read, the real-set pieces
    it laid, the figures it stood and whether it made the creative pass.
    Runs before the feature pass (2026-10-12) have none of these lines."""
    def found(pattern: str) -> list[str]:
        seen: list[str] = []
        for match in re.finditer(pattern, log, re.M):
            said = " ".join(match.group(1).split())
            if said and said not in seen:
                seen.append(said)
        return seen
    return {"features": found(r"app: working the (.+?) \(feature \d+ of \d+\)"),
            "techniques": found(r"app: looking up how to do (.+?)\s*$"),
            "laid": found(r"app: laying (\S+) as a real set built it"),
            "figures": found(r"app: standing (.+?) in the model"),
            "creative": "app: the creative pass" in log}


def _built(measured: dict, ldr: Path, parts: style.Parts) -> tuple[str, list[list]]:
    """How it was built, as tools/style.py measures it, and its most-used
    parts that are not plain bricks and plates."""
    if not measured.get("parts"):
        return "", []
    pct = lambda key: round(100 * float(measured.get(key, 0.0)))  # noqa: E731
    said = []
    for key, words, least in (("sideways", "studs sideways", 3), ("snot_parts", "brackets", 2),
                              ("tilted", "at an angle", 2), ("angle_parts", "hinges and clips", 2),
                              ("curve", "curved or round", 3), ("slope", "sloped", 3),
                              ("tile", "tiled", 3), ("texture", "texture parts", 3),
                              ("organic", "plants and rocks", 2)):
        if pct(key) >= least:
            said.append(f"{words} {pct(key)}%")
    said.append(f"plain bricks and plates {pct('plain')}%")
    shaped: Counter = Counter()
    if ldr.exists():
        model = style.read(read_text(ldr))
        for placed in model.placed:
            info = parts.get(placed.part, model.embedded)
            if not style.building(info) or info is None:
                continue
            if style.kinds(info) - {"plain"}:
                shaped[info.name] += 1
    return ", ".join(said), [[name, n] for name, n in shaped.most_common(5)]


def _thumb(picture: Path) -> str:
    """The design's corner view, cropped to the model and THUMB pixels on its
    longer side, as base64 JPEG: small enough to carry in the index."""
    if not picture.exists():
        return ""
    from PIL import Image, ImageChops
    image = Image.open(picture).convert("RGB")
    background = Image.new("RGB", image.size, image.getpixel((0, 0)))  # pyright: ignore[reportArgumentType]
    box = ImageChops.difference(image, background).convert("L").point(
        lambda v: 255 if v > 24 else 0).getbbox()
    if box:
        pad = 12
        image = image.crop((max(0, box[0] - pad), max(0, box[1] - pad),
                            min(image.width, box[2] + pad), min(image.height, box[3] + pad)))
    image.thumbnail((THUMB, THUMB))
    out = io.BytesIO()
    image.save(out, "JPEG", quality=72, optimize=True)
    return base64.b64encode(out.getvalue()).decode()


def entry_of(record_path: Path, parts: style.Parts) -> dict | None:
    record = json.loads(record_path.read_text())
    if record.get("dry_run") or not record.get("design", {}).get("model"):
        return None
    run_dir = record_path.parent
    judged = record["judge"]
    scores = {d: int(round(float(judged["scores"][d]))) for d in DIMENSIONS}
    reasons = {d: str(judged["reasons"].get(d, "")) for d in DIMENSIONS}
    again = record.get("judge_again") or {}
    log = (run_dir / "design.log").read_text(errors="replace") if (run_dir / "design.log").exists() else ""
    built, shaped = _built(record.get("style") or {}, run_dir / "design.ldr", parts)
    probe = record.get("probe") or {}
    entry = {
        "id": f"{record['batch']}/{record['subject']}/{record['run']}",
        "subject": record["subject"], "title": record["title"], "brief": record["brief"],
        "batch": record["batch"], "commit": record.get("commit", "?"),
        "rubric": record.get("rubric", 1),
        "scores": scores,
        "visual": round(sum(scores[d] for d in VISUAL) / len(VISUAL), 2),
        "parts": int(probe.get("parts") or (record.get("style") or {}).get("parts") or 0),
        "pieces": int(probe.get("pieces") or 0),
        "reasons": reasons,
        # Searched, never shown: the same design judged a second time is
        # a second description of it.
        "reasons_again": " ".join(str(v) for k, v in (again.get("reasons") or {}).items()
                                  if k != "buildability"),
        "built": built, "shaped": shaped,
        "process": _process(log),
        "thumb": _thumb(run_dir / "views_corner.png"),
    }
    return entry


def _terms(entry: dict) -> dict[str, float]:
    terms: dict[str, float] = {}

    def add(text: str, weight: float) -> None:
        for word in snippets.words(text):
            terms[word] = terms.get(word, 0.0) + weight
    add(entry["title"] + " " + entry["subject"].replace("_", " "), FIELDS["title"])
    add(entry["brief"], FIELDS["brief"])
    add(" ".join(entry["kinds"]), FIELDS["kinds"])
    add(" ".join(entry["process"]["features"]), FIELDS["features"])
    add(" ".join(v for k, v in entry["reasons"].items() if k != "buildability")
        + " " + entry.get("reasons_again", ""), FIELDS["reasons"])
    return {k: round(v, 2) for k, v in terms.items()}


def rescored_builds(text: str, heading_word: str) -> dict[str, float]:
    """Subject -> buildability, from the first table under the heading of
    docs/DESIGN_SCORES.md that has the word."""
    lines = text.splitlines()
    at = next((n for n, line in enumerate(lines)
               if line.startswith("## ") and heading_word in line), None)
    out: dict[str, float] = {}
    if at is None:
        return out
    columns: list[str] | None = None
    for line in lines[at + 1:]:
        if line.startswith("## ") or (columns and not line.startswith("|")):
            break
        if not line.startswith("|"):
            continue
        cells = [c.strip().strip("*") for c in line.strip().strip("|").split("|")]
        if columns is None:
            columns = cells
        elif not set(cells[0]) <= set("-"):
            row = dict(zip(columns, cells))
            try:
                out[row["subject"]] = float(row["build"])
            except (KeyError, ValueError):
                continue
    return out


def finish(entries: list[dict], out: Path) -> dict:
    """What is worked out from what was read, done again on every build so
    that kept designs follow a change to the rules: the re-scored build, the
    kinds of subject, the naming words, and the search terms. Then the index
    written."""
    told = SCORES.read_text() if SCORES.exists() else ""
    for batch, word in RESCORED.items():
        builds = rescored_builds(told, word)
        for entry in entries:
            if entry["batch"] == batch and entry["subject"] in builds:
                build = builds[entry["subject"]]
                entry["scores"]["buildability"] = int(round(build))
                entry["reasons"]["buildability"] = (
                    f"Re-scored {build:g} on the fixed build check (26ddb89); the judge's "
                    "words for it were not kept.")
    for entry in entries:
        entry["build_told"] = entry["batch"] not in OLD_CHECK
        entry["kinds"] = _subject_kinds(entry["title"], entry["brief"])
        entry["named"] = sorted(set(snippets.words(
            entry["title"] + " " + entry["subject"].replace("_", " "))) - NOT_NAMING)
        entry["t"] = _terms(entry)
        entry["n"] = round(sum(entry["t"].values()), 2)
    count: Counter = Counter()
    for entry in entries:
        count.update(entry["t"].keys())
    total = len(entries)
    document = {
        "format": 1,
        "about": "Designs made here and scored by the design bench's judge "
                 "(tools/bench, docs/DESIGN_SCORES.md). tools/design_memory.py.",
        "anchors": "LEGO's own 10242 MINI Cooper is 9; the same car as a naive stack of "
                   "plain bricks is 2",
        "fields": FIELDS,
        "subjects": {k: v.split() for k, v in snippets.SUBJECTS.items()},
        "idf": {w: round(math.log(1 + (total - n + 0.5) / (n + 0.5)), 3) for w, n in count.items()},
        "average": round(sum(e["n"] for e in entries) / max(1, total), 2),
        "entries": sorted(entries, key=lambda e: e["id"]),
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    raw = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode()
    out.write_bytes(gzip.compress(raw, 9, mtime=0) if out.suffix == ".gz" else raw)
    return document


def load(path: Path = OUT) -> dict:
    if not path.exists():
        return {"entries": []}
    raw = path.read_bytes()
    return json.loads(gzip.decompress(raw) if path.suffix == ".gz" else raw)


def build(results: list[Path], out: Path, fresh: bool) -> int:
    parts = style.Parts()
    kept = {} if fresh else {e["id"]: e for e in load(out)["entries"]}
    read = 0
    for folder in results:
        # <batch>/<subject>/<run>/record.json, and no deeper: a re-score
        # keeps the record it replaced in an oldcheck/ folder of the run.
        for record_path in sorted(folder.glob("*/*/*/record.json")):
            if record_path.parts[-4].startswith("dry-"):
                continue
            entry = entry_of(record_path, parts)
            if entry is None:
                continue
            kept[entry["id"]] = entry
            read += 1
    document = finish(list(kept.values()), out)
    subjects = Counter(e["subject"] for e in document["entries"])
    print(f"{read} records read; {len(document['entries'])} designs of {len(subjects)} "
          f"subjects in {out} ({out.stat().st_size // 1024} KB)")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("build")
    one.add_argument("--results", type=Path, action="append",
                     help="a bench results folder; more than one may be given "
                          "(default the main checkout's bench/results)")
    one.add_argument("--out", type=Path, default=OUT)
    one.add_argument("--fresh", action="store_true",
                     help="forget what the index holds and keep only what is read now")
    two = sub.add_parser("list")
    two.add_argument("--index", type=Path, default=OUT)
    args = parser.parse_args()
    if args.command == "build":
        return build(args.results or [RESULTS], args.out, args.fresh)
    for entry in load(args.index)["entries"]:
        print(f"{entry['id']:40} {entry['visual']:4.1f}  "
              + " ".join(f"{d[:4]} {entry['scores'][d]}" for d in DIMENSIONS)
              + f"  {entry['parts']}p  {', '.join(entry['kinds'])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
