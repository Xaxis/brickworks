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
    brick("3023", 14, 80, -8, 0),     # 4
    brick("3023", 14, 120, -8, 0),    # 5
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


def test_a_wheel_a_little_short_of_its_pin_is_near_and_a_stud_off_is_not():
    build = list(MODEL)
    build[4] = brick("3023", 14, 86, -10, 0)    # 0.3 stud and a quarter plate off
    build[5] = brick("3023", 14, 140, -8, 0)    # a whole stud off
    got = kinds(bf.compare(MODEL, build, BOUNDS))
    assert (got[4], got[5]) == ("near", "place")


def test_letters_of_one_mould_are_one_part():
    build = list(MODEL)
    build[4] = brick("3023b", 14, 80, -8, 0)
    assert kinds(bf.compare(MODEL, build, BOUNDS))[4] == "right"


def test_parts_built_before_the_stretch_are_not_judged_and_keep_their_place():
    # Parts 0-2 were the seed. The builder put the yellow plate where the seed's
    # blue brick was not, and nothing where part 4 goes, so part 5's plate stands in
    # part 4's place: one is right, one is missing, never two right.
    build = [MODEL[0], MODEL[1], MODEL[2], MODEL[3], brick("3023", 14, 80, -8, 0)]
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
        "plan": [{"index": 0, "number": 1, "callout": 0, "callout_step": 0, "attaches": False,
                  "bricks": [1, 2]},
                 {"index": 1, "number": 2, "callout": 0, "callout_step": 0, "attaches": False,
                  "bricks": [3]},
                 {"index": 2, "number": 3, "callout": 1, "callout_step": 1, "attaches": False,
                  "bricks": [4, 5, 6]},
                 {"index": 3, "number": 3, "callout": 1, "callout_step": 0, "attaches": True,
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
    # The part left off is the callout's, numbered as the step that puts it on, and
    # what the builder said of its page is taken as the cause.
    assert rows[4]["wrong"][0]["step"] == 3
    assert result["said_causes"] == {"hidden": 1.0}
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


class BusyApp(FakeApp):
    """An app still running the builder's last edit as a job for two more asks."""

    def __init__(self, models: Path) -> None:
        super().__init__(models)
        self.left = 2

    def ask(self, tool: str, arguments: dict) -> dict:
        if tool == "save_model" and self.left > 0:
            self.asked.append(tool)
            self.left -= 1
            return {"ok": True, "content": [{"type": "text", "text": (
                "The app is busy with job 1 (edit_model, 22 s in): Changed it: 145 bricks… "
                "Call job {\"id\": 1} until it gives its answer, then this.")}]}
        return super().ask(tool, arguments)


def test_page_done_keeps_the_model_once_the_edit_it_follows_has_finished(tmp_path):
    pages = tmp_path / "pages"
    pages.mkdir()
    models = tmp_path / "models"
    models.mkdir()
    app = BusyApp(models)
    server = booklet_mcp.Server(0, pages, tmp_path / "run", models, app)
    server.call("page_done", {"page": 18, "placed": 5})
    assert app.asked == ["save_model", "job", "save_model", "job", "save_model"]
    said = json.loads((tmp_path / "run" / "pages.jsonl").read_text().splitlines()[-1])
    assert said["snapshot"].endswith("page-18.ldr")
    assert (tmp_path / "run" / "snapshots" / "page-18.ldr").exists()


class SlowApp(FakeApp):
    """An app whose pictures wait for the GPU: view_model becomes job 4, which is still
    going when first asked about, and a call made meanwhile finds the app busy."""

    def __init__(self, models: Path) -> None:
        super().__init__(models)
        self.job_asks = 0

    def ask(self, tool: str, arguments: dict) -> dict:
        self.asked.append(tool)
        if tool == "view_model":
            words = "Started job 4: drawing the model. Call job {\"id\": 4} until it ends."
        elif tool == "look_at_model" and self.job_asks < 4:
            words = "The app is busy with job 4 (view_model, 50 s in): drawing."
        elif tool == "job":
            self.job_asks += 1
            words = ("Job 4 (view_model) is still going, 45 s in: drawing." if self.job_asks
                     in (1, 3) else "Job 4 (view_model) is done, after 70 s:")
            if "still" not in words:
                return {"ok": True, "content": [{"type": "text", "text": words},
                                                {"type": "image", "data": "", "mimeType": "image/png"}]}
        else:
            words = f"did {tool}"
        return {"ok": True, "content": [{"type": "text", "text": words}]}


def test_a_picture_that_waits_for_the_gpu_is_waited_for(tmp_path):
    # The builder has no job tool: on 2026-11-05 one was told "busy with job 4" for a
    # minute and stopped twice. The relay waits on the job as the app's design loop does.
    app = SlowApp(tmp_path)
    server = booklet_mcp.Server(0, tmp_path, tmp_path / "run", tmp_path, app)
    seen = server.call("view_model", {"from": "top"})
    assert seen["content"][0]["text"].startswith("Job 4 (view_model) is done")
    assert seen["content"][1]["type"] == "image" and not seen["isError"]
    assert app.asked == ["view_model", "job", "job"]
    looked = server.call("look_at_model", {})
    assert looked["content"][0]["text"] == "did look_at_model"
    assert app.asked[3:] == ["look_at_model", "job", "job", "look_at_model"]


def test_a_hose_drawn_in_segments_is_never_judged(monkeypatch):
    monkeypatch.setattr(bf, "_NAMES", {"3001": "Brick 2 x 4",
                                       "756": "~Hose Flexible Segment Center Section"})
    data = truth().data
    data["bricks"]["7"]["part"] = "756"
    t = bf.Truth(data)
    assert t.flex == {t.index["7"]}
    result = bf.score(t, moved(t.parts[:6], 0, [0, 0, 0]), 2, 4, BOUNDS)
    assert result["totals"]["parts"] == 6 and result["totals"]["right"] == 6


def test_a_second_vehicle_may_stand_anywhere_but_a_part_of_the_first_may_not():
    # A second model of three bricks, standing apart from the first: the builder stood
    # it elsewhere, turned. Where it stands is the builder's; its parts are right.
    apart = [brick("3001", 2, 400, 0, 0), brick("3001", 2, 400, -24, 0),
             brick("3023", 2, 400, -32, 0)]
    model = MODEL + apart
    build = MODEL + moved(apart, 90, [-300, 0, 500])
    got = bf.compare(model, build, BOUNDS)
    assert set(kinds(got).values()) == {"right"} and got["pieces"] == 2
    # The same three bricks put on the first model a stud off are one piece with it:
    # where they go is the booklet's, and a stud off is a stud off.
    joined = [brick("3001", 2, 160, 0, 0), brick("3001", 2, 160, -24, 0),
              brick("3023", 2, 160, -32, 0)]
    build = MODEL + [bf.Placed(p.part, p.colour, bf._add(p.at, [0, 0, 20]) + p.turn)
                     for p in joined]
    got = bf.compare(MODEL + joined, build, BOUNDS)
    assert [kinds(got)[i] for i in (6, 7, 8)] == ["place"] * 3 and got["pieces"] == 1


def test_a_layer_laid_on_a_wrong_one_is_carried_and_a_wrong_one_alone_is_not():
    # Four bricks in a row (page 2), a brick on the first (page 3), and a plate on that
    # brick and one on the last of the row (page 4).
    at = {"1": (0, 0), "2": (80, 0), "3": (160, 0), "4": (240, 0), "5": (0, -24),
          "6": (0, -32), "7": (240, -8)}
    # The row's first brick blue, so the row has an end to tell it by.
    bricks = {n: {"part": "3023" if n in ("6", "7") else "3001", "colour": 1 if n == "1" else 4,
                  "ldraw": [x, y, 0, *ONE]} for n, (x, y) in at.items()}
    t = bf.Truth({
        "model": "m.ldr", "title": "M",
        "pages": [{"number": 1, "kind": "cover", "steps": []},
                  {"number": 2, "kind": "steps", "steps": [{"plan": 0, "number": 1}]},
                  {"number": 3, "kind": "steps", "steps": [{"plan": 1, "number": 2}]},
                  {"number": 4, "kind": "steps", "steps": [{"plan": 2, "number": 3}]}],
        "plan": [{"index": 0, "number": 1, "callout": 0, "callout_step": 0, "attaches": False,
                  "bricks": [1, 2, 3, 4]},
                 {"index": 1, "number": 2, "callout": 0, "callout_step": 0, "attaches": False,
                  "bricks": [5]},
                 {"index": 2, "number": 3, "callout": 0, "callout_step": 0, "attaches": False,
                  "bricks": [6, 7]}],
        "bricks": bricks})
    build = list(t.parts)
    for n in (4, 5, 6):   # the brick on the first a stud along, and both plates too
        build[n] = bf.Placed(build[n].part, build[n].colour, bf._add(build[n].at, [20, 0, 0]) +
                             build[n].turn)
    result = bf.score(t, moved(build, 90, [0, 0, 0]), 2, 4, BOUNDS)
    rows = {r["page"]: r for r in result["pages"]}
    assert (rows[3]["place"], rows[3]["carried"]) == (1, 0)
    # The plate on the moved brick followed its page; the one on the row's end did not.
    assert (rows[4]["place"], rows[4]["carried"]) == (2, 1)
    assert [w.get("carried", False) for w in rows[4]["wrong"]].count(True) == 1
    assert result["totals"]["carried"] == 1
    assert result["said_causes"] == {"unsaid": 2.0, "carried": 1.0}


def test_make_photographs_only_the_pages_asked_for():
    # The castle's 324 pages take most of an hour; a stretch needs a dozen.
    assert bf._page_list("2-5,9") == [2, 3, 4, 5, 9]
    assert bf._page_list("172") == [172]


def test_a_booklet_drawn_another_way_is_read_as_it_says_and_ours_as_ours(tmp_path):
    """A printed LEGO® booklet has no parts box and no outline: a builder told it has
    would look for them. Its DIR says how its pages read; ours are read as before."""
    ours = bf.reading(tmp_path)
    prompt = bf.PROMPT.format(kinds=1, pieces=1, parts="", start="", notes="", first=2,
                              last=2, step_reading=ours["step"], apart=ours["apart"])
    assert "outlined in orange" in prompt and "(a yellow page)" in prompt
    assert "page" not in ours
    (tmp_path / "reading.json").write_text(json.dumps({
        "step": "New parts are drawn lifted above their place.",
        "apart": "steps of its own, numbered from 1 again",
        "page": "Page 1 is the cover. No parts boxes."}))
    printed = bf.reading(tmp_path)
    prompt = bf.PROMPT.format(kinds=1, pieces=1, parts="", start="", notes="", first=2,
                              last=2, step_reading=printed["step"], apart=printed["apart"])
    assert "outlined in orange" not in prompt and "yellow page" not in prompt
    assert "drawn lifted above their place" in prompt and "numbered from 1 again" in prompt
    models = tmp_path / "models"
    models.mkdir()
    told = booklet_mcp.Server(0, tmp_path, tmp_path / "run", models, FakeApp(models),
                              reading=printed["page"]).tools()[0]["description"]
    assert "No parts boxes." in told and "outlined" not in told
    assert told.startswith("One page of the booklet, as its picture.")
    plain = booklet_mcp.Server(0, tmp_path, tmp_path / "run", models, FakeApp(models))
    assert plain.tools()[0] == booklet_mcp.PAGE_TOOL
    other = tmp_path / "other.json"
    other.write_text(json.dumps({"step": "Told the conventions."}))
    assert bf.reading(tmp_path, other)["step"] == "Told the conventions."
    assert bf.reading(tmp_path, other)["apart"] == bf.READING["apart"]
