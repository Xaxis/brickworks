"""The judge: Claude, through Claude Code on the subscription, scoring one design.

Each call is shown the same two anchor pictures with the score each
stands for, the subject's references, the design's three views and the
build check's own words, and scores six dimensions 1-10 with a line of
reason each. The reply is held to a JSON schema (--json-schema), and read
here whether it came back as structured output or as text.

The rubric is versioned. Scores under one version compare; across two
they do not, so the summary says which version made each table.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import time
from dataclasses import dataclass
from pathlib import Path

RUBRIC_VERSION = 1

# In the order the table prints them.
DIMENSIONS: tuple[str, ...] = (
    "likeness", "surface", "colour", "technique", "creativity", "buildability")

RUBRIC: dict[str, str] = {
    "likeness": "Likeness, silhouette and proportion: from the references, does it read as "
                "the subject at a glance, with the subject's proportions, from every view?",
    "surface": "Surface elegance: smooth where the subject is smooth (tiles, curved slopes, "
               "SNOT and round parts where the real thing is sleek), studs only where they are "
               "meant (a base, a texture), no staircase where a curve should be.",
    "colour": "Colour and detail: the subject's colours, with tonal variation and fine detail "
              "(greebling, printed or textured parts, accents), and no flat expanse of one colour.",
    "technique": "Technique: the building techniques a real LEGO designer would use for this "
                 "subject at this scale (SNOT, brackets, hinges, clips, Technic where things "
                 "move, sub-assemblies at angles), used well rather than merely present.",
    "creativity": "Creativity: a creative touch, an easter egg, a story detail, a play or "
                  "display feature, a clever use of a part.",
    "buildability": "Buildability, from the build check below: 10 opens whole, one piece (items "
                    "named apart, such as a stand or a figure, are fine) and stands, with no "
                    "fault named; 8 one piece and stands, with a fault named; 6 two or three "
                    "loose pieces or a weak joint; 4 many pieces, or it does not stand; 2 parts "
                    "missing or most of it floating; 1 nothing was built.",
}

SCHEMA: dict = {
    "type": "object",
    "properties": {
        "looked_at": {"type": "array", "items": {"type": "string"},
                      "description": "the file name of every picture you opened"},
        **{dim: {"type": "object",
                 "properties": {"score": {"type": "integer", "minimum": 1, "maximum": 10},
                                "reason": {"type": "string"}},
                 "required": ["score", "reason"]} for dim in DIMENSIONS},
    },
    "required": ["looked_at", *DIMENSIONS],
}


@dataclass(frozen=True, slots=True)
class Picture:
    path: Path
    what: str


@dataclass(frozen=True, slots=True)
class Judgement:
    scores: dict[str, float]
    reasons: dict[str, str]
    looked_at: tuple[str, ...]

    def mean(self) -> float:
        return sum(self.scores[d] for d in DIMENSIONS) / len(DIMENSIONS)

    def as_dict(self) -> dict:
        return {"scores": self.scores, "reasons": self.reasons,
                "looked_at": list(self.looked_at), "mean": round(self.mean(), 2)}


def prompt(title: str, brief: str, scale: str, anchors: tuple[Picture, Picture],
           references: list[Picture], views: list[Picture], parts: int,
           probe: str, high: int, low: int) -> str:
    """Everything the judge is told, in a fixed order, so two calls differ only by the design."""
    lines = [
        "You are judging a LEGO model made by an AI design assistant against what an expert "
        "LEGO set designer would ship. Be strict and be consistent: the same model must get "
        "the same scores every time it is shown to you.",
        "",
        f"THE SUBJECT: {title}. Scale: {scale}.",
        f"The brief the designer was given: \"{brief}\"",
        "",
        "Open every picture below with the Read tool before you score anything.",
        "",
        "CALIBRATION, the same two pictures in every judgement:",
        f"  A. {anchors[0].path}: {anchors[0].what}. This is what {high} looks like on every "
        "visual dimension (likeness, surface, colour, technique, creativity).",
        f"  B. {anchors[1].path}: {anchors[1].what}. This is what {low} looks like on every "
        "visual dimension.",
        "  5 is a competent fan model that reads as its subject but that LEGO would not ship; "
        "10 is better than anything LEGO has made of the subject. A model is not better for "
        "being bigger.",
        "",
    ]
    if references:
        lines.append("REFERENCES for the subject:")
        lines += [f"  {n}. {p.path}: {p.what}" for n, p in enumerate(references, 1)]
    else:
        lines.append("REFERENCES: none could be fetched; judge likeness from what the subject is.")
    lines += [
        "",
        f"THE MODEL, {parts} parts, drawn by the same renderer as the anchors:",
        *[f"  {p.path}: {p.what}" for p in views],
        "",
        "THE BUILD CHECK, the app's own words (for buildability only):",
        *["  " + line for line in probe.strip().splitlines()],
        "",
        "Score each dimension 1-10, an integer, with one sentence saying why that names what you "
        "see in this model rather than generalities:",
        *[f"  {dim}: {RUBRIC[dim]}" for dim in DIMENSIONS],
        "",
        "Reply with only the JSON object the schema asks for, with looked_at listing the file "
        "name of every picture you opened.",
    ]
    return "\n".join(lines)


def _object(text: str) -> dict:
    """The JSON object in a reply's text: bare, fenced, or after a sentence."""
    text = text.strip()
    fenced = re.search(r"```(?:json)?\s*(\{.*?\})\s*```", text, flags=re.S)
    if fenced:
        text = fenced.group(1)
    start, end = text.find("{"), text.rfind("}")
    if start < 0 or end < start:
        raise ValueError("no JSON object in the reply")
    found = json.loads(text[start:end + 1])
    if not isinstance(found, dict):
        raise ValueError("the reply's JSON is not an object")
    return found


def parse(reply: dict | str) -> Judgement:
    """A judge's reply read into scores, or ValueError saying what is wrong with it.

    `reply` is Claude Code's --output-format json result (a dict with
    structured_output or result) or the text of a reply.
    """
    if isinstance(reply, dict) and "type" in reply and reply.get("type") == "result":
        if reply.get("is_error"):
            raise ValueError(f"the judge's call failed: {str(reply.get('result'))[:200]}")
        found = reply.get("structured_output")
        if not isinstance(found, dict):
            found = _object(str(reply.get("result", "")))
    elif isinstance(reply, dict):
        found = reply
    else:
        found = _object(reply)
    if isinstance(found.get("scores"), dict):       # {"scores": {...}} is the same answer
        found = {**found["scores"], "looked_at": found.get("looked_at", [])}
    scores: dict[str, float] = {}
    reasons: dict[str, str] = {}
    for dim in DIMENSIONS:
        said = found.get(dim)
        if isinstance(said, dict):
            score, reason = said.get("score"), said.get("reason", "")
        else:
            score, reason = said, ""
        if isinstance(score, str) and re.fullmatch(r"\s*\d+(\.\d+)?\s*", score):
            score = float(score)
        if isinstance(score, bool) or not isinstance(score, (int, float)):
            raise ValueError(f"no score for {dim}")
        if not 1 <= score <= 10:
            raise ValueError(f"{dim} scored {score}, outside 1-10")
        scores[dim] = float(score)
        reasons[dim] = " ".join(str(reason).split())
    looked = found.get("looked_at", [])
    return Judgement(scores, reasons, tuple(str(x) for x in looked if isinstance(x, str)))


def nothing_built(why: str) -> Judgement:
    """A run that left no model is scored, not skipped: the person got nothing."""
    return Judgement({d: 1.0 for d in DIMENSIONS}, {d: why for d in DIMENSIONS}, ())


def call(text: str, cwd: Path, readable: list[Path], model: str = "opus",
         timeout: int = 900, schema: dict | None = None) -> tuple[dict, float]:
    """Ask Claude Code, on the subscription, with the Read tool and nothing else.

    Billing variables are taken out of the environment so the call is on
    the plan this machine is signed in to, never an API key. `schema` is
    the reply's shape: the 1-10 scores unless the pairwise judge says its own.
    """
    env = {k: v for k, v in os.environ.items()
           if k not in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN")}
    command = ["claude", "-p", text, "--model", model,
               "--tools", "Read", "--allowedTools", "Read",
               "--restricted", "--strict-mcp-config", "--no-session-persistence",
               "--output-format", "json", "--json-schema", json.dumps(schema or SCHEMA)]
    for path in readable:
        command += ["--add-dir", str(path)]
    started = time.time()
    done = subprocess.run(command, cwd=cwd, env=env, capture_output=True, text=True,
                          timeout=timeout)
    took = time.time() - started
    if done.returncode != 0 and not done.stdout.strip():
        raise RuntimeError(f"claude exited {done.returncode}: {done.stderr.strip()[:300]}")
    return json.loads(done.stdout), took
