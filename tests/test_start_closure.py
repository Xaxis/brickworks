"""tools/web/start_closure.py: the first screen begins at every entry point
project.godot names, so whatever the engine loads before the app's own code
runs is compiled at the start and kept in the pack the engine waits for.

The web app never started once the main loop became a class of our own
(BrickworksLoop, 2026-11-07): the first screen began at src/main.tscn alone,
so the main loop went with the data pack, which is not mounted yet when the
engine makes it. Read from project.godot, the next main loop, autoload or
main scene put there is in the first pack without anyone remembering to add
it; one it cannot place stops the export.
"""

from __future__ import annotations

import importlib.util
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
_spec = importlib.util.spec_from_file_location("start_closure_under_test", ROOT / "tools/web/start_closure.py")
start_closure = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(start_closure)

LATER = 'class_name Later\nextends RefCounted\n\nconst PATHS := {\n\t&"Big": "res://src/big.gd",\n}\n'


def scene(uid: str, *named: tuple[str, str]) -> str:
    """A scene file: its header, with a uid when given, and the files it names."""
    header = "[gd_scene format=3" + (f' uid="{uid}"' if uid else "") + "]\n\n"
    lines = [f'[ext_resource type="{kind}" path="{path}" id="{n}"]' for n, (kind, path) in enumerate(named, 1)]
    return header + "\n".join(lines) + '\n\n[node name="Root" type="Node"]\nscript = ExtResource("1")\n'


def project(root: Path, settings: str, files: dict[str, str]) -> Path:
    """A project at root: its project.godot, src/later.gd, and these files."""
    root.mkdir(parents=True, exist_ok=True)
    (root / "project.godot").write_text("; Engine configuration file.\n\nconfig_version=5\n\n" + settings)
    for name, text in {"src/later.gd": LATER, "src/big.gd": "class_name Big\nextends Node\n", **files}.items():
        (root / name).parent.mkdir(parents=True, exist_ok=True)
        (root / name).write_text(text)
    return root


def test_the_app_s_main_loop_is_compiled_at_the_start() -> None:
    """The engine makes BrickworksLoop (run/main_loop_type) before it loads
    the main scene: it, and what it names, are the first screen's."""
    closure = start_closure.closure()
    assert "res://src/boot/brickworks_loop.gd" in closure, \
        "BrickworksLoop, project.godot's main loop, is not compiled at the start: the web app never starts"
    assert "res://src/main.gd" in closure


def test_every_entry_point_project_godot_names_is_where_the_start_begins(tmp_path: Path) -> None:
    """The main scene by uid and the scene it holds, the main loop by class
    name and what it names, and each autoload, a script or a scene: all are
    compiled at the start; a class Later loads, and a script nothing names,
    are not."""
    root = project(tmp_path, """[application]

config/name="Fixture"
run/main_scene="uid://cstart"
; The engine's main loop, made before the main scene.
run/main_loop_type="OurLoop"

[autoload]

Bus="*res://src/bus.gd"
Hud="*uid://chud"

[display]

window/size/viewport_width=1600
""", {
        "src/screens/start.tscn": scene("uid://cstart", ("Script", "res://src/screens/start.gd"),
                                        ("PackedScene", "res://src/screens/bar.tscn")),
        "src/screens/start.gd": "extends Node\n",
        "src/screens/bar.tscn": scene("", ("Script", "res://src/screens/bar.gd")),
        "src/screens/bar.gd": "extends Node\n",
        "src/boot/our_loop.gd": "class_name OurLoop\nextends SceneTree\n\nvar helper := Helper.new()\nvar big: Big\n",
        "src/util/helper.gd": "class_name Helper\nextends RefCounted\n",
        "src/bus.gd": "extends Node\n",
        "src/hud/hud.tscn": scene("uid://chud", ("Script", "res://src/hud/hud.gd")),
        "src/hud/hud.gd": "extends CanvasLayer\n",
        "src/unused.gd": "class_name Unused\nextends Node\n",
    })
    assert start_closure.closure(root) == {
        "res://src/screens/start.gd", "res://src/screens/bar.gd", "res://src/boot/our_loop.gd",
        "res://src/util/helper.gd", "res://src/bus.gd", "res://src/hud/hud.gd"}
    assert start_closure.outside(root) == {"res://src/later.gd", "res://src/big.gd", "res://src/unused.gd"}


def test_the_engine_s_own_main_loop_needs_no_script(tmp_path: Path) -> None:
    for n, loop in enumerate(("", 'run/main_loop_type="SceneTree"\n')):
        root = project(tmp_path / str(n), f'[application]\n\nrun/main_scene="res://src/main.tscn"\n{loop}', {
            "src/main.tscn": scene("", ("Script", "res://src/main.gd")),
            "src/main.gd": "extends Node\n",
        })
        assert start_closure.first_screen(root) == ["res://src/main.gd"]


def test_an_entry_point_it_cannot_place_is_an_error_not_a_script_left_out(tmp_path: Path) -> None:
    files = {"src/main.tscn": scene("", ("Script", "res://src/main.gd")), "src/main.gd": "extends Node\n"}
    for n, (settings, says) in enumerate((
        ('[application]\n\nrun/main_scene="res://src/main.tscn"\nrun/main_loop_type="Gone"\n', "Gone"),
        ('[application]\n\nrun/main_scene="res://src/main.tscn"\n\n[autoload]\n\nBus="*res://src/bus.gd"\n',
         "res://src/bus.gd"),
        ('[application]\n\nrun/main_scene="uid://cnowhere"\n', "uid://cnowhere"),
        ('[application]\n\nconfig/name="No scene"\n', "run/main_scene"),
    )):
        root = project(tmp_path / str(n), settings, files)
        try:
            start_closure.closure(root)
        except ValueError as error:
            assert says in str(error), f"{settings!r}: {error}"
            continue
        raise AssertionError(f"{settings!r} gave a first screen, where it names what is not there")
