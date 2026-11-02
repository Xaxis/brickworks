## The first screen compiles none of what Later loads, and loads none of it
## as it starts; each panel and dialog the window reaches is made the first
## time it is asked for, where it was made before, and opens.
##
##   godot --headless --path . --script src/dev/lazystart_probe.gd
##
## Loading main.gd compiled all 308 of the app's scripts before the first
## frame (webstart, 2026-10-30): it named 147 classes, and they nearly all
## named each other. The features are now reached through Later, by name,
## and this reads what Godot itself loaded, not what the code says:
##
##   main.tscn loaded, none of Later's scripts is (ResourceLoader.has_cached),
##   and how long the load took, which is main.gd's compile;
##   the window up and settled, still none, and nothing asked Later for one,
##   nor once a signed-in person's collection has come;
##   each member asked for as a probe or a check asks (main.get), made once,
##   over the window under the sign-in screens, or in the tools' column
##   above Stress's legend; the assistant with its panel and Claude's
##   connector; and the bin's Techniques tab counted them all along;
##   the menus' commands open the parts list, a figure, Settings and its keys,
##   Motions and Simulate, and Escape puts each away;
##   and what each first load took, printed.
##
## It names no class Later loads: naming one would compile it here first.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check("before the app, none of Later's scripts is loaded: %s" % ", ".join(_loaded()),
		_loaded().is_empty())
	var began: int = Time.get_ticks_usec()
	var scene: PackedScene = load("res://src/main.tscn")
	var compiled_ms: float = (Time.get_ticks_usec() - began) / 1000.0
	print("  main.tscn loaded, main.gd and all it names compiled, in %.0f ms" % compiled_ms)
	_check("main.gd compiled without one of them: %s" % ", ".join(_loaded()), _loaded().is_empty())

	_main = scene.instantiate()
	root.add_child(_main)
	for _n: int in 600:
		await process_frame
		_shell = _main.get("_shell")
		if _shell != null and _main.get("_bin") != null and bool(_main.get("_built")):
			break
	if _shell == null:
		print("  lazystart probe: SKIPPED — the shell never came up")
		quit(3)
		return
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	await _frames(120)
	_check("the window up and settled, still none loaded: %s" % ", ".join(_loaded()),
		_loaded().is_empty())
	_check("and nothing asked Later for one: %s" % str(Later.took), Later.took.is_empty())
	# A signed-in person's collection arrives a few seconds in: it told the
	# assistant, and asking for it made one then, on the web 5 to 9 s of
	# compiling under the person's first click (load_check, 2026-10-31).
	_shell.collection.store.changed.emit()
	await _frames(3)
	_check("their collection arriving makes no assistant: %s" % str(Later.took),
		Later.took.is_empty() and _main.get("_assistant_made") == null)

	await _a_model()
	_made_where_they_were()
	await _opened_by_the_menus()
	print("  first loads, ms: %s" % str(Later.took))
	_finish()


## Later's classes whose scripts are loaded.
func _loaded() -> PackedStringArray:
	var out := PackedStringArray()
	for name: StringName in Later.PATHS:
		if Later.loaded(name):
			out.append(name)
	return out


## A few bricks, for the commands that want a model.
func _a_model() -> void:
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	builder.held_part = "3001"
	builder.held_color = 4
	for column: int in 3:
		builder.update_preview(Vector3(column * 80.0 + 40.0, 400.0, 40.0), Vector3.DOWN)
		builder.place()
	await _frames(5)
	_check("a model of %d bricks to work on" % world.brick_count(), world.brick_count() >= 3)


## Each member, asked for, is made once and put where _build_ui put it.
func _made_where_they_were() -> void:
	var hud: Node = _main.get_node("HUD")
	var over: Array[String] = ["_inventory", "_figures", "_controls", "_mosaic", "_brickify",
		"_elements", "_render", "_share_panel", "_page_editor"]
	var column: Array[String] = ["_pose", "_hidden_colours", "_simulate"]
	var gates: Array[Node] = []
	var found: Node = _main.get("_gate")
	if is_instance_valid(found) and found.get_parent() == hud:
		gates.append(found)
	# What another makes first: what plays motions (Render's, Motions'), and the
	# assistant (its panel's).
	var others: Array[String] = ["_motions", "_assistant"]
	for member: String in others + over + column + ["_studio", "_saved_models", "_chat"]:
		_check("%s not made before it is asked for" % member, _main.get(member + "_made") == null)
		var got: Object = _main.get(member)
		_check("%s made when asked for" % member, got != null)
		if got == null:
			continue
		_check("%s made once" % member, is_same(_main.get(member), got)
			and is_same(_main.get(member + "_made"), got))
		if member in over:
			var panel: Control = got
			var under: bool = gates.all(func(gate: Node) -> bool:
				return panel.get_index() < gate.get_index())
			_check("%s over the window, under the sign-in screens" % member,
				panel.get_parent() == hud and under and not panel.visible)
		elif member in column:
			var panel: Control = got
			var stress: Control = _shell.stress.panel
			_check("%s in the tools' column above Stress's legend" % member,
				panel.get_parent() == stress.get_parent()
				and panel.get_index() < stress.get_index() and not panel.visible)
		elif got is Node:
			_check("%s in the tree" % member, (got as Node).is_inside_tree())
	_check("the assistant's panel is bound to the assistant",
		is_same(_main.get("_chat").get("assistant"), _main.get("_assistant")))
	var connector: Node = _main.get("_connector_made")
	_check("and Claude's connector made with it, in the tree",
		connector != null and connector.is_inside_tree())
	# The bin's Techniques tab said its count at start without loading them.
	var said: String = ""
	for child: Node in (_main.get("_bin") as Node).get("_category_row").get_children():
		if str(child.get_meta("category", "")) == "Techniques":
			said = (child as Button).text
	var count: int = Later.script(&"Techniques").all().size()
	_check("the bin's tab says \"%s\", and there are %d techniques" % [said, count],
		said == "Techniques %d" % count)


## The menus' commands open what was made on first use, and Escape puts it away.
func _opened_by_the_menus() -> void:
	for pair: Array in [["parts_list", "_inventory"], ["minifig", "_figures"],
			["settings", "_controls"], ["keys", "_controls"], ["pose", "_pose"],
			["simulate", "_simulate"]]:
		var command: String = pair[0]
		var panel: Control = _main.get(pair[1])
		_check("%s can be run" % command, _shell.can(command))
		await _shell.run(command)
		await _frames(6)
		var showing: bool = panel.visible if pair[1] != "_inventory" else bool(panel.call("is_showing"))
		_check("%s opens %s" % [command, pair[1]], showing)
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape)
		var up := escape.duplicate() as InputEventKey
		up.pressed = false
		root.push_input(up)
		await _frames(6)
		if panel.visible and pair[1] in ["_pose", "_simulate"]:
			panel.call("close")
			await _frames(3)
		var still: bool = panel.visible if pair[1] != "_inventory" else bool(panel.call("is_showing"))
		_check("%s put away again" % pair[1], not still)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _check(what: String, ok: bool) -> bool:
	print("  %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _finish() -> void:
	print("")
	if _failures == 0:
		print("lazystart probe: all checks passed")
	else:
		print("lazystart probe: %d check(s) FAILED" % _failures)
	if _main != null:
		_main.queue_free()
		await process_frame
	quit(1 if _failures else 0)
