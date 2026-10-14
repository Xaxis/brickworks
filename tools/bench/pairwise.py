"""The pairwise judge: of two designs of one subject, which is better, and by how much.

A 1-10 score moves by 0.7-1.0 between two designs made on the same code,
so most rounds' changes land inside the noise and nobody can tell a gain
from luck. Asked which of two is better, a judge resolves differences an
integer score ties: on 24 pairs whose answer is known it was right on all
64 known dimensions, where the 1-10 judge tied or reversed 12
(docs/DESIGN_SCORES.md, "Judged in pairs"). BrickBench judges this way,
and its judge agreed with 102 people on 34 of 36 pairs
[https://arxiv.org/html/2610.12452v1]. This is its method, on our designs:

- Two designs of one subject, three views each from the same cameras, the
  subject's references and each build check's words. The pictures are
  copied under names that say nothing (no batch, no date, no round).
- The answer is forced, A or B, per dimension and overall, with a
  sentence of reason. Each pair is asked in both orders, so a judge that
  leans to the first picture (or the second) cancels; a pair that splits
  between its two orders is the judge's tie.
- Bradley-Terry strengths per subject by Hunter's MM, with half a virtual
  tie between every two designs so that one which wins everything still
  has a finite strength (as BrickBench's elo.py). Reported as ELO: 400 /
  ln 10 a unit of log strength, the subject's designs centred on 1000. A
  gap of 100 is a 64% chance of being preferred, 200 is 76%.
- 95% intervals from 1,000 resamplings of the pairs, both orders kept
  together, as BrickBench resamples its prompts (drawn again from the fit
  for a subject of two or three designs).
- A lever's change across subjects carries two intervals: the judge's own,
  and one with the run-to-run spread of a design in it, which is the larger
  (194 ELO a design against the judge's ~45, measured 2026-10-14).

Everything here is pure: the prompt, the reply, the fit, the intervals,
a lever's effect across subjects, and the agreement on pairs whose
answer is known. tools/bench/run.py does the calls and the files.
"""

from __future__ import annotations

import hashlib
import math
import random
import re
import statistics
from dataclasses import dataclass, field

from bench import judge

# The judge's six dimensions, then the one BrickBench asks: which is better.
DIMENSIONS: tuple[str, ...] = (*judge.DIMENSIONS, "overall")
PICK = ("A", "B")
ELO_UNIT = 400.0 / math.log(10.0)
CENTRE = 1000.0
# Half a virtual tie: a quarter of a win each way, between every two designs.
PRIOR = 0.25
DRAWS = 1000

RUBRIC: dict[str, str] = {
    "likeness": "Likeness, silhouette and proportion: from the references, which reads as the "
                "subject at a glance, with the subject's proportions, from every view?",
    "surface": "Surface elegance: which is smooth where the subject is smooth (tiles, curved "
               "slopes, SNOT and round parts where the real thing is sleek), with studs only "
               "where they are meant and no staircase where a curve should be?",
    "colour": "Colour and detail: which has the subject's colours, with tonal variation and "
              "fine detail (greebling, printed or textured parts, accents), and no flat "
              "expanse of one colour?",
    "technique": "Technique: which uses the building techniques a LEGO® set designer would "
                 "use for this subject at this scale (SNOT, brackets, hinges, clips, Technic "
                 "where things move, sub-assemblies at angles), and uses them well rather than "
                 "merely having them?",
    "creativity": "Creativity: which has the better creative touch: an easter egg, a story "
                  "detail, a play or display feature, a clever use of a part?",
    "buildability": "Buildability, from each model's build check: one piece that stands with no "
                    "fault named (items named apart, such as a stand or a figure, are fine) "
                    "beats one with a fault named, which beats loose pieces or a model that "
                    "does not stand. When the two checks say the same, the one whose pictures "
                    "show the sturdier build.",
    "overall": "Overall: which of the two would a LEGO® set designer rather ship as this "
               "subject, everything considered?",
}

SCHEMA: dict = {
    "type": "object",
    "properties": {
        "looked_at": {"type": "array", "items": {"type": "string"},
                      "description": "the file name of every picture you opened"},
        **{dim: {"type": "object",
                 "properties": {"better": {"type": "string", "enum": list(PICK)},
                                "reason": {"type": "string"}},
                 "required": ["better", "reason"]} for dim in DIMENSIONS},
    },
    "required": ["looked_at", *DIMENSIONS],
}


# -- the question ---------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Shown:
    """One side of a pair as the judge sees it: its pictures, its size, its check."""

    views: tuple[judge.Picture, ...]
    parts: int
    probe: str      # the build check's verdict lines, or "" when it was not run


def prompt(title: str, brief: str, scale: str, references: list[judge.Picture],
           a: Shown, b: Shown) -> str:
    """Everything the judge is told, in a fixed order: two calls differ only by the pair."""
    lines = [
        "You are comparing two LEGO® models of the same subject, A and B, each made by an AI "
        "design assistant, as a LEGO® set designer would judge them. Be strict and be "
        "consistent: the same two models must get the same answers every time.",
        "",
        f"THE SUBJECT: {title}. Scale: {scale}.",
        f"The brief both were given: \"{brief}\"",
        "",
        "Open every picture below with the Read tool before you answer anything.",
        "",
    ]
    if references:
        lines.append("REFERENCES for the subject:")
        lines += [f"  {n}. {p.path}: {p.what}" for n, p in enumerate(references, 1)]
    else:
        lines.append("REFERENCES: none; judge likeness from what the subject is.")
    for name, side in (("A", a), ("B", b)):
        lines += ["", f"MODEL {name}, {side.parts} parts:",
                  *[f"  {p.path}: {p.what}" for p in side.views]]
        if side.probe.strip():
            lines += [f"  The build check's words for {name}:",
                      *["    " + line.strip() for line in side.probe.strip().splitlines()]]
        else:
            lines.append(f"  No build check was run for {name}; judge buildability from its "
                         "pictures.")
    lines += [
        "",
        "Both were drawn by the same renderer from the same views, so picture quality says "
        "nothing. A model is not better for being bigger or for having more parts. The order "
        "means nothing either: you are shown the same two the other way round as well.",
        "",
        "For each dimension say which model is better, A or B, and give one sentence naming "
        "what you see in the two that decides it. You must choose one even when they are "
        "close: pick the one that is better on that dimension, however slightly.",
        *[f"  {dim}: {RUBRIC[dim]}" for dim in DIMENSIONS],
        "",
        "Reply with only the JSON object the schema asks for, with looked_at listing the file "
        "name of every picture you opened.",
    ]
    return "\n".join(lines)


# -- the reply ------------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Verdict:
    """One ordered judgement: who was shown as A, who as B, and who won each dimension."""

    first: str                  # the design shown as A
    second: str                 # the design shown as B
    winners: dict[str, str]     # dimension -> the winning design's key
    reasons: dict[str, str]
    looked_at: tuple[str, ...] = ()

    def picked_first(self, dim: str) -> bool:
        return self.winners[dim] == self.first

    def as_dict(self) -> dict:
        return {"first": self.first, "second": self.second, "winners": self.winners,
                "reasons": self.reasons, "looked_at": list(self.looked_at)}

    @staticmethod
    def from_dict(said: dict) -> "Verdict":
        return Verdict(said["first"], said["second"], dict(said["winners"]),
                       dict(said.get("reasons", {})), tuple(said.get("looked_at", ())))


def _side(said: object) -> str | None:
    """'A' or 'B' from what the judge wrote: "A", " b ", "Model A". Anything else is None."""
    if not isinstance(said, str):
        return None
    word = re.sub(r"^(model|design)\s+", "", said.strip(), flags=re.I).strip(" .").upper()
    return word if word in PICK else None


def parse(reply: dict | str, first: str, second: str) -> Verdict:
    """A judge's reply read into a winner per dimension, or ValueError saying what is wrong.

    `first` and `second` are the keys of the designs shown as A and B.
    """
    if isinstance(reply, dict) and reply.get("type") == "result":
        if reply.get("is_error"):
            raise ValueError(f"the judge's call failed: {str(reply.get('result'))[:200]}")
        found = reply.get("structured_output")
        if not isinstance(found, dict):
            found = judge._object(str(reply.get("result", "")))
    elif isinstance(reply, dict):
        found = reply
    else:
        found = judge._object(reply)
    winners: dict[str, str] = {}
    reasons: dict[str, str] = {}
    for dim in DIMENSIONS:
        said = found.get(dim)
        pick, reason = (said.get("better"), said.get("reason", "")) if isinstance(said, dict) \
            else (said, "")
        side = _side(pick)
        if side is None:
            raise ValueError(f"no A or B for {dim}: {str(pick)[:40]!r}")
        winners[dim] = first if side == "A" else second
        reasons[dim] = " ".join(str(reason).split())
    looked = found.get("looked_at", [])
    return Verdict(first, second, winners, reasons,
                   tuple(str(x) for x in looked if isinstance(x, str)))


# -- Bradley-Terry --------------------------------------------------------


def wins(verdicts: list[Verdict], dim: str) -> dict[tuple[str, str], float]:
    """(winner, loser) -> how many times, on one dimension."""
    out: dict[tuple[str, str], float] = {}
    for v in verdicts:
        loser = v.second if v.winners[dim] == v.first else v.first
        key = (v.winners[dim], loser)
        out[key] = out.get(key, 0.0) + 1.0
    return out


def fit(keys: list[str], won: dict[tuple[str, str], float], prior: float = PRIOR,
        tolerance: float = 1e-9, most: int = 20000) -> dict[str, float]:
    """Bradley-Terry log strengths by Hunter's MM, centred on a mean of 0.

    `won[(i, j)]` is how often i beat j. Every two designs get `prior` wins
    each way, so the fit is finite when one design wins every pair and a
    design with no pairs sits at the mean.
    """
    n = len(keys)
    index = {k: i for i, k in enumerate(keys)}
    w = [[0.0] * n for _ in range(n)]
    for (a, b), count in won.items():
        if a in index and b in index and a != b:
            w[index[a]][index[b]] += count
    for i in range(n):
        for j in range(n):
            if i != j:
                w[i][j] += prior
    games = [[w[i][j] + w[j][i] for j in range(n)] for i in range(n)]
    total = [sum(row) for row in w]
    strength = [1.0] * n
    for _ in range(most):
        new = []
        for i in range(n):
            denominator = sum(games[i][j] / (strength[i] + strength[j])
                              for j in range(n) if j != i)
            new.append(total[i] / denominator if denominator > 0 else strength[i])
        centre = math.exp(sum(math.log(s) for s in new) / n)
        new = [s / centre for s in new]
        moved = max(abs(math.log(a) - math.log(b)) for a, b in zip(new, strength))
        strength = new
        if moved < tolerance:
            break
    return {k: math.log(strength[index[k]]) for k in keys}


def elo(log_strength: float) -> float:
    return CENTRE + ELO_UNIT * log_strength


def chance(elo_gap: float) -> float:
    """The chance the stronger of two designs this far apart is preferred."""
    return 1.0 / (1.0 + 10.0 ** (-elo_gap / 400.0))


def _pairs(verdicts: list[Verdict]) -> dict[frozenset, list[Verdict]]:
    """The verdicts grouped by their unordered pair, so both orders resample together."""
    out: dict[frozenset, list[Verdict]] = {}
    for v in verdicts:
        out.setdefault(frozenset((v.first, v.second)), []).append(v)
    return out


@dataclass(slots=True)
class Ranking:
    """One subject's designs on one dimension: ELO, interval, and the draws behind it."""

    dim: str
    elo: dict[str, float]
    low: dict[str, float]
    high: dict[str, float]
    draws: list[dict[str, float]] = field(repr=False, default_factory=list)

    def order(self) -> list[str]:
        return sorted(self.elo, key=lambda k: -self.elo[k])


def _percentile(values: list[float], q: float) -> float:
    ordered = sorted(values)
    at = q * (len(ordered) - 1)
    lo, hi = math.floor(at), math.ceil(at)
    return ordered[lo] + (ordered[hi] - ordered[lo]) * (at - lo)


# Fewer pairs than this and resampling them says nothing (one pair resampled is
# that pair every time): each verdict is drawn again from the fit instead.
FEWEST_PAIRS = 6


def rank(keys: list[str], verdicts: list[Verdict], dim: str, draws: int = DRAWS,
         seed: int = 0) -> Ranking:
    """ELO per design on one dimension, with a 95% interval from resampled pairs.

    With fewer than FEWEST_PAIRS pairs (a subject with two or three
    designs), the interval is parametric: every verdict drawn again with
    the chance the fitted strengths give it.
    """
    point = {k: elo(s) for k, s in fit(keys, wins(verdicts, dim)).items()}
    grouped = list(_pairs(verdicts).values())
    rng = random.Random(f"{seed}:{dim}")
    sampled: list[dict[str, float]] = []
    for _ in range(draws if grouped else 0):
        if len(grouped) >= FEWEST_PAIRS:
            chosen = [v for _ in grouped for v in rng.choice(grouped)]
        else:
            chosen = []
            for v in verdicts:
                won = rng.random() < chance(point[v.first] - point[v.second])
                chosen.append(Verdict(v.first, v.second,
                                      {dim: v.first if won else v.second}, {}))
        sampled.append({k: elo(s) for k, s in fit(keys, wins(chosen, dim)).items()})
    if not sampled:
        return Ranking(dim, point, dict(point), dict(point), [])
    return Ranking(dim, point,
                   {k: _percentile([d[k] for d in sampled], 0.025) for k in keys},
                   {k: _percentile([d[k] for d in sampled], 0.975) for k in keys},
                   sampled)


# -- reading rounds -------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Effect:
    """A lever's change in ELO, the mean over subjects of after minus before."""

    lever: str
    dim: str
    subjects: tuple[str, ...]
    mean: float
    low: float              # the judge's 95% interval: could these designs be told apart?
    high: float
    low_runs: float         # with the run-to-run spread in it: is the lever real?
    high_runs: float
    per_subject: dict[str, float]


def _round_mean(draw: dict[str, float], keys: list[str]) -> float:
    return sum(draw[k] for k in keys) / len(keys)


def effect(lever: str, dim: str, rankings: dict[str, Ranking],
           groups: dict[str, tuple[list[str], list[str]]], run_sd: float,
           seed: int = 0) -> Effect | None:
    """How far a round moved its subjects on one dimension, with two intervals.

    `groups[subject]` is (the designs before, the designs after). The
    judge's interval comes from the same draws as each subject's ranking.
    A round is one design a subject, and a design varies run to run by
    `run_sd` ELO on the same code; the second interval adds that, so a
    lever is called real only when its gain outruns the luck of a design.
    """
    used = [s for s, (before, after) in groups.items()
            if before and after and s in rankings and rankings[s].draws]
    if not used:
        return None
    per = {s: _round_mean(rankings[s].elo, groups[s][1]) - _round_mean(rankings[s].elo, groups[s][0])
           for s in used}
    count = min(len(rankings[s].draws) for s in used)
    rng = random.Random(f"{seed}:{lever}:{dim}")
    judged, with_runs = [], []
    for k in range(count):
        gaps, luck = [], []
        for s in used:
            before, after = groups[s]
            draw = rankings[s].draws[k]
            gaps.append(_round_mean(draw, after) - _round_mean(draw, before))
            spread = run_sd * math.sqrt(1.0 / len(after) + 1.0 / len(before))
            luck.append(rng.gauss(0.0, spread))
        judged.append(sum(gaps) / len(gaps))
        with_runs.append(sum(g + e for g, e in zip(gaps, luck)) / len(gaps))
    return Effect(lever, dim, tuple(used), sum(per.values()) / len(per),
                  _percentile(judged, 0.025), _percentile(judged, 0.975),
                  _percentile(with_runs, 0.025), _percentile(with_runs, 0.975), per)


def run_spread(rankings: dict[str, Ranking], twins: dict[str, list[list[str]]]) -> float | None:
    """The ELO standard deviation of one design about its code's mean, from repeated runs.

    `twins[subject]` lists groups of designs made on the same code. Each
    group's variance about its own mean, pooled over every group: what a
    second design of the same brief on the same code is worth, in ELO.
    """
    squares, freedom = 0.0, 0
    for subject, groups in twins.items():
        if subject not in rankings:
            continue
        for group in groups:
            if len(group) < 2:
                continue
            values = [rankings[subject].elo[k] for k in group]
            mean = sum(values) / len(values)
            squares += sum((v - mean) ** 2 for v in values)
            freedom += len(values) - 1
    return math.sqrt(squares / freedom) if freedom else None


# -- calibration ----------------------------------------------------------


@dataclass(frozen=True, slots=True)
class Known:
    """A pair whose answer is known: `better` should win each dimension in `dims`."""

    id: str
    kind: str               # "real set against its naive stack", "tiles taken off", ...
    better: str
    worse: str
    dims: tuple[str, ...]


def agreement(known: list[Known], verdicts: list[Verdict]) -> dict:
    """How often the judge names the known winner, in one order, in both, and again.

    - a verdict agrees when it names the known winner on a known dimension;
    - a pair agrees when every verdict on it does in both orders, splits when
      its orders disagree, and is wrong when both name the loser;
    - the orders agree when the two orders of one repeat name the same design,
      on every dimension, known or not;
    - a repeat agrees when the same order asked again names the same design.
    """
    by_pair = _pairs(verdicts)
    single = {"agree": 0, "of": 0}
    kinds: dict[str, dict[str, int]] = {}
    pairs = {"agree": 0, "split": 0, "wrong": 0}
    per_dim: dict[str, dict[str, int]] = {}
    for k in known:
        said = by_pair.get(frozenset((k.better, k.worse)), [])
        tally = kinds.setdefault(k.kind, {"agree": 0, "of": 0, "pairs": 0, "pairs_agree": 0})
        for dim in k.dims:
            right = [v.winners[dim] == k.better for v in said]
            if not right:
                continue
            single["agree"] += sum(right)
            single["of"] += len(right)
            tally["agree"] += sum(right)
            tally["of"] += len(right)
            d = per_dim.setdefault(dim, {"agree": 0, "of": 0})
            d["agree"] += sum(right)
            d["of"] += len(right)
            share = sum(right) / len(right)
            pairs["agree" if share == 1 else "wrong" if share == 0 else "split"] += 1
            tally["pairs"] += 1
            tally["pairs_agree"] += share == 1
    orders = {"same": 0, "of": 0}
    repeats = {"same": 0, "of": 0}
    first_pick = {"A": 0, "of": 0}
    for said in by_pair.values():
        by_order: dict[tuple[str, str], list[Verdict]] = {}
        for v in said:
            by_order.setdefault((v.first, v.second), []).append(v)
        ways = list(by_order.values())
        for dim in DIMENSIONS:
            for v in said:
                first_pick["A"] += v.picked_first(dim)
                first_pick["of"] += 1
            for same in ways:
                for x, y in zip(same, same[1:]):
                    repeats["same"] += x.winners[dim] == y.winners[dim]
                    repeats["of"] += 1
            if len(ways) == 2:
                for x, y in zip(ways[0], ways[1]):
                    orders["same"] += x.winners[dim] == y.winners[dim]
                    orders["of"] += 1
    return {"verdicts": single, "pairs": pairs, "kinds": kinds, "dims": per_dim,
            "orders": orders, "repeats": repeats, "first_pick": first_pick}


def share(part: int, whole: int) -> str:
    return f"{part} of {whole} ({100.0 * part / whole:.0f}%)" if whole else "none"


def wilson(part: int, whole: int, z: float = 1.96) -> tuple[float, float]:
    """A 95% interval for a share, which stays inside 0-1 at 0 and at all."""
    if not whole:
        return (0.0, 1.0)
    p = part / whole
    centre = (p + z * z / (2 * whole)) / (1 + z * z / whole)
    half = z * math.sqrt(p * (1 - p) / whole + z * z / (4 * whole * whole)) / (1 + z * z / whole)
    return (max(0.0, centre - half), min(1.0, centre + half))


def mean_abs(values: list[float]) -> float:
    return statistics.mean(abs(v) for v in values) if values else float("nan")


def opaque(key: str) -> str:
    """A design's name for the judge: six letters that say nothing of its round."""
    return hashlib.sha256(key.encode()).hexdigest()[:6]
