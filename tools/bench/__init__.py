"""The design bench: a fixed held-out suite, the real design loop, a calibrated judge.

    python3 tools/bench/run.py list
    python3 tools/bench/run.py run [--subjects barn_owl,bonsai] [--run 2] [--date D]
    python3 tools/bench/run.py run --dry-run          canned design, canned judge, no network
    python3 tools/bench/run.py summary --date D [--append docs/DESIGN_SCORES.md]

Design rounds had been judged by rerunning one or two subjects once and
reading tools/style.py. A run varies a lot, and "elegant" was judged by
eye, so nobody could say which change made designs better. This runs the
same ten subjects every time, renders each design the same way, and asks
the same judge with the same rubric and the same two anchor pictures for
scores, so a round is a number with a known noise.

suite.py    the subjects, their briefs, scales and reference pictures
judge.py    the rubric, the prompt, the call and the reading of the reply
scores.py   the probe's and the judge's output read into records, and the summary
run.py      the stages: design, views, probe, style, references, judge
"""
