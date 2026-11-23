"""What a remix changed, as the site counts it and says it (api/_remix_changes.js,
api/_remix.js; remixdiff, 2026-11-23).

The twelve pairs in tests/fixtures/remix_pairs/ (make_pairs.py) counted as
the app's Compare counts them: src/dev/compare_probe.gd holds the app to
expected.json on the same files, so the two are held to each other. And the
line a remix's page says, which version of the original it is counted
against, the runs the 3D view lights, and the Remixes tab's tree both ways.
"""

from __future__ import annotations

import json
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
PAIRS = ROOT / "tests/fixtures/remix_pairs"
CATALOGUE = ROOT / "assets/generated/catalogue.json"
ready = pytest.mark.skipif(shutil.which("node") is None or not CATALOGUE.exists(),
                           reason="needs node and the catalogue (assets/generated/catalogue.json)")
has_node = pytest.mark.skipif(shutil.which("node") is None, reason="needs node")


def node(script: str):
    run = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                         timeout=300, stdin=subprocess.DEVNULL)
    assert run.returncode == 0, run.stderr[-2000:]
    return json.loads(run.stdout)


@ready
def test_the_twelve_pairs_count_as_the_app_counts_them():
    got = node(f"""
import {{ readFileSync, readdirSync }} from "node:fs";
import {{ remixChanges }} from "./api/_remix_changes.js";
import {{ useCurrent }} from "./api/_parts.js";
const dir = {json.dumps(str(PAIRS))};
useCurrent(JSON.parse(readFileSync(`${{dir}}/part_current.json`, "utf8")).parts);
const out = {{}};
for (const f of readdirSync(dir).filter((f) => f.endsWith(".was.ldr")).sort()) {{
  const name = f.replace(".was.ldr", "");
  const r = remixChanges(readFileSync(`${{dir}}/${{f}}`, "utf8"), readFileSync(`${{dir}}/${{name}}.now.ldr`, "utf8"));
  const lit = [...r.shown.added, ...r.shown.recoloured, ...r.shown.moved].reduce((n, [, length]) => n + length, 0);
  out[name] = {{ ...r.counts, turned: r.turned, parts_was: r.parts_was, parts_now: r.parts_now,
    lit, ghosts: r.shown.ghosts, ghost_parts: r.shown.ghost ? r.shown.ghost.count : 0, count: r.shown.count }};
}}
console.log(JSON.stringify(out));
""")
    expected = json.loads((PAIRS / "expected.json").read_text())
    assert sorted(got) == sorted(expected) and len(expected) == 12
    for name, want in expected.items():
        mine = got[name]
        assert {key: mine[key] for key in want} == want, name
        # The 3D view lights each part it changed and ghosts each it took away.
        assert mine["lit"] == want["added"] + want["recoloured"] + want["moved"], name
        assert mine["ghosts"] == want["removed"] == mine["ghost_parts"], name
        assert mine["count"] == want["parts_now"], name


@ready
def test_the_files_as_written_are_the_files_make_pairs_writes():
    import importlib.util
    spec = importlib.util.spec_from_file_location("make_pairs", PAIRS / "make_pairs.py")
    made = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(made)
    for name, (was, now) in made.pairs().items():
        assert (PAIRS / f"{name}.was.ldr").read_text() == was, name
        assert (PAIRS / f"{name}.now.ldr").read_text() == now, name


@has_node
def test_the_line_says_each_change_in_order_and_none_as_none():
    said = node("""
import { changeLine } from "./api/_remix_changes.js";
console.log(JSON.stringify([
  changeLine({ added: 42, removed: 8, recoloured: 3, moved: 5 }),
  changeLine({ added: 0, removed: 1, recoloured: 0, moved: 2 }),
  changeLine({ added: 1, removed: 0, recoloured: 0, moved: 0 }),
  changeLine({ added: 0, removed: 0, recoloured: 0, moved: 0 }),
  changeLine(null),
  changeLine({ added: -1, removed: 0, recoloured: 0, moved: 0 }),
]));
""")
    assert said == ["42 parts added, 8 taken away, 3 recoloured, 5 moved", "1 part taken away, 2 moved",
                    "1 part added", "no parts changed", "", ""]


@has_node
def test_runs_hold_the_indexes_and_no_more_than_asked():
    got = node("""
import { runsOf, fromRuns } from "./api/_remix_changes.js";
const runs = runsOf([9, 1, 2, 3, 7, 8, 3]);
console.log(JSON.stringify({ runs, back: fromRuns(runs), most: fromRuns(runs, 4), bad: fromRuns([[1, -2], ["x", 3], [5, 1]]) }));
""")
    assert got["runs"] == [[1, 3], [7, 3]]
    assert got["back"] == [1, 2, 3, 7, 8, 9]
    assert got["most"] == [1, 2, 3, 7]
    assert got["bad"] == [5]


@has_node
def test_which_version_of_the_original_it_is_counted_against():
    got = node("""
import { againstOf } from "./api/_remix.js";
const versions = [{ n: 3, at: "2026-10-20T00:00:00Z" }, { n: 2, at: "2026-10-10T00:00:00Z" }, { n: 1, at: "2026-10-01T00:00:00Z" }];
console.log(JSON.stringify([
  againstOf(2, versions, "2026-10-25T00:00:00Z"),      // as its app said
  againstOf(7, versions, "2026-10-15T00:00:00Z"),      // said one the original no longer has: the newest then
  againstOf(null, versions, "2026-10-15T00:00:00Z"),   // not said: the newest when it was first shared
  againstOf(null, versions, "2026-09-01T00:00:00Z"),   // shared before any: the first
  againstOf(null, [], null),                           // nothing kept: its version 1
]));
""")
    assert got == [{"n": 2, "inferred": False}, {"n": 2, "inferred": True}, {"n": 2, "inferred": True},
                   {"n": 1, "inferred": True}, {"n": 1, "inferred": True}]


# A chain of three remixes: Lighthouse (the first) <- Harbour <- Quay (the
# page's) <- Pier <- Jetty, and Dock beside Pier; and one by link above all.
CHANGES = {"added": 4, "removed": 1, "moved": 0, "recoloured": 2, "turned": 0, "n": 1, "against_n": 1}
TREE = {
    "changes": {**CHANGES, "against": "Harbour001"},
    "up": [{"id": "Harbour001", "name": "Harbour", "author": "Ann", "depth": 1, "has_image": True, "has_thumb": True,
            "updated_at": "2026-10-01T00:00:00Z", "changes": {**CHANGES, "added": 9, "against": "Lighthse01"},
            "from": {"id": "Lighthse01", "name": "Lighthouse", "author": "Bo"}},
           {"id": "Lighthse01", "name": "Lighthouse", "author": "Bo", "depth": 2, "has_image": True, "has_thumb": False,
            "updated_at": "2026-09-01T00:00:00Z", "changes": None, "from": {"id": None, "by_link": True}},
           {"id": None, "by_link": True, "depth": 3}],
    "down": [{"id": "PierModel1", "name": "Pier", "author": "Cy", "parent": "QuayModel1", "depth": 1, "has_image": True,
              "has_thumb": True, "updated_at": "2026-11-01T00:00:00Z", "changes": {**CHANGES, "moved": 5}},
             {"id": "DockModel1", "name": "Dock", "author": None, "parent": "QuayModel1", "depth": 1, "has_image": False,
              "has_thumb": False, "updated_at": "2026-11-02T00:00:00Z", "changes": None},
             {"id": "JettyMod01", "name": "Jetty", "author": "Di", "parent": "PierModel1", "depth": 2, "has_image": True,
              "has_thumb": True, "updated_at": "2026-11-03T00:00:00Z", "changes": {**CHANGES, "removed": 3}}],
}
OWN = {"id": "QuayModel1", "name": "Quay", "author": "Eve", "has_image": True, "has_thumb": True,
       "updated_at": "2026-10-15T00:00:00Z"}


def tree_of(tree):
    return node(f"""
import {{ treeHtml }} from "./api/_remix.js";
console.log(JSON.stringify(treeHtml("https://brickworks.diy", "", {json.dumps(tree)}, {json.dumps(OWN)})));
""")


@has_node
def test_the_tree_is_drawn_both_ways_each_with_its_line():
    html = tree_of(TREE)
    # Up to the first, then the page's own, then three levels down, nested in
    # that order: each a list inside the one above it.
    order = ["A model shared by link", ">Lighthouse<", ">Harbour<", ">Quay<", ">Pier<", ">Jetty<", ">Dock<"]
    at = [html.index(word) for word in order]
    assert at == sorted(at), html
    assert html.count("<ol") == 6 and html.count("</ol>") == 6
    # The page's own, marked; every other listed one a link to its page.
    assert '<div class="node-card self" aria-current="page">' in html and "This model" in html
    for one in ("Harbour001", "Lighthse01", "PierModel1", "JettyMod01", "DockModel1"):
        assert f'href="/m/{one}"' in html, one
    assert 'href="/m/QuayModel1"' not in html
    # Each card its line; a remix of a remix names both.
    assert "A remix of Lighthouse by Bo, itself a remix of a model shared by link: 9 parts added, 1 taken away, 2 recoloured" in html
    assert "A remix of Harbour by Ann, itself a remix of Lighthouse: 4 parts added, 1 taken away, 2 recoloured" in html
    assert "A remix of Quay by Eve, itself a remix of Harbour: 4 parts added, 1 taken away, 2 recoloured, 5 moved" in html
    assert "A remix of Pier by Cy, itself a remix of Quay: 4 parts added, 3 taken away, 2 recoloured" in html
    assert ">A remix of Quay by Eve, itself a remix of Harbour</span>" in html   # Dock: not counted yet, no line
    assert "A remix of a model shared by link</span>" in html                   # Lighthouse's own
    # Dock has no picture: a space for one, the same size.
    assert html.count('<span class="no-picture" aria-hidden="true"></span>') == 2


@has_node
def test_a_tree_with_nothing_either_way_is_not_drawn_and_one_way_is():
    assert tree_of({"changes": None, "up": [], "down": []}) == ""
    only_down = tree_of({**TREE, "up": []})
    assert only_down.index(">Quay<") < only_down.index(">Pier<") < only_down.index(">Jetty<")
    assert "Lighthouse" not in only_down
    only_up = tree_of({**TREE, "down": []})
    assert ">Pier<" not in only_up and only_up.index(">Harbour<") < only_up.index(">Quay<")


@has_node
def test_a_blocked_maker_takes_their_remix_and_what_hangs_under_it():
    got = node(f"""
import {{ treeWithout }} from "./api/_remix.js";
const tree = {json.dumps(TREE)};
console.log(JSON.stringify(treeWithout(tree, new Set(["PierModel1"]), new Set()).down.map((one) => one.id)));
""")
    assert got == ["DockModel1"]


def published(*flags: str) -> dict:
    run = subprocess.run(["node", str(PAIRS / "publish.mjs"), "--n=1", *flags], cwd=ROOT, capture_output=True, text=True,
                         timeout=300, stdin=subprocess.DEVNULL)
    assert run.returncode == 0, run.stderr[-2000:]
    return json.loads(run.stdout)


@ready
def test_a_remix_published_is_counted_once_after_its_answer():
    # Through the real publish (api/share.js), as the app publishes a copy.
    got = published("--pair=09_mix_move_turn_recolour")
    run = got["runs"][0]
    assert run["status"] == 201 and run["threw"] is None and not got["troubles"], got
    want = json.loads((PAIRS / "expected.json").read_text())["09_mix_move_turn_recolour"]
    row = run["kept"]
    assert {key: row[key] for key in want} == want
    assert row["against"] == "CottageA01" and row["against_n"] == 1 and row["inferred"] is False and row["n"] == 1
    # Begun only once the answer was written: none of its reads before it.
    assert run["count_reads"] == 2 and run["reads_before_answer"] == 0 and run["counted_after_answer"] > 0
    # A model that is no remix counts nothing.
    plain = published("--plain")
    assert plain["runs"][0]["status"] == 201 and plain["kept"] == 0 and plain["runs"][0]["count_reads"] == 0
