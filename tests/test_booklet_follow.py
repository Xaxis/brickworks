"""The booklet builder's measure (tools/bench/booklet_follow.py) and its one server
(tools/bench/booklet_mcp.py).

The measure says how many of a model's parts a builder put right from the booklet's
pages alone: a scorer that calls a wrong part right, or charges a page with another
page's part, would make every number of ROADMAP item 7 wrong. So each kind is pinned
on a build whose answer is known, and the server is pinned to hand a builder the pages
and its hands, never the model.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools" / "bench"))
sys.path.insert(0, str(ROOT / "tools"))

import booklet_follow as bf  # noqa: E402
import booklet_mcp  # noqa: E402

# Boxes in LDraw's axes (y down): a 2 x 4 brick, a 2 x 2 slope that falls toward -z
# from its high back, and a 1 x 2 plate.
BOUNDS = bf.Bounds({
    "3001": ([-40.0, -4.0, -20.0], [40.0, 24.0, 20.0]),
    "3039": ([-20.0, -4.0, -30.0], [20.0, 24.0, 10.0]),
    "3023": ([-20.0, -4.0, -10.0], [20.0, 8.0, 10.0]),
})
ONE = [1, 0, 0, 0, 1, 0, 0, 0, 1]
HALF = [-1, 0, 0, 0, 1, 0, 0, 0, -1]   # half round the vertical


def brick(part: str, colour: int, x: float, y: float, z: float, turn=ONE) -> bf.Placed:
    return bf.Placed(part, colour, [x, y, z, *turn])


def moved(parts: list[bf.Placed], yaw: int, by: list[float]) -> list[bf.Placed]:
    """The same build, turned about the vertical and moved: where a builder starts."""
    turn = bf.YAWS[yaw]
    return [bf.Placed(p.part, p.colour, bf._add(bf._apply(turn, p.at), by) +
                      bf._mul(turn, p.turn)) for p in parts]


MODEL = [
    brick("3001", 4, 0, 0, 0),        # 0
    brick("3001", 4, 0, -24, 0),      # 1
    brick("3001", 1, 80, 0, 0),       # 2
    brick("3039", 15, 0, -48, 0),     # 3
    brick("3023", 14, 80, -24, 0),    # 4
    brick("3023", 14, 120, -24, 0),   # 5
]


def kinds(result: dict) -> dict[int, str]:
    return {i: got["kind"] for i, got in result["parts"].items()}


def test_a_build_turned_and_moved_is_all_right():
    result = bf.compare(MODEL, moved(MODEL, 90, [300, -16, -140]), BOUNDS)
    assert set(kinds(result).values()) == {"right"}
    assert result["extra"] == []


def test_each_kind_of_wrong():
    build = moved(MODEL, 180, [40, 0, 60])
    build[1] = bf.Placed("3001", 4, bf._add(build[1].at, [0, 0, -20]) + build[1].turn)  # a stud
    build[2] = bf.Placed("3001", 14, build[2].at + build[2].turn)                       # colour
    build[4] = bf.Placed("3001", 14, build[4].at + build[4].turn)                       # part
    del build[5]                                                                       # missing
    build.append(bf.Placed("3023", 2, [999, 0, 999, *ONE]))                            # extra
    result = bf.compare(MODEL, build, BOUNDS)
    assert kinds(result) == {0: "right", 1: "place", 2: "colour", 3: "right", 4: "part",
                             5: "missing"}
    # One stud deep in the model's own frame, whichever way the build stood.
    assert result["parts"][1]["off"] == [0.0, 0.0, 1.0]
    assert result["parts"][2]["was"] == 14
    assert [e["part"] for e in result["extra"]] == ["3023"]


def test_a_part_turned_on_its_own_symmetry_is_right_and_a_slope_is_not():
    # The 2 x 4 brick half round fills the same space: right, said "turned".
    build = list(MODEL)
    build[0] = brick("3001", 4, 0, 0, 0, HALF)
    result = bf.compare(MODEL, build, BOUNDS)
    assert result["parts"][0] == {"kind": "right", "turned": True, "by": 0}
    # The slope half round falls the other way: its box is a stud off, so not right.
    build = list(MODEL)
    build[3] = brick("3039", 15, 0, -48, 0, HALF)
    assert kinds(bf.compare(MODEL, build, BOUNDS))[3] == "place"


def test_letters_of_one_mould_are_one_part():
    build = list(MODEL)
    build[4] = brick("3023b", 14, 80, -24, 0)
    assert kinds(bf.compare(MODEL, build, BOUNDS))[4] == "right"


def test_parts_built_before_the_stretch_are_not_judged_and_keep_their_place():
    # Parts 0-2 were the seed. The builder put the yellow plate where the seed's
    # blue brick was not, and nothing where part 4 goes, so part 5's plate stands in
    # part 4's place: one is right, one is missing, never two right.
    build = [MODEL[0], MODEL[1], MODEL[2], MODEL[3], brick("3023", 14, 80, -24, 0)]
    result = bf.compare(MODEL, build, BOUNDS, judged={3, 4, 5})
    assert sorted(result["parts"]) == [3, 4, 5]
    assert sorted(k for k in kinds(result).values()) == ["missing", "right", "right"]
    assert result["earlier_lost"] == 0
    result = bf.compare(MODEL, build[1:], BOUNDS, judged={3, 4, 5})
    assert result["earlier_lost"] == 1


def test_read_ldraw_places_sub_models_and_their_colour():
    text = "\n".join([
        "0 FILE main.ldr", "1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat",
        "1 16 100 -24 0 0 0 1 0 1 0 -1 0 0 wing.ldr", "0 NOFILE",
        "0 FILE wing.ldr", "1 16 20 0 0 1 0 0 0 1 0 0 0 1 3023.DAT",
        "1 2 0 -8 0 1 0 0 0 1 0 0 0 1 3039.dat", "0 NOFILE"])
    parts = bf.read_ldraw(text)
    assert [(p.part, p.colour) for p in parts] == [("3001", 4), ("3023", 16), ("3039", 2)]
    # The wing turned a quarter round: its +x is the model's -z.
    assert parts[1].at == [100.0, -24.0, -20.0]
    assert parts[2].at == [100.0, -32.0, 0.0]


def truth() -> bf.Truth:
    """Four steps on three pages, the third step a callout of two copies built on a
    page of its own and put on by the fourth."""
    bricks = {str(n): {"part": "3001", "colour": 4, "ldraw": [0, -24 * n, 0, *ONE]}
              for n in range(1, 8)}
    return bf.Truth({
        "model": "m.ldr", "title": "M",
        "pages": [{"number": 1, "kind": "cover", "steps": []},
                  {"number": 2, "kind": "steps", "steps": [
                      {"plan": 0, "number": 1}, {"plan": 1, "number": 2}]},
                  {"number": 3, "kind": "callout", "steps": [
                      {"plan": 2, "number": 3, "in_callout": True}]},
                  {"number": 4, "kind": "steps", "steps": [{"plan": 3, "number": 3}]},
                  {"number": 5, "kind": "parts", "steps": []}],
        "plan": [{"index": 0, "callout": 0, "callout_step": 0, "attaches": False,
                  "bricks": [1, 2]},
                 {"index": 1, "callout": 0, "callout_step": 0, "attaches": False,
                  "bricks": [3]},
                 {"index": 2, "callout": 1, "callout_step": 1, "attaches": False,
                  "bricks": [4, 5, 6]},
                 {"index": 3, "callout": 1, "callout_step": 0, "attaches": True,
                  "bricks": [7]}],
        "bricks": bricks})


def test_a_callouts_parts_count_on_the_page_that_puts_it_on():
    t = truth()
    page = {t.ids[n]: p for n, p in t.placed_on.items()}
    assert page == {"1": 2, "2": 2, "3": 2, "4": 4, "5": 4, "6": 4, "7": 4}
    assert {t.ids[n]: p for n, p in t.built_on.items()}["4"] == 3
    assert t.step_pages() == [2, 3, 4]


def test_score_rows_a_page_and_the_seed_is_written_as_ldraw():
    t = truth()
    build = moved(t.parts[:6], 270, [20, 0, 0])   # the last part never put on
    result = bf.score(t, build, 2, 4, BOUNDS, {4: {"unclear": [{"why": "hidden",
                                                                 "what": "the last brick"}]}})
    rows = {r["page"]: r for r in result["pages"]}
    assert (rows[2]["parts"], rows[2]["right"]) == (3, 3)
    assert (rows[4]["parts"], rows[4]["right"], rows[4]["missing"]) == (4, 3, 1)
    assert rows[4]["built_on"] == [3, 4]
    assert rows[4]["unclear"][0]["why"] == "hidden"
    seed = bf.read_ldraw(t.ldraw([0, 1], "seed"))
    assert [(p.part, p.at) for p in seed] == [("3001", [0.0, -24.0, 0.0]),
                                              ("3001", [0.0, -48.0, 0.0])]
    later = bf.score(t, build, 4, 4, BOUNDS)
    assert later["totals"]["parts"] == 4


class FakeApp:
    """The app's port, as a builder's server reaches it: every call recorded."""

    def __init__(self, models: Path) -> None:
        self.models = models
        self.asked: list[str] = []

    def ask(self, tool: str, arguments: dict) -> dict:
        self.asked.append(tool)
        if tool == "__tools__":
            names = ["look_at_model", "edit_model", "open_model", "gallery", "view_model"]
            return {"ok": True, "tools": [{"name": n, "description": n,
                                           "input_schema": {}} for n in names]}
        if tool == "save_model":
            (self.models / f"{arguments['name']}.ldr").write_text("1 4 0 0 0 1 0 0 0 1 0 0 0 1 3001.dat\n")
        return {"ok": True, "content": [{"type": "text", "text": f"did {tool}"}]}


def test_the_server_hands_pages_and_hands_never_the_model(tmp_path):
    pages = tmp_path / "pages"
    pages.mkdir()
    (pages / "page-1.png").write_bytes(b"\x89PNG one")
    (pages / "page-2.png").write_bytes(b"\x89PNG two")
    models = tmp_path / "models"
    models.mkdir()
    app = FakeApp(models)
    server = booklet_mcp.Server(0, pages, tmp_path / "run", models, app)
    names = [t["name"] for t in server.tools()]
    assert names[:2] == ["booklet_page", "page_done"]
    assert "open_model" not in names and "gallery" not in names
    page = server.call("booklet_page", {"page": 2})
    assert page["content"][1]["type"] == "image" and not page["isError"]
    assert server.call("booklet_page", {"page": 9})["isError"]
    refused = server.call("open_model", {"name": "castle"})
    assert refused["isError"] and "open_model" not in app.asked
    assert not server.call("edit_model", {"add": []})["isError"]
    assert app.asked[-1] == "edit_model"
    server.call("page_done", {"page": 2, "placed": 5, "notes": "front is -z",
                              "unclear": [{"why": "hidden", "what": "a tile"}]})
    said = json.loads((tmp_path / "run" / "pages.jsonl").read_text().splitlines()[-1])
    assert (said["page"], said["placed"], said["unclear"][0]["why"]) == (2, 5, "hidden")
    assert (tmp_path / "run" / "snapshots" / "page-2.ldr").exists()
    calls = [json.loads(line)["tool"] for line in
             (tmp_path / "run" / "calls.jsonl").read_text().splitlines()]
    assert calls == ["booklet_page", "booklet_page", "open_model", "edit_model", "page_done"]
    # The app's tool list was read, never kept: tools/mcp_tools.json is the release's.
    assert app.asked.count("__tools__") == 1


def test_a_hose_drawn_in_segments_is_never_judged(monkeypatch):
    monkeypatch.setattr(bf, "_NAMES", {"3001": "Brick 2 x 4",
                                       "756": "~Hose Flexible Segment Center Section"})
    data = truth().data
    data["bricks"]["7"]["part"] = "756"
    t = bf.Truth(data)
    assert t.flex == {t.index["7"]}
    result = bf.score(t, moved(t.parts[:6], 0, [0, 0, 0]), 2, 4, BOUNDS)
    assert result["totals"]["parts"] == 6 and result["totals"]["right"] == 6
