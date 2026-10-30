## A laptop's parts bin and what a selected part needs, its place, turn and
## colour, in sight at once (docs/APP_UX2.md gap 5).
##
##   godot --path . --resolution 1280x720 --script src/dev/laptop_probe.gd
##
## At 1280 x 720 and 1400 x 900 the columns take turns so the model keeps
## 60% of the width (columns_probe): opening Properties folded the bin and
## the bin folded Properties, so a part put down and typed to its place, and
## the next part, cost a rail click each way (appux2's walk, 2026-10-30).
## Studio keeps its parts down the left and what is selected down the right
## at once.
##
## From a new model, five parts laid one after another from tiles in sight
## in the bin, as a person lays them: the tile clicked, the floor clicked,
## Esc, the part clicked, its X and Z typed (a click in the box, Ctrl+A, the
## number, Enter). The first is also turned by typing its Turn and painted
## by a colour clicked in the bin's colours. Each is read back from where the
## part stands and from the boxes, found as the page finds them
## (Main._page_controls). Where the boxes are not in sight with the bin open,
## the Properties rail is clicked to reach them and the Parts rail for the
## next tile, as a person must, and each is counted: none may be. The bin
## keeps 12 parts wholly in sight and the model 60% of the width throughout.
##
## PROBE_SIZE=1400x900 runs it at that size. Pictures in
## shots/laptop/<width>x<height>/.
extends SceneTree

const SHOTS := "res://shots/laptop/"
## Parts wholly in sight in the bin while a part's boxes are.
const LEAST_TILES := 12
const PARTS := 5
## Where each part is typed to: a row along X, a stud apart from where it
## was put down, and back along Z.
const STEP_X := 100.0
const FIRST_X := -200.0
const TYPED_Z := -60.0

var _failures: int = 0
var _main: Node
var _bin: PartsBin
var _builder: Builder
var _world: BrickWorld
var _camera: CadCamera
var _library: PartLibrary
var _out: String = ""
var _rail_clicks: int = 0
var _bin_folds: int = 0
var _fewest_tiles: int = 1 << 30
var _least_share: float = 1.0


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
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_bin = _main.get("_bin")
	_builder = _main.get("_builder")
	_world = _main.get("_world")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	for _n: int in 600:
		if _library.search_ready() and _world.brick_count() > 0:
			break
		await process_frame
	var units: Vector2 = root.get_visible_rect().size
	print("  window %dx%d, %d x %d units, columns \"%s\"" % [size.x, size.y, units.x, units.y,
		_main.get("_columns")])
	var bin_dock: SideDock = _main.get("_bin_dock")
	bin_dock.toggled.connect(func(open: bool) -> void:
		if not open:
			_bin_folds += 1)

	# A new model, seen from above its middle.
	_main.call("clear_model")
	_camera.frame(AABB(Vector3(-260, 0, -160), Vector3(520, 60, 320)))
	await _frames(40)
	_check("a laptop's columns take turns (\"%s\") and the bin is open, %d parts in sight"
		% [_main.get("_columns"), _tiles_in_sight()],
		_main.get("_columns") == "turns" and bin_dock.is_open() and _tiles_in_sight() >= 24)
	_keeps_share()

	var laid: int = 0
	var tried: int = 0
	var tile_at: int = 0
	while laid < PARTS and tried < PARTS * 3:
		tried += 1
		var tiles: Array = _tiles_list()
		if tile_at >= tiles.size():
			break
		var tile: Control = tiles[tile_at]
		tile_at += 1
		if await _lay_and_type(laid, tile):
			laid += 1
	_check("%d parts laid from the bin one after another, each typed to its place" % laid,
		laid == PARTS)
	_check("rail clicks to reach the boxes and the bin again: %d" % _rail_clicks,
		_rail_clicks == 0)
	_check("the bin never folded (%d folds), and showed %d parts or more in sight throughout"
		% [_bin_folds, _fewest_tiles], _bin_folds == 0 and _fewest_tiles >= LEAST_TILES)
	_check("the model kept %d%% of the width or more throughout" % floori(_least_share * 100.0),
		_least_share >= 0.6)
	await _shot("3_five_typed")
	print("")
	if _failures == 0:
		print("laptop: the bin and the selected part's place, turn and colour in sight at once")
	else:
		print("laptop: %d FAILED" % _failures)
	quit(1 if _failures > 0 else 0)


## One part from [param tile]: put down on the floor, selected by a click,
## read and typed to its place. False when it could not be put down there,
## and nothing was typed.
func _lay_and_type(n: int, tile: Control) -> bool:
	var part_id: String = str(tile.get_meta("part"))
	var info: PartLibrary.PartInfo = _library.parts.get(part_id)
	var name: String = info.name if info != null else part_id
	var had: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		had[brick.id] = true
	await _click(tile.get_global_rect().get_center())
	for _n: int in 600:
		if _library.mesh_for(part_id) != null:
			break
		await process_frame
	await _frames(10)
	var spot: Vector2 = _camera.unproject_position(Vector3(FIRST_X + STEP_X * n, 0, 80))
	await _move(spot + Vector2(3, 0))
	await _move(spot)
	await _click(spot)
	var put: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not had.has(brick.id):
			put = brick
	await _key(KEY_ESCAPE)
	if put == null:
		print("    %s (%s) from its tile: not put down there, the next tile tried" % [name, part_id])
		return false
	# Selected by a click on it, as a person picks it out.
	var mesh: Lbm.PartMesh = _library.mesh_for(part_id)
	var box: AABB = (put.transform * mesh.bounds).abs()
	for at: Vector3 in [box.get_center(), box.get_center() + Vector3(0, box.size.y * 0.4, 0)]:
		await _click(_camera.unproject_position(at))
		if _builder.selection.size() == 1 and _builder.selection.has(put.id):
			break
	var selected: bool = _builder.selection.size() == 1 and _builder.selection.has(put.id)
	if n == 0:
		await _shot("1_selected")
	var fields: Dictionary = await _boxes()
	var tiles: int = _tiles_in_sight()
	_fewest_tiles = mini(_fewest_tiles, tiles)
	var stands: Vector3 = put.transform.origin
	_check("%d. %s laid from its tile and selected by a click: X, Y, Z and Turn in sight and "
		% [n + 1, name] + "reading where it stands (%s), the bin open with %d parts in sight"
		% [_numbers(stands), tiles], selected and _reads(fields, stands, put)
		and (_main.get("_bin_dock") as SideDock).is_open() and tiles >= LEAST_TILES)
	_keeps_share()
	if fields.is_empty():
		await _bin_back()
		return true
	var want := Vector3(FIRST_X + STEP_X * n + 20.0, stands.y, TYPED_Z)
	await _type_in(fields["prop_x"], String.num(want.x, 2))
	await _type_in(fields["prop_z"], String.num(want.z, 2))
	fields = await _boxes()
	stands = put.transform.origin
	_check("   ...typed to X %s, Z %s: it stands at %s, and the boxes say so"
		% [String.num(want.x, 2), String.num(want.z, 2), _numbers(stands)],
		stands.distance_to(want) < 0.05 and _reads(fields, stands, put))
	if n == 0:
		await _turn_and_paint(put)
	_fewest_tiles = mini(_fewest_tiles, _tiles_in_sight())
	_keeps_share()
	await _bin_back()
	return true


## The first part turned by its Turn box, and painted by a colour clicked in
## the bin's colours: each read back from the part and from the boxes.
func _turn_and_paint(put: BrickWorld.Brick) -> void:
	var fields: Dictionary = await _boxes()
	if not fields.has("prop_turn"):
		_check("   ...its Turn in sight", false)
		return
	await _type_in(fields["prop_turn"], "90")
	fields = await _boxes()
	var yaw: float = Inspector._yaw_of(put.transform.basis)
	_check("   ...typed a Turn of 90: it faces %s°, and the box says %s" % [String.num(yaw, 1),
		String.num((fields.get("prop_turn", SpinBox.new()) as SpinBox).value, 1)],
		absf(yaw - 90.0) < 0.05 and fields.has("prop_turn")
		and absf((fields["prop_turn"] as SpinBox).value - 90.0) < 0.05)
	# A colour in sight in the bin's palette, not the part's.
	var was: int = put.color_code
	var palette: Rect2 = (_bin.get("_palette_scroll") as Control).get_global_rect()
	var swatches: Dictionary = _bin.get("_swatches")
	var chosen: int = -1
	for code: int in swatches:
		var swatch: Control = swatches[code]
		if code != was and code != 16 and swatch.is_visible_in_tree() \
				and palette.encloses(swatch.get_global_rect()):
			chosen = code
			break
	if chosen < 0:
		_check("   ...a colour in sight in the bin's colours", false)
		return
	await _click((swatches[chosen] as Control).get_global_rect().get_center())
	await _frames(10)
	fields = await _boxes()
	var colour: String = _library.color(chosen).name.replace("_", " ")
	var says: String = (fields["prop_colour"] as Label).text if fields.has("prop_colour") else ""
	_check("   ...%s clicked in the bin's colours: it is painted %s (%d), and its colour says \"%s\""
		% [colour, colour, put.color_code, says.get_slice("\n", 0)],
		put.color_code == chosen and says.begins_with(colour))
	await _shot("2_turned_and_painted")


## The boxes of the selection's properties, as the page finds them: the ones
## in sight and wholly in the window. Where they are not with the bin open,
## the Properties rail is clicked for them, as a person must, and counted.
func _boxes() -> Dictionary:
	await _frames(10)
	var found: Dictionary = _in_sight()
	if found.has("prop_x"):
		return found
	var rail: Control = (_main.get("_props_dock") as SideDock).rail()
	_rail_clicks += 1
	print("    the boxes are not in sight with the bin open: the Properties rail clicked")
	await _click(rail.get_global_rect().get_center())
	await create_timer(SideDock.SLIDE_SECONDS + 0.2).timeout
	await _frames(20)
	found = _in_sight()
	if _rail_clicks == 1:
		await _shot("1b_properties_rail")
	return found


func _in_sight() -> Dictionary:
	var window := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	var named: Dictionary = _main.call("_page_controls")
	var out: Dictionary = {}
	for name: String in ["prop_x", "prop_y", "prop_z", "prop_turn", "prop_colour"]:
		var control := named.get(name) as Control
		if control != null and control.is_visible_in_tree() \
				and window.encloses(control.get_global_rect()):
			out[name] = control
	return out


## The bin out again for the next tile: its rail clicked where Properties
## folded it, and counted.
func _bin_back() -> void:
	var dock: SideDock = _main.get("_bin_dock")
	if dock.is_open():
		return
	_rail_clicks += 1
	await _click(dock.rail().get_global_rect().get_center())
	await create_timer(SideDock.SLIDE_SECONDS + 0.2).timeout
	await _frames(20)


## Whether the boxes read where the part stands, to the hundredth, and which
## way it faces, to the tenth.
func _reads(fields: Dictionary, stands: Vector3, brick: BrickWorld.Brick) -> bool:
	for n: int in 3:
		var name: String = ["prop_x", "prop_y", "prop_z"][n]
		if not fields.has(name) or absf((fields[name] as SpinBox).value - stands[n]) > 0.011:
			return false
	return fields.has("prop_turn") and absf((fields["prop_turn"] as SpinBox).value
		- snappedf(Inspector._yaw_of(brick.transform.basis), 0.1)) < 0.051


## Click into a box, select what is in it, type, Enter.
func _type_in(spin: SpinBox, text: String) -> void:
	var field: LineEdit = spin.get_line_edit()
	await _click(field.get_global_rect().get_center())
	if not field.has_focus():
		print("    %s did not take the keys (at %s)" % [spin.accessibility_name,
			field.get_global_rect()])
		return
	await _key(KEY_A, true)
	await _type(text)
	await _key(KEY_ENTER)
	await _frames(6)


## The tiles in the bin wholly in sight, top to bottom.
func _tiles_list() -> Array:
	var out: Array = []
	var scroll: ScrollContainer = _bin._scroll
	if not scroll.is_visible_in_tree():
		return out
	var window: Rect2 = scroll.get_global_rect()
	for cell: Node in _bin._grid.get_children():
		var tile := cell as Control
		if tile != null and tile.visible and tile.has_meta("part") \
				and window.encloses(tile.get_global_rect()):
			out.append(tile)
	return out


func _tiles_in_sight() -> int:
	return _tiles_list().size()


func _keeps_share() -> void:
	var model: Rect2 = _main.call("_model_rect")
	_least_share = minf(_least_share, model.size.x / root.get_visible_rect().size.x)


static func _numbers(at: Vector3) -> String:
	return "%s, %s, %s" % [String.num(at.x, 2), String.num(at.y, 2), String.num(at.z, 2)]


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	var window := Vector2(DisplayServer.window_get_size())
	return at * (window / rect)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)
	await _frames(3)


func _click(at: Vector2) -> void:
	await _move(at)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = _as_event(at)
		event.global_position = event.position
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(4)


func _type(text: String) -> void:
	for n: int in text.length():
		var c: String = text[n]
		for down: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = OS.find_keycode_from_string(c.to_upper())
			event.unicode = c.unicode_at(0)
			event.pressed = down
			Input.parse_input_event(event)
			await process_frame
	await _frames(3)


func _key(code: Key, command: bool = false) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		event.ctrl_pressed = command
		Input.parse_input_event(event)
		await process_frame
	await _frames(3)


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
