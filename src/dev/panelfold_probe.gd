## Every stacked section of the studio folds and sizes one way (panelfold,
## 2026-11-13). The owner: the Colour section under the parts bin "needs
## to be collapsable and also resizable, such that A user can just minimize
## it to the bottom and B) so user can vertically resize it (to an extent)
## covering the parts picker submenu above it ... a consistent cohesive
## ui/ux pattern for our advanced panels" (PanelStack's header).
##
##   godot --path . --resolution 1280x720 --script src/dev/panelfold_probe.gd
##   PROBE_SIZE=1920x1080 tools/probe.sh panelfold_probe
##   tools/probe.sh panelfold_phone_probe     laid out for a finger, 390 x 844
##
## Driven by the pointer's and the keys' own events against the real
## scene, as a person drives it. Down the left: Colour wears the header the
## model tree, the properties and the bin wear (one PanelStack.Head); a
## click on it folds it to that header at the column's foot, the bin taking
## the room, and again brings it back as tall as it was; its bar, lit with
## the resize cursor, dragged up shows more rows of swatches and the bin
## gives the room; dragged far past, it stops with the bin its header and a
## row of parts; a double click puts it back; with the keys on it the
## arrows move it. Down the right, the same: the tree's header folds it to
## the top, the properties taking the column; its bar drags, stops with
## the properties their header and a row, a double click puts it back, the
## arrows move it. Then heights and folds outlive a restart (a run of its
## own on the same data folder, which needs tools/probe.sh's), and View,
## Panels, Reset panel layout puts every section back. On a phone, the
## drawer's: Colour's header a fingertip tall, its handle a fingertip tall,
## a tap folds it to the drawer's foot, the handle dragged by a finger
## sizes it, and the colours never fill while the tree is open.
## Pictures go to shots/panelfold/<size>/; look at them.
extends SceneTree

const PART := "3001"

var _failures: int = 0
var _main: Node
var _shell: Node
var _bin: Control
var _stack: Container
var _phone: bool = false
var _tag: String = ""
var _shots: String = ""
## On Xvfb the system's pointer goes where the events do: the app replays a
## motion where the system says the pointer is (Cursors._process), which
## would take the hover off the bar at once (tooltip_probe).
var _virtual: bool = OS.get_environment("XAUTHORITY").contains("xvfb-run")


func _initialize() -> void:
	_run.call_deferred()


func _check(what: String, ok: bool) -> bool:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1
	return ok


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_phone = args.has("--phone") or _finger()
	if _phone:
		Phone._on = 1
		Phone._wide = false
	var own: bool = _own_data_folder()
	ShellPrefs.kept_by_a_check = own
	var after: String = ""
	for arg: String in args:
		if arg.begins_with("--after-restart="):
			after = arg.trim_prefix("--after-restart=")
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("  no window: this probe needs one")
		quit(1)
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	Account.where = "user://probe_session.json"
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 1800:
		await process_frame
		if bool(_main.get("_built")):
			break
	await _frames(30)
	var playback: Variant = _main.get("_playback")
	if playback is BuildPlayback:
		(playback as BuildPlayback).stop()
	_shell = _main.get("_shell")
	_bin = _main.get("_bin")
	_stack = _main.get("_stack")
	var size: Vector2i = DisplayServer.window_get_size()
	_tag = "%dx%d%s" % [size.x, size.y, "_phone" if _phone else ""]
	_shots = ProjectSettings.globalize_path("res://shots/panelfold/%s/" % _tag)
	DirAccess.make_dir_recursive_absolute(_shots)
	if not after.is_empty():
		await _after_restart(after)
		_finish()
		return
	print("  a %s window%s, data folder of its own: %s" % [_tag, ", laid out for a finger"
		if _phone else "", own])
	await _model()
	if _phone:
		await _phone_drawer()
	else:
		await _left_column()
		await _right_column()
		await _restart(own, size)
		await _reset()
	_finish()


func _finish() -> void:
	print("")
	print("panelfold: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## The phone's script (panelfold_phone_probe) says so.
func _finger() -> bool:
	return false


# -- down the left ---------------------------------------------------------------


func _left_column() -> void:
	print("\n  down the left: the parts bin and Colour")
	var colours: Control = _bin.get("colours")
	var head: Control = _head(colours)
	var start: Dictionary = _left_said()
	print("    at first: %s" % _words(start))
	await _shot("left_at_first")
	var heads: Array = [_head(_bin), _head(_shell.get("outliner")), _head(_shell.get("inspector"))]
	var same: bool = head != null and heads.all(func(other: Variant) -> bool:
		return other is Control and (other as Control).get_script() == head.get_script())
	_check("Colour wears the header the bin, the model tree and the properties wear: a chevron, "
		+ "its name (%s)" % (_head_words(head) if head != null else "a plain label, no header"),
		same and _head_words(head).begins_with("▾ Colour"))
	# Folded by a click on its header.
	await _click(_header_point(colours))
	var folded: Dictionary = _left_said()
	await _shot("left_colour_folded")
	var at_foot: bool = absf(colours.get_global_rect().end.y - _stack.get_global_rect().end.y) < 1.0
	var head_tall: float = _head_tall(colours)
	_check("a click on its header folds Colour to that header at the column's foot (%s; its "
		% _words(folded) + "header %d tall, says \"%s\")" % [roundi(head_tall),
		_head_words(head) if head != null else "-"],
		_open(colours) == false and float(folded["colour"]) <= head_tall + 16.0 and at_foot
		and _head_words(head).begins_with("▸ Colour"))
	_check("...and the bin takes the room it gave (the bin %d -> %d, Colour %d -> %d)" % [
		roundi(float(start["bin"])), roundi(float(folded["bin"])), roundi(float(start["colour"])),
		roundi(float(folded["colour"]))],
		absf((float(folded["bin"]) - float(start["bin"]))
		- (float(start["colour"]) - float(folded["colour"]))) < 1.5
		and float(folded["bin"]) > float(start["bin"]))
	await _click(_header_point(colours))
	var back: Dictionary = _left_said()
	_check("a second click opens it as tall as it was (%s)" % _words(back),
		_open(colours) and absf(float(back["colour"]) - float(start["colour"])) < 1.0
		and absf(float(back["bin"]) - float(start["bin"])) < 1.0)

	# Its bar dragged up over the bin.
	var bar: Control = _bar_over(colours)
	_check("a bar lies over Colour's top edge, the resize cursor on it (%s)" % (
		"none" if bar == null else "%d tall at y %d" % [roundi(bar.size.y),
		roundi(bar.get_global_rect().get_center().y)]),
		bar != null and bar.mouse_default_cursor_shape == Control.CURSOR_VSIZE)
	if bar != null:
		_move(_bar_point(bar, colours), 0, Vector2.ZERO)
		await _frames(4)
		await _shot("left_bar_hovered")
	var rows_before: int = _swatch_rows()
	await _drag(_bar_point(bar, colours), -80.0)
	var dragged: Dictionary = _left_said()
	var rows_after: int = _swatch_rows()
	await _shot("left_colour_dragged_up")
	_check("dragged up 80, Colour is 80 taller and the bin 80 shorter (%s)" % _words(dragged),
		absf(float(dragged["colour"]) - float(start["colour"]) - 80.0) < 2.0
		and absf(float(start["bin"]) - float(dragged["bin"]) - 80.0) < 2.0)
	_check("...its swatches flow into the room: %d rows of them in sight, from %d"
		% [rows_after, rows_before], rows_after > rows_before)
	_check("...and the height is kept (colour_height %s)" % str(ShellPrefs.value("colour_height")),
		absf(float(ShellPrefs.value("colour_height")) - float(dragged["colour"])) < 1.0)

	# Far past: no taller than all its swatches, nothing blank under them.
	await _drag(_bar_point(bar, colours), -2000.0)
	var whole: Dictionary = _left_said()
	var palette: Control = _bin.get("_palette")
	var window: Control = _bin.get("_palette_scroll")
	await _shot("left_colour_all_in_sight")
	_check("dragged 2000 up it stops with every swatch in sight and nothing blank under them (%s; "
		% _words(whole) + "the swatches %d tall in a window of %d)" % [roundi(palette.size.y),
		roundi(window.size.y)], bar != null and float(whole["colour"]) > float(dragged["colour"])
		and absf(window.size.y - palette.size.y) < 2.0)
	# Every colour there is (All): then the bin is what stops it, at its
	# header and a row of parts.
	var all: Button = _bin.get("_all_colours")
	await _click(all.get_global_rect().get_center())
	await _frames(10)
	await _drag(_bar_point(bar, colours), -2000.0)
	var most: Dictionary = _left_said()
	await _shot("left_colour_at_its_most")
	var least_bin: float = _least(_bin)
	var grid: Control = _bin.get("_scroll")
	var row: float = float(PartsBin.PARTS_LEAST) * float(_bin.get("zoom"))
	# A tall window has room for every colour there is above the bin's
	# least: then all of them in sight is what stops it.
	var at_bin: bool = float(most["bin"]) <= least_bin + 2.0
	var all_seen: bool = absf(window.size.y - palette.size.y) < 2.0
	_check(("with every colour (All), dragged 2000 up it stops %s, the bin never under its "
		+ "header and a row of parts (%s; the bin's least %d, its parts' room %d of a row's %d; "
		+ "the swatches %d tall in a window of %d)") % ["at the bin's least" if at_bin
		else "with every colour in sight", _words(most), roundi(least_bin), roundi(grid.size.y),
		roundi(row), roundi(palette.size.y), roundi(window.size.y)],
		bar != null and float(most["colour"]) > float(whole["colour"])
		and float(most["bin"]) >= least_bin - 1.0 and (at_bin or all_seen)
		and grid.size.y >= row - 1.0 and grid.is_visible_in_tree())

	await _click(all.get_global_rect().get_center())
	await _frames(10)
	# A double click puts it back.
	await _click(_bar_point(bar, colours), true)
	var reset: Dictionary = _left_said()
	_check("a double click on the bar puts Colour back as at first (%s; colour_height %s)"
		% [_words(reset), str(ShellPrefs.value("colour_height"))],
		bar != null and absf(float(reset["colour"]) - float(start["colour"])) < 1.0
		and is_zero_approx(float(ShellPrefs.value("colour_height"))))

	# The keys: Tab reaches the bar, the arrows move it.
	await _keys_move(bar, colours, "Colour")
	await _click(_bar_point(bar, colours), true)


## The bar takes the keys, Up moves it up three steps, Down two back.
func _keys_move(bar: Control, section: Control, name: String) -> void:
	if bar == null:
		_check("with the keys on %s's bar, the arrows move it (no bar)" % name, false)
		return
	bar.grab_focus()
	await _frames(3)
	var was: float = section.size.y
	var grows: bool = bar.get_global_rect().get_center().y > section.get_global_rect().get_center().y
	for _n: int in 3:
		await _key(KEY_UP)
	var up: float = section.size.y
	for _n: int in 2:
		await _key(KEY_DOWN)
	var down: float = section.size.y
	await _shot("keys_%s" % name.to_lower().replace(" ", "_"))
	# A bar under the section it sizes makes it shorter going up.
	var sign_up: float = -1.0 if grows else 1.0
	_check(("with the keys on %s's bar (focus %s), Up three times moves it 48 up (%d -> %d) and "
		+ "Down twice 32 back (%d)") % [name, bar.has_focus(), roundi(was), roundi(up), roundi(down)],
		bar.has_focus() and absf((up - was) - sign_up * 48.0) < 1.5
		and absf((down - up) + sign_up * 32.0) < 1.5)
	bar.release_focus()
	await _frames(2)


func _left_said() -> Dictionary:
	var colours: Control = _bin.get("colours")
	return {"bin": _bin.size.y, "colour": colours.size.y, "column": _stack.size.y}


func _words(said: Dictionary) -> String:
	var out: PackedStringArray = []
	for key: String in said:
		out.append("%s %d" % [key, roundi(float(said[key]))])
	return ", ".join(out)


## The rows of swatches wholly in sight in the palette's window.
func _swatch_rows() -> int:
	var window: Control = _bin.get("_palette_scroll")
	var palette: Control = _bin.get("_palette")
	if window == null or palette == null:
		return 0
	var seen: Rect2 = window.get_global_rect()
	var tops: Dictionary = {}
	for found: Node in palette.find_children("*", "BaseButton", true, false):
		var swatch: Control = found
		if not swatch.is_visible_in_tree():
			continue
		var at: Rect2 = swatch.get_global_rect()
		if seen.encloses(at):
			tops[roundi(at.position.y)] = true
	return tops.size()


# -- down the right --------------------------------------------------------------


func _right_column() -> void:
	print("\n  down the right: the model tree over the properties")
	var side: Container = _main.get("_side")
	var dock: SideDock = _main.get("_props_dock")
	if side == null or dock == null:
		_check("the window has a right-hand column", false)
		return
	dock.set_open(true, false)
	var tree: Control = _shell.get("outliner")
	var props: Control = _shell.get("inspector")
	if not bool(tree.call("is_open")):
		tree.call("set_open", true)
	var builder: Builder = _main.get("_builder")
	var world: BrickWorld = _main.get("_world")
	var store: ModelStore = _main.get("_store")
	var ids: Array = world.bricks().filter(func(b: BrickWorld.Brick) -> bool:
		return not store.scenery.has(b.id)).map(func(b: BrickWorld.Brick) -> int: return b.id)
	builder.clear_selection()
	builder.select_brick(int(ids[0]), false)
	await _frames(40)
	var start: Dictionary = {"tree": tree.size.y, "properties": props.size.y}
	print("    a part chosen: %s" % _words(start))
	await _shot("right_at_first")
	var head: Control = _head(tree)
	_check("the model tree wears Colour's header (%s)" % _head_words(head),
		head != null and _head(_bin.get("colours")) != null
		and head.get_script() == _head(_bin.get("colours")).get_script()
		and _head_words(head).begins_with("▾ Model tree"))
	await _click(_header_point(tree))
	var folded: Dictionary = {"tree": tree.size.y, "properties": props.size.y}
	await _shot("right_tree_folded")
	_check("a click on its header folds the tree to it at the column's top, the properties taking "
		+ "the room (%s, says \"%s\")" % [_words(folded), _head_words(head)],
		not bool(tree.call("is_open")) and absf(tree.get_global_rect().position.y
		- side.get_global_rect().position.y) < 1.0 and float(folded["tree"]) <= _head_tall(tree) + 16.0
		and absf(float(folded["properties"]) - float(start["properties"])
		- (float(start["tree"]) - float(folded["tree"]))) < 1.5)
	await _click(_header_point(tree))
	_check("...and a second click opens it as tall as it was (tree %d)" % roundi(tree.size.y),
		bool(tree.call("is_open")) and absf(tree.size.y - float(start["tree"])) < 1.0)

	var bar: Control = _bar_over(tree)
	await _drag(_bar_point(bar, tree), 80.0)
	var dragged: Dictionary = {"tree": tree.size.y, "properties": props.size.y}
	_check("its bar dragged down 80: the tree 80 taller, the properties 80 shorter (%s)"
		% _words(dragged), bar != null and absf(float(dragged["tree"]) - float(start["tree"]) - 80.0) < 2.0
		and absf(float(start["properties"]) - float(dragged["properties"]) - 80.0) < 2.0)
	await _drag(_bar_point(bar, tree), 3000.0)
	var most: Dictionary = {"tree": tree.size.y, "properties": props.size.y}
	await _shot("right_tree_at_its_most")
	var row: float = float((load("res://src/ui/panel_stack.gd") as GDScript).get_script_constant_map()
		.get("ROW", 32.0))
	var props_least: float = _head_tall(props) + row
	_check("dragged 3000 down it stops: the properties keep their header and a row (%s; at least %d)"
		% [_words(most), roundi(props_least)],
		bar != null and float(most["properties"]) >= props_least - 1.0
		and float(most["properties"]) <= maxf(props_least, _least(props)) + 2.0)
	await _click(_bar_point(bar, tree), true)
	_check("a double click on the bar puts the tree back as at first (%d, tree_height %s)" % [
		roundi(tree.size.y), str(ShellPrefs.value("tree_height"))],
		bar != null and is_equal_approx(float(ShellPrefs.value("tree_height")),
		float(ShellPrefs.DEFAULTS["tree_height"])))
	await _frames(10)
	bar = _bar_over(tree)
	await _keys_move(bar, tree, "Model tree")


# -- kept, and put back -------------------------------------------------------------


## The layout left: Colour dragged 120 up, the model tree folded. A run of
## its own on the same data folder finds them so.
func _restart(own: bool, size: Vector2i) -> void:
	print("\n  started again")
	# The tree folded by its header, then the parts bin's column shown
	# (where the columns take turns, it puts the right one away) and Colour
	# dragged up 120.
	var tree: Control = _shell.get("outliner")
	if bool(tree.call("is_open")):
		await _click(_header_point(tree))
	var dock: SideDock = _main.get("_bin_dock")
	if not dock.is_open():
		dock.set_open(true, false)
		await _frames(40)
	var colours: Control = _bin.get("colours")
	var bar: Control = _bar_over(colours)
	await _drag(_bar_point(bar, colours), -120.0)
	var left: String = "colour_open=%d,colour_height=%d,outliner_open=%d" % [
		1 if _open(colours) else 0, roundi(colours.size.y), 1 if bool(tree.call("is_open")) else 0]
	print("    left: %s" % left)
	await _shot("left_before_restart")
	if not own:
		_check("a data folder of this run's own to keep the layout in (run by tools/probe.sh)", false)
		return
	var output: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--path",
		ProjectSettings.globalize_path("res://"), "--resolution", "%dx%d" % [size.x, size.y],
		"--script", "res://src/dev/panelfold_probe.gd", "--", "--after-restart=" + left],
		output, true)
	for line: String in "\n".join(output).split("\n"):
		if line.begins_with("  ok") or line.begins_with("  FAIL"):
			print("  " + line)
	_check("a run of its own, on the same data folder, found the layout as it was left (exit %d)"
		% code, code == 0)


func _after_restart(left: String) -> void:
	var want: Dictionary = {}
	for pair: String in left.split(","):
		want[pair.get_slice("=", 0)] = pair.get_slice("=", 1).to_int()
	await _frames(30)
	var colours: Control = _bin.get("colours")
	var tree: Control = _shell.get("outliner")
	await _shot("after_restart")
	print("    found: %s, colours shown %s, colour_height %s" % [_words(_left_said()),
		colours.is_visible_in_tree(), str(ShellPrefs.value("colour_height"))])
	_check("Colour open as it was left (%s), %d tall as it was dragged (%d)" % [_open(colours),
		roundi(colours.size.y), int(want["colour_height"])],
		_open(colours) == (int(want["colour_open"]) == 1)
		and absf(colours.size.y - float(want["colour_height"])) < 1.5)
	_check("the model tree folded as it was left (open %s)" % bool(tree.call("is_open")),
		bool(tree.call("is_open")) == (int(want["outliner_open"]) == 1))


## View, Panels, Reset panel layout: every section open, each as tall as
## at first.
func _reset() -> void:
	print("\n  View, Panels, Reset panel layout")
	var colours: Control = _bin.get("colours")
	var tree: Control = _shell.get("outliner")
	await _click(_header_point(colours))
	var in_menu: bool = false
	for item: Variant in Shell.SUBMENUS.get("panels", []):
		in_menu = in_menu or str(item) == "reset_panels"
	var ran: bool = bool(_shell.call("run", "reset_panels"))
	await _frames(20)
	await _shot("after_reset")
	_check("View, Panels holds Reset panel layout, and it ran (%s)" % ran, in_menu and ran)
	var palette: Object = _shell.get("palette")
	var found: Variant = palette.call("matches", "reset panel") if palette != null else []
	_check("Find a command finds it by \"reset panel\" (%s)" % str(found), "reset_panels" in found)
	_check("...Colour open again and as tall as at first (%d, colour_height %s), the model tree open"
		% [roundi(colours.size.y), str(ShellPrefs.value("colour_height"))],
		_open(colours) and is_zero_approx(float(ShellPrefs.value("colour_height")))
		and bool(tree.call("is_open")) and bool(ShellPrefs.value("colour_open")))


# -- a phone's drawer ------------------------------------------------------------


func _phone_drawer() -> void:
	print("\n  a phone's drawer: the model tree, the properties, Colour")
	var dock: SideDock = _main.get("_bin_dock")
	dock.set_open(true, false)
	await _frames(40)
	var tree: Control = _shell.get("outliner")
	if not bool(tree.call("is_open")):
		tree.call("set_open", true)
	await _frames(20)
	var colours: Control = _bin.get("colours")
	var head: Control = _head(colours)
	var finger: float = Phone.px(root, Phone.TARGET)
	var start: float = colours.size.y
	await _shot("drawer_at_first")
	var button: Control = head.get("button") if head != null else null
	_check("Colour's header in the drawer is a fingertip tall (%s, a fingertip %d)" % [
		"%d" % roundi(button.size.y) if button != null else "no header", roundi(finger)],
		button != null and button.size.y >= finger - 1.0)
	_check("the colours never fill while the tree is open (Colour %d of the drawer's %d, the tree %d)"
		% [roundi(colours.size.y), roundi(_stack.size.y), roundi(tree.size.y)],
		colours.size.y < _stack.size.y * 0.5 and bool(tree.call("is_open")))
	_check("the drawer holds them all: Colour's foot at its foot, not past it (%d of %d)"
		% [roundi(colours.get_global_rect().end.y), roundi(_stack.get_global_rect().end.y)],
		absf(colours.get_global_rect().end.y - _stack.get_global_rect().end.y) < 1.0)
	var bar: Control = _bar_over(colours)
	_check("Colour's handle is a fingertip tall (%s)" % ("none" if bar == null
		else "%d" % roundi(bar.size.y)), bar != null and bar.size.y >= finger - 1.0)
	await _tap(_header_point(colours))
	await _shot("drawer_colour_folded")
	_check("a tap on its header folds Colour to it at the drawer's foot (%d tall, its foot at %d of %d)"
		% [roundi(colours.size.y), roundi(colours.get_global_rect().end.y),
		roundi(_stack.get_global_rect().end.y)], not _open(colours)
		and colours.size.y <= _head_tall(colours) + 16.0
		and absf(colours.get_global_rect().end.y - _stack.get_global_rect().end.y) < 1.0)
	await _tap(_header_point(colours))
	_check("...and a tap opens it as tall as it was (%d, was %d)" % [roundi(colours.size.y),
		roundi(start)], _open(colours) and absf(colours.size.y - start) < 1.0)
	# Every colour there is (All), so there are more to show than fit.
	var all: Button = _bin.get("_all_colours")
	await _tap(all.get_global_rect().get_center())
	await _frames(10)
	var before: float = colours.size.y
	bar = _bar_over(colours)
	# The tree open over it, there is no room to give: a drag up leaves it
	# as it stands, and never shorter (it gave the tree's last rows 7 px).
	await _finger_drag(_bar_point(bar, colours), -100.0)
	await _frames(10)
	_check("with the tree open over it, a drag up by a finger leaves Colour as tall, never shorter (%d, was %d; the tree %d)"
		% [roundi(colours.size.y), roundi(before), roundi(tree.size.y)],
		bar != null and colours.size.y >= before - 1.0)
	# The tree folded: its room is the properties', and theirs Colour's.
	await _tap(_header_point(tree))
	await _frames(10)
	before = colours.size.y
	bar = _bar_over(colours)
	await _finger_drag(_bar_point(bar, colours), -100.0)
	await _frames(10)
	await _shot("drawer_colour_dragged_up")
	var most: float = float(_stack.call("most_of", colours)) if _stack.has_method("most_of") else 0.0
	_check(("the tree folded, with every colour (All), Colour's handle dragged up 100 by a finger: "
		+ "Colour 100 taller (%d, was %d; its most %d, the tree %d)") % [roundi(colours.size.y),
		roundi(before), roundi(most), roundi(tree.size.y)],
		bar != null and not bool(tree.call("is_open"))
		and absf(colours.size.y - before - 100.0) < 2.0)
	# The tree opened again under a Colour dragged taller: both in the
	# drawer, nothing past its foot, Colour as tall as the drawer lets it.
	await _tap(_header_point(tree))
	await _frames(10)
	await _shot("drawer_tree_reopened")
	var foot: float = colours.get_global_rect().end.y
	_check("the tree opened again: it and Colour share the drawer, Colour's foot at the drawer's (%d of %d; Colour %d, at first %d; the tree %d)"
		% [roundi(foot), roundi(_stack.get_global_rect().end.y), roundi(colours.size.y),
		roundi(start), roundi(tree.size.y)], bool(tree.call("is_open"))
		and absf(foot - _stack.get_global_rect().end.y) < 1.0 and colours.size.y >= start - 1.0)
	await _tap(all.get_global_rect().get_center())


# -- helpers ---------------------------------------------------------------------


func _head(section: Control) -> Control:
	return section.get("section_head") as Control if section != null else null


## "▾ Colour" or "▸ Colour": the chevron's way, and the name.
func _head_words(head: Control) -> String:
	if head == null:
		return ""
	var arrow: Control = head.get("arrow")
	var button: Button = head.get("button")
	var way: String = "?" if arrow == null else ("▾" if bool(arrow.get("down")) else "▸")
	return "%s %s" % [way, button.text if button != null else ""]


func _head_tall(section: Control) -> float:
	var head: Control = _head(section)
	return (head.size.y if head != null else 0.0) + _margins(section)


func _margins(section: Control) -> float:
	var style: StyleBox = section.get_theme_stylebox(&"panel")
	return style.get_margin(SIDE_TOP) + style.get_margin(SIDE_BOTTOM) if style != null else 0.0


func _open(section: Control) -> bool:
	return bool(section.call("is_open")) if section.has_method("is_open") else true


func _least(section: Control) -> float:
	var stack: Variant = section.get_parent()
	if stack != null and (stack as Object).has_method("least_open"):
		return float((stack as Object).call("least_open", section))
	return section.get_combined_minimum_size().y


## Where a person clicks to fold a section: its header's name, or on a
## section with none, its name's label.
func _header_point(section: Control) -> Vector2:
	var head: Control = _head(section)
	if head != null:
		var button: Control = head.get("button")
		return (button if button != null else head).get_global_rect().get_center()
	for found: Node in section.find_children("*", "Label", true, false):
		if (found as Label).text in ["Colour", "Model tree", "Properties"]:
			return (found as Control).get_global_rect().get_center()
	return section.get_global_rect().position + Vector2(30, 12)


## The bar shown on [param section]'s edge to the one that fills.
func _bar_over(section: Control) -> Control:
	var stack: Node = section.get_parent()
	if stack == null or not stack.has_method("sections"):
		return null
	var sections: Array = stack.call("sections")
	var edges: Array[float] = [section.get_global_rect().position.y, section.get_global_rect().end.y]
	for child: Node in stack.get_children():
		var bar: Control = child as Control
		if bar == null or child in sections or not bar.is_visible_in_tree():
			continue
		var rect: Rect2 = bar.get_global_rect()
		for edge: float in edges:
			if edge >= rect.position.y - 1.0 and edge <= rect.end.y + 1.0:
				return bar
	return null


func _bar_point(bar: Control, _section: Control) -> Vector2:
	if bar == null:
		return Vector2.INF
	return bar.get_global_rect().get_center() + Vector2(40, 0)


func _click(at: Vector2, double: bool = false) -> void:
	if at == Vector2.INF:
		return
	_move(at, 0, Vector2.ZERO)
	await _frames(3)
	_button(at, true, double)
	await _frames(2)
	_button(at, false)
	await _frames(6)


func _drag(at: Vector2, by: float) -> void:
	if at == Vector2.INF:
		return
	_move(at, 0, Vector2.ZERO)
	await _frames(3)
	_button(at, true)
	await _frames(2)
	var steps: int = 12
	var now: Vector2 = at
	for step: int in steps:
		var next: Vector2 = at + Vector2(0, by * float(step + 1) / steps)
		_move(next, MOUSE_BUTTON_MASK_LEFT, next - now)
		now = next
		await _frames(2)
	_button(now, false)
	await _frames(8)


func _tap(at: Vector2) -> void:
	if at == Vector2.INF:
		return
	_touch(at, true)
	await _frames(3)
	_touch(at, false)
	await _frames(8)


func _finger_drag(at: Vector2, by: float) -> void:
	if at == Vector2.INF:
		return
	_touch(at, true)
	await _frames(3)
	var steps: int = 12
	var now: Vector2 = at
	for step: int in steps:
		var next: Vector2 = at + Vector2(0, by * float(step + 1) / steps)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = _as_event(next)
		drag.relative = _as_event_by(next - now)
		drag.screen_relative = drag.relative
		Input.parse_input_event(drag)
		now = next
		await _frames(2)
	_touch(now, false)
	await _frames(8)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = code
		key.physical_keycode = code
		key.pressed = down
		Input.parse_input_event(key)
		await _frames(2)
	await _frames(2)


func _button(at: Vector2, down: bool, double: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.double_click = double
	event.position = _as_event(at)
	event.global_position = event.position
	if down:
		event.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(event)


func _move(at: Vector2, mask: int, relative: Vector2) -> void:
	if _virtual:
		Input.warp_mouse(_as_event(at))
	var motion := InputEventMouseMotion.new()
	motion.position = _as_event(at)
	motion.global_position = motion.position
	motion.button_mask = mask
	motion.relative = _as_event_by(relative)
	motion.screen_relative = motion.relative
	Input.parse_input_event(motion)


func _touch(at: Vector2, down: bool) -> void:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = down
	touch.position = _as_event(at)
	Input.parse_input_event(touch)


func _as_event(at: Vector2) -> Vector2:
	return root.get_final_transform() * at


func _as_event_by(by: Vector2) -> Vector2:
	return root.get_final_transform().basis_xform(by)


## A few bricks, nothing selected.
func _model() -> void:
	_main.call("clear_model")
	var world: BrickWorld = _main.get("_world")
	var builder: Builder = _main.get("_builder")
	for x: int in [-80, 0, 80]:
		var where := Transform3D(Basis.IDENTITY, Vector3(x, 24, 0))
		var brick_id: int = world.add_brick(PART, 4, where)
		builder.register(brick_id, PART, where)
	builder.clear_selection()
	var library: PartLibrary = _main.get("_library")
	for _n: int in 600:
		if library.search_ready():
			break
		await process_frame
	await _frames(30)


## Whether user:// is this run's own (probe.sh's XDG_DATA_HOME), never the
## person's.
func _own_data_folder() -> bool:
	var data: String = OS.get_environment("XDG_DATA_HOME")
	return not data.is_empty() and data.simplify_path() \
		!= OS.get_environment("HOME").path_join(".local/share").simplify_path()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _shots + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("    picture: %s" % path)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame
