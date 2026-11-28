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


def test_a_software_drawer_draws_the_gpus_renderer_on_lavapipe_in_the_runs_heavy_slot():
    # design47: five sessions shared the GPU's one slot, and 41 of 48 designs gave up on
    # a picture at least once. With --software each tab's drawer is lavapipe under heavy.
    from bench import run
    assert run.drawer() == run.DRAWER and run.drawer(False)[0] == run.GPU
    soft = run.drawer(True)
    assert soft[0] == run.HEAVY and run.GPU not in soft
    assert "GODOT_GPU=1" in soft and f"VK_ICD_FILENAMES={run.LAVAPIPE}" in soft
    assert f"VK_DRIVER_FILES={run.LAVAPIPE}" in soft
    assert soft[-1] == "godot" and "xvfb-run" in soft


def test_pictures_waited_are_read_from_the_godot_log():
    from bench import run
    log = ("leased shots: 000001 in 41200 ms\n"
           "draw_shots: 000001 drawn in 900 ms, 40 bricks\n"
           "leased shots: 000002 in 1300 ms\n"
           "leased shots: 000003 in 2100 ms\n")
    with tempfile.TemporaryDirectory() as where:
        path = Path(where) / "godot_design.log"
        assert run.pictures_waited(path) == {}, "no log, nothing waited"
        path.write_text("draw_shots: 000001 drawn in 900 ms, 40 bricks\n")
        assert run.pictures_waited(path) == {}, "a drawer's own line is not a wait"
        path.write_text(log)
        assert run.pictures_waited(path) == {"pictures": 3, "median_s": 2.1, "most_s": 41.2}


def test_an_app_from_before_the_drawer_runs_in_a_window_on_the_lease():
    from bench import run
    command = _design_command(with_drawer=False)
    assert command[:2] == [run.GPU, "xvfb-run"]
    assert "--headless" not in command
    assert not any(a.startswith("--draw-by=") for a in command)


def test_two_designs_at_once_are_lent_two_ports_and_get_them_back():
    # brickbench.py design --jobs 2 runs two designs as threads of one process:
    # both were handed BENCH_PORTS' first port, and the second app took 8787.
    from bench import run
    saved = os.environ.get("BENCH_PORTS")
    # A range of this run's own: the ports' locks are the whole box's, and with
    # one fixed range two units' ci_gates at once took all four between them,
    # and the second found "no free port" (2026-11-03).
    lo = 20000 + (os.getpid() % 4000) * 4
    os.environ["BENCH_PORTS"] = f"{lo}-{lo + 3}"
    got = []
    try:
        got = [run._free_port(), run._free_port()]
        assert got[0] != got[1], got
        run._port_back(got[0])
        again = run._free_port()
        got.append(again)
        assert again == got[0], (again, got)
    finally:
        for port in got:
            run._port_back(port)
        if saved is None:
            os.environ.pop("BENCH_PORTS", None)
        else:
            os.environ["BENCH_PORTS"] = saved


def test_pictures_given_up_are_counted_from_the_godot_log():
    from bench import run, realset
    # As a contended design's godot_design.log has them (gl-w4b 7410-1, 2026-10-20).
    log = ("  [ 85.3s]   app: no picture in time, so it is shown the letters\n"
           "WARNING: leased shots: no picture within 120 s\n"
           "     at: push_warning (core/variant/variant_utility.cpp:1034)\n"
           "draw_shots: 000004 drawn in 46 ms, 234 bricks\n"
           "WARNING: leased shots: no picture within 120 s\n"
           "WARNING: leased shots: 3 drawers ended without the picture\n")
    with tempfile.TemporaryDirectory() as where:
        path = Path(where) / "godot_design.log"
        assert run.pictures_given_up(path) == 0, "no log, nothing given up"
        path.write_text(log)
        assert run.pictures_given_up(path) == 3
        # An empty picture is the letters at once and is not one given up.
        path.write_text("  [ 85.3s]   app: no picture in time, so it is shown the letters\n")
        assert run.pictures_given_up(path) == 0
    found = [{"number": "7410-1", "design": {"pictures_given_up": 6}},
             {"number": "3932-1", "design": {"pictures_given_up": 0}},
             {"number": "9470-1", "design": {}}]
    said = realset.gave_up_said(found)
    assert "6 over 2 designs counted" in said and "7410-1 (6)" in said
    assert "3932-1" not in said and "1 recorded before the count was kept" in said
    assert "none" in realset.gave_up_said(found[1:2])


def test_a_design_records_the_pictures_it_gave_up():
    command_log = "WARNING: leased shots: no picture within 120 s\n"
    from bench import run, suite
    saved = (run.subprocess.run, run._tidy_user_dir, run._stop_leftovers, run.commit)

    def fake_run(command, **kwargs):
        kwargs["stdout"].write("claude code ok=true bricks=1  (1s)\n")
        godot = command[command.index("--log-file") + 1]
        Path(godot).write_text(command_log * 2)
        return type("Done", (), {"returncode": 0})()

    with tempfile.TemporaryDirectory() as where:
        app, out = Path(where) / "app", Path(where) / "out"
        (app / "src" / "ai").mkdir(parents=True)
        (app / "src" / "ai" / "leased_shots.gd").write_text("")
        out.mkdir()
        run.subprocess.run, run._tidy_user_dir = fake_run, (lambda *_a: [])
        run._stop_leftovers, run.commit = (lambda _port: []), (lambda _app=None: "abc1234")
        try:
            subject = suite.Subject(id="owl", title="Owl", brief="an owl", scale="", against="")
            made = run.design(subject, out, 60, None, app=app)
            recorded = json.loads((out / "design.json").read_text())
            # A design recorded before the count was kept is counted when read again.
            del recorded["pictures_given_up"]
            (out / "design.json").write_text(json.dumps(recorded))
            again = run.design(subject, out, 60, None, app=app)
        finally:
            run.subprocess.run, run._tidy_user_dir, run._stop_leftovers, run.commit = saved
    assert made["pictures_given_up"] == 2
    assert again["pictures_given_up"] == 2


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


# -- a checkout's class list ------------------------------------------------


def _tree(where: Path, listed: list[tuple[str, str]]) -> Path:
    """A checkout whose src/ declares Alpha and Beta (Gamma under a .gdignore,
    which Godot never scans), its class list naming [listed]."""
    for path, text in (("src/alpha.gd", "class_name Alpha\nextends Node\n"),
                       ("src/b/beta.gd", "extends RefCounted\nclass_name Beta\n"),
                       ("src/plain.gd", "extends Node\n"),
                       ("src/off/gamma.gd", "class_name Gamma\n"), ("src/off/.gdignore", "")):
        (where / path).parent.mkdir(parents=True, exist_ok=True)
        (where / path).write_text(text)
    (where / ".godot").mkdir()
    (where / ".godot" / "global_script_class_cache.cfg").write_text("list=[" + "}, ".join(
        '{\n"base": &"Node",\n"class": &"%s",\n"icon": "",\n"path": "%s"\n' % pair
        for pair in listed) + "}]\n")
    return where


def _classes_said(tree: Path) -> str:
    """What the class check says of [tree]: "" when it lets it run."""
    from bench import run
    run.classes_current.cache_clear()
    try:
        run.classes_current(tree)
    except SystemExit as refused:
        return str(refused)
    return ""


def test_a_checkout_whose_class_list_lacks_a_class_is_refused_by_name():
    # A realset run from a checkout imported before CutShape drew no
    # pictures and said nothing (design25, 2026-11-19).
    with tempfile.TemporaryDirectory() as where:
        said = _classes_said(_tree(Path(where), [("Alpha", "res://src/alpha.gd")]))
    assert "lacks 1 of the classes" in said and "Beta (res://src/b/beta.gd)" in said, said
    assert "Gamma" not in said and "tools/fresh_import.sh" in said, said


def test_a_class_listed_at_another_path_is_missing_too():
    with tempfile.TemporaryDirectory() as where:
        said = _classes_said(_tree(Path(where), [("Alpha", "res://src/alpha.gd"),
                                                 ("Beta", "res://src/beta.gd")]))
    assert "Beta (res://src/b/beta.gd)" in said, said


def test_a_checkout_with_every_class_listed_runs():
    with tempfile.TemporaryDirectory() as where:
        said = _classes_said(_tree(Path(where), [("Alpha", "res://src/alpha.gd"),
                                                 ("Beta", "res://src/b/beta.gd")]))
    assert said == ""


# -- facing: a design turned as its set faces before its views are drawn (design49) --------

_PARTS_BY_HAND = None


def _hand_parts():
    import style
    global _PARTS_BY_HAND
    if _PARTS_BY_HAND is None:
        # A 2x2 brick and a 1x1 "nose", their boxes in LDraw's axes (y down), as the catalogue
        # gives them; Parts.of keeps them off the catalogue and the library.
        _PARTS_BY_HAND = style.Parts.of({
            "3003": style.PartInfo("Brick  2 x  2", "Brick", ((-20.0, 0.0, -20.0), (20.0, 24.0, 20.0))),
            "3005": style.PartInfo("Brick  1 x  1", "Brick", ((-10.0, 0.0, -10.0), (10.0, 24.0, 10.0))),
        })
    return _PARTS_BY_HAND


_MODEL = """0 FILE beast.ldr
0 beast
0 !BRICKWORKS FLOOR NONE
1 16 0 0 0 1 0 0 0 1 0 0 0 1 body.ldr
1 4 60 -24 0 1 0 0 0 1 0 0 0 1 3005.dat
0 NOFILE
0 FILE body.ldr
1 15 0 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 15 40 0 0 1 0 0 0 1 0 0 0 1 3003.dat
1 15 -40 0 0 0 0 1 0 1 0 -1 0 0 3003.dat
0 NOFILE
"""


def test_a_turned_model_file_is_the_model_turned():
    from bench import facing
    parts = _hand_parts()
    before = facing.boxes(_MODEL, parts)
    assert len(before) == 4
    for quarter in range(4):
        text = facing.turned_text(_MODEL, quarter)
        got = sorted(facing.boxes(text, parts))
        want = sorted(facing.turn_boxes(before, quarter))
        assert [tuple(round(v, 6) for v in c) for c, _h in got] == \
            [tuple(round(v, 6) for v in c) for c, _h in want], quarter
        assert [h for _c, h in got] == [h for _c, h in want], quarter
    once = facing.turned_text(_MODEL, 1)
    # Only the first model's placing lines turn: a sub-model is carried by its line.
    assert once.split("0 FILE body.ldr")[1] == _MODEL.split("0 FILE body.ldr")[1]
    assert "1 4 0 -24 60 0 0 -1 0 1 0 1 0 0 3005.dat" in once, once
    assert "0 !BRICKWORKS FLOOR NONE" in once
    # Four quarter turns are none, written in the same numbers.
    four = once
    for _ in range(3):
        four = facing.turned_text(four, 1)
    assert four == _MODEL
    assert facing.turned_text(_MODEL, 0) == _MODEL


def test_the_turn_brings_the_designs_front_to_the_side_the_sets_faces():
    from bench import facing
    parts = _hand_parts()
    # The nose (3005) is at +x: the side the right camera sees (LDraw +x is the app's +x).
    nose = [b for b in facing.boxes(_MODEL, parts) if b[1] == (10.0, 12.0, 10.0)]
    assert nose and nose[0][0][0] > 0
    # A set whose front faces the front camera: the app's +z, LDraw's -z.
    quarter = facing.quarter_for(facing.SIDES.index("right"), facing.SIDES.index("front"))
    turned = facing.turn_boxes(nose, quarter)
    assert turned[0][0][2] < 0 and abs(turned[0][0][0]) < 1e-9, (quarter, turned)
    # Each side goes to the next one round with each quarter turn.
    for design in range(4):
        for the_set in range(4):
            assert (design + facing.quarter_for(design, the_set)) % 4 == the_set


def test_the_outline_lays_a_long_design_along_its_sets_length_and_keeps_a_square_ones_front():
    from bench import facing
    long_x = [((40.0 * i, -12.0, 0.0), (20.0, 12.0, 20.0)) for i in range(5)]
    long_z = [((0.0, -12.0, 40.0 * i), (20.0, 12.0, 20.0)) for i in range(5)]
    tall_end = long_z + [((0.0, -36.0, 160.0), (20.0, 12.0, 20.0))]
    square = [((40.0 * i, -12.0, 40.0 * j), (20.0, 12.0, 20.0)) for i in range(3) for j in range(3)]
    across = facing.facing(long_x, tall_end)
    assert across.quarter in (1, 3) and across.aspect[0] > 0 > across.aspect[1], across
    assert facing.facing(long_x, long_x).quarter == 0
    assert facing.facing(square, tall_end).quarter == 0
    assert facing.facing(long_x, square).quarter == 0
    # Its tall end where the set's is: the design's tall end at +x, the set's at +z.
    design = long_x + [((160.0, -36.0, 0.0), (20.0, 12.0, 20.0))]
    turned = facing.turn_boxes(design, facing.facing(design, tall_end).quarter)
    tallest = min(turned, key=lambda b: b[0][1])
    assert tallest[0][2] > 100, turned


def test_the_front_is_read_from_the_judges_reply():
    from bench import facing
    assert facing.read_front({"type": "result", "is_error": False,
                              "structured_output": {"front": "3", "reason": "its face"}}) == 2
    assert facing.read_front({"front": "1", "reason": "x"}) == 0
    assert facing.read_front({"type": "result", "is_error": True, "result": "limit"}) is None
    assert facing.read_front({"front": "5"}) is None and facing.read_front("no") is None
    said = facing.front_prompt("Wolf Legend Beast", ["/tmp/a.png", "/tmp/b.png", "/tmp/c.png",
                                                     "/tmp/d.png"])
    assert "4. /tmp/d.png" in said and "Wolf Legend Beast" in said
    # The pictures are named only by number: the question says nothing of which side is which.
    assert all(side not in said.split("Which picture")[0] for side in ("right", "back", "left"))


# -- pair: k designs a label, head to head, the run spread measured (design49) --------------


def _verdict(a: str, b: str, winner: str):
    from bench import pairwise
    return pairwise.Verdict(a, b, {d: winner for d in pairwise.DIMENSIONS}, {})


def _row(lev: list[str], base: list[str], better: dict[str, int], per_order: int = 2) -> dict:
    """Every pair of the subject's designs judged both ways round, the one with the higher
    `better` winning each verdict."""
    keys = lev + base
    verdicts = []
    for i, a in enumerate(keys):
        for b in keys[i + 1:]:
            winner = a if better[a] >= better[b] else b
            for _ in range(per_order):
                verdicts += [_verdict(a, b, winner), _verdict(b, a, winner)]
    return {"lev": lev, "base": base, "verdicts": verdicts}


def test_pair_judges_each_lever_design_against_each_base_design_and_within_on_asking():
    from bench import realset
    lev, base = ["l1", "l2"], ["b1", "b2"]
    assert len(realset.pair_pairs(lev, base, False)) == 4
    pairs = realset.pair_pairs(lev, base, True)
    assert len(pairs) == 6 and ("l1", "l2") in pairs and ("b1", "b2") in pairs


def test_pair_scores_an_aa_round_as_nothing_and_measures_the_run_spread():
    from bench import realset
    rows = {}
    for n in range(8):
        # Same code both sides: which design is best is luck, split evenly between labels.
        order = [0, 3, 1, 2] if n % 2 else [3, 0, 2, 1]
        rows[f"s{n}"] = _row([f"l1{n}", f"l2{n}"], [f"b1{n}", f"b2{n}"],
                             dict(zip([f"l1{n}", f"l2{n}", f"b1{n}", f"b2{n}"], order)))
    found = realset.pair_score(rows, None, {"all": list(rows)}, dims=("overall",))
    got = found["overall"]
    row = got["groups"]["all"]
    assert abs(row["mean"]) < 1e-6 and row["runs"][0] < 0 < row["runs"][1], row
    assert row["beyond"] == "-"
    assert got["run_sd_measured"] is not None and got["run_sd_measured"] > 100, got
    assert row["floor"] > 0 and row["subjects"] == 8
    # The floor is the with-runs half-width those subjects would have on 24.
    half = (row["runs"][1] - row["runs"][0]) / 2
    assert abs(row["floor"] - half * (8 / 24) ** 0.5) < 1e-6


def test_pair_sees_a_lever_that_wins_every_pair():
    from bench import realset
    rows = {f"s{n}": _row([f"l1{n}", f"l2{n}"], [f"b1{n}", f"b2{n}"],
                          {f"l1{n}": 3, f"l2{n}": 2, f"b1{n}": 1, f"b2{n}": 0})
            for n in range(12)}
    found = realset.pair_score(rows, None, {"all": list(rows)}, dims=("overall",))
    row = found["overall"]["groups"]["all"]
    assert row["mean"] > 300 and row["beyond"] == "better", row
    # Given a spread, it is the one used.
    given = realset.pair_score(rows, 50.0, {"all": list(rows)}, dims=("overall",))
    assert given["overall"]["run_sd"] == 50.0
