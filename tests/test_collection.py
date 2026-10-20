"""What a set expands to, checked against Rebrickable's raw tables.

tools/collection_data.py writes what is in every set for "My collection"
(src/collection/). Its expansion is checked here by doing the same sum a
different way: straight off the downloaded CSVs for one set at a time, with
no shards, no renames and no sorting — the set's own first inventory, its
minifigures' parts, spares apart. The written shard must say the same.

Skipped where the Rebrickable tables or the written shards are not on this
machine (tools/fetch_data.sh, tools/collection_data.py).
"""

from __future__ import annotations

import csv
import gzip
import io
import json
import sys
from collections import Counter
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import collection_data  # noqa: E402

VENDOR = ROOT / "vendor" / "rebrickable"
GENERATED = ROOT / "assets" / "generated"
SETS = GENERATED / "sets"

pytestmark = pytest.mark.skipif(
    not (VENDOR / "inventory_minifigs.csv.gz").exists() or not (SETS / "index.json").exists(),
    reason="Rebrickable tables or set shards not present; run tools/fetch_data.sh "
           "and tools/collection_data.py",
)


def _table(name: str) -> list[dict[str, str]]:
    with gzip.open(VENDOR / f"{name}.csv.gz", "rb") as raw:
        return list(csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8", newline="")))


def _straight(set_num: str) -> tuple[Counter, Counter]:
    """The set's parts and spares in Rebrickable's numbers, by (part, colour)."""
    inventories = _table("inventories")
    first: dict[str, str] = {}
    for row in sorted(inventories, key=lambda r: int(r["version"] or 1)):
        first.setdefault(row["set_num"], row["id"])
    wanted = {first[set_num]}
    figures = [(first[r["fig_num"]], int(r["quantity"])) for r in _table("inventory_minifigs")
               if r["inventory_id"] == first[set_num] and r["fig_num"] in first]
    times = {first[set_num]: 1}
    for inventory, quantity in figures:
        wanted.add(inventory)
        times[inventory] = times.get(inventory, 0) + quantity
    kept: Counter = Counter()
    spare: Counter = Counter()
    for row in _table("inventory_parts"):
        if row["inventory_id"] in wanted:
            into = spare if row["is_spare"] == "True" else kept
            into[(row["part_num"].lower(), int(row["color_id"]))] += \
                int(row["quantity"]) * times[row["inventory_id"]]
    return kept, spare


def _written(set_num: str) -> dict:
    shard = json.loads((SETS / f"{collection_data.shard_of(set_num):03d}.json").read_text())
    return shard["sets"][set_num]


def _figures():
    """collection_data's reading of a figure assembly's name, over the raw tables."""
    colours = json.loads((GENERATED / "colors.json").read_text())
    return collection_data._figure_parts(
        {r["part_num"].lower(): r["name"] for r in _table("parts")},
        {r["name"].strip().lower().replace("gray", "grey"): int(r["id"]) for r in _table("colors")},
        collection_data.rb.colour_codes(colours))


def _in_ldraw(counted: Counter, index: dict) -> Counter:
    colours = {int(k): v for k, v in index["colours"].items()}
    figure = _figures()
    out: Counter = Counter()
    for (part, colour), quantity in counted.items():
        if colour in colours:
            drawn = None if part in index["parts"] else figure(part, colours[colour])
            for one, code in drawn or [(index["parts"].get(part, part), colours[colour])]:
                out[(one, code)] += quantity
    return out


def test_the_shard_rule_is_the_apps() -> None:
    # The same numbers src/dev/collection_probe.gd asks SetInventories for.
    assert collection_data.shard_of("10237-1") == 244
    assert collection_data.shard_of("6020-1") == 183
    assert collection_data.shard_of(" 75192-1 ") == 184


@pytest.mark.parametrize("set_num", ["6020-1", "10237-1", "3931-1"])
def test_a_set_expands_to_its_inventory_and_its_minifigures(set_num: str) -> None:
    index = json.loads((SETS / "index.json").read_text())
    kept, spare = _straight(set_num)
    record = _written(set_num)
    assert Counter({(p, c): q for p, c, q in record["p"]}) == _in_ldraw(kept, index)
    assert Counter({(p, c): q for p, c, q in record.get("s", [])}) == _in_ldraw(spare, index)


def test_a_rebrickable_number_ldraw_names_is_ldraws() -> None:
    # Each LDraw file below says "Rebrickable <number>" in its header: a
    # print Rebrickable numbers pr0001 and LDraw p01, a torso Rebrickable
    # lists with its arms and hands (LDraw's shortcut places all five), and
    # a mould the two number apart. Before, all three kept Rebrickable's
    # number, and a set holding them held parts no model is drawn with.
    parts = json.loads((SETS / "index.json").read_text())["parts"]
    assert parts["3626apr0001"] == "3626ap01"
    assert parts["973c28h01pr0040"] == "76382p0003"
    assert parts["32005a"] == "2739a"


def test_a_figure_rebrickable_lists_whole_is_written_as_its_parts() -> None:
    # The Siege Tower's soldiers: "Hips and Blue Legs" in Black, and plain
    # torsos with their arms and hands, as LDraw draws a figure.
    figure = _figures()
    assert figure("970c28", 0) == [("3815b", 0), ("3816c", 1), ("3817c", 1)]
    assert figure("973c03h01", 4) == [("973", 4), ("3818", 0), ("3819", 0), ("3820", 14), ("3820", 14)]
    printed = figure("973c01h01pr0090", 15)
    assert printed is not None and printed[0] == ("973c01h01pr0090", 15) and printed[3] == ("3820", 14)
    assert figure("3001", 4) is None
    record = _written("6061-1")
    assert ["970c28", 0, 4] not in record["p"] and ["3816c", 1, 4] in record["p"]


def test_a_bricklink_colour_reads_back_as_the_ldraw_one_exported() -> None:
    # The wanted-list export writes LDraw 4 (red) as BrickLink 5 and 71
    # (light bluish grey) as 86; the import must read them back the same.
    index = json.loads((SETS / "index.json").read_text())
    assert index["bricklink_colours"]["5"] == 4
    assert index["bricklink_colours"]["86"] == 71
    assert index["bricklink_colours"]["11"] == 0
    # Colours the hand-made table had no number for; Pearl Dark Grey's
    # number, which Titanium shares; and the two it had wrong: Trans-Light
    # Blue is LDraw 43, not 41, and Flat Silver is 315, not 179.
    assert index["bricklink_colours"]["9"] == 7
    assert index["bricklink_colours"]["10"] == 8
    assert index["bricklink_colours"]["77"] == 148
    assert index["bricklink_colours"]["15"] == 43
    assert index["bricklink_colours"]["74"] == 41
    assert index["bricklink_colours"]["95"] == 315


def _colours() -> dict[int, dict]:
    return {c["code"]: c for c in json.loads((GENERATED / "colors.json").read_text())}


def _plain(code: int, colours: dict[int, dict]) -> int:
    return colours[code].get("plain_code", code) if code in colours else code


def test_every_colour_the_examples_use_has_a_bricklink_number() -> None:
    # A lot without one is left off the wanted list: the example car lost
    # 5 of its 26 to Light Grey and Trans Very Light Blue.
    colours = _colours()
    used: set[int] = set()
    for path in sorted((ROOT / "models").glob("*.ldr")):
        for line in path.read_text(errors="replace").splitlines():
            bits = line.split()
            if len(bits) >= 15 and bits[0] == "1" and bits[1] not in ("16", "24"):
                used.add(_plain(int(bits[1]), colours))
    assert len(used) >= 25
    assert sorted(code for code in used if "bricklink" not in colours.get(code, {})) == []


def test_the_thirty_commonest_colours_in_sets_have_bricklink_numbers() -> None:
    colours = _colours()
    pieces: Counter = Counter()
    for shard in sorted(SETS.glob("[0-9]*.json")):
        for record in json.loads(shard.read_text())["sets"].values():
            for _part, colour, quantity in record["p"] + record.get("s", []):
                pieces[_plain(int(colour), colours)] += quantity
    commonest = [code for code, _n in pieces.most_common(30)]
    assert [code for code in commonest if "bricklink" not in colours.get(code, {})] == []


def test_colors_json_carries_the_table_and_nothing_else() -> None:
    # Every number written is the table's, on a plastic colour LDConfig
    # has, and nothing held back was written.
    from bricklink_colours import HELD_BACK, NUMBERS
    colours = _colours()
    written = {code: c["bricklink"] for code, c in colours.items() if "bricklink" in c}
    assert written == NUMBERS
    assert all(colours[code]["group"] not in ("internal common material", "obsolete")
               for code in written)
    assert not set(HELD_BACK) & set(written)
    # The owner's call on the two old pairs the sources contradicted:
    # Trans Medium Blue is BrickLink's Trans-Medium Blue, and Pearl Silver
    # has no number, since 95 Flat Silver is LDraw 315.
    assert written[41] == 74
    assert written[43] == 15
    assert 179 not in written and 179 in HELD_BACK
    assert written[315] == 95
