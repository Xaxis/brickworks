"""Where a minifigure's parts go: the tool that measured it, held to the
LDraw library and to the app that uses its numbers.

tools/minifig.py measures the joints over real sets and writes the
per-part tables the app reads (src/minifig/minifig_data.gd); the joints
themselves are written twice, there and in src/minifig/minifig.gd. These
pin the two together and pin the rules that wrote the tables to parts
whose answer is known.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import minifig  # noqa: E402
from ldraw.library import Library  # noqa: E402

LDRAW_ROOT = ROOT / "vendor" / "ldraw"
needs_ldraw = pytest.mark.skipif(
    not (LDRAW_ROOT / "parts").is_dir(),
    reason="LDraw library not present; run tools/fetch_data.sh",
)
GDSCRIPT = (ROOT / "src" / "minifig" / "minifig.gd").read_text()


def _gd_constant(name: str) -> list[float]:
    found = re.search(r"const %s: Array\[float\] = \[(.*?)\]" % name, GDSCRIPT, re.S)
    assert found, name
    return [float(v) for v in found.group(1).replace("\n", " ").split(",")]


@pytest.mark.parametrize("tool, app", [
    ("arm_r", "ARM_R"), ("arm_l", "ARM_L"), ("hand_r", "HAND_R"),
    ("hand_l", "HAND_L"), ("head", "HEAD"), ("hips", "HIPS"), ("leg_r", "LEGS"),
])
def test_the_app_places_parts_where_the_tool_measured(tool: str, app: str) -> None:
    (x, y, z), rotation = minifig.JOINTS[tool]
    assert _gd_constant(app) == [x, y, z, *rotation]


def test_the_grip_is_where_the_hand_part_says() -> None:
    assert re.search(r"const GRIP := Vector3\(0.0, -0.8229, -9.8948\)", GDSCRIPT)
    assert minifig.GRIP == (0.0, -0.8229, -9.8948)


def test_a_figure_is_not_counted_in_a_models_texture() -> None:
    # tools/texture.py measures a model against real sets' inventories,
    # which keep figures apart; what a figure holds is a set part.
    import texture
    by_id = {
        "3001": {"category": "Brick"},
        "973": {"category": "Minifig"},
        "3626cp01": {"category": "Minifig"},
        "3901": {"category": "Minifig Headwear"},
        "3838": {"category": "Minifig Neckwear"},
        "2530": {"category": "Minifig Accessory"},
    }
    parts = [("3001", 4), ("973", 4), ("3626cp01", 14), ("3901", 70),
             ("3838", 0), ("2530", 72), ("3001", 1)]
    assert texture.without_figures(parts, by_id) == [("3001", 4), ("2530", 72), ("3001", 1)]


@pytest.fixture(scope="module")
def library() -> Library:
    return Library(LDRAW_ROOT)


@needs_ldraw
def test_a_cutlass_is_held_at_its_origin_along_y(library: Library) -> None:
    # 2530 is drawn the LDraw way: its handle a bar along Y through the
    # origin. Real figures hold it within half an LDU of there.
    (at, along) = minifig.grip_of(library, "2530")
    assert max(abs(v) for v in at) < 0.01
    assert abs(abs(along[1]) - 1.0) < 1e-6


@needs_ldraw
def test_a_shortsword_is_held_by_its_handle_not_its_guard(library: Library) -> None:
    # 3847's origin is at its guard, where a cross bar runs through it; the
    # handle is the bar along Y below, and real hands are 2 LDU from its
    # middle.
    (at, along) = minifig.grip_of(library, "3847")
    assert abs(at[1] - 8.0) < 0.01 and abs(at[0]) < 0.01 and abs(at[2]) < 0.01
    assert abs(along[1]) > 0.99


@needs_ldraw
def test_a_bow_has_no_bar_and_is_held_at_its_origin(library: Library) -> None:
    assert minifig.bars(library, "4499") == []
    assert minifig.grip_of(library, "4499") == ((0.0, 0.0, 0.0), (0.0, 1.0, 0.0))


@needs_ldraw
def test_airtanks_have_a_collar(library: Library) -> None:
    # Real figures wearing 3838 sit the head up 3 LDU (29 of 38); the
    # geometry says 4. The table uses what real figures do where they do.
    assert minifig.collar(library, "3838") == 4.0
    data = (ROOT / "src" / "minifig" / "minifig_data.gd").read_text()
    assert '"3838": 3,' in data
