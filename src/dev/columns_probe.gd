## The window's columns at a laptop's size: the parts bin down the left with
## room for its parts, the model tree and the properties down the right, and
## the assistant beside them (docs/APP_UX.md A10).
##
##   godot --path . --resolution 1280x720 --script src/dev/columns_probe.gd
##
## The bin and its colours had the left column to share with the model tree
## and the properties: at 1280 x 720 the bin showed 8 parts, and with a part
## selected the properties showed X and Y, the rest behind a scroller
## (appux371's walk, 2026-10-30). Studio keeps its parts down the left and
## what is selected on the right; Figma, Blender and Onshape all put the
## inspector on the right.
##
## And the model keeps 60% of the window's width throughout, which
## tools/web/fit_check.mjs asks of a laptop's window: at 1100 x 700 the
## panels once left no room to build, and with both columns open at 1400 x
## 900 the model had 41%. So a laptop's columns take turns, one beside the
## model at a time, and the bin is as wide as the model's share leaves it.
##
## On a first visit, nothing selected: the bin open with at least 24 parts
## wholly in sight, and the model tree and the properties down the right,
## open where both columns fit and folded to their rail where they take
## turns. A part clicked in the model, the Properties rail: every one of its
## properties in sight, nothing behind a scroller. The assistant turned on:
## it opens down the right, beside the bin where both fit. Its rail's
## Properties brings them back, and the Parts rail the bin.
## columns_saved_probe starts it from a layout kept before the right column
## was made (ShellPrefs): the bin folded, the assistant open, the model tree
## dragged to 300 and folded; the bin stays folded, the assistant shows, the
## tree comes out of its fold once and keeps its height.
##
## PROBE_SIZE=1400x900 and 1920x1080 run it at those sizes. Pictures go to
## shots/columns/<width>x<height>/.
extends SceneTree

const SHOTS := "res://shots/columns/"

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _shell: Shell
## Started from a layout kept before the right column (columns_saved_probe).
var _saved: bool = false
var _out: String = ""


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
	var size: Vector2i = DisplayServer.window_get_size()
	_out = "%s%dx%d/" % [SHOTS, size.x, size.y]
	if _saved:
		# A layout kept before the right column: what a person who had used
		# the app would load. A probe keeps nothing on disk (ShellPrefs), so
		# it is put in memory before the window reads it.
		ShellPrefs.put("assistant", "on")
		ShellPrefs.put("assistant_offered", true)
		ShellPrefs.put("parts_open", false)
		ShellPrefs.put("assistant_open", true)
		ShellPrefs.put("narrow_side", "assistant")
		ShellPrefs.put("tree_height", 300.0)
		ShellPrefs.put("outliner_open", false)
		ShellPrefs.put("inspector_open", true)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_bin = _main.get("_bin")
	_builder = _main.get("_builder")
	_shell = _main.get("_shell")
	var library: PartLibrary = _main.get("_library")
	for _n: int in 600:
		if library.search_ready() and (_main.get("_world") as BrickWorld).brick_count() > 0:
			break
		await process_frame
	await _frames(30)
	var units: Vector2 = root.get_visible_rect().size
	print("  window %dx%d, %d x %d units, columns \"%s\"" % [size.x, size.y, units.x, units.y,
		_main.get("_columns")])
	_say_geometry()
	if _saved:
		await _saved_layout()
	else:
		await _first_visit()
	print("")
	if _failures == 0:
		print("columns: %s" % ("a layout kept before the right column loads as it was left"
			if _saved else "the bin's parts and every property in sight, the model keeping its share"))
	else:
		print("columns: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


func _first_visit() -> void:
	var bin_dock: SideDock = _main.get("_bin_dock")
	var props_dock: SideDock = _main.get("_props_dock")
	var chat_dock: SideDock = _main.get("_chat_dock")
	var wide: bool = _main.get("_columns") == "wide"
	var tiles: int = _tiles_in_sight()
	_check("the parts bin is open, %d parts wholly in sight, %d across"
		% [tiles, _bin._grid.columns], bin_dock.is_open() and tiles >= 24)
	if wide:
		_check("the model tree and the properties are open down the right",
			props_dock != null and props_dock.is_open() and _shell.inspector.is_visible_in_tree()
			and _shell.outliner.is_visible_in_tree()
			and _shell.inspector.get_global_rect().position.x > _model_rect().end.x - 1.0)
	else:
		_check("the model tree and the properties are folded to their rail down the right",
			props_dock != null and not props_dock.is_open()
			and props_dock.rail().is_visible_in_tree()
			and props_dock.rail().get_global_rect().position.x >= _model_rect().end.x - 1.0)
	_model_keeps_its_share("the model")
	await _shot("1_first_visit")

	# A part clicked in the model, as a person picks one out; where one
	# column shows at a time, the Properties rail brings them out.
	var picked: bool = await _click_a_part()
	_check("a part clicked in the model is selected", picked)
	await _frames(20)
	if props_dock != null and not props_dock.is_open():
		await _click(props_dock.rail().get_global_rect().get_center())
		await _frames(30)
		_check("the Properties rail opens them and folds the bin",
			props_dock.is_open() and not bin_dock.is_open())
	var hidden: Array = _fields_out_of_sight()
	_check("with it selected every property is in sight, none behind a scroller%s"
		% ("" if hidden.is_empty() else " (out of sight: %s)" % ", ".join(hidden)),
		_shell.inspector.is_visible_in_tree() and hidden.is_empty())
	_model_keeps_its_share("...and the model")
	_say_geometry()
	await _shot("2_part_selected")

	# The assistant turned on, as Settings or the first visit's offer does.
	_main.call("set_assistant", true)
	await _frames(40)
	tiles = _tiles_in_sight()
	_check("the assistant turned on opens down the right (%s)" % _main.get("_columns"),
		chat_dock.is_open() and (_main.get("_chat") as Control).is_visible_in_tree())
	if wide:
		_check("and the parts bin stays open beside it, %d parts in sight" % tiles,
			bin_dock.is_open() and tiles >= 24)
	else:
		_check("and the parts bin is folded to its rail", not bin_dock.is_open()
			and bin_dock.rail().is_visible_in_tree())
	_model_keeps_its_share("the model")
	await _shot("3_assistant")

	# Its rail's Properties, as a person clicks it.
	var rail: Control = props_dock.rail() if props_dock != null else null
	if rail != null:
		await _click(rail.get_global_rect().get_center())
		await _frames(30)
	_check("the Properties rail brings the properties back, the assistant folded",
		props_dock != null and props_dock.is_open() and not chat_dock.is_open()
		and _shell.inspector.is_visible_in_tree() and _fields_out_of_sight().is_empty())
	await _shot("4_properties_again")
	# The Parts rail: the bin back, and where one column shows at a time
	# the right-hand one folded.
	await _click(bin_dock.rail().get_global_rect().get_center())
	await _frames(30)
	tiles = _tiles_in_sight()
	_check("the Parts rail brings the bin back, %d parts in sight%s" % [tiles,
		"" if wide else ", the right-hand column folded"], bin_dock.is_open() and tiles >= 24
		and (wide or not (props_dock.is_open() or chat_dock.is_open())))
	_model_keeps_its_share("...and the model")

	# View, Assistant: a command, not the rail, shows it again.
	_shell.run("panel_assistant")
	await _frames(30)
	_check("View, Assistant shows the assistant in the right column",
		chat_dock.is_open() and props_dock != null and not props_dock.is_open())
	# View, Properties: back to them, with them in sight.
	_shell.run("panel_properties")
	await _frames(30)
	_check("View, Properties shows them again, ticked",
		props_dock != null and props_dock.is_open() and _shell.inspector.is_visible_in_tree()
		and _shell.ticked("panel_properties") == 1)
	_shell.run("panel_properties")
	await _frames(30)
	_check("and again folds them, unticked",
		not _shell.inspector.is_open() and not _shell.ticked("panel_properties") == 1)
	_shell.run("panel_properties")
	await _frames(30)

	# Build your first model, from Help, Take the tour: Start, and its first
	# step brings the bin out from behind the assistant's column and frames
	# its parts, its line along the top of the model, not over it, and the
	# model keeping its share.
	_shell.run("panel_assistant")
	await _frames(30)
	_shell.run("tour")
	await _frames(5)
	var first: FirstBuild = _shell.first_build
	await _click((first.controls_by_name()["first_build_go"] as Control).get_global_rect().get_center())
	await create_timer(SideDock.SLIDE_SECONDS + 0.2).timeout
	await _frames(5)
	var parts: Control = _bin.controls_by_name()["parts list"]
	var lit: Rect2 = (first.get("_frame") as Control).get("lit")
	_check("Build your first model's first step opens the bin and frames its parts (%s: %s round %s)"
		% [first.step_name(), lit, parts.get_global_rect()],
		first.step_name() == "put" and bin_dock.is_open() and lit.encloses(parts.get_global_rect()))
	var below: Rect2 = (_main.get("_over_model") as Control).get_global_rect()
	_check("...its line along the top of the model, not over it (%s above %s)"
		% [first.get_global_rect(), below],
		first.is_visible_in_tree() and first.get_global_rect().end.y <= below.position.y + 1.0)
	_model_keeps_its_share("...and the model")
	await _shot("4b_first_build")
	first.stop()
	await _frames(5)


func _saved_layout() -> void:
	var bin_dock: SideDock = _main.get("_bin_dock")
	var chat_dock: SideDock = _main.get("_chat_dock")
	var props_dock: SideDock = _main.get("_props_dock")
	_check("the parts bin stays folded, as it was left", not bin_dock.is_open())
	_check("the assistant shows, as it was left", chat_dock.is_open())
	await _shot("5_saved_layout")
	_shell.run("panel_properties")
	await _frames(30)
	_check("View, Properties opens the right column on them",
		props_dock != null and props_dock.is_open() and _shell.inspector.is_visible_in_tree())
	_check("the model tree comes out of its fold in its new column",
		_shell.outliner.is_open() and _shell.outliner.is_visible_in_tree())
	# With nothing selected the tree has the column; with a part, its own
	# height, the properties the rest.
	var picked: bool = await _click_a_part()
	await _frames(20)
	var tall: float = _shell.outliner.size.y
	_check("a part selected, the tree keeps the height it was dragged to (%d)" % tall,
		picked and absf(tall - 300.0) <= 1.0)
	var hidden: Array = _fields_out_of_sight()
	_check("and every property is in sight under it%s" % ("" if hidden.is_empty()
		else " (out of sight: %s)" % ", ".join(hidden)), hidden.is_empty())
	_check("the height is kept still", is_equal_approx(float(ShellPrefs.value("tree_height")),
		300.0))
	await _shot("6_saved_properties")


## Each part's tile wholly inside the bin's scroller: what a person sees
## without scrolling.
func _tiles_in_sight() -> int:
	var scroll: ScrollContainer = _bin._scroll
	if not scroll.is_visible_in_tree():
		return 0
	var window: Rect2 = scroll.get_global_rect()
	var count: int = 0
	for cell: Node in _bin._grid.get_children():
		var tile := cell as Control
		if tile != null and tile.visible and window.encloses(tile.get_global_rect()):
			count += 1
	return count


## The properties' fields a person cannot see without scrolling: each one
## shown and not wholly inside the panel's scroller, or the scroller holding
## more than it shows.
func _fields_out_of_sight() -> Array:
	var out: Array = []
	var inspector: Inspector = _shell.inspector
	var scroll: ScrollContainer = inspector._scroll
	if not scroll.is_visible_in_tree():
		return ["the whole panel"]
	var window: Rect2 = scroll.get_global_rect().intersection(Rect2(Vector2.ZERO,
		root.get_visible_rect().size))
	for node: Node in inspector._body.find_children("*", "Control", true, false):
		var field := node as Control
		if not (field is SpinBox or field is Button) or not field.is_visible_in_tree():
			continue
		if not window.grow(0.5).encloses(field.get_global_rect()):
			out.append(_name_of(field))
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	if bar.max_value - bar.page > 1.0:
		out.append("%d units behind the scroller" % (bar.max_value - bar.page))
	return out


func _name_of(field: Control) -> String:
	if field is Button:
		return "\"%s\"" % (field as Button).text
	var at: int = field.get_index()
	var label := field.get_parent().get_child(at - 1) as Label if at > 0 else null
	return label.text if label != null else field.name


## The model's column, where a click lands on the model.
func _model_rect() -> Rect2:
	return _main.call("_model_rect")


## The model's share of the window's width, at least what fit_check.mjs asks
## of a laptop's window (Main.MODEL_SHARE).
func _model_keeps_its_share(what: String) -> void:
	var share: float = _model_rect().size.x / root.get_visible_rect().size.x
	_check("%s keeps %d%% of the width, %d units (%s)" % [what, floori(share * 100.0),
		_model_rect().size.x, _main.get("_columns")], share >= 0.6)


## A part of the model clicked: the one nearest the middle of its column
## that the click finds.
func _click_a_part() -> bool:
	var camera: CadCamera = _main.get("_camera")
	var world: BrickWorld = _main.get("_world")
	var scenery: Dictionary = (_main.get("_store") as ModelStore).scenery
	var room: Rect2 = _model_rect()
	var best: Vector2 = Vector2.INF
	for brick: BrickWorld.Brick in world.bricks():
		if scenery.has(brick.id):
			continue
		var at: Vector3 = brick.transform.origin
		if camera.is_position_behind(at):
			continue
		var spot: Vector2 = camera.unproject_position(at)
		if room.grow(-40.0).has_point(spot) and spot.distance_to(room.get_center()) \
				< best.distance_to(room.get_center()):
			best = spot
	if best == Vector2.INF:
		return false
	await _click(best)
	return not _builder.selection.is_empty()


func _say_geometry() -> void:
	var stack: Control = _main.get("_stack")
	var parts: Array = []
	for section: Control in (stack as PanelStack).sections():
		parts.append("%s %d" % [section.name if section.name != "" else section.get_class(),
			section.size.y])
	print("    left column %d x %d: %s" % [stack.size.x, stack.size.y, ", ".join(parts)])
	print("    bin grid %d x %d, %d across" % [_bin._scroll.size.x, _bin._scroll.size.y,
		_bin._grid.columns])
	var side: Variant = _main.get("_side")
	if side is PanelStack:
		parts = []
		for section: Control in (side as PanelStack).sections():
			parts.append("%s %d" % [section.get_class(), section.size.y])
		print("    right column %d x %d: %s" % [(side as Control).size.x,
			(side as Control).size.y, ", ".join(parts)])
	var scroll: ScrollContainer = _shell.inspector._scroll
	print("    properties scroller %d tall, holding %d" % [scroll.size.y,
		scroll.get_v_scroll_bar().max_value])


func _click(at: Vector2) -> void:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	var spot: Vector2 = at * (window / rect)
	var motion := InputEventMouseMotion.new()
	motion.position = spot
	motion.global_position = spot
	Input.parse_input_event(motion)
	await _frames(3)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = spot
		event.global_position = spot
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path(_out + name + ".png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: %s%s.png" % [_out.trim_prefix("res://"), name])
