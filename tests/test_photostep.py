"""Tests for tools/bench/photostep.py: the photo-of-a-step bench's server and its score.

The bench is only as good as two things: that the session is handed exactly what a
check_step_photo tool would hand it, and nothing that gives the case away (a file name,
the kind), and that an answer is scored against the truth as the bar reads it. So the
server is driven as Claude Code drives it, over stdio, and the score is checked on
answers that are right, half right and wrong.
"""

from __future__ import annotations

import base64
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from bench import photostep  # noqa: E402

TOOL = ROOT / "tools" / "bench" / "photostep.py"


def _group() -> dict:
    fault = {"part": "3001", "part_name": "Brick 2 x 4", "colour": 4, "colour_name": "Red",
             "box": [0.40, 0.40, 0.50, 0.50], "changed": 0.01}
    return {"set": "0000-1", "name": "Test Tower", "key": "0000_p5", "page": 5, "step": 5, "steps": 9,
            "before": 4, "after": 6, "camera": {"size": [64, 48]},
            "faults": {"missing": dict(fault, kind="missing"),
                       "moved": dict(fault, kind="moved", toward=["left", "farther"],
                                     box_after=[0.30, 0.40, 0.40, 0.50]),
                       "colour": dict(fault, kind="colour", colour_to=320, colour_to_name="Dark Red")},
            "lots": {"4": [{"part": "3001", "name": "Brick 2 x 4", "colour": 1, "colour_name": "Blue", "count": 1}],
                     "5": [{"part": "3001", "name": "Brick 2 x 4", "colour": 4, "colour_name": "Red", "count": 2}],
                     "6": []}}


def _answer(**said) -> dict:
    out = {"step_shown": 5, "fault": "none", "part": "", "part_name": "", "colour": "", "seen_colour": "",
           "moved_toward": "", "studs": 0, "at_x": 0.0, "at_y": 0.0, "confidence": 80, "says": ""}
    out.update(said)
    return out


def _fake_dir(root: Path) -> Path:
    from PIL import Image
    g = _group()
    (root / "cases.json").write_text(json.dumps({"groups": [g]}))
    refs = root / "refs" / g["key"]
    refs.mkdir(parents=True)
    for step in (4, 5, 6):
        for side in photostep.SIDES:
            Image.new("RGB", (32, 24), (step * 20, 0, 0)).save(refs / f"{step}_{side}.png")
            Image.new("RGB", (32, 24), (0, step * 20, 0)).save(refs / f"{step}_{side}_new.png")
    (root / "photos").mkdir()
    for kind in photostep.KINDS:
        name = photostep.opaque(f"{g['key']}_{kind}")
        Image.new("RGB", (64, 48), (len(kind) * 20, 0, 0)).save(root / "photos" / f"{name}.jpg")
    return root


def test_a_case_s_files_are_named_for_nothing_it_is():
    names = {photostep.opaque(f"7638_p14_{kind}") for kind in photostep.KINDS}
    assert len(names) == 5
    for name in names:
        assert not any(word in name for word in ("right", "miss", "move", "colour", "behind", "7638"))
    assert photostep.opaque("7638_p14_right") == photostep.opaque("7638_p14_right")


def test_a_right_answer_is_named_and_a_wrong_part_is_not():
    case = {"id": "0000_p5_moved", "group": _group(), "kind": "moved"}
    right = photostep.judge(case, _answer(fault="moved", part="3001.dat", moved_toward="left",
                                          at_x=0.35, at_y=0.45))
    assert right["found"] and right["kind_right"] and right["part_right"] and right["place_right"]
    assert right["named"] and right["step_exact"]
    wrong_way = photostep.judge(case, _answer(fault="moved", part="3001", moved_toward="right",
                                              at_x=0.45, at_y=0.45))
    assert wrong_way["found"] and not wrong_way["named"]
    wrong_part = photostep.judge(case, _answer(fault="moved", part="3003", moved_toward="left",
                                               at_x=0.45, at_y=0.45))
    assert wrong_part["found"] and not wrong_part["part_right"] and not wrong_part["named"]
    elsewhere = photostep.judge(case, _answer(fault="moved", part="3001", moved_toward="left",
                                              at_x=0.9, at_y=0.9))
    assert not elsewhere["place_right"] and not elsewhere["named"]


def test_the_wrong_kind_of_fault_is_found_but_not_named():
    case = {"id": "0000_p5_colour", "group": _group(), "kind": "colour"}
    said = photostep.judge(case, _answer(fault="missing", part="3001", at_x=0.45, at_y=0.45))
    assert said["found"] and not said["kind_right"] and not said["named"]
    said = photostep.judge(case, _answer(fault="wrong_colour", part_name="Brick 2 x 4", at_x=0.45, at_y=0.45))
    assert said["named"]
    none = photostep.judge(case, _answer())
    assert not none["found"] and not none["named"]


def test_behind_wants_the_step_before_and_any_fault_is_a_false_alarm():
    case = {"id": "0000_p5_behind", "group": _group(), "kind": "behind"}
    said = photostep.judge(case, _answer(step_shown=4))
    assert said["step_exact"] and said["step_within"] and not said["false_alarm"]
    # "Missing" a part step 5 adds is true a step behind: the step read is wrong, but it
    # is no false alarm; only the strict count holds it.
    said = photostep.judge(case, _answer(step_shown=5, fault="missing", part="3001"))
    assert not said["step_exact"] and said["step_within"] and not said["false_alarm"]
    assert said["false_alarm_strict"]
    said = photostep.judge(case, _answer(step_shown=4, fault="moved", part="3001"))
    assert said["step_exact"] and said["false_alarm"]
    said = photostep.judge(case, _answer(step_shown=4, fault="missing", part="3003"))
    assert said["false_alarm"]
    right = {"id": "0000_p5_right", "group": _group(), "kind": "right"}
    assert photostep.judge(right, _answer(step_shown=7))["step_within"] is False


def test_the_server_hands_over_the_photo_the_steps_and_their_parts(tmp_path):
    root = _fake_dir(tmp_path)
    asks = [{"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-06-18"}},
            {"jsonrpc": "2.0", "method": "notifications/initialized"},
            {"jsonrpc": "2.0", "id": 2, "method": "tools/list"},
            {"jsonrpc": "2.0", "id": 3, "method": "tools/call",
             "params": {"name": "check_step_photo", "arguments": {}}},
            {"jsonrpc": "2.0", "id": 4, "method": "tools/call",
             "params": {"name": "step_picture", "arguments": {"step": 6, "from": "back-left", "new": True}}},
            {"jsonrpc": "2.0", "id": 5, "method": "tools/call",
             "params": {"name": "step_picture", "arguments": {"step": 9, "from": "top"}}},
            {"jsonrpc": "2.0", "id": 6, "method": "tools/call",
             "params": {"name": "step_picture", "arguments": {"step": 5, "from": "top", "new": False}}}]
    done = subprocess.run([sys.executable, str(TOOL), "mcp", "--dir", str(root), "--case", "0000_p5_colour"],
                          input="\n".join(json.dumps(a) for a in asks) + "\n", capture_output=True,
                          text=True, timeout=60)
    replies = {r["id"]: r for r in map(json.loads, done.stdout.splitlines())}
    assert sorted(replies) == [1, 2, 3, 4, 5, 6]
    assert [t["name"] for t in replies[2]["result"]["tools"]] == ["check_step_photo", "step_picture"]
    content = replies[3]["result"]["content"]
    images = [c for c in content if c["type"] == "image"]
    assert len(images) == 4
    photo = base64.b64decode(images[0]["data"])
    expected = (root / "photos" / f"{photostep.opaque('0000_p5_colour')}.jpg").read_bytes()
    assert photo == expected
    words = " ".join(c["text"] for c in content if c["type"] == "text")
    assert "step 5 of 9" in words and "Step 5 adds: 2 x Brick 2 x 4 (3001), Red" in words
    assert "colour" not in photostep.opaque("0000_p5_colour")
    assert "Step 6 from the back-left, its new parts ringed" in replies[4]["result"]["content"][0]["text"]
    assert replies[5]["result"]["content"][0]["text"].startswith("Only steps 4, 5 and 6")
    # new=false is as if it were not sent: the plain picture.
    assert replies[6]["result"]["content"][0]["text"] == "Step 5 from the top:"
    calls = [json.loads(line) for line in (root / "answers" / "0000_p5_colour.tools.jsonl").read_text().splitlines()]
    assert [c["tool"] for c in calls] == ["check_step_photo", "step_picture", "step_picture", "step_picture"]
