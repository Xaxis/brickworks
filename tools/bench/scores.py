"""Reading a run's outputs into a record, and a batch of records into a table.

A record is one design of one subject: what the build check said, how
tools/style.py measured it, and what the judge scored. A batch is every
record under bench/results/<date>/; its summary is a score per subject
(the mean over its runs), the suite's mean, the run-to-run spread of the
subjects run more than once, and the three weakest dimensions across the
suite, which is what the next design round should attack.
"""

from __future__ import annotations

import json
import re
import statistics
from pathlib import Path

from bench.judge import DIMENSIONS

SHORT = {"likeness": "likeness", "surface": "surface", "colour": "colour",
         "technique": "technique", "creativity": "creative", "buildability": "build"}


# -- the build check ------------------------------------------------------


def read_probe(text: str) -> dict:
    """src/dev/candidate_probe.gd's output, read into facts.

    A probe that crashed or never ran says none of its lines; that is
    `ran: False`, not a model that failed every check.
    """
    found: dict = {"ran": False, "opens": None, "parts": None, "missing": None,
                   "buildable": None, "pieces": None, "named_apart": [], "stands": None,
                   "faults": [], "shared_faults": [], "candidate": None}
    for raw in text.splitlines():
        line = raw.strip()
        verdict = re.match(r"(ok|FAIL)\s+(.*)", line)
        if verdict:
            ok, what = verdict.group(1) == "ok", verdict.group(2)
            if what.startswith("it opens whole:"):
                found["ran"] = True
                found["opens"] = ok
                parts = re.search(r"(\d+) parts", what)
                missing = re.search(r"library \((\d+)\)", what)
                found["parts"] = int(parts.group(1)) if parts else None
                found["missing"] = int(missing.group(1)) if missing else None
            elif what.startswith("it is buildable, in one piece:"):
                found["buildable"] = ok
                body, _, apart = what.partition(" (apart as named: ")
                pieces = re.findall(r"(\d+) pieces?\b", body)
                found["pieces"] = int(pieces[-1]) if pieces else None
                if apart:
                    found["named_apart"] = [n.strip() for n in apart.rstrip(")").split(",")]
            elif what.startswith("it stands up:"):
                found["stands"] = ok
            elif what.startswith("the check does not call it ") and not ok:
                found["faults"].append(what.removeprefix("the check does not call it "))
            elif what.startswith("not counted: called "):
                found["shared_faults"].append(
                    what.removeprefix("not counted: called ").split(", as ")[0])
        elif line.startswith("still "):     # as the probe said it before 2026-10-13
            found["shared_faults"].append(line.removeprefix("still ").split(", as ")[0])
        elif line == "a candidate":
            found["candidate"] = True
        elif line.startswith("not a candidate"):
            found["candidate"] = False
    return found


def save_times(log: str) -> list[float]:
    """When a design session saved, in seconds from its start, from its progress lines.

    The app prints each tool call as `  [ 209.0s] saving`; the file a
    save writes has no other trace in the log unless the session names it.
    """
    return [float(m.group(1)) for m in re.finditer(r"^\s*\[\s*([\d.]+)s\] saving\s*$", log, re.M)]


# -- a batch --------------------------------------------------------------


def collect(batch: Path) -> list[dict]:
    """Every record under a batch folder, in subject then run order."""
    return [json.loads(p.read_text()) for p in sorted(batch.glob("*/*/record.json"))]


def _mean(values: list[float]) -> float:
    return sum(values) / len(values) if values else float("nan")


def summarise(records: list[dict]) -> dict:
    """Per subject the mean of its runs, the suite's mean, the spread and the weakest."""
    judged = [r for r in records if r.get("judge") and r["judge"].get("scores")]
    subjects: dict[str, list[dict]] = {}
    for record in judged:
        subjects.setdefault(record["subject"], []).append(record)
    rows = []
    for subject, runs in subjects.items():
        runs.sort(key=lambda r: r["run"])
        dims = {d: _mean([r["judge"]["scores"][d] for r in runs]) for d in DIMENSIONS}
        rows.append({
            "subject": subject, "runs": len(runs), "scores": dims, "mean": _mean(list(dims.values())),
            "parts": _mean([float(r.get("probe", {}).get("parts") or 0) for r in runs]),
            "pieces": [r.get("probe", {}).get("pieces") for r in runs],
            "failed": [r["run"] for r in runs if not r.get("design", {}).get("model")],
            "reasons": runs[0]["judge"].get("reasons", {}),
        })
    suite = {d: _mean([row["scores"][d] for row in rows]) for d in DIMENSIONS}
    repeats = []
    for subject, runs in subjects.items():
        if len(runs) < 2:
            continue
        per_dim = {d: [r["judge"]["scores"][d] for r in runs] for d in DIMENSIONS}
        means = [_mean([r["judge"]["scores"][d] for d in DIMENSIONS]) for r in runs]
        repeats.append({
            "subject": subject, "runs": [r["run"] for r in runs], "scores": per_dim,
            "means": means,
            "spread": {d: max(v) - min(v) for d, v in per_dim.items()},
            "mean_spread": max(means) - min(means),
        })
    spread = {d: _mean([rep["spread"][d] for rep in repeats]) for d in DIMENSIONS} if repeats else {}
    twice = [r for r in judged if r.get("judge_again", {}).get("scores")]
    judge_noise = ({d: _mean([abs(r["judge"]["scores"][d] - r["judge_again"]["scores"][d])
                              for r in twice]) for d in DIMENSIONS} if twice else {})
    judge_mean_noise = (_mean([abs(r["judge"]["mean"] - r["judge_again"]["mean"]) for r in twice])
                        if twice else None)
    weakest = sorted(DIMENSIONS, key=lambda d: suite[d])[:3] if rows else []
    commits = sorted({r.get("commit", "?") for r in judged})
    return {"rows": rows, "suite": suite, "suite_mean": _mean(list(suite.values())) if rows else float("nan"),
            "repeats": repeats, "spread": spread,
            "mean_spread": _mean([rep["mean_spread"] for rep in repeats]) if repeats else None,
            # The noise in one subject's mean score: pooled within-subject
            # standard deviation, so two subjects' different levels do not count.
            "noise": (statistics.mean([statistics.pvariance(rep["means"]) for rep in repeats]) ** 0.5
                      if repeats else None),
            "judged_twice": len(twice), "judge_noise": judge_noise,
            "judge_mean_noise": judge_mean_noise,
            "weakest": weakest, "commits": commits,
            "rubric": sorted({int(r["rubric"]) for r in judged if r.get("rubric") is not None}),
            "judges": sorted({r["judge"].get("model", "?") for r in judged})}


def _n(value: float) -> str:
    return f"{value:.1f}"


def markdown(summary: dict, batch: str) -> str:
    """The batch as a section of docs/DESIGN_SCORES.md."""
    rows = summary["rows"]
    head = ["subject", "runs", *[SHORT[d] for d in DIMENSIONS], "mean", "parts", "pieces"]
    out = [
        f"## {batch}: commit {', '.join(summary['commits'])}, rubric v"
        f"{', v'.join(str(v) for v in summary['rubric'])}, judge {', '.join(summary['judges'])}",
        "",
        "| " + " | ".join(head) + " |",
        "|" + "---|" * len(head),
    ]
    for row in rows:
        failed = f" (run {', '.join(map(str, row['failed']))} built nothing)" if row["failed"] else ""
        pieces = ", ".join("?" if p is None else str(p) for p in row["pieces"])
        out.append("| " + " | ".join([
            row["subject"] + failed, str(row["runs"]),
            *[_n(row["scores"][d]) for d in DIMENSIONS],
            f"**{_n(row['mean'])}**", f"{row['parts']:,.0f}", pieces]) + " |")
    if rows:
        out.append("| " + " | ".join([
            "**suite mean**", str(sum(r["runs"] for r in rows)),
            *[f"**{_n(summary['suite'][d])}**" for d in DIMENSIONS],
            f"**{_n(summary['suite_mean'])}**", "", ""]) + " |")
    if summary["repeats"]:
        out += ["", "Run to run, the same subject designed again on the same code "
                "(each cell is run 1 / run 2 ...):", "",
                "| subject | " + " | ".join(SHORT[d] for d in DIMENSIONS) + " | mean |",
                "|" + "---|" * (len(DIMENSIONS) + 2)]
        for rep in summary["repeats"]:
            cells = [" / ".join(f"{v:.0f}" for v in rep["scores"][d]) for d in DIMENSIONS]
            out.append(f"| {rep['subject']} | " + " | ".join(cells) + " | "
                       + " / ".join(_n(m) for m in rep["means"]) + " |")
        spread = summary["spread"]
        out += ["", "Mean spread between runs, per dimension: "
                + ", ".join(f"{SHORT[d]} {spread[d]:.1f}" for d in DIMENSIONS)
                + f"; of a subject's mean score, {summary['mean_spread']:.2f} (standard deviation "
                f"{summary['noise']:.2f}). A change to a subject's mean smaller than the spread "
                "is not yet a result."]
    if summary.get("judged_twice"):
        noise = summary["judge_noise"]
        out += ["", f"The judge alone, the same pictures judged twice ({summary['judged_twice']} "
                "runs), mean difference per dimension: "
                + ", ".join(f"{SHORT[d]} {noise[d]:.1f}" for d in DIMENSIONS)
                + f"; of the mean score, {summary['judge_mean_noise']:.2f}."]
    if summary["weakest"]:
        out += ["", "Weakest across the suite: " + ", ".join(
            f"**{d}** ({_n(summary['suite'][d])})" for d in summary["weakest"]) + "."]
    return "\n".join(out) + "\n"
