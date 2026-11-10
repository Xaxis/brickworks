"""A model page's LEGO® Pick a Brick file (APP_UX7 #24, sitepickabrick):
/m/<id>/parts-pab.csv beside BrickLink's and Rebrickable's lists, made by
the real handler (api/share.js) from the design stand-in's world
(tools/web/design_stand_in.mjs), with no network.

The list is api/_parts.js pickABrick, the app's ShopLists.pick_a_brick
ported: src/dev/parts_page_probe.gd holds the two to each other word for
word. Here: the page offers it as a link a file, the route answers each file
named as the app names it, an older version its own, a model whose list is
two files (src/dev/fixtures/pickabrick_big.ldr: 432 elements, one wanted
1,005 times) two links, and the lots it leaves off, with no element number
known, are counted under the buttons, never guessed.

tools/web/model_page_flow.mjs proves the same in a browser."""

from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIG = "src/dev/fixtures/pickabrick_big.ldr"


def answers(*paths: str, model: str = "") -> list[dict] | None:
    """Each of [paths] as the server answers it: {status, html, headers};
    with [model] (a checkout path), every shared model's file is that file."""
    if shutil.which("node") is None:
        return None
    script = (
        "import { readFileSync } from 'node:fs';"
        "const s = await import('./tools/web/design_stand_in.mjs');"
        f"const model = {json.dumps(model)};"
        "if (model) s.useModelFile(readFileSync(model, 'utf8'));"
        "const out = [];"
        f"for (const path of {json.dumps(list(paths))}) {{ const r = await s.serverPage('api', path);"
        "  out.push({ status: r.status, html: r.html, headers: r.headers }); }"
        "console.log(JSON.stringify(out));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=180, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def made(model: str) -> dict:
    """What the page's own port makes of [model] (a checkout path): its
    files, lines, pieces, the lots it leaves off and those past 999."""
    script = (
        "import { readFileSync } from 'node:fs';"
        "import { inventoryOf, pickABrick } from './api/_parts.js';"
        f"const parts = inventoryOf(readFileSync({json.dumps(model)}, 'utf8'));"
        "const m = pickABrick(parts);"
        "console.log(JSON.stringify({ files: m.files, lines: m.lines, pieces: m.pieces, total: parts.pieces,"
        "  missing: m.missing.map((l) => [l.part, l.colour, l.count]), over: m.over, stand_ins: m.stand_ins,"
        "  lots: parts.lots.map((l) => [l.part, l.colour, l.count, l.element, l.stand_in ? l.stand_in.element : null]) }));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=180, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def links(html: str) -> list[tuple[str, str]]:
    """The Parts bar's Pick a Brick links: (href, words)."""
    bar = re.search(r'<div class="parts-bar">(.*?)</div>\s*(?:<p|<ul)', html, re.S)
    assert bar, "no parts bar"
    return re.findall(r'<a class="cta ghost small" href="([^"]*/parts-pab[^"]*)" download title="[^"]+">([^<]+)</a>',
                      bar.group(1))


def test_the_page_offers_the_pick_a_brick_file_beside_the_other_two_shops() -> None:
    said = answers("/m/DesignAbc1", "/m/DesignAbc1/v/1", "/de/m/DesignAbc1")
    if said is None:
        return
    newest, older, german = (one["html"] for one in said)
    assert links(newest) == [("/m/DesignAbc1/parts-pab.csv", "LEGO® Pick a Brick CSV")]
    # An older version's page offers that version's own.
    assert links(older) == [("/m/DesignAbc1/v/1/parts-pab.csv", "LEGO® Pick a Brick CSV")]
    # After BrickLink's and Rebrickable's, in that order.
    bar = re.search(r'<div class="parts-bar">.*?<ul class="lot-list"', newest, re.S).group(0)
    assert bar.index("parts.xml") < bar.index("parts.csv") < bar.index("parts-pab.csv")
    # What it is, in the page's language.
    assert 'title="A list of LEGO® element numbers to upload at LEGO® Pick a Brick"' in newest
    assert 'title="Eine Liste von LEGO® Elementnummern zum Hochladen bei LEGO® Pick a Brick"' in german
    # The three bricks all have element numbers: nothing left off, no note.
    assert 'class="note pab-note"' not in newest


def test_the_file_is_legos_template_named_as_the_app_names_it() -> None:
    said = answers("/m/DesignAbc1/parts-pab.csv", "/m/DesignAbc1/v/1/parts-pab.csv", "/m/DesignAbc1/parts-pab-2.csv",
                   "/m/DesignAbc1/parts.json")
    if said is None:
        return
    newest, older, second, listed = said
    assert newest["status"] == 200 and newest["headers"]["content-type"] == "text/csv; charset=utf-8"
    assert newest["headers"]["content-disposition"] == 'attachment; filename="riverside-watchtower-pickabrick.csv"'
    assert older["headers"]["content-disposition"] == 'attachment; filename="riverside-watchtower-v1-pickabrick.csv"'
    # elementId,quantity, \r\n between lines and none after the last, as
    # LEGO's own template (ShopLists.pick_a_brick): the stand-in's three
    # bricks, each element once.
    rows = newest["html"].split("\r\n")
    assert rows[0] == "elementId,quantity" and "\n" not in "".join(rows) and len(rows) == 4
    assert all(re.fullmatch(r"\d+,1", row) for row in rows[1:])
    assert newest["html"] == made_of_bricks()["files"][0]
    # One file: there is no second.
    assert second["status"] == 404
    # The JSON says what it leaves off, as it does for the other two.
    body = json.loads(listed["html"])
    assert body["left_out"]["pickabrick"] == 0
    assert body["pickabrick"] == {"files": 1, "lines": 3, "pieces": 3, "left_out_pieces": 0, "over": {}}


def made_of_bricks() -> dict:
    """The port's list of the stand-in's three bricks."""
    script = (
        "import { BRICKS } from './tools/web/design_stand_in.mjs';"
        "import { inventoryOf, pickABrick } from './api/_parts.js';"
        "console.log(JSON.stringify(pickABrick(inventoryOf(BRICKS))));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=180, check=True)
    return json.loads(done.stdout.strip().splitlines()[-1])


def test_past_400_elements_it_is_a_file_each_and_past_999_the_rest_is_said() -> None:
    if shutil.which("node") is None:
        return
    big = made(BIG)
    files = [text.split("\r\n") for text in big["files"]]
    # 432 elements: 400 in the first file, the rest in the second, each with
    # its header, as Pick a Brick's upload takes them.
    assert big["lines"] == 432 and [len(rows) for rows in files] == [401, 33]
    assert all(rows[0] == "elementId,quantity" for rows in files)
    lines = [row.split(",") for rows in files for row in rows[1:]]
    assert len({element for element, _ in lines}) == 432
    assert all(1 <= int(n) <= 999 for _, n in lines)
    by_element = {element: int(n) for element, n in lines}
    lots = {(part, colour): (count, element, stood) for part, colour, count, element, stood in big["lots"]}
    # 1,005 black 1 x 1 plates: 999 asked for, 6 more by hand.
    plate = lots[("3024", 0)][1]
    assert by_element[plate] == 999 and big["over"] == {plate: 6}
    # A tyre in Rubber Black is sold as a Black one: the two lots one line.
    assert lots[("3641", 256)][1] == lots[("3641", 0)][1] and by_element[lots[("3641", 0)][1]] == 8
    # A direct colour is ordered as the colour it stands in as (#B40000 as
    # Red), counted into that element's line, and said.
    red = 0x2B40000
    assert lots[("3001", red)][1] == "" and lots[("3001", red)][2] == lots[("3001", 4)][1]
    assert by_element[lots[("3001", 4)][1]] == lots[("3001", 4)][0] + 2
    assert big["stand_ins"] == ["#B40000 as Red"]
    # A brick no element number is known for, and a direct colour whose
    # stand-in has none: left off and counted, never guessed.
    assert sorted(big["missing"]) == sorted([["3001", 316, 3], ["3001", 0x2FF0000, 2]])
    assert big["pieces"] + 5 == big["total"]
    assert sum(by_element.values()) + 6 == big["pieces"]


def test_a_model_whose_list_is_two_files_offers_both_and_counts_what_is_left_off() -> None:
    said = answers("/m/DesignAbc1", "/m/DesignAbc1/parts-pab.csv", "/m/DesignAbc1/parts-pab-2.csv",
                   "/m/DesignAbc1/parts-pab-3.csv", "/m/DesignAbc1/parts.json", "/es/m/DesignAbc1", model=BIG)
    if said is None:
        return
    page, first, second, third, listed, spanish = said
    big = made(BIG)
    assert links(page["html"]) == [("/m/DesignAbc1/parts-pab.csv", "LEGO® Pick a Brick CSV, 1 of 2"),
                                   ("/m/DesignAbc1/parts-pab-2.csv", "LEGO® Pick a Brick CSV, 2 of 2")]
    assert "Pick a Brick takes 400 elements a file." in page["html"]
    assert first["html"] == big["files"][0] and second["html"] == big["files"][1]
    assert first["headers"]["content-disposition"] == 'attachment; filename="riverside-watchtower-pickabrick-1.csv"'
    assert second["headers"]["content-disposition"] == 'attachment; filename="riverside-watchtower-pickabrick-2.csv"'
    assert third["status"] == 404
    note = re.search(r'<p class="note pab-note">([^<]*)</p>', page["html"]).group(1)
    assert note == ("Not on the Pick a Brick list, with no LEGO® element number known: 2 lots (5 parts). "
                    f"Pick a Brick takes 999 of an element: add by hand 6 more of {next(iter(big['over']))}.")
    assert "Fuera de la lista de Pick a Brick, sin número de elemento LEGO® conocido: 2 lotes (5 piezas)." in spanish["html"]
    assert "LEGO® Pick a Brick CSV, 2 de 2" in spanish["html"]
    body = json.loads(listed["html"])
    assert body["left_out"]["pickabrick"] == 2
    assert body["pickabrick"] == {"files": 2, "lines": 432, "pieces": big["pieces"], "left_out_pieces": 5, "over": big["over"]}


def test_a_list_with_nothing_on_it_offers_no_file() -> None:
    """A model whose every part is made, or has no element number known,
    has no Pick a Brick list: no link, and the route says why."""
    if shutil.which("node") is None:
        return
    script = (
        "import { pickABrick } from './api/_parts.js';"
        "const lots = [{ part: 'x1', colour: 4, count: 2, element: '', custom: true, stand_in: null },"
        "  { part: '3001', colour: 316, count: 1, element: '', custom: false, stand_in: null }];"
        "const m = pickABrick({ lots });"
        "console.log(JSON.stringify({ files: m.files, lines: m.lines, pieces: m.pieces, missing: m.missing.length }));"
    )
    done = subprocess.run(["node", "--input-type=module", "-e", script], cwd=ROOT, capture_output=True, text=True,
                          timeout=60, check=True)
    assert json.loads(done.stdout) == {"files": [], "lines": 0, "pieces": 0, "missing": 2}
