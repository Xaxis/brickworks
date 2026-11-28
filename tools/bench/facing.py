"""A design turned to face as its real set does, before the bench draws its views.

The bench draws a design and its set from the same cameras (run.VIEWS: corner, front and a
close look at the corner's nearest quarter), and the judge compares the two. A design's
front is wherever its session happened to put it. design48's A/A (the same code against
itself, docs/DESIGN_SCORES.md round forty-eight) had a wolf built facing -x: its corner
view showed its back and tail where the set's showed a head, and it lost eight verdicts of
eight. Of its eight subjects, three had the two designs facing different ways (the wolf,
a tractor shown side-on against one shown nose-first, a telehandler's two ends), and the
sets themselves nearly all face the front camera nose-first. Facing is the bench's, not
the designer's: a person turns a model to look at it.

So before the views are drawn the design is given a quarter turn about the vertical, never
by hand (tools/bench/realset.py `faced`):

- **By a look**: the design is drawn from its four sides (SIDES), and the judge's model is
  shown them beside the set's own front and corner views and asked which of the four shows
  the model from the side the set's front view shows the set (match_prompt). The design is
  turned to bring that side to the front camera (quarter_for).
- **By the outline**, when the look gives no answer: both models read as boxes
  (tools/style.py, figures and their gear left out), the design's long plan axis laid along
  the set's (`facing`). Which end goes where is a guess from the outline seen along the
  set's length; on design48's subjects it put two wolves' heads at opposite ends, which is
  why the look comes first.

The set's views define the front, so a design is never turned by its own idea of a front.

`turned_text` writes the turn into the model file: the first model's own lines turned
about the vertical through the origin, sub-models carried with their placing lines, so
nothing inside a sub-model changes. A quarter turn keeps every part on the lattice.
"""

from __future__ import annotations

import math
from dataclasses import dataclass

import style

GRID = 12
LONG = 0.2      # log(length / depth): 1.22 times as long as deep has a long axis
FLIP = 0.1
# A quarter turn about LDraw's vertical (y, down): x' = -z, z' = x, so +x goes to +z.
_QUARTER = ((0, 0, -1), (0, 1, 0), (1, 0, 0))

Box = tuple[tuple[float, float, float], tuple[float, float, float]]   # centre, half size


@dataclass(frozen=True, slots=True)
class Facing:
    """The turn a design is drawn at: quarter turns about the vertical, and why."""

    quarter: int
    scores: tuple[float, ...]       # each turn's likeness to the set, 0 to 3 quarters
    aspect: tuple[float, float]     # log(length / depth) of the design as made and the set

    @property
    def degrees(self) -> int:
        return 90 * self.quarter

    def as_dict(self) -> dict:
        return {"quarter": self.quarter, "degrees": self.degrees,
                "scores": [round(s, 4) for s in self.scores],
                "aspect": [round(a, 3) for a in self.aspect]}


def _power(quarter: int) -> tuple[tuple[int, ...], ...]:
    m = ((1, 0, 0), (0, 1, 0), (0, 0, 1))
    for _ in range(quarter % 4):
        m = tuple(tuple(sum(_QUARTER[i][k] * m[k][j] for k in range(3)) for j in range(3))
                  for i in range(3))
    return m


def boxes(text: str, parts: style.Parts) -> list[Box]:
    """Every building part's box in the model's own axes (LDraw, y down)."""
    model = style.read(text)
    placed = [(p, info) for p in model.placed
              if (info := parts.get(p.part, model.embedded)) is not None and style.building(info)]
    return [(b.centre, b.half) for b in style._boxes(placed, parts)]


def turn_boxes(found: list[Box], quarter: int) -> list[Box]:
    m = _power(quarter)
    out = []
    for centre, half in found:
        c = tuple(sum(m[i][k] * centre[k] for k in range(3)) for i in range(3))
        h = (half[2], half[1], half[0]) if quarter % 2 else half
        out.append((c, h))
    return out


def _span(lo: float, hi: float, low: float, size: float) -> range:
    """The raster cells a box from lo to hi covers, of GRID across an extent from `low`."""
    if size <= 0:
        return range(0, GRID)
    first = int(math.floor((lo - low) / size * GRID))
    last = int(math.ceil((hi - low) / size * GRID)) - 1
    first, last = max(0, min(GRID - 1, first)), max(0, min(GRID - 1, last))
    return range(first, max(first, last) + 1)


def seen(found: list[Box]) -> tuple[list[float], list[float], list[float], float]:
    """The top's height over the plan, what is covered from the front and from the side,
    each GRID x GRID in the model's own extent; and log(length along x / depth along z)."""
    if not found:
        return [0.0] * GRID * GRID, [0.0] * GRID * GRID, [0.0] * GRID * GRID, 0.0
    low = [min(c[k] - h[k] for c, h in found) for k in range(3)]
    high = [max(c[k] + h[k] for c, h in found) for k in range(3)]
    size = [high[k] - low[k] for k in range(3)]
    top = [0.0] * GRID * GRID
    front = [0.0] * GRID * GRID
    side = [0.0] * GRID * GRID
    for c, h in found:
        xs = _span(c[0] - h[0], c[0] + h[0], low[0], size[0])
        zs = _span(c[2] - h[2], c[2] + h[2], low[2], size[2])
        # y is down: a height is measured up from the model's lowest point.
        up_low, up_high = high[1] - (c[1] + h[1]), high[1] - (c[1] - h[1])
        ys = _span(up_low, up_high, 0.0, size[1])
        tall = up_high / size[1] if size[1] > 0 else 1.0
        for x in xs:
            for z in zs:
                top[x * GRID + z] = max(top[x * GRID + z], tall)
            for y in ys:
                front[x * GRID + y] = 1.0
        for z in zs:
            for y in ys:
                side[z * GRID + y] = 1.0
    aspect = math.log(max(size[0], 1.0) / max(size[2], 1.0))
    return top, front, side, aspect


def _correlation(a: list[float], b: list[float]) -> float:
    n = len(a)
    ma, mb = sum(a) / n, sum(b) / n
    va = sum((x - ma) ** 2 for x in a)
    vb = sum((y - mb) ** 2 for y in b)
    if va <= 0 or vb <= 0:
        return 0.0
    return sum((x - ma) * (y - mb) for x, y in zip(a, b)) / math.sqrt(va * vb)


def likeness(design: list[Box], the_set: list[Box], quarter: int) -> float:
    """How like the set's the design's outline along the set's length is at this turn: what
    each covers seen across the set's depth, the view that tells a nose from a tail."""
    _top, front, side, _a = seen(turn_boxes(design, quarter))
    _top2, front2, side2, their_aspect = seen(the_set)
    if their_aspect >= 0:
        return _correlation(front, front2)
    return _correlation(side, side2)


def facing(design: list[Box], the_set: list[Box]) -> Facing:
    """The quarter turn that faces the design as its set.

    A model with no long axis (its plan within LONG of square), or a set with none, keeps
    its own front: its session drew it from the front camera. Otherwise the design's long
    axis is laid along the set's: across it, the likelier of the two ends; along it, turned
    end for end only when its outline is FLIP likelier so (a building is much the same
    both ways round, and its session chose its front)."""
    scores = tuple(likeness(design, the_set, q) for q in range(4))
    ours, theirs = seen(design)[3], seen(the_set)[3]
    if abs(ours) < LONG or abs(theirs) < LONG:
        quarter = 0
    elif (ours > 0) == (theirs > 0):
        quarter = 2 if scores[2] - scores[0] >= FLIP else 0
    else:
        quarter = 1 if scores[1] >= scores[3] else 3
    return Facing(quarter, scores, (ours, theirs))


# -- which side matches the set's front view ---------------------------------------------
#
# An outline cannot tell a wolf's head from its tail when the set's outline is a crouching
# wolf with a rider and a raised sword: on design48's eight A/A subjects it put the two
# wolves' heads at opposite ends and turned a tractor already nose-first end for end. A
# look can. The design is drawn from its four sides (SIDES, ModelShot's level elevations),
# and the judge's model is shown the set's own front and corner views beside them and asked
# which of the four shows the model from the side the set's front view shows the set. The
# design is then turned to bring that side to the front camera.
#
# Asking for each model's own front instead was tried first and put two telehandlers of the
# same code at opposite ends (design49): the set's front camera sees its bucket, and one
# design's headlights were at the end away from its forks, which the look took for its front.
# The front that matters is the set's views', so the question is a match, not a front.

SIDES = ("front", "right", "back", "left")

MATCH_SCHEMA: dict = {
    "type": "object",
    "properties": {
        "picture": {"type": "string", "enum": ["1", "2", "3", "4"],
                    "description": "the model's picture seen from the side the set's front "
                                   "view shows the set"},
        "reason": {"type": "string"},
    },
    "required": ["picture", "reason"],
}


def match_prompt(title: str, set_front: str, set_corner: str, pictures: list[str]) -> str:
    """The question: which of four pictures of a model, each from one side, shows it from the
    side the set's front view shows the set."""
    lines = [f"A is the real LEGO® set {title} seen straight from one side; B is the same set "
             "seen from a corner, so you can tell which side A shows.",
             f"  A. {set_front}", f"  B. {set_corner}", "",
             f"1 to 4 are a different LEGO® model built to look like {title}, each drawn from "
             "a different side, the camera level with it and a quarter turn apart.", ""]
    lines += [f"  {n}. {path}" for n, path in enumerate(pictures, 1)]
    lines += ["", "Open every picture with the Read tool before you answer.",
              "Which of 1 to 4 shows the model from the same side as A shows the set: the "
              "same end of a vehicle or an animal, the same face of a building or a figure, "
              "turned towards you? Judge by which part of the subject faces the camera, not "
              "by how well the model is built. If two pictures are equally right (a model "
              "the same front and back), give the lower number. Reply with only the JSON "
              "object the schema asks for: the picture's number and one sentence saying "
              "what faces the camera in A and in that picture."]
    return "\n".join(lines)


def read_match(reply: dict | str) -> int | None:
    """The side (an index into SIDES, as the pictures were shown) the reply names, or None."""
    found = reply
    if isinstance(reply, dict) and reply.get("type") == "result":
        if reply.get("is_error"):
            return None
        found = reply.get("structured_output")
    if not isinstance(found, dict):
        return None
    said = str(found.get("picture", "")).strip()
    return int(said) - 1 if said in ("1", "2", "3", "4") else None


def quarter_for(design_side: int, to_side: int = 0) -> int:
    """The quarter turn that brings the design's side `design_side` to `to_side` (the front
    camera's, by default).

    A quarter turn (_QUARTER, +x to +z in LDraw's axes) carries what the right camera saw
    to the back camera, the back to the left, the left to the front and the front to the
    right (the app draws LDraw's +x at the right camera and its -z at the front one)."""
    return (to_side - design_side) % 4


def _number(value: float) -> str:
    if abs(value - round(value)) < 1e-6:
        return str(int(round(value)))
    return f"{value:.6f}".rstrip("0").rstrip(".")


def turned_line(line: str, quarter: int) -> str:
    """One placing line (type 1) turned about the vertical through the origin."""
    bits = line.split(None, 14)
    if len(bits) < 15 or bits[0] != "1":
        return line
    try:
        numbers = [float(b) for b in bits[2:14]]
    except ValueError:
        return line
    m = _power(quarter)
    p = numbers[0:3]
    rows = (numbers[3:6], numbers[6:9], numbers[9:12])
    p2 = [sum(m[i][k] * p[k] for k in range(3)) for i in range(3)]
    r2 = [[sum(m[i][k] * rows[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
    lead = line[:len(line) - len(line.lstrip())]
    return lead + " ".join(["1", bits[1], *(_number(v) for v in p2),
                            *(_number(v) for row in r2 for v in row), bits[14]])


def turned_text(text: str, quarter: int) -> str:
    """The model file with its first model's placing lines given the quarter turn."""
    if quarter % 4 == 0:
        return text
    out = []
    files = 0
    for line in text.splitlines():
        bits = line.split()
        if bits[:2] == ["0", "FILE"]:
            files += 1
        elif bits[:2] == ["0", "NOFILE"] and files == 1:
            files = 2           # the first model is over
        main = files <= 1
        out.append(turned_line(line, quarter) if main and bits[:1] == ["1"] else line)
    return "\n".join(out) + ("\n" if text.endswith("\n") else "")
