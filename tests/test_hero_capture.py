"""The home's loop never films a path, a session's name or work under way (herostudio2, 2026-11-26).

herostudio's first loop showed its render's status line, "wrote
/tmp/claude-1000/<session>/scratchpad/herostudio/cap3/...", with "Gathering the
light… 10%" and the share form's placeholder. src/dev/hero_capture_probe.gd now
keeps every word in sight at each recorded frame (DIR/<cut>/texts.json), and
tools/site/hero_capture.py refuses a cut whose words hold one, before it encodes
anything. These plant such words in a run's record and run the real tool on it.
"""

from __future__ import annotations

import importlib.util
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TOOL = ROOT / "tools" / "site" / "hero_capture.py"


def tool():
    spec = importlib.util.spec_from_file_location("hero_capture", TOOL)
    module = importlib.util.module_from_spec(spec)
    # Its dataclasses look their module up by name as they are made.
    sys.modules["hero_capture"] = module
    spec.loader.exec_module(module)
    return module


def recorded(folder: Path, words: list[list]) -> Path:
    """A run's frames folder whose desktop cut was recorded and saw [words]."""
    cut = folder / "desktop"
    cut.mkdir(parents=True)
    (cut / "cut.json").write_text(json.dumps({"ok": True, "segments": [{"name": "drop", "frames": 3}]}))
    (cut / "texts.json").write_text(json.dumps({"segments": {"drop": words}}))
    return folder


CLEAN = [[0, "Label", "Placing Brick 2 x 4: click to put it down"], [0, "placeholder", "Search 28,507 parts…"],
         [2, "Button", "Recent 4"], [5, "Label", "2 bricks · stands up"]]


def test_a_clean_cut_passes(tmp_path):
    assert tool().refused(recorded(tmp_path, CLEAN) / "desktop") == []


def test_a_planted_path_is_refused(tmp_path):
    planted = CLEAN + [[41, "Label", "wrote /tmp/claude-1000/abc/scratchpad/herostudio/cap3/render.png"]]
    wrong = tool().refused(recorded(tmp_path, planted) / "desktop")
    assert len(wrong) == 1
    assert wrong[0].startswith("drop, frame 41: a path under /tmp")


def test_each_kind_of_word_is_refused(tmp_path):
    module = tool()
    for words in ["/home/someone/Downloads/car.png", "/mnt/Projects/x", "claude-1000", "scratchpad",
                  "Gathering the light…", "Saving…", "Working out its steps for the link", "10%",
                  "castle, tower, wizard"]:
        folder = tmp_path / str(abs(hash(words)))
        assert module.refused(recorded(folder, [[3, "Label", words]]) / "desktop"), words


def test_a_cut_with_no_record_of_its_words_is_refused(tmp_path):
    cut = recorded(tmp_path, CLEAN) / "desktop"
    (cut / "texts.json").unlink()
    assert tool().refused(cut)


def test_the_tool_refuses_before_it_encodes(tmp_path):
    """The real command on a run with a planted path: it stops, says why, and
    writes nothing where the loop's files would go."""
    frames = recorded(tmp_path / "frames", CLEAN + [[7, "RichTextLabel", "Saved to /home/you/model.png"]])
    out = tmp_path / "out"
    run = subprocess.run([sys.executable, str(TOOL), f"--frames={frames}", "--only=desktop", f"--out={out}"],
                         capture_output=True, text=True, timeout=120)
    assert run.returncode != 0
    assert "refused" in run.stderr and "/home/you/model.png" in run.stderr
    assert not out.exists() or not any(out.iterdir())
