"""Turning a sentence into a model that can actually be built.

The design is Claude's; the geometry is not.  The model proposes
placements in brick coordinates and a deterministic validator resolves
every one against the real catalogue and the real lattice.  Anything that
overlaps, floats or falls off is handed back with the specific brick and
the specific reason, and it tries again.

That split is deliberate, and it is where most of the quality comes from.
A language model is good at what a dragon looks like and bad at whether
brick 214 clears brick 87; the validator is the reverse.  Neither is
asked to do the other's job.

Two tools are offered rather than one:

``search_parts``
    The catalogue has 24,731 entries and cannot go in a prompt.  A short
    starter palette covers most building, and search reaches the rest —
    so the model can look for "slope 45 2x2" instead of guessing a
    number.  Guessed part numbers are the most common single failure.

``check_design``
    Lets it check its own work mid-flight rather than at the end.  A
    wall that turns out to be four separate towers is much cheaper to
    fix while it is still being laid.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Callable

import anthropic

from .catalogue import Catalogue, load
from .model import Model, Placement
from .validate import Report, check

MODEL = "claude-opus-5"

# A starter bin: the parts most building is actually done with, chosen so
# the model can build without searching for anything. Everything else is
# a search away.
PALETTE: tuple[str, ...] = (
    # bricks
    "3005", "3004", "3622", "3010", "3009", "3008",
    "3003", "3002", "3001", "2456", "3007", "3006",
    # plates
    "3024", "3023", "3623", "3710", "3666", "3460",
    "3022", "3021", "3020", "3795", "3034", "3031", "3032", "3035",
    # tiles
    "3070b", "3069b", "63864", "2431", "3068b", "6179",
    # slopes and shaping
    "54200", "3040b", "3039", "3665", "3660", "4286", "3298",
    "3045", "3049", "6091", "11477", "15068",
    # useful odds
    "3062b", "4073", "6141", "3941", "4070", "87087", "60481", "3958",
)

# Colours worth naming. A model that can name a colour picks better ones
# than one choosing from 322 numbers.
COLORS: tuple[int, ...] = (
    0, 15, 4, 1, 2, 14, 25, 26, 27, 28, 70, 71, 72, 19, 5, 6,
    7, 8, 84, 85, 191, 226, 212, 288, 308, 320, 321, 322, 326, 484,
)

SYSTEM = """\
You design models out of real bricks. Your designs get built, so they have \
to hold together.

COORDINATES
Positions are in brick units, not millimetres.
  x and z count studs across the baseplate.
  y counts plates upward from the ground, which is y=0.
  A brick is 3 plates tall. A plate is 1. A tile is 1.
  x, y, z is the LOW CORNER of the part's footprint, not its centre.
  A 2x4 brick at x=0,z=0 covers studs 0..3 across and 0..1 deep.
  rot is quarter turns about the vertical axis: 0, 1, 2 or 3. Rotating \
swaps the footprint but does not move the corner.

So a 2x4 brick at y=0 occupies plates 0,1,2. The next brick on top of it \
goes at y=3. Two bricks side by side at y=0 go at x=0 and x=4.

THE RULES YOUR DESIGN MUST SATISFY
1. Nothing may overlap. Two parts cannot share space.
2. Nothing may float. Every part needs the ground (y=0) or another part \
directly beneath it.
3. The model must be ONE connected thing. Parts that merely sit side by \
side are NOT connected — only stacking connects them.

Rule 3 is the one that catches people. A wall built as separate stacked \
columns is not a wall, it is several towers. Stagger the joints: offset \
alternate courses so each part bridges the seam below it, exactly as you \
would with real bricks. This is the single most important habit.

HOW TO WORK
Think about the shape first, then lay it out layer by layer from the \
ground up. Keep a clear idea of what each layer is for.

Use search_parts when you want something you cannot name — a slope, a \
curve, a round plate. Do not guess part numbers; a guessed number is not \
a part and the design will be rejected.

Use check_design as you go, not only at the end. Checking a partial model \
is cheap and tells you whether the structure is sound before you detail it.

WHAT MAKES A MODEL GOOD
Shape reads before detail does. Get the silhouette right first.
Vary the colour with purpose, not at random.
Use slopes and tiles to break up the staircase that stacked bricks make.
A smaller model that reads clearly beats a larger one that does not.

Finish by calling submit_design with the complete list of parts."""


@dataclass
class DesignResult:
    model: Model
    report: Report
    rounds: int = 0
    tool_calls: int = 0
    input_tokens: int = 0
    output_tokens: int = 0
    transcript: list[str] = field(default_factory=list)

    @property
    def ok(self) -> bool:
        return self.report.ok


def _tools() -> list[dict[str, Any]]:
    return [
        {
            "name": "search_parts",
            "description": (
                "Find real parts by description. Returns part numbers with "
                "their footprint and height. Use this instead of guessing a "
                "part number."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": (
                            "Words that would appear in the part's name, e.g. "
                            "'slope 45 2 x 2' or 'plate 1 x 4' or 'round brick'"
                        ),
                    },
                    "limit": {"type": "integer", "default": 15},
                },
                "required": ["query"],
                "additionalProperties": False,
            },
            "strict": True,
        },
        {
            "name": "check_design",
            "description": (
                "Check a list of parts for overlaps, floating parts and "
                "whether it is one connected model. Safe to call on a "
                "partial design while you work."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "bricks": {"type": "array", "items": _brick_schema()},
                },
                "required": ["bricks"],
                "additionalProperties": False,
            },
            "strict": True,
        },
        {
            "name": "submit_design",
            "description": (
                "Submit the finished model. Call this once, with every part."
            ),
            "input_schema": {
                "type": "object",
                "properties": {
                    "name": {"type": "string"},
                    "description": {
                        "type": "string",
                        "description": "One sentence on what was built and how.",
                    },
                    "bricks": {"type": "array", "items": _brick_schema()},
                },
                "required": ["name", "description", "bricks"],
                "additionalProperties": False,
            },
            "strict": True,
        },
    ]


def _brick_schema() -> dict[str, Any]:
    return {
        "type": "object",
        "properties": {
            "part": {"type": "string", "description": "part number, e.g. 3001"},
            "color": {"type": "integer", "description": "LDraw colour code"},
            "x": {"type": "integer", "description": "studs across"},
            "y": {"type": "integer", "description": "plates up from ground"},
            "z": {"type": "integer", "description": "studs deep"},
            "rot": {"type": "integer", "description": "quarter turns, 0-3"},
        },
        "required": ["part", "color", "x", "y", "z", "rot"],
        "additionalProperties": False,
    }


def _palette_text(catalogue: Catalogue) -> str:
    lines = ["Parts you can use without searching:"]
    for part_id in PALETTE:
        part = catalogue.get(part_id)
        if part is not None:
            lines.append("  " + part.describe())
    lines.append("")
    lines.append("Colours (code: name):")
    names = []
    for code in COLORS:
        entry = catalogue.colors.get(code)
        if entry:
            names.append(f"{code}: {entry['name']}")
    lines.append("  " + ", ".join(names))
    return "\n".join(lines)


def design(
    brief: str,
    *,
    catalogue: Catalogue | None = None,
    client: anthropic.Anthropic | None = None,
    max_repairs: int = 3,
    max_turns: int = 24,
    effort: str = "high",
    max_tokens: int = 32000,
    on_event: Callable[[str], None] | None = None,
) -> DesignResult:
    """Design a model from a brief, checking and repairing until it holds.

    Two limits, counting different things, because conflating them was a
    bug: ``max_turns`` bounds the conversation, most of which is the model
    looking parts up, and ``max_repairs`` bounds how many times a design
    that failed validation is handed back. Counting searches against the
    repair budget meant a careful design ran out of attempts before it had
    submitted anything at all.

    Returns whatever the last attempt produced even when it does not fully
    validate: a model with three floating bricks is worth looking at and
    saying so, and is more useful than an exception.
    """
    catalogue = catalogue or load()
    client = client or _client()

    def say(text: str) -> None:
        if on_event:
            on_event(text)

    system = [
        {"type": "text", "text": SYSTEM},
        # The palette is long and identical every time, so it is worth a
        # cache breakpoint; the brief that follows is not.
        {
            "type": "text",
            "text": _palette_text(catalogue),
            "cache_control": {"type": "ephemeral"},
        },
    ]

    messages: list[dict[str, Any]] = [
        {"role": "user", "content": f"Build this: {brief}"}
    ]

    result = DesignResult(model=Model(name=brief[:60]), report=Report())
    submitted: Model | None = None
    repairs = 0
    ever_submitted = False

    for _turn in range(max_turns):
        say(f"turn {_turn + 1}")

        response = _call(client, system, messages, effort, max_tokens)
        result.input_tokens += response.usage.input_tokens
        result.output_tokens += response.usage.output_tokens

        if response.stop_reason == "refusal":
            result.transcript.append("the model declined this brief")
            break

        messages.append({"role": "assistant", "content": response.content})

        tool_results: list[dict[str, Any]] = []
        for block in response.content:
            if block.type == "text" and block.text.strip():
                result.transcript.append(block.text.strip())
            if block.type != "tool_use":
                continue

            result.tool_calls += 1
            payload, model_out = _run_tool(block, catalogue, say)
            if model_out is not None:
                submitted = model_out
            tool_results.append({
                "type": "tool_result",
                "tool_use_id": block.id,
                "content": payload,
            })

        if not tool_results:
            # Nothing was called and nothing submitted: it has finished
            # talking, so stop rather than prompt it round again.
            if not ever_submitted:
                result.transcript.append(
                    "stopped without submitting a design")
            break

        messages.append({"role": "user", "content": tool_results})

        if submitted is None:
            continue

        ever_submitted = True
        report = check(submitted, catalogue)
        result.model = submitted
        result.report = report
        result.rounds = repairs + 1
        say(f"checked: {report.summary()}")

        if report.ok:
            return result

        if repairs >= max_repairs:
            say("out of repair attempts; returning the best it managed")
            break

        # Hand back exactly what is wrong and let it repair.
        repairs += 1
        submitted = None
        messages.append({
            "role": "user",
            "content": (
                "That design does not hold together yet:\n\n"
                f"{report.as_feedback()}\n\n"
                "Fix those specific parts and submit the whole design again. "
                "Remember that parts side by side are not connected — only "
                "stacking connects them, so stagger the joints."
            ),
        })

    if submitted is not None:
        result.model = submitted
        result.report = check(submitted, catalogue)
    return result


def _call(
    client: anthropic.Anthropic,
    system: list[dict[str, Any]],
    messages: list[dict[str, Any]],
    effort: str,
    max_tokens: int,
) -> Any:
    """One turn. Streamed, because a long design can outlast an HTTP timeout."""
    with client.messages.stream(
        model=MODEL,
        max_tokens=max_tokens,
        system=system,
        messages=messages,
        tools=_tools(),
        thinking={"type": "adaptive"},
        output_config={"effort": effort},
    ) as stream:
        return stream.get_final_message()


def _run_tool(
    block: Any, catalogue: Catalogue, say: Callable[[str], None]
) -> tuple[str, Model | None]:
    """Execute one tool call. Returns (result text, submitted model or None)."""
    name = block.name
    args = block.input if isinstance(block.input, dict) else {}

    if name == "search_parts":
        query = str(args.get("query", ""))
        limit = int(args.get("limit", 15) or 15)
        found = catalogue.search(query, limit=limit)
        say(f"search '{query}' -> {len(found)}")
        if not found:
            return (f"No parts match '{query}'. Try fewer or plainer words.", None)
        return ("\n".join(p.describe() for p in found), None)

    if name == "check_design":
        model = Model(placements=[
            Placement.from_dict(b) for b in args.get("bricks", [])])
        report = check(model, catalogue)
        say(f"check {len(model)} bricks -> {report.summary()}")
        return (report.as_feedback(), None)

    if name == "submit_design":
        model = Model(
            name=str(args.get("name", "Model")),
            description=str(args.get("description", "")),
            placements=[
                Placement.from_dict(b) for b in args.get("bricks", [])],
        )
        say(f"submitted {len(model)} bricks")
        return ("Received. Checking it now.", model)

    return (f"No tool called {name}.", None)


def _client() -> anthropic.Anthropic:
    """Build a client, finding the key the way this project stores it."""
    key = os.environ.get("ANTHROPIC_API_KEY")
    if not key:
        key = _key_from_env_files()
    if key:
        return anthropic.Anthropic(api_key=key)
    # No key found: let the SDK resolve a profile or raise its own error,
    # which says more about what is missing than anything written here.
    return anthropic.Anthropic()


def _key_from_env_files() -> str | None:
    """Look in the .env files this machine keeps credentials in."""
    candidates = [
        Path.home() / "Projects" / "soniq" / "backend" / ".env",
        Path(__file__).resolve().parent.parent / ".env",
    ]
    for path in candidates:
        if not path.exists():
            continue
        for line in path.read_text().splitlines():
            for prefix in ("AI__ANTHROPIC_API_KEY=", "ANTHROPIC_API_KEY="):
                if line.startswith(prefix):
                    return line[len(prefix):].strip().strip('"').strip("'")
    return None
