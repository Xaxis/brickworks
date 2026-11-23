"""Tests for the photo bench's measures that photoreal4 added (tools/bench/photoreal.py).

The solo judge's numbers are only worth reading if its summary counts each label apart and
counts a set picture that is itself a render apart from the photographs; the outline mask is
only worth fitting a camera to if it crosses a soft shadow and stops at a part's edge; the
noise measure only steers the camera's grain if flat shading reads as none and noise as its
own size; and the tell tally only says what the judge names if "slightly" is not "light".
"""

from __future__ import annotations

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
