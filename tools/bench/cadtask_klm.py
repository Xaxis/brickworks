"""Building a set by hand, modelled: the keystroke-level model for Brickworks and Studio.

Card, Moran and Newell's keystroke-level model (KLM; "The keystroke-level
model for user performance time with interactive systems", CACM 23(7),
1980, and The Psychology of Human-Computer Interaction, 1983) times a task
an expert does without error as the sum of its operators:

    K  a key pressed                         0.28 s (an average non-secretary
                                             typist, 40 words a minute; 0.20 s
                                             is a skilled typist's)
    P  the pointer moved onto a target       1.1 s
    B  a mouse button pressed or released    0.1 s (a click is BB, 0.2 s)
    H  a hand moved between keyboard and mouse  0.4 s
    M  a mental preparation                  1.35 s

The system's own response time (R) is left out: it is what the measured
run on this box has and the model has not, so the two differ by it.

Both apps are modelled the same way for the same parts, from each one's
documented controls: Brickworks's own controls list (src/ui/controls_hint.gd)
and Studio's help pages (studiohelp.bricklink.com, the article numbers in
STUDIO_SOURCES). Everything here is MODELLED, NOT MEASURED. Where Studio's
pages do not say, the assumption is named in ASSUMPTIONS and chosen not to
favour Brickworks.

Conventions, the same for both apps:

- The left hand rests on the keyboard and the right on the mouse, so a
  single shortcut key costs no H; typing a part number does (both hands to
  the keys and back): H ... H.
- M before each decision: which part, which colour, which turn, where.
- A part's colour is sticky: a change only when it differs from the last.
- The part number typed is the file's (its digits and letters), each a K.
"""

from __future__ import annotations

import json
from collections import Counter
from functools import lru_cache
from pathlib import Path

## Seconds per operator (Card, Moran and Newell 1980, table 2).
SECONDS = {"K": 0.28, "P": 1.1, "B": 0.1, "H": 0.4, "M": 1.35}

STUDIO_SOURCES = {
    "search": "https://studiohelp.bricklink.com/hc/en-us/articles/6502499385111",
    "colour": "https://studiohelp.bricklink.com/hc/en-us/articles/5411673129879",
    "colour menu": "https://studiohelp.bricklink.com/hc/en-us/articles/5459441964695",
    "turn": "https://studiohelp.bricklink.com/hc/en-us/articles/5410338956695",
    "rotate": "https://studiohelp.bricklink.com/hc/en-us/articles/5411433123351",
    "snap": "https://studiohelp.bricklink.com/hc/en-us/articles/5412087360919",
    "steps": "https://studiohelp.bricklink.com/hc/en-us/articles/5626973531287",
    "nudge": "https://studiohelp.bricklink.com/hc/en-us/articles/5411126626199",
}

ASSUMPTIONS = [
    "Studio: Ctrl+F reaches the parts search; the box filters as you type, no Enter (6502499385111).",
    "Studio: the old search text is cleared by Ctrl+A, as in Brickworks (not confirmed).",
    "Studio: a part is clicked in the palette and clicked where it goes (P BB P BB); after a "
    "click it is not still in hand, so a second copy is clicked in the palette again "
    "(not confirmed; 5410338956695 says click or Space places).",
    "Studio: the colour square beside the search sets the colour of new parts and is sticky: "
    "a change is a click on it and a click on the colour (5411673129879).",
    "Studio: arrow keys turn the part in hand 90 degrees about the screen's axes "
    "(5410338956695, 5411433123351); the view is taken as square to the model, so Left/Right "
    "turn about the vertical and Up/Down about the left-right axis, and the turn is kept "
    "from the part before (not confirmed; the cheaper reading for Studio).",
    "Studio: E makes a new step and a part put down goes into the current step "
    "(5626973531287; the second half not confirmed).",
    "Studio snaps a part onto compatible connectors and turns it to fit (5412087360919); "
    "that saving is not modelled, so Studio's turns may be fewer than modelled.",
    "Brickworks: / focuses the parts search (controls_hint.gd); the old text needs Ctrl+A.",
    "Brickworks: the part stays in hand after a click (the status bar says so), so a "
    "second copy costs no search; the turn in hand is kept.",
    "Brickworks: the colour is a swatch in the always-open palette: one click. A colour not "
    "in sets since the palette's year (the old greys, 7 and 8) is not in that palette and "
    "has look-alikes beside it under All, so it is its name typed: Shift-C, the name, Enter "
    "(parts_bin.gd, colours_named). The whole name is counted, which is the most: the line "
    "over the palette names the first match, and a person stops typing once it is theirs.",
    "Brickworks: R and Shift-R turn the part in hand a quarter about its up; T and Shift-T "
    "roll it onto the next face in the order up, +z, down, -z, +x, -x (BrickLattice.FACES).",
    "Brickworks: E, Next step, once a step's parts are down: what was put down since the "
    "last step makes one (shell.gd, step_close), as Studio's E is modelled.",
]


## The colours the palette shows without All: those in sets lately
## (assets/generated/colors.json's current, PartLibrary.is_current).
COLOURS = Path(__file__).resolve().parent.parent.parent / "assets" / "generated" / "colors.json"


@lru_cache(maxsize=1)
def _palette() -> dict[int, dict]:
    try:
        return {int(c["code"]): c for c in json.loads(COLOURS.read_text())}
    except (OSError, ValueError):
        return {}


def in_short_palette(code: int) -> bool:
    """Whether the palette shows [code] before All is pressed. Unknown
    colours count as shown, which favours neither app."""
    colour = _palette().get(int(code))
    return True if colour is None else bool(colour.get("current", True))


def colour_name(code: int) -> str:
    colour = _palette().get(int(code))
    return str(colour["name"]) if colour else str(code)


def seconds(ops: list[str] | Counter) -> float:
    counts = ops if isinstance(ops, Counter) else Counter(ops)
    return round(sum(SECONDS[op] * n for op, n in counts.items()), 3)


# -- the 24 turns a part can have on the grid ----------------------------------

FACES = ["up", "+z", "down", "-z", "+x", "-x"]
_AXIS = {"up": (0, 1, 0), "down": (0, -1, 0), "+x": (1, 0, 0), "-x": (-1, 0, 0),
         "+z": (0, 0, 1), "-z": (0, 0, -1)}


def _quarter(axis: tuple[int, int, int], quarters: int) -> tuple:
    """A rotation by quarters of a turn about a unit axis, as integer rows."""
    x, y, z = axis
    c, s = [(1, 0), (0, 1), (-1, 0), (0, -1)][quarters % 4]
    t = 1 - c
    return ((t * x * x + c, t * x * y - s * z, t * x * z + s * y),
            (t * x * y + s * z, t * y * y + c, t * y * z - s * x),
            (t * x * z - s * y, t * y * z + s * x, t * z * z + c))


def _mul(a: tuple, b: tuple) -> tuple:
    return tuple(tuple(sum(a[r][k] * b[k][c] for k in range(3)) for c in range(3))
                 for r in range(3))


def basis_for(face: str, quarter: int) -> tuple:
    """BrickLattice.basis_for: the face the studs point to, then a quarter
    turn about the part's new up."""
    up = _AXIS[face]
    if face == "up":
        tip = _quarter((1, 0, 0), 0)
    elif face == "down":
        tip = _quarter((1, 0, 0), 2)
    else:
        k = (-up[2], 0, up[0])  # (0, 1, 0) x up
        tip = _quarter(k, 1)
    return _mul(_quarter(up, quarter), tip)


def brickworks_turn_keys(before: tuple[str, int], after: tuple[str, int]) -> list[str]:
    """The fewest presses of T/Shift-T and R/Shift-R from one turn in hand to
    another, as K operators (a Shift is a K of its own)."""
    df = (FACES.index(after[0]) - FACES.index(before[0])) % 6
    dq = (after[1] - before[1]) % 4
    keys: list[str] = []
    keys += ["K"] * df if df <= 3 else ["K", "K"] * (6 - df)
    keys += ["K"] * dq if dq <= 2 else ["K", "K"]
    return keys


def _studio_moves() -> list[tuple[tuple, int]]:
    """Studio's arrow keys on a view square to the model: a quarter about
    the vertical (Left, Right) or the left-right axis (Up, Down), one K."""
    return [(_quarter((0, 1, 0), 1), 1), (_quarter((0, 1, 0), 3), 1),
            (_quarter((1, 0, 0), 1), 1), (_quarter((1, 0, 0), 3), 1)]


def studio_turn_keys(before: tuple[str, int], after: tuple[str, int]) -> list[str]:
    """The fewest arrow presses that take one of the 24 turns to another
    (a breadth-first search over the 24)."""
    start = basis_for(*before)
    goal = basis_for(*after)
    if start == goal:
        return []
    seen = {start: 0}
    frontier = [start]
    while frontier:
        nxt = []
        for b in frontier:
            for move, cost in _studio_moves():
                c = _mul(move, b)
                if c not in seen:
                    seen[c] = seen[b] + cost
                    if c == goal:
                        return ["K"] * seen[c]
                    nxt.append(c)
        frontier = nxt
    return []


# -- one part, and a whole set ----------------------------------------------------

def model_part(app: str, part: dict, prev: dict | None) -> list[str]:
    """The operators to put one part down, after [prev] (None for the first).

    [part] has id, colour and turn (face, quarter)."""
    ops: list[str] = []
    same_part = prev is not None and prev["id"] == part["id"]
    typed = ["K"] * len(str(part["id"]))
    if app == "brickworks":
        if not same_part:
            # / to the search, Ctrl+A, the number; a look; the first tile.
            ops += ["M", "H", "K", "K", "K"] + typed + ["H", "M", "P", "B", "B"]
        if prev is None or prev["colour"] != part["colour"]:
            if in_short_palette(part["colour"]):
                ops += ["M", "P", "B", "B"]
            else:
                # Shift-C, the name, Enter: both hands to the keys and back.
                ops += ["M", "H", "K", "K"] + ["K"] * len(colour_name(part["colour"])) \
                    + ["K", "H"]
        turn_from = tuple(prev["turn"]) if prev else ("up", 0)
        keys = brickworks_turn_keys(turn_from, tuple(part["turn"]))
        if keys:
            ops += ["M"] + keys
        ops += ["M", "P", "B", "B"]
    elif app == "studio":
        if not same_part:
            # Ctrl+F, Ctrl+A, the number; a look; the thumbnail.
            ops += ["M", "H", "K", "K", "K", "K"] + typed + ["H", "M", "P", "B", "B"]
        else:
            # Not still in hand: the same thumbnail again.
            ops += ["M", "P", "B", "B"]
        if prev is None or prev["colour"] != part["colour"]:
            ops += ["M", "P", "B", "B", "P", "B", "B"]
        turn_from = tuple(prev["turn"]) if prev else ("up", 0)
        keys = studio_turn_keys(turn_from, tuple(part["turn"]))
        if keys:
            ops += ["M"] + keys
        ops += ["M", "P", "B", "B"]
    else:
        raise ValueError(f"no model of {app}")
    return ops


def model_steps(app: str, steps: list[int]) -> list[str]:
    """Marking the author's steps: [steps] is how many parts each step has."""
    ops: list[str] = []
    for _n in steps:
        # Studio: E for a new step. Brickworks: E, Next step, once the
        # step's parts are down (src/ui/shell.gd, step_close).
        ops += ["M", "K"]
    return ops


def model_build(app: str, parts: list[dict], steps: list[int] | None = None) -> dict:
    """Every part in order, and the steps marked if [steps] is given: the
    operators by kind, the seconds, and both per part."""
    ops: list[str] = []
    prev = None
    for part in parts:
        ops += model_part(app, part, prev)
        prev = part
    marking = model_steps(app, steps) if steps else []
    counts = Counter(ops)
    with_steps = Counter(ops + marking)
    n = max(len(parts), 1)
    return {
        "app": app, "parts": len(parts), "operators": dict(counts),
        "actions": sum(counts[k] for k in "KPB") - counts["B"] // 2,
        "seconds": seconds(counts), "seconds_per_part": round(seconds(counts) / n, 2),
        "with_steps": {"operators": dict(with_steps), "seconds": seconds(with_steps),
                       "seconds_per_part": round(seconds(with_steps) / n, 2),
                       "actions": sum(with_steps[k] for k in "KPB") - with_steps["B"] // 2},
        "modelled": True,
    }


def summarise_build(build: dict) -> dict:
    """tools/web/cad_task_flow.mjs's build.json, each set modelled in both
    apps for the parts the run tried, and the run against its own model."""
    out: dict = {"assumptions": ASSUMPTIONS, "studio_sources": STUDIO_SOURCES,
                 "seconds": SECONDS, "sets": []}
    for row in build.get("results", []):
        parts = [p for p in row.get("parts_list", []) if p.get("turn")]
        parts = parts[: int(row.get("tried") or len(parts))]
        steps = list(Counter(p["step"] for p in parts).values())
        model = {app: model_build(app, [{"id": p["id"], "colour": p["colour"],
                                        "turn": [p["turn"]["face"], p["turn"]["q"]]}
                                       for p in parts], steps)
                 for app in ("brickworks", "studio")}
        out["sets"].append({"set": row.get("set"), "parts": len(parts), "model": model,
                            "measured_vs_model": compare_run(row, model["brickworks"])})
    return out


def measured_operators(counts: dict) -> Counter:
    """A measured run's actions as KLM operators: a pointer move P, a click
    BB, a key or typed character K, a wheel notch K (KLM has none; a notch
    is about a keystroke's effort)."""
    return Counter({"P": counts.get("point", 0), "B": 2 * counts.get("click", 0),
                    "K": counts.get("key", 0) + counts.get("typed", 0) + counts.get("scroll", 0)})


def compare_run(measured: dict, modelled: dict) -> dict:
    """How a measured Brickworks run differs from its own model for the same
    parts: actions and operators per part, the seconds the operators come to
    against the seconds it took here, and which operators it had over."""
    parts = max(int(measured.get("tried") or measured.get("parts") or 1), 1)
    ops = measured_operators(measured.get("counts", {}))
    # A run that marked its steps (E once a step) is held to the model
    # that marks them too.
    if measured.get("counts", {}).get("step") and "with_steps" in modelled:
        modelled = {**modelled, "operators": modelled["with_steps"]["operators"],
                    "actions": modelled["with_steps"].get("actions", modelled["actions"]),
                    "seconds_per_part": modelled["with_steps"]["seconds_per_part"]}
    model_ops = Counter(modelled["operators"])
    # The model's motor operators only: M and H are a person's, not events.
    extra = {op: ops[op] - model_ops.get(op, 0) for op in "KPB"}
    actions = ops["P"] + ops["K"] + ops["B"] // 2
    return {
        "parts": parts,
        "measured_actions_per_part": round(actions / parts, 2),
        "modelled_actions_per_part": round(modelled["actions"] / max(modelled["parts"], 1), 2),
        "measured_operators": dict(ops),
        "modelled_operators": {op: model_ops.get(op, 0) for op in "KPBHM"},
        "extra_operators": extra,
        "measured_motor_seconds_per_part": round(seconds(ops) / parts, 2),
        "modelled_seconds_per_part": modelled["seconds_per_part"],
        "measured_wall_seconds_per_part": measured.get("seconds_per_part"),
        "extra_aims": measured.get("counts", {}).get("aim_fix", 0),
    }


if __name__ == "__main__":
    # python3 tools/bench/cadtask_klm.py BUILD.json [OUT.json | --merge]: both
    # apps modelled for the parts the run tried, and the run against its
    # model; --merge writes it into BUILD.json's summary, as summary.klm.
    import json
    import sys
    build = json.loads(open(sys.argv[1]).read())
    summary = summarise_build(build)
    text = json.dumps(summary, indent=1)
    if sys.argv[2:] == ["--merge"]:
        brief = [{"set": s["set"], "parts": s["parts"],
                  "brickworks_seconds_per_part": s["model"]["brickworks"]["seconds_per_part"],
                  "brickworks_with_steps": s["model"]["brickworks"]["with_steps"]["seconds_per_part"],
                  "studio_seconds_per_part": s["model"]["studio"]["seconds_per_part"],
                  "studio_with_steps": s["model"]["studio"]["with_steps"]["seconds_per_part"],
                  "brickworks_actions_per_part": round(s["model"]["brickworks"]["actions"]
                                                       / max(s["parts"], 1), 2),
                  "studio_actions_per_part": round(s["model"]["studio"]["actions"]
                                                   / max(s["parts"], 1), 2),
                  "measured_vs_model": s["measured_vs_model"]} for s in summary["sets"]]
        build.setdefault("summary", {})["klm"] = {
            "modelled_not_measured": True, "seconds": SECONDS,
            "assumptions": ASSUMPTIONS, "studio_sources": STUDIO_SOURCES, "sets": brief}
        open(sys.argv[1], "w").write(json.dumps(build, indent=1) + "\n")
    elif len(sys.argv) > 2:
        open(sys.argv[2], "w").write(text + "\n")
    else:
        print(text)
