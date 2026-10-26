## Edit, Select by, Part number or name… on a set built of sub-models, in
## the real app, in a window.
##
##   godot --path . --resolution 1600x1000 --script src/dev/find_submodels_probe.gd
##
## walk256 (D10): the Cat D11 Bulldozer (42131-1 from the OMR Library, 188
## sub-models) opened from the Library; Part number or name… listed "49
## pieces in 2 lots answer 11478", and a row clicked, a row double-clicked
## and Enter each left nothing selected. Studio's Select by takes the parts
## inside sub-models as it takes any. Here the set is opened as the Library
## opens it (?library=omr-42131-1), the find typed into key by key, and:
##
##   Enter          every one of them selected, those inside sub-models too,
##                  the list put away, the bar saying how many, the view
##                  framed on them
##   a row clicked  that part in that colour, every one, and framed
##   a row clicked twice
##                  the same, and the list put away once
##
## Pictures: shots/findsub_list.png, findsub_enter.png, findsub_row.png.
extends SceneTree

const SET := "omr-42131-1"
const PART := "11478"

var _failures: int = 0
var _main: Node
var _shell: Shell
var _bar: ModelBar
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _list: InventoryPanel
var _pointer := Vector2.ZERO


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	await process_frame
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_main = load("res://src/main.tscn").instantiate()
	root.add_child(_main)
	for _n: int in 120:
		await process_frame
	var playback: BuildPlayback = _main.get("_playback")
	if playback != null:
		playback.stop()
	_shell = _main.get("_shell")
	_bar = _main.get("_bar")
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_list = _main.get("_inventory")
	await _cat()
	_world.clear()
	await _frames(10)
	_main.queue_free()
	await _frames(10)
	print("\n%s" % ("all passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures else 0)


func _cat() -> void:
	print("\n  the Cat D11 Bulldozer, from the Library")
	_main.set("_from_library", SET)
	await _main.call("_maybe_open_library")
	var store: ModelStore = _main.get("_store")
	for _n: int in 6000:
		if not store.laying and store.awaited.is_empty():
			break
		await process_frame
	await _frames(60)
	var scenery: Dictionary = store.scenery
	var all_of_them: Array = []
	var in_submodels: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id == PART and not scenery.has(brick.id):
			all_of_them.append(brick.id)
			if not brick.group.is_empty():
				in_submodels += 1
	_check("the set is open (%d parts, %d of them %s, %d of those in sub-models)"
		% [_world.brick_count(), all_of_them.size(), PART, in_submodels],
		_world.brick_count() > 3000 and all_of_them.size() > 10 and in_submodels > 0)

	print("\n  words, as walk256 typed them")
	await _find("liftarm 1 x 5")
	var liftarms: int = 0
	for brick: BrickWorld.Brick in _world.bricks():
		if brick.part_id in ["32316", PART] and not scenery.has(brick.id):
			liftarms += 1
	await _key(KEY_ENTER)
	await _frames(30)
	_check("Enter selects the %d liftarms 1 x 5: %d" % [liftarms, _builder.selection.size()],
		liftarms > 0 and _builder.selection.size() == liftarms)
	print("     the bar: %s" % _bar._status.text)
	_builder.clear_selection()
	await _frames(10)

	print("\n  Enter")
	await _find()
	await _shot("findsub_list")
	var aimed_from: Vector3 = _camera._target_focus
	await _key(KEY_ENTER)
	await _frames(30)
	var picked: Array = _builder.selection.keys()
	_check("Enter selects every %s, in sub-models too: %d of %d" % [PART, picked.size(), all_of_them.size()],
		_same(picked, all_of_them))
	_check("...and puts the list away", not _list.visible)
	print("     the bar: %s" % _bar._status.text)
	_check("...and says how many", _bar._status.text.begins_with("selected %d" % all_of_them.size()))
	await _frames(90)
	_check("...and frames them", _framed(aimed_from))
	await _shot("findsub_enter")
	_builder.clear_selection()
	await _frames(10)

	print("\n  a row clicked")
	await _find()
	var row: Button = _row(0)
	_check("a row for the black ones", row != null)
	if row == null:
		return
	aimed_from = _camera._target_focus
	await _click(row.get_global_rect().get_center())
	await _frames(20)
	picked = _builder.selection.keys()
	var black: Array = all_of_them.filter(func(id: int) -> bool:
		return _world.get_brick(id).color_code == 0)
	_check("clicking it selects every black one: %d of %d" % [picked.size(), black.size()],
		not black.is_empty() and _same(picked, black))
	_check("...and puts the list away", not _list.visible)
	await _frames(90)
	_check("...and frames them", _framed(aimed_from))
	await _shot("findsub_row")
	_builder.clear_selection()
	await _frames(10)

	print("\n  a row clicked twice")
	await _find()
	row = _row(-1)
	if row == null:
		_check("a row for the yellow ones", false)
		return
	var at: Vector2 = row.get_global_rect().get_center()
	await _move(at)
	_button(at, true)
	await _frames(1)
	_button(at, false)
	await _frames(2)
	_button(at, true, true)
	await _frames(1)
	_button(at, false)
	await _frames(20)
	picked = _builder.selection.keys()
	var yellow: Array = all_of_them.filter(func(id: int) -> bool:
		return _world.get_brick(id).color_code != 0)
	_check("clicking it twice selects the yellow ones: %d of %d" % [picked.size(), yellow.size()],
		not yellow.is_empty() and _same(picked, yellow))
	_check("...and the list is away", not _list.visible)
	_builder.clear_selection()


## The list opened from Edit, Select by, and the part's number typed into
## its find, key by key.
func _find(words: String = PART) -> void:
	_shell.run("select_find")
	await _frames(20)
	_check("Part number or name… opens the list, its find to type into",
		_list.visible and _list._find.has_focus())
	await _type(words)
	print("     the list: %s" % _list._heading.text)
	_check("it lists what answers “%s”" % words, _list._find.text == words
		and _list._heading.text.contains("answer “%s”" % words))


## The row shown for [param colour] (-1: any but black).
func _row(colour: int) -> Button:
	for pair: Array in _list._made:
		var lot: Inventory.Lot = pair[0]
		if (pair[1] as Node).get_parent() != _list._rows or lot.part_id != PART:
			continue
		if (colour < 0 and lot.color_code != 0) or lot.color_code == colour:
			(_list._scroll as ScrollContainer).ensure_control_visible(pair[1])
			return pair[1]
	return null


static func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	var wanted: Dictionary = {}
	for id: Variant in b:
		wanted[int(id)] = true
	return a.all(func(id: Variant) -> bool: return wanted.has(int(id)))


## The view on the selection: its focus on the selection's middle, moved
## there from where it was.
func _framed(aimed_from: Vector3) -> bool:
	var box: AABB = _main.call("_selection_bounds")
	return _builder.selection.size() > 0 and box.size.length() > 0.0 \
		and _camera._target_focus.distance_to(box.get_center()) < 1.0 \
		and aimed_from.distance_to(box.get_center()) > 1.0


func _click(at: Vector2) -> void:
	await _move(at)
	_button(at, true)
	await _frames(2)
	_button(at, false)
	await _frames(4)


func _move(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = _as_event(at)
	event.global_position = event.position
	event.relative = event.position - _pointer
	_pointer = event.position
	Input.parse_input_event(event)
	await _frames(2)


func _button(at: Vector2, down: bool, twice: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.double_click = twice
	event.position = _as_event(at)
	event.global_position = event.position
	Input.parse_input_event(event)


func _as_event(at: Vector2) -> Vector2:
	var rect: Vector2 = root.get_visible_rect().size
	if rect.x <= 0.0 or rect.y <= 0.0:
		return at
	return at * (Vector2(DisplayServer.window_get_size()) / rect)


func _type(text: String) -> void:
	for character: String in text:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.keycode = OS.find_keycode_from_string(character.to_upper()) \
			if character != " " else KEY_SPACE
		event.physical_keycode = event.keycode
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	await _frames(6)


func _key(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	await _frames(6)


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/%s.png" % name)
