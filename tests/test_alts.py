"""Alternate builds, counted (altbuilds, 2026-11-23): which real set builds a
model, or which few sets do, by the app's own rules (api/_alts.js), and how a
model's page, a set's page and the gallery's API say it.

These drive the real code with sets of their own: api/_alts.js builds the
index the deployment packs, counts a model against it, and says what is kept;
web/card.js draws the lines; api/_directory.js reads the gallery's alt= and
from_one_set=1. tools/web/altbuilds_probe.mjs holds the count to the app's
own Collection check on real sets and models (src/dev/altbuilds_probe.gd).
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parent.parent
needs_node = pytest.mark.skipif(shutil.which("node") is None, reason="no node here")

# The catalogue's facts: 3794a and 3794b one part (a mould's letter off),
# 3005old moved to 3005, Rubber Black (256) filed as Black (0), and a sticker
# nobody owns on its own.
FACTS = {"known": ["3001", "3003", "3005", "3005old", "3020", "3023", "3794a", "3794b", "4073", "973pr1"],
         "moved": {"3005old": "3005"}, "plain": {"256": 0}}
# Six sets in two shards, and a database set that is no set.
SHARDS = [
    {"sets": {
        "1000-1": {"n": "Small house", "y": 2020, "p": [["3001", 4, 10], ["3003", 4, 6], ["3794a", 15, 4], ["3020", 1, 2]]},
        "1001-1": {"n": "Big house", "y": 2021, "p": [["3001", 4, 40], ["3003", 4, 20], ["3794b", 15, 8], ["3020", 1, 4],
                                                      ["3023", 0, 6]]},
        "2000-1": {"n": "Wheels", "y": 2019, "p": [["4073", 46, 12], ["3005", 0, 6]]},
    }},
    {"sets": {
        "2001-1": {"n": "Tiles", "y": 2019, "p": [["3023", 0, 4], ["973pr1", 1, 1]], "s": [["4073", 46, 50]]},
        "3000-1": {"n": "Grey", "y": 2018, "p": [["3001", 72, 8]]},
        "9999-1-dbase-1": {"n": "Database set", "y": 2001, "p": [["3001", 4, 999], ["4073", 46, 999], ["3005", 0, 999]]},
    }},
]


def node(script: str) -> Any:
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=120)
    assert done.returncode == 0, done.stderr
    return json.loads(done.stdout.strip().splitlines()[-1])


def counted(body: str) -> Any:
    """[body] run with the index made from SHARDS (packed and read back, as a
    deployment reads it) as `index`, and the facts as `facts`."""
    return node(
        "const a = await import('./api/_alts.js');"
        "const o = await import('./api/_owned.js');"
        f"const facts = o.useFacts({json.dumps(FACTS)});"
        f"const made = a.indexFrom({json.dumps(SHARDS)}, facts, new Set(['9999-1-dbase-1']));"
        "const index = a.unpackIndex(a.packIndex(made));"
        "const lots = (list) => o.keyed(list, facts);"
        f"console.log(JSON.stringify(await (async () => {{ {body} }})()));")


@needs_node
def test_the_index_spells_sets_as_the_gallery_spells_needs() -> None:
    said = counted(
        "return { sets: index.sets, pieces: index.pieces, keys: [...index.keys.keys()].sort(),"
        " moulds: [...index.keys.get('3794/15').at].map((at) => index.sets[at]),"
        " moved: [...index.keys.get('3005/0').at].map((at) => index.sets[at]) };")
    # The database set is no set; spares are not counted; a mould's letter off; a moved number as it is today.
    assert said["sets"] == ["1000-1", "1001-1", "2000-1", "2001-1", "3000-1"]
    assert said["pieces"] == [22, 78, 18, 5, 8]
    assert said["moulds"] == ["1000-1", "1001-1"]
    assert said["moved"] == ["2000-1"]
    assert "4073/46" in said["keys"] and "3001/4" in said["keys"]


@needs_node
def test_every_part_from_the_smallest_set_that_holds_it() -> None:
    # 8 red bricks and 2 jumpers (one 3794a, one 3794b): both houses hold all of it; the small one is said.
    said = counted(
        "const c = a.altsOf(lots([['3001', 4, 8], ['3794a', 15, 1], ['3794b', 15, 1]]), index);"
        "return { c, rows: a.countRows(lots([['3001', 4, 8], ['3794a', 15, 1], ['3794b', 15, 1]]), index).rows };")
    assert said["c"] == {"pieces": 10, "best": {"set": "1000-1", "have": 10}, "group": None, "cut": False}
    assert said["rows"] == [{"set": "1000-1", "have": 10, "role": "whole", "n": 0}]


@needs_node
def test_a_share_is_the_collection_check_part_by_part() -> None:
    # 12 red bricks: the small house has 10 of them; 2 grey plates it has; a tyre in Rubber Black (Black) it has not.
    said = counted(
        "return a.shareOf(lots([['3001', 4, 12], ['3020', 1, 2], ['4073', 256, 3]]), '1000-1', index);")
    assert said == {"set": "1000-1", "have": 12, "pieces": 17, "short": [
        {"part": "4073", "colour": 0, "need": 3, "have": 0}, {"part": "3001", "colour": 4, "need": 12, "have": 10}]}


@needs_node
def test_the_fewest_sets_that_hold_it_together() -> None:
    # Red bricks (either house), tyres (only the wheels; the tiles' are spares) and a printed tile (only the
    # tiles): no one set and no two, three together.
    said = counted(
        "const need = lots([['3001', 4, 30], ['4073', 46, 4], ['973pr1', 1, 1]]);"
        "return { c: a.altsOf(need, index), rows: a.countRows(need, index).rows };")
    assert said["c"]["best"] == {"set": "1001-1", "have": 30}
    assert said["c"]["group"] == [{"set": "1001-1", "have": 30}, {"set": "2000-1", "have": 4}, {"set": "2001-1", "have": 1}]
    assert said["rows"] == [{"set": "1001-1", "have": 30, "role": "group", "n": 1},
                            {"set": "2000-1", "have": 4, "role": "group", "n": 2},
                            {"set": "2001-1", "have": 1, "role": "group", "n": 3}]


@needs_node
def test_a_group_holds_every_part_and_none_of_its_sets_is_spare() -> None:
    said = counted(
        "const need = lots([['3001', 4, 30], ['4073', 46, 4], ['3023', 0, 2]]);"
        "return a.altsOf(need, index);")
    group = said["group"]
    assert group is not None and len(group) == 2, said
    assert {one["set"] for one in group} == {"1001-1", "2000-1"}
    # Each with what it alone holds of it, the most first.
    assert group[0] == {"set": "1001-1", "have": 32} and group[1] == {"set": "2000-1", "have": 4}


@needs_node
def test_a_part_no_set_has_means_no_group_and_no_claim() -> None:
    said = counted(
        "const need = lots([['3001', 4, 8], ['3023', 4, 1]]);"
        "return { c: a.altsOf(need, index), rows: a.countRows(need, index).rows };")
    assert said["c"]["group"] is None
    # 8 of 9 from the small house is 88%: said as its best set, never as an alternate build.
    assert said["rows"] == [{"set": "1000-1", "have": 8, "role": "best", "n": 0}]


@needs_node
def test_under_eighty_percent_nothing_is_said() -> None:
    said = counted("return a.countRows(lots([['3001', 4, 8], ['3023', 4, 4]]), index).rows;")
    assert said == []


@needs_node
def test_a_sets_own_model_is_no_alternate_of_anything() -> None:
    said = counted(
        "const need = lots([['3001', 4, 10], ['3003', 4, 6], ['3794a', 15, 4], ['3020', 1, 2]]);"
        "return { own: a.countRows(need, index, { library: { set: '1000-1', alternate_of: null } }).rows,"
        " other: a.countRows(need, index, { library: { set: '1001-1', alternate_of: '1001-1' } }).rows,"
        " declared: a.countRows(need, index, { declared: ['2000-1'] }).rows };")
    assert said["own"] == [{"set": "1000-1", "have": 22, "role": "own", "n": 0}]
    # The Library's other model of a set is that set's, and counted against every set as well.
    assert said["other"] == [{"set": "1001-1", "have": 22, "role": "library", "n": 0},
                             {"set": "1000-1", "have": 22, "role": "whole", "n": 0}]
    # A set its designer names is counted for what it holds: none of it.
    assert said["declared"] == [{"set": "1000-1", "have": 22, "role": "whole", "n": 0},
                                {"set": "2000-1", "have": 0, "role": "declared", "n": 0}]


@needs_node
def test_what_a_models_page_says() -> None:
    said = counted(
        "const rows = (list) => list.map(([set, role, have, n]) => ({ set, role, have, n: n || 0 }));"
        "return {"
        " whole: a.altSaid(rows([['1000-1', 'whole', 22]]), 22),"
        " group: a.altSaid(rows([['2000-1', 'group', 4, 2], ['1001-1', 'group', 32, 1]]), 36),"
        " best: a.altSaid(rows([['1000-1', 'best', 21]]), 22),"
        " library: a.altSaid(rows([['1001-1', 'library', 15]]), 22),"
        " own: a.altSaid(rows([['1000-1', 'own', 22]]), 22),"
        " declaredOnly: a.altSaid(rows([['2000-1', 'declared', 0]]), 22),"
        " percent: [a.percentOf(199, 200), a.percentOf(200, 200), a.percentOf(1, 3)] };")
    assert said["whole"] == {"how": "whole", "sets": [{"set": "1000-1", "have": 22}], "pieces": 22}
    assert said["group"]["how"] == "group" and [one["set"] for one in said["group"]["sets"]] == ["1001-1", "2000-1"]
    assert said["best"] == {"how": "best", "sets": [{"set": "1000-1", "have": 21}], "pieces": 22}
    assert said["library"] == {"how": "best", "sets": [{"set": "1001-1", "have": 15}], "pieces": 22}
    assert said["own"] is None and said["declaredOnly"] is None
    assert said["percent"] == [99, 100, 33]


@needs_node
def test_the_lines_as_drawn() -> None:
    said = node(
        "const c = await import('./web/card.js');"
        "const s = (set, have) => ({ set, have, name: set === '31009-1' ? 'Small Cottage' : 'Other', href: '/library/set/' + set });"
        "console.log(JSON.stringify({"
        " whole: c.altHtml({ how: 'whole', sets: [s('31009-1', 30)], pieces: 30 }),"
        " group: c.altHtml({ how: 'group', sets: [s('42115-1', 300), s('42054-1', 20), s('6111-1', 3)], pieces: 330 }),"
        " best: c.altHtml({ how: 'best', sets: [s('31009-1', 29)], pieces: 30 }),"
        " none: c.altHtml(null),"
        " version: c.altHtml({ how: 'version', sets: [{ set: '346-2', name: 'House with Car', have: 140,"
        "   href: '/library/set/346-2#versions' }], pieces: 150 }),"
        " card: [c.altCardSaid({ role: 'whole', have: 5, pieces: 5 }), c.altCardSaid({ role: 'group', have: 4, pieces: 9,"
        "   with: [{ set: '2000-1' }] }), c.altCardSaid({ role: 'best', have: 9, pieces: 10 }), c.altCardSaid(null, 'changed'),"
        "   c.altCardSaid(null, null)],"
        " short: c.basedHtml([{ how: 'alternate', set: '31009-1', name: 'Small Cottage', href: '/library/set/31009-1', short: 6 }]),"
        " share: c.basedHtml([{ how: 'alternate', set: '31009-1', name: 'Small Cottage', href: '/library/set/31009-1',"
        "   share: { have: 30, pieces: 30 } }]) }));")
    assert said["whole"] == ('<p class="from alt-build" id="alt-build" data-alt="whole">An alternate build of '
                             '<a href="/library/set/31009-1">31009 Small Cottage</a>: every part from the set</p>')
    assert said["group"] == ('<p class="from alt-build" id="alt-build" data-alt="group">An alternate build of '
                             '<a href="/library/set/42115-1">42115 Other</a>, <a href="/library/set/42054-1">42054 Other</a> and '
                             '<a href="/library/set/6111-1">6111 Other</a></p>')
    assert said["best"] == ('<p class="from alt-build" id="alt-build" data-alt="best">96% from '
                            '<a href="/library/set/31009-1">31009 Small Cottage</a></p>')
    assert said["none"] == ""
    assert said["version"] == ('<p class="from alt-build" id="alt-build" data-alt="version">A version of LEGO® set '
                               '<a href="/library/set/346-2#versions">346-2 House with Car</a></p>')
    assert said["card"] == ["Every part from this set", "44% from this set, the rest from 2000", "90% of its parts from this set",
                           "Changed from it", ""]
    assert "(uses 6 parts not in the set)" in said["short"] and 'data-short="6"' in said["short"]
    assert "set 31009-1 Small Cottage</a>: every part from the set</li>" in said["share"]


@needs_node
def test_the_gallery_asks_by_set_and_by_one_set() -> None:
    said = node(
        "const d = await import('./api/_directory.js');"
        "const ask = (q) => { try { return d.listQuery(q, 24, 100); } catch (e) { return { refused: e.message }; } };"
        "console.log(JSON.stringify([ask({ alt: '31009' }), ask({ alt: 'COMCON001-1', from_one_set: '1' }),"
        " ask({ alt: '31009 1' }), ask({ from_one_set: 'maybe' })]));")
    assert said[0]["asked"]["alt"] == "31009-1" and said[0]["said"]["alt"] == "31009-1"
    assert said[1]["asked"]["alt"] == "comcon001-1" and said[1]["asked"]["one_set"] is True
    assert said[1]["said"]["from_one_set"] is True
    assert said[2] == {"refused": "alt is a set's number, as on its box, like 31009-1"}
    assert said[3] == {"refused": "from_one_set is 1 or left out"}


@needs_node
def test_a_search_with_no_group_in_reach_is_given_up_and_said() -> None:
    # Nothing to find, and searched with a budget of one set: cut, and no claim.
    said = counted("return a.altsOf(lots([['3001', 4, 45], ['4073', 46, 1], ['3023', 0, 9]]), index, { mostTried: 1 });")
    assert said["group"] is None and said["cut"] is True
