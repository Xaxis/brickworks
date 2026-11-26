"""tools/callcheck.py names a call to a method that is not there.

handkeep2 took Builder._lift_on_top out (2026-11-26) and left two callers:
`builder._lift_on_top()` on a member typed Builder, and
`_builder.call("_lift_on_top")` in a probe. Godot's own check passed both, and
a release train went red on six probes. Each test here is a small tree of
scripts and the engine classes it needs, in the shape of a real finding (or a
real call that must not be named), so it runs in a moment with no engine.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "tools"))

import callcheck  # noqa: E402


def _cls(inherits, methods=(), members=None):
    return {"inherits": inherits, "methods": {m: None for m in methods}, "members": members or {}}


API = {
    "classes": {
        "Object": _cls(None, ["call", "callv", "call_deferred", "has_method", "connect", "free", "get"]),
        "RefCounted": _cls("Object", ["reference"]),
        "Node": _cls("Object", ["add_child", "get_parent", "queue_free"], {"name": "StringName"}),
        "Node3D": _cls("Node", ["look_at"], {"position": "Vector3"}),
        "Resource": _cls("RefCounted", ["duplicate"]),
        "Script": _cls("Resource", ["can_instantiate"]),
        "GDScript": _cls("Script", ["new", "get_script_constant_map"]),
        "JavaScriptObject": _cls("RefCounted"),
        "JavaScriptBridge": {"inherits": "Object", "members": {},
                             "methods": {"get_interface": "JavaScriptObject", "eval": None}},
    },
    "builtins": {
        "String": {"methods": {"begins_with": "bool", "length": "int"}, "members": {}},
        "Array": {"methods": {"append": None, "size": "int"}, "members": {}},
        "Dictionary": {"methods": {"get": None, "keys": "Array", "is_empty": "bool"}, "members": {}},
        "Callable": {"methods": {"call": None, "bind": "Callable", "is_valid": "bool"}, "members": {}},
        "Signal": {"methods": {"connect": "int", "emit": None}, "members": {}},
        "Vector3": {"methods": {"normalized": "Vector3"}, "members": {"x": "float"}},
    },
    "functions": {"print": None, "len": "int", "load": "Resource", "preload": "Resource", "str": "String"},
    "singletons": {"JavaScriptBridge": "JavaScriptBridge"},
}

BUILDER = """class_name Builder
extends RefCounted

var carrying: Dictionary = {}


func is_carrying() -> bool:
	return not carrying.is_empty()
"""


def _tree(tmp_path: Path, scripts: dict[str, str]) -> Path:
    for rel, text in scripts.items():
        path = tmp_path / "src" / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
    return tmp_path


def _named(tmp_path: Path, scripts: dict[str, str]) -> list[str]:
    findings, _n, _calls = callcheck.run(_tree(tmp_path, scripts), API, jobs=1)
    return [str(f) for f in findings]


def test_a_member_typed_builder_calling_a_removed_method(tmp_path):
    # Assemblies._copies_state, as it was at 35e93f7f7.
    found = _named(tmp_path, {"builder.gd": BUILDER, "assemblies.gd": """class_name Assemblies
extends RefCounted

var builder: Builder


func _copies_state() -> Array:
	var lifted: bool = builder.is_carrying() and builder._lift_on_top()
	return [lifted]
"""})
    assert len(found) == 1, found
    assert found[0].startswith("src/assemblies.gd:8: builder._lift_on_top()")
    assert "Builder has no method _lift_on_top" in found[0]


def test_a_method_called_by_name_on_a_typed_variable(tmp_path):
    # wingplace_probe, as it was at 35e93f7f7.
    found = _named(tmp_path, {"builder.gd": BUILDER, "probe.gd": """extends Node

var _builder: Builder


func _state() -> Array:
	return [_builder.call("is_carrying"), _builder.call("_lift_on_top"), _builder.callv("_gone", [])]
"""})
    assert [f.split(": ")[1] for f in found] == ['_builder.call("_lift_on_top")', '_builder.callv("_gone")'], found


def test_an_untyped_receiver_is_named_only_for_a_method_nothing_defines(tmp_path):
    found = _named(tmp_path, {"builder.gd": BUILDER, "user.gd": """extends RefCounted


func use(thing) -> void:
	thing.is_carrying()
	thing.queue_free()
	thing.never_written_anywhere()
"""})
    assert len(found) == 1 and "never_written_anywhere is defined by no script" in found[0], found


def test_a_guard_names_the_method_it_guards(tmp_path):
    found = _named(tmp_path, {"builder.gd": BUILDER, "user.gd": """extends RefCounted

var builder: Builder


func use() -> void:
	if builder.has_method("_gone"):
		builder.call("_gone")
	if builder.has_method("is_carrying"):
		print(builder.is_carrying())
"""})
    assert [f.split(":")[1] for f in found] == ["7", "8"], found


def test_a_method_handed_over_as_a_value(tmp_path):
    found = _named(tmp_path, {"builder.gd": BUILDER, "user.gd": """extends Node

signal ready_now
var builder: Builder


func use() -> void:
	var a: Callable = Callable(builder, "_gone")
	var b: Callable = builder._gone.bind(1)
	ready_now.connect(builder._gone)
	connect("ready_now", builder._gone)
	var fine: Callable = builder.is_carrying.bind()
	ready_now.connect(_on_ready)
	ready_now.connect(_on_nothing)
	print(a, b, fine)


func _on_ready() -> void:
	pass
"""})
    lines = [int(f.split(":")[1]) for f in found]
    assert lines == [8, 9, 10, 11, 14], found
    assert found[2].split(": ")[1] == "connect(builder._gone)"


def test_a_base_typed_variable_may_call_what_a_derived_class_defines(tmp_path):
    found = _named(tmp_path, {
        "base.gd": "class_name Base\nextends Node\n\n\nfunc base_only() -> void:\n\tpass\n",
        "derived.gd": "class_name Derived\nextends Base\n\n\nfunc derived_only() -> void:\n\tpass\n",
        "user.gd": """extends RefCounted


func use(b: Base) -> void:
	b.base_only()
	b.derived_only()
	b.add_child(null)
	b.nowhere_at_all()
""",
    })
    assert len(found) == 1 and "b.nowhere_at_all()" in found[0], found


def test_a_bare_call_to_what_the_base_class_lost(tmp_path):
    found = _named(tmp_path, {
        "base.gd": "class_name Base\nextends Node3D\n\n\nfunc kept() -> void:\n\tpass\n",
        "child.gd": """extends Base


func _ready() -> void:
	kept()
	look_at(position)
	add_child(Node.new())
	print(len([]))
	lost_in_base()
""",
    })
    assert len(found) == 1 and found[0].startswith("src/child.gd:9: lost_in_base()"), found


def test_a_field_typed_one_way_elsewhere(tmp_path):
    found = _named(tmp_path, {"builder.gd": BUILDER, "holder.gd": "class_name Holder\nextends RefCounted\n\nvar builder: Builder\n",
                              "user.gd": """extends RefCounted


func use(main) -> void:
	main.builder.is_carrying()
	main.builder._lift_on_top()
"""})
    assert len(found) == 1 and "main.builder._lift_on_top()" in found[0] and "Builder has no" in found[0], found


def test_a_deliberate_dynamic_call_is_marked_with_why(tmp_path):
    found = _named(tmp_path, {"user.gd": """extends RefCounted


func use(win) -> void:
	win.fetch_this()  # callcheck: dynamic, a JavaScript object's own method
	# callcheck: dynamic, the page's own function
	win.also_the_page()
	win.no_reason_given()  # callcheck: dynamic
	print("fine")  # callcheck: dynamic, nothing here needs it
	win.not_understood()  # callcheck: whatever
"""})
    # 5 and 7 are excused; 8's mark gives no reason, 9's excuses nothing, 10's is not one.
    assert [f.split(":")[1] for f in found] == ["8", "8", "9", "10", "10"], found
    assert "say why" in found[0] and "win.no_reason_given()" in found[1]
    assert "nothing on its line needs it" in found[2]
    assert "not understood" in found[3] and "win.not_understood()" in found[4]


def test_a_javascript_object_has_any_method(tmp_path):
    found = _named(tmp_path, {"web.gd": """extends RefCounted

var _window: JavaScriptObject = JavaScriptBridge.get_interface("window")


func use() -> void:
	_window.fetch_it()
	var doc := JavaScriptBridge.get_interface("document")
	doc.querySelector("x").whatever()
"""})
    assert found == [], found


def test_a_script_handed_out_by_later_is_its_class(tmp_path):
    found = _named(tmp_path, {"builder.gd": BUILDER, "later.gd": """class_name Later
extends RefCounted


static func script(name: StringName) -> GDScript:
	return load(str(name))


static func make(name: StringName) -> Object:
	return script(name).new()
""", "user.gd": """extends RefCounted


func use() -> void:
	var maker: GDScript = Later.script(&"Builder")
	maker.new().is_carrying()
	maker.get_script_constant_map()
	maker.made_up()
	var made: RefCounted = Later.make(&"Builder")
	made.is_carrying()
	made.also_made_up()
"""})
    assert [f.split(": ")[1] for f in found] == ["maker.made_up()", "made.also_made_up()"], found


def test_a_callables_call_is_handed_arguments_not_a_name(tmp_path):
    found = _named(tmp_path, {"user.gd": """extends RefCounted


func use(told: Callable, long_signature: int,
		clear: Callable = Callable()) -> void:
	told.call("frame 1 of 2")
	if clear.is_valid():
		clear.call("survey", long_signature)
	var attend: Callable = func(work: Callable) -> void: work.call("anything")
	attend.call(told)
"""})
    assert found == [], found


def test_strings_and_comments_are_not_read_as_calls(tmp_path):
    found = _named(tmp_path, {"user.gd": '''extends RefCounted

const HELP: String = """A page of help that says thing.gone() and (unbalanced
# not a comment, a line of the help
"""


func use() -> void:
	print("x.never_there() in a string")  # and y.never_there() in a comment
	never_there_either()
'''})
    assert len(found) == 1 and found[0].startswith("src/user.gd:10: never_there_either()"), found


def test_a_class_in_a_class_and_a_script_by_path(tmp_path):
    found = _named(tmp_path, {"outer.gd": """class_name Outer
extends RefCounted


class Inner extends RefCounted:
	func inner_only() -> void:
		pass


static func make() -> Inner:
	return Inner.new()
""", "by_path.gd": """extends "res://src/outer.gd"


func use() -> void:
	var i: Outer.Inner = Outer.make()
	i.inner_only()
	i.gone_from_inner()
	make().inner_only()
"""})
    assert len(found) == 1 and "i.gone_from_inner()" in found[0] and "Outer.Inner has no" in found[0], found


@pytest.mark.skipif(shutil.which("godot") is None, reason="no godot to read the engine's classes from")
def test_this_tree_calls_nothing_that_is_not_there():
    findings, n_scripts, n_calls = callcheck.run(ROOT, callcheck.load_api(), jobs=4)
    assert n_scripts > 500 and n_calls > 100000
    assert not findings, "\n".join(str(f) for f in findings)
