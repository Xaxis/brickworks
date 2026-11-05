## The parts bin and Properties get room, at a laptop's sizes and wider
## (docs/APP_UX.md A10, its Bar):
##
##   godot --path . --resolution 1920x1080 --script src/dev/roomfit_probe.gd
##
## Studio keeps its parts palette down the whole left side and what is
## selected on the right, both in sight at once. Here, at 1400 x 900 the bin
## showed 30 parts, and below the width where both columns fit round the
## model's 60% they took turns: the assistant, turned on, folded the bin to
## its rail at every size up to 1920 x 1080 (roomfit, 2026-11-05).
##
## The window is made each size in turn, 1280 x 720, 1400 x 900, 1600 x 900
## and 1920 x 1080, as a person's window is dragged, inside Xvfb's screen of
## the header's size. Through the root window: DisplayServer.window_set_size
## alone, on Xvfb with no window manager, says the window is the new size
## and never tells the viewport, which stayed 1920 x 1080. At each:
## - nothing selected, the assistant off, as a first visit opens: the bin's
##   parts wholly in sight inside its column, at least 24 at 1280 x 720 and
##   40 at 1400 x 900 and wider;
## - a part clicked in the model: its place, turn and colour in sight with
##   the bin, no rail clicked, down the right or under the bin
##   (Inspector.compact), 12 parts or more still in sight, and nothing of the
##   bin's column wider than the column (a bin 7 across in a column made 6
##   was cut off at its edge);
## - the assistant turned on: at 1400 px and wider it opens beside the bin,
##   the bin open with 12 parts or more and the part's boxes; below, where
##   one column shows, it may fold the bin to its rail, and the Parts rail
##   brings it back; the Properties rail swaps the properties back in, every
##   field in sight;
## - nothing but the view cube over the model, and the model keeps half the
##   width or more beside both columns, 60% where they take turns.
## Pictures go to shots/roomfit/<width>x<height>/.
extends SceneTree

const SHOTS := "res://shots/roomfit/"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1400, 900), Vector2i(1600, 900),
	Vector2i(1920, 1080)]
## The Bar's: the window that gets both columns, and the parts in sight.
const BOTH_FROM := 1400
const LEAST_TILES_LAPTOP := 24
const LEAST_TILES := 40
## Parts in sight while a part's boxes are, or the assistant is, beside the
## bin (laptop_probe's least).
const LEAST_BESIDE := 12

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _shell: Shell
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
	var table: Array[String] = []
	for size: Vector2i in SIZES:
		table.append(await _at(size))
	print("")
	print("  size        parts  parts with a part  boxes hidden  assistant: bin, parts  model")
	for line: String in table:
		print("  " + line)
	print("")
	if _failures == 0:
		print("roomfit: at each size the bin's parts, every property and the assistant in sight")
	else:
		print("roomfit: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## One window size, from a first visit's start to the assistant beside the
## bin; a line for the table at the end.
func _at(size: Vector2i) -> String:
	root.size = size
	await _frames(40)
	await create_timer(SideDock.SLIDE_SECONDS + 0.1).timeout
	await _frames(10)
	var got: Vector2i = root.size
	var units: Vector2 = root.get_visible_rect().size
	_out = "%s%dx%d/" % [SHOTS, size.x, size.y]
	print("")
	print("%d x %d (%d x %d units, columns \"%s\")" % [got.x, got.y, units.x, units.y,
		_main.get("_columns")])
	if got != size or DisplayServer.window_get_size() != size:
		_check("the window is %s, as asked (got %s)" % [size, got], false)
		return "%dx%d not made" % [size.x, size.y]
	var bin_dock: SideDock = _main.get("_bin_dock")
	var chat_dock: SideDock = _main.get("_chat_dock")
	var props_dock: SideDock = _main.get("_props_dock")
	var both: bool = size.x >= BOTH_FROM
	var least: int = LEAST_TILES if size.x >= BOTH_FROM else LEAST_TILES_LAPTOP

	# A first visit's: nothing selected, the assistant off, the bin open.
	_builder.clear_selection()
	if (_main.get("_chat_dock") as SideDock).visible:
		_main.call("set_assistant", false)
	if not bin_dock.is_open():
		await _click(bin_dock.rail().get_global_rect().get_center())
	# The right-hand column folded to its rail, as a first visit has it: the
	# size before left it open on the properties.
	if props_dock != null and props_dock.is_open():
		await _click(props_dock.rail().get_global_rect().get_center())
	await _settle()
	_say_geometry()
	var first: int = _tiles_in_sight()
	_check("nothing selected, the bin open with %d parts wholly in sight (%d across), %d or more"
		% [first, _bin._grid.columns, least], bin_dock.is_open() and first >= least)
	var share: float = _model_share()
	_nothing_over_the_model("the bin")
	await _shot("1_first")

	# A part picked out of the model: every one of its boxes in sight with
	# the bin, no rail clicked, in the properties down the right or, where
	# they are folded, under the bin (Inspector.compact).
	var picked: bool = await _click_a_part()
	_check("a part clicked in the model is selected", picked)
	await _settle()
	_say_geometry()
	var hidden: Array = _boxes_out_of_sight()
	var hidden_first: int = hidden.size()
	var with_part: int = _tiles_in_sight()
	_check("with it selected its place, turn and colour are in sight, no rail clicked (%s)"
		% (_where_boxes() if hidden.is_empty() else "out of sight: %s" % ", ".join(hidden)),
		hidden.is_empty())
	_check("...and the bin stays open, %d parts in sight, %d or more" % [with_part, LEAST_BESIDE],
		bin_dock.is_open() and with_part >= LEAST_BESIDE)
	_check("...nothing in the bin's column cut off at its edge (%s)" % _cut_off(),
		_cut_off().is_empty())
	share = minf(share, _model_share())
	_nothing_over_the_model("the bin and the properties")
	await _shot("2_part_selected")

	# The assistant turned on, as Settings or the first visit's offer does,
	# the part still selected.
	_main.call("set_assistant", true)
	await _settle()
	_say_geometry()
	var chat: Control = _main.get("_chat")
	var beside: int = _tiles_in_sight()
	var kept: bool = bin_dock.is_open()
	_check("the assistant turned on opens down the right",
		chat_dock.is_open() and chat != null and chat.is_visible_in_tree())
	if both:
		hidden = _boxes_out_of_sight()
		_check("...beside the bin, which stays open with %d parts in sight, %d or more"
			% [beside, LEAST_BESIDE], bin_dock.is_open() and beside >= LEAST_BESIDE)
		_check("...and the part's place, turn and colour in sight with them (%s)"
			% (_where_boxes() if hidden.is_empty() else "out of sight: %s" % ", ".join(hidden)),
			hidden.is_empty())
		_check("...nothing in the bin's column cut off at its edge (%s)" % _cut_off(),
			_cut_off().is_empty())
	else:
		_check("...and where one column shows, the bin folds to its rail (%d parts)" % beside,
			bin_dock.is_open() or bin_dock.rail().is_visible_in_tree())
	share = minf(share, _model_share())
	_nothing_over_the_model("the bin and the assistant")
	await _shot("3_assistant")
	# Its tab's neighbour: the properties again, in the same column.
	if props_dock != null:
		await _click(props_dock.rail().get_global_rect().get_center())
		await _settle()
		_check("the Properties rail swaps them back in the right column, the bin as it was",
			props_dock.is_open() and not chat_dock.is_open()
			and _fields_out_of_sight().is_empty() and bin_dock.is_open() == both)
	if not bin_dock.is_open():
		await _click(bin_dock.rail().get_global_rect().get_center())
		await _settle()
		_check("the Parts rail brings the bin back", bin_dock.is_open())
	_check("the model keeps %d%% of the width or more throughout (%d%%)"
		% [roundi(_least_share(both) * 100.0), roundi(share * 100.0)], share >= _least_share(both))
	_main.call("set_assistant", false)
	_builder.clear_selection()
	await _settle()
	return "%-11s %5d  %17d  %12s  %15s, %5d  %4d%%" % ["%dx%d" % [size.x, size.y], first,
		with_part, "none" if hidden_first == 0 else str(hidden_first),
		"open" if kept else "folds", beside, roundi(share * 100.0)]


func _settle() -> void:
	await _frames(20)
	await create_timer(SideDock.SLIDE_SECONDS + 0.1).timeout
	await _frames(10)


## Each part's tile wholly inside the bin's scroller: what a person sees
## without scrolling.
func _tiles_in_sight() -> int:
	var scroll: ScrollContainer = _bin._scroll
	if not scroll.is_visible_in_tree() or not (_main.get("_bin_dock") as SideDock).is_open():
		return 0
	# Inside the scroller, and inside the dock's room: a bin wider than its
	# column is cut off at the column's edge, its last tiles half drawn.
	var holder: Control = (_main.get("_bin_dock") as SideDock)._holder
	var window: Rect2 = scroll.get_global_rect().intersection(holder.get_global_rect()) \
		.intersection(Rect2(Vector2.ZERO, root.get_visible_rect().size))
	var count: int = 0
	for cell: Node in _bin._grid.get_children():
		var tile := cell as Control
		if tile != null and tile.visible and window.encloses(tile.get_global_rect()):
			count += 1
	return count


## The model's least share of the width: half beside both columns, 60%
## where they take turns (Main.BOTH_SHARE, MODEL_SHARE).
func _least_share(both: bool) -> float:
	return 0.5 if both else 0.6


## The selected part's boxes a person cannot see: in the properties down the
## right when they are open, every field and none behind a scroller; else in
## the compact one under the bin, its place, turn and colour wholly inside
## the bin's column.
func _boxes_out_of_sight() -> Array:
	var props_dock: SideDock = _main.get("_props_dock")
	if props_dock != null and props_dock.is_open():
		return _fields_out_of_sight()
	var near: Inspector = _main.get("_bin_props")
	if near == null or not near.is_visible_in_tree():
		return ["the properties, open neither down the right nor under the bin"]
	var holder: Control = (_main.get("_bin_dock") as SideDock)._holder
	var window: Rect2 = holder.get_global_rect().intersection(Rect2(Vector2.ZERO,
		root.get_visible_rect().size)).grow(0.5)
	var named: Dictionary = near.controls_by_name()
	var out: Array = []
	for name: String in ["prop_x", "prop_y", "prop_z", "prop_turn", "prop_tilt", "prop_roll",
			"prop_colour"]:
		var control := named.get(name) as Control
		if control == null or not control.is_visible_in_tree() \
				or not window.encloses(control.get_global_rect()):
			out.append(name.trim_prefix("prop_"))
	return out


func _where_boxes() -> String:
	var props_dock: SideDock = _main.get("_props_dock")
	return "down the right" if props_dock != null and props_dock.is_open() else "under the bin"


## What of the bin's column is wider than the column: its sections, which
## the column cuts off at its edge.
func _cut_off() -> String:
	var holder: Control = (_main.get("_bin_dock") as SideDock)._holder
	var out: Array = []
	for section: Control in (_main.get("_stack") as PanelStack).sections():
		if section.visible and section.get_combined_minimum_size().x > holder.size.x + 0.5:
			out.append("%s %d of %d" % [section.name if section.name != "" else section.get_class(),
				section.get_combined_minimum_size().x, holder.size.x])
	return ", ".join(out)


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


func _model_rect() -> Rect2:
	return _main.call("_model_rect")


func _model_share() -> float:
	return _model_rect().size.x / root.get_visible_rect().size.x


## The model's column clear of panels: nothing but the view cube over it
## (Main.model_cover, which fit_check.mjs asks of a browser's window).
func _nothing_over_the_model(beside: String) -> void:
	var cover: Dictionary = _main.call("model_cover")
	_check("with %s, nothing but the view cube over the model (%d of %d points covered), %d%% of the width"
		% [beside, (cover["covered"] as Array).size(), int(cover["samples"]),
		roundi(_model_share() * 100.0)], (cover["covered"] as Array).is_empty())


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
		if section.visible:
			parts.append("%s %d" % [section.name if section.name != "" else section.get_class(),
				section.size.y])
	print("    left column %d x %d: %s; bin grid %d x %d, %d across" % [stack.size.x,
		stack.size.y, ", ".join(parts), _bin._scroll.size.x, _bin._scroll.size.y,
		_bin._grid.columns])
	var side: Variant = _main.get("_side")
	if side is PanelStack and (side as Control).is_visible_in_tree():
		parts = []
		for section: Control in (side as PanelStack).sections():
			if section.visible:
				parts.append("%s %d" % [section.get_class(), section.size.y])
		print("    right column %d x %d: %s" % [(side as Control).size.x,
			(side as Control).size.y, ", ".join(parts)])
	print("    model %d units of %d, columns \"%s\"" % [_model_rect().size.x,
		root.get_visible_rect().size.x, _main.get("_columns")])


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
