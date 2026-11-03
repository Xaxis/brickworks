"""A change to the app's window names the browser flows that drive it.

tools/release/flows_for.py names the preview checks whose flows visit what a
change touched. A flow reaches a page by its address and the app's window by
its controls' names: booklet_edit_flow presses page_add_arrow and drags on
page_canvas, and a change to the page editor did not name it, so rel-m226
held on it (2026-10-30). These run it on the page editor and on a probe, and
match a flow's quoted names to a script's, numbered ones included.
"""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SCRIPT = ROOT / "tools" / "release" / "flows_for.py"


def _flows_for():
    spec = importlib.util.spec_from_file_location("flows_for", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _run(*files: str) -> str:
    return subprocess.run([sys.executable, str(SCRIPT), *files], cwd=ROOT,
                          capture_output=True, text=True, check=True).stdout


def test_the_page_editor_names_booklet_edit() -> None:
    out = _run("src/ui/page_editor.gd")
    line = next((l for l in out.splitlines() if l.startswith("booklet_edit ")), "")
    assert "src/ui/page_editor.gd" in line and "page_canvas" in line, out
    assert "booklet_edit" in out.splitlines()[-1].split(), out


def test_a_probe_names_no_flow() -> None:
    out = _run("src/dev/booklet_edit_probe.gd")
    assert "nothing for the browser flows here" in out, out


def test_a_numbered_name_is_reached_by_its_number_only(tmp_path: Path) -> None:
    flows_for = _flows_for()
    gd = 'var name := "page_picture_%d" % number\n_named["page_canvas"] = canvas\n'
    names, numbered = set(flows_for.CONTROL.findall(gd)), set(flows_for.NUMBERED.findall(gd))
    assert names == {"page_canvas"} and numbered == {"page_picture_"}
    flow = tmp_path / "a_flow.mjs"
    flow.write_text('const picture = "page_picture_4";\nawait where(`page_pictures`);\n')
    assert flows_for.reaches(flow, names, numbered) == {"page_picture_4"}
    flow.write_text("await where('page_canvas');\nconst other = 'page_picture_x';\n")
    assert flows_for.reaches(flow, names, numbered) == {"page_canvas"}
    flow.write_text("await where('page_canvases');\n")
    assert flows_for.reaches(flow, names, numbered) == set()


def _checks(out: str) -> set[str]:
    last = out.splitlines()[-1]
    return set(last.removeprefix("checks: ").split()) if last.startswith("checks: ") else set()


def test_what_a_session_hears_names_the_relays_flows() -> None:
    """What a session hears through the connector is made in the tab, and a
    change to it is the relay's address: the method said once and the
    sittings (claude_connector.gd), the method's words (connector_guide.gd)
    and the guide (assistant.gd) each name every check the relay's own file
    does, model_view among them. connector_guide.gd named none, and
    claude_connector.gd only the flows quoting a tool it happened to name;
    model_view pinned the method's first words, and went unrun from rel-m237,
    which changed them, to rel-m250 (mcpview, 2026-11-02)."""
    relay = _checks(_run("api/mcp.js"))
    assert {"model_view", "tabs", "tabpair"} <= relay, relay
    for path in ("src/net/claude_connector.gd", "src/ai/connector_guide.gd", "src/ai/assistant.gd"):
        out = _run(path)
        line = next((l for l in out.splitlines() if l.startswith("model_view ")), "")
        assert f"/api/mcp ({path})" in line, out
        assert relay <= _checks(out), (path, sorted(relay - _checks(out)))
