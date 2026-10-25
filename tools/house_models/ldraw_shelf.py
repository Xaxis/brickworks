#!/usr/bin/env python3
"""The gallery's shelf from the LDraw library: real builders' models of real
sets, each credited to the person who modelled it for LDraw's Official Model
Repository and shared under its own licence.

    tools/house_models/ldraw_shelf.py [--index INDEX] [--out LIST] [--table]

Reads each model's file in vendor/omr/files, every FILE section of it, not
only the main model's header: each section's "0 Author:" and "0 !LICENSE"
lines. A model goes on the shelf only when every section is under a licence
that lets anybody pass it on with credit (CCAL 2.0, which is CC BY 2.0, or
CC BY 4.0, as LDraw's CAreadme.txt says), all of them the same one, and
every section is by the same person (a section LDCad wrote for a flexible
part names LDCad, a program, and counts as nobody's). Anything else stops
the script, naming the file and why: nothing is guessed.

The page, the set's name, theme, year and part count are the library
index's (tools/library_build.py, INDEX: bench/results/library-2026-10-22/
library/index.json unless said), so the shelf says what the app's Library
says. Writes LIST (tools/web/gallery_seeds/ldraw_library.json unless said),
entries as src/dev/gallery_seed.gd reads them: the file, the title
("6080 King's Castle", and "LEGO® set 6080 King's Castle" in its words,
LEGO® only as an adjective and never in a title), "Brickworks"
as who shares it, the credit {by, licence, page} the file is published
with, the licence's id on the site (cc-by-2.0 or cc-by-4.0), and what its
page says. --table prints each file's sections, author and licence lines
as read, for a report.

Chosen by eye from the library's covers (gallery261, 2026-10-25): themes and
decades apart, 60 to 900 parts, every part in the app's catalogue, files
under 250 KB so a phone opens them, no licensed name (films, brands) in a
title, and no set drawn small on a long track. The kind and the tags are
said here; everything else is read.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(ROOT / "tools"))
from library_build import author_name, licence_of, with_marks  # noqa: E402

FILES = ROOT / "vendor" / "omr" / "files"
INDEX = ROOT / "bench" / "results" / "library-2026-10-22" / "library" / "index.json"
OUT = ROOT / "tools" / "web" / "gallery_seeds" / "ldraw_library.json"
SITE = {"CCAL 2.0": "cc-by-2.0", "CC BY 4.0": "cc-by-4.0"}
SAID = {"CCAL 2.0": "CC BY 2.0", "CC BY 4.0": "CC BY 4.0"}
MOST_BYTES = 250 * 1024
PROGRAMS = {"LDCad"}

# (library id, kind, tags, [yaw, pitch] for its picture or None)
# In the order the gallery shows them, newest first: themes taken in turn,
# so a page of New is not four castles and then six spaceships. Left out on
# sight of their pictures (gallery261): 374-1 Fire Station, whose flag is
# the LEGO logo (docs/TRADEMARKS.md rule 3), and 3063-1 Heartlake Flying
# Club, its seaplane hanging over the dock from the opening view.
SHELF = [
    ("omr-6080-1", "castle", ["castle", "knights", "minifigures"], None),
    ("omr-928-1", "space", ["spaceship", "base", "classic space"], None),
    ("omr-10183-1", "vehicle", ["train", "locomotive", "railway"], None),
    ("omr-5891-1", "town", ["house", "tree", "garden"], None),
    ("omr-8862-1", "vehicle", ["technic", "backhoe", "construction"], None),
    ("omr-21011-1", "architecture", ["landmark", "gate", "berlin"], None),
    ("omr-6973-1", "space", ["ice planet", "spaceship", "rover"], None),
    ("omr-6066-1", "castle", ["forest", "hideout", "minifigures"], None),
    ("omr-10124-1", "vehicle", ["aeroplane", "biplane", "history"], None),
    ("omr-6396-1", "town", ["airport", "aeroplane", "classic town"], None),
    ("omr-42022-1", "vehicle", ["technic", "hot rod", "car"], None),
    ("omr-40138-1", "vehicle", ["train", "christmas", "seasonal"], None),
    ("omr-6954-1", "space", ["spaceship", "blacktron"], None),
    ("omr-31025-1", "town", ["mountain", "hut", "waterfall"], None),
    ("omr-6085-1", "castle", ["castle", "knights", "minifigures"], None),
    ("omr-5521-1", "vehicle", ["boat", "speedboat", "model team"], None),
    ("omr-7641-1", "town", ["street", "bus", "shop"], None),
    ("omr-21016-1", "architecture", ["landmark", "gate", "seoul"], None),
    ("omr-851-1", "vehicle", ["technic", "tractor", "farm"], None),
    ("omr-358-1", "space", ["rocket", "launch pad"], None),
    ("omr-346-2", "town", ["house", "car", "garden"], None),
    ("omr-6043-1", "castle", ["dragon", "knights", "catapult"], None),
    ("omr-7815-1", "vehicle", ["train", "carriage", "railway"], None),
    ("omr-6951-1", "space", ["robot", "base", "classic space"], None),
    ("omr-40448-1", "vehicle", ["car", "vintage", "minifigures"], None),
    ("omr-6416-1", "town", ["pool", "holiday", "palm tree"], None),
    ("omr-5984-1", "space", ["spaceship", "space police"], None),
    ("omr-6361-1", "vehicle", ["crane", "truck", "classic town"], None),
    ("omr-5935-1", "vehicle", ["seaplane", "island", "adventurers"], None),
    ("omr-6365-1", "town", ["house", "cottage", "classic town"], None),
]


def sections(text: str) -> list[dict]:
    """Each FILE of an .mpd (a plain .ldr is one): its name, the author and
    licence lines it says, and whether it has any."""
    out: list[dict] = []
    for line in text.splitlines():
        words = line.strip()
        if words.startswith("0 FILE ") or not out:
            out.append({"name": words[7:].strip() if words.startswith("0 FILE ") else "", "author": None,
                        "licence": None})
            if words.startswith("0 FILE "):
                continue
        low = words.lower()
        if low.startswith("0 author:") and out[-1]["author"] is None:
            out[-1]["author"] = words[len("0 author:"):].strip()
        elif low.startswith("0 !license") and out[-1]["licence"] is None:
            out[-1]["licence"] = words[len("0 !license"):].strip()
    return out


def read(entry: dict) -> dict:
    """What a model's file says of whose it is and its licence, held to the
    rules above: a SystemExit naming the file when it fails one."""
    path = FILES / Path(entry["file"]).name
    raw = path.read_bytes()
    if len(raw) > MOST_BYTES:
        sys.exit(f"{path.name}: {len(raw) // 1024} KB, over {MOST_BYTES // 1024} KB for a phone")
    found = sections(raw.decode("utf-8", errors="replace"))
    people, licences = set(), set()
    for one in found:
        if one["licence"] is None:
            sys.exit(f"{path.name}: section {one['name']!r} says no licence")
        licence = licence_of(one["licence"])
        if not licence:
            sys.exit(f"{path.name}: section {one['name']!r} is {one['licence']!r}, not one to pass on")
        licences.add(licence)
        if one["author"] is None:
            sys.exit(f"{path.name}: section {one['name']!r} says no author")
        if author_name(one["author"]) not in PROGRAMS:
            people.add(author_name(one["author"]))
    if len(licences) != 1:
        sys.exit(f"{path.name}: sections under {sorted(licences)}, not one licence")
    if len(people) != 1:
        sys.exit(f"{path.name}: sections by {sorted(people)}, not one person")
    licence = licences.pop()
    by = people.pop()
    if by != author_name(entry["author"]) or licence != entry["licence"]:
        sys.exit(f"{path.name}: the library's index says {entry['author']!r}, {entry['licence']!r}")
    # The name alone: "Allard van Efferen (rabbitdesign.nl)" is credited
    # as Allard van Efferen, as a login in brackets is left off.
    by = re.sub(r"\s*\([^)]*\)", "", by).strip() or by
    return {"path": path, "bytes": len(raw), "sections": found, "by": by, "licence": licence}


def number(entry: dict) -> str:
    """A set's number without its -1, which every set has; a second version
    keeps its -2."""
    return re.sub(r"-1$", "", entry["set"])


def title(entry: dict) -> str:
    """"6080 King's Castle": which set it is, by its number and the name it
    was sold under. The mark is never in a title: the site refuses one that
    uses it (api/_names.js OWNED, as Rebrickable does, docs/TRADEMARKS.md
    rule 6), so its words say "LEGO® set 6080", the mark as an adjective."""
    return with_marks(f"{number(entry)} {entry['name']}")


def about(entry: dict, by: str, licence: str) -> str:
    theme = with_marks(entry["theme"].replace(" > ", ", "))
    return (f"LEGO® set {title(entry)}, from {entry['year']} ({theme}), as {by} modelled it for LDraw's Official "
            f"Model Repository. Shared here from the app's LDraw library under its "
            f"licence, {SAID[licence]}, crediting {by}. Brickworks wrote the file out again as it does any model "
            f"it shares, with build steps for its viewer and booklet.")


def main() -> None:
    ask = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ask.add_argument("--index", type=Path, default=INDEX)
    ask.add_argument("--out", type=Path, default=OUT)
    ask.add_argument("--table", action="store_true")
    args = ask.parse_args()
    library = {m["id"]: m for m in json.loads(args.index.read_text())["models"]}
    seeds, rows = [], []
    for model_id, kind, tags, turn in SHELF:
        entry = library.get(model_id)
        if entry is None:
            sys.exit(f"{model_id}: not in {args.index}")
        said = read(entry)
        seed = {"file": str(said["path"].relative_to(ROOT)), "name": title(entry), "author": "Brickworks",
                "about": about(entry, said["by"], said["licence"]),
                "tags": ["ldraw library", *tags, f"{entry['year'] // 10 * 10}s"],
                "kind": kind, "licence": SITE[said["licence"]],
                "credit": {"by": said["by"], "licence": said["licence"], "page": entry["page"]}}
        if turn:
            seed["turn"] = turn
        seeds.append(seed)
        rows.append((said, entry))
    args.out.write_text("[\n" + ",\n".join("  " + json.dumps(s, ensure_ascii=False) for s in seeds) + "\n]\n")
    print(f"{len(seeds)} models, every section of each read: {args.out.relative_to(ROOT)}")
    if args.table:
        print("\n| file | sections | author, as its header says | licence, as its header says | on the site |")
        print("|---|---|---|---|---|")
        for said, entry in rows:
            authors = sorted({one["author"] for one in said["sections"]})
            lines = sorted({one["licence"] for one in said["sections"]})
            print(f"| {said['path'].name} | {len(said['sections'])} | {'; '.join(authors)} | "
                  f"{'; '.join(lines)} | {SITE[said['licence']]} |")


if __name__ == "__main__":
    main()
