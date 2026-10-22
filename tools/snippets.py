#!/usr/bin/env python3
"""Real sets' sub-assemblies, found by what they are: the designer's
technique index.

    tools/snippets.py build [--most 60]       vendor/omr/files -> the index
    tools/snippets.py search "owl eye" [--max-studs 6] [--kinds sideways]
    tools/snippets.py ldr ID [--out FILE]      one entry as a standalone .ldr
    tools/snippets.py batches --thumbs DIR --size 40 --out DIR
                                               part lists for describing
    tools/snippets.py texts DIR                merge written descriptions

An expert asked for an owl's eye does not invent one: they remember how
a set built it. LDraw's model repository (tools/omr.py fetch) has 1,400
real sets with every part placed, and most modellers split them into
named sub-models — Eye, Beak, Wing L, Bonnet, Grille, Spoiler. `build`
takes every named sub-model of 2 to --most building parts, and the
unnamed clusters of craft tools/omr.py finds round brackets, hinges and
slopes, and writes for each: the set, its modeller and licence, the part
count and size in studs, the parts and colours, its kinds by
tools/style.py, the LDraw lines to place it as built, a description
(`text`) and the weighted search terms.

Search is lexical, BM25 over fields: the sub-model's name (x3), the
names of what it sits in (x1), its description (x1.5), tags — the name's
synonyms and its kinds (x1) — and the set it came from (x0.7). A word
that names a subject ("owl", "car", "dragon") ranks sub-models from sets
about that subject first, then from sets about its kind (a bird, an
animal): SUBJECTS says which set names are about what.
Filters: --max-studs (its longest side), --kinds. The app does the same
in src/ai/real_snippets.gd, from the index this writes.

Files marked free for non-commercial use, and the few share-alike ones,
are left out: what is here is CC BY, credited wherever it is shown.

The descriptions are written offline by Claude from a thumbnail and the
part list (`batches` writes the part lists; src/dev/snippet_thumbs.gd
renders the thumbnails; tools/describe_snippets.sh runs the sessions)
into assets/knowledge/snippet_texts.jsonl.gz, which `build` reads back.
Each is kept with the parts it was written from (looked_at), and given
only to a piece that still has them: rebuilt, a piece with other parts
is in the next `batches` to be described again.
"""

from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import omr  # noqa: E402
from ldraw.parser import read_text  # noqa: E402
import style  # noqa: E402

FILES = ROOT / "vendor" / "omr" / "files"
OUT = ROOT / "assets" / "knowledge" / "snippets.json.gz"
TEXTS = ROOT / "assets" / "knowledge" / "snippet_texts.jsonl.gz"
# Whether each lays whole on its own (src/dev/snippet_verdicts.gd): a
# local cache like the thumbnails, a few minutes to make again, and made
# again after every build: it is by id, and a cluster's id can come to
# hold other parts (looked_at).
VERDICTS = ROOT / "vendor" / "omr" / "snippet_verdicts.jsonl"
# A piece that lays as it stands counts this much more in a search.
LAYS = 1.25

# Words in a sub-model's name that say nothing about what it is.
FILLER = set("the a an of and with for in on to at by set model main mpd ldr dat sub "
             "submodel subpart subassembly assembly assy part parts step steps bag new "
             "build built complete final version alt alternate copy mod modified "
             "unnamed untitled nr no".split())

# Plurals and spellings a search has to see through, the same in
# src/ai/real_snippets.gd.
IRREGULAR = {"feet": "foot", "teeth": "tooth", "leaves": "leaf", "wolves": "wolf",
             "knives": "knife", "mice": "mouse", "geese": "goose", "men": "man",
             "calves": "calf", "halves": "half", "shelves": "shelf", "hooves": "hoof",
             "grey": "gray", "colour": "color", "tyre": "tire", "tyres": "tire",
             "aeroplane": "airplane", "storey": "story", "storeys": "story"}


def stem(word: str) -> str:
    word = word.lower()
    if word in IRREGULAR:
        return IRREGULAR[word]
    if len(word) > 4 and word.endswith("ies"):
        return word[:-3] + "y"
    if len(word) > 4 and word.endswith(("ches", "shes", "sses", "xes", "zes")):
        return word[:-2]
    if len(word) > 3 and word.endswith("s") and not word.endswith(("ss", "us", "is")):
        return word[:-1]
    return word


def words(text: str) -> list[str]:
    """A name as stemmed words: "EyeL" and "eyes" are both "eye"."""
    text = re.sub(r"([a-z])([A-Z])", r"\1 \2", text)
    # One letter and a word are one name: a Y-wing is not a wing, a T-rex
    # not a rex. Not L or R, which are left and right.
    text = re.sub(r"\b([A-KM-QS-Za-km-qs-z])-([A-Za-z]{2,})", r"\1\2", text)
    text = re.sub(r"([A-Za-z])(\d)", r"\1 \2", text)
    out = []
    for word in re.findall(r"[a-z0-9]+", text.lower()):
        if word in FILLER or word.isdigit() or len(word) < 3:
            continue
        out.append(stem(word))
    return out


# Words for the same feature, any one finding the others. Stemmed.
SYNONYMS = [
    "eye eyeball pupil iris eyelid", "head face skull", "beak bill",
    "wing wingtip", "tail tailfin", "nose snout muzzle nosecone front bow prow",
    "bonnet hood", "fender mudguard wheelarch", "grille grill radiator",
    "spoiler aerofoil airfoil", "engine motor", "thruster booster afterburner exhaust nozzle jet",
    "cockpit cabin canopy", "dome cupola", "roof rooftop", "turret tower spire steeple",
    "window pane windscreen windshield", "door gate doorway entrance hatch",
    "tree treetop foliage bush shrub hedge canopy", "flower plant blossom bloom petal",
    "foot paw claw talon hoof", "leg thigh", "hand claw gripper", "horn antler",
    "mane hair fur", "light lamp headlight headlamp lantern torch",
    "wheel tire rim hub", "seat chair bench stool", "table desk",
    "fence railing rail balustrade", "stair staircase ladder", "column pillar post",
    "cannon gun blaster weapon laser turret", "antenna aerial radar",
    "fin stabiliser stabilizer", "propeller rotor prop", "rock boulder stone cliff",
    "water wave river pond", "fire flame", "jaw mouth tooth", "body torso chest",
    "bumper fender", "rear back stern", "chimney flue", "arch archway",
    "wall facade", "floor deck", "base stand plinth pedestal display", "sign signage",
    "mast", "sail", "neck", "ear", "feather plume", "scale", "spike", "crown",
]
SYNONYM_OF: dict[str, set[str]] = {}
for _group in SYNONYMS:
    _ws = [stem(w) for w in _group.split()]
    for _w in _ws:
        SYNONYM_OF.setdefault(_w, set()).update(x for x in _ws if x != _w)

# Which sets are about what, by the words in their name, theme or the
# sub-models a piece sits in. A query naming the subject ranks those
# sets' pieces first. Not "mini" (X-wing Fighter - Mini is not a car),
# "fighter" (Fire Fighter is not a spaceship) or "falcon" (the
# Millennium Falcon is not a bird).
SUBJECTS = {
    "car": "car racer roadster coupe convertible porsche ferrari lamborghini mustang "
           "camaro corvette beetle cooper bugatti mclaren aston martin fiat bmw "
           "audi mercedes jaguar jeep dodge chevrolet ford volkswagen taxi dragster "
           "kart buggy rally hotrod limousine sedan supercar hypercar",
    "truck": "truck lorry tanker tipper dumper tow pickup trailer rig",
    "bird": "bird owl parrot eagle hawk penguin toucan flamingo swan duck "
            "chicken hen rooster woodpecker hummingbird peacock macaw pelican gull "
            "seagull crow raven robin sparrow stork heron phoenix kingfisher puffin",
    "animal": "animal dog puppy cat kitten horse pony fox bear lion tiger wolf deer "
              "reindeer rabbit bunny elephant giraffe monkey gorilla panda frog snake "
              "crocodile shark whale dolphin fish octopus dinosaur dino rex raptor "
              "unicorn squirrel hedgehog koala sloth pig cow sheep goat scorpion "
              "spider bee butterfly crab turtle seal orca hippo rhino zebra camel "
              "mouse rat bat beaver otter owl parrot eagle penguin bird dragon",
    "dragon": "dragon wyvern hydra serpent",
    "dinosaur": "dinosaur dino rex raptor triceratops stegosaurus brachiosaurus pterodactyl",
    "spaceship": "space starship starfighter shuttle spaceship rocket ufo saucer "
                 "falcon destroyer x-wing tie freighter galaxy blacktron futuron spyrius "
                 "tron unitron insectoid voyager enterprise",
    "plane": "plane airplane jet aircraft airliner biplane seaplane glider airport "
             "airline bomber",
    "helicopter": "helicopter chopper copter",
    "boat": "boat ship schooner galleon yacht ferry submarine barge tug harbor harbour "
            "pirate lifeboat trawler canoe kayak",
    "train": "train locomotive loco express railway railroad steam diesel tram metro "
             "wagon carriage freight",
    "castle": "castle fortress fort citadel knight medieval kingdom keep tower "
              "drawbridge",
    "house": "house home cottage cabin villa hut lodge building modular shop store "
             "cafe restaurant hotel bakery bank townhouse",
    "robot": "robot mech droid android exo exosuit",
    "flower": "flower bouquet botanical orchid rose bonsai succulent tulip daisy plant",
    "tree": "tree forest jungle palm oak pine",
}
SUBJECT_OF: dict[str, set[str]] = {}
for _subject, _members in SUBJECTS.items():
    for _w in [_subject] + _members.split():
        for _said in words(_w):
            SUBJECT_OF.setdefault(_said, set()).add(_subject)

# Themes about one subject, top level or sub-theme.
THEME_SUBJECTS = {"Speed Champions": "car", "Racers": "car", "Ferrari": "car",
                  "Train": "train", "Trains": "train", "Space": "spaceship",
                  "Castle": "castle", "Modular Buildings": "house",
                  "Architecture": "house", "Botanicals": "flower", "Airport": "plane",
                  "Pirates": "boat", "Harbor": "boat", "Coast Guard": "boat", "Boat": "boat"}

# What a piece's kinds (tools/style.py) are called in a search and a
# filter, and the share of its parts that makes it that kind.
KINDS = {
    "sideways": (("snot",), 0.25, "sideways snot studsout"),
    "angled": (("angled", "tilted"), 0.2, "angled tilted"),
    "curved": (("curve",), 0.3, "curved round curve"),
    "sloped": (("slope",), 0.3, "sloped slope"),
    "brackets": (("snot_parts",), 0.2, "bracket"),
    "hinged": (("angle_parts",), 0.2, "hinge clip articulated"),
    "textured": (("texture",), 0.2, "texture greeble greebling"),
    "smooth": (("tile",), 0.4, "smooth tiled"),
    "organic": (("organic",), 0.3, "organic"),
}
FIELDS = {"name": 3.0, "in": 1.0, "text": 1.5, "tags": 1.0, "set": 0.7}


def _licence(said: str) -> str:
    said = said.strip()
    found = re.search(r"CCAL version (\d\.\d)|CC BY(-SA)? (\d\.\d)", said)
    if not found:
        return said
    if found.group(1):
        return f"CC BY {found.group(1)}"
    return f"CC BY{found.group(2) or ''} {found.group(3)}"


def _author(said: str) -> str:
    """"Robert Paciorek [bercik]" is Robert Paciorek; "[EdmanZA]", who
    gave only a handle, is EdmanZA."""
    name = re.sub(r"\s*\[[^\]]*\]\s*$", "", said).strip()
    return name or said.strip().strip("[]").strip() or "?"


def _files(text: str) -> tuple[list[str], dict[str, list[list[str]]], set[str]]:
    """An .mpd's files in order, each one's part and sub-model lines, and
    which of them are parts carried in the file rather than sub-models."""
    order: list[str] = []
    lines: dict[str, list[list[str]]] = {}
    carried: set[str] = set()
    current = None
    for line in text.splitlines():
        bits = line.split()
        if bits[:2] == ["0", "FILE"]:
            current = " ".join(bits[2:]).lower().replace("\\", "/")
            if current not in lines:
                order.append(current)
                lines[current] = []
        elif bits[:2] == ["0", "!LDRAW_ORG"] and current and "part" in line.lower() \
                and "subpart" not in line.lower():
            carried.add(current)
        elif len(bits) >= 15 and bits[0] == "1":
            if current is None:
                current = "<main>"
                order.append(current)
                lines[current] = []
            lines[current].append(bits)
    return order, lines, carried


def _flat(name: str, lines: dict, carried: set, m: list[float], colour: int,
          depth: int = 0) -> list[tuple[str, int, list[float]]]:
    out = []
    for bits in lines.get(name, []):
        try:
            here = omr._compose(m, [float(v) for v in bits[2:14]])
            tint = colour if bits[1] == "16" else int(bits[1], 0)
        except ValueError:
            continue
        ref = " ".join(bits[14:]).lower().replace("\\", "/")
        if ref in lines and ref not in carried and depth < 16:
            out += _flat(ref, lines, carried, here, tint, depth + 1)
        else:
            out.append((ref, tint, here))
    return out


def _square(m: list[float]) -> bool:
    """Square to the grid, and not a mirror image: a placement can say it
    as a face and a turn."""
    r = m[3:]
    turned = (r[0] * (r[4] * r[8] - r[5] * r[7]) - r[1] * (r[3] * r[8] - r[5] * r[6])
              + r[2] * (r[3] * r[7] - r[4] * r[6]))
    return turned > 0 and all(min(abs(v), abs(abs(v) - 1)) < 0.02 for v in r)


def _shown_name(name: str, number: str) -> str:
    name = re.sub(r"\.(ldr|dat|mpd)$", "", name, flags=re.I)
    name = re.sub(rf"^\s*{re.escape(number.split('-')[0])}(-\d+)?\s*[-_:.]*\s*", "", name)
    return name.strip(" -_") or name


def _standing(placed: list[tuple[str, int, list[float]]], boxes: dict) -> tuple[list[str], list[float]]:
    """LDraw lines standing on y=0, moved by whole studs from the corner of
    its widest upright brick, plate or tile so it stays on the grid it was
    built on, and the size it comes to in studs, plates and studs."""
    lo = [math.inf] * 3
    hi = [-math.inf] * 3
    anchor = None
    best = -1.0
    for ref, _, m in placed:
        box = boxes[ref]
        r = m[3:]
        (bl, bh) = box
        c = [sum(r[k * 3 + j] * (bl[j] + bh[j]) / 2 for j in range(3)) + m[k] for k in range(3)]
        h = [sum(abs(r[k * 3 + j]) * (bh[j] - bl[j]) / 2 for j in range(3)) for k in range(3)]
        for k in range(3):
            lo[k] = min(lo[k], c[k] - h[k])
            hi[k] = max(hi[k], c[k] + h[k])
        upright = abs(r[4] - 1) < 0.02
        area = (2 * h[0]) * (2 * h[2])
        if upright and area > best:
            best = area
            anchor = (c[0] - h[0], c[1] + h[1], c[2] - h[2])
    if anchor is None:
        anchor = (lo[0], hi[1], lo[2])
    dx = -anchor[0] - 20 * round((lo[0] - anchor[0]) / 20)
    dz = -anchor[2] - 20 * round((lo[2] - anchor[2]) / 20)
    # The anchor's underside on a whole plate, nothing below the ground.
    dy = -anchor[1] - 8 * math.ceil((hi[1] - anchor[1]) / 8 - 0.01)
    body = []
    for ref, colour, m in placed:
        move = [m[0] + dx, m[1] + dy, m[2] + dz]
        turn = [float(round(v)) if abs(v - round(v)) < 0.02 else round(v, 4) for v in m[3:]]
        body.append(" ".join([str(colour)] + [f"{round(v, 3) + 0.0:g}" for v in move]
                             + [f"{v + 0.0:g}" for v in turn] + [ref]))
    size = [round((hi[0] - lo[0]) / 20, 1), round((hi[1] - lo[1]) / 8, 1),
            round((hi[2] - lo[2]) / 20, 1)]
    return body, size


def _kinds(found: dict) -> list[str]:
    out = []
    for kind, (keys, least, _) in KINDS.items():
        if sum(found.get(k, 0.0) for k in keys) >= least:
            out.append(kind)
    return out


def _entry(placed, parts: style.Parts, boxes: dict) -> dict:
    body, size = _standing(placed, boxes)
    model = style.Model([style.Placed(ref.removesuffix(".dat"), colour,
                                      style.Matrix(*m[3:], *m[:3]))
                         for ref, colour, m in placed])
    found = style.measure(model, parts)
    bom = Counter((parts.canonical(ref.removesuffix(".dat")), colour) for ref, colour, _ in placed)
    return {"parts": len(placed), "size": size, "ldr": body,
            "square": all(_square(m) for _, _, m in placed),
            "kinds": _kinds(found),
            "bom": [[p, c, n] for (p, c), n in sorted(bom.items(), key=lambda kv: (-kv[1], kv[0]))]}


def _boxes(placed, parts: style.Parts) -> dict:
    """Each part's box, which every part kept has: _flat's callers keep only
    parts the catalogue gives a box."""
    out = {}
    for ref, _, _ in placed:
        info = parts.get(ref.removesuffix(".dat"))
        assert info is not None and info.box is not None, ref
        out[ref] = info.box
    return out


def _subject_words(*texts: str) -> list[str]:
    said = set()
    for text in texts:
        for word in words(text):
            said.add(word)
            said.update(SUBJECT_OF.get(word, ()))
    return sorted(said)


def build(most: int, out: Path, texts: Path, clusters_a_set: int,
          verdicts: Path = VERDICTS) -> int:
    parts = style.Parts()
    index = {r["number"]: r for r in omr._index()}
    written = {"named": 0, "cluster": 0}
    entries: list[dict] = []
    seen: dict[tuple, dict] = {}
    cluster_seen: set = set()
    skipped = Counter()
    files = sorted(FILES.glob("*"))
    for at, path in enumerate(files):
        if at % 100 == 0:
            print(f"  {at}/{len(files)} models, {len(entries)} kept", flush=True)
        text = read_text(path)
        lowered = text.lower()
        if "non-commercial" in lowered:
            skipped["non-commercial"] += 1
            continue
        top = text.splitlines()
        licence = _licence(next((l[10:] for l in top if l.startswith("0 !LICENSE")), "?"))
        if "SA" in licence:
            skipped["share-alike"] += 1
            continue
        author = _author(next((l[9:] for l in top if l.startswith("0 Author:")), "?"))
        number = path.name.split("_")[0].removesuffix(".mpd").removesuffix(".ldr")
        row = index.get(number, {"number": number, "name": path.stem, "theme": "?", "year": "0"})
        credit = {"set": number, "set_name": row["name"], "theme": row["theme"],
                  "year": int(row.get("year") or 0), "by": author, "licence": licence}
        order, lines, carried = _files(text)
        if not order:
            continue
        # Where each sub-model is used, and in what colour, from the first
        # line that places it.
        parent: dict[str, tuple[str, int]] = {}
        for name in order:
            for bits in lines[name]:
                ref = " ".join(bits[14:]).lower().replace("\\", "/")
                if ref in lines and ref not in carried and ref not in parent and ref != name:
                    parent[ref] = (name, int(bits[1], 0) if bits[1].lstrip("-").isdigit() else 16)
        stem_of = path.stem
        named_here: Counter = Counter()
        for name in order[1:]:
            if name in carried:
                continue
            chain = []
            at_name, colour = name, 16
            for _ in range(8):
                if at_name not in parent:
                    break
                at_name, tint = parent[at_name]
                if colour == 16:
                    colour = tint
                chain.append(at_name)
            colour = 71 if colour == 16 else colour
            placed = []
            unknown = False
            for ref, tint, m in _flat(name, lines, carried, [0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1], colour):
                info = parts.get(ref.removesuffix(".dat"))
                if info is None or not style.building(info):
                    continue
                if info.box is None:
                    unknown = True
                    break
                # By its current number: 3794 has moved to 3794b.
                placed.append((parts.canonical(ref.removesuffix(".dat")) + ".dat", tint, m))
            if unknown:
                skipped["a part not in the catalogue"] += 1
                continue
            if not 2 <= len(placed) <= most:
                continue
            shown = _shown_name(name, number)
            if not words(shown):
                skipped["no name"] += 1
                continue
            made = _entry(placed, parts, _boxes(placed, parts))
            signature = tuple(sorted(made["ldr"]))
            if signature in seen:
                seen[signature]["copies"] = seen[signature].get("copies", 1) + 1
                continue
            slug = re.sub(r"[^a-z0-9]+", "-", shown.lower()).strip("-")[:40] or "piece"
            key = f"{stem_of}/{slug}"
            named_here[key] += 1
            if named_here[key] > 1:
                key += f"-{named_here[key]}"
            entry = {"id": key, "kind": "named", "name": shown,
                     "in": [_shown_name(c, number) for c in chain if c != order[0]][:3],
                     **credit, **made}
            entry["subject"] = _about(entry)
            seen[signature] = entry
            entries.append(entry)
            written["named"] += 1
        # The craft nobody split out.
        if clusters_a_set:
            for kept, (score, seed, group, body) in enumerate(
                    omr.found_clusters(text, parts, clusters_a_set, "", cluster_seen), 1):
                placed = []
                for line in body:
                    bits = line.split()
                    placed.append((" ".join(bits[14:]), int(bits[1]),
                                   [float(v) for v in bits[2:14]]))
                if len(placed) > most:
                    continue
                made = _entry(placed, parts, _boxes(placed, parts))
                sub = _shown_name(seed["sub"], number)
                seed_name = style._clean(seed["name"])
                entry = {"id": f"{stem_of}/cluster-{kept}", "kind": "cluster",
                         "name": f"{seed_name.split(' ')[0].lower()} work in {sub}",
                         "seed": seed_name, "in": [sub], **credit, **made}
                entry["subject"] = _about(entry)
                entries.append(entry)
                written["cluster"] += 1

    _finish(entries, out, texts, verdicts)
    print(f"{written['named']} named sub-models and {written['cluster']} clusters "
          f"from {len(files)} models")
    for why, count in skipped.most_common():
        print(f"  left out, {why}: {count}")
    return 0


def _finish(entries: list[dict], out: Path, texts: Path, verdicts_at: Path = VERDICTS) -> None:
    """Descriptions, verdicts and search terms onto the pieces, and the index
    written. Everything that is not reading the models, so that a new
    batch of descriptions is seconds to take in (build --from)."""
    said = _texts(texts)
    verdicts = {}
    if verdicts_at.exists():
        # Read while snippet_verdicts.gd is still writing it, the last line
        # can be half a line.
        for line in verdicts_at.read_text().splitlines():
            try:
                row = json.loads(line)
            except json.JSONDecodeError:
                continue
            verdicts[row["id"]] = row
    described = 0
    for entry in entries:
        row = said.get(entry["id"])
        entry["text"] = row["text"] if row and row.get("of") == looked_at(entry) else ""
        described += bool(entry["text"])
        verdict = verdicts.get(entry["id"])
        if verdict is not None:
            entry["lays"] = bool(verdict["ok"])
            if not verdict["ok"] and verdict.get("why"):
                entry["why"] = verdict["why"]
        entry["t"] = _terms(entry)
    _weigh(entries)
    out.parent.mkdir(parents=True, exist_ok=True)
    document = {"format": 1,
                "about": "Real sets' sub-assemblies from LDraw's Official Model Repository, "
                         "each credited to its modeller under its licence. tools/snippets.py.",
                "fields": FIELDS, "synonyms": SYNONYMS,
                "subjects": {k: v.split() for k, v in SUBJECTS.items()},
                "kinds": {k: v[2] for k, v in KINDS.items()},
                "idf": _idf(entries), "average": _average(entries),
                "entries": entries}
    raw = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode()
    if out.suffix == ".gz":
        out.write_bytes(gzip.compress(raw, 9, mtime=0))
    else:
        out.write_bytes(raw)
    print(f"{len(entries)} pieces; {sum(bool(e.get('lays')) for e in entries)} lay "
          f"as they stand; {described} described; "
          f"{out} {out.stat().st_size // 1024} KB")


def _about(entry: dict) -> list[str]:
    """What a piece's set is about, and what it sits in: its subject words.

    The set's name says what it is about; a theme only where every set in
    it is about one thing. Adventurers > Dino Island made a seaplane an
    animal."""
    theme = entry["theme"]
    set_words = " ".join([entry["set_name"]] + [
        subject for name, subject in THEME_SUBJECTS.items()
        if theme.split(" > ")[0] == name or theme.endswith(name)])
    if entry["kind"] == "cluster":
        return _subject_words(set_words, *entry["in"])
    return _subject_words(set_words, *entry["in"], entry["name"])


def rebuild(source: Path, out: Path, texts: Path, verdicts: Path = VERDICTS) -> int:
    """The index again from an index: new descriptions, verdicts or search
    rules, without reading 1,500 models."""
    entries = load(source)["entries"]
    for entry in entries:
        entry.pop("lays", None)
        entry.pop("why", None)
        entry["subject"] = _about(entry)
    _finish(entries, out, texts, verdicts)
    return 0


def _terms(entry: dict) -> dict[str, float]:
    """Each word the entry can be found by, weighted by the field it is in."""
    terms: dict[str, float] = {}

    def add(found: list[str], weight: float) -> None:
        for word in found:
            terms[word] = terms.get(word, 0.0) + weight

    name = words(entry["name"]) + (words(entry.get("seed", "")) if entry["kind"] == "cluster" else [])
    add(name, FIELDS["name"])
    add([w for part in entry.get("in", []) for w in words(part)], FIELDS["in"])
    add(words(entry.get("text", "")), FIELDS["text"])
    tags = sorted({s for w in name for s in SYNONYM_OF.get(w, ())} - set(name))
    for kind in entry["kinds"]:
        tags += KINDS[kind][2].split()
    add(tags, FIELDS["tags"])
    add(entry["subject"], FIELDS["set"])
    return {k: round(v, 2) for k, v in terms.items()}


def _idf(entries: list[dict]) -> dict[str, float]:
    count: Counter = Counter()
    for entry in entries:
        count.update(entry["t"].keys())
    total = len(entries)
    return {word: round(math.log(1 + (total - n + 0.5) / (n + 0.5)), 3)
            for word, n in count.items()}


def _average(entries: list[dict]) -> float:
    return round(sum(sum(e["t"].values()) for e in entries) / max(1, len(entries)), 2)


def _weigh(entries: list[dict]) -> None:
    for entry in entries:
        entry["n"] = round(sum(entry["t"].values()), 2)


# -- search, as the app does it -------------------------------------------

K1 = 1.2
B = 0.75


def load(path: Path = OUT) -> dict:
    raw = path.read_bytes()
    return json.loads(gzip.decompress(raw) if path.suffix == ".gz" else raw)


# A word naming the subject ("bird" in "bird beak") counts this much in a
# piece's score: it has already put the subject's sets first, and within
# them the feature asked for should decide, or every piece named "bird"
# comes before the parrot's beak.
SUBJECT_WEIGHT = 0.3


def query_words(query: str, vocabulary: dict) -> list[tuple[str, float]]:
    """The query as stemmed words and their weights, with two words run
    together where the index knows them that way: "wheel arch" also asks
    for "wheelarch", which counts double, being both words at once."""
    found = words(query)
    joined = [a + b for a, b in zip(found, found[1:]) if a + b in vocabulary]
    return ([(w, SUBJECT_WEIGHT if w in SUBJECT_OF else 1.0) for w in found]
            + [(w, 2.0) for w in joined])


def search(document: dict, query: str, max_studs: float = 0.0, kinds: list[str] | None = None,
           limit: int = 5, per_set: int = 2) -> list[tuple[float, dict]]:
    idf = document["idf"]
    average = document["average"] or 1.0
    asked = query_words(query, idf)
    # The subject named, and the kinds it is of: an owl, and a bird and an
    # animal.
    named_subjects = {w for w, _ in asked if w in SUBJECT_OF}
    subjects = {s for w in named_subjects for s in SUBJECT_OF[w]}
    scored = []
    for entry in document["entries"]:
        if max_studs and max(entry["size"][0], entry["size"][2]) > max_studs:
            continue
        if kinds and not set(kinds) <= set(entry["kinds"]):
            continue
        terms = entry["t"]
        score = 0.0
        for word, weight in asked:
            tf = terms.get(word, 0.0)
            if tf:
                score += weight * idf.get(word, 0.0) * tf * (K1 + 1) / (
                    tf + K1 * (1 - B + B * entry["n"] / average))
        if score <= 0:
            continue
        if entry.get("lays"):
            score *= LAYS
        # Sets about the subject first, then sets about its kind, where
        # what was asked for is in them too: otherwise every piece of an
        # owl set would come before every other set's eye.
        tier = 0
        if any(w in terms and w not in SUBJECT_OF for w, _ in asked):
            about = set(entry["subject"])
            tier = 2 if named_subjects & about else 1 if subjects & about else 0
        scored.append((tier, score, entry))
    scored.sort(key=lambda s: (-s[0], -round(s[1], 6), s[2]["id"]))
    scored = [(score, entry) for _, score, entry in scored]
    out: list[tuple[float, dict]] = []
    taken: Counter = Counter()
    for score, entry in scored:
        if taken[entry["set"]] >= per_set:
            continue
        taken[entry["set"]] += 1
        out.append((score, entry))
        if len(out) >= limit:
            break
    return out


# -- describing them -------------------------------------------------------

COLUMNS = 6
TILE = 192


def _colour_names() -> dict[int, str]:
    path = ROOT / "assets" / "generated" / "colors.json"
    if not path.exists():
        return {}
    return {int(c["code"]): c["name"].replace("_", " ") for c in json.loads(path.read_text())}


def thumb_name(entry: dict) -> str:
    """Its picture's file name, as src/ai/real_snippets.gd file_name() has it."""
    return entry["id"].replace("/", "__").replace("'", "").replace(" ", "_")


def about(entry: dict, parts: style.Parts, colours: dict[int, str]) -> str:
    """What a describer is told besides the picture: where it is from and
    what it is made of."""
    where = " > ".join([entry["name"]] + entry.get("in", []))
    lines = [f'"{where}" in {entry["set"]} {entry["set_name"]} ({entry["theme"]}), '
             f'{entry["parts"]} parts, {entry["size"][0]:g} x {entry["size"][2]:g} studs, '
             f'{entry["size"][1]:g} plates tall'
             + (f'; mostly {", ".join(entry["kinds"])}' if entry["kinds"] else "")]
    if entry["kind"] == "cluster":
        lines.append(f"  (not a named sub-model: parts round a {entry['seed']})")
    for part, colour, count in entry["bom"][:14]:
        info = parts.get(part)
        name = info.name if info else part
        lines.append(f"  {count} x {name} ({part}), {colours.get(colour, colour)}")
    if len(entry["bom"]) > 14:
        lines.append(f"  and {len(entry['bom']) - 14} more kinds of part")
    return "\n".join(lines)


def batches(document: dict, thumbs: Path, out: Path, size: int, texts: Path) -> int:
    from PIL import Image, ImageDraw
    parts = style.Parts()
    colours = _colour_names()
    now = {e["id"]: looked_at(e) for e in document["entries"]}
    done = {k for k, row in _texts(texts).items() if row.get("of") == now.get(k)}
    # Nor any already in a batch here: run again once more pictures are
    # made, this adds batches after the ones a describing run is working
    # through.
    out.mkdir(parents=True, exist_ok=True)
    taken = sorted(out.glob("batch_*.ids"))
    for listed in taken:
        done.update(listed.read_text().split())
    start = int(taken[-1].stem.split("_")[1]) + 1 if taken else 0
    todo = [e for e in document["entries"] if e["id"] not in done
            and (thumbs / f"{thumb_name(e)}.png").exists()]
    # The likeliest to be asked for first, should a run be cut short:
    # named pieces before clusters, then newer sets, whose craft is the
    # craft of now.
    todo.sort(key=lambda e: (e["kind"] != "named", -e["year"], e["id"]))
    out.mkdir(parents=True, exist_ok=True)
    made = 0
    for first in range(0, len(todo), size):
        group = todo[first:first + size]
        name = f"batch_{start + first // size:04d}"
        rows = math.ceil(len(group) / COLUMNS)
        sheet = Image.new("RGB", (COLUMNS * TILE, rows * TILE),
                          (238, 240, 244))  # pyright: ignore[reportArgumentType]
        draw = ImageDraw.Draw(sheet)
        for n, entry in enumerate(group):
            tile = Image.open(thumbs / f"{thumb_name(entry)}.png").convert("RGB")
            at = ((n % COLUMNS) * TILE, (n // COLUMNS) * TILE)
            sheet.paste(tile.resize((TILE, TILE)), at)
            draw.rectangle([at[0], at[1], at[0] + 30, at[1] + 22], fill=(20, 20, 20))
            draw.text((at[0] + 5, at[1] + 4), str(n + 1), fill=(255, 255, 255))
            draw.rectangle([at[0], at[1], at[0] + TILE - 1, at[1] + TILE - 1],
                           outline=(170, 170, 180))
        sheet.save(out / f"{name}.png")
        (out / f"{name}.txt").write_text("\n\n".join(
            f"{n + 1}. {about(e, parts, colours)}" for n, e in enumerate(group)) + "\n")
        (out / f"{name}.ids").write_text("\n".join(e["id"] for e in group) + "\n")
        made += 1
    print(f"{len(todo)} pieces to describe in {made} batches of up to {size}, in {out}")
    return 0


def _lines(path: Path) -> list[str]:
    """A text file's lines, gzipped or not."""
    raw = path.read_bytes()
    return (gzip.decompress(raw) if path.suffix == ".gz" else raw).decode().splitlines()


def _texts(path: Path) -> dict[str, dict]:
    """The descriptions written so far, by id: {"id", "text", "of"}."""
    if not path.exists():
        return {}
    return {row["id"]: row for row in map(json.loads, filter(str.strip, _lines(path)))}


def looked_at(entry: dict) -> str:
    """What a piece's description was written from, its parts and colours,
    said short. A cluster's id is its rank in its set, so a rebuild that
    finds other parts there keeps the id: 2,413 of 3,366 did when the part
    boxes were turned the right way round, and kept describing the parts
    they no longer had. A description is the piece's only while this
    matches."""
    return hashlib.sha1(json.dumps(entry["bom"]).encode()).hexdigest()[:12]


def merge_texts(folder: Path, texts: Path, index: Path = OUT) -> int:
    """The describers' answers, numbered as their batch was, into the texts
    file, each with what it was written from (looked_at) in the index the
    batches were made from."""
    known = _texts(texts)
    now = {e["id"]: looked_at(e) for e in load(index)["entries"]}
    added = 0
    for answer in sorted(folder.glob("batch_*.json")):
        if not answer.with_suffix(".png").exists():
            continue                # a batch of part families, tools/part_looks.py's
        ids = (folder / answer.name.replace(".json", ".ids")).read_text().split()
        try:
            said = json.loads(answer.read_text())
        except json.JSONDecodeError:
            print(f"  {answer.name}: not JSON", file=sys.stderr)
            continue
        said = said.get("structured_output", said) if isinstance(said, dict) else said
        items = said.get("items", []) if isinstance(said, dict) else said
        for item in items:
            n = int(item.get("n", 0))
            text = " ".join(str(item.get("text", "")).split())
            if not (1 <= n <= len(ids) and text and ids[n - 1] in now):
                continue
            key = ids[n - 1]
            if known.get(key, {}).get("of") != now[key]:
                known[key] = {"id": key, "text": text, "of": now[key]}
                added += 1
    texts.parent.mkdir(parents=True, exist_ok=True)
    written = "".join(json.dumps(row, ensure_ascii=False) + "\n"
                      for _, row in sorted(known.items())).encode()
    texts.write_bytes(gzip.compress(written, 9, mtime=0) if texts.suffix == ".gz" else written)
    print(f"{added} descriptions added; {len(known)} in {texts}")
    return 0


def ldr(entry: dict) -> str:
    return (f"0 {entry['name']}\n0 // from {entry['set']} {entry['set_name']}, by {entry['by']}, "
            f"LDraw OMR, {entry['licence']}\n"
            + "".join(f"1 {line}\n" for line in entry["ldr"]))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("build")
    one.add_argument("--most", type=int, default=60, help="the most parts a piece may have")
    one.add_argument("--clusters", type=int, default=3, help="clusters kept a model")
    one.add_argument("--out", type=Path, default=OUT)
    one.add_argument("--texts", type=Path, default=TEXTS)
    one.add_argument("--from", dest="source", type=Path,
                     help="an index to take the pieces from, rather than the models")
    one.add_argument("--verdicts", type=Path, default=VERDICTS,
                     help="src/dev/snippet_verdicts.gd's answers for this index")
    two = sub.add_parser("search")
    two.add_argument("query")
    two.add_argument("--max-studs", type=float, default=0.0)
    two.add_argument("--kinds", default="")
    two.add_argument("--limit", type=int, default=5)
    two.add_argument("--index", type=Path, default=OUT)
    two.add_argument("--ids", action="store_true", help="only the ids, one a line")
    sub.add_parser("credits", help="who modelled what the index holds")
    three = sub.add_parser("ldr")
    three.add_argument("id")
    three.add_argument("--out", type=Path)
    three.add_argument("--index", type=Path, default=OUT)
    four = sub.add_parser("batches")
    four.add_argument("--thumbs", type=Path, default=ROOT / "vendor" / "omr" / "thumbs")
    four.add_argument("--out", type=Path, required=True)
    four.add_argument("--size", type=int, default=24)
    four.add_argument("--index", type=Path, default=OUT)
    four.add_argument("--texts", type=Path, default=TEXTS)
    five = sub.add_parser("texts")
    five.add_argument("folder", type=Path)
    five.add_argument("--texts", type=Path, default=TEXTS)
    five.add_argument("--index", type=Path, default=OUT,
                      help="the index the batches were made from")
    args = parser.parse_args()
    if args.command == "build":
        if args.source:
            return rebuild(args.source, args.out, args.texts, args.verdicts)
        return build(args.most, args.out, args.texts, args.clusters, args.verdicts)
    if args.command == "texts":
        return merge_texts(args.folder, args.texts, args.index)
    document = load(getattr(args, "index", OUT))
    if args.command == "credits":
        by: dict[str, set[str]] = {}
        licences: Counter = Counter()
        for entry in document["entries"]:
            by.setdefault(entry["by"], set()).add(entry["set"].removesuffix("-1"))
            licences[entry["licence"]] += 1
        print(f"{len(document['entries'])} pieces from "
              f"{len({e['set'] for e in document['entries']})} sets by {len(by)} modellers; "
              + ", ".join(f"{n} {lic}" for lic, n in licences.most_common()))
        for name in sorted(by, key=str.lower):
            print(f"- {name}: {', '.join(sorted(by[name]))}")
        return 0
    if args.command == "batches":
        return batches(document, args.thumbs, args.out, args.size, args.texts)
    if args.command == "search":
        kinds = [k.strip() for k in args.kinds.split(",") if k.strip()]
        found = search(document, args.query, args.max_studs, kinds, args.limit)
        if args.ids:
            print("\n".join(entry["id"] for _, entry in found))
            return 0
        for score, entry in found:
            print(f"{score:6.2f}  {entry['id']:44} {entry['name'][:28]:28} "
                  f"{entry['parts']:3}p {entry['size'][0]:g}x{entry['size'][2]:g} "
                  f"{','.join(entry['kinds'])}  [{entry['set_name'][:30]}]")
            if entry.get("text"):
                print(f"        {entry['text'][:150]}")
        return 0
    entry = next((e for e in document["entries"] if e["id"] == args.id), None)
    if entry is None:
        print(f"no entry {args.id}", file=sys.stderr)
        return 1
    if args.out:
        args.out.write_text(ldr(entry))
    else:
        print(ldr(entry), end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
