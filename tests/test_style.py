"""Tests for tools/style.py: how a model is built, measured on tiny models.

Each model here is a few lines of LDraw written by hand, so the answer is
known before the measure runs: a 2 x 4 brick studs-up is not SNOT, the
same brick rolled onto its side is, a 45-degree turn is angled, and a
Left/Right pair placed as mirror images is symmetric.

LDraw is -Y up, which is the fact the orientation measure rests on: a
part's studs point along its matrix times (0, -1, 0).
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import style  # noqa: E402
from style import PartInfo, Parts  # noqa: E402

# A 2 x 4 brick's box in its own LDraw axes: studs up to y = -4, its
# bottom at y = 24.
BRICK = PartInfo("Brick 2 x 4", "Brick", ((-40.0, -4.0, -20.0), (40.0, 24.0, 20.0)))
SLOPE = PartInfo("Slope Brick 45 2 x 2", "Slope", ((-20.0, -4.0, -20.0), (20.0, 24.0, 20.0)))
# Mirror images of each other: the left one reaches further to +x.
LEFT = PartInfo("Wing 2 x 3 Left", "Wing", ((-10.0, -4.0, -30.0), (30.0, 8.0, 30.0)))
RIGHT = PartInfo("Wing 2 x 3 Right", "Wing", ((-30.0, -4.0, -30.0), (10.0, 8.0, 30.0)))
HEAD = PartInfo("Minifig Head", "Minifig", ((-10.0, -4.0, -10.0), (10.0, 20.0, 10.0)))

PARTS = Parts.of({"3001": BRICK, "3039": SLOPE, "left": LEFT, "right": RIGHT, "3626": HEAD},
                 twins={"left": "right"})

SQUARE = "1 0 0 0 1 0 0 0 1"
ON_ITS_SIDE = "1 0 0 0 0 -1 0 1 0"       # rolled 90 degrees about x
UPSIDE_DOWN = "1 0 0 0 -1 0 0 0 -1"      # 180 degrees about x
C = math.cos(math.radians(45))
TURNED_45 = f"{C} 0 {C} 0 1 0 {-C} 0 {C}"  # 45 degrees about y, studs still up
TILTED_45 = f"1 0 0 0 {C} {-C} 0 {C} {C}"  # 45 degrees about x


def line(part: str, at: tuple[float, float, float] = (0, 0, 0), turn: str = SQUARE,
         colour: int = 4) -> str:
    return f"1 {colour} {at[0]} {at[1]} {at[2]} {turn} {part}.dat"


def measured(*lines: str) -> dict:
    return style.measure(style.read("\n".join(lines)), PARTS)


# -- orientation ------------------------------------------------------------


def test_a_studs_up_brick_is_not_snot() -> None:
    found = measured(line("3001"))
    assert found["parts"] == 1
    assert found["snot"] == 0.0
    assert found["angled"] == 0.0


# A model's grid is the one most of its parts sit square on, so each of
# these stands its odd brick on a stack of three upright ones.
STACK = [line("3001"), line("3001", (0, -24, 0)), line("3001", (0, -48, 0))]


def test_a_brick_on_its_side_is_snot() -> None:
    found = measured(*STACK, line("3001", (0, -100, 0), ON_ITS_SIDE))
    assert found["snot"] == 0.25
    assert found["sideways"] == 0.25
    assert found["angled"] == 0.0     # square to the grid, just not upright


def test_upside_down_is_down() -> None:
    found = measured(*STACK, line("3001", (0, -100, 0), UPSIDE_DOWN))
    assert found["down"] == 0.25
    assert found["snot"] == 0.25


def test_a_model_built_on_its_side_is_left_on_its_side() -> None:
    """A quarter turn of the whole model is not undone: real sets build so."""
    found = measured(*[line("3001", (0, 0, z), ON_ITS_SIDE) for z in (0, 24, 48)],
                     line("3001", (0, -100, 0)))
    assert found["snot"] == 0.75
    assert found["turned"] == 0.0


def test_a_45_degree_turn_is_angled_and_still_studs_up() -> None:
    # Two square bricks set the model's grid; the third is turned on it.
    found = measured(*STACK, line("3001", (0, -100, 0), TURNED_45))
    assert found["angled"] == 0.25
    assert found["snot"] == 0.0


def test_a_45_degree_tilt_is_tilted() -> None:
    found = measured(*STACK, line("3001", (0, -100, 0), TILTED_45))
    assert found["tilted"] == 0.25
    assert found["snot"] == 0.25
    assert found["angled"] == 0.25


def test_a_model_saved_turned_is_squared_up_first() -> None:
    """A real set saved turned 30 degrees is still built square."""
    c, s = math.cos(math.radians(30)), math.sin(math.radians(30))
    turn = f"{c} 0 {s} 0 1 0 {-s} 0 {c}"
    found = measured(line("3001", turn=turn), line("3001", (0, -24, 0), turn))
    assert abs(found["turned"]) == 30.0
    assert found["angled"] == 0.0


# -- reading a model --------------------------------------------------------


def test_sub_models_are_flattened_with_their_transform_and_colour() -> None:
    model = style.read("\n".join([
        "0 FILE main.ldr",
        "1 2 100 0 0 " + ON_ITS_SIDE + " wall.ldr",
        "0 FILE wall.ldr",
        "1 16 0 -24 0 " + SQUARE + " 3001.dat",
        "1 1 0 0 0 " + SQUARE + " 3001.dat",
    ]))
    assert [p.part for p in model.placed] == ["3001", "3001"]
    first = model.placed[0]
    assert first.colour == 2          # 16 takes the colour that placed it
    assert model.placed[1].colour == 1
    # (0, -24, 0) rolled about x lands at z = -24, then moved to x = 100.
    assert (first.matrix.x, first.matrix.y, first.matrix.z) == (100, 0, -24)
    assert style.facing(first.matrix) == "sideways"


def test_a_part_carried_inside_the_document_is_one_part() -> None:
    model = style.read("\n".join([
        "0 FILE main.ldr",
        "1 4 0 0 0 " + SQUARE + " 10276 - 3001.dat",
        "0 FILE 10276 - 3001.dat",
        "0 3001",
        "0 !LDRAW_ORG Unofficial_Part",
        "1 16 0 0 0 " + SQUARE + " s/3001s01.dat",
    ]))
    assert [p.part for p in model.placed] == ["10276 - 3001"]
    # Its title names a part the catalogue knows, so it is read as that.
    assert PARTS.get("10276 - 3001", model.embedded) is BRICK


def test_minifigures_are_left_out() -> None:
    found = measured(*STACK, line("3626", (0, -100, 0), ON_ITS_SIDE))
    assert found["parts"] == 3
    assert found["snot"] == 0.0


# -- symmetry ---------------------------------------------------------------


def test_a_mirrored_pair_scores_symmetric() -> None:
    found = measured(line("left", (50, 0, 0)), line("right", (-50, 0, 0)))
    assert found["symmetry"] == 1.0
    assert found["plane"] == ("x", 0.0)


def test_a_pair_in_two_colours_is_not_a_mirror_image() -> None:
    found = measured(line("left", (50, 0, 0)), line("right", (-50, 0, 0), colour=1))
    assert found["symmetry"] == 0.0


def test_two_left_parts_are_not_a_mirror_image() -> None:
    found = measured(line("left", (50, 0, 0)), line("left", (-50, 0, 0)))
    assert found["symmetry"] == 0.0


def test_half_a_wall_mirrored_is_half_symmetric() -> None:
    # A mirrored pair, plus two more on one side only, set apart in z
    # so no plane mirrors them onto each other or onto themselves.
    found = measured(line("left", (50, 0, 0)), line("right", (-50, 0, 0)),
                     line("left", (130, 0, 200)), line("left", (210, 0, 400)))
    assert found["symmetry"] == 0.5


# -- kinds and shaping ------------------------------------------------------


@pytest.mark.parametrize("name, category, expected", [
    ("Brick 2 x 4", "Brick", {"plain"}),
    ("Plate 1 x 2", "Plate", {"plain"}),
    ("Brick 1 x 2 x 5", "Brick", {"plain"}),
    ("Slope Brick 45 2 x 1", "Slope", {"slope"}),
    ("Slope Brick Curved 2 x 1", "Slope", {"curve"}),
    ("Arch 1 x 4", "Arch", {"curve"}),
    ("Brick 2 x 2 Round", "Brick", {"curve"}),
    ("Wing 2 x 3 Left without Chamfer", "Wing", {"curve"}),
    ("Brick 1 x 1 with Headlight", "Brick", {"snot_parts"}),
    ("Brick 1 x 4 with Studs on Side", "Brick", {"snot_parts"}),
    ("Bracket 1 x 2 - 2 x 2 Up", "Bracket", {"snot_parts"}),
    ("Tile 2 x 2 Round with Round Underside Stud", "Tile", {"curve", "tile"}),
    ("Hinge Plate 1 x 4 Base", "Hinge", {"angle_parts"}),
    ("Plate 1 x 1 with Clip Vertical (Thick C-Clip)", "Plate", {"angle_parts"}),
    ("Turntable 2 x 2 Plate Base", "Turntable", {"angle_parts"}),
    ("Brick 1 x 2 with Embossed Bricks", "Brick", {"texture"}),
    ("Brick 1 x 2 Log", "Brick", {"texture"}),
    ("Brick 1 x 2 with Groove", "Brick", {"texture"}),
    ("Slope Brick 31 1 x 1 x 0.667", "Slope", {"slope", "texture"}),
    ("Plate 1 x 1 Round", "Plate", {"curve", "texture"}),
    ("Tile 1 x 2 Grille with Groove", "Tile", {"texture", "tile"}),
    ("Tile 1 x 2 with Groove", "Tile", {"tile"}),
    ("Rock Panel 4 x 10 x 6", "Rock", {"organic"}),
    ("Plant Leaves 6 x 5", "Plant", {"organic"}),
    ("Plate 1 x 2 with Groove with 1 Centre Stud", "Plate", set()),
    ("Technic Bush with Two Flanges", "Technic", set()),
    ("Window 1 x 2 x 3 without Sill", "Window", set()),
])
def test_kinds_of_real_part_names(name: str, category: str, expected: set) -> None:
    assert style.kinds(PartInfo(name, category)) == expected


def test_kinds_are_shares_of_the_model() -> None:
    found = measured(line("3001"), line("3039", (200, 0, 0)))
    assert found["plain"] == 0.5
    assert found["slope"] == 0.5
    assert found["shaped"] == 0.5


def test_a_brick_beside_a_slope_is_near_the_shaping() -> None:
    touching = measured(line("3001"), line("3039", (60, 0, 0)))
    apart = measured(line("3001"), line("3039", (200, 0, 0)))
    assert touching["near_shaped"] == 1.0
    assert apart["near_shaped"] == 0.5


# -- against the real catalogue, where there is one --------------------------


@pytest.mark.skipif(not style.CATALOGUE.exists(), reason="no catalogue.json; run tools/build_meshes.py")
def test_the_catalogue_knows_moved_parts_and_their_mirror_twins() -> None:
    parts = Parts()
    plate = parts.get("3023")                          # a stub: moved to 3023b
    assert plate is not None and plate.name == "Plate 1 x 2"
    assert parts.canonical("41770") == "41770a"
    assert parts.mirror("41770") == "41769a"           # Wing 2 x 4 Left -> Right
    assert parts.mirror("3001") == "3001"
