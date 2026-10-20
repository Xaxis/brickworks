"""Tests for tools/bench: reading the judge's reply and the build check, and the summary.

The bench is only as good as these readings. A reply read wrongly is a
score nobody gave; a probe read wrongly is a buildability the model does
not have; a summary that averages the wrong way ranks the wrong
dimension as weakest and sends a design round after it.
"""

from __future__ import annotations

import json
import math
import os
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

from bench import judge, scores  # noqa: E402
from bench.judge import DIMENSIONS  # noqa: E402

CANNED = ROOT / "tests" / "fixtures" / "bench" / "judge_reply.json"


def _refused(fn, *args) -> str:
    """The ValueError's message, or a failure if it returned."""
    try:
        fn(*args)
    except ValueError as error:
        return str(error)
    raise AssertionError(f"{fn.__name__} accepted {args!r}")


def _scores(**given: int) -> dict:
    return {d: {"score": given.get(d, 5), "reason": f"{d} reason"} for d in DIMENSIONS}


# -- the judge's reply ----------------------------------------------------


def test_structured_output_is_read():
    verdict = judge.parse(json.loads(CANNED.read_text()))
    assert verdict.scores == {"likeness": 5.0, "surface": 3.0, "colour": 4.0,
                              "technique": 3.0, "creativity": 2.0, "buildability": 10.0}
    assert verdict.reasons["surface"].startswith("Studs on every top face")
    assert "views_close.png" in verdict.looked_at
    assert verdict.mean() == 27 / 6


def test_text_reply_in_a_fence_after_a_sentence():
    body = json.dumps({"looked_at": ["a.png"], **_scores(likeness=8, creativity=1)})
    reply = {"type": "result", "is_error": False,
             "result": f"Here are my scores.\n```json\n{body}\n```\nThanks."}
    verdict = judge.parse(reply)
    assert verdict.scores["likeness"] == 8.0 and verdict.scores["creativity"] == 1.0
    assert verdict.looked_at == ("a.png",)


def test_bare_text_and_a_scores_wrapper_read_the_same():
    plain = judge.parse(json.dumps(_scores(technique=7)))
    wrapped = judge.parse(json.dumps({"scores": _scores(technique=7), "looked_at": []}))
    assert plain.scores == wrapped.scores and plain.scores["technique"] == 7.0


def test_a_number_as_a_string_is_a_score_but_words_are_not():
    said = _scores()
    said["colour"] = {"score": "6", "reason": "fine"}
    assert judge.parse(said).scores["colour"] == 6.0
    said["colour"] = {"score": "six", "reason": "fine"}
    assert "colour" in _refused(judge.parse, said)


def test_a_missing_dimension_is_refused_by_name():
    said = _scores()
    del said["buildability"]
    assert "buildability" in _refused(judge.parse, said)


def test_a_score_outside_one_to_ten_is_refused():
    assert "outside 1-10" in _refused(judge.parse, _scores(surface=11))
    assert "outside 1-10" in _refused(judge.parse, _scores(surface=0))


def test_a_true_is_not_a_score():
    said = _scores()
    said["likeness"] = {"score": True, "reason": ""}
    assert "likeness" in _refused(judge.parse, said)


def test_a_failed_call_is_refused_not_scored():
    reply = {"type": "result", "is_error": True, "result": "usage limit reached"}
    assert "failed" in _refused(judge.parse, reply)


def test_no_json_at_all_is_refused():
    assert "no JSON" in _refused(judge.parse, "I could not see the pictures.")


def test_nothing_built_scores_one_everywhere():
    verdict = judge.nothing_built("no model was produced")
    assert set(verdict.scores.values()) == {1.0} and verdict.mean() == 1.0


def test_the_prompt_names_every_picture_and_both_anchor_scores():
    anchors = (judge.Picture(Path("/a/high_corner.png"), "a real set"),
               judge.Picture(Path("/a/low_corner.png"), "a naive stack"))
    refs = [judge.Picture(Path("/r/photo1.jpg"), "an owl")]
    views = [judge.Picture(Path(f"/v/views_{v}.png"), v) for v in ("corner", "front", "close")]
    text = judge.prompt("a barn owl", "An owl.", "display", anchors, refs, views, 321,
                        "    ok    it stands up: stable", 9, 2)
    for path in ("/a/high_corner.png", "/a/low_corner.png", "/r/photo1.jpg",
                 "/v/views_corner.png", "/v/views_front.png", "/v/views_close.png"):
        assert path in text
    assert "what 9 looks like" in text and "what 2 looks like" in text
    assert "321 parts" in text and "it stands up: stable" in text
    assert all(f"  {d}: " in text for d in DIMENSIONS)


# -- the build check ------------------------------------------------------

NOT_A_CANDIDATE = """\
Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org
  design.ldr
    ok    it opens whole: 544 parts, none of them missing from the library (0)
    FAIL  it is buildable, in one piece: 1 problem (loose 1), 2 pieces
    ok    it stands up: stable
    ok    the check does not call it a dark face with nothing on it
    ok    not counted: called lit windows in rows, as orthanc.ldr on the page is
    FAIL  the check does not call it a yard for a base
  not a candidate: 2 faults
"""

A_CANDIDATE = """\
  design.ldr
    ok    it opens whole: 120 parts, none of them missing from the library (0)
    ok    it is buildable, in one piece: buildable, 3 pieces (apart as named: Nameplate, Driver)
    ok    it stands up: stable
  a candidate
"""


def test_a_failing_probe_is_read_into_facts():
    found = scores.read_probe(NOT_A_CANDIDATE)
    assert found["ran"] and found["opens"] and found["parts"] == 544 and found["missing"] == 0
    assert found["buildable"] is False and found["pieces"] == 2
    assert found["stands"] is True
    assert found["faults"] == ["a yard for a base"]
    assert found["shared_faults"] == ["lit windows in rows"]
    assert found["candidate"] is False


def test_a_fault_the_page_has_too_is_said_as_a_pass_and_read_as_shared():
    # The judge is shown the probe's lines: one the probe lets through must
    # not read as a fault named. Before, it said "still ..." and four runs
    # lost two points of buildability for it.
    line = "    ok    not counted: called sky through a slit, as orthanc.ldr on the page is"
    found = scores.read_probe(A_CANDIDATE.replace("  a candidate", line + "\n  a candidate"))
    assert found["faults"] == [] and found["shared_faults"] == ["sky through a slit"]
    assert found["candidate"] is True
    old = scores.read_probe("    still sky through a slit, as orthanc.ldr is\n")
    assert old["shared_faults"] == ["sky through a slit"] and old["faults"] == []


def test_figures_standing_apart_do_not_change_the_piece_count():
    found = scores.read_probe("    ok    it is buildable, in one piece: 244 bricks, buildable, "
                              "3 pieces, 2 figures apart\n")
    assert found["buildable"] is True and found["pieces"] == 3


def test_pieces_named_apart_are_read_and_the_count_is_the_last_number():
    found = scores.read_probe(A_CANDIDATE)
    assert found["buildable"] is True and found["pieces"] == 3
    assert found["named_apart"] == ["Nameplate", "Driver"]
    assert found["candidate"] is True and found["faults"] == []


def test_a_probe_that_never_ran_is_not_a_model_that_failed():
    found = scores.read_probe("SCRIPT ERROR: Parse Error\n")
    assert found["ran"] is False and found["buildable"] is None and found["candidate"] is None


def test_a_sessions_saves_are_read_from_its_progress_lines():
    # From the baseline owl's log: two saves, only the second named in words.
    log = ("  [  6.5s] connected (claude-opus-5-5) on your subscription\n"
           "  [204.3s] changing it\n"
           "  [209.0s] saving\n"
           "  said: Saved. Next I'm adding a few grass tufts\n"
           "  [220.9s] saving\n"
           "  said: It's saved as **`barn_owl_on_branch_v2.ldr`**\n"
           "  [221.0s] saving the booklet\n")
    assert scores.save_times(log) == [209.0, 220.9]
    assert scores.save_times("claude code ok=true bricks=616  (229s)") == []


def test_tidying_moves_the_runs_saves_and_leaves_everyone_elses():
    from bench import run
    log = ("  [209.0s] saving\n  [220.9s] saving\n"
           "  said: It's saved as **`owl_v2.ldr`**, like orthanc.ldr\n")
    with tempfile.TemporaryDirectory() as where:
        user, keep = Path(where) / "user", Path(where) / "keep"
        (user / "models").mkdir(parents=True)
        start = 1_800_000_000.0
        files = {"claude-code-mcp-4242.json": start,          # this run's connection
                 "models/owl.ldr": start + 209.5,              # its first save, not named
                 "models/owl_v2.ldr": start + 221.6,           # its last, named
                 "models/someone_elses.ldr": start + 100.0,    # another agent's, meanwhile
                 "models/orthanc.ldr": start - 86400.0}        # named in the log, but the owner's
        for name, when in files.items():
            (user / name).write_text("0 x\n")
            os.utime(user / name, (when, when))
        was = run.USER_DIR
        run.USER_DIR = user
        try:
            moved = run._tidy_user_dir(start - 7 * 86400, log, 4242, keep)
        finally:
            run.USER_DIR = was
        left = sorted(p.name for p in (user / "models").iterdir())
    assert sorted(moved) == ["claude-code-mcp-4242.json", "owl.ldr", "owl_v2.ldr"]
    assert left == ["orthanc.ldr", "someone_elses.ldr"]


def _design_command(with_drawer: bool) -> list[str]:
    """The command run.design starts for an app with or without the leased drawer."""
    from bench import run, suite
    started: list[list[str]] = []

    def fake_run(command, **_kwargs):
        started.append(list(command))
        log = _kwargs["stdout"]
        log.write("claude code ok=true bricks=1  (1s)\n")
        return type("Done", (), {"returncode": 0})()

    with tempfile.TemporaryDirectory() as where:
        app, out = Path(where) / "app", Path(where) / "out"
        (app / "src" / "ai").mkdir(parents=True)
        out.mkdir()
        if with_drawer:
            (app / "src" / "ai" / "leased_shots.gd").write_text("")
        saved = (run.subprocess.run, run._tidy_user_dir, run._stop_leftovers, run.commit)
        run.subprocess.run = fake_run
        run._tidy_user_dir = lambda *_a: []
        run._stop_leftovers = lambda _port: []
        run.commit = lambda _app=None: "abc1234"
        try:
            subject = suite.Subject(id="owl", title="Owl", brief="an owl", scale="", against="")
            run.design(subject, out, 60, None, app=app)
        finally:
            run.subprocess.run, run._tidy_user_dir, run._stop_leftovers, run.commit = saved
    assert len(started) == 1
    return started[0]


def test_a_design_runs_headless_and_leases_the_gpu_only_to_draw():
    from bench import run
    command = _design_command(with_drawer=True)
    assert run.GPU not in command[:1], "the app itself holds no lease"
    assert "--headless" in command and "xvfb-run" not in command
    drawer = [a for a in command if a.startswith("--draw-by=")]
    assert len(drawer) == 1
    assert json.loads(drawer[0][len("--draw-by="):]) == run.DRAWER
    assert run.DRAWER[0] == run.GPU and "xvfb-run" in run.DRAWER


def test_an_app_from_before_the_drawer_runs_in_a_window_on_the_lease():
    from bench import run
    command = _design_command(with_drawer=False)
    assert command[:2] == [run.GPU, "xvfb-run"]
    assert "--headless" not in command
    assert not any(a.startswith("--draw-by=") for a in command)


# -- the summary ----------------------------------------------------------


def _record(subject: str, run: int, **given: int) -> dict:
    return {"subject": subject, "run": run, "commit": "abc1234", "rubric": 1,
            "design": {"model": True}, "probe": {"parts": 100 * run, "pieces": 1},
            "judge": {"scores": {d: float(given.get(d, 5)) for d in DIMENSIONS},
                      "reasons": {}, "model": "claude-opus-5-5"}}


def test_the_summary_means_each_subject_then_the_suite():
    records = [_record("owl", 1, surface=2, colour=8), _record("owl", 2, surface=4, colour=6),
               _record("car", 1, surface=6, technique=1)]
    summary = scores.summarise(records)
    owl = next(r for r in summary["rows"] if r["subject"] == "owl")
    assert owl["runs"] == 2 and owl["scores"]["surface"] == 3.0 and owl["scores"]["colour"] == 7.0
    assert owl["parts"] == 150.0
    # The suite weighs subjects equally, not runs: the owl's two runs count once.
    assert summary["suite"]["surface"] == (3.0 + 6.0) / 2
    assert summary["suite"]["technique"] == (5.0 + 1.0) / 2
    assert summary["weakest"][:2] == ["technique", "surface"]


def test_the_spread_is_between_runs_of_one_subject():
    records = [_record("owl", 1, likeness=3), _record("owl", 2, likeness=7),
               _record("car", 1, likeness=9)]
    summary = scores.summarise(records)
    assert len(summary["repeats"]) == 1
    owl = summary["repeats"][0]
    assert owl["scores"]["likeness"] == [3.0, 7.0] and owl["spread"]["likeness"] == 4.0
    assert summary["spread"]["surface"] == 0.0
    assert math.isclose(summary["mean_spread"], 4 / 6)
    assert math.isclose(summary["noise"], 2 / 6)


def test_a_run_without_scores_is_left_out_and_a_failed_design_is_flagged():
    unjudged = _record("owl", 1)
    unjudged["judge"] = {}
    failed = _record("car", 1)
    failed["design"] = {"model": False}
    failed["judge"]["scores"] = {d: 1.0 for d in DIMENSIONS}
    summary = scores.summarise([unjudged, failed])
    assert [r["subject"] for r in summary["rows"]] == ["car"]
    assert summary["rows"][0]["failed"] == [1]
    assert "run 1 built nothing" in scores.markdown(summary, "2026-10-12")


def test_the_markdown_has_a_row_per_subject_the_suite_and_the_weakest():
    records = [_record("owl", 1, surface=2), _record("owl", 2, surface=4),
               _record("car", 1, colour=3)]
    text = scores.markdown(scores.summarise(records), "2026-10-12")
    assert text.startswith("## 2026-10-12: commit abc1234, rubric v1, judge claude-opus-5-5")
    assert "| owl | 2 | 5.0 | 3.0 |" in text
    assert "| car | 1 | 5.0 | 5.0 | 3.0 |" in text
    assert "**suite mean** | 3 |" in text
    assert "| owl | 5 / 5 | 2 / 4 |" in text
    assert "Weakest across the suite: **surface** (4.0), **colour** (4.0)" in text


def test_the_judge_noise_is_the_same_run_judged_twice():
    once = _record("owl", 1, likeness=4)
    once["judge"]["mean"] = 29 / 6
    once["judge_again"] = {"scores": {d: 5.0 for d in DIMENSIONS}, "mean": 31 / 6}
    once["judge_again"]["scores"]["likeness"] = 6.0
    summary = scores.summarise([once, _record("car", 1)])
    assert summary["judged_twice"] == 1
    assert summary["judge_noise"]["likeness"] == 2.0 and summary["judge_noise"]["surface"] == 0.0
    assert math.isclose(summary["judge_mean_noise"], 2 / 6)
    assert "judged twice (1 runs)" in scores.markdown(summary, "b")


def test_records_are_collected_from_a_batch_folder():
    with tempfile.TemporaryDirectory() as where:
        batch = Path(where)
        for record in (_record("owl", 1), _record("owl", 2), _record("car", 1)):
            out = batch / record["subject"] / str(record["run"])
            out.mkdir(parents=True)
            (out / "record.json").write_text(json.dumps(record))
        (batch / "anchors").mkdir()
        found = scores.collect(batch)
    assert [(r["subject"], r["run"]) for r in found] == [("car", 1), ("owl", 1), ("owl", 2)]
