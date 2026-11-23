"""Add sets shows what it would do before it does it (lists2a, docs/LISTS.md
section 5 item 6): to add, already there, not found.

Three real files a person brings (tests/fixtures/lists/): a Rebrickable set
list export, a BrickLink wanted list's XML and set numbers typed. This
reads each one here, by Python's own csv and XML parsers and the set
catalogue the site answers from, and holds both previews to the rows it
computes: a list's (web/set_numbers.js, as the page reads the file, then
api/_mylists.js previewSets, what op=import_preview answers) and the sets
you own's (api/collection.js parseImport then asShown, what a preview: true
POST answers). And what Add then brings in is what the preview said, never
more. tools/web/lists_flow.mjs drives the same in a browser, Cancel
writing nothing.
"""

from __future__ import annotations

import csv
import io
import json
import re
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILES = ROOT / "tests/fixtures/lists"
# Already in the list, and already owned once: King's Castle.
HELD = "6080-1"


def catalogue() -> set[str]:
    raw = json.loads((ROOT / "assets/generated/set_catalog.json").read_text(encoding="utf-8"))
    return {str(row[0]).lower() for row in raw["sets"]}


def numbers(name: str) -> list[str]:
    """The set numbers in a fixture, in its order, each once, as a person
    means them: 10497 is 10497-1."""
    text = (FILES / name).read_text(encoding="utf-8")
    if name.endswith(".csv"):
        found = [row["Set Number"] for row in csv.DictReader(io.StringIO(text))]
    elif name.endswith(".xml"):
        found = [item.findtext("ITEMID") for item in ET.fromstring(text).iter("ITEM") if item.findtext("ITEMTYPE") == "S"]
    else:
        found = [word for word in re.split(r"[\s,;]+", text) if word]
    out: list[str] = []
    for one in found:
        one = (one if re.search(r"-\d+$", one) else f"{one}-1").lower()
        if one not in out:
            out.append(one)
    return out


def expected(name: str) -> dict[str, list[str]]:
    known = catalogue()
    sets = numbers(name)
    return {"matched": [s for s in sets if s in known and s != HELD],
            "already": [s for s in sets if s == HELD],
            "missing": [s for s in sets if s not in known]}


def previews() -> dict:
    script = """
      import { readFileSync } from "node:fs";
      import { kindOf, setNumbersIn } from "./web/set_numbers.js";
      import { previewSets } from "./api/_mylists.js";
      import { asShown, parseImport } from "./api/collection.js";
      const out = {};
      for (const name of ["rebrickable_sets.csv", "bricklink_wanted.xml", "set_list.txt"]) {
        const text = readFileSync(`tests/fixtures/lists/${name}`, "utf8");
        const typed = name.endsWith(".txt");
        const list = previewSets(setNumbersIn(text), new Set([HELD]));
        const body = typed ? { from: "sets", text, mode: "add" } : { from: kindOf(text), text, mode: "add" };
        const have = { there: true, sets: [{ set: HELD, qty: 1 }], parts: [], recent: [], places: {} };
        const imported = parseImport(body);
        const owned = asShown(have, imported, body);
        out[name] = { list, owned: owned.preview, kind: body.from,
          brought: owned.imported.sets.filter((s) => !s.fig).map((s) => String(s.set).toLowerCase()),
          parsed: imported.sets.filter((s) => !s.fig).length };
      }
      console.log(JSON.stringify(out));
    """.replace("HELD", json.dumps(HELD))
    said = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120, stdin=subprocess.DEVNULL)
    assert said.returncode == 0, said.stderr
    return json.loads(said.stdout.strip().splitlines()[-1])


def test_each_file_s_preview_is_the_rows_it_holds() -> None:
    said = previews()
    kinds = {"rebrickable_sets.csv": "rebrickable_csv", "bricklink_wanted.xml": "bricklink_xml", "set_list.txt": "sets"}
    for name, kind in kinds.items():
        want = expected(name)
        # Each file has some of each, or the check would prove less.
        assert want["matched"] and want["already"] == [HELD] and want["missing"], (name, want)
        got = said[name]
        assert got["kind"] == kind, (name, got["kind"])
        for group in ("matched", "already", "missing"):
            assert got["list"][group] == want[group], (name, "list", group, got["list"][group], want[group])
            assert got["owned"][group] == want[group], (name, "owned", group, got["owned"][group], want[group])
        # What Add brings into the sets you own is what the preview said to
        # add, nothing it said was there or not found (a number typed twice
        # is two copies of one set, as a file's Quantity 2 is).
        assert sorted(set(got["brought"])) == sorted(want["matched"]), (name, got["brought"])
    # The counts a person reads, by file: Rebrickable's 6 rows are 4 to add,
    # King's Castle there and 99999-1 no set; BrickLink's 4 sets (its part
    # and minifigure are not sets) 2, 1 and 1, its part a lot; the typed 6
    # numbers, 10497 twice, 3, 1 and 1.
    counts = {name: [len(said[name]["owned"][g]) for g in ("matched", "already", "missing")] for name in kinds}
    assert counts == {"rebrickable_sets.csv": [4, 1, 1], "bricklink_wanted.xml": [2, 1, 1], "set_list.txt": [3, 1, 1]}, counts
    assert said["bricklink_wanted.xml"]["owned"]["lots"] == 1


def test_a_file_saved_with_a_byte_order_mark_reads_the_same() -> None:
    # Excel's "CSV UTF-8" begins with U+FEFF: unread, the first heading is
    # lost and the file is taken for typed numbers, so a quantity of 1 would
    # be set 1-1 (a real set, Mini-Wheel Model Maker No. 1).
    text = (FILES / "rebrickable_sets.csv").read_text(encoding="utf-8")
    script = """
      import { kindOf, setNumbersIn } from "./web/set_numbers.js";
      const text = process.argv[1];
      console.log(JSON.stringify({ plain: setNumbersIn(text), marked: setNumbersIn("\\uFEFF" + text),
        kind: kindOf("\\uFEFF" + text) }));
    """
    said = subprocess.run(["node", "--input-type=module", "-e", script, text], cwd=ROOT, capture_output=True,
                          text=True, timeout=60, stdin=subprocess.DEVNULL)
    assert said.returncode == 0, said.stderr
    got = json.loads(said.stdout)
    assert got["marked"] == got["plain"] == numbers("rebrickable_sets.csv") and "1-1" not in got["marked"], got
    assert got["kind"] == "rebrickable_csv"
