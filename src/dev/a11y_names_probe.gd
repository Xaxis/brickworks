## Every control a person can press, type in or choose from has a name a
## screen reader can say.
##
##   godot --path . --resolution 1400x900 --script src/dev/a11y_names_probe.gd
##
## Godot 4.7 tells a screen reader about the interface through AccessKit:
## each control's accessibility_name, or for a button its words, for a
## field its placeholder (Control._get_accessibility_name and its
## overrides, which this follows). A button with no words and no name is
## read by its tooltip, and here a tooltip is help: "3001\nBrick 2 x 4\n2 x 4
## studs, 1 brick\nRight-click to keep it in Favourites…" is a paragraph
## read out every time the tile is reached. So a name read from a tooltip of
## more than one line is counted as no name.
##
## It walks the whole scene from launch, then every dialog and panel the
## menus open, the bin's tabs, a selection's properties and the Settings
## with its AI page, and counts each visible control with no name once,
## however often it was seen. Every menu's every item is read too, open or
## not. It fails with the count and a line for each, and passes at none.
extends SceneTree

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bin: PartsBin
## instance id -> a line saying what it is, for each control with no name
var _unnamed: Dictionary = {}
## instance ids of every operable control seen, named or not
var _seen: Dictionary = {}


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	# Godot's own Save dialog, never the platform's: this shell's session
	# bus is the owner's, and theirs would open on their screen.
	SaveTo.native = false
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	var store: ModelStore = _main.get("_store")
	store.keeps = false
	_main.call("clear_model")
	await _frames(6)
	_walk_all("launch")

	# A part on the model, selected, so the properties show it.
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	var where := Transform3D(Basis.IDENTITY, Vector3(0, 24, 0))
	var brick: int = world.add_brick("3001", 4, where)
	builder.register(brick, "3001", where)
	builder.select_brick(brick, false)
	await _frames(6)
	_walk_all("a selection")
	for name: String in WITH_A_SELECTION:
		await _open_and_walk(name)

	# The bin's tabs, each in turn.
	for tab: String in [PartsBin.RECENT, PartsBin.FAVOURITES, PartsBin.TECHNIQUES]:
		_bin.call("show_category", tab)
		await _frames(8)
		_walk_all("the bin's " + tab)
	_bin.call("show_category", "All")
	await _frames(4)

	# Every dialog and panel the menus open, one at a time, put away
	# before the next.
	# A few by name, after --: openers=settings,keys.
	var openers: Array[String] = OPENERS.duplicate()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("openers="):
			openers.assign(arg.trim_prefix("openers=").split(",", false))
	for name: String in openers:
		await _open_and_walk(name)
	# Settings, AI, its whole form shown: another AI chosen.
	if openers.has("settings"):
		var settings: ControlsDialog = _main.get("_controls")
		settings.open_ai()
		settings.ai.who_key.button_pressed = true
		await _frames(12)
		_walk_all("settings, AI")
		settings.ai.who_claude.button_pressed = true
		settings.visible = false
		await _frames(4)

	var count: int = _unnamed.size()
	if count > 0:
		print("a11y names probe: %d of %d controls a person can operate have no name:"
			% [count, _seen.size()])
		var lines: Array = _unnamed.values()
		lines.sort()
		for line: String in lines:
			print("    " + line)
	_check("every control a person can operate has a name (%d of %d have none)"
		% [count, _seen.size()], count == 0)
	_finish()


## The commands that open a dialog or a panel, as the menus run them.
## Nothing that opens the system's file chooser or leaves the app.
const OPENERS: Array[String] = [
	"settings", "keys", "about", "save_as", "library", "versions", "render",
	"pose", "instructions", "share", "clear", "account", "select_find",
	"timeline", "parts_list", "collection",
	"collection_need", "collection_build", "minifig", "mosaic", "brickify",
	"part_maker", "print_part", "sticker", "measure", "simulate",
	"hidden_colours", "panel_outliner", "stress", "cut", "floor_custom",
]

## And those that ask for a part selected first.
const WITH_A_SELECTION: Array[String] = ["make_submodel", "printed_versions", "flex"]


func _open_and_walk(name: String) -> void:
	var before: Dictionary = _shown()
	if not _shell.run(name):
		print("  (%s cannot be run now)" % name)
		return
	await _frames(12)
	_walk_all(name)
	# Its work done before it is put away (Colour the hidden parts draws its
	# pictures): a coroutine still waiting at quit broke the heap on exit.
	await _idle()
	# Put away: Escape first, as a person would; then anything still up
	# that was not before. A dialog is closed as its window's close button
	# closes it, so whoever awaits its answer hears "cancelled" (SaveTo.ask
	# left waiting held its dialog in a static, and the heap broke at exit).
	_key(KEY_ESCAPE)
	await _frames(4)
	for id: int in _shown():
		if before.has(id):
			continue
		var thing: Object = instance_from_id(id)
		if thing is AcceptDialog and (thing as Window).visible:
			(thing as Window).close_requested.emit()
		if thing is Window and (thing as Window).visible:
			(thing as Window).hide()
		elif thing is CanvasItem:
			(thing as CanvasItem).visible = false
	await _frames(4)


## The windows and the panels of the shell that are showing, by id: what
## an opener put up is what is here after it and was not before.
func _shown() -> Dictionary:
	var out: Dictionary = {}
	_gather_shown(root, out, 0)
	return out


func _gather_shown(node: Node, out: Dictionary, depth: int) -> void:
	if node is Window and node != root:
		if (node as Window).visible:
			out[node.get_instance_id()] = true
		return
	if depth > 6:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is CanvasItem:
		out[node.get_instance_id()] = true
	for child: Node in node.get_children(true):
		_gather_shown(child, out, depth + 1)


func _walk_all(when: String) -> void:
	_walk(root, when)
	_read_menus(root, when)


func _walk(node: Node, when: String) -> void:
	if node is Window and node != root and not (node as Window).visible:
		return
	if node is CanvasItem and not (node as CanvasItem).visible:
		return
	if node is Control:
		var control: Control = node
		if _operable(control) and control.size.x >= 1.0 and control.size.y >= 1.0:
			var id: int = control.get_instance_id()
			_seen[id] = true
			if spoken(control).strip_edges().is_empty() and not _unnamed.has(id):
				_unnamed[id] = "%s  %s  [%s]  %s" % [when, control.get_class(),
					_where(control), control.tooltip_text.get_slice("\n", 0).left(50)]
	for child: Node in node.get_children(true):
		_walk(child, when)


## Every item of every menu in the tree, open or not.
func _read_menus(node: Node, when: String) -> void:
	if node is PopupMenu:
		var menu: PopupMenu = node
		for index: int in menu.item_count:
			if menu.is_item_separator(index):
				continue
			var key: String = "%d:%d" % [menu.get_instance_id(), index]
			_seen[key] = true
			if menu.get_item_text(index).strip_edges().is_empty() and not _unnamed.has(key):
				_unnamed[key] = "%s  menu item %d  [%s]  %s" % [when, index, _where(menu),
					menu.get_item_tooltip(index).get_slice("\n", 0).left(50)]
	for child: Node in node.get_children(true):
		_read_menus(child, when)


## What a person can press, type in or choose from, or what takes the
## keyboard's focus. A scroll bar is the scroll it is in. A control drawn by
## the app and pressed (the view cube and its arrows) shows the pointing
## hand, as a button does. Text a screen reader alone can stop on (Godot's
## labels, FOCUS_ACCESSIBILITY) is read as what it says.
static func _operable(control: Control) -> bool:
	if control is ScrollBar:
		return false
	# A spin box's field is said by the spin box's name.
	if control is LineEdit and control.get_parent() is SpinBox:
		return false
	if (control is Label or control is RichTextLabel) \
			and control.focus_mode == Control.FOCUS_ACCESSIBILITY:
		return false
	return control is BaseButton or control is LineEdit or control is TextEdit \
		or control is ItemList or control is Tree or control is Slider \
		or control is SpinBox or control is TabBar \
		or control.focus_mode != Control.FOCUS_NONE \
		or (control.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
			and control.mouse_filter == Control.MOUSE_FILTER_STOP)


## What a screen reader is told a control is called, as Godot 4.7 works it
## out (scene/gui/control.cpp, button.cpp, line_edit.cpp, text_edit.cpp),
## but for a tooltip of more than one line, which is help and not a name.
static func spoken(control: Control) -> String:
	var given: String = control.accessibility_name
	if given.is_empty() and not control.accessibility_labeled_by_nodes.is_empty():
		var labels: PackedStringArray = []
		for path: NodePath in control.accessibility_labeled_by_nodes:
			var label: Node = control.get_node_or_null(path)
			if label is Label:
				labels.append((label as Label).text)
		given = " ".join(labels)
	if control is Button or control is LinkButton:
		var words: String = str(control.get("text"))
		if not words.is_empty():
			return words if given.is_empty() or given == words else given + ": " + words
		if given.is_empty() and control.tooltip_text.strip_edges().split("\n").size() == 1:
			return control.tooltip_text
		return given
	if control is LineEdit or control is TextEdit:
		var placeholder: String = str(control.get("placeholder_text"))
		return placeholder if given.is_empty() else given
	if control is Label:
		return (control as Label).text if given.is_empty() else given
	if control is TabBar:
		var bar: TabBar = control
		if not given.is_empty():
			return given
		for index: int in bar.tab_count:
			if bar.get_tab_title(index).is_empty():
				return ""
		return "tabs" if bar.tab_count > 0 else ""
	return given


## The control's owner, by its class (the nearest scripted node above it
## with a class name), and its last steps down to it.
func _where(control: Node) -> String:
	var owner_name: String = ""
	var up: Node = control
	while up != null and owner_name.is_empty():
		var script: Script = up.get_script()
		if script != null and not script.get_global_name().is_empty():
			owner_name = script.get_global_name()
		up = up.get_parent()
	var parts: PackedStringArray = str(control.get_path()).split("/")
	return "%s %s" % [owner_name, "/".join(parts.slice(maxi(parts.size() - 2, 0)))]


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		Input.parse_input_event(event)


## Until the app says it is busy with nothing (Working), and Colour the
## hidden parts has drawn its pictures, a minute at most.
func _idle() -> void:
	var hidden: HiddenColoursPanel = _main.get("_hidden_colours")
	for _n: int in 3600:
		if not Working.is_busy() and (hidden == null or not bool(hidden.get("_working"))):
			return
		await process_frame


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _finish() -> void:
	if _failures == 0:
		print("a11y names probe: all checks passed")
	else:
		print("a11y names probe: %d checks failed" % _failures)
	quit(1 if _failures > 0 else 0)
