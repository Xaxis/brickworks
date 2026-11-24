"""A release runs what its own change reaches, less what was proven since.

tools/release/lean.py chooses a release's checks and probes: those its diff
against the build brickworks.diy serves reaches, less each one a preview
proved at a commit from which nothing reaches it, plus the smoke. rel-m319's
24 units named 146 of 150 checks and took 13 hours over 8 attempts
(2026-11-23). These hold the rule that carries a proof, the reading of a
battery's lines, and the records' age and history checks.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "tools" / "release" / "lean.py"


@pytest.fixture()
def lean(tmp_path, monkeypatch):
    spec = importlib.util.spec_from_file_location("lean", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    monkeypatch.setattr(module, "out_dir", lambda: tmp_path)
    return module


def proof(name, built, passed, at=None, hours=1.0):
    return {"name": name, "built": built, "at": at or built, "passed": passed,
            "time": int(time.time() - hours * 3600)}


def test_a_proof_carries_only_what_nothing_since_reaches(lean, monkeypatch):
    monkeypatch.setattr(lean, "is_ancestor", lambda a, b: True)
    reach = {"P": {"b"}}
    left, carried = lean.choose({"a", "b", "c"}, [proof("unit_x", "P", ["a", "b"])], ["H"], reach.get)
    assert left == {"b", "c"}
    assert set(carried) == {"a"} and carried["a"].startswith("unit_x (P")


def test_the_scripts_commit_counts_too(lean, monkeypatch):
    # A reused preview: built from P, its checks run from A, a later commit.
    # A check whose flow changed between A and the release is run again.
    monkeypatch.setattr(lean, "is_ancestor", lambda a, b: True)
    reach = {"P": set(), "A": {"a"}}
    left, carried = lean.choose({"a", "b"}, [proof("rel", "P", ["a", "b"], at="A")], ["H"], reach.get)
    assert left == {"a"} and set(carried) == {"b"}


def test_a_proof_outside_the_release_history_carries_nothing(lean, monkeypatch):
    # A unit's preview of a commit the release never merged proves nothing.
    monkeypatch.setattr(lean, "is_ancestor", lambda a, b: a != "Q")
    reach = {"Q": set(), "P": set()}
    left, carried = lean.choose({"a", "b"}, [proof("other", "Q", ["a"]), proof("mine", "P", ["b"])], ["H"],
                                reach.get)
    assert left == {"a"} and set(carried) == {"b"}


def test_a_failed_check_is_never_carried(lean, monkeypatch):
    monkeypatch.setattr(lean, "is_ancestor", lambda a, b: True)
    left, carried = lean.choose({"a", "b"}, [proof("rel", "P", ["b"])], ["H"], lambda c: set())
    assert left == {"a"} and set(carried) == {"b"}


def test_each_commit_is_reached_once(lean, monkeypatch):
    monkeypatch.setattr(lean, "is_ancestor", lambda a, b: True)
    calls = []

    def reach(c):
        calls.append(c)
        return set()

    lean.choose({"a", "b"}, [proof("r1", "P", ["a"]), proof("r2", "P", ["b"]), proof("r3", "P", ["a"], at="A")],
                ["H"], reach)
    assert sorted(calls) == ["A", "P"]


def test_a_useless_proof_costs_no_reach(lean, monkeypatch):
    monkeypatch.setattr(lean, "is_ancestor", lambda a, b: True)
    calls = []
    lean.choose({"a"}, [proof("r1", "P", ["z"])], ["H"], lambda c: calls.append(c) or set())
    assert calls == []


def test_the_battery_lines_later_ones_win(lean, tmp_path):
    pv = tmp_path / "t_pv.out"
    pv.write_text("site exit=0 fails=0 30s :: ok\noc exit=1 fails=2 90s :: FAIL x\n"
                  "gallery exit=0 fails=0 20s :: ok\ndone\n")
    alone = tmp_path / "t_alone_oc.out"
    alone.write_text("oc exit=0 fails=0 60s :: ok\n")
    assert sorted(lean.passed_in([pv, alone])) == ["gallery", "oc", "site"]
    again = tmp_path / "t_alone_gallery.out"
    again.write_text("gallery exit=1 fails=1 20s :: FAIL\n")
    assert sorted(lean.passed_in([pv, alone, again])) == ["oc", "site"]
    assert lean.passed_in([tmp_path / "missing.out"]) == []


def test_records_past_their_age_are_left_out(lean, tmp_path, monkeypatch):
    head = subprocess.run(["git", "-C", str(ROOT), "rev-parse", "HEAD"], capture_output=True, text=True).stdout.strip()
    f = lean.record("checks", "unit_x", head, head, ["site", "gallery"])
    assert f.parent == tmp_path / "proofs" / "checks"
    body = json.loads(f.read_text())
    assert body["built"] == head and body["passed"] == ["gallery", "site"]
    assert [r["name"] for r in lean.records("checks")] == ["unit_x"]
    old = dict(body, name="old", time=int(time.time() - (lean.MAX_AGE_H + 1) * 3600))
    (f.parent / "old.1").write_text(json.dumps(old))
    (f.parent / "junk.2").write_text("not json")
    assert [r["name"] for r in lean.records("checks")] == ["unit_x"]


def test_no_change_runs_the_smoke_alone(tmp_path):
    run = subprocess.run([sys.executable, str(SCRIPT), "checks", "--live", "HEAD", "--head", "HEAD",
                          "--tree", str(ROOT), "--smoke", "site", "--named", "oc"],
                         capture_output=True, text=True, env={"RELEASE_OUT": str(tmp_path), "PATH": "/usr/bin:/bin"})
    assert run.returncode == 0, run.stderr
    assert "0 files differ" in run.stdout
    assert run.stdout.strip().splitlines()[-1] == "checks: oc site"


def test_record_writes_nothing_when_nothing_passed(tmp_path):
    pv = tmp_path / "t_pv.out"
    pv.write_text("site exit=1 fails=1 30s :: FAIL\n")
    run = subprocess.run([sys.executable, str(SCRIPT), "record", "checks", "t", "HEAD", "HEAD", str(pv)],
                         capture_output=True, text=True, env={"RELEASE_OUT": str(tmp_path), "PATH": "/usr/bin:/bin"})
    assert run.returncode == 0 and "no proof written" in run.stdout
    assert not (tmp_path / "proofs").exists()


def _tree(tmp_path, files):
    for name, text in files.items():
        p = tmp_path / "tree" / name
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(text)
    return tmp_path / "tree"


def test_a_probe_is_reached_by_what_its_own_source_names(lean, tmp_path, monkeypatch):
    # featuremap affected reached every probe from any script (all load
    # main.gd); a probe that names the changed function, a word on a changed
    # line or the file is reached, one that names none of them is not.
    tree = _tree(tmp_path, {
        "src/ui/dialog.gd": "class_name ShopDialog\nextends Control\n\nfunc open_shop():\n\tshow_part(\"shop_list\")\n\nfunc other():\n\tpass\n",
        "src/dev/shop_probe.gd": "func _run():\n\tdialog.open_shop()\n",
        "src/dev/words_probe.gd": "var n = find(\"shop_list\")\n",
        "src/dev/path_probe.gd": "load(\"res://src/ui/dialog.gd\")\n",
        "src/dev/class_probe.gd": "var d := ShopDialog.new()\n",
        "src/dev/elsewhere_probe.gd": "func _run():\n\tpass\n",
    })
    monkeypatch.setattr(lean, "diff_files", lambda a, b: ["src/ui/dialog.gd"])
    monkeypatch.setattr(lean, "_changed_lines", lambda a, b, f: ({5}, ['\tshow_part("shop_list")']))
    listed = {"shop", "words", "path", "class", "elsewhere"}
    # Inside a function: the class's name alone is no sign.
    assert lean.probes_reached(tree, "A", "B", listed) == {"shop", "words", "path"}
    # Outside every function (a signal, a constant): the class's users too.
    monkeypatch.setattr(lean, "_changed_lines", lambda a, b, f: ({2}, ["extends Control"]))
    assert lean.probes_reached(tree, "A", "B", listed) == {"path", "class"}


def test_a_word_most_probes_say_picks_out_none(lean, tmp_path, monkeypatch):
    files = {"src/net/tools.gd": "func add_part():\n\tpass\n"}
    files.update({f"src/dev/p{i}_probe.gd": "add_part()\n" for i in range(30)})
    files["src/dev/own_probe.gd"] = "# drives res://src/net/tools.gd\n"
    tree = _tree(tmp_path, files)
    monkeypatch.setattr(lean, "diff_files", lambda a, b: ["src/net/tools.gd"])
    monkeypatch.setattr(lean, "_changed_lines", lambda a, b, f: ({2}, ["\tpass"]))
    listed = {f"p{i}" for i in range(30)} | {"own"}
    assert lean.probes_reached(tree, "A", "B", listed) == {"own"}


def test_a_changed_probe_reaches_itself_and_a_page_reaches_none(lean, tmp_path, monkeypatch):
    tree = _tree(tmp_path, {"src/dev/own_probe.gd": "pass\n", "web/page.html": "<p>shop_list</p>\n"})
    monkeypatch.setattr(lean, "diff_files", lambda a, b: ["src/dev/own_probe.gd", "web/page.html"])
    monkeypatch.setattr(lean, "_changed_lines", lambda a, b, f: (set(), []))
    assert lean.probes_reached(tree, "A", "B", {"own", "other"}) == {"own"}


def test_what_a_change_reaches_is_worked_out_once_per_tree(lean, tmp_path):
    # Staged (a tree) and run (that tree as a commit) ask the same question:
    # flows_for.py took 75 s of each for rel-m321.
    calls = []
    first = lean.memo("checks", "HEAD~1", "HEAD", lambda: calls.append(1) or {"site", "oc"})
    again = lean.memo("checks", "HEAD~1", "HEAD^{tree}", lambda: calls.append(1) or set())
    assert first == again == {"site", "oc"} and calls == [1]
    # Another kind, or another commit, is its own question.
    assert lean.memo("probes", "HEAD~1", "HEAD", lambda: {"beams"}) == {"beams"}
    assert lean.memo("checks", "HEAD~2", "HEAD", lambda: set()) == set()
    assert len(list((tmp_path / "proofs" / "reach").iterdir())) == 3


def test_a_check_whose_script_refuses_the_live_site_is_known_without_running_it(lean, tmp_path):
    # rel-m319's designer_period queued 45 minutes on brickworks.diy to exit 2.
    tree = _tree(tmp_path, {
        "tools/release/preview_checks.sh": (
            'declare -A CMD=(\n'
            '  [always]="tools/web/always_flow.mjs --url=$P --out=$S/x"\n'
            '  [signed]="tools/web/signed_check.mjs --url=$P --signed-in --try-start"\n'
            '  [plain]="tools/web/signed_check.mjs --url=$P"\n'
            '  [owner]="tools/web/owner_flow.mjs --url=$P"\n'
            '  [said]="tools/web/said_flow.mjs --url=$P"\n'
            '  [free]="tools/web/free_flow.mjs --url=$P"\n'
            ')\n'),
        "tools/web/always_flow.mjs": 'if (/(^|\\.)brickworks\\.diy$/.test(new URL(site).hostname)) {\n'
                                     '  console.error("always_flow: never on brickworks.diy; give a preview");\n  process.exit(2);\n}\n',
        "tools/web/signed_check.mjs": 'if (/brickworks\\.diy$/.test(host) && args["signed-in"]) {\n'
                                      '  console.error("signed_check: --signed-in never on brickworks.diy");\n  process.exit(2);\n}\n',
        "tools/web/owner_flow.mjs": 'if (live) {\n  console.error("owner_flow: never against brickworks.diy: the owner\'s own");\n'
                                    '  process.exit(2);\n}\n',
        # Said only in a comment, as console3's notice part: it runs there.
        "tools/web/said_flow.mjs": '// 6. The notice (never on brickworks.diy: a check posts nothing there)\n',
        "tools/web/free_flow.mjs": 'console.log("runs anywhere");\n',
    })
    names = ["always", "signed", "plain", "owner", "said", "free", "unknown"]
    assert lean.never_live(tree, names) == ["always", "signed", "owner"]


def test_a_short_night_proves_first_what_was_proven_longest_ago(lean):
    # The first nightly's 162 checks took 9.5 hours (nightreds, 2026-11-24):
    # a night of four proves those no proof holds first, then those proven
    # over 12 hours ago, each lot in the order given (the longest first).
    now = time.time()
    proofs = [proof("rel", "P", ["fresh", "stale"], hours=1.0), proof("older", "Q", ["stale", "half"], hours=13.0)]
    assert lean.oldest(["fresh", "never", "half", "stale", "none"], proofs, now) == ["never", "none", "half", "fresh", "stale"]
    assert lean.oldest([], proofs, now) == []
    assert lean.oldest(["a", "b"], [], now) == ["a", "b"]
