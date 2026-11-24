"""Tests for the photo bench's measures that photoreal4 added (tools/bench/photoreal.py).

The solo judge's numbers are only worth reading if its summary counts each label apart and
counts a set picture that is itself a render apart from the photographs; the outline mask is
only worth fitting a camera to if it crosses a soft shadow and stops at a part's edge; the
noise measure only steers the camera's grain if flat shading reads as none and noise as its
own size; and the tell tally only says what the judge names if "slightly" is not "light".
"""

from __future__ import annotations

import json
import random
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from bench import photoreal  # noqa: E402


def test_solo_summary_counts_each_label_and_kind_apart():
    verdicts = [
        {"who": "photo", "kind": "set", "answer": "photograph", "p_photo": 0.9},
        {"who": "photo", "kind": "closeup", "answer": "render", "p_photo": 0.3},
        {"who": "p4", "kind": "closeup", "answer": "photograph", "p_photo": 0.8},
        {"who": "p4", "kind": "set", "answer": "render", "p_photo": 0.1},
        {"who": "p4", "kind": "set", "error": "timed out"},
        {"who": "reference render", "kind": "set", "answer": "render", "p_photo": 0.05},
    ]
    summary = photoreal.solo_summary(verdicts)
    assert list(summary)[0] == "photo"
    assert summary["photo"]["all"] == {"trials": 2, "called_photograph": 1, "share_photograph": 0.5,
                                       "mean_p_photo": 0.6}
    # A verdict that never came is left out, not counted as a render.
    assert summary["p4"]["all"]["trials"] == 2
    assert summary["p4"]["closeups"]["share_photograph"] == 1.0
    assert summary["p4"]["sets"]["mean_p_photo"] == 0.1
    # 6512's picture, a render, never joins the photographs' numbers.
    assert summary["reference render"]["all"]["trials"] == 1
    assert summary["photo"]["sets"]["trials"] == 1


def test_silhouette_crosses_a_soft_shadow_and_stops_at_an_edge():
    image = Image.new("RGB", (80, 60), (255, 255, 255))
    draw = ImageDraw.Draw(image)
    # A shadow falling off in small steps under the part, then the part: a white face with an edge.
    for k in range(20):
        shade = 255 - 3 * k
        draw.rectangle((10 + k, 40, 70 - k, 58), fill=(shade, shade, shade))
    draw.rectangle((25, 15, 55, 45), fill=(60, 60, 60))
    draw.rectangle((28, 18, 52, 30), fill=(240, 240, 240))
    mask = photoreal.silhouette(image)
    assert mask.getpixel((40, 35)) == 255          # the part
    assert mask.getpixel((40, 22)) == 255          # its white face, inside its edge
    assert mask.getpixel((15, 50)) == 0            # the soft shadow is backdrop
    assert mask.getpixel((2, 2)) == 0


def test_sensor_noise_reads_flat_shading_as_none_and_noise_as_its_size():
    flat = Image.new("RGB", (120, 120))
    flat.putdata([(60 + x // 4, 60 + x // 4, 60 + x // 4) for _y in range(120) for x in range(120)])
    assert photoreal.sensor_noise(flat) < 0.3
    rng = random.Random(4)
    noisy = Image.new("RGB", (120, 120))
    values = [max(0, min(255, round(128 + rng.gauss(0, 3.0)))) for _ in range(120 * 120)]
    noisy.putdata([(v, v, v) for v in values])
    assert 2.4 < photoreal.sensor_noise(noisy) < 3.6
    # White paper (a cut-out's) is not read at all.
    assert photoreal.sensor_noise(Image.new("RGB", (60, 60), (255, 255, 255))) == 0.0


def test_tells_group_by_word_starts():
    assert photoreal._group("no dust, scratches or mould marks").startswith("wear")
    assert photoreal._group("slightly blurred edges") != "light and shadow"
    assert photoreal._group("seamless pure white background") == "backdrop"
    assert photoreal._group("minifigure facing away").startswith("staging")
    assert photoreal._group("a fingerprint on the top").startswith("wear")
    assert photoreal._group("something unheard of") == "other"


def test_every_solo_verdict_is_asked_under_a_fresh_name_outside_any_checkout(tmp_path, monkeypatch):
    # photoreal16: a name kept for every round repeats one draw of the judge. Each verdict must see
    # its picture under a name and folder no other verdict saw, outside the checkout (whose branch
    # and commits Claude Code would put in the judge's context), and the copy must be gone after.
    drawn = tmp_path / "arm"
    drawn.mkdir()
    shot = photoreal.shots()[0]
    Image.new("RGB", tuple(shot["size"]), (200, 30, 30)).save(drawn / f"{shot['name']}.png")
    seen = []

    def fake_ask(where, picture, model):
        assert picture.exists() and picture.parent == where
        assert not any((p / ".git").exists() for p in (picture, *picture.parents))
        assert len(list(where.iterdir())) == 1
        seen.append((picture, picture.read_bytes()))
        return {"answer": "render", "p_photo": 0.25, "reason": "", "render_tells": [], "photo_tells": [],
                "looked_at": [picture.name], "seconds": 1.0, "model": model}

    monkeypatch.setattr(photoreal, "_ask_solo", fake_ask)
    photoreal.solo([f"one={drawn}", f"two={drawn}"], tmp_path / "out", "t", "opus", jobs=2, trials=2,
                   rounds=2, seed=1, only=[shot["name"]])
    # photo, one, two: each 2 trials x 2 rounds
    assert len(seen) == 12
    assert len({p.name for p, _ in seen}) == 12 and len({p.parent for p, _ in seen}) == 12
    assert all(not p.parent.exists() for p, _ in seen)
    renders = {data for p, data in seen} - {photoreal._jpeg(photoreal.photo_of(shot))}
    assert len(renders) == 1  # the two labels were shown the same bytes
    record = json.loads((tmp_path / "out" / "solo_t.json").read_text())
    verdicts = [v for r in record["rounds"] for v in r["verdicts"]]
    assert {v["picture"] for v in verdicts if v["who"] == "one"} == {v["picture"] for v in verdicts if v["who"] == "two"}
    assert (tmp_path / "out" / "masters" / f"{verdicts[0]['picture']}.jpg").exists()
    assert record["scores"]["twins"][0]["a"] == "one" and record["scores"]["twins"][0]["pictures"] == 1


def _verdicts(who, values, picture_of=lambda shot, draw: f"{shot}{draw}"):
    """Solo verdicts: values is {shot: {draw: [p, ...]}}."""
    return [{"who": who, "shot": shot, "kind": "closeup", "draw": draw, "picture": picture_of(shot, draw),
             "p_photo": p} for shot, draws in values.items() for draw, ps in draws.items() for p in ps]


def test_score_is_the_mean_over_shots_and_a_paired_difference_with_its_interval():
    rng = random.Random(7)
    base = {f"s{k}": {"d1": [min(1, max(0, 0.2 + 0.05 * k + rng.gauss(0, 0.05))) for _ in range(6)]}
            for k in range(10)}
    lifted = {s: {d: [min(1, p + 0.1) for p in ps] for d, ps in draws.items()} for s, draws in base.items()}
    verdicts = _verdicts("off", base) + _verdicts("on", lifted, lambda s, d: f"on{s}{d}")
    scores = photoreal.score(verdicts, "off")
    off = scores["labels"]["off"]["all"]
    # each shot weighs the same: the mean over shots of each shot's mean
    want = sum(sum(ps) / len(ps) for draws in base.values() for ps in draws.values()) / 10
    assert abs(off["mean"] - want) < 1e-3 and off["low"] < off["mean"] < off["high"]
    gain = scores["labels"]["on"]["vs_base"]
    assert abs(gain["mean"] - 0.1) < 0.01 and gain["low"] > 0.05
    # a picture byte for byte the same in both arms adds nothing to their difference
    same = _verdicts("same", base) + _verdicts("off", base)
    tie = photoreal.score(same, "off")["labels"]["same"]["vs_base"]
    assert tie["mean"] == 0 and tie["low"] == 0 and tie["high"] == 0


def test_twins_measure_the_judges_noise_and_hold_their_interval():
    rng = random.Random(3)
    values = {f"s{k}": {"d1": [0.3 + 0.1 * (k % 3)] * 6} for k in range(10)}
    one = {s: {d: [p + rng.gauss(0, 0.06) for p in ps] for d, ps in draws.items()} for s, draws in values.items()}
    two = {s: {d: [p + rng.gauss(0, 0.06) for p in ps] for d, ps in draws.items()} for s, draws in values.items()}
    scores = photoreal.score(_verdicts("a", one) + _verdicts("b", two), "a")
    (twin,) = scores["twins"]
    assert twin["pictures"] == 10 and twin["low"] < 0 < twin["high"]
    # 120 verdicts of sd 0.06 a side: the difference's 95% half-width is about 1.96 * 0.06 * sqrt(2/60)
    assert 0.01 < twin["half_width"] < 0.04
