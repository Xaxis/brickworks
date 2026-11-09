"""A change to the app's window names the browser flows that drive it.

tools/release/flows_for.py names the preview checks whose flows visit what a
change touched. A flow reaches a page by its address and the app's window by
its controls' names: booklet_edit_flow presses page_add_arrow and drags on
page_canvas, and a change to the page editor did not name it, so rel-m226
held on it (2026-10-30). These run it on the page editor and on a probe, and
match a flow's quoted names to a script's, numbered ones included. The bin
names its controls with spaces and single words, which were not read, and
bin went unrun on four releases (2026-11-09): these run it on the bin and
on each script reached since, and read names of every shape.
"""

from __future__ import annotations

import importlib.util
import subprocess
import sys
from pathlib import Path

import pytest

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


def test_the_parts_bin_names_the_bins_flow() -> None:
    """parts_bin.gd names its controls with spaces and single words
    ("part search", "techniques", "technique " + a name), and only words
    joined by underscores were read: binrow changed the bin's shelves and
    flows_for said "none named", though bin_flow drives them, and bin went
    unrun on rel-m273 to m276 (2026-11-09)."""
    out = _run("src/ui/parts_bin.gd")
    line = next((l for l in out.splitlines() if l.startswith("bin ")), "")
    assert "src/ui/parts_bin.gd" in line and "part search" in line, out
    assert "bin" in _checks(out), out
    flows_for = _flows_for()
    hits = flows_for.reaches(ROOT / "tools" / "web" / "bin_flow.mjs", *flows_for.controls("src/ui/parts_bin.gd"))
    assert {"techniques", "technique window in a wall", "part search", "first fold"} <= hits, hits


@pytest.mark.parametrize("path, check, name", [
    # Main names the docks' rails and the view; a tooltip up it finds by
    # Tooltips; the bin keeps each tile's ThumbTile in a meta.
    ("src/ui/side_dock.gd", "dialogs", "parts_rail"),
    ("src/ui/marquee.gd", "link", "view"),
    ("src/ui/tooltips.gd", "cursor", "tooltip"),
    ("src/ui/thumb_tile.gd", "bin_tiles_flow.mjs", "tile picture 1"),
    # Made by joining: an owner's prefix, a list's keys.
    ("src/ui/claude_tab_view.gd", "tabpair", "account_new_chat"),
    ("src/render/render_settings.gd", "product_render", "render_look_product"),
    ("src/assembly/pinned_comments.gd", "together", "pin_mark_1"),
])
def test_a_control_named_another_way_names_its_flow(path: str, check: str, name: str) -> None:
    """Each script whose controls only the reading of every way a name is
    given reaches names the flow that drives them, by the name it drives."""
    out = _run(path)
    if check.endswith(".mjs"):
        # A flow no preview check runs is still said.
        assert check in next((l for l in out.splitlines() if l.startswith("also visit them")), ""), out
        return
    line = next((l for l in out.splitlines() if l.startswith(f"{check} ")), "")
    assert f"{path} (" in line and name in line, out
    assert check in _checks(out), out


def test_names_are_read_as_the_window_is_given_them() -> None:
    """A giver's keys of every shape, made ones as shapes; not a call's
    argument, a comparison, an index read, a local's own start, or a
    dictionary of another function."""
    flows_for = _flows_for()
    gd = (
        "func controls_by_name() -> Dictionary:\n"
        '\tvar named: Dictionary = {"parts list": _scroll, "brief": _input}\n'
        '\tnamed["techniques"] = child\n'
        '\tnamed["technique " + str(child.get_meta("technique"))] = child\n'
        '\tnamed["tile picture %d" % (n + 1)] = cell.get_meta("tile")\n'
        '\tnamed[prefix + "_comments"] = pill\n'
        '\tvar key: String = "phone_sheet_" + title\n'
        '\tnamed[key + "_done"] = done\n'
        '\tfor swatch: Node in find_children("favourite_*", "Button", true, false):\n'
        "\t\tnamed[str(swatch.name)] = swatch\n"
        '\tif _view == "list":\n'
        '\t\tnamed["motions_play"] = row["pick"]\n'
        "\tnamed.merge(_palette_controls())\n"
        "\treturn named\n"
        "\n"
        "func _palette_controls() -> Dictionary:\n"
        '\treturn {"palette new": _new}\n'
        "\n"
        "func _other() -> void:\n"
        '\tvar data := {"elsewhere": 1}\n'
    )
    assert flows_for._gives(gd) == {
        "parts list", "brief", "techniques", "technique %s", "tile picture %d", "%s_comments",
        "phone_sheet_%s", "favourite_%s", "motions_play", "palette new"}


def test_a_flow_reaches_a_name_by_quote_property_or_start(tmp_path: Path) -> None:
    """A name quoted, read as a property, or made in a template reaches; a
    message, a word compared or given as a value, and the page's own
    document searched by a word do not."""
    flows_for = _flows_for()
    given = {"part search", "techniques", "technique %s", "tile picture %d", "parts_rail", "tooltip",
             "list", "view", "new"}
    flow = tmp_path / "a_flow.mjs"
    flow.write_text(
        'await press("techniques");\n'
        'await where("technique window in a wall");\n'
        "const box = await where('part search');\n"
        "for (let n = 1; n < 4; n++) await where(`tile picture ${n}`);\n"
        "const rail = c.parts_rail;\n"
        "const tip = (window.brickworksControls || {}).tooltip;\n"
        'if (q.get("op") === "list") answer();\n'
        'await ask({ op: "new" });\n'
        'const shown = document.getElementById("view").hidden;\n'
        'check("technique rows: shown", true);\n')
    assert flows_for.reaches(flow, set(), set(), given) == {
        "techniques", "technique window in a wall", "part search", "tile picture ${…}", "parts_rail", "tooltip"}


def test_a_changed_page_names_the_flow_that_crawls_every_page() -> None:
    """coming_soon_check.mjs visits every page of the site and names none: a
    change to any page, a script a page loads, or the docs names it, and an
    API route does not (2026-11-07)."""
    for path in ("web/plans.html", "web/download.html", "web/beta.js", "docs-site/plans.md"):
        assert "coming_soon" in _checks(_run(path)), (path, _run(path))
    assert "coming_soon" not in _checks(_run("api/_parts.js"))
    flows_for = _flows_for()
    assert flows_for.a_page("/plans") and flows_for.a_page("/") and flows_for.a_page("/docs")
    assert not flows_for.a_page("/m/") and not flows_for.a_page("/api/share") and not flows_for.a_page("/no-such-page")
