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
SETS = ROOT / "assets" / "generated" / "sets"

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


def _in_ldraw(counted: Counter, index: dict) -> Counter:
    colours = {int(k): v for k, v in index["colours"].items()}
    out: Counter = Counter()
    for (part, colour), quantity in counted.items():
        if colour in colours:
            out[(index["parts"].get(part, part), colours[colour])] += quantity
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


def test_a_bricklink_colour_reads_back_as_the_ldraw_one_exported() -> None:
    # The wanted-list export writes LDraw 4 (red) as BrickLink 5 and 71
    # (light bluish grey) as 86; the import must read them back the same.
    index = json.loads((SETS / "index.json").read_text())
    assert index["bricklink_colours"]["5"] == 4
    assert index["bricklink_colours"]["86"] == 71
    assert index["bricklink_colours"]["11"] == 0
