## The parts a library update added are in the app: each found in the parts
## bin by its number, taken by its tile, and put on the model by a click.
##
##   MESA_VK_WSI_DEBUG=sw xvfb-run -a -s "-screen 0 1400x900x24" godot --path . \
##     --resolution 1400x900 --script src/dev/new_parts_probe.gd -- 3559 8491 3062bp07
##
## tools/update_parts.py prints the numbers of the parts it added; give
## three of them. For each: the catalogue the app opened has it, the bin's
## search lists its tile, a click on the tile reads its new mesh (the size
## the catalogue gives it), and the part goes down where its ghost stood, a
## brick of that number in the model. Given no numbers it skips, which
## tools/probe.sh counts as a failure. A picture in shots/new_parts/.
extends SceneTree

var _failures: int = 0
var _main: Node
var _world: BrickWorld
var _builder: Builder
var _camera: CadCamera
var _library: PartLibrary


func _initialize() -> void:
	_run()


func _check(what: String, ok: bool) -> void:
	print("  %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures += 1


func _run() -> void:
	var numbers: PackedStringArray = OS.get_cmdline_user_args()
	if numbers.is_empty():
		print("new_parts probe: SKIPPED, give the numbers tools/update_parts.py printed")
		quit(0)
		return
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
	_world = _main.get("_world")
	_builder = _main.get("_builder")
	_camera = _main.get("_camera")
	_library = _main.get("_library")
	print("  the app opened a catalogue of %d parts" % _library.parts.size())

	_main.call("clear_model")
	_camera.frame(AABB(Vector3(-240, 0, -160), Vector3(480, 80, 320)))
	await _frames(30)
	var bin: PartsBin = _main.get("_bin")
	for n: int in numbers.size():
		await _one(bin, numbers[n], Vector3(-160 + 160 * n, 0, 0))
	await _shot("placed")
	print("")
	print("new_parts: %s" % ("every check passed" if _failures == 0 else "%d FAILED" % _failures))
	quit(1 if _failures > 0 else 0)


## Search for [param number], take it by its tile, and click it down at
## [param spot] on the floor.
func _one(bin: PartsBin, number: String, spot: Vector3) -> void:
	var info: PartLibrary.PartInfo = _library.parts.get(number)
	_check("%s is in the catalogue (%s)" % [number, info.name if info != null else "absent"],
		info != null)
	if info == null:
		return
	await _click(bin._search.get_global_rect().get_center())
	await _key(KEY_A, true)
	await _type(number)
	await create_timer(0.4).timeout
	await _frames(4)
	var tile: Control = null
	for cell: Node in bin._grid.get_children():
		if cell is Control and str(cell.get_meta("part", "")) == number:
			tile = cell
	_check("the bin's search for %s lists its tile" % number, tile != null)
	if tile == null:
		return
	var from: Vector2 = tile.get_global_rect().get_center()
	await _click(from)
	for _n: int in 600:
		if _library.mesh_for(number) != null:
			break
		await process_frame
	var mesh: Lbm.PartMesh = _library.mesh_for(number)
	var size: Vector3 = mesh.bounds.size.abs() if mesh != null else Vector3.ZERO
	_check("its mesh read, %s LDU as the catalogue has it (%s)" % [size, info.size.abs()],
		mesh != null and size.is_equal_approx(info.size.abs()))
	if mesh == null:
		return
	await _frames(20)
	var target: Vector2 = _camera.unproject_position(spot)
	await _move(from.lerp(target, 0.5))
	await _move(target)
	await _frames(6)
	if _builder.ghost_place() == null or not _builder.can_place():
		_check("%s has a ghost that may go down at %s" % [number, target.round()], false)
		return
	var shown: Transform3D = _builder.ghost_transform()
	var before: Dictionary = {}
	for brick: BrickWorld.Brick in _world.bricks():
		before[brick.id] = true
	await _click_whole(target)
	var made: BrickWorld.Brick = null
	for brick: BrickWorld.Brick in _world.bricks():
		if not before.has(brick.id):
			made = brick
	_check("%s put down by a click, where its ghost stood (%s)" % [number,
		made.transform.origin if made != null else "nothing put"],
		made != null and made.part_id == number
			and made.transform.origin.distance_to(shown.origin) < 0.01)


# -- helpers, as placing_probe sends them -------------------------------------------


func _frames(count: int) -> void:
	for _n: int in count:
		await process_frame


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
	await _click_whole(at)


func _click_whole(at: Vector2) -> void:
	var whole: Vector2 = _as_event(at).floor()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		event.position = whole
		event.global_position = whole
		Input.parse_input_event(event)
		await _frames(2)
	await _frames(3)


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


func _shot(name: String) -> void:
	await _frames(20)
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = ProjectSettings.globalize_path("res://shots/new_parts/%s.png" % name)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	image.save_png(path)
	print("    picture: shots/new_parts/%s.png" % name)
