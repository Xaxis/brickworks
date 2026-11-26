"""Every way into or out of the hand goes through the hand (handkeep2).

A part in hand (lifted by X, a figure lifted whole, a selection carried) stays
the model's where it stood until it is put down or put back
(Builder._take_into_hand). Each review of the hand found a path round it: X on
one plain part took it off the model, so Ctrl+S then wrote the model without it;
the Shift+E turn moved held parts behind the hand's back, so Escape put them
back where they stood before the turn; a session's undo took back the person's
lift (figreview3 F1, F2, F5). The run-time guard counts a held part's place or
colour written round the hand (BrickWorld.round_the_hand). This one fails at
check time when new code opens a path round it:

1. A part's place, colour and kind are written by BrickWorld alone: nowhere else
   assigns .transform, .color_code or .part_id of a BrickWorld.Brick.
2. Inside BrickWorld, every function that writes them, or takes a part out, lets
   the hand go first (_hand_change), or is one the hand itself or a new or copied
   part's (ALLOWED, each with why).
3. The hand's doors are Builder's alone: BrickWorld.take_in_hand and
   put_from_hand, and BrickLattice.take_in_hand, are called from the hand's own
   functions (DOORS) and nowhere else.
4. A lift records nothing and takes nothing off: lifting is the hand's.
5. A session's undo is its own: the tools never press the person's undo (which
   puts their lift back), and never call Builder.undo() as the person.

src/dev is left out: the probes drive the app as a person and a session do.
Each rule is shown to catch its own kind of path on a sample (test_*_catches).
"""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "src"
WORLD = SRC / "render" / "brick_world.gd"
BUILDER = SRC / "assembly" / "builder.gd"

# BrickWorld functions that write a part and need not let the hand go: why each.
ALLOWED = {
    "put_from_hand": "the hand's own put, down or back",
    "_place": "a new part, in no hand",
    "add_unseen": "a new part, in no hand",
    "copy_for_reading": "a copy's own parts",
    "copy_at_home": "a copy's own parts",
    "clear": "the whole world let go of, the hand with it (Builder.holds_lift)",
    "_unplace": "called by remove_brick after _hand_change, and for ghosts, never in hand",
    "clear_ghosts": "ghosts, never in hand",
}

# The hand's doors and the only functions that may open them.
DOORS = {
    "world.take_in_hand(": {"_take_into_hand"},
    "lattice.take_in_hand(": {"_take_into_hand"},
    "world.put_from_hand(": {"_put_hand_back", "_put_hand_down"},
}

LIFTS = ("lift_hovered", "lift_brick", "lift_selection", "_lift_figure")

FIELDS = r"(?:transform|color_code|part_id)"
ASSIGN = rf"\.{FIELDS}\s*(?:[-+*/]?=)(?!=)"
DECLARED = re.compile(
    r"(?:var|for)\s+([A-Za-z_]\w*)\s*:\s*BrickWorld\.Brick\b"
    r"|[(,]\s*([A-Za-z_]\w*)\s*:\s*BrickWorld\.Brick\b"
)
FUNC = re.compile(r"^(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\(")


def _code(line: str) -> str:
    """The line without its comment (a # outside a string)."""
    out, quote = [], ""
    for ch in line:
        if quote:
            out.append(ch)
            if ch == quote:
                quote = ""
            continue
        if ch in "\"'":
            quote = ch
        elif ch == "#":
            break
        out.append(ch)
    return "".join(out)


def functions(text: str) -> dict[str, list[tuple[int, str]]]:
    """Each top-level function's lines (number, code), by name; lines in a
    class body (an inner class's own setters) under the class's name."""
    found: dict[str, list[tuple[int, str]]] = {}
    name = ""
    for number, raw in enumerate(text.splitlines(), 1):
        if raw and not raw[0].isspace():
            match = FUNC.match(raw)
            if match:
                name = match.group(1)
            elif raw.startswith("class "):
                name = "class " + raw.split()[1].rstrip(":")
            elif not raw.startswith("#"):
                name = ""
        if name:
            found.setdefault(name, []).append((number, _code(raw)))
    return found


def brick_writes_outside(path: Path, text: str) -> list[str]:
    """Rule 1: a Brick's place, colour or kind assigned in [path]."""
    names: set[str] = set()
    for line in text.splitlines():
        for match in DECLARED.finditer(_code(line)):
            names.add(match.group(1) or match.group(2))
    patterns = [re.compile(r"get_brick\([^)]*\)" + ASSIGN)]
    if names:
        patterns.append(re.compile(r"\b(?:" + "|".join(sorted(names)) + r")" + ASSIGN))
    found = []
    for number, raw in enumerate(text.splitlines(), 1):
        code = _code(raw)
        if any(p.search(code) for p in patterns):
            found.append(f"{path}:{number}: {raw.strip()}")
    return found


WORLD_WRITE = re.compile(r"\b(?:brick|twin|_bricks\[[^\]]+\])" + ASSIGN + r"|_bricks\.(?:erase|clear)\(")


def world_writes_round_hand(text: str, allowed: dict[str, str] = ALLOWED) -> list[str]:
    """Rule 2: BrickWorld functions writing a part without _hand_change."""
    found = []
    for name, lines in functions(text).items():
        if name.startswith("class ") or name in allowed:
            continue
        writes = [(n, c) for n, c in lines if WORLD_WRITE.search(c)]
        if writes and not any("_hand_change(" in c for _, c in lines):
            found += [f"brick_world.gd:{n}: {name}: {c.strip()}" for n, c in writes]
    return found


def doors_opened_elsewhere(files: dict[str, str]) -> list[str]:
    """Rule 3: the hand's doors called from anything but the hand."""
    found = []
    for path, text in files.items():
        mine = path.endswith("assembly/builder.gd")
        for name, lines in functions(text).items():
            for number, code in lines:
                for door, owners in DOORS.items():
                    if door in code and not (mine and name in owners):
                        found.append(f"{path}:{number}: {name} opens {door[:-1]}")
    return found


def lifts_that_take_off(text: str) -> list[str]:
    """Rule 4: a lift that removes a part or records a step."""
    found = []
    for name, lines in functions(text).items():
        if name not in LIFTS:
            continue
        for number, code in lines:
            if "remove_brick(" in code or "_history.append(" in code:
                found.append(f"builder.gd:{number}: {name}: {code.strip()}")
    return found


SESSION_UNDO = re.compile(r"\.press\(\s*\"(?:undo|redo)\"(?:\s+if\s+\w+\s+else\s+\"(?:undo|redo)\")?\s*\)"
                          r"|builder\.undo\(\s*\)")


def session_undoes_person(files: dict[str, str]) -> list[str]:
    """Rule 5: a session's tool pressing the person's undo."""
    found = []
    for path, text in files.items():
        for number, raw in enumerate(text.splitlines(), 1):
            if SESSION_UNDO.search(_code(raw)):
                found.append(f"{path}:{number}: {raw.strip()}")
    return found


def _shipped() -> dict[str, str]:
    out = {}
    for path in sorted(SRC.rglob("*.gd")):
        if (SRC / "dev") in path.parents:
            continue
        out[str(path.relative_to(ROOT))] = path.read_text(encoding="utf-8").removeprefix("﻿")
    return out


# -- the tree as it is ---------------------------------------------------------


def test_only_brick_world_writes_a_part() -> None:
    found = []
    for path, text in _shipped().items():
        if path.endswith("render/brick_world.gd"):
            continue
        found += brick_writes_outside(Path(path), text)
    assert not found, "a part's place, colour or kind is BrickWorld's to write:\n" + "\n".join(found)


def test_brick_world_lets_the_hand_go_first() -> None:
    found = world_writes_round_hand(WORLD.read_text(encoding="utf-8"))
    assert not found, "call _hand_change first, or add the function to ALLOWED with why:\n" + "\n".join(found)


def test_the_hands_doors_are_the_hands() -> None:
    found = doors_opened_elsewhere(_shipped())
    assert not found, "only the hand takes in or puts out (Builder._take_into_hand, _put_hand_*):\n" + "\n".join(found)


def test_a_lift_takes_nothing_off() -> None:
    found = lifts_that_take_off(BUILDER.read_text(encoding="utf-8"))
    assert not found, "a lift goes into hand (_take_into_hand), recording nothing:\n" + "\n".join(found)


def test_a_sessions_undo_is_its_own() -> None:
    session = {p: t for p, t in _shipped().items() if p.startswith(("src/net/", "src/ai/"))}
    found = session_undoes_person(session)
    assert not found, "a session undoes with press(name, false) or builder.undo(false):\n" + "\n".join(found)


def test_every_allowed_function_is_still_there() -> None:
    names = functions(WORLD.read_text(encoding="utf-8"))
    gone = [name for name in ALLOWED if name not in names]
    assert not gone, "ALLOWED names functions BrickWorld no longer has: " + ", ".join(gone)


# -- each rule catches its own kind of path ------------------------------------


def test_rule_one_catches() -> None:
    sample = (
        "func f(world: BrickWorld) -> void:\n"
        "\tvar b: BrickWorld.Brick = world.get_brick(3)\n"
        "\tb.transform = Transform3D.IDENTITY\n"
        "\tworld.get_brick(4).color_code = 14\n"
        "\tif b.transform == Transform3D.IDENTITY:\n"
        "\t\tpass\n"
    )
    found = brick_writes_outside(Path("x.gd"), sample)
    assert len(found) == 2 and ":3:" in found[0] and ":4:" in found[1], found


def test_rule_two_catches() -> None:
    sample = (
        "func rotate_model(turns: int) -> void:\n"
        "\tfor brick_id: int in _bricks.keys():\n"
        "\t\tvar brick: Brick = _bricks[brick_id]\n"
        "\t\tbrick.transform = Transform3D.IDENTITY\n"
        "func move_brick(brick_id: int, to: Transform3D) -> bool:\n"
        "\tvar brick: Brick = get_brick(brick_id)\n"
        "\t_hand_change(brick_id, \"move\")\n"
        "\tbrick.transform = to\n"
        "\treturn true\n"
    )
    found = world_writes_round_hand(sample)
    assert len(found) == 1 and "rotate_model" in found[0], found


def test_rule_three_catches() -> None:
    sample = {
        "src/ui/somewhere.gd": "func grab() -> void:\n\tbuilder.world.take_in_hand(3)\n",
        "src/assembly/builder.gd": (
            "func _take_into_hand(ids: Array) -> void:\n\tworld.take_in_hand(3)\n"
            "func lift_hovered() -> bool:\n\tworld.put_from_hand(3, Transform3D())\n"
        ),
    }
    found = doors_opened_elsewhere(sample)
    assert len(found) == 2 and "grab" in found[0] and "lift_hovered" in found[1], found


def test_rule_four_catches() -> None:
    sample = (
        "func lift_hovered() -> bool:\n"
        "\t_history.append({\"undo\": \"add\"})\n"
        "\tworld.remove_brick(_hovered)\n"
        "\treturn true\n"
    )
    assert len(lifts_that_take_off(sample)) == 2


def test_rule_five_catches() -> None:
    sample = {"src/net/t.gd": (
        "\tawait verbs.press(\"undo\")\n"
        "\tawait verbs.press(\"redo\" if again else \"undo\")\n"
        "\tbuilder.undo()\n"
        "\tawait verbs.press(\"undo\", false)\n"
        "\tbuilder.undo(false)\n"
    )}
    assert len(session_undoes_person(sample)) == 3
