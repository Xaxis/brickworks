#!/usr/bin/env python3
"""What a part looks like in a model, not what the catalogue calls it.

    tools/part_looks.py batches --out DIR [--most 600]   families to describe
    tools/describe_snippets.sh DIR                        Claude writes each a line
    tools/part_looks.py merge DIR                         -> assets/knowledge/part_looks.json
    tools/part_looks.py search "feather"

A designer wanting a feather, a claw or an exhaust does not know that
LEGO calls them "Plate 1 x 2 with Tooth", "Plate 1 x 1 with Clip" and
"Cone 1 x 1 with Stop". The catalogue's names say what a part is;
builders choose a part for what it reads as. So the parts are grouped
into families — one name with its sizes and its left and right taken
out ("Slope Brick Curved N x N") — the families real sets use most are
written up by Claude, a line each of what the family reads as in a
model, and the app's find_parts_like searches those lines
(src/ai/real_snippets.gd, the same BM25 as the real-set index).
"""

from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import snippets  # noqa: E402

CATALOGUE = ROOT / "assets" / "generated" / "catalogue.json"
OUT = ROOT / "assets" / "knowledge" / "part_looks.json"
SKIP = re.compile(r"^(minifig|sticker|duplo|znap|electric|string|hose|chain|lsynth|"
                  r"pattern|moved|~|=|_)", re.I)


def family_of(name: str) -> str:
    """A part's name with its sizes and its hand taken out."""
    key = re.sub(r"\d+(\.\d+)?\s*x\s*\d+(\.\d+)?(\s*x\s*\d+(\.\d+)?)?", "N x N", name)
    key = re.sub(r"\b\d+(\.\d+)?L\b", "NL", key)
    key = re.sub(r"\b(Left|Right)\b", "", key)
    return re.sub(r"\s+", " ", key).strip()


def families(most: int) -> list[dict]:
    """The families real sets use most, each with its commonest parts."""
    parts = json.loads(CATALOGUE.read_text())["parts"]
    grouped: dict[str, list[tuple[int, str, str]]] = defaultdict(list)
    for part in parts:
        name = part["name"]
        if part.get("moved_to") or SKIP.match(name) or SKIP.match(part.get("category", "")):
            continue
        if re.search(r"\b(pattern|print|sticker|obsolete)\b", name, re.I):
            continue
        grouped[family_of(name)].append((int(part.get("in_sets", 0) or 0), part["id"], name))
    ranked = sorted(grouped.items(), key=lambda kv: (-sum(n for n, _, _ in kv[1]), kv[0]))
    out = []
    for key, members in ranked[:most]:
        members.sort(key=lambda m: (-m[0], m[1]))
        out.append({"family": key, "used": sum(n for n, _, _ in members),
                    "parts": [[part, name] for _, part, name in members[:8]]})
    return out


def batches(out: Path, most: int, size: int) -> int:
    out.mkdir(parents=True, exist_ok=True)
    found = families(most)
    for first in range(0, len(found), size):
        group = found[first:first + size]
        name = f"batch_{first // size:04d}"
        (out / f"{name}.txt").write_text("\n".join(
            f"{n + 1}. {f['family']}  (e.g. " + "; ".join(f"{p} {nm}" for p, nm in f["parts"][:4])
            + ")" for n, f in enumerate(group)) + "\n")
        (out / f"{name}.ids").write_text("\n".join(f["family"] for f in group) + "\n")
    (out / "families.json").write_text(json.dumps(found))
    print(f"{len(found)} families in {math.ceil(len(found) / size)} batches, in {out}")
    return 0


def merge(folder: Path, out: Path) -> int:
    found = {f["family"]: f for f in json.loads((folder / "families.json").read_text())}
    said = 0
    for answer in sorted(folder.glob("batch_*.json")):
        if answer.with_suffix(".png").exists():
            continue                # a sheet of real-set pieces, tools/snippets.py's
        ids = (folder / answer.name.replace(".json", ".ids")).read_text().splitlines()
        data = json.loads(answer.read_text())
        data = data.get("structured_output", data)
        for item in data.get("items", []):
            n = int(item.get("n", 0))
            if 1 <= n <= len(ids) and ids[n - 1] in found:
                found[ids[n - 1]]["looks"] = " ".join(str(item.get("text", "")).split())
                said += 1
    rows = [f for f in found.values() if f.get("looks")]
    for row in rows:
        terms: dict[str, float] = {}
        for word in snippets.words(row["looks"]):
            terms[word] = terms.get(word, 0.0) + 2.0
        for word in snippets.words(row["family"]):
            terms[word] = terms.get(word, 0.0) + 1.0
        row["t"] = dict(terms)
        row["n"] = sum(terms.values())
    count: Counter = Counter()
    for row in rows:
        count.update(row["t"].keys())
    idf = {w: round(math.log(1 + (len(rows) - c + 0.5) / (c + 0.5)), 3) for w, c in count.items()}
    average = round(sum(r["n"] for r in rows) / max(1, len(rows)), 2)
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps({"format": 1, "about": "What each family of parts reads as "
                               "in a model, written by Claude; tools/part_looks.py.",
                               "idf": idf, "average": average, "families": rows},
                              separators=(",", ":"), ensure_ascii=False) + "\n")
    print(f"{said} families described; {out} {out.stat().st_size // 1024} KB")
    return 0


def search(query: str, limit: int = 6) -> list[dict]:
    document = json.loads(OUT.read_text())
    asked = snippets.words(query)
    scored = []
    for row in document["families"]:
        score = 0.0
        for word in asked:
            tf = row["t"].get(word, 0.0)
            if tf:
                score += document["idf"].get(word, 0.0) * tf * (snippets.K1 + 1) / (
                    tf + snippets.K1 * (1 - snippets.B + snippets.B * row["n"] / document["average"]))
        if score > 0:
            scored.append((score, row))
    scored.sort(key=lambda s: (-round(s[0], 6), s[1]["family"]))
    return [row for _, row in scored[:limit]]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    one = sub.add_parser("batches")
    one.add_argument("--out", type=Path, required=True)
    one.add_argument("--most", type=int, default=600)
    one.add_argument("--size", type=int, default=100)
    two = sub.add_parser("merge")
    two.add_argument("folder", type=Path)
    two.add_argument("--out", type=Path, default=OUT)
    three = sub.add_parser("search")
    three.add_argument("query")
    args = parser.parse_args()
    if args.command == "batches":
        return batches(args.out, args.most, args.size)
    if args.command == "merge":
        return merge(args.folder, args.out)
    for row in search(args.query):
        print(f"{row['family'][:50]:50} {row['looks'][:90]}")
        print(f"{'':50} {', '.join(p for p, _ in row['parts'][:6])}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
